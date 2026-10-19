# Read hourly ERA5 at every GHCNh and IGRA2 station from the ECMWF ARCO archive.
#
# For each station and each year it has data, the full hourly series is read (a whole ARCO chunk is
# downloaded anyway, so asking for every hour costs nothing extra and lets later steps compute
# tendencies). Stations are grouped by ARCO single-levels chunk block (4 x 4 cells = 1 x 1 deg) so a
# chunk shared by neighbouring stations is only downloaded once.
#
#   single-levels, all years : surface_pressure, temperature_2m
#   single-levels, main years: skin_temperature, boundary_layer_height, as covariates, and
#                              dewpoint_temperature_2m, for the virtual temperature
#   land, main years         : surface_pressure, temperature_2m
#
# Historical years (`years_era`) are only read for a random subset of up to 100 GHCNh stations
# that report in all of them -- enough to test for a change in accuracy over time, at a fraction of
# the download volume (every ARCO chunk is ~2 MB and the full run reads tens of thousands).

source("R/utils.R")
load_geopressurer()

var_alt <- c("surface_pressure", "temperature_2m")
var_cov <- c("skin_temperature", "boundary_layer_height", "dewpoint_temperature_2m")
short <- c(
  surface_pressure = "sp", temperature_2m = "t2m", dewpoint_temperature_2m = "d2m",
  skin_temperature = "skt", boundary_layer_height = "blh"
)

st <- fread(file.path(dir_tables, "stations.csv"))
cov <- fread(file.path(dir_interim, "ghcnh_coverage.csv"))
set.seed(4)
era_ok <- cov[year %in% years_era & days >= 183, .N, by = id][N == length(years_era), id]
era_ok <- intersect(era_ok, st[network == "ghcnh", id])
era_ids <- if (length(era_ok) > 100) sample(era_ok, 100) else era_ok
st[network == "ghcnh", years := lapply(selected_year, function(y)
  years_ghcnh[years_ghcnh <= y & years_ghcnh >= y - 2])]
st[network == "ghcnh" & id %in% era_ids, years := lapply(years, function(y) c(y, years_era))]
st[network == "igra", years := rep(list(years_sonde), .N)]
st <- st[lengths(years) > 0]

# ARCO is updated close to real time but may lag the station archives by several days. Find its
# latest available hour so current-year station series stop at the shared ERA5 boundary.
latest_required_year <- max(unlist(st$years))
search_start <- as.POSIXct(sprintf("%d-01-01 00:00:00", latest_required_year), tz = "UTC")
search_end <- as.POSIXct(format(Sys.time(), tz = "UTC", format = "%Y-%m-%d %H:00:00"), tz = "UTC")
era5_available <- function(date, dataset) {
  tryCatch({
    era5_read(st$lon[1], st$lat[1], date, "surface_pressure", dataset)
    TRUE
  }, error = function(e) {
    if (grepl("Selected indices for dimension.*out of range", conditionMessage(e))) FALSE else stop(e)
  })
}
latest_hour <- function(dataset) {
  if (!era5_available(search_start, dataset)) {
    stop("ERA5 ", dataset, " has no data in ", latest_required_year, ".", call. = FALSE)
  }
  lo <- as.numeric(search_start)
  hi <- as.numeric(search_end)
  while (lo < hi) {
    mid <- floor((lo + hi + 3600) / 7200) * 3600
    date <- as.POSIXct(mid, origin = "1970-01-01", tz = "UTC")
    if (era5_available(date, dataset)) lo <- mid else hi <- mid - 3600
  }
  as.POSIXct(lo, origin = "1970-01-01", tz = "UTC")
}
era5_last_hour <- min(latest_hour("single-levels"), latest_hour("land"))
cat("ERA5 data available through", format(era5_last_hour, tz = "UTC"), "UTC\n")
jsonlite::write_json(list(last_hour_utc = format(era5_last_hour, tz = "UTC",
  format = "%Y-%m-%d %H:%M:%S")), file.path(dir_interim, "era5_availability.json"), auto_unbox = TRUE)

g <- era5_snap(st$lon, st$lat, "single-levels")
st[, block := paste(network, (round((g$lat + 90) * 4)) %/% 4, (round((g$lon + 180) * 4)) %/% 4)]

out_dir <- file.path(dir_interim, "era5")
dir.create(out_dir, showWarnings = FALSE)
st[, out := file.path(out_dir, paste0(network, "_", id, ".parquet"))]
st[, needs_extract := vapply(seq_len(.N), function(i) {
  f <- out[i]
  if (!file.exists(f)) return(TRUE)
  present_dates <- read_parquet(f, col_select = "date")$date
  present_years <- unique(as.integer(format(present_dates, "%Y")))
  required_end <- min(as.POSIXct(sprintf("%d-12-31 23:00", max(years[[i]])), tz = "UTC"),
    era5_last_hour)
  !all(years[[i]] %in% present_years) || max(present_dates) < required_end
}, logical(1))]

hours_of <- function(years) {
  do.call(c, lapply(years, function(y) {
    end <- min(as.POSIXct(sprintf("%d-12-31 23:00", y), tz = "UTC"), era5_last_hour)
    seq(as.POSIXct(sprintf("%d-01-01", y), tz = "UTC"), end,
      by = "hour"
    )
  }))
}

extract_block <- function(b) {
  s <- st[block == b & needs_extract]
  if (nrow(s) == 0) return(TRUE)
  pts <- rbindlist(lapply(seq_len(nrow(s)), function(i) {
    data.table(k = i, lon = s$lon[i], lat = s$lat[i],
      date = hours_of(s$years[[i]]))
  }))
  pts[, main := as.integer(format(date, "%Y")) %in% c(years_ghcnh, years_sonde)]

  a <- era5_read(pts$lon, pts$lat, pts$date, var_alt, "single-levels")
  setnames(a, short[names(a)])
  setnames(a, paste0(names(a), "_sl"))
  m <- pts[, which(main)]
  cv <- era5_read(pts$lon[m], pts$lat[m], pts$date[m], var_cov, "single-levels")
  setnames(cv, short[names(cv)])
  res <- cbind(pts[, .(k, date)], a)
  for (v in names(cv)) {
    set(res, j = v, value = NA_real_)
    set(res, i = m, j = v, value = cv[[v]])
  }
  l <- era5_read(pts$lon[m], pts$lat[m], pts$date[m], var_alt, "land")
  setnames(l, paste0(short[names(l)], "_land"))
  for (v in names(l)) {
    set(res, j = v, value = NA_real_)
    set(res, i = m, j = v, value = l[[v]])
  }
  for (i in seq_len(nrow(s))) {
    write_parquet(res[k == i, !"k"], s$out[i])
  }
  TRUE
}

fwrite(data.table(id = era_ids), file.path(dir_interim, "era_ids.csv"))
blocks <- unique(st[needs_extract == TRUE]$block)
cat(length(blocks), "blocks,", nrow(st[needs_extract == TRUE]), "stations to extract\n")
t0 <- Sys.time()
res <- par_map(blocks, extract_block, cores = n_cores, geopressurer = TRUE,
  export = c("st", "var_alt", "var_cov", "short", "hours_of", "era5_last_hour"))
cat("Extraction took", format(Sys.time() - t0), "\n")
# Every station needs its ERA5 series: stop if a block failed, so that a rerun fetches it.
check_failures(res, blocks, "blocks", fatal = TRUE)

# Files written before the dewpoint was read for every network lack it: add it in place, for the
# main years only, as for the other covariates.
add_d2m <- function(f) {
  e <- as.data.table(read_parquet(f))
  if ("d2m" %in% names(e)) return(TRUE)
  s <- st[out == f]
  m <- e[, which(as.integer(format(date, "%Y")) %in% c(years_ghcnh, years_sonde))]
  d <- era5_read(rep(s$lon, length(m)), rep(s$lat, length(m)), e$date[m],
    "dewpoint_temperature_2m", "single-levels")
  set(e, j = "d2m", value = NA_real_)
  set(e, i = m, j = "d2m", value = d[[1]])
  write_parquet(e, f)
  TRUE
}
todo <- st[file.exists(out)]$out
todo <- todo[!vapply(todo, function(f) "d2m" %in% names(open_dataset(f)$schema), logical(1))]
cat(length(todo), "stations without dewpoint\n")
res <- par_map(todo, add_d2m, cores = n_cores, geopressurer = TRUE, export = "st")
check_failures(res, todo, "stations", fatal = TRUE)
