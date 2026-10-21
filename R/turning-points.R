# Bry-Boschan / Harding-Pagan censoring algorithm on a numeric vector.
# Turning points are kept as a data frame with columns `i` (position) and
# `peak` (TRUE for a peak, FALSE for a trough), sorted by position.

tp_candidates <- function(y, k) {
  n <- length(y)
  peak <- trough <- logical(n)
  if (n > 2L * k) {
    for (i in (k + 1L):(n - k)) {
      win <- y[(i - k):(i + k)]
      peak[i] <- all(y[i] >= win)
      trough[i] <- all(y[i] <= win)
    }
  }
  # a flat stretch is neither a peak nor a trough
  flat <- peak & trough
  peak[flat] <- FALSE
  trough[flat] <- FALSE
  tp <- data.frame(i = c(which(peak), which(trough)),
                   peak = c(rep(TRUE, sum(peak)), rep(FALSE, sum(trough))))
  tp[order(tp$i), , drop = FALSE]
}

# Of consecutive turning points of the same type keep the more extreme one.
tp_alternate <- function(tp, y) {
  j <- 1L
  while (j < nrow(tp)) {
    if (tp$peak[j] == tp$peak[j + 1L]) {
      a <- y[tp$i[j]]
      b <- y[tp$i[j + 1L]]
      drop <- if (tp$peak[j]) {
        if (a >= b) j + 1L else j
      } else {
        if (a <= b) j + 1L else j
      }
      tp <- tp[-drop, , drop = FALSE]
    } else {
      j <- j + 1L
    }
  }
  rownames(tp) <- NULL
  tp
}

# Peak-to-peak and trough-to-trough distances of at least `min_cycle`.
tp_enforce_cycle <- function(tp, y, min_cycle) {
  for (is_peak in c(TRUE, FALSE)) {
    repeat {
      same <- which(tp$peak == is_peak)
      gaps <- diff(tp$i[same])
      bad <- which(gaps < min_cycle)
      if (length(bad) == 0L) break
      a <- same[bad[1]]
      b <- same[bad[1] + 1L]
      va <- y[tp$i[a]]
      vb <- y[tp$i[b]]
      drop <- if (is_peak) {
        if (va >= vb) b else a
      } else {
        if (va <= vb) b else a
      }
      tp <- tp_alternate(tp[-drop, , drop = FALSE], y)
    }
  }
  tp
}

# No turning point within `e` observations of the ends.
tp_enforce_ends <- function(tp, n, e) {
  keep <- tp$i > e & tp$i <= n - e
  tp[keep, , drop = FALSE]
}

# First (last) peak must exceed the first (last) value; troughs likewise.
tp_enforce_extremes <- function(tp, y) {
  n <- length(y)
  repeat {
    changed <- FALSE
    if (nrow(tp) > 0L) {
      f <- 1L
      if ((tp$peak[f] && y[1] > y[tp$i[f]]) ||
          (!tp$peak[f] && y[1] < y[tp$i[f]])) {
        tp <- tp[-f, , drop = FALSE]
        changed <- TRUE
      }
    }
    if (nrow(tp) > 0L) {
      l <- nrow(tp)
      if ((tp$peak[l] && y[n] > y[tp$i[l]]) ||
          (!tp$peak[l] && y[n] < y[tp$i[l]])) {
        tp <- tp[-l, , drop = FALSE]
        changed <- TRUE
      }
    }
    if (!changed) break
  }
  tp
}

# Phases shorter than `min_phase`: drop the later turning point of the pair.
tp_enforce_phase <- function(tp, y, min_phase) {
  j <- 1L
  while (j < nrow(tp)) {
    if (tp$i[j + 1L] - tp$i[j] < min_phase) {
      tp <- tp_alternate(tp[-(j + 1L), , drop = FALSE], y)
    } else {
      j <- j + 1L
    }
  }
  tp
}

tp_core <- function(y, window, min_phase, min_cycle, end_exclusion) {
  n <- length(y)
  tp <- tp_alternate(tp_candidates(y, window), y)
  for (iter in seq_len(100L)) {
    before <- tp
    tp <- tp_enforce_cycle(tp, y, min_cycle)
    tp <- tp_alternate(tp_enforce_ends(tp, n, end_exclusion), y)
    tp <- tp_alternate(tp_enforce_extremes(tp, y), y)
    tp <- tp_enforce_phase(tp, y, min_phase)
    tp <- tp_alternate(tp_enforce_extremes(tp, y), y)
    if (identical(before, tp)) break
  }
  tp
}

date_with_rules <- function(dater, x, name) {
  check_ts(x)
  span <- non_na_span(x)
  rules <- resolve_dater(dater, stats::frequency(x))
  if (anyNA(span)) {
    tp <- data.frame(i = integer(0), peak = logical(0))
  } else {
    y <- as.numeric(x)[span[1]:span[2]]
    if (anyNA(y)) {
      rcli_abort("Internal missing values are not allowed when dating.",
                 "rcli_error_missing")
    }
    tp <- do.call(tp_core, c(list(y = y), rules))
    tp$i <- tp$i + span[1] - 1L
  }
  new("TurningPoints", name = name, series = x, index = as.integer(tp$i),
      type = c("trough", "peak")[tp$peak + 1L], params = rules)
}

#' @rdname date_turning_points
setMethod("date_turning_points", "BryBoschan",
          function(dater, x, name = "", ...) date_with_rules(dater, x, name))

#' @rdname date_turning_points
setMethod("date_turning_points", "BBQ",
          function(dater, x, name = "", ...) date_with_rules(dater, x, name))

#' Expansion and contraction states implied by turning points
#'
#' Returns 1 in expansions (after a trough up to and including the next peak)
#' and 0 in contractions. Observations before the first turning point take the
#' state that the first turning point ends; observations outside the
#' non-missing span of the series are `NA`.
#'
#' @param tp A [TurningPoints-class] object.
#' @return An integer `ts` aligned with the dated series.
#' @examples
#' x <- ts(sin(2 * pi * (1:120) / 40), frequency = 4)
#' cycle_states(date_turning_points(bbq(), x))
#' @export
cycle_states <- function(tp) {
  if (!is(tp, "TurningPoints")) {
    rcli_abort("`tp` must be a TurningPoints object.",
               "rcli_error_argument")
  }
  x <- tp@series
  n <- length(x)
  s <- rep(NA_integer_, n)
  span <- non_na_span(x)
  if (anyNA(span) || length(tp@index) == 0L) return(as_ts_like(s, x))
  first_is_peak <- tp@type[1] == "peak"
  state <- if (first_is_peak) 1L else 0L
  breaks <- c(tp@index, span[2])
  pos <- span[1]
  for (b in seq_along(breaks)) {
    s[pos:breaks[b]] <- state
    pos <- breaks[b] + 1L
    state <- 1L - state
    if (pos > span[2]) break
  }
  as_ts_like(s, x)
}
