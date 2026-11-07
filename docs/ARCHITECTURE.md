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
