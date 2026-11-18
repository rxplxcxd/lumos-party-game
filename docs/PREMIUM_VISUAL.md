# Premium-Visual-Überarbeitung (1.5.4) – Abschlussbericht

Ziel: bestehendes Spiel sichtbar hochwertiger, einheitlicher und technisch sauber – ohne neue Spielsysteme.
Basis: `f1e251b5` (Stand nach 1.5.3 + hochgeladene Asset-Zips). Arbeitszweig `claude/elegant-johnson-2kfiut`,
`main` unverändert. Verbindliche Regeln: [VISUAL_STANDARD.md](VISUAL_STANDARD.md).

## A. Assets

### A.1 JulioVII – alle kostenlosen Texturpakete mit „Stylized“ im Produkttitel

Quelle: Creator-Seite https://juliovii.itch.io (106 Einträge geprüft). **14 Pakete** erfüllen die Bedingungen
(„Stylized“ im Titel, Texturpaket, kostenlos/Name your own price). Geladen ausschließlich über den Gratis-Weg
(„No thanks, just take me to the downloads“). Die Gratis-Downloadseite bietet nur die Texturarchive an; die laut
Produktseite kostenpflichtigen Substance-Quellen (SBS/SBSAR) erscheinen dort nicht und wurden nicht geladen.

**Nicht geladen:** „3D Asset: Stylized Gravestones / Beer Mugs / Flasks“ (3D-Modelle, keine Texturpakete), alle
„99 Procedural Materials Pack“-Bände (kostenpflichtig, 6,99 $), Pakete ohne „Stylized“ im Titel, Realistic-Pakete.

**Lizenz** (Produktseite, je Paket identisch): „This pack is licensed CC-BY. … Any commercial application is allowed
except reselling.“ → Namensnennung im Spiel (Credits) und in `LICENSES.md`.

**Archiv:** Die Originale (1,1 GB, größte Datei 462 MB > GitHub-Grenze 100 MB) liegen nicht im Repository; Prüfsummen
und Inhalt in `data/juliovii_manifest.json`, erneuter Abruf mit `tools/assets/fetch_juliovii.py` (prüft SHA-256 –
getestet: byte-gleich). Das bereits hochgeladene `Stylized_GrassAndDirt.zip` ist byte-gleich mit dem Original.

| Paket | Quelle | Download / Integrität | Lizenz | Materialien | Auflösungen | Kanäle | Formate |
|---|---|---|---|---|---|---|---|
| Materials Stylized Concrete | [fmp-stylized-concrete](https://juliovii.itch.io/fmp-stylized-concrete) | ✅ 28 MB, ZIP intakt, SHA-256 b4102e96a472… | CC BY 4.0 | 9 | 4096² ×63 | AO/BaseColor/Height/Metallic/Normal/Roughness | JPG (+ .blend) |
| Stylized Bricks & Pavement | [ftp-bricks-pavement](https://juliovii.itch.io/ftp-bricks-pavement) | ✅ 54 MB, intakt, 3c0a4d111aaf… | CC BY 4.0 | 9 | 4096² ×63 | AO/BaseColor/Height/Metallic/Normal/Roughness | JPG (+ .blend) |
| Stylized Metals 01 | [ftp-metals-01](https://juliovii.itch.io/ftp-metals-01) | ✅ 36 MB, intakt, 37500e14facd… | CC BY 4.0 | 9 | 4096² ×56, 2048² ×7 | AO/BaseColor/Height/Metallic/Normal/Roughness | JPG (+ .blend) |
| Stylized Stone & Wood 02 | [ftp-stone-wood-02](https://juliovii.itch.io/ftp-stone-wood-02) | ✅ 37 MB, intakt, fd2ae2a0cadf… | CC BY 4.0 | 9 | 4096² ×50 | AO/BaseColor/Height/Normal/Roughness | JPG (+ .blend) |
| Texture Pack: Stylized 03 | [ftp-stylized-03](https://juliovii.itch.io/ftp-stylized-03) | ✅ 462 MB, intakt, b3b03bdc89a1… | CC BY 4.0 | 15 | 4096² ×120 | AO/BaseColor/Gloss/Height/Metallic/Normal/Roughness | JPG (+ .blend, .hdr) |
| Materials Stylized Bricks & Plaster | [ftp-stylized-bricks-plaster](https://juliovii.itch.io/ftp-stylized-bricks-plaster) | ✅ 30 MB, intakt, a224d97b438d… | CC BY 4.0 | 9 | 4096² ×63 | AO/BaseColor/Height/Metallic/Normal/Roughness | JPG (+ .blend) |
| Materials Stylized Metal Panels | [ftp-stylized-metal-panels](https://juliovii.itch.io/ftp-stylized-metal-panels) | ✅ 52 MB, intakt, d19b4e22c041… | CC BY 4.0 | 9 | 4096² ×67 | AO/BaseColor/Height/Metallic/Normal/Roughness | JPG (+ .blend) |
| Materials Stylized Mix Stones 01 | [ftp-stylized-mix-stones-01](https://juliovii.itch.io/ftp-stylized-mix-stones-01) | ✅ 40 MB, intakt, 56dd1996a486… | CC BY 4.0 | 9 | 4096² ×67 | AO/BaseColor/Emission/Height/Metallic/Normal/Roughness | JPG (+ .blend) |
| Materials Stylized Ceramic Tiles 01 | [ftp-stylizedceramictiles01](https://juliovii.itch.io/ftp-stylizedceramictiles01) | ✅ 31 MB, intakt, c5c34985698e… | CC BY 4.0 | 9 | 4096² ×63 | AO/BaseColor/Height/Metallic/Normal/Roughness | JPG (+ .blend) |
| Stylized Grass & Dirt | [ftpgrass-dirt](https://juliovii.itch.io/ftpgrass-dirt) | ✅ 20 MB, intakt, 706bddc944f2… (= Repo-Upload) | CC BY 4.0 | 9 | 4096² ×62 | AO/BaseColor/Height/Metallic/Normal/Roughness | JPG (+ .blend) |
| Stylized Bricks 01 | [ftpstylized-bricks-01](https://juliovii.itch.io/ftpstylized-bricks-01) | ✅ 68 MB, intakt, bcfd79357d3e… | CC BY 4.0 | 9 | 4096² ×63 | AO/BaseColor/Height/Metallic/Normal/Roughness | JPG (+ .blend) |
| Stylized Stone & Wood | [stylized-stone-wood](https://juliovii.itch.io/stylized-stone-wood) | ✅ 33 MB, intakt, 2c76254cf89e… | CC BY 4.0 | 9 | 4096² ×63 | AO/BaseColor/Height/Metallic/Normal/Roughness | JPG (+ .blend) |
| Texture Pack: Stylized 01 | [stylizedpk01](https://juliovii.itch.io/stylizedpk01) | ✅ 101 MB, intakt, fd85b1ca804b… | CC BY 4.0 | 9 | 4096² ×64, 2048² ×8 | AO/BaseColor/Gloss/Height/Metallic/Normal/Roughness | JPG (+ .blend, .hdr) |
| Texture Pack: Stylized 02 | [stylizedpk02](https://juliovii.itch.io/stylizedpk02) | ✅ 107 MB, intakt, e617715e4014… | CC BY 4.0 | 9 | 4096² ×72 | AO/BaseColor/Gloss/Height/Metallic/Normal/Roughness | JPG (+ .blend, .hdr) |

Summe: 132 Materialien, fast alle 4096² (JPG), Normalen durchgehend OpenGL-Konvention (geprüft: Korrelation
Grün-Kanal ↔ Höhengradient +0,34 … +0,97 in allen 14 Paketen). **Eignung:** handgemalt-stilisiert, weiche Formen,
passt zum Cozy-Look; 4K ist für das Spiel überdimensioniert → verkleinert auf 512²/1024².

**Ausgewählt (25 Familien, alle im Spiel verwendet)** – Quelle → Familie: HandpaintedGrass_01 → `grass`, HandpaintedGrassAndDirt_01 →
`meadow`, HandpaintedDirt_01 → `dirt`, HandpaintedSand_01 → `sand`, Stylized_06_Sand → `dune`, HandpaintedStones_03 →
`pebbles`, HandpaintedStones_02 → `flagstone`, Stylized_02_Stone_Ground → `cobble_moss`, Stone_01 → `rock`, Stone_04 →
`cliff`, StoneTiles_01 → `stone_wall`, Rounded_Bricks_01 → `bricks`, Plaster_01 → `plaster`, Stylized_03_Wood_Planks →
`planks`, Wood_01 → `wood`, WoodBark_02 → `bark`, Stylized_13_RoofSquare → `roof`, BaseMetal_01 → `metal`,
Stylized_08_Snow → `snow`, Stylized_18_Ice → `ice`, CeramicTiles_02 → `tiles`, BricksPavement_04 → `paving`,
Concrete_01 → `concrete`, LavaRock_01 → `lava_rock`, Stylized_22_Tatami → `fabric`. Zunächst aufbereitet, mangels
Einsatzort wieder entfernt: MetalPanels_01, CeramicTilingFloor_02, Stylized_33_Mud. Nicht ausgewählt (107): Dubletten in Funktion
(z. B. 9 rote Ziegelvarianten), zu kräftige Sondermuster (Alien-Eier, Fischschuppen, Leder-Sofa), Metallgitter/-paneele
ohne Einsatzort.

### A.2 Hochgeladene GitHub-Assets (Repo-Wurzel)

| Datei | Inhalt | Lizenz | Ergebnis |
|---|---|---|---|
| `Stylized_GrassAndDirt.zip` | JulioVII-Paket (s. o.) | CC BY 4.0 | **genutzt** (grass, meadow, dirt, sand, pebbles, flagstone) |
| `kenney_nature-kit.zip` | 329 Modelle | CC0 | byte-gleich mit `assets/3d/tracks-enviroment/kenney_nature-kit` (329/329 GLB) – Dublette, nicht erneut importiert; Material-Fehler darin behoben (s. B) |
| `kenney_mini-arena.zip` | 22 Modelle | CC0 | byte-gleich mit vorhandenem Paket (22/22) – Dublette |
| `kenney_interface-sounds.zip` | 100 OGG | CC0 | byte-gleich mit `assets/audio/kenney_interface-sounds (1)` (100/100) – Dublette |
| `kenney_input-prompts_1.5.zip` | 3056 PNG, 1504 SVG | CC0 | die 656 genutzten PNG sind byte-gleich vorhanden; Rest betrifft weitere Geräte-Layouts – kein Bedarf |
| `kenney_skyboxes-space.zip`, `kenney_skyboxes.zip` | 10 Panoramen 4096×2048 (gemalt) | CC0 | geprüft, passt stilistisch – derzeit **kein Einsatzort**: die Umgebungen „space“/„station“ nutzt keine Szene (Sternwarte/Orbit nutzen „observatory“ mit Horizontverlauf, den ein Panorama zerstören würde) |
| `kenney_casino-audio.zip` | 55 OGG (Karten, Chips, Würfel) | CC0 | geprüft – Würfelgeräusche passen nicht zum Würfelblock-Schlag des Bretts, Münzen haben eigene Klänge; nicht eingesetzt |
| `kenney_board-game-icons.zip` | 513 PNG / 256 SVG | CC0 | geprüft – HUD nutzt bereits „Board Game Info“; kein Mehrwert ohne neue UI-Funktionen |
| `mobile-controls-1.zip` | 29 PNG (Kenney Mobile Controls) | CC0 laut kenney.nl, Lizenzdatei fehlt im Zip | geprüft – Touch-Steuerung ist eigens gezeichnet (3D-Knöpfe, Druckanimation) und hochwertiger; nicht eingesetzt |
| `GodotWaterSource.zip` | 2 Wasser-Shader (Toon/Standard) | **keine Lizenzangabe** | technisch geprüft: braucht `DEPTH_TEXTURE` + Bildschirm-Refraktion (zusätzlicher Kopierschritt, im Browser teuer; das Spielwasser ist bewusst deckend). Idee (Flachwasser + Schaum am Ufer) als eigener Uferring umgesetzt (`shore.gdshader`), Code nicht übernommen |
| `SourceCode 2.zip` | Himmels-Shader (Tag/Nacht, Wolken aus 7× 1024²-Rauschtexturen) | **keine Lizenzangabe** | nicht eingesetzt: Rauschtexturen entstehen beim Laden (Sekunden im Browser), Lizenz ungeklärt |
| `SourceCode.zip` | „BinbunGrass“ – 10 000 Gras-Quads (MultiMesh, Alpha) | **keine Lizenzangabe** | nicht eingesetzt: Überzeichnung durch Alpha-Gras auf Mobilgeräten, Lizenz ungeklärt |
| `duck.zip` | Low-Poly-Ente (GLB 27 KB, Textur 512²) | **keine Lizenzangabe** | nicht eingesetzt bis zur Klärung der Lizenz |

Alle Zips bleiben unverändert im Repository (nichts gelöscht oder überschrieben).

## B. Lumos-Materialsystem

| Baustein | Datei | Aufgabe |
|---|---|---|
| Aufbereitung | `tools/assets/build_surfaces.py` + `tools/assets/surfaces_src.json` | 25 Familien aus den Originalarchiven: Kastenfilter-Verkleinerung (kachelbar, nie hochskaliert), AO eingebacken, Detailfarbe normiert (Helligkeit × gedämpfter Farbton), Rauheit im Alphakanal, Normalen renormiert |
| Laufzeitwerte | `scripts/core/surface_stats.gd` (erzeugt) | Normierung je Familie (linear `k`, sRGB `ks`), Mittelfarbe |
| Shader | `assets/shaders/lumos_surface.gdshader` | triplanar im Welt- oder Objektraum, Palettenfarbe × Detail, asymmetrisches Detail, Großflächen-Variation, Ausblenden zur Ferne, drei Stufen über ein Uniform, farbraumunabhängig |
| Bibliothek | `scripts/core/lumos_materials.gd` | Familien-Parameter, Cache je (Familie, Farbe, Optionen), Freigabe je Szenenwechsel und beim Beenden, Stufe bei Grafikwechsel nachziehen, doppelseitige Variante |
| Modell-Vereinheitlichung | `LumosMaterials.normalize_model` / `apply_to_model` (in `Assets._instantiate`) | metallic = 1 → 0 (Nature/Space Kit), Plastikglanz < 0,45 → 0,55, sprechende Materialnamen → Detail im Objektraum |
| Uferkante | `assets/shaders/shore.gdshader`, `WorldKit.shore()` | Flachwasser-Verlauf + wandernder Schaum am Inselrand (ersetzt die Tiefen-/Refraktionsidee des hochgeladenen Wasser-Shaders ohne Bildschirmkopie) |
| Einbindung | `WorldKit.surface()`, `family`-Parameter von `box/boxes/cylinder`, Kurzform `"familie@stärke"` | ein Wort am Aufruf genügt; ohne Familie bleibt alles wie bisher |
| Einstellung | „Oberflächen-Details“ (Einstellungen, Standard an) | aus = bisheriges einfarbiges Material (Rückfall) |

**Familien:** grass, meadow, dirt, sand, dune, pebbles, flagstone, cobble_moss, rock, cliff, stone_wall, bricks, plaster,
planks, wood, bark, roof, metal, snow, ice, tiles, paving, concrete, lava_rock, fabric (25) –
Parameter (Kachel, Rauheit, Metallic, Stärken) in `LumosMaterials.FAMILIES`, Regeln in `VISUAL_STANDARD.md`.

**Grafikstufen (Qualitätsprofile):** Niedrig = nur Detailfarbe (flache Böden 1 Texturzugriff), Mittel = + Normalmap der
Hauptprojektion (an Umschaltstellen weich ausgeblendet), Hoch/Ultra = Normalmap aller Projektionen + Großflächen-
Variation. Farbe in allen Stufen weich überblendet (anfangs harte Einzelprojektion → Naht auf runden Seitenwänden,
behoben). Wechsel der Grafikstufe wirkt sofort (Uniform), die Einstellung „Oberflächen-Details“ ab der nächsten Szene.

**Wichtigster technischer Befund:** Der Compatibility-Renderer dieses Builds rechnet **ohne Linear-Umrechnung** –
weder Texturen mit `source_color` noch Farb-Uniforms werden dekodiert (`tools/dev/srgb_probe.gd`: Uniform 0,5 → 0,502,
Rohwert 0,5 → 0,502). Eine linear berechnete Normierung machte alle Flächen ~30 % heller (Messung
`tools/dev/surface_probe.gd --neutral --raw=det`: 1,29 statt 1,0). Der Shader erkennt den Modus jetzt selbst und bleibt
auf beiden Wegen farbtreu: Lumos ohne Detail = altes Material Pixel für Pixel; mit Detail ±1 % Mittelwert.

## C. Visuelle Prüfung (Audit)

Methode: feste Kameras und fester Zufall (`material_shot.gd`, `board_life_shot.gd --views=nah,weit`, `track_shot.gd`,
`minigame_shot.gd --quality=high`), Vorher = unveränderte Arbeitskopie von `f1e251b5`, gleiche Auflösung, gleiches Licht.
Materialzählung aller GLB/GLTF (`mat_census`), Texturliste aller Importe, Strecken-Geometrie (`track_check.gd`).

### C.1 Befunde und Ursachen

| Bereich | Befund | Ursache | Maßnahme |
|---|---|---|---|
| Große Flächen (Inseln, Böden, Wände, Böschungen) | einfarbig, „Platzhalter“-Wirkung, keine Oberfläche | erzeugte Primitive ohne UVs mit Flat-Material | Lumos-Oberflächen (triplanar, keine UVs nötig) |
| Kenney Nature Kit (688 Materialien, 329 Modelle) / Space Kit (463) | dunkel, spiegeln Himmelsfarbe | glTF ohne Metallic-Angabe → metallic = 1 | beim Laden auf 0 (Metall-Namen 0,5) |
| KayKit Platformer (370), Mini-Game (266), City Builder (41) | Plastikglanz (Rauheit 0,2–0,4) | Exportwerte | auf 0,55 (Glas/Leuchten/Eis/Kristall ausgenommen) |
| Farbatlas-Modelle (Kenney/KayKit `colormap`, 1 Material je Paket) | in Ordnung | Palette ist der Stil | unverändert |
| Große Inseln (Zylinder r = 9–31 m) | Kanten im Umriss | 64 Segmente fest | 64–128 nach Radius |
| Uferlinien | harter Schnitt Wasser/Sand | kein Übergang | Uferring (Flachwasser + Schaum) |
| Strecken (7 von 12) | Fahrbahn bis 765 m je Runde unter dem Rasen | Höhen-Schließfehler über die Runde verteilt (s. E) | Anhebung beim Streckenbau |
| Texturen | Quellen 4K, Spiel nutzt 512²/1024² | – | kein 4K im Spiel; Detail per Kachel (150–350 Texel/m) |
| Kompression | Projektstandard verlustfrei (`compress/mode=0`) | richtig für Paletten (Blockkompression lässt Farbfelder bluten) | Detailtexturen als WebP (verlustbehaftet 0,85/0,9) – S3TC hätte das Web-Paket um 30 MB vergrößert (s. D.3), Paletten bleiben |
| Mipmaps / Filter | Mipmaps an (Projektstandard) | – | Detailtexturen zusätzlich anisotrop |
| Normalmaps | alle 14 Pakete OpenGL-Konvention | – | keine Umrechnung nötig, Konvention im Shader dokumentiert |
| Paket-Vorschaubilder | 1920×1080-Vorschauen (`contents.png`, `Preview.png` …) importiert | liegen in Asset-Ordnern | nicht exportiert (Exportliste nur geladene Dateien) – kein Laufzeitkosten-Befund |
| Wiederholungsmuster | bei großen Flächen sichtbar möglich | Kachel | Großflächen-Variation + Ausblenden zur Ferne |
| Nachtszenen (Friedhof, Zauberwald-Nacht) | Detail dunkelt nur ab → Nacht bleibt Nacht; Friedhof zu dunkel | asymmetrisches Detail | Friedhof halbe Stärke |

### C.2 Vorher/Nachher-Bilder

Abgelegt in `docs/screenshots/1.5.4/` (Vorher | Nachher, gleiche Kamera, gleiches Licht): Menü-Insel in drei Zuständen
(Original · neue Materialien · vollständig poliert), alle 10 Bretter (feste Nah-Kamera über dem Startfeld),
Minispiele (Spielkamera), Grafikstufen Hoch/Mittel/Niedrig, alle 12 Strecken mit je 3 festen Kameras
(`strecken_vorher_nachher_1.jpg`, `_2.jpg`: Vorher-Zeilen zeigen auf Lumos-Ring, Dschungel und Vulkan Rasen statt
Fahrbahn – die Fahrbahn lag unter der Bodenfläche, s. E.1).

## D. Leistung

Messarten nach `docs/GERAETE_TESTPLAN.md`: **Test-Server (headless, CPU)** und **simuliert (xvfb/llvmpipe,
Software-Rasterung)**. Echte Geräte standen nicht zur Verfügung – keine der Zahlen ist eine Geräte-FPS. Vorher =
Arbeitskopie `f1e251b5`, Nachher = Arbeitsstand, gleiche Ziele, nacheinander gemessen (`tools/dev/scene_profile.sh`).

### D.1 Test-Server, headless (CPU-Seite: Skripte, Physik, Animation, Laden)

| Ziel | Bildzeit Ø ms | p99 ms | 1 %-Tief FPS | Bilder > 33 ms | Laden s | Speicher MB |
|---|---|---|---|---|---|---|
| Hauptmenü | 1,80 → 1,76 | 2,9 → 2,5 | 236 → 311 | 0 → 0 | 0,69 → 0,72 | 185 → 194 |
| Brett Wuschel-Wiesen | 1,24 → 1,60 | 3,6 → 3,7 | 89 → 148 | 1 → 0 | 0,99 → 0,95 | 220 → 244 |
| Brett Piratenbucht | 1,45 → 1,60 | 4,4 → 4,0 | 109 → 135 | 1 → 1 | 0,95 → 0,88 | 232 → 239 |
| Brett Zauberwald | 1,61 → 1,41 | 3,5 → 3,7 | 166 → 166 | 0 → 0 | 0,89 → 0,89 | 227 → 233 |
| Brett Friedhof | 1,46 → 1,54 | 3,4 → 3,8 | 176 → 161 | 0 → 0 | 0,93 → 1,00 | 257 → 260 |
| Lumos-Ring | 1,88 → 1,96 | 4,0 → 4,2 | 168 → 155 | 0 → 0 | 0,77 → 0,81 | 192 → 199 |
| Gewitter-Pass | 2,19 → 2,21 | 4,3 → 4,2 | 175 → 185 | 0 → 0 | 0,79 → 0,84 | 194 → 201 |
| Wüsten-Canyon | 2,08 → 2,08 | 4,2 → 4,0 | 158 → 177 | 0 → 0 | 0,85 → 0,88 | 196 → 203 |
| Beach-Volley | 1,64 → 1,60 | 3,3 → 3,6 | 214 → 202 | 0 → 0 | 0,49 → 0,49 | 229 → 231 |
| Honig-Jagd | 0,95 → 1,06 | 2,2 → 2,3 | 261 → 349 | 0 → 0 | 0,54 → 0,49 | 204 → 207 |
| Pinguin-Curling | 1,30 → 1,24 | 7,4 → 5,6 | 113 → 147 | 0 → 0 | 0,54 → 0,52 | 227 → 229 |

CPU-Kosten im Rauschen (±0,3 ms), Ladezeit gleich, keine neuen Ruckler. Speicher +2 … +24 MB: Der Dummy-Renderer
hält die Detailtexturen unkomprimiert im Arbeitsspeicher (auf einer GPU liegen sie komprimiert im Grafikspeicher).

### D.2 Simuliert (Software-Renderer, Grafikstufe Hoch, 640×360)

| Ziel | Draw-Calls | Primitive k | Texturen MB | Videospeicher MB | Bildzeit ms (Software) | Laden s |
|---|---|---|---|---|---|---|
| Hauptmenü | 342 → 346 | 114,8 → 113,6 | 73,1 → 79,4 | 96 → 102 | 122,6 → 138,2 | 6,2 → 7,0 |
| Brett Wuschel-Wiesen | 707 → 798 | 152,9 → 176,9 | 64,3 → 76,9 | 88 → 101 | 115,3 → 163,3 | 8,1 → 10,3 |
| Brett Piratenbucht | 787 → 554 | 179,7 → 138,2 | 65,7 → 72,7 | 89 → 96 | 153,8 → 136,0 | 7,8 → 7,9 |
| Brett Zauberwald | 660 → 740 | 188,2 → 213,1 | 60,8 → 67,8 | 85 → 92 | 110,3 → 185,1 | 9,1 → 11,0 |
| Brett Friedhof | 555 → 555 | 122,7 → 122,7 | 93,3 → 97,5 | 117 → 121 | 116,5 → 153,4 | 6,5 → 8,0 |
| Lumos-Ring | 175 → 206 | 50,4 → 54,0 | 50,6 → 56,8 | 73 → 80 | 56,9 → 89,6 | 4,4 → 7,8 |
| Gewitter-Pass | 141 → 144 | 77,5 → 81,2 | 52,7 → 59,7 | 76 → 83 | 59,7 → 93,2 | 5,0 → 6,5 |
| Wüsten-Canyon | 257 → 259 | 94,1 → 94,5 | 51,5 → 58,5 | 75 → 82 | 85,2 → 139,0 | 4,5 → 6,0 |
| Beach-Volley | 300 → 307 | 70,2 → 70,8 | 54,8 → 62,3 | 78 → 86 | 85,1 → 92,1 | 4,0 → 4,6 |
| Honig-Jagd | 229 → 229 | 49,0 → 48,7 | 49,9 → 53,4 | 73 → 77 | 80,9 → 101,0 | 3,7 → 4,2 |
| Pinguin-Curling | 377 → 354 | 62,6 → 74,6 | 48,9 → 49,6 | 73 → 74 | 74,3 → 101,9 | 3,4 → 4,3 |

* Draw-Calls und Primitive schwanken mit Intro-Kamera und Figuren (Piratenbucht −233, Wiese +91) – der Shader
  ändert die Zahl der Draw-Calls nicht (ein Material je Fläche wie vorher); Strecken mit sichtbarer Fahrbahn
  (vorher unter dem Rasen verdeckt) zeichnen etwas mehr.
* **Texturspeicher** im Zwischenstand mit S3TC +4 … +13 MB je Szene; nach der Umstellung auf WebP-Speicherung (D.3)
  liegen die Detailtexturen unkomprimiert im Grafikspeicher – Werte in D.3.
* **Ladezeiten dieser Tabelle** stammen aus einem Lauf mit parallelen Jobs und sind nicht vergleichbar – ohne
  Nebenlast nachgemessen: unverändert (D.3).
* **Pixelkosten**, kontrolliert gemessen (`tools/dev/surface_cost.gd`, bildschirmfüllender Boden + Zylinder, gleiche
  Szene, nur Material verschieden; Software-Renderer): flach 34,3 ms · Stufe 0 40,9 ms (+19 %) · Stufe 1 48,5 ms
  (+41 %) · Stufe 2 47,8 ms (+39 %). Software-Rasterung bildet Texturzugriffe sehr teuer ab; auf GPUs sind 2 Zugriffe
  je Bodenpixel gering gegenüber Schatten- und Lichtberechnung. Optimierung: hinter 120 m (Detail ausgeblendet) kein
  Normalmap-Zugriff mehr – halbiert die Zugriffe auf den großen Fernböden der Kulissen.

### D.3 Web-Paket, Texturspeicher, Web-Build

**Paketgröße** (Web-Export, `index.pck`, gemessen):

| Stand | PCK | gzip (Auslieferung) |
|---|---|---|
| Original `f1e251b5` | 35,2 MB | 32,4 MB |
| Zwischenstand, Oberflächen als S3TC (BC3/RGTC) | 65,4 MB | 51,8 MB |
| **Endstand, Oberflächen als WebP (verlustbehaftet), 25 Familien, 1024² nur Gras/Sand** | **42,1 MB** | **39,2 MB** |

Die S3TC-Variante hätte den Download um 30 MB vergrößert – zu viel für Web/PWA. WebP (Albedo 0,85, Normalen 0,9)
ist im Pixelvergleich nicht unterscheidbar (`docs/screenshots/1.5.4/`), die Oberflächen belegen im Paket 6,8 MB.

**Texturspeicher** (Software-Renderer, Hoch; Original → S3TC-Zwischenstand → Endstand WebP):

| Ziel | Texturen MB | Videospeicher MB |
|---|---|---|
| Hauptmenü | 73,1 → 79,4 → 95,1 | 96 → 102 → 118 |
| Brett Wuschel-Wiesen | 64,3 → 76,9 → 93,6 | 88 → 101 → 118 |
| Brett Zauberwald | 60,8 → 67,8 → 77,9 | 85 → 92 → 102 |
| Lumos-Ring | 50,6 → 56,8 → 65,2 | 73 → 80 → 88 |
| Beach-Volley | 54,8 → 62,3 → 71,0 | 78 → 86 → 94 |

WebP liegt im Grafikspeicher unkomprimiert: +16 … +29 MB gegenüber dem Original. Mobile Browser ohne S3TC-Unterstützung
hätten auch die S3TC-Variante entpackt (gleicher Wert); am Desktop sind die zusätzlichen ~16 MB gegenüber S3TC
unkritisch. Bewusste Entscheidung: kleiner Download vor kleinstem Desktop-Grafikspeicher.

**Ladezeiten neu gemessen, ohne Nebenlast** (Software-Renderer, Hoch, 640×360; je Ziel Original und Endstand direkt
nacheinander, `scene_profile.sh --xvfb`; die Ladezeiten in D.2 stammen aus einem Lauf mit parallelen Jobs):

| Ziel | Laden s Original → Endstand | Texturen MB |
|---|---|---|
| Hauptmenü (warm; erster Lauf nach Container-Neustart kalt: 16,3 → 12,2) | 7,20 → 7,07 | 73,1 → 94,4 |
| Brett Wuschel-Wiesen | 12,94 → 12,17 | 64,3 → 93,6 |
| Brett Zauberwald | 10,58 → 10,57 | 60,8 → 77,9 |
| Lumos-Ring | 6,05 → 6,11 | 50,6 → 65,2 |
| Beach-Volley | 4,63 → 4,96 | 54,7 → 72,1 |

Ladezeit gleich (−0,8 … +0,3 s), 0 Engine-Fehler. Die früher gemessenen +0,5 … +3,4 s (D.2) waren Last der parallelen
Jobs, nicht Shader-Kompilierung.

**Web-Build im Browser** (Chromium, Software-WebGL, `tools/dev/web_shot.js`): Hauptmenü sowie Brett → Roulette →
Minispiel ohne Konsolenfehler – keine fehlenden Ressourcen, keine Shaderfehler, keine rosa/schwarzen Flächen
(`docs/screenshots/1.5.4/web_build_menue.jpg`).

### D.4 Qualitätsprofile

Bestehende Grafikstufen (Niedrig/Mittel/Hoch/Ultra) steuern den Oberflächen-Shader ohne Neukompilieren (Uniform):
Niedrig nur Detailfarbe (+19 % simuliert), Mittel/Hoch mit Normalmap. Zusätzlich abschaltbar über
„Oberflächen-Details“ (bisheriges Aussehen, keine Zusatzkosten). Keine pauschale Absenkung: Schatten, Auflösung,
Partikel unverändert.

## E. Spiel- und Regressionsprüfung

### E.1 Fehler gefunden und behoben

| Fehler | Seit | Wirkung | Behebung |
|---|---|---|---|
| Fahrbahn unter dem Rasen (7 Strecken) | 1.5.3 (Streckenverlängerung) | bis 765 m je Runde unsichtbar (Lumos-Ring 58 %, Dschungel 59 %, Vulkan 37 %, Frost 28 %, Canyon 26 %, Gewitter 15 %, Wasserfall 11 %; Korallen-Kanal außerhalb des Tunnels unter Sand/Wasser) | `RaceTrack._lift_below_ground`: weich anheben, Loopings/Gleiter starr, Überführungen behalten die Durchfahrtshöhe, Unterwassertunnel fest – jetzt ≤ 9 m je Runde (Tunnel ausgenommen), Steigung höchstens +0,01, keine Überschneidung |
| Nature/Space Kit metallic = 1 | Import | Bäume, Felsen, Klippen dunkel, spiegeln den Himmel (alle Welten) | `LumosMaterials.normalize_model` |
| Web-Export ohne Oberflächen-Texturen | (neu in dieser Arbeit, vor der Auslieferung gefunden) | Exportliste kennt nur Katalog-Pfade | `tools/export_list.gd` nimmt `assets/materials` auf; im Browser geprüft: 0 Konsolenfehler |
| „Reaktion fehlt: dodge“ / „surprised“ | 1.5.x | Menü-Ballspiel und Geister-Fotograf: Schreck-Reaktion wurde nie gespielt (Animationsname statt Reaktion) | `shocked` / `scared` aus der Reaktionsbibliothek |
| `tools/dev/race_shot.gd` liefert keine Bilder | 1.5.x | Prüfwerkzeug bleibt ohne Fehlermeldung stehen | neues `track_shot.gd` (Startweg wie der CI-Linsentest) |
| `board_life_shot.gd` beendet sich nicht | 1.5.3 | Prozess läuft bis zum äußeren Zeitlimit | beendet sich selbst |
| Import-Einstellungen der Oberflächen nicht im Repository | (neu in dieser Arbeit, vor der Auslieferung gefunden) | `.gitignore` schließt alle `*.import` aus → CI und frische Checkouts importieren die 50 Oberflächen-Texturen verlustfrei (Gras-Albedo 1 058 806 statt 183 394 Byte, gemessen) – das ausgelieferte Web-Paket wäre deutlich größer als die gemessenen 42,1 MB | Ausnahme `!assets/materials/surfaces/*.import`; geprüft: Godot 4.7.2 importiert neu, sobald sich die `.import`-Datei ändert (auch aus dem CI-Import-Cache) |

### E.2 Prüfungen des Endstands

| Prüfung | Werkzeug | Ergebnis |
|---|---|---|
| Skripte und Szenen | `tools/dev/Check.tscn` | 263 Dateien, 0 Probleme, 0 Skriptfehler |
| System-Tests (CPU-Stufen, Inventar, Items, Emotes, Steuerung, Touch) | `tools/dev/test_systems.gd` | 73 PASS, „TESTS OK“ |
| Asset-Inventur, Katalog, Steuerung | `tools/validate_catalog.py`, `tools/validate_controls.py` | OK |
| Gesichts-Labor (echtes Rendering) | `tools/charlab/face_lab.gd` | 6/6 PASS – Figuren, Mimik und Animationen unbeschädigt |
| Trailer-Trennung | CI-Schritt | OK (keine Verweise, nicht im Export) |
| Nitro Dash – **alle 12 Strecken**, je 1 Runde mit 8 CPU-Karts | `tools/dev/race_sweep.sh` | 12/12, je 8/8 im Ziel, keiner hängt fest (Korallen-Kanal 0,7 s festgefahren, Original 1,6 s) |
| Strecken-Geometrie | `track_check.gd` | Fahrbahn ≤ 9 m je Runde unter der Bodenkante (vorher bis 765 m; Unterwassertunnel ausgenommen), Steigung höchstens +0,01, keine Überschneidung |
| **Alle 69 Minispiele** mit 4 CPUs (erste Kategorie je Spiel) | `tools/dev/minigame_sweep.sh` | 69/69 regulär beendet, 0 Skriptfehler, 0 durchgefallen; Körpermitte in Geometrie nur bei Kullerfels-Flucht 0,1 s (eine Figur, beim Überrollen durch einen Fels – Spielmechanik) |
| Web-Build im Browser (Menü, Brett → Roulette → Minispiel) | `tools/dev/web_shot.js` | 0 Konsolenfehler, keine fehlenden Ressourcen, keine Shaderfehler, keine rosa/schwarzen Flächen |
| Online-Brett, 3 Geräte, 1 Mensch-Gast, 240 s (wie CI) | `tools/dev/net_test.sh … party meadow` lokal | Original und Endstand gleich: je 9 Brettzustände, alle Geräte identisch, 0 Skriptfehler. CI-Lauf #64 (`498dd17f`) brach hier ab: nur 2 Zustände in 240 s (Host = Gäste, keine Abweichung) – der Lauf kam auf dem CI-Rechner zu langsam voran |
| Kollisionswelt Original ↔ Endstand (Schneeball-Duell, fester Zufallswert) | Kollisionsformen-Liste | identisch (20 Formen, Lage, Größe) |

### E.3 Schneeball-Duell: „festgefahren“ höher? – geprüft, keine Regression

Der Minispiel-Sweep zeigte im Schneeball-Duell mehr „festgefahren“-Zeit (CPU will laufen, kommt nicht vom Fleck,
Summe der 4 Figuren): Original 12,7 / 9,8 / 16,1 / 14,5 s, Endstand 30,2 / 28,1 / 41,2 s. Untersuchung:

* **Code:** `snowball_fight.gd`, Spielfigur, Minispiel-Basis unverändert; der neue Material-Code nutzt weder Zufall
  noch Physik. **Kollisionswelt identisch** (20 Formen, Lage, Größe – bei festem Zufallswert sogar die Drehung der
  Deckungen, d. h. auch der Zufallsverbrauch beim Aufbau ist gleich).
* **Ursache der Streuung:** Der Sweep läuft im Schnellvorlauf (`--fixed-fps`), der Treffer-Hitstop
  (`Juice.hitstop`, 40 ms) und seine 300-ms-Sperre laufen aber in echter Zeit – wie viele Spielbilder davon betroffen
  sind, hängt von der Rechnerlast ab. Die Endstand-Läufe 30–41 s liefen parallel zu Render-Jobs.
* **Abwechselnd unter gleicher Last** (8 Paare, Schnellvorlauf): Original 17,9 / 27,9 / 11,3 / 12,5 / 29,6 / 22,6 /
  11,5 / 14,5 s (⌀ 18,5) · Endstand 15,2 / 27,6 / 29,3 / 26,1 / 11,1 / 26,5 / 33,9 / 26,6 s (⌀ 24,5); Mann-Whitney
  U = 21 (Grenze für 5 %: 13) – nicht signifikant.
* **Echtzeit wie im Spiel** (ohne Schnellvorlauf, 3 Paare): Original 20,8 / 26,5 / 21,7 s (⌀ 23,0) · Endstand
  27,3 / 29,4 / 22,1 s (⌀ 26,3) – Bereiche überlappen.

Ergebnis: kein nachweisbarer Unterschied, keine Ursache im geänderten Code; alle Läufe regulär beendet, 0 Skriptfehler.

## F. Git

* Arbeitszweig `claude/elegant-johnson-2kfiut` (Ausgangsstand `f1e251b5` = `main` nach PR #4/#5 + hochgeladene
  Zips). `main` unverändert, kein Merge, keine Veröffentlichung ohne Freigabe.
* Commits dieser Überarbeitung (Betreff `v1.5.4: …`): Materialsystem + Pilot (`ad65e8db`), alle Bereiche +
  Fahrbahn-Fix + Werkzeuge (`930b135e`, `82a1c044`), Web-Export/Stufen/Brücken-Fix/Reaktionen (`7a2fce44`),
  WebP-Umstellung, Version 1.5.4, Bericht (`d35e8260`), Fernbereich ohne Normalmap-Zugriff (`498dd17f`),
  Import-Einstellungen der Oberflächen im Repository (`1def7854`), Abschluss (Strecken-Bilder, Messwerte, E.2/E.3) –
  siehe `git log`.
* CI: Läufe nur über `workflow_dispatch` auf dem Arbeitszweig (kein offener PR). Ein solcher Lauf veröffentlicht
  nichts: Vercel ist ohne Token übersprungen, GitHub Pages und Release laufen nur auf `main`/Tags (geprüft an Lauf #58).
* **CI-Lauf #67** (`cc8fb94d`, workflow_dispatch): **grün** – alle Prüfschritte inkl. Online-Test, Langzeit-Test,
  Web-/Linux-Export und Browser-Rauchtest; Vercel/Pages/Release übersprungen (nichts veröffentlicht). Web-Artefakt
  (GitHub-Pages-Paket) 73,1 MB (Lauf #58, Original 1.5.3) → 79,9 MB (+6,8 MB) – deckt sich mit der lokalen Messung
  (D.3), d. h. die eingecheckten Import-Einstellungen greifen im CI. Vorheriger Lauf #64 (`498dd17f`, noch ohne
  `.import`-Dateien) brach im Online-Brett-Test ab (zu langsam, s. E.2).
* Nicht im Repository: JulioVII-Originalarchive (1,1 GB; Abruf + Prüfsummen über `tools/assets/fetch_juliovii.py`).
* Unverändert im Repository: alle 14 hochgeladenen Zips (nichts gelöscht oder überschrieben).
