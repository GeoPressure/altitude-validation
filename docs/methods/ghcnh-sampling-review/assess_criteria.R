# Assess proposed criteria using cached matched observations -----------------
# Run from the repository root. This writes review outputs only.
suppressPackageStartupMessages({
  library(data.table)
  library(arrow)
  library(lubridate)
  library(sf)
})
out <- "docs/methods/ghcnh-sampling-review"
setDTthreads(4)
st <- fread("output/tables/ground_station_stats.csv")
end <- as.Date("2026-10-13")
start <- as.Date("2022-01-01")
ends <- seq(end, start %m+% years(1), by = "-1 day")
boundaries <- sapply(0:12, function(m) as.integer(ends %m-% months(m)))
configs <- data.table(days = c(10, 15, 20, 25, 15, 15, 15), hours = c(4, 4, 4, 4, 2, 6, 8))
configs[, setting := paste0(days, "d_", hours, "h")]

# Compare geographic spacing on cached candidates ---------------------------
candidate <- fread("data/interim/ghcnh/candidate_stations.csv")
xy <- st_coordinates(st_transform(st_as_sf(candidate, coords = c("lon", "lat"), crs = 4326), 8857))
grid <- list()
for (width in c(100, 150, 200, 250, 300)) {
  cell <- data.table(candidate, x = floor(xy[, 1] / (width * 1000)), y = floor(xy[, 2] / (width * 1000)))
  cells <- cell[, .(candidates = .N, high = any(elev > 1000)), by = .(x, y)]
  grid[[as.character(width)]] <- cells[, .(width_km = width, occupied_cells = .N,
    singleton_cells = sum(candidates == 1), median_candidates = median(candidates),
    cells_with_high_station = sum(high))]
}
fwrite(rbindlist(grid), file.path(out, "criteria_grid.csv"))

# Read only the matched inputs needed for the review ------------------------
message("Reading cached matched observations")
a <- as.data.table(read_parquet("data/interim/errors_ghcnh.parquet",
  col_select = c("id", "date", "year", "err_sl", "pressure", "t2m_sl", "sp_sl", "d2m")))
a <- a[year >= 2022 & is.finite(err_sl) & is.finite(pressure) & is.finite(t2m_sl) & is.finite(sp_sl) & is.finite(d2m)]
a[, day := as.Date(date, tz = "UTC")]
a <- a[day >= start & day < end]
setkey(a, id, date)
ids <- unique(a$id)
message(nrow(a), " observations at ", length(ids), " stations")

# Find exact post-gross-removal coverage-qualified windows ------------------
# Raw daily coverage gives an upper bound; test its eligible windows in recency order.
windows <- list()
monthly <- list()
gross <- list()
for (j in seq_along(ids)) {
  s <- a[.(ids[j])]
  counts <- tabulate(as.integer(s$day - start) + 1L, nbins = as.integer(end - start))
  choices <- list()
  for (h in unique(configs$hours)) {
    cs <- c(0, cumsum(counts >= h))
    block <- sapply(1:12, function(m) cs[boundaries[, m] - as.integer(start) + 1L] -
      cs[boundaries[, m + 1] - as.integer(start) + 1L])
    choices[[as.character(h)]] <- apply(block, 1, min)
  }
  for (v in seq_len(nrow(configs))) {
    cfg <- configs[v]
    eligible <- which(choices[[as.character(cfg$hours)]] >= cfg$days)
    row <- data.table(id = ids[j], setting = cfg$setting, end = as.Date(NA), n = NA_integer_,
      bias = NA_real_, med_abs = NA_real_, p95_abs = NA_real_, gross_fraction = NA_real_,
      min_days = NA_integer_, min_month_hours = NA_integer_)
    for (i in eligible) {
      w <- s[day >= as.Date(boundaries[i, 13], origin = "1970-01-01") & day < ends[i]]
      centre <- median(w$err_sl)
      scale <- mad(w$err_sl)
      keep <- abs(w$err_sl - centre) <= max(100, 10 * scale)
      clean_counts <- tabulate(as.integer(w$day[keep] - start) + 1L, nbins = length(counts))
      cs <- c(0, cumsum(clean_counts >= cfg$hours))
      block <- cs[boundaries[i, 1:12] - as.integer(start) + 1L] - cs[boundaries[i, 2:13] - as.integer(start) + 1L]
      if (min(block) < cfg$days) next
      mh <- c(0, cumsum(clean_counts))
      row[, `:=`(end = ends[i], n = sum(keep), bias = mean(w$err_sl[keep]),
        med_abs = median(abs(w$err_sl[keep])), p95_abs = quantile(abs(w$err_sl[keep]), .95),
        gross_fraction = mean(!keep), min_days = min(block),
        min_month_hours = min(mh[boundaries[i, 1:12] - as.integer(start) + 1L] - mh[boundaries[i, 2:13] - as.integer(start) + 1L]))]
      if (cfg$setting == "15d_4h") {
        for (floor in c(50, 100, 150, 200)) for (mult in c(6, 10, 15)) {
          g <- abs(w$err_sl - centre) > max(floor, mult * scale)
          gross[[length(gross) + 1L]] <- data.table(id = ids[j], floor_m = floor, mad_multiplier = mult,
            fraction = mean(g), bias = mean(w$err_sl[!g]))
        }
        context <- s[day >= ends[i] %m-% years(3) & day < ends[i]]
        context <- context[abs(err_sl - median(err_sl)) <= max(100, 10 * mad(err_sl))]
        context[, month := floor_date(day, "month")]
        monthly[[ids[j]]] <- context[, .(error = median(err_sl), n = .N), by = .(id, month)]
      }
      break
    }
    windows[[length(windows) + 1L]] <- row
  }
  if (j %% 100 == 0) message("Coverage: ", j, "/", length(ids))
}
w <- rbindlist(windows)
fwrite(w, file.path(out, "criteria_windows.csv"))
m <- rbindlist(monthly)
fwrite(m, file.path(out, "criteria_monthly.csv"))
g <- rbindlist(gross)
fwrite(g, file.path(out, "criteria_gross_stations.csv"))
coverage <- w[, .(available = .N, passing = sum(!is.na(end)), at_latest = sum(end == as.Date("2026-10-13"), na.rm = TRUE),
  median_hours = as.numeric(median(n, na.rm = TRUE)), median_station_median_abs = median(med_abs, na.rm = TRUE),
  median_station_p95_abs = median(p95_abs, na.rm = TRUE)), by = setting]
fwrite(coverage, file.path(out, "criteria_coverage.csv"))
fwrite(g[, .(stations = .N, any_removed = sum(fraction > 0), reject_0_5pct = sum(fraction > .005),
  reject_1pct = sum(fraction > .01), reject_2pct = sum(fraction > .02)), by = .(floor_m, mad_multiplier)],
  file.path(out, "criteria_gross.csv"))

# Assess offset thresholds on the same rolling windows ----------------------
base <- merge(w[setting == "15d_4h" & !is.na(end)], st[, .(id, dz_sl, elev, sdor)], by = "id")
offset <- list()
for (intercept in c(15, 30, 60)) for (slope in c(.05, .10, .20)) {
  offset[[length(offset) + 1L]] <- base[, .(intercept_m = intercept, slope = slope, stations = .N,
    rejected = sum(abs(bias) > intercept + slope * abs(dz_sl)),
    rejected_low_gap = sum(abs(bias) > intercept + slope * abs(dz_sl) & abs(dz_sl) <= 30),
    rejected_high = sum(abs(bias) > intercept + slope * abs(dz_sl) & elev > 1000))]
}
fwrite(rbindlist(offset), file.path(out, "criteria_offset.csv"))

# Assess season-adjusted step support and thresholds ------------------------
# A fit is a screening score, not a calibrated significance test.
step_fit <- function(d, endpoint, min_months, min_hours, side) {
  d <- d[n >= min_hours][order(month)]
  if (nrow(d) < min_months || uniqueN(month(d$month)) < 12) return(data.table(tested = FALSE, step = NA_real_, t = NA_real_, at = as.Date(NA), latest_test = as.Date(NA)))
  season <- model.matrix(~ factor(month(d$month)))
  best <- list(rss = Inf)
  eligible <- which(seq_len(nrow(d)) >= side & seq_len(nrow(d)) <= nrow(d) - side &
    shift(d$month, type = "lead") >= endpoint %m-% years(1) & shift(d$month, type = "lead") < endpoint)
  for (i in eligible) {
    x <- cbind(season, step = as.numeric(seq_len(nrow(d)) > i))
    f <- lm.fit(x, d$error)
    if (f$rank < ncol(x) || nrow(x) <= ncol(x)) next
    rss <- sum(f$residuals^2)
    if (rss < best$rss) best <- list(rss = rss, x = x, step = unname(f$coefficients["step"]), at = d$month[i + 1L])
  }
  if (!is.finite(best$rss)) return(data.table(tested = FALSE, step = NA_real_, t = NA_real_, at = as.Date(NA), latest_test = as.Date(NA)))
  se <- sqrt(best$rss / (nrow(best$x) - ncol(best$x)) * solve(crossprod(best$x))["step", "step"])
  data.table(tested = TRUE, step = best$step, t = best$step / se, at = best$at, latest_test = max(d$month[eligible + 1L]))
}
steps <- list()
for (minimum in c(18, 24)) for (hours in c(60, 120)) for (side in c(3, 6)) {
  for (j in seq_len(nrow(base))) {
    fit <- step_fit(m[id == base$id[j]], base$end[j], minimum, hours, side)
    steps[[length(steps) + 1L]] <- data.table(id = base$id[j], min_months = minimum, min_hours = hours, side = side, fit)
  }
  message("Step fits: ", minimum, " months, ", hours, " hours, ", side, " each side")
}
b <- rbindlist(steps)
fwrite(b, file.path(out, "criteria_step_stations.csv"))
step_summary <- list()
for (amplitude in c(5, 10, 20)) for (t_cut in c(5, 10, 15)) {
  step_summary[[length(step_summary) + 1L]] <- b[, .(amplitude_m = amplitude, t_cut = t_cut, stations = .N,
    insufficient = sum(!tested), rejected_step = sum(tested & abs(step) >= amplitude & abs(t) >= t_cut, na.rm = TRUE)),
    by = .(min_months, min_hours, side)]
}
fwrite(rbindlist(step_summary), file.path(out, "criteria_steps.csv"))
default_step <- b[min_months == 18 & min_hours == 60 & side == 6]
combined <- merge(base, default_step, by = "id")
combined[, `:=`(reject_gross = gross_fraction > .01, reject_offset = abs(bias) > 30 + .1 * abs(dz_sl),
  reject_step = tested & abs(step) >= 10 & abs(t) >= 10)]
combined[, accepted := !reject_gross & !reject_offset & tested & !reject_step]
fwrite(combined, file.path(out, "criteria_default_stations.csv"))
fwrite(combined[, .(coverage_pass = .N, gross = sum(reject_gross), offset = sum(reject_offset),
  insufficient_step = sum(!tested), step = sum(reject_step, na.rm = TRUE), accepted = sum(accepted))],
  file.path(out, "criteria_default_summary.csv"))
recommended <- merge(base, b[min_months == 18 & min_hours == 60 & side == 3], by = "id")
recommended[, `:=`(reject_gross = gross_fraction > .01, reject_offset = abs(bias) > 30 + .1 * abs(dz_sl),
  reject_step = tested & abs(step) >= 10 & abs(t) >= 10)]
fwrite(recommended[, .(coverage_pass = .N, gross = sum(reject_gross), offset = sum(reject_offset),
  insufficient_step = sum(!tested), step = sum(reject_step, na.rm = TRUE),
  accepted = sum(!reject_gross & !reject_offset & tested & !reject_step))],
  file.path(out, "criteria_recommended_summary.csv"))

# Check coverage nesting and the minimum implied observation support --------
wide <- dcast(w, id ~ setting, value.var = "end")
stopifnot(all(is.na(wide$`15d_4h`) | (!is.na(wide$`10d_4h`) & wide$`15d_4h` <= wide$`10d_4h`)),
  all(is.na(wide$`20d_4h`) | (!is.na(wide$`15d_4h`) & wide$`20d_4h` <= wide$`15d_4h`)),
  all(is.na(wide$`25d_4h`) | (!is.na(wide$`20d_4h`) & wide$`25d_4h` <= wide$`20d_4h`)),
  all(w[setting == "15d_4h" & !is.na(end), n >= 12 * 15 * 4 & min_month_hours >= 60]))
capture.output(sessionInfo(), file = file.path(out, "criteria_session.txt"))
message("Review complete")
