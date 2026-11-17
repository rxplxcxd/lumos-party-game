#!/usr/bin/env python3
"""Auswertung des Lumos Player Agent: python3 tools/dev/agent_report.py <ordner> [--md=datei]
Je Minispiel: Ergebnis je Strategie (Platz von Platz 1 = Mensch an der Tastatur), Auffälligkeiten.
Auffällig ist: kein sauberes Ende, Skriptfehler, Ergebnis lässt sich nicht mit A verlassen, Nichtstun gewinnt
(außer Glücksspiele), kluges Spiel ist nicht besser als Nichtstun, Figur reagiert träge (> 6 Bilder),
einzelnes Bild > 50 ms, Erklärung wartet nicht auf den Menschen."""
import json, sys, collections
out = sys.argv[1]
md = next((a[5:] for a in sys.argv[2:] if a.startswith("--md=")), None)
inv = {m["id"]: m for m in json.load(open("data/project_inventory.json"))["minigames"]["list"]}
runs = collections.defaultdict(list)
for line in open(f"{out}/agent.jsonl"):
    try: e = json.loads(line)
    except Exception: continue
    runs[e["id"]].append(e)
rows, flagged = [], 0
tot = collections.Counter()
for gid, m in inv.items():
    rs = runs.get(gid, [])
    luck = "luck" in m["cats"]
    by = collections.defaultdict(list)
    for e in rs: by[e["strategy"]].append(e)
    def avg_place(s):
        v = [e["place"] for e in by.get(s, []) if e.get("end") == "ok" and e.get("place", 0) > 0]
        return sum(v) / len(v) if v else None
    flags = []
    if not rs: flags.append("nicht gelaufen")
    bad = [f'{e["strategy"]}/{e.get("cat","?")}: {e.get("end")}' for e in rs if e.get("end") != "ok"]
    if bad: flags.append("Ende: " + ", ".join(bad))
    errs = sum(e.get("script_errors", 0) for e in rs)
    if errs: flags.append(f"{errs} Skriptfehler ({next(e['first_error'] for e in rs if e.get('script_errors'))[:110]})")
    if any(e.get("end") == "ok" and not e.get("exit_ok") for e in rs): flags.append("Ergebnis nicht per A verlassen")
    pm, pi, pr, pa = avg_place("mimic"), avg_place("idle"), avg_place("random"), avg_place("mash")
    first_cat = (m["cats"] or ["ffa"])[0]
    pm1 = [e["place"] for e in by.get("mimic", []) if e.get("cat") == first_cat and e.get("end") == "ok"]
    pm1 = sum(pm1) / len(pm1) if pm1 else None
    team = first_cat in ("2v2", "coop", "boss")
    if not luck and not team and pi is not None and pi <= 1.0: flags.append("Nichtstun gewinnt")
    if not luck and not team and pm1 is not None and pi is not None and pm1 > pi + 0.01: flags.append(f"klug ({pm1:.1f}) schlechter als Nichtstun ({pi:.1f})")
    rf = [e["react_frames"] for e in rs if e.get("react_frames", -1) >= 0]
    if rf and max(rf) > 6: flags.append(f"Figur reagiert nach {max(rf)} Bildern")
    wm = max([e.get("worst_ms", 0) for e in rs] or [0])
    if wm > 50: flags.append(f"Bildspitze {wm:.0f} ms (bei {max(rs, key=lambda e: e.get('worst_ms', 0)).get('worst_at', 0)} s)")
    late = sorted({x.split(" (")[0] for e in rs for x in e.get("late_loads", [])})
    if late: flags.append("lädt mitten im Spiel nach: " + ", ".join(late))
    idle_intro = [e["intro"] for e in by.get("idle", [])]
    if idle_intro and idle_intro[0] < 25: flags.append(f"Erklärung endet ohne Eingabe nach {idle_intro[0]:.0f} s")
    cats_ok = sorted({e["cat"] for e in by.get("mimic", []) if e.get("end") == "ok"})
    level = "vollständig gespielt" if rs and not bad and len(by) == 4 else ("teilweise" if rs else "nicht geprüft")
    f2 = lambda v: "–" if v is None else f"{v:.1f}"
    rows.append((gid, m["name"], "/".join(m["cats"]), "/".join(cats_ok), f2(pm), f2(pi), f2(pr), f2(pa),
                 (str(max(rf)) if rf else "–"), f"{wm:.0f}", level, "; ".join(flags)))
    flagged += bool(flags); tot[level] += 1
lines = ["| Minispiel | Kategorien (gespielt) | Platz klug | AFK | Zufall | Masher | Reaktion (Bilder) | längstes Bild ms | Teststufe | Auffälligkeiten |", "|---|---|---|---|---|---|---|---|---|---|"]
for r in rows:
    lines.append(f"| {r[1]} (`{r[0]}`) | {r[2]} ({r[3]}) | {r[4]} | {r[5]} | {r[6]} | {r[7]} | {r[8]} | {r[9]} | {r[10]} | {r[11]} |")
text = "\n".join(lines)
n = sum(len(v) for v in runs.values())
head = f"{len(rows)} Minispiele · {n} Läufe · {dict(tot)} · {flagged} mit Auffälligkeiten"
print(head)
for r in rows:
    if r[11]: print(f"  {r[0]:18s} {r[11]}")
if md:
    open(md, "w").write(f"<!-- erzeugt von tools/dev/agent_report.py -->\n{head}\n\n{text}\n")
json.dump([dict(zip(["id","name","cats","cats_ok","mimic","idle","random","mash","react","worst_ms","level","flags"], r)) for r in rows], open(f"{out}/agent_summary.json", "w"), ensure_ascii=False, indent=1)
