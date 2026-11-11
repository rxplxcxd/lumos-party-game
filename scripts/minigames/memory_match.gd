extends MinigameBase
## Karten-Match (2 gegen 2): Auf dem Spieltisch liegen 20 verdeckte Karten (10 Paare – Münze, Stern, Herz,
## Schlüssel, Edelsteine …). Die Teams decken abwechselnd je zwei Karten auf; innerhalb des Teams wechselt der
## Aufdecker. Passt das Paar, gibt es einen Punkt und derselbe Spieler darf weitermachen. Jede Wahl hat ein
## Zeitlimit – wer trödelt, deckt eine Zufallskarte auf. Stick = Rahmen bewegen, A = Karte umdrehen.
## Online: Host-Modell (gleiche Kartenverteilung aus dem gemeinsamen Zufall).

const COLS := 5
const ROWS := 4
const CW := 1.55
const CH := 1.95
const PICK_T := 7.0
const KINDS := ["qp/coin", "qp/star", "qp/heart", "qp/key", "qp/gem_blue", "qp/gem_pink", "qp/gem_green", "qp/thunder", "qp/bomb", "qp/fruit"]
const KIND_SCALE := [0.5, 0.55, 0.6, 0.55, 0.5, 0.48, 0.55, 0.6, 0.45, 0.9]

var _kind: Array[int] = []
var _up: Array[bool] = []
var _done: Array[bool] = []
var _cards: Array[Node3D] = []
var _faces: Array[Node3D] = []
var _cursor := Vector2i(2, 1)
var _frame: MeshInstance3D
var _turn_team := 0
var _member_idx := [0, 0]
var _active := -1
var _picked: Array[int] = []
var _pick_t := PICK_T
var _reveal_t := 0.0
var _move_cd := 0.0
var _timer_lbl: Label3D


func _init() -> void:
	game_id = "memory_match"
	env_preset = "day"
	backdrop_style = "meadow"
	time_limit = 75.0
	score_format = "%d Paare"
	arena_radius = 7.0
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 8)
	net_model = "host"
	spawn_points = [Vector3(-5.6, 0.6, -1.0), Vector3(5.6, 0.6, -1.0), Vector3(-5.6, 0.6, 1.4), Vector3(5.6, 0.6, 1.4)]


func on_setup() -> void:
	var c := [0, 0]
	for i in 4:
		var t := teams[i]
		spawn_points[i] = Vector3(-5.8 if t == 0 else 5.8, 0.6, -1.2 + c[t] * 2.6)
		c[t] += 1


func build_arena() -> void:
	# Gartenpavillon: Holzdeck, großer Spieltisch mit Tischdecke, Lampions
	WorldKit.box(world, Vector3(16, 0.4, 10), Vector3(0, -0.2, 0), Color("#c49a6c"))
	WorldKit.box(world, Vector3(COLS * CW + 1.0, 0.8, ROWS * CH + 1.0), Vector3(0, 0.4, 0), Color("#8a5a34"))
	WorldKit.box(world, Vector3(COLS * CW + 0.8, 0.04, ROWS * CH + 0.8), Vector3(0, 0.82, 0), Color("#e8425a"), false)
	for x in range(-2, 3):
		WorldKit.box(world, Vector3(0.08, 0.05, ROWS * CH + 0.8), Vector3(x * CW, 0.85, 0), Color("#fff4f0"), false)
	for k in 6:
		var a := TAU * k / 6.0
		WorldKit.cylinder(world, 0.12, 3.0, Vector3(cos(a) * 7.5, 1.5, sin(a) * 5.0), Color("#7a4f2a"), false)
		var lamp := WorldKit.cylinder(world, 0.35, 0.5, Vector3(cos(a) * 7.5, 3.2, sin(a) * 5.0), [Color("#ffd166"), Color("#ff8fab"), Color("#8be9ff")][k % 3], false)
		((lamp.get_child(0) as MeshInstance3D)).material_override = WorldKit.mat([Color("#ffd166"), Color("#ff8fab"), Color("#8be9ff")][k % 3], 0.4, 1.2)
	WorldKit.scatter(world, ["plat/flowers", "nat/bush", "qp/bush_fruit"], 10, Vector3.ZERO, 9.0, 13.0, 0.0)
	# Kartenverteilung (gemeinsamer Zufall → auf allen Geräten gleich)
	var deck: Array[int] = []
	for k in KINDS.size():
		deck.append(k)
		deck.append(k)
	for k in range(deck.size() - 1, 0, -1):
		var j := rng.randi() % (k + 1)
		var tmp := deck[k]
		deck[k] = deck[j]
		deck[j] = tmp
	_kind = deck
	for i in COLS * ROWS:
		_up.append(false)
		_done.append(false)
		var c := Node3D.new()
		world.add_child(c)
		c.position = _card_pos(i)
		var back := WorldKit.box(c, Vector3(CW - 0.2, 0.1, CH - 0.25), Vector3.ZERO, Color("#7a4ec2"), false)
		WorldKit.box(back, Vector3(CW - 0.5, 0.02, CH - 0.55), Vector3(0, 0.06, 0), Color("#ffd166"), false)
		WorldKit.box(back, Vector3(CW - 0.6, 0.02, CH - 0.65), Vector3(0, -0.06, 0), Color("#fff6e0"), false)
		var face := Assets.spawn(KINDS[_kind[i]], world, _card_pos(i) + Vector3(0, 0.1, 0), 0.0, KIND_SCALE[_kind[i]])
		face.visible = false
		_cards.append(c)
		_faces.append(face)
	_frame = MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(CW, 0.04, CH)
	var mat := WorldKit.mat(Color(1.0, 0.85, 0.3, 0.5), 0.4, 1.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.material = mat
	_frame.mesh = fm
	world.add_child(_frame)
	_timer_lbl = Label3D.new()
	_timer_lbl.font_size = 120
	_timer_lbl.outline_size = 24
	_timer_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_timer_lbl.position = Vector3(0, 3.2, -ROWS * CH * 0.5 - 0.5)
	world.add_child(_timer_lbl)


func _card_pos(i: int) -> Vector3:
	var c := i % COLS
	var r := i / COLS
	return Vector3((c - (COLS - 1) * 0.5) * CW, 0.9, (r - (ROWS - 1) * 0.5) * CH)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0.8, 0.3)
	c.offset = Vector3(0, 11.5, 6.5)
	c.min_dist = 1.0
	c.max_dist = 1.0


func on_start() -> void:
	for av in avatars:
		if av:
			var pa := av as PartyAvatar
			pa.can_move = false
			pa.can_jump = false
			pa.can_shove = false
			pa.rig.face_now(Vector3.RIGHT if pa.global_position.x < 0.0 else Vector3.LEFT)
	_next_turn(true)


func check_end() -> bool:
	return not (false in _done)


func _team_members(t: int) -> Array[int]:
	var out: Array[int] = []
	for i in active_slots():
		if teams[i] == t:
			out.append(i)
	return out


func _next_turn(keep: bool) -> void:
	if not keep:
		_turn_team = 1 - _turn_team
	var mem := _team_members(_turn_team)
	if mem.is_empty():
		_turn_team = 1 - _turn_team
		mem = _team_members(_turn_team)
	if not keep or _active < 0:
		_member_idx[_turn_team] = (_member_idx[_turn_team] + 1) % maxi(mem.size(), 1)
		_active = mem[_member_idx[_turn_team] % mem.size()]
	_picked.clear()
	_pick_t = PICK_T
	var av := avatars[_active] as PartyAvatar
	av.rig.react("determined")
	Juice.float_text(self, av.global_position + Vector3.UP * 2.2, "Du bist dran!", Game.player_color(_active).lightened(0.3), 56)


func on_tick(delta: float) -> void:
	_move_cd = maxf(0.0, _move_cd - delta)
	if _reveal_t > 0.0:
		_reveal_t -= delta
		if _reveal_t <= 0.0:
			_resolve()
	elif _active >= 0:
		_pick_t -= delta
		var mv := InputHub.move(_active)
		if mv.length() > 0.55 and _move_cd <= 0.0:
			var dx := signi(roundi(mv.x)) if absf(mv.x) > 0.5 else 0
			var dy := signi(roundi(mv.y)) if absf(mv.y) > 0.5 else 0
			_cursor = Vector2i(clampi(_cursor.x + dx, 0, COLS - 1), clampi(_cursor.y + dy, 0, ROWS - 1))
			_move_cd = 0.18
			Audio.sfx("ui_move", _card_pos(_cursor.y * COLS + _cursor.x), -10.0)
		if InputHub.pressed(_active, "a"):
			_flip(_cursor.y * COLS + _cursor.x)
		elif _pick_t <= 0.0:
			var free: Array[int] = []
			for i in _up.size():
				if not _up[i] and not _done[i]:
					free.append(i)
			if not free.is_empty():
				_flip(free[rng.randi() % free.size()])
	_draw(delta)


func _flip(i: int) -> void:
	if _up[i] or _done[i] or _picked.size() >= 2:
		Audio.sfx("ui_error", null, -8.0)
		return
	_up[i] = true
	_picked.append(i)
	_pick_t = PICK_T
	Audio.sfx("plop", _card_pos(i), 0.0, 1.2)
	(avatars[_active] as PartyAvatar).rig.play_once("interact", "idle", 1.6)
	_show_card(i, true)
	if _picked.size() == 2:
		_reveal_t = 1.1


func _show_card(i: int, up: bool) -> void:
	var c := _cards[i]
	var tw := c.create_tween()
	tw.tween_property(c, "rotation:z", PI if up else 0.0, 0.22).set_trans(Tween.TRANS_BACK)
	_faces[i].visible = up
	if up:
		_faces[i].scale = Vector3.ONE * 0.01
		_faces[i].create_tween().tween_property(_faces[i], "scale", Vector3.ONE * KIND_SCALE[_kind[i]], 0.25).set_trans(Tween.TRANS_BACK)


func _resolve() -> void:
	var a := _picked[0]
	var b := _picked[1]
	if _kind[a] == _kind[b]:
		_done[a] = true
		_done[b] = true
		add_score(_active, 1.0, _card_pos(a) + Vector3.UP * 1.2)
		FX.stars(_card_pos(a) + Vector3.UP * 0.5, Color(1, 0.9, 0.4), 10)
		FX.stars(_card_pos(b) + Vector3.UP * 0.5, Color(1, 0.9, 0.4), 10)
		Audio.sfx("coin_chime", _card_pos(a))
		(avatars[_active] as PartyAvatar).rig.react("cheer")
		_next_turn(true)
	else:
		_up[a] = false
		_up[b] = false
		_show_card(a, false)
		_show_card(b, false)
		Audio.sfx("negative", null, -6.0)
		(avatars[_active] as PartyAvatar).rig.react("confused")
		_next_turn(false)


func _draw(_delta: float) -> void:
	_frame.position = _card_pos(_cursor.y * COLS + _cursor.x) + Vector3(0, 0.12, 0)
	if _active >= 0:
		var col := Game.player_color(_active)
		(_frame.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color = Color(col.r, col.g, col.b, 0.55)
		(_frame.mesh.surface_get_material(0) as StandardMaterial3D).emission = col
	_timer_lbl.text = str(int(ceil(_pick_t))) if _reveal_t <= 0.0 else ""
	_timer_lbl.modulate = Color("#ff8a5c") if _pick_t < 3.0 else Color("#fff1a8")


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	var up := 0
	var dn := 0
	for i in _up.size():
		if _up[i]:
			up |= 1 << i
		if _done[i]:
			dn |= 1 << i
	d["m"] = [up, dn, _cursor.x, _cursor.y, _active, snappedf(_pick_t, 0.1), 1 if _reveal_t > 0.0 else 0]
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var m: Array = d.get("m", [])
	if m.size() < 7:
		return
	for i in _up.size():
		var u := (int(m[0]) >> i) & 1 == 1
		var dn := (int(m[1]) >> i) & 1 == 1
		if dn and not _done[i]:
			FX.stars(_card_pos(i) + Vector3.UP * 0.5, Color(1, 0.9, 0.4), 8)
		_done[i] = dn
		if u != _up[i] and not dn:
			_up[i] = u
			_show_card(i, u)
			Audio.sfx("plop", _card_pos(i), 0.0, 1.2)
		elif dn and not _faces[i].visible:
			_up[i] = true
			_show_card(i, true)
	_cursor = Vector2i(int(m[2]), int(m[3]))
	_active = int(m[4])
	_pick_t = float(m[5])
	_reveal_t = 0.5 if int(m[6]) == 1 else 0.0
	_draw(0.0)


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, delta: float) -> void:
	if slot != _active or _reveal_t > 0.0:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var mem: Dictionary = cpu_mem[slot]
	if not mem.has("seen"):
		mem["seen"] = {}
	var seen: Dictionary = mem.seen
	# Alle gerade offenen Karten merken (mit Vergesslichkeit je Stufe)
	for i in _up.size():
		if _up[i] and not _done[i] and randf() < Game.lv([0.5, 0.75, 0.95], level):
			seen[i] = _kind[i]
	for i in seen.keys():
		if _done[i]:
			seen.erase(i)
	if not mem.has("target") or _up[int(mem.target)] or _done[int(mem.target)]:
		mem["target"] = _choose(seen)
		mem["wait"] = randf_range(0.3, 0.9) * (3 - level) * 0.5
	var target := int(mem.target)
	mem.wait = float(mem.wait) - delta
	var tc := Vector2i(target % COLS, target / COLS)
	var mv := Vector2.ZERO
	var held := {}
	if tc != _cursor:
		mv = Vector2(signi(tc.x - _cursor.x), signi(tc.y - _cursor.y))
	elif float(mem.wait) <= 0.0:
		held["a"] = true
		mem.erase("target")
	InputHub.set_virtual(slot, mv, held)


func _choose(seen: Dictionary) -> int:
	var free: Array[int] = []
	for i in _up.size():
		if not _up[i] and not _done[i]:
			free.append(i)
	if free.is_empty():
		return 0
	if _picked.size() == 1:
		var k := _kind[_picked[0]]
		for i in seen:
			if int(seen[i]) == k and int(i) != _picked[0] and not _up[int(i)]:
				return int(i)
	else:
		# Bekanntes Paar? Erst eine davon
		var by: Dictionary = {}
		for i in seen:
			var k2 := int(seen[i])
			if by.has(k2) and not _up[int(i)]:
				return int(i)
			by[k2] = i
	# Sonst eine noch unbekannte Karte
	var unknown := free.filter(func(i: int) -> bool: return not seen.has(i))
	return int(unknown[randi() % unknown.size()]) if not unknown.is_empty() else free[randi() % free.size()]
