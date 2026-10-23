# 04 — Rencana uji (rcli 0.2.0)

| Uji | FR / F | Berkas |
|---|---|---|
| Contoh tangan, data lengkap, awal terlambat, Prop. 5, kasus tepi, 0.1.3, acuan acak | FR-001, F-01 | `tests/testthat/test-ragged-edge.R` |
| Tren linear, horizon, kecocokan `predict(ar())`, kasus tepi, `cli_cycles`, prioritas TRAMO, slot spec | FR-002, F-02 | `tests/testthat/test-end-extension.R` |
| `oecd_spec`, hasil 0.1.x, GUI dan skrip | FR-003 | `test-end-extension.R`, `test-app.R` |
| Imports tidak bertambah; biaya perpanjangan; kalibrasi dan evaluasi waktu nyata | NFR-001, NFR-002, NFR-003 | `test-end-extension.R`; data dari `data-raw/calibrate_*.R`, `data-raw/realtime_defaults.R` |

## Bukti merah (G4)
Bukti merah: sebelum implementasi (2026-10-23): `devtools::test(filter = "ragged-edge|end-extension")` gagal — fungsi `extend_series`, `ar_extension`, `no_extension` dan argumen `ragged_edge` belum ada (lihat log di bawah).

Log (2026-10-23, `devtools::test(filter = "ragged-edge|end-extension")`): 9 galat, antara lain
`unused argument (extension = no_extension())` dan `no slot of name "extension" for this object of class "CliSpec"`; fungsi `extend_series`, `ar_extension`, `no_extension` belum ada.
