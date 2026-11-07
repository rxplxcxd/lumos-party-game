extends MinigameBase
## Geister-Schloss Schwindel: Ein stockdunkler Saal voller Falltüren. Nur bei Blitzen sieht man
## für einen Moment, welche Platten tragen und wo die Geister schweben. Merk dir den Weg!
## Wer stürzt, beginnt von vorn. Zuerst am Ausgang gewinnt.

const COLS := 5
const ROWS := 13
const TILE := 2.0
const START_Z := 2.4

var safe := {}          # Vector2i(col,row) -> bool
var path: Array[int] = []
var ghosts: Array[Dictionary] = []
var sun: DirectionalLight3D
var env: Environment
var flash_rect: ColorRect
var _flash_t := 2.0
var _cpu_known: Array[Dictionary] = [{}, {}, {}, {}]


func _init() -> void:
	game_id = "ghost_castle"
	env_preset = "ghost"
	time_limit = 60.0
	race = true
	respawn_on_fall = true
	kill_y = -5.0
	hazard = "void"
	teaser_height = 1.3
	arena_radius = 12.0
	arena_center = Vector3(0, 0, -10)
	cannon_pos = Vector3(-9, 0, 6)
	spawn_points = [Vector3(-3, 0.3, START_Z + 0.8), Vector3(-1, 0.3, START_Z + 0.8), Vector3(1, 0.3, START_Z + 0.8), Vector3(3, 0.3, START_Z + 0.8)]


func _z(row: int) -> float:
	return -row * TILE


func _x(col: int) -> float:
	return (col - (COLS - 1) * 0.5) * TILE


func build_arena() -> void:
	var we: WorldEnvironment = null
	for c in get_children():
		if c is WorldEnvironment:
			we = c
		if c is DirectionalLight3D:
			sun = c
	env = we.environment
	# sicheren Pfad erzeugen
	var col := COLS / 2
	for r in ROWS:
		safe[Vector2i(col, r)] = true
		path.append(col)
		var step := randi_range(-1, 1)
		if r % 3 == 2:
			step = (1 if col < COLS / 2 else -1) * randi_range(1, 2)
		var ncol := clampi(col + step, 0, COLS - 1)
		if ncol != col:
			# Querverbindung auf derselben Reihe
			for c2 in range(mini(col, ncol), maxi(col, ncol) + 1):
				safe[Vector2i(c2, r)] = true
		col = ncol
	for r in ROWS:
		for c3 in COLS:
			if randf() < 0.12:
				safe[Vector2i(c3, r)] = true
	# Platten
	for r in ROWS:
		for c4 in COLS:
			var k := Vector2i(c4, r)
			var pos := Vector3(_x(c4), 0, _z(r))
			if safe.get(k, false):
				var body := StaticBody3D.new()
				var cs := CollisionShape3D.new()
				var bs := BoxShape3D.new()
				bs.size = Vector3(TILE * 0.98, 0.5, TILE * 0.98)
				cs.shape = bs
				cs.position.y = -0.25
				body.add_child(cs)
				world.add_child(body)
				body.position = pos
				Assets.spawn("dun/floor_small", body)
			else:
				# Attrappe: sieht im Dunkeln gleich aus, trägt aber nicht (wackelnde Falltür)
				var fake := Assets.spawn("dun/floor_grate" if randf() < 0.3 else "dun/floor_small", world, pos, 0.0, 1.0)
				fake.scale = Vector3(0.5, 1.0, 0.5) if fake.name.contains("grate") else Vector3.ONE
				fake.set_meta("fake", true)
				Assets.tint(fake, Color(0.75, 0.7, 0.75))
				fake.position.y = -0.02
	# Start- und Zielpodest
	WorldKit.box(world, Vector3(COLS * TILE + 2, 0.5, 2.9), Vector3(0, -0.25, START_Z), Color(0.3, 0.25, 0.32))
	WorldKit.box(world, Vector3(COLS * TILE + 2, 0.5, 3.0), Vector3(0, -0.25, _z(ROWS) - 0.5), Color(0.3, 0.25, 0.32))
	var gate := WorldKit.place(world, "grave/crypt", Vector3(0, 0, _z(ROWS) - 2.6), 180.0, 3.0)
	WorldKit.torch_light(world, Vector3(-3, 2.5, _z(ROWS) - 1.0), Color(0.5, 0.8, 1.0), 1.6, 6.0)
	WorldKit.torch_light(world, Vector3(3, 2.5, _z(ROWS) - 1.0), Color(0.5, 0.8, 1.0), 1.6, 6.0)
	# Schloss-Kulisse
	for r in range(-1, ROWS + 2, 2):
		for side in [-1.0, 1.0]:
			var w := WorldKit.place(world, "dun/wall_arched" if r % 4 == 1 else "dun/wall", Vector3(side * (COLS * TILE * 0.5 + 1.8), -3, _z(r)), 90.0 * side, 1.0)
			w.scale.y = 2.0
	for p in [Vector3(-7, 0, -6), Vector3(7, 0, -14), Vector3(-7, 0, -20)]:
		WorldKit.place(world, "grave/candles", p, 0.0, 2.0)
	WorldKit.place(world, "grave/coffin", Vector3(6.5, 0, -3), 90.0, 2.0)
	# Geister
	for i in 3:
		var g := CharacterRig.new()
		world.add_child(g)
		g.setup("npc/ghost", -1, 2.2)
		Assets.tint(g.model, Color(0.8, 0.9, 1.0, 0.8), true, 0.6)
		var row := 3 + i * 3
		g.position = Vector3(0, 0.6, _z(row))
		g.play("idle")
		ghosts.append({"rig": g, "row": row, "phase": randf() * TAU, "speed": randf_range(0.9, 1.5)})
	# Blitz-Overlay
	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(0.85, 0.9, 1.0, 0.0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash_rect)


func spawn_players() -> void:
	super.spawn_players()
	for av in avatars:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.8, 0.5)
		lamp.light_energy = 0.6
		lamp.omni_range = 1.6
		lamp.position = Vector3(0, 1.4, 0)
		(av as Node3D).add_child(lamp)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, -6)
	c.offset = Vector3(0, 13, 9)
	c.center_weight = 0.15
	c.min_dist = 1.0
	c.max_dist = 1.35


func on_start() -> void:
	_lightning(true)
	for av in avatars:
		(av as PartyAvatar).rig.surface = "stone"


func on_tick(delta: float) -> void:
	_flash_t -= delta
	if _flash_t <= 0.0:
		_flash_t = randf_range(3.0, 4.6)
		_lightning(false)
	var t := Time.get_ticks_msec() / 1000.0
	for g in ghosts:
		var rig: CharacterRig = g.rig
		var x := sin(t * float(g.speed) + float(g.phase)) * (COLS * TILE * 0.5)
		var old := rig.position
		rig.position = Vector3(x, 0.6 + sin(t * 3.0) * 0.2, _z(g.row))
		rig.face(rig.position - old, delta, 8.0)
		for av in avatars:
			var a := av as PartyAvatar
			if a.alive and not a.is_stunned() and a.global_position.distance_to(rig.global_position) < 1.4:
				a.apply_knockback(Vector3(0, 0, 1), 9.0, 0.8, 5.0)
				a.rig.react("scared")
				Audio.sfx("ghost", a.global_position)
				Audio.sfx("evil_laugh", a.global_position, -8.0, 1.3)
	# Fortschritt & Ziel
	for i in 4:
		var a2 := avatars[i] as PartyAvatar
		if not a2.alive:
			continue
		var prog := -a2.global_position.z
		scores[i] = maxf(scores[i], clampf(prog / (ROWS * TILE) * 100.0, 0, 100))
		if a2.global_position.z < _z(ROWS) + 0.5 and not (i in finish_order):
			finish_player(i)
			a2.freeze(true)
			a2.rig.react("victory")


func _lightning(first: bool) -> void:
	Audio.sfx("thunder", null, -2.0 if not first else -8.0)
	var tw := create_tween()
	# Dreifach-Entladung: kurz – lang (Lesephase) – kurz, danach weiches Nachglühen
	var pulses := [[0.09, 3.6], [0.55, 4.5], [0.12, 3.0]]
	for k in pulses.size():
		var dur: float = pulses[k][0]
		var energy: float = pulses[k][1]
		tw.tween_callback(func() -> void:
			sun.light_energy = energy
			env.ambient_light_energy = 1.6
			env.fog_density = 0.008
			flash_rect.color.a = 0.4)
		tw.tween_property(flash_rect, "color:a", 0.08, dur * 0.6)
		tw.tween_interval(dur * 0.4)
		tw.tween_callback(func() -> void:
			sun.light_energy = 0.25
			env.ambient_light_energy = 0.3
			flash_rect.color.a = 0.0)
		tw.tween_interval(0.08)
	tw.tween_method(func(v: float) -> void:
		sun.light_energy = v
		env.ambient_light_energy = lerpf(0.14, 0.4, v / 1.2)
		env.fog_density = lerpf(0.03, 0.012, v / 1.2), 1.2, 0.08, 1.4)
	tw.tween_callback(func() -> void: env.fog_density = 0.03)
	Juice.shake(0.15)
	# CPU-Gedächtnis auffrischen
	for i in 4:
		_cpu_known[i]["refresh"] = true


func on_fell(slot: int, hz: String) -> void:
	# Lernen: CPU merkt sich die gefährliche Platte
	var a := avatars[slot] as PartyAvatar
	var c := int(round(a.global_position.x / TILE + (COLS - 1) * 0.5))
	var r := int(round(-a.global_position.z / TILE))
	_cpu_known[slot][Vector2i(c, r)] = false
	await super.on_fell(slot, hz)


func check_end() -> bool:
	return finish_order.size() >= 4


func _update_badges() -> void:
	for i in badges.size():
		if i in finish_order:
			badges[i].set_status("done", finish_order.find(i) + 1)
		else:
			badges[i].set_status("", "%d%%" % int(scores[i]))


# --- CPU ---------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var a := avatars[slot] as PartyAvatar
	if not a.alive or slot in finish_order:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var mem: Dictionary = _cpu_mem_for(slot)
	var r := int(round(-a.global_position.z / TILE))
	var c := int(round(a.global_position.x / TILE + (COLS - 1) * 0.5))
	var next_row := clampi(r + 1, 0, ROWS)
	if a.global_position.z > -0.4:
		next_row = 0
	var target_col: int = mem.get(next_row, path[mini(next_row, ROWS - 1)])
	var target := Vector3(_x(target_col) + (slot - 1.5) * 0.3, 0, _z(next_row) if next_row < ROWS else _z(ROWS) - 0.8)
	var to := target - a.global_position
	var mv: Vector2
	# seitlich ausrichten (auf dem Startpodest mit leichtem Vorwärtsdrang), dann vorwärts tasten
	if absf(to.x) > 0.9:
		mv = Vector2(signf(to.x), -0.4 if a.global_position.z > 1.2 else 0.0)
	else:
		mv = Vector2(to.x * 0.9, -1.0)
	# Geistern ausweichen
	for g in ghosts:
		var gp: Vector3 = (g.rig as Node3D).global_position
		if absf(gp.z - target.z) < 1.0 and absf(gp.x - a.global_position.x) < 2.2:
			mv = Vector2.ZERO
	InputHub.set_virtual(slot, mv.limit_length(1.0) * [0.7, 0.85, 1.0][level])


func _cpu_mem_for(slot: int) -> Dictionary:
	var known: Dictionary = _cpu_known[slot]
	if known.get("refresh", false) or not known.has("cols"):
		known["refresh"] = false
		var cols := {}
		var err: float = [0.22, 0.1, 0.03][int(Game.players[slot].cpu_level)]
		for r in ROWS:
			var col := path[r]
			if randf() < err:
				col = clampi(col + (1 if randf() < 0.5 else -1), 0, COLS - 1)
			if known.get(Vector2i(col, r), true) == false:
				col = path[r]
			cols[r] = col
		known["cols"] = cols
	return known["cols"]
