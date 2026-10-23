#' Extract the cycles of all series
#'
#' Applies, series by series on its own non-missing span: interpolation of
#' internal gaps, optional seasonal adjustment of the original series with
#' X-13ARIMA-SEATS, the transformation (`"auto"` takes logarithms of strictly
#' positive series), outlier replacement, the extension of the series end
#' with forecasts ([ar_extension()] by default), the cycle filter and the OECD
#' normalisation (subtract the mean, divide by the mean absolute deviation).
#' Every step is recorded in the `steps` slot.
#'
#' @param candidates A [CandidateSet-class].
#' @param spec A [CliSpec-class].
#' @return A named list of [CycleSeries-class], reference first.
#' @examples
#' sim <- simulate_cycles(seed = 1)
#' meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
#' cand <- cli_candidates(sim, "reference", meta = meta)
#' cyc <- cli_cycles(cand, cli_spec(freq = 12))
#' cyc$lead_6
#' @export
cli_cycles <- function(candidates, spec) {
  check_inputs(candidates, spec)
  data <- candidates@data
  nms <- c(candidates@reference, candidate_names(candidates))
  out <- lapply(nms, function(nm) cycle_one(data[, nm], nm, spec))
  stats::setNames(out, nms)
}

check_inputs <- function(candidates, spec) {
  if (!is(candidates, "CandidateSet")) {
    rcli_abort("`candidates` must be a CandidateSet (see cli_candidates()).",
               "rcli_error_argument")
  }
  if (!is(spec, "CliSpec")) {
    rcli_abort("`spec` must be a CliSpec (see cli_spec()).",
               "rcli_error_argument")
  }
  if (stats::frequency(candidates@data) != spec@freq) {
    rcli_abort("The frequency of the data and of `spec` differ.",
               "rcli_error_frequency")
  }
  invisible(TRUE)
}

cycle_one <- function(x, name, spec) {
  x <- as_ts_like(as.numeric(x), x)
  steps <- character(0)
  span <- non_na_span(x)
  if (anyNA(span) || span[2] - span[1] + 1L < 4L * spec@freq) {
    rcli_abort(
      sprintf("Series '%s' has fewer than four years of observations.", name),
      "rcli_error_short_series"
    )
  }
  core <- stats::window(x, start = stats::time(x)[span[1]],
                        end = stats::time(x)[span[2]])
  if (anyNA(core)) {
    core <- as_ts_like(fill_internal_na(as.numeric(core)), core)
    steps <- c(steps, "interpolated internal gaps")
  }
  if (spec@seasonal_adjust) {
    hol <- if (methods::.hasSlot(spec, "holidays")) spec@holidays else list()
    core <- seasonal_adjust_x13(core, hol)
    steps <- c(steps, attr(core, "step"))
    attr(core, "step") <- NULL
  }
  outliers <- spec_outliers(spec)
  engine <- if (methods::.hasSlot(outliers, "engine")) outliers@engine else
    "auto"
  core <- apply_transform(core, spec@transform, name, engine)
  steps <- c(steps, attr(core, "step"))
  attr(core, "step") <- NULL
  out <- treat_outliers(outliers, core)
  steps <- c(steps, out$step)
  core <- out$x
  fc <- out$forecast
  kind <- "outlier treatment"
  if (length(fc) == 0L) {
    ext <- spec_extension(spec)
    fc <- extend_series(ext, core)
    kind <- ext@label
  }
  h <- length(fc)
  if (h > 0L) {
    ext <- stats::ts(c(as.numeric(core), fc), start = stats::start(core),
                     frequency = stats::frequency(core))
    cyc <- utils::head(as.numeric(extract_cycle(spec@filter, ext)),
                       length(core))
    steps <- c(steps, sprintf(
      "cycle: %s (series extended by %d-period forecasts: %s)",
      spec@filter@label, h, kind))
  } else {
    cyc <- extract_cycle(spec@filter, core)
    steps <- c(steps, sprintf("cycle: %s", spec@filter@label))
  }
  place <- function(v) {
    full <- rep(NA_real_, length(x))
    full[span[1]:span[2]] <- as.numeric(v)
    as_ts_like(full, x)
  }
  new("CycleSeries", name = name, original = x, transformed = place(core),
      cycle = place(cyc), normalised = place(normalise_cycle(cyc)),
      steps = c(steps, "normalised (mean 0, mean absolute deviation 1)"))
}

# Outlier treatment of a specification (specifications saved before 0.1.3
# have only the robust threshold).
spec_outliers <- function(spec) {
  if (methods::.hasSlot(spec, "outliers")) spec@outliers else
    robust_outliers(spec@outlier_threshold)
}

# End-of-series extension of a specification (none before 0.2.0).
spec_extension <- function(spec) {
  if (methods::.hasSlot(spec, "extension")) spec@extension else
    no_extension()
}

apply_transform <- function(x, transform, name, engine = "auto") {
  positive <- all(x > 0)
  if (transform == "test") {
    use_log <- positive && log_test(x, engine)
    out <- if (use_log) log(x) else x
    attr(out, "step") <- if (use_log) "log (regARIMA log/level test)" else
      "levels (regARIMA log/level test)"
    return(out)
  }
  if (transform == "log" && !positive) {
    rcli_abort(sprintf("Series '%s' has non-positive values; cannot log.",
                          name), "rcli_error_transform")
  }
  if (transform == "log" || (transform == "auto" && positive)) {
    out <- log(x)
    attr(out, "step") <- "log"
  } else {
    out <- x
    attr(out, "step") <- "levels (no log)"
  }
  out
}

# Replace observations whose change is an extreme robust outlier.
replace_outliers <- function(x, threshold) {
  if (!is.finite(threshold)) return(list(x = x, n = 0L))
  v <- as.numeric(x)
  d <- diff(v)
  s <- stats::mad(d)
  if (!is.finite(s) || s == 0) return(list(x = x, n = 0L))
  z <- abs(d - stats::median(d)) / s
  # a spike shows as two consecutive extreme changes of opposite sign
  flag <- which(z[-length(z)] > threshold & z[-1] > threshold &
                  sign(d[-length(d)]) != sign(d[-1])) + 1L
  if (length(flag) == 0L) return(list(x = x, n = 0L))
  v[flag] <- NA
  list(x = as_ts_like(fill_internal_na(v), x), n = length(flag))
}

seasonal_adjust_x13 <- function(x, holidays = list()) {
  if (!requireNamespace("seasonal", quietly = TRUE)) {
    rcli_abort("Seasonal adjustment needs the 'seasonal' package.",
               "rcli_error_dependency")
  }
  reg <- holiday_regressors(x, holidays)
  if (is.null(reg)) {
    fit <- suppressMessages(seasonal::seas(x))
    step <- "seasonally adjusted (X-13ARIMA-SEATS)"
  } else {
    # X-13 needs the regressors over its forecast horizon (three years);
    # without them, use X-11 without forecast extension.
    covered <- stats::time(reg)[nrow(reg)] >=
      stats::time(x)[length(x)] + 3 - 1e-8
    args <- list(x, xreg = reg, regression.usertype = "holiday")
    if (!covered) args <- c(args, list(x11 = "", forecast.maxlead = 0))
    fit <- suppressMessages(do.call(seasonal::seas, args))
    step <- sprintf("seasonally adjusted (X-13ARIMA-SEATS%s, holidays: %s)",
                    if (covered) "" else ", X-11 without forecasts",
                    paste(vapply(holidays, function(h) h@name, ""),
                          collapse = ", "))
  }
  out <- as_ts_like(as.numeric(seasonal::final(fit)), x)
  attr(out, "step") <- step
  out
}
