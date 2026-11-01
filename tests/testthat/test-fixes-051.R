# FR-011 (rcli 0.5.1): defects found by the review of 1 November 2026.

sim_cand <- function(seed = 1, ...) {
  sim <- simulate_cycles(seed = seed, ...)
  meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
  cli_candidates(sim, "reference", meta = meta)
}

test_that("AC-FR-011.1 (F1): TRAMO outlier names with Roman periods", {
  xq <- stats::ts(rep(0, 40), start = c(2005, 1), frequency = 4)
  eff <- rcli:::outlier_effects(c("AO (IV-2009)", "LS (II-2010)"),
                                c(0.1, 0.2), xq)
  t_ao <- which(abs(stats::time(xq) - (2009 + 3 / 4)) < 1e-8)
  t_ls <- which(abs(stats::time(xq) - (2010 + 1 / 4)) < 1e-8)
  expect_equal(unname(eff[t_ao, "AO"]), 0.1)
  expect_equal(sum(eff[, "AO"] != 0), 1)
  expect_equal(unname(eff[t_ls - 1L, "LS"]), 0)
  expect_true(all(eff[t_ls:40, "LS"] == 0.2))
  xm <- stats::ts(rep(0, 120), start = c(2005, 1), frequency = 12)
  eff <- rcli:::outlier_effects("TC (5-2011)", 1, xm)
  t0 <- which(abs(stats::time(xm) - (2011 + 4 / 12)) < 1e-8)
  expect_equal(eff[t0 + 0:2, "TC"], 0.7^(0:2))
  expect_error(rcli:::outlier_effects("AO (spring-2011)", 1, xm),
               class = "rcli_error_outliers")
  # periods outside 1..frequency do not roll into another year
  expect_error(rcli:::outlier_effects("AO (V-2009)", 1, xq),
               class = "rcli_error_outliers")
  expect_error(rcli:::outlier_effects("AO (13-2009)", 1, xm),
               class = "rcli_error_outliers")
  expect_error(rcli:::outlier_effects("AO (0-2009)", 1, xm),
               class = "rcli_error_outliers")
})

test_that("AC-FR-011.2 (F2): forecasts continue the removed effects", {
  eff <- cbind(AO = c(0, 0.3, 0, 0, 0), TC = c(0, 0, 0.5, 0.35, 0.245),
               LS = c(0, 0, 0, 0.08, 0.08))
  fc <- c(10, 11, 12)
  out <- rcli:::clean_forecast(fc, eff, c("AO", "TC", "LS"))
  expect_equal(out, fc - 0.08 - 0.245 * 0.7^(1:3))
  # effects that are kept stay in the forecasts
  expect_equal(rcli:::clean_forecast(fc, eff, c("AO", "TC")),
               fc - 0.245 * 0.7^(1:3))
  expect_equal(rcli:::clean_forecast(fc, eff, "AO"), fc)
  expect_equal(rcli:::clean_forecast(numeric(0), eff, "LS"), numeric(0))
  # the decay rate of the engine: TRAMO 0.7, X-13 0.7^(12/f)
  expect_equal(rcli:::tc_rate("tramo", 4), 0.7)
  expect_equal(rcli:::tc_rate("x13", 12), 0.7)
  expect_equal(rcli:::tc_rate("x13", 4), 0.343)
  expect_equal(rcli:::clean_forecast(fc, eff, "TC", 0.343),
               fc - 0.245 * 0.343^(1:3))
  # end to end with X-13: no jump between the clean series and its forecast
  skip_if_not_installed("seasonal")
  set.seed(5)
  x <- stats::ts(cumsum(rnorm(240, 0, 0.004)) + 4.6, start = c(2000, 1),
                 frequency = 12)
  x[200:240] <- x[200:240] + 0.08
  out <- treat_outliers(tramo_outliers(engine = "x13",
                                       remove = c("AO", "TC", "LS")), x)
  skip_if(!grepl("LS [1-9]", out$step), "X-13 found no level shift")
  jump <- abs(out$forecast[1] - as.numeric(out$x)[240])
  expect_lt(jump, 0.03)
})

test_that("AC-FR-011.2b (F2): X-13 transitory changes in quarterly data", {
  skip_if_not_installed("seasonal")
  set.seed(7)
  x <- stats::ts(cumsum(rnorm(100, 0, 0.004)) + 4.6, start = c(2000, 1),
                 frequency = 4)
  x <- x + c(rep(0, 95), 0.08 * 0.343^(0:4))
  fit <- rcli:::regarima_x13(x, 4, NA)
  skip_if(fit$count[["TC"]] == 0L, "X-13 found no transitory change")
  e <- fit$effects[, "TC"]
  # the rate passed on to the forecasts is the one X-13 used in the data
  expect_equal(fit$tc_rate, e[100] / e[99], tolerance = 1e-6)
  out <- treat_outliers(tramo_outliers(engine = "x13", remove = "TC"), x)
  expect_equal(out$forecast, fit$forecast - e[100] * 0.343^(1:4),
               tolerance = 1e-8)
})

test_that("AC-FR-011.3 (F3): an extreme first change is replaced", {
  set.seed(2)
  v <- cumsum(rnorm(120))
  d <- diff(v)
  s <- stats::mad(d)
  # the last observation is the newest signal and is left alone
  last <- v
  last[120] <- v[119] + 15 * s
  out <- rcli:::replace_outliers(stats::ts(last), 5)
  expect_equal(out$n, 0L)
  expect_equal(as.numeric(out$x), last)
  first <- v
  first[1] <- v[2] - 15 * s
  out <- rcli:::replace_outliers(stats::ts(first), 5)
  expect_equal(out$n, 1L)
  expect_equal(as.numeric(out$x)[1], v[2] - stats::median(diff(first)))
  # the middle of the series behaves as before
  mid <- v
  mid[60] <- v[60] + 15 * s
  out <- rcli:::replace_outliers(stats::ts(mid), 5)
  expect_equal(out$n, 1L)
  expect_equal(as.numeric(out$x)[-60], mid[-60])
  # ordinary series are not touched
  n_flag <- vapply(1:200, function(k) {
    set.seed(k)
    rcli:::replace_outliers(stats::ts(cumsum(rnorm(240))), 5)$n
  }, integer(1))
  expect_lte(sum(n_flag), 2)
  # heavy tails: the last observation is never replaced
  last_kept <- vapply(1:200, function(k) {
    set.seed(k)
    y <- cumsum(stats::rt(240, 3))
    as.numeric(rcli:::replace_outliers(stats::ts(y), 5)$x)[240] == y[240]
  }, logical(1))
  expect_true(all(last_kept))
})

test_that("AC-FR-011.4 (G6): Conference Board works on cleaned levels", {
  cand <- sim_cand()
  spec <- cli_spec(12, aggregator = conference_board())
  cyc <- cli_cycles(cand, spec)
  # a spike in the original data of one component, removed by the outlier
  # treatment, must not reach the Conference Board index
  comps <- c("lead_6", "lead_3")
  spiked <- cyc
  orig <- spiked$lead_6@original
  orig[100] <- orig[100] * 3
  spiked$lead_6@original <- orig
  a <- cli_composite(cyc, comps, spec, cyc$reference)
  b <- cli_composite(spiked, comps, spec, cyc$reference)
  expect_equal(as.numeric(a@index), as.numeric(b@index))
  # the index follows the formula on the levels of the transformed series
  lev <- sapply(comps, function(nm) exp(as.numeric(cyc[[nm]]@transformed)))
  ch <- apply(lev, 2, function(v) {
    c(NA, 200 * diff(v) / (v[-1] + v[-length(v)]))
  })
  s <- apply(ch, 2, stats::sd, na.rm = TRUE)
  m <- as.numeric(ch %*% ((1 / s) / sum(1 / s)))
  m <- m[-1]
  lv <- 100 * cumprod((200 + m) / (200 - m))
  expect_equal(as.numeric(a@index)[-1], lv / mean(lv) * 100,
               tolerance = 1e-8)
  # without logs the levels are the transformed series themselves
  spec_n <- cli_spec(12, aggregator = conference_board(), transform = "none")
  cyc_n <- cli_cycles(cand, spec_n)
  expect_identical(rcli:::cycle_level(cyc_n$lead_6),
                   as.numeric(cyc_n$lead_6@transformed))
  spiked_n <- cyc_n
  orig <- spiked_n$lead_6@original
  orig[100] <- orig[100] * 3
  spiked_n$lead_6@original <- orig
  expect_equal(
    as.numeric(cli_composite(cyc_n, comps, spec_n, cyc_n$reference)@index),
    as.numeric(cli_composite(spiked_n, comps, spec_n, cyc_n$reference)@index))
})

test_that("AC-FR-011.5 (G9): presentation uses the cleaned reference", {
  res <- cli_build(sim_cand())
  ref <- cycles(res)$reference
  ref@original[50] <- ref@original[50] * 2
  res@cycles$reference <- ref
  pr <- cli_presentation(res)
  expect_equal(pr$reference, exp(as.numeric(ref@transformed)))
  expect_lt(abs(pr$reference[50] / pr$reference[49] - 1), 0.1)
})

test_that("AC-FR-011.6 (G7/E1): the out-of-sample check keeps lag shifts", {
  cand <- sim_cand()
  spec <- update(cli_spec(12), lag_shift = TRUE)
  train <- cli_build(window(cand, end = 2012),
                     update(spec, oos_cutoffs = numeric(0)))
  expect_gt(length(train@composite@shifts), 0L)
  seen <- list()
  real <- rcli::cli_composite
  testthat::local_mocked_bindings(
    cli_composite = function(cycles, components, spec, reference = NULL,
                             shifts = NULL) {
      # list() keeps a NULL entry, so a call without shifts is recorded
      seen[length(seen) + 1L] <<- list(shifts)
      real(cycles, components, spec, reference, shifts)
    },
    .package = "rcli"
  )
  sb <- cli_selection_bias(cand, spec, cutoffs = 2012)
  # the last call is the out-of-sample composite of one_cutoff()
  expect_equal(seen[[length(seen)]], train@composite@shifts)
})

test_that("AC-FR-011.7 (E2): windows outside the data", {
  cand <- sim_cand()
  expect_error(window(cand, end = 1990), class = "rcli_error_short_series")
  expect_error(window(cand, start = 2040), class = "rcli_error_short_series")
  # start after end inside the data is an ordinary window error
  expect_error(window(cand, start = 2010, end = 2005), "start")
  spec <- cli_spec(12, oos_cutoffs = c(1990, 2012))
  res <- suppressWarnings(cli_build(cand, spec))
  expect_s4_class(res, "CliResult")
  sb <- res@validation@out_of_sample
  expect_equal(sb$note[sb$cutoff == 1990], "training window too short")
  expect_equal(sb$note[sb$cutoff == 2012], "")
})

test_that("AC-FR-011.8 (E3): empty candidates and unusable references", {
  sim <- simulate_cycles(seed = 1)
  dead <- cbind(sim, dead = NA_real_)
  colnames(dead) <- c(colnames(sim), "dead")
  meta <- data.frame(name = colnames(dead)[-1], rationale = "early_stage")
  expect_warning(cand <- cli_candidates(dead, "reference", meta = meta),
                 class = "rcli_warning_dropped")
  expect_false("dead" %in% colnames(cand@data))
  expect_false("dead" %in% cand@meta$name)
  res <- suppressWarnings(cli_build(cand))
  expect_s4_class(res, "CliResult")
  # the dropped candidate also leaves the data vintages
  expect_warning(cand_v <- cli_candidates(dead, "reference", meta = meta,
                                          vintages = list(v1 = dead)),
                 class = "rcli_warning_dropped")
  expect_false("dead" %in% colnames(cand_v@vintages$v1))
  empty_ref <- sim
  empty_ref[, "reference"] <- NA
  expect_error(cli_candidates(empty_ref, "reference"),
               class = "rcli_error_argument")
  flat <- sim
  flat[, "reference"] <- 100
  expect_error(cli_candidates(flat, "reference"),
               class = "rcli_error_argument")
  only_dead <- cbind(reference = sim[, "reference"], dead = NA_real_)
  expect_error(suppressWarnings(cli_candidates(only_dead, "reference")),
               class = "rcli_error_argument")
})

test_that("AC-FR-011.9 (E4): invalid specifications give classed errors", {
  expect_error(cli_spec(alpha = 2), class = "rcli_error_argument")
  expect_error(update(cli_spec(12), freq = 7), class = "rcli_error_argument")
  for (arg in c("max_iter", "min_components", "ccf_lag_max",
                "granger_max_lag", "granger_dmax", "horizon")) {
    expect_error(do.call(cli_spec, stats::setNames(list(2.5), arg)),
                 class = "rcli_error_argument", info = arg)
  }
  expect_error(cli_spec(12, max_iter = NA), "must not be NA",
               class = "rcli_error_argument")
  expect_error(cli_spec(12, ccf_lag_max = NA), "must not be NA",
               class = "rcli_error_argument")
  expect_s4_class(cli_spec(12, horizon = NA), "CliSpec")
  expect_error(cli_spec(12, horizon = Inf), class = "rcli_error_argument")
  # update(): NA where documented, classed errors for wrong types
  expect_true(is.na(update(cli_spec(12, horizon = 3), horizon = NA)@horizon))
  expect_error(update(cli_spec(12), alpha = NA), "must not be NA",
               class = "rcli_error_argument")
  expect_error(update(cli_spec(12), max_iter = "3"),
               class = "rcli_error_argument")
  cand <- sim_cand()
  spec <- cli_spec(12)
  cyc <- cli_cycles(cand, spec)
  comp <- cli_composite(cyc, c("lead_6", "lead_3"), spec, cyc$reference)
  expect_error(cli_validate(comp, cyc$reference, list()),
               class = "rcli_error_argument")
  expect_error(cli_composite(cyc, c("lead_6", "lead_3"), spec, "reference"),
               class = "rcli_error_argument")
})

test_that("AC-FR-011.10 (E8): short quarterly samples are reported", {
  sim <- simulate_cycles(freq = 4, seed = 2, n_years = 8)
  short <- stats::window(sim, start = stats::start(sim),
                         end = stats::time(sim)[20])
  meta <- data.frame(name = colnames(short)[-1], rationale = "early_stage")
  cand <- cli_candidates(short, "reference", meta = meta)
  w <- character(0)
  a <- withCallingHandlers(cli_assess(cand, cli_spec(4)),
                           rcli_warning_short_series = function(c) {
                             w <<- c(w, conditionMessage(c))
                             invokeRestart("muffleWarning")
                           })
  expect_false(all(is.na(a@table$ccf_r)))
  expect_true(any(grepl("Granger", w)))
  expect_match(paste(w, collapse = " "), "lead_", fixed = TRUE)
  expect_identical(rcli:::min_overlap(12), 24L)
  expect_identical(rcli:::min_overlap(4), 8L)
})

test_that("AC-FR-011.11 (E9): fallbacks of PCA and DFM are visible", {
  cand <- sim_cand()
  for (agg in list(principal_component(), dynamic_factor())) {
    spec <- cli_spec(12, aggregator = agg)
    cyc <- cli_cycles(cand, spec)
    sparse <- cyc
    v <- sparse$lead_3@normalised
    v[-(1:4)] <- NA
    sparse$lead_3@normalised <- v
    expect_warning(comp <- cli_composite(sparse, c("lead_6", "lead_3"), spec,
                                         cyc$reference),
                   class = "rcli_warning_fallback")
    expect_s4_class(comp@aggregator, "EqualWeight")
    # one component is not a fallback
    expect_no_warning(cli_composite(cyc, "lead_6", spec, cyc$reference))
  }
})

test_that("AC-FR-011.12 (F9, G11): documentation matches the code", {
  rd <- function(topic) {
    paste(capture.output(tools::Rd2txt(
      tools::Rd_db("rcli")[[paste0(topic, ".Rd")]])), collapse = " ")
  }
  skip_if(length(tools::Rd_db("rcli")) == 0L, "help not installed")
  expect_match(rd("cli_spec"), "cross-correlation", fixed = TRUE)
  expect_false(grepl("method = \"linear\"", rd("oecd_spec"), fixed = TRUE))
})
