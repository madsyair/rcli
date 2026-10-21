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
