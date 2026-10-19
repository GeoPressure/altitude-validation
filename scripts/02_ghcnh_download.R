# Download GHCNh station-year files near the legacy surface-station locations.
#
# NCEI publishes both complete period-of-record station files and compact annual Parquet files.
# Annual files keep the transfer limited to study years and the historical station footprint.

source("R/utils.R")

years <- years_ghcnh
match_radius_km <- as.numeric(Sys.getenv("GHCNH_MATCH_RADIUS_KM", "25"))
base <- "https://www.ncei.noaa.gov/oa/global-historical-climatology-network"
out_dir <- file.path(dir_interim, "ghcnh", "annual")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# ---- Station metadata -----------------------------------------------------------------------
station_file <- file.path(dir_raw, "ghcnh-station-list.txt")
if (!file.exists(station_file)) {
  curl_download(paste0(base, "/hourly/doc/ghcnh-station-list.txt"), station_file)
}
x <- readLines(station_file, warn = FALSE)
ghcnh <- data.table(
  id = trimws(substr(x, 1, 11)),
  lat = as.numeric(substr(x, 13, 20)),
  lon = as.numeric(substr(x, 22, 30)),
  elev = as.numeric(substr(x, 32, 37)),
  state = trimws(substr(x, 39, 40)),
  name = trimws(substr(x, 42, 71))
)[is.finite(lat) & is.finite(lon) & is.finite(elev) & elev > -900]

frame <- fread(file.path(dir_interim, "ghcnh_match_frame.csv"))
distance_km <- function(lon1, lat1, lon2, lat2) {
  6371 * 2 * asin(sqrt(sin((lat2 - lat1) * pi / 360)^2 +
    cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin((lon2 - lon1) * pi / 360)^2))
}
nearest <- rbindlist(lapply(seq_len(nrow(frame)), function(i) {
  radius_lat <- match_radius_km / 110.574
  radius_lon <- match_radius_km / (111.320 * cos(frame$lat[i] * pi / 180))
  candidates <- which(abs(ghcnh$lat - frame$lat[i]) <= radius_lat &
    abs(ghcnh$lon - frame$lon[i]) <= radius_lon)
  if (!length(candidates)) return(NULL)
  d <- distance_km(frame$lon[i], frame$lat[i], ghcnh$lon[candidates], ghcnh$lat[candidates])
  j <- which.min(d)
  if (d[j] <= match_radius_km) data.table(legacy_id = frame$legacy_id[i], ghcnh_id = ghcnh$id[candidates[j]],
    distance_km = d[j])
}))
nearest <- merge(nearest, frame[, .(legacy_id, legacy_lat = lat, legacy_lon = lon,
  legacy_elev)], by = "legacy_id")
nearest <- merge(nearest, ghcnh[, .(ghcnh_id = id, ghcnh_lat = lat, ghcnh_lon = lon,
  ghcnh_elev = elev)], by = "ghcnh_id")
nearest[, elevation_difference_m := ghcnh_elev - legacy_elev]
fwrite(nearest, file.path(dir_interim, "ghcnh", "legacy_station_matches.csv"))
selected <- ghcnh[id %in% nearest$ghcnh_id]
fwrite(selected, file.path(dir_interim, "ghcnh", "candidate_stations.csv"))
cat(nrow(selected), "GHCNh stations within", match_radius_km,
  "km of the legacy station locations\n")

# ---- Annual files ----------------------------------------------------------------------------
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

for (year in years) {
  available <- list_year_ids(year)
  ids <- intersect(selected$id, available)
  jobs <- data.table(id = ids, year = year)
  download_station_year <- function(i) {
    id <- jobs$id[i]
    year <- jobs$year[i]
    out <- file.path(out_dir, sprintf("%s_%d.parquet", id, year))
    if (file.exists(out)) return(TRUE)
    url <- sprintf("%s/hourly/access/by-year/%d/parquet/GHCNh_%s_%d.parquet",
      base, year, id, year)
    tmp <- paste0(out, ".tmp")
    status <- system2("curl", c("-sfL", "--retry", "3", "-o", shQuote(tmp), shQuote(url)))
    if (status == 0) file.rename(tmp, out) else unlink(tmp)
    if (status != 0) stop("curl failed: ", url)
    TRUE
  }
  if (nrow(jobs)) {
    res <- par_map(seq_len(nrow(jobs)), download_station_year, cores = min(n_cores, 16),
      export = c("jobs", "base", "out_dir"))
    check_failures(res, jobs$id, paste(year, "GHCNh station files"), fatal = TRUE)
  }
  cat(year, ":", sum(file.exists(file.path(out_dir,
    sprintf("%s_%d.parquet", ids, year)))), "of", length(ids), "available station files\n")
}

provenance_file <- file.path(dir_interim, "ghcnh", "provenance.json")
rebuild_extracts <- Sys.getenv("GHCNH_REBUILD_EXTRACTS") == "1" ||
  !file.exists(provenance_file) ||
  !identical(jsonlite::fromJSON(provenance_file)$timestamp_format, "%Y-%m-%dT%H:%M:%S")

# Keep the analysis fields in one Parquet file per station-year. This makes the comparison easy to
# query with `arrow::open_dataset()` without holding the whole global sample in memory.
files <- file.path(out_dir, as.vector(outer(selected$id, years,
  function(id, year) sprintf("%s_%d.parquet", id, year))))
files <- files[file.exists(files)]
observations_dir <- file.path(dir_interim, "ghcnh", "observations")
dir.create(observations_dir, recursive = TRUE, showWarnings = FALSE)
filter_observation_file <- function(f) {
  out <- file.path(observations_dir, basename(f))
  if (file.exists(out) && !rebuild_extracts) return(TRUE)
  columns <- arrow::open_dataset(f)$schema$names
  keep <- intersect(c("STATION", "Station_name", "DATE", "LATITUDE", "LONGITUDE", "ELEVATION",
    "station_level_pressure", "station_level_pressure_Quality_Code",
    "station_level_pressure_Source_Code"), columns)
  d <- as.data.table(read_parquet(f, col_select = tidyselect::all_of(keep)))
  d[, DATE := as.POSIXct(DATE, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")]
  setnames(d, tolower(names(d)))
  write_parquet(d, out)
  TRUE
}
res <- par_map(files, filter_observation_file, cores = min(n_cores, 16),
  export = c("observations_dir", "rebuild_extracts"))
check_failures(res, files, "GHCNh station-year extracts", fatal = TRUE)

jsonlite::write_json(list(source = "NOAA GHCNh", years = years, timestamp_format = "%Y-%m-%dT%H:%M:%S",
  match_radius_km = match_radius_km, generated_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  station_list_url = paste0(base, "/hourly/doc/ghcnh-station-list.txt"),
  annual_data_url = paste0(base, "/hourly/access/by-year/"),
  observations_dir = observations_dir, n_stations = nrow(selected),
  n_station_year_files = length(files)),
  file.path(dir_interim, "ghcnh", "provenance.json"), pretty = TRUE, auto_unbox = TRUE)
