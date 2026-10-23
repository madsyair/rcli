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

## Kebutuhan nonfungsional
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
| F-02 | Perpanjangan AR pada perubahan (Yule-Walker, orde AIC) dan prakiraan kumulatif | Brockwell & Davis (1991), *Time Series: Theory and Methods* (rujukan `?stats::ar`); Akaike (1974) untuk AIC | FR-002 |

## Di luar cakupan
- Perpanjangan bermusim (SARIMA) dan prakiraan dari model multivariat.
- Mengubah `oecd_aggregate()`, klasifikasi, atau ambang.
- Evaluasi pada data BPS/BI (direkomendasikan kajian, dikerjakan terpisah).

## Pertanyaan terbuka
- (tidak ada; keputusan pengguna: "Lanjutkan ke versi 0.2.0 sesuai kajian")
