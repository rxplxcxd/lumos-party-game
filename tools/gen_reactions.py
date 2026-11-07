#!/usr/bin/env python3
"""
Erzeugt die Slapstick-Reaktionsbibliothek res://assets/animations/reactions/*.tres
(ReactionClip-Ressourcen). Danach im Godot-Inspector frei editierbar.
"""
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "animations" / "reactions"

# id: (clip, hold, squash(x,y), hop, spin, modifier, mod_time, fx, emote, emote_color, sfx, shake, then, speed)
R = {
    "cheer":       ("cheer", 1.6, (0.85, 1.25), 0.4, 0.0, "triumph", 1.2, "stars", "!", (1, .85, .2), "", 0.0, "", 1.0),
    "triumph":     ("cheer", 2.2, (0.8, 1.3), 0.6, 1.0, "triumph", 2.0, "confetti", "", (1, .85, .2), "", 0.0, "", 1.0),
    "wave":        ("wave", 1.6, (1, 1), 0.0, 0.0, "", 0.0, "", "", (1, 1, 1), "", 0.0, "", 1.0),
    "determined":  ("punch", 1.1, (1.25, 0.8), 0.0, 0.0, "triumph", 0.8, "sparkle", "!", (1, .9, .3), "whistle_up", 0.0, "", 1.0),
    "scared":      ("hit_b", 1.4, (0.8, 1.3), 0.5, 0.0, "scared", 1.3, "sweat", "!", (1, .35, .3), "", 0.0, "", 1.0),
    "shocked":     ("dodge_back", 1.2, (0.85, 1.2), 0.2, 0.0, "tremble", 1.0, "sweat", "?!", (1, .5, .3), "", 0.0, "", 1.0),
    "hit":         ("hit", 0.6, (1.3, 0.7), 0.0, 0.0, "", 0.0, "stars", "", (1, 1, 1), "punch", 0.2, "", 1.0),
    "big_hit":     ("hit_b", 1.8, (1.35, 0.65), 0.3, 0.0, "dizzy", 1.7, "dizzy", "", (1, 1, 1), "hit_soft", 0.35, "", 1.0),
    "dizzy":       ("idle", 2.0, (1.1, 0.9), 0.0, 0.0, "dizzy", 2.0, "dizzy", "", (1, 1, 1), "", 0.0, "", 1.0),
    "frustrated":  ("hammer", 2.0, (1.1, 0.9), 0.0, 0.0, "frustrated", 1.9, "anger", "#", (1, .25, .2), "stone_hit", 0.1, "", 1.3),
    "tantrum":     ("hammer", 2.4, (1.2, 0.8), 0.0, 0.0, "frustrated", 2.3, "dust", "#", (1, .2, .2), "stone_hit", 0.2, "", 1.6),
    "sad":         ("sit", 2.0, (1.1, 0.9), 0.0, 0.0, "sad", 2.0, "", "", (0.6, .7, 1), "", 0.0, "sit_up", 1.0),
    "laugh":       ("taunt_long", 1.8, (1, 1), 0.0, 0.0, "laugh", 1.7, "", "HA", (1, .9, .3), "", 0.0, "", 1.0),
    "taunt":       ("taunt", 1.3, (1, 1), 0.0, 0.0, "laugh", 1.0, "", "", (1, 1, 1), "", 0.0, "", 1.0),
    "sleepy":      ("sit", 3.0, (1, 1), 0.0, 0.0, "sad", 3.0, "zzz", "", (1, 1, 1), "", 0.0, "", 0.6),
    "soot_blast":  ("death_b", 2.4, (1.3, 0.6), 0.0, 0.0, "dizzy", 2.4, "soot", "!", (1, .4, .2), "", 0.5, "stand_up", 1.0),
    "slip":        ("death_b", 1.1, (1.25, 0.75), 0.0, 0.0, "", 0.0, "dust", "?", (.6, 1, .5), "boing", 0.15, "stand_up", 1.4),
    "trip_fall":   ("death", 1.6, (1.3, 0.7), 0.0, 0.0, "dizzy", 1.5, "dust", "?", (1, 1, 1), "hit_soft", 0.2, "stand_up", 1.2),
    "victory":     ("cheer", 2.6, (0.8, 1.3), 0.8, 1.0, "triumph", 2.5, "confetti", "", (1, 1, 1), "", 0.0, "", 1.0),
    "confused":    ("idle_b", 1.4, (1, 1), 0.0, 0.0, "", 0.0, "", "?", (.6, .8, 1), "", 0.0, "", 1.0),
    "coin_gain":   ("cheer", 0.9, (0.9, 1.15), 0.3, 0.0, "triumph", 0.7, "sparkle", "", (1, 1, 1), "", 0.0, "", 1.5),
    "coin_loss":   ("hit", 1.0, (1.15, 0.85), 0.0, 0.0, "sad", 0.9, "sweat", "", (1, 1, 1), "", 0.0, "", 1.0),
    "star_get":    ("cheer", 2.6, (0.75, 1.35), 1.0, 1.0, "triumph", 2.4, "confetti", "!", (1, .85, .2), "", 0.0, "", 1.0),
    "launch":      ("spawn_air", 1.2, (0.8, 1.3), 0.0, 0.0, "scared", 1.2, "", "!!", (1, .4, .3), "whistle_fall", 0.0, "", 1.0),
    "land_flat":   ("lie_down", 1.3, (1.4, 0.6), 0.0, 0.0, "dizzy", 1.2, "dust", "", (1, 1, 1), "hit_soft", 0.25, "stand_up", 1.6),
    "flex":        ("taunt_long", 1.8, (1.1, 1.0), 0.0, 0.0, "triumph", 1.7, "sparkle", "", (1, 1, 1), "", 0.0, "", 1.0),
    "cursed":      ("hit_b", 1.6, (0.85, 1.2), 0.3, 0.0, "tremble", 1.5, "smoke", "?!", (.75, .4, 1), "curse", 0.15, "", 1.0),
    "pushups":     ("pushups", 2.0, (1, 1), 0.0, 0.0, "", 0.0, "sweat", "", (1, 1, 1), "", 0.0, "", 1.3),
}

HEADER = '[gd_resource type="Resource" script_class="ReactionClip" load_steps=2 format=3]\n\n' \
         '[ext_resource type="Script" path="res://scripts/core/reaction_clip.gd" id="1_rc"]\n\n[resource]\nscript = ExtResource("1_rc")\n'


def col(c):
    return f"Color({c[0]}, {c[1]}, {c[2]}, 1)"


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.tres"):
        old.unlink()
    for rid, (clip, hold, sq, hop, spin, mod, mt, fx, emote, ec, sfx, shake, then, speed) in R.items():
        body = HEADER + "\n".join([
            f'id = "{rid}"', f'clip = "{clip}"', f"clip_speed = {speed}", f"hold = {hold}",
            f"squash = Vector2({sq[0]}, {sq[1]})", f"hop = {hop}", f"spin = {spin}", f'modifier = "{mod}"',
            f"modifier_time = {mt}", f'fx = "{fx}"', f'emote = "{emote}"', f"emote_color = {col(ec)}",
            f'sfx = "{sfx}"', f"shake = {shake}", f'then_clip = "{then}"']) + "\n"
        (OUT / f"{rid}.tres").write_text(body)
    readme = OUT.parent / "README.md"
    readme.write_text(
        "# Animations- & Reaktionsbibliothek\n\n"
        "Jede `.tres` in `reactions/` ist eine `ReactionClip`-Ressource (`scripts/core/reaction_clip.gd`).\n"
        "Sie kombiniert einen Rig-Clip (KayKit Rig_Medium bzw. Kenney-Clips), einen prozeduralen\n"
        "Bone-Modifier (`SlapstickModifier`), Squash & Stretch, Partikel, Emotes und Sound.\n\n"
        "Abspielen: `character_rig.react(\"cheer\")`. Neue Reaktionen: im Godot-Inspector duplizieren\n"
        "oder in `tools/gen_reactions.py` ergänzen.\n\n| Reaktion | Clip | Modifier | Effekt |\n|---|---|---|---|\n" +
        "\n".join(f"| `{k}` | {v[0]} | {v[5] or '–'} | {v[7] or '–'} |" for k, v in R.items()) + "\n")
    print(f"{len(R)} Reaktionen geschrieben nach {OUT}")


if __name__ == "__main__":
    main()
