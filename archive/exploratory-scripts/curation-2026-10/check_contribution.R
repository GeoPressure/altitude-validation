# How many stations each pressure-series (step 4) and reference (step 5) check decides, by disabling one check at a time.
source("R/utils.R")
source("R/ghcnh_sampling.R")
source("R/ghcnh_pressure_patterns.R")
source("R/ghcnh_terrain.R")
source("R/ghcnh_consistency.R")
load_geopressurer()
setDTthreads(1)
cores <- max(1L, parallel::detectCores() - 2L)
run_dir <- "data/interim/ghcnh/selection-2026-10-13"
out <- "output/drafts/check-contribution"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
settings <- readRDS(file.path(run_dir, "settings.rds"))
candidates <- as.data.table(readRDS(file.path(run_dir, "candidates.rds")))
catalogue <- rbindlist(lapply(list.files(file.path(run_dir, "catalogue"), full.names = TRUE), readRDS))
exclusions <- fread("docs/methods/ghcnh_reference_exclusions.csv")
review_exclusions <- fread("docs/methods/ghcnh_review_exclusions.csv")
terrain <- fread("output/drafts/atmospheric-figures/ground_terrain_candidates.csv")
attempts <- fread("output/drafts/atmospheric-figures/ground_terrain_window_attempts.csv")
calendar <- ghcnh_pressure_calendar(settings)

series_checks <- c("jump", "step", "noise", "irregularity", "frozen")
reference_checks <- c("gross", "full_record", "unverifiable", "month", "day", "timestamp")
variants <- c(list(baseline = character()), setNames(as.list(c(series_checks, reference_checks, "review")), c(series_checks, reference_checks, "review")),
  list(all_series = series_checks, all_reference = reference_checks, all_series_reference = c(series_checks, reference_checks)))
# Candidate simplified rule sets: drop checks that decide few or no stations.
if (Sys.getenv("VARIANTS") == "simplified") {
  minor <- c("step", "noise", "frozen", "gross", "month", "day")
  variants <- list(baseline = character(), minor = minor, minor_irregularity_timestamp = c(minor, "irregularity", "timestamp"),
    no_series_minor = c(minor, series_checks, "timestamp"))
  out <- file.path(out, "simplified")
  dir.create(out, showWarnings = FALSE)
}

# ghcnh_consistency with individual rules switched off.
consistency_off <- function(x, s, bounds = NULL, off = character(), rules = consistency_rules) {
  r <- ghcnh_consistency(x, s, bounds, rules)
  if (is.null(bounds)) return(r$reason == "reference_height" && !"full_record" %in% off)
  tolerance <- c(altimeter = rules$height_m, sea_level_pressure = rules$height_m + rules$slp_height_fraction * max(s$elev, 0))
  h_slp <- x$h_slp[is.finite(x$h_slp)]
  slp_usable <- length(h_slp) >= rules$min_reports && abs(median(h_slp) - s$elev) < rules$slp_max_offset_m && IQR(h_slp) < tolerance[["sea_level_pressure"]]
  interval <- 13L - findInterval(as.numeric(as.Date(x$date, tz = "UTC")), sort(bounds))
  months <- data.table(interval, h_alt = x$h_alt, h_slp = x$h_slp)[, .(n_alt = sum(is.finite(h_alt)), alt = median(h_alt, na.rm = TRUE),
    n_slp = sum(is.finite(h_slp)), slp = median(h_slp, na.rm = TRUE)), by = interval][data.table(interval = 1:12), on = "interval"]
  months[, source := fifelse((n_alt >= rules$month_reports) %in% TRUE, "altimeter",
    fifelse(slp_usable & (n_slp >= rules$month_reports) %in% TRUE, "sea_level_pressure", "none"))]
  months[, excess := abs(fifelse(source == "altimeter", alt, slp) - s$elev) - tolerance[source]]
  limit <- fifelse(is.finite(x$h_alt), tolerance[["altimeter"]], tolerance[["sea_level_pressure"]])
  h <- fifelse(is.finite(x$h_alt), x$h_alt, if (slp_usable) x$h_slp else NA_real_) - s$elev
  days <- data.table(day = as.Date(x$date, tz = "UTC"), h, limit)[is.finite(h), .(h = median(h), limit = median(limit)), by = day]
  fails <- c(gross = isTRUE(abs(r$isa_offset) > rules$isa_m),
    unverifiable = any(months$source == "none"),
    month = any(months$excess > 0, na.rm = TRUE),
    day = any(abs(days$h) > rules$day_factor * days$limit),
    timestamp = is.finite(r$tide_amplitude) && r$tide_amplitude > rules$tide_amplitude_hpa && abs(r$tide_lag) > rules$tide_lag_h)
  failed <- setdiff(names(fails)[fails], off)
  list(pass = !length(failed), reason = if (length(failed)) failed[1] else "accepted")
}

# One cell under every variant; disabling a check can only accept an earlier candidate, so cached data suffice.
assess_cell <- function(cell_id) {
  ids <- attempts[cell == cell_id]$id
  prep <- list()
  rbindlist(lapply(names(variants), function(v) {
    off <- variants[[v]]
    for (id_value in ids) {
      if (id_value %in% exclusions$id || (id_value %in% review_exclusions$id && !"review" %in% off)) next
      if (!isTRUE(terrain[id == id_value]$terrain_ok)) next
      s <- candidates[id == id_value]
      if (is.null(prep[[id_value]])) {
        o <- ghcnh_pressure_spikes(ghcnh_pressure(s, settings, catalogue, run_dir))
        prep[[id_value]] <<- list(o = o, episodes = rbind(ghcnh_pressure_episodes(o), ghcnh_pressure_patterns(o)$episodes),
          x = ghcnh_consistency_inputs(o, ghcnh_reference(s, settings, catalogue, run_dir), s))
      }
      p <- prep[[id_value]]
      if (consistency_off(p$x, s, off = off)) next
      w <- ghcnh_pressure_window(p$o, settings, calendar = calendar, episodes = p$episodes[!reason %in% off],
        check = function(rows, bounds) consistency_off(p$x[rows], s, bounds, off))
      if (!is.null(w$hours)) return(data.table(variant = v, cell = cell_id, id = id_value, start = w$start, end = w$end))
    }
    data.table(variant = v, cell = cell_id, id = NA_character_, start = as.Date(NA), end = as.Date(NA))
  }))
}
cells <- sort(unique(attempts$cell))
if (nzchar(Sys.getenv("N_CELLS"))) cells <- head(cells, as.integer(Sys.getenv("N_CELLS")))
sel <- rbindlist(parallel::mclapply(cells, function(cell_id) tryCatch(assess_cell(cell_id),
  error = function(e) data.table(variant = "error", cell = cell_id, id = conditionMessage(e))), mc.cores = cores, mc.preschedule = FALSE), fill = TRUE)
stopifnot(!any(sel$variant == "error"))
fwrite(sel, file.path(out, "variant_selection.csv"))

# ERA5 standard-conversion error of each newly entering station, from cached ERA5 series only.
base <- sel[variant == "baseline"]
cli::cli_alert_info("Baseline reproduces the selection: {setequal(base[!is.na(id)]$id, fread('data/interim/ghcnh/selection-curated-2026-10-22/full-accepted.csv')$id)}")
new <- unique(merge(sel[variant != "baseline" & !is.na(id)], base[, .(cell, base_id = id)], by = "cell")[is.na(base_id) | id != base_id, .(id, start, end)])
err <- rbindlist(parallel::mclapply(seq_len(nrow(new)), function(i) {
  n <- new[i]
  path <- file.path(run_dir, "core", paste0(n$id, ".parquet"))
  if (!file.exists(path)) return(NULL)
  s <- candidates[id == n$id]
  o <- ghcnh_pressure_spikes(ghcnh_pressure(s, settings, catalogue, run_dir))[date >= as.POSIXct(n$start, tz = "UTC") & date < as.POSIXct(n$end, tz = "UTC")]
  d <- merge(o, as.data.table(read_parquet(path)), by = "date")[is.finite(sp_sl) & is.finite(t2m_sl)]
  d[, err := era5_altitude(pressure * 100, sp_sl, t2m_sl, z_sl) - s$elev]
  data.table(id = n$id, start = n$start, bias = mean(d$err), sd = sd(d$err))
}, mc.cores = cores))
fwrite(err, file.path(out, "entering_errors.csv"))

summary <- rbindlist(lapply(setdiff(names(variants), "baseline"), function(v) {
  m <- merge(sel[variant == v, .(cell, id, start)], base[, .(cell, base_id = id)], by = "cell")
  entering <- merge(m[!is.na(id) & (is.na(base_id) | id != base_id)], err, by = c("id", "start"), all.x = TRUE)
  data.table(variant = v, stations = sum(!is.na(m$id)), cells_changed = sum(!is.na(m$id) & (is.na(m$base_id) | m$id != m$base_id)),
    new_cells = sum(!is.na(m$id) & is.na(m$base_id)), era5_known = sum(is.finite(entering$bias)),
    bias_gt20 = sum(abs(entering$bias) > 20, na.rm = TRUE), bias_gt50 = sum(abs(entering$bias) > 50, na.rm = TRUE),
    sd_gt20 = sum(entering$sd > 20, na.rm = TRUE))
}))
fwrite(summary, file.path(out, "check_contribution.csv"))
print(summary)
