# Runs steps 1 to 7 of the interface in shiny::testServer().
run_all_steps <- function(session, source = "example_m", mode = "auto",
                          cutoffs = "2012, 2016", method = "rcli",
                          aggregator = "equal", extend = TRUE) {
  session$setInputs(source = source, seed = 1, freq = "auto", start = "",
                    run1 = 1)
  session$setInputs(reference = "reference")
  n <- length(setdiff(colnames(session$userData$data()), "reference"))
  inputs <- stats::setNames(as.list(rep("early_stage", n)),
                            paste0("rat_", seq_len(n)))
  do.call(session$setInputs, inputs)
  session$setInputs(typ_1 = "stock", typ_2 = "flow")
  session$setInputs(run2 = 1)
  session$setInputs(method = method, filter = "hp_double",
                    aggregator = aggregator, extend = extend,
                    transform = "auto", seasonal = FALSE, outlier = 5,
                    min_lead = 3, min_median_lead = 1, min_consistency = 0.5,
                    max_missed = 0.4, max_extra = 0.4, alpha = 0.05,
                    min_auc = 0.7, min_components = 2, max_iter = 10,
                    oos_cutoffs = cutoffs, run3 = 1)
  session$setInputs(run4 = 1)
  session$setInputs(cyc_series = "lead_6", tp_series = "reference",
                    as_series = "lead_6", run5 = 1)
  session$setInputs(run6 = 1)
  session$setInputs(comp_mode = mode,
                    manual_components = c("lead_6", "lead_3"), run7 = 1)
}
