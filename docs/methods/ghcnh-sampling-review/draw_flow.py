"""Draw the proposed selection logic; no station data are read."""
from pathlib import Path
from html import escape
from math import hypot
from PIL import Image, ImageDraw, ImageFont

scale = 2
canvas = Image.new("RGB", (1420 * scale, 1400 * scale), "white")
draw = ImageDraw.Draw(canvas)
font_dir = Path("/System/Library/Fonts/Supplemental")
draw.rounded_rectangle((45*scale,150*scale,1375*scale,1150*scale),radius=18*scale,fill="#f7f9fb",outline="#d4dde5",width=2*scale)


out = Path('paper/figures/supp_ghcnh_selection.svg')
parts = ['''<svg xmlns="http://www.w3.org/2000/svg" width="1420" height="1400" viewBox="0 0 1420 1400">
<defs><marker id="arrow" markerWidth="9" markerHeight="9" refX="8" refY="4.5" orient="auto"><path d="M0,0 L9,4.5 L0,9 Z" fill="#526273"/></marker></defs>
<rect width="1420" height="1400" fill="white"/>
<style>text {font-family:Arial,sans-serif;fill:#203041} .edge {fill:none;stroke:#526273;stroke-width:2;marker-end:url(#arrow)}</style>
<rect x="45" y="150" width="1330" height="1000" rx="18" fill="#f7f9fb" stroke="#d4dde5" stroke-width="2"/>

''']

def node(x, y, w, h, lines, fill='#ffffff', stroke='#8da0b1', size=21, bold=False):
    parts.append(f'<rect x="{x-w/2}" y="{y-h/2}" width="{w}" height="{h}" rx="12" fill="{fill}" stroke="{stroke}" stroke-width="2"/>')
    draw.rounded_rectangle(((x-w/2)*scale,(y-h/2)*scale,(x+w/2)*scale,(y+h/2)*scale),radius=12*scale,fill=fill,outline=stroke,width=2*scale)
    font = ImageFont.truetype(str(font_dir / ('Arial Bold.ttf' if bold else 'Arial.ttf')),size*scale)
    first = y - (len(lines)-1)*15 + 7
    for i,line in enumerate(lines):
        draw.text((x*scale,(first+i*30-7)*scale),line,font=font,fill="#203041",anchor="mm")
        parts.append(f'<text x="{x}" y="{first+i*30}" text-anchor="middle" font-size="{size}" font-weight="{"bold" if bold else "normal"}">{escape(line)}</text>')

def edge(points, label=None, xy=None):
    parts.append('<polyline fill="none" stroke="#526273" stroke-width="2" points="'+' '.join(f'{x},{y}' for x,y in points)+'"/>')
    draw.line([(x*scale,y*scale) for x,y in points], fill='#526273', width=2*scale)
    x,y=points[-1]; px,py=points[-2]; length=hypot(x-px,y-py); ux,uy=(x-px)/length,(y-py)/length
    head=[(x,y),(x-12*ux+5*uy,y-12*uy-5*ux),(x-12*ux-5*uy,y-12*uy+5*ux)]
    parts.append('<polygon fill="#526273" points="'+' '.join(f'{a},{b}' for a,b in head)+'"/>')
    draw.polygon([(a*scale,b*scale) for a,b in head],fill='#526273')
    if label:
        x,y=xy
        draw.text((x*scale,(y-7)*scale),label,font=ImageFont.truetype(str(font_dir / "Arial.ttf"),20*scale),fill="#435567",anchor="mm")
        parts.append(f'<text x="{x}" y="{y}" font-size="20" text-anchor="middle" fill="#435567">{escape(label)}</text>')

node(710,65,1000,76,['1. Group candidate stations'],fill='#edf3f8',bold=True,size=24)
node(710,220,600,84,['2. Assess candidates within each cell','Candidate available?'],fill='#edf3f8',bold=True,size=22)
edge([(710,103),(710,178)])
node(1180,220,300,80,['Leave cell','unrepresented'],size=22)
edge([(1010,220),(1030,220)],'No',(1020,202))
node(710,375,620,76,['2a. Prepare hourly observations'],size=24)
edge([(710,262),(710,337)],'Yes',(745,306))
node(710,540,600,86,['2b. Find a qualifying year','Coverage passes?'],fill='#edf3f8',size=23)
edge([(710,413),(710,497)])
node(200,540,280,86,['Earlier endpoint','available?'],fill='#edf3f8',size=22)
edge([(410,540),(340,540)],'No',(375,521))
edge([(200,497),(200,455),(710,455),(710,497)],'Yes: move back one day',(450,438))
edge([(200,583),(200,650),(30,650),(30,220),(410,220)],'No',(227,620))
parts.append('<text x="220" y="202" text-anchor="middle" font-size="21">Next candidate</text>')
draw.text((220*scale,195*scale),'Next candidate',font=ImageFont.truetype(str(font_dir / 'Arial.ttf'),21*scale),fill='#203041',anchor='mm')
node(710,730,600,86,['2c. Check station consistency','Pass?'],fill='#edf3f8',size=23)
edge([(710,583),(710,687)],'Yes',(745,642))
edge([(410,730),(30,730),(30,650)],'No',(350,711))
node(710,910,600,76,['Accept station'],fill='#eaf4f2',stroke='#5b9188',bold=True,size=24)
edge([(710,773),(710,872)],'Yes',(745,827))
node(710,1090,420,76,['Finish cell'],size=23)
edge([(710,948),(710,1052)])
edge([(1180,260),(1180,1020),(710,1020)])
edge([(920,1090),(1390,1090),(1390,125),(710,125),(710,178)],'More cells',(1210,1070))
node(710,1300,1000,80,['3. Summarize errors'],fill='#edf3f8',bold=True,size=24)
edge([(710,1128),(710,1260)],'All cells assessed',(815,1210))
parts.append('</svg>')
out.write_text('\n'.join(parts))
canvas.resize((1420,1400), Image.Resampling.LANCZOS).save(out.with_suffix(".png"))
print(out)
