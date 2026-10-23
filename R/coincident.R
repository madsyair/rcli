# Coincident index: the composite of the candidates classified as coincident.

#' Coincident criteria
#'
#' The criteria a coincident index must meet in [cci_validate()]. They mirror
#' the leading criteria of each [Classifier-class], with timing in place of
#' lead:
#'
#' * `RcliClassifier`: at least three matched turning points; a positive
#'   cross-correlation peak within `coincident_band` periods of lag 0 (the
#'   band that labels candidates coincident); a median lead at turning points
#'   within the timing band (+/- 2 months, the OECD coincident band, or one
#'   period when that is wider, as for quarterly data); few
#'   missed and extra turning points; significant concordance. Granger
#'   causality is not required: a coincident series need not predict the
#'   reference.
#' * `OecdClassifier`: at least `min_matched` matched turning points and a
#'   median lead strictly inside +/- `coincident` months, the OECD
#'   definition of a coincident series.
#' * any other `Classifier`: at least three matched turning points and a
#'   median lead within the timing band.
#'
#' New rules can add a method for `coincident_criteria()`; the scorecard of
#' [cli_quality()] reports every criterion it returns.
#'
#' In the package simulations (`inst/calibration/coincident.csv`, made by
#' `data-raw/calibrate_coincident.R`, 100 replications) the default rule
#' passes 96 percent of monthly and 99 percent of quarterly composites of
#' truly coincident series at the default noise level, and at most 1 percent
#' of composites that lead or lag by 3 months (1 quarter). With twice the
#' noise the rule is less reliable, above all for quarterly data (65 percent
#' of coincident composites pass, 17 percent of leading ones). A lead of
#' exactly 2 months, which the OECD calls leading, passes in 12 to 25
#' percent of monthly replications. Without the one-period floor, only 82.5
#' percent of truly coincident quarterly composites passed, because dating
#' noise moves the median lead by one quarter.
#'
#' @param classifier A [Classifier-class].
#' @param row One-row data frame of turning-point statistics.
#' @param spec A [CliSpec-class].
#' @return Named logical vector, one element per criterion.
#' @references
#' Gyomai, G. and Guidetti, E. (2012). *OECD System of Composite Leading
#' Indicators*. OECD Publishing, Paris.
#' @seealso [cci_validate()], [cci_build()]
#' @examples
#' sim <- simulate_cycles(seed = 1)
#' meta <- data.frame(name = colnames(sim)[-1], rationale = "rapid_response")
#' spec <- cli_spec(freq = 12)
#' a <- cli_assess(cli_candidates(sim, "reference", meta = meta), spec)
#' row <- a@table[a@table$name == "coincident", ]
#' coincident_criteria(spec@classifier, row, spec)
#' @export
setGeneric("coincident_criteria", function(classifier, row, spec) {
  standardGeneric("coincident_criteria")
})

# Half-width, in periods, of the timing band of a coincident index.
timing_band <- function(classifier, spec) {
  if (is(classifier, "OecdClassifier")) {
    oecd_band(classifier, spec)[["coincident"]]
  } else {
    max(2 * spec@freq / 12, 1)
  }
}

#' @rdname coincident_criteria
setMethod("coincident_criteria", "Classifier", function(classifier, row,
                                                        spec) {
  band <- timing_band(classifier, spec)
  c(matched = isTRUE(row$n_matched >= 3L),
    timing = isTRUE(abs(row$median_lead) <= band))
})

#' @rdname coincident_criteria
setMethod("coincident_criteria", "RcliClassifier", function(classifier, row,
                                                            spec) {
  band <- timing_band(classifier, spec)
  share <- function(k) if (row$n_ref > 0L) k / row$n_ref else Inf
  c(
    matched = row$n_matched >= 3L,
    ccf = isTRUE(abs(row$ccf_lag) <= spec@coincident_band) &&
      isTRUE(row$ccf_r > 0),
    timing = isTRUE(abs(row$median_lead) <= band),
    missed = share(row$missed) <= spec@max_missed,
    extra = share(row$extra) <= spec@max_extra,
    concordance = isTRUE(row$concordance_p < spec@alpha) &&
      isTRUE(row$concordance > row$concordance_expected)
  )
})

#' @rdname coincident_criteria
setMethod("coincident_criteria", "OecdClassifier", function(classifier, row,
                                                            spec) {
  band <- timing_band(classifier, spec)
  c(matched = isTRUE(row$n_matched >= classifier@min_matched),
    timing = isTRUE(abs(row$median_lead) < band))
})

# Scorecard rows of the coincident criteria.
coincident_quality <- function(classifier, row, spec) {
  chk <- coincident_criteria(classifier, row, spec)
  band <- round(timing_band(classifier, spec), 3)
  share <- function(k) if (row$n_ref > 0L) k / row$n_ref else NA_real_
  oecd <- is(classifier, "OecdClassifier")
  min_matched <- if (oecd) classifier@min_matched else 3
  known <- list(
    matched = list("matched turning points", row$n_matched,
                   sprintf(">= %s", min_matched)),
    ccf = list("cross-correlation lag", row$ccf_lag,
               sprintf("within +/- %s, positive", spec@coincident_band)),
    timing = list("median lead at turning points", row$median_lead,
                  if (oecd) {
                    sprintf("within (-%s, %s)", band, band)
                  } else {
                    sprintf("within +/- %s", band)
                  }),
    missed = list("share of missed turning points", share(row$missed),
                  sprintf("<= %s", spec@max_missed)),
    extra = list("share of extra turning points", share(row$extra),
                 sprintf("<= %s", spec@max_extra)),
    concordance = list("concordance", row$concordance,
                       sprintf("> %s, p < %s",
                               round(row$concordance_expected, 3),
                               spec@alpha))
  )
  rows <- lapply(names(chk), function(nm) {
    k <- known[[nm]]
    if (is.null(k)) k <- list(nm, NA_real_, "")
    q_row("turning points", k[[1]], k[[2]], k[[3]], unname(chk[[nm]]))
  })
  do.call(rbind, rows)
}

# Out-of-sample rows of the coincident scorecard.
coincident_out_of_sample <- function(oos, spec) {
  g <- "out of sample"
  band <- timing_band(spec_classifier(spec), spec)
  timing_out <- stats::median(oos$median_lead_out)
  timely <- stats::median(oos$pct_timely_out)
  gap <- stats::median(abs(oos$lead_gap))
  rbind(
    q_row(g, "median lead after cut-offs", timing_out,
          sprintf("within +/- %s", round(band, 3)),
          isTRUE(abs(timing_out) <= band)),
    q_row(g, "share of later turning points within the band", timely,
          sprintf(">= %s", spec@min_consistency),
          isTRUE(timely >= spec@min_consistency)),
    q_row(g, "absolute in-sample minus later lead", gap,
          sprintf("<= %s", spec@min_lead), isTRUE(gap <= spec@min_lead))
  )
}

coincident_score <- function(val, spec) {
  row <- val@turning_points
  chk <- coincident_criteria(spec_classifier(spec), row, spec)
  share <- if (row$n_ref > 0L) (row$missed + row$extra) / row$n_ref else 1
  lag <- if (is.na(row$ccf_lag)) spec@ccf_lag_max else abs(row$ccf_lag)
  med <- if (is.na(row$median_lead)) spec@ccf_lag_max else
    abs(row$median_lead)
  conc <- if (is.na(row$concordance)) 0 else row$concordance
  10 * sum(chk) - lag - med + 5 * conc - 5 * share
}

#' Validate a coincident index
#'
#' Tests a coincident index against the reference cycle, as
#' [cli_validate()] does for a composite leading indicator, but with timing
#' in place of lead:
#'
#' * **turning points**: the index is dated and assessed like a candidate;
#'   `passed` is `TRUE` when it meets every [coincident_criteria()] of the
#'   specification's classifier;
#' * **current state**: the logit of the reference contraction state at time
#'   \eqn{t} on the change of the index over the quarter ending at \eqn{t}
#'   (horizon 0) gives the quadratic probability score and the area under
#'   the ROC curve;
#' * **direction**: the Pesaran and Timmermann (1992) test that the sign of
#'   the index's change matches the sign of the reference change in the same
#'   period.
#'
#' @param composite A [CompositeIndex-class].
#' @param reference The reference [CycleSeries-class].
#' @param spec A [CliSpec-class].
#' @return A [CliValidation-class] with role `"coincident"`.
#' @references
#' Pesaran, M. H. and Timmermann, A. (1992). A simple nonparametric test of
#' predictive performance. *Journal of Business and Economic Statistics*,
#' 10(4), 461--465.
#' @seealso [cci_build()], [cli_quality()]
#' @examples
#' sim <- simulate_cycles(leads = c(coin_a = 0, coin_b = 0, lead_6 = 6),
#'                        seed = 1)
#' meta <- data.frame(name = colnames(sim)[-1], rationale = "rapid_response")
#' spec <- cli_spec(freq = 12)
#' cyc <- cli_cycles(cli_candidates(sim, "reference", meta = meta), spec)
#' cci <- cli_composite(cyc, c("coin_a", "coin_b"), spec, cyc$reference)
#' cci_validate(cci, cyc$reference, spec)
#' @export
cci_validate <- function(composite, reference, spec) {
  if (!is(composite, "CompositeIndex") || !is(reference, "CycleSeries")) {
    rcli_abort("Supply a CompositeIndex and the reference CycleSeries.",
               "rcli_error_argument")
  }
  if (!is(spec, "CliSpec")) {
    rcli_abort("`spec` must be a CliSpec.", "rcli_error_argument")
  }
  comp_cs <- composite_as_cycle(composite)
  comp_cs@name <- "CCI"
  ref_tp <- date_turning_points(spec@dater, reference@normalised,
                                name = reference@name)
  comp_tp <- date_turning_points(spec@dater, comp_cs@normalised, name = "CCI")
  row <- assess_pair(reference, ref_tp, comp_cs, comp_tp, spec)$row
  chk <- coincident_criteria(spec_classifier(spec), row, spec)
  prob <- probability_scores(as.numeric(composite@cycle), ref_tp, 0,
                             span = max(1, spec@freq / 4))
  pt <- pesaran_timmermann(as.numeric(composite@cycle),
                           as.numeric(reference@normalised), 0)
  prob$pt_stat <- pt$stat
  prob$pt_p <- pt$p_value
  row$name <- NULL
  val <- new("CliValidation", turning_points = row, probability = prob,
             out_of_sample = data.frame(), passed = all(chk),
             failed = names(chk)[!chk], quality = NULL, role = "coincident")
  val@quality <- cli_quality(val, spec)
  val
}

#' Build a coincident index
#'
#' A coincident index summarises the current state of the cycle, as the
#' Conference Board coincident economic index does next to its leading
#' index. `cci_build()` aggregates the candidates that [cli_assess()]
#' classified as coincident with the specification's [Aggregator-class]
#' (the same machinery as [cli_build()], without lag-shifting), validates
#' the index with [cci_validate()] and, when it fails, removes components by
#' backward elimination until it passes or a stopping rule of the
#' specification applies. Every step is written to the audit log.
#'
#' Give a [CliResult-class] to reuse its cycles and classification, so that
#' the leading and the coincident index come from one run. When
#' `spec@oos_cutoffs` is not empty, [cli_selection_bias()] is run with
#' `role = "coincident"`.
#'
#' A coincident index can replace a quarterly reference series: see
#' [cci_as_reference()].
#'
#' @param x A [CandidateSet-class] or a [CliResult-class].
#' @param spec A [CliSpec-class]. By default the specification of `x` (a
#'   `CliResult`) or [cli_spec()] at the frequency of the data. Giving a
#'   specification with a `CliResult` reruns the cycles and the
#'   classification.
#' @param components Optional names of the components to start from; by
#'   default the candidates classified as coincident.
#' @param select Logical; remove components by backward elimination when the
#'   index fails? With `FALSE` the index keeps every component.
#' @return A [CciResult-class].
#' @seealso [cci_validate()], [coincident_criteria()], [cci_as_reference()]
#' @examples
#' sim <- simulate_cycles(leads = c(lead_6 = 6, lead_3 = 3, coin_a = 0,
#'                                  coin_b = 0, lag_3 = -3), seed = 1)
#' meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
#' res <- cli_build(cli_candidates(sim, "reference", meta = meta))
#' cci <- cci_build(res)
#' cci
#' coincidents(cci)
#' cli_quality(cci)
#' @export
cci_build <- function(x, spec = NULL, components = NULL, select = TRUE) {
  if (is(x, "CliResult") && is.null(spec)) {
    candidates <- x@candidates
    spec <- x@spec
    cycles <- x@cycles
    assessment <- x@assessment
    tps <- x@turning_points
  } else {
    candidates <- if (is(x, "CliResult")) x@candidates else x
    if (is.null(spec) && is(candidates, "CandidateSet")) {
      spec <- cli_spec(freq = stats::frequency(candidates@data))
    }
    check_inputs(candidates, spec)
    cycles <- cli_cycles(candidates, spec)
    assessment <- cli_assess(candidates, spec, cycles)
    for (nm in assessment@inverted) cycles[[nm]] <- invert_cycle(cycles[[nm]])
    tps <- cli_turning_points(cycles, spec)
  }
  if (!is.logical(select) || length(select) != 1L || is.na(select)) {
    rcli_abort("`select` must be TRUE or FALSE.", "rcli_error_argument")
  }
  comps <- if (is.null(components)) coincidents(assessment) else components
  if (!is.character(comps) || !all(comps %in% assessment@table$name)) {
    rcli_abort("`components` must name candidates of the assessment.",
               "rcli_error_argument")
  }
  ref <- cycles[[candidates@reference]]
  if (length(comps) == 0L) {
    rcli_warn("No candidate was classified as coincident; no index built.",
              "rcli_warning_no_coincident")
    sel <- list(composite = NULL, validation = NULL,
                audit = empty_audit("no coincident candidates"))
  } else {
    evaluate <- function(cs) {
      comp <- cli_composite(cycles, cs, spec, ref)
      val <- cci_validate(comp, ref, spec)
      list(composite = comp, validation = val,
           score = coincident_score(val, spec))
    }
    first <- if (is.null(components)) {
      "initial index of all coincident candidates"
    } else {
      "initial index of the given components"
    }
    sel <- if (select) {
      elimination_loop(comps, evaluate, spec, first)
    } else {
      keep_all(comps, evaluate, spec, first)
    }
  }
  validation <- sel$validation
  if (!is.null(validation) && length(spec@oos_cutoffs) > 0L) {
    validation@out_of_sample <- cli_selection_bias(
      candidates, spec, spec@oos_cutoffs, role = "coincident")
    validation@quality <- cli_quality(validation, spec)
  }
  new("CciResult", spec = spec, candidates = candidates, cycles = cycles,
      turning_points = tps, assessment = assessment,
      composite = sel$composite, validation = validation, audit = sel$audit)
}

# One evaluation without selection (cci_build(select = FALSE)).
keep_all <- function(comps, evaluate, spec, first_action) {
  cur <- evaluate(comps)
  last <- if (cur$validation@passed) {
    "accepted: all criteria met"
  } else {
    "kept: selection switched off"
  }
  audit <- rbind(
    audit_row(1L, first_action, comps, cur$validation, cur$score, spec),
    audit_row(1L, last, comps, cur$validation, cur$score, spec)
  )
  rownames(audit) <- NULL
  list(composite = cur$composite, validation = cur$validation, audit = audit)
}

#' Candidates classified as coincident
#'
#' @param x A [LeadAssessment-class], [CliResult-class] or
#'   [CciResult-class].
#' @param ... Unused.
#' @return Character vector of candidate names.
#' @seealso [leaders()], [cci_build()]
#' @examples
#' sim <- simulate_cycles(seed = 1)
#' meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
#' coincidents(cli_assess(cli_candidates(sim, "reference", meta = meta),
#'                        cli_spec(freq = 12)))
#' @export
setGeneric("coincidents", function(x, ...) standardGeneric("coincidents"))

#' @rdname coincidents
setMethod("coincidents", "LeadAssessment", function(x, ...) {
  x@table$name[x@table$class == "coincident"]
})

#' @rdname coincidents
setMethod("coincidents", "CliResult", function(x, ...) {
  coincidents(x@assessment)
})

#' Use a coincident index as the reference series
#'
#' The reference cycle of a composite leading indicator is often a
#' quarterly series (GDP) that has to be disaggregated to months (see
#' [cli_align()]), which blurs its turning-point dates. A monthly coincident
#' index is the reference the Conference Board uses. `cci_as_reference()`
#' returns a [CandidateSet-class] whose reference is the index of a
#' [CciResult-class]; the former reference and, by default, the components
#' of the index leave the candidates, so that no candidate is assessed
#' against an index it is part of.
#'
#' The new reference goes through the same cycle extraction as any series.
#' For an amplitude-adjusted index (every aggregator except
#' [conference_board()]) that series is already a cycle, which the
#' band-pass filters of the package leave almost unchanged; the level index
#' of [conference_board()] is the closer analogue of a level reference such
#' as GDP. Data vintages are dropped because the index has none.
#'
#' @param cci A [CciResult-class] with an index.
#' @param candidates The [CandidateSet-class] to take the candidates from;
#'   by default that of `cci`.
#' @param name Name of the new reference column.
#' @param drop_components Logical; remove the components of the index from
#'   the candidates?
#' @return A [CandidateSet-class].
#' @seealso [cci_build()], [cli_candidates()]
#' @examples
#' sim <- simulate_cycles(leads = c(lead_6 = 6, coin_a = 0, coin_b = 0),
#'                        seed = 1)
#' meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
#' cci <- cci_build(cli_candidates(sim, "reference", meta = meta))
#' cand <- cci_as_reference(cci)
#' cand
#' @export
cci_as_reference <- function(cci, candidates = NULL, name = "cci",
                             drop_components = TRUE) {
  if (!is(cci, "CciResult") || is.null(cci@composite)) {
    rcli_abort("`cci` must be a CciResult with an index (see cci_build()).",
               "rcli_error_argument")
  }
  if (is.null(candidates)) candidates <- cci@candidates
  if (!is(candidates, "CandidateSet")) {
    rcli_abort("`candidates` must be a CandidateSet.", "rcli_error_argument")
  }
  if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
    rcli_abort("`name` must be one non-empty string.", "rcli_error_argument")
  }
  if (!is.logical(drop_components) || length(drop_components) != 1L ||
      is.na(drop_components)) {
    rcli_abort("`drop_components` must be TRUE or FALSE.",
               "rcli_error_argument")
  }
  idx <- cci@composite@index
  if (stats::frequency(idx) != stats::frequency(candidates@data)) {
    rcli_abort("The index and the candidates have different frequencies.",
               "rcli_error_frequency")
  }
  keep <- setdiff(colnames(candidates@data), candidates@reference)
  if (drop_components) keep <- setdiff(keep, cci@composite@components)
  if (name %in% keep) {
    rcli_abort(sprintf(paste("A candidate is already called '%s';",
                             "choose another `name`."), name),
               "rcli_error_argument")
  }
  if (length(keep) == 0L) {
    rcli_abort("No candidate is left besides the index.",
               "rcli_error_argument")
  }
  dat <- cbind(idx, candidates@data[, keep, drop = FALSE])
  colnames(dat) <- c(name, keep)
  meta <- candidates@meta
  meta <- meta[meta$name %in% keep, , drop = FALSE]
  rownames(meta) <- NULL
  out <- cli_candidates(dat, reference = name, meta = meta)
  al <- alignment_of(candidates)
  if (nrow(al) > 0L) {
    out@alignment <- al[al$name %in% keep, , drop = FALSE]
  }
  out
}

#' @rdname show-methods
#' @export
setMethod("show", "CciResult", function(object) {
  cat("<CciResult>\n")
  a <- object@assessment@table
  cat("  candidates: ", nrow(a), " (", sum(a$class == "coincident"),
      " coincident)\n", sep = "")
  if (is.null(object@composite)) {
    cat("  no index: no candidate qualified as coincident\n")
  } else {
    cat("  coincident index: ",
        paste(object@composite@components, collapse = ", "), "\n", sep = "")
    v <- object@validation
    cat("  validation: ", if (v@passed) "passed" else "failed", ", lag ",
        fmt_num(v@turning_points$ccf_lag, 0), " (cross-correlation), lead ",
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
setMethod("summary", "CciResult", function(object, ...) {
  cat("== Coincident index ==\n\n")
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
  }
  invisible(list(assessment = object@assessment@table,
                 validation = object@validation, audit = object@audit))
})
