class_name LumosInteract
extends RefCounted
## Interaktionen des Character-Frameworks: Gegenstände greifen, halten, werfen, weitergeben, Bedienelemente
## mit beiden Händen fassen, und Zwei-Personen-Aktionen (High-Five, Umarmung, Schubser).
## Jede Interaktion verbindet Hand-IK, Körperbewegung, Gesicht, Objektposition und die Reaktion des Partners.
##
## Signale: grabbed(obj, hand) · released(obj, hand) · thrown(obj) · landed(obj, pos) · contact(kind, other)

signal grabbed(obj: Node3D, hand: String)
signal released(obj: Node3D, hand: String)
signal thrown(obj: Node3D)
signal landed(obj: Node3D, pos: Vector3)
signal contact(kind: String, other: LumosActor)

var actor: LumosActor
var held := {"l": null, "r": null}          # Hand → Node3D
var grip_offset := {"l": Vector3(0, -0.05, 0.07), "r": Vector3(0, -0.05, 0.07)}   # im Figurenraum
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
	_seq.append(tw)
	_seq = _seq.filter(func(x: Tween) -> bool: return x != null and x.is_valid())
	return tw


## Gegenstand greifen: Blick zum Objekt, Hand hin, zugreifen – danach liegt er in der Hand (held[hand]).
func grab(obj: Node3D, hand := "r", secs := 0.35) -> void:
	if obj == null or not is_instance_valid(obj):
		return
	var look_before: Variant = actor.look_target()
	actor.look_at_target(obj)
	actor.reach(hand, obj, secs)
	if actor.body:
		actor.body.chest_add = Vector3(0.18, 0, 0)   # leicht vorbeugen
	var tw := _tween()
	tw.tween_interval(secs)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(obj):
			actor.release(hand)
			return
		held[hand] = obj
		if actor.body:
			actor.body.chest_add = Vector3.ZERO
		actor.reach(hand, func() -> Vector3: return carry_point(hand), 0.3)   # Hand in Tragehaltung
		actor.look_at_target(look_before)   # Blick zurück zum vorherigen Ziel
		grabbed.emit(obj, hand))


## Tragepunkt der Hand vor dem Körper (hier landet die Hand, solange etwas gehalten wird).
func carry_point(hand: String) -> Vector3:
	return actor.rel(-0.24 if hand == "l" else 0.24, 0.95, 0.32)


## Loslassen: der Gegenstand bleibt an Ort und Stelle (oder fällt – Sache des Spiels), die Hand geht zurück.
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
	actor.reach(hand, func() -> Vector3: return actor.rel(0.42 * side, 1.75, -0.38), 0.2)   # ausholen
	if actor.body:
		actor.body.chest_add = Vector3(-0.12, 0.45 * side, 0)
	actor.rig.anticipate(0.22, 0.08)
	var tw := _tween()
	tw.tween_interval(0.24)
	tw.tween_callback(func() -> void:
		actor.reach(hand, func() -> Vector3: return actor.rel(0.2 * side, 1.5, 0.75), 0.09)   # durchziehen
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


## Gegenstand an einen anderen Akteur weitergeben: beide Hände treffen sich, der Gegenstand wechselt die Hand.
func give(to: LumosActor, hand := "r", to_hand := "l") -> void:
	var obj: Node3D = held[hand]
	if obj == null or to == null:
		return
	var mid := func() -> Vector3:
		return (actor.body.joint_pos("shoulder." + hand) + to.body.joint_pos("shoulder." + to_hand)) * 0.5 + Vector3(0, -0.12, 0)
	actor.look_at_target(to)
	to.look_at_target(obj)
	actor.reach(hand, mid, 0.4)
	to.reach(to_hand, mid, 0.45)
	var tw := _tween()
	tw.tween_interval(0.5)
	tw.tween_callback(func() -> void:
		held[hand] = null
		to.interact.held[to_hand] = obj
		released.emit(obj, hand)
		to.interact.grabbed.emit(obj, to_hand)
		to.express("smile", 0.3)
		actor.release(hand, 0.4)
		to.reach(to_hand, func() -> Vector3: return to.interact.carry_point(to_hand), 0.4)
		to.look_at_target(actor)
		contact.emit("give", to))


## Beide Hände an ein Lenkrad/Bedienelement: die Griffpunkte liegen auf dem Kranz und drehen sich mit dem Rad
## (lokale X/Y-Ebene des Rad-Knotens, Griff bei „10 und 2 Uhr“).
func hold_wheel(wheel: Node3D, radius := 0.3, secs := 0.35) -> void:
	_wheel = wheel
	_wheel_r = radius
	for hand in ["l", "r"]:
		var sgn := -1.0 if hand == "l" else 1.0
		actor.reach(hand, func() -> Vector3:
			if not is_instance_valid(_wheel):
				return Vector3.INF
			var x := _wheel.global_basis.x.normalized() * signf(_wheel.global_basis.x.dot(actor.rig.global_basis.x))
			return _wheel.global_position + (x * sgn * 0.82 + _wheel.global_basis.y.normalized() * 0.55) * _wheel_r, secs)


func release_wheel() -> void:
	_wheel = null
	actor.release("l")
	actor.release("r")


## High-Five: beide drehen sich zueinander, holen aus, die Hände treffen sich; danach lachen beide (versetzt).
static func high_five(a: LumosActor, b: LumosActor) -> void:
	_face_each_other(a, b)
	var mid := func() -> Vector3:
		var p := (a.rig.global_position + b.rig.global_position) * 0.5
		return Vector3(p.x, maxf(a.rig.global_position.y, b.rig.global_position.y) + 1.42, p.z)
	a.express("grin", 0.2)
	b.express("grin", 0.2)
	a.rig.anticipate(0.22, 0.06)
	b.rig.anticipate(0.22, 0.06)
	var tw := a.interact._tween()
	tw.tween_interval(0.14)
	tw.tween_callback(func() -> void:
		a.reach("r", mid, 0.26)
		b.reach("r", mid, 0.26))
	tw.tween_interval(0.3)
	tw.tween_callback(func() -> void:
		Audio.sfx("pop", mid.call(), -3.0, 1.2)
		a.rig.squash(1.06, 0.95, 0.25)
		b.rig.squash(1.06, 0.95, 0.25)
		a.interact.contact.emit("high_five", b)
		b.interact.contact.emit("high_five", a))
	tw.tween_interval(0.12)
	tw.tween_callback(func() -> void:
		a.release("r", 0.45)
		b.release("r", 0.45)
		a.laugh(1.2, 0.8))
	tw.tween_interval(0.22)
	tw.tween_callback(b.laugh.bind(1.2, 0.9))


## Umarmung: beide Arme um den Partner (Hände hinter dessen Schultern), Köpfe neigen sich, danach lösen.
static func hug(a: LumosActor, b: LumosActor, hold := 1.2) -> void:
	_face_each_other(a, b)
	for pair in [[a, b], [b, a]]:
		var me: LumosActor = pair[0]
		var other: LumosActor = pair[1]
		me.express("smile", 0.3)
		for hand in ["l", "r"]:
			var opp := "r" if hand == "l" else "l"
			me.reach(hand, func() -> Vector3: return other.body.joint_pos("shoulder." + opp) - other.forward() * 0.16 + Vector3(0, -0.05, 0), 0.45)
		if me.body:
			me.body.head_add = Vector3(0.1, 0, 0.22 if me == a else -0.22)
			me.body.chest_add = Vector3(0.14, 0, 0)
	var tw := a.interact._tween()
	tw.tween_interval(0.45)
	tw.tween_callback(func() -> void:
		a.express("dreamy", 0.3)
		b.express("dreamy", 0.3)
		a.interact.contact.emit("hug", b)
		b.interact.contact.emit("hug", a))
	tw.tween_interval(hold)
	tw.tween_callback(func() -> void:
		for me2: LumosActor in [a, b]:
			me2.release("l", 0.5)
			me2.release("r", 0.5)
			me2.express("smile", 0.4)
			if me2.body:
				me2.body.head_add = Vector3.ZERO
				me2.body.chest_add = Vector3.ZERO)


## Schubser: a stößt b mit beiden Händen vor die Brust; b federt zurück, stolpert und schaut erschrocken.
static func shove(a: LumosActor, b: LumosActor, strength := 1.0) -> void:
	_face_each_other(a, b)
	var chest := func() -> Vector3: return b.body.joint_pos("chest") + Vector3(0, 0.05, 0)
	a.express("determined", 0.15)
	a.reach("l", chest, 0.16)
	a.reach("r", chest, 0.16)
	var tw := a.interact._tween()
	tw.tween_interval(0.17)
	tw.tween_callback(func() -> void:
		var dir := b.rig.global_position - a.rig.global_position
		b.react_hit(dir, strength, true)
		Audio.sfx("hit_soft", b.rig.global_position, -3.0)
		a.interact.contact.emit("shove", b)
		b.interact.contact.emit("shoved", a))
	tw.tween_interval(0.2)
	tw.tween_callback(func() -> void:
		a.release("l", 0.4)
		a.release("r", 0.4)
		a.express("grin", 0.3))


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
			obj.global_position = actor.hand_pos(hand) + actor.rig.global_basis * (grip_offset[hand] as Vector3)
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
