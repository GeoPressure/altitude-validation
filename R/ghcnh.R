# GHCNh station candidates: pressure intake, quality checks and station-year selection.
suppressPackageStartupMessages({
  library(lubridate)
  library(sf)
})

# Commit complete cache files in their destination directory.
ghcnh_save <- function(x, path) {
  saveRDS(x, paste0(path, ".tmp"))
  readRDS(paste0(path, ".tmp"))
  stopifnot(file.rename(paste0(path, ".tmp"), path))
}

ghcnh_write <- function(d, path) {
  write_parquet(d, paste0(path, ".tmp"))
  stopifnot(identical(names(read_parquet(paste0(path, ".tmp"))), names(d)))
  stopifnot(file.rename(paste0(path, ".tmp"), path))
}

# Freeze annual availability independently of downloads.
ghcnh_catalogue <- function(year, run_dir, base) {
  path <- file.path(run_dir, "catalogue", paste0(year, ".rds"))
  if (file.exists(path)) return(readRDS(path))
  marker <- ""
  pages <- list()
  repeat {
    response <- httr2::request(paste0(base, "/")) |>
      httr2::req_url_query(prefix = sprintf("hourly/access/by-year/%d/parquet/", year),
        `max-keys` = 1000, marker = marker) |>
      httr2::req_retry(max_tries = 4) |>
      httr2::req_timeout(120) |>
      httr2::req_perform()
    doc <- xml2::xml_ns_strip(xml2::read_xml(httr2::resp_body_string(response)))
    stopifnot(xml2::xml_name(doc) == "ListBucketResult")
    entries <- xml2::xml_find_all(doc, ".//Contents")
    pages[[length(pages) + 1L]] <- data.table(
      id = sub("^.*GHCNh_([^_]+)_[0-9]{4}\\.parquet$", "\\1", xml2::xml_text(xml2::xml_find_first(entries, "Key"))),
      year = year, bytes = as.numeric(xml2::xml_text(xml2::xml_find_first(entries, "Size"))),
      modified = xml2::xml_text(xml2::xml_find_first(entries, "LastModified")))
    if (xml2::xml_text(xml2::xml_find_first(doc, ".//IsTruncated")) != "true") break
    marker <- xml2::xml_text(xml2::xml_find_first(doc, ".//NextMarker"))
    stopifnot(!is.na(marker), nzchar(marker))
  }
  result <- unique(rbindlist(pages), by = c("id", "year"))
  ghcnh_save(result, path)
  cli::cli_alert_info("Catalogue {year}: {nrow(result)} station files")
  result
}

# Annual GHCNh station file, downloaded once into data/raw/ghcnh.
ghcnh_annual <- function(id, year, settings) {
  path <- file.path(dir_raw, "ghcnh", sprintf("%s_%d.parquet", id, year))
  if (file.exists(path)) return(path)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  url <- sprintf("%s/hourly/access/by-year/%d/parquet/GHCNh_%s_%d.parquet", settings$base, year, id, year)
  status <- system2("curl", c("-fsSL", "--retry", "3", "--max-time", "120", "-o", shQuote(paste0(path, ".tmp")), shQuote(url)))
  if (status != 0) stop("NOAA download failed: ", id, " / ", year)
  read_parquet(paste0(path, ".tmp"), col_select = "STATION")
  stopifnot(file.rename(paste0(path, ".tmp"), path))
  path
}

# Station-level pressure of one candidate, one quality-controlled report per ERA5 hour.
ghcnh_pressure <- function(s, settings, catalogue, run_dir) {
  path <- file.path(run_dir, "pressure", paste0(s$id, ".parquet"))
  if (file.exists(path)) return(as.data.table(read_parquet(path)))
  years <- catalogue[id == s$id, sort(unique(year))]
  pieces <- list()
  for (year in years) {
    annual <- ghcnh_annual(s$id, year, settings)
    schema <- names(open_dataset(annual)$schema)
    keep <- schema[tolower(schema) %in% c("date", "station_level_pressure", "station_level_pressure_quality_code", "station_level_pressure_source_code")]
    d <- as.data.table(read_parquet(annual, col_select = tidyselect::all_of(keep)))
    setnames(d, tolower(names(d)))
    if (!"station_level_pressure" %in% names(d)) next
    q <- as.character(d$station_level_pressure_quality_code)
    src <- as.character(d$station_level_pressure_source_code)
    d <- d[is.finite(station_level_pressure) & station_level_pressure > settings$pressure_min &
      station_level_pressure < settings$pressure_max & !q %in% c("2", "3", "6", "7") &
      !(q %in% "5" & src %in% c("220", "221", "222", "223", "347", "348")) & (is.na(q) | !grepl("[a-z]", q))]
    pieces[[length(pieces) + 1L]] <- d[, .(date = as.POSIXct(date, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC"),
      pressure = station_level_pressure, quality_code = as.character(station_level_pressure_quality_code),
      source_code = as.character(station_level_pressure_source_code))]
  }
  d <- if (length(pieces)) rbindlist(pieces) else data.table(date = as.POSIXct(character(), tz = "UTC"),
    pressure = double(), quality_code = character(), source_code = character())
  d[, hour := era5_hour(date)]
  d[, distance := abs(as.numeric(difftime(date, hour, units = "secs")))]
  setorder(d, hour, distance, date)
  d <- unique(d, by = "hour")
  d[, date := hour]
  d[, c("hour", "distance") := NULL]
  d <- d[date >= settings$start & date < settings$end]
  ghcnh_write(d, path)
  d
}


# Reuse calendar boundaries across all stations in a selection run.
ghcnh_pressure_calendar <- function(settings) {
  start <- as.Date(settings$start)
  ends <- seq(as.Date(settings$end), start %m+% years(1), by = "-1 day")
  bounds <- do.call(cbind, lapply(0:12, function(m) as.integer(ends %m-% months(m))))
  list(start = start, ends = ends, bounds = bounds,
    upper = bounds[, 1:12] - as.integer(start) + 1L,
    lower = bounds[, 2:13] - as.integer(start) + 1L,
    n_days = as.integer(as.Date(settings$end) - start))
}

# Remove isolated pressure spikes bracketed by nearby agreeing observations.
ghcnh_pressure_spikes <- function(d) {
  d <- d[order(date)]
  previous <- shift(d$pressure)
  following <- shift(d$pressure, type = "lead")
  before <- as.numeric(difftime(d$date, shift(d$date), units = "hours"))
  after <- as.numeric(difftime(shift(d$date, type = "lead"), d$date, units = "hours"))
  departure <- pmin(abs(d$pressure - previous), abs(d$pressure - following))
  spike <- ((before <= 3 & after <= 3 & abs(previous - following) <= 2 & departure > 5) |
    (before <= 12 & after <= 12 & abs(previous - following) <= 3 & departure > 10 &
      abs(d$pressure - previous) > 2 * before & abs(d$pressure - following) > 2 * after)) &
    (d$pressure - previous) * (d$pressure - following) > 0
  d[is.na(spike) | !spike]
}

# Large pressure jumps across the full candidate history.
ghcnh_pressure_jumps <- function(d, jump_hpa = 20, jump_hours = 3, gap_jump_hpa = 50, gap_days = 7) {
  d <- d[order(date)]
  elapsed <- as.numeric(difftime(d$date, shift(d$date), units = "hours"))
  change <- d$pressure - shift(d$pressure)
  jumps <- which((abs(change) > jump_hpa & elapsed <= jump_hours) |
    (abs(change) > gap_jump_hpa & elapsed <= gap_days * 24))
  data.table(start = d$date[jumps - 1L], end = d$date[jumps])
}

# Latest year passing coverage, containing no large jump and passing an optional check.
# An optional check(rows, bounds) returns list(pass, ...); after a failure it is retried four weeks earlier.
ghcnh_pressure_window <- function(d, settings, calendar = ghcnh_pressure_calendar(settings),
  jumps = ghcnh_pressure_jumps(d), check = NULL) {
  d <- d[order(date)]
  days <- as.Date(d$date, tz = "UTC")
  counts <- tabulate(as.integer(days - calendar$start) + 1L, nbins = calendar$n_days)
  cs <- c(0, cumsum(counts >= settings$hours_per_day))
  coverage <- matrix(cs[calendar$upper] - cs[calendar$lower], ncol = 12)
  eligible <- rowSums(coverage < settings$days_per_month) == 0
  if (!any(eligible)) return(list(hours = NULL, consistency = list(reason = "coverage")))
  # A jump fails a year when both of its reports fall inside.
  for (j in seq_len(nrow(jumps))) {
    eligible[as.numeric(calendar$ends) * 86400 > as.numeric(jumps$end[j]) &
      calendar$bounds[, 13] * 86400 <= as.numeric(jumps$start[j])] <- FALSE
  }
  if (!any(eligible)) return(list(hours = NULL, consistency = list(reason = "jump")))
  first <- NULL
  retry <- Inf
  for (i in which(eligible)) {
    if (as.numeric(calendar$ends[i]) > retry) next
    rows <- days >= as.Date(calendar$bounds[i, 13], origin = "1970-01-01") & days < calendar$ends[i]
    result <- if (is.null(check)) list(pass = TRUE) else check(rows, calendar$bounds[i, ])
    if (is.null(first)) first <- result
    if (result$pass) return(list(start = as.Date(calendar$bounds[i, 13], origin = "1970-01-01"), end = calendar$ends[i],
      hours = d[rows], consistency = result))
    retry <- as.numeric(calendar$ends[i]) - 28
  }
  list(hours = NULL, consistency = first)
}

# ERA5 single-levels surface inputs at a station for every hour of the study period.
ghcnh_core <- function(s, settings, run_dir) {
  path <- file.path(run_dir, "core", paste0(s$id, ".parquet"))
  hours <- seq(settings$start, settings$end - 3600, by = "hour")
  if (file.exists(path)) {
    e <- as.data.table(read_parquet(path))
    stopifnot(identical(as.numeric(e$date), as.numeric(hours)))
    return(e)
  }
  values <- era5_read(rep(s$lon, length(hours)), rep(s$lat, length(hours)), hours,
    c("surface_pressure", "temperature_2m", "dewpoint_temperature_2m"), "single-levels")
  e <- data.table(date = hours, sp_sl = values$surface_pressure, t2m_sl = values$temperature_2m,
    d2m = values$dewpoint_temperature_2m, z_sl = era5_orography(s$lon, s$lat, "single-levels"))
  ghcnh_write(e, path)
  e
}

# ---- Station-consistency checks from the station's own GHCNh reports -------------
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
    annual <- ghcnh_annual(s$id, year, settings)
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

# Independent coordinate–height consistency check for GHCNh candidates.
ghcnh_terrain <- function(stations, cache = file.path(dir_derived, "ghcnh", "terrain")) {
  dir.create(cache, recursive = TRUE, showWarnings = FALSE)
  file <- file.path(cache, "stations.csv")
  checked <- if (file.exists(file)) fread(file) else data.table(id = character(), lat = double(), lon = double(), elev = double())
  pending <- stations[!checked, on = .(id, lat, lon, elev)]
  if (!nrow(pending)) return(merge(stations, checked, by = c("id", "lat", "lon", "elev")))
  # Query coordinates first; only inconsistent points need the surrounding samples.
  q <- pending[, .(id, lat, lon, north_m = 0, east_m = 0)]
  centre <- ghcnh_terrain_query(q, cache)
  pending <- merge(pending, centre[, .(id, dem = height)], by = "id")
  q <- pending[is.na(dem) | abs(elev - dem) > 50, .(north_m = rep(c(-500, 0, 500), each = 3), east_m = rep(c(-500, 0, 500), 3)), by = .(id, lat, lon)]
  q <- q[(north_m != 0 | east_m != 0) & abs(lat) < 83]
  nearby <- if (nrow(q)) ghcnh_terrain_query(q, cache) else centre[0]
  terrain <- rbind(centre, nearby)[, .(terrain_min = if (all(is.na(height))) NA_real_ else min(height, na.rm = TRUE), terrain_max = if (all(is.na(height))) NA_real_ else max(height, na.rm = TRUE)), by = id]
  pending <- merge(pending, terrain, by = "id")
  pending[, terrain_ok := is.finite(terrain_min) & elev >= terrain_min - 50 & elev <= terrain_max + 50]
  checked <- rbind(checked, pending[, .(id, lat, lon, elev, dem, terrain_min, terrain_max, terrain_ok)], fill = TRUE)
  fwrite(checked, file)
  merge(stations, checked, by = c("id", "lat", "lon", "elev"))
}

# Batch and cache public terrain requests; repeat runs are entirely local.
ghcnh_terrain_query <- function(q, cache) {
  q[, `:=`(query_lat = lat + north_m / 111320, query_lon = lon + east_m / (111320 * cos(lat * pi / 180)))]
  q[, query_lon := (query_lon + 180) %% 360 - 180]
  q[, batch := ceiling(.I / 100)]
  for (b in unique(q$batch)) {
    locations <- paste(sprintf("%.7f,%.7f", q[batch == b]$query_lat, q[batch == b]$query_lon), collapse = "|")
    file <- file.path(cache, paste0(digest::digest(locations), ".json"))
    if (!file.exists(file)) httr2::request("https://api.opentopodata.org/v1/srtm30m,aster30m") |>
      httr2::req_url_query(locations = locations, interpolation = "bilinear") |>
      httr2::req_throttle(1, realm = "ghcnh-terrain") |>
      httr2::req_retry(max_tries = 4) |>
      httr2::req_timeout(120) |>
      httr2::req_perform(path = file)
    response <- jsonlite::read_json(file, simplifyVector = TRUE)
    stopifnot(response$status == "OK", length(response$results$elevation) == q[batch == b, .N])
    q[batch == b, height := response$results$elevation]
    if (b %% 10 == 0) cli::cli_alert_info("Terrain lookup: {min(b * 100, nrow(q))}/{nrow(q)} positions")
  }
  q[, .(id, lat, lon, north_m, east_m, height)]
}
