# Core S4 classes of the workflow. Constructors live next to the code that
# fills each class (spec.R, candidates.R, cycles.R, ...).

#' Specification of a CLI workflow
#'
#' A `CliSpec` collects every choice of the workflow: the filter, the
#' turning-point rules, the classification thresholds, the aggregation method
#' and the stopping rules of the selection loop. Create it with [cli_spec()]
#' and change it with `update()`.
#'
#' @slot freq Data frequency, 4 or 12.
#' @slot filter A [CycleFilter-class].
#' @slot dater A [Dater-class].
#' @slot aggregator An [Aggregator-class].
#' @slot transform `"auto"`, `"log"` or `"none"`.
#' @slot seasonal_adjust Logical; X-13ARIMA-SEATS through \pkg{seasonal}.
#' @slot outlier_threshold Robust z-score above which a change is treated as
#'   an outlier and replaced by interpolation (`Inf` disables).
#' @slot min_lead Minimum lead (periods) of the cross-correlation peak.
#' @slot min_median_lead Minimum median lead at turning points.
#' @slot min_consistency Minimum share of reference turning points led.
#' @slot max_missed,max_extra Maximum shares of missed and extra turning
#'   points relative to the reference turning points.
#' @slot coincident_band Largest absolute cross-correlation lag of a
#'   coincident series.
#' @slot min_auc Minimum area under the ROC curve of a good composite.
#' @slot target_lead Lead range (periods) the OECD aims at; reported for
#'   information.
#' @slot lead_window Matching window `c(max_lag, max_lead)` in periods.
#' @slot ccf_lag_max Largest lag of the cross-correlation search.
#' @slot alpha Significance level of the concordance and Granger tests.
#' @slot granger_max_lag,granger_dmax Lag order bound and extra lags of the
#'   Toda-Yamamoto test.
#' @slot max_iter,min_components Stopping rules of the selection loop.
#' @slot horizon Forecast horizon of the probability tests (`NA`: the
#'   composite's median lead).
#' @slot oos_cutoffs Cut-off dates (decimal time) for the selection-bias
#'   harness; empty to skip it.
#' @slot holidays List of [holiday_effect()] objects removed during seasonal
#'   adjustment.
#' @slot classifier A [Classifier-class]: the rule that labels series
#'   leading, coincident, lagging or rejected.
#' @slot outliers An [OutlierTreatment-class].
#' @slot lag_shift Logical; shift the components so that their median leads
#'   align before aggregation (OECD lag-shifting)?
#' @slot extension An [Extension-class]: forecasts appended to each series
#'   before the cycle filter.
#' @seealso [cli_spec()]
#' @exportClass CliSpec
setClass("CliSpec", representation(
  freq = "numeric", filter = "CycleFilter", dater = "Dater",
  aggregator = "Aggregator", transform = "character",
  seasonal_adjust = "logical", outlier_threshold = "numeric",
  min_lead = "numeric", min_median_lead = "numeric",
  min_consistency = "numeric", max_missed = "numeric",
  max_extra = "numeric", coincident_band = "numeric", min_auc = "numeric",
  target_lead = "numeric",
  lead_window = "numeric", ccf_lag_max = "numeric", alpha = "numeric",
  granger_max_lag = "numeric", granger_dmax = "numeric",
  max_iter = "numeric", min_components = "numeric", horizon = "numeric",
  oos_cutoffs = "numeric", holidays = "list", classifier = "Classifier",
  outliers = "OutlierTreatment", lag_shift = "logical",
  extension = "Extension"
), prototype(holidays = list(), classifier = rcli_classifier(),
             outliers = robust_outliers(5), lag_shift = FALSE,
             extension = no_extension()))

#' Reference and candidate series
#'
#' @slot data A multivariate `ts`; one column is the reference series.
#' @slot reference Name of the reference column.
#' @slot meta Data frame of pre-selection metadata, one row per candidate:
#'   `name`, `rationale` (OECD economic rationale), `source`, `release_lag`,
#'   `type` (`"flow"`, `"stock"` or `"average"`, see [series_types]).
#' @slot vintages Named list of earlier data releases (each a `ts` matrix
#'   like `data`), kept for real-time evaluation.
#' @slot alignment Data frame describing how each series was brought to the
#'   common frequency by [cli_align()] (`name`, `from`, `type`, `method`);
#'   empty when the data came in at one frequency.
#' @seealso [cli_candidates()]
#' @exportClass CandidateSet
setClass("CandidateSet", representation(
  data = "ts", reference = "character", meta = "data.frame",
  vintages = "list", alignment = "data.frame"
), prototype(alignment = data.frame()))

#' Cyclical component of one series
#'
#' @slot name Series name.
#' @slot original Original series (`ts`).
#' @slot transformed Series after transformation, outlier treatment and
#'   seasonal adjustment (`ts`).
#' @slot cycle Filtered cycle (`ts`).
#' @slot normalised Normalised cycle (mean 0, mean absolute deviation 1).
#' @slot steps Character log of the transformations applied.
#' @seealso [cli_cycles()]
#' @exportClass CycleSeries
setClass("CycleSeries", representation(
  name = "character", original = "ts", transformed = "ts", cycle = "ts",
  normalised = "ts", steps = "character"
))

#' Classification of candidate series
#'
#' @slot table Data frame with one row per candidate: lead statistics at
#'   turning points, cross-correlation, concordance, Granger test, class and
#'   reasons.
#' @slot matches Named list of data frames pairing reference and candidate
#'   turning points.
#' @slot inverted Names of counter-cyclical candidates, inverted relative to
#'   their original series.
#' @seealso [cli_assess()]
#' @exportClass LeadAssessment
setClass("LeadAssessment", representation(
  table = "data.frame", matches = "list", inverted = "character"
))

#' Composite index
#'
#' @slot index Composite leading indicator (`ts`, long-term average 100).
#' @slot cycle Normalised composite cycle used for evaluation (`ts`).
#' @slot components Names of the components.
#' @slot weights Weights of the components.
#' @slot aggregator The [Aggregator-class] used.
#' @slot amplitude Amplitude factor matching the reference cycle.
#' @slot shifts Named periods by which each component was moved later
#'   (lag-shifting); empty when the components were not shifted.
#' @seealso [cli_composite()]
#' @exportClass CompositeIndex
setClass("CompositeIndex", representation(
  index = "ts", cycle = "ts", components = "character", weights = "numeric",
  aggregator = "Aggregator", amplitude = "numeric", shifts = "numeric"
), prototype(shifts = numeric(0)))

#' Validation of a composite index
#'
#' @slot turning_points One-row data frame of turning-point statistics.
#' @slot probability One-row data frame with the `horizon`, the quadratic
#'   probability score `qps` and its naive counterpart `qps_naive`, the area
#'   under the ROC curve `auc`, the number of out-of-sample forecasts
#'   `n_forecasts`, and the Pesaran-Timmermann directional test: `pt_stat`,
#'   the share of agreeing signs minus its value under independence (since
#'   0.6.0; earlier the z statistic of the 1992 test), and its one-sided
#'   fixed-b p-value `pt_p`.
#' @slot out_of_sample Results of [cli_selection_bias()] (may be empty).
#' @slot passed Logical; did the composite meet the leading criteria?
#' @slot failed Criteria that were not met.
#' @slot quality The [CliQuality-class] scorecard.
#' @slot role `"leading"` for a composite leading indicator ([cli_validate()])
#'   or `"coincident"` for a coincident index ([cci_validate()]); it decides
#'   which criteria the scorecard applies.
#' @seealso [cli_validate()], [cci_validate()], [cli_quality()]
#' @exportClass CliValidation
setClass("CliValidation", representation(
  turning_points = "data.frame", probability = "data.frame",
  out_of_sample = "data.frame", passed = "logical", failed = "character",
  quality = "ANY", role = "character"
), prototype(role = "leading"))

# Role of a validation (objects saved before 0.1.4 have no role slot).
validation_role <- function(x) {
  if (methods::.hasSlot(x, "role") && length(x@role) == 1L) x@role else
    "leading"
}

#' Quality scorecard of a composite leading indicator
#'
#' @slot table Data frame with one row per criterion: `group`
#'   (`"turning points"`, `"prediction"`, `"out of sample"`, `"information"`),
#'   `criterion`, `value`, `threshold` and `passed` (`NA` for information).
#' @slot verdict `"good"`, `"acceptable"` or `"weak"`.
#' @slot note One-sentence explanation of the verdict.
#' @seealso [cli_quality()]
#' @exportClass CliQuality
setClass("CliQuality", representation(
  table = "data.frame", verdict = "character", note = "character"
))

#' Result of the full workflow
#'
#' @slot spec The [CliSpec-class].
#' @slot candidates The [CandidateSet-class].
#' @slot cycles Named list of [CycleSeries-class].
#' @slot turning_points Named list of [TurningPoints-class].
#' @slot assessment The [LeadAssessment-class].
#' @slot composite The final [CompositeIndex-class] (or `NULL` when no
#'   candidate qualifies).
#' @slot validation The final [CliValidation-class] (or `NULL`).
#' @slot audit Data frame recording every iteration of the selection loop.
#' @seealso [cli_build()]
#' @exportClass CliResult
setClass("CliResult", representation(
  spec = "CliSpec", candidates = "CandidateSet", cycles = "list",
  turning_points = "list", assessment = "LeadAssessment",
  composite = "ANY", validation = "ANY", audit = "data.frame"
))

#' Result of the coincident-index workflow
#'
#' A `CciResult` has the slots of a [CliResult-class]; the composite is a
#' coincident index built from the candidates classified as coincident, and
#' its validation has role `"coincident"`. The accessors of `CliResult`
#' ([components()], [composite()], [validation()], [audit_log()],
#' [cycles()], [turning_points()], [assessment()]) and [cli_quality()] work
#' on it.
#'
#' @seealso [cci_build()]
#' @exportClass CciResult
setClass("CciResult", contains = "CliResult")
