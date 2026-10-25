# Consistency of the selections, error series and result tables: accepted rows and windows, one
# station per cell, conversions recomputed directly with GeoPressureR, equal station weights and
# complete weight distributions.
source("R/utils.R")
load_geopressurer()
setDTthreads(1)
set.seed(22)
st <- load_stations()
stopifnot(all(is.na(st$koppen) | grepl("^[ABCDE][A-Za-z]{1,2}$", st$koppen)),
  identical(is.na(st$koppen), is.na(st$climate)))
for (net in c("ghcnh", "igra")) {
  accepted <- fread(file.path(network_dir(net), "stations.csv"))
  stopifnot(!anyDuplicated(accepted$id), !anyDuplicated(accepted$cell),
    setequal(accepted$id, st[network == net, id]))
  columns <- c("id", "err_isa", "err_standard", "err_virtual",
    if (net == "ghcnh") c("date", "pressure", "sp_sl", "t2m_sl", "z_sl", "d2m") else
      c("launch", "press", "sp_sl", "t2m_sl", "z_sl", "d2m", "level_time", "press_s", "sp_s", "t2m_s", "z_s", "d2m_s", "agl"))
  d <- as.data.table(read_parquet(file.path(dir_derived, paste0("errors_", net, ".parquet")), col_select = tidyselect::all_of(columns)))
  expected <- accepted[[if (net == "ghcnh") "accepted_hours" else "accepted_levels"]]
  counts <- d[, .N, by = id]
  stopifnot(all(counts$N[match(accepted$id, counts$id)] == expected),
    all(is.finite(d$err_isa)), all(is.finite(d$err_standard)), all(is.finite(d$err_virtual)))
  dates <- if (net == "ghcnh") d$date else d$launch
  index <- match(d$id, accepted$id)
  if (net == "igra") {
    # Every retained sounding passes the hypsometric consistency check.
    source("R/igra.R")
    for (id_value in accepted$id) {
      flags <- igra_consistency(as.data.table(read_parquet(file.path(network_dir(net), "accepted", paste0(id_value, ".parquet")))))
      stopifnot(all(flags$consistent))
    }
  }
  stopifnot(all(dates >= as.POSIXct(accepted$window_start[index], tz = "UTC")),
    all(dates < as.POSIXct(accepted$window_end[index], tz = "UTC")))
  # Independent direct-formula checks of both absolute and paired conversions.
  k <- sample.int(nrow(d), min(10000L, nrow(d)))
  x <- d[k]
  site <- st[network == net][match(x$id, id)]
  if (net == "ghcnh") {
    direct <- pressure_to_altitude(x$pressure * 100, x$sp_sl, x$t2m_sl, x$z_sl,
      dewpoint = x$d2m, lon = site$lon, lat = site$lat, date = x$date, altitude_formula = "virtual") - site$elev
  } else {
    direct <- pressure_to_altitude(x$press, x$sp_sl, x$t2m_sl, x$z_sl,
      dewpoint = x$d2m, lon = site$lon, lat = site$lat, date = x$level_time, altitude_formula = "virtual") -
      pressure_to_altitude(x$press_s, x$sp_s, x$t2m_s, x$z_s,
      dewpoint = x$d2m_s, lon = site$lon, lat = site$lat, date = x$launch, altitude_formula = "virtual") - x$agl
  }
  stopifnot(max(abs(direct - x$err_virtual)) < .01)
  cli::cli_alert_success("{net}: accepted IDs, cell balance, row counts, windows and direct conversions agree")
  rm(d, x)
  gc()
}
B <- load_radiosondes(st, c("id", "band", "lsh", "sdoy"))
stopifnot(!anyNA(B$hbin), all(abs(B[, sum(w), by = .(id, hbin)]$V1 - 1) < 1e-10))
rm(B)
histogram <- fread(file.path(dir_tables, "ground_observation_hist.csv"))
stopifnot(all(abs(histogram[, sum(percent), by = formula]$V1 - 100) < 1e-8),
  all(abs(histogram[, sum(weight), by = formula]$V1 - st[network == "ghcnh", .N]) < 1e-6))
weights <- fread(file.path(dir_tables, "bird_target_height_weights.csv"))
stopifnot(!anyNA(weights$hbin), all(abs(weights[, sum(prop), by = variant]$V1 - 1) < 1e-10))
cli::cli_alert_success("Result checks passed")
