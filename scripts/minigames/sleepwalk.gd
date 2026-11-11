extends MinigameBase
## Schlafwandler-Parcours: Mit Schlafmütze und ausgestreckten Armen torkeln die Figuren blind über schmale
## Holzbalken hoch über einer nächtlichen Schlucht. Gesteuert wird nicht direkt: Vor jedem Hindernis blinkt ein
## schnelles Aktions-Menü auf – Steuerkreuz/Stick wählt (↑ Schritt vor · ← Links lehnen · → Rechts lehnen ·
## ↓ Hinsetzen). Die richtige Aktion lässt sie sicher weitertapsen, falsch oder zu langsam heißt: Stolpern
## über Bausteine (kurze Pause, manchmal ein Stück zurück). Wer am weitesten kommt, gewinnt.
## Online: Owner-Modell (jeder bewertet seine eigenen Eingaben, die Hindernisfolge ist für alle gleich).

const STEPS := 16
const STEP_LEN := 2.2
const LANE_X := [-4.8, -1.6, 1.6, 4.8]
const ACTIONS := ["up", "left", "right", "down"]
const LABELS := {"up": "Schritt vor", "left": "Links lehnen", "right": "Rechts lehnen", "down": "Hinsetzen"}
const OBSTACLE_FOR := {"up": "block", "left": "lean_r", "right": "lean_l", "down": "branch"}

var course: Array[String] = []          # Aktion je Schritt (für alle gleich)
var progress: Array[int] = [0, 0, 0, 0]
var _prompt_t: Array[float] = [0, 0, 0, 0]
var _stun: Array[float] = [0, 0, 0, 0]
var _prev_mag: Array[float] = [0, 0, 0, 0]
var _busy: Array[bool] = [false, false, false, false]
var _menus: Array[Control] = []
var _window := 1.25


func _init() -> void:
	game_id = "sleepwalk"
	env_preset = "night"
	backdrop_style = "night"
	time_limit = 45.0
	arena_radius = 12.0
	teaser_height = 0.8
	cannon_pos = Vector3(0, 0, 12)
	score_format = "%d Schritte"
	for i in 4:
		spawn_points.append(Vector3(LANE_X[i], 0.6, 6.0))


func on_setup() -> void:
	for k in STEPS:
		course.append(ACTIONS[rng.randi() % ACTIONS.size()])


func build_arena() -> void:
	# Schlucht: Felswände links/rechts, tief unten Nebel; Startplateau und Zielplateau mit Bettchen
	WorldKit.box(world, Vector3(16, 1, 4), Vector3(0, -0.5, 7.0), Color("#5a6a4a"))
	var goal_z := 6.0 - STEPS * STEP_LEN - 2.0
	WorldKit.box(world, Vector3(16, 1, 5), Vector3(0, -0.5, goal_z - 1.0), Color("#5a6a4a"))
	for sd in [-1.0, 1.0]:
		WorldKit.box(world, Vector3(6, 30, 60), Vector3(sd * 12.0, -14.0, goal_z * 0.5), Color("#4a4a62"), false)
	for i in 4:
		# Balken mit Querlatten
		var len := STEPS * STEP_LEN + 2.0
		var beam := WorldKit.box(world, Vector3(0.7, 0.3, len), Vector3(LANE_X[i], -0.15, 6.0 - len * 0.5 + 0.5), Color("#a8784a"), false)
		beam.name = "Beam%d" % i
		for k in STEPS:
			var z := 6.0 - (k + 1) * STEP_LEN
			WorldKit.box(world, Vector3(1.0, 0.08, 0.16), Vector3(LANE_X[i], 0.02, z + STEP_LEN * 0.5), Color("#8a5a32"), false)
			_obstacle(i, k, z)
		# Bettchen im Ziel
		var bed := WorldKit.box(world, Vector3(1.4, 0.4, 2.0), Vector3(LANE_X[i], 0.2, goal_z - 1.0), Color("#c98d5a"), false)
		bed.name = "Bed"
		WorldKit.box(world, Vector3(1.3, 0.2, 1.4), Vector3(LANE_X[i], 0.45, goal_z - 1.2), Game.player_color(i).lightened(0.3), false)
		var pillow := MeshInstance3D.new()
		var ps := SphereMesh.new()
		ps.radius = 0.4
		ps.height = 0.4
		ps.material = WorldKit.mat(Color.WHITE, 0.9)
		pillow.mesh = ps
		pillow.scale = Vector3(1.4, 0.6, 0.8)
		pillow.position = Vector3(LANE_X[i], 0.6, goal_z - 1.75)
		world.add_child(pillow)
	# Mond, Sterne, Laternen, schwebende Schäfchen zum Zählen
	var moon := MeshInstance3D.new()
	var ms := SphereMesh.new()
	ms.radius = 6.0
	ms.height = 12.0
	ms.material = WorldKit.mat(Color("#fff2c4"), 0.9, 0.9)
	moon.mesh = ms
	moon.position = Vector3(18, 22, goal_z - 30)
	world.add_child(moon)
	for k in 6:
		var lz := 4.0 - k * 6.0
		for sd in [-1.0, 1.0]:
			WorldKit.place(world, "town/lantern", Vector3(sd * 7.8, 0, lz), 0.0, 1.6)
			var ll := OmniLight3D.new()
			ll.light_color = Color(1.0, 0.8, 0.5)
			ll.light_energy = 0.9
			ll.omni_range = 6.0
			ll.position = Vector3(sd * 7.4, 1.8, lz)
			world.add_child(ll)
	for k in 5:
		var sheep := Node3D.new()
		world.add_child(sheep)
		for q in [Vector3.ZERO, Vector3(0.4, 0.15, 0.1), Vector3(-0.4, 0.1, -0.1)]:
			var puff := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.45
			sm.height = 0.8
			sm.material = WorldKit.mat(Color("#f4f4ff"), 1.0, 0.2)
			puff.mesh = sm
			puff.position = q
			sheep.add_child(puff)
		sheep.position = Vector3(-10.0 + k * 5.0, 6.0 + (k % 2) * 1.5, -10.0 - k * 4.0)
		var jt := sheep.create_tween().set_loops()
		jt.tween_property(sheep, "position:y", sheep.position.y + 1.6, 0.9 + k * 0.1).set_trans(Tween.TRANS_SINE)
		jt.tween_property(sheep, "position:y", sheep.position.y, 0.9 + k * 0.1).set_trans(Tween.TRANS_SINE)
	var fog := FX.emitter({"amount": 50, "life": 8.0, "one_shot": false, "explosive": 0.0, "spread": 180.0, "vel_min": 0.1, "vel_max": 0.4,
		"gravity": Vector3.ZERO, "size": 3.0, "color": Color(0.6, 0.6, 0.9, 0.18), "box": Vector3(14, 1, 40)})
	world.add_child(fog)
	fog.position = Vector3(0, -6.0, goal_z * 0.5)
	fog.preprocess = 6.0
	fog.emitting = true


## Hindernis je Schritt passend zur richtigen Aktion.
func _obstacle(lane: int, k: int, z: float) -> void:
	var x: float = LANE_X[lane]
	match OBSTACLE_FOR[course[k]]:
		"block":
			var b := WorldKit.box(world, Vector3(0.45, 0.45, 0.45), Vector3(x, 0.25, z + 0.6), [Color("#ff6b6b"), Color("#ffd23f"), Color("#3fa7ff")][k % 3], false)
			b.rotation.y = 0.4
		"branch":
			var br := WorldKit.cylinder(world, 0.12, 2.4, Vector3(x, 1.35, z + 0.6), Color("#6b4a2b"), false)
			br.rotation.z = PI * 0.5
			Assets.spawn("plat/flowers", world, Vector3(x + 0.6, 1.45, z + 0.6), 0.0, 0.6)
		"lean_l", "lean_r":
			var sd := -1.0 if OBSTACLE_FOR[course[k]] == "lean_l" else 1.0
			var post := WorldKit.cylinder(world, 0.15, 1.8, Vector3(x - sd * 0.45, 0.9, z + 0.6), Color("#8a8fa8"), false)
			post.name = "Post"
			var lamp := Assets.spawn("town/lantern", world, Vector3(x - sd * 0.45, 0, z + 0.6), 0.0, 0.7)
			lamp.name = "Lamp"


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, 0)
	c.offset = Vector3(0, 9.5, 11.0)
	c.min_dist = 1.0
	c.max_dist = 1.0
	c.follow = false


func spawn_players() -> void:
	super.spawn_players()
	for i in 4:
		var rig := (avatars[i] as PartyAvatar).rig
		var cap := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.34
		cm.height = 0.9
		cm.material = WorldKit.mat(Game.player_color(i).lightened(0.2), 0.8)
		cap.mesh = cm
		cap.position = Vector3(0.1, 2.1, 0)
		cap.rotation.z = -0.5
		rig.add_child(cap)
		var pom := MeshInstance3D.new()
		var ps := SphereMesh.new()
		ps.radius = 0.12
		ps.height = 0.24
		ps.material = WorldKit.mat(Color.WHITE, 0.9)
		pom.mesh = ps
		pom.position = Vector3(0.45, 2.45, 0)
		rig.add_child(pom)


func on_start() -> void:
	for i in 4:
		var av := avatars[i] as PartyAvatar
		av.can_move = false
		av.can_jump = false
		av.can_shove = false
		av.set_physics_process(false)
		av.rig.face_now(Vector3(0, 0, -1))
		FX.zzz(av.rig, 2.4, time_limit)
	var root := UI.center_root(hud)
	for i in active_slots():
		var m := _make_menu(i)
		root.add_child(m)
		_menus.append(m)
		_place_menu(i, m)
		_prompt_t[i] = _window


func _make_menu(i: int) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.22, 0.85)
	sb.border_color = Game.player_color(i)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(6)
	p.add_theme_stylebox_override("panel", sb)
	var v := UI.vbox(2)
	p.add_child(v)
	var l := UI.label("", 20, Color.WHITE, true, 6)
	l.name = "Ask"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var bar := ProgressBar.new()
	bar.name = "Time"
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(170, 8)
	v.add_child(bar)
	p.set_meta("slot", i)
	p.set_meta("ask", l)
	p.set_meta("bar", bar)
	return p


func _place_menu(i: int, m: Control) -> void:
	var vp := get_viewport().get_visible_rect().size
	var x := vp.x * (0.14 + 0.24 * float(i))
	UI.place(m, Control.PRESET_TOP_LEFT, Vector2(x - 95, vp.y - 170), Vector2(190, 0))


func _menu_of(i: int) -> Control:
	for m in _menus:
		if int(m.get_meta("slot")) == i:
			return m
	return null


func on_tick(delta: float) -> void:
	for i in active_slots():
		_stun[i] = maxf(0.0, _stun[i] - delta)
		var m := _menu_of(i)
		if progress[i] >= STEPS:
			if m:
				m.visible = false
			continue
		var want := course[progress[i]]
		if m:
			(m.get_meta("ask") as Label).text = String(LABELS[want]) if _stun[i] <= 0.0 else "Stolper …"
			(m.get_meta("bar") as ProgressBar).value = _prompt_t[i] / _window
			m.modulate = Color(1, 1, 1, 1.0 if _stun[i] <= 0.0 else 0.5)
		if _busy[i] or _stun[i] > 0.0 or not net_owned(i):
			continue
		_prompt_t[i] -= delta
		var choice := _read(i)
		if choice != "":
			if choice == want:
				_advance(i)
			else:
				_stumble(i, false)
		elif _prompt_t[i] <= 0.0:
			_stumble(i, true)
	if not net_sync or Net.is_host:
		var all_done := true
		for i in active_slots():
			if progress[i] < STEPS:
				all_done = false
		if all_done:
			end_game()


func _read(i: int) -> String:
	if Game.players[i].cpu:
		var mem := cpu_mem[i]
		if not mem.has("at"):
			var level: int = Game.players[i].cpu_level
			mem["at"] = randf_range(Game.lv_react([0.5, 0.35, 0.22], level), Game.lv_react([1.1, 0.8, 0.55], level))
			mem["ok"] = randf() < Game.lv([0.72, 0.86, 0.95], level)
		if _window - _prompt_t[i] >= float(mem.at):
			var want := course[progress[i]]
			var res: String = want if bool(mem.ok) else ACTIONS[(ACTIONS.find(want) + 1 + randi() % 3) % 4]
			mem.clear()
			return res
		return ""
	var mv := InputHub.move(i)
	var mag := mv.length()
	var res2 := ""
	if mag > 0.6 and _prev_mag[i] <= 0.6:
		if absf(mv.x) > absf(mv.y):
			res2 = "right" if mv.x > 0.0 else "left"
		else:
			res2 = "down" if mv.y > 0.0 else "up"
	_prev_mag[i] = mag
	return res2


func _advance(i: int) -> void:
	_busy[i] = true
	var av := avatars[i] as PartyAvatar
	var want := course[progress[i]]
	progress[i] += 1
	scores[i] = progress[i]
	report_score(i)
	var to := Vector3(LANE_X[i], 0.6, 6.0 - progress[i] * STEP_LEN)
	match want:
		"left", "right":
			var sd := -1.0 if want == "left" else 1.0
			av.rig.create_tween().tween_property(av.rig, "rotation:z", -sd * 0.35, 0.15)
		"down":
			av.rig.play_once("sit_down" if av.rig.has_clip("sit_down") else "crouch")
	av.rig.play("walk", 0.1, 0.7)
	Audio.sfx("step_wood", av.global_position, -8.0)
	var tw := av.create_tween()
	tw.tween_property(av, "position", to, 0.55 if want != "down" else 0.75).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		av.rig.rotation.z = 0.0
		av.rig.play("idle")
		_busy[i] = false
		_prompt_t[i] = maxf(0.6, _window - progress[i] * 0.03)
		if progress[i] >= STEPS:
			av.rig.play("lie_down" if av.rig.has_clip("lie_down") else "sit")
			FX.stars(av.global_position + Vector3.UP, Color(1, 0.95, 0.6), 14)
			Audio.sfx("sparkle_up", null, -6.0)
			finish_player(i))


func _stumble(i: int, slow: bool) -> void:
	var av := avatars[i] as PartyAvatar
	_stun[i] = 1.0
	_prompt_t[i] = _window
	av.rig.react("trip_fall" if av.rig.has_clip("trip_fall") else "dizzy")
	Audio.sfx("wood_hit", av.global_position, -4.0, 1.3)
	Juice.float_text(self, av.global_position + Vector3.UP * 2.4, "Zu langsam!" if slow else "Stolper!", Color("#ff9db0"), 54)
	if progress[i] > 0 and randf() < 0.35:
		progress[i] -= 1
		scores[i] = progress[i]
		var back := Vector3(LANE_X[i], 0.6, 6.0 - progress[i] * STEP_LEN)
		av.create_tween().tween_property(av, "position", back, 0.4)
	report_score(i)


func on_remote_score(slot: int, _extra: Dictionary) -> void:
	progress[slot] = int(scores[slot])


func cpu_think(slot: int, _delta: float) -> void:
	InputHub.set_virtual(slot, Vector2.ZERO)
