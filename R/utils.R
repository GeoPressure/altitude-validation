# Shared helpers for the altitude validation pipeline.
#
# The altitude retrieval itself is never re-implemented here: `era5_altitude()` calls the exact
# GeoPressureR internals that `pressurepath_create(source = "arco")` uses (grid snapping, nearest
# hour, ARCO reads, ERA5 orography and `pressure_to_altitude()`), so what is validated is what users
# get. `scripts/06_api_crosscheck.R` checks that the ARCO path agrees with GeoPressureAPI.

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

# Tier A (surface): recent years for the main result, plus sparse historical years to test whether
# accuracy depends on the ERA5 observing system.
years_main <- 2022:2024
years_era <- c(1990, 2005, 2015)
# Tier B (upper air)
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
