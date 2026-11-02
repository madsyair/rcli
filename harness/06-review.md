# 06 — Review

- Increment: rcli 0.6.0 (FR-012)
- Reviewer: A6 (konteks bersih: ya)
- Putaran: 1 (terhadap 8d45ba7; basis c950f03, 0.5.1 di main)
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
