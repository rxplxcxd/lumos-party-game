extends MinigameBase
## Strand-Volley (2 gegen 2): Ein Wasserball, ein Netz, zwei Teams. Wer den Ball berührt, baggert ihn
## automatisch in hohem Bogen hinüber; springen (A) und in der Luft B drücken = Schmetterball (flach und
## schnell). Landet der Ball im eigenen Feld, punktet das andere Team. Zuerst 7 Punkte oder die meisten
## Punkte nach Ablauf der Zeit.
## Online: Host-Modell.

const HALF_X := 8.0
const HALF_Z := 4.2
const NET_H := 2.3
const BALL_R := 0.45
const GRAV := 13.0
const WIN := 7

var _ball: Node3D
var _bpos := Vector3.ZERO
var _bvel := Vector3.ZERO
var _serve_t := 1.0
var _serve_side := 0
var _pts := [0, 0]
var _last_hit := -1
var _hit_cd: Array[float] = [0, 0, 0, 0]
var _shadow: MeshInstance3D
var _score_lbl: Label3D


func _init() -> void:
	game_id = "beach_volley"
	env_preset = "pirates"
	backdrop_style = "beach"
	time_limit = 60.0
	score_format = "%d"
	arena_radius = 9.0
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 9)
	net_model = "host"
	spawn_points = [Vector3(-4, 0.6, -1.5), Vector3(4, 0.6, -1.5), Vector3(-4, 0.6, 1.5), Vector3(4, 0.6, 1.5)]


func on_setup() -> void:
	var c := [0, 0]
	for i in 4:
		var t := teams[i]
		spawn_points[i] = Vector3(-4.5 if t == 0 else 4.5, 0.6, -1.6 + c[t] * 3.2)
		c[t] += 1


func build_arena() -> void:
	WorldKit.water(world, Vector2(80, 80), -0.6, Color(0.06, 0.4, 0.65), Color(0.3, 0.8, 0.9))
	WorldKit.box(world, Vector3(26, 1.0, 16), Vector3(0, -0.5, 0), Color("#f2d9a0"))
	# Spielfeldlinien, Netz mit Pfosten, unsichtbare Netzwand für Figuren
	for z in [-HALF_Z, HALF_Z]:
		WorldKit.box(world, Vector3(HALF_X * 2, 0.02, 0.12), Vector3(0, 0.01, z), Color("#ffffff"), false)
	for x in [-HALF_X, HALF_X]:
		WorldKit.box(world, Vector3(0.12, 0.02, HALF_Z * 2), Vector3(x, 0.01, 0), Color("#ffffff"), false)
	WorldKit.box(world, Vector3(0.1, 0.9, HALF_Z * 2 + 0.6), Vector3(0, NET_H - 0.45, 0), Color(1, 1, 1, 1), false)
	for k in 9:
		WorldKit.box(world, Vector3(0.06, 0.06, HALF_Z * 2 + 0.6), Vector3(0, NET_H - 0.9 + k * 0.11, 0), Color("#3a3a46"), false)
	for z in [-HALF_Z - 0.4, HALF_Z + 0.4]:
		WorldKit.cylinder(world, 0.1, NET_H + 0.2, Vector3(0, (NET_H + 0.2) * 0.5, z), Color("#d9d9e0"), false)
	# Unsichtbare Netzwand für Figuren (Kollision bleibt, Optik aus)
	var wall := WorldKit.box(world, Vector3(0.3, 4.0, HALF_Z * 2 + 1.0), Vector3(0, 2.0, 0), Color(0, 0, 0, 0))
	for m in wall.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).visible = false
	# Strandleben: Palmen, Liegestühle, Schirm, Muscheln, Kokosnüsse, Steg
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		WorldKit.place(world, "pirate/palm", Vector3(cos(a) * 12.0, 0, sin(a) * 8.0), randf() * 360.0, 0.9)
	WorldKit.scatter(world, ["mt/shell", "mt/shell_b", "mt/starfish"], 20, Vector3.ZERO, 9.0, 12.0, 0.02)
	WorldKit.place(world, "city/parasol", Vector3(-10.0, 0, -6.0), 20.0, 1.4)
	WorldKit.place(world, "mt/coconut", Vector3(10.0, 0, -6.0), 0.0, 2.0)
	WorldKit.place(world, "mt/dock", Vector3(11.0, -0.4, 6.0), 90.0, 2.0)
	_ball = Node3D.new()
	_ball.set_meta("keep_visible", true)
	world.add_child(_ball)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = BALL_R
	sm.height = BALL_R * 2.0
	mi.mesh = sm
	mi.material_override = WorldKit.mat(Color("#ffffff"), 0.4)
	_ball.add_child(mi)
	for k in 3:
		var band := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = BALL_R * 0.98
		tm.outer_radius = BALL_R * 1.03
		band.mesh = tm
		band.material_override = WorldKit.mat([Color("#ff4d6d"), Color("#ffd23f"), Color("#4da6ff")][k], 0.4)
		band.rotation = Vector3(k * PI / 3.0, 0, PI / 2.0)
		mi.add_child(band)
	_shadow = MgKit.warn_disc(world, Vector3.ZERO, 0.5, Color(0, 0, 0, 0.35), 9999.0)
	_score_lbl = Label3D.new()
	_score_lbl.font_size = 160
	_score_lbl.outline_size = 30
	_score_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_score_lbl.position = Vector3(0, NET_H + 1.6, -HALF_Z - 0.4)
	world.add_child(_score_lbl)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 1.2, 0.4)
	c.offset = Vector3(0, 10.5, 11.5)
	c.min_dist = 0.95
	c.max_dist = 1.05


func on_start() -> void:
	for av in avatars:
		if av:
			(av as PartyAvatar).can_shove = false
			(av as PartyAvatar).rig.surface = "sand"
	_serve(rng.randi() % 2)


func check_end() -> bool:
	return _pts[0] >= WIN or _pts[1] >= WIN


func _serve(side: int) -> void:
	_serve_side = side
	_serve_t = 1.1
	_bpos = Vector3(-3.5 if side == 0 else 3.5, 4.5, 0)
	_bvel = Vector3.ZERO
	_last_hit = -1


func on_tick(delta: float) -> void:
	for i in active_slots():
		_hit_cd[i] = maxf(0.0, _hit_cd[i] - delta)
		var av := avatars[i] as PartyAvatar
		var p := av.global_position
		p.x = clampf(p.x, -HALF_X - 1.0, -0.5) if teams[i] == 0 else clampf(p.x, 0.5, HALF_X + 1.0)
		p.z = clampf(p.z, -HALF_Z - 1.0, HALF_Z + 1.0)
		av.global_position = p
	if _serve_t > 0.0:
		_serve_t -= delta
		_bpos.y = 4.5 + sin(_serve_t * 8.0) * 0.1
		if _serve_t <= 0.0:
			_bvel = Vector3(0.8 if _serve_side == 0 else -0.8, 2.0, rng.randf_range(-0.6, 0.6))
	else:
		_bvel.y -= GRAV * delta
		var np := _bpos + _bvel * delta
		# Netz: unterhalb der Netzkante prallt der Ball zurück
		if signf(np.x) != signf(_bpos.x) and np.y < NET_H + BALL_R * 0.5:
			_bvel.x *= -0.5
			np.x = _bpos.x
			Audio.sfx("hit_soft", np, -6.0)
		_bpos = np
		if absf(_bpos.z) > HALF_Z + 3.0:
			_bvel.z *= -0.6
			_bpos.z = clampf(_bpos.z, -HALF_Z - 3.0, HALF_Z + 3.0)
		_touches()
		if _bpos.y <= BALL_R:
			_ground()
	_ball.position = _bpos
	_ball.rotation += Vector3(_bvel.z, 0, -_bvel.x) * delta * 0.8
	_shadow.position = Vector3(_bpos.x, 0.03, _bpos.z)
	_shadow.scale = Vector3.ONE * clampf(1.4 - _bpos.y * 0.12, 0.4, 1.4)
	_score_lbl.text = "%d : %d" % [_pts[0], _pts[1]]


func _touches() -> void:
	for i in active_slots():
		if _hit_cd[i] > 0.0:
			continue
		var av := avatars[i] as PartyAvatar
		var head := av.global_position + Vector3.UP * 1.3
		if head.distance_to(_bpos) < BALL_R + 0.75:
			_hit_cd[i] = 0.45
			var dir := 1.0 if teams[i] == 0 else -1.0
			var spike := not av.is_on_floor() and av.global_position.y > 0.8 and InputHub.held(i, "b")
			if spike:
				_bvel = Vector3(dir * rng.randf_range(9.0, 11.0), -1.5, rng.randf_range(-2.0, 2.0))
				FX.sparks(_bpos, Color(1, 0.9, 0.4), 12)
				Audio.sfx("punch", _bpos)
				Juice.shake(0.2)
				Juice.float_text(self, _bpos + Vector3.UP, "Schmetterball!", Color("#ffd166"), 60)
			else:
				# Bagger: hoher Bogen in die gegnerische Hälfte, mal kurz, mal tief ins Feld, gern in die Ecken
				_bvel = Vector3(dir * rng.randf_range(4.5, 8.2), rng.randf_range(7.0, 9.0), rng.randf_range(-2.6, 2.6) - _bpos.z * 0.15)
				Audio.sfx("boing", _bpos, -2.0)
			_last_hit = i
			av.rig.play_once("punch", "idle", 1.6)


func _ground() -> void:
	var side := 0 if _bpos.x < 0.0 else 1
	var out := absf(_bpos.x) > HALF_X + 0.2 or absf(_bpos.z) > HALF_Z + 0.2
	# Aus = Punkt für den Gegner des letzten Spielers; im Feld = Punkt für den Gegner der Seite
	var scorer := 1 - side
	if out and _last_hit >= 0:
		scorer = 1 - teams[_last_hit]
	_pts[scorer] += 1
	FX.dust(Vector3(_bpos.x, 0.1, _bpos.z), Color(0.95, 0.85, 0.6), 18, 1.4)
	Audio.sfx("bell", _bpos, -4.0)
	for i in active_slots():
		if teams[i] == scorer:
			add_score(i, 1.0)
			(avatars[i] as PartyAvatar).rig.react("cheer")
		else:
			(avatars[i] as PartyAvatar).rig.react("frustrated")
	Juice.float_text(self, Vector3(_bpos.x, 1.5, _bpos.z), "Aus!" if out else "Punkt!", Color("#fff1a8"), 70)
	_serve(1 - scorer)


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	d["b"] = [snappedf(_bpos.x, 0.01), snappedf(_bpos.y, 0.01), snappedf(_bpos.z, 0.01), _pts[0], _pts[1]]
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var b: Array = d.get("b", [])
	if b.size() == 5:
		var np := Vector3(float(b[0]), float(b[1]), float(b[2]))
		_bvel = (np - _bpos) * 30.0
		_bpos = np
		if int(b[3]) + int(b[4]) != _pts[0] + _pts[1]:
			Audio.sfx("bell", _bpos, -4.0)
			FX.dust(Vector3(_bpos.x, 0.1, _bpos.z), Color(0.95, 0.85, 0.6), 18, 1.4)
		_pts = [int(b[3]), int(b[4])]
	_ball.position = _bpos
	_shadow.position = Vector3(_bpos.x, 0.03, _bpos.z)
	_score_lbl.text = "%d : %d" % [_pts[0], _pts[1]]


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	var level: int = Game.players[slot].cpu_level
	var mem: Dictionary = cpu_mem[slot]
	var p := av.global_position
	var mine := -1.0 if teams[slot] == 0 else 1.0
	# Landepunkt vorausberechnen (einfache Wurfparabel), mit Schätzfehler je Stufe
	var land := _bpos
	var v := _bvel
	var q := _bpos
	for k in 90:
		v.y -= GRAV / 30.0
		q += v / 30.0
		if q.y <= 1.3:
			land = q
			break
	# Reaktionszeit: Ziel wird nur alle paar Zehntel neu geschätzt (mit Schätzfehler je Stufe)
	mem["rt"] = float(mem.get("rt", 0.0)) - delta
	if float(mem.rt) <= 0.0 or not mem.has("land"):
		mem["rt"] = Game.lv_react([0.55, 0.35, 0.2], level)
		var e: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * float(Game.lv([2.0, 1.2, 0.55], level))
		mem["land"] = Vector3(land.x + e.x, 0, land.z + e.y)
	var target: Vector3 = mem.land
	# Zwei Spieler teilen sich das Feld: vorne/hinten nach Slot-Reihenfolge, wenn der Ball nicht kommt
	var coming := signf(land.x) == mine and _serve_t <= 0.0
	var mates: Array[int] = []
	for o in active_slots():
		if teams[o] == teams[slot]:
			mates.append(o)
	var front := mates.find(slot) == 0
	if not coming:
		target = Vector3(mine * (2.5 if front else 5.5), 0, -1.5 if front else 1.5)
	elif mates.size() > 1:
		var other := avatars[mates[1] if front else mates[0]] as PartyAvatar
		if other.global_position.distance_to(target) + 0.6 < p.distance_to(target):
			target = Vector3(mine * (2.5 if front else 5.5), 0, -target.z * 0.5)
	var to := Vector2(target.x - p.x, target.z - p.z)
	var mv := to.normalized() * clampf(to.length() * 0.8, 0.0, 1.0)
	var held := {}
	var horiz := Vector2(_bpos.x - p.x, _bpos.z - p.z).length()
	if coming and horiz < 1.3 and _bpos.y > 1.6 and _bpos.y < 3.4 and av.is_on_floor() and _bvel.y < 0.0:
		held["a"] = true
	if not av.is_on_floor() and horiz < 1.4 and level >= 1 and absf(p.x) < 4.0 and randf() < Game.lv([0.0, 0.4, 0.8], level):
		held["b"] = true
	InputHub.set_virtual(slot, mv, held)
