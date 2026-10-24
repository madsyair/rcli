# 06 — Review

- Increment: rcli 0.2.2 (FR-006, FR-007)
- Reviewer: A6 (konteks bersih: ya)
- Putaran: 1
- Keadaan yang direview: cabang `rcli-0.2.2`, HEAD 31c2d41, terhadap basis
  5be0d5a (0.2.1 di main). Komit yang dibaca:
  - c7f66e5: judul berversi dan indeks sejalan sebagai acuan (FR-006);
  - 11e6928: frekuensi asal, acuan semesteran/tahunan, kolom GUI (FR-007);
  - f913e3b: skrip verifikasi numerik F-04, keterlacakan FR-006;
  - 31c2d41: kolom `frequency` di `show()` untuk `CandidateSet` (masuk
    selama review atas pemberitahuan koordinator; ikut direview).

  Semua uji, mutasi, dan `R CMD check` dijalankan pada salinan
  `git archive` di direktori sementara. Uji peramban memakai pustaka
  sementara (`R CMD INSTALL -l <tmp>`, `R_LIBS`); pustaka sistem tidak
  disentuh. Kode paket dan uji di repositori tidak diubah.

## Yang diperiksa

### FR-007 / F-04 (R/align.R, R/candidates.R)
- Baris demi baris terhadap F-04 §1, §3 dan §7:
  - `constraint_matrix(m, tp, k)`: w = (1, …, 1), (1/k, …, 1/k) dan
    (0, …, 0, 1); C = I_m ⊗ wᵀ lewat `kronecker(diag(m), t(w))`. Sesuai §1.
  - `denton_cholette(q, tp, to)`: k = to/f, D = `diff(diag(n))`, sistem KKT
    [2DᵀD Cᵀ; C 0][x; λ] = [0; y] diselesaikan dengan `solve()` (LU), tanpa
    inversi eksplisit. Sesuai §3 langkah 1 dan §6. Untuk k = 3, C, D dan
    `target_frame(q, 12)` sama dengan `monthly_frame()` 0.2.1 (§3 langkah 3).
  - `target_frame(q, to)`: awal = subperiode pertama dari periode rendah
    pertama, `k·(st[2] − 1) + 1`. Sesuai §1 ("dimulai pada subperiode
    pertama").
  - `interpolate_reference()`: v = y/k untuk aliran; posisi (k + 1)/2 atau k;
    `approx(rule = 2)` (konstan di luar ujung); NA di luar rentang periode
    rendah; minimal dua nilai. Sesuai §1 dan §3 langkah 4.
  - `chow_lin(..., to)`: indikator harus berfrekuensi `to`; jendela mulai
    pada subperiode pertama periode rendah pertama.
  - `convert_one()`: kandidat semesteran/tahunan → `abort_low_frequency()`
    (`rcli_error_frequency`); acuan memilih jalur menurut `method`. Sesuai
    §7.
- Verifikasi independen (skrip saya sendiri, bukan skrip harness):
  - Terhadap `tempdisagg::td(method = "denton-cholette")`, 30 kombinasi
    f ∈ {1, 2, 4}, to ∈ {4, 12}, tiga tipe, awal pada periode pertama dan
    terakhir tahun (termasuk `ts` semesteran mulai `c(2003, 2)`): selisih
    maksimum 7,8·10⁻¹²; `start()` sama dengan `td()` di semua kasus.
  - Terhadap penyelesaian kuadrat terkecil berkendala lewat ruang nol
    (`MASS::Null`, `qr.solve`), implementasi ketiga yang tidak memakai KKT:
    selisih maksimum 6,3·10⁻¹³.
  - k = 3 terhadap `denton_cholette()` 0.2.1 yang dimuat dari
    `git show 5be0d5a:R/align.R` (12 kasus, NA di kedua ujung, awal triwulan
    1–4): selisih tepat 0.
- Kasus tepi lewat `cli_align()`:
  - Data frame semesteran bertanggal akhir periode (30 Juni/31 Desember),
    mulai pada semester kedua, NA di kedua ujung, target bulanan dan
    triwulanan, ketiga tipe: awal jatuh pada subperiode pertama semester,
    galat kendala ≤ 2,4·10⁻¹³.
  - `ts` tahunan dengan NA di kedua ujung ke triwulanan: kendala
    1,4·10⁻¹⁴. Chow–Lin tahunan ke bulanan dan ke triwulanan: kendala
    ≤ 5,7·10⁻¹³; indikator berfrekuensi salah ditolak dengan pesan yang
    menyebut frekuensi target.
  - `period_key()`/`key_start()` untuk f = 1 dan 2 benar (Januari/Juni →
    semester 1, Juli/Desember → semester 2). Tanggal tahunan 31 Desember
    dan 1 Juli, serta semesteran 1 Januari/1 Juli, terdeteksi benar.
  - Mingguan dan harian tetap berjalan (termasuk `frequency = c(wk =
    "weekly", dy = "daily")`); `position` untuk kandidat triwulanan tetap
    berlaku.
  - Frekuensi yang dinyatakan: salah → `rcli_error_frequency` yang menyebut
    keduanya; nama/nilai tak dikenal, vektor tanpa nama, `list`, `NA` →
    `rcli_error_argument`.
  - Acuan tahunan satu nilai: Denton memberi seri datar (m = 1, KKT tetap
    tak singular); `"linear"` → `rcli_error_short_series`. NA di tengah →
    `rcli_error_argument`.
- `cli_candidates()`: kolom `frequency` diisi dari `alignment$from` lalu
  ditimpa `meta`; nilai tak dikenal → `rcli_error_argument`; semesteran/
  tahunan → `rcli_error_frequency`. Acuan tidak masuk metadata, jadi acuan
  tahunan tidak ditolak. `cci_as_reference()` membawa kolom ini.
- 31c2d41: `show()` menampilkan kolom `frequency` bila ada nilai; objek lama
  tanpa kolom itu tetap aman (`col %in% names(m)`).

### FR-006 (R/app.R, R/app-text.R)
- Judul `sprintf("rcli %s: %s", packageVersion, t("title"))`, kunci
  `title`, `cci_ref*`, `var_freq`, `freq_*` ada di kedua bahasa. `shiny`
  hanya dipanggil sebagai `shiny::`; server hanya memanggil fungsi paket.
- Skenario keadaan yang saya jalankan dengan `shiny::testServer()` dan
  `eval()` skrip ekspor, membandingkan indeks skrip dengan indeks GUI
  (`composite(res)` atau `cli` untuk mode manual):

  | Skenario | Hasil |
  |---|---|
  | Tombol tanpa indeks sejalan | peringatan, `prelude` tetap NULL |
  | Auto → acuan `cci` → langkah 3–7 | skrip = GUI |
  | Sesudah peralihan, acuan diganti `lead_6`, langkah 2 diulang (`cand_rebuilt`) | skrip = GUI (`cli_candidates(cand@data, reference = "lead_6")`) |
  | Komposit manual di kedua analisis | skrip = GUI |
  | Peralihan dua kali (prelude bersarang, dua `cci_as_reference`) | skrip = GUI |
  | Metode OECD (mesin TRAMO dimatikan dengan mock, karena rJava di mesin ini rusak), manual, dua kali | skrip = GUI |
  | Langkah 2 gagal (kandidat semesteran) | langkah 2 dikosongkan |
  | Langkah 1 diulang | `prelude` dan `cand_rebuilt` dihapus |
  | Komposit manual di analisis 1, langkah 9 tanpa langkah 7 di analisis 2, peralihan kedua | **skrip galat** (R3) |
  | Data dimuat, langkah 2 selesai, acuan diganti | **metadata pindah menurut posisi** (R1; juga di Chrome) |

### Gerbang yang dijalankan sendiri (HEAD 31c2d41)
- `devtools::test()` lengkap: 0 gagal, 0 galat, 1 dilewati (seasonal),
  3 peringatan tak tertangani (R8), termasuk `test-app-e2e.R` di Chrome
  headless (uji baru "the coincident index becomes the reference in the
  browser" lulus).
- `lintr::lint_package()`: 0 temuan.
- `roxygen2::roxygenise()`: `man/` dan `NAMESPACE` sinkron.
- `R CMD build` + `R CMD check --as-cran --no-manual`: 0 galat,
  0 peringatan, 3 NOTE dari lingkungan (URL GitHub 403 lewat proksi,
  "unable to verify current time", `JAVA_TOOL_OPTIONS`). Vignette (termasuk
  chunk `align-annual`) dibangun ulang tanpa masalah.
- Mutasi (filter `frequency|align|app-reference`, baseline 167 lulus):

  | Mutan | Uraian | Status |
  |---|---|---|
  | M4 | aliran tidak dibagi k di `interpolate_reference()` | mati (3) |
  | M6 | kandidat tahunan diterima `cli_align()` | mati (1) |
  | M7 | frekuensi yang dinyatakan tidak diperiksa | mati (1) |
  | M8 | bobot stok pada subperiode pertama | mati (8) |
  | M9 | kandidat semesteran diterima di metadata | mati (3) |
  | M10 | `from` tidak disalin ke `frequency` | mati (1) |
  | M11 | langkah 1 tidak menghapus `prelude` | mati (1) |
  | M12 | `cand_rebuilt` tidak pernah TRUE | mati (2) |
  | M13 | langkah 2 gagal tanpa `reset_from(2)` | mati (2) |
  | M16 | isian `frq_i` tidak dibaca | mati (4) |
  | M1 | `target_frame()` memakai 3 alih-alih k untuk awal | **bertahan** (R4) |
  | M5 | jendela indikator Chow–Lin memakai 3 alih-alih k | **bertahan** (R4) |
  | M2 | stok ditempatkan di tengah periode (`"linear"`) | **bertahan** (R4) |
  | M3 | NA di luar rentang periode rendah tidak dipasang | **bertahan** (R4) |
  | M17 | batas akhir `last` digeser k | **bertahan** (R4) |
  | M18 | Denton tanpa pemotongan NA di ujung | **bertahan** (R4) |
  | M14 | `keep()` hanya menurut posisi (`known <- NULL`) | **bertahan** (R1) |
  | M15 | jendela semesteran 175–182 hari | bertahan (R13) |

## Temuan
- [x] [R1][major] R/app.R:643-647 (observer `input$reference`),
  R/app.R:681-695 (`keep()`), NEWS.md:16-17 dan
  tests/testthat/test-app-frequency.R:29-34 — NEWS menyatakan "The candidate
  metadata of step 2 is kept by candidate name when the list of candidates
  changes, instead of by position". Dalam alur biasa itu tidak terjadi.
  Penggantian acuan menjalankan `reset_from(2L)`, yang mengosongkan
  `rv$meta`, sehingga `known` bernilai NULL saat `meta_ui` digambar ulang
  dan `keep()` kembali memakai `input[[id]]` menurut posisi. Selain itu,
  nama yang tidak ada di `known` selalu mewarisi isian posisi yang sama.
  Bukti (testServer dan Chrome headless): data contoh, `typ_1 = "stock"`
  (lead_6), `typ_2 = "flow"`, `frq_2 = "quarterly"` (lead_3), langkah 2
  dijalankan, lalu acuan diganti `noise_2`. Baris `reference` mendapat
  stock milik lead_6, baris `lead_6` mendapat flow/quarterly milik lead_3,
  dan baris `lead_3` kosong. Tipe dan frekuensi asal yang salah lalu masuk
  metadata dan skrip ekspor tanpa peringatan. Uji "kept by name when the
  reference changes" tidak membedakan nama dari posisi, karena lead_3 tetap
  di posisi 2 sebelum dan sesudah penggantian acuan ke `lead_6`; mutan M14
  (`known <- NULL`) lulus semua uji. Hal yang sama berlaku untuk uji lead_3
  di test-app-reference.R. Saran: simpan metadata menurut nama di nilai
  reaktif tersendiri (mis. `rv$meta_by_name`) yang diperbarui di `run2` dan
  tidak dikosongkan oleh `reset_from(2)`, atau rekam semua isian `rat_`,
  `typ_`, `frq_`, `src_` per nama sebelum digambar ulang. Untuk nama yang
  tidak dikenal, pakai nilai bawaan, bukan isian posisi yang sama. Uji
  dengan acuan yang menggeser posisi (mis. `noise_2`), dan periksa baris
  `reference` serta `lead_6`.
  - Perbaikan (A5, putaran 2): `meta_ui` mencari isian menurut nama: pertama isian kandidat yang sama pada tampilan terakhir (`shown_cands`), lalu metadata himpunan kandidat terakhir (`rv$meta_known`, tidak dihapus oleh `reset_from(2)`), lalu bawaan. Uji "R1: step-2 entries follow the candidate names, not positions" (test-app-frequency.R) memakai pergantian acuan ke `lead_3` sehingga posisi dan nama berbeda; merah sebelum perbaikan.
- [x] [R2][major] R/quality.R:111-115 dan 227-234, `?cli_quality`,
  vignettes/rcli.Rmd:197-199 (catatan acuan triwulanan) — Baris informasi dan catatan "reference
  disaggregated … uncertain by about one month" hanya muncul bila metode
  diawali `"quarterly to monthly"`. Acuan tahunan atau semesteran yang
  didisagregasi ke bulan atau triwulan (`"annual to monthly
  (denton-cholette)"`, dst.) tidak mendapat catatan apa pun. Saya uji
  `cli_build()` dengan acuan tahunan dari `simulate_cycles(seed = 1)`:
  kartu skor tanpa baris disagregasi, sedangkan acuan triwulanan dari data
  yang sama mendapatkannya. Padahal ketidakpastian titik balik acuan
  tahunan jauh lebih besar (jalur bulanan di dalam tahun sepenuhnya hasil
  penghalusan), dan alasan paket sendiri untuk menolak kandidat tahunan
  ("one or two values a year cannot show a lead of a few months",
  `?series_frequencies`, NEWS) berlaku juga untuk acuan. Kartu skor menjadi
  menyesatkan tepat untuk fitur baru ini. Saran: umumkan
  `quality_reference()` untuk setiap baris `alignment` acuan dengan
  `from` lebih rendah dari target; tulis ketidakpastian sekitar k/2
  subperiode (± 1 bulan untuk triwulanan, ± 3 untuk semesteran, ± 6 untuk
  tahunan; atau teks per frekuensi); perbarui teks catatan, `?cli_quality`,
  vignette, dan `app_phrases_id`. Pertimbangkan juga `rcli_warn()` di
  `cli_align()` saat acuan semesteran/tahunan didisagregasi ke bulan. Uji
  untuk acuan tahunan dan semesteran.
  - Perbaikan (A5, putaran 2): `disaggregation()` di R/quality.R mengenali acuan triwulanan, semesteran, dan tahunan; baris informasi dan catatan menyebut ±1, ±3, atau ±6 bulan; terjemahan Indonesia ditambah; `?cli_quality` diperbarui. Uji "R2" (tahunan dan semesteran); merah sebelum perbaikan.
- [x] [R3][major] R/app.R:1093 (`state <- current_state()` di
  observer `cci_ref`) dan R/app.R:550-554 (`fields`) — `rv$mode` dan
  `rv$components` bukan bagian dari `fields`, sehingga tidak ikut
  dikosongkan oleh `reset_from()`. Langkah 9 hanya mensyaratkan langkah 6,
  sedangkan `script()` mensyaratkan langkah 7. Akibatnya prelude dapat
  dibuat dari mode komposit analisis sebelumnya. Reproduksi
  (testServer): analisis 1 dengan komposit manual `c("lead_6",
  "coincident")` dan indeks sejalan manual `c("coincident", "lag_3")`;
  beralih; analisis 2 menjalankan langkah 3–6 dan 9 tanpa langkah 7;
  beralih lagi; analisis 3 menjalankan langkah 3–7. Skrip ekspor menulis
  `cli_composite(cycles(res), c("lead_6", "coincident"), …)` untuk analisis
  2, padahal `coincident` sudah keluar dari kandidat, sehingga `eval()`
  gagal dengan "`components` must name at least one element of `cycles`".
  Ini melanggar AC-FR-006.4 dan aturan CLAUDE.md "the exported R script
  must reproduce the composite built in the app". Saran: masukkan `mode`
  dan `components` ke `fields$7` (dengan nilai bawaan "auto" dan
  `character(0)` saat dikosongkan), atau tulis baris komposit di
  `analysis_lines()` hanya bila langkah 7 selesai (mis. `state$step7 =
  7L %in% rv$done`). Tambahkan uji untuk langkah 9 tanpa langkah 7 sebelum
  peralihan.
  - Perbaikan (A5, putaran 2): `mode` dan `components` masuk kelompok langkah 7 di `fields`, sehingga ikut dihapus `reset_from()`. Uji "R3: a manual composite from before a reset does not leak"; merah sebelum perbaikan.
- [x] [R4][minor] tests/testthat/test-frequency.R — Enam mutan bertahan pada
  inti FR-007:
  - M1 (`target_frame()` dengan 3 alih-alih k) dan M5 (jendela Chow–Lin):
    tidak ada uji dengan seri rendah yang mulai di periode kedua (mis.
    `ts(…, start = c(2001, 2), frequency = 2)` atau data frame semesteran
    mulai Juli), satu-satunya kasus ketika k·(st[2] − 1) berbeda;
  - M2 (posisi stok `"linear"`), M3 dan M17 (NA di luar rentang): uji
    interpolasi linear hanya memakai aliran tahunan tanpa NA;
  - M18: tidak ada acuan semesteran/tahunan dengan NA di ujung untuk
    Denton.

  Perilaku saat ini benar (saya periksa manual di atas). Saran: tambahkan
  (a) `ts` semesteran mulai `c(y, 2)` terhadap `tempdisagg::td()` termasuk
  `start()`; (b) Chow–Lin semesteran mulai semester kedua; (c) interpolasi
  linear stok dengan nilai hitungan tangan; (d) acuan tahunan dengan NA di
  kedua ujung, untuk Denton dan `"linear"`, dengan posisi NA yang diperiksa.
  - Perbaikan (A5, putaran 2): uji baru: acuan yang mulai di periode kedua (Denton bulanan/triwulanan dan linear), NA di ujung (Denton dan linear) serta NA di tengah, stok linear, jendela Chow–Lin.
- [x] [R5][minor] R/candidates.R:97-114 dan R/app.R:741-744 (isian `frq_i`) — Kolom
  `frequency` dari `meta` menimpa catatan `cli_align()` tanpa pemeriksaan.
  `cli_candidates(x, meta = data.frame(name = "lead_6", frequency =
  "weekly"))` diterima untuk seri yang terdeteksi bulanan, dan isian GUI
  `frq_i` juga tidak dibandingkan dengan apa pun. Di `cli_align()`
  ketidakcocokan yang sama adalah galat (AC-FR-007.5). Saran: bila
  `alignment` punya `from` untuk nama itu dan berbeda dari `meta`, galat
  `rcli_error_frequency` dengan pesan yang sama seperti `cli_align()`; atau
  dokumentasikan bahwa `meta` menang.
  - Perbaikan (A5, putaran 2): `complete_meta()` membandingkan `frequency` di `meta` dengan `from` catatan `cli_align()`; beda → `rcli_error_frequency` yang menyebut keduanya. Uji "R5"; merah sebelum perbaikan.
- [x] [R6][minor] R/align.R:174-180 dan 403 — Kandidat semesteran atau
  tahunan tanpa `type` mendapat galat "give its type in `type`"
  (`rcli_error_argument`). Setelah tipe diberikan, barulah pengguna diberi
  tahu bahwa seri itu tidak boleh menjadi kandidat. Saran: periksa
  `s$from %in% c("semiannual", "annual") && !identical(nm, reference)`
  sebelum pemeriksaan tipe, lalu panggil `abort_low_frequency()`.
  - Perbaikan (A5, putaran 2): `cli_align()` menolak kandidat semesteran/tahunan sebelum memeriksa tipe. Uji "R6"; merah sebelum perbaikan.
- [x] [R7][minor] R/align.R:500-541 — `interpolate_quarterly(q, tp, pos)`
  adalah kasus khusus `interpolate_reference()` (k = 3, posisi dapat
  diatur), dengan rumus yang sama tetapi ditulis dua kali (DRY,
  software-principles §2). `monthly_frame()` tinggal pembungkus satu baris.
  Saran: satu fungsi `interpolate_low(q, tp, to, pos = NULL)` yang dipakai
  kedua jalur, dengan uji lama sebagai pengaman.
  - Perbaikan (A5, putaran 2): `interpolate_quarterly()` kini memanggil `interpolate_reference(q, tp, 12, pos)`; rumus tinggal satu. Uji lama interpolasi triwulanan tetap lolos.
- [x] [R8][nit] tests/testthat/test-frequency.R:160, 178 dan 184 — Tiga
  peringatan `rcli_warning_rationale` tidak ditangani dan muncul di laporan
  uji. Saran: beri `rationale` untuk semua kandidat atau bungkus dengan
  `expect_warning(…, class = "rcli_warning_rationale")`.
  - Perbaikan (A5, putaran 2): peringatan rasional di test-frequency.R diredam dengan `suppressWarnings(classes = "rcli_warning_rationale")`.
- [x] [R9][nit] tests/testthat/test-app-reference.R:72 — 81 karakter;
  CLAUDE.md meminta ≤ 80 (lintr tidak menandai baris yang berakhir dengan
  literal string).
  - Perbaikan (A5, putaran 2): baris dipecah.
- [x] [R10][nit] R/align.R:406-412 dan `?cli_align` (`@param position`) —
  `position` diam-diam diabaikan untuk acuan semesteran/tahunan dengan
  `method = "linear"`. Saran: sebutkan di `@param position` bahwa argumen
  ini hanya untuk seri triwulanan, atau tolak nama acuan rendah.
  - Perbaikan (A5, putaran 2): `period_position()` (1 sampai k) dipakai untuk acuan semesteran/tahunan dengan `method = "linear"`; di luar rentang → `rcli_error_argument`; `?cli_align` diperbarui. Uji "R4/R10"; merah sebelum perbaikan.
- [x] [R11][nit] tests/testthat/test-frequency.R:120 — Uji Chow–Lin memakai
  toleransi 1e-6, sedangkan AC-FR-007.2 menyebut 1e-8; galat sebenarnya
  5,7·10⁻¹³. Saran: `tolerance = 1e-8`.
  - Perbaikan (A5, putaran 2): toleransi uji Chow–Lin 1e-8, sesuai AC-FR-007.2 (lolos).
- [x] [R12][nit] R/candidates.R:31-40 — `cli_candidates()` kini punya dua
  "frequency" yang berbeda arti: argumen `frequency` (bilangan, atribut
  waktu data frame) dan kolom `meta$frequency` (frekuensi asal, teks).
  Saran: satu kalimat di `@param start,frequency` yang membedakannya dari
  kolom metadata.
  - Perbaikan (A5, putaran 2): dokumentasi `meta` di `?cli_candidates` membedakan kolom `frequency` (frekuensi asal) dari argumen `frequency` (periode per tahun). Nama argumen tidak diubah agar kompatibel.
- [x] [R13][nit] R/align.R:338 — Mutan M15 (jendela semesteran 175–182)
  bertahan, karena uji hanya memakai tanggal 1 Januari/1 Juli. Saran: uji
  tanggal akhir periode (30 Juni/31 Desember) dan tahun kabisat untuk
  semesteran dan tahunan.
  - Perbaikan (A5, putaran 2): uji "R13" untuk jendela tanggal: 175 dan 190 hari → semesteran, 360 dan 370 → tahunan, 150/200/300/380 → galat.
- [x] [R14][nit] vignettes/rcli.Rmd:204-205 dan NEWS.md — Kalimat "with
  every year (or half-year) kept exactly" hanya benar untuk Denton–Cholette
  dan Chow–Lin, tidak untuk `"linear"`. Penambahan objek ekspor dan argumen
  baru lazimnya menaikkan versi minor menurut semantic versioning;
  keputusan 0.2.2 ada pada pemelihara (STATE), tetapi sebaiknya dicatat di
  08-release.

  - Perbaikan (A5, putaran 2): vinyet menyebut bahwa kendala dipenuhi persis untuk Denton–Cholette dan Chow–Lin, serta catatan ketidakpastian di kartu skor. Versi tetap 0.2.2 sesuai keputusan pemelihara ("dikerjakan sebagai versi 0.2.2"); saran 0.3.0 dicatat untuk dilaporkan ke pemelihara.

## Catatan di luar cakupan (sudah ada sebelum increment ini)
- R/app.R `current_state()` membaca `input$seed`, `input$source` dan
  `input$start` saat skrip dibuat, bukan saat langkah 1 dijalankan. Bila
  pengguna mengubah benih di langkah 1 tanpa menekan tombol lagi, skrip
  memakai benih baru. Dengan prelude, nilai itu kini juga dibekukan pada
  saat peralihan. Saran: simpan nilai langkah 1 di `rv` saat `run1`.
- Eskalasi lama (`lag_shift` di uji bias seleksi) masih terbuka di
  STATE.md.

Tindak lanjut A5: skrip ekspor kini memakai sumber data dan benih saat langkah 1 dijalankan (`rv$loaded`); uji "the script uses the data as loaded in step 1".

## Putusan
Putaran 1 — Inti numerik FR-007 benar dan sesuai F-04 baris demi baris.
Hasilnya diverifikasi independen terhadap `tempdisagg`, terhadap solusi
ruang nol, dan terhadap implementasi 0.2.1 (selisih 0 untuk k = 3).
Deteksi frekuensi, `period_key()`/`key_start()`, data bertanggal mulai
semester kedua, NA di ujung, Chow–Lin, mingguan/harian, dan `position`
semuanya berjalan benar. Rangkaian prelude FR-006 mereproduksi indeks
dalam enam skenario, termasuk peralihan dua kali dan metode OECD. Uji
lengkap (dengan e2e Chrome), lint, roxygen, dan `R CMD check --as-cran`
bersih.

Ada tiga major:
- R1: klaim "metadata menurut nama" tidak berlaku saat acuan diganti, dan
  ujinya tidak membedakan nama dari posisi;
- R2: kartu skor diam untuk acuan tahunan/semesteran yang didisagregasi;
- R3: skrip ekspor gagal bila langkah 9 dijalankan tanpa langkah 7
  sesudah komposit manual sebelumnya.

Ada empat minor (R4 celah uji inti FR-007, R5–R7) dan tujuh nit. R1–R3 dan
R4 sebaiknya ditutup sebelum rilis 0.2.2.

Putusan: CHANGES-REQUESTED
