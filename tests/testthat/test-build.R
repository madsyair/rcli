test_that("the workflow selects the simulated leaders", {
  cand <- sim_candidates(seed = 1)
  res <- cli_build(cand)
  expect_s4_class(res, "CliResult")
  expect_setequal(components(res), c("lead_6", "lead_3", "counter_4"))
  expect_true(validation(res)@passed)
  expect_equal(leaders(res), leaders(assessment(res)))
  expect_named(cycles(res), colnames(cand@data))
  expect_named(turning_points(res), colnames(cand@data))
  expect_true("inverted (counter-cyclical)" %in% cycles(res)$counter_4@steps)
  log <- audit_log(res)
  expect_equal(tail(log$action, 1), "accepted: all criteria met")
  expect_s4_class(composite(res), "CompositeIndex")
})

test_that("each aggregator runs through the whole workflow", {
  cand <- sim_candidates(seed = 2)
  aggs <- list(principal_component(), conference_board(), dynamic_factor())
  for (agg in aggs) {
    res <- cli_build(cand, cli_spec(12, aggregator = agg))
    expect_s4_class(res@composite@aggregator, class(agg))
    expect_true(length(components(res)) >= 2)
  }
})

test_that("the loop drops components until the stopping rule", {
  spec <- cli_spec(12)
  cand <- sim_candidates(seed = 1)
  cyc <- cli_cycles(cand, spec)
  a <- cli_assess(cand, spec, cyc)
  for (nm in a@inverted) cyc[[nm]] <- rcli:::invert_cycle(cyc[[nm]])
  strict <- update(spec, min_lead = 30, min_components = 1, max_iter = 5)
  sel <- rcli:::select_components(cyc, a, strict, "reference")
  log <- sel$audit
  expect_true(any(grepl("^dropped", log$action)))
  expect_equal(tail(log$action, 1),
               "stopped: minimum number of components reached")
  expect_equal(tail(log$n_components, 1), 1)
  capped <- update(strict, max_iter = 1)
  sel2 <- rcli:::select_components(cyc, a, capped, "reference")
  expect_equal(tail(sel2$audit$action, 1),
               "stopped: maximum number of iterations")
})

test_that("no leading candidate gives no composite and a warning", {
  cand <- sim_candidates(seed = 1)[c("noise_1", "noise_2", "lag_3")]
  expect_warning(res <- cli_build(cand), class = "rcli_warning_no_leaders")
  expect_null(composite(res))
  expect_length(components(res), 0)
  expect_output(print(res), "no composite")
  expect_output(summary(res), "Composite leading indicator")
})

test_that("results print, summarise and plot", {
  res <- cli_build(sim_candidates(seed = 1))
  expect_snapshot(res)
  expect_output(s <- summary(res), "CliValidation")
  expect_named(s, c("assessment", "validation", "audit"))
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  expect_invisible(plot(res))
  expect_invisible(plot(composite(res)))
  expect_invisible(plot(turning_points(res)$reference))
})
