# Trailer-Produktion „Lumos Party – Best adventures are shared.“

Eigenständige Produktionsumgebung für den Trailer. Sie ist vollständig vom Spiel getrennt:

* Alles liegt in diesem Ordner: Szene (`Trailer.tscn`), Regie-Skript (`trailer.gd`), eingefrorene Rennstrecke (`trailer_track.gd`), Render-Skript (`render.sh`), Video-Prüfung (`qa.py`) und Trennungs-Prüfung
  (`check_isolation.sh`).
* Die Nitro-Dash-Szene fährt auf einer eigenen Kopie des Lumos-Rings im Stand von Spiel 1.3.0
  (`trailer_track.gd`). Das Spiel hat seine Strecken in 1.4.0 neu entworfen. Die Kamerafahrten des Trailers sind
  auf den alten Verlauf choreografiert und bleiben so gültig (Bildvergleich gegen 1.3.0: gleiche Einstellungen).
  Die Karts selbst zeigen die aktuelle Spieloptik.
* Das Spiel kennt den Ordner nicht. Kein Menüpunkt, keine Szene und kein Skript des Spiels verweist hierher.
  Der Ordner ist auch nicht im Web- oder Linux-Export enthalten (`tools/export_list.gd` exportiert nur
  `autoload/`, `scripts/`, `scenes/` und die Asset-Ordner).
* Der Trailer **liest** vorhandene Teile des Spiels (Figuren-Rig, Modelle, Umgebungen, Effekte, Musik, Boss- und
  Kart-Modelle) und **verändert keines davon**. Alle Inszenierungen sind hier separat umgesetzt: Kamerafahrten,
  Wege, Blickregie, Gags, Weltenwechsel, Montage, Schmetterling, Glühwürmchen, Lagerfeuer und Titel.
* Die Renderqualität (volle Auflösung, 4×MSAA, 8192er-Schatten, kein Animations-LOD, keine Sichtweiten-
  Abschaltung) setzt der Trailer nur im Speicher seines eigenen Prozesses. Gespeichert wird nichts, die
  Spieleinstellungen bleiben unberührt.
* 4K bekommt nur der Trailer: `render.sh` baut ein temporäres Render-Projekt mit eigener Fenstergröße (Symlinks
  auf dieselben Dateien). Die `project.godot` des Spiels bleibt unverändert.

`bash trailer/check_isolation.sh` prüft die Trennung automatisch, auch in der CI: keine Verweise aus dem Spiel,
nicht im Export, Trailer läuft fehlerfrei.

## Video rendern

```bash
bash trailer/render.sh trailer_out 3840 2160 60
```

Ergebnis in `trailer_out/`:

* `Lumos_Party_Trailer_2160p60.mp4`: Master (H.264 High, 4K, 60 fps, AAC 256 kbit/s, −14 LUFS)
* `Lumos_Party_Trailer_1080p60.mp4`: 1080p-Fassung, aus dem 4K-Master verkleinert
* `qa.txt`: Prüfbericht
* `sheets/`: Kontaktbögen mit einem Bild je Sekunde
* `marks.json`: Schnittliste des Trailers

Eine schnelle Kontrollfassung (etwa 5 Minuten) entsteht mit `TRAILER_QUICK=1 bash trailer/render.sh /tmp/vorschau 1280 720 30`.
Der 4K60-Master braucht mit Software-Rendering etwa 1 s je Bild (gemessen: 5731 Bilder in 1 h 48 min). Mit
einer echten GPU geht es deutlich schneller.

Ansehen im Fenster (Esc beendet): `godot --path . res://trailer/Trailer.tscn`. Weitere Optionen nach `--`:

* `--trailer-from=X` startet ab Sekunde X (Vorschau, Ereignisse davor werden sofort ausgeführt)
* `--trailer-msaa=0..3`: Kantenglättung (0 aus, 1 = 2×, 2 = 4×, 3 = 8×)
* `--trailer-shadow=N`: Schattenauflösung
* `--trailer-marks=datei.json`: Schnittliste schreiben
* `--trailer-faces=/ordner`: Kontrollbilder der Mimik (alle vier Darsteller, je Ausdruck ein PNG)

## Prüfung des fertigen Videos (`qa.py`)

Bild für Bild (Analyse in 192×108) und für den Ton in 50-ms-Fenstern:

* **Format:** Auflösung, Bildrate, Bildanzahl, Länge gegenüber der Regie (fehlende oder hängende Szenen).
* **Schwarzbilder:** erlaubt sind nur die Aufblende, die Dunkelheit in Akt 1 und die Abblende.
* **Sprünge:** Jeder harte Bildwechsel wird mit der Schnittliste verglichen (Kamera-Schnitte, Blitze, Wasserwand,
  Weltenwechsel). Ein Sprung, der dort nicht steht, ist ein sichtbarer Fehler im Übergang.
* **Standbilder:** eingefrorene Bildfolgen außerhalb des Abspanns.
* **Ton:** Aussetzer (kurzes Wegbrechen mitten in lauter Musik), Stille, Übersteuerung, True Peak und Lautheit.
  Gewollt ist nur die Pause vor dem BOOM (65,0–65,4 s).

## Aufbau des Trailers (97 s)

| Zeit | Akt | Inhalt |
|---|---|---|
| 0–15 s | 1 · Ein kleiner Stern | Allein im Mondlicht, suchender Blick · Stern erscheint, Schreck wird Neugier · die Hand streckt sich aus, der Stern weicht aus · Berührung: der Stern steigt auf und entzündet den Wald (Himmel und Licht blenden auf, die Leuchtpilze gehen der Reihe nach an) · Staunen in Nahaufnahme, dann hebt sich die Kamera |
| 15–35 s | 2 · Eine Welt voller Wunder | Die Kamera bleibt nah: Glühwürmchen vor der Nase, er will es fangen und lacht · Stolpern über den Ast, Blick zurück, Lachen über sich selbst · Wasserfall über die Schulter gefilmt · die Magierin winkt in der Ferne, er winkt zurück und läuft los |
| 35–58 s | 3 · Gemeinsam unterwegs | Abklatschen (die Hände treffen sich) · Schmetterling auf der Nase, die Magierin läuft auf (Hände im Rücken) · der Barbar kommt keuchend ins Bild, Hände auf den Knien, Schulterklopfen · der Träumer auf dem Stein bemerkt es zu spät · Weltenwechsel hinter dem Baumstamm (Wald → Wiese) · Riesenblume im Gegenschuss, der Held nimmt die Hand der Magierin und zieht sie mit · Kamerafahrt hinter dem Wasserfall-Tor (Wiese → Bucht) |
| 58–65 s | 4 · Das Abenteuer eskaliert | Bucht im Abendlicht, Sand wird zu Vulkangestein, Knuffen im Laufen · der Boss erhebt sich: die Magierin klammert sich an den Helden, der Träumer duckt sich hinter den Barbaren · Stille … BOOM |
| 65–84,5 s | Montage | auf dem Takt (138 BPM): das echte Spielbrett „Wuschel-Wiesen“ aus der Luft, Würfelblock, Sprung dagegen (2 Takte) · Zug über vier Felder, +3 Münzen · der Stern schwebt herab · Minispiel Sumo-Ring (Schubser ins Wasser) · Zielsprint · Boss-Ausweichen · Nitro Dash auf dem Lumos-Ring (Start, Drift, Überholen, Ziel) |
| 84,5–97 s | 5 · Wieder zusammen | Alle nebeneinander auf der Bank am Feuer: Hände wärmen, der Träumer schläft an der Schulter, die Magierin zeigt in die Sterne · Nahaufnahme: Blick zum Keks, Bettelblick, der Barbar reicht ihn hinüber, die Hand nimmt ihn, beide lachen leise · Funke steigt auf, Blick zur aufsteigenden Kamera, Logo, Slogans |

Kein Dialog. Musik: Glühwald-Thema (Akte 1–4 und 5), Hurry-Up-Thema (Montage), dazu Effekte aus der
Sound-Bibliothek des Spiels.

## Technische Grenzen

Der GL-Compatibility-Renderer (Web-tauglich) hat keine echte Tiefenunschärfe. Die Bildtiefe entsteht über Nebel,
Licht, Brennweite und Staffelung im Raum.

## Animationsregie

* **Figuren = Character Framework des Spiels** (`scripts/actor/`, siehe `docs/CHARACTER_FRAMEWORK.md`). Seit 1.5.1
  gibt es nur noch eine Umsetzung: Der Trailer hängt je Darsteller `LumosBody` (Skelett-Modifier) und `LumosFace`
  an, Profil per `LumosActorConfig.detect()`. Eigene Kopien (`trailer_face.gd`, `trailer_body.gd`) gibt es nicht mehr.
  Trailer-Einstellungen: `ground_mask = 0` (Boden = Standhöhe der Figur, keine Raycasts gegen Kulissen),
  `lod = false` (immer volle Qualität), `attention = 0.42`.
  * Mimik: große Augen, Lachaugen, Brauen-Heben bei neuem Blickkontakt, große Münder (auch von weitem lesbar),
    Wangenröte. `expr()` setzt Gesicht **und** Haltung (Brust, Kopf, Schultern) zum Gefühl.
  * Blick: Kopf auf das Ziel, Oberkörper und Hüfte drehen mit (`attend_target`).
  * Arm-IK mit Reach-Assist: `reach()` führt eine Hand an einen Punkt; liegt er zu weit weg, lehnt sich die Brust hin.
  * Fußanker beim Stehen, Gehen und Laufen (nicht in Posen, Sprüngen oder im Kart).
  * `carry()` legt einen Gegenstand in die Hand. Lachen (`laugh()`) ist eine Kette: Schmunzeln, Mund auf, Augen zu
    Sicheln, Brust und Schultern wippen, ausklingen. Mund und Körper teilen dieselbe Phase.
  * Atmung, Kopfneigung (`tilt()`), Vorbeugen. Alles läuft in Filmzeit, also bei 30 und 60 fps gleich.
* **Keine Symbole:** Reaktionen aus der Bibliothek des Spiels laufen ohne „HAHA“, „!“ und Sternchen. Gefühle zeigen
  Gesicht und Körper.
* **Schritte:** Das Tempo, bei dem der Standfuß eines Lauf-Clips am Boden stillsteht, wird beim Start aus dem Clip
  vermessen (Gehen 0,67 m/s, Laufen 2,2 m/s). Die Abspielgeschwindigkeit folgt dem tatsächlichen Tempo, alle Wege
  sind auf diese Geschwindigkeiten ausgelegt. Vorher liefen die Figuren bis zu dreimal schneller als ihre Beine.
* **Raum:**
  * Niemand erscheint mitten im Bild (`_qa_popins()` meldet es sonst). Die Freunde stehen ab der Enthüllung des
    Waldes an ihren Plätzen.
  * Stein- und Hügelhöhe werden aus den Modellen gelesen, niemand schwebt.
  * Sperrzonen halten Bäume und Büsche aus Lichtung, Wasserfall und Sitzplätzen heraus.
  * Wasserfälle nutzen einen eigenen Fließ-Shader ohne Verformung (kein Flimmern vor der Felswand).
* **Spielbrett:** Die Montage baut das Brett mit dem `BoardBuilder` des Spiels (nur gelesen). Würfelblock und
  Stern sind die Modelle aus dem Spiel.
* **Wege:** `go()` beschreibt Wegstücke. Folgen zwei Stücke zeitlich und räumlich direkt aufeinander und zeigen
  in eine ähnliche Richtung, läuft die Figur ohne Halt durch.
* **Blick:** `look()` setzt ein Ziel (Punkt, Objekt, Figur oder `"cam"` für den Zuschauer). Der Kopf folgt mit
  Verzögerung. Ohne Ziel schweift der Blick beim Laufen voraus.
* **Gewicht:** Vorlage beim Beschleunigen, Rücklage beim Bremsen, kurzes Einsacken beim Anhalten.
* **Weltenwechsel:** Stamm und Wasserfall-Tor sind Verdecker, die keiner Welt gehören. Sie stehen zum
  Wechselzeitpunkt genau vor der Kamera und ziehen mit in die neue Welt. Die Schnee-Welt entfällt: zwei Wechsel
  statt vier, dafür mit Übergangszonen (Wiesenblumen am Waldrand, Sand und Palmen am Ende der Wiese). `qa.py` prüft, dass im Wechselbild kein Sprung
  messbar ist.
* **Rennen:** `_race_state()` liefert je Einstellung den Zustand aller Karts als reine Funktion der Zeit. Karts und
  Kamera lesen denselben Zustand. Die Fahrbahn nutzt eine Trailer-eigene Kopie des Straßen-Shaders.
