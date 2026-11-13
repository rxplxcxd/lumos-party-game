class_name LumosInteract
extends RefCounted
## Interaktionen des Character-Frameworks: Gegenstände greifen, halten, werfen, weitergeben, Bedienelemente mit
## beiden Händen fassen, und Zwei-Personen-Aktionen (High-Five, Umarmung, Schubser, Schulterklopfen).
## Jede Interaktion hat einen erkennbaren Anfang (Hinwenden, Ausholen), einen Kontakt (Hände an der Oberfläche,
## Handflächen richtig ausgerichtet, beide Körper nehmen das Gewicht auf) und ein Ende (Lösen, zurück in die Animation).
##
## Signale: grabbed(obj, hand) · released(obj, hand) · thrown(obj) · landed(obj, pos) · contact(kind, other)

signal grabbed(obj: Node3D, hand: String)
signal released(obj: Node3D, hand: String)
signal thrown(obj: Node3D)
signal landed(obj: Node3D, pos: Vector3)
signal contact(kind: String, other: LumosActor)

var actor: LumosActor
var held := {"l": null, "r": null}          # Hand → Node3D
var _flying: Array = []                     # [obj, start, ziel, höhe, t, dauer]
var _wheel: Node3D
var _wheel_r := 0.3
var _seq: Array[Tween] = []


func cancel_all() -> void:
	for tw in _seq:
		if tw and tw.is_valid():
			tw.kill()
	_seq.clear()


func _tween() -> Tween:
	var tw := actor.create_tween()
	_seq = _seq.filter(func(x: Tween) -> bool: return x != null and x.is_valid())
	_seq.append(tw)
	return tw


## Größe eines Gegenstands (halbe größte Ausdehnung seiner Meshes) – Hände greifen an die Oberfläche, nicht hinein.
static func radius_of(obj: Node3D) -> float:
	var r := 0.0
	for mi in Assets.find_meshes(obj):
		var m := mi as MeshInstance3D
		if m.mesh:
			var bb := m.get_aabb()
			r = maxf(r, maxf(bb.size.x, maxf(bb.size.y, bb.size.z)) * 0.5 * m.global_basis.get_scale().x)
	return r if r > 0.0 else 0.08


## Gegenstand greifen: Blick hin, vorbeugen, Hand an die Oberfläche (Handfläche zum Gegenstand) – danach liegt er
## in der Hand auf der Handfläche (held[hand]).
func grab(obj: Node3D, hand := "r", secs := 0.35) -> void:
	if obj == null or not is_instance_valid(obj):
		return
	var look_before: Variant = actor.look_target()
	var rad := radius_of(obj)
	actor.look_at_target(obj)
	# von oben zugreifen: Handfläche nach unten auf die Oberseite, Finger in Greifrichtung
	var fwd := func() -> Vector3:
		var d := obj.global_position - actor.rig.global_position if is_instance_valid(obj) else actor.forward()
		d.y = 0.0
		return d.normalized() if d.length() > 0.01 else actor.forward()
	actor.reach(hand, func() -> Vector3: return obj.global_position + Vector3.UP * rad if is_instance_valid(obj) else Vector3.INF, secs,
		func() -> Array: return [fwd.call(), Vector3.DOWN])
	if actor.body:
		actor.body.chest_add = Vector3(0.18, 0, 0)
	var tw := _tween()
	tw.tween_interval(secs)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(obj):
			actor.release(hand)
			return
		held[hand] = obj
		if actor.body:
			actor.body.chest_add = Vector3.ZERO
		actor.reach(hand, func() -> Vector3: return carry_point(hand), 0.3, func() -> Array: return [actor.forward(), Vector3.UP])
		actor.look_at_target(look_before)
		grabbed.emit(obj, hand))


## Tragepunkt der Hand vor dem Körper (Handfläche nach oben, der Gegenstand liegt darauf).
func carry_point(hand: String) -> Vector3:
	return actor.rel(-0.24 if hand == "l" else 0.24, 0.95, 0.32)


func drop(hand := "r") -> Node3D:
	var obj: Node3D = held[hand]
	held[hand] = null
	actor.release(hand)
	if obj:
		released.emit(obj, hand)
	return obj


## Werfen mit ganzer Körperbewegung: ausholen (Arm zurück, Oberkörper dreht mit) → durchziehen → loslassen →
## Nachschwung. Der Gegenstand fliegt im Bogen zum Ziel (landed-Signal); wer Physik will, hört auf thrown.
func throw_to(target: Vector3, hand := "r", arc := 1.2, flight := 0.6) -> void:
	var obj: Node3D = held[hand]
	if obj == null:
		return
	var side := -1.0 if hand == "l" else 1.0
	var look_before: Variant = actor.look_target()
	actor.look_at_target(target)
	actor.reach(hand, func() -> Vector3: return actor.rel(0.42 * side, 1.75, -0.38), 0.2, func() -> Array: return [Vector3.UP, actor.forward()])
	if actor.body:
		actor.body.chest_add = Vector3(-0.12, 0.45 * side, 0)
	actor.rig.anticipate(0.22, 0.08)
	var tw := _tween()
	tw.tween_interval(0.24)
	tw.tween_callback(func() -> void:
		actor.reach(hand, func() -> Vector3: return actor.rel(0.2 * side, 1.5, 0.75), 0.09, func() -> Array: return [actor.forward(), -Vector3.UP])
		if actor.body:
			actor.body.chest_add = Vector3(0.22, -0.35 * side, 0)
			actor.body.push(actor.forward() * 1.6))
	tw.tween_interval(0.1)
	tw.tween_callback(func() -> void:
		held[hand] = null
		if is_instance_valid(obj):
			_flying.append([obj, obj.global_position, target, arc, 0.0, flight])
			thrown.emit(obj)
			released.emit(obj, hand))
	tw.tween_interval(0.22)
	tw.tween_callback(func() -> void:
		actor.release(hand, 0.4)
		if actor.body:
			actor.body.chest_add = Vector3.ZERO
		actor.look_at_target(look_before))


## Weitergeben: beide Hände treffen sich (Handflächen nach oben), der Gegenstand wechselt die Hand.
func give(to: LumosActor, hand := "r", to_hand := "l") -> void:
	var obj: Node3D = held[hand]
	if obj == null or to == null:
		return
	var mid := func() -> Vector3:
		return (actor.body.joint_pos("shoulder." + hand) + to.body.joint_pos("shoulder." + to_hand)) * 0.5 + Vector3(0, -0.12, 0)
	actor.look_at_target(to)
	to.look_at_target(obj)
	actor.reach(hand, mid, 0.4, func() -> Array: return [actor.forward(), Vector3.UP])
	to.reach(to_hand, func() -> Vector3: return (mid.call() as Vector3) + Vector3(0, -0.06, 0), 0.45, func() -> Array: return [to.forward(), Vector3.UP])
	var tw := _tween()
	tw.tween_interval(0.5)
	tw.tween_callback(func() -> void:
		held[hand] = null
		to.interact.held[to_hand] = obj
		released.emit(obj, hand)
		to.interact.grabbed.emit(obj, to_hand)
		to.feel("smile", 0.3)
		actor.release(hand, 0.4)
		to.reach(to_hand, func() -> Vector3: return to.interact.carry_point(to_hand), 0.4, func() -> Array: return [to.forward(), Vector3.UP])
		to.look_at_target(actor)
		contact.emit("give", to))


## Beide Hände ans Lenkrad (10 und 2 Uhr): Griffpunkte auf dem Kranz drehen sich mit dem Rad, die Finger liegen
## entlang des Kranzes, die Handflächen zeigen nach vorn-innen auf das Rad.
func hold_wheel(wheel: Node3D, radius := 0.3, secs := 0.35) -> void:
	_wheel = wheel
	_wheel_r = radius
	for hand in ["l", "r"]:
		var sgn := -1.0 if hand == "l" else 1.0
		var grip := func() -> Vector3:
			if not is_instance_valid(_wheel):
				return Vector3.INF
			var x := _wheel.global_basis.x.normalized() * signf(_wheel.global_basis.x.dot(actor.right()))
			return _wheel.global_position + (x * sgn * 0.82 + _wheel.global_basis.y.normalized() * 0.55) * _wheel_r
		var ori := func() -> Array:
			if not is_instance_valid(_wheel):
				return []
			var radial: Vector3 = ((grip.call() as Vector3) - _wheel.global_position).normalized()
			var n := _wheel.global_basis.z.normalized()
			if n.dot(actor.forward()) < 0.0:
				n = -n
			var tangent := n.cross(radial).normalized()
			if tangent.y < 0.0:
				tangent = -tangent
			return [tangent, (n * 0.8 - radial * 0.6).normalized()]
		actor.reach(hand, grip, secs, ori)


func release_wheel() -> void:
	_wheel = null
	actor.release("l")
	actor.release("r")


## High-Five: zueinander drehen und so versetzt aufstellen, dass die rechten Schultern einander gegenüberstehen
## (die großen Köpfe bleiben seitlich versetzt), ausholen, die Handflächen treffen sich über Schulterhöhe (Finger
## oben), beide federn vom Schlag zurück; danach lachen beide (versetzt). Abstand aus der echten Armreichweite.
static func high_five(a: LumosActor, b: LumosActor) -> void:
	_face_each_other(a, b)
	if a.body == null or b.body == null or a.body.arm_mode() != "2bone" or b.body.arm_mode() != "2bone":
		_simple_contact(a, b, "high_five")
		return
	var d := b.rig.global_position - a.rig.global_position
	d.y = 0.0
	var dist := d.length()
	var n := d / maxf(dist, 0.01)
	var rt := n.cross(Vector3.UP).normalized()          # rechts von A
	var geo := func(me: LumosActor) -> Vector2:          # (seitlicher, vorderer) Versatz der rechten Schulter
		var o := me.body.rest_pos("shoulder.r") - me.rig.global_position
		return Vector2(o.dot(me.rig.global_basis.x.normalized()), o.dot(me.forward()))
	var ga: Vector2 = geo.call(a)
	var gb: Vector2 = geo.call(b)
	var x := (ga.x + gb.x) * 0.5
	var h := 0.32 * (a.body.reach_length() + b.body.reach_length()) * 0.5   # Treffpunkt über Schulterhöhe
	var gap := 0.025                                                         # Handflächen berühren sich
	var horiz := func(me: LumosActor) -> float:
		var r := me.body.reach_length() * 0.93
		var v := h - me.body.wrist_offset("r")
		return sqrt(maxf(r * r - v * v, 0.01))
	var want: float = ga.y + gb.y + float(horiz.call(a)) + float(horiz.call(b)) + gap * 2.0
	var mid0 := (a.rig.global_position + b.rig.global_position) * 0.5
	mid0.y = a.rig.global_position.y
	var pa1 := mid0 - n * want * 0.5 - rt * x
	var pb1 := Vector3(mid0.x, b.rig.global_position.y, mid0.z) + n * want * 0.5 + rt * x
	var meet := func() -> Vector3:
		var p := (a.body.joint_pos("shoulder.r") + b.body.joint_pos("shoulder.r")) * 0.5
		return p + Vector3.UP * h
	var ta := func() -> Vector3: return (meet.call() as Vector3) - n * gap
	var tb := func() -> Vector3: return (meet.call() as Vector3) + n * gap
	var ori_a := func() -> Array: return [Vector3.UP, n]
	var ori_b := func() -> Array: return [Vector3.UP, -n]
	a.feel("grin", 0.2)
	b.feel("grin", 0.2)
	a.rig.anticipate(0.22, 0.06)
	b.rig.anticipate(0.22, 0.06)
	var tw := a.interact._tween()
	tw.set_parallel(true)
	tw.tween_property(a.rig, "global_position", pa1, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(b.rig, "global_position", pb1, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void:
		for me: LumosActor in [a, b]:
			me.body.chest_add = Vector3(0.06, -0.12, 0)   # Schlagschulter etwas nach vorn
			me.body.head_add = Vector3(0, 0, -0.12)       # Kopf weicht dem Arm aus
		a.reach("r", ta, 0.22, ori_a)
		b.reach("r", tb, 0.22, ori_b))
	tw.tween_interval(0.25)
	tw.tween_callback(func() -> void:
		var p: Vector3 = meet.call()
		Audio.sfx("pop", p, -3.0, 1.2)
		a.nudge(-n * 1.8)
		b.nudge(n * 1.8)
		a.rig.squash(1.06, 0.95, 0.25)
		b.rig.squash(1.06, 0.95, 0.25)
		a.interact.contact.emit("high_five", b)
		b.interact.contact.emit("high_five", a))
	tw.tween_interval(0.16)
	tw.tween_callback(func() -> void:
		a.release("r", 0.45)
		b.release("r", 0.45)
		for me2: LumosActor in [a, b]:
			me2.body.chest_add = Vector3.ZERO
			me2.body.head_add = Vector3.ZERO
		a.laugh(1.2, 0.8))
	tw.tween_interval(0.22)
	tw.tween_callback(b.laugh.bind(1.2, 0.9))


## Figuren ohne zweiteilige Arme (Kenney, Haustiere): Kontakt als Stups mit Körper-Reaktion statt Hand-IK.
static func _simple_contact(a: LumosActor, b: LumosActor, kind: String) -> void:
	var d := b.rig.global_position - a.rig.global_position
	d.y = 0.0
	var n := d.normalized() if d.length() > 0.01 else a.forward()
	var tw := a.interact._tween()
	tw.tween_interval(0.2)
	tw.tween_callback(func() -> void:
		a.nudge(-n * 1.4)
		b.nudge(n * 1.4)
		a.interact.contact.emit(kind, b)
		b.interact.contact.emit(kind, a)
		a.laugh(1.0, 0.8)
		b.laugh(1.0, 0.8))


## Umarmung in drei Phasen: aufeinander zugehen (Köpfe seitlich versetzt, damit die großen Köpfe nicht ineinander
## stecken), Arme um die Schultern legen und sich andrücken, lösen und wieder auseinandertreten.
static func hug(a: LumosActor, b: LumosActor, hold := 1.2) -> void:
	_face_each_other(a, b)
	var pa0 := a.rig.global_position
	var pb0 := b.rig.global_position
	var d := pb0 - pa0
	d.y = 0.0
	var dist := d.length()
	if dist < 0.01:
		return
	var n := d / dist
	var side := n.cross(Vector3.UP).normalized()
	var close := (a.head_radius() + b.head_radius()) * 0.72
	var pa1 := pa0 + n * (dist - close) * 0.5 + side * 0.12
	var pb1 := pb0 - n * (dist - close) * 0.5 - side * 0.12
	for me: LumosActor in [a, b]:
		me.feel("joy", 0.25)
	var tw := a.interact._tween()
	tw.set_parallel(true)
	tw.tween_property(a.rig, "global_position", pa1, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(b.rig, "global_position", pb1, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void:
		for pair in [[a, b, 1.0], [b, a, -1.0]]:
			var me: LumosActor = pair[0]
			var other: LumosActor = pair[1]
			for hand in ["l", "r"]:
				var opp := "r" if hand == "l" else "l"
				me.reach(hand, func() -> Vector3: return other.body.joint_pos("shoulder." + opp) - other.forward() * 0.14 + Vector3(0, -0.04, 0), 0.32,
					func() -> Array: return [(other.rig.global_position - me.rig.global_position).normalized().cross(Vector3.UP) * (-1.0 if hand == "r" else 1.0), other.forward()],
					0.2)   # kaum Vorlehnen: die großen Köpfe bleiben nebeneinander
			if me.body:
				me.body.head_add = Vector3(0.1, 0.25 * float(pair[2]), 0.25 * float(pair[2]))
				me.body.chest_add = Vector3(0.16, 0, 0))
	tw.tween_interval(0.34)
	tw.tween_callback(func() -> void:
		a.nudge(n * 1.2)
		b.nudge(-n * 1.2)
		a.feel("dreamy", 0.3)
		b.feel("dreamy", 0.3)
		a.interact.contact.emit("hug", b)
		b.interact.contact.emit("hug", a))
	tw.tween_interval(hold)
	tw.tween_callback(func() -> void:
		for me2: LumosActor in [a, b]:
			me2.release("l", 0.4)
			me2.release("r", 0.4)
			me2.feel("smile", 0.4)
			if me2.body:
				me2.body.head_add = Vector3.ZERO
				me2.body.chest_add = Vector3.ZERO)
	tw.tween_interval(0.25)
	tw.set_parallel(true)
	tw.tween_property(a.rig, "global_position", pa0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(b.rig, "global_position", pb0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Schubser: beide Handflächen an die Brust des anderen (Oberfläche, nicht hinein); b federt zurück und stolpert,
## a bekommt den Rückstoß.
static func shove(a: LumosActor, b: LumosActor, strength := 1.0) -> void:
	_face_each_other(a, b)
	var chest := func(hand: String) -> Vector3:
		var c := b.body.joint_pos("chest") + Vector3(0, 0.05, 0)
		var to_a := (a.rig.global_position - b.rig.global_position).normalized()
		return c + to_a * b.head_radius() * 0.55 + b.right() * (0.12 if hand == "l" else -0.12)
	var ori := func() -> Array: return [Vector3.UP, (b.rig.global_position - a.rig.global_position).normalized()]
	a.feel("determined", 0.15)
	a.reach("l", chest.bind("l"), 0.16, ori)
	a.reach("r", chest.bind("r"), 0.16, ori)
	var tw := a.interact._tween()
	tw.tween_interval(0.17)
	tw.tween_callback(func() -> void:
		var dir := b.rig.global_position - a.rig.global_position
		b.react_hit(dir, strength, true)
		a.nudge(-dir.normalized() * 1.4 * strength)
		Audio.sfx("hit_soft", b.rig.global_position, -3.0)
		a.interact.contact.emit("shove", b)
		b.interact.contact.emit("shoved", a))
	tw.tween_interval(0.2)
	tw.tween_callback(func() -> void:
		a.release("l", 0.4)
		a.release("r", 0.4)
		a.feel("grin", 0.3))


## Schulterklopfen: Hand liegt auf der Schulter (Handfläche nach unten), klopft count-mal, die Schulter gibt jedes
## Mal nach; der andere schaut her und lächelt.
static func pat(a: LumosActor, b: LumosActor, hand := "r", count := 3) -> void:
	var sh := func() -> Vector3:
		var l := b.body.joint_pos("shoulder.l")
		var r := b.body.joint_pos("shoulder.r")
		var p := a.rig.global_position
		return (l if l.distance_to(p) < r.distance_to(p) else r) + Vector3.UP * 0.12
	a.look_at_target(b)
	a.reach(hand, sh, 0.3, func() -> Array: return [(b.rig.global_position - a.rig.global_position).normalized(), Vector3.DOWN])
	var tw := a.interact._tween()
	tw.tween_interval(0.3)
	for k in count:
		tw.tween_callback(func() -> void:
			b.nudge(Vector3.DOWN * 1.0 + (b.rig.global_position - a.rig.global_position).normalized() * 0.4)
			Audio.sfx("hit_soft", b.rig.global_position, -14.0, 1.5))
		tw.tween_interval(0.22)
	tw.tween_callback(func() -> void:
		b.look_at_target(a)
		b.feel("smile", 0.3)
		a.interact.contact.emit("pat", b))
	tw.tween_interval(0.2)
	tw.tween_callback(a.release.bind(hand, 0.4))


static func _face_each_other(a: LumosActor, b: LumosActor) -> void:
	var d := b.rig.global_position - a.rig.global_position
	d.y = 0.0
	if d.length() > 0.05:
		a.rig.turn_to(d, 0.2)
		b.rig.turn_to(-d, 0.2)
	a.look_at_target(b)
	b.look_at_target(a)


## Je Bild (vom LumosActor aufgerufen): gehaltene und fliegende Gegenstände nachführen.
func tick(delta: float) -> void:
	for hand in ["l", "r"]:
		var obj: Node3D = held[hand]
		if obj and is_instance_valid(obj):
			var ax := actor.body.hand_axes(hand) if actor.body else [Vector3.ZERO, Vector3.UP]
			var pn: Vector3 = ax[1] if (ax[1] as Vector3).length() > 0.5 else Vector3.UP
			obj.global_position = actor.hand_pos(hand) + pn * (radius_of(obj) + 0.02)   # liegt auf der Handfläche
		elif obj:
			held[hand] = null
	for f in _flying.duplicate():
		var o: Node3D = f[0]
		if not is_instance_valid(o):
			_flying.erase(f)
			continue
		f[4] = float(f[4]) + delta
		var u := clampf(float(f[4]) / float(f[5]), 0.0, 1.0)
		o.global_position = (f[1] as Vector3).lerp(f[2], u) + Vector3.UP * float(f[3]) * 4.0 * u * (1.0 - u)
		o.rotate_x(delta * 9.0)
		if u >= 1.0:
			_flying.erase(f)
			landed.emit(o, f[2])
