# 06 — Review

- Increment: rcli 0.5.1 (FR-011)
- Reviewer: A6 (konteks bersih: ya)
- Putaran: 1 (terhadap a180653; basis c66b115, 0.5.0 di main)
- Review 0.5.0 tersimpan di riwayat git berkas ini (komit b57fb19).

## Yang diperiksa (putaran 1)
- Seluruh diff R/, NEWS.md, man/, harness/ (FR-011, AC-FR-011.1–.12,
  "Increment 0.5.1"), `tests/testthat/test-fixes-051.R`, dan dua uji lama
  yang disesuaikan (`test-ragged-edge.R`, `test-app-e2e.R`).
- Suite uji lengkap pada a180653 (`devtools::test()`, termasuk e2e dengan
  Chrome): 0 gagal, 0 peringatan, 2 dilewati (salah satunya AC-FR-011.12,
  lihat R9). Snapshot print tidak rusak.
- `test-fixes-051.R` dijalankan terhadap kode lama (c66b115) untuk
  memeriksa bukti merah: semua blok gagal/galat kecuali AC-FR-011.6 (lihat
  R1) dan AC-FR-011.12 (dilewati).
- Regresi bawaan: `cli_build()` dengan `cli_spec(f)`, `conference_board()`,
  `principal_component()` dan `oecd_spec(f)` pada `simulate_cycles(seed =
  1:4, freq = 12 dan 4)`, lama vs baru. `cli_spec()` bawaan dan CB: indeks,
  tabel penilaian, dan penyajian identik. Perbedaan hanya pada
  `oecd_spec(4)` (F1: pencilan triwulanan TRAMO kini terhapus; versi lama
  memberi peringatan "NAs introduced by coercion"), penyajian `oecd_spec`
  (G9), dan `@aggregator` PCA satu komponen (R8). Tidak ada peringatan baru
  pada proses biasa (`warn_short_tests()` dan `rcli_warning_fallback` tidak
  muncul pada data bulanan/triwulanan 30 tahun).
- F1 dengan RJDemetra sungguhan: nama `"AO (IV-2009)"`, `"LS (II-2012)"`
  (triwulanan) dan `"AO (6-2013)"`, `"LS (8-2017)"` (bulanan, awal
  2005-03) dipetakan ke indeks waktu yang benar (40, 50, 100, 150).
- F2: tanda dan waktu kelanjutan LS/TC (efek pada n+h = efek[n] untuk LS,
  efek[n]·ρ^h untuk TC) benar secara aljabar; untuk TRAMO bulanan loncatan
  ujung = 0. Laju TC TRAMO triwulanan dari JDemetra+ diverifikasi = 0,7
  (`m$model$effects[, "out_i"]`: 0,3005 → 0,2104 → 0,1472). Laju X-13
  triwulanan = 0,343 (R2).
- F3: logika bendera ujung, nilai pengganti (`v[2] - med`,
  `v[m] + med`), interaksi dengan bendera tengah (lonjakan di observasi 2
  dan n−1 tetap ditangani aturan tengah), seri pendek (MAD 0 → keluar),
  serta laju positif palsu pada inovasi berekor tebal (R3).
- G6/G9: `cycle_level()` benar untuk seri ber-log, tanpa log (kolom yang
  melintasi nol: sama dengan `@original`), dan dengan penyesuaian musim
  (korelasi dengan seri tanpa musim 0,99986 vs 0,979 untuk `@original`).
  Komponen terbalik tetap ditangani lewat `attr(levels, "sign")`.
- G7/E1, E2, E3, E4, E8, E9, dokumentasi `?cli_spec`/`?oecd_spec`
  (dicocokkan dengan `contraction_probability()` dan `convert_one()`).
- Aturan proyek: tidak ada Imports baru, tidak ada cabang
  `if (class == ...)` baru, galat lewat `rcli_abort()` dengan kelas
  `rcli_error_*`, peringatan lewat `rcli_warn()`, panjang baris.

## Temuan putaran 1
- [x] [R1][major] tests/testthat/test-fixes-051.R:AC-FR-011.6 — Uji ini
  lolos juga pada kode lama (0 gagal pada c66b115), jadi bukan bukti merah
  untuk G7/E1. Penyebab: `train <- cli_build(...)` dipanggil **di dalam**
  cakupan `local_mocked_bindings()`, sehingga panggilan `cli_composite()`
  terakhir yang terekam di `seen` berasal dari `cli_build()` kedua itu
  (yang memang membawa geser lag), bukan dari `one_cutoff()`. Perbaikan:
  simpan `k <- length(seen)` segera sesudah `cli_selection_bias()` dan
  bandingkan `seen[[k]]`, atau bangun `train` sebelum memasang mock, atau
  uji akibatnya langsung (misalnya `lead_gap` ≈ 0 untuk komposit yang
  sama). Catatan "merah 27 kegagalan" di `harness/04-test-plan.md` perlu
  disesuaikan.
- [x] [R2][major] R/outliers.R:clean_forecast — Laju peluruhan TC tetap
  0,7, padahal X-13ARIMA-SEATS memakai 0,7^(12/s), yaitu 0,343 untuk data
  triwulanan (tabel `regression.temporarychange` dari X-13 sendiri:
  rasio 0,343). Akibatnya pada mesin X-13 triwulanan prakiraan dikurangi
  terlalu banyak. Bukti (`/tmp/rv051/e3.R`, TC di 2024Q2, efek[n] =
  0,0348): yang dikurangi paket 0,0244 / 0,0170 / 0,0119 / 0,0084 untuk
  h = 1..4, seharusnya 0,0119 / 0,0041 / 0,0014 / 0,0005. Ini mengenai
  bawaan `tramo_outliers()` (`remove = c("AO", "TC")`) dan `oecd_spec(4)`
  bila RJDemetra tidak terpasang (`engine = "auto"` → x13, kasus umum di
  CRAN). Usul: laju menurut mesin dan frekuensi (TRAMO 0,7; X-13
  0,7^(12/f)), atau perkirakan dari `effects[n, "TC"] / effects[n - 1,
  "TC"]` bila TC dimulai sebelum n; tambahkan uji X-13 triwulanan.
- [x] [R3][major] R/cycles.R:replace_outliers — Aturan ujung adalah uji
  **satu** perubahan, sedangkan aturan tengah memerlukan **dua** perubahan
  ekstrem berlawanan tanda; per observasi aturan ujung jauh lebih peka.
  Bukti (`/tmp/rv051/e5.R`, 2000 jalan acak n = 240, ambang bawaan 5):
  inovasi t(3): 50 penggantian di ujung vs 26 di 476.000 titik tengah
  (≈1,25% per titik ujung vs ≈0,005% per titik tengah); t(5): 16 vs 1;
  Gaussian: 0 vs 0. Uji AC-FR-011.3 "ordinary series are not touched"
  hanya memakai Gaussian. Dampak praktis: pada data waktu nyata, kejatuhan
  tajam di bulan terakhir (mis. Maret 2020) dihapus dan diganti `v[m] +
  median(d)` (contoh: 4,982 → 5,134 dalam log), lalu muncul kembali sebulan
  kemudian — jadi justru sinyal terbaru CLI direvisi. Ini mengubah hasil
  bawaan (`robust_outliers()` adalah bawaan) di titik yang paling dibaca,
  tanpa menjalankan ulang `data-raw/calibrate_*.R` /
  `realtime_defaults.R`, padahal rilis menyatakan "defaults unchanged".
  Usul (pilih satu): (a) di ujung awal saja, ujung akhir dibiarkan; (b)
  ambang ujung yang lebih tinggi sehingga laju positif palsu sebanding
  dengan aturan tengah, dikalibrasi; atau (c) tunda ke 0.6.0 bersama
  G1–G5. Tambahkan uji dengan inovasi berekor tebal.
- [x] [R4][minor] R/outliers.R:outlier_period/outlier_effects — Periode di
  luar 1..f tidak ditolak dan "membungkus" diam-diam ke tahun lain:
  `"AO (V-2009)"` pada data triwulanan → indeks 2010Q1, `"AO (13-2009)"`
  bulanan → 2010-01, `"AO (0-2009)"` → 2008-12. Klaim "unparseable →
  rcli_error_outliers" sebaiknya mencakup `per < 1 || per > f`. (Saran
  kecil: untuk TRAMO, efek pencilan tersedia langsung di
  `m$model$effects`, sehingga penguraian nama tidak perlu.)
- [x] [R5][minor] R/presentation.R (roxygen) dan R/app-text.R:pres_help —
  Teks masih "comparable with the original reference" / "sebanding dengan
  seri acuan asli", padahal sejak G9 kolom `reference` adalah seri acuan
  yang disesuaikan musim dan dibersihkan pencilannya. `@return` juga tidak
  menyebutkan hal itu. Perbarui roxygen, kedua bahasa di GUI, dan bila ada,
  buku pedoman.
- [x] [R6][minor] R/candidates.R:cli_candidates — Kandidat kosong dibuang
  dari `data`, `meta`, dan `alignment`, tetapi tidak dari `vintages`
  (`names(x@vintages)` tetap `"dead"`; `/tmp/rv051/e7.R`). Objek menjadi
  tidak konsisten (saat ini `vintages` hampir tidak dipakai, jadi tanpa
  dampak hasil).
- [x] [R7][minor] R/spec.R:setValidity("CliSpec") — Pemeriksaan bilangan
  bulat tidak mencakup `horizon` dan `granger_dmax` (`cli_spec(12, horizon
  = 2.5)` dan `granger_dmax = 0.5` diterima). `max_iter = NA` atau
  `ccf_lag_max = NA` menghasilkan `rcli_error_argument` dengan pesan R
  mentah "missing value where TRUE/FALSE needed" karena fungsi validitas
  sendiri gagal; sebaiknya diperiksa `is.na()` lebih dulu.
- [x] [R8][minor] R/aggregate.R:factor_fallback — Dengan **satu**
  komponen, PCA/DFM kini mencatat `@aggregator` = `EqualWeight` tanpa
  peringatan (`simulate_cycles(seed = 4, freq = 4)`, `principal_component()`:
  `PrincipalComponent -> EqualWeight`). Secara isi benar ("agregator yang
  benar-benar dipakai"), tetapi tampilan `print()`/GUI berubah untuk proses
  biasa; sebutkan di NEWS. Selain itu `one_cutoff()` membangun komposit luar
  sampel dengan `spec@aggregator`, bukan `train@composite@aggregator`
  (nit, hasilnya sama karena fallback akan terjadi lagi).
- [x] [R9][minor] R/assessment.R:min_overlap — Untuk data triwulanan
  tumpang tindih minimum turun dari 24 ke 8. Ini mengubah hasil bawaan
  untuk sampel triwulanan pendek (n = 28: pencarian lag dari ±4 menjadi
  ±8), dan korelasi dari 8 observasi sangat tidak presisi (galat baku
  ≈ 0,35). Sudah tercantum di NEWS; tetapi kalibrasi/`oecd-*.csv` tidak
  dijalankan ulang. Simulasi saya (AR(0,8) independen) tidak menunjukkan
  bias tambahan ke lag tepi dibanding aturan lama, jadi cukup sebagai
  catatan.
- [x] [R10][minor] tests/testthat/test-fixes-051.R — Celah uji: G6 hanya
  diuji untuk komponen ber-log tanpa penyesuaian musim (jalur tanpa log dan
  `seasonal_adjust = TRUE` tidak diuji); F2 ujung-ke-ujung memakai
  `skip_if()` bila X-13 tidak menemukan LS sehingga bisa lolos tanpa
  menguji; uji unit `clean_forecast()` menyalin rumus implementasi
  (tautologis) dan tidak mencakup triwulanan (R2); AC-FR-011.12 selalu
  dilewati pada `devtools::test()` ("help not installed"), hanya berjalan
  di `R CMD check`.
- [x] [R11][nit] R/candidates.R:window — `tryCatch()` menangkap semua galat
  `stats::window()` dan melabelinya "The window lies outside the data",
  termasuk `start` sesudah `end` di dalam rentang data; pesan menyesatkan.
- [x] [R12][nit] tests/testthat/test-fixes-051.R baris 97 dan 140 — 81
  karakter (aturan ≤ 80); `lintr` tidak melaporkannya, tetapi `nchar()`
  memastikan 81.
- [x] [R13][nit] NEWS.md — (a) F1: versi lama tidak "skipped silently";
  ia memberi peringatan "NAs introduced by coercion". (b) Kalimat pembuka
  "Defaults are unchanged" sebaiknya ditambah bahwa **hasil** bawaan dapat
  berubah: pencilan di ujung seri (F3), sampel triwulanan pendek (E8),
  `oecd_spec()` triwulanan (F1), dan `@aggregator` satu komponen (R8).

Catatan positif: F1, G6, G9, E2, E3, E4, E8, E9 benar secara logika dan
terbukti; tidak ada regresi pada `cli_spec()` bawaan; GUI dan snapshot
utuh; tidak ada Imports baru dan tidak ada cabang kelas baru.

## Keputusan putaran 1
request changes

Tiga temuan major harus diselesaikan dulu: R1 (uji G7 tidak membuktikan
apa pun), R2 (laju TC X-13 triwulanan salah pada jalur bawaan
`oecd_spec(4)` tanpa RJDemetra), dan R3 (aturan ujung F3 mengubah hasil
bawaan waktu nyata dan perlu dibatasi, dikalibrasi, atau ditunda). R4–R10
sebaiknya ditangani di putaran yang sama; R11–R13 opsional.

## Tindak lanjut putaran 1
- R1: `train` dibangun sebelum mock dipasang; panggilan direkam dengan
  `seen[i] <- list(shifts)` agar `NULL` ikut tercatat. Bukti merah: dengan
  `R/selection-bias.R` dari c66b115 uji ini gagal (1 kegagalan).
- R2: `tc_rate(engine, f)`: TRAMO 0,7; X-13 0,7^(12/f). Mesin mengembalikan
  lajunya (`fit$tc_rate`) dan `clean_forecast()` memakainya. Uji baru
  AC-FR-011.2b: X-13 triwulanan sungguhan, laju = rasio efek X-13 (0,343).
- R3: opsi (a): hanya ujung awal; observasi terakhir tidak disentuh.
  Uji: ujung akhir tidak berubah, termasuk 200 jalan acak t(3).
  Kalibrasi tidak perlu dijalankan ulang: ujung akhir kembali seperti
  0.5.0, ujung awal tidak memengaruhi sinyal terbaru (catatan di NEWS).
- R4: periode di luar 1..f → `rcli_error_outliers` (uji V, 13, 0).
- R5: roxygen `cli_presentation()` dan `pres_help` (dua bahasa); pedoman.
- R6: kandidat kosong juga dibuang dari setiap vintage (uji baru).
- R7: slot skalar selain `horizon` tidak boleh NA; `granger_dmax` dan
  `horizon` harus bilangan bulat (uji baru).
- R8: dicatat di NEWS; `one_cutoff()` dibiarkan (hasil sama).
- R9: dicatat (sudah di NEWS).
- R10: uji G6 tanpa log (`transform = "none"`); F2 triwulanan (R2).
  AC-FR-011.12 berjalan di `R CMD check`.
- R11: `window()` memeriksa rentang sendiri; galat lain dari
  `stats::window()` diteruskan apa adanya (uji `start` > `end`).
- R12: baris 81 karakter dipecah. R13: NEWS diperbaiki.
