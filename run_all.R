# Run the pipeline: every script in scripts/ in order, then the report.
#
#   Rscript run_all.R          # steps 01-17 and the report
#   Rscript run_all.R 12       # from step 12 (analysis) onwards
#   Rscript run_all.R 12 15    # steps 12 to 15 only
#
# Each step runs in its own R session and skips work already on disk (downloads, ERA5 reads), so the
# pipeline can be interrupted and resumed. Step 00 (bird flight heights) needs the GeoLocator master
# data package locally and its output is committed: run it explicitly with `Rscript run_all.R 0 0`.
# Set N_CORES (default 8) for the number of parallel workers.

args <- as.integer(commandArgs(trailingOnly = TRUE))
steps <- sort(list.files("scripts", "^[0-9]{2}_.*\\.R$"))
num <- as.integer(substr(steps, 1, 2))
from <- if (length(args) >= 1) args[1] else 1
to <- if (length(args) >= 2) args[2] else max(num)

for (s in steps[num >= from & num <= to]) {
  message("==== ", s)
  t0 <- Sys.time()
  if (system2("Rscript", file.path("scripts", s)) != 0) stop(s, " failed", call. = FALSE)
  message("     done in ", format(round(Sys.time() - t0, 1)))
}
if (to >= max(num)) {
  message("==== report")
  if (system2("quarto", c("render", "report/index.qmd")) != 0) stop("report failed", call. = FALSE)
}
