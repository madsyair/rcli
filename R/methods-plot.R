# Base-graphics plot methods.

tp_marks <- function(tp, y) {
  tm <- stats::time(tp@series)[tp@index]
  peaks <- tp@type == "peak"
  graphics::points(tm[peaks], y[tp@index][peaks], pch = 25, bg = "firebrick",
                   col = "firebrick")
  graphics::points(tm[!peaks], y[tp@index][!peaks], pch = 24,
                   bg = "steelblue", col = "steelblue")
}

#' Plot rcli objects
#'
#' * `TurningPoints`: the series with peaks (down triangles) and troughs (up
#'   triangles).
#' * `CycleSeries`: the normalised cycle.
#' * `CompositeIndex`: the composite index.
#' * `CliResult`: the normalised composite and reference cycles, with the
#'   reference contractions shaded.
#'
#' @param x The object to plot.
#' @param y Unused.
#' @param ... Further arguments passed to [graphics::plot()].
#' @return `x`, invisibly.
#' @examples
#' sim <- simulate_cycles(seed = 1)
#' meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
#' res <- cli_build(cli_candidates(sim, "reference", meta = meta))
#' plot(res)
#' @name plot-methods
NULL

#' @rdname plot-methods
#' @export
setMethod("plot", "TurningPoints", function(x, y, ...) {
  graphics::plot(x@series, ylab = x@name, xlab = "", ...)
  tp_marks(x, as.numeric(x@series))
  invisible(x)
})

#' @rdname plot-methods
#' @export
setMethod("plot", "CycleSeries", function(x, y, ...) {
  graphics::plot(x@normalised, ylab = "normalised cycle", xlab = "",
                 main = x@name, ...)
  graphics::abline(h = 0, col = "grey60")
  invisible(x)
})

#' @rdname plot-methods
#' @export
setMethod("plot", "CompositeIndex", function(x, y, ...) {
  graphics::plot(x@index, ylab = "index", xlab = "", ...)
  graphics::abline(h = 100, col = "grey60")
  invisible(x)
})

#' @rdname plot-methods
#' @export
setMethod("plot", "CliResult", function(x, y, ...) {
  ref <- x@cycles[[x@candidates@reference]]@normalised
  ref_tp <- x@turning_points[[x@candidates@reference]]
  rng <- range(ref, na.rm = TRUE)
  if (!is.null(x@composite)) {
    rng <- range(rng, x@composite@cycle, na.rm = TRUE)
  }
  graphics::plot(ref, type = "n", ylim = rng, xlab = "",
                 ylab = "normalised cycle", ...)
  states <- as.numeric(cycle_states(ref_tp))
  tm <- as.numeric(stats::time(ref))
  contraction <- which(states == 0)
  if (length(contraction) > 0L) {
    half <- 0.5 / stats::frequency(ref)
    shade <- grDevices::adjustcolor("grey70", alpha.f = 0.4)
    for (i in contraction) {
      graphics::polygon(c(tm[i] - half, tm[i] + half, tm[i] + half,
                          tm[i] - half), c(rng[1], rng[1], rng[2], rng[2]),
                        col = shade, border = NA)
    }
  }
  graphics::abline(h = 0, col = "grey60")
  graphics::lines(ref, col = "black", lwd = 1.5)
  labels <- "reference"
  cols <- "black"
  if (!is.null(x@composite)) {
    graphics::lines(x@composite@cycle, col = "firebrick", lwd = 1.5)
    labels <- c(labels, "composite leading indicator")
    cols <- c(cols, "firebrick")
  }
  graphics::legend("topleft", legend = labels, col = cols, lwd = 1.5,
                   bty = "n")
  invisible(x)
})
