---
format:
  pdf:
    documentclass: article
    pdf-engine: pdflatex
    fontsize: 11pt
    geometry: margin=2.5cm
    include-in-header:
      text: |
        \usepackage{ragged2e}
        \AtBeginDocument{\RaggedRight\pagestyle{empty}}
        \setlength{\parskip}{0.8em}
---

14 November 2026

\vspace{0.6em}

Dear Editors,

Please consider our manuscript, “A global assessment of three pressure-to-altitude conversions for geolocators on the ground and in flight”, for publication as an Article in Scientific Reports.

Lightweight archival pressure sensors reveal the altitudes of small migratory birds throughout the year, both in flight and on the ground. However, converting pressure to altitude introduces atmospheric errors that can affect ecological interpretation. We evaluate three conversions against weather-station and radiosonde observations worldwide, distinguish persistent bias from temporal variability, and use flight heights from 203 tracked birds to put these errors in ecological context.

We show that local ERA5 surface conditions substantially reduce altitude errors, while virtual temperature and a climatological temperature lapse rate further reduce systematic flight-height bias. This computationally simple conversion is implemented in [GeoPressureR](https://geopressure.org/GeoPressureR) (v3.7.0) and requires only measured pressure, its time and an approximate position. Our evaluation quantifies the remaining uncertainty relevant to migration altitude, elevational movements and flight-height thresholds. The study provides a global assessment of atmospheric conversion errors relevant to biologging and barometric altimetry, combining meteorological reference observations with an application to animal tracking.

The manuscript has not been published previously and is not under consideration elsewhere.

\vspace{0.6em}

Yours sincerely,

\vspace{0.6em}

Raphaël Nussbaumer and Mathieu Gravey
