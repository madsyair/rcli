# the scorecard prints by group

    Code
      cli_quality(cli_build(cand))
    Output
      <CliQuality> verdict: ACCEPTABLE
        Turning-point and prediction criteria are met; run the out-of-sample check of the selection (oos_cutoffs) before relying on the lead.
      
        turning points
         criterion                      value   threshold         status
         matched turning points           16    >= 3              pass  
         cross-correlation lead            4    >= 3, positive    pass  
         median lead at turning points     5    >= 1              pass  
         share of turning points led    0.941   >= 0.5            pass  
         share of missed turning points 0.0588  <= 0.4            pass  
         share of extra turning points  0.0588  <= 0.4            pass  
         concordance                    0.87    > 0.502, p < 0.05 pass  
         Granger causality p-value      8.9e-13 < 0.05            pass  
      
        prediction
         criterion                   value threshold       status
         out-of-sample forecasts      210  >= 20           pass  
         area under the ROC curve    0.86  >= 0.7          pass  
         quadratic probability score  0.3  < 0.526 (naive) pass  
         Pesaran-Timmermann p-value  1e-04 < 0.05          pass  
      
        information
         criterion                         value threshold status
         lead within the OECD target range    4  6 to 9    info  

