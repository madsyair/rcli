test_that("dates in CSV files are parsed", {
  q <- rcli:::parse_dates(c("2001Q1", "2001Q2", "2001-Q3"))
  expect_equal(q, list(frequency = 4, start = c(2001L, 1L)))
  m <- rcli:::parse_dates(c("2001-11", "2001-12", "2002-01"))
  expect_equal(m$start, c(2001L, 11L))
  d <- rcli:::parse_dates(c("2001-01-31", "2001-04-30"), frequency = 4)
  expect_equal(d, list(frequency = 4, start = c(2001L, 1L)))
  expect_error(rcli:::parse_dates(c("2001Q1", "2001Q3")),
               class = "rcli_error_dates")
  expect_error(rcli:::parse_dates("Jan 2001"), class = "rcli_error_dates")
})

test_that("read_cli_data reads files and data frames", {
  sim <- simulate_cycles(seed = 1, n_years = 8)
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f))
  tm <- time(sim)
  dates <- sprintf("%d-%02d", floor(tm + 1e-8), round((tm %% 1) * 12) + 1)
  utils::write.csv(data.frame(date = dates, as.data.frame(sim)), f,
                   row.names = FALSE)
  x <- read_cli_data(f)
  expect_equal(frequency(x), 12)
  expect_equal(start(x), c(1995, 1))
  expect_equal(unname(x[, "lead_6"]), unname(sim[, "lead_6"]),
               tolerance = 1e-6)
  y <- read_cli_data(as.data.frame(sim), frequency = 12, start = c(1995, 1))
  expect_equal(ncol(y), ncol(sim))
  expect_error(read_cli_data(as.data.frame(sim)), class = "rcli_error_argument")
  expect_error(read_cli_data(data.frame(a = 1:3)),
               class = "rcli_error_argument")
  expect_error(read_cli_data(data.frame(a = c("x", "y"), b = c("u", "v")),
                             frequency = 4, start = c(2000, 1)),
               class = "rcli_error_dates")
})

test_that("small server helpers", {
  expect_equal(rcli:::parse_cutoffs("2010, 2015"), c(2010, 2015))
  expect_equal(rcli:::parse_cutoffs(""), numeric(0))
  expect_error(rcli:::parse_cutoffs("abc"), class = "rcli_error_argument")
  expect_equal(rcli:::parse_start("2000-3"), c(2000L, 3L))
  expect_null(rcli:::parse_start(" "))
  expect_error(rcli:::parse_start("2000"), class = "rcli_error_argument")
  for (k in c("hp_double", "hp", "cf", "bk", "hamilton")) {
    expect_s4_class(rcli:::make_filter(k), "CycleFilter")
  }
  for (k in c("equal", "pca", "cb", "dfm")) {
    expect_s4_class(rcli:::make_aggregator(k), "Aggregator")
  }
  tr <- rcli:::app_translator("en")
  expect_equal(tr("s1"), "1. Data")
  expect_equal(tr("unknown_key"), "unknown_key")
  expect_setequal(names(rcli:::app_text$id), names(rcli:::app_text$en))
})

test_that("the interface builds in both languages", {
  skip_if_not_installed("shiny")
  for (lang in c("id", "en")) {
    ui <- rcli:::app_ui(lang)
    html <- as.character(ui)
    expect_match(html, rcli:::app_text[[lang]]$s9, fixed = TRUE)
  }
  expect_error(run_app("xx"))
})

test_that("the server runs the ten steps in order", {
  skip_if_not_installed("shiny")
  server <- function(input, output, session) {
    rcli:::app_server("en")(input, output, session)
  }
  shiny::testServer(rcli:::app_server("en"), {
    session$userData$data <- function() rv$data
    # steps cannot be skipped
    session$setInputs(run4 = 1)
    expect_null(rv$cycles)
    run_all_steps(session)
    expect_true(all(1:7 %in% rv$done))
    expect_s4_class(rv$cand, "CandidateSet")
    expect_equal(rv$cand@meta$type[1:3], c("stock", "flow", NA))
    expect_s4_class(rv$spec, "CliSpec")
    expect_equal(rv$spec@oos_cutoffs, c(2012, 2016))
    expect_true("counter_4" %in% rv$assessment@inverted)
    expect_setequal(rv$composite@components,
                    c("lead_6", "lead_3", "counter_4"))
    expect_match(output$data_summary, "lead_6")
    expect_match(output$assess_table, "leading")
    expect_match(output$scorecard, "turning points")
    expect_equal(quality()@verdict, "acceptable")
    session$setInputs(run8 = 1)
    expect_equal(nrow(rv$validation@out_of_sample), 2)
    expect_equal(quality()@verdict, "good")
    for (o in c("overview", "cycle_pair", "cycles_grid", "tp_plot",
                "leads_plot", "ccf_plot", "aligned_plot", "composite_plot",
                "weights_plot", "components_plot", "audit_plot", "roc_plot",
                "prob_plot", "sb_plot")) {
      expect_type(output[[o]], "list")
    }
    expect_match(output$script, "cli_build(cand, spec)", fixed = TRUE)
    script <- script()
    expect_match(script, "simulate_cycles(freq = 12, seed = 1)", fixed = TRUE)
    expect_match(script, 'type = c("stock", "flow", NA', fixed = TRUE)
    eval_env <- new.env()
    out <- utils::capture.output(eval(parse(text = script), envir = eval_env))
    expect_equal(components(eval_env$res), rv$composite@components)
    expect_s4_class(result(), "CliResult")
    # 9. coincident index, built from the classification of step 6
    expect_equal(coincidents(rv$assessment), "coincident")
    session$setInputs(cci_mode = "auto", run9 = 1)
    expect_s4_class(rv$cci, "CciResult")
    expect_equal(rv$cci@composite@components, "coincident")
    expect_equal(rv$cci@validation@role, "coincident")
    expect_equal(nrow(rv$cci@validation@out_of_sample), 2)
    expect_equal(cci_quality()@verdict, "good")
    expect_match(output$cci_scorecard, "median lead at turning points")
    expect_match(output$cci_audit, "initial index")
    expect_match(output$cci_print, "coincident index")
    for (o in c("cci_plot", "cci_weights_plot", "cci_components_plot")) {
      expect_type(output[[o]], "list")
    }
    script <- script()
    expect_match(script, "cci <- cci_build(res)", fixed = TRUE)
    eval_env <- new.env()
    out <- utils::capture.output(eval(parse(text = script), envir = eval_env))
    expect_equal(as.numeric(eval_env$cci@composite@index),
                 as.numeric(rv$cci@composite@index))
    for (d in c("dl_cci", "dl_cci_quality")) {
      expect_true(file.exists(output[[d]]))
    }
    expect_named(utils::read.csv(output$dl_cci), c("time", "index", "cycle"))
    # rebuilding the composite keeps the index; manual mode keeps every
    # chosen component
    session$setInputs(run7 = 2)
    expect_s4_class(rv$cci, "CciResult")
    session$setInputs(cci_mode = "manual",
                      cci_components = c("coincident", "lag_3"), run9 = 2)
    expect_equal(rv$cci@composite@components, c("coincident", "lag_3"))
    expect_match(script(), "select = FALSE", fixed = TRUE)
    manual_env <- new.env()
    utils::capture.output(eval(parse(text = script()), envir = manual_env))
    expect_equal(as.numeric(manual_env$cci@composite@index),
                 as.numeric(rv$cci@composite@index))
    # re-running an early step clears the later ones
    session$setInputs(run3 = 2)
    expect_null(rv$cycles)
    expect_null(rv$cci)
    expect_false(7L %in% rv$done)
  })
})

test_that("FR-003 AC-3: every aggregation x extension script reproduces", {
  skip_if_not_installed("shiny")
  combos <- expand.grid(aggregator = c("equal", "equal_level"),
                        extend = c(TRUE, FALSE), stringsAsFactors = FALSE)
  for (i in seq_len(nrow(combos))) {
    shiny::testServer(rcli:::app_server("en"), {
      session$userData$data <- function() rv$data
      run_all_steps(session, mode = "manual", cutoffs = "",
                    aggregator = combos$aggregator[i],
                    extend = combos$extend[i])
      script <- script()
      expect_match(script, if (combos$extend[i]) "ar_extension()" else
        "no_extension()", fixed = TRUE)
      eval_env <- new.env()
      out <- utils::capture.output(eval(parse(text = script),
                                        envir = eval_env))
      expect_equal(as.numeric(eval_env$cli@index),
                   as.numeric(rv$composite@index))
    })
  }
})

test_that("the OECD method runs in the interface and in the script", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("seasonal")
  skip_on_cran()
  shiny::testServer(rcli:::app_server("id"), {
    session$userData$data <- function() rv$data
    run_all_steps(session, mode = "manual", cutoffs = "", method = "oecd")
    expect_s4_class(rv$spec@classifier, "OecdClassifier")
    expect_true(rv$spec@lag_shift)
    expect_equal(names(rv$composite@shifts), c("lead_6", "lead_3"))
    expect_match(output$spec_print, "OECD")
    expect_match(output$scorecard, "rata-rata lead")
    script <- script()
    expect_match(script, "oecd_spec(", fixed = TRUE)
    expect_match(script, "shifts = lag_shifts(", fixed = TRUE)
    eval_env <- new.env()
    out <- utils::capture.output(eval(parse(text = script), envir = eval_env))
    expect_equal(as.numeric(eval_env$cli@index),
                 as.numeric(rv$composite@index))
  })
  expect_match(rcli:::spec_call(list(method = "oecd", seasonal = FALSE,
                                     alpha = 0.05, min_auc = 0.7,
                                     min_components = 2, max_iter = 10,
                                     oos_cutoffs = "2015"), 12),
               "oos_cutoffs = 2015", fixed = TRUE)
})

test_that("manual composites, uploads and downloads work", {
  skip_if_not_installed("shiny")
  sim <- simulate_cycles(freq = 4, seed = 2)
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f))
  tm <- time(sim)
  dates <- sprintf("%dQ%d", floor(tm + 1e-8), round((tm %% 1) * 4) + 1)
  utils::write.csv(data.frame(date = dates, as.data.frame(sim)), f,
                   row.names = FALSE)
  shiny::testServer(rcli:::app_server("id"), {
    session$userData$data <- function() rv$data
    session$setInputs(file = list(datapath = f, name = "q.csv"))
    session$setInputs(source = "upload", seed = 1, freq = "auto", start = "",
                      run1 = 1)
    expect_equal(frequency(rv$data), 4)
    session$setInputs(reference = "reference")
    n <- ncol(rv$data) - 1L
    do.call(session$setInputs, stats::setNames(
      as.list(rep("rapid_response", n)), paste0("rat_", seq_len(n))))
    session$setInputs(run2 = 1)
    session$setInputs(filter = "cf", aggregator = "dfm", transform = "auto",
                      seasonal = FALSE, outlier = 5, min_lead = 1,
                      min_median_lead = 0.5, min_consistency = 0.5,
                      max_missed = 0.4, max_extra = 0.4, alpha = 0.05,
                      min_auc = 0.7, min_components = 2, max_iter = 10,
                      oos_cutoffs = "", run3 = 1)
    session$setInputs(run4 = 1, run5 = 1, run6 = 1)
    session$setInputs(comp_mode = "manual",
                      manual_components = c("lead_2", "lead_1"), run7 = 1)
    expect_equal(rv$composite@components, c("lead_2", "lead_1"))
    expect_s4_class(rv$composite@aggregator, "DynamicFactor")
    expect_equal(rv$audit$action, "manual selection")
    session$setInputs(run8 = 1)
    expect_equal(nrow(rv$validation@out_of_sample), 0)
    # the coincident index needs a choice of components when none is
    # coincident; an empty manual choice is refused
    session$setInputs(cci_mode = "manual", cci_components = character(0),
                      run9 = 1)
    expect_null(rv$cci)
    expect_match(script(), "read_cli_data(\"q.csv\"", fixed = TRUE)
    expect_match(script(), "cli_composite(cycles(res)", fixed = TRUE)
    for (d in c("dl_cli", "dl_assess", "dl_audit", "dl_quality", "dl_rds",
                "dl_script")) {
      path <- output[[d]]
      expect_true(file.exists(path))
    }
    expect_s4_class(readRDS(output$dl_rds), "CliResult")
    # changing the reference invalidates the candidate set
    session$setInputs(reference = "lead_2")
    expect_null(rv$cand)
  })
})

test_that("plot helpers draw without error", {
  cand <- sim_candidates(seed = 1)
  res <- cli_build(cand, cli_spec(12, oos_cutoffs = c(2010, 2016)))
  cyc <- cycles(res)
  tps <- turning_points(res)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  expect_silent({
    rcli:::plot_series_overview(cand@data, "reference")
    rcli:::plot_cycle_pair(cyc, "reference", "lead_6", tps$reference, 6L)
    rcli:::plot_cycles_grid(cyc)
    rcli:::plot_turning_points(tps$lead_6, tps$reference)
    rcli:::plot_leads(assessment(res), res@spec)
    rcli:::plot_ccf(cyc, "reference", "lead_6", 24)
    rcli:::plot_composite(composite(res), cyc$reference, tps$reference)
    rcli:::plot_weights(composite(res))
    rcli:::plot_components(cyc, composite(res))
    rcli:::plot_audit(audit_log(res))
    pr <- contraction_probability(composite(res), cyc$reference, res@spec)
    rcli:::plot_probability(pr, tps$reference)
    rcli:::plot_roc(roc_curve(pr$probability, pr$contraction), 0.9)
    rcli:::plot_selection_bias(validation(res)@out_of_sample)
  })
  cb <- cli_composite(cyc, c("lead_6", "lead_3"),
                      update(res@spec, aggregator = conference_board()),
                      cyc$reference)
  expect_silent(rcli:::plot_composite(cb, cyc$reference, tps$reference))
  neg <- simulate_cycles(seed = 1, n_years = 8)
  neg[, "lag_3"] <- neg[, "lag_3"] - 500
  expect_silent(rcli:::plot_series_overview(neg, "reference"))
  expect_null(rcli:::plot_audit(audit_log(res)[0, ]))
  expect_null(rcli:::plot_selection_bias(
    validation(res)@out_of_sample[0, ]))
})

test_that("failed criteria are translated in the Indonesian interface", {
  x <- c("ccf, lead, consistency", "", "granger")
  expect_identical(translate_reasons(x, "en"), x)
  expect_identical(
    translate_reasons(x, "id"),
    c("lead korelasi silang, median lead, konsistensi", "", "Granger")
  )
})

test_that("coincident phrases are translated", {
  p <- rcli:::phrase_translator("id")
  expect_equal(p("coincident index"), "indeks sejalan")
  expect_equal(p("initial index of all coincident candidates"),
               "indeks awal dari semua kandidat sejalan")
  expect_equal(p("lag of the cross-correlation peak"),
               "lag puncak korelasi silang")
  q <- cli_quality(cci_build(sim_candidates(seed = 1)))
  shown <- rcli:::quality_display(q, p)
  expect_true(any(grepl("dalam", shown$ambang)))
  expect_false(any(grepl("within", shown$ambang)))
})

test_that("the scorecard row for a disaggregated reference is translated", {
  p <- rcli:::phrase_translator("id")
  expect_equal(p("reference disaggregated from quarterly data"),
               "seri acuan hasil disagregasi data triwulanan")
  expect_match(p("turning points +/- 1 month"), "1 bulan")
})
