test_that("defaults depend on the frequency", {
  m <- cli_spec(12)
  q <- cli_spec(4)
  expect_s4_class(m@dater, "BryBoschan")
  expect_s4_class(q@dater, "BBQ")
  expect_equal(c(m@min_lead, q@min_lead), c(3, 1))
  expect_equal(m@lead_window, c(12, 24))
  expect_equal(q@lead_window, c(4, 8))
  expect_s4_class(m@filter, "HPDoubleFilter")
  expect_s4_class(m@aggregator, "EqualWeight")
})

test_that("invalid specifications are rejected", {
  expect_error(cli_spec(1), class = "rcli_error_frequency")
  expect_error(cli_spec(min_consistency = 2), "min_consistency")
  expect_error(cli_spec(max_missed = 3), "max_missed")
  expect_error(cli_spec(alpha = 0), "alpha")
  expect_error(cli_spec(lead_window = 1), "lead_window")
  expect_error(cli_spec(horizon = -1), "horizon")
  expect_error(cli_spec(transform = "sqrt"))
})

test_that("update() changes and re-validates fields", {
  s <- update(cli_spec(), min_lead = 6L, aggregator = dynamic_factor())
  expect_equal(s@min_lead, 6)
  expect_s4_class(s@aggregator, "DynamicFactor")
  expect_error(update(cli_spec(), nonsense = 1),
               class = "rcli_error_argument")
  expect_error(update(cli_spec(), alpha = 2), "alpha")
})

test_that("specification objects print", {
  expect_snapshot(cli_spec(12))
  expect_snapshot(cli_spec(4, filter = cf_filter(6, 32)))
  expect_snapshot(hp_double_filter())
  expect_snapshot(bbq())
  expect_snapshot(conference_board())
})
