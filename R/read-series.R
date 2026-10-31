#' Read indicators from several CSV files, one or more per file
#'
#' Reads files that each hold a date column followed by one or more value
#' columns, as statistical offices often publish one indicator per file.
#' The files may have different frequencies; [cli_align()] brings them to
#' one. Each value column becomes one series; a column called `value` or
#' `nilai` takes the name of its file. The column separator and the decimal
#' mark are recognised in every file separately, unless they are given.
#'
#' The first column must hold dates in one of these forms, the same in the
#' whole file:
#'
#' | Form | Example | Date used |
#' | --- | --- | --- |
#' | year-month-day | `2001-01-15` | that day |
#' | day/month/year | `15/01/2001` | that day |
#' | year-month | `2001-01` | the first day of the month |
#' | year and quarter | `2001Q1` | the first day of the quarter |
#' | year and half | `2001S1` | the first day of the half-year |
#' | year | `2001` | 1 January |
#'
#' The source frequency (daily, weekly, monthly, quarterly, semiannual or
#' annual) is then recognised from the spacing of the dates. Empty cells
#' are dropped from that series only, so the series of one file may cover
#' different periods.
#'
#' @param files Paths of the CSV files. Names, if given, replace the file
#'   names in the series names and messages (for instance the original
#'   names of uploaded files).
#' @param sep Column separator: `"auto"`, `","`, `";"` or `"\t"`.
#' @param dec Decimal mark: `"auto"`, `"."` or `","`.
#' @return A named list of data frames with columns `date` (`Date`) and
#'   `value`, ready for [cli_align()]. Each carries the attributes
#'   `frequency` (the recognised source frequency) and `file`.
#' @seealso [cli_align()] to bring the series to one frequency,
#'   [read_cli_data()] for one file with one column per series.
#' @examples
#' dir <- tempfile()
#' dir.create(dir)
#' writeLines(c("date,value", "2001Q1,100", "2001Q2,101", "2001Q3,103",
#'              "2001Q4,104"), file.path(dir, "gdp.csv"))
#' writeLines(c("date;sales;credit", paste0("2001-", sprintf("%02d", 1:12),
#'              ";", 50:61, ";", 20:31, ",5")), file.path(dir, "monthly.csv"))
#' series <- read_cli_series(file.path(dir, c("gdp.csv", "monthly.csv")))
#' vapply(series, attr, "", "frequency")
#' cli_align(series, freq = 12, type = c(gdp = "flow"), reference = "gdp")
#' @export
read_cli_series <- function(files, sep = "auto", dec = "auto") {
  if (!is.character(files) || length(files) == 0L) {
    rcli_abort("`files` must name at least one file.", "rcli_error_argument")
  }
  shown <- names(files)
  if (is.null(shown)) shown <- rep("", length(files))
  shown[!nzchar(shown)] <- basename(files[!nzchar(shown)])
  out <- list()
  for (k in seq_along(files)) {
    s <- read_series_file(files[[k]], shown[k], sep, dec)
    clash <- intersect(names(s), names(out))
    if (length(clash) > 0L) {
      rcli_abort(sprintf(paste("Series name '%s' appears twice; rename a",
                               "column or a file."), clash[1]),
                 "rcli_error_argument")
    }
    out <- c(out, s)
  }
  out
}

# The series of one file.
read_series_file <- function(path, shown, sep, dec) {
  if (!file.exists(path)) {
    rcli_abort(sprintf("File '%s' not found.", shown), "rcli_error_argument")
  }
  fmt <- csv_format(path, sep = sep, dec = dec)
  args <- list(path, sep = fmt$sep, dec = fmt$dec, check.names = FALSE,
               strip.white = TRUE, na.strings = c("NA", ""))
  if (has_bom(path)) args$fileEncoding <- "UTF-8-BOM"
  df <- do.call(utils::read.csv, args)
  if (ncol(df) < 2L || nrow(df) == 0L) {
    rcli_abort(sprintf(paste("File '%s' needs a date column and at least",
                             "one value column."), shown),
               "rcli_error_argument")
  }
  dates <- as.character(df[[1]])
  keep <- !is.na(dates) & nzchar(trimws(dates))
  df <- df[keep, , drop = FALSE]
  dates <- series_dates(dates[keep], shown)
  values <- df[-1]
  label <- sub("\\.[^.]*$", "", shown)
  nms <- names(values)
  own <- tolower(nms) %in% c("value", "nilai")
  nms[own] <- label
  # a separator at the end of every line adds an empty column without name
  empty <- vapply(values, function(v) all(is.na(v)), logical(1))
  unnamed <- grepl("^(V[0-9]+|X(\\.[0-9]+)?)?$", names(values))
  num <- vapply(values, is.numeric, logical(1)) & !empty
  dropped <- !num & !(empty & unnamed)
  if (any(dropped)) {
    rcli_warn(sprintf(paste("File '%s': columns without numbers were",
                            "dropped: %s. Check the decimal mark and remove",
                            "thousands separators and text."),
                      shown, paste(names(values)[dropped], collapse = ", ")),
              "rcli_warning_dropped")
  }
  if (!any(num)) {
    rcli_abort(sprintf(paste("File '%s' has no numeric column; check the",
                             "column separator and the decimal mark."),
                       shown), "rcli_error_argument")
  }
  out <- list()
  for (j in which(num)) {
    ok <- !is.na(values[[j]])
    s <- data.frame(date = dates[ok], value = as.numeric(values[[j]][ok]))
    attr(s, "frequency") <- as_dated(s, nms[j], "start")$from
    attr(s, "file") <- shown
    out[[nms[j]]] <- s
  }
  if (anyDuplicated(names(out)) > 0L) {
    rcli_abort(sprintf("File '%s' has two columns with the same name.",
                       shown), "rcli_error_argument")
  }
  out
}

# Dates of one file; every value must have the same form.
series_dates <- function(x, shown) {
  x <- trimws(x)
  forms <- list(
    ymd = "^([0-9]{4})[-/]([0-9]{1,2})[-/]([0-9]{1,2})$",
    dmy = "^([0-9]{1,2})[-/.]([0-9]{1,2})[-/.]([0-9]{4})$",
    ym = "^([0-9]{4})[-/]([0-9]{1,2})$",
    q = "^([0-9]{4})[- ]?[Qq]([1-4])$",
    s = "^([0-9]{4})[- ]?[SsHh]([12])$",
    y = "^([0-9]{4})$"
  )
  hit <- vapply(forms, function(f) grepl(f, x[1]), logical(1))
  bad_value <- function(i) {
    rcli_abort(sprintf(paste("File '%s': date '%s' is not understood. Use",
                             "one form throughout: 2001-01-15, 15/01/2001,",
                             "2001-01, 2001Q1, 2001S1 or 2001."),
                       shown, x[i]), "rcli_error_dates")
  }
  if (!any(hit)) bad_value(1L)
  form <- names(forms)[hit][1]
  m <- regmatches(x, regexec(forms[[form]], x))
  wrong <- which(lengths(m) == 0L)
  if (length(wrong) > 0L) bad_value(wrong[1])
  part <- function(i) as.integer(vapply(m, `[`, "", i))
  ymd <- switch(form,
    ymd = cbind(part(2), part(3), part(4)),
    dmy = cbind(part(4), part(3), part(2)),
    ym = cbind(part(2), part(3), 1L),
    q = cbind(part(2), 3L * part(3) - 2L, 1L),
    s = cbind(part(2), 6L * part(3) - 5L, 1L),
    y = cbind(part(2), 1L, 1L)
  )
  d <- as.Date(sprintf("%04d-%02d-%02d", ymd[, 1], ymd[, 2], ymd[, 3]),
               format = "%Y-%m-%d")
  if (anyNA(d)) bad_value(which(is.na(d))[1])
  d
}
