# 06 — Review

- Increment: rcli 0.3.1 (FR-008)
- Reviewer: A6 (konteks bersih: ya)
- Putaran: 2 (putaran 1 terhadap 4152863; putaran 2 terhadap 567153e)
- Keadaan yang direview: putaran 1 pada cabang `rcli-0.3.1`, HEAD 4152863,
  terhadap basis 595dba8 (0.3.0 di main). Komit yang dibaca:
  - 4152863: pemisah kolom dan tanda desimal berkas CSV unggahan di GUI
    (FR-008), versi 0.3.1.

  Putaran 2 pada cabang yang sama, HEAD 567153e; lihat bagian "Review
  putaran 2".

  Semua uji, mutasi, dan `R CMD check` dijalankan pada salinan
  `git archive` di direktori sementara. Uji peramban memakai pustaka
  sementara (`R CMD INSTALL -l <tmp>`, `R_LIBS`); pustaka sistem tidak
  disentuh. Kode paket dan uji di repositori tidak diubah.

## Yang diperiksa

### FR-008 (R/app.R, R/app-text.R)
- `csv_format(path, sep, dec)` (R/app.R:76-100) terhadap AC-FR-008.2:
  pemisah = yang paling sering muncul di antara koma, titik koma, dan tab
  pada baris judul (seri pertama menang bila seri: koma); tanda desimal
  koma bila pemisah bukan koma dan baris data pertama memuat
  `[0-9],[0-9]`; selain itu titik; pemisah = tanda desimal →
  `rcli_error_argument`. Kode sesuai AC kata demi kata. Masalahnya ada
  pada aturan itu sendiri (R1, R2) dan pada pembacaan baris (R3).
- `csv_choice()` (R/app.R:104-116): `NULL`/`"auto"` → `"auto"`; nama tak
  dikenal → `rcli_error_argument`. Benar.
- Isian `csv_sep`/`csv_dec` di UI: `shiny` hanya dipanggil sebagai
  `shiny::`; kedelapan kunci teks ada di `app_text$id` dan `app_text$en`.
  Kunci ini tidak dipakai di tabel atau grafik, jadi tidak perlu masuk
  `app_phrases_id`.
- Server langkah 1 hanya memanggil fungsi paket (`csv_format()`,
  `csv_choice()`, `read_cli_data()`); format disimpan di
  `rv$loaded$sep/dec` saat `run1`, sehingga pilihan yang diubah sesudahnya
  tidak mengubah skrip (diuji, dan saya periksa sendiri).
- `data_lines()`: `deparse_value("\t")` menulis `"\t"` di skrip; `sep`/`dec`
  hanya ditulis bila berbeda dari `","`/`"."`. Skrip menyertakan format
  juga di prelude, karena prelude dibuat lewat `app_script()`.
- `current_state()`: `reference` NULL bila `rv$cand` NULL, `lag_shift`
  FALSE bila `rv$spec` NULL. Hanya membuat fungsi aman dipanggil sebelum
  langkah 2/3; perilaku sesudah langkah 7 tidak berubah.
- Jalur data contoh (testServer): dengan `csv_sep = "comma"`,
  `csv_dec = "comma"` (pilihan kontradiktif), langkah 1 tetap selesai,
  `rv$loaded$sep` NULL, dan skrip menulis `simulate_cycles()`. Unggah
  `write.csv2()` lalu kembali ke contoh triwulanan: `sep`/`dec` hilang
  dari state dan skrip. Tidak ada kebocoran.
- NEWS.md, `@param ...` di `?read_cli_data`, dan DESCRIPTION 0.3.1 sesuai
  dengan perilaku kode. `man/` sinkron dengan roxygen.

### Kasus tepi `csv_format()` + `read_cli_data()` (jalur GUI persis)

| Kasus | Hasil `sep`/`dec` | Akibat |
|---|---|---|
| Koma, titik koma, tab berdesimal koma (berkas uji) | benar | data sama |
| Tab berdesimal titik | `"\t"`/`.` | benar |
| Titik koma, bilangan bulat saja | `;`/`.` | benar (tak ambigu untuk bilangan bulat) |
| Titik koma, satu baris data | `;`/`,` | benar, `ts` satu baris |
| CRLF (Windows) dan CR saja (Mac lama) | `;`/`,` | benar |
| BOM UTF-8, kolom pertama tanggal | `;`/`,` | benar (BOM ikut kolom tanggal yang dibuang) |
| BOM UTF-8, tanpa kolom tanggal | `;`/`,` | nilai benar, nama seri pertama `"﻿pdb"` (R5) |
| Kolom pertama numerik tanpa tanggal, `frequency`/`start` diberikan | benar (`;` dan `,`) | benar |
| Hanya judul / berkas kosong | — | galat terbaca ("No numeric column found" / "no lines available in input") |
| Titik koma, nama berkoma seri 2:2 (`PDB (ADHK, miliar)`) | **`,`/`.`** | galat menyesatkan "Dates must look like…" (R1) |
| Sama, tanpa kolom tanggal (2 koma : 1 titik koma) | **`,`/`.`** | **angka salah tanpa galat**: kolom `PDB (ADHK` = 100, 101, 102; `triliun)` = 1, 9, 5 (R1) |
| Koma, nama berkutip memuat 3 titik koma | **`;`** | galat "at least two columns" (R1) |
| Titik koma, baris data pertama kosong atau `NA` | **`;`/`.`** | galat "No numeric column found" (R2) |
| Titik koma, indeks basis 100 di baris pertama | **`;`/`.`** | galat "No numeric column found" (R2) |
| Titik koma, kolom cacah + kolom indeks, baris pertama bulat | **`;`/`.`** | **kolom indeks hilang tanpa pesan** (R2) |
| Tab, pemisah ribuan koma (`1,100.5`) | **`"\t"`/`,`** | galat "No numeric column found" (R2) |
| Titik koma, pemisah ribuan titik (`2.345,5`) | `;`/`,` | kolom `pdb` hilang tanpa pesan (R8) |
| Windows-1252 (byte 0x96/0xA0) di judul atau baris 2, lokal UTF-8 | — | **galat "input string 1 is invalid UTF-8"**, juga dengan pilihan eksplisit; 0.3.0 membaca berkas yang sama (R3) |

### Reproduksi skrip ekspor (testServer, langkah 1–7, `eval()` skrip)

| Berkas | Baris skrip | Data dan indeks skrip = GUI |
|---|---|---|
| `write.csv2()`, otomatis | `sep = ";", dec = ","` | ya |
| `write.csv2()`, eksplisit | `sep = ";", dec = ","` | ya |
| tab berdesimal koma, otomatis | `sep = "\t", dec = ","` | ya |
| tab berdesimal titik, otomatis | `sep = "\t", dec = "."` | ya |
| koma, otomatis | tanpa `sep`/`dec` | ya |
| `write.csv2()` dengan BOM | `sep = ";", dec = ","` | ya |
| `write.csv2()`, acuan bernama `PDB riil` | `sep = ";", dec = ","` | **tidak**: skrip membaca `PDB.riil` dan gagal (R4) |
| koma, acuan bernama `PDB riil` | tanpa `sep`/`dec` | **tidak** (sama; sudah ada sejak sebelum 0.3.1) |

### Gerbang yang dijalankan sendiri (HEAD 4152863)
- `devtools::test()` lengkap dengan `NOT_CRAN=true` dan pustaka sementara:
  `[ FAIL 0 | WARN 0 | SKIP 1 | PASS 1683 ]`; satu-satunya yang dilewati
  adalah uji `seasonal`, jadi uji peramban (termasuk unggahan
  `write.csv2()`) ikut berjalan di Chrome headless.
- `lintr::lint_package()`: 0 temuan.
- `roxygen2::roxygenise()`: `man/` dan `NAMESPACE` sinkron.
- Baris > 80 karakter di berkas yang diubah: hanya test-app-e2e.R:124-125
  (sudah ada sebelumnya).
- `R CMD build` + `R CMD check --as-cran --no-manual` (0.3.1): 0 galat,
  0 peringatan, 3 NOTE dari lingkungan (URL GitHub 403 lewat proksi,
  "unable to verify current time", `JAVA_TOOL_OPTIONS`), sama dengan
  review 0.3.0; contoh, `\donttest{}`, uji, dan vignette lolos.
- Mesin uji berlokal `C` (ASCII). Kasus R3 hanya muncul di lokal UTF-8
  (`LANG=C.UTF-8`), yaitu lokal bawaan R ≥ 4.2 di Windows, macOS, dan
  kebanyakan Linux.
- Mutasi (filter `app-csv`, baseline 36 lulus):

  | Mutan | Uraian | Status |
  |---|---|---|
  | M1 | desimal otomatis tanpa syarat `sep != ","` | mati (1 galat) |
  | M2 | desimal otomatis selalu titik | mati (12) |
  | M4 | pemeriksaan `sep == dec` dihapus | mati (1) |
  | M6 | `csv_choice()` selalu `"auto"` | mati (2) |
  | M9 | pilihan pemisah GUI diabaikan | mati (2) |
  | M10 | `rv$loaded$sep` dari isian, bukan hasil pengenalan | mati (3) |
  | M11 | `reference = reference()` tanpa pengaman | mati (2 galat) |
  | M12 | `lag_shift` tanpa pengaman `rv$spec` | mati (2 galat) |
  | M13 | urutan pemisah dibalik pada seri | mati (7) |
  | M8 | pilihan tanda desimal GUI diabaikan | **bertahan** (R6) |
  | M5 | `sep != "," \|\| dec != "."` → `&&` di `data_lines()` | **bertahan** (R6) |
  | M7 | peta `csv_choice()` tanpa `kind` (titik diterima sebagai pemisah) | **bertahan** (R6) |
  | M3 | faktor kehadiran `regexpr(...) > 0` dihapus | bertahan (R7) |
  | M14 | pemisah cadangan `";"` alih-alih `","` | bertahan (R7) |
  | M15 | baris kosong tidak dibuang | bertahan (R7) |

## Temuan
- [ ] [R1][major] R/app.R:84-91 (`csv_format()`, pengenalan pemisah) dan
  AC-FR-008.2 — Pemisah dipilih dari jumlah karakter di baris judul saja,
  tanpa memperhatikan kutip dan tanpa memeriksa baris data; bila seri,
  koma menang karena urutan `seps`. Judul berbahasa Indonesia dengan
  satuan sering memuat koma (`PDB (ADHK, miliar)`, `Kredit (Rp,
  triliun)`), dan Excel tidak mengutip nama yang memuat koma bila
  pemisahnya titik koma. Bukti:
  - judul `tanggal;PDB (ADHK, miliar);Kredit (Rp, triliun)` (2:2) → koma;
    langkah 1 gagal dengan "Dates must look like…", yang menyesatkan
    karena tanggalnya benar;
  - tanpa kolom tanggal (`frequency`/`start` diberikan), judul
    `PDB (ADHK, miliar);Kredit (Rp, triliun)` (2 koma : 1 titik koma) →
    koma; langkah 1 **selesai dengan angka salah**: seri `PDB (ADHK` =
    100, 101, 102 (bagian bulat) dan `triliun)` = 1, 9, 5 (bagian desimal
    seri kedua);
  - berkas koma dengan nama berkutip `"a;b;c;d"` → titik koma → galat.

  Saran: hitung jumlah kolom per baris dengan
  `utils::count.fields(textConnection(lines), sep = s, quote = "\"")`
  untuk judul dan baris data; pilih titik koma, lalu tab, bila jumlahnya
  sama di semua baris dan lebih dari 1; selain itu koma. Saya uji
  aturan ini pada keempat contoh di atas: semuanya benar (titik koma 3 3 3
  dan 2 2 2; koma untuk nama berkutip berisi titik koma dan untuk
  `tanggal,a;b,c`). Perbarui AC-FR-008.2 dan NEWS; tambahkan uji untuk
  ketiga contoh.
  - Perbaikan (A5, putaran 2): pemisah dikenali dengan `count.fields()` (tanda kutip dihormati): yang membagi setiap baris menjadi jumlah kolom sama dan terlebar; bila seri, tab, titik koma, lalu koma. Uji "R1" (nama kolom berkoma, bertanda kutip, dan berkas koma dengan titik koma di nama).
- [x] [R2][major] R/app.R:92-95 (`csv_format()`, tanda desimal) dan
  AC-FR-008.2 — Tanda desimal koma hanya dikenali bila **baris data
  pertama** memuat `1,5`. Data indikator sering diawali `NA`/sel kosong
  (seri mulai belakangan) atau nilai bulat (indeks dengan basis 100 pada
  periode pertama). Bukti (titik koma, semua bentuk Excel ID):
  - baris pertama `2001Q1;;` atau `2001Q1;NA;NA` → titik → "No numeric
    column found";
  - `2010-01;100;100`, sesudahnya `101,3;99,8` → titik → galat yang sama;
  - `tanggal;izin;ihk` dengan `2010-01;12;100`, sesudahnya `15;101,3` →
    titik → langkah 1 **selesai, kolom `ihk` hilang tanpa pesan**
    (`read_cli_data()` membuang kolom non-numerik);
  - kebalikannya: tab dengan pemisah ribuan koma (`1,100.5`) → koma →
    "No numeric column found".

  Saran: periksa semua baris yang sudah dibaca (lebih baik seluruh berkas
  atau beberapa ratus baris) per sel: koma bila ada sel
  `^[-+]?[0-9]+,[0-9]+$` dan tidak ada sel `^[-+]?[0-9]*\.[0-9]+$`; atau
  baca dengan kedua tanda desimal dan pilih yang menghasilkan lebih banyak
  kolom numerik (seri → titik). Perbarui kalimat AC-FR-008.2 dan NEWS
  ("the first data line"). Uji: baris pertama `NA`, kosong, dan basis
  100, termasuk kasus kolom yang hilang.
  - Perbaikan (A5, putaran 2): tanda desimal mengikuti mayoritas sel pecahan dari sampai 500 baris (`1,5`/`1.234,5` koma; `1.5`/`1,234.5` titik), bukan hanya baris pertama. Uji "R2" (baris kosong/NA/bulat di awal, berkas tab dengan koma ribuan).
- [x] [R3][major] R/app.R:82-83 dan 85-94 (`readLines()`, `trimws()`,
  `gregexpr()`, `grepl()`) — Regresi untuk berkas Windows-1252. Excel di
  Windows menyimpan "CSV (dipisahkan koma)" dalam kode halaman ANSI;
  karakter seperti en dash (0x96), spasi tak terputus (0xA0), atau `²`
  (0xB2) di judul atau baris data pertama bukan UTF-8 yang sah. Dalam
  lokal UTF-8 (bawaan R ≥ 4.2 di Windows, juga macOS dan Linux),
  `trimws()` dan fungsi regex lainnya berhenti dengan "input string 1 is
  invalid UTF-8". Langkah 1 gagal **juga dengan pilihan eksplisit**,
  karena `trimws()` selalu dijalankan. Di 0.3.0, `read_cli_data(f,
  check.names = FALSE)` membaca berkas yang sama tanpa masalah (saya uji
  dengan `LANG=C.UTF-8`). Uji paket tidak menangkapnya karena mesin uji
  berlokal `C`. Saran: `Encoding(lines) <- "bytes"` sesudah `readLines()`
  (saya periksa: `trimws`, `gregexpr`, dan `grepl` lalu berjalan dan
  hasilnya benar), atau `iconv(lines, "", "UTF-8", sub = "byte")`; lewati
  pembacaan baris bila kedua pilihan eksplisit. Uji dengan berkas yang
  memuat byte 0x96 di bawah `withr::local_locale(c(LC_CTYPE =
  "C.UTF-8"))`, dilewati bila lokal itu tidak tersedia.
  - Perbaikan (A5, putaran 2): semua pola dicocokkan dengan `useBytes = TRUE` dan sel dibaca sebagai teks; tanpa `trimws()` biasa. Uji "R3" dengan berkas Windows-1252, di lokal bawaan dan C.UTF-8.
- [x] [R4][major] R/app.R:488-505 (`data_lines()`) terhadap R/app.R:696,
  AC-FR-008.4 dan aturan CLAUDE.md "the exported R script must reproduce
  the composite built in the app" — GUI membaca dengan
  `check.names = FALSE`, sedangkan skrip memanggil `read_cli_data()` tanpa
  argumen itu. Nama kolom dengan spasi atau tanda baca, yang lazim di
  berkas Excel (`PDB riil`), menjadi `PDB.riil` di skrip, sehingga
  `cli_candidates(data, reference = "PDB riil")` gagal: "`reference` must
  name one column of `data`" (saya jalankan langkah 1–7 lalu `eval()`
  skrip, untuk berkas titik koma dan koma). Cacat ini sudah ada sebelum
  0.3.1, tetapi `data_lines()` baru ditulis untuk langkah 1, dan
  AC-FR-008.4 menyatakan skrip "mereproduksi data GUI". Uji AC-1/4 hanya
  membandingkan `as.numeric()`, jadi nama tidak pernah diperiksa. Saran:
  tulis `check.names = FALSE` di baris `read_cli_data()` skrip untuk
  unggahan (selalu, atau bila `make.names(nama) != nama`); di uji,
  bandingkan juga `colnames(env$data)` dengan `colnames(rv$data)`, dan
  tambahkan kasus dengan nama berspasi.
  - Perbaikan (A5, putaran 2): `data_lines()` menulis `check.names = FALSE` dan nama berkas lewat `deparse_value()`. Uji "R4" (nama kolom berspasi, skrip menghasilkan data identik; nama berkas bertanda kutip).
- [x] [R5][minor] R/app.R:691-697 dan `read_cli_data()` — BOM UTF-8
  (Excel "CSV UTF-8") tetap menempel pada nama kolom pertama. Bila kolom
  pertama adalah seri (tanpa kolom tanggal), nama seri menjadi
  `"﻿pdb"`: tampil seperti `pdb` di GUI, tetapi
  `cli_candidates(reference = "pdb")` di R gagal. Saran: buang `^﻿`
  dari nama kolom pertama di `read_cli_data()` (bukan lewat
  `fileEncoding = "UTF-8-BOM"`, karena itu akan merusak berkas
  Windows-1252 pada R3); uji tanpa kolom tanggal.
  - Perbaikan (A5, putaran 2): `read_cli_data()` membaca berkas ber-BOM dengan `fileEncoding = "UTF-8-BOM"` (kecuali pengguna memberi `fileEncoding`). Uji "R5".
- [x] [R6][minor] tests/testthat/test-app-csv.R:39-71 dan 86-97 — Tiga
  mutan bertahan:
  - M8 (pilihan tanda desimal GUI diabaikan): uji "eksplisit" memakai
    pilihan yang sama dengan hasil pengenalan otomatis, jadi tidak
    membuktikan bahwa pilihan dipakai. Uji AC-3 lulus karena alasan lain:
    bila `csv_dec` diabaikan, pemisah koma pada berkas titik koma
    menghasilkan satu kolom, sehingga `rv$data` tetap NULL tanpa galat
    `sep == dec`.
  - M5 (`||` → `&&` di `data_lines()`): tidak ada uji skrip untuk
    `sep = ";", dec = "."`; mutan itu menghapus `sep` dari skrip, dan
    skrip lalu membaca berkas dengan koma.
  - M7 (peta pilihan tanpa `kind`): `csv_choice("point", "sep")` diterima.

  Saran: (a) berkas titik koma dengan baris pertama bulat (kasus R2) dan
  `csv_dec = "comma"`, lalu periksa nilai desimalnya; (b) uji AC-3 dengan
  berkas berpemisah koma, sehingga hanya galat `sep == dec` yang dapat
  membuat langkah 1 gagal, atau periksa kelas galat lewat
  `csv_format()` dengan nilai dari `csv_choice()`; (c)
  `data_lines(list(source = "upload", sep = ";", dec = ".", ...))` memuat
  `sep = ";"`; (d) `expect_error(csv_choice("point", "sep"), class =
  "rcli_error_argument")`.
  - Perbaikan (A5, putaran 2): uji "R6": pilihan titik koma + titik dipakai dan masuk skrip; `csv_choice()` diuji langsung; uji AC-3 kini memakai berkas bilangan bulat yang akan terbaca tanpa pemeriksaan.
- [x] [R7][nit] R/app.R:85-90 dan tests/testthat/test-app-csv.R:18-29 —
  M3, M14, dan M15 bertahan: tidak ada uji dengan judul dua kolom (`t;a`,
  tempat faktor `regexpr(...) > 0` menentukan hasil), berkas tanpa
  pemisah, atau baris kosong sebelum judul. Hitungan
  `length(gregexpr(...)) * (regexpr(...) > 0)` juga sulit dibaca. Bila
  R1 diperbaiki dengan `count.fields()`, bagian ini hilang; bila tidak,
  pakai `lengths(regmatches(head, gregexpr(x, head, fixed = TRUE)))` dan
  tambahkan ketiga uji itu.
  - Perbaikan (A5, putaran 2): penghitungan pemisah diganti `detect_separator()` berbasis `count.fields()`; aturannya dijelaskan di komentar.
- [x] [R8][minor] `read_cli_data()` (R/app.R:20-39) — Kolom non-numerik
  dibuang tanpa pesan. Dengan FR-008 ini lebih sering terjadi: angka Excel
  ID berpemisah ribuan (`2.345,5`) dibaca sebagai teks, dan kolom `pdb`
  hilang begitu saja (begitu juga kasus R2). Perilaku ini terdokumentasi,
  tetapi pengguna GUI tidak diberi tahu. Saran: `rcli_warn()` yang
  menyebut kolom yang dibuang (GUI menampilkannya lewat `safely()`); uji
  dengan `expect_warning(class = ...)`.
  - Perbaikan (A5, putaran 2): `read_cli_data()` memberi peringatan `rcli_warning_dropped` yang menyebut kolom yang dibuang; GUI menampilkannya sebagai notifikasi. Uji "R8".
- [x] [R9][nit] R/app.R:205 dan NEWS.md — `fileInput` kini juga menerima
  `.txt`; NEWS tidak menyebutnya, dan berkas tab dari aplikasi lain sering
  berakhiran `.tsv`. Saran: tambahkan `.tsv` dan sebutkan di NEWS.
  - Perbaikan (A5, putaran 2): `.tsv` ditambahkan; NEWS menyebut `.txt` dan `.tsv`.
- [x] [R10][nit] tests/testthat/test-app-csv.R:51-52 — AC-FR-008.1
  meminta nilai "sama persis", sedangkan uji memakai `expect_equal()`
  (toleransi 1,5·10⁻⁸). Nilainya memang identik. Saran:
  `expect_identical()`.

  - Perbaikan (A5, putaran 2): `expect_identical()` untuk data GUI dan data skrip.
## Catatan di luar cakupan (sudah ada sebelum increment ini)
- DESCRIPTION tidak memuat `Roxygen: list(markdown = TRUE)`, sehingga
  tanda petik terbalik dan `[utils::read.csv()]` di `?read_cli_data`
  (dan 50 halaman lain) tampil apa adanya, bukan sebagai `\code{}` atau
  tautan. Kalimat baru di `@param ...` ikut terkena.
- `app_script()`/`data_lines()` menulis nama berkas dengan
  `"\"%s\""` tanpa *escape*; nama berkas yang memuat `"` atau `\`
  menghasilkan skrip yang tidak dapat diurai. Saran: `deparse_value()`.

Tindak lanjut A5 untuk catatan di luar increment: `Roxygen: list(markdown = TRUE)` di DESCRIPTION, 56 berkas Rd ditulis ulang (kode dan tautan benar); nama berkas di skrip di-escape (lihat R4).

## Review putaran 2
- Reviewer: A6 (konteks bersih: ya). Keadaan: cabang `rcli-0.3.1`, HEAD
  567153e. Komit yang dibaca sejak 4152863:
  - 567153e: perbaikan R1–R10, revisi AC-FR-008.2 dan AC-FR-008.4,
    `Roxygen: list(markdown = TRUE)` (56 berkas Rd ditulis ulang).

  Semua pemeriksaan dijalankan pada salinan `git archive` 567153e dengan
  pustaka sementara. Kotak `[x]` di atas dicentang oleh A5. Status di
  bawah ini adalah verifikasi saya; kotak R1 saya kembalikan ke `[ ]`
  karena belum tertutup.
- Gerbang yang saya jalankan sendiri:
  - `devtools::test()` lengkap dengan `NOT_CRAN=true`:
    `[ FAIL 0 | WARN 0 | SKIP 1 | PASS 1701 ]`; satu-satunya yang dilewati
    adalah `seasonal`, jadi uji peramban ikut berjalan;
  - `lintr::lint_package()`: 0 temuan;
  - `roxygen2::roxygenise()`: `man/` dan `NAMESPACE` sinkron;
  - `R CMD build` + `R CMD check --as-cran --no-manual`: 0 galat,
    0 peringatan, 3 NOTE dari lingkungan (sama dengan putaran 1);
    "checking Rd cross-references ... OK";
  - tidak ada baris > 80 karakter di R/app.R, test-app-csv.R, dan NEWS.md.
- Konversi Markdown Rd (4152863 → 567153e, 56 berkas): saya merender
  kedua versi dengan `tools::Rd2txt()` dan membandingkan kata demi kata
  sesudah membuang tanda format (`[ ]`, `-class`, petik, `_`, `*`).
  Satu-satunya perbedaan isi adalah kalimat baru yang disengaja di
  `?read_cli_data`. Semua 44 `\emph{}` baru adalah judul jurnal/buku atau
  istilah (*sidang isbat*), dan 22 `\strong{}` adalah label butir yang
  memang ditulis `**…**`; tidak ada rumus yang berubah menjadi penekanan.
  `\enumerate{}`/`\itemize{}` baru berasal dari daftar bernomor/berbutir di
  roxygen. Tautan `[fungsi()]`, `[Kelas-class]` (`\linkS4class{}`),
  `[stats::ar()]`, dan `[utils::read.csv()]` (→ `utils:read.table`) valid
  menurut `R CMD check`. Tidak ada tautan rusak atau makna yang berubah.
- Contoh gagal putaran 1 diulang (jalur GUI persis, lokal `C` dan
  `C.UTF-8`):

  | Kasus | Putaran 1 | Putaran 2 |
  |---|---|---|
  | Titik koma, nama berkoma 2:2, ada tanggal | `,` → galat tanggal | `;`/`,` benar |
  | Sama, **tanpa kolom tanggal** (2 koma : 1 titik koma) | `,` → angka salah | **`,` → angka masih salah** (100, 101, 102 / 1, 9, 5), kini dengan peringatan kolom dibuang (R1) |
  | Koma, nama berkutip berisi titik koma (2 dan 3 buah) | `;` → galat | `,`/`.` benar |
  | Titik koma, baris pertama kosong/`NA`/basis 100 | galat | `;`/`,` benar |
  | Kolom cacah + kolom indeks, baris pertama bulat | kolom hilang tanpa pesan | `;`/`,`, kedua kolom terbaca |
  | Tab, ribuan koma (`1,100.5`) | galat | `"\t"`/`.`; kolom itu dibuang dengan peringatan (benar: `read.csv()` tidak membaca pemisah ribuan) |
  | Titik koma, ribuan titik (`2.345,5`) | kolom hilang tanpa pesan | `;`/`,`; kolom dibuang dengan `rcli_warning_dropped` |
  | Windows-1252 di judul, lokal UTF-8 | galat, juga eksplisit | `;`/`,` benar |
  | Windows-1252 di kolom teks, lokal UTF-8 | — | benar; kolom teks dibuang dengan peringatan |
  | BOM tanpa kolom tanggal | nama `"﻿pdb"` | `pdb` |
  | CRLF, CR, satu baris data, bilangan bulat saja, tab bertitik | benar | benar |
  | Hanya judul / berkas kosong | galat terbaca | sama |

- Kasus baru:

  | Kasus | Hasil | Akibat |
  |---|---|---|
  | Titik koma, bilangan bulat berformat ribuan Excel ID (`987`, `1.012`, `1.045`) | `;`/`.` | **seri 987; 1,012; 1,045 tanpa pesan** (R11) |
  | Tab, bilangan bulat berformat ribuan (`12,345`) | `"\t"`/`,` | **12,345 dibaca 12.345 tanpa pesan** (R11) |
  | Titik koma, kolom tanpa nama karena `;` di akhir baris | `;`/`,` | peringatan "dropped: ." (R12) |
  | Baris sumber di akhir (`Sumber: BPS`) | `;`/`,` | galat tanggal; sudah begitu di 0.3.0 |
  | Spasi tak terputus 0xA0 menempel pada angka, lokal UTF-8 | `;`/`,` | galat `read.csv()` "invalid multibyte string"; sama di putaran 1 dan 0.3.0 |
  | BOM + nama non-ASCII, lokal `C` | `;`/`,` | nama `m<c2><b2>`; GUI dan skrip sama, data utuh |

- Reproduksi skrip ekspor (testServer langkah 1–7, `eval()` skrip):
  `write.csv2()` otomatis dan eksplisit, tab berdesimal koma dan titik,
  koma, BOM, dan acuan bernama `PDB riil` (berkas titik koma dan koma):
  nama kolom, data, dan indeks skrip = GUI di kedelapan kasus. Pilihan
  data contoh tetap tidak bocor (jalur tidak berubah).
- Mutasi (filter `app-csv`, baseline 54 lulus):

  | Mutan | Uraian | Status |
  |---|---|---|
  | M5 | `\|\|` → `&&` di `data_lines()` | **mati** (1) |
  | M8 | pilihan tanda desimal GUI diabaikan | **mati** (2) |
  | N1 | urutan seri koma, titik koma, tab | mati (1) |
  | N6 | skrip tanpa `check.names = FALSE` | mati (2) |
  | N7 | `has_bom()` selalu FALSE | mati (1) |
  | N8 | peringatan kolom dibuang dihapus | mati (1) |
  | N9 | `detect_decimal()` hanya membaca satu baris | mati (1) |
  | N10 | nama berkas tanpa `deparse_value()` | mati (1 galat) |
  | M7 | peta `csv_choice()` tanpa `kind` | **bertahan** (R13) |
  | N2 | syarat "jumlah kolom sama" diabaikan | bertahan (R13) |
  | N3 | seri desimal → koma | bertahan (R13) |
  | N4 | `trimws()`/`grepl()` tanpa `useBytes` di `detect_decimal()` | bertahan (R13) |
  | N5 | pola koma tanpa kelompok ribuan (`1.234,5`) | bertahan (R13) |
  | N11 | pengaman `fileEncoding` dari pengguna dihapus | bertahan (R13) |
  | N12 | pemisah cadangan `";"` | bertahan (R13) |

  Mutan M3, M14, dan M15 putaran 1 tidak berlaku lagi karena kodenya
  diganti `detect_separator()`.

### Status temuan putaran 1
- R1 **belum tertutup**. `detect_separator()` memilih pembagian teratur
  yang *terlebar*. Pada berkas titik koma berdesimal koma, setiap koma
  desimal menambah satu kolom bila dipisah dengan koma, sehingga
  pembagian koma bisa sama teratur dan lebih lebar. Contoh putaran 1 tanpa
  kolom tanggal masih terbaca salah: judul `PDB (ADHK, miliar);Kredit
  (Rp, triliun)` dan baris `100,5;20,1` → titik koma 2 2 2 2, koma 3 3 3
  3 → koma; langkah 1 selesai dengan seri `PDB (ADHK` = 100, 101, 102 dan
  `triliun)` = 1, 9, 5. Peringatan baru menyebut kolom yang dibuang, jadi
  kini tidak sepenuhnya diam, tetapi angkanya tetap salah. Uji R1 hanya
  memakai berkas bertanggal (koma ≤ titik koma) dan tidak mencakup kasus
  ini. Saran: di antara pembagian yang teratur dengan lebih dari satu
  kolom, pilih tab, lalu titik koma, lalu koma, tanpa melihat lebar;
  "terlebar" hanya untuk berkas yang tidak teratur. Saya uji aturan itu
  pada sembilan berkas (empat contoh putaran 1, tiga berkas uji R1, tab
  dengan koma di nama, koma biasa): semuanya benar, termasuk kasus ini.
  Tambahkan kasus tanpa tanggal ke uji R1 dan sesuaikan kalimat "yang
  terlebar" di AC-FR-008.2, NEWS, dan komentar kode.
- R2 tertutup. Mayoritas sel pecahan dari ≤ 500 baris: baris pertama
  kosong, `NA`, atau bulat tidak lagi menentukan; tab dengan ribuan koma
  dikenali titik. N9 mati. Sisa ambiguitas kelompok ribuan dicatat di R11.
- R3 tertutup. Berkas Windows-1252 (judul dan kolom teks) terbaca di
  `C.UTF-8` dengan pilihan otomatis dan eksplisit. Uji R3 hanya memuat
  byte non-UTF-8 di judul, yang tidak pernah melewati `detect_decimal()`
  (`skip = 1L`), sehingga N4 bertahan (R13).
- R4 tertutup. Skrip menulis `check.names = FALSE` dan nama berkas lewat
  `deparse_value()`; skrip mereproduksi nama, data, dan indeks untuk
  `PDB riil`. N6 dan N10 mati.
- R5 tertutup. Berkas ber-BOM dibaca dengan `fileEncoding =
  "UTF-8-BOM"` hanya bila tiga bita pertama memang BOM, jadi berkas
  Windows-1252 (R3) tidak terpengaruh. Di lokal `C` nama non-ASCII menjadi
  `<c2><b2>`, tetapi data utuh dan GUI = skrip. N7 mati.
- R6 tertutup. M5 dan M8 kini mati (uji AC-3 memakai berkas bilangan
  bulat berpemisah koma, uji R6 memeriksa baris skrip `sep = ";", dec =
  "."`). M7 masih bertahan karena `csv_choice("point", "sep")` tidak diuji;
  sisa ini masuk R13.
- R7 tertutup. Kode penghitungan diganti `detect_separator()`; mutan
  M3/M14/M15 tidak berlaku lagi.
- R8 tertutup. `rcli_warning_dropped` menyebut kolom yang dibuang; GUI
  menampilkannya lewat `safely()`, dan langkah 1 tetap selesai. N8 mati.
- R9 tertutup. `.tsv` diterima; NEWS menyebut `.txt` dan `.tsv`.
- R10 tertutup. `expect_identical()` untuk data GUI dan skrip.
- Catatan di luar cakupan tertutup: `Roxygen: list(markdown = TRUE)`
  (diperiksa di atas) dan nama berkas lewat `deparse_value()`.

### Temuan baru
- [ ] [R11][major] R/app.R:134-146 (`detect_decimal()`) dan AC-FR-008.2 —
  Sel bilangan bulat berformat ribuan dihitung sebagai bukti tanda
  desimal. `1.012` cocok dengan pola titik dan `12,345` cocok dengan pola
  koma, padahal di berkas Excel keduanya biasanya angka ribuan (format
  `#.##0`). Bukti: berkas titik koma `wisman` = `987`, `1.012`, `1.045`,
  `998` → titik → seri 987; 1,012; 1,045; 998, tanpa galat dan tanpa
  peringatan. Berkas tab `12,345`, `13,002` → koma → 12,345 dan 13,002.
  Seri cacah yang melewati 1.000 (wisatawan, izin, unit) lazim di data
  BPS, dan lonjakan palsu ini masuk langsung ke siklus. Perilaku ini sudah
  ada di putaran 1 (saya lewatkan saat itu), tetapi aturan baru
  menjadikannya bagian dari spesifikasi. Saran: anggap sel
  `^-?[0-9]{1,3}([.,][0-9]{3})+$` dengan satu jenis tanda sebagai ambigu
  dan jangan dihitung. Bila hanya sel ambigu yang ada, beri `rcli_warn()`
  yang menyebut kolomnya (mis. "angka seperti 1.012 bisa berarti seribu
  dua belas; pilih tanda desimal"), atau untuk titik koma pakai koma
  sehingga kolom itu dibuang dengan `rcli_warning_dropped`, bukan dibaca
  salah. Uji: kedua contoh di atas.
- [ ] [R12][nit] R/app.R:43-50 (`rcli_warning_dropped`) — Excel kadang
  menulis `;` di akhir setiap baris. Kolom kosong tanpa nama itu memicu
  "Columns without numbers were dropped: ." yang membingungkan. Saran:
  buang kolom yang seluruhnya `NA` tanpa peringatan, atau tulis
  `(tanpa nama)`.
- [ ] [R13][nit] tests/testthat/test-app-csv.R — Mutan yang bertahan:
  M7 (`csv_choice("point", "sep")` diterima), N2 (syarat teratur
  diabaikan), N3 (seri desimal), N4 (`useBytes`; berkas Windows-1252 dengan
  byte di kolom teks atau sel data), N5 (`1.234,5` sebagai bukti koma),
  N11 (`fileEncoding` dari pengguna pada berkas ber-BOM: tanpa pengaman,
  galat "matched by multiple actual arguments"), dan N12. Saran: satu
  harapan untuk masing-masing; uji N4 di bawah `C.UTF-8` seperti uji R3.

### Ringkasan putaran 2
R2–R10 tertutup dan terverifikasi; catatan di luar cakupan juga ditutup.
Konversi Markdown 56 berkas Rd tidak mengubah isi, dan tautannya lolos
`R CMD check`. Uji lengkap, lint, roxygen, dan check bersih. R1 belum
tertutup: contoh tanpa kolom tanggal dari putaran 1 masih menghasilkan
angka salah, karena aturan "terlebar" kalah oleh koma desimal. Ada satu
major baru (R11, kelompok ribuan dibaca sebagai desimal tanpa pesan) dan
dua nit baru (R12, R13).

## Putusan
Putaran 1 — Bentuk kode sesuai desain dan AC-FR-008 kata demi kata.
Pilihan eksplisit, pesan galat `rcli_error_argument`, penyimpanan format
di `rv$loaded`, teks dua bahasa, dan jalur data contoh benar. Skrip ekspor
mereproduksi data dan indeks GUI untuk berkas koma, titik koma, tab (dengan
`"\t"`), dan BOM. Uji lengkap (termasuk Chrome), lint, roxygen, dan
`R CMD check` bersih.

Namun aturan pengenalan otomatis di AC-FR-008.2 terlalu rapuh untuk berkas
yang menjadi sasaran fitur ini, dan ada empat major:
- R1: pemisah dari baris judul saja; nama kolom berkoma membuat berkas
  titik koma terbaca sebagai koma, dan tanpa kolom tanggal angkanya salah
  tanpa galat;
- R2: tanda desimal dari baris data pertama saja; `NA` atau nilai basis
  100 di baris pertama menyebabkan galat atau kolom hilang tanpa pesan;
- R3: regresi untuk berkas Windows-1252 di lokal UTF-8; langkah 1 gagal
  bahkan dengan pilihan eksplisit;
- R4: skrip ekspor gagal untuk nama kolom berspasi (`check.names`).

Ada tiga minor (R5 BOM, R6 celah uji/mutan, R8 kolom dibuang tanpa pesan)
dan tiga nit (R7, R9, R10). R1–R4 sebaiknya ditutup sebelum rilis 0.3.1,
dengan pembaruan AC-FR-008.2 dan NEWS. Putusan putaran 1:
CHANGES-REQUESTED.

Putaran 2 — R2–R10 tertutup dan terverifikasi. Ada dua major terbuka:
- R1 (sisa): berkas titik koma berdesimal koma tanpa kolom tanggal, dengan
  koma di nama kolom, masih terbaca sebagai koma, dan angkanya salah.
  Perbaikannya kecil: pilih titik koma/tab di antara pembagian teratur
  tanpa melihat lebar;
- R11 (baru): bilangan bulat berformat ribuan (`1.012`, `12,345`) dihitung
  sebagai bukti desimal dan dibaca salah tanpa pesan.

Keduanya menghasilkan data salah dari berkas Excel berbahasa Indonesia,
sasaran FR-008, dan keduanya perlu uji. R12 dan R13 adalah nit.

Putusan: CHANGES-REQUESTED

## Tindak lanjut A5 sesudah putaran 2
- [x] R1: di antara pemisah yang teratur, urutan pilihan tab, titik koma, lalu koma, tanpa melihat lebar; tanpa pemisah teratur, baris judul terlebar. Uji "R1: without a date column decimal commas do not win the split" (contoh putaran 2) beserta N2 dan N12; merah sebelum perbaikan.
- [x] R11: sel `1.012`/`12,345` (satu tanda, satu kelompok tiga digit) tidak dihitung sebagai bukti; `1.234.567`/`1,234,567` dihitung sebagai pemisah ribuan; tanpa bukti lain, tanda di sel bergolongan dianggap pemisah ribuan sehingga kolom dibuang dengan peringatan. Uji "R11" (titik koma, tab, kelompok ganda, N5); merah sebelum perbaikan.
- [x] R12: `read_cli_data()` membuang diam-diam kolom tanpa nama yang seluruhnya kosong. Uji "R12"; merah sebelum perbaikan.
- [x] R13: uji "R13" untuk M7 (`csv_choice("point", "sep")` dan sebaliknya), N4 (bita Windows-1252 di sel data di bawah C.UTF-8), N11 (`fileEncoding` dari pengguna pada berkas ber-BOM); N2, N3, N5, N12 di uji R1 dan R11.
