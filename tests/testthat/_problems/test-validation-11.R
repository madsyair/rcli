# Extracted from test-validation.R:11

# prequel ----------------------------------------------------------------------
spec <- cli_spec(12)
cyc <- cli_cycles(sim_candidates(seed = 1), spec)

# test -------------------------------------------------------------------------
expect_equal(rcli:::auc_score(c(0.1, 0.2, 0.8, 0.9), c(0, 0, 1, 1)), 1)
expect_equal(rcli:::auc_score(c(0.9, 0.8, 0.2, 0.1), c(0, 0, 1, 1)), 0)
expect_true(is.na(rcli:::auc_score(1:3, c(1, 1, 1))))
x <- as.numeric(sine_ts(shift = -6))
y <- as.numeric(sine_ts())
pt <- rcli:::pesaran_timmermann(x, y, 6)
expect_lt(pt$p_value, 1e-6)
