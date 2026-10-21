#' Read reference and candidate series from a CSV file
#'
#' Reads a CSV file with one column per series. If the first column holds
#' dates (`2001-01`, `2001-01-15` or `2001Q1`), the frequency and start are
#' taken from it; otherwise give `frequency` and `start`. Non-numeric
#' columns other than the date column are dropped.
#'
#' @param file Path to a CSV file, or a data frame already read.
#' @param frequency `NULL` (detect from dates), 12 or 4.
#' @param start Start as `c(year, period)` when there is no date column.
#' @param ... Passed to [utils::read.csv()].
#' @return A multivariate `ts`.
#' @examples
#' df <- data.frame(date = c("2001Q1", "2001Q2", "2001Q3"),
#'                  gdp = c(100, 101, 103), sales = c(50, 52, 51))
#' read_cli_data(df)
#' @export
read_cli_data <- function(file, frequency = NULL, start = NULL, ...) {
  df <- if (is.data.frame(file)) file else utils::read.csv(file, ...)
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
  num <- vapply(df, is.numeric, logical(1))
  if (!any(num)) {
    rcli_abort("No numeric column found.", "rcli_error_argument")
  }
  if (is.null(frequency) || is.null(start)) {
    rcli_abort("Give `frequency` and `start` when there is no date column.",
               "rcli_error_argument")
  }
  check_frequency(frequency)
  stats::ts(as.matrix(df[num]), start = start, frequency = frequency)
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

#' Run the step-by-step graphical interface
#'
#' `run_app()` opens a Shiny application that walks through the workflow in
#' nine steps: data, candidate metadata, specification, cycles, turning
#' points, classification, composite, validation with the quality scorecard,
#' and export (results, a `CliResult` object and an R script that reproduces
#' the analysis). Each step unlocks the next one; re-running a step clears
#' the results that depend on it.
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
aggregator_choices <- c("equal", "pca", "cb", "dfm")
names(aggregator_choices) <- c("Equal weights (OECD)",
                               "First principal component",
                               "Conference Board", "Dynamic factor model")

step_panel <- function(t, k, ...) {
  shiny::tabPanel(
    t(paste0("s", k)), value = paste0("s", k),
    shiny::h3(t(paste0("s", k))),
    shiny::p(shiny::em(t(paste0("h", k)))),
    ...,
    if (k < 9L) {
      shiny::div(style = "margin: 20px 0;",
                 shiny::actionButton(paste0("next", k), t("next_step")))
    }
  )
}

app_ui <- function(language = "id") {
  t <- app_translator(language)
  has_seasonal <- requireNamespace("seasonal", quietly = TRUE)
  shiny::fluidPage(
    shiny::titlePanel(t("title")),
    shiny::uiOutput("progress"),
    shiny::navlistPanel(
      id = "step", widths = c(3, 9),
      step_panel(
        t, 1L,
        shiny::fluidRow(
          shiny::column(5,
            shiny::radioButtons("source", t("source"), stats::setNames(
              c("example_m", "example_q", "upload"),
              c(t("src_example_m"), t("src_example_q"), t("src_upload")))),
            shiny::numericInput("seed", t("seed"), 2026, min = 1),
            shiny::fileInput("file", t("file"), accept = ".csv"),
            shiny::selectInput("freq", t("freq"), stats::setNames(
              c("auto", "12", "4"),
              c(t("freq_auto"), t("monthly"), t("quarterly")))),
            shiny::textInput("start", t("start"), ""),
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
            shiny::selectInput("filter", t("filter"), filter_choices),
            shiny::selectInput("aggregator", t("aggregator"),
                               aggregator_choices),
            shiny::selectInput("transform", t("transform"),
                               c("auto", "log", "none")),
            shiny::checkboxInput("seasonal", paste(
              t("seasonal"), if (!has_seasonal) t("seasonal_missing")),
              FALSE),
            shiny::numericInput("outlier", t("outlier"), 5, min = 1),
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
        shiny::plotOutput("audit_plot", height = 250)
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
        shiny::downloadButton("dl_cli", t("dl_cli")),
        shiny::downloadButton("dl_assess", t("dl_assess")),
        shiny::downloadButton("dl_audit", t("dl_audit")),
        shiny::downloadButton("dl_quality", t("dl_quality")),
        shiny::downloadButton("dl_rds", t("dl_rds")),
        shiny::downloadButton("dl_script", t("dl_script")),
        shiny::h4(t("code")), shiny::verbatimTextOutput("script")
      )
    )
  )
}

# ---- helpers used by the server ---------------------------------------

make_filter <- function(key) {
  switch(key, hp_double = hp_double_filter(), hp = hp_filter(),
         cf = cf_filter(), bk = bk_filter(), hamilton = hamilton_filter())
}

make_aggregator <- function(key) {
  switch(key, equal = equal_weight(), pca = principal_component(),
         cb = conference_board(), dfm = dynamic_factor())
}

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
  for (w in c("positive", "naive", "to")) {
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
  lines <- c("library(rcli)", "", "# 1. Data")
  if (state$source == "upload") {
    lines <- c(lines, sprintf(
      "data <- read_cli_data(\"%s\", frequency = %s, start = %s)",
      state$file_name, deparse_value(state$frequency),
      deparse_value(state$start)))
  } else {
    lines <- c(lines, sprintf("data <- simulate_cycles(freq = %s, seed = %s)",
                              state$frequency, state$seed))
  }
  meta <- state$meta
  lines <- c(lines, "", "# 2. Candidates and their economic rationale",
             sprintf(paste0("meta <- data.frame(\n  name = %s,\n",
                            "  rationale = %s,\n  source = %s,\n",
                            "  type = %s\n)"),
                     deparse_value(meta$name),
                     deparse_value(meta$rationale),
                     deparse_value(meta$source),
                     deparse_value(if (is.null(meta$type)) {
                       rep(NA_character_, nrow(meta))
                     } else {
                       meta$type
                     })),
             sprintf(paste0("cand <- cli_candidates(data, reference = ",
                            "\"%s\", meta = meta)"),
                     state$reference),
             "", "# 3. Specification", state$spec_call, "",
             "# 4-7. Cycles, turning points, classification, composite",
             "res <- cli_build(cand, spec)", "assessment(res)")
  if (identical(state$mode, "manual")) {
    lines <- c(lines, sprintf(
      "cli <- cli_composite(cycles(res), %s, spec, cycles(res)[[\"%s\"]])",
      deparse_value(state$components), state$reference),
      sprintf("val <- cli_validate(cli, cycles(res)[[\"%s\"]], spec)",
              state$reference),
      "", "# 8. Validation and quality", "cli_quality(val, spec)")
  } else {
    lines <- c(lines, "audit_log(res)", "plot(res)", "",
               "# 8. Validation and quality", "cli_quality(res)")
  }
  paste(lines, collapse = "\n")
}

spec_call <- function(input, freq) {
  cut <- parse_cutoffs(input$oos_cutoffs)
  agg <- c(equal = "equal_weight()", pca = "principal_component()",
           cb = "conference_board()", dfm = "dynamic_factor()")
  flt <- c(hp_double = "hp_double_filter()", hp = "hp_filter()",
           cf = "cf_filter()", bk = "bk_filter()",
           hamilton = "hamilton_filter()")
  sprintf(paste0(
    "spec <- cli_spec(\n  freq = %s, filter = %s, aggregator = %s,\n",
    "  transform = \"%s\", seasonal_adjust = %s, outlier_threshold = %s,\n",
    "  min_lead = %s, min_median_lead = %s, min_consistency = %s,\n",
    "  max_missed = %s, max_extra = %s, alpha = %s, min_auc = %s,\n",
    "  min_components = %s, max_iter = %s, oos_cutoffs = %s\n)"),
    freq, flt[[input$filter]], agg[[input$aggregator]], input$transform,
    input$seasonal, input$outlier, input$min_lead, input$min_median_lead,
    input$min_consistency, input$max_missed, input$max_extra, input$alpha,
    input$min_auc, input$min_components, input$max_iter,
    deparse_value(cut))
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
      spec_call = NULL, mode = "auto", components = character(0)
    )
    fields <- list(`1` = "data", `2` = c("cand", "meta"),
                   `3` = c("spec", "spec_call"), `4` = "cycles", `5` = "tps",
                   `6` = c("assessment", "cycles_used"),
                   `7` = c("composite", "validation", "audit"))
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

    for (k in 1:8) {
      local({
        kk <- k
        shiny::observeEvent(input[[paste0("next", kk)]], {
          shiny::updateNavlistPanel(session, "step",
                                    selected = paste0("s", kk + 1L))
        })
      })
    }

    output$progress <- shiny::renderUI({
      marks <- vapply(1:9, function(k) {
        ok <- k %in% rv$done || (k == 9L && 7L %in% rv$done) ||
          (k == 8L && 7L %in% rv$done)
        sprintf("%s %d", if (ok) "\u25CF" else "\u25CB", k)
      }, character(1))
      shiny::div(style = "margin-bottom: 10px; color: #555;",
                 shiny::strong(paste0(t("progress"), ": ")),
                 paste(marks, collapse = "  "))
    })

    # 1. Data --------------------------------------------------------------
    shiny::observeEvent(input$run1, {
      data <- safely({
        if (input$source == "upload") {
          shiny::req(input$file)
          freq <- if (input$freq == "auto") NULL else as.numeric(input$freq)
          read_cli_data(input$file$datapath, frequency = freq,
                        start = parse_start(input$start), check.names = FALSE)
        } else {
          freq <- if (input$source == "example_m") 12 else 4
          simulate_cycles(freq = freq, seed = input$seed)
        }
      })
      if (is.null(data)) return()
      rv$data <- data
      finish(1L)
      sel <- if ("reference" %in% colnames(data)) "reference" else
        colnames(data)[1]
      shiny::updateSelectInput(session, "reference", choices = colnames(data),
                               selected = sel)
      monthly <- stats::frequency(data) == 12
      shiny::updateNumericInput(session, "min_lead",
                                value = if (monthly) 3 else 1)
      shiny::updateNumericInput(session, "min_median_lead",
                                value = if (monthly) 1 else 0.5)
      shiny::showNotification(t("loaded"), type = "message")
    })
    shiny::observeEvent(input$reference, {
      if (!is.null(rv$cand) && !identical(input$reference, reference())) {
        reset_from(2L)
      }
    }, ignoreInit = TRUE)
    output$data_summary <- shiny::renderTable({
      need(1L)
      translate_names(data_summary(rv$data), p)
    })
    output$overview <- shiny::renderPlot({
      need(1L)
      shiny::req(input$reference %in% colnames(rv$data))
      plot_series_overview(rv$data, input$reference, tr = p)
    })

    # 2. Metadata ----------------------------------------------------------
    candidates_now <- shiny::reactive({
      need(1L)
      setdiff(colnames(rv$data), input$reference)
    })
    output$meta_ui <- shiny::renderUI({
      # depends only on the data and the reference, so that the choices the
      # user made are not reset when later steps run
      shiny::req(rv$data, input$reference)
      cands <- setdiff(colnames(rv$data), input$reference)
      example <- shiny::isolate(input$source) != "upload"
      labels <- if (language == "id") oecd_rationales_id else oecd_rationales
      choices <- c(stats::setNames("", t("none")),
                   stats::setNames(names(labels), labels))
      type_choices <- c(stats::setNames("", t("none")),
                        stats::setNames(names(series_types),
                                        c(t("type_flow"), t("type_stock"),
                                          t("type_average"))))
      keep <- function(id, default) {
        v <- shiny::isolate(input[[id]])
        if (is.null(v)) default else v
      }
      rows <- lapply(seq_along(cands), function(i) {
        shiny::fluidRow(
          shiny::column(3, shiny::tags$p(shiny::strong(cands[i]),
                                         style = "margin-top: 8px;")),
          shiny::column(4, shiny::selectInput(
            paste0("rat_", i), NULL, choices,
            selected = keep(paste0("rat_", i),
                            if (example) "early_stage" else ""))),
          shiny::column(2, shiny::selectInput(
            paste0("typ_", i), NULL, type_choices,
            selected = keep(paste0("typ_", i), ""))),
          shiny::column(3, shiny::textInput(
            paste0("src_", i), NULL, keep(paste0("src_", i), ""),
            placeholder = t("data_source")))
        )
      })
      shiny::tagList(
        shiny::fluidRow(shiny::column(3, shiny::strong("")),
                        shiny::column(4, shiny::strong(t("rationale"))),
                        shiny::column(2, shiny::strong(t("var_type"))),
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
        stringsAsFactors = FALSE
      )
      cand <- safely(cli_candidates(rv$data, input$reference, meta = meta))
      if (is.null(cand)) return()
      rv$cand <- cand
      rv$meta <- meta
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
      freq <- stats::frequency(rv$data)
      spec <- safely(cli_spec(
        freq = freq, filter = make_filter(input$filter),
        aggregator = make_aggregator(input$aggregator),
        transform = input$transform, seasonal_adjust = input$seasonal,
        outlier_threshold = input$outlier, min_lead = input$min_lead,
        min_median_lead = input$min_median_lead,
        min_consistency = input$min_consistency,
        max_missed = input$max_missed, max_extra = input$max_extra,
        alpha = input$alpha, min_auc = input$min_auc,
        min_components = input$min_components, max_iter = input$max_iter,
        oos_cutoffs = parse_cutoffs(input$oos_cutoffs)
      ))
      if (is.null(spec)) return()
      rv$spec <- spec
      rv$spec_call <- spec_call(input, freq)
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
          comp <- cli_composite(rv$cycles_used, comps, rv$spec, ref_cs)
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

    # 9. Export ------------------------------------------------------------
    result <- shiny::reactive({
      need(7L)
      new("CliResult", spec = rv$spec, candidates = rv$cand,
          cycles = rv$cycles_used, turning_points = rv$tps,
          assessment = rv$assessment, composite = rv$composite,
          validation = rv$validation, audit = rv$audit)
    })
    script <- shiny::reactive({
      need(7L)
      app_script(list(
        source = input$source,
        file_name = if (is.null(input$file)) "data.csv" else input$file$name,
        frequency = stats::frequency(rv$data),
        start = if (input$source == "upload") parse_start(input$start) else
          NULL,
        seed = input$seed, meta = rv$meta, reference = reference(),
        spec_call = rv$spec_call, mode = rv$mode,
        components = rv$components
      ))
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
    output$dl_rds <- shiny::downloadHandler(
      filename = function() "cli_result.rds",
      content = function(file) saveRDS(result(), file)
    )
    output$dl_script <- shiny::downloadHandler(
      filename = function() "cli_analysis.R",
      content = function(file) writeLines(script(), file)
    )
  }
}
