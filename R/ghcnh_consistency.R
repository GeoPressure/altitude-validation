# Station-consistency checks from the station's own GHCNh reports -------------
consistency_rules <- list(min_reports = 500, month_reports = 100, height_m = 15, slp_height_fraction = .01,
  slp_max_offset_m = 500, day_factor = 3, persistent_months = 12, tide_amplitude_hpa = .5, tide_lag_h = 1.5, tide_peak_lst = 9.8, tide_day_reports = 8)

# Archive QC for an auxiliary field, matching the station-pressure exclusions.
ghcnh_field_ok <- function(value, q, src, lower, upper) {
  q <- as.character(q)
  src <- as.character(src)
  is.finite(value) & value > lower & value < upper & !q %in% c("2", "3", "6", "7") &
    !(q %in% "5" & src %in% c("220", "221", "222", "223", "347", "348")) & (is.na(q) | !grepl("[a-z]", q))
}

# Sea-level pressure, altimeter and temperature from the report chosen for each pressure hour.
ghcnh_reference <- function(s, settings, catalogue, run_dir) {
  path <- file.path(run_dir, "reference", paste0(s$id, ".parquet"))
  if (file.exists(path)) return(as.data.table(read_parquet(path)))
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  fields <- c("station_level_pressure", "sea_level_pressure", "altimeter", "temperature")
  pieces <- list()
  for (year in catalogue[id == s$id, sort(unique(year))]) {
    annual <- file.path(if (year == max(settings$years)) file.path(run_dir, "annual") else
      "data/interim/ghcnh/annual", sprintf("%s_%d.parquet", s$id, year))
    if (!file.exists(annual)) {
      url <- sprintf("%s/hourly/access/by-year/%d/parquet/GHCNh_%s_%d.parquet", settings$base, year, s$id, year)
      status <- system2("curl", c("-fsSL", "--retry", "3", "--max-time", "120", "-o", shQuote(paste0(annual, ".tmp")), shQuote(url)))
      if (status != 0) stop("NOAA download failed: ", s$id, " / ", year)
      read_parquet(paste0(annual, ".tmp"), col_select = "STATION")
      stopifnot(file.rename(paste0(annual, ".tmp"), annual))
    }
    schema <- names(open_dataset(annual)$schema)
    keep <- schema[tolower(schema) %in% c("date", fields, paste0(fields, "_quality_code"), paste0(fields, "_source_code"))]
    d <- as.data.table(read_parquet(annual, col_select = tidyselect::all_of(keep)))
    setnames(d, tolower(names(d)))
    for (f in setdiff(c(fields, paste0(fields, "_quality_code"), paste0(fields, "_source_code")), names(d))) d[, (f) := NA]
    d <- d[ghcnh_field_ok(station_level_pressure, station_level_pressure_quality_code, station_level_pressure_source_code,
      settings$pressure_min, settings$pressure_max)]
    d[!ghcnh_field_ok(sea_level_pressure, sea_level_pressure_quality_code, sea_level_pressure_source_code, 850, 1090), sea_level_pressure := NA]
    d[!ghcnh_field_ok(altimeter, altimeter_quality_code, altimeter_source_code, 850, 1090), altimeter := NA]
    d[!ghcnh_field_ok(temperature, temperature_quality_code, temperature_source_code, -90, 60), temperature := NA]
    pieces[[length(pieces) + 1L]] <- d[, .(date = as.POSIXct(date, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC"),
      pressure = station_level_pressure, sea_level_pressure = as.numeric(sea_level_pressure),
      altimeter = as.numeric(altimeter), temperature = as.numeric(temperature))]
  }
  d <- rbindlist(pieces)
  # Same report choice per hour as ghcnh_pressure(), so the fields belong to the selected pressure report.
  d[, hour := era5_hour(date)]
  d[, distance := abs(as.numeric(difftime(date, hour, units = "secs")))]
  setorder(d, hour, distance, date)
  d <- unique(d, by = "hour")
  d <- d[hour >= settings$start & hour < settings$end, .(date = hour, pressure, sea_level_pressure, altimeter, temperature)]
  ghcnh_write(d, path)
  d
}

# Per-report implied heights and tide anomalies; window statistics only subset these.
ghcnh_consistency_inputs <- function(o, ref, s) {
  d <- merge(o, ref[, .(date, ref_pressure = pressure, sea_level_pressure, altimeter, temperature)], by = "date", all.x = TRUE)
  stopifnot(all(d$pressure == d$ref_pressure))
  setorder(d, date)
  n <- 0.190284
  d[, h_alt := ((altimeter / (pressure - .3))^n - 1) * (pressure - .3)^n / (1013.25^n * .0065 / 288)]
  # Hypsometric inversion of sea-level pressure with a standard-lapse mean column temperature.
  d[, h_slp := s$elev]
  for (k in 1:5) d[, h_slp := 287.05 * (temperature + 273.15 + .0065 * h_slp / 2) / 9.80665 * log(sea_level_pressure / pressure)]
  d[, lst := (as.numeric(date) / 3600 + s$lon / 15) %% 24]
  d[, day := floor((as.numeric(date) / 3600 + s$lon / 15) / 24)]
  d[, tide := if (.N >= consistency_rules$tide_day_reports) pressure - mean(pressure) else NA_real_, by = day]
  d[, .(date, h_alt, h_slp, lst, tide)]
}

# Height, timing and gross-level consistency of one candidate year. With `bounds` (the 13 day
# numbers delimiting its month-long intervals), every interval needs its own agreeing height
# reference and no day may depart grossly; without them, the full record is tested through its
# overall median and its longest run of disagreeing calendar months.
ghcnh_consistency <- function(x, s, bounds = NULL, rules = consistency_rules) {
  tolerance <- c(altimeter = rules$height_m, sea_level_pressure = rules$height_m + rules$slp_height_fraction * max(s$elev, 0))
  h_slp <- x$h_slp[is.finite(x$h_slp)]
  slp_offset <- if (length(h_slp)) median(h_slp) - s$elev else NA_real_
  slp_usable <- length(h_slp) >= rules$min_reports && abs(slp_offset) < rules$slp_max_offset_m &&
    IQR(h_slp) < tolerance[["sea_level_pressure"]]
  interval <- if (is.null(bounds)) rep(1L, nrow(x)) else
    13L - findInterval(as.numeric(as.Date(x$date, tz = "UTC")), sort(bounds))
  minimum <- if (is.null(bounds)) rules$min_reports else rules$month_reports
  months <- data.table(interval = interval, h_alt = x$h_alt, h_slp = x$h_slp)[, .(
    n_alt = sum(is.finite(h_alt)), alt = median(h_alt, na.rm = TRUE),
    n_slp = sum(is.finite(h_slp)), slp = median(h_slp, na.rm = TRUE)), by = interval]
  months <- months[data.table(interval = seq_len(if (is.null(bounds)) 1L else 12L)), on = "interval"]
  months[, source := fifelse((n_alt >= minimum) %in% TRUE, "altimeter",
    fifelse(slp_usable & (n_slp >= minimum) %in% TRUE, "sea_level_pressure", "none"))]
  months[, offset := fifelse(source == "altimeter", alt, slp) - s$elev]
  months[, excess := abs(offset) - tolerance[source]]
  limit <- fifelse(is.finite(x$h_alt), tolerance[["altimeter"]], tolerance[["sea_level_pressure"]])
  if (is.null(bounds)) {
    # Level changes widen the record's SLP spread, so every plausible SLP report is used here.
    h <- fifelse(is.finite(x$h_alt), x$h_alt, fifelse(abs(x$h_slp - s$elev) < rules$slp_max_offset_m, x$h_slp, NA_real_)) - s$elev
    calendar <- data.table(m = format(x$date, "%Y-%m"), h, limit)[is.finite(h), .(out = abs(median(h)) > median(limit), .N), by = m][
      N >= rules$month_reports][order(m)]
    runs <- rle(calendar$out)
    departure <- max(c(0L, runs$lengths[runs$values])) >= rules$persistent_months
  } else {
    # Daily medians catch short pressure offsets within an otherwise consistent month.
    h <- fifelse(is.finite(x$h_alt), x$h_alt, if (slp_usable) x$h_slp else NA_real_) - s$elev
    days <- data.table(day = as.Date(x$date, tz = "UTC"), h, limit)[is.finite(h), .(h = median(h), limit = median(limit)), by = day]
    departure <- any(abs(days$h) > rules$day_factor * days$limit)
  }
  t <- x[is.finite(tide)]
  fit <- if (nrow(t) >= rules$min_reports) lm.fit(cbind(1, cos(pi * t$lst / 6), sin(pi * t$lst / 6),
    cos(pi * t$lst / 12), sin(pi * t$lst / 12)), t$tide)$coefficients else rep(NA_real_, 5)
  amplitude <- sqrt(fit[2]^2 + fit[3]^2)
  lag <- ((atan2(fit[3], fit[2]) * 6 / pi - rules$tide_peak_lst + 6) %% 12) - 6
  reason <- if (departure) "reference_height" else
    if (any(months$source == "none")) "unverifiable" else if (any(months$excess > 0)) "reference_height" else
    if (is.finite(amplitude) && amplitude > rules$tide_amplitude_hpa && abs(lag) > rules$tide_lag_h) "timestamp" else "accepted"
  worst <- if (all(is.na(months$offset))) NA_real_ else months$offset[which.max(abs(months$offset))]
  list(pass = reason == "accepted", reason = reason, height_source = names(which.max(table(months$source))),
    height_offset = worst, tide_amplitude = unname(amplitude), tide_lag = unname(lag))
}
