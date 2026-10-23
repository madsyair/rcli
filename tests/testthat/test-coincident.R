# FR-005 (rcli 0.2.1): the coincident index of PR #1 in the 0.2 series.
# AC-FR-005.1 is this file with the 0.2 defaults; AC-FR-005.3 is in
# test-app-e2e.R (the exported script reproduces the index).

coin_leads <- c(lead_6 = 6, lead_3 = 3, coin_a = 0, coin_b = 0, lag_3 = -3)

test_that("cci_build aggregates the coincident candidates", {
  cand <- sim_candidates(seed = 1, leads = coin_leads)
  res <- cli_build(cand)
  cci <- cci_build(res)
  expect_s4_class(cci, "CciResult")
  expect_s4_class(cci, "CliResult")
  expect_equal(coincidents(res), coincidents(assessment(res)))
  expect_true(all(c("coin_a", "coin_b") %in% coincidents(res)))
  expect_setequal(components(cci), c("coin_a", "coin_b"))
  v <- validation(cci)
  expect_equal(v@role, "coincident")
  expect_true(v@passed)
  expect_lte(abs(v@turning_points$ccf_lag), res@spec@coincident_band)
  expect_equal(v@probability$horizon, 0)
  expect_equal(tail(audit_log(cci)$action, 1), "accepted: all criteria met")
  expect_match(audit_log(cci)$action[1], "coincident candidates")
})

test_that("a CliResult and a CandidateSet give the same index", {
  cand <- sim_candidates(seed = 1, leads = coin_leads)
  a <- cci_build(cli_build(cand))
  b <- cci_build(cand)
  expect_equal(composite(a)@index, composite(b)@index)
  expect_equal(composite(a)@weights, composite(b)@weights)
})

test_that("cci_validate fails leading and lagging composites", {
  cand <- sim_candidates(seed = 1, leads = coin_leads)
  spec <- cli_spec(12)
  cyc <- cli_cycles(cand, spec)
  ref <- cyc$reference
  lead <- cci_validate(cli_composite(cyc, c("lead_6", "lead_3"), spec, ref),
                       ref, spec)
  lag <- cci_validate(cli_composite(cyc, "lag_3", spec, ref), ref, spec)
  coin <- cci_validate(cli_composite(cyc, c("coin_a", "coin_b"), spec, ref),
                       ref, spec)
  expect_false(lead@passed)
  expect_true(all(c("ccf", "timing") %in% lead@failed))
  expect_false(lag@passed)
  expect_true(coin@passed)
  expect_false("granger" %in% names(coincident_criteria(spec@classifier,
                                                        coin@turning_points,
                                                        spec)))
  expect_error(cci_validate(1, ref, spec), class = "rcli_error_argument")
  expect_error(cci_validate(cli_composite(cyc, "coin_a", spec, ref), ref, 1),
               class = "rcli_error_argument")
})

test_that("the scorecard tests timing for a coincident index", {
  cand <- sim_candidates(seed = 1, leads = coin_leads)
  q <- cli_quality(cci_build(cand))
  tab <- as.data.frame(q)
  tp <- tab[tab$group == "turning points", ]
  expect_true("median lead at turning points" %in% tp$criterion)
  expect_match(tp$threshold[tp$criterion == "median lead at turning points"],
               "within")
  expect_false(any(grepl("Granger", tab$criterion)))
  expect_true("lag of the cross-correlation peak" %in% tab$criterion)
  expect_equal(q@verdict, "acceptable")
  expect_match(q@note, "timing")
})

test_that("the out-of-sample check can make a coincident index good", {
  cand <- sim_candidates(seed = 1, leads = coin_leads)
  cci <- cci_build(cand, cli_spec(12, oos_cutoffs = c(2012, 2016)))
  oos <- validation(cci)@out_of_sample
  expect_equal(nrow(oos), 2L)
  expect_true("pct_timely_out" %in% names(oos))
  expect_true(all(abs(oos$median_lead_out) <= 2))
  q <- cli_quality(cci)
  expect_true(any(q@table$group == "out of sample"))
  expect_equal(q@verdict, "good")
})

test_that("selection bias keeps its leading default", {
  cand <- sim_candidates(seed = 1)
  out <- cli_selection_bias(cand, cli_spec(12), 2015)
  expect_true(all(c("pct_led_out", "pct_timely_out") %in% names(out)))
  expect_error(cli_selection_bias(cand, cli_spec(12), 2015, role = "x"))
})

test_that("no coincident candidate gives a warning and no index", {
  cand <- sim_candidates(seed = 1, leads = c(lead_6 = 6, lead_3 = 3),
                         counter = numeric(0), n_noise = 0)
  expect_warning(cci <- cci_build(cand), class = "rcli_warning_no_coincident")
  expect_null(composite(cci))
  expect_equal(cli_quality(cci)@verdict, "weak")
  expect_output(show(cci), "no index")
})

test_that("components and select control the selection", {
  cand <- sim_candidates(seed = 1, leads = coin_leads)
  res <- cli_build(cand)
  kept <- cci_build(res, components = c("coin_a", "lag_3"), select = FALSE)
  expect_setequal(components(kept), c("coin_a", "lag_3"))
  expect_equal(tail(audit_log(kept)$action, 1), "kept: selection switched off")
  picked <- cci_build(res, components = c("coin_a", "coin_b", "lead_6"))
  expect_setequal(components(picked), c("coin_a", "coin_b"))
  expect_equal(audit_log(picked)$action[2], "dropped lead_6")
  expect_error(cci_build(res, components = "nope"),
               class = "rcli_error_argument")
  expect_error(cci_build(res, select = NA), class = "rcli_error_argument")
  expect_error(cci_build(1), class = "rcli_error_argument")
})

test_that("a spec given with a CliResult reruns the classification", {
  cand <- sim_candidates(seed = 1, leads = coin_leads)
  res <- cli_build(cand)
  cci <- cci_build(res, cli_spec(12, classifier = oecd_classifier()))
  expect_s4_class(cci@spec@classifier, "OecdClassifier")
  expect_named(coincident_criteria(cci@spec@classifier,
                                   validation(cci)@turning_points, cci@spec),
               c("matched", "timing"))
})

test_that("the OECD timing band is strict and the rcli band inclusive", {
  spec_r <- cli_spec(12)
  spec_o <- cli_spec(12, classifier = oecd_classifier())
  row <- data.frame(n_matched = 5, median_lead = 2, ccf_lag = 0, ccf_r = 0.8,
                    n_ref = 6, missed = 1, extra = 0, concordance = 0.8,
                    concordance_expected = 0.5, concordance_p = 0.01)
  expect_true(coincident_criteria(spec_r@classifier, row, spec_r)[["timing"]])
  expect_false(coincident_criteria(spec_o@classifier, row, spec_o)[["timing"]])
  row$median_lead <- -1.5
  expect_true(coincident_criteria(spec_o@classifier, row, spec_o)[["timing"]])
  setClass("PlainRule", contains = "Classifier", where = globalenv())
  on.exit(removeClass("PlainRule", where = globalenv()), add = TRUE)
  plain <- new("PlainRule", label = "plain")
  expect_named(coincident_criteria(plain, row, spec_r), c("matched", "timing"))
  q <- rcli:::coincident_quality(plain, row, spec_r)
  expect_equal(nrow(q), 2L)
  # the rule texts follow the classifier (methods, not class branches)
  rule <- function(cl, spec) {
    rcli:::coincident_quality(cl, row, spec)$threshold
  }
  expect_true(all(c(">= 3", "within +/- 2") %in% rule(plain, spec_r)))
  expect_true(all(c(">= 3", "within (-2, 2)") %in%
                    rule(spec_o@classifier, spec_o)))
  expect_true(">= 1" %in% rule(oecd_classifier(min_matched = 1), spec_o))
})

test_that("quarterly data use a one-period timing band", {
  spec <- cli_spec(4)
  expect_equal(rcli:::timing_band(spec@classifier, spec), 1)
  expect_equal(rcli:::timing_band(oecd_classifier(), spec), 2 / 3)
  cand <- sim_candidates(seed = 3, freq = 4,
                         leads = c(lead_2 = 2, coin_a = 0, coin_b = 0))
  cci <- cci_build(cand)
  expect_true(validation(cci)@passed)
})

test_that("a coincident index can become the reference", {
  cand <- sim_candidates(seed = 1, leads = coin_leads)
  cci <- cci_build(cand)
  ref <- cci_as_reference(cci)
  expect_s4_class(ref, "CandidateSet")
  expect_equal(ref@reference, "cci")
  expect_false(any(c("reference", "coin_a", "coin_b") %in% colnames(ref@data)))
  expect_equal(as.numeric(ref@data[, "cci"]),
               as.numeric(composite(cci)@index))
  expect_setequal(ref@meta$name, setdiff(colnames(ref@data), "cci"))
  res <- cli_build(ref)
  expect_true(all(c("lead_6", "lead_3") %in% leaders(res)))
  keep <- cci_as_reference(cci, name = "cei", drop_components = FALSE)
  expect_true(all(c("coin_a", "coin_b") %in% colnames(keep@data)))
  expect_error(cci_as_reference(cci, name = "lead_6"),
               class = "rcli_error_argument")
  expect_error(cci_as_reference(cci, name = ""),
               class = "rcli_error_argument")
  expect_error(cci_as_reference(cci, drop_components = NA),
               class = "rcli_error_argument")
  expect_error(cci_as_reference(cli_build(cand)),
               class = "rcli_error_argument")
  expect_error(cci_as_reference(cci, candidates = 1),
               class = "rcli_error_argument")
})

test_that("show, summary and plot describe a coincident index", {
  cand <- sim_candidates(seed = 1, leads = coin_leads)
  cci <- cci_build(cand)
  expect_output(show(cci), "coincident index: coin_a, coin_b")
  expect_output(show(validation(cci)), "timing \\(coincident index\\)")
  expect_output(s <- summary(cci), "Coincident index")
  expect_named(s, c("assessment", "validation", "audit"))
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_identical(plot(cci), cci)
})

test_that("validations saved before 0.1.4 count as leading", {
  v <- new("CliValidation")
  expect_equal(rcli:::validation_role(v), "leading")
  v@role <- character(0)
  expect_equal(rcli:::validation_role(v), "leading")
})

test_that("FR-005 AC-2: the calibration with the 0.2 defaults stands", {
  cal <- utils::read.csv(system.file("calibration", "coincident.csv",
                                     package = "rcli"))
  base <- cal[cal$noise_sd == 0.4, ]
  expect_true(all(base$pass_rate[base$truth == "coincident"] >= 0.9))
  expect_true(all(base$pass_rate[base$truth %in%
                                   c("leading", "lagging")] <= 0.05))
})

# Review of 0.2.1 (harness/06-review.md, R1-R6)

test_that("R1: a validation object without the role slot counts as leading", {
  v <- new("CliValidation")
  attr(v, "role") <- NULL
  expect_false(methods::.hasSlot(v, "role"))
  expect_equal(rcli:::validation_role(v), "leading")
})

test_that("R2/R3: the out-of-sample timing rules, band edges included", {
  spec_r <- cli_spec(12)
  spec_o <- cli_spec(12, classifier = oecd_classifier())
  oos <- data.frame(median_lead_out = 2, pct_timely_out = 0.5, lead_gap = 0)
  status <- function(o, spec) {
    stats::setNames(rcli:::coincident_out_of_sample(o, spec)$passed,
                    c("timing", "timely", "gap"))
  }
  expect_equal(unname(status(oos, spec_r)), c(TRUE, TRUE, TRUE))
  # the OECD band is open in sample, so it is open out of sample too
  expect_false(status(oos, spec_o)[["timing"]])
  expect_match(rcli:::coincident_out_of_sample(oos, spec_o)$threshold[1],
               "within (-2, 2)", fixed = TRUE)
  expect_false(status(transform(oos, median_lead_out = 2.5),
                      spec_r)[["timing"]])
  expect_false(status(transform(oos, pct_timely_out = 0.4),
                      spec_r)[["timely"]])
  gap <- spec_r@min_lead
  expect_true(status(transform(oos, lead_gap = -gap), spec_r)[["gap"]])
  expect_false(status(transform(oos, lead_gap = gap + 0.5),
                      spec_r)[["gap"]])
  # the share of timely turning points follows the same rule
  oecd <- spec_o@classifier
  expect_equal(rcli:::in_timing_band(oecd, c(-2, -1, 2), 2),
               c(FALSE, TRUE, FALSE))
  expect_equal(rcli:::in_timing_band(spec_r@classifier, c(-2, 2.5), 2),
               c(TRUE, FALSE))
})

test_that("R5: a coincident index chains at the ragged edge", {
  sim <- simulate_cycles(leads = coin_leads, seed = 5)
  n <- nrow(sim)
  sim[(n - 1):n, "coin_b"] <- NA
  meta <- data.frame(name = colnames(sim)[-1], rationale = "rapid_response")
  cand <- cli_candidates(sim, "reference", meta = meta)
  build <- function(edge) {
    spec <- cli_spec(12, aggregator = equal_weight(min_coverage = 0.5,
                                                   ragged_edge = edge))
    cci_build(cand, spec, components = c("coin_a", "coin_b"),
              select = FALSE)@composite
  }
  chain <- build("chain")
  level <- build("level")
  expect_equal(chain@aggregator@ragged_edge, "chain")
  expect_equal(level@aggregator@ragged_edge, "level")
  # the composite is rescaled over the sample, so compare after an affine
  # fit on the dates before the ragged edge: they agree there, not at the
  # edge, where the plain mean jumps to coin_a alone
  y <- as.numeric(chain@cycle)
  x <- as.numeric(level@cycle)
  body <- seq_len(n - 2)
  fit <- stats::lm(y[body] ~ x[body])
  expect_lt(max(abs(stats::residuals(fit))), 1e-8)
  pred <- stats::coef(fit)[[1]] + stats::coef(fit)[[2]] * x[n]
  expect_gt(abs(y[n] - pred), 1e-3)
})

test_that("R6: the selection score rewards timing and concordance", {
  spec <- cli_spec(12)
  row <- data.frame(n_matched = 10, median_lead = 0, ccf_lag = 0,
                    ccf_r = 0.8, n_ref = 10, missed = 1, extra = 1,
                    concordance = 0.8, concordance_expected = 0.5,
                    concordance_p = 0.01)
  score <- function(r) {
    rcli:::coincident_score(new("CliValidation", turning_points = r), spec)
  }
  base <- score(row)
  # every criterion passes: 10 points each, minus lags, plus concordance
  expect_equal(base, 10 * 6 - 0 - 0 + 5 * 0.8 - 5 * 0.2)
  expect_equal(score(transform(row, median_lead = 1)), base - 1)
  expect_equal(score(transform(row, ccf_lag = -1)), base - 1)
  expect_lt(score(transform(row, concordance = 0.6)), base)
})
