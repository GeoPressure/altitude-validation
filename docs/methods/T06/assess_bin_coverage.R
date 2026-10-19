# Minimum coverage per station and height bin, using the saved observations.
# Run from the project root after compare_designs.R.
source("R/utils.R")
out <- "docs/methods/T06"
gpt3 <- gpt3_read(1)
st <- load_stations()
b <- load_radiosondes(st)
b <- b[is.finite(err_sl_rel) & is.finite(sp_sl) & is.finite(t2m_sl) & is.finite(d2m), .(id, sounding, date, surface, press, gph, hbin, w, t2m_sl, sp_sl, d2m, z_sl, err_sl_rel)]
b[st[network == "igra"], on = "id", `:=`(lon = i.lon, lat = i.lat)]
b[, tv := virtual_temperature(t2m_sl, d2m, sp_sl)]
sfc <- b[surface == TRUE, .(ps = press[1], hs = gph[1], sp_s = sp_sl[1], t_s = t2m_sl[1], tv_s = tv[1]), by = .(id, sounding)]
b <- merge(b[surface == FALSE & hbin != levels(hbin)[1]], sfc, by = c("id", "sounding"))
# Preserve the study's sounding-day GPT3 convention for all compared designs.
L <- gpt3_lapse(gpt3, b$lon, b$lat, as.POSIXlt(as.POSIXct(substr(b$sounding, 1, 8), format = "%Y%m%d", tz = "UTC"))$yday + 1)
L[abs(L) < 1e-5] <- -1e-5
b[, e_isa := (altitude_lapse(press, 101325, 288.15, 0) - altitude_lapse(ps, 101325, 288.15, 0)) - (gph - hs)]
b[, e_standard := err_sl_rel]
b[, e_virtual := (altitude_lapse(press, sp_sl, tv, z_sl, L) - gph) - (altitude_lapse(ps, sp_s, tv_s, z_sl, L) - hs)]
b[, cell := paste(floor(lat / 2), floor(lon / 2))]
b[, w_station_bin := 1 / .N, by = .(id, hbin)]
b[, w_sounding_bin := 1 / .N, by = .(id, sounding, hbin)]
ns <- unique(b[, .(id, sounding, hbin)])[, .(n_soundings = .N), by = .(id, hbin)]
b[ns, on = .(id, hbin), w_sounding_bin := w_sounding_bin / i.n_soundings]
nc <- unique(b[, .(id, cell, hbin)])[, .(n_stations = .N), by = .(cell, hbin)]
b[nc, on = .(cell, hbin), `:=`(w_station_bin = w_station_bin / i.n_stations, w_sounding_bin = w_sounding_bin / i.n_stations)]
b[, w_equal_station_bin := 1 / .N, by = .(id, hbin)]
# Coverage is defined by distinct soundings, not vertical level count.
coverage <- b[, .(soundings = uniqueN(sounding)), by = .(id, hbin)]
b[coverage, on = .(id, hbin), n_soundings := i.soundings]
station <- rbindlist(lapply(c("isa", "standard", "virtual"), function(f) {
  b[, .(formula = f, soundings = n_soundings[1], levels = .N, bias = mean(get(paste0("e_", f))), mae = mean(abs(get(paste0("e_", f))))), by = .(id, hbin)]
}))
fwrite(station, file.path(out, "flight_station_bin_metrics.csv"))
results <- list()
for (threshold in c(1, 30, 100)) {
  d <- b[n_soundings >= threshold]
  d[, w_threshold := 1 / .N, by = .(id, hbin)]
  for (f in c("isa", "standard", "virtual")) {
    results[[paste(threshold, f)]] <- d[, .(min_soundings = threshold, formula = f, stations = uniqueN(id), soundings = uniqueN(paste(id, sounding)), levels = .N, bias = wmean(get(paste0("e_", f)), w_threshold), mae = wmean(abs(get(paste0("e_", f))), w_threshold), p95_abs = wquant(abs(get(paste0("e_", f))), w_threshold, 0.95)), by = hbin]
  }
}
results <- rbindlist(results)
results[, hbin := as.character(hbin)]
fwrite(results, file.path(out, "flight_bin_minimum_sensitivity.csv"))
results <- merge(results, bird_height_weights()[, .(hbin, prop)], by = "hbin")
fwrite(results[, .(bias = sum(bias * prop), mae = sum(mae * prop)), by = .(min_soundings, formula)], file.path(out, "flight_bin_minimum_bird.csv"))
cat("Bird-weighted results by minimum distinct soundings per station-bin\n")
print(fread(file.path(out, "flight_bin_minimum_bird.csv")))

# The threshold-one case must reproduce the earlier equal-station-band comparison.
check <- merge(fread(file.path(out, "flight_bin_minimum_sensitivity.csv"))[min_soundings == 1], fread(file.path(out, "flight_weighting.csv"))[variant == "equal_station_bin"], by = c("formula", "hbin"))
check <- data.table(metric = c("bias", "mae", "p95_abs"), max_abs_difference_m = c(max(abs(check$bias.x - check$bias.y)), max(abs(check$mae.x - check$mae.y)), max(abs(check$p95_abs.x - check$p95_abs.y))))
fwrite(check, file.path(out, "coverage_reproduction_checks.csv"))
stopifnot(max(check$max_abs_difference_m) < 1e-7)
