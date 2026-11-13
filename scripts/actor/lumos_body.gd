class_name LumosBody
extends SkeletonModifier3D
## Körper-Ebene des Character-Frameworks: prozedurale Bewegung und IK über der abgespielten Animation
## (läuft nach dem SlapstickModifier des Spiels). Alles additiv, gewichtet und geglättet – nichts springt.
##
##  * Arm-IK je Hand (Zielpunkt in Weltkoordinaten, Gewicht 0..1, Ziel wird geglättet → kein Zittern)
##  * Fuß-IK: Füße folgen der Bodenhöhe (ground: Callable(Vector3) → float), das Becken senkt sich mit
##  * Atmung, Gewichtsverlagerung im Stand, Lachen (Brust, Schultern, Kopf), Zusatz-Neigung von Kopf und Brust
##  * Impuls-Feder: Stöße, Treffer, Beschleunigen/Bremsen/Kurven lassen Oberkörper und Kopf nachschwingen
## Zeitbasis ist dt (vom LumosActor gesetzt) – unabhängig von der Bildrate.

var cfg := LumosActorConfig.new()
var dt := 1.0 / 60.0
var laugh := 0.0
var laugh_phase := 0.0
var breath := 0.35
var breath_rate := 1.4
var head_add := Vector3.ZERO        # (nicken, drehen, schief) rad
var chest_add := Vector3.ZERO
var lean := Vector2.ZERO            # (vor/zurück, seitlich) rad – z. B. aus Beschleunigung und Kurve
var hand_w := {"l": 0.0, "r": 0.0}
var hand_t := {"l": Vector3.ZERO, "r": Vector3.ZERO}
var ground := Callable()            # leer = ebener Boden auf Höhe der Figur
var foot_w := 1.0                   # Fuß-IK ein-/ausblenden (z. B. 0 im Sprung)

var _b := {}
var _head := Vector3.ZERO
var _chest := Vector3.ZERO
var _lean := Vector2.ZERO
var _imp := Vector3.ZERO            # Feder-Auslenkung (x seitlich, y hoch, z vor) im Figurenraum
var _imp_v := Vector3.ZERO
var _hand_s := {"l": Vector3.ZERO, "r": Vector3.ZERO}
var _hand_on := {"l": false, "r": false}
var _foot_dy := {"l": 0.0, "r": 0.0}
var _pelvis := 0.0
var _t := 0.0
var _pos := {}                      # Gelenk → Weltposition nach der Modifikation


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
			_b["arm%d.%s" % [k, sd]] = skel.find_bone(String(a[k])) if a.size() == 3 else -1
			_b["leg%d.%s" % [k, sd]] = skel.find_bone(String(l[k])) if l.size() == 3 else -1
		if int(_b["arm2." + sd]) < 0:   # Rigs ohne Hand-Knochen: Handgelenk/Slot
			for alt in ["wrist." + sd, "handslot." + sd]:
				if skel.find_bone(alt) >= 0:
					_b["arm2." + sd] = skel.find_bone(alt)
					break
	_t = randf() * 10.0
	return int(_b.chest) >= 0 and int(_b.head) >= 0


func has_arms() -> bool:
	return int(_b.get("arm0.l", -1)) >= 0 and int(_b.get("arm2.l", -1)) >= 0


func has_legs() -> bool:
	return int(_b.get("leg0.l", -1)) >= 0 and int(_b.get("leg2.l", -1)) >= 0


## Weltposition eines Gelenks NACH allen Modifikatoren (Stand des letzten Bildes):
## "hand.l/r", "shoulder.l/r", "elbow.l/r", "thigh.l/r", "knee.l/r", "foot.l/r", "head", "chest", "hips".
## (Godot setzt die Knochen nach dem Skinning zurück – von außen abgefragte Posen wären die unveränderten.
## Deshalb merkt sich die Ebene die Positionen am Ende ihrer Berechnung.)
func joint_pos(name: String) -> Vector3:
	var key := name
	var parts := name.split(".")
	if parts.size() == 2:
		key = String({"shoulder": "arm0.", "elbow": "arm1.", "hand": "arm2.", "thigh": "leg0.", "knee": "leg1.", "foot": "leg2."}.get(parts[0], parts[0] + ".")) + parts[1]
	if _pos.has(key):
		return _pos[key]
	var sk := get_skeleton()
	var i: int = _b.get(key, -1)
	if sk == null or i < 0:
		return sk.global_position if sk else Vector3.ZERO
	return sk.global_transform * sk.get_bone_global_pose(i).origin


## Stoß in Weltrichtung (m/s-artig): Oberkörper und Kopf schwingen gedämpft nach.
func push(world_impulse: Vector3) -> void:
	var sk := get_skeleton()
	if sk:
		_imp_v += sk.global_transform.basis.inverse() * world_impulse


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
	# Impuls-Feder (halb-implizit, stabil auch bei großen Schritten)
	_imp_v += (-_imp * cfg.impulse_stiffness - _imp_v * cfg.impulse_damping) * dt
	_imp += _imp_v * dt
	_imp = _imp.limit_length(1.2)
	var br := sin(_t * breath_rate * TAU / 2.6) * breath
	var sway := sin(_t * 0.55) * 0.035 * cfg.idle_sway * clampf(1.0 - _lean.length() * 6.0, 0.0, 1.0)
	var chest_pitch := _chest.x - br * 0.03 + _lean.x + _imp.z * 0.45
	var chest_roll := _chest.z + _lean.y + _imp.x * 0.45 + sway * 0.5
	var shoulder := br * 0.035
	var head_pitch := _head.x + br * 0.012 - _imp.z * 0.3 - _lean.x * 0.4
	var head_roll := _head.z - _imp.x * 0.3 - sway * 0.4
	if laugh > 0.001:
		var s := sin(laugh_phase)
		chest_pitch += (s * 0.07 - 0.09) * laugh
		shoulder += (0.1 + 0.09 * s) * laugh
		head_pitch += (-0.2 + 0.07 * sin(laugh_phase + 0.6)) * laugh
	_rot(sk, "hips", Vector3.FORWARD, sway)
	_rot(sk, "chest", Vector3.RIGHT, chest_pitch)
	_rot(sk, "chest", Vector3.UP, _chest.y)
	_rot(sk, "chest", Vector3.FORWARD, chest_roll)
	_rot(sk, "arm0.l", Vector3.FORWARD, -shoulder)
	_rot(sk, "arm0.r", Vector3.FORWARD, shoulder)
	_rot(sk, "head", Vector3.RIGHT, head_pitch)
	_rot(sk, "head", Vector3.UP, _head.y)
	_rot(sk, "head", Vector3.FORWARD, head_roll)
	if cfg.foot_ik and foot_w > 0.001 and has_legs():
		_feet(sk)
	for sd in ["l", "r"]:
		var w: float = hand_w[sd]
		if w > 0.001:
			# Ziel glätten (kein Zittern); beim Einschalten direkt übernehmen
			_hand_s[sd] = hand_t[sd] if not _hand_on[sd] else (_hand_s[sd] as Vector3).lerp(hand_t[sd], 1.0 - exp(-dt / 0.035))
			_hand_on[sd] = true
			var pole := Vector3(0.45 if sd == "l" else -0.45, -1.0, -0.55)
			_ik(sk, "arm0." + sd, "arm1." + sd, "arm2." + sd, sk.global_transform.affine_inverse() * (_hand_s[sd] as Vector3), pole, w, 0.985)
		else:
			_hand_on[sd] = false
	var gx := sk.global_transform
	for k in _b:
		if int(_b[k]) >= 0:
			_pos[k] = gx * sk.get_bone_global_pose(int(_b[k])).origin


## Fuß-IK: Bodenhöhe unter jedem Fuß abfragen, Becken absenken, Füße auf den Boden setzen (Knie nach vorn).
func _feet(sk: Skeleton3D) -> void:
	var inv := sk.global_transform.affine_inverse()
	var base_y := sk.global_position.y
	var want := {"l": 0.0, "r": 0.0}
	var anim := {}
	for sd in ["l", "r"]:
		var fp := sk.get_bone_global_pose(int(_b["leg2." + sd]))
		anim[sd] = fp.origin
		var wp := sk.global_transform * fp.origin
		var g: float = float(ground.call(wp)) if ground.is_valid() else base_y
		want[sd] = clampf(g - base_y, -cfg.foot_ik_max, cfg.foot_ik_max)
	var f := 1.0 - exp(-dt / 0.07)
	for sd in ["l", "r"]:
		_foot_dy[sd] = lerpf(_foot_dy[sd], want[sd], f)
	_pelvis = lerpf(_pelvis, minf(minf(float(_foot_dy.l), float(_foot_dy.r)), 0.0), f)
	var scl := sk.global_transform.basis.get_scale().y
	if absf(_pelvis) > 0.0005 and int(_b.hips) >= 0:
		var hp := sk.get_bone_global_pose(int(_b.hips))
		hp.origin.y += _pelvis / scl * foot_w
		sk.set_bone_global_pose(int(_b.hips), hp)
	for sd in ["l", "r"]:
		var dy: float = _foot_dy[sd]
		if absf(dy - _pelvis) < 0.0005 and absf(_pelvis) < 0.0005:
			continue
		var tg: Vector3 = anim[sd]
		tg.y += dy / scl   # die animierte Fußhöhe bleibt erhalten (Schritt hebt den Fuß), nur der Boden verschiebt sie
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
