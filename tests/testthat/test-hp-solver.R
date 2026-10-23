# FR-004, F-03: the HP trend is solved with a banded LDL' factorisation in
# O(n) time and memory (rcli 0.2.1). Reference: harness/02-math/F-03.md.

hp_dense <- function(x, lambda) {
  n <- length(x)
  d2 <- diff(diag(n), differences = 2)
  as.numeric(solve(diag(n) + lambda * crossprod(d2), x))
}

test_that("FR-004 AC-1: the banded solver equals the dense solution", {
  set.seed(31)
  for (n in c(4, 5, 6, 50, 372)) {
    x <- cumsum(rnorm(n))
    for (lambda in c(0, 13.9, 1600, 133107.9)) {
      # kappa(A) <= 1 + 16 lambda, about 2e6 here: both solutions carry
      # errors near 1e-10 relative, so 1e-9 separates them from real bugs
      expect_equal(rcli:::hp_trend_core(x, lambda), hp_dense(x, lambda),
                   tolerance = 1e-9)
    }
  }
})

test_that("FR-004 AC-2: lines are kept and the mean and slope preserved", {
  tt <- seq_len(200)
  x <- 3 + 0.25 * tt
  expect_equal(rcli:::hp_trend_core(x, 133107.9), x, tolerance = 1e-8)
  set.seed(32)
  y <- cumsum(rnorm(300))
  tau <- rcli:::hp_trend_core(y, 133107.9)
  expect_equal(sum(tau), sum(y), tolerance = 1e-8)
  expect_equal(sum(seq_along(y) * tau), sum(seq_along(y) * y),
               tolerance = 1e-8)
})

test_that("FR-004 AC-3: the solution is backward stable", {
  set.seed(33)
  n <- 372
  lambda <- 133107.9
  x <- cumsum(rnorm(n))
  tau <- rcli:::hp_trend_core(x, lambda)
  a <- diag(n) + lambda * crossprod(diff(diag(n), differences = 2))
  # normwise backward error (Higham 2002, sec. 7.1); a backward stable
  # solver gives a small multiple of the unit roundoff
  eta <- max(abs(a %*% tau - x)) /
    (max(rowSums(abs(a))) * max(abs(tau)) + max(abs(x)))
  expect_lte(eta, 10 * .Machine$double.eps)
})

test_that("FR-004 AC-4: lambda = 0 and short series", {
  x <- c(1, 4, 2, 8, 5)
  expect_equal(rcli:::hp_trend_core(x, 0), x)
  expect_error(rcli:::hp_trend_core(1:3, 1600),
               class = "rcli_error_short_series")
})

test_that("FR-004 AC-6: a long series needs no n x n matrix", {
  skip_on_cran()
  set.seed(34)
  x <- cumsum(rnorm(1e5))
  # the dense system would take 80 GB of memory
  elapsed <- system.time(tau <- rcli:::hp_trend_core(x, 1600))[["elapsed"]]
  expect_length(tau, 1e5)
  expect_true(all(is.finite(tau)))
  # finishing at all is the evidence (the dense system fails to allocate);
  # the time limit holds without coverage instrumentation, which slows
  # the R loops several times
  if (!identical(Sys.getenv("R_COVR"), "true")) expect_lt(elapsed, 5)
})
