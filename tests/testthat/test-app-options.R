# FR-010 (rcli 0.5.0): package options that only code could use before,
# now in the interface; the exported script reproduces each of them.

step3_base <- list(method = "rcli", filter = "hp_double", aggregator = "equal",
                   extend = TRUE, transform = "auto", seasonal = FALSE,
                   outlier = 5, min_lead = 3, min_median_lead = 1,
                   min_consistency = 0.5, max_missed = 0.4, max_extra = 0.4,
                   alpha = 0.05, min_auc = 0.7, min_components = 2,
                   max_iter = 10, oos_cutoffs = "")

# Steps 1 and 2 on the simulated example, then step 3 with `inputs`.
with_step3 <- function(inputs, code, freq = "example_m") {
  shiny::testServer(rcli:::app_server("en"), {
    session$setInputs(source = freq, seed = 1, run1 = 1)
    session$setInputs(reference = "reference")
    n <- length(setdiff(colnames(rv$data), "reference"))
    do.call(session$setInputs,
            stats::setNames(as.list(rep("early_stage", n)),
                            paste0("rat_", seq_len(n))))
    session$setInputs(run2 = 1)
    do.call(session$setInputs, utils::modifyList(step3_base, inputs))
    session$setInputs(run3 = 1)
    code(rv, session)
  })
}

# The specification the script builds equals the one of the interface.
expect_script_spec <- function(rv) {
  env <- new.env()
  eval(parse(text = rv$spec_call), envir = env)
  expect_identical(env$spec, rv$spec)
}

test_that("AC-FR-010.1: the Idulfitri effect in seasonal adjustment", {
  skip_if_not_installed("shiny")
  html <- as.character(rcli:::app_ui("id"))
  expect_match(html, 'id="idulfitri"', fixed = TRUE)
  for (method in c("rcli", "oecd")) {
    with_step3(list(method = method, seasonal = TRUE, idulfitri = TRUE),
               function(rv, session) {
      expect_true(3L %in% rv$done)
      expect_length(rv$spec@holidays, 1L)
      expect_equal(rv$spec@holidays[[1]]@name, "idulfitri")
      expect_match(rv$spec_call, "holiday_effect(idulfitri_dates()",
                   fixed = TRUE)
      expect_script_spec(rv)
    })
  }
  # without seasonal adjustment the effect is not used
  with_step3(list(seasonal = FALSE, idulfitri = TRUE), function(rv, session) {
    expect_length(rv$spec@holidays, 0L)
    expect_false(grepl("holiday", rv$spec_call))
  })
})

test_that("AC-FR-010.4: classifier, outliers and lag shift one by one", {
  skip_if_not_installed("shiny")
  with_step3(list(classifier = "oecd", lag_shift = TRUE),
             function(rv, session) {
    expect_s4_class(rv$spec@classifier, "OecdClassifier")
    expect_true(rv$spec@lag_shift)
    expect_s4_class(rv$spec@aggregator, "EqualWeight")
    expect_script_spec(rv)
  })
  skip_if_not_installed("seasonal")
  with_step3(list(outlier_method = "tramo"), function(rv, session) {
    expect_s4_class(rv$spec@outliers, "TramoOutliers")
    expect_s4_class(rv$spec@classifier, "RcliClassifier")
    expect_script_spec(rv)
  })
})

test_that("AC-FR-010.5: filter and dating parameters", {
  skip_if_not_installed("shiny")
  cases <- list(
    list(list(filter = "hp_double", hp_trend_period = 100,
              hp_smooth_period = 10), "trend_period", 100),
    list(list(filter = "hp", hp_lambda = 14400), "lambda", 14400),
    list(list(filter = "cf", band_pl = 18, band_pu = 96), "pu", 96),
    list(list(filter = "bk", band_pl = 18, band_pu = 96, bk_k = 24), "k",
         24),
    list(list(filter = "hamilton", ham_h = 18, ham_p = 6), "h", 18)
  )
  for (cs in cases) {
    with_step3(cs[[1]], function(rv, session) {
      expect_equal(methods::slot(rv$spec@filter, cs[[2]]), cs[[3]])
      expect_script_spec(rv)
    })
  }
  with_step3(list(dater_min_phase = 7, dater_min_cycle = 18),
             function(rv, session) {
    expect_s4_class(rv$spec@dater, "BryBoschan")
    expect_equal(rv$spec@dater@min_phase, 7)
    expect_true(is.na(rv$spec@dater@window))
    expect_script_spec(rv)
  })
  with_step3(list(dater_window = 3, min_lead = 1, min_median_lead = 0.5),
             function(rv, session) {
    expect_s4_class(rv$spec@dater, "BBQ")
    expect_equal(rv$spec@dater@window, 3)
    expect_script_spec(rv)
  }, freq = "example_q")
})

test_that("AC-FR-010.6/7: thresholds, coverage, extension and defaults", {
  skip_if_not_installed("shiny")
  with_step3(list(coincident_band = 2, lead_window = "10, 20",
                  ccf_lag_max = 18, target_lead = "4, 8",
                  granger_max_lag = 6, granger_dmax = 2, horizon = 6,
                  agg_min_coverage = 0.8, ar_h = 6, ar_order_max = 4),
             function(rv, session) {
    s <- rv$spec
    expect_equal(s@coincident_band, 2)
    expect_equal(s@lead_window, c(10, 20))
    expect_equal(s@ccf_lag_max, 18)
    expect_equal(s@target_lead, c(4, 8))
    expect_equal(c(s@granger_max_lag, s@granger_dmax, s@horizon), c(6, 2, 6))
    expect_equal(s@aggregator@min_coverage, 0.8)
    expect_equal(c(s@extension@h, s@extension@order_max), c(6, 4))
    expect_script_spec(rv)
  })
  # empty entries keep the package defaults and stay out of the script
  with_step3(list(), function(rv, session) {
    expect_identical(rv$spec, cli_spec(12, outlier_threshold = 5,
                                       min_lead = 3, min_median_lead = 1))
    for (arg in c("lead_window", "coincident_band", "dater", "holidays",
                  "classifier", "lag_shift", "min_coverage")) {
      expect_false(grepl(arg, rv$spec_call, fixed = TRUE), info = arg)
    }
    expect_script_spec(rv)
  })
  # an invalid entry is refused and step 3 is not completed
  with_step3(list(filter = "cf", band_pl = 96, band_pu = 18),
             function(rv, session) {
    expect_false(3L %in% rv$done)
    expect_null(rv$spec)
  })
  with_step3(list(lead_window = "12"), function(rv, session) {
    expect_false(3L %in% rv$done)
  })
})

test_that("AC-FR-010.2: the three OECD forms in step 7 and the script", {
  skip_if_not_installed("shiny")
  sim <- simulate_cycles(seed = 1)
  meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
  cand <- cli_candidates(sim, "reference", meta = meta)
  res <- cli_build(cand)
  cli <- cli_composite(cycles(res), c("lead_6", "lead_3"), res@spec,
                       cycles(res)[["reference"]])
  manual <- res
  manual@composite <- cli
  expect_identical(cli_presentation(res, composite = cli),
                   cli_presentation(manual))
  expect_identical(cli_presentation(res, composite = NULL),
                   cli_presentation(res))
  expect_error(cli_presentation(res, composite = "x"),
               class = "rcli_error_argument")
  html <- as.character(rcli:::app_ui("en"))
  expect_match(html, 'id="pres_form"', fixed = TRUE)
  expect_match(html, 'id="dl_presentation"', fixed = TRUE)
  for (mode in c("auto", "manual")) {
    shiny::testServer(rcli:::app_server("en"), {
      session$userData$data <- function() rv$data
      run_all_steps(session, mode = mode, cutoffs = "")
      pres <- presentation()
      expect_named(pres, c("time", "amplitude_adjusted", "trend_restored",
                           "rate_of_change", "reference",
                           "reference_amplitude_adjusted", "reference_trend",
                           "reference_rate_of_change"))
      for (form in c("amplitude_adjusted", "trend_restored",
                     "rate_of_change")) {
        session$setInputs(pres_form = form)
        expect_true(inherits(output$pres_plot, "list"), info = form)
      }
      expect_equal(utils::read.csv(output$dl_presentation)$trend_restored,
                   pres$trend_restored, tolerance = 1e-12)
      script <- script()
      expect_match(script, "pres <- cli_presentation(res", fixed = TRUE)
      env <- new.env()
      utils::capture.output(eval(parse(text = script), envir = env))
      expect_equal(env$pres, pres)
    })
  }
})

test_that("AC-FR-010.3: alignment options for several files", {
  skip_if_not_installed("shiny")
  files <- multi_files()
  shiny::testServer(rcli:::app_server("en"), {
    session$setInputs(source = "upload_multi", csv_sep = "auto",
                      csv_dec = "auto", target_freq = "12", files = files,
                      run1 = 1)
    session$setInputs(reference = "pdb")
    html <- as.character(output$meta_ui$html)
    for (id in c("align_method", "week_date", "align_coverage")) {
      expect_match(html, sprintf('id="%s"', id), fixed = TRUE)
    }
    do.call(session$setInputs, stats::setNames(
      as.list(rep("early_stage", 5)), paste0("rat_", 1:5)))
    session$setInputs(ref_type = "average", typ_5 = "flow",
                      align_method = "linear", week_date = "end",
                      align_coverage = 0.5, run2 = 1)
    expect_true(2L %in% rv$done)
    expect_match(rv$cand@alignment$method[1], "linear")
    lines <- rcli:::data_lines(current_state())
    txt <- paste(lines, collapse = "\n")
    expect_match(txt, 'method = "linear"', fixed = TRUE)
    expect_match(txt, 'week_date = "end"', fixed = TRUE)
    expect_match(txt, "min_coverage = 0.5", fixed = TRUE)
    old <- setwd(dirname(files$datapath[1]))
    on.exit(setwd(old), add = TRUE)
    env <- new.env()
    eval(parse(text = txt), envir = env)
    expect_equal(as.numeric(env$data), as.numeric(rv$cand@data))
    # Chow-Lin needs an indicator
    session$setInputs(align_method = "chow-lin", align_indicator = "",
                      run2 = 2)
    expect_false(2L %in% rv$done)
    skip_if_not_installed("tempdisagg")
    session$setInputs(align_indicator = "coincident", run2 = 3)
    expect_true(2L %in% rv$done)
    # R2: the indicator is not a candidate
    expect_false("coincident" %in% colnames(rv$cand@data))
    expect_false("coincident" %in% rv$cand@meta$name)
    expect_match(rv$cand@alignment$method[1], "chow-lin")
    txt <- paste(rcli:::data_lines(current_state()), collapse = "\n")
    expect_match(txt, 'indicator = cli_align(series["coincident"]',
                 fixed = TRUE)
    env <- new.env()
    eval(parse(text = txt), envir = env)
    expect_equal(as.numeric(env$data), as.numeric(rv$cand@data))
    # the alignment options are not shown for one file
    session$setInputs(source = "example_m", seed = 1, run1 = 2)
    session$setInputs(reference = "reference")
    expect_false(grepl("align_method", as.character(output$meta_ui$html)))
  })
})

test_that("R1: names from files cannot run as code", {
  skip_if_not_installed("shiny")
  odd <- c('k" = "flow", zz = {writeLines("x", "PWNED"); "flow"}, "j',
           "back`tick", "a=b)", "line\nbreak", "ok")
  for (nm in odd) {
    txt <- rcli:::chr_text(stats::setNames("flow", nm))
    expect_identical(eval(parse(text = txt), envir = baseenv()),
                     stats::setNames("flow", nm), info = nm)
  }
  expect_equal(rcli:::chr_text(c(pdb = "average")), 'c(pdb = "average")')
  expect_equal(rcli:::chr_text("a\"b"), '"a\\"b"')
  # a quarterly file whose name tries to inject code
  dir <- tempfile("inject")
  dir.create(dir)
  bad <- 'k" = "flow", zz = {writeLines("x", "PWNED"); "flow"}, "j.csv'
  q <- paste0(rep(1995:2014, each = 4), "Q", 1:4)
  m <- format(seq(as.Date("1995-01-01"), by = "month", length.out = 240),
              "%Y-%m")
  sim <- simulate_cycles(seed = 1, n_years = 20)
  writeLines(c("date,value", paste0(q, ",", 100 + seq_along(q))),
             file.path(dir, "q.csv"))
  writeLines(c("date,a,b", paste0(m, ",", sim[, "lead_6"], ",",
                                  sim[, "lead_3"])), file.path(dir, "m.csv"))
  files <- data.frame(name = c(bad, "m.csv"), size = 1, type = "text/csv",
                      datapath = file.path(dir, c("q.csv", "m.csv")))
  old <- setwd(dir)
  on.exit(setwd(old), add = TRUE)
  shiny::testServer(rcli:::app_server("en"), {
    session$setInputs(source = "upload_multi", csv_sep = "auto",
                      csv_dec = "auto", target_freq = "12", files = files,
                      run1 = 1)
    ref <- sub("\\.csv$", "", bad)
    session$setInputs(reference = "a")
    session$setInputs(rat_1 = "early_stage", rat_2 = "early_stage",
                      typ_1 = "flow", run2 = 1)
    expect_false(file.exists(file.path(dir, "PWNED")))
    expect_true(2L %in% rv$done)
    expect_true(ref %in% colnames(rv$cand@data))
  })
})

test_that("R5/R6: the code calls exported functions and writes doubles", {
  input <- c(step3_base, list(
    seasonal = TRUE, idulfitri = TRUE, classifier = "oecd",
    outlier_method = "tramo", lag_shift = TRUE, filter = "bk",
    band_pl = 18, band_pu = 96, bk_k = 24, dater_min_phase = 7,
    agg_min_coverage = 0.8, ar_h = 6, lead_window = "10, 20",
    min_lead = 3L, max_iter = 10L))
  texts <- c(rcli:::spec_call(input, 12), rcli:::spec_call(input, 4),
             rcli:::spec_call(utils::modifyList(input, list(
               method = "oecd")), 12),
             rcli:::align_text(list(freq = 12, type = c(a = "flow"),
                                    reference = "a", method = "chow-lin",
                                    indicator = "b", week_date = "end",
                                    min_coverage = 0.5)))
  ns <- asNamespace("rcli")
  for (txt in texts) {
    called <- unique(all.names(parse(text = txt), functions = TRUE))
    ours <- called[vapply(called, exists, logical(1), envir = ns,
                          inherits = FALSE)]
    expect_true(all(ours %in% getNamespaceExports("rcli")),
                info = paste(setdiff(ours, getNamespaceExports("rcli")),
                             collapse = ", "))
  }
  expect_false(grepl("[0-9]L", texts[1]))
  expect_match(texts[1], "min_lead = 3,", fixed = TRUE)
})

test_that("R7: inputs without effect are hidden", {
  skip_if_not_installed("shiny")
  html <- as.character(rcli:::app_ui("en"))
  expect_match(html, "input.outlier_method != &#39;tramo&#39;", fixed = TRUE)
  files <- multi_files()
  shiny::testServer(rcli:::app_server("en"), {
    session$setInputs(source = "upload_multi", csv_sep = "auto",
                      csv_dec = "auto", target_freq = "4", files = files,
                      run1 = 1)
    # a quarterly reference in a quarterly analysis is not converted
    session$setInputs(reference = "pdb")
    html <- as.character(output$meta_ui$html)
    expect_false(grepl('id="align_method"', html, fixed = TRUE))
    expect_match(html, 'id="week_date"', fixed = TRUE)
  })
})

test_that("R9: crafted input values cannot run as code", {
  skip_if_not_installed("shiny")
  dir <- tempfile("r9")
  dir.create(dir)
  flag <- file.path(dir, "PWNED")
  evil_name <- sprintf('a" = 1, b = {writeLines("x", "%s")}, "c', flag)
  evil <- stats::setNames(list(1), evil_name)
  # numeric and choice inputs of step 3
  for (id in c("min_lead", "alpha", "ar_h", "hp_trend_period", "transform",
               "filter", "aggregator", "lead_window")) {
    with_step3(stats::setNames(list(evil), id), function(rv, session) {
      expect_false(3L %in% rv$done, info = id)
    })
    expect_false(file.exists(flag), info = id)
  }
  with_step3(list(min_lead = "3); writeLines('x', 'PWNED'); (1"),
             function(rv, session) expect_false(3L %in% rv$done))
  with_step3(list(transform = "auto\"); writeLines('x', 'PWNED'); (\""),
             function(rv, session) expect_false(3L %in% rv$done))
  # the alignment of step 2
  files <- multi_files()
  shiny::testServer(rcli:::app_server("en"), {
    session$setInputs(source = "upload_multi", csv_sep = "auto",
                      csv_dec = "auto", target_freq = "12", files = files,
                      run1 = 1)
    session$setInputs(reference = "pdb")
    do.call(session$setInputs, stats::setNames(
      as.list(rep("early_stage", 5)), paste0("rat_", 1:5)))
    for (bad in list(list(align_coverage = evil),
                     list(align_method = evil),
                     list(align_method = "linear\"); writeLines(1); (\""))) {
      do.call(session$setInputs, c(list(ref_type = "average",
                                        typ_5 = "flow"), bad))
      session$setInputs(run2 = 1)
      expect_false(2L %in% rv$done)
    }
    expect_false(file.exists(flag))
  })
  # a second line of defence: unexpected names are refused before running
  expect_error(rcli:::eval_code(
    sprintf('spec <- cli_spec(12, min_lead = {writeLines("x", "%s"); 3})',
            flag), "spec"), class = "rcli_error_argument")
  expect_false(file.exists(flag))
  expect_s4_class(rcli:::eval_code("spec <- cli_spec(freq = 12)", "spec"),
                  "CliSpec")
})

test_that("R10/R12: odd reference names in the script, ASCII names", {
  skip_if_not_installed("shiny")
  dir <- tempfile("r10")
  dir.create(dir)
  old <- setwd(dir)
  on.exit(setwd(old), add = TRUE)
  sim <- simulate_cycles(seed = 1)
  odd <- 'ref"); writeLines("x", "PWNED"); invisible("'
  colnames(sim)[1] <- odd
  shiny::testServer(rcli:::app_server("en"), {
    rv$data <- sim
    rv$loaded <- list(source = "example_m", seed = 1, frequency = 12)
    rv$done <- 1L
    session$setInputs(reference = odd)
    do.call(session$setInputs, stats::setNames(
      as.list(rep("early_stage", 7)), paste0("rat_", 1:7)))
    session$setInputs(run2 = 1)
    do.call(session$setInputs, step3_base)
    session$setInputs(run3 = 1, run4 = 1)
    session$setInputs(tp_series = odd, as_series = "lead_6", run5 = 1)
    session$setInputs(run6 = 1)
    session$setInputs(comp_mode = "manual",
                      manual_components = c("lead_6", "lead_3"), run7 = 1)
    expect_true(7L %in% rv$done)
    script <- sub("data <- simulate_cycles\\(freq = 12, seed = 1\\)",
                  "data <- sim", script())
    env <- new.env()
    env$sim <- sim
    utils::capture.output(eval(parse(text = script), envir = env))
    expect_false(file.exists("PWNED"))
    expect_equal(as.numeric(env$cli@index), as.numeric(rv$composite@index))
  })
  # names outside ASCII are quoted, so the script runs in any locale
  txt <- rcli:::chr_text(stats::setNames("flow", "ekspor_é"))
  expect_match(txt, "stats::setNames(", fixed = TRUE)
})
