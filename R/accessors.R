#' Extract parts of the workflow results
#'
#' * `leaders()`: names of the candidates classified as leading.
#' * `components()`: components of the final composite.
#' * `audit_log()`: the iterations of the selection loop.
#' * `assessment()`, `composite()`, `validation()`, `cycles()`,
#'   `turning_points()`: the stored objects.
#'
#' @param x A [CliResult-class] (or a [LeadAssessment-class] for
#'   `leaders()`, a [CompositeIndex-class] for `components()`).
#' @param ... Unused.
#' @return See Description.
#' @examples
#' sim <- simulate_cycles(seed = 1)
#' meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
#' res <- cli_build(cli_candidates(sim, "reference", meta = meta))
#' leaders(res)
#' components(res)
#' audit_log(res)
#' @name accessors
NULL

#' @rdname accessors
#' @export
setGeneric("leaders", function(x, ...) standardGeneric("leaders"))

#' @rdname accessors
setMethod("leaders", "LeadAssessment", function(x, ...) {
  x@table$name[x@table$class == "leading"]
})

#' @rdname accessors
setMethod("leaders", "CliResult", function(x, ...) leaders(x@assessment))

#' @rdname accessors
#' @export
setGeneric("components", function(x, ...) standardGeneric("components"))

#' @rdname accessors
setMethod("components", "CompositeIndex", function(x, ...) x@components)

#' @rdname accessors
setMethod("components", "CliResult", function(x, ...) {
  if (is.null(x@composite)) character(0) else x@composite@components
})

#' @rdname accessors
#' @export
setGeneric("audit_log", function(x, ...) standardGeneric("audit_log"))

#' @rdname accessors
setMethod("audit_log", "CliResult", function(x, ...) x@audit)

#' @rdname accessors
#' @export
setGeneric("assessment", function(x, ...) standardGeneric("assessment"))

#' @rdname accessors
setMethod("assessment", "CliResult", function(x, ...) x@assessment)

#' @rdname accessors
#' @export
setGeneric("composite", function(x, ...) standardGeneric("composite"))

#' @rdname accessors
setMethod("composite", "CliResult", function(x, ...) x@composite)

#' @rdname accessors
#' @export
setGeneric("validation", function(x, ...) standardGeneric("validation"))

#' @rdname accessors
setMethod("validation", "CliResult", function(x, ...) x@validation)

#' @rdname accessors
#' @export
setGeneric("cycles", function(x, ...) standardGeneric("cycles"))

#' @rdname accessors
setMethod("cycles", "CliResult", function(x, ...) x@cycles)

#' @rdname accessors
#' @export
setGeneric("turning_points", function(x, ...) standardGeneric("turning_points"))

#' @rdname accessors
setMethod("turning_points", "CliResult", function(x, ...) x@turning_points)

#' Convert results to data frames
#'
#' @param x An object of class [TurningPoints-class], [LeadAssessment-class],
#'   [CompositeIndex-class] or [CliValidation-class].
#' @param row.names,optional Ignored.
#' @param ... Unused.
#' @return A data frame. For turning points: `time` (decimal), `period`
#'   (year and month or quarter), `type`, `index` and `value`. For a composite:
#'   `time`, `index` and `cycle`. For a validation: one row combining the
#'   turning-point and probability statistics.
#' @examples
#' x <- ts(sin(2 * pi * (1:120) / 40), frequency = 4, start = 1990)
#' as.data.frame(date_turning_points(bbq(), x))
#' @name as.data.frame
NULL

period_label <- function(time, freq) {
  year <- floor(time + 1e-8)
  sub <- round((time - year) * freq) + 1
  if (freq == 12) sprintf("%d-%02d", year, sub) else sprintf("%dQ%d", year, sub)
}

#' @rdname as.data.frame
#' @export
setMethod("as.data.frame", "TurningPoints",
          function(x, row.names = NULL, optional = FALSE, ...) {
  tm <- as.numeric(stats::time(x@series))[x@index]
  data.frame(time = tm,
             period = period_label(tm, stats::frequency(x@series)),
             type = x@type, index = x@index,
             value = as.numeric(x@series)[x@index], stringsAsFactors = FALSE)
})

#' @rdname as.data.frame
#' @export
setMethod("as.data.frame", "LeadAssessment",
          function(x, row.names = NULL, optional = FALSE, ...) x@table)

#' @rdname as.data.frame
#' @export
setMethod("as.data.frame", "CompositeIndex",
          function(x, row.names = NULL, optional = FALSE, ...) {
  data.frame(time = as.numeric(stats::time(x@index)),
             index = as.numeric(x@index), cycle = as.numeric(x@cycle))
})

#' @rdname as.data.frame
#' @export
setMethod("as.data.frame", "CliValidation",
          function(x, row.names = NULL, optional = FALSE, ...) {
  cbind(x@turning_points, x@probability, passed = x@passed)
})
