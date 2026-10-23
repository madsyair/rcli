# Builds the golden files used by the replication harness.
# BCDating was archived from CRAN on 2026-05-06, so its results are stored
# here once instead of being computed during the tests. Run from the package
# root with BCDating installed from the CRAN archive:
#   install.packages(
#     "https://cran.r-project.org/src/contrib/Archive/BCDating/BCDating_0.9.8.tar.gz",
#     repos = NULL, type = "source")
library(BCDating)

simulate_quarterly <- function(seed, n = 160) {
  set.seed(seed)
  ts(cumsum(rnorm(n, 0.5, 1)) + 10 * sin(2 * pi * (1:n) / 28),
     frequency = 4, start = 1980)
}

seeds <- 1:50
bbq_golden <- lapply(seeds, function(s) {
  y <- simulate_quarterly(s)
  d <- BBQ(y)
  list(seed = s, y = as.numeric(y), peaks = as.integer(d@peaks),
       troughs = as.integer(d@troughs))
})
saveRDS(bbq_golden, "tests/testthat/fixtures/bcdating_bbq.rds", version = 2)

# Golden composite of rcli 0.1.3 (tests/testthat/fixtures/composite-0.1.3.rds),
# used to check that cli_spec(aggregator = equal_weight(ragged_edge = "level"),
# extension = no_extension()) reproduces 0.1.3. Run from the package root:
#   d <- tempfile(); dir.create(d)
#   system(sprintf("git archive a3b8181 | tar -x -C %s", d))
#   devtools::load_all(d)
#   sim <- simulate_cycles(seed = 4)
#   meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
#   res <- cli_build(cli_candidates(sim, "reference", meta = meta))
#   saveRDS(list(version = "0.1.3", components = res@composite@components,
#                index = as.numeric(res@composite@index),
#                cycle = as.numeric(res@composite@cycle)),
#           "tests/testthat/fixtures/composite-0.1.3.rds")
