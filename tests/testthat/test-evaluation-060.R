# FR-012 (rcli 0.6.0): sign of a series, fixed-b tests, OECD conformity and
# out-of-sample prediction.

# a regular cycle of `period` months with slowly drifting phase
regular_cycles <- function(period, seed, n = 360, noise = 0.4) {
  set.seed(seed)
  t <- seq_len(n + 80)
  c0 <- sin(2 * pi * t / period + cumsum(stats::rnorm(length(t), 0, 0.02)))
  make <- function(shift, sgn = 1) {
    idx <- (41:(40 + n)) + shift
    idio <- as.numeric(stats::arima.sim(list(ar = 0.5), n)) * noise
    100 * exp(0.002 * seq_len(n) + 0.04 * (sgn * c0[idx] + idio))
  }
  stats::ts(cbind(reference = make(0), lead_6 = make(6), lead_3 = make(3),
                  counter_4 = make(4, -1)), start = 1995, frequency = 12)
}

meta_for <- function(x, ...) {
  data.frame(name = colnames(x)[-1], rationale = "early_stage", ...)
}

test_that("AC-FR-012.1: the sign can be declared in meta", {
  sim <- simulate_cycles(seed = 1)
  meta <- meta_for(sim, sign = NA_real_)
  meta$sign[meta$name == "counter_4"] <- -1
  meta$sign[meta$name == "lead_6"] <- 1
  cand <- cli_candidates(sim, "reference", meta = meta)
  tab <- assessment(cli_build(cand))@table
  expect_true("sign_source" %in% names(tab))
  src <- stats::setNames(tab$sign_source, tab$name)
  expect_equal(unname(src[c("counter_4", "lead_6", "lead_3")]),
               c("meta", "meta", "data"))
  expect_true(tab$inverted[tab$name == "counter_4"])
  # a declared sign is kept even when the data say otherwise
  meta2 <- meta_for(sim, sign = NA_real_)
  meta2$sign[meta2$name == "counter_4"] <- 1
  a2 <- cli_assess(cli_candidates(sim, "reference", meta = meta2),
                   cli_spec(12))
  row <- a2@table[a2@table$name == "counter_4", ]
  expect_false(row$inverted)
  expect_equal(row$sign_source, "meta")
  expect_false(row$class == "leading")
  bad <- meta_for(sim, sign = 2)
  expect_error(cli_candidates(sim, "reference", meta = bad),
               class = "rcli_error_argument")
})

test_that("AC-FR-012.2 (F-05): regular cycles keep their sign", {
  inv <- vapply(1:10, function(s) {
    x <- regular_cycles(48, s)
    a <- suppressWarnings(cli_assess(cli_candidates(x, "reference",
                                                    meta = meta_for(x)),
                                     cli_spec(12)))
    stats::setNames(a@table$inverted, a@table$name)[c("lead_6", "lead_3",
                                                      "counter_4")]
  }, logical(3))
  expect_false(any(inv["lead_6", ]))
  expect_false(any(inv["lead_3", ]))
  expect_true(all(inv["counter_4", ]))
  # the cross-correlation is reported at the positive peak
  x <- regular_cycles(48, 1)
  a <- cli_assess(cli_candidates(x, "reference", meta = meta_for(x)),
                  cli_spec(12))
  row <- a@table[a@table$name == "lead_6", ]
  expect_gt(row$ccf_r, 0)
  expect_true(row$ccf_lag >= 4 && row$ccf_lag <= 8)
  # the rule itself: strongest correlation within |k| <= K
  lags <- -24:24
  r <- 0.9 * cos(2 * pi * (lags - 6) / 48)
  r[lags == -18] <- -0.95
  expect_equal(rcli:::orient_sign(r, lags, k_max = 12), 1)
  expect_equal(rcli:::orient_sign(-r, lags, k_max = 12), -1)
  expect_equal(rcli:::orient_sign(r, lags, k_max = 24), -1)
  expect_true(is.na(rcli:::orient_sign(rep(NA_real_, 49), lags, 12)))
  # the lead is read within half a cycle: a 3-period lead on a 24-period
  # cycle, not the same phase 21 periods later (critic F-05, C1)
  sine <- function(shift) {
    stats::ts(sin(2 * pi * (seq_len(480) + shift) / 24), frequency = 12)
  }
  cc <- rcli:::cross_correlation(as.numeric(sine(3)), as.numeric(sine(0)),
                                 24, peak_max = 12)
  expect_equal(cc$lag, 3)
  tp <- date_turning_points(bry_boschan(), sine(0))
  expect_equal(rcli:::peak_lag_max(tp, cli_spec(12)), 12)
  # the sign window does not grow with min_lead (critic F-05, C2)
  tp48 <- date_turning_points(bry_boschan(), stats::ts(
    sin(2 * pi * seq_len(480) / 36), frequency = 12))
  expect_equal(rcli:::sign_lag_max(tp48, cli_spec(12, min_lead = 12)), 9)
  # simulated calibration data: the same signs as before
  for (s in 1:3) {
    sim <- simulate_cycles(seed = s)
    a <- cli_assess(cli_candidates(sim, "reference", meta = meta_for(sim)),
                    cli_spec(12))
    expect_equal(setdiff(a@inverted, c("noise_1", "noise_2")), "counter_4",
                 info = paste("seed", s))
  }
})

test_that("AC-FR-012.3 (F-06): fixed-b p-values", {
  tab <- rcli:::fixed_b_null
  expect_equal(attr(tab, "b"), 0.3)
  q95 <- stats::approx(tab$upper, tab$t, 0.05)$y
  expect_equal(rcli:::fixed_b_p(q95), 0.05, tolerance = 1e-6)
  expect_equal(rcli:::fixed_b_p(0), 0.5)
  expect_equal(rcli:::fixed_b_p(-q95), 0.95, tolerance = 1e-6)
  expect_equal(rcli:::fixed_b_p(100), min(tab$upper))
  # close to the Kiefer-Vogelsang (2005) response surface
  expect_equal(q95, 1.6449 + 2.1859 * 0.3 + 0.3142 * 0.09 - 0.3427 * 0.027,
               tolerance = 0.03)
  # size on persistent independent binary series
  set.seed(12)
  markov <- function(n, p) {
    s <- integer(n)
    s[1] <- stats::rbinom(1, 1, 0.5)
    for (t in 2:n) s[t] <- if (stats::runif(1) < p) 1L - s[t - 1] else s[t - 1]
    s
  }
  # (phases of about a year; for two-year phases the size is about 8%, see
  # inst/calibration/test-size.csv)
  p <- vapply(1:1000, function(k) {
    rcli:::hac_fixed_b_p(markov(360, 1 / 12), markov(360, 1 / 12))
  }, numeric(1))
  expect_lte(mean(p < 0.05), 0.08)
  # an exact fit is significant, not NA (critic F-06, C8)
  s <- markov(120, 1 / 12)
  expect_equal(rcli:::hac_fixed_b_p(s, s), min(tab$upper))
  # concordance() reports this one-sided test
  tp <- date_turning_points(bry_boschan(), sine_ts())
  lead <- date_turning_points(bry_boschan(), sine_ts(shift = -6))
  conc <- concordance(lead, tp, shift = 6)
  sx <- rcli:::shift_vec(as.numeric(cycle_states(lead)), 6L)
  sy <- as.numeric(cycle_states(tp))
  ok <- !is.na(sx) & !is.na(sy)
  expect_equal(conc$p_value, rcli:::hac_fixed_b_p(sy[ok], sx[ok]))
  expect_lt(conc$p_value, 0.01)
})

test_that("AC-FR-012.4: OECD classifier checks cyclical conformity", {
  expect_true(oecd_classifier()@conformity)
  spec <- cli_spec(12, classifier = oecd_classifier())
  row <- data.frame(n_ref = 10, n_matched = 8, missed = 2, extra = 1,
                    median_lead = 5, ccf_lag = 6, ccf_r = 0.6,
                    concordance = 0.8, concordance_expected = 0.5,
                    concordance_p = 0.001, pct_led = 0.8, granger_p = 0.01)
  expect_equal(classify_candidate(spec@classifier, row, spec)$class,
               "leading")
  bad <- row
  bad$ccf_r <- -0.3
  out <- classify_candidate(spec@classifier, bad, spec)
  expect_equal(out$class, "rejected")
  expect_match(out$reasons, "ccf")
  bad <- row
  bad$concordance_p <- 0.4
  expect_equal(classify_candidate(spec@classifier, bad, spec)$class,
               "rejected")
  bad <- row
  bad$extra <- 6
  expect_equal(classify_candidate(spec@classifier, bad, spec)$class,
               "rejected")
  # coincident and lagging series need conformity too
  co <- row
  co$median_lead <- 0
  expect_equal(classify_candidate(spec@classifier, co, spec)$class,
               "coincident")
  co$ccf_r <- -0.3
  expect_equal(classify_candidate(spec@classifier, co, spec)$class,
               "rejected")
  # the 0.5.1 rule, explicitly or from a classifier saved before 0.6.0
  old <- oecd_classifier(conformity = FALSE)
  bad <- row
  bad$ccf_r <- -0.3
  expect_equal(classify_candidate(old, bad, spec)$class, "leading")
  saved <- oecd_classifier()
  attr(saved, "conformity") <- NULL
  expect_equal(classify_candidate(saved, bad, spec)$class, "leading")
  expect_error(oecd_classifier(conformity = NA), class = "rcli_error_argument")
})

test_that("AC-FR-012.6 (F-07): recursive out-of-sample probabilities", {
  set.seed(3)
  n <- 120
  x <- cumsum(stats::rnorm(n))
  y <- as.numeric(rcli:::shift_vec(x, 2L) < 0)
  y[is.na(y)] <- 0
  h <- 2L
  out <- rcli:::recursive_logit(y, x, h)
  ok <- which(!is.na(x) & !is.na(y))
  t0 <- ok[ceiling(0.4 * length(ok))]
  expect_true(all(is.na(out$probability[seq_len(t0)])))
  t <- t0 + 15L
  train <- ok[ok <= t - h]
  fit <- suppressWarnings(stats::glm(y[train] ~ x[train],
                                     family = stats::binomial()))
  expect_equal(out$probability[t],
               unname(stats::plogis(sum(stats::coef(fit) * c(1, x[t])))),
               tolerance = 1e-6)
  expect_equal(out$naive[t], mean(y[train]))
  sim <- simulate_cycles(seed = 4)
  spec <- cli_spec(12)
  cyc <- cli_cycles(cli_candidates(sim, "reference", meta = meta_for(sim)),
                    spec)
  cli <- cli_composite(cyc, c("lead_6", "lead_3"), spec, cyc$reference)
  val <- cli_validate(cli, cyc$reference, spec)
  pr <- val@probability
  expect_true(all(c("qps", "qps_naive", "auc", "n_forecasts") %in% names(pr)))
  cp <- contraction_probability(cli, cyc$reference, spec)
  k <- !is.na(cp$probability)
  expect_equal(pr$n_forecasts, sum(k))
  expect_equal(pr$qps, 2 * mean((cp$probability[k] - cp$contraction[k])^2))
  expect_equal(pr$auc, rcli:::auc_score(cp$probability[k],
                                        cp$contraction[k]))
  ins <- contraction_probability(cli, cyc$reference, spec, recursive = FALSE)
  expect_gt(sum(!is.na(ins$probability)), sum(k))
})

test_that("AC-FR-012.7: Pesaran-Timmermann with fixed-b and a fixed horizon", {
  spec <- cli_spec(12)
  expect_equal(rcli:::validation_horizon(spec), 6)
  expect_equal(rcli:::validation_horizon(cli_spec(4)), 2)
  expect_equal(rcli:::validation_horizon(update(spec, horizon = 3)), 3)
  set.seed(8)
  ref <- as.numeric(stats::arima.sim(list(ar = c(1.8, -0.85)), 360))
  cli <- rcli:::shift_vec(ref, -6L) + stats::rnorm(360, 0, 0.3)
  pt <- rcli:::pesaran_timmermann(cli, ref, 6L)
  dx <- rcli:::shift_vec(c(NA, diff(cli)), 6L)
  dy <- c(NA, diff(ref))
  ok <- !is.na(dx) & !is.na(dy) & dx != 0 & dy != 0
  expect_equal(pt$p_value, rcli:::hac_fixed_b_p(as.numeric(dy[ok] > 0),
                                                as.numeric(dx[ok] > 0)))
  expect_lt(pt$p_value, 0.01)
  # size: independent smooth series, fixed horizon
  p <- vapply(1:150, function(k) {
    a <- as.numeric(stats::arima.sim(list(ar = c(1.8, -0.85)), 360))
    b <- as.numeric(stats::arima.sim(list(ar = c(1.8, -0.85)), 360))
    rcli:::pesaran_timmermann(a, b, 6L)$p_value
  }, numeric(1))
  expect_lte(mean(p < 0.05), 0.08)
})

test_that("AC-FR-012.9: the interface sets the sign and the OECD rule", {
  skip_if_not_installed("shiny")
  shiny::testServer(rcli:::app_server("id"), {
    session$setInputs(source = "example_m", seed = 1, freq = "auto",
                      start = "", run1 = 1)
    session$setInputs(reference = "reference")
    cands <- setdiff(colnames(rv$data), "reference")
    k <- match("counter_4", cands)
    inputs <- stats::setNames(as.list(rep("early_stage", length(cands))),
                              paste0("rat_", seq_along(cands)))
    do.call(session$setInputs, inputs)
    do.call(session$setInputs, stats::setNames(list("-1"),
                                               paste0("sgn_", k)))
    session$setInputs(run2 = 1)
    expect_equal(rv$cand@meta$sign[rv$cand@meta$name == "counter_4"], -1)
    expect_true(all(is.na(rv$cand@meta$sign[rv$cand@meta$name !=
                                                "counter_4"])))
    session$setInputs(method = "rcli", filter = "hp_double",
                      aggregator = "equal", extend = TRUE, transform = "auto",
                      seasonal = FALSE, outlier = 5, min_lead = 3,
                      min_median_lead = 1, min_consistency = 0.5,
                      max_missed = 0.4, max_extra = 0.4, alpha = 0.05,
                      min_auc = 0.7, min_components = 2, max_iter = 10,
                      oos_cutoffs = "", classifier = "oecd_median",
                      run3 = 1)
    expect_false(rv$spec@classifier@conformity)
    session$setInputs(classifier = "rcli", run3 = 2)
    session$setInputs(run4 = 1)
    session$setInputs(cyc_series = "lead_6", tp_series = "reference",
                      as_series = "lead_6", run5 = 1)
    session$setInputs(run6 = 1)
    expect_match(output$assess_table, "kontrasiklis (dinyatakan)",
                 fixed = TRUE)
    expect_match(output$assess_table, "prosiklis", fixed = TRUE)
    session$setInputs(comp_mode = "auto", run7 = 1)
    script <- script()
    expect_match(script, "sign = c(NA, NA, NA, NA, -1, NA, NA)",
                 fixed = TRUE)
    env <- new.env()
    utils::capture.output(eval(parse(text = script), envir = env))
    expect_equal(env$cand@meta$sign, rv$cand@meta$sign)
    expect_equal(components(env$res), rv$composite@components)
    # the OECD method with and without the conformity criteria
    session$setInputs(method = "oecd", oecd_conformity = FALSE, run3 = 3)
    expect_false(rv$spec@classifier@conformity)
    session$setInputs(oecd_conformity = TRUE, run3 = 4)
    expect_true(rv$spec@classifier@conformity)
  })
})

test_that("AC-FR-012.5 and .8: calibration evidence of 0.6.0", {
  read_cal <- function(f) {
    utils::read.csv(system.file("calibration", f, package = "rcli"))
  }
  lw <- read_cal("lead-window.csv")
  expect_setequal(unique(lw$window), c("asymmetric", "symmetric"))
  # the default window is the asymmetric one of the study
  expect_equal(cli_spec(12)@lead_window, c(12, 24))
  expect_equal(cli_spec(4)@lead_window, c(4, 8))
  acc <- read_cal("accuracy.csv")
  expect_lte(max(acc$false_leading), 0.015)
  cmp <- read_cal("oecd-classification.csv")
  key <- paste(cmp$freq, cmp$noise_sd)
  conf <- cmp[cmp$rule == "OECD (min 3 matched)", ]
  med <- cmp[cmp$rule == "OECD (median lead only)", ]
  med <- med[match(paste(conf$freq, conf$noise_sd),
                   paste(med$freq, med$noise_sd)), ]
  expect_true(all(conf$false_leading <= med$false_leading / 2))
  drop <- med$leading_found - conf$leading_found
  expect_true(all(drop[conf$noise_sd == 0.2] <= 0.01))
  expect_true(all(drop <= 0.12))
  oe <- lw[lw$classifier == "oecd" & lw$window == "asymmetric", ]
  expect_true(all(oe$false_leading <= 0.1))
})

test_that("review 0.6.0: declared signs, idempotence, short forecasts", {
  sim <- simulate_cycles(seed = 1)
  meta <- meta_for(sim, sign = c(NA, NA, NA, NA, -1, NA, NA))
  cand <- cli_candidates(sim, "reference", meta = meta)
  res <- cli_build(cand)
  again <- cli_assess(cand, res@spec, cycles(res))@table
  first <- assessment(res)@table
  expect_equal(again$class, first$class)
  expect_equal(again$ccf_lag, first$ccf_lag)
  # factor signs keep their values
  meta$sign <- factor(meta$sign)
  expect_equal(cli_candidates(sim, "reference", meta = meta)@meta$sign,
               c(NA, NA, NA, NA, -1, NA, NA))
  # the scorecard counts the out-of-sample forecasts
  q <- cli_quality(res)@table
  expect_true("out-of-sample forecasts" %in% q$criterion)
  spec_far <- update(res@spec, horizon = 340)
  v <- cli_validate(res@composite, cycles(res)$reference, spec_far)
  row <- v@quality@table[v@quality@table$criterion ==
                           "out-of-sample forecasts", ]
  expect_false(row$passed)
  # the selection loop does not compute the prediction group, the result
  # does
  expect_false(is.na(validation(res)@probability$auc))
})
