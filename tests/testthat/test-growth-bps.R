# FR-015 (INC-17): growth rates by the BPS formula and series in percent.
# Formula F-08 (harness/02-math). The check against the rates BPS publishes
# was run outside the package: the BPS tables used are not public data and
# are not part of the repository.

test_that("AC-FR-015.1: growth_form() uses the BPS formula by default", {
  y <- ts(c(100, 102, 105, 103, 108, 110, 115, 112), frequency = 4,
          start = 2020)
  z <- log(y)
  g <- apply_form(growth_form(), z, logged = TRUE)
  expect_equal(as.numeric(g)[-(1:4)], 100 * (y[5:8] / y[1:4] - 1),
               tolerance = 1e-12)
  q <- apply_form(growth_form(1), z, logged = TRUE)
  expect_equal(as.numeric(q)[-1], 100 * (y[-1] / y[-8] - 1),
               tolerance = 1e-12)
  a <- apply_form(acceleration_form(), z, logged = TRUE)
  expect_equal(as.numeric(a)[-(1:5)], diff(100 * (y[5:8] / y[1:4] - 1)),
               tolerance = 1e-12)
  # the log rates of 0.7.0-0.8.0 remain available
  expect_equal(as.numeric(apply_form(growth_form(rate = "log"), z,
                                     TRUE))[-(1:4)],
               100 * diff(as.numeric(z), 4), tolerance = 1e-12)
  # a series without logarithm: differences, whatever the rate
  r <- ts(c(5, 5.5, 6, 5.75, 6.25, 6.5, 7, 6.5), frequency = 4)
  for (rate in c("percent", "log")) {
    expect_equal(as.numeric(apply_form(growth_form(rate = rate), r,
                                       FALSE))[-(1:4)],
                 r[5:8] - r[1:4], tolerance = 1e-12)
  }
  expect_identical(growth_form()@rate, "percent")
  expect_identical(acceleration_form(rate = "log")@rate, "log")
  expect_error(growth_form(rate = "ratio"), class = "rcli_error_argument")
  expect_error(acceleration_form(rate = c("percent", "log", "x")),
               class = "rcli_error_argument")
  # a form saved before INC-17 has no rate and behaves as the log rate
  old <- growth_form()
  attr(old, "rate") <- NULL
  expect_equal(apply_form(old, z, TRUE),
               apply_form(growth_form(rate = "log"), z, TRUE))
})

test_that("AC-FR-015.2: the BPS rate differs from the log rate", {
  # a quarterly volume series growing about 5 percent a year, like GDP
  set.seed(152)
  y <- ts(1e6 * exp(cumsum(rnorm(60, log(1.05) / 4, 0.004))),
          frequency = 4, start = 2010)
  z <- log(y)
  for (k in c(4, 1)) {
    bps <- apply_form(growth_form(k), z, TRUE)
    lg <- apply_form(growth_form(k, rate = "log"), z, TRUE)
    direct <- 100 * (y / stats::lag(y, -k) - 1)
    both <- stats::ts.intersect(bps, direct)
    expect_lt(max(abs(both[, 1] - both[, 2])), 1e-9)
    # the log rate is lower by about 50 r^2 points (F-08, item 1)
    r <- as.numeric(bps)[-(1:k)] / 100
    gap <- as.numeric(bps - lg)[-(1:k)]
    expect_equal(gap, 50 * r^2, tolerance = 0.05)
  }
  expect_gt(max(as.numeric(apply_form(growth_form(), z, TRUE) -
                             apply_form(growth_form(rate = "log"), z,
                                        TRUE)), na.rm = TRUE), 0.1)
  # the same through cli_cycles() without seasonal adjustment and outliers
  x <- cbind(ref = y, cand = y * exp(rnorm(60, 0, 0.01)))
  cand <- cli_candidates(x, "ref", meta = data.frame(name = "cand",
                                                     rationale = "early_stage"))
  cy <- cli_cycles(cand, cli_spec(freq = 4, form = growth_form(),
                                  outlier_threshold = Inf))
  both <- stats::ts.intersect(cy$ref@transformed,
                              100 * (y / stats::lag(y, -4) - 1))
  both <- both[stats::complete.cases(both), , drop = FALSE]
  expect_lt(max(abs(both[, 1] - both[, 2])), 1e-9)
})

test_that("AC-FR-015.3: series in percent are differenced in points", {
  set.seed(15)
  n <- 80
  lv <- ts(exp(cumsum(rnorm(n, 0.01, 0.01)) + 5), frequency = 4,
           start = 2005)
  rate <- ts(6 + 2 * sin(2 * pi * (1:n) / 24) + rnorm(n, 0, 0.1),
             frequency = 4, start = 2005)
  x <- cbind(ref = lv, rate = rate, rate2 = rate)
  meta <- data.frame(name = c("rate", "rate2"), rationale = "prime_mover",
                     unit = c("percent", NA))
  cand <- cli_candidates(x, "ref", meta = meta)
  expect_identical(cand@meta$unit, c("percent", NA))
  spec <- cli_spec(freq = 4, form = growth_form(), outlier_threshold = Inf)
  cy <- cli_cycles(cand, spec)
  # logged by the "auto" transformation, but differenced in points
  expect_true(any(grepl("^log", cy$rate@steps)))
  expect_equal(as.numeric(cy$rate@transformed)[-(1:4)],
               rate[5:n] - rate[1:(n - 4)], tolerance = 1e-10)
  expect_true(any(grepl("difference \\(percentage points\\)",
                        cy$rate@steps)))
  # without the unit: percent growth of the rate
  expect_equal(as.numeric(cy$rate2@transformed)[-(1:4)],
               100 * (rate[5:n] / rate[1:(n - 4)] - 1), tolerance = 1e-10)
  # acceleration of a series in percent: change of the difference
  ca <- cli_cycles(cand, update(spec, form = acceleration_form()))
  expect_equal(as.numeric(ca$rate@transformed)[-(1:5)],
               diff(rate[5:n] - rate[1:(n - 4)]), tolerance = 1e-10)
  # the level form ignores the unit
  c0 <- cli_cycles(cand, cli_spec(freq = 4, outlier_threshold = Inf))
  expect_equal(c0$rate@normalised, c0$rate2@normalised)
  # a reference in percent, given in a row of meta
  x2 <- cbind(ref = rate, lv = lv)
  m2 <- data.frame(name = c("ref", "lv"), rationale = c(NA, "early_stage"),
                   unit = c("percent", NA))
  c2 <- cli_candidates(x2, "ref", meta = m2)
  expect_identical(c2@meta$name, "lv")
  expect_identical(series_unit(c2, "ref"), "percent")
  expect_identical(series_unit(c2, "lv"), "level")
  cr <- cli_cycles(c2, spec)
  expect_equal(as.numeric(cr$ref@transformed)[-(1:4)],
               rate[5:n] - rate[1:(n - 4)], tolerance = 1e-10)
  # kept by subsetting and windows
  expect_identical(series_unit(c2[1], "ref"), "percent")
  expect_identical(series_unit(window(c2, start = 2010), "ref"), "percent")
  # an old candidate set has no units
  old <- c2
  attr(old, "units") <- NULL
  expect_identical(series_unit(old, "ref"), "level")
  bad <- data.frame(name = "lv", rationale = "early_stage", unit = "pct")
  expect_error(cli_candidates(x2, "ref", meta = bad),
               class = "rcli_error_argument")
})

test_that("AC-FR-015.4: the interface sets the units and writes them", {
  skip_if_not_installed("shiny")
  shiny::testServer(rcli:::app_server("id"), {
    session$setInputs(source = "example_m", seed = 1, freq = "auto",
                      start = "", run1 = 1)
    session$setInputs(reference = "reference")
    cands <- setdiff(colnames(rv$data), "reference")
    k <- match("lead_3", cands)
    inputs <- stats::setNames(as.list(rep("early_stage", length(cands))),
                              paste0("rat_", seq_along(cands)))
    do.call(session$setInputs, inputs)
    # no unit chosen: nothing is written
    session$setInputs(run2 = 1)
    expect_true(all(is.na(rv$cand@meta$unit)))
    expect_false(grepl("unit =", paste(rcli:::candidate_lines(
      list(meta = rv$meta, reference = "reference", ref_unit = "level"),
      "data"), collapse = "\n"), fixed = TRUE))
    do.call(session$setInputs, stats::setNames(list("percent"),
                                               paste0("unt_", k)))
    session$setInputs(ref_unit = "percent", run2 = 2)
    expect_identical(series_unit(rv$cand, "lead_3"), "percent")
    expect_identical(series_unit(rv$cand, "reference"), "percent")
    expect_identical(series_unit(rv$cand, "lead_6"), "level")
    session$setInputs(method = "rcli", filter = "hp_smoother",
                      aggregator = "equal", extend = TRUE,
                      transform = "auto", seasonal = FALSE, outlier = 5,
                      min_lead = 3, min_median_lead = 1,
                      min_consistency = 0.5, max_missed = 0.4,
                      max_extra = 0.4, alpha = 0.05, min_auc = 0.7,
                      min_components = 2, max_iter = 10, oos_cutoffs = "",
                      form = "growth", growth_lag = "annual", run3 = 1)
    session$setInputs(run4 = 1)
    expect_true(any(grepl("difference \\(percentage points\\)",
                          rv$cycles$lead_3@steps)))
    expect_true(any(grepl("difference \\(percentage points\\)",
                          rv$cycles$reference@steps)))
    expect_false(any(grepl("percentage points", rv$cycles$lead_6@steps)))
    lines <- rcli:::candidate_lines(
      list(meta = rv$meta, reference = "reference", ref_unit = "percent"),
      "sim")
    text <- paste(lines, collapse = "\n")
    expect_match(text, "unit = c(", fixed = TRUE)
    expect_match(text, "c(\"name\", \"unit\")] <- c(\"reference\", \"percent\")",
                 fixed = TRUE)
    env <- new.env()
    env$sim <- rv$data
    eval(parse(text = text), envir = env)
    expect_identical(env$cand@units, rv$cand@units)
    expect_equal(env$cand@meta$unit, rv$cand@meta$unit)
  })
})
