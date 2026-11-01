# 06 — Review

- Increment: rcli 0.5.0 (FR-010)
- Reviewer: A6 (konteks bersih: ya)
- Putaran: 3 (putaran 1 terhadap 0db13de, putaran 2 terhadap b7c4820,
  putaran 3 terhadap 72f7aed; basis 986d2ea, 0.4.0 di main)
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

## Review putaran 2 (b7c4820)
- R1–R8 tertutup, masing-masing diverifikasi dengan kode. `chr_text()`
  diuji dengan nama berkas, tajuk kolom, `align_indicator`, `align_method`,
  `reference`, `ref_type`, `week_date`, dan berbagai pengodean di locale C
  dan C.UTF-8: tidak ada injeksi; kasus yang tidak dapat ditulis aman
  ditolak.
- `cli_presentation()`: satuan simpangan seri acuan tanpa log sama dengan
  amplitudo komposit (rasio MAD 1,16 untuk seri ber-log maupun tanpa log).
- Uji: `test-app-options` 112, `test-oecd` 83, `test-app-multi` 51,
  `test-app` 131, `test-app-reference` 33; tanpa kegagalan.

### Temuan baru putaran 2
- [x] [R9][blocker] R/app-options.R `given()`, `value_text()`, `transform`
  — pesan websocket buatan dapat mengirim daftar bernama sebagai isian
  angka atau pilihan; `deparse()` tidak meloloskan nama daftar, sehingga
  kode R dijalankan di server saat langkah 3 atau 2 (didemonstrasikan lewat
  `min_lead`, `transform`, `alpha`, `ar_h`, `hp_trend_period`,
  `align_coverage`).
- [x] [R10][major] R/app.R — nama seri acuan disisipkan ke skrip ekspor
  tanpa diloloskan (sudah ada sejak 0.4.0); tajuk kolom buatan menjalankan
  kode saat skrip dijalankan pengguna.
- [x] [R11][nit] Isian ambang pencilan tetap tampil di mode OECD.
- [x] [R12][nit] `chr_text()` menulis nama non-ASCII tanpa kutip; skrip
  tidak berjalan di sesi non-UTF-8; byte tak sah memberi galat bukan
  `rcli_error_*`.
- [x] [R13][nit] Pemeriksaan bolak-balik `chr_text()` mengevaluasi di
  `baseenv()`.

Putusan putaran 2: CHANGES-REQUESTED

## Tindak lanjut A5 sesudah putaran 2
Perbaikan dua lapis:
- Lapis 1, validasi isian: `given()` hanya menerima satu nilai atomik;
  `value_text()` hanya meloloskan satu angka berhingga dan menulisnya
  sebagai double; isian pilihan (`filter`, `aggregator`, `transform`,
  `align_method`) dicocokkan dengan daftar pilihan (`choice_key()`,
  `choice_text()`); `pair_text()` dan `align_indicator` menolak nilai
  bukan teks tunggal. Isian yang tidak sah → `rcli_error_argument`, dan
  langkahnya tidak selesai.
- Lapis 2, daftar putih di `eval_code()`: sebelum dijalankan, setiap nama
  dalam kode harus fungsi ekspor rcli, salah satu `code_names` (`<-`, `c`,
  `[`, `!=`, `names`, `stats::setNames`, …), atau objek yang diberikan;
  selain itu kode ditolak tanpa dijalankan.
- R10: seri acuan, komponen, dan komponen indeks sejalan di skrip ditulis
  dengan `chr_text()`.
- R11: ambang pencilan hanya tampil untuk metode rcli tanpa TRAMO.
- R12: nama tanpa kutip hanya untuk nama ASCII; kegagalan pengodean →
  `rcli_error_argument`.
- R13: bolak-balik dievaluasi di lingkungan yang hanya berisi `c` dan
  `::`.
- Uji "R9" (daftar bernama dan string injeksi untuk delapan isian langkah
  3 dan tiga isian langkah 2, serta daftar putih) dan "R10/R12" (skrip
  dengan nama seri acuan injeksi dievaluasi; komposit sama dengan GUI).
- Bukti merah: uji baru gagal 14 kali pada b7c4820 (termasuk kode yang
  dijalankan lewat daftar bernama dan skrip dengan nama seri acuan
  injeksi); semuanya lolos sesudah perbaikan.

## Review putaran 3 (72f7aed)
- Uji: `test-app-options` 141, `test-app` 131, `test-app-multi` 51,
  `test-app-reference` 33, `test-app-csv` 78, `test-app-frequency` 13;
  tanpa kegagalan; lintr bersih.
- R9–R13 tertutup. Lapis 1 diserang dengan daftar, daftar bernama,
  vektor, NULL, NA, Inf, string berkutip dan bergaris miring terbalik,
  angka sebagai string, dan nilai logika; lapis 2 dengan `stats::system`,
  `base::system`, `rcli::`, `:::`, `"system"(...)`, `function`, `[[`, dan
  penimpaan `setNames`: semuanya ditolak, tanpa berkas penanda.
- Tanpa regresi: isian integer, isian lanjutan kosong, transformasi log,
  data triwulanan, metode OECD dengan titik potong, Chow–Lin, rantai
  indeks sejalan sebagai acuan.

### Temuan baru putaran 3
- [x] [R14][minor] Batas atas isian angka hanya di peramban; `ar_h = 1e9`
  dari pesan buatan meminta 7,5 GB memori.
- [x] [R15][minor] Daftar putih `eval_code()` memuat semua fungsi ekspor
  (termasuk `read_cli_data()`, `run_app()`) dan `numeric`.
- [x] [R16][nit] Isian langkah 2 yang bukan satu string (pesan buatan)
  menghentikan sesi.
- [x] [R17][nit] Lingkungan bolak-balik `chr_text()` masih memuat `::`.
- [x] [R18][nit] `parse_cutoffs()` memberi `simpleError` untuk NULL atau
  daftar.
- Catatan di luar increment: pesan buatan dapat mengisi `datapath` isian
  berkas dengan jalur sembarang; perlu dipertimbangkan bila aplikasi
  di-hosting untuk umum.

Putusan: APPROVE

## Tindak lanjut A5 sesudah putaran 3
- R14: `input_limits` memberi batas sisi server untuk setiap isian angka;
  di luar batas → `rcli_error_argument`.
- R15: daftar putih per pemanggil (`spec_functions`, `align_functions`);
  `numeric` dihapus dari `code_names`; titik potong kosong tidak ditulis.
- R16: `one_text()` memperlakukan isian yang bukan satu string sebagai
  kosong.
- R17: nama dalam teks bolak-balik diperiksa sebelum dievaluasi.
- R18: `parse_cutoffs()` menerima NULL sebagai kosong dan menolak selain
  satu string dengan `rcli_error_argument`.
- Uji "R14/R16/R18" dan tambahan di "R9".
