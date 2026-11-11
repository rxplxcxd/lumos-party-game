extends MinigameBase
## Nagel-Profi: Vier Werkbänke, ein Riesenhammer pro Spieler. A halten lädt die Schlagkraft (die Anzeige pendelt
## hoch und runter), loslassen = Schlag. Im grünen Bereich sitzt der Nagel tief, zu fest = krumm (B mehrmals
## tippen zum Geradebiegen), zu schwach = kaum Wirkung. Goldnägel sind härter, zählen aber doppelt.
## Online: Host-Modell (Host simuliert alle Werkbänke, Clients zeigen den Stand).

const XS := [-5.4, -1.8, 1.8, 5.4]
const SWEET_LO := 0.7
const SWEET_HI := 0.88
const CHARGE_T := 0.85        # Sekunden von 0 bis voll
const NAILS := [              # gemeinsame Abfolge: alle bekommen dieselben Nägel
	{"kind": "iron", "hard": 1.0, "pts": 1}, {"kind": "iron", "hard": 1.0, "pts": 1}, {"kind": "copper", "hard": 0.8, "pts": 1},
	{"kind": "gold", "hard": 1.6, "pts": 2}, {"kind": "iron", "hard": 1.1, "pts": 1}, {"kind": "copper", "hard": 0.85, "pts": 1},
	{"kind": "gold", "hard": 1.7, "pts": 2}, {"kind": "iron", "hard": 1.2, "pts": 1}, {"kind": "gold", "hard": 1.8, "pts": 2},
]
const NAIL_COL := {"iron": Color("#b8c0cc"), "copper": Color("#d9824a"), "gold": Color("#ffd23f")}

var _st: Array[Dictionary] = []      # je Spieler: power, dir, charging, depth, nail, bent, fix, swing
var _was_held: Array[bool] = [false, false, false, false]
var _vis: Array[Dictionary] = []     # je Spieler: hammer, nail, fill, board


func _init() -> void:
	game_id = "nail_pro"
	env_preset = "day"
	time_limit = 35.0
	score_format = "%d Pkt."
	backdrop_style = "meadow"
	arena_radius = 8.0
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 8)
	spawn_points = [Vector3(XS[0], 0.6, 1.4), Vector3(XS[1], 0.6, 1.4), Vector3(XS[2], 0.6, 1.4), Vector3(XS[3], 0.6, 1.4)]
	net_model = "host"


func build_arena() -> void:
	# Werkstatt-Hof: Holzdielen, Bretterstapel, Sägeböcke, Werkzeugwand
	WorldKit.box(world, Vector3(18, 0.4, 10), Vector3(0, -0.2, 0), Color("#c49a6c"))
	for i in 9:
		WorldKit.box(world, Vector3(18, 0.02, 0.06), Vector3(0, 0.01, -4.5 + i * 1.1), Color("#9c744a"), false)
	WorldKit.box(world, Vector3(18, 4.5, 0.4), Vector3(0, 2.0, -4.6), Color("#8a5a34"), false)
	for i in 7:
		WorldKit.box(world, Vector3(0.12, 0.9, 0.12), Vector3(-7.5 + i * 2.5, 3.2, -4.3), Color("#5b5f66"), false)
		WorldKit.cylinder(world, 0.22, 0.12, Vector3(-7.5 + i * 2.5, 3.7, -4.3), Color("#d9824a"), false)
	WorldKit.place(world, "surv/planks", Vector3(-8.0, 0, -2.5), 20.0, 1.6)
	WorldKit.place(world, "surv/anvil", Vector3(8.2, 0, -2.6), -30.0, 1.4)
	WorldKit.place(world, "surv/barrel", Vector3(8.6, 0, 2.5), 0.0, 1.3)
	WorldKit.place(world, "nat/stump", Vector3(-8.4, 0, 2.6), 0.0, 1.6)
	for i in 4:
		_st.append({"power": 0.0, "dir": 1.0, "charging": false, "depth": 0.0, "nail": 0, "bent": false, "fix": 0, "swing": 0.0})
		_build_station(i)


func _build_station(i: int) -> void:
	var x: float = XS[i]
	var col := Game.player_color(i)
	WorldKit.box(world, Vector3(2.6, 0.9, 1.5), Vector3(x, 0.45, -0.6), Color("#a4703f"))
	WorldKit.box(world, Vector3(2.7, 0.08, 1.6), Vector3(x, 0.92, -0.6), Color("#7a4f2a"), false)
	var board := WorldKit.box(world, Vector3(1.4, 0.25, 0.9), Vector3(x, 1.08, -0.6), Color("#e3b77d"), false)
	var nail := Node3D.new()
	world.add_child(nail)
	nail.position = Vector3(x, 1.2, -0.6)
	WorldKit.cylinder(nail, 0.05, 0.7, Vector3(0, 0.35, 0), Color("#b8c0cc"), false)
	WorldKit.cylinder(nail, 0.17, 0.06, Vector3(0, 0.71, 0), Color("#b8c0cc"), false)
	# Riesenhammer: Drehpunkt hinter dem Nagel, Kopf in Spielerfarbe
	var pivot := Node3D.new()
	world.add_child(pivot)
	pivot.position = Vector3(x + 1.3, 1.9, -0.6)
	WorldKit.box(pivot, Vector3(1.6, 0.16, 0.16), Vector3(-0.5, 0, 0), Color("#8a5a34"), false)
	WorldKit.box(pivot, Vector3(0.5, 0.5, 0.75), Vector3(-1.3, 0.0, 0), col, false)
	WorldKit.box(pivot, Vector3(0.52, 0.08, 0.77), Vector3(-1.3, -0.22, 0), col.darkened(0.3), false)
	pivot.rotation.z = -0.35
	# Kraftanzeige: Rahmen, grüner Bereich, Füllung
	var meter := Node3D.new()
	world.add_child(meter)
	meter.position = Vector3(x - 1.55, 1.0, -0.1)
	WorldKit.box(meter, Vector3(0.36, 2.0, 0.08), Vector3(0, 1.0, 0), Color("#2b2236"), false)
	WorldKit.box(meter, Vector3(0.38, 2.0 * (SWEET_HI - SWEET_LO), 0.1), Vector3(0, 2.0 * (SWEET_LO + SWEET_HI) * 0.5, 0.01), Color("#5fd35a"), false)
	var fill := WorldKit.box(meter, Vector3(0.26, 1.0, 0.12), Vector3(0, 0, 0.02), Color("#fff1a8"), false)
	WorldKit.box(meter, Vector3(0.44, 0.1, 0.12), Vector3(0, 2.05, 0), col, false)
	_vis.append({"pivot": pivot, "nail": nail, "fill": fill, "board": board})
	_set_nail_look(i)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 1.0, 0.0)
	c.offset = Vector3(0, 7.5, 10.5)
	c.min_dist = 0.95
	c.max_dist = 1.05


func on_start() -> void:
	for av in avatars:
		var pa := av as PartyAvatar
		pa.can_move = false
		pa.can_jump = false
		pa.can_shove = false
		pa.rig.face_now(Vector3.FORWARD)


func on_tick(delta: float) -> void:
	for i in active_slots():
		var s := _st[i]
		var held := InputHub.held(i, "a")
		s.swing = maxf(0.0, float(s.swing) - delta)
		if bool(s.bent):
			if InputHub.pressed(i, "b"):
				s.fix = int(s.fix) + 1
				Audio.sfx("wood_hit", Vector3(XS[i], 1.2, -0.6), -8.0, 1.6)
				FX.sparks(Vector3(XS[i], 1.6, -0.6), Color(1, 0.9, 0.6), 4)
				if int(s.fix) >= 3:
					s.bent = false
					s.fix = 0
					Juice.float_text(self, Vector3(XS[i], 2.4, -0.6), "Gerade!", Color("#9be7ff"), 64)
		elif float(s.swing) <= 0.0:
			if held:
				if not bool(s.charging):
					s.charging = true
					s.power = 0.0
					s.dir = 1.0
				s.power = float(s.power) + float(s.dir) * delta / CHARGE_T
				if float(s.power) >= 1.0:
					s.power = 1.0
					s.dir = -1.0
				elif float(s.power) <= 0.0:
					s.power = 0.0
					s.dir = 1.0
			elif bool(s.charging) and _was_held[i]:
				s.charging = false
				_strike(i, float(s.power))
		_was_held[i] = held
	_render()


func _strike(i: int, p: float) -> void:
	var s := _st[i]
	s.swing = 0.32
	var nail: Dictionary = NAILS[int(s.nail) % NAILS.size()]
	var hard := float(nail.hard)
	var at := Vector3(XS[i], 1.5, -0.6)
	var av := avatars[i] as PartyAvatar
	av.rig.play_once("punch", "idle", 1.6)
	if p > SWEET_HI + 0.02:
		s.bent = true
		s.fix = 0
		s.depth = maxf(0.0, float(s.depth) - 0.05)
		Juice.float_text(self, at + Vector3.UP, "Krumm! B tippen", Color("#ff8a5c"), 64)
		Audio.sfx("boing", at, -2.0)
		av.rig.react("frustrated")
	elif p >= SWEET_LO:
		# Je mittiger, desto tiefer: Mitte = "Perfekt!", Randbereich = "Gut!"
		var q := 1.0 - absf(p - (SWEET_LO + SWEET_HI) * 0.5) / ((SWEET_HI - SWEET_LO) * 0.5)
		s.depth = float(s.depth) + (0.42 + 0.2 * q) / hard
		Juice.float_text(self, at + Vector3.UP, "Perfekt!" if q > 0.6 else "Gut!", Color("#7dff8a") if q > 0.6 else Color("#c8f7a0"), 64)
		FX.sparks(at, Color(1, 0.95, 0.5), 14)
		Audio.sfx("stone_hit", at, 0.0, 1.3)
		Juice.shake(0.12)
	else:
		s.depth = float(s.depth) + (0.08 + p * 0.25) / hard
		Audio.sfx("wood_hit", at, -3.0)
		FX.dust(at, Color(0.9, 0.75, 0.5), 5, 0.6)
	InputHub.rumble(i, 0.6, 0.12)
	if float(s.depth) >= 1.0:
		add_score(i, float(nail.pts), at + Vector3.UP * 0.6)
		Audio.sfx("coin", at)
		FX.stars(at + Vector3.UP * 0.4, NAIL_COL[nail.kind], 10)
		av.rig.react("cheer" if int(nail.pts) > 1 else "flex")
		s.nail = int(s.nail) + 1
		s.depth = 0.0
		_set_nail_look(i)
		var b: Node3D = _vis[i].board
		Juice.squash(b, 1.1, 0.8, 0.25, Vector3.ONE)


func _set_nail_look(i: int) -> void:
	var nail: Dictionary = NAILS[int(_st[i].nail) % NAILS.size()]
	var c: Color = NAIL_COL[nail.kind]
	for part in (_vis[i].nail as Node3D).get_children():
		for mi in (part as Node).find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = WorldKit.mat(c, 0.3, 0.15 if nail.kind == "gold" else 0.0)
	var n: Node3D = _vis[i].nail
	n.scale = Vector3(1, 0.01, 1)
	n.create_tween().tween_property(n, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)


func _render() -> void:
	for i in 4:
		if i >= _st.size() or i >= _vis.size():
			return
		var s := _st[i]
		var v := _vis[i]
		var n: Node3D = v.nail
		n.position.y = 1.2 - clampf(float(s.depth), 0.0, 1.0) * 0.62
		n.rotation.z = 0.6 if bool(s.bent) else 0.0
		var fill: Node3D = v.fill
		var p := float(s.power) if bool(s.charging) else 0.0
		fill.scale = Vector3(1, maxf(p * 2.0, 0.01), 1)
		fill.position.y = p
		var pivot: Node3D = v.pivot
		# Ausholen beim Laden, Schlag beim Loslassen: Kopf landet genau auf dem Nagelkopf
		var nail_top := n.position.y + 0.74
		var hit_rot := asin(clampf((1.9 - (nail_top + 0.25)) / 1.3, -1.0, 1.0))
		var target := (-0.35 - p * 1.0) if bool(s.charging) else (hit_rot if float(s.swing) > 0.2 else -0.35)
		pivot.rotation.z = lerpf(pivot.rotation.z, target, 0.6 if float(s.swing) > 0.2 else 0.25)


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	d["s"] = _st.map(func(s: Dictionary) -> Array: return [snappedf(float(s.power), 0.01), 1 if bool(s.charging) else 0, snappedf(float(s.depth), 0.01), int(s.nail), 1 if bool(s.bent) else 0, snappedf(float(s.swing), 0.02)])
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var arr: Array = d.get("s", [])
	for i in mini(arr.size(), _st.size()):
		var e: Array = arr[i]
		var s := _st[i]
		var old_nail := int(s.nail)
		var old_swing := float(s.swing)
		s.power = float(e[0])
		s.charging = int(e[1]) == 1
		s.depth = float(e[2])
		s.nail = int(e[3])
		s.bent = int(e[4]) == 1
		s.swing = float(e[5])
		if int(s.nail) != old_nail:
			_set_nail_look(i)
		if float(s.swing) > old_swing + 0.1:
			(avatars[i] as PartyAvatar).rig.play_once("punch", "idle", 1.6)
			Audio.sfx("wood_hit", Vector3(XS[i], 1.5, -0.6), -3.0)
	_render()


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var level: int = Game.players[slot].cpu_level
	var s := _st[slot]
	var mem: Dictionary = cpu_mem[slot]
	var held := {}
	if bool(s.bent):
		mem["tap"] = not bool(mem.get("tap", false))
		if bool(mem.tap) and randf() < Game.lv([0.35, 0.55, 0.8], level):
			held["b"] = true
	elif float(s.swing) <= 0.0:
		if not mem.has("aim"):
			# Zielwert: Profis treffen die Mitte, Anfänger streuen (auch mal drüber)
			mem["aim"] = clampf((SWEET_LO + SWEET_HI) * 0.5 + randf_range(-1.0, 1.0) * Game.lv([0.17, 0.11, 0.05], level, true), 0.3, 1.0)
		var aim := float(mem.aim)
		if not bool(s.charging) or (float(s.power) < aim and float(s.dir) > 0.0):
			held["a"] = true
		else:
			mem.erase("aim")
	InputHub.set_virtual(slot, Vector2.ZERO, held)
