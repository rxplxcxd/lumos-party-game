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

**Ausgewählt (28 Familien)** – Quelle → Familie: HandpaintedGrass_01 → `grass`, HandpaintedGrassAndDirt_01 →
`meadow`, HandpaintedDirt_01 → `dirt`, HandpaintedSand_01 → `sand`, Stylized_06_Sand → `dune`, HandpaintedStones_03 →
`pebbles`, HandpaintedStones_02 → `flagstone`, Stylized_02_Stone_Ground → `cobble_moss`, Stone_01 → `rock`, Stone_04 →
`cliff`, StoneTiles_01 → `stone_wall`, Rounded_Bricks_01 → `bricks`, Plaster_01 → `plaster`, Stylized_03_Wood_Planks →
`planks`, Wood_01 → `wood`, WoodBark_02 → `bark`, Stylized_13_RoofSquare → `roof`, BaseMetal_01 → `metal`,
MetalPanels_01 → `metal_panel`, Stylized_08_Snow → `snow`, Stylized_18_Ice → `ice`, CeramicTiles_02 → `tiles`,
CeramicTilingFloor_02 → `checker`, BricksPavement_04 → `paving`, Concrete_01 → `concrete`, LavaRock_01 → `lava_rock`,
Stylized_22_Tatami → `fabric`, Stylized_33_Mud → `mud`. Nicht ausgewählt (104): Dubletten in Funktion
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
| Aufbereitung | `tools/assets/build_surfaces.py` + `tools/assets/surfaces_src.json` | 28 Familien aus den Originalarchiven: Kastenfilter-Verkleinerung (kachelbar, nie hochskaliert), AO eingebacken, Detailfarbe normiert (Helligkeit × gedämpfter Farbton), Rauheit im Alphakanal, Normalen renormiert |
| Laufzeitwerte | `scripts/core/surface_stats.gd` (erzeugt) | Normierung je Familie (linear `k`, sRGB `ks`), Mittelfarbe |
| Shader | `assets/shaders/lumos_surface.gdshader` | triplanar im Welt- oder Objektraum, Palettenfarbe × Detail, asymmetrisches Detail, Großflächen-Variation, Ausblenden zur Ferne, drei Stufen über ein Uniform, farbraumunabhängig |
| Bibliothek | `scripts/core/lumos_materials.gd` | Familien-Parameter, Cache je (Familie, Farbe, Optionen), Freigabe je Szenenwechsel und beim Beenden, Stufe bei Grafikwechsel nachziehen, doppelseitige Variante |
| Modell-Vereinheitlichung | `LumosMaterials.normalize_model` / `apply_to_model` (in `Assets._instantiate`) | metallic = 1 → 0 (Nature/Space Kit), Plastikglanz < 0,45 → 0,55, sprechende Materialnamen → Detail im Objektraum |
| Uferkante | `assets/shaders/shore.gdshader`, `WorldKit.shore()` | Flachwasser-Verlauf + wandernder Schaum am Inselrand (ersetzt die Tiefen-/Refraktionsidee des hochgeladenen Wasser-Shaders ohne Bildschirmkopie) |
| Einbindung | `WorldKit.surface()`, `family`-Parameter von `box/boxes/cylinder`, Kurzform `"familie@stärke"` | ein Wort am Aufruf genügt; ohne Familie bleibt alles wie bisher |
| Einstellung | „Oberflächen-Details“ (Einstellungen, Standard an) | aus = bisheriges einfarbiges Material (Rückfall) |

**Familien:** grass, meadow, dirt, sand, dune, pebbles, flagstone, cobble_moss, rock, cliff, stone_wall, bricks, plaster,
planks, wood, bark, roof, metal, metal_panel, snow, ice, tiles, checker, paving, concrete, lava_rock, fabric, mud –
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
| Kompression | Projektstandard verlustfrei (`compress/mode=0`) | richtig für Paletten (Blockkompression lässt Farbfelder bluten) | Detailtexturen VRAM-komprimiert (BC3/RGTC), Paletten bleiben |
| Mipmaps / Filter | Mipmaps an (Projektstandard) | – | Detailtexturen zusätzlich anisotrop |
| Normalmaps | alle 14 Pakete OpenGL-Konvention | – | keine Umrechnung nötig, Konvention im Shader dokumentiert |
| Paket-Vorschaubilder | 1920×1080-Vorschauen (`contents.png`, `Preview.png` …) importiert | liegen in Asset-Ordnern | nicht exportiert (Exportliste nur geladene Dateien) – kein Laufzeitkosten-Befund |
| Wiederholungsmuster | bei großen Flächen sichtbar möglich | Kachel | Großflächen-Variation + Ausblenden zur Ferne |
| Nachtszenen (Friedhof, Zauberwald-Nacht) | Detail dunkelt nur ab → Nacht bleibt Nacht; Friedhof zu dunkel | asymmetrisches Detail | Friedhof halbe Stärke |
