class_name LumosActorConfig
extends Resource
## Einstellungen je Figurentyp für das Character-Framework – und der Adapter, der sie aus einem Rig ableitet.
##
##   var cfg := LumosActorConfig.detect(rig)     # erkennt Knochen, Gliedmaßen-Art und Profil
##   cfg.breath = 0.5                              # danach frei anpassbar
##   LumosActor.attach(rig, cfg)
##
## Profile:
##  * "humanoid": zweiteilige Arme und Beine (KayKit-Helden, eigene Avatare auf dem KayKit-Rig) – alles verfügbar
##  * "simple":   einteilige Gliedmaßen (Kenney-Figuren) – Arme zielen als Ganzes, keine Fuß-IK
##  * "rigid":    kein Skelett (Haustiere) – Haltung, Lachen, Stöße und Blick über den ganzen Körper (Pivot)

@export var profile := "humanoid"

@export_group("Knochen")
@export var bone_hips := "hips"
@export var bone_chest := "chest"
@export var bone_head := "head"
## je Seite [Oberarm, Unterarm, Hand] (zweiteilig) bzw. [Arm] (einteilig) bzw. []
@export var arm_bones := {"l": ["upperarm.l", "lowerarm.l", "hand.l"], "r": ["upperarm.r", "lowerarm.r", "hand.r"]}
@export var leg_bones := {"l": ["upperleg.l", "lowerleg.l", "foot.l"], "r": ["upperleg.r", "lowerleg.r", "foot.r"]}
## Knochen, der die Hand dreht (KayKit: Handgelenk); leer = Handknochen
@export var wrist_bones := {"l": "wrist.l", "r": "wrist.r"}
## Handfläche in der Ruhepose (Skelett-Raum). KayKit-Ruhepose = T-Pose mit Handflächen nach unten.
@export var palm_rest := Vector3(0, -1, 0)

@export_group("Gesicht")
@export var face_enabled := true
@export var feature_scale := 1.0        ## Größe der Gesichtszüge (größer = von weitem lesbarer)

@export_group("Körper")
@export var breath := 0.35             ## Ruhe-Atmung (1 = außer Atem)
@export var breath_rate := 1.4
@export var idle_sway := 1.0           ## Gewichtsverlagerung im Stand
@export var lean_accel := 0.045        ## Vor-/Rücklage je m/s² Beschleunigung
@export var lean_turn := 0.12          ## Seitneigung in Kurven (rad je rad/s)
@export var impulse_stiffness := 70.0  ## Feder für Stöße/Treffer
@export var impulse_damping := 9.0
@export var posture_scale := 1.0       ## Stärke der Gefühls-Haltung (Brust, Kopf, Schultern)
@export var attention := 0.3           ## Anteil, mit dem sich der Oberkörper zum Blickziel dreht
@export var reach_lean := 0.5          ## Reach-Assist: max. Neigung (rad), mit der die Brust einem zu fernen Handziel folgt

@export_group("Füße")
@export var foot_ik := true
@export var foot_lock := true          ## Standfuß in der Standphase am Boden verankern
@export var foot_ik_max := 0.35        ## größte Bodenanpassung (m)
@export var ankle_height := 0.09       ## Höhe des Fußknochens über der Sohle (Skelett-Raum)
@export var ground_mask := 1           ## Kollisionsmaske der Bodenabfrage (Raycast), 0 = keine

@export_group("Leistung")
@export var lod := true                ## Detailstufen: fern → ohne Fuß-IK/Oberkörper-Blick, außerhalb des Bildes → pausiert
@export var lod_far := 24.0            ## ab dieser Entfernung (in Körpergrößen) gilt eine Figur als fern

@export_group("Fortbewegung")
@export var walk_speed := 0.0          ## 0 = aus dem Clip vermessen
@export var run_speed := 0.0
@export var accel := 9.0               ## m/s² beim Anfahren
@export var decel := 12.0              ## m/s² beim Bremsen
@export var turn_rate := 9.0           ## rad/s


## Adapter: Konfiguration aus dem Skelett ableiten (Knochennamen gängiger Rigs, ein- oder zweiteilige Gliedmaßen).
static func detect(rig: CharacterRig) -> LumosActorConfig:
	var c := LumosActorConfig.new()
	if rig == null or rig.skel == null:
		c.profile = "rigid"
		c.foot_ik = false
		c.foot_lock = false
		c.arm_bones = {"l": [], "r": []}
		c.leg_bones = {"l": [], "r": []}
		c.wrist_bones = {"l": "", "r": ""}
		return c
	var sk := rig.skel
	var names: Array[String] = []
	for i in sk.get_bone_count():
		names.append(sk.get_bone_name(i))
	c.bone_hips = _pick(names, ["hips", "pelvis", "root"], "")
	c.bone_chest = _pick(names, ["chest", "upperchest", "spine2", "spine1", "spine", "torso"], "")
	c.bone_head = _pick(names, ["head"], "")
	var two_arms := true
	var two_legs := true
	for sd in ["l", "r"]:
		var up := _limb(names, ["upperarm", "upper_arm", "arm"], sd, ["forearm", "lower"])
		var lo := _limb(names, ["lowerarm", "lower_arm", "forearm"], sd, [])
		var ha := _limb(names, ["hand"], sd, ["slot"])
		var wr := _limb(names, ["wrist"], sd, [])
		if up != "" and lo != "" and (ha != "" or wr != ""):
			c.arm_bones[sd] = [up, lo, ha if ha != "" else wr]
			c.wrist_bones[sd] = wr if wr != "" else ha
		elif up != "":
			c.arm_bones[sd] = [up]
			c.wrist_bones[sd] = ""
			two_arms = false
		else:
			c.arm_bones[sd] = []
			two_arms = false
		var ul := _limb(names, ["upperleg", "upper_leg", "thigh", "upleg", "leg"], sd, ["lower", "low"])
		var ll := _limb(names, ["lowerleg", "lower_leg", "shin", "calf", "knee"], sd, [])
		var ft := _limb(names, ["foot", "ankle"], sd, [])
		if ul != "" and ll != "" and ft != "":
			c.leg_bones[sd] = [ul, ll, ft]
		else:
			c.leg_bones[sd] = []
			two_legs = false
	if c.bone_chest == c.bone_hips:
		c.bone_hips = _pick(names, ["root"], "")
	c.profile = "humanoid" if two_arms and two_legs else "simple"
	if not two_legs:
		c.foot_ik = false
		c.foot_lock = false
	return c


static func _pick(names: Array[String], cands: Array, fallback: String) -> String:
	for cand in cands:
		for n in names:
			if n.to_lower() == String(cand):
				return n
	return fallback


## Gliedmaßen-Knochen einer Seite: Name enthält eines der Wörter und einen Seiten-Hinweis
## („.l“, „_l“, „-left“, „left…“), aber keines der Ausschlusswörter.
static func _limb(names: Array[String], words: Array, sd: String, exclude: Array) -> String:
	var side_words := ["left", "l"] if sd == "l" else ["right", "r"]
	for w in words:
		for n in names:
			var low := n.to_lower()
			if not low.contains(String(w)):
				continue
			var bad := false
			for ex in exclude:
				if low.contains(String(ex)):
					bad = true
			if bad:
				continue
			var side := low.contains(side_words[0]) or low.ends_with("." + sd) or low.ends_with("_" + sd) or low.ends_with("-" + sd) \
				or low.begins_with(sd + "_") or low.begins_with(sd + ".")
			if side:
				return n
	return ""
