# Animations- & Reaktionsbibliothek

Jede `.tres` in `reactions/` ist eine `ReactionClip`-Ressource (`scripts/core/reaction_clip.gd`).
Sie kombiniert einen Rig-Clip (KayKit Rig_Medium bzw. Kenney-Clips), einen prozeduralen
Bone-Modifier (`SlapstickModifier`), Squash & Stretch, Partikel, Emotes und Sound.

Abspielen: `character_rig.react("cheer")`. Neue Reaktionen: im Godot-Inspector duplizieren
oder in `tools/gen_reactions.py` ergänzen.

| Reaktion | Clip | Modifier | Effekt |
|---|---|---|---|
| `cheer` | cheer | triumph | stars |
| `triumph` | cheer | triumph | confetti |
| `wave` | wave | – | – |
| `determined` | punch | triumph | sparkle |
| `scared` | hit_b | scared | sweat |
| `shocked` | dodge_back | tremble | sweat |
| `hit` | hit | – | stars |
| `big_hit` | hit_b | dizzy | dizzy |
| `dizzy` | idle | dizzy | dizzy |
| `frustrated` | hammer | frustrated | anger |
| `tantrum` | hammer | frustrated | dust |
| `sad` | sit | sad | – |
| `laugh` | taunt_long | laugh | – |
| `taunt` | taunt | laugh | – |
| `sleepy` | sit | sad | zzz |
| `soot_blast` | death_b | dizzy | soot |
| `slip` | death_b | – | dust |
| `trip_fall` | death | dizzy | dust |
| `victory` | cheer | triumph | confetti |
| `confused` | idle_b | – | – |
| `coin_gain` | cheer | triumph | sparkle |
| `coin_loss` | hit | sad | sweat |
| `star_get` | cheer | triumph | confetti |
| `launch` | spawn_air | scared | – |
| `land_flat` | lie_down | dizzy | dust |
| `flex` | taunt_long | triumph | sparkle |
| `cursed` | hit_b | tremble | smoke |
| `pushups` | pushups | – | sweat |
