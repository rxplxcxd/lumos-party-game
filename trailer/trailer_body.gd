extends SkeletonModifier3D
## Körper-Ebene für die Trailer-Darsteller (nur Trailer): liegt über der Animation und dem Slapstick-Modifier
## des Spiels und sorgt dafür, dass Berührungen wirklich stattfinden.
##
##  * Arm-IK (Schulter–Ellbogen–Hand): eine Hand erreicht einen Punkt im Raum – die Schulter des Freundes, die Hand
##    beim Abklatschen, den Keks. Gewicht 0..1 blendet weich zwischen Animation und Ziel.
##  * Lachen als Körperbewegung: Brustkorb wippt, Schultern heben und senken sich, der Kopf geht leicht in den
##    Nacken und nickt im Takt. Dieselbe Phase steuert den Mund (trailer_face.gd).
##  * Atmung (Brustkorb, Schultern) – ruhig im Stand, pumpend nach dem Rennen.
##  * Zusätzliche Kopf- und Brust-Neigung für kleine Gesten (schief gelegter Kopf, Nicken, Anlehnen).

var laugh := 0.0            # 0..1
var laugh_phase := 0.0
var breath := 0.35          # Stärke der Atmung (1 = außer Atem)
var breath_rate := 1.4      # Atemzüge pro Sekunde · 2π
var head_add := Vector3.ZERO    # (nicken, drehen, schief legen) in rad – wird geglättet
var chest_add := Vector3.ZERO
var hand_w := {"l": 0.0, "r": 0.0}
var hand_t := {"l": Vector3.ZERO, "r": Vector3.ZERO}   # Ziel in Weltkoordinaten

var _b := {}
var _head := Vector3.ZERO
var _chest := Vector3.ZERO
var dt := 1.0 / 60.0         # Bildschritt der Regie (Filmzeit – nicht die Echtzeit: gleich bei 30 und 60 fps)
var _t := 0.0


func bind(skel: Skeleton3D) -> void:
	for n in ["hips", "spine", "chest", "head", "upperarm.l", "upperarm.r", "lowerarm.l", "lowerarm.r"]:
		_b[n] = skel.find_bone(n)
	for sd in ["l", "r"]:
		for n in ["hand." + sd, "wrist." + sd, "handslot." + sd]:
			if skel.find_bone(n) >= 0:
				_b["hand." + sd] = skel.find_bone(n)
				break


## Weltposition eines Knochens nach allen Modifikatoren (Hand, Schulter, Kopf …) – Stand des letzten Bildes.
func bone_pos(name: String) -> Vector3:
	var sk := get_skeleton()
	var i: int = _b.get(name, -1)
	if sk == null or i < 0:
		return global_position
	return sk.global_transform * sk.get_bone_global_pose(i).origin


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
	# Atmung
	var br := sin(_t * breath_rate * TAU / 2.6) * breath
	var chest_pitch := _chest.x - br * 0.03
	var shoulder := br * 0.035
	var head_pitch := _head.x + br * 0.012
	# Lachen: Brust wippt, Schultern zucken, Kopf leicht im Nacken und nickt mit
	if laugh > 0.001:
		var s := sin(laugh_phase)
		chest_pitch += (s * 0.07 - 0.09) * laugh
		shoulder += (0.1 + 0.09 * s) * laugh
		head_pitch += (-0.2 + 0.07 * sin(laugh_phase + 0.6)) * laugh
	_rot(sk, "chest", Vector3.RIGHT, chest_pitch)
	_rot(sk, "chest", Vector3.UP, _chest.y)
	_rot(sk, "chest", Vector3.FORWARD, _chest.z)
	_rot(sk, "upperarm.l", Vector3.FORWARD, -shoulder)
	_rot(sk, "upperarm.r", Vector3.FORWARD, shoulder)
	_rot(sk, "head", Vector3.RIGHT, head_pitch)
	_rot(sk, "head", Vector3.UP, _head.y)
	_rot(sk, "head", Vector3.FORWARD, _head.z)
	for sd in ["l", "r"]:
		var w: float = hand_w[sd]
		if w > 0.001:
			_ik(sk, sd, hand_t[sd], w)


## Zwei-Knochen-IK: Ellbogen knickt nach unten-außen-hinten, die Hand landet auf dem Ziel.
func _ik(sk: Skeleton3D, sd: String, target: Vector3, w: float) -> void:
	var iu: int = _b.get("upperarm." + sd, -1)
	var il: int = _b.get("lowerarm." + sd, -1)
	var ih: int = _b.get("hand." + sd, -1)
	if iu < 0 or il < 0 or ih < 0:
		return
	var tg := sk.global_transform.affine_inverse() * target
	var a := sk.get_bone_global_pose(iu)
	var pb := sk.get_bone_global_pose(il).origin
	var pc := sk.get_bone_global_pose(ih).origin
	var l1 := a.origin.distance_to(pb)
	var l2 := pb.distance_to(pc)
	var to := tg - a.origin
	var d := clampf(to.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.004)
	var dir := to.normalized()
	var pole := Vector3(0.45 if sd == "l" else -0.45, -1.0, -0.55)
	var perp := pole - dir * pole.dot(dir)
	perp = perp.normalized() if perp.length() > 0.01 else Vector3.DOWN
	var x := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
	var nb := a.origin + dir * x + perp * h
	var nc := a.origin + dir * d
	var q1 := Quaternion((pb - a.origin).normalized(), (nb - a.origin).normalized())
	a.basis = Basis(Quaternion.IDENTITY.slerp(q1, w)) * a.basis
	sk.set_bone_global_pose(iu, a)
	var b2 := sk.get_bone_global_pose(il)
	var c2 := sk.get_bone_global_pose(ih).origin
	var q2 := Quaternion((c2 - b2.origin).normalized(), (nc - b2.origin).normalized())
	b2.basis = Basis(Quaternion.IDENTITY.slerp(q2, w)) * b2.basis
	sk.set_bone_global_pose(il, b2)
