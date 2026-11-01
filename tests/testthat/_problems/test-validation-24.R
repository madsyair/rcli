# Extracted from test-validation.R:24

# prequel ----------------------------------------------------------------------
spec <- cli_spec(12)
cyc <- cli_cycles(sim_candidates(seed = 1), spec)

# test -------------------------------------------------------------------------
ci <- cli_composite(cyc, c("lead_6", "lead_3"), spec, cyc$reference)
v <- cli_validate(ci, cyc$reference, spec)
expect_true(v@passed)
expect_length(v@failed, 0)
expect_gte(v@turning_points$ccf_lag, 3)
expect_true(v@probability$qps >= 0 && v@probability$qps <= 2)
expect_gt(v@probability$auc, 0.8)
expect_lt(v@probability$pt_p, 0.01)
expect_equal(v@probability$horizon, v@turning_points$ccf_lag)
