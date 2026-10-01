# GNSS stations with co-located meteorological sensors: an ERA5-independent reference.
#
# IGS and EUREF permanent GNSS stations often carry a barometer, reported in daily RINEX
# meteorological files. Their pressure is not exchanged on the GTS and so is not assimilated by ERA5,
# and the barometer height is tied to a geodetic antenna whose ellipsoidal height is known to mm.
#
# This script lists the daily met files of 2022-2024 on the BKG mirror (anonymous), keeps stations
# with at least 180 days, and stores for every station the hourly pressure (mean of the samples
# within +/- 1 min of each hour) with the per-file header metadata: sensor model and the barometer
# position (SENSOR POS XYZ/H). Daily files are deleted after parsing. Site logs are downloaded for
# the independent sensor-height check in 14_independent_errors.R.

source("R/utils.R")

base <- "https://igs.bkg.bund.de/root_ftp"
archives <- c("IGS", "EUREF")
out_dir <- file.path(dir_interim, "gnss")
dir.create(file.path(out_dir, "hourly"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(dir_raw, "gnss_logs"), recursive = TRUE, showWarnings = FALSE)
days <- seq(as.Date(sprintf("%d-01-01", min(years_main))), as.Date(sprintf("%d-12-31",
  max(years_main))), by = "day")

# ---- Listing ---------------------------------------------------------------------------------
list_file <- file.path(out_dir, "listing.csv")
if (!file.exists(list_file)) {
  jobs <- CJ(day = as.character(days), archive = archives)
  lst <- par_map(seq_len(nrow(jobs)), function(i) {
    d <- as.Date(jobs$day[i])
    url <- sprintf("%s/%s/obs/%s/%s/", base, jobs$archive[i], format(d, "%Y"), format(d, "%j"))
    html <- paste(readLines(url, warn = FALSE), collapse = "\n")
    f <- regmatches(html, gregexpr('href="[^"]*(_MM\\.rnx|\\.[0-9]{2}m)\\.gz"', html))[[1]]
    f <- gsub('^href="|"$', "", f)
    if (length(f) == 0) return(NULL)
    data.table(day = jobs$day[i], archive = jobs$archive[i], file = f)
  }, cores = min(n_cores, 6), export = c("jobs", "base"))
  ok <- check_failures(lst, paste(jobs$archive, jobs$day), "daily listings")
  lst <- rbindlist(lst[vapply(lst, is.data.frame, logical(1))])
  # Cache the listing only when every day was listed, so that a rerun completes it.
  if (all(ok)) fwrite(lst, list_file)
} else {
  lst <- fread(list_file)
}
lst[, station := toupper(substr(file, 1, 4))]
lst[, rinex3 := grepl("_MM\\.rnx", file)]
# One file per station and day: RINEX 3 before RINEX 2, IGS before EUREF.
setorder(lst, station, day, -rinex3, archive)
lst <- lst[, .SD[1], by = .(station, day)]
keep <- lst[, .N, by = station][N >= 180, station]
lst <- lst[station %in% keep]
cat(length(keep), "stations with >= 180 days of met files\n")

# ---- Download and parse ----------------------------------------------------------------------
parse_met <- function(path) {
  con <- gzfile(path, "r")
  L <- readLines(con, warn = FALSE)
  close(con)
  eoh <- grep("END OF HEADER", L, fixed = TRUE)[1]
  if (is.na(eoh)) return(NULL)
  hdr <- L[seq_len(eoh)]
  lab <- substring(hdr, 61)
  obs <- unlist(strsplit(trimws(substr(hdr[grepl("^# / TYPES OF OBSERV", lab)], 7, 60)), "\\s+"))
  ip <- match("PR", obs)
  if (is.na(ip)) return(NULL)
  pos <- hdr[grepl("^SENSOR POS XYZ/H", lab) & substr(hdr, 58, 59) == "PR"]
  pos <- if (length(pos)) as.numeric(strsplit(trimws(substr(pos[1], 1, 56)), "\\s+")[[1]]) else NA
  mod <- hdr[grepl("^SENSOR MOD/TYPE/ACC", lab) & substr(hdr, 58, 59) == "PR"]
  acc <- if (length(mod)) suppressWarnings(as.numeric(substr(mod[1], 47, 53))) else NA_real_
  mod <- if (length(mod)) trimws(paste(substr(mod[1], 1, 20), substr(mod[1], 21, 40))) else NA
  d <- L[-seq_len(eoh)]
  v3 <- grepl("^\\s*3", hdr[1])
  # Record lines start with the epoch; continuation lines (more than 8 types, RINEX 2) are joined.
  is_rec <- if (v3) grepl("^ [0-9]{4} ", d) else grepl("^ [ 0-9][0-9] [ 0-9][0-9] ", d)
  grp <- cumsum(is_rec)
  d <- vapply(split(d, grp), paste, character(1), collapse = " ")[as.character(unique(grp[grp > 0]))]
  tok <- strsplit(trimws(d), "\\s+")
  ok <- lengths(tok) >= 6 + ip
  tok <- tok[ok]
  if (length(tok) == 0) return(NULL)
  m <- matrix(as.numeric(unlist(lapply(tok, `[`, c(1:6, 6 + ip)))), ncol = 7, byrow = TRUE)
  yr <- if (v3) m[, 1] else 2000 + m[, 1]
  t <- ISOdatetime(yr, m[, 2], m[, 3], m[, 4], m[, 5], m[, 6], tz = "UTC")
  p <- m[, 7]
  hr <- round(as.numeric(t) / 3600) * 3600
  near <- abs(as.numeric(t) - hr) <= 60 & p > 300 & p < 1100
  if (!any(near)) return(NULL)
  h <- data.table(date = as.POSIXct(hr[near], origin = "1970-01-01", tz = "UTC"), p = p[near])
  h <- h[, .(pressure = mean(p), n = .N), by = date]
  h[, `:=`(hdr_X = pos[1], hdr_Y = pos[2], hdr_Z = pos[3], hdr_H = pos[4], sensor = mod,
    sensor_acc = acc)]
  h[]
}

extract_station <- function(s) {
  out <- file.path(out_dir, "hourly", paste0(s, ".parquet"))
  if (file.exists(out)) return(TRUE)
  f <- lst[station == s]
  tmp <- tempfile(paste0("gnss_", s))
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))
  # One curl call per station, reusing connections: much faster than one call per daily file.
  f[, url := sprintf("%s/%s/obs/%s/%s/%s", base, archive, format(as.Date(day), "%Y"),
    format(as.Date(day), "%j"), file)]
  f[, dest := file.path(tmp, paste0(day, "_", file))]
  cfg <- file.path(tmp, "curl.cfg")
  writeLines(sprintf('url = "%s"\noutput = "%s"', f$url, f$dest), cfg)
  system2("curl", c("-sfL", "--retry", "5", "--retry-all-errors", "-K",
    shQuote(cfg)))
  h <- rbindlist(lapply(f$dest[file.exists(f$dest)], function(x) {
    tryCatch(parse_met(x), error = function(e) NULL)
  }))
  if (nrow(h) == 0) h <- data.table(date = as.POSIXct(character(), tz = "UTC"))
  h[, station := s]
  write_parquet(h, paste0(out, ".tmp"))
  file.rename(paste0(out, ".tmp"), out)
  TRUE
}

# At most 6 parallel downloads from the BKG server.
res <- par_map(keep, extract_station, cores = min(n_cores, 6),
  export = c("lst", "base", "out_dir", "parse_met"))
check_failures(res, keep, "stations")

# ---- Site logs -------------------------------------------------------------------------------
# Current site log of each station, from IGS or, failing that, the EUREF Permanent Network.
igs_idx <- readLines("https://files.igs.org/pub/station/log/", warn = FALSE)
igs_logs <- unique(unlist(regmatches(igs_idx, gregexpr("[a-z0-9]{9}_[0-9]{8}\\.log", igs_idx))))
epn_idx <- readLines("https://epncb.oma.be/ftp/station/log/", warn = FALSE)
epn_logs <- unique(unlist(regmatches(epn_idx, gregexpr("[a-z0-9]{9}_[0-9]{8}\\.log", epn_idx))))
for (s in keep) {
  if (length(list.files(file.path(dir_raw, "gnss_logs"), paste0("^", tolower(s))))) next
  cand <- sort(igs_logs[startsWith(igs_logs, tolower(s))], decreasing = TRUE)
  url <- if (length(cand)) paste0("https://files.igs.org/pub/station/log/", cand[1]) else {
    cand <- sort(epn_logs[startsWith(epn_logs, tolower(s))], decreasing = TRUE)
    if (length(cand)) paste0("https://epncb.oma.be/ftp/station/log/", cand[1]) else NA
  }
  if (is.na(url)) {
    message("no site log: ", s)
    next
  }
  tryCatch(curl_download(url, file.path(dir_raw, "gnss_logs", basename(url))),
    error = function(e) message("log failed: ", s))
}
