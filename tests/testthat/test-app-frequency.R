# FR-007 AC-7 (rcli 0.2.2): the source frequency of each candidate in step 2.

test_that("step 2 records the source frequency of each candidate", {
  skip_if_not_installed("shiny")
  html <- as.character(rcli:::app_ui("id"))
  expect_true(all(c("var_freq", "freq_annual") %in%
                    names(rcli:::app_text$id)))
  shiny::testServer(rcli:::app_server("en"), {
    session$setInputs(source = "example_m", seed = 1, freq = "auto",
                      start = "", run1 = 1)
    session$setInputs(reference = "reference")
    html <- as.character(output$meta_ui$html)
    expect_match(html, "frq_1", fixed = TRUE)
    expect_match(html, rcli:::app_text$en$freq_semiannual, fixed = TRUE)
    session$setInputs(rat_1 = "early_stage", rat_2 = "early_stage",
                      frq_1 = "weekly", frq_2 = "quarterly", run2 = 1)
    expect_equal(rv$cand@meta$frequency[1:3], c("weekly", "quarterly", NA))
    # a semiannual candidate is refused and step 2 is not completed
    session$setInputs(frq_3 = "semiannual", run2 = 2)
    expect_false(2L %in% rv$done)
    expect_null(rv$cand)
    session$setInputs(frq_3 = "", run2 = 3)
    expect_true(2L %in% rv$done)
    # the frequencies reach the exported script
    lines <- rcli:::candidate_lines(list(meta = rv$meta,
                                         reference = "reference"), "data")
    expect_true(any(grepl('frequency = c("weekly", "quarterly", NA',
                          lines, fixed = TRUE)))
    # and are kept by name when the reference changes
    session$setInputs(reference = "lead_6")
    html <- as.character(output$meta_ui$html)
    row <- regmatches(html, regexpr("lead_3.*?frq_[0-9]+.*?</select>", html))
    expect_match(row, 'value="quarterly" selected', fixed = TRUE)
  })
})

test_that("R1: step-2 entries follow the candidate names, not positions", {
  skip_if_not_installed("shiny")
  shiny::testServer(rcli:::app_server("en"), {
    session$setInputs(source = "example_m", seed = 1, freq = "auto",
                      start = "", run1 = 1)
    session$setInputs(reference = "reference")
    invisible(output$meta_ui)
    # lead_6 is first and lead_3 second; with lead_3 as reference, lead_6
    # becomes second, where lead_3's entries were
    session$setInputs(typ_1 = "stock", typ_2 = "flow", frq_1 = "weekly")
    session$setInputs(reference = "lead_3")
    html <- as.character(output$meta_ui$html)
    row <- regmatches(html, regexpr("lead_6.*?typ_[0-9]+.*?</select>", html))
    expect_match(row, 'value="stock" selected', fixed = TRUE)
    row <- regmatches(html, regexpr("lead_6.*?frq_[0-9]+.*?</select>", html))
    expect_match(row, 'value="weekly" selected', fixed = TRUE)
  })
})
