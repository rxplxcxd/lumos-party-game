extends MinigameBase
## Murmel-Labyrinth (Duell): Jeder hat ein eigenes Holzlabyrinth mit drei Murmeln. Stick = Brett kippen –
## die Murmeln rollen, prallen an Wänden ab und stoßen sich gegenseitig. Ins grüne Zielloch = versenkt,
## in ein schwarzes Fallenloch = zurück zum Start. Wer zuerst alle drei versenkt, gewinnt.
## Online: Host-Modell (Host rollt beide Bretter).

const HALF := 3.0
const MR := 0.24
const BX := [-4.3, 4.3]
const WALLS := [Rect2(-3.0, -1.1, 4.0, 0.22), Rect2(-1.0, 0.88, 4.0, 0.22), Rect2(0.6, 1.1, 0.22, 0.85)]
const START := Vector2(-2.3, -2.3)
const GOAL := Vector2(2.3, 2.35)
const TRAPS := [Vector2(2.35, -0.05), Vector2(-0.3, 0.5), Vector2(-2.35, 1.4)]
const WAY := [Vector2(-2.2, -2.0), Vector2(1.9, -2.0), Vector2(1.7, -0.25), Vector2(-0.4, -0.4), Vector2(-2.0, -0.1), Vector2(-1.7, 2.4), Vector2(0.0, 2.5), Vector2(1.4, 2.5), GOAL]

var _boards: Array[Dictionary] = []   # je Duellant: {slot, node, tilt, marbles:[{pos, vel, state, t, node}], sunk}
var _duel: Array[int] = []


func _init() -> void:
	game_id = "marble_maze"
	env_preset = "day"
	backdrop_style = "meadow"
	time_limit = 60.0
	score_format = "%d/3"
	arena_radius = 7.0
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 8)
	net_model = "host"
	spawn_points = [Vector3(BX[0], 0.6, 4.4), Vector3(BX[1], 0.6, 4.4), Vector3(-7, 0.6, 5), Vector3(7, 0.6, 5)]


func build_arena() -> void:
	WorldKit.box(world, Vector3(18, 0.4, 13), Vector3(0, -0.2, 0.5), Color("#c49a6c"))
	for k in 2:
		var holder := Node3D.new()
		world.add_child(holder)
		holder.position = Vector3(BX[k], 1.0, 0)
		WorldKit.box(world, Vector3(0.6, 1.0, 0.6), Vector3(BX[k], 0.5, 0), Color("#7a4f2a"), false)
		var board := Node3D.new()
		holder.add_child(board)
		WorldKit.box(board, Vector3(HALF * 2 + 0.4, 0.2, HALF * 2 + 0.4), Vector3(0, -0.1, 0), Color("#e3b77d"), false)
		for e in [Rect2(-HALF - 0.2, -HALF - 0.2, HALF * 2 + 0.4, 0.2), Rect2(-HALF - 0.2, HALF, HALF * 2 + 0.4, 0.2), Rect2(-HALF - 0.2, -HALF, 0.2, HALF * 2), Rect2(HALF, -HALF, 0.2, HALF * 2)]:
			_wall_mesh(board, e, Color("#8a5a34"))
		for w in WALLS:
			_wall_mesh(board, w, Color("#a4703f"))
		var g := MgKit.ring(board, 0.36, 0.08, Color(0.3, 1.0, 0.45), 1.4)
		g.position = Vector3(GOAL.x, 0.01, GOAL.y)
		WorldKit.cylinder(board, 0.32, 0.02, Vector3(GOAL.x, 0.005, GOAL.y), Color("#1d3b1d"), false)
		for t in TRAPS:
			WorldKit.cylinder(board, 0.3, 0.02, Vector3(t.x, 0.005, t.y), Color("#14101a"), false)
			MgKit.ring(board, 0.33, 0.05, Color(0.9, 0.2, 0.3), 0.6).position = Vector3(t.x, 0.01, t.y)
		var st := MgKit.ring(board, 0.5, 0.05, Color(1, 1, 1, 0.6), 0.3)
		st.position = Vector3(START.x, 0.01, START.y)
		var marbles: Array = []
		for m in 3:
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = MR
			sm.height = MR * 2.0
			mi.mesh = sm
			var mat := WorldKit.mat([Color("#ff5d73"), Color("#4dc3ff"), Color("#ffd23f")][m], 0.1, 0.25)
			mat.metallic = 0.4
			mi.material_override = mat
			board.add_child(mi)
			marbles.append({"pos": START + Vector2(m * 0.5, 0), "vel": Vector2.ZERO, "state": 0, "t": 0.0, "node": mi})
		_boards.append({"slot": -1, "node": board, "tilt": Vector2.ZERO, "marbles": marbles, "sunk": 0})
	WorldKit.scatter(world, ["plat/flowers", "nat/bush", "qp/bush_fruit", "nat/tree_oak"], 12, Vector3.ZERO, 9.5, 14.0, 0.0)


func _wall_mesh(board: Node3D, r: Rect2, col: Color) -> void:
	WorldKit.box(board, Vector3(r.size.x, 0.35, r.size.y), Vector3(r.get_center().x, 0.17, r.get_center().y), col, false)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 1.0, 0.8)
	c.offset = Vector3(0, 11.5, 7.5)
	c.min_dist = 1.0
	c.max_dist = 1.0


func on_start() -> void:
	_duel = active_slots()
	for k in mini(2, _duel.size()):
		_boards[k].slot = _duel[k]
		var av := avatars[_duel[k]] as PartyAvatar
		av.can_move = false
		av.can_jump = false
		av.can_shove = false
		av.global_position = Vector3(BX[k], 0.0, 4.2)
		av.rig.face_now(Vector3.FORWARD)


func check_end() -> bool:
	for b in _boards:
		if int(b.sunk) >= 3:
			return true
	return false


func on_tick(delta: float) -> void:
	for b in _boards:
		if int(b.slot) < 0:
			continue
		var want := InputHub.move(int(b.slot))
		b.tilt = (b.tilt as Vector2).lerp(want, minf(1.0, delta * 8.0))
		_step(b, delta)
		_draw(b)


func _step(b: Dictionary, delta: float) -> void:
	var tilt: Vector2 = b.tilt
	var ms: Array = b.marbles
	for m in ms:
		if int(m.state) == 1:
			continue
		if int(m.state) == 2:
			m.t = float(m.t) - delta
			if float(m.t) <= 0.0:
				m.state = 0
				m.pos = START
				m.vel = Vector2.ZERO
			continue
		var v: Vector2 = m.vel
		v += tilt * 9.5 * delta
		v *= 1.0 - 0.9 * delta
		var p: Vector2 = (m.pos as Vector2) + v * delta
		# Rand
		if absf(p.x) > HALF - MR:
			p.x = signf(p.x) * (HALF - MR)
			v.x *= -0.45
		if absf(p.y) > HALF - MR:
			p.y = signf(p.y) * (HALF - MR)
			v.y *= -0.45
		# Innenwände (Kreis gegen Rechteck)
		for w in WALLS:
			var r: Rect2 = w
			var cl := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
			var off := p - cl
			if off.length() < MR and off.length() > 0.0001:
				var n := off.normalized()
				p = cl + n * MR
				v -= n * v.dot(n) * 1.45
				if absf(v.dot(n)) > 1.5:
					Audio.sfx("wood_hit", null, -18.0, 1.6)
		m.pos = p
		m.vel = v
		# Löcher
		if p.distance_to(GOAL) < 0.34 and v.length() < 6.0:
			m.state = 1
			b.sunk = int(b.sunk) + 1
			add_score(int(b.slot), 1.0)
			Audio.sfx("coin_chime", null, -2.0)
			FX.stars(_world_pos(b, GOAL) + Vector3.UP * 0.3, Color(0.5, 1.0, 0.6), 10)
			(avatars[int(b.slot)] as PartyAvatar).rig.react("cheer")
		else:
			for t in TRAPS:
				if p.distance_to(t) < 0.23:
					m.state = 2
					m.t = 0.6
					Audio.sfx("whistle_fall", null, -6.0, 1.4)
					(avatars[int(b.slot)] as PartyAvatar).rig.react("frustrated")
	# Murmeln stoßen sich
	for i in ms.size():
		for j in range(i + 1, ms.size()):
			if int(ms[i].state) != 0 or int(ms[j].state) != 0:
				continue
			var d: Vector2 = (ms[j].pos as Vector2) - (ms[i].pos as Vector2)
			if d.length() < MR * 2.0 and d.length() > 0.0001:
				var n2 := d.normalized()
				var push := (MR * 2.0 - d.length()) * 0.5
				ms[i].pos = (ms[i].pos as Vector2) - n2 * push
				ms[j].pos = (ms[j].pos as Vector2) + n2 * push
				var rel: float = ((ms[i].vel as Vector2) - (ms[j].vel as Vector2)).dot(n2)
				if rel > 0.0:
					ms[i].vel = (ms[i].vel as Vector2) - n2 * rel
					ms[j].vel = (ms[j].vel as Vector2) + n2 * rel


func _world_pos(b: Dictionary, p: Vector2) -> Vector3:
	return (b.node as Node3D).global_transform * Vector3(p.x, MR, p.y)


func _draw(b: Dictionary) -> void:
	var board: Node3D = b.node
	var tilt: Vector2 = b.tilt
	board.rotation = Vector3(tilt.y * 0.16, 0, -tilt.x * 0.16)
	for m in b.marbles:
		var mi: MeshInstance3D = m.node
		match int(m.state):
			0:
				mi.visible = true
				mi.position = Vector3((m.pos as Vector2).x, MR, (m.pos as Vector2).y)
				mi.rotation += Vector3((m.vel as Vector2).y, 0, -(m.vel as Vector2).x) * 0.05
			1:
				mi.visible = true
				mi.position = Vector3(GOAL.x, -0.05, GOAL.y)
			2:
				mi.visible = false


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	var out := []
	for b in _boards:
		var e := [snappedf((b.tilt as Vector2).x, 0.01), snappedf((b.tilt as Vector2).y, 0.01), int(b.sunk)]
		for m in b.marbles:
			e.append_array([snappedf((m.pos as Vector2).x, 0.01), snappedf((m.pos as Vector2).y, 0.01), int(m.state)])
		out.append(e)
	d["mb"] = out
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var arr: Array = d.get("mb", [])
	for k in mini(arr.size(), _boards.size()):
		var e: Array = arr[k]
		var b := _boards[k]
		b.tilt = Vector2(float(e[0]), float(e[1]))
		if int(e[2]) > int(b.sunk):
			Audio.sfx("coin_chime", null, -2.0)
		b.sunk = int(e[2])
		for m in 3:
			var mm: Dictionary = b.marbles[m]
			var np := Vector2(float(e[3 + m * 3]), float(e[4 + m * 3]))
			mm.vel = (np - (mm.pos as Vector2)) * 30.0
			mm.pos = np
			mm.state = int(e[5 + m * 3])
		_draw(b)


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var k := -1
	for i in _boards.size():
		if int(_boards[i].slot) == slot:
			k = i
	if k < 0:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var b := _boards[k]
	var mem: Dictionary = cpu_mem[slot]
	# Führende Murmel (am weitesten im Weg) steuern; Wegpunkt-Index je Murmel merken
	if not mem.has("wp"):
		mem["wp"] = [0, 0, 0]
	var best := -1
	var best_wp := -1
	for m in 3:
		var mm: Dictionary = b.marbles[m]
		if int(mm.state) != 0:
			if int(mm.state) == 2:
				mem.wp[m] = 0
			continue
		var wi := int(mem.wp[m])
		while wi < WAY.size() - 1 and (mm.pos as Vector2).distance_to(WAY[wi]) < 0.55:
			wi += 1
		mem.wp[m] = wi
		# Die hinterste zuerst – so rollen die anderen nicht allein in die Fallen
		if best < 0 or wi < best_wp:
			best = m
			best_wp = wi
	if best < 0:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var mm2: Dictionary = b.marbles[best]
	var target: Vector2 = WAY[best_wp]
	var to: Vector2 = target - (mm2.pos as Vector2)
	var kp: float = Game.lv([0.8, 1.0, 1.2], level)
	var kd: float = Game.lv([0.35, 0.55, 0.75], level)
	var tilt := to * kp - (mm2.vel as Vector2) * kd
	# Alle Murmeln von den Fallen weghalten (Kippen wirkt auf alle gleichzeitig)
	for m in 3:
		var om: Dictionary = b.marbles[m]
		if int(om.state) != 0:
			continue
		for t in TRAPS:
			var away: Vector2 = (om.pos as Vector2) - (t as Vector2)
			if away.length() < 0.9:
				tilt += away.normalized() * (0.9 - away.length()) * Game.lv([0.6, 1.0, 1.4], level)
	tilt = tilt.limit_length(Game.lv([0.55, 0.7, 0.85], level))
	if randf() < Game.lv([0.05, 0.02, 0.0], level, true):
		tilt += Vector2(randf_range(-1, 1), randf_range(-1, 1))
	InputHub.set_virtual(slot, tilt.limit_length(1.0))
