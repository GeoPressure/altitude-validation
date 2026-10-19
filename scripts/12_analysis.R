# Reference screen, summaries, and models of what the error depends on, for the surface stations
# (GHCNh) and the radiosondes (IGRA2) (figures: 17_figures.R).
#
# Station bias is the persistent signed offset; station SD is scatter about that offset.
# They describe components of altitude discrepancies, rather than complete accuracy.
# Pooled statistics weight every station by its cell weight `cw` (1 / stations in its 2 x 2 degree
# cell, see load_stations()), spread over its observations, so neither dense networks nor the extra
# mountain stations dominate. Station-level medians and quantiles use the same weights.

source("R/utils.R")
suppressPackageStartupMessages(library(mgcv))
set.seed(5)

st <- load_stations()

# ==== GHCNh =================================================================================
A <- as.data.table(read_parquet(file.path(dir_interim, "errors_ghcnh.parquet")))
selected_years <- st[network == "ghcnh", .(id, year = selected_year)]
A <- A[selected_years, on = .(id, year)]
gross_frac <- mean(A$gross, na.rm = TRUE)
gross_st <- A[, .(gross_st = mean(gross %in% TRUE)), by = id]
Am <- A[!gross %in% TRUE & is.finite(err_sl)]
matched_coverage <- Am[, .(matched_days = uniqueN(as.Date(date)), matched_hours = uniqueN(date)), by = id]
matched_coverage[, coverage_ok := matched_days >= 183 & matched_hours / pmax(matched_days, 1) >= 4]
fwrite(matched_coverage, file.path(dir_tables, "ground_matched_coverage.csv"))
Am <- Am[id %in% matched_coverage[coverage_ok == TRUE, id]]
rm(A)

stA <- Am[, c(
  .(n = .N),
  setNames(summarise_error(err_sl)[c("bias", "sd", "mae", "rmse", "p95_abs")],
    paste0(c("bias", "sd", "mae", "rmse", "p95"), "_sl")),
  setNames(summarise_error(err_land)[c("bias", "sd", "mae", "rmse", "p95_abs")],
    paste0(c("bias", "sd", "mae", "rmse", "p95"), "_land"))
), by = id]
stA <- merge(st[network == "ghcnh"], stA, by = "id")
stA <- merge(stA, gross_st, by = "id")
# Reference-plausibility screen, conditional on ERA5-standard residuals.
# Persistent offsets, fitted steps and frequent gross flags can reflect reference metadata,
# pressure error or conversion discrepancies; none is a unique diagnosis of a faulty station.
# The main comparison (step 18) therefore also reports unscreened and step/noise-only results.
stA[, consistent := abs(bias_sl) <= 30 + 0.1 * abs(dz_sl)]
chk <- fread(file.path(dir_tables, "ground_reference_checks.csv"))
stA <- merge(stA, chk[, !"bias"], by = "id", all.x = TRUE)
stA[is.na(step_flag), step_flag := FALSE]
stA[, noisy := gross_st > 0.01]
stA[, reference := consistent & !step_flag & !noisy]
fwrite(stA, file.path(dir_tables, "ground_station_stats.csv"))

# Excluded stations and the independent evidence about them
flag <- stA[reference == FALSE][order(-abs(bias_sl)), .(
  id, name, elev, z_sl = round(z_sl), dz_sl = round(dz_sl), bias = round(bias_sl, 1),
  sd = round(sd_sl, 1),
  reason = mapply(function(a, b, c) {
    paste(c("implausible offset", "step change", "gross errors")[c(a, b, c)], collapse = " + ")
  }, !consistent, step_flag, noisy),
  step = fifelse(step_flag, round(step), NA_real_),
  step_at = fifelse(step_flag, step_at, NA_character_),
  dem_srtm = dem_srtm_centre, dem_aster = dem_aster_centre, dem_refutes,
  nb_n, nb_km_min = round(nb_km_min), nb_bias_median = round(nb_bias_median, 1)
)]
fwrite(flag, file.path(dir_tables, "ground_excluded.csv"))

Am <- merge(Am, stA[, .(id, bias_sl, bias_land, n, cw, consistent, reference)], by = "id")
Am[, e_db := err_sl - bias_sl]
Am[, w := cw / n]

summ_A <- function(ids, label, group) {
  s <- stA[id %in% ids]
  o <- Am[id %in% ids]
  rbindlist(lapply(c("sl", "land"), function(ds) {
    b <- s[[paste0("bias_", ds)]]
    sdv <- s[[paste0("sd_", ds)]]
    ob <- is.finite(b)
    e <- o[[paste0("err_", ds)]]
    ok <- is.finite(e)
    data.table(
      group = group, subset = label, dataset = ds,
      n_stations = sum(ob), n_obs = sum(ok),
      abs_bias_median = wquant(abs(b[ob]), s$cw[ob], 0.5),
      abs_bias_p90 = wquant(abs(b[ob]), s$cw[ob], 0.9),
      sd_median = wquant(sdv[ob], s$cw[ob], 0.5),
      sd_p90 = wquant(sdv[ob], s$cw[ob], 0.9),
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
fwrite(tabA, file.path(dir_tables, "ground_summary.csv"))

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
fwrite(sensA, file.path(dir_tables, "ground_sensitivity.csv"))

# ---- What the error depends on: station level ------------------------------------------------------------------
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
fwrite(drivers_st, file.path(dir_tables, "ground_importance_station.csv"))

# ---- What the error depends on: observation level (precision) --------------------------------------------------
# Bound the station-effect fit; all error summaries above still use every eligible observation.
dobs <- Am[reference == TRUE & is.finite(blh) & is.finite(skt_t2m) & is.finite(dsp6)]
model_ids <- sample(sort(unique(dobs$id)), min(uniqueN(dobs$id), 200L))
dobs <- dobs[id %in% model_ids][sample(.N, min(.N, 1e5))]
dobs[, `:=`(abs_e = abs(e_db), id_f = factor(id), log_blh = log(blh), abs_dsp6 = abs(dsp6) / 100)]
m_obs <- bam(abs_e ~ s(lsh, bs = "cc", k = 12) + s(sdoy, bs = "cc", k = 12) + s(log_blh, k = 8) +
  s(skt_t2m, k = 8) + s(abs_dsp6, k = 8) + s(id_f, bs = "re"),
  data = dobs, discrete = TRUE, nthreads = n_cores)
imp <- drop_importance(m_obs, dobs, function(f) {
  bam(f, data = dobs, discrete = TRUE, nthreads = n_cores)
})
imp[, n_stations := uniqueN(dobs$id)]
fwrite(dobs[, .(n = .N), by = id], file.path(dir_tables, "ground_importance_sample.csv"))
fwrite(imp, file.path(dir_tables, "ground_importance_obs.csv"))

# ==== IGRA2 ==================================================================================
B <- load_radiosondes(st)
gross_frac_B <- attr(B, "gross_frac")

# Formula variants are evaluated separately in 16_formula.R.
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
fwrite(tabB, file.path(dir_tables, "flight_height.csv"))
tabB_dn <- height_stats(B, c("hbin", "daynight", "season"))[order(method, hbin)]
fwrite(tabB_dn, file.path(dir_tables, "flight_daynight_season.csv"))

# Physical explanation: layer-mean temperature assumed by the formula vs observed by the sonde
B[, pred_temp := agl * (tmean_assumed - tmean_obs) / tmean_obs]
fit_t <- B[agl > 200 & is.finite(pred_temp) & is.finite(err_sl_rel), {
  f <- lm(err_sl_rel ~ pred_temp)
  .(r = cor(err_sl_rel, pred_temp), slope = coef(f)[2], intercept = coef(f)[1],
    r2 = summary(f)$r.squared, n = .N)
}]
fwrite(fit_t, file.path(dir_tables, "flight_temperature_explanation.csv"))

# ==== Key numbers quoted in the report ==========================================================
g <- function(tab, sub, ds, col) tab[subset == sub & dataset == ds][[col]]
api <- if (file.exists(file.path(dir_tables, "api_crosscheck_summary.csv"))) {
  fread(file.path(dir_tables, "api_crosscheck_summary.csv"))
} else NULL
bsl <- tabB[method == names(err_vars)[1]]
hb <- function(bin, col) bsl[hbin == bin][[col]]
key <- list(
  ghcnh_n_stations = uniqueN(Am$id),
  ghcnh_gross_fraction = gross_frac,
  ghcnh_n_candidates = nrow(fread(file.path(dir_interim, "ghcnh_match_frame.csv"))),
  ghcnh_n_coverage = nrow(fread(file.path(dir_interim, "ghcnh_stations_all.csv"))),
  igra_n_candidates = nrow(fread(file.path(dir_interim, "igra_candidates.csv"))),
  igra_n_with_data = fread(file.path(dir_interim, "igra_candidates.csv"))[n_soundings >= 100, .N],
  ghcnh_n_inconsistent = sum(!stA$consistent),
  ghcnh_n_step = sum(stA$step_flag),
  ghcnh_n_noisy = sum(stA$noisy),
  ghcnh_high_frac = mean(stA$elev > 1000),
  ghcnh_high_weight = stA[, sum(cw[elev > 1000]) / sum(cw)],
  ghcnh_ref_n_stations = g(tabA, lab_cons, "sl", "n_stations"),
  ghcnh_ref_abs_bias_median = g(tabA, lab_cons, "sl", "abs_bias_median"),
  ghcnh_ref_sd_median = g(tabA, lab_cons, "sl", "sd_median"),
  igra_n_stations = uniqueN(B$id),
  igra_gross_fraction = gross_frac_B,
  igra_rel_bias_1000_1500 = hb("(1e+03,1.5e+03]", "bias"),
  igra_rel_rmse_1000_1500 = hb("(1e+03,1.5e+03]", "rmse"),
  igra_rel_bias_2000_3000 = hb("(2e+03,3e+03]", "bias"),
  igra_rel_rmse_2000_3000 = hb("(2e+03,3e+03]", "rmse"),
  igra_rel_bias_5000_6000 = hb("(5e+03,6e+03]", "bias"),
  api_max_abs_diff = if (is.null(api)) NA else api$max_abs_diff
)
key <- data.table(
  metric = names(key),
  value = vapply(key, function(v) if (length(v)) as.numeric(v[1]) else NA_real_, 1)
)
fwrite(key, file.path(dir_tables, "key_numbers.csv"))
writeLines(geopressurer_version(), file.path(dir_tables, "geopressurer_version.txt"))

# ==== Tables behind the figures (drawn by 17_figures.R) ========================================
bc <- B[!is.na(climate) & is.finite(err_sl_rel) & !is.na(hbin), .(bias = wmean(err_sl_rel, w),
  sd = sqrt(wmean((err_sl_rel - wmean(err_sl_rel, w))^2, w)), n_st = uniqueN(id)),
  by = .(hbin, climate, season)]
bc[, agl_mid := hbin_mid[as.integer(hbin)]]
fwrite(bc, file.path(dir_tables, "flight_climate_season.csv"))
# Observed error vs the error predicted from the temperature profile, counted in 5 m bins
bt <- B[agl > 200 & is.finite(pred_temp) & is.finite(err_sl_rel),
  .N, by = .(pred = 5 * round(pred_temp / 5), obs = 5 * round(err_sl_rel / 5))]
fwrite(bt, file.path(dir_tables, "flight_temperature_bins.csv"))
fwrite(B[, .(n_soundings = uniqueN(sounding), n_levels = .N), by = id],
  file.path(dir_tables, "flight_stations_used.csv"))

cat("Analysis done.\n")
print(tabA[group == "all"])
print(tabB[method == names(err_vars)[1]])
