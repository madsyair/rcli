# FR-001, F-01: equal weights chained at the ragged edge (rcli 0.2.0).
# Reference: harness/02-math/F-01.md, revision 2 (additive chain).

spec <- cli_spec(12)
ew <- function(z, ...) {
  aggregate_components(equal_weight(...), z, NULL, spec)$cycle
}

test_that("FR-001 AC-1: the hand example is chained after the last full row", {
  z <- cbind(a = c(0, 1, 2, 3), b = c(0, 1, 2, 3), c = c(0, 1, 2, NA))
  h <- ew(z)
  expect_equal(h[1:3], rowMeans(z)[1:3], tolerance = 1e-12)
  expect_equal(h[4], h[3] + 1, tolerance = 1e-12)
})

test_that("FR-001 AC-2 / F-01 Prop. 2: complete data equal the level mean", {
  set.seed(1)
  z <- matrix(rnorm(60), 20, 3, dimnames = list(NULL, c("a", "b", "c")))
  expect_equal(ew(z), rowMeans(z))
  expect_identical(ew(z), ew(z, ragged_edge = "level"))
})

test_that("FR-001 AC-3 / F-01 Prop. 1: a late start is not chained", {
  set.seed(2)
  z <- matrix(rnorm(60), 20, 3, dimnames = list(NULL, c("a", "b", "c")))
  z[1:6, "a"] <- NA
  expect_identical(ew(z), ew(z, ragged_edge = "level"))
})

test_that("F-01 Prop. 4: a missing component causes no composition jump", {
  # m = 0.5, so that the plain mean is defined with one of two components
  z <- cbind(a = c(0, 1, 1), b = c(0, -1, NA))
  h <- ew(z, min_coverage = 0.5)
  expect_equal(h[3], h[2])
  z2 <- cbind(a = c(0, 1, 1.4), b = c(0, -1, NA), c = c(2, 2, 2.4))
  h2 <- ew(z2, min_coverage = 0.5)
  expect_equal(h2[3] - h2[2], 0.4)
  l <- ew(z, min_coverage = 0.5, ragged_edge = "level")
  expect_false(isTRUE(all.equal(l[3], l[2])))
})

test_that("FR-001 AC-4: edge cases", {
  # a coverage gap after the last full row stops the chain for good
  z <- cbind(a = c(0, 1, 2, NA, 4), b = c(0, 1, NA, NA, 4),
             c = c(0, 1, 2, 3, NA))
  h <- ew(z)
  expect_false(is.na(h[3]))
  expect_true(all(is.na(h[4:5])))
  # fewer than q components with a change: the chain stops (C4)
  z5 <- cbind(a = c(0, 1, NA), b = c(0, 1, 2), c = c(0, NA, 3),
              d = c(0, NA, 5))
  expect_true(is.na(ew(z5, min_coverage = 0.5)[3]))
  # no full row, one component, one row: the plain mean
  z2 <- cbind(a = c(NA, 1, 2), b = c(0, NA, NA))
  expect_identical(ew(z2, min_coverage = 0.5),
                   ew(z2, min_coverage = 0.5, ragged_edge = "level"))
  z3 <- cbind(a = c(1, 2, NA))
  expect_identical(ew(z3), ew(z3, ragged_edge = "level"))
  z1 <- cbind(a = 1, b = 2)
  expect_identical(ew(z1), ew(z1, ragged_edge = "level"))
  # F-01 Prop. 5: a large shock at the edge moves the chain by the mean
  # change, not more (C1)
  z4 <- cbind(a = c(0, 0, -199.5, 0), b = c(0, 0, 0, NA))
  h4 <- ew(z4, min_coverage = 0.5)
  expect_equal(diff(h4)[3], 199.5)
  expect_lte(max(abs(diff(h4))), max(abs(diff(z4)), na.rm = TRUE))
})

test_that("F-01 (D2): q tolerance and a gap between full rows", {
  # m * k = 3.0000000000000004: q must be 3, so three changes are enough
  z <- cbind(a = c(0, 1, 2), b = c(0, 1, 2), c = c(0, 1, 2),
             d = c(0, 1, NA), e = c(0, 1, NA))
  m <- 0.6000000000000001
  expect_equal(ew(z, min_coverage = m)[3], ew(z, min_coverage = m)[2] + 1)
  # the chain starts after the LAST full row, not after the first gap
  z2 <- cbind(a = c(0, 1, NA, 3, 4), b = c(0, 1, 2, 3, NA),
              c = c(0, 1, 2, 3, 5))
  h <- ew(z2, min_coverage = 0.5)
  expect_equal(h[1:4], ew(z2, min_coverage = 0.5, ragged_edge = "level")[1:4])
  expect_equal(h[5], h[4] + 1.5)
})

test_that("FR-001 AC-5: ragged_edge = 'level' reproduces rcli 0.1.3", {
  z <- cbind(a = c(NA, 1, 2, 3), b = c(0, 1, 2, NA), c = c(0, 1, NA, NA))
  w <- rep(1 / 3, 3)
  old <- rcli:::weighted_available(z, w)
  old[!rcli:::coverage_mask(z, 0.6)] <- NA
  expect_equal(ew(z, ragged_edge = "level"), old)
})

test_that("FR-001 AC-6/7: arguments, defaults and objects from 0.1.x", {
  expect_error(equal_weight(ragged_edge = "x"), class = "rcli_error_argument")
  expect_error(equal_weight(ragged_edge = c("level", "chain")),
               class = "rcli_error_argument")
  expect_equal(spec@aggregator@ragged_edge, "chain")
  expect_match(spec@aggregator@label, "chained")
  old <- equal_weight(ragged_edge = "level")
  old_obj <- new("EqualWeight", label = "Equal weights", min_coverage = 0.6)
  attr(old_obj, "ragged_edge") <- NULL
  expect_false(methods::.hasSlot(old_obj, "ragged_edge"))
  z <- cbind(a = c(0, 1, 2), b = c(0, 1, NA), c = c(0, 2, 3))
  got <- aggregate_components(old_obj, z, NULL, spec)$cycle
  expect_equal(got, aggregate_components(old, z, NULL, spec)$cycle)
  expect_false(isTRUE(all.equal(got, ew(z))))
})

test_that("F-01: package code matches the reference implementation", {
  ref_hybrid <- function(z, m) {
    n <- nrow(z); k <- ncol(z); q <- max(1, ceiling(m * k - 1e-9))
    obs <- !is.na(z)
    lev <- rep(NA_real_, n)
    for (t in seq_len(n)) {
      if (sum(obs[t, ]) >= q) lev[t] <- mean(z[t, obs[t, ]])
    }
    full <- which(rowSums(obs) == k)
    if (length(full) == 0L) return(lev)
    b <- max(full)
    out <- lev
    if (b < n) out[(b + 1):n] <- NA_real_
    stopped <- FALSE
    for (t in seq_len(n)[-seq_len(b)]) {
      both <- obs[t, ] & obs[t - 1, ]
      if (stopped || sum(both) < q || is.na(out[t - 1])) {
        stopped <- TRUE
        next
      }
      out[t] <- out[t - 1] + mean(z[t, both] - z[t - 1, both])
    }
    out
  }
  set.seed(20261023)
  for (r in 1:300) {
    n <- sample(2:30, 1); k <- sample(1:4, 1)
    m <- sample(c(0, 0.5, 0.6, 1), 1)
    z <- matrix(rnorm(n * k), n, k, dimnames = list(NULL, letters[seq_len(k)]))
    for (j in seq_len(k)) {
      s <- sample(0:3, 1); e <- sample(0:3, 1)
      if (s > 0) z[seq_len(min(s, n)), j] <- NA
      if (e > 0) z[max(1, n - e + 1):n, j] <- NA
    }
    expect_equal(ew(z, min_coverage = m), ref_hybrid(z, m), tolerance = 1e-12)
  }
})

test_that("FR-001: the default composite equals 0.1.3 on balanced data", {
  cyc <- cli_cycles(sim_candidates(seed = 1), cli_spec(12,
                    extension = no_extension()))
  comps <- c("lead_6", "lead_3")
  new_ci <- cli_composite(cyc, comps, cli_spec(12))
  old_ci <- cli_composite(cyc, comps, cli_spec(12,
    aggregator = equal_weight(ragged_edge = "level")))
  expect_equal(as.numeric(new_ci@cycle), as.numeric(old_ci@cycle),
               tolerance = 1e-12)
})

test_that("F-01 Prop. 7: on contiguous spans the chain is an imputed mean", {
  set.seed(77)
  for (r in 1:100) {
    n <- 20; k <- 4
    z <- matrix(rnorm(n * k), n, k, dimnames = list(NULL, letters[1:k]))
    ends <- n - sample(0:3, k, replace = TRUE)
    for (j in seq_len(k)) if (ends[j] < n) z[(ends[j] + 1):n, j] <- NA
    h <- ew(z, min_coverage = 0)
    b <- min(ends)
    zt <- z
    for (t in seq_len(n)[-seq_len(b)]) {
      av <- !is.na(z[t, ])
      if (!any(av)) break
      delta <- mean(z[t, av] - z[t - 1, av])
      zt[t, !av] <- zt[t - 1, !av] + delta
    }
    ok <- !is.na(h)
    expect_equal(h[ok], rowMeans(zt)[ok])
  }
})

test_that("FR-001 AC-8: the PCA and DFM fallbacks chain at the ragged edge", {
  z <- cbind(a = c(0, 1, 2), b = c(0, 1, NA), c = c(0, 2, 3))
  for (ag in list(principal_component(), dynamic_factor())) {
    expect_warning(out <- aggregate_components(ag, z, NULL, spec),
                   class = "rcli_warning_fallback")
    expect_equal(out$cycle, ew(z))
  }
})
