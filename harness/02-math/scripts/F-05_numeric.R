# F-05: numerical verification of the sign rule and of the lead read after
# orientation. Run from the package root:
#   Rscript harness/02-math/scripts/F-05_numeric.R
# The sample study (regular and AR(2) cycles) is data-raw/evaluation_060.R,
# summarised in inst/calibration/test-size.csv (study "sign").
suppressMessages(devtools::load_all(quiet = TRUE))
ok <- TRUE
check <- function(cond, msg) {
  if (!isTRUE(cond)) {
    ok <<- FALSE
    cat("FAIL:", msg, "\n")
  }
}
lags <- -24:24

# 1. Lemma 1 in a large sample: cross_correlation() of x = s a c(t + l) + e
# against s kappa rho(k - l), for an AR(2) cycle with known autocorrelation
set.seed(5)
n <- 200000
phi <- c(1.2, -0.5)
cyc <- as.numeric(stats::arima.sim(list(ar = phi), n + 60))
rho <- stats::ARMAacf(ar = phi, lag.max = 60)
for (s in c(1, -1)) for (l in c(-5, 0, 6)) {
  idx <- 31:(30 + n)
  ref <- cyc[idx]
  x <- s * 0.7 * cyc[idx + l] + stats::rnorm(n, 0, 2)
  kappa <- 0.7 * stats::sd(ref) / stats::sd(x)
  cc <- rcli:::cross_correlation(x, ref, 24, peak_max = 24)
  theory <- s * kappa * rho[abs(lags - l) + 1]
  check(max(abs(cc$all - theory)) < 0.01,
        sprintf("Lemma 1, s = %d, l = %d", s, l))
}

# 2. Propositions 3 and 5 on sinusoids, including P not divisible by 4,
# with the opposite-phase peak made slightly stronger
for (P in c(18, 24, 30, 36, 42, 48, 60, 72)) {
  K <- floor(P / 4)
  for (ell in 0:K) for (s in c(1, -1)) for (sgn_l in c(1, -1)) {
    l <- sgn_l * ell
    if (abs(l) >= P / 4) next
    r <- s * 0.8 * cos(2 * pi * (lags - l) / P)
    anti <- lags[abs(abs(lags - l) - P / 2) < 1e-9]
    r[lags %in% anti] <- r[lags %in% anti] * (1 + 1e-9)
    check(rcli:::orient_sign(r, lags, K) == s,
          sprintf("Prop. 3: P=%d lead=%d s=%d", P, l, s))
    # Proposition 5: the oriented peak within floor(P/2) is the lead itself
    rs <- s * r
    inside <- abs(lags) <= min(24, floor(P / 2))
    k_dag <- lags[inside][which.max(rs[inside])]
    check(k_dag == l, sprintf("Prop. 5: P=%d lead=%d", P, l))
    if (length(anti) > 0L) {
      check(rcli:::orient_sign(r, lags, 24) == -s,
            sprintf("unrestricted rule picks antiphase: P=%d lead=%d", P, l))
    }
  }
  # Proposition 4: (s, l) and (-s, l - P/2) give identical r(k)
  if (P %% 2 == 0) {
    a <- 0.8 * cos(2 * pi * (lags - 3) / P)
    b <- -0.8 * cos(2 * pi * (lags - (3 - P / 2)) / P)
    check(max(abs(a - b)) < 1e-12, sprintf("Prop. 4: P=%d", P))
  }
}

# 3. the windows computed from the turning points of the reference
tp_of <- function(P) {
  date_turning_points(bry_boschan(),
                      stats::ts(sin(2 * pi * (1:480) / P), frequency = 12))
}
spec <- cli_spec(12)
check(abs(rcli:::reference_period(tp_of(48)) - 48) < 1e-9, "P-hat of a sine")
check(rcli:::sign_lag_max(tp_of(48), spec) == 12, "K = P/4")
check(rcli:::peak_lag_max(tp_of(48), spec) == 24, "peak window = P/2")
check(rcli:::sign_lag_max(tp_of(30), spec) == 7, "K for P = 30")
p30 <- rcli:::reference_period(tp_of(30))   # 29.97: dated turning points
check(rcli:::peak_lag_max(tp_of(30), spec) == floor(p30 / 2),
      "peak window for P = 30")
check(rcli:::sign_lag_max(tp_of(36), cli_spec(12, min_lead = 12)) == 9,
      "K does not grow with min_lead")
check(rcli:::sign_lag_max(tp_of(160), spec) == 24, "K capped at ccf_lag_max")
flat <- date_turning_points(bry_boschan(), stats::ts(1:60, frequency = 12))
check(is.na(rcli:::reference_period(flat)), "P-hat NA without cycles")
check(rcli:::sign_lag_max(flat, spec) == 24, "K = ccf_lag_max when P-hat NA")

# 4. tolerance to an overestimated cycle length (missed cycles): the rule
# needs floor(P-hat / 4) < P / 2 - |l|; with P-hat = 2P it fails, as stated
P <- 36
l <- 3
r <- 0.8 * cos(2 * pi * (lags - l) / P)
r[lags == l - P / 2] <- r[lags == l - P / 2] * (1 + 1e-9)
check(rcli:::orient_sign(r, lags, floor(1.5 * P / 4)) == 1,
      "P-hat = 1.5 P still identifies the sign")
check(rcli:::orient_sign(r, lags, floor(2 * P / 4)) == -1,
      "P-hat = 2 P breaks the rule (documented limit)")
cat(if (ok) "PASS" else "FAIL", "\n")
