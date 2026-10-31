# FR-008 (rcli 0.3.1): column separator and decimal mark of an uploaded CSV
# file in step 1 of the interface.

csv_lines <- list(
  comma = c("tanggal,pdb,kredit", "2001Q1,100.5,20.1", "2001Q2,101.2,20.9",
            "2001Q3,102.0,21.5", "2001Q4,103.4,22.0", "2002Q1,104.1,22.6"),
  semicolon = c("tanggal;pdb;kredit", "2001Q1;100,5;20,1", "2001Q2;101,2;20,9",
                "2001Q3;102,0;21,5", "2001Q4;103,4;22,0", "2002Q1;104,1;22,6"),
  tab = c("tanggal\tpdb\tkredit", "2001Q1\t100,5\t20,1", "2001Q2\t101,2\t20,9",
          "2001Q3\t102,0\t21,5", "2001Q4\t103,4\t22,0", "2002Q1\t104,1\t22,6")
)
write_csv_lines <- function(lines) {
  f <- tempfile(fileext = ".csv")
  writeLines(lines, f)
  f
}

test_that("FR-008 AC-2: the separator and decimal mark are recognised", {
  f <- lapply(csv_lines, write_csv_lines)
  expect_equal(rcli:::csv_format(f$comma), list(sep = ",", dec = "."))
  expect_equal(rcli:::csv_format(f$semicolon), list(sep = ";", dec = ","))
  expect_equal(rcli:::csv_format(f$tab), list(sep = "\t", dec = ","))
  # a semicolon file with decimal points
  g <- write_csv_lines(c("t;a;b", "2001Q1;1.5;2", "2001Q2;1.7;3"))
  expect_equal(rcli:::csv_format(g), list(sep = ";", dec = "."))
  # explicit choices override the recognition
  expect_equal(rcli:::csv_format(f$semicolon, sep = ";", dec = "."),
               list(sep = ";", dec = "."))
})

test_that("FR-008 AC-3: separator and decimal mark must differ", {
  f <- write_csv_lines(csv_lines$comma)
  expect_error(rcli:::csv_format(f, sep = ",", dec = ","),
               class = "rcli_error_argument")
  expect_error(rcli:::csv_format(f, sep = "|"),
               class = "rcli_error_argument")
})

test_that("FR-008 AC-1/4: step 1 reads Indonesian Excel files", {
  skip_if_not_installed("shiny")
  ref <- read_cli_data(write_csv_lines(csv_lines$comma))
  for (kind in c("semicolon", "tab")) {
    for (choice in list(c("auto", "auto"),
                        c(if (kind == "tab") "tab" else "semicolon",
                          "comma"))) {
      path <- write_csv_lines(csv_lines[[kind]])
      shiny::testServer(rcli:::app_server("en"), {
        session$setInputs(source = "upload", freq = "auto", start = "",
                          csv_sep = choice[1], csv_dec = choice[2],
                          file = list(name = "pdb.csv", datapath = path))
        session$setInputs(run1 = 1)
        expect_equal(1L, rv$done)
        expect_equal(as.numeric(rv$data), as.numeric(ref))
        expect_equal(tsp(rv$data), tsp(ref))
        # the script reads the file with the format actually used, even if
        # the choices change after step 1
        session$setInputs(csv_sep = "comma", csv_dec = "point")
        lines <- rcli:::data_lines(current_state())
        sep <- if (kind == "tab") "\\t" else ";"
        expect_true(any(grepl(sprintf('sep = "%s", dec = ","', sep), lines,
                              fixed = TRUE)))
        env <- new.env()
        old <- setwd(dirname(path))
        on.exit(setwd(old), add = TRUE)
        file.copy(path, file.path(dirname(path), "pdb.csv"), overwrite = TRUE)
        eval(parse(text = lines), envir = env)
        expect_equal(as.numeric(env$data), as.numeric(ref))
      })
    }
  }
})

test_that("FR-008: a comma file keeps the short script line", {
  skip_if_not_installed("shiny")
  path <- write_csv_lines(csv_lines$comma)
  shiny::testServer(rcli:::app_server("en"), {
    session$setInputs(source = "upload", freq = "auto", start = "",
                      csv_sep = "auto", csv_dec = "auto",
                      file = list(name = "pdb.csv", datapath = path))
    session$setInputs(run1 = 1)
    lines <- rcli:::data_lines(current_state())
    expect_false(any(grepl("sep =", lines, fixed = TRUE)))
  })
})

test_that("FR-008 AC-3: a contradictory choice leaves step 1 undone", {
  skip_if_not_installed("shiny")
  path <- write_csv_lines(csv_lines$semicolon)
  shiny::testServer(rcli:::app_server("en"), {
    session$setInputs(source = "upload", freq = "auto", start = "",
                      csv_sep = "comma", csv_dec = "comma",
                      file = list(name = "pdb.csv", datapath = path))
    session$setInputs(run1 = 1)
    expect_null(rv$data)
    expect_false(1L %in% rv$done)
  })
})

test_that("FR-008 AC-5: the choices are labelled in both languages", {
  skip_if_not_installed("shiny")
  keys <- c("csv_sep", "csv_dec", "sep_auto", "sep_comma", "sep_semicolon",
            "sep_tab", "dec_point", "dec_comma")
  for (lang in c("id", "en")) {
    expect_true(all(keys %in% names(rcli:::app_text[[lang]])))
    html <- as.character(rcli:::app_ui(lang))
    expect_match(html, 'id="csv_sep"', fixed = TRUE)
    expect_match(html, 'id="csv_dec"', fixed = TRUE)
  }
})
