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
