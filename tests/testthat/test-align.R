# Frequency alignment (cli_align) and the native Denton-Cholette.

quarterly_of <- function(x, type) {
  rcli:::monthly_to_quarterly(x, type)
}

test_that("Denton-Cholette matches tempdisagg and keeps the constraint", {
  sim <- simulate_cycles(seed = 3, n_years = 15)
  m <- sim[, "reference"]
  for (tp in c("flow", "average", "stock")) {
    q <- quarterly_of(m, tp)
    x <- rcli:::denton_cholette(q, tp)
    expect_equal(frequency(x), 12)
    expect_equal(start(x), c(1995, 1))
    expect_equal(as.numeric(quarterly_of(x, tp)), as.numeric(q),
                 tolerance = 1e-8)
    skip_if_not_installed("tempdisagg")
    conv <- c(flow = "sum", average = "average", stock = "last")[[tp]]
    ref <- stats::predict(tempdisagg::td(q ~ 1, to = "monthly",
                                         conversion = conv,
                                         method = "denton-cholette"))
    expect_equal(as.numeric(x), as.numeric(ref), tolerance = 1e-8)
  }
})

test_that("monthly data are aggregated to quarters by type", {
  x <- ts(1:12, start = c(2000, 2), frequency = 12)   # Feb = 1, Apr = 3
  f <- quarterly_of(x, "flow")
  expect_equal(start(f), c(2000, 1))
  expect_equal(as.numeric(f), c(NA, 3 + 4 + 5, 6 + 7 + 8, 9 + 10 + 11, NA))
  expect_equal(as.numeric(quarterly_of(x, "stock"))[2:4], c(5, 8, 11))
  expect_equal(as.numeric(quarterly_of(x, "average"))[2], 4)
})

test_that("quarterly candidates are interpolated at the OECD month", {
  q <- ts(c(30, 60, 90), start = c(2000, 1), frequency = 4)
  flow <- rcli:::interpolate_quarterly(q, "flow", 2L)
  expect_equal(as.numeric(flow),
               c(10, 10, 40 / 3, 50 / 3, 20, 70 / 3, 80 / 3, 30, 30))
  stock <- rcli:::interpolate_quarterly(q, "stock", 3L)
  expect_equal(as.numeric(stock)[c(3, 6, 9)], c(30, 60, 90))
  expect_equal(as.numeric(stock)[4], 40)
  expect_error(rcli:::interpolate_quarterly(ts(1, frequency = 4), "flow",
                                            2L),
               class = "rcli_error_short_series")
})

test_that("weekly flows are spread over days, not counted by weeks", {
  # a constant flow of 7 per week is 1 per day: each month equals its days
  weeks <- seq(as.Date("2021-01-04"), as.Date("2021-12-27"), by = "week")
  x <- cli_align(list(w = data.frame(date = weeks, value = 7)),
                 type = c(w = "flow"))
  days <- c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
  expect_equal(as.numeric(x[1:12, "w"]), days, tolerance = 1e-10)
  expect_true(is.na(x[13, "w"]))        # 2 days of January 2022
  # the same weeks dated by their last day give the same months
  y <- cli_align(list(w = data.frame(date = weeks + 6, value = 7)),
                 type = c(w = "flow"), week_date = "end")
  expect_equal(as.numeric(y[1:12, "w"]), days, tolerance = 1e-10)
  avg <- cli_align(list(w = data.frame(date = weeks, value = 5)),
                   type = c(w = "average"))
  expect_true(all(abs(avg[1:12, "w"] - 5) < 1e-12))
  stk <- cli_align(list(w = data.frame(date = weeks, value = seq_along(weeks))),
                   type = c(w = "stock"))
  # the stock of a month is the last week ending in it
  expect_equal(as.numeric(stk[1, "w"]), 4)
})

test_that("daily data follow the type and the edge coverage rule", {
  d <- seq(as.Date("2020-01-01"), as.Date("2020-03-10"), by = "day")
  x <- cli_align(list(f = data.frame(date = d, value = 1),
                      a = data.frame(date = d, value = as.numeric(d)),
                      s = data.frame(date = d, value = seq_along(d))),
                 type = c(f = "flow", a = "average", s = "stock"))
  expect_equal(as.numeric(x[1:2, "f"]), c(31, 29))
  expect_true(is.na(x[3, "f"]))          # 10 of 31 days observed
  expect_equal(as.numeric(x[1, "a"]), mean(as.numeric(d[1:31])))
  expect_equal(as.numeric(x[1:2, "s"]), c(31, 60))
  # business-day data keep full months
  b <- d[!format(d, "%u") %in% c("6", "7")]
  y <- cli_align(list(b = data.frame(date = b, value = 2)),
                 type = c(b = "average"))
  expect_equal(as.numeric(y[1:2, "b"]), c(2, 2))
  # a partial edge flow is scaled to the whole period
  z <- cli_align(list(f = data.frame(date = d[-(1:5)], value = 1)),
                 type = c(f = "flow"))
  expect_equal(as.numeric(z[1, "f"]), 31, tolerance = 1e-10)
})

test_that("cli_align builds a candidate set with its record", {
  sim <- simulate_cycles(seed = 2, n_years = 12)
  q <- quarterly_of(sim[, "reference"], "flow")
  x <- cli_align(list(gdp = q, sim[, c("lead_6", "lead_3")]),
                 type = c(gdp = "flow"), reference = "gdp",
                 method = "linear")
  al <- attr(x, "alignment")
  expect_equal(al$name, c("gdp", "lead_6", "lead_3"))
  expect_equal(al$method[2], "none")
  expect_match(al$method[1], "quarterly to monthly (linear)", fixed = TRUE)
  meta <- data.frame(name = c("lead_6", "lead_3"), rationale = "early_stage",
                     type = c("flow", "average"))
  cand <- cli_candidates(x, reference = "gdp", meta = meta)
  expect_equal(cand@meta$type, c("flow", "average"))
  expect_equal(nrow(cand@alignment), 3)
  expect_null(attr(cand@data, "alignment"))
  expect_output(show(cand), "converted:")
  expect_output(show(cand), "gdp: quarterly to monthly")
  sub <- cand["lead_6"]
  expect_equal(sub@alignment$name, c("gdp", "lead_6"))
  expect_equal(rcli:::reference_conversion(cand)$name, "gdp")
  plain <- cli_candidates(sim, "reference",
                          meta = data.frame(name = colnames(sim)[-1],
                                            rationale = "early_stage"))
  expect_null(rcli:::reference_conversion(plain))
})

test_that("a quarterly CLI can be prepared from monthly series", {
  sim <- simulate_cycles(seed = 2, n_years = 12)
  x <- cli_align(list(sim[, c("reference", "lead_6")]), freq = 4,
                 type = c(reference = "flow", lead_6 = "average"))
  expect_equal(frequency(x), 4)
  expect_equal(as.numeric(x[1, "lead_6"]), mean(sim[1:3, "lead_6"]))
  expect_equal(as.numeric(x[1, "reference"]), sum(sim[1:3, "reference"]))
})

test_that("a disaggregated reference is flagged in the quality scorecard", {
  sim <- simulate_cycles(seed = 1)
  q <- quarterly_of(sim[, "reference"], "flow")
  x <- cli_align(list(reference = q, sim[, -1]), type = c(reference = "flow"),
                 reference = "reference")
  meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
  res <- cli_build(cli_candidates(x, "reference", meta = meta))
  ql <- cli_quality(res)
  expect_true("reference disaggregated from quarterly data" %in%
                ql@table$criterion)
  expect_match(ql@note, "uncertain by about one month")
  expect_setequal(leaders(res), c("lead_6", "lead_3", "counter_4"))
})

test_that("Chow-Lin needs tempdisagg and a monthly indicator", {
  sim <- simulate_cycles(seed = 4, n_years = 12)
  q <- quarterly_of(sim[, "reference"], "flow")
  expect_error(cli_align(list(gdp = q), type = c(gdp = "flow"),
                         reference = "gdp", method = "chow-lin"),
               class = "rcli_error_argument")
  skip_if_not_installed("tempdisagg")
  x <- cli_align(list(gdp = q), type = c(gdp = "flow"), reference = "gdp",
                 method = "chow-lin", indicator = sim[, "coincident"])
  expect_equal(as.numeric(quarterly_of(x[, "gdp"], "flow")), as.numeric(q),
               tolerance = 1e-6)
})

test_that("cli_align rejects unclear input", {
  q <- ts(1:8, start = 2000, frequency = 4)
  expect_error(cli_align(list(q)), class = "rcli_error_argument")
  expect_error(cli_align(list(a = q)), class = "rcli_error_argument")
  expect_error(cli_align(list(a = q), type = c(a = "level")),
               class = "rcli_error_argument")
  expect_error(cli_align(list(a = q), type = c(b = "flow")),
               class = "rcli_error_argument")
  expect_error(cli_align(list(a = q), type = c(a = "flow"), reference = "z"),
               class = "rcli_error_argument")
  expect_error(cli_align(list(a = ts(1:20, frequency = 52)),
                         type = c(a = "flow")),
               class = "rcli_error_frequency")
  expect_error(cli_align(list(a = data.frame(x = 1))),
               class = "rcli_error_argument")
  odd <- data.frame(date = as.Date("2020-01-01") + c(0, 15, 30), value = 1)
  expect_error(cli_align(list(a = odd), type = c(a = "flow")),
               class = "rcli_error_frequency")
  dup <- data.frame(date = as.Date("2020-01-01") + c(0, 0, 1), value = 1)
  expect_error(cli_align(list(a = dup), type = c(a = "flow")),
               class = "rcli_error_argument")
  expect_error(cli_align(list(a = q), type = c(a = "flow"),
                         position = c(a = 5)),
               class = "rcli_error_argument")
  expect_error(cli_candidates(
    cli_align(list(a = q, b = q * 2), type = c(a = "flow", b = "flow"),
              reference = "a"),
    "a", meta = data.frame(name = "b", rationale = "early_stage",
                           type = "level")),
    class = "rcli_error_argument")
})

test_that("monthly and quarterly data frames are read by their dates", {
  m <- data.frame(date = seq(as.Date("2020-01-15"), by = "month",
                             length.out = 6), value = 1:6)
  q <- data.frame(date = seq(as.Date("2020-02-15"), by = "3 months",
                             length.out = 4), value = 1:4)
  x <- cli_align(list(m = m, q = q), type = c(q = "average"))
  expect_equal(as.numeric(x[1:6, "m"]), 1:6)
  expect_equal(as.numeric(x[2, "q"]), 1)
})
