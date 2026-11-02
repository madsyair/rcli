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

## Increment rcli 0.3.0 (keputusan pengguna 24 Oktober 2026: "Iya. Kerjakan")

### FR-006 — GUI: judul dengan versi dan indeks sejalan sebagai seri acuan
- AC-FR-006.1  Judul GUI berbunyi "rcli <versi>: Indikator Komposit Pendahulu dan Sejalan" (id) dan "rcli <versi>: Composite Leading and Coincident Indicators" (en), dengan versi dari `utils::packageVersion("rcli")`.
- AC-FR-006.2  Langkah 9 punya tombol `cci_ref`. Tanpa indeks sejalan, tombol hanya memberi peringatan. Dengan indeks, `cci_as_reference()` dijalankan; langkah 1–2 berisi himpunan kandidat baru (acuan "cci", tanpa acuan lama dan komponen indeks), langkah 3 dan sesudahnya dikosongkan, panel pindah ke langkah 3.
- AC-FR-006.3  Metadata kandidat (rasional, tipe, sumber) dipertahankan menurut nama kandidat, termasuk di isian langkah 2.
- AC-FR-006.4  Skrip R ekspor mereproduksi komposit yang dibentuk terhadap indeks sejalan (indeks sama persis), baik tanpa maupun dengan pengulangan langkah 2; memuat analisis pertama, `cand <- cci_as_reference(cci)`, dan analisis kedua.
- AC-FR-006.5  Langkah 1 yang dijalankan ulang menghapus rangkaian ini.

### FR-007 — Frekuensi asal setiap seri (keputusan pengguna 24 Oktober 2026: "Iya. Kerjakan usulan frekuensi")
Ekspor `series_frequencies` (daily, weekly, monthly, quarterly, semiannual, annual); argumen `frequency` pada `cli_align()`; kolom `frequency` pada metadata `cli_candidates()`; isian frekuensi asal di GUI langkah 2.
- AC-FR-007.1  `cli_align()` mengenali data semesteran dan tahunan, baik data frame bertanggal (jarak 175–190 dan 360–370 hari) maupun `ts` berfrekuensi 2 dan 1.
- AC-FR-007.2  Seri acuan semesteran atau tahunan didisagregasi ke frekuensi target (bulanan atau triwulanan) dengan kendala agregasi sesuai tipenya: Denton–Cholette dengan rasio k umum (F-04, bawaan) atau Chow–Lin (tempdisagg); untuk keduanya kendala dipenuhi persis (toleransi 1e-8): jumlah k nilai = nilai asal (aliran), rata-rata k nilai (rata-rata), nilai ke-k (stok). Interpolasi linear (pilihan) menempatkan nilai di tengah periode (aliran, rata-rata) atau di akhir periode (stok).
- AC-FR-007.3  Untuk k = 3 (triwulanan ke bulanan), hasil Denton–Cholette identik dengan versi 0.2.1 (toleransi 1e-10).
- AC-FR-007.4  Kandidat semesteran atau tahunan → galat `rcli_error_frequency` yang menyebut bahwa frekuensi itu hanya boleh untuk seri acuan, baik di `cli_align()` maupun di metadata `cli_candidates()`.
- AC-FR-007.5  Frekuensi yang dinyatakan di `cli_align(frequency = )` berbeda dari frekuensi yang terdeteksi → galat `rcli_error_frequency` yang menyebut keduanya; nilai atau nama yang tidak dikenal → `rcli_error_argument`.
- AC-FR-007.6  `cli_candidates()` menyimpan kolom `frequency` di metadata: dari `meta`, atau dari catatan `cli_align()` bila tidak diisi; nilai tidak dikenal → `rcli_error_argument`.
- AC-FR-007.7  GUI langkah 2 punya isian "Frekuensi asal" per kandidat; nilainya masuk metadata dan skrip ekspor; kandidat semesteran/tahunan memberi pesan galat dan langkah 2 tidak selesai.

## Increment rcli 0.3.1 (keputusan pengguna 31 Oktober 2026: "Iya. Beri opsi untuk pemisah csv")

### FR-008 — GUI: pemisah kolom dan tanda desimal berkas CSV
GUI langkah 1 punya isian `csv_sep` (otomatis, koma, titik koma, tab) dan `csv_dec` (otomatis, titik, koma) untuk berkas yang diunggah.
- AC-FR-008.1  Berkas berpemisah titik koma dan berdesimal koma (bentuk Excel berbahasa Indonesia) terbaca benar dengan pilihan otomatis maupun pilihan eksplisit; nilainya sama persis dengan berkas berpemisah koma yang setara.
- AC-FR-008.2  Pengenalan otomatis (revisi sesudah review R1–R3): pemisah adalah yang membagi setiap baris menjadi jumlah kolom yang sama (tanda kutip dihormati), dengan urutan pilihan tab, titik koma, lalu koma, bukan menurut lebar (revisi putaran 2: koma desimal melebarkan pemisah koma); tanda desimal mengikuti mayoritas sel yang tegas (`1,5`, `1.234,5`, `1.234.567` untuk koma; `1.5`, `1,234.5`, `1,234,567` untuk titik), bukan hanya baris pertama; sel seperti `1.012` atau `12,345` tidak dihitung, dan bila hanya sel seperti itu yang ada, tanda yang dipakai di sel itu dianggap pemisah ribuan sehingga kolomnya dibuang dengan peringatan, bukan terbaca keliru; pemisah koma selalu bertitik desimal. Teks diperiksa sebagai bita, sehingga berkas Windows-1252 terbaca pada sesi UTF-8. Berkas berpemisah tab juga terbaca.
- AC-FR-008.3  Pemisah dan tanda desimal yang sama (koma dan koma) → galat `rcli_error_argument`; langkah 1 tidak selesai.
- AC-FR-008.4  Skrip R ekspor memakai `sep` dan `dec` yang benar-benar dipakai (hasil pengenalan otomatis), hanya bila berbeda dari bawaan `read.csv()`, serta `check.names = FALSE` seperti GUI, dan mereproduksi data GUI persis (nama kolom ikut sama); pilihan yang diubah sesudah langkah 1 tidak mengubah skrip.
- AC-FR-008.5  Kedua isian punya teks Indonesia dan Inggris.

## Increment rcli 0.4.0 (keputusan pengguna 1 November 2026: "Iya. Buatkan menerima beberapa berkas.")

### FR-009 — Beberapa berkas, satu per indikator
Fungsi baru `read_cli_series()` dan sumber data baru di GUI langkah 1, "Unggah beberapa berkas (satu per indikator)", sehingga seri dengan frekuensi berbeda dapat diunggah dalam berkas masing-masing lalu diselaraskan dengan `cli_align()`.
- AC-FR-009.1  `read_cli_series(files)` membaca satu atau beberapa berkas CSV. Kolom pertama setiap berkas berisi tanggal, kolom lain berisi nilai. Setiap kolom nilai menjadi satu seri (data frame `date`, `value`) dalam daftar bernama. Kolom bernama `value` atau `nilai` dinamai menurut nama berkas tanpa ekstensi. Nama seri yang sama di dua berkas → `rcli_error_argument`.
- AC-FR-009.2  Format tanggal yang dikenali: `2001-01-15`, `15/01/2001` (hari/bulan/tahun), `2001-01`, `2001Q1`, `2001S1`, `2001`. Tanggal yang tidak dikenali → `rcli_error_dates` yang menyebut berkas dan nilai pertama yang salah.
- AC-FR-009.3  Pemisah kolom dan tanda desimal dikenali per berkas dengan aturan FR-008, atau mengikuti `sep` dan `dec` yang diberikan. Atribut `frequency` setiap seri berisi frekuensi asal yang dikenali `cli_align()` (harian sampai tahunan), dan atribut `file` berisi nama berkasnya.
- AC-FR-009.4  Hasil `read_cli_series()` dapat langsung dipakai `cli_align()`. Untuk berkas bulanan dan triwulanan, hasilnya sama dengan membaca berkas lebar setara dengan `read_cli_data()`.
- AC-FR-009.5  GUI: sumber `upload_multi` dengan isian `files` (banyak berkas) dan `target_freq` (bulanan, triwulanan). Langkah 1 menampilkan setiap seri dengan berkas, frekuensi asal, awal, akhir, dan jumlah observasi, serta grafik semua seri. Seri acuan dipilih dari semua seri.
- AC-FR-009.6  GUI langkah 2 (mode beberapa berkas): isian tipe seri acuan; frekuensi asal setiap kandidat terisi dari hasil pengenalan. "Bentuk himpunan kandidat" menjalankan `cli_align()` lalu `cli_candidates()`. Seri yang frekuensinya harus diubah tetapi tidak bertipe → pesan galat dan langkah 2 tidak selesai.
- AC-FR-009.7  Skrip R ekspor mereproduksi data GUI dengan `read_cli_series()` dan `cli_align()`, lalu komposit yang sama. Langkah 3–10 dan tombol indeks sejalan sebagai acuan tetap bekerja.

### FR-010 — Pilihan paket yang belum ada di GUI (increment rcli 0.5.0)
Hasil audit (2026-11-01): alur utama sudah tercakup di GUI, tetapi beberapa pilihan paket hanya dapat dipakai lewat kode. Increment ini menutup butir 1–7 audit; skrip ekspor tetap mereproduksi GUI persis.
- AC-FR-010.1  Efek Idulfitri: di langkah 3, bila penyesuaian musiman dipilih, kotak centang `idulfitri` menambahkan `holidays = holiday_effect(idulfitri_dates(), name = "idulfitri")` ke spesifikasi, untuk metode rcli maupun OECD. Tanpa penyesuaian musiman, efek tidak dipakai.
- AC-FR-010.2  Bentuk penyajian OECD: langkah 7 menampilkan grafik tiga bentuk `cli_presentation()` (disesuaikan amplitudonya, dipulihkan trennya, laju perubahan 12 bulan atau 4 triwulan), masing-masing bersama bentuk seri acuan yang sepadan; langkah 10 mengunduhnya sebagai CSV. `cli_presentation()` mendapat argumen `composite` agar komposit pilihan manual (`cli_composite()`) juga dapat disajikan; skrip ekspor memuat pemanggilannya.
- AC-FR-010.3  Penyelarasan (mode beberapa berkas, langkah 2): pilihan metode disagregasi seri acuan (`denton-cholette`, `chow-lin`, `linear`), seri indikator untuk Chow–Lin (seri berfrekuensi analisis), tanggal data mingguan (`week_date`: awal atau akhir minggu), dan cakupan minimum data harian/mingguan (`min_coverage`). Chow–Lin tanpa paket 'tempdisagg' atau tanpa indikator → pesan galat dan langkah 2 tidak selesai.
- AC-FR-010.4  Opsi lanjutan metode rcli (langkah 3): pengklasifikasi (`rcli_classifier()` atau `oecd_classifier()`), perlakuan pencilan (`robust_outliers()` atau `tramo_outliers()`), dan penggeseran lag (`lag_shift`) dapat dipilih masing-masing.
- AC-FR-010.5  Opsi lanjutan: parameter penyaring siklus terpilih (HP ganda: periode tren dan penghalusan; HP: λ; CF/BK: batas pita, K untuk BK; Hamilton: h dan p) dan aturan penanggalan titik balik (jendela, fase minimum, siklus minimum, eksklusi ujung) untuk Bry–Boschan (bulanan) atau BBQ (triwulanan).
- AC-FR-010.6  Opsi lanjutan: `coincident_band`, `lead_window`, `ccf_lag_max`, `target_lead`, `granger_max_lag`, `granger_dmax`, `horizon`, cakupan minimum agregasi (`min_coverage`), serta `h` dan `order_max` perpanjangan AR.
- AC-FR-010.7  Isian opsi lanjutan yang kosong berarti nilai bawaan paket (yang dapat bergantung pada frekuensi); hanya isian yang diisi muncul di skrip ekspor. Nilai tak sah (misalnya batas pita terbalik) → pesan galat paket dan langkah 3 tidak selesai.
- AC-FR-010.8  Spesifikasi (langkah 3) dan penyelarasan (langkah 2) dibentuk dari teks kode yang sama dengan skrip ekspor, sehingga GUI dan skrip tidak dapat berbeda; uji membandingkan objek yang dihasilkan keduanya untuk setiap pilihan.

### FR-011 — Perbaikan cacat hasil kajian menyeluruh (increment rcli 0.5.1)
Sumber: kajian menyeluruh 1 November 2026 (Project: `claude/kajian-menyeluruh-rcli-0.5.0.md`). Bawaan metode tidak berubah; perubahan pengklasifikasi (G1–G5) ditunda ke 0.6.0 karena memerlukan kalibrasi ulang.
- AC-FR-011.1 (F1)  Nama pencilan JDemetra+ dengan periode angka Romawi (triwulanan, misalnya `AO (IV-2009)`) maupun angka (bulanan, `AO (5-2011)`) diurai; efeknya dihapus. Nama yang tidak dapat diurai atau periodenya di luar 1..frekuensi → `rcli_error_outliers`, bukan dilewati atau digeser ke tahun lain.
- AC-FR-011.2 (F2)  Bila LS atau TC dihapus, prakiraan regARIMA dikurangi kelanjutan efeknya: LS tetap, TC meluruh dengan laju mesinnya (TRAMO 0,7; X-13 0,7^(12/f), yaitu 0,343 untuk data triwulanan), sehingga ujung seri bersih tidak meloncat.
- AC-FR-011.3 (F3)  `robust_outliers()` juga menandai perubahan ekstrem pada observasi pertama (uji satu sisi dengan ambang yang sama) dan menggantinya dengan observasi kedua dikurangi median perubahan. Observasi terakhir tidak disentuh (sinyal terbaru; perubahan ekstrem di ujung akhir belum dapat dibedakan dari pergeseran level atau titik balik; review 0.5.1 R3). Perilaku di tengah seri tidak berubah.
- AC-FR-011.4 (G6)  `conference_board()` menghitung perubahan simetris dari level seri yang sudah disesuaikan musim, dibersihkan pencilannya, dan ditransformasi (`@transformed`, dikembalikan ke level bila ber-log), bukan dari seri asli.
- AC-FR-011.5 (G9)  `cli_presentation()`: kolom seri acuan (`reference`, `reference_amplitude_adjusted`, `reference_rate_of_change`) memakai level seri acuan yang sudah disesuaikan musim dan dibersihkan pencilannya.
- AC-FR-011.6 (G7/E1)  `cli_selection_bias()` membentuk komposit sesudah titik potong dengan geser lag komposit latih; dengan `lag_shift = TRUE`, `lead_gap` membandingkan komposit yang sama.
- AC-FR-011.7 (E2)  `window()` pada himpunan kandidat di luar rentang data → `rcli_error_short_series`; `cli_build()` dengan titik potong sebelum awal data selesai, dan baris titik potong itu berisi catatan, bukan galat.
- AC-FR-011.8 (E3)  `cli_candidates()` membuang kandidat yang seluruhnya kosong (juga dari vintage data) dengan peringatan `rcli_warning_dropped`; seri acuan yang seluruhnya kosong atau konstan → `rcli_error_argument`.
- AC-FR-011.9 (E4)  Pelanggaran validitas `cli_spec()` dan `update()` → `rcli_error_argument`; slot skalar selain `horizon` tidak boleh NA; `max_iter`, `min_components`, `ccf_lag_max`, `granger_max_lag`, `granger_dmax`, dan `horizon` harus bilangan bulat; `cli_validate()` dan `cli_composite()` memeriksa `spec` dan `reference` dengan galat bertipe.
- AC-FR-011.10 (E8)  Korelasi silang memerlukan tumpang tindih dua tahun (24 bulan atau 8 triwulan). Kandidat yang korelasi silang atau uji Grangernya tidak dapat dihitung karena seri terlalu pendek disebut dalam peringatan `rcli_warning_short_series`.
- AC-FR-011.11 (E9)  Bila PCA atau DFM kembali ke bobot sama karena baris lengkap terlalu sedikit, muncul peringatan `rcli_warning_fallback`, dan `CompositeIndex@aggregator` mencatat agregator yang benar-benar dipakai.
- AC-FR-011.12 (F9, G11)  Dokumentasi `?oecd_spec` (interpolasi kandidat triwulanan) dan `?cli_spec` (`horizon` NA memakai lag korelasi silang) sesuai kode.

### FR-012 — Evaluasi kandidat dan validasi yang lebih jujur (increment rcli 0.6.0)
Sumber: kajian menyeluruh 1 November 2026, temuan G1, G2, G3, G5 (Project: `claude/kajian-menyeluruh-rcli-0.5.0.md`); bukti simulasi ulang 2 November 2026 (`data-raw/evaluation_060.R`). Perubahan ini mengubah hasil bawaan, sehingga kalibrasi diulang.
- AC-FR-012.1 (G1, arah dari `meta`)  `meta` menerima kolom `sign`: 1 (prosiklis), −1 (kontrasiklis), atau NA (ditentukan dari data). Arah yang dinyatakan dipakai apa adanya tanpa inversi otomatis; nilai lain → `rcli_error_argument`. Tabel penilaian memuat kolom `sign_source` ("meta", "data", atau "none" bila arah tidak terbaca).
- AC-FR-012.2 (G1, aturan data, F-05 revisi 2)  Bila `sign` NA, arah seri adalah tanda korelasi silang terbesar (nilai mutlak) pada lag |k| ≤ K, dengan K = min(`ccf_lag_max`, max(1, ⌊P̂/4⌋)) dan P̂ rata-rata jarak antartitik balik sejenis seri acuan (K = `ccf_lag_max` bila tidak ada dua puncak maupun dua lembah). `ccf_lag` dan `ccf_r` adalah puncak korelasi sesudah orientasi pada |k| ≤ min(`ccf_lag_max`, max(1, ⌊P̂/2⌋)). Bila arah tidak terbaca, seri tidak dibalik dan `sign_source` = "none". Pada siklus teratur 48 bulan, pendahulu 6 bulan tidak pernah dibalik; pada simulasi kalibrasi, arah semua seri bersinyal sama dengan 0.5.1 (arah seri derau murni acak dan dapat berbeda). Arah yang dinyatakan pada siklus yang sudah dibalik tidak membaliknya lagi.
- AC-FR-012.3 (G3, F-06)  Nilai p konkordansi berasal dari uji HAC Bartlett *fixed-b* satu sisi (b = 0,3; Kiefer dan Vogelsang 2005) atas regresi status seri acuan pada status kandidat, dengan nilai p dari tabel distribusi nol *fixed-b* yang disimulasikan (`data-raw/fixed_b_table.R`). Pada status fase Markov independen (n = 360, peluang berganti 1/12 dan 1/24), penolakan pada α = 5% paling besar 8%; ukuran pada siklus tersimulasi dan pada n kecil dilaporkan di `inst/calibration/test-size.csv`.
- AC-FR-012.4 (G2, kesesuaian siklus OECD)  `oecd_classifier(conformity = TRUE)` (bawaan) mensyaratkan, selain median *lead*: puncak korelasi silang positif, pangsa titik balik terlewat dan ekstra paling besar `max_missed` dan `max_extra`, serta konkordansi signifikan di atas nilai harapan. `conformity = FALSE` memberi aturan 0.5.1; spesifikasi yang disimpan sebelum 0.6.0 berperilaku seperti `conformity = FALSE`.
- AC-FR-012.5 (G2, jendela)  Bawaan `lead_window` dipilih dari kalibrasi AC-FR-012.8 di antara (12, 24) dan (12, 12) bulanan (padanan triwulanannya (4, 8) dan (4, 4)); pilihan dan buktinya tercatat di `inst/calibration/lead-window.csv`.
- AC-FR-012.6 (G5, F-07)  Peluang kontraksi di `cli_validate()` berasal dari logit rekursif luar sampel: prakiraan pertama sesudah 40% observasi yang dapat dipakai, model untuk waktu t ditaksir dari observasi s ≤ t − h. QPS dibandingkan dengan prakiraan naif rekursif (pangsa kontraksi s ≤ t − h); AUC dihitung dari prakiraan itu; kolom `n_forecasts` mencatat jumlahnya. `contraction_probability(recursive = TRUE)` memberi peluang yang sama.
- AC-FR-012.7 (G5)  Uji arah Pesaran–Timmermann memakai bentuk regresi (Pesaran dan Timmermann 2009) dengan HAC *fixed-b* F-06. `horizon = NA` berarti batas bawah `target_lead` (6 bulan atau 2 triwulan), bukan lag korelasi silang. Pada seri halus independen dengan h tetap, penolakan pada α = 5% paling besar 8%; pada komposit tersimulasi dari seri independen dilaporkan di `inst/calibration/test-size.csv`.
- AC-FR-012.8 (kalibrasi)  Harness kalibrasi dijalankan ulang (`calibrate_collect.R`, `calibrate_summarise.R`, `calibrate_coincident.R`, `compare_oecd.R`, `realtime_defaults.R`); `inst/calibration/*.csv`, vinyet, `?cli_spec`, `?cli_assess`, dan `?concordance` diperbarui. Ukuran dan daya uji tercatat di `inst/calibration/test-size.csv`. Label pendahulu palsu `rcli_classifier()` tetap ≤ 1,5% pada simulasi kalibrasi (0.5.1: ≤ 1,3%). Untuk `oecd_classifier()`, syarat kesesuaian paling sedikit memangkas separuh label pendahulu palsu, baik pada seri non-pendahulu kalibrasi maupun pada siklus independen, dibandingkan aturan 0.5.1 (`oecd-classification.csv`, `lead-window.csv`). Deteksi pendahulu sejati turun paling banyak 1 poin persen pada bising 0,2 dan paling banyak 12 poin persen pada bising lebih tinggi. (Revisi sesudah review 0.6.0 R3: batas semula 2 poin persen untuk semua bising tidak tercapai, karena syarat konkordansi dan siklus terlewat juga menyaring sebagian pendahulu sejati yang berderau. Turunnya deteksi itu dicatat di NEWS dan vinyet sebagai harga pengurangan label palsu.) (Studi pendahuluan, 60 ulangan, bising 0,2: siklus independen 43% → 18% triwulanan dan 48% → 10% bulanan; batas 10% yang semula diusulkan tidak tercapai untuk triwulanan karena aturan OECD tidak memuat uji kausalitas, dan hal ini dicatat di `?oecd_classifier`.)
- AC-FR-012.9 (GUI)  Langkah 2 menyediakan isian arah (otomatis, prosiklis, kontrasiklis) untuk setiap kandidat dalam dua bahasa; skrip ekspor menulis kolom `sign`; tabel langkah 6 menandai arah dari `meta`. `oecd_classifier(conformity = )` tersedia di opsi lanjutan.

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
| F-03 | Penyaring HP dengan LDLᵀ pita O(n) | Hodrick & Prescott (1997); Golub & Van Loan (2013, §4.1–4.3); Higham (2002, bab 10) | FR-004 |
| F-04 | Denton–Cholette aditif selisih pertama dengan rasio agregasi k umum, dan interpolasi linear per k | Denton (1971); Dagum & Cholette (2006, bab 6); IMF (2017, bab 6) | FR-007 |
| F-02 | Perpanjangan AR pada perubahan (Yule-Walker, orde AIC) dan prakiraan kumulatif | Brockwell & Davis (1991), *Time Series: Theory and Methods* (rujukan `?stats::ar`); Akaike (1974) untuk AIC | FR-002 |
| F-05 | Identifikasi arah seri dari korelasi silang pada lag |k| ≤ max(min_lead, ⌊P̂/4⌋) | baru; prinsip arah dari kesesuaian siklus Gyomai & Guidetti (2012, p. 8–9) | FR-012 |
| F-06 | Uji HAC Bartlett *fixed-b* (b = 0,3) untuk konkordansi dan arah, dengan tabel distribusi nol tersimulasi | Kiefer & Vogelsang (2005); Harding & Pagan (2006); Pesaran & Timmermann (2009) | FR-012 |
| F-07 | Logit rekursif luar sampel untuk peluang kontraksi, QPS, dan AUC | Estrella & Mishkin (1998); Diebold & Rudebusch (1989); Berge & Jordà (2011) | FR-012 |

## Di luar cakupan
- Perpanjangan bermusim (SARIMA) dan prakiraan dari model multivariat.
- Mengubah `oecd_aggregate()`, klasifikasi, atau ambang.
- Evaluasi pada data BPS/BI (direkomendasikan kajian, dikerjakan terpisah).
- 0.6.0: G4 (ukuran uji Toda–Yamamoto pada siklus tersaring) hanya didokumentasikan; evaluasi waktu nyata dengan *vintage*, aturan sinyal titik balik, jam siklus bisnis, indeks difusi, dan refaktor ditunda.
- 0.6.0: inflasi ukuran uji konkordansi karena geser dipilih dari data (median *lead*) tidak dikoreksi; dicatat di dokumentasi.

## Pertanyaan terbuka
- (tidak ada; keputusan pengguna: "Lanjutkan ke versi 0.2.0 sesuai kajian")
