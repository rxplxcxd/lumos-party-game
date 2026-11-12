extends MinigameBase
## Boss-Kampf in Echtzeit: Alle laufen frei in der Arena des jeweiligen Brett-Bosses (siehe BossDefs), sammeln
## themenpassende Wurfgeschosse auf (Berühren) und werfen sie mit B auf den Boss. Der Boss kündigt jede
## Fähigkeit sichtbar an (leuchtende Bodenkreise, Schweif-/Flammenbögen, Wellen, Sturmangriffe, Geschosse …) –
## ausweichen, drüberspringen (A), Positionieren und die Spezial-Orte der Arena taktisch nutzen entscheidet.
## Phasen bei 66 % / 33 %: Der Boss wird schneller, in der Wut-Phase greift er doppelt an.
## Schaden = Punkte. Besiegt ihr ihn rechtzeitig, gibt es einen Sieges-Bonus; Münz-/Item-Effekte werden
## auf dem Brett verrechnet. Online: Host-Modell (Host simuliert, Clients zeigen Zustand & Animationen).

const R := 13.0
const BOSS_HOME := Vector3(0, 0, -5.5)
const SPEED := 7.0

var boss_id := ""
var def: Dictionary = {}
var model: BossModel
var hp := 50.0
var max_hp := 50.0
var bphase := 1
var boss_pos := BOSS_HOME
var defeated := false
var _atk_cd := 3.5
var _double_t := -1.0
var _last_ability := ""
var _stun_boss_t := 0.0
var _t := 0.0

var hazards: Array[Dictionary] = []
var _hz_id := 0
var ammo: Array[Dictionary] = []          # {node, holder}
var carry: Array[bool] = [false, false, false, false]
var pickups: Array[Dictionary] = []       # Münzen auf dem Boden {node, p}
var pads: Array[Dictionary] = []          # Spezial-Orte der Arena
var status: Array[Dictionary] = [{}, {}, {}, {}]
var coin_delta: Array[int] = [0, 0, 0, 0]
var item_steal: Array[int] = [0, 0, 0, 0]

var night := false
var _night_t := 0.0
var _night_force := 0.0
var flood := false
var _flood_t := 0.0
var _flood_force := 0.0
var armor_t := 0.0
var invert_t := 0.0
var slip_t := 0.0
var fog_t := 0.0
var overclock_t := 0.0
var frost_armor := true
var _wind := Vector3.ZERO
var _wind_t := 0.0
var _duel: Dictionary = {}
var _duel_cd := 4.0

var _act_seq := 0
var _act_kind := ""
var _say_text := ""
var _say_until := 0.0
var _say_label: Label
var _bar: BossBar
var _fog_rect: ColorRect
var _sun: DirectionalLight3D
var _water: Node3D
var _hz_nodes := {}                       # id -> Node3D (Darstellung, auch auf Clients)


func _init() -> void:
	game_id = "boss_battle"
	time_limit = 80.0
	show_timer = true
	arena_radius = 12.0
	teaser_height = 2.0
	cannon_pos = Vector3(0, 0, 16)
	net_model = "host"
	score_format = "%d Schaden"
	music_track = 3
	boss_id = String(Game.minigame_setup.get("boss", ""))
	spawn_points = [Vector3(-4.5, 0.6, 6.5), Vector3(-1.5, 0.6, 7.5), Vector3(1.5, 0.6, 7.5), Vector3(4.5, 0.6, 6.5)]


func on_setup() -> void:
	if boss_id == "" or not BossDefs.BOSSES.has(boss_id):
		if Game.mode == "party":
			boss_id = BossDefs.for_board(String(Game.party.get("board", "meadow")))
		else:
			var keys := BossDefs.BOSSES.keys()
			boss_id = String(keys[rng.randi() % keys.size()])
	def = BossDefs.get_def(boss_id)
	env_preset = String(def.env)
	backdrop_style = String(def.backdrop)
	info = info.duplicate()
	info["name"] = "%s – %s" % [def.name, def.title]
	info["desc"] = "%s Sammelt %s und werft sie auf den Boss – weicht den angekündigten Angriffen aus! %s" % [def.intro, def.ammo[0], def.unique]
	info["controls"] = "Stick: Laufen · A: Springen · B: Werfen"
	var n := maxi(1, active_slots().size())
	max_hp = 21.0 * n + 12.0   # 4 Spieler: 96 LP – gutes Teamplay braucht rund eine Minute
	hp = max_hp


# --- Arena ------------------------------------------------------------------------------------------------------

func build_arena() -> void:
	var ground: Color = def.ground
	var tile: Color = def.tile
	WorldKit.cylinder(world, R, 1.0, Vector3(0, -0.5, 0), ground)
	WorldKit.cylinder(world, R + 0.5, 0.6, Vector3(0, -0.9, 0), tile.darkened(0.3), false)
	WorldKit.cylinder(world, 4.2, 0.12, Vector3(BOSS_HOME.x, 0.02, BOSS_HOME.z), tile.darkened(0.12), false)
	for k in 24:
		var a := TAU * k / 24.0
		var post := WorldKit.box(world, Vector3(0.5, 0.5, 0.5), Vector3(cos(a) * (R - 0.2), 0.25, sin(a) * (R - 0.2)), tile.darkened(0.2), false)
		post.rotation.y = -a
	match String(def.env):
		"dungeon":
			WorldKit.lava(world, Vector2(90, 90), -1.4)
		"pirates":
			_water = WorldKit.water(world, Vector2(120, 120), -0.55)
	model = BossModel.create(boss_id)
	model.set_meta("keep_visible", true)
	world.add_child(model)
	model.position = BOSS_HOME
	_build_pads()


func _pad_ring(n: int, radius: float, a0 := 0.0) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for k in n:
		var a := a0 + TAU * k / n
		out.append(Vector3(sin(a) * radius, 0, cos(a) * radius * 0.85 + 0.6))
	return out


## Spezial-Orte je Boss (feste Anordnung, damit alle Online-Geräte dieselbe Arena haben).
func _build_pads() -> void:
	match boss_id:
		"ignis":
			var g := RandomNumberGenerator.new()
			g.seed = 4711
			for k in 9:
				var a := TAU * k / 9.0 + g.randf_range(-0.2, 0.2)
				var rr := g.randf_range(5.5, 10.0)
				var p := Vector3(sin(a) * rr, 0, cos(a) * rr * 0.9 + 1.0)
				var n := Node3D.new()
				world.add_child(n)
				n.position = p
				WorldKit.cylinder(n, 1.25, 0.08, Vector3(0, 0.03, 0), Color("#6a4a40"), false)
				for c in 3:
					var cr := WorldKit.box(n, Vector3(1.6, 0.03, 0.08), Vector3(0, 0.08, 0), Color("#1a0d0a"), false)
					cr.rotation.y = c * 1.1
				var lava := WorldKit.cylinder(n, 1.15, 0.06, Vector3(0, -0.02, 0), Color("#ff7a1a"), false)
				lava.visible = false
				lava.name = "Lava"
				pads.append({"kind": "crack", "p": p, "r": 1.25, "node": n, "hp": 2, "occ": 0.0})
		"klabautox":
			for p in _pad_ring(4, 8.5, PI * 0.25):
				var n := WorldKit.cylinder(world, 1.9, 0.7, p + Vector3(0, 0.35, 0), Color("#f3e0a8"), true)
				WorldKit.place(n, "pirate/palm", Vector3(0.8, 0.35, -0.6), 40.0, 0.8)
				pads.append({"kind": "sand", "p": p, "r": 1.9, "node": n})
		"astraios":
			for p in _pad_ring(3, 9.0, PI * 0.33):
				var n := Node3D.new()
				world.add_child(n)
				n.position = p
				WorldKit.cylinder(n, 1.1, 0.25, Vector3(0, 0.12, 0), Color("#e9efff"), false)
				var barrel := WorldKit.cylinder(n, 0.45, 0.6, Vector3(0, 0.75, -0.2), Color("#9fd0ff"), false)
				barrel.rotation.x = -0.8
				pads.append({"kind": "cannon", "p": p, "r": 1.1, "node": n, "cd": 0.0})
		"grabstein":
			for k in 4:
				var a := -1.2 + k * 0.8
				var p := BOSS_HOME + Vector3(sin(a) * 5.0, 0, cos(a) * 4.0)
				var n := WorldKit.box(world, Vector3(1.1, 1.6, 0.4), p + Vector3(0, 0.8, 0), Color("#8a8a9a"), true)
				WorldKit.box(n, Vector3(0.7, 0.12, 0.42), Vector3(0, 0.3, 0), Color("#5a5a6a"), false)
				pads.append({"kind": "tomb", "p": p, "r": 0.8, "node": n, "hp": 2})
		"frostbart":
			for p in _pad_ring(3, 9.5, 0.4):
				var n := Node3D.new()
				world.add_child(n)
				n.position = p
				var mi := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.75
				sm.height = 1.5
				sm.material = WorldKit.mat(Color(1, 1, 1), 0.9, 0.15)
				mi.mesh = sm
				mi.position = Vector3(0, 0.75, 0)
				n.add_child(mi)
				pads.append({"kind": "snow", "p": p, "r": 1.3, "node": n, "got": false})
		"galaxus":
			for p in _pad_ring(3, 8.5, 0.0):
				var n := Node3D.new()
				world.add_child(n)
				n.position = p
				var g2 := WorldKit.cylinder(n, 1.25, 0.18, Vector3(0, 0.09, 0), Color("#d9a441"), false)
				g2.name = "Gear"
				for k in 10:
					var a2 := TAU * k / 10.0
					WorldKit.box(g2, Vector3(0.32, 0.18, 0.32), Vector3(cos(a2) * 1.35, 0, sin(a2) * 1.35), Color("#b07a2a"), false).rotation.y = -a2
				pads.append({"kind": "gear", "p": p, "r": 1.35, "node": n, "on": false, "occ": 0.0})
		"noxumbra":
			for p in _pad_ring(4, 8.0, PI * 0.25):
				var n := Node3D.new()
				world.add_child(n)
				n.position = p
				WorldKit.cylinder(n, 2.3, 0.04, Vector3(0, 0.03, 0), Color(0.37, 1.0, 0.88, 0.35), false)
				WorldKit.cylinder(n, 0.12, 0.7, Vector3(0, 0.35, 0), Color("#e8e0d0"), false)
				var cap := MeshInstance3D.new()
				var cs := SphereMesh.new()
				cs.radius = 0.6
				cs.height = 0.6
				cs.material = WorldKit.mat(Color("#5fffe0"), 0.4, 2.2)
				cap.mesh = cs
				cap.position = Vector3(0, 0.8, 0)
				n.add_child(cap)
				var l := OmniLight3D.new()
				l.light_color = Color("#5fffe0")
				l.light_energy = 1.2
				l.omni_range = 4.0
				l.position = Vector3(0, 1.2, 0)
				n.add_child(l)
				pads.append({"kind": "mush", "p": p, "r": 2.3, "node": n})
		"baahemoth":
			for p in [Vector3(-7.5, 0, 3.5), Vector3(7.5, 0, 3.5)]:
				var n := Node3D.new()
				world.add_child(n)
				n.position = p
				WorldKit.cylinder(n, 1.3, 0.14, Vector3(0, 0.07, 0), Color("#ff9f1a"), false)
				for sd in [-1.0, 1.0]:
					var b := WorldKit.box(n, Vector3(0.12, 0.9, 0.06), Vector3(sd * 0.18, 0.7, 0), Color("#e8eef8"), false)
					b.rotation.z = sd * 0.6
				pads.append({"kind": "duel", "p": p, "r": 1.3, "node": n})
		"marquise":
			for p in _pad_ring(3, 8.5, 0.5):
				var body := AnimatableBody3D.new()
				world.add_child(body)
				body.position = p
				var cs2 := CollisionShape3D.new()
				var cyl := CylinderShape3D.new()
				cyl.radius = 1.3
				cyl.height = 0.4
				cs2.shape = cyl
				body.add_child(cs2)
				WorldKit.cylinder(body, 1.3, 0.4, Vector3.ZERO, Color("#ffb3cf"), false)
				var ch := MeshInstance3D.new()
				var chs := SphereMesh.new()
				chs.radius = 0.45
				chs.height = 0.9
				chs.material = WorldKit.mat(Color("#e0203a"), 0.15, 0.2)
				ch.mesh = chs
				ch.position = Vector3(0, 0.6, -0.9)
				body.add_child(ch)
				pads.append({"kind": "lift", "p": p, "r": 1.3, "node": body, "state": "down", "t": 0.0})
		"zephyros":
			for p in _pad_ring(3, 8.5, 0.3):
				var n := Node3D.new()
				world.add_child(n)
				n.position = p
				WorldKit.cylinder(n, 1.1, 0.1, Vector3(0, 0.05, 0), Color("#bfe8ff"), false)
				var sw := FX.emitter({"amount": 14, "life": 1.0, "one_shot": false, "explosive": 0.0, "spread": 8.0, "vel_min": 3.0, "vel_max": 5.0,
					"gravity": Vector3.ZERO, "size": 0.2, "color": Color(1, 1, 1, 0.8), "box": Vector3(0.7, 0.1, 0.7)})
				sw.position = Vector3(0, 0.2, 0)
				n.add_child(sw)
				sw.emitting = true
				pads.append({"kind": "updraft", "p": p, "r": 1.1, "node": n, "cd": 0.0})


func setup_camera(c: ArenaCamera) -> void:
	# Blick etwas weiter zum Boss hin und steiler von oben: Der Boss steht so unterhalb der HP-Leiste und des
	# Timers im Bild statt dahinter, die Arena bleibt ganz sichtbar.
	c.fixed_center = Vector3(0, 0, -0.8)
	c.offset = Vector3(0, 20.5, 16.5)
	c.min_dist = 1.0
	c.max_dist = 1.0
	c.follow = false


func _build_hud() -> void:
	super._build_hud()
	var root := UI.center_root(hud)
	_fog_rect = ColorRect.new()
	_fog_rect.color = Color(0.75, 0.85, 0.9, 0.0)
	_fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_fog_rect)
	# Kompakte, halbtransparente Boss-Leiste (blendet sich aus, wenn der Boss dahinter steht)
	_bar = BossBar.new().setup(root, String(def.get("name", "Boss")), model)
	_say_label = UI.label("", 34, UI.GOLD, true, 10)
	_say_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_say_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_say_label)
	UI.place(_say_label, Control.PRESET_CENTER_BOTTOM, Vector2(-520, -170), Vector2(1040, 90))


func on_start() -> void:
	for i in 4:
		var av := avatars[i] as PartyAvatar
		av.can_shove = false
		av.kill_y = -6.0
		av.max_speed = SPEED
	for c in get_children():
		if c is WorldEnvironment and (c as WorldEnvironment).environment:
			(c as WorldEnvironment).environment.fog_density *= 0.35
		if c is DirectionalLight3D:
			_sun = c
	for c2 in world.get_children():
		if c2 is DirectionalLight3D:
			_sun = c2
	if _is_host_model_client():
		return
	_act("roar")
	_say("%s!" % def.name, 2.0)
	get_tree().create_timer(2.2).timeout.connect(func() -> void: _say(String(def.unique), 3.2))


func _say(text: String, hold := 1.6) -> void:
	_say_text = text
	_say_until = _t + hold
	if _say_label:
		_say_label.text = text
		Juice.ui_punch(_say_label, 0.1, 0.25)


func _act(kind: String) -> void:
	_act_seq += 1
	_act_kind = kind
	if model and kind != "defeat":
		model.act(kind)


# --- Spielschleife (Host) ---------------------------------------------------------------------------------------

func on_tick(delta: float) -> void:
	if defeated:
		return
	_update_status(delta)
	_update_ammo(delta)
	_update_pads(delta)
	_update_hazards(delta)
	_update_unique(delta)
	_boss_ai(delta)
	for i in active_slots():
		var av := avatars[i] as PartyAvatar
		if av.global_position.y < -4.0 or Vector2(av.global_position.x, av.global_position.z).length() > R + 3.0:
			av.respawn(Vector3(rng.randf_range(-3, 3), 1.5, 6.0))
			_coins(i, -2)
			_drop_carry(i)


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	if model:
		model.position = model.position.lerp(boss_pos, clampf(delta * 6.0, 0.0, 1.0))
	for o in ammo:
		var n: Node3D = o.node
		if int(o.holder) >= 0:
			n.position = (avatars[int(o.holder)] as Node3D).global_position + Vector3.UP * 2.3
		else:
			n.rotation.y += delta * 2.5
			n.position.y = 0.8 + sin(_t * 3.0 + n.position.x) * 0.12
	if _say_label and _t > _say_until and _say_label.text != "":
		_say_label.text = ""
		_say_text = ""
	if _fog_rect:
		_fog_rect.color.a = lerpf(_fog_rect.color.a, 0.62 if fog_t > 0.0 else 0.0, clampf(delta * 3.0, 0.0, 1.0))
	_refresh_hp()
	for h in hazards:
		_hz_draw(h)
	_hz_cleanup()


func _update_status(delta: float) -> void:
	armor_t = maxf(0.0, armor_t - delta)
	invert_t = maxf(0.0, invert_t - delta)
	slip_t = maxf(0.0, slip_t - delta)
	fog_t = maxf(0.0, fog_t - delta)
	_wind_t = maxf(0.0, _wind_t - delta)
	for i in active_slots():
		var av := avatars[i] as PartyAvatar
		var st := status[i]
		var sp := SPEED
		if flood and av.global_position.y < 0.5 and not _on_kind(av.global_position, "sand"):
			sp *= 0.55
		if float(st.get("frozen", 0.0)) > 0.0:
			st.frozen = float(st.frozen) - delta
			sp *= 0.45
		for h in hazards:
			if String(h.kind) == "zone" and String(h.eff) == "slow" and float(h.t) > float(h.warn) and _in_circle(av.global_position, h.p, float(h.r)):
				sp *= 0.38
		av.max_speed = sp
		av.slippery = 0.85 if slip_t > 0.0 else 0.0
		av.input_mult = -1.0 if invert_t > 0.0 else 1.0
		var in_duel := not _duel.is_empty() and i in [int(_duel.get("a", -1)), int(_duel.get("b", -1))]
		if int(st.get("bubble", 0)) > 0:
			av.can_move = false
			av.can_jump = false
			if InputHub.pressed(i, "a") or InputHub.pressed(i, "b"):
				st.bubble = int(st.bubble) - 1
				Juice.squash(av.rig, 1.1, 0.9, 0.1)
				if int(st.bubble) <= 0:
					_pop_bubble(i)
		elif not in_duel:
			av.can_move = true
			av.can_jump = true
		if _wind_t > 0.0 and av.is_on_floor():
			var w := _wind
			if w == Vector3.ZERO:
				w = Vector3(av.global_position.x - boss_pos.x, 0, av.global_position.z - boss_pos.z).normalized() * 9.0
			av.velocity += w * delta


func _on_kind(p: Vector3, kind: String) -> bool:
	for pd in pads:
		if String(pd.kind) == kind and _in_circle(p, pd.p, float(pd.r)):
			return true
	return false


func _in_circle(p: Vector3, c: Vector3, r: float) -> bool:
	return Vector2(p.x - c.x, p.z - c.z).length() <= r


# --- Wurfgeschosse ----------------------------------------------------------------------------------------------

func _ammo_node() -> Node3D:
	var n := Node3D.new()
	world.add_child(n)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.36
	sm.height = 0.72
	var col: Color = def.ammo[1]
	sm.material = WorldKit.mat(col, 0.35, 0.6)
	mi.mesh = sm
	n.add_child(mi)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.45
	tm.outer_radius = 0.55
	tm.material = WorldKit.mat(Color(1, 1, 1), 0.3, 0.8)
	ring.mesh = tm
	ring.rotation.x = PI * 0.5
	n.add_child(ring)
	return n


func _update_ammo(delta: float) -> void:
	var want := 2 + int(ceil(active_slots().size() / 2.0))
	var free := 0
	for o in ammo:
		if int(o.holder) < 0:
			free += 1
	if free < want and rng.randf() < delta * (0.75 if free > 0 else 2.0):
		for tries in 12:
			var a := rng.randf() * TAU
			var rr := rng.randf_range(3.0, R - 1.5)
			var p := Vector3(cos(a) * rr, 0.8, sin(a) * rr)
			if p.distance_to(boss_pos) < 5.0 or _hazard_at(p):
				continue
			var n := _ammo_node()
			n.position = p
			Juice.pop_in(n, 0.3)
			ammo.append({"node": n, "holder": -1})
			break
	for o in ammo:
		if int(o.holder) >= 0:
			continue
		var n2: Node3D = o.node
		for i in active_slots():
			if not carry[i] and (avatars[i] as Node3D).global_position.distance_to(n2.position) < 1.25:
				carry[i] = true
				o.holder = i
				Audio.sfx("item_get", n2.position, -6.0)
				break
	for i in active_slots():
		if carry[i] and InputHub.pressed(i, "b") and int(status[i].get("bubble", 0)) <= 0:
			_throw(i)
	for c in pickups.duplicate():
		for i in active_slots():
			if (avatars[i] as Node3D).global_position.distance_to(c.p) < 1.1:
				_coins(i, 1)
				(c.node as Node3D).queue_free()
				pickups.erase(c)
				break


func _hazard_at(p: Vector3) -> bool:
	for h in hazards:
		if String(h.kind) == "zone" and _in_circle(p, h.p, float(h.r) + 0.5):
			return true
	return false


func _drop_carry(i: int) -> void:
	if not carry[i]:
		return
	carry[i] = false
	for o in ammo:
		if int(o.holder) == i:
			(o.node as Node3D).queue_free()
			ammo.erase(o)
			break


func _throw(i: int) -> void:
	carry[i] = false
	var orb: Dictionary = {}
	for o in ammo:
		if int(o.holder) == i:
			orb = o
	if orb.is_empty():
		return
	ammo.erase(orb)
	var n: Node3D = orb.node
	var av := avatars[i] as PartyAvatar
	av.rig.play("throw", 0.05, 1.5, true)
	var high := av.global_position.y > 2.4
	var lit := _on_kind(av.global_position, "mush")
	var tomb := _nearest_tomb(av.global_position)
	var to := boss_pos + Vector3(rng.randf_range(-0.6, 0.6), 3.2, 0.8)
	if not tomb.is_empty():
		to = (tomb.node as Node3D).global_position
	var from := n.position
	var dist := from.distance_to(to)
	var arc := func(t: float) -> void:
		n.position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * (2.0 + dist * 0.12)
	var tw := create_tween()
	tw.tween_method(arc, 0.0, 1.0, 0.3 + dist * 0.025)
	tw.tween_callback(func() -> void:
		n.queue_free()
		_impact(i, tomb, high, lit, dist))


func _nearest_tomb(p: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var bd := INF
	for pd in pads:
		if String(pd.kind) == "tomb" and int(pd.hp) > 0:
			var d := p.distance_to(pd.p)
			if d < bd:
				bd = d
				best = pd
	return best


func _tombs_left() -> int:
	var n := 0
	for pd in pads:
		if String(pd.kind) == "tomb" and int(pd.hp) > 0:
			n += 1
	return n


func _impact(i: int, tomb: Dictionary, high: bool, lit: bool, dist: float) -> void:
	if defeated or state != "play":
		return
	if not tomb.is_empty():
		tomb.hp = int(tomb.hp) - 1
		var tn: Node3D = tomb.node
		FX.smoke(tn.global_position, Color(0.6, 0.6, 0.7), 12, 1.0)
		Audio.sfx("stone_hit", tn.global_position, -2.0)
		scores[i] += 1.0
		if int(tomb.hp) <= 0:
			tn.create_tween().tween_property(tn, "rotation:x", -PI * 0.48, 0.3)
			var left := _tombs_left()
			_say("Grabstein zerstört!" + (" Noch %d." % left if left > 0 else " Der Graf ist verwundbar!"), 1.6)
		return
	if dist > 20.0:
		return
	if boss_id == "noxumbra" and night and not lit:
		FX.dust(boss_pos + Vector3.UP * 2.0, Color(0.4, 0.4, 0.5), 8, 0.6)
		_say("Verfehlt – im Schatten! Werft aus dem Pilzlicht.", 1.4)
		return
	if armor_t > 0.0:
		FX.sparks(boss_pos + Vector3.UP * 2.5, UI.GOLD, 16)
		Audio.sfx("metal_hit", boss_pos, -2.0)
		_coins(i, 2)
		return
	var dmg := 2.5
	if high:
		dmg *= 2.0
	if overclock_t > 0.0:
		dmg *= 2.0
	if _stun_boss_t > 0.0:
		dmg *= 1.5
	if boss_id == "frostbart" and frost_armor:
		dmg *= 0.5
	_damage(i, dmg, "Höhenbonus ×2!" if high else "")


func _damage(i: int, dmg: float, note := "") -> void:
	if defeated:
		return
	dmg = minf(dmg, hp)
	hp -= dmg
	scores[i] += dmg
	model.hit()
	FX.sparks(boss_pos + Vector3(0, 3.0, 1.5), Game.player_color(i), 22)
	FX.stars(boss_pos + Vector3(0, 4.0, 1.0), UI.GOLD, 8)
	Audio.sfx("punch", boss_pos, 0.0, 0.9)
	Juice.float_text(self, boss_pos + Vector3(rng.randf_range(-1.5, 1.5), 5.5, 1.5), ("-%d" % int(round(dmg))) + ("  " + note if note != "" else ""), Game.player_color(i).lightened(0.3), 110)
	if hp <= 0.0:
		scores[i] += 5.0
		_defeat(i)
		return
	var np := 1 if hp > max_hp * 0.66 else (2 if hp > max_hp * 0.33 else 3)
	if np > bphase:
		bphase = np
		model.set_rage(bphase - 1)
		_act_seq += 1
		_act_kind = "rage%d" % bphase
		_stun_boss_t = 2.2
		_atk_cd = 2.6
		_say(("Phase 2! %s ist benommen – und wird gleich wütend!" % def.name) if bphase == 2 else ("WUT-PHASE! %s greift jetzt doppelt an!" % def.name), 2.0)


# --- Spezial-Orte -----------------------------------------------------------------------------------------------

func _update_pads(delta: float) -> void:
	_duel_cd = maxf(0.0, _duel_cd - delta)
	var gears_on := 0
	for pd in pads:
		var on: Array[int] = []
		for i in active_slots():
			var av := avatars[i] as PartyAvatar
			if _in_circle(av.global_position, pd.p, float(pd.r)) and av.global_position.y < float((pd.node as Node3D).position.y) + 2.0:
				on.append(i)
		match String(pd.kind):
			"crack":
				if int(pd.hp) > 0:
					if not on.is_empty():
						pd.occ = float(pd.occ) + delta
						if float(pd.occ) > 1.0:
							pd.occ = 0.0
							pd.hp = int(pd.hp) - 1
							var n: Node3D = pd.node
							FX.dust(n.global_position + Vector3.UP * 0.2, Color(0.5, 0.35, 0.3), 12, 1.0)
							Audio.sfx("plank_break", n.global_position, -4.0)
							if int(pd.hp) <= 0:
								_collapse(pd)
					else:
						pd.occ = maxf(0.0, float(pd.occ) - delta * 0.5)
				else:
					for i in on:
						if (avatars[i] as PartyAvatar).global_position.y < 0.4:
							_hurt(i, "burn", pd.p)
							(avatars[i] as PartyAvatar).respawn(Vector3(rng.randf_range(-3, 3), 1.5, 6.0))
			"cannon":
				pd.cd = maxf(0.0, float(pd.cd) - delta)
				if float(pd.cd) <= 0.0 and not on.is_empty() and (avatars[on[0]] as PartyAvatar).is_on_floor():
					pd.cd = 2.5
					_cannon_launch(on[0])
			"snow":
				if not bool(pd.got) and not on.is_empty():
					pd.got = true
					(pd.node as Node3D).visible = false
					Audio.sfx("plop", pd.p, -2.0)
					var got := 0
					for p2 in pads:
						if String(p2.kind) == "snow" and bool(p2.got):
							got += 1
					scores[on[0]] += 2.0
					if got >= 3:
						frost_armor = false
						model.hit()
						FX.explosion(boss_pos + Vector3.UP * 3.0, 1.5)
						_say("Drei Riesen-Schneebälle – die Frost-Rüstung zerspringt!", 2.0)
					else:
						_say("Riesen-Schneeball %d/3!" % got, 1.2)
			"gear":
				if not bool(pd.on):
					if not on.is_empty():
						pd.occ = float(pd.occ) + delta
						if float(pd.occ) > 1.4:
							pd.on = true
							Audio.sfx("wheel_tick", pd.p, -2.0)
							scores[on[0]] += 1.0
					else:
						pd.occ = 0.0
				var g: Node3D = (pd.node as Node3D).get_node("Gear")
				g.rotation.y += delta * (6.0 if bool(pd.on) else 0.4 + float(pd.occ) * 3.0)
				if bool(pd.on):
					gears_on += 1
			"updraft":
				pd.cd = maxf(0.0, float(pd.cd) - delta)
				for i in on:
					var av2 := avatars[i] as PartyAvatar
					if av2.is_on_floor() and float(pd.cd) <= 0.0:
						av2.velocity.y = 17.0
						pd.cd = 0.4
						Audio.sfx("whoosh", av2.global_position, -4.0, 1.3)
						FX.ring(av2.global_position, Color(1, 1, 1, 0.8), 1.4, 0.4)
			"lift":
				_update_lift(pd, on, delta)
	if boss_id == "galaxus":
		if overclock_t > 0.0:
			overclock_t -= delta
			if overclock_t <= 0.0:
				for pd2 in pads:
					pd2.on = false
					pd2.occ = 0.0
		elif gears_on >= 3:
			overclock_t = 7.0
			_stun_boss_t = 7.0
			_act("timejump")
			_say("Alle Uhrwerke synchron – Galaxus gerät aus dem Takt! Doppelter Schaden!", 2.4)
	if boss_id == "baahemoth":
		_update_duel(delta)


func _collapse(pd: Dictionary) -> void:
	var n: Node3D = pd.node
	for c in n.get_children():
		(c as Node3D).visible = String(c.name) == "Lava"
	FX.explosion(n.global_position, 0.7)
	_say("Der Boden bricht ein – darunter brodelt Lava!", 1.4)


func _cannon_launch(i: int) -> void:
	var av := avatars[i] as PartyAvatar
	av.set_physics_process(false)
	_drop_carry(i)
	Audio.sfx("cannon", av.global_position, -2.0)
	FX.smoke(av.global_position, Color(1, 1, 1), 14, 1.2)
	var from := av.global_position
	var to := boss_pos + Vector3(rng.randf_range(-2.0, 2.0), 0.6, -4.0)
	var arc := func(t: float) -> void:
		av.global_position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * 9.0
	var tw := create_tween()
	tw.tween_method(arc, 0.0, 1.0, 1.1)
	tw.tween_callback(func() -> void:
		av.set_physics_process(true)
		av.velocity = Vector3.ZERO
		if not defeated:
			_damage(i, 7.0 if not (boss_id == "frostbart" and frost_armor) else 3.5, "Rückenangriff!"))


func _update_lift(pd: Dictionary, on: Array[int], delta: float) -> void:
	var body: AnimatableBody3D = pd.node
	pd.t = float(pd.t) + delta
	match String(pd.state):
		"down":
			if not on.is_empty() and float(pd.t) > 0.6:
				pd.state = "up"
				pd.t = 0.0
				Audio.sfx("woop", body.global_position, -4.0)
				body.create_tween().tween_property(body, "position:y", 4.2, 1.2).set_trans(Tween.TRANS_SINE)
		"up":
			if float(pd.t) > 7.0:
				pd.state = "lower"
				pd.t = 0.0
				body.create_tween().tween_property(body, "position:y", 0.0, 1.2).set_trans(Tween.TRANS_SINE)
		"lower":
			if float(pd.t) > 1.3:
				pd.state = "down"
				pd.t = 0.0


func _update_duel(delta: float) -> void:
	if pads.size() < 2:
		return
	if _duel.is_empty():
		if _duel_cd > 0.0:
			return
		var on0: Array[int] = []
		var on1: Array[int] = []
		for i in active_slots():
			var p := (avatars[i] as Node3D).global_position
			if _in_circle(p, pads[0].p, 1.3):
				on0.append(i)
			elif _in_circle(p, pads[1].p, 1.3):
				on1.append(i)
		if not on0.is_empty() and not on1.is_empty():
			_duel = {"a": on0[0], "b": on1[0], "ca": 0, "cb": 0, "t": 3.0}
			for i in [on0[0], on1[0]]:
				(avatars[i] as PartyAvatar).can_move = false
			_say("Hämmer-Duell! %s gegen %s – A hämmern!" % [_pname(on0[0]), _pname(on1[0])], 3.0)
		return
	_duel.t = float(_duel.t) - delta
	if InputHub.pressed(int(_duel.a), "a"):
		_duel.ca = int(_duel.ca) + 1
	if InputHub.pressed(int(_duel.b), "a"):
		_duel.cb = int(_duel.cb) + 1
	if float(_duel.t) <= 0.0:
		var w := int(_duel.a) if int(_duel.ca) >= int(_duel.cb) else int(_duel.b)
		scores[w] += 4.0
		(avatars[w] as PartyAvatar).rig.react("cheer")
		_float(w, "+4 Duell-Sieg", UI.GOLD)
		_say("%s gewinnt das Duell (%d:%d)!" % [_pname(w), maxi(int(_duel.ca), int(_duel.cb)), mini(int(_duel.ca), int(_duel.cb))], 1.6)
		for i in [int(_duel.a), int(_duel.b)]:
			(avatars[i] as PartyAvatar).can_move = true
		_duel = {}
		_duel_cd = 9.0


func _update_unique(delta: float) -> void:
	match boss_id:
		"klabautox":
			_flood_force = maxf(0.0, _flood_force - delta)
			_flood_t += delta
			var want := _flood_force > 0.0 or fmod(_flood_t, 16.0) > 10.0
			if want != flood:
				flood = want
				_set_flood(flood)
				_say("Flut! Rettet euch auf die Sandbänke!" if flood else "Ebbe – das Wasser zieht sich zurück.", 1.4)
		"noxumbra":
			_night_force = maxf(0.0, _night_force - delta)
			_night_t += delta
			var want2 := _night_force > 0.0 or fmod(_night_t, 20.0) > 11.0
			if want2 != night:
				night = want2
				_set_night(night)
				_say("Die Nacht bricht herein – nur aus dem Pilzlicht trefft ihr sie!" if night else "Es wird Tag.", 1.6)


# --- Boss-KI ----------------------------------------------------------------------------------------------------

func _boss_ai(delta: float) -> void:
	if _stun_boss_t > 0.0:
		_stun_boss_t -= delta
		if model:
			model.rotation.z = sin(_t * 9.0) * 0.06
		return
	if model:
		model.rotation.z = 0.0
	var charging := false
	for h in hazards:
		if String(h.kind) == "charge":
			charging = true
	if not charging:
		var drift := BOSS_HOME + Vector3(sin(_t * 0.35) * 2.5, 0, 0)
		boss_pos = boss_pos.lerp(drift, clampf(delta * 1.2, 0.0, 1.0))
	if _double_t > 0.0:
		_double_t -= delta
		if _double_t <= 0.0:
			_use_ability()
	_atk_cd -= delta
	if _atk_cd <= 0.0:
		_atk_cd = [4.6, 3.6, 3.0][bphase - 1]
		_use_ability()
		if bphase >= 3:
			_double_t = 1.2


func _use_ability() -> void:
	var abil: Array = def.abilities
	var avail := 2 if bphase == 1 else 3
	var pick: Array = abil[rng.randi() % avail]
	var guard := 0
	while String(pick[0]) == _last_ability and guard < 6:
		pick = abil[rng.randi() % avail]
		guard += 1
	_last_ability = String(pick[0])
	_say("%s: %s!" % [def.name, pick[1]], 1.4)
	_act(_anim_for(String(pick[0])))
	_ability(String(pick[0]))


func _anim_for(ab: String) -> String:
	return {"lava": "breath", "tail": "tail", "armor": "curl", "tsunami": "wave", "bubble": "breath", "claw": "pinch",
		"comet": "comet", "cannonade": "gust", "gravity": "gravity", "soulsteal": "steal", "taxi": "spin", "fog": "breath",
		"iceslide": "spin", "avalanche": "stomp", "frostbreath": "frost", "timejump": "timejump", "rockets": "roar", "nova": "slam",
		"darkness": "roar", "roots": "slam", "spores": "breath", "ramstorm": "ram", "sheepflood": "roar", "dandelion": "gust",
		"caramel": "breath", "candleflame": "flame", "cherrybomb": "lunge", "gust": "gust", "whirl": "spin", "seedstorm": "storm"}.get(ab, "roar")


func _players() -> Array[int]:
	var out: Array[int] = []
	for i in active_slots():
		if (avatars[i] as PartyAvatar).alive:
			out.append(i)
	return out


func _rand_player() -> int:
	var ps := _players()
	return ps[rng.randi() % ps.size()] if not ps.is_empty() else 0


func _ppos(i: int) -> Vector3:
	var p := (avatars[i] as Node3D).global_position
	return Vector3(p.x, 0, p.z)


func _rand_spot(min_boss := 4.5) -> Vector3:
	for k in 20:
		var a := rng.randf() * TAU
		var rr := rng.randf_range(1.5, R - 1.5)
		var p := Vector3(cos(a) * rr, 0, sin(a) * rr)
		if p.distance_to(boss_pos) > min_boss:
			return p
	return Vector3(0, 0, 5)


func _angle_to_player() -> float:
	var p := _ppos(_rand_player())
	return atan2(p.x - boss_pos.x, p.z - boss_pos.z)


func _ability(ab: String) -> void:
	var ps := _players()
	if ps.is_empty():
		return
	match ab:
		"lava":
			for k in 3 + bphase:
				var p := _ppos(ps[k]) if k < ps.size() else _rand_spot()
				_zone(p, 2.2, 1.3, 6.0, "burn")
		"tail":
			var face := _angle_to_player()
			_sweep(boss_pos, 2.0, 12.0, face - 1.6, face + 1.6, 1.1, 1.0, "hit", Color("#ff8a5c"))
		"armor":
			armor_t = 6.0
			FX.sparks(boss_pos + Vector3.UP * 2.0, UI.GOLD, 30)
			_say("Schatz-Panzerung! Würfe prallen ab – lassen aber Münzen fallen.", 2.0)
		"tsunami":
			_ring(boss_pos, 6.5, 1.0, "hit", Color(0.4, 0.75, 1.0, 0.85), true)
			_flood_force = 8.0
		"bubble":
			for k in mini(2, ps.size()):
				_proj(boss_pos + Vector3(0, 2.0, 2.0), ps[(k + rng.randi()) % ps.size()], 4.2, "trap", 5.0)
		"claw":
			var tgt := _nearest_player(boss_pos)
			_zone(_ppos(tgt), 2.0, 0.9, 0.2, "grab")
		"comet":
			for p in ps:
				_zone(_ppos(p), 1.8, 1.4, 0.25, "stun")
			for k in 2 + bphase:
				_zone(_rand_spot(), 1.8, 1.4, 0.25, "stun")
		"cannonade", "gust":
			_wind = Vector3.ZERO if ab == "cannonade" else Vector3(rng.randf_range(-1, 1), 0, 1.0).normalized() * 10.0
			_wind_t = 3.0
			FX.shockwave(boss_pos, 10.0, Color(1, 1, 1, 0.7))
		"gravity":
			invert_t = 5.0
			_say("Gravitations-Umkehr – eure Steuerung ist vertauscht!", 2.0)
		"soulsteal":
			for k in mini(2, ps.size()):
				_proj(boss_pos + Vector3(0, 3.0, 1.5), ps[(k + rng.randi()) % ps.size()], 3.6, "steal", 6.0)
		"taxi":
			var p2 := _rand_player()
			var av := avatars[p2] as PartyAvatar
			FX.smoke(av.global_position, Color(0.7, 1.0, 0.9), 16, 1.2)
			_drop_carry(p2)
			av.global_position = _rand_spot(3.0) + Vector3.UP * 1.0
			av.velocity = Vector3.ZERO
			av.stun(0.8)
			FX.smoke(av.global_position, Color(0.7, 1.0, 0.9), 16, 1.2)
			_say("Geister-Taxi! %s wird entführt." % _pname(p2), 1.4)
		"fog":
			fog_t = 6.0
		"iceslide":
			slip_t = 6.0
			_say("Eisrutschen-Chaos – alles spiegelglatt!", 1.6)
		"avalanche":
			for k in 4 + bphase:
				var pp := _ppos(ps[k]) if k < ps.size() else _rand_spot()
				_zone(pp, 1.6, 1.2, 4.0, "freeze")
		"frostbreath":
			var f := _angle_to_player()
			_sweep(boss_pos, 1.5, 12.0, f - 0.9, f + 0.9, 1.0, 0.9, "freeze", Color(0.7, 0.95, 1.0))
		"timejump":
			var undone := false
			for pd in pads:
				if String(pd.get("kind", "")) == "gear" and bool(pd.on):
					pd.on = false
					undone = true
					break
			boss_pos = BOSS_HOME + Vector3(rng.randf_range(-3, 3), 0, 0)
			_say("Zeitsprung! Ein Uhrwerk springt zurück." if undone else "Zeitsprung!", 1.4)
		"rockets":
			for k in mini(3, ps.size() + 1):
				_proj(boss_pos + Vector3(0, 3.0, 1.0), ps[k % ps.size()], 5.5, "hit", 4.0)
		"nova":
			_ring(boss_pos, 8.0, 1.0, "stun", Color(0.85, 0.8, 1.0, 0.9), false)
		"darkness":
			_night_force = 10.0
		"roots":
			for p in ps:
				_zone(_ppos(p), 1.5, 1.1, 0.4, "root")
		"spores":
			invert_t = 4.5
			FX.smoke(boss_pos + Vector3.UP * 3.0, Color(0.8, 0.6, 1.0), 30, 3.0)
			_say("Sporen-Wolke – Steuerung vertauscht!", 1.6)
		"ramstorm":
			var tgt2 := _ppos(_rand_player())
			var dir := tgt2 - boss_pos
			dir.y = 0.0
			dir = dir.normalized()
			_charge(boss_pos, boss_pos + dir * 15.0, 1.1, 1.0)
		"sheepflood":
			for k in 6 + bphase * 2:
				var side := -1.0 if k % 2 == 0 else 1.0
				var z := rng.randf_range(-8.0, 9.0)
				_minion(Vector3(side * (R + 1.0), 0, z), Vector3(-side, 0, rng.randf_range(-0.2, 0.2)).normalized(), rng.randf_range(4.5, 7.0), k * 0.25)
		"dandelion", "seedstorm":
			for k in 2:
				_tornado(_rand_spot(), 6.0)
			if ab == "seedstorm":
				for k2 in 3:
					_zone(_rand_spot(), 1.6, 1.2, 0.2, "hit")
		"whirl":
			for k in 1 + bphase:
				_tornado(_rand_spot(), 6.5)
		"caramel":
			for k in 3:
				var p3 := _ppos(ps[k]) if k < ps.size() else _rand_spot()
				_zone(p3, 2.4, 1.0, 7.0, "slow")
		"candleflame":
			var f2 := _angle_to_player()
			_sweep(boss_pos, 1.5, 11.0, f2 - 1.1, f2 + 1.1, 1.0, 1.0, "burn", Color(1.0, 0.6, 0.2))
		"cherrybomb":
			_bomb(_rand_spot(3.5), 5.0)


func _nearest_player(p: Vector3) -> int:
	var best := _rand_player()
	var bd := INF
	for i in _players():
		var d := _ppos(i).distance_to(p)
		if d < bd:
			bd = d
			best = i
	return best


# --- Gefahren ---------------------------------------------------------------------------------------------------

func _new_hazard(kind: String, eff: String, p: Vector3, r: float, warn: float, dur: float) -> Dictionary:
	_hz_id += 1
	var h := {"id": _hz_id, "kind": kind, "eff": eff, "p": p, "r": r, "warn": warn, "dur": dur, "t": 0.0, "hit": {},
		"a0": 0.0, "a1": 0.0, "to": Vector3.ZERO, "target": -1, "speed": 0.0, "dir": Vector3.ZERO, "col": Color(1, 0.3, 0.3)}
	hazards.append(h)
	return h


func _zone(p: Vector3, r: float, warn: float, dur: float, eff: String) -> void:
	_new_hazard("zone", eff, p, r, warn, dur)


func _sweep(c: Vector3, r_in: float, r_out: float, a0: float, a1: float, warn: float, dur: float, eff: String, col: Color) -> void:
	var h := _new_hazard("sweep", eff, c, r_out, warn, dur)
	h.a0 = a0
	h.a1 = a1
	h.speed = r_in
	h.col = col


func _ring(c: Vector3, speed: float, warn: float, eff: String, col: Color, sand_safe: bool) -> void:
	var h := _new_hazard("ring", eff, c, 0.0, warn, (R + 2.0) / speed)
	h.speed = speed
	h.col = col
	h.target = 1 if sand_safe else 0


func _charge(from: Vector3, to: Vector3, warn: float, dur: float) -> void:
	var h := _new_hazard("charge", "hit", from, 2.0, warn, dur)
	h.to = to


func _proj(p: Vector3, target: int, speed: float, eff: String, life: float) -> void:
	var h := _new_hazard("proj", eff, p, 0.9, 0.3, life)
	h.target = target
	h.speed = speed


func _minion(p: Vector3, dir: Vector3, speed: float, delay: float) -> void:
	var h := _new_hazard("minion", "hit", p, 0.8, delay, 7.0)
	h.dir = dir
	h.speed = speed


func _bomb(p: Vector3, fuse: float) -> void:
	_new_hazard("bomb", "burn", p, 3.6, fuse, 0.3)


func _tornado(p: Vector3, life: float) -> void:
	var h := _new_hazard("tornado", "fling", p, 1.3, 0.6, life)
	h.dir = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()


func _update_hazards(delta: float) -> void:
	for h in hazards.duplicate():
		h.t = float(h.t) + delta
		var t: float = h.t
		var warn: float = h.warn
		var active := t >= warn
		var kind := String(h.kind)
		match kind:
			"zone":
				if active and not bool(h.get("boomed", false)):
					h.boomed = true
					_zone_burst(h)
				if active:
					for i in _players():
						var av := avatars[i] as PartyAvatar
						if _in_circle(av.global_position, h.p, float(h.r)) and av.global_position.y < 1.4:
							_hit_once(h, i, Vector3(h.p))
			"sweep":
				if active:
					var k := clampf((t - warn) / float(h.dur), 0.0, 1.0)
					var ang := lerpf(float(h.a0), float(h.a1), k)
					for i in _players():
						var av2 := avatars[i] as PartyAvatar
						var d := Vector2(av2.global_position.x - h.p.x, av2.global_position.z - h.p.z)
						if d.length() < float(h.speed) or d.length() > float(h.r) or av2.global_position.y > 0.95:
							continue
						var pa := atan2(d.x, d.y)
						if absf(wrapf(pa - ang, -PI, PI)) < 0.2:
							_hit_once(h, i, Vector3(h.p))
			"ring":
				if active:
					var rad := (t - warn) * float(h.speed)
					h.r = rad
					for i in _players():
						var av3 := avatars[i] as PartyAvatar
						var dd := Vector2(av3.global_position.x - h.p.x, av3.global_position.z - h.p.z).length()
						if absf(dd - rad) < 0.7 and av3.global_position.y < 0.9:
							if int(h.target) == 1 and _on_kind(av3.global_position, "sand"):
								continue
							_hit_once(h, i, Vector3(h.p))
			"charge":
				if active:
					var k2 := clampf((t - warn) / float(h.dur), 0.0, 1.0)
					var from: Vector3 = h.p
					var to: Vector3 = h.to
					var bp := from.lerp(to, smoothstep(0.0, 1.0, k2))
					var edge := Vector2(bp.x, bp.z)
					if edge.length() > R - 2.5:
						edge = edge.normalized() * (R - 2.5)
					boss_pos = Vector3(edge.x, 0, edge.y)
					for i in _players():
						if _ppos(i).distance_to(boss_pos) < 2.6:
							_hit_once(h, i, boss_pos)
			"proj":
				if active:
					var tg := int(h.target)
					var tp := _ppos(tg) + Vector3.UP * 1.0 if tg >= 0 else Vector3(h.p)
					var pp: Vector3 = h.p
					pp = pp.move_toward(tp, float(h.speed) * delta)
					h.p = pp
					for i in _players():
						if (avatars[i] as Node3D).global_position.distance_to(pp) < float(h.r) + 0.3:
							_hit_once(h, i, pp)
							h.t = warn + float(h.dur)
			"minion":
				if active:
					var mp: Vector3 = h.p
					mp += (h.dir as Vector3) * float(h.speed) * delta
					h.p = mp
					for i in _players():
						var av4 := avatars[i] as PartyAvatar
						if _in_circle(av4.global_position, mp, float(h.r)) and av4.global_position.y < 0.9:
							_hit_once(h, i, mp)
			"bomb":
				if active and not bool(h.get("boomed", false)):
					h.boomed = true
					FX.explosion(Vector3(h.p) + Vector3.UP * 0.5, 1.4)
					for i in _players():
						if _in_circle(_ppos(i), h.p, float(h.r)):
							_hit_once(h, i, Vector3(h.p))
					for k3 in 6:
						var a := TAU * k3 / 6.0
						_spawn_coin(Vector3(h.p) + Vector3(cos(a), 0, sin(a)) * 2.0)
					_say("BUMM! Die Kirsch-Bombe verstreut Münzen!", 1.4)
			"tornado":
				if active:
					var tp2: Vector3 = h.p
					tp2 += (h.dir as Vector3) * 2.2 * delta
					if Vector2(tp2.x, tp2.z).length() > R - 1.5:
						h.dir = -(h.dir as Vector3)
					if rng.randf() < delta * 0.6:
						h.dir = (h.dir as Vector3).rotated(Vector3.UP, rng.randf_range(-1.2, 1.2))
					h.p = tp2
					for i in _players():
						var av5 := avatars[i] as PartyAvatar
						var dv := tp2 - _ppos(i)
						dv.y = 0.0
						if dv.length() < 4.5 and av5.is_on_floor():
							av5.velocity += dv.normalized() * 7.0 * delta
						if dv.length() < float(h.r):
							_hit_once(h, i, tp2)
		if float(h.t) >= warn + float(h.dur):
			hazards.erase(h)


func _hit_once(h: Dictionary, i: int, from: Vector3) -> void:
	var hit: Dictionary = h.hit
	var key := str(i)
	var now := float(h.t)
	if hit.has(key) and (String(h.eff) != "burn" or now - float(hit[key]) < 1.0):
		return
	hit[key] = now
	_hurt(i, String(h.eff), from)


func _hurt(i: int, eff: String, from: Vector3) -> void:
	var av := avatars[i] as PartyAvatar
	if not av.alive:
		return
	var away := av.global_position - from
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(0, 0, 1)
	match eff:
		"hit":
			av.apply_knockback(away, 11.0, 0.55, 5.0)
			av.rig.react("hit")
			_coins(i, -1)
			_drop_carry(i)
		"burn":
			av.apply_knockback(away, 9.0, 0.6, 6.0)
			av.rig.react("soot_blast")
			FX.embers(av.global_position + Vector3.UP, 10)
			_coins(i, -2)
			_drop_carry(i)
		"freeze":
			av.stun(1.3)
			status[i]["frozen"] = 3.0
			FX.smoke(av.global_position + Vector3.UP, Color(0.75, 0.95, 1.0), 12, 1.0)
			_float(i, "Eingefroren!", Color("#9fe8ff"))
		"root":
			av.stun(1.8)
			FX.dust(av.global_position, Color(0.35, 0.25, 0.15), 14, 1.2)
			_float(i, "Wurzel-Schlinge!", Color("#9fe07a"))
		"stun":
			av.stun(1.4)
			FX.dizzy_stars(av, 2.4, 1.4)
			_drop_carry(i)
		"trap":
			if int(status[i].get("bubble", 0)) > 0:
				return
			status[i]["bubble"] = 6
			_drop_carry(i)
			_float(i, "Blasen-Gefängnis! A hämmern!", Color("#9fe8ff"))
			var bub := MeshInstance3D.new()
			bub.name = "Bubble"
			var sm := SphereMesh.new()
			sm.radius = 1.0
			sm.height = 2.0
			sm.material = WorldKit.mat(Color(0.6, 0.9, 1.0, 0.35), 0.1, 0.3)
			bub.mesh = sm
			bub.position = Vector3(0, 1.0, 0)
			av.add_child(bub)
		"steal":
			scores[i] = maxf(0.0, scores[i] - 2.0)
			_float(i, "Seele geraubt! −2", Color("#c7a0ff"))
			FX.smoke(av.global_position + Vector3.UP, Color(0.7, 0.5, 1.0), 10, 1.0)
		"grab":
			av.apply_knockback(away, 8.0, 0.7, 3.0)
			_drop_carry(i)
			var n := _items(i)
			if n > 0:
				item_steal[i] += int(ceil(n / 2.0))
				_say("Die Scheren-Zange schnappt %d Item(s) von %s!" % [int(ceil(n / 2.0)), _pname(i)], 1.6)
			else:
				_coins(i, -3)
				_say("Zange! %s verliert 3 Münzen." % _pname(i), 1.4)
		"fling":
			av.apply_knockback(away, 12.0, 0.8, 14.0)
			av.rig.react("launch")
			_drop_carry(i)


func _pop_bubble(i: int) -> void:
	status[i].erase("bubble")
	var av := avatars[i] as PartyAvatar
	var b := av.get_node_or_null("Bubble")
	if b:
		b.queue_free()
	FX.splash(av.global_position + Vector3.UP, 1.0)
	Audio.sfx("pop", av.global_position, -2.0)


func _zone_burst(h: Dictionary) -> void:
	var p: Vector3 = h.p
	match String(h.eff):
		"burn":
			FX.embers(p + Vector3.UP * 0.4, 20)
			Audio.sfx("explosion", p, -8.0, 1.2)
		"freeze":
			FX.smoke(p + Vector3.UP * 1.5, Color(0.95, 0.98, 1.0), 14, 1.3)
			Audio.sfx("glass", p, -4.0)
		"stun":
			FX.explosion(p + Vector3.UP * 0.3, 0.6)
		"root":
			FX.dust(p + Vector3.UP * 0.2, Color(0.4, 0.3, 0.2), 12, 1.0)
		"grab":
			Audio.sfx("punch", p, -2.0, 0.7)
			FX.shockwave(p, 2.5, Color(1, 0.6, 0.4, 0.8))
		_:
			FX.shockwave(p, float(h.r) + 0.5, Color(1, 0.7, 0.5, 0.7))


func _spawn_coin(p: Vector3) -> void:
	var n := WorldKit.cylinder(world, 0.3, 0.08, p + Vector3(0, 0.5, 0), Color("#ffd23f"), false)
	n.rotation.x = PI * 0.5
	Juice.pop_in(n, 0.25)
	pickups.append({"node": n, "p": p})


# --- Darstellung der Gefahren (Host und Clients) ----------------------------------------------------------------

func _decal_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _eff_color(eff: String) -> Color:
	return {"burn": Color(1.0, 0.45, 0.1), "freeze": Color(0.6, 0.9, 1.0), "root": Color(0.45, 0.32, 0.18), "stun": Color(0.85, 0.7, 1.0),
		"slow": Color(0.91, 0.64, 0.23), "grab": Color(1.0, 0.4, 0.3), "trap": Color(0.6, 0.9, 1.0), "steal": Color(0.7, 0.5, 1.0),
		"fling": Color(1, 1, 1)}.get(eff, Color(1.0, 0.35, 0.35))


func _hz_node(h: Dictionary) -> Node3D:
	var id := int(h.id)
	if _hz_nodes.has(id) and is_instance_valid(_hz_nodes[id]):
		return _hz_nodes[id]
	var n := Node3D.new()
	world.add_child(n)
	var col := _eff_color(String(h.eff))
	match String(h.kind):
		"zone", "bomb":
			var d := MeshInstance3D.new()
			d.name = "Decal"
			var cm := CylinderMesh.new()
			cm.top_radius = float(h.r)
			cm.bottom_radius = float(h.r)
			cm.height = 0.04
			cm.material = _decal_mat(Color(col, 0.35))
			d.mesh = cm
			d.position.y = 0.06
			n.add_child(d)
			var rim := MeshInstance3D.new()
			rim.name = "Rim"
			var tm := TorusMesh.new()
			tm.inner_radius = maxf(0.05, float(h.r) - 0.12)
			tm.outer_radius = float(h.r)
			tm.material = _decal_mat(Color(col, 0.9))
			rim.mesh = tm
			rim.position.y = 0.08
			n.add_child(rim)
			if String(h.kind) == "bomb":
				var ch := MeshInstance3D.new()
				var cs := SphereMesh.new()
				cs.radius = 0.7
				cs.height = 1.4
				cs.material = WorldKit.mat(Color("#e0203a"), 0.15, 0.25)
				ch.mesh = cs
				ch.position.y = 0.8
				n.add_child(ch)
				var lb := Label3D.new()
				lb.name = "Count"
				lb.font_size = 72
				lb.outline_size = 14
				lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				lb.position.y = 2.2
				n.add_child(lb)
			elif String(h.eff) == "freeze" and float(h.dur) > 1.0:
				for k in 3:
					var ic := WorldKit.cylinder(n, 0.0, 0.32, Vector3((k - 1) * 0.5, 0.8, (k % 2) * 0.4 - 0.2), Color("#bfefff"), false)
					ic.name = "Ice%d" % k
					ic.visible = false
		"sweep":
			var piv := Node3D.new()
			piv.name = "Piv"
			n.add_child(piv)
			var beam := MeshInstance3D.new()
			var bm := BoxMesh.new()
			var len := float(h.r) - float(h.speed)
			bm.size = Vector3(0.7, 0.7, len)
			bm.material = _decal_mat(Color(h.col as Color, 0.85))
			beam.mesh = bm
			beam.position = Vector3(0, 0.5, float(h.speed) + len * 0.5)
			piv.add_child(beam)
			for k2 in 9:
				var dd := MeshInstance3D.new()
				var dm := CylinderMesh.new()
				dm.top_radius = 0.35
				dm.bottom_radius = 0.35
				dm.height = 0.03
				dm.material = _decal_mat(Color(h.col as Color, 0.45))
				dd.mesh = dm
				var a := lerpf(float(h.a0), float(h.a1), k2 / 8.0)
				dd.position = Vector3(sin(a), 0.0, cos(a)) * (float(h.r) * 0.75) + Vector3.UP * 0.05
				dd.name = "Warn%d" % k2
				n.add_child(dd)
		"ring":
			var rg := MeshInstance3D.new()
			rg.name = "Ring"
			var tm2 := TorusMesh.new()
			tm2.inner_radius = 0.85
			tm2.outer_radius = 1.0
			tm2.material = _decal_mat(Color(h.col as Color, 0.85))
			rg.mesh = tm2
			rg.position.y = 0.4
			n.add_child(rg)
		"charge":
			var ln := MeshInstance3D.new()
			ln.name = "Line"
			var lm := BoxMesh.new()
			var to: Vector3 = h.to
			var from: Vector3 = h.p
			lm.size = Vector3(3.2, 0.03, maxf(0.5, from.distance_to(to)))
			lm.material = _decal_mat(Color(1, 0.3, 0.3, 0.4))
			ln.mesh = lm
			ln.position = (from + to) * 0.5 + Vector3.UP * 0.06
			ln.rotation.y = atan2(to.x - from.x, to.z - from.z)
			n.add_child(ln)
		"proj":
			var pm := MeshInstance3D.new()
			var ps := SphereMesh.new()
			var big := String(h.eff) == "trap"
			ps.radius = 0.7 if big else 0.4
			ps.height = ps.radius * 2.0
			ps.material = WorldKit.mat(Color(col, 0.6 if big else 1.0), 0.2, 1.2)
			pm.mesh = ps
			n.add_child(pm)
		"minion":
			var sh := MeshInstance3D.new()
			var ss := SphereMesh.new()
			ss.radius = 0.55
			ss.height = 0.9
			ss.material = WorldKit.mat(Color.WHITE, 1.0)
			sh.mesh = ss
			sh.position.y = 0.6
			n.add_child(sh)
			WorldKit.box(n, Vector3(0.3, 0.3, 0.32), Vector3(0, 0.7, 0.5), Color("#3a3040"), false)
		"tornado":
			for k3 in 4:
				var tr := MeshInstance3D.new()
				var tt := TorusMesh.new()
				tt.inner_radius = 0.4 + k3 * 0.35
				tt.outer_radius = 0.55 + k3 * 0.35
				tt.material = _decal_mat(Color(1, 1, 1, 0.55))
				tr.mesh = tt
				tr.position.y = 0.4 + k3 * 0.7
				n.add_child(tr)
	_hz_nodes[id] = n
	return n


func _hz_draw(h: Dictionary) -> void:
	var n := _hz_node(h)
	var t: float = h.t
	var warn: float = h.warn
	var active := t >= warn
	match String(h.kind):
		"zone", "bomb":
			n.position = Vector3(h.p)
			var dcl := n.get_node("Decal") as MeshInstance3D
			var k := clampf(t / maxf(warn, 0.01), 0.0, 1.0)
			((dcl.mesh as CylinderMesh).material as StandardMaterial3D).albedo_color.a = (0.18 + 0.25 * absf(sin(t * 10.0))) if not active else 0.55
			(n.get_node("Rim") as Node3D).scale = Vector3.ONE * (0.4 + 0.6 * k) if not active else Vector3.ONE
			if String(h.kind) == "bomb":
				(n.get_node("Count") as Label3D).text = str(int(ceil(maxf(0.0, warn - t))))
			for k2 in 3:
				var ic := n.get_node_or_null("Ice%d" % k2) as Node3D
				if ic:
					ic.visible = active
		"sweep":
			n.position = Vector3(h.p)
			var piv := n.get_node("Piv") as Node3D
			piv.visible = active
			for k3 in 9:
				(n.get_node("Warn%d" % k3) as Node3D).visible = not active
			if active:
				var kk := clampf((t - warn) / float(h.dur), 0.0, 1.0)
				piv.rotation.y = lerpf(float(h.a0), float(h.a1), kk)
		"ring":
			n.position = Vector3(h.p)
			var rg := n.get_node("Ring") as Node3D
			rg.visible = active
			var rad := maxf(0.1, (t - warn) * float(h.speed))
			rg.scale = Vector3(rad, 1.0, rad)
		"charge":
			(n.get_node("Line") as Node3D).visible = not active
		"proj", "minion", "tornado":
			n.position = Vector3(h.p)
			n.visible = active or String(h.kind) == "proj"
			if String(h.kind) == "tornado":
				n.rotation.y += 0.25
			elif String(h.kind) == "minion":
				n.rotation.y = atan2((h.dir as Vector3).x, (h.dir as Vector3).z)
				n.position.y = absf(sin(t * 12.0)) * 0.25


func _hz_cleanup() -> void:
	var live := {}
	for h in hazards:
		live[int(h.id)] = true
	for id in _hz_nodes.keys():
		if not live.has(id):
			var n: Node3D = _hz_nodes[id]
			if is_instance_valid(n):
				n.queue_free()
			_hz_nodes.erase(id)


# --- Abschluss --------------------------------------------------------------------------------------------------

func _defeat(finisher: int) -> void:
	defeated = true
	hazards.clear()
	_hz_cleanup()
	_act_seq += 1
	_act_kind = "defeat"
	model.defeat()
	Audio.jingle("fanfare")
	Juice.slowmo(0.35, 1.0)
	FX.confetti(boss_pos + Vector3.UP * 4.0, 120)
	for i in active_slots():
		(avatars[i] as PartyAvatar).rig.react("victory")
	_say("%s ist besiegt! Finaler Treffer: %s (+5)" % [def.name, _pname(finisher)], 3.0)
	await get_tree().create_timer(3.0, false).timeout
	end_game()


func on_timeout() -> void:
	if defeated:
		return
	defeated = true
	hazards.clear()
	_hz_cleanup()
	_act("roar")
	_say("%s entkommt lachend … nächstes Mal!" % def.name, 2.4)
	model.create_tween().tween_property(model, "position:y", 14.0, 1.4).set_trans(Tween.TRANS_BACK)
	await get_tree().create_timer(2.2, false).timeout
	end_game()


func check_end() -> bool:
	return false


func result_extra() -> Dictionary:
	return {"boss": boss_id, "boss_defeated": hp <= 0.0, "coin_delta": coin_delta.duplicate(), "item_steal": item_steal.duplicate()}


# --- Hilfen -----------------------------------------------------------------------------------------------------

func _items(i: int) -> int:
	return (Game.players[i].get("items", []) as Array).size() - item_steal[i] if Game.mode == "party" else 0


func _coins(i: int, n: int) -> void:
	if n == 0:
		return
	coin_delta[i] += n
	var av := avatars[i] as PartyAvatar
	FX.coins_burst(av.global_position + Vector3.UP * 1.5, absi(n), n > 0)
	_float(i, ("+%d" % n) if n > 0 else ("%d" % n), UI.GOLD if n > 0 else Color("#ff8a8a"))


func _float(i: int, text: String, col: Color) -> void:
	Juice.float_text(self, (avatars[i] as PartyAvatar).global_position + Vector3.UP * 2.6, text, col, 70)


func _pname(i: int) -> String:
	return String(Game.hero(Game.players[i].hero).name).split(" ")[0]


func _set_flood(on: bool) -> void:
	if _water:
		_water.create_tween().tween_property(_water, "position:y", 0.3 if on else -0.55, 0.9)


func _set_night(on: bool) -> void:
	if model:
		model.set_shadow(on)
	if _sun:
		_sun.create_tween().tween_property(_sun, "light_energy", 0.22 if on else 1.0, 0.9)


func _refresh_hp() -> void:
	if _bar == null:
		return
	_bar.tracked = model
	var tag := ""
	if boss_id == "frostbart" and frost_armor:
		tag = "Frost-Rüstung (halber Schaden)"
	elif boss_id == "grabstein" and _tombs_left() > 0:
		tag = "Unverwundbar: %d Grabsteine" % _tombs_left()
	elif armor_t > 0.0:
		tag = "Gepanzert"
	elif overclock_t > 0.0:
		tag = "Aus dem Takt – doppelter Schaden!"
	elif boss_id == "noxumbra" and night:
		tag = "Im Schatten"
	_bar.set_hp(hp / max_hp, "%d / %d · Phase %d" % [int(ceil(hp)), int(max_hp), bphase], tag, Color("#ff4d6d") if bphase < 3 else Color("#ff2a2a"))


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	d["b"] = [snappedf(boss_pos.x, 0.01), snappedf(boss_pos.z, 0.01)]
	d["hp"] = snappedf(hp, 0.1)
	d["bp"] = bphase
	d["ni"] = night
	d["fl"] = flood
	d["fo"] = snappedf(fog_t, 0.1)
	d["ar"] = snappedf(armor_t, 0.1)
	d["oc"] = snappedf(overclock_t, 0.1)
	d["fa"] = frost_armor
	d["sy"] = _say_text
	d["as"] = _act_seq
	d["ak"] = _act_kind
	d["df"] = defeated
	var ob: Array = []
	for o in ammo:
		var p := (o.node as Node3D).position
		ob.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01), int(o.holder)])
	d["ob"] = ob
	d["pk"] = pickups.map(func(c: Dictionary) -> Array: return [snappedf((c.p as Vector3).x, 0.01), snappedf((c.p as Vector3).z, 0.01)])
	d["hz"] = hazards.map(func(h: Dictionary) -> Array:
		var p2: Vector3 = h.p
		var to: Vector3 = h.to
		var dr: Vector3 = h.dir
		return [int(h.id), String(h.kind), String(h.eff), snappedf(p2.x, 0.01), snappedf(p2.y, 0.01), snappedf(p2.z, 0.01), snappedf(float(h.r), 0.01),
			snappedf(float(h.t), 0.01), float(h.warn), float(h.dur), snappedf(float(h.a0), 0.01), snappedf(float(h.a1), 0.01),
			snappedf(float(h.speed), 0.01), snappedf(to.x, 0.01), snappedf(to.z, 0.01), snappedf(dr.x, 0.01), snappedf(dr.z, 0.01), (h.col as Color).to_html()])
	d["pd"] = pads.map(func(pd: Dictionary) -> Array:
		return [int(pd.get("hp", 0)), 1 if bool(pd.get("on", false)) else 0, 1 if bool(pd.get("got", false)) else 0, snappedf((pd.node as Node3D).position.y, 0.01)])
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var b: Array = d.get("b", [boss_pos.x, boss_pos.z])
	boss_pos = Vector3(float(b[0]), 0, float(b[1]))
	var nh := float(d.get("hp", hp))
	if nh < hp - 0.01 and model:
		model.hit()
	hp = nh
	var nb := int(d.get("bp", bphase))
	if nb > bphase and model:
		model.set_rage(nb - 1)
	bphase = nb
	var ni := bool(d.get("ni", night))
	if ni != night:
		_set_night(ni)
	night = ni
	var fl := bool(d.get("fl", flood))
	if fl != flood:
		_set_flood(fl)
	flood = fl
	fog_t = float(d.get("fo", 0.0))
	armor_t = float(d.get("ar", 0.0))
	overclock_t = float(d.get("oc", 0.0))
	frost_armor = bool(d.get("fa", frost_armor))
	var sy := String(d.get("sy", ""))
	if sy != _say_text and sy != "":
		_say(sy, 1.6)
	var aseq := int(d.get("as", _act_seq))
	if aseq != _act_seq:
		_act_seq = aseq
		var k := String(d.get("ak", ""))
		if model and k != "" and not k.begins_with("rage"):
			if k == "defeat":
				model.defeat()
			else:
				model.act(k)
	defeated = bool(d.get("df", defeated))
	var ob: Array = d.get("ob", [])
	while ammo.size() > ob.size():
		(ammo[0].node as Node3D).queue_free()
		ammo.remove_at(0)
	while ammo.size() < ob.size():
		ammo.append({"node": _ammo_node(), "holder": -1})
	for k2 in ob.size():
		ammo[k2].holder = int(ob[k2][3])
		if int(ob[k2][3]) < 0:
			(ammo[k2].node as Node3D).position = Vector3(float(ob[k2][0]), float(ob[k2][1]), float(ob[k2][2]))
	var pk: Array = d.get("pk", [])
	while pickups.size() > pk.size():
		(pickups[0].node as Node3D).queue_free()
		pickups.remove_at(0)
	while pickups.size() < pk.size():
		_spawn_coin(Vector3.ZERO)
	for k3 in pk.size():
		pickups[k3].p = Vector3(float(pk[k3][0]), 0, float(pk[k3][1]))
		(pickups[k3].node as Node3D).position = (pickups[k3].p as Vector3) + Vector3(0, 0.5, 0)
	var hz: Array = d.get("hz", [])
	hazards.clear()
	for e in hz:
		hazards.append({"id": int(e[0]), "kind": String(e[1]), "eff": String(e[2]), "p": Vector3(float(e[3]), float(e[4]), float(e[5])),
			"r": float(e[6]), "t": float(e[7]), "warn": float(e[8]), "dur": float(e[9]), "a0": float(e[10]), "a1": float(e[11]),
			"speed": float(e[12]), "to": Vector3(float(e[13]), 0, float(e[14])), "dir": Vector3(float(e[15]), 0, float(e[16])),
			"col": Color(String(e[17])), "hit": {}, "target": -1})
	var pd: Array = d.get("pd", [])
	for k4 in mini(pd.size(), pads.size()):
		var e2: Array = pd[k4]
		var pad: Dictionary = pads[k4]
		match String(pad.kind):
			"crack":
				if int(pad.hp) > 0 and int(e2[0]) <= 0:
					_collapse(pad)
				pad.hp = int(e2[0])
			"tomb":
				if int(pad.hp) > 0 and int(e2[0]) <= 0:
					(pad.node as Node3D).create_tween().tween_property(pad.node, "rotation:x", -PI * 0.48, 0.3)
				pad.hp = int(e2[0])
			"gear":
				pad.on = int(e2[1]) == 1
			"snow":
				pad.got = int(e2[2]) == 1
				(pad.node as Node3D).visible = not bool(pad.got)
			"lift":
				(pad.node as Node3D).position.y = float(e2[3])


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	var level: int = Game.players[slot].cpu_level
	var pos := av.global_position
	var mv := Vector2.ZERO
	var held := {}
	if int(status[slot].get("bubble", 0)) > 0 or (not _duel.is_empty() and slot in [int(_duel.a), int(_duel.b)]):
		if randf() < 0.35 + level * 0.15:
			held["a"] = true
		InputHub.set_virtual(slot, Vector2.ZERO, held)
		return
	var goal := Vector3.INF
	if carry[slot]:
		var tgt := boss_pos
		var tomb := _nearest_tomb(pos)
		if not tomb.is_empty():
			tgt = tomb.p
		if boss_id == "noxumbra" and night and not _on_kind(pos, "mush"):
			goal = _nearest_pad(pos, "mush")
		elif Vector2(tgt.x - pos.x, tgt.z - pos.z).length() < Game.lv([8.0, 10.0, 12.0], level):
			if randf() < 0.12:
				held["b"] = true
		else:
			goal = tgt
	else:
		if boss_id == "galaxus" and overclock_t <= 0.0 and level >= 1:
			for pd in pads:
				if not bool(pd.on):
					goal = pd.p
					break
		if boss_id == "frostbart" and frost_armor:
			for pd2 in pads:
				if String(pd2.kind) == "snow" and not bool(pd2.got):
					goal = pd2.p
					break
		if goal == Vector3.INF:
			var bd := INF
			for o in ammo:
				if int(o.holder) < 0:
					var p: Vector3 = (o.node as Node3D).position
					if p.distance_to(pos) < bd:
						bd = p.distance_to(pos)
						goal = p
	if flood and boss_id == "klabautox" and not _on_kind(pos, "sand") and level >= 1:
		goal = _nearest_pad(pos, "sand")
	if goal != Vector3.INF:
		mv = Vector2(goal.x - pos.x, goal.z - pos.z).normalized()
	# Ausweichen: angekündigte Zonen verlassen, über Bögen/Wellen springen
	for h in hazards:
		var kind := String(h.kind)
		var hp3: Vector3 = h.p
		var d := Vector2(pos.x - hp3.x, pos.z - hp3.z)
		match kind:
			"zone", "bomb":
				if d.length() < float(h.r) + 0.8 and float(h.t) > float(h.warn) - Game.lv([0.5, 0.9, 1.2], level):
					mv = d.normalized()
			"sweep", "ring":
				var near := false
				if kind == "ring":
					var rad := (float(h.t) - float(h.warn)) * float(h.speed)
					near = absf(d.length() - rad) < 1.6 and float(h.t) > float(h.warn)
				else:
					var ang := lerpf(float(h.a0), float(h.a1), clampf((float(h.t) - float(h.warn)) / float(h.dur), 0.0, 1.0))
					near = absf(wrapf(atan2(d.x, d.y) - ang, -PI, PI)) < 0.45 and float(h.t) > float(h.warn) and d.length() < float(h.r)
				if near and level >= 1 and av.is_on_floor() and randf() < 0.5 + level * 0.2:
					held["a"] = true
			"charge", "minion", "proj", "tornado":
				var dd := d.length() if kind != "charge" else Vector2(pos.x - boss_pos.x, pos.z - boss_pos.z).length()
				if dd < 3.2:
					mv = Vector2(-d.y, d.x).normalized() if kind == "charge" else d.normalized()
	if Vector2(pos.x, pos.z).length() > R - 1.8:
		mv += -Vector2(pos.x, pos.z).normalized()
	if invert_t > 0.0:
		mv = -mv   # CPU gleicht die vertauschte Steuerung aus
	InputHub.set_virtual(slot, mv.limit_length(1.0), held)


func _nearest_pad(p: Vector3, kind: String) -> Vector3:
	var best := Vector3.INF
	for pd in pads:
		if String(pd.kind) == kind and (best == Vector3.INF or p.distance_to(pd.p) < p.distance_to(best)):
			best = pd.p
	return best
