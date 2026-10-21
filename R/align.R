#' Variable types for frequency conversion
#'
#' The type of a series sets how its frequency is changed (temporal
#' aggregation constraint):
#'
#' * `"flow"`: an amount accumulated over the period (GDP, production, sales,
#'   exports); a quarter is the sum of its months.
#' * `"stock"`: a position at a point in time (money supply, outstanding
#'   credit, reserves); a quarter is its last month.
#' * `"average"`: an average over the period (price indices, exchange and
#'   interest rates, survey balances, unemployment rate); a quarter is the
#'   mean of its months.
#'
#' @format A named character vector.
#' @seealso [cli_align()]
#' @examples
#' series_types
#' @export
series_types <- c(
  flow = "Flow: amount over the period (sum)",
  stock = "Stock: position at the end of the period (last value)",
  average = "Average: mean level over the period (mean)"
)

#' Align series of mixed frequencies
#'
#' Converts daily, weekly, monthly and quarterly series to one target
#' frequency, with the aggregation rule set by the type of each series
#' ([series_types]), so that they can enter [cli_candidates()]. The rules
#' follow the temporal-aggregation constraints of national accounts (IMF
#' 2017) and the OECD practice for composite leading indicators (Gyomai and
#' Guidetti 2012):
#'
#' * **Daily and weekly data** are spread over calendar days (a weekly flow
#'   is divided by seven; a weekly average is repeated on its seven days) and
#'   then summed (flow), averaged (average) or taken at the last observation
#'   (stock) within each month or quarter. Weeks are never summed by the
#'   month their last day falls in, which would make months of five weeks
#'   look 25 percent higher than months of four.
#' * **Monthly to quarterly**: sum, mean or last month; incomplete quarters
#'   are missing.
#' * **Quarterly to monthly, reference series**: temporal disaggregation that
#'   keeps the quarterly constraint: `"denton-cholette"` (the smoothest
#'   monthly path, Denton 1971 with the Cholette modification, computed
#'   here), `"chow-lin"` (regression on a monthly `indicator`, Chow and Lin
#'   1971, via the 'tempdisagg' package; the indicator must not also be a
#'   candidate) or `"linear"`.
#' * **Quarterly to monthly, candidates**: linear interpolation with the
#'   quarterly value placed in the central month (flows, averages) or the
#'   last month (stocks), as the OECD does; `position` overrides it, e.g. for
#'   a survey run in the first month of each quarter.
#'
#' The first and last periods of a daily or weekly series are kept only if
#' the data span at least `min_coverage` of their calendar days; a partial
#' flow is scaled up to the full period.
#'
#' @param series A list of series. Each element is a univariate `ts`
#'   (quarterly or monthly), a multivariate `ts` (its columns are taken as
#'   series of their own) or a data frame with columns `date` and `value`
#'   (daily, weekly, monthly or quarterly observations). Elements other than
#'   multivariate `ts` must be named.
#' @param freq Target frequency: 12 (monthly) or 4 (quarterly).
#' @param type Named character vector of series types (`"flow"`, `"stock"`
#'   or `"average"`); required for every series whose frequency changes.
#' @param reference Name of the reference series, which is disaggregated
#'   with `method` instead of interpolated.
#' @param method Disaggregation method for a quarterly reference series.
#' @param indicator Monthly `ts` used by `method = "chow-lin"`.
#' @param position Named integers (1 to 3): month of the quarter at which a
#'   quarterly candidate is placed before interpolation.
#' @param week_date Whether the dates of weekly data mark the first
#'   (`"start"`) or the last (`"end"`) day of each week.
#' @param min_coverage Smallest share of an edge period that daily or weekly
#'   data must cover.
#' @return A multivariate `ts` at frequency `freq`. Its attribute
#'   `"alignment"` is a data frame (`name`, `from`, `type`, `method`) that
#'   [cli_candidates()] stores with the candidate set.
#' @references
#' Chow, G. C. and Lin, A. (1971). Best linear unbiased interpolation,
#' distribution, and extrapolation of time series by related series.
#' *Review of Economics and Statistics*, 53(4), 372--375.
#'
#' Denton, F. T. (1971). Adjustment of monthly or quarterly series to annual
#' totals: an approach based on quadratic minimization. *Journal of the
#' American Statistical Association*, 66(333), 99--102.
#'
#' Gyomai, G. and Guidetti, E. (2012). *OECD System of Composite Leading
#' Indicators*. OECD, Paris.
#'
#' International Monetary Fund (2017). *Quarterly National Accounts Manual*,
#' chapter 6: Benchmarking and reconciliation. IMF, Washington.
#'
#' Sax, C. and Steiner, P. (2013). Temporal disaggregation of time series.
#' *The R Journal*, 5(2), 80--87.
#' @seealso [series_types], [cli_candidates()]
#' @examples
#' sim <- simulate_cycles(seed = 1, n_years = 20)
#' gdp_q <- aggregate(sim[, "reference"], nfrequency = 4, FUN = sum)
#' days <- seq(as.Date("1995-01-01"), as.Date("2014-12-31"), by = "day")
#' rate <- data.frame(date = days, value = 100 + cumsum(rnorm(length(days))))
#' x <- cli_align(
#'   list(gdp = gdp_q, sim[, c("lead_6", "lead_3")], rate = rate),
#'   type = c(gdp = "flow", rate = "average"), reference = "gdp"
#' )
#' attr(x, "alignment")
#' meta <- data.frame(name = c("lead_6", "lead_3", "rate"),
#'                    rationale = "early_stage")
#' cand <- cli_candidates(x, reference = "gdp", meta = meta)
#' @export
cli_align <- function(series, freq = 12, type = NULL, reference = NULL,
                      method = c("denton-cholette", "chow-lin", "linear"),
                      indicator = NULL, position = NULL,
                      week_date = c("start", "end"), min_coverage = 0.7) {
  check_frequency(freq)
  method <- match.arg(method)
  week_date <- match.arg(week_date)
  series <- flatten_series(series)
  type <- check_types(type, names(series))
  check_number(min_coverage, "min_coverage", lower = 0, upper = 1)
  if (!is.null(reference) && !reference %in% names(series)) {
    rcli_abort("`reference` must name one of the series.",
               "rcli_error_argument")
  }
  out <- list()
  log <- list()
  for (nm in names(series)) {
    s <- as_dated(series[[nm]], nm, week_date)
    tp <- if (nm %in% names(type)) type[[nm]] else NA_character_
    if (s$from != freq_name(freq) && is.na(tp)) {
      rcli_abort(
        sprintf(paste("Series '%s' is %s and must be converted; give its",
                      "type in `type` (flow, stock or average)."),
                nm, s$from),
        "rcli_error_argument"
      )
    }
    res <- convert_one(s, nm, tp, freq, is_ref = identical(nm, reference),
                       method = method, indicator = indicator,
                       position = position, min_coverage = min_coverage)
    out[[nm]] <- res$x
    log[[nm]] <- data.frame(name = nm, from = s$from, type = tp,
                            method = res$method, stringsAsFactors = FALSE)
  }
  x <- if (length(out) == 1L) {
    stats::ts(matrix(as.numeric(out[[1]]), ncol = 1,
                     dimnames = list(NULL, names(out))),
              start = stats::start(out[[1]]), frequency = freq)
  } else {
    do.call(stats::ts.union, out)
  }
  colnames(x) <- names(out)
  attr(x, "alignment") <- do.call(rbind, unname(log))
  x
}

freq_name <- function(freq) {
  c("4" = "quarterly", "12" = "monthly")[[as.character(freq)]]
}

flatten_series <- function(series) {
  if (!is.list(series) || is.data.frame(series) || length(series) == 0L) {
    rcli_abort("`series` must be a non-empty list of series.",
               "rcli_error_argument")
  }
  nms <- names(series)
  if (is.null(nms)) nms <- rep("", length(series))
  out <- list()
  for (k in seq_along(series)) {
    s <- series[[k]]
    if (stats::is.ts(s) && !is.null(dim(s)) && ncol(s) > 1L) {
      if (is.null(colnames(s))) {
        rcli_abort("A multivariate `ts` in `series` needs column names.",
                   "rcli_error_argument")
      }
      for (cn in colnames(s)) out[[cn]] <- s[, cn]
    } else {
      if (!nzchar(nms[k])) {
        rcli_abort("Every series except a multivariate `ts` must be named.",
                   "rcli_error_argument")
      }
      out[[nms[k]]] <- s
    }
  }
  if (anyDuplicated(names(out)) > 0L) {
    rcli_abort("Series names must be unique.", "rcli_error_argument")
  }
  out
}

check_types <- function(type, names) {
  if (is.null(type)) return(character(0))
  if (!is.character(type) || is.null(names(type)) ||
      any(!nzchar(names(type)))) {
    rcli_abort("`type` must be a named character vector.",
               "rcli_error_argument")
  }
  bad <- setdiff(type, names(series_types))
  if (length(bad) > 0L) {
    rcli_abort(sprintf("Unknown type(s): %s. Use flow, stock or average.",
                       paste(bad, collapse = ", ")), "rcli_error_argument")
  }
  unknown <- setdiff(names(type), names)
  if (length(unknown) > 0L) {
    rcli_abort(sprintf("`type` names unknown series: %s.",
                       paste(unknown, collapse = ", ")),
               "rcli_error_argument")
  }
  type
}

# Bring one input into a common shape: a ts (monthly or quarterly) or dated
# observations (daily or weekly).
as_dated <- function(s, nm, week_date) {
  if (stats::is.ts(s)) {
    f <- stats::frequency(s)
    if (!f %in% c(4, 12)) {
      rcli_abort(sprintf(paste("Series '%s': a `ts` must be monthly or",
                               "quarterly; give daily or weekly data as a",
                               "data frame with `date` and `value`."), nm),
                 "rcli_error_frequency")
    }
    return(list(from = freq_name(f), x = stats::ts(as.numeric(s),
                start = stats::start(s), frequency = f)))
  }
  if (!is.data.frame(s) || !all(c("date", "value") %in% names(s))) {
    rcli_abort(sprintf(paste("Series '%s' must be a `ts` or a data frame",
                             "with columns `date` and `value`."), nm),
               "rcli_error_argument")
  }
  d <- as.Date(s$date)
  v <- as.numeric(s$value)
  if (anyNA(d)) {
    rcli_abort(sprintf("Series '%s' has missing or invalid dates.", nm),
               "rcli_error_argument")
  }
  o <- order(d)
  d <- d[o]
  v <- v[o]
  if (anyDuplicated(d) > 0L) {
    rcli_abort(sprintf("Series '%s' has duplicated dates.", nm),
               "rcli_error_argument")
  }
  step <- if (length(d) > 1L) stats::median(as.numeric(diff(d))) else NA
  from <- if (is.na(step)) {
    NA_character_
  } else if (step <= 4) {
    "daily"
  } else if (step >= 6 && step <= 8) {
    "weekly"
  } else if (step >= 27 && step <= 32) {
    "monthly"
  } else if (step >= 85 && step <= 95) {
    "quarterly"
  } else {
    NA_character_
  }
  if (is.na(from)) {
    rcli_abort(sprintf(paste("Series '%s': cannot tell the frequency of its",
                             "dates (daily, weekly, monthly or quarterly)."),
                       nm), "rcli_error_frequency")
  }
  if (from %in% c("monthly", "quarterly")) {
    f <- if (from == "monthly") 12 else 4
    key <- period_key(d, f)
    full <- seq(min(key), max(key))
    vals <- rep(NA_real_, length(full))
    vals[match(key, full)] <- v
    return(list(from = from, x = stats::ts(vals, start = key_start(min(key),
                f), frequency = f)))
  }
  if (from == "weekly" && week_date == "end") d <- d - 6
  list(from = from, dates = d, values = v)
}

period_key <- function(d, freq) {
  y <- as.integer(format(d, "%Y"))
  m <- as.integer(format(d, "%m"))
  y * freq + (m - 1L) %/% (12L / freq)
}

key_start <- function(key, freq) c(key %/% freq, key %% freq + 1L)

period_bounds <- function(key, freq) {
  y <- key %/% freq
  p <- key %% freq
  first <- as.Date(sprintf("%d-%02d-01", y, p * (12L / freq) + 1L))
  nxt <- seq(first, by = sprintf("%d months", 12L / freq), length.out = 2L)[2]
  c(first, nxt - 1)
}

convert_one <- function(s, nm, tp, freq, is_ref, method, indicator,
                        position, min_coverage) {
  target <- freq_name(freq)
  if (identical(s$from, target)) {
    return(list(x = s$x, method = "none"))
  }
  if (s$from %in% c("daily", "weekly")) {
    days <- expand_days(s, tp)
    x <- aggregate_days(days$dates, days$values, tp, freq, min_coverage,
                        span = days$span)
    how <- if (s$from == "weekly" && tp != "stock") {
      sprintf("spread over days, %s", rule_word(tp))
    } else {
      rule_word(tp)
    }
    return(list(x = x, method = sprintf("%s to %s (%s)", s$from, target,
                                         how)))
  }
  if (s$from == "monthly" && freq == 4) {
    return(list(x = monthly_to_quarterly(s$x, tp),
                method = sprintf("monthly to quarterly (%s)", rule_word(tp))))
  }
  # quarterly to monthly
  if (is_ref) {
    x <- switch(method,
      "denton-cholette" = denton_cholette(s$x, tp),
      "chow-lin" = chow_lin(s$x, tp, indicator),
      "linear" = interpolate_quarterly(s$x, tp, quarter_position(nm, tp,
                                                                 position))
    )
    return(list(x = x, method = sprintf("quarterly to monthly (%s)",
                                         method)))
  }
  pos <- quarter_position(nm, tp, position)
  list(x = interpolate_quarterly(s$x, tp, pos),
       method = sprintf("quarterly to monthly (linear, month %d)", pos))
}

rule_word <- function(tp) {
  c(flow = "sum", stock = "last", average = "mean")[[tp]]
}

# Daily and weekly data as calendar days. A weekly flow is spread evenly over
# its seven days; a weekly average is repeated; a weekly stock is observed on
# the last day of its week.
expand_days <- function(s, tp) {
  if (s$from == "daily") {
    return(list(dates = s$dates, values = s$values,
                span = range(s$dates)))
  }
  start <- s$dates
  if (tp == "stock") {
    return(list(dates = start + 6, values = s$values,
                span = c(min(start), max(start) + 6)))
  }
  d <- rep(start, each = 7L) + rep(0:6, length(start))
  v <- rep(if (tp == "flow") s$values / 7 else s$values, each = 7L)
  list(dates = d, values = v, span = c(min(start), max(start) + 6))
}

aggregate_days <- function(dates, values, tp, freq, min_coverage, span) {
  key <- period_key(dates, freq)
  keys <- seq(min(key), max(key))
  out <- vapply(keys, function(k) {
    sel <- key == k & !is.na(values)
    if (!any(sel)) return(NA_real_)
    b <- period_bounds(k, freq)
    v <- values[sel]
    # a stock needs the end of the period; flows and averages enough days
    if (tp == "stock") return(if (span[2] >= b[2]) v[length(v)] else NA_real_)
    covered <- as.numeric(min(b[2], span[2]) - max(b[1], span[1])) + 1
    share <- covered / (as.numeric(b[2] - b[1]) + 1)
    if (share < min_coverage) return(NA_real_)
    if (tp == "flow") sum(v) / share else mean(v)
  }, numeric(1))
  stats::ts(out, start = key_start(min(keys), freq), frequency = freq)
}

monthly_to_quarterly <- function(x, tp) {
  v <- as.numeric(x)
  st <- stats::start(x)
  lead_in <- (st[2] - 1L) %% 3L
  v <- c(rep(NA_real_, lead_in), v)
  v <- c(v, rep(NA_real_, (3L - length(v) %% 3L) %% 3L))
  m <- matrix(v, nrow = 3L)
  q <- switch(tp,
    flow = colSums(m),
    average = colMeans(m),
    stock = m[3L, ]
  )
  stats::ts(q, start = c(st[1], (st[2] - 1L) %/% 3L + 1L), frequency = 4)
}

quarter_position <- function(nm, tp, position) {
  if (!is.null(position) && nm %in% names(position)) {
    p <- as.integer(position[[nm]])
    if (!p %in% 1:3) {
      rcli_abort("`position` values must be 1, 2 or 3.",
                 "rcli_error_argument")
    }
    return(p)
  }
  if (tp == "stock") 3L else 2L
}

# Monthly ts covering whole quarters of a quarterly ts `q`.
monthly_frame <- function(q) {
  st <- stats::start(q)
  stats::ts(rep(NA_real_, 3L * length(q)),
            start = c(st[1], 3L * (st[2] - 1L) + 1L), frequency = 12)
}

# OECD: linear interpolation with the quarterly value placed at month `pos`
# of its quarter (a flow is expressed per month first).
interpolate_quarterly <- function(q, tp, pos) {
  frame <- monthly_frame(q)
  v <- as.numeric(q)
  if (tp == "flow") v <- v / 3
  at <- 3L * (seq_along(v) - 1L) + pos
  ok <- !is.na(v)
  if (sum(ok) < 2L) {
    rcli_abort("A quarterly series needs at least two observations.",
               "rcli_error_short_series")
  }
  y <- stats::approx(at[ok], v[ok], xout = seq_along(frame), rule = 2)$y
  first <- min(at[ok]) - pos + 1L
  last <- max(at[ok]) - pos + 3L
  y[seq_along(y) < first | seq_along(y) > last] <- NA_real_
  as_ts_like(y, frame)
}

# Aggregation matrix of the quarterly constraint.
constraint_matrix <- function(m, tp) {
  w <- switch(tp, flow = c(1, 1, 1), average = c(1, 1, 1) / 3,
              stock = c(0, 0, 1))
  kronecker(diag(m), t(w))
}

# Additive first-difference Denton-Cholette without indicator: the smoothest
# monthly path (least squares of first differences) that satisfies the
# quarterly constraint exactly.
denton_cholette <- function(q, tp) {
  span <- non_na_span(q)
  if (anyNA(span) || anyNA(q[span[1]:span[2]])) {
    rcli_abort("The quarterly reference series has missing values.",
               "rcli_error_argument")
  }
  core <- stats::window(q, start = stats::time(q)[span[1]],
                        end = stats::time(q)[span[2]])
  y <- as.numeric(core)
  m <- length(y)
  n <- 3L * m
  cm <- constraint_matrix(m, tp)
  dm <- diff(diag(n))
  a <- rbind(cbind(2 * crossprod(dm), t(cm)),
             cbind(cm, matrix(0, m, m)))
  sol <- solve(a, c(rep(0, n), y))
  as_ts_like(sol[seq_len(n)], monthly_frame(core))
}

chow_lin <- function(q, tp, indicator) {
  if (!requireNamespace("tempdisagg", quietly = TRUE)) {
    rcli_abort("`method = \"chow-lin\"` needs the 'tempdisagg' package.",
               "rcli_error_dependency")
  }
  if (is.null(indicator) || !stats::is.ts(indicator) ||
      stats::frequency(indicator) != 12) {
    rcli_abort("`method = \"chow-lin\"` needs a monthly `indicator` ts.",
               "rcli_error_argument")
  }
  conv <- c(flow = "sum", stock = "last", average = "average")[[tp]]
  y <- stats::na.omit(q)
  ind <- stats::ts(as.numeric(indicator), start = stats::start(indicator),
                   frequency = 12)
  ind <- stats::window(ind, start = c(stats::start(y)[1],
                                      3L * (stats::start(y)[2] - 1L) + 1L))
  fit <- tempdisagg::td(y ~ ind, conversion = conv,
                        method = "chow-lin-maxlog")
  stats::predict(fit)
}
