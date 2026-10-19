# Surface reference data

GHCNh now supplies the primary global surface pressure observations and station elevations. The candidate geography follows the prior HadISD station footprint: step 01 reads its final station inventory only to establish candidate locations, step 02 matches those locations to GHCNh stations within 25 km and downloads annual files, and step 03 selects each station's most recent GHCNh year that passes pressure/QC and reporting coverage before thinning the sample. The default match radius can be changed with `GHCNH_MATCH_RADIUS_KM`.

Run the primary intake and screening with:

```sh
Rscript run_all.R 1 3
```

The GHCNh raw annual files, reduced station-year files, station crosswalk, screening outputs and provenance are stored under `data/interim/ghcnh/`. The downstream analysis reads one selected GHCNh pressure year per station from `data/interim/ghcnh/pressure/`; station elevation and coordinates are from the GHCNh station list. Pressure QC flags and source codes are retained with the screened records for later cleaning sensitivity checks. For each candidate station, the screen selects the most recent year from 2022 through the latest available year that has at least 183 reporting days and four distinct accepted station-pressure hours per reporting day. The source QC screen excludes suspect/error codes and lowercase flags.

The crosswalk preserves the old candidate geography but not a common observation year: each station contributes its latest qualifying GHCNh year, which can differ by station and can include partial 2026 data. It does not yet add GHCNh-only stations outside the HadISD inventory.


MeteoSwiss (`scripts/06_meteoswiss_download.R`) and GNSS (`scripts/05_gnss_download.R`) remain the targeted complementary references because they can supply barometer-height metadata. ARM is a candidate for a small, site-specific check if deployment metadata gives a stronger height reference or ERA5 independence can be established. DWD and the Copernicus global surface archive are optional exploratory intakes and are not in the primary pipeline because neither currently adds a distinct reference-height or independence advantage over GHCNh. IGRA2 remains the separate upper-air comparison.

The [transition review](transition-review.md) records the date/QC audit and the choice of GHCNh and IGRA2 as the two primary references. GNSS and MeteoSwiss are complementary appendix checks. The ISO timestamp parser was corrected and all candidate extracts rebuilt because the earlier implicit parser discarded observation hours. Step 03 now retains up to two preceding years for the seasonal step-change check while the main error statistics use the selected year.

The October 2026 intake retained 5,202 coverage-qualified candidates and 2,146 stations after thinning (2026: 1,471; 2025: 417; 2024: 181; 2023: 41; 2022: 36). ERA5 extraction completed for all retained stations through 2026-10-12 23:00 UTC. Two stations fell below coverage after matching; the station screen retained 1,983 of the remaining 2,144. Source timestamp, distinct-hour coverage and latest-year checks pass. The matched 2024 transition audit and the complementary-source assessment are documented in the transition review. Primary tables are regenerated from GHCNh, with GNSS and MeteoSwiss kept as appendix checks. A cached-data analysis rebuild starts with `N_CORES=16 Rscript run_all.R 12`.

The paired completed-year sensitivity retains 1,912 screened stations: ERA5-standard MAE is 6.48 m with the latest qualifying year and 6.37 m with the latest qualifying completed year. Recent observations are not intrinsically more accurate. Final selected years and source-QC composition are recorded in `output/tables/paper_ground_selected_years.csv` and `paper_ground_qc_provenance.csv`; the manuscript supplement includes both checks.

The transition build completed on 2026-10-19: analysis steps 10–20, figures, and PDF/HTML versions of the manuscript and supplement were regenerated. R parsing, source/coverage checks, cross-table totals and visual PDF checks passed.
