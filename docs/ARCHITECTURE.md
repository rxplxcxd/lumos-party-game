# Architektur

## Autoloads (Reihenfolge in `project.godot`)

| Name | Datei | Aufgabe |
|---|---|---|
| `EventBus` | `autoload/event_bus.gd` | Lose Kopplung: `cutscene_requested`, `camera_shake`, `coins_changed`, `item_hit` … |
| `Game` | `autoload/game_state.gd` | Spieler, Helden, Bretter/Minispiele/Strecken-Tabellen, Party-Zustand, Einstellungen (`user://settings.cfg`) |
| `Assets` | `autoload/assets.gd` | Zentraler Modell-/Icon-Katalog (kurze Schlüssel), Instanzierung, AABB-Cache, Tint, geteilte Rig-Animationsbibliothek |
| `Audio` | `autoload/audio_manager.gd` | SFX-Pools (2D/3D), Musik-Crossfade, Ansager, Jingles mit Ducking, Motor-Loops |
| `InputHub` | `autoload/input_hub.gd` | 4 Spieler-Slots: Tastatur + Touch + Gamepads + virtuelle CPU-Eingaben, Kanten-Erkennung, Haptik |
| `Juice` | `autoload/juice.gd` | Besitzt `Engine.time_scale` (Hitstop, Zeitlupe, Vorspulen), Trauma-Shake, FOV-Punch, Squash & Stretch, schwebende Zahlen |
| `FX` | `autoload/fx.gd` | CPUParticles3D-Bibliothek (Staub, Sand, Spritzer, Funken, Konfetti, Explosion, Münzen, Benommenheits-Sterne …) |
| `CutsceneManager` | `autoload/cutscene_manager.gd` | Spielt `scenes/cutscenes/*.tscn`, eigene Cine-Kamera, Letterbox, Titelkarten, Countdown |
| `Router` | `autoload/scene_router.gd` | Szenenwechsel mit Stern-Wipe (`assets/shaders/star_wipe.gdshader`) |

## Eingabe

`InputHub` liefert für jeden Slot `move()`, `held()`, `pressed()`. Kanten werden an den SceneTree-Signalen
`process_frame`/`physics_frame` erkannt – InputHub verbindet sich zuerst und läuft deshalb vor allen
Koroutinen (`await get_tree().process_frame`) und allen `_process`-Aufrufen. `pressed()` erkennt automatisch,
ob aus der Physik- oder Prozess-Schleife gefragt wird. CPU-Spieler schreiben per `set_virtual()` in denselben
Kanal, Minispiele müssen also nicht zwischen Mensch und KI unterscheiden.

## Charaktere & Animationen

* `CharacterRig` (`scripts/core/character_rig.gd`) mappt logische Clips (`idle`, `run`, `cheer`, `hit`, `sit_chair` …)
  auf drei Rig-Familien: KayKit Rig_Medium (Helden), Kenney-Standard (Mini-Charaktere, Skelett, Geist) und Cube-Pets.
  Die KayKit-Clips stammen aus `KayKit_Character_Animations_1.1` und werden einmalig zu einer `AnimationLibrary`
  zusammengeführt (`Assets.rig_library()`), die sich alle Helden teilen.
* `SlapstickModifier` (`SkeletonModifier3D`) addiert prozedurale Bewegungen nach der Animation.
* `ReactionClip`-Ressourcen (`assets/animations/reactions/*.tres`) bündeln Clip, Modifier, Squash, Partikel,
  Emote und Sound. `rig.react("tantrum")` spielt alles zusammen ab.

## Cutscenes

Eine Cutscene ist eine Szene mit einem Skript, das von `Cutscene` erbt und `run(director, ctx)` implementiert.
Der Director (`CutsceneManager`) bietet awaitbare Primitive: `cut`, `move`, `orbit`, `fly_path`, `track`, `zoom`,
`punch`, `shake`, `title`, `subtitle`, `big_word`, `flash`, `fade`, `letterbox`, `countdown`, `wait`.
Gestartet wird per `await CutsceneManager.play("Podium", {...})` oder `EventBus.cutscene_requested.emit(...)`.

## Modus A – Brettspiel

* `BoardDefs` beschreibt jedes Brett als geschlossene Hauptschleife (Catmull-Rom) + Abzweigungen; daraus entsteht
  ein Feld-Graph mit `next`/`prev`. Routen können rundenabhängig offen sein (`toggle`) oder Wegzoll kosten (`gate`).
* `BoardBuilder` baut Felder, Pfade (MultiMesh), Themen-Kulisse, NPCs und animiert die wechselnden Routen.
* `party_board.gd` steuert Runden, Züge, Würfel, Abzweig-Wahl, Feld-Events, Stern, Händler, Minispiel-Roulette und das
  Finale. Der Zustand liegt in `Game.party` und überdauert den Wechsel in die Minispiel-Szene und zurück.

## Minispiele

`MinigameBase` übernimmt Ablauf (Teaser → Anleitung → Countdown → Spiel → Sieger → Ergebnis → Rücksprung),
HUD, Timer, Platzierungslogik (Punkte, Überleben, Rennen) und ruft pro Physik-Frame `cpu_think()` für CPU-Slots auf.
Jedes Minispiel überschreibt nur `build_arena()`, ggf. `spawn_players()`, `on_tick()`, `check_end()` und `cpu_think()`.

## Modus B – Nitro Dash

* `RaceTrack` sampelt den Spline selbst und berechnet stabile Rahmen: Welt-oben + Banking, im Looping analytisch
  zur Loop-Achse (die eingebauten Up-Vektoren von `Curve3D` driften im Looping). Fahrbahn, Leitplanken, Unterseite,
  Glas-Tunnel und Boost-Felder entstehen prozedural.
* `Racer` simuliert im Strecken-Raum (`s`, `x`, `h`, `psi`, `v`): dadurch kleben Karts sauber in Loopings,
  Leitplanken-Abpraller und Item-Projektile (Kuchendeckel prallt lateral ab) sind exakt, und die KI fährt eine
  Ideallinie mit Krümmungs-Vorsteuerung.
* `NitroDash` verwaltet Rennen, Items, Kollisionen, Platzierungen, Kamera, HUD und Minimap.

## Web-Export

* `project.godot`: GL-Compatibility, verlustfreie Texturen (`importer_defaults`), Jolt-Physik.
* `tools/asset_pipeline.py` setzt `.gdignore` für FBX/OBJ/DAE/STL/Previews und ungenutzte Pakete
  (Import aller verwendeten Pakete ≈ 2 Minuten).
* `tools/export_list.gd` erzeugt `export_presets.cfg` mit exakter Dateiliste aus dem Katalog.
* `web/shell.html` ist die eigene HTML-Shell (Ladebildschirm, iOS/Android-Meta, Installieren-Button,
  Drehen-Hinweis, Vollbild, Lumos-OS-Erkennung über `window.LumosCloudSDK` / `?lumos=1`).
* `tools/postexport_pwa.py` erzeugt den Service Worker (versionierter Precache, Network-First für die Seite,
  Cache-First für Engine/PCK), Manifest, Icons, Store-Metadaten und das ZIP.

## Speicher & Langzeit-Stabilität (seit 1.2.7)

Lange Sessions (11–15 Runden) haben im Browser – vor allem auf iPhones – den Tab neu laden lassen. Ursachen und
Gegenmittel:

* **Schrift-Glyphen:** Jede Schriftgröße × Konturstärke × Gewicht legt eigene Glyphen-Texturen an (gemessen:
  ~3 MB je Größe mit Kontur), die die Engine nie freigibt. Angepasste Labels, schwebende Texte, Bossnamen …
  erzeugen über eine Session hunderte Größen. `UI.clear_font_caches()` leert beim Szenenwechsel die Größen-Caches
  (die Schriften bleiben gültig, Texte zeichnen weiter). Nachmessen: `tools/dev/font_mem.gd` (53 Größen: 163 MB →
  8 MB).
* **Deko-Ausrichtung:** Der Dreiecks-Cache von `PropSettler` hielt jedes Mesh jeder Szene fest – jetzt nur noch
  während eines Laufs.
* **Kart-Motoren:** eine Loop-Kopie je Sound statt je Kart (im Browser wird jeder neue Stream als Sample dekodiert
  und nie freigegeben).
* **Szenenwechsel:** alte Szene erst ganz freigeben, dann laden; Modell-Cache behält nur die letzten zwei Szenen.
* **Messen:** `--log-scenes` (auch im Web als `?args=--log-scenes`) schreibt bei jedem Wechsel Speicher, Objekte,
  Ressourcen, verwaiste Knoten, Textur-/Puffer-Speicher und Cache-Größen – einmal mit Szene, einmal ohne.
* **Langzeit-Test:** `tools/dev/soak.gd` spielt eine CPU-Party über viele Runden im Schnellvorlauf und schlägt
  fehl, wenn Speicher, Objekte oder (mit Rendering unter xvfb) Grafikspeicher von Runde zu Runde wachsen oder
  eine Szene hängt. In der CI mit 12 Runden; lokal z. B. `--rounds=20`. Im Browser: `node tools/dev/web_soak.js
  <url> <minuten>` (WASM-/JS-Heap, Browser-RAM).
* **Schatten:** Kulisse weit außerhalb der Arena wirft keine Schatten (spart Zeichenaufrufe je Schattenkarte),
  kleine Teile haben Sichtweiten, Statisten laufen mit Animations-LOD.

## Saison-Deko (seit 1.2.8)

`Seasonal` (`scripts/core/seasonal.gd`) erkennt die Saison am Gerätedatum oder an der Einstellung `season_deco`
(`auto`/`off`/`christmas`/`halloween`, Test: `--season=`). Brett (`BoardBuilder._build_seasonal`), Minispiel-Kulisse
(`MinigameBase._seasonal_deco`, abschaltbar mit `no_seasonal`) und Hauptmenü übergeben Kandidaten-Stellen.
`decorate()` mischt sie mit einem lokalen, ortsfesten Zufall und prüft jede Stelle:

* fester Untergrund unter Mitte und Rand der Grundfläche (`PropSettler._ground_at`, ohne Wasser/Lava-Shader),
* keine Überlappung mit vorhandenen Modellen (bei Bäumen zählt nur der Stamm, Bodendecker gar nicht),
* `exclude(p)` sperrt die Spielfläche, `allow_tall(p)` erlaubt Hohes nur außerhalb der Kamerasicht.

`centerpiece()` sucht spiralförmig um einen Wunschpunkt Platz für ein Ensemble (Baum + Geschenke bzw. Kürbishaufen).

## Trailer (seit 1.2.8)

`trailer/trailer.gd` (eigenständige Produktion, vom Spiel getrennt – siehe `trailer/README.md`) ist ein kleines
Regie-System: Zeitereignisse (`at`), Wegstrecken mit weichem
Anfahren und Abbremsen (`go`), Blickziele (`look`), Haltungen (`pose`), Reaktionen (`react`) und Kamera-Keys mit
Schnitten (`key`). Die Sets liegen weit auseinander in einer Szene, und gewechselt wird nur dann, wenn ein
Verdecker das Bild füllt (Stamm, Wasserwand, Lichtblitz). So gibt es keine sichtbaren Sprünge. Im Movie-Maker-Modus
läuft alles mit fester Bildrate, deshalb ist jeder Render gleich. Tiefenschärfe gibt es im GL-Compatibility-Renderer
nicht. Die Bildtiefe entsteht über Nebel, Licht und Brennweite.
