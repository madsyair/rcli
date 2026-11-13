# Test fixture tests/testthat/fixtures/oecd-idn.rds from the snapshot of
# data-raw/oecd_idn_fetch.R: the OECD normalised CLI, reference series and
# components (NOR), the amplitude-adjusted CLI (LI_AA) and the reference
# series as ratio to trend (RS_RT), monthly from 1990-01. Run from the
# package root:  Rscript data-raw/oecd_idn_fixture.R
all <- utils::read.csv("data-raw/oecd-idn/oecd-idn.csv",
                       stringsAsFactors = FALSE)
pick <- all[all$dataflow == "DF_CLI" & all$transformation != "GY" &
              (all$adjustment == "NOR" |
                 (all$measure == "LI" & all$adjustment == "AA") |
                 (all$measure == "RS" & all$adjustment == "RT")), ]
pick$column <- ifelse(pick$adjustment == "NOR", pick$measure,
                      paste(pick$measure, pick$adjustment, sep = "_"))
months <- format(seq(as.Date("1990-01-01"),
                     as.Date(paste0(max(pick$period), "-01")), by = "month"),
                 "%Y-%m")
fixture <- sapply(split(pick, pick$column), function(s) {
  s$value[match(months, s$period)]
})
saveRDS(list(snapshot = readLines("data-raw/oecd-idn/SNAPSHOT")[1],
             start = c(1990L, 1L), data = round(fixture, 5)),
        "tests/testthat/fixtures/oecd-idn.rds", version = 2)
