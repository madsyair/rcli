#' The three OECD forms of a composite leading indicator
#'
#' Returns the forms in which the OECD presents a CLI (Gyomai and Guidetti
#' 2012, p. 9--11), next to the matching forms of the reference series:
#'
#' * **amplitude adjusted**: the composite cycle rescaled to the amplitude
#'   of the de-trended reference series around 100 (the `index` of the
#'   composite for every aggregation method except the Conference Board's);
#'   compared with the de-trended reference series it reads as an output
#'   gap ("growth cycle");
#' * **trend restored**: the long-term trend of the reference series times
#'   the amplitude-adjusted CLI divided by 100, comparable with the level of
#'   the reference series ("business cycle"). The trend is the Hodrick-Prescott
#'   trend with the cut-off of the specification's double HP filter (120
#'   months by default), taken from the transformed reference series and
#'   extended linearly beyond the last reference observation;
#' * **12-month rate of change** of the trend-restored CLI (4 quarters for
#'   quarterly data), comparable with the year-on-year growth of the
#'   reference ("growth rate cycle").
#'
#' For a reference that is not logged (for instance a balance that crosses
#' zero), deviations are measured in percent of the mean absolute level, as
#' in the amplitude of the composite, and the trend is restored by adding
#' them to the trend rather than by multiplying.
#'
#' With a growth rate or acceleration form ([growth_form()],
#' [acceleration_form()]), the reference is its rate and the amplitude of
#' the composite is in percentage points (the units of the rate):
#' `amplitude_adjusted` and `reference_amplitude_adjusted` are 100 plus the
#' deviation in percentage points, `trend_restored` and `reference_trend`
#' are the mean rate of the reference plus that deviation and the mean rate
#' itself, and the two rate-of-change columns are `NA`.
#'
#' The reference series in the output is the transformed one: seasonally
#' adjusted and cleaned of outliers as in the specification, in the units
#' of the original data, so that neither seasonality nor spikes enter the
#' comparison.
#'
#' Peaks and troughs differ between forms: trend restoration moves peaks
#' later and troughs earlier, and peaks of the rate of change mark
#' inflection points of the amplitude-adjusted series, so the forms should
#' not be mixed when reading signals.
#'
#' @param x A [CliResult-class] with a composite.
#' @param composite Optional [CompositeIndex-class] presented instead of the
#'   composite of `x`, for instance one chosen by hand with
#'   [cli_composite()] from `cycles(x)`.
#' @return A data frame with `time` and the columns `amplitude_adjusted`,
#'   `trend_restored`, `rate_of_change`, `reference` (seasonally adjusted
#'   and cleaned of outliers),
#'   `reference_amplitude_adjusted` (the reference without trend, in the
#'   units of `amplitude_adjusted`), `reference_trend` and
#'   `reference_rate_of_change`.
#' @references
#' Gyomai, G. and Guidetti, E. (2012). *OECD System of Composite Leading
#' Indicators*. OECD Publishing, Paris.
#' @examples
#' sim <- simulate_cycles(seed = 1)
#' meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
#' res <- cli_build(cli_candidates(sim, "reference", meta = meta))
#' pr <- cli_presentation(res)
#' tail(pr)
#' @export
cli_presentation <- function(x, composite = NULL) {
  if (!is(x, "CliResult")) {
    rcli_abort("`x` must be a CliResult (see cli_build()).",
               "rcli_error_argument")
  }
  if (!is.null(composite) && !is(composite, "CompositeIndex")) {
    rcli_abort("`composite` must be a CompositeIndex (see cli_composite()).",
               "rcli_error_argument")
  }
  comp <- if (is.null(composite)) x@composite else composite
  if (is.null(comp)) {
    rcli_abort("`x` must be a CliResult with a composite (see cli_build()).",
               "rcli_error_argument")
  }
  ref <- x@cycles[[x@candidates@reference]]
  f <- stats::frequency(comp@cycle)
  amp_adj <- 100 + as.numeric(comp@cycle) * comp@amplitude
  if (form_units(ref) != "level") return(rate_presentation(comp, ref, amp_adj))
  logged <- is_logged(ref)
  trend <- reference_trend(ref, x@spec)
  trend_level <- if (logged) exp(trend) else trend
  # the reference as seasonally adjusted and cleaned of outliers, so that
  # neither seasonality nor spikes enter the comparison
  orig <- cycle_level(ref)
  if (logged) {
    # percent deviation from trend, as the amplitude of a logged reference
    tr <- trend_level * amp_adj / 100
    ref_amp <- 100 * orig / trend_level
  } else {
    # deviation from trend in percent of the mean level, as the amplitude
    # of a reference that is not logged (it may cross zero)
    scale <- mean(abs(as.numeric(ref@transformed)), na.rm = TRUE)
    tr <- trend_level + (amp_adj - 100) / 100 * scale
    ref_amp <- 100 + 100 * (orig - trend_level) / scale
  }
  data.frame(
    time = as.numeric(stats::time(comp@cycle)),
    amplitude_adjusted = amp_adj,
    trend_restored = tr,
    rate_of_change = rate_of_change(tr, f),
    reference = orig,
    reference_amplitude_adjusted = ref_amp,
    reference_trend = trend_level,
    reference_rate_of_change = rate_of_change(orig, f)
  )
}

# Growth rate and acceleration forms: the composite amplitude is in the
# units of the reference rate (percentage points), so the composite is
# shown around the mean rate of the reference; a rate of change of a rate
# is not defined.
rate_presentation <- function(comp, ref, amp_adj) {
  orig <- as.numeric(ref@transformed)
  centre <- rep(mean(orig, na.rm = TRUE), length(orig))
  na <- rep(NA_real_, length(orig))
  data.frame(
    time = as.numeric(stats::time(comp@cycle)),
    amplitude_adjusted = amp_adj,
    trend_restored = centre + amp_adj - 100,
    rate_of_change = na,
    reference = orig,
    reference_amplitude_adjusted = 100 + orig - centre,
    reference_trend = centre,
    reference_rate_of_change = na
  )
}

is_logged <- function(cs) {
  any(grepl("^log", cs@steps)) && identical(form_units(cs), "level")
}

# Level of the transformed series of a CycleSeries: seasonally adjusted and
# cleaned of outliers, in the units of the original data.
cycle_level <- function(cs) {
  v <- as.numeric(cs@transformed)
  if (is_logged(cs)) exp(v) else v
}

rate_of_change <- function(v, lag) {
  prev <- shift_vec(v, as.integer(lag))
  if (all(v > 0, na.rm = TRUE)) 100 * (v / prev - 1) else v - prev
}

# Long-term HP trend of the transformed reference, extended linearly.
reference_trend <- function(ref, spec) {
  f <- spec@freq
  tp <- if (methods::.hasSlot(spec@filter, "trend_period") &&
              !is.na(spec@filter@trend_period)) {
    spec@filter@trend_period
  } else {
    10 * f
  }
  v <- as.numeric(ref@transformed)
  span <- non_na_span(v)
  out <- rep(NA_real_, length(v))
  core <- v[span[1]:span[2]]
  tr <- hp_trend_core(core, hp_lambda(tp))
  out[span[1]:span[2]] <- tr
  m <- length(tr)
  if (span[2] < length(v)) {
    slope <- tr[m] - tr[m - 1L]
    out[(span[2] + 1L):length(v)] <- tr[m] + slope *
      seq_len(length(v) - span[2])
  }
  if (span[1] > 1L) {
    slope <- tr[2] - tr[1]
    out[1:(span[1] - 1L)] <- tr[1] - slope * rev(seq_len(span[1] - 1L))
  }
  out
}
