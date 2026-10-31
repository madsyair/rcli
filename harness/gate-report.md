# Gate report — 2026-10-31T17:46:12

| Gerbang | Hasil | Gagal |
|---|---|---|
| G1 Kebutuhan | LOLOS | 0 |
| G2 Verifikasi matematis | LOLOS | 0 |
| G3 Desain | LOLOS | 0 |
| G4 Uji-dulu | LOLOS | 0 |
| G5 Build & uji | LOLOS | 0 |
| G6 Review | LOLOS | 0 |
| G7 Dokumentasi | LOLOS | 0 |
| G8 Rilis | LOLOS | 0 |

## G1 Kebutuhan
- [x] Ada kebutuhan FR/NFR — 11 ID
- [x] Setiap FR/NFR punya kriteria penerimaan — lengkap
- [x] Tidak ada TODO
- [x] Bagian 'Di luar cakupan' ada

## G2 Verifikasi matematis
- [x] F-01: status kelas C — PROVEN
- [x] F-01: kritikus independen — putusan terakhir: ACCEPT
- [x] F-01: skrip verifikasi tersimpan — F-01_numeric.R, F-01_symbolic.py
- [x] F-01: uji yang diturunkan — 8 butir
- [x] F-03: status kelas A — CITED-VERIFIED
- [x] F-03: skrip verifikasi tersimpan — F-03_numeric.R, F-03_symbolic.py
- [x] F-03: uji yang diturunkan — 6 butir
- [x] F-04: status kelas A — CITED-VERIFIED
- [x] F-04: skrip verifikasi tersimpan — F-04_numeric.R
- [x] F-04: uji yang diturunkan — 4 butir
- [x] F-02: status kelas A — CITED-VERIFIED
- [x] F-02: skrip verifikasi tersimpan — F-02_numeric.R
- [x] F-02: uji yang diturunkan — 7 butir

## G3 Desain
- [x] Setiap FR terpetakan di desain — 8 FR
- [x] Ada ADR — 2 ADR
- [x] Tidak ada TODO

## G4 Uji-dulu
- [x] Ada berkas uji
- [x] Setiap FR/NFR dilacak ke uji — 11 ID
- [x] Setiap F-xx dilacak ke uji — 4 formula
- [x] Bukti merah tercatat — sebelum implementasi (2026-10-23): `devtools::test(filter = "ragged-edge|end-ext

## G5 Build & uji
- [x] tests — exit 0: [ FAIL 0 | WARN 0 | SKIP 1 | PASS 1725 ] | ℹ Testing rcli | Loading required package: shiny | Picked up JAVA_TOOL_OPTIONS: -Djavax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts -Djavax.net.ssl.trustStoreType=JKS -Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=44707 -Dhttp.nonProxyHosts=localhost|127.
- [x] lint — exit 0: 
- [x] coverage — exit 0: coverage 96.97266

## G6 Review
- [x] Tidak ada temuan blocker/major terbuka
- [x] Putusan APPROVE — APPROVE

## G7 Dokumentasi
- [x] document — exit 0: ℹ Updating rcli documentation | ℹ Loading rcli
- [x] examples — exit 0: ℹ Updating rcli documentation | ℹ Loading rcli | ℹ Loading rcli | ℹ Loading rcli

## G8 Rilis
- [x] Gerbang G1–G7 lolos
- [x] check-as-cran — exit 0:  | 0 errors ✔ | 0 warnings ✔ | 2 notes ✖ | ℹ Updating rcli documentation | ℹ Loading rcli
