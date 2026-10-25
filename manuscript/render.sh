#!/usr/bin/env bash
# Render the manuscript and supplement (Springer Nature sn-jnl class) and assemble the journal
# upload files in manuscript/submission/. Run from anywhere; requires Quarto and pdfLaTeX.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
export TEXINPUTS="$PWD/vendor:${TEXINPUTS:-}"
quarto render paper.qmd --to pdf
quarto render supplement.qmd --to pdf
quarto render cover-letter.md --to pdf

# Upload files: manuscript, supplement, cover letter, figures and an editable LaTeX source.
out=submission
rm -rf "$out" && mkdir -p "$out/latex-source/figures"
cp paper.pdf "$out/manuscript.pdf"
cp supplement.pdf "$out/Additional_file_1.pdf"
cp cover-letter.pdf "$out/cover-letter.pdf"
n=1
for f in fig1_column fig2_stations fig3_ground fig4_flight fig5_conditions; do
  cp "figures/$f.pdf" "$out/Figure_$n.pdf"
  n=$((n + 1))
done
sed 's|]{vendor/sn-jnl}|]{sn-jnl}|' paper.tex > "$out/latex-source/paper.tex"
cp vendor/sn-jnl.cls references.bib "$out/latex-source/"
cp figures/fig*.pdf "$out/latex-source/figures/"
(cd "$out/latex-source" && zip -qr ../latex-source.zip .)
rm -rf "$out/latex-source"
echo "Upload files written to manuscript/$out"
