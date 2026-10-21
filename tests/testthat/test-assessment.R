test_that("matching recovers a known lead", {
  ref <- date_turning_points(bry_boschan(), sine_ts(shift = 0), name = "ref")
  cand <- date_turning_points(bry_boschan(), sine_ts(shift = -6), name = "c")
  m <- rcli:::match_turning_points(ref, cand, c(12, 24), 6)
  expect_true(all(m$pairs$lead[!is.na(m$pairs$lead)] == 6))
  expect_equal(m$n_extra, 0)
})

test_that("concordance of identical cycles is 1 and significant", {
  tp <- date_turning_points(bry_boschan(), sine_ts())
  conc <- concordance(tp, tp)
  expect_equal(conc$index, 1)
  expect_lt(conc$p_value, 1e-6)
  lead <- date_turning_points(bry_boschan(), sine_ts(shift = -6))
  expect_equal(concordance(lead, tp, shift = 6)$index, 1, tolerance = 0.05)
  short <- date_turning_points(bbq(), ts(1:5, frequency = 4))
  expect_true(is.na(concordance(short, short)$index))
})

test_that("cross-correlation finds the lead", {
  a <- as.numeric(sine_ts(shift = -5))
  b <- as.numeric(sine_ts())
  cc <- rcli:::cross_correlation(a, b, 12)
  expect_equal(cc$lag, 5)
  expect_gt(cc$r, 0.99)
  expect_true(is.na(rcli:::cross_correlation(1:10, 1:10, 2)$lag))
})

test_that("Toda-Yamamoto test detects Granger causality", {
  set.seed(5)
  n <- 300
  x <- as.numeric(arima.sim(list(ar = 0.7), n))
  y <- 0.8 * rcli:::shift_vec(x, 3) + rnorm(n, 0, 0.3)
  y[1:3] <- rnorm(3)
  expect_lt(rcli:::toda_yamamoto_p(x, y, 6, 1), 1e-6)
  z <- as.numeric(arima.sim(list(ar = 0.7), n))
  expect_gt(rcli:::toda_yamamoto_p(z, y, 6, 1), 0.01)
  expect_true(is.na(rcli:::toda_yamamoto_p(z[1:20], y[1:20], 6, 1)))
})

test_that("classification recovers the simulated truth", {
  cand <- sim_candidates(seed = 2, noise_sd = 0.2)
  a <- cli_assess(cand, cli_spec(12))
  truth <- attr(cand, "truth")
  tab <- as.data.frame(a)
  expect_equal(tab$class, truth$class[match(tab$name, truth$name)])
  expect_equal(a@inverted[1], "counter_4")
  expect_setequal(leaders(a), c("lead_6", "lead_3", "counter_4"))
  expect_true(all(tab$reasons[tab$class == "leading"] == ""))
  expect_true(all(nzchar(tab$reasons[tab$class != "leading"])))
})

test_that("classification works on quarterly data", {
  cand <- sim_candidates(seed = 3, freq = 4, noise_sd = 0.2)
  a <- cli_assess(cand, cli_spec(4))
  expect_true(all(c("lead_2", "lead_1") %in% leaders(a)))
  expect_false(any(c("noise_1", "noise_2") %in% leaders(a)))
})

test_that("assessments print", {
  a <- cli_assess(sim_candidates(seed = 2, noise_sd = 0.2), cli_spec(12))
  expect_snapshot(a)
  expect_output(summary(a), "LeadAssessment")
})
