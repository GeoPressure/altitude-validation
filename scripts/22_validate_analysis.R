# Verify scientific inputs, weights and cross-output consistency ------------
source("R/utils.R")
load_geopressurer()
setDTthreads(1)
set.seed(22)
st <- load_stations()
for (net in c("ghcnh", "igra")) {
  accepted <- fread(file.path(selection_dir(net), "full-accepted.csv"))
  stopifnot(fread(file.path(selection_dir(net), "full-metrics.csv"))$pending == 0,
    !anyDuplicated(accepted$id), !anyDuplicated(accepted$cell),
    setequal(accepted$id, st[network == net, id]))
  d <- as.data.table(read_parquet(file.path(dir_interim, paste0("errors_", net, ".parquet"))))
  expected <- accepted[[if (net == "ghcnh") "accepted_hours" else "accepted_levels"]]
  counts <- d[, .N, by = id]
  stopifnot(all(counts$N[match(accepted$id, counts$id)] == expected),
    all(is.finite(d$err_isa)), all(is.finite(d$err_standard)), all(is.finite(d$err_virtual)))
  dates <- if (net == "ghcnh") d$date else d$launch
  index <- match(d$id, accepted$id)
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
B <- load_radiosondes(st)
stopifnot(!anyNA(B$hbin), all(abs(B[, sum(w), by = .(id, hbin)]$V1 - 1) < 1e-10))
rm(B)
primary <- fread(file.path(dir_tables, "paper_ground_tails.csv"))[reference == "GHCNh"]
sensitivity <- fread(file.path(dir_tables, "paper_selection_sensitivity.csv"))[selection == "primary"]
check <- merge(primary, sensitivity, by = "formula")
stopifnot(max(abs(check$medae.x - check$medae.y)) < 1e-7,
  max(abs(check$p95_abs.x - check$p95_abs.y)) < 1e-7)
bird <- merge(fread(file.path(dir_tables, "paper_flight_bird.csv")),
  fread(file.path(dir_tables, "paper_bird_target_sensitivity.csv"))[variant == "all_flight"], by = "formula")
stopifnot(max(abs(bird$medae.x - bird$medae.y)) < 1e-7)
# Retain source settings with the completed generation; this removes draft notices.
jsonlite::write_json(list(generated_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  networks = lapply(c("ghcnh", "igra"), function(net) list(network = net,
    run = selection_dir(net), settings = readRDS(file.path(selection_dir(net), "settings.rds")),
    stations = st[network == net, .N])),
  package = geopressurer_version(),
  source_md5 = as.list(tools::md5sum(c("R/utils.R", list.files("scripts", "^[0-9].*R$", full.names = TRUE)))),
  checks = c("accepted rows and windows", "one station per cell", "equal station-band weights",
    "direct GeoPressureR formulas", "selection-comparison primary equality", "bird-target equality")),
  file.path(dir_tables, "selection_analysis_complete.json"), pretty = TRUE, auto_unbox = TRUE)
cli::cli_alert_success("Numerical integration checks passed")
