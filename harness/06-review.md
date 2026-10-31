# 06 — Review

- Increment: rcli 0.4.0 (FR-009)
- Reviewer: A6 (konteks bersih: ya)
- Putaran: 2 (putaran 1 terhadap 0fd867f, putaran 2 terhadap 38984f2;
  basis 1b66e30, 0.3.1 di main)
- Review 0.3.1 tersimpan di riwayat git berkas ini (komit a1a433b).

## Yang diperiksa (putaran 1)
- `test-read-series.R` 58/58 dan `test-app-multi.R` 38/38 lolos; lintr
  bersih; `roxygenise()` tidak mengubah apa pun; contoh
  `read_cli_series()` 3,2 detik.
- Skrip ekspor jalur triwulanan dievaluasi: data kandidat dan indeks
  komposit sama persis dengan GUI.
- Perubahan `complete_meta()` aman bagi pengguna lama: bawaan yang
  dipakai adalah NA kecuali `cli_align()` mencatat sesuatu; frekuensi di
  `meta` yang bertentangan tetap ditolak.
- Rantai indeks sejalan sebagai acuan, seri basi sesudah muat ulang,
  nama unggahan dan `datapath`, kunci teks dua bahasa, kunci
  `app_phrases_id` baru, `shiny::`, tanpa Imports baru, NEWS: tanpa
  masalah.

## Temuan putaran 1
- [x] [R1][major] R/read-series.R — kolom `value` yang diberi nama berkas
  menimpa kolom lain bernama sama (`gdp_sa.csv` dengan `date,value,gdp_sa`
  menghasilkan satu seri); pemeriksaan duplikat tidak pernah aktif; tajuk
  ganda `a,a` diam-diam menjadi `a`, `a.1`.
- [x] [R2][minor] read-series.R — kolom angka tanpa tajuk menjadi seri
  bernama `""`, lalu `cli_align()` gagal dengan pesan yang tidak menyebut
  berkas.
- [x] [R3][minor] R/app.R — tipe seri acuan terbawa saat seri acuan
  diganti, sehingga seri acuan baru dikonversi dengan tipe yang keliru.
- [x] [R4][minor] app.R — `target_freq` hanya dibaca di langkah 1;
  mengubahnya sesudah itu tidak berpengaruh walaupun pilihan berubah.
- [x] [R5][minor] app.R — isian frekuensi asal di mode beberapa berkas
  dapat diubah, tetapi setiap perubahan pasti gagal, dan pilihan pengguna
  ditimpa saat panel digambar ulang.
- [x] [R6][minor] read-series.R — tanda nilai hilang di tabel terbitan
  (`-`, `..`, `...`, `#N/A`) membuang seluruh kolom.
- [x] [R7][nit] read-series.R — seri tidak diurutkan menurut tanggal.
- [x] [R8][nit] read-series.R — kolom tanggal kosong dan seri satu
  observasi memberi pesan yang tidak menyebut berkas.
- [x] [R9][nit] read-series.R — bentuk tanggal yang diterima lebih luas
  dari dokumentasi; tanggal-waktu Excel tengah malam ditolak.
- [x] [R10][minor] tests — uji untuk R1–R4, `multi_lines()` dengan
  `sep`/`dec`, dan evaluasi skrip triwulanan belum ada.

Putusan putaran 1: CHANGES-REQUESTED

## Tindak lanjut A5 sesudah putaran 1
- R1: nama diambil dari tajuk berkas (`names(df)[-1]`), bukan dari
  `df[-1]`; nama ganda di antara kolom angka satu berkas adalah galat
  yang menyebut berkas dan nama. Uji "R1/R2".
- R2: kolom angka tanpa tajuk adalah galat yang menyebut berkas; kolom
  kosong akibat pemisah di akhir baris tetap diabaikan.
- R3: tipe seri acuan hanya dipertahankan selama seri acuannya sama
  (`ref_type_for`). Uji "R3/R10".
- R4: mengubah frekuensi analisis sesudah berkas dibaca mengosongkan
  langkah 2 dan seterusnya, memperbarui `rv$loaded$frequency`, dan
  menyesuaikan ambang *lead*.
- R5: di mode beberapa berkas, frekuensi asal ditampilkan sebagai teks
  (`frq_text_i`) dan diisi dari deteksi di metadata.
- R6: argumen baru `na` dengan bawaan `NA`, `-`, `..`, `...`, `#N/A`.
- R7: setiap seri diurutkan menurut tanggal.
- R8: kolom tanggal tanpa isi (`rcli_error_dates`) dan seri dengan kurang
  dari dua observasi (`rcli_error_argument`) menyebut berkas; kelas galat
  didokumentasikan di `@return`.
- R9: dokumentasi menyebut semua pemisah yang diterima dan bahwa tanggal
  dibaca hari lebih dulu; akhiran `00:00` atau `00:00:00` diabaikan; jam
  lain tetap ditolak.
- R10: uji ditambahkan; uji triwulanan kini mengevaluasi skrip dan
  membandingkan data kandidat dan indeks komposit.
- Bukti merah: uji baru dijalankan pada kode 0fd867f: 9 kegagalan (3 di
  `test-read-series.R`, 6 di `test-app-multi.R`); semuanya lolos sesudah
  perbaikan.

## Review putaran 2 (38984f2)
- Uji: `test-read-series` 77/77, `test-app-multi` 48/48,
  `test-app-frequency` 13/13, `test-app-reference` 33/33, `test-app-csv`
  78/78; lintr bersih.
- R1–R10 tertutup, masing-masing diverifikasi dengan kode: nama ganda dan
  kolom tanpa tajuk ditolak; tipe seri acuan dikosongkan saat acuan
  diganti; mengganti frekuensi analisis mengosongkan langkah 2 dan skrip
  tetap mereproduksi GUI; frekuensi asal tampil sebagai teks; tanda nilai
  hilang tidak mengganggu deteksi desimal; urutan tanggal; pesan galat
  menyebut berkas; tanggal-waktu tengah malam.
- Jalur indeks sejalan sebagai acuan dengan beberapa berkas: skrip ekspor
  dievaluasi tanpa galat, indeks komposit dan `meta` sama dengan GUI.

### Temuan baru putaran 2
- [x] [R11][minor] read-series.R `series_dates` — tanggal bulan/hari/tahun
  (ekspor Excel en-US) terbaca sebagai hari 1–12 Januari dan dikenali
  harian tanpa galat; `cli_align()` lalu menghasilkan hampir semua NA.
- [x] [R12][nit] app.R — sesudah indeks sejalan menjadi acuan, mengubah
  frekuensi analisis tidak berpengaruh, tetapi pilihannya berubah.
- [x] [R13][nit] read-series.R — seri satu observasi menggagalkan seluruh
  berkas, sedangkan kolom kosong hanya dibuang dengan peringatan.
- [x] [R14][nit] read-series.R — jam tengah malam satu digit (`0:00`)
  tidak dibuang; `na` tidak divalidasi.
- [x] [R15][nit] app.R — tipe seri acuan terbawa ke berkas baru dengan
  nama seri acuan yang sama.

Putusan: APPROVE

## Tindak lanjut A5 sesudah putaran 2
- R11: tanggal hari-bulan-tahun yang menghasilkan deret hari berjarak
  lebih dari sebulan ditolak (`rcli_error_dates`) dengan saran format
  ISO; data harian sungguhan tetap diterima.
- R12: pilihan frekuensi analisis dikembalikan ke nilai yang dipakai.
- R13: seri dengan kurang dari dua observasi dibuang dengan
  `rcli_warning_dropped`; galat hanya bila tidak ada seri yang tersisa.
- R14: pola `[ T]0?0:00(:00)?$`; `na` harus character.
- R15: `ref_type_for` dikosongkan di langkah 1.
- Uji "R11/R13/R14" dan tambahan di `test-app-multi.R`; pada 38984f2
  uji-uji itu gagal 3 kali.
