# Build the two files of the Zenodo record (uploaded by hand) into data/zenodo/:
#
#   altitude-validation-code.zip  the current working tree (code, tables, figures, manuscript) plus
#                                 rendered documents
#   altitude-validation-data.zip  the downloaded and extracted data that are slow or impossible to
#                                 get again (ERA5 at every station, radiosondes,
#                                 DEM values, and the station lists and API listings as they were)
#
# Frozen selection directories include accepted inputs and candidate caches;
# raw annual archives and reproducible error series are not required.
#
# Run from the project root: Rscript zenodo/make_archive.R

out <- "data/zenodo"
dir.create(out, showWarnings = FALSE)

code <- file.path(out, "altitude-validation-code.zip")
unlink(code)
# Include current tracked and untracked project files, including uncommitted analysis changes.
files <- unique(system2("git", c("ls-files", "--cached", "--others", "--exclude-standard"), stdout = TRUE))
files <- files[file.exists(files)]
rendered <- c("paper/paper.pdf", "paper/paper.html", "paper/supplement.pdf",
  "paper/supplement.html", "archive/report/index.html")
files <- unique(c(files, rendered[file.exists(rendered)]))
tmp <- tempfile()
for (f in files) {
  dir.create(file.path(tmp, "altitude-validation", dirname(f)), recursive = TRUE, showWarnings = FALSE)
  file.copy(f, file.path(tmp, "altitude-validation", f))
}
code_abs <- file.path(normalizePath(out), basename(code))
old <- setwd(tmp)
stopifnot(system2("zip", c("-q", "-r", shQuote(code_abs), "altitude-validation")) == 0)
setwd(old)
unlink(tmp, recursive = TRUE)

data <- file.path(out, "altitude-validation-data.zip")
unlink(data)
keep <- c(
  "data/interim/ghcnh/selection-2026-10-13",
  "data/interim/ghcnh/selection-curated-2026-10-22",
  "data/interim/igra-selection-2026-10-13",
  "data/interim/igra-selection-curated-2026-10-23",
  "data/interim/analysis-2026-10-13/era5",
  "data/interim/analysis-2026-10-13/historical_ground.parquet",
  "data/interim/igra",
  "data/raw/era5_invariant.nc", "data/raw/ghcnh-station-list.txt",
  "data/raw/gpt3"
)
stopifnot(all(file.exists(keep)))
file.copy("zenodo/data_README.md", "data/README.md", overwrite = TRUE)
# Parquet and NetCDF are already compressed: store them as they are.
stopifnot(system2("zip", c("-q", "-r", "-n", ".parquet:.nc", data, "data/README.md", keep)) == 0)
unlink("data/README.md")

cat(sprintf("%s: %.0f MB\n%s: %.0f MB\n", code, file.size(code) / 2^20, data,
  file.size(data) / 2^20))
