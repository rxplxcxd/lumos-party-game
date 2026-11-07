#!/usr/bin/env python3
"""
Lumos Party – Cartoon-SFX-Synthese
==================================

Ergänzt die Kenney-Soundpakete um klassische Slapstick-Effekte, die dort fehlen:
fieses Lachen (Homing-Kanonenkugel), fallender Pfeifton, Boing, Trommelwirbel,
traurige Posaune (letzter Platz), Konfetti-Plopp und Kanonenschuss.
Ausgabe: assets/sfx/*.ogg   (benötigt numpy + ffmpeg)
"""
from __future__ import annotations

import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

SR = 32000
OUT = Path(__file__).resolve().parent.parent / "assets" / "sfx"
rng = np.random.default_rng(7)


def t_axis(sec: float) -> np.ndarray:
    return np.arange(int(sec * SR)) / SR


def resonate(x: np.ndarray, f: float, q: float) -> np.ndarray:
    """Einfacher 2-Pol-Resonanzfilter (Formant)."""
    w = 2 * np.pi * f / SR
    r = np.exp(-w / (2 * q))
    a1, a2 = -2 * r * np.cos(w), r * r
    y = np.zeros_like(x)
    for i in range(len(x)):
        y[i] = x[i] - a1 * (y[i - 1] if i > 0 else 0) - a2 * (y[i - 2] if i > 1 else 0)
    return y * (1 - r)


def glottal(freq: np.ndarray) -> np.ndarray:
    ph = np.cumsum(freq) / SR
    p = ph % 1.0
    return (np.where(p < 0.4, np.sin(np.pi * p / 0.4), 0.0) - 0.25)


def evil_laugh() -> np.ndarray:
    parts = []
    base = 230.0
    for k in range(6):
        dur = 0.17
        t = t_axis(dur)
        f = base * (1 - 0.07 * k) * (1 + 0.12 * np.exp(-t * 18)) * (1 + 0.02 * np.sin(2 * np.pi * 30 * t))
        src = glottal(f) + rng.uniform(-0.15, 0.15, len(t)) * np.exp(-t * 40)
        v = resonate(src, 750, 6) * 1.0 + resonate(src, 1150, 8) * 0.7 + resonate(src, 2600, 10) * 0.25
        env = np.minimum(1, t * 60) * np.exp(-t * 7)
        parts.append(v * env)
        parts.append(np.zeros(int(0.05 * SR)))
    return np.concatenate(parts)


def whistle(start: float, end: float, dur: float) -> np.ndarray:
    t = t_axis(dur)
    f = start * (end / start) ** (t / dur)
    f *= 1 + 0.01 * np.sin(2 * np.pi * 6 * t)
    ph = 2 * np.pi * np.cumsum(f) / SR
    w = np.sin(ph) + 0.08 * rng.uniform(-1, 1, len(t))
    return w * np.minimum(1, t * 30) * np.minimum(1, (dur - t) * 8)


def boing() -> np.ndarray:
    t = t_axis(0.6)
    f = 140 + 260 * np.exp(-t * 6) * (1 + 0.35 * np.sin(2 * np.pi * 18 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 5)


def drumroll() -> np.ndarray:
    out = np.zeros(int(1.6 * SR))
    hit = int(0.035 * SR)
    for k in range(0, len(out) - hit, hit):
        t = np.arange(hit) / SR
        amp = 0.4 + 0.6 * (k / len(out))
        out[k:k + hit] += rng.uniform(-1, 1, hit) * np.exp(-t * 90) * amp
    return out


def sad_trombone() -> np.ndarray:
    notes = [(311.13, 0.35), (293.66, 0.35), (277.18, 0.35), (261.63, 1.1)]
    parts = []
    for i, (f0, d) in enumerate(notes):
        t = t_axis(d)
        vib = (1 + 0.025 * np.sin(2 * np.pi * 5.5 * t) * (t > 0.3)) if i == 3 else 1
        f = f0 * vib * (1 - 0.03 * (t / d) if i == 3 else 1)
        ph = 2 * np.pi * np.cumsum(f) / SR
        w = sum(np.sin(ph * h) / h ** 0.8 for h in range(1, 8))
        w = resonate(w, 900, 2.5) * 3
        env = np.minimum(1, t * 25) * np.minimum(1, (d - t) * 12)
        parts.append(w * env)
    return np.concatenate(parts)


def pop() -> np.ndarray:
    t = t_axis(0.18)
    f = 900 * np.exp(-t * 25) + 200
    return (np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.6 + rng.uniform(-1, 1, len(t)) * 0.4) * np.exp(-t * 30)


def cannon() -> np.ndarray:
    t = t_axis(1.1)
    boom = np.sin(2 * np.pi * np.cumsum(50 + 120 * np.exp(-t * 20)) / SR) * np.exp(-t * 5)
    noise = rng.uniform(-1, 1, len(t)) * np.exp(-t * 7)
    noise = np.convolve(noise, np.ones(12) / 12, mode="same")
    return boom * 0.9 + noise * 0.8


def crowd() -> np.ndarray:
    t = t_axis(2.2)
    out = np.zeros(len(t))
    for _ in range(40):
        f0 = rng.uniform(160, 420)
        start = rng.uniform(0, 0.4)
        d = rng.uniform(0.8, 1.8)
        mask = (t >= start) & (t < start + d)
        tt = t[mask] - start
        f = f0 * (1 + 0.15 * np.sin(2 * np.pi * rng.uniform(2, 5) * tt))
        src = glottal(f)
        v = resonate(src, rng.uniform(600, 900), 5) + resonate(src, rng.uniform(1000, 1600), 6) * 0.5
        out[mask] += v * np.minimum(1, tt * 8) * np.minimum(1, (d - tt) * 3) * 0.3
    hiss = rng.uniform(-1, 1, len(t)) * 0.08 * np.minimum(1, t * 4) * np.minimum(1, (2.2 - t) * 2)
    return out + hiss


def write(name: str, x: np.ndarray) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    x = x / (np.max(np.abs(x)) or 1) * 0.9
    pcm = (x * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as td:
        wp = Path(td) / "a.wav"
        with wave.open(str(wp), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wp), "-c:a", "libvorbis", "-q:a", "4",
                        str(OUT / f"{name}.ogg")], check=True)
    print(f"  {name}.ogg")


def main() -> None:
    print("Synthetisiere Cartoon-SFX …")
    write("evil_laugh", evil_laugh())
    write("whistle_fall", whistle(2400, 500, 1.1))
    write("whistle_up", whistle(500, 2200, 0.45))
    write("boing", boing())
    write("drumroll", drumroll())
    write("sad_trombone", sad_trombone())
    write("pop", pop())
    write("cannon", cannon())
    write("crowd_cheer", crowd())


if __name__ == "__main__":
    main()
