extends MinigameBase
## Taxi-Koordinaten (2 gegen 2): Jedes Team fährt ein Taxi – ein Teammitglied lenkt NUR links/rechts, das
## andere NUR vor/zurück. Beide Teams jagen denselben winkenden Fahrgast; wer ihn zuerst einsammelt, bringt ihn
## zur Zielfahne (+1 für beide im Team). Wer ein besetztes Taxi kräftig rammt, schnappt sich den Fahrgast!
## Online: Host-Modell.

const HALF_X := 9.5
const HALF_Z := 6.3
const R := 0.95
const MAX_V := 6.5
const BLOCKS := [Rect2(-7.4, -4.4, 5.2, 3.0), Rect2(2.2, -4.4, 5.2, 3.0), Rect2(-7.4, 1.4, 5.2, 3.0), Rect2(2.2, 1.4, 5.2, 3.0)]

var _taxi: Array[Dictionary] = []    # je Team: {node, pos, vel, x_slot, z_slot, carry}
var _pax := Vector3.ZERO
var _pax_state := 0                  # 0 = wartet, 1 = im Taxi, 2 = nächster kommt
var _pax_team := -1
var _goal := Vector3.ZERO
var _pax_node: Node3D
var _goal_node: Node3D
var _beacon: MeshInstance3D
var _wait_t := 0.8
var _steal_cd := 0.0


func _init() -> void:
	game_id = "axis_taxi"
	env_preset = "day"
	backdrop_style = "meadow"
	time_limit = 50.0
	score_format = "%d"
	arena_radius = 10.0
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 10)
	net_model = "host"
	spawn_points = [Vector3(-8, 0.6, 0), Vector3(8, 0.6, 0), Vector3(-8, 0.6, 0.8), Vector3(8, 0.6, 0.8)]


func build_arena() -> void:
	# Straßennetz: Asphalt mit Mittellinien, vier Häuserblöcke mit Gebäuden, Bäumchen und Laternen
	WorldKit.box(world, Vector3(HALF_X * 2 + 1.4, 0.4, HALF_Z * 2 + 1.4), Vector3(0, -0.2, 0), Color("#5d6270"))
	for z in [-5.8, 0.0, 5.8]:
		for x in range(-9, 10, 2):
			WorldKit.box(world, Vector3(0.9, 0.02, 0.14), Vector3(x, 0.01, z), Color("#ffe066"), false)
	for x in [-8.6, 0.0, 8.6]:
		for z in range(-5, 6, 2):
			WorldKit.box(world, Vector3(0.14, 0.02, 0.9), Vector3(x, 0.01, z), Color("#ffe066"), false)
	var bkeys := ["city/building_a", "city/building_e", "city/building_h", "city/sky_a"]
	for k in BLOCKS.size():
		var r: Rect2 = BLOCKS[k]
		var c := Vector3(r.get_center().x, 0, r.get_center().y)
		WorldKit.box(world, Vector3(r.size.x, 0.25, r.size.y), c + Vector3(0, 0.12, 0), Color("#b8c2a8"), false)
		WorldKit.place(world, bkeys[k], c + Vector3(-1.0, 0.25, 0), 0.0, 1.2)
		WorldKit.place(world, "nat/tree_oak", c + Vector3(1.6, 0.25, -0.8), randf() * 360.0, 1.4)
		WorldKit.place(world, "nat/bush", c + Vector3(1.8, 0.25, 0.8), 0.0, 2.0)
		WorldKit.place(world, "town/lantern", c + Vector3(r.size.x * 0.5 - 0.3, 0.25, r.size.y * 0.5 - 0.3), 0.0, 0.9)
	for side in [-1.0, 1.0]:
		WorldKit.box(world, Vector3(HALF_X * 2 + 1.4, 0.6, 0.4), Vector3(0, 0.3, side * (HALF_Z + 0.9)), Color("#9aa3b5"))
		WorldKit.box(world, Vector3(0.4, 0.6, HALF_Z * 2 + 1.4), Vector3(side * (HALF_X + 0.9), 0.3, 0), Color("#9aa3b5"))
	for k in 2:
		var n := Assets.spawn("car/taxi", world, Vector3(-8.0 if k == 0 else 8.0, 0, 0), 90.0 if k == 0 else -90.0, 1.5)
		# Teamfarbe als Dachschild
		WorldKit.box(n, Vector3(0.6, 0.18, 0.35), Vector3(0, 0.95, 0), Color("#ff4d6d") if k == 0 else Color("#4da6ff"), false)
		_taxi.append({"node": n, "pos": Vector3(-8.0 if k == 0 else 8.0, 0, 0), "vel": Vector3.ZERO, "x_slot": -1, "z_slot": -1})
	_pax_node = Assets.spawn("mini/female_b", world, Vector3.ZERO, 0.0, 1.0)
	_beacon = MgKit.ring(world, 1.2, 0.12, Color(1.0, 0.85, 0.3), 1.5)
	_goal_node = WorldKit.place(world, "qp/flag", Vector3(0, 0, 0), 0.0, 0.6)
	_goal_node.visible = false


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, 0.6)
	c.offset = Vector3(0, 15.0, 11.0)
	c.min_dist = 0.95
	c.max_dist = 1.05


func on_start() -> void:
	# Rollen: kleinerer Slot im Team lenkt X, der andere Z
	for t in 2:
		var mem: Array[int] = []
		for i in active_slots():
			if teams[i] == t:
				mem.append(i)
		if mem.size() > 0:
			_taxi[t].x_slot = mem[0]
			_taxi[t].z_slot = mem[1] if mem.size() > 1 else mem[0]
		for i in mem:
			var av := avatars[i] as PartyAvatar
			av.freeze(true)
			av.can_shove = false
			av.set_physics_process(false)
			av.rig.scale *= 0.55
			av.rig.play("sit_chair", 0.1)
			Juice.float_text(self, av.global_position + Vector3.UP * 2.0, "← →" if i == _taxi[t].x_slot else "↑ ↓", Color("#fff1a8"), 70)
	_new_passenger()


func _street_point() -> Vector3:
	var line := rng.randi() % 4
	match line:
		0:
			return Vector3(rng.randf_range(-HALF_X + 1, HALF_X - 1), 0, [-5.8, 0.0, 5.8][rng.randi() % 3])
		1:
			return Vector3([-8.6, 0.0, 8.6][rng.randi() % 3], 0, rng.randf_range(-HALF_Z + 1, HALF_Z - 1))
		2:
			return Vector3(rng.randf_range(-HALF_X + 1, -1.5), 0, 0.0)
	return Vector3(0.0, 0, rng.randf_range(-HALF_Z + 1, HALF_Z - 1))


func _new_passenger() -> void:
	_pax = _street_point()
	_pax_state = 0
	_pax_team = -1
	_pax_node.visible = true
	_pax_node.position = _pax
	_beacon.visible = true
	_beacon.position = _pax + Vector3.UP * 0.05
	_goal_node.visible = false
	Audio.sfx("whistle_up", _pax, -6.0)


func on_tick(delta: float) -> void:
	_steal_cd = maxf(0.0, _steal_cd - delta)
	for t in 2:
		_drive(t, delta)
	_bump()
	var tt := time_limit - time_left
	_beacon.scale = Vector3.ONE * (1.0 + sin(tt * 6.0) * 0.12)
	match _pax_state:
		0:
			_pax_node.rotation.y += delta * 2.0
			for t in 2:
				if (_taxi[t].pos as Vector3).distance_to(_pax) < 1.7:
					_pickup(t)
					break
		1:
			_pax_node.position = (_taxi[_pax_team].pos as Vector3) + Vector3.UP * 1.25
			_beacon.position = _goal + Vector3.UP * 0.05
			if (_taxi[_pax_team].pos as Vector3).distance_to(_goal) < 1.7:
				_deliver()
		2:
			_wait_t -= delta
			if _wait_t <= 0.0:
				_new_passenger()


func _drive(t: int, delta: float) -> void:
	var tx: Dictionary = _taxi[t]
	if int(tx.x_slot) < 0:
		return
	var want := Vector3(InputHub.move(int(tx.x_slot)).x, 0, InputHub.move(int(tx.z_slot)).y) * MAX_V
	var v: Vector3 = (tx.vel as Vector3).move_toward(want, 14.0 * delta)
	var p: Vector3 = (tx.pos as Vector3) + v * delta
	# Häuserblöcke und Rand: achsenweise abprallen (gleiten entlang der Kante)
	for r in BLOCKS:
		var e := (r as Rect2).grow(R * 0.9)
		if e.has_point(Vector2(p.x, p.z)):
			var old: Vector3 = tx.pos
			if not e.has_point(Vector2(old.x, p.z)):
				p.x = old.x
				v.x *= -0.2
			elif not e.has_point(Vector2(p.x, old.z)):
				p.z = old.z
				v.z *= -0.2
			else:
				p = old
	p.x = clampf(p.x, -HALF_X + 0.4, HALF_X - 0.4)
	p.z = clampf(p.z, -HALF_Z + 0.4, HALF_Z - 0.4)
	tx.pos = p
	tx.vel = v
	var node: Node3D = tx.node
	node.position = p
	if v.length() > 0.5:
		node.rotation.y = lerp_angle(node.rotation.y, atan2(v.x, v.z), 0.25)
		if randf() < 0.1:
			FX.dust(p - v.normalized() * 1.0, Color(0.75, 0.75, 0.8), 2, 0.4)
	# Fahrer sitzen im Taxi (vorne lenkt X, hinten Z)
	var fwd := Vector3(sin(node.rotation.y), 0, cos(node.rotation.y))
	(avatars[int(tx.x_slot)] as PartyAvatar).global_position = p + fwd * 0.35 + Vector3.UP * 0.55
	if int(tx.z_slot) != int(tx.x_slot):
		(avatars[int(tx.z_slot)] as PartyAvatar).global_position = p - fwd * 0.45 + Vector3.UP * 0.55
	for s in [int(tx.x_slot), int(tx.z_slot)]:
		(avatars[s] as PartyAvatar).rig.rotation.y = node.rotation.y


func _bump() -> void:
	var a: Dictionary = _taxi[0]
	var b: Dictionary = _taxi[1]
	var d: Vector3 = (b.pos as Vector3) - (a.pos as Vector3)
	if d.length() < R * 2.0 and d.length() > 0.01:
		var n := d.normalized()
		var push := (R * 2.0 - d.length()) * 0.5
		a.pos = (a.pos as Vector3) - n * push
		b.pos = (b.pos as Vector3) + n * push
		var rel := ((a.vel as Vector3) - (b.vel as Vector3)).dot(n)
		if rel > 0.0:
			a.vel = (a.vel as Vector3) - n * rel * 0.9
			b.vel = (b.vel as Vector3) + n * rel * 0.9
			Audio.sfx("metal_hit", (a.pos as Vector3) + n * R, -4.0)
			Juice.shake(0.15)
		# Kräftiger Rempler klaut den Fahrgast
		if rel > 4.0 and _pax_state == 1 and _steal_cd <= 0.0:
			var thief := 0 if _pax_team == 1 else 1
			var rammer_speed := (a.vel as Vector3).length() if thief == 0 else (b.vel as Vector3).length()
			if rammer_speed > 2.0:
				_pax_team = thief
				_steal_cd = 1.5
				FX.stars(_pax_node.global_position + Vector3.UP, Color(1, 0.9, 0.4), 12)
				Juice.float_text(self, _pax_node.global_position + Vector3.UP * 1.5, "Umgestiegen!", Color("#ffd166"), 64)
				Audio.sfx("boing", _pax_node.global_position)


func _pickup(t: int) -> void:
	_pax_state = 1
	_pax_team = t
	_goal = _street_point()
	while _goal.distance_to(_pax) < 8.0:
		_goal = _street_point()
	_goal_node.visible = true
	_goal_node.position = _goal
	Audio.sfx("chime", _pax)
	FX.sparks(_pax + Vector3.UP, Color(1, 0.9, 0.4), 10)


func _deliver() -> void:
	var t := _pax_team
	_pax_state = 2
	_wait_t = 0.8
	_pax_node.visible = false
	_beacon.visible = false
	_goal_node.visible = false
	FX.stars(_goal + Vector3.UP, Color(1, 0.85, 0.3), 16)
	Audio.sfx("coin_chime", _goal)
	var crew: Array[int] = [int(_taxi[t].x_slot)]
	if int(_taxi[t].z_slot) != crew[0]:
		crew.append(int(_taxi[t].z_slot))
	for s in crew:
		add_score(s, 1.0)
		(avatars[s] as PartyAvatar).rig.react("cheer")


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	d["t"] = _taxi.map(func(tx: Dictionary) -> Array: return [snappedf((tx.pos as Vector3).x, 0.01), snappedf((tx.pos as Vector3).z, 0.01), snappedf((tx.node as Node3D).rotation.y, 0.02)])
	d["p"] = [snappedf(_pax.x, 0.01), snappedf(_pax.z, 0.01), _pax_state, _pax_team, snappedf(_goal.x, 0.01), snappedf(_goal.z, 0.01)]
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var ts: Array = d.get("t", [])
	for k in mini(2, ts.size()):
		_taxi[k].pos = Vector3(float(ts[k][0]), 0, float(ts[k][1]))
		(_taxi[k].node as Node3D).position = _taxi[k].pos
		(_taxi[k].node as Node3D).rotation.y = float(ts[k][2])
	var pp: Array = d.get("p", [])
	if pp.size() == 6:
		var st := int(pp[2])
		if st != _pax_state and st == 2:
			FX.stars(_goal + Vector3.UP, Color(1, 0.85, 0.3), 16)
			Audio.sfx("coin_chime", _goal)
		_pax = Vector3(float(pp[0]), 0, float(pp[1]))
		_pax_state = st
		_pax_team = int(pp[3])
		_goal = Vector3(float(pp[4]), 0, float(pp[5]))
		_pax_node.visible = st != 2
		_beacon.visible = st != 2
		_goal_node.visible = st == 1
		_goal_node.position = _goal
		if st == 0:
			_pax_node.position = _pax
			_beacon.position = _pax + Vector3.UP * 0.05
		elif st == 1 and _pax_team >= 0:
			_pax_node.position = (_taxi[_pax_team].pos as Vector3) + Vector3.UP * 1.25
			_beacon.position = _goal + Vector3.UP * 0.05


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var t := teams[slot]
	if t > 1 or _taxi.is_empty():
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var tx: Dictionary = _taxi[t]
	var p: Vector3 = tx.pos
	var target := _pax if _pax_state == 0 else (_goal if _pax_team == t else (_taxi[1 - t].pos as Vector3))
	# Über die Straßen: erst auf eine Straße, die zum Ziel führt (Kreuzungen bei x/z = −8,6 / 0 / 8,6)
	var way := target
	if _blocked(p, target):
		var lanes := [-8.6, 0.0, 8.6]
		var lx: float = lanes.reduce(func(a: float, b: float) -> float: return a if absf(a - p.x) < absf(b - p.x) else b)
		var lz: float = [-5.8, 0.0, 5.8].reduce(func(a: float, b: float) -> float: return a if absf(a - p.z) < absf(b - p.z) else b)
		way = Vector3(lx, 0, target.z) if absf(p.x - lx) < absf(p.z - lz) else Vector3(target.x, 0, lz)
		if p.distance_to(way) < 0.8:
			way = target
	var to := way - p
	var mv := Vector2.ZERO
	var gain: float = [0.6, 0.9, 1.3][level]
	if slot == int(tx.x_slot):
		mv.x = clampf(to.x * gain, -1.0, 1.0)
	if slot == int(tx.z_slot):
		mv.y = clampf(to.z * gain, -1.0, 1.0)
	if randf() < [0.08, 0.03, 0.0][level]:
		mv = -mv
	InputHub.set_virtual(slot, mv)


func _blocked(a: Vector3, b: Vector3) -> bool:
	for k in 8:
		var q := a.lerp(b, (k + 1) / 9.0)
		for r in BLOCKS:
			if (r as Rect2).grow(R * 0.6).has_point(Vector2(q.x, q.z)):
				return true
	return false
