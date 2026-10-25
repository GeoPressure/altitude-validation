# Flight-height results: errors of the three conversions above IGRA2 sounding sites by height,
# climate zone, season and time of day; the bird-weighted summary; and the explanation of errors by
# the column temperature. Each station has equal weight within each height band (load_radiosondes()).
source("R/utils.R")
setDTthreads(1)
formulas <- c("isa", "standard", "virtual")
st <- load_stations()
writeLines(geopressurer_version(), file.path(dir_tables, "geopressurer_version.txt"))

# ---- Three conversions -----------------------------------------------------------------------
B <- load_radiosondes(st, c("id", "band", "lsh", "sdoy", "agl", "err_isa", "err_standard", "err_virtual", "sounding"))
for (f in formulas) setnames(B, paste0("err_", f), paste0("e_", f))
summarise_by <- function(by, wcol = "w") {
  rbindlist(lapply(formulas, function(f) {
    B[, .(formula = f, bias = wmean(get(paste0("e_", f)), get(wcol)),
      sd = sqrt(wmean((get(paste0("e_", f)) - wmean(get(paste0("e_", f)), get(wcol)))^2, get(wcol))),
      n_stations = uniqueN(id)), by = by]
  }))
}
tails_by <- function(by, wcol) {
  rbindlist(lapply(formulas, function(f) {
    B[, .(formula = f, medae = wquant(abs(get(paste0("e_", f))), get(wcol), .5),
      p95_abs = wquant(abs(get(paste0("e_", f))), get(wcol), .95)), by = by]
  }))
}
fwrite(tails_by("hbin", "w"), file.path(dir_tables, "flight_tails.csv"))
# Station bias and SD at each interpolated height, and pooled absolute errors at each height.
fwrite(rbindlist(lapply(formulas, function(f) {
  B[, .(formula = f, bias = mean(get(paste0("e_", f))), sd = sd(get(paste0("e_", f))),
    n = .N, n_soundings = uniqueN(sounding), cw = 1), by = .(id, agl_mid = agl)]
})), file.path(dir_tables, "flight_profile_station.csv"))
B[, w_agl := 1 / .N, by = .(id, agl)]
fwrite(tails_by("agl", "w_agl"), file.path(dir_tables, "flight_profile_tails.csv"))
# Mean signed error by climate zone (at least three stations), day and night, and season.
fwrite(summarise_by(c("agl", "climate", "season"))[!is.na(climate) & n_stations >= 3],
  file.path(dir_tables, "flight_climate_profile.csv"))
fwrite(summarise_by(c("agl", "daynight", "season")), file.path(dir_tables, "flight_daynight_profile.csv"))

# Median absolute error weighted by the flight-time distribution of tracked birds, pooling all
# flight time or giving each tag equal weight.
weights <- fread(file.path(dir_tables, "bird_target_height_weights.csv"))
B[, w_band := w / sum(w), by = hbin]
fwrite(rbindlist(lapply(unique(weights$variant), function(target) {
  p <- weights[variant == target]
  w_target <- B$w_band * p$prop[match(as.character(B$hbin), p$hbin)]
  rbindlist(lapply(formulas, function(f) {
    data.table(variant = target, formula = f, medae = wquant(abs(B[[paste0("e_", f)]]), w_target, .5))
  }))
})), file.path(dir_tables, "flight_bird.csv"))
fwrite(B[, .(n_soundings = uniqueN(sounding), n_levels = .N), by = id], file.path(dir_tables, "flight_stations_used.csv"))
rm(B)

# ---- Column temperature (ERA5, standard lapse rate) -------------------------------------------
B <- load_radiosondes(st, c("id", "band", "lsh", "sdoy", "agl", "err_standard", "tmean_assumed", "tmean_obs", "sounding"))
# Error predicted by the difference between the assumed and observed layer-mean temperature.
B[, pred_temp := agl * (tmean_assumed - tmean_obs) / tmean_obs]
fit <- B[agl > 200 & is.finite(pred_temp) & is.finite(err_standard)]
fwrite(fit[, .(r = cor(err_standard, pred_temp), slope = coef(lm(err_standard ~ pred_temp))[2],
  r2 = cor(err_standard, pred_temp)^2, n = .N)], file.path(dir_tables, "flight_temperature_explanation.csv"))
fwrite(fit[, .N, by = .(pred = 5 * round(pred_temp / 5), obs = 5 * round(err_standard / 5))],
  file.path(dir_tables, "flight_temperature_bins.csv"))
cli::cli_alert_success("Flight results: {uniqueN(st[network == 'igra', id])} sounding sites")
