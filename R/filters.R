# Filter algorithms. Each `*_core()` works on a plain numeric vector without
# missing values; the S4 methods resolve default parameters from the series
# frequency and restore the time attributes.

#' Smoothing parameter of an HP filter with a given cut-off period
#'
#' Returns the \eqn{\lambda} at which the gain of the Hodrick-Prescott
#' cyclical filter equals one half at `period` observations,
#' \eqn{\lambda = [4 (1 - \cos(2\pi/period))^2]^{-1}}. A cut-off of 120 months
#' gives \eqn{\lambda \approx 133107.9}, the value used by the OECD.
#'
#' @param period Cut-off period in observations (> 2).
#' @return A positive number.
#' @examples
#' hp_lambda(120)
#' hp_lambda(12)
#' @export
hp_lambda <- function(period) {
  check_number(period, "period", lower = 2 + 1e-8)
  1 / (4 * (1 - cos(2 * pi / period))^2)
}

hp_trend_core <- function(x, lambda) {
  n <- length(x)
  if (n < 4L) {
    rcli_abort("The HP filter needs at least 4 observations.",
               "rcli_error_short_series")
  }
  d2 <- diff(diag(n), differences = 2)
  as.numeric(solve(diag(n) + lambda * crossprod(d2), x))
}

cf_core <- function(x, pl, pu) {
  n <- length(x)
  a <- 2 * pi / pu
  b <- 2 * pi / pl
  j <- seq_len(n)
  bj <- c((b - a) / pi, (sin(j * b) - sin(j * a)) / (pi * j)) # B_0..B_n
  cum <- cumsum(bj[-1])                                       # sum B_1..B_m
  # Btilde_k = -B_0 / 2 - sum_{j = 1}^{k - 1} B_j
  btilde <- function(k) -bj[1] / 2 - if (k >= 2) cum[k - 1] else 0
  out <- numeric(n)
  for (t in seq_len(n)) {
    w <- numeric(n)
    w[t] <- bj[1]
    nf <- n - t - 1L
    if (nf >= 1L) w[t + seq_len(nf)] <- w[t + seq_len(nf)] + bj[1 + seq_len(nf)]
    w[n] <- w[n] + btilde(n - t)
    nb <- t - 2L
    if (nb >= 1L) w[t - seq_len(nb)] <- w[t - seq_len(nb)] + bj[1 + seq_len(nb)]
    w[1] <- w[1] + btilde(t - 1L)
    out[t] <- sum(w * x)
  }
  out
}

bk_core <- function(x, pl, pu, k) {
  n <- length(x)
  if (n <= 2 * k) {
    rcli_abort("The Baxter-King filter needs more than 2k observations.",
               "rcli_error_short_series")
  }
  a <- 2 * pi / pu
  b <- 2 * pi / pl
  j <- seq_len(k)
  bj <- c((b - a) / pi, (sin(j * b) - sin(j * a)) / (pi * j))
  theta <- -(bj[1] + 2 * sum(bj[-1])) / (2 * k + 1)
  w <- c(rev(bj[-1]), bj) + theta
  out <- rep(NA_real_, n)
  for (t in (k + 1):(n - k)) out[t] <- sum(w * x[(t - k):(t + k)])
  out
}

hamilton_core <- function(x, h, p) {
  n <- length(x)
  if (n < h + p + p + 2) {
    rcli_abort("The Hamilton filter needs more than h + 2p observations.",
               "rcli_error_short_series")
  }
  rows <- n - h - p + 1L
  xmat <- vapply(0:(p - 1), function(j) x[(p - j):(n - h - j)], numeric(rows))
  xmat <- cbind(1, matrix(xmat, nrow = rows))
  y <- x[(p + h):n]
  fit <- stats::lm.fit(xmat, y)
  out <- rep(NA_real_, n)
  out[(p + h):n] <- fit$residuals
  out
}

resolve_default <- function(value, default) if (is.na(value)) default else value

#' @rdname extract_cycle
setMethod("extract_cycle", "HPFilter", function(filter, x, ...) {
  check_ts(x)
  f <- stats::frequency(x)
  lambda <- resolve_default(filter@lambda, if (f == 4) 1600 else 129600)
  as_ts_like(as.numeric(x) - hp_trend_core(as.numeric(x), lambda), x)
})

#' @rdname extract_cycle
setMethod("extract_cycle", "HPDoubleFilter", function(filter, x, ...) {
  check_ts(x)
  f <- stats::frequency(x)
  tp <- resolve_default(filter@trend_period, 10 * f)
  sp <- resolve_default(filter@smooth_period, f)
  v <- as.numeric(x)
  dev <- v - hp_trend_core(v, hp_lambda(tp))
  as_ts_like(hp_trend_core(dev, hp_lambda(sp)), x)
})

#' @rdname extract_cycle
setMethod("extract_cycle", "CFFilter", function(filter, x, ...) {
  check_ts(x)
  f <- stats::frequency(x)
  pl <- resolve_default(filter@pl, 1.5 * f)
  pu <- resolve_default(filter@pu, 8 * f)
  check_band(pl, pu)
  as_ts_like(cf_core(as.numeric(x), pl, pu), x)
})

#' @rdname extract_cycle
setMethod("extract_cycle", "BKFilter", function(filter, x, ...) {
  check_ts(x)
  f <- stats::frequency(x)
  pl <- resolve_default(filter@pl, 1.5 * f)
  pu <- resolve_default(filter@pu, 8 * f)
  k <- resolve_default(filter@k, 3 * f)
  check_band(pl, pu)
  as_ts_like(bk_core(as.numeric(x), pl, pu, k), x)
})

#' @rdname extract_cycle
setMethod("extract_cycle", "HamiltonFilter", function(filter, x, ...) {
  check_ts(x)
  f <- stats::frequency(x)
  h <- resolve_default(filter@h, 2 * f)
  p <- resolve_default(filter@p, f)
  as_ts_like(hamilton_core(as.numeric(x), h, p), x)
})
