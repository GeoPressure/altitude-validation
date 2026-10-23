# Standard-atmosphere uncertainty estimates and discussion comparison

Author-facing review, 23 October 2026. Original full texts were checked against the current manuscript and the current `paper_ground_tails.csv` and `paper_flight_tails.csv` tables. The discussion implementation and its numerical basis are recorded below; the proposed paragraphs at the end document the earlier review options.

## Implemented discussion structure

The opening Discussion paragraph retains the practical, accessible-method argument and adds the rounded flight-height guidance. Ecology follows immediately, with an interpretive transition. The literature comparison follows the atmospheric-input paragraph and precedes remaining measurement uncertainty, so it evaluates earlier estimates without interrupting the main finding-to-ecology progression. Content outside Discussion was preserved. Validation: the manuscript PDF and HTML rendered successfully without unresolved citation warnings; all Discussion citation keys resolve, and visual inspection of PDF pages 9–12 confirmed readable text, citations and table layout.

The approximate 4% to 1% median absolute error and 10% to 3% p95 summaries apply only to the four reporting bands spanning 0.5–3 km above the sounding surface. Dividing each band statistic by its midpoint gives the following ranges; these are descriptive summaries, not fitted uncertainty functions or total-error intervals.

| Conversion | Median absolute error / band midpoint | p95 absolute error / band midpoint |
| --- | --- | --- |
| Standard atmosphere | 3.36–4.40% | 7.54–9.53% |
| ERA5, standard lapse rate | 0.96–1.27% | 3.50–4.71% |
| ERA5, virtual temperature + GPT3 | 0.70–0.97% | 2.73–3.22% |

## Source findings

| Study | Conversion and uncertainty statement | Source location and interpretation |
| --- | --- | --- |
| [Sjöberg et al. (2018)](https://doi.org/10.1111/jav.01821) | Standard-atmosphere altitudes can differ by several hundred metres at ground level and by more than 10% at several kilometres. Their general conclusion describes reducing error to ±100 m or less using geopotential-height information from reanalysis. | `literature/references/sjoberg2018.pdf`, Methods, p. 3, and General conclusion, p. 8. They compare NCEP/NCAR geopotential heights with standard-atmosphere heights at three pressure levels for broad travel segments of two birds. The ±100 m statement concerns correction, rather than the accuracy of the uncorrected standard atmosphere; it is not specified as an empirical 95% interval. |
| [Dufour et al. (2026)](https://doi.org/10.1016/j.isci.2025.114466) | ERA5 ground pressure and temperature are used for conversion. The methods give an expected error of approximately ±100 m, combining sensor resolution, ERA5 biases and geolocation error. | `literature/references/dufour2026.pdf`, STAR Methods, p. e2 (PDF p. 14). This is a combined expected uncertainty for a weather-informed conversion, not an uncorrected standard-atmosphere error or a stated 95% interval. Its supporting references are Liechti et al. (2018) and Nussbaumer et al. (2023), “Reconstructing bird trajectories…”. |
| [Liechti et al. (2018)](https://doi.org/10.1186/s40462-018-0137-1) | Uses standard atmospheric conditions; describes deviations of several tens of metres and states that passing high- and low-pressure systems rarely cause height differences above 200 m (approximately 25 hPa). | `literature/references/liechti2018.pdf`, Altitude measurements, p. 4. This gives useful context for weather-driven reference-pressure errors, but is not a global empirical tail estimate and does not establish a universal bound on temperature-profile error. |
| [Lindström et al. (2021)](https://doi.org/10.1016/j.cub.2021.05.047) | Presents standard-atmosphere altitudes and uses weather data to assess deviations: approximately 80 m underestimation at 3,000 m in Europe in autumn and 400 m at 7,200 m over Africa in spring. | `literature/references/lindstrom2021.pdf`, STAR Methods, Estimating altitude, p. e2 (PDF p. 9), and Table S2. These are estimates for particular regions, seasons and pressure levels, rather than universal uncertainty bounds. The 7,200 m example is outside our evaluated 0–6 km above-surface range and uses a different vertical reference. |

The two explicit statements around ±100 m located in this review are Sjöberg et al. (2018) and Dufour et al. (2026). Only the former places the statement in its concluding discussion; the latter states it in the methods. Neither supports describing ±100 m as the general uncertainty of an uncorrected standard atmosphere.

## Comparison with the current results

### Alerstam and Liechti precedents

These are particularly relevant to discussing the uncorrected standard atmosphere. Alerstam is a coauthor of Sjöberg et al. (2018), Lindström et al. (2021), and [Sjöberg et al. (2023), “Solar heating may explain extreme diel flight altitude changes in migrating birds”](https://doi.org/10.1016/j.cub.2023.08.035). The latter's STAR Methods, “Details about logger data,” state that standard-atmosphere heights may differ by ±10% from true geopotential altitudes depending on local conditions. At 3,000 m, 10% corresponds to 300 m, although the statement is not a calibrated confidence interval. The same paragraph separately gives sensor accuracy of approximately ±1 hPa (approximately ±8 m), illustrating why device accuracy must be distinguished from atmospheric conversion accuracy.

For a discussion focused on standard-atmosphere assumptions, lead with Liechti (2018), Lindström (2021), and Sjöberg (2023), alongside Sjöberg (2018). Their estimates already recognize weather- and height-dependent error. Our contribution is to quantify the distributions across a broad reference sample and compare corrections, rather than establish that such errors exist for the first time. Dufour (2026) is better placed as a separate example of combined uncertainty after weather correction.

Alternative discussion opening: “Previous tracking studies recognized that standard-atmosphere altitudes can depart from actual heights as atmospheric conditions change. Liechti et al. [@liechti2018] described deviations of several tens of metres, with pressure-system effects rarely exceeding 200 m, while Lindström et al. [@lindstrom2021] estimated underestimation of approximately 80 m at 3,000 m and 400 m at 7,200 m under particular regional and seasonal conditions. Sjöberg et al. [@sjoberg2023] noted potential deviations of ±10%. Our global reference comparisons quantify how these errors vary across conditions and heights and how much local atmospheric information reduces them.” Follow with the existing numerical contrast and retain the difference in vertical references and error statistics when interpreting these comparisons.

| Evaluation | Standard atmosphere: median / p95 absolute error (m) | ERA5, standard lapse rate | ERA5, virtual temperature + GPT3 |
| --- | --- | --- | --- |
| Ground, retained GHCNh stations | 38.1 / 140 | 3.7 / 15 | 3.7 / 15 |
| Flight, 2–3 km above sounding surface | 93.3 / 235 | 31.8 / 118 | 24.1 / 81 |
| Flight, 5–6 km above sounding surface | 236.1 / 389 | 92.6 / 262 | 79.1 / 235 |

These values support replacing a single rule of thumb with height- and method-specific uncertainty summaries. At 2–3 km, even after subtracting the altitude estimated at the sounding surface, 5% of standard-atmosphere absolute errors exceed approximately 235 m. The full correction reduces that threshold to 81 m, but the corresponding threshold reaches 235 m at 5–6 km. Thus, ±100 m is neither a general bound for the standard atmosphere nor a general bound for corrected flight heights.

The comparison should remain descriptive. Our flight errors isolate surface-referenced atmospheric conversion error and exclude added sensor error and absolute surface-reference error. Our ground discrepancies retain uncertainty in reference elevations. The prior ±100 m estimates do not specify the same error statistic or evaluated population, so our p95 values cannot establish a factor-of-improvement over those studies or validate their total-error estimates. No reanalysis of their bird records was undertaken.

## Proposed discussion paragraph

Suggested position: after the opening Discussion paragraph, before the ecological implications. Inline R expressions below use the manuscript's existing lookup functions and avoid freezing the numerical results in the source.

Previous studies provide useful uncertainty estimates for pressure-derived altitudes. Sjöberg et al. [@sjoberg2018] described standard-atmosphere deviations of several hundred metres and suggested that reanalysis-based correction could reduce errors to approximately ±100 m or less. Dufour et al. [@dufour2026], using ERA5 surface pressure and temperature, likewise reported an expected combined uncertainty of approximately ±100 m from sensor, atmospheric and positional errors. Our results show how the atmospheric component varies with conversion method and height. At 2--3 km above the sounding surface, the 95th percentile of absolute error was `r r0(ftval("isa", km["b4"]))` m with the standard atmosphere and `r r0(ftval("virtual", km["b4"]))` m with the full correction, rising to `r r0(ftval("virtual", "(5e+03,6e+03]"))` m at 5--6 km. These surface-referenced errors exclude added sensor and absolute surface-reference errors, so they are not directly equivalent to earlier combined uncertainty estimates. They nevertheless show why uncertainty should be specified for the conversion and height range being interpreted.
