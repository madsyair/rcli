#' Classification rules
#'
#' A `Classifier` decides, from the statistics computed by [cli_assess()],
#' whether a candidate (or the composite, in [cli_validate()]) is leading,
#' coincident, lagging or rejected.
#'
#' * `rcli_classifier()`: the default of the package. A series is leading
#'   when it meets every criterion listed in [cli_assess()]: at least three
#'   matched turning points, a positive cross-correlation peak at a lead of
#'   at least `min_lead`, a median lead of at least `min_median_lead`,
#'   consistency, few missed and extra turning points, significant
#'   concordance and Granger causality. The thresholds are the fields of the
#'   [CliSpec-class] and were calibrated by Monte Carlo simulation.
#' * `oecd_classifier()`: the OECD rule (Gyomai and Guidetti 2012, p. 9),
#'   which uses only the median lead at turning points: coincident within
#'   +/- `coincident` months, leading from `coincident` months on ("shorter
#'   or medium" up to `long` months, "longer" beyond) and lagging at
#'   `-coincident` months or less. Thresholds are given in months and
#'   converted to quarters for quarterly data. The OECD sets no minimum
#'   number of turning points; `min_matched` (default 3) is the smallest
#'   number of matched turning points from which a median lead is computed,
#'   set it to 1 to follow the OECD table literally. With `conformity =
#'   TRUE` (the default since 0.6.0) the OECD evaluation criteria of cyclical
#'   conformity and missing or extra cycles (Gyomai and Guidetti 2012, p. 8)
#'   are required as well: a positive cross-correlation peak, at most
#'   `max_missed` missed and `max_extra` extra turning points, and a
#'   concordance significantly above its value under independence. Without
#'   them the median lead alone labels about half of all independent cycles
#'   as leading; with them about one in ten (monthly) to one in five
#'   (quarterly) in the simulations of `inst/calibration/lead-window.csv`,
#'   since the OECD rule has no test of predictive content such as the
#'   Granger test of [rcli_classifier()] (0 to 3 percent). `conformity =
#'   FALSE` gives the rule of rcli 0.5.1; the other statistics are then
#'   reported for judgement only.
#'
#' New rules are added by defining a subclass of `Classifier` and methods
#' for the generics `classify_candidate()` and `leading_criteria()`.
#'
#' @param coincident Half-width, in months, of the coincident band (OECD: 2).
#' @param long Lead, in months, above which a leading series is "longer
#'   leading" (OECD: 8).
#' @param min_matched Minimum number of matched turning points.
#' @param conformity Require cyclical conformity and few missed or extra
#'   cycles (see above).
#' @return A `Classifier` object.
#' @references
#' Gyomai, G. and Guidetti, E. (2012). *OECD System of Composite Leading
#' Indicators*. OECD Publishing, Paris.
#' @seealso [cli_spec()], [oecd_spec()], [cli_assess()]
#' @examples
#' rcli_classifier()
#' oecd_classifier()
#' cli_spec(classifier = oecd_classifier())
#' @name Classifier-class
#' @aliases Classifier
#' @exportClass Classifier
NULL

setClass("Classifier", representation("VIRTUAL", label = "character"))

#' @rdname Classifier-class
setClass("RcliClassifier", contains = "Classifier")

#' @rdname Classifier-class
setClass("OecdClassifier", contains = "Classifier",
         representation(coincident = "numeric", long = "numeric",
                        min_matched = "numeric", conformity = "logical"))

#' @rdname Classifier-class
#' @export
rcli_classifier <- function() {
  new("RcliClassifier",
      label = "rcli: cross-correlation, turning points, concordance, Granger")
}

#' @rdname Classifier-class
#' @export
oecd_classifier <- function(coincident = 2, long = 8, min_matched = 3,
                            conformity = TRUE) {
  check_number(coincident, "coincident", lower = 0)
  check_number(long, "long", lower = 0)
  check_number(min_matched, "min_matched", lower = 1)
  if (long < coincident) {
    rcli_abort("`long` must be at least `coincident`.", "rcli_error_argument")
  }
  if (!is.logical(conformity) || length(conformity) != 1L ||
      is.na(conformity)) {
    rcli_abort("`conformity` must be TRUE or FALSE.", "rcli_error_argument")
  }
  label <- if (conformity) {
    "OECD: median lead at turning points, cyclical conformity"
  } else {
    "OECD: median lead at turning points"
  }
  new("OecdClassifier", label = label,
      coincident = as.numeric(coincident), long = as.numeric(long),
      min_matched = as.numeric(min_matched), conformity = conformity)
}

# Conformity setting of an OECD classifier; classifiers saved before 0.6.0
# have none and keep the rule they were created with.
oecd_conformity <- function(classifier) {
  methods::.hasSlot(classifier, "conformity") &&
    isTRUE(classifier@conformity)
}

#' @rdname Classifier-class
#' @param classifier A `Classifier`.
#' @param row One-row data frame of statistics from [cli_assess()].
#' @param spec A [CliSpec-class].
#' @export
setGeneric("classify_candidate", function(classifier, row, spec) {
  standardGeneric("classify_candidate")
})

#' @rdname Classifier-class
#' @export
setGeneric("leading_criteria", function(classifier, row, spec) {
  standardGeneric("leading_criteria")
})

#' @rdname Classifier-class
#' @param object An object to print.
setMethod("show", "Classifier", function(object) {
  cat("<", class(object), "> ", object@label, "\n", sep = "")
  invisible(object)
})

#' @rdname Classifier-class
setMethod("show", "OecdClassifier", function(object) {
  cat("<OecdClassifier> ", object@label, "\n", sep = "")
  cat("  coincident within +/- ", object@coincident, " months; leading from ",
      object@coincident, " months (longer over ", object@long,
      "); lagging at -", object@coincident, " months or less; at least ",
      object@min_matched, " matched turning points",
      if (oecd_conformity(object)) {
        "; cyclical conformity and few missed or extra cycles"
      }, "\n", sep = "")
  invisible(object)
})

# Half-width, in periods, of the timing band of a coincident index, and the
# texts of the scorecard rules that depend on the classifier. Internal
# generics, so that a classifier sets its own band without branches here.
setGeneric("timing_band", function(classifier, spec) {
  standardGeneric("timing_band")
})
setMethod("timing_band", "Classifier", function(classifier, spec) {
  max(2 * spec@freq / 12, 1)
})
setMethod("timing_band", "OecdClassifier", function(classifier, spec) {
  oecd_band(classifier, spec)[["coincident"]]
})

# TRUE where a lead lies in the timing band: inclusive by default, strict for
# the OECD classifier (its coincident band is an open interval).
setGeneric("in_timing_band", function(classifier, lead, band) {
  standardGeneric("in_timing_band")
})
setMethod("in_timing_band", "Classifier", function(classifier, lead, band) {
  abs(lead) <= band
})
setMethod("in_timing_band", "OecdClassifier", function(classifier, lead,
                                                       band) {
  abs(lead) < band
})

setGeneric("timing_rules", function(classifier, band) {
  standardGeneric("timing_rules")
})
setMethod("timing_rules", "Classifier", function(classifier, band) {
  list(matched = ">= 3", timing = sprintf("within +/- %s", band))
})
setMethod("timing_rules", "OecdClassifier", function(classifier, band) {
  list(matched = sprintf(">= %s", classifier@min_matched),
       timing = sprintf("within (-%s, %s)", band, band))
})
