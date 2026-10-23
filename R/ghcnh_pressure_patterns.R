# Pressure-only irregularity and persistent-step evidence.
ghcnh_pressure_patterns <- function(d, start = min(d$date), end = max(d$date) + 3600) {
  d <- copy(d)[order(date)]
  elapsed <- as.numeric(difftime(d$date, shift(d$date), units = "hours"))
  following <- shift(elapsed, type = "lead")
  change <- d$pressure - shift(d$pressure)
  d[, cadence := elapsed]
  d[, innovation := abs(pressure - (shift(pressure) + shift(pressure, type = "lead")) / 2) / cadence]
  d[, block := as.Date("2022-01-01") + floor(as.numeric(as.Date(date, tz = "UTC") - as.Date("2022-01-01")) / 14) * 14]
  blocks <- d[elapsed == following & elapsed <= 3, .(n = .N, days = uniqueN(as.Date(date, tz = "UTC")),
    median = median(innovation), p90 = quantile(innovation, .9), large = sum(innovation > 1)), by = .(block, cadence)][n >= 30 & days >= 7]
  baseline <- blocks[, .(baseline = quantile(p90, .2)), by = cadence]
  blocks <- d[elapsed == following & elapsed <= 3 & date - elapsed * 3600 >= start & date + following * 3600 < end,
    .(n = .N, days = uniqueN(as.Date(date, tz = "UTC")), median = median(innovation),
      p90 = quantile(innovation, .9), large = sum(innovation > 1)), by = .(block, cadence)][n >= 30 & days >= 7]
  blocks <- merge(blocks, baseline, by = "cadence")
  blocks[, ratio := p90 / pmax(baseline, .1)]
  blocks[, noise := p90 >= 1.5 & ratio >= 4 & large >= 10]

  # Test an abrupt hourly step only when adjacent tendencies are quiet.
  ii <- which(d$date - 24 * 3600 >= start & d$date + 24 * 3600 <= end & elapsed == 1 & shift(elapsed) == 1 & following == 1 & abs(change) >= 4 &
    abs(shift(change)) <= abs(change) / 3 & abs(shift(change, type = "lead")) <= abs(change) / 3)
  steps <- data.table(date = d$date[ii], jump = change[ii], before = NA_real_, after = NA_real_, scale = NA_real_, n_before = 0L, n_after = 0L)
  for (j in seq_along(ii)) {
    i <- ii[j]
    before_rows <- which(d$date >= d$date[i] - 24 * 3600 & d$date < d$date[i])
    after_rows <- which(d$date >= d$date[i] & d$date < d$date[i] + 24 * 3600)
    local <- which(abs(as.numeric(difftime(d$date, d$date[i], units = "days"))) <= 14 & elapsed == 1)
    steps[j, `:=`(before = median(d$pressure[before_rows]), after = median(d$pressure[after_rows]),
      scale = median(abs(change[setdiff(local, i)])), n_before = length(before_rows), n_after = length(after_rows))]
  }
  steps[, ratio := abs(jump) / pmax(scale, .1)]
  steps[, abrupt := n_before >= 18 & n_after >= 18 & ratio >= 6 &
    sign(after - before) == sign(jump) & abs(after - before) >= .5 * abs(jump)]
  steps[, `:=`(weekly_support = FALSE, pre_spread = NA_real_, post_spread = NA_real_, persistent = NA_real_)]
  for (j in which(steps$abrupt)) {
    at <- steps$date[j]
    if (at - 28 * 86400 < start || at + 28 * 86400 > end) next
    daily <- d[date >= at - 28 * 86400 & date < at + 28 * 86400,
      .(n = .N, pressure = median(pressure)), by = .(day = floor(as.numeric(difftime(date, at, units = "days"))))][n >= 18]
    weekly <- daily[, .(days = .N, pressure = median(pressure)), by = .(week = floor(day / 7))]
    if (nrow(weekly) != 8 || any(weekly$days < 4)) next
    before_week <- weekly[week < 0]$pressure
    after_week <- weekly[week >= 0]$pressure
    steps[j, `:=`(weekly_support = TRUE, pre_spread = diff(range(before_week)), post_spread = diff(range(after_week)),
      persistent = min(sign(jump) * (after_week - median(before_week))))]
  }
  steps[, step := abrupt & weekly_support & pre_spread <= .5 * abs(jump) & post_spread <= .5 * abs(jump) & persistent >= .5 * abs(jump)]
  # Keep episode bounds at actual supporting reports, not calendar-block edges.
  episodes <- list()
  for (j in which(blocks$noise)) {
    ii <- which(d$block == blocks$block[j] & elapsed == following & elapsed == blocks$cadence[j] & d$innovation > 1 &
      d$date - elapsed * 3600 >= start & d$date + following * 3600 < end)
    episodes[[length(episodes) + 1L]] <- data.table(start = d$date[min(ii) - 1L], end = d$date[max(ii) + 1L], reason = "irregularity")
  }
  episodes <- rbindlist(c(episodes, list(data.table(start = steps$date[steps$step] - 3600, end = steps$date[steps$step], reason = rep("step", sum(steps$step))))))
  list(blocks = blocks, steps = steps, episodes = episodes)
}
