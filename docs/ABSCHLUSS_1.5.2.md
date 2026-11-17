# Abschlussbericht 1.5.2 – Qualitätsdurchlauf („Full Universe Polish“)

Stand: 17.11.2026 · Branch `claude/elegant-johnson-2kfiut` · `main` unverändert (wartet auf Freigabe).
Laufende Arbeitsnotiz: `docs/WORKLOG.md` · Spielertest: `docs/PLAYTEST.md` · Leistung: `docs/PERF_SCENES.md` ·
Framework: `docs/CHARACTER_FRAMEWORK.md` · Inventar: `data/project_inventory.json`.

**Kurzfazit.** Alle 69 Minispiele, 12 Strecken, 10 Bretter, 10 Bosskämpfe, die Modi und das ganze Menü wurden
automatisiert gespielt bzw. bedient und gemessen; gefundene Fehler sind behoben (u. a. eine defekte Kernmechanik,
blockierende Züge, Ruckler bis 448 ms, Engine-Fehler in fünf Minispielen, eine Fokus-Falle im Menü). Nitro Dash hat
auf 10 von 12 Strecken eigene Ereignisse, gestaltete Rückgeraden und Wassertropfen auf der Linse. Das Character
Framework steckt jetzt im Spiel – vorerst in Menü-Insel und Siegerehrung. Nicht erledigt: Bretter einzeln beleben,
Framework auf Brett/Minispielen/Nitro Dash, deutlich längere Strecken, Bildraten auf echten Geräten.

## A. Minispiele

* **Anzahl (aus dem Code):** 69, alle mit Szene und Skript. Kategorien (mehrfach möglich): FFA 49, 2v2 23, Duell 13,
  1v3 7, Münz 5, Glück 3, Boss 2, Koop 1. Die README nannte noch 38 (korrigiert).
* **Einzelprüfung:** Lumos Player Agent (`tools/dev/player_agent.gd`) spielt jedes Spiel als Mensch über echte
  Tastatur-Ereignisse – klug (in jeder Kategorie, zwei Startwerte), abwesend, zufällig, Button-Masher: 379 Läufe im
  zweiten Durchlauf, 33 Nachprüf-Läufe für die zuletzt geänderten Spiele. Dazu misst das Szenen-Profil jedes Spiel von
  Spielbeginn bis Ende (Bildzeiten, Speicher, Engine-Fehler).
* **Gefundene Probleme und Änderungen:**

| Spiel | Problem | Änderung |
|---|---|---|
| Stampf-Wellen | Kernmechanik wirkungslos (Landung nie erkannt) → fast immer Vierfach-Gleichstand | Landung nach Abheben; Bühne schrumpft zweimal mit Vorwarnung; 11–24 Treffer je Partie |
| Kürbis-Weitwurf, Geisterschloss, Wolkenboss | Echtzeit-Uhr statt Spielzeit (CPU warf nie; Sprünge nach Pause) | `MinigameBase.clock` |
| Pinguin-Curling, Schatz-Schnüffeln, Stein-Kegeln | abwesender Spieler blockierte die Runde | Zug-Zeitbegrenzung mit Countdown |
| 18 Spiele | Modelle erst beim ersten Auftauchen geladen (Ruckler bis 448 ms) | Vorabladen beim Aufbau |
| Stein-Kegeln | Bahn schwebte, Felsen lagen auf der Bahn | Plateau, Deko nur seitlich |
| Rhythmus-Küche | Ruck bis 292 ms beim Gangwechsel (Song kam erst dann von der Platte) | Gänge, Hurry-Up und Outro im Hintergrund vorgeladen |
| Lava-Surfen, Farb-Chaos, Wolkenboss, Ballon-Schlacht | Engine-Fehler „material is null“ beim Löschen eingefärbter Objekte | Material bis nach der Render-Instanz gehalten |
| Achterbahn-Schießbude | Intro: Kanone zielte mit Nullvektor | feste Richtung als Rückfall |
| Ballon-Schlacht | Skelett-Basis einer geschrumpften Figur invertiert (Fehler je Bild) | übersprungen |

* **Testergebnisse:** alle 69 Spiele enden in allen Strategien sauber, Ergebnis lässt sich mit A verlassen,
  0 Skriptfehler; Engine-Fehler während des Spiels: vorher 47 Meldungen in 5 Spielen, jetzt 0; kein Bild über 33 ms
  (längstes 29,8 ms, Minigolf-Duell); Spielzeit-Fenster der Messung: 62 von 67 Spielen bis zum Ende gespielt.
* **Offene Einschränkungen:** Spielspaß und Lesbarkeit kann der Agent nicht bewerten; bei Analog-Präzision
  (Minigolf, Kart-Kegeln, Rempelkugeln, Eisschollen) sagt der Platz des Tastatur-Agenten wenig über die Balance;
  Gamepad und Touch spielt der Agent nicht (Zuordnung geprüft mit `tools/validate_controls.py`).

## B. Nitro Dash

| Strecke | Länge/Runde | Höhenunterschied | Gesamtkurve | längste Gerade | Streckenereignisse | Mechaniken | CPU-ms Mittel / p99 / max |
|---|---|---|---|---|---|---|---|
| Lumos-Ring | 1054 m | 26 m | 1081° | 160 m | – | – | 1.25 / 3.07 / 10.3 |
| Korallen-Kanal | 1033 m | 12 m | 969° | 149 m | water ×4, crab ×1 | dividers:1 | 1.29 / 2.7 / 11.3 |
| Vulkan-Inselchen | 990 m | 28 m | 966° | 160 m | lava ×5 | – | 1.17 / 2.32 / 7.2 |
| Gewitter-Pass | 1191 m | 23 m | 1209° | 161 m | bolt ×2, rock ×2 | wet:3 | 1.51 / 3.38 / 10.3 |
| Frostgipfel | 994 m | 19 m | 901° | 159 m | snowball ×3 | – | 1.23 / 3.41 / 10.1 |
| Sternenstaub-Bahn | 1189 m | 32 m | 1239° | 194 m | orb ×3 | bounce:3 | 1.43 / 3.24 / 11.0 |
| Stadt-Rallye | 1113 m | 3 m | 1125° | 131 m | car ×4 | dividers:1 | 1.28 / 2.78 / 7.8 |
| Wüsten-Canyon | 1008 m | 24 m | 1037° | 152 m | tumbleweed ×2, sand ×2 | bounce:1 | 1.19 / 2.37 / 7.6 |
| Glühwald-Pfad | 1151 m | 8 m | 1240° | 77 m | – | wet:1, tunnel:1, bounce:4 | 1.19 / 2.47 / 7.5 |
| Zuckerguss-Allee | 1043 m | 26 m | 1199° | 154 m | gumball ×3 | bounce:2 | 1.26 / 3.01 / 10.5 |
| Dschungel-Tempel | 1130 m | 7 m | 1063° | 134 m | log ×4 | dividers:1 | 1.12 / 3.07 / 11.6 |
| Wasserfall-Schlucht | 1043 m | 11 m | 851° | 154 m | water ×3 | wet:1, falls:1 | 1.35 / 3.16 / 7.5 |

CPU-ms: Bildzeit der CPU-Seite auf dem Testserver (siehe E). Gesamtkurve = Summe der Richtungsänderungen je Runde.

* **Neue Hindernisse und Streckenereignisse (je Strecke im festen Takt, mit Vorwarnung, 3 s Schonfrist nach einem
  Treffer):** Wasser- und Sandfontänen, Lava-Geysire, Blitzeinschläge mit dunkler Einschlagstelle, Steinschlag mit
  Schatten, rollende Schneebälle, Kaugummikugeln und Sternschnuppen, Querverkehr, Steppenläufer, Krabben,
  Baumstämme. 10 von 12 Strecken haben eigene Ereignisse (vorher 2); Lumos-Ring und Glühwald-Pfad bleiben bewusst
  ohne (Einsteigerstrecke bzw. Tunnel-, Nass- und Sprungpassagen).
* **Streckenaufbau:** Der Streckenbaukasten gestaltet die Gerade des Rundenschlusses mit Schlenkern, Kuppen,
  Item-Reihen und Marken; neun Strecken verloren ihre 110–290 m lange leere Rückgerade (z. B. Glühwald 233 → 77 m,
  Stadt 264 → 131 m). Neue Item-Reihen und Sprungfelder auf vier Strecken.
* **Neue visuelle Effekte:** lichtbrechende Wassertropfen auf der Kameralinse (Wasserfall, Fontäne, Gischt des
  Vordermanns, Gewitterregen, Auftauchen; Bildmitte bleibt frei, nicht auf „Niedrig“), Reifengischt aus beiden
  Hinterrädern, Spritzer und Funken je Ereignis.
* **Physik/KI:** Treffer-Schonfrist (`HIT_GRACE` 3 s); KI bremst vor Querverkehr nur noch bei Tempo > 9 (blieb vorher
  bis 3,3 s stehen). Die Fahrphysik selbst (1.4.0) blieb unverändert.
* **Performance:** CPU-Seite je Strecke 1,12–1,51 ms im Mittel, p99 ≤ 3,41 ms, längstes Bild 11,6 ms, kein Bild
  über 33 ms (8 Karts, 45 s Fahrt); Render-Zählwerte in `docs/PERF_SCENES.md`.
* **Tests:** Fahrtest aller 12 Strecken – 8 von 8 CPU-Karts im Ziel, keiner hängt fest, 0 Skriptfehler,
  Rundenzeiten-Median 38,4–47,3 s; Item-Regeln-Test OK; CI-Stichprobe 5 Strecken.
* **Grenzen:** Die Runden sind kaum länger geworden (≈ 990–1190 m, 40–47 s); Linsentropfen nur in der
  Einzelansicht, nicht im Split-Screen.

## C. Spielbretter und Welten

| Brett | Felder | Abzweige | Boss | CPU-ms Mittel / p99 / max | Speicher-Spitze | Dauertest |
|---|---|---|---|---|---|---|
| Dungeon Deep | 44 | 3 | ignis | 0.28 / 1.6 / 8.7 | 213 MB | 5 Runden, 4 CPU: OK |
| Sonnige Palmen-Bucht | 44 | 4 | klabautox | 0.35 / 2.12 / 32.0 | 226 MB | 5 Runden, 4 CPU: OK |
| Sternen-Wolkenland | 46 | 4 | astraios | 0.34 / 1.74 / 9.0 | 222 MB | 5 Runden, 4 CPU: OK |
| Geisterfriedhof | 45 | 4 | grabstein | 0.35 / 1.52 / 8.6 | 246 MB | 5 Runden, 4 CPU: OK |
| Frostdorf | 44 | 4 | frostbart | 0.34 / 2.39 / 8.3 | 226 MB | 5 Runden, 4 CPU: OK |
| Sternen-Sternwarte | 44 | 4 | galaxus | 0.32 / 1.75 / 10.3 | 214 MB | 5 Runden, 4 CPU: OK |
| Glühwürmchen-Zauberwald | 44 | 4 | noxumbra | 0.33 / 1.96 / 13.1 | 230 MB | 5 Runden, 4 CPU: OK |
| Wuschel-Wiesen | 44 | 4 | baahemoth | 0.34 / 1.62 / 8.8 | 223 MB | 5 Runden, 4 CPU: OK |
| Zuckerback-Torte | 45 | 4 | marquise | 0.32 / 1.72 / 7.8 | 227 MB | 5 Runden, 4 CPU: OK |
| Der Wolkenturm | 51 | 3 | zephyros | 0.46 / 2.28 / 10.4 | 230 MB | 5 Runden, 4 CPU: OK |

* **Geprüft:** alle 10 Bretter im Dauertest (5 Runden Party mit 4 CPUs) und im CI-Langzeittest (12 Runden,
  Speicher-/Objekt-Lecks), Deko-Prüfung aller Bretter und Minispiel-Arenen (1 Fund → 0: Stein-Kegeln), Leistungsprofil
  jedes Bretts (40 s Spielzeit), Bosskämpfe aller 10 Bosse (CPU 0,89–1,26 ms im Mittel, längstes Bild 11,9 ms),
  Menü-Insel, Siegerehrung.
* **Verbesserungen:** Siegerehrung am Party-Ende mit Character Framework (siehe D); sonst **keine** Gameplay- oder
  Optikänderung an den Brettern in diesem Durchlauf. Die Nacht-Stimmung des Glühwürmchen-Zauberwalds ist
  unverändert erhalten.
* **Verbleibend:** Bretter wurden nicht einzeln belebt oder überarbeitet; ein einzelnes Bild mit 32,0 ms auf der
  Palmen-Bucht (knapp unter der 33-ms-Grenze, nicht untersucht).

## D. Character Framework

* **Komponenten:** `LumosActor` (Fassade), `LumosBody` (Haltung, Gewicht, IK, Sekundärbewegung, Ausweichen),
  `LumosFace` (gezeichnetes Gesicht), `LumosEmotion` (≈ 70 Gefühle mit Hüllkurven), `LumosPersonality`, `LumosMind`,
  `LumosSocial`, `LumosMicro` (Mikroleben, Gesten), `LumosLayers` (Prioritäten), `LumosInteraction`/`LumosInteract`
  (14 Interaktionen), `LumosCartoon`, `LumosLocomotion`, `LumosProf` (Messpunkte); neu: `LumosGame` (Spiel-Anbindung).
* **Neu in diesem Durchlauf:** Einsatz im Spiel (Menü-Insel: Gesichter, Mikroleben, Blicke, Reaktionen aufs Antippen,
  Gruppenjubel; Siegerehrung: Anspannung, Erleichterung, Freude, Stolz, Verlegenheit), Schalter „Lebendige Mimik“,
  aus auf „Niedrig“; Korrektur: Abschalten stellt jetzt die Original-Augen wieder her.
* **Animationen/IK (Finalisierung 1.5.2):** Stürze und Aufstehen mit Helfer, seitliche Umarmung, Trösten am Oberarm,
  vorausschauendes Ausweichen von Kopf und Oberkörper. Character Lab: 98 von 98 Prüfungen bestanden, darunter
  „keine Durchdringung in 28 Interaktionen“ (kleinster Abstand −17 mm bei Toleranz −30 mm); Trailer: kleinster Abstand
  +23 mm, keine Durchdringung.
* **Emotionen und Persönlichkeit:** Spiel-Reaktionen werden im Gesicht gespiegelt (wave → Freude, victory → Jubel,
  shocked → Überraschung, sad, dizzy, trip_fall …); Persönlichkeit steuert Reaktionsverzögerung, Ausdrucksstärke,
  Blickkontakt, Ansteckung.
* **Performance:** Performance-Labor (16 Figuren, CPU): Stehen 7,16 → 3,74 ms, alles zugleich 11,24 → 7,43 ms nach
  der Optimierung. Im Spiel: Menü-Insel mit 6 Figuren +1,3 ms je Bild (0,22 → ≈ 1,5 ms auf dem Testserver; davon
  Körper 0,4, Fassade/Gefühle/Blicke 0,4, Gesichter 0,3 ms); Siegerehrung 4 Figuren für ≈ 25 s.
* **Kompatibilität:** KayKit-Helden voll; Haustiere ohne Gesicht; Kenney-Figuren nur zielende Arme; eigene
  Lumos-Avatare bleiben ohne Framework (noch nicht geprüft).
* **Grenzen:** nicht auf Brett-Figuren, Minispiel-Avataren und Nitro-Dash-Fahrern (dort entstehen die Figuren nicht
  neu – Gesichter würden mitten in der Einstellung erscheinen; braucht Einbau ab Szenenstart und Messung im
  Web-Build); auf Distanz der Menü-Insel ist die Mimik subtil; keine Finger, Umarmung nur seitlich (Chibi-Proportionen).

## E. Technische Qualität

| Prüfung | Ergebnis |
|---|---|
| Skript- und Szenenprüfung (`Check.tscn`) | 258 Dateien, 0 Probleme |
| System-Tests (CPU-Stufen, Inventar, Items, Emotes, Steuerung, Touch) | TESTS OK – 0 Fehler |
| Nitro Dash Item-Regeln | OK |
| Character Behavior Laboratory | 98/98, CHARLAB OK |
| Spieler-Agent | 69/69 Spiele vollständig gespielt, 0 Skriptfehler |
| Menü-Agent (Tastatur 16:9, Controller, Smartphone 19,5:9, Tablet 4:3) | 10 Seiten ohne Befund, 11/11 Abläufe |
| Szenen-Profil (105 Szenen) | 0 Engine-Fehler, 0 Bilder > 33 ms |
| Fahrtest 12 Strecken, Brett-Dauertests | bestanden |
| CI (Import, Prüfungen, Tests, Lab, Langzeit-Test, Online-Tests, Web/PWA/Linux-Export, Browser-Rauchtest) | Lauf 49 und 50 grün; Lauf für den Endstand: siehe G |

* **Regressionen:** nach jedem Paket Check, betroffene Tests, Agent für die geänderten Spiele bzw. Menü-Agent; keine
  Regression gefunden. Kein Test wurde abgeschwächt, übersprungen oder entfernt.
* **Performance:** `docs/PERF_SCENES.md` – CPU-Seite im Mittel 0,3–1,6 ms je Bild, p99 ≤ 7,3 ms. Das ist die
  Rechenzeit auf einem Server-Prozessor ohne Grafikkarte; echte Bildraten auf Smartphones, Konsole und im Web-Build
  sind **nicht** gemessen.
* **Speicher:** statischer Speicher je Szene 108–246 MB (Spitze), nach jedem Ablauf zurück im Menü 0 verwaiste
  Knoten; Wachstum über viele Runden prüft der CI-Langzeittest.
* **Laufzeitfehler:** 0 Skriptfehler in allen Läufen; Engine-Fehler 47 → 0.
* **Plattformen/Export:** Web/PWA (WebGL2 ohne Threads, Vercel/GitHub Pages/iOS-tauglich), Linux mit eingebettetem
  PCK (Lumos-Sideload), Store-Paket – alle im CI gebaut, Rauchtest in Chromium. Physische Geräte nicht getestet.

## F. Trailer

| Merkmal | Wert |
|---|---|
| Datei | `Lumos_Party_Trailer_1080p60.mp4` (an den Bericht angehängt) |
| Auflösung | 1920 × 1080 |
| Bildrate | 60/1 fps konstant, 5836 Bilder. Nachweis echter 60 fps: Bild-zu-Bild-Vergleich – nur 20 von 5835 Paaren nahezu gleich, alle im gewollt schwarzen Anfang (0–0,2 s) und im Schlussbild (97,0–97,2 s); eine auf 60 fps verdoppelte 30-fps-Datei hätte ≈ 2900 solcher Paare |
| Dauer | 97,27 s |
| Größe | 159 352 841 Byte (159,4 MB) |
| Codec | H.264 High |
| Audio | AAC-LC 48 kHz Stereo, −14,1 LUFS, True Peak −1,2 dBFS |
| QA | `qa.py` OK: Helligkeit ⌀ 72, 21 harte Schnitte (alle gewollt), Weltenwechsel bei 52,02 s und 57,97 s unsichtbar (Δ 14,0 / 12,6); Durchdringungs-Prüfung OK (+23 mm) |
| Kontaktbogen | 5 Bögen (`sheets/sheet_00–04.png`) |

Storyboard unverändert (durchgehender Lauf, Weltenwechsel durch Vordergrund-Verdeckung); überarbeitet wurde der
Stamm des Wechsels Wald → Wiese (Rinde statt schwarzer Fläche, schnellerer Durchzug). Die Darsteller sind volle
Framework-Figuren.

## G. Git und Release-Status

* **Branch:** `claude/elegant-johnson-2kfiut` (14 Commits vor `main`); `main` unangetastet.
* **Relevante Commits dieses Durchlaufs:** `494fb7ec` Inventar, Player-Agent, Streckenereignisse · `7f517a1e`
  Rückgeraden, Linsentropfen, Vorabladen · `6279cff3` Linsentropfen sichtbar, KI vor Querverkehr · `0b34856c`
  Trailer-Stamm · `b21548a7` Stein-Kegeln, Neu-Render · `73a3b8e0` Changelog · `1cdef2d3` Menü-Agent und
  Menü-Korrekturen · `24229018` Framework im Spiel, Szenen-Profil, Ruckler/Engine-Fehler · danach Bericht und Profil
  (siehe `git log`). Davor (Finalisierung): `a9cea90b`, `bc2a005d`.
* **Arbeitsbaum:** sauber (alles committet und gepusht).
* **CI:** siehe Abschlussnachricht (Lauf für den Endstand).
* **Nicht abgeschlossen:** Bretter einzeln beleben; Framework Stufe 3–4 (Brett-Figuren, Minispiel-Ergebnis, Nitro
  Dash); Strecken deutlich verlängern; Linsentropfen im Split-Screen; Bildraten auf Zielgeräten und im Web-Build;
  Maus/Touch-Bedienung automatisiert prüfen; Spielspaß durch Menschen testen.
* **Empfehlung:** Den Stand als **1.5.2** nach `main` übernehmen, sobald du ihn freigibst – er ist geprüft und
  stabiler als `main`. Davor (oder als erster Schritt für 1.5.3): einmal auf einem echten Smartphone und im Browser
  mit „FPS anzeigen“ spielen (Menü, ein Brett, ein Rennen), und eine kurze Runde mit Menschen für den Spielspaß.
