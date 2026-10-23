# 08 — Rilis rcli 0.2.0

- Versi: 0.2.0 (DESCRIPTION, NEWS.md).
- Kalibrasi: `data-raw/calibrate_collect.R` + `calibrate_summarise.R` (60 ulangan), `data-raw/compare_oecd.R`, `data-raw/realtime_defaults.R` dijalankan ulang; `inst/calibration/*.csv` diperbarui.
- Dokumentasi: roxygen, vinyet bagian 8, README, pedoman (bab 2, 3, 5, 6, 11, 12; tangkapan layar GUI).
- Cek: `R CMD check --as-cran --no-manual` lokal; CI tiga OS setelah push.

## Keputusan yang menunggu pengelola
- AC-NFR-002.1 (≤ 10% tambahan waktu `cli_cycles()`) tidak terpenuhi: +16% (+8 ms per seri). Pilihan: (a) terima penyimpangan untuk 0.2.0; (b) ganti penyaring HP padat O(n³) dengan penyelesai pentadiagonal O(n) di increment berikutnya, yang juga mempercepat semua penyaring HP; (c) jadikan perpanjangan opsional. Rekomendasi: (a) sekarang, (b) berikutnya.
