#!/usr/bin/env python3
"""
Steuerungs-Vertrag aller Minispiele (docs/CONTROLS.md) – läuft in der CI.

1. Jedes Minispiel im Katalog (autoload/game_state.gd, MINIGAMES) hat einen "controls"-Text.
2. Der Text nennt nur Standard-Eingaben (Stick, A/B/X/Y/L/R, Tippen …). Sensor-Mechaniken (Neigen,
   Schütteln, Pusten, Mikrofon, Gyro, Bewegungssteuerung) sind nur erlaubt, wenn sie als "optional"
   gekennzeichnet sind – das Spiel muss ohne sie vollständig und gleichwertig spielbar sein.
3. Minispiel-Skripte, die Sensor-APIs nutzen (Beschleunigung, Gyroskop, Mikrofon-Aufnahme), müssen einen
   Kommentar "# FALLBACK:" enthalten, der den gleichwertigen Standard-Weg beschreibt.

Aufruf: python3 tools/validate_controls.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SENSOR_WORDS = re.compile(r"neig|schüttel|schuettel|pust(?!e)|mikro|gyro|beschleunig|bewegungssteuer|joy-?con", re.I)
SENSOR_API = re.compile(r"get_accelerometer|get_gyroscope|get_gravity|get_magnetometer|AudioEffectCapture|AudioStreamMicrophone|DeviceMotion|DeviceOrientation|getUserMedia")


def main() -> int:
    src = (ROOT / "autoload" / "game_state.gd").read_text()
    block = src[src.index("const MINIGAMES := ["):]
    block = block[: block.index("\n]\n")]
    problems = []
    n = 0
    for m in re.finditer(r'\{"id": "([a-z0-9_]+)".*?(?=\n\t\{"id"|\Z)', block, re.S):
        gid, body = m.group(1), m.group(0)
        if '"scene"' not in body:
            continue
        n += 1
        c = re.search(r'"controls": "([^"]*)"', body)
        if not c or not c.group(1).strip():
            problems.append(f"{gid}: kein \"controls\"-Text")
            continue
        text = c.group(1)
        if SENSOR_WORDS.search(text) and "optional" not in text.lower():
            problems.append(f"{gid}: Sensor-Steuerung ohne Kennzeichnung als optional: {text!r}")
    for f in sorted((ROOT / "scripts" / "minigames").glob("*.gd")):
        code = f.read_text()
        if SENSOR_API.search(code) and "# FALLBACK:" not in code:
            problems.append(f"{f.name}: nutzt Sensor-APIs ohne '# FALLBACK:'-Beschreibung des Standard-Wegs")
    for p in problems:
        print("::error::" + p)
    print(f"Steuerungs-Vertrag: {n} Minispiele geprüft, {len(problems)} Probleme.")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
