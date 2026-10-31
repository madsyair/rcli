# Specification of the OECD options (rcli 0.1.3), following Gyomai and
# Guidetti (2012), "OECD System of Composite Leading Indicators":
#
# * Classification (p. 9): by the median lead/lag at turning points;
#   coincident within +/- 2 months, leading from 2 months (shorter/medium
#   up to 8, longer over 8), lagging at -2 months or less. Thresholds are
#   in months and converted to periods (x freq / 12).
# * Aggregation (p. 9): average the growth rates of the components, chain
#   the average growth into the index; a date is computed only when at least
#   60 percent of the components are available. Components are the
#   normalised cycles plus 100 (p. 7).
# * Lag-shifting (p. 9): components are lagged so that their leads align;
#   here every component is moved later by (its median lead - the shortest
#   median lead), rounded to whole periods.
# * Outliers (p. 6-7): TRAMO detects additive outliers, transitory changes
#   and level shifts and the outliers are replaced by estimated values;
#   TRAMO also decides log or levels and gives short-horizon forecasts that
#   extend the series before the HP filter.
# * Presentation (p. 9-11): amplitude-adjusted CLI, trend-restored CLI
#   (trend of the reference times the amplitude-adjusted CLI / 100) and its
#   12-month rate of change.

spec <- cli_spec(12)
cyc <- cli_cycles(sim_candidates(seed = 1), spec)
comps <- c("lead_6", "lead_3")

row_with <- function(median_lead, n_matched = 5) {
  data.frame(name = "x", n_ref = 6, n_matched = n_matched, missed = 1,
             extra = 0, median_lead = median_lead, mean_lead = median_lead,
             sd_lead = 1, pct_led = 0.8, ccf_lag = median_lead, ccf_r = 0.7,
             concordance = 0.8, concordance_expected = 0.5,
             concordance_p = 0.01, granger_p = 0.01)
}

test_that("the OECD classifier follows the median-lead table", {
  s <- update(spec, classifier = oecd_classifier())
  cls <- function(l, ...) rcli:::classify_row(row_with(l, ...), s)$class
  expect_equal(cls(6), "leading")
  expect_equal(cls(2), "leading")
  expect_equal(cls(12), "leading")
  expect_equal(cls(1.5), "coincident")
  expect_equal(cls(0), "coincident")
  expect_equal(cls(-1.5), "coincident")
  expect_equal(cls(-2), "lagging")
  expect_equal(cls(-7), "lagging")
  expect_equal(cls(6, n_matched = 2), "rejected")
  expect_equal(cls(NA), "rejected")
  expect_match(rcli:::classify_row(row_with(12), s)$reasons, "longer")
  expect_equal(rcli:::classify_row(row_with(5), s)$reasons, "")
})

test_that("OECD thresholds are in months and follow the frequency", {
  sq <- cli_spec(4, classifier = oecd_classifier())
  cls <- function(l) rcli:::classify_row(row_with(l), sq)$class
  expect_equal(cls(1), "leading")       # 3 months
  expect_equal(cls(0.5), "coincident")  # 1.5 months
  expect_equal(cls(-1), "lagging")
  expect_error(oecd_classifier(coincident = -1), class = "rcli_error_argument")
  expect_error(oecd_classifier(coincident = 9, long = 8),
               class = "rcli_error_argument")
})

test_that("the default classifier is unchanged", {
  expect_s4_class(spec@classifier, "RcliClassifier")
  r <- row_with(6)
  expect_equal(rcli:::classify_row(r, spec)$class, "leading")
  r$granger_p <- 0.5
  expect_equal(rcli:::classify_row(r, spec)$class, "rejected")
  expect_equal(rcli:::classify_row(r, update(spec,
    classifier = oecd_classifier()))$class, "leading")
})

test_that("OECD aggregation chains the average growth of the components", {
  s <- update(spec, aggregator = oecd_aggregate())
  z <- cbind(a = c(1, 2, 1, 0), b = c(0, 1, 3, 2))
  out <- aggregate_components(s@aggregator, z, NULL, s)
  lv <- z + 100
  g <- rowMeans(lv[-1, ] / lv[-4, ] - 1)
  expect_equal(out$cycle, 100.5 * cumprod(c(1, 1 + g)))
  expect_equal(unname(out$weights), c(0.5, 0.5))
  # identical components: the chained index reproduces the component
  same <- cbind(a = c(1, 2, 1, 0), b = c(1, 2, 1, 0))
  expect_equal(aggregate_components(s@aggregator, same, NULL, s)$cycle,
               c(1, 2, 1, 0) + 100)
})

test_that("OECD aggregation uses available growth rates at a ragged edge", {
  s <- update(spec, aggregator = oecd_aggregate())
  z <- cbind(a = c(0, 1, 2, 3), b = c(0, 1, 2, 3), c = c(0, 1, 2, NA))
  out <- aggregate_components(s@aggregator, z, NULL, s)$cycle
  expect_equal(out[4] / out[3], 103 / 102)
  # below 60 percent coverage the index is missing; chaining resumes
  z2 <- cbind(a = c(0, 1, NA, 3, 4), b = c(0, 1, NA, NA, 4),
              c = c(0, 1, NA, 3, 4))
  out2 <- aggregate_components(s@aggregator, z2, NULL, s)$cycle
  expect_true(is.na(out2[3]))
  expect_false(is.na(out2[4]))
  expect_equal(out2[5] / out2[4], 104 / 103)
  expect_true(all(is.na(aggregate_components(
    s@aggregator, cbind(a = c(NA, 1), b = c(NA, NA)), NULL, s)$cycle)))
})

test_that("cli_composite applies lag shifts", {
  ci <- cli_composite(cyc, comps, spec, shifts = c(lead_6 = 3, lead_3 = 0))
  z6 <- as.numeric(cyc$lead_6@normalised)
  z3 <- as.numeric(cyc$lead_3@normalised)
  manual <- rowMeans(cbind(rcli:::shift_vec(z6, 3L), z3))
  expect_equal(as.numeric(ci@cycle), rcli:::normalise_cycle(manual))
  expect_equal(ci@shifts, c(lead_6 = 3, lead_3 = 0))
  expect_error(cli_composite(cyc, comps, spec, shifts = c(lead_6 = -1)),
               class = "rcli_error_argument")
  expect_length(cli_composite(cyc, comps, spec)@shifts, 0L)
})

test_that("lag shifts align the median leads in cli_build", {
  cand <- sim_candidates(seed = 1)
  res <- cli_build(cand, update(spec, lag_shift = TRUE))
  sh <- res@composite@shifts
  tab <- res@assessment@table
  lead <- tab$median_lead[match(res@composite@components, tab$name)]
  expect_equal(unname(sh), round(lead - min(lead)))
  expect_equal(min(sh), 0)
  expect_match(paste(capture.output(res@composite), collapse = " "),
               "shift")
})

test_that("robust outliers keep the 0.1.1 behaviour", {
  x <- ts(sin(1:120 / 6) + 10, frequency = 12)
  x[60] <- x[60] + 5
  out <- treat_outliers(robust_outliers(5), x)
  expect_equal(out$n, 1L)
  expect_length(out$forecast, 0L)
  expect_equal(cli_spec(12, outlier_threshold = 3)@outliers@threshold, 3)
  expect_equal(update(spec, outlier_threshold = 4)@outliers@threshold, 4)
  expect_error(robust_outliers(0), class = "rcli_error_argument")
})

test_that("TRAMO-type outliers are removed with X-13 regARIMA", {
  skip_if_not_installed("seasonal")
  skip_on_cran()
  set.seed(3)
  x <- ts(log(100 + 10 * sin(2 * pi * (1:180) / 50)) +
            cumsum(rnorm(180, 0, 0.003)), frequency = 12, start = 2000)
  y <- x
  y[90] <- y[90] + 0.15
  out <- treat_outliers(tramo_outliers(engine = "x13", forecast = 12), y)
  expect_gte(out$n, 1L)
  expect_lt(abs(out$x[90] - x[90]), 0.05)
  expect_length(out$forecast, 12L)
  expect_match(out$step, "X-13")
  keep <- treat_outliers(tramo_outliers(engine = "x13", remove = "LS",
                                        forecast = 0), y)
  expect_equal(as.numeric(keep$x)[90], as.numeric(y)[90], tolerance = 1e-6)
  expect_length(keep$forecast, 0L)
})

test_that("TRAMO engine runs through RJDemetra when installed", {
  skip_if_not_installed("RJDemetra")
  skip_on_cran()
  set.seed(3)
  x <- ts(log(100 + 10 * sin(2 * pi * (1:180) / 50)) +
            cumsum(rnorm(180, 0, 0.003)), frequency = 12, start = 2000)
  x[90] <- x[90] + 0.15
  out <- treat_outliers(tramo_outliers(engine = "tramo", forecast = 6), x)
  expect_gte(out$n, 1L)
  expect_length(out$forecast, 6L)
  expect_match(out$step, "TRAMO")
  expect_true(rcli:::log_test(exp(x), "tramo"))
})

test_that("engine auto falls back to X-13 without RJDemetra", {
  local_mocked_bindings(has_rjdemetra = function() FALSE,
                        has_seasonal = function() TRUE)
  expect_equal(rcli:::resolve_engine("auto"), "x13")
  expect_error(rcli:::resolve_engine("tramo"),
               class = "rcli_error_dependency")
  local_mocked_bindings(has_rjdemetra = function() TRUE)
  expect_equal(rcli:::resolve_engine("auto"), "tramo")
})

test_that("a failed regARIMA fit falls back with a warning", {
  x <- ts(cumsum(rnorm(60)), frequency = 12)
  expect_warning(out <- rcli:::regarima_failed(x, 6),
                 class = "rcli_warning_outliers")
  expect_true(all(out$effects == 0))
  expect_length(out$forecast, 6L)
  expect_equal(sum(out$count), 0)
  skip_if_not_installed("seasonal")
  local_mocked_bindings(seas = function(...) stop("no convergence"),
                        .package = "seasonal")
  expect_warning(f <- rcli:::regarima_x13(x, 3, NA),
                 class = "rcli_warning_outliers")
  expect_length(f$forecast, 3L)
})

test_that("tramo_outliers validates its arguments", {
  expect_error(tramo_outliers(remove = "XX"), class = "rcli_error_argument")
  expect_error(tramo_outliers(forecast = -1), class = "rcli_error_argument")
  expect_error(tramo_outliers(critical = 0), class = "rcli_error_argument")
  expect_s4_class(tramo_outliers(), "TramoOutliers")
})

test_that("forecasts extend the series before the cycle filter", {
  skip_if_not_installed("seasonal")
  skip_on_cran()
  cand <- sim_candidates(seed = 2)
  s <- update(spec, outliers = tramo_outliers(engine = "x13", forecast = 12))
  cs <- cli_cycles(cand, s)$lead_6
  expect_true(any(grepl("12-period forecasts", cs@steps)))
  expect_equal(length(cs@cycle), length(cand@data[, "lead_6"]))
})

test_that("transform = 'test' lets the regARIMA test choose logs", {
  skip_if_not_installed("seasonal")
  skip_on_cran()
  ap <- AirPassengers
  expect_true(rcli:::log_test(ap, "x13"))
  out <- rcli:::apply_transform(ap, "test", "ap")
  expect_match(attr(out, "step"), "log")
  neg <- ts(sin(1:120 / 5), frequency = 12)
  expect_match(attr(rcli:::apply_transform(neg, "test", "neg"), "step"),
               "levels")
})

test_that("oecd_spec bundles the OECD choices", {
  s <- oecd_spec(12)
  expect_s4_class(s@classifier, "OecdClassifier")
  expect_s4_class(s@aggregator, "OecdAggregate")
  expect_s4_class(s@outliers, "TramoOutliers")
  expect_true(s@lag_shift)
  expect_equal(s@transform, "test")
  expect_s4_class(s@filter, "HPDoubleFilter")
  expect_equal(s@min_median_lead, 2)
  expect_equal(oecd_spec(4)@min_median_lead, 2 / 3)
  expect_equal(oecd_spec(12, max_iter = 3)@max_iter, 3)
  expect_output(show(s), "OECD")
})

test_that("cli_build runs with the OECD classifier and aggregation", {
  cand <- sim_candidates(seed = 1)
  s <- update(spec, classifier = oecd_classifier(),
              aggregator = oecd_aggregate(), lag_shift = TRUE)
  res <- cli_build(cand, s)
  expect_s4_class(res, "CliResult")
  expect_true("lead_6" %in% leaders(res))
  q <- cli_quality(res)
  expect_true(any(grepl("median lead", q@table$criterion)))
  expect_false(any(grepl("Granger", q@table$criterion)))
})

test_that("cli_presentation gives the three OECD forms", {
  cand <- sim_candidates(seed = 1)
  res <- cli_build(cand)
  pr <- cli_presentation(res)
  expect_named(pr, c("time", "amplitude_adjusted", "trend_restored",
                     "rate_of_change", "reference",
                     "reference_amplitude_adjusted", "reference_trend",
                     "reference_rate_of_change"))
  expect_equal(pr$reference_amplitude_adjusted,
               100 * pr$reference / pr$reference_trend)
  comp <- res@composite
  expect_equal(pr$amplitude_adjusted,
               100 + as.numeric(comp@cycle) * comp@amplitude)
  ok <- !is.na(pr$trend_restored) & !is.na(pr$reference_trend)
  expect_equal(pr$trend_restored[ok],
               pr$reference_trend[ok] * pr$amplitude_adjusted[ok] / 100)
  i <- which(!is.na(pr$trend_restored))
  i <- i[i > 12][1]
  expect_equal(pr$rate_of_change[i],
               100 * (pr$trend_restored[i] / pr$trend_restored[i - 12] - 1))
  # the trend is extended to the end of the composite
  last_cli <- max(which(!is.na(pr$amplitude_adjusted)))
  expect_false(is.na(pr$trend_restored[last_cli]))
  expect_error(cli_presentation(1), class = "rcli_error_argument")
})

test_that("R3/R4: the forms of a reference that is not logged", {
  # a balance that crosses zero is not logged
  sim <- simulate_cycles(seed = 4, n_years = 20)
  bal <- sim
  bal[, "reference"] <- sim[, "reference"] - mean(sim[, "reference"])
  meta <- data.frame(name = colnames(bal)[-1], rationale = "early_stage")
  res <- cli_build(cli_candidates(bal, "reference", meta = meta),
                   cli_spec(12, transform = "none"))
  pr <- cli_presentation(res)
  ref <- cycles(res)$reference
  expect_false(rcli:::is_logged(ref))
  scale <- mean(abs(as.numeric(ref@transformed)), na.rm = TRUE)
  ok <- !is.na(pr$trend_restored)
  expect_equal(pr$trend_restored[ok], pr$reference_trend[ok] +
                 (pr$amplitude_adjusted[ok] - 100) / 100 * scale)
  expect_equal(pr$reference_amplitude_adjusted,
               100 + 100 * (pr$reference - pr$reference_trend) / scale)
  # the de-trended reference is on the scale of the composite (the old
  # ratio to a trend near zero ran into the thousands)
  ratio <- stats::sd(pr$reference_amplitude_adjusted, na.rm = TRUE) /
    stats::sd(pr$amplitude_adjusted, na.rm = TRUE)
  expect_true(ratio > 0.5 && ratio < 2)
})
