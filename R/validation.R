#' Validate a composite leading indicator
#'
#' Tests the composite against the reference cycle in three ways:
#'
#' * **turning points**: the composite is dated and assessed exactly like a
#'   candidate (lead, consistency, missed and extra turning points,
#'   cross-correlation, concordance); `passed` is `TRUE` when it meets every
#'   leading criterion of the specification;
#' * **probability of contraction**: a logit model of the reference
#'   contraction state at time \eqn{t} on the change of the composite over
#'   the quarter ending at \eqn{t - h} (3 months or 1 quarter) gives the
#'   quadratic probability score (QPS, Diebold and Rudebusch 1989) and the
#'   area under the ROC curve (Berge and Jordà 2011);
#' * **direction**: the Pesaran and Timmermann (1992) test that the sign of
#'   the composite's change predicts the sign of the reference change
#'   \eqn{h} periods later.
#'
#' The horizon \eqn{h} is `spec@horizon` or, when that is `NA`, the lead of
#' the composite's cross-correlation peak (at least 1). These are in-sample
#' measures; use [cli_selection_bias()] for the out-of-sample check.
#'
#' @param composite A [CompositeIndex-class].
#' @param reference The reference [CycleSeries-class].
#' @param spec A [CliSpec-class].
#' @return A [CliValidation-class].
#' @references
#' Berge, T. J. and Jordà, Ò. (2011). Evaluating the classification of
#' economic activity into recessions and expansions. *American Economic
#' Journal: Macroeconomics*, 3(2), 246--277.
#'
#' Diebold, F. X. and Rudebusch, G. D. (1989). Scoring the leading
#' indicators. *Journal of Business*, 62(3), 369--391.
#'
#' Pesaran, M. H. and Timmermann, A. (1992). A simple nonparametric test of
#' predictive performance. *Journal of Business and Economic Statistics*,
#' 10(4), 461--465.
#' @examples
#' sim <- simulate_cycles(seed = 1)
#' meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
#' spec <- cli_spec(freq = 12)
#' cyc <- cli_cycles(cli_candidates(sim, "reference", meta = meta), spec)
#' cli <- cli_composite(cyc, c("lead_6", "lead_3"), spec, cyc$reference)
#' cli_validate(cli, cyc$reference, spec)
#' @export
cli_validate <- function(composite, reference, spec) {
  if (!is(composite, "CompositeIndex") || !is(reference, "CycleSeries")) {
    rcli_abort("Supply a CompositeIndex and the reference CycleSeries.",
               "rcli_error_argument")
  }
  comp_cs <- composite_as_cycle(composite)
  ref_tp <- date_turning_points(spec@dater, reference@normalised,
                                name = reference@name)
  comp_tp <- date_turning_points(spec@dater, comp_cs@normalised, name = "CLI")
  row <- assess_pair(reference, ref_tp, comp_cs, comp_tp, spec)$row
  chk <- leading_checks(row, spec)
  h <- if (is.na(spec@horizon)) max(1, row$ccf_lag, na.rm = TRUE) else
    spec@horizon
  prob <- probability_scores(as.numeric(composite@cycle), ref_tp, h,
                             span = max(1, spec@freq / 4))
  pt <- pesaran_timmermann(as.numeric(composite@cycle),
                           as.numeric(reference@normalised), h)
  prob$pt_stat <- pt$stat
  prob$pt_p <- pt$p_value
  row$name <- NULL
  val <- new("CliValidation", turning_points = row, probability = prob,
             out_of_sample = data.frame(), passed = all(chk),
             failed = names(chk)[!chk], quality = NULL)
  val@quality <- cli_quality(val, spec)
  val
}

composite_as_cycle <- function(composite) {
  new("CycleSeries", name = "CLI", original = composite@index,
      transformed = composite@index, cycle = composite@cycle,
      normalised = composite@cycle, steps = "composite")
}

probability_scores <- function(cli, ref_tp, h, span) {
  pr <- contraction_fit(cli, ref_tp, h, span)
  if (is.null(pr)) {
    return(data.frame(horizon = h, qps = NA_real_, qps_naive = NA_real_,
                      auc = NA_real_))
  }
  ok <- !is.na(pr$probability)
  y <- pr$contraction[ok]
  p <- pr$probability[ok]
  data.frame(horizon = h, qps = 2 * mean((p - y)^2),
             qps_naive = 2 * mean((mean(y) - y)^2), auc = auc_score(p, y))
}

# Logit of the reference contraction state on the lagged change of the CLI.
contraction_fit <- function(cli, ref_tp, h, span) {
  y <- 1 - as.numeric(cycle_states(ref_tp))
  change <- cli - shift_vec(cli, as.integer(span))
  x <- shift_vec(change, as.integer(h))
  ok <- !is.na(x) & !is.na(y)
  if (sum(ok) < 20L || length(unique(y[ok])) < 2L) return(NULL)
  fit <- suppressWarnings(stats::glm(y[ok] ~ x[ok],
                                     family = stats::binomial()))
  p <- rep(NA_real_, length(y))
  p[ok] <- stats::fitted(fit)
  data.frame(time = as.numeric(stats::time(ref_tp@series)),
             contraction = y, probability = p)
}

#' Probability of contraction implied by a composite
#'
#' Fits the logit model used by [cli_validate()]: the reference contraction
#' state (1 between a peak and the next trough) at time \eqn{t} on the change
#' of the composite over the quarter ending at \eqn{t - h}. `roc_curve()`
#' turns the fitted probabilities into the points of the ROC curve.
#'
#' @param composite A [CompositeIndex-class].
#' @param reference The reference [CycleSeries-class].
#' @param spec A [CliSpec-class].
#' @param horizon Lead \eqn{h} in periods; `NULL` uses the lead of the
#'   cross-correlation peak, as in [cli_validate()].
#' @return `contraction_probability()`: a data frame with `time`,
#'   `contraction` (0/1) and `probability` (`NA` where the model cannot be
#'   evaluated), or `NULL` when there are too few observations.
#'   `roc_curve()`: a data frame with `threshold`, `fpr` and `tpr`.
#' @examples
#' sim <- simulate_cycles(seed = 1)
#' meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
#' spec <- cli_spec(freq = 12)
#' cyc <- cli_cycles(cli_candidates(sim, "reference", meta = meta), spec)
#' cli <- cli_composite(cyc, c("lead_6", "lead_3"), spec, cyc$reference)
#' pr <- contraction_probability(cli, cyc$reference, spec)
#' head(roc_curve(pr$probability, pr$contraction))
#' @export
contraction_probability <- function(composite, reference, spec,
                                    horizon = NULL) {
  if (!is(composite, "CompositeIndex") || !is(reference, "CycleSeries")) {
    rcli_abort("Supply a CompositeIndex and the reference CycleSeries.",
               "rcli_error_argument")
  }
  ref_tp <- date_turning_points(spec@dater, reference@normalised,
                                name = reference@name)
  if (is.null(horizon)) {
    cc <- cross_correlation(as.numeric(composite@cycle),
                            as.numeric(reference@normalised),
                            spec@ccf_lag_max)
    horizon <- max(1, cc$lag, na.rm = TRUE)
  }
  contraction_fit(as.numeric(composite@cycle), ref_tp, horizon,
                  span = max(1, spec@freq / 4))
}

#' @rdname contraction_probability
#' @param score Predicted probabilities (or any score, higher meaning more
#'   likely contraction).
#' @param outcome Observed 0/1 outcome.
#' @export
roc_curve <- function(score, outcome) {
  ok <- !is.na(score) & !is.na(outcome)
  score <- score[ok]
  outcome <- outcome[ok]
  th <- c(Inf, sort(unique(score), decreasing = TRUE))
  pos <- sum(outcome == 1)
  neg <- sum(outcome == 0)
  data.frame(
    threshold = th,
    fpr = vapply(th, function(t) sum(score >= t & outcome == 0) / neg,
                 numeric(1)),
    tpr = vapply(th, function(t) sum(score >= t & outcome == 1) / pos,
                 numeric(1))
  )
}

# Area under the ROC curve via the Mann-Whitney statistic.
auc_score <- function(score, y) {
  pos <- y == 1
  n1 <- sum(pos)
  n0 <- sum(!pos)
  if (n1 == 0L || n0 == 0L) return(NA_real_)
  r <- rank(score)
  (sum(r[pos]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

pesaran_timmermann <- function(cli, ref, h) {
  dx <- shift_vec(c(NA, diff(cli)), as.integer(h))
  dy <- c(NA, diff(ref))
  ok <- !is.na(dx) & !is.na(dy) & dx != 0 & dy != 0
  n <- sum(ok)
  if (n < 20L) return(list(stat = NA_real_, p_value = NA_real_))
  px <- mean(dx[ok] > 0)
  py <- mean(dy[ok] > 0)
  p_hat <- mean((dx[ok] > 0) == (dy[ok] > 0))
  p_star <- py * px + (1 - py) * (1 - px)
  v_p <- p_star * (1 - p_star) / n
  v_star <- (2 * py - 1)^2 * px * (1 - px) / n +
    (2 * px - 1)^2 * py * (1 - py) / n +
    4 * py * px * (1 - py) * (1 - px) / n^2
  denom <- v_p - v_star
  if (!(denom > 0)) return(list(stat = NA_real_, p_value = NA_real_))
  stat <- (p_hat - p_star) / sqrt(denom)
  list(stat = stat, p_value = stats::pnorm(stat, lower.tail = FALSE))
}
