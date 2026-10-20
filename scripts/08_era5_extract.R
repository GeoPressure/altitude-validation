# Additional atmosphere inputs at the retained observations ----------------
# The selection caches already contain the primary ERA5 inputs. Per-station
# files checkpoint only the additional variables needed for S2/S3.
source("R/utils.R")
source("R/ghcnh_sampling.R")
load_geopressurer()
setDTthreads(1)
st <- fread(file.path(dir_tables, "stations.csv"))
previous <- fread("archive/analysis-before-selection-2026-10-20/stations.csv")
dir.create(file.path(analysis_dir, "era5"), recursive = TRUE, showWarnings = FALSE)

extract_station <- function(i) {
  s <- st[i]
  out <- file.path(analysis_dir, "era5", paste0(s$network, "_", s$id, ".parquet"))
  if (file.exists(out)) return(TRUE)
  d <- as.data.table(read_parquet(file.path(selection_dir(s$network), "accepted", paste0(s$id, ".parquet"))))
  dates <- if (s$network == "ghcnh") sort(unique(d$date)) else sort(unique(c(d$date, d$date_s)))
  e <- data.table(date = dates)
  fields <- c("sp_land", "t2m_land")
  for (v in fields) e[, (v) := NA_real_]
  cached <- file.path(dir_interim, "era5", paste0(s$network, "_", s$id, ".parquet"))
  same <- previous[network == s$network & id == s$id & abs(lat - s$lat) < 1e-8 & abs(lon - s$lon) < 1e-8]
  if (nrow(same) && file.exists(cached)) {
    old <- as.data.table(read_parquet(cached, col_select = c("date", fields)))
    e[old, on = "date", (fields) := mget(paste0("i.", fields))]
  }
  for (v in fields) {
    missing <- which(!is.finite(e[[v]]))
    if (!length(missing)) next
    variable <- c(sp_land = "surface_pressure", t2m_land = "temperature_2m")[[v]]
    values <- era5_read(rep(s$lon, length(missing)), rep(s$lat, length(missing)), e$date[missing],
      variable, if (v %in% c("sp_land", "t2m_land")) "land" else "single-levels")
    set(e, i = missing, j = v, value = values[[1]])
  }
  ghcnh_write(e, out)
  cli::cli_alert_info("Atmosphere {i}/{nrow(st)}: {s$network} {s$id}")
  TRUE
}
todo <- which(!file.exists(file.path(analysis_dir, "era5", paste0(st$network, "_", st$id, ".parquet"))))
cli::cli_alert_info("Additional atmosphere inputs: {length(todo)} stations to read")
res <- par_map(todo, extract_station, cores = n_cores, geopressurer = TRUE,
  export = c("st", "previous", "ghcnh_write"))
check_failures(res, st$id[todo], "retained station atmosphere inputs", fatal = TRUE)
