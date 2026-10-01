# Compute altitude errors at the HadISD surface stations and the IGRA2 radiosondes.
#
# error = altitude retrieved by GeoPressureR from the observed pressure - reference altitude
#   HadISD reference: the station elevation (HadISD metadata)
#   IGRA2 reference:  the radiosonde's geopotential height at that pressure level
#
# Both ERA5 single-levels (`_sl`, the GeoPressureR/GeoPressureAPI default) and ERA5-Land (`_land`)
# are evaluated with otherwise identical code.

source("R/utils.R")
load_geopressurer()

st <- fread(file.path(dir_tables, "stations.csv"))
era5_dir <- file.path(dir_interim, "era5")

add_era5_covariates <- function(e) {
  setorder(e, date)
  # 6-hour surface pressure tendency (Pa), centred
  e[, dsp6 := shift(sp_sl, -3) - shift(sp_sl, 3)]
  # skin minus 2 m temperature: negative when the surface is colder than the air (stable,
  # typically nocturnal/winter inversion); positive under daytime heating
  e[, skt_t2m := skt - t2m_sl]
  e
}

# The formula variants of 16_formula.R rely on altitude_lapse() reproducing GeoPressureR.
stopifnot(isTRUE(all.equal(
  altitude_lapse(80000, 95000, 280, 500), era5_altitude(80000, 95000, 280, 500)
)))

# ---- HadISD --------------------------------------------------------------------------------
errA_station <- function(i) {
  s <- st[network == "hadisd"][i]
  o <- as.data.table(read_parquet(file.path(dir_interim, "hadisd", paste0(s$id, ".parquet"))))
  f <- file.path(era5_dir, paste0("hadisd_", s$id, ".parquet"))
  if (!file.exists(f) || nrow(o) == 0) return(NULL)
  e <- add_era5_covariates(as.data.table(read_parquet(f)))
  o[, date := era5_hour(date)]
  o <- unique(o, by = "date")
  d <- merge(o, e, by = "date")
  d[, h_sl := era5_altitude(pressure * 100, sp_sl, t2m_sl, s$z_sl)]
  d[, h_land := era5_altitude(pressure * 100, sp_land, t2m_land, s$z_land)]
  d[, err_sl := h_sl - s$elev]
  d[, err_land := h_land - s$elev]
  # Gross observation errors (typos, unit slips that survived HadISD QC): more than 100 m and 10
  # robust SD away from the station's own median error.
  med <- median(d$err_sl, na.rm = TRUE)
  rsd <- mad(d$err_sl, na.rm = TRUE)
  d[, gross := abs(err_sl - med) > max(100, 10 * rsd)]
  d[, `:=`(
    id = s$id,
    year = as.integer(format(date, "%Y")),
    lsh = local_solar_hour(date, s$lon),
    sdoy = seasonal_doy(date, s$lat)
  )]
  d[, .(id, date, year, lsh, sdoy, pressure, err_sl, err_land, gross, blh, skt_t2m, dsp6,
    t2m_sl, sp_sl)]
}

nA <- nrow(st[network == "hadisd"])
resA <- par_map(seq_len(nA), errA_station, cores = n_cores, geopressurer = TRUE,
  export = c("st", "era5_dir", "add_era5_covariates"))
A <- rbindlist(Filter(is.data.frame, resA))
write_parquet(A, file.path(dir_interim, "errors_hadisd.parquet"))
cat("HadISD:", uniqueN(A$id), "stations,", nrow(A), "observations,",
  sprintf("%.3f%%", 100 * mean(A$gross, na.rm = TRUE)), "flagged gross\n")

# ---- IGRA2 ---------------------------------------------------------------------------------
parse_hhmm <- function(x) {
  x <- sprintf("%04d", as.integer(x))
  hh <- as.integer(substr(x, 1, 2))
  mm <- as.integer(substr(x, 3, 4))
  mm[mm == 99] <- 0L
  ifelse(hh <= 23 & mm <= 59, hh + mm / 60, NA_real_)
}

errB_station <- function(i) {
  s <- st[network == "igra"][i]
  f_obs <- file.path(dir_interim, "igra", paste0(s$id, ".parquet"))
  f <- file.path(era5_dir, paste0("igra_", s$id, ".parquet"))
  if (!file.exists(f_obs) || !file.exists(f)) return(NULL)
  o <- as.data.table(read_parquet(f_obs))
  if (nrow(o) == 0) return(NULL)
  # The surface level's height is usually left blank (only its pressure is reported); by definition
  # it is the station elevation.
  o[lvl2 == 1 & gph < -8000, gph := as.integer(round(s$elev))]
  # Valid pressure and geopotential height (IGRA: -8888 removed by QA, -9999 missing)
  o <- o[press > 0 & gph > -8000]
  o[, nominal := as.POSIXct(sprintf("%d-%02d-%02d %02d:00", year, month, day, hour), tz = "UTC")]
  o <- o[hour <= 23]
  # Launch time: release time when given, wrapped to within 12 h of the nominal hour.
  o[, rel := parse_hhmm(reltime)]
  o[, off := ifelse(is.na(rel), 0, ((rel - hour + 12) %% 24) - 12)]
  o[, launch := nominal + off * 3600]
  o[, sounding := paste(format(nominal, "%Y%m%d%H"))]
  # Surface level of each sounding
  sfc <- o[lvl2 == 1, .(gph_sfc = gph[1], p_sfc = press[1]), by = sounding]
  o <- merge(o, sfc, by = "sounding", all.x = TRUE)
  o[is.na(gph_sfc), gph_sfc := s$elev]
  o[, agl := gph - gph_sfc]
  o <- o[agl >= -10 & agl <= max_agl_sonde]
  # Elapsed time since launch (MMMSS); when missing, assume a 5 m/s ascent.
  o[, et := ifelse(etime >= 0, (etime %/% 100) * 60 + etime %% 100, NA_real_)]
  o[is.na(et), et := pmax(agl, 0) / 5]
  o[, date := era5_hour(launch + et)]

  e <- add_era5_covariates(as.data.table(read_parquet(f)))
  d <- merge(o, e, by = "date")
  d[, err_sl := era5_altitude(press, sp_sl, t2m_sl, s$z_sl) - gph]
  d[, err_land := era5_altitude(press, sp_land, t2m_land, s$z_land) - gph]
  # Error relative to the sounding's own surface level: cancels the station elevation (and any
  # error in it), leaving only how the error grows with height above the ground.
  d[, surface := lvl2 == 1]
  d[, err_sl_rel := err_sl - err_sl[surface][1], by = sounding]
  d[, err_land_rel := err_land - err_land[surface][1], by = sounding]

  # Mean temperature of the layer from the surface to this level, observed by the sonde
  # (log-pressure weighted) vs assumed by the formula (t2m + L * dz / 2 for a linear profile).
  # Their difference drives the height-dependent error: err ~ agl * (T_assumed - T_obs) / T_obs.
  d <- d[order(sounding, -press)]
  d[, temp_k := ifelse(temp > -8000, temp / 10 + 273.15, NA_real_)]
  d[, tmean_obs := {
    lp <- log(press)
    tk <- zoo::na.approx(temp_k, lp, na.rm = FALSE, rule = 2)
    w <- c(0, -diff(lp))
    seg <- c(tk[1], (head(tk, -1) + tail(tk, -1)) / 2)
    cw <- cumsum(w)
    ifelse(cw > 0, cumsum(w * seg) / pmax(cw, 1e-12), tk[1])
  }, by = sounding]
  d[, tmean_assumed := t2m_sl - 0.0065 * pmax(agl, 0) / 2]

  d[, `:=`(
    id = s$id,
    year = as.integer(format(date, "%Y")),
    lsh = local_solar_hour(date, s$lon),
    sdoy = seasonal_doy(date, s$lat)
  )]
  # sp_sl, t2m_sl and d2m are kept so that 16_formula.R can evaluate formula variants.
  d[, .(id, sounding, date, year, lsh, sdoy, surface, press, gph, agl, err_sl, err_land, err_sl_rel,
    err_land_rel, tmean_obs, tmean_assumed, blh, skt_t2m, dsp6, t2m_sl, sp_sl, d2m)]
}

nB <- nrow(st[network == "igra"])
resB <- par_map(seq_len(nB), errB_station, cores = n_cores, geopressurer = TRUE,
  export = c("st", "era5_dir", "add_era5_covariates", "parse_hhmm"))
B <- rbindlist(Filter(is.data.frame, resB))
write_parquet(B, file.path(dir_interim, "errors_igra.parquet"))
cat("IGRA2:", uniqueN(B$id), "stations,", uniqueN(B[, paste(id, sounding)]), "soundings,",
  nrow(B), "levels\n")
