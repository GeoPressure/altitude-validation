# MeteoSwiss SwissMetNet: station pressure at a documented barometer height.
#
# MeteoSwiss publishes, for each automatic station, the height of the barometer
# (`station_height_barometer_masl`) separately from the station height, and 10-min pressure at
# barometer height (QFE, `prestas0`, instantaneous). The value at the full hour is kept for
# 2022-2024. Most stations are exchanged on the GTS (and so assimilated by ERA5); a station is
# flagged `in_isd` when its WMO index appears in NOAA's ISD station history, which receives non-US
# data mainly from the GTS. Open data, "Source: MeteoSwiss".

source("R/utils.R")

out_dir <- file.path(dir_interim, "meteoswiss")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
base <- "https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn"

meta_file <- file.path(dir_raw, "ogd-smn_meta_stations.csv")
if (!file.exists(meta_file)) curl_download(paste0(base, "/ogd-smn_meta_stations.csv"), meta_file)
meta <- fread(meta_file, encoding = "Latin-1")
meta <- meta[is.finite(station_height_barometer_masl), .(
  id = station_abbr, name = station_name, wigos = station_wigos_id,
  lat = station_coordinates_wgs84_lat, lon = station_coordinates_wgs84_lon,
  elev_station = station_height_masl, elev = station_height_barometer_masl
)]

isd_file <- file.path(dir_raw, "isd-history.csv")
if (!file.exists(isd_file)) {
  curl_download("https://www.ncei.noaa.gov/pub/data/noaa/isd-history.csv", isd_file)
}
isd <- fread(isd_file, colClasses = list(character = c("USAF", "WBAN")))
isd <- isd[as.integer(substr(END, 1, 4)) >= max(years_main) &
  as.integer(substr(BEGIN, 1, 4)) <= min(years_main)]
meta[, wmo := fifelse(grepl("^0-20000-0-", wigos), sub("^0-20000-0-", "", wigos), NA_character_)]
meta[, in_isd := !is.na(wmo) & paste0(wmo, "0") %in% isd$USAF]
fwrite(meta, file.path(out_dir, "stations.csv"))
cat(nrow(meta), "stations with a barometer height;", sum(!meta$in_isd), "not in ISD\n")

extract <- function(s) {
  out <- file.path(out_dir, paste0(s, ".parquet"))
  if (file.exists(out)) return(TRUE)
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f))
  curl_download(sprintf("%s/%s/ogd-smn_%s_t_historical_2020-2029.csv", base, tolower(s),
    tolower(s)), f)
  d <- fread(f, select = c("reference_timestamp", "prestas0"), encoding = "Latin-1")
  d[, date := as.POSIXct(reference_timestamp, format = "%d.%m.%Y %H:%M", tz = "UTC")]
  d <- d[format(date, "%M") == "00" & as.integer(format(date, "%Y")) %in% years_main &
    is.finite(prestas0), .(id = s, date, pressure = prestas0)]
  write_parquet(d, out)
  TRUE
}
res <- par_map(meta$id, extract, cores = min(n_cores, 4), export = c("out_dir", "base"))
check_failures(res, meta$id, "stations")
