#' Cycle forms
#'
#' A `CycleForm` decides what the cycle is extracted from: the level of the
#' series (the OECD growth cycle), its growth rate (growth rate cycle) or its
#' acceleration. The form is applied in [cli_cycles()] after seasonal
#' adjustment, the transformation and the outlier treatment, and before the
#' end-of-series extension and the cycle filter, so that growth rates are
#' computed from seasonally adjusted series and calendar effects do not
#' enter them (formula F-08 in the package harness).
#'
#' * `level_form()`: the series itself (default; the results of earlier
#'   versions).
#' * `growth_form(lag)`: growth rate over `lag` periods. A logged series
#'   gives \eqn{100 (z_t - z_{t-k})}, the log growth rate in percent; a
#'   series in levels (rates, percentages, indices that were not logged)
#'   gives the difference \eqn{z_t - z_{t-k}} in its own units. `lag = NA`
#'   (default) means one year (12 months or 4 quarters), the year-on-year
#'   rate; `lag = 1` gives the period-on-period rate.
#' * `acceleration_form(lag)`: the change of that growth rate from the
#'   previous period, \eqn{g_t - g_{t-1}}, in percentage points.
#'
#' The first `lag` (growth) or `lag + 1` (acceleration) observations are
#' missing. Without a `filter`, [cli_spec()] pairs the growth and
#' acceleration forms with [hp_smoother()], which smooths without removing a
#' trend, and the level form with [hp_double_filter()]. New forms are added
#' by a subclass of `CycleForm` with methods for `apply_form()` and
#' `default_filter()`.
#'
#' **Experimental.** The thresholds of the classifiers were calibrated on
#' growth cycles (the level form). Growth rate and acceleration cycles have
#' more turning points, so the share of extra turning points and the other
#' criteria have not been calibrated for them; simulation results are in
#' `inst/calibration/forms.csv`.
#'
#' @param lag Number of periods of the growth rate (a positive whole
#'   number), or `NA` for one year.
#' @param form A `CycleForm`.
#' @param x A `ts`: the seasonally adjusted, transformed series.
#' @param logged Logical: is `x` the logarithm of the series?
#' @return `level_form()`, `growth_form()` and `acceleration_form()` return
#'   a `CycleForm`; `apply_form()` a `ts` like `x`; `default_filter()` a
#'   [CycleFilter-class].
#' @references
#' Gyomai, G. and Guidetti, E. (2012). *OECD System of Composite Leading
#' Indicators*. OECD, Paris.
#' @seealso [cli_spec()], [hp_smoother()]
#' @examples
#' x <- ts(log(100 * cumprod(1 + rnorm(40, 0.01, 0.01))), frequency = 4)
#' g <- apply_form(growth_form(), x, logged = TRUE)
#' head(g, 6)
#' spec <- cli_spec(freq = 4, form = growth_form())
#' spec@filter
#' @name CycleForm-class
#' @aliases CycleForm
#' @exportClass CycleForm
NULL

setClass("CycleForm", representation("VIRTUAL", label = "character"))

#' @rdname CycleForm-class
setClass("LevelForm", contains = "CycleForm")

#' @rdname CycleForm-class
setClass("GrowthForm", contains = "CycleForm",
         representation(lag = "numeric"))

#' @rdname CycleForm-class
setClass("AccelerationForm", contains = "CycleForm",
         representation(lag = "numeric"))

check_lag <- function(lag) {
  check_number(lag, "lag", lower = 1, integer = TRUE, allow_na = TRUE)
  if (is.infinite(lag)) {
    rcli_abort("`lag` must be finite.", "rcli_error_argument")
  }
  as.numeric(lag)
}

#' @rdname CycleForm-class
#' @export
level_form <- function() new("LevelForm", label = "level")

#' @rdname CycleForm-class
#' @export
growth_form <- function(lag = NA) {
  new("GrowthForm", label = "growth rate", lag = check_lag(lag))
}

#' @rdname CycleForm-class
#' @export
acceleration_form <- function(lag = NA) {
  new("AccelerationForm", label = "acceleration", lag = check_lag(lag))
}

#' @rdname CycleForm-class
#' @export
setGeneric("apply_form", function(form, x, logged) {
  standardGeneric("apply_form")
})

#' @rdname CycleForm-class
#' @export
setGeneric("default_filter", function(form) {
  standardGeneric("default_filter")
})

# Growth rate of `x` over `k` periods (F-08), NA for the first k.
growth_rate <- function(x, k, logged) {
  v <- as.numeric(x)
  n <- length(v)
  g <- rep(NA_real_, n)
  if (n > k) {
    d <- v[(k + 1):n] - v[1:(n - k)]
    g[(k + 1):n] <- if (isTRUE(logged)) 100 * d else d
  }
  as_ts_like(g, x)
}

form_lag <- function(form, x) {
  resolve_default(form@lag, stats::frequency(x))
}

#' @rdname CycleForm-class
setMethod("apply_form", "LevelForm", function(form, x, logged) x)

#' @rdname CycleForm-class
setMethod("apply_form", "GrowthForm", function(form, x, logged) {
  growth_rate(x, form_lag(form, x), logged)
})

#' @rdname CycleForm-class
setMethod("apply_form", "AccelerationForm", function(form, x, logged) {
  g <- growth_rate(x, form_lag(form, x), logged)
  growth_rate(g, 1, FALSE)
})

#' @rdname CycleForm-class
setMethod("default_filter", "CycleForm", function(form) hp_smoother())

#' @rdname CycleForm-class
setMethod("default_filter", "LevelForm", function(form) hp_double_filter())

# Kind of a form: "level", "growth" or "acceleration" (used instead of
# class tests wherever the units of a cycle matter).
setGeneric("form_kind", function(form) standardGeneric("form_kind"))
setMethod("form_kind", "LevelForm", function(form) "level")
setMethod("form_kind", "GrowthForm", function(form) "growth")
setMethod("form_kind", "AccelerationForm", function(form) "acceleration")

# Text recorded in the `steps` of a CycleSeries; downstream functions read
# the units of the series from it (see form_units()). Series that were not
# logged are differenced in their own units, and the text says so.
setGeneric("form_step", function(form, freq, logged = TRUE) {
  standardGeneric("form_step")
})
setMethod("form_step", "LevelForm", function(form, freq, logged = TRUE) {
  character(0)
})
setMethod("form_step", "GrowthForm", function(form, freq, logged = TRUE) {
  paste0("form: ", growth_label(form@lag, freq, logged))
})
setMethod("form_step", "AccelerationForm",
          function(form, freq, logged = TRUE) {
  paste0("form: acceleration of the ", growth_label(form@lag, freq, logged))
})

growth_label <- function(lag, freq, logged = TRUE) {
  k <- resolve_default(lag, freq)
  what <- if (isTRUE(logged)) "growth rate" else "difference"
  if (k == freq) return(paste("annual", what))
  sprintf("%s over %d period%s", what, as.integer(k),
          if (k == 1) "" else "s")
}

# Units of a CycleSeries: "level", "growth" or "acceleration".
form_units <- function(cs) {
  st <- cs@steps
  if (any(grepl("^form: acceleration", st))) return("acceleration")
  if (any(grepl("^form: ", st))) return("growth")
  "level"
}

# Form of a specification (specifications saved before 0.7.0 have none).
spec_form <- function(spec) {
  if (methods::.hasSlot(spec, "form")) spec@form else level_form()
}
