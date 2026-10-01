# Static, per-station covariates for HadISD and IGRA2 stations.
#
#  - ERA5 orography at the cell GeoPressureR samples, for single-levels (0.25 deg) and land (0.1 deg)
#  - ERA5 standard deviation of sub-grid orography (`sdor`, terrain roughness) and land-sea mask
#  - An independent DEM elevation at the station coordinates (OpenTopoData, Mapzen terrain tiles:
#    SRTM/ASTER/... ~30-90 m), used to flag stations whose reported elevation looks wrong
#  - Koppen-Geiger climate zone (kgc package, 1986-2010)

source("R/utils.R")
load_geopressurer()

# ---- ERA5 invariants ------------------------------------------------------------------------
inv_file <- file.path(dir_raw, "era5_invariant.nc")
if (!file.exists(inv_file)) {
  ecmwfr::wf_request(
    list(
      dataset_short_name = "reanalysis-era5-single-levels",
      product_type = "reanalysis",
      variable = c("standard_deviation_of_orography", "land_sea_mask"),
      year = "2000", month = "01", day = "01", time = "00:00",
      data_format = "netcdf", download_format = "unarchived",
      target = basename(inv_file)
    ),
    path = dir_raw, verbose = FALSE
  )
}
inv <- terra::rast(inv_file)
names(inv) <- ifelse(grepl("sdor", names(inv)), "sdor", "lsm")
if (terra::xmax(inv) > 180) inv <- terra::rotate(inv)

# ---- Stations -------------------------------------------------------------------------------
stA <- fread(file.path(dir_interim, "hadisd_stations.csv"))[, .(id, name, lat, lon, elev, network = "hadisd")]
# Radiosonde stations selected in 04_igra_download.R.
stB <- fread(file.path(dir_interim, "igra_stations.csv"))[, .(id, name, lat, lon, elev, network = "igra")]
st <- rbind(stA, stB)

g <- era5_snap(st$lon, st$lat, "single-levels")
st[, z_sl := era5_orography(lon, lat, "single-levels")]
st[, z_land := era5_orography(lon, lat, "land")]
iv <- terra::extract(inv, cbind(g$lon, g$lat))
st[, sdor := iv$sdor]
st[, lsm := iv$lsm]

# ---- Independent DEM ------------------------------------------------------------------------
dem_file <- file.path(dir_interim, "station_dem.csv")
dem <- if (file.exists(dem_file)) fread(dem_file) else data.table(id = character(), dem = numeric())
todo <- st[!id %in% dem$id]
if (nrow(todo) > 0) {
  batches <- split(seq_len(nrow(todo)), ceiling(seq_len(nrow(todo)) / 100))
  for (b in batches) {
    loc <- paste(sprintf("%.5f,%.5f", todo$lat[b], todo$lon[b]), collapse = "|")
    r <- httr2::request("https://api.opentopodata.org/v1/mapzen") |>
      httr2::req_url_query(locations = loc) |>
      httr2::req_retry(max_tries = 5) |>
      httr2::req_perform() |>
      httr2::resp_body_json()
    el <- vapply(r$results, function(z) if (is.null(z$elevation)) NA_real_ else z$elevation, 1)
    dem <- rbind(dem, data.table(id = todo$id[b], dem = el))
    fwrite(dem, dem_file)
    Sys.sleep(1.1) # public API: 1 call per second
  }
}
st <- merge(st, unique(dem, by = "id"), by = "id", all.x = TRUE)

# ---- Koppen ---------------------------------------------------------------------------------
# LookupCZ() looks its lookup table up in the global environment.
data("climatezones", package = "kgc", envir = globalenv())
kz <- data.frame(
  Site = st$id,
  Longitude = st$lon,
  Latitude = st$lat,
  rndCoord.lon = kgc::RoundCoordinates(st$lon),
  rndCoord.lat = kgc::RoundCoordinates(st$lat)
)
st[, koppen := as.character(kgc::LookupCZ(kz))]
st[, koppen_main := substr(koppen, 1, 1)]
st[koppen_main %in% c("", "C") & koppen %in% c(NA, "Climate Zone info missing"), koppen_main := NA]

st[, dz_sl := elev - z_sl]
st[, dz_land := elev - z_land]
st[, dem_diff := elev - dem]

fwrite(st, file.path(dir_tables, "stations.csv"))
print(st[, .(n = .N, sdor_med = median(sdor, na.rm = TRUE), abs_dem_diff_med = median(abs(dem_diff),
  na.rm = TRUE)), by = network])
