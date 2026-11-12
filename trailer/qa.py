#!/usr/bin/env python3
"""Automatische Prüfung des fertigen Trailer-Videos – Bild und Ton, Bild für Bild.

    python3 trailer/qa.py <video.mp4> [--marks=marks.json] [--sheets=ordner] [--expect=3840x2160@60]

Prüft:
  * Format: Auflösung, Bildrate, Länge, Bild- und Tonspur vorhanden
  * Schwarzbilder: Abschnitte ohne Inhalt (erlaubt: Aufblende am Anfang, Dunkelheit in Akt 1, Abblende am Ende)
  * Sprünge: harte Bildwechsel, die nicht in der Schnittliste des Trailers stehen (Kamera-Schnitt, Blitz,
    Wasserwand, Weltenwechsel) – ein unerwarteter Sprung heißt: sichtbarer Fehler im Übergang
  * Standbilder: eingefrorene Bildfolgen (Ruckler/hängende Szene) außerhalb von Schwarzblenden
  * Ton: Aussetzer (kurzes Wegbrechen mitten in lauter Musik), Stille, Übersteuerung (Clipping), Lautheit
Erzeugt auf Wunsch Kontaktbögen (ein Bild je Sekunde) zur Sichtkontrolle. Exit-Code 1 bei Fehlern.
Benötigt ffmpeg/ffprobe, numpy und Pillow.
"""
import json
import subprocess
import sys

import numpy as np

W, H = 192, 108           # Analyse-Größe (reicht für Sprünge, Schwarz und Standbilder)
AW = 0.05                 # Ton-Fenster in Sekunden


def run(cmd, binary=False):
    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if r.returncode != 0:
        raise SystemExit("Fehler bei %s:\n%s" % (" ".join(cmd[:3]), r.stderr.decode(errors="replace")[-800:]))
    return r.stdout if binary else r.stdout.decode()


def probe(path):
    out = json.loads(run(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", path]))
    v = next((s for s in out["streams"] if s["codec_type"] == "video"), None)
    a = next((s for s in out["streams"] if s["codec_type"] == "audio"), None)
    return v, a, float(out["format"]["duration"])


def segments(mask, fps, min_len):
    """Zusammenhängende True-Abschnitte (Start, Ende in Sekunden), mindestens min_len lang."""
    out, start = [], None
    for i, m in enumerate(list(mask) + [False]):
        if m and start is None:
            start = i
        elif not m and start is not None:
            if (i - start) / fps >= min_len:
                out.append((start / fps, i / fps))
            start = None
    return out


def fmt(seg):
    return "%.2f–%.2f s" % seg


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    if not args:
        raise SystemExit(__doc__)
    path = args[0]
    errors, notes = [], []
    v, a, dur = probe(path)
    if v is None:
        raise SystemExit("FEHLER: keine Bildspur")
    num, den = (int(x) for x in v["r_frame_rate"].split("/"))
    fps = num / den
    print("[QA] %s · %dx%d · %.3f fps · %.2f s · Video %s · Ton %s" % (path, v["width"], v["height"], fps, dur,
          v["codec_name"], ("%s %s Hz %s Kanäle" % (a["codec_name"], a["sample_rate"], a["channels"])) if a else "FEHLT"))
    if "expect" in opts:
        res, efps = opts["expect"].split("@")
        ew, eh = (int(x) for x in res.split("x"))
        if (v["width"], v["height"]) != (ew, eh) or abs(fps - float(efps)) > 0.01:
            errors.append("Format %dx%d@%.2f statt %s" % (v["width"], v["height"], fps, opts["expect"]))
    if a is None:
        errors.append("keine Tonspur")
    marks, mdur = [], None
    if "marks" in opts:
        md = json.load(open(opts["marks"]))
        marks = [(float(t), k) for t, k in md["marks"]]
        mdur = float(md["duration"])
        if abs(dur - mdur) > 0.25:
            errors.append("Länge %.2f s statt %.2f s (Szenen fehlen oder hängen)" % (dur, mdur))

    # --- Bild -----------------------------------------------------------------------------------------------
    raw = run(["ffmpeg", "-v", "error", "-i", path, "-vf", "scale=%d:%d:flags=area,format=gray" % (W, H),
               "-f", "rawvideo", "-"], binary=True)
    fr = np.frombuffer(raw, dtype=np.uint8).reshape(-1, H, W).astype(np.float32)
    n = len(fr)
    exp_frames = int(round(dur * fps))
    if abs(n - exp_frames) > 2:
        errors.append("%d Bilder statt %d" % (n, exp_frames))
    lum = fr.reshape(n, -1).mean(axis=1)
    p99 = np.percentile(fr.reshape(n, -1), 99, axis=1)
    diff = np.zeros(n)
    diff[1:] = np.abs(fr[1:] - fr[:-1]).reshape(n - 1, -1).mean(axis=1)
    black = (lum < 8.0) & (p99 < 30.0)
    end = mdur or dur
    for seg in segments(black, fps, 0.4):
        ok = seg[1] <= 9.0 or seg[0] >= end - 2.0   # Akt 1 (Dunkelheit) und Abblende
        (notes if ok else errors).append(("Schwarz (gewollt) " if ok else "Schwarzbild ") + fmt(seg))
    # Sprünge: Bildwechsel deutlich über dem örtlichen Bewegungsniveau
    jumps = []
    for i in range(1, n):
        lo, hi = max(1, i - 20), min(n, i + 21)
        local = np.median(np.concatenate([diff[lo:i], diff[i + 1:hi]])) if hi - lo > 2 else 0.0
        if diff[i] > 14.0 and diff[i] > 5.0 * local + 6.0:
            jumps.append(i)
    tol = 3.5 / fps + 0.02
    unexpected = []
    for i in jumps:
        tt = i / fps
        hit = next((k for (mt, k) in marks if -tol <= tt - mt <= 0.45), None)   # Blitze bauen sich kurz auf
        if hit is None and marks:
            unexpected.append(tt)
        else:
            notes.append("Schnitt %.2f s (%s, Δ %.0f)" % (tt, hit or "?", diff[i]))
    for tt in unexpected:
        errors.append("unerwarteter Bildsprung bei %.2f s (Δ %.0f)" % (tt, diff[int(round(tt * fps))]))
    if marks:
        found = {round(i / fps, 2) for i in jumps}
        for mt, k in marks:
            if k == "Schnitt" and not any(-tol <= f - mt <= 0.45 for f in found) and 1.0 < mt < end - 1.0:
                notes.append("Schnitt %.2f s (%s) weich – kein harter Sprung messbar" % (mt, k))
    # Verdeckte Weltenwechsel (ohne Schnitt/Blitz/Wasserwand daneben): Der Verdecker füllt das Bild – dort darf
    # überhaupt kein Sprung messbar sein, sonst sieht man den Wechsel.
    for mt, k in marks:
        if not k.startswith("Welt") or mt < 1.0:
            continue
        if any(abs(mt2 - mt) < 0.6 and not k2.startswith("Welt") for mt2, k2 in marks):
            continue
        near = [i for i in jumps if abs(i / fps - mt) <= tol]
        if near:
            errors.append("verdeckter Weltenwechsel %.2f s (%s) sichtbar (Δ %.0f)" % (mt, k, max(diff[i] for i in near)))
        else:
            i = int(round(mt * fps))
            notes.append("verdeckter Weltenwechsel %.2f s (%s) unsichtbar (Δ %.1f)" % (mt, k, float(diff[max(1, min(n - 1, i))])))
    frozen = (diff < 0.04) & ~black
    for seg in segments(frozen, fps, 0.5):
        ok = seg[0] >= end - 6.0   # Abspann mit stehendem Logo
        (notes if ok else errors).append(("Standbild (Abspann) " if ok else "Standbild ") + fmt(seg))
    print("[QA] Bild: %d Bilder · Helligkeit ⌀ %.0f · %d harte Schnitte · Bewegung ⌀ %.2f" % (n, lum.mean(), len(jumps), diff.mean()))

    # --- Ton ------------------------------------------------------------------------------------------------
    if a is not None:
        pcm = np.frombuffer(run(["ffmpeg", "-v", "error", "-i", path, "-ac", "2", "-ar", "48000", "-f", "f32le", "-"],
                                binary=True), dtype=np.float32).reshape(-1, 2)
        mono = pcm.mean(axis=1)
        win = int(48000 * AW)
        k = len(mono) // win
        rms = np.sqrt((mono[:k * win].reshape(k, win) ** 2).mean(axis=1) + 1e-12)
        db = 20 * np.log10(rms)
        peak = float(np.abs(pcm).max())
        clipped = int((np.abs(pcm) >= 0.999).sum())
        if clipped > 0:
            errors.append("Übersteuerung: %d Samples am Anschlag" % clipped)
        drop = []
        for i in range(6, k - 6):
            around = np.median(np.concatenate([db[i - 6:i - 1], db[i + 2:i + 7]]))
            if db[i] < -50.0 and around > -32.0:
                drop.append(i * AW)
        for tt in drop:
            ok = 64.9 <= tt <= 65.5   # gewollte Stille vor dem BOOM
            (notes if ok else errors).append(("Pause (gewollt) " if ok else "Tonaussetzer ") + "%.2f s" % tt)
        for seg in segments(db < -55.0, 1 / AW, 0.3):
            ok = seg[1] <= 1.0 or seg[0] >= end - 1.5 or (64.8 <= seg[0] and seg[1] <= 65.6)
            (notes if ok else errors).append(("Stille (gewollt) " if ok else "Stille ") + fmt(seg))
        lufs = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128=peak=true", "-f", "null", "-"],
                              stderr=subprocess.PIPE, stdout=subprocess.DEVNULL, check=False).stderr.decode(errors="replace")
        summ = lufs[lufs.rfind("Summary:"):]
        il = next((ln.split()[1] for ln in summ.splitlines() if ln.strip().startswith("I:")), "?")
        tp = next((ln.split()[1] for ln in summ.splitlines() if ln.strip().startswith("Peak:")), "?")
        print("[QA] Ton: Spitze %.3f (%.1f dBFS) · True Peak %s dBFS · Lautheit %s LUFS · ⌀ %.1f dB" % (
            peak, 20 * np.log10(max(peak, 1e-9)), tp, il, float(db.mean())))

    # --- Kontaktbögen ---------------------------------------------------------------------------------------
    if "sheets" in opts:
        from PIL import Image, ImageDraw
        import os
        os.makedirs(opts["sheets"], exist_ok=True)
        tw, th, cols, rows = 320, 180, 6, 4
        thumbs = np.frombuffer(run(["ffmpeg", "-v", "error", "-i", path, "-vf",
                                    "fps=1,scale=%d:%d:flags=area" % (tw, th), "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                                   binary=True), dtype=np.uint8).reshape(-1, th, tw, 3)
        per = cols * rows
        for s in range(0, len(thumbs), per):
            sheet = Image.new("RGB", (cols * tw, rows * th))
            d = ImageDraw.Draw(sheet)
            for j, im in enumerate(thumbs[s:s + per]):
                x, y = (j % cols) * tw, (j // cols) * th
                sheet.paste(Image.fromarray(im), (x, y))
                d.text((x + 4, y + 2), "%d s" % (s + j), fill=(255, 255, 0))
            sheet.save(os.path.join(opts["sheets"], "sheet_%02d.png" % (s // per)))
        print("[QA] Kontaktbögen: %s" % opts["sheets"])

    for nt in notes:
        print("[QA]   · " + nt)
    for e in errors:
        print("[QA] FEHLER " + e)
    print("QA OK" if not errors else "QA FEHLER (%d)" % len(errors))
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
