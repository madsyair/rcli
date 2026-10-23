# Real-time evaluation of the 0.2.0 defaults (study of 23 October 2026).
# Run from the package root:  Rscript data-raw/realtime_defaults.R
# Pseudo real-time vintages every 12 months (month 216 to 36 months before
# the end), components published 0 to 2 months late; the last value of each
# vintage composite is compared with the full-sample composite.
# Output: inst/calibration/realtime-defaults.csv
devtools::load_all(quiet = TRUE)
reps <- as.integer(Sys.getenv("LEADCLI_REPS", "40"))
comps <- c("lead_9", "lead_6", "lead_3")
variants <- list(
  v013 = list(agg = equal_weight(ragged_edge = "level"), ext = no_extension()),
  chain = list(agg = equal_weight(), ext = no_extension()),
  ar = list(agg = equal_weight(ragged_edge = "level"), ext = ar_extension()),
  v020 = list(agg = equal_weight(), ext = ar_extension()))
make_data <- function(seed, dgp, noise) {
  sim <- simulate_cycles(leads = c(lead_9 = 9, lead_6 = 6, lead_3 = 3),
                         counter = numeric(0), n_noise = 0,
                         noise_sd = noise, seed = seed)
  if (dgp == "stochastic") {
    set.seed(seed + 1e4)
    for (j in seq_len(ncol(sim))) {
      sim[, j] <- sim[, j] * exp(cumsum(rnorm(nrow(sim), 0, 0.004)))
    }
  }
  sim
}
cyc_of <- function(d, spec) {
  stats::setNames(lapply(comps, function(nm) rcli:::cycle_one(d[, nm], nm,
                                                              spec)), comps)
}
one_rep <- function(seed, dgp, noise) {
  sim <- make_data(seed, dgp, noise); n <- nrow(sim)
  set.seed(seed + 2e4)
  lag <- stats::setNames(sample(0:2, 3, replace = TRUE), comps)
  res <- list()
  for (v in names(variants)) {
    spec <- cli_spec(12, aggregator = variants[[v]]$agg,
                     extension = variants[[v]]$ext)
    fin <- as.numeric(cli_composite(cyc_of(sim, spec), comps, spec)@cycle)
    for (tt in seq(216, n - 36, by = 12)) {
      d <- stats::window(sim, end = stats::time(sim)[tt])
      for (nm in comps) if (lag[[nm]] > 0) d[(tt - lag[[nm]] + 1):tt, nm] <- NA
      v_c <- as.numeric(cli_composite(cyc_of(d, spec), comps, spec)@cycle)
      last <- max(which(!is.na(v_c)))
      f <- fin[seq_along(v_c)]
      res[[length(res) + 1]] <- data.frame(
        trend = dgp, noise_sd = noise, seed = seed, variant = v,
        rev = abs(v_c[last] - f[last]),
        dir_ok = sign(v_c[last] - v_c[last - 1]) == sign(f[last] - f[last - 1]))
    }
  }
  do.call(rbind, res)
}
grid <- expand.grid(trend = c("deterministic", "stochastic"),
                    noise_sd = c(0.4, 0.8), stringsAsFactors = FALSE)
out <- do.call(rbind, lapply(seq_len(nrow(grid)), function(g) {
  do.call(rbind, parallel::mclapply(seq_len(reps), one_rep,
                                    dgp = grid$trend[g],
                                    noise = grid$noise_sd[g], mc.cores = 2))
}))
res <- aggregate(cbind(revision = rev, direction_right = dir_ok) ~
                   variant + trend + noise_sd, out, mean)
res$variant <- factor(res$variant, c("v013", "chain", "ar", "v020"),
                      c("0.1.x", "chain only", "AR only", "0.2.0"))
res <- res[order(res$trend, res$noise_sd, res$variant), ]
res[, 4:5] <- round(res[, 4:5], 3)
utils::write.csv(res, "inst/calibration/realtime-defaults.csv",
                 row.names = FALSE)
print(res, row.names = FALSE)
