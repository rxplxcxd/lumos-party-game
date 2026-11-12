# Lizenzen & Herkunft

Übersicht über alle fremden Bestandteile von **Lumos Party & Nitro Dash**. Der Spielcode (GDScript, Shader,
Werkzeuge in `tools/`) gehört zum Projekt. Die genaue Paketliste mit Verwendungszweck steht in
[docs/ASSET_INVENTORY.md](docs/ASSET_INVENTORY.md) (wird von `tools/asset_pipeline.py` erzeugt).

## Engine & Bibliotheken

| Bestandteil | Lizenz | Hinweis |
|---|---|---|
| Godot Engine 4.7 (inkl. Web-Vorlage, Audio-Worklets) | MIT | © Godot Engine contributors, Juan Linietsky, Ariel Manzur |
| Firebase JavaScript SDK (nur Web, zur Laufzeit von gstatic.com geladen) | Apache 2.0 | Anmeldung & Online-Räume |
| Jolt Physics (in Godot enthalten) | MIT | Physik |

## Schriften

| Schrift | Lizenz | Datei |
|---|---|---|
| Lilita One | SIL Open Font License 1.1 | `assets/fonts/OFL-LilitaOne.txt` |
| Fredoka | SIL Open Font License 1.1 | `assets/fonts/OFL-Fredoka.txt` |

## 3D-Modelle, Animationen, Sounds, Icons

| Herkunft | Pakete | Lizenz |
|---|---|---|
| **Kenney** (kenney.nl) | alle `kenney_*`-Pakete: Bauteile, Fahrzeuge, Figuren, Eingabe-Symbole, Interface-/Impact-/RPG-/Sci-Fi-Sounds, Jingles, Sprachaufnahmen | CC0 1.0 (gemeinfrei) |
| **KayKit** (Kay Lousberg) | alle `KayKit_*`-Pakete: Abenteurer, Animationen, Dungeon, Natur, Brettspiel-Teile, Raumstation, Minispiel-Pack | CC0 1.0 (gemeinfrei) |
| **Quaternius** (quaternius.com) | `3d/quaternius/nature`, `3d/quaternius/platformer` | CC0 1.0 (siehe `License.txt` im Paket) |
| vom Projekt bereitgestellt | `3d/nature/lowpoly_env`, `3d/nature/modular_terrain` | Lizenztext liegt nicht im Repository – vor einer kommerziellen Veröffentlichung prüfen |
| **dobo_ui** (itch.io) | `assets/ui/cozy` – Cozy UI Pack (Demo-Version) | Bedingungen des Anbieters, siehe `README_dobo_ui.txt`; vor einer kommerziellen Veröffentlichung prüfen |

Die Eingabe-Symbole stammen aus Kenneys *Input Prompts*-Paket (eigene, gemeinfreie Zeichnungen). Ordnernamen
im Paket bezeichnen nur das Tastenlayout; das Spiel zeigt keine Marken- oder Herstellernamen an.

## Musik

| Bestandteil | Herkunft |
|---|---|
| Brett-, Menü- und Minispiel-Soundtracks (`assets/music/`) | vom Projektinhaber bereitgestellte Soundtracks (Soundtracks 1–3), für das Spiel geschnitten und gemastert mit `tools/audio/build_music.py` |
| Jingles & kurze Effekte | Kenney (CC0), siehe oben |

## Eigene Inhalte

Bosse, Bretter, Strecken, Minispiele, Shader, Reaktions-Animationen (`assets/animations/reactions`), Logos und
Markenbild von Lumos (`assets/brand`) sind für dieses Projekt erstellt.
