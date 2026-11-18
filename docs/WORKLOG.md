# Arbeitsdokumentation

Zentrale, fortlaufende Notiz: Stand, Entscheidungen, offene Punkte. Wer hier weiterarbeitet (auch nach einer
Unterbrechung), liest zuerst den obersten Abschnitt. Branch: `claude/elegant-johnson-2kfiut` · `main` bleibt bis zur
Freigabe unverändert.

## 1.5.4 – Premium-Visual-Überarbeitung (Materialsystem, Assets, Audit, Leistung, Fehlerbehebung)

Ausgangsstand `f1e251b5` (1.5.3 + hochgeladene Zips). Bericht: `docs/PREMIUM_VISUAL.md`, Regeln: `docs/VISUAL_STANDARD.md`.

| Schritt (Reihenfolge laut Auftrag) | Status | Ergebnis / Ort |
|---|---|---|
| 1 Status, Sicherung, Vorher-Bilder | fertig | Arbeitskopie des Ausgangsstands (Scratchpad `wt_base`), Vorher-Bilder Menü/Bretter/Strecken/Minispiele mit festen Kameras |
| 2 JulioVII | fertig | 14 kostenlose „Stylized“-Texturpakete (CC BY 4.0), alle intakt; Prüfsummen `data/juliovii_manifest.json`, erneut ladbar `tools/assets/fetch_juliovii.py` |
| 3 GitHub-Assets | fertig | 14 Zips analysiert: 4 Dubletten (byte-gleich), Kenney-Skyboxen/Casino/Icons/Mobile ohne Einsatzort, 4 Zips ohne Lizenzangabe nicht übernommen |
| 4 Pipeline | fertig | `tools/assets/build_surfaces.py` → 25 Familien (512², Gras/Sand 1024²), WebP im Paket (+6,8 MB) |
| 5 Pilot Hauptmenü-Insel | fertig | Sand/Gras, Uferkante, rundere Inseln; drei Zustände mit festen Kameras |
| 6 Materialsystem/Standard | fertig | `LumosMaterials` + `lumos_surface.gdshader`; Modell-Fehlerkorrektur metallic=1 (Nature/Space Kit) |
| 7 Alle Bereiche | fertig | 10 Bretter, 12 Strecken (Boden, Böschung, Felsen), 46 Minispiele + 3 Modi (Böden), 10 Boss-Arenen |
| 8 Leistung | fertig | headless CPU im Rauschen, simuliert (Software-Renderer) Pixelkosten +19/+41/+39 % je Stufe, Fernbereich ohne Normalmap-Zugriff, Web-Paket 42,1 MB (WebP statt S3TC), Bericht D |
| 9 Spiel/Regression | fertig | **Fund: Fahrbahn unter dem Boden** auf 7 Strecken (seit 1.5.3) – behoben in `RaceTrack._lift_below_ground`; alle 12 Strecken und 69 Minispiele geprüft, Schneeball-Duell-Abweichung als Messrauschen belegt (Bericht E.3) |
| 10 Doku | fertig | `docs/PREMIUM_VISUAL.md` (A–F), `docs/VISUAL_STANDARD.md`, Vorher/Nachher-Bilder `docs/screenshots/1.5.4/` |

Funde unterwegs (1.5.4):
* **Compatibility-Renderer rechnet hier ohne Linear-Umrechnung** (Texturen und `source_color`-Uniforms werden nicht
  dekodiert, `tools/dev/srgb_probe.gd`). Die Detail-Normierung erkennt das jetzt selbst (`space_probe`), sonst war alles
  ~30 % zu hell.
* **Kenney Nature Kit (329 Modelle) und Space Kit kamen mit metallic = 1** (glTF-Standardwert) – Bäume, Felsen, Klippen
  wirkten dunkel und spiegelten den Himmel. Behoben beim Laden (`LumosMaterials.normalize_model`).
* **Fahrbahn unter dem Rasen:** `build_path` verteilt den Höhen-Schließfehler über die Runde; seit der Verlängerung lagen
  bis zu 765 m je Runde unter der Bodenkante (Lumos-Ring 58 %, Dschungel 59 %). Jetzt ≤ 9 m (Unterwassertunnel
  ausgenommen), Steigungen unverändert, keine Überschneidungen.
* **Import-Einstellungen der Oberflächen fehlten im Repository** (`.gitignore` schließt `*.import` aus) – CI hätte sie
  verlustfrei importiert (Gras-Albedo 1,06 MB statt 183 KB). Ausnahme für `assets/materials/surfaces/*.import`.
* Schneeball-Duell „festgefahren“ im Sweep höher – Ursache: Hitstop in echter Zeit während des Schnellvorlaufs
  (lastabhängig); unter gleicher Last und in Echtzeit kein nachweisbarer Unterschied, Kollisionswelt identisch.
* `tools/dev/race_shot.gd` liefert seit 1.5.x keine Bilder mehr (bleibt ohne Fehlermeldung stehen) – ersetzt durch
  `tools/dev/track_shot.gd` (feste Kameras, Startweg wie der CI-Linsentest). `board_life_shot.gd` beendet sich jetzt
  selbst und hat eine feste Nah-Ansicht (`--views=nah`).

## 1.5.3 – Release-Nachträge, Character-Framework-Stufe „1.6“, Universe Polish

Versionsnummer: **1.5.3** (die Framework-Stufe heißt im Auftrag „1.6“ – das ist nur der Arbeitstitel, keine Version).

| Schritt (Reihenfolge laut Auftrag) | Status | Ergebnis / Ort |
|---|---|---|
| 1 PR für die Nachträge | fertig, **wartet auf Freigabe** | PR #4 `claude/release-1.5.2-nachtraege` (`7a07d1b5`, `6164e5ae`) → `main`; CI-Lauf 44147956385 (PR-Ereignis) grün, Vercel-Vorschau grün; nicht gemergt |
| 2 Mund an der Gesichtsoberfläche | fertig (Code + Messung) | `LumosFace`: jeder Mund-Punkt einzeln auf die Haut (Tiefenraster, Normale je Punkt), weiche Grenzen an Kinn/Nase/Schnurrbart/Wange/Ausrüstung; vorher bis 0,45 Kopfbreiten vor bzw. 0,134 in der Haut, jetzt ≤ 0,032 / ≥ −0,009 |
| 3 Verdeckung (Bart, Helm, Visier, Maske, Brille, Hut …) | fertig (Code + Labortests) | neue Klasse `LumosAppearance`; Kapuzen-Schurke: Mund unter der Maske ausgeblendet (vorher Zähne unter der Maske); Hände weichen Helm/Hut/Maske aus |
| 4 CharLab | fertig (Referenzbilder 6 Helden folgen zum Abschluss) | `tools/charlab/face_lab.gd` (`--lab-face`): Kompatibilität, Mund an der Haut, Ausrüstungstests, Hände in Ausrüstung, Referenzbilder, PASS/FAIL |
| 5 Leistung + Integration | fertig | PerfLab alter/neuer Stand: Gesicht zeichnen 3,21 → 3,19 ms (16 Figuren, Szenario F) |
| 6 Framework je Bereich | fertig | Brett (mit Körper), Minispiele und Nitro Dash (nur Gesicht), eigene Schalter; je Szene ≈ +0,5 bis +1 ms CPU |
| 7 Bretter einzeln beleben | fertig | `scripts/party/board_life.gd`; je Brett 0 bis +0,6 ms; Kontrollbilder `tools/dev/board_life_shot.gd` |
| 8 Strecken verlängern | fertig | +13 % bis +49 %; Fahrtest 12/12 alle im Ziel; Rundenzeiten vorher/nachher in `docs/ABSCHLUSS_1.5.3.md` |
| 9 Linsentropfen im Split-Screen | fertig | je Ansicht eigene Linse; Test `tools/dev/lens_split_test.gd` (CI) |
| 10 Geräte-FPS-Testplan | Plan fertig, keine Geräte verfügbar | `docs/GERAETE_TESTPLAN.md`; simulierte Web-Messung (SwiftShader, 1×/4×) in `docs/ABSCHLUSS_1.5.3.md` F |
| 11 Regression, CI, Doku A–G | lokal fertig, CI auf dem Endstand läuft | `docs/ABSCHLUSS_1.5.3.md` (A–G); lokal: Check, Systemtests, Item-Regeln, Fahrtest 12/12, Verhaltenslabor 98/98, Gesichts-Labor 6/6, Linsen-Test, Langzeit-Test, Menü-Agent (Tastatur, Controller, Smartphone, Tablet), Spieler-Agent (5 Minispiele, 32 Läufe, 0 Skriptfehler), Trailer-Trennung |

Funde unterwegs (1.5.3):
* **Wackel-Physik (seit 1.5.2):** Zubehör wurde am ganzen Teilnamen erkannt – „RogueHooded_…“ enthält „hood“, also
  wippten beim Kapuzen-Schurken *alle acht* Teile wie ein Hut (Kopf, Beine, Arme, Körper, Maske, Umhang). Jetzt zählt
  nur der Teilname nach dem Modell-Präfix (`lumos_body.gd`).
* Die neue Labor-Zählung „kopf_starr = 0“ für den Kapuzen-Schurken war genau diese Folge (Kopf-Mesh an eine Feder
  umgehängt), kein Modellfehler; alle sechs Helden hängen zu 100 % am Kopfknochen.
* Das Gesicht folgt jetzt dem Knochen, an dem die Gesichtshaut tatsächlich hängt (nicht fest „head“).


## 1.5.2 – Qualitätsdurchlauf („Full Universe Polish“)

### Stand

| Paket | Status | Ergebnis / Ort |
|---|---|---|
| A – 1.5.2 finalisieren (Profiling, Optimierung, Stresstests, Trailer ohne Durchdringung) | fertig | Commits `a9cea90b`, `bc2a005d`; CI-Lauf 49 auf dem Branch grün; `docs/CHARACTER_FRAMEWORK.md` |
| B0 – Projektinventar | fertig | `tools/dev/inventory.gd` → `data/project_inventory.json` |
| B1 – Player-Agent | fertig | `tools/dev/player_agent.gd`, `player_agent.sh`, `agent_report.py` |
| B2 – alle Minispiele einzeln | fertig (automatisch gespielt; Funde behoben) | `docs/PLAYTEST.md` |
| B3 – Nitro Dash | Ereignisse, Rückgeraden, Wasser fertig; Fahrtest 12/12 sauber | CHANGELOG „Qualitätsdurchlauf“ |
| B4 – Bretter | nur Dauertest je Brett (5 Runden) + Deko-Prüfung, keine Überarbeitung | Scratch-Protokoll, CI-Soak |
| B5 – Framework im Spiel | Stufen 1–2 eingebaut (Menü-Insel, Siegerehrung); Brett, Minispiele, Nitro Dash offen | `scripts/actor/lumos_game.gd`, `docs/CHARACTER_FRAMEWORK.md` „Einsatz im Spiel“ |
| B6 – UI/UX | fertig für Tastatur/Controller (Menü-Agent, Funde behoben); Maus/Touch nicht automatisiert | `tools/dev/menu_agent.gd`, `docs/PLAYTEST.md` |
| B7 – Technik-Profile je Szene | fertig: 105 Szenen CPU-seitig + 48 mit Render-Zählwerten; Funde behoben (Küchen-Ruckler, Material-Fehler, 2 Engine-Fehler, OBJ-Flächen: Draw-Calls −19 % gesamt, Bretter −28 %); echte Geräte-FPS offen | `tools/dev/scene_profile.sh`, `docs/PERF_SCENES.md` |
| C10 – Trailer 2.0 | Weltenwechsel-Stamm überarbeitet, Neu-Render; kein neuer Storyboard-Umfang | `trailer/README.md` |
| D11 – Abschluss | in Arbeit | |

## Inventar (aus dem Code, nicht aus der Doku)

69 Minispiele (alle mit Szene und Skript; Kategorien: 49 FFA, 23 2v2, 13 Duell, 7 1v3, 5 Münz, 3 Glück, 2 Boss,
1 Koop) · 12 Strecken (987–1180 m je Runde) · 10 Bretter (44–51 Felder, 3–4 Abzweige) · 10 Bosse (je Brett einer) ·
6 Figuren · 4 Party-Modi · Zusatzmodi Koopathlon, Kolosseum, Partyhelfer-Reise, Marathon, Freies Spiel.
Abweichung Doku ↔ Code: README nannte in der Ordnerübersicht noch „38 Minispiele“ (korrigiert).

## Arbeitsweise

* Tests nie abschwächen. Jede Änderung: `Check.tscn`, betroffene Tests, Player-Agent für das Spiel, dann Commit.
* Befehle: siehe `docs/PLAYTEST.md` (Agent) und `docs/CHARACTER_FRAMEWORK.md` (Lab, PerfLab).
* Trailer: erst Beat-Vorschauen (`--trailer-from/--trailer-to`), dann `ClearanceProbe`, dann Voll-Render.

## Entscheidungen und offene Punkte

(fortlaufend ergänzt)

* Nächste sinnvolle Schritte: (1) ~~Menü-Durchlauf~~ erledigt (Menü-Agent), (1b) Bildraten auf echten Geräten und
  im Web-Build messen (`tools/dev/web_perf.js`, „FPS anzeigen“), (2) Strecken wirklich verlängern (zweite Schleife je Strecke; Baukasten und Überschneidungs-Prüfung sind
  da), (3) Linsentropfen in `SplitView`, (4) Bretter einzeln beleben, (5) Framework Stufe 3 (Brett-Figuren ab Szenenstart, Minispiel-Ergebnis).
* Agent-Befunde, die bewusst blieben: Rempelkugeln/Kart-Kegeln/Eisschollen – Tastatur-Agent schwächer als Analog-CPU
  (kein Fehler); Pinguin-Curling – der automatische Wurf eines Abwesenden kann Punkte bringen (gewollt mittelmäßig).
