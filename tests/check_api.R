# Cross-check (network): GeoPressureAPI (Earth Engine) vs the ARCO path used throughout this study.
#
# For a random subset of GHCNh stations, one week of observed station pressure is sent to
# GeoPressureAPI's pressurePath endpoint (dataset = "single-levels", altitudeFormula = "standard",
# the formula evaluated here) and the returned altitude is
# compared with the altitude this pipeline computed from ARCO. Agreement means every result here
# holds for both entry points of GeoPressureR.

source("R/utils.R")
set.seed(2)

A <- as.data.table(read_parquet(file.path(dir_derived, "errors_ghcnh.parquet")))
st <- fread(file.path(dir_tables, "stations.csv"))[network == "ghcnh"]
ids <- sample(unique(A$id), 25)

out <- rbindlist(lapply(ids, function(i) {
  s <- st[id == i]
  week <- as.POSIXct(as.character(s$window_start + 90), tz = "UTC")
  week <- c(week, week + 7 * 24 * 60 * 60)
  d <- A[id == i & date >= week[1] & date < week[2]]
  if (nrow(d) == 0) return(NULL)
  body <- list(
    lon = rep(s$lon, nrow(d)),
    lat = rep(s$lat, nrow(d)),
    time = as.numeric(d$date),
    variable = list("surface_pressure"),
    dataset = "single-levels",
    altitudeFormula = "standard",
    pressure = d$pressure * 100,
    workers = 1
  )
  r <- tryCatch(
    httr2::request("https://glp.mgravey.com/GeoPressure/v2/pressurePath/") |>
      httr2::req_body_json(body, digits = 7, auto_unbox = TRUE) |>
      httr2::req_timeout(300) |>
      httr2::req_perform() |>
      httr2::resp_body_json(simplifyVector = TRUE),
    error = function(e) {
      message(i, ": ", conditionMessage(e))
      NULL
    }
  )
  if (is.null(r) || is.null(r$data$altitude)) return(NULL)
  api <- data.table(date = as.POSIXct(r$data$time, origin = "1970-01-01", tz = "UTC"),
    alt_api = unlist(r$data$altitude))
  d <- merge(d[, .(id, date, alt_arco = err_sl + s$elev)], api, by = "date")
  d
}))

out[, diff := alt_api - alt_arco]
summ <- out[, .(stations = uniqueN(id), n = .N, mean_diff = mean(diff), mad_diff = mean(abs(diff)),
  max_abs_diff = max(abs(diff)))]
print(summ)
