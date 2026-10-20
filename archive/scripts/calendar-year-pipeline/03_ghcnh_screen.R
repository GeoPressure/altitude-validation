# Select each station's most recent GHCNh year that passes pressure QC and coverage, then thin spatially.

source("R/utils.R")
set.seed(6)

observations_dir <- file.path(dir_interim, "ghcnh", "observations")
station_dir <- file.path(dir_interim, "ghcnh")
stations <- fread(file.path(station_dir, "candidate_stations.csv"))
matches <- fread(file.path(station_dir, "legacy_station_matches.csv"))
legacy <- matches[, .(legacy_id = legacy_id[1]), by = ghcnh_id]
stations <- merge(stations, legacy, by.x = "id", by.y = "ghcnh_id", all.x = TRUE)
stations[, wmo := substr(legacy_id, 1, 5)]

# Preserve the historical sensitivity check with a reproducible sample of up to 100 candidates.
set.seed(4)
era_candidates <- if (nrow(stations) > 100) sample(stations$id, 100) else stations$id
base <- "https://www.ncei.noaa.gov/oa/global-historical-climatology-network"
raw_annual_dir <- file.path(station_dir, "annual")
dir.create(observations_dir, recursive = TRUE, showWarnings = FALSE)
list_year_ids <- function(year) {
  prefix <- sprintf("hourly/access/by-year/%d/parquet/", year)
  marker <- ""
  ids <- character()
  repeat {
    url <- paste0(base, "/?prefix=", prefix, "&max-keys=1000",
      if (nzchar(marker)) paste0("&marker=", marker) else "")
    xml <- paste(readLines(url, warn = FALSE), collapse = "")
    keys <- regmatches(xml, gregexpr("(?<=<Key>)[^<]+", xml, perl = TRUE))[[1]]
    ids <- c(ids, sub("^.*GHCNh_([^_]+)_[0-9]{4}\\.parquet$", "\\1", keys))
    if (!grepl("<IsTruncated>true</IsTruncated>", xml, fixed = TRUE)) break
    marker <- sub(".*<NextMarker>([^<]+)</NextMarker>.*", "\\1", xml)
  }
  ids
}
download_historical <- function(i) {
  id <- jobs$id[i]
  year <- jobs$year[i]
  out <- file.path(raw_annual_dir, sprintf("%s_%d.parquet", id, year))
  if (!file.exists(out)) {
    tmp <- paste0(out, ".tmp")
    url <- sprintf("%s/hourly/access/by-year/%d/parquet/GHCNh_%s_%d.parquet", base, year, id, year)
    status <- system2("curl", c("-sfL", "--retry", "2", "-o", shQuote(tmp), shQuote(url)))
    if (status == 0) file.rename(tmp, out) else {
      unlink(tmp)
      stop("curl failed: ", url)
    }
  }
  if (file.exists(out)) {
    d <- as.data.table(read_parquet(out))
    keep <- intersect(c("STATION", "Station_name", "DATE", "LATITUDE", "LONGITUDE", "ELEVATION",
      "station_level_pressure", "station_level_pressure_Quality_Code",
      "station_level_pressure_Source_Code"), names(d))
    d <- d[, ..keep]
    d[, DATE := as.POSIXct(DATE, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")]
    setnames(d, tolower(names(d)))
    reduced <- file.path(observations_dir, basename(out))
    write_parquet(d, reduced)
  }
  TRUE
}
jobs <- rbindlist(lapply(years_era, function(year) {
  data.table(id = intersect(era_candidates, list_year_ids(year)), year = year)
}))
res <- par_map(seq_len(nrow(jobs)), download_historical, cores = min(n_cores, 6),
  export = c("jobs", "raw_annual_dir", "observations_dir", "base"))
check_failures(res, jobs$id, "GHCNh historical station files", fatal = TRUE)

read_station_year <- function(id, year) {
  f <- file.path(observations_dir, sprintf("%s_%d.parquet", id, year))
  if (!file.exists(f)) return(data.table())
  d <- as.data.table(read_parquet(f))
  if (!nrow(d) || !"station_level_pressure" %in% names(d)) return(data.table())
  q <- d$station_level_pressure_quality_code
  source <- d$station_level_pressure_source_code
  # Source QC is source-dependent: 2/3 and 6/7 flag suspect/error reports;
  # 5 means removed for 220-223/347-348, but checked-good for the legacy ISD sources.
  d <- d[is.finite(station_level_pressure) & station_level_pressure > 300 &
    station_level_pressure < 1100 & !(q %in% c("2", "3", "6", "7")) &
    !(q %in% "5" & source %in% c("220", "221", "222", "223", "347", "348")) &
    (is.na(q) | !grepl("[a-z]", q))]
  if (!nrow(d)) return(data.table())
  d[, .(id = id, date = as.POSIXct(date, tz = "UTC"), pressure = station_level_pressure,
    quality_code = station_level_pressure_quality_code,
    source_code = station_level_pressure_source_code)]
}

station_coverage <- function(id, years) {
  rbindlist(lapply(years, function(year) {
    d <- read_station_year(id, year)
    if (!nrow(d)) return(data.table(id = id, year = year, n = 0L, reports = 0L, days = 0L, months = 0L))
    hours <- unique(era5_hour(d$date))
    hours <- hours[as.integer(format(hours, "%Y", tz = "UTC")) == year]
    data.table(id = id, year = year, n = length(hours), reports = nrow(d),
      days = uniqueN(as.Date(hours)), months = uniqueN(format(hours, "%Y-%m")))
  }))
}
coverage <- rbindlist(par_map(stations$id, function(id) station_coverage(id, years_ghcnh),
  cores = n_cores, export = c("station_coverage", "read_station_year", "observations_dir",
    "years_ghcnh")))
historical_coverage <- rbindlist(par_map(era_candidates,
  function(id) station_coverage(id, years_era), cores = min(n_cores, 6),
  export = c("station_coverage", "read_station_year", "observations_dir", "years_era")))
coverage <- unique(rbind(coverage, historical_coverage))
fwrite(coverage, file.path(dir_interim, "ghcnh_coverage.csv"))

qc_summary <- arrow::open_dataset(observations_dir) |>
  dplyr::filter(station_level_pressure > 300, station_level_pressure < 1100) |>
  dplyr::count(station_level_pressure_quality_code, station_level_pressure_source_code) |>
  dplyr::collect()
fwrite(as.data.table(qc_summary), file.path(dir_interim, "ghcnh_qc_summary.csv"))

best_year <- coverage[year %in% years_ghcnh & days >= 183 & n / pmax(days, 1) >= 4,
  .(selected_year = max(year)), by = id]
stations_all <- merge(stations, best_year, by.x = "id", by.y = "id")
fwrite(stations_all, file.path(dir_interim, "ghcnh_stations_all.csv"))
selected <- thin_stations(stations_all)
fwrite(selected, file.path(dir_interim, "ghcnh_stations.csv"))

# Save only screened pressure reports in one station file for the downstream ERA5 comparison.
pressure_dir <- file.path(station_dir, "pressure")
dir.create(pressure_dir, showWarnings = FALSE)
write_station <- function(i) {
  id <- stations_all$id[i]
  station_years <- unique(c(years_ghcnh[years_ghcnh <= stations_all$selected_year[i] &
    years_ghcnh >= stations_all$selected_year[i] - 2], if (id %in% era_candidates) years_era))
  d <- rbindlist(lapply(station_years, function(year) read_station_year(id, year)))
  write_parquet(d, file.path(pressure_dir, paste0(id, ".parquet")))
  TRUE
}
res <- par_map(seq_len(nrow(stations_all)), write_station, cores = n_cores,
  export = c("stations_all", "years_era", "era_candidates", "observations_dir",
    "read_station_year", "pressure_dir"))
check_failures(res, stations_all$id, "GHCNh screened station pressure", fatal = TRUE)

jsonlite::write_json(list(source = "NOAA GHCNh", candidate_years = years_ghcnh,
  selected_year_rule = "Most recent year with at least 183 reporting days and 4 distinct accepted pressure hours per reporting day",
  quality_rule = "Keep missing QC and accepted legacy flags; exclude suspect/error codes and lowercase QC flags",
  coverage_rule = "At least 183 reporting days and 4 distinct accepted pressure hours per reporting day in the selected year",
  n_candidates = nrow(stations), n_coverage_pass = nrow(stations_all),
  n_selected = nrow(selected), generated_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)),
  file.path(station_dir, "screening_provenance.json"), pretty = TRUE, auto_unbox = TRUE)
fwrite(data.table(id = era_candidates), file.path(dir_interim, "ghcnh_era_candidate_ids.csv"))

cat(nrow(stations_all), "GHCNh stations have a qualifying year;", nrow(selected),
  "retained after spatial thinning\n")
