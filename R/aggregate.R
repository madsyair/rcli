# Aggregation of component cycles into a composite.

coverage_mask <- function(z, min_coverage) {
  avail <- rowSums(!is.na(z))
  avail >= max(1, ceiling(min_coverage * ncol(z) - 1e-9))
}

# Weighted mean over the components available at each date.
weighted_available <- function(z, w) {
  num <- rowSums(sweep(z, 2, w, `*`), na.rm = TRUE)
  den <- rowSums(sweep(!is.na(z), 2, w, `*`))
  out <- num / den
  out[den == 0] <- NA_real_
  out
}

#' @rdname cli_composite
setMethod("aggregate_components", "EqualWeight",
          function(aggregator, z, levels, spec) {
  w <- rep(1 / ncol(z), ncol(z))
  comp <- weighted_available(z, w)
  comp[!coverage_mask(z, aggregator@min_coverage)] <- NA_real_
  list(cycle = comp, index = NULL, weights = stats::setNames(w, colnames(z)))
})

#' @rdname cli_composite
setMethod("aggregate_components", "PrincipalComponent",
          function(aggregator, z, levels, spec) {
  cc <- stats::complete.cases(z)
  if (ncol(z) < 2L || sum(cc) < 3L * ncol(z)) {
    return(aggregate_components(equal_weight(aggregator@min_coverage), z,
                                levels, spec))
  }
  pc <- stats::prcomp(z[cc, , drop = FALSE], center = TRUE, scale. = TRUE)
  load <- pc$rotation[, 1]
  if (sum(load) < 0) load <- -load
  load <- pmax(load, 0)
  w <- load / sum(load)
  comp <- weighted_available(z, w)
  comp[!coverage_mask(z, aggregator@min_coverage)] <- NA_real_
  list(cycle = comp, index = NULL, weights = stats::setNames(w, colnames(z)))
})

symmetric_change <- function(v) {
  if (all(v > 0, na.rm = TRUE)) {
    c(NA, 200 * diff(v) / (v[-1] + v[-length(v)]))
  } else {
    c(NA, diff(v))
  }
}

#' @rdname cli_composite
setMethod("aggregate_components", "ConferenceBoard",
          function(aggregator, z, levels, spec) {
  ch <- vapply(seq_len(ncol(levels)), function(j) {
    symmetric_change(levels[, j]) * attr(levels, "sign")[j]
  }, numeric(nrow(levels)))
  ch <- matrix(ch, nrow = nrow(levels))
  s <- apply(ch, 2, stats::sd, na.rm = TRUE)
  w <- (1 / s) / sum(1 / s)
  contrib <- weighted_available(ch, w)
  ok <- coverage_mask(ch, aggregator@min_coverage) & !is.na(contrib)
  contrib[!ok] <- NA_real_
  span <- non_na_span(contrib)
  index <- rep(NA_real_, length(contrib))
  if (!anyNA(span)) {
    seg <- contrib[span[1]:span[2]]
    seg[is.na(seg)] <- 0
    lev <- 100 * cumprod((200 + seg) / (200 - seg))
    index[span[1]:span[2]] <- lev / mean(lev) * 100
  }
  idx_ts <- stats::ts(index, start = attr(levels, "tsp")[1],
                      frequency = spec@freq)
  cyc <- rep(NA_real_, length(index))
  if (!anyNA(span)) {
    core <- stats::window(idx_ts, start = stats::time(idx_ts)[span[1]],
                          end = stats::time(idx_ts)[span[2]])
    cyc[span[1]:span[2]] <- as.numeric(extract_cycle(spec@filter, log(core)))
  }
  list(cycle = cyc, index = index, weights = stats::setNames(w, colnames(z)))
})

#' @rdname cli_composite
setMethod("aggregate_components", "DynamicFactor",
          function(aggregator, z, levels, spec) {
  cc <- stats::complete.cases(z)
  if (ncol(z) < 2L || sum(cc) < 3L * ncol(z)) {
    return(aggregate_components(equal_weight(aggregator@min_coverage), z,
                                levels, spec))
  }
  fit <- dfm_two_step(z)
  comp <- fit$factor
  if (isTRUE(stats::cor(comp, rowMeans(z, na.rm = TRUE),
                        use = "complete.obs") < 0)) {
    comp <- -comp
    fit$loadings <- -fit$loadings
  }
  comp[!coverage_mask(z, aggregator@min_coverage)] <- NA_real_
  w <- fit$loadings / sum(fit$loadings)
  list(cycle = comp, index = NULL, weights = stats::setNames(w, colnames(z)))
})

# One-factor model x_t = lambda f_t + e_t, f_t = phi f_{t-1} + u_t, estimated
# by principal components and a Kalman smoother (Doz, Giannone and Reichlin
# 2011). Missing observations are skipped in the update step.
dfm_two_step <- function(z) {
  mu <- colMeans(z, na.rm = TRUE)
  s <- apply(z, 2, stats::sd, na.rm = TRUE)
  s[!(s > 0)] <- 1
  x <- sweep(sweep(z, 2, mu), 2, s, `/`)
  cc <- stats::complete.cases(x)
  xc <- x[cc, , drop = FALSE]
  ev <- eigen(stats::cor(xc), symmetric = TRUE)
  f0 <- as.numeric(xc %*% ev$vectors[, 1])
  f0 <- f0 / stats::sd(f0)
  lambda <- as.numeric(crossprod(xc, f0) / (length(f0) - 1))
  r <- pmax(colMeans((xc - outer(f0, lambda))^2), 1e-4)
  phi <- stats::coef(stats::lm.fit(cbind(f0[-length(f0)]), f0[-1]))[[1]]
  phi <- max(min(phi, 0.99), -0.99)
  q <- max(1 - phi^2, 1e-4)
  n <- nrow(x)
  a_f <- p_f <- a_p <- p_p <- numeric(n)
  a <- 0
  p <- q / (1 - phi^2)
  for (t in seq_len(n)) {
    a_p[t] <- if (t == 1L) 0 else phi * a
    p_p[t] <- if (t == 1L) p else phi^2 * p + q
    o <- !is.na(x[t, ])
    if (any(o)) {
      info <- 1 / p_p[t] + sum(lambda[o]^2 / r[o])
      p <- 1 / info
      a <- p * (a_p[t] / p_p[t] + sum(lambda[o] * x[t, o] / r[o]))
    } else {
      a <- a_p[t]
      p <- p_p[t]
    }
    a_f[t] <- a
    p_f[t] <- p
  }
  a_s <- a_f
  if (n > 1L) {
    for (t in (n - 1L):1L) {
      j <- p_f[t] * phi / p_p[t + 1L]
      a_s[t] <- a_f[t] + j * (a_s[t + 1L] - a_p[t + 1L])
    }
  }
  all_na <- rowSums(!is.na(x)) == 0
  a_s[all_na] <- NA_real_
  list(factor = a_s, loadings = lambda, phi = phi, idio_var = r)
}

#' Aggregate components into a composite leading indicator
#'
#' Combines the normalised cycles of `components` with the specification's
#' [Aggregator-class]. The composite cycle is normalised again; the published
#' index is that cycle rescaled to the amplitude of the reference cycle (in
#' percent deviation from trend) around a long-term average of 100, as in the
#' OECD "amplitude adjusted" CLI. For the Conference Board method the index
#' is the cumulated standardised changes (average 100) and the cycle is
#' extracted from it with the specification's filter.
#'
#' @param cycles Named list of [CycleSeries-class] (counter-cyclical series
#'   already inverted, as returned in a [CliResult-class]).
#' @param components Names of the components to aggregate.
#' @param spec A [CliSpec-class].
#' @param reference Optional [CycleSeries-class] of the reference series for
#'   the amplitude adjustment.
#' @param aggregator,z,levels Internal arguments of the aggregation methods.
#' @return A [CompositeIndex-class].
#' @examples
#' sim <- simulate_cycles(seed = 1)
#' meta <- data.frame(name = colnames(sim)[-1], rationale = "early_stage")
#' spec <- cli_spec(freq = 12)
#' cyc <- cli_cycles(cli_candidates(sim, "reference", meta = meta), spec)
#' cli <- cli_composite(cyc, c("lead_6", "lead_3"), spec, cyc$reference)
#' cli
#' @export
cli_composite <- function(cycles, components, spec, reference = NULL) {
  if (!is(spec, "CliSpec")) {
    rcli_abort("`spec` must be a CliSpec.", "rcli_error_argument")
  }
  if (length(components) == 0L || !all(components %in% names(cycles))) {
    rcli_abort("`components` must name at least one element of `cycles`.",
               "rcli_error_argument")
  }
  template <- cycles[[components[1]]]@normalised
  z <- vapply(components, function(nm) as.numeric(cycles[[nm]]@normalised),
              numeric(length(template)))
  z <- matrix(z, ncol = length(components),
              dimnames = list(NULL, components))
  levels <- vapply(components, function(nm) as.numeric(cycles[[nm]]@original),
                   numeric(length(template)))
  levels <- matrix(levels, ncol = length(components))
  attr(levels, "sign") <- vapply(components, function(nm) {
    if ("inverted (counter-cyclical)" %in% cycles[[nm]]@steps) -1 else 1
  }, numeric(1))
  attr(levels, "tsp") <- stats::tsp(template)
  agg <- aggregate_components(spec@aggregator, z, levels, spec)
  cyc <- normalise_cycle(agg$cycle)
  amp <- if (is.null(reference)) 1 else reference_amplitude(reference)
  index <- if (is.null(agg$index)) 100 + cyc * amp else agg$index
  new("CompositeIndex", index = as_ts_like(index, template),
      cycle = as_ts_like(cyc, template), components = components,
      weights = agg$weights, aggregator = spec@aggregator, amplitude = amp)
}

# Amplitude of the reference cycle in percent deviation from trend.
reference_amplitude <- function(reference) {
  cyc <- as.numeric(reference@cycle)
  if ("log" %in% reference@steps) {
    100 * mean_abs_dev(cyc)
  } else {
    100 * mean_abs_dev(cyc) / mean(abs(as.numeric(reference@transformed)),
                                   na.rm = TRUE)
  }
}
