# FR-013 (rcli 0.7.0): cycle forms (level, growth rate, acceleration) and the
# HP smoother. Formulas F-08 and F-09 (harness/02-math).

test_that("AC-FR-013.1: hp_smoother() is the HP trend at a short cut-off", {
  set.seed(11)
  x <- ts(cumsum(rnorm(80)) + 10, frequency = 4, start = 2000)
  sm <- extract_cycle(hp_smoother(4), x)
  # trend = x minus the HP cycle at lambda(4)
  ref <- x - extract_cycle(hp_filter(hp_lambda(4)), x)
  expect_equal(as.numeric(sm), as.numeric(ref), tolerance = 1e-10)
  expect_identical(tsp(sm), tsp(x))
  # default period: one year of observations
  expect_equal(as.numeric(extract_cycle(hp_smoother(), x)), as.numeric(sm),
               tolerance = 1e-12)
  xm <- ts(cumsum(rnorm(120)), frequency = 12, start = 2000)
  expect_equal(as.numeric(extract_cycle(hp_smoother(), xm)),
               as.numeric(xm - extract_cycle(hp_filter(hp_lambda(12)), xm)),
               tolerance = 1e-10)
  # constant and linear series are left unchanged
  k <- ts(rep(3, 40), frequency = 4)
  expect_equal(as.numeric(extract_cycle(hp_smoother(), k)), rep(3, 40),
               tolerance = 1e-8)
  lin <- ts(2 + 0.5 * (1:40), frequency = 4)
  expect_equal(as.numeric(extract_cycle(hp_smoother(), lin)),
               as.numeric(lin), tolerance = 1e-8)
  expect_s4_class(hp_smoother(), "CycleFilter")
  expect_error(hp_smoother(2), class = "rcli_error_argument")
  expect_error(hp_smoother(Inf), class = "rcli_error_argument")
  expect_error(hp_smoother("a"), class = "rcli_error_argument")
})

test_that("AC-FR-013.2: apply_form() computes growth rates and accelerations", {
  set.seed(12)
  y <- ts(exp(cumsum(rnorm(40, 0.01, 0.02)) + 5), frequency = 4,
          start = 2010)
  z <- log(y)
  for (k in c(1, 4)) {
    g <- apply_form(growth_form(k), z, logged = TRUE)
    expect_identical(tsp(g), tsp(z))
    expect_true(all(is.na(g[seq_len(k)])))
    expect_equal(as.numeric(g)[-seq_len(k)], 100 * diff(as.numeric(z), k),
                 tolerance = 1e-10)
    a <- apply_form(acceleration_form(k), z, logged = TRUE)
    expect_true(all(is.na(a[seq_len(k + 1)])))
    expect_equal(as.numeric(a)[-seq_len(k + 1)],
                 diff(100 * diff(as.numeric(z), k)), tolerance = 1e-10)
  }
  # unlogged series: simple differences in their own units
  r <- ts(5 + cumsum(rnorm(40, 0, 0.3)), frequency = 4, start = 2010)
  g <- apply_form(growth_form(4), r, logged = FALSE)
  expect_equal(as.numeric(g)[-(1:4)], diff(as.numeric(r), 4),
               tolerance = 1e-10)
  # default lag is the frequency (annual rate)
  expect_equal(apply_form(growth_form(), z, logged = TRUE),
               apply_form(growth_form(4), z, logged = TRUE))
  # level form leaves the series alone
  expect_identical(apply_form(level_form(), z, logged = TRUE), z)
  # linearity: value = volume x price  =>  rates add up (F-08, item 2)
  p <- ts(cumsum(rnorm(40, 0.005, 0.01)), frequency = 4, start = 2010)
  expect_equal(apply_form(growth_form(), z + p, logged = TRUE),
               apply_form(growth_form(), z, logged = TRUE) +
                 apply_form(growth_form(), p, logged = TRUE),
               tolerance = 1e-10)
  for (f in list(level_form(), growth_form(), acceleration_form())) {
    expect_s4_class(f, "CycleForm")
  }
  expect_error(growth_form(0), class = "rcli_error_argument")
  expect_error(growth_form(1.5), class = "rcli_error_argument")
  expect_error(acceleration_form(-1), class = "rcli_error_argument")
})

test_that("AC-FR-013.3: cli_spec(form = ) and the default filter", {
  s0 <- cli_spec(freq = 4)
  expect_s4_class(s0@form, "LevelForm")
  expect_s4_class(s0@filter, "HPDoubleFilter")
  s1 <- cli_spec(freq = 4, form = growth_form())
  expect_s4_class(s1@form, "GrowthForm")
  expect_s4_class(s1@filter, "HPSmoother")
  s2 <- cli_spec(freq = 4, form = acceleration_form(1))
  expect_s4_class(s2@filter, "HPSmoother")
  s3 <- cli_spec(freq = 4, form = growth_form(), filter = hp_filter())
  expect_s4_class(s3@filter, "HPFilter")
  expect_s4_class(default_filter(level_form()), "HPDoubleFilter")
  expect_s4_class(default_filter(growth_form()), "HPSmoother")
  expect_error(cli_spec(freq = 4, form = "growth"),
               class = "rcli_error_argument")
  # the default results do not change (same cycles as an explicit level form)
  cand <- sim_candidates(seed = 3, freq = 4, n_years = 20)
  c0 <- cli_cycles(cand, cli_spec(freq = 4))
  c1 <- cli_cycles(cand, cli_spec(freq = 4, form = level_form()))
  expect_identical(c0, c1)
  # update() keeps and replaces the form
  expect_s4_class(update(s1, min_lead = 2)@form, "GrowthForm")
  expect_s4_class(update(s0, form = growth_form())@form, "GrowthForm")
  # a specification saved before 0.7.0 behaves as the level form
  old <- s0
  attr(old, "form") <- NULL
  expect_s4_class(spec_form(old), "LevelForm")
})

test_that("AC-FR-013.4: cli_cycles() applies the form after seasonal steps", {
  cand <- sim_candidates(seed = 4, freq = 4, n_years = 20)
  spec <- cli_spec(freq = 4, form = growth_form(), outlier_threshold = Inf)
  cyc <- cli_cycles(cand, spec)
  ref <- cyc$reference
  lv <- cli_cycles(cand, cli_spec(freq = 4, outlier_threshold = Inf))$reference
  # the transformed slot holds the annual log growth of the level series
  expect_equal(as.numeric(ref@transformed)[-(1:4)],
               100 * diff(as.numeric(lv@transformed), 4), tolerance = 1e-10)
  expect_true(all(is.na(ref@transformed[1:4])))
  expect_true(all(is.na(ref@cycle[1:4])))
  expect_true(all(is.na(ref@normalised[1:4])))
  expect_true(any(grepl("^form: annual growth rate", ref@steps)))
  expect_true(any(grepl("HP smoother", ref@steps)))
  # acceleration loses one more observation
  acc <- cli_cycles(cand, update(spec, form = acceleration_form()))$reference
  expect_true(all(is.na(acc@transformed[1:5])))
  expect_false(is.na(acc@transformed[6]))
  # q-to-q growth
  q <- cli_cycles(cand, update(spec, form = growth_form(1)))$reference
  expect_true(any(grepl("^form: growth rate over 1 period", q@steps)))
  # too short after differencing
  short <- sim_candidates(seed = 5, freq = 4, n_years = 8)
  expect_error(cli_cycles(short, cli_spec(freq = 4,
                                          form = acceleration_form(24))),
               class = "rcli_error_short_series")
})

test_that("AC-FR-013.5: units of growth forms downstream", {
  cand <- sim_candidates(seed = 6, freq = 4, n_years = 20)
  spec <- cli_spec(freq = 4, form = growth_form(), outlier_threshold = Inf)
  cyc <- cli_cycles(cand, spec)
  ref <- cyc$reference
  expect_identical(form_units(ref), "growth")
  expect_identical(form_units(cli_cycles(cand, cli_spec(freq = 4))$reference),
                   "level")
  # levels of a growth series are the growth rates themselves (no exp())
  expect_equal(rcli:::cycle_level(ref), as.numeric(ref@transformed))
  # amplitude in percentage points: mean absolute deviation of the cycle
  cv <- as.numeric(ref@cycle)
  cv <- cv[!is.na(cv)]
  expect_equal(rcli:::reference_amplitude(ref), mean(abs(cv - mean(cv))))
  # presentation in the units of the rate (review R-13.1)
  sim <- simulate_cycles(seed = 3, freq = 4)
  meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
  res <- suppressWarnings(cli_build(cli_candidates(sim, "reference",
                                                   meta = meta), spec))
  expect_false(is.null(composite(res)))
  pr <- cli_presentation(res)
  g <- as.numeric(res@cycles$reference@transformed)
  expect_equal(pr$reference, g)
  expect_equal(pr$reference_trend, rep(mean(g, na.rm = TRUE), length(g)))
  expect_equal(pr$trend_restored - pr$reference_trend,
               pr$amplitude_adjusted - 100)
  expect_equal(pr$reference_amplitude_adjusted - 100, g - mean(g, na.rm = TRUE))
  expect_true(all(is.na(pr$rate_of_change)))
  expect_true(all(is.na(pr$reference_rate_of_change)))
  # composite and reference deviations on the same scale
  ratio <- stats::sd(pr$amplitude_adjusted, na.rm = TRUE) /
    stats::sd(pr$reference_amplitude_adjusted, na.rm = TRUE)
  expect_gt(ratio, 0.2)
  expect_lt(ratio, 5)
  expect_error(cli_spec(freq = 4, form = growth_form(),
                        aggregator = conference_board()),
               class = "rcli_error_argument")
  expect_error(update(cli_spec(freq = 4, aggregator = conference_board()),
                      form = growth_form()),
               class = "rcli_error_argument")
})

test_that("AC-FR-013.6: a true leader still leads in the growth form", {
  hits <- vapply(1:10, function(s) {
    cand <- sim_candidates(seed = s, freq = 4, n_years = 30,
                           leads = c(lead_2 = 2), n_noise = 0,
                           noise_sd = 0.2)
    spec <- cli_spec(freq = 4, form = growth_form(), outlier_threshold = Inf)
    a <- suppressWarnings(cli_assess(cand, spec))
    tab <- a@table
    lead <- tab$median_lead[tab$name == "lead_2"]
    isTRUE(abs(lead - 2) <= 1)
  }, logical(1))
  expect_gte(mean(hits), 0.8)
})

test_that("AC-FR-013.8: level results equal rcli 0.6.0 (golden file)", {
  gold <- readRDS(test_path("fixtures", "level-0.6.0.rds"))
  for (g in gold) {
    sim <- simulate_cycles(seed = 7, freq = g$freq)
    meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
    b <- suppressWarnings(cli_build(cli_candidates(sim, "reference",
                                                   meta = meta),
                                    cli_spec(g$freq)))
    expect_equal(lapply(b@cycles, function(cs) as.numeric(cs@normalised)),
                 g$cycles, tolerance = 1e-12)
    expect_identical(b@assessment@table$class, g$class)
    expect_equal(as.numeric(b@composite@index), g$index, tolerance = 1e-12)
  }
})

test_that("form and filter stay coherent (review R-13.2, R-13.4)", {
  # update() moves a default filter with the form, keeps a chosen one
  s1 <- cli_spec(freq = 4, form = growth_form())
  expect_s4_class(update(s1, form = level_form())@filter, "HPDoubleFilter")
  expect_s4_class(update(cli_spec(freq = 4), form = growth_form())@filter,
                  "HPSmoother")
  s2 <- cli_spec(freq = 4, form = growth_form(), filter = cf_filter())
  expect_s4_class(update(s2, form = acceleration_form())@filter, "CFFilter")
  # the level form with a filter that keeps the trend warns
  expect_warning(cli_spec(freq = 4, filter = hp_smoother()),
                 class = "rcli_warning_form_filter")
  expect_warning(update(s1, form = level_form(), filter = hp_smoother()),
                 class = "rcli_warning_form_filter")
  expect_no_warning(cli_spec(freq = 4, form = growth_form(),
                             filter = hp_filter()))
  # print() shows a non-level form and nothing for the level form
  out <- capture.output(show(s1))
  expect_true(any(grepl("form: +annual growth rate \\(experimental\\)", out)))
  expect_false(any(grepl("form:", capture.output(show(cli_spec(freq = 4))))))
  out <- capture.output(show(cli_spec(freq = 12,
                                      form = acceleration_form(1))))
  expect_true(any(grepl("acceleration of the growth rate over 1 period",
                        out)))
})

test_that("levels-only aggregators refuse growth cycles (review R-13.5)", {
  cand <- sim_candidates(seed = 8, freq = 4, n_years = 20)
  cyc <- cli_cycles(cand, cli_spec(freq = 4, form = growth_form(),
                                   outlier_threshold = Inf))
  comps <- setdiff(names(cyc), cand@reference)[1:2]
  expect_error(cli_composite(cyc, comps,
                             cli_spec(freq = 4,
                                      aggregator = conference_board())),
               class = "rcli_error_argument")
  expect_s4_class(cli_composite(cyc, comps, cli_spec(freq = 4)),
                  "CompositeIndex")
})

test_that("series that are not logged are differenced (review R-13.10)", {
  cand <- sim_candidates(seed = 9, freq = 4, n_years = 20)
  spec <- cli_spec(freq = 4, form = growth_form(), transform = "none",
                   outlier_threshold = Inf)
  ref <- cli_cycles(cand, spec)$reference
  expect_true(any(grepl("^form: annual difference$", ref@steps)))
  expect_identical(form_units(ref), "growth")
  lv <- cli_cycles(cand, cli_spec(freq = 4, transform = "none",
                                  outlier_threshold = Inf))$reference
  expect_equal(as.numeric(ref@transformed)[-(1:4)],
               diff(as.numeric(lv@transformed), 4), tolerance = 1e-10)
  acc <- cli_cycles(cand, update(spec, form = acceleration_form(1)))
  expect_true(any(grepl("^form: acceleration of the difference over 1",
                        acc$reference@steps)))
  expect_identical(form_units(acc$reference), "acceleration")
})

test_that("the form survives the TRAMO forecasts and the 3-year limit", {
  skip_if_not_installed("seasonal")
  cand <- sim_candidates(seed = 10, freq = 4, n_years = 20)
  spec <- cli_spec(freq = 4, form = growth_form(),
                   outliers = tramo_outliers(forecast = 4))
  ref <- cli_cycles(cand, spec)$reference
  expect_true(all(is.na(ref@transformed[1:4])))
  expect_false(anyNA(ref@cycle[-(1:4)]))
})

test_that("three years must remain after the differences", {
  short <- sim_candidates(seed = 5, freq = 4, n_years = 8)
  n <- nrow(short@data)
  spec <- cli_spec(freq = 4, outlier_threshold = Inf)
  # n - k observations remain; 12 (three years) is enough, 11 is not
  expect_s4_class(cli_cycles(short, update(spec, form = growth_form(n - 12)))
                  $reference, "CycleSeries")
  expect_error(cli_cycles(short, update(spec, form = growth_form(n - 11))),
               class = "rcli_error_short_series")
})
