#!/usr/bin/env python3
"""
Lumos Party – Musik-Komponist
=============================

Die Asset-Pakete im Repo enthalten nur kurze Jingles, aber keine durchgehende
Hintergrundmusik. Dieses Skript komponiert und synthetisiert deshalb eigene,
nahtlos loopende Chiptune-/Party-Tracks (deterministisch per Seed) und legt sie
als OGG Vorbis in ``assets/music/`` ab.

Aufruf:  python3 tools/compose_music.py      (benötigt numpy + ffmpeg)
"""
from __future__ import annotations

import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

SR = 32000
OUT = Path(__file__).resolve().parent.parent / "assets" / "music"

NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
        "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}
CHORD = {"": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "m7": [0, 3, 7, 10], "maj7": [0, 4, 7, 11],
         "sus": [0, 5, 7], "dim": [0, 3, 6], "6": [0, 4, 7, 9]}


def midi_hz(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12)


def parse_chord(name: str, octave: int = 4) -> tuple[int, list[int]]:
    root = name[:2] if len(name) > 1 and name[1] in "#b" else name[:1]
    kind = name[len(root):]
    base = 12 * (octave + 1) + NOTE[root]
    return base, [base + i for i in CHORD[kind]]


def env(n: int, a=0.005, d=0.08, s=0.6, r=0.05) -> np.ndarray:
    t = np.arange(n) / SR
    e = np.ones(n) * s
    ai, di, ri = int(a * SR), int(d * SR), int(r * SR)
    if ai > 0:
        e[:ai] = np.linspace(0, 1, ai, endpoint=False)
    if di > 0 and ai + di < n:
        e[ai:ai + di] = np.linspace(1, s, di, endpoint=False)
    if ri > 0 and ri < n:
        e[-ri:] *= np.linspace(1, 0, ri)
    return e * np.exp(-t * 0.0)


def osc(kind: str, f: float, n: int, duty=0.5, vib=0.0) -> np.ndarray:
    t = np.arange(n) / SR
    ph = 2 * np.pi * f * t
    if vib:
        ph += vib * np.sin(2 * np.pi * 5.5 * t) * np.clip(t * 3, 0, 1)
    p = (ph / (2 * np.pi)) % 1.0
    if kind == "square":
        return np.where(p < duty, 1.0, -1.0) * 0.6
    if kind == "tri":
        return (4 * np.abs(p - 0.5) - 1)
    if kind == "saw":
        return (2 * p - 1) * 0.5
    if kind == "sine":
        return np.sin(ph)
    if kind == "pluck":
        return (np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph)) * 0.6
    if kind == "organ":
        return (np.sin(ph) + 0.45 * np.sin(2 * ph) + 0.3 * np.sin(4 * ph)) * 0.55
    raise ValueError(kind)


class Track:
    def __init__(self, bpm: float, bars: int, beats_per_bar: int = 4, swing: float = 0.0):
        self.bpm, self.bars, self.bpb, self.swing = bpm, bars, beats_per_bar, swing
        self.beat = 60.0 / bpm
        self.length = int(bars * beats_per_bar * self.beat * SR)
        self.buf = np.zeros(self.length + SR * 2)

    def t(self, beat: float) -> int:
        b = beat
        frac = b % 1.0
        if self.swing and abs(frac - 0.5) < 1e-6:
            b += self.swing * 0.5
        return int(b * self.beat * SR)

    def note(self, beat: float, dur_beats: float, midi: float, kind="square", vol=0.2, a=0.005, d=0.08, s=0.6,
             r=0.05, duty=0.5, vib=0.0, slide: float = 0.0):
        n = max(16, int(dur_beats * self.beat * SR))
        f = midi_hz(midi)
        if slide:
            t = np.arange(n) / SR
            freq = f * (2 ** ((slide * np.exp(-t * 18)) / 12))
            ph = 2 * np.pi * np.cumsum(freq) / SR
            w = np.sin(ph) if kind == "sine" else np.where((ph / (2 * np.pi)) % 1 < duty, 0.6, -0.6)
        else:
            w = osc(kind, f, n, duty, vib)
        w = w * env(n, a, d, s, r) * vol
        i = self.t(beat)
        self.buf[i:i + n] += w

    def kick(self, beat: float, vol=0.5):
        n = int(0.22 * SR)
        t = np.arange(n) / SR
        f = 45 + 110 * np.exp(-t * 35)
        w = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 14) * vol
        i = self.t(beat)
        self.buf[i:i + n] += w

    def snare(self, beat: float, vol=0.22, rng=np.random.default_rng(1)):
        n = int(0.18 * SR)
        t = np.arange(n) / SR
        w = (rng.uniform(-1, 1, n) * 0.8 + np.sin(2 * np.pi * 190 * t) * 0.4) * np.exp(-t * 22) * vol
        i = self.t(beat)
        self.buf[i:i + n] += w

    def hat(self, beat: float, vol=0.06, open_=False, rng=np.random.default_rng(2)):
        n = int((0.12 if open_ else 0.04) * SR)
        t = np.arange(n) / SR
        noise = rng.uniform(-1, 1, n)
        noise = np.diff(np.concatenate([[0], noise]))  # Hochpass
        w = noise * np.exp(-t * (18 if open_ else 70)) * vol
        i = self.t(beat)
        self.buf[i:i + n] += w

    def render(self) -> np.ndarray:
        # Ausklang auf den Anfang falten -> nahtloser Loop
        out = self.buf[:self.length].copy()
        tail = self.buf[self.length:]
        out[:len(tail)] += tail
        # einfache Echo-Raumwirkung
        d = int(self.beat * 0.75 * SR)
        wet = np.zeros_like(out)
        wet[d:] = out[:-d] * 0.22
        wet[:d] += out[-d:] * 0.22
        out = out + wet
        peak = np.max(np.abs(out)) or 1.0
        return np.tanh(out / peak * 1.25) * 0.85


def melody(track: Track, rng, prog, start_oct, kind, vol, motif_bars=2, density=0.7, duty=0.5, vib=0.25,
           scale=None, rest_end=True):
    """Erzeugt eine Melodie aus Akkordtönen mit wiederkehrenden Motiven (A A' B A)."""
    bpb = track.bpb
    motifs = {}
    sections = ["A", "A2", "B", "A"]
    bars_total = len(prog)
    for bar in range(bars_total):
        sec = sections[(bar // motif_bars) % len(sections)]
        sub = bar % motif_bars
        key = (sec, sub)
        root, tones = parse_chord(prog[bar], start_oct)
        if key not in motifs or sec == "A2":
            rhythm = []
            b = 0.0
            while b < bpb - 0.01:
                step = rng.choice([0.5, 0.5, 1.0, 1.0, 1.5, 0.25 * 2]) if density > 0.5 else rng.choice([1.0, 1.0, 2.0])
                step = min(step, bpb - b)
                rhythm.append((b, step, rng.random() < density, int(rng.integers(0, 4))))
                b += step
            if sec == "A2" and ("A", sub) in motifs:
                rhythm = [(rb, rs, play, (deg + (1 if i == len(motifs[("A", sub)]) - 1 else 0)) % 4)
                          for i, (rb, rs, play, deg) in enumerate(motifs[("A", sub)])]
            motifs[key] = rhythm
        for (b, step, play, deg) in motifs[key]:
            if not play:
                continue
            if rest_end and bar == bars_total - 1 and b >= bpb - 1:
                continue
            pool = tones + [tones[0] + 12]
            m = pool[deg % len(pool)]
            if scale and rng.random() < 0.25:
                m += rng.choice([-2, 2]) if (m % 12 + 2) % 12 in scale else 0
            track.note(bar * bpb + b, step * 0.92, m, kind, vol, duty=duty, vib=vib, s=0.55, r=0.04)


def comp(name: str, bpm: float, prog: list[str], seed: int, style: str, bpb=4, swing=0.0):
    rng = np.random.default_rng(seed)
    tr = Track(bpm, len(prog), bpb, swing)
    for bar, ch in enumerate(prog):
        base = bar * bpb
        root, tones = parse_chord(ch, 2)
        # Bass
        if style in ("pirate",):
            for k in range(bpb):
                m = root if k % 2 == 0 else root + 7
                tr.note(base + k, 0.9, m, "tri", 0.32, d=0.1, s=0.4)
        else:
            pattern = [0, 0.5, 1.5, 2, 2.5, 3.5] if style in ("race", "minigame") else [0, 1.5, 2, 3]
            for i, k in enumerate(pattern):
                if k >= bpb:
                    continue
                m = root + (12 if i % 3 == 2 else 0)
                tr.note(base + k, 0.45, m, "square" if style == "race" else "tri", 0.26, duty=0.25, s=0.5)
        # Akkord-Arpeggio / Pads
        _, ctones = parse_chord(ch, 4)
        if style in ("menu", "sky", "minigame", "race"):
            steps = 8 if style != "race" else 16
            for k in range(int(bpb * steps / 4)):
                m = ctones[k % len(ctones)] + (12 if (k // len(ctones)) % 2 else 0)
                tr.note(base + k * 4 / steps, 4 / steps * 0.8, m, "square", 0.05, duty=0.125, s=0.3, d=0.04)
        elif style == "dungeon":
            for m in ctones:
                tr.note(base, bpb * 0.98, m - 12, "organ", 0.07, a=0.2, s=0.8, r=0.3, vib=0.15)
        elif style == "pirate":
            for k in range(bpb):
                if k % 2 == 1:
                    for m in ctones[:3]:
                        tr.note(base + k, 0.5, m, "pluck", 0.06, s=0.2)
        elif style == "podium":
            for m in ctones:
                tr.note(base, bpb * 0.95, m, "saw", 0.05, a=0.08, s=0.7, r=0.2)
        # Drums
        for k in range(bpb):
            if style == "dungeon":
                if k == 0:
                    tr.kick(base + k, 0.45)
                if k == 2:
                    tr.snare(base + k, 0.12)
                tr.hat(base + k + 0.5, 0.04)
            elif style == "pirate":
                if k % 3 == 0:
                    tr.kick(base + k, 0.4)
                else:
                    tr.hat(base + k, 0.05)
                if k == bpb - 1:
                    tr.snare(base + k, 0.14)
            else:
                if k % 2 == 0 or (style in ("race", "minigame") and k == 3 and bar % 2):
                    tr.kick(base + k, 0.5)
                if k % 2 == 1:
                    tr.snare(base + k, 0.2)
                tr.hat(base + k, 0.05)
                tr.hat(base + k + 0.5, 0.04, open_=(style == "race" and k == 3))
                if style in ("race", "minigame"):
                    tr.hat(base + k + 0.25, 0.025)
                    tr.hat(base + k + 0.75, 0.025)
    # Lead-Melodie
    lead = {"menu": ("square", 5, 0.12, 0.5), "sky": ("pluck", 5, 0.16, 0.5), "dungeon": ("tri", 5, 0.15, 0.5),
            "pirate": ("square", 5, 0.1, 0.25), "minigame": ("square", 5, 0.11, 0.25), "race": ("saw", 5, 0.13, 0.5),
            "podium": ("square", 5, 0.13, 0.5)}[style]
    melody(tr, rng, prog, lead[1], lead[0], lead[2], density=0.8 if style in ("race", "minigame") else 0.65,
           duty=lead[3])
    # Gegenstimme in der zweiten Hälfte
    if style in ("menu", "sky", "race", "podium"):
        half = len(prog) // 2
        sub = Track(bpm, len(prog), bpb, swing)
        melody(sub, np.random.default_rng(seed + 7), prog, 4, "tri", 0.07, density=0.5)
        sub.buf[: int(half * bpb * tr.beat * SR)] = 0
        tr.buf[: len(sub.buf)] += sub.buf
    audio = tr.render()
    write_ogg(name, audio)


def write_ogg(name: str, audio: np.ndarray):
    OUT.mkdir(parents=True, exist_ok=True)
    pcm = (np.clip(audio, -1, 1) * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as td:
        wav_path = Path(td) / f"{name}.wav"
        with wave.open(str(wav_path), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), "-c:a", "libvorbis", "-q:a", "3",
                        str(OUT / f"{name}.ogg")], check=True)
    print(f"  {name}.ogg  {len(audio) / SR:5.1f}s")


def main():
    print("Komponiere Lumos-Party-Soundtrack …")
    comp("menu_theme", 124, ["C", "Am", "F", "G", "C", "Am", "Dm", "G7", "F", "G", "Em", "Am", "F", "G", "C", "C"], 11,
         "menu")
    comp("board_dungeon", 96, ["Am", "Am", "F", "E", "Dm", "Am", "E", "E", "Am", "C", "F", "E", "Dm", "F", "E", "Am"], 23,
         "dungeon")
    comp("board_pirates", 132, ["D", "D", "G", "A", "D", "Bm", "G", "A7", "D", "G", "D", "A", "G", "A", "D", "D"], 37,
         "pirate", bpb=3)
    comp("board_sky", 112, ["F", "C", "Dm", "Bb", "F", "C", "Bb", "C", "Dm", "Bb", "F", "C", "Bb", "C", "F", "F"], 41,
         "sky", swing=0.15)
    comp("minigame", 150, ["E", "C#m", "A", "B", "E", "C#m", "A", "B", "A", "B", "G#m", "C#m", "A", "B", "E", "B"], 53,
         "minigame")
    comp("race", 162, ["Em", "C", "D", "B7", "Em", "C", "D", "D", "C", "D", "Bm", "Em", "C", "D", "B7", "Em"], 67, "race")
    comp("podium", 104, ["C", "F", "G", "C", "Am", "F", "G7", "C"], 79, "podium")


if __name__ == "__main__":
    main()
