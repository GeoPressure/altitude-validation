# Download DWD hourly station pressure and station metadata for the study years.
#
# P0 is the observed barometric pressure at station height. The source archives retain DWD quality
# levels and flags; station heights and coordinates come from the archive's accompanying metadata.

source("R/utils.R")
years_main <- 2022:2024

years <- years_main
base <- "https://opendata.dwd.de/climate_environment/CDC/observations_germany/climate/hourly/pressure"
out_dir <- file.path(dir_interim, "dwd")
raw_dir <- file.path(dir_raw, "dwd")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

download_listing <- function(url) {
  page <- paste(readLines(url, warn = FALSE), collapse = "\n")
  unique(regmatches(page, gregexpr('stundenwerte_P0_[^"<> ]+_(hist|akt)\\.zip', page))[[1]])
}

archives <- unique(c(
  download_listing(paste0(base, "/historical/")),
  download_listing(paste0(base, "/recent/"))
))
archives <- archives[grepl("_hist\\.zip$", archives) | grepl("_akt\\.zip$", archives)]
period <- regmatches(archives, regexec("_([0-9]{8})_([0-9]{8})_(hist|akt)\\.zip$", archives))
keep <- vapply(seq_along(archives), function(i) {
  if (grepl("_akt\\.zip$", archives[i])) return(TRUE)
  p <- period[[i]]
  start <- as.integer(substr(p[2], 1, 4))
  end <- as.integer(substr(p[3], 1, 4))
  start <= max(years) && end >= min(years)
}, logical(1))
archives <- archives[keep]

extract_archive <- function(archive) {
  id <- sub("^stundenwerte_P0_([0-9]+)_.*", "\\1", archive)
  out <- file.path(out_dir, paste0(sub("\\.zip$", "", archive), ".parquet"))
  if (file.exists(out)) return(TRUE)

  folder <- if (grepl("_hist\\.zip$", archive)) "historical" else "recent"
  zip_file <- file.path(raw_dir, archive)
  if (!file.exists(zip_file)) curl_download(paste0(base, "/", folder, "/", archive), zip_file)
  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))
  members <- unzip(zip_file, list = TRUE)$Name
  unzip(zip_file, exdir = tmp)
  data_file <- file.path(tmp, members[grepl("produkt_p0_stunde", members, ignore.case = TRUE) &
    grepl("\\.txt$", members)][1])
  meta_file <- file.path(tmp, members[grepl("Metadaten_Geographie", members) &
    grepl("\\.txt$", members)][1])
  if (!file.exists(data_file) || !file.exists(meta_file)) return(FALSE)

  d <- fread(data_file, sep = ";", na.strings = c("-999", "-999.0"),
    colClasses = list(character = c("STATIONS_ID", "MESS_DATUM")))
  m <- fread(meta_file, sep = ";", encoding = "Latin-1")
  d[, date := as.POSIXct(MESS_DATUM, format = "%Y%m%d%H", tz = "UTC")]
  d <- d[as.integer(format(date, "%Y", tz = "UTC")) %in% years]
  if (!nrow(d)) return(TRUE)
  m[, `:=`(meta_start = as.Date(as.character(von_datum), "%Y%m%d"),
    meta_end = as.Date(as.character(bis_datum), "%Y%m%d"))]
  m[is.na(meta_end), meta_end := as.Date("2100-01-01")]
  overlap <- pmin(as.numeric(m$meta_end), as.numeric(as.Date(max(d$date)))) -
    pmax(as.numeric(m$meta_start), as.numeric(as.Date(min(d$date))))
  meta <- m[which.max(overlap), .(id = id, name = Stationsname,
    elev = as.numeric(Stationshoehe), lat = as.numeric(`Geogr.Breite`),
    lon = as.numeric(`Geogr.Laenge`))]
  d[, `:=`(elev = meta$elev, lat = meta$lat, lon = meta$lon, name = meta$name)]
  write_parquet(d, out)
  TRUE
}

res <- par_map(archives, extract_archive, cores = min(n_cores, 4),
  export = c("base", "raw_dir", "out_dir", "years"))
check_failures(res, archives, "DWD station archives")

files <- list.files(out_dir, "^stundenwerte_P0_.*\\.parquet$", full.names = TRUE)
dwd <- rbindlist(lapply(files, read_parquet), fill = TRUE)
if (nrow(dwd)) write_parquet(dwd, file.path(out_dir, "observations.parquet"))
jsonlite::write_json(list(source = "DWD Climate Data Center", years = years,
  generated_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  pressure = "P0, barometric pressure at station height",
  archive_index = paste0(base, "/historical/"), n_archives = length(archives),
  n_station_files = length(files)), file.path(out_dir, "provenance.json"),
  pretty = TRUE, auto_unbox = TRUE)
