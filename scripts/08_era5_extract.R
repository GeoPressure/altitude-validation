# Read hourly ERA5 at every HadISD and IGRA2 station from the ECMWF ARCO archive.
#
# For each station and each year it has data, the full hourly series is read (a whole ARCO chunk is
# downloaded anyway, so asking for every hour costs nothing extra and lets later steps compute
# tendencies). Stations are grouped by ARCO single-levels chunk block (4 x 4 cells = 1 x 1 deg) so a
# chunk shared by neighbouring stations is only downloaded once.
#
#   single-levels, all years : surface_pressure, temperature_2m
#   single-levels, main years: skin_temperature, boundary_layer_height
#                              (+ dewpoint_temperature_2m for IGRA2), as covariates
#   land, main years         : surface_pressure, temperature_2m
#
# Historical years (`years_era`) are only read for a random subset of up to 100 HadISD stations
# that report in all of them -- enough to test for a change in accuracy over time, at a fraction of
# the download volume (every ARCO chunk is ~2 MB and the full run reads tens of thousands).

source("R/utils.R")
load_geopressurer()

var_alt <- c("surface_pressure", "temperature_2m")
var_cov <- c("skin_temperature", "boundary_layer_height")
short <- c(
  surface_pressure = "sp", temperature_2m = "t2m", dewpoint_temperature_2m = "d2m",
  skin_temperature = "skt", boundary_layer_height = "blh"
)

st <- fread(file.path(dir_tables, "stations.csv"))
cov <- fread(file.path(dir_interim, "hadisd_coverage.csv"))
set.seed(4)
era_ok <- cov[year %in% years_era & days >= 183, .N, by = id][N == length(years_era), id]
era_ok <- intersect(era_ok, st[network == "hadisd", id])
era_ids <- if (length(era_ok) > 100) sample(era_ok, 100) else era_ok
yearsA <- cov[days >= 30 & (year %in% years_main | id %in% era_ids), .(years = list(sort(year))),
  by = id]
st[network == "igra", years := list(list(years_sonde))]
st[yearsA, on = "id", years := i.years]
st <- st[lengths(years) > 0]

g <- era5_snap(st$lon, st$lat, "single-levels")
st[, block := paste(network, (round((g$lat + 90) * 4)) %/% 4, (round((g$lon + 180) * 4)) %/% 4)]

out_dir <- file.path(dir_interim, "era5")
dir.create(out_dir, showWarnings = FALSE)
st[, out := file.path(out_dir, paste0(network, "_", id, ".parquet"))]

hours_of <- function(years) {
  do.call(c, lapply(years, function(y) {
    seq(as.POSIXct(sprintf("%d-01-01", y), tz = "UTC"),
      as.POSIXct(sprintf("%d-12-31 23:00", y), tz = "UTC"),
      by = "hour"
    )
  }))
}

extract_block <- function(b) {
  s <- st[block == b & !file.exists(out)]
  if (nrow(s) == 0) return(TRUE)
  pts <- rbindlist(lapply(seq_len(nrow(s)), function(i) {
    data.table(k = i, lon = s$lon[i], lat = s$lat[i],
      date = hours_of(s$years[[i]]))
  }))
  pts[, main := as.integer(format(date, "%Y")) %in% c(years_main, years_sonde)]

  a <- era5_read(pts$lon, pts$lat, pts$date, var_alt, "single-levels")
  setnames(a, short[names(a)])
  setnames(a, paste0(names(a), "_sl"))
  m <- pts[, which(main)]
  vc <- c(var_cov, if (s$network[1] == "igra") "dewpoint_temperature_2m")
  cv <- era5_read(pts$lon[m], pts$lat[m], pts$date[m], vc, "single-levels")
  setnames(cv, short[names(cv)])
  res <- cbind(pts[, .(k, date)], a)
  for (v in names(cv)) {
    set(res, j = v, value = NA_real_)
    set(res, i = m, j = v, value = cv[[v]])
  }
  l <- era5_read(pts$lon[m], pts$lat[m], pts$date[m], var_alt, "land")
  setnames(l, paste0(short[names(l)], "_land"))
  for (v in names(l)) {
    set(res, j = v, value = NA_real_)
    set(res, i = m, j = v, value = l[[v]])
  }
  for (i in seq_len(nrow(s))) {
    write_parquet(res[k == i, !"k"], s$out[i])
  }
  TRUE
}

fwrite(data.table(id = era_ids), file.path(dir_interim, "era_ids.csv"))
blocks <- unique(st[!file.exists(out)]$block)
cat(length(blocks), "blocks,", nrow(st[!file.exists(out)]), "stations to extract\n")
t0 <- Sys.time()
res <- par_map(blocks, extract_block, cores = n_cores, geopressurer = TRUE,
  export = c("st", "var_alt", "var_cov", "short", "hours_of"))
cat("Extraction took", format(Sys.time() - t0), "\n")
# Every station needs its ERA5 series: stop if a block failed, so that a rerun fetches it.
check_failures(res, blocks, "blocks", fatal = TRUE)
