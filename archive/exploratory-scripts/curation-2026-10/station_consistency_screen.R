# Exploratory ERA5-free consistency screen of the selected GHCNh station years.
# Selection decisions use only GHCNh fields; ERA5 statistics are joined afterwards for evaluation.
suppressPackageStartupMessages({
  library(data.table)
  library(arrow)
  library(parallel)
})
out <- "output/drafts/station-consistency"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
s <- fread("output/tables/ground_station_stats.csv")[network == "ghcnh"]
cols <- c("DATE", "temperature", "station_level_pressure", "sea_level_pressure", "altimeter")

diagnose <- function(i) {
  r <- s[i]
  yrs <- year(r$window_start):year(r$window_end)
  fs <- ifelse(yrs == 2026, file.path("data/interim/ghcnh/selection-2026-10-13/annual", sprintf("%s_%d.parquet", r$id, yrs)),
    file.path("data/interim/ghcnh/annual", sprintf("%s_%d.parquet", r$id, yrs)))
  d <- rbindlist(lapply(fs[file.exists(fs)], function(f) {
    x <- as.data.table(read_parquet(f, col_select = tidyselect::any_of(cols)))
    for (cc in setdiff(cols, names(x))) x[, (cc) := NA_real_]
    x[, ..cols]
  }))
  d[, date := as.POSIXct(DATE, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")]
  d <- d[date >= as.POSIXct(r$window_start) & date < as.POSIXct(r$window_end) & is.finite(station_level_pressure)]
  P <- d$station_level_pressure

  # Altimeter setting inverts exactly to the height the station used (NWS formula, hPa and m).
  n <- 0.190284
  h_alt <- ((d$altimeter / (P - 0.3))^n - 1) * (P - 0.3)^n / (1013.25^n * 0.0065 / 288)
  h_alt <- h_alt[is.finite(h_alt) & d$altimeter > 850 & d$altimeter < 1090]

  # Sea-level pressure inverts approximately, with the station temperature and a standard lapse rate.
  ok <- is.finite(d$sea_level_pressure) & is.finite(d$temperature) & d$sea_level_pressure > 850 & d$sea_level_pressure < 1090
  T <- d$temperature[ok] + 273.15
  h <- rep(r$elev, sum(ok))
  for (k in 1:5) h <- 287.05 * (T + 0.0065 * h / 2) / 9.80665 * log(d$sea_level_pressure[ok] / P[ok])
  hm <- data.table(m = format(d$date[ok], "%Y%m"), h = h)[, .(h = median(h), .N), by = m][N >= 20][order(m)]

  # Semi-diurnal tide phase in local solar time; daily means remove synoptic variation.
  d[, lst := (as.numeric(date) / 3600 + r$lon / 15) %% 24]
  d[, day := floor((as.numeric(date) / 3600 + r$lon / 15) / 24)]
  d[, anom := station_level_pressure - mean(station_level_pressure), by = day]
  d[, n_day := .N, by = day]
  t <- d[n_day >= 8]
  tide <- if (nrow(t) >= 500) lm.fit(cbind(1, cos(2 * pi * t$lst / 12), sin(2 * pi * t$lst / 12),
    cos(2 * pi * t$lst / 24), sin(2 * pi * t$lst / 24)), t$anom)$coefficients else rep(NA_real_, 5)

  data.table(id = r$id, n_alt = length(h_alt), h_alt = median(h_alt), n_slp = sum(ok), h_slp = median(h),
    h_slp_iqr = IQR(h), slp_month_jump = if (nrow(hm) > 1) max(abs(diff(hm$h))) else NA_real_,
    s2_amp = sqrt(tide[2]^2 + tide[3]^2), s2_peak = (atan2(tide[3], tide[2]) * 12 / (2 * pi)) %% 12)
}
d <- merge(s[, .(id, name, lat, lon, elev, era5_bias = bias_sl, era5_sd = sd_sl)],
  rbindlist(mclapply(seq_len(nrow(s)), diagnose, mc.cores = max(1, detectCores() - 2))), by = "id")
isa <- fread("output/tables/paper_ground_station.csv")[reference == "GHCNh" & formula == "isa", .(id, isa_bias = bias)]
d <- merge(d, isa, by = "id")

d[, `:=`(dalt = h_alt - elev, dslp = h_slp - elev, tol = 20 + 0.02 * pmax(elev, 0))]
d[, slp_ok := n_slp > 500 & abs(dslp) < 500 & h_slp_iqr < tol]
d[, s2_lag := ((s2_peak - median(s2_peak[s2_amp > 0.5], na.rm = TRUE) + 6) %% 12) - 6]
d[, `:=`(
  elevation_offset = fifelse(n_alt > 500, abs(dalt) > 20, slp_ok & abs(dslp) > tol) %in% TRUE,
  reference_jump = (elev < 500 & slp_month_jump > 30) %in% TRUE,
  timestamp_lag = (s2_amp > 0.5 & abs(s2_lag) > 1.5) %in% TRUE,
  gross_pressure = abs(isa_bias) > 500,
  verifiable = n_alt > 500 | slp_ok)]
d[, flagged := elevation_offset | reference_jump | timestamp_lag | gross_pressure]
fwrite(d, file.path(out, "station_consistency.csv"))

summary <- function(x) x[, .(stations = .N, bias_gt20 = sum(abs(era5_bias) > 20), bias_gt50 = sum(abs(era5_bias) > 50),
  bias_gt100 = sum(abs(era5_bias) > 100), sd_gt20 = sum(era5_sd > 20), median_abs_bias = median(abs(era5_bias)),
  p95_abs_bias = quantile(abs(era5_bias), .95), clean_removed = sum(abs(era5_bias) < 10 & era5_sd < 10))]
evaluation <- rbind(cbind(set = "current", summary(d)), cbind(set = "kept", summary(d[flagged == FALSE])),
  cbind(set = "flagged", summary(d[flagged == TRUE])), cbind(set = "kept_verifiable", summary(d[flagged == FALSE & verifiable == TRUE])),
  cbind(set = "kept_unverifiable", summary(d[flagged == FALSE & verifiable == FALSE])))
fwrite(evaluation, file.path(out, "evaluation.csv"))
print(evaluation)
