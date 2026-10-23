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
