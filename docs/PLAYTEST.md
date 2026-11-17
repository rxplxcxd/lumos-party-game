# Spielertest aller Minispiele (Lumos Player Agent)

Der Agent spielt jedes der 69 Minispiele als **Mensch auf Platz 1 über echte Tastatur-Ereignisse**
(`Input.parse_input_event` → `InputHub` → Spiel – derselbe Weg wie am Gerät), die anderen Plätze sind CPU-Gegner.

```bash
bash tools/dev/player_agent.sh build/agent 4
```

```bash
python3 tools/dev/agent_report.py build/agent --md=build/agent/report.md
```

Einzelnes Spiel: `./godot --headless --fixed-fps 60 --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/player_agent.gd --only=stomp_waves --strategy=mimic`

## Strategien

| Strategie | Was sie prüft |
|---|---|
| `mimic` (klug) | spielt mit dem Verstand der CPU des Spiels, aber über die Tastatur (8 Richtungen, feines Zielen getippt); für Spiele mit interner CPU-Logik (Schlafwandler, Schläfrige Sterne) liest der Agent die Ansage und schnippt die Richtung. In **jeder** Kategorie des Spiels, erste Kategorie mit zwei Startwerten |
| `idle` (abwesend) | fasst nichts an: Das Spiel muss sauber enden, Nichtstun darf nicht gewinnen, niemand darf blockiert werden |
| `random` | zufällige Richtungen und Tasten: nichts darf abstürzen oder hängen |
| `mash` | läuft Kreise und hämmert A/B/X/Y |

Gemessen je Lauf: Ende, Spielzeit, Platz und Punkte, Weg der Figur, Reaktion der Figur auf die erste Eingabe (Bilder),
längstes Einzelbild (CPU), Modelle, die erst mitten im Spiel geladen werden, Objektzuwachs, Skriptfehler, ob Erklärung
und Ergebnis mit A weitergehen.

## Teststufen (ehrlich)

* **Automatisch vollständig gespielt:** alle 69 Spiele, 379 Läufe (alle Kategorien × Strategien), 0 Skriptfehler, alle
  enden sauber, alle Ergebnisbildschirme lassen sich mit A verlassen.
* **Nur teilweise aussagekräftig:** Bei Spielen, in denen Tastatur-Präzision nicht an den Analogstick heranreicht
  (z. B. Minigolf, Kart-Kegeln, Rempelkugeln), sagt der Platz des Agenten wenig über die Balance.
* **Nicht automatisch geprüft:** Spielspaß, Lesbarkeit, Optik (dafür Kontrollbilder), Gamepad- und Touch-Eingabe
  (der Agent nutzt die Tastatur; die Zuordnung prüft `tools/validate_controls.py`), Online-Spiel (eigene Tests).

## Funde und Korrekturen aus dem ersten Durchlauf

| Spiel | Fund | Korrektur |
|---|---|---|
| Stampf-Wellen | **Kernmechanik defekt:** Ein Stampfer erzeugte nie eine Welle (Landung wurde über die Fallgeschwindigkeit erkannt, die am Boden 0 ist). Folge: 0 Treffer, niemand schied aus, fast immer Vierfach-Gleichstand | Landung = wieder am Boden nach dem Abheben; Bühne schrumpft zweimal mit Vorwarnung; CPU stampft öfter. Jetzt 11–24 Treffer je Partie, klare Platzierungen |
| Kürbis-Weitwurf | CPU drehte den Stick nach Echtzeit-Uhr: im Zeitraffer (und bei Zeitlupe) baute sie keinen Schwung auf, alle 0 Punkte | Spielzeit (`MinigameBase.clock`) |
| Geisterschloss, Wolkenboss | Bahnen von Geistern bzw. Boss liefen nach Echtzeit-Uhr – nach einer Pause sprangen sie | Spielzeit |
| Pinguin-Curling, Schatz-Schnüffeln, Stein-Kegeln | ein abwesender Mensch blockierte die Runde endlos bzw. bis zum Zeitlimit | Zug-Zeitbegrenzung (`turn_timed_out`: 15–20 s ohne Eingabe, Countdown in den letzten 5 s, dann zieht das Spiel) |
| 18 Spiele | Modelle (Münzen, Geschosse, Sammelobjekte) wurden erst beim ersten Auftauchen geladen: Ruckler bis 448 ms | Vorabladen beim Aufbau (`MinigameBase.WARM_MODELS`, `Assets.warm`) |
| Test-Infrastruktur | 2 von 379 Engine-Abstürzen beim parallelen Start (Signal 11 vor Spielbeginn, nicht spielbedingt) | Treiber wiederholt einmal |

## Funde aus dem Szenen-Profil (dritter Durchlauf) und Nachprüfung

Das Leistungsprofil aller Szenen (`docs/PERF_SCENES.md`) fing Engine-Fehlermeldungen und Ruckler mit, die der
Spieler-Agent nicht als Fehler zählte (keine Skriptfehler):

| Spiel | Fund | Korrektur |
|---|---|---|
| Rhythmus-Küche | Ruck bis 292 ms beim Wechsel in den 2. Gang: der Song des Gangs kam erst dann von der Platte (bei warmem Datei-Cache nur ≈ 10 ms, darum nicht immer sichtbar) | alle Gänge laden beim Start im Hintergrund vor; jedes Minispiel lädt Hurry-Up und Outro vor |
| Lava-Surfen, Farb-Chaos, Wolkenboss, Ballon-Schlacht | „material is null“ bei jedem eingesammelten Edelstein, geplatzten Ballon u. Ä. – Godot 4.7 gibt eingefärbte Override-Materialien vor der Render-Instanz frei (isoliert nachgestellt: 5 von 5 Löschungen) | `Assets.keep_material`: Material als Metadaten bis zum Schluss gehalten (0 von 5) |
| Achterbahn-Schießbude | Minispiel-Intro: Kanone zielt mit Nullvektor (steht genau über der Arenamitte) | feste Richtung als Rückfall |
| Ballon-Schlacht | Slapstick-Modifier invertierte die Skelett-Basis einer auf Größe 0 geschrumpften Figur (Fehler je Bild) | übersprungen, solange die Figur unsichtbar klein ist |

Nachprüfung mit dem Spieler-Agenten: diese sechs Spiele in 33 Läufen (alle Kategorien × Strategien) vollständig
gespielt, alle enden sauber, 0 Skriptfehler, 0 Engine-Fehler während des Spiels (übrig sind nur die üblichen
Speicher-Zusammenfassungen beim Beenden des Testprozesses).

## Ergebnis je Minispiel (zweiter Durchlauf, nach den Korrekturen)

Platz = Platz des Agenten (1 = gewonnen), gemittelt. „Auffälligkeiten“ stammen aus dem Lauf **vor** dem Vorabladen
der Modelle (das ist seither behoben und an Stichproben nachgeprüft).


| Minispiel | Kategorien (gespielt) | Platz klug | AFK | Zufall | Masher | Reaktion (Bilder) | längstes Bild ms | Teststufe | Auffälligkeiten |
|---|---|---|---|---|---|---|---|---|---|
| Plank-Panic (`plank_panic`) | ffa/2v2 (2v2/ffa) | 2.3 | 3.0 | 4.0 | 4.0 | 2 | 115 | vollständig gespielt | Bildspitze 115 ms (bei 3.4 s) |
| Dungeon Drop (`dungeon_drop`) | ffa/2v2/duel (2v2/duel/ffa) | 2.5 | 4.0 | 4.0 | 4.0 | 2 | 23 | vollständig gespielt |  |
| Kart-Bowling (`kart_bowling`) | ffa/2v2 (2v2/ffa) | 2.3 | 4.0 | 4.0 | 3.0 | – | 21 | vollständig gespielt | lädt mitten im Spiel nach: td/boulder |
| Schatz-Seilbahn (`treasure_zipline`) | ffa/2v2 (2v2/ffa) | 1.3 | 4.0 | 4.0 | 3.0 | – | 21 | vollständig gespielt | lädt mitten im Spiel nach: bg/coin_gold |
| Geister-Schloss Schwindel (`ghost_castle`) | ffa/2v2/duel (2v2/duel/ffa) | 1.8 | 4.0 | 4.0 | 4.0 | 2 | 24 | vollständig gespielt |  |
| Fässer-Chaos (`barrel_chaos`) | ffa/2v2 (2v2/ffa) | 1.7 | 4.0 | 3.0 | 4.0 | 2 | 24 | vollständig gespielt | lädt mitten im Spiel nach: bg/coin_gold, dun/coin_stack |
| Lavastrom-Surfen (`lava_surf`) | ffa/2v2 (2v2/ffa) | 2.0 | 4.0 | 4.0 | 3.0 | – | 24 | vollständig gespielt | lädt mitten im Spiel nach: mg/diamond, mg/ring, pirate/rocks_a, td/rocks |
| Turm-Balancieren (`tower_balance`) | ffa/duel (duel/ffa) | 1.7 | 2.0 | 1.0 | 2.0 | 2 | 19 | vollständig gespielt | lädt mitten im Spiel nach: dun/column, dun/floor_small |
| Bomben-Heißer-Hut (`hot_bomb`) | ffa (ffa) | 1.5 | 4.0 | 3.0 | 4.0 | 2 | 13 | vollständig gespielt |  |
| Schleim-Spur Sprint (`slime_sprint`) | ffa/2v2/duel (2v2/duel/ffa) | 1.2 | 4.0 | 4.0 | 4.0 | 2 | 39 | vollständig gespielt |  |
| Münzregen (`coin_rain`) | coin/ffa/2v2/duel (2v2/coin/duel/ffa) | 1.8 | 4.0 | 4.0 | 4.0 | 2 | 31 | vollständig gespielt | lädt mitten im Spiel nach: mg/powerup_bomb, plat/coin, plat/star |
| Sumo-Schubser (`sumo_shove`) | ffa/2v2/duel (2v2/duel/ffa) | 2.2 | 4.0 | 4.0 | 4.0 | 2 | 15 | vollständig gespielt |  |
| Schneeball-Schlacht (`snowball_fight`) | ffa/2v2 (2v2/ffa) | 2.7 | 4.0 | 4.0 | 4.0 | 2 | 13 | vollständig gespielt | lädt mitten im Spiel nach: hol/snowball |
| Farb-Chaos (`color_chaos`) | ffa/2v2 (2v2/ffa) | 1.7 | 4.0 | 4.0 | 4.0 | 2 | 16 | vollständig gespielt | lädt mitten im Spiel nach: mg/powerup_bomb |
| Hammer-Hüpfen (`hammer_hop`) | ffa/1v3 (1v3/ffa) | 1.3 | 4.0 | 4.0 | 4.0 | 2 | 32 | vollständig gespielt |  |
| Fischfang (`fish_catch`) | ffa/duel/coin (coin/duel/ffa) | 1.8 | 4.0 | 3.0 | 3.0 | – | 25 | vollständig gespielt | lädt mitten im Spiel nach: plat/crate, surv/fish, surv/fish_small |
| Sternschnuppen-Regen (`meteor_dodge`) | ffa/1v3 (1v3/ffa) | 2.0 | 2.0 | 4.0 | 4.0 | 2 | 16 | vollständig gespielt | lädt mitten im Spiel nach: plat/star |
| Rhythmus-Tanz (`rhythm_dance`) | ffa/2v2 (2v2/ffa) | 3.0 | 4.0 | 4.0 | 4.0 | – | 16 | vollständig gespielt |  |
| Minigolf-Duell (`minigolf_duel`) | ffa/duel (duel/ffa) | 2.7 | 4.0 | 4.0 | 4.0 | – | 27 | vollständig gespielt |  |
| Ballon-Kart-Battle (`balloon_battle`) | ffa/2v2 (2v2/ffa) | 1.7 | 3.0 | 2.0 | 3.0 | – | 32 | vollständig gespielt | lädt mitten im Spiel nach: hol/cookie, toy/item_box |
| Blumen-Farbenrausch (`flower_rush`) | ffa (ffa) | 2.5 | 4.0 | 4.0 | 3.0 | 2 | 10 | vollständig gespielt |  |
| Kuschel-Bälle-Hüpfen (`plush_balls`) | ffa (ffa) | 1.0 | 4.0 | 4.0 | 4.0 | 2 | 30 | vollständig gespielt |  |
| Schlummer-Sternchen-Tanz (`sleepy_stars`) | ffa (ffa) | 1.0 | 4.0 | 4.0 | 4.0 | – | 16 | vollständig gespielt |  |
| Kürbis-Weitwurf (`pumpkin_toss`) | ffa/duel (duel/ffa) | 3.3 | 4.0 | 4.0 | 4.0 | – | 15 | vollständig gespielt |  |
| Seilziehen am Pilzbach (`tug_of_war`) | 1v3/2v2 (1v3/2v2) | 2.0 | 2.0 | 2.0 | 2.0 | – | 10 | vollständig gespielt |  |
| Honigbären-Flucht (`honey_chase`) | 1v3 (1v3) | 2.0 | 2.0 | 2.0 | 2.0 | – | 9 | vollständig gespielt |  |
| Baumhöhlen-Versteck (`hollow_hide`) | 1v3 (1v3) | 2.0 | 2.0 | 2.0 | 2.0 | – | 10 | vollständig gespielt |  |
| Schienen-Express (`rail_express`) | 2v2 (2v2) | 2.0 | 2.0 | 2.0 | 2.0 | – | 18 | vollständig gespielt |  |
| Sternen-Korbschlacht (`star_hoops`) | 2v2 (2v2) | 1.5 | 2.0 | 2.0 | 2.0 | 2 | 23 | vollständig gespielt | lädt mitten im Spiel nach: plat/star |
| Glücks-Glöckchen (`lucky_bells`) | luck/coin/ffa (coin/ffa/luck) | 3.2 | 4.0 | 3.0 | 3.0 | – | 17 | vollständig gespielt | lädt mitten im Spiel nach: bg/coin_gold |
| Schatzkisten-Schnüffeln (`chest_sniff`) | luck/ffa (ffa/luck) | 2.3 | 3.0 | 1.0 | 4.0 | – | 15 | vollständig gespielt | lädt mitten im Spiel nach: bg/coin_gold |
| Boss-Kampf (`boss_battle`) | boss (boss) | 2.0 | 4.0 | 4.0 | 4.0 | 2 | 17 | vollständig gespielt | lädt mitten im Spiel nach: bg/coin_gold |
| Boss: Pustebacke, der Wolkendrache (`boss_cloud`) | boss (boss) | 1.0 | 4.0 | 4.0 | 4.0 | 2 | 10 | vollständig gespielt | lädt mitten im Spiel nach: plat/coin |
| Geister-Fotograf (`ghost_photo`) | ffa (ffa) | 2.5 | 4.0 | 4.0 | 4.0 | 2 | 26 | vollständig gespielt | lädt mitten im Spiel nach: bg/coin_gold |
| Käse-Kloppe (`cheese_brawl`) | ffa (ffa) | 2.0 | 3.0 | 4.0 | 3.0 | 2 | 36 | vollständig gespielt |  |
| Pinguin-Curling (`penguin_curling`) | ffa (ffa) | 2.5 | 2.0 | 4.0 | 3.0 | – | 15 | vollständig gespielt | klug (2.5) schlechter als Nichtstun (2.0) |
| Seifenblasen-Ballett (`bubble_ballet`) | ffa (ffa) | 1.0 | 4.0 | 4.0 | 4.0 | – | 12 | vollständig gespielt |  |
| Schlafwandler-Parcours (`sleepwalk`) | ffa (ffa) | 1.0 | 4.0 | 4.0 | 4.0 | – | 15 | vollständig gespielt |  |
| Rhythmus-Küche (`rhythm_kitchen`) | coop (coop) | 1.5 | 1.0 | 1.0 | 1.0 | – | 22 | vollständig gespielt |  |
| Kugel-Karambolage (`bumper_balls`) | ffa (ffa) | 2.0 | 3.0 | 4.0 | 4.0 | – | 10 | vollständig gespielt |  |
| Wackelsteg-Wirbel (`log_bridge`) | ffa (ffa) | 3.0 | 4.0 | 4.0 | 4.0 | 2 | 19 | vollständig gespielt |  |
| Funken-Karussell (`spark_carousel`) | ffa (ffa) | 1.5 | 4.0 | 4.0 | 4.0 | 3 | 11 | vollständig gespielt |  |
| Sandwich-Sturm (`sandwich_storm`) | ffa (ffa) | 3.0 | 4.0 | 4.0 | 4.0 | 2 | 26 | vollständig gespielt |  |
| Stampf-Wellen (`stomp_waves`) | ffa (ffa) | 1.5 | 4.0 | 4.0 | 4.0 | 2 | 22 | vollständig gespielt |  |
| Kullerfels-Flucht (`boulder_run`) | ffa (ffa) | 3.5 | 4.0 | 4.0 | 4.0 | 2 | 16 | vollständig gespielt |  |
| Eisschollen-Sturm (`ice_floes`) | ffa (ffa) | 3.5 | 2.0 | 4.0 | 4.0 | 4 | 13 | vollständig gespielt | klug (3.5) schlechter als Nichtstun (2.0) |
| Nagel-Profi (`nail_pro`) | ffa (ffa) | 4.0 | 4.0 | 4.0 | 4.0 | – | 11 | vollständig gespielt |  |
| Raketen-Rucksack-Rallye (`jetpack_rally`) | ffa (ffa) | 3.0 | 4.0 | 4.0 | 4.0 | 2 | 11 | vollständig gespielt |  |
| Schlitten an der Kante (`sled_edge`) | ffa (ffa) | 2.0 | 4.0 | 4.0 | 3.0 | – | 13 | vollständig gespielt |  |
| Eislauf-Münzjagd (`ice_coins`) | coin/ffa (coin/ffa) | 2.7 | 4.0 | 4.0 | 4.0 | 4 | 30 | vollständig gespielt |  |
| Spitzhacken-Spurt (`pickaxe_dash`) | ffa (ffa) | 1.0 | 4.0 | 4.0 | 4.0 | – | 24 | vollständig gespielt |  |
| Blockpfad-Poker (`bridge_bluff`) | ffa (ffa) | 2.0 | 3.0 | 4.0 | 3.0 | 2 | 15 | vollständig gespielt |  |
| UFO-Kaperung (`ufo_heist`) | 1v3 (1v3) | 1.0 | 2.0 | 2.0 | 2.0 | – | 9 | vollständig gespielt |  |
| Schalter-Schikane (`switch_gauntlet`) | 1v3 (1v3) | 2.0 | 2.0 | 2.0 | 2.0 | – | 12 | vollständig gespielt | lädt mitten im Spiel nach: plat/barrel |
| Bomben-Entschärfung (`bomb_defuse`) | 2v2 (2v2) | 1.0 | 2.0 | 1.0 | 1.0 | 2 | 14 | vollständig gespielt | lädt mitten im Spiel nach: qp/bomb |
| Taxi-Koordinaten (`axis_taxi`) | 2v2 (2v2) | 2.0 | 2.0 | 1.0 | 2.0 | – | 17 | vollständig gespielt |  |
| Karten-Match (`memory_match`) | 2v2 (2v2) | 1.5 | 2.0 | 2.0 | 2.0 | – | 13 | vollständig gespielt |  |
| Strand-Volley (`beach_volley`) | 2v2 (2v2) | 1.5 | 2.0 | 2.0 | 2.0 | 2 | 14 | vollständig gespielt |  |
| Tretboot-Rennen (`pedal_boat`) | 2v2 (2v2) | 1.0 | 2.0 | 2.0 | 2.0 | – | 12 | vollständig gespielt |  |
| Gemüse-Ernte (`veggie_harvest`) | 2v2 (2v2) | 1.0 | 2.0 | 2.0 | 2.0 | 2 | 13 | vollständig gespielt |  |
| Schnell-Angler (`quick_fishing`) | duel (duel) | 1.5 | 2.0 | 2.0 | 2.0 | – | 14 | vollständig gespielt | lädt mitten im Spiel nach: surv/fish |
| Klatsch-Karussell (`slap_carousel`) | duel (duel) | 1.5 | 2.0 | 2.0 | 2.0 | 2 | 11 | vollständig gespielt |  |
| Murmel-Labyrinth (`marble_maze`) | duel (duel) | 1.0 | 2.0 | 1.0 | 2.0 | – | 8 | vollständig gespielt |  |
| Steinkopf-Kegeln (`stone_bowling`) | duel (duel) | 1.0 | 2.0 | 2.0 | 2.0 | – | 15 | vollständig gespielt |  |
| Mega-Summser (`mega_bee`) | ffa (ffa) | 1.5 | 4.0 | 4.0 | 4.0 | 2 | 12 | vollständig gespielt |  |
| Kullerkasten (`prize_drop`) | luck/coin/ffa (coin/ffa/luck) | 2.8 | 4.0 | 1.0 | 1.0 | – | 9 | vollständig gespielt |  |
| Achterbahn-Schießbude (`coaster_shooter`) | ffa (ffa) | 1.0 | 4.0 | 2.0 | 4.0 | – | 11 | vollständig gespielt |  |
| Flitzestein-Wurf (`stone_skip`) | ffa (ffa) | 2.5 | 4.0 | 4.0 | 4.0 | – | 14 | vollständig gespielt |  |
| Spukvilla-Sprint (`ghost_manor`) | ffa (ffa) | 1.5 | 4.0 | 4.0 | 3.0 | 2 | 6 | vollständig gespielt |  |

## Menü-Agent (Bedienung ohne Maus und Touch)

`tools/dev/menu_agent.gd` bedient das Menü ausschließlich über echte Ereignisse (`Input.parse_input_event`):
Pfeiltasten/Enter/Esc bzw. Steuerkreuz/A/B. Engine-Fehler schneidet ein eigener `Logger` je Seite und Ablauf mit.

```bash
godot --headless --fixed-fps 60 --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/menu_agent.gd
```

Schalter: `--pad` (Controller statt Tastatur), `--size=1560x720` (Bildformat; headless hat sonst 1280×1280),
`--pages-only` (ohne Spielabläufe), `--trace` (Tastenwege bei Abweichungen), `--paths` (Tastenwege je Seite).

Je Seite: Ankunft und Erst-Fokus · Fokus-Breitensuche mit allen vier Richtungen (Regler, Wert-Stepper und Textfelder
nur hoch/runter) – jedes Bedienelement muss erreichbar sein · Fallen (keine Richtung führt heraus) · fokussiertes
Element nicht ganz im Bild/Scroll-Ausschnitt · Text über Bildschirm- oder Scroll-Rand · Abbrechen und „Zurück“
führen zur erwarteten Seite · Fokus-Rückkehr auf den Eintrag, über den man kam · Elemente ohne zugänglichen Namen.
Abläufe: Brett, Rennen, Minispiel, Zufall, Marathon, Partyhelfer-Reise, Rhythmus-Küche, Athlon, Wolkenturm,
Kolosseum jeweils Start → 4 s Spiel → Pause → „Zum Hauptmenü“ (zweimal bestätigen) → Hauptseite mit Fokus,
nicht pausiert; außerdem ein freies Minispiel bis zum Ende → Ergebnis → Auswahl → Abbrechen → Hauptseite.

| Durchlauf | Seiten | Befunde | Abläufe |
|---|---|---|---|
| Tastatur 1280×720, vor den Korrekturen | 8 erreicht (Einstellungen per Tastenweg nicht verlässlich) | Fokus-Falle im Raumcode-Feld, 3–8 Kacheln halb außerhalb (bis 62 px), seitliche Sprünge, keine zugänglichen Namen | – |
| Tastatur 1280×720 | 10 | 0 | 11/11 |
| Controller 1280×720 | 10 | 0 | – |
| Smartphone quer 2340×1080 (sichtbar 1560×720) | 10 | 0 | – |
| Tablet 4:3 (1280×960) | 10 | 0 | – |

Nicht abgedeckt: Maus und Touch (Klickflächen, Ziehen im Touch-Layout), Bildschirmleser selbst (nur geprüft, dass
jedes Element einen Namen hat), Online-Räume mit echter Verbindung.
