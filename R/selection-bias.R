#' Check the selection bias of in-sample leads
#'
#' Leads measured on the sample used to choose the components overstate the
#' lead the composite will deliver later: components are kept precisely
#' because they happened to lead in that sample. For every cut-off date
#' \eqn{T_0} this harness
#'
#' 1. restricts the data to observations up to \eqn{T_0} and runs the whole
#'    selection ([cli_build()]) on that window;
#' 2. records the in-sample lead of the resulting composite;
#' 3. rebuilds the composite from the same components on the full sample and
#'    measures its lead only at reference turning points after \eqn{T_0}.
#'
#' The component choice is therefore out of sample; the cycles in step 3 are
#' still two-sided filter estimates, so this is a pseudo out-of-sample check
#' of selection, not a real-time evaluation (for that, store data vintages in
#' the [CandidateSet-class]). A large positive `lead_gap` signals that the
#' in-sample lead is mostly a selection effect.
#'
#' @param candidates A [CandidateSet-class].
#' @param spec A [CliSpec-class].
#' @param cutoffs Cut-off dates in decimal time (e.g. `c(2010, 2015)`).
#' @return A data frame with one row per cut-off: `cutoff`, `n_components`,
#'   `components`, in-sample `ccf_lag_in` and `median_lead_in`,
#'   out-of-sample `median_lead_out`, `pct_led_out` and `n_tp_out` (number of
#'   reference turning points after the cut-off), `lead_gap`
#'   (`median_lead_in - median_lead_out`) and `note`, which explains empty
#'   rows (training window too short, or no leading candidate before the
#'   cut-off).
#' @examples
#' \donttest{
#' sim <- simulate_cycles(seed = 1)
#' meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
#' cand <- cli_candidates(sim, "reference", meta = meta)
#' cli_selection_bias(cand, cli_spec(freq = 12), cutoffs = 2015)
#' }
#' @export
cli_selection_bias <- function(candidates, spec, cutoffs) {
  check_inputs(candidates, spec)
  if (!is.numeric(cutoffs) || length(cutoffs) == 0L) {
    rcli_abort("`cutoffs` must be a non-empty numeric vector.",
               "rcli_error_argument")
  }
  full_cycles <- cli_cycles(candidates, spec)
  ref <- full_cycles[[candidates@reference]]
  ref_tp <- date_turning_points(spec@dater, ref@normalised, name = ref@name)
  rows <- lapply(sort(cutoffs), function(t0) {
    one_cutoff(candidates, spec, t0, full_cycles, ref, ref_tp)
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

one_cutoff <- function(candidates, spec, t0, full_cycles, ref, ref_tp) {
  empty <- data.frame(cutoff = t0, n_components = 0L, components = "",
                      ccf_lag_in = NA_real_, median_lead_in = NA_real_,
                      median_lead_out = NA_real_, pct_led_out = NA_real_,
                      n_tp_out = NA_integer_, lead_gap = NA_real_,
                      note = "", stringsAsFactors = FALSE)
  train <- tryCatch(
    suppressWarnings(cli_build(window(candidates, end = t0),
                               update(spec, oos_cutoffs = numeric(0)))),
    rcli_error = function(e) NULL
  )
  if (is.null(train)) {
    empty$note <- "training window too short"
    return(empty)
  }
  if (is.null(train@composite)) {
    empty$note <- "no leading candidate before the cut-off"
    return(empty)
  }
  comps <- train@composite@components
  cycles <- full_cycles
  for (nm in intersect(comps, train@assessment@inverted)) {
    cycles[[nm]] <- invert_cycle(cycles[[nm]])
  }
  comp <- cli_composite(cycles, comps, spec, ref)
  comp_cs <- composite_as_cycle(comp)
  comp_tp <- date_turning_points(spec@dater, comp_cs@normalised, name = "CLI")
  e <- resolve_dater(spec@dater, spec@freq)$end_exclusion
  pairs <- match_turning_points(ref_tp, comp_tp, spec@lead_window, e)$pairs
  times <- stats::time(ref@normalised)
  after <- pairs[times[pairs$ref_index] > t0, , drop = FALSE]
  leads <- after$lead[!is.na(after$lead)]
  tp_in <- train@validation@turning_points
  med_out <- if (length(leads) > 0L) stats::median(leads) else NA_real_
  empty$n_components <- length(comps)
  empty$components <- paste(comps, collapse = ", ")
  empty$ccf_lag_in <- tp_in$ccf_lag
  empty$median_lead_in <- tp_in$median_lead
  empty$median_lead_out <- med_out
  empty$pct_led_out <- if (nrow(after) > 0L) sum(leads > 0) / nrow(after) else
    NA_real_
  empty$n_tp_out <- nrow(after)
  empty$lead_gap <- tp_in$median_lead - med_out
  empty
}
