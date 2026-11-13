# Download the OECD data behind the composite leading indicator (CLI) of
# Indonesia and save a snapshot, so that data-raw/oecd_idn_validate.R runs
# without internet access. Run from the package root:
#   Rscript data-raw/oecd_idn_fetch.R
#
# Source: OECD Data Explorer, SDMX REST API (https://sdmx.oecd.org/public/
# rest/), monthly series of Indonesia (REF_AREA = IDN):
#   DF_CLI      the CLI (LI), the reference series (RS, GDP) and the seven
#               components of the Indonesian CLI, normalised by the OECD
#               (LOCO*); the components are published only in this form
#   DF_FINMARK  share prices, call-money and three-month interbank rates,
#               rupiah per US dollar (original values)
#   DF_CS       composite consumer confidence (original values)
#   DF_QNA      quarterly GDP, chain-linked volume, seasonally adjusted
#               (quarterly; the OECD reference series is monthly GDP)
# Output: data-raw/oecd-idn/oecd-idn.csv (long format),
# data-raw/oecd-idn/SNAPSHOT (download date and queries) and the test
# fixture tests/testthat/fixtures/oecd-idn.rds (the normalised CLI, reference
# series and components, used by test-oecd.R).

base <- "https://sdmx.oecd.org/public/rest/data/"
queries <- c(
  DF_CLI = "OECD.SDD.STES,DSD_STES@DF_CLI,/IDN.M........",
  DF_FINMARK = "OECD.SDD.STES,DSD_STES@DF_FINMARK,/IDN.M.CC+IRSTCI+IR3TIB+SHARE.......",
  DF_CS = "OECD.SDD.STES,DSD_STES@DF_CS,/IDN.M.CCICP.......",
  DF_QNA = "OECD.SDD.NAD,DSD_NAMAIN1@DF_QNA,/Q..IDN.S1..B1GQ._Z...XDC.LR.."
)
keep <- c("MEASURE", "Measure", "UNIT_MEASURE", "ADJUSTMENT", "TRANSFORMATION",
          "TIME_PERIOD", "OBS_VALUE")
get_one <- function(id) {
  url <- paste0(base, queries[[id]], "?format=csvfilewithlabels")
  d <- utils::read.csv(url, check.names = FALSE, stringsAsFactors = FALSE)
  if (!"MEASURE" %in% names(d)) { # national accounts: the transaction
    d$MEASURE <- d$TRANSACTION
    d$Measure <- d$Transaction
  }
  d <- d[!is.na(d$OBS_VALUE), intersect(keep, names(d))]
  for (v in setdiff(keep, names(d))) d[[v]] <- NA
  data.frame(dataflow = id, d[keep], check.names = FALSE)
}
all <- do.call(rbind, lapply(names(queries), get_one))
names(all) <- c("dataflow", "measure", "label", "unit", "adjustment",
                "transformation", "period", "value")
all <- all[order(all$dataflow, all$measure, all$unit, all$adjustment,
                 all$transformation, all$period), ]
dir.create("data-raw/oecd-idn", showWarnings = FALSE)
utils::write.csv(all, "data-raw/oecd-idn/oecd-idn.csv", row.names = FALSE)
writeLines(c(paste("downloaded:", format(Sys.time(), "%Y-%m-%d %H:%M %Z")),
             paste0(names(queries), ": ", base, queries)),
           "data-raw/oecd-idn/SNAPSHOT")
print(table(paste(all$dataflow, all$measure, all$adjustment)))

# test fixture: the OECD normalised cycles, monthly, from 1990-01
nor <- all[all$dataflow == "DF_CLI" & all$adjustment == "NOR", ]
months <- format(seq(as.Date("1990-01-01"),
                     as.Date(paste0(max(nor$period), "-01")), by = "month"),
                 "%Y-%m")
fixture <- sapply(split(nor, nor$measure), function(s) {
  s$value[match(months, s$period)]
})
saveRDS(list(snapshot = readLines("data-raw/oecd-idn/SNAPSHOT")[1],
             start = c(1990L, 1L), data = round(fixture, 5)),
        "tests/testthat/fixtures/oecd-idn.rds", version = 2)
