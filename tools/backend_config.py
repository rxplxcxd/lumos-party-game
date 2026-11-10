#!/usr/bin/env python3
"""
Setzt die Supabase-Projektdaten in scripts/net/backend_config.gd ein (CI-Schritt vor dem Export).

Quelle: Umgebungsvariablen SB_URL und SB_KEY (in der CI aus den Repo-Variablen bzw. -Secrets
SUPABASE_URL / SUPABASE_ANON_KEY). Sind sie leer, bleibt die Datei unverändert.

Sicherheitsprüfung: Ein service_role-/secret-Key würde im Web-Build öffentlich ausgeliefert und RLS
aushebeln – dann bricht der Build mit einer klaren Meldung ab.

Aufruf: SB_URL=https://xyz.supabase.co SB_KEY=eyJ... python3 tools/backend_config.py
"""
from __future__ import annotations

import base64
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CFG = ROOT / "scripts" / "net" / "backend_config.gd"


def jwt_role(key: str) -> str:
    parts = key.split(".")
    if len(parts) != 3:
        return ""
    try:
        pad = parts[1] + "=" * (-len(parts[1]) % 4)
        return str(json.loads(base64.urlsafe_b64decode(pad)).get("role", ""))
    except Exception:  # noqa: BLE001
        return ""


def main() -> int:
    url = os.environ.get("SB_URL", "").strip().rstrip("/")
    key = os.environ.get("SB_KEY", "").strip()
    if not url and not key:
        print("Supabase: keine Repo-Variablen gesetzt – backend_config.gd bleibt unverändert.")
        return 0
    if not url or not key:
        print("::error::Supabase: SUPABASE_URL und SUPABASE_ANON_KEY müssen beide gesetzt sein.")
        return 1
    if key.startswith("sb_secret_") or jwt_role(key) == "service_role":
        print("::error::Supabase: Das ist der service_role-/secret-Key! Bitte den anon- bzw. publishable-Key verwenden.")
        return 1
    if not re.match(r"^[A-Za-z0-9._-]+$", key):
        print("::error::Supabase: SUPABASE_ANON_KEY enthält ungültige Zeichen (Leerzeichen/Anführungszeichen mitkopiert?).")
        return 1
    for suffix in ("/rest/v1", "/auth/v1"):
        if url.endswith(suffix):
            url = url[: -len(suffix)]
    if not re.match(r"^https://[A-Za-z0-9.-]+(:\d+)?$", url):
        print(f"::error::Supabase: SUPABASE_URL muss wie https://<projekt>.supabase.co aussehen (ist: {url!r}).")
        return 1
    src = CFG.read_text()
    src = re.sub(r'^const SUPABASE_URL := ".*"$', f'const SUPABASE_URL := "{url}"', src, flags=re.M)
    src = re.sub(r'^const SUPABASE_ANON_KEY := ".*"$', f'const SUPABASE_ANON_KEY := "{key}"', src, flags=re.M)
    CFG.write_text(src)
    print(f"Supabase: {url} eingesetzt (Key …{key[-6:]}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
