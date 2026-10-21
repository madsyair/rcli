test_that("cycles are computed for every series with a log of steps", {
  cand <- sim_candidates(seed = 2)
  cyc <- cli_cycles(cand, cli_spec(12))
  expect_named(cyc, colnames(cand@data))
  cs <- cyc$lead_6
  expect_s4_class(cs, "CycleSeries")
  expect_true("log" %in% cs@steps)
  expect_equal(mean(cs@normalised), 0, tolerance = 1e-10)
  expect_equal(mean(abs(cs@normalised)), 1, tolerance = 1e-10)
})

test_that("ragged edges, gaps and non-positive series are handled", {
  sim <- simulate_cycles(seed = 3, n_years = 15)
  sim[1:24, "lead_6"] <- NA
  sim[100, "lead_3"] <- NA
  sim[, "lag_3"] <- sim[, "lag_3"] - 200
  meta <- data.frame(name = colnames(sim)[-1], rationale = "rapid_response")
  cand <- cli_candidates(sim, "reference", meta = meta)
  cyc <- cli_cycles(cand, cli_spec(12))
  expect_true(all(is.na(cyc$lead_6@cycle[1:24])))
  expect_false(anyNA(cyc$lead_6@cycle[25:180]))
  expect_true("interpolated internal gaps" %in% cyc$lead_3@steps)
  expect_true("levels (no log)" %in% cyc$lag_3@steps)
  expect_error(cli_cycles(cand, cli_spec(12, transform = "log")),
               class = "rcli_error_transform")
})

test_that("isolated spikes are replaced", {
  sim <- simulate_cycles(seed = 4, n_years = 12)
  sim[60, "lead_3"] <- sim[60, "lead_3"] * 3
  meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
  cyc <- cli_cycles(cli_candidates(sim, "reference", meta = meta), cli_spec(12))
  expect_true(any(grepl("outlier", cyc$lead_3@steps)))
  cyc2 <- cli_cycles(cli_candidates(sim, "reference", meta = meta),
                     cli_spec(12, outlier_threshold = Inf))
  expect_false(any(grepl("outlier", cyc2$lead_3@steps)))
})

test_that("input problems are reported", {
  cand <- sim_candidates(seed = 1)
  expect_error(cli_cycles(cand, cli_spec(4)), class = "rcli_error_frequency")
  expect_error(cli_cycles(cand, list()), class = "rcli_error_argument")
  expect_error(cli_cycles(list(), cli_spec()), class = "rcli_error_argument")
  short <- simulate_cycles(seed = 1, n_years = 10)
  short[1:100, "lead_6"] <- NA
  meta <- data.frame(name = colnames(short)[-1], rationale = "early_stage")
  expect_error(cli_cycles(cli_candidates(short, "reference", meta = meta),
                          cli_spec(12)),
               class = "rcli_error_short_series")
})

test_that("X-13 seasonal adjustment removes a seasonal pattern", {
  skip_on_cran()
  skip_if_not_installed("seasonal")
  sim <- simulate_cycles(seed = 1, n_years = 12)
  season <- 1 + 0.05 * sin(2 * pi * cycle(sim) / 12)
  sim[, "lead_3"] <- sim[, "lead_3"] * season
  meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
  cand <- cli_candidates(sim, "reference", meta = meta)
  raw <- cli_cycles(cand, cli_spec(12))$lead_3
  adj <- cli_cycles(cand, cli_spec(12, seasonal_adjust = TRUE))$lead_3
  expect_true("seasonally adjusted (X-13ARIMA-SEATS)" %in% adj@steps)
  expect_lt(which(adj@steps == "seasonally adjusted (X-13ARIMA-SEATS)"),
            which(adj@steps == "log"))
  seas_amp <- function(v) {
    d <- diff(as.numeric(v))
    sd(tapply(d, cycle(v)[-1], mean))
  }
  expect_lt(seas_amp(adj@transformed), seas_amp(raw@transformed) / 2)
})

test_that("seasonal adjustment needs the seasonal package", {
  skip_if(requireNamespace("seasonal", quietly = TRUE))
  cand <- sim_candidates(seed = 1)
  expect_error(cli_cycles(cand, cli_spec(12, seasonal_adjust = TRUE)),
               class = "rcli_error_dependency")
})

test_that("cycle series print and plot", {
  cyc <- cli_cycles(sim_candidates(seed = 1), cli_spec(12))
  expect_snapshot(cyc$lead_6)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  expect_invisible(plot(cyc$lead_6))
})
