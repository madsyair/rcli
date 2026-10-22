# specification objects print

    Code
      cli_spec(12)
    Output
      <CliSpec> monthly composite leading indicator
        filter:      OECD double Hodrick-Prescott
        dating:      Bry-Boschan
        aggregation: Equal weights
        leading if:  cross-correlation lead >= 3 months, median lead >= 1, leads >= 50% of turning points,
                     missed and extra <= 40% and 40%, concordance and Granger causality significant at 0.05
        loop:        at most 10 iterations, at least 2 components

---

    Code
      cli_spec(4, filter = cf_filter(6, 32))
    Output
      <CliSpec> quarterly composite leading indicator
        filter:      Christiano-Fitzgerald
        dating:      Harding-Pagan BBQ
        aggregation: Equal weights
        leading if:  cross-correlation lead >= 1 quarters, median lead >= 0.5, leads >= 50% of turning points,
                     missed and extra <= 40% and 40%, concordance and Granger causality significant at 0.05
        loop:        at most 10 iterations, at least 2 components

---

    Code
      hp_double_filter()
    Output
      <HPDoubleFilter> OECD double Hodrick-Prescott
        trend_period: default
        smooth_period: default

---

    Code
      bbq()
    Output
      <BBQ> Harding-Pagan BBQ
        window: default
        min_phase: default
        min_cycle: default
        end_exclusion: default

---

    Code
      conference_board()
    Output
      <ConferenceBoard> Conference Board standardisation
        min_coverage: 0.6

