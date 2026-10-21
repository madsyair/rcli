spec <- cli_spec(12)
cyc <- cli_cycles(sim_candidates(seed = 1), spec)
comps <- c("lead_6", "lead_3")

test_that("equal weights average the normalised cycles", {
  ci <- cli_composite(cyc, comps, spec)
  manual <- rcli:::normalise_cycle(
    (as.numeric(cyc$lead_6@normalised) + as.numeric(cyc$lead_3@normalised)) / 2
  )
  expect_equal(as.numeric(ci@cycle), manual)
  expect_equal(unname(ci@weights), c(0.5, 0.5))
  expect_equal(mean(ci@index), 100)
  expect_equal(ci@amplitude, 1)
})

test_that("coverage rule masks dates with too few components", {
  cyc2 <- cyc
  cyc2$lead_3@normalised[1:30] <- NA
  ci <- cli_composite(cyc2, comps, update(spec, aggregator = equal_weight(0.6)))
  expect_true(all(is.na(ci@cycle[1:30])))
  ci2 <- cli_composite(cyc2, comps,
                       update(spec, aggregator = equal_weight(0.5)))
  expect_false(anyNA(ci2@cycle))
})

test_that("principal-component weights are non-negative and sum to one", {
  ci <- cli_composite(cyc, c(comps, "coincident"),
                      update(spec, aggregator = principal_component()))
  expect_equal(sum(ci@weights), 1)
  expect_true(all(ci@weights >= 0))
  one <- cli_composite(cyc, "lead_6",
                       update(spec, aggregator = principal_component()))
  expect_equal(unname(one@weights), 1)
})

test_that("Conference Board index averages 100 and keeps a cycle", {
  ci <- cli_composite(cyc, comps, update(spec, aggregator = conference_board()))
  expect_equal(mean(ci@index, na.rm = TRUE), 100)
  expect_gt(cor(as.numeric(ci@cycle), as.numeric(cyc$lead_6@normalised),
                use = "complete.obs"), 0.8)
  expect_equal(sum(ci@weights), 1)
  expect_equal(rcli:::symmetric_change(c(-1, 1, 2)), c(NA, 2, 1))
})

test_that("dynamic factor recovers the common cycle with ragged edges", {
  cyc2 <- cyc
  cyc2$lead_3@normalised[340:360] <- NA
  ci <- cli_composite(cyc2, c(comps, "coincident"),
                      update(spec, aggregator = dynamic_factor(0.3)))
  avg <- rowMeans(sapply(c(comps, "coincident"),
                         function(n) as.numeric(cyc[[n]]@normalised)))
  expect_gt(cor(as.numeric(ci@cycle), avg, use = "complete.obs"), 0.85)
  expect_false(anyNA(ci@cycle[340:360]))
  expect_true(all(ci@weights > 0))
})

test_that("inverted components enter with their sign", {
  inv <- cyc
  inv$counter_4 <- rcli:::invert_cycle(inv$counter_4)
  ci <- cli_composite(inv, c("lead_6", "counter_4"),
                      update(spec, aggregator = conference_board()))
  expect_gt(cor(as.numeric(ci@cycle), as.numeric(cyc$lead_6@normalised),
                use = "complete.obs"), 0.7)
})

test_that("the index is amplitude adjusted to the reference", {
  ci <- cli_composite(cyc, comps, spec, cyc$reference)
  amp <- 100 * rcli:::mean_abs_dev(as.numeric(cyc$reference@cycle))
  expect_equal(ci@amplitude, amp)
  expect_equal(mean(abs(ci@index - 100)), amp, tolerance = 1e-8)
})

test_that("bad component lists are rejected and composites print", {
  expect_error(cli_composite(cyc, "zzz", spec),
               class = "rcli_error_argument")
  expect_error(cli_composite(cyc, comps, list()),
               class = "rcli_error_argument")
  expect_snapshot(cli_composite(cyc, comps, spec))
  df <- as.data.frame(cli_composite(cyc, comps, spec))
  expect_named(df, c("time", "index", "cycle"))
})
