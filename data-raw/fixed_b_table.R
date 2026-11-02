# Null distribution of the fixed-b HAC t statistic (Bartlett kernel,
# bandwidth M = b n with b = 0.3), used by fixed_b_p() for the concordance
# and Pesaran-Timmermann tests (F-06). Run from the package root:
#   Rscript data-raw/fixed_b_table.R
# Output: R/sysdata.rda (object `fixed_b_null`).
#
# Under the fixed-b asymptotics of Kiefer and Vogelsang (2005) the t
# statistic of a regression coefficient converges to W(1) / sqrt(Q_b), a
# functional of a Brownian motion that does not depend on the regressors.
# It is simulated here with the location model (iid normal errors, n =
# 1000), where the t statistic of the mean has the same limit.

b <- 0.3
n <- 1000L
reps <- 400000L
chunk <- 4000L
m <- floor(b * n)
nfft <- 2L^ceiling(log2(2L * n))
w <- c(1, 2 * (1 - seq_len(m - 1L) / (b * n)))

set.seed(20261102)
tstat <- function(k) {
  u <- matrix(stats::rnorm(n * k), n, k)
  mu <- colMeans(u)
  e <- sweep(u, 2, mu)
  pad <- rbind(e, matrix(0, nfft - n, k))
  f <- stats::mvfft(pad)
  ac <- Re(stats::mvfft(f * Conj(f), inverse = TRUE))[seq_len(m), ,
                                                       drop = FALSE] /
    (nfft * n)
  omega <- colSums(ac * w)
  sqrt(n) * mu / sqrt(omega)
}
t_all <- unlist(lapply(seq_len(reps / chunk), function(i) tstat(chunk)))
a <- sort(abs(t_all))
# upper-tail probabilities P(T > t) for t >= 0, from |T| (symmetry)
upper <- c(seq(0.5, 0.01, by = -0.0025), seq(0.0099, 0.001, by = -0.0001),
           seq(0.00095, 0.0001, by = -0.00005))
q <- stats::quantile(a, 1 - 2 * upper, names = FALSE, type = 8)
fixed_b_null <- data.frame(t = q, upper = upper)
attr(fixed_b_null, "b") <- b
attr(fixed_b_null, "reps") <- reps
save(fixed_b_null, file = "R/sysdata.rda", compress = "xz")
cat("one-sided 95% quantile:", stats::approx(upper, q, 0.05)$y,
    "(Kiefer-Vogelsang 2005 polynomial:",
    1.6449 + 2.1859 * b + 0.3142 * b^2 - 0.3427 * b^3, ")\n")
