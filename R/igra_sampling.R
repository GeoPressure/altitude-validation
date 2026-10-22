# IGRA sampling units used by scripts/sampling/sample_igra.R -------------------------
# Cache commits use ghcnh_save()/ghcnh_write(); no GHCNh run files are changed.

# Download and validate one complete archive before reducing its profiles.
igra_profiles <- function(s, settings, run_dir) {
  path <- file.path(run_dir, "profiles", paste0(s$id, ".rds"))
  if (file.exists(path)) return(readRDS(path))
  zip <- file.path(run_dir, "downloads", paste0(s$id, ".zip"))
  url <- paste0(settings$base, "/access/data-por/", s$id, "-data.txt.zip")
  if (!file.exists(zip)) {
    status <- system2("curl", c("-fsSL", "--retry", "3", "--max-time", "300", "-o", shQuote(paste0(zip, ".tmp")), shQuote(url)))
    if (status != 0) stop("IGRA download failed: ", s$id)
    status <- system2("unzip", c("-tqq", shQuote(paste0(zip, ".tmp"))))
    if (status != 0) stop("IGRA ZIP integrity check failed: ", s$id)
    stopifnot(file.rename(paste0(zip, ".tmp"), zip))
  }
  bytes <- file.size(zip)
  csv <- paste0(zip, ".csv.tmp")
  awk <- paste0(zip, ".awk.tmp")
  on.exit(unlink(c(csv, awk)))
  writeLines(paste0(
    'BEGIN{OFS=","; expected=0; seen=0} ',
    'substr($0,1,1)=="#"{if(seen!=expected) exit 42; ',
    'expected=substr($0,33,4)+0; seen=0; y=substr($0,14,4)+0; ',
    'keep=(y>=', min(settings$years), ' && y<=', max(settings$years), '); ',
    'hdr=substr($0,2,11) OFS y OFS substr($0,19,2) OFS substr($0,22,2) OFS substr($0,25,2) OFS ',
    'substr($0,28,4) OFS substr($0,38,8) OFS substr($0,47,8); next} ',
    '{seen++; if(keep) print hdr, substr($0,1,1), substr($0,2,1), substr($0,4,5), ',
    'substr($0,10,6), substr($0,16,1), substr($0,17,5), substr($0,22,1), substr($0,23,5), substr($0,28,1)} ',
    'END{if(seen!=expected) exit 42}'
  ), awk)
  cmd <- sprintf("unzip -p %s | awk -f %s > %s", shQuote(zip), shQuote(awk), shQuote(csv))
  status <- system2("/bin/bash", c("-o", "pipefail", "-c", shQuote(cmd)))
  if (status != 0) stop("IGRA extraction or sounding record count failed: ", s$id)
  cols <- c("id", "year", "month", "day", "hour", "reltime", "p_source", "np_source", "lvl1", "lvl2", "etime", "press", "pflag", "gph", "zflag", "temp", "tflag")
  raw <- if (file.size(csv)) fread(csv, header = FALSE, col.names = cols,
    colClasses = list(character = c(1L, 7L, 8L, 13L, 15L, 17L))) else
    as.data.table(setNames(lapply(cols, function(x) if (x %in% c("id", "p_source", "np_source", "pflag", "zflag", "tflag")) character() else integer()), cols))
  result <- list(levels = igra_prepare(raw, s, settings), download_bytes = bytes, raw_levels = nrow(raw))
  ghcnh_save(result, path)
  unlink(zip)
  result
}

# Pair airborne levels with their own accepted surface and assign level times.
igra_prepare <- function(d, s, settings) {
  d <- unique(copy(d))[hour <= 23]
  d[, c("id", "p_source", "np_source", "pflag", "zflag", "tflag") := lapply(.SD, as.character), .SDcols = c("id", "p_source", "np_source", "pflag", "zflag", "tflag")]
  d[, nominal := as.POSIXct(sprintf("%04d-%02d-%02d %02d:00", year, month, day, hour), tz = "UTC")]
  d[, sounding := sprintf("%04d%02d%02d%02d_%04d", year, month, day, hour, reltime)]
  rel <- (d$reltime %/% 100) + fifelse(d$reltime %% 100 == 99, 0, d$reltime %% 100) / 60
  d[, launch := nominal + fifelse(reltime == 9999, 0, ((rel - hour + 12) %% 24) - 12) * 3600]
  d <- d[launch >= settings$start & launch < settings$end]
  surface <- d[lvl2 == 1 & press > 0 & (gph > -8000 | gph == -9999),
    .(press_s = press[1], gph_s = fifelse(gph[1] == -9999, s$elev, as.numeric(gph[1])),
      date_s = era5_hour(launch[1])), by = sounding]
  d <- merge(d[lvl2 != 1 & press > 0 & gph > -8000 & etime != -8888], surface, by = "sounding")
  d[, agl := gph - gph_s]
  d <- d[agl > 0 & agl <= settings$max_agl]
  d[, elapsed := fifelse(etime == -9999, agl / settings$ascent_m_s, (etime %/% 100) * 60 + etime %% 100)]
  d[, level_time := launch + elapsed]
  d[, date := era5_hour(level_time)]
  d <- d[level_time >= settings$start & level_time < settings$end & date >= settings$start & date < settings$end & date_s >= settings$start & date_s < settings$end]
  d[, band := as.character(cut(agl, settings$height_breaks))]
  setorder(d, launch, elapsed, -press)
  d[]
}

# Read just the distinct hours required by the candidate's prepared profiles.
igra_core <- function(s, dates, run_dir, old_stations) {
  path <- file.path(run_dir, "core", paste0(s$id, ".parquet"))
  if (file.exists(path)) return(as.data.table(read_parquet(path)))
  e <- data.table(date = sort(unique(dates)))
  old <- old_stations[id == s$id & abs(lat - s$lat) < 1e-8 & abs(lon - s$lon) < 1e-8]
  cached <- file.path("data/interim/era5", paste0("igra_", s$id, ".parquet"))
  if (nrow(old) && file.exists(cached)) {
    previous <- as.data.table(read_parquet(cached, col_select = c("date", "sp_sl", "t2m_sl", "d2m")))
    e <- merge(e, previous, by = "date", all.x = TRUE)
  } else e[, `:=`(sp_sl = NA_real_, t2m_sl = NA_real_, d2m = NA_real_)]
  missing <- which(!is.finite(e$sp_sl) | !is.finite(e$t2m_sl) | !is.finite(e$d2m))
  for (attempt in 1:3) {
    result <- tryCatch({
      if (length(missing)) {
        values <- era5_read(rep(s$lon, length(missing)), rep(s$lat, length(missing)), e$date[missing],
          c("surface_pressure", "temperature_2m", "dewpoint_temperature_2m"), "single-levels")
        e[missing, `:=`(sp_sl = values$surface_pressure, t2m_sl = values$temperature_2m, d2m = values$dewpoint_temperature_2m)]
      }
      e[, z_sl := if (nrow(old) && is.finite(old$z_sl[1])) old$z_sl[1] else era5_orography(s$lon, s$lat, "single-levels")]
      TRUE
    }, error = identity)
    if (isTRUE(result)) break
    if (attempt == 3) stop(result)
    Sys.sleep(attempt)
  }
  ghcnh_write(e, path)
  e
}

# All conversions share paired finite atmospheric and height inputs.
igra_match <- function(o, e, s, gpt3) {
  d <- merge(o, e, by = "date")
  surface <- copy(e)
  setnames(surface, names(surface), c("date_s", "sp_s", "t2m_s", "d2m_s", "z_s"))
  d <- merge(d, surface, by = "date_s")
  d <- d[is.finite(sp_sl) & is.finite(t2m_sl) & is.finite(d2m) & is.finite(z_sl) &
    is.finite(sp_s) & is.finite(t2m_s) & is.finite(d2m_s) & is.finite(z_s)]
  d[, err_standard := (era5_altitude(press, sp_sl, t2m_sl, z_sl) - era5_altitude(press_s, sp_s, t2m_s, z_s)) - agl]
  d[, err_isa := (altitude_lapse(press, 101325, 288.15, 0) - altitude_lapse(press_s, 101325, 288.15, 0)) - agl]
  L <- gpt3_lapse(gpt3, rep(s$lon, nrow(d)), rep(s$lat, nrow(d)), as.POSIXlt(d$level_time, tz = "UTC")$yday + 1)
  L_s <- gpt3_lapse(gpt3, rep(s$lon, nrow(d)), rep(s$lat, nrow(d)), as.POSIXlt(d$launch, tz = "UTC")$yday + 1)
  L <- fifelse(abs(L) < 1e-5, -1e-5, L)
  L_s <- fifelse(abs(L_s) < 1e-5, -1e-5, L_s)
  d[, err_virtual := (altitude_lapse(press, sp_sl, virtual_temperature(t2m_sl, d2m, sp_sl), z_sl, L) -
    altitude_lapse(press_s, sp_s, virtual_temperature(t2m_s, d2m_s, sp_s), z_s, L_s)) - agl]
  d[is.finite(err_isa) & is.finite(err_standard) & is.finite(err_virtual)]
}

# Coverage counts launch dates after the candidate-local outlier exclusion.
igra_window <- function(d, settings, clean = TRUE) {
  if (!nrow(d)) return(NULL)
  days <- as.Date(d$launch, tz = "UTC")
  start <- as.Date(settings$start)
  end <- as.Date(settings$end)
  ends <- seq(end, start %m+% years(1), by = "-1 day")
  bounds <- sapply(0:12, function(m) as.integer(ends %m-% months(m)))
  counts <- tabulate(as.integer(unique(days) - start) + 1L, nbins = as.integer(end - start))
  cs <- c(0, cumsum(counts > 0))
  block <- sapply(1:12, function(m) cs[bounds[, m] - as.integer(start) + 1L] - cs[bounds[, m + 1] - as.integer(start) + 1L])
  eligible <- which(apply(block, 1, min) >= settings$days_per_month)
  if (!length(eligible)) return(NULL)
  if (!clean) return(ends[eligible[1]])
  for (i in eligible) {
    w <- copy(d[days >= as.Date(bounds[i, 13], origin = "1970-01-01") & days < ends[i]])
    w[, outlier := abs(err_standard - median(err_standard)) > max(settings$outlier_m, settings$outlier_mad * mad(err_standard)), by = band]
    fraction <- mean(w$outlier)
    matched <- nrow(w)
    w <- w[outlier == FALSE]
    counts <- tabulate(as.integer(unique(as.Date(w$launch, tz = "UTC")) - start) + 1L, nbins = as.integer(end - start))
    cs <- c(0, cumsum(counts > 0))
    support <- cs[bounds[i, 1:12] - as.integer(start) + 1L] - cs[bounds[i, 2:13] - as.integer(start) + 1L]
    if (min(support) < settings$days_per_month) next
    w[, outlier := NULL]
    w[, weight := 1 / .N, by = band]
    return(list(start = as.Date(bounds[i, 13], origin = "1970-01-01"), end = ends[i], levels = w,
      matched_levels = matched, outlier_fraction = fraction, min_month_days = min(support)))
  }
  NULL
}

# A scientific rejection advances; a technical failure preserves the candidate.
igra_cell <- function(cell_id, candidates, settings, run_dir, old_stations, gpt3) {
  path <- file.path(run_dir, "cells", paste0(cell_id, ".rds"))
  state <- if (file.exists(path)) readRDS(path) else list(cell = cell_id, next_candidate = 1L,
    completed = FALSE, attempts = data.table(), accepted = NULL, pending = NULL)
  if (state$completed) return(state)
  group <- candidates[cell == cell_id][order(candidate_order)]
  for (i in seq.int(state$next_candidate, nrow(group))) {
    s <- group[i]
    before <- state
    t0 <- proc.time()[["elapsed"]]
    result <- tryCatch({
      profiles <- igra_profiles(s, settings, run_dir)
      o <- profiles$levels
      w <- NULL
      if (!is.null(igra_window(o, settings, clean = FALSE))) {
        e <- igra_core(s, c(o$date, o$date_s), run_dir, old_stations)
        d <- igra_match(o, e, s, gpt3)
        w <- igra_window(d, settings)
      }
      row <- data.table(id = s$id, candidate_order = i, reason = if (is.null(w)) "coverage" else "accepted",
        seconds = proc.time()[["elapsed"]] - t0, download_bytes = profiles$download_bytes,
        raw_levels = profiles$raw_levels, prepared_levels = nrow(o),
        window_start = if (is.null(w)) as.Date(NA) else w$start,
        window_end = if (is.null(w)) as.Date(NA) else w$end,
        accepted_levels = if (is.null(w)) 0L else nrow(w$levels),
        accepted_soundings = if (is.null(w)) 0L else uniqueN(w$levels$sounding),
        min_month_days = if (is.null(w)) NA_integer_ else w$min_month_days,
        outlier_fraction = if (is.null(w)) NA_real_ else w$outlier_fraction)
      if (!is.null(w)) {
        ghcnh_write(w$levels, file.path(run_dir, "accepted", paste0(s$id, ".parquet")))
        state$accepted <- cbind(s, row[, !c("id", "candidate_order")])
        state$completed <- TRUE
      }
      state$attempts <- rbind(state$attempts, row)
      state$next_candidate <- i + 1L
      state$pending <- NULL
      if (i == nrow(group)) state$completed <- TRUE
      ghcnh_save(state, path)
      TRUE
    }, error = identity)
    if (inherits(result, "error")) {
      state <- before
      state$pending <- list(id = s$id, message = conditionMessage(result))
      ghcnh_save(state, path)
      cli::cli_alert_warning("Cell {cell_id}: pending at {s$id}: {conditionMessage(result)}")
      break
    }
    if (state$completed) break
  }
  cli::cli_alert_info("Cell {cell_id}: {nrow(state$attempts)} assessed; {if (!is.null(state$accepted)) 'accepted' else if (state$completed) 'empty' else 'pending'}")
  state
}
