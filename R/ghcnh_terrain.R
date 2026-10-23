# Independent coordinate–height consistency check for GHCNh candidates.
ghcnh_terrain <- function(stations, cache = "data/interim/ghcnh/terrain-srtm-aster") {
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
