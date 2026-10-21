check_censoring <- function(tp, n) {
  r <- tp@params
  idx <- tp@index
  if (length(idx) == 0L) return(invisible(TRUE))
  expect_true(all(idx > r$end_exclusion & idx <= n - r$end_exclusion))
  if (length(idx) > 1L) {
    expect_true(all(diff(idx) >= r$min_phase))
    expect_false(any(tp@type[-1] == tp@type[-length(tp@type)]))
  }
  for (ty in c("peak", "trough")) {
    same <- idx[tp@type == ty]
    if (length(same) > 1L) expect_true(all(diff(same) >= r$min_cycle))
  }
}

test_that("turning points of a sine wave are exact", {
  x <- sine_ts(n = 240, period = 48)
  tp <- date_turning_points(bry_boschan(), x)
  expect_equal(tp@index[tp@type == "peak"], c(12L, 60L, 108L, 156L, 204L))
  expect_equal(tp@index[tp@type == "trough"], c(36L, 84L, 132L, 180L, 228L))
})

test_that("censoring rules hold on random walks", {
  for (s in 1:15) {
    set.seed(s)
    xm <- ts(cumsum(rnorm(240)), frequency = 12)
    xq <- ts(cumsum(rnorm(120)), frequency = 4)
    check_censoring(date_turning_points(bry_boschan(), xm), 240)
    check_censoring(date_turning_points(bbq(), xq), 120)
  }
})

test_that("BBQ replicates BCDating (golden file)", {
  golden <- readRDS(test_path("fixtures", "bcdating_bbq.rds"))
  same <- 0L
  for (g in golden) {
    y <- ts(g$y, frequency = 4, start = 1980)
    tp <- date_turning_points(bbq(), y)
    ref <- sort(c(g$peaks, g$troughs))
    if (identical(as.integer(ref), tp@index)) {
      same <- same + 1L
    } else {
      # differences come from BCDating keeping the earlier of two close
      # turning points; rcli keeps the more extreme one
      ours_p <- tp@index[tp@type == "peak"]
      ref_p <- g$peaks
      expect_gte(max(g$y[ours_p]), max(g$y[ref_p]) - 1e-8)
      expect_lte(abs(length(tp@index) - length(ref)), 2)
    }
  }
  expect_gte(same, 45L)
})

test_that("Bry-Boschan matches Coinprofile on a smooth monthly series", {
  skip_if_not_installed("Coinprofile")
  set.seed(7)
  n <- 300
  y <- 100 + 5 * sin(2 * pi * (1:n) / 50) + cumsum(rnorm(n, 0, 0.2))
  ref <- Coinprofile::TP_BryBoschan(y, frequ = 12, year = 2000, month = 1)
  tp <- date_turning_points(bry_boschan(), ts(y, frequency = 12, start = 2000))
  expect_equal(tp@index, as.integer(ref$Time))
})

test_that("constant and missing series give no turning points", {
  expect_length(date_turning_points(bbq(), ts(rep(1, 40), frequency = 4))@index,
                0L)
  expect_length(date_turning_points(bbq(), ts(rep(NA_real_, 40),
                                              frequency = 4))@index, 0L)
  x <- ts(c(rep(NA, 10), sin(2 * pi * (1:100) / 20), rep(NA, 5)), frequency = 4)
  tp <- date_turning_points(bbq(), x)
  expect_true(all(tp@index > 10 & tp@index <= 110))
  x[50] <- NA
  expect_error(date_turning_points(bbq(), x), class = "rcli_error_missing")
})

test_that("cycle states follow the turning points", {
  x <- sine_ts(n = 120, period = 40, freq = 12)
  tp <- date_turning_points(bry_boschan(), x)
  s <- as.numeric(cycle_states(tp))
  expect_equal(s[1:10], rep(1, 10))
  expect_equal(s[11], 0)
  expect_equal(s[30], 0)
  expect_equal(s[31], 1)
  expect_error(cycle_states(1:3), class = "rcli_error_argument")
  empty <- date_turning_points(bbq(), ts(rep(1, 20), frequency = 4))
  expect_true(all(is.na(cycle_states(empty))))
})

test_that("dater arguments and defaults", {
  expect_s4_class(bry_boschan(), "BryBoschan")
  expect_error(bbq(window = 0), class = "rcli_error_argument")
  expect_equal(rcli:::resolve_dater(bbq(min_cycle = 6), 4)$min_cycle, 6)
  expect_equal(rcli:::resolve_dater(bry_boschan(), 12)$min_cycle, 15)
  expect_error(new("TurningPoints", name = "x", series = ts(1:3),
                   index = c(2L, 1L), type = c("peak", "trough")),
               "increasing")
  expect_error(new("TurningPoints", name = "x", series = ts(1:3),
                   index = c(1L, 2L), type = c("peak", "peak")),
               "alternate")
})

test_that("turning points convert to a data frame", {
  tp <- date_turning_points(bry_boschan(), sine_ts())
  df <- as.data.frame(tp)
  expect_named(df, c("time", "period", "type", "index", "value"))
  expect_equal(df$period[1], "2000-12")
})
