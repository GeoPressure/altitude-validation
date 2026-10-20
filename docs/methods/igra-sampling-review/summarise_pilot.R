# Measured per-cell resources and rough full-selection projection.
library(data.table)
setDTthreads(1)
set.seed(11)
run_dir <- "data/interim/igra-selection-2026-10-13"
out <- "docs/methods/igra-sampling-review"
a <- fread(file.path(run_dir, "pilot-16-attempts.csv"))
m <- fread(file.path(run_dir, "pilot-16-metrics.csv"))
resources <- a[, .(attempts = .N, seconds = sum(seconds), download_bytes = sum(download_bytes), accepted = sum(reason == "accepted")), by = cell]
resources[, cache_bytes := vapply(cell, function(key) {
  ids <- a[cell == key, id]
  files <- c(file.path(run_dir, "cells", paste0(key, ".rds")),
    file.path(run_dir, "profiles", paste0(ids, ".rds")), file.path(run_dir, "core", paste0(ids, ".parquet")),
    file.path(run_dir, "accepted", paste0(ids, ".parquet")))
  sum(file.size(files), na.rm = TRUE)
}, numeric(1))]
fwrite(resources, file.path(out, "pilot-resources-by-cell.csv"))
# Candidate processing time includes network and extraction, not socket startup.
boots <- replicate(2000, colMeans(as.matrix(resources[sample(.N, replace = TRUE), .(attempts, seconds, download_bytes, cache_bytes, accepted)])))
projection <- data.table(metric = c("attempted_stations", "wall_hours_three_workers", "download_gib", "stored_gib", "accepted_stations"),
  estimate = colMeans(resources[, .(attempts, seconds, download_bytes, cache_bytes, accepted)]) * m$cells_total / c(1, 3*3600, 1024^3, 1024^3, 1),
  lower = apply(boots, 1, quantile, .025) * m$cells_total / c(1, 3*3600, 1024^3, 1024^3, 1),
  upper = apply(boots, 1, quantile, .975) * m$cells_total / c(1, 3*3600, 1024^3, 1024^3, 1))
fwrite(projection, file.path(out, "pilot-projection.csv"))
print(m)
print(projection)
