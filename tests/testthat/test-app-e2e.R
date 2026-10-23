# End-to-end tests: the application runs in headless Chrome and is driven
# through the ten steps as a user would, with clicks on the step buttons
# and the "Next step" buttons. Skipped on CRAN and when Chrome is missing.

test_that("a user completes the ten steps in the browser", {
  skip_if_no_browser()
  app <- start_app("workflow-en", "en")
  on.exit(app$stop(), add = TRUE)

  # 1. Data
  expect_match(app$get_html("h2"), "Composite Leading Indicator")
  app$set_inputs(source = "example_m", wait_ = FALSE)
  app$click("run1")
  app$wait_for_idle()
  expect_equal(app$get_value(input = "reference"), "reference")
  expect_match(app$get_value(output = "data_summary"), "lead_6")
  expect_plot(app, "overview")
  expect_match(notifications(app), "Data loaded")
  shot(app, "step1-data")

  # 2. Candidate metadata: one rationale selector per candidate
  go_to(app, 2L)
  expect_equal(app$get_value(input = "rat_1"), "early_stage")
  expect_equal(app$get_value(input = "rat_7"), "early_stage")
  app$set_inputs(rat_6 = "prime_mover", src_6 = "BPS")
  app$click("run2")
  app$wait_for_idle()
  # regression: the choices must survive the re-run of later steps
  expect_equal(app$get_value(input = "rat_6"), "prime_mover")
  expect_equal(app$get_value(input = "src_6"), "BPS")
  expect_match(app$get_value(output = "cand_print"), "7 candidate")
  expect_match(app$get_value(output = "cand_print"), "prime_mover")
  shot(app, "step2-metadata")

  # 3. Specification
  go_to(app, 3L)
  app$set_inputs(oos_cutoffs = "2012, 2016", wait_ = FALSE)
  app$click("run3")
  expect_match(app$get_value(output = "spec_print"),
               "OECD double Hodrick-Prescott")
  shot(app, "step3-specification")

  # 4. Cycles
  go_to(app, 4L)
  app$click("run4")
  app$wait_for_idle()
  app$set_inputs(cyc_series = "lead_6", wait_ = FALSE)
  app$wait_for_idle()
  expect_plot(app, "cycle_pair")
  expect_plot(app, "cycles_grid")
  expect_match(app$get_value(output = "cycle_steps"), "normalised")
  shot(app, "step4-cycles")

  # 5. Turning points
  go_to(app, 5L)
  app$click("run5")
  app$wait_for_idle()
  app$set_inputs(tp_series = "reference", wait_ = FALSE)
  app$wait_for_idle()
  expect_match(app$get_value(output = "tp_counts"), "troughs")
  expect_plot(app, "tp_plot")
  expect_match(app$get_value(output = "tp_table"), "peak")
  shot(app, "step5-turning-points")

  # 6. Classification
  go_to(app, 6L)
  app$click("run6")
  app$wait_for_idle()
  tab <- app$get_value(output = "assess_table")
  expect_match(tab, "leading")
  expect_match(tab, "counter_4 \\*")
  expect_plot(app, "leads_plot")
  app$set_inputs(as_series = "lead_6", wait_ = FALSE)
  app$wait_for_idle()
  expect_plot(app, "ccf_plot")
  expect_plot(app, "aligned_plot")
  expect_match(app$get_value(output = "reasons"), "rejected")
  shot(app, "step6-classification")

  # 7. Composite (automatic selection loop)
  go_to(app, 7L)
  expect_setequal(app$get_value(input = "manual_components"),
                  c("lead_6", "lead_3", "counter_4"))
  app$click("run7")
  app$wait_for_idle()
  for (id in c("composite_plot", "weights_plot", "components_plot",
               "audit_plot")) {
    expect_plot(app, id)
  }
  expect_match(app$get_value(output = "audit_table"), "accepted")
  shot(app, "step7-composite")

  # 8. Validation: acceptable before, good after the out-of-sample check
  go_to(app, 8L)
  expect_text_soon(app, "#verdict", "ACCEPTABLE")
  app$click("run8")
  app$wait_for_idle(timeout = 120000)
  expect_text_soon(app, "#verdict", "GOOD")
  expect_match(app$get_value(output = "scorecard"), "out of sample")
  expect_match(app$get_value(output = "sb_table"), "2016")
  for (id in c("roc_plot", "prob_plot", "sb_plot")) expect_plot(app, id)
  shot(app, "step8-validation")

  # 9. Coincident index: the coincident candidate is preselected
  go_to(app, 9L)
  expect_equal(app$get_value(input = "cci_components"), "coincident")
  app$click("run9")
  app$wait_for_idle(timeout = 120000)
  expect_text_soon(app, "#cci_verdict", "ACCEPTABLE")
  expect_match(app$get_value(output = "cci_scorecard"), "median lead")
  expect_match(app$get_value(output = "cci_audit"), "initial index")
  for (id in c("cci_plot", "cci_weights_plot", "cci_components_plot")) {
    expect_plot(app, id)
  }
  shot(app, "step9-coincident")

  # 10. Export: every download works and the script reproduces the result
  go_to(app, 10L)
  shot(app, "step10-export")
  csv <- utils::read.csv(app$get_download("dl_cli"))
  expect_named(csv, c("time", "index", "cycle"))
  expect_equal(nrow(csv), 360)
  expect_true("class" %in% names(utils::read.csv(app$get_download("dl_assess"))))
  expect_true("action" %in% names(utils::read.csv(app$get_download("dl_audit"))))
  q <- utils::read.csv(app$get_download("dl_quality"))
  expect_true(all(q$passed[q$group != "information"]))
  res <- readRDS(app$get_download("dl_rds"))
  expect_s4_class(res, "CliResult")
  env <- new.env()
  utils::capture.output(source(app$get_download("dl_script"), local = env))
  expect_equal(components(env$res), components(res))
  # the script carries the out-of-sample cut-offs, so it reaches the same
  # verdict as the interface
  expect_equal(cli_quality(env$res)@verdict, "good")
  # FR-005 AC-3: the script reproduces the coincident index as well
  expect_equal(as.numeric(env$cci@composite@index),
               utils::read.csv(app$get_download("dl_cci"))$index)
  expect_true("criterion" %in%
                names(utils::read.csv(app$get_download("dl_cci_quality"))))

  expect_match(app$get_html("#progress"), "\u25CF 9")
  expect_match(app$get_html("#progress"), "\u25CF 10")
  expect_no_browser_errors(app)
})

test_that("steps cannot be skipped in the browser", {
  skip_if_no_browser()
  app <- start_app("gating", "en")
  on.exit(app$stop(), add = TRUE)
  app$set_inputs(step = "s6")
  app$click("run6")
  app$wait_for_idle()
  expect_match(notifications(app), "Complete the previous step first")
  expect_text_soon(app, "#assess_table", "Complete the previous step first")
  app$set_inputs(step = "s8")
  expect_text_soon(app, "#scorecard", "Complete the previous step first")
  expect_no_browser_errors(app)
})

test_that("an uploaded quarterly CSV runs through the Indonesian interface", {
  skip_if_no_browser()
  sim <- simulate_cycles(freq = 4, seed = 2)
  tm <- stats::time(sim)
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  utils::write.csv(data.frame(
    tanggal = sprintf("%dQ%d", floor(tm + 1e-8), round((tm %% 1) * 4) + 1),
    as.data.frame(sim)), path, row.names = FALSE)

  app <- start_app("upload-id", "id")
  on.exit(app$stop(), add = TRUE)
  expect_match(app$get_html("h2"), "Indikator Komposit Pendahulu")
  app$set_inputs(source = "upload", wait_ = FALSE)
  app$upload_file(file = path)
  app$click("run1")
  app$wait_for_idle()
  expect_match(app$get_value(output = "data_summary"), "1995Q1")
  expect_match(app$get_value(output = "data_summary"), "observasi")
  expect_equal(app$get_value(input = "min_lead"), 1)

  go_to(app, 2L)
  n <- ncol(sim) - 1L
  inputs <- stats::setNames(as.list(rep("rapid_response", n)),
                            paste0("rat_", seq_len(n)))
  do.call(app$set_inputs, c(inputs, wait_ = FALSE))
  app$click("run2")
  go_to(app, 3L)
  app$set_inputs(aggregator = "dfm", filter = "cf", wait_ = FALSE)
  app$click("run3")
  expect_match(app$get_value(output = "spec_print"), "Christiano-Fitzgerald")
  for (k in 4:6) {
    go_to(app, k)
    app$click(paste0("run", k))
    app$wait_for_idle()
  }
  go_to(app, 7L)
  app$set_inputs(comp_mode = "manual", wait_ = FALSE)
  app$set_inputs(manual_components = c("lead_2", "lead_1"), wait_ = FALSE)
  app$click("run7")
  app$wait_for_idle()
  audit <- app$get_value(output = "audit_table")
  expect_match(audit, "pemilihan manual")
  expect_match(audit, "tindakan")
  expect_plot(app, "composite_plot")
  go_to(app, 8L)
  expect_text_soon(app, "#verdict", "Vonis mutu")
  score <- app$get_value(output = "scorecard")
  expect_match(score, "titik balik")
  expect_match(score, "lolos|GAGAL")
  app$click("run8")
  expect_match(notifications(app), "titik potong")
  shot(app, "upload-id-step8")
  go_to(app, 9L)
  app$click("run9")
  app$wait_for_idle(timeout = 120000)
  expect_text_soon(app, "#cci_verdict", "Vonis mutu")
  expect_match(app$get_value(output = "cci_audit"), "indeks awal")
  go_to(app, 10L)
  script <- readLines(app$get_download("dl_script"))
  expect_true(any(grepl("cci_build(res)", script, fixed = TRUE)))
  expect_true(any(grepl("read_cli_data", script)))
  expect_true(any(grepl("dynamic_factor()", script, fixed = TRUE)))
  expect_true(any(grepl("cli_composite(cycles(res)", script, fixed = TRUE)))
  expect_no_browser_errors(app)
})

test_that("a malformed CSV gives an error message and the app keeps working", {
  skip_if_no_browser()
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  writeLines(c("date,gdp,sales", "Jan 2001,1,2", "Feb 2001,2,3"), path)
  app <- start_app("bad-csv", "en")
  on.exit(app$stop(), add = TRUE)
  app$set_inputs(source = "upload", wait_ = FALSE)
  app$upload_file(file = path)
  app$click("run1")
  app$wait_for_idle()
  expect_match(notifications(app), "Error")
  expect_text_soon(app, "#data_summary", "Complete the previous step first")
  app$set_inputs(source = "example_q", wait_ = FALSE)
  app$click("run1")
  app$wait_for_idle()
  expect_match(app$get_value(output = "data_summary"), "Q1")
  expect_no_browser_errors(app)
})
