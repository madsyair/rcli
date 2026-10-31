# 04 — Rencana uji (rcli 0.2.0, 0.2.1)

| Uji | FR / F | Berkas |
|---|---|---|
| Contoh tangan, data lengkap, awal terlambat, Prop. 5, kasus tepi, 0.1.3, acuan acak | FR-001, F-01 | `tests/testthat/test-ragged-edge.R` |
| Tren linear, horizon, kecocokan `predict(ar())`, kasus tepi, `cli_cycles`, prioritas TRAMO, slot spec | FR-002, F-02 | `tests/testthat/test-end-extension.R` |
| `oecd_spec`, hasil 0.1.x, GUI dan skrip | FR-003 | `test-end-extension.R`, `test-app.R` |
| Kecocokan dengan solve() padat, seri linear dan invarian, stabilitas mundur, λ = 0, n < 4, n = 10⁵ | FR-004, F-03 | `tests/testthat/test-hp-solver.R`; replikasi mFilter di `test-filters.R` |
| Indeks koinsiden, kartu skor, teks aturan per pengklasifikasi, GUI langkah 9–10, skrip ekspor | FR-005 | `test-coincident.R`, `test-quality.R`, `test-selection-bias.R`, `test-app.R`, `test-app-e2e.R`; `data-raw/calibrate_coincident.R` |
| Judul berversi, tombol indeks sejalan sebagai acuan, metadata menurut nama, skrip ekspor berantai | FR-006 | `tests/testthat/test-app-reference.R`, `test-app-e2e.R` ("the coincident index becomes the reference in the browser") |
| Frekuensi asal: deteksi semesteran/tahunan, Denton–Cholette k umum (pembanding tempdisagg, k = 3 sama dengan 0.2.1), interpolasi linear, Chow–Lin, penolakan kandidat semesteran/tahunan, frekuensi yang dinyatakan, metadata | FR-007, F-04 | `tests/testthat/test-frequency.R`; uji lama `test-align.R` |
| GUI langkah 2: isian frekuensi asal, penolakan, skrip, simpan menurut nama | FR-007 AC-7 | `tests/testthat/test-app-frequency.R` |
| Pemisah kolom dan tanda desimal CSV: pengenalan otomatis, pilihan eksplisit, galat bila sama, skrip ekspor, teks dua bahasa; unggahan `write.csv2()` di peramban | FR-008 | `tests/testthat/test-app-csv.R`, `test-app-e2e.R` |
| Beberapa berkas per indikator: bentuk tanggal, nama seri, format per berkas, sel kosong, kesetaraan dengan berkas lebar, metadata kosong tidak menimpa penyelarasan | FR-009 AC-1 sampai AC-4, AC-6 | `tests/testthat/test-read-series.R` |
| GUI beberapa berkas: ringkasan, grafik, tipe seri acuan, frekuensi terisi, penolakan tanpa tipe, langkah 3–9, skrip ekspor, indeks sejalan sebagai acuan; unggahan tiga berkas di peramban | FR-009 AC-5 sampai AC-7 | `tests/testthat/test-app-multi.R`, `test-app-e2e.R` |
| Imports tidak bertambah; biaya perpanjangan; kalibrasi dan evaluasi waktu nyata | NFR-001, NFR-002, NFR-003 | `test-end-extension.R`; data dari `data-raw/calibrate_*.R`, `data-raw/realtime_defaults.R` |

## Bukti merah (G4)
Bukti merah: sebelum implementasi (2026-10-23): `devtools::test(filter = "ragged-edge|end-extension")` gagal — fungsi `extend_series`, `ar_extension`, `no_extension` dan argumen `ragged_edge` belum ada (lihat log di bawah).

Log (2026-10-23, `devtools::test(filter = "ragged-edge|end-extension")`): 9 galat, antara lain
`unused argument (extension = no_extension())` dan `no slot of name "extension" for this object of class "CliSpec"`; fungsi `extend_series`, `ar_extension`, `no_extension` belum ada.

### Bukti merah 0.2.1 (G4)
Bukti merah: sebelum implementasi FR-004 (2026-10-23), `devtools::test(filter = "hp-solver")` gagal: AC-6 `Error: cannot allocate vector of size 74.5 Gb` (solve() padat untuk n = 10⁵) dan AC-3 dengan batas semula (galat sisa relatif 2e-10 > 1e-10, juga untuk solve() padat; batas direvisi ke galat mundur ternorma ≤ 10u sesuai teori, lihat 01 dan F-03).

### Bukti merah 0.3.0 (G4)
Bukti merah: sebelum implementasi FR-006 (2026-10-24), `devtools::test(filter = "app-reference")` gagal: judul tanpa versi (2 kegagalan), kunci teks `cci_ref` belum ada (galat), dan tombol `cci_ref` tidak berbuat apa-apa (6 kegagalan pada `rv$cand@reference`, `rv$done`, `rv$data`).

Bukti merah FR-007 (2026-10-24): `devtools::test(filter = "frequency")` gagal 10 kali sebelum implementasi (`series_frequencies` tidak ada, `cli_align()` menolak `ts` tahunan, `denton_cholette()` tanpa argumen `to`, metadata tanpa kolom `frequency`); `test-app-frequency.R` gagal 3 kali (kunci teks `var_freq` dan isian `frq_i` belum ada).

### Bukti merah 0.3.1 (G4)
Bukti merah: sebelum implementasi FR-008 (2026-10-31), `devtools::test(filter = "app-csv")` gagal 10 kali (`csv_format()` dan `data_lines()` belum ada; berkas bertitik koma terbaca sebagai satu kolom; isian `csv_sep` dan `csv_dec` belum ada di UI).

### Bukti merah 0.4.0 (G4)
Bukti merah: sebelum implementasi FR-009 (2026-11-01), `test-read-series.R` gagal 4 kali (`read_cli_series()` belum ada) dan `test-app-multi.R` gagal 2 kali (kunci teks `src_upload_multi` dan isian `files` belum ada; langkah 2 tidak selesai). Uji "metadata kosong tidak menimpa penyelarasan" ditambahkan sesudah uji GUI menemukan cacat itu di `complete_meta()`; uji itu gagal pada kode 0.3.1.
