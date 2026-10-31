# rcli

<!-- badges: start -->
[![R-CMD-check](https://github.com/madsyair/rcli/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/madsyair/rcli/actions/workflows/R-CMD-check.yaml)
[![test-coverage](https://github.com/madsyair/rcli/actions/workflows/test-coverage.yaml/badge.svg)](https://github.com/madsyair/rcli/actions/workflows/test-coverage.yaml)
[![lint](https://github.com/madsyair/rcli/actions/workflows/lint.yaml/badge.svg)](https://github.com/madsyair/rcli/actions/workflows/lint.yaml)
<!-- badges: end -->

`rcli` builds composite leading indicators (CLI), and the coincident index
that goes with them, from the selection of candidate series to a tested
composite, following the OECD system of composite leading indicators:

1. **Candidates** – a reference series and candidate series with their
   economic rationale (`cli_candidates()`).
2. **Specification** – every methodological choice in one validated object
   (`cli_spec()`).
3. **Cycles** – log transformation, outlier treatment, optional seasonal
   adjustment, one year of AR forecasts appended to stabilise the end of the
   series, and one of five filters: Hodrick-Prescott, OECD double HP,
   Christiano-Fitzgerald, Baxter-King or Hamilton (`cli_cycles()`).
4. **Turning points** – Bry-Boschan and Harding-Pagan BBQ rules
   (`cli_turning_points()`).
5. **Classification** – leading, coincident, lagging or rejected, from the
   cross-correlation lead, leads at turning points, concordance and a
   Toda-Yamamoto Granger test (`cli_assess()`).
6. **Aggregation** – equal weights chained at the ragged edge, the OECD
   chained growth, principal components, Conference Board standardisation
   or a dynamic factor model (`cli_composite()`).
7. **Validation** – turning-point statistics, QPS, AUC and the
   Pesaran-Timmermann test (`cli_validate()`), plus a check of the selection
   bias of in-sample leads (`cli_selection_bias()`).
8. **Selection loop** – components are dropped until the composite passes,
   with an audit log (`cli_build()`).
9. **Quality verdict** – a scorecard of turning-point, prediction and
   out-of-sample criteria returns *good*, *acceptable* or *weak*
   (`cli_quality()`).
10. **Coincident index** – the coincident candidates aggregated the same
    way and tested for timing instead of lead (`cci_build()`,
    `cci_validate()`); `cci_as_reference()` makes the index the monthly
    reference series.

`oecd_spec()` follows the OECD method step by step instead: TRAMO
outliers with forecasts, the log/level test, the median-lead
classification, lag-shifting and the chained average growth of the
components; `cli_presentation()` gives the three OECD forms of the
composite. The vignette explains, with simulations, where and why the
defaults differ.

Series of mixed frequencies (daily, weekly, monthly, quarterly) and types
(flow, stock, average), read from one file per indicator with
`read_cli_series()`, are brought to one frequency with `cli_align()`, and
moving holidays such as Idulfitri are removed during seasonal adjustment with
`holiday_effect()`.

A Shiny interface runs the same steps with plots for each of them:
`run_app()` (Indonesian) or `run_app(language = "en")`.

## Installation

`rcli` is not on CRAN yet. Install the development version from
[GitHub](https://github.com/madsyair/rcli):

``` r
# install.packages("remotes")
remotes::install_github("madsyair/rcli")

# or, with pak
# install.packages("pak")
pak::pak("madsyair/rcli")
```

To build the vignette as well:

``` r
remotes::install_github("madsyair/rcli", build_vignettes = TRUE)
```

The core of the package needs only base R (R >= 4.1.0). Optional features
use packages listed in `Suggests`:

``` r
install.packages("shiny")     # graphical interface, run_app()
install.packages("seasonal")  # X-13ARIMA-SEATS, cli_spec(seasonal_adjust = TRUE)
```

Check the installation:

``` r
library(rcli)
packageVersion("rcli")
run_app()   # opens the step-by-step interface in the browser
```

## Example

``` r
library(rcli)

sim  <- simulate_cycles(seed = 2026)                 # known leads
meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
cand <- cli_candidates(sim, reference = "reference", meta = meta)

res <- cli_build(cand, cli_spec(freq = 12, oos_cutoffs = 2015))
res
assessment(res)   # why each candidate was kept or rejected
audit_log(res)    # decisions of the selection loop
cli_quality(res)  # is the composite good enough?
plot(res)
```

## Mixed frequencies

``` r
gdp_q <- aggregate(sim[, "reference"], nfrequency = 4, FUN = sum)
weeks <- seq(as.Date("1995-01-02"), as.Date("2024-12-23"), by = "week")
sales <- data.frame(date = weeks, value = 700)
x <- cli_align(list(gdp = gdp_q, sim[, -1], sales = sales),
               type = c(gdp = "flow", sales = "flow"), reference = "gdp")
attr(x, "alignment")          # how each series was converted
meta_x <- data.frame(name = colnames(x)[-1], rationale = "early_stage")
cand <- cli_candidates(x, reference = "gdp", meta = meta_x)
```

| Type | Examples | Higher to lower frequency | Quarterly to monthly |
|---|---|---|---|
| `flow` | GDP, production, sales | sum | Denton-Cholette (reference) or central month |
| `stock` | money, outstanding credit | end of period | last month |
| `average` | prices, rates, survey balances | mean | central month |

## Graphical interface

`run_app()` opens a Shiny application that walks through ten steps (data,
candidate metadata, specification, cycles, turning points, classification,
composite, validation with the quality scorecard, coincident index, and
export). Each step
unlocks the next one, and the export step writes an R script that reproduces
the analysis. `rcli_app()` returns the application object for deployment on
Shiny Server or Posit Connect (`system.file("app", package = "rcli")`).

## Guidebook (in Indonesian)

The folder [`pedoman/`](pedoman) holds a Quarto book, *Pedoman Penyusunan
Indikator Komposit Pendahulu*, with the theory behind each step, worked
examples with interpretation, a case study and a screenshot guide to the
graphical interface. Render it with `quarto render --to all` from that
folder.

## Quality harness

* Filters replicate `mFilter` and `neverhpfilter` to machine precision.
* Turning points agree with `Coinprofile` and with a golden file of
  `BCDating` results (archived from CRAN in May 2026).
* Default classification thresholds are calibrated by Monte Carlo
  simulation (`data-raw/`); on simulated monthly data no non-leading series
  is labelled leading.
* `R CMD check --as-cran` runs on Windows, macOS and Linux in GitHub Actions.

## References

Gyomai, G. and Guidetti, E. (2012). *OECD System of Composite Leading
Indicators*. OECD.

Harding, D. and Pagan, A. (2002). Dissecting the cycle: a methodological
investigation. *Journal of Monetary Economics*, 49(2), 365–381.

Marcellino, M. (2006). Leading indicators. *Handbook of Economic
Forecasting*, Vol. 1, 879–960.

## Bug reports

Please report problems at <https://github.com/madsyair/rcli/issues>.
