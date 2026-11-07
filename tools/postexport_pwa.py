#!/usr/bin/env python3
"""
Post-Export für die PWA / den Lumos Store.

* kopiert Manifest + Icons aus web/ in den Export-Ordner
* erzeugt sw.js (Service Worker) mit Versions-Hash und vollständiger Precache-Liste:
  - Navigation: Network-First (Updates kommen sofort an), Offline-Fallback aus dem Cache
  - Engine/Spieldaten: Cache-First mit Hintergrund-Aktualisierung
  - alte Caches werden beim Aktivieren gelöscht
* schreibt version.json und lumos-app.json (Store-Metadaten), .nojekyll für GitHub Pages
* optional: --zip erzeugt lumos-party-web.zip für den Lumos Store / GitHub Releases

Aufruf: python3 tools/postexport_pwa.py build/web [--zip] [--base-url URL]
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


SW_TEMPLATE = r"""// Lumos Party – Service Worker (automatisch erzeugt von tools/postexport_pwa.py)
const VERSION = '__VERSION__';
const CACHE = 'lumos-party-' + VERSION;
const PRECACHE = __FILES__;

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(PRECACHE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k.startsWith('lumos-party-') && k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('message', (event) => {
  if (event.data === 'skipWaiting') self.skipWaiting();
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;
  // Navigation: Network-First, damit neue Versionen sofort geladen werden
  if (req.mode === 'navigate') {
    event.respondWith(
      fetch(req).then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put('./index.html', copy));
        return res;
      }).catch(() => caches.match('./index.html'))
    );
    return;
  }
  // Spieldaten: Cache-First (Engine/PCK sind versioniert über den Cache-Namen)
  event.respondWith(
    caches.match(req, { ignoreSearch: true }).then((hit) => {
      if (hit) return hit;
      return fetch(req).then((res) => {
        if (res.ok) {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(req, copy));
        }
        return res;
      });
    })
  );
});
"""


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
    # Manifest & Icons
    shutil.copy(ROOT / "web" / "manifest.webmanifest", out / "manifest.webmanifest")
    icons = out / "icons"
    icons.mkdir(exist_ok=True)
    for f in (ROOT / "web" / "icons").glob("*.png"):
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
        if p.is_file() and p.name not in ("sw.js", "index.html") and not p.name.endswith((".zip", ".map")) \
                and p.name not in ("version.json", "lumos-app.json", ".nojekyll"):
            files.append("./" + p.relative_to(out).as_posix())
    (out / "sw.js").write_text(SW_TEMPLATE.replace("__VERSION__", version).replace("__FILES__", json.dumps(files, indent=2)))
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
    print(f"PWA fertig: {len(files)} Dateien im Precache, Version {version}, {total / 1e6:.1f} MB")
    if make_zip:
        zpath = out.parent / "lumos-party-web.zip"
        with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
            for p in sorted(out.rglob("*")):
                if p.is_file():
                    z.write(p, p.relative_to(out).as_posix())
        print(f"Store-Paket: {zpath} ({zpath.stat().st_size / 1e6:.1f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
