#' Moving-holiday effect
#'
#' @slot name Short name of the holiday.
#' @slot dates Dates of the holiday.
#' @slot windows Named list of day windows around the holiday.
#' @slot center Centring of the regressors.
#' @seealso [holiday_effect()]
#' @exportClass HolidayEffect
setClass("HolidayEffect", representation(
  name = "character", dates = "Date", windows = "list", center = "character"
))

#' Moving-holiday effects for seasonal adjustment
#'
#' A moving holiday, such as Eid al-Fitr (Idulfitri) in Indonesia, falls in a
#' different month from year to year, so fixed monthly seasonal factors
#' cannot remove it. `holiday_effect()` describes such a holiday by its dates
#' and by one or more windows of days around it; each window becomes one
#' regressor of the regARIMA model of X-13ARIMA-SEATS (built with
#' [seasonal::genhol()]), and the estimated effect is removed from the
#' seasonally adjusted series. Pass the effects to [cli_spec()] through
#' `holidays`, together with `seasonal_adjust = TRUE`.
#'
#' The default windows suit Idulfitri in Indonesia: demand rises in the two
#' weeks before the holiday, production falls during the week of collective
#' leave that starts on it. Centring with `"mean"` follows the advice of the
#' 'seasonal' package for Ramadan-type holidays.
#'
#' @param dates Dates of the holiday (class `Date`), covering every year of
#'   the data.
#' @param name Short name, used for the regressors (`<name>_<window>`).
#' @param windows Named list of windows, each `c(first, last)` in days
#'   relative to the holiday (negative = before).
#' @param center Centring of the regressors, passed to [seasonal::genhol()].
#' @return A `HolidayEffect` object.
#' @references
#' Lestari, E., Widiharih, T. and Rahmawati, R. (2018). Peramalan ekspor
#' nonmigas dengan variasi kalender Islam menggunakan X-13-ARIMA-SEATS.
#' *Jurnal Gaussian*, 7(3), 236--247.
#' @seealso [idulfitri_dates()], [cli_spec()]
#' @examples
#' eid <- holiday_effect(idulfitri_dates(1990, 2030), name = "idulfitri")
#' eid
#' \donttest{
#' if (requireNamespace("seasonal", quietly = TRUE)) {
#'   sim <- simulate_cycles(seed = 1)
#'   meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
#'   spec <- cli_spec(seasonal_adjust = TRUE, holidays = eid)
#'   cyc <- cli_cycles(cli_candidates(sim, "reference", meta = meta), spec)
#'   cyc$lead_6
#' }
#' }
#' @export
holiday_effect <- function(dates, name = "holiday",
                           windows = list(before = c(-14, -1),
                                          after = c(0, 6)),
                           center = c("mean", "calendar", "none")) {
  center <- match.arg(center)
  if (!inherits(dates, "Date") || length(dates) < 2L || anyNA(dates)) {
    rcli_abort("`dates` must be a vector of at least two Dates.",
               "rcli_error_argument")
  }
  if (!is.character(name) || length(name) != 1L ||
      !grepl("^[A-Za-z][A-Za-z0-9_]*$", name)) {
    rcli_abort("`name` must be one word of letters, digits and _.",
               "rcli_error_argument")
  }
  ok <- is.list(windows) && length(windows) > 0L &&
    !is.null(names(windows)) && all(nzchar(names(windows))) &&
    all(vapply(windows, function(w) {
      is.numeric(w) && length(w) == 2L && !anyNA(w) && w[1] <= w[2]
    }, logical(1)))
  if (!ok) {
    rcli_abort("`windows` must be a named list of c(first, last) day pairs.",
               "rcli_error_argument")
  }
  new("HolidayEffect", name = name, dates = sort(unique(dates)),
      windows = lapply(windows, as.numeric), center = center)
}

#' Approximate dates of Idulfitri
#'
#' Dates of 1 Syawal (Eid al-Fitr) from the arithmetic (tabular) Islamic
#' calendar. The official Indonesian date, set each year by the Ministry of
#' Religious Affairs after the *sidang isbat*, can differ from these by one
#' or two days. For monthly holiday regressors such a difference rarely
#' matters, but the official dates should be used when they are at hand.
#'
#' @param from,to First and last Gregorian year.
#' @return A sorted vector of class `Date`.
#' @seealso [holiday_effect()]
#' @examples
#' idulfitri_dates(2020, 2026)
#' @export
idulfitri_dates <- function(from = 1980, to = 2040) {
  check_number(from, "from", lower = 1, upper = 9999, integer = TRUE)
  check_number(to, "to", lower = from, upper = 9999, integer = TRUE)
  hijri <- seq(floor((from - 622) * 33 / 32) - 1, ceiling((to - 622) * 33 /
                                                             32) + 1)
  # Julian day of 1 Shawwal (month 10) of each Hijri year, tabular calendar
  jd <- 1 + ceiling(29.5 * 9) + (hijri - 1) * 354 +
    floor((3 + 11 * hijri) / 30) + 1948439.5 - 1
  d <- as.Date(jd - 2440587.5, origin = "1970-01-01")
  yr <- as.integer(format(d, "%Y"))
  sort(d[yr >= from & yr <= to])
}

# Holiday regressors for one series, or NULL without holidays.
holiday_regressors <- function(x, holidays) {
  if (length(holidays) == 0L) return(NULL)
  f <- stats::frequency(x)
  regs <- list()
  for (h in holidays) {
    for (w in names(h@windows)) {
      r <- seasonal::genhol(h@dates, start = h@windows[[w]][1],
                            end = h@windows[[w]][2], frequency = f,
                            center = h@center)
      regs[[paste(h@name, w, sep = "_")]] <- r
    }
  }
  reg <- do.call(stats::ts.union, regs)
  if (is.null(dim(reg))) reg <- stats::ts(matrix(reg, ncol = 1),
                                          start = stats::start(reg),
                                          frequency = f)
  colnames(reg) <- names(regs)
  if (stats::time(reg)[1] > stats::time(x)[1] + 1e-8 ||
      stats::time(reg)[nrow(reg)] < stats::time(x)[length(x)] - 1e-8) {
    rcli_abort("The holiday dates do not cover the whole span of the data.",
               "rcli_error_argument")
  }
  reg
}

#' @rdname holiday_effect
#' @param object A `HolidayEffect`.
#' @export
setMethod("show", "HolidayEffect", function(object) {
  d <- object@dates
  cat("<HolidayEffect> '", object@name, "', ", length(d), " dates from ",
      format(min(d)), " to ", format(max(d)), "\n", sep = "")
  for (w in names(object@windows)) {
    v <- object@windows[[w]]
    cat(sprintf("  %s: days %+d to %+d\n", w, as.integer(v[1]),
                as.integer(v[2])))
  }
  invisible(object)
})
