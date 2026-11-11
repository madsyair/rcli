# Golden file of the level form: cycles and composite of rcli 0.6.0, so that
# tests of 0.7.0 and later check that the default results did not change.
# Run from the root of a checkout of rcli 0.6.0 (commit 285b331):
#   git worktree add /tmp/rcli-060 285b331
#   cd /tmp/rcli-060 && Rscript <this repo>/data-raw/make_level_060.R <out>
devtools::load_all(quiet = TRUE)
out <- commandArgs(TRUE)[1]
stopifnot(packageVersion("rcli") == "0.6.0")
res <- lapply(c(12, 4), function(freq) {
  sim <- simulate_cycles(seed = 7, freq = freq)
  meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
  cand <- cli_candidates(sim, "reference", meta = meta)
  spec <- cli_spec(freq)
  b <- suppressWarnings(cli_build(cand, spec))
  list(freq = freq,
       cycles = lapply(b@cycles, function(cs) as.numeric(cs@normalised)),
       class = b@assessment@table$class,
       index = as.numeric(b@composite@index))
})
saveRDS(res, out, version = 2)
