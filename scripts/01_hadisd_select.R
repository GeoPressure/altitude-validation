# Surface station candidates: every HadISD station whose record spans the main years.
#
# HadISD's station list does not say which stations report station-level pressure, so all of them
# are downloaded; 02_hadisd_download.R keeps those with enough station pressure and
# 03_hadisd_thin.R thins them for spatial balance.

source("R/utils.R")

f <- file.path(dir_raw, "hadisd_station_fullinfo_v343_2025f.txt")
if (!file.exists(f)) {
  download.file(
    "https://www.metoffice.gov.uk/hadobs/hadisd/v343_2025f/files/hadisd_station_fullinfo_v343_2025f.txt",
    f
  )
}
x <- readLines(f)
st <- data.table(
  id = substr(x, 1, 12),
  name = trimws(substr(x, 14, 43)),
  lat = as.numeric(substr(x, 44, 52)),
  lon = as.numeric(substr(x, 53, 61)),
  elev = as.numeric(substr(x, 62, 69)),
  start = as.Date(substr(x, 70, 80)),
  end = as.Date(substr(x, 81, 92))
)

# Must cover the main years.
st <- st[start <= as.Date(sprintf("%d-01-01", min(years_main))) &
  end >= as.Date(sprintf("%d-01-01", max(years_main) + 1))]

fwrite(st, file.path(dir_interim, "hadisd_candidates.csv"))
cat(nrow(st), "candidate stations\n")
