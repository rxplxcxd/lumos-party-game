# Changelog – Lumos Party & Nitro Dash

Versionierung vor dem Release: **1.1.x** (1.1.1 … 1.1.9), danach **1.2** = offizieller Release.
Eine Quelle für alle Stellen: `python3 tools/version.py <version>` (bzw. `--next`). Commit-Betreff: `vX.Y.Z: …`.

## 1.1.6
* **Fix: Unerwarteter Neustart nach Minispielen** (Rücksprung zum Startbildschirm). Ursache war ein Speicherleck:
  Gfx hielt seit 1.1.4 jedes bearbeitete Mesh in einem Dictionary fest (pro Brett-Besuch über tausend Objekte),
  dazu ein unbegrenzter Modell-Cache und 4 verwaiste Nodes pro Szene. Lange Sessions liefen voll, bis der Browser
  den Tab neu geladen hat. Jetzt: Markierung am Mesh selbst, Modell-Cache behält nur die letzten zwei Szenen, die
  alte Szene wird vor dem Laden der neuen freigegeben (keine doppelte Spitzenlast). Gemessen: Objektzahl bleibt
  über viele Brett↔Minispiel-Wechsel konstant (~4.500 statt +1.100 je Wechsel), keine verwaisten Nodes mehr.
  Neue Testoption `--log-scenes` protokolliert jeden Szenenwechsel mit Speicher und Objektzahl.
* **Sattere Farben:** ACES statt Filmic-Tonemapping (Filmic hat helle Flächen entsättigt), weniger Dunstschleier,
  weniger bläuliches Himmelslicht in Schatten, höhere Grund-Sättigung.
* **Neue Regler** unter Einstellungen: *Farbsättigung* und *Farbstärke* – wirken sofort auf alle Szenen.

## 1.1.5
* **Bosskämpfe als freie Echtzeit-Arenakämpfe** statt Würfel-Ring: Alle laufen und springen frei, sammeln
  themenpassende Wurfgeschosse (Wasserbomben, Kokosnüsse, Sternsplitter …) und werfen sie mit B auf den Boss.
  Jede Fähigkeit ist eine sichtbar angekündigte Gefahr: leuchtende Bodenkreise (Lava, Eiszapfen, Kometen,
  Wurzeln, Karamell), Schweif-/Flammen-/Frostbögen und Wellen zum Drüberspringen, Sturmangriffe, zielsuchende
  Blasen/Raketen/Geisterorbs, Wind, Wirbelstürme, Schafherden, Kirsch-Bomben, vertauschte Steuerung, Nebel,
  Glätte. Die Einzigartigkeiten sind Orte in der Arena: brüchiger Boden über Lava, Sandbänke bei Flut,
  Wolkenkanonen in den Rücken des Bosses, Grabsteine als Schild, Riesen-Schneebälle, Uhrwerk-Felder,
  Pilzlicht bei Nacht, Duell-Felder, Kirsch-Lifte und Aufwind-Felder (Höhenbonus ×2).
  Phasen bei 66 %/33 % (kurz benommen, dann schneller; Wut-Phase mit Doppelangriffen), 80 Sekunden Zeit.

## 1.1.4
* **Performance-Notfall (alle Plattformen):** gemessen statt geraten – das Hauptmenü war GPU-gebunden.
  * Wasser deckend statt transparent (zwei bildschirmfüllende, sortierte Alpha-Flächen mit je 18.800
    Dreiecken waren der größte Einzelposten); Unterteilung gedeckelt.
  * Geometrie-Diät für alle prozeduralen Grundkörper, kleine Deko wirft keine Schatten mehr (z. B. 680 → 268
    Schattenwerfer), Sichtweiten-Culling kleiner Deko, Lichter blenden mit Entfernung aus.
  * Browser: eine Schattenkaskade unter „Hoch“, kürzere Schattendistanz, Glow nur auf Ultra, weniger Partikel.
  * Animations-LOD für Statisten (halbe/viertel Rate in der Ferne), Slapstick-Modifier nur nahe der Kamera.
* **Pinguin-Curling neu:** Pinguin liegt beim Zielen direkt vor der Figur und dreht sich in Schussrichtung
  (Stick, Stick-Richtung oder Maus), gepunktete Ziellinie mit Bandenabprall; jede Runde eine neue Bahn aus
  7 Layouts (Geraden, Kurven, S-Kurve, Slalom, Prellbock) mit Banden und Hindernissen.
* **10 Boss-Gegner** (je Brett einer, Kampfsystem ab 1.1.5 in Echtzeit): drei
  Fähigkeiten, drei Phasen (Wut-Phase mit Doppelangriff) und eine Einzigartigkeit pro Boss; vollständig
  prozedurale, animierte Modelle (Atmen, Schweben, Glühen, Rauch, Blasen, Zahnräder …) mit eigenen
  Aktions-Animationen. Münz- und Item-Effekte werden auf dem Brett verrechnet.

## 1.1.3
* **Performance (vor allem im Browser):**
  * 3D-Pixelbudget: Auf Retina-/4K-Displays (devicePixelRatio 2–3) wurde die Szene bisher in voller
    Geräteauflösung gerendert. Jetzt max. ~1700 px Breite (Ultra 2200) mit Hochskalierung; die UI bleibt scharf.
  * Dynamische Auflösung steigt bei dauerhaft zu niedrigen FPS jetzt auch eine Qualitätsstufe ab, statt an
    der Untergrenze stecken zu bleiben (nur bei Qualität „Auto“).
  * WebGL: MSAA nur noch auf „Ultra“, Glow erst ab „Hoch“, weiche Schattenfilter aus.
  * Physik: höchstens 4 Physik-Schritte pro Bild (keine Verlangsamungs-Spirale auf schwachen Geräten).

## 1.1.2
* **Automatisches Deployment:** Jeder Push auf `main` baut per GitHub Actions den Web-Export, führt das
  PWA-Postprocessing und den Browser-Rauchtest aus und veröffentlicht auf GitHub Pages
  (https://rxplxcxd.github.io/lumos-party-game/). Kein manueller ZIP-Download mehr nötig.
  Einmalig nötig: Settings → Pages → Source „GitHub Actions“ (oder Secret `PAGES_TOKEN`).
* **Fix (Online-Rennen):** Kam ein entfernter Fahrer als letzter Mensch ins Ziel, endete das Rennen auf dem
  Client nie (sein Ziel-Status wurde vor dem Rundenzähler gesetzt, die Ziel-Prüfung lief nicht). Jetzt wird
  jede Physik-Runde geprüft. Das war auch die Ursache des seit Tagen roten CI-Online-Tests.
* **Schlanker Web-Build:** Die Musik (≈ 30 MB) steckt nicht mehr im Start-Paket – `index.pck` schrumpft von
  49,6 auf 19,7 MB. Die Songs liegen als `music/…ogg` neben dem Spiel, werden bei Bedarf sofort und sonst im
  Hintergrund nacheinander geladen (Menü → Minispiele → Bretter). Native Builds behalten alles im PCK.
* **Schlankes Repository:** 34.371 nie importierte Dateien (≈ 685 MB) entfernt – FBX-/OBJ-/DAE-/STL-Duplikate,
  Vorschaubilder, Vektor-/Spritesheet-Varianten und ungenutzte Pakete, die Godot per `.gdignore` ohnehin
  übersprang. Das Spiel nutzt ausschließlich GLB/glTF; Inventar (`docs/ASSET_INVENTORY.md`) neu erzeugt.
  Texturen machen im Build nur 0,24 MB aus, Musik ist bereits effizient kodiert (≈ 108 kbit/s Vorbis) –
  eine erneute verlustbehaftete Kompression hätte hörbar geschadet und wurde bewusst nicht gemacht.

## 1.1.1
* **Fix: Web-Build hing beim Laden („Lädt Spielwelt … 59 %“).** Ursache: Godots Web-Lader reicht einen
  mitten im Download abreißenden Stream nie als Fehler weiter – der Balken friert dann für immer ein.
  Ausgelöst wurde das vor allem durch den Service Worker, der bei jedem neuen Build ~90 MB parallel
  vorgeladen, sich per `skipWaiting`/`clients.claim` mitten im Laden ausgetauscht und die großen Dateien
  durch sich hindurchgestreamt hat.
  * Ladebildschirm lädt `index.wasm`/`index.pck` selbst: Stillstand-Erkennung (15 s), Vollständigkeits-
    Prüfung, bis zu 4 Versuche; Wachhund mit „Neu laden“ (entfernt alte Service Worker & Caches).
  * Service Worker greift online nicht mehr in die großen Dateien ein, wird erst nach dem Spielstart
    registriert und legt sie danach im Hintergrund für den Offline-Start ab.
* **Neuer Ladebildschirm & neues Logo** aus echten Spiel-Assets (Ritter im Kart, Party-Stern, Würfel,
  Münzen) – gerendert mit `tools/brand/render_logo.gd`, Icons aus `tools/brand/make_icons.py`; Spiel-
  Schriften (Lilita One, Fredoka), gestreifter Ladebalken mit Stern, Tipps, Versionsanzeige.
* Neue App-Icons (PWA, Lumos Store, Projekt-Icon).

## 1.1.0
* Wolkenturm, Kolosseum-Turnier, eigene 3D-Avatare, 5 neue Minispiele, Themen-Tierchen, nur hochgeladene
  Soundtracks, Web-Build nicht mehr im Repo (siehe Git-Historie bis 9c2bdfe3).
