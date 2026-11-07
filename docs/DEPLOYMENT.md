# Deployment – Web/PWA (Vercel), Lumos OS (Sideload & Kiosk), Firebase

## 1. Web-Build lokal

```bash
./godot --headless --export-release "Web" web/index.html
python3 tools/postexport_pwa.py web          # optional: version.json, lumos-app.json, --zip für das Store-Paket
cd web && python3 -m http.server 8080          # http://localhost:8080
```

* `web/` ist Quelle **und** Ausgabeordner: `shell.html`, `lumos_bridge.js`, `sw.js`, `manifest.webmanifest`,
  `icons/` und `vercel.json` sind eingecheckt; die Exportdateien (`index.*`) sind per `.gitignore` ausgeschlossen.
* Die Exportliste in `export_presets.cfg` wird erzeugt mit
  `./godot --headless --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/export_list.gd`
  (nach dem Hinzufügen neuer Modelle/Szenen ausführen – die CI macht das automatisch).
* Rauchtest im Browser (Chromium/WebGL2, prüft Engine-Start, Manifest, Service Worker und dass der
  AudioContext nach der ersten Geste läuft): `node tools/web_smoke_test.js http://localhost:8080/`

### Audio im Browser
Browser erlauben Ton erst nach einer Nutzer-Geste. Das Spiel zeigt auf dem Startbildschirm im Web
„Tippen oder Taste drücken“ – ab dieser Geste laufen Musik, Soundeffekte und UI-Sounds vollständig.

## 2. Vercel

* **Projekt-Root = Repository:** Die `vercel.json` im Root setzt `outputDirectory: "web"`.
* **Projekt-Root = `web/`:** `web/vercel.json` gilt direkt.
* Header: `application/wasm` für `.wasm`, `application/octet-stream` für `.pck`, `no-cache` für `sw.js`
  und `index.html`, `Cross-Origin-Opener-Policy: same-origin-allow-popups` (nötig für das Google-Login-Popup).
  Cross-Origin-Isolation ist nicht nötig (Build ohne Threads).
* Manuell: `npx vercel deploy web --prod` (die `.vercelignore` blendet nur Quell-Dateien aus, nicht den Export).
* Automatisch: GitHub-Secrets `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID` setzen – die CI deployt
  jeden Push auf `main` und jedes Tag.
* iOS: „Teilen → Zum Home-Bildschirm“ startet im Vollbild-Querformat (Manifest `display: fullscreen`,
  `orientation: landscape`, Safe-Area-Ränder werden im HUD berücksichtigt).

## 3. Lumos OS (Lumos One)

### Installer (empfohlen, auch in der Kiosk-/Gamescope-Sitzung)
```bash
curl -LO https://raw.githubusercontent.com/rxplxcxd/lumos-party-game/main/tools/lumos/install_lumos.py
python3 install_lumos.py --launch
```
Der Installer lädt die neueste Release-Version (bevorzugt die native Linux-Binärdatei mit eingebettetem
PCK, sonst das Web-Paket mit Start-Skript), installiert nach `~/.local/share/lumos-party/` und registriert
das Spiel über den Daemon (`ws://127.0.0.1:7420`, `auth.hello` mit `~/.cache/lumos/daemon.token`, dann
`sideload.add {path, name}`; `--launch` ruft `library.launch {id}` auf). Läuft der Daemon nicht, wird der
Eintrag im gleichen Format direkt in `~/.local/share/lumos/library.json` ergänzt.
Optionen: `--web`, `--file <pfad>`, `--uninstall`. Getestet gegen `lumosd` aus `lumos-one-os`
(Registrierung, Auflistung, Start, Entfernen).

### Manuell
* Linux-Binärdatei: `./godot --headless --export-release "Linux" build/linux/lumos-party.x86_64`
  (Linux-Exportvorlage nötig), dann in Lumos OS unter *Bibliothek → Datei hinzufügen* auswählen.
* Web-Paket: `lumos-party-web.zip` entpacken und `index.html` über einen lokalen Server öffnen.

### Erkennung im Spiel
Lumos-Hardware wird erkannt über `LUMOS_KIOSK=1`, `~/.cache/lumos/daemon.token`, `LUMOS_CLOUD_URL`,
den User-Agent der Lumos-Shell oder eine erreichbare Lumos Cloud (`/v1/health` → `provider: "lumos"`).
Dann bietet das Profil „Login mit Lumos Cloud“ an (still über gespeicherte Sitzung bzw. den
Schlüsselbund der Lumos-Shell, sonst E-Mail/Passwort der Lumos-ID).

## 4. Firebase (Online-Räume, Google-/E-Mail-Login, Profile)

1. In der Firebase-Konsole des Projekts `lumos-party-game` unter **Authentication → Sign-in method**
   aktivieren: *Google*, *E-Mail/Passwort*, *Anonym*. Unter *Autorisierte Domains* die Vercel-Domain eintragen.
2. **Realtime Database** (europe-west1) anlegen und die Regeln deployen:
   `cd firebase && npx firebase-tools deploy --only database --project lumos-party-game`
3. Der Web-API-Schlüssel aus `web/lumos_bridge.js` muss gültig sein. Für native Builds (REST) darf der
   Schlüssel nicht auf HTTP-Referrer beschränkt sein – ggf. einen zweiten, auf die Identity-Toolkit- und
   Realtime-Database-APIs beschränkten Schlüssel verwenden.

Lokaler Test ohne Internet: `bash tools/dev/net_test.sh <ordner> race` bzw. `… sumo_shove`
(RTDB-Ersatz `tools/dev/rtdb_mock.py`, zwei native Instanzen, KI fährt die lokalen Spieler).

## 5. CI (`.github/workflows/build-web.yml`)

Pull Requests und Pushes: Asset-Katalog prüfen → importieren → Skripte prüfen → Exportliste →
Online-Test (Rennen + Sumo, headless) → Web-Export + PWA → Browser-Rauchtest (inkl. Audio).
Auf `main`/Tags zusätzlich: Linux-Export, GitHub Pages, Vercel (falls Secrets gesetzt).
Tags `v*` erzeugen ein Release mit `lumos-party-web.zip`, `lumos-party-linux.x86_64`,
`install_lumos.py` und `lumos-app.json`.
