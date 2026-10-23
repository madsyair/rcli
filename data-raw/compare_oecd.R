# Monte Carlo comparison of the package defaults with the OECD options
# (rcli 0.1.3). Run from the package root after the calibration harness:
#   Rscript data-raw/compare_oecd.R
# Outputs in inst/calibration/:
#   oecd-classification.csv  classification accuracy, rcli rule vs OECD rule
#   oecd-aggregation.csv     aggregation and lag-shifting experiment
#   oecd-outliers.csv        robust outlier rule vs TRAMO-type regARIMA
devtools::load_all(quiet = TRUE)
reps <- as.integer(Sys.getenv("LEADCLI_REPS", "100"))
parts <- Sys.getenv("LEADCLI_PARTS", "ABC")

# ---- A. classification ------------------------------------------------------
if (grepl("A", parts)) {
  # The calibration statistics (data-raw/calibrate_collect.R) are classified
  # again with the OECD rule, so that only the rule differs.
  d <- utils::read.csv("inst/calibration/assessment-stats.csv")
  reclass <- function(classifier) {
    vapply(seq_len(nrow(d)), function(i) {
      s <- cli_spec(d$freq[i], classifier = classifier)
      classify_row(d[i, ], s)$class
    }, character(1))
}
d$oecd <- reclass(oecd_classifier())
d$oecd_min1 <- reclass(oecd_classifier(min_matched = 1))
rate <- function(cls, rows) mean(cls[rows] == d$truth[rows])
classification <- do.call(rbind, lapply(
  split(seq_len(nrow(d)), list(d$freq, d$noise_sd)), function(i) {
    lead <- i[d$truth[i] == "leading"]
    other <- i[d$truth[i] != "leading"]
    noise <- i[d$truth[i] == "rejected"]
    do.call(rbind, lapply(c("class", "oecd", "oecd_min1"), function(r) {
      data.frame(freq = d$freq[i[1]], noise_sd = d$noise_sd[i[1]],
                 rule = c(class = "rcli", oecd = "OECD (min 3 matched)",
                          oecd_min1 = "OECD (literal)")[[r]],
                 overall = rate(d[[r]], i),
                 leading_found = mean(d[[r]][lead] == "leading"),
                 false_leading = mean(d[[r]][other] == "leading"),
                 noise_called_leading = mean(d[[r]][noise] == "leading"))
    }))
  }))
classification[, 4:7] <- round(classification[, 4:7], 3)
rownames(classification) <- NULL
utils::write.csv(classification, "inst/calibration/oecd-classification.csv",
                 row.names = FALSE)
print(classification)
}

# ---- B. aggregation and lag-shifting ------------------------------------------
# True leading components with different leads; the composite is built with
# the six combinations of aggregation (plain mean, chained at the edge,
# OECD chain) and lag-shifting. "Ragged edge": the
# longest-lead component misses its last `k` values, as when a series is
# published late; the error is the gap to the full-information composite
# over those dates, in units of the composite's mean absolute deviation.
comp_stats <- function(ci, ref_cs, spec) {
  cs <- composite_as_cycle(ci)
  ref_tp <- date_turning_points(spec@dater, ref_cs@normalised)
  tp <- date_turning_points(spec@dater, cs@normalised)
  row <- assess_pair(ref_cs, ref_tp, cs, tp, spec)$row
  c(ccf_lag = row$ccf_lag, ccf_r = row$ccf_r, median_lead = row$median_lead,
    sd_lead = row$sd_lead, extra = row$extra, missed = row$missed)
}
aggregation_rep <- function(seed, noise_sd, k = 2L) {
  sim <- simulate_cycles(leads = c(lead_9 = 9, lead_6 = 6, lead_3 = 3),
                         counter = numeric(0), n_noise = 0,
                         noise_sd = noise_sd, seed = seed)
  meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
  cand <- cli_candidates(sim, "reference", meta = meta)
  spec <- cli_spec(12)
  cyc <- cli_cycles(cand, spec)
  a <- cli_assess(cand, spec, cyc)
  comps <- c("lead_9", "lead_6", "lead_3")
  ref <- cyc$reference
  ragged <- cyc
  last <- max(which(!is.na(ragged$lead_9@normalised)))
  ragged$lead_9@normalised[(last - k + 1L):last] <- NA
  out <- list()
  aggs <- list(level = equal_weight(ragged_edge = "level"),
               chain = equal_weight(), oecd = oecd_aggregate())
  for (agg in names(aggs)) {
    for (shift in c(FALSE, TRUE)) {
      s <- update(spec, aggregator = aggs[[agg]])
      sh <- if (shift) lag_shifts(comps, a) else NULL
      full <- cli_composite(cyc, comps, s, ref, shifts = sh)
      part <- cli_composite(ragged, comps, s, ref, shifts = sh)
      dates <- (last - k + 1L):last
      # with lag-shifting the late values move past the last date and are
      # dropped from both composites, so the error is not comparable
      err <- if (shift) NA_real_ else
        mean(abs(as.numeric(part@cycle)[dates] -
                   as.numeric(full@cycle)[dates]), na.rm = TRUE)
      out[[length(out) + 1L]] <- data.frame(
        seed = seed, noise_sd = noise_sd, aggregation = agg, lag_shift = shift,
        t(comp_stats(full, ref, s)), ragged_edge_error = err)
    }
  }
  do.call(rbind, out)
}
if (grepl("B", parts)) {
  agg <- do.call(rbind, lapply(c(0.4, 0.8), function(ns) {
    do.call(rbind, lapply(seq_len(reps), aggregation_rep, noise_sd = ns))
  }))
  aggregation <- aggregate(
    agg[, c("ccf_lag", "ccf_r", "median_lead", "sd_lead", "extra", "missed",
            "ragged_edge_error")],
    agg[, c("noise_sd", "aggregation", "lag_shift")], mean, na.rm = TRUE)
  aggregation[, 4:10] <- round(aggregation[, 4:10], 3)
  aggregation$ragged_edge_error[is.nan(aggregation$ragged_edge_error)] <- NA
  utils::write.csv(aggregation, "inst/calibration/oecd-aggregation.csv",
                   row.names = FALSE)
  print(aggregation)
}

# ---- C. outliers -----------------------------------------------------------------
# Additive outliers (one-month spikes of 8 standard deviations of the
# monthly change) and one level shift (10 of them) are injected into every
# candidate; the classification with the robust rule is compared with TRAMO-type regARIMA (X-13 engine,
# which runs without Java).
outlier_rep <- function(seed) {
  sim <- simulate_cycles(noise_sd = 0.4, seed = seed)
  set.seed(seed)
  n <- nrow(sim)
  truth <- attr(sim, "truth")
  for (j in 2:ncol(sim)) {
    v <- log(sim[, j])
    s <- stats::sd(diff(v), na.rm = TRUE)
    at <- sample(24:(n - 24), 4)
    v[at] <- v[at] + sample(c(-1, 1), 4, TRUE) * 8 * s
    ls_at <- sample(60:(n - 60), 1)
    v[ls_at:n] <- v[ls_at:n] + 10 * s
    sim[, j] <- exp(v)
  }
  meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
  cand <- cli_candidates(sim, "reference", meta = meta)
  do.call(rbind, lapply(list(robust = robust_outliers(5),
                             tramo = tramo_outliers(engine = "x13")),
                        function(o) {
    tab <- cli_assess(cand, cli_spec(12, outliers = o))@table
    data.frame(seed = seed, method = as.character(class(o))[1],
               name = tab$name,
               class = tab$class, ccf_r = tab$ccf_r,
               truth = truth$class[match(tab$name, truth$name)])
  }))
}
if (grepl("C", parts)) {
  n_out <- min(reps, as.integer(Sys.getenv("LEADCLI_OUTLIER_REPS", "40")))
  out <- do.call(rbind, lapply(seq_len(n_out), outlier_rep))
  outliers <- do.call(rbind, lapply(split(out, out$method), function(x) {
    data.frame(method = x$method[1], reps = n_out,
               overall = mean(x$class == x$truth),
               leading_found = mean(x$class[x$truth == "leading"] == "leading"),
               false_leading = mean(x$class[x$truth != "leading"] == "leading"),
               mean_abs_ccf_r = mean(abs(x$ccf_r), na.rm = TRUE))
  }))
  outliers[, 3:6] <- round(outliers[, 3:6], 3)
  utils::write.csv(outliers, "inst/calibration/oecd-outliers.csv",
                   row.names = FALSE)
  print(outliers)
}
