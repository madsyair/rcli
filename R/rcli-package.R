#' rcli: composite leading indicators from component selection to validation
#'
#' `rcli` implements the full workflow for building a composite leading
#' indicator (CLI):
#'
#' 1. collect a reference series and candidate series ([cli_candidates()]),
#'    after bringing series of mixed frequencies and types to one frequency
#'    ([cli_align()]);
#' 2. configure every step in one specification object ([cli_spec()]);
#' 3. extract cycles ([cli_cycles()]) with a [CycleFilter-class];
#' 4. date turning points ([cli_turning_points()]) with a [Dater-class];
#' 5. classify candidates as leading, coincident, lagging or rejected
#'    ([cli_assess()]);
#' 6. aggregate the leading components ([cli_composite()]) with an
#'    [Aggregator-class];
#' 7. test the composite ([cli_validate()], [cli_selection_bias()]);
#' 8. re-select components until the composite passes ([cli_build()]).
#'
#' [cli_build()] runs steps 3 to 8 and returns a [CliResult-class] that keeps
#' every intermediate object and an audit trail of selection decisions
#' ([audit_log()]).
#'
#' @references
#' Gyomai, G. and Guidetti, E. (2012). *OECD System of Composite Leading
#' Indicators*. OECD Publishing, Paris.
#'
#' Marcellino, M. (2006). Leading indicators. In G. Elliott, C. W. J. Granger
#' and A. Timmermann (eds.), *Handbook of Economic Forecasting*, Vol. 1,
#' 879--960. \doi{10.1016/S1574-0706(05)01016-5}
#'
#' @keywords internal
#' @importFrom methods new validObject is slot slot<- slotNames setClass
#'   setGeneric setMethod setValidity show
#' @importFrom stats ts start end frequency time window lm lm.fit coef median
#'   sd cor pf pnorm na.omit tsp tsp<- quantile mad approx glm binomial
#'   fitted var arima.sim rnorm update setNames complete.cases prcomp
#' @importFrom graphics plot lines abline legend par points
#' @importFrom grDevices adjustcolor
#' @importFrom utils head tail
"_PACKAGE"
