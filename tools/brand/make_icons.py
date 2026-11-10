#!/usr/bin/env python3
"""
Baut aus dem gerenderten Spiel-Logo (tools/brand/render_logo.gd → logo_render.png) alle Marken-Grafiken:

* web/brand/logo.png            – freigestelltes Logo für den Ladebildschirm (Held im Kart + Stern)
* web/icons/icon-{1024,512,192,180}.png – App-Icons (abgerundeter Container, Himmel-Verlauf, Logo)
* web/icons/icon-maskable-512.png       – vollflächig, Logo in der sicheren Zone (Android)
* assets/brand/icon.png         – Projekt-Icon (Fenster, Export-Icons index.icon.png / apple-touch)

Aufruf: python3 tools/brand/make_icons.py <logo_render.png>
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent.parent


def gradient(size: int, top: tuple, bottom: tuple) -> Image.Image:
    g = Image.new("RGBA", (1, size))
    for y in range(size):
        t = y / max(1, size - 1)
        g.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    return g.resize((size, size))


def sky(size: int) -> Image.Image:
    """Heller Party-Himmel: Himmelblau → Lavendel → warmes Rosa, mit Sonnenschein oben und weichen Wolken."""
    bg = gradient(size, (70, 176, 255), (255, 128, 196))
    mid = gradient(size, (120, 200, 255), (255, 170, 210))
    mask = Image.new("L", (size, size))
    d = ImageDraw.Draw(mask)
    d.ellipse((-size * 0.3, size * 0.2, size * 1.3, size * 1.1), fill=70)
    mask = mask.filter(ImageFilter.GaussianBlur(size * 0.12))
    bg = Image.composite(mid, bg, mask)
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((size * 0.18, -size * 0.25, size * 0.82, size * 0.4), fill=(255, 250, 215, 150))
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.08))
    bg.alpha_composite(glow)
    clouds = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cd = ImageDraw.Draw(clouds)
    for cx, cy, r in ((0.12, 0.86, 0.16), (0.3, 0.92, 0.18), (0.55, 0.95, 0.17), (0.8, 0.9, 0.19), (0.97, 0.84, 0.14)):
        cd.ellipse(((cx - r) * size, (cy - r) * size, (cx + r) * size, (cy + r) * size), fill=(255, 255, 255, 215))
    clouds = clouds.filter(ImageFilter.GaussianBlur(size * 0.01))
    bg.alpha_composite(clouds)
    return bg


def with_shadow(logo: Image.Image, blur: float, alpha: int = 110, offset=(0, 0.02)) -> Image.Image:
    w, h = logo.size
    pad = int(max(w, h) * 0.08)
    out = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    sh = Image.new("RGBA", logo.size, (40, 10, 70, 0))
    sh.putalpha(logo.getchannel("A").point(lambda a: a * alpha // 255))
    out.alpha_composite(sh, (pad + int(offset[0] * w), pad + int(offset[1] * h)))
    out = out.filter(ImageFilter.GaussianBlur(blur))
    out.alpha_composite(logo, (pad, pad))
    return out


def fit(img: Image.Image, box: int) -> Image.Image:
    w, h = img.size
    k = box / max(w, h)
    return img.resize((max(1, int(w * k)), max(1, int(h * k))), Image.LANCZOS)


def icon(logo: Image.Image, size: int, rounded: bool, inner: float) -> Image.Image:
    s = 1024
    canvas = sky(s)
    art = fit(with_shadow(logo, 10), int(s * inner))
    canvas.alpha_composite(art, ((s - art.width) // 2, (s - art.height) // 2 + int(s * 0.02)))
    if rounded:
        mask = Image.new("L", (s, s), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, s - 1, s - 1), radius=int(s * 0.22), fill=255)
        rim = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        ImageDraw.Draw(rim).rounded_rectangle((6, 6, s - 7, s - 7), radius=int(s * 0.21), outline=(255, 255, 255, 150), width=10)
        canvas.alpha_composite(rim)
        canvas.putalpha(mask)
    return canvas.resize((size, size), Image.LANCZOS)


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    src = Image.open(sys.argv[1]).convert("RGBA")
    logo = src.crop(src.getchannel("A").getbbox())
    brand = ROOT / "web" / "brand"
    brand.mkdir(parents=True, exist_ok=True)
    fit(with_shadow(logo, 14, 140), 720).save(brand / "logo.png", optimize=True)
    icons = ROOT / "web" / "icons"
    for size in (1024, 512, 192, 180):
        icon(logo, size, True, 0.9).save(icons / f"icon-{size}.png", optimize=True)
    icon(logo, 512, False, 0.7).save(icons / "icon-maskable-512.png", optimize=True)
    (ROOT / "assets" / "brand").mkdir(parents=True, exist_ok=True)
    icon(logo, 512, True, 0.9).save(ROOT / "assets" / "brand" / "icon.png", optimize=True)
    print("Logo & Icons geschrieben.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
