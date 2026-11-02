# F-07: the recursive out-of-sample logit equals manual glm() fits.
# Run from the package root: Rscript harness/02-math/scripts/F-07_numeric.R
suppressMessages(devtools::load_all(quiet = TRUE))
ok <- TRUE
set.seed(11)
for (h in c(0L, 1L, 6L)) {
  n <- 150
  x <- cumsum(stats::rnorm(n))
  x[c(5, 40)] <- NA
  y <- as.numeric(stats::runif(n) < stats::plogis(-0.3 * x))
  out <- rcli:::recursive_logit(y, x, h)
  obs <- which(!is.na(x) & !is.na(y))
  t0 <- obs[ceiling(0.4 * length(obs))]
  g <- max(h, 1L)
  for (t in obs[obs > t0]) {
    tr <- obs[obs <= t - g]
    fit <- suppressWarnings(stats::glm(y[tr] ~ x[tr],
                                       family = stats::binomial()))
    p <- unname(stats::plogis(sum(stats::coef(fit) * c(1, x[t]))))
    if (abs(out$probability[t] - p) > 1e-6 ||
        abs(out$naive[t] - mean(y[tr])) > 1e-12) {
      ok <- FALSE
      cat("FAIL at h =", h, "t =", t, "\n")
    }
  }
  if (any(!is.na(out$probability[seq_len(t0)]))) {
    ok <- FALSE
    cat("FAIL: forecast before t0 at h =", h, "\n")
  }
}
cat(if (ok) "PASS" else "FAIL", "\n")
