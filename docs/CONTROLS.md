# Steuerung – plattformübergreifender Vertrag für alle Minispiele

Lumos Party läuft auf Smartphones, Tablets, Laptops, PCs und Lumos-Konsolen. Deshalb gilt für **jedes**
Minispiel, auch für künftige:

1. **Keine exklusive Hardware.** Kein Spiel darf Joy-Con-Gesten, Gyroskop, Beschleunigungssensor,
   Mikrofon (Pusten) oder andere Gerätesensoren voraussetzen.
2. **Sensoren sind höchstens ein optionales Extra.** Erkennt das Spiel ein Gerät mit Sensor, darf es ihn
   *zusätzlich* anbieten. Gewinnen und Spielen muss aber ohne Sensor genauso gut gehen.
3. **Universeller Standard-Weg:** Jedes Minispiel ist vollständig und gleichwertig über die Standard-Aktionen
   unten spielbar.
4. **Design-Übersetzung:** Basiert eine Spielidee auf Schütteln, Pusten oder Gesten, wird sie auf Standard-Eingaben
   umgedacht. Aus Schütteln/Pumpen wird abwechselndes Hämmern von A/B, aus Pusten ein Windstoß per A/B in
   Stick-Richtung, aus Neigen/Balancieren die Stick-Steuerung. Beispiel: Seifenblasen-Ballett.

## Standard-Aktionen und ihre Belegung

| Aktion | Gamepad | Tastatur | Maus (im Minispiel) | Touch |
|---|---|---|---|---|
| Stick (Bewegen/Zielen) | linker Stick / Steuerkreuz | WASD oder Pfeiltasten | – | virtueller Stick |
| A (Springen/Bestätigen) | A | Leertaste, Enter, J, Z | Linksklick | A-Knopf |
| B (Aktion/Werfen) | B | K, X, Rücktaste | Rechtsklick | B-Knopf |
| X | X / L-Schulter / L-Trigger | E, L, C, Strg | – | X-Knopf (falls angezeigt) |
| Y (halten: Emote-Rad) | Y | Q, I, V | Emote-Knopf oben rechts | Emote-Knopf oben rechts |
| R | R-Schulter / R-Trigger | Umschalt | – | – |
| Start/Pause | Start, Back | Esc, P | – | Pause-Knopf |

Die Maus zählt nur während eines laufenden Minispiels als A/B (`InputHub.mouse_play`). In Menüs bleiben Klicks
normale Klicks. Auf Touch-Geräten ist die Maus-Belegung aus, weil Antippen auch Maus-Ereignisse erzeugt.

**Emotes:** Y halten öffnet auf Brett und in Minispielen das Emote-Rad (acht selbst gezeichnete Grafiken, keine
Standard-Emojis); Stick wählen, loslassen sendet. Alternativ per Klick/Tipp auf den Emote-Knopf. Abklingzeit 1,1 s.

**Menüs:** Listen scrollen auf Touch-Geräten per Wischen mit Schwung; ein Wischen löst beim Loslassen keinen
Knopf aus. In der Spieler-/CPU-Auswahl springt der Fokus mit links/rechts zwischen Figur, Typ und Stufe einer
Zeile und mit hoch/runter zwischen den Zeilen; A auf einem Pfeil ändert den Wert.

**Anleitung vor Minispielen:** Lokal bleibt sie stehen, bis jemand bestätigt (A, Leertaste, Klick oder Tippen).
Online bestätigt jeder selbst („Bereit!“), spätestens nach 15 s geht es los.

**Bildrate (Einstellungen → Grafik):** **Automatisch** (Standard seit 1.2.7: 120 FPS auf Bildschirmen ab 100 Hz wie
iPhone/iPad Pro, Gaming-Monitoren und High-Hz-Android, sonst 60; im Browser wird der Bildschirmtakt gemessen),
60 FPS, 120 FPS oder Maximal (Bildschirmtakt). Die Physik läuft im gleichen Takt mit. Schafft ein Gerät die 120
nicht dauerhaft, fällt die Automatik für die Sitzung auf stabile 60 FPS zurück, statt die Auflösung zu opfern;
Notebooks und Handhelds im Akkubetrieb bleiben bei 60.

**Sichere Bildschirmränder:** HUDs, Boss-Leisten, Emote-Knopf, Cutscene-Hinweis und die FPS-Anzeige (Debug,
Einstellungen → „FPS anzeigen“) liegen innerhalb der sicheren Ränder – auf dem iPhone nicht mehr von runden
Ecken, Dynamic Island oder Home-Leiste angeschnitten (`InputHub.safe_margins()`, `UI.hud_root()`).

## Umsetzung im Code

* Eingaben immer über `InputHub` abfragen: `move(slot)`, `pressed(slot, "a")`, `held(slot, "b")`.
  Nie direkt über Geräte-APIs. So funktionieren Tastatur, Maus, Gamepad, Touch, Online und CPU (virtuelle
  Eingaben) automatisch.
* Jeder Katalog-Eintrag in `autoload/game_state.gd` braucht einen `"controls"`-Text mit Standard-Aktionen.
* Optionale Sensor-Extras gehören hinter eine Geräte-Erkennung und eine Einstellung (Standard: aus). Im Skript
  steht dann ein Kommentar `# FALLBACK:`, der den gleichwertigen Standard-Weg beschreibt.
* CI-Prüfung: `python3 tools/validate_controls.py`. Sie bricht ab bei fehlendem `controls`-Text, bei
  Sensor-Mechaniken ohne „optional“ und bei Sensor-APIs ohne `# FALLBACK:`.

## Qualitäts-Sweep

`bash tools/dev/minigame_sweep.sh [ausgabe.jsonl] [ids…]` spielt jedes Minispiel mit 4 CPUs im Schnellvorlauf und
meldet:
* die Spieldauer: zu früh endende oder hängende Spiele;
* wer zu Spielbeginn bzw. am Ende noch im Spiel ist;
* Figuren, die durch den Boden gefallen sind;
* Figuren, deren Körpermitte in fester Geometrie steckt (Clipping);
* Texte, die über den Bildschirmrand hinausragen;
* Skriptfehler.

So wurden das Seifenblasen-Ballett (alle im Intro ausgeschieden, Spielzeit 0 s) und Dungeon Drop (Feld nach
≈10 s zerstört) gefunden.
