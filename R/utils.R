# Shared helpers for the altitude validation pipeline.
#
# The altitude retrieval itself is never re-implemented here: `era5_altitude()` calls the exact
# GeoPressureR internals that `pressurepath_create(source = "arco")` uses (grid snapping, nearest
# hour, ARCO reads, ERA5 orography and `pressure_to_altitude()`), so what is validated is what users
# get. `scripts/10_api_crosscheck.R` checks that the ARCO path agrees with GeoPressureAPI.

suppressPackageStartupMessages({
  library(data.table)
  library(arrow)
})

# ---- Configuration ---------------------------------------------------------------------------

GEOPRESSURER_PATH <- Sys.getenv("GEOPRESSURER_PATH", "~/Documents/GitHub/GeoPressureR")

dir_raw <- "data/raw"
dir_interim <- "data/interim"
dir_tables <- "output/tables"
dir_figures <- "output/figures"
for (d in c(dir_raw, dir_interim, dir_tables, dir_figures)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

# HadISD (surface): recent years for the main result, plus sparse historical years to test whether
# accuracy depends on the ERA5 observing system.
years_main <- 2022:2024
years_era <- c(1990, 2005, 2015)
# IGRA2 (upper air)
years_sonde <- 2023:2024
max_agl_sonde <- 6000

n_cores <- as.integer(Sys.getenv("N_CORES", "8"))

load_geopressurer <- function() {
  suppressMessages(pkgload::load_all(GEOPRESSURER_PATH, quiet = TRUE, export_all = TRUE))
  invisible(TRUE)
}

geopressurer_version <- function() {
  sha <- tryCatch(
    system2("git", c("-C", GEOPRESSURER_PATH, "rev-parse", "--short", "HEAD"), stdout = TRUE),
    error = function(e) NA_character_
  )
  desc <- read.dcf(file.path(GEOPRESSURER_PATH, "DESCRIPTION"), fields = "Version")[1, 1]
  paste0(desc, " (", sha, ")")
}

# ---- ERA5 extraction ------------------------------------------------------------------------

#' Snap coordinates to the ERA5 grid exactly as `pressurepath_create_arco_impl()` does.
era5_snap <- function(lon, lat, era5_dataset) {
  res <- if (era5_dataset == "land") 0.1 else 0.25
  list(
    lon = floor(lon / res + 0.5) * res,
    lat = if (era5_dataset == "land") ceiling(lat / res - 0.5) * res else floor(lat / res + 0.5) * res
  )
}

#' Nearest ERA5 hour, as GeoPressureAPI's join and the ARCO backend pick it.
era5_hour <- function(date) {
  as.POSIXct(ceiling(as.numeric(date) / 3600 - 0.5) * 3600, origin = "1970-01-01", tz = "UTC")
}

#' Read ERA5 variables at points (one row per point) from ARCO.
#' @param lon,lat,date vectors of equal length (date POSIXct UTC, already on the hour)
era5_read <- function(lon, lat, date, variable, era5_dataset) {
  g <- era5_snap(lon, lat, era5_dataset)
  out <- lapply(variable, function(v) {
    era5_arco_read_points(v, era5_dataset, g$lon, g$lat, date, debug = FALSE)
  })
  names(out) <- variable
  as.data.table(out)
}

#' ERA5 orography [m] at points, from the same files GeoPressureR uses.
era5_orography <- function(lon, lat, era5_dataset) {
  g <- era5_snap(lon, lat, era5_dataset)
  era5_surface_elevation(g$lon, g$lat, rep(era5_dataset, length(lon)), quiet = TRUE)
}

#' Altitude [m] from pressure [Pa] with the GeoPressureR formula.
era5_altitude <- function(pressure_pa, surface_pressure, temperature_2m, orography) {
  pressure_to_altitude(pressure_pa, surface_pressure, temperature_2m, orography)
}

#' GeoPressureR's barometric formula with the lapse rate (K/m) exposed, for the formula variants in
#' `16_formula.R`. With `lapse = -0.0065` it is `pressure_to_altitude()` (checked in
#' `09_errors.R`).
altitude_lapse <- function(pressure, sp, temperature, z, lapse = -0.0065) {
  z + temperature / lapse * ((pressure / sp)^(-8.31432 * lapse / 9.80665 / 0.0289644) - 1)
}

#' 2 m virtual temperature (K) from 2 m temperature and dewpoint (K) and surface pressure (Pa):
#' Tv = T (1 + 0.608 q), with the vapour pressure from Bolton (1980).
virtual_temperature <- function(t, td, sp) {
  e <- 611.2 * exp(17.67 * (td - 273.15) / (td - 273.15 + 243.5))
  q <- 0.622 * e / (sp - 0.378 * e)
  t * (1 + 0.608 * q)
}

# ---- Misc -----------------------------------------------------------------------------------

#' Run `fun` over `x` in socket workers, retrying a failed element a few times (ARCO occasionally
#' drops a connection) and returning NULL for elements that keep failing.
#'
#' Socket rather than forked workers: on macOS, libcurl segfaults in a forked child. Each worker
#' sources R/utils.R (and loads GeoPressureR when `geopressurer = TRUE`); `export` names further
#' objects to copy from the calling environment.
par_map <- function(x, fun, cores = n_cores, retries = 3, geopressurer = FALSE, export = character(),
                    envir = parent.frame()) {
  cl <- parallel::makePSOCKcluster(cores)
  on.exit(parallel::stopCluster(cl))
  wd <- getwd()
  parallel::clusterCall(cl, function(wd, gp) {
    setwd(wd)
    source("R/utils.R")
    if (gp) load_geopressurer()
    NULL
  }, wd, geopressurer)
  if (length(export) > 0) parallel::clusterExport(cl, export, envir = envir)
  safe <- function(xi) {
    for (i in seq_len(retries)) {
      res <- tryCatch(fun(xi), error = function(e) e)
      if (!inherits(res, "error")) return(res)
      Sys.sleep(2 * i)
    }
    message("failed: ", paste(format(xi), collapse = " "), " -- ", conditionMessage(res))
    structure(list(conditionMessage(res)), class = "par_map_error")
  }
  environment(safe) <- list2env(list(fun = fun, retries = retries), parent = globalenv())
  parallel::parLapplyLB(cl, x, safe)
}

#' Report the elements of `x` for which par_map() failed; with `fatal = TRUE`, stop so that the
#' step is rerun (it resumes from what is already on disk) rather than silently left incomplete.
check_failures <- function(res, x, what = "elements", fatal = FALSE) {
  ok <- vapply(res, function(r) !inherits(r, "par_map_error"), logical(1))
  cat(sum(ok), "of", length(x), what, "done\n")
  if (!all(ok)) {
    msg <- paste0(sum(!ok), " ", what, " failed: ", paste(head(format(x[!ok]), 10), collapse = ", "),
      if (sum(!ok) > 10) ", ..." else "")
    if (fatal) stop(msg, ". Rerun this step to retry them.", call. = FALSE) else warning(msg, call. = FALSE)
  }
  invisible(ok)
}

#' Download with the system curl (robust, resumable-safe, no R libcurl state).
curl_download <- function(url, dest) {
  status <- system2("curl", c("-sfL", "--retry", "3", "-o", shQuote(dest), shQuote(url)))
  if (status != 0) stop("curl failed (", status, "): ", url)
  invisible(dest)
}

local_solar_hour <- function(date, lon) {
  (as.numeric(format(date, "%H", tz = "UTC")) + as.numeric(format(date, "%M", tz = "UTC")) / 60 +
    lon / 15) %% 24
}

#' Day of year shifted by half a year in the southern hemisphere, so that 1 = mid-winter-ish
#' January in the north and July in the south: "seasonal day".
seasonal_doy <- function(date, lat) {
  doy <- as.integer(format(date, "%j", tz = "UTC"))
  south <- rep_len(lat < 0, length(doy))
  doy[south] <- (doy[south] + 182) %% 365 + 1
  doy
}

summarise_error <- function(e) {
  e <- e[is.finite(e)]
  list(
    n = length(e),
    bias = mean(e),
    mae = mean(abs(e)),
    rmse = sqrt(mean(e^2)),
    sd = sd(e),
    p50_abs = unname(quantile(abs(e), 0.5)),
    p95_abs = unname(quantile(abs(e), 0.95))
  )
}

# ---- Shared by the analysis scripts ---------------------------------------------------------

wmean <- function(x, w) sum(x * w) / sum(w)
wquant <- function(x, w, p) {
  o <- order(x)
  cw <- cumsum(w[o]) / sum(w)
  x[o][which(cw >= p)[1]]
}

#' Thin stations for spatial balance: one random station per `res`-degree cell, plus every station
#' above `high` m (mountain stations are scarce and are where errors are largest).
thin_stations <- function(s, res = 2, high = 1000) {
  cell <- paste(floor(s$lat / res), floor(s$lon / res))
  pick <- unlist(lapply(split(seq_len(nrow(s)), cell), function(i) i[sample.int(length(i), 1)]))
  s[sort(unique(c(pick, which(s$elev > high))))]
}

#' Terrain roughness class from the SD of the sub-grid orography (ERA5 `sdor`, m).
terrain_class <- function(sdor) {
  cut(sdor, c(-Inf, 20, 50, 150, 300, Inf), labels = c("flat (<20 m)", "gentle (20-50 m)",
    "hilly (50-150 m)", "rough (150-300 m)", "mountain (>300 m)"))
}

#' Station table with the classes used to break down the results.
load_stations <- function() {
  st <- fread(file.path(dir_tables, "stations.csv"))
  st[, abs_lat := abs(lat)]
  st[, terrain := terrain_class(sdor)]
  st[, elev_class := cut(elev, c(-Inf, 200, 500, 1000, 2000, Inf),
    labels = c("<200 m", "200-500 m", "500-1000 m", "1000-2000 m", ">2000 m"))]
  st[, lat_band := cut(abs_lat, c(0, 23.5, 45, 66.5, 90), include.lowest = TRUE,
    labels = c("tropics (0-23.5)", "subtropics (23.5-45)", "mid-latitude (45-66.5)",
      "polar (>66.5)"))]
  climate_names <- c(A = "A tropical", B = "B arid", C = "C temperate", D = "D continental",
    E = "E polar")
  st[, climate := climate_names[koppen_main]]
  # Cell weight: stations sharing a 2 x 2 degree cell share one weight, so that the stations kept
  # above 1000 m (see thin_stations()) add precision without tilting global summaries to mountains.
  st[, cw := 1 / .N, by = .(network, floor(lat / 2), floor(lon / 2))]
  st[]
}

hbin_breaks <- c(-10, 1, 100, 250, 500, 1000, 1500, 2000, 3000, 4000, 5000, 6000)
hbin_mid <- c(0, 50, 175, 375, 750, 1250, 1750, 2500, 3500, 4500, 5500)

#' Radiosonde levels used in the analysis: stations with at least 100 soundings (each station has a
#' fixed weight, so it must be representative), gross errors removed (levels more than 150 m and 10
#' robust SD from the median of their height bin), and weights `w` (the station's cell weight `cw`
#' spread over its levels).
load_radiosondes <- function(st) {
  B <- as.data.table(read_parquet(file.path(dir_interim, "errors_igra.parquet")))
  B <- merge(B, st[network == "igra", .(id, climate, abs_lat, z_sl, cw)],
    by = "id")
  B <- B[id %in% B[, uniqueN(sounding), by = id][V1 >= 100, id]]
  B[, hbin := cut(agl, hbin_breaks, right = TRUE)]
  B[, gross := {
    m <- median(err_sl_rel, na.rm = TRUE)
    r <- mad(err_sl_rel, na.rm = TRUE)
    abs(err_sl_rel - m) > max(150, 10 * r)
  }, by = hbin]
  gross_frac <- mean(B$gross, na.rm = TRUE)
  B <- B[!gross %in% TRUE]
  B[, w := cw / .N, by = id]
  B[, daynight := fifelse(lsh >= 7 & lsh < 19, "day", "night")]
  B[, season := fifelse(sdoy >= 80 & sdoy < 266, "summer half", "winter half")]
  setattr(B, "gross_frac", gross_frac)
  B[]
}

#' Share of geolocator flight points in each radiosonde height bin (below-ground points go to the
#' lowest bin, points above 6 km to the highest).
bird_height_weights <- function() {
  bird <- fread(file.path(dir_tables, "bird_height_distribution.csv"))[flight == TRUE]
  bb <- data.table(
    hbin = levels(cut(0, hbin_breaks, right = TRUE))[-1],
    lo = c(1, 100, 250, 500, 1000, 1500, 2000, 3000, 4000, 5000),
    hi = c(100, 250, 500, 1000, 1500, 2000, 3000, 4000, 5000, 6000)
  )
  bird[, lo := as.numeric(sub("^\\[([^,]+),.*", "\\1", bin))]
  bb <- merge(bb, bird[, .(lo, prop)], by = "lo", all.x = TRUE)
  bb[lo == 1, prop := bird[lo == 0, prop]]
  bb[lo == 1, prop := prop + sum(bird[lo == -Inf, prop])]
  bb[lo == 5000, prop := prop + sum(bird[lo == 6000, prop])]
  bb[, prop := prop / sum(prop)]
  bb[]
}
