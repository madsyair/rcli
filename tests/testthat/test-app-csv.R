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
        expect_identical(rv$data, ref)
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
        expect_identical(env$data, ref)
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
  # integers only: without the check, sep = dec = "," would read this file
  path <- write_csv_lines(c("tanggal,pdb,kredit", "2001Q1,100,20",
                            "2001Q2,101,21", "2001Q3,102,22"))
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

# Review of 0.3.1 (harness/06-review.md, round 1)

test_that("R1: commas inside semicolon headers do not fool the detection", {
  heads <- c('tanggal;PDB (ADHK, miliar);kredit, juta',
             'tanggal;"PDB, riil";kredit')
  for (h in heads) {
    f <- write_csv_lines(c(h, "2001Q1;100,5;20,1", "2001Q2;101,2;20,9",
                           "2001Q3;102,0;21,5"))
    expect_equal(rcli:::csv_format(f), list(sep = ";", dec = ","))
  }
  # a comma file whose names hold semicolons stays a comma file
  f <- write_csv_lines(c('tanggal,"a;b",c', "2001Q1,1.5,2.5",
                         "2001Q2,1.6,2.6"))
  expect_equal(rcli:::csv_format(f), list(sep = ",", dec = "."))
})

test_that("R2: the decimal mark is found below empty or whole-number rows", {
  f <- write_csv_lines(c("tanggal;pdb;kredit", "2001Q1;;", "2001Q2;100;20",
                         "2001Q3;NA;21", "2001Q4;101,5;21,7"))
  expect_equal(rcli:::csv_format(f), list(sep = ";", dec = ","))
  # whole numbers only: either mark reads the same values
  g <- write_csv_lines(c("tanggal;pdb;kredit", "2001Q1;100;20",
                         "2001Q2;101;21"))
  expect_equal(rcli:::csv_format(g)$sep, ";")
  # tab file with decimal points and thousands commas
  h <- write_csv_lines(c("tanggal\tpdb\tkredit", "2001Q1\t1,234.5\t20.1",
                         "2001Q2\t1,240.2\t20.9"))
  expect_equal(rcli:::csv_format(h), list(sep = "\t", dec = "."))
})

test_that("R3: a Windows-1252 file is read under any locale", {
  f <- tempfile(fileext = ".csv")
  bytes <- c(charToRaw("tanggal;pengeluaran r"), as.raw(0xe9),
             charToRaw("el;kredit\n2001Q1;100,5;20,1\n2001Q2;101,2;20,9\n"))
  writeBin(bytes, f)
  expect_equal(rcli:::csv_format(f), list(sep = ";", dec = ","))
  old <- Sys.getlocale("LC_CTYPE")
  on.exit(Sys.setlocale("LC_CTYPE", old), add = TRUE)
  if (nzchar(suppressWarnings(Sys.setlocale("LC_CTYPE", "C.UTF-8")))) {
    expect_equal(rcli:::csv_format(f), list(sep = ";", dec = ","))
  }
})

test_that("R4: the script keeps column names with spaces", {
  skip_if_not_installed("shiny")
  path <- write_csv_lines(c("tanggal;PDB riil;kredit bank",
                            "2001Q1;100,5;20,1", "2001Q2;101,2;20,9",
                            "2001Q3;102,0;21,5", "2001Q4;103,4;22,0"))
  shiny::testServer(rcli:::app_server("en"), {
    session$setInputs(source = "upload", freq = "auto", start = "",
                      csv_sep = "auto", csv_dec = "auto",
                      file = list(name = "pdb riil.csv", datapath = path))
    session$setInputs(run1 = 1)
    expect_equal(colnames(rv$data), c("PDB riil", "kredit bank"))
    lines <- rcli:::data_lines(current_state())
    expect_true(any(grepl("check.names = FALSE", lines, fixed = TRUE)))
    env <- new.env()
    old <- setwd(dirname(path))
    on.exit(setwd(old), add = TRUE)
    file.copy(path, file.path(dirname(path), "pdb riil.csv"),
              overwrite = TRUE)
    eval(parse(text = lines), envir = env)
    expect_identical(env$data, rv$data)
  })
})

test_that("R4: file names with quotes are written safely", {
  lines <- rcli:::data_lines(list(source = "upload",
                                  file_name = 'data "baru".csv',
                                  frequency = 4, start = NULL,
                                  sep = ",", dec = "."))
  expect_silent(parse(text = lines))
  expect_match(paste(lines, collapse = "\n"), 'data \\"baru\\".csv',
               fixed = TRUE)
})

test_that("R5: a byte-order mark does not stick to the first name", {
  f <- tempfile(fileext = ".csv")
  writeBin(c(as.raw(c(0xef, 0xbb, 0xbf)),
             charToRaw("pdb,kredit\n100,20\n101,21\n102,22\n")), f)
  x <- read_cli_data(f, frequency = 4, start = c(2001, 1))
  expect_equal(colnames(x), c("pdb", "kredit"))
  g <- tempfile(fileext = ".csv")
  writeBin(c(as.raw(c(0xef, 0xbb, 0xbf)),
             charToRaw("tanggal,pdb,kredit\n2001Q1,100,20\n2001Q2,101,21\n")),
           g)
  expect_equal(colnames(read_cli_data(g)), c("pdb", "kredit"))
})

test_that("R6: explicit choices are used, also in the script", {
  skip_if_not_installed("shiny")
  # semicolons with decimal points: the decimal choice must be honoured
  path <- write_csv_lines(c("tanggal;pdb;kredit", "2001Q1;100.5;20.1",
                            "2001Q2;101.2;20.9", "2001Q3;102.0;21.5"))
  ref <- read_cli_data(write_csv_lines(csv_lines$comma[1:4]))
  shiny::testServer(rcli:::app_server("en"), {
    session$setInputs(source = "upload", freq = "auto", start = "",
                      csv_sep = "semicolon", csv_dec = "point",
                      file = list(name = "pdb.csv", datapath = path))
    session$setInputs(run1 = 1)
    expect_identical(rv$data, ref)
    lines <- rcli:::data_lines(current_state())
    expect_true(any(grepl('sep = ";", dec = "."', lines, fixed = TRUE)))
  })
  expect_equal(rcli:::csv_choice("point", "dec"), ".")
  expect_equal(rcli:::csv_choice("tab", "sep"), "\t")
  expect_error(rcli:::csv_choice("pipe", "sep"),
               class = "rcli_error_argument")
})

test_that("R8: dropped non-numeric columns are reported", {
  f <- write_csv_lines(c("tanggal;pdb;kredit", "2001Q1;2.345,5;20,1",
                         "2001Q2;2.401,0;20,9"))
  expect_warning(x <- read_cli_data(f, sep = ";", dec = ","),
                 class = "rcli_warning_dropped", regexp = "pdb")
  expect_equal(colnames(x), "kredit")
})
