#!/usr/bin/env python3
"""Prüft, dass jeder im Asset-Katalog (autoload/assets.gd) referenzierte Pfad existiert
und nicht in einem per .gdignore ausgeschlossenen Ordner liegt."""
import re, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
src = (ROOT / "autoload/assets.gd").read_text()
consts = dict(re.findall(r'^const (\w+) := "([^"]+)"', src, re.M))
bad = 0; n = 0
for m in re.finditer(r'"([\w/]+)":\s*(\w+)\s*\+\s*"([^"]+)"|^\s*(\w+)\s*\+\s*"([^"]+)",', src, re.M):
    base, rest = (m.group(2), m.group(3)) if m.group(2) else (m.group(4), m.group(5))
    if base not in consts: continue
    p = consts[base] + rest; n += 1
    fs = ROOT / p.replace("res://", "")
    ign = any((d / ".gdignore").exists() for d in [fs.parent, *fs.parent.parents] if ROOT in d.parents or d == ROOT)
    if not fs.exists() or ign:
        bad += 1; print("FEHLT" if not fs.exists() else "IGNORIERT", m.group(1) or "", p)
for k, v in re.findall(r'"(\w+)":\s*"(res://[^"]+)"', src):
    n += 1
    if not (ROOT / v.replace("res://", "")).exists(): bad += 1; print("FEHLT", k, v)
print(f"{n} Pfade geprüft, {bad} Probleme")
sys.exit(1 if bad else 0)
