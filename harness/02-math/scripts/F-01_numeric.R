# Verifikasi numerik F-01: implementasi acuan (loop, ditulis dari definisi
# di F-01.md) dibandingkan dengan aggregate_components(equal_weight()).
suppressMessages(devtools::load_all("/home/claude/rcli", quiet = TRUE))
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
spec <- cli_spec(12)
worst <- 0
na_mismatch <- 0
check <- function(z, m) {
  got <- aggregate_components(equal_weight(m), z, NULL, spec)$cycle
  want <- ref_hybrid(z, m)
  na_mismatch <<- na_mismatch + sum(is.na(got) != is.na(want))
  ok <- !is.na(got) & !is.na(want)
  if (any(ok)) {
    worst <<- max(worst, abs(got[ok] - want[ok]) / pmax(1, abs(want[ok])))
  }
}
# (1) acak: n = 1..40, ekor tebal (t3 x 30), NA di awal, ujung, dan tengah
for (rep in 1:2000) {
  n <- sample(1:40, 1); k <- sample(1:5, 1); m <- sample(c(0, 0.5, 0.6, 1), 1)
  z <- matrix(rt(n * k, 3) * sample(c(1, 30), 1), n, k,
              dimnames = list(NULL, letters[seq_len(k)]))
  for (j in seq_len(k)) {
    s <- sample(0:3, 1); e <- sample(0:3, 1)
    if (s > 0) z[seq_len(min(s, n)), j] <- NA
    if (e > 0) z[max(1, n - e + 1):n, j] <- NA
    if (runif(1) < 0.2) z[sample(n, 1), j] <- NA
  }
  check(z, m)
}
# (2) terarah: ujung acak sesudah baris lengkap terakhir, termasuk celah
#     cakupan yang lalu pulih dan baris tanpa komponen ber-perubahan
for (rep in 1:2000) {
  k <- sample(2:5, 1); b <- sample(2:10, 1); tail_n <- sample(1:8, 1)
  m <- sample(c(0, 0.5, 0.6, 1), 1)
  z <- matrix(rnorm((b + tail_n) * k), b + tail_n, k,
              dimnames = list(NULL, letters[seq_len(k)]))
  avail <- matrix(runif(tail_n * k) < 0.6, tail_n, k)
  avail[1, sample(k, 1)] <- FALSE
  z[(b + 1):(b + tail_n), ][!avail] <- NA
  check(z, m)
}
cat("F-01 numerik: selisih relatif maksimum", worst,
    "; ketidakcocokan NA", na_mismatch, "\n")
stopifnot(worst <= 1e-12, na_mismatch == 0)
