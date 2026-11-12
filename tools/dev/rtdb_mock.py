#!/usr/bin/env python3
"""
Minimaler, REST-kompatibler Ersatz für die Firebase Realtime Database – nur für lokale Tests
der Online-Logik (zwei native Instanzen ohne Internet).

  GET/PUT/PATCH/POST/DELETE  http://127.0.0.1:PORT/<pfad>.json
  POST erzeugt einen Push-Schlüssel (zeitlich sortierbar) wie Firebase, {".sv": "timestamp"} wird ersetzt.

Aufruf: python3 tools/dev/rtdb_mock.py [port]
Spiel:  LUMOS_RTDB_URL=http://127.0.0.1:PORT LUMOS_NET_TEST_UID=hostA godot … -- --net-test=host

Schlechte Verbindungen simulieren (Netz-QA):
  MOCK_DELAY_MS=300   jede Anfrage wartet zufällig 0…300 ms (Latenz + Jitter, auch Reihenfolge-Vertauschung)
  MOCK_FAIL_PCT=5     5 % der Anfragen scheitern mit HTTP 503 (Paketverlust / Funkloch)
"""
import json
import os
import random
import sys
import threading
import time

DELAY_MS = int(os.environ.get("MOCK_DELAY_MS", "0") or 0)
FAIL_PCT = float(os.environ.get("MOCK_FAIL_PCT", "0") or 0)
STATS = {"requests": 0, "failed": 0}
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DATA: dict = {}
LOCK = threading.Lock()
_counter = [0]


def _resolve(v):
    if isinstance(v, dict):
        if v.get(".sv") == "timestamp":
            return int(time.time() * 1000)
        return {k: _resolve(x) for k, x in v.items()}
    if isinstance(v, list):
        return [_resolve(x) for x in v]
    return v


def _parts(path: str):
    path = path.split("?", 1)[0]
    if path.endswith(".json"):
        path = path[:-5]
    return [p for p in path.strip("/").split("/") if p]


def _get(parts):
    node = DATA
    for p in parts:
        if not isinstance(node, dict) or p not in node:
            return None
        node = node[p]
    return node


def _set(parts, value):
    if not parts:
        DATA.clear()
        if isinstance(value, dict):
            DATA.update(value)
        return
    node = DATA
    for p in parts[:-1]:
        if not isinstance(node.get(p), dict):
            node[p] = {}
        node = node[p]
    if value is None:
        node.pop(parts[-1], None)
    else:
        node[parts[-1]] = value


def _push_key():
    _counter[0] += 1
    return "-M%013d%05d" % (int(time.time() * 1000), _counter[0])


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _bad_network(self) -> bool:
        """Verzögert die Anfrage und lässt einen Teil scheitern (True = schon mit 503 beantwortet)."""
        STATS["requests"] += 1
        if DELAY_MS > 0:
            time.sleep(random.uniform(0, DELAY_MS) / 1000.0)
        if FAIL_PCT > 0 and random.uniform(0, 100) < FAIL_PCT:
            STATS["failed"] += 1
            n = int(self.headers.get("Content-Length") or 0)
            if n:
                self.rfile.read(n)
            self.send_response(503)
            self.send_header("Content-Length", "0")
            self.end_headers()
            if STATS["failed"] % 50 == 1:
                print(f"[MOCK] {STATS['failed']} von {STATS['requests']} Anfragen absichtlich gescheitert", flush=True)
            return True
        return False

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(n) if n else b""
        return json.loads(raw) if raw.strip() else None

    def _reply(self, obj, code=200):
        b = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        if self._bad_network():
            return
        with LOCK:
            self._reply(_get(_parts(self.path)))

    def do_PUT(self):
        if self._bad_network():
            return
        v = _resolve(self._body())
        with LOCK:
            _set(_parts(self.path), v)
        self._reply(v)

    def do_PATCH(self):
        if self._bad_network():
            return
        v = _resolve(self._body()) or {}
        parts = _parts(self.path)
        with LOCK:
            cur = _get(parts)
            if not isinstance(cur, dict):
                cur = {}
            for k, x in v.items():
                if x is None:
                    cur.pop(k, None)
                else:
                    cur[k] = x
            _set(parts, cur)
        self._reply(v)

    def do_POST(self):
        if self._bad_network():
            return
        v = _resolve(self._body())
        key = _push_key()
        with LOCK:
            _set(_parts(self.path) + [key], v)
        self._reply({"name": key})

    def do_DELETE(self):
        if self._bad_network():
            return
        with LOCK:
            _set(_parts(self.path), None)
        self._reply(None)


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 9123
    print(f"RTDB-Mock auf http://127.0.0.1:{port} (Verzögerung bis {DELAY_MS} ms, Ausfall {FAIL_PCT} %)", flush=True)
    ThreadingHTTPServer(("127.0.0.1", port), H).serve_forever()
