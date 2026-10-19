# Verify actual source/extract timestamps and final coverage after rebuilding the intake.
source("R/utils.R")
f <- file.path(dir_interim, "ghcnh", "annual", "ACW00011647_2026.parquet")
raw <- read_parquet(f, col_select = "DATE")$DATE
extracted <- read_parquet(file.path(dir_interim, "ghcnh", "observations", basename(f)), col_select = "date")$date
expected <- as.POSIXct(raw, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
stopifnot(!anyNA(extracted), identical(as.numeric(extracted), as.numeric(expected)),
  uniqueN(extracted) > uniqueN(as.Date(extracted)),
  identical(format(extracted[2], "%H:%M", tz = "UTC"), "01:00"))
cov <- fread(file.path(dir_interim, "ghcnh_coverage.csv"))
st <- fread(file.path(dir_interim, "ghcnh_stations_all.csv"))
stopifnot(nrow(st) > 0, uniqueN(cov, by = c("id", "year")) == nrow(cov))
chosen <- merge(st[, .(id, year = selected_year)], cov, by = c("id", "year"))
stopifnot(nrow(chosen) == nrow(st), all(chosen$days >= 183), all(chosen$n / chosen$days >= 4),
  all(cov$n <= cov$reports), all(cov$months <= 12L),
  all(cov$days <= ifelse(cov$year %% 4 == 0, 366L, 365L)))
latest <- cov[year %in% years_ghcnh & days >= 183 & n / pmax(days, 1) >= 4,
  .(year = max(year)), by = id]
stopifnot(all(st$selected_year == latest$year[match(st$id, latest$id)]))
cat("Source timestamps, distinct-hour coverage and latest qualifying years verified\n")
