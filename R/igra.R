# IGRA2 sounding candidates: profile intake, consistency checks and station-year selection.
# Cache files are committed with ghcnh_save() and ghcnh_write() from R/ghcnh.R.

# Download and validate one complete archive before reducing its profiles.
igra_profiles <- function(s, settings, run_dir) {
  path <- file.path(run_dir, "profiles", paste0(s$id, ".rds"))
  if (file.exists(path)) {
    return(readRDS(path))
  }
  zip <- file.path(run_dir, "downloads", paste0(s$id, ".zip"))
  url <- paste0(settings$base, "/access/data-por/", s$id, "-data.txt.zip")
  if (!file.exists(zip)) {
    status <- system2(
      "curl",
      c(
        "-fsSL",
        "--retry",
        "3",
        "--max-time",
        "300",
        "-o",
        shQuote(paste0(zip, ".tmp")),
        shQuote(url)
      )
    )
    if (status != 0) {
      stop("IGRA download failed: ", s$id)
    }
    status <- system2("unzip", c("-tqq", shQuote(paste0(zip, ".tmp"))))
    if (status != 0) {
      stop("IGRA ZIP integrity check failed: ", s$id)
    }
    stopifnot(file.rename(paste0(zip, ".tmp"), zip))
  }
  bytes <- file.size(zip)
  csv <- paste0(zip, ".csv.tmp")
  awk <- paste0(zip, ".awk.tmp")
  on.exit(unlink(c(csv, awk)))
  writeLines(
    paste0(
      'BEGIN{OFS=","; expected=0; seen=0} ',
      'substr($0,1,1)=="#"{if(seen!=expected) exit 42; ',
      'expected=substr($0,33,4)+0; seen=0; y=substr($0,14,4)+0; ',
      'keep=(y>=',
      min(settings$years),
      ' && y<=',
      max(settings$years),
      '); ',
      'hdr=substr($0,2,11) OFS y OFS substr($0,19,2) OFS substr($0,22,2) OFS substr($0,25,2) OFS ',
      'substr($0,28,4) OFS substr($0,38,8) OFS substr($0,47,8); next} ',
      '{seen++; if(keep) print hdr, substr($0,1,1), substr($0,2,1), substr($0,4,5), ',
      'substr($0,10,6), substr($0,16,1), substr($0,17,5), substr($0,22,1), substr($0,23,5), substr($0,28,1)} ',
      'END{if(seen!=expected) exit 42}'
    ),
    awk
  )
  cmd <- sprintf(
    "unzip -p %s | awk -f %s > %s",
    shQuote(zip),
    shQuote(awk),
    shQuote(csv)
  )
  status <- system2("/bin/bash", c("-o", "pipefail", "-c", shQuote(cmd)))
  if (status != 0) {
    stop("IGRA extraction or sounding record count failed: ", s$id)
  }
  cols <- c(
    "id",
    "year",
    "month",
    "day",
    "hour",
    "reltime",
    "p_source",
    "np_source",
    "lvl1",
    "lvl2",
    "etime",
    "press",
    "pflag",
    "gph",
    "zflag",
    "temp",
    "tflag"
  )
  raw <- if (file.size(csv)) {
    fread(
      csv,
      header = FALSE,
      col.names = cols,
      colClasses = list(character = c(1L, 7L, 8L, 13L, 15L, 17L))
    )
  } else {
    as.data.table(setNames(
      lapply(cols, function(x) {
        if (
          x %in% c("id", "p_source", "np_source", "pflag", "zflag", "tflag")
        ) {
          character()
        } else {
          integer()
        }
      }),
      cols
    ))
  }
  result <- list(
    levels = igra_prepare(raw, s, settings),
    download_bytes = bytes,
    raw_levels = nrow(raw)
  )
  ghcnh_save(result, path)
  unlink(zip)
  result
}

# Pair airborne levels with their own accepted surface and assign level times.
igra_prepare <- function(d, s, settings) {
  d <- unique(copy(d))[hour <= 23]
  d[,
    c("id", "p_source", "np_source", "pflag", "zflag", "tflag") := lapply(
      .SD,
      as.character
    ),
    .SDcols = c("id", "p_source", "np_source", "pflag", "zflag", "tflag")
  ]
  d[,
    nominal := as.POSIXct(
      sprintf("%04d-%02d-%02d %02d:00", year, month, day, hour),
      tz = "UTC"
    )
  ]
  d[,
    sounding := sprintf(
      "%04d%02d%02d%02d_%04d",
      year,
      month,
      day,
      hour,
      reltime
    )
  ]
  rel <- (d$reltime %/% 100) +
    fifelse(d$reltime %% 100 == 99, 0, d$reltime %% 100) / 60
  d[,
    launch := nominal +
      fifelse(reltime == 9999, 0, ((rel - hour + 12) %% 24) - 12) * 3600
  ]
  d <- d[launch >= settings$start & launch < settings$end]
  surface <- d[
    lvl2 == 1 & press > 0 & (gph > -8000 | gph == -9999),
    .(
      press_s = press[1],
      gph_s = fifelse(gph[1] == -9999, s$elev, as.numeric(gph[1])),
      date_s = era5_hour(launch[1])
    ),
    by = sounding
  ]
  d <- merge(
    d[lvl2 != 1 & press > 0 & gph > -8000 & etime != -8888],
    surface,
    by = "sounding"
  )
  d[, agl := gph - gph_s]
  d <- d[agl > 0 & agl <= settings$max_agl]
  d[,
    elapsed := fifelse(
      etime == -9999,
      agl / settings$ascent_m_s,
      (etime %/% 100) * 60 + etime %% 100
    )
  ]
  d[, level_time := launch + elapsed]
  d[, date := era5_hour(level_time)]
  d <- d[
    level_time >= settings$start &
      level_time < settings$end &
      date >= settings$start &
      date < settings$end &
      date_s >= settings$start &
      date_s < settings$end
  ]
  d[, band := as.character(cut(agl, settings$height_breaks))]
  setorder(d, launch, elapsed, -press)
  d[]
}

# ERA5 single-levels surface inputs at the distinct hours of a candidate's profiles.
igra_core <- function(s, dates, run_dir) {
  path <- file.path(run_dir, "core", paste0(s$id, ".parquet"))
  if (file.exists(path)) {
    return(as.data.table(read_parquet(path)))
  }
  e <- data.table(date = sort(unique(dates)))
  values <- era5_read(
    rep(s$lon, nrow(e)),
    rep(s$lat, nrow(e)),
    e$date,
    c("surface_pressure", "temperature_2m", "dewpoint_temperature_2m"),
    "single-levels"
  )
  e[, `:=`(
    sp_sl = values$surface_pressure,
    t2m_sl = values$temperature_2m,
    d2m = values$dewpoint_temperature_2m,
    z_sl = era5_orography(s$lon, s$lat, "single-levels")
  )]
  ghcnh_write(e, path)
  e
}

# All conversions share paired finite atmospheric and height inputs.
igra_match <- function(o, e, s, gpt3) {
  d <- merge(o, e, by = "date")
  surface <- copy(e)
  setnames(
    surface,
    names(surface),
    c("date_s", "sp_s", "t2m_s", "d2m_s", "z_s")
  )
  d <- merge(d, surface, by = "date_s")
  d <- d[
    is.finite(sp_sl) &
      is.finite(t2m_sl) &
      is.finite(d2m) &
      is.finite(z_sl) &
      is.finite(sp_s) &
      is.finite(t2m_s) &
      is.finite(d2m_s) &
      is.finite(z_s)
  ]
  d[,
    err_standard := (era5_altitude(press, sp_sl, t2m_sl, z_sl) -
      era5_altitude(press_s, sp_s, t2m_s, z_s)) -
      agl
  ]
  d[,
    err_isa := (altitude_lapse(press, 101325, 288.15, 0) -
      altitude_lapse(press_s, 101325, 288.15, 0)) -
      agl
  ]
  L <- gpt3_lapse(
    gpt3,
    rep(s$lon, nrow(d)),
    rep(s$lat, nrow(d)),
    as.POSIXlt(d$level_time, tz = "UTC")$yday + 1
  )
  L_s <- gpt3_lapse(
    gpt3,
    rep(s$lon, nrow(d)),
    rep(s$lat, nrow(d)),
    as.POSIXlt(d$launch, tz = "UTC")$yday + 1
  )
  L <- fifelse(abs(L) < 1e-5, -1e-5, L)
  L_s <- fifelse(abs(L_s) < 1e-5, -1e-5, L_s)
  d[,
    err_virtual := (altitude_lapse(
      press,
      sp_sl,
      virtual_temperature(t2m_sl, d2m, sp_sl),
      z_sl,
      L
    ) -
      altitude_lapse(
        press_s,
        sp_s,
        virtual_temperature(t2m_s, d2m_s, sp_s),
        z_s,
        L_s
      )) -
      agl
  ]
  d[is.finite(err_isa) & is.finite(err_standard) & is.finite(err_virtual)]
}

# Sounding self-consistency: reported height gains against the sonde's own temperature profile.
sounding_rules <- list(
  height_m = 30,
  height_fraction = 0.03,
  inconsistent_fraction = 0.1
)

igra_consistency <- function(d, rules = sounding_rules) {
  d <- copy(d)
  setorder(d, sounding, -press)
  d[, tmean := sonde_mean_temperature(press, press_s, temp), by = sounding]
  d[, mismatch := agl - 287.05 / 9.80665 * tmean * log(press_s / press)]
  d[,
    .(
      checked = all(is.finite(mismatch)),
      consistent = all(is.finite(mismatch)) &&
        all(abs(mismatch) <= rules$height_m + rules$height_fraction * agl)
    ),
    by = sounding
  ]
}

# Latest year with 15 launch dates of consistent soundings in each month-long interval and few
# inconsistent checked soundings; ERA5 is not used.
igra_window <- function(d, flags, settings, rules = sounding_rules) {
  if (!nrow(d)) {
    return(list(reason = "coverage"))
  }
  launches <- merge(
    unique(d[, .(sounding, day = as.Date(launch, tz = "UTC"))]),
    flags,
    by = "sounding"
  )
  start <- as.Date(settings$start)
  end <- as.Date(settings$end)
  ends <- seq(end, start %m+% years(1), by = "-1 day")
  bounds <- sapply(0:12, function(m) as.integer(ends %m-% months(m)))
  n_days <- as.integer(end - start)
  index <- function(x) as.integer(x - start) + 1L
  monthly <- function(days) {
    cs <- c(0, cumsum(tabulate(index(unique(days)), nbins = n_days) > 0))
    sapply(1:12, function(m) {
      cs[bounds[, m] - as.integer(start) + 1L] -
        cs[bounds[, m + 1] - as.integer(start) + 1L]
    })
  }
  # Coverage by all soundings separates sparse records from records failing consistency.
  if (!any(apply(monthly(launches$day), 1, min) >= settings$days_per_month)) {
    return(list(reason = "coverage"))
  }
  block <- monthly(launches[consistent, day])
  covered <- apply(block, 1, min) >= settings$days_per_month
  checked <- c(
    0,
    cumsum(tabulate(index(launches[checked, day]), nbins = n_days))
  )
  bad <- c(
    0,
    cumsum(tabulate(
      index(launches[checked & !consistent, day]),
      nbins = n_days
    ))
  )
  lower <- bounds[, 13] - as.integer(start) + 1L
  upper <- bounds[, 1] - as.integer(start) + 1L
  fraction <- (bad[upper] - bad[lower]) /
    pmax(checked[upper] - checked[lower], 1)
  eligible <- which(covered & fraction <= rules$inconsistent_fraction)
  if (!length(eligible)) {
    return(list(reason = "consistency"))
  }
  i <- eligible[1]
  window_start <- as.Date(bounds[i, 13], origin = "1970-01-01")
  keep <- launches[
    consistent & day >= window_start & day < ends[i],
    sounding
  ]
  list(
    reason = "accepted",
    start = window_start,
    end = ends[i],
    levels = d[sounding %in% keep],
    inconsistent_fraction = fraction[i],
    min_month_days = min(block[i, ])
  )
}
