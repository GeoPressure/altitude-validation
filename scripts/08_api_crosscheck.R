# Cross-check: GeoPressureAPI (Earth Engine) vs the ARCO path used throughout this study.
#
# For a random subset of Tier A stations, one week of observed station pressure is sent to
# GeoPressureAPI's pressurePath endpoint (dataset = "single-levels") and the returned altitude is
# compared with the altitude this pipeline computed from ARCO. Agreement means every result here
# holds for both entry points of GeoPressureR.

source("R/utils.R")
set.seed(2)

A <- as.data.table(read_parquet(file.path(dir_interim, "errors_A.parquet")))
st <- fread(file.path(dir_tables, "stations.csv"))[tier == "A"]
ids <- sample(unique(A$id), 25)
week <- c(as.POSIXct("2023-07-10", tz = "UTC"), as.POSIXct("2023-07-17", tz = "UTC"))

out <- rbindlist(lapply(ids, function(i) {
  d <- A[id == i & date >= week[1] & date < week[2] & !gross]
  if (nrow(d) == 0) return(NULL)
  s <- st[id == i]
  body <- list(
    lon = rep(s$lon, nrow(d)),
    lat = rep(s$lat, nrow(d)),
    time = as.numeric(d$date),
    variable = list("surface_pressure"),
    dataset = "single-levels",
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
fwrite(out, file.path(dir_tables, "api_crosscheck.csv"))
summ <- out[, .(stations = uniqueN(id), n = .N, mean_diff = mean(diff), mad_diff = mean(abs(diff)),
  max_abs_diff = max(abs(diff)))]
fwrite(summ, file.path(dir_tables, "api_crosscheck_summary.csv"))
print(summ)
