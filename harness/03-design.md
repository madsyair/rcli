# 03 — Desain (rcli 0.2.0)

## Peta kebutuhan ke API
| FR | Elemen API | Berkas |
|---|---|---|
| FR-001 | `equal_weight(min_coverage = 0.6, ragged_edge = c("chain", "level"))`; slot `ragged_edge` di kelas `EqualWeight`; metode `aggregate_components("EqualWeight")` | `R/classes-aggregator.R`, `R/aggregate.R` |
| FR-002 | Kelas strategi virtual `Extension`, subkelas `ArExtension` (slot `h`, `order_max`) dan `NoExtension`; konstruktor `ar_extension()`, `no_extension()`; generic `extend_series(extension, x, ...)`; slot `extension` di `CliSpec`; `cycle_one()` memakai prakiraan perlakuan pencilan bila ada, selain itu `extend_series()` | `R/classes-extension.R`, `R/classes-core.R`, `R/cycles.R`, `R/spec.R` |
| FR-003 | `cli_spec(extension = NULL)`, `update()`, `show("CliSpec")`, `oecd_spec(extension = no_extension())`; GUI `aggregator_choices` (`equal`, `equal_level`, …), kotak centang `extend`; `spec_call()` | `R/spec.R`, `R/methods-show.R`, `R/app.R`, `R/app-text.R` |

## Keputusan
- ADR-001: rantai hanya di ujung (bukan rangkaian penuh) dan argumen `ragged_edge` pada `equal_weight()` alih-alih kelas agregasi baru.
- ADR-002: perpanjangan sebagai strategi tersendiri (`Extension`), bukan bagian dari `OutlierTreatment`.

## Kompatibilitas
- Objek 0.1.x tanpa slot baru: `EqualWeight` tanpa `ragged_edge` → "level"; `CliSpec` tanpa `extension` → tanpa perpanjangan (`methods::.hasSlot`).
- Cara mendapat hasil 0.1.x didokumentasikan di NEWS dan `?cli_spec`.

## Increment 0.2.1
| FR | Elemen API | Berkas |
|---|---|---|
| FR-004 | `hp_trend_core(x, lambda)` (internal) dengan faktorisasi LDLᵀ pita; antarmuka `hp_filter()`, `hp_double_filter()`, `cli_presentation()` tidak berubah | `R/filters.R` |
| FR-005 | `cci_build()`, `cci_validate()`, `coincident_criteria()`, `coincidents()`, `cci_as_reference()`, kelas `CciResult`, slot `role` di `CliValidation`; GUI langkah 9 (indeks sejalan) dan 10 (ekspor); generic internal `timing_band()` dan `timing_rules()` | `R/coincident.R`, `R/app*.R`, `R/quality.R`, `R/selection-bias.R` |

Keputusan 0.2.1:
- Penyelesai pita ditulis dalam R murni (tanpa 'Matrix' dan tanpa kode C), karena tidak boleh ada Imports baru tanpa persetujuan dan waktunya sudah 0,4 ms per panggilan pada n = 372.
- Pita lebar batas klasifikasi koinsiden diatur oleh metode kelas `Classifier` (generic internal), sesuai aturan CLAUDE.md "tanpa cabang `if (class == ...)` di inti"; kode PR #1 semula memakai `is(classifier, "OecdClassifier")`.

## Increment 0.3.0
| FR | Elemen API | Berkas |
|---|---|---|
| FR-006 | Judul `titlePanel(sprintf("rcli %s: %s", packageVersion, t("title")))`; tombol `cci_ref` dan observer yang memanggil `cci_as_reference()`; nilai reaktif `prelude` (skrip analisis sebelumnya) dan `cand_rebuilt`; `app_script()` dipecah menjadi `candidate_lines()` dan `analysis_lines()`; metadata langkah 2 dipertahankan menurut nama | `R/app.R`, `R/app-text.R` |

Keputusan: skrip ekspor menyimpan analisis pertama secara utuh (prelude) agar `cci` dapat dibentuk ulang di R; tanpa itu skrip tidak dapat mereproduksi seri acuan "cci".
| FR-007 | `series_frequencies`; `cli_align(frequency = )` dengan `check_frequencies()`; deteksi semesteran/tahunan di `as_dated()`; `convert_one()` menolak kandidat semesteran/tahunan (`abort_low_frequency()`); `denton_cholette(q, tp, to)`, `constraint_matrix(m, tp, k)`, `target_frame()`, `interpolate_reference()`, `chow_lin(..., to)`; kolom `frequency` di `complete_meta()`; GUI isian `frq_i` | `R/align.R`, `R/candidates.R`, `R/app.R`, `R/app-text.R` |

Keputusan FR-007: frekuensi semesteran dan tahunan hanya untuk seri acuan (keputusan pengguna menerima usulan); kandidat ditolak dengan galat, bukan peringatan, agar komposit tidak memuat komponen yang tak mungkin menunjukkan *lead* beberapa bulan. Frekuensi asal dideteksi dari tanggal dan hanya diperiksa bila dinyatakan.

## Increment 0.3.1
| FR | Elemen API | Berkas |
|---|---|---|
| FR-008 | Isian GUI `csv_sep`, `csv_dec`; fungsi internal `csv_format(path, sep, dec)` (pengenalan otomatis) dan `csv_choice()`; `data_lines()` (langkah 1 skrip ekspor, dengan `sep` dan `dec` bila bukan bawaan); `rv$loaded$sep`, `rv$loaded$dec` | `R/app.R`, `R/app-text.R` |

Keputusan: `read_cli_data()` tidak diubah (argumen `...` sudah diteruskan ke `read.csv()`); pengenalan otomatis hanya di GUI agar perilaku fungsi untuk pengguna R tetap eksplisit.

## Increment 0.4.0
| FR | Elemen API | Berkas |
|---|---|---|
| FR-009 | Fungsi ekspor `read_cli_series(files, sep, dec)`; internal `read_series_file()`, `series_dates()`; GUI sumber `upload_multi` dengan isian `files` (banyak) dan `target_freq`, `rv$series`, `rv$align`, `series_summary()`, `date_label()`, `plot_series_dated()`, `index_first()`; langkah 2 isian `ref_type`, frekuensi asal terisi dari deteksi, `run2` memanggil `cli_align()` lalu `cli_candidates()`; `multi_lines()` di skrip ekspor | `R/read-series.R`, `R/app.R`, `R/app-plots.R`, `R/app-text.R` |

Keputusan FR-009:
- Fungsi baca terpisah dari `read_cli_data()` karena keluarannya berbeda (daftar seri bertanggal, bukan `ts` lebar) dan langsung menjadi masukan `cli_align()`; tidak ada Imports baru.
- Tanggal setiap berkas harus satu bentuk; bentuk dikenali dari nilai pertama, dan nilai pertama yang menyimpang disebut dalam pesan galat.
- Sel kosong hanya membuang observasi seri itu, sehingga satu berkas boleh memuat seri dengan rentang berbeda.
- Penyelarasan frekuensi dilakukan di langkah 2, bukan langkah 1, karena tipe variabel (aliran, stok, rata-rata) baru diisi di langkah 2. Langkah 1 menyimpan seri apa adanya (`rv$series`), `rv$data` kosong.
- Perbaikan inti yang ikut: `complete_meta()` tidak lagi menimpa tipe dan frekuensi dari `cli_align()` dengan nilai kosong di `meta`.

## Increment 0.5.0
| FR | Elemen API | Berkas |
|---|---|---|
| FR-010 | Argumen baru `cli_presentation(x, composite = NULL)`; GUI: `idulfitri`, panel `advanced_ui()` (isian `classifier`, `outlier_method`, `lag_shift`, parameter penyaring, penanggalan, ambang, cakupan agregasi, AR), isian penyelarasan `align_method`, `align_indicator`, `week_date`, `align_coverage` (`align_ui()`), `pres_form`, `pres_plot`, `dl_presentation`; fungsi internal `spec_call()`, `align_text()`, `assign_text()`, `call_text()`, `eval_code()`, `plot_presentation()` | `R/app-options.R` (baru), `R/app.R`, `R/app-text.R`, `R/app-plots.R`, `R/presentation.R` |

Keputusan FR-010:
- GUI menjalankan teks kode yang juga ditulis ke skrip ekspor (`eval_code()`), untuk spesifikasi (langkah 3) dan penyelarasan (langkah 2). Dengan begitu GUI dan skrip tidak dapat berbeda, dan setiap pilihan baru cukup ditambahkan di satu tempat.
- Isian lanjutan yang kosong berarti bawaan paket; bawaan yang bergantung pada frekuensi tidak diduplikasi di GUI.
- Opsi lanjutan hanya untuk metode rcli; metode "Persis OECD" tetap paket tetap `oecd_spec()`, kecuali efek Idulfitri yang berlaku untuk keduanya.
- Seri indikator Chow–Lin dipilih dari seri yang frekuensinya sama dengan frekuensi analisis dan dibentuk di skrip dengan `cli_align(series["x"], freq = ...)[, "x"]`.

## Increment 0.5.1
| FR | Elemen API | Berkas |
|---|---|---|
| FR-011 | Internal `outlier_period()`, `clean_forecast()`, `cycle_level()`, `check_valid()`, `new_valid()`, `min_overlap()`, `warn_short_tests()`, `factor_fallback()`; perilaku `replace_outliers()`, `window()` CandidateSet, `cli_candidates()`, `cli_composite()`, `cli_validate()`, `one_cutoff()` | `R/outliers.R`, `R/cycles.R`, `R/aggregate.R`, `R/presentation.R`, `R/selection-bias.R`, `R/candidates.R`, `R/spec.R`, `R/assessment.R`, `R/validation.R` |

Keputusan FR-011:
- Hanya cacat; bawaan metode tidak berubah. Temuan yang menyentuh pengklasifikasi dan kartu skor (G1–G5) ditunda ke 0.6.0 karena memerlukan kalibrasi ulang.
- Hanya perubahan ekstrem pada observasi pertama yang diganti; observasi terakhir tidak disentuh karena merupakan sinyal terbaru (review 0.5.1, R3).
- Tumpang tindih minimum korelasi silang dinyatakan dalam tahun (dua tahun) agar bulanan tidak berubah (24) dan triwulanan tidak lagi selalu NA untuk sampel pendek.

## Increment 0.6.0
| FR | Elemen API | Berkas |
|---|---|---|
| FR-012 | Kolom `meta$sign`; kolom `sign_source` di tabel penilaian; internal `orient_sign()` (F-05), `fixed_b_p()` dan tabel `fixed_b_null` di `R/sysdata.rda` (F-06), `recursive_logit()` (F-07); argumen `oecd_classifier(conformity = )` dan `contraction_probability(recursive = )`; perilaku `cross_correlation()`, `concordance()`, `pesaran_timmermann()`, `cli_validate()`, `horizon = NA` | `R/assessment.R`, `R/candidates.R`, `R/classes-classifier.R`, `R/validation.R`, `R/spec.R`, `R/app*.R`, `data-raw/fixed_b_table.R`, `data-raw/evaluation_060.R` |

Keputusan FR-012 (bukti: simulasi 2 November 2026, diringkas di `inst/calibration/test-size.csv`):
- Arah seri (G1): korelasi silang terbesar pada |k| ≤ ⌊P̂/4⌋ benar untuk siklus teratur bila *lead* < P/4; pada *lead* ≥ P/4 arah memang tidak teridentifikasi (*lead* P/2 sama dengan inversi), sehingga pengguna dapat menyatakannya di `meta$sign`, sesuai praktik OECD yang menetapkan arah dari alasan ekonomi. Pemasangan titik balik sebagai penentu arah ditolak: salah 35–45% untuk *lead* 12 pada siklus AR(2).
- Uji konkordansi (G3): uji rotasi sirkular dengan jarak geser minimum ditolak karena ukurannya mendekati g/n (7–13%); uji geser Harris (2020) berukuran benar tetapi dayanya 14%. HAC *fixed-b* memberi ukuran 6–8% pada status Markov (n = 360) dan 6–10% pada siklus tersimulasi dengan geser tetap, dengan daya ≥ 0,97. Inflasi karena geser dipilih dari data (sekitar 15% bulanan) tidak dikoreksi dan didokumentasikan.
- Horizon uji prediksi: batas bawah `target_lead`, karena horizon dari lag korelasi silang adalah pilihan dari data dan menaikkan ukuran uji PT dari 5% ke 13%.
- Kesesuaian siklus OECD (G2): Gyomai dan Guidetti (2012, p. 8) menilai *lead*, kesesuaian siklus (korelasi silang), dan siklus terlewat atau ekstra; `oecd_classifier()` 0.5.1 hanya memakai median *lead*. Jendela simetris saja tidak menghilangkan bias median *lead* pada pasangan independen (pemasangan berurutan menghasilkan bias negatif), sehingga syarat kesesuaian yang menjadi perbaikan utamanya.
- Peluang kontraksi (G5): logit rekursif luar sampel, sesuai Estrella dan Mishkin (1998); QPS dalam sampel selalu mengalahkan prakiraan konstan sehingga tidak informatif.

