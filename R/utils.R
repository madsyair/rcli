# Internal helpers: conditions, argument checks and time-series utilities.

# Signal a classed error. All errors raised by rcli inherit from
# "rcli_error" so that callers can catch them selectively.
rcli_abort <- function(message, class = NULL) {
  cond <- structure(
    class = c(class, "rcli_error", "error", "condition"),
    list(message = message, call = NULL)
  )
  stop(cond)
}

rcli_warn <- function(message, class = NULL) {
  cond <- structure(
    class = c(class, "rcli_warning", "warning", "condition"),
    list(message = message, call = NULL)
  )
  warning(cond)
}

check_number <- function(x, name, lower = -Inf, upper = Inf,
                         integer = FALSE, allow_na = FALSE) {
  if (length(x) == 1L && is.atomic(x) && is.na(x) && allow_na) {
    return(invisible(TRUE))
  }
  ok <- is.numeric(x) && length(x) == 1L && !is.na(x)
  ok <- ok && x >= lower && x <= upper
  if (ok && integer) ok <- abs(x - round(x)) < 1e-8
  if (!ok) {
    kind <- if (integer) "a whole number" else "a number"
    rcli_abort(
      sprintf("`%s` must be %s in [%s, %s].", name, kind, lower, upper),
      "rcli_error_argument"
    )
  }
  invisible(TRUE)
}

check_flag <- function(x, name) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    rcli_abort(sprintf("`%s` must be TRUE or FALSE.", name),
               "rcli_error_argument")
  }
  invisible(TRUE)
}

check_frequency <- function(freq) {
  if (!is.numeric(freq) || length(freq) != 1L || !freq %in% c(4, 12)) {
    rcli_abort("Only quarterly (4) and monthly (12) data are supported.",
               "rcli_error_frequency")
  }
  invisible(TRUE)
}

check_ts <- function(x, name = "x") {
  if (!stats::is.ts(x)) {
    rcli_abort(sprintf("`%s` must be a `ts` object.", name),
               "rcli_error_argument")
  }
  check_frequency(stats::frequency(x))
  invisible(TRUE)
}

# Positions of the first and last non-missing observation.
non_na_span <- function(x) {
  idx <- which(!is.na(x))
  if (length(idx) == 0L) return(c(NA_integer_, NA_integer_))
  c(min(idx), max(idx))
}

# Fill internal gaps by linear interpolation; leading and trailing NAs stay.
fill_internal_na <- function(x) {
  span <- non_na_span(x)
  if (anyNA(span)) return(x)
  inner <- span[1]:span[2]
  miss <- inner[is.na(x[inner])]
  if (length(miss) > 0L) {
    obs <- inner[!is.na(x[inner])]
    x[miss] <- stats::approx(obs, x[obs], xout = miss)$y
  }
  x
}

# Rebuild a ts with the time attributes of `template`.
as_ts_like <- function(values, template) {
  stats::ts(values, start = stats::start(template),
            frequency = stats::frequency(template))
}

# Mean absolute deviation around the mean (OECD normalisation scale).
mean_abs_dev <- function(x) {
  x <- x[!is.na(x)]
  mean(abs(x - mean(x)))
}

# OECD normalisation: subtract the mean, divide by the mean absolute deviation.
normalise_cycle <- function(x) {
  m <- mean(x, na.rm = TRUE)
  s <- mean_abs_dev(x)
  if (!is.finite(s) || s <= 0) return(x * 0)
  (x - m) / s
}

# Shift a vector forward by k positions (positive k moves values later).
shift_vec <- function(x, k) {
  n <- length(x)
  if (k == 0L) return(x)
  out <- rep(NA_real_, n)
  if (abs(k) >= n) return(out)
  if (k > 0L) {
    out[(k + 1L):n] <- x[1:(n - k)]
  } else {
    out[1:(n + k)] <- x[(1 - k):n]
  }
  out
}

# Periods per year used to translate defaults expressed in years.
per_year <- function(freq) as.numeric(freq)

fmt_num <- function(x, digits = 2) {
  ifelse(is.na(x), "NA", formatC(x, format = "f", digits = digits))
}

# Compact display of statistics: small p-values in scientific notation.
fmt_value <- function(x) {
  vapply(x, function(v) {
    if (is.na(v)) return("NA")
    if (v != 0 && abs(v) < 1e-3) return(format(v, digits = 2,
                                                scientific = TRUE))
    formatC(v, digits = 3, format = "fg")
  }, character(1))
}
