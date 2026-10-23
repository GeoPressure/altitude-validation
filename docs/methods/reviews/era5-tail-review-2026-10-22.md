# ERA5 residual-tail review

Author-facing diagnostic review of the curated ground histogram selection, 22 October 2026. The criteria are standard-lapse ERA5 station error SD >30 m or mean bias <−100 m. Nine stations meet the SD criterion and two meet the bias criterion; none meet both. The review itself applied no timestamp correction; the eleven stations were subsequently excluded through manual curation, documented in `ground-curation-and-spikes-2026-10-22.md`.

| Station | Mean bias (m) | SD (m) | Diagnostic interpretation |
|---|---:|---:|---|
| Qairoonhairiti | −148.5 | 4.2 | Stable offset throughout the year. Independent height documentation supports the listed site; the pressure-reference/site issue remains unresolved. |
| Sayak | −130.2 | 3.3 | Stable offset. Other station coordinates exist, but no independently verified explanation for the full discrepancy has been established. |
| Buzaubaj | −78.5 | 44.4 | Long periods of changing offset and a pronounced shift around June 2026. A pressure-reference or sensor problem is plausible but unconfirmed. |
| Sioux Falls SURFRAD | −46.6 | 40.9 | Clear shift across the July 2023 observation gap: January–June monthly biases are −75 to −92 m, compared with −3 to −9 m in August–December. NOAA independently confirms the listed coordinates and 473 m elevation, so an incorrect constant station height alone does not explain the time dependence. |
| TAS_A moving ice station | +27.9 | 64.9 | Broad continuous scatter. A moving ice installation is not a fixed reference elevation; movement, surface change and atmospheric representativeness are plausible contributors, not individually demonstrated causes of this SD. GEUS provides GPS positions and elevation as time-varying variables. |
| Nueva Casas Grandes | +16.4 | 40.0 | Abrupt downward shift of approximately 80–90 m in converted altitude around April 2025, followed by smaller changes. Station pressure has a corresponding step; a source/calibration/reference change is plausible. |
| Ma'an | +14.9 | 40.1 | Only nine retained reports deviate by >100 m from the station's median error. Their timestamps span 2–14 May 2023. Robust SD (MAD scaled by 1.4826) is 8.8 m, versus ordinary SD 40.1 m. |
| Itiruçu | −7.8 | 54.9 | Repeated large rapid pressure oscillations persist across the retained year. Twelve successive-report jumps exceed 10 hPa within three hours, but none exceed the current 20 hPa threshold. Robust SD remains 53.4 m, so this is not driven by a handful of extreme reports. |
| Crozet | +5.9 | 36.8 | Strong diagnostic evidence of temporal misalignment: pressure residual SD falls from 4.46 to 0.58 hPa when observations at t are compared with ERA5 at t−7 hours. Exact source timestamp interpretation remains unverified. |
| Kerguelen | +4.7 | 53.2 | Strong diagnostic evidence of temporal misalignment: pressure residual SD falls from 6.52 to 0.61 hPa when observations at t are compared with ERA5 at t−10 hours. Exact source timestamp interpretation remains unverified. |
| Johannesburg Botanical Gardens | +2.3 | 45.0 | A bad episode on 13–18 May 2026 accounts for 40 reports >100 m from the station median; most reports otherwise remain close to the reference. Robust SD is 4.1 m, versus ordinary SD 45.0 m. |

The current pressure-continuity criterion targets jumps >20 hPa within three hours or >50 hPa across gaps of up to seven days. Smaller steps, long-gap shifts and sparse bad episodes can therefore survive it. Identifying a failure pattern in ERA5 residuals is useful diagnostically, but does not by itself provide an independent rejection rule.

## Timestamp diagnostic

Expected station pressure is obtained by inverting the standard-lapse barometric conversion at the archive station height. For each integer shift from −12 to +12 hours, observed pressure is matched to this expected-pressure series and the residual SD is calculated. Crozet and Kerguelen improve sharply at nonzero shifts while retaining almost the full sample: 8,398 versus 8,406 pairs for Crozet, and 8,397 versus 8,408 for Kerguelen. This is evidence for a timing issue, not independent verification of a correct timestamp shift. Both stations carry source code 393; the public NOAA source-list PDF retrieved during this review does not define that code. Météo-France documents UTC for mainland hourly observations and FU for overseas observations, making a time-reference issue worth tracing, but this does not establish the actual GHCNh conversion or the required offset for these files. No empirical lag correction has been applied.

## Sources and outputs

- [NOAA Sioux Falls SURFRAD station metadata](https://gml.noaa.gov/grad/surfrad/sitepage.html).
- [GEUS TAS_Av3 hourly dataset metadata](https://thredds.geus.dk/thredds/dodsC/aws/l2stations/netcdf/hour/TAS_Av3_hour.nc.html): ablation site on ice, GPS-derived position and altitude; this current installation is context rather than a validated reconstruction of the retained 2022–2023 elevation history.
- [Météo-France hourly dataset documentation](https://www.data.gouv.fr/datasets/donnees-climatologiques-de-base-horaires).
- [NOAA GHCNh source list](https://www.ncei.noaa.gov/oa/global-historical-climatology-network/hourly/doc/ghcnh-source-list.pdf).

Rebuild with `Rscript scripts/drafts/high_bias_stations.R tails`, then `Rscript scripts/drafts/era5_tail_diagnostics.R`. Figures and numerical outputs use prefix `output/drafts/atmospheric-figures/era5_tail_review`. The time-series figures display all 11 stations across two pages, with retained station pressure on the left and converted ASL height on the right. Monthly summaries, robust-scatter diagnostics and lag comparisons are saved alongside them.
