# Monte Carlo calibration of the cycle forms (rcli 0.7.0, FR-013).
# The classification thresholds were calibrated for level (growth) cycles.
# This script measures how the same default rules classify simulated
# candidates with known class when the cycles are taken as annual growth
# rates or as accelerations (with the HP smoother as default filter).
# Run from the package root (about 10 minutes for 60 replications):
#   Rscript data-raw/calibrate_forms.R
# Output: inst/calibration/forms.csv
devtools::load_all(quiet = TRUE)
reps <- as.integer(Sys.getenv("RCLI_REPS", "60"))
forms <- list(level = level_form(), growth = growth_form(),
              acceleration = acceleration_form())
collect <- function(freq, noise_sd, form) {
  do.call(rbind, lapply(seq_len(reps), function(s) {
    sim <- simulate_cycles(freq = freq, noise_sd = noise_sd, seed = s)
    truth <- attr(sim, "truth")
    meta <- data.frame(name = truth$name, rationale = "early_stage")
    cand <- cli_candidates(sim, "reference", meta = meta)
    spec <- cli_spec(freq, form = forms[[form]])
    tab <- suppressWarnings(cli_assess(cand, spec))@table
    data.frame(freq = freq, noise_sd = noise_sd, form = form, seed = s,
               truth = truth$class[match(tab$name, truth$name)],
               class = tab$class)
  }))
}
grid <- expand.grid(freq = c(12, 4), noise_sd = c(0.2, 0.4, 0.8),
                    form = names(forms), stringsAsFactors = FALSE)
d <- do.call(rbind, Map(collect, grid$freq, grid$noise_sd, grid$form))
by <- list(form = d$form, freq = d$freq, noise_sd = d$noise_sd)
acc <- aggregate(list(correct = d$class == d$truth),
                 c(by, list(truth = d$truth)), mean)
nl <- d$truth != "leading"
fp <- aggregate(list(false_leading = d$class[nl] == "leading"),
                lapply(by, `[`, nl), mean)
overall <- aggregate(list(overall = d$class == d$truth), by, mean)
wide <- reshape(acc, idvar = c("form", "freq", "noise_sd"),
                timevar = "truth", direction = "wide")
out <- merge(merge(wide, fp), overall)
out[, -(1:3)] <- round(out[, -(1:3)], 3)
out$reps <- reps
out <- out[order(match(out$form, names(forms)), -out$freq, out$noise_sd), ]
dir.create("inst/calibration", showWarnings = FALSE, recursive = TRUE)
utils::write.csv(out, "inst/calibration/forms.csv", row.names = FALSE)
print(out, row.names = FALSE)
