# Review INC-13 (0.7.0), putaran 1

- Increment: rcli 0.7.0 (FR-013; F-08, F-09; ADR-003)
- Reviewer: A6 (konteks bersih: ya)
- Basis: 285b331 (0.6.0 di main), cabang `rcli-0.7.0`, pohon kerja belum
  dikomit (diff + berkas baru `R/classes-form.R`,
  `tests/testthat/test-cycle-form.R`, `data-raw/calibrate_forms.R`,
  `harness/02-math/F-08.md`, `F-09.md`, `harness/adr/ADR-003.md`,
  `inst/calibration/forms.csv`). Selama review, `vignettes/rcli.Rmd` ikut
  berubah di pohon kerja; bagian vinyet di bawah dinilai pada keadaan
  terakhir yang terbaca.
- Skrip probe: di direktori scratchpad sesi (`compat.R`, `probe1.R` sampai
  `probe5.R`), tidak di repo.

## Yang diperiksa

- **F-08 terhadap kode, baris demi baris.** `growth_rate()` memberi
  100 (z_t − z_{t−k}) untuk seri ber-log dan z_t − z_{t−k} untuk seri tanpa
  log, dengan NA pada t ≤ k. Percepatan adalah `growth_rate(g, 1, FALSE)`,
  dengan NA pada t ≤ k + 1. `lag = NA` menjadi frekuensi. Penanda `logged`
  dibaca dari `steps` ("log" dan "log (regARIMA log/level test)" cocok;
  "levels ..." tidak). Hasilnya sesuai F-08. Identitas pergeseran fase
  (butir 4) dan gain ½ F-09 diperiksa ulang dan benar.
- **`cycle_one()`.** Urutannya SA → transformasi → pencilan → bentuk →
  perpanjangan → filter. Prakiraan TRAMO dibentuk bersama inti, sehingga
  laju di ujung memakai nilai inti; ini diperiksa dengan `oecd_spec(form =)`
  dan `tramo_outliers()`. `drop` menghitung NA awal, lalu `span[1]` digeser.
  Probe (`probe2.R`) memakai acuan penuh, kandidat yang mulai terlambat
  30 bulan, kandidat dengan ujung kasar 6 bulan, dan kandidat dengan celah
  di tengah 4 bulan. Pola NA `transformed` dan `cycle` sama persis dengan
  perhitungan tangan, dan selisih maksimumnya 0. Seri tanpa log yang
  melintasi nol memberi selisih biasa. Batasnya juga benar: 4 tahun dengan
  laju tahunan lolos (36 observasi); `growth_form(200)` gagal dengan
  `rcli_error_short_series`.
- **Kompatibilitas mundur** (`compat.R`, dibandingkan dengan salinan HEAD
  0.6.0). Untuk spesifikasi bawaan, siklus `cli_cycles()` dan indeks komposit
  `cli_build()` *identik* dengan 0.6.0, dan jalur TRAMO juga identik. Objek
  `CliSpec` 0.6.0 tanpa slot `form` memberi siklus yang identik;
  `update()` mengisi `level_form()`, sedangkan `show` dan `cli_presentation()`
  tetap berjalan.
- **Penolakan Conference Board.** `cli_spec(form = acceleration_form(),
  aggregator = conference_board())` dan `update()` keduanya memberi
  `rcli_error_argument`; lihat R-13.5 untuk celahnya.
- **Seluruh alur** (`probe4.R`): `cli_build()`, validasi, `cci_build()`, dan
  `cli_presentation()` dijalankan untuk laju tahunan, percepatan, dan laju
  antarperiode, bulanan dan triwulanan. Semuanya berjalan tanpa galat.
  (Laju m-to-m bulanan tidak menghasilkan komposit pada seed 5; ini sesuai
  label eksperimental dan bukan cacat.)
- **AC-FR-013.6 bulanan** (`probe5.R`, tidak ada di uji). Pada 10 ulangan,
  lead_6 berada dalam ±1 bulan pada bentuk laju 10/10 dan percepatan 8/10.
- **GUI.** `choice_key()` menjaga `form` dan `growth_lag`. `form_text()`
  hanya menulis `growth_form()`/`acceleration_form(lag = 1)`; keduanya sudah
  masuk daftar putih `spec_functions`, dan `level_form` tidak perlu masuk.
  Kunci teks baru ada di kedua bahasa. Uji pemalsuan `"growth; system('x')"`
  ditolak.
- **Gaya dan paket.** Tidak ada baris > 80 karakter; `lintr::lint()` bersih
  untuk semua berkas yang berubah; Imports tidak bertambah; `roxygenise()`
  pada salinan tidak mengubah `man/` dan `NAMESPACE`.
- **Uji.** `test-cycle-form.R` 61 PASS dan `test-app-options.R` semua PASS.
  `R CMD check` tidak dijalankan reviewer; itu tugas gerbang A0.

## Temuan

### R-13.1 — blocker — `cli_presentation()` salah satuan pada bentuk laju dan percepatan
- [ ] Lokasi: `R/presentation.R:83-98` (cabang tanpa log),
  `R/aggregate.R:350`, `R/app-plots.R:268-290`.
- Uraian: `is_logged()` kini FALSE untuk bentuk laju/percepatan, sehingga
  presentasi masuk ke cabang "seri tanpa log". Cabang itu menganggap
  amplitudo komposit dinyatakan dalam *persen dari rata-rata level*
  (`100 * mad / mean|level|`). Padahal untuk bentuk baru
  `reference_amplitude()` mengembalikan amplitudo dalam *poin persen*
  (`mad` saja). Akibatnya ada dua kolom yang skalanya keliru:
  - `trend_restored = tren + (amp_adj − 100)/100 × scale` mengecil dengan
    faktor `scale/100`;
  - `reference_amplitude_adjusted = 100 + 100 (orig − tren)/scale` membesar
    dengan faktor `100/scale`.
- Skenario (`probe1.R`, `simulate_cycles(seed = 1)`, `growth_form()`):
  - simpangan baku `amplitude_adjusted − 100` = 5,61, sedangkan
    `reference_amplitude_adjusted − 100` = 105,8 (skalanya beda 19 kali);
  - `trend_restored − reference_trend` = 0,30, sedangkan
    `reference − reference_trend` = 5,62.
  - Kedua seri dalam satu panel GUI "Bentuk penyajian OECD" dan CSV unduhan
    tidak dapat dibandingkan.
  - Selain itu, `rate_of_change` dan `reference_rate_of_change` menjadi
    "laju dari laju". Bila semua laju positif (misalnya PDB ≈ 5%),
    `rate_of_change()` menghitung `100 (g_t/g_{t−12} − 1)`, yaitu perubahan
    persen dari laju, yang tidak bermakna. Label plot ("level of the
    reference series", "rate of change over a year (%)") juga keliru.
  - Uji AC-FR-013.5 hanya memeriksa nama kolom (`test-cycle-form.R:145`),
    sehingga cacat ini lolos.
- Saran (pilih satu):
  1. Untuk `form_units(ref) != "level"`, tolak `cli_presentation()` dengan
     `rcli_error_argument` ("bentuk penyajian OECD didefinisikan untuk
     siklus pertumbuhan"), lalu sembunyikan atau nonaktifkan panel penyajian
     di GUI.
  2. Definisikan presentasi aditif dalam poin persen: `tr = tren + (amp_adj
     − 100)`, `ref_amp = 100 + (orig − tren)`, dan `rate_of_change = NA`
     (atau hapus kolomnya). Label plot juga perlu disesuaikan.

  Pilihan mana pun perlu uji numerik, misalnya simpangan baku kedua kolom
  amplitudo sebanding.

### R-13.2 — major — Bentuk nilai dengan `hp_smoother()` diterima tanpa peringatan; `update()` menghasilkan kombinasi itu
- [ ] Lokasi: `R/spec.R:327-351` (`update`), `R/spec.R:124`, `R/app.R:232`
  (pilihan filter), `R/app.R:1136-1139` (observer).
- Uraian: `hp_smoother()` tidak membuang tren. Bila dipasangkan dengan
  `level_form()`, "siklus" yang dihasilkan adalah log level yang dihaluskan.
- Skenario:
  - `cli_cycles(cand, cli_spec(filter = hp_smoother()))$reference@cycle`
    berada di rentang 4,58–5,27, yaitu tren log (`probe3.R`).
  - Bry-Boschan lalu menanggali tren, normalisasi membagi tren, dan
    klasifikasi memakai siklus yang tidak bermakna, tanpa satu pun
    peringatan.
  - Jalan termudah ke kombinasi ini:
    `update(cli_spec(form = growth_form()), form = level_form())`. Filter
    tetap `hp_smoother()` (diverifikasi: label "HP smoother").
  - Di GUI, pengguna dapat memilih "HP smoother" pada bentuk nilai.
  - Dokumentasi `@param form` memang menyuruh memberi `filter` saat
    `update()`, tetapi kegagalan diam seperti ini termasuk kasus tepi yang
    tidak ditangani.
- Saran:
  - Di `cli_spec()`/`update()`, keluarkan `rcli_warn()` (kelas
    `rcli_warning_form_filter`) bila bentuknya `LevelForm` dan filternya
    tidak membuang tren. Pemeriksaan ini sebaiknya lewat generic, misalnya
    `detrends(filter)` atau `check_filter(form, filter)`, bukan cabang
    kelas.
  - Selain itu, di `update()`, bila `form` diganti tanpa `filter` dan filter
    lama sama dengan `default_filter(form lama)`, ganti filter dengan
    `default_filter(form baru)`. Perilaku ini perlu didokumentasikan.

### R-13.3 — major — AC-FR-013.8 belum terpenuhi: NEWS memuat placeholder, dan beberapa dokumen menyesatkan
- [ ] Lokasi: `NEWS.md:29` (`RESULTS_PLACEHOLDER`), `R/cycles.R:3-9`
  (`?cli_cycles`), `R/classes-core.R:93-94` (`@slot transformed`),
  `R/presentation.R:1-50` (`?cli_presentation`), `vignettes/rcli.Rmd`
  (§8: "`cli_presentation()` returns the three OECD forms of any composite").
- Uraian:
  - NEWS akan terbit dengan teks `RESULTS_PLACEHOLDER`.
  - `?cli_cycles` masih menyebut urutan langkah tanpa langkah bentuk.
  - `?CycleSeries-class` menyebut `transformed` sebagai "Series after
    transformation ...", padahal pada bentuk baru slot itu berisi laju atau
    percepatan, dengan NA tambahan di awal.
  - `?cli_presentation` dan vinyet menyatakan bahwa presentasi berlaku untuk
    komposit apa pun (lihat R-13.1).
  - Pedoman (`pedoman/`) tidak ada di repo ini, sehingga bagian AC-FR-013.8
    itu tidak dapat diverifikasi.
  - `inst/calibration/forms.csv` dibaca vinyet tetapi belum terlacak git.
    Bila lupa dikomit, vinyet gagal dibangun.
- Saran: isi ringkasan hasil simulasi di NEWS dan perbarui
  `?cli_cycles`, `@slot transformed`, dan `?cli_presentation` (sesuai
  keputusan R-13.1). Komit `forms.csv` dan catat status pedoman di STATE.

### R-13.4 — minor — `show(CliSpec)` tidak menampilkan bentuk siklus
- [ ] Lokasi: `R/methods-show.R:56-90`.
- Skenario: `print(cli_spec(form = acceleration_form()))` hanya menampilkan
  "filter: HP smoother". Bentuk, lag, dan status eksperimental tidak terlihat.
  `oecd_spec(form = growth_form())` tercetak persis seperti `oecd_spec()`,
  padahal siklusnya laju (dan dipasangkan dengan HP ganda, karena
  `oecd_spec()` mengunci filter). Spesifikasi yang disimpan lalu dicetak
  ulang menyembunyikan pilihan yang paling menentukan satuan hasil.
- Saran: tambahkan baris `form:` saat bentuknya bukan nilai, misalnya
  `"  form:        annual growth rate (experimental)"`, lewat generic
  (`form_step()`/label) dan snapshot di `_snaps/`.

### R-13.5 — minor — Penolakan Conference Board berupa cabang kelas di inti dan dapat dilewati
- [ ] Lokasi: `R/spec.R:256-262`, `R/aggregate.R:286`.
- Uraian: validitas `CliSpec` memakai `!is(form, "LevelForm") &&
  is(aggregator, "ConferenceBoard")`. Ini cabang kelas di inti, yang
  bertentangan dengan semangat aturan proyek "Never add `if (class == ...)`
  branches in the core". Selain itu, penjaga hanya memeriksa spesifikasi,
  bukan siklus. Skenario (`probe3.R`):
  `cli_composite(cli_cycles(cand, cli_spec(form = growth_form())),
  c("lead_6", "lead_3"), cli_spec(aggregator = conference_board()), ...)`
  berjalan dan menghitung perubahan simetris dari laju pertumbuhan.
  `form_units()` juga menurunkan satuan dari teks `steps` lewat regex, yang
  rapuh bila teks langkah berubah.
- Saran: tambahkan generic `supports_form(aggregator, form)` (bawaan TRUE,
  FALSE untuk `ConferenceBoard` × bukan nilai) yang dipanggil di validitas.
  Di metode `aggregate_components()` Conference Board, periksa satuan
  komponen (misalnya atribut `"units"` pada `levels` yang diisi
  `cli_composite()` dari `form_units()`).

### R-13.6 — minor — Celah uji (mutasi yang tidak tertangkap)
- [ ] Lokasi: `tests/testthat/test-cycle-form.R`.
  - (a) Baris 88-91: AC-FR-013.3 meminta hasil "sama persis dengan 0.6.0",
    tetapi uji membandingkan dua jalur 0.7.0 (`form = NULL` dan
    `level_form()`). Regresi pada jalur nilai, misalnya `window()` yang
    mengubah `tsp`, tidak akan tertangkap. Reviewer sudah memverifikasi
    keidentikan secara manual. Saran: berkas golden siklus 0.6.0 (RDS di
    `tests/testthat/fixtures`, dibuat dari tag 0.6.0).
  - (b) Baris 143-147: presentasi hanya diperiksa nama kolomnya (lihat
    R-13.1).
  - (c) Jalur prakiraan TRAMO + bentuk tidak diuji. Mutasi yang menghapus
    `fc <- utils::tail(as.numeric(whole), length(fc))` (`R/cycles.R:94`)
    akan menyambung laju dengan prakiraan log level dan tidak tertangkap.
  - (d) Batas `keep < 3L * spec@freq` (`R/cycles.R:87`) tidak diuji tepat di
    3f dan 3f − 1; mutasi `<` → `<=` lolos.
  - (e) Observer GUI yang mengganti filter (`R/app.R:1136`) tidak diuji.
  - (f) AC-FR-013.6 menyebut bulanan dan triwulanan, tetapi uji hanya
    triwulanan. Hasil probe bulanan lolos (lihat di atas).
- Saran: tambahkan uji (a)–(f). Untuk (e), bila `testServer` tidak dapat
  mengamati `updateSelectInput`, pindahkan logikanya ke fungsi murni
  (`filter_for_form(form)`) dan uji fungsi itu.

### R-13.7 — minor — Teks GUI: "Penghalus HP" tidak ada di daftar filter; observer menimpa pilihan pengguna
- [ ] Lokasi: `R/app-text.R:99-101`, `R/app.R:232-237`, `R/app.R:1136-1139`.
- Uraian:
  - Bantuan berbahasa Indonesia meminta "pilih Penghalus HP sebagai
    penyaring", padahal daftar filter hanya berlabel Inggris "HP smoother
    (no detrending)". AC-FR-013.7 menyebut filter "Penghalus HP".
  - Observer juga mengganti filter pada *setiap* perubahan bentuk, termasuk
    laju → percepatan, sehingga pilihan filter pengguna (misalnya CF)
    tertimpa diam-diam.
- Saran: buat label filter mengikuti bahasa (atau samakan teks bantuan
  dengan label daftar). Observer cukup mengganti filter saat melintasi batas
  nilai ↔ bukan nilai, atau saat filter yang sedang dipakai adalah
  `default_filter` bentuk sebelumnya.

### R-13.8 — minor — Simulasi menunjukkan pangsa pendahulu palsu di atas 1,5% untuk bentuk baru, tetapi tidak disebut di dokumen
- [ ] Lokasi: `inst/calibration/forms.csv`, `R/classes-form.R:29-33`.
- Uraian: `false_leading` = 0,025 (percepatan, bulanan, bising 0,8) dan
  0,017 (laju, triwulanan, bising 0,8). Keduanya di atas sasaran 1,5% yang
  dipakai untuk bawaan (AC-NFR-003.1). Label eksperimental memang ada,
  tetapi angka ini adalah alasan konkretnya.
- Saran: sebutkan angka itu di NEWS (pengganti placeholder) dan di
  `?CycleForm-class`.

### R-13.9 — nit — Nilai λ(12) di F-09 salah
- [ ] Lokasi: `harness/02-math/F-09.md:9`.
- Uraian: tertulis λ(12) ≈ 10,4, padahal `hp_lambda(12)` =
  [4(1 − cos(π/6))²]⁻¹ = 13,93. Kodenya benar; hanya catatan MVR yang
  salah.
- Saran: ganti dengan 13,93.

### R-13.10 — nit — Label satuan untuk seri tanpa log
- [ ] Lokasi: `R/classes-form.R:19-20`, `R/classes-form.R:147-159`.
- Uraian: dokumentasi menyebut percepatan "in percentage points", dan
  `steps` mencatat "annual growth rate" juga untuk seri tanpa log. Padahal
  hasilnya selisih dalam satuan asli (misalnya poin indeks), bukan laju.
- Saran: tulis "percentage points for logged series, otherwise the units of
  the series". Untuk seri tanpa log, pakai teks langkah "form: annual
  difference" dan sesuaikan regex `form_units()`.

## Ringkasan

| ID | Tingkat | Ringkas |
|---|---|---|
| R-13.1 | blocker | `cli_presentation()` salah satuan pada bentuk laju/percepatan (beda skala ~19×; laju dari laju) |
| R-13.2 | major | Bentuk nilai + `hp_smoother()` diam-diam menghasilkan tren sebagai siklus; `update(form = level_form())` membawa ke sana |
| R-13.3 | major | NEWS berisi `RESULTS_PLACEHOLDER`; `?cli_cycles`, `@slot transformed`, `?cli_presentation`, dan vinyet belum sesuai; `forms.csv` belum terlacak |
| R-13.4 | minor | `show(CliSpec)` tidak menampilkan bentuk |
| R-13.5 | minor | Penolakan CB berupa cabang kelas di validitas dan dapat dilewati lewat `cli_composite()` |
| R-13.6 | minor | Celah uji: golden 0.6.0, presentasi, prakiraan TRAMO, batas 3f, observer, bulanan |
| R-13.7 | minor | "Penghalus HP" tidak ada di daftar; observer menimpa filter pilihan pengguna |
| R-13.8 | minor | `false_leading` 1,7–2,5% pada bentuk baru tidak disebut di dokumen |
| R-13.9 | nit | λ(12) di F-09 salah (10,4 → 13,93) |
| R-13.10 | nit | Label "growth rate"/"percentage points" untuk seri tanpa log |

Putaran berikut: A5 menindaklanjuti R-13.1 sampai R-13.3 (wajib) dan
sebaiknya R-13.4 sampai R-13.10; reviewer memverifikasi ulang.

Putusan: CHANGES-REQUESTED

---

## Tindak lanjut A5 (2026-11-11)

| ID | Tindakan |
|---|---|
| R-13.1 | `cli_presentation()` untuk bentuk laju/percepatan memakai `rate_presentation()`: komposit di sekitar rata-rata laju acuan dalam poin persentase, kolom laju perubahan `NA`. Uji satuan baru di AC-FR-013.5 (kolom setara, rasio simpangan baku 0,2–5). |
| R-13.2 | Generic internal `removes_trend()` (`HPSmoother` = FALSE); `cli_spec()` dan `update()` memberi peringatan `rcli_warning_form_filter` untuk bentuk level + penyaring tanpa pembuangan tren. `update(form = )` memindahkan penyaring bawaan bentuk lama ke bawaan bentuk baru dan mempertahankan pilihan manual. |
| R-13.3 | NEWS terisi hasil `forms.csv`; dokumentasi `cli_cycles`, slot `transformed`, `cli_presentation`, `cli_spec` diperbarui; `forms.csv` ikut dikomit. Buku pedoman ada di luar repo (folder kerja maintainer) dan sudah diperbarui di sana (bab 3, 11, 12, A, B). |
| R-13.4 | `show()` mencetak baris `form:` untuk bentuk bukan level; snapshot level tidak berubah. |
| R-13.5 | Pemeriksaan kelas diganti generic `form_kind()` dan `needs_levels()`; `cli_composite()` juga menolak siklus bukan level dengan agregator yang memerlukan level. |
| R-13.6 | Berkas emas `fixtures/level-0.6.0.rds` dibuat dari komit 285b331 (`data-raw/make_level_060.R`); uji siklus, kelas, dan indeks bulanan dan triwulanan identik. Uji baru: penyajian, prakiraan TRAMO + bentuk, batas tiga tahun, observer GUI. |
| R-13.7 | Teks Indonesia menyebut "HP smoother" sesuai label pilihan; observer hanya mengganti penyaring bawaan bentuk lain (uji dengan `local_mocked_bindings`). |
| R-13.8 | NEWS dan buku pedoman menyebut 1,7–2,5 persen pendahulu palsu pada sel paling bising, di atas target 1,5 persen. |
| R-13.9 | F-09: λ(12) ≈ 13,93. |
| R-13.10 | Langkah seri tanpa log bertuliskan "annual difference"/"difference over k periods"; `form_units()` membaca awalan "form:". |

Gerbang sesudah tindak lanjut: uji paket hijau, lint 0 temuan, cakupan 95,7%, `R CMD check --as-cran` 0 ERROR, 0 WARNING, 3 NOTE (lingkungan: *new submission*/URL 403 lewat proxy, waktu, `JAVA_TOOL_OPTIONS`).

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

