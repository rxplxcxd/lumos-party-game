class_name LumosActorConfig
extends Resource
## Einstellungen je Figurentyp für das Character-Framework. Alle Werte haben sinnvolle Standardwerte
## (KayKit-Rig der Lumos-Helden); für andere Rigs nur die Knochennamen und Proportionen anpassen.

@export_group("Knochen")
@export var bone_hips := "hips"
@export var bone_chest := "chest"
@export var bone_head := "head"
@export var arm_bones := {"l": ["upperarm.l", "lowerarm.l", "hand.l"], "r": ["upperarm.r", "lowerarm.r", "hand.r"]}
@export var leg_bones := {"l": ["upperleg.l", "lowerleg.l", "foot.l"], "r": ["upperleg.r", "lowerleg.r", "foot.r"]}

@export_group("Gesicht")
@export var face_enabled := true

@export_group("Körper")
@export var breath := 0.35             ## Ruhe-Atmung (1 = außer Atem)
@export var breath_rate := 1.4
@export var idle_sway := 1.0           ## Gewichtsverlagerung im Stand
@export var lean_accel := 0.045        ## Vor-/Rücklage je m/s² Beschleunigung
@export var lean_turn := 0.12          ## Seitneigung in Kurven (rad je rad/s)
@export var impulse_stiffness := 70.0  ## Feder für Stöße/Treffer
@export var impulse_damping := 9.0
@export var foot_ik := true
@export var foot_ik_max := 0.35        ## größte Bodenanpassung (m)
@export var ankle_height := 0.09       ## Höhe des Fußknochens über der Sohle (Skelett-Raum)

@export_group("Fortbewegung")
@export var walk_speed := 0.0          ## 0 = aus dem Clip vermessen
@export var run_speed := 0.0
@export var accel := 9.0               ## m/s² beim Anfahren
@export var decel := 12.0              ## m/s² beim Bremsen
@export var turn_rate := 9.0           ## rad/s
