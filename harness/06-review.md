# 06 — Review

- Increment: rcli 0.2.0 (FR-001–FR-003)
- Reviewer: A6 (konteks bersih: ya)
- Putaran: 1
- Keadaan yang direview: pohon kerja `/home/claude/rcli` pada 23-10-2026
  pukul 15.10–15.25 WIB (`git diff` terhadap a3b8181 ditambah berkas yang
  belum dilacak). Selama review, pohon kerja masih diubah agen lain
  (NEWS, vinyet, `pedoman/`, `inst/calibration/`, `test-ragged-edge.R`).
  Temuan di bawah merujuk ke keadaan terakhir yang saya baca.

## Yang diperiksa
- Kebenaran: `chain_ragged_edge()` (R/aggregate.R:40-55) sama baris demi
  baris dengan F-01 rev. 2 §1 dan §7 (q dengan toleransi 1e-9, b = baris
  lengkap terakhir, syarat |B_t| ≥ q, rantai berhenti tanpa dimulai ulang).
  `extend_series("ArExtension")` sesuai F-02 §7.
- Kesetaraan dengan 0.1.3, diuji sendiri dan independen dari uji paket:
  `git archive HEAD` (0.1.3) dibandingkan dengan pohon kerja memakai
  `cli_spec(aggregator = equal_weight(ragged_edge = "level"),
  extension = no_extension())`. Hasilnya, `cli_build()` pada
  `sim_candidates(seed = 1:4)` dan satu kasus ujung compang-camping memberi
  komponen yang sama dan siklus komposit identik (selisih maksimum 0).
  AC-FR-003.4 terpenuhi.
- Uji: `devtools::test()` lengkap: 0 gagal, 0 galat, 1 dilewati (seasonal).
  Filter `ragged-edge|end-extension`: 352 lulus.
- Mutasi (salinan di direktori sementara, filter
  `ragged-edge|end-extension`): mati 9 dari 11. Daftarnya: rantai dimulai
  ulang dari L, q dihitung dari |A_t|, cadangan `spec_extension()` diganti
  AR, AR didahulukan atas TRAMO, toleransi q dihapus (dengan uji D2 yang
  baru), `cumsum` prakiraan dihapus, b = baris lengkap pertama, dan h bawaan
  dikunci 12. **Bertahan**: (M1) cadangan `.hasSlot` pada `EqualWeight`
  diganti `"chain"`; (M9) drift `mean(d)` diganti 0; (M6) `order_max`
  diabaikan.
- Kalibrasi (selesai pukul ±15.20): `false_leading` maksimum 0,013 ≤ 0,015
  (AC-NFR-003.1 terpenuhi untuk angka ini).
- `roxygen2::roxygenise()` pada salinan: `man/` dan `NAMESPACE` sinkron
  dengan sumber.

## Temuan
- [x] [R1][blocker] tests/testthat/test-ragged-edge.R:96 — Uji AC-FR-001.7
  tidak menguji objek 0.1.x. `new("EqualWeight", label = ..., min_coverage
  = 0.6)` mendapat slot `ragged_edge = "level"` dari prototipe, sehingga
  cabang `methods::.hasSlot()` di R/aggregate.R:23-27 tidak pernah
  dijalankan. Mutan yang mengganti cadangan `"level"` dengan `"chain"`
  tetap lulus (M1). Kodenya sendiri benar: setelah
  `attr(o, "ragged_edge") <- NULL` hasilnya 0; 1,333; 2,5 (level), bukan
  2,333 (chain). Saran: hapus atributnya di uji
  (`attr(old_obj, "ragged_edge") <- NULL`), pastikan
  `expect_false(methods::.hasSlot(old_obj, "ragged_edge"))`, lalu
  bandingkan dengan hasil level dan pastikan berbeda dari hasil chain
  untuk z yang sama.
- [x] [R2][major] R/spec.R:24 (dan man/cli_spec.Rd:48) — `@param
  aggregator` menyatakan bawaan "chains the average growth of the
  components". Sejak F-01 rev. 2, yang dirantai adalah rata-rata
  *perubahan* siklus ternormalisasi, bukan laju pertumbuhan, jadi
  dokumentasi ini menyesatkan. `@param ragged_edge` di
  R/classes-aggregator.R:58-61 sudah diperbaiki. Saran: samakan
  rumusannya ("adds the average change of the components to the previous
  value at the ragged edge") lalu jalankan roxygen.
- [x] [R3][major] harness/01-requirements.md:17 dan harness/adr/ADR-001.md:1,12
  — AC-FR-001.1 masih memakai bentuk revisi 1:
  `cycle[1:3] = 100 + rowMeans(z)` dan `cycle[4] = cycle[3] × (103/102)`.
  Rumus ini bertentangan dengan F-01 rev. 2 dan dengan uji yang
  mengklaim menelusurinya (test-ragged-edge.R:9-14 memeriksa
  `h[4] = h[3] + 1` tanpa +100). ADR-001 juga masih berjudul "Rantai laju
  pertumbuhan" dan merujuk "Akibat 4", padahal sekarang Akibat 3. Jejak
  FR → F → uji jadi tidak konsisten. Saran: perbarui AC-FR-001.1
  (H_{1:3} = rowMeans, H_4 = H_3 + 1, toleransi 1e-12), judul dan
  konsekuensi ADR-001, serta label Proposisi.
- [x] [R4][major] tests/testthat/test-end-extension.R:42-44 dan :4-8 —
  AC-FR-002.6 ("prakiraan garis lurus dengan rerata perubahan") tidak
  benar-benar teruji. Uji memakai `rep(2, 30)` dengan rerata perubahan 0,
  sehingga mutan drift `last + 0 * seq_len(h)` lulus (M9). Uji tren
  linear AC-FR-002.1 (`0.01 * (1:120)`) tidak lewat cabang drift karena
  `var(diff(x)) = 8,9e-34 > 0`. Seri itu diproses `stats::ar()` pada
  derau pembulatan dan lulus hanya karena simpangannya sangat kecil. Ini
  bertentangan dengan klaim F-02 §1 dan §3.3 ("varians nol → p = 0").
  Cabang drift juga merupakan cadangan saat `ar()` gagal
  (R/classes-extension.R:109-118), jadi jalur ini memikul perilaku nyata.
  Saran: (a) uji dengan kemiringan yang representasinya eksak, mis.
  `ts(0.25 * (1:120), frequency = 12)`, yang memberi var(d) = 0 dan hasil
  harus `x_n + 0.25 * (1:h)`; (b) uji cadangan saat `ar()` gagal atau
  memberi nilai tak berhingga; (c) pertimbangkan ambang relatif, mis.
  `var(d) <= (sqrt(.Machine$double.eps) * max(abs(d)))^2`, lalu
  perbarui F-02 §1/§3 sesuai perilaku sebenarnya.
- [x] [R5][major] vignettes/rcli.Rmd:270-272 — Chunk `realtime-defaults`
  membaca `inst/calibration/realtime-defaults.csv`, yang tidak ada (pukul
  15.25). `data-raw/realtime_defaults.R` belum dijalankan dan tidak
  termasuk perintah kalibrasi yang sedang berjalan. Akibatnya
  `read.csv("")` galat, vinyet gagal dibangun, dan `R CMD check` gagal
  (bertentangan dengan AC-NFR-003.2). Di R/classes-extension.R:17-20,
  dokumentasi juga mengutip "vignette, section 8 … 18 to 23 percent, as
  much as X-13 regARIMA forecasts", padahal skrip waktu-nyata yang
  dikirim tidak memuat varian X-13. Klaim itu tidak dapat direproduksi
  dari artefak paket. Saran: jalankan skrip, sertakan CSV-nya, lalu
  samakan angka di vinyet, NEWS, dan `?Extension-class` dengan CSV itu.
  Bila tidak, tambahkan varian X-13 ke skrip atau hapus klaim tersebut.
- [x] [R6][minor] R/cycles.R:80 — Langkah audit memakai teks tetap
  `"AR forecasts"` untuk setiap subkelas `Extension`. Padahal dokumentasi
  `Extension` mengundang pengguna menambah strategi baru, dan strategi
  buatan pengguna akan tercatat sebagai "AR forecasts". Pengetahuan
  tentang strategi tertentu bocor ke inti. Saran: pakai
  `spec_extension(spec)@label`, atau generic kecil untuk teks langkah;
  sesuaikan uji AC-FR-002.4 dan snapshot.
- [x] [R7][minor] R/spec.R:278 — `update()` pada spesifikasi 0.1.x
  (tanpa slot `extension`) gagal di `validObject()` dengan pesan "slots in
  class definition but not in object: extension". Akibatnya NEWS.md:29
  ("Objects saved with 0.1.x keep their old behaviour") tidak sepenuhnya
  benar. `cli_build()` dengan objek lama tetap berjalan. Polanya sudah ada
  sejak 0.1.3, tetapi increment ini menambah slot baru. Saran: di
  `update()`, isi slot yang hilang dengan nilai yang sesuai dengan
  perilaku lama (`no_extension()`, dst.) sebelum `validObject()`, dan
  tambahkan ujinya.
- [x] [R8][minor] R/classes-extension.R:32-34,111-112 — Dokumentasi
  menyatakan bahwa `order_max = NULL` berarti frekuensi data, dibatasi
  10 log10(n) "as in stats::ar()". Kode berbeda dalam tiga hal: batas itu
  juga dikenakan pada nilai pengguna; n yang dipakai adalah n − 1
  (`length(d)`); dan ada batas `length(d) - 2` (= n − 3), sedangkan F-02
  §1 menulis n − 2. `order_max` juga praktis tidak teruji: uji AC-3
  memakai `order_max = 12` (= frekuensi), dan AIC tetap memilih orde 1,
  sehingga mutan yang mengabaikan `order_max` lulus (M6). Saran:
  samakan dokumentasi, F-02, dan kode, lalu tambahkan uji
  `order_max = 0`. Pada uji itu prakiraan perubahan harus sama dengan
  rerata d, dan berbeda dari prakiraan AR(1).
- [x] [R9][minor] R/classes-extension.R:103-110 — `extend_series()` adalah
  fungsi terekspor tanpa validasi masukan. Bila `x` memuat NA,
  `var(d)` bernilai NA dan `if (NA)` menghasilkan galat R mentah, bukan
  `rcli_abort()`. Bila `x` bukan `ts`, frekuensinya 1, sehingga h bawaan
  diam-diam menjadi 1. Saran: periksa `stats::is.ts(x)`, tidak ada NA, dan
  n ≥ 3, lalu gagal lewat `rcli_abort(..., "rcli_error_argument")`.
- [x] [R10][minor] tests/testthat/test-end-extension.R:92-107 — Uji
  AC-FR-003.4 membandingkan hasil dengan nilai yang dihitung ulang memakai
  `cli_cycles()` 0.2.0 dan `rowMeans`, bukan nilai dari 0.1.3. Uji ini
  tidak akan menangkap regresi di `cycle_one()`. Saya sudah memverifikasi
  kesetaraan bit demi bit secara terpisah (lihat "Yang diperiksa").
  Saran: simpan fixture emas dari 0.1.3, mis. komposit
  `sim_candidates(seed = 4)` di `tests/testthat/fixtures/`, dan
  bandingkan dengannya.
- [x] [R11][minor] tests/testthat/test-app.R:139-155 — AC-FR-003.3
  menuntut skrip ekspor mereproduksi komposit "untuk kombinasi apa pun".
  Indeks hanya dibandingkan untuk level + tanpa perpanjangan. Uji bawaan
  (chain + AR) di :124-131 hanya membandingkan daftar komponen, bukan
  indeksnya. Saran: parametrisasi uji atas keempat kombinasi
  `aggregator ∈ {equal, equal_level}` × `extend ∈ {TRUE, FALSE}` dan
  bandingkan `@index`.
- [x] [R12][minor] AC-NFR-002.1 — Belum ada bukti tertulis. Ukuran saya
  dilakukan saat kalibrasi berjalan bersamaan, jadi berderau: median
  `cycle_one()` 0,054 → 0,064 detik pada satu pengukuran (+19%) dan
  0,060 → 0,060 detik pada pengukuran berkelompok. `extend_series()`
  sendiri hanya ±2 ms; sisanya berasal dari penyaring pada n + 12. Saran:
  ukur tanpa beban dan catat hasilnya di harness atau gate report.
- [x] [R13][nit] tests/testthat/test-ragged-edge.R:12-13 — AC-FR-001.1
  menuntut toleransi 1e-12, sedangkan uji memakai toleransi bawaan
  `expect_equal` (±1,5e-8). Saran: `tolerance = 1e-12`.
- [x] [R14][nit] tests/testthat/test-end-extension.R:99 dan
  tests/testthat/test-app.R:139 — Panjang baris 81 karakter, melanggar
  aturan ≤ 80. `lintr::lint()` per berkas tidak menandainya, jadi periksa
  apakah `.lintr` benar-benar terbaca.
- [x] [R15][nit] R/app.R:121 — Label GUI "Equal weights, plain mean
  (rcli 0.1)" berbeda dari AC-FR-003.3 ("Equal weights, level at the edge
  (rcli 0.1)"). Saran: samakan AC atau label.
- [x] [R16][nit] R/methods-show.R:77 — Untuk `oecd_spec()`, `show()`
  mencetak "end: none", padahal seri tetap diperpanjang dengan prakiraan
  TRAMO. Saran: tulis mis. "none (forecasts of the outlier treatment are
  used)" bila perlakuan pencilan memberi prakiraan.
- [x] [R17][nit] harness/02-math/F-02.md §8 — Kotak centang belum diisi,
  padahal ujinya ada. harness/03-design.md merujuk `R/extension.R`, yang
  tidak ada (semuanya di `R/classes-extension.R`). R/classes-extension.R
  juga tidak punya komentar rujukan ke F-02, padahal R/aggregate.R
  merujuk F-01.
- [x] [R18][nit] tests/testthat/test-end-extension.R:83 —
  `cli_spec(extension = "ar")` menghasilkan galat `methods` generik, bukan
  `rcli_error_argument`. Polanya sama dengan `outliers` dan `classifier`.
  Uji ini juga tidak memeriksa kelas galat. Saran: validasi kelas di
  `cli_spec()` lewat `rcli_abort()` bila ingin konsisten dengan aturan
  proyek.

## Putusan
Satu blocker (R1: uji AC-FR-001.7 tidak menjalankan jalur kompatibilitas)
dan empat major (R2 dokumentasi menyesatkan, R3 AC/ADR tidak sesuai F-01
rev. 2, R4 cabang drift AC-FR-002.6 tidak teruji, R5 vinyet merujuk CSV
yang tidak ada sehingga check gagal). Inti numerik (F-01, F-02) benar dan
kesetaraan dengan 0.1.3 terverifikasi independen.

Putusan putaran 1: CHANGES-REQUESTED

## Tanggapan A5 (putaran 1 → 2)
- R1: uji menghapus atribut `ragged_edge`, memeriksa `.hasSlot` FALSE, dan memastikan hasil berbeda dari "chain" (`test-ragged-edge.R`, uji FR-001 AC-6/7).
- R2: `@param aggregator` di `R/spec.R` diperbarui (rata-rata perubahan); `man/cli_spec.Rd` dibuat ulang.
- R3: AC-FR-001.1/2/4 dan ADR-001 diperbarui ke F-01 revisi 2.
- R4: cabang garis lurus memakai ambang relatif `var(d) <= (sqrt(eps) * max|d|)^2`; uji kemiringan 0,25 (eksak) dan 0,01; uji cadangan lewat `ar_forecast()` yang di-mock (NULL dan Inf). F-02 §1, §3, §7 diperbarui.
- R5: `inst/calibration/realtime-defaults.csv` dibuat oleh `data-raw/realtime_defaults.R`; klaim X-13 dihapus dari `?Extension-class` dan NEWS (angka di dokumentasi paket kini dari CSV itu).
- R6: teks langkah memakai label strategi (`... forecasts: <label>`); untuk prakiraan pencilan "outlier treatment".
- R7: `update()` memanggil `upgrade_spec()` yang mengisi slot yang hilang dengan perilaku lama; diuji.
- R8: dokumentasi `order_max` disamakan dengan kode dan F-02; uji `order_max = 0` vs 1.
- R9: `extend_series()` memvalidasi `ts`, NA, dan n ≥ 3 lewat `rcli_abort`; diuji.
- R10: fixture emas `tests/testthat/fixtures/composite-0.1.3.rds` dihitung dengan kode 0.1.3 (git a3b8181); uji AC-FR-003.4 membandingkan indeks (toleransi 1e-12).
- R11: uji GUI atas 4 kombinasi agregasi × perpanjangan, membandingkan `@index`.
- R12: diukur tanpa beban: 0,0511 → 0,0593 detik per seri (+16%); AC-NFR-002.1 tidak terpenuhi seperti tertulis, dicatat sebagai penyimpangan di 01-requirements (penyebab: HP padat O(n³)).
- R13: toleransi 1e-12 pada AC-FR-001.1.
- R14: baris di berkas yang diubah ≤ 80 karakter (sisa >80 adalah berkas lama: test-app-e2e.R, test-quality.R, data-raw).
- R15: AC-FR-003.3 disamakan dengan label GUI.
- R16: `show()` mencetak "forecasts of the outlier treatment" bila perlakuan pencilan memberi prakiraan.
- R17: kotak F-02 §8 dicentang; jalur desain diperbaiki; komentar rujukan F-02 ditambahkan di kode.
- R18: `cli_spec()` memeriksa kelas `classifier`, `outliers`, `extension` lewat `rcli_abort`; diuji.

## Review putaran 2
- Reviewer: A6 (konteks bersih: ya). Keadaan: pohon kerja 23-10-2026
  (termasuk tambahan uji NFR-001/002/003 di akhir `test-end-extension.R`,
  cuplikan `_snaps/cycles.md` yang diterima, dan `04-test-plan.md`).
- Uji: filter `ragged-edge|end-extension|oecd|spec|cycles` 610 lulus,
  0 gagal, 1 dilewati; `test-app.R` 0 gagal (uji 4 kombinasi FR-003 AC-3:
  8 ekspektasi lulus). `lintr::lint_package()`: 0 temuan.
  `roxygen2::roxygenise()` pada salinan: `man/` dan `NAMESPACE` sinkron.
- Mutasi ulang (salinan di direktori sementara): M1 (cadangan `.hasSlot`
  → "chain") mati, 2 gagal; M9 (drift 0) mati, 5 gagal; M6 (abaikan
  `order_max`) mati, 2 gagal; M11 (`show()` tanpa teks prakiraan pencilan)
  mati; M12 (`upgrade_spec()` mengisi `ar_extension()`) mati. **Bertahan**:
  M10 (ambang relatif diganti `var(d) > 0`), lihat R19.
- Fixture emas diverifikasi independen: `git archive a3b8181` +
  `cli_build(sim_candidates(seed = 4), cli_spec(12))` memberi komponen
  identik dan selisih indeks maksimum 0 terhadap
  `fixtures/composite-0.1.3.rds`.
- Angka `realtime-defaults.csv` dicek: AR saja vs 0.1.x mengurangi revisi
  18,0–23,4% (cocok dengan "18 to 23 percent" di `?Extension-class` dan
  NEWS); arah benar rata-rata 72% → 80% (cocok dengan NEWS).

### Status temuan putaran 1
- R1 tertutup: atribut dihapus, `.hasSlot` FALSE diperiksa, hasil dibedakan
  dari "chain"; mutan M1 kini mati.
- R2 tertutup: `@param aggregator` memakai "average change"; Rd sinkron.
- R3 tertutup: AC-FR-001.1/2/4 dan ADR-001 sesuai F-01 rev. 2; label
  Proposisi di uji cocok dengan F-01. Sisa kecil di tabel formula, lihat R24.
- R4 tertutup: cabang garis lurus diuji dengan kemiringan 0,25 (eksak) dan
  cadangan `ar()` gagal/Inf lewat mock; mutan M9 mati. Ambang relatifnya
  sendiri belum terkunci uji (R19).
- R5 tertutup: CSV ada, dibuat skrip yang dikirim, dibaca vinyet §8; klaim
  X-13 dihapus; angka cocok dengan CSV.
- R6 tertutup: teks langkah memakai `ext@label` atau "outlier treatment";
  snapshot diperbarui.
- R7 tertutup: `upgrade_spec()` dipanggil di `update()`; saya uji juga
  spesifikasi tanpa lima slot baru dan dengan `EqualWeight` tanpa
  `ragged_edge`: `update()` berhasil, `show()` mencetak "end: none".
- R8 tertutup: dokumentasi, F-02 §1 dan kode sama (m = n − 1, batas
  ⌊10 log10 m⌋ dan m − 2); uji `order_max = 0` vs 1; mutan M6 mati.
- R9 tertutup untuk NA, non-`ts`, n < 3. Nilai tak berhingga belum (R22).
- R10 tertutup: fixture dari 0.1.3, diverifikasi independen (selisih 0).
- R11 tertutup: 4 kombinasi, `@index` dibandingkan, lulus.
- R12 tertutup sebagai temuan dokumentasi: hasil ukur tanpa beban dicatat
  di 01-requirements (+16%). AC-NFR-002.1 tetap tidak terpenuhi; keputusan
  menerima penyimpangan ada di tangan pengelola (R23).
- R13 tertutup: toleransi 1e-12.
- R14 tertutup: tidak ada baris > 80 di berkas yang diubah; lint bersih.
- R15 tertutup: AC-FR-003.3 sama dengan label GUI.
- R16 tertutup: `show(oecd_spec())` mencetak "forecasts of the outlier
  treatment"; `forecast = 0` mencetak label perpanjangan (konsisten dengan
  perilaku, tetapi lihat R20).
- R17 tertutup: F-02 §8 dicentang, jalur desain benar, komentar F-02 ada.
- R18 tertutup: `check_strategy()` untuk `classifier`, `outliers`,
  `extension` dengan `rcli_error_argument`; diuji.

### Temuan baru
- [x] [R20][major] R/classes-outliers.R:42-43 dan R/cycles.R:78-81 —
  Dokumentasi `tramo_outliers(forecast)` menyatakan "0 none", padahal sejak
  0.2.0 `forecast = 0` membuat `treat_outliers()` mengembalikan
  `numeric(0)`, sehingga `cycle_one()` beralih ke `spec@extension`
  (bawaan `ar_extension()`). Terverifikasi:
  `cli_spec(12, outliers = tramo_outliers(engine = "x13", forecast = 0))`
  memberi langkah "series extended by 12-period forecasts: AR forecasts of
  the changes, one year". Pengguna yang memakai `forecast = 0` untuk
  mematikan prakiraan (perilaku 0.1.3) kini diam-diam mendapat prakiraan AR.
  Saran: ubah `@param forecast` menjadi mis. "0: no forecasts from the
  outlier treatment; the specification's `extension` is used instead (use
  `no_extension()` for none)", sebut di NEWS sebagai perubahan perilaku,
  dan tambahkan uji (dengan `skip_if_not_installed("seasonal")`) yang
  memastikan `forecast = 0` + `no_extension()` tidak memperpanjang seri.
- [x] [R19][minor] R/classes-extension.R:119 — Ambang relatif
  `var(d) <= (sqrt(eps) * max|d|)^2` (perbaikan R4) tidak terkunci uji:
  mutan M10 (`var(d) > 0`) lulus semua uji, karena `ar()` pada derau
  pembulatan kemiringan 0,01 tetap memberi garis lurus dalam toleransi
  1e-10. Saran: pada uji kemiringan 0,01, mock `ar_forecast` agar
  mengembalikan nilai salah (mis. `rep(99, h)`) lalu pastikan hasil tetap
  `y[120] + 0.01 * (1:12)`; dengan begitu cabang yang diambil teruji.
- [x] [R21][minor] R/aggregate.R:86 dan :143 — Cadangan
  `principal_component()` dan `dynamic_factor()` memanggil
  `equal_weight(aggregator@min_coverage)`, yang kini merantai ujung seri.
  Perubahan ini tidak ada di 01-requirements maupun 03-design/ADR dan tidak
  diuji. NEWS.md menyebutnya, tetapi NEWS.md:31 juga menyatakan "Objects
  saved with 0.1.x keep their old behaviour"; untuk spesifikasi PCA/DFM
  0.1.x yang jatuh ke cadangan, hal itu tidak berlaku, dan resep "0.1.x
  exactly" tidak mencakup agregator ini. Saran: putuskan secara eksplisit
  (ADR atau catatan desain), tambahkan uji cadangan, dan perbaiki kalimat
  NEWS. Alternatif: pakai `ragged_edge = "level"` di cadangan.
- [x] [R22][minor] R/classes-extension.R:108 — Validasi memakai
  `anyNA(x)`, jadi `Inf` lolos. `extend_series(ar_extension(),
  ts(c(1, 2, Inf, 4, 5), frequency = 4))` menghasilkan galat R mentah
  "missing value where TRUE/FALSE needed" di baris 119. Saran:
  `all(is.finite(x))` dan pesan "finite values".
- [x] [R23][minor] tests/testthat/test-end-extension.R:156-162 — Uji
  "NFR-002" hanya mengukur `extend_series()` (< 0,05 detik per panggilan)
  dan tidak menguji AC-NFR-002.1 (≤ 10% pada `cli_cycles()`), yang menurut
  01-requirements tidak terpenuhi (+16%). Penerimaan penyimpangan ditulis
  oleh pelaksana, bukan pengelola. Saran: beri nama uji sesuai isinya (mis.
  "NFR-002 (proxy): extend_series is cheap"), dan minta persetujuan
  pengelola atas penyimpangan AC-NFR-002.1 di 08-release (atau ubah AC-nya).
- [x] [R24][nit] harness/01-requirements.md:30,54 dan
  R/classes-extension.R:21 — Tabel formula masih menulis F-01 sebagai
  "rantai laju pertumbuhan" (sisa R3). AC-FR-002.4 masih mengutip teks
  langkah lama "h-period AR forecasts", sedangkan sekarang "h-period
  forecasts: <label>". "At no noticeable cost in time" di
  `?Extension-class` sebaiknya selaras dengan +16% yang tercatat (mis.
  "about 8 ms per series"). Saran: samakan ketiganya.
- [x] [R25][nit] R/classes-aggregator.R:120-126 — `equal_weight(ragged_edge
  = c("level", "chain"))` diam-diam mengambil elemen pertama. Saran:
  `match.arg(ragged_edge)`, yang menolak vektor panjang > 1 yang bukan
  bawaan; pertahankan `rcli_abort()` untuk pesan galat.
- [x] [R26][nit] tests/testthat/fixtures/composite-0.1.3.rds — Asal-usul
  fixture hanya dicatat di komentar uji; tidak ada skrip untuk membuatnya
  ulang. Saran: tambahkan potongan di `data-raw/make_fixtures.R` (memuat
  `git archive a3b8181`, `cli_build(sim_candidates(seed = 4),
  cli_spec(12))`).

### Ringkasan
R1–R18 tertutup; kesetaraan dengan 0.1.3 dan inti numerik F-01/F-02 tetap
benar. Satu major baru (R20: `tramo_outliers(forecast = 0)` didokumentasikan
"none" tetapi kini memicu perpanjangan AR) dan empat minor (R19 ambang
relatif tidak terkunci uji, R21 cadangan PCA/DFM berubah tanpa keputusan,
R22 `Inf` tidak divalidasi, R23 uji NFR-002 tidak menguji AC dan
penyimpangan belum disetujui pengelola).

Putusan putaran 2: CHANGES-REQUESTED

## Tanggapan A5 (putaran 2 → 3)
- R19: uji kemiringan 0,01 me-mock `ar_forecast()` agar mengembalikan 99; hasil tetap garis lurus, jadi cabang ambang relatif teruji.
- R20: dokumentasi `forecast` di `tramo_outliers()` menjelaskan bahwa 0 berarti perpanjangan spesifikasi berlaku; NEWS mencatat perubahan perilaku ini.
- R21: keputusan dicatat di ADR-001 (tambahan) dan AC-FR-001.8; NEWS menyebutnya sebagai pengecualian kompatibilitas; uji `FR-001 AC-8`.
- R22: validasi `all(is.finite(x))`; uji dengan `Inf`.
- R23: uji dinamai "NFR-002 (proxy)"; penyimpangan AC-NFR-002.1 (+16%) dinaikkan ke pengelola untuk diputuskan (lihat 08-release.md).
- R24: tabel formula dan AC-FR-002.4 di 01-requirements diperbarui; `?Extension-class` menyebut biaya ±8 ms per seri.
- R25: `ragged_edge` vektor selain bawaan ditolak dengan `rcli_error_argument`; diuji.
- R26: resep pembuatan fixture 0.1.3 ditambahkan ke `data-raw/make_fixtures.R`.

## Review putaran 3
- Reviewer: A6 (konteks bersih: ya). Keadaan: pohon kerja 23-10-2026
  setelah "Tanggapan A5 (putaran 2 → 3)".
- Uji: `devtools::test(filter = "ragged-edge|end-extension|oecd")` 569
  lulus, 0 gagal, 0 dilewati. `lintr::lint_package()`: 0. `roxygenise()`
  pada salinan: `man/` dan `NAMESPACE` sinkron. Tidak ada baris > 80 di
  `R/` dan berkas uji yang diubah.
- Mutasi (salinan sementara): M10 (ambang relatif → `var(d) > 0`) kini
  mati (1 gagal); M13 (`is.finite` → `anyNA`) mati (1 galat); M14
  (cadangan PCA/DFM → "level") mati (2 gagal).

### Status temuan putaran 2
- R19 tertutup: uji kemiringan 0,01 me-mock `ar_forecast()` ke 99; hasil
  tetap garis lurus, jadi cabang ambang relatif teruji (M10 mati).
- R20 tertutup: `@param forecast` di `tramo_outliers()` kini menjelaskan
  bahwa 0 berarti perpanjangan spesifikasi berlaku (`no_extension()` untuk
  tanpa prakiraan); NEWS mencatat perubahan perilaku. Jalur kodenya
  (`length(fc) == 0` → `extend_series()`) sudah teruji lewat AC-4; uji
  khusus kombinasi `forecast = 0` belum ada (R27, nit).
- R21 tertutup: keputusan di ADR-001 (Tambahan) dan AC-FR-001.8; NEWS
  menyebut pengecualian kompatibilitas; uji AC-8 memakai z yang hasil
  "chain"-nya berbeda dari "level" (M14 mati).
- R22 tertutup: `all(is.finite(x))`, pesan "finite values", diuji
  dengan `Inf` (M13 mati).
- R23 tertutup sebagai temuan review: uji dinamai "NFR-002 (proxy)";
  penyimpangan AC-NFR-002.1 (+16%) tercatat di 01-requirements dan
  dinaikkan ke pengelola di 08-release ("Keputusan yang menunggu
  pengelola"). Keputusannya tetap menunggu pengelola sebelum rilis.
- R24 tertutup: tabel formula F-01 ("rata-rata perubahan; revisi 2"),
  AC-FR-002.4 (teks langkah dengan label), dan `?Extension-class` (±8 ms
  per seri) sudah selaras.
- R25 tertutup: vektor selain bawaan, termasuk `c("level", "chain")`,
  ditolak dengan `rcli_error_argument`; diuji.
- R26 tertutup: resep di `data-raw/make_fixtures.R` setara dengan
  `sim_candidates(seed = 4)` (helper-sim.R) dan dengan fixture yang sudah
  saya verifikasi bit demi bit di putaran 2.

### Temuan baru
- [ ] [R27][nit] tests/testthat/test-end-extension.R — Belum ada uji
  `cli_cycles()` dengan `tramo_outliers(forecast = 0)` yang memastikan
  perpanjangan spesifikasi dipakai (dan tidak dipakai dengan
  `no_extension()`), padahal perilaku ini kini dijanjikan di dokumentasi
  dan NEWS. Saran: tambahkan dua ekspektasi di uji AC-5 (dengan
  `skip_if_not_installed("seasonal")`).

### Ringkasan
Semua temuan R1–R26 tertutup; tidak ada blocker atau major terbuka. Satu
nit baru (R27). Penyimpangan AC-NFR-002.1 menunggu keputusan pengelola di
08-release sebelum rilis.

Putusan: APPROVE
