#' Date the turning points of all cycles
#'
#' @param cycles Named list of [CycleSeries-class] from [cli_cycles()].
#' @param spec A [CliSpec-class].
#' @return A named list of [TurningPoints-class].
#' @examples
#' sim <- simulate_cycles(seed = 1)
#' meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
#' spec <- cli_spec(freq = 12)
#' cyc <- cli_cycles(cli_candidates(sim, "reference", meta = meta), spec)
#' tps <- cli_turning_points(cyc, spec)
#' as.data.frame(tps$reference)
#' @export
cli_turning_points <- function(cycles, spec) {
  lapply(cycles, function(cs) {
    date_turning_points(spec@dater, cs@normalised, name = cs@name)
  })
}

# ---- turning-point matching ------------------------------------------------

# Pair reference and candidate turning points of the same type, in time
# order, when the candidate turns at most `window[2]` periods before and
# `window[1]` periods after the reference. Leads are positive when the
# candidate turns first.
match_turning_points <- function(ref, cand, window, end_exclusion) {
  cspan <- non_na_span(cand@series)
  rspan <- non_na_span(ref@series)
  ok_ref <- ref@index >= cspan[1] + end_exclusion &
    ref@index <= cspan[2] - end_exclusion
  ok_cand <- cand@index >= rspan[1] + end_exclusion &
    cand@index <= rspan[2] - end_exclusion
  r_idx <- ref@index[ok_ref]
  r_typ <- ref@type[ok_ref]
  c_idx <- cand@index[ok_cand]
  c_typ <- cand@type[ok_cand]
  used <- logical(length(c_idx))
  last <- -Inf
  pairs <- data.frame(ref_index = r_idx, type = r_typ,
                      cand_index = NA_integer_, lead = NA_real_)
  for (k in seq_along(r_idx)) {
    lead <- r_idx[k] - c_idx
    ok <- !used & c_typ == r_typ[k] & c_idx > last &
      lead <= window[2] & lead >= -window[1]
    if (any(ok)) {
      best <- which(ok)[which.min(abs(lead[ok]))]
      used[best] <- TRUE
      last <- c_idx[best]
      pairs$cand_index[k] <- c_idx[best]
      pairs$lead[k] <- lead[best]
    }
  }
  list(pairs = pairs, n_extra = sum(!used))
}

# ---- statistics --------------------------------------------------------------

cross_correlation <- function(cand, ref, lag_max) {
  lags <- -lag_max:lag_max
  r <- vapply(lags, function(k) {
    a <- shift_vec(cand, k)
    ok <- !is.na(a) & !is.na(ref)
    if (sum(ok) < 24L) return(NA_real_)
    if (stats::sd(a[ok]) == 0 || stats::sd(ref[ok]) == 0) return(NA_real_)
    stats::cor(a[ok], ref[ok])
  }, numeric(1))
  if (all(is.na(r))) {
    return(list(lag = NA_real_, r = NA_real_, lags = lags, all = r))
  }
  best <- which.max(abs(r))
  list(lag = lags[best], r = r[best], lags = lags, all = r)
}

# Newey-West test of the slope in a regression of y on x.
hac_slope_p <- function(y, x) {
  n <- length(y)
  if (n < 10L || stats::var(x) == 0 || stats::var(y) == 0) return(NA_real_)
  xm <- cbind(1, x)
  fit <- stats::lm.fit(xm, y)
  u <- xm * fit$residuals
  bw <- floor(4 * (n / 100)^(2 / 9))
  s <- crossprod(u)
  if (bw >= 1L) {
    for (l in seq_len(bw)) {
      g <- crossprod(u[(l + 1L):n, , drop = FALSE],
                     u[1:(n - l), , drop = FALSE])
      s <- s + (1 - l / (bw + 1)) * (g + t(g))
    }
  }
  bread <- solve(crossprod(xm))
  v <- bread %*% s %*% bread
  if (!(v[2, 2] > 0)) return(NA_real_)
  2 * stats::pnorm(-abs(fit$coefficients[2] / sqrt(v[2, 2])))
}

#' Concordance index of two cycles
#'
#' Harding and Pagan (2002) concordance: the share of periods in which the
#' two series are in the same phase, compared with its value under
#' independence, and a Newey-West test of no synchronisation (Harding and
#' Pagan 2006).
#'
#' @param x,y [TurningPoints-class] objects of the same frequency and length.
#' @param shift Periods by which `x` is moved forward before comparing (use
#'   the lead of `x`).
#' @return A list with `index`, `expected` (value under independence) and
#'   `p_value`.
#' @references
#' Harding, D. and Pagan, A. (2006). Synchronization of cycles. *Journal of
#' Econometrics*, 132(1), 59--79.
#' @examples
#' t <- 1:240
#' a <- ts(sin(2 * pi * t / 48), frequency = 12)
#' b <- ts(sin(2 * pi * (t - 6) / 48), frequency = 12)
#' concordance(date_turning_points(bry_boschan(), a),
#'             date_turning_points(bry_boschan(), b), shift = 6)
#' @export
concordance <- function(x, y, shift = 0) {
  sx <- shift_vec(as.numeric(cycle_states(x)), as.integer(round(shift)))
  sy <- as.numeric(cycle_states(y))
  if (length(sx) != length(sy)) {
    rcli_abort("`x` and `y` must have the same length.",
               "rcli_error_argument")
  }
  ok <- !is.na(sx) & !is.na(sy)
  if (sum(ok) < 10L) {
    return(list(index = NA_real_, expected = NA_real_, p_value = NA_real_))
  }
  sx <- sx[ok]
  sy <- sy[ok]
  index <- mean(sx * sy + (1 - sx) * (1 - sy))
  mx <- mean(sx)
  my <- mean(sy)
  list(index = index, expected = mx * my + (1 - mx) * (1 - my),
       p_value = hac_slope_p(sy, sx))
}

lag_matrix <- function(x, lags) {
  if (lags == 0L) return(matrix(numeric(0), nrow = length(x), ncol = 0))
  vapply(seq_len(lags), function(l) shift_vec(x, l), numeric(length(x)))
}

# Toda-Yamamoto test that `cand` Granger-causes `ref`; lag order by AIC.
toda_yamamoto_p <- function(cand, ref, max_lag, dmax) {
  ok <- !is.na(cand) & !is.na(ref)
  cand <- cand[ok]
  ref <- ref[ok]
  n <- length(ref)
  if (n < 4L * (max_lag + dmax) + 10L) return(NA_real_)
  fit_rss <- function(p, extra, restrict) {
    total <- p + extra
    ylag <- lag_matrix(ref, total)
    xlag <- lag_matrix(cand, total)
    if (restrict) xlag <- xlag[, seq_len(total) > p, drop = FALSE]
    rows <- (max_lag + dmax + 1L):n
    xm <- cbind(1, ylag[rows, , drop = FALSE], xlag[rows, , drop = FALSE])
    fit <- stats::lm.fit(xm, ref[rows])
    list(rss = sum(fit$residuals^2), k = ncol(xm), n = length(rows))
  }
  aic <- vapply(seq_len(max_lag), function(p) {
    f <- fit_rss(p, 0L, FALSE)
    f$n * log(f$rss / f$n) + 2 * f$k
  }, numeric(1))
  p <- which.min(aic)
  u <- fit_rss(p, dmax, FALSE)
  r <- fit_rss(p, dmax, TRUE)
  if (!(u$rss > 0)) return(NA_real_)
  fstat <- ((r$rss - u$rss) / p) / (u$rss / (u$n - u$k))
  stats::pf(fstat, p, u$n - u$k, lower.tail = FALSE)
}

# ---- one candidate --------------------------------------------------------

assess_pair <- function(ref_cs, ref_tp, cand_cs, cand_tp, spec) {
  e <- resolve_dater(spec@dater, spec@freq)$end_exclusion
  m <- match_turning_points(ref_tp, cand_tp, spec@lead_window, e)
  pairs <- m$pairs
  leads <- pairs$lead[!is.na(pairs$lead)]
  n_ref <- nrow(pairs)
  med <- if (length(leads) > 0L) stats::median(leads) else NA_real_
  ccf <- cross_correlation(as.numeric(cand_cs@normalised),
                           as.numeric(ref_cs@normalised), spec@ccf_lag_max)
  shift <- if (!is.na(med)) med else if (!is.na(ccf$lag)) ccf$lag else 0
  conc <- concordance(cand_tp, ref_tp, shift = shift)
  row <- data.frame(
    name = cand_cs@name,
    n_ref = n_ref,
    n_matched = length(leads),
    missed = n_ref - length(leads),
    extra = m$n_extra,
    median_lead = med,
    mean_lead = if (length(leads) > 0L) mean(leads) else NA_real_,
    sd_lead = if (length(leads) > 1L) stats::sd(leads) else NA_real_,
    pct_led = if (n_ref > 0L) sum(leads > 0) / n_ref else NA_real_,
    ccf_lag = ccf$lag,
    ccf_r = ccf$r,
    concordance = conc$index,
    concordance_expected = conc$expected,
    concordance_p = conc$p_value,
    granger_p = toda_yamamoto_p(as.numeric(cand_cs@normalised),
                                as.numeric(ref_cs@normalised),
                                spec@granger_max_lag, spec@granger_dmax),
    stringsAsFactors = FALSE
  )
  list(row = row, pairs = pairs)
}

# Classifier of a specification (specifications saved before 0.1.3 have
# none and use the package rule).
spec_classifier <- function(spec) {
  if (methods::.hasSlot(spec, "classifier")) spec@classifier else
    rcli_classifier()
}

# Criteria of a leading series; returns a named logical vector.
leading_checks <- function(row, spec) {
  leading_criteria(spec_classifier(spec), row, spec)
}

classify_row <- function(row, spec) {
  classify_candidate(spec_classifier(spec), row, spec)
}

#' @rdname Classifier-class
setMethod("leading_criteria", "RcliClassifier", function(classifier, row,
                                                         spec) {
  conc_ok <- isTRUE(row$concordance_p < spec@alpha) &&
    isTRUE(row$concordance > row$concordance_expected)
  share <- function(k) if (row$n_ref > 0L) k / row$n_ref else Inf
  c(
    matched = row$n_matched >= 3L,
    ccf = isTRUE(row$ccf_lag >= spec@min_lead) && isTRUE(row$ccf_r > 0),
    lead = isTRUE(row$median_lead >= spec@min_median_lead),
    consistency = isTRUE(row$pct_led >= spec@min_consistency),
    missed = share(row$missed) <= spec@max_missed,
    extra = share(row$extra) <= spec@max_extra,
    concordance = conc_ok,
    granger = isTRUE(row$granger_p < spec@alpha)
  )
})

#' @rdname Classifier-class
setMethod("classify_candidate", "RcliClassifier", function(classifier, row,
                                                           spec) {
  chk <- leading_criteria(classifier, row, spec)
  base_ok <- chk[["matched"]] && chk[["missed"]] && chk[["extra"]] &&
    chk[["concordance"]]
  cls <- if (all(chk)) {
    "leading"
  } else if (base_ok && isTRUE(abs(row$ccf_lag) <= spec@coincident_band)) {
    "coincident"
  } else if (base_ok && isTRUE(row$ccf_lag <= -spec@min_lead)) {
    "lagging"
  } else {
    "rejected"
  }
  reasons <- if (cls == "leading") {
    ""
  } else {
    paste(names(chk)[!chk], collapse = ", ")
  }
  list(class = cls, reasons = reasons)
})

# OECD thresholds in periods of the data.
oecd_band <- function(classifier, spec) {
  c(coincident = classifier@coincident, long = classifier@long) *
    spec@freq / 12
}

#' @rdname Classifier-class
setMethod("leading_criteria", "OecdClassifier", function(classifier, row,
                                                         spec) {
  band <- oecd_band(classifier, spec)
  c(matched = isTRUE(row$n_matched >= classifier@min_matched),
    lead = isTRUE(row$median_lead >= band[["coincident"]]))
})

#' @rdname Classifier-class
setMethod("classify_candidate", "OecdClassifier", function(classifier, row,
                                                           spec) {
  band <- oecd_band(classifier, spec)
  lead <- row$median_lead
  if (!isTRUE(row$n_matched >= classifier@min_matched) || is.na(lead)) {
    return(list(class = "rejected", reasons = "matched"))
  }
  if (lead >= band[["coincident"]]) {
    reasons <- if (lead > band[["long"]]) {
      sprintf("longer lead (over %s months)", classifier@long)
    } else {
      ""
    }
    return(list(class = "leading", reasons = reasons))
  }
  if (lead <= -band[["coincident"]]) {
    return(list(class = "lagging", reasons = "lead"))
  }
  list(class = "coincident", reasons = "lead")
})

invert_cycle <- function(cs) {
  cs@cycle <- -cs@cycle
  cs@normalised <- -cs@normalised
  cs@steps <- c(cs@steps, "inverted (counter-cyclical)")
  cs
}

#' Classify candidates as leading, coincident, lagging or rejected
#'
#' For every candidate the function pairs its turning points with those of
#' the reference series and computes: the number of reference turning points
#' it can be compared with, matched, missed and extra turning points; the
#' median, mean and standard deviation of the lead; the share of reference
#' turning points it leads; the lag and value of the peak cross-correlation;
#' the concordance index at the median lead with a Newey-West test; and the
#' p-value of a Toda-Yamamoto test that the candidate Granger-causes the
#' reference. A candidate whose peak cross-correlation is negative is
#' inverted and assessed again.
#'
#' The rule is the [Classifier-class] of the specification. With the default
#' [rcli_classifier()], a candidate is **leading** when it has at least
#' three matched turning
#' points, its cross-correlation with the reference peaks with a positive sign
#' at a lead of at least `min_lead`, its median lead at turning points is at
#' least `min_median_lead`, it leads at least `min_consistency` of the
#' reference turning points, missed and extra turning points are at most
#' `max_missed` and `max_extra` of the reference turning points, its
#' concordance is significantly above the value under independence, and it
#' Granger-causes the reference at level `alpha`. The Granger criterion was
#' added after the Monte Carlo calibration showed it cuts false "leading"
#' labels of pure-noise series by a factor of about ten at almost no loss of
#' power. **Coincident** and **lagging** series pass the matching, missed,
#' extra and concordance criteria with a cross-correlation peak within
#' `coincident_band` or at a lag of at least `min_lead`. All others are
#' **rejected**; the `reasons` column lists the leading criteria they failed.
#'
#' With [oecd_classifier()] the class follows the OECD table of median leads
#' at turning points (coincident within +/- 2 months, lagging at -2 months
#' or less); the other statistics are reported but not used.
#'
#' The lead of the cross-correlation peak is the primary lead measure because
#' the Monte Carlo calibration of the package showed that median leads at
#' turning points shrink towards zero as idiosyncratic noise grows, while the
#' cross-correlation lead stays unbiased (see `vignette("rcli")`).
#'
#' @param candidates A [CandidateSet-class].
#' @param spec A [CliSpec-class].
#' @param cycles Optional output of [cli_cycles()] to avoid recomputation.
#' @return A [LeadAssessment-class].
#' @references
#' Atabek, A., Coşar, E. E. and Şahinöz, S. (2005). A new composite leading
#' indicator for Turkish economic activity. *Emerging Markets Finance and
#' Trade*, 41(1), 45--64.
#'
#' Toda, H. Y. and Yamamoto, T. (1995). Statistical inference in vector
#' autoregressions with possibly integrated processes. *Journal of
#' Econometrics*, 66(1--2), 225--250.
#' @examples
#' sim <- simulate_cycles(seed = 1)
#' meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
#' cand <- cli_candidates(sim, "reference", meta = meta)
#' a <- cli_assess(cand, cli_spec(freq = 12))
#' a
#' leaders(a)
#' @export
cli_assess <- function(candidates, spec, cycles = NULL) {
  check_inputs(candidates, spec)
  if (is.null(cycles)) cycles <- cli_cycles(candidates, spec)
  ref_cs <- cycles[[candidates@reference]]
  ref_tp <- date_turning_points(spec@dater, ref_cs@normalised,
                                name = ref_cs@name)
  rows <- list()
  matches <- list()
  inverted <- character(0)
  for (nm in candidate_names(candidates)) {
    cs <- cycles[[nm]]
    tp <- date_turning_points(spec@dater, cs@normalised, name = nm)
    res <- assess_pair(ref_cs, ref_tp, cs, tp, spec)
    is_inv <- isTRUE(res$row$ccf_r < 0)
    if (is_inv) {
      cs <- invert_cycle(cs)
      tp <- date_turning_points(spec@dater, cs@normalised, name = nm)
      res <- assess_pair(ref_cs, ref_tp, cs, tp, spec)
      inverted <- c(inverted, nm)
    }
    cls <- classify_row(res$row, spec)
    res$row$inverted <- is_inv
    res$row$class <- cls$class
    res$row$reasons <- cls$reasons
    rows[[nm]] <- res$row
    matches[[nm]] <- res$pairs
  }
  tab <- do.call(rbind, rows)
  meta <- candidates@meta
  tab$rationale <- meta$rationale[match(tab$name, meta$name)]
  first <- c("name", "class", "rationale", "inverted")
  tab <- tab[, c(first, setdiff(names(tab), c(first, "reasons")), "reasons")]
  rownames(tab) <- NULL
  new("LeadAssessment", table = tab, matches = matches, inverted = inverted)
}
