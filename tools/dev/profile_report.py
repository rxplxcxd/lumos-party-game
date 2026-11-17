#!/usr/bin/env python3
"""Szenen-Profil als Markdown-Tabellen (Technik-Audit).

    python3 tools/dev/profile_report.py <headless.jsonl> [<xvfb.jsonl> [<xvfb_vorher.jsonl>]] > docs/PERF_SCENES.md

headless.jsonl: tools/dev/scene_profile.sh (CPU-Seite, Dummy-Renderer)
xvfb.jsonl:     tools/dev/scene_profile.sh … --xvfb (Draw-Calls, Primitive, Videospeicher; Software-Renderer)
"""
import json
import statistics as st
import sys

GROUPS = [("menu", "Menü"), ("board", "Bretter"), ("track", "Nitro-Dash-Strecken"), ("boss", "Bosskämpfe"),
          ("mode", "Abenteuer & Modi"), ("mg", "Minispiele")]


def load(path):
    rows = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


def fmt(v, nd=2):
    return "–" if v is None else (f"{v:.{nd}f}" if isinstance(v, float) else str(v))


def main():
    head = load(sys.argv[1])
    xv = {r["target"]: r for r in load(sys.argv[2])} if len(sys.argv) > 2 else {}
    xb = {r["target"]: r for r in load(sys.argv[3])} if len(sys.argv) > 3 else {}
    ok = [r for r in head if "ms_avg" in r]
    out = []
    w = out.append
    w("# Leistungsprofil je Szene")
    w("")
    w("Erzeugt mit `tools/dev/scene_profile.sh` und `tools/dev/profile_report.py`. Jede Szene startet wie im Spiel über "
      "den Router, alle Plätze CPU; gemessen wird nach der Aufbauphase (Minispiele ab Spielbeginn bis zum Ende, "
      "Bretter 40 s, Strecken 45 s, Menü und Modi 20 s Spielzeit).")
    w("")
    w("**Was die Zahlen bedeuten (ehrlich):**")
    w("")
    w("* *CPU-ms* = Wanduhr je Bild im Headless-Betrieb (Dummy-Renderer): Skripte, Physik, Animation, Szenenbaum, "
      "Audio. **Die Grafikkarte ist darin nicht enthalten.** Gemessen auf dem Server-Prozessor der Testumgebung; "
      "auf Smartphones und im Web (WebAssembly) ist die CPU-Seite ein Mehrfaches teurer.")
    w("* *1 %-Tief* = Mittel der langsamsten 1 % der Bilder (als ms). *> 33 ms* = Bilder, die auch auf schneller "
      "Hardware als Ruckler sichtbar wären.")
    w("* *Draw-Calls / Primitive / Videospeicher* stammen aus einem zweiten Lauf mit echtem OpenGL-Renderer "
      "(Mesa llvmpipe unter xvfb). Dessen Bildzeiten sind Software-Rasterung und **keine** FPS-Aussage für echte "
      "Geräte; die Zählwerte gelten aber genauso auf jeder GPU.")
    w("* Echte Bildraten (GPU, Web-Build, Akku) müssen auf den Zielgeräten gemessen werden – im Spiel über "
      "„FPS anzeigen“ bzw. `--perf-log`, im Browser mit `tools/dev/web_perf.js`.")
    w("")
    w("## Überblick")
    w("")
    w("| Bereich | Szenen | CPU-ms Mittel (Median / max) | p99 max | schlechtestes Bild | Bilder > 33 ms | Speicher Spitze | Engine-Fehler |")
    w("|---|---|---|---|---|---|---|---|")
    for key, name in GROUPS:
        g = [r for r in ok if r["target"].split(":")[0] == key]
        if not g:
            continue
        worst = max(g, key=lambda r: r["ms_max"])
        errs = sum(len(r.get("errors", [])) for r in g)
        w(f"| {name} | {len(g)} | {st.median([r['ms_avg'] for r in g]):.2f} / {max(r['ms_avg'] for r in g):.2f} | "
          f"{max(r['ms_p99'] for r in g):.2f} | {worst['ms_max']:.1f} ms ({worst['target'].split(':')[-1]}) | "
          f"{sum(r['over33'] for r in g)} | {max(r['mem_peak_mb'] for r in g):.0f} MB | {errs} |")
    failed = [r for r in head if "ms_avg" not in r]
    if failed:
        w("")
        w("Ohne Messwert: " + ", ".join(f"`{r['target']}` ({r.get('error', '?')})" for r in failed))
    for key, name in GROUPS:
        g = [r for r in ok if r["target"].split(":")[0] == key]
        if not g:
            continue
        w("")
        w(f"## {name}")
        w("")
        cols = "| Szene | CPU-ms Mittel | p95 | p99 | 1 %-Tief | Maximum (bei s) | > 16,7 ms | > 33 ms | Speicher MB (Spitze) | Knoten |"
        sep = "|---|---|---|---|---|---|---|---|---|---|"
        if xv:
            cols += (" Draw-Calls (vorher → jetzt) |" if xb else " Draw-Calls |") + " Primitive (Tsd.) | Videospeicher MB |"
            sep += "---|---|---|"
        w(cols)
        w(sep)
        for r in sorted(g, key=lambda r: r["target"]):
            low_ms = 1000.0 / r["fps_1low"] if r.get("fps_1low") else None
            line = (f"| {r['target'].split(':')[-1]} | {r['ms_avg']:.2f} | {r['ms_p95']:.2f} | {r['ms_p99']:.2f} | "
                    f"{fmt(low_ms)} | {r['ms_max']:.1f} ({r['max_at_s']:.1f}) | {r['over16_pct']:.2f} % | {r['over33']} | "
                    f"{r['mem_mb']:.0f} ({r['mem_peak_mb']:.0f}) | {r['nodes']} |")
            if xv:
                x = xv.get(r["target"], {})
                dc = fmt(x.get('draw_calls'), 0)
                b = xb.get(r["target"], {})
                if xb and b.get('draw_calls') is not None and x.get('draw_calls') is not None:
                    dc = f"{b['draw_calls']:.0f} → {x['draw_calls']:.0f}"
                line += f" {dc} | {fmt(x.get('prims_k'), 1)} | {fmt(x.get('vmem_mb'), 0)} |"
            w(line)
    if xv and xb:
        both = [t for t in xv if t in xb and xv[t].get('draw_calls') is not None and xb[t].get('draw_calls') is not None]
        sb = sum(xb[t]['draw_calls'] for t in both)
        sa = sum(xv[t]['draw_calls'] for t in both)
        best = sorted(both, key=lambda t: xv[t]['draw_calls'] - xb[t]['draw_calls'])[:5]
        w("")
        w("## Draw-Calls vor und nach dem Zusammenführen der OBJ-Flächen")
        w("")
        w(f"Summe über {len(both)} gemessene Szenen: {sb:.0f} → {sa:.0f} ({100.0 * (sa - sb) / max(sb, 1):+.0f} %). "
          "Größte Einsparungen: " + ", ".join(f"{t.split(':')[-1]} {xb[t]['draw_calls']:.0f} → {xv[t]['draw_calls']:.0f}" for t in best) + ". "
          "Ursache: Godots OBJ-Import legt je Materialwechsel in der Datei eine eigene Fläche an (eine 0,5-m-Blume hatte 87 "
          "Flächen bei 3 Materialien); `Assets._merge_surfaces` führt gleiche Materialien beim Laden zusammen. Gleiche "
          "Geometrie (Primitive unverändert), Bildvergleich im Rauschen zweier gleicher Läufe.")
    if xv:
        w("")
        w("## Einordnung der Draw-Calls")
        w("")
        w("Beispiel Hauptmenü (eigene Messung vor dem Zusammenführen, gleiche Ansicht): Grafikstufe Hoch 663 Draw-Calls je Bild, davon ≈ 600 "
          "für die 3D-Insel (195 sichtbare Objekte, 88 Schattenwerfer, mehrteilige Figuren) und ≈ 60 für die Oberfläche; "
          "Mittel 522, Niedrig 447 (ohne Schatten). Die Grafikstufen passen das bereits an: „Niedrig“ ohne Schatten, im "
          "Web auf Niedrig/Mittel nur eine Schattenebene und 30 % kürzere Schattendistanz, kleine Deko wirft keinen "
          "Schatten. Wuschel-Wiesen lag auch ohne Schatten noch bei ≈ 1100 – dort waren nicht die Schatten, sondern die "
          "OBJ-Flächen die Ursache (siehe oben). Ob die heutigen Werte auf schwachen Geräten reichen, zeigt erst eine "
          "Messung dort.")
    notes = [r for r in ok if r.get("errors") or r.get("late_loads") or r.get("over33")]
    if notes:
        w("")
        w("## Auffälligkeiten")
        w("")
        for r in notes:
            bits = []
            if r.get("over33"):
                bits.append("Ruckler " + ", ".join(f"{ms} ms bei {t} s" for t, ms in r.get("spikes", [])))
            if r.get("errors"):
                bits.append(f"{len(r['errors'])} Engine-Fehler, z. B. `{r['errors'][0]}`")
            if r.get("late_loads"):
                bits.append("erst während der Messung geladen: " + ", ".join(r["late_loads"][:5]))
            w(f"* `{r['target']}`: " + "; ".join(bits))
    print("\n".join(out))


if __name__ == "__main__":
    main()
