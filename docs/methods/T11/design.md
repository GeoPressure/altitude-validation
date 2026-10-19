# T11 — Expanded location-displacement test

This test broadens the T10 pilot from ten stations and 80 soundings to 50 IGRA2 stations and 200 soundings. The target question is how much the conversion's average absolute error changes when atmospheric data are queried at an uncertain location rather than the exact station location.

## Design

- Select ten eligible stations at random within each of the five IGRA climate classes (seed 20261019), requiring at least one retained level between 1.7 and 2.3 km in every quarter of 2024. Terrain roughness is recorded and represented according to available station coverage; rare climate/roughness combinations cannot be balanced, so this is not a factorial terrain comparison.
- Select one launch per station per quarter, nearest the middle of that quarter. Use the retained level nearest 2 km (within 1.7–2.3 km) and its matched surface reference. Keep observed pressure, observation time and sonde geopotential height fixed.
- Query the same six distances as T10 (0, 10, 25, 50, 100 and 200 km) with eight bearings for positive offsets. Use ERA5 surface pressure, 2 m temperature/dewpoint and orography at the nearest grid point/hour and GPT3 at the displaced coordinate. The 0 km query is the exact-location baseline.
- Compare standard atmosphere, ERA5 standard lapse and ERA5 virtual temperature/GPT3. Report absolute altitude and surface-referenced height separately.

## Primary comparison

At each distance, calculate pooled MAE with equal station, launch and bearing weights. The primary percentage change is `100 × (MAE at displaced query / MAE at 0 km − 1)`. It describes how the population-average absolute error changes relative to the exact-location query. Bootstrap stations, keeping each station's four launches and all paired directions together, for a 95% interval. Also report the distribution of station-level MAE percentage changes.

Individual percentage changes in absolute error are not the primary measure: they can become enormous when an exact-location error is near zero. Report paired absolute changes in metres, their 95th percentile and the share of cases with increased absolute error instead. Directional observations are repeated scenarios, not independent animals.

## Files and limitations

The station, launch, location and query-plan CSVs are written before retrieval. Results, station summaries, raw paired errors and provenance are saved beside this design. ERA5 values are cached under `data/interim/location_sensitivity_wide/`; existing T10 station caches are copied in and extended only for missing station/grid/hour combinations.

This remains a fixed 2024 near-2-km sensitivity experiment, not a flight-time-weighted validation, a global distribution of real geolocator position errors or a test of terrain-clearance correction. It cannot establish universal location tolerances or characterize rare weather extremes.

Run `Rscript docs/methods/T11/run_experiment.R` from the repository root. The network extraction reuses exact cached queries and may take substantially longer than T10. Results and the distance-response figure are then regenerated from the saved paired errors and summary tables.
