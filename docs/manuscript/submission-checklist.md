# Movement Ecology submission preparation

Prepared on 23 October 2026 against the [general submission guidelines](https://link.springer.com/journal/40462/submission-guidelines) and [Methodology instructions](https://link.springer.com/journal/40462/submission-guidelines/methodology).

## Prepared

- Article type: Methodology; the cover letter explains the tested computational advance and relevance to movement ecology.
- Main manuscript: double-spaced review format, continuous line numbers and page numbers; structured abstract; seven keywords; abbreviation definitions and list; required declarations; AI-use disclosure; additional-file description.
- Funding: no dedicated research funding, confirmed by the corresponding author. Acknowledgements: Not applicable for now, as requested.
- Ethics: secondary analysis of public bird-tracking data, with no new capture, handling or experimentation; original collection information is attributed to the source dataset and studies.
- Website documentation is cited through numbered bibliography entries. Repository DOI links remain in the availability statement.
- Main figures are supplied as individual PDF files with embedded fonts. The supplement is named Additional_file_1.pdf for upload.
- `bash paper/render.sh` rebuilds the manuscript and supplement in PDF and HTML. `python3 scripts/submission/prepare_submission.py` produces the upload files in `output/submission/` and the editable source ZIP.
- `Rscript zenodo/make_archive.R` builds the code and data archives in `data/zenodo/`. It includes the current working tree so recent analysis changes are included without making a Git commit.

## Before actual submission

- Publish the prepared Zenodo code/data archives, or provide a working private reviewer link. On 23 October 2026, the record API and DOI for 10.5281/zenodo.23085093 returned HTTP 404. The manuscript describes the identifier as reserved. After publication, change that sentence to state that the archive is available in Zenodo and verify the download links.
- Obtain Mathieu's final approval. The corresponding author asked that approval be assumed during preparation; approval itself has not been verified. The cover letter contains the approval and exclusivity declarations on that requested assumption; verify them before actually sending it.
- Confirm that the AI-use statement accurately describes assistance and that both authors have checked the final code, results, citations and text.
- Confirm institutional open-access coverage or payment arrangements and the publication licence in the submission portal. These are not determined by the absence of research funding.
- Upload manuscript.pdf, latex-source.zip, Figure_1.pdf through Figure_5.pdf, Additional_file_1.pdf and the finalized cover letter. The cover letter source is `paper/cover-letter.md`; rebuild its PDF with `quarto render paper/cover-letter.md --to pdf` before packaging. Enter both authors' information from the manuscript title page.

## Validation limits

Local pdfLaTeX compilation uses TeX Live 2026. Compatibility with the journal's stated TeX Live 2021 environment requires verification by its submission compiler; that older environment is not installed locally.
