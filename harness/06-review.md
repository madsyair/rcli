# 06 — Review

- Increment: rcli 0.3.1 (FR-008)
- Reviewer: A6 (konteks bersih: ya)
- Putaran: 1
- Keadaan yang direview: cabang `rcli-0.3.1`, HEAD 4152863, terhadap basis
  595dba8 (0.3.0 di main). Komit yang dibaca:
  - 4152863: pemisah kolom dan tanda desimal berkas CSV unggahan di GUI
    (FR-008), versi 0.3.1.

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
- [x] [R1][major] R/app.R:84-91 (`csv_format()`, pengenalan pemisah) dan
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
dengan pembaruan AC-FR-008.2 dan NEWS.

Putusan: CHANGES-REQUESTED
