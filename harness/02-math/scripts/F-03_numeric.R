# F-03 numeric verification: banded LDL' HP solver vs the dense solve() of
# rcli 0.2.0. Run from the package root: Rscript harness/02-math/scripts/F-03_numeric.R
devtools::load_all(quiet = TRUE)
dense <- function(x, lambda) {
  n <- length(x)
  a <- diag(n) + lambda * crossprod(diff(diag(n), differences = 2))
  list(tau = as.numeric(solve(a, x)), a = a)
}
# normwise backward error (Higham 2002, sec. 7.1)
eta <- function(a, tau, x) {
  max(abs(a %*% tau - x)) / (max(rowSums(abs(a))) * max(abs(tau)) +
                               max(abs(x)))
}
set.seed(1)
out <- NULL
for (n in c(4, 5, 6, 50, 372, 612)) for (lambda in c(0, 13.9, 1600,
                                                      133107.9, 1e8)) {
  x <- cumsum(rnorm(n))
  dn <- dense(x, lambda)
  b <- rcli:::hp_trend_core(x, lambda)
  out <- rbind(out, data.frame(
    n = n, lambda = lambda,
    rel_diff = max(abs(b - dn$tau)) / max(abs(dn$tau)),
    eta_band = eta(dn$a, b, x), eta_dense = eta(dn$a, dn$tau, x)))
}
print(signif(out, 3))
stopifnot(all(out$eta_band <= 10 * .Machine$double.eps))
x <- 3 + 0.25 * seq_len(200)
stopifnot(max(abs(rcli:::hp_trend_core(x, 133107.9) - x)) < 1e-8 * max(x))
for (n in c(372, 612)) {
  x <- cumsum(rnorm(n))
  tb <- system.time(for (r in 1:50) rcli:::hp_trend_core(x, 133107.9))[[3]]
  td <- system.time(for (r in 1:20) dense(x, 133107.9))[[3]]
  cat(sprintf("n = %d: banded %.2f ms, dense %.1f ms\n", n, tb / 50 * 1000,
              td / 20 * 1000))
}
cat("F-03 numeric check: PASS\n")
