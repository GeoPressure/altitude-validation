# Main comparisons from the accepted station error series ------------------
source("R/utils.R")
setDTthreads(1)
formulas <- c(isa = "Standard atmosphere", standard = "ERA5, standard lapse rate", virtual = "ERA5, virtual temperature + GPT3")
st <- load_stations()

# Ground comparisons ------------------------------------------------------
G <- as.data.table(read_parquet(file.path(dir_interim, "errors_ghcnh.parquet"),
  col_select = c("id", "date", "err_isa", "err_standard", "err_virtual")))
G <- merge(G, st[network == "ghcnh", .(id, terrain, elev, lat, lon)], by = "id")
G[, reference := "GHCNh"]
G[, w := 1 / .N, by = .(reference, id)]
write_parquet(G, file.path(analysis_dir, "ground_comparison.parquet"))
gs <- rbindlist(lapply(names(formulas), function(f) {
  G[, .(formula = f, n = .N, bias = mean(get(paste0("err_", f))), sd = sd(get(paste0("err_", f))),
    mae = mean(abs(get(paste0("err_", f)))), rmse = sqrt(mean(get(paste0("err_", f))^2)),
    terrain = terrain[1], elev = median(elev), lat = lat[1], lon = lon[1], cw = 1), by = .(reference, id)]
}))
fwrite(gs, file.path(dir_tables, "paper_ground_station.csv"))
ground_summary <- function(s) {
  s[, .(n_stations = .N, abs_bias_median = wquant(abs(bias), cw, .5), abs_bias_p90 = wquant(abs(bias), cw, .9),
    sd_median = wquant(sd, cw, .5), sd_p90 = wquant(sd, cw, .9), mae = wmean(mae, cw), rmse = sqrt(wmean(rmse^2, cw)))]
}
ground <- rbind(gs[, ground_summary(.SD), by = .(formula, reference)][, terrain := "all"],
  gs[reference == "GHCNh", ground_summary(.SD), by = .(formula, reference, terrain)])
fwrite(ground, file.path(dir_tables, "paper_ground.csv"))
tails <- rbindlist(lapply(names(formulas), function(f) {
  G[, .(formula = f, medae = wquant(abs(get(paste0("err_", f))), w, .5),
    p95_abs = wquant(abs(get(paste0("err_", f))), w, .95)), by = reference]
}))
fwrite(tails, file.path(dir_tables, "paper_ground_tails.csv"))
fwrite(G[, .(stations = uniqueN(id), observations = .N), by = reference], file.path(dir_tables, "paper_ground_coverage.csv"))
obs <- rbindlist(lapply(c("isa", "standard", "virtual"), function(f) {
  x <- abs(G[[paste0("err_", f)]])
  as.data.table(c(list(metric = "observation", formula = f),
    as.list(setNames(vapply(c(0.1, 0.25, 0.5, 0.75, 0.9), function(p) wquant(x, G$w, p), 1),
      c("q10", "q25", "q50", "q75", "q90")))))
}))
fwrite(obs, file.path(dir_tables, "paper_ground_observation_quantiles.csv"))
rm(G, gs)
gc()

# Flight comparisons ------------------------------------------------------
B <- load_radiosondes(st, c("id", "band", "lsh", "sdoy", "agl", "err_isa", "err_standard", "err_virtual", "sounding"))
for (f in names(formulas)) setnames(B, paste0("err_", f), paste0("e_", f))
long <- function(by) {
  rbindlist(lapply(names(formulas), function(f) {
    B[, .(formula = f, bias = wmean(get(paste0("e_", f)), w),
      sd = sqrt(wmean((get(paste0("e_", f)) - wmean(get(paste0("e_", f)), w))^2, w)),
      mae = wmean(abs(get(paste0("e_", f))), w), medae = wquant(abs(get(paste0("e_", f))), w, .5),
      rmse = sqrt(wmean(get(paste0("e_", f))^2, w)), n_stations = uniqueN(id)), by = by]
  }))
}
fh <- long("hbin")[order(formula, hbin)]
fh[, agl_mid := hbin_mid[as.integer(hbin)]]
fwrite(fh, file.path(dir_tables, "paper_flight_height.csv"))
fwrite(rbindlist(lapply(names(formulas), function(f) {
  B[, .(formula = f, medae = wquant(abs(get(paste0("e_", f))), w, .5),
    p95_abs = wquant(abs(get(paste0("e_", f))), w, .95)), by = hbin]
})), file.path(dir_tables, "paper_flight_tails.csv"))
fs <- rbindlist(lapply(names(formulas), function(f) {
  B[, .(formula = f, bias = mean(get(paste0("e_", f))), sd = sd(get(paste0("e_", f))), n = .N), by = .(id, hbin)]
}))
fs <- merge(fs, st[network == "igra", .(id, lat, lon)], by = "id")
fs[, `:=`(cw = 1, agl_mid = hbin_mid[as.integer(hbin)])]
fwrite(fs, file.path(dir_tables, "paper_flight_station.csv"))
B[, profile_mid := (ceiling(agl / 250) - .5) * 250]
profile <- rbindlist(lapply(names(formulas), function(f) {
  B[, .(formula = f, bias = mean(get(paste0("e_", f))), sd = sd(get(paste0("e_", f))),
    n = .N, n_soundings = uniqueN(sounding), cw = 1), by = .(id, agl_mid = profile_mid)]
}))
fwrite(profile, file.path(dir_tables, "paper_flight_profile_station.csv"))
fwrite(rbindlist(lapply(c("bias", "sd"), function(m) {
  fs[is.finite(get(m)), .(metric = m, median = wquant(get(m), cw, .5),
    q25 = wquant(get(m), cw, .25), q75 = wquant(get(m), cw, .75)), by = .(formula, hbin, agl_mid)]
})), file.path(dir_tables, "paper_flight_station_summary.csv"))
bb <- bird_height_weights()
B[, prop := bb$prop[match(as.character(hbin), bb$hbin)]]
B[, w_bird := w / sum(w) * prop, by = hbin]
bird <- rbindlist(lapply(names(formulas), function(f) {
  B[, .(formula = f, bias = wmean(get(paste0("e_", f)), w_bird),
    mae = wmean(abs(get(paste0("e_", f))), w_bird),
    rmse = sqrt(wmean(get(paste0("e_", f))^2, w_bird)),
    medae = wquant(abs(get(paste0("e_", f))), w_bird, .5))]
}))
fwrite(bird, file.path(dir_tables, "paper_flight_bird.csv"))
fc <- long(c("hbin", "climate", "season"))[!is.na(climate) & n_stations >= 3]
fc[, agl_mid := hbin_mid[as.integer(hbin)]]
fwrite(fc, file.path(dir_tables, "paper_flight_climate.csv"))
fd <- long(c("hbin", "daynight", "season"))
fd[, agl_mid := hbin_mid[as.integer(hbin)]]
fwrite(fd, file.path(dir_tables, "paper_flight_daynight.csv"))
print(tails)
print(bird)
