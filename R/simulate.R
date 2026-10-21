#' Simulate a reference series and candidates with known leads
#'
#' Generates a common cycle from a stationary AR(2) process with complex
#' roots (period `period` years) and builds positive series around a growth
#' trend: a reference series, candidates that are the common cycle shifted by
#' known leads, counter-cyclical candidates (inverted and shifted), and pure
#' noise candidates. Every series carries its own AR(1) idiosyncratic noise.
#' The truth is returned in the `truth` attribute and is used by the
#' simulation harness of the package tests.
#'
#' @param n_years Length of the sample in years.
#' @param freq 12 (monthly) or 4 (quarterly).
#' @param leads Named vector of leads in periods (negative values lag).
#'   `NULL` gives leads of 6, 3, 0 and -3 months, or 2, 1, 0 and -1 quarters.
#' @param counter Named vector of leads of counter-cyclical candidates;
#'   `NULL` gives 4 months or 1 quarter.
#' @param n_noise Number of candidates without cyclical signal.
#' @param noise_sd Standard deviation of the idiosyncratic noise relative to
#'   the cycle.
#' @param period Average cycle length in years.
#' @param start Start of the sample (passed to [stats::ts()]).
#' @param seed Optional seed; when given, the random number generator state
#'   of the session is restored on exit.
#' @return A multivariate `ts` whose first column is `reference`; attribute
#'   `truth` is a data frame with columns `name`, `lead`, `class` and
#'   `inverted`.
#' @examples
#' sim <- simulate_cycles(seed = 42)
#' attr(sim, "truth")
#' plot(sim[, 1:3])
#' @export
simulate_cycles <- function(n_years = 30, freq = 12,
                            leads = NULL, counter = NULL, n_noise = 2,
                            noise_sd = 0.4, period = 4, start = 1995,
                            seed = NULL) {
  check_frequency(freq)
  check_number(n_years, "n_years", lower = 8)
  check_number(n_noise, "n_noise", lower = 0, integer = TRUE)
  check_number(noise_sd, "noise_sd", lower = 0)
  check_number(period, "period", lower = 1)
  if (!is.null(seed)) {
    old <- if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
      get(".Random.seed", envir = globalenv(), inherits = FALSE)
    }
    on.exit({
      if (is.null(old)) {
        rm(".Random.seed", envir = globalenv())
      } else {
        assign(".Random.seed", old, envir = globalenv())
      }
    }, add = TRUE)
    set.seed(seed)
  }
  if (is.null(leads)) {
    leads <- if (freq == 12) {
      c(lead_6 = 6, lead_3 = 3, coincident = 0, lag_3 = -3)
    } else {
      c(lead_2 = 2, lead_1 = 1, coincident = 0, lag_1 = -1)
    }
  }
  if (is.null(counter)) {
    counter <- if (freq == 12) c(counter_4 = 4) else c(counter_1 = 1)
  }
  n <- round(n_years * freq)
  all_shift <- c(0, leads, counter)
  pad <- max(abs(all_shift)) + 2L * freq
  omega <- 2 * pi / (period * freq)
  r <- if (freq == 12) 0.97 else 0.9
  cyc <- stats::arima.sim(list(ar = c(2 * r * cos(omega), -r^2)),
                          n = n + 2L * pad, n.start = 10L * freq)
  cyc <- as.numeric(scale(cyc))
  make <- function(shift, sign = 1) {
    idx <- (pad + 1L):(pad + n) + shift
    idio <- as.numeric(stats::arima.sim(list(ar = 0.5), n = n)) * noise_sd
    trend <- 0.02 / freq * seq_len(n) + stats::rnorm(1, 0, 0.5)
    100 * exp(trend + 0.04 * (sign * cyc[idx] + idio))
  }
  cols <- list(reference = make(0))
  for (nm in names(leads)) cols[[nm]] <- make(leads[[nm]])
  for (nm in names(counter)) cols[[nm]] <- make(counter[[nm]], sign = -1)
  for (k in seq_len(n_noise)) {
    idio <- as.numeric(stats::arima.sim(list(ar = 0.9), n = n))
    cols[[paste0("noise_", k)]] <- 100 * exp(0.02 / freq * seq_len(n) +
                                               0.04 * idio)
  }
  truth_lead <- c(leads, counter, rep(NA, n_noise))
  truth <- data.frame(
    name = names(cols)[-1],
    lead = unname(truth_lead),
    class = truth_class(truth_lead, freq),
    inverted = c(rep(FALSE, length(leads)), rep(TRUE, length(counter)),
                 rep(FALSE, n_noise)),
    stringsAsFactors = FALSE
  )
  out <- stats::ts(do.call(cbind, cols), start = start, frequency = freq)
  attr(out, "truth") <- truth
  out
}

truth_class <- function(lead, freq) {
  min_lead <- if (freq == 12) 3 else 1
  band <- if (freq == 12) 1 else 0
  vapply(lead, function(l) {
    if (is.na(l)) return("rejected")
    if (l >= min_lead) return("leading")
    if (abs(l) <= band) return("coincident")
    if (l <= -min_lead) return("lagging")
    "rejected"
  }, character(1), USE.NAMES = FALSE)
}
