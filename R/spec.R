#' Specify a CLI workflow
#'
#' Collects every methodological choice in one validated object. Arguments
#' left at `NULL` take frequency-specific defaults: the monthly defaults
#' follow the OECD system of composite leading indicators (Gyomai and
#' Guidetti 2012); the quarterly ones translate them to quarters. The
#' classification thresholds were calibrated with the Monte Carlo harness in
#' `data-raw/` (see `vignette("rcli")`): on simulated monthly data they
#' classify about 86 percent of candidates correctly with about 1 percent of
#' non-leading series wrongly labelled leading.
#'
#' @param freq Data frequency: 12 (monthly) or 4 (quarterly).
#' @param filter A [CycleFilter-class]; default [hp_double_filter()].
#' @param dater A [Dater-class]; default [bry_boschan()] for monthly and
#'   [bbq()] for quarterly data.
#' @param aggregator An [Aggregator-class]; default [equal_weight()].
#' @param transform `"auto"` (logarithm for strictly positive series),
#'   `"log"` or `"none"`.
#' @param seasonal_adjust Seasonally adjust with X-13ARIMA-SEATS (needs the
#'   \pkg{seasonal} package)?
#' @param outlier_threshold Robust z-score of period-to-period changes above
#'   which an observation is replaced by interpolation; `Inf` disables.
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
#' @param horizon Horizon of the probability tests; `NA` uses the median lead
#'   of the composite.
#' @param oos_cutoffs Optional cut-off dates (decimal time, e.g. `2015`) for
#'   the selection-bias harness run by [cli_build()].
#' @param holidays A [holiday_effect()], or a list of them, whose effects
#'   X-13ARIMA-SEATS estimates and removes (needs `seasonal_adjust = TRUE`).
#'   For Indonesian data, `holiday_effect(idulfitri_dates())` removes the
#'   moving Idulfitri effect, which fixed monthly factors cannot.
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
                     aggregator = NULL, transform = c("auto", "log", "none"),
                     seasonal_adjust = FALSE, outlier_threshold = 5,
                     min_lead = NULL, min_median_lead = NULL,
                     min_consistency = 0.5, max_missed = 0.4,
                     max_extra = 0.4, coincident_band = NULL,
                     min_auc = 0.7, target_lead = NULL,
                     lead_window = NULL, ccf_lag_max = NULL, alpha = 0.05,
                     granger_max_lag = NULL, granger_dmax = 1,
                     max_iter = 10, min_components = 2, horizon = NA,
                     oos_cutoffs = numeric(0), holidays = list()) {
  check_frequency(freq)
  monthly <- freq == 12
  if (is(holidays, "HolidayEffect")) holidays <- list(holidays)
  spec <- new(
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
    holidays = holidays
  )
  validObject(spec)
  spec
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
  if (!(object@min_components >= 1)) {
    msg <- c(msg, "`min_components` must be >= 1.")
  }
  if (!is.na(object@horizon) && !(object@horizon >= 0)) {
    msg <- c(msg, "`horizon` must be NA or >= 0.")
  }
  hol <- object@holidays
  if (!all(vapply(hol, is, logical(1), "HolidayEffect"))) {
    msg <- c(msg, "`holidays` must be holiday_effect() objects.")
  } else if (length(hol) > 0L && !isTRUE(object@seasonal_adjust)) {
    msg <- c(msg, "`holidays` need `seasonal_adjust = TRUE`.")
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
  args <- list(...)
  bad <- setdiff(names(args), slotNames(object))
  if (length(args) > 0L && (is.null(names(args)) || length(bad) > 0L)) {
    rcli_abort(
      sprintf("Unknown specification field(s): %s.",
              paste(bad, collapse = ", ")),
      "rcli_error_argument"
    )
  }
  for (nm in names(args)) {
    value <- args[[nm]]
    if (is.numeric(value)) value <- as.numeric(value)
    slot(object, nm) <- value
  }
  validObject(object)
  object
})
