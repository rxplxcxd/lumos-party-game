#!/usr/bin/env python3
"""Draufsichten aller Strecken aus dem JSON von track_check.gd (--json=…).
    python3 tools/dev/track_plot.py strecken.json bild.png
Fahrbahn in Streckenbreite, Farbe = Höhe; Start (grün), Rampen (Dreieck), Gleiter (gestrichelt), Wasser (blau),
Eis (hellblau), Nässe (türkis), Item-Reihen (gelb), Boost (orange), Trennwände (rot), Sprungpilze (pink), Gefahren (violett)."""
import json, sys, math
from PIL import Image, ImageDraw

data = json.load(open(sys.argv[1]))
ids = list(data.keys())
cols = 4 if len(ids) > 4 else len(ids)
rows = (len(ids) + cols - 1) // cols
T = 520
img = Image.new("RGB", (cols * T, rows * T), (24, 26, 32))
dr = ImageDraw.Draw(img)
for idx, tid in enumerate(ids):
    t = data[tid]
    pts = t["pts"]
    xs = [p[0] for p in pts]; zs = [p[2] for p in pts]; ys = [p[1] for p in pts]
    minx, maxx, minz, maxz = min(xs), max(xs), min(zs), max(zs)
    span = max(maxx - minx, maxz - minz) + t["width"] * 2 + 20
    sc = (T - 40) / span
    ox, oy = (idx % cols) * T, (idx // cols) * T
    cx, cz = (minx + maxx) / 2, (minz + maxz) / 2
    def P(x, z):
        return (ox + T / 2 + (x - cx) * sc, oy + T / 2 + 10 + (z - cz) * sc)
    ymin, ymax = min(ys), max(ys)
    step = t["step"]
    def at(s):
        i = int(s / step) % len(pts)
        return pts[i]
    w = max(2, int(t["width"] * sc))
    for i in range(len(pts)):
        a = pts[i]; b = pts[(i + 1) % len(pts)]
        h = (a[1] - ymin) / max(ymax - ymin, 1)
        col = (int(90 + 140 * h), int(110 + 60 * (1 - h)), int(200 - 120 * h))
        dr.line([P(a[0], a[2]), P(b[0], b[2])], fill=col, width=w)
    f = t["feats"]
    def seg(rngs, col, width=3):
        for r in rngs:
            s = r[0]
            while s < r[1]:
                a, b = at(s), at(s + step)
                dr.line([P(a[0], a[2]), P(b[0], b[2])], fill=col, width=width)
                s += step
    seg(f["water"], (60, 140, 255), max(3, w // 2))
    seg(f["ice"], (200, 240, 255), max(3, w // 2))
    seg(f["wet"], (60, 220, 210), max(3, w // 3))
    seg(f["glide"], (255, 255, 255), 2)
    for s in f["items"]:
        p = at(s + 10); x, y = P(p[0], p[2]); dr.ellipse([x - 4, y - 4, x + 4, y + 4], fill=(255, 220, 60))
    for b in f["boosts"]:
        p = at(b[0]); x, y = P(p[0], p[2]); dr.rectangle([x - 3, y - 3, x + 3, y + 3], fill=(255, 140, 40))
    for s in f["ramps"]:
        p = at(s); x, y = P(p[0], p[2]); dr.polygon([(x, y - 6), (x - 5, y + 4), (x + 5, y + 4)], fill=(255, 255, 255))
    for dv in f["dividers"]:
        seg([[dv["s0"], dv["s1"]]], (255, 60, 60), 3)
    for bo in f["bounces"]:
        p = at(bo["s"]); x, y = P(p[0], p[2]); dr.ellipse([x - 5, y - 5, x + 5, y + 5], fill=(255, 100, 200))
    for hz in f["hazards"]:
        p = at(hz["s"]); x, y = P(p[0], p[2]); dr.ellipse([x - 5, y - 5, x + 5, y + 5], outline=(190, 90, 255), width=3)
    p0 = pts[0]; x, y = P(p0[0], p0[2]); dr.ellipse([x - 6, y - 6, x + 6, y + 6], fill=(60, 220, 90))
    p1 = pts[3]; x1, y1 = P(p1[0], p1[2]); dr.line([(x, y), (x1, y1)], fill=(60, 220, 90), width=3)
    length = len(pts) * step
    dr.text((ox + 8, oy + 6), "%s, %d m, ~%.0f s, Hoehe %.0f-%.0f m" % (t["name"], length, length / 25.0, ymin, ymax), fill=(255, 255, 255))
img.save(sys.argv[2])
