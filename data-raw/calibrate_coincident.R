# Monte Carlo check of the coincident criteria (rcli 0.1.4).
# Run from the package root:
#   Rscript data-raw/calibrate_coincident.R
# Output: inst/calibration/coincident.csv, the share of simulated composites
# that pass cci_validate() by true timing of their two components.
#
# The timing band was first +/- 2 months for both frequencies. For quarterly
# data that band is narrower than one period, and only 82.5 percent of truly
# coincident composites passed (40 replications), because turning-point
# dating noise moves the median lead by one quarter. With a band of
# max(2 months, 1 period) the share rose to 98.8 percent (80 replications)
# while no leading or lagging composite passed: the cross-correlation
# criterion keeps them out.
devtools::load_all(quiet = TRUE)
reps <- as.integer(Sys.getenv("RCLI_REPS", "100"))

one_setting <- function(freq, noise_sd, seed) {
  k <- if (freq == 12) 3 else 1
  leads <- c(coin_a = 0, coin_b = 0, lead_a = k, lead_b = k,
             lag_a = -k, lag_b = -k)
  if (freq == 12) leads <- c(leads, near_a = 2, near_b = 2)
  sim <- simulate_cycles(freq = freq, leads = leads, counter = numeric(0),
                         n_noise = 0, noise_sd = noise_sd, seed = seed)
  meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
  spec <- cli_spec(freq = freq)
  cand <- suppressWarnings(cli_candidates(sim, "reference", meta = meta))
  cyc <- cli_cycles(cand, spec)
  test <- function(cs) {
    comp <- cli_composite(cyc, cs, spec, cyc$reference)
    cci_validate(comp, cyc$reference, spec)@passed
  }
  pairs <- list(coincident = c("coin_a", "coin_b"),
                leading = c("lead_a", "lead_b"),
                lagging = c("lag_a", "lag_b"))
  if (freq == 12) pairs$leading_2m <- c("near_a", "near_b")
  vapply(pairs, test, logical(1))
}

grid <- expand.grid(freq = c(12, 4), noise_sd = c(0.4, 0.8))
rows <- lapply(seq_len(nrow(grid)), function(i) {
  g <- grid[i, ]
  res <- vapply(seq_len(reps), function(s) {
    out <- one_setting(g$freq, g$noise_sd, s)
    c(out, leading_2m = if (g$freq == 12) out[["leading_2m"]] else NA)[
      c("coincident", "leading", "lagging", "leading_2m")]
  }, logical(4))
  data.frame(freq = g$freq, noise_sd = g$noise_sd,
             truth = rownames(res), reps = reps,
             pass_rate = rowMeans(res))
})
out <- do.call(rbind, rows)
out <- out[!is.na(out$pass_rate), ]
rownames(out) <- NULL
print(out)
utils::write.csv(out, "inst/calibration/coincident.csv", row.names = FALSE)
