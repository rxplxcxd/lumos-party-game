# Trailer-Produktion „Lumos Party – Best adventures are shared.“

Eigenständige Produktionsumgebung für den Trailer. Sie ist vollständig vom Spiel getrennt:

* Alles liegt in diesem Ordner: Szene (`Trailer.tscn`), Regie-Skript (`trailer.gd`), Render-Skript (`render.sh`),
  Video-Prüfung (`qa.py`) und Trennungs-Prüfung (`check_isolation.sh`).
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

## Prüfung des fertigen Videos (`qa.py`)

Bild für Bild (Analyse in 192×108) und für den Ton in 50-ms-Fenstern:

* **Format:** Auflösung, Bildrate, Bildanzahl, Länge gegenüber der Regie (fehlende oder hängende Szenen).
* **Schwarzbilder:** erlaubt sind nur die Aufblende, die Dunkelheit in Akt 1 und die Abblende.
* **Sprünge:** Jeder harte Bildwechsel wird mit der Schnittliste verglichen (Kamera-Schnitte, Blitze, Wasserwand,
  Weltenwechsel). Ein Sprung, der dort nicht steht, ist ein sichtbarer Fehler im Übergang.
* **Standbilder:** eingefrorene Bildfolgen außerhalb des Abspanns.
* **Ton:** Aussetzer (kurzes Wegbrechen mitten in lauter Musik), Stille, Übersteuerung, True Peak und Lautheit.
  Gewollt ist nur die Pause vor dem BOOM (65,0–65,4 s).

## Aufbau des Trailers (95,5 s)

| Zeit | Akt | Inhalt |
|---|---|---|
| 0–15 s | 1 · Ein kleiner Stern | Dunkelheit, Stern erscheint, Neugier, Stern weicht aus, Berührung → Lichtwelle → Glühwürmchen-Wald, Kran nach oben |
| 15–35 s | 2 · Eine Welt voller Wunder | Weg, Glühwürmchen vor der Nase, Stolpern über den Ast, Wasserfall, die Magierin winkt in der Ferne, Loslaufen |
| 35–58 s | 3 · Gemeinsam unterwegs | High-Five, Schmetterling auf der Nase, Zusammenstoß, der keuchende Barbar, der Träumer auf dem Stein, Beinahe-Zusammenprall, Weltenwechsel hinter dem Stamm und durch die Wasserwand, der vergessene Freund wird an der Hand mitgezogen |
| 58–65 s | 4 · Das Abenteuer eskaliert | Sternenblitz, Strand → Vulkangestein, der Boss erhebt sich, alle schauen nach oben, Stille … BOOM |
| 65–83 s | Montage | auf dem Takt (138 BPM): Minispiel-Start, Münzduell, Fotofinish, Wasserplumps, Boss-Ausweichen, Siegerpose, Nitro-Dash-Drift, Überholen, Ziellinie, Jubel |
| 83–95 s | 5 · Wieder zusammen | Lagerfeuer: Hände wärmen, Sterne schauen, essen, eingeschlafen an der Schulter, Keks-Pointe, Funke steigt auf, Logo, Slogans, Plattform-Hinweis |

Kein Dialog. Musik: Glühwald-Thema (Akte 1–4 und 5), Hurry-Up-Thema (Montage), dazu Effekte aus der
Sound-Bibliothek des Spiels.

## Technische Grenzen

Der GL-Compatibility-Renderer (Web-tauglich) hat keine echte Tiefenunschärfe. Die Bildtiefe entsteht über Nebel,
Licht, Brennweite und Staffelung im Raum.
