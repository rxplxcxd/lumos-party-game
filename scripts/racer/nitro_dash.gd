extends Node3D
## Nitro Dash – Arcade-Racer.
## 8 Karts (4 Spieler-Slots + 4 Zusatz-CPUs), 12 Strecken, 12 Items (siehe ItemModels.INFO):
##   Angriff: Kuchendeckel, Konfetti-Salve, Homing-Kanonenkugel, Piraten-Anker, Megafon-Schock, Donnerwolke
##   Verteidigung: Seifenblase, Spiegelschild, Honigfalle (nach hinten) · Tempo: Nitro, Funkenkern, Kometenritt
## Verteilung nach Platz: vorn eher Verteidigung, hinten eher Aufholen – aber nie ein Item, das die Platzierung
## einfach umdreht (Donnerwolke nur kurz, Kometenritt nur weit hinten und höchstens einer zugleich).
## Online gilt Opfer-Autorität: Ob ein Treffer wirkt, entscheidet das Gerät, dem das getroffene Kart gehört.

## Gewichte je Platz (ab Platz k gilt die Zeile). Summen müssen nicht 100 sein.
const ITEM_TABLE := {
	1: {"pie": 24, "honey": 26, "bubble": 18, "mirror": 12, "candy": 10, "nitro": 10},
	2: {"pie": 18, "honey": 14, "candy": 16, "bubble": 12, "mirror": 10, "nitro": 14, "spark": 8, "homing": 8},
	4: {"candy": 14, "homing": 16, "nitro": 16, "spark": 12, "megaphone": 12, "anchor": 10, "honey": 8, "bubble": 6, "pie": 6},
	6: {"homing": 18, "nitro": 18, "anchor": 14, "megaphone": 14, "spark": 12, "thunder": 8, "comet": 6, "bubble": 6, "candy": 4},
	8: {"nitro": 18, "homing": 16, "anchor": 14, "comet": 14, "thunder": 12, "megaphone": 12, "spark": 10, "bubble": 4},
}
const THUNDER_COOLDOWN := 14.0
const BOX_LANES := [-6.0, -3.0, 0.0, 3.0, 6.0]
const BOX_RESPAWN := 1.6
const EXTRA := [
	{"model": "mini/robot", "name": "Robo-Rudi", "kart": "kart/oozi", "color": Color("#9aa7b8")},
	{"model": "mini/alien", "name": "Zorbi", "kart": "kart/ooli", "color": Color("#7dff9a")},
	{"model": "mini/zombie", "name": "Zombie-Zack", "kart": "kart/oodi", "color": Color("#8fbf6a")},
	{"model": "mini/worker", "name": "Baustellen-Berta", "kart": "kart/oobi", "color": Color("#ffb347")},
]

var def: Dictionary
var track: RaceTrack
var racers: Array[Racer] = []
var focus: Racer
var cam: Camera3D
var laps := 3
var state := "intro"
var race_time := 0.0
var projectiles: Array[Dictionary] = []
var traps: Array[Dictionary] = []        # Honigpfützen: {node, s, x, life, hits, owner}
var _last_thunder := -99.0
var boxes: Array[Dictionary] = []
var _closeup_cd := 0.0
var _finish_wait := -1.0
var _env: Environment
var _env_base := {}
var _underwater := 0.0
var _bubbles: CPUParticles3D
var _rays_sun: DirectionalLight3D

# HUD
var _hud: Control
var _pos_label: Label
var _lap_label: Label
var _time_label: Label
var _speed_label: Label
var _item_icon: UIIcon
var _item_panel: PanelContainer
var _drift_bar: ColorRect
var _msg: Label
var _minimap: Control
var _splat: Control
var _roll_t := 0.0


func _ready() -> void:
	Game.mode = "race" if Game.mode != "free_play" else Game.mode
	laps = int(Game.race_cfg.laps)
	def = TrackDefs.get_def(Game.race_cfg.track)
	var we := WorldKit.env(self, def.env)
	if WorldKit.PRESETS.get(def.env, {}).get("rays", false):
		_rays_sun = we.get_meta("sun")
	_env = we.environment
	_env_base = {"fog": _env.fog_enabled, "fog_color": _env.fog_light_color, "fog_density": _env.fog_density, "ambient": _env.ambient_light_color}
	track = RaceTrack.new()
	add_child(track)
	track.build(def)
	mech = TrackMechanics.new()
	add_child(mech)
	mech.on_hit = _hazard_hit
	mech.build(track, def)
	_build_world()
	if _rays_sun:
		for k in 4:
			WorldKit.god_rays(self, track.frame(track.length * k / 4.0).origin, 25.0, _rays_sun, 5)
	_build_boxes()
	_spawn_racers()
	_build_camera()
	_build_hud()
	_setup_views()
	if Net.online:
		Net.message.connect(_on_net)
	Audio.music("race")
	InputHub.set_touch_profile("none")
	_flow()


# --- Welt -----------------------------------------------------------------------------------------------

var scenery: TrackScenery
var mech: TrackMechanics


func _build_world() -> void:
	var theme: String = def.theme
	if theme in TrackScenery.THEMES:
		scenery = TrackScenery.new()
		add_child(scenery)
		scenery.build(track, def, _env)
	var bb := TrackScenery.bounds(track)
	var bc := Vector3(bb.get_center().x, 0, bb.get_center().y)
	match theme:
		"pirates":
			WorldKit.water(self, Vector2(bb.size.x + 500, bb.size.y + 500), -0.6).position = Vector3(bc.x, -0.6, bc.z)
			# Sand nur unter dem Hafen-Teil der Strecke – der Tauchtunnel bleibt im Wasser sichtbar
			var ss := 0.0
			while ss < track.length:
				if not track.is_water(ss) and not track.is_water(ss + 12.0) and not track.is_water(ss - 12.0):
					var o := track.frame(ss).origin
					WorldKit.box(self, Vector3(40, 1, 40), Vector3(o.x, -0.75, o.z), Color("#f1d9a0"), false)
				ss += 18.0
		"volcano":
			WorldKit.box(self, Vector3(bb.size.x + 320, 1, bb.size.y + 320), Vector3(bc.x, -0.8, bc.z), Color("#7a9a4a"), false)
			WorldKit.box(self, Vector3(bb.size.x + 60, 1, bb.size.y + 60), Vector3(bc.x, -0.75, bc.z), Color("#b88a5a"), false)
			for g in track.glide_ranges:   # Lavasee unter dem Gleitflug
				var gm := track.frame((g.x + g.y) * 0.5)
				var lava := WorldKit.lava(self, Vector2(40, g.y - g.x + 30.0), -0.5, Vector2(0.05, 0.1))
				lava.position = Vector3(gm.origin.x, -0.5, gm.origin.z)
				lava.rotation.y = gm.basis.get_euler().y
			var cone := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 14.0
			cm.bottom_radius = 46.0
			cm.height = 38.0
			cm.material = WorldKit.mat(Color("#8a5a42"), 0.95)
			cone.mesh = cm
			var cpos := Vector3(bb.position.x - 70.0, 18, bb.position.y - 50.0)
			cone.position = cpos
			add_child(cone)
			var top := WorldKit.lava(self, Vector2(26, 26), 37.2, Vector2(0.02, 0.03))
			top.position = Vector3(cpos.x, 37.2, cpos.z)
			var smoke := FX.emitter({"amount": 30, "life": 6.0, "one_shot": false, "explosive": 0.0, "spread": 15.0, "vel_min": 2.0, "vel_max": 4.0,
				"gravity": Vector3(0.3, 0.4, 0), "size": 6.0, "color": Color(1, 0.95, 0.9, 0.35), "box": Vector3(10, 1, 10)})
			add_child(smoke)
			smoke.position = Vector3(cpos.x, 39, cpos.z)
			smoke.emitting = true
		"ring":
			WorldKit.box(self, Vector3(bb.size.x + 320, 1, bb.size.y + 320), Vector3(bc.x, -0.8, bc.z), Color("#4c9a36"), false)
		_:
			pass
	_decorate(theme)
	# Start-/Zieltor
	var fr := track.frame(0.0)
	var gate := Assets.spawn("toy/gate_finish", self, fr.origin, 0.0, track.width / 1.55 * 1.05)
	gate.global_transform = Transform3D(fr.basis.scaled(Vector3.ONE * (track.width / 1.55 * 1.05)), fr.origin)
	var light := Assets.spawn("race/light_red", self, fr.origin + fr.basis.y * 9.0 + fr.basis.x * (track.width * 0.5 + 1.0), 0.0, 4.0)
	light.global_basis = fr.basis.scaled(Vector3.ONE * 4.0)


func _decorate(theme: String) -> void:
	var keys: Array
	var near: Array
	match theme:
		"storm", "snow", "space", "city", "desert":
			keys = []
			near = []
		"pirates":
			keys = ["pirate/palm", "pirate/palm_bend", "pirate/palm_detailed", "pirate/rocks_a", "pirate/rocks_b", "pirate/barrel", "pirate/crate", "pirate/flag", "pirate/tower_small"]
			near = ["race/barrier_white", "pirate/barrel", "race/flag_red"]
		"volcano":
			keys = ["pirate/palm", "pirate/palm_bend", "nat/rock_large", "nat/rock_tall", "nat/cliff_stone", "pirate/rocks_a", "nat/bush", "race/tent", "nat/tree_palm"]
			near = ["race/barrier_white", "pirate/barrel", "race/flag_red", "race/pylon"]
		_:
			keys = ["race/tree_large", "race/tree_small", "nat/tree_oak", "nat/tree_default", "race/tent", "race/billboard", "race/banner_tower_red", "race/banner_tower_green", "race/radar", "race/pits"]
			near = ["race/barrier_red", "race/barrier_white", "race/light_post", "race/flag_checkers", "race/pylon"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(def.id)
	var s := 0.0 if not (theme in TrackScenery.THEMES) else track.length   # v2-Themen dekoriert TrackScenery
	while s < track.length:
		var fr := track.frame(s)
		var flat_up := fr.basis.y.dot(Vector3.UP) > 0.95 and fr.origin.y < 2.5 and fr.origin.y > -1.5
		if flat_up and not track.is_glide(s) and not track.is_water(s) and not track.is_loop(s):
			for side: float in [-1.0, 1.0]:
				var off := track.width * 0.5 + rng.randf_range(2.5, 4.0)
				var p: Vector3 = fr.origin + fr.basis.x * side * off
				p.y = 0.0
				if rng.randf() < 0.5 and track.min_dist_to_track(p) > track.width * 0.5 + 1.0:
					var n := WorldKit.place(self, near[rng.randi() % near.size()], p, 0.0, 3.0, false, false)
					n.look_at(p + fr.basis.z, Vector3.UP)
				var far_p: Vector3 = fr.origin + fr.basis.x * side * (track.width * 0.5 + rng.randf_range(9.0, 26.0))
				far_p.y = 0.0
				if rng.randf() < 0.55 and track.min_dist_to_track(far_p) > track.width * 0.5 + 5.0:
					var k: String = keys[rng.randi() % keys.size()]
					var scl := rng.randf_range(3.0, 5.0) if k.begins_with("race/") or k.begins_with("nat/") else rng.randf_range(1.3, 2.6)
					WorldKit.place(self, k, far_p, rng.randf() * 360.0, scl, false, rng.randf() < 0.3)
		s += 11.0
	# Tribünen am Start
	for i in (4 if theme != "space" else 0):
		var fr2 := track.frame(track.length - 20.0 + i * 12.0)
		var p2 := fr2.origin - fr2.basis.x * (track.width * 0.5 + 6.0)
		p2.y = 0.0
		var gs := WorldKit.place(self, "race/grandstand_round", p2, 0.0, 5.0, false)
		gs.look_at(fr2.origin, Vector3.UP)
	# Warme Fackel-Lichter am Vulkan
	if theme == "volcano":
		var s2 := 0.0
		var colors := [Color(1.0, 0.75, 0.45), Color(1.0, 0.6, 0.35), Color(1.0, 0.85, 0.6)]
		var ci := 0
		while s2 < track.length:
			var fr3 := track.frame(s2)
			var l := OmniLight3D.new()
			l.light_color = colors[ci % 3]
			l.light_energy = 1.2
			l.omni_range = 12.0
			add_child(l)
			l.global_position = fr3.origin + fr3.basis.y * 4.0
			ci += 1
			s2 += 45.0
	# Unterwasser: Fische und Korallen um den Tunnel
	for wr in track.water_ranges:
		var s3 := wr.x
		while s3 < wr.y:
			var fr4 := track.frame(s3)
			for k2 in 2:
				var fish := Assets.spawn("surv/fish_small" if k2 == 0 else "surv/fish", self, fr4.origin + fr4.basis.x * randf_range(-18, 18) + fr4.basis.y * randf_range(2, 9), randf() * 360.0, randf_range(8.0, 14.0))
				Assets.tint(fish, Color.from_hsv(randf(), 0.5, 1.0))
				fish.set_meta("swim", randf() * TAU)
			WorldKit.place(self, "nat/lily", fr4.origin + fr4.basis.x * randf_range(-16, 16) - fr4.basis.y * 0.5, 0.0, 6.0)
			s3 += 14.0


func _build_boxes() -> void:
	for rs in track.item_rows:
		for lx in BOX_LANES:
			var n := Node3D.new()
			add_child(n)
			var m := Assets.spawn("toy/item_box", n, Vector3(0, -0.65, 0), 45.0, 3.0)
			var q := Label3D.new()
			q.text = "?"
			q.font = UI.title_font()
			q.font_size = 120
			q.outline_size = 20
			q.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			q.pixel_size = 0.006
			q.position.y = 0.0
			n.add_child(q)
			boxes.append({"node": n, "s": rs + 10.0, "x": lx, "respawn": 0.0})


func _mode() -> String:
	return String(Game.race_cfg.get("mode", "single"))


func _spawn_racers() -> void:
	var entries: Array = []
	var time_trial := _mode() == "time"
	if not time_trial:
		for e in EXTRA:
			entries.append({"slot": -1, "model": e.model, "name": e.name, "kart": e.kart, "color": e.color})
	var kart_keys := ["kart/oobi", "kart/oodi", "kart/ooli", "kart/oopi"]
	for i in (1 if time_trial else 4):
		var hero := Game.hero(Game.players[i].hero)
		entries.append({"slot": i, "model": hero.model, "name": hero.name, "kart": kart_keys[i], "color": Game.player_color(i)})
	for i in entries.size():
		var e: Dictionary = entries[i]
		var r := Racer.new()
		add_child(r)
		r.setup(i, e.slot, e.kart, e.model, e.name, e.color, track)
		var row := i / 2
		r.place_on_grid(track.length - 10.0 - row * 7.5, (-3.4 if i % 2 == 0 else 3.4))
		r.lap_done.connect(_on_lap)
		r.item_changed.connect(_on_item_changed)
		racers.append(r)
	focus = racers[mini(4, racers.size() - 1)]
	for r in racers:
		if Net.online and not Net.owns_slot(r.slot):
			r.remote = true
	for r in racers:
		if r.slot >= 0 and not r.is_cpu and not r.remote:
			focus = r
			break


# --- Split-Screen & Multi-Monitor ----------------------------------------------------------------------------
## 2–4 menschliche Fahrer bekommen je eine eigene Kamera. Im Browser/auf einem Bildschirm wird geteilt
## (2 = oben/unten, 3–4 = Raster). Nativ mit mehreren Monitoren wandern weitere Spieler auf eigene
## Vollbild-Fenster auf den anderen Bildschirmen. Monitor-Änderungen werden alle 2 s erkannt.

var views: Array[SplitView] = []
var _split_layer: CanvasLayer
var _windows: Array[Window] = []
var _screen_count := 1
var _screen_poll := 2.0
var _split_in_main := false
var _views_on := false
var _extra_maps: Array[Control] = []


func _exit_tree() -> void:
	# Die Haupt-Viewport-Einstellung überdauert Szenenwechsel – immer zurücksetzen
	get_viewport().disable_3d = false


func _humans() -> Array[Racer]:
	var out: Array[Racer] = []
	for r in racers:
		if r.slot >= 0 and not r.remote and (not r.is_cpu or "--split-test" in OS.get_cmdline_user_args()):
			out.append(r)
	out.sort_custom(func(a: Racer, b: Racer) -> bool: return a.slot < b.slot)
	return out


func _teardown_views() -> void:
	for v in views:
		v.queue_free()
	views.clear()
	for w in _windows:
		w.queue_free()
	_windows.clear()
	_extra_maps.clear()
	if _split_layer:
		_split_layer.queue_free()
		_split_layer = null
	_split_in_main = false


func _setup_views() -> void:
	_teardown_views()
	var humans := _humans()
	_screen_count = DisplayServer.get_screen_count()
	if humans.size() < 2 or not Game.settings.get("split_screen", true):
		return
	var multi: bool = not OS.has_feature("web") and _screen_count > 1 and bool(Game.settings.get("multi_display", true)) and DisplayServer.get_name() != "headless"
	var screens := mini(_screen_count, humans.size()) if multi else 1
	var groups: Array = []
	for i in screens:
		groups.append([])
	for k in humans.size():
		(groups[k % screens] as Array).append(humans[k])
	for gi in groups.size():
		var group: Array = groups[gi]
		if gi == 0 and group.size() == 1:
			focus = group[0]   # Hauptfenster zeigt P1 mit normaler Kamera und vollem HUD
			continue
		var host: Node
		if gi == 0:
			_split_layer = CanvasLayer.new()
			_split_layer.layer = 5
			add_child(_split_layer)
			host = _split_layer
			_split_in_main = true
		else:
			var w := Window.new()
			w.title = "Lumos Nitro Dash – Monitor %d" % (gi + 1)
			w.borderless = true
			w.unfocusable = false
			add_child(w)
			var rect := DisplayServer.screen_get_usable_rect(gi)
			w.current_screen = gi
			w.position = rect.position
			w.size = rect.size
			w.mode = Window.MODE_FULLSCREEN
			w.close_requested.connect(func() -> void: w.hide())
			_windows.append(w)
			host = w
		var grid: Container
		if group.size() == 2:
			grid = VBoxContainer.new()
		else:
			var gc := GridContainer.new()
			gc.columns = 2 if group.size() > 1 else 1
			grid = gc
		grid.add_theme_constant_override("separation", 4)
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		grid.set_anchors_preset(Control.PRESET_FULL_RECT)
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(grid)
		for r in group:
			var v := SplitView.new().setup(r, laps)
			grid.add_child(v)
			views.append(v)
		if group.size() == 3:
			# 4. Viertel: Übersichtskarte
			var fill := ColorRect.new()
			fill.color = Color(0.05, 0.02, 0.12, 0.92)
			fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
			grid.add_child(fill)
			var mm := MiniMap.new()
			mm.race = self
			UI.place(mm, Control.PRESET_CENTER, Vector2(-120, -120), Vector2(240, 240))
			fill.add_child(mm)
			_extra_maps.append(mm)
	if focus.is_cpu and not humans.is_empty():
		focus = humans[0]
	# Haupt-HUD im Split nur für Meldungen + Karte
	_pos_label.get_parent().visible = not _split_in_main
	_item_panel.visible = not _split_in_main
	_speed_label.get_parent().visible = not _split_in_main
	if _split_in_main:
		UI.place(_minimap, Control.PRESET_CENTER, Vector2(-80, -80), Vector2(160, 160))
		_minimap.visible = humans.size() != 3
	_set_views_on(_views_on)


func _set_views_on(on: bool) -> void:
	_views_on = on
	if _split_layer:
		_split_layer.visible = on
	for w in _windows:
		w.visible = on
	# Hauptansicht nicht doppelt rendern, solange das Raster sie komplett verdeckt
	get_viewport().disable_3d = on and _split_in_main
	for v in views:
		v.vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
		v.fit_hud.call_deferred()


# --- Kamera ---------------------------------------------------------------------------------------------

func _build_camera() -> void:
	cam = Camera3D.new()
	cam.fov = 68.0
	cam.far = 700.0
	cam.set_meta("base_fov", 68.0)
	add_child(cam)
	cam.make_current()
	var fr := focus.global_transform
	cam.global_position = fr.origin + fr.basis.z * 8.0 + fr.basis.y * 3.2
	cam.look_at(fr.origin, Vector3.UP)
	_bubbles = FX.make_trail(cam, "bubbles")
	_bubbles.position = Vector3(0, -1, -6)
	_bubbles.amount = 30
	_bubbles.emission_sphere_radius = 6.0


var _cam_up := Vector3.UP


func _update_camera(delta: float) -> void:
	if CutsceneManager.active:
		return
	var fr := focus.global_transform
	var fwd := -fr.basis.z
	var up := fr.basis.y
	_cam_up = _cam_up.lerp(up.normalized(), clampf(delta * 5.0, 0, 1)).normalized()
	var drift_side := fr.basis.x * float(focus.drift_dir) * -1.2
	var dist := 5.4 + absf(focus.v) * 0.03
	var want := fr.origin - fwd * dist + _cam_up * (3.9 + (1.5 if focus.gliding else 0.0)) + drift_side
	cam.global_position = cam.global_position.lerp(want, 1.0 - exp(-delta * 9.0))
	var look := fr.origin + fwd * 6.0 + _cam_up * 1.0
	if cam.global_position.distance_to(look) > 0.1:
		cam.look_at(look, _cam_up)
	var base_fov := 66.0 + clampf(absf(focus.v) / Racer.MAX_SPEED, 0, 1.4) * 8.0 + (6.0 if focus.boost_t > 0.0 else 0.0)
	cam.set_meta("base_fov", base_fov)
	cam.fov = lerpf(cam.fov, base_fov, clampf(delta * 3.0, 0, 1))


# --- Ablauf -------------------------------------------------------------------------------------------------

func _flow() -> void:
	await get_tree().process_frame
	await CutsceneManager.play("RaceIntro", {"race": self})
	await _net_barrier()
	InputHub.set_touch_profile("race")
	_set_views_on(true)
	state = "countdown"
	var early := {}
	_countdown_watch(early)
	await CutsceneManager.countdown("LOS!")
	state = "race"
	for r in racers:
		r.started = true
		if not r.is_cpu:
			if early.get(r.idx, false):
				r.stun_t = 0.7
				r.visual.spin_out(1.0, 0.7)
				_message("Fehlstart!", Color("#ff6b6b"))
			elif InputHub.held(r.slot, "a") or (Game.settings.auto_accel and Game.is_touch_device):
				r._boost(1.0, false)
				_message("Raketenstart!", Color("#7fd6ff"))
		elif randf() < 0.3 + 0.2 * r.cpu_level:
			r._boost(0.8, false)


func _countdown_watch(early: Dictionary) -> void:
	# A vor "2" gedrückt = Fehlstart, zwischen "1" und "LOS" gehalten = Raketenstart
	var t := 0.0
	while state == "countdown":
		t += get_process_delta_time()
		for r in racers:
			if not r.is_cpu and t < 1.0 and InputHub.ui_pressed(r.slot, "a"):
				early[r.idx] = true
		await get_tree().process_frame


var _net_t := 0.0
var _net_ready: Dictionary = {}
var _net_go := false


func _net_hit(r: Racer, kind: String, proj := "") -> void:
	if Net.online and not r.remote:
		Net.send({"k": "hit", "i": r.idx, "kind": kind, "p": proj}, true)


func _on_net(from: String, msg: Dictionary) -> void:
	var k := String(msg.get("k", ""))
	var i := int(msg.get("i", -1))
	var r: Racer = racers[i] if i >= 0 and i < racers.size() else null
	match k:
		"rsb":
			for st in msg.get("l", []):
				if st is Dictionary:
					var ri := int((st as Dictionary).get("i", -1))
					if ri >= 0 and ri < racers.size() and racers[ri].remote:
						racers[ri].push_snapshot(st as Dictionary)
		"rs":
			if r and r.remote:
				r.push_snapshot(msg)
		"item":
			if r and r.remote:
				use_item(r, String(msg.get("kind", "")), true)
		"refl":   # Spiegelschild: Geschoss kehrt um und fliegt zum Absender zurück
			var owner_i := int(msg.get("o", -1))
			if r and r.remote and owner_i >= 0 and owner_i < racers.size():
				_remove_near_projectile(r, String(msg.get("p", "")))
				_reflect(r, racers[owner_i], String(msg.get("p", "pie")))
		"trap":   # Honigpfütze verbraucht
			for tp in traps.duplicate():
				if int(tp.get("id", -1)) == int(msg.get("t", -2)):
					_remove_trap(tp)
		"hit":
			if r and r.remote:
				if String(msg.get("kind", "")) == "block":
					r.bubble_t = 0.0
					FX.burst(r.global_position + Vector3.UP * 1.2, {"amount": 18, "life": 0.6, "spread": 180.0, "vel_min": 3.0, "vel_max": 6.0,
						"size": 0.35, "color": Color(0.75, 0.95, 1.0, 0.8)})
					Audio.sfx("pop", r.global_position, -4.0, 0.9)
				else:
					r.invuln_t = 0.0
					r.hit(String(msg.get("kind", "spin")))
				_remove_near_projectile(r, String(msg.get("p", "")))
		"ready":
			_net_ready[from] = true
		"go":
			_net_go = true
		"left":
			for o in racers:
				if o.remote and o.slot >= 0 and not o.is_cpu and not o.finished and _slot_of_peer(from) == o.slot:
					o.finished = true
					o.finish_time = race_time + 999.0
					_message("%s hat das Spiel verlassen" % o.display_name, Color(1, 1, 1, 0.8))


func _remove_near_projectile(r: Racer, proj: String) -> void:
	if proj == "":
		return
	for p in projectiles.duplicate():
		if p.kind == proj and absf(track.wrap_s(r.s - float(p.s) + track.length * 0.5) - track.length * 0.5) < 9.0:
			FX.smoke((p.node as Node3D).global_position, Color(1, 1, 1), 6, 0.6)
			(p.node as Node3D).queue_free()
			projectiles.erase(p)
			return


func _slot_of_peer(id: String) -> int:
	return int((Net.game_cfg.get("slots", {}) as Dictionary).get(id, -1))


## Online: alle Geräte starten den Countdown gleichzeitig (Host gibt das Signal).
func _net_barrier() -> void:
	if not Net.online:
		return
	# Lade-Gate: Der Countdown startet erst, wenn ALLE Geräte die Strecke fertig geladen haben
	await Net.loading_gate()
	if "--net-test" in str(OS.get_cmdline_user_args()):
		print("[NET] Start-Countdown um %.2f s (Host=%s)" % [Time.get_ticks_msec() / 1000.0, Net.is_host])


func _physics_process(delta: float) -> void:
	if Net.online and state != "intro":
		_net_t += delta
		if _net_t >= 1.0 / Net.state_rate():
			_net_t = 0.0
			var batch: Array = []
			for r in racers:
				if not r.remote:
					batch.append(r.net_state())
			if not batch.is_empty():
				Net.send({"k": "rsb", "l": batch}, false)
	if state == "intro":
		for r in racers:
			r.tick(delta)
		return
	if state == "race" or state == "finish":
		race_time += delta
	for r in racers:
		_rubber_band(r)
		r.tick(delta)
	_collide_racers()
	_update_boxes(delta)
	_update_projectiles(delta)
	_update_traps(delta)
	_update_item_fx(delta)
	if state == "race" or state == "finish":
		mech.tick(race_time, racers)
	_rank()
	_closeup_cd = maxf(0.0, _closeup_cd - delta)
	# Online: Ein entfernter Fahrer meldet sein Ziel per Zustand („fi“) – dabei läuft _on_lap nicht durch die
	# Ziel-Logik. Deshalb hier jede Physik-Runde prüfen, ob alle menschlichen Fahrer im Ziel sind.
	if state == "race" and _finish_wait < 0.0 and _all_humans_done():
		_finish_wait = 3.5
		state = "finish"
	if _finish_wait > 0.0:
		_finish_wait -= delta
		if _finish_wait <= 0.0:
			_end_race()


func _process(delta: float) -> void:
	_update_camera(delta)
	_update_hud(delta)
	for v in views:
		v.tick(delta, race_time)
	for m in _extra_maps:
		m.queue_redraw()
	_screen_poll -= delta
	if _screen_poll <= 0.0:
		_screen_poll = 2.0
		var sc := DisplayServer.get_screen_count()
		if sc != _screen_count and state in ["countdown", "race"]:
			_screen_count = sc
			_message("Bildschirme erkannt: %d" % sc, UI.ACCENT2, 1.2)
			_setup_views()
			_set_views_on(true)
	_update_underwater(delta)
	for c in get_children():
		if c.has_meta("swim"):
			var n := c as Node3D
			n.position += -n.global_basis.z * delta * 2.0
			n.rotation.y += delta * 0.4


func _rubber_band(r: Racer) -> void:
	if not r.is_cpu or r.remote:
		r.speed_mult = 1.0
		return
	var base: float = Game.lv([0.9, 0.97, 1.02], r.cpu_level, false)   # Insane: kein Tempo-Bonus (wäre Mogeln)
	var gap := focus.progress - r.progress
	var band := 1.0
	if gap > 40.0:
		band = 1.07
	elif gap < -70.0:
		band = 0.93
	r.speed_mult = base * band


## Kart-Kollisionen mit Masse: Boost und Komet schieben stärker, geschrumpfte Karts fliegen weg. Seitliche Rempler
## geben beiden einen Dreh- und Wank-Impuls; Auffahrunfälle tauschen Tempo. Wer den Kometen berührt, wird
## weggeschleudert (entschieden vom Gerät des Getroffenen).
func _collide_racers() -> void:
	for a in racers.size():
		for b in range(a + 1, racers.size()):
			var ra := racers[a]
			var rb := racers[b]
			var ds := track.wrap_s(rb.s - ra.s)
			if ds > track.length * 0.5:
				ds -= track.length
			if absf(ds) > 2.8 or absf(rb.h - ra.h) > 1.5:
				continue
			var dx := rb.x - ra.x
			if absf(dx) >= 2.3:
				continue
			# Komet: weg da!
			if ra.comet_t > 0.0 or rb.comet_t > 0.0:
				var victim := rb if ra.comet_t > 0.0 else ra
				var rammer := ra if victim == rb else rb
				if victim.comet_t <= 0.0 and not victim.remote and victim.hit("knock"):
					victim.x = clampf(victim.x + signf(victim.x - rammer.x + 0.01) * 2.5, -track.width * 0.5 + 2.0, track.width * 0.5 - 2.0)
					_net_hit(victim, "knock")
					Audio.sfx("explosion_big", victim.global_position, -8.0, 1.5)
					FX.stars(victim.global_position + Vector3.UP * 1.5, Color(1, 0.9, 0.4), 14)
				continue
			var ma := _mass(ra)
			var mb := _mass(rb)
			var overlap := 2.3 - absf(dx)
			var dirx := 1.0 if dx >= 0 else -1.0
			ra.x -= overlap * dirx * mb / (ma + mb)
			rb.x += overlap * dirx * ma / (ma + mb)
			var dv := (ra.v - rb.v) * 0.3
			if ds > 0:
				ra.v -= maxf(dv, 0.0) * mb / (ma + mb) * 2.0
				rb.v += maxf(dv, 0.0) * ma / (ma + mb) * 2.0
			else:
				rb.v -= maxf(-dv, 0.0) * ma / (ma + mb) * 2.0
				ra.v += maxf(-dv, 0.0) * mb / (ma + mb) * 2.0
			if overlap > 0.25:
				var strength := clampf(overlap / 1.2, 0.3, 1.0)
				ra.psi -= dirx * 0.1 * strength * mb / ma
				rb.psi += dirx * 0.1 * strength * ma / mb
				ra.visual.bump(dirx, strength * mb / ma)
				rb.visual.bump(-dirx, strength * ma / mb)
				if ra.drift_dir != 0 and overlap > 0.8:
					ra.drift_level = maxi(0, ra.drift_level - 1)
				if rb.drift_dir != 0 and overlap > 0.8:
					rb.drift_level = maxi(0, rb.drift_level - 1)
				var mid := (ra.global_position + rb.global_position) * 0.5
				Audio.sfx("punch", mid, -8.0)
				FX.sparks(mid + Vector3.UP * 0.5, Color(1, 0.9, 0.5), 6)
				if ra == focus or rb == focus:
					InputHub.rumble(focus.slot, 0.4, 0.1)


## Streckengefahr hat ein eigenes Kart erwischt (Lavafontäne, Baumstamm).
func _hazard_hit(r: Racer, kind: String) -> void:
	if r.hit("spin"):
		if kind == "geyser":
			r.vh = 7.0
			r.h = maxf(r.h, 0.1)
			FX.burst(r.global_position + Vector3.UP, {"amount": 18, "life": 0.7, "spread": 50.0, "dir": Vector3.UP, "vel_min": 4.0, "vel_max": 8.0,
				"gravity": Vector3(0, -12, 0), "size": 0.4, "additive": true, "color": Color(1.0, 0.55, 0.2)})
			Audio.sfx("explosion_big", r.global_position, -8.0, 1.4)
		else:
			Audio.sfx("stone_hit", r.global_position, -2.0, 0.8)
			FX.dust(r.global_position, Color(0.6, 0.5, 0.35), 12, 1.2)
		_net_hit(r, "spin")
		if r == focus:
			_message("Lava!" if kind == "geyser" else "Baumstamm!", Color("#ff9f43"))


## Sprungfeld überfahren (vom Kart gemeldet) – nur Optik.
func on_bounce(s: float, x: float) -> void:
	mech.bounce_fx(s, x)


func _mass(r: Racer) -> float:
	return (1.6 if r.boost_t > 0.0 else 1.0) * (0.45 if r.shrink_t > 0.0 else 1.0)


func _rank() -> void:
	var order := racers.duplicate()
	order.sort_custom(func(a: Racer, b: Racer) -> bool:
		if a.finished != b.finished:
			return a.finished
		if a.finished:
			return a.finish_time < b.finish_time
		return a.progress > b.progress)
	for i in order.size():
		(order[i] as Racer).place = i + 1


var _lap_t0 := 0.0
var lap_times: Array[float] = []


func _on_lap(r: Racer, lap: int) -> void:
	if r == focus:
		if lap <= 0:
			_lap_t0 = race_time
		else:
			lap_times.append(race_time - _lap_t0)
			_lap_t0 = race_time
			if _mode() == "time":
				var lt := lap_times[lap_times.size() - 1]
				var rec := Game.record_for(String(def.id))
				var best_lap: float = rec.get("lap", INF)
				var is_best: bool = lt < best_lap and lap_times.min() == lt
				_message("Runde: %s%s" % [_fmt(lt), "  NEUER RUNDENREKORD!" if is_best else ""], UI.GOLD if is_best else Color.WHITE, 1.4)
	if lap >= laps and not r.finished:
		r.finished = true
		r.finish_time = race_time
		if not r.is_cpu:
			Audio.sfx("bell")
			Audio.jingle("finish")
			_message("ZIEL! %d. Platz" % r.place, UI.GOLD)
			FX.confetti(r.global_position + Vector3.UP * 3.0, 80)
			r.visual.hero.react("victory")
		if (_all_humans_done() and _finish_wait < 0.0) or (focus.is_cpu and r == focus):
			_finish_wait = 3.5
			state = "finish"
	elif lap == laps - 1 and r == focus:
		Audio.voice("final_round")
		Audio.minigame_hurry()   # letzte Runde: taktgenau in die Hurry-Up-Version
		_message("LETZTE RUNDE!", Color("#ff4d6d"))
	elif r == focus and lap > 0 and lap < laps:
		Audio.sfx("bong")
		_message("Runde %d / %d" % [lap + 1, laps], Color.WHITE)


func _all_humans_done() -> bool:
	var humans := 0
	for o in racers:
		if not o.is_cpu:
			humans += 1
			if not o.finished:
				return false
	return humans > 0


func _end_race() -> void:
	state = "done"
	_set_views_on(false)
	Audio.minigame_outro()
	InputHub.set_touch_profile("none")
	var order := racers.duplicate()
	order.sort_custom(func(a: Racer, b: Racer) -> bool: return a.place < b.place)
	var entries: Array = []
	for r in order:
		entries.append({"model": r.visual.hero.model_key, "name": r.display_name, "color": r.color, "player": r.slot})
	if _mode() != "time":
		for r in racers:
			if r.slot >= 0 and not r.is_cpu:
				EventBus.race_result.emit(r.slot, r.place)
	if Net.online:
		if "--net-test" in str(OS.get_cmdline_user_args()):
			print("[NET] Rennende %.2f s · empfangen %s · Reihenfolge %s" % [Time.get_ticks_msec() / 1000.0, Net.debug_counts,
				order.map(func(r: Racer) -> String: return "%s%s" % [r.display_name, "(remote)" if r.remote else ""])])
		await _results(order)
		Net.back_to_lobby()
		Router.goto("res://scenes/menu/MainMenu.tscn", {"page": "online"})
		return
	match _mode():
		"time":
			await _time_trial_results()
			Router.goto("res://scenes/menu/MainMenu.tscn")
			return
		"gp":
			await _results(order)
			await _gp_standings(order)
			return
	var podium := [entries[0], entries[1], entries[2], entries[entries.size() - 1]]
	await CutsceneManager.play("Podium", {"entries": podium, "skippable": true})
	await _results(order)
	Router.goto("res://scenes/menu/MainMenu.tscn")


static func _fmt(t: float) -> String:
	if t == INF:
		return "—"
	return "%d:%05.2f" % [int(t) / 60, fmod(t, 60.0)]


# --- Zeitfahren ---------------------------------------------------------------------------------------------

func _time_trial_results() -> void:
	var total := focus.finish_time if focus.finished else race_time
	var best_lap := INF
	for lt in lap_times:
		best_lap = minf(best_lap, lt)
	var res := Game.submit_time(String(def.id), total, best_lap)
	if res.total_record:
		Audio.voice("new_highscore")
		FX.confetti(focus.global_position + Vector3.UP * 3.0, 100)
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var root := UI.center_root(layer)
	var panel := UI.panel()
	root.add_child(panel)
	panel.custom_minimum_size = Vector2(640, 0)
	var v := UI.vbox(10)
	panel.add_child(v)
	var t := UI.label("Zeitfahren – %s" % def.name, 46, UI.GOLD, true, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	for i in lap_times.size():
		var row := UI.hbox(14)
		var l := UI.label("Runde %d" % (i + 1), 28, Color.WHITE, true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UI.label(_fmt(lap_times[i]), 28, UI.GOLD if lap_times[i] == best_lap else Color.WHITE, true))
		v.add_child(row)
	var tot := UI.label("Gesamt: %s" % _fmt(total), 40, Color.WHITE, true, 8)
	tot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tot)
	var rec_txt := "NEUER STRECKENREKORD!" if res.total_record else "Rekord: %s" % _fmt(float(res.best_total))
	var rec := UI.label(rec_txt, 32, Color("#7dff9a") if res.total_record else Color(1, 1, 1, 0.8), true)
	rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(rec)
	v.add_child(UI.prompt("a", "Weiter", 26))
	await get_tree().process_frame
	panel.position = (root.size - panel.size) / 2.0
	Juice.pop_in(panel, 0.4)
	if res.total_record:
		Juice.ui_punch(rec, 0.3, 0.6)
	var wait := 0.0
	while wait < (15.0 if not focus.is_cpu else 3.0):
		await get_tree().process_frame
		wait += get_process_delta_time()
		if wait > 0.6 and InputHub.any_human_pressed("a"):
			break


# --- Grand Prix ------------------------------------------------------------------------------------------------

func _gp_standings(order: Array) -> void:
	var gp: Dictionary = Game.gp
	if gp.is_empty():
		Router.goto("res://scenes/menu/MainMenu.tscn")
		return
	var pts: Dictionary = gp.points
	var gained := {}
	for r in order:
		var rr := r as Racer
		var add: int = Game.GP_POINTS[clampi(rr.place - 1, 0, Game.GP_POINTS.size() - 1)]
		pts[rr.display_name] = int(pts.get(rr.display_name, 0)) + add
		gained[rr.display_name] = add
		gp.colors[rr.display_name] = rr.color
		gp.models[rr.display_name] = rr.visual.hero.model_key
		gp.slots[rr.display_name] = rr.slot
	var names: Array = pts.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return int(pts[a]) > int(pts[b]))
	var last_race := int(gp.index) + 1 >= (gp.tracks as Array).size()
	var layer := CanvasLayer.new()
	layer.layer = 41
	add_child(layer)
	var root := UI.center_root(layer)
	var panel := UI.panel()
	root.add_child(panel)
	panel.custom_minimum_size = Vector2(700, 0)
	var v := UI.vbox(6)
	panel.add_child(v)
	var t := UI.label("%s – %s" % [gp.cup, "Endstand" if last_race else "Rennen %d/%d" % [int(gp.index) + 1, (gp.tracks as Array).size()]], 42, UI.GOLD, true, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	for k in names.size():
		var nm: String = names[k]
		var row := UI.hbox(12)
		var pl := UI.label("%d." % (k + 1), 28, UI.GOLD if k == 0 else Color.WHITE, true)
		pl.custom_minimum_size.x = 50
		row.add_child(pl)
		var slot: int = int(gp.slots.get(nm, -1))
		var n := UI.label(nm + ("" if slot < 0 else "  (P%d)" % (slot + 1)), 26, (gp.colors[nm] as Color).lightened(0.3), true)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		row.add_child(UI.label("+%d" % int(gained.get(nm, 0)), 22, Color("#7dff9a"), true))
		var p := UI.label("%d" % int(pts[nm]), 28, Color.WHITE, true)
		p.custom_minimum_size.x = 56
		p.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(p)
		v.add_child(row)
	if not last_race:
		var next_id: String = gp.tracks[int(gp.index) + 1]
		var nl := UI.label("Nächstes Rennen: %s" % Game.track_info(next_id).name, 28, UI.ACCENT2, true)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nl)
	v.add_child(UI.prompt("a", "Siegerehrung" if last_race else "Weiter", 26))
	await get_tree().process_frame
	panel.position = (root.size - panel.size) / 2.0
	Juice.pop_in(panel, 0.4)
	var human := false
	for r in racers:
		if not r.is_cpu:
			human = true
	var wait := 0.0
	while wait < (15.0 if human else 3.0):
		await get_tree().process_frame
		wait += get_process_delta_time()
		if wait > 0.6 and InputHub.any_human_pressed("a"):
			break
	layer.queue_free()
	if last_race:
		for k in names.size():
			var sl: int = int(gp.slots.get(names[k], -1))
			if sl >= 0 and not Game.players[sl].cpu:
				EventBus.gp_result.emit(sl, k + 1, String(gp.cup))
		var entries: Array = []
		for nm in names:
			entries.append({"model": gp.models[nm], "name": nm, "color": gp.colors[nm], "player": int(gp.slots[nm])})
		await CutsceneManager.play("Podium", {"entries": [entries[0], entries[1], entries[2], entries[entries.size() - 1]], "skippable": true})
		Game.gp = {}
		Game.race_cfg.mode = "single"
		Router.goto("res://scenes/menu/MainMenu.tscn")
	else:
		gp.index = int(gp.index) + 1
		Game.race_cfg.track = gp.tracks[int(gp.index)]
		Router.goto("res://scenes/racer/NitroDash.tscn")


# --- Items --------------------------------------------------------------------------------------------------

func _roll_item(place: int) -> String:
	if _mode() == "time":
		return "nitro"
	var table: Dictionary = ITEM_TABLE[1]
	for k in ITEM_TABLE.keys():
		if place >= int(k):
			table = ITEM_TABLE[k]
	var allowed := {}
	for k2 in table.keys():
		if k2 == "thunder" and race_time - _last_thunder < THUNDER_COOLDOWN:
			continue   # Donnerwolke nicht im Dauerfeuer
		if k2 == "comet" and racers.any(func(o: Racer) -> bool: return o.comet_t > 0.0):
			continue   # höchstens ein Komet zugleich
		allowed[k2] = table[k2]
	var total := 0
	for v in allowed.values():
		total += int(v)
	var r := randi() % maxi(total, 1)
	for k3 in allowed.keys():
		r -= int(allowed[k3])
		if r < 0:
			return k3
	return "nitro"


func _update_boxes(delta: float) -> void:
	for b in boxes:
		var n: Node3D = b.node
		if b.respawn > 0.0:
			b.respawn = float(b.respawn) - delta
			if b.respawn <= 0.0:
				n.visible = true
				Juice.pop_in(n, 0.3)
		var fr := track.frame(b.s)
		n.global_position = fr.origin + fr.basis.x * float(b.x) + fr.basis.y * (1.6 + sin(Time.get_ticks_msec() / 300.0 + float(b.x)) * 0.2)
		n.rotation.y += delta * 2.0
		if not n.visible:
			continue
		for r in racers:
			var ds := absf(track.wrap_s(r.s - float(b.s) + track.length * 0.5) - track.length * 0.5)
			if ds < 2.2 and absf(r.x - float(b.x)) < 2.0 and r.h < 2.5:
				n.visible = false
				b.respawn = BOX_RESPAWN
				FX.stars(n.global_position, Color(1, 0.8, 1.0), 10)
				Audio.sfx("glass", n.global_position, -6.0 if not r.is_cpu else -14.0)
				if r.item == "" and r.rolling <= 0.0 and not r.remote:
					r.item = _roll_item(r.place)
					r.rolling = 1.0
					if r == focus:
						_roll_t = 1.0
				break


func ai_wants_item(r: Racer) -> bool:
	match r.item:
		"nitro":
			return absf(track.curvature(r.s, 15.0)) < 0.01
		"spark":
			return absf(track.curvature(r.s, 20.0)) > 0.014
		"megaphone":
			for o in racers:
				if o != r and o.global_position.distance_to(r.global_position) < 16.0:
					return true
			return false
		"pie", "candy":
			for o in racers:
				var ahead := track.wrap_s(o.s - r.s)
				if o != r and ahead > 3.0 and ahead < 40.0 and absf(o.x - r.x) < (3.0 if r.item == "pie" else 7.0):
					return true
			return randf() < 0.12 or r.item_age > 5.0
		"honey":
			if r.item_age > 7.0:
				return true
			for o in racers:
				var behind := track.wrap_s(r.s - o.s)
				if o != r and behind > 3.0 and behind < 28.0:
					return true
			return randf() < 0.2
		"bubble", "mirror":
			if r.item_age > 6.0:
				return true   # nicht ewig horten
			for p in projectiles:
				if p.owner != r and (p.target == r or p.kind in ["pie", "candy"]) and track.wrap_s(r.s - float(p.s)) < 45.0:
					return true
			return r.place <= 2 and randf() < 0.25 or randf() < 0.08
		"homing", "anchor", "thunder":
			return r.place > 1
		"comet":
			return true
	return false


## Item einsetzen. Würfe beginnen mit einer Ausholbewegung des Fahrers; das Geschoss löst sich erst beim Loslassen.
## Online spielen alle Geräte dieselbe Abfolge ab (Nachricht "item"), die Wirkung auf ein Kart entscheidet dessen Besitzer.
func use_item(r: Racer, kind: String, from_net := false) -> void:
	var pos := r.global_position
	if Net.online and not from_net and not r.remote:
		Net.send({"k": "item", "i": r.idx, "kind": kind}, true)
	match kind:
		"nitro":
			r._boost(1.6, false)
			if r == focus:
				Audio.voice("power_up")
		"spark":
			r.spark_t = 7.0
			Audio.sfx("sparkle_up", pos, -4.0, 1.0)
			FX.stars(pos + Vector3.UP * 1.5, Color(0.5, 0.85, 1.0), 12)
		"bubble":
			r.bubble_t = 10.0
			Audio.sfx("pop", pos, -4.0, 0.7)
			Audio.sfx("sparkle_up", pos, -8.0, 1.3)
		"mirror":
			r.mirror_t = 8.0
			Audio.sfx("chime", pos, -4.0, 1.2)
		"comet":
			r.comet_t = 4.0
			r.invuln_t = 0.0
			r.stun_t = 0.0
			r._boost(4.0, false)
			Audio.sfx("whoosh", pos, 0.0, 0.7)
			Audio.sfx("explosion_big", pos, -10.0, 1.8)
			if r == focus:
				Juice.fov_punch(cam, 14.0, 0.8)
				_message("KOMETENRITT!", UI.GOLD)
		"thunder":
			_last_thunder = race_time
			Audio.sfx("thunder", pos, -2.0, 1.0)
			for o in racers:
				if o != r and o.place < r.place and not o.finished:
					_thunder_strike(o, r)
		"megaphone":
			Audio.sfx("megaphone", pos)
			Audio.sfx("explosion_big", pos, -6.0, 1.6)
			FX.shockwave(pos, 18.0, Color(1.0, 0.5, 0.8, 0.9))
			r.visual.wobble(0.15, 0.4)
			if r == focus:
				Juice.shake(0.35)
			for o in racers:
				if o != r and not o.remote and o.global_position.distance_to(pos) < 18.0:
					var mk := "shrink" if randf() < 0.5 else "spin"
					if o.hit(mk):
						_net_hit(o, mk)
						_maybe_closeup(o, r)
		"pie", "candy", "homing", "anchor":
			var release := r.visual.throw_anim(false, kind)
			_after(r, release, func() -> void: _launch_item(r, kind))
		"honey":
			var release2 := r.visual.throw_anim(true, "honey")
			_after(r, release2, func() -> void: _drop_honey(r))


## Verzögert ausführen, solange das Kart existiert (Tween hängt am Kart → stirbt mit ihm).
func _after(r: Racer, t: float, f: Callable) -> void:
	if t <= 0.0:
		f.call()
		return
	var tw := r.create_tween()
	tw.tween_interval(t)
	tw.tween_callback(f)


func _launch_item(r: Racer, kind: String) -> void:
	var pos := r.global_position
	match kind:
		"pie":
			_spawn_projectile(r, "pie", maxf(r.v + 22.0, 42.0), sin(r.psi) * 22.0, 1.6, 5.0)
			Audio.sfx("whoosh", pos)
		"candy":
			for k in 3:
				var p := _spawn_projectile(r, "candy", maxf(r.v + 24.0, 44.0), sin(r.psi) * 24.0 + (k - 1) * 9.0, 1.5, 4.0 + k * 0.6)
				p.life = 4.0
			Audio.sfx("pop", pos, -2.0, 1.3)
		"homing":
			var target: Racer = null
			for o in racers:
				if o.place == r.place - 1:
					target = o
			var p2 := _spawn_projectile(r, "homing", 58.0, 0.0, 1.8, 0.0)
			p2.target = target
			Audio.sfx("evil_laugh", pos)
			Audio.sfx("cannon", pos, -4.0)
			FX.smoke(pos + Vector3.UP * 1.5, Color(0.85, 0.85, 0.85), 8, 0.5)
		"anchor":
			var best: Racer = null
			var bd := 75.0
			for o in racers:
				if o == r:
					continue
				var ahead := track.wrap_s(o.s - r.s)
				if ahead > 1.0 and ahead < bd:
					bd = ahead
					best = o
			var p3 := _spawn_projectile(r, "anchor", 66.0, 0.0, 1.6, 2.0)
			p3.target = best
			Audio.sfx("metal_hit", pos, -4.0)


## Geschoss starten. up = Anfangs-Steiggeschwindigkeit (Wurfbogen); danach landet es und rollt/rutscht weiter.
func _spawn_projectile(owner: Racer, kind: String, speed: float, vx: float, h: float, up := 0.0) -> Dictionary:
	var n := Node3D.new()
	add_child(n)
	var model: Node3D
	match kind:
		"pie":
			model = ItemModels.pie(1.0)
		"candy":
			model = ItemModels.candy([Color("#ff5c9a"), Color("#5cc8ff"), Color("#ffd23f")][randi() % 3], 1.15)
		"homing", "reflect":
			model = ItemModels.cannonball(1.15)
			var fuse := FX.make_trail(n, "sparks")
			fuse.emitting = true
			fuse.color = Color(1, 0.7, 0.2)
			var reticle := Sprite3D.new()
			reticle.texture = Assets.icon("crosshair")
			reticle.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			reticle.modulate = Color(1, 0.2, 0.2) if kind == "homing" else Color(0.6, 0.85, 1.0)
			reticle.pixel_size = 0.02
			reticle.visible = false
			n.add_child(reticle)
			n.set_meta("reticle", reticle)
		"anchor":
			model = ItemModels.anchor(1.0)
	if model:
		model.name = "Model"
		n.add_child(model)
	var p := {"node": n, "kind": kind, "s": owner.s + 2.5, "x": owner.x, "h": h, "vh": up, "speed": speed, "vx": vx,
		"life": 7.0 if kind == "pie" else 5.0, "owner": owner, "target": null, "age": 0.0, "bounces": 0, "spin": 0.0}
	projectiles.append(p)
	_place_projectile(p)
	return p


func _place_projectile(p: Dictionary) -> void:
	var n: Node3D = p.node
	var fr := track.frame(float(p.s))
	n.global_transform = Transform3D(fr.basis, fr.origin + fr.basis.x * float(p.x) + fr.basis.y * float(p.h))


func _update_projectiles(delta: float) -> void:
	for p in projectiles.duplicate():
		p.age = float(p.age) + delta
		p.life = float(p.life) - delta
		var n: Node3D = p.node
		var model := n.get_node_or_null("Model") as Node3D
		var target: Racer = p.target
		var ground := 0.55 if p.kind == "pie" else (0.5 if p.kind == "candy" else 0.0)
		match p.kind:
			"pie", "candy":
				p.s = track.wrap_s(float(p.s) + float(p.speed) * delta)
				p.x = float(p.x) + float(p.vx) * delta
				# Wurfbogen → aufsetzen → rutschen (Kuchen) bzw. hüpfen (Bonbons)
				p.vh = float(p.vh) - 30.0 * delta
				p.h = float(p.h) + float(p.vh) * delta
				if float(p.h) <= ground:
					p.h = ground
					if float(p.vh) < -3.0:
						p.vh = -float(p.vh) * (0.45 if p.kind == "candy" else 0.0)
						if p.kind == "candy" and model:
							Juice.squash(model, 1.3, 0.7, 0.2, model.scale)
					else:
						p.vh = 0.0
				var lim := track.lane_limits(float(p.s), float(p.x))
				lim += Vector2(Racer.RADIUS - 0.8, -(Racer.RADIUS - 0.8))
				if float(p.x) < lim.x or float(p.x) > lim.y:
					p.x = clampf(float(p.x), lim.x, lim.y)
					p.vx = -float(p.vx) * 0.9
					p.bounces = int(p.bounces) + 1
					Audio.sfx("boing", n.global_position, -6.0)
					FX.sparks(n.global_position, Color(1, 1, 0.8), 6)
				if model:
					p.spin = float(p.spin) + delta * (11.0 if p.kind == "pie" else 16.0)
					if p.kind == "pie":   # flach rotierend, leicht taumelnd
						model.rotation = Vector3(sin(float(p.age) * 9.0) * 0.12, float(p.spin), cos(float(p.age) * 7.0) * 0.1)
					else:
						model.rotation = Vector3(-float(p.spin), float(p.spin) * 0.3, 0.0)
			"homing", "anchor", "reflect":
				p.s = track.wrap_s(float(p.s) + float(p.speed) * (delta if p.kind != "reflect" else -delta))
				if target and is_instance_valid(target):
					p.x = lerpf(float(p.x), target.x, clampf(delta * 4.0, 0, 1))
					p.h = lerpf(float(p.h), target.h + 1.0, clampf(delta * 3.0, 0, 1))
					var reticle: Variant = n.get_meta("reticle") if n.has_meta("reticle") else null
					if reticle:
						var near := absf(track.wrap_s(target.s - float(p.s) + track.length * 0.5) - track.length * 0.5) < 30.0
						(reticle as Sprite3D).visible = near
						if near:
							(reticle as Sprite3D).global_position = target.global_position + target.global_basis.y * 2.5
				if model:
					if p.kind == "anchor":
						model.rotation.x += delta * 14.0
					else:   # Kugel rollt vorwärts, das Gesicht schaut grimmig nach vorn
						model.rotation = Vector3(sin(float(p.age) * 6.0) * 0.15, (PI if p.kind == "reflect" else 0.0), sin(float(p.age) * 8.0) * 0.1)
				if p.kind == "homing" and int(p.age * 1.2) != int((float(p.age) - delta) * 1.2):
					Audio.sfx("evil_laugh", n.global_position, -10.0, 1.2)
		_place_projectile(p)
		# Treffer (nur auf eigenen Karts – Opfer-Autorität)
		var done: bool = p.life <= 0.0 or (p.kind == "pie" and int(p.bounces) > 6) or (p.kind == "candy" and int(p.bounces) > 3)
		for r in racers:
			if r == p.owner and float(p.age) < 0.6:
				continue
			if p.kind in ["homing", "anchor", "reflect"] and target and r != target:
				continue
			if r.remote:
				continue
			var ds := track.wrap_s(r.s - float(p.s) + track.length * 0.5) - track.length * 0.5
			var reach := 2.0 if p.kind != "candy" else 1.7
			if absf(ds) < 2.4 and absf(r.x - float(p.x)) < reach and absf(r.h - float(p.h) + 0.8) < 2.4:
				if r.mirror_t > 0.0 and p.kind != "reflect" and is_instance_valid(p.owner) and p.owner != r:
					r.mirror_t = 0.0
					Audio.sfx("metal_hit", r.global_position, -2.0, 1.4)
					FX.ring(r.global_position + Vector3.UP, Color(0.7, 0.9, 1.0, 0.9), 4.0, 0.3)
					_reflect(r, p.owner as Racer, String(p.kind))
					if Net.online:
						Net.send({"k": "refl", "i": r.idx, "o": (p.owner as Racer).idx, "p": p.kind}, true)
				else:
					var kind: String = {"pie": "splat", "candy": "spin", "homing": "blast", "reflect": "blast", "anchor": "anchor"}.get(p.kind, "spin")
					var had_bubble := r.bubble_t > 0.0
					if r.hit(kind):
						_impact(r, p)
						_net_hit(r, kind, String(p.kind))
					elif had_bubble and r.bubble_t <= 0.0:
						_net_hit(r, "block", String(p.kind))
				done = true
				break
		if done:
			if p.life <= 0.0:
				FX.smoke(n.global_position, Color(0.8, 0.8, 0.8), 4, 0.5)
			n.queue_free()
			projectiles.erase(p)


## Spiegelschild: aus dem Geschoss wird eine Kanonenkugel, die zum Absender zurückfliegt.
func _reflect(from: Racer, owner: Racer, _kind: String) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var p := _spawn_projectile(from, "reflect", 60.0, 0.0, 1.8, 0.0)
	p.s = from.s - 1.0
	p.owner = from
	p.target = owner
	var fwd := track.wrap_s(owner.s - from.s)
	if fwd < track.length * 0.5:   # Absender liegt vorn → die Kugel fliegt vorwärts
		p.kind = "homing"
		p.s = from.s + 2.5
	p.age = 0.0


## Honigtopf nach hinten werfen: fliegt im Bogen ein Stück zurück und zerplatzt zur Pfütze.
func _drop_honey(r: Racer) -> void:
	var start := r.global_position + Vector3.UP * 1.6
	var s_drop := track.wrap_s(r.s - 4.5)
	var x_drop := clampf(r.x, -track.width * 0.5 + 2.0, track.width * 0.5 - 2.0)
	var fr := track.frame(s_drop)
	var end_pos := fr.origin + fr.basis.x * x_drop + fr.basis.y * 0.05
	var pot := ItemModels.honey_pot(1.0)
	add_child(pot)
	pot.global_position = start
	var tw := pot.create_tween()
	tw.tween_method(func(u: float) -> void:
		pot.global_position = start.lerp(end_pos, u) + Vector3.UP * sin(u * PI) * 2.0
		pot.rotation = Vector3(u * 5.0, u * 2.0, 0.0), 0.0, 1.0, 0.4)
	tw.tween_callback(func() -> void:
		Audio.sfx("slime", end_pos, -2.0)
		FX.burst(end_pos + Vector3.UP * 0.3, {"amount": 14, "life": 0.6, "spread": 70.0, "vel_min": 2.0, "vel_max": 4.0,
			"gravity": Vector3(0, -12, 0), "size": 0.3, "color": Color(1.0, 0.7, 0.15)})
		pot.queue_free()
		var puddle := ItemModels.honey_puddle(1.7)
		add_child(puddle)
		puddle.global_transform = Transform3D(fr.basis, end_pos)
		puddle.scale = Vector3(0.2, 1.0, 0.2)
		puddle.create_tween().tween_property(puddle, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		traps.append({"node": puddle, "s": s_drop, "x": x_drop, "life": 14.0, "hits": 0, "owner": r, "id": r.idx * 1000 + traps.size() + int(race_time * 10.0) % 997}))


func _update_traps(delta: float) -> void:
	for tp in traps.duplicate():
		tp.life = float(tp.life) - delta
		if float(tp.life) <= 0.0:
			_remove_trap(tp)
			continue
		for r in racers:
			if r.remote or r.h > 0.6 or (r == tp.owner and float(tp.life) > 13.0):
				continue
			var ds := absf(track.wrap_s(r.s - float(tp.s) + track.length * 0.5) - track.length * 0.5)
			if ds < 2.2 and absf(r.x - float(tp.x)) < 2.3:
				var had_bubble := r.bubble_t > 0.0
				if r.hit("honey"):
					_net_hit(r, "honey")
					FX.burst(r.global_position + Vector3.UP * 0.4, {"amount": 12, "life": 0.7, "spread": 60.0, "vel_min": 1.5, "vel_max": 3.0,
						"gravity": Vector3(0, -8, 0), "size": 0.28, "color": Color(1.0, 0.7, 0.15)})
					Audio.sfx("slime", r.global_position, -4.0)
					if r == focus:
						_message("Klebrig! Honig!", Color("#ffb21e"))
				elif had_bubble:
					_net_hit(r, "block", "honey")
				else:
					continue
				tp.hits = int(tp.hits) + 1
				if int(tp.hits) >= 2:
					_remove_trap(tp)
					if Net.online:
						Net.send({"k": "trap", "t": int(tp.id)}, true)
				break


func _remove_trap(tp: Dictionary) -> void:
	if traps.has(tp):
		traps.erase(tp)
		var n: Node3D = tp.node
		if is_instance_valid(n):
			var tw := n.create_tween()
			tw.tween_property(n, "scale", Vector3(0.05, 1.0, 0.05), 0.3)
			tw.tween_callback(n.queue_free)


## Donnerwolke: zieht über dem Opfer auf, kurzer Blitz. Nur eigene Karts werden getroffen (Opfer-Autorität).
func _thunder_strike(o: Racer, attacker: Racer) -> void:
	var cloud := ItemModels.thunder_cloud(1.4)
	o.add_child(cloud)
	cloud.position = Vector3(0, 7.0, 0)
	cloud.scale = Vector3.ONE * 0.2
	var tw := cloud.create_tween()
	tw.tween_property(cloud, "scale", Vector3.ONE * 1.4, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_callback(func() -> void:
		FX.sparks(o.global_position + Vector3.UP * 1.0, Color(1.0, 0.95, 0.4), 14)
		Audio.sfx("zap", o.global_position, -2.0, 1.0)
		if not o.remote and o.hit("zap"):
			_net_hit(o, "zap")
			if o == focus:
				_message("Bzzzt! Donnerwolke!", Color("#ffe14a"))
				Juice.shake(0.25))
	tw.tween_interval(0.5)
	tw.tween_property(cloud, "scale", Vector3.ONE * 0.05, 0.3)
	tw.tween_callback(cloud.queue_free)
	if attacker == focus:
		_message("Donnerwolke!", Color("#ffe14a"))


## Laufende Item-Optik: kreisender Funkenkern, Kometen-Stern vor dem Kart.
func _update_item_fx(_delta: float) -> void:
	for r in racers:
		var core := r.get_node_or_null("SparkCore") as Node3D
		if r.spark_t > 0.0:
			if core == null:
				core = ItemModels.spark_core(1.1)
				core.name = "SparkCore"
				r.add_child(core)
			var a := race_time * 4.0 + r.idx
			core.position = Vector3(cos(a) * 1.6, 1.7 + sin(a * 2.0) * 0.2, sin(a) * 1.6)
			core.rotation.y = a * 2.0
		elif core:
			core.queue_free()
		var comet := r.get_node_or_null("Comet") as Node3D
		if r.comet_t > 0.0:
			if comet == null:
				comet = ItemModels.comet(1.3)
				comet.name = "Comet"
				r.add_child(comet)
				comet.position = Vector3(0, 1.2, -2.4)
				var trail := FX.make_trail(comet, "flame")
				trail.emitting = true
			comet.rotation.z = race_time * 6.0
		elif comet:
			comet.queue_free()


func _impact(r: Racer, p: Dictionary) -> void:
	var pos := r.global_position
	var owner: Racer = p.owner
	match p.kind:
		"pie":
			Audio.sfx("slime", pos)
			Audio.sfx("hit_soft", pos)
			FX.burst(pos + Vector3.UP, {"amount": 24, "life": 0.8, "spread": 80.0, "vel_min": 4.0, "vel_max": 8.0, "gravity": Vector3(0, -14, 0), "size": 0.6, "color": Color("#fff6e8")})
			if r == focus:
				_pie_splat()
		"candy":
			Audio.sfx("pop", pos, 0.0, 1.2)
			FX.confetti(pos + Vector3.UP * 1.2, 30)
		"homing", "reflect":
			FX.explosion(pos, 1.2)
			if not Net.online:   # Treffer-Stopp hält die eigene Simulation an – online wäre das unfair
				Juice.hitstop(0.08)
			_maybe_closeup(r, owner)
		"anchor":
			Audio.sfx("metal_hit", pos)
			Audio.sfx("whoosh", pos, 0.0, 0.6)
			FX.dust(pos, Color(0.8, 0.75, 0.7), 18, 1.5)
			FX.stars(pos + Vector3.UP * 2.0, Color(0.8, 0.9, 1.0), 12)
			_maybe_closeup(r, owner)
	if r == focus:
		_message({"pie": "Kuchen im Gesicht!", "candy": "Bonbon-Treffer!", "homing": "BUMM!", "reflect": "Zurück zum Absender!", "anchor": "Geankert! −18 m"}.get(p.kind, "Autsch!"), Color("#ff6b6b"))
	elif owner == focus:
		_message("Treffer!", Color("#7dff9a"))
		Audio.voice("correct")


func _maybe_closeup(victim: Racer, attacker: Racer) -> void:
	if _closeup_cd > 0.0 or CutsceneManager.active or not views.is_empty() or Net.online:
		return   # im Split-Screen keine Zeitlupen-Nahaufnahme (jeder braucht seine Ansicht), online auch nicht:
		# Zeitlupe bremst nur die eigene Simulation – man verlöre Strecke und die Gefahren-Uhr liefe hinterher
	if victim != focus and attacker != focus:
		return
	_closeup_cd = 6.0
	CutsceneManager.play("ItemHitCloseup", {"victim": victim, "letterbox": true, "blend_back": 0.22, "skippable": false})


func _update_underwater(delta: float) -> void:
	var target := 1.0 if (track.is_water(focus.s) and cam.global_position.y < -0.6) else 0.0
	_underwater = lerpf(_underwater, target, clampf(delta * 3.0, 0, 1))
	_bubbles.emitting = _underwater > 0.5
	if _underwater > 0.01:
		_env.fog_enabled = true
		_env.fog_light_color = (_env_base.fog_color as Color).lerp(Color(0.04, 0.22, 0.42), _underwater)
		_env.fog_density = lerpf(_env_base.fog_density, 0.022, _underwater)
		_env.glow_intensity = lerpf(0.6, 0.25, _underwater)
		_env.ambient_light_color = (_env_base.ambient as Color).lerp(Color(0.25, 0.45, 0.7), _underwater)
	elif _env.fog_density != _env_base.fog_density:
		_env.fog_enabled = _env_base.fog
		_env.fog_density = _env_base.fog_density
		_env.fog_light_color = _env_base.fog_color
		_env.ambient_light_color = _env_base.ambient


# --- HUD ------------------------------------------------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_hud = UI.hud_root(layer)
	var left := UI.vbox(-6)
	_hud.add_child(left)
	left.position = Vector2(24, 14)
	_pos_label = UI.label("8.", 96, Color.WHITE, true, 16)
	left.add_child(_pos_label)
	_lap_label = UI.label("Runde 1/%d" % laps, 30, Color.WHITE, true, 8)
	left.add_child(_lap_label)
	_time_label = UI.label("0:00.00", 24, Color(1, 1, 1, 0.85), true, 6)
	left.add_child(_time_label)
	_item_panel = UI.panel(Color(0.08, 0.04, 0.2, 0.85), 26)
	_hud.add_child(_item_panel)
	_item_panel.custom_minimum_size = Vector2(124, 124)
	UI.place(_item_panel, Control.PRESET_TOP_RIGHT, Vector2(-150, 18), Vector2(124, 124))
	_item_icon = UIIcon.new("question", 90)
	_item_panel.add_child(_item_icon)
	_item_icon.visible = false
	var bottom := UI.vbox(4)
	_hud.add_child(bottom)
	UI.place(bottom, Control.PRESET_BOTTOM_LEFT, Vector2(24, -96), Vector2(240, 70))
	_speed_label = UI.label("0 km/h", 34, Color.WHITE, true, 8)
	bottom.add_child(_speed_label)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(1, 1, 1, 0.18)
	bar_bg.custom_minimum_size = Vector2(220, 14)
	bottom.add_child(bar_bg)
	_drift_bar = ColorRect.new()
	_drift_bar.size = Vector2(0, 14)
	bar_bg.add_child(_drift_bar)
	_msg = UI.label("", 64, Color.WHITE, true, 14)
	_msg.set_anchors_preset(Control.PRESET_CENTER)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.position = Vector2(-500, -170)
	_msg.size = Vector2(1000, 90)
	_msg.visible = false
	_hud.add_child(_msg)
	_minimap = MiniMap.new()
	(_minimap as MiniMap).race = self
	_hud.add_child(_minimap)
	if Game.is_touch_device:
		UI.place(_minimap, Control.PRESET_TOP_RIGHT, Vector2(-380, 18), Vector2(210, 210))
	else:
		UI.place(_minimap, Control.PRESET_BOTTOM_RIGHT, Vector2(-230, -230), Vector2(210, 210))
	_splat = Control.new()
	_splat.set_anchors_preset(Control.PRESET_FULL_RECT)
	_splat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splat.visible = false
	_splat.draw.connect(_draw_splat)
	_hud.add_child(_splat)


func _update_hud(delta: float) -> void:
	if not is_instance_valid(focus):
		return
	_pos_label.text = "%d." % focus.place
	_pos_label.add_theme_color_override("font_color", UI.GOLD if focus.place == 1 else (Color("#dfe8f0") if focus.place <= 3 else Color.WHITE))
	_lap_label.text = "Runde %d/%d" % [clampi(focus.lap + 1, 1, laps), laps]
	var t := race_time
	_time_label.text = "%d:%05.2f" % [int(t) / 60, fmod(t, 60.0)]
	_speed_label.text = "%d km/h" % int(absf(focus.v) * 3.6)
	var lvl := focus.drift_level
	var frac := 0.0
	if focus.drift_dir != 0:
		frac = clampf(focus.drift_t / Racer.DRIFT_LEVELS[2], 0, 1)
	_drift_bar.size.x = 220.0 * frac
	_drift_bar.color = [Color(1, 1, 1, 0.6), KartVisual.SPARK_COLORS[0], KartVisual.SPARK_COLORS[1], Color.from_hsv(fmod(Time.get_ticks_msec() / 400.0, 1.0), 0.8, 1.0)][lvl]
	if focus.rolling > 0.0:
		_item_icon.visible = true
		_roll_t -= delta
		if int(Time.get_ticks_msec() / 70) % 2 == 0:
			_item_icon.set_kind(ItemModels.icon_of(ItemModels.INFO.keys()[randi() % ItemModels.INFO.size()]))
			Audio.sfx("item_roll", null, -10.0)
	elif focus.item != "":
		_item_icon.visible = true
		_item_icon.set_kind(ItemModels.icon_of(focus.item))
	else:
		_item_icon.visible = false
	_minimap.queue_redraw()


func _on_item_changed(r: Racer) -> void:
	for v in views:
		if v.racer == r and r.item != "":
			v.message(ItemModels.name_of(r.item), Color("#ffe066"), 0.7)
	if r == focus and r.item != "" and not _split_in_main:
		Juice.ui_punch(_item_panel, 0.25, 0.4)
		_message(ItemModels.name_of(r.item), Color("#ffe066"), 0.7)


func _message(text: String, color := Color.WHITE, hold := 1.0) -> void:
	_msg.text = text
	_msg.add_theme_color_override("font_color", color)
	_msg.visible = true
	_msg.modulate.a = 1.0
	_msg.pivot_offset = _msg.size / 2.0
	_msg.scale = Vector2(0.4, 0.4)
	var tw := _msg.create_tween()
	tw.tween_property(_msg, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(_msg, "modulate:a", 0.0, 0.25)


var _splat_t := 0.0
var _splat_blobs: Array = []


func _pie_splat() -> void:
	_splat_blobs.clear()
	var vs := get_viewport().get_visible_rect().size
	for i in 14:
		_splat_blobs.append([Vector2(randf_range(0.2, 0.8) * vs.x, randf_range(0.2, 0.8) * vs.y), randf_range(60, 190)])
	_splat.visible = true
	_splat.modulate.a = 1.0
	var tw := _splat.create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_splat, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func() -> void: _splat.visible = false)
	_splat.queue_redraw()


func _draw_splat() -> void:
	for b in _splat_blobs:
		_splat.draw_circle(b[0] + Vector2(0, 8), b[1], Color(0.85, 0.75, 0.6, 0.6))
		_splat.draw_circle(b[0], b[1], Color(1, 0.97, 0.9, 0.95))
		_splat.draw_circle(b[0] - Vector2(b[1], b[1]) * 0.3, b[1] * 0.25, Color(1, 1, 1, 1))


func _results(order: Array) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var root := UI.center_root(layer)
	var panel := UI.panel()
	root.add_child(panel)
	panel.custom_minimum_size = Vector2(760, 0)
	var v := UI.vbox(6)
	panel.add_child(v)
	var t := UI.label("Rennergebnis – %s" % def.name, 48, UI.GOLD, true, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	for r in order:
		var rr := r as Racer
		var row := UI.hbox(14)
		var pl := UI.label("%d." % rr.place, 32, UI.GOLD if rr.place == 1 else Color.WHITE, true)
		pl.custom_minimum_size.x = 56
		row.add_child(pl)
		var nm := UI.label(rr.display_name + ("" if rr.slot < 0 else "  (P%d)" % (rr.slot + 1)), 28, rr.color.lightened(0.3), true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		var tt := rr.finish_time if rr.finished else race_time
		row.add_child(UI.label(("%d:%05.2f" % [int(tt) / 60, fmod(tt, 60.0)]) if rr.finished else "—", 26, Color.WHITE, true))
		v.add_child(row)
	v.add_child(UI.prompt("a", "Weiter", 26))
	await get_tree().process_frame
	panel.position = (root.size - panel.size) / 2.0
	Juice.pop_in(panel, 0.4)
	var wait := 0.0
	var human := false
	for r in racers:
		if not r.is_cpu:
			human = true
	while wait < (15.0 if human else 3.0):
		await get_tree().process_frame
		wait += get_process_delta_time()
		if wait > 0.6 and InputHub.any_human_pressed("a"):
			break
	var fade := create_tween()
	fade.tween_property(panel, "modulate:a", 0.0, 0.2)
	await fade.finished
	layer.queue_free()


# --- Minimap ----------------------------------------------------------------------------------------------------

class MiniMap extends Control:
	var race: Node

	func _draw() -> void:
		if race == null:
			return
		var tr: RaceTrack = race.track
		var pts: PackedVector2Array = tr.minimap
		if pts.size() < 2:
			return
		var mn := pts[0]
		var mx := pts[0]
		for p in pts:
			mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.y))
			mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.y))
		var span := maxf(mx.x - mn.x, mx.y - mn.y)
		var scl := (size.x - 20.0) / span
		var off := (size - (mx - mn) * scl) / 2.0
		draw_circle(size / 2.0, size.x * 0.52, Color(0.05, 0.02, 0.12, 0.55))
		var poly := PackedVector2Array()
		for p in pts:
			poly.append((p - mn) * scl + off)
		poly.append(poly[0])
		draw_polyline(poly, Color(0, 0, 0, 0.5), 9.0, true)
		draw_polyline(poly, Color(1, 1, 1, 0.9), 5.0, true)
		for r in race.racers:
			var rr := r as Racer
			var p2 := (Vector2(rr.global_position.x, rr.global_position.z) - mn) * scl + off
			var rad := 8.0 if rr == race.focus else 5.5
			draw_circle(p2, rad + 2.0, Color(0, 0, 0, 0.7))
			draw_circle(p2, rad, rr.color)
