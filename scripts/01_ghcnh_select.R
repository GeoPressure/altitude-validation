# Define the historical surface-station footprint to preserve a like-for-like transition from
# HadISD. Only station locations and identifiers are used here; all pressure observations come
# from GHCNh.

source("R/utils.R")

f <- file.path(dir_raw, "hadisd_station_fullinfo_v343_2025f.txt")
if (!file.exists(f)) {
  download.file(
    "https://www.metoffice.gov.uk/hadobs/hadisd/v343_2025f/files/hadisd_station_fullinfo_v343_2025f.txt",
    f
  )
}
x <- readLines(f)
frame <- data.table(
  legacy_id = substr(x, 1, 12),
  name = trimws(substr(x, 14, 43)),
  lat = as.numeric(substr(x, 44, 52)),
  lon = as.numeric(substr(x, 53, 61)),
  legacy_elev = as.numeric(substr(x, 62, 69)),
  start = as.Date(substr(x, 70, 80)),
  end = as.Date(substr(x, 81, 92))
)
frame <- frame[start <= as.Date(sprintf("%d-01-01", min(years_main))) &
  end >= as.Date(sprintf("%d-01-01", max(years_main) + 1))]

fwrite(frame, file.path(dir_interim, "ghcnh_match_frame.csv"))
cat(nrow(frame), "legacy station locations available for the GHCNh transition\n")
