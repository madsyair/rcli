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
#'   the quarter ending at \eqn{t - h} (3 months or 1 quarter), estimated
#'   recursively out of sample (Estrella and Mishkin 1998): the probability
#'   for \eqn{t} comes from a model fitted to the periods up to
#'   \eqn{t - h} only, starting after 40 percent of the sample. Its
#'   quadratic probability score (QPS, Diebold and Rudebusch 1989) is
#'   compared with the naive forecast, the share of contraction periods up to
#'   \eqn{t - h}, and its area under the ROC curve (Berge and Jordà 2011)
#'   is computed from the same forecasts (`n_forecasts` of them). Fitted in
#'   sample, a logit always beats the naive forecast and says nothing;
#' * **direction**: the regression form of the Pesaran and Timmermann
#'   (2009) test that the sign of the composite's change predicts the sign
#'   of the reference change \eqn{h} periods later, with the fixed-b HAC
#'   variance of [concordance()], which allows for the strong persistence of
#'   the signs of cyclical changes.
#'
#' The horizon \eqn{h} is `spec@horizon` or, when that is `NA`, the lower
#' end of `spec@target_lead` (6 months or 2 quarters by default), fixed in
#' advance: a horizon taken from the composite's own cross-correlation would
#' be chosen from the data being tested. Use [cli_selection_bias()] for the
#' check of the selection itself.
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
#' Estrella, A. and Mishkin, F. S. (1998). Predicting U.S. recessions:
#' financial variables as leading indicators. *Review of Economics and
#' Statistics*, 80(1), 45--61.
#'
#' Pesaran, M. H. and Timmermann, A. (2009). Testing dependence among
#' serially correlated multicategory variables. *Journal of the American
#' Statistical Association*, 104(485), 325--337.
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
  if (!is(spec, "CliSpec")) {
    rcli_abort("`spec` must be a CliSpec (see cli_spec()).",
               "rcli_error_argument")
  }
  comp_cs <- composite_as_cycle(composite)
  ref_tp <- date_turning_points(spec@dater, reference@normalised,
                                name = reference@name)
  comp_tp <- date_turning_points(spec@dater, comp_cs@normalised, name = "CLI")
  row <- assess_pair(reference, ref_tp, comp_cs, comp_tp, spec)$row
  chk <- leading_checks(row, spec)
  h <- validation_horizon(spec)
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

# Horizon of the prediction tests: fixed in advance, never taken from the
# composite being tested.
validation_horizon <- function(spec) {
  if (is.na(spec@horizon)) spec@target_lead[1] else spec@horizon
}

probability_scores <- function(cli, ref_tp, h, span) {
  pr <- contraction_fit(cli, ref_tp, h, span, recursive = TRUE)
  empty <- data.frame(horizon = h, qps = NA_real_, qps_naive = NA_real_,
                      auc = NA_real_, n_forecasts = 0L)
  if (is.null(pr)) return(empty)
  ok <- !is.na(pr$probability)
  if (!any(ok)) return(empty)
  y <- pr$contraction[ok]
  p <- pr$probability[ok]
  data.frame(horizon = h, qps = 2 * mean((p - y)^2),
             qps_naive = 2 * mean((pr$naive[ok] - y)^2),
             auc = auc_score(p, y), n_forecasts = sum(ok))
}

# Logit of the reference contraction state on the lagged change of the CLI,
# fitted once in sample or recursively out of sample (F-07).
contraction_fit <- function(cli, ref_tp, h, span, recursive = TRUE) {
  y <- 1 - as.numeric(cycle_states(ref_tp))
  change <- cli - shift_vec(cli, as.integer(span))
  x <- shift_vec(change, as.integer(h))
  ok <- !is.na(x) & !is.na(y)
  if (sum(ok) < 20L || length(unique(y[ok])) < 2L) return(NULL)
  time <- as.numeric(stats::time(ref_tp@series))
  if (recursive) {
    rl <- recursive_logit(y, x, h)
    return(data.frame(time = time, contraction = y,
                      probability = rl$probability, naive = rl$naive))
  }
  fit <- suppressWarnings(stats::glm(y[ok] ~ x[ok],
                                     family = stats::binomial()))
  p <- rep(NA_real_, length(y))
  p[ok] <- stats::fitted(fit)
  data.frame(time = time, contraction = y, probability = p,
             naive = ifelse(ok, mean(y[ok]), NA_real_))
}

# Recursive out-of-sample logit (F-07): the forecast for t uses the pairs
# (x_s, y_s) with s <= t - max(h, 1), which are known at t - h when x_t is
# (for h = 0, the state of t itself is unknown), and starts after `start`
# of the usable observations. `naive` is the share of contractions in the
# same training sample.
recursive_logit <- function(y, x, h, start = 0.4) {
  n <- length(y)
  p <- naive <- rep(NA_real_, n)
  ok <- which(!is.na(x) & !is.na(y))
  if (length(ok) < 20L) return(list(probability = p, naive = naive))
  t0 <- ok[ceiling(start * length(ok))]
  gap <- max(as.integer(h), 1L)
  for (t in ok[ok > t0]) {
    train <- ok[ok <= t - gap]
    if (length(train) < 10L || length(unique(y[train])) < 2L) next
    fit <- suppressWarnings(stats::glm.fit(cbind(1, x[train]), y[train],
                                           family = stats::binomial()))
    p[t] <- stats::plogis(sum(fit$coefficients * c(1, x[t])))
    naive[t] <- mean(y[train])
  }
  list(probability = p, naive = naive)
}

#' Probability of contraction implied by a composite
#'
#' Fits the logit model used by [cli_validate()]: the reference contraction
#' state (1 between a peak and the next trough) at time \eqn{t} on the change
#' of the composite over the quarter ending at \eqn{t - h}, recursively out
#' of sample by default (see [cli_validate()]). `roc_curve()` turns the
#' probabilities into the points of the ROC curve.
#'
#' @param composite A [CompositeIndex-class].
#' @param reference The reference [CycleSeries-class].
#' @param spec A [CliSpec-class].
#' @param horizon Lead \eqn{h} in periods; `NULL` uses the horizon of
#'   [cli_validate()] (`spec@horizon`, or the lower end of
#'   `spec@target_lead`).
#' @param recursive `TRUE` for out-of-sample probabilities, each from a model
#'   fitted to earlier periods only; `FALSE` for the fitted values of one
#'   model estimated on the whole sample (rcli 0.5.1).
#' @return `contraction_probability()`: a data frame with `time`,
#'   `contraction` (0/1), `probability` (`NA` where the model cannot be
#'   evaluated, and before the first recursive forecast) and `naive` (the
#'   share of contraction periods in the same estimation sample), or `NULL`
#'   when there are too few observations.
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
                                    horizon = NULL, recursive = TRUE) {
  if (!is(composite, "CompositeIndex") || !is(reference, "CycleSeries")) {
    rcli_abort("Supply a CompositeIndex and the reference CycleSeries.",
               "rcli_error_argument")
  }
  ref_tp <- date_turning_points(spec@dater, reference@normalised,
                                name = reference@name)
  if (is.null(horizon)) horizon <- validation_horizon(spec)
  contraction_fit(as.numeric(composite@cycle), ref_tp, horizon,
                  span = max(1, spec@freq / 4), recursive = recursive)
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

# Pesaran and Timmermann (2009), regression form: the sign of the reference
# change on the sign of the composite change h periods earlier, with the
# fixed-b HAC test of F-06. `stat` is the share of agreeing signs minus its
# value under independence (as in Pesaran and Timmermann 1992).
pesaran_timmermann <- function(cli, ref, h) {
  dx <- shift_vec(c(NA, diff(cli)), as.integer(h))
  dy <- c(NA, diff(ref))
  ok <- !is.na(dx) & !is.na(dy) & dx != 0 & dy != 0
  if (sum(ok) < 20L) return(list(stat = NA_real_, p_value = NA_real_))
  x <- as.numeric(dx[ok] > 0)
  y <- as.numeric(dy[ok] > 0)
  px <- mean(x)
  py <- mean(y)
  stat <- mean(x == y) - (px * py + (1 - px) * (1 - py))
  list(stat = stat, p_value = hac_fixed_b_p(y, x))
}
