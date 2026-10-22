# Static covariates for the completed station selections -------------------
source("R/utils.R")

st <- rbindlist(lapply(c("ghcnh", "igra"), function(network) {
  run <- selection_dir(network)
  stopifnot(fread(file.path(run, "full-metrics.csv"))$pending == 0)
  s <- fread(file.path(run, "full-accepted.csv"))
  s[, .(network, id, name, lat, lon, elev, cell, window_start, window_end)]
}))
previous <- if (file.exists(file.path(dir_tables, "stations.csv"))) fread(file.path(dir_tables, "stations.csv")) else st[, .(network, id, lat, lon, z_sl = NA_real_, z_land = NA_real_)]
index <- match(paste(st$network, st$id, st$lat, st$lon), paste(previous$network, previous$id, previous$lat, previous$lon))
st[, `:=`(z_sl = previous$z_sl[index], z_land = previous$z_land[index])]
st[!is.finite(z_sl), z_sl := vapply(seq_len(.N), function(i) {
  read_parquet(file.path(selection_dir(network[i]), "accepted", paste0(id[i], ".parquet")), col_select = "z_sl")$z_sl[1]
}, numeric(1))]
if (any(!is.finite(st$z_land))) {
  load_geopressurer()
  st[!is.finite(z_land), z_land := era5_orography(lon, lat, "land")]
}
inv <- terra::rast(file.path(dir_raw, "era5_invariant.nc"))
names(inv) <- ifelse(grepl("sdor", names(inv)), "sdor", "lsm")
if (terra::xmax(inv) > 180) inv <- terra::rotate(inv)
g <- era5_snap(st$lon, st$lat, "single-levels")
iv <- terra::extract(inv, cbind(g$lon, g$lat))
st[, `:=`(sdor = iv$sdor, lsm = iv$lsm)]
data("climatezones", package = "kgc", envir = globalenv())
kz <- data.frame(Site = st$id, Longitude = st$lon, Latitude = st$lat,
  rndCoord.lon = kgc::RoundCoordinates(st$lon), rndCoord.lat = kgc::RoundCoordinates(st$lat))
st[, koppen := as.character(kgc::LookupCZ(kz))]
st[, koppen_main := substr(koppen, 1, 1)]
st[, `:=`(dz_sl = elev - z_sl, dz_land = elev - z_land)]
fwrite(st, file.path(dir_tables, "stations.csv"))
cli::cli_alert_success("Static covariates: {sum(st$network == 'ghcnh')} GHCNh and {sum(st$network == 'igra')} IGRA stations")
