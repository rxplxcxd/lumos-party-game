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
| B2 – alle Minispiele einzeln | in Arbeit | `docs/PLAYTEST.md` |
| B3 – Nitro Dash | offen | |
| B4–B8 – Bretter, UI, Framework im Spiel, Technik | offen | |
| C10 – Trailer 2.0 | offen | |
| D11 – Abschluss | offen | |

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
