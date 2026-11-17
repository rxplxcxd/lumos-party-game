# Leistungsprofil je Szene

Erzeugt mit `tools/dev/scene_profile.sh` und `tools/dev/profile_report.py`. Jede Szene startet wie im Spiel über den Router, alle Plätze CPU; gemessen wird nach der Aufbauphase (Minispiele ab Spielbeginn bis zum Ende, Bretter 40 s, Strecken 45 s, Menü und Modi 20 s Spielzeit).

**Was die Zahlen bedeuten (ehrlich):**

* *CPU-ms* = Wanduhr je Bild im Headless-Betrieb (Dummy-Renderer): Skripte, Physik, Animation, Szenenbaum, Audio. **Die Grafikkarte ist darin nicht enthalten.** Gemessen auf dem Server-Prozessor der Testumgebung; auf Smartphones und im Web (WebAssembly) ist die CPU-Seite ein Mehrfaches teurer.
* *1 %-Tief* = Mittel der langsamsten 1 % der Bilder (als ms). *> 33 ms* = Bilder, die auch auf schneller Hardware als Ruckler sichtbar wären.
* *Draw-Calls / Primitive / Videospeicher* stammen aus einem zweiten Lauf mit echtem OpenGL-Renderer (Mesa llvmpipe unter xvfb). Dessen Bildzeiten sind Software-Rasterung und **keine** FPS-Aussage für echte Geräte; die Zählwerte gelten aber genauso auf jeder GPU.
* Echte Bildraten (GPU, Web-Build, Akku) müssen auf den Zielgeräten gemessen werden – im Spiel über „FPS anzeigen“ bzw. `--perf-log`, im Browser mit `tools/dev/web_perf.js`.

## Überblick

| Bereich | Szenen | CPU-ms Mittel (Median / max) | p99 max | schlechtestes Bild | Bilder > 33 ms | Speicher Spitze | Engine-Fehler |
|---|---|---|---|---|---|---|---|
| Menü | 1 | 1.64 / 1.64 | 3.52 | 7.9 ms (menu) | 0 | 184 MB | 0 |
| Bretter | 10 | 0.34 / 0.46 | 2.39 | 32.0 ms (pirates) | 0 | 246 MB | 0 |
| Nitro-Dash-Strecken | 12 | 1.25 / 1.51 | 3.41 | 11.6 ms (jungle_ruins) | 0 | 180 MB | 0 |
| Bosskämpfe | 10 | 1.06 / 1.26 | 3.43 | 11.9 ms (ignis) | 0 | 208 MB | 0 |
| Abenteuer & Modi | 5 | 0.36 / 0.72 | 1.94 | 18.1 ms (colosseum) | 0 | 193 MB | 0 |
| Minispiele | 67 | 0.77 / 1.11 | 7.34 | 29.8 ms (minigolf_duel) | 0 | 215 MB | 0 |

## Menü

| Szene | CPU-ms Mittel | p95 | p99 | 1 %-Tief | Maximum (bei s) | > 16,7 ms | > 33 ms | Speicher MB (Spitze) | Knoten |
|---|---|---|---|---|---|---|---|---|---|
| menu | 1.64 | 2.44 | 3.52 | 4.67 | 7.9 (12.3) | 0.00 % | 0 | 182 (184) | 538 |

## Bretter

| Szene | CPU-ms Mittel | p95 | p99 | 1 %-Tief | Maximum (bei s) | > 16,7 ms | > 33 ms | Speicher MB (Spitze) | Knoten |
|---|---|---|---|---|---|---|---|---|---|
| cake | 0.32 | 0.47 | 1.72 | 3.66 | 7.8 (1.0) | 0.00 % | 0 | 209 (227) | 980 |
| dungeon | 0.28 | 0.37 | 1.60 | 3.73 | 8.7 (1.0) | 0.00 % | 0 | 195 (213) | 1025 |
| frost | 0.34 | 0.45 | 2.39 | 4.31 | 8.3 (1.0) | 0.00 % | 0 | 207 (226) | 978 |
| glowforest | 0.33 | 0.45 | 1.96 | 4.69 | 13.1 (39.0) | 0.00 % | 0 | 200 (230) | 1435 |
| graveyard | 0.35 | 0.48 | 1.52 | 3.69 | 8.6 (1.0) | 0.00 % | 0 | 228 (246) | 1196 |
| meadow | 0.34 | 0.56 | 1.62 | 3.80 | 8.8 (1.0) | 0.00 % | 0 | 203 (223) | 1419 |
| pirates | 0.35 | 0.58 | 2.12 | 5.43 | 32.0 (29.1) | 0.04 % | 0 | 204 (226) | 1101 |
| sky | 0.34 | 0.73 | 1.74 | 4.08 | 9.0 (1.0) | 0.00 % | 0 | 200 (222) | 1067 |
| station | 0.32 | 0.47 | 1.75 | 3.86 | 10.3 (1.0) | 0.00 % | 0 | 196 (214) | 988 |
| tower | 0.46 | 0.87 | 2.28 | 4.67 | 10.4 (1.0) | 0.00 % | 0 | 209 (230) | 2015 |

## Nitro-Dash-Strecken

| Szene | CPU-ms Mittel | p95 | p99 | 1 %-Tief | Maximum (bei s) | > 16,7 ms | > 33 ms | Speicher MB (Spitze) | Knoten |
|---|---|---|---|---|---|---|---|---|---|
| candy_lane | 1.26 | 2.13 | 3.01 | 4.41 | 10.5 (30.3) | 0.00 % | 0 | 175 (180) | 943 |
| city_rally | 1.28 | 2.03 | 2.78 | 3.76 | 7.8 (6.5) | 0.00 % | 0 | 170 (174) | 1327 |
| coral_canal | 1.29 | 2.04 | 2.70 | 4.08 | 11.3 (18.4) | 0.00 % | 0 | 173 (177) | 1108 |
| desert_canyon | 1.19 | 1.87 | 2.37 | 3.31 | 7.6 (6.5) | 0.00 % | 0 | 168 (172) | 1011 |
| falls_gorge | 1.35 | 2.15 | 3.16 | 4.37 | 7.5 (6.5) | 0.00 % | 0 | 167 (171) | 869 |
| frost_peak | 1.23 | 2.19 | 3.41 | 4.42 | 10.1 (41.7) | 0.00 % | 0 | 174 (178) | 839 |
| glow_forest | 1.19 | 1.82 | 2.47 | 3.60 | 7.5 (6.5) | 0.00 % | 0 | 173 (177) | 1136 |
| jungle_ruins | 1.12 | 1.87 | 3.07 | 4.39 | 11.6 (37.9) | 0.00 % | 0 | 175 (180) | 1085 |
| lumos_ring | 1.25 | 2.02 | 3.07 | 4.55 | 10.3 (41.7) | 0.00 % | 0 | 167 (172) | 959 |
| neon_volcano | 1.17 | 1.70 | 2.32 | 3.57 | 7.2 (6.5) | 0.00 % | 0 | 167 (170) | 926 |
| orbit_ring | 1.43 | 2.17 | 3.24 | 5.05 | 11.0 (39.6) | 0.00 % | 0 | 167 (170) | 886 |
| storm_pass | 1.51 | 2.38 | 3.38 | 4.90 | 10.3 (6.5) | 0.00 % | 0 | 167 (173) | 883 |

## Bosskämpfe

| Szene | CPU-ms Mittel | p95 | p99 | 1 %-Tief | Maximum (bei s) | > 16,7 ms | > 33 ms | Speicher MB (Spitze) | Knoten |
|---|---|---|---|---|---|---|---|---|---|
| astraios | 1.04 | 1.63 | 2.67 | 3.66 | 6.5 (0.7) | 0.00 % | 0 | 195 (196) | 571 |
| baahemoth | 1.12 | 1.78 | 3.24 | 3.98 | 6.8 (0.4) | 0.00 % | 0 | 203 (206) | 656 |
| frostbart | 1.26 | 2.04 | 3.43 | 4.83 | 8.1 (2.2) | 0.00 % | 0 | 198 (202) | 642 |
| galaxus | 0.89 | 1.39 | 2.23 | 3.60 | 8.6 (7.7) | 0.00 % | 0 | 200 (203) | 652 |
| grabstein | 1.02 | 1.60 | 2.18 | 3.07 | 6.3 (10.6) | 0.00 % | 0 | 199 (203) | 545 |
| ignis | 1.12 | 1.88 | 3.25 | 4.15 | 11.9 (46.0) | 0.00 % | 0 | 196 (199) | 687 |
| klabautox | 1.09 | 1.85 | 2.75 | 3.44 | 8.2 (3.2) | 0.00 % | 0 | 203 (204) | 634 |
| marquise | 1.03 | 1.61 | 2.60 | 3.75 | 7.8 (0.2) | 0.00 % | 0 | 201 (208) | 695 |
| noxumbra | 1.01 | 1.71 | 2.58 | 3.39 | 5.5 (24.4) | 0.00 % | 0 | 195 (197) | 557 |
| zephyros | 1.17 | 1.88 | 2.98 | 4.05 | 7.7 (35.2) | 0.00 % | 0 | 195 (197) | 575 |

## Abenteuer & Modi

| Szene | CPU-ms Mittel | p95 | p99 | 1 %-Tief | Maximum (bei s) | > 16,7 ms | > 33 ms | Speicher MB (Spitze) | Knoten |
|---|---|---|---|---|---|---|---|---|---|
| athlon | 0.16 | 0.19 | 0.33 | 2.62 | 6.9 (17.6) | 0.00 % | 0 | 165 (169) | 697 |
| colosseum | 0.36 | 0.53 | 1.65 | 4.20 | 18.1 (13.2) | 0.08 % | 0 | 104 (108) | 887 |
| journey | 0.55 | 0.84 | 0.99 | 1.05 | 1.1 (5.0) | 0.00 % | 0 | 112 (112) | 675 |
| kitchen | 0.72 | 1.17 | 1.94 | 3.61 | 7.5 (0.0) | 0.00 % | 0 | 192 (193) | 675 |
| marathon | 0.08 | 0.12 | 0.14 | 0.38 | 1.2 (0.2) | 0.00 % | 0 | 117 (129) | 384 |

## Minispiele

| Szene | CPU-ms Mittel | p95 | p99 | 1 %-Tief | Maximum (bei s) | > 16,7 ms | > 33 ms | Speicher MB (Spitze) | Knoten |
|---|---|---|---|---|---|---|---|---|---|
| axis_taxi | 0.71 | 1.17 | 1.91 | 2.65 | 5.0 (5.1) | 0.00 % | 0 | 200 (201) | 631 |
| balloon_battle | 0.62 | 1.28 | 2.64 | 4.13 | 6.6 (5.4) | 0.00 % | 0 | 197 (198) | 733 |
| barrel_chaos | 0.67 | 1.07 | 2.08 | 3.25 | 9.7 (3.5) | 0.00 % | 0 | 207 (210) | 485 |
| beach_volley | 0.82 | 1.41 | 2.34 | 3.33 | 12.5 (5.6) | 0.00 % | 0 | 203 (205) | 564 |
| bomb_defuse | 0.87 | 1.45 | 2.62 | 3.33 | 5.7 (8.9) | 0.00 % | 0 | 177 (178) | 446 |
| boss_cloud | 0.91 | 1.47 | 2.24 | 4.02 | 13.6 (8.2) | 0.00 % | 0 | 195 (207) | 450 |
| boulder_run | 1.07 | 2.13 | 3.18 | 4.29 | 7.8 (1.9) | 0.00 % | 0 | 179 (184) | 454 |
| bridge_bluff | 0.62 | 1.08 | 1.91 | 3.42 | 12.3 (2.5) | 0.00 % | 0 | 205 (215) | 496 |
| bubble_ballet | 0.85 | 1.34 | 1.73 | 2.13 | 3.3 (25.9) | 0.00 % | 0 | 173 (173) | 436 |
| bumper_balls | 0.65 | 1.09 | 1.72 | 2.40 | 8.0 (27.6) | 0.00 % | 0 | 178 (179) | 420 |
| cheese_brawl | 0.93 | 1.45 | 4.29 | 4.63 | 5.6 (4.4) | 0.00 % | 0 | 174 (175) | 555 |
| chest_sniff | 0.40 | 0.76 | 1.85 | 2.65 | 6.1 (3.2) | 0.00 % | 0 | 194 (195) | 500 |
| coaster_shooter | 0.62 | 1.02 | 1.63 | 2.37 | 4.0 (1.0) | 0.00 % | 0 | 188 (188) | 897 |
| coin_rain | 0.97 | 1.83 | 2.98 | 3.72 | 5.8 (2.5) | 0.00 % | 0 | 196 (197) | 518 |
| color_chaos | 0.91 | 1.55 | 2.46 | 3.53 | 7.7 (31.7) | 0.00 % | 0 | 186 (187) | 673 |
| dungeon_drop | 1.04 | 1.84 | 2.72 | 3.75 | 8.0 (11.4) | 0.00 % | 0 | 178 (179) | 693 |
| fish_catch | 0.41 | 0.69 | 1.60 | 2.24 | 6.0 (3.0) | 0.00 % | 0 | 188 (189) | 633 |
| flower_rush | 0.78 | 1.11 | 1.82 | 3.12 | 5.9 (0.5) | 0.00 % | 0 | 185 (186) | 625 |
| ghost_castle | 0.78 | 1.20 | 1.75 | 2.71 | 7.8 (10.1) | 0.00 % | 0 | 188 (189) | 629 |
| ghost_manor | 0.93 | 1.47 | 3.14 | 3.24 | 3.3 (1.5) | 0.00 % | 0 | 176 (177) | 631 |
| ghost_photo | 0.87 | 1.30 | 2.96 | 3.73 | 5.3 (16.1) | 0.00 % | 0 | 193 (193) | 584 |
| hammer_hop | 0.61 | 0.94 | 2.01 | 2.75 | 9.5 (20.7) | 0.00 % | 0 | 179 (184) | 412 |
| hollow_hide | 0.31 | 0.59 | 1.01 | 2.15 | 8.4 (4.6) | 0.00 % | 0 | 204 (210) | 517 |
| honey_chase | 0.58 | 0.87 | 3.33 | 3.33 | 3.3 (0.6) | 0.00 % | 0 | 179 (179) | 524 |
| hot_bomb | 0.86 | 1.45 | 2.18 | 3.26 | 9.7 (9.5) | 0.00 % | 0 | 179 (179) | 622 |
| ice_coins | 0.84 | 1.63 | 2.91 | 3.53 | 4.7 (32.5) | 0.00 % | 0 | 184 (184) | 486 |
| ice_floes | 0.71 | 1.21 | 2.12 | 2.70 | 4.1 (20.6) | 0.00 % | 0 | 176 (179) | 576 |
| jetpack_rally | 0.89 | 1.86 | 2.79 | 3.19 | 4.0 (6.4) | 0.00 % | 0 | 183 (183) | 500 |
| kart_bowling | 0.51 | 0.81 | 1.63 | 2.17 | 4.4 (41.7) | 0.00 % | 0 | 180 (180) | 519 |
| lava_surf | 0.40 | 0.79 | 2.13 | 3.11 | 7.9 (10.4) | 0.00 % | 0 | 185 (190) | 362 |
| log_bridge | 0.83 | 1.58 | 2.52 | 2.94 | 4.2 (15.6) | 0.00 % | 0 | 176 (177) | 636 |
| lucky_bells | 0.32 | 0.46 | 1.20 | 1.73 | 3.2 (5.8) | 0.00 % | 0 | 194 (196) | 576 |
| marble_maze | 0.63 | 1.04 | 1.62 | 2.54 | 4.8 (4.3) | 0.00 % | 0 | 182 (183) | 556 |
| mega_bee | 0.92 | 1.43 | 2.30 | 3.38 | 7.7 (3.3) | 0.00 % | 0 | 185 (186) | 589 |
| memory_match | 0.72 | 1.12 | 2.18 | 3.14 | 7.5 (9.2) | 0.00 % | 0 | 194 (195) | 692 |
| meteor_dodge | 0.74 | 1.29 | 2.45 | 3.00 | 6.0 (24.7) | 0.00 % | 0 | 173 (175) | 519 |
| minigolf_duel | 1.06 | 3.28 | 7.34 | 9.90 | 29.8 (28.0) | 0.06 % | 0 | 186 (190) | 487 |
| nail_pro | 0.90 | 1.46 | 2.42 | 2.89 | 4.0 (18.3) | 0.00 % | 0 | 191 (191) | 639 |
| pedal_boat | 0.91 | 1.53 | 2.19 | 2.73 | 7.3 (16.0) | 0.00 % | 0 | 181 (185) | 597 |
| penguin_curling | 0.78 | 3.12 | 4.21 | 5.26 | 23.0 (28.6) | 0.03 % | 0 | 204 (213) | 998 |
| pickaxe_dash | 1.03 | 1.87 | 2.91 | 3.80 | 8.4 (13.7) | 0.00 % | 0 | 187 (191) | 488 |
| plank_panic | 0.71 | 1.30 | 2.64 | 3.41 | 5.9 (12.5) | 0.00 % | 0 | 176 (177) | 506 |
| plush_balls | 0.87 | 1.59 | 3.01 | 3.46 | 4.8 (10.9) | 0.00 % | 0 | 174 (178) | 690 |
| prize_drop | 0.88 | 1.38 | 1.88 | 3.83 | 9.6 (2.6) | 0.00 % | 0 | 198 (202) | 677 |
| pumpkin_toss | 0.43 | 0.98 | 2.42 | 3.92 | 6.9 (0.4) | 0.00 % | 0 | 198 (199) | 603 |
| quick_fishing | 0.63 | 1.10 | 1.57 | 3.69 | 10.4 (8.2) | 0.00 % | 0 | 200 (204) | 502 |
| rail_express | 0.69 | 1.07 | 1.63 | 2.31 | 3.2 (1.7) | 0.00 % | 0 | 183 (183) | 981 |
| rhythm_dance | 0.79 | 1.47 | 1.97 | 2.38 | 3.6 (8.1) | 0.00 % | 0 | 184 (185) | 561 |
| sandwich_storm | 0.72 | 1.27 | 2.79 | 3.95 | 10.7 (35.0) | 0.00 % | 0 | 182 (194) | 854 |
| slap_carousel | 0.55 | 0.87 | 1.70 | 2.88 | 7.5 (6.4) | 0.00 % | 0 | 179 (181) | 477 |
| sled_edge | 0.57 | 0.98 | 1.66 | 3.22 | 11.7 (2.5) | 0.00 % | 0 | 204 (207) | 470 |
| sleepwalk | 0.74 | 1.19 | 2.05 | 2.92 | 6.2 (14.3) | 0.00 % | 0 | 188 (195) | 778 |
| sleepy_stars | 0.45 | 0.75 | 1.58 | 2.93 | 11.1 (14.8) | 0.00 % | 0 | 188 (196) | 569 |
| slime_sprint | 1.00 | 1.64 | 2.80 | 4.13 | 7.7 (21.4) | 0.00 % | 0 | 187 (194) | 784 |
| snowball_fight | 1.11 | 2.17 | 3.36 | 4.20 | 11.5 (3.5) | 0.00 % | 0 | 194 (195) | 570 |
| spark_carousel | 0.68 | 1.52 | 2.49 | 3.75 | 12.5 (20.5) | 0.00 % | 0 | 178 (187) | 385 |
| star_hoops | 0.77 | 1.28 | 2.39 | 2.96 | 6.6 (2.2) | 0.00 % | 0 | 182 (183) | 486 |
| stomp_waves | 0.76 | 1.67 | 2.33 | 2.66 | 3.8 (23.1) | 0.00 % | 0 | 171 (172) | 381 |
| stone_bowling | 0.72 | 1.08 | 1.74 | 2.66 | 7.7 (7.5) | 0.00 % | 0 | 187 (188) | 608 |
| stone_skip | 0.79 | 1.28 | 2.02 | 3.61 | 10.6 (5.2) | 0.00 % | 0 | 193 (196) | 504 |
| sumo_shove | 0.69 | 1.31 | 2.05 | 3.36 | 4.4 (1.6) | 0.00 % | 0 | 174 (174) | 426 |
| switch_gauntlet | 0.92 | 1.69 | 2.77 | 4.33 | 8.6 (1.8) | 0.00 % | 0 | 198 (200) | 569 |
| tower_balance | 1.05 | 1.48 | 2.74 | 3.42 | 5.0 (23.3) | 0.00 % | 0 | 180 (180) | 493 |
| treasure_zipline | 0.65 | 1.01 | 1.86 | 2.86 | 6.5 (1.2) | 0.00 % | 0 | 197 (198) | 962 |
| tug_of_war | 0.84 | 1.29 | 1.89 | 2.28 | 3.2 (11.0) | 0.00 % | 0 | 186 (186) | 1818 |
| ufo_heist | 0.63 | 1.13 | 1.66 | 2.48 | 6.9 (16.4) | 0.00 % | 0 | 175 (176) | 550 |
| veggie_harvest | 1.01 | 1.69 | 2.62 | 3.86 | 10.7 (8.0) | 0.00 % | 0 | 200 (204) | 690 |

## Auffälligkeiten

* `board:dungeon`: erst während der Messung geladen: bg/d6 (1 ms), plat/arrow (1 ms), bg/coin_gold (0 ms)
* `board:pirates`: erst während der Messung geladen: bg/d6 (1 ms), bg/coin_gold (1 ms)
* `board:sky`: erst während der Messung geladen: bg/d6 (1 ms), bg/coin_gold (1 ms)
* `board:graveyard`: erst während der Messung geladen: bg/d6 (1 ms), plat/arrow (0 ms), bg/coin_gold (0 ms)
* `board:frost`: erst während der Messung geladen: bg/d6 (1 ms), bg/coin_gold (0 ms)
* `board:station`: erst während der Messung geladen: bg/d6 (1 ms), bg/coin_gold (0 ms), plat/arrow (0 ms)
* `board:glowforest`: erst während der Messung geladen: bg/d6 (1 ms), bg/coin_gold (0 ms), plat/arrow (0 ms)
* `board:meadow`: erst während der Messung geladen: bg/d6 (1 ms), bg/coin_gold (0 ms)
* `board:cake`: erst während der Messung geladen: bg/d6 (1 ms), plat/arrow (1 ms), bg/coin_gold (1 ms)
* `board:tower`: erst während der Messung geladen: bg/d6 (1 ms), bg/coin_gold (1 ms)
* `mode:colosseum`: erst während der Messung geladen: pet/crab (1 ms), hero/mage (14 ms), npc/bear (1 ms)
* `mode:marathon`: erst während der Messung geladen: pirate/rocks_b (2 ms), arena/statue (2 ms), arena/column (0 ms), env/mount_a (1 ms), env/mount_b (1 ms)
