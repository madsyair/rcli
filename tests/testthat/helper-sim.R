# Candidate set from simulated data with known truth.
sim_candidates <- function(seed = 1, freq = 12, ...) {
  sim <- simulate_cycles(freq = freq, seed = seed, ...)
  meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
  cand <- cli_candidates(sim, "reference", meta = meta)
  attr(cand, "truth") <- attr(sim, "truth")
  cand
}

sine_ts <- function(n = 240, period = 48, shift = 0, freq = 12, start = 2000) {
  ts(sin(2 * pi * ((1:n) - shift) / period), frequency = freq, start = start)
}
