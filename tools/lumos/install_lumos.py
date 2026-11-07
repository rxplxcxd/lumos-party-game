#!/usr/bin/env python3
"""
Lumos Party & Nitro Dash – Installer für Lumos OS (Lumos One, Kiosk-/Gamescope-Sitzung).

Was passiert:
  1. Neueste Version von GitHub Releases laden (bevorzugt die native Linux-Binärdatei mit eingebettetem
     PCK, sonst das Web-Paket). Alternativ lokale Datei: --file <pfad>.
  2. Installation nach ~/.local/share/lumos-party/ (Web-Paket wird entpackt, dazu ein Start-Skript, das
     einen lokalen Webserver startet und das Spiel im Vollbild-/Kiosk-Fenster öffnet).
  3. Registrierung in der Lumos-Bibliothek über den Daemon (ws://127.0.0.1:7420, auth.hello mit dem
     Token aus ~/.cache/lumos/daemon.token, dann sideload.add {path, name}). Ist der Daemon nicht erreichbar,
     wird der Eintrag direkt in ~/.local/share/lumos/library.json ergänzt (wird beim nächsten Start gelesen).
  4. Optional sofort starten: --launch (library.launch {id}).

Aufruf:
  python3 install_lumos.py                 # neueste Version installieren
  python3 install_lumos.py --web           # Web-Paket statt nativer Binärdatei
  python3 install_lumos.py --file lumos-party.x86_64 --launch
  python3 install_lumos.py --uninstall

Nur Python-Standardbibliothek (Lumos OS bringt Python 3 mit, lumosd ist selbst in Python geschrieben).
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import shutil
import socket
import stat
import struct
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

REPO = "rxplxcxd/lumos-party-game"
NAME = "Lumos Party & Nitro Dash"
HOME = Path.home()
INSTALL = HOME / ".local" / "share" / "lumos-party"
LUMOS_DATA = HOME / ".local" / "share" / "lumos"
TOKEN_PATHS = [Path(os.environ.get("XDG_RUNTIME_DIR", "/run/user/%d" % os.getuid())) / "lumos" / "daemon.token", HOME / ".cache" / "lumos" / "daemon.token"]
NATIVE_ASSET = "lumos-party-linux.x86_64"
WEB_ASSET = "lumos-party-web.zip"


def log(msg: str) -> None:
    print("[Lumos Party] " + msg, flush=True)


# --- Download --------------------------------------------------------------------------------------------

def latest_release_assets() -> tuple[dict, str]:
    url = f"https://api.github.com/repos/{REPO}/releases/latest"
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json", "User-Agent": "lumos-party-installer"})
    with urllib.request.urlopen(req, timeout=20) as r:
        data = json.load(r)
    return {a["name"]: a["browser_download_url"] for a in data.get("assets", [])}, data.get("tag_name", "?")


def download(url: str, dest: Path) -> None:
    log(f"Lade {url}")
    req = urllib.request.Request(url, headers={"User-Agent": "lumos-party-installer"})
    with urllib.request.urlopen(req, timeout=60) as r, open(dest, "wb") as f:
        total = int(r.headers.get("Content-Length") or 0)
        done = 0
        while True:
            chunk = r.read(1 << 20)
            if not chunk:
                break
            f.write(chunk)
            done += len(chunk)
            if total:
                print(f"\r  {done * 100 // total:3d} %  ({done / 1e6:.1f} MB)", end="", flush=True)
    print()


# --- Installation ----------------------------------------------------------------------------------------

LAUNCHER = """#!/bin/bash
# Lumos Party & Nitro Dash – Starter für das Web-Paket (vom Installer erzeugt)
DIR="{web}"
PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$DIR" >/dev/null 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null' EXIT
sleep 0.6
URL="http://127.0.0.1:$PORT/?lumos=1"
for B in chromium chromium-browser google-chrome brave-browser microsoft-edge; do
  if command -v "$B" >/dev/null 2>&1; then
    "$B" --kiosk --app="$URL" --user-data-dir="$HOME/.local/share/lumos-party/browser" \\
      --autoplay-policy=no-user-gesture-required --enable-features=WebAssemblyLazyCompilation \\
      --ignore-gpu-blocklist --no-first-run --noerrdialogs --disable-session-crashed-bubble
    exit $?
  fi
done
if command -v flatpak >/dev/null 2>&1 && flatpak info org.chromium.Chromium >/dev/null 2>&1; then
  flatpak run org.chromium.Chromium --kiosk --app="$URL" --autoplay-policy=no-user-gesture-required --no-first-run
  exit $?
fi
xdg-open "$URL"
wait $SERVER
"""


def install_native(src: Path) -> Path:
    INSTALL.mkdir(parents=True, exist_ok=True)
    dest = INSTALL / "lumos-party.x86_64"
    shutil.copyfile(src, dest)
    dest.chmod(dest.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    with open(dest, "rb") as f:
        if f.read(4) != b"\x7fELF":
            raise SystemExit("Die Datei ist keine Linux-Binärdatei (ELF).")
    return dest


def install_web(zip_path: Path) -> Path:
    web = INSTALL / "web"
    if web.exists():
        shutil.rmtree(web)
    web.mkdir(parents=True)
    with zipfile.ZipFile(zip_path) as z:
        z.extractall(web)
    if not (web / "index.html").exists():
        raise SystemExit("Web-Paket ungültig (index.html fehlt).")
    launcher = INSTALL / "lumos-party.sh"
    launcher.write_text(LAUNCHER.format(web=str(web)))
    launcher.chmod(0o755)
    return launcher


# --- lumosd (WebSocket, minimal ohne Fremdbibliotheken) --------------------------------------------------

class Daemon:
    def __init__(self, host: str = "127.0.0.1", port: int = 7420) -> None:
        self.sock = socket.create_connection((host, port), timeout=5)
        key = base64.b64encode(os.urandom(16)).decode()
        self.sock.sendall((f"GET / HTTP/1.1\r\nHost: {host}:{port}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
                           f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\nOrigin: http://localhost\r\n\r\n").encode())
        resp = b""
        while b"\r\n\r\n" not in resp:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise ConnectionError("Handshake abgebrochen")
            resp += chunk
        if b" 101 " not in resp.split(b"\r\n", 1)[0]:
            raise ConnectionError("Kein WebSocket-Upgrade: " + resp.split(b"\r\n", 1)[0].decode(errors="replace"))
        self.buf = resp.split(b"\r\n\r\n", 1)[1]
        self.next_id = 1

    def _send(self, obj: dict) -> None:
        data = json.dumps(obj).encode()
        mask = os.urandom(4)
        head = bytearray([0x81])
        n = len(data)
        if n < 126:
            head.append(0x80 | n)
        elif n < 65536:
            head.append(0x80 | 126)
            head += struct.pack(">H", n)
        else:
            head.append(0x80 | 127)
            head += struct.pack(">Q", n)
        self.sock.sendall(bytes(head) + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))

    def _read_exact(self, n: int) -> bytes:
        while len(self.buf) < n:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise ConnectionError("Verbindung geschlossen")
            self.buf += chunk
        out, self.buf = self.buf[:n], self.buf[n:]
        return out

    def _recv(self) -> dict:
        while True:
            b1, b2 = self._read_exact(2)
            n = b2 & 0x7F
            if n == 126:
                n = struct.unpack(">H", self._read_exact(2))[0]
            elif n == 127:
                n = struct.unpack(">Q", self._read_exact(8))[0]
            payload = self._read_exact(n)
            if b1 & 0x0F == 0x1:
                return json.loads(payload)
            if b1 & 0x0F == 0x8:
                raise ConnectionError("Daemon hat die Verbindung geschlossen")

    def call(self, method: str, params: dict | None = None) -> object:
        rid = self.next_id
        self.next_id += 1
        self._send({"id": rid, "method": method, "params": params or {}})
        while True:
            msg = self._recv()
            if msg.get("id") == rid:
                if "error" in msg:
                    err = msg["error"]
                    raise RuntimeError(f"{method}: {err.get('message')} ({err.get('code')})")
                return msg.get("result")


def read_token() -> str:
    for p in TOKEN_PATHS:
        try:
            return p.read_text().strip()
        except OSError:
            continue
    return ""


def register_daemon(path: Path, launch: bool) -> bool:
    try:
        d = Daemon()
        d.call("auth.hello", {"token": read_token()})
        entry = d.call("sideload.add", {"path": str(path), "name": NAME})
        log(f"In der Lumos-Bibliothek registriert: {entry.get('id') if isinstance(entry, dict) else entry}")
        if launch and isinstance(entry, dict):
            d.call("library.launch", {"id": entry["id"]})
            log("Spiel gestartet.")
        return True
    except (OSError, ConnectionError, RuntimeError, ValueError) as e:
        log(f"Daemon nicht erreichbar ({e}) – trage direkt in library.json ein.")
        return False


def register_file(path: Path) -> None:
    """Fallback ohne laufenden Daemon: gleiches Format wie lumosd (sideload.add)."""
    apps = HOME / "Applications"
    apps.mkdir(exist_ok=True)
    dest = apps / path.name
    if path.resolve() != dest.resolve():
        shutil.copyfile(path, dest)
    dest.chmod(dest.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP)
    lib_file = LUMOS_DATA / "library.json"
    LUMOS_DATA.mkdir(parents=True, exist_ok=True)
    state = {"sideload": [], "stats": {}}
    if lib_file.exists():
        try:
            state = json.loads(lib_file.read_text())
        except json.JSONDecodeError:
            pass
    with open(dest, "rb") as f:
        head = f.read(2)
    item_id = "sideload:" + hashlib.sha1(str(dest).encode()).hexdigest()[:12]
    entry = {"id": item_id, "kind": "binary", "name": NAME, "path": str(dest), "args": []}
    if head == b"#!":
        entry["script"] = True
    state["sideload"] = [s for s in state.get("sideload", []) if s.get("id") != item_id] + [entry]
    tmp = lib_file.with_suffix(".tmp")
    tmp.write_text(json.dumps(state, indent=1))
    os.replace(tmp, lib_file)
    log(f"Eintrag {item_id} in {lib_file} gespeichert.")


def uninstall() -> None:
    try:
        d = Daemon()
        d.call("auth.hello", {"token": read_token()})
        lib = d.call("library.list") or []
        items = lib if isinstance(lib, list) else lib.get("items", [])
        for it in items:
            if isinstance(it, dict) and it.get("name") == NAME and str(it.get("id", "")).startswith("sideload:"):
                d.call("sideload.remove", {"id": it["id"]})
                log(f"Aus der Bibliothek entfernt: {it['id']}")
    except (OSError, ConnectionError, RuntimeError) as e:
        log(f"Daemon nicht erreichbar ({e}).")
    shutil.rmtree(INSTALL, ignore_errors=True)
    log("Deinstalliert.")


def main() -> int:
    ap = argparse.ArgumentParser(description="Lumos Party & Nitro Dash für Lumos OS installieren")
    ap.add_argument("--file", help="lokale Datei (.x86_64 oder lumos-party-web.zip)")
    ap.add_argument("--web", action="store_true", help="Web-Paket statt nativer Binärdatei verwenden")
    ap.add_argument("--launch", action="store_true", help="nach der Installation starten")
    ap.add_argument("--uninstall", action="store_true")
    a = ap.parse_args()
    if a.uninstall:
        uninstall()
        return 0
    tmp = Path(tempfile.mkdtemp(prefix="lumos-party-"))
    try:
        if a.file:
            src = Path(a.file).expanduser().resolve()
            is_web = src.suffix == ".zip"
        else:
            assets, tag = latest_release_assets()
            log(f"Neueste Version: {tag}")
            is_web = a.web or NATIVE_ASSET not in assets
            name = WEB_ASSET if is_web else NATIVE_ASSET
            if name not in assets:
                raise SystemExit(f"Release enthält {name} nicht.")
            src = tmp / name
            download(assets[name], src)
        target = install_web(src) if is_web else install_native(src)
        log(f"Installiert nach {target}")
        if not register_daemon(target, a.launch):
            register_file(target)
        log("Fertig! Das Spiel erscheint in der Lumos-Bibliothek.")
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
