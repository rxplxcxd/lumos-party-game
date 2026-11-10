#!/usr/bin/env python3
"""
Versionierung von Lumos Party & Nitro Dash – eine Quelle, alle Stellen synchron.

Schema vor dem Release: 1.1.x (1.1.1 … 1.1.9), danach 1.2 = offizieller Release.

  python3 tools/version.py            → zeigt die aktuelle Version
  python3 tools/version.py 1.1.2      → setzt die Version überall
  python3 tools/version.py --next     → zählt die Patch-Stelle hoch (1.1.9 → Fehler: dann bewusst 1.2 setzen)

Geändert werden: project.godot (config/version – im Spiel unten rechts im Hauptmenü), lumos-app.json
(Store-Manifest) und web/shell.html (Versionsanzeige im Ladebildschirm). version.json/Store-Build-Infos
schreibt tools/postexport_pwa.py beim Export aus project.godot.
Commit-Konvention: Betreff beginnt mit „vX.Y.Z:“.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PATTERN = re.compile(r"^1\.1\.[1-9]$|^1\.2(\.\d+)?$|^1\.[3-9](\.\d+)?$|^[2-9]\.\d+(\.\d+)?$")


def current() -> str:
    m = re.search(r'^config/version="([^"]+)"', (ROOT / "project.godot").read_text(), re.M)
    return m.group(1) if m else "0.0.0"


def set_version(v: str) -> None:
    pg = ROOT / "project.godot"
    pg.write_text(re.sub(r'^config/version="[^"]*"', f'config/version="{v}"', pg.read_text(), flags=re.M))
    la = ROOT / "lumos-app.json"
    data = json.loads(la.read_text())
    data["version"] = v
    la.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    sh = ROOT / "web" / "shell.html"
    sh.write_text(re.sub(r'(<div id="ver">v)[^<]*(</div>)', rf"\g<1>{v}\g<2>", sh.read_text()))


def main() -> int:
    if len(sys.argv) < 2:
        print(current())
        return 0
    arg = sys.argv[1]
    if arg == "--next":
        major, minor, *patch = (current().split(".") + ["0"])[:3]
        p = int(patch[0]) + 1
        if (major, minor) == ("1", "1") and p > 9:
            print("1.1.9 ist die letzte Vor-Release-Version – den Release bewusst mit „tools/version.py 1.2“ setzen.")
            return 1
        arg = f"{major}.{minor}.{p}"
    if not PATTERN.match(arg):
        print(f"Ungültige Version „{arg}“ – vor dem Release nur 1.1.1 … 1.1.9, danach 1.2.")
        return 1
    set_version(arg)
    print(f"Version gesetzt: {arg}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
