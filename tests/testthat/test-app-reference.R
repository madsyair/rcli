# FR-006 (rcli 0.3.0): the title shows the version, and step 9 can make the
# coincident index the reference series of a new analysis
# (cci_as_reference()); the exported script reproduces the whole chain.

test_that("the title names both indices and the package version", {
  skip_if_not_installed("shiny")
  v <- as.character(utils::packageVersion("rcli"))
  html <- as.character(rcli:::app_ui("id"))
  expect_match(html, paste0("rcli ", v, ": Indikator Komposit Pendahulu ",
                            "dan Sejalan"), fixed = TRUE)
  html <- as.character(rcli:::app_ui("en"))
  expect_match(html, paste0("rcli ", v, ": Composite Leading and ",
                            "Coincident Indicators"), fixed = TRUE)
  expect_match(html, rcli:::app_text$en$cci_ref, fixed = TRUE)
})

test_that("the coincident index becomes the reference of a new analysis", {
  skip_if_not_installed("shiny")
  shiny::testServer(rcli:::app_server("en"), {
    session$userData$data <- function() rv$data
    # the button needs a coincident index
    session$setInputs(cci_ref = 1)
    expect_null(rv$prelude)
    run_all_steps(session)
    session$setInputs(cci_mode = "auto", run9 = 1)
    cci <- rv$cci
    session$setInputs(cci_ref = 2)
    # steps 1 and 2 hold the new candidate set, the later steps are cleared
    expect_equal(rv$cand@reference, "cci")
    expect_equal(rv$done, 1:2)
    expect_null(rv$spec)
    expect_null(rv$cci)
    expect_false("coincident" %in% colnames(rv$data))
    expect_equal(colnames(rv$data)[1], "cci")
    expect_equal(as.numeric(rv$data[, "cci"]),
                 as.numeric(cci@composite@index))
    # the metadata of the remaining candidates is kept, by name
    expect_equal(rv$meta$type[rv$meta$name == "lead_6"], "stock")
    expect_equal(rv$meta$type[rv$meta$name == "lead_3"], "flow")
    session$setInputs(reference = "cci")
    expect_equal(rv$done, 1:2)
    html <- as.character(output$meta_ui$html)
    # rationale, direction, then type
    row_lead3 <- regmatches(html, regexpr(
      "lead_3.*?</select>.*?</select>.*?</select>", html))
    expect_match(row_lead3, 'value="flow" selected', fixed = TRUE)
    # steps 3 to 7 run against the index
    session$setInputs(run3 = 2)
    session$setInputs(run4 = 2)
    session$setInputs(tp_series = "cci", as_series = "lead_6", run5 = 2)
    session$setInputs(run6 = 2)
    session$setInputs(comp_mode = "auto", run7 = 2)
    expect_true(all(1:7 %in% rv$done))
    expect_equal(reference(), "cci")
    expect_true("lead_6" %in% rv$composite@components)
    script <- script()
    expect_match(script, "cand <- cci_as_reference(cci)", fixed = TRUE)
    expect_false(grepl("# cand_cci <-", script, fixed = TRUE))
    env <- new.env()
    utils::capture.output(eval(parse(text = script), envir = env))
    expect_equal(env$cand@reference, "cci")
    expect_equal(components(env$res), rv$composite@components)
    expect_equal(as.numeric(composite(env$res)@index),
                 as.numeric(rv$composite@index))
    # editing the metadata again rebuilds the candidates in the script too
    n <- ncol(rv$data) - 1L
    do.call(session$setInputs,
            stats::setNames(as.list(rep("rapid_response", n)),
                            paste0("rat_", seq_len(n))))
    session$setInputs(run2 = 2, run3 = 3, run4 = 3, run5 = 3, run6 = 3,
                      run7 = 3)
    script <- script()
    expect_match(script,
                 "cand <- cli_candidates(cand@data, reference = \"cci\"",
                 fixed = TRUE)
    env <- new.env()
    utils::capture.output(eval(parse(text = script), envir = env))
    expect_equal(env$cand@meta$rationale, rv$cand@meta$rationale)
    expect_equal(as.numeric(composite(env$res)@index),
                 as.numeric(rv$composite@index))
    # loading data again starts from scratch
    session$setInputs(run1 = 5)
    expect_null(rv$prelude)
    expect_equal(rv$done, 1L)
  })
})

test_that("R3: a manual composite from before a reset does not leak", {
  skip_if_not_installed("shiny")
  shiny::testServer(rcli:::app_server("en"), {
    session$userData$data <- function() rv$data
    run_all_steps(session, mode = "manual")
    expect_equal(rv$mode, "manual")
    # step 3 again: steps 4 to 9 are redone, step 7 is skipped
    session$setInputs(run3 = 2, run4 = 2, run5 = 2, run6 = 2)
    expect_null(rv$mode)
    expect_null(rv$components)
    session$setInputs(cci_mode = "auto", run9 = 1, cci_ref = 1)
    session$setInputs(reference = "cci")
    session$setInputs(run3 = 3, run4 = 3, run5 = 3, run6 = 3,
                      comp_mode = "auto", run7 = 3)
    env <- new.env()
    utils::capture.output(eval(parse(text = script()), envir = env))
    expect_equal(as.numeric(composite(env$res)@index),
                 as.numeric(rv$composite@index))
  })
})

test_that("the script uses the data as loaded in step 1", {
  skip_if_not_installed("shiny")
  shiny::testServer(rcli:::app_server("en"), {
    session$userData$data <- function() rv$data
    run_all_steps(session)
    session$setInputs(seed = 99)
    expect_match(script(), "simulate_cycles(freq = 12, seed = 1)",
                 fixed = TRUE)
  })
})
