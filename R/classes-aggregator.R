#' Aggregation methods
#'
#' An `Aggregator` combines the normalised cycles of the selected leading
#' components into one composite cycle.
#'
#' * `equal_weight()`: the default. At each date the composite is the mean
#'   of the normalised cycles of the available components; dates with less
#'   than `min_coverage` of the components available are missing (the OECD
#'   uses 60 percent).
#' * `oecd_aggregate()`: the OECD procedure (Gyomai and Guidetti 2012,
#'   p. 9). Each component is the normalised cycle plus 100; at each date
#'   the growth rates of the available components are averaged with equal
#'   weights and the average growth is chained into the index, which starts
#'   at the mean level of the components. A date is computed only when at
#'   least `min_coverage` of the components are available; after a gap the
#'   chain restarts at the mean level of the available components. When
#'   all components are observed, the result moves almost exactly like
#'   the equal-weight mean; it differs at the ragged edge, where a missing
#'   component changes the average growth instead of the average level.
#' * `principal_component()`: weights proportional to the loadings of the
#'   first principal component of the components over their common sample,
#'   in the spirit of the targeted-predictor approach (Bai and Ng 2008)
#'   used for the Global Economic Barometers (Abberger et al. 2022); the
#'   components entering the PCA are the ones that passed the screening.
#' * `conference_board()`: The Conference Board method. Symmetric
#'   percentage changes of the original components (simple differences for
#'   series that are not strictly positive) are weighted by the inverse of
#'   their standard deviations, summed and cumulated into an index. The cycle
#'   of that index is then extracted with the specification's filter.
#' * `dynamic_factor()`: a one-factor dynamic factor model estimated in two
#'   steps (Doz, Giannone and Reichlin 2011): principal components give the
#'   loadings and idiosyncratic variances, an AR(1) is fitted to the factor,
#'   and a Kalman smoother with missing data returns the factor. Ragged edges
#'   are handled by the smoother.
#'
#' New methods are added by defining a subclass of `Aggregator` and a method
#' for the generic `aggregate_components()` (see [cli_composite()]).
#'
#' @param min_coverage Minimum share of components that must be observed at a
#'   date for the composite to be computed.
#' @return An `Aggregator` object.
#' @references
#' Abberger, K., Graff, M., Müller, O. and Sturm, J.-E. (2022). Composite
#' global indicators from survey data: the Global Economic Barometers.
#' *Review of World Economics*, 158, 917--945.
#' \doi{10.1007/s10290-021-00449-8}
#'
#' Bai, J. and Ng, S. (2008). Forecasting economic time series using targeted
#' predictors. *Journal of Econometrics*, 146(2), 304--317.
#'
#' Doz, C., Giannone, D. and Reichlin, L. (2011). A two-step estimator for
#' large approximate dynamic factor models based on Kalman filtering.
#' *Journal of Econometrics*, 164(1), 188--205.
#'
#' Gyomai, G. and Guidetti, E. (2012). *OECD System of Composite Leading
#' Indicators*. OECD Publishing, Paris.
#'
#' The Conference Board (2001). *Business Cycle Indicators Handbook*.
#' The Conference Board, New York.
#' @seealso [cli_composite()], [cli_spec()]
#' @examples
#' equal_weight()
#' oecd_aggregate()
#' dynamic_factor(min_coverage = 0.5)
#' @name Aggregator-class
#' @aliases Aggregator
#' @exportClass Aggregator
NULL

setClass("Aggregator", representation("VIRTUAL", label = "character",
                                      min_coverage = "numeric"))

#' @rdname Aggregator-class
setClass("EqualWeight", contains = "Aggregator")

#' @rdname Aggregator-class
setClass("OecdAggregate", contains = "Aggregator")

#' @rdname Aggregator-class
setClass("PrincipalComponent", contains = "Aggregator")

#' @rdname Aggregator-class
setClass("ConferenceBoard", contains = "Aggregator")

#' @rdname Aggregator-class
setClass("DynamicFactor", contains = "Aggregator")

new_aggregator <- function(class, label, min_coverage) {
  check_number(min_coverage, "min_coverage", lower = 0, upper = 1)
  new(class, label = label, min_coverage = min_coverage)
}

#' @rdname Aggregator-class
#' @export
equal_weight <- function(min_coverage = 0.6) {
  new_aggregator("EqualWeight", "Equal weights", min_coverage)
}

#' @rdname Aggregator-class
#' @export
oecd_aggregate <- function(min_coverage = 0.6) {
  new_aggregator("OecdAggregate", "Chained average growth (OECD)",
                 min_coverage)
}

#' @rdname Aggregator-class
#' @export
principal_component <- function(min_coverage = 0.6) {
  new_aggregator("PrincipalComponent", "First principal component",
                 min_coverage)
}

#' @rdname Aggregator-class
#' @export
conference_board <- function(min_coverage = 0.6) {
  new_aggregator("ConferenceBoard", "Conference Board standardisation",
                 min_coverage)
}

#' @rdname Aggregator-class
#' @export
dynamic_factor <- function(min_coverage = 0.6) {
  new_aggregator("DynamicFactor", "Dynamic factor model (two-step)",
                 min_coverage)
}

# Generic for aggregation methods. `z` is a matrix of normalised component
# cycles (columns), `levels` a matrix of the original components (same
# columns, attributes `sign` and `tsp`), `spec` the CliSpec. Methods return
# list(cycle = numeric, index = numeric or NULL, weights = named numeric).

#' @rdname cli_composite
#' @export
setGeneric("aggregate_components", function(aggregator, z, levels, spec) {
  standardGeneric("aggregate_components")
})
