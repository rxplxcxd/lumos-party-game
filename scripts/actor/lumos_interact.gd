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
		if actor.look_target() == obj:   # nur zurückschauen, wenn niemand inzwischen ein neues Blickziel gesetzt hat
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
		if actor.look_target() is Vector3 and (actor.look_target() as Vector3).is_equal_approx(target):
			actor.look_at_target(look_before))


## Weitergeben (Interaktionsprotokoll „give“): beide Hände treffen sich, der Gegenstand wechselt die Hand.
func give(to: LumosActor, hand := "r", to_hand := "l") -> LumosInteraction:
	return LumosInteraction.start("give", actor, to, {"hand": hand, "to_hand": to_hand})


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


## Zwei-Personen-Aktionen laufen seit 1.5.2 über das Interaktionsprotokoll (LumosInteraction) – eine Umsetzung,
## Phasen, Schicht-Ansprüche, sauberes Beenden. Diese Aufrufe bleiben als Kurzformen erhalten.
static func high_five(a: LumosActor, b: LumosActor) -> LumosInteraction:
	return LumosInteraction.start("high_five", a, b)


static func hug(a: LumosActor, b: LumosActor, hold := 1.2) -> LumosInteraction:
	return LumosInteraction.start("hug", a, b, {"secs": hold})


static func shove(a: LumosActor, b: LumosActor, strength := 1.0) -> LumosInteraction:
	return LumosInteraction.start("playful_shove", a, b, {"strength": strength})


static func pat(a: LumosActor, b: LumosActor, hand := "r", count := 3) -> LumosInteraction:
	return LumosInteraction.start("pat", a, b, {"hand": hand, "count": count})


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
