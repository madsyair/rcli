# Example data for vignette("oecd-indonesia") and the graphical interface:
# the OECD series of Indonesia from the snapshot of data-raw/oecd_idn_fetch.R,
# one CSV file per indicator (as read_cli_series() and the app read them)
# plus the published CLI and its components. Run from the package root:
#   Rscript data-raw/oecd_idn_extdata.R
d <- utils::read.csv("data-raw/oecd-idn/oecd-idn.csv", stringsAsFactors = FALSE)
out <- "inst/extdata/oecd-idn"
dir.create(out, showWarnings = FALSE, recursive = TRUE)
one <- function(file, flow, measure, adjustment, quarterly = FALSE) {
  s <- d[d$dataflow == flow & d$measure == measure &
           d$adjustment == adjustment & d$transformation != "GY", ]
  s <- s[order(s$period), ]
  date <- if (quarterly) sub("-Q", "Q", s$period) else s$period
  utils::write.csv(data.frame(date = date, value = signif(s$value, 8)),
                   file.path(out, file), row.names = FALSE, quote = FALSE)
}
one("gdp.csv", "DF_QNA", "B1GQ", "Y", quarterly = TRUE)
one("share_prices.csv", "DF_FINMARK", "SHARE", "_Z")
one("call_money_rate.csv", "DF_FINMARK", "IRSTCI", "_Z")
one("rupiah_per_usd.csv", "DF_FINMARK", "CC", "_Z")
one("consumer_confidence.csv", "DF_CS", "CCICP", "Y")
# published CLI, reference series and components (monthly, wide)
# (LI TR GY is the 12-month growth rate of the trend-restored CLI)
cl <- d[d$dataflow == "DF_CLI" &
          (d$adjustment == "NOR" | (d$measure == "LI" & d$adjustment == "AA") |
             (d$measure == "LI" & d$adjustment == "TR") |
             (d$measure == "RS" & d$adjustment == "RT")), ]
cl$column <- ifelse(cl$adjustment == "NOR", cl$measure,
                    paste(cl$measure, cl$adjustment, cl$transformation,
                          sep = "_"))
cl$column <- c(LI = "cli_normalised", LI_AA_IX = "cli_amplitude_adjusted",
               LI_TR_IX = "cli_trend_restored",
               LI_TR_GY = "cli_growth_rate",
               RS = "reference_normalised",
               RS_RT_IX = "reference_ratio_to_trend")[cl$column] |>
  (\(x) ifelse(is.na(x), cl$column, x))()
months <- sort(unique(cl$period))
wide <- data.frame(date = months)
for (col in unique(cl$column)) {
  s <- cl[cl$column == col, ]
  wide[[col]] <- signif(s$value[match(months, s$period)], 8)
}
wide <- wide[, c("date", "cli_amplitude_adjusted", "cli_normalised",
                 "cli_trend_restored", "cli_growth_rate",
                 "reference_ratio_to_trend", "reference_normalised",
                 sort(grep("^LOCO", names(wide), value = TRUE)))]
utils::write.csv(wide, file.path(out, "oecd_cli.csv"), row.names = FALSE,
                 quote = FALSE, na = "")
writeLines(c(readLines("data-raw/oecd-idn/SNAPSHOT")[1],
             "Source: OECD Data Explorer (SDMX API), Indonesia; see data-raw/oecd_idn_fetch.R"),
           file.path(out, "SOURCE.txt"))
print(list.files(out))
