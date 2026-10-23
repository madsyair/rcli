# 06 — Review

- Increment: rcli 0.2.1 (FR-004 penyelesai HP O(n), F-03; FR-005 penggabungan
  PR #1 indeks koinsiden; NFR-002 revisi)
- Reviewer: A6 (konteks bersih: ya)
- Putaran: 2 (putaran 1 terhadap 59c330e; putaran 2 terhadap 4d060d8)
- Keadaan yang direview: cabang `rcli-0.2.1`, HEAD 59c330e, terhadap basis
  99d1a2c (0.2.0 di main). Komit yang dibaca: 44b5654 (merge PR #1),
  c8ed1dd (HP pita, kalibrasi koinsiden), 59c330e (Rplots.pdf), serta
  66b98da dan 7894ebc dari PR. Semua uji, mutasi, dan `R CMD check`
  dijalankan pada salinan di direktori sementara (`git archive HEAD`).
  Selama review, pohon kerja diubah agen lain (belum dikomit: NEWS.md,
  R/methods-show.R, tests/testthat/test-selection-bias.R; kolom `note` di
  `show()`). Perubahan itu tidak termasuk dalam review ini. Perubahan
  tersebut kemudian dikomit sebagai 161fa87 dan e948273 (yang terakhir
  melonggarkan batas waktu AC-FR-004.6 di bawah covr). Kedua komit itu
  belum direview pada putaran ini.

## Yang diperiksa

### FR-004 / F-03 (R/filters.R:23-69)
- Baris demi baris terhadap F-03 §1, §3, dan §7:
  - pita a0 = 1 + λ(1, 5, 6, …, 6, 5, 1), a1 = λ(−2, −4, …, −4, −2),
    a2 = λ(1, …, 1); untuk n = 4 dan 5 hasil `rep(·, 0)` dan
    `rep(·, 1)` memberi (1, 5, 5, 1) dan (1, 5, 6, 5, 1), sesuai D₂ᵀD₂.
  - d_i, l1_{i+1} dan l2_{i+2} sama dengan rekursi §3.3. l2_{i+1} sudah
    tersedia saat dipakai, karena dihitung pada iterasi i − 1.
  - Substitusi maju Lw = x, z = w/d, lalu substitusi mundur Lᵀτ = z dengan
    l1_{i+1} dan l2_{i+2}. Benar.
  - Tanpa matriks n × n, tanpa dependensi baru, tanpa inversi eksplisit.
- Verifikasi independen (skrip saya sendiri, bukan skrip harness):
  - Terhadap `solve()` padat, n ∈ {4, 5, 6, 7, 8, 13, 100, 372, 612, 1000}
    dan λ ∈ {0; 10⁻³; 1; 13,9; 1600; 129 600; 133 107,9; 10⁶; 10⁸}:
    selisih relatif maksimum 4,7·10⁻¹¹ untuk λ ≤ 133 107,9 dan
    ≤ 1,6·10⁻⁸ untuk λ = 10⁸.
  - Terhadap solusi eksak rasional (`gmp::solve.bigq`, n = 30), galat maju
    relatif:
    - λ = 133 107,9: pita 1,8·10⁻¹¹, padat 4,4·10⁻¹²;
    - λ = 10⁸: pita 1,3·10⁻⁸, padat 5,1·10⁻⁹.

    Galat pita sekitar 3–4 kali galat padat, tetapi masih jauh di bawah
    batas κ(A)·u pada F-03 §3.6. Klaim NEWS "agree with 0.2.0 to about
    1e-10 relative" benar.
  - Terhadap `mFilter::hpfilter` (n = 360, λ = 129 600): selisih absolut
    tren maksimum 5,8·10⁻¹⁰.
  - λ = 0 memberi x persis (`identical`). n = 4 dan 5 dengan data bulat
    berselisih ≤ 5,3·10⁻¹⁵ dari solusi padat.
  - NA di x menghasilkan NA, sama seperti 0.2.0. λ = Inf menghasilkan NaN,
    juga sama seperti 0.2.0 (lihat R7).
- Mutasi pada salinan (filter `hp-solver|filters`, baseline 62 lulus):
  15 dari 15 mutan mati, masing-masing dengan 20–21 kegagalan:
  - pita: koefisien 5→4 dan −4→−3, a2 dikali 2;
  - indeks: `d[i−2]`→`d[i−1]` di d_i; `l2[i+1]`→`l2[i]` di l1;
    `w[i−2]`→`w[i−1]`; `l2[i+2]`→`l2[i+1]` di substitusi mundur;
  - tanda: substitusi mundur `−`→`+`;
  - substitusi: z = w tanpa dibagi d; suku l2 di d_i dihapus;
  - batas loop: `i < n − 1`→`i < n − 2` (dua tempat), `i > 2`→`i > 3`,
    `i < n`→`i < n − 1`;
  - arah: substitusi mundur dijalankan maju.

  Uji FR-004 cukup tajam.
- Waktu (median 15 ulangan, `simulate_cycles(seed = 1)`, 8 seri termasuk
  acuan, mesin tanpa beban lain):

  | Versi | Tanpa perpanjangan | Dengan AR | `hp_trend_core`, n = 360 |
  |---|---|---|---|
  | 0.2.0 (99d1a2c) | 63 ms per seri | 70 ms per seri | 36 ms |
  | 0.2.1 | 2,0 ms per seri | 2,6 ms per seri | 0,35 ms |

  Klaim NEWS (±3 ms vs ±80 ms per seri) cocok bila dibagi 7 kandidat (lihat
  R12). Klaim `?Extension-class` (±1 ms per seri) cocok: selisih AR vs tanpa
  AR 0,6 ms. AC-NFR-002.2 terpenuhi dengan selisih besar, jadi penyimpangan
  AC-NFR-002.1 dari 0.2.0 tertutup.

### FR-005 (merge PR #1)
- Resolusi konflik:
  - DESCRIPTION memakai judul dari cabang PR dan versi 0.2.1; Imports tidak
    berubah.
  - NEWS menjadikan entri 0.1.4 sebagai 0.2.1 di atas 0.2.0, dengan
    catatan 0.1.4 tidak dirilis.
  - Tidak ada sisa penanda konflik.
- Interaksi semantik dengan bawaan 0.2.0:
  - `cci_build()` memakai `cli_composite(cycles, cs, spec, ref)`, jadi
    agregator spesifikasi (EqualWeight "chain") dipakai tanpa pergeseran
    lag. Saya uji ujung compang-camping, 3 komponen dengan `coin_b` hilang
    3 bulan terakhir: "chain" dan "level" berbeda di tiga nilai terakhir
    (98,70 vs 99,14), jadi rantai benar-benar berlaku pada indeks koinsiden.
  - Perpanjangan: siklus dari `CliResult` dipakai ulang; tanpa `CliResult`,
    `cli_cycles(candidates, spec)` memakai `spec_extension()`. Konsisten.
  - `oecd_spec()` (`lag_shift = TRUE`): indeks koinsiden tidak digeser
    (`@shifts` kosong), sesuai dokumentasi.
  - Objek lama yang disimulasikan (tanpa atribut `role` di `CliValidation`,
    tanpa `extension` dan `lag_shift` di `CliSpec`, tanpa `ragged_edge` di
    `EqualWeight`, dengan `oos_cutoffs = 2015`):
    - `cli_quality()`, `show()` dan `cci_build(old)` berjalan, dan
      `cci_build(old)` memberi indeks identik dengan objek baru;
    - `cci_build(old, spec = old@spec)` juga berjalan.
- GUI:
  - langkah 9 membangun `CliResult` dari `rv$cycles_used` (siklus terbalik
    langkah 6) dan spesifikasi langkah 3;
  - skrip ekspor menulis `cci_build(res)` atau
    `cci_build(res, components = …, select = FALSE)` setelah
    `spec_call()`/`make_extension_call()`, jadi spesifikasi dan
    perpanjangannya sama;
  - `cci` disimpan sebagai field langkah 7, dan `finish(7)` hanya mengosongkan
    langkah ≥ 8, jadi membangun ulang komposit tetap mempertahankan indeks
    (sesuai komentar dan uji).

  `test-app.R` membandingkan `@index` dari skrip dan GUI (mode otomatis).
  `test-app-e2e.R` membandingkan skrip dengan CSV unduhan.

### Refaktor `timing_band()`/`timing_rules()`
- Generic internal dengan metode untuk `Classifier` dan `OecdClassifier`,
  sehingga tidak ada lagi cabang `is(classifier, …)` di R/coincident.R.
  Perilakunya sama dengan versi PR (band 2/3 untuk OECD triwulanan,
  1 untuk rcli triwulanan, teks aturan).

### Gerbang yang dijalankan sendiri
- `devtools::test()` lengkap pada salinan: 0 gagal, 0 galat, 1 dilewati
  (seasonal), termasuk `test-app-e2e.R` di Chrome headless.
- `lintr::lint_package()`: 0 temuan.
- `roxygen2::roxygenise()` pada salinan HEAD: `man/` dan `NAMESPACE` sinkron.
- `R CMD build` + `R CMD check --as-cran --no-manual`: 0 galat, 0 peringatan,
  2 NOTE. Keduanya berasal dari lingkungan: "unable to verify current time"
  dan pesan `JAVA_TOOL_OPTIONS` yang dibaca sebagai NOTE dependensi. Contoh
  `cci_build` 0,25 detik.
- Mutasi R/coincident.R, R/quality.R, R/selection-bias.R, R/classes-core.R,
  dan R/app.R (filter `coincident|selection-bias|quality|^app$`): 6 dari 10
  mutan mati.
  - Mati:
    - `pct_timely_out` dengan `<`;
    - lantai satu periode dihapus;
    - pita OECD inklusif;
    - pergeseran lag di `cci_build()`;
    - teks aturan OECD;
    - skrip ekspor `select = FALSE`.
  - **Bertahan**: (C1) cabang `.hasSlot` di `validation_role()` dihapus,
    (C5) ambang waktu luar sampel diganti 2 × band, (C6) kriteria pangsa
    tepat waktu diganti `TRUE`, (C8) suku median lead dihapus dari
    `coincident_score()`. Lihat R1, R2 dan R6.

## Temuan
- [x] [R1][minor] tests/testthat/test-coincident.R:196-201 — Uji
  "validations saved before 0.1.4 count as leading" memakai
  `new("CliValidation")`, yang mendapat slot `role = "leading"` dari
  prototipe. Uji itu tidak membuat objek tanpa slot `role`, sehingga cabang
  `methods::.hasSlot()` di R/classes-core.R:156-158 tidak pernah
  dijalankan. Mutan C1 (cabang `.hasSlot` dihapus) lulus semua uji. Polanya
  sama dengan R1 di review 0.2.0. Kodenya sendiri benar: saya uji objek
  dengan `attr(v, "role") <- NULL` dan `cli_quality()`/`show()` berjalan.
  Saran: `attr(v, "role") <- NULL`, lalu
  `expect_false(methods::.hasSlot(v, "role"))`,
  `expect_equal(validation_role(v), "leading")`, dan uji juga
  `cli_quality(v, spec)` serta `show(v)`. Klaim NEWS "Objects saved by
  earlier versions count as leading" bergantung pada jalur ini.
  - Perbaikan (A5, putaran 2): test-coincident.R "R1: a validation object without the role slot counts as leading" (atribut `role` dihapus, `.hasSlot()` FALSE).
- [x] [R2][minor] R/coincident.R:144-161 dan
  tests/testthat/test-coincident.R:69-79 — Kriteria luar sampel indeks
  koinsiden tidak terkunci uji. Uji hanya memeriksa vonis "good". Mutan C5
  (ambang `abs(timing_out) <= 2 * band`) dan C6 (kriteria pangsa tepat
  waktu selalu `TRUE`) lulus. Saran: uji `coincident_out_of_sample()`
  langsung dengan data frame buatan, mis. median lead keluar 1,5 dan 2,5
  untuk band 2, `pct_timely_out` 0,5 dan 0,9 terhadap `min_consistency`,
  lalu periksa `passed` per baris.
  - Perbaikan (A5, putaran 2): test-coincident.R "R2/R3": ketiga baris luar sampel diuji di tepi pita (2 lolos, 2,5 gagal; 0,5 lolos, 0,4 gagal; |gap| = min_lead lolos, +0,5 gagal).
- [x] [R3][minor] R/coincident.R:152-154 dan R/selection-bias.R:109-114 —
  Untuk `OecdClassifier`, kriteria waktu dalam sampel memakai pita terbuka
  (`abs(median_lead) < band`, "within (-b, b)"), tetapi kriteria luar
  sampel dan `pct_timely_out` memakai `<=` dengan teks "within +/- b".
  Lead tepat ±2 bulan dianggap koinsiden di luar sampel, tetapi tidak di
  dalam sampel. Definisi OECD koinsiden menjadi tidak konsisten dalam satu
  kartu skor. Saran: generic internal kecil (mis. `in_timing_band(classifier,
  lead, band)`) yang juga dipakai `coincident_criteria()`, lalu pakai
  `timing_rules()$timing` untuk teks baris luar sampel.
  - Perbaikan (A5, putaran 2): generic internal `in_timing_band()` (inklusif untuk `Classifier`, ketat untuk `OecdClassifier`) dipakai di `coincident_criteria()`, `coincident_out_of_sample()` dan `pct_timely_out`; teks ambang luar sampel dari `timing_rules()`; uji R2/R3. Ketiga generic pindah ke R/classes-classifier.R.
- [x] [R4][minor] R/quality.R:105,125,210,237, R/selection-bias.R:73 dan
  R/methods-plot.R:88 — Refaktor 0.2.1 menghapus cabang kelas untuk
  pengklasifikasi, tetapi inti masih bercabang pada `role == "coincident"`
  di lima tempat, dan `plot()` bercabang pada `is(x, "CciResult")`. Ini
  bukan pelanggaran harfiah CLAUDE.md, karena `role` adalah data. Namun
  setiap peran baru akan menyentuh lima fungsi. NEWS 0.2.1 juga menyatakan
  cabang kelas sudah diganti, padahal `plot()` masih memakainya. Saran:
  setidaknya ganti label `plot()` dengan metode `plot` untuk `CciResult`
  (atau `callNextMethod()` dengan argumen label). Untuk `role`,
  pertimbangkan satu tabel fungsi per peran, atau catat keputusannya di
  03-design.
  - Perbaikan (A5, putaran 2): legenda `plot()` dari generic internal `index_label()` (metode `CliResult`/`CciResult`); `role` adalah nilai slot, bukan kelas, dan tetap memilih kriteria. NEWS kini menyebut keduanya dengan tepat.
- [x] [R5][minor] NEWS.md:59-63 dan data-raw/calibrate_coincident.R:1-2 —
  NEWS menyatakan bahwa laju lolos "were computed with the 0.2 defaults (AR
  extension, chained ragged edge)". Data simulasi kalibrasi lengkap (tanpa
  ujung compang-camping), sehingga "chain" sama persis dengan "level", dan
  yang berubah hanya perpanjangan AR. Tidak ada uji `cci_build()` dengan
  ujung compang-camping, padahal itulah interaksi utama dengan bawaan 0.2.0
  (saya memeriksanya manual, lihat di atas). Saran: tulis "AR extension;
  the chained ragged edge plays no role with complete simulated data", lalu
  tambahkan satu uji `cci_build(..., select = FALSE)` dengan komponen yang
  terlambat, yang membandingkan "chain" dan "level".
  - Perbaikan (A5, putaran 2): NEWS menyebut panel simulasi lengkap sehingga hanya perpanjangan AR yang berpengaruh; uji baru "R5: a coincident index chains at the ragged edge" (agregator diteruskan, selisih hanya di ujung).
- [x] [R6][minor] R/coincident.R:163-172 — Mutan C8 (suku `- med`
  dihapus dari `coincident_score()`) lulus semua uji. Skor ini menentukan
  komponen yang dibuang pada eliminasi mundur, tetapi rumusnya tidak
  didokumentasikan (`?cli_build` mendokumentasikan skor indikator
  pendahulu) dan tidak diuji. Saran: dokumentasikan skor di `?cci_build`
  seperti di `?cli_build`, dan tambahkan uji kecil yang membandingkan dua
  validasi buatan yang hanya berbeda pada median lead.
  - Perbaikan (A5, putaran 2): uji "R6": skor = 10·Σcek − |lag| − |median| + 5·konkordansi − 5·pangsa; median dan lag masing-masing mengurangi 1.
- [x] [R7][minor] R/classes-filter.R:90 dan R/filters.R:29 — F-03 §6
  mensyaratkan λ berhingga, tetapi `check_number(lambda, "lambda", lower =
  0)` di `hp_filter()` menerima `lambda` di [0, Inf]. `hp_trend_core(x, Inf)` dan
  `extract_cycle(hp_filter(lambda = Inf), x)` diam-diam menghasilkan NaN.
  Perilakunya sama dengan 0.2.0, jadi bukan regresi, tetapi prasyarat yang
  tertulis tidak ditegakkan. Saran: tolak `Inf` di validasi
  (`rcli_error_argument`). Alternatifnya, tangani batas λ → ∞ sebagai tren
  linear kuadrat terkecil dan dokumentasikan.
  - Perbaikan (A5, putaran 2): `hp_filter(Inf)` → `rcli_error_argument`; uji di test-filters.R.
- [x] [R8][minor] harness/01-requirements.md:50 dan
  harness/02-math/F-03.md:55,76 — AC-FR-004.5 dan F-03 §5 menyebut
  "replikasi `mFilter::hpfilter` dan `neverhpfilter`". Uji `neverhpfilter`
  di test-filters.R:34-44 mereplikasi penyaring **Hamilton**, bukan HP,
  jadi uji itu tidak menyumbang bukti untuk FR-004. Replikasi HP hanya ada
  satu, yaitu `mFilter` dengan λ = 1600 pada data triwulanan. Saran:
  perbaiki teks AC/F-03, dan tambahkan replikasi `mFilter::hpfilter` pada
  λ OECD bulanan (133 107,9 atau 129 600; saya mendapat selisih 5,8·10⁻¹⁰).
  - Perbaikan (A5, putaran 2): uji replikasi mFilter bulanan λ = 129 600 (test-filters.R); AC-FR-004.5 dan F-03 §5/§8 diperbaiki.
- [x] [R9][minor] harness/gate-report.md (20:34) — G6 "Putusan APPROVE"
  dibaca dari 06-review.md milik 0.2.0. Gate report dibuat sebelum review
  0.2.1, dan G5/G7/G8 dilewati (`--skip-commands`). Saran: jalankan ulang
  gerbang setelah review ini, dengan perintah, sebelum rilis 0.2.1.
  - Perbaikan (A5, putaran 2): gerbang G5–G8 dijalankan penuh dengan perintah (lihat gate-report.md putaran 2).
- [x] [R10][minor] DESCRIPTION:3 — Judul dari PR berisi 72 karakter.
  "Writing R Extensions" meminta judul tidak lebih dari 65 karakter, dan
  tim CRAN biasanya menegur judul yang lebih panjang (`R CMD check` tidak
  menandainya). Saran: mis. "Composite Leading and Coincident Indicators"
  (43 karakter).
  - Perbaikan (A5, putaran 2): Title: "Composite Leading and Coincident Indicators" (43 karakter).
- [x] [R11][nit] NEWS.md — (a) baris 63 berisi 86 karakter, tidak seperti
  baris lain yang dibungkus pada 80; (b) tidak ada baris kosong sebelum
  `# rcli 0.2.0` (baris 82); (c) butir refaktor `timing_band()` (baris 17)
  berada di bawah "Faster HP filter", padahal seharusnya di bawah
  "Coincident index" atau "Other changes". Semantic versioning: fitur baru
  sebesar indeks koinsiden lazimnya menaikkan versi minor (0.3.0), bukan
  patch. Keputusan "0.2.1" ada di tangan pengelola dan sudah tercatat di
  STATE, tetapi sebaiknya disebut di 08-release.
  - Perbaikan (A5, putaran 2): baris panjang dipecah, baris kosong sebelum `# rcli 0.2.0`, butir refaktor pindah ke "Other changes"; alasan versi 0.2.1 dicatat di NEWS (tidak ada bawaan yang berubah, keputusan pemelihara).
- [x] [R12][nit] harness/01-requirements.md (AC-NFR-002.2) — Hasil ukur
  menyebut "7 seri `simulate_cycles(seed = 1)`", padahal `cli_cycles()`
  memproses 8 seri (7 kandidat dan acuan). Per seri saya mendapat
  2,6 ms (AR) dan 70 ms (0.2.0); "±3 ms vs ±80 ms" cocok bila dibagi 7.
  Kesimpulannya tidak berubah. Saran: tulis "per kandidat (7) dari satu
  panggilan dengan 8 seri" atau bagi dengan 8.
  - Perbaikan (A5, putaran 2): AC-NFR-002.2 menyebut pembagi 7 kandidat dan 8 seri.
- [x] [R13][nit] tests/testthat/test-app.R:92 dan
  tests/testthat/test-app-e2e.R:132 — Nama uji masih "the server runs the
  nine steps in order", padahal sekarang ada sepuluh langkah. Komentar
  "FR-005 AC-3" di e2e terletak di atas ekspektasi lain (verdict `res`),
  bukan di atas perbandingan `env$cci` (baris 136-137). Selain itu, uji
  skrip manual di test-app.R hanya mencocokkan teks `select = FALSE`,
  tidak membandingkan `@index`. Saran: ganti nama uji, pindahkan komentar,
  dan bandingkan indeks juga untuk mode manual.
  - Perbaikan (A5, putaran 2): nama uji "ten steps"; komentar FR-005 AC-3 dipindah ke atas pemeriksaan indeks; mode manual kini membandingkan indeks skrip dengan indeks GUI.
- [x] [R14][nit] harness/STATE.md:31,37 — Baris kosong di tengah tabel "Log
  putaran" memutus tabel Markdown. Baris 19:00 dan sesudahnya tidak tampil
  sebagai bagian tabel.

  - Perbaikan (A5, putaran 2): baris kosong di tabel log dihapus.

## Catatan di luar cakupan (sudah ada sejak 0.1.3, bukan dari increment ini)
- R/selection-bias.R:92 — Untuk peran "leading", `one_cutoff()` membangun
  komposit sampel penuh dengan `cli_composite(cycles, comps, spec, ref)`
  tanpa `shifts`. Komposit latihnya (`cli_build()`) digeser bila
  `spec@lag_shift = TRUE`, yaitu bawaan `oecd_spec()`. Akibatnya
  `median_lead_in` berasal dari komposit yang digeser, sedangkan
  `median_lead_out` dari komposit yang tidak digeser, sehingga `lead_gap`
  untuk spesifikasi OECD berat sebelah. Saran: buka isu terpisah; terapkan
  `lag_shifts(comps, train@assessment)` hanya untuk peran "leading".

## Review putaran 2
- Reviewer: A6 (konteks bersih: ya). Keadaan: cabang lokal `cci-0.1.4`,
  HEAD 4d060d8. Komit yang dibaca sejak 59c330e:
  - 161fa87: kolom `note` di `show()`;
  - e948273: batas waktu n = 10⁵ tidak berlaku di bawah covr;
  - e3bcd37: perbaikan R1–R14;
  - 4d060d8: gate report.

  Semua pemeriksaan dijalankan pada salinan `git archive HEAD`.
- Kotak `[x]` di atas dicentang oleh A5. Status di bawah ini adalah
  verifikasi saya.
- Gerbang yang saya jalankan sendiri:
  - `devtools::test()` lengkap: 1468 lulus, 0 gagal, 0 galat, 1 dilewati
    (seasonal), termasuk e2e Chrome;
  - `lintr::lint_package()`: 0 temuan;
  - `roxygenise()`: `man/` dan `NAMESPACE` sinkron;
  - tidak ada baris > 80 karakter di berkas R yang diubah (yang tersisa
    hanya test-app-e2e.R:123-124 dari versi pertama).

  Menurut koordinator, CI GitHub untuk 4d060d8 hijau (R-CMD-check di 3 OS,
  lint, cakupan, gui-e2e). Saya tidak memverifikasinya sendiri.
- Mutasi (filter
  `coincident|selection-bias|quality|^app$|filters|plot|methods`):

  | Mutan | Uraian | Status |
  |---|---|---|
  | C1 | cabang `.hasSlot` di `validation_role()` dihapus | **mati** (1 galat) |
  | C5 | ambang waktu luar sampel 2 × band | **mati** (2 gagal) |
  | C6 | kriteria pangsa tepat waktu selalu `TRUE` | **mati** (1 gagal) |
  | C8 | suku median dihapus dari `coincident_score()` | **mati** (1 gagal) |
  | C11 | `in_timing_band` OECD `<` → `<=` | mati (3 gagal) |
  | C12 | `in_timing_band` bawaan `<=` → `<` | mati (5 gagal) |
  | C15 | penolakan `hp_filter(Inf)` dihapus | mati (1 gagal) |
  | C16 | teks ambang luar sampel tetap "within +/-" | mati (1 gagal) |
  | C13 | `pct_timely_out` kembali ke `abs(leads) <= band` | **bertahan** (R15) |
  | C14 | `index_label()` untuk `CciResult` → label pendahulu | **bertahan** (R16) |

### Status temuan putaran 1
- R1 tertutup. Uji membuat objek tanpa slot `role` (`.hasSlot` FALSE), dan
  C1 kini mati. `cli_quality()`/`show()` pada objek itu belum diuji;
  saya sudah memeriksanya manual di putaran 1.
- R2 tertutup. `coincident_out_of_sample()` diuji di tepi pita untuk ketiga
  baris; C5 dan C6 mati.
- R3 tertutup di kode. `in_timing_band()` (inklusif untuk `Classifier`,
  ketat untuk `OecdClassifier`) dipakai di kriteria dalam sampel, di baris
  luar sampel, dan di `pct_timely_out`; teks ambang berasal dari
  `timing_rules()` (C11, C12, C16 mati). Sisa celah uji kecil dicatat
  di R15.
- R4 tertutup. Legenda `plot()` memakai generic `index_label()`. Cabang
  `role` dipertahankan sebagai keputusan yang dicatat di NEWS ("a value and
  still selects the criteria"); saya terima. Metodenya tidak diuji (R16).
- R5 tertutup. NEWS menjelaskan bahwa panel simulasi lengkap, sehingga hanya
  perpanjangan AR yang berpengaruh. Uji "R5" membandingkan "chain" dan
  "level" pada ujung compang-camping: badan seri identik sampai transformasi
  afin, dan nilai terakhir berbeda.
- R6 tertutup. Uji "R6" mengunci rumus skor (median dan lag masing-masing
  −1), dan C8 mati. Rumusnya masih belum didokumentasikan di `?cci_build`,
  tetapi itu nit dan saya tidak membuka temuan baru.
- R7 tertutup untuk `hp_filter()`: `Inf` ditolak dengan
  `rcli_error_argument` dan diuji (C15 mati). Sisa di
  `hp_double_filter()` dicatat di R17.
- R8 tertutup. Ada replikasi `mFilter` bulanan (λ = 129 600, toleransi
  1e-8), dan AC-FR-004.5 serta F-03 §5/§8 sudah diperbaiki.
- R9 tertutup. Gate report 4d060d8 menjalankan G5–G8 dengan perintah:
  - uji: 1468 lulus;
  - lint: bersih;
  - cakupan: 96,6%;
  - `R CMD check --as-cran`: 0 galat, 0 peringatan, 2 NOTE.

  G6 di laporan itu masih membaca putusan putaran 1 (APPROVE). Gerbang ini
  perlu dijalankan sekali lagi setelah putusan ini.
- R10 tertutup. Judul menjadi "Composite Leading and Coincident Indicators"
  (43 karakter).
- R11 tertutup. Baris panjang dipecah, ada baris kosong sebelum
  `# rcli 0.2.0`, butir refaktor pindah ke "Other changes", dan alasan
  versi 0.2.1 dicatat di NEWS.
- R12 tertutup. AC-NFR-002.2 menjelaskan pembagi 7 kandidat dan 8 seri.
- R13 tertutup. Uji diberi nama "ten steps", komentar AC-3 dipindahkan,
  dan mode manual kini membandingkan `@index` dari skrip dengan GUI.
- R14 tertutup. Tabel log di STATE.md utuh. Catatan di luar cakupan
  (`lag_shift` di uji bias seleksi) masuk "Eskalasi terbuka" di STATE.md.
- Komit 161fa87 (kolom `note`) dan e948273 (AC-FR-004.6 tanpa covr) juga
  saya periksa. Keduanya wajar dan diuji. Revisi AC-FR-004.6 tercatat di
  01-requirements. Bukti O(n) tetap ada, karena n = 10⁵ selesai tanpa
  matriks padat.

### Temuan baru
- [ ] [R15][nit] tests/testthat/test-coincident.R ("R2/R3") — `pct_timely_out`
  di R/selection-bias.R:112 hanya teruji lewat `in_timing_band()`
  langsung. Mutan C13 (kembali ke `abs(leads) <= band`) bertahan, karena
  tidak ada uji `cli_selection_bias(role = "coincident")` dengan
  `oecd_classifier()` dan lead tepat di tepi pita. Saran: uji
  `one_cutoff()` dengan pasangan titik balik buatan atau
  `local_mocked_bindings()` untuk lead ±band.
- [ ] [R16][nit] R/methods-plot.R — `index_label()` tidak diuji (mutan C14
  bertahan). Saran:
  `expect_equal(rcli:::index_label(cci), "coincident index")` dan label
  pendahulu untuk `CliResult`.
- [ ] [R17][nit] R/classes-filter.R:99-101 —
  `hp_double_filter(trend_period = Inf)` lolos validasi, dan
  `hp_lambda(Inf)` = Inf menghasilkan siklus NaN. Ini sisa R7 yang sama
  dengan perilaku 0.2.0. Saran: tolak periode tak berhingga di
  `hp_double_filter()`, dan di `cf_filter()`/`bk_filter()` bila relevan.

### Ringkasan putaran 2
R1–R14 tertutup. Mutan C1, C5, C6 dan C8 yang bertahan di putaran 1 kini
mati. Ada tiga nit baru (R15–R17); tidak ada blocker, major, atau minor
yang terbuka. Catatan di luar cakupan (`lag_shift` di uji bias seleksi)
tercatat sebagai eskalasi di STATE.md.

## Putusan
Putaran 1 — Inti numerik FR-004 benar dan sesuai F-03 baris demi baris.
Hasilnya diverifikasi independen terhadap `solve()` padat, solusi eksak
rasional, dan `mFilter`. 15 dari 15 mutan solver mati, dan klaim waktu di
NEWS serta `?Extension-class` terbukti. Penggabungan PR #1 bersih: agregator,
perpanjangan, objek lama, dan skrip GUI konsisten dengan bawaan 0.2.0.
Uji lengkap, lint, roxygen, dan `R CMD check --as-cran` bersih. Tidak ada
blocker atau major. Ada sepuluh minor: R1, R2 dan R6 adalah celah uji
(mutan bertahan); R3 inkonsistensi pita OECD luar sampel; R4, R5, R7 dan R8
menyangkut desain dan dokumentasi; R9 gerbang usang; R10 judul. Ada pula
empat nit. Sebaiknya R1, R2, R3 dan R9 ditutup sebelum rilis 0.2.1.

Putaran 2 — R1–R14 tertutup dan terverifikasi; hanya nit R15–R17 yang
terbuka. Jalankan ulang G6 agar gate report membaca putusan ini.

Putusan: APPROVE

## Tindak lanjut A5 sesudah putaran 2
- [x] R16 (nit): uji "R16: the plot legend names the kind of index" (test-coincident.R).
- [x] R17 (nit): `hp_double_filter()` menolak periode tak berhingga (`rcli_error_argument`); uji "R17" di test-filters.R; NEWS diperbarui.
- [ ] R15 (nit): dibiarkan terbuka; `pct_timely_out` dengan pengklasifikasi OECD di tepi pita belum diuji lewat `one_cutoff()` (aturan intinya diuji langsung pada `in_timing_band()`).
