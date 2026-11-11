extends MinigameBase
## Rhythmus-Küche: Bis zu vier Köche kochen gemeinsam im Takt ein Fünf-Gänge-Menü. Jeder Gang ist ein
## eigenes kleines Rhythmus-Spiel – Gemüse schnippeln, Teig rühren, Pfannkuchen wenden, Gewürz-Duett und
## Torte verzieren. Noten laufen auf der eigenen Spur in den Kreis: genau im Takt drücken!
## Schaffen alle Köche einen Gang mit mindestens 80 %, gibt es den Team-Bonus. Am Ende vergibt
## Chefkoch Brummbär eine Küchen-Note (S, A, B, C) für das ganze Team.
## Online: Jeder bewertet seine Eingaben selbst (Owner-Modell), die Punkte werden geteilt.

const PERFECT := 0.08
const GOOD := 0.17
const LANE_SPEED := 300.0
const COUNT_IN := 4
const COURSES := [
	{"id": "chop", "name": "Gemüse schnippeln", "bpm": 92.0, "kinds": ["a"], "beats": 20, "half": 0.0,
		"hint": "A im Takt: Schnipp, schnapp!", "melody": [0, 2, 4, 2, 0, 4, 5, 4]},
	{"id": "stir", "name": "Teig rühren", "bpm": 98.0, "kinds": ["left", "right"], "beats": 20, "half": 0.0,
		"hint": "Stick links/rechts im Takt – rühren!", "melody": [4, 2, 0, 2, 4, 4, 4, 2]},
	{"id": "flip", "name": "Pfannkuchen wenden", "bpm": 104.0, "kinds": ["a", "a", "up"], "beats": 22, "half": 0.15,
		"hint": "A = brutzeln, Stick hoch = WENDEN!", "melody": [0, 4, 7, 4, 5, 4, 2, 0]},
	{"id": "spice", "name": "Gewürz-Duett", "bpm": 108.0, "kinds": ["a", "b"], "beats": 24, "half": 0.0,
		"hint": "Brummbär spielt vor – ihr spielt nach!", "melody": [7, 5, 4, 2, 4, 5, 7, 9]},
	{"id": "deco", "name": "Torte verzieren", "bpm": 116.0, "kinds": ["up", "down", "left", "right", "a"], "beats": 26, "half": 0.25,
		"hint": "Pfeile im Takt: Sahne-Tupfer!", "melody": [0, 4, 7, 9, 7, 4, 5, 7]},
]
## Jeder Gang läuft auf einem eigenen Soundtrack (Track 1–4 normal, Finale auf Track 1 im Hurry-Up-Tempo);
## das Notenblatt folgt exakt dessen BPM.
const COURSE_MUSIC := [[0, "normal"], [1, "normal"], [2, "normal"], [3, "normal"], [0, "hurry"]]
const SCALE := [1.0, 1.122, 1.26, 1.335, 1.498, 1.682, 1.888, 2.0, 2.245, 2.52]
const DISH_NAMES := ["Knackiger Gartensalat", "Fluffiger Teig", "Pfannkuchen-Turm", "Würzige Kürbissuppe", "Sahne-Erdbeer-Torte"]

var notes: Array[Dictionary] = []          # {t, kind, course, demo}
var song_t := -1.0
var course_idx := -1
var course_bounds: Array[Vector2] = []     # [start, end] in Sekunden je Gang
var _judged: Array[Dictionary] = [{}, {}, {}, {}]
var _hits: Array[Array] = [[], [], [], []]  # je Gang: [perfekt, gut, verpasst]
var combo: Array[int] = [0, 0, 0, 0]
var _prev_mag: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _lanes: Array[Control] = []
var _course_label: Label
var _hint_label: Label
var _grade_label: Label
var _eighth := -999
var _beat_len := 0.6
var _stations: Array[Node3D] = []
var _props: Array[Dictionary] = []
var _chef: CharacterRig
var _dishes: Array[Node3D] = []
var _bonus := 0
var _ended := false
var _cpu_plan: Array[Dictionary] = [{}, {}, {}, {}]


func _init() -> void:
	game_id = "rhythm_kitchen"
	music_track = -2   # Musik wird je Gang selbst gesteuert
	touch_profile = "dance"
	env_preset = "day"
	time_limit = 300.0
	show_timer = false
	arena_radius = 8.0
	teaser_height = 1.2
	cannon_pos = Vector3(0, 0, 11)
	score_format = "%d Pkt."
	spawn_points = [Vector3(-4.5, 0.6, 1.6), Vector3(-1.5, 0.6, 1.6), Vector3(1.5, 0.6, 1.6), Vector3(4.5, 0.6, 1.6)]


func on_setup() -> void:
	category = "coop"
	for i in 4:
		teams[i] = 0
	_build_chart()


# --- Notenblatt ---------------------------------------------------------------------------------------------

func _build_chart() -> void:
	var t := 2.0
	for c in COURSES.size():
		var cd: Dictionary = COURSES[c]
		var bl := 60.0 / _course_bpm(c)
		var start := t
		t += COUNT_IN * bl
		var kinds: Array = cd.kinds
		var beats: int = cd.beats
		if cd.id == "spice":
			# Ruf und Antwort: 2 Takte vorspielen (Demo), 2 Takte nachspielen
			var b := 0
			while b < beats:
				var pattern: Array[String] = []
				for k in 4:
					pattern.append(String(kinds[rng.randi() % kinds.size()]))
				for k in 4:
					notes.append({"t": t + (b + k) * bl, "kind": pattern[k], "course": c, "demo": true})
				for k in 4:
					notes.append({"t": t + (b + 4 + k) * bl, "kind": pattern[k], "course": c, "demo": false})
				b += 8
		else:
			for b in beats:
				if cd.id == "chop" and b % 8 == 7:
					continue   # kleine Atempause
				var kind := String(kinds[rng.randi() % kinds.size()])
				if cd.id == "stir":
					kind = "left" if b % 2 == 0 else "right"
				notes.append({"t": t + b * bl, "kind": kind, "course": c, "demo": false})
				if float(cd.half) > 0.0 and b % 4 == 1 and rng.randf() < float(cd.half) * 3.0:
					notes.append({"t": t + (b + 0.5) * bl, "kind": String(kinds[rng.randi() % kinds.size()]), "course": c, "demo": false})
		t += beats * bl + 2.0 * bl
		course_bounds.append(Vector2(start, t))
		t += 2.6   # Gericht präsentieren
	for i in 4:
		_hits[i] = []
		for c in COURSES.size():
			_hits[i].append([0, 0, 0])


func _playable_count(c: int) -> int:
	var n := 0
	for nt in notes:
		if int(nt.course) == c and not bool(nt.demo):
			n += 1
	return n


# --- Küche ---------------------------------------------------------------------------------------------------

func build_arena() -> void:
	# Holzboden mit Fliesen-Läufer, cremige Wände, großes Sonnenfenster
	WorldKit.box(world, Vector3(22, 1, 14), Vector3(0, -0.5, -1), Color("#d9b48a"))
	for x in 11:
		for z in 2:
			var tile := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(1.9, 0.04, 1.9)
			tile.mesh = bm
			tile.material_override = WorldKit.mat(Color("#fff3e0") if (x + z) % 2 == 0 else Color("#f6b8a8"), 0.8)
			world.add_child(tile)
			tile.position = Vector3(-10 + x * 2.0, 0.02, 3.4 + z * 2.0)
	WorldKit.box(world, Vector3(22, 9, 0.6), Vector3(0, 4.5, -7.5), Color("#fff1d8"), false)
	WorldKit.box(world, Vector3(0.6, 9, 14), Vector3(-11, 4.5, -1), Color("#ffe6c4"), false)
	WorldKit.box(world, Vector3(0.6, 9, 14), Vector3(11, 4.5, -1), Color("#ffe6c4"), false)
	var win := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(6, 3.4, 0.1)
	win.mesh = wm
	win.material_override = WorldKit.mat(Color("#bfe6ff"), 0.2, 0.6)
	win.position = Vector3(0, 5.2, -7.15)
	world.add_child(win)
	for xx in [-3.1, 0.0, 3.1]:
		WorldKit.box(world, Vector3(0.2, 3.6, 0.2), Vector3(xx, 5.2, -7.05), Color("#ffffff"), false)
	WorldKit.box(world, Vector3(6.4, 0.2, 0.2), Vector3(0, 5.2, -7.05), Color("#ffffff"), false)
	# Regale mit Gläsern und Töpfen
	for side in [-1.0, 1.0]:
		for row in 2:
			WorldKit.box(world, Vector3(5, 0.18, 1.0), Vector3(side * 7.0, 3.6 + row * 1.6, -6.7), Color("#c98d5a"), false)
			for k in 4:
				var jar := WorldKit.cylinder(world, 0.28, 0.7, Vector3(side * 7.0 - 1.8 + k * 1.2, 4.05 + row * 1.6, -6.7), [Color("#ffb3c7"), Color("#a8dcff"), Color("#ffe08a"), Color("#b6f29a")][(k + row) % 4], false)
				jar.name = "Jar"
	# Herd mit Kupfertöpfen hinten
	WorldKit.box(world, Vector3(8, 1.8, 1.6), Vector3(0, 0.9, -6.2), Color("#f2ead8"), false)
	for k in 3:
		WorldKit.cylinder(world, 0.6, 0.8, Vector3(-2.4 + k * 2.4, 2.2, -6.2), Color("#d98c4a"), false)
	var steam := FX.emitter({"amount": 26, "life": 2.2, "one_shot": false, "explosive": 0.0, "spread": 18.0, "vel_min": 0.4, "vel_max": 0.9,
		"gravity": Vector3(0, 0.25, 0), "size": 0.5, "color": Color(1, 1, 1, 0.35), "box": Vector3(5, 0.2, 0.4)})
	world.add_child(steam)
	steam.position = Vector3(0, 2.7, -6.2)
	steam.emitting = true
	# Lange Arbeitstheke mit vier Stationen
	WorldKit.box(world, Vector3(16, 1.1, 1.6), Vector3(0, 0.55, -0.2), Color("#b07a4a"))
	WorldKit.box(world, Vector3(16.4, 0.14, 1.9), Vector3(0, 1.17, -0.2), Color("#f4ead2"), false)
	for i in 4:
		var st := Node3D.new()
		world.add_child(st)
		st.position = Vector3(spawn_points[i].x, 1.25, -0.25)
		_stations.append(st)
		var board := WorldKit.box(st, Vector3(1.6, 0.08, 0.9), Vector3(0, 0.02, 0), Color("#e8c79a"), false)
		board.name = "Board"
		var veg := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.28
		sm.height = 0.5
		sm.material = WorldKit.mat([Color("#ff6b6b"), Color("#ff9f43"), Color("#7ed957"), Color("#ffd23f")][i], 0.5)
		veg.mesh = sm
		veg.position = Vector3(-0.3, 0.3, 0)
		st.add_child(veg)
		var knife := WorldKit.box(st, Vector3(0.08, 0.06, 0.7), Vector3(0.35, 0.5, 0), Color("#dfe6ee"), false)
		var bowl := WorldKit.cylinder(st, 0.45, 0.35, Vector3(0, 0.18, 0), Color("#a8dcff"), false)
		bowl.visible = false
		var spoon := WorldKit.box(st, Vector3(0.08, 0.8, 0.08), Vector3(0, 0.6, 0), Color("#c98d5a"), false)
		spoon.visible = false
		var pan := WorldKit.cylinder(st, 0.5, 0.08, Vector3(0, 0.06, 0), Color("#4a4a55"), false)
		pan.visible = false
		var cake := WorldKit.cylinder(st, 0.55, 0.45, Vector3(0, 0.22, 0), Color("#fff3d6"), false)
		cake.visible = false
		var cmat := MeshInstance3D.new()
		var pcm := CylinderMesh.new()
		pcm.top_radius = 0.42
		pcm.bottom_radius = 0.42
		pcm.height = 0.08
		pcm.material = WorldKit.mat(Color("#f2c27a"), 0.7)
		cmat.mesh = pcm
		cmat.position = Vector3(0, 0.16, 0)
		cmat.visible = false
		st.add_child(cmat)
		var shaker := WorldKit.cylinder(st, 0.14, 0.4, Vector3(0.3, 0.25, 0), Color("#ff8fa3"), false)
		shaker.visible = false
		_props.append({"veg": veg, "knife": knife, "bowl": bowl, "spoon": spoon, "pan": pan, "pancake": cmat, "cake": cake, "shaker": shaker})
	# Chefkoch Brummbär mit Kochmütze
	_chef = CharacterRig.new()
	world.add_child(_chef)
	_chef.setup("npc/bear", -1, 1.5)
	_chef.position = Vector3(0, 0, -3.6)
	_chef.face_now(Vector3(0, 0, 1))
	_chef.play("idle")
	var hat := WorldKit.cylinder(_chef, 0.32, 0.5, Vector3(0, 2.25, 0), Color.WHITE, false)
	hat.name = "ChefHat"
	var puff := MeshInstance3D.new()
	var ps := SphereMesh.new()
	ps.radius = 0.45
	ps.height = 0.6
	ps.material = WorldKit.mat(Color.WHITE, 0.9)
	puff.mesh = ps
	puff.position = Vector3(0, 2.6, 0)
	_chef.add_child(puff)
	for p in [Vector3(-8, 0, 1), Vector3(8, 0, 1)]:
		WorldKit.place(world, "plat/flowers", p, 0.0, 1.6)
	var sun := OmniLight3D.new()
	sun.light_color = Color(1.0, 0.9, 0.7)
	sun.light_energy = 1.4
	sun.omni_range = 16.0
	sun.position = Vector3(0, 6, -3)
	world.add_child(sun)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0.1, -0.6)
	c.offset = Vector3(0, 6.2, 9.4)
	c.min_dist = 1.0
	c.max_dist = 1.0
	c.follow = false


# --- HUD --------------------------------------------------------------------------------------------------------

class KitchenLane extends Control:
	const SPEED := 300.0
	var game: Node
	var slot := 0
	var flash := 0.0
	var flash_col := Color.WHITE
	var _font: Font

	func _ready() -> void:
		_font = UI.title_font()
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		flash = maxf(0.0, flash - delta * 3.0)
		queue_redraw()

	func _draw() -> void:
		var h := size.y
		var col := Game.player_color(slot)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.18, 0.1, 0.06, 0.55), true)
		draw_rect(Rect2(Vector2(0, h - 4), Vector2(size.x, 4)), col.darkened(0.2), true)
		var hx := 70.0
		draw_circle(Vector2(hx, h * 0.5), h * 0.42, Color(1, 1, 1, 0.16 + flash * 0.5).lerp(flash_col, flash * 0.6))
		draw_arc(Vector2(hx, h * 0.5), h * 0.42, 0.0, TAU, 32, Color(1, 1, 1, 0.9), 3.0, true)
		var st: float = game.song_t
		var judged: Dictionary = game._judged[slot]
		for i in (game.notes as Array).size():
			var nt: Dictionary = game.notes[i]
			var dt := float(nt.t) - st
			if dt < -0.25 or dt > 3.4:
				continue
			if judged.has(i) and not bool(nt.demo):
				continue
			var x := hx + dt * SPEED
			if x > size.x - 10.0:
				continue
			_draw_note(Vector2(x, h * 0.5), String(nt.kind), h * 0.34, bool(nt.demo))
		var name_t := String(Game.hero(Game.players[slot].hero).name).get_slice(" ", 0)
		draw_string(_font, Vector2(size.x - 8 - _font.get_string_size(name_t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x, 22), name_t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col.lightened(0.4))
		var cb: int = game.combo[slot]
		if cb >= 3:
			var ct := "%d×" % cb
			draw_string(_font, Vector2(size.x - 8 - _font.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x, h - 10), ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UI.GOLD)

	func _draw_note(c: Vector2, kind: String, r: float, demo: bool) -> void:
		var base := {"a": Color("#2ecc71"), "b": Color("#ff5c7a"), "up": Color("#ffd23f"), "down": Color("#7fd6ff"), "left": Color("#ff9f43"), "right": Color("#c79bff")}.get(kind, Color.WHITE) as Color
		if demo:
			base = base.lerp(Color(1, 1, 1), 0.5)
			base.a = 0.55
		draw_circle(c, r, base)
		draw_arc(c, r, 0.0, TAU, 24, Color(1, 1, 1, 0.9 if not demo else 0.5), 2.5, true)
		if kind in ["a", "b"]:
			var t := kind.to_upper()
			var sz := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 1.3))
			draw_string(_font, c + Vector2(-sz.x * 0.5, sz.y * 0.32), t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 1.3), Color(0.12, 0.06, 0.02))
		else:
			var d: Vector2 = {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}[kind]
			var p := Vector2(-d.y, d.x)
			var tip := c + d * r * 0.62
			draw_colored_polygon(PackedVector2Array([tip, c - d * r * 0.2 + p * r * 0.55, c - d * r * 0.2 - p * r * 0.55]), Color(0.12, 0.06, 0.02))
			draw_line(c - d * r * 0.55, c, Color(0.12, 0.06, 0.02), r * 0.3)


func on_start() -> void:
	for i in 4:
		var av := avatars[i] as PartyAvatar
		av.can_move = false
		av.can_jump = false
		av.can_shove = false
		av.set_physics_process(false)
		av.rig.face_now(Vector3(0, 0, -1))
	var root := UI.center_root(hud)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	root.add_child(box)
	var n_act := active_slots().size()
	var lane_h := 58.0 if n_act <= 2 else 46.0
	UI.place(box, Control.PRESET_CENTER_BOTTOM, Vector2(-390, -(lane_h + 6) * n_act - 14), Vector2(780, (lane_h + 6) * n_act))
	for i in active_slots():
		var ln := KitchenLane.new()
		ln.game = self
		ln.slot = i
		ln.custom_minimum_size = Vector2(780, lane_h)
		box.add_child(ln)
		_lanes.append(ln)
	_course_label = UI.label("", 40, UI.GOLD, true, 10)
	_course_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_course_label)
	UI.place(_course_label, Control.PRESET_CENTER_TOP, Vector2(-400, 90), Vector2(800, 56))
	_hint_label = UI.label("", 24, Color.WHITE, true, 8)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_hint_label)
	UI.place(_hint_label, Control.PRESET_CENTER_TOP, Vector2(-400, 144), Vector2(800, 36))
	_grade_label = UI.label("", 26, Color("#7dff9a"), true, 8)
	_grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_grade_label)
	UI.place(_grade_label, Control.PRESET_CENTER_TOP, Vector2(-400, 180), Vector2(800, 36))
	song_t = 0.0
	Audio.music("", 0.6)


func _lane_of(slot: int) -> KitchenLane:
	for l in _lanes:
		if (l as KitchenLane).slot == slot:
			return l as KitchenLane
	return null


# --- Ablauf ------------------------------------------------------------------------------------------------------

func on_tick(delta: float) -> void:
	if _ended:
		return
	song_t += delta
	var c := -1
	for k in course_bounds.size():
		if song_t >= course_bounds[k].x and song_t < course_bounds[k].y + 2.6:
			c = k
	if c != course_idx and c >= 0:
		_start_course(c)
	_music_tick()
	for i in active_slots():
		if not Net.owns_slot(i):
			continue
		_read_input(i)
		_check_misses(i)
	_check_course_end()
	if song_t > course_bounds[course_bounds.size() - 1].y + 2.8:
		_ended = true
		_finish_menu()


var _course_done: Array[bool] = [false, false, false, false, false]


func _course_bpm(c: int) -> float:
	var cm: Array = COURSE_MUSIC[clampi(c, 0, COURSE_MUSIC.size() - 1)]
	return Audio.track_bpm(int(cm[0]), String(cm[1]))


func _start_course(c: int) -> void:
	course_idx = c
	var cd: Dictionary = COURSES[c]
	_beat_len = 60.0 / _course_bpm(c)
	var cm: Array = COURSE_MUSIC[c]
	Audio.minigame_music(int(cm[0]), 0.25, String(cm[1]), song_t - course_bounds[c].x)
	_course_label.text = "Gang %d: %s" % [c + 1, String(cd.name)]
	_hint_label.text = String(cd.hint)
	_grade_label.text = ""
	Juice.ui_punch(_course_label, 0.25, 0.4)
	Audio.sfx("bell", null, -2.0, 1.2)
	_chef.react("cheer")
	for i in 4:
		var pr: Dictionary = _props[i]
		pr.veg.visible = cd.id == "chop"
		pr.knife.visible = cd.id == "chop"
		pr.bowl.visible = cd.id == "stir"
		pr.spoon.visible = cd.id == "stir"
		pr.pan.visible = cd.id == "flip"
		pr.pancake.visible = cd.id == "flip"
		pr.shaker.visible = cd.id == "spice"
		pr.cake.visible = cd.id == "deco"
		if cd.id == "spice":
			pr.bowl.visible = true


func _check_course_end() -> void:
	if course_idx < 0 or _course_done[course_idx]:
		return
	if song_t < course_bounds[course_idx].y:
		return
	_course_done[course_idx] = true
	var total := _playable_count(course_idx)
	var all_good := true
	var sum := 0.0
	for i in active_slots():
		var h: Array = _hits[i][course_idx]
		var ratio := (float(h[0]) + float(h[1]) * 0.6) / float(maxi(1, total))
		sum += ratio
		if ratio < 0.8:
			all_good = false
	var avg := sum / float(maxi(1, active_slots().size()))
	_course_label.text = DISH_NAMES[course_idx] + "!"
	_hint_label.text = "Gang geschafft: %d %%" % int(round(avg * 100.0))
	if all_good:
		_bonus += 1
		_grade_label.text = "Team-Bonus! Alle über 80 %"
		for i in active_slots():
			scores[i] += 10.0
		Audio.jingle("lucky")
	else:
		Audio.sfx("powerup")
	_present_dish(course_idx)
	for i in active_slots():
		(avatars[i] as PartyAvatar).rig.react("cheer" if avg > 0.6 else "sad")


func _present_dish(c: int) -> void:
	var d := Node3D.new()
	world.add_child(d)
	d.position = Vector3(-4.0 + c * 2.0, 1.25, -1.0 + 0.0)
	var plate := WorldKit.cylinder(d, 0.6, 0.06, Vector3(0, 0.03, 0), Color.WHITE, false)
	plate.name = "Plate"
	match c:
		0:
			for k in 6:
				var leaf := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.22
				sm.height = 0.3
				sm.material = WorldKit.mat([Color("#7ed957"), Color("#ff6b6b"), Color("#ffd23f")][k % 3], 0.6)
				leaf.mesh = sm
				leaf.position = Vector3(cos(k * 1.1) * 0.25, 0.16, sin(k * 1.1) * 0.25)
				d.add_child(leaf)
		1:
			WorldKit.cylinder(d, 0.45, 0.35, Vector3(0, 0.2, 0), Color("#fff3d6"), false)
		2:
			for k in 4:
				WorldKit.cylinder(d, 0.42, 0.08, Vector3(0, 0.1 + k * 0.09, 0), Color("#f2c27a"), false)
			WorldKit.cylinder(d, 0.2, 0.06, Vector3(0, 0.5, 0), Color("#ffe08a"), false)
		3:
			WorldKit.cylinder(d, 0.48, 0.3, Vector3(0, 0.17, 0), Color("#ff9f43"), false)
		4:
			WorldKit.cylinder(d, 0.5, 0.5, Vector3(0, 0.27, 0), Color("#ffb3c7"), false)
			var berry := MeshInstance3D.new()
			var bs := SphereMesh.new()
			bs.radius = 0.14
			bs.height = 0.28
			bs.material = WorldKit.mat(Color("#e8304a"), 0.3)
			berry.mesh = bs
			berry.position = Vector3(0, 0.6, 0)
			d.add_child(berry)
	Juice.pop_in(d, 0.5)
	FX.stars(d.global_position + Vector3.UP * 0.6, Color(1, 0.9, 0.4), 16)
	FX.confetti(d.global_position + Vector3.UP * 1.0, 30)
	_dishes.append(d)


## Musik aus Klängen: Bass/Trommel auf den Schlägen, Hi-Hat auf Achteln, Melodie aus der Gang-Tonleiter.
func _music_tick() -> void:
	if course_idx < 0:
		return
	var cb := course_bounds[course_idx]
	var rel := song_t - cb.x
	if rel < 0.0 or song_t > cb.y:
		return
	var e := int(floor(rel / (_beat_len * 0.5)))
	if e == _eighth:
		return
	_eighth = e
	var beat := e / 2
	var on_beat := e % 2 == 0
	var cd: Dictionary = COURSES[course_idx]
	if beat < COUNT_IN:
		if on_beat:
			Audio.sfx("tick", null, -2.0, 1.4 if beat == COUNT_IN - 1 else 1.0, 0.0)
			CutsceneManager.big_word(str(COUNT_IN - beat) if beat < COUNT_IN - 1 else "Los!", UI.GOLD if beat == COUNT_IN - 1 else Color.WHITE, 0.25)
		return
	# Der Soundtrack trägt den Takt – Chefkoch Brummbär wippt mit, auf jedem Taktanfang ein Marimba-Akzent
	if on_beat:
		_chef.hop(0.12, 0.12)
		if beat % 4 == 0 and cd.id == "spice":
			Audio.sfx("marimba", null, -14.0, 1.0, 0.0)


# --- Eingabe & Bewertung -----------------------------------------------------------------------------------------

func _read_input(i: int) -> void:
	var kind := ""
	if Game.players[i].cpu:
		kind = _cpu_input(i)
	else:
		if InputHub.pressed(i, "a"):
			kind = "a"
		elif InputHub.pressed(i, "b"):
			kind = "b"
		var mv := InputHub.move(i)
		var mag := mv.length()
		if mag > 0.6 and _prev_mag[i] <= 0.6:
			if absf(mv.x) > absf(mv.y):
				kind = "right" if mv.x > 0.0 else "left"
			else:
				kind = "down" if mv.y > 0.0 else "up"
		_prev_mag[i] = mag
	if kind != "":
		_judge(i, kind)


func _judge(i: int, kind: String) -> void:
	var best := -1
	var best_d := 1e9
	for k in notes.size():
		var nt: Dictionary = notes[k]
		if bool(nt.demo) or _judged[i].has(k):
			continue
		var d := absf(float(nt.t) - song_t)
		if d < best_d:
			best_d = d
			best = k
	if best < 0 or best_d > GOOD * 1.6:
		return   # weit weg von jeder Note: ignorieren (kein Strafpunkt)
	var nt2: Dictionary = notes[best]
	var c := int(nt2.course)
	var ln := _lane_of(i)
	if best_d <= GOOD and String(nt2.kind) == kind:
		var perfect := best_d <= PERFECT
		_judged[i][best] = 2 if perfect else 1
		combo[i] += 1
		scores[i] += (3.0 if perfect else 1.0) * (1.0 + minf(combo[i], 30) / 30.0)
		(_hits[i][c] as Array)[0 if perfect else 1] = int((_hits[i][c] as Array)[0 if perfect else 1]) + 1
		if ln:
			ln.flash = 1.0
			ln.flash_col = UI.GOLD if perfect else Color("#7dff9a")
		_action(i, kind, perfect)
	else:
		_judged[i][best] = 0
		combo[i] = 0
		(_hits[i][c] as Array)[2] = int((_hits[i][c] as Array)[2]) + 1
		if ln:
			ln.flash = 0.7
			ln.flash_col = Color("#ff6b6b")
		Audio.sfx("hit_soft", null, -10.0, 0.8)
		(avatars[i] as PartyAvatar).rig.squash(1.1, 0.9, 0.15)
	report_score(i)


func _check_misses(i: int) -> void:
	for k in notes.size():
		var nt: Dictionary = notes[k]
		if bool(nt.demo) or _judged[i].has(k):
			continue
		if song_t - float(nt.t) > GOOD:
			_judged[i][k] = 0
			combo[i] = 0
			var c := int(nt.course)
			(_hits[i][c] as Array)[2] = int((_hits[i][c] as Array)[2]) + 1


## Sichtbare Kochaktion an der Station des Spielers.
func _action(i: int, kind: String, perfect: bool) -> void:
	var pr: Dictionary = _props[i]
	var st := _stations[i]
	var av := avatars[i] as PartyAvatar
	av.rig.hop(0.18, 0.14)
	if perfect:
		FX.stars(st.global_position + Vector3.UP * 0.6, Color(1, 0.9, 0.4), 4)
	match COURSES[course_idx].id:
		"chop":
			var kn: Node3D = pr.knife
			var tw := kn.create_tween()
			tw.tween_property(kn, "position:y", 0.12, 0.05)
			tw.tween_property(kn, "position:y", 0.5, 0.12)
			Audio.sfx("wood_hit", st.global_position, -4.0, 1.3)
			Juice.squash(pr.veg, 1.2, 0.8, 0.15, Vector3.ONE)
			FX.dust(st.global_position + Vector3(-0.2, 0.3, 0), [Color("#ff6b6b"), Color("#ff9f43"), Color("#7ed957"), Color("#ffd23f")][i], 4, 0.4)
		"stir":
			var sp: Node3D = pr.spoon
			sp.create_tween().tween_property(sp, "rotation:z", 0.5 if kind == "right" else -0.5, 0.1)
			Audio.sfx("slime", st.global_position, -8.0, 1.4)
		"flip":
			var pc: Node3D = pr.pancake
			if kind == "up":
				var tw2 := pc.create_tween()
				tw2.tween_property(pc, "position:y", 1.3, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw2.parallel().tween_property(pc, "rotation:x", pc.rotation.x + PI, 0.34)
				tw2.tween_property(pc, "position:y", 0.16, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				Audio.sfx("whoosh", st.global_position, -6.0, 1.3)
			else:
				Audio.sfx("drift", st.global_position, -14.0, 1.8)
				FX.smoke(st.global_position + Vector3.UP * 0.3, Color(1, 1, 1, 0.6), 3, 0.4)
		"spice":
			var sh: Node3D = pr.shaker
			Juice.squash(sh, 1.3, 0.75, 0.15, Vector3.ONE)
			Audio.sfx("glass" if kind == "a" else "pluck", st.global_position, -6.0, 1.5 if kind == "a" else 1.0)
			FX.dust(st.global_position + Vector3(0.3, 0.5, 0), Color("#ffb070") if kind == "a" else Color("#9be37a"), 5, 0.4)
		"deco":
			var cake: Node3D = pr.cake
			var dollop := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.1
			sm.height = 0.16
			sm.material = WorldKit.mat([Color.WHITE, Color("#ffb3c7"), Color("#a8dcff"), Color("#ffe08a")][randi() % 4], 0.8)
			dollop.mesh = sm
			var d: Vector2 = {"up": Vector2(0, -1), "down": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0), "a": Vector2.ZERO}.get(kind, Vector2.ZERO)
			dollop.position = Vector3(d.x * 0.32 + randf_range(-0.08, 0.08), 0.3, d.y * 0.32 + randf_range(-0.08, 0.08))
			cake.add_child(dollop)
			Juice.pop_in(dollop, 0.2)
			Audio.sfx("pop", st.global_position, -6.0, 1.2)


func _cpu_input(i: int) -> String:
	var plan := _cpu_plan[i]
	var level: int = Game.players[i].cpu_level
	for k in notes.size():
		var nt: Dictionary = notes[k]
		if bool(nt.demo) or _judged[i].has(k):
			continue
		var dt := float(nt.t) - song_t
		if dt > 0.3:
			break
		if not plan.has(k):
			var skill: float = Game.lv([0.72, 0.86, 0.96], level, true)
			plan[k] = randf_range(-0.05, 0.05) if randf() < skill else 9.0
		if float(plan[k]) < 9.0 and dt <= float(plan[k]):
			return String(nt.kind)
	return ""


func on_remote_score(slot: int, _extra: Dictionary) -> void:
	var ln := _lane_of(slot)
	if ln:
		ln.flash = 0.6
		ln.flash_col = Color("#7dff9a")


# --- Abschluss ----------------------------------------------------------------------------------------------------

func _total_ratio() -> float:
	var maxp := 0.0
	for c in COURSES.size():
		maxp += _playable_count(c) * 3.0 * 1.6
	var sum := 0.0
	var n := 0
	for i in active_slots():
		sum += scores[i]
		n += 1
	return clampf(sum / maxf(1.0, maxp * n), 0.0, 1.0)


func grade() -> String:
	var r := _total_ratio()
	if r >= 0.82:
		return "S"
	if r >= 0.66:
		return "A"
	if r >= 0.48:
		return "B"
	return "C"


func _finish_menu() -> void:
	Audio.minigame_outro()
	_course_label.text = "Das Menü ist fertig!"
	_hint_label.text = ""
	_grade_label.text = ""
	_chef.react("victory")
	end_game()


func team_result() -> int:
	return 0 if grade() in ["S", "A", "B"] else -1


func compute_placements() -> Array[int]:
	var places: Array[int] = [0, 0, 0, 0]
	var win := team_result() == 0
	for i in active_slots():
		places[i] = 1 if win else 2
	return places


func _show_results(placements: Array[int]) -> void:
	state = "results"
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var root := UI.center_root(layer)
	var panel := UI.panel()
	root.add_child(panel)
	panel.custom_minimum_size = Vector2(720, 0)
	var v := UI.vbox(10)
	panel.add_child(v)
	var t := UI.label("Brummbärs Urteil", 44, UI.GOLD, true, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var g := grade()
	var gl := UI.label(g, 150, {"S": UI.GOLD, "A": Color("#7dff9a"), "B": Color("#7fd6ff"), "C": Color("#ff9db0")}[g], true, 18)
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(gl)
	var words := {"S": "Sterne-Küche! Einfach himmlisch!", "A": "Köstlich! Ein echtes Festmahl.", "B": "Lecker! Da geht noch mehr.", "C": "Ähm … essbar. Nochmal üben!"}
	var wl := UI.label(String(words[g]), 30, Color.WHITE, true, 8)
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(wl)
	var bl := UI.label("Team-Bonus: %d von 5 Gängen · Gesamt %d %%" % [_bonus, int(round(_total_ratio() * 100.0))], 24, Color(1, 1, 1, 0.85), true, 6)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(bl)
	for i in active_slots():
		var row := UI.hbox(14)
		var nm := UI.label(Game.hero(Game.players[i].hero).name, 28, Game.player_color(i).lightened(0.3), true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		row.add_child(UI.label("%d Pkt." % int(scores[i]), 28, Color.WHITE, true))
		v.add_child(row)
	var go := UI.prompt("a", "Weiter", 28)
	v.add_child(go)
	await get_tree().process_frame
	panel.position = (root.size - panel.size) / 2.0
	Juice.pop_in(panel, 0.45)
	Juice.ui_punch(gl, 0.4, 0.6)
	Audio.jingle("win" if placements.has(1) else "lose")
	if g == "S":
		FX.confetti(Vector3(0, 3, 0), 120)
	var has_human := false
	for i in 4:
		if not Game.players[i].cpu:
			has_human = true
	var wait := 0.0
	while wait < (14.0 if has_human else 3.5):
		await get_tree().process_frame
		wait += get_process_delta_time()
		if wait > 0.8 and InputHub.any_human_pressed("a"):
			break
	Audio.sfx("ui_confirm")
	Game.records_note("rhythm_kitchen_grade", ["C", "B", "A", "S"].find(g))
	layer.queue_free()


func result_extra() -> Dictionary:
	return {"grade": grade()}
