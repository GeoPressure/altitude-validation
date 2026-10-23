# Pressure-anomaly histogram tail

The top-left panel of `supplement_sensitivity_draft` shows one median per accepted GHCNh station of ERA5 surface pressure minus ISA pressure at the same ERA5 surface elevation. It describes departure from a fixed atmosphere, not pressure measurement error. The ISA calculation uses sea-level pressure 101325 Pa, temperature 288.15 K and lapse rate −0.0065 K/m.

Of 2,130 stations, 33 have median anomalies below −15 hPa: 32 in Antarctica and one at Grytviken, South Georgia. The most negative medians are Amundsen–Scott (−39.16 hPa), Vostok (−34.72 hPa), Dome C II (−34.70 hPa), Dome Plateau Eagle (−33.94 hPa) and Ski-Blu (−33.23 hPa). These stations form a regional tail rather than geographically scattered anomalies.

Independent recomputation from all accepted observations at these 33 stations reproduced the exported medians to <1e−10 hPa. ERA5 elevations were constant through each record. Fresh ERA5 surface-pressure extraction at 12 saved timestamps each for Amundsen–Scott, Vostok and Neumayer reproduced cached values to <1e−6 Pa.

| Station | ERA5 elevation (m) | Median ERA5 pressure (hPa) | ISA pressure at ERA5 elevation (hPa) | Median observed pressure (hPa) |
|---|---:|---:|---:|---:|
| Amundsen–Scott | 2789 | 680.9 | 720.1 | 679.6 |
| Vostok | 3487 | 624.0 | 658.7 | 623.1 |
| Neumayer | 33 | 979.3 | 1009.3 | 978.7 |

Observed pressure is measured at the reported station elevation, which can differ from ERA5 elevation; the table is a plausibility check, not a paired pressure-error calculation.

At the 12 sampled timestamps, median ERA5 mean-sea-level pressure departures from 1013.25 hPa were −28.89 hPa at Neumayer, −10.79 hPa at Amundsen–Scott and −1.07 hPa at Vostok. Surface departures at the corresponding ERA5 elevations were −29.16, −43.48 and −36.58 hPa. These sampled values support a combination of low regional pressures and nonstandard atmospheric-column structure; mean-sea-level reduction is itself model-derived and is not an independent validation.

No pressure calculation or extraction problem was identified. Retain the tail, and identify its Antarctic/Southern Ocean origin in an annotation or caption if this draft is developed. Station-level review values are in `output/drafts/atmospheric-figures/pressure_tail_review.csv`. No manuscript or figure was changed for this review.

## Separate climate-label bug

`scripts/07_static.R` sets `koppen_main` to the first character of the kgc lookup result and retains A–E. The lookup sometimes returns the text `Climate Zone info missing`; its initial C consequently becomes `C temperate` in `load_stations()`. This affects 93 GHCNh and 15 IGRA2 stations in the current station table. Neumayer and Brunt AWS are two affected tail stations. The pressure histogram and its numerical medians do not depend on climate labels. Climate-stratified results, labels and any example selection using those labels need to be regenerated after repairing the classification. The correction maps missing lookup results to NA before deriving the main climate zone, preserves missing values when loading station metadata, and excludes unclassified stations only from climate-specific summaries. The ground and flight climate summaries and associated figures were regenerated. All ten stations in the fixed position-displacement pilot retain valid classifications. Overall ground and flight error summaries are unchanged. Reapplying the Figure 1 selection rules selects Cairo Regional Airport for the weather record and Lake Charles for the summer sounding; the winter sounding remains Lincoln.
