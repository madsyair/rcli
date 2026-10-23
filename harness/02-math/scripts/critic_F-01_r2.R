# Critic A2c, putaran 2, untuk F-01 revisi 2 (rantai aditif).
# Jalankan: Rscript harness/02-math/scripts/critic_F-01_r2.R  (~20 detik)
suppressMessages(devtools::load_all("/home/claude/rcli", quiet = TRUE))
ns <- asNamespace("rcli")
spec <- cli_spec(12)
ew <- function(z, m = 0.6, edge = "chain") {
  aggregate_components(equal_weight(m, edge), z, NULL, spec)$cycle
}
lv <- function(z, m = 0.6) ew(z, m, "level")
say <- function(...) cat(sprintf(...), "\n")

## R1. Kasus batas --------------------------------------------------------
say("== R1 kasus batas")
say("n=1 lengkap identik: %s", identical(ew(cbind(a = 1, b = 2)),
                                       lv(cbind(a = 1, b = 2))))
say("n=1 tak lengkap identik: %s", identical(ew(cbind(a = 1, b = NA)),
                                           lv(cbind(a = 1, b = NA))))
z0 <- matrix(NA_real_, 4, 3, dimnames = list(NULL, letters[1:3]))
say("semua NA: %s", paste(ew(z0), collapse = " "))
zk1 <- cbind(a = c(1, NA, 3, NA))
say("k=1 dengan celah: chain %s | level %s", paste(ew(zk1), collapse = " "),
    paste(lv(zk1), collapse = " "))
zm <- cbind(a = c(0, 1, 2, 3), b = c(0, 1, 2, NA), c = c(0, 1, NA, NA))
say("m=1: chain %s | level %s", paste(ew(zm, 1), collapse = " "),
    paste(lv(zm, 1), collapse = " "))
say("m=0: chain %s", paste(round(ew(zm, 0), 3), collapse = " "))
zi <- cbind(a = c(0, 1, Inf, 2), b = c(0, 1, 2, NA))
say("Inf teramati (tidak ditolak): %s",
    paste(ew(zi, 0.5), collapse = " "))
zb <- cbind(a = c(0, 1e308, -1e308), b = c(0, 1e308, NA))
say("nilai sangat besar: %s", paste(ew(zb, 0.5), collapse = " "))
say("q untuk m = seq(...)[12] = %.17g, k = 5: %d; literal 0.6*5 = %.17g",
    seq(0.05, 0.95, 0.05)[12], max(1, ceiling(seq(0.05, 0.95, 0.05)[12] * 5
                                              - 1e-9)), 0.6 * 5)

## R2. Usulan Proposisi 7: kolom berselang (dijamin cli_cycles) ------------
## Bila setiap kolom teramati pada satu selang [s_i, e_i] dan F tidak kosong,
## maka untuk t > b: B_t = A_t, dom(H) = dom(L), dan H_t = rata-rata panel
## terimputasi (komponen yang berhenti dibawa dengan perubahan rata-rata).
say("== R2 kolom berselang (k sampai 8, n sampai 60, 3000 matriks)")
set.seed(7)
bad_dom <- 0; bad_imp <- 0; worst <- 0; ratio <- 0
for (r in 1:3000) {
  n <- sample(2:60, 1); k <- sample(1:8, 1); m <- sample(c(0, .5, .6, 1), 1)
  z <- matrix(rt(n * k, 3), n, k, dimnames = list(NULL, letters[1:k]))
  for (j in 1:k) {
    s <- sample(0:5, 1); e <- sample(0:8, 1)
    if (s > 0) z[seq_len(min(s, n)), j] <- NA
    if (e > 0) z[max(1, n - e + 1):n, j] <- NA
  }
  h <- ew(z, m); l <- lv(z, m)
  full <- which(complete.cases(z))
  if (length(full) == 0) next
  b <- max(full)
  bad_dom <- bad_dom + sum(is.na(h) != is.na(l))
  zh <- z; imp <- rep(NA_real_, n); imp[b] <- mean(z[b, ])
  for (t in seq_len(n)[-seq_len(b)]) {
    o <- !is.na(z[t, ])
    if (sum(o) < max(1, ceiling(m * k - 1e-9))) break
    d <- mean(z[t, o] - zh[t - 1, o])
    zh[t, !o] <- zh[t - 1, !o] + d
    imp[t] <- mean(zh[t, ])
  }
  ok <- !is.na(h) & seq_len(n) >= b
  bad_imp <- bad_imp + sum(is.na(imp[ok]))
  worst <- max(worst, abs(h[ok] - imp[ok]), na.rm = TRUE)
  ratio <- max(ratio, max(abs(h), na.rm = TRUE) / max(abs(z), na.rm = TRUE))
}
say("dom(H) != dom(L): %d; H tanpa imputasi: %d; |H - imputasi| maks %.2e",
    bad_dom, bad_imp, worst)
say("maks |H| / maks |z| pada kolom berselang: %.3f", ratio)

## R2b. Lewat cli_composite: celah interior pada data mentah diisi
##      (fill_internal_na), sehingga kolom z selalu berselang.
sim <- simulate_cycles(seed = 3)
sim[300, "lead_3"] <- NA
sim[(nrow(sim) - 1):nrow(sim), "lead_6"] <- NA
cyc <- cli_cycles(cli_candidates(sim, "reference",
  meta = data.frame(name = colnames(sim)[-1], rationale = "early_stage")),
  cli_spec(12, extension = no_extension()))
zz <- sapply(c("lead_6", "lead_3"), function(nm) as.numeric(cyc[[nm]]@normalised))
runs <- apply(!is.na(zz), 2, function(v) length(rle(v)$lengths))
say("cli_cycles: banyak blok NA/teramati per kolom (<= 3 berarti selang): %s",
    paste(runs, collapse = " "))

## R3. Kontra-contoh: ekor tak bersarang, m = 0,6 bawaan ------------------
## Dua komponen datar, tiga komponen bergiliran (-1, 1, NA). Setiap tanggal
## |A_t| = 4 dan |B_t| = 3 = q, jadi rantai jalan terus, tetapi lompatan
## komponen yang masuk kembali dibuang dan H hanyut 2/3 per langkah.
say("== R3 hanyutan pada ekor tak bersarang (m = 0,6, k = 5)")
tail_n <- 30
pat <- function(ph) c(-1, 1, NA)[(ph %% 3) + 1]
zt <- cbind(a = 0, b = 0, c = pat(0:tail_n), d = pat(1:(tail_n + 1)),
            e = pat(2:(tail_n + 2)))
zt <- rbind(c(0, 0, 0, 0, 0), zt)
h <- ew(zt); l <- lv(zt)
say("rentang z: [%g, %g]; L ujung %.3f; H ujung %.3f; |B_t| min %d",
    min(zt, na.rm = TRUE), max(zt, na.rm = TRUE), l[nrow(zt)], h[nrow(zt)],
    min(sapply(3:nrow(zt), function(t) sum(!is.na(zt[t, ]) &
                                             !is.na(zt[t - 1, ])))))

## R4. Kontra-contoh: H lebih pendek dari L (satu NA terisolasi) ----------
say("== R4 domain H lebih sempit dari L")
set.seed(4)
zd <- matrix(rnorm(40 * 3), 40, 3, dimnames = list(NULL, c("a", "b", "c")))
zd[11:40, "a"] <- NA   # komponen a berhenti di t = 10
zd[15, "b"] <- NA      # satu NA terisolasi di b
h <- ew(zd); l <- lv(zd)
say("t dengan L ada tetapi H NA: %d dari %d (pertama t = %d)",
    sum(!is.na(l) & is.na(h)), sum(!is.na(l)),
    min(which(!is.na(l) & is.na(h))))

## R5. Galat titik-mengambang terhadap acuan rasional (seri panjang) ------
say("== R5 galat pada ekor panjang (n - b = 5000, nilai ~ 1e3)")
set.seed(5)
nb <- 5000
zl <- matrix(round(rnorm((nb + 1) * 3) * 1e3, 2), nb + 1, 3,
             dimnames = list(NULL, c("a", "b", "c")))
zl[-1, "c"] <- NA
h <- ew(zl)
exact <- mean(zl[1, ]) + cumsum(c(0, diff(rowMeans(zl[, 1:2]))))
say("selisih maks terhadap bentuk tertutup: %.2e (eps*(n-b)*max|z| = %.2e)",
    max(abs(h - exact)), .Machine$double.eps * nb * max(abs(zl), na.rm = TRUE))

## R6. Analisis mutan terhadap test-ragged-edge.R dan grid F-01_numeric.R --
say("== R6 mutan")
orig <- get("chain_ragged_edge", ns)
mut <- list(
  restart = function(z, comp, min_coverage) {
    n <- nrow(z); full <- which(stats::complete.cases(z))
    if (length(full) == 0L) return(comp)
    last <- max(full); if (last == n) return(comp)
    q <- max(1, ceiling(min_coverage * ncol(z) - 1e-9)); out <- comp
    for (t in (last + 1L):n) {
      both <- !is.na(z[t, ]) & !is.na(z[t - 1L, ])
      if (sum(both) < q || is.na(out[t - 1L])) next
      out[t] <- out[t - 1L] + mean(z[t, both] - z[t - 1L, both])
    }
    out
  },
  no_tol = function(z, comp, min_coverage) {
    n <- nrow(z); full <- which(stats::complete.cases(z))
    if (length(full) == 0L) return(comp)
    last <- max(full); if (last == n) return(comp)
    q <- max(1, ceiling(min_coverage * ncol(z))); out <- comp
    out[(last + 1L):n] <- NA_real_
    for (t in (last + 1L):n) {
      both <- !is.na(z[t, ]) & !is.na(z[t - 1L, ])
      if (sum(both) < q || is.na(out[t - 1L])) break
      out[t] <- out[t - 1L] + mean(z[t, both] - z[t - 1L, both])
    }
    out
  },
  first_gap = function(z, comp, min_coverage) {
    n <- nrow(z); cc <- stats::complete.cases(z); full <- which(cc)
    if (length(full) == 0L) return(comp)
    after <- which(!cc & seq_len(n) > min(full))
    last <- if (length(after)) min(after) - 1L else n
    if (last == n) return(comp)
    q <- max(1, ceiling(min_coverage * ncol(z) - 1e-9)); out <- comp
    out[(last + 1L):n] <- NA_real_
    for (t in (last + 1L):n) {
      both <- !is.na(z[t, ]) & !is.na(z[t - 1L, ])
      if (sum(both) < q || is.na(out[t - 1L])) break
      out[t] <- out[t - 1L] + mean(z[t, both] - z[t - 1L, both])
    }
    out
  },
  div_k = function(z, comp, min_coverage) {
    n <- nrow(z); full <- which(stats::complete.cases(z))
    if (length(full) == 0L) return(comp)
    last <- max(full); if (last == n) return(comp)
    q <- max(1, ceiling(min_coverage * ncol(z) - 1e-9)); out <- comp
    out[(last + 1L):n] <- NA_real_
    for (t in (last + 1L):n) {
      both <- !is.na(z[t, ]) & !is.na(z[t - 1L, ])
      if (sum(both) < q || is.na(out[t - 1L])) break
      out[t] <- out[t - 1L] + sum(z[t, both] - z[t - 1L, both]) / ncol(z)
    }
    out
  },
  level_diff = function(z, comp, min_coverage) {
    n <- nrow(z); full <- which(stats::complete.cases(z))
    if (length(full) == 0L) return(comp)
    last <- max(full); if (last == n) return(comp)
    q <- max(1, ceiling(min_coverage * ncol(z) - 1e-9)); out <- comp
    out[(last + 1L):n] <- NA_real_
    for (t in (last + 1L):n) {
      both <- !is.na(z[t, ]) & !is.na(z[t - 1L, ])
      if (sum(both) < q || is.na(out[t - 1L])) break
      out[t] <- out[t - 1L] + mean(z[t, ], na.rm = TRUE) -
        mean(z[t - 1L, ], na.rm = TRUE)
    }
    out
  }
)
grid_ok <- function() {
  ref <- function(z, m) {
    environment(orig) <- ns
    ag <- equal_weight(m, "level")
    comp <- aggregate_components(ag, z, NULL, spec)$cycle
    orig(z, comp, m)
  }
  set.seed(20261023); bad <- 0
  for (r in 1:2000) {
    n <- sample(1:40, 1); k <- sample(1:5, 1)
    m <- sample(c(0, 0.5, 0.6, 1, seq(0.05, 0.95, 0.05)[12]), 1)
    z <- matrix(rt(n * k, 3), n, k, dimnames = list(NULL, letters[1:k]))
    for (j in 1:k) {
      s <- sample(0:3, 1); e <- sample(0:3, 1)
      if (s > 0) z[seq_len(min(s, n)), j] <- NA
      if (e > 0) z[max(1, n - e + 1):n, j] <- NA
      if (runif(1) < 0.2) z[sample(n, 1), j] <- NA
    }
    a <- ew(z, m); b <- ref(z, m)
    if (!isTRUE(all.equal(a, b, tolerance = 1e-12))) bad <- bad + 1
  }
  bad
}
run_tests <- function() {
  res <- as.data.frame(testthat::test_file(
    "/home/claude/rcli/tests/testthat/test-ragged-edge.R",
    reporter = "silent", package = "rcli", load_package = "none"))
  sum(res$failed) + sum(res$error)
}
for (nm in names(mut)) {
  f <- mut[[nm]]; environment(f) <- ns
  unlockBinding("chain_ragged_edge", ns)
  assign("chain_ragged_edge", f, envir = ns)
  tf <- tryCatch(run_tests(), error = function(e) NA)
  gb <- grid_ok()
  assign("chain_ragged_edge", orig, envir = ns)
  lockBinding("chain_ragged_edge", ns)
  say("mutan %-10s: kegagalan test-ragged-edge.R %s; grid berbeda %d/2000",
      nm, tf, gb)
}
