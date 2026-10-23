# GNSS–GHCNh overlap check, 22 October 2026

> Historical review: GNSS and MeteoSwiss evaluations were retired on 22 October 2026. The current study uses GHCNh and IGRA2; the manuscript sources and `run_all.R` define the active analysis.


The GNSS and GHCNh sources cannot be described as disjoint station networks. The Lindenberg GNSS site log explicitly places LDB2 at the DWD meteorological station in Lindenberg (`data/raw/gnss_logs/ldb200deu_20260730.log`, site-identification additional information). GHCNh lists Lindenberg at a separation of approximately 211 m. Proximity and common site names also identify candidate overlap at Helgoland and Potsdam.

The full GHCNh inventory contains a site within 1 km of 14 of the 49 retained GNSS barometers. Restricting the inventory to stations with catalogue files during 2022–2024 leaves 10 GNSS sites within 1 km. These are candidate co-locations, not verified sensor-identity matches.

For all 49 GNSS barometers, the audit compares nearby GHCNh candidates within 5 km, or the nearest active candidate when none is within that radius. It uses each candidate's latest available year during 2022–2024, applies the primary observation-level pressure quality exclusions, keeps the report nearest each hour and joins it to unique GNSS station-hours. The audit reads existing GNSS inputs and stores new NOAA downloads separately under `data/interim/gnss-ghcnh-overlap/`; it does not alter either validation sample. No-pressure/no-overlap cases remain in the results with zero matched hours. A distant nearest station is contextual information, not evidence that it represents the same facility.

| GNSS site | GHCNh station | Separation | Matched hours | Median GHCNh minus GNSS pressure |
|---|---|---:|---:|---:|
| HELG | GMN00002115, Helgoland | 92 m | 8759 | +0.62 hPa |
| LDB2 | GMN00003015, Lindenberg | 211 m | 8760 | +1.58 hPa |
| POTS | GMN00003987, Potsdam | 345 m | 8397 | −0.90 hPa |

These pressure series are not identical. Differences in sensor height, instrument calibration, reporting time or preprocessing could contribute. Comparing pressures does not establish whether observations from the exact GNSS barometer are ever forwarded through another reporting route. The supported statement is that some GNSS sites are co-located with GHCNh weather stations; neither archive origin nor differences between the saved series prove observing-system or ERA5-assimilation independence.

An earlier audit (`docs/methods/T05/audit.md`) identified `in_isd = FALSE` in older GNSS derived files as a hard-coded value. It is not evidence of verified absence from ISD or GHCNh; current validation code does not use that flag to establish independence.

Reproduce with `Rscript scripts/review_gnss_ghcnh_overlap.R`. Numerical results are in `output/tables/gnss_ghcnh_overlap.csv`. The supplement now explicitly notes co-located sites. No main numerical results or manuscript renders were changed.
