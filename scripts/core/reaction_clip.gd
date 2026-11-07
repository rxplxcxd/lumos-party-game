class_name ReactionClip
extends Resource
## Eine Slapstick-Reaktion aus der Animationsbibliothek (res://assets/animations/reactions/*.tres).
## Kombiniert Rig-Clip + prozeduralen Bone-Modifier + Squash & Stretch + Partikel + Sound.

@export var id := ""
## Logischer Clip-Name (siehe CharacterRig.MAP_*), z. B. "cheer", "hit", "hammer"
@export var clip := "idle"
@export var clip_speed := 1.0
## Wie lange die Reaktion Fortbewegungs-Animationen blockiert (Sekunden)
@export var hold := 1.0
## Anfangs-Squash: x = Breite (XZ), y = Höhe. (1,1) = keiner
@export var squash := Vector2.ONE
## Kleiner Hüpfer des Charakters (Meter)
@export var hop := 0.0
## Drehungen um die Hochachse (z. B. 1.0 = Pirouette)
@export var spin := 0.0
## Prozeduraler Bone-Modifier: dizzy | scared | frustrated | triumph | laugh | sad | tremble | ""
@export var modifier := ""
@export var modifier_time := 1.0
## Partikel/Effekt: stars | dizzy | confetti | sweat | anger | zzz | smoke | soot | dust | sparkle | ""
@export var fx := ""
## Emote-Symbol über dem Kopf ("!", "?", "#", "♪")
@export var emote := ""
@export var emote_color := Color(1, 0.85, 0.2)
@export var sfx := ""
@export var shake := 0.0
## Clip, der nach Ablauf gespielt wird (leer = zurück zu idle)
@export var then_clip := ""
