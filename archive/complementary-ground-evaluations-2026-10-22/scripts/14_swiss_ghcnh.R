# Paired Swiss height references, using all WMO-matched GHCNh stations.
# Downloads and errors stay in a dedicated cache; the global selection is read-only.
source("R/utils.R")
load_geopressurer()
suppressPackageStartupMessages(library(sf))
setDTthreads(1)
cache <- "data/interim/swiss-ghcnh"
for (part in c("annual", "pressure", "errors")) dir.create(file.path(cache, part), recursive = TRUE, showWarnings = FALSE)
primary_paths <- c("output/tables/stations.csv", "output/tables/ground_station_stats.csv",
  file.path(selection_dir("ghcnh"), "full-accepted.csv"), "output/tables/paper_ground.csv")
primary_md5 <- tools::md5sum(primary_paths)

# Match identities before assessing co-location and pressure coverage.
meta <- readLines(file.path(dir_raw, "ghcnh-station-list.txt"), warn = FALSE)
ghcnh <- data.table(ghcnh_id = trimws(substr(meta, 1, 11)), ghcnh_lat = as.numeric(substr(meta, 13, 20)),
  ghcnh_lon = as.numeric(substr(meta, 22, 30)), ghcnh_elev = as.numeric(substr(meta, 32, 37)),
  wmo = trimws(substr(meta, 81, 85)))
swiss <- fread(file.path(dir_interim, "meteoswiss", "stations.csv"))
swiss[, wmo := sprintf("%05d", as.integer(wmo))]
matches <- merge(swiss, ghcnh[wmo != ""], by = "wmo")
matches[, match_distance_km := as.numeric(st_distance(
  st_as_sf(matches, coords = c("ghcnh_lon", "ghcnh_lat"), crs = 4326),
  st_as_sf(matches, coords = c("lon", "lat"), crs = 4326), by_element = TRUE)) / 1000]
setorder(matches, wmo)
fwrite(matches, file.path(cache, "matches.csv"))
catalogue <- rbindlist(lapply(years_main, function(y) readRDS(file.path(selection_dir("ghcnh"), "catalogue", paste0(y, ".rds")))))
annuals <- unique(merge(matches[, .(id = ghcnh_id)], catalogue[, .(id, year)], by = "id"))
base <- "https://www.ncei.noaa.gov/oa/global-historical-climatology-network"

# Reuse existing raw files read-only; new files are downloaded to the Swiss cache.
prepare_annual <- function(i) {
  a <- annuals[i]
  output <- file.path(cache, "pressure", sprintf("%s_%d.parquet", a$id, a$year))
  if (file.exists(output)) return(TRUE)
  filename <- sprintf("%s_%d.parquet", a$id, a$year)
  reduced <- file.path("data/interim/ghcnh/observations", filename)
  if (file.exists(reduced)) d <- as.data.table(read_parquet(reduced)) else {
    raw <- file.path("data/interim/ghcnh/annual", filename)
    if (!file.exists(raw)) raw <- file.path(cache, "annual", filename)
    if (!file.exists(raw)) {
      url <- sprintf("%s/hourly/access/by-year/%d/parquet/GHCNh_%s_%d.parquet", base, a$year, a$id, a$year)
      curl_download(url, paste0(raw, ".tmp"))
      read_parquet(paste0(raw, ".tmp"), col_select = "STATION")
      stopifnot(file.rename(paste0(raw, ".tmp"), raw))
    }
    keep <- names(open_dataset(raw)$schema)
    keep <- keep[tolower(keep) %in% c("date", "station_level_pressure", "station_level_pressure_quality_code", "station_level_pressure_source_code")]
    d <- as.data.table(read_parquet(raw, col_select = tidyselect::all_of(keep)))
    setnames(d, tolower(names(d)))
  }
  q <- as.character(d$station_level_pressure_quality_code)
  src <- as.character(d$station_level_pressure_source_code)
  d <- d[is.finite(station_level_pressure) & station_level_pressure > 300 & station_level_pressure < 1100 &
    !q %in% c("2", "3", "6", "7") & !(q %in% "5" & src %in% c("220", "221", "222", "223", "347", "348")) &
    (is.na(q) | !grepl("[a-z]", q)),
    .(date = as.POSIXct(date, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC"), pressure = station_level_pressure)]
  d[, hour := era5_hour(date)]
  d[, distance := abs(as.numeric(difftime(date, hour, units = "secs")))]
  setorder(d, hour, distance, date)
  d <- unique(d, by = "hour")
  d[, date := hour]
  d <- d[date >= as.POSIXct("2022-01-01", tz = "UTC") & date < as.POSIXct("2025-01-01", tz = "UTC"), .(date, pressure)]
  write_parquet(d, output)
  TRUE
}
cli::cli_alert_info("Preparing {nrow(annuals)} annual files for {nrow(matches)} WMO matches")
res <- par_map(seq_len(nrow(annuals)), prepare_annual, cores = 6,
  export = c("annuals", "cache", "base"))
check_failures(res, paste(annuals$id, annuals$year), "Swiss GHCNh annual files", fatal = TRUE)

# Evaluate co-located sites with documented pressure-sensor heights.
pairs <- matches[match_distance_km <= 1]
meteo <- fread(file.path(dir_tables, "indep_station_stats.csv"))[source == "MeteoSwiss"]
paired_errors <- function(i) {
  s <- pairs[i]
  output <- file.path(cache, "errors", paste0(s$ghcnh_id, ".parquet"))
  if (file.exists(output)) return(TRUE)
  files <- file.path(cache, "pressure", sprintf("%s_%d.parquet", s$ghcnh_id, annuals[id == s$ghcnh_id, year]))
  d <- rbindlist(lapply(files, function(f) as.data.table(read_parquet(f))))
  setorder(d, date)
  # Reuse ERA5 annotations only when the two coordinates select the same grid cell.
  g <- era5_snap(c(s$ghcnh_lon, s$lon), c(s$ghcnh_lat, s$lat), "single-levels")
  cached <- file.path(dir_interim, "indep", paste0("MeteoSwiss_", s$id, ".parquet"))
  e <- data.table(date = d$date, sp_sl = NA_real_, t2m_sl = NA_real_)
  if (g$lon[1] == g$lon[2] && g$lat[1] == g$lat[2] && file.exists(cached)) {
    previous <- as.data.table(read_parquet(cached, col_select = c("date", "sp_sl", "t2m_sl")))
    previous <- previous[, .(sp_sl = mean(sp_sl), t2m_sl = mean(t2m_sl)), by = date]
    e[previous, on = "date", `:=`(sp_sl = i.sp_sl, t2m_sl = i.t2m_sl)]
  }
  missing <- which(!is.finite(e$sp_sl) | !is.finite(e$t2m_sl))
  if (length(missing)) {
    a <- era5_read(rep(s$ghcnh_lon, length(missing)), rep(s$ghcnh_lat, length(missing)), e$date[missing],
      c("surface_pressure", "temperature_2m"), "single-levels")
    e[missing, `:=`(sp_sl = a$surface_pressure, t2m_sl = a$temperature_2m)]
  }
  z <- era5_orography(s$ghcnh_lon, s$ghcnh_lat, "single-levels")
  d[, `:=`(sp_sl = e$sp_sl, t2m_sl = e$t2m_sl)]
  d <- d[is.finite(sp_sl) & is.finite(t2m_sl)]
  d[, altitude := era5_altitude(pressure * 100, sp_sl, t2m_sl, z)]
  d[, err_listed := altitude - s$ghcnh_elev]
  d <- d[abs(err_listed - median(err_listed)) <= max(100, 10 * mad(err_listed))]
  d[, err_sensor := altitude - s$elev]
  write_parquet(d, output)
  TRUE
}
cli::cli_alert_info("Evaluating {nrow(pairs)} pairs within 1 km")
res <- par_map(seq_len(nrow(pairs)), paired_errors, cores = 4, geopressurer = TRUE,
  export = c("pairs", "annuals", "cache"))
check_failures(res, pairs$ghcnh_id, "Swiss paired errors", fatal = TRUE)
stats <- rbindlist(lapply(pairs$ghcnh_id, function(id) {
  d <- as.data.table(read_parquet(file.path(cache, "errors", paste0(id, ".parquet"))))
  stopifnot(!anyDuplicated(d$date), all(abs((d$err_sensor - d$err_listed) -
    pairs[ghcnh_id == id, ghcnh_elev - elev]) < 1e-8))
  d[, .(ghcnh_id = id, n = .N, start = min(date), end = max(date),
    bias_ghcnh = mean(err_listed), bias_height_only = mean(err_sensor), sd = sd(err_listed))]
}))
ms <- merge(pairs, stats[n >= 2160], by = "ghcnh_id")
ms[, `:=`(d_station = ghcnh_elev - elev_station, d_barometer = ghcnh_elev - elev)]
ms <- merge(ms, meteo[, .(id, bias_meteoswiss = bias_sl)], by = "id", all.x = TRUE)
fwrite(ms, file.path(dir_tables, "meteoswiss_vs_ghcnh.csv"))
fwrite(ms, file.path(dir_tables, "paper_swiss_height.csv"))
fwrite(ms[, .(n = .N, median_abs_ghcnh = median(abs(bias_ghcnh)),
  median_abs_height_only = median(abs(bias_height_only)))], file.path(dir_tables, "paper_swiss_height_summary.csv"))
stopifnot(identical(primary_md5, tools::md5sum(primary_paths)))
cli::cli_alert_success("{nrow(ms)} Swiss pairs retained; global GHCNh inputs and summaries unchanged")
print(ms[, .(n = .N, median_abs_listed = median(abs(bias_ghcnh)), median_abs_sensor = median(abs(bias_height_only)))])
