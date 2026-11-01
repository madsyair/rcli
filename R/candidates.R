#' OECD economic rationales for leading indicators
#'
#' The four types of economic rationale the OECD uses in the pre-selection of
#' candidate components (Gyomai and Guidetti 2012).
#'
#' @format A named character vector.
#' @examples
#' oecd_rationales
#' @export
oecd_rationales <- c(
  early_stage = "Early stage: measures early stages of production",
  rapid_response = "Rapid response: responds rapidly to changes in activity",
  expectations = "Expectation sensitive: measures or reacts to expectations",
  prime_mover = "Prime mover: relates to policy or external drivers"
)

#' Collect the reference and candidate series
#'
#' Builds a [CandidateSet-class]: one reference series (for example GDP or an
#' industrial production index) and the candidate leading series, all at the
#' same monthly or quarterly frequency. Series may start and end at different
#' dates (ragged edges); internal gaps are filled by interpolation later.
#'
#' Pre-selection metadata documents why each candidate might lead. The OECD
#' requires an economic rationale for every component; statistics alone do
#' not replace it. Missing rationales trigger a warning.
#'
#' @param data A multivariate `ts`, or a data frame of numeric columns
#'   together with `start` and `frequency`.
#' @param reference Name of the reference column.
#' @param meta Optional data frame with a `name` column and any of
#'   `rationale` (one of `names(oecd_rationales)`), `source`,
#'   `release_lag` (publication delay in periods), `type` (one of
#'   `names(series_types)`) and `frequency`, the source frequency (one of
#'   `names(series_frequencies)`; a candidate cannot be semiannual or
#'   annual). When `data` comes from [cli_align()], the types, source
#'   frequencies and conversion steps recorded there are kept as well, and a
#'   source frequency in `meta` must agree with the recorded one. (The
#'   `frequency` column of `meta` is the source frequency of a candidate; the
#'   argument `frequency` below is the number of periods a year of `data`.)
#' @param vintages Optional named list of earlier releases, each shaped like
#'   `data`, for real-time evaluation.
#' @param start,frequency Time attributes when `data` is a data frame.
#' @return A [CandidateSet-class] object.
#' @seealso [simulate_cycles()] for example data.
#' @examples
#' sim <- simulate_cycles(seed = 1)
#' meta <- data.frame(name = colnames(sim)[-1], rationale = "expectations")
#' cand <- cli_candidates(sim, reference = "reference", meta = meta)
#' cand
#' @export
cli_candidates <- function(data, reference, meta = NULL, vintages = list(),
                           start = NULL, frequency = NULL) {
  if (is.data.frame(data)) {
    if (is.null(start) || is.null(frequency)) {
      rcli_abort(
        "Supply `start` and `frequency` when `data` is a data frame.",
        "rcli_error_argument"
      )
    }
    num <- vapply(data, is.numeric, logical(1))
    data <- stats::ts(as.matrix(data[num]), start = start,
                      frequency = frequency)
  }
  if (!stats::is.ts(data) || is.null(dim(data))) {
    rcli_abort("`data` must be a multivariate `ts` or a data frame.",
               "rcli_error_argument")
  }
  check_frequency(stats::frequency(data))
  if (is.null(colnames(data)) || anyDuplicated(colnames(data)) > 0L) {
    rcli_abort("Columns of `data` need unique names.",
               "rcli_error_argument")
  }
  if (!is.character(reference) || length(reference) != 1L ||
      !reference %in% colnames(data)) {
    rcli_abort("`reference` must name one column of `data`.",
               "rcli_error_argument")
  }
  if (ncol(data) < 2L) {
    rcli_abort("`data` needs at least one candidate besides the reference.",
               "rcli_error_argument")
  }
  alignment <- attr(data, "alignment")
  if (!is.data.frame(alignment)) alignment <- data.frame()
  attr(data, "alignment") <- NULL
  ref <- as.numeric(data[, reference])
  if (all(is.na(ref)) ||
      length(unique(ref[!is.na(ref)])) < 2L) {
    rcli_abort("The reference series is empty or constant.",
               "rcli_error_argument")
  }
  empty <- setdiff(colnames(data)[apply(data, 2, function(v) all(is.na(v)))],
                   reference)
  if (length(empty) > 0L) {
    rcli_warn(sprintf("Candidates without observations were dropped: %s.",
                      paste(empty, collapse = ", ")),
              "rcli_warning_dropped")
    keep <- setdiff(colnames(data), empty)
    if (length(keep) < 2L) {
      rcli_abort("`data` needs at least one candidate with observations.",
                 "rcli_error_argument")
    }
    tsp0 <- stats::tsp(data)
    data <- stats::ts(data[, keep, drop = FALSE], start = tsp0[1],
                      frequency = tsp0[3])
    if (!is.null(meta) && is.data.frame(meta) && "name" %in% names(meta)) {
      meta <- meta[!meta$name %in% empty, , drop = FALSE]
    }
    if (nrow(alignment) > 0L) {
      alignment <- alignment[!alignment$name %in% empty, , drop = FALSE]
    }
  }
  meta <- complete_meta(meta, setdiff(colnames(data), reference), alignment)
  if (!is.list(vintages)) {
    rcli_abort("`vintages` must be a list.", "rcli_error_argument")
  }
  new("CandidateSet", data = data, reference = reference, meta = meta,
      vintages = vintages, alignment = alignment)
}

complete_meta <- function(meta, names, alignment = data.frame()) {
  base <- data.frame(name = names, rationale = NA_character_,
                     source = NA_character_, release_lag = NA_real_,
                     type = NA_character_, frequency = NA_character_,
                     stringsAsFactors = FALSE)
  hit <- match(names, alignment$name)
  detected <- rep(NA_character_, length(names))
  if ("from" %in% names(alignment)) {
    detected[!is.na(hit)] <- alignment$from[hit[!is.na(hit)]]
  }
  for (col in intersect(c("type", "from"), names(alignment))) {
    to <- if (col == "from") "frequency" else col
    base[[to]][!is.na(hit)] <- alignment[[col]][hit[!is.na(hit)]]
  }
  if (!is.null(meta)) {
    if (!is.data.frame(meta) || !"name" %in% names(meta)) {
      rcli_abort("`meta` must be a data frame with a `name` column.",
                 "rcli_error_argument")
    }
    unknown <- setdiff(meta$name, names)
    if (length(unknown) > 0L) {
      rcli_abort(sprintf("`meta` names unknown candidates: %s.",
                            paste(unknown, collapse = ", ")),
                    "rcli_error_argument")
    }
    # a missing entry keeps what cli_align() recorded
    at <- match(meta$name, names)
    for (col in intersect(c("rationale", "source", "release_lag", "type",
                            "frequency"), names(meta))) {
      given <- !is.na(meta[[col]])
      base[[col]][at[given]] <- meta[[col]][given]
    }
  }
  bad_type <- !is.na(base$type) & !base$type %in% names(series_types)
  if (any(bad_type)) {
    rcli_abort(
      sprintf("Unknown type(s): %s. Use one of: %s.",
              paste(unique(base$type[bad_type]), collapse = ", "),
              paste(names(series_types), collapse = ", ")),
      "rcli_error_argument"
    )
  }
  bad_freq <- !is.na(base$frequency) &
    !base$frequency %in% names(series_frequencies)
  if (any(bad_freq)) {
    rcli_abort(
      sprintf("Unknown frequency: %s. Use one of: %s.",
              paste(unique(base$frequency[bad_freq]), collapse = ", "),
              paste(names(series_frequencies), collapse = ", ")),
      "rcli_error_argument"
    )
  }
  clash <- which(!is.na(detected) & !is.na(base$frequency) &
                   detected != base$frequency)
  if (length(clash) > 0L) {
    i <- clash[1]
    rcli_abort(sprintf(paste("Candidate '%s' is given as %s in `meta`, but",
                             "cli_align() found %s data."),
                       base$name[i], base$frequency[i], detected[i]),
               "rcli_error_frequency")
  }
  low <- which(base$frequency %in% c("semiannual", "annual"))
  if (length(low) > 0L) abort_low_frequency(base$name[low[1]],
                                            base$frequency[low[1]])
  bad <- !is.na(base$rationale) & !base$rationale %in% names(oecd_rationales)
  if (any(bad)) {
    rcli_abort(
      sprintf("Unknown rationale(s): %s. Use one of: %s.",
              paste(unique(base$rationale[bad]), collapse = ", "),
              paste(names(oecd_rationales), collapse = ", ")),
      "rcli_error_argument"
    )
  }
  if (anyNA(base$rationale)) {
    rcli_warn(
      sprintf(paste("No economic rationale for: %s.",
                    "The OECD requires one per component."),
              paste(base$name[is.na(base$rationale)], collapse = ", ")),
      "rcli_warning_rationale"
    )
  }
  base
}

candidate_names <- function(x) setdiff(colnames(x@data), x@reference)

# Alignment record, also for candidate sets saved before rcli 0.1.1.
alignment_of <- function(x) {
  if (methods::.hasSlot(x, "alignment")) x@alignment else data.frame()
}

# Conversion of the reference series, or NULL when it came in as is.
reference_conversion <- function(x) {
  al <- alignment_of(x)
  if (nrow(al) == 0L) return(NULL)
  row <- al[al$name == x@reference, , drop = FALSE]
  if (nrow(row) == 0L || row$method == "none") NULL else row
}

#' @rdname cli_candidates
#' @param x A [CandidateSet-class].
#' @param i Candidate names or positions to keep (the reference is always
#'   kept).
#' @param j,drop,... Unused.
#' @export
setMethod("[", "CandidateSet", function(x, i, j, ..., drop = FALSE) {
  cands <- candidate_names(x)
  keep <- if (is.character(i)) i else cands[i]
  if (!all(keep %in% cands)) {
    rcli_abort("Unknown candidate(s) in subset.", "rcli_error_argument")
  }
  cols <- c(x@reference, keep)
  x@data <- x@data[, cols, drop = FALSE]
  x@meta <- x@meta[x@meta$name %in% keep, , drop = FALSE]
  if (nrow(alignment_of(x)) > 0L) {
    x@alignment <- x@alignment[x@alignment$name %in% cols, , drop = FALSE]
  }
  x@vintages <- lapply(x@vintages, function(v) {
    v[, intersect(cols, colnames(v)), drop = FALSE]
  })
  x
})

#' Restrict a candidate set to a time window
#'
#' @param x A [CandidateSet-class].
#' @param start,end Window limits passed to [stats::window()].
#' @param ... Unused.
#' @return A [CandidateSet-class].
#' @examples
#' sim <- simulate_cycles(seed = 1)
#' meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
#' cand <- cli_candidates(sim, "reference", meta = meta)
#' window(cand, end = c(2015, 12))
#' @export
setMethod("window", "CandidateSet", function(x, start = NULL, end = NULL, ...) {
  x@data <- tryCatch(
    suppressWarnings(stats::window(x@data, start = start, end = end)),
    error = function(e) {
      rcli_abort("The window lies outside the data.",
                 "rcli_error_short_series")
    })
  x
})
