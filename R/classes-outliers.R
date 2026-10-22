#' Outlier treatment
#'
#' An `OutlierTreatment` cleans a (transformed) series of outliers before
#' its cycle is extracted, and may extend it with forecasts.
#'
#' * `robust_outliers()`: the default of the package. An observation is an
#'   outlier when its change from the previous period and the next change
#'   are both more than `threshold` robust z-scores (deviation from the
#'   median change divided by the median absolute deviation) and of
#'   opposite sign, that is, a one-period spike. Spikes are replaced by
#'   linear interpolation. No model and no external program are needed.
#' * `tramo_outliers()`: the OECD treatment (Gyomai and Guidetti 2012,
#'   p. 6--7). A regARIMA model with automatic outlier detection finds
#'   additive outliers (AO), transitory changes (TC) and level shifts (LS);
#'   the estimated effects of the types in `remove` are subtracted from the
#'   series, which replaces the outlying observations by their estimated
#'   values. The same model provides `forecast` periods of forecasts that
#'   extend the series before the cycle filter, which stabilises the end of
#'   the cycle. With `engine = "tramo"` the model is TRAMO, through the
#'   \pkg{RJDemetra} package (JDemetra+, needs Java), as at the OECD; with
#'   `engine = "x13"` it is the regARIMA part of X-13ARIMA-SEATS through
#'   \pkg{seasonal}, which uses the same outlier types and detection
#'   procedure (Chen and Liu 1993); `"auto"` takes TRAMO when \pkg{RJDemetra}
#'   is installed and X-13 otherwise.
#'
#' By default only AO and TC (temporary shocks) are removed. Level shifts
#' are detected, so that they are not mistaken for other outliers, but kept:
#' in monthly activity data the automatic procedure often labels the onset
#' of a recession a level shift, and removing it would erase a genuine
#' cyclical movement. Use `remove = c("AO", "TC", "LS")` for the fully
#' linearised series.
#'
#' New treatments are added by defining a subclass and a method for the
#' generic `treat_outliers()`, which returns a list with the cleaned series
#' `x`, the number of outliers `n`, a description `step` and a numeric
#' vector `forecast` (possibly empty).
#'
#' @param threshold Robust z-score above which a change is extreme.
#' @param engine `"auto"`, `"tramo"` (RJDemetra) or `"x13"` (seasonal).
#' @param remove Outlier types whose effects are removed: any of `"AO"`,
#'   `"TC"`, `"LS"`.
#' @param forecast Number of periods of forecasts appended before the cycle
#'   filter; `NULL` means one year (12 months or 4 quarters), 0 none. The
#'   OECD describes these forecasts as "short horizon" without giving the
#'   number.
#' @param critical Critical t-value of the outlier detection; `NULL` uses
#'   the program's default, which depends on the length of the series.
#' @return An `OutlierTreatment` object.
#' @references
#' Chen, C. and Liu, L.-M. (1993). Joint estimation of model parameters and
#' outlier effects in time series. *Journal of the American Statistical
#' Association*, 88(421), 284--297.
#'
#' Gómez, V. and Maravall, A. (2001). Automatic modeling methods for
#' univariate series. In D. Peña, G. C. Tiao and R. S. Tsay (eds.), *A
#' Course in Time Series Analysis*, 171--201. Wiley, New York.
#'
#' Gyomai, G. and Guidetti, E. (2012). *OECD System of Composite Leading
#' Indicators*. OECD Publishing, Paris.
#' @seealso [cli_spec()], [oecd_spec()]
#' @examples
#' robust_outliers()
#' tramo_outliers(engine = "x13")
#' @name OutlierTreatment-class
#' @aliases OutlierTreatment
#' @exportClass OutlierTreatment
NULL

setClass("OutlierTreatment", representation("VIRTUAL", label = "character"))

#' @rdname OutlierTreatment-class
setClass("RobustOutliers", contains = "OutlierTreatment",
         representation(threshold = "numeric"))

#' @rdname OutlierTreatment-class
setClass("TramoOutliers", contains = "OutlierTreatment",
         representation(engine = "character", remove = "character",
                        forecast = "numeric", critical = "numeric"))

#' @rdname OutlierTreatment-class
#' @export
robust_outliers <- function(threshold = 5) {
  if (!is.numeric(threshold) || length(threshold) != 1L || is.na(threshold) ||
      !(threshold > 0)) {
    rcli_abort("`threshold` must be a positive number (Inf disables).",
               "rcli_error_argument")
  }
  new("RobustOutliers", label = sprintf("robust z-score > %s", threshold),
      threshold = as.numeric(threshold))
}

#' @rdname OutlierTreatment-class
#' @export
tramo_outliers <- function(engine = c("auto", "tramo", "x13"),
                           remove = c("AO", "TC"), forecast = NULL,
                           critical = NULL) {
  engine <- match.arg(engine)
  remove <- toupper(remove)
  if (length(remove) == 0L || !all(remove %in% c("AO", "TC", "LS"))) {
    rcli_abort("`remove` must contain \"AO\", \"TC\" and/or \"LS\".",
               "rcli_error_argument")
  }
  if (!is.null(forecast)) {
    check_number(forecast, "forecast", lower = 0, integer = TRUE)
  }
  if (!is.null(critical)) check_number(critical, "critical", lower = 1)
  new("TramoOutliers",
      label = sprintf("TRAMO-type regARIMA (%s), remove %s", engine,
                      paste(unique(remove), collapse = ", ")),
      engine = engine, remove = unique(remove),
      forecast = if (is.null(forecast)) NA_real_ else as.numeric(forecast),
      critical = if (is.null(critical)) NA_real_ else as.numeric(critical))
}

#' @rdname OutlierTreatment-class
#' @param method An `OutlierTreatment`.
#' @param x A `ts` (already transformed, without missing values).
#' @param ... Unused.
#' @export
setGeneric("treat_outliers", function(method, x, ...) {
  standardGeneric("treat_outliers")
})

#' @rdname OutlierTreatment-class
#' @param object An object to print.
setMethod("show", "OutlierTreatment", function(object) {
  cat("<", class(object), "> ", object@label, "\n", sep = "")
  invisible(object)
})
