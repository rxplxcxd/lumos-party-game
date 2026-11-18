#!/usr/bin/env python3
"""JulioVII-Originalarchive erneut laden und prüfen (nur kostenloser Weg „No thanks, just take me to the downloads“).

  python3 -I tools/assets/fetch_juliovii.py <zielordner> [--only=slug1,slug2]

Liest data/juliovii_manifest.json, lädt je Paket die dort genannte Datei nach <zielordner>/<slug>/ und vergleicht die
SHA-256-Prüfsumme. Kostenpflichtige Dateien (Substance-Quellen) bietet die Gratis-Seite nicht an – sie werden nie geladen.
Danach: python3 -I tools/assets/build_surfaces.py <zielordner>
"""
import hashlib, html, json, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def curl(ck, *a, out=None):
    cmd = ["curl", "-sS", "-L", "--fail", "-c", ck, "-b", ck] + list(a)
    if out:
        cmd += ["-o", out]
    return subprocess.run(cmd, capture_output=True, check=True).stdout.decode("utf-8", "replace")


def fetch(dest, e):
    slug = e["slug"]
    os.makedirs(os.path.join(dest, slug), exist_ok=True)
    ck = os.path.join(dest, f".cookies_{slug}")
    base = f"https://juliovii.itch.io/{slug}"
    tok = re.findall(r'name="csrf_token" value="([^"]+)"', curl(ck, base + "/purchase"))[0]
    page = json.loads(curl(ck, "-X", "POST", "-d", f"csrf_token={tok}", base + "/download_url"))["url"]
    d = curl(ck, page)
    tok2 = re.findall(r'name="csrf_token" value="([^"]+)"', d)[0]
    ups = re.findall(r'data-upload_id="(\d+)".*?<strong title="([^"]+)" class="name">', d, re.S)
    uid = [u for u, n in ups if html.unescape(n) == e["file"]]
    if not uid:
        raise SystemExit(f"{slug}: Datei {e['file']} nicht auf der Gratis-Downloadseite")
    url = json.loads(curl(ck, "-X", "POST", "--data-urlencode", f"csrf_token={tok2}", f"{base}/file/{uid[0]}?source=game_download"))["url"]
    fn = os.path.join(dest, slug, e["file"])
    curl(ck, url, out=fn)
    os.remove(ck)
    h = hashlib.sha256(open(fn, "rb").read()).hexdigest()
    print(("OK  " if h == e["sha256"] else "ABWEICHUNG ") + f"{slug}/{e['file']} {h}")
    return h == e["sha256"]


def main():
    dest = sys.argv[1]
    only = [a.split("=", 1)[1].split(",") for a in sys.argv[2:] if a.startswith("--only=")]
    man = json.load(open(os.path.join(ROOT, "data/juliovii_manifest.json")))
    ok = all(fetch(dest, e) for e in man["packs"] if not only or e["slug"] in only[0])
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
