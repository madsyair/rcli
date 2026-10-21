# Users extend rcli by subclassing the exported virtual strategy classes.

test_that("a user-defined filter and aggregator plug into the workflow", {
  setClass("TestLinearFilter", contains = "CycleFilter",
           where = globalenv())
  on.exit(removeClass("TestLinearFilter", where = globalenv()), add = TRUE)
  setMethod("extract_cycle", "TestLinearFilter", function(filter, x, ...) {
    tt <- seq_along(x)
    stats::ts(stats::residuals(stats::lm(as.numeric(x) ~ poly(tt, 3))),
              start = stats::start(x), frequency = stats::frequency(x))
  }, where = globalenv())

  setClass("TestMedianAggregator", contains = "Aggregator",
           where = globalenv())
  on.exit(removeClass("TestMedianAggregator", where = globalenv()),
          add = TRUE)
  setMethod("aggregate_components", "TestMedianAggregator",
            function(aggregator, z, levels, spec) {
    w <- rep(1 / ncol(z), ncol(z))
    list(cycle = apply(z, 1, stats::median, na.rm = TRUE), index = NULL,
         weights = stats::setNames(w, colnames(z)))
  }, where = globalenv())

  sim <- simulate_cycles(seed = 3)
  meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
  cand <- cli_candidates(sim, "reference", meta = meta)
  spec <- cli_spec(
    freq = 12,
    filter = new("TestLinearFilter", label = "cubic trend"),
    aggregator = new("TestMedianAggregator", label = "median",
                     min_coverage = 0.6)
  )
  res <- cli_build(cand, spec)
  expect_s4_class(res, "CliResult")
  expect_s4_class(composite(res), "CompositeIndex")
  expect_identical(composite(res)@aggregator@label, "median")
})
