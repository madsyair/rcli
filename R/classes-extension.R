#' Extension of the end of a series before the cycle filter
#'
#' Two-sided filters such as the Hodrick-Prescott filter are least reliable
#' at the end of a series, which is where a leading indicator is read. An
#' `Extension` appends forecasts to the (transformed, outlier-treated)
#' series before the cycle is extracted; the forecasts are dropped again
#' afterwards, so the cycle keeps the length of the data. This is what the
#' OECD does with TRAMO forecasts (Gyomai and Guidetti 2012, p. 7) and
#' reduces end-point revisions of the Hodrick-Prescott filter (Kaiser and
#' Maravall 2001).
#'
#' * `ar_extension()`: the default since rcli 0.2.0. An autoregressive model
#'   for the period-to-period changes, with the order chosen by AIC up to
#'   `order_max` and estimated by the Yule-Walker equations
#'   ([stats::ar()]); the forecasts of the changes are cumulated from the
#'   last observation. A series whose changes are constant (up to rounding)
#'   is extended as a straight line with the mean change, and so is a series
#'   for which the autoregression cannot be fitted. In the real-time
#'   simulations behind this default (`data-raw/realtime_defaults.R`,
#'   vignette section 8) it cut the revision of the last value of the
#'   composite by 18 to 23 percent. With the O(n) HP solver of 0.2.1 it
#'   costs about 1 ms per series of 30 years.
#' * `no_extension()`: no forecasts (the behaviour of rcli 0.1.x).
#'
#' When the outlier treatment already gives forecasts ([tramo_outliers()]),
#' those are used and the extension is ignored.
#'
#' New strategies are added with a subclass of `Extension` and a method for
#' the generic `extend_series()`, which returns the numeric vector of
#' forecasts (possibly empty).
#'
#' @param h Number of periods appended; `NULL` means one year (12 months
#'   or 4 quarters).
#' @param order_max Largest autoregressive order considered; `NULL` means
#'   the frequency of the data. Any value is further bounded by
#'   `10 log10(m)` (the default bound of [stats::ar()]) and by `m - 2`,
#'   where `m = n - 1` is the number of changes.
#' @return An `Extension` object.
#' @references
#' Akaike, H. (1974). A new look at the statistical model identification.
#' *IEEE Transactions on Automatic Control*, 19(6), 716--723.
#'
#' Brockwell, P. J. and Davis, R. A. (1991). *Time Series: Theory and
#' Methods*, 2nd edition. Springer, New York.
#'
#' Gyomai, G. and Guidetti, E. (2012). *OECD System of Composite Leading
#' Indicators*. OECD Publishing, Paris.
#'
#' Kaiser, R. and Maravall, A. (2001). *Measuring Business Cycles in
#' Economic Time Series*. Lecture Notes in Statistics 154. Springer, New
#' York.
#' @seealso [cli_spec()], [tramo_outliers()]
#' @examples
#' x <- ts(cumsum(rnorm(120, 0.01, 0.02)), frequency = 12)
#' extend_series(ar_extension(h = 6), x)
#' extend_series(no_extension(), x)
#' @name Extension-class
#' @aliases Extension
#' @exportClass Extension
NULL

setClass("Extension", representation("VIRTUAL", label = "character"))

#' @rdname Extension-class
setClass("ArExtension", contains = "Extension",
         representation(h = "numeric", order_max = "numeric"))

#' @rdname Extension-class
setClass("NoExtension", contains = "Extension")

#' @rdname Extension-class
#' @export
ar_extension <- function(h = NULL, order_max = NULL) {
  if (!is.null(h)) check_number(h, "h", lower = 1, integer = TRUE)
  if (!is.null(order_max)) {
    check_number(order_max, "order_max", lower = 0, integer = TRUE)
  }
  new("ArExtension",
      label = sprintf("AR forecasts of the changes, %s",
                      if (is.null(h)) "one year" else paste(h, "periods")),
      h = if (is.null(h)) NA_real_ else as.numeric(h),
      order_max = if (is.null(order_max)) NA_real_ else as.numeric(order_max))
}

#' @rdname Extension-class
#' @export
no_extension <- function() {
  new("NoExtension", label = "none")
}

#' @rdname Extension-class
#' @param extension An `Extension`.
#' @param x A `ts` with at least three observations and no missing values.
#' @param ... Unused.
#' @export
setGeneric("extend_series", function(extension, x, ...) {
  standardGeneric("extend_series")
})

#' @rdname Extension-class
setMethod("extend_series", "NoExtension", function(extension, x, ...) {
  numeric(0)
})

# F-02 (harness/02-math/F-02.md): AR model of the changes by Yule-Walker,
# order by AIC; forecasts of the changes cumulated from the last value.
#' @rdname Extension-class
setMethod("extend_series", "ArExtension", function(extension, x, ...) {
  if (!stats::is.ts(x) || length(x) < 3L || !all(is.finite(x))) {
    rcli_abort("`x` must be a ts with at least 3 finite values.",
               "rcli_error_argument")
  }
  f <- stats::frequency(x)
  h <- if (is.na(extension@h)) f else extension@h
  v <- as.numeric(x)
  d <- diff(v)
  last <- v[length(v)]
  drift <- last + mean(d) * seq_len(h)
  scale <- max(abs(d))
  if (!(stats::var(d) > (sqrt(.Machine$double.eps) * scale)^2)) return(drift)
  pmax <- if (is.na(extension@order_max)) f else extension@order_max
  pmax <- min(pmax, floor(10 * log10(length(d))), length(d) - 2L)
  fd <- ar_forecast(d, max(0, pmax), h)
  if (is.null(fd) || any(!is.finite(fd))) drift else last + cumsum(fd)
})

# Forecasts of the changes from stats::ar(); NULL when the fit fails.
ar_forecast <- function(d, order_max, h) {
  tryCatch({
    fit <- stats::ar(d, aic = TRUE, order.max = order_max,
                     method = "yule-walker")
    as.numeric(stats::predict(fit, n.ahead = h)$pred)
  }, error = function(e) NULL)
}

#' @rdname Extension-class
#' @param object An object to print.
setMethod("show", "Extension", function(object) {
  cat("<", class(object), "> ", object@label, "\n", sep = "")
  invisible(object)
})
