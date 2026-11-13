# Character Animation & Interaction Framework

Wiederverwendbares Fundament für lebendige Figuren: Mimik, prozedurale Körperbewegung, IK mit Handdrehung,
Fußverankerung, Fortbewegung mit synchronen Schritten und Interaktionen. Liegt in `scripts/actor/`, Testlabor in
`tools/charlab/`.

**Stand 1.5.1:** implementiert und im Labor gemessen (Werte unten). Der **Trailer** nutzt das Framework als einzige
Umsetzung (die alten Kopien `trailer_face.gd` / `trailer_body.gd` sind entfernt). **Noch nicht** in Spielabläufe
eingebaut: Brett, Minispiele und Nitro Dash nutzen es nicht. Version 1.5.0 bleibt als Rückfall im Verlauf erhalten.

## Architektur

| Datei | Klasse | Aufgabe |
|---|---|---|
| `lumos_actor.gd` | `LumosActor` (Node) | Fassade. Hängt alles an ein `CharacterRig`, treibt die Teile je Bild an, Detailstufen (LOD). |
| `lumos_face.gd` | `LumosFace` (Node3D) | Gesichtsebene am Kopfknochen: Augen, Lider, Glanzpunkte, Brauen, Wangen, Mund. |
| `lumos_body.gd` | `LumosBody` (SkeletonModifier3D) | Arm-IK mit Handdrehung und Reach-Assist, Fußanker, Haltung, Blick, Atmung, Lachen, Stoß-Feder. |
| `lumos_locomotion.gd` | `LumosLocomotion` (RefCounted) | Zustände, Überblendung, Schritt-Synchronisierung, Trägheit. |
| `lumos_interact.gd` | `LumosInteract` (RefCounted) | Greifen, Tragen, Werfen, Weitergeben, Lenkrad, High-Five, Umarmung, Schubser, Schulterklopfen. |
| `lumos_actor_config.gd` | `LumosActorConfig` (Resource) | Adapter: Profil, Knochennamen und Stellgrößen je Figurentyp, `detect(rig)`. |

Das Framework verändert weder `CharacterRig` noch die Modelle. Es nutzt Clips und Überblendung über
`CharacterRig.play()` und den Kopf-Blick des `SlapstickModifier` (`look_target`, `look_weight`). `LumosBody` ist ein
zweiter Modifier und läuft danach.

### Adapter: Profile je Figurentyp

`LumosActorConfig.detect(rig)` liest das Skelett und wählt ein Profil. Jede Funktion prüft, ob sie für das Profil
möglich ist, und fällt sonst sauber zurück (keine Fehler, keine halben Posen).

| Profil | Erkennung | Gesicht | Arme | Beine | Haltung/Stoß | Geprüft mit |
|---|---|---|---|---|---|---|
| `humanoid` | Skelett mit Schulter-Ellbogen-Hand und Hüfte-Knie-Fuß | ja | Zwei-Knochen-IK, Handdrehung | Fußanker, Bodenabfrage | Knochen | 4 KayKit-Helden |
| `simple` | Skelett mit einteiligen Gliedmaßen | nein (Augen nicht erkennbar) | Arm zielt zum Punkt („aim“) | keine Fuß-IK | Knochen | Kenney `mini/male_a`, `mini/robot` |
| `rigid` | kein Skelett | nein | keine | keine | ganzer Körper kippt/wippt (`rig.pivot`) | Haustiere `pet/cat`, `pet/dog` |

`actor.capabilities()` liefert, was eine Figur kann: `{profile, face, brows, arms, hand_orient, legs, foot_lock,
posture}`. Eigene Typen: Konfiguration von `detect()` holen und Knochennamen oder Werte überschreiben.

## Schnellstart

```gdscript
var actor := LumosActor.attach(rig)              # Profil automatisch; erneuter Aufruf liefert denselben Akteur
actor.move(wish_velocity, grounded, delta)       # Trägheit, Position, Animation, Körperneigung
actor.feel("joy", 0.2, 0.7)                      # Gesicht UND Haltung (Brust, Kopf, Schultern)
actor.laugh(1.4)                                 # Lachen als Kette aus Gesicht und Körper
actor.look_at_target(other_actor)                # Augen, Kopf, Oberkörper; neuer Blickkontakt hebt die Brauen
actor.interact.grab(item, "r")                   # hinschauen, Handfläche von oben, greifen, auf der Handfläche tragen
actor.interact.throw_to(target_position)
LumosInteract.high_five(actor_a, actor_b)
```

Wird die Figur vom Spiel selbst bewegt (`CharacterBody3D`, Streckenkoordinaten), ersetzt
`actor.animate(echte_geschwindigkeit, grounded, delta)` den Aufruf von `move()`.

## LumosActor

| Methode | Wirkung |
|---|---|
| `attach(rig, config = null)` (static) | Framework anhängen (`config` leer = `detect()`). `of(rig)` liefert einen vorhandenen Akteur. |
| `move(wish, grounded, delta)` / `animate(velocity, grounded, delta)` | Mit bzw. ohne eigene Positionierung. |
| `feel(name, secs, intensity)` (= `express`) | Ausdruck in Gesicht und Haltung; Figuren ohne Gesicht/Skelett zeigen ihn mit dem ganzen Körper. |
| `laugh(duration, strength, then)` | Schmunzeln → Lachen → klingt aus → Ausdruck `then`. |
| `look_at_target(t)` | `Vector3`, `Node3D`, `LumosActor` (ins Gesicht) oder `null`. Oberkörper und Hüfte drehen mit. |
| `react_hit(from_dir, strength, stumble)`, `nudge(world_impulse)` | Treffer bzw. Stoß: Oberkörper federt gedämpft nach. |
| `reach(hand, target, secs, orient, assist)` / `release(hand, secs)` | Hand an ein Ziel führen. `orient` = `[Finger, Handfläche]` (Welt) oder `Callable`; `assist` 0–1 = wie weit sich die Brust zu einem fernen Ziel lehnen darf. |
| `palm(finger, palm_normal)` (static) | Hilfe zum Bauen von `orient`. |
| `hand_pos(hand)`, `hand_weight(hand)`, `rel(right, up, fwd)`, `forward()`, `right()`, `head_radius()` | Hilfen für eigene Interaktionen. |
| `set_breath(amount, rate)`, `time_scale` | Atmung, Zeitlupe je Figur. |
| `set_enabled(on)` | Framework für diese Figur aus/an (aus = nur die normale Animation des Spiels). |
| `lod` | 0 voll · 1 fern (`cfg.lod_far`): ohne Fußanker und Oberkörper-Blick, Gesicht seltener · 2 seit 0,4 s außerhalb des Bildes: Körper-Modifier und Gesicht pausieren. `cfg.lod = false` = immer voll (Filme). |

Signale: `laughed`, `hit_reacted(strength)`, `hand_reached(hand)`, `hand_released(hand)`.

## LumosFace

Die Lumos-Helden haben starre Augen (kleine Kapseln im Kopf-Mesh) und keinen Mund. `setup(rig)`:
1. sucht das Kopf-Mesh und vermisst Augen (dunkel, bläulich), Hautfarbe und Brauen – alle Schwellen relativ zur
   Kopfgröße, Ergebnis je Modell zwischengespeichert,
2. versenkt die Original-Augen in einer **eigenen Kopie** des Meshs (das Modell bleibt unverändert),
3. rastert die Kopfoberfläche (Tiefe und Normalen) und legt jedes Gesichtsteil auf eine angenäherte
   Flächenkrümmung (`_plane`) – Augen und Mund liegen bei jedem Blickwinkel auf der Haut, ohne zu schweben und
   ohne den Kopf zu durchdringen (geprüft frontal, 45° und 75°),
4. zeichnet Brauen nur, wenn die Original-Brauen eindeutig ersetzt werden (`has_own_brows`); doppelte nie.

Ausdrücke (`LumosFace.EXPR`): `neutral, smile, grin, joy, laugh, awe, surprised, curious, confused, scared, worried,
sad, angry, determined, sleepy, asleep, pant, ouch, smug, dreamy, plead`. Parameter (`KEYS`): `lid, squint, wide,
brow, tilt, asym, open, curve, width, round, blush`.

**Lesbarkeit aus der Ferne (1.5.1):** Münder deutlich größer (Grundbreite +25 %, rundes „O“ beim Staunen),
geschlossene Mundlinie kräftiger, offener Mund bei negativen Gefühlen oben gewölbt („∩“, Grimasse statt Grinsen),
Wangenröte bei Freude, kurzes Brauen-Heben bei neuem Blickkontakt.

| Mitglied | Bedeutung |
|---|---|
| `set_expression(name, secs, intensity)` / `set_expr` | Übergang zum Ausdruck. `intensity` mischt mit „neutral“. |
| `add_expression(name, params)` | Eigenen Ausdruck registrieren. |
| `flash_brows(amount)` | Brauen kurz heben (Erkennen, Begrüßen). |
| `laugh`, `laugh_phase`, `chew`, `gaze`, `blink_on`, `feature_scale` | Mundrhythmus, Blick, Lidschlag, Größe der Gesichtsteile. |
| `paused` | Keine Aktualisierung (LOD außerhalb des Bildes). |
| `param(key)`, `metrics()` | Für Tests: aktueller Wert, vermessene Größen (`u` = Kopfbreite). |

Neu gezeichnet wird nur bei sichtbarer Änderung, nah jedes Bild, mittel 20 Hz, fern 5 Hz.

## LumosBody

Additiv über der Animation, alles geglättet. Zeitbasis `dt` (setzt `LumosActor`), also bildratenunabhängig.

| Mitglied | Bedeutung |
|---|---|
| `hand_t`, `hand_w`, `hand_dir`, `hand_assist` | Ziel (Welt), Gewicht, Handhaltung `[Finger, Handfläche]`, Reach-Assist je Hand. |
| `ground` | `Callable(Vector3) -> float`: Bodenhöhe. Leer = Raycast (`cfg.ground_mask`), sonst Fallback. |
| `grounded`, `foot_w` | Fußanker an/aus (in der Luft, im Fahrzeug, in Posen aus). |
| `set_posture(name, secs, intensity)` | Haltung je Gefühl (Brust, Kopf, Schultern, Neigung). |
| `attend_target`, `attend_w` | Blickziel: Hüfte 30 %, Brust 70 % der Drehung, der Kopf bleibt auf dem Ziel. |
| `lean`, `head_add`, `chest_add`, `breath`, `breath_rate`, `laugh` | Neigung, Gesten, Atmung, Lachen. |
| `push(world_impulse)` | Stoß: Oberkörper und Kopf schwingen gedämpft nach. |
| `joint_pos(name)` | Weltposition **nach** allen Modifikatoren: `hand`, `shoulder`, `elbow`, `thigh`, `knee`, `foot` (`.l/.r`), `head`, `chest`, `hips`. |
| `rest_pos(name)` | Gelenk in Ruhepose mit aktueller Skelettlage – sofort gültig, auch direkt nach einem Versetzen. |
| `hand_axes(hand)` | Finger- und Handflächenrichtung (Welt) nach der Modifikation. |
| `arm_length()`, `reach_length()`, `wrist_offset(hand)` | Schulter→Hand, Schulter→Handgelenk, Handgelenk→Hand (Welt). |

Wichtig: Godot setzt Knochen nach dem Skinning zurück. Von außen abgefragte Posen sind die **ohne** Modifikatoren.
Für Hand- und Fußpositionen immer `joint_pos()` verwenden, direkt nach einem Teleport `rest_pos()`.

**Hand-IK:** Zwei-Knochen-Lösung mit Pol-Richtung, Reichweite auf 98,5 % begrenzt. Mit Handhaltung endet die Kette
am Handgelenk: Das Handgelenk wird so gesetzt, dass die *gedrehte* Hand genau am Ziel liegt. Wechsel der
Handhaltung gleiten (Slerp, 70 ms) statt umzuklappen. **Reach-Assist:** liegt das Ziel außer Reichweite, dreht
sich die Brust um ihren Ursprung, bis die Schulter es erreicht (höchstens `cfg.reach_lean`, je Hand mit `assist`
dosierbar – bei Umarmungen klein, damit die großen Köpfe nicht zusammenstoßen).

**Fußanker:** In der Standphase (der Fuß ist im Clip auf seiner tiefsten Höhe) wird der Fuß in der Welt verankert
und erst beim Anheben gelöst; zu weites Ziehen löst ihn mit einem kurzen Schrittbogen. Bodenhöhe aus `ground`, sonst
Raycast; das Becken senkt sich, wenn ein Fuß tiefer steht. Teleports (> 1,5 m je Bild) lösen alle Anker.

## LumosLocomotion

* `stride_speed(rig, clip, fallback)` vermisst das Tempo, bei dem der Standfuß stillsteht (Helden: Gehen 0,87 m/s,
  Laufen 3,14 m/s bei Skalierung 1).
* `update(velocity, grounded, delta)` wählt den Zustand und passt die Abspielgeschwindigkeit an (Gehen 0,45–1,9×,
  Laufen 0,6–1,75×), mit Hysterese. `steer(wish, delta)` glättet die Geschwindigkeit (`cfg.accel`, `cfg.decel`).
* `play_action(name, clip, secs, blend, speed)`: einmalige Aktion (`stumble`, `dance`, `fall_down`, `cheer`, `throw`).

## LumosInteract

| Methode | Ablauf (Anfang → Höhepunkt → Ende) |
|---|---|
| `grab(obj, hand, secs)` | Blick, Handfläche von oben auf die Oberfläche, zugreifen, Gegenstand liegt auf der nach oben gedrehten Handfläche. |
| `drop(hand)`, `throw_to(target, hand, arc, flight)`, `give(to, hand, to_hand)` | Loslassen · Ausholen, Durchziehen, Nachschwung · Übergabe Hand zu Hand. |
| `hold_wheel(wheel, radius)` / `release_wheel()` | Beide Hände am Kranz (10 und 2 Uhr), Finger entlang des Kranzes, folgt der Drehung. |
| `high_five(a, b)` (static) | Rechte Schultern einander gegenüber (Köpfe seitlich versetzt), Abstand aus der echten Reichweite, Treffpunkt über Schulterhöhe, Handflächen berühren sich (Finger oben), beide federn zurück, lachen. Ohne Zwei-Knochen-Arme: Stups mit Körper-Reaktion. |
| `hug(a, b, hold)` (static) | Annähern (Köpfe seitlich), Arme um die Schultern, andrücken, lösen, zurücktreten. |
| `shove(a, b, strength)`, `pat(a, b, hand, count)` (static) | Handflächen an der Brust, Partner taumelt · Handfläche auf der Schulter, die Schulter gibt bei jedem Klopfer nach. |

Signale: `grabbed(obj, hand)`, `released(obj, hand)`, `thrown(obj)`, `landed(obj, pos)`, `contact(kind, other)`.

## Konfiguration (`LumosActorConfig`)

`profile`, Knochennamen (`bone_hips`, `bone_chest`, `bone_head`, `arm_bones`, `leg_bones`, `wrist_bones`),
`palm_rest` (Handflächen-Normale der Ruhepose), Gesicht (`face_enabled`, `feature_scale`), Atmung, `idle_sway`,
Neigung, Stoß-Feder, `posture_scale`, `attention`, `reach_lean`, Füße (`foot_ik`, `foot_lock`, `foot_ik_max`,
`ankle_height`, `ground_mask`), Leistung (`lod`, `lod_far`), Fortbewegung (`walk_speed`/`run_speed` 0 = vermessen,
`accel`, `decel`, `turn_rate`).

## Testlabor (Animation Quality Gate)

```bash
./godot --path . res://tools/charlab/CharLab.tscn
```

```bash
./godot --headless --fixed-fps 60 --path . res://tools/charlab/CharLab.tscn -- --lab-auto
```

```bash
xvfb-run -a ./godot --path . res://tools/charlab/CharLab.tscn -- --lab-faces=/ordner
```

Interaktiv (Tasten `1`–`0`, `U` Umarmung, `S` Schubser, `P` Schulterklopfen, `B` Bodenstufe), automatisch mit
Messung (Ende: `CHARLAB OK`, läuft in der CI), Gesichter je Ausdruck aus 0°, 45°, 75°. Immer mit `--fixed-fps 60`.

Messwerte 1.5.1 (headless, CPU):

| Bereich | Prüfung | Ergebnis |
|---|---|---|
| Kompatibilität | 4 Helden `humanoid`, 2 Kenney `simple`, 2 Haustiere `rigid`; alle API-Aufrufe fehlerfrei | bestanden |
| Fußanker | Standfuß-Rutschen Gehen 0,67 m/s / Laufen 2,2 m/s / Gehen+Tragen+Schauen+Lachen | 0,009 / 0,040 / 0,019 m/s (1.5.0: 0,2 / 0,6) |
| Boden | Fuß auf 20-cm-Stufe per Callable / per Raycast | 205 / 203 mm höher, Becken senkt sich |
| Hand | Griff an Balloberfläche · Handfläche beim Greifen unten · beim Tragen oben · Wechsel je Bild | 0 mm · 0° · 0° · 11,6° (weich) |
| Lenkrad | Hände am drehenden Kranz · Finger entlang des Kranzes | 3 mm · 3° (1.5.0: 131 mm) |
| High-Five | Abstand der Hände · Handflächen zueinander · Kopfabstand | 50 mm (= Handflächen berühren sich) · −1,00 · 1,00 m (1.5.0: 438 mm) |
| Umarmung | Brustabstand · Köpfe · Lösen | 0,80 m · 0,66 m seitlich versetzt · gelöst |
| Mimik/Haltung | 21 Ausdrücke erreicht · größter Sprung je Bild · Kopfweg „sad“↔„joy“ · Lachen Gesicht/Körper | ja · 0,30 · 96 mm · synchron (0,000) |
| Blick | Schulterlinie dreht mit · Augen wandern | 104 mm · 0,16 |

Leistung (gesamte Bildzeit, alle Figuren gehen, lachen, schauen, zwei Paare klatschen ab, Zusatzfiguren tragen;
„Framework“ = Differenz zur selben Szene mit abgeschaltetem Framework):

| Figuren | 1 | 4 | 8 | 16 | 16 außerhalb des Bildes (LOD) |
|---|---|---|---|---|---|
| Bildzeit | 0,8 ms | 2,2 ms | 3,2 ms | 4,3 ms | 0,65 ms |
| davon Framework | 0,46 ms | 1,8 ms | 2,8 ms | 3,9 ms | – |

(1.5.0: 13 ms für 16 Figuren.) Gemessen auf dem Entwicklungsrechner ohne Grafik; Werte schwanken je Lauf um ~20 %.

## Einsatz im Trailer

`trailer/trailer.gd` hängt je Darsteller `LumosBody` und `LumosFace` an (`detect()`), mit `ground_mask = 0` und
Boden = Standhöhe der Figur, `lod = false`, `attention = 0.42`. `expr()` setzt Gesicht und Haltung, der Blick dreht
den Oberkörper mit, `reach()` nimmt eine Handhaltung, Kontakte geben mit `push()` Gewicht weiter, der Fußanker ist
nur beim Stehen/Gehen/Laufen auf Bodenhöhe aktiv.

## Integrationsbeispiele

**Nitro Dash, Hände am Lenkrad:** `LumosActor.attach(visual.hero)`, dann `actor.interact.hold_wheel(wheel, 0.2)`.
**Item werfen:** `actor.interact.held["r"] = item`, auf `thrown` hören, `actor.interact.throw_to(aim)`.
**Minispiel:** `actor.react_hit(dir, 1.0, true)`, `winner.laugh(1.6)`, `winner.look_at_target(loser)`.
**Brett:** `LumosInteract.high_five(a, b)` nach einem Team-Sieg, `actor.look_at_target(star_node)` vor dem Sternkauf.

## Bekannte Grenzen (ehrlich)

* **Nicht im Spiel eingebaut.** Brett, Minispiele und Nitro Dash laufen unverändert ohne Framework.
* **Kenney-Figuren:** kein Gesicht (Augen im Mesh nicht erkennbar), Arme nur zielend ohne Handdrehung, keine Fuß-IK.
* **Haustiere:** nur Ganzkörper-Haltung, -Stoß und -Lachen; kein Gesicht, keine Gliedmaßen-IK.
* **Eigene Avatare (Lumos OS, auf das KayKit-Rig umgezielt):** erwartet Profil `humanoid`, im Labor aber **nicht
  geprüft** (kein Beispiel-Avatar offline verfügbar). Gesicht hängt davon ab, ob die Augen im Mesh erkennbar sind.
* **Leistung:** nur CPU headless gemessen. GPU-Kosten und Web (WebAssembly, langsamer als nativ) sind **nicht**
  gemessen. Der teuerste Teil ist das Neuzeichnen lachender Gesichter.
* Fußanker beim Laufen: Rest-Rutschen 0,04 m/s. Gehaltene Objekte folgen der Hand ohne Kollision. Keine Finger.
* Bodenabfrage per Raycast trifft jedes Objekt der Maske – in dekorierten Szenen eine eigene `ground`-Funktion setzen.
