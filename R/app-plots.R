# Plot helpers used by the Shiny application (base graphics). They are
# internal but usable directly: rcli:::plot_leads(assessment, spec).

class_colours <- c(leading = "#1b7837", coincident = "#2166ac",
                   lagging = "#b35806", rejected = "#969696")

shade_contractions <- function(tp, ylim) {
  states <- as.numeric(cycle_states(tp))
  tm <- as.numeric(stats::time(tp@series))
  half <- 0.5 / stats::frequency(tp@series)
  shade <- grDevices::adjustcolor("grey70", alpha.f = 0.35)
  runs <- rle(states == 0 & !is.na(states))
  ends <- cumsum(runs$lengths)
  starts <- ends - runs$lengths + 1L
  for (k in which(runs$values)) {
    graphics::rect(tm[starts[k]] - half, ylim[1], tm[ends[k]] + half, ylim[2],
                   col = shade, border = NA)
  }
}

# All series indexed to 100 at their first observation (log scale).
plot_series_overview <- function(data, reference, tr = function(x) x) {
  x <- data
  for (j in seq_len(ncol(x))) x[, j] <- index_first(x[, j])
  cols <- grDevices::hcl.colors(ncol(x), "Dark 3")
  ref <- which(colnames(x) == reference)
  cols[ref] <- "black"
  lwd <- ifelse(seq_len(ncol(x)) == ref, 2.5, 1)
  rng <- range(x[x > 0], na.rm = TRUE)
  graphics::plot(as.numeric(stats::time(x)), as.numeric(x[, 1]), type = "n",
                 ylim = rng,
                 log = "y", xlab = "", ylab = tr("index (first value = 100)"))
  for (j in seq_len(ncol(x))) {
    graphics::lines(as.numeric(stats::time(x)), as.numeric(x[, j]),
                    col = cols[j], lwd = lwd[j])
  }
  graphics::legend("topleft", legend = colnames(x), col = cols, lwd = lwd,
                   bg = grDevices::adjustcolor("white", 0.8), box.col = NA,
                   cex = 0.8, ncol = 2)
}

# Normalised cycle of one series against the reference cycle.
plot_cycle_pair <- function(cycles, reference, name, ref_tp = NULL,
                            shift = 0, tr = function(x) x) {
  ref <- cycles[[reference]]@normalised
  cand <- cycles[[name]]@normalised
  if (shift != 0) cand <- as_ts_like(shift_vec(as.numeric(cand), shift), cand)
  ylim <- range(ref, cand, na.rm = TRUE)
  graphics::plot(ref, type = "n", ylim = ylim, xlab = "",
                 ylab = tr("normalised cycle"))
  if (!is.null(ref_tp)) shade_contractions(ref_tp, ylim)
  graphics::abline(h = 0, col = "grey60")
  graphics::lines(ref, lwd = 2)
  graphics::lines(cand, col = "firebrick", lwd = 1.5)
  lab <- if (shift != 0) {
    sprintf("%s (%s %+d)", name, tr("moved"), shift)
  } else {
    name
  }
  graphics::legend("topleft", legend = c(reference, lab),
                   col = c("black", "firebrick"), lwd = c(2, 1.5), bty = "n")
}

# Small multiples of all normalised cycles.
plot_cycles_grid <- function(cycles, tr = function(x) x) {
  n <- length(cycles)
  nc <- min(3L, n)
  old <- graphics::par(mfrow = c(ceiling(n / nc), nc),
                       mar = c(2, 2, 2, 1))
  on.exit(graphics::par(old))
  for (cs in cycles) {
    graphics::plot(cs@normalised, main = cs@name, xlab = "", ylab = "",
                   cex.main = 0.9)
    graphics::abline(h = 0, col = "grey60")
  }
}

# A cycle with its turning points over the reference contractions.
plot_turning_points <- function(tp, ref_tp, tr = function(x) x) {
  y <- as.numeric(tp@series)
  ylim <- range(y, na.rm = TRUE)
  graphics::plot(tp@series, type = "n", ylim = ylim, xlab = "",
                 ylab = tp@name)
  shade_contractions(ref_tp, ylim)
  graphics::lines(tp@series, lwd = 1.5)
  tp_marks(tp, y)
  graphics::legend("topleft", bty = "n", pch = c(25, 24, 15),
                   col = c("firebrick", "steelblue", "grey70"),
                   pt.bg = c("firebrick", "steelblue", "grey70"),
                   legend = c(tr("peak"), tr("trough"),
                              tr("reference contraction")))
}

# Cross-correlation lead of every candidate, coloured by class.
plot_leads <- function(assessment, spec, tr = function(x) x) {
  tab <- assessment@table
  tab <- tab[order(tab$ccf_lag), ]
  cols <- class_colours[tab$class]
  lab <- paste0(tab$name, ifelse(tab$inverted, "*", ""))
  rng <- range(c(tab$ccf_lag, -spec@min_lead, spec@min_lead), na.rm = TRUE)
  graphics::dotchart(tab$ccf_lag, labels = lab, color = cols, pch = 19,
                     xlim = rng + c(-1, 1),
                     xlab = tr("lead of the cross-correlation peak (periods)"))
  graphics::abline(v = c(-spec@min_lead, spec@min_lead), lty = 2,
                   col = "grey50")
  graphics::abline(v = 0, col = "grey70")
  graphics::legend("bottomright", legend = tr(names(class_colours)),
                   col = class_colours, pch = 19, bty = "n", cex = 0.8)
}

# Cross-correlations of a candidate with the reference at every lead.
plot_ccf <- function(cycles, reference, name, lag_max, tr = function(x) x) {
  cc <- cross_correlation(as.numeric(cycles[[name]]@normalised),
                          as.numeric(cycles[[reference]]@normalised),
                          lag_max)
  cols <- ifelse(cc$lags == cc$lag, "firebrick", "grey60")
  graphics::barplot(cc$all, names.arg = cc$lags, col = cols, border = NA,
                    ylim = c(-1, 1), xlab = tr("lead (periods; > 0: leads)"),
                    ylab = tr("correlation"), main = name)
  graphics::abline(h = 0)
}

# Composite index against the reference cycle on the same scale.
plot_composite <- function(composite, reference, ref_tp, tr = function(x) x,
                           label = "composite leading indicator") {
  idx <- composite@index
  ref <- 100 + reference@normalised * composite@amplitude
  if (is(composite@aggregator, "ConferenceBoard")) {
    idx <- 100 + composite@cycle * composite@amplitude
  }
  ylim <- range(idx, ref, na.rm = TRUE)
  graphics::plot(idx, type = "n", ylim = ylim, xlab = "",
                 ylab = tr("index (long-term average = 100)"))
  shade_contractions(ref_tp, ylim)
  graphics::abline(h = 100, col = "grey60")
  graphics::lines(ref, lwd = 1.5, col = "black")
  graphics::lines(idx, lwd = 2, col = "firebrick")
  graphics::legend("topleft", bty = "n", lwd = c(2, 1.5, 8),
                   col = c("firebrick", "black", "grey80"),
                   legend = c(tr(label),
                              tr("reference cycle"),
                              tr("reference contraction")))
}

plot_weights <- function(composite, tr = function(x) x) {
  w <- sort(composite@weights)
  n <- length(w)
  old <- graphics::par(mar = c(4, max(6, 0.6 * max(nchar(names(w)))), 1, 1))
  on.exit(graphics::par(old))
  mid <- graphics::barplot(w, horiz = TRUE, las = 1, col = "#1b7837",
                           border = NA, xlab = tr("weight"), cex.names = 0.85,
                           width = 1, space = 0.6, xlim = c(0, max(w) * 1.25),
                           ylim = c(0, max(n * 1.6 + 0.6, 4)))
  graphics::text(w, mid, sprintf("%.2f", w), pos = 4, cex = 0.8)
}

plot_components <- function(cycles, composite, tr = function(x) x) {
  comps <- composite@components
  ylim <- range(composite@cycle, vapply(comps, function(n) {
    range(cycles[[n]]@normalised, na.rm = TRUE)
  }, numeric(2)), na.rm = TRUE)
  graphics::plot(composite@cycle, type = "n", ylim = ylim, xlab = "",
                 ylab = tr("normalised cycle"))
  for (n in comps) {
    graphics::lines(cycles[[n]]@normalised,
                    col = grDevices::adjustcolor("grey40", 0.5))
  }
  graphics::lines(composite@cycle, col = "firebrick", lwd = 2)
  graphics::legend("topleft", bty = "n", lwd = c(2, 1),
                   col = c("firebrick", "grey60"),
                   legend = c(tr("composite"), tr("components")))
}

plot_audit <- function(audit, tr = function(x) x) {
  a <- audit[!is.na(audit$score) & !grepl("^(accepted|stopped)", audit$action),
             , drop = FALSE]
  if (nrow(a) == 0L) return(invisible(NULL))
  cols <- ifelse(a$passed, "#1b7837", "#b2182b")
  x <- seq_len(nrow(a))
  graphics::plot(x, a$score, type = "b", pch = 19, col = cols, xaxt = "n",
                 xlim = c(0.5, nrow(a) + 0.5), xlab = "", ylab = tr("score"))
  graphics::axis(1, at = x, labels = paste0(x, "\n(", a$n_components, ")"),
                 padj = 0.5)
  graphics::mtext(tr("step (number of components)"), side = 1, line = 3,
                  cex = 0.85)
  graphics::legend("bottomright", bty = "n", pch = 19, cex = 0.8,
                   col = c("#1b7837", "#b2182b"),
                   legend = c(tr("passes"), tr("fails")))
}

plot_probability <- function(prob, ref_tp, tr = function(x) x) {
  graphics::plot(prob$time, prob$probability, type = "n", ylim = c(0, 1),
                 xlab = "", ylab = tr("probability of contraction"))
  shade_contractions(ref_tp, c(0, 1))
  graphics::lines(prob$time, prob$probability, col = "firebrick", lwd = 1.5)
  graphics::abline(h = 0.5, lty = 2, col = "grey50")
}

plot_roc <- function(roc, auc, tr = function(x) x) {
  graphics::plot(roc$fpr, roc$tpr, type = "s", lwd = 2, col = "firebrick",
                 xlim = c(0, 1), ylim = c(0, 1), xaxs = "i", yaxs = "i",
                 xlab = tr("false positive rate"),
                 ylab = tr("true positive rate"),
                 main = sprintf("AUC = %.3f", auc))
  graphics::abline(0, 1, lty = 2, col = "grey50")
}

plot_selection_bias <- function(sb, tr = function(x) x) {
  if (nrow(sb) == 0L || all(is.na(sb$median_lead_out))) return(invisible(NULL))
  m <- rbind(sb$median_lead_in, sb$median_lead_out)
  m[is.na(m)] <- 0
  top <- max(1, m) * 1.35
  low <- min(0, m) * 1.1
  mid <- graphics::barplot(m, beside = TRUE, names.arg = sb$cutoff,
                           col = c("grey60", "#1b7837"), border = NA,
                           ylim = c(low, top), xlab = tr("cut-off"),
                           ylab = tr("median lead (periods)"))
  graphics::abline(h = 0)
  empty <- is.na(sb$median_lead_out)
  if (any(empty)) {
    graphics::text(colMeans(mid)[empty], top * 0.1, tr("no composite"),
                   cex = 0.8, col = "grey40")
  }
  graphics::legend("top", horiz = TRUE, bty = "n",
                   fill = c("grey60", "#1b7837"),
                   border = NA,
                   legend = c(tr("in sample"), tr("after cut-off")))
}

# A series as an index of its first value (100), or, when it has values at
# or below zero, as standardised deviations from its first value.
index_first <- function(v) {
  first <- v[which(!is.na(v))[1]]
  if (isTRUE(first > 0) && all(v > 0, na.rm = TRUE)) {
    100 * v / first
  } else {
    100 + (v - first) / stats::sd(v, na.rm = TRUE) * 10
  }
}

# Overview of series read from several files (read_cli_series()), each on
# its own dates, so that daily, monthly and quarterly series share one axis.
plot_series_dated <- function(series, reference, tr = function(x) x) {
  y <- lapply(series, function(s) index_first(s$value))
  dates <- do.call(c, lapply(series, `[[`, "date"))
  vals <- unlist(y)
  cols <- grDevices::hcl.colors(length(series), "Dark 3")
  ref <- which(names(series) == reference)
  cols[ref] <- "black"
  lwd <- ifelse(seq_along(series) == ref, 2.5, 1)
  graphics::plot(range(dates), range(vals[vals > 0], na.rm = TRUE),
                 type = "n", log = "y", xlab = "",
                 ylab = tr("index (first value = 100)"))
  for (j in seq_along(series)) {
    graphics::lines(series[[j]]$date, y[[j]], col = cols[j], lwd = lwd[j])
  }
  graphics::legend("topleft", legend = names(series), col = cols, lwd = lwd,
                   bg = grDevices::adjustcolor("white", 0.8), box.col = NA,
                   cex = 0.8, ncol = 2)
}

# One of the three OECD forms of the composite (cli_presentation()) next to
# the matching form of the reference series.
plot_presentation <- function(pres, form, tr = function(x) x) {
  cli <- pres[[form]]
  ref <- switch(form,
    amplitude_adjusted = 100 * pres$reference / pres$reference_trend,
    trend_restored = pres$reference,
    rate_of_change = pres$reference_rate_of_change)
  ylab <- switch(form,
    amplitude_adjusted = "index (trend of the reference = 100)",
    trend_restored = "level of the reference series",
    rate_of_change = "rate of change over a year (%)")
  ref_label <- switch(form,
    amplitude_adjusted = "reference series without trend",
    trend_restored = "reference series",
    rate_of_change = "rate of change of the reference series")
  ylim <- range(cli, ref, na.rm = TRUE)
  graphics::plot(pres$time, cli, type = "n", ylim = ylim, xlab = "",
                 ylab = tr(ylab))
  if (form == "amplitude_adjusted") graphics::abline(h = 100, col = "grey60")
  if (form == "rate_of_change") graphics::abline(h = 0, col = "grey60")
  if (form == "trend_restored") {
    graphics::lines(pres$time, pres$reference_trend, col = "grey55", lty = 2)
  }
  graphics::lines(pres$time, ref, lwd = 1.5, col = "black")
  graphics::lines(pres$time, cli, lwd = 2, col = "firebrick")
  leg <- c(tr("composite leading indicator"), tr(ref_label))
  col <- c("firebrick", "black")
  lty <- c(1, 1)
  if (form == "trend_restored") {
    leg <- c(leg, tr("trend of the reference series"))
    col <- c(col, "grey55")
    lty <- c(lty, 2)
  }
  graphics::legend("topleft", lwd = c(2, 1.5, 1)[seq_along(leg)],
                   lty = lty, col = col, legend = leg, box.col = NA,
                   bg = grDevices::adjustcolor("white", 0.85))
}
