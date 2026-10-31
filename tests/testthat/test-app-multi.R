# FR-009 AC-5 to AC-7 (rcli 0.4.0): step 1 accepts one file per indicator,
# at different frequencies, and step 2 aligns them with cli_align().

test_that("AC-FR-009.5/6/7: several files run through the ten steps", {
  skip_if_not_installed("shiny")
  html <- as.character(rcli:::app_ui("id"))
  expect_match(html, rcli:::app_text$id$src_upload_multi, fixed = TRUE)
  expect_match(html, 'id="files"', fixed = TRUE)
  expect_match(html, "multiple", fixed = TRUE)
  files <- multi_files()
  shiny::testServer(rcli:::app_server("en"), {
    session$setInputs(source = "upload_multi", csv_sep = "auto",
                      csv_dec = "auto", target_freq = "12", files = files)
    session$setInputs(run1 = 1)
    expect_equal(rv$done, 1L)
    expect_named(rv$series, c("pdb", "lead_6", "lead_3", "coincident",
                              "lag_3", "counter"))
    session$setInputs(reference = "pdb")
    tab <- as.character(output$data_summary)
    for (s in c("indikator.csv", "quarterly", "monthly", "1995Q1",
                "1995-01")) {
      expect_match(tab, s, fixed = TRUE)
    }
    expect_true(inherits(output$overview, "list"))
    # step 2: the reference type and the detected frequencies
    html <- as.character(output$meta_ui$html)
    expect_match(html, "ref_type", fixed = TRUE)
    row <- regmatches(html, regexpr("counter.*?frq_[0-9]+.*?</select>",
                                    html))
    expect_match(row, 'value="quarterly" selected', fixed = TRUE)
    session$setInputs(rat_1 = "early_stage", rat_2 = "early_stage",
                      rat_3 = "rapid_response", rat_4 = "rapid_response",
                      rat_5 = "expectations")
    # a series to convert without a type: step 2 is not completed
    session$setInputs(run2 = 1)
    expect_false(2L %in% rv$done)
    session$setInputs(ref_type = "average", typ_5 = "flow", run2 = 2)
    expect_true(2L %in% rv$done)
    expect_equal(stats::frequency(rv$cand@data), 12)
    expect_equal(rv$cand@reference, "pdb")
    expect_equal(rv$cand@meta$frequency[rv$cand@meta$name == "counter"],
                 "quarterly")
    expect_equal(rv$cand@meta$type[rv$cand@meta$name == "counter"], "flow")
    # steps 3 to 7
    session$setInputs(method = "rcli", filter = "hp_double",
                      aggregator = "equal", extend = TRUE,
                      transform = "auto", seasonal = FALSE, outlier = 5,
                      min_lead = 3, min_median_lead = 1,
                      min_consistency = 0.5, max_missed = 0.4,
                      max_extra = 0.4, alpha = 0.05, min_auc = 0.7,
                      min_components = 2, max_iter = 10, oos_cutoffs = "",
                      run3 = 1)
    session$setInputs(run4 = 1)
    session$setInputs(cyc_series = "lead_6", tp_series = "pdb",
                      as_series = "lead_6", run5 = 1)
    session$setInputs(run6 = 1)
    session$setInputs(comp_mode = "auto", run7 = 1)
    expect_true(all(1:7 %in% rv$done))
    # the script reads the files and aligns them as the interface did
    script <- script()
    expect_match(script, paste0('series <- read_cli_series(c("pdb.csv", ',
                                '"indikator.csv", "counter.csv"))'),
                 fixed = TRUE)
    expect_match(script, "data <- cli_align(series, freq = 12", fixed = TRUE)
    old <- setwd(dirname(files$datapath[1]))
    on.exit(setwd(old), add = TRUE)
    env <- new.env()
    utils::capture.output(eval(parse(text = script), envir = env))
    expect_equal(env$cand@data, rv$cand@data)
    expect_equal(components(env$res), rv$composite@components)
    expect_equal(as.numeric(composite(env$res)@index),
                 as.numeric(rv$composite@index))
    # the coincident index as reference keeps the chain reproducible
    session$setInputs(cci_mode = "auto", run9 = 1)
    session$setInputs(cci_ref = 1)
    expect_null(rv$series)
    expect_equal(rv$cand@reference, "cci")
    session$setInputs(reference = "cci")
    expect_false(grepl("ref_type", as.character(output$meta_ui$html),
                       fixed = TRUE))
    session$setInputs(run3 = 2)
    session$setInputs(run4 = 2)
    session$setInputs(tp_series = "cci", run5 = 2)
    session$setInputs(run6 = 2)
    session$setInputs(comp_mode = "auto", run7 = 2)
    env <- new.env()
    utils::capture.output(eval(parse(text = script()), envir = env))
    expect_equal(as.numeric(composite(env$res)@index),
                 as.numeric(rv$composite@index))
    # another source clears the files
    session$setInputs(source = "example_m", seed = 1, run1 = 2)
    expect_null(rv$series)
    expect_equal(rv$done, 1L)
  })
})

test_that("AC-FR-009.5: quarterly analysis and bad files", {
  skip_if_not_installed("shiny")
  files <- multi_files()
  shiny::testServer(rcli:::app_server("en"), {
    session$setInputs(source = "upload_multi", csv_sep = "auto",
                      csv_dec = "auto", target_freq = "4", files = files,
                      run1 = 1)
    expect_equal(rv$done, 1L)
    session$setInputs(reference = "pdb")
    # quarterly thresholds
    session$setInputs(rat_1 = "early_stage", rat_2 = "early_stage",
                      rat_3 = "early_stage", rat_4 = "early_stage",
                      rat_5 = "early_stage", typ_1 = "average",
                      typ_2 = "average", typ_3 = "average",
                      typ_4 = "average", run2 = 1)
    expect_true(2L %in% rv$done)
    expect_equal(stats::frequency(rv$cand@data), 4)
    expect_equal(rv$cand@meta$frequency[1], "monthly")
    script <- rcli:::app_script(current_state())
    expect_match(script, "cli_align(series, freq = 4", fixed = TRUE)
    # a file with bad dates changes nothing
    bad <- tempfile(fileext = ".csv")
    writeLines(c("date,value", "kemarin,1", "hari ini,2"), bad)
    session$setInputs(files = data.frame(name = "bad.csv", size = 1,
                                         type = "text/csv", datapath = bad),
                      run1 = 2)
    expect_equal(rv$done, 1:2)
    expect_named(rv$series, c("pdb", "lead_6", "lead_3", "coincident",
                              "lag_3", "counter"))
  })
})
