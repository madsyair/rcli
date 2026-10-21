sim <- simulate_cycles(n_years = 10, seed = 1)
meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")

test_that("candidate sets are validated", {
  cand <- cli_candidates(sim, "reference", meta = meta)
  expect_s4_class(cand, "CandidateSet")
  expect_equal(rcli:::candidate_names(cand), colnames(sim)[-1])
  expect_error(cli_candidates(sim, "gdp", meta = meta),
               class = "rcli_error_argument")
  expect_error(cli_candidates(sim[, 1, drop = FALSE], "reference"),
               class = "rcli_error_argument")
  expect_error(cli_candidates(1:10, "reference"),
               class = "rcli_error_argument")
  expect_error(cli_candidates(as.data.frame(sim), "reference"),
               class = "rcli_error_argument")
  bad <- meta
  bad$rationale[1] <- "magic"
  expect_error(cli_candidates(sim, "reference", meta = bad),
               "Unknown rationale")
  expect_error(cli_candidates(sim, "reference", meta = data.frame(x = 1)),
               class = "rcli_error_argument")
  expect_error(cli_candidates(sim, "reference",
                              meta = data.frame(name = "zzz")),
               class = "rcli_error_argument")
})

test_that("missing rationales trigger a warning", {
  expect_warning(cli_candidates(sim, "reference"),
                 class = "rcli_warning_rationale")
})

test_that("data frames are accepted with time attributes", {
  df <- as.data.frame(sim)
  cand <- cli_candidates(df, "reference", meta = meta, start = 1995,
                         frequency = 12)
  expect_equal(start(cand@data), c(1995, 1))
})

test_that("subsetting and windowing keep the reference", {
  cand <- cli_candidates(sim, "reference", meta = meta)
  sub <- cand[c("lead_6", "lag_3")]
  expect_equal(colnames(sub@data), c("reference", "lead_6", "lag_3"))
  expect_equal(nrow(sub@meta), 2)
  expect_error(cand["zzz"], class = "rcli_error_argument")
  w <- window(cand, end = c(2000, 12))
  expect_equal(end(w@data), c(2000, 12))
})

test_that("candidate sets print", {
  expect_snapshot(cli_candidates(sim, "reference", meta = meta))
})
