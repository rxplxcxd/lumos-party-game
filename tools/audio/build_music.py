#!/usr/bin/env python3
"""Lumos Party – Musik-Pipeline (Schnitt, Beat-Raster, BPM-Anpassung, nahtlose Loops).

Aufruf:  python3 -I tools/audio/build_music.py <quellordner> <repo>
  <quellordner> enthält die Roh-MP3s (Minigame-Soundtrack-1..4.mp3, <Brett>-Soundtrack.mp3, Hauptmenü-Soundtrack.mp3)

Was passiert:
  1. Dekodieren (ffmpeg, 44,1 kHz Stereo, float32) und Onset-Hüllkurve berechnen.
  2. Beat-Raster je Abschnitt messen (feine Tempo- und Phasensuche um das native Tempo).
  3. Minispiel-Tracks an den Vorgaben schneiden – Start rastet auf den nächsten Schlag ein, die Länge
     wird auf ganze Takte gerundet; unter den Kandidaten gewinnt die Naht mit der höchsten spektralen
     Ähnlichkeit (Anfang vs. Ende), dazu 60 ms Überblendung Ende→Anfang = nahtloser Loop.
  4. Tonhöhenerhaltend (atempo) auf die Ziel-BPM strecken (Normal / Hurry-Up), Outro bleibt nativ.
  5. Brett-/Menü-Tracks: ganze Stücke als nahtlose Loops (beste Naht in ganzen Takten nahe am Ende).
  6. OGG Vorbis schreiben + scripts/core/music_meta.gd (BPM, Takte, Dauer je Abschnitt) erzeugen.
"""
import json
import os
import subprocess
import sys
import unicodedata

import numpy as np

SR = 44100
HOP = 512
NFFT = 2048

# Vorgaben (Sekunden) und Ziel-BPM laut Spieldesign
MINIGAME_TRACKS = {
    1: {"normal": (2, 41, 120), "hurry": (42, 73, 145), "outro": (155, None)},
    2: {"normal": (2, 132, 110), "hurry": (133, 159, 138), "outro": (158, None)},
    3: {"normal": (2, 137, 120), "hurry": (138, 154, 140), "outro": (155, None)},
    4: {"normal": (2, 121, 115), "hurry": (121, 153, 145), "outro": (154, None)},
}
BOARD_TRACKS = {
    "menu": "Hauptmenü-Soundtrack.mp3",
    "board_dungeon": "Dungeon-Soundtrack.mp3",
    "board_pirates": "Sonnige-Palmen-Bucht-Soundtrack.mp3",
    "board_sky": "Sternen-Wolkenland-Soundtrack.mp3",
    "board_graveyard": "Geisterfriedhof-Soundtrack.mp3",
    "board_frost": "Frostdorf-Soundtrack.mp3",
    "board_station": "Sternen-Sternwarte-Soundtrack.mp3",
    "board_glowforest": "Glühwürmchen-Soundtrack.mp3",
    "board_meadow": "Wuschel-Wiesen-Soundtrack.mp3",
    "board_cake": "Zuckerback-Torte-Soundtrack.mp3",
}


def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "2", "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()


def spectra(mono):
    w = np.hanning(NFFT).astype(np.float32)
    frames = np.lib.stride_tricks.sliding_window_view(mono, NFFT)[::HOP] * w
    return np.log1p(np.abs(np.fft.rfft(frames, axis=1))[:, :512] * 10.0)


def onset_env(spec):
    flux = np.maximum(0.0, np.diff(spec, axis=0)).sum(axis=1)
    flux = np.concatenate([[0.0], flux])
    flux -= np.convolve(flux, np.ones(16) / 16, mode="same")
    return np.maximum(flux, 0.0)


FPS = SR / HOP


def grid(env, t0, t1, bpm_guess):
    """Feine Suche nach Tempo und Phase: maximiert die Onset-Energie auf dem Schlagraster."""
    idx = np.arange(len(env))
    best = (bpm_guess, t0, -1.0)
    for bpm in np.arange(bpm_guess - 0.6, bpm_guess + 0.6, 0.02):
        beat = 60.0 / bpm
        for off in np.arange(0.0, beat, 0.004):
            ts = np.arange(t0 + off, t1, beat)
            v = np.interp(ts * FPS, idx, env).sum()
            if v > best[2]:
                best = (float(bpm), float(t0 + off), float(v))
    return best[0], best[1]


def native_tempo(env, t0, t1):
    seg = env[int(t0 * FPS):int(t1 * FPS)]
    seg = seg - seg.mean()
    ac = np.correlate(seg, seg, mode="full")[len(seg) - 1:]
    best, bv = 120.0, -1e9
    for bpm in np.arange(80, 180, 0.25):
        lag = 60.0 / bpm * FPS
        v = np.mean([np.interp(lag * k, np.arange(len(ac)), ac) for k in (1, 2, 4, 8)])
        if v > bv:
            best, bv = float(bpm), v
    return best


def seam_score(spec, a, b, bar):
    """Ähnlichkeit der Musik direkt nach Loop-Start (a) und nach Loop-Ende (b) über einen Takt."""
    fa, fb, n = int(a * FPS), int(b * FPS), int(bar * FPS)
    if fb + n >= len(spec):
        return -1.0
    A = spec[fa:fa + n].ravel()
    B = spec[fb:fb + n].ravel()
    cos = float(np.dot(A, B) / (np.linalg.norm(A) * np.linalg.norm(B) + 1e-9))
    ea, eb = float(spec[fa:fa + n].mean()), float(spec[fb:fb + n].mean())
    return cos - abs(ea - eb) / max(ea, eb, 1e-6) * 0.5


def cut_loop(audio, start, length, xf=0.06):
    s, n, x = int(start * SR), int(length * SR), int(xf * SR)
    loop = audio[s:s + n].copy()
    tail = audio[s + n:s + n + x]
    if len(tail) == x:
        fade = np.linspace(0.0, 1.0, x, dtype=np.float32)[:, None]
        loop[:x] = loop[:x] * fade + tail * (1.0 - fade)
    return loop


def write_ogg(audio, path, tempo=1.0, quality=3, fade_out=0.0):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    filters = []
    if abs(tempo - 1.0) > 1e-4:
        filters.append("atempo=%.6f" % tempo)
    if fade_out > 0:
        dur = len(audio) / SR / tempo
        filters.append("afade=t=out:st=%.3f:d=%.3f" % (max(0.0, dur - fade_out), fade_out))
    cmd = ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-"]
    if filters:
        cmd += ["-af", ",".join(filters)]
    cmd += ["-c:a", "libvorbis", "-q:a", str(quality), path]
    subprocess.run(cmd, input=audio.astype(np.float32).tobytes(), check=True)
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
                         capture_output=True, text=True).stdout.strip()
    return float(out)


def find_file(src_dir, name):
    """macOS-ZIPs speichern Umlaute zerlegt (NFD) – Dateinamen normalisiert vergleichen."""
    want = unicodedata.normalize("NFC", name)
    for f in os.listdir(src_dir):
        if unicodedata.normalize("NFC", f) == want:
            return os.path.join(src_dir, f)
    return None


def best_bars(spec, start, bar, want_len, lo_bars, hi_bars, limit_end, even_only=False):
    cands = []
    for nb in range(max(4, lo_bars), hi_bars + 1):
        end = start + nb * bar
        if end > limit_end or (even_only and nb % 2 == 1):
            continue
        # Musikalische Phrasen bevorzugen (4er-, dann 2er-Taktgruppen)
        prior = 0.05 if nb % 4 == 0 else (0.025 if nb % 2 == 0 else 0.0)
        cands.append((seam_score(spec, start, end, bar) - abs(nb * bar - want_len) / want_len * 0.15 + prior, nb))
    cands.sort(reverse=True)
    return cands[0][1] if cands else max(4, int(want_len // bar))


def build_minigame(src_dir, repo, meta):
    for k, cfg in MINIGAME_TRACKS.items():
        path = find_file(src_dir, "Minigame-Soundtrack-%d.mp3" % k)
        audio = decode(path)
        mono = audio.mean(axis=1)
        spec = spectra(mono)
        env = onset_env(spec)
        dur = len(audio) / SR
        entry = {}
        n0, n1, n_bpm = cfg["normal"]
        h0, h1, h_bpm = cfg["hurry"]
        native = native_tempo(env, n0, n1)
        for sect, (a, b, target) in (("normal", cfg["normal"]), ("hurry", cfg["hurry"])):
            bpm, first = grid(env, max(0.0, a - 0.3), min(b, a + 30.0), native)
            beat = 60.0 / bpm
            bar = beat * 4
            want = b - first
            limit = (h0 + 1.0) if sect == "normal" else dur - 1.0
            nb = best_bars(spec, first, bar, want, int(want // bar) - 2, int(want // bar) + 1, limit)
            loop = cut_loop(audio, first, nb * bar)
            factor = target / bpm
            out = os.path.join(repo, "assets/music/minigame/mg%d_%s.ogg" % (k, sect))
            length = write_ogg(loop, out, factor)
            entry[sect] = {"file": "res://assets/music/minigame/mg%d_%s.ogg" % (k, sect), "bpm": float(target),
                           "native_bpm": round(bpm, 2), "start": round(first, 3), "bars": nb, "length": round(length, 3)}
            print("Track %d %-6s nativ %.2f BPM, Start %.3f s, %d Takte, gestreckt ×%.4f → %d BPM, %.2f s"
                  % (k, sect, bpm, first, nb, factor, target, length))
        o0 = cfg["outro"][0]
        bpm_o, first_o = grid(env, max(0.0, o0 - 0.3), min(dur, o0 + 12.0), native)
        out = os.path.join(repo, "assets/music/minigame/mg%d_outro.ogg" % k)
        seg = audio[int(first_o * SR):]
        length = write_ogg(seg, out, 1.0, fade_out=0.25)
        entry["outro"] = {"file": "res://assets/music/minigame/mg%d_outro.ogg" % k, "bpm": round(bpm_o, 2),
                          "start": round(first_o, 3), "length": round(length, 3)}
        print("Track %d outro  ab %.3f s, %.2f s" % (k, first_o, length))
        meta["minigame"].append(entry)


def build_boards(src_dir, repo, meta):
    for mid, fname in BOARD_TRACKS.items():
        path = find_file(src_dir, fname)
        if path is None:
            print("fehlt:", fname)
            continue
        audio = decode(path)
        mono = audio.mean(axis=1)
        spec = spectra(mono)
        env = onset_env(spec)
        dur = len(audio) / SR
        native = native_tempo(env, 5.0, min(dur - 5.0, 70.0))
        bpm, first = grid(env, 0.0, 30.0, native)
        bar = 240.0 / bpm
        avail = dur - first - 0.3
        want = avail
        nb = best_bars(spec, first, bar, want, int((avail - 26.0) // bar), int(avail // bar) - 1, dur - 0.5, bpm > 140.0)
        loop = cut_loop(audio, first, nb * bar, xf=0.08)
        rel = "assets/music/board/%s.ogg" % mid.replace("board_", "")
        length = write_ogg(loop, os.path.join(repo, rel), 1.0)
        meta["boards"][mid] = {"file": "res://" + rel, "bpm": round(bpm, 2), "start": round(first, 3), "bars": nb,
                               "length": round(length, 3)}
        print("%-16s %.2f BPM, Loop ab %.3f s über %d Takte = %.1f s (von %.1f s)" % (mid, bpm, first, nb, length, dur))


def write_meta(repo, meta):
    lines = [
        "class_name MusicMeta",
        "## Automatisch erzeugt von tools/audio/build_music.py – nicht von Hand bearbeiten.",
        "## Minispiel-Tracks: Abschnitte normal/hurry (nahtlose Loops in ganzen Takten, auf Ziel-BPM gestreckt)",
        "## und outro (einmalig). Brett-/Menü-Tracks: nahtlose Loops. Jede Datei beginnt exakt auf einem Schlag.",
        "",
        "const MINIGAME := " + json.dumps(meta["minigame"], ensure_ascii=False, indent="\t").replace("\n", "\n"),
        "",
        "const BOARDS := " + json.dumps(meta["boards"], ensure_ascii=False, indent="\t"),
        "",
    ]
    with open(os.path.join(repo, "scripts/core/music_meta.gd"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


if __name__ == "__main__":
    src, repo = sys.argv[1], sys.argv[2]
    meta = {"minigame": [], "boards": {}}
    build_minigame(src, repo, meta)
    build_boards(src, repo, meta)
    write_meta(repo, meta)
