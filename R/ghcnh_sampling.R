# GHCNh sampling units used by scripts/sampling/sample_ghcnh.R ------------------------
suppressPackageStartupMessages({
  library(lubridate)
  library(sf)
})

# Commit complete cache files in their destination directory.
ghcnh_save <- function(x, path) {
  saveRDS(x, paste0(path, ".tmp"))
  readRDS(paste0(path, ".tmp"))
  stopifnot(file.rename(paste0(path, ".tmp"), path))
}

ghcnh_write <- function(d, path) {
  write_parquet(d, paste0(path, ".tmp"))
  stopifnot(identical(names(read_parquet(paste0(path, ".tmp"))), names(d)))
  stopifnot(file.rename(paste0(path, ".tmp"), path))
}

# Freeze annual availability independently of downloads.
ghcnh_catalogue <- function(year, run_dir, base) {
  path <- file.path(run_dir, "catalogue", paste0(year, ".rds"))
  if (file.exists(path)) return(readRDS(path))
  marker <- ""
  pages <- list()
  repeat {
    response <- httr2::request(paste0(base, "/")) |>
      httr2::req_url_query(prefix = sprintf("hourly/access/by-year/%d/parquet/", year),
        `max-keys` = 1000, marker = marker) |>
      httr2::req_retry(max_tries = 4) |>
      httr2::req_timeout(120) |>
      httr2::req_perform()
    doc <- xml2::xml_ns_strip(xml2::read_xml(httr2::resp_body_string(response)))
    stopifnot(xml2::xml_name(doc) == "ListBucketResult")
    entries <- xml2::xml_find_all(doc, ".//Contents")
    pages[[length(pages) + 1L]] <- data.table(
      id = sub("^.*GHCNh_([^_]+)_[0-9]{4}\\.parquet$", "\\1", xml2::xml_text(xml2::xml_find_first(entries, "Key"))),
      year = year, bytes = as.numeric(xml2::xml_text(xml2::xml_find_first(entries, "Size"))),
      modified = xml2::xml_text(xml2::xml_find_first(entries, "LastModified")))
    if (xml2::xml_text(xml2::xml_find_first(doc, ".//IsTruncated")) != "true") break
    marker <- xml2::xml_text(xml2::xml_find_first(doc, ".//NextMarker"))
    stopifnot(!is.na(marker), nzchar(marker))
  }
  result <- unique(rbindlist(pages), by = c("id", "year"))
  ghcnh_save(result, path)
  cli::cli_alert_info("Catalogue {year}: {nrow(result)} station files")
  result
}

# Prepare accepted distinct hours; current-year files belong to this run.
ghcnh_pressure <- function(s, settings, catalogue, run_dir) {
  path <- file.path(run_dir, "pressure", paste0(s$id, ".parquet"))
  if (file.exists(path)) return(as.data.table(read_parquet(path)))
  years <- catalogue[id == s$id, sort(unique(year))]
  pieces <- list()
  for (year in years) {
    annual <- file.path(if (year == max(settings$years)) file.path(run_dir, "annual") else
      "data/interim/ghcnh/annual", sprintf("%s_%d.parquet", s$id, year))
    reduced <- file.path("data/interim/ghcnh/observations", basename(annual))
    if (year < max(settings$years) && file.exists(reduced)) {
      d <- as.data.table(read_parquet(reduced))
    } else {
      if (!file.exists(annual)) {
        url <- sprintf("%s/hourly/access/by-year/%d/parquet/GHCNh_%s_%d.parquet", settings$base, year, s$id, year)
        status <- system2("curl", c("-fsSL", "--retry", "3", "--max-time", "120", "-o", shQuote(paste0(annual, ".tmp")), shQuote(url)))
        if (status != 0) stop("NOAA download failed: ", s$id, " / ", year)
        read_parquet(paste0(annual, ".tmp"), col_select = "STATION")
        stopifnot(file.rename(paste0(annual, ".tmp"), annual))
      }
      schema <- names(open_dataset(annual)$schema)
      keep <- schema[tolower(schema) %in% c("date", "station_level_pressure", "station_level_pressure_quality_code", "station_level_pressure_source_code")]
      d <- as.data.table(read_parquet(annual, col_select = tidyselect::all_of(keep)))
      setnames(d, tolower(names(d)))
    }
    if (!"station_level_pressure" %in% names(d)) next
    q <- as.character(d$station_level_pressure_quality_code)
    src <- as.character(d$station_level_pressure_source_code)
    d <- d[is.finite(station_level_pressure) & station_level_pressure > settings$pressure_min &
      station_level_pressure < settings$pressure_max & !q %in% c("2", "3", "6", "7") &
      !(q %in% "5" & src %in% c("220", "221", "222", "223", "347", "348")) & (is.na(q) | !grepl("[a-z]", q))]
    pieces[[length(pieces) + 1L]] <- d[, .(date = as.POSIXct(date, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC"),
      pressure = station_level_pressure, quality_code = as.character(station_level_pressure_quality_code),
      source_code = as.character(station_level_pressure_source_code))]
  }
  d <- if (length(pieces)) rbindlist(pieces) else data.table(date = as.POSIXct(character(), tz = "UTC"),
    pressure = double(), quality_code = character(), source_code = character())
  d[, hour := era5_hour(date)]
  d[, distance := abs(as.numeric(difftime(date, hour, units = "secs")))]
  setorder(d, hour, distance, date)
  d <- unique(d, by = "hour")
  d[, date := hour]
  d[, c("hour", "distance") := NULL]
  d <- d[date >= settings$start & date < settings$end]
  ghcnh_write(d, path)
  d
}

# Raw coverage is an upper bound on coverage after matching/outlier removal.
ghcnh_window <- function(d, settings, clean = TRUE) {
  if (!nrow(d)) return(NULL)
  days <- as.Date(d$date, tz = "UTC")
  start <- as.Date(settings$start)
  end <- as.Date(settings$end)
  ends <- seq(end, start %m+% years(1), by = "-1 day")
  bounds <- sapply(0:12, function(m) as.integer(ends %m-% months(m)))
  counts <- tabulate(as.integer(days - start) + 1L, nbins = as.integer(end - start))
  cs <- c(0, cumsum(counts >= settings$hours_per_day))
  block <- sapply(1:12, function(m) cs[bounds[, m] - as.integer(start) + 1L] - cs[bounds[, m + 1] - as.integer(start) + 1L])
  eligible <- which(apply(block, 1, min) >= settings$days_per_month)
  if (!length(eligible)) return(NULL)
  if (!clean) return(ends[eligible[1]])
  for (i in eligible) {
    w <- d[days >= as.Date(bounds[i, 13], origin = "1970-01-01") & days < ends[i]]
    outlier <- abs(w$err_sl - median(w$err_sl)) > max(settings$outlier_m, settings$outlier_mad * mad(w$err_sl))
    counts <- tabulate(as.integer(as.Date(w$date[!outlier], tz = "UTC") - start) + 1L, nbins = as.integer(end - start))
    cs <- c(0, cumsum(counts >= settings$hours_per_day))
    if (min(cs[bounds[i, 1:12] - as.integer(start) + 1L] - cs[bounds[i, 2:13] - as.integer(start) + 1L]) < settings$days_per_month) next
    return(list(start = as.Date(bounds[i, 13], origin = "1970-01-01"), end = ends[i],
      outlier_fraction = mean(outlier), bias = mean(w$err_sl[!outlier]), hours = w[!outlier],
      matched_hours = nrow(w)))
  }
  NULL
}

# Cache a full primary ERA5 series; request only missing hours.
ghcnh_core <- function(s, settings, run_dir, old_stations) {
  path <- file.path(run_dir, "core", paste0(s$id, ".parquet"))
  hours <- seq(settings$start, settings$end - 3600, by = "hour")
  if (file.exists(path)) {
    e <- as.data.table(read_parquet(path))
    stopifnot(identical(as.numeric(e$date), as.numeric(hours)))
    return(e)
  }
  old <- old_stations[id == s$id & abs(lat - s$lat) < 1e-8 & abs(lon - s$lon) < 1e-8]
  cached <- file.path("data/interim/era5", paste0("ghcnh_", s$id, ".parquet"))
  e <- data.table(date = hours)
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
  stopifnot(identical(as.numeric(e$date), as.numeric(hours)))
  ghcnh_write(e, path)
  e
}

# Required season-adjusted step check over the selected window's history.
ghcnh_step <- function(d, endpoint, settings) {
  none <- list(tested = FALSE, step = NA_real_, score = NA_real_, at = as.Date(NA), months = 0L)
  d <- d[date >= as.POSIXct(endpoint %m-% years(settings$step_years), tz = "UTC") & date < as.POSIXct(endpoint, tz = "UTC")]
  if (!nrow(d)) return(none)
  d <- d[abs(err_sl - median(err_sl)) <= max(settings$outlier_m, settings$outlier_mad * mad(err_sl))]
  d[, month := floor_date(as.Date(date, tz = "UTC"), "month")]
  m <- d[, .(error = median(err_sl), n = .N), by = month][n >= settings$step_hours][order(month)]
  none$months <- nrow(m)
  if (nrow(m) < settings$step_months || uniqueN(month(m$month)) < 12) return(none)
  season <- model.matrix(~ factor(month(m$month)))
  eligible <- which(seq_len(nrow(m)) >= settings$step_side & seq_len(nrow(m)) <= nrow(m) - settings$step_side &
    shift(m$month, type = "lead") >= endpoint %m-% years(1) & shift(m$month, type = "lead") < endpoint)
  best <- list(rss = Inf)
  for (i in eligible) {
    x <- cbind(season, step = as.numeric(seq_len(nrow(m)) > i))
    f <- lm.fit(x, m$error)
    if (f$rank < ncol(x) || nrow(x) <= ncol(x)) next
    rss <- sum(f$residuals^2)
    if (rss < best$rss) best <- list(rss = rss, x = x, step = unname(f$coefficients["step"]), at = m$month[i + 1L])
  }
  if (!is.finite(best$rss)) return(none)
  se <- sqrt(best$rss / (nrow(best$x) - ncol(best$x)) * solve(crossprod(best$x))["step", "step"])
  list(tested = TRUE, step = best$step, score = best$step / se, at = best$at, months = nrow(m))
}

# A cell is the independent unit of parallel work and checkpointing.
ghcnh_cell <- function(cell_id, candidates, settings, catalogue, run_dir, old_stations) {
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
      o <- ghcnh_pressure(s, settings, catalogue, run_dir)
      reason <- "coverage"
      w <- NULL
      step <- list(tested = FALSE, step = NA_real_, score = NA_real_, at = as.Date(NA), months = 0L)
      if (!is.null(ghcnh_window(o, settings, clean = FALSE))) {
        e <- ghcnh_core(s, settings, run_dir, old_stations)
        d <- merge(o, e, by = "date")
        d <- d[is.finite(sp_sl) & is.finite(t2m_sl) & is.finite(d2m) & is.finite(z_sl)]
        d[, err_sl := era5_altitude(pressure * 100, sp_sl, t2m_sl, z_sl) - s$elev]
        d <- d[is.finite(err_sl)]
        w <- ghcnh_window(d, settings)
        if (!is.null(w)) {
          step <- ghcnh_step(d, w$end, settings)
          reason <- if (w$outlier_fraction > settings$outlier_fraction) "outliers" else
            if (abs(w$bias) > settings$offset_m + settings$offset_slope * abs(s$elev - e$z_sl[1])) "offset" else
            if (!step$tested) "step_support" else if (abs(step$step) >= settings$step_m & abs(step$score) >= settings$step_score) "step" else "accepted"
        }
      }
      row <- data.table(id = s$id, candidate_order = i, reason = reason, seconds = proc.time()[["elapsed"]] - t0,
        pressure_hours = nrow(o), window_start = if (is.null(w)) as.Date(NA) else w$start,
        window_end = if (is.null(w)) as.Date(NA) else w$end,
        accepted_hours = if (is.null(w)) 0L else nrow(w$hours),
        outlier_fraction = if (is.null(w)) NA_real_ else w$outlier_fraction,
        bias = if (is.null(w)) NA_real_ else w$bias, step = step$step, step_score = step$score, step_at = step$at,
        step_months = step$months)
      if (reason == "accepted") {
        ghcnh_write(w$hours, file.path(run_dir, "accepted", paste0(s$id, ".parquet")))
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
