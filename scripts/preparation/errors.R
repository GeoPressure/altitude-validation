# Accepted observations and error series -----------------------------------
source("R/utils.R")
source("R/ghcnh_sampling.R")
setDTthreads(1)
refresh <- "--refresh" %in% commandArgs(trailingOnly = TRUE)
st <- fread(file.path(dir_tables, "stations.csv"))
gpt3 <- gpt3_read(1)
dir.create(file.path(analysis_dir, "errors"), recursive = TRUE, showWarnings = FALSE)

station_errors <- function(i) {
  s <- st[i]
  out <- file.path(analysis_dir, "errors", paste0(s$network, "_", s$id, ".parquet"))
  accepted <- file.path(selection_dir(s$network), "accepted", paste0(s$id, ".parquet"))
  if (!refresh && file.exists(out) && file.mtime(out) >= file.mtime(accepted)) return(TRUE)
  d <- as.data.table(read_parquet(accepted))
  e <- as.data.table(read_parquet(file.path(analysis_dir, "era5", paste0(s$network, "_", s$id, ".parquet"))))
  if (s$network == "ghcnh") {
    d <- merge(d, e[, .(date, sp_land, t2m_land)], by = "date", all.x = TRUE)
    d[, err_land := era5_altitude(pressure * 100, sp_land, t2m_land, s$z_land) - s$elev]
    L <- gpt3_lapse(gpt3, rep(s$lon, nrow(d)), rep(s$lat, nrow(d)), as.POSIXlt(d$date, tz = "UTC")$yday + 1)
    L <- fifelse(abs(L) < 1e-5, -1e-5, L)
    d[, `:=`(err_standard = err_sl, err_isa = altitude_lapse(pressure * 100, 101325, 288.15, 0) - s$elev,
      err_virtual = altitude_lapse(pressure * 100, sp_sl, virtual_temperature(t2m_sl, d2m, sp_sl), z_sl, L) - s$elev)]
  } else {
    d <- merge(d, e[, .(date, sp_land, t2m_land)], by = "date", all.x = TRUE)
    d <- merge(d, e[, .(date_s = date, sp_land_s = sp_land, t2m_land_s = t2m_land)], by = "date_s", all.x = TRUE)
    d[, `:=`(err_sl_rel = err_standard,
      err_land_rel = (era5_altitude(press, sp_land, t2m_land, s$z_land) -
        era5_altitude(press_s, sp_land_s, t2m_land_s, s$z_land)) - agl,
      surface = FALSE)]
    setorder(d, sounding, -press)
    d[, tmean_obs := sonde_mean_temperature(press, press_s, temp), by = sounding]
    d[, tmean_assumed := t2m_sl - 0.0065 * (gph_s - z_sl + agl / 2)]
  }
  d[, `:=`(id = s$id, year = as.integer(format(date, "%Y")),
    lsh = local_solar_hour(date, s$lon), sdoy = seasonal_doy(date, s$lat))]
  ghcnh_write(d, out)
  TRUE
}
cached <- file.path(analysis_dir, "errors", paste0(st$network, "_", st$id, ".parquet"))
accepted <- vapply(seq_len(nrow(st)), function(i) file.path(selection_dir(st$network[i]), "accepted", paste0(st$id[i], ".parquet")), character(1))
todo <- if (refresh) seq_len(nrow(st)) else which(!file.exists(cached) | file.mtime(cached) < file.mtime(accepted))
res <- par_map(todo, station_errors, cores = n_cores, geopressurer = TRUE, export = c("st", "gpt3", "ghcnh_write", "refresh"))
check_failures(res, st$id[todo], "station error series", fatal = TRUE)
for (net in c("ghcnh", "igra")) {
  files <- file.path(analysis_dir, "errors", paste0(net, "_", st[network == net, id], ".parquet"))
  combined <- file.path(dir_interim, paste0("errors_", net, ".parquet"))
  if (!refresh && file.exists(combined) && all(file.mtime(files) <= file.mtime(combined))) next
  d <- rbindlist(lapply(files, function(f) as.data.table(read_parquet(f))))
  stopifnot(uniqueN(d$id) == st[network == net, .N])
  write_parquet(d, combined)
  cli::cli_alert_success("{net}: {uniqueN(d$id)} stations, {nrow(d)} observations")
}
