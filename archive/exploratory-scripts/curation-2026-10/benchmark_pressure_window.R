source("R/utils.R")
source("R/ghcnh_sampling.R")
setDTthreads(1)
run_dir <- "data/interim/ghcnh/selection-2026-10-13"
settings <- readRDS(file.path(run_dir, "settings.rds"))
trial <- fread("output/drafts/atmospheric-figures/pressure_window_trial.csv")
calendar <- ghcnh_pressure_calendar(settings)
reading <- system.time({
  records <- lapply(trial$id, function(id) as.data.table(read_parquet(file.path(run_dir, "pressure", paste0(id, ".parquet")))))
})[["elapsed"]]

# Compare identical searches with and without reusing calendar boundaries.
timings <- list()
for (iteration in 1:3) {
  uncached <- system.time({
    ends_uncached <- lapply(records, function(d) ghcnh_pressure_window(d, settings)$end)
  })[["elapsed"]]
  cached <- system.time({
    ends_cached <- lapply(records, function(d) ghcnh_pressure_window(d, settings, calendar = calendar)$end)
  })[["elapsed"]]
  stopifnot(identical(ends_cached, ends_uncached), isTRUE(all.equal(as.Date(unlist(ends_cached), origin = "1970-01-01"), as.Date(trial$end_after))))
  timings[[iteration]] <- data.table(iteration, stations = nrow(trial), records = sum(vapply(records, nrow, integer(1))),
    read_seconds = reading, uncached_seconds = uncached, cached_seconds = cached)
}
result <- rbindlist(timings)
fwrite(result, "output/drafts/atmospheric-figures/pressure_window_benchmark.csv")
print(result)
