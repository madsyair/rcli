# Fixture of FR-015 (AC-FR-015.2): GDP and household consumption (PKRT) at
# constant 2010 prices and the growth rates BPS publishes for them, from the
# BPS expenditure tables (PKRT_series.xlsx: Tabel 2 levels, Tabel 5 q-to-q,
# Tabel 6 y-on-y), 2010Q1-2026Q3.
# Run: Rscript data-raw/bps_growth_fixture.R path/to/PKRT_series.xlsx
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L, requireNamespace("readxl", quietly = TRUE))
d <- suppressMessages(readxl::read_excel(args[1], sheet = "PKRT",
                                         col_names = FALSE))
title_row <- function(pattern) {
  which(apply(d, 1, function(r) any(grepl(pattern, r))))[1]
}
# rows: title, +3 quarter labels, +6 household consumption, +15 GDP
table_rows <- function(start, last) {
  q <- unlist(d[start + 3, ])
  qcol <- which(q %in% c("I", "II", "III", "IV"))
  num <- function(r) suppressWarnings(as.numeric(unlist(d[r, qcol])))
  a <- num(start + 6)
  b <- num(start + 15)
  ok <- which(!is.na(a) | !is.na(b))
  ok <- min(ok):max(ok)
  st <- last - (length(ok) - 1) / 4
  list(pkrt = stats::ts(a[ok], start = st, frequency = 4),
       pdb = stats::ts(b[ok], start = st, frequency = 4))
}
# the level table starts in 2010Q1; every table ends in the same quarter
lv <- table_rows(title_row("^Tabel 2\\."), 0)
last <- 2010 + (length(lv$pdb) - 1) / 4
lv <- table_rows(title_row("^Tabel 2\\."), last)
fx <- list(level = lv,
           qtq = table_rows(title_row("^Tabel 5\\."), last),
           yoy = table_rows(title_row("^Tabel 6\\."), last),
           source = paste("BPS, PDB menurut pengeluaran (PKRT_series.xlsx),",
                          "Tabel 2, 5, 6"))
saveRDS(fx, file.path("tests", "testthat", "fixtures", "bps-pdb-pkrt.rds"),
        version = 2)
