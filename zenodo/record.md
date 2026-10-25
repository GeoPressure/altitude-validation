# Zenodo record (manual upload)

Reserved DOI: [10.5281/zenodo.23085093](https://doi.org/10.5281/zenodo.23085093). The record is an unpublished draft. The reviewer preview was verified on 25 October 2026.

## Upload files

Run `Rscript zenodo/make_archive.R` from the repository root to build `data/zenodo/altitude-validation-code.zip` and `data/zenodo/altitude-validation-data.zip`. This packages the current working tree and existing data caches; it does not rerun the analysis or render documents. It includes uncommitted and non-ignored untracked project files. Inspect the working tree before building. Use `Rscript zenodo/make_archive.R --code-only` to refresh only the code ZIP after editing documentation. Files already on the Zenodo draft are from the superseded workflow and must both be replaced.

The code archive includes existing rendered PDFs and HTML where present. Rebuild those separately when a final rendered manuscript is required; packaging does not synchronise them with edited QMD sources. Reviewer-access URLs in submission material should be replaced with the public DOI when the record is published.

## Metadata

- **Resource type:** Dataset
- **Title:** How accurate is altitude from pressure geolocators? Code and data for a global assessment of three pressure-to-altitude conversions
- **Creators:** Nussbaumer, Raphaël; Swiss Ornithological Institute, Sempach, Switzerland; ORCID 0000-0002-8185-1020. Gravey, Mathieu; Institute for Interdisciplinary Mountain Research, Austrian Academy of Sciences, Innsbruck, Austria; ORCID 0000-0002-0871-1507.
- **Version:** v1
- **Publication date:** Set to the actual publication date when publishing; the current draft displays 1 October 2026.
- **Licence:** CC BY 4.0 for original derived data and manuscript material; identify MIT separately for code. Third-party inputs retain their source terms; see the data README.
- **Keywords:** geolocator; barometric altimetry; ERA5; GPT3; bird migration; flight height; GHCNh; IGRA2; validation
- **Community:** geolocator-dp, if appropriate to the community's scope and accepted by its curators.
- **Description:** Paste the plain text in `zenodo/description.txt`.
- **Related works:** is supplement to https://github.com/GeoPressure/altitude-validation; references https://github.com/GeoPressure/GeoPressureR; references 10.25921/jp3d-3v19 (GHCNh), 10.7289/V5X63K0Q (IGRA2), 10.24381/cds.adbb2d47 (ERA5), 10.24381/cds.e2161bac (ERA5-Land), 10.1007/s00190-017-1066-2 (GPT3), and 10.5281/zenodo.18187093 (bird trajectories).

Use the GitHub repository as the documentation link. The former GitHub Pages report and HadISD/GNSS/MeteoSwiss description do not describe the current study. Add the manuscript DOI as a related publication when available. For later releases, use Zenodo's “New version” workflow.
