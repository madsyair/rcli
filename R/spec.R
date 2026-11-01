#' Specify a CLI workflow
#'
#' Collects every methodological choice in one validated object. Arguments
#' left at `NULL` take frequency-specific defaults: the monthly defaults
#' follow the OECD system of composite leading indicators (Gyomai and
#' Guidetti 2012); the quarterly ones translate them to quarters. The
#' classification thresholds were calibrated with the Monte Carlo harness in
#' `data-raw/` (see `vignette("rcli")`): on simulated monthly data they
#' classify about 87 percent of candidates correctly with at most 1.3
#' percent of non-leading series wrongly labelled leading (recalibrated with
#' the 0.2.0 defaults).
#'
#' Since rcli 0.2.0 the defaults chain the composite at the ragged edge
#' (`equal_weight()`) and extend each series with one year of AR forecasts
#' before the filter (`ar_extension()`). The settings of rcli 0.1.x are
#' `cli_spec(aggregator = equal_weight(ragged_edge = "level"),
#' extension = no_extension())`.
#'
#' @param freq Data frequency: 12 (monthly) or 4 (quarterly).
#' @param filter A [CycleFilter-class]; default [hp_double_filter()].
#' @param dater A [Dater-class]; default [bry_boschan()] for monthly and
#'   [bbq()] for quarterly data.
#' @param aggregator An [Aggregator-class]; default [equal_weight()], which
#'   after the last date with all components adds the average change of the
#'   available components to the previous value (since 0.2.0;
#'   `equal_weight(ragged_edge = "level")` restores rcli 0.1.x).
#' @param transform `"auto"` (logarithm for strictly positive series),
#'   `"log"`, `"none"` or `"test"` (logarithm when the log/level test of a
#'   regARIMA model prefers it, as TRAMO does at the OECD; needs
#'   \pkg{RJDemetra} or \pkg{seasonal}).
#' @param seasonal_adjust Seasonally adjust with X-13ARIMA-SEATS (needs the
#'   \pkg{seasonal} package)?
#' @param outlier_threshold Robust z-score of period-to-period changes above
#'   which an observation is replaced by interpolation; `Inf` disables. A
#'   shortcut for `outliers = robust_outliers(outlier_threshold)`.
#' @param min_lead Minimum lead of the cross-correlation peak, in periods
#'   (default 3 months or 1 quarter). Also the minimum lag of a lagging series.
#' @param min_median_lead Minimum median lead at turning points (default 1
#'   month or 0.5 quarter, that is, the median must point to a lead).
#' @param min_consistency Minimum share of reference turning points that the
#'   candidate leads (default 0.5).
#' @param max_missed,max_extra Maximum shares of missed and extra turning
#'   points, relative to the number of reference turning points (default 0.4).
#' @param coincident_band Largest absolute lag of the cross-correlation peak
#'   of a coincident series (default 1 month or 0 quarters).
#' @param min_auc Minimum area under the ROC curve for a good composite
#'   (default 0.7, "acceptable discrimination" in Hosmer and Lemeshow 2000).
#' @param target_lead Lead range the OECD aims at, reported in the quality
#'   scorecard for information (default 6 to 9 months or 2 to 3 quarters).
#' @param lead_window Turning points are paired when the candidate turns at
#'   most `lead_window[1]` periods after and `lead_window[2]` periods before
#'   the reference (default `c(12, 24)` months or `c(4, 8)` quarters).
#' @param ccf_lag_max Largest lead or lag of the cross-correlation search
#'   (default 24 months or 8 quarters).
#' @param alpha Significance level of the tests (default 0.05).
#' @param granger_max_lag Largest lag order considered by the Toda-Yamamoto
#'   test (default 12 months or 4 quarters); the order is chosen by AIC.
#' @param granger_dmax Extra unrestricted lags of the Toda-Yamamoto test.
#' @param max_iter Maximum number of iterations of the selection loop.
#' @param min_components Smallest number of components of the composite.
#' @param horizon Horizon of the probability tests; `NA` uses the lag of the
#'   cross-correlation peak of the composite (at least 1).
#' @param oos_cutoffs Optional cut-off dates (decimal time, e.g. `2015`) for
#'   the selection-bias harness run by [cli_build()].
#' @param holidays A [holiday_effect()], or a list of them, whose effects
#'   X-13ARIMA-SEATS estimates and removes (needs `seasonal_adjust = TRUE`).
#'   For Indonesian data, `holiday_effect(idulfitri_dates())` removes the
#'   moving Idulfitri effect, which fixed monthly factors cannot.
#' @param classifier A [Classifier-class]; default [rcli_classifier()]. Use
#'   [oecd_classifier()] for the OECD median-lead rule.
#' @param outliers An [OutlierTreatment-class]; default
#'   `robust_outliers(outlier_threshold)`. Use [tramo_outliers()] for the
#'   OECD treatment.
#' @param lag_shift Shift each component later by its median lead minus the
#'   shortest median lead of the components before aggregation, as the OECD
#'   does (default `FALSE`). Values moved past the last date of the data are
#'   dropped.
#' @param extension An [Extension-class]; default [ar_extension()]: each
#'   series is extended by one year of AR forecasts before the cycle filter.
#'   Use [no_extension()] for the behaviour of rcli 0.1.x.
#' @return A [CliSpec-class] object.
#' @references
#' Gyomai, G. and Guidetti, E. (2012). *OECD System of Composite Leading
#' Indicators*. OECD Publishing, Paris.
#' @examples
#' spec <- cli_spec(freq = 12)
#' spec
#' update(spec, min_lead = 6, aggregator = dynamic_factor())
#' @export
cli_spec <- function(freq = 12, filter = NULL, dater = NULL,
                     aggregator = NULL,
                     transform = c("auto", "log", "none", "test"),
                     seasonal_adjust = FALSE, outlier_threshold = 5,
                     min_lead = NULL, min_median_lead = NULL,
                     min_consistency = 0.5, max_missed = 0.4,
                     max_extra = 0.4, coincident_band = NULL,
                     min_auc = 0.7, target_lead = NULL,
                     lead_window = NULL, ccf_lag_max = NULL, alpha = 0.05,
                     granger_max_lag = NULL, granger_dmax = 1,
                     max_iter = 10, min_components = 2, horizon = NA,
                     oos_cutoffs = numeric(0), holidays = list(),
                     classifier = NULL, outliers = NULL, lag_shift = FALSE,
                     extension = NULL) {
  check_frequency(freq)
  monthly <- freq == 12
  if (is(holidays, "HolidayEffect")) holidays <- list(holidays)
  check_strategy(classifier, "Classifier", "classifier")
  check_strategy(outliers, "OutlierTreatment", "outliers")
  check_strategy(extension, "Extension", "extension")
  spec <- new_valid(
    "CliSpec",
    freq = as.numeric(freq),
    filter = if (is.null(filter)) hp_double_filter() else filter,
    dater = if (is.null(dater)) {
      if (monthly) bry_boschan() else bbq()
    } else {
      dater
    },
    aggregator = if (is.null(aggregator)) equal_weight() else aggregator,
    transform = match.arg(transform),
    seasonal_adjust = seasonal_adjust,
    outlier_threshold = as.numeric(outlier_threshold),
    min_lead = as.numeric(if (is.null(min_lead)) {
      if (monthly) 3 else 1
    } else {
      min_lead
    }),
    min_median_lead = as.numeric(if (is.null(min_median_lead)) {
      if (monthly) 1 else 0.5
    } else {
      min_median_lead
    }),
    min_consistency = as.numeric(min_consistency),
    max_missed = as.numeric(max_missed),
    max_extra = as.numeric(max_extra),
    coincident_band = as.numeric(if (is.null(coincident_band)) {
      if (monthly) 1 else 0
    } else {
      coincident_band
    }),
    min_auc = as.numeric(min_auc),
    target_lead = as.numeric(if (is.null(target_lead)) {
      if (monthly) c(6, 9) else c(2, 3)
    } else {
      target_lead
    }),
    lead_window = as.numeric(if (is.null(lead_window)) {
      if (monthly) c(12, 24) else c(4, 8)
    } else {
      lead_window
    }),
    ccf_lag_max = as.numeric(if (is.null(ccf_lag_max)) {
      if (monthly) 24 else 8
    } else {
      ccf_lag_max
    }),
    alpha = as.numeric(alpha),
    granger_max_lag = as.numeric(if (is.null(granger_max_lag)) {
      if (monthly) 12 else 4
    } else {
      granger_max_lag
    }),
    granger_dmax = as.numeric(granger_dmax),
    max_iter = as.numeric(max_iter),
    min_components = as.numeric(min_components),
    horizon = as.numeric(horizon),
    oos_cutoffs = as.numeric(oos_cutoffs),
    holidays = holidays,
    classifier = if (is.null(classifier)) rcli_classifier() else classifier,
    outliers = if (is.null(outliers)) {
      robust_outliers(outlier_threshold)
    } else {
      outliers
    },
    lag_shift = lag_shift,
    extension = if (is.null(extension)) ar_extension() else extension
  )
  if (is(spec@outliers, "RobustOutliers")) {
    spec@outlier_threshold <- spec@outliers@threshold
  }
  check_valid(spec)
  spec
}

# validObject() and new() with the error class of the package.
check_valid <- function(object) {
  tryCatch(methods::validObject(object), error = invalid_error)
  invisible(TRUE)
}

new_valid <- function(...) tryCatch(methods::new(...), error = invalid_error)

invalid_error <- function(e) {
  rcli_abort(sub("^invalid class .*? object: ", "", conditionMessage(e),
                 perl = TRUE), "rcli_error_argument")
}

check_strategy <- function(x, class, name) {
  if (!is.null(x) && !is(x, class)) {
    rcli_abort(sprintf("`%s` must be a %s object.", name, class),
               "rcli_error_argument")
  }
  invisible(TRUE)
}

# Slots added after 0.1.0, filled with the behaviour of the version that
# saved the object (used by update() on old specifications).
upgrade_spec <- function(object) {
  old <- list(holidays = list(), classifier = rcli_classifier(),
              outliers = robust_outliers(object@outlier_threshold),
              lag_shift = FALSE, extension = no_extension())
  for (nm in names(old)) {
    if (!methods::.hasSlot(object, nm)) attr(object, nm) <- old[[nm]]
  }
  object
}

setValidity("CliSpec", function(object) {
  msg <- character(0)
  one <- function(slot) length(slot(object, slot)) == 1L
  scalar_slots <- c("freq", "outlier_threshold", "min_lead", "min_median_lead",
                    "min_consistency", "max_missed", "max_extra",
                    "coincident_band", "ccf_lag_max", "alpha",
                    "granger_max_lag", "granger_dmax", "max_iter",
                    "min_components", "horizon", "min_auc")
  for (s in scalar_slots) {
    if (!one(s)) msg <- c(msg, sprintf("`%s` must have length 1.", s))
  }
  if (length(msg) > 0L) return(msg)
  for (s in setdiff(scalar_slots, "horizon")) {
    if (is.na(slot(object, s))) {
      msg <- c(msg, sprintf("`%s` must not be NA.", s))
    }
  }
  if (length(msg) > 0L) return(msg)
  if (!object@freq %in% c(4, 12)) msg <- c(msg, "`freq` must be 4 or 12.")
  if (length(object@seasonal_adjust) != 1L || is.na(object@seasonal_adjust)) {
    msg <- c(msg, "`seasonal_adjust` must be TRUE or FALSE.")
  }
  if (!(object@outlier_threshold > 0)) {
    msg <- c(msg, "`outlier_threshold` must be positive.")
  }
  if (!(object@min_lead >= 0)) msg <- c(msg, "`min_lead` must be >= 0.")
  if (!(object@min_consistency >= 0 && object@min_consistency <= 1)) {
    msg <- c(msg, "`min_consistency` must be in [0, 1].")
  }
  for (s in c("max_missed", "max_extra")) {
    if (!(slot(object, s) >= 0 && slot(object, s) <= 1)) {
      msg <- c(msg, sprintf("`%s` must be a share in [0, 1].", s))
    }
  }
  for (s in c("coincident_band", "granger_dmax", "min_median_lead")) {
    if (!(slot(object, s) >= 0)) msg <- c(msg, sprintf("`%s` must be >= 0.", s))
  }
  if (!(object@min_auc >= 0.5 && object@min_auc <= 1)) {
    msg <- c(msg, "`min_auc` must be in [0.5, 1].")
  }
  if (length(object@target_lead) != 2L || anyNA(object@target_lead) ||
      object@target_lead[1] > object@target_lead[2]) {
    msg <- c(msg, "`target_lead` must be an increasing pair of numbers.")
  }
  if (length(object@lead_window) != 2L || any(object@lead_window < 0)) {
    msg <- c(msg, "`lead_window` must be two non-negative numbers.")
  }
  if (!(object@ccf_lag_max >= 1)) msg <- c(msg, "`ccf_lag_max` must be >= 1.")
  if (!(object@alpha > 0 && object@alpha < 1)) {
    msg <- c(msg, "`alpha` must be in (0, 1).")
  }
  if (!(object@granger_max_lag >= 1)) {
    msg <- c(msg, "`granger_max_lag` must be >= 1.")
  }
  if (!(object@max_iter >= 1)) msg <- c(msg, "`max_iter` must be >= 1.")
  for (s in c("max_iter", "min_components", "ccf_lag_max",
              "granger_max_lag", "granger_dmax", "horizon")) {
    v <- slot(object, s)
    if (is.finite(v) && abs(v - round(v)) > 1e-8) {
      msg <- c(msg, sprintf("`%s` must be a whole number.", s))
    }
  }
  if (!(object@min_components >= 1)) {
    msg <- c(msg, "`min_components` must be >= 1.")
  }
  if (!is.na(object@horizon) &&
      !(object@horizon >= 0 && is.finite(object@horizon))) {
    msg <- c(msg, "`horizon` must be NA or a finite number >= 0.")
  }
  hol <- object@holidays
  if (!all(vapply(hol, is, logical(1), "HolidayEffect"))) {
    msg <- c(msg, "`holidays` must be holiday_effect() objects.")
  } else if (length(hol) > 0L && !isTRUE(object@seasonal_adjust)) {
    msg <- c(msg, "`holidays` need `seasonal_adjust = TRUE`.")
  }
  if (length(object@lag_shift) != 1L || is.na(object@lag_shift)) {
    msg <- c(msg, "`lag_shift` must be TRUE or FALSE.")
  }
  if (length(msg) == 0L) TRUE else msg
})

#' Update a specification
#'
#' @param object A [CliSpec-class].
#' @param ... Named slots to replace, e.g. `min_lead = 6`.
#' @return The updated, re-validated [CliSpec-class].
#' @examples
#' update(cli_spec(), aggregator = principal_component())
#' @export
setMethod("update", "CliSpec", function(object, ...) {
  object <- upgrade_spec(object)
  args <- list(...)
  bad <- setdiff(names(args), slotNames(object))
  if (length(args) > 0L && (is.null(names(args)) || length(bad) > 0L)) {
    rcli_abort(
      sprintf("Unknown specification field(s): %s.",
              paste(bad, collapse = ", ")),
      "rcli_error_argument"
    )
  }
  types <- methods::getSlots("CliSpec")
  for (nm in names(args)) {
    value <- args[[nm]]
    if (is.numeric(value) ||
        (types[[nm]] == "numeric" && is.logical(value) && all(is.na(value)))) {
      value <- as.numeric(value)
    }
    tryCatch(slot(object, nm) <- value, error = invalid_error)
  }
  # keep the outlier shortcut and the outlier treatment in step
  if ("outlier_threshold" %in% names(args) && !"outliers" %in% names(args)) {
    object@outliers <- robust_outliers(object@outlier_threshold)
  }
  if (is(object@outliers, "RobustOutliers")) {
    object@outlier_threshold <- object@outliers@threshold
  }
  check_valid(object)
  object
})

#' Specification that follows the OECD method
#'
#' A [cli_spec()] with every step set as in the OECD system of composite
#' leading indicators (Gyomai and Guidetti 2012):
#'
#' * outliers: TRAMO, additive outliers and transitory changes replaced by
#'   estimates ([tramo_outliers()]);
#' * logarithm or levels: TRAMO test (`transform = "test"`);
#' * end of the series: TRAMO forecasts before the filter
#'   ([tramo_outliers()]);
#' * cycle: double Hodrick-Prescott filter, 12 to 120 months
#'   ([hp_double_filter()]);
#' * turning points: simplified Bry-Boschan ([bry_boschan()]);
#' * classification: median lead, coincident within +/- 2 months
#'   ([oecd_classifier()]);
#' * lag-shifting: the leads of the components aligned (`lag_shift = TRUE`);
#' * aggregation: chained average growth with the 60 percent rule
#'   ([oecd_aggregate()]);
#' * presentation: amplitude adjusted, trend restored and 12-month rate of
#'   change ([cli_presentation()]).
#'
#' Seasonal adjustment, which the OECD applies only to series that are not
#' already adjusted at the source, uses X-13ARIMA-SEATS (the successor of
#' X-12-ARIMA, with SEATS) when `seasonal_adjust = TRUE`. Quarterly
#' candidates are always interpolated linearly by [cli_align()], at the
#' month the OECD uses (`method` only concerns the reference series). The
#' selection loop of
#' [cli_build()] then evaluates composites with the OECD classifier.
#'
#' The minimum median lead of the out-of-sample check is set to the
#' coincident band (2 months). Other arguments are passed to [cli_spec()].
#'
#' @param freq Data frequency, 12 or 4. The OECD system is monthly; for
#'   quarterly data the month thresholds are converted to quarters.
#' @param seasonal_adjust,holidays See [cli_spec()].
#' @param engine Engine of [tramo_outliers()] and of the log/level test.
#' @param ... Further arguments of [cli_spec()].
#' @return A [CliSpec-class].
#' @references
#' Gyomai, G. and Guidetti, E. (2012). *OECD System of Composite Leading
#' Indicators*. OECD Publishing, Paris.
#' @seealso [cli_spec()] for the package defaults and the reasons they
#'   differ (`vignette("rcli")`).
#' @examples
#' oecd_spec()
#' \donttest{
#' sim <- simulate_cycles(seed = 1)
#' meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
#' cand <- cli_candidates(sim, "reference", meta = meta)
#' if (requireNamespace("seasonal", quietly = TRUE)) {
#'   res <- cli_build(cand, oecd_spec(engine = "x13"))
#'   res
#' }
#' }
#' @export
oecd_spec <- function(freq = 12, seasonal_adjust = FALSE, holidays = list(),
                      engine = c("auto", "tramo", "x13"), ...) {
  check_frequency(freq)
  engine <- match.arg(engine)
  cls <- oecd_classifier()
  cli_spec(freq = freq, filter = hp_double_filter(), dater = NULL,
           aggregator = oecd_aggregate(), transform = "test",
           seasonal_adjust = seasonal_adjust, holidays = holidays,
           min_median_lead = cls@coincident * freq / 12,
           classifier = cls, outliers = tramo_outliers(engine = engine),
           lag_shift = TRUE, extension = no_extension(), ...)
}
