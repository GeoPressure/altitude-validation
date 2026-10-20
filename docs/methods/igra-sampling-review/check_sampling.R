# Scientific boundaries and candidate recovery; no network access.
source("R/utils.R")
source("R/ghcnh_sampling.R")
source("R/igra_sampling.R")
setDTthreads(1)
settings <- list(start = as.POSIXct("2023-01-01", tz = "UTC"), end = as.POSIXct("2024-01-02", tz = "UTC"),
  max_agl = 6000, ascent_m_s = 5, days_per_month = 15L, outlier_m = 150, outlier_mad = 10,
  height_breaks = c(0, 100, 250, 500, 1000, 1500, 2000, 3000, 4000, 5000, 6000))
s <- data.table(id = "TEST", elev = 1000)
checks <- character()

# Source QA, midnight release, timing and the former pressure boundary ------
raw <- data.table(id = "TEST", year = 2023L, month = 1L, day = rep(2:6, each = 2), hour = 0L,
  reltime = c(2350L, 2350L, rep(0L, 8)), p_source = "test", np_source = "test",
  lvl1 = 2L, lvl2 = rep(c(1L, 0L), 5), etime = c(0L, -9999L, 0L, 3000L, 0L, -8888L, 0L, 3000L, 0L, 3000L),
  press = rep(c(100000L, 35000L), 5), pflag = "", gph = c(-9999L, 6000L, -8888L, 2000L, 1000L, 2000L, 1000L, 2000L, 1000L, 2000L),
  zflag = "", temp = -9999L, tflag = "")
raw[day == 5 & lvl2 == 1, press := -9999L]
x <- igra_prepare(raw, s, settings)
stopifnot(nrow(x) == 2L, all(x$day == c(2L, 6L)), x$press[1] == 35000,
  x$gph_s[1] == 1000, x$agl[1] == 5000, x$elapsed[1] == 1000,
  format(x$launch[1], tz = "UTC") == "2023-01-01 23:50:00",
  format(x$date[2], tz = "UTC") == "2023-01-06")
stopifnot(nrow(igra_prepare(raw[0], s, settings)) == 0L,
  nrow(igra_prepare(raw[lvl2 != 1], s, settings)) == 0L,
  nrow(igra_prepare(raw[day == 3], s, settings)) == 0L)
checks <- c(checks, "Source QA, missing surface substitution, empty/absent surface, <400 hPa, midnight release and half-hour tie")

# A one-day move finds a passing window; extra levels do not add dates -------
launches <- do.call(c, lapply(1:12, function(m) as.POSIXct(sprintf("2023-%02d-%02d", m, 1:15), tz = "UTC")))
d <- data.table(launch = launches, sounding = as.character(launches), band = "(0,100]", err_standard = 0)
w <- igra_window(d, settings)
stopifnot(w$end == as.Date("2024-01-01"), w$min_month_days == 15, abs(sum(w$levels$weight) - 1) < 1e-12)
one_day <- copy(d)
one_day[month(launch) == 6, launch := as.POSIXct("2023-06-01", tz = "UTC")]
stopifnot(is.null(igra_window(one_day, settings)))
checks <- c(checks, "Daily backwards search and distinct launch-date monthly coverage")

# Strict >150 m boundary and coverage recalculated after removal ------------
boundary <- copy(d)
boundary[1, err_standard := 150]
stopifnot(!is.null(igra_window(boundary, settings)))
boundary[1, err_standard := 150.01]
stopifnot(is.null(igra_window(boundary, settings)))
checks <- c(checks, "Strict outlier boundary and post-exclusion coverage")

# Build month blocks directly from a month-end, including leap February -----
month_end <- settings
month_end$start <- as.POSIXct("2022-03-01", tz = "UTC")
month_end$end <- as.POSIXct("2024-03-31", tz = "UTC")
bounds <- as.Date(month_end$end) %m-% months(0:12)
leap <- copy(d)
leap[, launch := as.POSIXct(do.call(c, lapply(bounds[2:13], function(a) a + 0:14)), tz = "UTC")]
stopifnot(igra_window(leap, month_end)$end == as.Date("2024-03-31"))
checks <- c(checks, "Month-end and leap-year blocks are anchored independently")

# Inject one scientific rejection and one technical failure before acceptance.
root <- tempfile("igra-check-")
dir.create(root)
for (run in c("resumed", "direct")) {
  for (part in c("cells", "accepted")) dir.create(file.path(root, run, part), recursive = TRUE)
}
invisible(file.create(file.path(root, "resumed", "fail-once")))
e <- new.env(parent = globalenv())
e$igra_profiles <- function(s, settings, run_dir) {
  if (s$id == "B" && file.exists(file.path(run_dir, "fail-once"))) {
    unlink(file.path(run_dir, "fail-once"))
    stop("Injected interrupted retrieval")
  }
  list(levels = if (s$id == "A") d[0] else copy(d), download_bytes = 10, raw_levels = nrow(d))
}
e$igra_core <- function(...) data.table()
e$igra_match <- function(o, ...) copy(o)
cell <- igra_cell
environment(cell) <- e
candidates <- data.table(id = c("A", "B"), candidate_order = 1:2, cell = "test")
a <- cell("test", candidates, settings, file.path(root, "resumed"), NULL, NULL)
stopifnot(!a$completed, a$next_candidate == 2L, a$pending$id == "B", nrow(a$attempts) == 1L)
b <- cell("test", candidates, settings, file.path(root, "resumed"), NULL, NULL)
c <- cell("test", candidates, settings, file.path(root, "direct"), NULL, NULL)
stopifnot(b$completed, identical(b$accepted$id, c$accepted$id), identical(b$attempts$reason, c$attempts$reason),
  isTRUE(all.equal(read_parquet(file.path(root, "resumed", "accepted", "B.parquet")), read_parquet(file.path(root, "direct", "accepted", "B.parquet")))) )
finished <- cell("test", candidates, settings, file.path(root, "resumed"), NULL, NULL)
stopifnot(isTRUE(all.equal(finished, b, check.attributes = FALSE)))
unlink(root, recursive = TRUE)
checks <- c(checks, "Rejection advances, technical failure preserves candidate, resume equals uninterrupted run")
fwrite(data.table(check = checks, passed = TRUE), "docs/methods/igra-sampling-review/sampling-checks.csv")
cli::cli_alert_success("{length(checks)} scientific and recovery checks passed")
