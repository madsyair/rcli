# assessments print

    Code
      a
    Output
      <LeadAssessment> leading: 3, coincident: 1, lagging: 1, rejected: 2
             name      class lead median  led missed extra conc granger_p
           lead_6    leading    6    6.0 0.89   0/18     0 0.93   6.8e-19
           lead_3    leading    3    3.0 0.89   0/18     0 0.90   1.3e-20
       coincident coincident    0    0.0 0.39   0/18     0 0.91   3.4e-08
            lag_3    lagging   -3   -3.0 0.06   1/18     4 0.87   6.3e-02
       counter_4*    leading    4    4.5 0.94   0/18     0 0.89   1.5e-19
         noise_1*   rejected    7    2.5 0.56   0/18     7 0.64   3.0e-01
          noise_2   rejected  -24    1.0 0.44   3/18    10 0.52   1.1e-01
      lead: cross-correlation lead; median: median lead at turning points;
      led: share of reference turning points led; conc: concordance
      * inverted (counter-cyclical)

