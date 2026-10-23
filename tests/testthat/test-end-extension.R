# FR-002, F-02: end-of-series extension with AR forecasts (rcli 0.2.0).
# Reference: harness/02-math/F-02.md.

test_that("FR-002 AC-1 / F-02: a linear trend is continued exactly", {
  # slope 0.25 is exact in binary, so the changes have zero variance
  x <- ts(0.25 * (1:120), frequency = 12)
  expect_equal(extend_series(ar_extension(h = 12), x), x[120] + 0.25 * (1:12))
  # slope 0.01 leaves rounding noise in the changes: still a straight line,
  # and taken by the drift branch, not by the autoregression (R19)
  y <- ts(0.01 * (1:120), frequency = 12)
  local_mocked_bindings(ar_forecast = function(d, order_max, h) rep(99, h))
  expect_equal(extend_series(ar_extension(h = 12), y),
               y[120] + 0.01 * (1:12), tolerance = 1e-10)
})

test_that("FR-002 AC-6: the drift fallback uses the mean change", {
  set.seed(5)
  x <- ts(cumsum(rnorm(100, 0.3, 1)), frequency = 12)
  d <- diff(as.numeric(x))
  local_mocked_bindings(ar_forecast = function(d, order_max, h) NULL)
  expect_equal(extend_series(ar_extension(h = 4), x),
               x[100] + mean(d) * (1:4))
  local_mocked_bindings(ar_forecast = function(d, order_max, h) rep(Inf, h))
  expect_equal(extend_series(ar_extension(h = 4), x),
               x[100] + mean(d) * (1:4))
})

test_that("F-02: order_max bounds the autoregression", {
  set.seed(7)
  d <- as.numeric(arima.sim(list(ar = 0.6), n = 300)) * 0.01 + 0.002
  x <- ts(cumsum(c(5, d)), frequency = 12)
  f0 <- extend_series(ar_extension(h = 3, order_max = 0), x)
  expect_equal(f0, x[length(x)] + mean(diff(as.numeric(x))) * (1:3),
               tolerance = 1e-10)
  f1 <- extend_series(ar_extension(h = 3, order_max = 1), x)
  expect_false(isTRUE(all.equal(f0, f1)))
})

test_that("F-02: extend_series validates its input", {
  e <- ar_extension()
  expect_error(extend_series(e, 1:10), class = "rcli_error_argument")
  expect_error(extend_series(e, ts(c(1, NA, 3, 4), frequency = 4)),
               class = "rcli_error_argument")
  expect_error(extend_series(e, ts(1:2, frequency = 4)),
               class = "rcli_error_argument")
  expect_error(extend_series(e, ts(c(1, 2, Inf, 4, 5), frequency = 4)),
               class = "rcli_error_argument")
})

test_that("FR-002 AC-2: horizons and the no-extension strategy", {
  set.seed(3)
  xm <- ts(cumsum(rnorm(120, 0.01, 0.02)), frequency = 12)
  xq <- ts(cumsum(rnorm(60, 0.01, 0.02)), frequency = 4)
  expect_length(extend_series(ar_extension(), xm), 12L)
  expect_length(extend_series(ar_extension(), xq), 4L)
  expect_length(extend_series(ar_extension(h = 6), xm), 6L)
  expect_length(extend_series(no_extension(), xm), 0L)
  expect_error(ar_extension(h = 0), class = "rcli_error_argument")
  expect_error(ar_extension(h = 2.5), class = "rcli_error_argument")
  expect_error(ar_extension(order_max = -1), class = "rcli_error_argument")
  expect_output(show(ar_extension()), "AR")
  expect_output(show(no_extension()), "none")
})

test_that("FR-002 AC-3 / F-02: forecasts match predict(ar()) on differences", {
  set.seed(7)
  d <- as.numeric(arima.sim(list(ar = 0.6), n = 600)) * 0.01 + 0.002
  x <- ts(cumsum(c(5, d)), frequency = 12)
  dd <- diff(as.numeric(x))
  fit <- stats::ar(dd, aic = TRUE, order.max = 12, method = "yule-walker")
  want <- x[length(x)] + cumsum(as.numeric(predict(fit, n.ahead = 12)$pred))
  expect_equal(extend_series(ar_extension(h = 12, order_max = 12), x), want,
               tolerance = 1e-10)
  fit1 <- stats::ar(dd, aic = FALSE, order.max = 1, method = "yule-walker")
  manual <- x[length(x)] + fit1$x.mean +
    fit1$ar[1] * (dd[length(dd)] - fit1$x.mean)
  expect_equal(extend_series(ar_extension(h = 1, order_max = 1), x), manual,
               tolerance = 1e-10)
  expect_lt(abs(fit1$ar[1] - 0.6), 0.1)
})

test_that("FR-002 AC-6: constant changes and very short series", {
  x <- ts(rep(2, 30), frequency = 12)
  expect_equal(extend_series(ar_extension(h = 3), x), rep(2, 3))
  short <- ts(c(1, 1.1, 1.3), frequency = 4)
  f <- extend_series(ar_extension(h = 2), short)
  expect_length(f, 2L)
  expect_true(all(is.finite(f)))
})

test_that("FR-002 AC-4: cli_cycles extends the series and keeps its length", {
  cand <- sim_candidates(seed = 2)
  cs <- cli_cycles(cand, cli_spec(12))$lead_6
  expect_true(any(grepl("12-period forecasts: AR forecasts", cs@steps)))
  expect_equal(length(cs@cycle), length(cand@data[, "lead_6"]))
  plain <- cli_cycles(cand, cli_spec(12, extension = no_extension()))$lead_6
  expect_false(any(grepl("forecasts", plain@steps)))
  # the extension changes the end of the cycle, not its middle
  mid <- 100:200
  expect_equal(as.numeric(cs@cycle)[mid], as.numeric(plain@cycle)[mid],
               tolerance = 1e-3)
})

test_that("FR-002 AC-5: forecasts of the outlier treatment take precedence", {
  skip_if_not_installed("seasonal")
  skip_on_cran()
  cand <- sim_candidates(seed = 2)
  s <- cli_spec(12, outliers = tramo_outliers(engine = "x13", forecast = 6))
  cs <- cli_cycles(cand, s)$lead_6
  expect_true(any(grepl("6-period forecasts: outlier treatment", cs@steps)))
  expect_false(any(grepl("AR forecasts", cs@steps)))
  # forecast = 0: the extension of the specification applies (R27)
  s0 <- cli_spec(12, outliers = tramo_outliers(engine = "x13", forecast = 0))
  expect_true(any(grepl("AR forecasts", cli_cycles(cand, s0)$lead_6@steps)))
})

test_that("FR-002 AC-7 / FR-003 AC-1: spec slot, update, print, old objects", {
  s <- cli_spec(12)
  expect_s4_class(s@extension, "ArExtension")
  s2 <- update(s, extension = no_extension())
  expect_s4_class(s2@extension, "NoExtension")
  expect_output(show(s), "end:")
  old <- s
  attr(old, "extension") <- NULL
  expect_s4_class(rcli:::spec_extension(old), "NoExtension")
  expect_error(cli_spec(extension = "ar"), class = "rcli_error_argument")
  expect_error(cli_spec(classifier = "oecd"), class = "rcli_error_argument")
  expect_error(cli_spec(outliers = 5), class = "rcli_error_argument")
  # update() on a specification saved before the extension slot existed
  old2 <- s
  for (nm in c("extension", "lag_shift")) attr(old2, nm) <- NULL
  up <- update(old2, min_lead = 4)
  expect_s4_class(up@extension, "NoExtension")
  expect_false(up@lag_shift)
  expect_output(show(oecd_spec()), "forecasts of the outlier treatment")
})

test_that("FR-003 AC-2: oecd_spec uses TRAMO forecasts, no AR extension", {
  s <- oecd_spec()
  expect_s4_class(s@extension, "NoExtension")
  expect_s4_class(s@aggregator, "OecdAggregate")
})

test_that("FR-003 AC-4: the 0.1.x settings reproduce the 0.1.3 composite", {
  # golden values computed with rcli 0.1.3 (git a3b8181), default spec
  gold <- readRDS(test_path("fixtures", "composite-0.1.3.rds"))
  cand <- sim_candidates(seed = 4)
  old <- cli_spec(12, aggregator = equal_weight(ragged_edge = "level"),
                  extension = no_extension())
  res <- cli_build(cand, old)
  expect_equal(res@composite@components, gold$components)
  expect_equal(as.numeric(res@composite@index), gold$index,
               tolerance = 1e-12)
})

test_that("NFR-001: no new hard dependencies", {
  imports <- trimws(strsplit(utils::packageDescription("rcli")$Imports,
                             ",")[[1]])
  expect_setequal(imports, c("graphics", "grDevices", "methods", "stats",
                             "utils"))
})

test_that("NFR-002 (proxy): extend_series itself is cheap", {
  skip_on_cran()
  set.seed(9)
  x <- ts(cumsum(rnorm(360, 0.01, 0.02)), frequency = 12)
  t_ext <- system.time(for (i in 1:20) extend_series(ar_extension(), x))
  expect_lt(t_ext[["elapsed"]] / 20, 0.05)
})

test_that("NFR-003: recalibrated thresholds keep false leaders rare", {
  acc <- utils::read.csv(system.file("calibration", "accuracy.csv",
                                     package = "rcli"))
  expect_lte(max(acc$false_leading), 0.015)
  rt <- utils::read.csv(system.file("calibration", "realtime-defaults.csv",
                                    package = "rcli"))
  new <- rt[rt$variant == "0.2.0", ]
  old <- rt[rt$variant == "0.1.x", ]
  expect_true(all(new$revision < old$revision))
  expect_true(all(new$direction_right > old$direction_right))
})
