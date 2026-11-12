#!/usr/bin/env python3
"""
Lumos Party – Asset-Pipeline
============================

1. Scannt den kompletten Ordner ``assets/`` (3D-Pakete, Audio, 2D-Icons).
2. Validiert jedes glTF/GLB (Header, JSON-Chunk, externe Buffer/Texturen vorhanden).
3. Schreibt ``docs/ASSET_INVENTORY.md`` (menschenlesbar) und
   ``data/asset_inventory.json`` (maschinenlesbar).
4. Erzeugt ``.gdignore``-Dateien, damit Godot nur Runtime-Formate importiert
   (glTF/GLB, OGG, PNG-Texturen) und Duplikate wie FBX/OBJ/DAE/STL, Previews,
   Unity-Pakete usw. ignoriert. Das hält Import-Zeit, CI und PWA-Größe klein.

Aufruf:  python3 tools/asset_pipeline.py [--check]
  --check  bricht mit Exit-Code 1 ab, wenn ein referenziertes Modell defekt ist
"""
from __future__ import annotations

import json
import os
import re
import struct
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"

# --------------------------------------------------------------------------
# Pakete, die im Spiel verwendet werden (werden von Godot importiert).
# Rolle = wofür das Paket im Spiel (teils zweckentfremdet) eingesetzt wird.
# --------------------------------------------------------------------------
PACK_ROLES: dict[str, str] = {
    "3d/minigames-and-others/KayKit_HalloweenBits_1.0_FREE": "Friedhof-Brett & Geister-Spiele (Gruft, Grabsteine, Zäune, Totholz, Laternen, Kerzen); Halloween-Deko (Kürbisse, Kerzen, Schädel)",
    "3d/minigames-and-others/KayKit_Furniture_Bits_1.0_FREE": "Einrichtung der Spukvilla & Geister-Villa (Sessel, Regale, Bilder, Lampen, Teppiche)",
    "3d/minigames-and-others/KayKit_Restaurant_Bits_1.0_FREE": "Rhythmus-Küche (Theken, Herd, Kühlschrank, Zutaten-Kisten, Gerichte), Sandwich-Sturm-Zutaten",
    "3d/minigames-and-others/KayKit_City_Builder_Bits_1.0_FREE": "Stadt-Kulisse: Achsen-Taxi, Raumstation-Vorplatz (Gebäude, Ampeln, Laternen, Hydranten, Autos)",
    "3d/minigames-and-others/KayKit_Platformer_Pack_1.0_FREE": "Hüpf-Parcours-Teile: Zielbanner, Federn, Fahnen, Sterne, Ringe für Plattform-Minispiele",
    "3d/characters/KayKit_Skeletons_1.1_FREE": "Skelett-Figuren (Rig_Medium, nutzen die gemeinsame Animationsbibliothek) als Zuschauer am Friedhof/Dungeon und Halloween-Tänzer",
    # Charaktere
    "3d/characters/KayKit_Adventurers_2.0_FREE": "Spielbare Helden (Knight, Barbarian, Mage, Ranger, Rogue) auf Rig_Medium",
    "3d/characters/KayKit_Character_Animations_1.1": "Geteilte Rig_Medium-Animationsbibliothek (Jubeln, Winken, Treffer, Sprünge, Skelett-Taunts)",
    "3d/characters/kenney_mini-characters": "Kart-Fahrer (drive-Animation), Publikum, Händler-NPC",
    "3d/characters/kenney_cube-pets_1.0": "Zuschauer-Tiere, Maskottchen im Menü, Brett-Deko",
    # Brettspiel
    "3d/boardgame/KayKit_BoardGameBits_1.0_FREE": "Würfel-Blöcke, Münzen, Fahnen, Sanduhr, Spielfeld-Tiles",
    "3d/boardgame/kenney_board-game-info": "Feld-Icons (Glück, Sanduhr, Spieler) im HUD",
    # Minispiele & Props
    "3d/minigames-and-others/KayKit_Dungeon_Pack_1.1_FREE": "Dungeon-Deep-Brett, Dungeon-Drop-Platten, Fackeln als Event-Felder, Säulen fürs Turm-Balancieren",
    "3d/minigames-and-others/KayKit Mini-Game Variety Pack 1.2": "Bomben, Spike-Roller, Swiper-Pendel, Powerup-Blöcke, Bär/Hund/Ente-NPCs",
    "3d/minigames-and-others/kenney_graveyard-kit_5.0": "Geister-Schloss (Geister, Skelette, Gruften, Zäune)",
    "3d/minigames-and-others/kenney_platformer-kit": "Sky-Kingdom-Inseln, Sterne, Truhen, Flaggen, Sprungfedern",
    "3d/minigames-and-others/kenney_castle-kit": "Sky-Kingdom-Burg, Türme, Brücken",
    "3d/minigames-and-others/kenney_survival-kit": "Fische (als Haie skaliert), Amboss, Kisten",
    "3d/minigames-and-others/KayKit_RPGToolsBits_1.0_FREE": "Amboss für den Podest-Gag, Werkzeuge",
    "3d/minigames-and-others/kenney_tower-defense-kit": "Felsbrocken (Kart-Bowling), Kanonenkugeln (Homing-Item)",
    "3d/minigames-and-others/KayKit_Forest_Nature_Pack_1.0_FREE": "Bäume/Felsen für Strecken und Bretter",
    "3d/minigames-and-others/kenney_modular-cave-kit_1.0": "Vulkan-/Höhlen-Kulissen",
    "3d/minigames-and-others/kenney_input-prompts_1.5": "Button-Glyphen (Switch/Xbox/Tastatur/Touch)",
    "3d/minigames-and-others/kenney_medals": "Medaillen in der Siegerehrung",
    "3d/minigames-and-others/kenney_crosshair-pack": "Zielmarker der Homing-Kanonenkugel",
    "3d/minigames-and-others/KayKit_Holiday_Bits_1.0_FREE": "Konfetti-/Geschenk-Deko, Schneeball-Kanone",
    # Strecken & Umgebung
    "3d/tracks-enviroment/kenney_pirate-kit": "Pirates-Cove-Brett, Planken-Feld, Kanonen, Fässer-Chaos, Plank-Panic",
    "3d/tracks-enviroment/kenney_racing-kit": "Nitro-Dash-Streckendeko (Tribünen, Banner, Zielbogen)",
    "3d/tracks-enviroment/kenney_nature-kit": "Bäume, Felsen, Klippen für alle Welten",
    "3d/tracks-enviroment/kenney_space-kit": "Neon-Vulkan-Strecke (Krater, Raketen, Kristalle)",
    "3d/tracks-enviroment/kenney_mini-arcade": "Glücksrad (prize-wheel) für die Glücksrad-Kiste",
    "3d/tracks-enviroment/kenney_mini-arena": "Pokal & Arena-Bauteile fürs Podest",
    "3d/tracks-enviroment/kenney_fantasy-town-kit_2.0": "Häuser & Mauern im Sky Kingdom",
    "3d/tracks-enviroment/kenney_holiday-kit": "Frostdorf-Brett & Frostgipfel-Strecke (Hütten, Schneemänner, Rentiere), Schneeball-Schlacht",
    "3d/minigames-and-others/kenney_minigolf-kit": "Minigolf-Duell (Bahnen, Bälle, Löcher, Fahnen)",
    "3d/tracks-enviroment/kenney_space-station-kit": "Raumstation-Brett (Böden, Geländer, Konsolen)",
    "3d/minigames-and-others/KayKit_Space_Base_Bits_1.0_FREE": "Raumstation-Brett & Orbit-Strecke (Module, Landeplätze, Windräder)",
    "3d/tracks-enviroment/kenney_city-kit-commercial_2.1": "Stadt-Rallye-Strecke (Hochhäuser, Markisen)",
    "3d/tracks-enviroment/kenney_city-kit-suburban_20": "Stadt-Rallye-Strecke (Vorstadthäuser, Zäune, Bäume)",
    # Natur & Plattformer (1.2.3) – FBX/OBJ liegen direkt im Paket und werden von Godot nativ importiert
    "3d/quaternius/nature": "Upgrade-Pools: Bäume (Eiche, Birke, Weide, Kiefer, tot, verschneit, Herbst), Büsche, Steine, Pflanzen, Mais",
    "3d/quaternius/platformer": "Wolken, Felsplattformen, Tür/Schlüsseltor, Truhen, Fallen, Münzen, Edelsteine, Gegner, Würfel",
    "3d/nature/lowpoly_env": "Berg-Horizont, Bäume, Büsche, Steine, Pflanzen, Gelände-Kulissen",
    "3d/nature/modular_terrain": "Themen-Deko: Stege, Muscheln, Schatztruhe, Loren, Lagerfeuer, Ruinen, Zäune (OBJ, matt gestellt)",
    # Fahrzeuge
    "3d/vehicles/kenney_car-kit": "Karts (kart-oobi … kart-oozi) für Nitro Dash und Kart-Bowling",
    "3d/vehicles/kenney_toy-car-kit": "Item-Boxen, Rampen",
    "3d/vehicles/kenney_watercraft-pack": "Boote/Bojen in Pirates Cove und im Unterwasser-Tunnel",
    # Audio – alles klein, wird komplett importiert
    "audio/kenney_digital-audio": "Power-Ups, Boost, Item-Rollen",
    "audio/kenney_impact-sounds": "Schritte (Holz/Stein/Gras), Aufschläge, Slapstick-Hits",
    "audio/kenney_interface-sounds (1)": "Menü, Würfel-Ticks, Glücksrad",
    "audio/kenney_music-jingles": "Gewinn-/Verlust-Jingles, Stern-Fanfare",
    "audio/kenney_rpg-audio": "Münzen, Truhen, Türen",
    "audio/kenney_sci-fi-sounds": "Explosionen, Schleim, Motoren",
    "audio/kenney_ui-audio": "Button-Feedback",
    "audio/kenney_voiceover-pack": "Ansager: Ready/Set/Go, Zahlen 1–10, Congratulations",
    "audio/kenney_voiceover-pack-fighter": "Ansager: Round 1–5, Final Round, Winner",
}

# Unterordner, die innerhalb aktiver Pakete importiert werden (Whitelist pro Paket).
# Alle anderen Unterordner (FBX/OBJ/DAE, Previews …) erhalten eine .gdignore.
PACK_SUBDIR_WHITELIST: dict[str, list[str]] = {
    "3d/characters/KayKit_Character_Animations_1.1": ["KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium"],
    "3d/characters/KayKit_Adventurers_2.0_FREE": ["KayKit_Adventurers_2.0_FREE/Characters/gltf"],
    "3d/boardgame/kenney_board-game-info": ["PNG/Default (128px)"],
    "3d/minigames-and-others/kenney_input-prompts_1.5": [
        "Nintendo Switch/Default", "Xbox Series/Default", "PlayStation Series/Default", "Keyboard & Mouse/Default", "Touch/Default"],
    "3d/minigames-and-others/kenney_medals": ["PNG"],
    "3d/minigames-and-others/kenney_crosshair-pack": ["PNG/Glow"],
}

NON_RUNTIME_DIR = re.compile(
    r"^(fbx.*|obj|dae|stl|.* format)$|^(previews?|isometric|side|vector|spritesheet|tilemap|"
    r"unity package|convert|samples|kaykit brand resouces|texture|mannequin character|rig_large|"
    r"extra heads|fonts|double)$",
    re.IGNORECASE,
)
RUNTIME_FORMAT_DIR = re.compile(r"^(glb format|gltf format)$", re.IGNORECASE)

MODEL_EXT = {".glb", ".gltf"}
AUDIO_EXT = {".ogg", ".wav", ".mp3"}
IMAGE_EXT = {".png", ".jpg", ".jpeg", ".svg"}


def read_gltf(path: Path) -> dict:
    data = path.read_bytes()
    if data[:4] == b"glTF":
        if len(data) < 20:
            raise ValueError("GLB zu kurz")
        version, length = struct.unpack("<II", data[4:12])
        if version != 2:
            raise ValueError(f"GLB-Version {version}")
        chunk_len, chunk_type = struct.unpack("<II", data[12:20])
        if chunk_type != 0x4E4F534A:
            raise ValueError("erster Chunk ist kein JSON")
        return json.loads(data[20:20 + chunk_len])
    return json.loads(data)


def validate_model(path: Path) -> dict:
    info = {"ok": True, "error": "", "anims": [], "skinned": False, "meshes": 0}
    try:
        j = read_gltf(path)
        info["meshes"] = len(j.get("meshes", []))
        info["skinned"] = bool(j.get("skins"))
        info["anims"] = [a.get("name", "") for a in j.get("animations", [])]
        for ref in [b.get("uri") for b in j.get("buffers", [])] + [i.get("uri") for i in j.get("images", [])]:
            if ref and not ref.startswith("data:"):
                if not (path.parent / ref).exists():
                    from urllib.parse import unquote
                    if not (path.parent / unquote(ref)).exists():
                        info["ok"] = False
                        info["error"] = f"fehlende Referenz {ref}"
    except Exception as exc:  # noqa: BLE001
        info["ok"] = False
        info["error"] = str(exc)
    return info


def pack_dirs() -> list[str]:
    out = []
    for group in ("3d", "audio"):
        base = ASSETS / group
        if not base.exists():
            continue
        if group == "audio":
            out += [f"audio/{p.name}" for p in sorted(base.iterdir()) if p.is_dir()]
        else:
            for cat in sorted(base.iterdir()):
                if cat.is_dir():
                    out += [f"3d/{cat.name}/{p.name}" for p in sorted(cat.iterdir()) if p.is_dir()]
    return out


def write_gdignore(directory: Path) -> None:
    marker = directory / ".gdignore"
    if not marker.exists():
        marker.write_text("")


def remove_gdignore(directory: Path) -> None:
    marker = directory / ".gdignore"
    if marker.exists():
        marker.unlink()


def apply_import_rules(pack: str) -> None:
    pack_path = ASSETS / pack
    # vorhandene Marker zurücksetzen, damit Regeländerungen greifen
    for marker in pack_path.rglob(".gdignore"):
        marker.unlink()
    if pack not in PACK_ROLES:
        write_gdignore(pack_path)
        return
    whitelist = PACK_SUBDIR_WHITELIST.get(pack)
    if whitelist:
        keep = {(pack_path / w).resolve() for w in whitelist}
        keep_parents = set()
        for k in keep:
            keep_parents.update(k.parents)
        for dp, dn, _ in os.walk(pack_path):
            d = Path(dp).resolve()
            for name in list(dn):
                sub = (d / name).resolve()
                if any(sub == k or k in sub.parents for k in keep):
                    continue  # erlaubt (inkl. Unterordner)
                if sub in keep_parents:
                    continue  # auf dem Weg zu einem erlaubten Ordner
                write_gdignore(sub)
                dn.remove(name)
        return
    for dp, dn, _ in os.walk(pack_path):
        for name in list(dn):
            if RUNTIME_FORMAT_DIR.match(name):
                continue
            if NON_RUNTIME_DIR.match(name):
                write_gdignore(Path(dp) / name)
                dn.remove(name)


def main() -> int:
    check = "--check" in sys.argv
    packs = pack_dirs()
    inventory = {"packs": [], "totals": {}}
    totals = Counter()
    broken = []
    for pack in packs:
        p = ASSETS / pack
        ext_counter = Counter()
        size = 0
        models, audio, images = [], [], []
        anim_sets = {}
        for dp, _, files in os.walk(p):
            low = dp.lower()
            for f in files:
                fp = Path(dp) / f
                ext = fp.suffix.lower()
                ext_counter[ext] += 1
                size += fp.stat().st_size
                rel = fp.relative_to(ROOT).as_posix()
                if ext in MODEL_EXT and not re.search(r"fbx|/obj|/dae", low):
                    v = validate_model(fp)
                    models.append(rel)
                    if not v["ok"]:
                        broken.append((rel, v["error"]))
                    if v["anims"]:
                        anim_sets[rel] = v["anims"]
                elif ext in AUDIO_EXT:
                    audio.append(rel)
                elif ext in IMAGE_EXT and "preview" not in f.lower():
                    images.append(rel)
        totals.update(ext_counter)
        inventory["packs"].append({
            "pack": pack,
            "used": pack in PACK_ROLES,
            "role": PACK_ROLES.get(pack, "Reserve (nicht importiert, für künftige Inhalte)"),
            "size_mb": round(size / 1e6, 2),
            "formats": dict(ext_counter.most_common()),
            "runtime_models": len(models),
            "audio_files": len(audio),
            "images": len(images),
            "animated_models": anim_sets,
        })
        apply_import_rules(pack)

    inventory["totals"] = dict(totals.most_common())
    inventory["broken"] = broken
    (ROOT / "data").mkdir(exist_ok=True)
    (ROOT / "data" / "asset_inventory.json").write_text(json.dumps(inventory, indent=1, ensure_ascii=False))

    # Markdown-Bericht
    lines = [
        "# Asset-Inventur – Lumos Party & Nitro Dash",
        "",
        "Automatisch erzeugt von `tools/asset_pipeline.py`. Nicht von Hand bearbeiten.",
        "",
        f"* Pakete gesamt: **{len(packs)}**, davon im Spiel verwendet: **{sum(1 for p in inventory['packs'] if p['used'])}**",
        f"* Runtime-Modelle (glTF/GLB): **{sum(p['runtime_models'] for p in inventory['packs'])}**",
        f"* Audio-Dateien: **{sum(p['audio_files'] for p in inventory['packs'])}**",
        f"* Defekte/unvollständige Modelle: **{len(broken)}**",
        "",
        "Godot importiert ausschließlich die Runtime-Formate der verwendeten Pakete. FBX/OBJ/DAE/STL-Duplikate,",
        "Vorschaubilder und Unity-Pakete sind per `.gdignore` ausgeschlossen. Der Web-Export enthält danach nur",
        "die Dateien, die der Code tatsächlich lädt (`tools/gen_export_list.py`).",
        "",
        "| Paket | Verwendet | Rolle im Spiel | Größe | Modelle | Audio |",
        "|---|---|---|---:|---:|---:|",
    ]
    for p in inventory["packs"]:
        lines.append(
            f"| `{p['pack']}` | {'✅' if p['used'] else '–'} | {p['role']} | {p['size_mb']} MB | {p['runtime_models']} | {p['audio_files']} |")
    lines += ["", "## Animierte Modelle", ""]
    for p in inventory["packs"]:
        for model, anims in p["animated_models"].items():
            lines.append(f"* `{model}`: {', '.join(anims)}")
    if broken:
        lines += ["", "## Probleme", ""] + [f"* `{m}`: {e}" for m, e in broken]
    lines += ["", "## Dateiformate gesamt", ""] + [f"* `{k or '(ohne)'}`: {v}" for k, v in totals.most_common()]
    (ROOT / "docs").mkdir(exist_ok=True)
    (ROOT / "docs" / "ASSET_INVENTORY.md").write_text("\n".join(lines) + "\n")

    print(f"{len(packs)} Pakete gescannt, {len(broken)} Probleme.")
    for m, e in broken[:20]:
        print("  !", m, e)
    return 1 if (check and broken) else 0


if __name__ == "__main__":
    sys.exit(main())
