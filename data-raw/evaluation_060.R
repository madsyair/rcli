# Evidence for FR-012 (rcli 0.6.0): sign rule, size and power of the
# concordance and Pesaran-Timmermann tests, and out-of-sample prediction
# criteria, on simulated pairs with known truth. Run from the package root:
#   Rscript data-raw/evaluation_060.R
# Output: inst/calibration/test-size.csv (one row per statistic).
devtools::load_all(quiet = TRUE)
reps <- as.integer(Sys.getenv("RCLI_REPS", "100"))
rows <- list()
add <- function(study, setting, series, statistic, value, n) {
  rows[[length(rows) + 1L]] <<- data.frame(
    study = study, setting = setting, series = series, statistic = statistic,
    value = round(value, 4), reps = n)
}
meta_of <- function(x) {
  data.frame(name = colnames(x)[-1], rationale = "early_stage")
}

# ---- 1. sign of a series (F-05) -------------------------------------------
regular <- function(P, s, n = 360, noise = 0.4) {
  set.seed(s)
  t <- seq_len(n + 80)
  c0 <- sin(2 * pi * t / P + cumsum(stats::rnorm(length(t), 0, 0.02)))
  g <- function(sh, sgn = 1) {
    idx <- (41:(40 + n)) + sh
    100 * exp(0.002 * seq_len(n) + 0.04 * (sgn * c0[idx] + noise *
      as.numeric(stats::arima.sim(list(ar = 0.5), n))))
  }
  stats::ts(cbind(reference = g(0), l3 = g(3), l6 = g(6), l9 = g(9),
                  l12 = g(12), c4 = g(4, -1), c9 = g(9, -1)),
            start = 1995, frequency = 12)
}
truth <- c(l3 = 1, l6 = 1, l9 = 1, l12 = 1, c4 = -1, c9 = -1)
# rule A (0.5.1): strongest correlation within +/- ccf_lag_max; F05: the
# package rule; C: the orientation with more matched minus extra turning
# points (ties: F05), a rejected alternative
sign_errors <- function(gen, label, n_rep) {
  err <- matrix(0, length(truth), 3, dimnames = list(names(truth),
                                                       c("A", "F05", "C")))
  for (s in seq_len(n_rep)) {
    x <- gen(s)
    cand <- cli_candidates(x, "reference", meta = meta_of(x))
    spec <- cli_spec(12)
    cyc <- suppressWarnings(cli_cycles(cand, spec))
    tps <- cli_turning_points(cyc, spec)
    k_sign <- sign_lag_max(tps$reference, spec)
    ref <- as.numeric(cyc$reference@normalised)
    e <- resolve_dater(spec@dater, spec@freq)$end_exclusion
    score <- function(cs) {
      tp <- date_turning_points(spec@dater, cs@normalised)
      m <- match_turning_points(tps$reference, tp, spec@lead_window, e)
      sum(!is.na(m$pairs$lead)) - m$n_extra
    }
    for (nm in names(truth)) {
      cc <- cross_correlation(as.numeric(cyc[[nm]]@normalised), ref,
                              spec@ccf_lag_max, 24L)
      a <- sign(cc$all[which.max(abs(cc$all))])
      b <- orient_sign(cc$all, cc$lags, k_sign)
      sc <- c(score(cyc[[nm]]), score(invert_cycle(cyc[[nm]])))
      c3 <- if (sc[1] != sc[2]) c(1, -1)[which.max(sc)] else b
      err[nm, ] <- err[nm, ] + c(a != truth[[nm]], b != truth[[nm]],
                                 c3 != truth[[nm]])
    }
  }
  for (nm in names(truth)) for (rule in colnames(err)) {
    add("sign", label, nm, paste0("error_", rule), err[nm, rule] / n_rep,
        n_rep)
  }
}
for (P in c(36, 48, 72)) {
  sign_errors(function(s) regular(P, s), sprintf("regular P=%d", P),
              min(reps, 20L))
}
for (noise in c(0.4, 0.8)) {
  sign_errors(function(s) {
    simulate_cycles(seed = s, noise_sd = noise,
                    leads = c(l3 = 3, l6 = 6, l9 = 9, l12 = 12),
                    counter = c(c4 = 4, c9 = 9), n_noise = 0)
  }, sprintf("AR(2) 4 years noise=%.1f", noise), min(reps, 20L))
}

# ---- 2. concordance and direction tests (F-06) -----------------------------
# t statistic with a Bartlett HAC of bandwidth b n, and the one-sided 95%
# critical value of the Kiefer-Vogelsang (2005) response surface, for the
# choice of b (the package uses b = 0.3 and its simulated table)
t_fixed_b <- function(y, x, b) {
  n <- length(y)
  if (stats::var(x) == 0 || stats::var(y) == 0) return(NA_real_)
  xm <- cbind(1, x)
  fit <- stats::lm.fit(xm, y)
  u <- xm * fit$residuals
  m <- b * n
  s <- crossprod(u)
  for (l in seq_len(ceiling(m) - 1L)) {
    g <- crossprod(u[(l + 1L):n, , drop = FALSE], u[1:(n - l), , drop = FALSE])
    s <- s + (1 - l / m) * (g + t(g))
  }
  bread <- solve(crossprod(xm))
  v <- bread %*% s %*% bread
  fit$coefficients[[2]] / sqrt(v[2, 2])
}
kv_cv95 <- function(b) 1.6449 + 2.1859 * b + 0.3142 * b^2 - 0.3427 * b^3
markov <- function(n, pr) {
  s <- integer(n)
  s[1] <- stats::rbinom(1, 1, 0.5)
  sw <- stats::runif(n) < pr
  for (t in 2:n) s[t] <- if (sw[t]) 1L - s[t - 1] else s[t - 1]
  s
}
set.seed(20261102)
for (n in c(120, 360)) for (pr in c(1 / 12, 1 / 24)) {
  sims <- replicate(2000, {
    y <- markov(n, pr)
    x <- markov(n, pr)
    c(table = isTRUE(hac_fixed_b_p(y, x) < 0.05),
      vapply(c(0.1, 0.2, 0.3, 0.5), function(b) {
        tt <- t_fixed_b(y, x, b)
        isTRUE(tt > kv_cv95(b))
      }, logical(1)))
  })
  rownames(sims) <- c("fixedb_table", paste0("kv_b", c(0.1, 0.2, 0.3, 0.5)))
  for (st in rownames(sims)) {
    add("size-markov", sprintf("n=%d switch=1/%d", n, round(1 / pr)),
        "independent", paste0("reject_", st), mean(sims[st, ]), 2000)
  }
}
nw_p <- function(y, x) {
  n <- length(y)
  xm <- cbind(1, x)
  fit <- stats::lm.fit(xm, y)
  u <- xm * fit$residuals
  bw <- floor(4 * (n / 100)^(2 / 9))
  s <- crossprod(u)
  for (l in seq_len(bw)) {
    g <- crossprod(u[(l + 1L):n, , drop = FALSE], u[1:(n - l), , drop = FALSE])
    s <- s + (1 - l / (bw + 1)) * (g + t(g))
  }
  b <- solve(crossprod(xm))
  v <- b %*% s %*% b
  tt <- fit$coefficients[2] / sqrt(v[2, 2])
  stats::pnorm(tt, lower.tail = FALSE)
}
for (freq in c(12, 4)) {
  rej <- matrix(0, 2, 4, dimnames = list(c("independent", "lead"),
    c("nw_median", "fixedb_median", "nw_fixed", "fixedb_fixed")))
  n_na <- c(independent = 0, lead = 0)
  for (s in seq_len(reps)) {
    a <- simulate_cycles(seed = s, freq = freq)
    b <- simulate_cycles(seed = s + 10000L, freq = freq)
    lead_nm <- colnames(a)[2]
    x <- stats::ts(cbind(reference = a[, "reference"],
                         independent = b[, "reference"],
                         lead = a[, lead_nm]),
                   start = stats::start(a), frequency = freq)
    spec <- cli_spec(freq)
    cyc <- suppressWarnings(cli_cycles(cli_candidates(x, "reference",
                                                      meta = meta_of(x)),
                                       spec))
    tps <- cli_turning_points(cyc, spec)
    sy <- as.numeric(cycle_states(tps$reference))
    for (nm in c("independent", "lead")) {
      row <- assess_pair(cyc$reference, tps$reference, cyc[[nm]], tps[[nm]],
                         spec)$row
      sh <- if (is.na(row$median_lead)) 0L else
        as.integer(round(row$median_lead))
      fixed <- if (nm == "lead") as.integer(round(spec@freq / 2)) else 0L
      for (k in c("median", "fixed")) {
        shift <- if (k == "median") sh else fixed
        sx <- shift_vec(as.numeric(cycle_states(tps[[nm]])), shift)
        ok <- !is.na(sx) & !is.na(sy)
        rej[nm, paste0("nw_", k)] <- rej[nm, paste0("nw_", k)] +
          (nw_p(sy[ok], sx[ok]) < 0.05)
        p_fb <- hac_fixed_b_p(sy[ok], sx[ok])
        n_na[nm] <- n_na[nm] + is.na(p_fb)
        rej[nm, paste0("fixedb_", k)] <- rej[nm, paste0("fixedb_", k)] +
          isTRUE(p_fb < 0.05)
      }
    }
  }
  for (nm in rownames(rej)) {
    for (st in colnames(rej)) {
      add("concordance", sprintf("freq=%d", freq), nm,
          paste0("reject_", st), rej[nm, st] / reps, reps)
    }
    add("concordance", sprintf("freq=%d", freq), nm, "fixedb_p_missing",
        n_na[[nm]] / (2 * reps), reps)
  }
}

# ---- 3. prediction criteria of a composite (F-06, F-07) --------------------
pt92 <- function(cli, ref, h) {
  dx <- shift_vec(c(NA, diff(cli)), as.integer(h))
  dy <- c(NA, diff(ref))
  ok <- !is.na(dx) & !is.na(dy) & dx != 0 & dy != 0
  n <- sum(ok)
  px <- mean(dx[ok] > 0)
  py <- mean(dy[ok] > 0)
  ph <- mean((dx[ok] > 0) == (dy[ok] > 0))
  ps <- py * px + (1 - py) * (1 - px)
  v <- ps * (1 - ps) / n - ((2 * py - 1)^2 * px * (1 - px) / n +
    (2 * px - 1)^2 * py * (1 - py) / n + 4 * py * px * (1 - py) * (1 - px) /
      n^2)
  stats::pnorm((ph - ps) / sqrt(v), lower.tail = FALSE)
}
res <- list()
for (s in seq_len(reps)) {
  a <- simulate_cycles(seed = s)
  b <- simulate_cycles(seed = s + 10000L)
  x <- stats::ts(cbind(reference = a[, "reference"], i1 = b[, "lead_6"],
                       i2 = b[, "lead_3"], lead_6 = a[, "lead_6"],
                       lead_3 = a[, "lead_3"]),
                 start = stats::start(a), frequency = 12)
  spec <- cli_spec(12)
  cyc <- suppressWarnings(cli_cycles(cli_candidates(x, "reference",
                                                    meta = meta_of(x)), spec))
  ref_tp <- date_turning_points(spec@dater, cyc$reference@normalised)
  for (set in list(c("i1", "i2"), c("lead_6", "lead_3"))) {
    comp <- cli_composite(cyc, set, spec, cyc$reference)
    cli <- as.numeric(comp@cycle)
    ref <- as.numeric(cyc$reference@normalised)
    ins <- contraction_fit(cli, ref_tp, 6, 3, recursive = FALSE)
    k <- !is.na(ins$probability)
    v <- cli_validate(comp, cyc$reference, spec)@probability
    cc <- cross_correlation(cli, ref, spec@ccf_lag_max, 24L)
    h_data <- max(1, cc$lag)
    res[[length(res) + 1L]] <- data.frame(
      set = if (set[1] == "i1") "independent" else "lead",
      in_auc = auc_score(ins$probability[k], ins$contraction[k]) >= 0.7,
      in_qps = 2 * mean((ins$probability[k] - ins$contraction[k])^2) <
        2 * mean((mean(ins$contraction[k]) - ins$contraction[k])^2),
      pt92_data_h = pt92(cli, ref, h_data) < 0.05,
      oos_auc = isTRUE(v$auc >= 0.7),
      oos_qps = isTRUE(v$qps < v$qps_naive),
      pt_fixedb = isTRUE(v$pt_p < 0.05),
      pt_fixedb_data_h = isTRUE(pesaran_timmermann(cli, ref, h_data)$p_value <
                                  0.05))
  }
}
res <- do.call(rbind, res)
res$in_all <- res$in_auc & res$in_qps & res$pt92_data_h
res$oos_all <- res$oos_auc & res$oos_qps & res$pt_fixedb
for (st in unique(res$set)) {
  d <- res[res$set == st, ]
  for (col in setdiff(names(d), "set")) {
    add("prediction", "freq=12", st, paste0("pass_", col), mean(d[[col]]),
        reps)
  }
}
out <- do.call(rbind, rows)
utils::write.csv(out, "inst/calibration/test-size.csv", row.names = FALSE)
print(out)
