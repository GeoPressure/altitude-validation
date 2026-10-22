# Summaries and environmental models for the accepted observations ----------
source("R/utils.R")

st <- load_stations()

# ==== GHCNh =================================================================================
A <- as.data.table(read_parquet(file.path(dir_interim, "errors_ghcnh.parquet"), col_select = c("id", "err_sl", "err_land")))
Am <- A[is.finite(err_sl)]
rm(A)

stA <- Am[, c(
  .(n = .N, n_land = sum(is.finite(err_land)),
    bias_sl_paired = mean(err_sl[is.finite(err_land)]), sd_sl_paired = sd(err_sl[is.finite(err_land)])),
  setNames(summarise_error(err_sl)[c("bias", "sd", "mae", "rmse", "p95_abs")],
    paste0(c("bias", "sd", "mae", "rmse", "p95"), "_sl")),
  setNames(summarise_error(err_land)[c("bias", "sd", "mae", "rmse", "p95_abs")],
    paste0(c("bias", "sd", "mae", "rmse", "p95"), "_land"))
), by = id]
stA <- merge(st[network == "ghcnh"], stA, by = "id")
stA[, reference := TRUE]
fwrite(stA, file.path(dir_tables, "ground_station_stats.csv"))
rm(Am)
gc()

# ==== IGRA2 ==================================================================================
B <- load_radiosondes(st, c("id", "band", "lsh", "sdoy", "agl", "err_sl_rel", "err_land_rel", "tmean_assumed", "tmean_obs", "sounding"))


# Three-conversion comparisons are evaluated in conversion_comparison.R.
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
paired <- copy(B[is.finite(err_land_rel)])
paired[, w := 1 / .N, by = .(id, hbin)]
tabB <- height_stats(paired, "hbin")[order(method, hbin)]
rm(paired)
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
key <- list(ghcnh_n_stations = nrow(stA), igra_n_stations = uniqueN(B$id),
  ghcnh_ref_abs_bias_median = median(abs(stA$bias_sl)), ghcnh_ref_sd_median = median(stA$sd_sl))
key <- data.table(
  metric = names(key),
  value = vapply(key, function(v) if (length(v)) as.numeric(v[1]) else NA_real_, 1)
)
fwrite(key, file.path(dir_tables, "key_numbers.csv"))
writeLines(geopressurer_version(), file.path(dir_tables, "geopressurer_version.txt"))

# ==== Tables behind the figures (drawn by supplement.R) ========================================
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
print(stA[, .(stations = .N, median_abs_bias = median(abs(bias_sl)), median_sd = median(sd_sl))])
print(tabB[method == names(err_vars)[1]])
