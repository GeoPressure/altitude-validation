# Static covariates of the selected stations: ERA5 and ERA5-Land orography, sub-grid orography
# (terrain roughness), land-sea mask and Köppen–Geiger climate zone.
source("R/utils.R")
load_geopressurer()

st <- rbindlist(lapply(c("ghcnh", "igra"), function(network) {
  s <- fread(file.path(network_dir(network), "stations.csv"))
  s[, .(network, id, name, lat, lon, elev, cell, window_start, window_end)]
}))
st[, z_sl := era5_orography(lon, lat, "single-levels")]
st[, z_land := era5_orography(lon, lat, "land")]
inv <- terra::rast(file.path(dir_raw, "era5_invariant.nc"))
names(inv) <- ifelse(grepl("sdor", names(inv)), "sdor", "lsm")
if (terra::xmax(inv) > 180) {
  inv <- terra::rotate(inv)
}
g <- era5_snap(st$lon, st$lat, "single-levels")
iv <- terra::extract(inv, cbind(g$lon, g$lat))
st[, `:=`(sdor = iv$sdor, lsm = iv$lsm)]
data("climatezones", package = "kgc", envir = globalenv())
kz <- data.frame(
  Site = st$id,
  Longitude = st$lon,
  Latitude = st$lat,
  rndCoord.lon = kgc::RoundCoordinates(st$lon),
  rndCoord.lat = kgc::RoundCoordinates(st$lat)
)
st[, koppen := as.character(kgc::LookupCZ(kz))]
st[!grepl("^[ABCDE][A-Za-z]{1,2}$", koppen), koppen := NA_character_]
st[, koppen_main := substr(koppen, 1, 1)]
st[, `:=`(dz_sl = elev - z_sl, dz_land = elev - z_land)]
fwrite(st, file.path(dir_tables, "stations.csv"))
cli::cli_alert_success(
  "Static covariates: {sum(st$network == 'ghcnh')} GHCNh and {sum(st$network == 'igra')} IGRA2 stations"
)
