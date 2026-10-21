# Monte Carlo calibration harness, part 1: collect assessment statistics of
# simulated candidates with known class. Run from the package root:
#   Rscript data-raw/calibrate_collect.R
# Output: inst/calibration/assessment-stats.csv
devtools::load_all(quiet = TRUE)
reps <- as.integer(Sys.getenv("LEADCLI_REPS", "100"))
collect <- function(freq, noise_sd) {
  do.call(rbind, lapply(seq_len(reps), function(s) {
    sim <- simulate_cycles(freq = freq, noise_sd = noise_sd, seed = s)
    truth <- attr(sim, "truth")
    meta <- data.frame(name = truth$name, rationale = "early_stage")
    cand <- cli_candidates(sim, "reference", meta = meta)
    tab <- cli_assess(cand, cli_spec(freq))@table
    tab$truth <- truth$class[match(tab$name, truth$name)]
    tab$true_lead <- truth$lead[match(tab$name, truth$name)]
    tab$seed <- s
    tab$freq <- freq
    tab$noise_sd <- noise_sd
    tab
  }))
}
grid <- expand.grid(freq = c(12, 4), noise_sd = c(0.2, 0.4, 0.8))
res <- do.call(rbind, Map(collect, grid$freq, grid$noise_sd))
dir.create("inst/calibration", showWarnings = FALSE, recursive = TRUE)
utils::write.csv(res, "inst/calibration/assessment-stats.csv", row.names = FALSE)
