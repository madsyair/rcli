# F-06: numerical verification of the fixed-b test and its null table.
# Run from the package root: Rscript harness/02-math/scripts/F-06_numeric.R
suppressMessages(devtools::load_all(quiet = TRUE))
ok <- TRUE
check <- function(cond, msg) {
  cat(if (isTRUE(cond)) "ok  " else "FAIL", msg, "\n")
  if (!isTRUE(cond)) ok <<- FALSE
}
tab <- rcli:::fixed_b_null
q95 <- stats::approx(tab$upper, tab$t, 0.05)$y
kv <- 1.6449 + 2.1859 * 0.3 + 0.3142 * 0.09 - 0.3427 * 0.027

# 1. independent regression simulation, t statistic with random regressor
set.seed(1)
tstat <- function(y, x, b = 0.3) {
  n <- length(y)
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
tt <- replicate(20000, tstat(stats::rnorm(500), stats::rnorm(500)))
q_reg <- stats::quantile(tt, c(0.05, 0.95), names = FALSE)
cat(sprintf("q95 table %.3f, regression sim %.3f, KV polynomial %.3f\n",
            q95, q_reg[2], kv))
check(abs(q95 / q_reg[2] - 1) < 0.03, "table vs regression simulation (3%)")
check(abs(q95 / kv - 1) < 0.03, "table vs Kiefer-Vogelsang polynomial (3%)")
# symmetry: tail probabilities of a signed simulation of the limit at the
# tabulated quantile (200 000 draws, standard error of each about 0.0005)
signed <- unlist(lapply(1:50, function(i) {
  n <- 1000
  m <- 300
  u <- matrix(stats::rnorm(n * 4000), n, 4000)
  e <- sweep(u, 2, colMeans(u))
  s <- apply(e, 2, cumsum)
  # Bartlett variance through partial sums (Kiefer and Vogelsang 2005)
  om <- 2 / (n * m) * (colSums(s^2) - colSums(s[1:(n - m), ] *
                                                s[(m + 1):n, ]))
  sqrt(n) * colMeans(u) / sqrt(om)
}))
up <- mean(signed > q95)
lo <- mean(signed < -q95)
cat(sprintf("P(T > q95) = %.4f, P(T < -q95) = %.4f\n", up, lo))
check(abs(up - 0.05) < 0.003 && abs(lo - 0.05) < 0.003,
      "symmetric tails at the tabulated quantile")

# 3. fixed_b_p
grid <- seq(-6, 6, by = 0.01)
p <- vapply(grid, rcli:::fixed_b_p, numeric(1))
check(all(diff(p) <= 1e-12), "p decreasing in t")
check(rcli:::fixed_b_p(0) == 0.5, "p(0) = 0.5")
check(abs(rcli:::fixed_b_p(q95) - 0.05) < 1e-9, "p(q95) = 0.05")

# 4. size on independent persistent binary series
set.seed(2)
markov <- function(n, pr) {
  s <- integer(n)
  s[1] <- stats::rbinom(1, 1, 0.5)
  sw <- stats::runif(n) < pr
  for (t in 2:n) s[t] <- if (sw[t]) 1L - s[t - 1] else s[t - 1]
  s
}
nw <- function(y, x) {
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
  bread <- solve(crossprod(xm))
  v <- bread %*% s %*% bread
  stats::pnorm(fit$coefficients[[2]] / sqrt(v[2, 2]), lower.tail = FALSE)
}
sims <- replicate(2000, {
  y <- markov(360, 1 / 24)
  x <- markov(360, 1 / 24)
  c(fb = rcli:::hac_fixed_b_p(y, x), nw = nw(y, x))
})
size_fb <- mean(sims["fb", ] < 0.05, na.rm = TRUE)
size_nw <- mean(sims["nw", ] < 0.05, na.rm = TRUE)
cat(sprintf("size at 5%%: fixed-b %.3f, Newey-West %.3f\n", size_fb, size_nw))
# the size at switching probability 1/24 is about 7.5 to 8 percent
# (inst/calibration/test-size.csv); the check allows for Monte Carlo error
check(size_fb <= 0.09, "fixed-b size <= 9% (switching 1/24)")
check(size_nw > 0.15, "Newey-West size > 15% (the defect)")
cat(if (ok) "PASS" else "FAIL", "\n")
