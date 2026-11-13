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

## Keputusan yang menunggu maintainer

1. T3: tambahkan pilihan ukuran amplitudo (`sd` atau `mad`) dan jadikan
   `sd` bawaan `oecd_spec()`? Bawaan `cli_spec()` tidak berubah.
2. T2: tambahkan pilihan laju log dengan pembalikan resiprokal pada
   `oecd_aggregate()`? Bukti hanya dari satu negara; dokumen OECD hanya
   menyebut "averaging the growth rates".
3. T6: ambang `max_extra` untuk aturan OECD perlu dikaji dengan lebih
   banyak negara sebelum diubah.
