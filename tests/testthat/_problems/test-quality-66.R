# Extracted from test-quality.R:66

# prequel ----------------------------------------------------------------------
cand <- sim_candidates(seed = 1)

# test -------------------------------------------------------------------------
spec <- cli_spec(12)
cyc <- cli_cycles(cand, spec)
ci <- cli_composite(cyc, c("lead_6", "lead_3"), spec, cyc$reference)
pr <- contraction_probability(ci, cyc$reference, spec)
expect_named(pr, c("time", "contraction", "probability"))
