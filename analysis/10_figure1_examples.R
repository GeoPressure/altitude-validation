# Figure 1 examples: one typical weather station fortnight and two typical soundings.
source("R/utils.R")
source("R/figures.R")
# ---- Figure 1: the column temperature assumed by each formula, two typical soundings ------------
# The two soundings are chosen by a fixed rule, not by eye. For each of two classes, a temperate
# (Koppen C) summer night and a continental (Koppen D) winter night, we take every radiosonde sounding
# of the analysis (load_radiosondes()) in the core of the season (seasonal day of year, i.e. the
# southern hemisphere shifted by six months, in June-August or December-February) and in that half
# of the day (local solar time 07-19 h or not, as in the paper), and its level closest to 2 km above
# the ground (1.7-2.3 km). We compute the error of the height above the ground of the three formulas
# at that level and keep the sounding whose three errors are jointly
# closest (Euclidean distance, m) to the medians of its class: the sounding is typical of the class
# for all three formulas at once.
gpt3 <- gpt3_read(1)
st <- load_stations()
lapse_gpt3 <- function(lon, lat, date) {
  L <- gpt3_lapse(gpt3, lon, lat, as.POSIXlt(date, tz = "UTC")$yday + 1)
  fifelse(abs(L) < 1e-5, -1e-5, L)
}
B <- load_radiosondes(st, c("id", "band", "lsh", "sdoy", "agl", "sp_sl", "t2m_sl", "d2m", "sounding", "level_time", "err_isa", "err_standard", "err_virtual"), levels = TRUE)
B <- B[is.finite(sp_sl) & is.finite(t2m_sl) & is.finite(d2m)]
B[st[network == "igra"], on = "id", `:=`(lon = i.lon, lat = i.lat)]
classes <- data.table(
  cls = c("summer", "winter"), climate = c("C temperate", "D continental"),
  daynight = c("night", "night"), title = c("Temperate summer night", "Continental winter night")
)
B[, cls := fifelse(sdoy >= 152 & sdoy <= 243, "summer", fifelse(sdoy >= 335 | sdoy <= 59,
  "winter", NA_character_))]
B <- B[classes, on = .(cls, climate, daynight), nomatch = NULL]
K <- B[agl >= 1700 & agl <= 2300][order(abs(agl - 2000))][, .SD[1], by = .(id, sounding)]
rm(B)
K[, L := lapse_gpt3(lon, lat, level_time)]
K[, `:=`(e_isa = err_isa, e_standard = err_standard, e_virtual = err_virtual)]
ecols <- c("e_isa", "e_standard", "e_virtual")
K[, paste0("m_", ecols) := lapply(.SD, median), by = cls, .SDcols = ecols]
K[, dist := sqrt((e_isa - m_e_isa)^2 + (e_standard - m_e_standard)^2 +
  (e_virtual - m_e_virtual)^2)]
pick <- K[order(dist)][, .SD[1], by = cls][classes, on = "cls"]
pick[, n_class := K[, .N, by = cls][pick, on = "cls", N]]
pick[st[network == "igra"], on = "id", name := i.name]
print(pick[, .(cls, id, name, sounding, lsh, agl, e_isa, e_standard, e_virtual, m_e_isa,
  m_e_standard, m_e_virtual, n_class)])
picks <- pick[, .(class = title, id, sounding, agl)]


gs <- fread(file.path(dir_tables, "ground_station.csv"))
candidates <- dcast(gs[formula %in% c("isa", "standard")], id ~ formula, value.var = "sd")
candidates <- merge(candidates, st[network == "ghcnh" & koppen_main == "C" & sdor < 20,
  .(id, name, elev)], by = "id")
candidates[, distance := ((isa - median(isa)) / IQR(isa))^2 +
  ((standard - median(standard)) / IQR(standard))^2]
site <- candidates[order(distance, id)][1]
W <- as.data.table(read_parquet(file.path(analysis_dir, "errors", paste0("ghcnh_", site$id, ".parquet"))))
setorder(W, date)
W[, block := as.integer(difftime(date, min(date), units = "days")) %/% 14]
blocks <- W[, .(n = .N, span = as.numeric(difftime(max(date), min(date), units = "days")),
  pressure_range = diff(range(pressure))), by = block][span > 13 & n >= .9 * max(n)]
chosen <- blocks[order(abs(pressure_range - median(pressure_range)), block)][1]
W <- W[block == chosen$block]
Ew <- melt(W, id.vars = "date", measure.vars = paste0("err_", names(pal_conversion)),
  variable.name = "formula", value.name = "error")
Ew[, formula := sub("err_", "", formula)]
profiles <- list()
profile_errors <- list()
for (i in seq_len(nrow(picks))) {
  k <- picks[i]
  d <- as.data.table(read_parquet(file.path(analysis_dir, "errors", paste0("igra_", k$id, ".parquet"))))
  d <- d[sounding == k$sounding][order(agl)]
  k0 <- d[which.min(abs(agl - k$agl))]
  s <- st[network == "igra" & id == k$id]
  L <- gpt3_lapse(gpt3, s$lon, s$lat, as.POSIXlt(k0$level_time, tz = "UTC")$yday + 1)
  heights <- seq(0, 6000, 25)
  z <- heights + k0$gph_s
  profiles[[i]] <- rbind(
    d[temp > -8000 & agl <= 6000, .(height = agl, temperature = temp / 10, formula = "Observed temperature")],
    data.table(height = heights, temperature = 15 - .0065 * z, formula = "isa"),
    data.table(height = heights, temperature = k0$t2m_sl - 273.15 - .0065 * (z - k0$z_sl), formula = "standard"),
    data.table(height = heights, temperature = virtual_temperature(k0$t2m_sl, k0$d2m, k0$sp_sl) -
      273.15 + L * (z - k0$z_sl), formula = "virtual"))[, example := k$class]
  d[, `:=`(illustration_isa = altitude_lapse(press, 101325, 288.15, 0) -
      altitude_lapse(press_s, 101325, 288.15, 0) - agl,
    illustration_standard = altitude_lapse(press, k0$sp_sl, k0$t2m_sl, k0$z_sl) -
      altitude_lapse(press_s, k0$sp_sl, k0$t2m_sl, k0$z_sl) - agl,
    illustration_virtual = altitude_lapse(press, k0$sp_sl,
      virtual_temperature(k0$t2m_sl, k0$d2m, k0$sp_sl), k0$z_sl, L) -
      altitude_lapse(press_s, k0$sp_sl,
        virtual_temperature(k0$t2m_sl, k0$d2m, k0$sp_sl), k0$z_sl, L) - agl)]
  profile_errors[[i]] <- melt(rbind(data.table(height = 0, isa = 0, standard = 0, virtual = 0),
    d[agl <= 6000, .(height = agl, isa = illustration_isa,
    standard = illustration_standard, virtual = illustration_virtual)]), id.vars = "height",
    variable.name = "formula", value.name = "error")[, example := k$class]
}
P <- rbindlist(profiles)
E <- rbindlist(profile_errors)
P[formula == "Observed temperature", formula := "observed"]
for (d in list(P, E)) d[, example := factor(example,
  c("Temperate summer night", "Continental winter night"), c("Summer night", "Winter night"))]

saveRDS(list(W = W, Ew = Ew, P = P, E = E), file.path(analysis_dir, "figure1.rds"))
