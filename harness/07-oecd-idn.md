# Validasi rcli dengan CLI Indonesia terbitan OECD (INC-14, mode `audit`)

Tanggal: 14 November 2026. Data: snapshot API SDMX OECD tanggal 13 November 2026
(`data-raw/oecd-idn/SNAPSHOT`). Skrip pengunduh adalah `data-raw/oecd_idn_fetch.R`; skrip eksperimen
adalah `data-raw/oecd_idn_validate.R`. Hasil:
`inst/calibration/oecd-idn-*.csv`. Uji regresi: dua uji di `test-oecd.R`
dengan *fixture* `tests/testthat/fixtures/oecd-idn.rds`.

## Data OECD untuk Indonesia

| Dataflow | Isi |
|---|---|
| DF_CLI | CLI (*amplitude adjusted*, *normalised*, *trend restored*), seri acuan PDB (siklus ternormalisasi, rasio terhadap tren, tren), dan tujuh komponen dalam bentuk siklus ternormalisasi saja |
| DF_FINMARK | Harga saham, suku bunga *call money* dan antarbank 3 bulan, rupiah per dolar AS (nilai asli) |
| DF_CS | Keyakinan konsumen komposit (nilai asli) |
| DF_QNA | PDB triwulanan, volume berantai, disesuaikan musiman |

Ketujuh komponen: keyakinan konsumen (LOCOCI), kurs (LOCOEX), produksi
barang galian nonlogam (LOCOPM, berhenti Desember 2019), harga produsen
(LOCOPP), harga saham (LOCOSP), suku bunga jangka pendek (LOCOST), dan
aktivitas pariwisata (LOCOTA). OECD tidak menerbitkan seri asli harga produsen, produksi nonlogam, serta
pariwisata.

## Temuan

| No. | Tahap | Hasil | Kode rcli | Status |
|---|---|---|---|---|
| T1 | Agregasi | `oecd_aggregate()` dengan tanda OECD: korelasi 0,998 dengan CLI terbitan; 27 dari 27 titik balik pada bulan yang sama | `R/aggregate.R`, metode `OecdAggregate` | sama |
| T2 | Rumus agregasi | rcli merantai laju aritmetika (z + 100) dan membalik tanda z. Laju log dengan pembalikan resiprokal memberi korelasi 0,9998; titik balik tetap sama | `R/aggregate.R`; `invert_cycle()` di `R/assessment.R` | varian, tidak berdampak pada titik balik |
| T3 | Penyesuaian amplitudo | CLI *amplitude adjusted* OECD = CLI ternormalisasi × 1,713, mendekati rasio simpangan baku (1,704). rcli memakai rasio simpangan absolut rata-rata (1,427), sehingga ayunan indeksnya sekitar 17% lebih kecil | `reference_amplitude()` di `R/aggregate.R` | varian; usul opsi `sd` |
| T4 | Tepi kasar | OECD menerbitkan Oktober 2026 dengan 2 dari 6 komponen aktif (di bawah aturan 60%); rcli mengosongkan bulan itu | `coverage_mask()` | rcli mengikuti dokumen OECD |
| T5 | Arah komponen | Dari data, rcli membalik kurs dan suku bunga seperti OECD, tetapi tidak membalik harga produsen (korelasi dengan PDB 0,07). Dengan `meta$sign`, hasil T1 kembali | penentuan tanda di `cli_assess()` | sesuai dokumentasi; anjuran: tanda dari rasional ekonomi |
| T6 | Klasifikasi | Aturan median *lead* saja: 5 *leading*, 2 *coincident*. Aturan OECD dengan kesesuaian siklus: hanya suku bunga yang *leading*, karena siklus ekstra melebihi `max_extra` 0,4. CLI terbitan OECD sendiri memiliki 11 titik balik ekstra terhadap 16 titik balik acuan (0,69) | `oecd_classifier()`, `max_extra` | rcli lebih ketat daripada praktik OECD |
| T7 | Ekstraksi siklus | Dari seri asli, `oecd_spec()` menghasilkan siklus berkorelasi 0,90–0,99 dengan siklus OECD; siklus PDB (Denton–Cholette ke bulanan) menemukan 19 dari 19 titik balik acuan. Tanpa pencilan TRAMO, korelasi naik sedikit (0,92–0,99) | `cli_cycles()` | sama; selisih berasal dari data dan pencilan |

## Kajian dokumen OECD (14 November 2026)

| Dokumen | Isi yang relevan | Dampak pada rcli |
|---|---|---|
| Gyomai dan Guidetti (2012), *OECD System of Composite Leading Indicators* (sama dengan versi November 2008 yang dipresentasikan di UNSD 2009) | Agregasi: "averaging the growth rates … chained"; amplitudo: "rescales … to match the amplitudes"; normalisasi dengan simpangan absolut rata-rata; Bry–Boschan fase 5 dan siklus 15 bulan; aturan 60% | Sudah menjadi acuan; rumus laju, ukuran amplitudo, dan cara pembalikan tidak disebut |
| Nilsson dan Gyomai (2011), *Cycle extraction* (OECD Statistics Working Papers 2011/04) | HP ganda 12–120 bulan sejak Desember 2008; "series specific stabilizing forecasting with forecast horizons from 0 to 2 month" (¶65); prakiraan panjang memperbesar revisi akhir (¶62) | `oecd_spec()` memakai prakiraan 12 bulan → diubah menjadi 2 bulan; dokumentasi `tramo_outliers()` keliru dan diperbaiki |
| *OECD CLI Zone Aggregation Methodology* | Agregasi zona: indeks Laspeyres berantai tahunan dengan bobot PDB PPP; 60% bobot; CLI *trend restored* = CLI *amplitude adjusted* × tren acuan | Hanya untuk zona; rumus *trend restored* sama dengan `cli_presentation()` |
| FAQ dan glosarium CLI OECD | λ = 133.107,94 dan 13,93 (sama dengan rcli); amplitudo "on average agrees" dengan acuan; normalisasi CLI dengan simpangan absolut rata-rata | Tidak ada rumus amplitudo maupun pembalikan |
| *Handbook on Constructing Composite Indicators* (OECD/JRC 2008) | Menyatakan tidak membahas CLI; rumus normalisasi siklus sama (bagian 5.6) | Tidak berdampak |
| *Interpreting OECD CLIs* (2020) | Tafsiran CLI di atas/bawah 100 dan arah perubahan bulanan | Tidak berdampak pada perhitungan |

Kesimpulan: dokumen OECD tidak menetapkan rumus laju, cara pembalikan, dan ukuran amplitudo. Pilihan FR-014 diambil dari data OECD Indonesia (T2, T3), sedangkan horizon prakiraan diambil dari Nilsson dan Gyomai (2011).

## Tindak lanjut (INC-15, FR-014)

| Temuan | Perubahan | Hasil pada data Indonesia |
|---|---|---|
| T2 | `oecd_aggregate(growth = "log")` menjadi bawaan; `"ratio"` = aturan 0.7.0 | korelasi 0,998 → 0,9998; 27 dari 27 titik balik tetap |
| T3 | `cli_spec(amplitude = "sd")`; `oecd_spec()` memakai `"sd"`, bawaan `cli_spec()` tetap `"mad"` | selisih rata-rata indeks *amplitude adjusted* 0,34 → 0,04 poin |
| Nilsson dan Gyomai (2011) | `oecd_spec(forecast = NULL)` = 2 bulan (1 triwulan) | korelasi siklus harga saham dengan siklus OECD 0,976 → 0,985; suku bunga 0,943 → 0,947 |
| T4, T6 | tidak diubah: dokumen OECD hanya menyebut aturan 60% dan tidak memberi ambang siklus ekstra | — |
