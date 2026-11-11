extends MinigameBase
## Tretboot-Rennen (2 gegen 2): Jedes Team sitzt in einem Tretboot. Beide treten im Wechsel A/B (gleiche
## Taste zweimal = Leerlauf) – je gleichmäßiger, desto schneller. Gelenkt wird gemeinsam: Die Stick-Ausschläge
## beider Fahrer werden gemittelt. Drei Runden durch alle Bojen-Tore; Rempeln erlaubt.
## Online: Host-Modell.

const LAPS := 3
const GATES := [Vector3(0, 0, -9), Vector3(10, 0, -5), Vector3(12, 0, 4), Vector3(3, 0, 9), Vector3(-8, 0, 7), Vector3(-12, 0, -2)]
const BOAT_R := 1.3

var _boats: Array[Dictionary] = []   # je Team: {node, pos, head, speed, crew, gate, lap, last:{slot:btn}, done}
var _gate_nodes: Array[Node3D] = []
var _wake_t := 0.0


func _init() -> void:
	game_id = "pedal_boat"
	env_preset = "day"
	backdrop_style = "meadow"
	time_limit = 60.0
	race = true
	score_format = "%d Tore"
	arena_radius = 13.0
	teaser_height = 1.0
	cannon_pos = Vector3(-4, 0, 12)
	net_model = "host"
	spawn_points = [Vector3(-3, 0.6, -10), Vector3(-3, 0.6, -7.5), Vector3(-4, 0.6, -10), Vector3(-4, 0.6, -7.5)]


func build_arena() -> void:
	WorldKit.water(world, Vector2(90, 90), -0.35, Color(0.12, 0.42, 0.55), Color(0.4, 0.75, 0.8))
	# Seeufer ringsum mit Schilf, Seerosen, Steg und Bäumen
	for i in 20:
		var a := TAU * i / 20.0
		var p := Vector3(cos(a) * 19.0, -0.8, sin(a) * 15.0)
		WorldKit.box(world, Vector3(7, 1.4, 7), p, Color("#7cc85a"), false).rotation.y = a
		WorldKit.place(world, ["nat/tree_oak", "nat/tree_pine", "nat/bush", "mt/cattail"][i % 4], p + Vector3(0, 0.7, 0), randf() * 360.0, [2.4, 2.4, 2.4, 2.0][i % 4])
	WorldKit.scatter(world, ["qn/lilypad", "mt/cattail", "mt/cattail_b"], 24, Vector3.ZERO, 13.5, 16.0, -0.3)
	WorldKit.place(world, "mt/dock", Vector3(-3.5, -0.4, -12.5), 0.0, 2.4)
	WorldKit.place(world, "mt/dock", Vector3(-3.5, -0.4, -14.8), 0.0, 2.4)
	for k in GATES.size():
		var g := Node3D.new()
		world.add_child(g)
		g.position = GATES[k]
		var nxt: Vector3 = GATES[(k + 1) % GATES.size()]
		var prv: Vector3 = GATES[(k - 1 + GATES.size()) % GATES.size()]
		var dir := (nxt - prv).normalized()
		var side := Vector3(-dir.z, 0, dir.x)
		for s in [-1.0, 1.0]:
			var b := Assets.spawn("water/buoy", g, side * s * 2.6 + Vector3(0, -0.35, 0), 0.0, 0.8)
			b.set_meta("bob", s)
		var flag := WorldKit.place(g, "qp/flag", Vector3(0, 1.4, 0), rad_to_deg(atan2(side.x, side.z)), 0.4)
		flag.visible = false
		_gate_nodes.append(g)
	for t in 2:
		var n := Assets.spawn("water/boat_row", world, Vector3(-3.0 - t * 2.8, -0.3, -10.5), 90.0, 2.0)
		WorldKit.box(n, Vector3(0.5, 0.5, 0.06), Vector3(0, 0.9, -0.9), Color("#ff4d6d") if t == 0 else Color("#4da6ff"), false)
		_boats.append({"node": n, "pos": Vector3(-3.0 - t * 2.8, 0, -10.5), "head": PI / 2.0, "speed": 0.0, "crew": [], "gate": 0, "lap": 0,
			"last": {}, "done": false})


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, 0)
	c.offset = Vector3(0, 19.0, 15.0)
	c.center_weight = 0.6
	c.min_dist = 0.9
	c.max_dist = 1.15


func on_start() -> void:
	for i in active_slots():
		var t := teams[i]
		if t < 2:
			_boats[t].crew.append(i)
		var av := avatars[i] as PartyAvatar
		av.freeze(true)
		av.can_shove = false
		av.set_physics_process(false)
		av.rig.play("sit_chair", 0.1)
		av.rig.scale *= 0.8
	_highlight()


## Sobald das erste Boot im Ziel ist, ist das Rennen entschieden
func check_end() -> bool:
	for bt in _boats:
		if bool(bt.done):
			return true
	return false


func on_tick(delta: float) -> void:
	for t in 2:
		_drive(t, delta)
	_collide()
	var tt := time_limit - time_left
	for g in _gate_nodes:
		for b in g.get_children():
			if b.has_meta("bob"):
				(b as Node3D).position.y = -0.35 + sin(tt * 2.0 + float(b.get_meta("bob"))) * 0.08


func _drive(t: int, delta: float) -> void:
	var bt: Dictionary = _boats[t]
	var crew: Array = bt.crew
	if crew.is_empty() or bool(bt.done):
		bt.speed = float(bt.speed) * (1.0 - delta)
		_place_boat(bt)
		return
	var steer := 0.0
	var last: Dictionary = bt.last
	for s in crew:
		steer += InputHub.move(int(s)).x / crew.size()
		var btn := ""
		if InputHub.pressed(int(s), "a"):
			btn = "a"
		elif InputHub.pressed(int(s), "b"):
			btn = "b"
		if btn != "":
			if String(last.get(s, "")) != btn:
				bt.speed = minf(float(bt.speed) + 0.55, 7.5)
				(avatars[int(s)] as PartyAvatar).rig.hop(0.08, 0.12)
				if randf() < 0.3:
					Audio.sfx("splash", bt.pos as Vector3, -16.0, 1.4)
			else:
				Audio.sfx("metal_light", bt.pos as Vector3, -14.0, 0.7)   # Leerlauf
			last[s] = btn
	bt.speed = maxf(0.0, float(bt.speed) - (1.6 + float(bt.speed) * 0.18) * delta)
	bt.head = float(bt.head) - steer * (1.1 + float(bt.speed) * 0.12) * delta
	var dir := Vector3(sin(float(bt.head)), 0, cos(float(bt.head)))
	var p: Vector3 = (bt.pos as Vector3) + dir * float(bt.speed) * delta
	# Ufer: weiches Zurückschieben
	var e := Vector2(p.x / 15.5, p.z / 11.8)
	if e.length() > 1.0:
		p = Vector3(p.x / e.length(), 0, p.z / e.length())
		bt.speed = float(bt.speed) * 0.85
	bt.pos = p
	_place_boat(bt)
	# Tore
	var g: Vector3 = GATES[int(bt.gate)]
	if p.distance_to(g) < 3.0:
		bt.gate = (int(bt.gate) + 1) % GATES.size()
		for s in crew:
			add_score(int(s), 1.0)
		Audio.sfx("chime", g, -4.0)
		FX.ring(g + Vector3.UP * 0.2, Color(1, 0.9, 0.4), 3.0, 0.4)
		if int(bt.gate) == 1:
			bt.lap = int(bt.lap) + 1
			if int(bt.lap) > LAPS:
				bt.done = true
				for s in crew:
					finish_player(int(s))
			elif int(bt.lap) == LAPS:
				Juice.float_text(self, p + Vector3.UP * 2.5, "Letzte Runde!", Color("#ffd166"), 70)
		_highlight()
	_wake_t -= delta
	if float(bt.speed) > 2.0 and _wake_t <= 0.0:
		_wake_t = 0.08
		FX.splash(p - dir * 1.6 + Vector3(0, 0.1, 0), 0.3)


func _place_boat(bt: Dictionary) -> void:
	var n: Node3D = bt.node
	var tt := time_limit - time_left
	n.position = (bt.pos as Vector3) + Vector3(0, -0.3 + sin(tt * 3.0) * 0.04, 0)
	n.rotation.y = float(bt.head)
	n.rotation.z = sin(tt * 2.2) * 0.03
	var dir := Vector3(sin(float(bt.head)), 0, cos(float(bt.head)))
	var crew: Array = bt.crew
	for k in crew.size():
		var av := avatars[int(crew[k])] as PartyAvatar
		av.global_position = n.position + dir * (0.45 - k * 0.9) + Vector3.UP * 0.35
		av.rig.rotation.y = float(bt.head)


func _collide() -> void:
	var a: Dictionary = _boats[0]
	var b: Dictionary = _boats[1]
	var d: Vector3 = (b.pos as Vector3) - (a.pos as Vector3)
	if d.length() < BOAT_R * 2.0 and d.length() > 0.01:
		var n := d.normalized()
		var push := (BOAT_R * 2.0 - d.length()) * 0.5
		a.pos = (a.pos as Vector3) - n * push
		b.pos = (b.pos as Vector3) + n * push
		if randf() < 0.2:
			Audio.sfx("wood_hit", (a.pos as Vector3) + n * BOAT_R, -6.0)


## Nächstes Tor des führenden Teams markieren (Fähnchen), damit klar ist, wohin es geht
func _highlight() -> void:
	for k in _gate_nodes.size():
		var on := false
		for bt in _boats:
			if int(bt.gate) == k and not bool(bt.done):
				on = true
		for c in _gate_nodes[k].get_children():
			if not c.has_meta("bob"):
				(c as Node3D).visible = on


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	d["bt"] = _boats.map(func(bt: Dictionary) -> Array: return [snappedf((bt.pos as Vector3).x, 0.01), snappedf((bt.pos as Vector3).z, 0.01), snappedf(float(bt.head), 0.01), int(bt.gate), snappedf(float(bt.speed), 0.1)])
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var bs: Array = d.get("bt", [])
	var changed := false
	for t in mini(2, bs.size()):
		var e: Array = bs[t]
		_boats[t].pos = Vector3(float(e[0]), 0, float(e[1]))
		_boats[t].head = float(e[2])
		_boats[t].speed = float(e[4])
		if int(e[3]) != int(_boats[t].gate):
			changed = true
			Audio.sfx("chime", GATES[int(_boats[t].gate)], -4.0)
		_boats[t].gate = int(e[3])
		(_boats[t].node as Node3D).position = (_boats[t].pos as Vector3) + Vector3(0, -0.3, 0)
		(_boats[t].node as Node3D).rotation.y = float(e[2])
	if changed:
		_highlight()


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var t := teams[slot]
	if t > 1 or _boats.is_empty():
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var bt: Dictionary = _boats[t]
	var mem: Dictionary = cpu_mem[slot]
	var p: Vector3 = bt.pos
	var g: Vector3 = GATES[int(bt.gate)]
	var to := g - p
	var want := atan2(to.x, to.z)
	var diff := wrapf(want - float(bt.head), -PI, PI)
	var mv := Vector2(clampf(-diff * Game.lv([1.2, 1.8, 2.4], level), -1.0, 1.0), 0)
	# Treten im Wechsel mit menschlichem Tempo
	mem["acc"] = float(mem.get("acc", 0.0)) + Game.lv([4.5, 6.0, 7.5], level) / 60.0
	var held := {}
	if float(mem.acc) >= 1.0:
		mem.acc = float(mem.acc) - 1.0
		var nxt := "b" if String(mem.get("last", "b")) == "a" else "a"
		if randf() < Game.lv([0.12, 0.05, 0.01], level, true):
			nxt = String(mem.get("last", "a"))
		mem["last"] = nxt
		held[nxt] = true
	InputHub.set_virtual(slot, mv, held)
