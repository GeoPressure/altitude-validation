# Run from the project root. Reads saved data; writes only T06 diagnostics.

# Load packages -----------------------------------------------------------
library(dplyr)
source("R/utils.R")
out <- "docs/methods/T06"
set.seed(606)
gpt3 <- gpt3_read(1)

# Cell multiplicity and the elevation exception ----------------------------
st <- load_stations()
ground_meta <- fread("output/tables/ground_station_stats.csv")
flight_meta <- st[network == "igra" & id %in% fread("output/tables/flight_stations_used.csv")$id]
cells <- rbindlist(list(ground_meta[, .(reference = "HadISD before QC", id, lat, lon, elev)], ground_meta[reference == TRUE, .(reference = "HadISD retained", id, lat, lon, elev)], flight_meta[, .(reference = "IGRA retained", id, lat, lon, elev)]))
cells[, cell := paste(floor(lat / 2), floor(lon / 2))]
cell_counts <- cells[, .(stations = .N, high_stations = sum(elev > 1000)), by = .(reference, cell)]
fwrite(cell_counts, file.path(out, "cell_counts.csv"))
fwrite(cell_counts[, .(stations = sum(stations), cells = .N, multi_station_cells = sum(stations > 1), stations_in_multi_cells = sum(stations[stations > 1]), max_stations = max(stations)), by = reference], file.path(out, "cell_summary.csv"))

# Compare ground filters on common inputs for all three conversions --------
x <- open_dataset("data/interim/errors_hadisd.parquet") |>
  filter(year >= 2022, year <= 2024, is.finite(err_sl), is.finite(sp_sl), is.finite(t2m_sl), is.finite(d2m)) |>
  select(id, date, pressure, err_sl, gross, sp_sl, t2m_sl, d2m) |>
  collect() |>
  as.data.table()
x <- merge(x, ground_meta[, .(id, lat, lon, elev, z_sl)], by = "id")
L <- gpt3_lapse(gpt3, x$lon, x$lat, as.POSIXlt(x$date, tz = "UTC")$yday + 1)
L[abs(L) < 1e-5] <- -1e-5
x[, e_isa := altitude_lapse(pressure * 100, 101325, 288.15, 0)]
x[, e_isa := e_isa - elev]
x[, e_standard := err_sl]
x[, e_virtual := err_sl + altitude_lapse(pressure * 100, sp_sl, virtual_temperature(t2m_sl, d2m, sp_sl), z_sl, L) - altitude_lapse(pressure * 100, sp_sl, t2m_sl, z_sl)]
rm(L)
station_stats <- list()
for (f in c("isa", "standard", "virtual")) {
  for (qc in c("gross_removed", "gross_kept")) {
    d <- if (qc == "gross_removed") x[!gross %in% TRUE] else x
    station_stats[[paste(f, qc)]] <- d[, .(formula = f, observation_qc = qc, n = .N, bias = mean(get(paste0("e_", f))), sd = sd(get(paste0("e_", f))), mae = mean(abs(get(paste0("e_", f)))), rmse = sqrt(mean(get(paste0("e_", f))^2))), by = id]
  }
}
ss <- merge(rbindlist(station_stats), ground_meta[, .(id, reference, consistent, step_flag, noisy, cw, lat, lon, elev, sdor, dz_sl, screen_bias = bias_sl)], by = "id")
ss[, cell := paste(floor(lat / 2), floor(lon / 2))]
fwrite(ss, file.path(out, "ground_station_diagnostics.csv"))
rules <- c("no_station_screen", "step_and_noise_only", "offset_only", "current_screen", "strict_screen", "loose_screen", "current_keep_gross")
summaries <- list()
members <- list()
for (rule in rules) {
  s <- ss[observation_qc == ifelse(rule == "current_keep_gross", "gross_kept", "gross_removed")]
  s <- switch(rule,
    no_station_screen = s,
    step_and_noise_only = s[!step_flag & !noisy],
    offset_only = s[consistent == TRUE],
    current_screen = s[reference == TRUE],
    strict_screen = s[!step_flag & !noisy & abs(screen_bias) <= 15 + 0.05 * abs(dz_sl)],
    loose_screen = s[!step_flag & !noisy & abs(screen_bias) <= 60 + 0.2 * abs(dz_sl)],
    current_keep_gross = s[reference == TRUE])
  members[[rule]] <- unique(s$id)
  for (weight in c("existing_cell", "retained_cell", "equal_station")) {
    s[, w := switch(weight, existing_cell = cw, retained_cell = 1 / .N, equal_station = 1), by = .(formula, cell)]
    summaries[[paste(rule, weight)]] <- s[, .(rule = rule, weighting = weight, stations = .N, cells = uniqueN(cell), rows = sum(n), mae = wmean(mae, w), rmse = sqrt(wmean(rmse^2, w)), median_station_mae = wquant(mae, w, 0.5), median_abs_bias = wquant(abs(bias), w, 0.5), median_station_sd = wquant(sd, w, 0.5)), by = formula]
  }
}
fwrite(rbindlist(summaries), file.path(out, "ground_filter_weighting.csv"))
# Exact individual-error percentiles for the three central screening alternatives.
x <- x[!gross %in% TRUE]
tails <- list()
for (f in c("isa", "standard", "virtual")) {
  ord <- order(abs(x[[paste0("e_", f)]]))
  for (rule in c("no_station_screen", "step_and_noise_only", "current_screen")) {
    s <- ss[formula == f & observation_qc == "gross_removed" & id %in% members[[rule]]]
    w <- (s$cw / s$n)[match(x$id, s$id)]
    w[is.na(w)] <- 0
    cum <- cumsum(w[ord]) / sum(w)
    tails[[paste(f, rule)]] <- data.table(formula = f, rule = rule, p50_abs = abs(x[[paste0("e_", f)]][ord[which(cum >= 0.5)[1]]]), p95_abs = abs(x[[paste0("e_", f)]][ord[which(cum >= 0.95)[1]]]))
  }
}
fwrite(rbindlist(tails), file.path(out, "ground_filter_tails.csv"))
rm(x, d, w, cum, ord)
gc()

# Is the high-elevation exception necessary for the aggregate? -------------
base <- ss[observation_qc == "gross_removed" & reference == TRUE]
choices <- unique(base[, .(id, cell, elev)])
draws <- list()
for (i in 1:200) {
  ids <- choices[, .(id = sample(id, 1)), by = cell]$id
  draws[[i]] <- base[id %in% ids, .(draw = i, stations = .N, high_stations = sum(elev > 1000), mae = mean(mae), median_abs_bias = wquant(abs(bias), rep(1, .N), 0.5), median_sd = wquant(sd, rep(1, .N), 0.5)), by = formula]
}
fwrite(rbindlist(draws), file.path(out, "one_station_per_cell_draws.csv"))
fwrite(base[, .(stations = .N, mae = mean(mae), median_sd = median(sd)), by = .(formula, elevation = fifelse(elev > 1000, ">1000 m", "<=1000 m"))], file.path(out, "ground_elevation_strata.csv"))

# GNSS duplicated-hour sensitivity ----------------------------------------
gs <- fread("output/tables/indep_station_stats.csv")[source == "GNSS" & height_ok]
g <- rbindlist(lapply(gs$id, function(id) as.data.table(read_parquet(file.path("data/interim/indep", paste0("GNSS_", id, ".parquet"))))))
g[, gross := abs(err_sl - median(err_sl, na.rm = TRUE)) > max(100, 10 * mad(err_sl, na.rm = TRUE)), by = id]
g <- g[!gross %in% TRUE & is.finite(err_sl) & is.finite(d2m)]
g <- merge(g, gs[, .(id, z_sl)], by = "id")
# Merge duplicate-hour atmospheric/height inputs first, then evaluate each conversion.
dedup <- g[, .(pressure = mean(pressure), elev = mean(elev), sp_sl = mean(sp_sl), t2m_sl = mean(t2m_sl), d2m = mean(d2m), z_sl = z_sl[1], lat = lat[1], lon = lon[1]), by = .(id, date)]
gnss <- list()
for (variant in c("current", "unique_hour_mean")) {
  d <- if (variant == "current") copy(g) else copy(dedup)
  L <- gpt3_lapse(gpt3, d$lon, d$lat, as.POSIXlt(d$date, tz = "UTC")$yday + 1)
  L[abs(L) < 1e-5] <- -1e-5
  d[, e_isa := altitude_lapse(pressure * 100, 101325, 288.15, 0) - elev]
  d[, e_standard := altitude_lapse(pressure * 100, sp_sl, t2m_sl, z_sl) - elev]
  d[, e_virtual := altitude_lapse(pressure * 100, sp_sl, virtual_temperature(t2m_sl, d2m, sp_sl), z_sl, L) - elev]
  d[, w := 1 / .N, by = id]
  for (f in c("isa", "standard", "virtual")) {
    gnss[[paste(variant, f)]] <- d[, .(variant = variant, formula = f, stations = uniqueN(id), rows = .N, bias = wmean(get(paste0("e_", f)), w), mae = wmean(abs(get(paste0("e_", f))), w), p95_abs = wquant(abs(get(paste0("e_", f))), w, 0.95))]
  }
}
fwrite(rbindlist(gnss), file.path(out, "gnss_duplicate_sensitivity.csv"))
rm(g, dedup, d, L)
gc()

# Airborne weighting: levels, station-bins, and sounding-bins ----------------
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
fw <- list()
for (variant in c("current", "equal_station_bin", "equal_cell_station_bin", "equal_cell_sounding_bin")) {
  weight <- c(current = "w", equal_station_bin = "w_equal_station_bin", equal_cell_station_bin = "w_station_bin", equal_cell_sounding_bin = "w_sounding_bin")[[variant]]
  for (f in c("isa", "standard", "virtual")) {
    fw[[paste(variant, f)]] <- b[, .(variant = variant, formula = f, stations = uniqueN(id), cells = uniqueN(cell), levels = .N, bias = wmean(get(paste0("e_", f)), get(weight)), mae = wmean(abs(get(paste0("e_", f))), get(weight)), rmse = sqrt(wmean(get(paste0("e_", f))^2, get(weight))), p95_abs = wquant(abs(get(paste0("e_", f))), get(weight), 0.95)), by = hbin]
  }
}
fw <- rbindlist(fw)
fw[, hbin := as.character(hbin)]
fwrite(fw, file.path(out, "flight_weighting.csv"))
fw <- merge(fw, bird_height_weights()[, .(hbin, prop)], by = "hbin")
fwrite(fw[, .(bias = sum(bias * prop), mae = sum(mae * prop), rmse = sqrt(sum(rmse^2 * prop))), by = .(variant, formula)], file.path(out, "flight_weighting_bird.csv"))
fwrite(b[, .(levels = .N, soundings = uniqueN(sounding), era5_hours = uniqueN(date)), by = .(id, hbin)], file.path(out, "flight_sampling_bin.csv"))

# Verify reproduction of the current tables before interpreting contrasts ---
check_ground <- merge(fread(file.path(out, "ground_filter_weighting.csv"))[rule == "current_screen" & weighting == "existing_cell"], fread("docs/methods/T06/baseline/paper_ground.csv")[reference == "HadISD" & terrain == "all"], by = "formula")
check_flight <- merge(fread(file.path(out, "flight_weighting_bird.csv"))[variant == "current"], fread("docs/methods/T06/baseline/paper_flight_bird.csv"), by = "formula")
check_gnss <- merge(fread(file.path(out, "gnss_duplicate_sensitivity.csv"))[variant == "current"], fread("docs/methods/T06/baseline/paper_ground.csv")[reference == "GNSS" & terrain == "all"], by = "formula")
checks <- data.table(comparison = c("HadISD current MAE", "GNSS current MAE", "flight current bird MAE"), max_abs_difference_m = c(max(abs(check_ground$mae.x - check_ground$mae.y)), max(abs(check_gnss$mae.x - check_gnss$mae.y)), max(abs(check_flight$mae.x - check_flight$mae.y))))
fwrite(checks, file.path(out, "reproduction_checks.csv"))
print(checks)
stopifnot(max(checks$max_abs_difference_m) < 1e-7)
