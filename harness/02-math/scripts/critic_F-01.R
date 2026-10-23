# Kritik A2c untuk F-01: kontra-contoh dan uji kecukupan skrip numerik.
# Jalankan: Rscript harness/02-math/scripts/critic_F-01.R (dari akar paket).
# Tidak memuat kode paket F-01 (belum ada); hanya ref_hybrid dari
# F-01_numeric.R (disalin apa adanya) dan helper 0.1.3 dari R/utils.R.

ref_hybrid <- function(z, m) {
  n <- nrow(z); k <- ncol(z); q <- max(1, ceiling(m * k - 1e-9))
  lv <- z + 100
  obs <- !is.na(z)
  L <- rep(NA_real_, n)
  for (t in seq_len(n)) {
    if (sum(obs[t, ]) >= q) L[t] <- mean(lv[t, obs[t, ]])
  }
  full <- which(rowSums(obs) == k)
  if (length(full) == 0L || k == 1L) return(L)
  b <- max(full)
  H <- L
  if (b < n) H[(b + 1):n] <- NA_real_
  stopped <- FALSE
  for (t in seq_len(n)[-seq_len(b)]) {
    B <- obs[t, ] & obs[t - 1, ]
    if (stopped || sum(obs[t, ]) < q || is.na(H[t - 1]) || !any(B)) {
      stopped <- TRUE
      next
    }
    H[t] <- H[t - 1] * (1 + mean(lv[t, B] / lv[t - 1, B] - 1))
  }
  H
}
# Helper 0.1.3 (salinan R/utils.R).
mean_abs_dev <- function(x) {
  x <- x[!is.na(x)]
  mean(abs(x - mean(x)))
}
normalise_cycle <- function(x) {
  m <- mean(x, na.rm = TRUE)
  s <- mean_abs_dev(x)
  if (!is.finite(s) || s <= 0) return(x * 0)
  (x - m) / s
}
old_level <- function(z, m) {        # equal_weight() 0.1.3 (tanpa +100)
  q <- max(1, ceiling(m * ncol(z) - 1e-9))
  out <- rowMeans(z, na.rm = TRUE)
  out[rowSums(!is.na(z)) < q] <- NA_real_
  out
}
say <- function(...) cat(sprintf(...), "\n", sep = "")

## K1. Asumsi "|z| << 100 karena MAD = 1" salah: |z| dapat mencapai ~n/2.
n <- 400
x <- c(rep(0, n - 1), -1)
z1 <- normalise_cycle(x)
say("K1: n = %d, MAD(z) = %.3f, min z = %.2f -> level min = %.2f",
    n, mean_abs_dev(z1), min(z1), 100 + min(z1))
stopifnot(abs(mean_abs_dev(z1) - 1) < 1e-12, min(z1) < -100)
# Batas umum: max |z_i| <= n/2 (jumlah simpangan positif = negatif = n*D/2).

## K2. l > 0 tidak cukup: level kecil positif memberi lompatan rantai besar.
z2 <- cbind(a = c(0, -99.5, 0), b = c(0, 0, NA))
h2 <- ref_hybrid(z2, 0.5)
say("K2: H = %s (faktor H3/H2 = %.1f)", paste(round(h2, 2), collapse = ", "),
    h2[3] / h2[2])

## K3. Akibat 4 di aritmetika titik-mengambang: M konstan persis, L tidak.
set.seed(1)
found <- NULL
for (i in 1:20000) {
  a <- runif(6, 0, 3)
  z <- if (i %% 2) cbind(a, -a) else cbind(a, a, -2 * a)   # M_t = 0
  L <- rowMeans(z + 100)
  if (stats::sd(L) > 0 && all(rowMeans(z) == 0)) { found <- z; break }
}
if (!is.null(found)) {
  nh <- normalise_cycle(rowMeans(found + 100))
  no <- normalise_cycle(rowMeans(found))
  say("K3: percobaan %d; N(L) = %s; N(M) = %s", i,
      paste(signif(nh, 3), collapse = " "), paste(no, collapse = " "))
} else {
  say("K3: tidak ditemukan")
}

## K4. c_t = 1 tetapi |B_t| < q: laju satu komponen menggerakkan rantai.
z4 <- cbind(a = c(0, 0, 5), b = c(0, 0, NA), c = c(0, NA, NA),
            d = c(0, 0, 0), e = c(0, NA, 0))
q4 <- max(1, ceiling(0.6 * 5 - 1e-9))
B4 <- !is.na(z4[3, ]) & !is.na(z4[2, ])
say("K4: q = %d, |A_3| = %d, |B_3| = %d, H = %s", q4, sum(!is.na(z4[3, ])),
    sum(B4), paste(round(ref_hybrid(z4, 0.6), 4), collapse = ", "))
z4b <- cbind(a = c(0, 0, NA), b = c(0, 1, NA), c = c(0, NA, 0),
             d = c(0, NA, 0), e = c(0, 0, 0))
say("K4b: |A_2| = 3, |A_3| = 3, |B_3| = %d (hanya e) -> H = %s",
    sum(!is.na(z4b[3, ]) & !is.na(z4b[2, ])),
    paste(round(ref_hybrid(z4b, 0.6), 4), collapse = ", "))

## K5. Proposisi 2, 5, 6 dan Akibat 4 pada grid acak (ref_hybrid).
set.seed(7)
p2 <- p5 <- p6 <- a4 <- 0
for (r in 1:3000) {
  n <- sample(1:40, 1); k <- sample(1:5, 1)
  m <- sample(c(0, 0.5, 0.6, 1), 1)
  z <- matrix(rnorm(n * k), n, k)
  h <- ref_hybrid(z, m)
  p2 <- max(p2, abs(h - (100 + rowMeans(z))))
  a4 <- max(a4, abs(normalise_cycle(h) - normalise_cycle(old_level(z, m))),
            na.rm = TRUE)
  if (k >= 2 && n >= 3) {
    zz <- z
    drop <- sample(k, sample(1:(k - 1), 1))
    zz[n, drop] <- NA
    rr <- runif(1, -0.05, 0.05)
    zz[n, -drop] <- (zz[n - 1, -drop] + 100) * (1 + rr) - 100
    hh <- ref_hybrid(zz, 0)
    p5 <- max(p5, abs(hh[n] / hh[n - 1] - (1 + rr)))
  }
  p6 <- p6 + sum(h <= 0, na.rm = TRUE)
}
say("K5: Prop2 maks %.2e; Akibat4 maks %.2e; Prop5 maks %.2e; Prop6 H<=0: %d",
    p2, a4, p5, p6)

## K6. Kecukupan F-01_numeric.R: mutan dijalankan pada grid yang sama.
mut <- list(
  restart = function(z, m) {        # rantai mulai ulang dari L (tidak berhenti)
    h <- ref_hybrid(z, m); L <- old_level(z, m) + 100
    n <- nrow(z); obs <- !is.na(z)
    full <- which(rowSums(obs) == ncol(z))
    if (!length(full) || ncol(z) == 1L) return(h)
    for (t in seq_len(n)[-seq_len(max(full))]) {
      if (!is.na(h[t])) next
      if (!is.na(L[t])) {
        B <- obs[t, ] & obs[t - 1, ]
        lv <- z + 100
        h[t] <- if (!is.na(h[t - 1]) && any(B)) {
          h[t - 1] * mean(lv[t, B] / lv[t - 1, B])
        } else L[t]
      }
    }
    h
  },
  no_cov = function(z, m) ref_hybrid(z, 0),          # c_t diabaikan di rantai
  b_cov = function(z, m) {                           # b = baris tercakup akhir
    zz <- z; ok <- which(!is.na(old_level(z, m)))
    if (!length(ok)) return(ref_hybrid(z, m))
    h <- ref_hybrid(z, m); bb <- max(ok)
    h[bb] <- old_level(z, m)[bb] + 100; h
  },
  level_ratio = function(z, m) {                     # rantai rasio rerata level
    h <- ref_hybrid(z, m); L <- old_level(z, m) + 100
    obs <- !is.na(z); full <- which(rowSums(obs) == ncol(z))
    if (!length(full) || ncol(z) == 1L) return(h)
    for (t in seq_len(nrow(z))[-seq_len(max(full))]) {
      if (!is.na(h[t])) h[t] <- h[t - 1] * L[t] / L[t - 1]
    }
    h
  },
  growth_A = function(z, m) {                        # g atas A_t (na.rm)
    h <- ref_hybrid(z, m); lv <- z + 100; n <- nrow(z)
    obs <- !is.na(z); full <- which(rowSums(obs) == ncol(z))
    if (!length(full) || ncol(z) == 1L) return(h)
    g <- rowMeans(rbind(NA, lv[-1, , drop = FALSE] / lv[-n, , drop = FALSE] -
                          1), na.rm = TRUE)
    for (t in seq_len(n)[-seq_len(max(full))]) {
      if (!is.na(h[t])) h[t] <- h[t - 1] * (1 + g[t])
    }
    h
  }
)
set.seed(20261023)
hits <- setNames(integer(length(mut)), names(mut))
stop_branch <- empty_B <- nonpos <- 0
for (rep in 1:2000) {
  n <- sample(2:40, 1); k <- sample(1:5, 1); m <- sample(c(0, 0.5, 0.6, 1), 1)
  z <- matrix(rnorm(n * k), n, k)
  for (j in seq_len(k)) {
    s <- sample(0:3, 1); e <- sample(0:3, 1)
    if (s > 0) z[seq_len(min(s, n)), j] <- NA
    if (e > 0) z[max(1, n - e + 1):n, j] <- NA
    if (runif(1) < 0.2) z[sample(n, 1), j] <- NA
  }
  want <- ref_hybrid(z, m)
  L <- old_level(z, m) + 100
  if (any(is.na(want) & !is.na(L))) stop_branch <- stop_branch + 1
  if (any(z + 100 <= 0, na.rm = TRUE)) nonpos <- nonpos + 1
  full <- which(rowSums(!is.na(z)) == k)
  if (length(full) && k > 1L && max(full) < n) {
    tt <- (max(full) + 1):n
    ob <- !is.na(z)
    if (any(rowSums(ob[tt, , drop = FALSE] & ob[tt - 1, , drop = FALSE]) == 0 &
            rowSums(ob[tt, , drop = FALSE]) >= max(1, ceiling(m * k - 1e-9)))) {
      empty_B <- empty_B + 1
    }
  }
  for (nm in names(mut)) {
    got <- mut[[nm]](z, m)
    d <- any(is.na(got) != is.na(want)) ||
      any(abs(got - want) > 1e-12, na.rm = TRUE)
    hits[nm] <- hits[nm] + d
  }
}
say("K6: replikasi dengan cabang 'rantai berhenti tetapi L ada': %d / 2000",
    stop_branch)
say("K6: c_t = 1 dan B_t kosong sesudah b: %d; level <= 0: %d; n = 1: 0",
    empty_B, nonpos)
for (nm in names(hits)) say("K6: mutan %-12s terdeteksi di %4d / 2000", nm,
                            hits[nm])

## K7. Toleransi mutlak 1e-12 vs implementasi setara lain (log-cumsum).
set.seed(3)
w40 <- w400 <- 0
for (r in 1:200) for (n in c(40, 400)) {
  z <- matrix(rnorm(n * 3, sd = 3), n, 3)
  z[(n - n / 2):n, 3] <- NA
  h <- ref_hybrid(z, 0); lv <- z + 100; b <- n - n / 2 - 1
  g <- sapply((b + 1):n, function(t) mean(lv[t, 1:2] / lv[t - 1, 1:2]) - 1)
  h2 <- h; h2[(b + 1):n] <- h[b] * exp(cumsum(log1p(g)))
  d <- max(abs(h - h2))
  if (n == 40) w40 <- max(w40, d) else w400 <- max(w400, d)
}
say("K7: selisih maks loop vs log-cumsum: n = 40 -> %.2e; n = 400 -> %.2e",
    w40, w400)

## K8. q pada batas titik-mengambang: m*k yang secara eksak bulat.
cand <- expand.grid(m = seq(0.05, 0.95, by = 0.05), k = 1:20)
mk <- cand$m * cand$k
exact_int <- abs(mk - round(mk)) < 1e-9
bad <- cand[exact_int & ceiling(mk) != round(mk), ]
say("K8: %d pasangan (m, k) dengan m*k bulat eksak tetapi ceiling(m*k) != m*k;",
    nrow(bad))
say("K8: contoh m = %.17g (dari seq), k = %d: ceiling = %d, dgn -1e-9 = %d",
    bad$m[1], bad$k[1], ceiling(bad$m[1] * bad$k[1]),
    ceiling(bad$m[1] * bad$k[1] - 1e-9))
