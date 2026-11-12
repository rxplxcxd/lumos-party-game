class_name SlapstickModifier
extends SkeletonModifier3D
## Prozeduraler Bone-Rig-Modifier: legt additive Bewegungen über die abgespielte Animation.
##
## * look: Kopf (und etwas Brust) dreht sich zu einem Weltpunkt (Blickkontakt mit der Kamera)
## * dizzy: kreisendes Kopf-/Oberkörper-Torkeln
## * scared/tremble: hochfrequentes Zittern, Kopf eingezogen
## * frustrated: Kopfschütteln + zusammengesackte Brust
## * triumph: Brust raus, Kinn hoch
## * laugh: rhythmisches Vor-/Zurückwippen
## * sad: hängender Kopf
## * lean: seitliches Neigen in Kurven (Karts, Sprint)
## * steer: Arme nach vorn ans Lenkrad (Kart-Sitzpose), Lenkwinkel dreht die Arme mit
## * jolt: Oberkörper-Ruck (x = nach hinten/vorn, y = seitlich) – vom Kart als gedämpfte Feder gesetzt
## * arm_throw: Wurfarm (rechts): −1 = weit ausgeholt, +1 = durchgeschwungen, 0 = am Lenkrad
##
## Skelett-Raum der KayKit-Rigs: Charakter blickt nach +Z, oben = +Y.

var weights := {"dizzy": 0.0, "scared": 0.0, "frustrated": 0.0, "triumph": 0.0, "laugh": 0.0, "sad": 0.0, "tremble": 0.0}
var look_target := Vector3.ZERO
var look_weight := 0.0
var lean := 0.0
var steer_weight := 0.0
var steer := 0.0
var jolt := Vector2.ZERO
var arm_throw := 0.0

var _bones := {}
var _t := 0.0
var _last_ms := 0


func _ready() -> void:
	_last_ms = Time.get_ticks_msec()


func bind(skel: Skeleton3D) -> void:
	_bones.clear()
	for n in ["hips", "spine", "chest", "head", "upperarm.l", "upperarm.r", "lowerarm.l", "lowerarm.r"]:
		var idx := skel.find_bone(n)
		if idx >= 0:
			_bones[n] = idx


func pulse(mode: String, duration := 1.0, strength := 1.0) -> void:
	if not weights.has(mode):
		return
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: weights[mode] = v, weights[mode], strength, 0.15)
	tw.tween_interval(maxf(duration - 0.4, 0.05))
	tw.tween_method(func(v: float) -> void: weights[mode] = v, strength, 0.0, 0.25)


func clear_all() -> void:
	for k in weights.keys():
		weights[k] = 0.0
	look_weight = 0.0
	lean = 0.0


func _rot(skel: Skeleton3D, bone: String, axis: Vector3, angle: float) -> void:
	if absf(angle) < 0.0001 or not _bones.has(bone):
		return
	var idx: int = _bones[bone]
	var g := skel.get_bone_global_pose(idx)
	g.basis = Basis(axis.normalized(), angle) * g.basis
	skel.set_bone_global_pose(idx, g)


func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null or _bones.is_empty():
		return
	var now := Time.get_ticks_msec()
	var dt := clampf((now - _last_ms) / 1000.0, 0.0, 0.1) * Engine.time_scale
	_last_ms = now
	_t += dt
	var w: Dictionary = weights

	# --- Rumpf ---
	var hips_roll := lean * 0.18
	var chest_pitch := jolt.x * 0.22
	var chest_roll := lean * 0.22 + jolt.y * 0.16
	var head_pitch := 0.0
	var head_yaw := 0.0
	var head_roll := 0.0

	if w.dizzy > 0.0:
		chest_roll += sin(_t * 5.0) * 0.18 * w.dizzy
		chest_pitch += cos(_t * 5.0) * 0.12 * w.dizzy
		head_roll += sin(_t * 5.0 + 0.8) * 0.35 * w.dizzy
		head_pitch += cos(_t * 5.0 + 0.8) * 0.25 * w.dizzy
	if w.scared > 0.0:
		head_pitch += 0.25 * w.scared
		chest_pitch += -0.15 * w.scared
		hips_roll += sin(_t * 55.0) * 0.03 * w.scared
		head_yaw += sin(_t * 47.0) * 0.06 * w.scared
	if w.tremble > 0.0:
		chest_roll += sin(_t * 61.0) * 0.05 * w.tremble
		head_roll += sin(_t * 53.0) * 0.08 * w.tremble
	if w.frustrated > 0.0:
		head_yaw += sin(_t * 14.0) * 0.45 * w.frustrated
		chest_pitch += 0.3 * w.frustrated
		head_pitch += 0.2 * w.frustrated
	if w.triumph > 0.0:
		chest_pitch += -0.28 * w.triumph
		head_pitch += -0.3 * w.triumph
	if w.laugh > 0.0:
		chest_pitch += (sin(_t * 18.0) * 0.12 - 0.1) * w.laugh
		head_pitch += (sin(_t * 18.0 + 0.5) * 0.18 - 0.15) * w.laugh
	if w.sad > 0.0:
		head_pitch += 0.5 * w.sad
		chest_pitch += 0.25 * w.sad

	_rot(skel, "hips", Vector3.FORWARD, hips_roll)
	_rot(skel, "chest", Vector3.RIGHT, chest_pitch)
	_rot(skel, "chest", Vector3.FORWARD, chest_roll)

	# --- Kopf: Blick zu einem Weltpunkt ---
	if look_weight > 0.001 and _bones.has("head"):
		var head_g := skel.global_transform * skel.get_bone_global_pose(_bones.head)
		var to_target := (look_target - head_g.origin)
		if to_target.length() > 0.1:
			var local_dir := skel.global_transform.basis.inverse() * to_target.normalized()
			var yaw := clampf(atan2(local_dir.x, local_dir.z), -1.1, 1.1)
			var pitch := clampf(-asin(clampf(local_dir.y, -1, 1)), -0.6, 0.6)
			head_yaw += yaw * look_weight
			head_pitch += pitch * look_weight
			_rot(skel, "chest", Vector3.UP, yaw * 0.25 * look_weight)
	_rot(skel, "head", Vector3.UP, head_yaw)
	_rot(skel, "head", Vector3.RIGHT, head_pitch)
	_rot(skel, "head", Vector3.FORWARD, head_roll)

	# --- Arme: Lenkrad-Pose ---
	if steer_weight > 0.001:
		_rot(skel, "upperarm.l", Vector3.UP, -1.25 * steer_weight)
		_rot(skel, "upperarm.r", Vector3.UP, 1.25 * steer_weight)
		_rot(skel, "upperarm.l", Vector3.FORWARD, -0.55 * steer_weight + steer * 0.35)
		_rot(skel, "upperarm.r", Vector3.FORWARD, 0.55 * steer_weight + steer * 0.35)
	if absf(arm_throw) > 0.001:
		# Ausholen: Arm nach hinten-oben, Wurf: nach vorn-oben durchziehen, Unterarm schnappt nach
		var back := clampf(-arm_throw, 0.0, 1.0)
		var fwd := clampf(arm_throw, 0.0, 1.0)
		_rot(skel, "upperarm.r", Vector3.RIGHT, -1.5 * back + 1.6 * fwd)
		_rot(skel, "upperarm.r", Vector3.FORWARD, -0.9 * back - 0.5 * fwd)
		_rot(skel, "lowerarm.r", Vector3.RIGHT, -0.9 * back + 0.3 * fwd)
		_rot(skel, "chest", Vector3.UP, -0.35 * back + 0.3 * fwd)
	if w.scared > 0.3:
		_rot(skel, "upperarm.l", Vector3.FORWARD, 0.9 * w.scared + sin(_t * 40.0) * 0.1)
		_rot(skel, "upperarm.r", Vector3.FORWARD, -0.9 * w.scared - sin(_t * 43.0) * 0.1)
	if w.triumph > 0.3:
		_rot(skel, "upperarm.l", Vector3.FORWARD, 1.1 * w.triumph)
		_rot(skel, "upperarm.r", Vector3.FORWARD, -1.1 * w.triumph)
