# Choice of the default turning-point matching window (FR-012, AC-5):
# classification accuracy of the rcli and OECD rules with the asymmetric
# window of rcli 0.5.1 and a symmetric one, on the calibration simulations
# plus one independent cycle per replication. Run from the package root:
#   Rscript data-raw/lead_window_choice.R
# Output: inst/calibration/lead-window.csv
devtools::load_all(quiet = TRUE)
reps <- as.integer(Sys.getenv("RCLI_REPS", "60"))
windows <- list(`12` = list(asymmetric = c(12, 24), symmetric = c(12, 12)),
                `4` = list(asymmetric = c(4, 8), symmetric = c(4, 4)))
rows <- list()
for (freq in c(12, 4)) for (noise in c(0.2, 0.4, 0.8)) {
  stats_by_window <- list()
  for (s in seq_len(reps)) {
    sim <- simulate_cycles(freq = freq, noise_sd = noise, seed = s)
    other <- simulate_cycles(freq = freq, noise_sd = noise, seed = s + 10000L)
    truth <- attr(sim, "truth")
    x <- stats::ts(cbind(sim, independent = other[, "reference"]),
                   start = stats::start(sim), frequency = freq)
    colnames(x) <- c(colnames(sim), "independent")
    meta <- data.frame(name = colnames(x)[-1], rationale = "early_stage")
    cand <- cli_candidates(x, "reference", meta = meta)
    cyc <- suppressWarnings(cli_cycles(cand, cli_spec(freq)))
    for (w in names(windows[[as.character(freq)]])) {
      spec <- cli_spec(freq, lead_window = windows[[as.character(freq)]][[w]])
      tab <- suppressWarnings(cli_assess(cand, spec, cycles = cyc))@table
      tab$truth <- c(truth$class, "rejected")[
        match(tab$name, c(truth$name, "independent"))]
      tab$oecd <- vapply(seq_len(nrow(tab)), function(i) {
        s_oecd <- update(spec, classifier = oecd_classifier())
        classify_row(tab[i, ], s_oecd)$class
      }, character(1))
      tab$window <- w
      stats_by_window[[length(stats_by_window) + 1L]] <- tab
    }
  }
  d <- do.call(rbind, stats_by_window)
  for (w in unique(d$window)) for (rule in c("class", "oecd")) {
    e <- d[d$window == w, ]
    cls <- e[[rule]]
    acc <- function(k) mean(cls[e$truth == k] == k)
    rows[[length(rows) + 1L]] <- data.frame(
      freq = freq, noise_sd = noise, window = w,
      classifier = if (rule == "class") "rcli" else "oecd",
      correct.leading = acc("leading"), correct.coincident = acc("coincident"),
      correct.lagging = acc("lagging"), correct.rejected = acc("rejected"),
      false_leading = mean(cls[e$truth != "leading"] == "leading"),
      false_leading_independent = mean(cls[e$name == "independent"] ==
                                         "leading"),
      overall = mean(cls == e$truth), reps = reps)
  }
}
out <- do.call(rbind, rows)
out[, 5:11] <- round(out[, 5:11], 3)
utils::write.csv(out, "inst/calibration/lead-window.csv", row.names = FALSE)
print(out)
