#' Read reference and candidate series from a CSV file
#'
#' Reads a CSV file with one column per series. If the first column holds
#' dates (`2001-01`, `2001-01-15` or `2001Q1`), the frequency and start are
#' taken from it; otherwise give `frequency` and `start`. Non-numeric
#' columns other than the date column are dropped with a warning (often a
#' wrong decimal mark or thousands separators). A UTF-8 byte-order mark at
#' the start of the file is ignored.
#'
#' @param file Path to a CSV file, or a data frame already read.
#' @param frequency `NULL` (detect from dates), 12 or 4.
#' @param start Start as `c(year, period)` when there is no date column.
#' @param ... Passed to [utils::read.csv()], e.g. `sep = ";", dec = ","` for
#'   a file saved by Excel with Indonesian settings.
#' @return A multivariate `ts`.
#' @seealso [read_cli_series()] for one file per indicator, at different
#'   frequencies.
#' @examples
#' df <- data.frame(date = c("2001Q1", "2001Q2", "2001Q3"),
#'                  gdp = c(100, 101, 103), sales = c(50, 52, 51))
#' read_cli_data(df)
#' @export
read_cli_data <- function(file, frequency = NULL, start = NULL, ...) {
  df <- if (is.data.frame(file)) {
    file
  } else if (has_bom(file) && !"fileEncoding" %in% names(list(...))) {
    # a UTF-8 byte-order mark would otherwise stick to the first name
    utils::read.csv(file, fileEncoding = "UTF-8-BOM", ...)
  } else {
    utils::read.csv(file, ...)
  }
  if (ncol(df) < 2L) {
    rcli_abort("The data need at least two columns.", "rcli_error_argument")
  }
  first <- df[[1]]
  if (!is.numeric(first)) {
    tm <- parse_dates(as.character(first), frequency)
    frequency <- tm$frequency
    start <- tm$start
    df <- df[-1]
  }
  # a separator at the end of every line adds an empty column without name
  blank <- vapply(seq_along(df), function(j) {
    grepl("^(X(\\.[0-9]+)?)?$", names(df)[j]) && all(is.na(df[[j]]))
  }, logical(1))
  df <- df[!blank]
  num <- vapply(df, is.numeric, logical(1))
  if (!any(num)) {
    rcli_abort(paste("No numeric column found; check the column separator",
                     "and the decimal mark."), "rcli_error_argument")
  }
  if (!all(num)) {
    rcli_warn(sprintf(paste("Columns without numbers were dropped: %s.",
                            "Check the decimal mark and remove thousands",
                            "separators and text."),
                      paste(names(df)[!num], collapse = ", ")),
              "rcli_warning_dropped")
  }
  if (is.null(frequency) || is.null(start)) {
    rcli_abort("Give `frequency` and `start` when there is no date column.",
               "rcli_error_argument")
  }
  check_frequency(frequency)
  stats::ts(as.matrix(df[num]), start = start, frequency = frequency)
}

has_bom <- function(file) {
  is.character(file) && length(file) == 1L && file.exists(file) &&
    identical(readBin(file, "raw", 3L), as.raw(c(0xef, 0xbb, 0xbf)))
}

parse_dates <- function(x, frequency = NULL) {
  x <- trimws(x)
  q <- regmatches(x, regexec("^([0-9]{4})[- ]?[Qq]([1-4])$", x))
  m <- regmatches(x, regexec("^([0-9]{4})[-/]([0-9]{1,2})([-/][0-9]{1,2})?$",
                             x))
  if (all(lengths(q) == 3L)) {
    year <- as.integer(vapply(q, `[`, "", 2))
    per <- as.integer(vapply(q, `[`, "", 3))
    freq <- 4
  } else if (all(lengths(m) == 4L)) {
    year <- as.integer(vapply(m, `[`, "", 2))
    per <- as.integer(vapply(m, `[`, "", 3))
    freq <- 12
    if (identical(as.numeric(frequency), 4)) {
      per <- (per - 1L) %/% 3L + 1L
      freq <- 4
    }
  } else {
    rcli_abort("Dates must look like 2001-01, 2001-01-15 or 2001Q1.",
               "rcli_error_dates")
  }
  pos <- year * freq + per
  if (any(diff(pos) != 1)) {
    rcli_abort("Dates must be consecutive months or quarters.",
               "rcli_error_dates")
  }
  list(frequency = freq, start = c(year[1], per[1]))
}

# Column separator and decimal mark of a CSV file (FR-008). "auto" takes
# the separator that splits every line into the same number of fields
# (quotes respected), preferring tab, then semicolon, then comma: decimal
# commas make a comma split wider, so width cannot decide. The decimal mark
# is the one more cells use: "1,5", "1.234,5" and "1.234.567" count for a
# comma, "1.5", "1,234.5" and "1,234,567" for a point; "1.012" or "12,345"
# may be either and count for neither. Text is handled as bytes, so files
# in other encodings than the session's (Windows-1252 from Excel) do not
# stop the detection.
csv_format <- function(path, sep = "auto", dec = "auto") {
  seps <- c(",", ";", "\t")
  if (!sep %in% c("auto", seps) || !dec %in% c("auto", ".", ",")) {
    rcli_abort("Unknown column separator or decimal mark.",
               "rcli_error_argument")
  }
  if (sep == "auto") sep <- detect_separator(path, seps)
  if (dec == "auto") dec <- if (sep == ",") "." else detect_decimal(path, sep)
  if (sep == dec) {
    rcli_abort("The column separator and the decimal mark must differ.",
               "rcli_error_argument")
  }
  list(sep = sep, dec = dec)
}

detect_separator <- function(path, seps) {
  fields <- lapply(seps, function(x) {
    n <- tryCatch(suppressWarnings(utils::count.fields(
      path, sep = x, quote = "\"", comment.char = "",
      blank.lines.skip = TRUE)), error = function(e) integer(0))
    n[!is.na(n)]
  })
  width <- vapply(fields, function(n) if (length(n) > 0L) n[1] else 0L,
                  numeric(1))
  regular <- vapply(fields, function(n) {
    length(n) > 0L && n[1] > 1L && all(n == n[1])
  }, logical(1))
  preference <- match(c("\t", ";", ","), seps)
  if (any(regular)) {
    return(seps[preference[preference %in% which(regular)][1]])
  }
  # no regular split: the widest header line, or a comma
  if (max(width) <= 1) "," else seps[which.max(width)]
}

detect_decimal <- function(path, sep) {
  cells <- tryCatch(unlist(utils::read.table(
    path, sep = sep, quote = "\"", header = FALSE, skip = 1L,
    colClasses = "character", fill = TRUE, comment.char = "",
    na.strings = character(0), nrows = 500L
  ), use.names = FALSE), error = function(e) character(0))
  cells <- gsub("^\\s+|\\s+$", "", cells, useBytes = TRUE)
  has <- function(pattern) grepl(pattern, cells, useBytes = TRUE)
  # one mark and one group of three digits: thousands or decimals (a
  # thousands group never follows a leading zero, so 0,125 is a decimal)
  either <- has("^-?[1-9][0-9]{0,2}[.,][0-9]{3}$")
  comma <- (has("^-?([0-9]{1,3}(\\.[0-9]{3})+|[0-9]+),[0-9]+$") & !either) |
    has("^-?[0-9]{1,3}(\\.[0-9]{3}){2,}$")
  point <- (has("^-?([0-9]{1,3}(,[0-9]{3})+|[0-9]+)\\.[0-9]+$") & !either) |
    has("^-?[0-9]{1,3}(,[0-9]{3}){2,}$")
  if (sum(comma) > sum(point)) return(",")
  if (sum(point) > sum(comma)) return(".")
  # no evidence: take grouped whole numbers as thousands, so that such a
  # column is dropped with a warning instead of being misread as 1.012
  grouped <- cells[either]
  if (length(grouped) > 0L && all(grepl(".", grouped, fixed = TRUE))) {
    return(",")
  }
  "."
}

# Value of a separator or decimal-mark choice of the interface.
csv_choice <- function(value, kind) {
  if (is.null(value) || identical(value, "auto")) return("auto")
  map <- if (kind == "sep") {
    c(comma = ",", semicolon = ";", tab = "\t")
  } else {
    c(point = ".", comma = ",")
  }
  if (!value %in% names(map)) {
    rcli_abort("Unknown column separator or decimal mark.",
               "rcli_error_argument")
  }
  map[[value]]
}

#' Run the step-by-step graphical interface
#'
#' `run_app()` opens a Shiny application that walks through the workflow in
#' ten steps: data, candidate metadata, specification, cycles, turning
#' points, classification, composite, validation with the quality scorecard,
#' coincident index ([cci_build()]), and export (results, a `CliResult`
#' object and an R script that reproduces the analysis). Each step unlocks
#' the next one; re-running a step clears the results that depend on it. The
#' coincident index needs only the classification, so it can be built before
#' or after the composite leading indicator.
#'
#' `rcli_app()` returns the application object without running it, for
#' deployment on Shiny Server or Posit Connect (see
#' `system.file("app", package = "rcli")`) and for automated tests.
#'
#' @param language Interface language: `"id"` (Indonesian) or `"en"`.
#' @param ... Passed to [shiny::runApp()], e.g. `launch.browser`.
#' @return `run_app()` is called for its side effect and returns the value of
#'   [shiny::runApp()]; `rcli_app()` returns a `shiny.appobj`.
#' @examples
#' if (interactive()) {
#'   run_app()
#'   run_app(language = "en")
#' }
#' if (requireNamespace("shiny", quietly = TRUE)) {
#'   app <- rcli_app("en")
#'   class(app)
#' }
#' @export
run_app <- function(language = c("id", "en"), ...) {
  shiny::runApp(rcli_app(match.arg(language)), ...)
}

#' @rdname run_app
#' @export
rcli_app <- function(language = c("id", "en")) {
  language <- match.arg(language)
  if (!requireNamespace("shiny", quietly = TRUE)) {
    rcli_abort("The graphical interface needs the 'shiny' package.",
               "rcli_error_dependency")
  }
  shiny::shinyApp(ui = app_ui(language), server = app_server(language))
}

# ---- user interface ----------------------------------------------------------

filter_choices <- c("hp_double", "hp", "cf", "bk", "hamilton")
names(filter_choices) <- c("OECD double Hodrick-Prescott", "Hodrick-Prescott",
                           "Christiano-Fitzgerald", "Baxter-King",
                           "Hamilton regression")
aggregator_choices <- c("equal", "equal_level", "oecd", "pca", "cb", "dfm")
names(aggregator_choices) <- c("Equal weights, chained at the ragged edge",
                               "Equal weights, plain mean (rcli 0.1)",
                               "Chained average growth (OECD)",
                               "First principal component",
                               "Conference Board", "Dynamic factor model")

step_panel <- function(t, k, ...) {
  shiny::tabPanel(
    t(paste0("s", k)), value = paste0("s", k),
    shiny::h3(t(paste0("s", k))),
    shiny::p(shiny::em(t(paste0("h", k)))),
    ...,
    if (k < 10L) {
      shiny::div(style = "margin: 20px 0;",
                 shiny::actionButton(paste0("next", k), t("next_step")))
    }
  )
}

app_ui <- function(language = "id") {
  t <- app_translator(language)
  has_seasonal <- requireNamespace("seasonal", quietly = TRUE)
  shiny::fluidPage(
    shiny::titlePanel(sprintf("rcli %s: %s", utils::packageVersion("rcli"),
                              t("title"))),
    shiny::uiOutput("progress"),
    shiny::navlistPanel(
      id = "step", widths = c(3, 9),
      step_panel(
        t, 1L,
        shiny::fluidRow(
          shiny::column(5,
            shiny::radioButtons("source", t("source"), stats::setNames(
              c("example_m", "example_q", "upload", "upload_multi"),
              c(t("src_example_m"), t("src_example_q"), t("src_upload"),
                t("src_upload_multi")))),
            shiny::conditionalPanel(
              "input.source == 'example_m' || input.source == 'example_q'",
              shiny::numericInput("seed", t("seed"), 2026, min = 1)),
            shiny::conditionalPanel(
              "input.source == 'upload'",
              shiny::fileInput("file", t("file"),
                               accept = c(".csv", ".txt", ".tsv"))),
            shiny::conditionalPanel(
              "input.source == 'upload_multi'",
              shiny::fileInput("files", t("files"), multiple = TRUE,
                               accept = c(".csv", ".txt", ".tsv")),
              shiny::selectInput("target_freq", t("target_freq"),
                                 stats::setNames(c("12", "4"),
                                                 c(t("monthly"),
                                                   t("quarterly"))))),
            shiny::conditionalPanel(
              "input.source == 'upload' || input.source == 'upload_multi'",
              shiny::fluidRow(
                shiny::column(6, shiny::selectInput(
                  "csv_sep", t("csv_sep"), stats::setNames(
                    c("auto", "comma", "semicolon", "tab"),
                    c(t("sep_auto"), t("sep_comma"), t("sep_semicolon"),
                      t("sep_tab"))))),
                shiny::column(6, shiny::selectInput(
                  "csv_dec", t("csv_dec"), stats::setNames(
                    c("auto", "point", "comma"),
                    c(t("sep_auto"), t("dec_point"), t("dec_comma")))))
              )),
            shiny::conditionalPanel(
              "input.source == 'upload'",
              shiny::selectInput("freq", t("freq"), stats::setNames(
                c("auto", "12", "4"),
                c(t("freq_auto"), t("monthly"), t("quarterly")))),
              shiny::textInput("start", t("start"), "")),
            shiny::actionButton("run1", t("run1"), class = "btn-primary")
          ),
          shiny::column(7,
            shiny::selectInput("reference", t("reference"), choices = NULL),
            shiny::h4(t("data_summary")), shiny::tableOutput("data_summary")
          )
        ),
        shiny::h4(t("overview")), shiny::plotOutput("overview", height = 380)
      ),
      step_panel(
        t, 2L, shiny::uiOutput("meta_ui"),
        shiny::actionButton("run2", t("run2"), class = "btn-primary"),
        shiny::verbatimTextOutput("cand_print")
      ),
      step_panel(
        t, 3L,
        shiny::fluidRow(
          shiny::column(6,
            shiny::selectInput("method", t("method"), stats::setNames(
              c("rcli", "oecd"), c(t("method_rcli"), t("method_oecd")))),
            shiny::conditionalPanel(
              "input.method == 'oecd'",
              shiny::helpText(t("method_help"))),
            shiny::selectInput("filter", t("filter"), filter_choices),
            shiny::selectInput("aggregator", t("aggregator"),
                               aggregator_choices),
            shiny::selectInput("transform", t("transform"),
                               c("auto", "log", "none", "test")),
            shiny::checkboxInput("seasonal", paste(
              t("seasonal"), if (!has_seasonal) t("seasonal_missing")),
              FALSE),
            shiny::conditionalPanel(
              "input.seasonal",
              shiny::checkboxInput("idulfitri", t("idulfitri"), FALSE)),
            shiny::numericInput("outlier", t("outlier"), 5, min = 1),
            shiny::checkboxInput("extend", t("extend"), TRUE),
            shiny::textInput("oos_cutoffs", t("oos_cutoffs"), "")
          ),
          shiny::column(6,
            shiny::numericInput("min_lead", t("min_lead"), 3, min = 0),
            shiny::numericInput("min_median_lead", t("min_median_lead"), 1,
                                min = 0, step = 0.5),
            shiny::numericInput("min_consistency", t("min_consistency"), 0.5,
                                min = 0, max = 1, step = 0.05),
            shiny::numericInput("max_missed", t("max_missed"), 0.4, min = 0,
                                max = 1, step = 0.05),
            shiny::numericInput("max_extra", t("max_extra"), 0.4, min = 0,
                                max = 1, step = 0.05),
            shiny::numericInput("alpha", t("alpha"), 0.05, min = 0.001,
                                max = 0.5, step = 0.01),
            shiny::numericInput("min_auc", t("min_auc"), 0.7, min = 0.5,
                                max = 1, step = 0.05),
            shiny::numericInput("min_components", t("min_components"), 2,
                                min = 1),
            shiny::numericInput("max_iter", t("max_iter"), 10, min = 1)
          )
        ),
        shiny::conditionalPanel("input.method == 'rcli'", advanced_ui(t)),
        shiny::actionButton("run3", t("run3"), class = "btn-primary"),
        shiny::verbatimTextOutput("spec_print")
      ),
      step_panel(
        t, 4L,
        shiny::actionButton("run4", t("run4"), class = "btn-primary"),
        shiny::selectInput("cyc_series", t("series"), choices = NULL),
        shiny::h4(t("cycle_pair")), shiny::plotOutput("cycle_pair"),
        shiny::h4(t("steps_log")), shiny::verbatimTextOutput("cycle_steps"),
        shiny::h4(t("cycles_all")), shiny::plotOutput("cycles_grid",
                                                     height = "auto")
      ),
      step_panel(
        t, 5L,
        shiny::actionButton("run5", t("run5"), class = "btn-primary"),
        shiny::h4(t("tp_counts")), shiny::tableOutput("tp_counts"),
        shiny::selectInput("tp_series", t("series"), choices = NULL),
        shiny::h4(t("tp_plot")), shiny::plotOutput("tp_plot"),
        shiny::h4(t("tp_table")), shiny::tableOutput("tp_table")
      ),
      step_panel(
        t, 6L,
        shiny::actionButton("run6", t("run6"), class = "btn-primary"),
        shiny::h4(t("assess_table")), shiny::tableOutput("assess_table"),
        shiny::h4(t("leads_plot")), shiny::plotOutput("leads_plot"),
        shiny::selectInput("as_series", t("series"), choices = NULL),
        shiny::fluidRow(
          shiny::column(6, shiny::h4(t("ccf_plot")),
                        shiny::plotOutput("ccf_plot")),
          shiny::column(6, shiny::h4(t("aligned")),
                        shiny::plotOutput("aligned_plot"))
        ),
        shiny::h4(t("reasons")), shiny::verbatimTextOutput("reasons")
      ),
      step_panel(
        t, 7L,
        shiny::radioButtons("comp_mode", t("comp_mode"), stats::setNames(
          c("auto", "manual"), c(t("mode_auto"), t("mode_manual"))),
          inline = TRUE),
        shiny::checkboxGroupInput("manual_components", t("components"),
                                  choices = character(0), inline = TRUE),
        shiny::actionButton("run7", t("run7"), class = "btn-primary"),
        shiny::h4(t("composite_plot")), shiny::plotOutput("composite_plot"),
        shiny::fluidRow(
          shiny::column(5, shiny::h4(t("weights")),
                        shiny::plotOutput("weights_plot", height = 300)),
          shiny::column(7, shiny::h4(t("components_plot")),
                        shiny::plotOutput("components_plot", height = 300))
        ),
        shiny::h4(t("audit")), shiny::tableOutput("audit_table"),
        shiny::plotOutput("audit_plot", height = 250),
        shiny::h4(t("pres_title")),
        shiny::helpText(t("pres_help")),
        shiny::selectInput("pres_form", t("pres_form"), stats::setNames(
          c("amplitude_adjusted", "trend_restored", "rate_of_change"),
          c(t("pres_amp"), t("pres_trend"), t("pres_growth")))),
        shiny::plotOutput("pres_plot", height = 340)
      ),
      step_panel(
        t, 8L,
        shiny::uiOutput("verdict"),
        shiny::actionButton("run8", t("run8"), class = "btn-primary"),
        shiny::h4(t("scorecard")), shiny::tableOutput("scorecard"),
        shiny::fluidRow(
          shiny::column(5, shiny::h4(t("roc")),
                        shiny::plotOutput("roc_plot", height = 340)),
          shiny::column(7, shiny::h4(t("probability")),
                        shiny::plotOutput("prob_plot", height = 340))
        ),
        shiny::h4(t("sb_table")), shiny::tableOutput("sb_table"),
        shiny::plotOutput("sb_plot", height = 280),
        shiny::h4(t("validation")), shiny::verbatimTextOutput("val_print")
      ),
      step_panel(
        t, 9L,
        shiny::uiOutput("cci_verdict"),
        shiny::radioButtons("cci_mode", t("comp_mode"), stats::setNames(
          c("auto", "manual"), c(t("mode_auto"), t("mode_manual"))),
          inline = TRUE),
        shiny::checkboxGroupInput("cci_components", t("components"),
                                  choices = character(0), inline = TRUE),
        shiny::actionButton("run9", t("run9"), class = "btn-primary"),
        shiny::h4(t("cci_plot")), shiny::plotOutput("cci_plot"),
        shiny::fluidRow(
          shiny::column(5, shiny::h4(t("weights")),
                        shiny::plotOutput("cci_weights_plot", height = 300)),
          shiny::column(7, shiny::h4(t("components_plot")),
                        shiny::plotOutput("cci_components_plot",
                                          height = 300))
        ),
        shiny::h4(t("scorecard")), shiny::tableOutput("cci_scorecard"),
        shiny::h4(t("audit")), shiny::tableOutput("cci_audit"),
        shiny::h4(t("validation")), shiny::verbatimTextOutput("cci_print"),
        shiny::h4(t("cci_ref_heading")),
        shiny::p(shiny::em(t("cci_ref_help"))),
        shiny::actionButton("cci_ref", t("cci_ref"))
      ),
      step_panel(
        t, 10L,
        shiny::downloadButton("dl_cli", t("dl_cli")),
        shiny::downloadButton("dl_assess", t("dl_assess")),
        shiny::downloadButton("dl_audit", t("dl_audit")),
        shiny::downloadButton("dl_quality", t("dl_quality")),
        shiny::downloadButton("dl_presentation", t("dl_presentation")),
        shiny::downloadButton("dl_rds", t("dl_rds")),
        shiny::downloadButton("dl_script", t("dl_script")),
        shiny::downloadButton("dl_cci", t("dl_cci")),
        shiny::downloadButton("dl_cci_quality", t("dl_cci_quality")),
        shiny::h4(t("code")), shiny::verbatimTextOutput("script")
      )
    )
  )
}

# ---- helpers used by the server ---------------------------------------



parse_cutoffs <- function(text) {
  parts <- trimws(strsplit(text, ",")[[1]])
  parts <- parts[nzchar(parts)]
  out <- suppressWarnings(as.numeric(parts))
  if (anyNA(out)) {
    rcli_abort("Cut-offs must be numbers separated by commas.",
               "rcli_error_argument")
  }
  out
}

parse_start <- function(text) {
  if (!nzchar(trimws(text))) return(NULL)
  p <- suppressWarnings(as.integer(strsplit(trimws(text), "[- ]")[[1]]))
  if (length(p) != 2L || anyNA(p)) {
    rcli_abort("Start must look like 2000-1.", "rcli_error_argument")
  }
  p
}

data_summary <- function(data) {
  tm <- stats::time(data)
  f <- stats::frequency(data)
  rows <- lapply(colnames(data), function(nm) {
    span <- non_na_span(data[, nm])
    data.frame(series = nm, start = period_label(tm[span[1]], f),
               end = period_label(tm[span[2]], f),
               observations = sum(!is.na(data[, nm])),
               missing = sum(is.na(data[, nm][span[1]:span[2]])))
  })
  do.call(rbind, rows)
}

# Summary of series read from several files: one row per series.
series_summary <- function(series, p = function(x) x) {
  rows <- lapply(names(series), function(nm) {
    s <- series[[nm]]
    from <- attr(s, "frequency")
    data.frame(series = nm, file = attr(s, "file"), frequency = p(from),
               start = date_label(min(s$date), from),
               end = date_label(max(s$date), from),
               observations = nrow(s))
  })
  do.call(rbind, rows)
}

# A date written as the period of its frequency.
date_label <- function(d, from) {
  y <- as.integer(format(d, "%Y"))
  m <- as.integer(format(d, "%m"))
  switch(from,
         monthly = format(d, "%Y-%m"),
         quarterly = sprintf("%dQ%d", y, (m - 1L) %/% 3L + 1L),
         semiannual = sprintf("%dS%d", y, (m - 1L) %/% 6L + 1L),
         annual = as.character(y),
         format(d, "%Y-%m-%d"))
}

assessment_display <- function(tab, p = function(x) x) {
  out <- data.frame(
    candidate = paste0(tab$name, ifelse(tab$inverted, " *", "")),
    class = tab$class,
    rationale = ifelse(is.na(tab$rationale), "", tab$rationale),
    lead = tab$ccf_lag,
    median = tab$median_lead,
    led = sprintf("%.2f", tab$pct_led),
    missed = paste0(tab$missed, "/", tab$n_ref),
    extra = tab$extra,
    concordance = sprintf("%.2f", tab$concordance),
    granger_p = fmt_value(tab$granger_p),
    stringsAsFactors = FALSE
  )
  out$class <- p(out$class)
  translate_names(out, p)
}

quality_display <- function(q, p = function(x) x) {
  tab <- q@table
  status <- ifelse(is.na(tab$passed), "info",
                   ifelse(tab$passed, "pass", "fail"))
  thr <- p(tab$threshold)
  for (w in c("positive", "naive", "to", "within")) {
    thr <- gsub(paste0("\\b", w, "\\b"), p(w), thr)
  }
  out <- data.frame(group = p(tab$group), criterion = p(tab$criterion),
                    value = fmt_value(tab$value), threshold = thr,
                    status = p(status), stringsAsFactors = FALSE)
  translate_names(out, p)
}

verdict_colour <- c(good = "#1b7837", acceptable = "#b35806",
                    weak = "#b2182b")

deparse_value <- function(x) {
  paste(deparse(x, width.cutoff = 500L), collapse = "")
}

# R code reproducing the analysis done in the interface.
app_script <- function(state) {
  if (!is.null(state$prelude)) {
    # the coincident index of an earlier analysis became the reference
    lines <- c(state$prelude, "",
               "# The coincident index becomes the reference series",
               "cand <- cci_as_reference(cci)")
    if (isTRUE(state$cand_rebuilt)) {
      lines <- c(lines, "", candidate_lines(state, "cand@data"))
    }
    return(paste(c(lines, analysis_lines(state)), collapse = "\n"))
  }
  lines <- c("library(rcli)", "", data_lines(state))
  lines <- c(lines, "", candidate_lines(state, "data"))
  paste(c(lines, analysis_lines(state)), collapse = "\n")
}

# Step 1 of the script: the data as loaded, with the column separator and
# decimal mark of an uploaded file when they differ from read.csv()'s.
data_lines <- function(state) {
  if (identical(state$source, "upload_multi")) return(multi_lines(state))
  if (!identical(state$source, "upload")) {
    return(c("# 1. Data",
             sprintf("data <- simulate_cycles(freq = %s, seed = %s)",
                     state$frequency, state$seed)))
  }
  fmt <- ""
  sep <- if (is.null(state$sep)) "," else state$sep
  dec <- if (is.null(state$dec)) "." else state$dec
  if (sep != "," || dec != ".") {
    fmt <- sprintf(",\n                      sep = %s, dec = %s",
                   deparse_value(sep), deparse_value(dec))
  }
  c("# 1. Data",
    sprintf(paste0("data <- read_cli_data(%s, frequency = %s, start = %s,",
                   "\n                      check.names = FALSE%s)"),
            deparse_value(state$file_name), deparse_value(state$frequency),
            deparse_value(state$start), fmt))
}

# Step 1 of the script for one file per indicator: the files as read, and
# the frequency alignment done in step 2.
multi_lines <- function(state) {
  fmt <- ""
  if (!identical(state$sep, "auto")) {
    fmt <- paste0(fmt, ", sep = ", deparse_value(state$sep))
  }
  if (!identical(state$dec, "auto")) {
    fmt <- paste0(fmt, ", dec = ", deparse_value(state$dec))
  }
  lines <- c("# 1. Data: one file per indicator",
             sprintf("series <- read_cli_series(%s%s)",
                     deparse_value(state$file_name), fmt))
  if (is.null(state$align)) return(lines)
  c(lines, "# brought to one frequency in step 2", align_text(state$align))
}

# Step 2 of the script: the metadata and the candidate set built from `data`.
candidate_lines <- function(state, data) {
  meta <- state$meta
  c("# 2. Candidates and their economic rationale",
    sprintf(paste0("meta <- data.frame(\n  name = %s,\n",
                   "  rationale = %s,\n  source = %s,\n",
                   "  type = %s,\n  frequency = %s\n)"),
            deparse_value(meta$name),
            deparse_value(meta$rationale),
            deparse_value(meta$source),
            deparse_value(meta_column(meta, "type")),
            deparse_value(meta_column(meta, "frequency"))),
    sprintf(paste0("cand <- cli_candidates(%s, reference = ",
                   "\"%s\", meta = meta)"),
            data, state$reference))
}

meta_column <- function(meta, col) {
  if (is.null(meta[[col]])) rep(NA_character_, nrow(meta)) else meta[[col]]
}

# Steps 3 to 9 of the script.
analysis_lines <- function(state) {
  lines <- c("", "# 3. Specification", state$spec_call, "",
             "# 4-7. Cycles, turning points, classification, composite",
             "res <- cli_build(cand, spec)", "assessment(res)")
  if (identical(state$mode, "manual")) {
    shift_arg <- if (isTRUE(state$lag_shift)) {
      sprintf(paste0(",\n                     shifts = ",
                     "lag_shifts(%s, assessment(res))"),
              deparse_value(state$components))
    } else {
      ""
    }
    lines <- c(lines, sprintf(
      "cli <- cli_composite(cycles(res), %s, spec, cycles(res)[[\"%s\"]]%s)",
      deparse_value(state$components), state$reference, shift_arg),
      sprintf("val <- cli_validate(cli, cycles(res)[[\"%s\"]], spec)",
              state$reference),
      "pres <- cli_presentation(res, composite = cli)  # three OECD forms",
      "", "# 8. Validation and quality", "cli_quality(val, spec)")
  } else {
    lines <- c(lines, "audit_log(res)", "plot(res)",
               "pres <- cli_presentation(res)  # three OECD forms", "",
               "# 8. Validation and quality", "cli_quality(res)")
  }
  if (!is.null(state$cci_mode)) {
    call <- if (identical(state$cci_mode, "manual")) {
      sprintf("cci <- cci_build(res, components = %s, select = FALSE)",
              deparse_value(state$cci_components))
    } else {
      "cci <- cci_build(res)"
    }
    lines <- c(lines, "", "# 9. Coincident index", call, "cli_quality(cci)")
    if (!isTRUE(state$as_reference)) {
      lines <- c(lines, paste("# cand_cci <- cci_as_reference(cci)",
                              " # the index as reference"))
    }
  }
  lines
}




# ---- server -------------------------------------------------------------

app_server <- function(language = "id") {
  t <- app_translator(language)
  p <- phrase_translator(language)
  function(input, output, session) {
    rv <- shiny::reactiveValues(
      data = NULL, cand = NULL, spec = NULL, cycles = NULL, tps = NULL,
      assessment = NULL, cycles_used = NULL, composite = NULL,
      validation = NULL, audit = NULL, done = integer(0), meta = NULL,
      spec_call = NULL, mode = "auto", components = character(0),
      cci = NULL, cci_mode = NULL, prelude = NULL, cand_rebuilt = FALSE,
      loaded = NULL, meta_known = NULL, series = NULL, align = NULL
    )
    fields <- list(`1` = c("data", "series"),
                   `2` = c("cand", "meta", "align"),
                   `3` = c("spec", "spec_call"), `4` = "cycles", `5` = "tps",
                   `6` = c("assessment", "cycles_used"),
                   `7` = c("composite", "validation", "audit", "cci",
                           "cci_mode", "mode", "components"))
    reset_from <- function(k) {
      for (s in names(fields)) {
        if (as.integer(s) >= k) for (f in fields[[s]]) rv[[f]] <- NULL
      }
      rv$done <- rv$done[rv$done < k]
    }
    finish <- function(k) {
      reset_from(k + 1L)
      rv$done <- sort(unique(c(rv$done, k)))
    }
    safely <- function(expr) {
      tryCatch(
        withCallingHandlers(expr, warning = function(w) {
          shiny::showNotification(conditionMessage(w), type = "warning",
                                  duration = 8)
          invokeRestart("muffleWarning")
        }),
        error = function(e) {
          shiny::showNotification(
            paste(t("error"), conditionMessage(e), sep = ": "),
            type = "error", duration = 10
          )
          NULL
        }
      )
    }
    need <- function(k) {
      shiny::validate(shiny::need(k %in% rv$done, t("need_prev")))
    }
    reference <- function() rv$cand@reference
    # the coincident index (step 9) needs only the classification; it is
    # stored with the step-7 fields so that rebuilding the composite keeps it
    need_cci <- function() {
      shiny::validate(shiny::need(!is.null(rv$cci) &&
                                    !is.null(rv$cci@composite),
                                  t("need_cci")))
    }

    for (k in 1:9) {
      local({
        kk <- k
        shiny::observeEvent(input[[paste0("next", kk)]], {
          shiny::updateNavlistPanel(session, "step",
                                    selected = paste0("s", kk + 1L))
        })
      })
    }

    output$progress <- shiny::renderUI({
      marks <- vapply(1:10, function(k) {
        ok <- k %in% rv$done || (k == 10L && 7L %in% rv$done) ||
          (k == 8L && 7L %in% rv$done) || (k == 9L && !is.null(rv$cci))
        sprintf("%s %d", if (ok) "\u25CF" else "\u25CB", k)
      }, character(1))
      shiny::div(style = "margin-bottom: 10px; color: #555;",
                 shiny::strong(paste0(t("progress"), ": ")),
                 paste(marks, collapse = "  "))
    })

    # 1. Data --------------------------------------------------------------
    # the series names: the columns of one data set, or the series read from
    # several files (aligned in step 2)
    series_names <- function() {
      if (is.null(rv$series)) colnames(rv$data) else names(rv$series)
    }
    multi <- function() !is.null(rv$series)
    # the reference series whose type the step-2 entry holds
    ref_type_for <- NULL
    shiny::observeEvent(input$run1, {
      sep <- csv_choice(input$csv_sep, "sep")
      dec <- csv_choice(input$csv_dec, "dec")
      if (input$source == "upload_multi") {
        shiny::req(input$files)
        series <- safely(read_cli_series(
          stats::setNames(input$files$datapath, input$files$name),
          sep = sep, dec = dec))
        if (is.null(series)) return()
        data <- NULL
        fmt <- list(sep = sep, dec = dec)
        freq <- as.numeric(input$target_freq)
      } else {
        data <- safely({
          if (input$source == "upload") {
            shiny::req(input$file)
            f <- if (input$freq == "auto") NULL else as.numeric(input$freq)
            fmt <- csv_format(input$file$datapath, sep = sep, dec = dec)
            out <- read_cli_data(input$file$datapath, frequency = f,
                                 start = parse_start(input$start),
                                 check.names = FALSE, sep = fmt$sep,
                                 dec = fmt$dec)
            attr(out, "csv_format") <- fmt
            out
          } else {
            f <- if (input$source == "example_m") 12 else 4
            simulate_cycles(freq = f, seed = input$seed)
          }
        })
        if (is.null(data)) return()
        series <- NULL
        fmt <- attr(data, "csv_format")
        attr(data, "csv_format") <- NULL
        freq <- stats::frequency(data)
      }
      rv$data <- data
      rv$series <- series
      # the script reproduces the data as loaded, not later edits of step 1
      file_name <- switch(input$source,
                          upload = if (is.null(input$file)) "data.csv" else
                            input$file$name,
                          upload_multi = input$files$name,
                          "data.csv")
      rv$loaded <- list(
        source = input$source, file_name = file_name,
        start = if (input$source == "upload") parse_start(input$start) else
          NULL,
        seed = input$seed, sep = fmt$sep, dec = fmt$dec, frequency = freq
      )
      rv$meta_known <- NULL
      rv$prelude <- NULL
      rv$cand_rebuilt <- FALSE
      ref_type_for <<- NULL
      finish(1L)
      nms <- series_names()
      sel <- if ("reference" %in% nms) "reference" else nms[1]
      shiny::updateSelectInput(session, "reference", choices = nms,
                               selected = sel)
      monthly <- freq == 12
      shiny::updateNumericInput(session, "min_lead",
                                value = if (monthly) 3 else 1)
      shiny::updateNumericInput(session, "min_median_lead",
                                value = if (monthly) 1 else 0.5)
      shiny::showNotification(t("loaded"), type = "message")
    })
    # a new analysis frequency for files already read clears step 2 onwards
    shiny::observeEvent(input$target_freq, {
      f <- as.numeric(input$target_freq)
      if (!multi()) {
        # the files gave way to the coincident index: keep the frequency
        if (identical(rv$loaded$source, "upload_multi")) {
          shiny::updateSelectInput(session, "target_freq",
                                   selected = as.character(
                                     rv$loaded$frequency))
        }
        return()
      }
      if (identical(f, rv$loaded$frequency)) return()
      loaded <- rv$loaded
      loaded$frequency <- f
      rv$loaded <- loaded
      reset_from(2L)
      shiny::updateNumericInput(session, "min_lead",
                                value = if (f == 12) 3 else 1)
      shiny::updateNumericInput(session, "min_median_lead",
                                value = if (f == 12) 1 else 0.5)
    }, ignoreInit = TRUE)
    shiny::observeEvent(input$reference, {
      if (!is.null(rv$cand) && !identical(input$reference, reference())) {
        reset_from(2L)
      }
    }, ignoreInit = TRUE)
    output$data_summary <- shiny::renderTable({
      need(1L)
      tab <- if (multi()) series_summary(rv$series, p) else
        data_summary(rv$data)
      translate_names(tab, p)
    })
    output$overview <- shiny::renderPlot({
      need(1L)
      shiny::req(input$reference %in% series_names())
      if (multi()) {
        plot_series_dated(rv$series, input$reference, tr = p)
      } else {
        plot_series_overview(rv$data, input$reference, tr = p)
      }
    })

    # 2. Metadata ----------------------------------------------------------
    candidates_now <- shiny::reactive({
      need(1L)
      setdiff(series_names(), input$reference)
    })
    shown_cands <- character(0)
    output$meta_ui <- shiny::renderUI({
      # depends only on the data and the reference, so that the choices the
      # user made are not reset when later steps run
      shiny::req(!is.null(rv$data) || multi(), input$reference)
      cands <- setdiff(series_names(), input$reference)
      example <- !shiny::isolate(input$source) %in% c("upload",
                                                      "upload_multi")
      labels <- if (language == "id") oecd_rationales_id else oecd_rationales
      choices <- c(stats::setNames("", t("none")),
                   stats::setNames(names(labels), labels))
      type_choices <- c(stats::setNames("", t("none")),
                        stats::setNames(names(series_types),
                                        c(t("type_flow"), t("type_stock"),
                                          t("type_average"))))
      # entries follow the candidate names, since the order of the
      # candidates changes with the reference: first the entry shown for the
      # same candidate in the last rendering, then the metadata of the last
      # candidate set, then the default
      known <- shiny::isolate(rv$meta_known)
      shown <- shown_cands
      freq_keys <- names(series_frequencies)
      freq_choices <- c(stats::setNames("", t("none")),
                        stats::setNames(freq_keys,
                                        vapply(paste0("freq_", freq_keys), t,
                                               character(1))))
      keep <- function(id, default) {
        prefix <- sub("_[0-9]+$", "", id)
        nm <- cands[as.integer(sub("^[a-z]+_", "", id))]
        j <- match(nm, shown)
        if (!is.na(j)) {
          v <- shiny::isolate(input[[paste0(prefix, "_", j)]])
          if (!is.null(v)) return(v)
        }
        col <- c(rat = "rationale", typ = "type", src = "source",
                 frq = "frequency")[[prefix]]
        if (!is.null(known) && col %in% names(known) && nm %in% known$name) {
          v <- known[[col]][match(nm, known$name)]
          return(if (is.na(v)) "" else v)
        }
        default
      }
      # the frequency of a series read from a file is the detected one, so
      # it is shown, not chosen
      frq_cell <- function(i) {
        if (multi()) {
          from <- attr(rv$series[[cands[i]]], "frequency")
          return(shiny::tags$p(t(paste0("freq_", from)),
                               id = paste0("frq_text_", i),
                               style = "margin-top: 8px;"))
        }
        shiny::selectInput(paste0("frq_", i), NULL, freq_choices,
                           selected = keep(paste0("frq_", i), ""))
      }
      rows <- lapply(seq_along(cands), function(i) {
        shiny::fluidRow(
          shiny::column(2, shiny::tags$p(shiny::strong(cands[i]),
                                         style = "margin-top: 8px;")),
          shiny::column(3, shiny::selectInput(
            paste0("rat_", i), NULL, choices,
            selected = keep(paste0("rat_", i),
                            if (example) "early_stage" else ""))),
          shiny::column(2, shiny::selectInput(
            paste0("typ_", i), NULL, type_choices,
            selected = keep(paste0("typ_", i), ""))),
          shiny::column(2, frq_cell(i)),
          shiny::column(3, shiny::textInput(
            paste0("src_", i), NULL, keep(paste0("src_", i), ""),
            placeholder = t("data_source")))
        )
      })
      shown_cands <<- cands
      ref_row <- if (multi() && input$reference %in% names(rv$series)) {
        # the type belongs to one reference series
        old <- if (identical(ref_type_for, input$reference)) {
          shiny::isolate(input$ref_type)
        }
        ref_type_for <<- input$reference
        from <- attr(rv$series[[input$reference]], "frequency")
        type_row <- shiny::fluidRow(shiny::column(6, shiny::selectInput(
          "ref_type",
          sprintf("%s: %s (%s)", t("ref_type"), input$reference,
                  t(paste0("freq_", from))),
          type_choices, selected = if (is.null(old)) "" else old),
          shiny::helpText(t("ref_type_help"))))
        old_align <- shiny::isolate(list(
          align_method = input$align_method,
          align_indicator = input$align_indicator,
          week_date = input$week_date, align_coverage = input$align_coverage))
        shiny::tagList(
          type_row, shiny::h5(t("align_title")),
          align_ui(t, rv$series, input$reference, rv$loaded$frequency,
                   old_align))
      }
      shiny::tagList(
        ref_row,
        shiny::fluidRow(shiny::column(2, shiny::strong("")),
                        shiny::column(3, shiny::strong(t("rationale"))),
                        shiny::column(2, shiny::strong(t("var_type"))),
                        shiny::column(2, shiny::strong(t("var_freq"))),
                        shiny::column(3, shiny::strong(t("data_source")))),
        rows
      )
    })
    shiny::observeEvent(input$run2, {
      cands <- candidates_now()
      meta <- data.frame(
        name = cands,
        rationale = vapply(seq_along(cands), function(i) {
          v <- input[[paste0("rat_", i)]]
          if (is.null(v) || !nzchar(v)) NA_character_ else v
        }, character(1)),
        source = vapply(seq_along(cands), function(i) {
          v <- input[[paste0("src_", i)]]
          if (is.null(v) || !nzchar(v)) NA_character_ else v
        }, character(1)),
        type = vapply(seq_along(cands), function(i) {
          v <- input[[paste0("typ_", i)]]
          if (is.null(v) || !nzchar(v)) NA_character_ else v
        }, character(1)),
        frequency = vapply(seq_along(cands), function(i) {
          if (multi()) return(attr(rv$series[[cands[i]]], "frequency"))
          v <- input[[paste0("frq_", i)]]
          if (is.null(v) || !nzchar(v)) NA_character_ else v
        }, character(1)),
        stringsAsFactors = FALSE
      )
      align <- NULL
      data <- rv$data
      if (multi()) {
        rt <- if (is.null(input$ref_type)) NA_character_ else input$ref_type
        type <- stats::setNames(c(rt, meta$type),
                                c(input$reference, cands))
        type <- type[!is.na(type) & nzchar(type)]
        type <- type[intersect(names(rv$series), names(type))]
        align <- list(freq = rv$loaded$frequency, type = type,
                      reference = input$reference,
                      method = input$align_method,
                      indicator = input$align_indicator,
                      week_date = input$week_date,
                      min_coverage = input$align_coverage)
        # the interface runs the code it writes into the script
        data <- safely(eval_code(align_text(align), "data",
                                 list(series = rv$series)))
      }
      cand <- if (!is.null(data)) {
        safely(cli_candidates(data, input$reference, meta = meta))
      }
      if (is.null(cand)) {
        # a refused metadata set leaves no stale candidate set behind
        reset_from(2L)
        return()
      }
      rv$cand <- cand
      rv$meta <- meta
      rv$meta_known <- meta
      rv$align <- align
      rv$cand_rebuilt <- !is.null(rv$prelude)
      finish(2L)
    })
    output$cand_print <- shiny::renderPrint({
      need(2L)
      show(rv$cand)
    })

    # 3. Specification -------------------------------------------------------
    shiny::observeEvent(input$run3, {
      if (!2L %in% rv$done) {
        shiny::showNotification(t("need_prev"), type = "warning")
        return()
      }
      freq <- stats::frequency(rv$cand@data)
      # the interface runs the code it writes into the script
      code <- safely(spec_call(input, freq))
      spec <- if (!is.null(code)) safely(eval_code(code, "spec"))
      if (is.null(spec)) return()
      rv$spec <- spec
      rv$spec_call <- code
      finish(3L)
    })
    output$spec_print <- shiny::renderPrint({
      need(3L)
      show(rv$spec)
    })

    # 4. Cycles ------------------------------------------------------------
    shiny::observeEvent(input$run4, {
      if (!3L %in% rv$done) {
        shiny::showNotification(t("need_prev"), type = "warning")
        return()
      }
      cyc <- shiny::withProgress(message = t("run4"),
                                 safely(cli_cycles(rv$cand, rv$spec)))
      if (is.null(cyc)) return()
      rv$cycles <- cyc
      finish(4L)
      cands <- setdiff(names(cyc), reference())
      shiny::updateSelectInput(session, "cyc_series", choices = cands)
      shiny::updateSelectInput(session, "tp_series", choices = names(cyc))
      shiny::updateSelectInput(session, "as_series", choices = cands)
    })
    output$cycle_pair <- shiny::renderPlot({
      need(4L)
      shiny::req(input$cyc_series %in% names(rv$cycles))
      plot_cycle_pair(rv$cycles, reference(), input$cyc_series, tr = p)
    })
    output$cycle_steps <- shiny::renderPrint({
      need(4L)
      shiny::req(input$cyc_series %in% names(rv$cycles))
      show(rv$cycles[[input$cyc_series]])
    })
    output$cycles_grid <- shiny::renderPlot({
      need(4L)
      plot_cycles_grid(rv$cycles, tr = p)
    }, height = function() {
      n <- if (is.null(rv$cycles)) 1L else length(rv$cycles)
      180 * ceiling(n / 3)
    })

    # 5. Turning points ----------------------------------------------------
    shiny::observeEvent(input$run5, {
      if (!4L %in% rv$done) {
        shiny::showNotification(t("need_prev"), type = "warning")
        return()
      }
      tps <- safely(cli_turning_points(rv$cycles, rv$spec))
      if (is.null(tps)) return()
      rv$tps <- tps
      finish(5L)
    })
    output$tp_counts <- shiny::renderTable({
      need(5L)
      translate_names(data.frame(series = names(rv$tps),
                 peaks = vapply(rv$tps, function(x) sum(x@type == "peak"),
                                numeric(1)),
                 troughs = vapply(rv$tps, function(x) {
                   sum(x@type == "trough")
                 }, numeric(1))), p)
    }, digits = 0)
    output$tp_plot <- shiny::renderPlot({
      need(5L)
      shiny::req(input$tp_series %in% names(rv$tps))
      plot_turning_points(rv$tps[[input$tp_series]], rv$tps[[reference()]],
                          tr = p)
    })
    output$tp_table <- shiny::renderTable({
      need(5L)
      shiny::req(input$tp_series %in% names(rv$tps))
      df <- as.data.frame(rv$tps[[input$tp_series]])
      df$type <- p(df$type)
      translate_names(df[, c("period", "type", "value")], p)
    })

    # 6. Classification ----------------------------------------------------
    shiny::observeEvent(input$run6, {
      if (!5L %in% rv$done) {
        shiny::showNotification(t("need_prev"), type = "warning")
        return()
      }
      a <- shiny::withProgress(message = t("run6"),
                               safely(cli_assess(rv$cand, rv$spec, rv$cycles)))
      if (is.null(a)) return()
      used <- rv$cycles
      for (nm in a@inverted) used[[nm]] <- invert_cycle(used[[nm]])
      rv$assessment <- a
      rv$cycles_used <- used
      finish(6L)
      shiny::updateCheckboxGroupInput(
        session, "manual_components", choices = a@table$name,
        selected = leaders(a), inline = TRUE)
      shiny::updateCheckboxGroupInput(
        session, "cci_components", choices = a@table$name,
        selected = coincidents(a), inline = TRUE)
    })
    output$assess_table <- shiny::renderTable({
      need(6L)
      assessment_display(rv$assessment@table, p)
    })
    output$leads_plot <- shiny::renderPlot({
      need(6L)
      plot_leads(rv$assessment, rv$spec, tr = p)
    })
    output$ccf_plot <- shiny::renderPlot({
      need(6L)
      shiny::req(input$as_series %in% names(rv$cycles_used))
      plot_ccf(rv$cycles_used, reference(), input$as_series,
               rv$spec@ccf_lag_max, tr = p)
    })
    output$aligned_plot <- shiny::renderPlot({
      need(6L)
      shiny::req(input$as_series %in% names(rv$cycles_used))
      tab <- rv$assessment@table
      lag <- tab$ccf_lag[tab$name == input$as_series]
      plot_cycle_pair(rv$cycles_used, reference(), input$as_series,
                      ref_tp = rv$tps[[reference()]],
                      shift = if (is.na(lag)) 0L else as.integer(lag), tr = p)
    })
    output$reasons <- shiny::renderPrint({
      need(6L)
      tab <- rv$assessment@table
      out <- tab[tab$class != "leading", c("name", "class", "reasons")]
      out$class <- p(out$class)
      out$reasons <- translate_reasons(out$reasons, language)
      print(translate_names(out, p), row.names = FALSE)
    })

    # 7. Composite ---------------------------------------------------------
    shiny::observeEvent(input$run7, {
      if (!6L %in% rv$done) {
        shiny::showNotification(t("need_prev"), type = "warning")
        return()
      }
      ref_cs <- rv$cycles_used[[reference()]]
      res <- safely({
        if (input$comp_mode == "auto") {
          if (length(leaders(rv$assessment)) == 0L) {
            rcli_abort(t("no_leaders"), "rcli_error_no_leaders")
          }
          select_components(rv$cycles_used, rv$assessment, rv$spec,
                            reference())
        } else {
          comps <- input$manual_components
          if (length(comps) == 0L) {
            rcli_abort(t("components"), "rcli_error_argument")
          }
          shifts <- if (isTRUE(rv$spec@lag_shift)) {
            lag_shifts(comps, rv$assessment)
          }
          comp <- cli_composite(rv$cycles_used, comps, rv$spec, ref_cs,
                                shifts = shifts)
          val <- cli_validate(comp, ref_cs, rv$spec)
          list(composite = comp, validation = val,
               audit = audit_row(1L, "manual selection", comps, val,
                                 composite_score(val, rv$spec), rv$spec))
        }
      })
      if (is.null(res) || is.null(res$composite)) return()
      rv$composite <- res$composite
      rv$validation <- res$validation
      rv$audit <- res$audit
      rv$mode <- input$comp_mode
      rv$components <- res$composite@components
      finish(7L)
    })
    output$composite_plot <- shiny::renderPlot({
      need(7L)
      plot_composite(rv$composite, rv$cycles_used[[reference()]],
                     rv$tps[[reference()]], tr = p)
    })
    output$weights_plot <- shiny::renderPlot({
      need(7L)
      plot_weights(rv$composite, tr = p)
    })
    output$components_plot <- shiny::renderPlot({
      need(7L)
      plot_components(rv$cycles_used, rv$composite, tr = p)
    })
    output$audit_table <- shiny::renderTable({
      need(7L)
      a <- rv$audit
      a$action <- p(a$action)
      a$passed <- ifelse(a$passed, p("pass"), p("fail"))
      translate_names(a[, c("iteration", "action", "components", "ccf_lag",
                            "median_lead", "passed", "score")], p)
    })
    output$audit_plot <- shiny::renderPlot({
      need(7L)
      plot_audit(rv$audit, tr = p)
    })

    # 8. Validation and quality ---------------------------------------------
    quality <- shiny::reactive({
      need(7L)
      cli_quality(rv$validation, rv$spec)
    })
    shiny::observeEvent(input$run8, {
      if (!7L %in% rv$done) {
        shiny::showNotification(t("need_prev"), type = "warning")
        return()
      }
      if (length(rv$spec@oos_cutoffs) == 0L) {
        shiny::showNotification(t("no_cutoffs"), type = "warning")
        return()
      }
      sb <- shiny::withProgress(
        message = t("run8"),
        safely(cli_selection_bias(rv$cand, rv$spec, rv$spec@oos_cutoffs))
      )
      if (is.null(sb)) return()
      val <- rv$validation
      val@out_of_sample <- sb
      val@quality <- cli_quality(val, rv$spec)
      rv$validation <- val
    })
    output$verdict <- shiny::renderUI({
      q <- quality()
      shiny::div(
        style = sprintf(paste("background: %s; color: white; padding: 14px;",
                              "border-radius: 6px; margin-bottom: 14px;"),
                        verdict_colour[[q@verdict]]),
        shiny::h3(style = "margin: 0;",
                  paste0(t("verdict"), ": ", t(q@verdict))),
        shiny::p(style = "margin: 6px 0 0 0;", t(paste0(q@verdict, "_note")))
      )
    })
    output$scorecard <- shiny::renderTable({
      quality_display(quality(), p)
    })
    probability <- shiny::reactive({
      need(7L)
      contraction_probability(rv$composite, rv$cycles_used[[reference()]],
                              rv$spec)
    })
    output$roc_plot <- shiny::renderPlot({
      pr <- probability()
      shiny::req(!is.null(pr))
      plot_roc(roc_curve(pr$probability, pr$contraction),
               rv$validation@probability$auc, tr = p)
    })
    output$prob_plot <- shiny::renderPlot({
      pr <- probability()
      shiny::req(!is.null(pr))
      plot_probability(pr, rv$tps[[reference()]], tr = p)
    })
    output$sb_table <- shiny::renderTable({
      need(7L)
      sb <- rv$validation@out_of_sample
      shiny::validate(shiny::need(nrow(sb) > 0L, t("no_cutoffs")))
      sb$note <- p(sb$note)
      translate_names(sb[, c("cutoff", "components", "median_lead_in",
                             "median_lead_out", "pct_led_out", "n_tp_out",
                             "lead_gap", "note")], p)
    })
    output$sb_plot <- shiny::renderPlot({
      need(7L)
      sb <- rv$validation@out_of_sample
      shiny::req(nrow(sb) > 0L)
      plot_selection_bias(sb, tr = p)
    })
    output$val_print <- shiny::renderPrint({
      need(7L)
      show(rv$validation)
    })

    # 9. Coincident index ---------------------------------------------------
    shiny::observeEvent(input$run9, {
      if (!6L %in% rv$done) {
        shiny::showNotification(t("need_prev"), type = "warning")
        return()
      }
      base <- new("CliResult", spec = rv$spec, candidates = rv$cand,
                  cycles = rv$cycles_used, turning_points = rv$tps,
                  assessment = rv$assessment, composite = NULL,
                  validation = NULL, audit = data.frame())
      cci <- shiny::withProgress(message = t("run9"), safely({
        if (input$cci_mode == "auto") {
          if (length(coincidents(rv$assessment)) == 0L) {
            rcli_abort(t("no_coincident"), "rcli_error_no_coincident")
          }
          cci_build(base)
        } else {
          comps <- input$cci_components
          if (length(comps) == 0L) {
            rcli_abort(t("components"), "rcli_error_argument")
          }
          cci_build(base, components = comps, select = FALSE)
        }
      }))
      if (is.null(cci) || is.null(cci@composite)) return()
      rv$cci <- cci
      rv$cci_mode <- input$cci_mode
    })
    # the coincident index becomes the reference of a new analysis
    shiny::observeEvent(input$cci_ref, {
      if (is.null(rv$cci) || is.null(rv$cci@composite)) {
        shiny::showNotification(t("need_cci"), type = "warning")
        return()
      }
      cand <- safely(cci_as_reference(rv$cci))
      if (is.null(cand)) return()
      state <- current_state()
      state$as_reference <- TRUE
      prelude <- app_script(state)
      reset_from(2L)
      rv$data <- cand@data
      rv$series <- NULL
      rv$cand <- cand
      rv$meta <- cand@meta
      rv$meta_known <- cand@meta
      rv$prelude <- prelude
      rv$cand_rebuilt <- FALSE
      rv$done <- 1:2
      shiny::updateSelectInput(session, "reference",
                               choices = colnames(cand@data),
                               selected = cand@reference)
      shiny::updateNavlistPanel(session, "step", selected = "s3")
      shiny::showNotification(t("cci_ref_done"), type = "message")
    })
    cci_quality <- shiny::reactive({
      need_cci()
      cli_quality(rv$cci)
    })
    output$cci_verdict <- shiny::renderUI({
      q <- cci_quality()
      note <- if (q@verdict == "acceptable") "acceptable_note_cci" else
        paste0(q@verdict, "_note")
      shiny::div(
        style = sprintf(paste("background: %s; color: white; padding: 14px;",
                              "border-radius: 6px; margin-bottom: 14px;"),
                        verdict_colour[[q@verdict]]),
        shiny::h3(style = "margin: 0;",
                  paste0(t("verdict"), ": ", t(q@verdict))),
        shiny::p(style = "margin: 6px 0 0 0;", t(note))
      )
    })
    output$cci_plot <- shiny::renderPlot({
      need_cci()
      plot_composite(rv$cci@composite, rv$cycles_used[[reference()]],
                     rv$tps[[reference()]], tr = p, label = "coincident index")
    })
    output$cci_weights_plot <- shiny::renderPlot({
      need_cci()
      plot_weights(rv$cci@composite, tr = p)
    })
    output$cci_components_plot <- shiny::renderPlot({
      need_cci()
      plot_components(rv$cycles_used, rv$cci@composite, tr = p)
    })
    output$cci_scorecard <- shiny::renderTable({
      quality_display(cci_quality(), p)
    })
    output$cci_audit <- shiny::renderTable({
      need_cci()
      a <- rv$cci@audit
      a$action <- p(a$action)
      a$passed <- ifelse(a$passed, p("pass"), p("fail"))
      translate_names(a[, c("iteration", "action", "components", "ccf_lag",
                            "median_lead", "passed", "score")], p)
    })
    output$cci_print <- shiny::renderPrint({
      need_cci()
      show(rv$cci@validation)
    })

    # 10. Export -----------------------------------------------------------
    result <- shiny::reactive({
      need(7L)
      new("CliResult", spec = rv$spec, candidates = rv$cand,
          cycles = rv$cycles_used, turning_points = rv$tps,
          assessment = rv$assessment, composite = rv$composite,
          validation = rv$validation, audit = rv$audit)
    })
    current_state <- function() {
      list(
        source = rv$loaded$source,
        file_name = rv$loaded$file_name,
        frequency = rv$loaded$frequency, align = rv$align,
        start = rv$loaded$start,
        seed = rv$loaded$seed, sep = rv$loaded$sep, dec = rv$loaded$dec,
        meta = rv$meta,
        reference = if (is.null(rv$cand)) NULL else reference(),
        spec_call = rv$spec_call, mode = rv$mode,
        components = rv$components,
        lag_shift = !is.null(rv$spec) && isTRUE(rv$spec@lag_shift),
        cci_mode = rv$cci_mode,
        cci_components = if (is.null(rv$cci)) NULL else
          rv$cci@composite@components,
        prelude = rv$prelude, cand_rebuilt = rv$cand_rebuilt
      )
    }
    script <- shiny::reactive({
      need(7L)
      app_script(current_state())
    })
    output$script <- shiny::renderText(script())
    csv_download <- function(name, value) {
      shiny::downloadHandler(
        filename = function() paste0(name, ".csv"),
        content = function(file) {
          utils::write.csv(value(), file, row.names = FALSE)
        }
      )
    }
    output$dl_cli <- csv_download("cli", function() {
      as.data.frame(rv$composite)
    })
    output$dl_assess <- csv_download("assessment", function() {
      rv$assessment@table
    })
    output$dl_audit <- csv_download("audit_log", function() rv$audit)
    output$dl_quality <- csv_download("quality", function() {
      as.data.frame(quality())
    })
    presentation <- shiny::reactive({
      need(7L)
      cli_presentation(result())
    })
    output$pres_plot <- shiny::renderPlot({
      shiny::req(input$pres_form)
      plot_presentation(presentation(), input$pres_form, tr = p)
    })
    output$dl_presentation <- csv_download("cli_presentation", presentation)
    output$dl_rds <- shiny::downloadHandler(
      filename = function() "cli_result.rds",
      content = function(file) saveRDS(result(), file)
    )
    output$dl_script <- shiny::downloadHandler(
      filename = function() "cli_analysis.R",
      content = function(file) writeLines(script(), file)
    )
    output$dl_cci <- csv_download("cci", function() {
      need_cci()
      as.data.frame(rv$cci@composite)
    })
    output$dl_cci_quality <- csv_download("cci_quality", function() {
      as.data.frame(cci_quality())
    })
  }
}
