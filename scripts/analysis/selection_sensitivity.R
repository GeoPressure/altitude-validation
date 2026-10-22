# Station-selection comparison using the frozen GHCNh candidate order --------
# Rscript scripts/analysis/selection_sensitivity.R       # completed full selection
# Rscript scripts/analysis/selection_sensitivity.R 64    # cached pilot verification
source("R/utils.R")
source("R/ghcnh_sampling.R")
load_geopressurer()
setDTthreads(1)
run_dir <- "data/interim/ghcnh/selection-2026-10-13"
settings <- readRDS(file.path(run_dir, "settings.rds"))
candidates <- readRDS(file.path(run_dir, "candidates.rds"))
gpt3 <- gpt3_read(1)
args <- commandArgs(trailingOnly = TRUE)
cells <- sort(unique(candidates$cell))
if (length(args)) {
  set.seed(settings$seed)
  cells <- head(sample(cells), as.integer(args[1]))
  output <- "docs/methods/ghcnh-sampling-review/pilot-selection-sensitivity.csv"
} else {
  stopifnot(file.exists(file.path(run_dir, "full-metrics.csv")),
    fread(file.path(run_dir, "full-metrics.csv"))$pending == 0)
  output <- "output/tables/paper_selection_sensitivity.csv"
}

# Both cases use only cells represented by the primary selection ------------
parts <- list()
for (cell_id in cells) {
  state <- readRDS(file.path(run_dir, "cells", paste0(cell_id, ".rds")))
  stopifnot(state$completed)
  if (is.null(state$accepted)) next
  first_covered <- state$attempts[!is.na(window_end)][1]
  for (choice in c("primary", "coverage_only")) {
    id_value <- if (choice == "primary") state$accepted$id else first_covered$id
    s <- candidates[id == id_value]
    if (id_value == state$accepted$id) {
      d <- as.data.table(read_parquet(file.path(run_dir, "accepted", paste0(id_value, ".parquet"))))
    } else {
      o <- as.data.table(read_parquet(file.path(run_dir, "pressure", paste0(id_value, ".parquet"))))
      e <- as.data.table(read_parquet(file.path(run_dir, "core", paste0(id_value, ".parquet"))))
      d <- merge(o, e, by = "date")
      d <- d[is.finite(sp_sl) & is.finite(t2m_sl) & is.finite(d2m) & is.finite(z_sl)]
      d[, err_sl := era5_altitude(pressure * 100, sp_sl, t2m_sl, z_sl) - s$elev]
      d <- d[is.finite(err_sl)]
      window <- ghcnh_window(d, settings)
      stopifnot(window$end == first_covered$window_end)
      d <- window$hours
    }
    L <- gpt3_lapse(gpt3, rep(s$lon, nrow(d)), rep(s$lat, nrow(d)), as.POSIXlt(d$date, tz = "UTC")$yday + 1)
    L <- fifelse(abs(L) < 1e-5, -1e-5, L)
    d[, err_isa := altitude_lapse(pressure * 100, 101325, 288.15, 0) - s$elev]
    d[, err_standard := err_sl]
    d[, err_virtual := altitude_lapse(pressure * 100, sp_sl, virtual_temperature(t2m_sl, d2m, sp_sl), z_sl, L) - s$elev]
    parts[[length(parts) + 1L]] <- d[, .(cell = cell_id, id = id_value, selection = choice,
      err_isa, err_standard, err_virtual, weight = 1 / .N)]
  }
}
d <- rbindlist(parts)
stopifnot(all(is.finite(d$err_isa)), all(is.finite(d$err_standard)), all(is.finite(d$err_virtual)))
results <- rbindlist(lapply(c("isa", "standard", "virtual"), function(f) {
  d[, .(formula = f, cells = uniqueN(cell), stations = uniqueN(id),
    medae = wquant(abs(get(paste0("err_", f))), weight, .5),
    p95_abs = wquant(abs(get(paste0("err_", f))), weight, .95)), by = selection]
}))
fwrite(results, output)
cli::cli_alert_success("Saved selection comparison for {uniqueN(d$cell)} represented cells to {output}")
