# 06 — Review

- Increment: rcli 0.6.0 (FR-012)
- Reviewer: A6 (konteks bersih: ya)
- Putaran: 2 (putaran 1 terhadap 8d45ba7, putaran 2 terhadap a38aba0;
  basis c950f03, 0.5.1 di main)
- Review 0.5.1 tersimpan di riwayat git berkas ini (komit dddd20c).

## Yang diperiksa (putaran 1)

- **Kesesuaian dengan F-05, F-06, dan F-07.** Kode dicocokkan dengan catatan
  matematika tanpa mengulang buktinya.
  - `orient_sign()`, `sign_lag_max()` = min(L, max(1, ⌊P̂/4⌋)),
    `peak_lag_max()` = ⌊P̂/2⌋, dan `cross_correlation(peak_max =)`: sesuai
    F-05 revisi 2.
  - `hac_fixed_b_p()` dan `fixed_b_p()`: sesuai F-06. Tabel `fixed_b_null`
    terurut, b = 0,3, dan 400 ribu ulangan.
  - `recursive_logit()`: sesuai F-07 dengan g = max(h, 1), t₀ pada 40%, dan
    syarat minimal 10 observasi latih dengan dua kelas. Ada satu
    penyimpangan kecil (R8).
- **Alur `cli_assess()`.** Diperiksa sumber arah (meta atau data), inversi,
  penanggalan yang kini hanya dilakukan sekali sesudah orientasi, dan
  `sign_source`. Diperiksa pula pemakaian `assessment@inverted` di `build.R`,
  `coincident.R` (`cci_build`), `selection-bias.R` (`one_cutoff`), dan
  `app.R`. Semuanya konsisten untuk pemakaian normal; lihat R5 untuk
  pemakaian ulang siklus yang sudah dibalik.
- **Kompatibilitas mundur** (`/tmp/rv060/compat.R`).
  - `CandidateSet` tanpa `meta$sign` memberi tabel penilaian yang identik.
  - `LeadAssessment` tanpa `sign_source` tetap dapat dicetak dan
    ditampilkan dengan `assessment_display()`.
  - `OecdClassifier` tanpa slot `conformity` berperilaku seperti
    `conformity = FALSE`, dan `show`, `cli_build()`, `oecd_spec(classifier =)`,
    serta `update()` berjalan. `validObject()` gagal, tetapi tidak pernah
    dipanggil.
  - `probability` tanpa `n_forecasts` tetap dapat dicetak dan dinilai.
- **Kasus batas validasi** (`/tmp/rv060/edge.R`).
  - Sampel pendek: 8 tahun bulanan dan 12 tahun triwulanan.
  - `contraction_fit()` mengembalikan NULL, dan horizon 60 memberi
    `n_forecasts` = 0.
  - Data latih dengan satu kelas, x konstan, separasi sempurna, dan
    `cci_validate()` dengan h = 0.
- **GUI dengan `shiny::testServer`** (`/tmp/rv060/test-zz-review.R`, 15 PASS).
  - (A) Arah dinyatakan untuk counter_4 (−1) dan lead_3 (1), lalu acuan
    diganti ke lead_6. Isian `sgn_` mengikuti nama kandidat, acuan lama yang
    menjadi kandidat mendapat "Otomatis", dan langkah 2 yang dijalankan ulang
    memberi `sign` yang benar.
  - (B) Unggahan banyak berkas: `sign` sampai ke `cli_align()`,
    `cli_candidates()`, tabel langkah 6 ("countercyclical (declared)"), dan
    skrip. Skrip yang dijalankan ulang memberi komponen yang sama.
  - (C) Metode OECD dengan kotak kesesuaian tidak dicentang: skrip menulis
    `oecd_classifier(conformity = FALSE)` serta mereproduksi kelas dan
    komponen.
- **Tata letak langkah 2.** Tangkapan layar Chrome *headless* pada lebar
  1400 px dan 1024 px: `/tmp/rv060/step2-id-1400.png` dan
  `/tmp/rv060/step2-id-1024.png`.
- **Plot.** `plot_ccf()` dirender ke `/tmp/rv060/ccf.png` dan sudah dilihat;
  sorotannya benar untuk lead_6, counter_4, noise_2, dan lag_3.
- **Uji.**
  - `test-evaluation-060.R`: 67 PASS.
  - Seluruh rangkaian dengan `NOT_CRAN=true RCLI_E2E=true` (termasuk
    *snapshot* dan e2e Chrome): 0 gagal, 0 galat
    (`/tmp/rv060/fulltest-notcran.log`).
- **Gaya kode.** `lintr` bersih pada `R/assessment.R`, `R/validation.R`, dan
  `R/app.R`. Tidak ada baris baru di atas 80 karakter; tiga baris panjang di
  `data-raw/compare_oecd.R` dan `test-quality.R` sudah ada sebelumnya.
  Imports tidak bertambah, dan 'shiny' hanya dipanggil sebagai `shiny::`.
- **Teks aplikasi.** Kunci baru `app_text` ada dalam dua bahasa, dan kelima
  kunci baru `app_phrases_id` dipakai di tabel.
- **Kesesuaian NEWS.md, vinyet, `?concordance`, `?oecd_classifier`, dan
  F-07 §5 dengan `inst/calibration/*.csv`.**
- **Kinerja 0.5.1 dibanding 0.6.0** (`/tmp/rv060/perf*.R`, median, mesin yang
  sama).

  | Pengukuran | 0.5.1 | 0.6.0 |
  |---|---|---|
  | `cli_validate` | 0,02 detik | 0,17 detik |
  | `cli_build` bulanan | 0,26 detik | 0,37 detik |
  | `cli_build` dengan 2 titik potong | 0,61 detik | 0,98 detik |
  | Loop eliminasi 9 pendahulu yang gagal (`perf3.R`) | 1,7 detik | 7,2 detik |

- **Tidak dijalankan:** `R CMD check --as-cran`.

## Temuan putaran 1

- [x] [R1][major] R/app.R:app_server (`output$meta_ui`) — Kolom frekuensi
  selebar 1 tidak terbaca.
  - Pada 1400 px pemilih frekuensi hanya menampilkan "(beru" dengan panah
    menimpa teks.
  - Pada 1024 px pemilih itu hanya berisi panah, dan judul "Frekuensi asal"
    bertabrakan dengan "Sumber" ("FrekuensiSumber").
  - Kolom arah selebar 2 juga memotong "Otomatis (dari data)" menjadi
    "Otomatis (dari dat" atau "Otomatis (c".
  - Bukti: `/tmp/rv060/step2-id-1400.png` dan `/tmp/rv060/step2-id-1024.png`.
  - Usul: label arah yang pendek ("Otomatis", "Prosiklis", "Kontrasiklis"),
    frekuensi kembali selebar 2, dan sumber dipindah ke baris kedua atau
    dibuat selebar 1. Ambil ulang tangkapan layar pedoman
    (`pedoman/scripts/screenshots.R`).
- [x] [R2][major] R/build.R:select_components / R/coincident.R:cci_build
  (`evaluate`) — Logit rekursif dihitung untuk setiap percobaan di loop
  eliminasi, padahal hasilnya tidak pernah dipakai di sana.
  - `passed` dan `failed` hanya berasal dari `leading_checks()`, dan
    `composite_score()` tidak memakai `probability`. Peluang kontraksi baru
    relevan untuk komposit yang akhirnya diterima.
  - Akibatnya `cli_validate()` 8× lebih lambat (0,02 → 0,17 detik), dan loop
    dengan 9 pendahulu 4,3× lebih lambat (1,7 → 7,2 detik).
  - Biaya ini dikalikan lagi oleh jumlah titik potong `oos_cutoffs`
    (`cli_selection_bias` memanggil `cli_build` ulang) dan oleh GUI
    (`contraction_probability()` dihitung lagi di langkah 8).
  - Jumlah validasi tumbuh kira-kira k²/2 untuk k pendahulu.
  - Usul: validasi tanpa kelompok prediksi di dalam `evaluate`, misalnya
    argumen internal `prediction = FALSE`, lalu satu `cli_validate()` penuh
    untuk komposit terpilih. Pilihan lain: *warm start*
    `glm.fit(start = coef sebelumnya)`. Catat hasil ukurnya di NFR-002.
- [x] [R3][major] inst/calibration/oecd-classification.csv,
  vignettes/rcli.Rmd — AC-FR-012.8 tidak terpenuhi, dan vinyet keliru.
  - AC meminta deteksi pendahulu sejati turun paling banyak 2 poin persen
    dibanding aturan 0.5.1. Kolom `leading_found` untuk "OECD (min 3
    matched)" dibanding "OECD (median lead only)":

    | Frekuensi, derau | Dengan kesesuaian | Median *lead* saja | Selisih |
    |---|---|---|---|
    | 4, 0,4 | 0,820 | 0,843 | −2,3 pp |
    | 12, 0,4 | 0,917 | 0,940 | −2,3 pp |
    | 4, 0,8 | 0,430 | 0,533 | −10,3 pp |
    | 12, 0,8 | 0,703 | 0,773 | −7,0 pp |

  - Vinyet menulis "the OECD rule finds as many true leaders", padahal itu
    hanya benar pada derau 0,2.
  - `harness/gate-report.md` tidak menelusuri AC-FR-012.8 maupun .5.
  - Usul: perbaiki kalimat vinyet dan NEWS ("finds 2 to 10 points fewer
    leaders in noisy data"). Revisi AC secara eksplisit dengan alasannya,
    atau tunjukkan perubahan yang memenuhinya. Tambahkan pemeriksaan AC .5
    dan .8 di laporan gerbang.
- [x] [R4][minor] R/methods-show.R:classifier_lines("OecdClassifier") —
  `print(oecd_spec())` masih menulis "leading if: median lead at turning
  points >= 2 months (OECD rule)" tanpa syarat kesesuaian siklus. Itu bukan
  lagi aturan bawaan. Gunakan `oecd_conformity()` seperti di
  `show("OecdClassifier")`.
- [x] [R5][minor] R/assessment.R:cli_assess — Inversi ganda bila `cycles`
  sudah dibalik dan arah dinyatakan.
  - `cli_assess(cand, res@spec, cycles(res))` dengan
    `meta$sign = -1` membalik counter_4 dua kali. Hasilnya berubah dari
    leading (ccf_lag 4, r 0,95) menjadi rejected (ccf_lag −18, r 0,66).
    Bukti: `/tmp/rv060/dbl.R`.
  - Di 0.5.1 panggilan yang sama idempoten, dan di 0.6.0 tetap idempoten bila
    arah ditentukan dari data.
  - `aggregate.R:276` membaca tanda dari `"inverted (counter-cyclical)" %in%
    steps`, sehingga siklus yang dibalik dua kali tetap diberi tanda −1.
  - Usul: lewati inversi bila langkah itu sudah ada di `cs@steps` (atau
    tolak dengan `rcli_error_argument`), dan tambahkan uji.
- [x] [R6][minor] R/quality.R (roxygen dan `cli_quality`), R/app-text.R
  (`acceptable_note`, `acceptable_note_cci`) — Teks kriteria prediksi
  ketinggalan.
  - `?cli_quality` masih menyebut "Pesaran and Timmermann (1992) test" dengan
    rujukan 1992. Ia juga menggambarkan prakiraan naif sebagai "a constant
    probability equal to the share of contraction periods".
  - Keduanya sudah berubah: kini bentuk regresi 2009 dengan *fixed-b*, dan
    prakiraan naif rekursif.
  - Catatan vonis "In-sample criteria are met" / "Kriteria dalam sampel
    lolos" tidak lagi tepat, karena kelompok prediksi kini luar sampel.
    Contoh rumusan: "Turning-point and out-of-sample prediction criteria are
    met; run the selection-bias check (oos_cutoffs)…".
  - `?cli_validate` sudah benar.
- [x] [R7][minor] R/validation.R:probability_scores, R/quality.R:quality_prediction —
  `n_forecasts` tidak terlihat dan tidak punya batas minimum.
  - Dengan 8 prakiraan, kriteria QPS dinyatakan "pass" (1,04 < 1,16), AUC
    bernilai NA karena hanya satu kelas sehingga dinyatakan "fail", dan
    catatannya hanya "Criteria not met in: prediction".
  - Dengan `horizon = 60`, `n_forecasts` = 0 dan ketiga kriteria gagal tanpa
    penjelasan (`/tmp/rv060/edge.R`).
  - `print(CliValidation)` juga tidak menampilkan `n_forecasts`.
  - Usul: baris informasi "number of out-of-sample forecasts" di kartu skor,
    ambang minimum (misalnya ≥ 20 dengan dua kelas, selain itu status NA
    disertai catatan), dan `n_forecasts` di cetakan validasi.
- [x] [R8][minor] R/validation.R:recursive_logit — Bila `glm.fit()` memberi
  koefisien NA (x konstan di data latih), `p[t]` bernilai NA tetapi `naive[t]`
  tetap diisi.
  - Ada 13 kasus seperti itu di `edge.R`. F-07 §1 menyatakan "selain itu p_t
    dan q_t NA".
  - `contraction_probability()` lalu mengembalikan `naive` tanpa
    `probability`. Ringkasan QPS tidak terpengaruh karena memakai
    `!is.na(p)`.
  - `fit$converged` juga tidak diperiksa.
  - Usul: isi `naive[t]` hanya bila prediksi terhingga.
- [x] [R9][minor] harness/01-requirements.md:AC-FR-012.2 — Teks AC tidak
  mengikuti F-05 revisi 2.
  - Masih tertulis K = max(`min_lead`, ⌊P̂/4⌋), sedangkan kode dan F-05
    memakai max(1, ⌊P̂/4⌋). AC juga menyebut `ccf_lag` dicari pada
    ±`ccf_lag_max`, sedangkan kode memakai setengah siklus.
  - Klaim "arah semua seri sama dengan 0.5.1" tidak berlaku untuk noise_2:
    *snapshot* `assessment.md` kini menandainya "noise_2*", dan uji
    mengecualikan seri derau.
  - Usul: perbarui AC dan sebut pengecualian seri derau.
- [x] [R10][minor] NEWS.md, vignettes/rcli.Rmd, harness/02-math/F-07.md §5 —
  Angka tidak sama dengan `inst/calibration/test-size.csv`.
  - NEWS dan vinyet menulis bahwa Newey-West menolak "19 to 37 percent",
    padahal csv memberi 0,11 (freq = 4, geser tetap), 0,19, 0,22, dan 0,37,
    yaitu 11–37%. `?concordance` sudah benar (11–19% untuk geser tetap).
  - F-07 §5 menulis QPS luar sampel lolos 62%, AUC 16% → 11%, dan semua
    kriteria 9% → 6%. Csv memberi `pass_oos_qps` 0,30, `pass_in_auc` =
    `pass_oos_auc` = 0,06, dan `pass_in_all` 0,05 → `pass_oos_all` 0,03.
  - Catatan desain menulis inflasi "sekitar 15% bulanan", sedangkan csv
    memberi 0,18.
  - Samakan angkanya dengan bukti final.
- [x] [R11][minor] R/validation.R:pesaran_timmermann — Makna kolom `pt_stat`
  berubah tanpa catatan.
  - Dulu kolom itu berisi statistik z PT 1992; kini berisi selisih
    proporsi kecocokan arah.
  - Kolom ini ikut ke `as.data.frame(validation)` dan unduhan CSV. Catat di
    NEWS dan dokumentasi kelas, atau ganti nama kolomnya.
- [x] [R12][minor] tests/testthat/_problems/*.R — Empat berkas ekstrak
  kegagalan testthat ikut di-*commit*.
  - Isinya asersi lama yang kini salah, misalnya `expect_equal(horizon,
    ccf_lag)` dan `expect_named(pr, c("time", "contraction",
    "probability"))`.
  - Berkas itu tidak tercantum di `.Rbuildignore` sehingga ikut ke *tarball*.
  - Usul: hapus, dan tambahkan `tests/testthat/_problems` ke `.gitignore`
    dan `.Rbuildignore`.
- [x] [R13][nit] R/app.R:assessment_display, R/methods-show.R — Seri yang
  arahnya tidak terbaca dari data (`orient_sign()` NA, tidak dibalik)
  ditampilkan sebagai "procyclical". Pertimbangkan kolom `sign` (1, −1, NA)
  di tabel penilaian dan label "tidak tentu".
- [x] [R14][nit] R/assessment.R:fixed_b_p — Nilai p dibatasi bawah pada
  1e-4, yaitu batas tabel. Kartu skor mencetak "1e-04" seolah-olah nilai
  persis. Tulis "< 1e-04" atau sebut batas ini di `?concordance` dan
  `?cli_quality`.
- [x] [R15][nit] R/candidates.R:complete_meta — `meta$sign` bertipe faktor
  diubah menjadi kode level. Contohnya, `factor(c(-1, NA))` menjadi 1 tanpa
  galat. Ubah ke `as.character()` dahulu bila `is.factor()`.
- [x] [R16][nit] R/app.R / R/app-options.R — Ada dua kendali untuk
  kesesuaian siklus OECD.
  - Untuk metode OECD tersedia kotak centang; untuk metode rcli tersedia
    pilihan "oecd" atau "oecd_median" di opsi lanjutan.
  - Pada metode rcli kotak centang diabaikan. Terverifikasi: kotak FALSE
    dengan pengklasifikasi "oecd" memberi `conformity` TRUE.
  - Perilaku ini dapat diterima, tetapi sebaiknya dijelaskan di teks bantuan.
- [x] [R17][nit] R/assessment.R:cli_assess — Korelasi silang dihitung dua
  kali per kandidat: sekali untuk arah dan sekali di `assess_pair()`.
  Waktunya kecil, tetapi hasil pertama bisa diteruskan.
- [x] [R18][nit] R/app-plots.R:plot_ccf — Batang yang disorot bisa bukan
  batang tertinggi bila puncak global berada di luar jendela setengah siklus.
  Arsir jendela pencarian (dan jendela tanda ⌊P̂/4⌋) agar pengguna tidak
  bingung. Label GUI "Horizon uji peluang" kini juga berlaku untuk uji arah
  PT.

## Keputusan putaran 1

Putusan putaran 1: CHANGES-REQUESTED

Ada tiga temuan major:

- R1: tata letak langkah 2 tidak dapat dipakai pada lebar umum;
- R2: regresi kinerja yang tidak perlu di loop seleksi;
- R3: AC-FR-012.8 tidak terpenuhi, dan vinyet mengklaim sebaliknya.

R4–R12 sebaiknya diselesaikan pada putaran yang sama karena semuanya perbaikan
teks atau penjagaan kecil. Logika inti (F-05, F-06, dan F-07),
kompatibilitas mundur, jalur GUI (penggantian acuan, unggahan banyak berkas,
dan reproduksi skrip OECD tanpa kesesuaian), serta seluruh rangkaian uji
dalam keadaan baik.

## Tindak lanjut putaran 1
- R1: isian arah diletakkan di bawah rasional dalam kolom yang sama; lebar kolom kembali seperti 0.5.1 (2, 3, 2, 2, 3); label pendek ("Arah: otomatis/prosiklis/kontrasiklis"). Tangkapan layar Chrome 1400 dan 1024 px sudah dilihat: semua teks terbaca.
- R2: `validate_leading()` dan `validate_coincident()` dengan `prediction = FALSE` di loop seleksi; `cli_validate()` / `cci_validate()` penuh hanya untuk komposit terpilih. `perf3.R`: 7,2 → 1,3 detik (0.5.1: 1,2 detik); `cli_build()` bulanan 0,56 detik, dengan dua titik potong 1,06 detik.
- R3: AC-FR-012.8 dirumuskan ulang dengan alasan (deteksi turun ≤ 1 poin persen pada bising 0,2, ≤ 12 poin pada bising tinggi; label palsu paling sedikit separuh); vinyet dan NEWS diperbaiki; uji baru membaca `lead-window.csv`, `accuracy.csv`, dan `oecd-classification.csv` (AC .5 dan .8).
- R4: `print()` spesifikasi OECD menyebut syarat kesesuaian.
- R5: arah yang dinyatakan dibandingkan dengan orientasi siklus (`is_inverted()`); panggilan ulang idempoten; `aggregate.R` memakai `is_inverted()`; uji baru.
- R6: `?cli_quality` (PT 2009, naif rekursif, batas tabel p) dan catatan vonis "acceptable" (R, GUI, dua bahasa).
- R7: baris "out-of-sample forecasts" (≥ 20) di kartu skor; jumlahnya di `print()` validasi; uji.
- R8: p dan naif keduanya NA bila `glm.fit()` tidak konvergen atau prakiraannya tidak berhingga.
- R9: AC-FR-012.2 mengikuti F-05 revisi 2.
- R10: angka Newey–West 11–37%; F-07 §5 dan catatan desain disamakan dengan CSV.
- R11: arti `pt_stat` di NEWS dan `?CliValidation`.
- R12: `_problems/` dihapus dan diabaikan (`.gitignore`, `.Rbuildignore`).
- R13: arah yang tidak terbaca: `sign_source` = "none", label "tidak tentu" di GUI.
- R14: batas 1e-4 disebut di `?concordance`, `?cli_quality`, dan NEWS.
- R15: `meta$sign` bertipe faktor dibaca dari labelnya; uji.
- R16: kotak centang kesesuaian hanya tampil untuk metode OECD; pilihan untuk metode rcli ada di opsi lanjutan. Diterima apa adanya.
- R17: tidak diubah (biaya kecil).
- R18: label horizon kini "Horizon uji peluang dan arah"; arsiran jendela pada grafik ditunda.

## Yang diperiksa (putaran 2)

- **R1 (tata letak langkah 2).** Paket dari a38aba0 dipasang ke
  `/tmp/rv060/lib2`, lalu langkah 2 dipotret di Chrome *headless* (id dan en,
  1400 dan 1024 px): `/tmp/rv060/r2-step2-{id,en}-{1400,1024}.png`.
  - Pemilih arah kini berada di bawah rasional, dan lebar kolom kembali
    2, 3, 2, 2, 3 (jumlah 12; terverifikasi juga dari HTML `testServer`).
  - Pada 1400 px semua teks terbaca, termasuk "Arah: otomatis" dan
    "(belum diisi)". Sisa kecil pada 1024 px ada di R24.
- **R2 (kinerja dan kesetaraan hasil).**
  - `/tmp/rv060/same.R` membandingkan 8d45ba7 dengan a38aba0 pada 3 seed,
    termasuk `oos_cutoffs = c(2012, 2016)` dan `cci_build()`. Hasilnya
    identik (`all.equal` TRUE) untuk `audit_log`, `validation@probability`,
    `turning_points`, `out_of_sample`, kartu skor (di luar baris baru), serta
    `probability` dan audit CCI.
  - Loop memakai `passed` dan `score`, yang tidak bergantung pada kelompok
    prediksi.
  - Jalur `cci_build(select = FALSE)` dan jalur tanpa komponen juga benar:
    validasi diganti `cci_validate()` hanya bila ada komposit, dan
    `select_components()` keluar lebih awal bila tidak ada pendahulu.
  - Konsumen lain tidak memakai `probability` dari loop: `one_cutoff()` hanya
    membaca `turning_points`, dan mode manual GUI memanggil `cli_validate()`
    langsung.
  - Waktu (`perf3.R`, loop 9 pendahulu yang gagal):

    | Versi | Waktu |
    |---|---|
    | 0.5.1 | 1,28 detik |
    | 8d45ba7 | 7,2 detik |
    | a38aba0 | 1,45 detik |

    `cli_build` bulanan naik dari 0,22 menjadi 0,39 detik (+1 validasi
    penuh), dan dengan dua titik potong dari 0,66 menjadi 0,98 detik.
- **R3.** AC-FR-012.8 yang dirumuskan ulang dicocokkan dengan
  `oecd-classification.csv`.
  - Penurunan deteksi pendahulu sejati 0 dan 0,3 poin persen pada bising 0,2,
    dan paling besar 10,3 poin persen di bising lebih tinggi. Batas AC
    (≤ 1 dan ≤ 12 poin persen) terpenuhi.
  - Label palsu kalibrasi turun dari 18,5–23% menjadi 2,5–7,5% (≤ separuh).
  - `accuracy.csv` paling besar 1,3% (batas ≤ 1,5%).
  - Uji baru "AC-FR-012.5 and .8" memeriksa angka-angka ini. Vinyet dan NEWS
    kini jujur ("2 to 10 percentage points fewer in noisy data").
- **R5.** `/tmp/rv060/r2-dbl.R`: `cli_assess(cand, spec, cycles(res))` dengan
  `sign = -1` kini idempoten (leading, ccf_lag 4, r 0,95 sama dengan hasil
  pertama), begitu pula tanpa arah dinyatakan. Logika paritas
  `is_inverted()` diperiksa untuk keempat kombinasi (dinyatakan ±1, siklus
  sudah dibalik atau belum) dan benar.
- **R7.** Baris "out-of-sample forecasts" (≥ 20) muncul di kartu skor.
  - Sampel 8 tahun dengan 8 prakiraan memberi status "fail", dan
    `horizon = 340` di uji baru juga memberi "fail".
  - Validasi lama tanpa `n_forecasts` tidak memunculkan baris itu dan tetap
    dapat dicetak (`/tmp/rv060/r2-compat.R`).
  - `print(CliValidation)` menampilkan jumlah prakiraan.
- **R4, R6, R8–R15.** Diperiksa pada diff:
  - `print(oecd_spec())` kini menyebut kesesuaian; untuk pengklasifikasi
    lama tanpa slot, baris itu tidak muncul.
  - Faktor `sign` dibaca dari labelnya.
  - `_problems/` sudah dihapus dan diabaikan.
  - Teks vonis dalam dua bahasa sudah benar.
  - `?CliValidation` dan NEWS menjelaskan `pt_stat`.
- **GUI `testServer`** (`/tmp/rv060/test-zz-review.R` pada a38aba0):
  15 PASS. Arah tetap per nama kandidat sesudah acuan diganti, unggahan
  banyak berkas membawa `sign`, dan skrip OECD dengan kesesuaian tidak
  dicentang mereproduksi kelas dan komponen.
- **Kasus batas** (`/tmp/rv060/r2-edge.R`, `/tmp/rv060/sep.R`,
  `/tmp/rv060/sep2.R`); hasilnya di R19.
- **Uji, *lint*, dan gaya.**
  - Seluruh rangkaian dengan `NOT_CRAN=true`: 0 gagal, 0 galat, 2 dilewati
    (`/tmp/rv060/r2-fulltest.log`). Uji e2e di rangkaian ini memakai paket
    yang terpasang di *site-library*; hasil 168 PASS dari koordinator tidak
    saya ulang secara terpisah.
  - `lintr` bersih pada semua berkas R dan uji yang berubah; tidak ada baris
    di atas 80 karakter.
- **Catatan di luar cakupan.** `/home/claude/rcli-gh` saat ini memiliki
  perubahan belum di-*commit* pada `R/methods-show.R` (3+, 2−) yang bukan
  bagian dari a38aba0 dan bukan dari peninjau. Perubahan itu tidak diperiksa.

## Temuan putaran 2

Temuan putaran 1:

- [x] [R1] Selesai pada 1400 px (sisa kecil pada 1024 px di R24).
- [x] [R2] Selesai: hasil identik, waktu loop setara dengan 0.5.1.
- [x] [R3] Selesai: AC dirumuskan ulang dengan alasan, data memenuhinya, dan
  uji ditambahkan.
- [x] [R4], [R5], [R6], [R7], [R9], [R10], [R11], [R12], [R15] Selesai.
- [x] [R8] Dikerjakan, tetapi caranya menimbulkan R19.
- [x] [R13] Dikerjakan; sisa dokumentasi di R21.
- [x] [R14] Dikerjakan sebagian; lihat R20.
- [x] [R16], [R17] Diterima apa adanya.
- [x] [R18] Diterima apa adanya (arsiran jendela ditunda).

Temuan baru:

- [x] [R19][minor] R/validation.R:recursive_logit — Prakiraan dari fit yang
  tidak konvergen kini dibuang (`!isTRUE(fit$converged)`).
  - Pada sampel pendek, ketidakkonvergenan hampir selalu berarti separasi
    (kuasi-)sempurna di sampel latih awal. Prakiraannya ekstrem (≈ 0 atau 1)
    dan sering salah, sehingga membuangnya memilih titik evaluasi
    berdasarkan keadaan model. Akibatnya penilaian menjadi optimistis.
  - Bukti, dari `sep.R` (aturan lama dibanding dengan filter konvergensi):

    | Sampel | n | QPS | AUC |
    |---|---|---|---|
    | 8 tahun seed 3, CLI h = 6 | 52 → 45 | 0,455 → 0,259 | 0,729 → 0,901 |
    | 8 tahun seed 6, CLI h = 6 | 52 → 47 | 0,51 → 0,35 | 0,68 → 0,84 |
    | 8 tahun seed 3, CCI h = 0 | 55 → 39 | | |

  - `sep2.R`: sekitar 16% sampel bulanan 8 tahun terkena; tidak ada yang
    terkena pada 15–20 tahun, baik bulanan maupun triwulanan. Dampaknya
    terbatas pada sampel pendek, tetapi justru di sana kartu skor paling
    perlu jujur.
  - Usul: pakai prakiraan selama berhingga, walau tidak konvergen (prakiraan
    ekstrem tetap prakiraan yang sah dari prosedur itu). Pilihan lain:
    gantikan dengan prakiraan naif atau fit berpenalti, lalu catat jumlah
    fit yang tidak konvergen sebagai informasi. Sesuaikan F-07 §5.
    (Saran "periksa `fit$converged`" di R8 putaran 1 memang mengundang
    perubahan ini; maksudnya mencatat, bukan membuang.)
- [x] [R20][nit] R/assessment.R:concordance (roxygen) — Tindak lanjut R14
  menyebut batas 1e-4 dicantumkan di `?concordance`. Kenyataannya batas itu
  hanya ada di `?cli_quality` dan NEWS (`grep "1e-4"` pada `R/` dan `man/`).
  Tambahkan satu kalimat di `@return` `concordance()`.
- [x] [R21][nit] harness/01-requirements.md:AC-FR-012.1, R/assessment.R:cli_assess,
  R/methods-show.R — Dokumentasi nilai "none" belum lengkap.
  - AC-FR-012.1 masih menulis `sign_source` bernilai "meta" atau "data";
    nilai "none" baru disebut di AC .2.
  - `?cli_assess` tidak menyebut ketiga nilainya.
  - `print(LeadAssessment)` tidak menandai arah yang tidak tentu.
- [x] [R22][nit] R/methods-show.R:classifier_lines("OecdClassifier") — Baris
  kesesuaian yang dicetak panjangnya sekitar 118 karakter, sehingga terlipat
  di konsol 80 kolom. Pecah menjadi dua baris seperti pada
  `RcliClassifier`.
- [x] [R23][nit] tests/testthat/test-evaluation-060.R — AC-FR-012.8 kini
  menyatakan label palsu pada siklus independen terpangkas paling sedikit
  separuh. Namun uji hanya memeriksa `lead-window.csv` `false_leading ≤ 0,1`
  tanpa pembanding 0.5.1. Pembandingnya tersedia di kolom
  `noise_called_leading` `oecd-classification.csv` (0,04–0,065 dibanding
  0,265–0,44); tambahkan asersi separuhnya.
- [x] [R24][nit] R/app.R (langkah 2, 1024 px) — Pemilih tipe dan frekuensi
  (lebar 2, sama dengan 0.5.1) masih memotong "(belum diisi)" atau
  "(not given)", dan panah "Direction: automatic" menumpuk huruf terakhir
  (`r2-step2-en-1024.png`). Ini bukan regresi dan masih dapat dipakai.
- [x] [R25][nit] R/assessment.R:cli_assess — Dengan `is_inverted()`, siklus
  yang sudah dibalik kini masuk ke `@inverted` dan bertanda
  `inverted = TRUE`, juga di jalur data. Di 0.5.1 tidak demikian.
  - Pemanggil yang memakai pola `for (nm in a@inverted) invert_cycle()` atas
    siklus yang sama akan membalik dua kali.
  - Semua pemanggil di paket memakai siklus segar (`build.R`,
    `coincident.R`, `selection-bias.R`, `app.R`), jadi saat ini tidak ada
    kesalahan.
  - Usul: sebut di dokumentasi `LeadAssessment` bahwa `inverted` berarti
    "dibalik relatif terhadap seri asli".

## Keputusan putaran 2

Semua temuan major putaran 1 (R1, R2, dan R3) selesai dan terverifikasi.
Hasil `cli_build()` dan `cci_build()` identik dengan 8d45ba7, sedangkan waktu
loop kembali setara dengan 0.5.1. Tidak ada temuan blocker atau major baru.
R19 sebaiknya diperbaiki sebelum rilis karena memengaruhi kejujuran kartu
skor pada sampel pendek. Perbaikannya kecil dan tidak mengubah hasil pada
sampel 15 tahun ke atas. R20–R25 bersifat kosmetik atau dokumentasi.

Putusan: APPROVE

## Tindak lanjut putaran 2
- R19: prakiraan berhingga dari fit yang tidak konvergen tetap dipakai (F-07 §5 diperbarui).
- R20: batas 1e-4 di `@return` `concordance()`.
- R21: nilai "none" di AC-FR-012.1 dan `?cli_assess`; `print()` menandai arah tak terbaca dengan `?`.
- R22: baris kesesuaian di `print()` spesifikasi dipecah dua (juga baris horizon di `print()` validasi).
- R23: uji AC .8 membandingkan `noise_called_leading` dengan aturan median saja (paling banyak separuh).
- R24: bukan regresi; dibiarkan.
- R25: `?LeadAssessment`: `inverted` relatif terhadap seri asli.

