# Monte Carlo harness: the default rules must keep false "leading" labels rare
# and recover most true leaders. A small version runs everywhere; the larger
# one (also used for the calibration in data-raw/) is skipped on CRAN.
harness_accuracy <- function(seeds, freq = 12, noise_sd = 0.2) {
  rows <- lapply(seeds, function(s) {
    cand <- sim_candidates(seed = s, freq = freq, noise_sd = noise_sd)
    tab <- as.data.frame(cli_assess(cand, cli_spec(freq)))
    truth <- attr(cand, "truth")
    tab$truth <- truth$class[match(tab$name, truth$name)]
    tab
  })
  d <- do.call(rbind, rows)
  list(overall = mean(d$class == d$truth),
       false_leading = mean(d$class[d$truth != "leading"] == "leading"),
       true_leading = mean(d$class[d$truth == "leading"] == "leading"))
}

test_that("small Monte Carlo harness", {
  h <- harness_accuracy(1:4)
  expect_gte(h$overall, 0.8)
  expect_lte(h$false_leading, 0.1)
  expect_gte(h$true_leading, 0.8)
})

test_that("larger Monte Carlo harness", {
  skip_on_cran()
  m <- harness_accuracy(1:20, freq = 12, noise_sd = 0.4)
  expect_gte(m$overall, 0.8)
  expect_lte(m$false_leading, 0.05)
  q <- harness_accuracy(1:20, freq = 4, noise_sd = 0.2)
  expect_gte(q$overall, 0.85)
  expect_lte(q$false_leading, 0.05)
})
