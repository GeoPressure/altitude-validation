# Optional transition audit using the existing HadISD cache; not required by the GHCNh pipeline.
# Compare common 2024 hours at nearby matched stations using the same ERA5 grid cell.
source("R/utils.R")
suppressPackageStartupMessages(library(dplyr))
old <- fread(file.path(dir_interim, "ghcnh", "pre_transition_results", "ground_station_stats.csv"))
new <- fread(file.path(dir_tables, "stations.csv"))[network == "ghcnh"]
matches <- fread(file.path(dir_interim, "ghcnh", "legacy_station_matches.csv"))[distance_km <= 1]
pairs <- merge(matches, old[, .(legacy_id = id, old_elev = elev, old_lat = lat, old_lon = lon)], by = "legacy_id")
pairs <- merge(pairs, new[, .(ghcnh_id = id, new_elev = elev, new_lat = lat, new_lon = lon)], by = "ghcnh_id")
g_old <- era5_snap(pairs$old_lon, pairs$old_lat, "single-levels")
g_new <- era5_snap(pairs$new_lon, pairs$new_lat, "single-levels")
pairs <- pairs[g_old$lon == g_new$lon & g_old$lat == g_new$lat][order(distance_km)]
pairs <- unique(pairs, by = "ghcnh_id")
old_ids <- pairs$legacy_id
new_ids <- pairs$ghcnh_id
O <- open_dataset(file.path(dir_interim, "errors_hadisd.parquet")) |>
  filter(year == 2024, id %in% old_ids, !gross) |>
  select(id, date, pressure, err_sl) |>
  collect() |>
  as.data.table()
N <- open_dataset(file.path(dir_interim, "errors_ghcnh.parquet")) |>
  filter(year == 2024, id %in% new_ids, !gross) |>
  select(id, date, pressure, err_sl) |>
  collect() |>
  as.data.table()
setnames(O, c("id", "pressure", "err_sl"), c("legacy_id", "old_pressure", "old_error"))
setnames(N, c("id", "pressure", "err_sl"), c("ghcnh_id", "new_pressure", "new_error"))
O <- merge(O, pairs[, .(legacy_id, ghcnh_id)], by = "legacy_id")
D <- merge(O, N, by = c("ghcnh_id", "date"))
D <- D[is.finite(old_error) & is.finite(new_error)]
summary <- D[, .(common_hours = .N, median_pressure_change_hpa = median(new_pressure - old_pressure),
  median_abs_pressure_change_hpa = median(abs(new_pressure - old_pressure)),
  old_bias = mean(old_error), new_bias = mean(new_error), old_sd = sd(old_error), new_sd = sd(new_error)),
  by = .(legacy_id, ghcnh_id)][common_hours >= 500]
summary <- merge(pairs, summary, by = c("legacy_id", "ghcnh_id"))
summary[, elevation_change_m := new_elev - old_elev]
fwrite(summary, file.path(dir_interim, "ghcnh", "legacy_paired_2024.csv"))
print(summary[, .(stations = .N, common_hours = sum(common_hours),
  median_station_abs_pressure_change_hpa = median(median_abs_pressure_change_hpa),
  median_abs_elevation_change_m = median(abs(elevation_change_m)))])
