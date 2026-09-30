# Full pipeline. Each step is idempotent: downloads and ERA5 reads skip what is already on disk.
# N_CORES (default 8) sets the number of parallel workers.

R = Rscript

all: report

data/interim/hadisd_candidates.csv:
	$(R) scripts/01_select_hadisd.R

data/interim/stations_A_all.csv: data/interim/hadisd_candidates.csv
	$(R) scripts/02_download_hadisd.R

data/interim/stations_A.csv: data/interim/stations_A_all.csv
	$(R) scripts/02b_thin_hadisd.R

data/interim/igra_candidates.csv:
	$(R) scripts/03_igra.R

output/tables/stations.csv: data/interim/stations_A.csv data/interim/igra_candidates.csv
	$(R) scripts/04_static.R

data/interim/era5.done: output/tables/stations.csv
	$(R) scripts/05_era5_extract.R && touch $@

data/interim/errors_A.parquet: data/interim/era5.done
	$(R) scripts/06_errors.R

output/tables/api_crosscheck_summary.csv: data/interim/errors_A.parquet
	$(R) scripts/08_api_crosscheck.R

output/tables/headline.csv: data/interim/errors_A.parquet output/tables/api_crosscheck_summary.csv
	$(R) scripts/07_analysis.R

# Optional: needs the GeoLocator master data package locally (output is committed).
bird-heights:
	$(R) scripts/00_bird_heights.R

report: output/tables/headline.csv
	quarto render report/index.qmd

.PHONY: all report bird-heights
