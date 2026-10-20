# Run from the project root; reads existing IGRA extracts only.
library(data.table)
library(arrow)
library(sf)
setDTthreads(1)
out <- "docs/methods/igra-sampling-review"
st <- fread("data/interim/igra_candidates.csv")
selected <- fread("data/interim/igra_stations.csv")$id
xy <- st_as_sf(st, coords = c("lon", "lat"), crs = 4326) |> st_transform(8857) |> st_coordinates()
st[, cell := paste(floor(xy[, 1] / 200000), floor(xy[, 2] / 200000), sep = "_")]

# Count usable launches before ERA5 matching and residual exclusions --------
monthly <- list()
quality <- list()
started <- Sys.time()
for (i in seq_len(nrow(st))) {
  f <- file.path("data/interim/igra", paste0(st$id[i], ".parquet"))
  if (!file.exists(f)) next
  d <- as.data.table(read_parquet(f))
  if (!nrow(d)) next
  d[, sounding := sprintf("%04d%02d%02d%02d", year, month, day, hour)]
  quality[[st$id[i]]] <- d[, .(levels = .N, surface_levels = sum(lvl2 == 1), surface_missing = sum(lvl2 == 1 & gph == -9999), surface_qa_removed = sum(lvl2 == 1 & gph == -8888), elapsed_missing = sum(etime == -9999), elapsed_qa_removed = sum(etime == -8888), non_surface_below_400 = sum(lvl2 != 1 & press > 0 & press < 40000))]
  # Missing surface height can use inventory elevation; a QA rejection cannot.
  s <- d[lvl2 == 1 & press > 0 & (gph > -8000 | gph == -9999), .(surface_height = fifelse(gph[1] == -9999, st$elev[i], gph[1])), by = sounding]
  d <- merge(d[hour <= 23 & lvl2 != 1 & press > 0 & gph > -8000], s, by = "sounding")
  d[, agl := gph - surface_height]
  d <- d[agl > 0 & agl <= 6000]
  if (!nrow(d)) next
  d <- unique(d[, .(year, month, day, sounding)])
  monthly[[st$id[i]]] <- d[, .(days = uniqueN(day), soundings = uniqueN(sounding)), by = .(year, month)]
}
quality <- rbindlist(quality, idcol = "id")
monthly <- rbindlist(monthly, idcol = "id")
fwrite(quality, file.path(out, "cached-quality.csv"))
grid <- st[, CJ(year = 2023:2024, month = 1:12), by = .(id, cell)]
monthly <- merge(grid, monthly, by = c("id", "year", "month"), all.x = TRUE)
monthly[is.na(days), `:=`(days = 0L, soundings = 0L)]
fwrite(monthly, file.path(out, "cached-monthly-coverage.csv"))
annual <- monthly[, .(min_month_days = min(days), soundings = sum(soundings)), by = .(id, cell, year)]
annual[, old_selected := id %in% selected]
fwrite(annual, file.path(out, "cached-annual-coverage.csv"))
coverage <- rbindlist(lapply(c(5L, 10L, 15L), function(k) {
  x <- annual[min_month_days >= k]
  data.table(min_days_each_month = k, stations_either_year = uniqueN(x$id), cells_either_year = uniqueN(x$cell), old_selected_stations = uniqueN(x[old_selected == TRUE, id]))
}))
fwrite(coverage, file.path(out, "coverage-thresholds.csv"))
summary <- data.table(metric = c("candidate_stations", "cached_stations", "old_selected_stations", "candidate_equal_area_cells", "raw_levels", "surface_levels", "surface_missing", "surface_qa_removed", "elapsed_missing", "elapsed_qa_removed", "non_surface_below_400", "wall_seconds"), value = c(nrow(st), nrow(quality), length(selected), uniqueN(st$cell), quality[, sum(levels)], quality[, sum(surface_levels)], quality[, sum(surface_missing)], quality[, sum(surface_qa_removed)], quality[, sum(elapsed_missing)], quality[, sum(elapsed_qa_removed)], quality[, sum(non_surface_below_400)], as.numeric(difftime(Sys.time(), started, units = "secs"))))
fwrite(summary, file.path(out, "cached-summary.csv"))
print(summary)
print(coverage)

# Compare pooled and candidate-local residual exclusions ------------------
# This is a threshold diagnostic, not a replacement analysis or final sample.
d <- as.data.table(read_parquet("data/interim/errors_igra.parquet", col_select = c("id", "agl", "err_sl_rel")))
d <- d[is.finite(err_sl_rel)]
d[, band := cut(agl, c(-10, 1, 100, 250, 500, 1000, 1500, 2000, 3000, 4000, 5000, 6000))]
d <- d[!is.na(band)]
d[, pooled := abs(err_sl_rel - median(err_sl_rel)) > max(150, 10 * mad(err_sl_rel)), by = band]
d[, local := abs(err_sl_rel - median(err_sl_rel)) > max(150, 10 * mad(err_sl_rel)), by = .(id, band)]
residual <- d[, .(levels = .N, pooled_removed = sum(pooled), local_removed = sum(local), both_removed = sum(pooled & local), stations = uniqueN(id)), by = band]
fwrite(residual, file.path(out, "residual-exclusions.csv"))
print(residual)
