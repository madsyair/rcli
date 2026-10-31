# FR-009 (rcli 0.4.0): one file per indicator, read with read_cli_series()
# and brought to one frequency with cli_align().

write_lines_as <- function(lines, name) {
  dir <- tempfile("series")
  dir.create(dir)
  f <- file.path(dir, name)
  writeLines(lines, f)
  f
}

test_that("AC-FR-009.1: one series per value column, named by the file", {
  ipi <- write_lines_as(c("date,value", "2001-01,100", "2001-02,101",
                          "2001-03,103"), "ipi.csv")
  kredit <- write_lines_as(c("tanggal;nilai", "2001-01;5,5", "2001-02;5,7",
                             "2001-03;5,8"), "kredit.csv")
  survei <- write_lines_as(c("date,bts,cci", "2001Q1,10,90", "2001Q2,12,91",
                             "2001Q3,9,92"), "survei.csv")
  out <- read_cli_series(c(ipi, kredit, survei))
  expect_named(out, c("ipi", "kredit", "bts", "cci"))
  for (s in out) {
    expect_s3_class(s, "data.frame")
    expect_named(s, c("date", "value"))
    expect_s3_class(s$date, "Date")
  }
  expect_equal(out$ipi$value, c(100, 101, 103))
  expect_equal(out$kredit$value, c(5.5, 5.7, 5.8))
  expect_equal(out$cci$value, c(90, 91, 92))
  expect_equal(out$bts$date, as.Date(c("2001-01-01", "2001-04-01",
                                       "2001-07-01")))
  # the names of `files` replace the file names (uploads have random paths)
  out <- read_cli_series(c(produksi = ipi))
  expect_named(out, "produksi")
  expect_equal(attr(out$produksi, "file"), "produksi")
  # the same name twice is refused
  ipi2 <- write_lines_as(c("date,value", "2001-01,1", "2001-02,2"), "ipi.csv")
  expect_error(read_cli_series(c(ipi, ipi2)), class = "rcli_error_argument")
  expect_error(read_cli_series(character(0)), class = "rcli_error_argument")
  expect_error(read_cli_series(file.path(tempdir(), "missing.csv")),
               class = "rcli_error_argument")
})

test_that("AC-FR-009.2: six date formats, one per frequency", {
  cases <- list(
    daily = list(c("2001-01-15", "2001-01-16", "2001-01-17", "2001-01-18"),
                 as.Date("2001-01-15") + 0:3),
    weekly = list(c("15/01/2001", "22/01/2001", "29/01/2001", "05/02/2001"),
                  as.Date("2001-01-15") + 7 * 0:3),
    monthly = list(c("2001-01", "2001-02", "2001-03", "2001-04"),
                   seq(as.Date("2001-01-01"), by = "month", length.out = 4)),
    quarterly = list(c("2001Q1", "2001Q2", "2001Q3", "2001Q4"),
                     seq(as.Date("2001-01-01"), by = "3 months",
                         length.out = 4)),
    semiannual = list(c("2001S1", "2001S2", "2002S1", "2002S2"),
                      seq(as.Date("2001-01-01"), by = "6 months",
                          length.out = 4)),
    annual = list(c("2001", "2002", "2003", "2004"),
                  seq(as.Date("2001-01-01"), by = "year", length.out = 4))
  )
  for (fr in names(cases)) {
    f <- write_lines_as(c("date,value", paste0(cases[[fr]][[1]], ",", 1:4)),
                        paste0(fr, ".csv"))
    s <- read_cli_series(f)[[1]]
    expect_equal(s$date, cases[[fr]][[2]], info = fr)
    expect_equal(attr(s, "frequency"), fr, info = fr)
  }
  # an unknown or mixed format names the file and the first bad value
  f <- write_lines_as(c("date,value", "2001-01,1", "Jan 2001,2", "2001-03,3"),
                      "campur.csv")
  err <- expect_error(read_cli_series(f), class = "rcli_error_dates")
  expect_match(conditionMessage(err), "campur.csv", fixed = TRUE)
  expect_match(conditionMessage(err), "Jan 2001", fixed = TRUE)
  f <- write_lines_as(c("date,value", "2001-13,1", "2001-14,2"), "bulan.csv")
  expect_error(read_cli_series(f), class = "rcli_error_dates")
})

test_that("AC-FR-009.3: format per file, missing values and text columns", {
  a <- write_lines_as(c("date\tvalue", "2001Q1\t1234,5", "2001Q2\t1240,25",
                        "2001Q3\t1251,0"), "a.csv")
  b <- write_lines_as(c("date,x,y", "2001-01,1.5,", "2001-02,1.6,2",
                        "2001-03,1.7,3"), "b.csv")
  out <- read_cli_series(c(a, b))
  expect_equal(out$a$value, c(1234.5, 1240.25, 1251))
  expect_equal(attr(out$a, "frequency"), "quarterly")
  expect_equal(attr(out$a, "file"), "a.csv")
  # a missing value drops that observation of that series only
  expect_equal(out$x$value, c(1.5, 1.6, 1.7))
  expect_equal(out$y$date, as.Date(c("2001-02-01", "2001-03-01")))
  # explicit choices apply to every file
  expect_equal(read_cli_series(b, sep = ",", dec = ".")$x$value,
               c(1.5, 1.6, 1.7))
  # a column without numbers is dropped with a warning
  c3 <- write_lines_as(c("date,x,note", "2001-01,1,a", "2001-02,2,b"),
                       "c.csv")
  expect_warning(out <- read_cli_series(c3), class = "rcli_warning_dropped")
  expect_named(out, "x")
  d <- write_lines_as(c("date,note", "2001-01,a", "2001-02,b"), "d.csv")
  expect_error(suppressWarnings(read_cli_series(d)),
               class = "rcli_error_argument")
  e <- write_lines_as("date", "e.csv")
  expect_error(read_cli_series(e), class = "rcli_error_argument")
  # a UTF-8 byte-order mark does not stick to the date column
  g <- tempfile(fileext = ".csv")
  con <- file(g, "wb")
  writeBin(as.raw(c(0xef, 0xbb, 0xbf)), con)
  writeBin(charToRaw("date,value\n2001Q1,1\n2001Q2,2\n"), con)
  close(con)
  expect_equal(read_cli_series(g)[[1]]$value, c(1, 2))
})

test_that("AC-FR-009.4: per-indicator files equal the wide file", {
  sim <- simulate_cycles(seed = 3, n_years = 12)
  dates <- format(seq(as.Date("2001-01-01"), by = "month",
                      length.out = nrow(sim)), "%Y-%m")
  wide <- write_lines_as(
    utils::capture.output(utils::write.csv(
      data.frame(date = dates, sim, check.names = FALSE), row.names = FALSE,
      quote = FALSE)), "wide.csv")
  mfiles <- vapply(colnames(sim), function(nm) {
    write_lines_as(c("date,value", paste0(dates, ",", sprintf(
      "%.15g", sim[, nm]))), paste0(nm, ".csv"))
  }, character(1))
  out <- read_cli_series(unname(mfiles))
  expect_named(out, colnames(sim))
  aligned <- cli_align(out, freq = 12)
  expect_equal(unclass(aligned)[, ], unclass(read_cli_data(wide))[, ],
               ignore_attr = TRUE, tolerance = 1e-12)
  expect_equal(stats::tsp(aligned), stats::tsp(read_cli_data(wide)))
  # quarterly
  q <- stats::aggregate(sim, nfrequency = 4, FUN = mean)
  qd <- paste0(floor(stats::time(q)), "Q", stats::cycle(q))
  files <- vapply(colnames(q), function(nm) {
    write_lines_as(c("date,value", paste0(qd, ",", sprintf("%.15g",
                                                          q[, nm]))),
                   paste0(nm, ".csv"))
  }, character(1))
  wide <- write_lines_as(
    utils::capture.output(utils::write.csv(
      data.frame(date = qd, q, check.names = FALSE), row.names = FALSE,
      quote = FALSE)), "wide.csv")
  aligned <- cli_align(read_cli_series(unname(files)), freq = 4)
  expect_equal(unclass(aligned)[, ], unclass(read_cli_data(wide))[, ],
               ignore_attr = TRUE, tolerance = 1e-12)
  # mixed frequencies: a quarterly reference with monthly candidates
  ref <- write_lines_as(c("date,value", paste0(qd, ",", sprintf(
    "%.15g", q[, "reference"]))), "pdb.csv")
  series <- read_cli_series(c(ref, unname(mfiles[-1])))
  aligned <- cli_align(series, freq = 12, type = c(pdb = "average"),
                       reference = "pdb")
  expect_equal(stats::frequency(aligned), 12)
  expect_equal(colnames(aligned), names(series))
  expect_equal(attr(aligned, "alignment")$from[1], "quarterly")
})

test_that("AC-FR-009.6: an empty metadata entry keeps the alignment record", {
  sim <- simulate_cycles(seed = 3, n_years = 10)
  q <- stats::aggregate(sim[, "reference"], nfrequency = 4, FUN = mean)
  series <- list(ref = q, lead_6 = sim[, "lead_6"], lead_3 = sim[, "lead_3"])
  data <- cli_align(series, freq = 12, type = c(ref = "average",
                                                lead_6 = "flow"),
                    reference = "ref")
  meta <- data.frame(name = c("lead_6", "lead_3"),
                     rationale = "early_stage", type = NA_character_,
                     frequency = c(NA, "monthly"))
  cand <- cli_candidates(data, "ref", meta = meta)
  expect_equal(cand@meta$type, c("flow", NA))
  expect_equal(cand@meta$frequency, c("monthly", "monthly"))
})

test_that("R1/R2: names within one file", {
  f <- write_lines_as(c("date,value,gdp_sa", "2001Q1,1,10", "2001Q2,2,20"),
                      "gdp_sa.csv")
  err <- expect_error(read_cli_series(f), class = "rcli_error_argument")
  expect_match(conditionMessage(err), "gdp_sa", fixed = TRUE)
  f <- write_lines_as(c("date,a,a", "2001Q1,1,10", "2001Q2,2,20"), "dup.csv")
  expect_error(read_cli_series(f), class = "rcli_error_argument")
  f <- write_lines_as(c("date,a,", "2001Q1,1,10", "2001Q2,2,20"), "kosong.csv")
  err <- expect_error(read_cli_series(f), class = "rcli_error_argument")
  expect_match(conditionMessage(err), "kosong.csv", fixed = TRUE)
  # an empty column left by a trailing separator is still ignored
  f <- write_lines_as(c("date,a,", "2001Q1,1,", "2001Q2,2,"), "akhir.csv")
  expect_named(read_cli_series(f), "a")
})

test_that("R6-R9: missing marks, order, short series and date forms", {
  f <- write_lines_as(c("date,a,b", "2001Q1,-,1", "2001Q2,2,..",
                        "2001Q3,3,#N/A", "2001Q4,4,4", "2002Q1,5,5"),
                      "tanda.csv")
  out <- read_cli_series(f)
  expect_equal(out$a$value, 2:5)
  expect_equal(out$b$value, c(1, 4, 5))
  # a file written newest first is sorted
  f <- write_lines_as(c("date,value", "2001-03,3", "2001-02,2", "2001-01,1"),
                      "terbalik.csv")
  s <- read_cli_series(f)[[1]]
  expect_equal(s$value, 1:3)
  expect_false(is.unsorted(s$date))
  # one observation, or no dates at all, names the file
  f <- write_lines_as(c("date,value", "2001Q1,1"), "satu.csv")
  err <- expect_error(suppressWarnings(read_cli_series(f)),
                      class = "rcli_error_argument")
  expect_match(conditionMessage(err), "satu.csv", fixed = TRUE)
  f <- write_lines_as(c("date,value", ",1", ",2"), "tanpa.csv")
  err <- expect_error(read_cli_series(f), class = "rcli_error_dates")
  expect_match(conditionMessage(err), "tanpa.csv", fixed = TRUE)
  # Excel date-times at midnight, and the documented separators
  for (d in list(c("2001-01-15 00:00:00", "2001-01-22 00:00:00"),
                 c("2001/01/15", "2001/01/22"),
                 c("15-01-2001", "22-01-2001"),
                 c("15.01.2001", "22.01.2001"))) {
    f <- write_lines_as(c("date;value", paste0(d, ";", 1:2)), "waktu.csv")
    expect_equal(read_cli_series(f)[[1]]$date,
                 as.Date(c("2001-01-15", "2001-01-22")), info = d[1])
  }
  f <- write_lines_as(c("date,value", "2001-01-15 08:30,1",
                        "2001-01-16 08:30,2"), "jam.csv")
  expect_error(read_cli_series(f), class = "rcli_error_dates")
})

test_that("R11/R13/R14: US dates, one-value series and the na argument", {
  us <- format(seq(as.Date("2001-01-01"), by = "month", length.out = 24),
               "%m/%d/%Y")
  us <- sub("^0", "", sub("/0", "/", us))
  f <- write_lines_as(c("date,value", paste0(us, ",", 1:24)), "us.csv")
  err <- expect_error(read_cli_series(f), class = "rcli_error_dates")
  expect_match(conditionMessage(err), "us.csv", fixed = TRUE)
  # genuine daily dates written day first are accepted
  d <- format(as.Date("2001-01-01") + 0:59, "%d/%m/%Y")
  f <- write_lines_as(c("date,value", paste0(d, ",", 1:60)), "harian.csv")
  expect_equal(attr(read_cli_series(f)[[1]], "frequency"), "daily")
  f <- write_lines_as(c("date,value", "15/01/2001 0:00,1",
                        "22/01/2001 0:00,2"), "jam.csv")
  expect_equal(read_cli_series(f)[[1]]$value, 1:2)
  # a series of one value is dropped like a column without numbers
  f <- write_lines_as(c("date,a,b", "2001Q1,1,", "2001Q2,2,5"), "satu.csv")
  expect_warning(out <- read_cli_series(f), class = "rcli_warning_dropped")
  expect_named(out, "a")
  f <- write_lines_as(c("date,a", "2001Q1,1", "2001Q2,"), "hanya.csv")
  expect_error(suppressWarnings(read_cli_series(f)),
               class = "rcli_error_argument")
  expect_error(read_cli_series(f, na = 1), class = "rcli_error_argument")
})
