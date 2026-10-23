#' Cycle filters
#'
#' A `CycleFilter` turns a (possibly log-transformed) series into its cyclical
#' component. `rcli` ships five filters; new ones are added by defining a
#' subclass of the virtual class `CycleFilter` and a method for
#' [extract_cycle()].
#'
#' Parameters given as `NA` are resolved from the frequency of the series when
#' the filter is applied, so the same specification works for monthly and
#' quarterly data. Periods are expressed in observations.
#'
#' * `hp_filter()`: Hodrick-Prescott filter; the cycle is the deviation from
#'   the HP trend. The default smoothing parameter is 1600 for quarterly and
#'   129600 for monthly data (Ravn and Uhlig 2002). The trend solves the
#'   pentadiagonal system of the filter with a banded LDL' factorisation in
#'   O(n) time and memory (Golub and Van Loan 2013, sec. 4.3).
#' * `hp_double_filter()`: the OECD double Hodrick-Prescott filter. A first HP
#'   filter with a cut-off of `trend_period` removes the trend; a second one
#'   with a cut-off of `smooth_period` removes high-frequency noise. Defaults:
#'   10 and 1 year (120 and 12 months), as in Gyomai and Guidetti (2012).
#' * `cf_filter()`: Christiano-Fitzgerald asymmetric band-pass filter for a
#'   random walk (Christiano and Fitzgerald 2003), keeping periods between `pl`
#'   and `pu` (defaults 1.5 and 8 years).
#' * `bk_filter()`: Baxter-King symmetric band-pass filter with `k` leads and
#'   lags (default 3 years); the first and last `k` values are missing.
#' * `hamilton_filter()`: Hamilton (2018) regression filter; the cycle is the
#'   residual of a regression of \eqn{y_{t+h}} on \eqn{y_t, \dots,
#'   y_{t-p+1}}. Defaults: `h` = 2 years, `p` = 1 year.
#'
#' @param lambda HP smoothing parameter, or `NA` for the frequency default.
#' @param trend_period,smooth_period Cut-off periods (in observations) of the
#'   two HP filters, or `NA` for the defaults.
#' @param pl,pu Lower and upper period (in observations) of the pass band, or
#'   `NA` for the defaults.
#' @param k Number of leads and lags of the Baxter-King filter, or `NA`.
#' @param h,p Horizon and number of lags of the Hamilton filter, or `NA`.
#' @return An object inheriting from `CycleFilter`.
#' @references
#' Christiano, L. J. and Fitzgerald, T. J. (2003). The band pass filter.
#' *International Economic Review*, 44(2), 435--465.
#'
#' Golub, G. H. and Van Loan, C. F. (2013). *Matrix Computations*, 4th ed.
#' Johns Hopkins University Press, Baltimore.
#'
#' Hamilton, J. D. (2018). Why you should never use the Hodrick-Prescott
#' filter. *Review of Economics and Statistics*, 100(5), 831--843.
#'
#' Hodrick, R. J. and Prescott, E. C. (1997). Postwar U.S. business cycles: an
#' empirical investigation. *Journal of Money, Credit and Banking*, 29(1),
#' 1--16.
#'
#' Ravn, M. O. and Uhlig, H. (2002). On adjusting the Hodrick-Prescott filter
#' for the frequency of observations. *Review of Economics and Statistics*,
#' 84(2), 371--376.
#' @seealso [extract_cycle()], [cli_spec()]
#' @examples
#' x <- ts(cumsum(rnorm(120)) + 50, frequency = 12, start = 2000)
#' cyc <- extract_cycle(hp_double_filter(), x)
#' head(cyc)
#' @name CycleFilter-class
#' @aliases CycleFilter
#' @exportClass CycleFilter
NULL

setClass("CycleFilter", representation("VIRTUAL", label = "character"))

#' @rdname CycleFilter-class
setClass("HPFilter", contains = "CycleFilter",
         representation(lambda = "numeric"))

#' @rdname CycleFilter-class
setClass("HPDoubleFilter", contains = "CycleFilter",
         representation(trend_period = "numeric", smooth_period = "numeric"))

#' @rdname CycleFilter-class
setClass("CFFilter", contains = "CycleFilter",
         representation(pl = "numeric", pu = "numeric"))

#' @rdname CycleFilter-class
setClass("BKFilter", contains = "CycleFilter",
         representation(pl = "numeric", pu = "numeric", k = "numeric"))

#' @rdname CycleFilter-class
setClass("HamiltonFilter", contains = "CycleFilter",
         representation(h = "numeric", p = "numeric"))

#' @rdname CycleFilter-class
#' @export
hp_filter <- function(lambda = NA) {
  check_number(lambda, "lambda", lower = 0, allow_na = TRUE)
  if (is.infinite(lambda)) {
    rcli_abort("`lambda` must be finite.", "rcli_error_argument")
  }
  new("HPFilter", label = "Hodrick-Prescott", lambda = as.numeric(lambda))
}

#' @rdname CycleFilter-class
#' @export
hp_double_filter <- function(trend_period = NA, smooth_period = NA) {
  check_number(trend_period, "trend_period", lower = 2, allow_na = TRUE)
  check_number(smooth_period, "smooth_period", lower = 2, allow_na = TRUE)
  if (!is.na(trend_period) && !is.na(smooth_period) &&
      smooth_period >= trend_period) {
    rcli_abort("`smooth_period` must be shorter than `trend_period`.",
               "rcli_error_argument")
  }
  new("HPDoubleFilter", label = "OECD double Hodrick-Prescott",
      trend_period = as.numeric(trend_period),
      smooth_period = as.numeric(smooth_period))
}

#' @rdname CycleFilter-class
#' @export
cf_filter <- function(pl = NA, pu = NA) {
  check_number(pl, "pl", lower = 2, allow_na = TRUE)
  check_number(pu, "pu", lower = 2, allow_na = TRUE)
  check_band(pl, pu)
  new("CFFilter", label = "Christiano-Fitzgerald",
      pl = as.numeric(pl), pu = as.numeric(pu))
}

#' @rdname CycleFilter-class
#' @export
bk_filter <- function(pl = NA, pu = NA, k = NA) {
  check_number(pl, "pl", lower = 2, allow_na = TRUE)
  check_number(pu, "pu", lower = 2, allow_na = TRUE)
  check_number(k, "k", lower = 1, integer = TRUE, allow_na = TRUE)
  check_band(pl, pu)
  new("BKFilter", label = "Baxter-King",
      pl = as.numeric(pl), pu = as.numeric(pu), k = as.numeric(k))
}

#' @rdname CycleFilter-class
#' @export
hamilton_filter <- function(h = NA, p = NA) {
  check_number(h, "h", lower = 1, integer = TRUE, allow_na = TRUE)
  check_number(p, "p", lower = 1, integer = TRUE, allow_na = TRUE)
  new("HamiltonFilter", label = "Hamilton regression",
      h = as.numeric(h), p = as.numeric(p))
}

check_band <- function(pl, pu) {
  if (!is.na(pl) && !is.na(pu) && pl >= pu) {
    rcli_abort("`pl` must be smaller than `pu`.", "rcli_error_argument")
  }
  invisible(TRUE)
}

#' Extract the cyclical component of a series
#'
#' @param filter A [CycleFilter-class] object.
#' @param x A monthly or quarterly `ts` without internal missing values.
#' @param ... Unused.
#' @return A `ts` with the same time attributes as `x`; values the filter
#'   cannot compute (for example the ends of the Baxter-King filter) are `NA`.
#' @seealso [CycleFilter-class]
#' @examples
#' x <- ts(sin(2 * pi * (1:160) / 40) + (1:160) / 20, frequency = 4)
#' extract_cycle(cf_filter(), x)
#' @export
setGeneric("extract_cycle", function(filter, x, ...) {
  standardGeneric("extract_cycle")
})
