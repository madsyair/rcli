# 01 — Kebutuhan (rcli 0.2.0)

## Tujuan dan pengguna sasaran
Mengganti dua bawaan `rcli` sesuai kajian "Kajian: metode OECD yang unggul
sebagai bawaan rcli" (23 Oktober 2026): agregasi bobot sama yang disambung
berantai di ujung seri, dan perpanjangan ujung seri dengan model AR sebelum
penyaring siklus. Pengguna: analis BPS/BI yang memperbarui CLI bulanan ketika
sebagian komponen belum terbit (ujung seri compang-camping). Data: matriks
siklus ternormalisasi `z` (n × k, nilai hilang di awal/ujung) dan seri
tertransformasi (log) tanpa nilai hilang di tengah.

## Kebutuhan fungsional

### FR-001 — Agregasi bobot sama hibrida sebagai bawaan
`equal_weight(min_coverage = 0.6, ragged_edge = c("chain", "level"))`;
`cli_spec()` memakai `equal_weight()` dengan `ragged_edge = "chain"`.
- AC-FR-001.1  Diberikan z = cbind(a = c(0, 1, 2, 3), b = c(0, 1, 2, 3), c = c(0, 1, 2, NA)), ketika `aggregate_components(equal_weight(), z, NULL, spec)` dipanggil, maka cycle[1:3] = rowMeans(z)[1:3] dan cycle[4] = cycle[3] + 1 (toleransi 1e-12; F-01 revisi 2, bentuk aditif).
- AC-FR-001.2  Diberikan z tanpa nilai hilang, maka hasil `ragged_edge = "chain"` identik dengan rowMeans(z) dan dengan `ragged_edge = "level"`, sehingga komposit identik dengan 0.1.3.
- AC-FR-001.3  Diberikan komponen yang baru terbit belakangan (NA di awal) dan semua lengkap di ujung, maka hasil "chain" sama dengan "level" (toleransi 1e-12): sambungan berantai hanya di ujung.
- AC-FR-001.4  Kasus tepi: tanggal sesudah periode lengkap terakhir dengan kurang dari q komponen yang punya perubahan → NA, dan semua tanggal sesudahnya NA (rantai berhenti); tidak ada baris lengkap → sama dengan "level"; satu komponen atau satu baris → sama dengan "level"; guncangan besar → langkah tidak melebihi perubahan komponen terbesar.
- AC-FR-001.5  `ragged_edge = "level"` mereproduksi `equal_weight()` 0.1.3 (rata-rata langsung dengan aturan cakupan) persis.
- AC-FR-001.6  Argumen salah (`ragged_edge = "x"`) → galat `rcli_error_argument`.
- AC-FR-001.7  Objek `EqualWeight` yang disimpan versi 0.1.x (tanpa slot `ragged_edge`) diagregasi dengan "level".
- AC-FR-001.8  Cadangan `principal_component()` dan `dynamic_factor()` (terlalu sedikit baris lengkap) memakai `equal_weight()` bawaan, jadi ikut merantai di ujung seri (keputusan ADR-001).

### FR-002 — Perpanjangan ujung seri sebagai bawaan
Kelas strategi `Extension` dengan `ar_extension(h = NULL, order_max = NULL)` dan `no_extension()`; generic `extend_series(extension, x)` mengembalikan vektor prakiraan; slot `extension` di `CliSpec`, bawaan `ar_extension()`.
- AC-FR-002.1  Diberikan x = ts dengan tren linear murni (x_t = 0,01 t, bulanan), ketika `extend_series(ar_extension(h = 12), x)`, maka hasil = x_n + 0,01 × (1:12) (toleransi 1e-8).
- AC-FR-002.2  `h = NULL` → panjang prakiraan = frekuensi (12 bulanan, 4 triwulanan). `no_extension()` → `numeric(0)`.
- AC-FR-002.3  Diberikan seri AR(1) pada perubahan dengan φ = 0,6 (n = 600, seed tetap), maka prakiraan 1 langkah = x_n + μ + φ̂(Δx_n − μ) dengan φ̂ dari `stats::ar` (cocok dengan `predict(stats::ar(...))`, toleransi 1e-10).
- AC-FR-002.4  `cli_cycles()` mencatat langkah "series extended by h-period forecasts: <label strategi>"; panjang siklus tetap sama dengan data.
- AC-FR-002.5  Prakiraan dari `tramo_outliers()` didahulukan; perpanjangan AR tidak dipakai bila perlakuan pencilan sudah memberi prakiraan.
- AC-FR-002.6  Kasus tepi: perubahan konstan (varians nol) → prakiraan garis lurus dengan rerata perubahan, tanpa galat; `h` bukan bilangan bulat ≥ 1 → `rcli_error_argument`.
- AC-FR-002.7  Spesifikasi 0.1.x tanpa slot `extension` → tanpa perpanjangan.

### FR-003 — Konfigurasi, OECD, dan GUI
- AC-FR-003.1  `cli_spec()` menerima `extension = NULL` (bawaan AR); `update(spec, extension = no_extension())` bekerja; `show()` mencetak baris perpanjangan.
- AC-FR-003.2  `oecd_spec()` memakai `no_extension()` dan `oecd_aggregate()` (prakiraan dari TRAMO).
- AC-FR-003.3  GUI langkah 3: pilihan agregasi "Equal weights, chained at the ragged edge" dan "Equal weights, plain mean (rcli 0.1)", kotak centang perpanjangan AR (bawaan aktif); skrip ekspor mereproduksi komposit untuk kombinasi apa pun.
- AC-FR-003.4  Cara mendapat hasil 0.1.x: `cli_spec(aggregator = equal_weight(ragged_edge = "level"), extension = no_extension())` memberi komposit identik dengan 0.1.3 (diuji terhadap nilai yang dihitung dengan cara lama).

## Increment rcli 0.2.1 (keputusan pengguna 23 Oktober 2026: "Kinerja: pilihan b"; "iya" untuk menggabungkan PR #1)

### FR-004 — Penyaring HP dengan penyelesai pita O(n)
`hp_trend_core()` menyelesaikan (I + λD₂ᵀD₂)τ = x dengan faktorisasi LDLᵀ pita (F-03) alih-alih `solve()` matriks padat.
- AC-FR-004.1  Untuk n ∈ {4, 5, 6, 50, 372} dan λ ∈ {0; 13,9; 1600; 133 107,9}, hasil sama dengan `solve(diag(n) + λ crossprod(D2), x)` (toleransi relatif 1e-9).
- AC-FR-004.2  x linear → τ = x (toleransi 1e-8 relatif); untuk x acak Σ τ = Σ x dan Σ tτ = Σ tx (toleransi 1e-8 relatif).
- AC-FR-004.3  Galat mundur ternorma η = ‖Aτ − x‖∞ / (‖A‖∞‖τ‖∞ + ‖x‖∞) ≤ 10u (u = `.Machine$double.eps`) untuk λ = 133 107,9, n = 372 (Higham 2002, §7.1). Revisi: batas semula ‖Aτ − x‖∞/‖x‖∞ ≤ 1e-10 lebih ketat daripada teori (≈ u‖A‖ ≈ 5e-10) dan juga dilanggar oleh `solve()` padat.
- AC-FR-004.4  λ = 0 → τ = x; n < 4 → `rcli_error_short_series`.
- AC-FR-004.5  Uji replikasi `mFilter::hpfilter` tetap lolos (triwulanan λ = 1600) dan ditambah uji bulanan λ = 129 600 (review R8; uji `neverhpfilter` menguji penyaring Hamilton, bukan HP).
- AC-FR-004.6  n = 100 000 selesai (cara padat butuh memori 80 GB), dalam < 5 detik tanpa instrumentasi covr. Revisi: di CI cakupan, instrumentasi covr membuat loop R lebih lambat (5,47 detik), jadi batas waktu hanya berlaku tanpa covr.

### FR-005 — Indeks koinsiden (PR #1) di seri 0.2
- AC-FR-005.1  Semua uji PR #1 (`test-coincident.R`, `test-app.R`, `test-app-e2e.R`, `test-quality.R`, `test-selection-bias.R`) lolos dengan bawaan 0.2.0.
- AC-FR-005.2  `data-raw/calibrate_coincident.R` dijalankan ulang dengan bawaan 0.2.0: pada noise 0,4 pangsa lolos komposit yang benar-benar koinsiden ≥ 0,9 (bulanan dan triwulanan), komposit pendahulu/tertinggal 3 bulan ≤ 0,05.
- AC-FR-005.3  Skrip ekspor GUI mereproduksi indeks koinsiden (uji e2e).

### NFR-002 (revisi 0.2.1) — Kinerja
- AC-NFR-002.2  Waktu `cli_cycles()` per seri dengan perpanjangan AR (bawaan 0.2.1) ≤ waktu 0.1.3 tanpa perpanjangan, sehingga penyimpangan 0.2.0 (+16%) tertutup.
  - Hasil ukur (2026-10-23, median 15 ulangan, 7 seri `simulate_cycles(seed = 1)`): 0.2.0 terpasang (solve() padat) tanpa perpanjangan 0,0727 detik, dengan AR 0,0793 detik; 0.2.1 tanpa perpanjangan 0,0021 detik, dengan AR 0,0033 detik. Waktu dibagi 7 kandidat; `cli_cycles()` juga memproses seri acuan (8 seri), sehingga per seri sekitar 0,0029 detik. **Terpenuhi**: 0,0033 ≤ 0,0727.

## Increment rcli 0.2.2 (keputusan pengguna 24 Oktober 2026: "Iya. Kerjakan")

### FR-006 — GUI: judul dengan versi dan indeks sejalan sebagai seri acuan
- AC-FR-006.1  Judul GUI berbunyi "rcli <versi>: Indikator Komposit Pendahulu dan Sejalan" (id) dan "rcli <versi>: Composite Leading and Coincident Indicators" (en), dengan versi dari `utils::packageVersion("rcli")`.
- AC-FR-006.2  Langkah 9 punya tombol `cci_ref`. Tanpa indeks sejalan, tombol hanya memberi peringatan. Dengan indeks, `cci_as_reference()` dijalankan; langkah 1–2 berisi himpunan kandidat baru (acuan "cci", tanpa acuan lama dan komponen indeks), langkah 3 dan sesudahnya dikosongkan, panel pindah ke langkah 3.
- AC-FR-006.3  Metadata kandidat (rasional, tipe, sumber) dipertahankan menurut nama kandidat, termasuk di isian langkah 2.
- AC-FR-006.4  Skrip R ekspor mereproduksi komposit yang dibentuk terhadap indeks sejalan (indeks sama persis), baik tanpa maupun dengan pengulangan langkah 2; memuat analisis pertama, `cand <- cci_as_reference(cci)`, dan analisis kedua.
- AC-FR-006.5  Langkah 1 yang dijalankan ulang menghapus rangkaian ini.

### NFR-001 — Tanpa dependensi baru
- AC-NFR-001.1  DESCRIPTION Imports tidak berubah; AR memakai `stats::ar`.
### NFR-002 — Kinerja
- AC-NFR-002.1  Waktu `cli_cycles()` per seri bertambah ≤ 10% dibanding tanpa perpanjangan (kajian: 0,060 → 0,061 detik).
  - Hasil ukur tanpa beban (2026-10-23, median 15 ulangan, 8 seri): 0,0511 → 0,0593 detik (+16%, +8 ms per seri). **Tidak terpenuhi seperti tertulis.** Penyebab utama: penyaring HP memakai `solve()` matriks padat O(n³), sehingga 12 observasi tambahan menambah sekitar 10%. Diterima sebagai penyimpangan karena tambahan absolutnya kecil (±0,07 detik untuk `cli_build()` 8 seri); usul increment berikutnya: penyelesai pentadiagonal O(n) untuk HP.
### NFR-003 — Kalibrasi dan mutu
- AC-NFR-003.1  Harness kalibrasi dijalankan ulang; pangsa salah pendahulu ≤ 1,5% di semua skenario; `inst/calibration/accuracy.csv`, vinyet, dan `?cli_spec` diperbarui.
- AC-NFR-003.2  Cakupan uji ≥ 90%; `R CMD check --as-cran` 0 galat, 0 peringatan.

## Formula dan algoritma
| ID | Nama | Sumber awal / "baru" | Dipakai oleh |
|---|---|---|---|
| F-01 | Agregasi bobot sama hibrida (rata-rata langsung, rantai rata-rata perubahan sesudah baris lengkap terakhir; revisi 2) | baru (gabungan Gyomai & Guidetti 2012, p. 9, dengan rata-rata langsung) | FR-001 |
| F-03 | Penyaring HP dengan LDLᵀ pita O(n) | Hodrick & Prescott (1997); Golub & Van Loan (2013, §4.1–4.3); Higham (2002, bab 10) | FR-004 |
| F-02 | Perpanjangan AR pada perubahan (Yule-Walker, orde AIC) dan prakiraan kumulatif | Brockwell & Davis (1991), *Time Series: Theory and Methods* (rujukan `?stats::ar`); Akaike (1974) untuk AIC | FR-002 |

## Di luar cakupan
- Perpanjangan bermusim (SARIMA) dan prakiraan dari model multivariat.
- Mengubah `oecd_aggregate()`, klasifikasi, atau ambang.
- Evaluasi pada data BPS/BI (direkomendasikan kajian, dikerjakan terpisah).

## Pertanyaan terbuka
- (tidak ada; keputusan pengguna: "Lanjutkan ke versi 0.2.0 sesuai kajian")
