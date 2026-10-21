#' Turning-point dating rules
#'
#' A `Dater` holds the censoring rules of a turning-point algorithm. Both
#' built-in daters implement the Bry and Boschan (1971) logic as simplified by
#' Harding and Pagan (2002) and the OECD:
#'
#' 1. a peak (trough) is a local maximum (minimum) within `window`
#'    observations on each side;
#' 2. peaks and troughs must alternate; of two consecutive peaks (troughs) the
#'    higher (lower) is kept;
#' 3. turning points closer than `end_exclusion` observations to either end
#'    are dropped, as are first or last peaks (troughs) lower (higher) than the
#'    end values;
#' 4. a cycle (peak to peak or trough to trough) lasts at least `min_cycle`
#'    observations and a phase at least `min_phase` observations.
#'
#' `bry_boschan()` uses the monthly defaults (window 5, phase 5, cycle 15,
#' end exclusion 6); `bbq()` uses the quarterly defaults of Harding and Pagan
#' (window 2, phase 2, cycle 5, end exclusion 2). Parameters left at `NA`
#' are resolved from the series frequency, so either dater can be applied to
#' monthly or quarterly data.
#'
#' @param window Half-width of the local extremum window.
#' @param min_phase Minimum length of an expansion or contraction.
#' @param min_cycle Minimum length of a full cycle.
#' @param end_exclusion Number of observations at each end in which no turning
#'   point is accepted.
#' @return A `Dater` object.
#' @references
#' Bry, G. and Boschan, C. (1971). *Cyclical Analysis of Time Series: Selected
#' Procedures and Computer Programs*. NBER, New York.
#'
#' Harding, D. and Pagan, A. (2002). Dissecting the cycle: a methodological
#' investigation. *Journal of Monetary Economics*, 49(2), 365--381.
#' @seealso [date_turning_points()]
#' @examples
#' bry_boschan()
#' bbq(min_cycle = 6)
#' @name Dater-class
#' @aliases Dater
#' @exportClass Dater
NULL

setClass("Dater", representation(
  "VIRTUAL", label = "character", window = "numeric", min_phase = "numeric",
  min_cycle = "numeric", end_exclusion = "numeric"
))

#' @rdname Dater-class
setClass("BryBoschan", contains = "Dater")

#' @rdname Dater-class
setClass("BBQ", contains = "Dater")

check_dater_args <- function(window, min_phase, min_cycle, end_exclusion) {
  check_number(window, "window", lower = 1, integer = TRUE, allow_na = TRUE)
  check_number(min_phase, "min_phase", lower = 1, integer = TRUE,
               allow_na = TRUE)
  check_number(min_cycle, "min_cycle", lower = 2, integer = TRUE,
               allow_na = TRUE)
  check_number(end_exclusion, "end_exclusion", lower = 0, integer = TRUE,
               allow_na = TRUE)
}

#' @rdname Dater-class
#' @export
bry_boschan <- function(window = NA, min_phase = NA, min_cycle = NA,
                        end_exclusion = NA) {
  check_dater_args(window, min_phase, min_cycle, end_exclusion)
  new("BryBoschan", label = "Bry-Boschan", window = as.numeric(window),
      min_phase = as.numeric(min_phase), min_cycle = as.numeric(min_cycle),
      end_exclusion = as.numeric(end_exclusion))
}

#' @rdname Dater-class
#' @export
bbq <- function(window = NA, min_phase = NA, min_cycle = NA,
                end_exclusion = NA) {
  check_dater_args(window, min_phase, min_cycle, end_exclusion)
  new("BBQ", label = "Harding-Pagan BBQ", window = as.numeric(window),
      min_phase = as.numeric(min_phase), min_cycle = as.numeric(min_cycle),
      end_exclusion = as.numeric(end_exclusion))
}

# Defaults of the censoring rules, expressed per frequency.
dater_defaults <- function(freq) {
  if (freq == 12) {
    list(window = 5, min_phase = 5, min_cycle = 15, end_exclusion = 6)
  } else {
    list(window = 2, min_phase = 2, min_cycle = 5, end_exclusion = 2)
  }
}

resolve_dater <- function(dater, freq) {
  d <- dater_defaults(freq)
  list(
    window = resolve_default(dater@window, d$window),
    min_phase = resolve_default(dater@min_phase, d$min_phase),
    min_cycle = resolve_default(dater@min_cycle, d$min_cycle),
    end_exclusion = resolve_default(dater@end_exclusion, d$end_exclusion)
  )
}

#' Turning points of a series
#'
#' Objects of class `TurningPoints` store the peaks and troughs of one series.
#'
#' @slot name Series name.
#' @slot series The dated series (`ts`).
#' @slot index Positions of the turning points in `series`.
#' @slot type `"peak"` or `"trough"` for each turning point.
#' @slot params Censoring rules actually applied.
#' @seealso [date_turning_points()], [as.data.frame,TurningPoints-method]
#' @exportClass TurningPoints
setClass("TurningPoints", representation(
  name = "character", series = "ts", index = "integer", type = "character",
  params = "list"
), validity = function(object) {
  if (length(object@index) != length(object@type)) {
    return("`index` and `type` must have the same length.")
  }
  if (!all(object@type %in% c("peak", "trough"))) {
    return("`type` must be 'peak' or 'trough'.")
  }
  if (is.unsorted(object@index, strictly = TRUE)) {
    return("`index` must be strictly increasing.")
  }
  if (length(object@type) > 1L &&
      any(object@type[-1] == object@type[-length(object@type)])) {
    return("Peaks and troughs must alternate.")
  }
  TRUE
})

#' Date the turning points of a series
#'
#' @param dater A [Dater-class] object.
#' @param x A monthly or quarterly `ts`. Leading and trailing `NA` are
#'   ignored; internal `NA` are not allowed.
#' @param name Optional series name stored in the result.
#' @param ... Unused.
#' @return A [TurningPoints-class] object.
#' @examples
#' x <- ts(sin(2 * pi * (1:240) / 48), frequency = 12, start = 2000)
#' tp <- date_turning_points(bry_boschan(), x)
#' as.data.frame(tp)
#' @export
setGeneric("date_turning_points", function(dater, x, ...) {
  standardGeneric("date_turning_points")
})
