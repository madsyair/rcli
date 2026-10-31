# 06 — Review

- Increment: rcli 0.5.0 (FR-010)
- Reviewer: A6 (konteks bersih: ya)
- Putaran: 1 terhadap 0db13de (basis 986d2ea, 0.4.0 di main)
- Review 0.4.0 tersimpan di riwayat git berkas ini (komit 3b87683).

## Yang diperiksa (putaran 1)
- `test-app-options.R` lolos (90 harapan); lintr bersih; tidak ada baris
  lebih dari 80 karakter; kunci `app_text` sama di kedua bahasa; tujuh
  kunci baru `app_phrases_id` dipakai di `plot_presentation()`.
- Injeksi lewat `pair_text`, `parse_cutoffs`, isian angka, `target_freq`,
  nama seri acuan dan indikator (nilai string): aman.
- Format angka (`1e-04`, `1e+05`, negatif, NA) menghasilkan teks yang
  terbaca ulang; GUI dan skrip memakai teks yang sama.
- Idulfitri, pilihan penanggal menurut frekuensi, persistensi isian
  penyelarasan, dan mode manual `cli_presentation(res, composite = cli)`:
  benar.

## Temuan putaran 1
- [x] [R1][blocker] R/app-options.R `align_text` — `deparse()` tidak
  meloloskan tanda kutip di dalam nama vektor; nama seri dari nama berkas
  unggahan atau tajuk kolom dapat menjalankan kode R di server pada
  langkah 2 (didemonstrasikan dengan berkas yang menulis berkas lain).
- [x] [R2][major] app-options.R `align_ui` — indikator Chow–Lin hanya dapat
  dipilih dari kandidat, padahal `?cli_align` melarang indikator menjadi
  kandidat; kandidat pendahulu menjadi sejalan semu.
- [x] [R3][major] R/app-plots.R — seri acuan tanpa tren digambar sebagai
  `100 * reference / trend`; untuk seri acuan tanpa log yang trennya
  mendekati nol, grafik meledak (−2 427 sampai 38 685).
- [x] [R4][minor] R/presentation.R — `trend_restored` multiplikatif juga
  untuk seri acuan tanpa log; tren negatif membalik siklus.
- [x] [R5][minor] tests — skrip dievaluasi di lingkungan yang dapat
  menjangkau fungsi internal; tidak ada bukti skrip berjalan hanya dengan
  `library(rcli)`.
- [x] [R6][nit] app-options.R `value_text` — isian angka dari peramban
  bertipe integer, sehingga skrip menulis `5L`.
- [x] [R7][nit] Isian ambang pencilan tetap tampil saat TRAMO dipilih;
  pilihan disagregasi tampil walaupun seri acuan tidak diubah.
- [x] [R8][nit] R/app.R — sisa baris kosong ganda.

Putusan putaran 1: CHANGES-REQUESTED

## Tindak lanjut A5 sesudah putaran 1
- R1: `chr_text()` menulis vektor karakter dengan `encodeString()`; nama
  tak sintaktis lewat `stats::setNames()`; teks diuji terbaca ulang identik
  sebelum dipakai, kalau tidak `rcli_error_argument`. Dipakai untuk tipe,
  seri acuan, metode, indikator, dan nama berkas di skrip. Uji "R1" memakai
  nama berkas injeksi dari review.
- R2: seri indikator Chow–Lin dikeluarkan dari kandidat
  (`series[names(series) != "x"]`) dan dari metadata; teks bantuan
  menjelaskannya.
- R3: `cli_presentation()` mendapat kolom `reference_amplitude_adjusted`
  dalam satuan CLI disesuaikan amplitudo; grafik memakai kolom itu.
- R4: untuk seri acuan tanpa log, simpangan diukur dalam persen rata-rata
  level absolut (sama dengan amplitudo komposit) dan tren dipulihkan
  secara aditif. Uji "R3/R4".
- R5: uji memeriksa bahwa setiap fungsi paket yang dipanggil teks kode
  termasuk ekspor.
- R6: angka ditulis sebagai double.
- R7: ambang pencilan disembunyikan saat TRAMO; pilihan disagregasi dan
  indikator hanya tampil (dan hanya dipakai) bila seri acuan diubah
  frekuensinya.
- R8: baris kosong dirapikan.
- Bukti merah: uji baru gagal 12 kali pada 0db13de (7 di
  `test-app-options.R`, 5 di `test-oecd.R`).
