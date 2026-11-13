# Character Animation, Emotion & Interaction Framework

Universelles Mehrschicht-System für lebendige Figuren: Gefühlszustand, Mikroleben, Körpergewicht, soziale
Wahrnehmung, Interaktionsprotokoll, Persönlichkeit und Cartoon-Reaktionen – aufbauend auf Mimik, IK mit Handdrehung,
Fußverankerung und Fortbewegung (1.5.0/1.5.1). Code in `scripts/actor/`, Testlabor in `tools/charlab/`.

**Stand 1.5.2 (Finalisierung):** implementiert, im Character Behavior Laboratory geprüft (98 Prüfungen, Werte
unten), im Performance-Labor je Teilsystem gemessen und optimiert, im Trailer im Einsatz – dort ohne Durchdringung
(Prüfprogramm, kleinster Abstand fester Körperteile im ganzen Trailer +23 mm).
**Nicht** in Spielabläufe eingebaut: Brett, Minispiele und Nitro Dash laufen unverändert ohne Framework. Rückfall:
1.5.1 (Commit `76e50fce`) und 1.5.0 im Git-Verlauf; Original-Renders bleiben aufbewahrt. Schnittstellen-Version:
`LumosActorConfig.API_VERSION = 2`, Profil-Schema `SCHEMA = 2`.

Keine AAA-Behauptung: Die Zahlen belegen Funktion und Messwerte. Ob Bewegungen natürlich *wirken*, zeigen die
Kontrollbilder (Sichtprüfung) – und dort gibt es noch Grenzen (siehe unten).

## Architektur

Ebenen je Bild, von unten nach oben – jede wirkt auf die darunter, nichts ersetzt hart:

| # | Ebene | Baustein |
|---|---|---|
| 1 | Basisbewegung (Clip des Spiels) | `CharacterRig` (unverändert) |
| 2 | Lokomotion: Tempo, Schritt-Sync, Trägheit | `LumosLocomotion` |
| 3 | Körpergewicht & Balance: Schwerpunkt-Federn, Stand-/Spielbein, Becken, Landung, Last, Stolpern | `LumosBody` |
| 4 | Haltung: Gefühl + Persönlichkeit | `LumosEmotion` → `LumosBody` |
| 5 | Kopf & Blick: Augen springen zuerst, Kopf folgt, Oberkörper dreht mit | `LumosActor`, `LumosMicro` |
| 6 | Gesicht & Gefühl: gemischte Gefühle, Lidschlag, Mund (Sprechen, Seufzen …) | `LumosEmotion` → `LumosFace` |
| 7 | Arme & Hände: Gesten, Hand-IK mit Handdrehung, Reach-Assist | `LumosMicro`, `LumosBody` |
| 8 | Interaktionen: Protokoll mit Phasen | `LumosInteraction` |
| 9 | Sekundärbewegung: Kopf/Arme schwingen nach, Hut/Umhang/Köcher federn | `LumosBody` |
| 10 | Cartoon-Reaktionen | `LumosCartoon` |
| 11 | Effekte (Tränen, Herzen, Sterne …) | `LumosCartoon` |

Konflikte regelt `LumosLayers` (Kanäle + Prioritäten). Wer entscheidet, *was* eine Figur tut: Regie/Spiel
(direkte Aufrufe) → Interaktionen → `LumosMind` (soziale Reaktionen) → `LumosMicro` (Leerlauf).

| Datei | Klasse | Aufgabe |
|---|---|---|
| `lumos_actor.gd` | `LumosActor` (Node) | Fassade; verbindet alle Teile je Bild; Regie-Eingänge; LOD. |
| `lumos_personality.gd` | `LumosPersonality` (Resource) | Zehn Charakterzüge, Vorlagen, abgeleitete Werte. |
| `lumos_emotion.gd` | `LumosEmotion` (RefCounted) | Dynamischer Gefühlszustand → Gesicht, Haltung, Verhaltens-Hinweise. |
| `lumos_layers.gd` | `LumosLayers` (RefCounted) | Kanäle, Prioritäten, kontrolliertes Verdrängen. |
| `lumos_micro.gd` | `LumosMicro` (RefCounted) | Mikroleben (Blicke, Gewichtswechsel, Kopf) und Gesten-Engine (31 Gesten). |
| `lumos_social.gd` | `LumosSocial` (Node, je Szene) | Wahrnehmung, Ereignisse, Beziehungen, Interaktions-Takt. |
| `lumos_mind.gd` | `LumosMind` (RefCounted) | Soziale Reaktionen: versetzt, individuell, nach Persönlichkeit. |
| `lumos_interaction.gd` | `LumosInteraction` (RefCounted) | Interaktionsprotokoll (13 Arten). |
| `lumos_cartoon.gd` | `LumosCartoon` (RefCounted, statisch) | 26 Cartoon-Reaktionen mit Effekten. |
| `lumos_face.gd` | `LumosFace` (Node3D) | Gesichtsebene (Augen, Pupillen, Lider, Brauen, Wangen, Tränen, Mund). |
| `lumos_body.gd` | `LumosBody` (SkeletonModifier3D) | IK, Fußanker, Gewicht, Sekundärbewegung, Zubehör-Federn. |
| `lumos_locomotion.gd` / `lumos_interact.gd` | – | Fortbewegung · Greifen, Tragen, Werfen, Lenkrad (+ Kurzformen fürs Protokoll). |
| `lumos_actor_config.gd` | `LumosActorConfig` (Resource) | Adapter: Profil, Knochen, Merkmale, Verhalten, Migration. |
| `lumos_prof.gd` | `LumosProf` (statisch) | Messpunkte je Teilsystem fürs Performance-Labor; im Normalbetrieb aus (kostet dann eine Abfrage). |

## Schnellstart

```gdscript
var actor := LumosActor.attach(rig)            # Profil, Merkmale und Persönlichkeit aus dem Modell
actor.move(wish_velocity, grounded, delta)     # Fortbewegung mit Gewicht und Trägheit
actor.feel("joy")                              # Stimmung (hält) – Gesicht, Haltung, Blickstil, Lidschlag, Atmung
actor.react("surprise", 0.9)                   # Reaktion (steigt an, hält, klingt ab, Nachwirkung „curious“)
actor.laugh(1.4)                               # Freunde in der Nähe lachen ggf. versetzt mit
actor.cartoon("cry", 0.9)                      # Tränenfontänen; ein freundlicher Freund kommt trösten
actor.interact_with("handshake", other)        # Protokoll mit Phasen, null = abgelehnt (jemand ist beschäftigt)
actor.say(1.5)                                 # Lippen bewegen sich, Zuhörer schauen her und nicken
actor.gesture("scratch")                       # Geste aus der Engine
```

## Schnittstellen

### LumosActor (Ergänzungen 1.5.2; alle 1.5.1-Aufrufe gelten weiter)

| Mitglied | Wirkung |
|---|---|
| `feel(name, secs, intensity)` / `express` | Stimmung setzen (bleibt bis zur nächsten). |
| `react(name, intensity, hold, source)` | Gefühlsreaktion mit Hüllkurve und Nachwirkung. |
| `cartoon(id, intensity, opts)` | Cartoon-Reaktion (siehe unten). |
| `interact_with(kind, other, opts)` | Interaktion starten. |
| `gesture(id, opts)` / `say(secs, intensity)` / `emit_social(kind, data)` | Geste · Sprechen · Ereignis aussenden. |
| `look_at_target(t)` · `look_social(t, secs)` · `look_focus()` | Blickziel · kurzes Hinschauen · auf wen schaut die Figur. |
| `jump(height)` · `land(strength)` · `stumble(dir, strength)` | Sprung mit Ausholen und gewichtiger Landung · Landung · Gleichgewicht verlieren. |
| `fall(dir, strength)` · `get_up(speed)` · `fallen` · `is_rising()` | Hinfallen (Stolpern, Arme rudern, auf den Hosenboden), sitzen bleiben, aufstehen – allein nach eigener Geduld oder mit Hilfe (`help_up`). |
| `volumes()` · `clearance(a, b)` · `clearance_dir` · `clearance_bound` · `fit_distance(a, b, dir, …)` | Feste Körperteile als Ellipsoide · kleinster Abstand zweier Figuren · Richtung · billige untere Schranke · passender Abstand für eine Aufstellung. |
| `reach(hand, target, secs, orient, assist, owner)` · `release(hand, secs, owner)` | Hand führen; mit `owner` löst nur der eigene Besitzer. |
| `script_look(pos, w)` · `script_hand(hand, w, pos, orient, assist)` · `script_laugh(level)` | Regie-Eingänge je Bild (höchste Schicht). |
| `set_breath(amount, rate)` | Atmung fest vorgeben; `amount < 0` gibt sie an das Gefühl zurück. |
| `personality`, `emotion`, `layers`, `micro`, `mind`, `social`, `rng`, `scripted` | Teile; `scripted` = Regie bewegt die Figur. |
| `capabilities()` | profile, face, brows, arms, hand_orient, legs, foot_lock, posture, jiggle, pet_parts, api. |

### LumosEmotion

`set_mood(id, i, secs)`, `trigger(id, i, hold, attack, release, source)`, `clear(id)`, `intensity_of(id)`,
`dominant()`, `strongest_reaction()`, `active()`; Ausgaben je Bild: `face_out`, `posture_out`, `mods`
(`blink`, `gaze`, `gest`, `breath`, `mouth`, `valence`, `arousal`, `cartoon`). Mischung: gewichteter Mittelwert
der nach Stärke skalierten Ausschläge (Reaktionen wiegen 1,6-fach gegen die Stimmung, „neutral“ verdünnt nichts);
Röte, Tränen, Zittern, Backen, Lederhaut, Schielen: das stärkste Gefühl gewinnt. Signale `changed`, `triggered`.

### Weitere

* `LumosPersonality`: `preset(name)`, `reaction_delay(rng)`, `intensity_scale()`, `expressiveness()`,
  `gesture_scale()`, `eye_contact_time(rng)`, `avert_chance()`, `cartoon_bias()`, `contagion()`, `fidget_rate()`, `posture()`.
* `LumosLayers`: `claim(owner, channels, prio, on_preempt)`, `can_claim`, `release(owner)`, `owner_of`, `prio_of`,
  `is_free`, `owners()`, `stats`.
* `LumosMicro`: `play(id, opts)` (side, target, dur, prio, owner, reach), `stop()`, `gesture`, `look_target`, `stats`.
* `LumosSocial`: `of(node)`, `emit(kind, src, data)`, `perceive(actor)`, `relation/set_relation`, `add_poi`,
  `comforter_for`, `helper_for`/`claim_help` (genau ein Helfer je Sturz), `interaction_of`, `roots()` (Wurzeln aller
  Figuren, einmal je Bild), Signal `event`, `log`.
* `LumosMind`: `hear(ev, dist)`, `reactions` (Protokoll: Zeit, Ereignis, Reaktion, Verzögerung).
* `LumosInteraction`: `start(kind, a, b, opts)`, `cancel()`, `phase`, `phases_done`, `times`, `done`, `ok`;
  Signale `phase_changed`, `finished(ok)`.
* `LumosCartoon`: `react(actor, id, intensity, opts)`, `stop(actor, id)`, `running(actor)`, `available()`.
* `LumosFace` (neu): Parameter `pout, press, tremble, cheek, sclera, pupil, tear, smirk, cross`; `set_params`,
  `mouth_action(id)` (yawn, sigh, swallow, gasp, sob, snicker, smack, chatter, pant, press), `talk`, `gaze_target`,
  `blink_mult`, `blink_slow`, `saccade()`, `blinks`.
* `LumosBody` (neu): `weight_shift`, `crouch`, `load`, `hop_lift`, `micro_head`, `micro_chest`, `tremble`,
  `hat_avoid`, `avoid` (Ausweichen naher Körper), `phase` (Startphase der Eigenbewegung), `traits`; `land()`,
  `stumble()`, `set_posture_vec()`, `dynamics_state()`, `jiggle_state()`, `hat_radius()`, `bone_xform(bone)`
  (Knochenlage nach der Modifikation), statisch `spring()`.

## Gefühle

36 geforderte Gefühle, jedes mit eigenem Gesicht (`LumosFace.EXPR`), eigener Haltung (`LumosBody.POSTURE`) und
eigenem Verhalten (`LumosEmotion.META`: Valenz, Erregung, Blickstil, Lidschlag, bevorzugte Gesten, Atmung,
Mundaktion, Nachwirkung, Cartoon bei Höhepunkt) – dazu die 21 Ausdrücke aus 1.5.x und Cartoon-Gesichter
(`cry, love, puppy, sulk, puffed, dizzy, cross_eyed, sleep_smile`).

| positiv | negativ | sozial / situativ |
|---|---|---|
| Freude `joy` · Begeisterung `delight` · Euphorie `euphoria` · Stolz `pride` · Erleichterung `relief` · Zufriedenheit `content` · Zuneigung `affection` · liebevolle Freundlichkeit `tender` · Neugier `curious` · Verspieltheit `playful` · Schadenfreude `gloat` · Verlegenheit (positiv) `bashful` | Traurigkeit `sad` · Enttäuschung `disappointed` · Angst `fear` · Panik `panic` · Wut `anger` · Frustration `frustrated` · Eifersucht `jealous` · Scham `shame` · Verwirrung `confused` · Unsicherheit `insecure` · Einsamkeit `lonely` · Erschöpfung `exhausted` | Überraschung `surprise` · Ungläubigkeit `disbelief` · Misstrauen `suspicious` · Verlegenheit `embarrassed` · Nervosität `nervous` · Mitgefühl `compassion` · Bewunderung `admiration` · Trotz `defiant` · Ungeduld `impatient` · Konzentration `focus` · Nachdenklichkeit `pensive` · spielerische Provokation `teasing` |

Beispiele für Nachwirkungen: Lachen → Zufriedenheit, Schreck → Nervosität, Weinen → Traurigkeit, Begeisterung →
Freude, Wut → Frustration. Persönlichkeit wirkt auf Stärke (Gefühlsbetonung), Anstieg (Impulsivität), Haltezeit und
Ausdrucksstärke (ruhige/schüchterne Figuren zeigen subtiler).

## Cartoon-Reaktionen

`cry` (Tränenfontänen seitlich aus beiden Augen, Kopf nach hinten, Arme hoch, danach vornübergebeugt schluchzen,
Tropfen) · `big_surprise` (riesige Augen, winzige Pupillen, O-Mund, Erstarren, Hüpfer) · `jaw_drop` · `freeze` ·
`jump_back` (Rückwärtssprung, andere schauen hin) · `almost_fall` (Arme rudern, Ausfallschritt) · `dizzy` (Sterne,
Kopf kreist) · `love` (Herzen, Hände gefaltet, wiegen) · `blush_shy` · `face_in_hands` · `laugh_fit` (in die Knie,
Bauch/Knie klatschen, Lachtränen, danach wegwischen) · `wipe_tears` · `puff_cheeks` (Backen aufblasen, Dampf) ·
`stomp` · `sulk` (Arme verschränkt, demonstrativ weg) · `look_away` · `joy_hop` · `spin_joy` · `head_shake` ·
`hide_behind` (hinter einem Freund verstecken, hervorlugen) · `shiver` (Zähneklappern) · `sweat` · `proud_pose`
(Hände in die Hüften, Funkeln) · `facepalm` · `puppy` (Bettelblick) · `shrug`.

Stärke 0..1 (× `cfg.cartoon`), Abklingzeit je Reaktion, Budget 3 in 10 s je Figur. Automatisch nur aus einem
anhaltenden Höhepunkt einer *Reaktion* (nie aus einer gesetzten Stimmung), mit Zufall je Persönlichkeit, nie in
Interaktionen, erst ab Autonomie 0,6. Effekte sitzen seitlich bzw. über dem Kopf und blenden beim Abbruch weich aus.

## Mikroleben

* Blick: Ziele nach Auffälligkeit (wer schaut mich an, spricht, lacht, kommt näher; interessante Dinge; Umgebung),
  Blickstil je Gefühl (unten, oben/nachdenken, umherschauen, ausweichen, Seitenblick). **Augen führen** (Sakkade
  ~40 ms), der Kopf folgt verzögert und nur zu ~80 %, der Oberkörper dreht mit. Blickkontakt: Brauen heben,
  freundlich lächeln, halten je Persönlichkeit, Schüchterne weichen nach unten/zur Seite aus.
* Lidschlag: log-normal verteilt um ~3,4 s, Dauer 0,11–0,2 s, 14 % Doppelblinzeln, Blinzeln bei großen Blicksprüngen,
  Häufigkeit und Dauer je Gefühl (nervös ×2, konzentriert ×0,4, müde langsamer).
* Mund: Sprechen silbenweise (Öffnung, Rundung, Breite, Pausen), Seufzen, Gähnen, Schlucken, Keuchen, Schmollen,
  Lippenpressen, Zittern der Unterlippe, Kauen, schiefes Grinsen, Weinen.
* Körper: Stand-/Spielbeinwechsel alle 3–8 s, kleine Kopfneigungen, Gesten passend zu Gefühl und Persönlichkeit
  (Kopf kratzen, Gesicht/Kinn berühren, Kleidung richten, Hände in die Hüften, Arme verschränken, Hände reiben,
  Strecken, sich selbst umarmen, Stirn wischen …), Ausweichen im persönlichen Raum. Gesten haben eigenes Tempo
  (Strecken 0,9 s, Jubel 0,3 s) und lösen weich (Ziel und Handhaltung bleiben beim Lösen stehen).

## Gewicht, Balance, Sekundärbewegung

Federn (halbimplizit, mit Unterschritten – stabil auch bei 10 fps) aus der tatsächlichen Wurzelbewegung:
Oberkörper kippt beim Bremsen nach vorn und beim Anfahren zurück, Kopf schwingt verzögert nach, Arme pendeln, bei
Drehungen führt der Kopf und die Brust folgt verzögert. Kontrapost: Becken wandert aufs Standbein, Hüfte sinkt auf
der Spielbeinseite, Schultern kippen gegen, die Füße bleiben verankert. Becken-Feder für Landung, Hocke und Last;
schwere Last lehnt zurück. Stolpern: Ausfallschritt, Arme rudern, Erholen. Masse, Beweglichkeit und Bewegungsstil
(`mass`, `agility`, `bounce`) bestimmen Frequenz und Ausschlag.

Zubehör: Hüte, Helme, Umhänge, Köcher bekommen zur Laufzeit je einen eigenen Knochen; ihre Haut wird auf diesen
Knochen umgebunden (Kopie der Skin-Ressource – Modelldateien bleiben unverändert). Hüte wippen gegen die
Beschleunigung und weichen mit der Krempe aus, wenn ein Kopf nahe kommt; Umhänge heben sich mit dem Tempo.

## Persönlichkeit

Züge (0..1): energy, playfulness, confidence, shyness, friendliness, curiosity, impulsivity, emotionality, humor,
sociability. Vorlagen: `balanced, brave, curious, boisterous, dreamy, shy, calm, pet`. Wirkung: Blickkontakt-Dauer,
Ausweichen, Reaktionszeit, Gefühlsstärke, Ausdrucksstärke, Gestenhäufigkeit und -größe, Grundhaltung (selbstbewusst
aufrecht, schüchtern kleiner), Ansteckung beim Lachen, Cartoon-Neigung. Zuordnung je Modell als Daten
(`LumosActorConfig.MODEL_TRAITS`), keine Sonderlösungen im Code.

## Sozialverhalten

`LumosSocial` (ein Knoten je Szene) verteilt Ereignisse: hörbare (laugh, cry, fright, scream, talk, joke, cheer,
hit, win, lose, boo) an alle im Umkreis, sichtbare nur an die, die ungefähr hinschauen. Wahrnehmung je Bild einmal
berechnet und geteilt. `LumosMind` reagiert zeitversetzt (Reaktionszeit je Persönlichkeit, mit Streuung, mit
Entfernung) und individuell: Mitlachen (Ansteckung nach Humor/Beziehung), trösten gehen, zur Schreck-Quelle
schauen, zurückwinken, auf Witze lachen/schmunzeln/ungläubig den Kopf schütteln, Sieg/Niederlage (Freude,
Bewunderung, gespielte Enttäuschung, Schadenfreude), mittanzen, dem Zeigen folgen, zuhören (hinschauen, nicken).

Autonomie (`cfg.autonomy`): ≥ 0,2 hinschauen · ≥ 0,35 Gesicht reagiert · ≥ 0,6 Gesten, Mitlachen mit dem Körper,
Cartoon · ≥ 0,75 Handlungen mit Ortswechsel (trösten, mittanzen). Spätere Sprache/Dialoge: `say()` + Ereignis „talk“.

## Interaktionsprotokoll

Phasen `approach → contact → main → response → after → end`, Abbruch jederzeit sauber (`cancel`, Verdrängung,
Teilnehmer verschwindet). Beide Teilnehmer belegen `root, legs, torso, head, eyes, arm.l, arm.r` mit P_INTERACT.
Kontaktpunkte aus der echten Reichweite; Ziele am eigenen Körper aus der Ruhepose (keine Rückkopplung mit dem Lehnen).

Arten (14): `high_five`, `handshake`, `hug`, `pat`, `comfort`, `take_hand`, `give`, `tease`, `cheer_together`,
`dance_together`, `playful_shove`, `scare`, `shared_laugh`, `help_up`. Figuren ohne zweiteilige Arme bekommen eine
Körper-Variante (Stups mit Reaktion). `LumosInteract.high_five/hug/shove/pat/give` sind Kurzformen.

Aufstellung aus der Geometrie statt fester Abstände: `fit_distance` setzt die Ruhe-Volumen beider Figuren gedanklich
an den Zielort und sucht den kleinsten Abstand mit Luft; Trösten und Aufhelfen suchen einen freien Platz neben der
Figur (`_solve_beside`/`_solve_spot`), gehen *um* sie herum statt hindurch und drehen sich erst dort zu ihr.
Chibi-Proportionen (Kopfradius ≈ 0,55 m, Arm ≈ 0,5 m) erzwingen zwei Formen: **Umarmung seitlich** (gemeinsame
Blickrichtung, Schulter an Schulter, innerer Arm um die Schulter – von vorn stecken die Köpfe ineinander; beim
Loslassen ein kleiner Schritt auseinander) und **Trösten mit der Hand am Oberarm** (die Schulter liegt unter dem
großen Kopf). Aufhelfen: Hand reichen, greifen (Griffpunkt zwischen beiden Händen), hochziehen, stützen, loslassen.

## Körpervolumen und Durchdringungsschutz

Feste Körperteile sind Ellipsoide in den eigenen Achsen der Meshes (eng anliegend), gebunden an Kopf- bzw.
Brustknochen: Kopf samt Helm, Visier-Rahmen und Kapuze, Rumpf. Breite Hutkrempen zählen nicht (eigene Ausweich-Feder
`hat_avoid`). `volumes()` nutzt die Knochenlage *nach* der Skelett-Modifikation (`bone_xform`) und wird je Bild
einmal berechnet. `clearance(a, b)` = Mittenabstand minus beider Radien entlang der Verbindung (≈ 1–3 cm genau).

Ausweichen (`_keep_apart`, jede Figur, jedes Bild): unterschreitet ein Paar `AVOID_MARGIN` (3 cm), neigen sich Kopf
(voll) und Oberkörper (60 %) vom engsten Teil weg, höchstens ~26°, mit Luft langsam zurück. **Vorausschauend:**
schließt sich der Abstand schnell (Auflaufen, Abbremsen mit Schwung, Drehen), zählt der für `AVOID_LOOKAHEAD` =
0,1 s vorausberechnete Abstand – der Kopf weicht schon vor der Berührung aus. Eine billige untere Schranke über
Hüllkugeln (`clearance_bound`) überspringt die genaue Rechnung, wenn sie ohnehin „frei“ ergäbe (gleiches Ergebnis).

Geprüft: B26 (alle 14 Interaktionen × 2 Paare, Toleranz −30 mm) und im Trailer `trailer/ClearanceProbe.tscn` (alle
Paare, jedes Bild). Kosten: `actor.apart` 0,52 ms bei 16 Figuren im dichten Gedränge (≈ 32 µs je Figur).

## Stürze, Aufhelfen und Stresstests

`fall()` → Stolpern mit rudernden Armen, Sitzen am Boden (Ereignis „fall“, hörbar). Wer wie reagiert, entsteht aus
der Persönlichkeit, nicht aus einer Choreografie: Erschrecken (unsicher, schüchtern), Lachen (Humor, Verspieltheit),
Helfen (freundlich, selbstsicher – genau einer, `claim_help`), mit Streuung der Reaktionszeiten. Die Gestürzte ärgert
oder schämt sich (`on_fell`: frustriert bei Selbstvertrauen/Impulsivität, sonst verlegen) und lacht mit Humor später
selbst darüber; Auslachen bringt einen bösen Blick. Ohne Helfer steht sie nach ihrer Geduld allein auf.

| Test | Ergebnis (headless, `--fixed-fps 60`) |
|---|---|
| B21 Stolper-Szenario (4 Figuren, 2 Varianten) | 2 erschrecken, 1 lacht, genau 1 hilft (Ritter); Gestürzte ärgert sich (0,8 s), lacht selbst (3,3 s); Auslachen → böser Blick; 16 zeitversetzte Reaktionen auf ihr Lachen; Hände beim Hochziehen 3 mm; Reaktionszeiten streuen 0,24 s; danach ruhig. Variante „Spaßvogel“: niemand lacht ihn aus, er lacht früher (2,4 s) |
| B22 Unterbrechungen | Reflex verdrängt das Aufhelfen mitten im Griff sauber (Hände frei, sie sitzt weiter); ohne Hilfe steht sie allein auf; Regie beendet eine Umarmung für beide ohne Reste |
| B23 Konkurrenz | 3 gleichzeitige Anfragen: eine beginnt, die anderen nacheinander, nie zwei zugleich; von dreien angesprochen: schaut 2 an, kein Hin und Her, winkt einmal |
| B24 Wiederholung | 30 Witze in 3 s: 4 Lacher (Abklingzeit), 0 weitergegebene Lacher – keine Kettenreaktion, danach Ruhe |
| B25 zwei Stürze zugleich | 1 Helfer, keiner hilft zweien, beide stehen wieder |
| B26 Durchdringung | 28 Interaktionen, kleinster Abstand −17 mm (Umarmung Barbar/Waldläuferin, Kontaktphase), sonst ≥ +31 mm |

## Schichten und Prioritäten

| Priorität | Wer | Beispiel |
|---|---|---|
| 0 / 10 | Leerlauf / Mikrogesten | Kopf kratzen, Blicke |
| 20 | soziale Reaktion | zurückwinken, nicken |
| 30 | Cartoon | Weinen, Herzen |
| 35 | ausdrückliches `reach()` des Spiels | Tragen, Greifen |
| 40 | Interaktion | Umarmung, Übergabe |
| 50 | Regie | Trailer-Hände, -Blick |
| 60 | Reflex | Schreck-Sprung |

Höher verdrängt niedriger (Rückruf → sauberes Ende), gleich oder niedriger wird abgelehnt. Ein Besitzer belegt
alle Kanäle seiner Handlung auf einmal.

## Adapter und Profile

| Profil | Erkennung | Gesicht | Arme | Beine | Gewicht/Haltung | Geprüft |
|---|---|---|---|---|---|---|
| `humanoid` | zweiteilige Arme und Beine | ja | IK + Handdrehung | Fußanker | Knochen, Zubehör-Federn | 4 KayKit-Helden |
| `simple` | einteilige Gliedmaßen | nein | zielen | – | Knochen | Kenney `mini/male_a`, `mini/robot` |
| `rigid` | kein Skelett | nein | – | Beine-Einzelteile schwingen | ganzer Körper, Schwanz wedelt | `pet/cat` (Schwanz), `pet/dog` (ohne Schwanz-Teil) |

Fehlt eine Fähigkeit, wählt das System eine Alternative: kein Skelett → Ganzkörper-Bewegung; keine Finger →
Handhaltung über das Handgelenk; keine Gesichtsknochen → Gesichtsebene; keine erkennbaren Augen → Effekte am
geschätzten Kopf; kein Zubehör → keine Zubehör-Federn.

## Versionierung und Migration

`API_VERSION = 2`, `SCHEMA = 2`. `LumosActorConfig.migrate(cfg)` hebt ältere Profile an (fehlende Felder →
Standardwerte, vorhandene Werte bleiben) und wird in `attach()` immer aufgerufen.

Migrationsanleitung 1.5.1 → 1.5.2:
1. `feel()` setzt jetzt eine **Stimmung** im Gefühlszustand (wirkt bis zur nächsten); für kurze Gefühle `react()`.
2. Wer `face.set_expression()` direkt aufrief, während ein `LumosActor` läuft, nutzt `actor.feel()` – das Gesicht
   folgt jetzt dem Gefühlszustand.
3. Wer `body.hand_t/hand_w` oder den Blick-Modifier direkt setzte (Regie), nutzt `script_hand()` / `script_look()`.
4. `reach()` ohne `owner` belegt den Arm-Kanal mit P_API; eigene Systeme übergeben einen `owner`.
5. Eigene Interaktionen über `LumosInteraction.start()`; die alten statischen Aufrufe bleiben als Kurzform.
6. Für reine Regie-Szenen: `cfg.autonomy` senken (0,35 = Mikroleben + dezente Reaktionen) und `actor.scripted = true`.

## Character Behavior Laboratory

```bash
./godot --headless --fixed-fps 60 --path . res://tools/charlab/CharLab.tscn -- --lab-auto
```

```bash
./godot --headless --fixed-fps 60 --path . res://tools/charlab/CharLab.tscn -- --lab-behavior
```

```bash
xvfb-run -a ./godot --path . --fixed-fps 60 res://tools/charlab/CharLab.tscn -- --lab-behavior=/ordner
```

Erster Aufruf: alle Prüfungen (CI, Ergebnis `CHARLAB OK`). Zweiter: nur die Verhaltensbereiche (einzelne mit
`--lab-only=21,26`). Dritter: dazu Kontrollbilder für die Sichtprüfung (`b02_cartoon_*`, `b04_gruppe_*`,
`b08_landung`, `b15_troesten`, `b16_gleichzeitig`). Fehlersuche B26: `LUMOS_DBG_B26=hug` gibt den kleinsten Abstand
je Phase der gewählten Interaktion aus.

Messwerte 1.5.2 (headless, CPU):

| Bereich | Ergebnis |
|---|---|
| B1 Gefühle | 36/36 vorhanden; nächstes Paar Enttäuschung/Einsamkeit Abstand 0,43; Lachen steigt (0,97), klingt ab, Nachwirkung Zufriedenheit 0,58; Freude + Verlegenheit gleichzeitig sichtbar; lebhaft vs. ruhig 0,92 vs. 0,44 |
| B2 Cartoon | alle 26 Reaktionen auf Held, Kenney-Figur und Haustier; Fontänen 43 → 60 Tropfen, seitlich; danach aufgeräumt; Abklingzeit und Budget greifen |
| B3 Augen | Augen 0,07 s vor dem Kopf (0,42 s); Lidschlag-Streuung 113 %; nervös 11, konzentriert 4 Lidschläge in 21 s |
| B4 Mikroleben | je Figur ≥ 8 Blicke in 14 s, 11× Blickkontakt, Gewichtswechsel, 7 Gesten; größte Bewegungsänderung je Bild 39 mm |
| B5 Atmung | erschöpft 0,97/2,5 · zufrieden 0,35/1,4 (Stärke/Takt) |
| B6 Balance | Bremsen: 0,14 rad vor, gefangen nach 0,58 s; Standbein 29 mm Becken, Füße 6 mm; Last 35 mm zurück, 33 mm tiefer; Stolpern erholt |
| B7 Drehen | Drehrate 7,9 rad/s, Brust hängt 0,28 rad nach, Kopf führt |
| B8 Landen | schwer (Barbar, Masse 1,4) federt 34 mm ein, leicht (Magierin, 0,85) 16 mm; beide stehen danach ruhig, Füße am Platz |
| B9–B12 | Greifen 0 mm/0°, Lenkrad 3 mm, High-Five 63 mm (Köpfe 1,09 m), seitliche Umarmung (Schultern 581 mm, Hand 89 mm), Schulterklopfen (CharLab 7–12) |
| B13 Übergabe | Hände treffen sich (59 mm), Besitzwechsel, Phasen vollständig |
| B14 Mitlachen | 2 von 3 lachen versetzt mit (kleinster Abstand 0,17 s), die Schüchterne lächelt nur |
| B15 Trösten | Freund geht von selbst hin, Hand am Oberarm (60 mm), Weinen → Erleichterung 0,94 |
| B16 gleichzeitig | High-Five + Handschlag + Umarmung parallel ohne Konflikt; Vorrang und Ablehnung korrekt |
| B17 Persönlichkeit | Blickkontakt 0,58 s (schüchtern) vs. 2,59 s; Reaktionszeit 0,23 s (impulsiv) vs. 0,59 s; Ausweichen 5:0; Lächeln 1,07 vs. 0,87 |
| B18 Modelltypen | Held ↔ Kenney (High-Five als Stups), Held tätschelt Haustier, Haustier ↔ Kenney jubeln |
| B19 Haustiere | Schwanz wedelt 1,17 rad, eingezogen 0,49 rad bei Angst, Beine 0,90 rad, reagiert auf Lachen |
| B20 Ressourcen | 0 Knoten Rest nach allen Verhaltenstests |
| B21–B26 | siehe „Stürze, Aufhelfen und Stresstests“ |

## Leistung

Gemessen mit dem Performance-Labor (CPU, headless, ohne Grafik; Intel Xeon 2,3 GHz, 4 Kerne, Cloud-VM):

```bash
./godot --headless --fixed-fps 60 --path . res://tools/charlab/PerfLab.tscn -- --perf=/ordner --perf-repeat=2
```

Szenarien je 1/4/8/16 Figuren: 0A/0B ohne Framework (nur Spiel-Animation) · A Stehen mit Mikroleben · B alle bewegen
sich · C Paare interagieren · D Gefühlsreaktionen mit sozialer Ansteckung · E Cartoon-Effekte gleichzeitig
(erzwungen, ohne Budget) · F alles zugleich (realistisch) · G1 wie F außerhalb des Bildes · G2 wie F, 50 m entfernt.
Je Lauf 240 Bilder ohne und 240 mit Messpunkten; Kennwerte Mittel, p95, p99, Spitze. **„Bild“** = Abstand zweier
Bilder (Godots gesamter Prozess-Schritt: alle `_process`, Tweens, Partikel, Skelette – ohne Rendern),
**„Framework“** = Summe der Messabschnitte (`LumosProf`) der Figurenverarbeitung. Vorher = Commit `d9cccd8a` mit
denselben Messpunkten; nachher = Endstand, Mittel aus zwei Läufen (Streuung je Lauf bis ±15 % auf der Cloud-VM).

16 Figuren (ms):

| Szenario | Bild Ø vorher → nachher | p95 nachher | p99 nachher | Spitze nachher | Framework Ø vorher → nachher | je Figur |
|---|---|---|---|---|---|---|
| A Stehen, Mikroleben | 7,16 → 3,74 (−48 %) | 4,91 | 5,55 | 7,29 | 7,37 → 3,66 (−50 %) | 0,23 |
| B Bewegung | 7,80 → 5,13 (−34 %) | 7,29 | 9,04 | 11,55 | 7,13 → 4,17 (−42 %) | 0,26 |
| C Interaktionen | 10,63 → 6,34 (−40 %) | 7,87 | 10,00 | 12,44 | 9,73 → 5,53 (−43 %) | 0,35 |
| D Gefühle, Ansteckung | 12,12 → 7,95 (−34 %) | 9,99 | 11,60 | 16,89 | 11,58 → 7,86 (−32 %) | 0,49 |
| E Cartoon (Worst Case) | 12,31 → 7,40 (−40 %) | 9,38 | 10,59 | 11,97 | 11,47 → 6,42 (−44 %) | 0,40 |
| F alles zugleich | 11,24 → 7,43 (−34 %) | 9,02 | 10,27 | 12,28 | 10,26 → 7,44 (−28 %) | 0,47 |
| G1 außerhalb des Bildes | 3,28 → 1,73 (−47 %) | 2,07 | 2,37 | 2,64 | 2,02 → 1,10 (−46 %) | 0,07 |
| G2 weit entfernt | 5,84 → 3,95 (−32 %) | 5,37 | 6,87 | 9,31 | 5,56 → 3,61 (−35 %) | 0,23 |
| 0A/0B ohne Framework | 0,28/0,42 → 0,26/0,38 | – | – | – | – | – |

Skalierung F (realistisch), Bild Ø: 1 Figur 0,84 → 0,53 · 4 Figuren 2,81 → 1,83 · 8 Figuren 5,39 → 3,70 ·
16 Figuren 11,24 → 7,43 ms – annähernd linear (≈ 0,45 ms je Figur).

Aufschlüsselung F/16, Ø ms vorher → nachher: Gesicht 5,78 → 3,46 (davon Neuzeichnen 5,62 → 3,19) · Gefühlszustand
1,80 → 1,07 · Körper (IK, Fußanker, Gewicht, Zubehör) 1,23 → 1,33 · Mikroleben 0,29 → 0,26 · Wahrnehmung 0,58 →
0,08 · Hutkrempe 0,60 → 0,12 · Ausweichen bei Nähe (neu) 0,52 · Mind 0,06 → 0,07 · Blick 0,09 → 0,14 · Hände
0,21 → 0,23 · Sozialer Knoten + Interaktionen 0,05 → 0,10 · Lokomotion 0,03 → 0,04. Objekte, die nach allen
Läufen übrig bleiben: 1114 → 181 (Lambda-Zyklen in Interaktionen und Mind aufgelöst).

Optimierungen (ohne sichtbaren Unterschied, A/B-Bildvergleich und alle Lab-Prüfungen grün):
* Gesicht: Neuzeichnen nur, wenn sich ein Eingang um mehr als 0,25 Pixel in der Bildgröße des Kopfes auswirken
  würde (Kamera-Entfernung, Blickfeld); Normalen nur bei Änderung; leere Flächen ohne Fehler.
* Gefühle: gepackte Felder, nur besetzte Ausschläge, Mischen nur bei Änderung.
* Wahrnehmung: ein öffentlicher Zustand je Figur und Bild statt Neuberechnung je Beobachter; Hutkrempe ohne
  volle Wahrnehmung.
* Außerhalb des Bildes ruht auch das Anwenden der Gefühle (beim Wiedereintritt sofort übernommen).
* Ausweichen: Hüllkugel-Schranke vor der genauen Ellipsoid-Rechnung, Wurzeln aller Figuren einmal je Bild.

**Nicht gemessen:** GPU-Zeit und Rendern (im Container nur Software-Rendering, nicht aussagekräftig), WebAssembly
im Browser. Die Zahlen sind reine CPU-Zeit der Figurenverarbeitung bzw. des Prozess-Schritts.

## Einsatz im Trailer

Die Darsteller sind volle `LumosActor` (`scripted = true`, `autonomy = 0,35`, feste Zufallsstartwerte, auch der
globale Zufall ist gesetzt – jeder Lauf ist bildgenau gleich; geprüft: zwei Läufe, identische Abstände). Die Regie gibt je Bild Blick, Hände und Lachen vor (`script_*`, Ziele ungeglättet: die Augen springen, der
Kopf folgt), `expr()` setzt Stimmungen. Dazwischen lebt jede Figur selbst: Blicke, Lidschlag, Gewicht,
Zubehör-Federn, Atmung, dezente Reaktionen. Gezielt eingesetzt: großes Staunen mit Erstarren, verlegenes
Kopfkratzen, Schielen aufs Glühwürmchen, Stolpern mit Gewicht, Rotwerden, Herzen an der Blüte, Zittern vor dem Boss,
Sternchen nach der Explosion, Bettelblick, Schlucken, Lächeln im Schlaf.

## Vorbereitung der Spiel-Integration (schrittweise, noch nicht umgesetzt)

1. Brett-Zwischensequenzen (Sieg, Sternkauf): `attach` + `feel`/`react`, Autonomie 0,35.
2. Minispiel-Ergebnis: Ereignisse `win`/`lose` aussenden, Gewinner jubelt, andere reagieren.
3. Nitro Dash: Fahrer mit `hold_wheel` und Reaktionen auf Treffer.
4. Je Schritt: Leistung im Web-Build messen, Abschaltbarkeit über `set_enabled(false)` behalten.

## Bekannte Grenzen (ehrlich)

* **Nicht im Spiel eingebaut.** Spielabläufe, Steuerung, Physik und Kollisionen sind unverändert.
* Gesten und Interaktionen sind prozedural über IK; es gibt keine Finger. Schnelle Gesten bleiben IK-Bögen,
  keine handanimierte Qualität.
* Chibi-Geometrie: Der Kopf ist breiter, als der Arm lang ist. Umarmungen gibt es darum nur seitlich, Trösten an
  den Oberarm, Griffe an die Schultern von vorn sind nicht möglich (im Trailer durch Handfläche-an-Handfläche
  ersetzt); beim gemeinsamen Loslaufen an der Hand liegen die Handgelenke 20–28 cm auseinander (Finger berühren
  sich, kein fester Griff).
* Hüllkörper sind Ellipsoide (≈ 1–3 cm genau); breite Hutkrempen zählen nicht und weichen über eine eigene Feder aus.
* Umhänge hängen nach dem Umbinden starr am Oberkörper (schwingen, biegen sich aber nicht).
* Kenney-Figuren: kein Gesicht, Arme nur zielend. Haustiere: kein Gesicht; Schwanzwedeln nur, wo das Modell einen
  eigenen Schwanz-Knoten hat (Katze ja, Hund nein).
* Eigene Avatare (Lumos OS) sind weiterhin **nicht** geprüft.
* Leistung nur als CPU-Zeit headless gemessen; GPU-, Render- und Web-Kosten (WebAssembly) sind nicht gemessen. Das
  Ausweichen bei Nähe kostet bei dichtem Gedränge ≈ 32 µs je Figur zusätzlich.
* Das Character Lab ist bis auf Effekt-Zufall wiederholbar (z. B. High-Five 63 bzw. 65 mm in zwei Läufen).
* Das Sozialverhalten nutzt einfache Regeln (Wahrscheinlichkeiten, Verzögerungen), keine Planung; Ortswechsel
  (trösten gehen, helfen) setzen die Figur per Tween – im Spiel müsste das die Spiel-Logik übernehmen.
* Ob alles natürlich *wirkt*, ist nur per Sichtprüfung beurteilbar; die Kontrollbilder zeigen plausible Abläufe,
  aber keine Prüfung mit Zuschauern.
