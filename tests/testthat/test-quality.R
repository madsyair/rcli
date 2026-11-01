cand <- sim_candidates(seed = 1)

test_that("verdicts follow the three groups of criteria", {
  acc <- cli_quality(cli_build(cand))
  expect_s4_class(acc, "CliQuality")
  expect_equal(acc@verdict, "acceptable")
  expect_setequal(unique(acc@table$group),
                  c("turning points", "prediction", "information"))
  good <- cli_quality(cli_build(cand, cli_spec(12, oos_cutoffs = c(2008, 2016))))
  expect_equal(good@verdict, "good")
  expect_true("out of sample" %in% good@table$group)
  expect_true(all(is.na(good@table$passed[good@table$group == "information"])))
})

test_that("a selection effect makes the composite weak", {
  res <- cli_build(cand)
  v <- validation(res)
  # in-sample lead of 6 months that vanishes after the cut-offs, as found for
  # the OECD-type CLI of Indonesian GDP
  v@out_of_sample <- data.frame(
    cutoff = c(2010, 2014), n_components = 3, components = "a, b, c",
    ccf_lag_in = 6, median_lead_in = 6, median_lead_out = c(0, 0),
    pct_led_out = c(0.3, 0.4), n_tp_out = c(8, 5), lead_gap = c(6, 6)
  )
  q <- cli_quality(v, res@spec)
  expect_equal(q@verdict, "weak")
  oos <- q@table[q@table$group == "out of sample", ]
  expect_true(all(!oos$passed))
  expect_match(q@note, "out of sample")
})

test_that("cut-offs with fewer than three later turning points are ignored", {
  res <- cli_build(cand)
  v <- validation(res)
  v@out_of_sample <- data.frame(
    cutoff = 2023, n_components = 3, components = "a", ccf_lag_in = 4,
    median_lead_in = 5, median_lead_out = -3, pct_led_out = 0, n_tp_out = 2,
    lead_gap = 8
  )
  expect_equal(cli_quality(v, res@spec)@verdict, "acceptable")
})

test_that("failed in-sample criteria make the composite weak", {
  spec <- cli_spec(12)
  cyc <- cli_cycles(cand, spec)
  ci <- cli_composite(cyc, "lag_3", spec, cyc$reference)
  q <- cli_quality(cli_validate(ci, cyc$reference, spec), spec)
  expect_equal(q@verdict, "weak")
  expect_match(q@note, "turning points")
  expect_false(q@table$passed[q@table$criterion == "cross-correlation lead"])
})

test_that("no composite and bad inputs", {
  res <- suppressWarnings(cli_build(cand[c("noise_1", "lag_3")]))
  q <- cli_quality(res)
  expect_equal(q@verdict, "weak")
  expect_equal(nrow(as.data.frame(q)), 0)
  expect_error(cli_quality(1), class = "rcli_error_argument")
})

test_that("contraction probabilities and ROC curve", {
  spec <- cli_spec(12)
  cyc <- cli_cycles(cand, spec)
  ci <- cli_composite(cyc, c("lead_6", "lead_3"), spec, cyc$reference)
  pr <- contraction_probability(ci, cyc$reference, spec)
  expect_named(pr, c("time", "contraction", "probability", "naive"))
  ok <- !is.na(pr$probability)
  expect_true(all(pr$probability[ok] >= 0 & pr$probability[ok] <= 1))
  roc <- roc_curve(pr$probability, pr$contraction)
  expect_equal(roc$fpr[1], 0)
  expect_equal(tail(roc$fpr, 1), 1)
  expect_equal(tail(roc$tpr, 1), 1)
  auc <- sum(diff(roc$fpr) * (head(roc$tpr, -1) + tail(roc$tpr, -1)) / 2)
  v <- cli_validate(ci, cyc$reference, spec)
  expect_equal(auc, v@probability$auc, tolerance = 1e-8)
  expect_null(contraction_probability(ci, cyc$reference, spec, horizon = 400))
  expect_error(contraction_probability(1, cyc$reference, spec),
               class = "rcli_error_argument")
})

test_that("the scorecard prints by group", {
  expect_snapshot(cli_quality(cli_build(cand)))
})

test_that("spec validates the quality thresholds", {
  expect_error(cli_spec(min_auc = 0.3), "min_auc")
  expect_error(cli_spec(target_lead = c(9, 6)), "target_lead")
  expect_equal(cli_spec(4)@target_lead, c(2, 3))
})
