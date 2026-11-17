# Geräte-Testplan: Bildrate, Bildzeiten, Speicher, Ladezeiten (ab 1.5.3)

Ziel: belastbare Leistungswerte **auf echten Geräten** – und eine klare Trennung von Werten aus dieser Test-Umgebung.
Dieser Plan ist reproduzierbar vorbereitet; **echte Geräte standen in der Entwicklungsumgebung nicht zur Verfügung**
(Cloud-Container ohne GPU, ohne Smartphone, ohne Tablet). Es gibt hier deshalb **keine** Geräte-FPS – nur
gekennzeichnete Server- und Simulationswerte (Abschnitt 6).

## 1. Drei Arten von Messwerten – nie vermischen

| Art | Wo | Was sie aussagt | Was sie **nicht** aussagt |
|---|---|---|---|
| **Gerät (echt)** | Zielgerät, echter Browser/Build, echte GPU | Bildrate, Ruckler, Akku/Wärme, Ladezeit wie beim Spieler | – |
| **Test-Server (headless)** | CI/Container, Dummy-Renderer | CPU-Kosten von Skripten, Physik, Animation, Szenenbaum; Speicher; Engine-Fehler | GPU-Kosten, echte FPS |
| **Simuliert** | Chromium mit Software-Rendering (SwiftShader/llvmpipe), CPU-Drosselung | Verhältnisse (vorher/nachher, Szene A vs. B), lange Hauptthread-Aufgaben, Ladeverlauf | Werte eines bestimmten Geräts |

Jede Tabelle nennt ihre Art im Titel. Simulierte oder Server-Werte werden nie als „FPS auf Gerät X“ berichtet.

## 2. Messgrößen

* **Mittlere FPS** und **1 %-Tief** (Mittel der langsamsten 1 % der Bilder, als FPS).
* **Bildzeit-Verteilung:** p50, p95, p99, Maximum; Anteile > 16,7 ms (60 FPS verfehlt), > 33,3 ms (sichtbarer Ruckler),
  > 50 ms; Histogramm in 2-ms-Schritten.
* **Ausreißer** mit Zeitpunkt und Ursache-Hinweis (Szenenwechsel, erstes Laden eines Klangs/Modells, Shader-Kompilierung).
* **CPU/GPU:** CPU-Zeit je Bild (Godot: Prozess + Physik), GPU-Zeit je Bild (Godot-Viewport-Messung
  `viewport_set_measure_render_time`, im Browser über `EXT_disjoint_timer_query` wo verfügbar), Draw-Calls, Primitive.
* **Speicher:** statischer Speicher, Videospeicher; im Browser zusätzlich JS-Heap (`performance.memory`, nur Chromium).
* **Ladezeiten:** Start bis Hauptmenü, Hauptmenü → Brett, Brett → Minispiel, Menü → Rennen (kalt: erster Start nach
  Leeren des Caches; warm: zweiter Start).
* **Mehrere Figuren:** Character Framework mit 4/8/16 Figuren (PerfLab-Szenarien A, F), Brett mit 4 lebendigen Figuren,
  Siegerehrung.
* **Split-Screen:** Nitro Dash mit 2, 3, 4 Ansichten (je eigene Kamera, eigene Linsentropfen), Gewitterstrecke.

## 3. Geräte-Matrix

| Gruppe | Beispiele | Build | Status |
|---|---|---|---|
| Desktop, dedizierte GPU | Windows/Linux, GTX/RTX- oder RX-Klasse | Linux-/Windows-Export, Web (Chrome, Firefox) | nicht verfügbar – vorbereitet |
| Desktop, integrierte GPU | Laptop mit Intel Iris/UHD, AMD Vega | Web (Chrome, Edge) | nicht verfügbar – vorbereitet |
| Mac | Apple-Silicon-MacBook | Web (Safari, Chrome) | nicht verfügbar – vorbereitet |
| Smartphone hoch | aktuelles iPhone, Android-Oberklasse | Web/PWA (Safari, Chrome) | nicht verfügbar – vorbereitet |
| Smartphone mittel/niedrig | Android-Mittelklasse (4 GB RAM), älteres iPhone | Web/PWA | nicht verfügbar – vorbereitet |
| Tablet | iPad, Android-Tablet | Web/PWA | nicht verfügbar – vorbereitet |
| Test-Server | dieser Container (CPU, kein GPU) | headless | gemessen (Abschnitt 6) |
| Simulation | Chromium headless, Software-GL, CPU-Drosselung 1×/4× | Web-Export | gemessen, falls Export möglich (Abschnitt 6) |

## 4. Ablauf je Gerät (reproduzierbar)

1. **Build:** gleicher Commit für alle Geräte; Version unten rechts im Hauptmenü notieren (z. B. 1.5.3).
2. **Einstellungen:** Grafikstufe einmal *Automatisch* (Erkennung notieren) und je einmal *Niedrig/Mittel/Hoch*;
   Bildrate 60 und 120 (wo das Gerät 120 Hz kann); „Lebendige Mimik“ an und aus; „FPS anzeigen“ an.
3. **Szenen** (je 60 s, jeweils 3 Wiederholungen, erster Lauf kalt):
   Hauptmenü (Figuren-Insel) · Brett Wuschel-Wiesen · Brett Wolkenturm (vertikal, meiste Knoten) · Minispiel
   Sumo-Schubser · Minispiel Rhythmus-Küche · Nitro Dash Lumos-Ring (1 Spieler) · Nitro Dash Sturmpass mit 2 und
   4 Spielern im Split-Screen · Siegerehrung.
4. **Aufzeichnen:**
   * Web: `node tools/dev/web_perf.js "<url>?args=--perf-log" 60 [drosselung]` (Chromium; Bildintervalle, lange
     Aufgaben, [PERF]-Marker des Spiels). Auf dem Gerät selbst: Remote-Debugging (Chrome → `chrome://inspect`,
     Safari → Web-Inspektor) mit dem Performance-Panel; FPS-Anzeige im Spiel als Kontrolle.
   * Desktop-Build: `godot --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/scene_profile.gd
     --target=<ziel> --secs=60` mit echtem Renderer (liefert Bildzeit-Verteilung, Draw-Calls, Speicher).
   * Framework mit vielen Figuren: `res://tools/charlab/PerfLab.tscn -- --perf-render` (mit Grafik).
5. **Notieren:** Gerät, Betriebssystem, Browser + Version, Akkustand/Netzteil, Raumtemperatur grob, Ladezeiten
   (Stoppuhr oder [PERF]-Marker), Auffälligkeiten (Ruckler mit Zeitpunkt, Wärme, Drosselung).
6. **Auswerten:** Tabelle unten je Gerät; Vergleich mit der Vorversion nur bei gleichem Gerät und gleichen
   Einstellungen.

## 5. Ergebnisvorlage (Gerät, echt)

| Gerät | Browser/Build | Grafikstufe | Szene | Ø FPS | 1 %-Tief | p95 / p99 ms | > 33 ms | Speicher | Ladezeit |
|---|---|---|---|---|---|---|---|---|---|
| *(leer – noch kein Gerät gemessen)* | | | | | | | | | |

## 6. Vorhandene Werte (nicht von Geräten)

* **Test-Server, headless (CPU):** `docs/PERF_SCENES.md` (105 Szenen, Stand 1.5.2) und die 1.5.3-Messungen in
  `docs/ABSCHLUSS_1.5.3.md` (Framework je Bereich, Bretter mit und ohne eigenes Leben, Strecken vorher/nachher).
* **Test-Server, Software-Renderer (xvfb/llvmpipe):** Draw-Calls, Primitive, Videospeicher je Szene
  (`data/perf_scenes_render.jsonl`) – Zählwerte gelten auf jeder GPU, die Bildzeiten nicht.
* **Simuliert (Chromium, Software-GL, CPU-Drosselung):** siehe `docs/ABSCHLUSS_1.5.3.md`, Abschnitt F – nur zum
  Vergleichen von Szenen und Ständen, nicht als Geräte-FPS.
