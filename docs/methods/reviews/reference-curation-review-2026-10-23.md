# Reference curation and pressure-pattern review

Author-facing review, 23 October 2026. The main selection excludes independently documented station-reference conflicts and candidates explicitly labelled moving ice installations. Large ISA departures alone do not exclude a station, and ERA5 error is not an accept/reject criterion. The pressure episode and coverage thresholds are unchanged.

## Reference exclusions

The exclusion list contains 39 moving ice installations in the frozen candidate catalogue and 20 documented reference conflicts. Eleven reference conflicts were identified in this review, including four established in the initial ISA-tail investigation, five established in the follow-up, and two found while checking replacement candidates. The remaining nine reference conflicts were already documented. All exclusions are applied before pressure-window selection; replacement candidates follow the existing order and checks.

| ID | Archive reference | Independent evidence | Decision |
| --- | --- | --- | --- |
| CIM00085410 | Chorrillos, 3,200 m | WMO 85410 is Azapa Alto, 838 m, at different coordinates | Exclude |
| CHM00059948 | Sanya, 7 m | CMA gives WMO 59948 an elevation of 419.4 m | Exclude |
| CHI0000ZLYA | Yan An, 959 m | Raw WMO 53845 identifies Yanan, 1,180.4 m | Exclude |
| RPI0000RPUB | Baguio, 1,295.7 m | PAGASA gives WMO 98328 a barometer height of 1,501 m | Exclude |
| INM00042114 | Tehri, 770 m | IMD 1991–2020 tables place Tehri at 30°23′ N, 78°26′ E, 1,575 m, whereas the archive uses the older reference | Exclude |
| INI0000VILH | Leh airport reference, 3,255.9 m | The retained record includes WMO 42034; IMD gives Leh observatory 3,513 m. IEM independently identifies VILH as the airport at approximately 3,258 m | Exclude the merged record with incompatible references |
| INM00042308 | Itanagar/Papumpare, 413 m | IMD gives WMO 42308 Itanagar an elevation of 202.73 m | Exclude |
| PEM00084614 | Tarma, 3,200 m | SENAMHI lists CO-Tarma at 3,000 m and coordinates 11°23′49″ S, 75°41′25″ W, matching the archive location to its precision | Exclude |
| IRM00040756 | Garmsar, 900 m | Raw WMO 40756 identifies Firouzkooh in archived IRIMO Form 10, with elevation 1,975.6 m and a different location | Exclude |
| IRM00040770 | Qom, 928 m | IRIMO Form 3 identifies WMO 40770 at 877.4 m and 34°42′ N, 50°51′ E, differing from archive coordinates 34.65° N, 50.9° E | Exclude replacement candidate |
| IRI0000OIFK | Kashan airport, 1,056.1 m | IEM links OIFK and this GHCNh ID to WMO 40785 at city coordinates 33.98333° N, 51.45° E and 982 m, differing from archive airport coordinates 33.8953° N, 51.577° E | Exclude replacement candidate |

Sources: [Chile: Azapa Alto](https://climatologia.meteochile.gob.cl/application/informacion/fichaDeEstacion/180047); [CMA station inventory, PDF pages 2 and 5](https://image.data.cma.cn/static/doc/A/A.0012.0001/SURF_CHN_MUL_HOR_STATION_EN.pdf); [PAGASA Baguio](https://wis.pagasa.dost.gov.ph/oapi/collections/stations/items/0-20000-0-98328?f=html); [IMD climatological tables, PDF pages 359, 479 and 773](https://imdpune.gov.in/library/public/Climatological%20Tables%201991-2020.pdf); [IEM VILH station metadata](https://mesonet.agron.iastate.edu/sites/site.php?network=IN__ASOS&station=VILH); [SENAMHI inventory, PDF page 5](https://www.senamhi.gob.pe/load/file/02950SENA-85.pdf); [IRIMO Firouzkooh Form 10, archived 2014](https://web.archive.org/web/20140912055443/http://www.chaharmahalmet.ir/stat/archive/iran/teh/FIROUZKO/10.asp). The IMD and SENAMHI rows were checked in rendered PDF pages. The IRIMO header was retrieved from the archived original HTML; a local copy is in `output/drafts/reference-curation/irimo-firuzkuh.html`.

The documented discrepancy need not explain every metre of the ERA5 error to invalidate the archive reference. In particular, IMD's Tehri height differs from both the archive and the height suggested by pressure conversion. The exclusion is based on conflicting independent location/elevation metadata, rather than selecting a replacement elevation to fit ERA5.

The two replacement candidates were checked before finalising their cell. Qom has mean ERA5 error −55.5 m and SD 6.3 m; its smooth pressure record does not reveal the reference discrepancy documented in [IRIMO's archived Qom Form 3](https://web.archive.org/web/20140906134337/http://www.chaharmahalmet.ir/stat/archive/iran/qom/GHOM/3.asp). Kashan's qualifying year has mean ERA5 error −101.3 m and SD 6.6 m; [IEM metadata explicitly link its ICAO and GHCNh identifiers to the city WMO station](https://mesonet.agron.iastate.edu/sites/site.php?network=IR__ASOS&station=OIFK), while the archive uses the airport reference. This reproduces the kind of airport/city conflict documented for other stations. Both are excluded on metadata grounds. Garmsar, Qom and Kashan are the three frozen candidates in cell `22_21`, leaving that cell without an eligible fixed reference.

## Final selection

The selection retains 2,179 GHCNh stations and 11,683,676 observations, versus 2,192 stations and 11,745,654 observations before this curation. Thirteen previously represented cells lose their station: four moving installations and nine catalogue conflicts. No replacement remains eligible after the reference review. The two additionally excluded replacement candidates, Qom and Kashan, were not part of the initial 2,192-station sample. All retained stations keep their previous selected year, and all 28 ISA-tail stations with absolute ERA5 mean bias below 25 m remain selected. Isolated-spike screening removes 1,370 reports from the retained windows. The IGRA sample remains at 643 stations.

The complete rebuild (`Rscript run_all.R ground_selection prepare analysis figures check`) passed. All 2,179 ground years passed full-history pressure episode checks, exact agreement with cleaned pressure records, and monthly coverage. Numerical integration checks passed for station IDs, cell balance, observation counts, selected windows, direct conversions and analysis weights. Analysis tables and figures were regenerated; the selection diagram and ground histogram were visually inspected. The run log is `logs/reference-curation-complete.log`. Rendered manuscript documents were not rebuilt during this review.

## Four unresolved large offsets

| Station | ERA5 mean bias before curation | Pressure-pattern finding | Decision |
| --- | ---: | --- | --- |
| Limoncocha, ECM00084075 | +2,183.0 m | Coherent selected-year pressure of 760.1–769.3 hPa; no short record or isolated spike explains the persistent offset | Retain pending an independently established identity or pressure-reference error |
| Kithira, GRI0000LGKC | −154.6 m | Smooth weather variability with a very stable offset; annual error SD 4.5 m | Retain; reference mismatch is plausible but not demonstrated for the retained ICAO reports |
| Sinan, CHM00057731 | +156.5 m | Coherent annual pressure cycle; nearly identical median error on either side of the April 2026 source transition | Retain; CMA elevation 416.8 m agrees with archive 418 m |
| Xining, CHI0000ZLXN | +168.3 m | Coherent variability, stable offset across the April source transition | Retain; CMA lists WMO 52866 at 2,295.2 m and a different location, but the precise identity/reference of the retained ICAO and WMO reports is unresolved |

For Kithira, [SMHI's foreign station list](https://www.smhi.se/polopoly_fs/1.3281!utl_stationslista.pdf) places WMO 16743 at 167 m, close to the pressure-implied height, while [IEM's Greek airport table](https://mesonet.agron.iastate.edu/sites/networks.php?network=GR__ASOS&station=LGKF) places ICAO LGKC at 319 m, close to our archive's 318.5 m. The retained record uses ICAO LGKC and source 223. A WMO-versus-airport or pressure-reference mix-up is therefore a concrete hypothesis, but those two listings alone do not establish which site supplied the retained measurements.

The four stations remain in the main sample because this investigation does not establish an independent exclusion basis. Their source-specific medians and full records are available for inspection. A smooth series with a fixed offset can evade time-series quality checks; increasing the record-length requirement would not resolve this issue.

## Other visible patterns

Three stations from the ISA-tail review illustrate patterns that a small annual mean error can conceal. They remain selected in this curation, which addresses reference validity rather than adding a new pressure rule.

- **Halvfarryggen, AYM00089003:** a largely coherent record develops multi-day positive pressure excursions in December 2025–January 2026, reaching ERA5 errors below −400 m. January's two-week close-up shows broad rises and reversals rather than isolated one-report spikes. The current rapid-jump and repeated-reversal thresholds do not reject this selected year.
- **La Quiaca, ARI0000SASQ:** the ERA5 error changes abruptly from roughly +35 m to −30 m during March 2025, while the reporting source remains 223. The corresponding pressure level changes by roughly 5 hPa, below the current 20 hPa rapid-jump threshold. A persistent pressure-reference change is a plausible explanation; ERA5 is used here to diagnose the pattern, not to decide exclusion.
- **San Luis, COI0000SKIP:** source 223 is substantially more scattered than source 412 after the April 2026 transition, but the central error remains around −25 m. The later pressure values also show discrete bands. Changing precision or source processing can explain visible texture changes; the plot alone does not establish a faulty sensor.

These patterns motivate reviewing sustained excursions and smaller level shifts in pressure itself, with thresholds justified independently of ERA5. No additional station or year was excluded on those diagnostic patterns in this implementation.

## Inspect the plots

Run `Rscript scripts/drafts/reference_curation_review.R` from the repository root. This script uses the saved pre-curation tail records for the nine unresolved-at-start stations, including the five reference conflicts subsequently established, accepted records for the three pattern examples, and cached pressure/atmospheric inputs to reconstruct the two replacement-candidate years. It does not alter selection.

Outputs are in `output/drafts/reference-curation/`. `review_page1.png` through `review_page4.png` show pressure and ERA5 error for all 14 reviewed stations. Each station also has an individual `<ID>.png` containing the full available pressure history, reviewed pressure year, ERA5 errors with daily medians, and a fortnight around the largest within-day error range. The reviewed year is shaded in the full-history panel. Colours identify archive sources; gaps longer than 12 hours are unconnected. `source_comparison.csv` provides source-specific counts, date spans and median pressures/errors.
