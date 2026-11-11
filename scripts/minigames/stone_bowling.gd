extends MinigameBase
## Steinkopf-Kegeln (Duell): Am Ende der Bahn drehen sich sechs grimmige Steinköpfe auf einer Scheibe.
## Abwechselnd hat jeder drei Würfe: Der Zielpfeil pendelt – A legt die Richtung fest, dann pendelt die
## Kraftanzeige – A wirft. Umgefallene Köpfe zählen; alle sechs = Abräumer (+3 Bonus).
## Online: Host-Modell (Host rollt Kugel und Köpfe).

const LANE_Z := 7.0
const PIN_C := Vector3(0, 0, -6.0)
const PIN_R := 0.42
const BALL_R := 0.55
const THROWS := 3

var _duel: Array[int] = []
var _turn := 0
var _phase := "aim"      # aim | power | roll | settle
var _aim := 0.0
var _aim_dir := 1.0
var _power := 0.0
var _pow_dir := 1.0
var _ball := Vector3.ZERO
var _bvel := Vector3.ZERO
var _ball_node: Node3D
var _arrow: Node3D
var _meter: Node3D
var _meter_fill: Node3D
var _pins: Array[Dictionary] = []   # {node, off (Vector2 relativ), pos, vel, down}
var _spin := 0.0
var _t := 0.0
var _prev_a: Array[bool] = [false, false, false, false]


func _init() -> void:
	game_id = "stone_bowling"
	env_preset = "sunset"
	backdrop_style = "meadow"
	time_limit = 80.0
	score_format = "%d Köpfe"
	arena_radius = 8.0
	teaser_height = 1.0
	cannon_pos = Vector3(5, 0, 9)
	net_model = "host"
	spawn_points = [Vector3(-1.2, 0.6, LANE_Z + 1.2), Vector3(1.2, 0.6, LANE_Z + 1.2), Vector3(-5, 0.6, 8), Vector3(5, 0.6, 8)]


func build_arena() -> void:
	# Tempelbahn: Steinplatten, Fackeln, Säulen, Drehscheibe mit Rillen
	WorldKit.box(world, Vector3(5.0, 0.4, 18), Vector3(0, -0.2, 0.5), Color("#cbb89a"))
	for z in range(-7, 9, 2):
		WorldKit.box(world, Vector3(4.8, 0.02, 0.06), Vector3(0, 0.01, z), Color("#9c8a6c"), false)
	for side in [-1.0, 1.0]:
		WorldKit.box(world, Vector3(0.35, 0.5, 18), Vector3(side * 2.65, 0.25, 0.5), Color("#8a7a62"), false)
		for k in 4:
			WorldKit.place(world, "mt/ruin" if k % 2 else "mt/ruin_b", Vector3(side * 3.8, 0, -6.0 + k * 4.0), randf() * 360.0, 1.6)
			WorldKit.torch_light(world, Vector3(side * 3.2, 1.6, -5.0 + k * 4.0))
	var disc := WorldKit.cylinder(world, 2.1, 0.12, PIN_C + Vector3(0, 0.06, 0), Color("#a08868"), false)
	disc.name = "Disc"
	MgKit.ring(world, 2.0, 0.08, Color("#6b5a44"), 0.0).position = PIN_C + Vector3(0, 0.13, 0)
	WorldKit.scatter(world, ["nat/rock_large", "nat/bush", "mt/stalagmite_s", "qn/rock_moss"], 14, Vector3(0, 0, 0), 5.5, 10.0, 0.0)
	_ball_node = Node3D.new()
	world.add_child(_ball_node)
	var bm := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = BALL_R
	sm.height = BALL_R * 2.0
	bm.mesh = sm
	bm.material_override = WorldKit.mat(Color("#3d6fd6"), 0.3, 0.15)
	_ball_node.add_child(bm)
	_arrow = Node3D.new()
	world.add_child(_arrow)
	WorldKit.box(_arrow, Vector3(0.18, 0.05, 2.4), Vector3(0, 0.05, -1.4), Color(1, 0.85, 0.3), false)
	_meter = Node3D.new()
	world.add_child(_meter)
	_meter.position = Vector3(2.0, 0.5, LANE_Z + 0.5)
	WorldKit.box(_meter, Vector3(0.3, 1.6, 0.1), Vector3(0, 0.8, 0), Color("#2b2236"), false)
	_meter_fill = WorldKit.box(_meter, Vector3(0.22, 1.0, 0.12), Vector3(0, 0, 0.01), Color("#ff9f43"), false)
	for k in 6:
		var node := Node3D.new()
		world.add_child(node)
		WorldKit.cylinder(node, PIN_R, 1.1, Vector3(0, 0.55, 0), Color("#9a9aa6"), false)
		WorldKit.box(node, Vector3(0.5, 0.12, 0.05), Vector3(0, 0.75, PIN_R - 0.02), Color("#2a2a33"), false)   # grimmige Brauen
		for s in [-1.0, 1.0]:
			WorldKit.cylinder(node, 0.07, 0.05, Vector3(s * 0.14, 0.62, PIN_R - 0.01), Color("#ffe066"), false).rotation.x = PI / 2.0
		_pins.append({"node": node, "off": Vector2.ZERO, "pos": Vector2.ZERO, "vel": Vector2.ZERO, "down": false, "tilt": 0.0})


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0.5, 0.5)
	c.offset = Vector3(0, 10.0, 11.5)
	c.min_dist = 1.0
	c.max_dist = 1.0


func on_start() -> void:
	_duel = active_slots()
	for k in _duel.size():
		var av := avatars[_duel[k]] as PartyAvatar
		av.can_move = false
		av.can_jump = false
		av.can_shove = false
		av.global_position = Vector3(-1.2 + k * 2.4, 0.0, LANE_Z + 1.4)
		av.rig.face_now(Vector3.FORWARD)
	_reset_pins()
	_begin_throw()


func check_end() -> bool:
	return _turn >= THROWS * maxi(_duel.size(), 1)


func _thrower() -> int:
	return _duel[_turn % _duel.size()] if not _duel.is_empty() else 0


func _reset_pins() -> void:
	var offs := [Vector2(0, -0.8), Vector2(-0.55, 0.1), Vector2(0.55, 0.1), Vector2(-1.1, 1.0), Vector2(0, 1.0), Vector2(1.1, 1.0)]
	for k in 6:
		var p := _pins[k]
		p.off = offs[k]
		p.pos = offs[k]
		p.vel = Vector2.ZERO
		p.down = false
		p.tilt = 0.0


func _begin_throw() -> void:
	_phase = "aim"
	_aim = 0.0
	_power = 0.0
	_t = 0.0
	_reset_pins()
	_ball = Vector3(0, BALL_R, LANE_Z)
	_bvel = Vector3.ZERO
	var s := _thrower()
	Juice.float_text(self, (avatars[s] as PartyAvatar).global_position + Vector3.UP * 2.3, "Wurf %d" % (_turn / maxi(_duel.size(), 1) + 1), Game.player_color(s).lightened(0.3), 56)


func on_tick(delta: float) -> void:
	_t += delta
	_spin += delta * 0.9
	var s := _thrower()
	var a_now := InputHub.held(s, "a")
	var a_edge := a_now and not _prev_a[s]
	_prev_a[s] = a_now
	match _phase:
		"aim":
			_aim += _aim_dir * delta * 0.9
			if absf(_aim) > 0.38:
				_aim_dir = -signf(_aim)
			if a_edge and _t > 0.3:
				_phase = "power"
				_t = 0.0
				Audio.sfx("click")
		"power":
			_power += _pow_dir * delta * 1.4
			if _power > 1.0 or _power < 0.0:
				_pow_dir = -_pow_dir
				_power = clampf(_power, 0.0, 1.0)
			if a_edge and _t > 0.15:
				_phase = "roll"
				_t = 0.0
				var spd := lerpf(7.0, 16.0, _power)
				_bvel = Vector3(sin(_aim), 0, -cos(_aim)) * spd
				(avatars[s] as PartyAvatar).rig.play_once("throw", "idle", 1.4)
				Audio.sfx("whoosh", _ball)
		"roll":
			_ball += _bvel * delta
			_bvel *= 1.0 - 0.15 * delta
			if absf(_ball.x) > 2.2:
				_ball.x = signf(_ball.x) * 2.2
				_bvel.x *= -0.4
				Audio.sfx("stone_hit", _ball, -8.0)
			_collide(delta)
			if _ball.z < PIN_C.z - 3.0 or _bvel.length() < 0.6 or _t > 5.0:
				_phase = "settle"
				_t = 0.0
		"settle":
			_collide(delta)
			if _t > 1.4:
				_score_throw()
				_turn += 1
				if _turn < THROWS * _duel.size():
					_begin_throw()
	_update_pins(delta)
	_draw()


func _collide(_delta: float) -> void:
	var b2 := Vector2(_ball.x, _ball.z)
	for p in _pins:
		var wp: Vector2 = _pin_world(p)
		var d := wp - b2
		if not bool(p.down) and d.length() < PIN_R + BALL_R and _phase == "roll":
			var n := d.normalized()
			p.vel = n * maxf(_bvel.length() * 0.7, 3.0)
			p.down = true
			_bvel = Vector3(_bvel.x - n.x * 1.5, 0, _bvel.z - n.y * 1.5) * 0.85
			Audio.sfx("stone_hit", Vector3(wp.x, 0.5, wp.y))
			FX.dust(Vector3(wp.x, 0.4, wp.y), Color(0.75, 0.7, 0.6), 8, 0.8)
			Juice.shake(0.12)
	# Fallende Köpfe reißen andere mit
	for p in _pins:
		if not bool(p.down) or (p.vel as Vector2).length() < 2.6:
			continue
		var wp2: Vector2 = _pin_world(p)
		for q in _pins:
			if bool(q.down):
				continue
			var d2: Vector2 = _pin_world(q) - wp2
			if d2.length() < PIN_R * 1.95 and randf() < 0.75:
				q.down = true
				q.vel = d2.normalized() * (p.vel as Vector2).length() * 0.45
				Audio.sfx("stone_hit", Vector3(wp2.x, 0.5, wp2.y), -4.0, 1.2)


func _pin_world(p: Dictionary) -> Vector2:
	if bool(p.down):
		return p.pos
	var o: Vector2 = (p.off as Vector2).rotated(_spin)
	return Vector2(PIN_C.x, PIN_C.z) + o


func _update_pins(delta: float) -> void:
	for p in _pins:
		if bool(p.down):
			if (p.pos as Vector2) == (p.off as Vector2):
				p.pos = Vector2(PIN_C.x, PIN_C.z) + (p.off as Vector2).rotated(_spin)
			p.pos = (p.pos as Vector2) + (p.vel as Vector2) * delta
			p.vel = (p.vel as Vector2) * (1.0 - 3.0 * delta)
			p.tilt = minf(float(p.tilt) + delta * 6.0, PI / 2.0)


func _score_throw() -> void:
	var n := 0
	for p in _pins:
		if bool(p.down):
			n += 1
	var s := _thrower()
	var av := avatars[s] as PartyAvatar
	if n > 0:
		add_score(s, float(n + (3 if n == 6 else 0)), av.global_position + Vector3.UP * 2.4)
	if n == 6:
		CutsceneManager.big_word("Abräumer!", Color("#ffd166"), 0.8)
		Audio.jingle("fanfare", false)
		av.rig.react("victory")
	elif n >= 3:
		av.rig.react("cheer")
	else:
		av.rig.react("sad")


func _draw() -> void:
	_ball_node.position = _ball
	_ball_node.rotation.x -= _bvel.z * 0.02
	_arrow.visible = _phase == "aim" or _phase == "power"
	_arrow.position = Vector3(_ball.x, 0.02, _ball.z)
	_arrow.rotation.y = -_aim
	_meter.visible = _phase == "power"
	_meter_fill.scale = Vector3(1, maxf(_power * 1.6, 0.01), 1)
	_meter_fill.position.y = _power * 0.8
	var disc := world.get_node_or_null("Disc") as Node3D
	if disc:
		disc.rotation.y = -_spin
	for p in _pins:
		var wp: Vector2 = _pin_world(p)
		var node: Node3D = p.node
		node.position = Vector3(wp.x, 0.12, wp.y)
		node.rotation = Vector3(float(p.tilt), -_spin if not bool(p.down) else node.rotation.y, 0)


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	var pins := []
	for p in _pins:
		pins.append_array([snappedf((p.pos as Vector2).x, 0.01), snappedf((p.pos as Vector2).y, 0.01), 1 if bool(p.down) else 0, snappedf(float(p.tilt), 0.05)])
	d["sb"] = [snappedf(_ball.x, 0.01), snappedf(_ball.z, 0.01), snappedf(_aim, 0.01), snappedf(_power, 0.01), ["aim", "power", "roll", "settle"].find(_phase), snappedf(_spin, 0.01), _turn, pins]
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var e: Array = d.get("sb", [])
	if e.size() < 8:
		return
	var nb := Vector3(float(e[0]), BALL_R, float(e[1]))
	_bvel = (nb - _ball) * 30.0
	_ball = nb
	_aim = float(e[2])
	_power = float(e[3])
	_phase = ["aim", "power", "roll", "settle"][int(e[4])]
	_spin = float(e[5])
	_turn = int(e[6])
	var pins: Array = e[7]
	for k in mini(6, pins.size() / 4):
		var was := bool(_pins[k].down)
		_pins[k].pos = Vector2(float(pins[k * 4]), float(pins[k * 4 + 1]))
		_pins[k].down = int(pins[k * 4 + 2]) == 1
		_pins[k].tilt = float(pins[k * 4 + 3])
		if bool(_pins[k].down) and not was:
			Audio.sfx("stone_hit", Vector3(float(pins[k * 4]), 0.5, float(pins[k * 4 + 1])))
	_draw()


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	if slot != _thrower():
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var mem: Dictionary = cpu_mem[slot]
	var held := {}
	match _phase:
		"aim":
			if not mem.has("want"):
				# Ziel: Mitte der Köpfe zum Ankunftszeitpunkt (Drehung vorhersagen), mit Fehler je Stufe
				var t_arr := (LANE_Z - PIN_C.z) / 13.0
				var c := Vector2(0, 0.35).rotated(_spin + t_arr * 0.9)
				var tx: float = c.x + randf_range(-1.0, 1.0) * float(Game.lv([0.9, 0.45, 0.15], level, true))
				mem["want"] = atan2(tx, LANE_Z - PIN_C.z)
			if absf(_aim - float(mem.want)) < 0.03 and _t > 0.3:
				held["a"] = true
				mem.erase("want")
		"power":
			if not mem.has("pw"):
				mem["pw"] = clampf(0.75 + randf_range(-1, 1) * Game.lv([0.3, 0.15, 0.05], level, true), 0.2, 1.0)
			if absf(_power - float(mem.pw)) < 0.04 and _pow_dir > 0.0 and _t > 0.15:
				held["a"] = true
				mem.erase("pw")
	InputHub.set_virtual(slot, Vector2.ZERO, held)
