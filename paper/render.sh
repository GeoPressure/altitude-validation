#!/usr/bin/env bash
# Render the manuscript to PDF (Springer Nature sn-jnl class, keeping the .tex) and to HTML.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
export TEXINPUTS="$PWD/vendor:${TEXINPUTS:-}"
quarto render paper.qmd --to pdf
quarto render paper.qmd --to html
quarto render supplement.qmd --to pdf
quarto render supplement.qmd --to html
