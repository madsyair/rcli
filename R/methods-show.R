# show() and summary() methods.

describe_filter <- function(f) f@label

#' Print and summarise rcli objects
#'
#' @param object A rcli object.
#' @param ... Unused.
#' @return `show()` returns `object` invisibly; `summary()` returns a list of
#'   the main results invisibly after printing them.
#' @name show-methods
#' @examples
#' cli_spec()
#' sim <- simulate_cycles(seed = 1)
#' meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
#' res <- cli_build(cli_candidates(sim, "reference", meta = meta))
#' summary(res)
NULL

#' @rdname show-methods
#' @export
setMethod("show", "CycleFilter", function(object) {
  slots <- setdiff(slotNames(object), "label")
  vals <- vapply(slots, function(s) {
    v <- slot(object, s)
    if (is.na(v)) "default" else format(v)
  }, character(1))
  cat("<", class(object), "> ", object@label, "\n", sep = "")
  if (length(slots) > 0L) {
    cat(paste0("  ", slots, ": ", vals, collapse = "\n"), "\n", sep = "")
  }
  invisible(object)
})

#' @rdname show-methods
#' @export
setMethod("show", "Dater", function(object) {
  cat("<", class(object), "> ", object@label, "\n", sep = "")
  for (s in c("window", "min_phase", "min_cycle", "end_exclusion")) {
    v <- slot(object, s)
    cat("  ", s, ": ", if (is.na(v)) "default" else v, "\n", sep = "")
  }
  invisible(object)
})

#' @rdname show-methods
#' @export
setMethod("show", "Aggregator", function(object) {
  cat("<", class(object), "> ", object@label, "\n", sep = "")
  cat("  min_coverage: ", object@min_coverage, "\n", sep = "")
  invisible(object)
})

#' @rdname show-methods
#' @export
setMethod("show", "CliSpec", function(object) {
  unit <- if (object@freq == 12) "months" else "quarters"
  cat("<CliSpec> ", if (object@freq == 12) "monthly" else "quarterly",
      " composite leading indicator\n", sep = "")
  cat("  filter:      ", object@filter@label, "\n", sep = "")
  cat("  dating:      ", object@dater@label, "\n", sep = "")
  cat("  aggregation: ", object@aggregator@label, "\n", sep = "")
  if (isTRUE(object@seasonal_adjust)) {
    hol <- if (methods::.hasSlot(object, "holidays")) object@holidays else
      list()
    cat("  seasonal:    X-13ARIMA-SEATS",
        if (length(hol) > 0L) {
          paste0(" with holiday regressors (",
                 paste(vapply(hol, function(h) h@name, ""),
                       collapse = ", "), ")")
        }, "\n", sep = "")
  }
  cat("  leading if:  cross-correlation lead >= ", object@min_lead, " ", unit,
      ", median lead >= ", object@min_median_lead,
      ", leads >= ", object@min_consistency * 100, "% of turning points,\n",
      "               missed and extra <= ", object@max_missed * 100, "% and ",
      object@max_extra * 100, "%, concordance and Granger causality ",
      "significant at ", object@alpha, "\n", sep = "")
  cat("  loop:        at most ", object@max_iter, " iterations, at least ",
      object@min_components, " components\n", sep = "")
  invisible(object)
})

#' @rdname show-methods
#' @export
setMethod("show", "CandidateSet", function(object) {
  tm <- stats::time(object@data)
  f <- stats::frequency(object@data)
  cat("<CandidateSet> reference '", object@reference, "' and ",
      length(candidate_names(object)), " candidate(s), ",
      period_label(tm[1], f), " to ", period_label(tm[length(tm)], f), "\n",
      sep = "")
  m <- object@meta
  m$rationale[is.na(m$rationale)] <- "(none)"
  cols <- c("name", "rationale")
  if ("type" %in% names(m) && any(!is.na(m$type))) {
    m$type[is.na(m$type)] <- ""
    cols <- c(cols, "type")
  }
  print(m[, cols], row.names = FALSE)
  al <- alignment_of(object)
  al <- al[al$method != "none", , drop = FALSE]
  if (nrow(al) > 0L) {
    cat("  converted:\n")
    cat(sprintf("    %s: %s\n", al$name, al$method), sep = "")
  }
  if (length(object@vintages) > 0L) {
    cat("  vintages: ", length(object@vintages), "\n", sep = "")
  }
  invisible(object)
})

#' @rdname show-methods
#' @export
setMethod("show", "CycleSeries", function(object) {
  span <- non_na_span(object@cycle)
  f <- stats::frequency(object@cycle)
  tm <- stats::time(object@cycle)
  cat("<CycleSeries> '", object@name, "', ", period_label(tm[span[1]], f),
      " to ", period_label(tm[span[2]], f), "\n", sep = "")
  cat(paste0("  - ", object@steps, collapse = "\n"), "\n", sep = "")
  invisible(object)
})

#' @rdname show-methods
#' @export
setMethod("show", "TurningPoints", function(object) {
  cat("<TurningPoints> '", object@name, "': ", sum(object@type == "peak"),
      " peak(s), ", sum(object@type == "trough"), " trough(s)\n", sep = "")
  if (length(object@index) > 0L) {
    df <- as.data.frame(object)
    print(df[, c("period", "type")], row.names = FALSE)
  }
  invisible(object)
})

#' @rdname show-methods
#' @export
setMethod("show", "LeadAssessment", function(object) {
  tab <- object@table
  counts <- table(factor(tab$class, c("leading", "coincident", "lagging",
                                      "rejected")))
  cat("<LeadAssessment> ", paste(names(counts), counts, sep = ": ",
                                 collapse = ", "), "\n", sep = "")
  out <- data.frame(
    name = paste0(tab$name, ifelse(tab$inverted, "*", "")), class = tab$class,
    lead = tab$ccf_lag, median = tab$median_lead,
    led = round(tab$pct_led, 2),
    missed = paste0(tab$missed, "/", tab$n_ref),
    extra = tab$extra, conc = round(tab$concordance, 2),
    granger_p = signif(tab$granger_p, 2),
    stringsAsFactors = FALSE
  )
  print(out, row.names = FALSE)
  cat("lead: cross-correlation lead; median: median lead at turning points;\n",
      "led: share of reference turning points led; conc: concordance\n",
      if (any(tab$inverted)) "* inverted (counter-cyclical)\n", sep = "")
  invisible(object)
})

#' @rdname show-methods
#' @export
setMethod("show", "CompositeIndex", function(object) {
  span <- non_na_span(object@index)
  f <- stats::frequency(object@index)
  tm <- stats::time(object@index)
  cat("<CompositeIndex> ", object@aggregator@label, ", ",
      length(object@components), " component(s), ",
      period_label(tm[span[1]], f), " to ", period_label(tm[span[2]], f),
      "\n", sep = "")
  w <- round(object@weights, 3)
  cat(paste0("  ", names(w), ": ", w, collapse = "\n"), "\n", sep = "")
  invisible(object)
})

#' @rdname show-methods
#' @export
setMethod("show", "CliValidation", function(object) {
  tp <- object@turning_points
  pr <- object@probability
  cat("<CliValidation> ", if (object@passed) "PASSED" else "FAILED", "\n",
      sep = "")
  if (!object@passed) {
    cat("  failed criteria: ", paste(object@failed, collapse = ", "), "\n",
        sep = "")
  }
  cat("  lead: cross-correlation ", fmt_num(tp$ccf_lag, 0), ", median at ",
      "turning points ", fmt_num(tp$median_lead, 1), " (",
      fmt_num(100 * tp$pct_led, 0), "% of turning points led)\n", sep = "")
  cat("  turning points: ", tp$missed, " missed, ", tp$extra, " extra of ",
      tp$n_ref, "; concordance ", fmt_num(tp$concordance), "\n", sep = "")
  cat("  horizon ", pr$horizon, ": QPS ", fmt_num(pr$qps, 3), ", AUC ",
      fmt_num(pr$auc, 3), ", Pesaran-Timmermann p ", fmt_num(pr$pt_p, 3),
      "\n", sep = "")
  if (is(object@quality, "CliQuality")) {
    cat("  quality verdict: ", object@quality@verdict, " (see cli_quality())\n",
        sep = "")
  }
  oos <- object@out_of_sample
  if (nrow(oos) > 0L) {
    cat("  selection bias (lead in sample vs after cut-off):\n")
    print(oos[, c("cutoff", "n_components", "median_lead_in",
                  "median_lead_out", "n_tp_out", "lead_gap")],
          row.names = FALSE)
  }
  invisible(object)
})

#' @rdname show-methods
#' @export
setMethod("show", "CliResult", function(object) {
  cat("<CliResult>\n")
  a <- object@assessment@table
  cat("  candidates: ", nrow(a), " (", sum(a$class == "leading"),
      " leading)\n", sep = "")
  if (is.null(object@composite)) {
    cat("  no composite: no candidate qualified as leading\n")
  } else {
    cat("  composite: ", paste(object@composite@components, collapse = ", "),
        "\n", sep = "")
    v <- object@validation
    cat("  validation: ", if (v@passed) "passed" else "failed", ", lead ",
        fmt_num(v@turning_points$ccf_lag, 0), " (cross-correlation), ",
        fmt_num(v@turning_points$median_lead, 1), " (median at turning ",
        "points)\n", sep = "")
    cat("  quality verdict: ", cli_quality(object)@verdict, "\n", sep = "")
  }
  cat("  selection loop: ", nrow(object@audit), " step(s); see audit_log()\n",
      sep = "")
  invisible(object)
})

#' @rdname show-methods
#' @export
setMethod("summary", "CliResult", function(object, ...) {
  cat("== Composite leading indicator ==\n\n")
  show(object@spec)
  cat("\n")
  show(object@assessment)
  cat("\n")
  if (!is.null(object@composite)) {
    show(object@composite)
    cat("\n")
    show(object@validation)
    cat("\n")
    show(cli_quality(object))
    oos <- object@validation@out_of_sample
    if (nrow(oos) > 0L && isTRUE(stats::median(oos$lead_gap, na.rm = TRUE) >
                                 object@spec@min_lead)) {
      cat("\nWarning: the in-sample lead exceeds the lead after the cut-off",
          "dates by more than", object@spec@min_lead, "periods (median);",
          "it is likely a selection effect.\n")
    }
  }
  invisible(list(assessment = object@assessment@table,
                 validation = object@validation, audit = object@audit))
})

#' @rdname show-methods
#' @export
setMethod("summary", "LeadAssessment", function(object, ...) {
  show(object)
  invisible(object@table)
})
