# F-04 numeric verification: Denton-Cholette with a general aggregation
# ratio k against tempdisagg (independent implementation), the constraint,
# the KKT rank (uniqueness) and the k = 3 case of rcli 0.2.1.
# Run from the package root: Rscript harness/02-math/scripts/F-04_numeric.R
devtools::load_all(quiet = TRUE)
set.seed(4)
agg <- function(x, k, tp) {
  m <- matrix(as.numeric(x), nrow = k)
  switch(tp, flow = colSums(m), average = colMeans(m), stock = m[k, ])
}
out <- NULL
for (f in c(1, 2, 4)) for (to in c(4, 12)) {
  if (to <= f) next
  k <- to / f
  y <- ts(100 + cumsum(rnorm(10 * f, 2)), start = c(2001, 1),
          frequency = f)
  for (tp in c("flow", "average", "stock")) {
    x <- rcli:::denton_cholette(y, tp, to)
    conv <- c(flow = "sum", average = "average", stock = "last")[[tp]]
    ref <- stats::predict(tempdisagg::td(
      y ~ 1, to = to, conversion = conv, method = "denton-cholette"))
    m <- length(y)
    n <- k * m
    cm <- rcli:::constraint_matrix(m, tp, k)
    kkt <- rbind(cbind(2 * crossprod(diff(diag(n))), t(cm)),
                 cbind(cm, matrix(0, m, m)))
    out <- rbind(out, data.frame(
      from = f, to = to, k = k, type = tp,
      constraint = max(abs(agg(x, k, tp) - as.numeric(y))),
      vs_tempdisagg = max(abs(as.numeric(x) - as.numeric(ref))),
      kkt_full_rank = qr(kkt)$rank == n + m))
  }
}
out_print <- out
out_print[, 5:6] <- signif(out_print[, 5:6], 3)
print(out_print)
stopifnot(all(out$constraint < 1e-8), all(out$vs_tempdisagg < 1e-6),
          all(out$kkt_full_rank))
cat("F-04 numeric check: PASS\n")
