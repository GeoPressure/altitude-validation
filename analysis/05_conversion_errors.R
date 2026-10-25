# Conversion errors of every accepted ground observation and sounding level: the standard
# atmosphere, ERA5 with the standard lapse rate and ERA5 with virtual temperature and the GPT3 lapse
# rate. Ground errors are also computed with ERA5-Land surface conditions. Run with --refresh to recompute cached stations.
source("R/utils.R")
source("R/ghcnh.R")
setDTthreads(1)
refresh <- "--refresh" %in% commandArgs(trailingOnly = TRUE)
st <- fread(file.path(dir_tables, "stations.csv"))
gpt3 <- gpt3_read(1)
for (part in c("era5_land", "errors")) {
  dir.create(
    file.path(analysis_dir, part),
    recursive = TRUE,
    showWarnings = FALSE
  )
}
accepted_file <- function(network, id) {
  file.path(network_dir(network), "accepted", paste0(id, ".parquet"))
}

# ERA5-Land surface pressure and 2 m temperature at the accepted ground hours -----------------
ground <- which(st$network == "ghcnh")
era5_land <- function(i) {
  s <- st[i]
  out <- file.path(analysis_dir, "era5_land", paste0(s$id, ".parquet"))
  e <- data.table(
    date = sort(unique(
      read_parquet(accepted_file(s$network, s$id), col_select = "date")$date
    ))
  )
  if (file.exists(out)) {
    e <- merge(e, as.data.table(read_parquet(out)), by = "date", all.x = TRUE)
  } else {
    e[, `:=`(sp_land = NA_real_, t2m_land = NA_real_)]
  }
  for (v in c("sp_land", "t2m_land")) {
    missing <- which(!is.finite(e[[v]]))
    if (!length(missing)) {
      next
    }
    variable <- c(sp_land = "surface_pressure", t2m_land = "temperature_2m")[[
      v
    ]]
    values <- era5_read(
      rep(s$lon, length(missing)),
      rep(s$lat, length(missing)),
      e$date[missing],
      variable,
      "land"
    )
    set(e, i = missing, j = v, value = values[[1]])
  }
  ghcnh_write(e, out)
  TRUE
}
res <- par_map(
  ground,
  era5_land,
  cores = n_cores,
  geopressurer = TRUE,
  export = c("st", "ghcnh_write", "accepted_file")
)
check_failures(res, st$id[ground], "ERA5-Land series", fatal = TRUE)

# Errors per station ---------------------------------------------------------------------------
lapse_gpt3 <- function(lon, lat, date) {
  L <- gpt3_lapse(
    gpt3,
    rep(lon, length(date)),
    rep(lat, length(date)),
    as.POSIXlt(date, tz = "UTC")$yday + 1
  )
  fifelse(abs(L) < 1e-5, -1e-5, L)
}
station_errors <- function(i) {
  s <- st[i]
  out <- file.path(
    analysis_dir,
    "errors",
    paste0(s$network, "_", s$id, ".parquet")
  )
  accepted <- accepted_file(s$network, s$id)
  if (!refresh && file.exists(out) && file.mtime(out) >= file.mtime(accepted)) {
    return(TRUE)
  }
  d <- as.data.table(read_parquet(accepted))
  if (s$network == "ghcnh") {
    e <- as.data.table(read_parquet(file.path(
      analysis_dir,
      "era5_land",
      paste0(s$id, ".parquet")
    )))
    d <- merge(d, e[, .(date, sp_land, t2m_land)], by = "date", all.x = TRUE)
    # Altitude error at the station: estimate minus reported elevation.
    d[, `:=`(
      err_land = era5_altitude(pressure * 100, sp_land, t2m_land, s$z_land) -
        s$elev,
      err_standard = err_sl,
      err_isa = altitude_lapse(pressure * 100, 101325, 288.15, 0) - s$elev,
      err_virtual = altitude_lapse(
        pressure * 100,
        sp_sl,
        virtual_temperature(t2m_sl, d2m, sp_sl),
        z_sl,
        lapse_gpt3(s$lon, s$lat, date)
      ) -
        s$elev
    )]
  } else {
    # Flight-height error: height above the launch surface minus the radiosonde's height.
    # Layer-mean temperature observed by the sonde and assumed by the standard-lapse conversion.
    setorder(d, sounding, -press)
    d[,
      tmean_obs := sonde_mean_temperature(press, press_s, temp),
      by = sounding
    ]
    d[, tmean_assumed := t2m_sl - 0.0065 * (gph_s - z_sl + agl / 2)]
  }
  d[, `:=`(
    id = s$id,
    year = as.integer(format(date, "%Y")),
    lsh = local_solar_hour(date, s$lon),
    sdoy = seasonal_doy(date, s$lat)
  )]
  ghcnh_write(d, out)
  TRUE
}
todo <- seq_len(nrow(st))
res <- par_map(
  todo,
  station_errors,
  cores = n_cores,
  geopressurer = TRUE,
  export = c(
    "st",
    "gpt3",
    "ghcnh_write",
    "refresh",
    "accepted_file",
    "lapse_gpt3"
  )
)
check_failures(res, st$id[todo], "station error series", fatal = TRUE)

# One error file per network --------------------------------------------------------------------
for (net in c("ghcnh", "igra")) {
  d <- rbindlist(lapply(
    file.path(
      analysis_dir,
      "errors",
      paste0(net, "_", st[network == net, id], ".parquet")
    ),
    function(f) as.data.table(read_parquet(f))
  ))
  stopifnot(uniqueN(d$id) == st[network == net, .N])
  write_parquet(d, file.path(dir_derived, paste0("errors_", net, ".parquet")))
  cli::cli_alert_success(
    "{net}: {uniqueN(d$id)} stations, {nrow(d)} observations"
  )
}
