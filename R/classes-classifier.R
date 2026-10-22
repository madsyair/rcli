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
#'   set it to 1 to follow the OECD table literally. The other statistics
#'   (mean lead and its standard deviation, cross-correlation peak, missed
#'   and extra turning points) are reported for judgement, as in the OECD
#'   evaluation step, but do not enter the class.
#'
#' New rules are added by defining a subclass of `Classifier` and methods
#' for the generics `classify_candidate()` and `leading_criteria()`.
#'
#' @param coincident Half-width, in months, of the coincident band (OECD: 2).
#' @param long Lead, in months, above which a leading series is "longer
#'   leading" (OECD: 8).
#' @param min_matched Minimum number of matched turning points.
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
                        min_matched = "numeric"))

#' @rdname Classifier-class
#' @export
rcli_classifier <- function() {
  new("RcliClassifier",
      label = "rcli: cross-correlation, turning points, concordance, Granger")
}

#' @rdname Classifier-class
#' @export
oecd_classifier <- function(coincident = 2, long = 8, min_matched = 3) {
  check_number(coincident, "coincident", lower = 0)
  check_number(long, "long", lower = 0)
  check_number(min_matched, "min_matched", lower = 1)
  if (long < coincident) {
    rcli_abort("`long` must be at least `coincident`.", "rcli_error_argument")
  }
  new("OecdClassifier", label = "OECD: median lead at turning points",
      coincident = as.numeric(coincident), long = as.numeric(long),
      min_matched = as.numeric(min_matched))
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
      object@min_matched, " matched turning points\n", sep = "")
  invisible(object)
})
