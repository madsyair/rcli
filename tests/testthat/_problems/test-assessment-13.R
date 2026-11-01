# Extracted from test-assessment.R:13

# test -------------------------------------------------------------------------
tp <- date_turning_points(bry_boschan(), sine_ts())
conc <- concordance(tp, tp)
expect_equal(conc$index, 1)
expect_lt(conc$p_value, 1e-6)
