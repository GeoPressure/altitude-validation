# Main three-conversion analysis, using cached pressure and atmospheric inputs.
# Ground discrepancies retain reference-height uncertainty; flight errors are relative
# to each sounding's own surface. T06 sensitivities are separate from primary selections.
source("R/utils.R")
load_geopressurer()
set.seed(18)
formulas <- c(isa = "Standard atmosphere", standard = "ERA5, standard lapse rate", virtual = "ERA5, virtual temperature + GPT3")
alt_isa <- function(p) altitude_lapse(p, 101325, 288.15, 0, -0.0065)
gpt3 <- gpt3_read(1)
lapse_gpt3 <- function(lon, lat, date) {
  L <- gpt3_lapse(gpt3, lon, lat, as.POSIXlt(date, tz = "UTC")$yday + 1)
  fifelse(abs(L) < 1e-5, -1e-5, L)
}

# Ground inputs and unique reference hours ---------------------------------
stA <- fread(file.path(dir_tables, "ground_station_stats.csv"))
A <- as.data.table(read_parquet(file.path(dir_interim, "errors_ghcnh.parquet"), col_select = c("id", "date", "year", "pressure", "err_sl", "gross", "t2m_sl", "sp_sl", "d2m")))
A <- A[stA[, .(id, year = selected_year)], on = .(id, year)]
A <- A[!gross %in% TRUE & is.finite(err_sl) & is.finite(d2m)]
A <- merge(A, stA[, .(id, lat, lon, elev, z_sl, terrain, selected = reference, stable = !step_flag & !noisy)], by = "id")
A[, reference := "GHCNh"]
stI <- fread(file.path(dir_tables, "indep_station_stats.csv"))[source == "MeteoSwiss" | height_ok]
I <- rbindlist(lapply(file.path(dir_interim, "indep", paste0(stI$source, "_", stI$id, ".parquet")), function(f) as.data.table(read_parquet(f))))
I <- average_reference_hours(I)
I <- merge(I, stI[, .(source, id, z_sl, terrain = terrain_class(sdor))], by = c("source", "id"))
I[, err_sl := altitude_lapse(pressure * 100, sp_sl, t2m_sl, z_sl) - elev]
I[, gross := abs(err_sl - median(err_sl, na.rm = TRUE)) > max(100, 10 * mad(err_sl, na.rm = TRUE)), by = .(source, id)]
I <- I[!gross %in% TRUE & is.finite(err_sl) & is.finite(d2m)]
I <- I[id %in% I[, .N, by = .(source, id)][N >= 2160, id]]
I[, `:=`(reference = source, selected = TRUE, stable = TRUE, id = paste(source, id))]
cols <- c("reference", "id", "date", "lat", "lon", "elev", "pressure", "err_sl", "sp_sl", "t2m_sl", "d2m", "z_sl", "terrain", "selected", "stable")
G <- rbind(A[, ..cols], I[, ..cols])
rm(A, I)
G[, p := pressure * 100]
G[, err_isa := alt_isa(p) - elev]
G[, err_standard := err_sl]
G[, err_virtual := err_sl + altitude_lapse(p, sp_sl, virtual_temperature(t2m_sl, d2m, sp_sl), z_sl, lapse_gpt3(lon, lat, date)) - altitude_lapse(p, sp_sl, t2m_sl, z_sl)]
k <- G[, sample(.N, 1e5)]
stopifnot(max(abs(G$err_virtual[k] - (G[k, pressure_to_altitude(p, sp_sl, t2m_sl, z_sl, dewpoint = d2m, lon = lon, lat = lat, date = date, altitude_formula = "virtual")] - G$elev[k]))) < 0.01)

gs_all <- rbindlist(lapply(names(formulas), function(f) {
  v <- paste0("err_", f)
  G[, .(formula = f, n = .N, bias = mean(get(v)), sd = sd(get(v)), mae = mean(abs(get(v))), rmse = sqrt(mean(get(v)^2)), terrain = terrain[1], elev = median(elev), lat = lat[1], lon = lon[1], selected = selected[1], stable = stable[1]), by = .(reference, id)]
}))
ground_summary <- function(s) {
  s[, .(n_stations = .N, abs_bias_median = wquant(abs(bias), cw, 0.5), abs_bias_p90 = wquant(abs(bias), cw, 0.9), sd_median = wquant(sd, cw, 0.5), sd_p90 = wquant(sd, cw, 0.9), mae = wmean(mae, cw), rmse = sqrt(wmean(rmse^2, cw)))]
}

# Selection sensitivity with weights assigned after each final selection -----
sensitivity <- list()
for (rule in c("all_eligible", "step_noise_only", "screened")) {
  s <- gs_all[reference == "GHCNh"]
  s <- switch(rule, all_eligible = s, step_noise_only = s[stable == TRUE], screened = s[selected == TRUE])
  s[, cw := 1 / .N, by = .(formula, floor(lat / 2), floor(lon / 2))]
  m <- s[, ground_summary(.SD), by = formula]
  for (f in names(formulas)) {
    d <- G[reference == "GHCNh" & id %in% s$id]
    sf <- s[formula == f]
    w <- (sf$cw / sf$n)[match(d$id, sf$id)]
    m[formula == f, `:=`(medae = wquant(abs(d[[paste0("err_", f)]]), w, 0.5),
      p95_abs = wquant(abs(d[[paste0("err_", f)]]), w, 0.95))]
  }
  m[, selection := rule]
  sensitivity[[rule]] <- m
}
fwrite(rbindlist(sensitivity), file.path(dir_tables, "paper_ground_screen_sensitivity.csv"))
rm(d, w)

# Primary ground comparisons -----------------------------------------------
gs <- gs_all[selected == TRUE]
gs[, cw := 1 / .N, by = .(reference, formula, floor(lat / 2), floor(lon / 2))]
gs[reference != "GHCNh", cw := 1]
fwrite(gs, file.path(dir_tables, "paper_ground_station.csv"))
ground <- rbind(gs[, ground_summary(.SD), by = .(formula, reference)][, terrain := "all"], gs[reference == "GHCNh", ground_summary(.SD), by = .(formula, reference, terrain)])
fwrite(ground, file.path(dir_tables, "paper_ground.csv"))
G <- G[selected == TRUE]
G[gs[formula == "standard", .(reference, id, cw)], on = .(reference, id), cw := i.cw]
G[, w := cw / .N, by = .(reference, id)]
ground_tails <- rbindlist(lapply(names(formulas), function(f) {
  G[, .(formula = f, medae = wquant(abs(get(paste0("err_", f))), w, 0.5), p95_abs = wquant(abs(get(paste0("err_", f))), w, 0.95), over50 = wmean(abs(get(paste0("err_", f))) > 50, w), over100 = wmean(abs(get(paste0("err_", f))) > 100, w), over200 = wmean(abs(get(paste0("err_", f))) > 200, w)), by = reference]
}))
fwrite(ground_tails, file.path(dir_tables, "paper_ground_tails.csv"))
coverage <- G[, .(rows = .N, hours = uniqueN(date)), by = .(reference, id, year = as.POSIXlt(date, tz = "UTC")$year + 1900)]
calendar_ghcnh <- unique(G[reference == "GHCNh", .(reference, id,
  year = as.integer(format(date, "%Y")))])
calendar_independent <- unique(G[reference != "GHCNh", .(reference, id)])[
  , .(year = years_main), by = .(reference, id)]
calendar <- rbind(calendar_ghcnh, calendar_independent)
coverage <- merge(calendar, coverage, by = c("reference", "id", "year"), all.x = TRUE)
coverage[is.na(rows), `:=`(rows = 0L, hours = 0L)]
coverage[, hour_fraction := hours / ifelse(year %% 4 == 0 & (year %% 100 != 0 | year %% 400 == 0), 8784, 8760)]
fwrite(coverage, file.path(dir_tables, "paper_ground_station_year.csv"))
fwrite(coverage[, .(stations = uniqueN(id), rows = sum(rows), unique_hours = sum(hours), median_hour_pct = 100 * median(hour_fraction)), by = reference], file.path(dir_tables, "paper_ground_coverage.csv"))
print(ground[terrain == "all"])
rm(G, gs_all)
gc()

# Height-only comparison at matched Swiss stations -------------------------
ms <- fread(file.path(dir_tables, "meteoswiss_vs_ghcnh.csv"))[is.finite(bias_ghcnh) & is.finite(bias_meteoswiss)]
ms[, bias_height_only := bias_ghcnh + d_barometer]
fwrite(ms, file.path(dir_tables, "paper_swiss_height.csv"))
fwrite(ms[, .(n = .N, median_abs_ghcnh = median(abs(bias_ghcnh)), median_abs_height_only = median(abs(bias_height_only)), median_abs_meteoswiss = median(abs(bias_meteoswiss)))], file.path(dir_tables, "paper_swiss_height_summary.csv"))

# ---- Flight ------------------------------------------------------------------------------------
st <- load_stations()
B <- load_radiosondes(st)
B <- B[is.finite(err_sl_rel) & is.finite(sp_sl) & is.finite(t2m_sl) & is.finite(d2m),
  .(id, sounding, surface, press, gph, agl, hbin, w, climate, season, lsh, t2m_sl, sp_sl, d2m, z_sl,
    err_sl_rel)]
B[st[network == "igra"], on = "id", `:=`(lon = i.lon, lat = i.lat)]
B[, date := as.POSIXct(substr(sounding, 1, 8), format = "%Y%m%d", tz = "UTC")]
B[, tv2m := virtual_temperature(t2m_sl, d2m, sp_sl)]
sfc <- B[surface == TRUE, .(press_s = press[1], gph_s = gph[1], sp_s = sp_sl[1], t2m_s = t2m_sl[1],
  tv2m_s = tv2m[1]), by = .(id, sounding)]
B <- merge(B[surface == FALSE & hbin != levels(hbin)[1]], sfc, by = c("id", "sounding"))
B[, L := lapse_gpt3(lon, lat, date)]
B[, e_isa := (alt_isa(press) - alt_isa(press_s)) - (gph - gph_s)]
B[, e_standard := err_sl_rel]
B[, e_virtual := (altitude_lapse(press, sp_sl, tv2m, z_sl, L) - gph) -
  (altitude_lapse(press_s, sp_s, tv2m_s, z_sl, L) - gph_s)]
B[, daynight := fifelse(lsh >= 7 & lsh < 19, "day", "night")]
cat(uniqueN(B$id), "radiosonde stations,", nrow(B), "levels\n")

bb <- bird_height_weights()
B[, prop := bb$prop[match(as.character(hbin), bb$hbin)]]
B[is.na(prop), prop := 0]

long <- function(by) {
  rbindlist(lapply(names(formulas), function(f) {
    v <- paste0("e_", f)
    B[, .(formula = f, bias = wmean(get(v), w), sd = sqrt(wmean((get(v) - wmean(get(v), w))^2, w)),
      mae = wmean(abs(get(v)), w), medae = wquant(abs(get(v)), w, 0.5), rmse = sqrt(wmean(get(v)^2, w)), n_stations = uniqueN(id)),
      by = by]
  }))
}
fh <- long("hbin")[order(formula, hbin)]
fh[, agl_mid := hbin_mid[as.integer(hbin)]]
fwrite(fh, file.path(dir_tables, "paper_flight_height.csv"))

flight_tails <- rbindlist(lapply(names(formulas), function(f) {
  B[, .(formula = f, medae = wquant(abs(get(paste0("e_", f))), w, 0.5), p95_abs = wquant(abs(get(paste0("e_", f))), w, 0.95)), by = hbin]
}))
fwrite(flight_tails, file.path(dir_tables, "paper_flight_tails.csv"))

# Station mean error and temporal/profile scatter within each height band
fs <- rbindlist(lapply(names(formulas), function(f) {
  v <- paste0("e_", f)
  B[, .(formula = f, bias = mean(get(v)), sd = sd(get(v)), n = .N), by = .(id, hbin)]
}))
fs <- merge(fs, unique(st[network == "igra", .(id, lat, lon)]), by = "id")
fs[, cw := 1 / uniqueN(id), by = .(floor(lat / 2), floor(lon / 2))]
fs[, agl_mid := hbin_mid[as.integer(hbin)]]
fwrite(fs, file.path(dir_tables, "paper_flight_station.csv"))

# Finer observed-height summaries for Figure 4; primary reporting bands stay unchanged.
B[, profile_mid := (ceiling(agl / 250) - 0.5) * 250]
profile <- rbindlist(lapply(names(formulas), function(f) {
  v <- paste0("e_", f)
  B[agl > 0 & agl <= 6000, .(formula = f, bias = mean(get(v)), sd = sd(get(v)),
    n = .N, n_soundings = uniqueN(sounding)), by = .(id, agl_mid = profile_mid)]
}))
profile <- merge(profile, unique(fs[, .(id, cw)]), by = "id")
fwrite(profile, file.path(dir_tables, "paper_flight_profile_station.csv"))
station_summary <- rbindlist(lapply(c("bias", "sd"), function(m) {
  fs[is.finite(get(m)), .(metric = m, median = wquant(get(m), cw, 0.5),
    q25 = wquant(get(m), cw, 0.25), q75 = wquant(get(m), cw, 0.75)),
    by = .(formula, hbin, agl_mid)]
}))
fwrite(station_summary, file.path(dir_tables, "paper_flight_station_summary.csv"))

# Over the heights birds fly: per-bin statistics combined by the share of bird flight time
bird <- merge(fh, bb[, .(hbin, prop)], by = "hbin")[, .(bias = sum(bias * prop),
  mae = sum(mae * prop), rmse = sqrt(sum(rmse^2 * prop))), by = formula]
# Normalize the empirical error distribution within each band before applying flight-time weights.
B[, w_bird := w / sum(w) * prop, by = hbin]
for (f in names(formulas)) bird[formula == f,
  medae := wquant(abs(B[[paste0("e_", f)]]), B$w_bird, 0.5)]
fwrite(bird, file.path(dir_tables, "paper_flight_bird.csv"))
print(bird)

fc <- long(c("hbin", "climate", "season"))[!is.na(climate) & n_stations >= 3]
fc[, agl_mid := hbin_mid[as.integer(hbin)]]
fwrite(fc, file.path(dir_tables, "paper_flight_climate.csv"))
fd <- long(c("hbin", "daynight", "season"))
fd[, agl_mid := hbin_mid[as.integer(hbin)]]
fwrite(fd, file.path(dir_tables, "paper_flight_daynight.csv"))

# Record this generation stage separately from older exploratory version files.
jsonlite::write_json(list(generated_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), package = geopressurer_version(), ground_intake = jsonlite::fromJSON(file.path(dir_interim, "ghcnh", "screening_provenance.json")), era5_availability = jsonlite::fromJSON(file.path(dir_interim, "era5_availability.json")), source_md5 = as.list(tools::md5sum(c("R/utils.R", "scripts/03_ghcnh_screen.R", "scripts/08_era5_extract.R", "scripts/09_errors.R", "scripts/11_reference_checks.R", "scripts/12_analysis.R", "scripts/18_three_formulas.R", file.path(path.expand(GEOPRESSURER_PATH), c("R/pressure_to_altitude.R", "R/gpt3_lapse_rate.R"))))), session = capture.output(sessionInfo())), file.path(dir_tables, "paper_analysis_provenance.json"), pretty = TRUE, auto_unbox = TRUE)
