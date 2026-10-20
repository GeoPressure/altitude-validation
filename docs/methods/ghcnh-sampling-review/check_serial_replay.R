# Recompute the pilot sequentially from the same prepared inputs -------------
source("R/utils.R")
out <- "docs/methods/ghcnh-sampling-review"
run_dir <- "data/interim/ghcnh/selection-2026-10-13"
replay_dir <- tempfile("ghcnh-serial-check-")
dir.create(replay_dir)
for (name in c("settings.rds", "inventory.rds", "candidates.rds")) {
  stopifnot(file.link(file.path(run_dir, name), file.path(replay_dir, name)))
}
for (part in c("catalogue", "annual", "pressure", "core")) {
  dir.create(file.path(replay_dir, part))
  files <- list.files(file.path(run_dir, part), full.names = TRUE)
  files <- files[!grepl("\\.tmp$", files)]
  stopifnot(all(file.link(files, file.path(replay_dir, part, basename(files)))))
}
status <- system2("Rscript", c("scripts/sample_ghcnh.R", "64", "1"),
  env = paste0("GHCNH_RUN_DIR=", shQuote(replay_dir)),
  stdout = file.path(replay_dir, "replay.log"), stderr = file.path(replay_dir, "replay.log"))
stopifnot(status == 0)
p <- fread(file.path(run_dir, "pilot-64-accepted.csv"))
q <- fread(file.path(replay_dir, "pilot-64-accepted.csv"))
setorder(p, id)
setorder(q, id)
stopifnot(identical(p$id, q$id), identical(p$window_start, q$window_start),
  identical(p$window_end, q$window_end), identical(p$accepted_hours, q$accepted_hours))
a <- fread(file.path(run_dir, "pilot-64-attempts.csv"))
b <- fread(file.path(replay_dir, "pilot-64-attempts.csv"))
setorder(a, cell, candidate_order)
setorder(b, cell, candidate_order)
stopifnot(identical(a$id, b$id), identical(a$reason, b$reason))
for (id in p$id) {
  x <- read_parquet(file.path(run_dir, "accepted", paste0(id, ".parquet")))
  y <- read_parquet(file.path(replay_dir, "accepted", paste0(id, ".parquet")))
  stopifnot(identical(x$date, y$date), isTRUE(all.equal(x, y)))
}
fwrite(data.table(check = c("Fresh sequential and socket selections", "Every accepted hour and input"),
  result = "pass", cells = 64L, accepted_stations = nrow(p)), file.path(out, "pilot-nearest-hour-parallel-checks.csv"))
invisible(file.copy(file.path(replay_dir, "pilot-64-metrics.csv"), file.path(out, "pilot-nearest-hour-serial-metrics.csv"), overwrite = TRUE))
unlink(replay_dir, recursive = TRUE)
cat("Sequential recomputation matches all 64 cells and", nrow(p), "accepted station series.\n")
