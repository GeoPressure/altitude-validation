# Build the two files of the Zenodo record (uploaded by hand) into data/zenodo/:
#
#   altitude-validation-code.zip  the repository at HEAD (code, tables, figures, report) plus the
#                                 rendered HTML report
#   altitude-validation-data.zip  the downloaded and extracted data that are slow or impossible to
#                                 get again (ERA5 at every station, radiosondes, GNSS, MeteoSwiss,
#                                 DEM values, and the station lists and API listings as they were)
#
# HadISD is left out: its licence does not allow it in a CC BY record, and v3.4.3.2025f is the
# final, frozen release, so steps 01-03 download exactly the same files again. The errors
# (09_errors.R) are left out too: they are recomputed in a few minutes.
#
# Run from the project root after committing: Rscript zenodo/make_archive.R

out <- "data/zenodo"
dir.create(out, showWarnings = FALSE)

code <- file.path(out, "altitude-validation-code.zip")
unlink(code)
stopifnot(system2("git", c("archive", "--format=zip", "--prefix=altitude-validation/", "-o", code,
  "HEAD")) == 0)
# Add the rendered report, which is not committed (GitHub Pages builds it).
tmp <- tempfile()
dir.create(file.path(tmp, "altitude-validation", "report"), recursive = TRUE)
file.copy("report/index.html", file.path(tmp, "altitude-validation", "report"))
code_abs <- normalizePath(code)
old <- setwd(tmp)
stopifnot(system2("zip", c("-q", code_abs, "altitude-validation/report/index.html")) == 0)
setwd(old)

data <- file.path(out, "altitude-validation-data.zip")
unlink(data)
keep <- c(
  "data/interim/era5", "data/interim/era_ids.csv",
  "data/interim/igra", "data/interim/igra_candidates.csv", "data/interim/igra_stations.csv",
  "data/interim/gnss", "data/interim/meteoswiss", "data/interim/indep",
  "data/interim/neighbours", "data/interim/station_dem.csv", "data/interim/station_dem_box.csv",
  "data/raw/era5_invariant.nc", "data/raw/gnss_logs", "data/raw/igra2-station-list.txt",
  "data/raw/isd-history.csv", "data/raw/ogd-smn_meta_stations.csv"
)
stopifnot(all(file.exists(keep)))
file.copy("zenodo/data_README.md", "data/README.md", overwrite = TRUE)
# Parquet and NetCDF are already compressed: store them as they are.
stopifnot(system2("zip", c("-q", "-r", "-n", ".parquet:.nc", data, "data/README.md", keep)) == 0)
unlink("data/README.md")

cat(sprintf("%s: %.0f MB\n%s: %.0f MB\n", code, file.size(code) / 2^20, data,
  file.size(data) / 2^20))
