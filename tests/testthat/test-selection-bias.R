test_that("the selection-bias harness reports in- and out-of-sample leads", {
  cand <- sim_candidates(seed = 3)
  sb <- cli_selection_bias(cand, cli_spec(12), c(2016, 2012))
  expect_equal(sb$cutoff, c(2012, 2016))
  expect_true(all(sb$n_components >= 1))
  expect_true(all(sb$n_tp_out > 0))
  expect_equal(sb$lead_gap, sb$median_lead_in - sb$median_lead_out)
  expect_true(all(sb$median_lead_out > 0))
})

test_that("too short training windows give empty rows", {
  cand <- sim_candidates(seed = 3)
  sb <- cli_selection_bias(cand, cli_spec(12), 1997)
  expect_equal(sb$n_components, 0)
  expect_equal(sb$note, "training window too short")
  sb2 <- cli_selection_bias(sim_candidates(seed = 2026), cli_spec(12), 2008)
  expect_equal(sb2$note, "no leading candidate before the cut-off")
  ok <- cli_selection_bias(cand, cli_spec(12), 2014)
  expect_equal(ok$note, "")
  expect_error(cli_selection_bias(cand, cli_spec(12), numeric(0)),
               class = "rcli_error_argument")
})

test_that("cli_build stores the harness when cut-offs are given", {
  cand <- sim_candidates(seed = 3)
  res <- cli_build(cand, cli_spec(12, oos_cutoffs = 2014))
  oos <- validation(res)@out_of_sample
  expect_equal(nrow(oos), 1)
  expect_output(print(validation(res)), "selection bias")
})

test_that("summary warns when the in-sample lead is a selection effect", {
  res <- cli_build(sim_candidates(seed = 3), cli_spec(12))
  res@validation@out_of_sample <- data.frame(
    cutoff = 2014, n_components = 2, components = "a, b", ccf_lag_in = 6,
    median_lead_in = 9, median_lead_out = 0, pct_led_out = 0.2, n_tp_out = 4,
    lead_gap = 9
  )
  expect_output(summary(res), "selection effect")
})
