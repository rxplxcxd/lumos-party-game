extends MinigameBase
## Kullerkasten (Glück & Münzen): Ein großes Nagelbrett auf dem Jahrmarkt. Jeder schiebt seinen Abwurf oben
## entlang (Stick) und lässt nacheinander drei Kugeln fallen (A). Die Kugeln hüpfen durch die Nägel und
## landen in Fächern mit Münzwerten – ganz in der Mitte wartet die 10. Ein wandernder Bumper bringt Chaos.
## Online: Host-Modell (Host rollt alle Kugeln).

const W := 4.2
const TOP := 9.0
const BR := 0.22
const PR := 0.12
const BALLS := 3
const SLOT_VAL := [2, 5, 1, 3, 10, 3, 1, 5, 2]

var _pegs: Array[Vector2] = []
var _balls: Array[Dictionary] = []   # {pos, vel, slot, node, done}
var _drop_x: Array[float] = [-3.0, -1.0, 1.0, 3.0]
var _left: Array[int] = [BALLS, BALLS, BALLS, BALLS]
var _cd: Array[float] = [0, 0, 0, 0]
var _droppers: Array[Node3D] = []
var _bumper: Node3D
var _bump_x := 0.0
var _board: Node3D
var _over_t := -1.0


func _init() -> void:
	game_id = "prize_drop"
	env_preset = "sunset"
	backdrop_style = "meadow"
	time_limit = 35.0
	score_format = "%d Münzen"
	arena_radius = 7.0
	teaser_height = 4.0
	cannon_pos = Vector3(6, 0, 8)
	net_model = "host"
	spawn_points = [Vector3(-3, 0.6, 3.0), Vector3(-1, 0.6, 3.0), Vector3(1, 0.6, 3.0), Vector3(3, 0.6, 3.0)]


func build_arena() -> void:
	WorldKit.box(world, Vector3(16, 0.4, 10), Vector3(0, -0.2, 2), Color("#c49a6c"))
	_board = Node3D.new()
	world.add_child(_board)
	_board.position = Vector3(0, 0.4, 0)
	WorldKit.box(_board, Vector3(W * 2 + 0.6, TOP + 1.2, 0.3), Vector3(0, TOP * 0.5, -0.25), Color("#7a4ec2"), false)
	WorldKit.box(_board, Vector3(W * 2 + 0.2, TOP + 0.8, 0.05), Vector3(0, TOP * 0.5, -0.08), Color("#fff6e0"), false)
	for s in [-1.0, 1.0]:
		WorldKit.box(_board, Vector3(0.3, TOP + 1.2, 0.5), Vector3(s * (W + 0.3), TOP * 0.5, 0), Color("#ff8fab"), false)
	# Nägel: versetzte Reihen
	var row := 0
	var y := TOP - 1.6
	while y > 1.6:
		var off := 0.45 if row % 2 else 0.0
		var x := -W + 0.45 + off
		while x < W - 0.3:
			_pegs.append(Vector2(x, y))
			var peg := WorldKit.cylinder(_board, PR, 0.3, Vector3(x, y, 0), Color("#ffd166"), false)
			peg.rotation.x = PI / 2.0
			x += 0.9
		y -= 0.75
		row += 1
	# Fächer mit Werten
	var sw := W * 2.0 / SLOT_VAL.size()
	for k in SLOT_VAL.size():
		var cx := -W + sw * (k + 0.5)
		if k > 0:
			WorldKit.box(_board, Vector3(0.08, 1.0, 0.3), Vector3(-W + sw * k, 0.5, 0), Color("#7a4ec2"), false)
		var lb := Label3D.new()
		lb.text = str(SLOT_VAL[k])
		lb.font_size = 110 if SLOT_VAL[k] < 10 else 150
		lb.outline_size = 22
		lb.modulate = Color("#ffd23f") if SLOT_VAL[k] >= 10 else (Color("#ffffff") if SLOT_VAL[k] >= 3 else Color("#c9d6e8"))
		lb.position = Vector3(cx, 0.35, 0.25)
		_board.add_child(lb)
	_bumper = Node3D.new()
	_board.add_child(_bumper)
	var bm := WorldKit.cylinder(_bumper, 0.42, 0.35, Vector3.ZERO, Color("#ff4d6d"), false)
	bm.rotation.x = PI / 2.0
	for k in 4:
		var d := Node3D.new()
		world.add_child(d)
		WorldKit.box(d, Vector3(0.5, 0.25, 0.4), Vector3.ZERO, Game.player_color(k), false)
		WorldKit.box(d, Vector3(0.12, 0.3, 0.12), Vector3(0, -0.25, 0), Color("#5b5f66"), false)
		_droppers.append(d)
	# Jahrmarkt-Deko
	for i in 6:
		WorldKit.place(world, ["town/lantern", "qp/bush_fruit", "plat/flowers"][i % 3], Vector3(-7.0 + i * 2.8, 0, 6.0), randf() * 360.0, [1.2, 0.3, 1.8][i % 3])


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 4.8, 0)
	c.offset = Vector3(0, 1.5, 13.0)
	c.look_offset = Vector3.ZERO
	c.min_dist = 1.0
	c.max_dist = 1.0


func on_start() -> void:
	for i in active_slots():
		var av := avatars[i] as PartyAvatar
		av.can_move = false
		av.can_jump = false
		av.can_shove = false
		av.rig.face_now(Vector3.FORWARD)


func check_end() -> bool:
	return _over_t >= 0.0 and _over_t > 1.5


func on_tick(delta: float) -> void:
	var tt := time_limit - time_left
	_bump_x = sin(tt * 0.9) * (W - 1.0)
	_bumper.position = Vector3(_bump_x, 4.2, 0)
	for i in active_slots():
		_cd[i] = maxf(0.0, _cd[i] - delta)
		_drop_x[i] = clampf(_drop_x[i] + InputHub.move(i).x * 4.5 * delta, -W + 0.3, W - 0.3)
		_droppers[i].position = _board.position + Vector3(_drop_x[i], TOP + 0.3 + i * 0.02, 0.05)
		if InputHub.pressed(i, "a") and _left[i] > 0 and _cd[i] <= 0.0:
			_drop(i)
	_step(delta)
	var all_done := true
	for i in active_slots():
		if _left[i] > 0:
			all_done = false
	for b in _balls:
		if not bool(b.done):
			all_done = false
	if all_done:
		_over_t = maxf(_over_t, 0.0) + delta


func _drop(i: int) -> void:
	_left[i] -= 1
	_cd[i] = 0.7
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = BR
	sm.height = BR * 2.0
	mi.mesh = sm
	mi.material_override = WorldKit.mat(Game.player_color(i).lightened(0.2), 0.2, 0.3)
	_board.add_child(mi)
	_balls.append({"pos": Vector2(_drop_x[i], TOP), "vel": Vector2(rng.randf_range(-0.3, 0.3), 0), "slot": i, "node": mi, "done": false, "age": 0.0})
	Audio.sfx("plop", null, -4.0, 1.3)
	(avatars[i] as PartyAvatar).rig.play_once("interact", "idle", 1.6)


func _step(delta: float) -> void:
	for b in _balls:
		if bool(b.done):
			continue
		var v: Vector2 = b.vel
		var p: Vector2 = b.pos
		# Liegt eine Kugel auf einem Nagel still? Anstupsen; nach 9 s fällt sie in jedem Fall ins Fach darunter
		b.age = float(b.age) + delta
		if v.length() < 0.3 and p.y > 1.0:
			v += Vector2(rng.randf_range(-1.5, 1.5), 0.5)
		if float(b.age) > 9.0:
			p.y = BR
		v.y -= 14.0 * delta
		p += v * delta
		if absf(p.x) > W - BR:
			p.x = signf(p.x) * (W - BR)
			v.x *= -0.5
		for pg in _pegs:
			var d := p - pg
			if d.length() < BR + PR:
				var n := d.normalized() if d.length() > 0.001 else Vector2.UP
				p = pg + n * (BR + PR)
				v = v - n * v.dot(n) * 1.5 + Vector2(rng.randf_range(-0.4, 0.4), 0)
				if randf() < 0.3:
					Audio.sfx("tick", null, -16.0, randf_range(1.2, 1.6))
		var bd := p - Vector2(_bump_x, 4.2)
		if bd.length() < BR + 0.42:
			var n2 := bd.normalized()
			p = Vector2(_bump_x, 4.2) + n2 * (BR + 0.42)
			v = n2 * maxf(v.length(), 5.0)
			Audio.sfx("boing", null, -8.0, 1.3)
		# Fachtrenner
		var sw := W * 2.0 / SLOT_VAL.size()
		if p.y < 1.0:
			for k in range(1, SLOT_VAL.size()):
				var wx := -W + sw * k
				if absf(p.x - wx) < BR + 0.04:
					p.x = wx + signf(p.x - wx) * (BR + 0.04)
					v.x *= -0.4
		if p.y <= BR:
			p.y = BR
			b.done = true
			var k2 := clampi(int((p.x + W) / sw), 0, SLOT_VAL.size() - 1)
			var val: int = SLOT_VAL[k2]
			add_score(int(b.slot), float(val), _board.position + Vector3(p.x, 1.6, 0.4))
			Audio.sfx("coin_chime" if val >= 10 else "coin", null, -2.0)
			FX.sparks(_board.position + Vector3(p.x, 0.4, 0.3), Color(1, 0.9, 0.4), 12 if val >= 10 else 6)
			if val >= 10:
				Juice.shake(0.2)
				(avatars[int(b.slot)] as PartyAvatar).rig.react("victory")
		b.pos = p
		b.vel = v
		(b.node as Node3D).position = Vector3(p.x, p.y, 0.08)


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	var bs := []
	for b in _balls:
		bs.append([snappedf((b.pos as Vector2).x, 0.01), snappedf((b.pos as Vector2).y, 0.01), int(b.slot), 1 if bool(b.done) else 0])
		# (Alter nur auf dem Host relevant)
	d["pd"] = [_drop_x.map(func(x: float) -> float: return snappedf(x, 0.01)), _left.duplicate(), bs, snappedf(_over_t, 0.1)]
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var e: Array = d.get("pd", [])
	if e.size() < 4:
		return
	for i in 4:
		_drop_x[i] = float(e[0][i])
		_left[i] = int(e[1][i])
		_droppers[i].position = _board.position + Vector3(_drop_x[i], TOP + 0.3, 0.05)
	var bs: Array = e[2]
	while _balls.size() < bs.size():
		var nb: Array = bs[_balls.size()]
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = BR
		sm.height = BR * 2.0
		mi.mesh = sm
		mi.material_override = WorldKit.mat(Game.player_color(int(nb[2])).lightened(0.2), 0.2, 0.3)
		_board.add_child(mi)
		_balls.append({"pos": Vector2.ZERO, "vel": Vector2.ZERO, "slot": int(nb[2]), "node": mi, "done": false, "age": 0.0})
		Audio.sfx("plop", null, -4.0, 1.3)
	for k in bs.size():
		var be: Array = bs[k]
		var was := bool(_balls[k].done)
		_balls[k].pos = Vector2(float(be[0]), float(be[1]))
		_balls[k].done = int(be[3]) == 1
		(_balls[k].node as Node3D).position = Vector3(float(be[0]), float(be[1]), 0.08)
		if bool(_balls[k].done) and not was:
			Audio.sfx("coin", null, -2.0)
	_over_t = float(e[3])
	var tt := time_limit - time_left
	_bump_x = sin(tt * 0.9) * (W - 1.0)
	_bumper.position = Vector3(_bump_x, 4.2, 0)


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var level: int = Game.players[slot].cpu_level
	var mem: Dictionary = cpu_mem[slot]
	if _left[slot] <= 0:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	if not mem.has("aim"):
		# Mitte (10er-Fach) mit Streuung; Anfänger zielen manchmal einfach irgendwohin
		mem["aim"] = randf_range(-W + 0.5, W - 0.5) if randf() < [0.35, 0.15, 0.05][level] else randf_range(-1, 1) * [0.9, 0.5, 0.25][level]
		mem["wait"] = randf_range(0.3, 1.4)
	var to := float(mem.aim) - _drop_x[slot]
	var held := {}
	mem.wait = float(mem.wait) - 1.0 / 60.0
	if absf(to) < 0.08 and float(mem.wait) <= 0.0:
		held["a"] = true
		mem.erase("aim")
	InputHub.set_virtual(slot, Vector2(clampf(to * 3.0, -1.0, 1.0), 0), held)
