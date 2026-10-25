# Build the two files of the Zenodo record (uploaded by hand) into data/zenodo/:
#   altitude-validation-code.zip  tracked repository files and the rendered PDFs
#   altitude-validation-data.zip  derived data needed to rebuild the results without downloads
# Run from the project root: Rscript zenodo/make_archive.R [--code-only]

out <- "data/zenodo"
dir.create(out, showWarnings = FALSE)

code <- file.path(out, "altitude-validation-code.zip")
unlink(code)
files <- system2("git", c("ls-files"), stdout = TRUE)
files <- unique(c(files[file.exists(files)], "manuscript/paper.pdf", "manuscript/supplement.pdf"))
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
if ("--code-only" %in% commandArgs(trailingOnly = TRUE)) {
  cat(sprintf("%s: %.0f MB\n", code, file.size(code) / 2^20))
  quit(save = "no")
}

data <- file.path(out, "altitude-validation-data.zip")
unlink(data)
keep <- c(
  "data/derived/ghcnh/candidates", "data/derived/ghcnh/selection", "data/derived/ghcnh/terrain",
  "data/derived/igra/candidates", "data/derived/igra/selection",
  "data/derived/analysis/era5_land", "data/derived/position_sensitivity",
  "data/raw/era5_invariant.nc", "data/raw/ghcnh-station-list.txt", "data/raw/igra2-station-list.txt",
  "data/raw/gpt3"
)
stopifnot(all(file.exists(keep)))
stopifnot(file.copy("zenodo/data_README.md", "data/README.md", overwrite = TRUE))
# Parquet and NetCDF are already compressed: store them as they are.
stopifnot(system2("zip", c("-q", "-r", "-n", ".parquet:.nc", data, "data/README.md", keep)) == 0)
unlink("data/README.md")

cat(sprintf("%s: %.0f MB\n%s: %.0f MB\n", code, file.size(code) / 2^20, data,
  file.size(data) / 2^20))
