#' Is the composite leading indicator good enough?
#'
#' Turns the validation results into a scorecard with an explicit verdict.
#' The criteria come in three groups:
#'
#' **Turning points** (OECD evaluation; Gyomai and Guidetti 2012): the
#' composite must meet every leading criterion of the specification, the same
#' ones used to classify candidates (see [cli_assess()]).
#'
#' **Prediction**:
#' * the area under the ROC curve of the contraction probability is at least
#'   `min_auc` (0.7 is "acceptable discrimination", Hosmer and Lemeshow 2000;
#'   Berge and Jordà 2011 use the ROC curve to score business-cycle
#'   classifiers);
#' * the quadratic probability score beats the naive forecast, a constant
#'   probability equal to the share of contraction periods (Diebold and
#'   Rudebusch 1989);
#' * the Pesaran and Timmermann (1992) test rejects that the composite's
#'   direction is unrelated to the later direction of the reference.
#'
#' **Out of sample** (only when [cli_selection_bias()] has been run, for
#' example through `oos_cutoffs` in [cli_spec()]): over the cut-offs that
#' leave at least three reference turning points, the median of the later
#' median leads is at least `min_median_lead`, the composite leads at least
#' `min_consistency` of those turning points, and the median of the
#' in-sample minus later leads is at most `min_lead` periods (no selection
#' effect). Medians are used because single cut-offs with few later turning
#' points are noisy: in the package simulations genuine leaders show gaps of
#' up to 3.5 months at individual cut-offs.
#'
#' The lead of the cross-correlation peak is also compared with the lead the
#' OECD aims at (`target_lead`, 6 to 9 months); this row is information only.
#' When the reference series of a [CliResult-class] was disaggregated from
#' quarterly data by [cli_align()], a second information row and the note
#' say that its turning-point dates, and so the lead, are uncertain by about
#' one month.
#'
#' **Verdict**: `"good"` when all three groups pass; `"acceptable"` when the
#' turning-point and prediction groups pass but no out-of-sample check was
#' run; `"weak"` otherwise.
#'
#' @param x A [CliValidation-class] or a [CliResult-class].
#' @param spec A [CliSpec-class]; taken from `x` when it is a `CliResult`.
#' @return A [CliQuality-class] object.
#' @references
#' Berge, T. J. and Jordà, Ò. (2011). Evaluating the classification of
#' economic activity into recessions and expansions. *American Economic
#' Journal: Macroeconomics*, 3(2), 246--277.
#'
#' Diebold, F. X. and Rudebusch, G. D. (1989). Scoring the leading
#' indicators. *Journal of Business*, 62(3), 369--391.
#'
#' Hosmer, D. W. and Lemeshow, S. (2000). *Applied Logistic Regression*, 2nd
#' edition. Wiley, New York.
#'
#' Pesaran, M. H. and Timmermann, A. (1992). A simple nonparametric test of
#' predictive performance. *Journal of Business and Economic Statistics*,
#' 10(4), 461--465.
#' @examples
#' sim <- simulate_cycles(seed = 1)
#' meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
#' res <- cli_build(cli_candidates(sim, "reference", meta = meta))
#' cli_quality(res)
#' @export
cli_quality <- function(x, spec = NULL) {
  ref_conv <- NULL
  if (is(x, "CliResult")) {
    ref_conv <- reference_conversion(x@candidates)
    spec <- x@spec
    x <- x@validation
    if (is.null(x)) {
      return(new("CliQuality", table = data.frame(), verdict = "weak",
                 note = "No composite was built."))
    }
  }
  if (!is(x, "CliValidation") || !is(spec, "CliSpec")) {
    rcli_abort("Supply a CliValidation with its CliSpec, or a CliResult.",
               "rcli_error_argument")
  }
  tab <- rbind(quality_turning_points(x@turning_points, spec),
               quality_prediction(x@probability, spec),
               quality_out_of_sample(x@out_of_sample, spec),
               quality_information(x@turning_points, spec),
               quality_reference(ref_conv))
  rownames(tab) <- NULL
  ok <- function(g) {
    r <- tab$passed[tab$group == g]
    length(r) > 0L && all(r %in% TRUE)
  }
  has_oos <- any(tab$group == "out of sample")
  tp_ok <- ok("turning points")
  pr_ok <- ok("prediction")
  if (tp_ok && pr_ok && has_oos && ok("out of sample")) {
    verdict <- "good"
    note <- "All turning-point, prediction and out-of-sample criteria are met."
  } else if (tp_ok && pr_ok && !has_oos) {
    verdict <- "acceptable"
    note <- paste("In-sample criteria are met; run the out-of-sample check",
                  "(oos_cutoffs) before relying on the lead.")
  } else {
    verdict <- "weak"
    failed <- unique(tab$group[tab$passed %in% FALSE])
    note <- sprintf("Criteria not met in: %s.", paste(failed, collapse = ", "))
  }
  if (!is.null(ref_conv) && grepl("^quarterly to monthly", ref_conv$method)) {
    note <- paste(note, "The reference was disaggregated from quarterly",
                  "data: its turning-point dates and the lead are uncertain",
                  "by about one month.")
  }
  new("CliQuality", table = tab, verdict = verdict, note = note)
}

q_row <- function(group, criterion, value, threshold, passed) {
  data.frame(group = group, criterion = criterion, value = value,
             threshold = threshold, passed = passed, stringsAsFactors = FALSE)
}

quality_turning_points <- function(row, spec) {
  quality_criteria(spec_classifier(spec), row, spec)
}

#' @rdname Classifier-class
#' @export
setGeneric("quality_criteria", function(classifier, row, spec) {
  standardGeneric("quality_criteria")
})

#' @rdname Classifier-class
setMethod("quality_criteria", "Classifier", function(classifier, row, spec) {
  chk <- leading_criteria(classifier, row, spec)
  q_row("turning points", names(chk), NA_real_, "", unname(chk))
})

#' @rdname Classifier-class
setMethod("quality_criteria", "RcliClassifier", function(classifier, row,
                                                         spec) {
  chk <- leading_criteria(classifier, row, spec)
  share <- function(k) if (row$n_ref > 0L) k / row$n_ref else NA_real_
  g <- "turning points"
  rbind(
    q_row(g, "matched turning points", row$n_matched, ">= 3",
          chk[["matched"]]),
    q_row(g, "cross-correlation lead", row$ccf_lag,
          sprintf(">= %s, positive", spec@min_lead), chk[["ccf"]]),
    q_row(g, "median lead at turning points", row$median_lead,
          sprintf(">= %s", spec@min_median_lead), chk[["lead"]]),
    q_row(g, "share of turning points led", row$pct_led,
          sprintf(">= %s", spec@min_consistency), chk[["consistency"]]),
    q_row(g, "share of missed turning points", share(row$missed),
          sprintf("<= %s", spec@max_missed), chk[["missed"]]),
    q_row(g, "share of extra turning points", share(row$extra),
          sprintf("<= %s", spec@max_extra), chk[["extra"]]),
    q_row(g, "concordance", row$concordance,
          sprintf("> %s, p < %s", round(row$concordance_expected, 3),
                  spec@alpha), chk[["concordance"]]),
    q_row(g, "Granger causality p-value", row$granger_p,
          sprintf("< %s", spec@alpha), chk[["granger"]])
  )
})

#' @rdname Classifier-class
setMethod("quality_criteria", "OecdClassifier", function(classifier, row,
                                                         spec) {
  chk <- leading_criteria(classifier, row, spec)
  band <- oecd_band(classifier, spec)
  share <- function(k) if (row$n_ref > 0L) k / row$n_ref else NA_real_
  g <- "turning points"
  i <- "information"
  rbind(
    q_row(g, "matched turning points", row$n_matched,
          sprintf(">= %s", classifier@min_matched), chk[["matched"]]),
    q_row(g, "median lead at turning points", row$median_lead,
          sprintf(">= %s", round(band[["coincident"]], 3)), chk[["lead"]]),
    q_row(i, "mean lead at turning points", row$mean_lead, "", NA),
    q_row(i, "standard deviation of the lead", row$sd_lead, "", NA),
    q_row(i, "cross-correlation lead", row$ccf_lag, "close to median lead",
          NA),
    q_row(i, "peak cross-correlation", row$ccf_r, "", NA),
    q_row(i, "share of missed turning points", share(row$missed), "", NA),
    q_row(i, "share of extra turning points", share(row$extra), "", NA)
  )
})

quality_prediction <- function(prob, spec) {
  g <- "prediction"
  rbind(
    q_row(g, "area under the ROC curve", prob$auc,
          sprintf(">= %s", spec@min_auc), isTRUE(prob$auc >= spec@min_auc)),
    q_row(g, "quadratic probability score", prob$qps,
          sprintf("< %s (naive)", round(prob$qps_naive, 3)),
          isTRUE(prob$qps < prob$qps_naive)),
    q_row(g, "Pesaran-Timmermann p-value", prob$pt_p,
          sprintf("< %s", spec@alpha), isTRUE(prob$pt_p < spec@alpha))
  )
}

quality_out_of_sample <- function(oos, spec) {
  if (nrow(oos) == 0L) return(NULL)
  oos <- oos[!is.na(oos$median_lead_out) & oos$n_tp_out >= 3L, , drop = FALSE]
  if (nrow(oos) == 0L) return(NULL)
  g <- "out of sample"
  lead_out <- stats::median(oos$median_lead_out)
  led_out <- stats::median(oos$pct_led_out)
  gap <- stats::median(oos$lead_gap)
  rbind(
    q_row(g, "median lead after cut-offs", lead_out,
          sprintf(">= %s", spec@min_median_lead),
          isTRUE(lead_out >= spec@min_median_lead)),
    q_row(g, "share of later turning points led", led_out,
          sprintf(">= %s", spec@min_consistency),
          isTRUE(led_out >= spec@min_consistency)),
    q_row(g, "in-sample minus later lead", gap,
          sprintf("<= %s", spec@min_lead), isTRUE(gap <= spec@min_lead))
  )
}

# Information row when the reference was disaggregated to monthly.
quality_reference <- function(conv) {
  if (is.null(conv) || !grepl("^quarterly to monthly", conv$method)) {
    return(NULL)
  }
  q_row("information", "reference disaggregated from quarterly data",
        1, "turning points +/- 1 month", NA)
}

quality_information <- function(row, spec) {
  q_row("information", "lead within the OECD target range", row$ccf_lag,
        sprintf("%s to %s", spec@target_lead[1], spec@target_lead[2]),
        NA)
}

#' @rdname show-methods
#' @export
setMethod("show", "CliQuality", function(object) {
  label <- c(good = "GOOD", acceptable = "ACCEPTABLE", weak = "WEAK")
  cat("<CliQuality> verdict: ", label[[object@verdict]], "\n", sep = "")
  cat("  ", object@note, "\n", sep = "")
  tab <- object@table
  if (nrow(tab) > 0L) {
    status <- ifelse(is.na(tab$passed), "info",
                     ifelse(tab$passed, "pass", "FAIL"))
    for (g in unique(tab$group)) {
      i <- tab$group == g
      cat("\n  ", g, "\n", sep = "")
      out <- data.frame(criterion = tab$criterion[i],
                        value = fmt_value(tab$value[i]),
                        threshold = tab$threshold[i], status = status[i],
                        stringsAsFactors = FALSE)
      names(out) <- c("  criterion", "value", "threshold", "status")
      out[[1]] <- paste0("  ", out[[1]])
      print(out, row.names = FALSE, right = FALSE)
    }
  }
  invisible(object)
})

#' @rdname as.data.frame
#' @export
setMethod("as.data.frame", "CliQuality",
          function(x, row.names = NULL, optional = FALSE, ...) x@table)
