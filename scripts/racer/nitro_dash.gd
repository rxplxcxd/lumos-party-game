extends Node3D
## Nitro Dash – Arcade-Racer.
## 8 Karts (4 Spieler-Slots + 4 Zusatz-CPUs), 3 Strecken, Items mit Juice:
##   Kuchendeckel (prallt von Wänden ab) · Homing-Kanonenkugel (verfolgt den Vordermann, lacht fies)
##   Megafon-Schock (Schrumpfen/Drehen in der Umgebung) · Piraten-Anker (20 m zurück) · Nitro

const ITEM_TABLE := {
	1: {"pie": 50, "nitro": 30, "megaphone": 20},
	2: {"pie": 35, "nitro": 25, "megaphone": 20, "anchor": 10, "homing": 10},
	4: {"homing": 25, "anchor": 25, "nitro": 25, "megaphone": 15, "pie": 10},
	7: {"homing": 35, "anchor": 30, "nitro": 30, "megaphone": 5},
}
const ITEM_NAMES := {"pie": "Kuchendeckel", "homing": "Homing-Kanonenkugel", "megaphone": "Megafon-Schock", "anchor": "Piraten-Anker", "nitro": "Nitro"}
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
	_build_world()
	if _rays_sun:
		for k in 4:
			WorldKit.god_rays(self, track.frame(track.length * k / 4.0).origin, 25.0, _rays_sun, 5)
	_build_boxes()
	_spawn_racers()
	_build_camera()
	_build_hud()
	Audio.music("race")
	InputHub.set_touch_profile("none")
	_flow()


# --- Welt -----------------------------------------------------------------------------------------------

func _build_world() -> void:
	var theme: String = def.theme
	match theme:
		"pirates":
			WorldKit.water(self, Vector2(600, 600), -0.6)
			WorldKit.box(self, Vector3(110, 1, 160), Vector3(30, -0.75, 20), Color("#f1d9a0"), false)
		"neon":
			WorldKit.box(self, Vector3(500, 1, 500), Vector3(60, -0.8, 30), Color("#140a24"), false)
			var lava := WorldKit.lava(self, Vector2(70, 90), -0.5, Vector2(0.05, 0.1))
			lava.position = Vector3(110, -0.5, 60)
		_:
			WorldKit.box(self, Vector3(500, 1, 500), Vector3(80, -0.8, 20), Color("#4c9a36"), false)
			var canyon := WorldKit.water(self, Vector2(50, 70), -26.0)
			canyon.position = Vector3(172, -26, 50)
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
		"pirates":
			keys = ["pirate/palm", "pirate/palm_bend", "pirate/palm_detailed", "pirate/rocks_a", "pirate/rocks_b", "pirate/barrel", "pirate/crate", "pirate/flag", "pirate/tower_small"]
			near = ["race/barrier_white", "pirate/barrel", "race/flag_red"]
		"neon":
			keys = ["space/rock_crystals", "space/rock_crystals_b", "space/rocket", "space/satellite", "space/machine", "space/turret", "td/crystal", "space/meteor", "space/hangar"]
			near = ["race/light_colored", "race/pylon", "race/barrier_red"]
		_:
			keys = ["race/tree_large", "race/tree_small", "nat/tree_oak", "nat/tree_default", "race/tent", "race/billboard", "race/banner_tower_red", "race/banner_tower_green", "race/radar", "race/pits"]
			near = ["race/barrier_red", "race/barrier_white", "race/light_post", "race/flag_checkers", "race/pylon"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(def.id)
	var s := 0.0
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
	for i in 4:
		var fr2 := track.frame(track.length - 20.0 + i * 12.0)
		var p2 := fr2.origin - fr2.basis.x * (track.width * 0.5 + 6.0)
		p2.y = 0.0
		var gs := WorldKit.place(self, "race/grandstand_round" if theme != "neon" else "space/hangar", p2, 0.0, 5.0, false)
		gs.look_at(fr2.origin, Vector3.UP)
	# Neon-Lichter
	if theme == "neon":
		var s2 := 0.0
		var colors := [Color(0.2, 0.9, 1.0), Color(1.0, 0.2, 0.8), Color(0.6, 0.3, 1.0)]
		var ci := 0
		while s2 < track.length:
			var fr3 := track.frame(s2)
			var l := OmniLight3D.new()
			l.light_color = colors[ci % 3]
			l.light_energy = 2.2
			l.omni_range = 14.0
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
		for lx in [-5.25, -1.75, 1.75, 5.25]:
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


func _spawn_racers() -> void:
	var entries: Array = []
	for e in EXTRA:
		entries.append({"slot": -1, "model": e.model, "name": e.name, "kart": e.kart, "color": e.color})
	var kart_keys := ["kart/oobi", "kart/oodi", "kart/ooli", "kart/oopi"]
	for i in 4:
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
	focus = racers[4]
	for r in racers:
		if r.slot >= 0 and not r.is_cpu:
			focus = r
			break


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
	InputHub.set_touch_profile("race")
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


func _physics_process(delta: float) -> void:
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
	_rank()
	_closeup_cd = maxf(0.0, _closeup_cd - delta)
	if _finish_wait > 0.0:
		_finish_wait -= delta
		if _finish_wait <= 0.0:
			_end_race()


func _process(delta: float) -> void:
	_update_camera(delta)
	_update_hud(delta)
	_update_underwater(delta)
	for c in get_children():
		if c.has_meta("swim"):
			var n := c as Node3D
			n.position += -n.global_basis.z * delta * 2.0
			n.rotation.y += delta * 0.4


func _rubber_band(r: Racer) -> void:
	if not r.is_cpu:
		r.speed_mult = 1.0
		return
	var base: float = [0.9, 0.97, 1.02][r.cpu_level]
	var gap := focus.progress - r.progress
	var band := 1.0
	if gap > 40.0:
		band = 1.07
	elif gap < -70.0:
		band = 0.93
	r.speed_mult = base * band


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
			if absf(dx) < 2.3:
				var push := (2.3 - absf(dx)) * 0.5 * (1.0 if dx >= 0 else -1.0)
				ra.x -= push
				rb.x += push
				var dv := (ra.v - rb.v) * 0.25
				if ds > 0:
					ra.v -= maxf(dv, 0.0)
					rb.v += maxf(dv, 0.0)
				else:
					rb.v -= maxf(-dv, 0.0)
					ra.v += maxf(-dv, 0.0)
				if absf(push) > 0.25:
					var mid := (ra.global_position + rb.global_position) * 0.5
					Audio.sfx("punch", mid, -8.0)
					FX.sparks(mid + Vector3.UP * 0.5, Color(1, 0.9, 0.5), 6)
					if ra == focus or rb == focus:
						InputHub.rumble(focus.slot, 0.4, 0.1)


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


func _on_lap(r: Racer, lap: int) -> void:
	if lap >= laps and not r.finished:
		r.finished = true
		r.finish_time = race_time
		if not r.is_cpu:
			Audio.sfx("bell")
			Audio.jingle("finish")
			_message("ZIEL! %d. Platz" % r.place, UI.GOLD)
			FX.confetti(r.global_position + Vector3.UP * 3.0, 80)
			r.visual.hero.react("victory")
		var all_humans_done := true
		for o in racers:
			if not o.is_cpu and not o.finished:
				all_humans_done = false
		if (all_humans_done and _finish_wait < 0.0) or (focus.is_cpu and r == focus):
			_finish_wait = 3.5
			state = "finish"
	elif lap == laps - 1 and r == focus:
		Audio.voice("final_round")
		Audio.set_music_pitch(1.08)
		_message("LETZTE RUNDE!", Color("#ff4d6d"))
	elif r == focus and lap > 0 and lap < laps:
		Audio.sfx("bong")
		_message("Runde %d / %d" % [lap + 1, laps], Color.WHITE)


func _end_race() -> void:
	state = "done"
	Audio.set_music_pitch(1.0)
	InputHub.set_touch_profile("none")
	var order := racers.duplicate()
	order.sort_custom(func(a: Racer, b: Racer) -> bool: return a.place < b.place)
	var entries: Array = []
	for r in order:
		entries.append({"model": r.visual.hero.model_key, "name": r.display_name, "color": r.color, "player": r.slot})
	var podium := [entries[0], entries[1], entries[2], entries[entries.size() - 1]]
	await CutsceneManager.play("Podium", {"entries": podium, "skippable": true})
	await _results(order)
	Router.goto("res://scenes/menu/MainMenu.tscn")


# --- Items --------------------------------------------------------------------------------------------------

func _roll_item(place: int) -> String:
	var table: Dictionary = ITEM_TABLE[1]
	for k in [1, 2, 4, 7]:
		if place >= k:
			table = ITEM_TABLE[k]
	var total := 0
	for v in table.values():
		total += int(v)
	var r := randi() % total
	for k2 in table.keys():
		r -= int(table[k2])
		if r < 0:
			return k2
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
				b.respawn = 3.0
				FX.stars(n.global_position, Color(1, 0.8, 1.0), 10)
				Audio.sfx("glass", n.global_position, -6.0 if not r.is_cpu else -14.0)
				if r.item == "" and r.rolling <= 0.0:
					r.item = _roll_item(r.place)
					r.rolling = 1.0
					if r == focus:
						_roll_t = 1.0
				break


func ai_wants_item(r: Racer) -> bool:
	match r.item:
		"nitro":
			return absf(track.curvature(r.s, 15.0)) < 0.01
		"megaphone":
			for o in racers:
				if o != r and o.global_position.distance_to(r.global_position) < 16.0:
					return true
			return false
		"pie":
			for o in racers:
				var ahead := track.wrap_s(o.s - r.s)
				if o != r and ahead > 3.0 and ahead < 40.0 and absf(o.x - r.x) < 3.0:
					return true
			return randf() < 0.15
		"homing", "anchor":
			return r.place > 1
	return false


func use_item(r: Racer, kind: String) -> void:
	var pos := r.global_position
	match kind:
		"nitro":
			r._boost(1.6, false)
			if r == focus:
				Audio.voice("power_up")
		"megaphone":
			Audio.sfx("megaphone", pos)
			Audio.sfx("explosion_big", pos, -6.0, 1.6)
			FX.shockwave(pos, 18.0, Color(1.0, 0.5, 0.8, 0.9))
			if r == focus:
				Juice.shake(0.35)
			for o in racers:
				if o != r and o.global_position.distance_to(pos) < 18.0:
					if o.hit("shrink" if randf() < 0.5 else "spin"):
						_maybe_closeup(o, r)
		"pie":
			_spawn_projectile(r, "pie", maxf(r.v + 22.0, 42.0), sin(r.psi) * 22.0, 0.8)
			Audio.sfx("whoosh", pos)
		"homing":
			var target: Racer = null
			for o in racers:
				if o.place == r.place - 1:
					target = o
			var p := _spawn_projectile(r, "homing", 58.0, 0.0, 1.8)
			p.target = target
			Audio.sfx("evil_laugh", pos)
			Audio.sfx("cannon", pos, -4.0)
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
			var p2 := _spawn_projectile(r, "anchor", 66.0, 0.0, 1.4)
			p2.target = best
			Audio.sfx("metal_hit", pos, -4.0)


func _spawn_projectile(owner: Racer, kind: String, speed: float, vx: float, h: float) -> Dictionary:
	var n := Node3D.new()
	add_child(n)
	match kind:
		"pie":
			var crust := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.9
			cm.bottom_radius = 0.75
			cm.height = 0.35
			cm.material = WorldKit.mat(Color("#c8803a"))
			crust.mesh = cm
			n.add_child(crust)
			var cream := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.8
			sm.height = 0.6
			sm.material = WorldKit.mat(Color("#fff6e8"), 0.4)
			cream.mesh = sm
			cream.position.y = 0.2
			n.add_child(cream)
			var cherry := MeshInstance3D.new()
			var sm2 := SphereMesh.new()
			sm2.radius = 0.18
			sm2.height = 0.36
			sm2.material = WorldKit.mat(Color("#e0203a"), 0.3)
			cherry.mesh = sm2
			cherry.position.y = 0.55
			n.add_child(cherry)
		"homing":
			Assets.spawn("pirate/cannon_ball", n, Vector3.ZERO, 0.0, 1.6)
			var fuse := FX.make_trail(n, "sparks")
			fuse.emitting = true
			fuse.color = Color(1, 0.7, 0.2)
			var reticle := Sprite3D.new()
			reticle.texture = Assets.icon("crosshair")
			reticle.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			reticle.modulate = Color(1, 0.2, 0.2)
			reticle.pixel_size = 0.02
			reticle.visible = false
			n.add_child(reticle)
			n.set_meta("reticle", reticle)
		"anchor":
			var a := Node3D.new()
			n.add_child(a)
			var shaft := MeshInstance3D.new()
			var cm2 := CylinderMesh.new()
			cm2.top_radius = 0.12
			cm2.bottom_radius = 0.12
			cm2.height = 2.0
			cm2.material = WorldKit.mat(Color("#7a8ca8"), 0.3)
			shaft.mesh = cm2
			a.add_child(shaft)
			var hook := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.6
			tm.outer_radius = 0.85
			tm.material = WorldKit.mat(Color("#7a8ca8"), 0.3)
			hook.mesh = tm
			hook.rotation.x = PI / 2.0
			hook.position.y = -0.7
			a.add_child(hook)
	var p := {"node": n, "kind": kind, "s": owner.s + 2.5, "x": owner.x, "h": h, "speed": speed, "vx": vx,
		"life": 7.0 if kind == "pie" else 5.0, "owner": owner, "target": null, "age": 0.0, "bounces": 0}
	projectiles.append(p)
	return p


func _update_projectiles(delta: float) -> void:
	var hw := track.width * 0.5 - 0.8
	for p in projectiles.duplicate():
		p.age = float(p.age) + delta
		p.life = float(p.life) - delta
		var n: Node3D = p.node
		var target: Racer = p.target
		match p.kind:
			"pie":
				p.s = track.wrap_s(float(p.s) + float(p.speed) * delta)
				p.x = float(p.x) + float(p.vx) * delta
				if absf(float(p.x)) > hw:
					p.x = signf(float(p.x)) * hw
					p.vx = -float(p.vx)
					p.bounces = int(p.bounces) + 1
					Audio.sfx("boing", n.global_position, -6.0)
					FX.sparks(n.global_position, Color(1, 1, 0.8), 6)
				n.rotation.y += delta * 10.0
			"homing", "anchor":
				p.s = track.wrap_s(float(p.s) + float(p.speed) * delta)
				if target and is_instance_valid(target):
					p.x = lerpf(float(p.x), target.x, clampf(delta * 4.0, 0, 1))
					p.h = lerpf(float(p.h), target.h + 1.0, clampf(delta * 3.0, 0, 1))
					var reticle: Variant = n.get_meta("reticle") if n.has_meta("reticle") else null
					if reticle:
						var near := track.wrap_s(target.s - float(p.s)) < 30.0
						(reticle as Sprite3D).visible = near
						if near:
							(reticle as Sprite3D).global_position = target.global_position + target.global_basis.y * 2.5
				if p.kind == "homing" and int(p.age * 1.2) != int((float(p.age) - delta) * 1.2):
					Audio.sfx("evil_laugh", n.global_position, -10.0, 1.2)
				if p.kind == "anchor":
					n.rotation.x += delta * 14.0
		var fr := track.frame(float(p.s))
		n.global_transform = Transform3D(fr.basis, fr.origin + fr.basis.x * float(p.x) + fr.basis.y * float(p.h)) * Transform3D(Basis().rotated(Vector3.UP, n.rotation.y), Vector3.ZERO)
		# Treffer
		var done: int = p.life <= 0.0 or (p.kind == "pie" and int(p.bounces) > 6)
		for r in racers:
			if r == p.owner and float(p.age) < 0.6:
				continue
			if p.kind != "pie" and target and r != target:
				continue
			var ds := track.wrap_s(r.s - float(p.s) + track.length * 0.5) - track.length * 0.5
			if absf(ds) < 2.4 and absf(r.x - float(p.x)) < 2.0 and absf(r.h - float(p.h) + 0.8) < 2.4:
				var kind: String = {"pie": "spin", "homing": "blast", "anchor": "anchor"}.get(p.kind, "spin")
				if r.hit(kind):
					_impact(r, p)
				done = true
				break
		if done:
			if p.life <= 0.0:
				FX.smoke(n.global_position, Color(0.8, 0.8, 0.8), 4, 0.5)
			n.queue_free()
			projectiles.erase(p)


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
		"homing":
			FX.explosion(pos, 1.2)
			Juice.hitstop(0.08)
			_maybe_closeup(r, owner)
		"anchor":
			Audio.sfx("metal_hit", pos)
			Audio.sfx("whoosh", pos, 0.0, 0.6)
			FX.dust(pos, Color(0.8, 0.75, 0.7), 18, 1.5)
			FX.stars(pos + Vector3.UP * 2.0, Color(0.8, 0.9, 1.0), 12)
			_maybe_closeup(r, owner)
	if r == focus:
		_message({"pie": "Kuchen im Gesicht!", "homing": "BUMM!", "anchor": "Geankert! −20 m"}.get(p.kind, "Autsch!"), Color("#ff6b6b"))
	elif owner == focus:
		_message("Treffer!", Color("#7dff9a"))
		Audio.voice("correct")


func _maybe_closeup(victim: Racer, attacker: Racer) -> void:
	if _closeup_cd > 0.0 or CutsceneManager.active:
		return
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
	_hud = UI.center_root(layer)
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
	_item_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_item_panel.position = Vector2(-150, 18)
	_item_panel.custom_minimum_size = Vector2(124, 124)
	_item_icon = UIIcon.new("question", 90)
	_item_panel.add_child(_item_icon)
	_item_icon.visible = false
	var bottom := UI.vbox(4)
	_hud.add_child(bottom)
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.position = Vector2(24, -96)
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
	_minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT if not Game.is_touch_device else Control.PRESET_TOP_RIGHT)
	_minimap.position = Vector2(-230, -230) if not Game.is_touch_device else Vector2(-380, 18)
	_minimap.size = Vector2(210, 210)
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
			_item_icon.set_kind(["pie", "cannonball", "megaphone", "anchor", "nitro"][randi() % 5])
			Audio.sfx("item_roll", null, -10.0)
	elif focus.item != "":
		_item_icon.visible = true
		_item_icon.set_kind({"pie": "pie", "homing": "cannonball", "megaphone": "megaphone", "anchor": "anchor", "nitro": "nitro"}[focus.item])
	else:
		_item_icon.visible = false
	_minimap.queue_redraw()


func _on_item_changed(r: Racer) -> void:
	if r == focus and r.item != "":
		Juice.ui_punch(_item_panel, 0.25, 0.4)
		_message(ITEM_NAMES.get(r.item, ""), Color("#ffe066"), 0.7)


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
