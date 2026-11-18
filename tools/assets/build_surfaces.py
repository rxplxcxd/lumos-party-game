#!/usr/bin/env python3
"""Lumos-Oberflächen aus den JulioVII-Originalarchiven aufbereiten (reproduzierbar, Originale bleiben unverändert).

  python3 -I tools/assets/build_surfaces.py <ordner_mit_archiven> [--only=grass,sand]

<ordner_mit_archiven>/<pack>/<datei>.zip wie von tools/assets/fetch_juliovii.py geladen (Prüfsummen in
data/juliovii_manifest.json). Ergebnis je Familie in assets/materials/surfaces/:
  <familie>_albedo.webp  RGB = Detailfarbe (linear auf Mittelwert 0,7 normiert, AO eingebacken), A = Rauheit (0..1 gestreckt)
  <familie>_normal.webp  Normalmap, OpenGL-Konvention (wie Godot), verlustfrei
Verkleinern mit Image.reduce (Kastenfilter auf ganzen Blöcken): kachelbar ohne Randnaht, kein Hochskalieren.
Statistik je Familie (Mittelfarbe, Rauheitsbereich, Quellauflösung) → data/surface_stats.json, Laufzeitwerte → scripts/core/surface_stats.gd.
"""
import io, json, os, sys, zipfile
import numpy as np
from PIL import Image

Image.MAX_IMAGE_PIXELS = None
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = json.load(open(os.path.join(ROOT, "tools/assets/surfaces_src.json")))["families"]
OUT = os.path.join(ROOT, "assets/materials/surfaces")
K_MAX = 0.7   # gespeicherter Mittelwert (linear, höchstens); Shader teilt durch k → Mittel 1,0 → Palettenfarbe bleibt.
HUE_KEEP = 0.35
# Je Familie kleiner, wenn helle Stellen sonst abgeschnitten würden (Schachbrett, Eis): k = 0,98 / 99,5-%-Quantil.


def s2l(x):
    return np.where(x <= 0.04045, x / 12.92, ((x + 0.055) / 1.055) ** 2.4)


def l2s(x):
    return np.where(x <= 0.0031308, x * 12.92, 1.055 * np.power(np.clip(x, 0, None), 1 / 2.4) - 0.055)


def find(zf, mat, chan):
    keys = {"BaseColor": ["basecolor", "base_color", "albedo", "diffuse"], "Normal": ["normal"],
            "Roughness": ["roughness"], "AO": ["ambientocclusion", "ambient_occlusion", "_ao", "occlusion"]}[chan]
    for n in zf.namelist():
        b = os.path.basename(n).lower()
        if not b.startswith(mat.lower()) or "glossiness" in b:
            continue
        rest = b[len(mat):]
        if any(k in rest for k in keys) and "dx" not in rest:
            return n
    return None


def load(zf, name, mode, res):
    im = Image.open(io.BytesIO(zf.read(name))).convert(mode)
    f = im.size[0] // res
    if f > 1:
        im = im.reduce(f)
    elif f < 1:
        raise SystemExit(f"{name}: Quelle {im.size} kleiner als Ziel {res} – kein Hochskalieren")
    return np.asarray(im, dtype=np.float32) / 255.0, im.size[0] * max(f, 1)


def build(fam, cfg, arch):
    d = os.path.join(arch, cfg["pack"])
    zp = [os.path.join(d, z) for z in os.listdir(d) if z.endswith(".zip")][0]
    zf = zipfile.ZipFile(zp)
    res = int(cfg["res"])
    bc, src_res = load(zf, find(zf, cfg["mat"], "BaseColor"), "RGB", res)
    lin = s2l(bc)
    ao_n = find(zf, cfg["mat"], "AO")
    if ao_n:
        ao, _ = load(zf, ao_n, "L", res)
        lin = lin * (1.0 - float(cfg["ao"]) * (1.0 - ao[..., None]))
    mean = lin.reshape(-1, 3).mean(0)
    # Detail = Helligkeitsverhältnis × gedämpfte Farbtonabweichung: Je-Kanal-Verhältnisse würden schwache Kanäle
    # (Blau bei gelbgrünem Gras) zu Rauschen aufblasen. Farbton bleibt zu HUE_KEEP erhalten (Gelbstich im Gras).
    w = np.array([0.2126, 0.7152, 0.0722], np.float32)
    lum = np.maximum(lin @ w, 1e-5)[..., None]
    mlum = float(mean @ w)
    chroma = np.clip((lin / lum) / np.maximum(mean / mlum, 1e-4), 0.25, 4.0)
    ratio = (lum / mlum) * chroma ** float(cfg.get("hue", HUE_KEEP))
    k = float(np.clip(0.98 / np.percentile(ratio.max(axis=2), 99.5), 0.3, K_MAX))
    det = np.clip(ratio * k, 0.0, 1.0)
    clipped = float((ratio * k > 1.0).mean())
    rn = find(zf, cfg["mat"], "Roughness")
    if rn:
        r, _ = load(zf, rn, "L", res)
        lo, hi = np.percentile(r, 2), np.percentile(r, 98)
        # Flache Rauheitskarte (z. B. alles 1,0): Mitte speichern, Bereich legt das Material fest
        rs = np.clip((r - lo) / (hi - lo), 0, 1) if hi - lo > 0.02 else np.full(r.shape, 0.5, np.float32)
    else:
        lo = hi = 0.8
        rs = np.full(det.shape[:2], 0.5, np.float32)
    srgb = l2s(det)
    ks = float(srgb.mean())   # Mittelwert im gespeicherten sRGB-Raum (Renderer ohne Linear-Umrechnung, siehe Shader)
    rgba = np.dstack([srgb, rs])
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(OUT, f"{fam}_albedo.webp"), quality=94, method=6)
    nn = find(zf, cfg["mat"], "Normal")
    n, _ = load(zf, nn, "RGB", res)
    v = n * 2.0 - 1.0
    v /= np.maximum(np.linalg.norm(v, axis=2, keepdims=True), 1e-6)
    Image.fromarray(((v * 0.5 + 0.5) * 255 + 0.5).astype(np.uint8), "RGB").save(os.path.join(OUT, f"{fam}_normal.webp"), lossless=True, method=6)
    st = {"pack": cfg["pack"], "material": cfg["mat"], "source_res": src_res, "res": res, "mean_srgb": [round(float(x), 3) for x in l2s(mean)],
          "rough_src": [round(float(lo), 3), round(float(hi), 3)], "ao": bool(ao_n), "k": round(k, 4), "ks": round(ks, 4), "hue": float(cfg.get("hue", HUE_KEEP)), "clipped_share": round(clipped, 4),
          "files": [f"{fam}_albedo.webp", f"{fam}_normal.webp"]}
    print(fam, st)
    return st


def main():
    arch = sys.argv[1]
    only = [a.split("=", 1)[1].split(",") for a in sys.argv[2:] if a.startswith("--only=")]
    stats_p = os.path.join(ROOT, "data/surface_stats.json")
    stats = json.load(open(stats_p)) if os.path.exists(stats_p) else {}
    for fam, cfg in SRC.items():
        if only and fam not in only[0]:
            continue
        stats[fam] = build(fam, cfg, arch)
    json.dump(dict(sorted(stats.items())), open(stats_p, "w"), indent=1)
    # Laufzeitdaten als GDScript-Konstante: JSON-Dateien landen beim Export („resources“) nicht im Paket.
    lines = ["class_name SurfaceStats", "extends RefCounted", "## Erzeugt von tools/assets/build_surfaces.py – nicht von Hand ändern.",
             "## k/ks = Normierung der Detailfarbe (linear / sRGB-Raum), mean = Mittelfarbe der Quelle (sRGB) für Familien mit eigener Farbe.", "", "const DATA := {"]
    for fam, st in sorted(stats.items()):
        lines.append('\t"%s": {"k": %s, "ks": %s, "mean": [%s]},' % (fam, st["k"], st["ks"], ", ".join(str(x) for x in st["mean_srgb"])))
    lines.append("}")
    open(os.path.join(ROOT, "scripts/core/surface_stats.gd"), "w").write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
