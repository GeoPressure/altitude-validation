# GPS/barometer report: source and reproduction notes


All ten core papers were read in full text from PDFs in `literature/references/`; the source locations are listed below. Direct DOI links accompany each summary. Numerical claims were checked against the named sections, tables or figures, rather than inferred from plotted marks. Reviews and citations encountered in these papers provided context but were not treated as independently read primary evidence. This report intentionally does not repeat the songbird literature catalogue in `review-T01-T03.md`.

| Study | Local PDF | Key evidence location |
|:--|:--|:--|
| Lato 2022 | `lato2022.pdf` | Abstract; trial Methods/Results; Figures 5–6 |
| Schaub 2023 | `schaub2023.pdf` | Methods/Results; Figure 2; supplement, p. 5 |
| Péron 2020 | `peron2020.pdf` | Experimental tests; negative-height section; Figure 3 |
| Ross-Smith 2016 | `rosssmith2016.pdf` | Accepted manuscript; Results; Figures 1–6 |
| Cleasby 2015 | `cleasby2015.pdf` | Altitude calibration; flight-height Results; Figure 5 |
| Johnston 2023 | `johnston2023.pdf` | Calibration Methods; Results; Figure 6 |
| Miller 2026 | `review_S095927092610063X.pdf` | Figures 2–5; Table 1 |
| Clark 2019 | `clark2019.pdf` | Abstract; altitude Methods; Figures 3 and 6 |
| Lempidakis 2024 | `lempidakis2024.pdf` | Abstract; Methods; Figures 1–4 |
| Senner 2018 | `senner2018.pdf` | Tracking Methods; Results; Figures 2–3; Table 1 |

The six reproduced figures are attributed individually and retain their original scientific marks. Page-edge prose and/or original captions were cropped away; the captions in this report are newly written reading guides. The reproduced sources carry Creative Commons Attribution licences (CC BY; 4.0 where specified); retain attribution and the [licence link](https://creativecommons.org/licenses/by/4.0/) when reusing the report. Figure file paths, source PDF hashes, page numbers and crop coordinates are recorded in `docs/assets/gps-barometer/manifest.json`. The accepted Ross-Smith manuscript and Lempidakis publisher PDF were obtained from institutional repositories; their source URLs are in `docs/assets/gps-barometer/source_downloads.json`. No figure from the Ross-Smith accepted manuscript is reproduced here.

Rebuild the figure crops with `python docs/scripts/extract_gps_review_figures.py` from the repository root, using Python with Pillow and Poppler's `pdftoppm` on the path. The report is maintained directly as [Markdown](gps-barometer-ecology.md); it no longer has Quarto, HTML or PDF copies. This literature-review record contains no executable analysis. Later manuscript edits are documented in [the response plan](../../archive/docs/manuscript/comment-response-plan.md).
