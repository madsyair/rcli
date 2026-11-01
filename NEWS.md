# rcli 0.6.0

The evaluation of candidates and the validation of the composite are
revised after the review of 1 November 2026 (findings G1, G2, G3 and G5).
Default results change, so the calibration was run again; the evidence is
in `data-raw/evaluation_060.R` and `inst/calibration/test-size.csv`.

## Direction of a candidate (G1)

* `meta` in `cli_candidates()` takes a column `sign`: 1 (procyclical), -1
  (countercyclical) or `NA` (from the data). A declared sign is used as
  given, as the OECD sets the direction from the economic rationale. The
  assessment table records `sign_source`, `print()` marks declared signs
  with `^`, and the interface has a direction entry in step 2.
* Where no sign is declared, it is the sign of the strongest
  cross-correlation within a quarter of the average reference cycle,
  instead of within +/- `ccf_lag_max`. With regular cycles the old rule
  inverted true leaders about half of the time (a 6-month lead on a 4-year
  cycle correlates almost as strongly, with opposite sign, at a lag of 18
  months).
* The cross-correlation lead is the peak of the oriented correlation within
  half a reference cycle, so that the same phase one cycle later is not
  taken for it.

## Tests that allow for persistent cycles (G3, G5)

* The concordance test uses a Bartlett HAC variance with a fixed bandwidth
  of 30 percent of the sample and the fixed-b critical values of Kiefer and
  Vogelsang (2005). The Newey-West bandwidth of earlier versions rejected
  independent cycles 19 to 37 percent of the time at the 5 percent level;
  the new test 6 to 18 percent (the upper end when the shift is the median
  lead chosen from the same data). `concordance()` reports a one-sided
  p-value.
* The Pesaran-Timmermann test of `cli_validate()` and `cci_validate()` uses
  the regression form of Pesaran and Timmermann (2009) with the same
  variance.
* The probability of contraction of `cli_validate()` comes from a recursive
  out-of-sample logit (Estrella and Mishkin 1998): the QPS is compared with
  a naive forecast from the same past data, and the AUC is computed from
  the forecasts (`n_forecasts`). In sample, a logit always beat the naive
  forecast. `contraction_probability(recursive = FALSE)` gives the old
  in-sample fit.
* `horizon = NA` now means the lower end of `target_lead` (6 months or 2
  quarters), fixed in advance, instead of the lag of the composite's own
  cross-correlation peak.

## OECD classifier (G2)

* `oecd_classifier(conformity = TRUE)`, the new default, also requires the
  OECD criteria of cyclical conformity and missing or extra cycles: a
  positive cross-correlation peak, few missed and extra turning points and
  significant concordance. Without them the median lead alone labelled
  about half of all independent cycles leading. `conformity = FALSE` (also
  in the interface) gives the 0.5.1 rule; classifiers saved before 0.6.0
  keep it.
* `oecd_spec()` takes a `classifier` argument.
* The default matching window stays asymmetric: a symmetric one did not
  remove the bias of the median lead of independent series and lost true
  leaders (`inst/calibration/lead-window.csv`).

## Calibration

* The calibration harness was run again (100 samples per frequency and
  noise level). Classification accuracy is as before; true leaders are
  found slightly more often, false "leading" labels stay at about 1 percent
  or less, and in very noisy quarterly data pure-noise series are called
  coincident or lagging somewhat more often (up to about 15 percent, from
  7 percent).
* With the conformity criteria, `oecd_classifier()` labels 2 to 8 percent of
  the non-leading calibration candidates leading, against 19 to 23 percent
  with the median lead alone (`inst/calibration/oecd-classification.csv`).

## Documentation

* The Toda-Yamamoto test on filtered cycles rejects independent series
  somewhat more often than its nominal level; this is noted in
  `?cli_assess`.
* `?concordance` reports the size of the new test in simulations.

# rcli 0.5.1

Corrections from the review of 1 November 2026. Default settings are
unchanged, but default results can change where a fix applies: an extreme
first change of a series, short quarterly samples, `oecd_spec()` with
quarterly data, and the aggregator recorded for a single component.
Improvements of the candidate evaluation that need a new calibration are
planned for 0.6.0.

## Bug fixes

* `tramo_outliers()`: outliers of quarterly data, which JDemetra+ dates
  with Roman numerals ("AO (IV-2009)"), were not removed (with a warning
  "NAs introduced by coercion"); they are now removed. An outlier whose
  date cannot be read, or whose period lies outside the year, is an error
  (`rcli_error_outliers`).
* `tramo_outliers(remove = ...)` with level shifts or transitory changes:
  the regARIMA forecasts used to extend the series now continue the removed
  effects (a level shift unchanged, a transitory change decaying at the
  rate of the engine: 0.7 for TRAMO, 0.7^(12/f) for X-13, i.e. 0.343 for
  quarterly data), so the clean series no longer jumps where it meets its
  forecasts.
* `robust_outliers()` (the default) also replaces an extreme change at the
  first observation, which the two-sided rule could never flag. The last
  observation is deliberately left alone: an extreme last change cannot be
  told apart from a level shift or a turn until the next observation
  arrives, and it is the newest signal of the indicator.
* `conference_board()` computes its symmetric changes from the seasonally
  adjusted, cleaned and transformed series instead of the original data,
  so seasonal adjustment and outlier treatment now apply to it.
* `cli_presentation()` compares the composite with the seasonally adjusted
  and cleaned reference series, not with the original data.
* `cli_selection_bias()` (and the out-of-sample check of `cli_build()`)
  evaluates the composite after a cut-off with the lag shifts of the
  composite selected before it; with `lag_shift = TRUE` (as in
  `oecd_spec()`) the in-sample and later leads were measured on different
  composites.

## Robustness

* `window()` on a candidate set outside the data is an
  `rcli_error_short_series`, so a cut-off before the data start gives a
  note in the out-of-sample check instead of stopping `cli_build()`.
* `cli_candidates()` drops candidates without any observation (also from
  the data vintages), with a warning (`rcli_warning_dropped`), and refuses
  an empty or constant reference series.
* Invalid specifications from `cli_spec()` and `update()` give
  `rcli_error_argument`; scalar settings other than `horizon` must not be
  `NA`, and `max_iter`, `min_components`, `ccf_lag_max`, `granger_max_lag`,
  `granger_dmax` and `horizon` must be whole numbers. `cli_validate()`
  checks `spec` and `cli_composite()` checks `reference`.
* The cross-correlation needs two years of overlap (24 months as before, 8
  quarters instead of 24), and candidates whose cross-correlation or
  Granger test cannot be computed are named in a warning
  (`rcli_warning_short_series`).
* `principal_component()` and `dynamic_factor()` warn when they fall back
  to equal weights with two or more components (`rcli_warning_fallback`),
  and the composite records the aggregator actually used; with a single
  component this is `equal_weight()`, which `print()` and the GUI now
  show.

## Documentation

* `?cli_spec`: `horizon = NA` uses the lag of the cross-correlation peak.
  `?oecd_spec`: quarterly candidates are always interpolated linearly.

# rcli 0.5.0

An audit of the package against the interface found options that only code
could use. This release brings them into the interface; the exported script
reproduces each of them.

## Graphical interface

* Step 3: with seasonal adjustment, *Remove the Idulfitri effect* adds
  `holiday_effect(idulfitri_dates())` to the specification (both methods).
* Step 3: *Advanced options* for the rcli method: the candidate classifier
  (rcli or OECD median lead), the outlier treatment (robust z or TRAMO) and
  the OECD lag shift, each on its own; the parameters of the chosen cycle
  filter and of the turning-point dating rule (Bry-Boschan or BBQ); the
  coincident band, the turning-point pairing window, the target lead, the
  largest cross-correlation and Granger lags, the extra Toda-Yamamoto lags,
  the horizon of the probability tests, the minimum share of components of
  the aggregation and the horizon and order of the AR end extension. Empty
  entries keep the package defaults (which may depend on the frequency) and
  stay out of the script; invalid entries stop step 3 with the package's
  message.
* Step 2 (several files): the disaggregation of the reference series
  (Denton-Cholette, Chow-Lin with an indicator series of the analysis
  frequency, which then is not a candidate, or linear interpolation; shown
  only when the reference is converted), the dates of weekly data (start or
  end of the week) and the minimum coverage of daily and weekly data.
* Step 7 shows the three OECD forms of the composite (amplitude adjusted,
  trend restored, rate of change over a year) next to the matching form of
  the reference series; step 10 downloads them as CSV.
* Steps 2 and 3 now run the very code they write into the script, so the
  interface and the script cannot differ. Series names from file names and
  column headers are written so that they read back exactly, whatever
  characters they hold; every input is checked (a single finite number, or
  one of the offered choices, within limits checked on the server) before
  it becomes code, and the code is refused unless it names only the
  functions that step uses and a few operators. The reference series and the components are written the same
  way in the script. Whole numbers are written without the `L` suffix.

## Presentation

* `cli_presentation()` gains `composite`, to present a composite chosen by
  hand with `cli_composite()`, and the column
  `reference_amplitude_adjusted` (the reference without trend, in the units
  of the amplitude-adjusted CLI).
* For a reference that is not logged (a balance that may cross zero),
  `cli_presentation()` now measures deviations in percent of the mean
  absolute level, as the amplitude of the composite does, and restores the
  trend by adding them to it; before, it multiplied by a trend that could be
  near zero or negative, which inverted or blew up the trend-restored form.

# rcli 0.4.0

## Data input

* New `read_cli_series()` reads several CSV files, one or more indicators
  per file, as statistical offices often publish them. The first column of
  each file holds dates (`2001-01-15`, `15/01/2001`, `2001-01`, `2001Q1`,
  `2001S1` or `2001`, one form per file); every other numeric column
  becomes a series, and a column called `value` or `nilai` takes the name
  of its file. The column separator and the decimal mark are recognised
  per file, as in the interface since 0.3.1. Each series is a data frame
  with `date` and `value`, carries its recognised source frequency, and
  goes straight into `cli_align()`. A date that does not fit is reported
  with its file name and value (`rcli_error_dates`); two series with the
  same name and a value column without a name are refused, naming the
  file, and so are day-first dates that look like month/day/year; a series
  with fewer than two observations is dropped with a warning. Cells such as `-`, `..`
  or `#N/A` (argument `na`) count as missing values, and Excel date-times
  at midnight are read as dates.
* `cli_candidates()`: an empty `type` or `frequency` in `meta` no longer
  overwrites what `cli_align()` recorded for that candidate.

## Graphical interface

* Step 1 gains the source *Upload several files (one per indicator)*: the
  files may have different frequencies (daily to annual for the
  reference), and an *Analysis frequency* (monthly or quarterly) is chosen.
  The summary lists each series with its file, source frequency, start,
  end and number of observations; the overview plot puts all series on one
  time axis. Inputs that do not apply to the chosen source are hidden.
* Step 2 then asks for the variable type of the reference series as well
  (cleared when another reference is chosen), shows the source frequencies
  that were recognised, and aligns all
  series with `cli_align()` before building the candidate set. A series
  that must be converted but has no type stops step 2 with a message.
  Changing the analysis frequency after the files were read clears step 2
  and the later steps.
* The exported script reads the files with `read_cli_series()` and aligns
  them with the same `cli_align()` call, so it reproduces the analysis,
  also when the coincident index later becomes the reference.

# rcli 0.3.1

## Graphical interface

* Step 1 gains *Column separator* (automatic, comma, semicolon, tab) and
  *Decimal mark* (automatic, point, comma) for an uploaded file, so CSV
  files saved by Excel with Indonesian settings (semicolons and decimal
  commas) can be read. The automatic choice takes the separator that
  splits every line into the same number of fields (quotes respected, so
  commas inside column names do not mislead it), preferring tab, then
  semicolon, then comma, and the decimal mark that most unambiguous cells
  use. Whole numbers with a thousands separator (`1.012`, `12,345`) are no
  evidence (`0,125` is, since thousands never follow a leading zero); when
  nothing else decides, such a column is dropped with a warning instead
  of being read as 1.012. Files in Windows-1252 encoding are read in UTF-8
  sessions as well. A separator equal to the decimal mark is an error, and
  "No numeric column found" now points at the separator and decimal mark.
  The upload also accepts `.txt` and `.tsv` files.
* The exported script passes the format actually used to
  `read_cli_data()` (`sep`, `dec`) when it differs from the `read.csv()`
  defaults, and `check.names = FALSE` as the interface does, so column
  names with spaces survive; file names are quoted safely.

## Data input

* `read_cli_data()` ignores a UTF-8 byte-order mark at the start of the
  file and an empty, unnamed column left by a separator at the end of
  every line, and warns (`rcli_warning_dropped`) when it drops columns
  without numbers, which usually means a wrong decimal mark or thousands
  separators.

## Documentation

* The help pages are now written from Markdown (`Roxygen: list(markdown =
  TRUE)`): code shows as code and `[function()]` references are links.

# rcli 0.3.0

New exported functions and arguments (the source frequency of every series)
and interface features, so the minor version changes; no default changes.

## Graphical interface

* The title shows the package version and names both indices ("rcli
  0.3.0: Composite Leading and Coincident Indicators"; in Indonesian
  "Indikator Komposit Pendahulu dan Sejalan").
* Step 9 gains a button that makes the coincident index the reference
  series of a new analysis (`cci_as_reference()`): steps 1 and 2 are filled
  with the new candidate set, without the former reference and the
  components of the index, the candidate metadata is kept, and the user
  continues from step 3. The exported R script reproduces the whole chain:
  the first analysis, `cand <- cci_as_reference(cci)`, and the analysis
  against the index (with `cli_candidates(cand@data, ...)` when the
  metadata is edited again). Loading data in step 1 starts from scratch.
* The entries of step 2 follow the candidate names when the list of
  candidates changes (another reference series, or the coincident index
  as reference), instead of their position.
* The exported script uses the data source and seed as they were when
  step 1 ran, and a manual composite from before a reset of the later
  steps no longer leaks into it.
* Step 2 gains a *Source frequency* column (daily to annual); the values
  enter the metadata and the exported script. A semiannual or annual
  candidate is refused with a message, and a refused step 2 clears its
  earlier result.

## Source frequencies

* New `series_frequencies`: daily, weekly, monthly, quarterly, semiannual
  and annual. `cli_candidates()` keeps the source frequency of every
  candidate in the metadata (`frequency`), from `meta` or from the record
  of `cli_align()`; a semiannual or annual candidate is an error
  (`rcli_error_frequency`), because one or two values a year cannot show a
  lead of a few months.
* `cli_align()` recognises semiannual and annual data (dated data frames,
  or `ts` of frequency 2 and 1). Such a series can be the reference and is
  disaggregated to months or quarters: the Denton-Cholette method now
  takes any aggregation ratio (harness/02-math/F-04.md; it agrees with
  `tempdisagg` and, for quarters to months, with 0.2.1), Chow-Lin takes an
  indicator at the target frequency, and `method = "linear"` places each
  value in the middle (flows, averages) or at the end (stocks) of its
  period.
* `cli_align(frequency = )` declares source frequencies; a series whose
  dates show another frequency is an error naming both.
* The printed candidate set shows the source frequencies when any is
  known, as it does for the types.
* A source frequency given in `meta` must agree with the one `cli_align()`
  found; a semiannual or annual candidate is refused before its type is
  asked for.
* `position` also places the values of a semiannual or annual reference
  for `method = "linear"` (1 to k subperiods).
* `cli_quality()` notes a disaggregated reference of any source frequency:
  its turning-point dates are uncertain by about one month (quarterly),
  3 months (semiannual) or 6 months (annual). It used to note only the
  quarterly case.

# rcli 0.2.1

The coincident index prepared as 0.1.4 (never released) is merged into
the 0.2 series. It adds functions without changing any default, so the
version stays in the 0.2 series at the maintainer's request.

## Faster HP filter

* The HP trend (used by `hp_filter()`, `hp_double_filter()`, the default
  filter, and `cli_presentation()`) is now computed with a banded LDL'
  factorisation of its pentadiagonal system in O(n) time and memory instead
  of a dense `solve()` in O(n^3) time and O(n^2) memory. Results agree with
  0.2.0 to about 1e-10 relative; both are backward stable. `cli_cycles()`
  now takes about 3 ms instead of about 80 ms per monthly series of 30
  years, so the AR extension that became the default in 0.2.0 costs less
  than the filter of 0.1.3 without it. Series of 100,000 observations no
  longer need 80 GB of memory.

## Coincident index

A coincident index summarises the current state of the cycle, as the
Conference Board coincident economic index does next to its leading index.
The candidates that `cli_assess()` already classified as coincident are now
used instead of discarded.

* `cci_build()`: aggregates the coincident candidates with the aggregator
  of the specification (the same machinery as `cli_build()`, without
  lag-shifting), validates the index and removes components by backward
  elimination until it passes. It takes a `CliResult`, so that the leading
  and the coincident index come from one run, or a `CandidateSet`.
  `components` sets the starting components and `select = FALSE` keeps
  them all. Returns a `CciResult`, a subclass of `CliResult`, so the usual
  accessors, `plot()`, `summary()` and `cli_quality()` work.
* `cci_validate()` and the generic `coincident_criteria()`: timing in place
  of lead. The default rule asks for a cross-correlation peak within
  `coincident_band`, a median lead at turning points within +/- 2 months
  (one period for quarterly data), few missed and extra turning points and
  significant concordance; Granger causality is not required. With
  `oecd_classifier()` the median lead must lie strictly inside the OECD
  coincident band. The current contraction state (horizon 0) is scored by
  QPS, AUC and the Pesaran-Timmermann test.
* `coincidents()` lists the candidates classified as coincident.
* `cci_as_reference()` turns a coincident index into the reference series
  of a new `CandidateSet`, dropping the former reference and the components
  of the index, so a monthly index can replace a disaggregated quarterly
  reference.
* `cli_selection_bias(role = "coincident")` checks the timing of the index
  after cut-off dates; the output gains `pct_timely_out`. `cci_build()`
  runs it when `oos_cutoffs` is set, so a coincident index can reach the
  verdict "good".
* `CliValidation` gains a `role` slot (`"leading"` or `"coincident"`) that
  the scorecard, `show()` and the selection-bias check follow. Objects saved
  by earlier versions count as leading.
* `data-raw/calibrate_coincident.R` and `inst/calibration/coincident.csv`:
  Monte Carlo pass rates of the coincident criteria (100 replications). At
  the default noise level 96 percent (monthly) and 99 percent (quarterly)
  of truly coincident composites pass and at most 1 percent of composites
  that lead or lag by 3 months; with twice the noise the quarterly rates
  are 65 and 15 percent. The rates were computed with the 0.2 defaults
  and moved by at most 2 points against those of the 0.1.x defaults; the
  simulated panels are complete, so only the AR extension made a
  difference (a test checks the chain at a ragged edge separately).
  Without the one-period floor of the timing band only 82.5 percent of
  truly coincident quarterly composites passed.

## Graphical interface

* New step 9, *Coincident index*: automatic selection or a manual choice of
  components, the verdict, the index against the reference cycle, weights,
  components, scorecard and audit log. It needs only step 6, so rebuilding
  the composite in step 7 keeps it. Export moves to step 10 and gains the
  index and its scorecard as CSV; the exported script adds `cci_build()`.
  Indonesian and English text.

## Other changes

* The timing band of a coincident index, whether a lead lies inside it,
  and the texts of its scorecard rules are internal methods of the
  classifier instead of a branch on its class, so the OECD band is open
  both in sample and after the cut-offs (it was closed after them). The
  legend of `plot()` for a coincident index comes from a method as well.
  The role of a validation (`"leading"` or `"coincident"`) is a value and
  still selects the criteria.
* `hp_filter(Inf)` and `hp_double_filter()` with an infinite period are
  errors instead of giving a cycle of `NaN`.
* The printed validation summary shows the reason (`note`) for cut-off
  dates without a composite, for example when no candidate was coincident
  in the training window.
* The test of the TRAMO/X-13 engine choice no longer needs 'seasonal'
  installed (it failed on machines without it).

# rcli 0.2.0

## New defaults (results at the end of the sample change)

Two steps that the OECD does better at the end of the sample are now on by
default, in the form a simulation study found best (vignette, section 8):

* `equal_weight()` gains `ragged_edge = c("chain", "level")`. With the new
  default `"chain"`, the dates after the last date at which all components
  are observed are filled by adding the average change of the components
  available at both dates to the previous value, so that a component
  published late no longer makes the end of the composite jump. Before that
  date the composite is the plain mean as before; with complete data the
  composite is identical to 0.1.x. Unlike the full OECD chain
  (`oecd_aggregate()`), a component that starts late leaves the composite
  unchanged. In real-time simulations the direction of the last monthly
  change was right in 80 percent of vintages instead of 72 percent.
* New strategy class `Extension` with `ar_extension()` (default) and
  `no_extension()`, generic `extend_series()` and `cli_spec(extension = )`:
  each series is extended by one year of forecasts from an autoregressive
  model of its changes (`stats::ar()`, no new dependency) before the cycle
  filter. The revision of the last value of the composite fell by 18 to 23
  percent (`data-raw/realtime_defaults.R`,
  `inst/calibration/realtime-defaults.csv`), at a cost of about 8 ms per
  series. Forecasts from `tramo_outliers()` take precedence;
  `oecd_spec()` uses no AR extension. Note that
  `tramo_outliers(forecast = 0)` no longer means "no forecasts" on its own:
  the AR extension then applies unless `extension = no_extension()`.
* The calibration harness was run again with the new defaults
  (`inst/calibration/accuracy.csv`); the classification thresholds stand.
* To reproduce rcli 0.1.x exactly:
  `cli_spec(aggregator = equal_weight(ragged_edge = "level"),
  extension = no_extension())`; a test checks this against a composite
  computed with rcli 0.1.3. Objects saved with 0.1.x keep their old
  behaviour, and `update()` fills their missing fields accordingly; the
  one exception is the plain equal-weights fallback of
  `principal_component()` and `dynamic_factor()`, which now chains at the
  ragged edge.

## Other changes

* The graphical interface offers "Equal weights, chained at the ragged edge"
  (default) and "Equal weights, plain mean (rcli 0.1)" and a check box for
  the AR extension; the exported script reproduces either.
* `CliSpec` prints the end-of-series extension. `cli_spec()` checks the
  class of `classifier`, `outliers` and `extension`.
* Mathematical verification of the new aggregation (propositions, symbolic
  and numerical checks, independent review) is kept in `harness/02-math/`
  of the source repository.

# rcli 0.1.3

## The OECD method as an option

Every step of the OECD system (Gyomai and Guidetti 2012) is now available,
and `oecd_spec()` sets them all at once. The defaults do not change.

* `oecd_classifier()`: the OECD median-lead table (coincident within
  +/- 2 months, leading from 2 months, longer leading over 8, lagging at
  -2 or less). New strategy class `Classifier` with the generics
  `classify_candidate()`, `leading_criteria()` and `quality_criteria()`;
  `rcli_classifier()` is the default rule. `cli_spec(classifier = )`.
* `tramo_outliers()`: additive outliers, transitory changes and level
  shifts detected by TRAMO (through 'RJDemetra', new in Suggests, needs
  Java) or by the regARIMA part of X-13 ('seasonal'); AO and TC effects are
  removed and the series is extended with forecasts before the cycle
  filter. New strategy class `OutlierTreatment` with `robust_outliers()`
  (the previous rule, still the default) and `cli_spec(outliers = )`.
* `cli_spec(transform = "test")`: logarithm or levels from the regARIMA
  log/level test, as TRAMO decides at the OECD.
* `oecd_aggregate()`: the average growth of the components chained into
  the index, with the 60 percent rule.
* `cli_spec(lag_shift = TRUE)` and `lag_shifts()`: components are moved so
  that their median leads align; `cli_composite(shifts = )` and the new
  `shifts` slot of `CompositeIndex`.
* `cli_presentation()`: the three OECD forms of a composite (amplitude
  adjusted, trend restored, 12-month rate of change) next to the reference.
* The graphical interface offers the method (rcli or OECD) in step 3, the
  chained aggregation and the log test; the exported script reproduces the
  OECD composite, including lag shifts in manual mode.

## Evidence for the defaults

* `data-raw/compare_oecd.R` compares the defaults with the OECD options on
  simulated data (`inst/calibration/oecd-*.csv`, vignette section 8). The
  median-lead rule labels 20 to 28 percent of non-leading candidates
  leading against at most 1.3 percent for the default rule; lag-shifting
  shortens the lead of the composite by about three months; the chained
  OECD aggregation is identical in sample and more than halves the error at
  a ragged edge, so it is recommended for real-time work.

# rcli 0.1.1

* `cli_align()` brings daily, weekly, monthly and quarterly series to one
  frequency with rules set by the variable type (`series_types`: flow,
  stock, average). Weekly data are spread over days before they are summed
  into months. A quarterly reference series is disaggregated to months with
  the Denton-Cholette method (computed in the package, identical to
  'tempdisagg'), Chow-Lin (needs 'tempdisagg', now in Suggests) or linear
  interpolation; quarterly candidates are interpolated at the central month
  (last month for stocks), as the OECD does.
* `cli_candidates()` keeps the conversion record of `cli_align()` (new slot
  `alignment` of `CandidateSet`) and a `type` column in the metadata.
* `cli_quality()` adds an information row and a note when the reference
  series was disaggregated from quarterly data.
* `holiday_effect()` and `idulfitri_dates()`: moving-holiday regressors
  (such as Idulfitri) for X-13ARIMA-SEATS through
  `cli_spec(seasonal_adjust = TRUE, holidays = ...)`.
* The graphical interface records the variable type of each candidate in
  step 2 and in the exported script; the remaining English words in the
  Indonesian scorecard are translated.
* `CliSpec` prints the Granger criterion and the seasonal adjustment.
* The virtual classes `CycleFilter`, `Dater` and `Aggregator` are exported
  so that users can add their own methods.
* Objects saved with rcli 0.1.0 still work: the new slots are optional.

# rcli 0.1.0

* First release (developed under the working name 'leadcli').
* Quality scorecard `cli_quality()` with a good / acceptable / weak verdict
  from turning-point, prediction and out-of-sample criteria;
  `contraction_probability()` and `roc_curve()`.
* Step-by-step graphical interface `run_app()` (Indonesian or English) with
  plots for every step and export of results and a reproducible R script;
  `read_cli_data()` reads CSV files with a date column.
* Cycle filters: Hodrick-Prescott, OECD double Hodrick-Prescott,
  Christiano-Fitzgerald, Baxter-King and Hamilton; all replicate mFilter and
  neverhpfilter to machine precision.
* Turning points: Bry-Boschan (monthly) and Harding-Pagan BBQ (quarterly)
  censoring rules, checked against BCDating (golden file) and Coinprofile.
* Classification of candidates as leading, coincident, lagging or rejected
  from cross-correlation, turning-point leads, concordance and a Toda-Yamamoto
  Granger test, with default thresholds calibrated by Monte Carlo
  simulation.
* Aggregation with equal weights, principal components, Conference Board
  standardisation factors or a two-step dynamic factor model.
* Validation with turning-point statistics, quadratic probability score,
  area under the ROC curve and the Pesaran-Timmermann test; backward
  selection loop with an audit log; selection-bias harness for out-of-sample
  leads.
