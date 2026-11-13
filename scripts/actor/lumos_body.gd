class_name LumosBody
extends SkeletonModifier3D
## Körper-Ebene des Character-Frameworks: prozedurale Bewegung und IK über der abgespielten Animation
## (läuft nach dem SlapstickModifier des Spiels). Alles additiv, gewichtet und geglättet – nichts springt.
##
##  * Arm-IK je Hand mit Handgelenk-Ausrichtung (Finger- und Handflächen-Richtung); einteilige Arme zielen als Ganzes
##  * Fuß-IK: Bodenhöhe (Callable oder Raycast), Becken gleicht aus; Standfuß-Verankerung in der Standphase
##  * Gefühls-Haltung (Brust, Kopf, Schultern), Aufmerksamkeit (Oberkörper dreht sich mit zum Blickziel),
##    Atmung, Gewichtsverlagerung im Stand, Lachen, Impuls-Feder für Stöße und Treffer
## Zeitbasis ist dt (vom Besitzer gesetzt) – unabhängig von der Bildrate.

## Haltung je Gefühl: Brust vor (+)/zurück (−), Kopf runter (+)/hoch (−), Schultern hoch (+), Kopf schief.
const POSTURE := {
	"neutral": [0.0, 0.0, 0.0, 0.0], "smile": [-0.04, -0.06, 0.0, 0.0], "grin": [-0.06, -0.08, 0.04, 0.0],
	"joy": [-0.1, -0.14, 0.06, 0.0], "laugh": [0.0, -0.04, 0.0, 0.0], "awe": [-0.16, -0.22, 0.14, 0.0],
	"surprised": [-0.14, -0.16, 0.16, 0.0], "curious": [0.08, 0.02, 0.0, 0.18], "confused": [0.0, 0.04, 0.1, -0.2],
	"scared": [-0.06, 0.14, 0.26, 0.0], "worried": [0.08, 0.12, 0.1, 0.06], "sad": [0.18, 0.14, -0.12, 0.12],
	"angry": [0.18, 0.12, 0.12, 0.0], "determined": [0.1, 0.06, 0.04, 0.0], "sleepy": [0.12, 0.22, -0.06, 0.06],
	"asleep": [0.2, 0.36, -0.08, -0.2], "pant": [0.35, -0.06, 0.08, 0.0], "ouch": [0.2, 0.16, 0.16, 0.0],
	"smug": [-0.08, -0.12, 0.0, 0.1], "dreamy": [0.0, -0.1, 0.0, 0.14], "plead": [0.1, -0.1, 0.1, 0.16],
	# 1.5.2 – erweitertes Gefühlsspektrum
	"delight": [-0.14, -0.18, 0.12, 0.0], "euphoria": [-0.2, -0.28, 0.18, 0.0], "pride": [-0.18, -0.2, -0.05, 0.0],
	"relief": [0.12, 0.06, -0.14, 0.0], "content": [0.0, -0.04, -0.03, 0.04], "affection": [0.02, 0.06, 0.0, 0.14],
	"tender": [0.05, 0.08, -0.02, 0.12], "playful": [-0.04, -0.06, 0.06, -0.1], "gloat": [-0.1, -0.08, 0.1, 0.05],
	"bashful": [0.12, 0.16, 0.12, 0.12], "disappointed": [0.22, 0.14, -0.16, 0.0], "fear": [-0.06, 0.14, 0.28, 0.0],
	"panic": [-0.12, 0.08, 0.34, 0.0], "anger": [0.18, 0.12, 0.12, 0.0], "frustrated": [0.12, 0.06, 0.16, 0.0],
	"jealous": [0.06, 0.08, 0.06, -0.14], "shame": [0.26, 0.32, 0.16, 0.0], "insecure": [0.1, 0.12, 0.14, 0.06],
	"lonely": [0.2, 0.18, -0.14, 0.08], "exhausted": [0.34, 0.08, -0.12, 0.0], "surprise": [-0.1, -0.12, 0.22, 0.0],
	"disbelief": [-0.06, -0.04, 0.06, 0.0], "suspicious": [-0.1, 0.02, 0.04, -0.08], "embarrassed": [0.1, 0.16, 0.16, 0.1],
	"nervous": [0.04, 0.06, 0.2, 0.0], "compassion": [0.12, 0.12, 0.0, 0.16], "admiration": [-0.08, -0.1, 0.06, 0.06],
	"defiant": [-0.14, -0.18, 0.04, 0.0], "impatient": [0.02, 0.0, 0.06, 0.0], "focus": [0.14, 0.08, 0.04, 0.0],
	"pensive": [0.04, 0.06, 0.0, 0.1], "teasing": [0.06, -0.06, 0.06, -0.12], "cry": [-0.12, -0.3, 0.2, 0.0],
	"love": [0.0, 0.04, 0.04, 0.14], "puppy": [0.08, 0.1, 0.12, 0.14], "sulk": [-0.06, -0.12, 0.08, -0.06],
	"puffed": [0.1, 0.04, 0.18, 0.0], "dizzy": [0.04, 0.06, 0.0, 0.18], "cross_eyed": [0.0, 0.0, 0.06, 0.0],
	"sleep_smile": [0.2, 0.3, -0.08, -0.15],
}
## Zubehör, das nachschwingt (Name enthält …): Art, Stärke. Hüte wippen um ihren Ansatz, Umhänge hängen und wehen.
const JIGGLE_KINDS := [["helmet", "hat", 0.22], ["visor", "hat", 0.22], ["bearhat", "hat", 0.4], ["hat", "hat", 1.0],
	["hood", "hat", 0.5], ["hair", "hat", 0.8], ["cape", "cape", 1.0], ["cloak", "cape", 1.0], ["quiver", "pack", 0.6],
	["backpack", "pack", 0.6], ["tail", "pack", 1.0]]

var cfg := LumosActorConfig.new()
var dt := 1.0 / 60.0
var laugh := 0.0
var laugh_phase := 0.0
var breath := 0.35
var breath_rate := 1.4
var head_add := Vector3.ZERO        # (nicken, drehen, schief) rad
var chest_add := Vector3.ZERO
var lean := Vector2.ZERO            # (vor/zurück, seitlich) rad
var hand_w := {"l": 0.0, "r": 0.0}
var hand_t := {"l": Vector3.ZERO, "r": Vector3.ZERO}
var lite := false                 # LOD „fern“: Fuß-IK und Oberkörper-Blick blenden aus
var _lite_k := 0.0
var hand_assist := {"l": 1.0, "r": 1.0}   # Reach-Assist je Hand (0–1)
var hand_dir := {"l": [], "r": []}  # [Fingerrichtung, Handflächenrichtung] (Welt) oder leer = Hand bleibt, wie sie ist
var ground := Callable()            # Callable(Vector3) → float; leer = Raycast (cfg.ground_mask) bzw. Höhe der Figur
var grounded := true                # false (Sprung, Sitzen auf etwas Höherem): keine Fuß-IK, keine Verankerung
var foot_w := 1.0
var attend_target := Vector3.ZERO   # Blickziel (Welt); attend_w 0..1
var attend_w := 0.0
# --- 1.5.2: Gewicht, Balance, Sekundärbewegung ---
var weight_shift := 0.0             # −1..1 Gewicht aufs eine/andere Bein (Kontrapost; von LumosMicro)
var crouch := 0.0                   # 0..1 in die Knie (Lachanfall, Verstecken, Ausholen vor dem Sprung)
var load := 0.0                     # 0..1 schwerer Gegenstand: zurücklehnen, einsinken, Schultern tiefer
var hop_lift := 0.0                 # Höhe eines Pivot-Sprungs (CharacterRig.hop) – dann keine Fußverankerung
var micro_head := Vector3.ZERO      # Kopf-Zusatz aus Mikrobewegung/Cartoon (getrennt von head_add der Regie)
var micro_chest := Vector3.ZERO
var tremble := 0.0                  # Zittern (Angst, Kälte, Schluchzen)
var hat_avoid := Vector3.ZERO       # Welt-Richtung zu einem nahen Kopf (Länge 0..1): die Hutkrempe weicht nach hinten aus
var traits := {"mass": 1.0, "agility": 1.0, "bounce": 0.5}

var _b := {}
var _head := Vector3.ZERO
var _chest := Vector3.ZERO
var _lean := Vector2.ZERO
var _post := Vector4.ZERO
var _post_t := Vector4.ZERO
var _post_tau := 0.3
var _imp := Vector3.ZERO
var _imp_v := Vector3.ZERO
var _hand_s := {"l": Vector3.ZERO, "r": Vector3.ZERO}
var _hand_on := {"l": false, "r": false}
var _hand_rest := {}                # Seite → [Ruhe-Basis Handgelenk, Finger (Ruhe), Handfläche (Ruhe)] im Skelett-Raum
var _aim_tip := {}                  # Knochen → Spitze relativ zum Knochen (Ruhepose), für einteilige Gliedmaßen
var _foot := {"l": {}, "r": {}}     # Verankerung je Fuß
var _foot_dy := {"l": 0.0, "r": 0.0}
var _pelvis := 0.0
var _leg_len := 0.5
var _last_root := Vector3.INF
var _pos := {}                      # Gelenk → Weltposition nach der Modifikation
var _hand_basis := {}               # Seite → Welt-Basis des Handgelenks nach der Modifikation
var _t := 0.0
var _arm_len := 0.5
var _reach_len := 0.5            # Schulter → Handgelenk (IK-Kette bei ausgerichteter Hand)
var _hand_q := {}                 # Seite → geglättete Handdrehung (Quaternion, Skelett-Raum)
var _pole := {}                   # Seite → geglättete Ellbogen-Richtung
var _hand_off := {}               # Seite → Versatz Handgelenk→Hand (Ruhepose, Skelett-Raum)
var _rv := Vector3.ZERO           # Wurzel: Geschwindigkeit, Beschleunigung (Skelett-Raum), Gierrate
var _ra := Vector3.ZERO
var _yaw_prev := INF
var _yaw_rate := 0.0
var _iner := Vector4.ZERO         # Trägheitsfedern: Brust (Neigung, Seite), Kopf (Neigung, Seite)
var _iner_v := Vector4.ZERO
var _arm_sw := 0.0                # Armschwung aus Trägheit
var _arm_sw_v := 0.0
var _turn_lag := 0.0              # Brust folgt einer Drehung verzögert
var _turn_lag_v := 0.0
var _ws := 0.0                    # geglättete Gewichtsverlagerung
var _drop := 0.0                  # Becken-Feder (m, + = tiefer)
var _drop_v := 0.0
var _flail := 0.0                 # Arme rudern (Stolpern)
var _jig: Array = []              # Zubehör-Federn: {bone, parent, rest (Transform3D), kind, gain, ang, vel, prev, pv}


func bind(skel: Skeleton3D, config: LumosActorConfig = null) -> bool:
	if config:
		cfg = config
	breath = cfg.breath
	breath_rate = cfg.breath_rate
	_b = {"hips": skel.find_bone(cfg.bone_hips), "chest": skel.find_bone(cfg.bone_chest), "head": skel.find_bone(cfg.bone_head)}
	for sd in ["l", "r"]:
		var a: Array = cfg.arm_bones.get(sd, [])
		var l: Array = cfg.leg_bones.get(sd, [])
		for k in 3:
			_b["arm%d.%s" % [k, sd]] = skel.find_bone(String(a[k])) if a.size() > k else -1
			_b["leg%d.%s" % [k, sd]] = skel.find_bone(String(l[k])) if l.size() == 3 else -1
		_b["wrist." + sd] = skel.find_bone(String(cfg.wrist_bones.get(sd, ""))) if String(cfg.wrist_bones.get(sd, "")) != "" else int(_b["arm2." + sd])
		_foot[sd] = {"on": false, "w": 0.0, "pos": Vector3.ZERO, "sole": INF, "step": 0.0}
		_bind_hand(skel, sd)
		if int(_b["arm0." + sd]) >= 0 and int(_b["arm1." + sd]) < 0:
			_bind_aim(skel, int(_b["arm0." + sd]))
	if arm_mode() == "2bone":
		_arm_len = skel.get_bone_global_rest(int(_b["arm0.l"])).origin.distance_to(skel.get_bone_global_rest(int(_b["arm1.l"])).origin) \
			+ skel.get_bone_global_rest(int(_b["arm1.l"])).origin.distance_to(skel.get_bone_global_rest(int(_b["arm2.l"])).origin)
		_reach_len = skel.get_bone_global_rest(int(_b["arm0.l"])).origin.distance_to(skel.get_bone_global_rest(int(_b["arm1.l"])).origin) \
			+ skel.get_bone_global_rest(int(_b["arm1.l"])).origin.distance_to(skel.get_bone_global_rest(int(_b["wrist.l"]) if int(_b["wrist.l"]) >= 0 else int(_b["arm2.l"])).origin)
	if has_legs():
		_leg_len = skel.get_bone_global_rest(int(_b["leg0.l"])).origin.distance_to(skel.get_bone_global_rest(int(_b["leg2.l"])).origin)
	_t = randf() * 10.0
	traits = {"mass": cfg.mass, "agility": cfg.agility, "bounce": cfg.bounce}
	if cfg.jiggle:
		_setup_jiggle(skel)
	return int(_b.head) >= 0


func has_arms() -> bool:
	return int(_b.get("arm0.l", -1)) >= 0


func arm_mode() -> String:
	if int(_b.get("arm0.l", -1)) < 0:
		return "none"
	return "2bone" if int(_b.get("arm1.l", -1)) >= 0 and int(_b.get("arm2.l", -1)) >= 0 else "aim"


func has_legs() -> bool:
	return int(_b.get("leg0.l", -1)) >= 0 and int(_b.get("leg2.l", -1)) >= 0


## Weltposition eines Gelenks NACH allen Modifikatoren (Stand des letzten Bildes):
## "hand.l/r", "shoulder.l/r", "elbow.l/r", "thigh.l/r", "knee.l/r", "foot.l/r", "head", "chest", "hips".
## (Godot setzt die Knochen nach dem Skinning zurück – von außen abgefragte Posen wären die unveränderten.)
func joint_pos(name: String) -> Vector3:
	var key := _key(name)
	if _pos.has(key):
		return _pos[key]
	var sk := get_skeleton()
	var i: int = _b.get(key, -1)
	if sk == null or i < 0:
		return sk.global_position if sk else Vector3.ZERO
	return sk.global_transform * sk.get_bone_global_pose(i).origin


## Gelenk in der Ruhepose, mit der aktuellen Lage des Skeletts (Welt) – sofort gültig, auch direkt nach einem
## Versetzen der Figur (joint_pos kennt dann erst im nächsten Bild die neue Lage).
func rest_pos(name: String) -> Vector3:
	var sk := get_skeleton()
	var i: int = _b.get(_key(name), -1)
	if sk == null or i < 0:
		return sk.global_position if sk else Vector3.ZERO
	return sk.global_transform * sk.get_bone_global_rest(i).origin


func _key(name: String) -> String:
	var parts := name.split(".")
	if parts.size() != 2:
		return name
	var key := String({"shoulder": "arm0.", "elbow": "arm1.", "hand": "arm2.", "thigh": "leg0.", "knee": "leg1.", "foot": "leg2."}.get(parts[0], parts[0] + ".")) + parts[1]
	if key.begins_with("arm2.") and int(_b.get(key, -1)) < 0:
		key = "tip." + parts[1]   # einteiliger Arm: Spitze
	return key


## Fingerrichtung und Handflächen-Normale (Welt) der Hand nach der Modifikation – für Tests und Griffe.
func hand_axes(sd: String) -> Array:
	if not _hand_basis.has(sd) or not _hand_rest.has(sd):
		return [Vector3.ZERO, Vector3.ZERO]
	var bw: Basis = _hand_basis[sd]
	var rest: Array = _hand_rest[sd]
	var inv: Basis = (rest[0] as Basis).inverse()
	return [(bw * (inv * (rest[1] as Vector3))).normalized(), (bw * (inv * (rest[2] as Vector3))).normalized()]


## Stoß in Weltrichtung: Oberkörper und Kopf schwingen gedämpft nach.
func push(world_impulse: Vector3) -> void:
	var sk := get_skeleton()
	if sk:
		_imp_v += sk.global_transform.basis.inverse() * world_impulse


## Haltung direkt (Brust, Kopf, Schultern, Neigung) – LumosEmotion mischt sie aus den Gefühlen.
func set_posture_vec(v: Vector4, secs := 0.3) -> void:
	_post_t = v * cfg.posture_scale
	_post_tau = maxf(secs, 0.02) / 2.5


## Gefühls-Haltung (Namen wie die Gesichtsausdrücke), weich in secs Sekunden.
func set_posture(name: String, secs := 0.3, intensity := 1.0) -> void:
	var p: Array = POSTURE.get(name, POSTURE.neutral)
	_post_t = Vector4(p[0], p[1], p[2], p[3]) * intensity * cfg.posture_scale
	_post_tau = maxf(secs, 0.02) / 2.5


func _bind_hand(sk: Skeleton3D, sd: String) -> void:
	var wi: int = _b.get("wrist." + sd, -1)
	if wi < 0 or int(_b.get("arm1." + sd, -1)) < 0:
		return
	var wr := sk.get_bone_global_rest(wi)
	var ref := -1
	for c in sk.get_bone_children(wi):
		ref = c
	var fdir := Vector3.ZERO
	if ref >= 0:
		for c2 in sk.get_bone_children(ref):   # weiter entfernter Kindknochen (Handslot) = Fingerspitze
			ref = c2
		fdir = sk.get_bone_global_rest(ref).origin - wr.origin
	if fdir.length() < 0.01:
		fdir = wr.origin - sk.get_bone_global_rest(int(_b["arm1." + sd])).origin
	fdir = fdir.normalized()
	var palm := cfg.palm_rest - fdir * cfg.palm_rest.dot(fdir)
	if palm.length() < 0.01:
		palm = Vector3.FORWARD
	_hand_rest[sd] = [wr.basis.orthonormalized(), fdir, palm.normalized()]
	var hi: int = _b.get("arm2." + sd, -1)
	if hi >= 0 and hi != wi:
		_hand_off[sd] = sk.get_bone_global_rest(hi).origin - wr.origin


## Einteilige Gliedmaße: ihre Spitze aus den Haut-Gewichten bestimmen (Schwerpunkt der Vertices × 2).
func _bind_aim(sk: Skeleton3D, bone: int) -> void:
	var origin := sk.get_bone_global_rest(bone).origin
	var sum := Vector3.ZERO
	var n := 0
	for ch in sk.get_children():
		var mi := ch as MeshInstance3D
		if mi == null or mi.skin == null or mi.mesh == null:
			continue
		var bind_idx := -1
		for bi in mi.skin.get_bind_count():
			if mi.skin.get_bind_name(bi) == sk.get_bone_name(bone) or mi.skin.get_bind_bone(bi) == bone:
				bind_idx = bi
		if bind_idx < 0:
			continue
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES] if arr[Mesh.ARRAY_BONES] != null else PackedInt32Array()
			var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS] if arr[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
			if bones.is_empty() or ws.size() != bones.size():
				continue
			var per := bones.size() / vs.size()
			for v in vs.size():
				for k in per:
					if bones[v * per + k] == bind_idx and ws[v * per + k] > 0.5:
						sum += vs[v]
						n += 1
	var tip := (sum / n - origin) * 2.0 if n > 0 else Vector3(0, -0.4, 0)
	_aim_tip[bone] = sk.get_bone_global_rest(bone).basis.inverse() * tip


func _rot(sk: Skeleton3D, bone: String, axis: Vector3, angle: float) -> void:
	var i: int = _b.get(bone, -1)
	if i < 0 or absf(angle) < 0.0001:
		return
	var g := sk.get_bone_global_pose(i)
	g.basis = Basis(axis, angle) * g.basis
	sk.set_bone_global_pose(i, g)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _b.is_empty():
		return
	_t += dt
	laugh_phase += dt * 17.0
	var f := 1.0 - exp(-dt / 0.12)
	_head = _head.lerp(head_add, f)
	_chest = _chest.lerp(chest_add, f)
	_lean = _lean.lerp(lean, 1.0 - exp(-dt / 0.18))
	_post = _post.lerp(_post_t, 1.0 - exp(-dt / _post_tau))
	_imp_v += (-_imp * cfg.impulse_stiffness - _imp_v * cfg.impulse_damping) * dt
	_imp += _imp_v * dt
	_imp = _imp.limit_length(1.2)
	_dynamics(sk)
	var br := sin(_t * breath_rate * TAU / 2.6) * breath
	var sway := sin(_t * 0.55) * 0.035 * cfg.idle_sway * clampf(1.0 - _lean.length() * 6.0, 0.0, 1.0)
	var trem := sin(_t * 47.0) * 0.022 * tremble
	var chest_pitch := _chest.x + _post.x - br * 0.03 + _lean.x + _imp.z * 0.45 + _iner.x + micro_chest.x - 0.16 * load
	var chest_roll := _chest.z + _lean.y + _imp.x * 0.45 + sway * 0.5 + _iner.y + micro_chest.z + trem
	var shoulder := br * 0.035 + _post.z - 0.05 * load + absf(trem) * 0.6
	var head_pitch := _head.x + _post.y + br * 0.012 - _imp.z * 0.3 - _lean.x * 0.4 + _iner.z + micro_head.x + sin(_t * 53.0) * 0.016 * tremble
	var head_roll := _head.z + _post.w - _imp.x * 0.3 - sway * 0.4 + _iner.w + micro_head.z
	if laugh > 0.001:
		var s := sin(laugh_phase)
		chest_pitch += (s * 0.07 - 0.09) * laugh
		shoulder += (0.1 + 0.09 * s) * laugh
		head_pitch += (-0.2 + 0.07 * sin(laugh_phase + 0.6)) * laugh
	# Aufmerksamkeit: Oberkörper dreht sich mit zum Blickziel, der Kopf (vom Blick-Modifier gedreht) bleibt auf Ziel
	_lite_k = move_toward(_lite_k, 1.0 if lite else 0.0, dt / 0.3)
	var turn := 0.0
	if attend_w > 0.01 and _lite_k < 0.999:
		var loc := sk.global_transform.affine_inverse() * attend_target
		turn = clampf(atan2(loc.x, loc.z), -1.2, 1.2) * cfg.attention * attend_w * (1.0 - _lite_k)
	_rot(sk, "hips", Vector3.FORWARD, sway)
	_rot(sk, "hips", Vector3.UP, turn * 0.3)
	_rot(sk, "chest", Vector3.RIGHT, chest_pitch)
	_rot(sk, "chest", Vector3.UP, _chest.y + turn * 0.7 + _turn_lag + micro_chest.y)
	_rot(sk, "chest", Vector3.FORWARD, chest_roll)
	_rot(sk, "arm0.l", Vector3.FORWARD, -shoulder)
	_rot(sk, "arm0.r", Vector3.FORWARD, shoulder)
	# Arme schwingen träge nach (Anhalten → nach vorn) und rudern beim Stolpern – nur, wo keine Hand-IK greift
	for sd in ["l", "r"]:
		var free := 1.0 - float(hand_w[sd])
		if free > 0.01:
			var fl := sin(_t * 15.0 + (0.0 if sd == "l" else 2.2)) * 0.9 * _flail
			_rot(sk, "arm0." + sd, Vector3.RIGHT, (-_arm_sw + fl) * free)
			if _flail > 0.01:
				_rot(sk, "arm0." + sd, Vector3.FORWARD, (0.6 * _flail + absf(fl) * 0.3) * (-1.0 if sd == "l" else 1.0) * free)
	_rot(sk, "head", Vector3.RIGHT, head_pitch)
	_rot(sk, "head", Vector3.UP, _head.y - turn + micro_head.y + clampf(_yaw_rate * 0.07, -0.35, 0.35))   # Kopf führt in Drehungen
	_rot(sk, "head", Vector3.FORWARD, head_roll)
	# Teleport (Szenenwechsel, Zurücksetzen): Verankerung lösen
	var root := sk.global_position
	if _last_root != Vector3.INF and root.distance_to(_last_root) > 1.5:
		for sd in ["l", "r"]:
			_foot[sd].on = false
			_foot[sd].w = 0.0
	_last_root = root
	foot_w = move_toward(foot_w, 1.0 if grounded and not lite and hop_lift < 0.02 else 0.0, dt / 0.12)
	if cfg.foot_ik and has_legs() and foot_w > 0.001:
		_feet(sk)
	# Kontrapost: die Schultern kippen gegen das Becken, der Kopf bleibt fast waagerecht
	if absf(_ws) > 0.002:
		_rot(sk, "chest", Vector3.FORWARD, _ws * 0.1 * foot_w)
		_rot(sk, "head", Vector3.FORWARD, -_ws * 0.035 * foot_w)
	# Hände: Ziel (geglättet) → Handgelenk-Ziel (bei vorgegebener Handdrehung), Reach-Assist, dann IK
	var mode := arm_mode()
	var ik_t := {}
	var ik_b := {}
	for sd in ["l", "r"]:
		var w: float = hand_w[sd]
		if w <= 0.001:
			_hand_on[sd] = false
			_hand_q.erase(sd)
			continue
		_hand_s[sd] = hand_t[sd] if not _hand_on[sd] else (_hand_s[sd] as Vector3).lerp(hand_t[sd], 1.0 - exp(-dt / 0.035))
		_hand_on[sd] = true
		var tg := sk.global_transform.affine_inverse() * (_hand_s[sd] as Vector3)
		var hd: Array = hand_dir[sd]
		var want := _hand_basis_for(sk, sd, hd[0], hd[1]) if mode == "2bone" and hd.size() == 2 else Basis()
		if want != Basis():
			# Wechsel der Handhaltung (z. B. Greifen von oben → Halten von unten) gleitet statt umzuklappen
			var q := want.orthonormalized().get_rotation_quaternion()
			if _hand_q.has(sd):
				q = (_hand_q[sd] as Quaternion).slerp(q, 1.0 - exp(-dt / 0.07))
			_hand_q[sd] = q
			want = Basis(q).scaled(want.get_scale())
		else:
			_hand_q.erase(sd)
		if want != Basis() and _hand_off.has(sd):
			# Ziel gilt für die Hand: Handgelenk so setzen, dass die gedrehte Hand genau dort landet
			tg -= (want * ((_hand_rest[sd] as Array)[0] as Basis).inverse()) * (_hand_off[sd] as Vector3)
		ik_t[sd] = tg
		ik_b[sd] = want
	if mode == "2bone" and cfg.reach_lean > 0.0:
		for sd: String in ik_t:
			_lean_to(sk, sd, ik_t[sd], float(hand_w[sd]) * float(hand_assist[sd]), ik_b[sd] != Basis() and _hand_off.has(sd))
	for sd: String in ik_t:
		var w: float = hand_w[sd]
		if mode == "2bone":
			# Ellbogen-Richtung: unten-außen-hinten; liegt das Ziel über der Schulter (Kopf kratzen, Winken), wandert sie
			# nach außen-hinten – sonst stünde sie fast entgegen der Zielrichtung und der Ellbogen könnte umklappen.
			var sx := 1.0 if sd == "l" else -1.0
			var shp := sk.get_bone_global_pose(int(_b["arm0." + sd])).origin
			var up_f := clampf(((ik_t[sd] as Vector3) - shp).normalized().y, 0.0, 1.0)
			var pole_t := Vector3(sx * (0.45 + 0.85 * up_f), -1.0 * (1.0 - up_f) - 0.12, -0.55)
			_pole[sd] = pole_t if not _pole.has(sd) else (_pole[sd] as Vector3).lerp(pole_t, 1.0 - exp(-dt / 0.08))
			var pole: Vector3 = _pole[sd]
			_ik(sk, "arm0." + sd, "arm1." + sd, ("wrist." if ik_b[sd] != Basis() and _hand_off.has(sd) else "arm2.") + sd, ik_t[sd], pole, w, 0.985)
			if ik_b[sd] != Basis():
				_set_hand_basis(sk, sd, ik_b[sd], w)
		elif mode == "aim":
			_aim(sk, int(_b["arm0." + sd]), ik_t[sd], w)
	if not _jig.is_empty():
		_update_jiggle(sk)
	# Gelenk-Positionen nach der Modifikation merken
	var gx := sk.global_transform
	for k in _b:
		if int(_b[k]) >= 0:
			_pos[k] = gx * sk.get_bone_global_pose(int(_b[k])).origin
	for sd in ["l", "r"]:
		var a0: int = _b.get("arm0." + sd, -1)
		if a0 >= 0 and _aim_tip.has(a0):
			var pa := sk.get_bone_global_pose(a0)
			_pos["tip." + sd] = gx * (pa.origin + pa.basis * (_aim_tip[a0] as Vector3))
		var wi: int = _b.get("wrist." + sd, -1)
		if wi >= 0:
			_hand_basis[sd] = gx.basis * sk.get_bone_global_pose(wi).basis


## Gewicht und Trägheit je Bild: Wurzel-Beschleunigung und Gierrate aus der Bewegung der Figur → Federn für
## Oberkörper (kippt beim Bremsen nach vorn, beim Anfahren zurück), Kopf (schwingt verzögert nach), Arme (pendeln),
## Brust in Drehungen (folgt verzögert, der Kopf führt), Gewichtsverlagerung und Becken (Landen, Hocke, Last).
## Masse und Beweglichkeit (traits) bestimmen Frequenz und Ausschlag: schwer = träger und tiefer.
func _dynamics(sk: Skeleton3D) -> void:
	var root := sk.global_position
	var h := maxf(dt, 0.001)
	var mass := maxf(float(traits.mass), 0.3)
	var agi := maxf(float(traits.agility), 0.3)
	var bounce := clampf(float(traits.bounce), 0.0, 1.0)
	var inv_b := sk.global_basis.orthonormalized().inverse()
	var fz := sk.global_basis.z
	var yaw := atan2(fz.x, fz.z)
	if _last_root == Vector3.INF or root.distance_to(_last_root) > 1.5:
		_rv = Vector3.ZERO
		_ra = Vector3.ZERO
		_yaw_prev = yaw
		_reset_jiggle()
	else:
		var v := inv_b * (root - _last_root) / h
		_ra = _ra.lerp(((v - _rv) / h).limit_length(40.0), 1.0 - exp(-dt / 0.06))
		_rv = v
		_yaw_rate = lerpf(_yaw_rate, clampf(wrapf(yaw - _yaw_prev, -PI, PI) / h, -8.0, 8.0), 1.0 - exp(-dt / 0.05))
		_yaw_prev = yaw
	var sm := sqrt(mass)
	var zc := lerpf(0.78, 0.4, bounce)
	# Oberkörper (Neigung vor/zurück, seitlich) – Trägheit gegen die Beschleunigung
	var tgt_p := clampf(-_ra.z * 0.016 * sm, -0.35, 0.35)
	var tgt_r := clampf(-_ra.x * 0.01 * sm, -0.25, 0.25)
	var sp := spring(_iner.x, _iner_v.x, tgt_p, 1.7 * agi / sm, zc, dt)
	var sr := spring(_iner.y, _iner_v.y, tgt_r, 1.7 * agi / sm, zc, dt)
	# Kopf: folgt dem Oberkörper verzögert und schwingt etwas weiter (Nachbewegung)
	var hp := spring(_iner.z, _iner_v.z, _iner.x * 0.75, 2.6 * agi / sm, zc * 0.85, dt)
	var hr := spring(_iner.w, _iner_v.w, _iner.y * 0.6, 2.6 * agi / sm, zc * 0.85, dt)
	_iner = Vector4(sp.x, sr.x, hp.x, hr.x)
	_iner_v = Vector4(sp.y, sr.y, hp.y, hr.y)
	var sa := spring(_arm_sw, _arm_sw_v, clampf(-_ra.z * 0.03 * sm, -0.6, 0.6), 1.3 / sm, lerpf(0.6, 0.3, bounce), dt)
	_arm_sw = sa.x
	_arm_sw_v = sa.y
	var st := spring(_turn_lag, _turn_lag_v, clampf(-_yaw_rate * 0.05, -0.3, 0.3), 2.2 * agi, 0.7, dt)
	_turn_lag = st.x
	_turn_lag_v = st.y
	_ws = lerpf(_ws, clampf(weight_shift, -1.0, 1.0), 1.0 - exp(-dt / 0.45))
	var drop_t := (crouch * 0.24 + load * 0.08) * _leg_len * sk.global_basis.get_scale().y
	var sd := spring(_drop, _drop_v, drop_t, 2.4 * agi / sm, lerpf(0.8, 0.45, bounce), dt)
	_drop = sd.x
	_drop_v = sd.y
	_flail = move_toward(_flail, 0.0, dt / 0.9)


## Gedämpfte Feder (halbimplizit, mit Unterschritten bei großen Zeitschritten) → (Wert, Geschwindigkeit).
static func spring(x: float, v: float, target: float, hz: float, zeta: float, step: float) -> Vector2:
	var k := pow(TAU * hz, 2.0)
	var c := 2.0 * zeta * TAU * hz
	var n := maxi(1, ceili(step / (1.0 / 90.0)))
	var hh := step / n
	for i in n:
		v += ((target - x) * k - v * c) * hh
		x += v * hh
	return Vector2(x, v)


## Landung (Sprung, Stolpern): das Becken federt ein – schwere Figuren tiefer und langsamer, leichte federnder.
func land(strength := 1.0) -> void:
	var sk := get_skeleton()
	var sc := sk.global_basis.get_scale().y if sk else 1.0
	_drop_v += 0.9 * clampf(strength, 0.0, 2.0) * sqrt(maxf(float(traits.mass), 0.3)) * sc


## Gleichgewicht verlieren: starker Stoß, die Füße lösen sich zum Ausfallschritt, die Arme rudern, dann fängt
## sich die Figur über die Federn wieder.
func stumble(world_dir: Vector3, strength := 1.0) -> void:
	if world_dir.length() > 0.001:
		push(world_dir.normalized() * 6.0 * strength)
	_flail = clampf(maxf(_flail, strength), 0.0, 1.0)
	_drop_v += 0.5 * strength
	for sd in ["l", "r"]:
		if not (_foot[sd] as Dictionary).is_empty():
			_foot[sd].on = false
			_foot[sd].step = 1.0


## Messwerte für Tests: Trägheitswinkel (Brust, Kopf), Armschwung, Becken, Gewichtsverlagerung, Gierrate.
func dynamics_state() -> Dictionary:
	return {"chest": Vector2(_iner.x, _iner.y), "head": Vector2(_iner.z, _iner.w), "arms": _arm_sw, "drop": _drop, "ws": _ws,
		"yaw_rate": _yaw_rate, "turn_lag": _turn_lag, "acc": _ra, "vel": _rv}


## Zubehör (Hüte, Helme, Umhänge, Köcher): eigener Knochen je Teil; die Haut des Teils wird darauf umgebunden
## (Kopie der Skin-Ressource je Figur – Modelldateien bleiben unverändert). Drehpunkt am Ansatz des Teils.
func _setup_jiggle(sk: Skeleton3D) -> void:
	for c in sk.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.skin == null or mi.mesh == null:
			continue
		var nm := String(mi.name).to_lower()
		var kind := ""
		var gain := 0.0
		for e: Array in JIGGLE_KINDS:
			if nm.contains(String(e[0])):
				kind = String(e[1])
				gain = float(e[2])
				break
		if kind == "":
			continue
		var used := {}
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var bs: PackedInt32Array = arr[Mesh.ARRAY_BONES] if arr[Mesh.ARRAY_BONES] != null else PackedInt32Array()
			var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS] if arr[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
			for q in mini(bs.size(), ws.size()):
				if ws[q] > 0.01:
					used[bs[q]] = int(used.get(bs[q], 0)) + 1
		if used.is_empty():
			continue
		var skin := mi.skin
		var top := -1
		var top_n := -1
		for bi: int in used:
			if int(used[bi]) > top_n:
				top_n = int(used[bi])
				top = bi
		var parent := _bind_bone(sk, skin, top)
		if kind != "hat":
			parent = int(_b.get("chest", parent))   # Umhang und Köcher hängen am Oberkörper
		if parent < 0:
			continue
		var bb := mi.transform * mi.get_aabb()
		var pc := bb.get_center()
		var pivot := Vector3(pc.x, bb.position.y + bb.size.y * 0.28, pc.z)
		if kind != "hat":   # Ansatz oben, an der Körperseite des Teils
			pivot = Vector3(pc.x, bb.end.y - bb.size.y * 0.06, (bb.end.z - bb.size.z * 0.25) if pc.z < 0.0 else (bb.position.z + bb.size.z * 0.25))
		var gr := Transform3D(Basis(), pivot)
		var bname := "lumos_jig_%d" % _jig.size()
		var jb := sk.get_bone_count()
		sk.add_bone(bname)
		sk.set_bone_parent(jb, parent)
		var local := sk.get_bone_global_rest(parent).affine_inverse() * gr
		sk.set_bone_rest(jb, local)
		sk.set_bone_pose(jb, local)
		var ns := skin.duplicate() as Skin
		for bi2: int in used:
			var ob := _bind_bone(sk, skin, bi2)
			if ob < 0:
				continue
			ns.set_bind_pose(bi2, gr.affine_inverse() * sk.get_bone_global_rest(ob) * skin.get_bind_pose(bi2))
			if skin.get_bind_name(bi2) != &"":
				ns.set_bind_name(bi2, bname)
			else:
				ns.set_bind_bone(bi2, jb)
		mi.skin = ns
		_jig.append({"bone": jb, "parent": parent, "local": local, "kind": kind, "gain": gain, "name": String(mi.name),
			"rad": maxf(bb.size.x, bb.size.z) * 0.5,
			"ang": Vector2.ZERO, "vel": Vector2.ZERO, "prev": Vector3.INF, "pv": Vector3.ZERO, "pa": Vector3.ZERO})


func _bind_bone(sk: Skeleton3D, skin: Skin, i: int) -> int:
	var bn := skin.get_bind_name(i)
	return sk.find_bone(bn) if bn != &"" else skin.get_bind_bone(i)


func _reset_jiggle() -> void:
	for j: Dictionary in _jig:
		j.prev = Vector3.INF
		j.pv = Vector3.ZERO
		j.pa = Vector3.ZERO
		j.vel = Vector2.ZERO


## Zubehör-Federn: Hüte kippen gegen die Beschleunigung und wippen nach, Umhänge heben sich mit dem Tempo, hängen
## sonst und schwingen seitlich; alles begrenzt, damit nichts durch den Körper schlägt.
func _update_jiggle(sk: Skeleton3D) -> void:
	var gx := sk.global_transform
	var inv_b := gx.basis.orthonormalized().inverse()
	var cp := 0.0
	var ci: int = _b.get("chest", -1)
	if ci >= 0:
		var cu := sk.get_bone_global_pose(ci).basis.y.normalized()
		cp = atan2(cu.z, cu.y)
	var mass := maxf(float(traits.mass), 0.3)
	for j: Dictionary in _jig:
		var base: Transform3D = sk.get_bone_global_pose(int(j.parent)) * (j.local as Transform3D)
		var wp := gx * base.origin
		var a_loc := Vector3.ZERO
		if (j.prev as Vector3) != Vector3.INF:
			var v := (wp - (j.prev as Vector3)) / maxf(dt, 0.001)
			j.pa = (j.pa as Vector3).lerp(((v - (j.pv as Vector3)) / maxf(dt, 0.001)).limit_length(60.0), 1.0 - exp(-dt / 0.04))
			j.pv = v
			a_loc = inv_b * (j.pa as Vector3)
		j.prev = wp
		var g := float(j.gain)
		var tgt := Vector2.ZERO
		var hz := 2.0
		var zeta := 0.3
		var lim := Vector4(-0.2, 0.2, -0.2, 0.2)
		match String(j.kind):
			"hat":
				var av := inv_b * hat_avoid   # jemand ist nah am Kopf: Krempe hebt sich auf seiner Seite (Hut kippt weg)
				tgt = Vector2(-a_loc.z * 0.012 - av.z * 0.45, a_loc.x * 0.012 + av.x * 0.45) * g
				hz = 2.6
				zeta = 0.22
				var extra := 0.3 * minf(av.length(), 1.0)
				lim = Vector4(-0.16 * g - extra, 0.16 * g + extra, -0.16 * g - extra, 0.16 * g + extra)
			"cape":
				tgt = Vector2((minf(maxf(_rv.z, 0.0) * 0.2, 0.8) + a_loc.z * 0.02 - cp * 0.85) * g, -a_loc.x * 0.015 * g)
				hz = 1.5
				zeta = 0.32
				lim = Vector4(-0.05, 0.95, -0.3, 0.3)
			_:
				tgt = Vector2(a_loc.z * 0.014, -a_loc.x * 0.01) * g
				lim = Vector4(-0.25, 0.25, -0.2, 0.2)
		var ang: Vector2 = j.ang
		var vel: Vector2 = j.vel
		var px := spring(ang.x, vel.x, tgt.x, hz / sqrt(mass), zeta, dt)
		var py := spring(ang.y, vel.y, tgt.y, hz / sqrt(mass), zeta, dt)
		var cx := clampf(px.x, lim.x, lim.y)
		var cy := clampf(py.x, lim.z, lim.w)
		j.ang = Vector2(cx, cy)
		j.vel = Vector2(px.y if is_equal_approx(cx, px.x) else 0.0, py.y if is_equal_approx(cy, py.x) else 0.0)
		sk.set_bone_global_pose(int(j.bone), Transform3D(base.basis * Basis.from_euler(Vector3(cx, 0.0, cy)), base.origin))


## Größter Hut-Radius (Welt, waagerecht) – für den Abstand der Krempe zu anderen Köpfen; 0 = kein Hut.
func hat_radius() -> float:
	var r := 0.0
	var sk := get_skeleton()
	for j: Dictionary in _jig:
		if String(j.kind) == "hat" and float(j.gain) > 0.5:
			r = maxf(r, float(j.get("rad", 0.0)))
	return r * (sk.global_basis.get_scale().x if sk else 1.0)


## Zubehör-Zustand für Tests: [[Name, Art, Winkel]].
func jiggle_state() -> Array:
	var out: Array = []
	for j: Dictionary in _jig:
		out.append([String(j.name), String(j.kind), j.ang])
	return out


## Reach-Assist: liegt das Ziel außerhalb der Armreichweite, dreht sich die Brust um ihren Ursprung so weit
## (höchstens cfg.reach_lean), dass die Schulter das Ziel erreicht – wie ein Mensch, der sich zum Griff lehnt.
func _lean_to(sk: Skeleton3D, sd: String, tg: Vector3, w: float, to_wrist: bool) -> void:
	var ic: int = _b.get("chest", -1)
	var i0: int = _b.get("arm0." + sd, -1)
	var i1: int = _b.get("arm1." + sd, -1)
	var i2: int = _b.get(("wrist." if to_wrist else "arm2.") + sd, -1)
	if ic < 0 or i0 < 0 or i1 < 0 or i2 < 0:
		return
	var s := sk.get_bone_global_pose(i0).origin
	var r := (s.distance_to(sk.get_bone_global_pose(i1).origin) + sk.get_bone_global_pose(i1).origin.distance_to(sk.get_bone_global_pose(i2).origin)) * 0.96
	if s.distance_to(tg) <= r:
		return
	var c := sk.get_bone_global_pose(ic)
	var to_s := s - c.origin
	var to_t := tg - c.origin
	var a := to_s.length()
	var b := to_t.length()
	var axis := to_s.cross(to_t)
	if a < 0.001 or b < 0.001 or axis.length() < 0.000001:
		return
	var need := to_s.angle_to(to_t) - acos(clampf((a * a + b * b - r * r) / (2.0 * a * b), -1.0, 1.0))
	need = clampf(need, 0.0, cfg.reach_lean) * clampf(w, 0.0, 1.0)
	if need > 0.0005:
		c.basis = Basis(axis.normalized(), need) * c.basis
		sk.set_bone_global_pose(ic, c)


## Reichweite Schulter → Handgelenk (Welt) – nach ihr richten sich Griff- und Kontaktabstände.
func reach_length() -> float:
	var sk := get_skeleton()
	return _reach_len * (sk.global_transform.basis.get_scale().x if sk else 1.0)


## Länge Handgelenk → Hand (Welt): um so viel liegt die Hand bei ausgerichteter Handfläche vor dem Handgelenk.
func wrist_offset(sd := "r") -> float:
	var sk := get_skeleton()
	return (_hand_off[sd] as Vector3).length() * (sk.global_transform.basis.get_scale().x if sk else 1.0) if _hand_off.has(sd) else 0.0


## Ziel-Basis des Handgelenks (Skelett-Raum) für Finger- und Handflächen-Richtung (Welt); Basis() = nicht möglich.
func _hand_basis_for(sk: Skeleton3D, sd: String, finger: Vector3, palm: Vector3) -> Basis:
	if not _hand_rest.has(sd) or finger.length() < 0.01:
		return Basis()
	var inv := sk.global_transform.basis.inverse()
	var fd := (inv * finger).normalized()
	var pd := inv * palm
	pd = (pd - fd * pd.dot(fd))
	if pd.length() < 0.01:
		return Basis()
	pd = pd.normalized()
	var rest: Array = _hand_rest[sd]
	var fr: Vector3 = rest[1]
	var pr: Vector3 = rest[2]
	return (Basis(fd, pd, fd.cross(pd)) * Basis(fr, pr, fr.cross(pr)).inverse()) * (rest[0] as Basis)


## Armlänge (Schulter bis Hand, Welt) – für Interaktionsabstände.
func arm_length() -> float:
	var sk := get_skeleton()
	return _arm_len * (sk.global_transform.basis.get_scale().x if sk else 1.0)


## Handgelenk ausrichten: Ziel-Basis (Skelett-Raum, aus _hand_basis_for, geglättet), mit Gewicht w eingeblendet.
func _set_hand_basis(sk: Skeleton3D, sd: String, want: Basis, w: float) -> void:
	var wi: int = _b["wrist." + sd]
	var g := sk.get_bone_global_pose(wi)
	var sc := g.basis.get_scale()
	var q := g.basis.orthonormalized().get_rotation_quaternion().slerp(want.orthonormalized().get_rotation_quaternion(), clampf(w, 0.0, 1.0))
	g.basis = Basis(q).scaled(sc)
	sk.set_bone_global_pose(wi, g)


## Einteilige Gliedmaße auf ein Ziel richten (Spitze zeigt zum Ziel).
func _aim(sk: Skeleton3D, bone: int, tg: Vector3, w: float) -> void:
	if not _aim_tip.has(bone):
		return
	var g := sk.get_bone_global_pose(bone)
	var cur := g.basis * (_aim_tip[bone] as Vector3)
	var want := tg - g.origin
	if cur.length() < 0.001 or want.length() < 0.001:
		return
	var q := Quaternion(cur.normalized(), want.normalized())
	g.basis = Basis(Quaternion.IDENTITY.slerp(q, w)) * g.basis
	sk.set_bone_global_pose(bone, g)


## Bodenhöhe unter einem Weltpunkt: Callable, sonst Raycast (Kollisionsmaske), sonst Höhe der Figur.
func _ground_y(p: Vector3, fallback: float) -> float:
	if ground.is_valid():
		return float(ground.call(p))
	if cfg.ground_mask != 0 and is_inside_tree():
		var space := get_viewport().world_3d.direct_space_state if get_viewport() else null
		if space:
			var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.6, p + Vector3.DOWN * 0.9, cfg.ground_mask)
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				return (hit.position as Vector3).y
	return fallback


## Füße: Bodenhöhe anpassen (Becken gleicht aus) und den Standfuß in der Standphase in der Welt verankern.
## Standphase = der Fuß ist im Clip auf seiner tiefsten Höhe. Gelöst wird beim Anheben, wenn sich das Bein zu weit
## spannen müsste (dann ein kleiner Nachstell-Schritt), beim Teleport oder sobald die Figur nicht mehr am Boden ist.
func _feet(sk: Skeleton3D) -> void:
	var gx := sk.global_transform
	var base_y := sk.global_position.y
	var scl := gx.basis.get_scale().y
	var anim := {}
	var want := {"l": 0.0, "r": 0.0}
	var f := 1.0 - exp(-dt / 0.07)
	for sd in ["l", "r"]:
		var fp := sk.get_bone_global_pose(int(_b["leg2." + sd]))
		anim[sd] = fp.origin
		var ft: Dictionary = _foot[sd]
		ft.sole = minf(float(ft.sole) + dt * 0.02 * _leg_len, fp.origin.y)   # tiefste Höhe im Clip (driftet langsam nach)
		var wp := gx * fp.origin
		var stance := fp.origin.y - float(ft.sole) < 0.05 * _leg_len and grounded
		var g := _ground_y(wp, base_y)
		want[sd] = clampf(g - base_y, -cfg.foot_ik_max, cfg.foot_ik_max)
		if cfg.foot_lock:
			if stance and not bool(ft.on) and float(ft.w) < 0.05:
				ft.on = true
				ft.pos = wp
			elif bool(ft.on):
				var drift := Vector2(wp.x - (ft.pos as Vector3).x, wp.z - (ft.pos as Vector3).z).length()
				if not stance or drift > 0.42 * _leg_len * scl:
					ft.on = false
					ft.step = 1.0 if stance else 0.0   # Bein spannt zu sehr: kleiner Nachstell-Schritt
			ft.w = move_toward(float(ft.w), 1.0 if bool(ft.on) else 0.0, dt / (0.05 if bool(ft.on) else 0.12))
			ft.step = move_toward(float(ft.step), 0.0, dt / 0.12)
	for sd in ["l", "r"]:
		_foot_dy[sd] = lerpf(_foot_dy[sd], want[sd], f)
	_pelvis = lerpf(_pelvis, minf(minf(float(_foot_dy.l), float(_foot_dy.r)), 0.0), f)
	var pel_y := (_pelvis - clampf(_drop, -0.02, 0.4 * _leg_len * scl)) / scl
	var pel_x := _ws * 0.08 * _leg_len
	if (absf(pel_y) > 0.0005 or absf(pel_x) > 0.0005) and int(_b.get("hips", -1)) >= 0:
		var hp := sk.get_bone_global_pose(int(_b.hips))
		hp.origin += Vector3(pel_x, pel_y, 0.0) * foot_w
		hp.basis = Basis(Vector3.FORWARD, -_ws * 0.06 * foot_w) * hp.basis   # Hüfte sinkt auf der Spielbein-Seite
		sk.set_bone_global_pose(int(_b.hips), hp)
	var inv := gx.affine_inverse()
	for sd in ["l", "r"]:
		var ft2: Dictionary = _foot[sd]
		var tg: Vector3 = anim[sd]
		var lw := float(ft2.w)
		if lw > 0.001:
			var lp: Vector3 = inv * (ft2.pos as Vector3)
			tg = Vector3(lerpf(tg.x, lp.x, lw), tg.y, lerpf(tg.z, lp.z, lw))
		tg.y += float(_foot_dy[sd]) / scl + sin(clampf(float(ft2.step), 0.0, 1.0) * PI) * 0.07 * _leg_len
		if (tg - (anim[sd] as Vector3)).length() < 0.0005 and absf(pel_y) < 0.0005 and absf(pel_x) < 0.0005:
			continue
		_ik(sk, "leg0." + sd, "leg1." + sd, "leg2." + sd, tg, Vector3(0.1 if sd == "l" else -0.1, 0.0, 1.0), foot_w, 0.995)


## Zwei-Knochen-IK im Skelett-Raum. pole = Richtung, in die das Mittelgelenk knickt; reach < 1 hält das Gelenk
## leicht gebeugt (keine durchgestreckten, umschnappenden Gelenke).
func _ik(sk: Skeleton3D, b0: String, b1: String, b2: String, tg: Vector3, pole: Vector3, w: float, reach: float) -> void:
	var iu: int = _b.get(b0, -1)
	var il: int = _b.get(b1, -1)
	var ih: int = _b.get(b2, -1)
	if iu < 0 or il < 0 or ih < 0:
		return
	var a := sk.get_bone_global_pose(iu)
	var pb := sk.get_bone_global_pose(il).origin
	var pc := sk.get_bone_global_pose(ih).origin
	var l1 := a.origin.distance_to(pb)
	var l2 := pb.distance_to(pc)
	var to := tg - a.origin
	if to.length() < 0.001 or l1 < 0.001 or l2 < 0.001:
		return
	var d := clampf(to.length(), absf(l1 - l2) + 0.02, (l1 + l2) * reach)
	var dir := to.normalized()
	var perp := pole - dir * pole.dot(dir)
	perp = perp.normalized() if perp.length() > 0.01 else Vector3.DOWN
	var x := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
	var nb := a.origin + dir * x + perp * h
	var nc := a.origin + dir * d
	var q1 := Quaternion((pb - a.origin).normalized(), (nb - a.origin).normalized())
	a.basis = Basis(Quaternion.IDENTITY.slerp(q1, w)) * a.basis
	sk.set_bone_global_pose(iu, a)
	var b2x := sk.get_bone_global_pose(il)
	var c2 := sk.get_bone_global_pose(ih).origin
	var q2 := Quaternion((c2 - b2x.origin).normalized(), (nc - b2x.origin).normalized())
	b2x.basis = Basis(Quaternion.IDENTITY.slerp(q2, w)) * b2x.basis
	sk.set_bone_global_pose(il, b2x)
