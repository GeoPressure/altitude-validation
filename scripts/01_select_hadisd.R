# Tier A candidate selection: a spatially balanced sample of HadISD stations.
#
# HadISD's station list does not say which stations report station-level pressure, so this selects
# candidates generously; 02_download_hadisd.R then keeps those with enough station pressure.
#
# Design: within every 5 x 5 degree cell keep the highest, the lowest and one random station (this
# balances continents and spans each cell's elevation range), then add every station above 1000 m
# so that rough terrain -- where errors are expected to be largest -- is well represented.

source("R/utils.R")
set.seed(1)

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
st[, cell := paste(floor(lat / 5), floor(lon / 5))]

pick <- st[, {
  i <- unique(c(which.max(elev), which.min(elev), sample(.N, min(.N, 1))))
  .SD[i]
}, by = cell]
cand <- unique(rbind(pick, st[elev > 1000]), by = "id")
cand[, reason := fifelse(id %in% pick$id, "cell", "high")]

fwrite(cand, file.path(dir_interim, "hadisd_candidates.csv"))
cat(nrow(cand), "candidate stations from", uniqueN(st$cell), "cells\n")
print(table(cut(cand$elev, c(-500, 200, 500, 1000, 1500, 2000, 3000, 6000))))
