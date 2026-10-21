# the scorecard prints by group

    Code
      cli_quality(cli_build(cand))
    Output
      <CliQuality> verdict: ACCEPTABLE
        In-sample criteria are met; run the out-of-sample check (oos_cutoffs) before relying on the lead.
      
        turning points
         criterion                      value   threshold         status
         matched turning points           15    >= 3              pass  
         cross-correlation lead            4    >= 3, positive    pass  
         median lead at turning points     5    >= 1              pass  
         share of turning points led    0.882   >= 0.5            pass  
         share of missed turning points 0.118   <= 0.4            pass  
         share of extra turning points  0       <= 0.4            pass  
         concordance                    0.882   > 0.501, p < 0.05 pass  
         Granger causality p-value      5.9e-13 < 0.05            pass  
      
        prediction
         criterion                   value   threshold       status
         area under the ROC curve    0.944   >= 0.7          pass  
         quadratic probability score 0.186   < 0.497 (naive) pass  
         Pesaran-Timmermann p-value  4.1e-36 < 0.05          pass  
      
        information
         criterion                         value threshold status
         lead within the OECD target range    4  6 to 9    info  

