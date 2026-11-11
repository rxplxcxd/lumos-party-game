extends MinigameBase
## Flitzestein-Wurf (jeder gegen jeden): Vom Strand aus lässt jeder auf seiner Bahn flache Steine über den See
## hüpfen. A gedrückt halten = Kraft (pendelt), Stick hoch/runter = Abwurfwinkel (flach hüpft öfter, zu steil
## versinkt sofort), loslassen = Wurf. Drei Würfe – es zählt die beste Weite. Bojen zeigen die Meter.
## Online: Host-Modell.

const LANE_X := [-4.5, -1.5, 1.5, 4.5]
const THROWS := 3
const G := 9.8

var _left: Array[int] = [THROWS, THROWS, THROWS, THROWS]
var _charging: Array[bool] = [false, false, false, false]
var _power: Array[float] = [0, 0, 0, 0]
var _pdir: Array[float] = [1, 1, 1, 1]
var _angle: Array[float] = [12, 12, 12, 12]
var _stones: Array[Dictionary] = []   # {slot, z, y, vz, vy, skips, node, done}
var _best: Array[float] = [0, 0, 0, 0]
var _idle: Array[float] = [0, 0, 0, 0]
var _bars: Array[Node3D] = []
var _over_t := -1.0


func _init() -> void:
	game_id = "stone_skip"
	env_preset = "day"
	backdrop_style = "beach"
	time_limit = 45.0
	score_format = "%d m"
	arena_radius = 12.0
	teaser_height = 1.0
	cannon_pos = Vector3(8, 0, 6)
	net_model = "host"
	spawn_points = [Vector3(LANE_X[0], 0.6, 2.0), Vector3(LANE_X[1], 0.6, 2.0), Vector3(LANE_X[2], 0.6, 2.0), Vector3(LANE_X[3], 0.6, 2.0)]


func build_arena() -> void:
	WorldKit.water(world, Vector2(120, 140), -0.05, Color(0.08, 0.4, 0.6), Color(0.35, 0.8, 0.9))
	WorldKit.box(world, Vector3(20, 0.6, 8), Vector3(0, -0.3, 5.5), Color("#f2d9a0"))
	# Weiten-Bojen alle 10 m mit Schildern
	for m in range(10, 70, 10):
		for x in [-6.2, 6.2]:
			Assets.spawn("water/buoy", world, Vector3(x, -0.2, -m + 1.5), 0.0, 0.7)
		var lb := Label3D.new()
		lb.text = "%d m" % m
		lb.font_size = 160
		lb.outline_size = 30
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.position = Vector3(6.8, 1.4, -m + 1.5)
		world.add_child(lb)
	for i in 4:
		WorldKit.box(world, Vector3(2.6, 0.02, 0.1), Vector3(LANE_X[i], 0.01, 1.4), Game.player_color(i), false)
		var bar := Node3D.new()
		world.add_child(bar)
		bar.position = Vector3(LANE_X[i] + 0.9, 0.4, 2.0)
		WorldKit.box(bar, Vector3(0.22, 1.4, 0.08), Vector3(0, 0.7, 0), Color("#2b2236"), false)
		WorldKit.box(bar, Vector3(0.16, 1.0, 0.1), Vector3(0, 0, 0.01), Game.player_color(i).lightened(0.3), false).name = "Fill"
		_bars.append(bar)
	WorldKit.scatter(world, ["mt/shell", "mt/shell_b", "mt/starfish", "mt/coconut"], 18, Vector3(0, 0, 6), 3.0, 9.0, 0.02)
	for i in 4:
		WorldKit.place(world, "pirate/palm", Vector3(-9.0 + i * 6.0, 0, 8.5), randf() * 360.0, 0.9)
	WorldKit.place(world, "mt/dock", Vector3(-8.5, -0.4, 0.0), 0.0, 2.4)
	WorldKit.place(world, "water/boat_sail", Vector3(-14.0, -0.3, -30.0), 30.0, 2.0)


func setup_camera(c: ArenaCamera) -> void:
	c.follow = false
	c.fixed_center = Vector3(0, 0, -6)
	c.offset = Vector3(0, 9.0, 13.0)
	c.min_dist = 1.0
	c.max_dist = 1.0
	c.smooth = 2.0


func on_start() -> void:
	for i in active_slots():
		var av := avatars[i] as PartyAvatar
		av.can_move = false
		av.can_jump = false
		av.can_shove = false
		av.rig.face_now(Vector3.FORWARD)


func check_end() -> bool:
	return _over_t > 1.6


func on_tick(delta: float) -> void:
	for i in active_slots():
		if _left[i] <= 0:
			continue
		_angle[i] = clampf(_angle[i] + InputHub.move(i).y * -22.0 * delta, 2.0, 35.0)
		var held := InputHub.held(i, "a")
		_idle[i] += delta
		if held:
			if not _charging[i]:
				_charging[i] = true
				_power[i] = 0.0
				_pdir[i] = 1.0
			_power[i] += _pdir[i] * delta * 1.2
			if _power[i] > 1.0 or _power[i] < 0.0:
				_pdir[i] = -_pdir[i]
				_power[i] = clampf(_power[i], 0.0, 1.0)
		elif _charging[i] or _idle[i] > 9.0:
			_charging[i] = false
			_throw(i)
	_step(delta)
	# Kamera folgt dem weitesten fliegenden Stein
	var far := 0.0
	for s in _stones:
		if not bool(s.done):
			far = maxf(far, float(s.z))
	if is_instance_valid(cam):
		cam.fixed_center = Vector3(0, 0, -6.0 - far * 0.75)
	var all_done := true
	for i in active_slots():
		if _left[i] > 0:
			all_done = false
	for s in _stones:
		if not bool(s.done):
			all_done = false
	if all_done:
		_over_t = maxf(_over_t, 0.0) + delta
	_draw()


func _throw(i: int) -> void:
	_left[i] -= 1
	_idle[i] = 0.0
	var spd := lerpf(8.0, 22.0, _power[i])
	var a := deg_to_rad(_angle[i])
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.12
	mi.mesh = sm
	mi.material_override = WorldKit.mat(Color("#9aa3b5").lerp(Game.player_color(i), 0.35), 0.6)
	world.add_child(mi)
	_stones.append({"slot": i, "z": 0.0, "y": 1.2, "vz": spd * cos(a), "vy": spd * sin(a), "skips": 0, "node": mi, "done": false})
	(avatars[i] as PartyAvatar).rig.play_once("throw", "idle", 1.5)
	Audio.sfx("whoosh", Vector3(LANE_X[i], 1, 1), -6.0)


func _step(delta: float) -> void:
	for s in _stones:
		if bool(s.done):
			continue
		s.vy = float(s.vy) - G * delta
		s.z = float(s.z) + float(s.vz) * delta
		s.y = float(s.y) + float(s.vy) * delta
		if float(s.y) <= 0.0:
			var inc := rad_to_deg(atan2(-float(s.vy), float(s.vz)))
			var pos := Vector3(LANE_X[int(s.slot)], 0.0, -float(s.z))
			if inc < 24.0 and float(s.vz) > 2.8:
				s.skips = int(s.skips) + 1
				s.vy = -float(s.vy) * 0.6 + 0.6
				s.vz = float(s.vz) * 0.82
				s.y = 0.01
				FX.ring(pos + Vector3.UP * 0.05, Color(1, 1, 1, 0.8), 0.9, 0.3)
				Audio.sfx("plop", pos, -6.0, 1.2 + int(s.skips) * 0.05)
			else:
				s.done = true
				FX.splash(pos + Vector3.UP * 0.1, 0.6)
				Audio.sfx("splash", pos, -4.0)
				var dist := float(s.z)
				var i := int(s.slot)
				if dist > _best[i]:
					var gain := floorf(dist) - scores[i]
					_best[i] = dist
					if gain > 0.0:
						add_score(i, gain, pos + Vector3.UP * 1.5)
				Juice.float_text(self, pos + Vector3.UP * 2.0, "%d m · %d×" % [int(dist), int(s.skips)], Game.player_color(i).lightened(0.35), 60)
				if int(s.skips) >= 8:
					(avatars[i] as PartyAvatar).rig.react("victory")


func _draw() -> void:
	for s in _stones:
		var n: MeshInstance3D = s.node
		n.position = Vector3(LANE_X[int(s.slot)], float(s.y) + 0.06, -float(s.z))
		n.rotation.y += 0.6
		n.visible = not bool(s.done)
	for i in 4:
		var fill := _bars[i].get_node("Fill") as Node3D
		var p := _power[i] if _charging[i] else 0.0
		fill.scale = Vector3(1, maxf(p * 1.4, 0.01), 1)
		fill.position.y = p * 0.7
		_bars[i].rotation.x = -deg_to_rad(_angle[i]) * 0.8


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	var st := []
	for s in _stones:
		st.append([int(s.slot), snappedf(float(s.z), 0.02), snappedf(float(s.y), 0.02), 1 if bool(s.done) else 0])
	d["sk"] = [_power.map(func(v: float) -> float: return snappedf(v, 0.02)), _charging.map(func(b: bool) -> int: return 1 if b else 0), _angle.map(func(v: float) -> float: return snappedf(v, 0.5)), st, snappedf(_over_t, 0.1)]
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var e: Array = d.get("sk", [])
	if e.size() < 5:
		return
	for i in 4:
		_power[i] = float(e[0][i])
		_charging[i] = int(e[1][i]) == 1
		_angle[i] = float(e[2][i])
	var st: Array = e[3]
	while _stones.size() < st.size():
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.22
		sm.height = 0.12
		mi.mesh = sm
		mi.material_override = WorldKit.mat(Color("#9aa3b5"), 0.6)
		world.add_child(mi)
		_stones.append({"slot": int(st[_stones.size()][0]), "z": 0.0, "y": 1.2, "vz": 0.0, "vy": 0.0, "skips": 0, "node": mi, "done": false})
	for k in st.size():
		var was := bool(_stones[k].done)
		_stones[k].z = float(st[k][1])
		_stones[k].y = float(st[k][2])
		_stones[k].done = int(st[k][3]) == 1
		if bool(_stones[k].done) and not was:
			FX.splash(Vector3(LANE_X[int(_stones[k].slot)], 0.1, -float(_stones[k].z)), 0.6)
	_over_t = float(e[4])
	var far := 0.0
	for s in _stones:
		if not bool(s.done):
			far = maxf(far, float(s.z))
	if is_instance_valid(cam):
		cam.fixed_center = Vector3(0, 0, -6.0 - far * 0.75)
	_draw()


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var level: int = Game.players[slot].cpu_level
	var mem: Dictionary = cpu_mem[slot]
	if _left[slot] <= 0:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	# Warten, bis der eigene Stein gelandet ist (wie ein Mensch, der zuschaut)
	for s in _stones:
		if int(s.slot) == slot and not bool(s.done):
			InputHub.set_virtual(slot, Vector2.ZERO)
			return
	if not mem.has("ang"):
		# Taktik: Am weitesten fliegt der Stein knapp unter ~20,5° mit voller Kraft – darüber versinkt er sofort.
		# Jede Stufe hält so viel Sicherheitsabstand zu dieser Kante, wie ihre eigene Streuung verlangt.
		var spread: float = Game.lv([9.0, 5.0, 2.0], level, true)
		var aim := clampf(20.2 - spread * 0.95, 8.0, 19.6)
		# Streuung wie bei Menschen: meist nah am Ziel, selten weit daneben (Dreiecksverteilung)
		mem["ang"] = clampf(aim + (randf_range(-1, 1) + randf_range(-1, 1)) * 0.5 * spread, 3.0, 30.0)
		var pn: float = Game.lv([0.3, 0.15, 0.06], level, true)
		mem["pw"] = clampf(1.0 - pn * 0.8 + (randf_range(-1, 1) + randf_range(-1, 1)) * 0.5 * pn, 0.3, 1.0)
	var mv := Vector2(0, clampf((_angle[slot] - float(mem.ang)) * 0.3, -1.0, 1.0))
	var held := {}
	if absf(_angle[slot] - float(mem.ang)) < 1.0:
		held["a"] = true
		if _charging[slot] and absf(_power[slot] - float(mem.pw)) < 0.03 and _pdir[slot] > 0.0:
			held.erase("a")
			mem.erase("ang")
	InputHub.set_virtual(slot, mv, held)
