#!/usr/bin/env python3
"""
Post-Export für die PWA / den Lumos Store.

* kopiert Manifest, Icons, Service Worker (web/sw.js, Network-First mit Offline-Fallback),
  JS-Brücke (web/lumos_bridge.js) und vercel.json in den Export-Ordner – bei einem Export direkt
  nach web/ (./godot --headless --export-release "Web" web/index.html) liegt alles schon dort
* schreibt version.json und lumos-app.json (Store-Metadaten), .nojekyll für GitHub Pages
* optional: --zip erzeugt lumos-party-web.zip für den Lumos Store / GitHub Releases

Aufruf: python3 tools/postexport_pwa.py web [--zip] [--base-url URL]   (oder build/web)
"""
from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import sys
import time
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP_ID = "com.lumos.party"
REPO = "rxplxcxd/lumos-party-game"


def project_version() -> str:
    for line in (ROOT / "project.godot").read_text().splitlines():
        if line.startswith("config/version="):
            return line.split("=", 1)[1].strip().strip('"')
    return "1.0.0"


def git_sha() -> str:
    try:
        return subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.strip() or "dev"
    except Exception:  # noqa: BLE001
        return "dev"




def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    out = Path(sys.argv[1]).resolve()
    make_zip = "--zip" in sys.argv
    base_url = f"https://{REPO.split('/')[0]}.github.io/{REPO.split('/')[1]}/"
    if "--base-url" in sys.argv:
        base_url = sys.argv[sys.argv.index("--base-url") + 1]
    if not (out / "index.html").exists():
        print("index.html fehlt – zuerst exportieren.")
        return 1
    # Manifest, Icons, Service Worker, JS-Brücke, Vercel-Konfiguration
    src = ROOT / "web"
    if out != src.resolve():
        for name in ("manifest.webmanifest", "sw.js", "lumos_bridge.js", "vercel.json"):
            shutil.copy(src / name, out / name)
        icons = out / "icons"
        icons.mkdir(exist_ok=True)
        for f in (src / "icons").glob("*.png"):
            shutil.copy(f, icons / f.name)
    # Versions-Hash über die großen Dateien
    h = hashlib.sha256()
    for name in ("index.pck", "index.wasm", "index.js", "index.html"):
        p = out / name
        if p.exists():
            h.update(p.read_bytes())
    version = f"{project_version()}-{h.hexdigest()[:10]}"
    files = ["./", "./index.html", "./manifest.webmanifest"]
    for p in sorted(out.rglob("*")):
        if p.is_file() and p.name not in ("sw.js", "index.html", "shell.html", ".gdignore", "vercel.json", ".vercelignore") \
                and not p.name.endswith((".zip", ".map")) and p.name not in ("version.json", "lumos-app.json", ".nojekyll"):
            files.append("./" + p.relative_to(out).as_posix())
    # Service Worker: statisch (web/sw.js), Cache-Name an die Build-Version koppeln
    sw = (src / "sw.js").read_text().replace("const CACHE = 'lumos-party-v1-1';", f"const CACHE = 'lumos-party-{version}';")
    (out / "sw.js").write_text(sw) if out != src.resolve() else None
    total = sum(p.stat().st_size for p in out.rglob("*") if p.is_file())
    meta = {"version": project_version(), "build": version, "commit": git_sha(), "built_at": int(time.time()), "bytes": total}
    (out / "version.json").write_text(json.dumps(meta, indent=2))
    # Store-Manifest (gleiches Format wie im Repo-Root, mit Build-Infos)
    store = json.loads((ROOT / "lumos-app.json").read_text())
    store["version"] = project_version()
    store["build"] = version
    store["size_bytes"] = total
    store["entry"]["url"] = base_url
    (out / "lumos-app.json").write_text(json.dumps(store, indent=2, ensure_ascii=False))
    (out / ".nojekyll").write_text("")
    print(f"PWA fertig: {len(files)} Dateien, Version {version}, {total / 1e6:.1f} MB")
    if make_zip:
        zpath = ROOT / "build" / "lumos-party-web.zip"
        zpath.parent.mkdir(exist_ok=True)
        with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
            for p in sorted(out.rglob("*")):
                if p.is_file() and p.name not in ("shell.html", ".gdignore", ".vercelignore") and not p.name.endswith(".zip"):
                    z.write(p, p.relative_to(out).as_posix())
        print(f"Store-Paket: {zpath} ({zpath.stat().st_size / 1e6:.1f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
