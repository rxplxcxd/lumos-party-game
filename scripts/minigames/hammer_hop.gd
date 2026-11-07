extends MinigameBase
## Hammer-Hüpfen: Ein riesiger Holzhammer-Balken kreist knapp über dem Boden einer runden
## Turmplattform – spring im richtigen Moment! Er wird schneller, wechselt die Richtung, und ab der
## Hälfte kreist ein zweiter, hoher Balken mit, unter dem man NICHT springen darf.

const RADIUS := 8.0
const ARM_LOW_Y := 0.45
const ARM_HIGH_Y := 2.15

var arms: Array[Dictionary] = []
var _speed := 1.25
var _dir := 1.0
var _flip_t := 9.0
var _second_spawned := false


func _init() -> void:
	game_id = "hammer_hop"
	env_preset = "sky"
	time_limit = 45.0
	survival = true
	hazard = "fall"
	kill_y = -8.0
	arena_radius = 9.5
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 13)
	spawn_points = [Vector3(-3.5, 0.5, -3.5), Vector3(3.5, 0.5, -3.5), Vector3(-3.5, 0.5, 3.5), Vector3(3.5, 0.5, 3.5)]


func build_arena() -> void:
	WorldKit.cylinder(world, RADIUS, 1.0, Vector3(0, -0.5, 0), Color("#c8b48a"))
	WorldKit.cylinder(world, RADIUS + 0.4, 0.3, Vector3(0, -1.1, 0), Color("#7a6a50"), false)
	WorldKit.cylinder(world, RADIUS * 0.7, 8.0, Vector3(0, -5.5, 0), Color("#8f8270"), false)
	# Zentrale Säule mit Getriebe
	var hub := WorldKit.cylinder(world, 0.9, 3.0, Vector3(0, 1.5, 0), Color("#6b5b45"))
	hub.name = "Hub"
	WorldKit.place(world, "castle/tower_roof", Vector3(0, 3.0, 0), 0.0, 1.0)
	_add_arm(0.0, false)
	# Wolken-Inseln ringsum
	for i in 8:
		var a := TAU * i / 8.0 + 0.3
		var pos := Vector3(cos(a) * 18.0, randf_range(-6.0, -2.0), sin(a) * 18.0)
		WorldKit.place(world, ["castle/tower", "nat/tree_oak", "castle/tree", "plat/tree"][i % 4], pos, randf() * 360.0, 2.0)
	for i in 6:
		var a2 := TAU * i / 6.0
		WorldKit.place(world, "plat/flag", Vector3(cos(a2), 0, sin(a2)) * (RADIUS - 0.4), rad_to_deg(-a2), 1.2)


func _add_arm(angle: float, high: bool) -> void:
	var pivot := Node3D.new()
	world.add_child(pivot)
	pivot.position = Vector3(0, ARM_HIGH_Y if high else ARM_LOW_Y, 0)
	pivot.rotation.y = angle
	var length := RADIUS + 0.6
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(length, 0.45, 0.55)
	bm.material = WorldKit.mat(Color("#a0522d") if not high else Color("#5a6fa8"), 0.7)
	beam.mesh = bm
	beam.position = Vector3(length * 0.5, 0, 0)
	pivot.add_child(beam)
	# Hammerkopf am Ende
	var head := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.75
	cm.bottom_radius = 0.75
	cm.height = 1.8
	cm.material = WorldKit.mat(Color("#d0a060") if not high else Color("#8fb0ff"), 0.6, 0.15)
	head.mesh = cm
	head.rotation.z = 0.0
	head.rotation.x = PI * 0.5
	head.position = Vector3(length, 0, 0)
	pivot.add_child(head)
	var rope_ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.74
	tm.outer_radius = 0.86
	tm.material = WorldKit.mat(Color("#ffd23f"), 0.4, 0.6)
	rope_ring.mesh = tm
	rope_ring.rotation.z = PI * 0.5
	rope_ring.position = Vector3(length, 0, 0)
	pivot.add_child(rope_ring)
	var whoosh := FX.make_trail(head, "dust")
	whoosh.emitting = true
	whoosh.amount = 10
	arms.append({"pivot": pivot, "angle": angle, "high": high, "prev": angle})
	if high:
		Juice.pop_in(pivot, 0.5)


func on_start() -> void:
	for av in avatars:
		(av as PartyAvatar).can_shove = true
		(av as PartyAvatar).rig.surface = "wood"


func on_tick(delta: float) -> void:
	var prog := 1.0 - time_left / time_limit
	_speed = lerpf(1.25, 3.1, prog)
	_flip_t -= delta
	if _flip_t <= 0.0:
		_flip_t = randf_range(6.0, 10.0)
		_dir = -_dir
		Audio.sfx("creak", Vector3.ZERO, 0.0)
		Juice.shake(0.12)
		for a in arms:
			Juice.squash(a.pivot, 1.0, 1.3, 0.3)
	if not _second_spawned and prog > 0.45:
		_second_spawned = true
		_add_arm(float(arms[0].angle) + PI, true)
		CutsceneManager.big_word("Achtung, oben!", Color("#8fb0ff"), 0.6)
	for a in arms:
		var spd := _speed   # gleiche Geschwindigkeit: Abstand tief/hoch bleibt immer fair (halbe Runde)
		a.prev = a.angle
		a.angle = float(a.angle) + _dir * spd * delta
		(a.pivot as Node3D).rotation.y = float(a.angle)
		_check_hits(a)


## Winkel eines Punkts so, wie Node3D.rotation.y den Balken (+X) dreht.
static func _ang(p: Vector3) -> float:
	return atan2(-p.z, p.x)


func _check_hits(a: Dictionary) -> void:
	var high: bool = a.high
	for i in 4:
		var av := avatars[i] as PartyAvatar
		if not alive[i] or not av.alive:
			continue
		var p := av.global_position
		var r := Vector2(p.x, p.z).length()
		if r > RADIUS + 0.8 or r < 0.9:
			continue
		var ang := _ang(p)
		# hat der Balken den Winkel des Spielers in diesem Frame überstrichen?
		var swept := wrapf(float(a.angle) - float(a.prev), -PI, PI)
		var rel := wrapf(ang - float(a.prev), -PI, PI)
		var tol := 0.42 / maxf(r, 0.5)
		var crossed := (swept >= 0.0 and rel >= -tol and rel <= swept + tol) or (swept < 0.0 and rel <= tol and rel >= swept - tol)
		if not crossed:
			continue
		var feet := p.y
		var hit := false
		if high:
			hit = feet + 1.7 > ARM_HIGH_Y - 0.25 and feet < ARM_HIGH_Y + 0.25
		else:
			hit = feet < ARM_LOW_Y + 0.42
		if hit:
			_bonk(i, a)


func _bonk(i: int, a: Dictionary) -> void:
	var av := avatars[i] as PartyAvatar
	var p := av.global_position
	var radial := Vector3(p.x, 0, p.z).normalized()
	var ang := float(a.angle)
	var tangent := Vector3(-sin(ang), 0, -cos(ang)) * _dir
	av.alive = false
	av.freeze(true)
	av.set_physics_process(false)
	eliminate(i)
	av.rig.react("launch")
	Audio.sfx("wood_hit", p, 2.0)
	Audio.sfx("whistle_up", p, -4.0)
	FX.stars(p + Vector3.UP * 1.2, Color(1, 0.95, 0.5), 14)
	Juice.hitstop(0.09)
	Juice.shake(0.4)
	InputHub.rumble(i, 1.0, 0.35)
	var dest := p + (tangent * 0.7 + radial * 0.6).normalized() * 16.0 + Vector3.UP * 7.0
	var tw := av.create_tween()
	tw.tween_property(av, "global_position", dest, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(av.rig.pivot, "rotation:z", TAU * 2.5 * _dir, 0.9)
	tw.tween_property(av, "global_position", dest + Vector3(0, -22, 0), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		FX.stars(av.global_position + Vector3.UP * 10.0, Color(1, 1, 1), 5)
		av.visible = false)


func cpu_think(slot: int, delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	if not alive[slot]:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var mem := cpu_mem[slot]
	var pos := av.global_position
	var held := {}
	var hold_t := float(mem.get("hold", 0.0)) - delta
	var r := Vector2(pos.x, pos.z).length()
	var ang := _ang(pos)
	var must_jump := false
	var must_stay := false
	var react: float = [0.2, 0.27, 0.32][level] + float(mem.get("jitter", 0.0))
	for a in arms:
		var spd := _speed
		var gap := wrapf((ang - float(a.angle)) * _dir, 0.0, TAU)
		var t := gap / maxf(spd, 0.01)
		if a.high:
			if t < 0.75:
				must_stay = true
		elif t < react and t > react - 0.12:
			must_jump = true
	if must_jump and not must_stay and av.is_on_floor():
		hold_t = 0.32
		mem["jitter"] = randf_range(-0.06, 0.06) * (3 - level)
		if randf() < [0.12, 0.05, 0.015][level]:
			hold_t = 0.0   # verpatzt – auch CPUs sind nur Menschen
	if hold_t > 0.0:
		held["a"] = true
	mem["hold"] = hold_t
	# in einem bequemen Ring bleiben, weg von Gegnern
	var want_r := 4.5
	var mv := Vector2.ZERO
	if r > want_r + 1.5:
		mv = -Vector2(pos.x, pos.z).normalized() * 0.7
	elif r < want_r - 2.0:
		mv = Vector2(pos.x, pos.z).normalized() * 0.5
	for o in avatars:
		var oa := o as PartyAvatar
		if oa != av and oa.alive and oa.global_position.distance_to(pos) < 1.6:
			mv += Vector2(pos.x - oa.global_position.x, pos.z - oa.global_position.z).normalized() * 0.6
			if level > 0 and randf() < 0.03:
				held["b"] = true
	InputHub.set_virtual(slot, mv.limit_length(1.0), held)
