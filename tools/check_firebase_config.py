#!/usr/bin/env python3
"""
CI-Prüfung der Firebase-Konfiguration (einziges Backend des Spiels).

1. scripts/net/firebase_config.gd (GDScript: native REST, Datenbank-URL) und FIREBASE_CONFIG in
   web/lumos_bridge.js (Web-SDK) müssen exakt übereinstimmen.
2. Google muss den API-Key akzeptieren: accounts:lookup mit einem absichtlich ungültigen Token
   (legt nichts an). Antwort INVALID_ID_TOKEN = Key gültig; „API key not valid“ = Build bricht ab.
   Genau dieser Fall (ein Tippfehler 0/O im Key) hatte die Anmeldung bis 1.1.7 lahmgelegt.
   Ohne Netz gibt es nur eine Warnung.

Aufruf: python3 tools/check_firebase_config.py
"""
from __future__ import annotations

import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GD = ROOT / "scripts" / "net" / "firebase_config.gd"
JS = ROOT / "web" / "lumos_bridge.js"
PAIRS = {"API_KEY": "apiKey", "AUTH_DOMAIN": "authDomain", "PROJECT_ID": "projectId", "DATABASE_URL": "databaseURL",
         "STORAGE_BUCKET": "storageBucket", "MESSAGING_SENDER_ID": "messagingSenderId", "APP_ID": "appId",
         "MEASUREMENT_ID": "measurementId"}


def main() -> int:
    gd = dict(re.findall(r'^const (\w+) := "([^"]*)"', GD.read_text(), flags=re.M))
    block = re.search(r"const FIREBASE_CONFIG = \{(.*?)\};", JS.read_text(), flags=re.S)
    if not block:
        print("::error::FIREBASE_CONFIG fehlt in web/lumos_bridge.js")
        return 1
    js = dict(re.findall(r"(\w+):\s*'([^']*)'", block.group(1)))
    bad = [f"{g}={gd.get(g)!r} ≠ {j}={js.get(j)!r}" for g, j in PAIRS.items() if gd.get(g) != js.get(j) or not gd.get(g)]
    if bad:
        print("::error::Firebase-Konfiguration weicht ab (firebase_config.gd ↔ lumos_bridge.js): " + "; ".join(bad))
        return 1
    print(f"Firebase-Konfiguration konsistent (Projekt {gd['PROJECT_ID']}, Key …{gd['API_KEY'][-6:]}).")
    req = urllib.request.Request(
        "https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=" + gd["API_KEY"],
        data=json.dumps({"idToken": "ci-check"}).encode(), headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            body = r.read().decode()
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
    except Exception as e:  # noqa: BLE001
        print(f"::warning::API-Key-Prüfung übersprungen (kein Netz?): {e}")
        return 0
    msg = ""
    try:
        msg = str(json.loads(body).get("error", {}).get("message", ""))
    except Exception:  # noqa: BLE001
        pass
    if "API key not valid" in msg or "API_KEY_INVALID" in body:
        print("::error::Google lehnt den Firebase-API-Key ab („API key not valid“) – Key in firebase_config.gd/lumos_bridge.js prüfen.")
        return 1
    print(f"API-Key von Google akzeptiert (Antwort: {msg or 'ok'}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
