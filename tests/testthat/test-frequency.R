# FR-007, F-04 (rcli 0.2.2): the source frequency of every series, annual
# and semiannual reference series, and the Denton-Cholette disaggregation
# with a general aggregation ratio. Reference: harness/02-math/F-04.md.

# k consecutive target values aggregated by type (the constraint of F-04)
aggregate_k <- function(x, k, tp) {
  m <- matrix(as.numeric(x), nrow = k)
  switch(tp, flow = colSums(m), average = colMeans(m), stock = m[k, ])
}

test_that("FR-007: the source frequencies are listed", {
  expect_named(series_frequencies, c("daily", "weekly", "monthly",
                                     "quarterly", "semiannual", "annual"))
})

test_that("FR-007 AC-1/2: annual and semiannual references are detected", {
  set.seed(71)
  ann <- ts(100 + cumsum(rnorm(20, 2)), start = 2001, frequency = 1)
  sem <- ts(50 + cumsum(rnorm(40, 1)), start = c(2001, 1), frequency = 2)
  years <- seq(as.Date("2001-01-01"), by = "year", length.out = 20)
  halves <- seq(as.Date("2001-01-01"), by = "6 months", length.out = 40)
  ann_df <- data.frame(date = years, value = as.numeric(ann))
  sem_df <- data.frame(date = halves, value = as.numeric(sem))
  cand <- ts(rnorm(240), start = c(2001, 1), frequency = 12)
  for (ref in list(ann, ann_df)) {
    x <- cli_align(list(gdp = ref, lead = cand), type = c(gdp = "flow"),
                   reference = "gdp")
    al <- attr(x, "alignment")
    expect_equal(al$from[al$name == "gdp"], "annual")
    expect_match(al$method[al$name == "gdp"], "annual to monthly")
    expect_equal(aggregate_k(x[, "gdp"], 12, "flow"), as.numeric(ann),
                 tolerance = 1e-8)
  }
  for (ref in list(sem, sem_df)) {
    x <- cli_align(list(gdp = ref, lead = cand), type = c(gdp = "average"),
                   reference = "gdp")
    expect_equal(attr(x, "alignment")$from[1], "semiannual")
    expect_equal(aggregate_k(x[, "gdp"], 6, "average"), as.numeric(sem),
                 tolerance = 1e-8)
  }
  # to quarters: k = 4 (annual) and 2 (semiannual)
  cand_q <- ts(rnorm(80), start = c(2001, 1), frequency = 4)
  x <- cli_align(list(gdp = ann, lead = cand_q), freq = 4,
                 type = c(gdp = "stock"), reference = "gdp")
  expect_equal(aggregate_k(x[, "gdp"], 4, "stock"), as.numeric(ann),
               tolerance = 1e-8)
  x <- cli_align(list(gdp = sem, lead = cand_q), freq = 4,
                 type = c(gdp = "flow"), reference = "gdp")
  expect_equal(aggregate_k(x[, "gdp"], 2, "flow"), as.numeric(sem),
               tolerance = 1e-8)
})

test_that("F-04: Denton-Cholette keeps every constraint and matches td()", {
  set.seed(72)
  y <- ts(100 + cumsum(rnorm(15, 3)), start = 2005, frequency = 1)
  for (tp in c("flow", "average", "stock")) {
    for (to in c(12, 4)) {
      k <- to
      x <- rcli:::denton_cholette(y, tp, to)
      expect_equal(frequency(x), to)
      expect_equal(start(x), c(2005, 1))
      expect_length(x, k * length(y))
      expect_equal(aggregate_k(x, k, tp), as.numeric(y), tolerance = 1e-8)
      skip_if_not_installed("tempdisagg")
      conv <- c(flow = "sum", average = "average", stock = "last")[[tp]]
      ref <- stats::predict(tempdisagg::td(
        y ~ 1, to = if (to == 12) "monthly" else "quarterly",
        conversion = conv, method = "denton-cholette"))
      expect_equal(as.numeric(x), as.numeric(ref), tolerance = 1e-8)
    }
  }
})

test_that("F-04 AC-3: quarterly to monthly is unchanged from 0.2.1", {
  # the 0.2.1 implementation (k = 3), kept here as the reference
  old <- function(q, tp) {
    y <- as.numeric(q)
    m <- length(y)
    n <- 3L * m
    w <- switch(tp, flow = c(1, 1, 1), average = c(1, 1, 1) / 3,
                stock = c(0, 0, 1))
    cm <- kronecker(diag(m), t(w))
    dm <- diff(diag(n))
    a <- rbind(cbind(2 * crossprod(dm), t(cm)), cbind(cm, matrix(0, m, m)))
    solve(a, c(rep(0, n), y))[seq_len(n)]
  }
  set.seed(73)
  q <- ts(100 + cumsum(rnorm(40)), start = c(2000, 2), frequency = 4)
  for (tp in c("flow", "average", "stock")) {
    x <- rcli:::denton_cholette(q, tp, 12)
    expect_equal(as.numeric(x), old(q, tp), tolerance = 1e-10)
    expect_equal(start(x), c(2000, 4))
  }
})

test_that("FR-007: annual references can be interpolated linearly", {
  y <- ts(c(120, 240, 360), start = 2001, frequency = 1)
  x <- cli_align(list(gdp = y, lead = ts(rnorm(36), start = 2001,
                                         frequency = 12)),
                 type = c(gdp = "flow"), reference = "gdp",
                 method = "linear")
  v <- as.numeric(x[, "gdp"])
  # the monthly level 10, 20, 30 sits in the middle of each year (6.5);
  # before it the first level is held, between levels the slope is 10 / 12
  expect_equal(v[1:6], rep(10, 6))
  expect_equal(v[c(7, 8)], c(10 + 5 / 12, 10 + 15 / 12))
  expect_equal(v[18] + v[19], 40)
  expect_match(attr(x, "alignment")$method[1], "annual to monthly (linear)",
               fixed = TRUE)
})

test_that("FR-007: annual references can be disaggregated by Chow-Lin", {
  skip_if_not_installed("tempdisagg")
  set.seed(74)
  ind <- ts(100 + cumsum(rnorm(240)), start = 2001, frequency = 12)
  y <- ts(aggregate_k(ind, 12, "flow") * 1.1, start = 2001, frequency = 1)
  x <- cli_align(list(gdp = y, lead = ind), type = c(gdp = "flow"),
                 reference = "gdp", method = "chow-lin", indicator = ind)
  expect_equal(aggregate_k(x[, "gdp"], 12, "flow"), as.numeric(y),
               tolerance = 1e-8)
})

test_that("FR-007 AC-4: annual and semiannual candidates are rejected", {
  ann <- ts(1:20, start = 2001, frequency = 1)
  ref <- ts(rnorm(240), start = 2001, frequency = 12)
  expect_error(cli_align(list(ref = ref, ann = ann), type = c(ann = "flow"),
                         reference = "ref"),
               class = "rcli_error_frequency", regexp = "reference series")
  sim <- simulate_cycles(seed = 1)
  meta <- data.frame(name = c("lead_6", "lead_3"),
                     rationale = "early_stage",
                     frequency = c("monthly", "semiannual"))
  expect_error(cli_candidates(sim, "reference", meta = meta),
               class = "rcli_error_frequency", regexp = "reference series")
})

test_that("FR-007 AC-5: a declared frequency must match the data", {
  q <- ts(1:40, start = c(2001, 1), frequency = 4)
  m <- ts(rnorm(120), start = c(2001, 1), frequency = 12)
  expect_error(cli_align(list(ref = m, q = q), type = c(q = "flow"),
                         reference = "ref",
                         frequency = c(q = "monthly")),
               class = "rcli_error_frequency",
               regexp = "declared monthly.*quarterly")
  x <- cli_align(list(ref = m, q = q), type = c(q = "flow"),
                 reference = "ref", frequency = c(q = "quarterly"))
  expect_equal(attr(x, "alignment")$from, c("monthly", "quarterly"))
  expect_error(cli_align(list(ref = m, q = q), type = c(q = "flow"),
                         frequency = c(q = "yearly")),
               class = "rcli_error_argument")
  expect_error(cli_align(list(ref = m, q = q), type = c(q = "flow"),
                         frequency = c(zz = "monthly")),
               class = "rcli_error_argument")
})

test_that("FR-007 AC-6: the metadata keeps the source frequency", {
  sim <- simulate_cycles(seed = 1)
  meta <- data.frame(name = c("lead_6", "lead_3"), rationale = "early_stage",
                     frequency = c("weekly", NA))
  quiet <- function(expr) {
    suppressWarnings(expr, classes = "rcli_warning_rationale")
  }
  cand <- quiet(cli_candidates(sim, "reference", meta = meta))
  expect_true("frequency" %in% names(cand@meta))
  expect_equal(cand@meta$frequency[1:2], c("weekly", NA))
  bad <- transform(meta, frequency = c("yearly", NA))
  expect_error(quiet(cli_candidates(sim, "reference", meta = bad)),
               class = "rcli_error_argument")
  # from cli_align() when not given
  q <- ts(rnorm(120), start = c(1995, 1), frequency = 4)
  x <- cli_align(list(sim[, c("reference", "lead_6")], q_lead = q),
                 type = c(q_lead = "average"), reference = "reference")
  cand <- quiet(cli_candidates(x, "reference",
                               meta = data.frame(name = c("lead_6", "q_lead"),
                                                 rationale = "early_stage")))
  expect_equal(cand@meta$frequency, c("monthly", "quarterly"))
})

test_that("FR-007: the printed candidate set shows given source frequencies", {
  sim <- simulate_cycles(seed = 1)
  quiet <- function(expr) {
    suppressWarnings(expr, classes = "rcli_warning_rationale")
  }
  plain <- quiet(cli_candidates(sim, "reference",
                                meta = data.frame(name = "lead_6",
                                                  rationale = "early_stage")))
  expect_false(any(grepl("frequency", capture.output(show(plain)))))
  meta <- data.frame(name = "lead_6", rationale = "early_stage",
                     frequency = "weekly")
  cand <- quiet(cli_candidates(sim, "reference", meta = meta))
  out <- capture.output(show(cand))
  expect_true(any(grepl("frequency", out)))
  expect_true(any(grepl("lead_6.*weekly", out)))
})

# Review of 0.2.2 (harness/06-review.md, round 1)

test_that("R2: an annual or semiannual reference is flagged on the scorecard", {
  sim <- simulate_cycles(seed = 2026)
  for (f in c(annual = 1, semiannual = 2)) {
    low <- aggregate(sim[, "reference"], nfrequency = f, FUN = sum)
    x <- cli_align(list(pdrb = low, sim[, -1]), type = c(pdrb = "flow"),
                   reference = "pdrb")
    meta <- data.frame(name = colnames(x)[-1], rationale = "early_stage")
    res <- cli_build(cli_candidates(x, "pdrb", meta = meta))
    q <- cli_quality(res)
    kind <- names(per <- c(annual = 6, semiannual = 3))[f]
    row <- q@table[q@table$group == "information" &
                     grepl("disaggregated", q@table$criterion), ]
    expect_equal(row$criterion,
                 sprintf("reference disaggregated from %s data", kind))
    expect_equal(row$threshold,
                 sprintf("turning points +/- %d months", per[[kind]]))
    expect_match(q@note, sprintf("about %d months", per[[kind]]))
  }
})

test_that("R4: a reference starting in its second period keeps its dates", {
  set.seed(75)
  sem <- ts(100 + cumsum(rnorm(21)), start = c(2001, 2), frequency = 2)
  x <- rcli:::denton_cholette(sem, "average", 12)
  expect_equal(start(x), c(2001, 7))
  expect_equal(aggregate_k(x, 6, "average"), as.numeric(sem),
               tolerance = 1e-8)
  q <- rcli:::denton_cholette(sem, "flow", 4)
  expect_equal(start(q), c(2001, 3))
  lin <- rcli:::interpolate_reference(sem, "average", 12)
  expect_equal(start(lin), c(2001, 7))
})

test_that("R4: missing values at the ends are dropped, inside they stop", {
  y <- ts(c(NA, 120, 240, 360, NA), start = 2000, frequency = 1)
  x <- rcli:::denton_cholette(y, "flow", 12)
  expect_equal(start(x), c(2001, 1))
  expect_length(x, 36)
  expect_equal(aggregate_k(x, 12, "flow"), c(120, 240, 360),
               tolerance = 1e-8)
  lin <- rcli:::interpolate_reference(y, "flow", 12)
  expect_true(all(is.na(lin[1:12])))
  expect_true(all(is.na(lin[49:60])))
  expect_false(anyNA(lin[13:48]))
  expect_error(rcli:::denton_cholette(ts(c(1, NA, 3), start = 2000), "flow",
                                      12), class = "rcli_error_argument")
})

test_that("R4/R10: stocks sit at the end of the period; position moves it", {
  y <- ts(c(10, 20, 30), start = 2001, frequency = 1)
  lin <- rcli:::interpolate_reference(y, "stock", 12)
  expect_equal(as.numeric(lin[c(1, 12, 18, 24, 36)]), c(10, 10, 15, 20, 30))
  m <- ts(rnorm(36), start = 2001, frequency = 12)
  x <- cli_align(list(gdp = y, lead = m), type = c(gdp = "average"),
                 reference = "gdp", method = "linear",
                 position = c(gdp = 1))
  expect_equal(as.numeric(x[c(1, 13, 25), "gdp"]), c(10, 20, 30))
  expect_error(cli_align(list(gdp = y, lead = m), type = c(gdp = "average"),
                         reference = "gdp", method = "linear",
                         position = c(gdp = 13)),
               class = "rcli_error_argument")
})

test_that("R4: Chow-Lin uses the indicator from the start of the reference", {
  skip_if_not_installed("tempdisagg")
  set.seed(76)
  ind <- ts(100 + cumsum(rnorm(300)), start = 2001, frequency = 12)
  y <- ts(aggregate_k(window(ind, start = 2003), 12, "average") + 5,
          start = 2003, frequency = 1)
  x <- rcli:::chow_lin(y, "average", ind, 12)
  expect_equal(start(x), c(2003, 1))
  expect_equal(aggregate_k(window(x, end = c(2025, 12)), 12, "average"),
               as.numeric(y), tolerance = 1e-8)
})

test_that("R5: the metadata frequency must agree with cli_align()", {
  sim <- simulate_cycles(seed = 1)
  q <- ts(rnorm(120), start = c(1995, 1), frequency = 4)
  x <- cli_align(list(sim[, c("reference", "lead_6")], q_lead = q),
                 type = c(q_lead = "average"), reference = "reference")
  meta <- data.frame(name = c("lead_6", "q_lead"), rationale = "early_stage",
                     frequency = c("monthly", "monthly"))
  expect_error(cli_candidates(x, "reference", meta = meta),
               class = "rcli_error_frequency", regexp = "q_lead.*quarterly")
})

test_that("R6: an annual candidate is refused before its type is asked", {
  ann <- ts(1:20, start = 2001, frequency = 1)
  ref <- ts(rnorm(240), start = 2001, frequency = 12)
  expect_error(cli_align(list(ref = ref, ann = ann), reference = "ref"),
               class = "rcli_error_frequency", regexp = "reference series")
})

test_that("R13: the date windows of the frequencies", {
  start <- as.Date("2001-01-01")
  frame <- function(step, n = 12) {
    data.frame(date = start + step * (0:(n - 1)), value = seq_len(n))
  }
  ref <- ts(rnorm(240), start = 2001, frequency = 12)
  for (step in c(175, 190)) {
    x <- cli_align(list(ref = ref, s = frame(step)), type = c(s = "flow"),
                   reference = "s")
    expect_equal(attr(x, "alignment")$from[2], "semiannual")
  }
  for (step in c(360, 370)) {
    x <- cli_align(list(ref = ref, a = frame(step)), type = c(a = "flow"),
                   reference = "a")
    expect_equal(attr(x, "alignment")$from[2], "annual")
  }
  for (step in c(150, 200, 300, 380)) {
    expect_error(cli_align(list(ref = ref, s = frame(step)),
                           type = c(s = "flow"), reference = "s"),
                 class = "rcli_error_frequency", regexp = "cannot tell")
  }
})
