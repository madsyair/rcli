# Package options in the interface (FR-010): the advanced options of step 3,
# the alignment options of step 2 and the code that both the interface and
# the exported script run. The interface evaluates the same text it writes
# into the script, so the two cannot differ.

# ---- code text -------------------------------------------------------------

# Whether an input holds a value (an empty numeric input is NA). Inputs
# come from the browser and may be anything a crafted message holds, so
# only a single atomic value counts.
given <- function(x) {
  is.atomic(x) && length(x) == 1L && !is.na(x) && !identical(x, "")
}

# Refuse an input that cannot be written as code safely.
bad_input <- function(id) {
  rcli_abort(sprintf("Invalid value of the input '%s'.", id),
             "rcli_error_argument")
}

# `fun(name = value, ...)` with the given arguments; values are code text.
call_text <- function(fun, args = list()) {
  args <- args[!vapply(args, is.null, logical(1))]
  if (length(args) == 0L) return(paste0(fun, "()"))
  paste0(fun, "(", paste(names(args), "=", unlist(args), collapse = ", "),
         ")")
}

# Code text of a numeric input, or NULL when it is empty. Only a single
# finite number passes; it is written as a double (the browser sends whole
# numbers as integers), so the text holds nothing but the number.
value_text <- function(x, id = "number") {
  if (is.null(x) || (is.atomic(x) && length(x) == 1L && is.na(x))) {
    return(NULL)
  }
  if (!is.atomic(x) || length(x) != 1L || is.logical(x)) bad_input(id)
  v <- suppressWarnings(as.numeric(unname(x)))
  if (!is.finite(v)) bad_input(id)
  deparse_value(v)
}

# Code text of a choice input, which must be one of `allowed`.
choice_text <- function(x, allowed, id = "choice") {
  if (!is.atomic(x) || length(x) != 1L || !is.character(x) ||
      !x %in% allowed) {
    bad_input(id)
  }
  chr_text(unname(x))
}

# Code text of a character vector, names included, that reads back as the
# same vector whatever the strings hold (quotes, backticks, line breaks):
# names come from file names and column headers, and the interface runs
# this text. A vector that does not read back exactly is refused.
chr_text <- function(x) {
  if (!is.atomic(x)) bad_input("text")
  nm <- names(x)
  x <- as.character(x)
  fail <- function() {
    rcli_abort(paste("A series name or value cannot be written as R code;",
                     "rename the file or column."), "rcli_error_argument")
  }
  vals <- tryCatch(encodeString(unname(x), quote = "\""),
                   error = function(e) fail())
  # plain names only for ASCII names that need no quotes, so that the
  # script also runs in sessions that are not UTF-8
  plain <- !is.null(nm) && tryCatch(
    all(nzchar(nm) & !grepl("[^ -~]", nm, useBytes = TRUE) &
          make.names(nm) == nm),
    error = function(e) FALSE)
  out <- if (is.null(nm)) {
    if (length(x) == 1L) vals else paste0("c(", paste(vals, collapse = ", "),
                                          ")")
  } else if (plain) {
    paste0("c(", paste(nm, "=", vals, collapse = ", "), ")")
  } else {
    nms <- tryCatch(encodeString(nm, quote = "\""),
                    error = function(e) fail())
    paste0("stats::setNames(c(", paste(vals, collapse = ", "), "), c(",
           paste(nms, collapse = ", "), "))")
  }
  # read back with nothing but `c`, `::` and the literals available
  safe <- list2env(list(c = base::c, `::` = base::`::`), parent = emptyenv())
  back <- tryCatch(eval(parse(text = out), envir = safe),
                   error = function(e) NULL)
  ref <- x
  if (!is.null(nm)) names(ref) <- nm
  if (!identical(back, ref)) fail()
  out
}

# `name <- fun(...)`, wrapping the arguments over lines of at most `width`
# characters, continuation lines aligned after the opening parenthesis. An
# argument without a name is passed by position.
assign_text <- function(name, fun, args, width = 78L) {
  args <- args[!vapply(args, is.null, logical(1))]
  parts <- ifelse(nzchar(names(args)),
                  paste(names(args), "=", unlist(args)), unlist(args))
  head <- paste0(name, " <- ", fun, "(")
  pad <- strrep(" ", nchar(head))
  lines <- character(0)
  cur <- head
  for (k in seq_along(parts)) {
    piece <- if (k < length(parts)) paste0(parts[k], ",") else
      paste0(parts[k], ")")
    fresh <- cur %in% c(head, pad)
    if (!fresh && nchar(cur) + nchar(piece) + 1L > width) {
      lines <- c(lines, cur)
      cur <- pad
      fresh <- TRUE
    }
    cur <- paste0(cur, if (fresh) "" else " ", piece)
  }
  paste(c(lines, cur), collapse = "\n")
}

# Names the generated code may use besides the exported functions of the
# package: assignment, vectors, subsetting and `stats::setNames`.
code_names <- c("<-", "(", "c", "::", "stats", "setNames", "[", "!=",
                "names", "-", "numeric")

# Run code text written for the exported script and return one object.
# `values` are the objects the code refers to (for instance `series`). As a
# second line of defence, code that names anything else than exported
# functions, `code_names`, `name` and `values` is refused before it runs.
eval_code <- function(text, name, values = list()) {
  exprs <- parse(text = text)
  used <- all.names(exprs)
  other <- setdiff(used, c(getNamespaceExports("rcli"), code_names, name,
                           names(values)))
  if (length(other) > 0L) {
    rcli_abort(sprintf("The generated code uses unexpected names: %s.",
                       paste(other, collapse = ", ")),
               "rcli_error_argument")
  }
  env <- list2env(values, parent = asNamespace("rcli"))
  for (e in exprs) eval(e, envir = env)
  get(name, envir = env, inherits = FALSE)
}

# Two numbers typed as "6, 9".
pair_text <- function(text, name) {
  if (is.null(text)) return(NULL)
  if (!is.atomic(text) || length(text) != 1L || !is.character(text)) {
    bad_input(name)
  }
  if (!nzchar(trimws(text))) return(NULL)
  v <- suppressWarnings(as.numeric(strsplit(trimws(text), "[,; ]+")[[1]]))
  if (length(v) != 2L || anyNA(v)) {
    rcli_abort(sprintf("`%s` needs two numbers, e.g. 6, 9.", name),
               "rcli_error_argument")
  }
  deparse_value(v)
}

# ---- specification (step 3) ----------------------------------------------

# A choice input used as a key, checked against `allowed`.
choice_key <- function(x, allowed, id) {
  if (!is.atomic(x) || length(x) != 1L || !is.character(x) ||
      !x %in% allowed) {
    bad_input(id)
  }
  x
}

filter_text <- function(input) {
  key <- choice_key(input$filter, c("hp_double", "hp", "cf", "bk",
                                    "hamilton"), "filter")
  switch(key,
    hp_double = call_text("hp_double_filter", list(
      trend_period = value_text(input$hp_trend_period),
      smooth_period = value_text(input$hp_smooth_period))),
    hp = call_text("hp_filter", list(lambda = value_text(input$hp_lambda))),
    cf = call_text("cf_filter", list(pl = value_text(input$band_pl),
                                     pu = value_text(input$band_pu))),
    bk = call_text("bk_filter", list(pl = value_text(input$band_pl),
                                     pu = value_text(input$band_pu),
                                     k = value_text(input$bk_k))),
    hamilton = call_text("hamilton_filter", list(
      h = value_text(input$ham_h), p = value_text(input$ham_p)))
  )
}

aggregator_text <- function(input) {
  cov <- value_text(input$agg_min_coverage)
  key <- choice_key(input$aggregator, c("equal", "equal_level", "oecd",
                                        "pca", "cb", "dfm"), "aggregator")
  switch(key,
    equal = call_text("equal_weight", list(min_coverage = cov)),
    equal_level = call_text("equal_weight", list(
      min_coverage = cov, ragged_edge = "\"level\"")),
    oecd = call_text("oecd_aggregate", list(min_coverage = cov)),
    pca = call_text("principal_component", list(min_coverage = cov)),
    cb = call_text("conference_board", list(min_coverage = cov)),
    dfm = call_text("dynamic_factor", list(min_coverage = cov))
  )
}

# The dating rule, only when one of its parameters is given.
dater_text <- function(input, freq) {
  args <- list(window = value_text(input$dater_window),
               min_phase = value_text(input$dater_min_phase),
               min_cycle = value_text(input$dater_min_cycle),
               end_exclusion = value_text(input$dater_end_exclusion))
  if (all(vapply(args, is.null, logical(1)))) return(NULL)
  call_text(if (freq == 12) "bry_boschan" else "bbq", args)
}

extension_text <- function(input) {
  if (isFALSE(input$extend)) return("no_extension()")
  call_text("ar_extension", list(h = value_text(input$ar_h),
                                 order_max = value_text(input$ar_order_max)))
}

holidays_text <- function(input) {
  if (isTRUE(input$seasonal) && isTRUE(input$idulfitri)) {
    "holiday_effect(idulfitri_dates(), name = \"idulfitri\")"
  }
}

# Code of step 3: `spec <- cli_spec(...)` or `spec <- oecd_spec(...)`.
spec_call <- function(input, freq) {
  cut <- deparse_value(parse_cutoffs(input$oos_cutoffs))
  if (identical(input$method, "oecd")) {
    return(assign_text("spec", "oecd_spec", list(
      freq = freq, seasonal_adjust = deparse_value(isTRUE(input$seasonal)),
      holidays = holidays_text(input), alpha = value_text(input$alpha),
      min_auc = value_text(input$min_auc),
      min_components = value_text(input$min_components),
      max_iter = value_text(input$max_iter), oos_cutoffs = cut)))
  }
  tramo <- identical(input$outlier_method, "tramo")
  assign_text("spec", "cli_spec", list(
    freq = freq, filter = filter_text(input),
    dater = dater_text(input, freq),
    aggregator = aggregator_text(input),
    transform = choice_text(input$transform, c("auto", "log", "none",
                                                "test"), "transform"),
    seasonal_adjust = deparse_value(isTRUE(input$seasonal)),
    holidays = holidays_text(input),
    outlier_threshold = if (!tramo) value_text(input$outlier),
    outliers = if (tramo) "tramo_outliers()",
    min_lead = value_text(input$min_lead),
    min_median_lead = value_text(input$min_median_lead),
    min_consistency = value_text(input$min_consistency),
    max_missed = value_text(input$max_missed),
    max_extra = value_text(input$max_extra),
    coincident_band = value_text(input$coincident_band),
    min_auc = value_text(input$min_auc),
    target_lead = pair_text(input$target_lead, "target_lead"),
    lead_window = pair_text(input$lead_window, "lead_window"),
    ccf_lag_max = value_text(input$ccf_lag_max),
    alpha = value_text(input$alpha),
    granger_max_lag = value_text(input$granger_max_lag),
    granger_dmax = value_text(input$granger_dmax),
    max_iter = value_text(input$max_iter),
    min_components = value_text(input$min_components),
    horizon = value_text(input$horizon),
    oos_cutoffs = cut,
    classifier = if (identical(input$classifier, "oecd")) {
      "oecd_classifier()"
    },
    lag_shift = if (isTRUE(input$lag_shift)) "TRUE",
    extension = extension_text(input)))
}

# Inputs of the advanced options of the rcli method (step 3). Empty
# numeric inputs mean the package default, which may depend on the
# frequency.
advanced_ui <- function(t) {
  num <- function(id, ...) {
    shiny::numericInput(id, t(id), NA, ...)
  }
  shiny::tags$details(
    style = "margin: 10px 0 15px 0;",
    shiny::tags$summary(shiny::strong(t("advanced"))),
    shiny::helpText(t("advanced_help")),
    shiny::fluidRow(
      shiny::column(4,
        shiny::selectInput("classifier", t("classifier"), stats::setNames(
          c("rcli", "oecd"), c(t("cls_rcli"), t("cls_oecd")))),
        shiny::selectInput("outlier_method", t("outlier_method"),
                           stats::setNames(c("robust", "tramo"),
                                           c(t("out_robust"),
                                             t("out_tramo")))),
        shiny::checkboxInput("lag_shift", t("lag_shift"), FALSE),
        shiny::h5(t("adv_filter")),
        shiny::conditionalPanel(
          "input.filter == 'hp_double'",
          num("hp_trend_period", min = 2), num("hp_smooth_period", min = 2)),
        shiny::conditionalPanel("input.filter == 'hp'",
                                num("hp_lambda", min = 0)),
        shiny::conditionalPanel(
          "input.filter == 'cf' || input.filter == 'bk'",
          num("band_pl", min = 2), num("band_pu", min = 2)),
        shiny::conditionalPanel("input.filter == 'bk'", num("bk_k", min = 1)),
        shiny::conditionalPanel("input.filter == 'hamilton'",
                                num("ham_h", min = 1), num("ham_p", min = 1))
      ),
      shiny::column(4,
        shiny::h5(t("adv_dater")),
        num("dater_window", min = 1), num("dater_min_phase", min = 1),
        num("dater_min_cycle", min = 2), num("dater_end_exclusion", min = 0),
        shiny::h5(t("adv_aggregation")),
        num("agg_min_coverage", min = 0, max = 1, step = 0.05),
        num("ar_h", min = 1), num("ar_order_max", min = 1)
      ),
      shiny::column(4,
        shiny::h5(t("adv_thresholds")),
        num("coincident_band", min = 0),
        shiny::textInput("lead_window", t("lead_window"), ""),
        shiny::textInput("target_lead", t("target_lead"), ""),
        num("ccf_lag_max", min = 1), num("granger_max_lag", min = 1),
        num("granger_dmax", min = 0), num("horizon", min = 0)
      )
    )
  )
}

# ---- alignment (step 2, several files) ------------------------------------

# Code of the alignment: `data <- cli_align(series, ...)`; `al` holds the
# choices of step 2.
align_text <- function(al) {
  if (!is.null(al$indicator) && !is.atomic(al$indicator)) {
    bad_input("align_indicator")
  }
  chow <- identical(al$method, "chow-lin") && given(al$indicator)
  # the indicator of Chow-Lin explains the reference, so it is not a
  # candidate (see ?cli_align)
  first <- if (chow) {
    sprintf("series[names(series) != %s]", chr_text(al$indicator))
  } else {
    "series"
  }
  indicator <- if (chow) {
    sprintf("cli_align(series[%s], freq = %s)[, %s]",
            chr_text(al$indicator), al$freq, chr_text(al$indicator))
  }
  cov <- value_text(al$min_coverage, "align_coverage")
  if (identical(cov, "0.7")) cov <- NULL
  args <- list(
    first, freq = al$freq,
    type = if (length(al$type) > 0L) chr_text(al$type),
    reference = chr_text(al$reference),
    method = if (!is.null(al$method) &&
                 !identical(al$method, "denton-cholette")) {
      choice_text(al$method, c("chow-lin", "linear"), "align_method")
    },
    indicator = indicator,
    week_date = if (identical(al$week_date, "end")) "\"end\"",
    min_coverage = cov)
  assign_text("data", "cli_align", args)
}

# Inputs of the alignment options, shown in step 2 for several files.
align_ui <- function(t, series, reference, freq, old) {
  # the disaggregation options only matter when the reference is converted
  keep <- function(id, default) {
    v <- old[[id]]
    if (is.null(v)) default else v
  }
  target <- c(`12` = "monthly", `4` = "quarterly")[[as.character(freq)]]
  same <- names(series)[vapply(series, function(s) {
    identical(attr(s, "frequency"), target)
  }, logical(1))]
  same <- setdiff(same, reference)
  convert <- !identical(attr(series[[reference]], "frequency"), target)
  has_td <- requireNamespace("tempdisagg", quietly = TRUE)
  methods <- stats::setNames(
    c("denton-cholette", "chow-lin", "linear"),
    c(t("align_dc"),
      paste(t("align_cl"), if (!has_td) t("tempdisagg_missing")),
      t("align_lin")))
  shiny::fluidRow(
    if (convert) shiny::column(3, shiny::selectInput(
      "align_method", t("align_method"), methods,
      selected = keep("align_method", "denton-cholette"))),
    if (convert) shiny::column(3, shiny::conditionalPanel(
      "input.align_method == 'chow-lin'",
      shiny::selectInput("align_indicator", t("align_indicator"),
                         c(stats::setNames("", t("none")), same),
                         selected = keep("align_indicator", "")),
      shiny::helpText(t("align_indicator_help")))),
    shiny::column(3, shiny::selectInput(
      "week_date", t("week_date"),
      stats::setNames(c("start", "end"), c(t("week_start"), t("week_end"))),
      selected = keep("week_date", "start"))),
    shiny::column(3, shiny::numericInput(
      "align_coverage", t("align_coverage"),
      keep("align_coverage", 0.7), min = 0, max = 1, step = 0.05))
  )
}
