# Verify accepted inputs and replay the fixed pilot without downloading.
source("R/utils.R")
source("R/ghcnh_sampling.R")
source("R/igra_sampling.R")
load_geopressurer()
setDTthreads(1)
run_dir <- "data/interim/igra-selection-2026-10-13"
out <- "docs/methods/igra-sampling-review"
settings <- readRDS(file.path(run_dir, "settings.rds"))
accepted <- fread(file.path(run_dir, "pilot-16-accepted.csv"))
gpt3 <- gpt3_read(1)
checks <- list()
for (station_id in accepted$id) {
  d <- as.data.table(read_parquet(file.path(run_dir, "accepted", paste0(station_id, ".parquet"))))
  stopifnot(all(d$press > 0 & d$press_s > 0 & d$gph > -8000 & d$etime != -8888),
    all(d$agl > 0 & d$agl <= 6000), all(is.finite(d$err_standard)), all(is.finite(d$err_virtual)),
    all(is.finite(d$err_isa)), max(abs(d[, sum(weight), by = band]$V1 - 1)) < 1e-12)
  row <- accepted[id == station_id]
  blocks <- as.Date(row$window_end) %m-% months(0:12)
  days <- unique(as.Date(d$launch, tz = "UTC"))
  support <- vapply(1:12, function(m) sum(days >= blocks[m+1] & days < blocks[m]), integer(1))
  stopifnot(min(support) >= settings$days_per_month)
  # Compare virtual conversion against GeoPressureR at the exact paired times.
  k <- unique(round(seq(1, nrow(d), length.out = min(100L, nrow(d)))))
  s <- accepted[id == station_id]
  h <- d[k, pressure_to_altitude(press, sp_sl, t2m_sl, z_sl, dewpoint = d2m,
    lon = rep(s$lon, .N), lat = rep(s$lat, .N), date = level_time, altitude_formula = "virtual")]
  hs <- d[k, pressure_to_altitude(press_s, sp_s, t2m_s, z_s, dewpoint = d2m_s,
    lon = rep(s$lon, .N), lat = rep(s$lat, .N), date = launch, altitude_formula = "virtual")]
  delta <- max(abs(h - hs - d$agl[k] - d$err_virtual[k]))
  stopifnot(delta < .01)
  checks[[station_id]] <- data.table(id = station_id, levels = nrow(d), soundings = uniqueN(d$sounding), min_month_days = min(support),
    below_400_hpa_levels = sum(d$press < 40000), virtual_max_difference_m = delta)
}
fwrite(rbindlist(checks), file.path(out, "pilot-input-checks.csv"))

# Replay with empty checkpoints and accepted outputs, reusing immutable inputs.
replay <- tempfile("igra-serial-replay-")
dir.create(replay)
for (part in c("profiles", "core")) {
  dir.create(file.path(replay, part))
  files <- list.files(file.path(run_dir, part), full.names = TRUE)
  stopifnot(all(file.link(files, file.path(replay, part, basename(files)))))
}
files <- file.path(run_dir, c("settings.rds", "inventory.rds", "catalogue.rds", "candidates.rds"))
stopifnot(all(file.link(files, file.path(replay, basename(files)))))
status <- system2(file.path(R.home("bin"), "Rscript"), c("scripts/sample_igra.R", "16", "1"),
  env = paste0("IGRA_RUN_DIR=", replay), stdout = file.path(replay, "replay.log"), stderr = file.path(replay, "replay-errors.log"))
stopifnot(status == 0)
a <- fread(file.path(run_dir, "pilot-16-attempts.csv"))
b <- fread(file.path(replay, "pilot-16-attempts.csv"))
keep <- setdiff(names(a), "seconds")
stopifnot(isTRUE(all.equal(a[, ..keep], b[, ..keep], check.attributes = FALSE)))
for (station_id in accepted$id) {
  stopifnot(isTRUE(all.equal(read_parquet(file.path(run_dir, "accepted", paste0(station_id, ".parquet"))),
    read_parquet(file.path(replay, "accepted", paste0(station_id, ".parquet"))))))
}
file.copy(file.path(replay, "pilot-16-metrics.csv"), file.path(out, "pilot-16-serial-metrics.csv"), overwrite = TRUE)
unlink(replay, recursive = TRUE)
fwrite(data.table(check = c("Accepted QC, seasonal coverage, weights and exact paired-time virtual conversion", "Fresh serial replay matches parallel selection and all accepted inputs"), passed = TRUE), file.path(out, "pilot-checks.csv"))
cli::cli_alert_success("Pilot input and serial replay checks passed")
