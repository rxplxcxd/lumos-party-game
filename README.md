# Lumos Party & Nitro Dash

Der zweite exklusive Titel für **Lumos OS**: ein chaotisches 3D-Party-Brettspiel mit 10 Minispielen
(**Modus A – Lumos Party**) und ein High-Speed-Arcade-Racer (**Modus B – Nitro Dash**).
Gebaut mit **Godot 4.7** (GL-Compatibility/WebGL2), läuft auf dem Lumos One Handheld (Download aus dem
Lumos Store) und als installierbare **PWA** in jedem modernen Browser – mit Touch, Tastatur und bis zu
vier Gamepads.

![Hauptmenü](docs/screenshots/menu.png)

| Brettspiel | Minispiel-Roulette | Lavastrom-Surfen |
|---|---|---|
| ![Brett](docs/screenshots/board.png) | ![Roulette](docs/screenshots/roulette.png) | ![Minispiel](docs/screenshots/minigame.png) |
| **Nitro Dash – Lumos-Ring** | **Neon-Vulkan (Gleiter)** | **Siegerehrung** |
| ![Racer](docs/screenshots/race.png) | ![Neon](docs/screenshots/race_neon.png) | ![Podest](docs/screenshots/podium.png) |

## Inhalt

### Modus A – Lumos Party
* **3 Bretter** mit eigenem Look, eigener Musik und sich verändernden Routen:
  * **Dungeon Deep** – Lavakanal mit auf- und abtauchendem Lava-Steg, Skelett-Wächter verlangt Wegzoll, Fackel-Fallen
  * **Pirates Cove** – Sandbank, die mit der Flut verschwindet, Krabben-Händler, Piraten-Planken
  * **Sky Kingdom** – schwebende Inseln, Zugbrücken, die jede Runde umschalten, Wolken-Kanonen
* **Felder:** Blau (+3), Rot (−3), **Glücksrad-Kiste** (Mini-Glücksrad auf dem Bildschirm), **Piraten-Planke**
  (katapultiert ein Brett zurück, klaut 10 Münzen), **Dungeon-Fluch** (tauscht die zwei am weitesten
  entfernten Spieler), Fackel-Falle, Wolken-Kanone, Händler; Lumos-Stern für 20 Münzen, Bonus-Sterne am Ende.
* **10 Minispiele:** Plank-Panic · Dungeon Drop · Kart-Bowling · Schatz-Seilbahn · Geister-Schloss Schwindel ·
  Fässer-Chaos · Lavastrom-Surfen · Turm-Balancieren (Jolt-Physik + Wind) · Bomben-Heißer-Hut · Schleim-Spur Sprint.
  Alle auch einzeln in der **Minispiel-Arena** spielbar.

### Modus B – Nitro Dash
* **3 Strecken:** Lumos-Ring (Looping, Gleiter-Schlucht), Korallen-Kanal (gläserner Unterwasser-Tunnel mit
  Lichtkegeln und Blasen), Neon-Vulkan (Looping + Gleiter über Lava, Neonlicht).
* **Arcade-Handling** mit dreistufigem Drift-Boost (Funken Blau → Orange → Regenbogen), Raketenstart, Rampen,
  Boost-Feldern, Gummiband-KI und 8 Karts (deine Helden + 4 Zusatz-Fahrer).
* **Items:** Kuchendeckel (prallt von Wänden ab) · Homing-Kanonenkugel (verfolgt den Vordermann mit fiesem Lachen) ·
  Megafon-Schock (Schrumpfen/Drehen in der Umgebung) · Piraten-Anker (20 m zurück) · Nitro.
  Super-Treffer schalten in eine 0,5-s-Matrix-Zeitlupe um das Opfer.

### Animations-, Effekt- & Cutscene-System
* `CharacterRig` überträgt die **KayKit-Rig_Medium-Animationsbibliothek** (100+ Clips) auf alle Helden,
  dazu **Squash & Stretch**, Antizipation und ein prozeduraler **Bone-Rig-Modifier** (`SkeletonModifier3D`):
  Torkeln, Zittern, Kopfschütteln, Triumph-Pose, Blickkontakt mit der Kamera, Lenkpose im Kart.
* **28 Slapstick-Reaktionen** als editierbare Ressourcen in `assets/animations/reactions/` (Jubeln, Frust-Hämmern,
  Ruß-Gesicht, Benommenheit mit Cartoon-Sternen, Ausrutschen …).
* Untergrund-abhängige Partikel (Dungeon-Geröll, Sandwirbel, Wasserspritzer, Funken, Schleim, Glut).
* **CutsceneManager** (Event-Bus-gesteuert) mit Tween-Kamera, Orbit, Spline-Flug, Dyna-Zoom, Shake,
  Letterbox und Countdown. Cutscenes in `scenes/cutscenes/`: Runden-Intro (360°-Flug, schlafende Gegner,
  zuckende Fallen, Startspieler grinst in die Kamera), Minispiel-Teaser (Spieler per Kanone ins Bild),
  Sieger-Moment, Stern-Erhalt, Planken-Katapult, Fluch-Tausch, Rennen-Intro, Item-Zeitlupe und das
  **Podest-Drama** (goldene Spotlight-Dusche, Konfetti-Kanonen – und ein Amboss für den Letzten).

## Steuerung

| Aktion | Tastatur | Gamepad (Lumos/Xbox/Switch) | Touch |
|---|---|---|---|
| Bewegen / Lenken | WASD / Pfeile | linker Stick / Steuerkreuz | schwebender Stick (linke Hälfte) |
| A – Springen / Würfeln / OK | Leertaste, Enter | A | grüner Button |
| B – Aktion / Schubsen / Nein | K | B | roter Button |
| Item (Nitro Dash) | E | X oder LB/LT | gelber Button |
| Drift (Nitro Dash) | Shift / Leertaste | RB oder RT | blauer Button |
| Pause | Esc | Start | ‖ |

Touch-Buttons sind in **Einstellungen → Layout anpassen** frei verschiebbar (Größe/Deckkraft per Regler),
Vibration läuft über Gamepad-Rumble bzw. `navigator.vibrate`. CPU-Züge lassen sich mit gehaltenem A vorspulen.

## Entwicklung

Voraussetzung: **Godot 4.7.2** (Standard-Build reicht), Python 3 mit `numpy` (nur für Musik/SFX-Generierung).

```bash
godot --path . --import
```

```bash
godot --path .
```

Hilfswerkzeuge:

| Befehl | Zweck |
|---|---|
| `python3 tools/asset_pipeline.py --check` | Asset-Inventur, glTF-Validierung, `.gdignore`-Regeln, `docs/ASSET_INVENTORY.md` |
| `python3 tools/validate_catalog.py` | prüft alle Pfade im Asset-Katalog (`autoload/assets.gd`) |
| `python3 tools/compose_music.py` / `tools/compose_sfx.py` | erzeugt Soundtrack und Cartoon-SFX |
| `python3 tools/gen_reactions.py` | erzeugt die Reaktionsbibliothek |
| `godot --headless --path . res://tools/dev/Check.tscn` | lädt alle Skripte/Szenen (Fehlerprüfung) |
| `tools/dev/test_minigames.sh <ordner>` | spielt alle Minispiele mit 4 CPUs an und speichert Screenshots |

Test-Start-Optionen (nach `--`): `--scene=res://scenes/minigames/HotBomb.tscn --cpu --touch --board=pirates
--rounds=1 --track=neon_volcano --laps=1 --shots=5,10 --quit=20 --debug-ai`.

## Web/PWA-Build & Lumos Store

```bash
godot --headless --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/export_list.gd
```

```bash
godot --headless --path . --export-release "Web" build/web/index.html
```

```bash
python3 tools/postexport_pwa.py build/web --zip
```

* Der Export nutzt die Single-Thread-Variante (kein SharedArrayBuffer nötig → läuft auf GitHub Pages und iOS Safari).
* `tools/export_list.gd` exportiert nur Assets, die der Katalog wirklich referenziert (≈16 MB PCK statt 900 MB Quell-Assets).
* `tools/postexport_pwa.py` erzeugt Service Worker (versionierter Precache, Offline-Start), Manifest, Icons,
  `version.json`, `lumos-app.json` und das Store-Paket `build/lumos-party-web.zip`.
* **GitHub Actions** (`.github/workflows/build-web.yml`): Import → Skriptprüfung → Export → PWA → Browser-Rauchtest
  (Chromium/WebGL2) → Deployment auf **GitHub Pages** (Push auf `main`) und **GitHub Release** mit ZIP +
  `lumos-app.json` (Tag `v*`). Einmalig nötig: *Settings → Pages → Source: GitHub Actions*.
* `lumos-app.json` im Repo-Root beschreibt die App für den Lumos Store (Web-Einstieg + Download-ZIP).

## Projektstruktur

```
autoload/        EventBus, Game, Assets, Audio, InputHub, Juice, FX, CutsceneManager, Router
scripts/core/    CharacterRig, SlapstickModifier, ReactionClip, PartyAvatar, KartVisual, WorldKit, Kameras
scripts/party/   Brett-Daten, Brett-Baukasten, Brettspiel-Logik
scripts/minigames/  MinigameBase + 10 Minispiele
scripts/racer/   TrackDefs, RaceTrack, Racer (Fahrphysik + KI), NitroDash (Rennleitung, Items, HUD)
scripts/ui/      Boot, Hauptmenü, Touch-Steuerung, Theme, Icons, Glücksrad
scenes/          boot, menu, party, minigames, racer, cutscenes
assets/          Original-Assetpakete (3d/, audio/) + animations/, music/, sfx/, fonts/, shaders/
web/             HTML-Shell, Manifest, Icons der PWA
tools/           Asset-Pipeline, Generatoren, Export, Tests
docs/            ASSET_INVENTORY.md, ARCHITECTURE.md, Screenshots
```

Details zur Technik: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) · Asset-Nutzung: [docs/ASSET_INVENTORY.md](docs/ASSET_INVENTORY.md)

## Lizenzen

3D-Modelle, Sounds und Icons: Kenney und KayKit (CC0). Schriften: Lilita One und Fredoka (SIL OFL 1.1,
siehe `assets/fonts/`). Engine: Godot (MIT). Soundtrack und Cartoon-SFX sind prozedural erzeugt.
