test_that("shift_vec moves values forward and backward", {
  expect_equal(rcli:::shift_vec(1:5, 2), c(NA, NA, 1, 2, 3))
  expect_equal(rcli:::shift_vec(1:5, -2), c(3, 4, 5, NA, NA))
  expect_equal(rcli:::shift_vec(1:3, 0), 1:3)
  expect_true(all(is.na(rcli:::shift_vec(1:3, 5))))
})

test_that("internal gaps are interpolated, edges kept", {
  x <- c(NA, 1, NA, 3, NA)
  expect_equal(rcli:::fill_internal_na(x), c(NA, 1, 2, 3, NA))
  expect_equal(rcli:::fill_internal_na(c(NA, NA)), c(NA, NA))
})

test_that("normalisation gives mean 0 and mean absolute deviation 1", {
  z <- rcli:::normalise_cycle(c(1, 4, 2, 8, 5))
  expect_equal(mean(z), 0)
  expect_equal(mean(abs(z)), 1)
  expect_equal(rcli:::normalise_cycle(rep(2, 4)), rep(0, 4))
})

test_that("argument checks raise classed errors", {
  expect_error(rcli:::check_number("a", "x"),
               class = "rcli_error_argument")
  expect_error(rcli:::check_number(1.5, "x", integer = TRUE),
               class = "rcli_error_argument")
  expect_error(rcli:::check_number(NA, "x"),
               class = "rcli_error_argument")
  expect_true(rcli:::check_number(NA, "x", allow_na = TRUE))
  expect_error(rcli:::check_flag(NA, "x"), class = "rcli_error_argument")
  expect_error(rcli:::check_frequency(1), class = "rcli_error_frequency")
  expect_error(rcli:::check_ts(1:3), class = "rcli_error_argument")
})

test_that("period labels follow the frequency", {
  expect_equal(rcli:::period_label(2000, 12), "2000-01")
  expect_equal(rcli:::period_label(2000 + 11 / 12, 12), "2000-12")
  expect_equal(rcli:::period_label(2001.75, 4), "2001Q4")
})
