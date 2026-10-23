set.seed(11)
xq <- ts(cumsum(rnorm(200)) + 100, frequency = 4, start = 1970)
xm <- ts(cumsum(rnorm(360)) + 100, frequency = 12, start = 1990)

test_that("HP smoothing parameter matches the OECD values", {
  expect_equal(hp_lambda(120), 133107.94, tolerance = 1e-6)
  expect_equal(hp_lambda(12), 13.93, tolerance = 1e-3)
  expect_error(hp_lambda(2), class = "rcli_error_argument")
})

test_that("HP filter replicates mFilter", {
  skip_if_not_installed("mFilter")
  ours <- extract_cycle(hp_filter(1600), xq)
  ref <- mFilter::hpfilter(xq, freq = 1600, type = "lambda")$cycle
  expect_equal(as.numeric(ours), as.numeric(ref), tolerance = 1e-8)
})

test_that("Christiano-Fitzgerald filter replicates mFilter (random walk)", {
  skip_if_not_installed("mFilter")
  ours <- extract_cycle(cf_filter(6, 32), xq)
  ref <- mFilter::cffilter(xq, pl = 6, pu = 32, root = TRUE)$cycle
  expect_equal(as.numeric(ours), as.numeric(ref), tolerance = 1e-8)
})

test_that("Baxter-King filter replicates mFilter", {
  skip_if_not_installed("mFilter")
  ours <- extract_cycle(bk_filter(6, 32, 12), xq)
  ref <- mFilter::bkfilter(xq, pl = 6, pu = 32, nfix = 12, type = "fixed")$cycle
  ok <- !is.na(ours)
  expect_equal(sum(!ok), 24)
  expect_equal(as.numeric(ours)[ok], as.numeric(ref)[ok], tolerance = 1e-8)
})

test_that("Hamilton filter replicates neverhpfilter", {
  skip_if_not_installed("neverhpfilter")
  skip_if_not_installed("xts")
  y <- xts::as.xts(xq)
  names(y) <- "y"
  ref <- as.numeric(neverhpfilter::yth_filter(y, h = 8, p = 4,
                                              output = "cycle"))
  ours <- extract_cycle(hamilton_filter(8, 4), xq)
  expect_equal(sum(is.na(ours)), 11)
  expect_equal(as.numeric(ours)[!is.na(ours)], ref, tolerance = 1e-8)
})

test_that("default parameters are resolved from the frequency", {
  expect_equal(extract_cycle(hp_filter(), xq),
               extract_cycle(hp_filter(1600), xq))
  expect_equal(extract_cycle(hp_filter(), xm),
               extract_cycle(hp_filter(129600), xm))
  expect_equal(extract_cycle(hp_double_filter(), xm),
               extract_cycle(hp_double_filter(120, 12), xm))
  expect_equal(sum(is.na(extract_cycle(bk_filter(), xm))), 72)
  expect_equal(sum(is.na(extract_cycle(hamilton_filter(), xm))), 35)
})

test_that("filters keep the time attributes", {
  for (f in list(hp_filter(), hp_double_filter(), cf_filter(), bk_filter(),
                 hamilton_filter())) {
    out <- extract_cycle(f, xm)
    expect_s3_class(out, "ts")
    expect_equal(tsp(out), tsp(xm))
  }
})

test_that("the double HP filter recovers a business cycle around a trend", {
  t <- 1:360
  cyc <- sin(2 * pi * t / 48)
  x <- ts(0.01 * t + cyc, frequency = 12)
  out <- extract_cycle(hp_double_filter(), x)
  expect_gt(cor(as.numeric(out), cyc), 0.95)
})

test_that("invalid filter arguments are rejected", {
  expect_error(cf_filter(32, 6), class = "rcli_error_argument")
  expect_error(bk_filter(k = 0), class = "rcli_error_argument")
  expect_error(hp_double_filter(12, 120), class = "rcli_error_argument")
  expect_error(hamilton_filter(h = 1.5), class = "rcli_error_argument")
  expect_error(extract_cycle(hp_filter(), 1:10),
               class = "rcli_error_argument")
  expect_error(extract_cycle(hp_filter(), ts(1:3, frequency = 4)),
               class = "rcli_error_short_series")
  expect_error(extract_cycle(bk_filter(), ts(1:20, frequency = 4)),
               class = "rcli_error_short_series")
  expect_error(extract_cycle(hamilton_filter(), ts(1:12, frequency = 4)),
               class = "rcli_error_short_series")
})

test_that("R8: the HP filter replicates mFilter at the monthly lambda", {
  skip_if_not_installed("mFilter")
  set.seed(8)
  xm <- ts(cumsum(rnorm(360)) + 100, frequency = 12, start = 1995)
  ours <- extract_cycle(hp_filter(129600), xm)
  ref <- mFilter::hpfilter(xm, freq = 129600, type = "lambda")$cycle
  expect_equal(as.numeric(ours), as.numeric(ref), tolerance = 1e-8)
  expect_error(hp_filter(Inf), class = "rcli_error_argument")
})
