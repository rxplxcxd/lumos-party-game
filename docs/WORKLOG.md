# Arbeitsdokumentation – Qualitätsdurchlauf 1.5.2 („Full Universe Polish“)

Zentrale, fortlaufende Notiz: Stand, Entscheidungen, offene Punkte. Wer hier weiterarbeitet (auch nach einer
Unterbrechung), liest zuerst diesen Abschnitt. Branch: `claude/elegant-johnson-2kfiut` · `main` bleibt bis zur
Freigabe unverändert.

## Stand

| Paket | Status | Ergebnis / Ort |
|---|---|---|
| A – 1.5.2 finalisieren (Profiling, Optimierung, Stresstests, Trailer ohne Durchdringung) | fertig | Commits `a9cea90b`, `bc2a005d`; CI-Lauf 49 auf dem Branch grün; `docs/CHARACTER_FRAMEWORK.md` |
| B0 – Projektinventar | fertig | `tools/dev/inventory.gd` → `data/project_inventory.json` |
| B1 – Player-Agent | fertig | `tools/dev/player_agent.gd`, `player_agent.sh`, `agent_report.py` |
| B2 – alle Minispiele einzeln | fertig (automatisch gespielt; Funde behoben) | `docs/PLAYTEST.md` |
| B3 – Nitro Dash | Ereignisse, Rückgeraden, Wasser fertig; Fahrtest 12/12 sauber | CHANGELOG „Qualitätsdurchlauf“ |
| B4 – Bretter | nur Dauertest je Brett (5 Runden) + Deko-Prüfung, keine Überarbeitung | Scratch-Protokoll, CI-Soak |
| B5 – Framework im Spiel | **offen** (nicht eingebaut) | `docs/CHARACTER_FRAMEWORK.md` „Vorbereitung“ |
| B6 – UI/UX | **offen** (kein Menü-Durchlauf des Agenten) | |
| B7 – Technik-Profile je Szene | **offen** (nur Minispiel-Ruckler und Framework gemessen) | |
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

* Nächste sinnvolle Schritte: (1) Agent um Menü-Durchlauf erweitern (Start → Modus → Figur → Spiel → Ergebnis →
  zurück), (2) Strecken wirklich verlängern (zweite Schleife je Strecke; Baukasten und Überschneidungs-Prüfung sind
  da), (3) Linsentropfen in `SplitView`, (4) Bretter einzeln beleben, (5) Framework in Sieges-/Ergebnisszenen.
* Agent-Befunde, die bewusst blieben: Rempelkugeln/Kart-Kegeln/Eisschollen – Tastatur-Agent schwächer als Analog-CPU
  (kein Fehler); Pinguin-Curling – der automatische Wurf eines Abwesenden kann Punkte bringen (gewollt mittelmäßig).
