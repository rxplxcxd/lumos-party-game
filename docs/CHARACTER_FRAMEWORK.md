# Character Animation & Interaction Framework

Wiederverwendbares Fundament für lebendige Figuren: Mimik, prozedurale Körperbewegung, IK, Fortbewegung mit
synchronen Schritten und Interaktionen. Liegt in `scripts/actor/`, Testlabor in `tools/charlab/`.

**Stand:** implementiert und im Labor geprüft. **Noch nicht** in Spielabläufe eingebaut: Brett, Minispiele, Nitro
Dash und der Trailer nutzen es nicht. Der Trailer hat eigene, ältere Kopien von Gesicht und Körper in `trailer/`.

## Architektur

| Datei | Klasse | Aufgabe |
|---|---|---|
| `lumos_actor.gd` | `LumosActor` (Node) | Fassade. Hängt alles an ein vorhandenes `CharacterRig`, treibt die Teile je Bild an. |
| `lumos_face.gd` | `LumosFace` (Node3D) | Gesichtsebene am Kopfknochen: Augen, Lider, Glanzpunkte, Brauen, Mund. |
| `lumos_body.gd` | `LumosBody` (SkeletonModifier3D) | Arm-IK, Fuß-IK, Atmung, Gewichtsverlagerung, Lachen, Impuls-Feder. |
| `lumos_locomotion.gd` | `LumosLocomotion` (RefCounted) | Zustände, Überblendung, Schritt-Synchronisierung, Trägheit. |
| `lumos_interact.gd` | `LumosInteract` (RefCounted) | Greifen, Halten, Werfen, Weitergeben, Lenkrad, High-Five, Umarmung, Schubser. |
| `lumos_actor_config.gd` | `LumosActorConfig` (Resource) | Knochennamen und Stellgrößen je Figurentyp. |

Die Teile sind einzeln nutzbar und dürfen fehlen: Ein Rig ohne Kopf-Mesh bekommt kein Gesicht, eines ohne Arme
keine Hand-IK. `LumosActor` prüft das und warnt, statt abzubrechen.

Das Framework verändert weder `CharacterRig` noch die Modelle. Es nutzt, was es schon gibt:
* Clips und Überblendung über `CharacterRig.play()`.
* Kopf-Blick über den `SlapstickModifier` des Spiels (`look_target`, `look_weight`).
* `LumosBody` ist ein zweiter Modifier und läuft danach.

## Schnellstart

```gdscript
var actor := LumosActor.attach(rig)              # einmalig; liefert bei erneutem Aufruf denselben Akteur
actor.move(wish_velocity, grounded, delta)       # bewegt die Figur mit Trägheit und animiert passend
actor.express("joy", 0.2, 0.7)                   # Ausdruck, Übergangszeit, Stärke
actor.laugh(1.4)                                 # Lachen als Kette aus Gesicht und Körper
actor.look_at_target(other_actor)                # Kopf und Augen, weich; null hebt den Blick auf
actor.interact.grab(item, "r")                   # hinschauen, hingreifen, halten
actor.interact.throw_to(target_position)         # ausholen, durchziehen, loslassen, Nachschwung
LumosInteract.high_five(actor_a, actor_b)
```

Wird die Figur vom Spiel selbst bewegt (`CharacterBody3D`, Streckenkoordinaten), ersetzt
`actor.animate(echte_geschwindigkeit, grounded, delta)` den Aufruf von `move()`.

## LumosActor

| Methode | Wirkung |
|---|---|
| `attach(rig, config = null)` (static) | Framework anhängen. `of(rig)` liefert einen vorhandenen Akteur oder `null`. |
| `move(wish, grounded, delta)` | Wunschgeschwindigkeit → Trägheit → Position → Animation und Körperneigung. |
| `animate(velocity, grounded, delta)` | Nur animieren, wenn das Spiel die Figur bewegt. |
| `express(name, secs, intensity)` | Gesichtsausdruck. |
| `laugh(duration, strength, then)` | Schmunzeln → Lachen → klingt aus → Ausdruck `then`. |
| `look_at_target(t)` | `Vector3`, `Node3D`, `LumosActor` (schaut ins Gesicht) oder `null`. |
| `react_hit(from_dir, strength, stumble)` | Oberkörper federt, Gesicht zuckt, optional Stolper-Clip. |
| `reach(hand, target, secs)` / `release(hand, secs)` | Hand an ein Ziel führen und halten / weich zurückgeben. Ziel: `Vector3`, `Node3D` oder `Callable`. |
| `hand_pos(hand)`, `hand_weight(hand)`, `rel(right, up, fwd)`, `forward()` | Hilfen für eigene Interaktionen. |
| `set_breath(amount, rate)` | Atmung, zum Beispiel außer Atem nach dem Rennen. |
| `time_scale` | Zeitlupe je Figur. |

Signale: `laughed`, `hit_reacted(strength)`, `hand_reached(hand)`, `hand_released(hand)`.

## LumosFace

Die Lumos-Helden haben starre Augen (kleine Kapseln im Kopf-Mesh) und keinen Mund. `setup(rig)`:
1. sucht das Kopf-Mesh (`*_Head`) und vermisst darin Augen (dunkel, bläulich) und Gesichtsfläche auf Mundhöhe,
2. versenkt die Original-Augen in einer **eigenen Kopie** des Meshs (das Modell bleibt unverändert),
3. ersetzt die Original-Brauen, wenn sie eindeutig erkennbar sind (`has_own_brows`). Sonst bleiben sie stehen und
   es werden keine eigenen gezeichnet. Doppelte Brauen gibt es in keinem Fall.

Alle Positionen kommen aus der Vermessung, nicht aus festen Werten je Modell. `setup()` gibt `false` zurück, wenn
das Rig kein Skelett, keinen Kopfknochen oder keine erkennbaren Augen hat. Dann bleibt die Figur, wie sie ist.

Ausdrücke sind Parametersätze (`LumosFace.EXPR`), zwischen denen das Gesicht gleitet:
`neutral, smile, grin, joy, laugh, awe, surprised, curious, confused, scared, worried, sad, angry, determined,
sleepy, asleep, pant, ouch, smug, dreamy, plead`.

Parameter (`KEYS`): `lid` (Oberlid), `squint` (Lachaugen), `wide`, `brow` (Höhe), `tilt` (Lid- und Brauenneigung:
positiv besorgt, negativ grimmig), `asym`, `open`, `curve`, `width`, `round`.

| Mitglied | Bedeutung |
|---|---|
| `set_expression(name, secs, intensity)` | Übergang zum Ausdruck. `intensity` mischt mit „neutral“. |
| `add_expression(name, params)` | Eigenen Ausdruck registrieren. |
| `laugh`, `laugh_phase`, `chew` | Rhythmische Mundbewegung. `LumosActor` koppelt `laugh_phase` an den Körper. |
| `gaze` | Blickrichtung der Augen (−1..1). Setzt `LumosActor` aus dem Blickziel. |
| `blink_on` | Automatischer Lidschlag. |
| `param(key)` | Aktueller Wert, für Tests. |

Signal: `expression_changed(name)`.

Stand der vier Helden: Gesicht bei allen. Bewegliche Brauen bei Magierin, Barbar und Waldläufer. Beim Ritter
liegen die Brauen unter dem Helm, dort übernehmen die schrägen Lider den Ausdruck.

## LumosBody

Additiv über der Animation, alles geglättet. Zeitbasis ist `dt` (setzt `LumosActor`), also bildratenunabhängig.

| Mitglied | Bedeutung |
|---|---|
| `hand_t[hand]`, `hand_w[hand]` | Ziel (Welt) und Gewicht der Arm-IK. Normalerweise über `LumosActor.reach()`. |
| `ground` | `Callable(Vector3) -> float`: Bodenhöhe unter einem Weltpunkt. Leer = ebener Boden. |
| `foot_w` | Fuß-IK ein- und ausblenden. `LumosActor` blendet sie in der Luft aus. |
| `lean` | Vor-/Rücklage und Seitneigung. `LumosActor` setzt sie aus Beschleunigung und Kurve. |
| `head_add`, `chest_add` | Zusätzliche Neigung für Gesten (nicken, schief legen, vorbeugen). |
| `breath`, `breath_rate`, `laugh` | Atmung und Lachen. |
| `push(world_impulse)` | Stoß: Oberkörper und Kopf schwingen gedämpft nach. |
| `joint_pos(name)` | Weltposition nach allen Modifikatoren: `hand.l/r`, `shoulder`, `elbow`, `thigh`, `knee`, `foot`, `head`, `chest`, `hips`. |

Wichtig: Godot setzt Knochen nach dem Skinning zurück. `skeleton.get_bone_global_pose()` liefert von außen die
Pose **ohne** Modifikatoren. Für Hand- und Fußpositionen deshalb immer `joint_pos()` verwenden.

IK-Details: Zwei-Knochen-Lösung mit Pol-Richtung (Ellbogen nach unten-außen-hinten, Knie nach vorn). Die
Reichweite ist auf 98,5 % (Arm) und 99,5 % (Bein) begrenzt, damit Gelenke nie durchstrecken und umschnappen. Das
Handziel wird mit 35 ms geglättet. Die Fuß-IK erhält die animierte Fußhöhe (der Schritt hebt den Fuß weiter) und
senkt das Becken, wenn ein Fuß tiefer steht.

Grenze: Die Hand wird positioniert, aber nicht gedreht. Für Griffe mit bestimmter Handhaltung fehlt eine
Handgelenk-Ausrichtung.

## LumosLocomotion

* `stride_speed(rig, clip, fallback)` vermisst je Clip das Tempo, bei dem der Standfuß am Boden stillsteht, und
  merkt es sich je Modell. Helden: Gehen 0,87 m/s, Laufen 3,14 m/s bei Skalierung 1.
* `update(velocity, grounded, delta)` wählt den Zustand und passt die Abspielgeschwindigkeit an das echte Tempo an
  (Gehen 0,45–1,9×, Laufen 0,6–1,75×). Hysterese verhindert Flackern zwischen Gehen und Laufen.
* `steer(wish, delta)` liefert die geglättete Geschwindigkeit (`cfg.accel`, `cfg.decel`).
* `play_action(name, clip, secs, blend, speed)` spielt eine einmalige Aktion mit Überblendung. Vorbelegt:
  `stumble`, `dance`, `fall_down`, `cheer`, `throw`. Danach übernimmt `update()` wieder.
* Zustände: `idle, walk, run, jump, fall, land` und Aktionsnamen. Signal: `state_changed(from, to)`.

## LumosInteract

| Methode | Ablauf |
|---|---|
| `grab(obj, hand, secs)` | Blick zum Objekt, vorbeugen, Hand hin, zugreifen, Hand in Tragehaltung. Der vorige Blick kehrt zurück. |
| `drop(hand)` | Loslassen, Hand zurück. Gibt das Objekt zurück. |
| `throw_to(target, hand, arc, flight)` | Ausholen mit Oberkörperdrehung, durchziehen, loslassen, Nachschwung. Das Objekt fliegt im Bogen. |
| `give(to, hand, to_hand)` | Beide Hände treffen sich, das Objekt wechselt den Besitzer. |
| `hold_wheel(wheel, radius)` / `release_wheel()` | Beide Hände am Kranz. Die Griffpunkte drehen sich mit dem Rad. |
| `high_five(a, b)`, `hug(a, b, hold)`, `shove(a, b, strength)` (static) | Beide drehen sich zueinander, Hände treffen sich, der Partner reagiert. |

`held[hand]` ist das gehaltene Objekt, `grip_offset[hand]` sein Versatz in der Hand.
Signale: `grabbed(obj, hand)`, `released(obj, hand)`, `thrown(obj)`, `landed(obj, pos)`, `contact(kind, other)`.

Wer echte Physik will, hört auf `thrown` und übernimmt das Objekt selbst.

## Konfiguration (`LumosActorConfig`)

Knochennamen (`bone_hips`, `bone_chest`, `bone_head`, `arm_bones`, `leg_bones`), `face_enabled`, Atmung
(`breath`, `breath_rate`), `idle_sway`, Neigung (`lean_accel`, `lean_turn`), Impuls-Feder (`impulse_stiffness`,
`impulse_damping`), Fuß-IK (`foot_ik`, `foot_ik_max`, `ankle_height`), Fortbewegung (`walk_speed`, `run_speed`
mit 0 = vermessen, `accel`, `decel`, `turn_rate`).

Die Standardwerte passen zum KayKit-Rig der Helden. Für andere Rigs genügen meist die Knochennamen.

## Testlabor

```bash
./godot --path . res://tools/charlab/CharLab.tscn
```

```bash
./godot --headless --fixed-fps 60 --path . res://tools/charlab/CharLab.tscn -- --lab-auto
```

```bash
xvfb-run -a ./godot --fixed-fps 60 --path . res://tools/charlab/CharLab.tscn -- --lab-auto=/ordner
```

```bash
xvfb-run -a ./godot --path . res://tools/charlab/CharLab.tscn -- --lab-faces=/ordner
```

Der erste Aufruf ist interaktiv, der zweite misst alles, der dritte speichert zusätzlich ein Bild je Vorführung,
der vierte Nahaufnahmen aller Gesichter je Ausdruck. Immer mit `--fixed-fps 60` messen, sonst verfälscht eine
langsame Grafik die Zeitmessungen.

Tasten: `1` Stehen/Atmen · `2` Gehen/Rennen · `3` Lachen · `4` Mimik · `5` Greifen · `6` Werfen · `7` Lenkrad ·
`8` High-Five · `9` Treffer · `0` Kombination · `U` Umarmung · `S` Schubser · `B` Bodenstufe (Fuß-IK).

Gemessen wird unter anderem: Atmung sichtbar, Füße am Boden, Anfahren mit Trägheit, Rutschen des Standfußes,
Lachen (Mund, Augen, Körper gleichzeitig), jeder Ausdruck erreicht und ohne Sprung, Hand am Gegenstand,
Wurf landet, Hände am drehenden Lenkrad, High-Five-Abstand, Umarmung, Treffer-Feder, Fuß-IK auf 20 cm Stufe,
Kombination, Rechenzeit mit 16 Akteuren.

## Integrationsbeispiele

**Nitro Dash, Hände am Lenkrad.** `KartVisual` erzeugt den Fahrer als `CharacterRig` (`visual.hero`):
```gdscript
var actor := LumosActor.attach(visual.hero)
actor.interact.hold_wheel(wheel_node, 0.2)      # wheel_node dreht sich mit dem Lenkeinschlag
actor.express("determined")
```

**Item werfen statt der bisherigen Wurf-Tweens:**
```gdscript
actor.interact.held["r"] = item_model            # liegt schon in der Hand
actor.interact.thrown.connect(func(obj): launch_projectile(obj), CONNECT_ONE_SHOT)
actor.interact.throw_to(aim_point)
```

**Minispiel, Treffer und Jubel:**
```gdscript
actor.react_hit(attacker.global_position.direction_to(victim.global_position), 1.0, true)
winner_actor.laugh(1.6); winner_actor.look_at_target(loser_actor)
```

**Brettspiel, Figuren reagieren aufeinander:** `LumosInteract.high_five(a, b)` nach einem Team-Sieg,
`actor.look_at_target(star_node)` vor dem Sternkauf.

## Bekannte Grenzen

* Standfuß rutscht im Labor noch im Schnitt 0,2 m/s beim Gehen (0,67 m/s) und 0,6 m/s beim Laufen (2,2 m/s), gemessen auf einer Kreisbahn. Deutlich
  besser als ohne Synchronisierung, aber kein vollständiges Fuß-Verankern.
* Keine Handdrehung in der IK, keine Finger.
* Gesichtserkennung ist auf die KayKit-Helden abgestimmt. Andere Modelle (Kenney-Figuren, Haustiere, eigene
  Avatare) sind nicht geprüft. Dort liefert `LumosFace.setup()` voraussichtlich `false`.
* Fuß-IK braucht eine Bodenhöhen-Funktion vom Spiel. Eine Abfrage per Raycast ist nicht eingebaut.
* Gehaltene Objekte folgen der Hand ohne Kollision.
