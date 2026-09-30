# Download candidate HadISD stations and extract station-level pressure for the study years.
#
# Each HadISD file holds a station's full record (~5 MB). Only the years in `years_main` and
# `years_era` are kept, as one parquet file per station; the netCDF is deleted afterwards.
# HadISD's own QC is applied: values it flagged (-2e30) are dropped.

source("R/utils.R")

base <- "https://www.metoffice.gov.uk/hadobs/hadisd/v343_2025f/data"
cand <- fread(file.path(dir_interim, "hadisd_candidates.csv"))
out_dir <- file.path(dir_interim, "hadisd")
dir.create(out_dir, showWarnings = FALSE)
years <- c(years_era, years_main)

extract_station <- function(id) {
  out <- file.path(out_dir, paste0(id, ".parquet"))
  if (file.exists(out)) return(TRUE)
  gz <- tempfile(fileext = ".nc.gz")
  url <- sprintf("%s/hadisd.3.4.3.2025f_19310101-20250829_%s.nc.gz", base, id)
  curl_download(url, gz)
  nc_file <- R.utils::gunzip(gz, remove = TRUE, overwrite = TRUE)
  on.exit(unlink(nc_file))
  nc <- ncdf4::nc_open(nc_file)
  on.exit(ncdf4::nc_close(nc), add = TRUE)
  time <- as.POSIXct("1931-01-01", tz = "UTC") + ncdf4::ncvar_get(nc, "time") * 3600
  p <- as.vector(ncdf4::ncvar_get(nc, "stnlp"))
  d <- data.table(
    id = id,
    date = time,
    pressure = p
  )[is.finite(pressure) & pressure > 300 & pressure < 1100 &
    as.integer(format(date, "%Y")) %in% years]
  meta <- data.table(
    id = id,
    lat = as.numeric(ncdf4::ncvar_get(nc, "latitude")),
    lon = as.numeric(ncdf4::ncvar_get(nc, "longitude")),
    elev = as.numeric(ncdf4::ncvar_get(nc, "elevation"))
  )
  fwrite(meta, file.path(out_dir, paste0(id, ".meta.csv")))
  # Write then rename, so an interrupted run never leaves a truncated file that looks done.
  write_parquet(d, paste0(out, ".tmp"))
  file.rename(paste0(out, ".tmp"), out)
  TRUE
}

res <- par_map(cand$id, extract_station, cores = 8, export = c("out_dir", "base", "years"))
cat(sum(vapply(res, isTRUE, logical(1))), "of", nrow(cand), "stations extracted\n")

# Coverage: keep stations with station pressure on >= 50% of days in each main year, at a typical
# resolution of 6 h or better (most report 3-hourly).
files <- list.files(out_dir, "\\.parquet$", full.names = TRUE)
cov <- rbindlist(lapply(files, function(f) {
  d <- read_parquet(f)
  if (nrow(d) == 0) return(NULL)
  setDT(d)
  d[, year := as.integer(format(date, "%Y"))]
  d[, .(n = .N, days = uniqueN(as.Date(date))), by = .(id, year)]
}))
meta <- rbindlist(lapply(list.files(out_dir, "\\.meta\\.csv$", full.names = TRUE), fread))
fwrite(cov, file.path(dir_interim, "hadisd_coverage.csv"))

ok <- cov[year %in% years_main, .(
  years_ok = sum(days >= 183 & n / days >= 4)
), by = id][years_ok == length(years_main), id]
sel <- merge(cand[, .(id, name, reason)], meta, by = "id")[id %in% ok]
fwrite(sel, file.path(dir_interim, "stations_A_all.csv"))
cat(nrow(sel), "stations with adequate station pressure in", paste(years_main, collapse = ", "), "\n")
