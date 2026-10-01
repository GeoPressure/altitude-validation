# Select IGRA2 radiosonde stations and extract their soundings for `years_sonde`.
#
# IGRA2 period-of-record files are large (tens of MB zipped), so each one is streamed through
# funzip and awk, which keep only the study years and levels at or below 400 hPa (~7 km) plus the
# surface level. One parquet file per station.
#
# All stations active over the study years are downloaded. Those with at least 100 soundings are
# then thinned with the same rule as the surface stations (03_hadisd_thin.R): one random station
# per 2 x 2 degree cell, plus every station above 1000 m.

source("R/utils.R")
set.seed(1)

f <- file.path(dir_raw, "igra2-station-list.txt")
if (!file.exists(f)) {
  curl_download(
    "https://www.ncei.noaa.gov/data/integrated-global-radiosonde-archive/doc/igra2-station-list.txt",
    f
  )
}
x <- readLines(f)
st <- data.table(
  id = substr(x, 1, 11),
  lat = as.numeric(substr(x, 13, 20)),
  lon = as.numeric(substr(x, 22, 30)),
  elev = as.numeric(substr(x, 32, 37)),
  name = trimws(substr(x, 42, 71)),
  first = as.integer(substr(x, 73, 76)),
  last = as.integer(substr(x, 78, 81)),
  nobs = as.integer(substr(x, 83, 88))
)
st <- st[first <= min(years_sonde) - 1 & last >= max(years_sonde) + 1 & elev > -900]
cand <- st
fwrite(cand, file.path(dir_interim, "igra_candidates.csv"))
cat(nrow(cand), "IGRA candidate stations\n")

out_dir <- file.path(dir_interim, "igra")
dir.create(out_dir, showWarnings = FALSE)

awk_prog <- paste0(
  'BEGIN{OFS=","} ',
  'substr($0,1,1)=="#"{',
  'y=substr($0,14,4); keep=(', paste0('y=="', years_sonde, '"', collapse = "||"), '); ',
  'hdr=substr($0,2,11) OFS y OFS substr($0,19,2) OFS substr($0,22,2) OFS substr($0,25,2) OFS ',
  'substr($0,28,4) OFS substr($0,56,7) OFS substr($0,64,8); next} ',
  'keep{p=substr($0,10,6)+0; t2=substr($0,2,1); ',
  'if(p>=40000 || t2=="1") print hdr, substr($0,1,1), t2, substr($0,4,5), p, substr($0,16,1), ',
  'substr($0,17,5), substr($0,22,1), substr($0,23,5), substr($0,28,1)}'
)
cols <- c(
  "id", "year", "month", "day", "hour", "reltime", "lat", "lon",
  "lvl1", "lvl2", "etime", "press", "pflag", "gph", "zflag", "temp", "tflag"
)

extract_sonde <- function(id) {
  out <- file.path(out_dir, paste0(id, ".parquet"))
  if (file.exists(out)) return(TRUE)
  url <- sprintf(
    "https://www.ncei.noaa.gov/data/integrated-global-radiosonde-archive/access/data-por/%s-data.txt.zip",
    id
  )
  csv <- tempfile(fileext = ".csv")
  on.exit(unlink(csv))
  awk_file <- tempfile(fileext = ".awk")
  writeLines(awk_prog, awk_file)
  cmd <- sprintf("curl -sfL --retry 3 %s | funzip | awk -f %s > %s", shQuote(url), awk_file, csv)
  status <- system(cmd)
  if (status != 0 || !file.exists(csv)) stop("stream failed: ", status)
  d <- if (file.size(csv) > 0) {
    fread(csv, header = FALSE, col.names = cols, colClasses = list(character = c(1, 6, 13, 15, 17)))
  } else {
    data.table()
  }
  write_parquet(d, out)
  TRUE
}

# At most 3 parallel streams: the NCEI server throttles more.
res <- par_map(cand$id, extract_sonde, cores = min(n_cores, 3),
  export = c("out_dir", "awk_prog", "cols"))
check_failures(res, cand$id, "stations")

n_sound <- vapply(cand$id, function(i) {
  f <- file.path(out_dir, paste0(i, ".parquet"))
  if (!file.exists(f)) return(0L)
  d <- read_parquet(f)
  if (nrow(d) == 0) 0L else nrow(unique(d[, c("year", "month", "day", "hour")]))
}, integer(1))
cand[, n_soundings := n_sound]
fwrite(cand, file.path(dir_interim, "igra_candidates.csv"))
sel <- thin_stations(cand[n_soundings >= 100])
fwrite(sel, file.path(dir_interim, "igra_stations.csv"))
cat(nrow(sel), "radiosonde stations kept of", sum(cand$n_soundings >= 100), "with >= 100 soundings\n")
