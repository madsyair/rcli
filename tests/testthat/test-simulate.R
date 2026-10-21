test_that("simulation returns the truth and is reproducible", {
  a <- simulate_cycles(seed = 9)
  b <- simulate_cycles(seed = 9)
  expect_identical(a, b)
  truth <- attr(a, "truth")
  expect_equal(truth$name, colnames(a)[-1])
  expect_equal(truth$class, c("leading", "leading", "coincident", "lagging",
                              "leading", "rejected", "rejected"))
  expect_true(all(a > 0))
  q <- simulate_cycles(freq = 4, n_years = 20, n_noise = 0, seed = 1)
  expect_equal(frequency(q), 4)
  expect_equal(attr(q, "truth")$lead, c(2, 1, 0, -1, 1))
})

test_that("a supplied seed leaves the session RNG untouched", {
  set.seed(123)
  before <- .Random.seed
  simulate_cycles(seed = 1, n_years = 8)
  expect_identical(.Random.seed, before)
})

test_that("truth classes follow the default thresholds", {
  expect_equal(rcli:::truth_class(c(6, 2, 1, -1, -3, NA), 12),
               c("leading", "rejected", "coincident", "coincident", "lagging",
                 "rejected"))
  expect_equal(rcli:::truth_class(c(1, 0, -1), 4),
               c("leading", "coincident", "lagging"))
})
