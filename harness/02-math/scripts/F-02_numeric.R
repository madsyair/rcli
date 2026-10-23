# Verifikasi numerik F-02.
suppressMessages(devtools::load_all("/home/claude/rcli", quiet = TRUE))
# (a) tren linear murni
x <- ts(0.01 * (1:120), frequency = 12)
fa <- extend_series(ar_extension(h = 12), x)
stopifnot(max(abs(fa - (x[120] + 0.01 * (1:12)))) < 1e-8)
# (b), (c), (d) AR(1) pada perubahan
set.seed(7)
d <- as.numeric(arima.sim(list(ar = 0.6), n = 600)) * 0.01 + 0.002
x <- ts(cumsum(c(5, d)), frequency = 12)
fb <- extend_series(ar_extension(h = 12, order_max = 12), x)
dd <- diff(as.numeric(x))
fit <- stats::ar(dd, aic = TRUE, order.max = 12, method = "yule-walker")
want <- x[length(x)] + cumsum(as.numeric(predict(fit, n.ahead = 12)$pred))
stopifnot(max(abs(fb - want)) < 1e-10)
f1 <- extend_series(ar_extension(h = 1, order_max = 1), x)
fit1 <- stats::ar(dd, aic = FALSE, order.max = 1, method = "yule-walker")
manual <- x[length(x)] + fit1$x.mean + fit1$ar[1] * (dd[length(dd)] -
                                                       fit1$x.mean)
cat("orde terpilih:", fit$order, "; phi1:", round(fit1$ar[1], 3), "\n")
stopifnot(abs(f1 - manual) < 1e-10, abs(fit1$ar[1] - 0.6) < 0.1)
cat("F-02 numerik: lolos\n")
