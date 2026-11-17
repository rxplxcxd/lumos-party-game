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
| Menü | 1 | 1.60 / 1.60 | 2.33 | 11.5 ms (menu) | 0 | 180 MB | 0 |
| Bretter | 10 | 0.38 / 0.42 | 2.34 | 22.1 ms (tower) | 0 | 250 MB | 0 |
| Nitro-Dash-Strecken | 12 | 1.15 / 1.38 | 3.36 | 13.2 ms (lumos_ring) | 0 | 180 MB | 0 |
| Bosskämpfe | 10 | 0.90 / 1.01 | 3.01 | 9.4 ms (zephyros) | 0 | 208 MB | 0 |
| Abenteuer & Modi | 5 | 0.20 / 0.64 | 1.64 | 12.6 ms (colosseum) | 0 | 193 MB | 0 |
| Minispiele | 67 | 0.72 / 1.31 | 8.03 | 28.7 ms (penguin_curling) | 0 | 216 MB | 0 |

## Menü

| Szene | CPU-ms Mittel | p95 | p99 | 1 %-Tief | Maximum (bei s) | > 16,7 ms | > 33 ms | Speicher MB (Spitze) | Knoten | Draw-Calls (vorher → jetzt) | Primitive (Tsd.) | Videospeicher MB |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| menu | 1.60 | 2.01 | 2.33 | 3.37 | 11.5 (2.8) | 0.00 % | 0 | 180 (180) | 535 | 652 → 348 | 114.0 | 96 |

## Bretter

| Szene | CPU-ms Mittel | p95 | p99 | 1 %-Tief | Maximum (bei s) | > 16,7 ms | > 33 ms | Speicher MB (Spitze) | Knoten | Draw-Calls (vorher → jetzt) | Primitive (Tsd.) | Videospeicher MB |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| cake | 0.38 | 0.80 | 1.79 | 4.74 | 14.1 (1.0) | 0.00 % | 0 | 210 (230) | 977 | 459 → 490 | 119.2 | 96 |
| dungeon | 0.31 | 0.46 | 1.59 | 4.33 | 11.8 (1.0) | 0.00 % | 0 | 195 (216) | 1023 | 448 → 368 | 88.5 | 85 |
| frost | 0.40 | 0.69 | 1.83 | 4.59 | 11.3 (20.7) | 0.00 % | 0 | 206 (226) | 975 | 763 → 557 | 185.3 | 93 |
| glowforest | 0.42 | 0.84 | 2.34 | 5.00 | 15.5 (1.0) | 0.00 % | 0 | 200 (222) | 1429 | 839 → 706 | 232.3 | 84 |
| graveyard | 0.36 | 0.74 | 2.05 | 4.00 | 7.9 (1.0) | 0.00 % | 0 | 229 (250) | 1204 | 498 → 504 | 105.0 | 116 |
| meadow | 0.37 | 0.58 | 1.84 | 4.15 | 9.1 (1.0) | 0.00 % | 0 | 203 (220) | 1418 | 1642 → 745 | 168.4 | 88 |
| pirates | 0.27 | 0.33 | 1.48 | 3.30 | 8.0 (1.0) | 0.00 % | 0 | 202 (220) | 1099 | 956 → 733 | 164.9 | 88 |
| sky | 0.34 | 0.57 | 1.87 | 4.26 | 9.5 (1.0) | 0.00 % | 0 | 200 (219) | 1067 | 676 → 535 | 112.2 | 87 |
| station | 0.38 | 0.79 | 1.81 | 4.02 | 9.8 (1.0) | 0.00 % | 0 | 197 (216) | 990 | 786 → 480 | 101.0 | 84 |
| tower | 0.41 | 0.80 | 1.88 | 4.57 | 22.1 (1.0) | 0.04 % | 0 | 208 (227) | 2009 | 683 → 490 | 52.1 | 87 |

## Nitro-Dash-Strecken

| Szene | CPU-ms Mittel | p95 | p99 | 1 %-Tief | Maximum (bei s) | > 16,7 ms | > 33 ms | Speicher MB (Spitze) | Knoten | Draw-Calls (vorher → jetzt) | Primitive (Tsd.) | Videospeicher MB |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| candy_lane | 1.16 | 1.87 | 2.74 | 4.46 | 11.5 (30.2) | 0.00 % | 0 | 173 (179) | 913 | 256 → 255 | 92.1 | 80 |
| city_rally | 1.24 | 1.92 | 2.73 | 3.75 | 7.5 (6.5) | 0.00 % | 0 | 170 (173) | 1316 | 139 → 139 | 77.4 | 75 |
| coral_canal | 1.24 | 2.01 | 3.03 | 4.65 | 8.8 (35.0) | 0.00 % | 0 | 172 (176) | 1098 | 337 → 337 | 75.5 | 77 |
| desert_canyon | 1.28 | 2.10 | 3.04 | 4.07 | 7.4 (6.5) | 0.00 % | 0 | 169 (174) | 1015 | 152 → 152 | 65.3 | 74 |
| falls_gorge | 1.09 | 1.71 | 2.42 | 3.58 | 10.5 (27.0) | 0.00 % | 0 | 166 (171) | 832 | 147 → 147 | 69.3 | 72 |
| frost_peak | 1.15 | 1.74 | 2.55 | 4.08 | 10.8 (2.6) | 0.00 % | 0 | 173 (178) | 832 | 226 → 226 | 74.0 | 80 |
| glow_forest | 1.14 | 1.82 | 2.76 | 3.72 | 7.5 (17.5) | 0.00 % | 0 | 175 (180) | 1122 | 254 → 222 | 65.2 | 80 |
| jungle_ruins | 1.04 | 1.64 | 2.08 | 2.93 | 6.5 (6.5) | 0.00 % | 0 | 174 (178) | 1119 | 172 → 172 | 50.7 | 80 |
| lumos_ring | 1.14 | 1.79 | 2.59 | 4.41 | 13.2 (31.1) | 0.00 % | 0 | 167 (171) | 932 | 186 → 186 | 47.5 | 73 |
| neon_volcano | 1.38 | 2.19 | 3.36 | 4.61 | 9.8 (42.5) | 0.00 % | 0 | 168 (172) | 930 | 213 → 213 | 51.8 | 74 |
| orbit_ring | 1.12 | 1.72 | 2.14 | 3.06 | 6.6 (6.5) | 0.00 % | 0 | 167 (170) | 894 | 224 → 207 | 60.4 | 74 |
| storm_pass | 1.38 | 2.17 | 2.90 | 3.95 | 7.7 (6.5) | 0.00 % | 0 | 168 (173) | 846 | 165 → 165 | 73.7 | 75 |

## Bosskämpfe

| Szene | CPU-ms Mittel | p95 | p99 | 1 %-Tief | Maximum (bei s) | > 16,7 ms | > 33 ms | Speicher MB (Spitze) | Knoten | Draw-Calls (vorher → jetzt) | Primitive (Tsd.) | Videospeicher MB |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| astraios | 0.86 | 1.43 | 2.12 | 3.13 | 5.0 (20.9) | 0.00 % | 0 | 195 (196) | 565 | 257 → 268 | 47.6 | 77 |
| baahemoth | 1.01 | 1.79 | 3.01 | 4.33 | 7.3 (2.6) | 0.00 % | 0 | 204 (207) | 633 | 318 → 322 | 82.0 | 80 |
| frostbart | 1.00 | 1.72 | 2.70 | 4.02 | 8.6 (4.5) | 0.00 % | 0 | 192 (197) | 619 | 281 → 296 | 53.2 | 76 |
| galaxus | 0.88 | 1.40 | 2.14 | 3.21 | 6.2 (4.1) | 0.00 % | 0 | 200 (203) | 652 | 312 → 323 | 42.9 | 77 |
| grabstein | 0.85 | 1.46 | 2.07 | 2.92 | 5.7 (10.4) | 0.00 % | 0 | 199 (203) | 531 | 256 → 261 | 43.0 | 76 |
| ignis | 0.99 | 1.79 | 2.99 | 3.64 | 5.4 (57.4) | 0.00 % | 0 | 196 (199) | 662 | 433 → 404 | 52.1 | 76 |
| klabautox | 0.88 | 1.46 | 2.36 | 3.73 | 9.1 (0.9) | 0.00 % | 0 | 203 (204) | 633 | 296 → 284 | 54.6 | 78 |
| marquise | 0.91 | 1.46 | 2.69 | 3.85 | 7.5 (3.0) | 0.00 % | 0 | 202 (208) | 709 | 385 → 377 | 55.4 | 78 |
| noxumbra | 0.86 | 1.48 | 2.25 | 3.03 | 7.3 (8.1) | 0.00 % | 0 | 197 (203) | 547 | 281 → 257 | 46.3 | 78 |
| zephyros | 0.93 | 1.62 | 2.49 | 3.66 | 9.4 (35.7) | 0.00 % | 0 | 195 (197) | 575 | 291 → 299 | 74.2 | 77 |

## Abenteuer & Modi

| Szene | CPU-ms Mittel | p95 | p99 | 1 %-Tief | Maximum (bei s) | > 16,7 ms | > 33 ms | Speicher MB (Spitze) | Knoten | Draw-Calls (vorher → jetzt) | Primitive (Tsd.) | Videospeicher MB |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| athlon | 0.17 | 0.21 | 0.31 | 2.36 | 6.1 (17.6) | 0.00 % | 0 | 165 (169) | 699 | 1227 → 614 | 135.2 | 92 |
| colosseum | 0.20 | 0.25 | 0.80 | 2.70 | 12.6 (13.2) | 0.00 % | 0 | 104 (108) | 887 | 311 → 311 | 46.5 | 63 |
| journey | 0.39 | 0.61 | 0.85 | 0.98 | 1.4 (9.9) | 0.00 % | 0 | 112 (112) | 675 | 894 → 477 | 122.4 | 52 |
| kitchen | 0.64 | 0.94 | 1.64 | 2.94 | 6.4 (0.0) | 0.00 % | 0 | 192 (193) | 675 | 393 → 393 | 105.4 | 78 |
| marathon | 0.08 | 0.13 | 0.20 | 0.46 | 1.3 (0.2) | 0.00 % | 0 | 119 (131) | 89 | 52 → 51 | 17.5 | 56 |

## Minispiele

| Szene | CPU-ms Mittel | p95 | p99 | 1 %-Tief | Maximum (bei s) | > 16,7 ms | > 33 ms | Speicher MB (Spitze) | Knoten | Draw-Calls (vorher → jetzt) | Primitive (Tsd.) | Videospeicher MB |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| axis_taxi | 0.83 | 1.30 | 1.76 | 2.36 | 4.9 (28.7) | 0.00 % | 0 | 201 (201) | 628 | – | – | – |
| balloon_battle | 0.51 | 0.93 | 2.50 | 3.64 | 7.7 (0.0) | 0.00 % | 0 | 198 (199) | 729 | 366 → 374 | 65.7 | 87 |
| barrel_chaos | 0.61 | 0.96 | 1.74 | 2.81 | 9.8 (3.5) | 0.00 % | 0 | 207 (210) | 485 | – | – | – |
| beach_volley | 0.78 | 1.36 | 2.09 | 3.10 | 13.3 (1.3) | 0.00 % | 0 | 203 (205) | 576 | 334 → 287 | 63.0 | 78 |
| bomb_defuse | 0.73 | 1.25 | 2.22 | 2.74 | 6.4 (0.8) | 0.00 % | 0 | 177 (178) | 447 | – | – | – |
| boss_cloud | 1.06 | 1.77 | 3.11 | 5.24 | 17.1 (22.5) | 0.06 % | 0 | 195 (207) | 446 | – | – | – |
| boulder_run | 1.31 | 2.80 | 4.12 | 5.38 | 9.6 (11.2) | 0.00 % | 0 | 180 (184) | 454 | – | – | – |
| bridge_bluff | 0.73 | 1.26 | 2.16 | 3.72 | 12.6 (26.4) | 0.00 % | 0 | 206 (216) | 497 | – | – | – |
| bubble_ballet | 0.67 | 1.06 | 1.39 | 1.63 | 2.3 (38.0) | 0.00 % | 0 | 173 (173) | 435 | – | – | – |
| bumper_balls | 0.68 | 1.24 | 1.86 | 2.77 | 9.0 (23.9) | 0.00 % | 0 | 178 (179) | 427 | – | – | – |
| cheese_brawl | 0.63 | 0.94 | 2.12 | 3.10 | 4.5 (10.9) | 0.00 % | 0 | 174 (175) | 540 | – | – | – |
| chest_sniff | 0.33 | 0.51 | 1.38 | 2.29 | 5.2 (3.6) | 0.00 % | 0 | 194 (195) | 501 | – | – | – |
| coaster_shooter | 0.74 | 1.21 | 1.75 | 2.51 | 4.0 (1.9) | 0.00 % | 0 | 188 (188) | 889 | 282 → 283 | 79.7 | 77 |
| coin_rain | 0.88 | 1.57 | 2.62 | 3.39 | 6.4 (2.4) | 0.00 % | 0 | 196 (197) | 507 | – | – | – |
| color_chaos | 0.71 | 1.04 | 1.87 | 2.83 | 7.6 (2.4) | 0.00 % | 0 | 186 (188) | 677 | – | – | – |
| dungeon_drop | 0.86 | 1.61 | 2.38 | 2.85 | 4.7 (33.4) | 0.00 % | 0 | 178 (179) | 693 | – | – | – |
| fish_catch | 0.40 | 0.58 | 1.25 | 2.58 | 11.1 (38.5) | 0.00 % | 0 | 187 (200) | 639 | – | – | – |
| flower_rush | 0.93 | 1.52 | 2.70 | 3.88 | 6.5 (0.5) | 0.00 % | 0 | 183 (184) | 629 | – | – | – |
| ghost_castle | 0.68 | 1.06 | 1.71 | 2.57 | 8.1 (6.5) | 0.00 % | 0 | 188 (189) | 616 | – | – | – |
| ghost_manor | 0.92 | 1.41 | 2.56 | 2.96 | 3.6 (5.0) | 0.00 % | 0 | 177 (177) | 630 | – | – | – |
| ghost_photo | 1.04 | 1.65 | 3.29 | 4.35 | 6.6 (16.0) | 0.00 % | 0 | 193 (194) | 585 | – | – | – |
| hammer_hop | 0.54 | 0.90 | 1.89 | 2.94 | 9.3 (21.1) | 0.00 % | 0 | 176 (185) | 412 | – | – | – |
| hollow_hide | 0.35 | 0.76 | 1.08 | 2.27 | 8.6 (4.6) | 0.00 % | 0 | 205 (210) | 518 | – | – | – |
| honey_chase | 0.52 | 0.74 | 0.98 | 1.58 | 3.1 (11.8) | 0.00 % | 0 | 179 (180) | 523 | – | – | – |
| hot_bomb | 0.72 | 1.20 | 1.74 | 2.52 | 8.2 (5.3) | 0.00 % | 0 | 179 (180) | 621 | – | – | – |
| ice_coins | 0.76 | 1.43 | 2.47 | 3.14 | 4.9 (3.9) | 0.00 % | 0 | 183 (184) | 493 | – | – | – |
| ice_floes | 0.64 | 1.13 | 2.07 | 2.73 | 5.0 (16.4) | 0.00 % | 0 | 178 (179) | 597 | – | – | – |
| jetpack_rally | 0.98 | 1.90 | 2.92 | 3.57 | 6.1 (34.0) | 0.00 % | 0 | 183 (184) | 502 | – | – | – |
| kart_bowling | 0.50 | 0.79 | 1.68 | 2.21 | 4.8 (23.2) | 0.00 % | 0 | 180 (180) | 489 | 305 → 306 | 73.8 | 76 |
| lava_surf | 0.35 | 0.57 | 1.54 | 2.35 | 5.6 (8.1) | 0.00 % | 0 | 184 (190) | 364 | 149 → 154 | 38.2 | 71 |
| log_bridge | 0.79 | 1.56 | 2.78 | 3.37 | 6.0 (18.9) | 0.00 % | 0 | 176 (177) | 592 | – | – | – |
| lucky_bells | 0.32 | 0.46 | 1.41 | 1.47 | 1.5 (5.5) | 0.00 % | 0 | 196 (196) | 597 | – | – | – |
| marble_maze | 0.56 | 0.87 | 1.03 | 1.79 | 4.7 (4.4) | 0.00 % | 0 | 181 (183) | 557 | – | – | – |
| mega_bee | 0.82 | 1.28 | 2.28 | 3.31 | 9.3 (3.2) | 0.00 % | 0 | 185 (186) | 599 | – | – | – |
| memory_match | 0.97 | 1.55 | 2.81 | 4.37 | 22.2 (38.2) | 0.03 % | 0 | 193 (195) | 692 | – | – | – |
| meteor_dodge | 0.63 | 1.01 | 2.23 | 3.50 | 9.7 (5.6) | 0.00 % | 0 | 174 (175) | 454 | – | – | – |
| minigolf_duel | 1.01 | 2.97 | 8.03 | 9.71 | 14.9 (53.8) | 0.00 % | 0 | 184 (190) | 487 | 226 → 205 | 62.3 | 73 |
| nail_pro | 0.88 | 1.43 | 2.47 | 3.16 | 5.0 (8.8) | 0.00 % | 0 | 191 (192) | 634 | – | – | – |
| pedal_boat | 0.74 | 1.21 | 1.67 | 2.50 | 5.8 (16.1) | 0.00 % | 0 | 181 (185) | 598 | – | – | – |
| penguin_curling | 0.76 | 3.26 | 5.08 | 6.85 | 28.7 (36.9) | 0.03 % | 0 | 197 (209) | 983 | 406 → 382 | 66.5 | 71 |
| pickaxe_dash | 1.00 | 1.87 | 2.68 | 3.33 | 6.5 (8.6) | 0.00 % | 0 | 184 (184) | 480 | 173 → 174 | 64.7 | 75 |
| plank_panic | 0.65 | 1.02 | 1.80 | 2.65 | 5.1 (1.2) | 0.00 % | 0 | 181 (181) | 508 | – | – | – |
| plush_balls | 0.66 | 1.17 | 2.07 | 2.60 | 4.1 (12.2) | 0.00 % | 0 | 174 (176) | 711 | – | – | – |
| prize_drop | 0.99 | 1.54 | 2.81 | 3.89 | 7.2 (2.2) | 0.00 % | 0 | 199 (202) | 677 | – | – | – |
| pumpkin_toss | 0.37 | 0.76 | 1.63 | 2.99 | 5.2 (0.4) | 0.00 % | 0 | 198 (199) | 602 | – | – | – |
| quick_fishing | 0.66 | 1.12 | 1.61 | 3.23 | 11.6 (6.2) | 0.00 % | 0 | 201 (206) | 503 | – | – | – |
| rail_express | 0.61 | 0.97 | 1.62 | 2.10 | 2.7 (6.7) | 0.00 % | 0 | 183 (183) | 981 | – | – | – |
| rhythm_dance | 0.53 | 0.94 | 1.35 | 1.63 | 2.7 (2.5) | 0.00 % | 0 | 185 (185) | 561 | – | – | – |
| sandwich_storm | 0.86 | 1.61 | 3.26 | 4.63 | 14.4 (35.0) | 0.00 % | 0 | 183 (194) | 897 | – | – | – |
| slap_carousel | 0.50 | 0.79 | 1.20 | 2.38 | 9.4 (6.4) | 0.00 % | 0 | 179 (182) | 479 | – | – | – |
| sled_edge | 0.55 | 0.89 | 1.47 | 2.50 | 7.5 (2.2) | 0.00 % | 0 | 205 (207) | 470 | – | – | – |
| sleepwalk | 0.67 | 1.26 | 1.77 | 2.36 | 6.3 (19.0) | 0.00 % | 0 | 189 (195) | 795 | – | – | – |
| sleepy_stars | 0.30 | 0.39 | 0.92 | 2.17 | 9.4 (1.0) | 0.00 % | 0 | 195 (196) | 569 | – | – | – |
| slime_sprint | 0.83 | 1.47 | 2.41 | 3.01 | 6.5 (17.4) | 0.00 % | 0 | 188 (194) | 788 | – | – | – |
| snowball_fight | 0.82 | 1.54 | 2.66 | 3.28 | 5.9 (3.2) | 0.00 % | 0 | 195 (195) | 550 | 250 → 266 | 189.8 | 81 |
| spark_carousel | 0.65 | 1.43 | 2.12 | 3.00 | 12.6 (20.5) | 0.00 % | 0 | 177 (187) | 395 | – | – | – |
| star_hoops | 0.86 | 1.53 | 2.59 | 3.40 | 9.0 (2.7) | 0.00 % | 0 | 182 (183) | 494 | – | – | – |
| stomp_waves | 0.88 | 1.91 | 2.79 | 3.39 | 5.2 (13.0) | 0.00 % | 0 | 171 (172) | 382 | – | – | – |
| stone_bowling | 0.55 | 0.76 | 1.15 | 2.19 | 8.1 (7.7) | 0.00 % | 0 | 187 (188) | 608 | – | – | – |
| stone_skip | 0.72 | 1.36 | 2.24 | 3.12 | 8.5 (5.1) | 0.00 % | 0 | 193 (196) | 504 | – | – | – |
| sumo_shove | 0.72 | 1.35 | 2.38 | 3.04 | 4.3 (5.1) | 0.00 % | 0 | 174 (174) | 424 | 177 → 164 | 39.9 | 67 |
| switch_gauntlet | 0.96 | 1.60 | 3.54 | 4.95 | 9.0 (1.6) | 0.00 % | 0 | 198 (200) | 548 | – | – | – |
| tower_balance | 0.91 | 1.44 | 2.14 | 2.77 | 4.0 (4.0) | 0.00 % | 0 | 179 (180) | 481 | – | – | – |
| treasure_zipline | 0.53 | 0.64 | 1.12 | 1.99 | 6.1 (0.4) | 0.00 % | 0 | 198 (199) | 993 | – | – | – |
| tug_of_war | 0.63 | 0.90 | 1.57 | 2.14 | 3.7 (11.4) | 0.00 % | 0 | 186 (187) | 1845 | – | – | – |
| ufo_heist | 0.71 | 1.15 | 1.59 | 2.97 | 9.4 (26.2) | 0.00 % | 0 | 178 (180) | 566 | – | – | – |
| veggie_harvest | 1.09 | 1.95 | 2.78 | 4.03 | 12.9 (8.0) | 0.00 % | 0 | 200 (204) | 681 | – | – | – |

## Draw-Calls vor und nach dem Zusammenführen der OBJ-Flächen

Summe über 48 gemessene Szenen: 19528 → 15909 (-19 %). Größte Einsparungen: meadow 1642 → 745, athlon 1227 → 614, journey 894 → 477, station 786 → 480, menu 652 → 348. Ursache: Godots OBJ-Import legt je Materialwechsel in der Datei eine eigene Fläche an (eine 0,5-m-Blume hatte 87 Flächen bei 3 Materialien); `Assets._merge_surfaces` führt gleiche Materialien beim Laden zusammen. Gleiche Geometrie (Primitive unverändert), Bildvergleich im Rauschen zweier gleicher Läufe.

## Einordnung der Draw-Calls

Beispiel Hauptmenü (eigene Messung vor dem Zusammenführen, gleiche Ansicht): Grafikstufe Hoch 663 Draw-Calls je Bild, davon ≈ 600 für die 3D-Insel (195 sichtbare Objekte, 88 Schattenwerfer, mehrteilige Figuren) und ≈ 60 für die Oberfläche; Mittel 522, Niedrig 447 (ohne Schatten). Die Grafikstufen passen das bereits an: „Niedrig“ ohne Schatten, im Web auf Niedrig/Mittel nur eine Schattenebene und 30 % kürzere Schattendistanz, kleine Deko wirft keinen Schatten. Wuschel-Wiesen lag auch ohne Schatten noch bei ≈ 1100 – dort waren nicht die Schatten, sondern die OBJ-Flächen die Ursache (siehe oben). Ob die heutigen Werte auf schwachen Geräten reichen, zeigt erst eine Messung dort.

## Auffälligkeiten

* `board:dungeon`: erst während der Messung geladen: audio:creak1.ogg (0 ms), audio:whistle_up.ogg (0 ms), audio:3.ogg (0 ms), audio:tone1.ogg (0 ms), audio:magic_t.ogg (0 ms)
* `board:pirates`: erst während der Messung geladen: audio:creak3.ogg (0 ms), audio:whistle_up.ogg (0 ms), audio:3.ogg (0 ms), audio:tone1.ogg (0 ms), audio:magic_s.ogg (0 ms)
* `board:sky`: erst während der Messung geladen: audio:creak2.ogg (0 ms), audio:whistle_up.ogg (0 ms), audio:3.ogg (0 ms), audio:tone1.ogg (0 ms), audio:magic_t.ogg (0 ms)
* `board:graveyard`: erst während der Messung geladen: audio:creak3.ogg (0 ms), audio:whistle_up.ogg (0 ms), audio:3.ogg (0 ms), audio:tone1.ogg (0 ms), audio:magic_s.ogg (0 ms)
* `board:frost`: erst während der Messung geladen: audio:creak1.ogg (0 ms), audio:whistle_up.ogg (0 ms), audio:3.ogg (0 ms), audio:tone1.ogg (0 ms), audio:magic_s.ogg (0 ms)
* `board:station`: erst während der Messung geladen: audio:creak2.ogg (0 ms), audio:whistle_up.ogg (0 ms), audio:3.ogg (0 ms), audio:tone1.ogg (0 ms), audio:magic_t.ogg (0 ms)
* `board:glowforest`: erst während der Messung geladen: audio:creak1.ogg (0 ms), audio:whistle_up.ogg (0 ms), audio:3.ogg (0 ms), audio:tone1.ogg (0 ms), audio:magic_t.ogg (0 ms)
* `board:meadow`: erst während der Messung geladen: audio:creak2.ogg (0 ms), audio:whistle_up.ogg (0 ms), audio:3.ogg (0 ms), audio:tone1.ogg (0 ms), audio:magic_s.ogg (0 ms)
* `board:cake`: erst während der Messung geladen: audio:creak3.ogg (0 ms), audio:whistle_up.ogg (0 ms), audio:3.ogg (0 ms), audio:tone1.ogg (0 ms), audio:magic_s.ogg (0 ms)
* `board:tower`: erst während der Messung geladen: audio:creak3.ogg (0 ms), audio:whistle_up.ogg (0 ms), audio:3.ogg (0 ms), audio:tone1.ogg (0 ms), audio:magic_t.ogg (0 ms)
* `track:lumos_ring`: erst während der Messung geladen: audio:whistle_up.ogg (0 ms), audio:3.ogg (0 ms), audio:tone1.ogg (0 ms), audio:magic_t.ogg (0 ms), audio:2.ogg (1 ms)
* `track:coral_canal`: erst während der Messung geladen: audio:whistle_up.ogg (0 ms), audio:3.ogg (0 ms), audio:tone1.ogg (0 ms), audio:magic_s.ogg (0 ms), audio:2.ogg (0 ms)
* `track:neon_volcano`: erst während der Messung geladen: audio:whistle_up.ogg (0 ms), audio:3.ogg (0 ms), audio:tone1.ogg (0 ms), audio:magic_t.ogg (0 ms), audio:2.ogg (0 ms)
* `track:storm_pass`: erst während der Messung geladen: audio:lowFrequency_explosion_001.ogg (0 ms), audio:whistle_up.ogg (0 ms), audio:3.ogg (0 ms), audio:tone1.ogg (0 ms), audio:magic_t.ogg (0 ms)
* `track:frost_peak`: erst während der Messung geladen: audio:whistle_up.ogg (0 ms), audio:3.ogg (0 ms), audio:tone1.ogg (0 ms), audio:magic_t.ogg (0 ms), audio:2.ogg (0 ms)
* `track:orbit_ring`: erst während der Messung geladen: audio:whistle_up.ogg (0 ms), audio:3.ogg (0 ms), audio:tone1.ogg (0 ms), audio:magic_t.ogg (0 ms), audio:2.ogg (0 ms)
* `track:city_rally`: erst während der Messung geladen: audio:whistle_up.ogg (0 ms), audio:3.ogg (0 ms), audio:tone1.ogg (0 ms), audio:magic_t.ogg (0 ms), audio:2.ogg (0 ms)
* `track:desert_canyon`: erst während der Messung geladen: audio:whistle_up.ogg (0 ms), audio:3.ogg (0 ms), audio:tone1.ogg (0 ms), audio:magic_s.ogg (0 ms), audio:2.ogg (0 ms)
* `track:glow_forest`: erst während der Messung geladen: audio:whistle_up.ogg (0 ms), audio:3.ogg (0 ms), audio:tone1.ogg (0 ms), audio:magic_s.ogg (0 ms), audio:2.ogg (0 ms)
* `track:candy_lane`: erst während der Messung geladen: audio:whistle_up.ogg (0 ms), audio:3.ogg (0 ms), audio:tone1.ogg (0 ms), audio:magic_s.ogg (0 ms), audio:2.ogg (0 ms)
* `track:jungle_ruins`: erst während der Messung geladen: audio:whistle_up.ogg (0 ms), audio:3.ogg (0 ms), audio:tone1.ogg (0 ms), audio:magic_s.ogg (0 ms), audio:2.ogg (0 ms)
* `track:falls_gorge`: erst während der Messung geladen: audio:whistle_up.ogg (0 ms), audio:3.ogg (0 ms), audio:tone1.ogg (0 ms), audio:magic_t.ogg (0 ms), audio:2.ogg (0 ms)
* `boss:ignis`: erst während der Messung geladen: audio:impactMining_001.ogg (0 ms), audio:impactPunch_heavy_001.ogg (0 ms), audio:phaseJump1.ogg (0 ms), audio:lowDown.ogg (0 ms), audio:impactPunch_heavy_000.ogg (0 ms)
* `boss:klabautox`: erst während der Messung geladen: audio:impactPunch_heavy_001.ogg (1 ms), audio:phaserDown2.ogg (0 ms), audio:impactPunch_medium_000.ogg (0 ms), audio:phaseJump2.ogg (0 ms), audio:impactMining_000.ogg (0 ms)
* `boss:astraios`: erst während der Messung geladen: audio:cannon.ogg (0 ms), audio:impactSoft_medium_000.ogg (0 ms), audio:impactPunch_medium_000.ogg (0 ms), audio:impactMining_001.ogg (0 ms), audio:explosionCrunch_000.ogg (0 ms)
* `boss:grabstein`: erst während der Messung geladen: audio:phaserDown2.ogg (0 ms), audio:impactMining_001.ogg (0 ms), audio:impactPunch_heavy_000.ogg (0 ms), audio:phaseJump2.ogg (0 ms), audio:impactPunch_medium_000.ogg (0 ms)
* `boss:frostbart`: erst während der Messung geladen: audio:explosionCrunch_002.ogg (1 ms), audio:impactMining_000.ogg (0 ms), audio:impactGlass_heavy_000.ogg (0 ms), audio:powerUp10.ogg (0 ms), audio:impactPunch_heavy_001.ogg (1 ms)
* `boss:galaxus`: erst während der Messung geladen: audio:powerUp10.ogg (0 ms), audio:impactPunch_medium_000.ogg (0 ms), audio:lowDown.ogg (0 ms), audio:impactPunch_heavy_000.ogg (0 ms), audio:impactPunch_heavy_001.ogg (0 ms)
* `boss:noxumbra`: erst während der Messung geladen: audio:impactPunch_heavy_001.ogg (1 ms), audio:lowFrequency_explosion_001.ogg (0 ms), audio:impactPunch_medium_000.ogg (0 ms), audio:lowFrequency_explosion_000.ogg (1 ms), audio:footstep_concrete_001.ogg (0 ms)
* `boss:baahemoth`: erst während der Messung geladen: audio:impactPunch_medium_000.ogg (0 ms), audio:impactPunch_heavy_001.ogg (0 ms), audio:lowDown.ogg (0 ms), audio:impactPunch_heavy_000.ogg (0 ms), audio:footstep_concrete_001.ogg (0 ms)
* `boss:marquise`: erst während der Messung geladen: audio:impactPunch_medium_000.ogg (0 ms), audio:impactPunch_heavy_001.ogg (0 ms), audio:phaserDown2.ogg (0 ms), audio:phaseJump1.ogg (0 ms), audio:impactPunch_heavy_000.ogg (0 ms)
* `boss:zephyros`: erst während der Messung geladen: audio:impactPunch_heavy_001.ogg (0 ms), audio:phaseJump2.ogg (0 ms), audio:footstep_concrete_002.ogg (0 ms), audio:footstep_concrete_001.ogg (0 ms), audio:footstep_concrete_000.ogg (0 ms)
* `mode:athlon`: erst während der Messung geladen: audio:drumroll.ogg (1 ms), audio:tone1.ogg (0 ms), audio:threeTone1.ogg (0 ms), audio:mg1_normal.ogg (2 ms), audio:impactBell_heavy_000.ogg (0 ms)
* `mode:colosseum`: erst während der Messung geladen: npc/bear (1 ms), audio:impactBell_heavy_000.ogg (0 ms), audio:impactPunch_heavy_001.ogg (0 ms), audio:magic_b.ogg (0 ms), audio:creak2.ogg (0 ms)
* `mode:kitchen`: erst während der Messung geladen: audio:impactBell_heavy_000.ogg (0 ms), audio:tick_001.ogg (0 ms), audio:impactWood_heavy_001.ogg (0 ms), audio:impactWood_heavy_000.ogg (0 ms), audio:powerUp5.ogg (1 ms)
* `mg:plank_panic`: erst während der Messung geladen: audio:impactPunch_heavy_001.ogg (0 ms), audio:impactSoft_heavy_002.ogg (0 ms), audio:whistle_fall.ogg (0 ms), audio:bong_001.ogg (0 ms), audio:evil_laugh.ogg (0 ms)
* `mg:dungeon_drop`: erst während der Messung geladen: audio:impactMining_002.ogg (1 ms), audio:impactPunch_medium_000.ogg (0 ms), audio:impactMining_000.ogg (0 ms), audio:phaseJump1.ogg (0 ms), audio:creak3.ogg (0 ms)
* `mg:kart_bowling`: erst während der Messung geladen: audio:impactMining_001.ogg (0 ms), audio:impactMetal_light_000.ogg (0 ms), audio:impactSoft_heavy_001.ogg (0 ms), audio:impactPunch_medium_000.ogg (0 ms), audio:impactMetal_light_001.ogg (0 ms)
* `mg:treasure_zipline`: erst während der Messung geladen: audio:boing.ogg (0 ms), audio:handleCoins.ogg (0 ms), audio:powerUp2.ogg (1 ms), audio:pepSound2.ogg (0 ms), audio:powerUp5.ogg (0 ms)
* `mg:ghost_castle`: erst während der Messung geladen: audio:impactPunch_heavy_000.ogg (0 ms), audio:forceField_003.ogg (1 ms), audio:evil_laugh.ogg (0 ms), audio:impactPunch_medium_000.ogg (0 ms), audio:powerUp7.ogg (0 ms)
* `mg:barrel_chaos`: erst während der Messung geladen: audio:phaserDown1.ogg (0 ms), audio:impactWood_heavy_001.ogg (0 ms), audio:impactWood_heavy_000.ogg (0 ms), audio:drumroll.ogg (1 ms), audio:explosionCrunch_002.ogg (0 ms)
* `mg:lava_surf`: erst während der Messung geladen: audio:phaserDown2.ogg (0 ms), audio:impactPunch_heavy_001.ogg (0 ms), audio:pepSound2.ogg (0 ms), audio:thrusterFire_000.ogg (1 ms), audio:impactPunch_heavy_000.ogg (0 ms)
* `mg:tower_balance`: erst während der Messung geladen: audio:impactMining_000.ogg (0 ms), audio:phaseJump2.ogg (0 ms), audio:phaserDown1.ogg (1 ms), audio:feedback_alert.ogg (1 ms), audio:hurry_up.ogg (0 ms)
* `mg:hot_bomb`: erst während der Messung geladen: audio:impactSoft_heavy_000.ogg (0 ms), audio:explosionCrunch_002.ogg (1 ms), audio:lowFrequency_explosion_000.ogg (0 ms), audio:bong_001.ogg (0 ms), audio:impactBell_heavy_000.ogg (0 ms)
* `mg:slime_sprint`: erst während der Messung geladen: audio:phaseJump2.ogg (0 ms), audio:impactSoft_heavy_001.ogg (0 ms), audio:impactMetal_heavy_000.ogg (0 ms), audio:phaseJump1.ogg (0 ms), audio:impactSoft_medium_001.ogg (0 ms)
* `mg:coin_rain`: erst während der Messung geladen: audio:impactPunch_medium_000.ogg (0 ms), audio:pepSound2.ogg (0 ms), audio:explosionCrunch_001.ogg (1 ms), audio:impactPunch_heavy_000.ogg (0 ms), audio:explosionCrunch_002.ogg (0 ms)
* `mg:sumo_shove`: erst während der Messung geladen: audio:impactSoft_heavy_000.ogg (0 ms), audio:impactPunch_heavy_000.ogg (0 ms), audio:phaserDown1.ogg (0 ms), audio:phaseJump2.ogg (0 ms), audio:impactPunch_heavy_001.ogg (0 ms)
* `mg:snowball_fight`: erst während der Messung geladen: audio:phaseJump2.ogg (0 ms), audio:pluck_001.ogg (0 ms), audio:impactSoft_medium_001.ogg (0 ms), audio:impactSoft_heavy_001.ogg (0 ms), audio:phaseJump1.ogg (0 ms)
* `mg:color_chaos`: erst während der Messung geladen: audio:impactPunch_medium_000.ogg (0 ms), audio:slime_001.ogg (1 ms), audio:impactPunch_heavy_000.ogg (0 ms), audio:feedback_alert.ogg (0 ms), audio:hurry_up.ogg (0 ms)
* `mg:hammer_hop`: erst während der Messung geladen: audio:bong_001.ogg (0 ms), audio:impactWood_heavy_001.ogg (0 ms), audio:creak1.ogg (0 ms), audio:impactWood_heavy_000.ogg (0 ms), audio:creak2.ogg (0 ms)
* `mg:fish_catch`: erst während der Messung geladen: audio:impactSoft_heavy_002.ogg (0 ms), audio:pepSound2.ogg (0 ms), audio:powerUp7.ogg (0 ms), audio:slime_001.ogg (2 ms), audio:feedback_alert.ogg (1 ms)
* `mg:meteor_dodge`: erst während der Messung geladen: audio:explosionCrunch_001.ogg (0 ms), audio:bong_001.ogg (0 ms), audio:impactBell_heavy_000.ogg (0 ms), audio:explosionCrunch_000.ogg (0 ms), audio:explosionCrunch_002.ogg (1 ms)
* `mg:rhythm_dance`: erst während der Messung geladen: audio:feedback_alert.ogg (0 ms), audio:hurry_up.ogg (0 ms), audio:tick_002.ogg (0 ms), audio:tick_001.ogg (0 ms), audio:impactBell_heavy_000.ogg (0 ms)
* `mg:minigolf_duel`: erst während der Messung geladen: audio:boing.ogg (0 ms), audio:impactWood_heavy_000.ogg (0 ms), audio:impactMetal_light_001.ogg (0 ms), audio:magic_h2.ogg (0 ms), audio:handleCoins2.ogg (1 ms)
* `mg:balloon_battle`: erst während der Messung geladen: audio:powerUp10.ogg (0 ms), audio:impactSoft_heavy_001.ogg (0 ms), audio:thrusterFire_002.ogg (1 ms), audio:boing.ogg (0 ms), audio:explosionCrunch_002.ogg (1 ms)
* `mg:flower_rush`: erst während der Messung geladen: audio:pluck_002.ogg (0 ms), audio:impactPlank_medium_001.ogg (1 ms), audio:phaserDown1.ogg (1 ms), audio:impactPlank_medium_000.ogg (0 ms), audio:pluck_001.ogg (0 ms)
* `mg:plush_balls`: erst während der Messung geladen: audio:drop_002.ogg (0 ms), audio:phaseJump1.ogg (0 ms), audio:impactSoft_heavy_001.ogg (0 ms), audio:boing.ogg (0 ms), audio:phaseJump2.ogg (0 ms)
* `mg:sleepy_stars`: erst während der Messung geladen: audio:impactBell_heavy_000.ogg (0 ms), audio:sad_trombone.ogg (0 ms), audio:bong_001.ogg (0 ms), audio:pluck_001.ogg (0 ms), audio:feedback_alert.ogg (0 ms)
* `mg:pumpkin_toss`: erst während der Messung geladen: audio:impactMining_001.ogg (0 ms), audio:phaserDown1.ogg (0 ms), audio:impactMining_000.ogg (0 ms), audio:impactBell_heavy_000.ogg (0 ms)
* `mg:tug_of_war`: erst während der Messung geladen: audio:feedback_alert.ogg (0 ms), audio:hurry_up.ogg (0 ms), audio:tick_002.ogg (0 ms), audio:tick_001.ogg (0 ms), audio:impactBell_heavy_000.ogg (0 ms)
* `mg:honey_chase`: erst während der Messung geladen: audio:slime_000.ogg (0 ms), audio:phaseJump2.ogg (0 ms), audio:phaseJump1.ogg (0 ms), audio:impactPunch_heavy_000.ogg (0 ms), audio:impactBell_heavy_000.ogg (0 ms)
* `mg:hollow_hide`: erst während der Messung geladen: audio:magic_u.ogg (0 ms), audio:magic_h.ogg (0 ms), audio:whistle_up.ogg (0 ms), audio:impactBell_heavy_000.ogg (1 ms)
* `mg:rail_express`: erst während der Messung geladen: audio:phaseJump1.ogg (0 ms), audio:phaseJump2.ogg (1 ms), audio:impactBell_heavy_000.ogg (0 ms)
* `mg:star_hoops`: erst während der Messung geladen: audio:powerUp7.ogg (1 ms), audio:impactPunch_medium_000.ogg (0 ms), audio:impactPunch_heavy_000.ogg (0 ms), audio:boing.ogg (0 ms), audio:feedback_alert.ogg (1 ms)
* `mg:lucky_bells`: erst während der Messung geladen: audio:pluck_002.ogg (0 ms), audio:pluck_001.ogg (0 ms)
* `mg:chest_sniff`: erst während der Messung geladen: audio:handleCoins2.ogg (0 ms), audio:doorOpen_1.ogg (0 ms), audio:powerUp7.ogg (0 ms), audio:pepSound2.ogg (0 ms), audio:forceField_003.ogg (0 ms)
* `mg:boss_cloud`: erst während der Messung geladen: audio:impactPunch_medium_000.ogg (0 ms), audio:impactPunch_heavy_000.ogg (0 ms), audio:impactPunch_heavy_001.ogg (0 ms), audio:bong_001.ogg (0 ms), audio:footstep_grass_001.ogg (1 ms)
* `mg:ghost_photo`: erst während der Messung geladen: audio:magic_e.ogg (0 ms), audio:handleCoins.ogg (0 ms), audio:pepSound2.ogg (0 ms), audio:magic_h2.ogg (0 ms), audio:magic_b.ogg (0 ms)
* `mg:cheese_brawl`: erst während der Messung geladen: audio:evil_laugh.ogg (0 ms), audio:scratch_003.ogg (0 ms), audio:feedback_woop.ogg (0 ms), audio:bong_001.ogg (0 ms), audio:scratch_001.ogg (0 ms)
* `mg:penguin_curling`: erst während der Messung geladen: audio:impactWood_heavy_001.ogg (0 ms), audio:scratch_003.ogg (0 ms), audio:impactWood_heavy_000.ogg (0 ms), audio:boing.ogg (0 ms)
* `mg:bubble_ballet`: erst während der Messung geladen: audio:boing.ogg (0 ms), audio:feedback_alert.ogg (0 ms), audio:hurry_up.ogg (0 ms), audio:tick_002.ogg (0 ms), audio:tick_001.ogg (0 ms)
* `mg:sleepwalk`: erst während der Messung geladen: audio:footstep_wood_000.ogg (1 ms), audio:footstep_wood_002.ogg (1 ms), audio:impactWood_heavy_001.ogg (0 ms), audio:powerUp7.ogg (0 ms), audio:impactBell_heavy_000.ogg (0 ms)
* `mg:bumper_balls`: erst während der Messung geladen: audio:thrusterFire_002.ogg (1 ms), audio:phaserUp3.ogg (0 ms), audio:footstep_concrete_002.ogg (0 ms), audio:footstep_concrete_001.ogg (1 ms), audio:footstep_concrete_000.ogg (0 ms)
* `mg:log_bridge`: erst während der Messung geladen: audio:impactWood_heavy_000.ogg (0 ms), audio:phaseJump2.ogg (0 ms), audio:impactWood_heavy_001.ogg (0 ms), audio:phaseJump1.ogg (0 ms), audio:impactMining_001.ogg (0 ms)
* `mg:spark_carousel`: erst während der Messung geladen: audio:laser6.ogg (0 ms), audio:zap1.ogg (1 ms), audio:zap2.ogg (0 ms), audio:feedback_alert.ogg (1 ms), audio:bong_001.ogg (0 ms)
* `mg:sandwich_storm`: erst während der Messung geladen: audio:slime_001.ogg (1 ms), audio:slime_000.ogg (0 ms), audio:phaseJump1.ogg (0 ms), audio:impactSoft_heavy_001.ogg (0 ms), audio:bong_001.ogg (0 ms)
* `mg:stomp_waves`: erst während der Messung geladen: audio:impactPunch_medium_000.ogg (0 ms), audio:impactPunch_heavy_001.ogg (0 ms), audio:impactSoft_medium_000.ogg (0 ms), audio:impactMining_000.ogg (0 ms), audio:bong_001.ogg (0 ms)
* `mg:boulder_run`: erst während der Messung geladen: audio:phaseJump2.ogg (0 ms), audio:impactMining_002.ogg (2 ms), audio:handleCoins2.ogg (0 ms), audio:impactWood_heavy_000.ogg (0 ms), audio:impactPlank_medium_000.ogg (0 ms)
* `mg:ice_floes`: erst während der Messung geladen: audio:phaserDown1.ogg (0 ms), audio:impactPlank_medium_000.ogg (0 ms), audio:impactPunch_medium_000.ogg (0 ms), audio:impactSoft_medium_001.ogg (0 ms), audio:slime_001.ogg (1 ms)
* `mg:nail_pro`: erst während der Messung geladen: audio:impactMining_000.ogg (1 ms), audio:handleCoins2.ogg (0 ms), audio:impactWood_heavy_001.ogg (0 ms), audio:feedback_alert.ogg (0 ms), audio:hurry_up.ogg (0 ms)
* `mg:jetpack_rally`: erst während der Messung geladen: audio:lowFrequency_explosion_001.ogg (0 ms), audio:zap1.ogg (0 ms), audio:phaseJump2.ogg (0 ms), audio:zap2.ogg (0 ms), audio:footstep_concrete_000.ogg (0 ms)
* `mg:sled_edge`: erst während der Messung geladen: audio:scratch_001.ogg (0 ms), audio:whistle_fall.ogg (0 ms), audio:magic_e.ogg (0 ms), audio:magic_a.ogg (0 ms), audio:footstep_snow_000.ogg (1 ms)
* `mg:ice_coins`: erst während der Messung geladen: audio:impactPunch_heavy_001.ogg (0 ms), audio:magic_b.ogg (0 ms), audio:magic_l.ogg (0 ms), audio:impactPunch_heavy_000.ogg (0 ms), audio:magic_d.ogg (0 ms)
* `mg:pickaxe_dash`: erst während der Messung geladen: audio:footstep_snow_001.ogg (0 ms), audio:magic_j.ogg (0 ms), audio:footstep_snow_000.ogg (0 ms), audio:impactMetal_light_000.ogg (0 ms), audio:feedback_alert.ogg (1 ms)
* `mg:bridge_bluff`: erst während der Messung geladen: audio:tick_002.ogg (0 ms), audio:impactSoft_medium_000.ogg (0 ms), audio:magic_d.ogg (0 ms), audio:impactPlank_medium_000.ogg (0 ms), audio:thrusterFire_000.ogg (2 ms)
* `mg:ufo_heist`: erst während der Messung geladen: audio:cannon.ogg (0 ms), audio:explosionCrunch_000.ogg (0 ms), audio:laserRetro_001.ogg (1 ms), audio:bong_001.ogg (0 ms), audio:thrusterFire_000.ogg (1 ms)
* `mg:switch_gauntlet`: erst während der Messung geladen: audio:feedback_woom.ogg (0 ms), audio:drop_002.ogg (0 ms), audio:phaseJump2.ogg (0 ms), audio:impactPunch_heavy_000.ogg (0 ms), audio:impactSoft_heavy_000.ogg (0 ms)
* `mg:bomb_defuse`: erst während der Messung geladen: audio:slime_001.ogg (1 ms), audio:slime_000.ogg (0 ms), audio:boing.ogg (0 ms), audio:feedback_alert.ogg (0 ms), audio:hurry_up.ogg (0 ms)
* `mg:axis_taxi`: erst während der Messung geladen: audio:impactMetal_heavy_001.ogg (0 ms), audio:magic_d.ogg (0 ms), audio:magic_p.ogg (0 ms), audio:feedback_alert.ogg (1 ms), audio:hurry_up.ogg (1 ms)
* `mg:memory_match`: erst während der Messung geladen: audio:feedback_negative.ogg (1 ms), audio:magic_h2.ogg (1 ms)
* `mg:beach_volley`: erst während der Messung geladen: audio:impactPunch_medium_000.ogg (0 ms), audio:impactBell_heavy_000.ogg (0 ms), audio:impactMining_002.ogg (0 ms), audio:impactPunch_heavy_001.ogg (0 ms), audio:impactMining_001.ogg (0 ms)
* `mg:pedal_boat`: erst während der Messung geladen: audio:magic_p.ogg (0 ms), audio:impactWood_heavy_001.ogg (0 ms), audio:impactMetal_light_000.ogg (0 ms), audio:magic_c.ogg (1 ms), audio:slime_001.ogg (2 ms)
* `mg:veggie_harvest`: erst während der Messung geladen: audio:magic_l.ogg (0 ms), audio:footstep_snow_001.ogg (0 ms), audio:footstep_snow_002.ogg (0 ms), audio:handleCoins.ogg (0 ms), audio:impactPunch_medium_000.ogg (0 ms)
* `mg:quick_fishing`: erst während der Messung geladen: audio:magic_h2.ogg (1 ms), audio:slime_001.ogg (3 ms), audio:feedback_alert.ogg (1 ms), audio:handleCoins2.ogg (0 ms), audio:impactSoft_heavy_002.ogg (0 ms)
* `mg:slap_carousel`: erst während der Messung geladen: audio:phaseJump2.ogg (0 ms), audio:impactPunch_heavy_000.ogg (0 ms), audio:impactSoft_heavy_001.ogg (0 ms), audio:impactPunch_heavy_001.ogg (0 ms), audio:impactSoft_heavy_000.ogg (0 ms)
* `mg:marble_maze`: erst während der Messung geladen: audio:impactMining_002.ogg (0 ms), audio:magic_l.ogg (0 ms), audio:magic_d.ogg (0 ms), audio:impactBell_heavy_000.ogg (0 ms)
* `mg:stone_bowling`: erst während der Messung geladen: audio:impactMining_002.ogg (0 ms), audio:impactMining_001.ogg (0 ms), audio:jingles_NES14.ogg (0 ms), audio:click3.ogg (0 ms), audio:impactBell_heavy_000.ogg (0 ms)
* `mg:mega_bee`: erst während der Messung geladen: audio:feedback_alert.ogg (0 ms), audio:phaserDown2.ogg (0 ms), audio:impactMining_002.ogg (0 ms), audio:phaseJump1.ogg (0 ms), audio:boing.ogg (0 ms)
* `mg:prize_drop`: erst während der Messung geladen: audio:boing.ogg (0 ms), audio:handleCoins.ogg (1 ms), audio:handleCoins2.ogg (0 ms), audio:magic_d.ogg (0 ms), audio:impactBell_heavy_000.ogg (0 ms)
* `mg:coaster_shooter`: erst während der Messung geladen: audio:impactPunch_heavy_000.ogg (0 ms), audio:impactPunch_medium_000.ogg (0 ms), audio:feedback_alert.ogg (0 ms), audio:hurry_up.ogg (0 ms), audio:tick_002.ogg (0 ms)
* `mg:stone_skip`: erst während der Messung geladen: audio:magic_a.ogg (0 ms), audio:slime_001.ogg (1 ms), audio:impactSoft_heavy_002.ogg (0 ms), audio:impactBell_heavy_000.ogg (0 ms)
* `mg:ghost_manor`: erst während der Messung geladen: audio:impactPunch_heavy_000.ogg (0 ms), audio:magic_c.ogg (0 ms), audio:powerUp7.ogg (0 ms), audio:impactBell_heavy_000.ogg (0 ms)
