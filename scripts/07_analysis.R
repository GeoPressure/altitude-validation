# Summaries and driver models for Tier A and Tier B (figures: 10_figures.R).
#
# Vocabulary used throughout:
#   accuracy  = the per-station mean error (bias). Constant in time, so it only matters for
#               absolute altitude and for comparing altitudes across locations.
#   precision = the temporal SD of the error at a station once its bias is removed. This is what
#               limits relative altitude (e.g. flight climbs, or changes at one site).
# Pooled statistics weight every station equally (weights 1 / n_obs per station), so dense
# networks do not dominate.

source("R/utils.R")
suppressPackageStartupMessages(library(mgcv))
set.seed(5)

st <- load_stations()

# ==== Tier A ==================================================================================
A <- as.data.table(read_parquet(file.path(dir_interim, "errors_A.parquet")))
gross_frac <- mean(A$gross, na.rm = TRUE)
A <- A[!gross %in% TRUE]
Am <- A[year %in% years_main]

stA <- Am[, c(
  .(n = .N),
  setNames(summarise_error(err_sl)[c("bias", "sd", "mae", "rmse", "p95_abs")],
    paste0(c("bias", "sd", "mae", "rmse", "p95"), "_sl")),
  setNames(summarise_error(err_land)[c("bias", "sd", "mae", "rmse", "p95_abs")],
    paste0(c("bias", "sd", "mae", "rmse", "p95"), "_land"))
), by = id]
stA <- merge(st[tier == "A"], stA, by = "id")
# Reference screen. Two reasons to distrust a station as a reference:
#  1. Implausible offset: a constant offset larger than ERA5 can produce, i.e. 30 m (~3.6 hPa, about
#     twice the p95 where no extrapolation is needed) plus 10% of the gap between station elevation
#     and ERA5 orography (radiosondes show the extrapolation error rarely exceeds 3-6% of the gap).
#     Such a station reports its pressure at a different height than its listed elevation (datum,
#     metadata or barometer error).
#  2. Step change: a clear jump in its error during 2022-2024 (09_reference_checks.R). ERA5 does not
#     jump at one site; the station moved, changed barometer or changed its reference height.
# Both are kept in "all stations" and excluded from the reference set used everywhere else.
stA[, consistent := abs(bias_sl) <= 30 + 0.1 * abs(dz_sl)]
chk <- fread(file.path(dir_tables, "A_reference_checks.csv"))
stA <- merge(stA, chk[, !"bias"], by = "id", all.x = TRUE)
stA[is.na(step_flag), step_flag := FALSE]
stA[, reference := consistent & !step_flag]
fwrite(stA, file.path(dir_tables, "A_station_stats.csv"))

# Excluded stations and the independent evidence about them
flag <- stA[reference == FALSE][order(-abs(bias_sl)), .(
  id, name, elev, z_sl = round(z_sl), dz_sl = round(dz_sl), bias = round(bias_sl, 1),
  sd = round(sd_sl, 1),
  reason = fifelse(!consistent & step_flag, "implausible offset + step",
    fifelse(!consistent, "implausible offset", "step change")),
  step = fifelse(step_flag, round(step), NA_real_),
  step_at = fifelse(step_flag, step_at, NA_character_),
  dem_srtm = dem_srtm_centre, dem_aster = dem_aster_centre, dem_refutes,
  nb_n, nb_km_min = round(nb_km_min), nb_bias_median = round(nb_bias_median, 1)
)]
fwrite(flag, file.path(dir_tables, "A_excluded.csv"))

Am <- merge(Am, stA[, .(id, bias_sl, bias_land, n, consistent, reference)], by = "id")
Am[, e_db := err_sl - bias_sl]
Am[, w := 1 / n]

summ_A <- function(ids, label, group) {
  s <- stA[id %in% ids]
  o <- Am[id %in% ids]
  rbindlist(lapply(c("sl", "land"), function(ds) {
    b <- s[[paste0("bias_", ds)]]
    sdv <- s[[paste0("sd_", ds)]]
    e <- o[[paste0("err_", ds)]]
    ok <- is.finite(e)
    data.table(
      group = group, subset = label, dataset = ds,
      n_stations = sum(is.finite(b)), n_obs = sum(ok),
      abs_bias_median = median(abs(b), na.rm = TRUE),
      abs_bias_p90 = quantile(abs(b), 0.9, na.rm = TRUE),
      sd_median = median(sdv, na.rm = TRUE),
      sd_p90 = quantile(sdv, 0.9, na.rm = TRUE),
      mae = wmean(abs(e[ok]), o$w[ok]),
      rmse = sqrt(wmean(e[ok]^2, o$w[ok])),
      p95_abs = wquant(abs(e[ok]), o$w[ok], 0.95)
    )
  }))
}

groups <- list(
  terrain = "terrain", elevation = "elev_class", latitude = "lat_band", climate = "climate"
)
lab_cons <- "reference set (plausible offset, no step change)"
stC <- stA[reference == TRUE]
tabA <- rbind(
  summ_A(stA$id, "all stations", "all"),
  summ_A(stC$id, lab_cons, "all"),
  # Breakdowns use the reference set: otherwise a handful of reference errors dominate MAE/RMSE.
  rbindlist(lapply(names(groups), function(g) {
    rbindlist(lapply(levels(factor(stC[[groups[[g]]]])), function(l) {
      summ_A(stC[get(groups[[g]]) == l]$id, l, g)
    }))
  }))
)
fwrite(tabA, file.path(dir_tables, "A_summary.csv"))

# Sensitivity of the pooled statistics to the screen (appendix)
sens_rules <- data.table(
  rule = c("no screen", "15 m + 5%", "30 m + 10% (used)", "60 m + 20%", "100 m + 30%"),
  a = c(Inf, 15, 30, 60, 100), b = c(Inf, 0.05, 0.1, 0.2, 0.3)
)
sensA <- rbindlist(lapply(seq_len(nrow(sens_rules)), function(i) {
  r <- sens_rules[i]
  ok <- stA[, abs(bias_sl) <= r$a + r$b * abs(dz_sl)]
  rbind(
    cbind(rule = r$rule, steps = "kept", summ_A(stA$id[ok], "", "")[dataset == "sl"]),
    cbind(rule = r$rule, steps = "excluded",
      summ_A(stA$id[ok & !stA$step_flag], "", "")[dataset == "sl"])
  )
}))
sensA[, c("group", "subset", "dataset") := NULL]
fwrite(sensA, file.path(dir_tables, "A_sensitivity.csv"))

# Diurnal and seasonal cycle of the de-biased error (precision), by climate zone
Am[, hour_bin := floor(lsh)]
Am[, month_seas := pmin(12, floor((sdoy - 1) / 30.5) + 1)]
Am <- merge(Am, stA[, .(id, climate, terrain)], by = "id")
cyc_h <- Am[reference == TRUE, .(mean = wmean(e_db, w), sd = sqrt(wmean(e_db^2, w)), n = .N), by = .(climate,
  hour_bin)]
cyc_m <- Am[reference == TRUE, .(mean = wmean(e_db, w), sd = sqrt(wmean(e_db^2, w)), n = .N), by = .(climate,
  month_seas)]
fwrite(cyc_h, file.path(dir_tables, "A_cycle_hour.csv"))
fwrite(cyc_m, file.path(dir_tables, "A_cycle_month.csv"))

# Change over time (ERA5 observing system): stations with data in every era year
era_ids <- if (file.exists(file.path(dir_interim, "era_ids.csv"))) {
  fread(file.path(dir_interim, "era_ids.csv"))$id
} else character()
Ae <- A[id %in% era_ids]
if (nrow(Ae) > 0) {
  Ae <- Ae[, .(bias = mean(err_sl), sd = sd(err_sl), n = .N), by = .(id, year)][n >= 500]
  Ae <- Ae[id %in% Ae[, .N, by = id][N == max(N), id]]
  eraA <- Ae[, .(n_stations = .N, abs_bias_median = median(abs(bias)), sd_median = median(sd),
    sd_p90 = quantile(sd, 0.9)), by = year][order(year)]
  fwrite(eraA, file.path(dir_tables, "A_era.csv"))
}

# ---- Drivers: station level ------------------------------------------------------------------
dA <- stA[reference == TRUE & is.finite(sd_sl) & is.finite(sdor) & !is.na(climate)]
dA[, climate := factor(climate)]
m_bias <- gam(log(abs(bias_sl) + 0.5) ~ s(dz_sl, k = 8) + s(log1p(sdor), k = 6) +
  s(abs_lat, k = 6) + climate, data = dA, method = "REML")
m_sd <- gam(log(sd_sl) ~ s(dz_sl, k = 8) + s(log1p(sdor), k = 6) + s(abs_lat, k = 6) + climate,
  data = dA, method = "REML")

# Deviance explained lost when each term is dropped and the model refitted: a simple, comparable
# importance measure for smooth and parametric terms alike.
drop_importance <- function(m, data, fit = function(f) gam(f, data = data, method = "REML")) {
  labs <- attr(terms(formula(m)), "term.labels")
  full <- summary(m)$dev.expl
  pretty <- c(dz_sl = "station elevation - ERA5 orography", sdor = "sub-grid terrain roughness",
    abs_lat = "absolute latitude", climate = "Koppen climate zone", lsh = "local solar hour",
    sdoy = "season", log_blh = "boundary layer height", skt_t2m = "skin - 2 m temperature",
    abs_dsp6 = "6 h pressure tendency", id_f = "station (random effect)")
  key <- sub("^s\\((log1p\\()?([a-z0-9_]+).*$", "\\2", labs)
  data.table(
    term = ifelse(key %in% names(pretty), pretty[key], labs),
    dev_expl_full = full,
    dev_expl_drop = vapply(seq_along(labs), function(i) {
      f <- reformulate(labs[-i], response = formula(m)[[2]])
      full - summary(fit(f))$dev.expl
    }, numeric(1)),
    n = nrow(m$model)
  )
}
drivers_st <- rbind(
  cbind(response = "log |bias|", drop_importance(m_bias, dA)),
  cbind(response = "log SD", drop_importance(m_sd, dA))
)
fwrite(drivers_st, file.path(dir_tables, "A_drivers_station.csv"))

# ---- Drivers: observation level (precision) --------------------------------------------------
dobs <- Am[reference == TRUE & is.finite(blh) & is.finite(skt_t2m) & is.finite(dsp6)][sample(.N, min(.N, 2e6))]
dobs[, `:=`(abs_e = abs(e_db), id_f = factor(id), log_blh = log(blh), abs_dsp6 = abs(dsp6) / 100)]
m_obs <- bam(abs_e ~ s(lsh, bs = "cc", k = 12) + s(sdoy, bs = "cc", k = 12) + s(log_blh, k = 8) +
  s(skt_t2m, k = 8) + s(abs_dsp6, k = 8) + s(id_f, bs = "re"),
  data = dobs, discrete = TRUE, nthreads = n_cores)
imp <- drop_importance(m_obs, dobs, function(f) {
  bam(f, data = dobs, discrete = TRUE, nthreads = n_cores)
})
fwrite(imp, file.path(dir_tables, "A_drivers_obs.csv"))
saveRDS(m_obs, file.path(dir_interim, "m_obs.rds"))

# ==== Tier B ==================================================================================
B <- load_tier_b(st)
gross_frac_B <- attr(B, "gross_frac")

# Formula variants are evaluated separately in 07b_formula.R.
err_vars <- c(
  "GeoPressureR (ERA5 single-levels)" = "err_sl_rel",
  "ERA5-Land" = "err_land_rel"
)

height_stats <- function(d, by) {
  rbindlist(lapply(names(err_vars), function(lab) {
    v <- err_vars[[lab]]
    d[is.finite(get(v)), .(
      method = lab, n = .N, n_stations = uniqueN(id),
      bias = wmean(get(v), w), sd = sqrt(wmean((get(v) - wmean(get(v), w))^2, w)),
      mae = wmean(abs(get(v)), w), rmse = sqrt(wmean(get(v)^2, w)),
      p95_abs = wquant(abs(get(v)), w, 0.95)
    ), by = by]
  }))
}
tabB <- height_stats(B, "hbin")[order(method, hbin)]
fwrite(tabB, file.path(dir_tables, "B_height.csv"))
tabB_dn <- height_stats(B, c("hbin", "daynight", "season"))[order(method, hbin)]
fwrite(tabB_dn, file.path(dir_tables, "B_height_daynight_season.csv"))
tabB_cl <- height_stats(B[!is.na(climate)], c("hbin", "climate"))[order(method, hbin)]
fwrite(tabB_cl, file.path(dir_tables, "B_height_climate.csv"))

# Absolute error at height (not relative to the surface level): accuracy for a bird in flight
tabB_abs <- B[is.finite(err_sl), .(
  n = .N, bias = wmean(err_sl, w), mae = wmean(abs(err_sl), w), rmse = sqrt(wmean(err_sl^2, w)),
  p95_abs = wquant(abs(err_sl), w, 0.95)
), by = .(hbin, trusted)][order(trusted, hbin)]
fwrite(tabB_abs, file.path(dir_tables, "B_height_absolute.csv"))

# Bird-weighted error: height bins weighted by the share of geolocator flight points in them
bird_bins <- bird_height_weights()
bw <- merge(tabB, bird_bins[, .(hbin, prop)], by = "hbin")
bird_w <- bw[, .(
  mae = sum(mae * prop), rmse = sqrt(sum(rmse^2 * prop)), bias = sum(bias * prop)
), by = method]
fwrite(bird_w, file.path(dir_tables, "B_bird_weighted.csv"))

# Physical explanation: layer-mean temperature assumed by the formula vs observed by the sonde
B[, pred_temp := agl * (tmean_assumed - tmean_obs) / tmean_obs]
fit_t <- B[agl > 200 & is.finite(pred_temp) & is.finite(err_sl_rel), {
  f <- lm(err_sl_rel ~ pred_temp)
  .(r = cor(err_sl_rel, pred_temp), slope = coef(f)[2], intercept = coef(f)[1],
    r2 = summary(f)$r.squared, n = .N)
}]
fwrite(fit_t, file.path(dir_tables, "B_temperature_explanation.csv"))

# ==== Headline numbers ========================================================================
g <- function(tab, sub, ds, col) tab[subset == sub & dataset == ds][[col]]
api <- if (file.exists(file.path(dir_tables, "api_crosscheck_summary.csv"))) {
  fread(file.path(dir_tables, "api_crosscheck_summary.csv"))
} else NULL
bsl <- tabB[method == names(err_vars)[1]]
bw1 <- bird_w[method == names(err_vars)[1]]
hb <- function(bin, col) bsl[hbin == bin][[col]]
headline <- list(
  A_n_stations = uniqueN(Am$id),
  A_n_obs = nrow(Am),
  A_gross_fraction = gross_frac,
  A_abs_bias_median = g(tabA, "all stations", "sl", "abs_bias_median"),
  A_abs_bias_p90 = g(tabA, "all stations", "sl", "abs_bias_p90"),
  A_sd_median = g(tabA, "all stations", "sl", "sd_median"),
  A_sd_p90 = g(tabA, "all stations", "sl", "sd_p90"),
  A_mae = g(tabA, "all stations", "sl", "mae"),
  A_rmse = g(tabA, "all stations", "sl", "rmse"),
  A_p95 = g(tabA, "all stations", "sl", "p95_abs"),
  A_n_candidates = nrow(fread(file.path(dir_interim, "hadisd_candidates.csv"))),
  A_n_coverage = nrow(fread(file.path(dir_interim, "stations_A_all.csv"))),
  B_n_candidates = nrow(fread(file.path(dir_interim, "igra_candidates.csv"))),
  B_n_with_data = nrow(st[tier == "B"]),
  B_n_levels = nrow(B),
  A_n_inconsistent = sum(!stA$consistent),
  A_n_step = sum(stA$step_flag),
  A_n_step_only = sum(stA$step_flag & stA$consistent),
  A_n_excluded = sum(!stA$reference),
  A_n_dem_refutes = sum(stA$dem_refutes, na.rm = TRUE),
  A_n_dem_refutes_reference = sum(stA$dem_refutes & stA$reference, na.rm = TRUE),
  A_n_minute_coord = sum(stA$minute_coord, na.rm = TRUE),
  A_cons_n_stations = g(tabA, lab_cons, "sl", "n_stations"),
  A_cons_abs_bias_median = g(tabA, lab_cons, "sl", "abs_bias_median"),
  A_cons_abs_bias_p90 = g(tabA, lab_cons, "sl", "abs_bias_p90"),
  A_cons_sd_median = g(tabA, lab_cons, "sl", "sd_median"),
  A_cons_sd_p90 = g(tabA, lab_cons, "sl", "sd_p90"),
  A_cons_mae = g(tabA, lab_cons, "sl", "mae"),
  A_cons_rmse = g(tabA, lab_cons, "sl", "rmse"),
  A_cons_p95 = g(tabA, lab_cons, "sl", "p95_abs"),
  A_cons_land_mae = g(tabA, lab_cons, "land", "mae"),
  A_cons_land_abs_bias_median = g(tabA, lab_cons, "land", "abs_bias_median"),
  A_land_mae = g(tabA, "all stations", "land", "mae"),
  A_land_abs_bias_median = g(tabA, "all stations", "land", "abs_bias_median"),
  B_n_stations = uniqueN(B$id),
  B_n_soundings = uniqueN(B[, paste(id, sounding)]),
  B_gross_fraction = gross_frac_B,
  B_rel_bias_1000_1500 = hb("(1e+03,1.5e+03]", "bias"),
  B_rel_rmse_1000_1500 = hb("(1e+03,1.5e+03]", "rmse"),
  B_rel_bias_2000_3000 = hb("(2e+03,3e+03]", "bias"),
  B_rel_rmse_2000_3000 = hb("(2e+03,3e+03]", "rmse"),
  B_rel_bias_5000_6000 = hb("(5e+03,6e+03]", "bias"),
  B_rel_rmse_5000_6000 = hb("(5e+03,6e+03]", "rmse"),
  B_bird_weighted_bias = bw1$bias,
  B_bird_weighted_mae = bw1$mae,
  B_bird_weighted_rmse = bw1$rmse,
  B_temp_r = fit_t$r,
  api_max_abs_diff = if (is.null(api)) NA else api$max_abs_diff
)
headline <- data.table(
  metric = names(headline),
  value = vapply(headline, function(v) if (length(v)) as.numeric(v[1]) else NA_real_, 1)
)
fwrite(headline, file.path(dir_tables, "headline.csv"))
writeLines(geopressurer_version(), file.path(dir_tables, "geopressurer_version.txt"))

# ==== Tables behind the figures (drawn by 10_figures.R) ========================================
bc <- B[!is.na(climate) & is.finite(err_sl_rel) & !is.na(hbin), .(bias = wmean(err_sl_rel, w),
  sd = sqrt(wmean((err_sl_rel - wmean(err_sl_rel, w))^2, w)), n_st = uniqueN(id)),
  by = .(hbin, climate, season)]
bc[, agl_mid := hbin_mid[as.integer(hbin)]]
fwrite(bc, file.path(dir_tables, "B_height_climate_season.csv"))
# Observed error vs the error predicted from the temperature profile, counted in 5 m bins
bt <- B[agl > 200 & is.finite(pred_temp) & is.finite(err_sl_rel),
  .N, by = .(pred = 5 * round(pred_temp / 5), obs = 5 * round(err_sl_rel / 5))]
fwrite(bt, file.path(dir_tables, "B_temperature_bins.csv"))
fwrite(B[, .(n_soundings = uniqueN(sounding), n_levels = .N), by = id],
  file.path(dir_tables, "B_stations_used.csv"))

cat("Analysis done.\n")
print(tabA[group == "all"])
print(tabB[method == names(err_vars)[1]])
print(bird_w)
