# Benchmark the default local window search on cached station series --------
# Run from the repository root; no production outputs are changed.
suppressPackageStartupMessages({
  library(data.table)
  library(arrow)
  library(dplyr)
  library(lubridate)
})
setDTthreads(2)
out <- "docs/methods/ghcnh-sampling-review"
previous <- fread(file.path(out, "criteria_windows.csv"))[setting == "15d_4h"]
set.seed(11)
ids <- unique(c(sample(previous$id, 50), sample(previous[is.na(end), id], 10)))
cutoff <- as.Date("2026-10-13")
start <- as.Date("2022-01-01")
ends <- seq(cutoff, start %m+% years(1), by = "-1 day")
boundaries <- sapply(0:12, function(m) as.integer(ends %m-% months(m)))
t_read <- system.time({
  a <- open_dataset("data/interim/errors_ghcnh.parquet") |>
    filter(id %in% ids, year >= 2022) |>
    select(id, date, err_sl, pressure, t2m_sl, sp_sl, d2m) |>
    collect() |>
    as.data.table()
  a <- a[is.finite(err_sl) & is.finite(pressure) & is.finite(t2m_sl) & is.finite(sp_sl) & is.finite(d2m)]
  a[, day := as.Date(date, tz = "UTC")]
  a <- a[day >= start & day < cutoff]
  setkey(a, id, date)
})
results <- list()
for (j in seq_along(ids)) {
  tested <- 0L
  chosen <- as.Date(NA)
  elapsed <- system.time({
    s <- a[.(ids[j])]
    counts <- tabulate(as.integer(s$day - start) + 1L, nbins = as.integer(cutoff - start))
    cs <- c(0, cumsum(counts >= 4))
    block <- sapply(1:12, function(m) cs[boundaries[, m] - as.integer(start) + 1L] -
      cs[boundaries[, m + 1] - as.integer(start) + 1L])
    eligible <- which(apply(block, 1, min) >= 15)
    for (i in eligible) {
      tested <- tested + 1L
      w <- s[day >= as.Date(boundaries[i, 13], origin = "1970-01-01") & day < ends[i]]
      keep <- abs(w$err_sl - median(w$err_sl)) <= max(100, 10 * mad(w$err_sl))
      clean_counts <- tabulate(as.integer(w$day[keep] - start) + 1L, nbins = length(counts))
      cs <- c(0, cumsum(clean_counts >= 4))
      if (min(cs[boundaries[i, 1:12] - as.integer(start) + 1L] - cs[boundaries[i, 2:13] - as.integer(start) + 1L]) < 15) next
      chosen <- ends[i]
      break
    }
  })[["elapsed"]]
  results[[j]] <- data.table(id = ids[j], observations = nrow(s), possible_endpoints = length(ends),
    raw_coverage_windows = length(eligible), cleaned_windows_tested = tested, end = chosen, elapsed_s = elapsed)
}
b <- rbindlist(results)
comparison <- merge(b[, .(id, end)], previous[, .(id, expected = end)], by = "id")
stopifnot(all((is.na(comparison$end) & is.na(comparison$expected)) |
  (!is.na(comparison$end) & !is.na(comparison$expected) & comparison$end == comparison$expected)))
fwrite(b, file.path(out, "implementation_benchmark_stations.csv"))
fwrite(b[, .(stations = .N, observations = sum(observations), read_elapsed_s = t_read[["elapsed"]],
  search_elapsed_s = sum(elapsed_s), median_station_search_s = median(elapsed_s),
  max_station_search_s = max(elapsed_s), cleaned_windows_tested = sum(cleaned_windows_tested),
  cached_subset_mb = as.numeric(object.size(a)) / 1024^2)], file.path(out, "implementation_benchmark.csv"))

# Small transfer probe using the existing ERA5 reader -----------------------
source("R/utils.R")
load_geopressurer()
probe <- system.time({
  e <- era5_read(rep(-61.7833, 24), rep(17.1333, 24),
    seq(as.POSIXct("2025-01-01", tz = "UTC"), by = "hour", length.out = 24),
    c("surface_pressure", "temperature_2m", "dewpoint_temperature_2m"), "single-levels")
})
stopifnot(nrow(e) == 24, all(is.finite(as.matrix(e))))
fwrite(data.table(hours = 24, variables = 3, elapsed_s = probe[["elapsed"]]),
  file.path(out, "implementation_network_probe.csv"))
message("Local benchmark and small ERA5 transfer probe complete")
