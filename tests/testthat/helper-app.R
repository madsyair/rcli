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

# FR-009: one file per indicator, at different frequencies (a quarterly
# reference, an Indonesian Excel file with four monthly indicators and a
# quarterly flow), as a data frame like the value of a fileInput().
multi_files <- function() {
  sim <- simulate_cycles(seed = 1)
  dir <- tempfile("multi")
  dir.create(dir)
  q <- stats::aggregate(sim, nfrequency = 4, FUN = mean)
  qd <- paste0(floor(stats::time(q) + 1e-6), "Q", stats::cycle(q))
  md <- format(seq(as.Date("1995-01-01"), by = "month",
                   length.out = nrow(sim)), "%Y-%m")
  num <- function(x) sprintf("%.15g", x)
  writeLines(c("date,value", paste0(qd, ",", num(q[, "reference"]))),
             file.path(dir, "pdb.csv"))
  # an Indonesian Excel file with several indicators
  ind <- c("lead_6", "lead_3", "coincident", "lag_3")
  body <- apply(sim[, ind], 1, function(r) {
    paste(gsub(".", ",", num(r), fixed = TRUE), collapse = ";")
  })
  writeLines(c(paste(c("tanggal", ind), collapse = ";"),
               paste(md, body, sep = ";")), file.path(dir, "indikator.csv"))
  q4 <- stats::aggregate(sim[, "counter_4"], nfrequency = 4, FUN = sum)
  writeLines(c("date,nilai", paste0(qd, ",", num(q4))),
             file.path(dir, "counter.csv"))
  names <- c("pdb.csv", "indikator.csv", "counter.csv")
  data.frame(name = names, size = 1, type = "text/csv",
             datapath = file.path(dir, names), stringsAsFactors = FALSE)
}
