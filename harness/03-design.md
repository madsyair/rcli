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
