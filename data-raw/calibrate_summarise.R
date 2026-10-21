# Monte Carlo calibration harness, part 2: classification accuracy of the
# default rules by frequency and noise level.
# Output: inst/calibration/accuracy.csv
d <- utils::read.csv("inst/calibration/assessment-stats.csv")
acc <- aggregate(list(correct = d$class == d$truth),
                 list(freq = d$freq, noise_sd = d$noise_sd, truth = d$truth),
                 mean)
fp <- with(d[d$truth != "leading", ],
           aggregate(list(false_leading = class == "leading"),
                     list(freq = freq, noise_sd = noise_sd), mean))
overall <- aggregate(list(overall = d$class == d$truth),
                     list(freq = d$freq, noise_sd = d$noise_sd), mean)
wide <- reshape(acc, idvar = c("freq", "noise_sd"), timevar = "truth",
                direction = "wide")
out <- merge(merge(wide, fp), overall)
out[, -(1:2)] <- round(out[, -(1:2)], 3)
utils::write.csv(out, "inst/calibration/accuracy.csv", row.names = FALSE)
print(out)
