# Validation of rcli against the OECD composite leading indicator (CLI) of
# Indonesia. Run from the package root after data-raw/oecd_idn_fetch.R:
#   Rscript data-raw/oecd_idn_validate.R
#
# The OECD publishes, for Indonesia, the CLI, its reference series (monthly
# GDP) and its seven components, the components only as normalised cycles.
# Two experiments:
#   A. OECD cycles in: the OECD's normalised components and reference cycle
#      go into rcli as cycles. Tests the sign of each component, the
#      classification, the OECD aggregation (oecd_aggregate()), the
#      amplitude adjustment and turning points against the published CLI.
#      A0 is the rule of rcli 0.7.0 (arithmetic growth, mean absolute
#      deviation); A1 the oecd_spec() of FR-014 (log growth with reciprocal
#      inversion, standard deviation).
#   B. Original series in: the four components whose original series the
#      OECD also publishes (share prices, call-money rate, rupiah per US
#      dollar, consumer confidence) and quarterly GDP go through the whole
#      OECD specification of rcli (oecd_spec()). Tests cycle extraction
#      against the OECD's cycles and the composite of the four.
# Outputs in inst/calibration/:
#   oecd-idn-components.csv   A and B per component
#   oecd-idn-composite.csv    composites against the published CLI
#   oecd-idn-turning-points.csv  turning points of the CLI and composites
#   oecd-idn-gaps.csv         C. sources of the remaining differences
#                             (aggregation formula, amplitude, ragged edge)
devtools::load_all(quiet = TRUE)
d <- utils::read.csv("data-raw/oecd-idn/oecd-idn.csv",
                     stringsAsFactors = FALSE)

# ---- data ---------------------------------------------------------------------
monthly <- function(measure, adjustment, dataflow = "DF_CLI") {
  s <- d[d$measure == measure & d$adjustment == adjustment &
           d$dataflow == dataflow & d$transformation != "GY", ]
  s <- s[order(s$period), ]
  st <- as.integer(strsplit(s$period[1], "-")[[1]])
  out <- stats::ts(NA_real_, start = st, frequency = 12,
                   end = as.integer(strsplit(s$period[nrow(s)], "-")[[1]]))
  tm <- st[1] + (st[2] - 1) / 12 + seq_along(out) / 12 - 1 / 12
  lab <- sprintf("%d-%02d", floor(tm + 1e-6), round((tm %% 1) * 12) + 1L)
  out[match(s$period, lab)] <- s$value
  out
}
comps <- c(LOCOCI = "Consumer confidence", LOCOEX = "Exchange rate",
           LOCOPM = "Production of non-metallic products",
           LOCOPP = "Producer prices", LOCOSP = "Share prices",
           LOCOST = "Short-term interest rate", LOCOTA = "Tourism activity")
nor <- do.call(cbind, c(list(LI = monthly("LI", "NOR"),
                             LI_AA = monthly("LI", "AA"),
                             RS = monthly("RS", "NOR")),
                        lapply(stats::setNames(names(comps), names(comps)),
                               monthly, adjustment = "NOR")))

# A CycleSeries from a published OECD cycle (index around 100).
as_cycle <- function(x, name) {
  x <- x - 100
  new("CycleSeries", name = name, original = x, transformed = x, cycle = x,
      normalised = normalise_cycle(x), steps = "OECD normalised cycle")
}
# all comparisons on the monthly time base of the OECD data
on_base <- function(x) {
  stats::window(x, start = stats::start(nor), end = stats::end(nor),
                extend = TRUE)
}
corr_at <- function(a, b, k = 0L) {
  a <- shift_vec(as.numeric(on_base(a)), k)
  b <- as.numeric(on_base(b))
  ok <- !is.na(a) & !is.na(b)
  stats::cor(a[ok], b[ok])
}
date_tp <- function(x, name) {
  date_turning_points(dater, on_base(x), name = name)
}
peak <- function(a, b, lags = -12:12) {
  r <- vapply(lags, corr_at, numeric(1), a = a, b = b)
  c(lag = lags[which.max(r)], r = max(r), r0 = r[lags == 0])
}
tp_agreement <- function(ref, cand, spec, window = 3L) {
  m <- match_turning_points(ref, cand, c(window, window), 0L)
  p <- m$pairs
  data.frame(ref_tp = nrow(p), matched = sum(!is.na(p$lead)),
             missed = sum(is.na(p$lead)), extra = m$n_extra,
             mean_abs_gap = mean(abs(p$lead), na.rm = TRUE),
             median_lead = stats::median(p$lead, na.rm = TRUE))
}
spec_a <- oecd_spec()
dater <- spec_a@dater

# ---- A. OECD cycles in ------------------------------------------------------------
cyc_a <- c(list(RS = as_cycle(nor[, "RS"], "RS")),
           lapply(stats::setNames(names(comps), names(comps)),
                  function(nm) as_cycle(nor[, nm], nm)))
meta <- data.frame(name = names(comps), rationale = "early_stage")
data_a <- nor[, c("RS", names(comps))]
cand_a <- cli_candidates(data_a, "RS", meta = meta)
spec_median <- update(spec_a,
                      classifier = oecd_classifier(conformity = FALSE))
ass_a <- list(oecd = cli_assess(cand_a, spec_a, cycles = cyc_a),
              median = cli_assess(cand_a, spec_median, cycles = cyc_a),
              rcli = cli_assess(cand_a, cli_spec(freq = 12), cycles = cyc_a))
# the same with the OECD's signs given as economic priors (meta$sign)
meta_sign <- meta
meta_sign$sign <- ifelse(meta$name %in% c("LOCOEX", "LOCOST", "LOCOPP"),
                         -1, 1)
cand_sign <- cli_candidates(data_a, "RS", meta = meta_sign)
ass_sign <- cli_assess(cand_sign, spec_a, cycles = cyc_a)
cyc_sign <- cyc_a
for (nm in ass_sign@inverted) cyc_sign[[nm]] <- invert_cycle(cyc_sign[[nm]])
inv_a <- ass_a$oecd@inverted
cyc_inv <- cyc_a
for (nm in inv_a) cyc_inv[[nm]] <- invert_cycle(cyc_inv[[nm]])

# the reference cycle in percent deviation from trend (ratio to trend), for
# the amplitude adjustment
rt <- on_base(monthly("RS", "RT"))
ref_rt <- new("CycleSeries", name = "RS", original = rt, transformed = rt,
              cycle = rt - 100, normalised = normalise_cycle(rt - 100),
              steps = "OECD ratio to trend")
spec_070 <- update(spec_a, aggregator = oecd_aggregate(growth = "ratio"),
                   amplitude = "mad")
li <- as_cycle(nor[, "LI"], "LI")
li_tp <- date_tp(li@normalised, "LI")
rs_tp <- date_tp(cyc_a$RS@normalised, "RS")
composite_row <- function(label, ci) {
  cc <- composite_as_cycle(ci)
  tp <- date_tp(cc@normalised, label)
  p <- peak(cc@normalised, li@normalised)
  aa <- mean(abs(as.numeric(on_base(ci@index)) - as.numeric(nor[, "LI_AA"])),
            na.rm = TRUE)
  e <- as.numeric(on_base(cc@normalised)) - as.numeric(li@normalised)
  data.frame(composite = label, n_components = length(ci@components),
             corr_lag0 = p[["r0"]], best_lag = p[["lag"]],
             corr_best = p[["r"]], aa_gap = aa,
             mad_gap = mean(abs(e), na.rm = TRUE),
             tp_agreement(li_tp, tp, spec_a),
             vs_reference(tp, cc@normalised))
}
# against the OECD reference series: turning points matched within the
# lead window of oecd_spec() (12 months after, 24 before) and the lead of
# the cross-correlation peak
vs_reference <- function(tp, x) {
  m <- match_turning_points(rs_tp, tp, spec_a@lead_window, 0L)
  p <- peak(x, cyc_a$RS@normalised, -12:24)
  data.frame(ref_tp_rs = nrow(m$pairs),
             ref_matched = sum(!is.na(m$pairs$lead)), ref_extra = m$n_extra,
             ref_median_lead = stats::median(m$pairs$lead, na.rm = TRUE),
             ref_ccf_lag = p[["lag"]], ref_ccf_r = p[["r"]])
}
oecd_signs <- c(LOCOEX = -1, LOCOST = -1, LOCOPP = -1)
cyc_true <- cyc_a
for (nm in names(oecd_signs)) cyc_true[[nm]] <- invert_cycle(cyc_true[[nm]])
benchmark <- new("CompositeIndex", index = nor[, "LI_AA"],
                 cycle = li@normalised,
                 components = names(comps), weights = rep(1 / 7, 7),
                 aggregator = oecd_aggregate(), amplitude = 1)
comp_a <- rbind(
  composite_row("OECD published CLI (benchmark)", benchmark),
  composite_row("A0 OECD components, OECD signs, rcli 0.7.0 rule",
                cli_composite(cyc_true, names(comps), spec_070, ref_rt)),
  composite_row("A1 OECD components, OECD signs, oecd_spec()",
                cli_composite(cyc_true, names(comps), spec_a, ref_rt)),
  composite_row("A2 OECD components, signs found by rcli, oecd_aggregate()",
                cli_composite(cyc_inv, names(comps), spec_a, ref_rt)),
  composite_row("A3 OECD components, signs from meta$sign, oecd_aggregate()",
                cli_composite(cyc_sign, names(comps), spec_a, ref_rt)),
  composite_row("A4 OECD components, OECD signs, equal_weight()",
                cli_composite(cyc_true, names(comps),
                              update(spec_a, aggregator = equal_weight()),
                              ref_rt))
)

# ---- B. original series in ------------------------------------------------------
fin <- function(m) monthly(m, "_Z", "DF_FINMARK")
gdp <- d[d$dataflow == "DF_QNA", ]
gdp <- stats::ts(gdp$value[order(gdp$period)], frequency = 4,
                 start = as.integer(strsplit(min(gdp$period), "-Q")[[1]]))
orig <- list(gdp = gdp, LOCOSP = fin("SHARE"), LOCOST = fin("IRSTCI"),
             LOCOEX = fin("CC"), LOCOCI = monthly("CCICP", "Y", "DF_CS"))
data_b <- cli_align(orig, type = c(gdp = "flow", LOCOST = "average"),
                    reference = "gdp")
meta_b <- data.frame(name = names(orig)[-1], rationale = "early_stage")
cand_b <- cli_candidates(data_b, "gdp", meta = meta_b)
spec_b <- oecd_spec(engine = "auto")
res_b <- cli_build(cand_b, spec_b)
cyc_b <- cli_cycles(cand_b, spec_b)

# per component
row_comp <- function(nm) {
  row <- function(a) {
    t <- as.data.frame(a)
    t[t$name == nm, ]
  }
  ra <- row(ass_a$oecd)
  rr <- row(ass_a$rcli)
  out <- data.frame(
    component = nm, label = comps[[nm]],
    oecd_sign = if (nm %in% names(oecd_signs)) "inverted" else "as is",
    rcli_sign = if (nm %in% inv_a) "inverted" else "as is",
    A_class_oecd_rule = ra$class,
    A_class_oecd_median_rule = row(ass_a$median)$class,
    A_class_rcli_rule = rr$class, A_reasons_oecd_rule = ra$reasons,
    A_median_lead = ra$median_lead, A_ccf_lag = rr$ccf_lag,
    A_ccf_r = rr$ccf_r,
    B_original = NA_character_, B_corr_with_oecd_cycle = NA_real_,
    B_best_lag = NA_real_, B_tp_matched = NA_real_, B_tp_oecd = NA_real_)
  if (nm %in% names(cyc_b)) {
    s <- if (nm %in% names(oecd_signs)) -1 else 1
    p <- peak(s * cyc_b[[nm]]@normalised, cyc_true[[nm]]@normalised, -6:6)
    tp_o <- date_tp(cyc_true[[nm]]@normalised, nm)
    tp_r <- date_tp(s * cyc_b[[nm]]@normalised, nm)
    g <- tp_agreement(tp_o, tp_r, spec_a)
    out$B_original <- c(LOCOSP = "SHARE (index)", LOCOST = "IRSTCI (% p.a.)",
                        LOCOEX = "CC (IDR per USD)",
                        LOCOCI = "CCICP (balance)")[[nm]]
    out$B_corr_with_oecd_cycle <- p[["r0"]]
    out$B_best_lag <- p[["lag"]]
    out$B_tp_matched <- g$matched
    out$B_tp_oecd <- g$ref_tp
  }
  out
}
tab_comp <- do.call(rbind, lapply(names(comps), row_comp))
ref_row <- {
  p <- peak(cyc_b$gdp@normalised, cyc_a$RS@normalised, -6:6)
  tp_r <- date_tp(cyc_b$gdp@normalised, "gdp")
  g <- tp_agreement(rs_tp, tp_r, spec_a)
  data.frame(component = "RS", label = "Reference series (GDP)",
             oecd_sign = "as is", rcli_sign = "as is",
             A_class_oecd_rule = "reference",
             A_class_oecd_median_rule = "reference",
             A_class_rcli_rule = "reference", A_reasons_oecd_rule = "",
             A_median_lead = NA, A_ccf_lag = NA, A_ccf_r = NA,
             B_original = "B1GQ quarterly (Denton-Cholette to monthly)",
             B_corr_with_oecd_cycle = p[["r0"]], B_best_lag = p[["lag"]],
             B_tp_matched = g$matched, B_tp_oecd = g$ref_tp)
}
tab_comp <- rbind(ref_row, tab_comp)

# composites from original series: four components, OECD signs; and the
# composite chosen by cli_build()
four <- names(orig)[-1]
cyc_b4 <- cyc_b
for (nm in intersect(four, names(oecd_signs))) {
  cyc_b4[[nm]] <- invert_cycle(cyc_b4[[nm]])
}
cyc_a4 <- cyc_true[c("RS", four)]
tab_compo <- rbind(
  comp_a,
  composite_row("A5 OECD cycles of the four components of B",
                cli_composite(cyc_a4, four, spec_a, ref_rt)),
  composite_row("B1 four original series, oecd_spec(), OECD signs",
                cli_composite(cyc_b4, four, spec_b, cyc_b4$gdp)),
  composite_row(paste0("B2 cli_build(): ",
                       paste(composite(res_b)@components, collapse = "+")),
                composite(res_b))
)

# turning points of the published CLI, the reference and composite A1
ci_a1 <- cli_composite(cyc_true, names(comps), spec_a, ref_rt)
tp_a1 <- date_tp(composite_as_cycle(ci_a1)@normalised, "A1")
tp_tab <- do.call(rbind, lapply(list(RS = rs_tp, LI = li_tp, A1 = tp_a1),
                                as.data.frame))
tp_tab$series <- rep(c("RS (OECD reference)", "LI (OECD CLI)",
                       "A1 (rcli composite)"),
                     c(length(rs_tp@index), length(li_tp@index),
                       length(tp_a1@index)))
tp_tab <- tp_tab[, c("series", "period", "type")]

# ---- C. where the remaining gaps come from -------------------------------------
# C1 aggregation: rcli 0.7.0 chained the arithmetic growth of z + 100 and
# inverted by changing the sign of z; oecd_aggregate(growth = "log") chains
# log growth with reciprocal inversion (R/aggregate.R, OecdAggregate).
# Variants on the published components, inverted by the OECD signs, are
# compared with the published normalised CLI.
pub <- nor[, names(comps)]
sgn <- ifelse(colnames(pub) %in% names(oecd_signs), -1, 1)
mirror <- sweep(pub - 100, 2, sgn, "*") + 100
recip <- pub
recip[, sgn < 0] <- 100^2 / pub[, sgn < 0]
chain_growth <- function(lv, log_growth, min_coverage = 0.6) {
  n <- nrow(lv)
  g <- if (log_growth) log(lv[-1, ] / lv[-n, ]) else lv[-1, ] / lv[-n, ] - 1
  g <- c(NA, rowMeans(g, na.rm = TRUE))
  g[!is.finite(g)] <- NA
  cover <- rowSums(!is.na(lv)) / ncol(lv)
  idx <- rep(NA_real_, n)
  for (t in seq_len(n)) {
    if (cover[t] < min_coverage) next
    idx[t] <- if (t > 1L && !is.na(idx[t - 1L]) && !is.na(g[t])) {
      idx[t - 1L] * (if (log_growth) exp(g[t]) else 1 + g[t])
    } else {
      mean(lv[t, ], na.rm = TRUE)
    }
  }
  normalise_cycle(idx - 100)
}
gap_row <- function(label, x) {
  y <- as.numeric(li@normalised)
  ok <- !is.na(x) & !is.na(y)
  data.frame(experiment = "C1 aggregation", variant = label,
             value = stats::cor(x[ok], y[ok]),
             mad_gap = mean(abs(x[ok] - y[ok])))
}
gaps <- rbind(
  gap_row("arithmetic growth, sign inversion (growth = \"ratio\", 0.7.0)",
          chain_growth(mirror, FALSE)),
  gap_row("arithmetic growth, reciprocal inversion",
          chain_growth(recip, FALSE)),
  gap_row("log growth, sign inversion", chain_growth(mirror, TRUE)),
  gap_row("log growth, reciprocal inversion (growth = \"log\")",
          chain_growth(recip, TRUE)),
  gap_row("plain average of the available components",
          normalise_cycle(rowMeans(mirror, na.rm = TRUE) - 100))
)
# C2 amplitude adjustment: the published amplitude-adjusted CLI is the
# normalised CLI times a factor; cli_spec(amplitude =) chooses the mean
# absolute deviation or the standard deviation (R/aggregate.R,
# reference_amplitude()).
rt <- monthly("RS", "RT")
both <- stats::ts.intersect(rt, nor[, "LI"], nor[, "LI_AA"])
both <- both[stats::complete.cases(both), ]
fit <- stats::coef(stats::lm(I(both[, 3] - 100) ~ 0 + I(both[, 2] - 100)))
mad <- function(v) mean(abs(v - mean(v)))
gaps <- rbind(gaps, data.frame(
  experiment = "C2 amplitude",
  variant = c("OECD factor (amplitude-adjusted CLI on normalised CLI)",
              "ratio of mean absolute deviations (amplitude = \"mad\")",
              "ratio of standard deviations (amplitude = \"sd\")"),
  value = c(fit[[1]], mad(both[, 1]) / mad(both[, 2]),
            stats::sd(both[, 1]) / stats::sd(both[, 2])),
  mad_gap = NA_real_))
# C3 ragged edge: components available at the last dates of the CLI
last <- utils::tail(which(!is.na(nor[, "LI"])), 3)
gaps <- rbind(gaps, data.frame(
  experiment = "C3 ragged edge",
  variant = sprintf("%d-%02d: components available (of 7)",
                    as.integer(stats::time(nor)[last] %/% 1),
                    as.integer(round(stats::time(nor)[last] %% 1 * 12)) + 1L),
  value = rowSums(!is.na(pub[last, ])), mad_gap = NA_real_))
num <- vapply(gaps, is.numeric, logical(1))
gaps[num] <- lapply(gaps[num], round, 5)

num <- vapply(tab_comp, is.numeric, logical(1))
tab_comp[num] <- lapply(tab_comp[num], round, 3)
num <- vapply(tab_compo, is.numeric, logical(1))
tab_compo[num] <- lapply(tab_compo[num], round, 3)
write_out <- function(x, f) {
  utils::write.csv(x, file.path("inst/calibration", f), row.names = FALSE)
}
write_out(tab_comp, "oecd-idn-components.csv")
write_out(tab_compo, "oecd-idn-composite.csv")
write_out(tp_tab, "oecd-idn-turning-points.csv")
write_out(gaps, "oecd-idn-gaps.csv")
print(gaps)
print(tab_comp)
print(tab_compo)
print(tp_tab)
print(res_b)
