"""Package the rendered LaTeX sources and journal upload files. Run after paper/render.sh."""
from pathlib import Path
import re
import shutil
import zipfile

root = Path(__file__).resolve().parents[2]
out = root / 'output/submission'
out.mkdir(parents=True, exist_ok=True)
source = out / 'latex-source'
if source.exists():
    shutil.rmtree(source)
source.mkdir()

for stem in ('paper', 'supplement'):
    text = (root / f'paper/{stem}.tex').read_text()
    for name in re.findall(r'\\includegraphics(?:\[[^\]]*\])?\{([^}]+)\}', text):
        original = (root / 'paper' / name).resolve()
        target = Path('figures') / ('main' if stem == 'paper' else 'supplement') / original.name
        (source / target).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(original, source / target)
        text = text.replace('{' + name + '}', '{' + target.as_posix() + '}')
    (source / f'{stem}.tex').write_text(text)
shutil.copy2(root / 'paper/vendor/sn-jnl.cls', source)
shutil.copy2(root / 'paper/references.bib', source)
(source / 'README.txt').write_text(
    'Main document: paper.tex\nSupplement: supplement.tex\n'
    'Compile each document twice with pdflatex; references are embedded in the TeX.\n'
    'The source files are generated from paper/paper.qmd and paper/supplement.qmd.\n'
    'Upload Additional_file_1.pdf separately as supplementary material.\n'
)
with zipfile.ZipFile(out / 'latex-source.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(source.rglob('*')):
        if path.is_file():
            archive.write(path, path.relative_to(source))
shutil.copy2(root / 'paper/paper.pdf', out / 'manuscript.pdf')
shutil.copy2(root / 'paper/supplement.pdf', out / 'Additional_file_1.pdf')
shutil.copy2(root / 'paper/cover-letter.md', out / 'cover-letter.md')
shutil.copy2(root / 'paper/cover-letter.pdf', out / 'cover-letter.pdf')
for number, name in enumerate(('fig1_column', 'fig2_stations', 'fig3_ground', 'fig4_flight', 'fig5_conditions'), 1):
    shutil.copy2(root / f'paper/figures/{name}.pdf', out / f'Figure_{number}.pdf')
print(out)
