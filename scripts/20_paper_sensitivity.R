# Sensitivity appendix generated from the same cached observations as step 18.
# Keep primary flight weighting and station selection unchanged.
source("R/utils.R")
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

# Height-band support and alternative flight weights -----------------------
fwrite(b[, .(stations = uniqueN(id), soundings = uniqueN(paste(id, sounding)), levels = .N), by = hbin], file.path(dir_tables, "paper_flight_support.csv"))
variants <- c("current", "equal_station_bin", "equal_sounding_bin", "minimum30", "minimum100")
results <- list()
overall_medians <- list()
for (variant in variants) {
  d <- copy(b)
  if (variant == "minimum30") d <- d[n_soundings >= 30]
  if (variant == "minimum100") d <- d[n_soundings >= 100]
  d[, w_alt := w]
  if (variant != "current") d[, w_alt := 1 / .N, by = .(id, hbin)]
  if (variant == "equal_sounding_bin") d[, w_alt := w_sounding_bin]
  d[, w_target := w_alt / sum(w_alt), by = hbin]
  d[bird_height_weights(), on = "hbin", w_target := w_target * i.prop]
  for (f in c("isa", "standard", "virtual")) {
    overall_medians[[paste(variant, f)]] <- data.table(variant = variant, formula = f,
      medae = wquant(abs(d[[paste0("e_", f)]]), d$w_target, 0.5))
    results[[paste(variant, f)]] <- d[, .(variant = variant, formula = f, stations = uniqueN(id), bias = wmean(get(paste0("e_", f)), w_alt), mae = wmean(abs(get(paste0("e_", f))), w_alt), medae = wquant(abs(get(paste0("e_", f))), w_alt, 0.5), p95_abs = wquant(abs(get(paste0("e_", f))), w_alt, 0.95)), by = hbin]
  }
}
results <- rbindlist(results)
results[, hbin := as.character(hbin)]
fwrite(results, file.path(dir_tables, "paper_flight_weighting_height.csv"))
results <- merge(results, bird_height_weights()[, .(hbin, prop)], by = "hbin")
results <- results[, .(bias = sum(bias * prop), mae = sum(mae * prop)), by = .(variant, formula)]
results <- merge(results, rbindlist(overall_medians), by = c("variant", "formula"))
fwrite(results, file.path(dir_tables, "paper_flight_weighting_sensitivity.csv"))
check <- merge(results[variant == "current"], fread(file.path(dir_tables, "paper_flight_bird.csv")), by = "formula")
stopifnot(max(abs(check$mae.x - check$mae.y)) < 1e-7, max(abs(check$bias.x - check$bias.y)) < 1e-7, max(abs(check$medae.x - check$medae.y)) < 1e-7)
# Reweight the full absolute-error distribution for each biological target.
b[, w_target := w / sum(w), by = hbin]
target_medians <- list()
for (target in unique(fread(file.path(dir_tables, "bird_target_height_weights.csv"))$variant)) {
  weights <- fread(file.path(dir_tables, "bird_target_height_weights.csv"))[variant == target]
  b[, prop_target := 0]
  b[weights, on = "hbin", prop_target := i.prop]
  for (f in c("isa", "standard", "virtual")) target_medians[[paste(target, f)]] <-
    data.table(variant = target, formula = f,
      medae = wquant(abs(b[[paste0("e_", f)]]), b$w_target * b$prop_target, 0.5))
}
rm(b, d)
gc()

# Duplicate-hour contrast, holding the primary GNSS station selection fixed -
gs <- fread(file.path(dir_tables, "indep_station_stats.csv"))[source == "GNSS" & height_ok]
gs <- gs[paste("GNSS", id) %in% fread(file.path(dir_tables, "paper_ground_station.csv"))[reference == "GNSS", id]]
g <- rbindlist(lapply(gs$id, function(id) as.data.table(read_parquet(file.path(dir_interim, "indep", paste0("GNSS_", id, ".parquet"))))))
g <- merge(g, gs[, .(id, z_sl)], by = "id")
gnss <- list()
for (variant in c("repeated_hours", "unique_hours")) {
  d <- if (variant == "repeated_hours") copy(g) else average_reference_hours(g)
  d[, err_sl := altitude_lapse(pressure * 100, sp_sl, t2m_sl, z_sl) - elev]
  d[, gross := abs(err_sl - median(err_sl, na.rm = TRUE)) > max(100, 10 * mad(err_sl, na.rm = TRUE)), by = id]
  d <- d[!gross %in% TRUE & is.finite(err_sl) & is.finite(d2m)]
  L <- gpt3_lapse(gpt3, d$lon, d$lat, as.POSIXlt(d$date, tz = "UTC")$yday + 1)
  L[abs(L) < 1e-5] <- -1e-5
  d[, e_isa := altitude_lapse(pressure * 100, 101325, 288.15, 0) - elev]
  d[, e_standard := err_sl]
  d[, e_virtual := altitude_lapse(pressure * 100, sp_sl, virtual_temperature(t2m_sl, d2m, sp_sl), z_sl, L) - elev]
  d[, w := 1 / .N, by = id]
  for (f in c("isa", "standard", "virtual")) gnss[[paste(variant, f)]] <- d[, .(variant = variant, formula = f, rows = .N, mae = wmean(abs(get(paste0("e_", f))), w), medae = wquant(abs(get(paste0("e_", f))), w, 0.5), p95_abs = wquant(abs(get(paste0("e_", f))), w, 0.95))]
}
fwrite(rbindlist(gnss), file.path(dir_tables, "paper_gnss_hour_sensitivity.csv"))
# Biological target contrasts use committed aggregate weights from the published bird release.
# Regenerating the raw-data target audit remains optional; ordinary builds need no bird tracks.
targets <- merge(fread(file.path(dir_tables, "bird_target_height_weights.csv")), fread(file.path(dir_tables, "paper_flight_height.csv")), by = "hbin", allow.cartesian = TRUE)
targets <- targets[, .(bias = sum(bias * prop), mae = sum(mae * prop), rmse = sqrt(sum(rmse^2 * prop))), by = .(variant, formula)]
targets <- merge(targets, rbindlist(target_medians), by = c("variant", "formula"))
fwrite(merge(fread(file.path(dir_tables, "bird_target_support.csv")), targets, by = "variant"), file.path(dir_tables, "paper_bird_target_sensitivity.csv"))

print(results)

# Descriptive reference comparisons use the current primary station summaries.
gs <- fread(file.path(dir_tables, "paper_ground_station.csv"))[formula == "standard"]
fwrite(gs[, .(n_stations = .N, abs_bias_median = median(abs(bias)), sd_median = median(sd)), by = .(set = reference, terrain)], file.path(dir_tables, "paper_reference_terrain.csv"))

# Recency sensitivity: hold the selected stations fixed and compare each selected year with its
# latest qualifying completed calendar year. This tests the date choice, not a different network.
s <- fread(file.path(dir_tables, "ground_station_stats.csv"))[reference == TRUE]
primary_years <- s[, .(id, year = selected_year)]
cov <- fread(file.path(dir_interim, "ghcnh_coverage.csv"))
complete <- cov[year %in% years_ghcnh & year < as.integer(format(Sys.Date(), "%Y")) & days >= 183 & n / pmax(days, 1) >= 4,
  .(complete_year = max(year)), by = id]
s <- merge(s[, .(id, selected_year, lat, lon)], complete, by = "id")
a <- as.data.table(read_parquet(file.path(dir_interim, "errors_ghcnh.parquet"),
  col_select = c("id", "year", "date", "err_sl", "gross", "quality_code", "source_code")))
a <- a[!gross %in% TRUE & is.finite(err_sl)]
y <- a[, .(n = .N, days = uniqueN(as.Date(date)), months = uniqueN(format(date, "%m")),
  bias = mean(err_sl), sd = sd(err_sl), mae = mean(abs(err_sl))), by = .(id, year)]
pair <- merge(s, y, by = "id", allow.cartesian = TRUE)
pair <- pair[year == selected_year | year == complete_year]
# Both years must survive the same post-match coverage check.
pair <- pair[days >= 183 & n / days >= 4]
ids <- pair[, .(both = all(c(selected_year[1], complete_year[1]) %in% year)), by = id][both == TRUE, id]
pair <- pair[id %in% ids]
comparison <- rbind(pair[year == selected_year][, choice := "latest_qualifying"],
  pair[year == complete_year][, choice := "latest_completed"])
comparison[, cw := 1 / .N, by = .(choice, floor(lat / 2), floor(lon / 2))]
fwrite(comparison, file.path(dir_tables, "paper_ground_date_station.csv"))
date_summary <- comparison[, .(stations = .N, median_days = median(days), median_months = median(months),
  mae = wmean(mae, cw), median_abs_bias = wquant(abs(bias), cw, .5),
  median_sd = wquant(sd, cw, .5)), by = choice]
date_errors <- merge(a, comparison[, .(id, year, choice, weight = cw / n)], by = c("id", "year"), allow.cartesian = TRUE)
date_medians <- date_errors[, .(medae = wquant(abs(err_sl), weight, .5)), by = choice]
fwrite(merge(date_summary, date_medians, by = "choice"), file.path(dir_tables, "paper_ground_date_sensitivity.csv"))
fwrite(primary_years[, .N, by = .(selected_year = year)][order(selected_year)],
  file.path(dir_tables, "paper_ground_selected_years.csv"))

# Retained legacy QC provenance: missing and gross-limit flags are not a full-QC guarantee.
qc <- a[primary_years, on = .(id, year), nomatch = 0L]
qc[, qc_class := fcase(is.na(quality_code) | quality_code == "", "missing source QC",
  quality_code == "1" | (quality_code == "5" & source_code %in% c("313", "314", "315", "322", "335", "343", "344", "346")),
  "source checked-good", default = "other accepted source flag")]
fwrite(qc[, .(stations = uniqueN(id), accepted_hours = .N), by = .(qc_class, quality_code, source_code)],
  file.path(dir_tables, "paper_ground_qc_provenance.csv"))

jsonlite::write_json(list(generated_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), source_md5 = as.list(tools::md5sum(c("R/utils.R", "scripts/20_paper_sensitivity.R")))), file.path(dir_tables, "paper_sensitivity_provenance.json"), pretty = TRUE, auto_unbox = TRUE)
