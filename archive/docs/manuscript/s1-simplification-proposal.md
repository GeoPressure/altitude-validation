# Proposed shorter S1: reference data, sampling and quality control

**Implemented follow-up:** The manuscript now contains a refined version of this draft, with unique GNSS hours and post-selection ground cell weights. See the [implementation record](../../../docs/methods/T06/implementation.md). The original proposal below is retained for traceability.

This was replacement wording for review, not an edit at the time it was drafted. It describes the current numerical analysis. The [T06 assessment](../../../docs/methods/T06/recommendations.md) separately evaluates possible changes to weighting, coverage and duplicate handling. Those changes must be implemented and the affected numbers updated before describing them as the primary analysis.

## Proposed replacement prose

We evaluated the same pressure observations with all three conversions. Ground references comprise HadISD v3.4.3.2025f in 2022–2024 and co-located GNSS barometers from the IGS/EUREF networks in the same years. IGRA2 radiosondes in 2023–2024 provide the airborne comparison. ERA5 single-level pressure, 2 m temperature, dewpoint and surface elevation were obtained at the nearest 0.25° grid cell and hour. Missing reference observations were not filled. Product descriptions, variables and the observation windows are listed in Table S1; exact snapshot limitations and retrieval details accompany the analysis code.

HadISD candidates required pressure on at least 183 days in each year and an average of four observations per reporting day. To limit geographic clustering, we selected one random station per 2° cell and retained additional stations above 1000 m. Cell weights account for these additional stations. GNSS selection required at least 180 listed file-days across the study period, sufficient usable observations and agreement between the median site-log and file-header barometer heights within 1 m. Ellipsoidal GNSS heights were converted using EGM96. These checks do not establish that the pressure records are independent of ERA5.

Absolute ground error combines the conversion discrepancy with uncertainty in pressure and reference height. Listed HadISD station elevation can differ from barometer height. We therefore flag stations with large persistent offsets, step changes or frequently implausible observations, using the explicit rules in Table S1. Because the offset flag depends on ERA5 residuals, screened results are conditional on this selection. S4 reports results with and without the station screen and a separate metadata check using MeteoSwiss published barometer heights. Reference-height uncertainty cannot be removed simply by choosing a robust error statistic.

IGRA supplies pressure and reported geopotential height, rather than independently surveyed geometric height at every level. We use retained levels 1–6000 m above the sounding surface; missing surface height is replaced by station elevation. Reference pressure and atmospheric inputs must be finite, a surface observation must be available, and the station must have at least 100 soundings across the study period. Height bands and their station/sounding counts are provided with the flight-error tables; coverage is not uniform with height.

HadISD observations are assigned to the nearest ERA5 hour, retaining the first report per hour. GNSS samples within ±1 min of each hour are averaged within daily files; MeteoSwiss full-hour observations are used for the S4 comparison. Radiosonde level times combine release time and elapsed ascent time. Missing values use nominal release time or a 5 m/s ascent estimate, respectively. All radiosonde levels use the launch-station coordinates; balloon drift is ignored. S4 reports GNSS duplicate-hour sensitivity. Detailed parsing conventions, coverage by station-year and diagnostic flags remain available with the code.

## Compact Table S1 to accompany the prose

| Dataset or check | Retained input / criterion | Location of details |
|---|---|---|
| HadISD | Station pressure; ≥183 days/year and ≥4 reports/reporting day; 2° thinning with additional >1000 m sites | Product/version citation; counts and coverage table |
| Ground observation quality | Discrepancy from station median >max(100 m, 10 MAD) flagged as gross | Exact implementation and removed counts in code |
| HadISD station flags | Absolute offset >30 m + 0.10 × absolute station–ERA5 elevation gap; step magnitude ≥10 m with absolute t ≥10; >1% gross observations | S4 threshold sensitivity, with interpretation as suspect references rather than proven height errors |
| GNSS barometers | ≥180 listed days over the full window; ≥2160 usable rows; median header/log height difference within ±1 m | RINEX/site-log/geoid definitions and retained counts |
| IGRA2 | ≥100 soundings per station; surface plus source pressure ≥400 hPa; valid matched surface and airborne levels 1–6000 m | Height-band station/sounding support and timing-fallback documentation |
| Radiosonde gross-error check | Surface-referenced error differs from height-band median by >max(150 m, 10 MAD) | S4/code; flag is not proof of an instrument fault |
| MeteoSwiss corroboration | Published barometer height; full-hour QFE; ≥2160 rows | S4 alone, including the height-only HadISD comparison |

Keep the existing dataset citations when applying the prose. MAD denotes the scaled median absolute deviation returned by R's `mad()`, not the unscaled median absolute deviation. The current implementation assigns HadISD cell weights before reference screening; the small effect of recomputing them after screening belongs in S4, with the numerical update if adopted.

## What moves out of S1

- Keep the MeteoSwiss methodology, paired height-only result and regional figure together in S4. The main text needs one sentence referring to this check, rather than presenting a fourth primary network.
- Keep the rationale and sensitivity of the reference-height screen in S4; S1 retains the actual rule and its conditional interpretation.
- Put the full station-year coverage tables, raw parsing fields, release-minute conventions, original version/retrieval limitations and technical provenance in the linked analysis documentation. Retain product identity, observation periods and material limitations in the supplement.
- Place exact height-band boundaries and per-band support beside the flight-error table. They need not also appear as a long prose list in S1.
- Keep the contrast between absolute altitude error and station temporal scatter in the main Methods, not repeated in dataset descriptions.
