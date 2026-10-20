"""Render the proposed IGRA process as matching SVG and PNG figures."""
from pathlib import Path
from html import escape
from math import hypot
from PIL import Image, ImageDraw, ImageFont

out = Path("paper/figures/supp_igra_selection.svg")
scale = 2
canvas = Image.new("RGB", (1420 * scale, 1230 * scale), "white")
draw = ImageDraw.Draw(canvas)
fonts = Path("/System/Library/Fonts/Supplemental")
parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="1420" height="1230" viewBox="0 0 1420 1230">', '<rect width="1420" height="1230" fill="white"/>', '<style>text{font-family:Arial,sans-serif;fill:#203041}</style>', '<rect x="45" y="150" width="1330" height="830" rx="18" fill="#f7f9fb" stroke="#d4dde5" stroke-width="2"/>']
draw.rounded_rectangle((45*scale,150*scale,1375*scale,980*scale), radius=18*scale, fill="#f7f9fb", outline="#d4dde5", width=2*scale)


def label(x, y, text, size=21, bold=False):
    font = ImageFont.truetype(str(fonts / ("Arial Bold.ttf" if bold else "Arial.ttf")), size*scale)
    draw.text((x*scale, (y-7)*scale), text, font=font, fill="#203041", anchor="mm")
    parts.append(f'<text x="{x}" y="{y}" text-anchor="middle" font-size="{size}" font-weight="{"bold" if bold else "normal"}">{escape(text)}</text>')


def node(x, y, width, height, lines, fill="#ffffff", bold=False):
    box = (x-width/2, y-height/2, x+width/2, y+height/2)
    draw.rounded_rectangle(tuple(v*scale for v in box), radius=12*scale, fill=fill, outline="#8da0b1", width=2*scale)
    parts.append(f'<rect x="{box[0]}" y="{box[1]}" width="{width}" height="{height}" rx="12" fill="{fill}" stroke="#8da0b1" stroke-width="2"/>')
    for i, text in enumerate(lines):
        label(x, y-(len(lines)-1)*15+7+i*30, text, 23, bold)


def edge(points, text=None, xy=None):
    draw.line([(x*scale, y*scale) for x,y in points], fill="#526273", width=2*scale)
    parts.append('<polyline fill="none" stroke="#526273" stroke-width="2" points="'+' '.join(f'{x},{y}' for x,y in points)+'"/>')
    x,y = points[-1]
    px,py = points[-2]
    length = hypot(x-px, y-py)
    ux,uy = (x-px)/length, (y-py)/length
    head = [(x,y),(x-12*ux+5*uy,y-12*uy-5*ux),(x-12*ux-5*uy,y-12*uy+5*ux)]
    draw.polygon([(a*scale,b*scale) for a,b in head], fill="#526273")
    parts.append('<polygon fill="#526273" points="'+' '.join(f'{a},{b}' for a,b in head)+'"/>')
    if text:
        label(*xy, text, 20)


node(710,65,1000,76,["1. Group candidate stations"],"#edf3f8",True)
node(710,220,600,84,["2. Assess candidates within each cell","Candidate available?"],"#edf3f8",True)
edge([(710,103),(710,178)])
node(1180,220,300,80,["Leave cell","unrepresented"])
edge([(1010,220),(1030,220)],"No",(1020,202))
node(710,375,620,76,["2a. Prepare sounding profiles"])
edge([(710,262),(710,337)],"Yes",(745,306))
node(710,540,600,86,["2b. Find a qualifying year","Coverage passes?"],"#edf3f8")
edge([(710,413),(710,497)])
node(200,540,280,86,["Earlier endpoint","available?"],"#edf3f8")
edge([(410,540),(340,540)],"No",(375,521))
edge([(200,497),(200,455),(710,455),(710,497)],"Yes: move back one day",(450,438))
edge([(200,583),(200,650),(30,650),(30,220),(410,220)],"No",(227,620))
label(220,202,"Next candidate")
node(710,730,600,76,["Accept station"],"#eaf4f2",True)
edge([(710,583),(710,692)],"Yes",(745,642))
node(710,920,420,76,["Finish cell"])
edge([(710,768),(710,882)])
edge([(1180,260),(1180,840),(710,840)])
edge([(920,920),(1390,920),(1390,125),(710,125),(710,178)],"More cells",(1210,900))
node(710,1130,1000,80,["3. Summarize errors"],"#edf3f8",True)
edge([(710,958),(710,1090)],"All cells assessed",(815,1040))
parts.append("</svg>")
out.write_text("\n".join(parts))
canvas.resize((1420,1230), Image.Resampling.LANCZOS).save(out.with_suffix(".png"))
