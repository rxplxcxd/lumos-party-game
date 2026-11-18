# Lumos Visual Standard (ab 1.5.4, Premium-Visual-Überarbeitung)

Verbindliche Regeln für alle neuen und überarbeiteten Inhalte. Ziel: der stilisierte, gemütliche Low-Poly-Look –
hochwertig, einheitlich, ohne Fotorealismus und ohne übertriebenen Glanz. **Die Palettenfarbe ist die Identität einer
Welt; Texturen liefern nur Detail.** Umsetzung: `scripts/core/lumos_materials.gd` (Bibliothek),
`assets/shaders/lumos_surface.gdshader` (Shader), `tools/assets/build_surfaces.py` (Aufbereitung).

## 1. Wann welches Material

| Fläche | Material | Beispiel |
|---|---|---|
| Große erzeugte Flächen (Böden, Inseln, Wände, Böschungen, Felsen, Häuschen) | `WorldKit.surface(familie, farbe)` bzw. `family`-Parameter von `WorldKit.box/boxes/cylinder` | Wiesenboden `grass`, Inselrand `sand`, Turmwände `plaster` |
| Spielrelevante Farbflächen (Zonen, Felder, Teamfarben, Ziele, Markierungen) | **einfarbig** (`WorldKit.mat`) – Lesbarkeit geht vor | Farbfelder in Farbchaos, Bumper-Zonen, Curling-Zielkreise |
| Modelle mit Farbatlas (Kenney/KayKit `colormap`) | unverändert – die Palette ist der Stil | Palmen, Häuser, Karts, Figuren |
| Modelle mit sprechenden Materialnamen (Nature-/Space-/Racing-Kit, Quaternius) | automatisch über `LumosMaterials.MODEL_NAMES`, Objektraum, Stärke 0,65 | Felsen `stone` → `rock`, Rinde `woodBark` → `bark` |
| Wasser, Lava, Fahrbahn, Effekte | eigene Shader (`water`, `lava`, `road`, FX) | – |
| Uferkanten runder Inseln | `WorldKit.shore()` (Flachwasser + Schaum) | Menü-Insel, Piratenbucht |

Glatte Sonderwelten (Torte, Zuckerguss, Wolken) bleiben bewusst einfarbig-glatt.

## 2. Texturen

* **Auflösung je Familie** (Kachel, wiederholt): **1024²** nur für die Flächen mit echten Nahansichten (`grass`,
  `sand` – Menü-Insel, Bretter), **512²** für alle anderen. **Nie 4K** im Spiel; Quellen werden nur
  verkleinert (`Image.reduce` = Kastenfilter auf ganzen Blöcken → kachelbar ohne Randnaht), **nie hochskaliert**.
* **Texeldichte** (Ziel 150–350 Texel/m): 1024² auf 3–3,5 m Kachel ≈ 290–340 Texel/m, 512² auf 2–3 m ≈ 170–256 Texel/m.
  Modelle: Kachel × 0,6 (kleinere Requisiten). Fernboden der Kulisse: 6 m (blendet ab 40 m aus).
* **Kanäle**: `<familie>_albedo.webp` RGB = Detailfarbe (Mittelwert normiert, AO zu 30–60 % eingebacken),
  A = Rauheit (2.–98.-Perzentil auf 0..1 gestreckt); `<familie>_normal.webp` (Quelle verlustfrei, im Paket WebP 0,9). Höhe wird nicht
  genutzt (keine Parallaxe – zu teuer im Browser).
* **Import**: Detailtexturen als **WebP verlustbehaftet** (`compress/mode=1`, Albedo 0,85, Normalen 0,9), Mipmaps an.
  Begründung (gemessen): S3TC vergrößerte das Web-Paket um 30 MB (35,2 → 65,4 MB), WebP um 6,8 MB; Bildunterschied im
  Pixelvergleich nicht erkennbar. Im Grafikspeicher liegen sie unkomprimiert (512² ≈ 1,4 MB, 1024² ≈ 5,6 MB mit
  Mipmaps) – mobile Browser ohne S3TC hätten sie ohnehin entpackt. Nur Familien liefern, die das Spiel verwendet.
* **Farbatlas-/Palettentexturen bleiben verlustfrei** (Projektstandard `compress/mode=0`): Blockkompression lässt
  die Farbfelder ineinanderbluten, verlustbehaftete Kompression verschmiert die Feldgrenzen.
* **Filter**: Welttexturen `filter_linear_mipmap_anisotropic` + `repeat_enable` (im Shader gesetzt). UI-Texturen
  bleiben beim Projektstandard.
* **Wiederholung**: Großflächen-Variation (Wertrauschen, nur abdunkelnd, 3–14 %) und Ausblenden des Details zur Ferne
  (`fade_far` 120 m) – kein Kachelmuster am Horizont, kein Flimmern.

## 3. Materialparameter

| Familie | Rauheit | Metallic | Normal | Farbdetail |
|---|---|---|---|---|
| Gras, Wiese, Erde, Sand, Düne | 0,86–1,0 | 0 | 0,8–0,9 | 0,75–0,9 |
| Kiesel, Feldstein, Moos-Pflaster, Fels, Klippe, Steinwand, Ziegel | 0,70–0,95 | 0 | 1,0–1,1 | 0,8–0,9 |
| Putz | 0,82–0,95 | 0 | 0,7 | 0,55 |
| Planken, Holz, Rinde, Dach | 0,60–0,95 | 0 | 0,8–1,0 | 0,8–0,85 |
| Metall, Metallplatten | 0,32–0,70 | 0,45–0,55 | 0,7–0,9 | 0,7 |
| Schnee | 0,55–0,80 | 0 | 0,7 | 0,6 |
| Eis | 0,08–0,30 | 0 | 0,6 | 0,7 |
| Fliesen, Schachbrett | 0,28–0,60 | 0 | 0,7–0,8 | 0,8–1,0 |
| Beton, Pflaster | 0,70–0,95 | 0 | 0,7–1,0 | 0,7–0,9 |
| Stoff | 0,86–1,0 | 0 | 0,7 | 0,7 |

* **Metallic nur für echtes Metall.** Importierte Materialien mit `metallic = 1` (glTF-Standardwert, z. B. Kenney
  Nature/Space Kit) werden beim Laden auf 0 gesetzt, Metall-Namen auf 0,5.
* **Kein Plastikglanz**: Rauheit < 0,45 wird auf 0,55 angehoben – außer Glas, Leuchtteile, Eis, Kristall, Wasser,
  Edelsteine, Gold/Chrom (Namensliste `LumosMaterials.GLOSSY_OK`).
* **Specular** 0,4 (Standard), 0,45–0,6 nur für Schnee, Eis, Fliesen, Metall.
* **Farbdetail asymmetrisch**: Vertiefungen dunkeln voll ab, helle Stellen heben nur zu 30 % an (helle Tag-Szenen
  liegen nahe am Weißpunkt – sonst bleicht die Fläche aus).

## 4. Normalmaps

OpenGL-Konvention (Grün = +V, wie Godot); nach dem Verkleinern renormiert. Im Shader triplanar im Weltraum
(statische Flächen) bzw. Objektraum (bewegte/skalierte Modelle) als Tangential-Störung der Flächennormale. Stärke je
Familie 0,6–1,1; auf Modellen × 0,65. Prüfung der Konvention: `corr(G, dh/dZeile) > 0` (siehe Abschnitt C im Bericht).

## 5. Shader-Regeln

* **Ein** Oberflächen-Shader für alle Familien; Varianten nur über Parameter. Einzige Code-Variante: doppelseitig
  (`cull_disabled`) für offene Meshes – zur Laufzeit aus demselben Code erzeugt.
* **Stufen über die Grafikstufe** (`quality`-Uniform, kein Neukompilieren): Niedrig 0 (nur Farbe, eine Projektion,
  1 Texturzugriff) · Mittel 1 (+ Normalmap, 2 Zugriffe) · Hoch/Ultra 2 (weiche Dreifach-Projektion,
  2 Zugriffe je sichtbarer Projektion; flache Böden 2, Kanten 4–6).
* **Farbraumunabhängig**: Der Compatibility-Renderer rechnet hier ohne Linear-Umrechnung, auf anderen Plattformen mit.
  Die Normierung prüft das über ein `source_color`-Uniform (`space_probe`) und wählt `k` (linear) oder `ks` (sRGB).
* **Verboten in Weltmaterialien**: `SCREEN_TEXTURE`, `DEPTH_TEXTURE`, Parallaxe, Transparenz auf großen Flächen (Ausnahme:
  schmaler Uferring), eigene Shaderkopien je Szene.
* Neue Familien nur über `tools/assets/surfaces_src.json` + `build_surfaces.py` (reproduzierbar, Statistik in
  `scripts/core/surface_stats.gd`).

## 6. Geometrie, LOD

* Erzeugte Zylinder: `radial_segments = clamp(Radius × 10, 64, 128)` – keine sichtbaren Kanten im Umriss großer Inseln.
* Importierte Modelle: `meshes/generate_lods=true` (Godot-Auto-LOD), Schattenmeshes an (Importstandard des Projekts).
* OBJ-Flächen gleichen Materials werden zusammengeführt (`Assets._merge_surfaces`).

## 7. Budgets (gemessen, Software-Renderer, Grafikstufe „Hoch“, 640×360)

Zählwerte gelten auf jeder GPU; Bildzeiten des Software-Renderers sind keine Geräte-FPS.

| Szene | Draw-Calls | Primitive | Texturspeicher | Ladezeit (Test-Server) |
|---|---|---|---|---|
| Hauptmenü | ≤ 400 | ≤ 150 k | ≤ 100 MB | ≤ 7 s |
| Brett | ≤ 800 | ≤ 250 k | ≤ 110 MB | ≤ 8 s |
| Strecke (1 Ansicht) | ≤ 400 | ≤ 120 k | ≤ 80 MB | ≤ 7 s |
| Minispiel / Boss | ≤ 450 | ≤ 200 k | ≤ 80 MB | ≤ 5 s |

Oberflächen-Details je Szene: höchstens 8 Familien gleichzeitig (≈ 12–35 MB Grafikspeicher, je nach Anzahl der
1024²-Familien). Nicht benötigte Familien werden beim Szenenwechsel freigegeben
(`LumosMaterials.prune` über `Assets.prune_cache`).

## 8. Prüfung

* `tools/dev/surface_probe.gd` – Helligkeitsabgleich alt/neu (gleiche Grundfarbe), `--raw=` zeigt Shaderwerte.
* `tools/dev/srgb_probe.gd` – Farbraum des Renderers.
* `tools/dev/material_shot.gd` – feste Kameras der Menü-Insel (Vorher/Nachher bei gleichem Zufall und Licht).
* `tools/dev/board_life_shot.gd`, `tools/dev/race_shot.gd`, `tools/dev/minigame_shot.gd` – Kontrollbilder.
* `tools/dev/scene_profile.sh` – Draw-Calls, Primitive, Speicher, Ladezeit je Szene.
