extends MinigameBase
## Rhythmus-Tanz: Pfeile und A-Noten laufen im Takt über die Bühne-Leiste. Genau im Kreis den
## Stick in die Richtung schnippen (oder A drücken)! PERFEKT = 3, GUT = 1. Serien geben Bonus,
## das Tempo zieht zweimal an. Die Figuren tanzen mit – oder stolpern.

const PERFECT := 0.075
const GOOD := 0.17
const LANE_SPEED := 340.0   # Pixel pro Sekunde
const KINDS := ["left", "right", "up", "down", "a"]

var notes: Array[Dictionary] = []
var song_t := 0.0
var bpm := 96.0
var _next_beat := 1.6
var _beat_idx := 0
var _judged: Array[Dictionary] = [{}, {}, {}, {}]
var _prev_mag: Array[float] = [0.0, 0.0, 0.0, 0.0]
var combo: Array[int] = [0, 0, 0, 0]
var _lane: Control
var _marker: Control
var _spots: Array[OmniLight3D] = []
var _floor_tiles: Array[MeshInstance3D] = []
var _cpu_plan: Array[Dictionary] = [{}, {}, {}, {}]


func _init() -> void:
	game_id = "rhythm_dance"
	touch_profile = "dance"
	env_preset = "sunset"
	time_limit = 42.0
	arena_radius = 7.0
	teaser_height = 1.2
	cannon_pos = Vector3(0, 0, 11)
	spawn_points = [Vector3(-4.5, 0.6, 0), Vector3(-1.5, 0.6, 0), Vector3(1.5, 0.6, 0), Vector3(4.5, 0.6, 0)]


func build_arena() -> void:
	# Gartenfest-Bühne: Holzbühne mit Pastell-Tanzfliesen, Lichterketten, Vorhang und Wiesen-Publikum
	WorldKit.box(world, Vector3(30, 1, 22), Vector3(0, -0.6, 2), Color("#7cc860"), false)
	WorldKit.box(world, Vector3(14, 1.0, 7), Vector3(0, -0.5, 0), Color("#c98d5a"))
	var cols := [Color("#ffb3c7"), Color("#a8dcff"), Color("#ffe08a"), Color("#b6f29a")]
	var bm := BoxMesh.new()
	bm.size = Vector3(1.9, 0.06, 1.9)
	for x in 7:
		for z in 3:
			var mi := MeshInstance3D.new()
			mi.mesh = bm
			mi.material_override = WorldKit.mat(cols[(x + z) % 4], 0.6, 0.15)
			world.add_child(mi)
			mi.position = Vector3(-6 + x * 2.0, 0.03, -2 + z * 2.0)
			_floor_tiles.append(mi)
	# Rückwand mit Vorhang und Wimpelkette
	WorldKit.box(world, Vector3(18, 7, 0.6), Vector3(0, 3.5, -4.5), Color("#fff1d8"), false)
	for k in 9:
		var cur := WorldKit.box(world, Vector3(1.9, 6.2, 0.3), Vector3(-8 + k * 2.0, 3.3, -4.0), Color("#e8546a") if k % 2 == 0 else Color("#d0405a"), false)
		cur.name = "Curtain"
	for k in 14:
		var flag := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.7, 0.8, 0.05)
		pm.material = WorldKit.mat(cols[k % 4], 0.7)
		flag.mesh = pm
		flag.rotation.z = PI
		flag.position = Vector3(-8.5 + k * 1.3, 6.4 - absf(k - 6.5) * 0.06, -3.6)
		world.add_child(flag)
	for side in [-1.0, 1.0]:
		WorldKit.place(world, "plat/flowers", Vector3(side * 7.8, 0, -3.2), 0.0, 2.0)
		WorldKit.place(world, "town/lantern", Vector3(side * 7.6, 0, 2.6), 0.0, 2.0)
		WorldKit.place(world, "nat/tree_oak", Vector3(side * 12.0, 0, -5.0), 0.0, 3.0)
	for i in 4:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.85, 0.6).lerp(cols[i], 0.4)
		l.light_energy = 1.4
		l.omni_range = 8.0
		world.add_child(l)
		l.position = Vector3(-6 + i * 4.0, 5.5, 1.0)
		_spots.append(l)
	# Publikum: Wiesentiere vor der Bühne
	for i in 9:
		var who: String = ["pet/bunny", "pet/chick", "pet/cat", "pet/deer", "pet/cow", "npc/duck"][i % 6]
		var fan := CharacterRig.new()
		world.add_child(fan)
		fan.setup(who, -1, 0.9)
		fan.position = Vector3(-8 + i * 2.0, 0, 6.8)
		fan.face_now(Vector3(0, 0, -1))
		fan.play("idle")
		var tw := fan.create_tween().set_loops()
		tw.tween_property(fan, "position:y", 0.35, 0.3 + (i % 3) * 0.04).set_trans(Tween.TRANS_SINE)
		tw.tween_property(fan, "position:y", 0.0, 0.3 + (i % 3) * 0.04).set_trans(Tween.TRANS_SINE)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 1.0, 0)
	c.offset = Vector3(0, 5.5, 10.5)
	c.min_dist = 1.0
	c.max_dist = 1.0
	c.follow = false


func on_start() -> void:
	for av in avatars:
		var a := av as PartyAvatar
		a.can_move = false
		a.can_jump = false
		a.can_shove = false
		a.velocity = Vector3.ZERO
		a.set_physics_process(false)
		a.rig.face_now(Vector3(0, 0, 1))
		a.rig.play("idle", 0.2)
	_build_lane()
	song_t = 0.0


func _build_lane() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	root.position = Vector2(0, 108)
	_hud_root.add_child(root)
	var bar := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 0.14, 0.08, 0.72)
	sb.set_corner_radius_all(40)
	sb.border_color = Color(1, 1, 1, 0.25)
	sb.set_border_width_all(3)
	bar.add_theme_stylebox_override("panel", sb)
	bar.position = Vector2(-520, 0)
	bar.size = Vector2(1040, 92)
	root.add_child(bar)
	_lane = Control.new()
	_lane.clip_contents = true
	_lane.position = Vector2(-516, 4)
	_lane.size = Vector2(1032, 84)
	root.add_child(_lane)
	_marker = TextureRect.new()
	(_marker as TextureRect).texture = FX.tex_ring
	(_marker as TextureRect).expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_marker.size = Vector2(96, 96)
	_marker.position = Vector2(-470, -2)
	_marker.modulate = Color(1, 1, 1, 0.9)
	root.add_child(_marker)


func _hit_x() -> float:
	return 52.0   # Mitte des Markers innerhalb der Lane


func _spawn_note(beat_time: float) -> void:
	var prog := 1.0 - time_left / time_limit
	var pool := KINDS.slice(0, 4)
	if prog > 0.25:
		pool = KINDS
	var kind: String = pool[randi() % pool.size()]
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size = Vector2(72, 72)
	var col := {"left": Color("#ff6fb5"), "right": Color("#6fd0ff"), "up": Color("#ffd23f"), "down": Color("#7dff6a"), "a": Color.WHITE}[kind] as Color
	if kind == "a":
		var g := InputHub.glyph_texture("a")
		tr.texture = g if g else UI.icon_tex("star", 72)
	else:
		tr.texture = UI.icon_tex("arrow_" + kind, 72, col)
	_lane.add_child(tr)
	notes.append({"t": beat_time, "kind": kind, "node": tr, "done": false})


func on_tick(delta: float) -> void:
	song_t += delta
	var prog := 1.0 - time_left / time_limit
	bpm = 96.0 if prog < 0.35 else (112.0 if prog < 0.7 else 128.0)
	var spb := 60.0 / bpm
	# Noten 2 s im Voraus erzeugen
	while _next_beat < song_t + 2.2 and time_left > 2.5:
		var gap := spb if (_beat_idx % 8 != 7) else spb * 2.0
		if prog > 0.6 and randf() < 0.25:
			gap = spb * 0.5
		_spawn_note(_next_beat)
		_next_beat += gap
		_beat_idx += 1
	# Takt-Effekte
	var beat_phase := fmod(song_t, spb) / spb
	_marker.scale = Vector2.ONE * (1.0 + (1.0 - beat_phase) * 0.12)
	_marker.pivot_offset = _marker.size * 0.5
	for i in _spots.size():
		_spots[i].light_energy = 0.9 + (1.0 - beat_phase) * 1.3 * (1.0 if (int(song_t / spb) + i) % 2 == 0 else 0.4)
	for k in _floor_tiles.size():
		var on := (k + int(song_t / spb)) % 3 == 0
		(_floor_tiles[k].material_override as StandardMaterial3D).emission_energy_multiplier = 1.4 if on else 0.15
	# Noten bewegen
	for n in notes.duplicate():
		var dt: float = float(n.t) - song_t
		var tr: TextureRect = n.node
		tr.position = Vector2(_hit_x() + dt * LANE_SPEED - 36.0, 6)
		if dt < -GOOD and not n.done:
			n.done = true
			for i in 4:
				if not _judged[i].has(n.t):
					_judge(i, n, "miss")
			tr.modulate = Color(1, 1, 1, 0.35)
		if dt < -1.0:
			notes.erase(n)
			tr.queue_free()
	# Eingaben auswerten
	for i in 4:
		var inp := _read_input(i)
		if inp != "":
			_try_hit(i, inp)


func _read_input(i: int) -> String:
	var mv := InputHub.move(i)
	var mag := mv.length()
	var res := ""
	if mag > 0.6 and _prev_mag[i] <= 0.6:
		if absf(mv.x) > absf(mv.y):
			res = "right" if mv.x > 0 else "left"
		else:
			res = "down" if mv.y > 0 else "up"
	_prev_mag[i] = mag
	if InputHub.pressed(i, "a"):
		res = "a"
	return res


func _try_hit(i: int, inp: String) -> void:
	var best: Dictionary = {}
	var bd := INF
	for n in notes:
		if _judged[i].has(n.t):
			continue
		var d := absf(float(n.t) - song_t)
		if d < bd:
			bd = d
			best = n
	if best.is_empty() or bd > GOOD * 1.6:
		return   # weit weg von jeder Note: ignorieren (kein Spam-Malus)
	if String(best.kind) != inp or bd > GOOD:
		_judge(i, best, "miss")
	elif bd <= PERFECT:
		_judge(i, best, "perfect")
	else:
		_judge(i, best, "good")


func _judge(i: int, n: Dictionary, grade: String) -> void:
	_judged[i][n.t] = grade
	var av := avatars[i] as PartyAvatar
	var head := av.global_position + Vector3.UP * 2.6
	match grade:
		"perfect":
			combo[i] += 1
			var bonus := 1 if combo[i] >= 8 else 0
			scores[i] += 3 + bonus
			Juice.float_text(self, head, "PERFEKT!", Color("#ffd23f"), 64, 1.0, 0.6)
			_dance(av, String(n.kind), true)
			if not Game.players[i].cpu:
				Audio.sfx("pluck", null, -6.0, 1.5)
		"good":
			combo[i] += 1
			scores[i] += 1
			Juice.float_text(self, head, "GUT", Color("#7dff9a"), 56, 0.8, 0.5)
			_dance(av, String(n.kind), false)
		_:
			if combo[i] >= 5:
				Juice.float_text(self, head + Vector3.UP * 0.5, "Serie weg!", Color("#ff6b6b"), 50, 0.8, 0.6)
			combo[i] = 0
			Juice.float_text(self, head, "DANEBEN", Color("#ff6b6b"), 50, 0.6, 0.5)
			av.rig.play("hit", 0.05, 1.4, true)
			av.rig.lock(0.35)
			av.rig.squash(1.2, 0.8, 0.3)
	if combo[i] > 0 and combo[i] % 10 == 0:
		FX.confetti(av.global_position + Vector3.UP * 2.0, 30)
		Juice.float_text(self, head + Vector3.UP * 0.7, "%d er Serie!" % combo[i], Color("#c79bff"), 60)


func _dance(av: PartyAvatar, kind: String, perfect: bool) -> void:
	match kind:
		"left", "right":
			av.rig.spin_around(1.0 if kind == "right" else -1.0, 0.32)
		"up":
			av.rig.hop(0.7 if perfect else 0.45, 0.3)
		"down":
			av.rig.squash(1.3, 0.7, 0.28)
		"a":
			av.rig.play("cheer", 0.05, 1.6, true)
			av.rig.lock(0.3)
			av.rig.hop(0.4, 0.25)
	if perfect:
		FX.stars(av.global_position + Vector3.UP * 1.0, Game.player_color(av.slot).lightened(0.4), 5)


func cpu_think(slot: int, _delta: float) -> void:
	var level: int = Game.players[slot].cpu_level
	var plan := _cpu_plan[slot]
	var held := {}
	var mv := Vector2.ZERO
	# nächste unbewertete Note planen
	if plan.is_empty() or _judged[slot].has(plan.t):
		plan.clear()
		for n in notes:
			if not _judged[slot].has(n.t) and float(n.t) > song_t - 0.05:
				var r := randf()
				var off := 0.0
				var perfect_p: float = [0.3, 0.55, 0.78][level]
				var good_p: float = [0.45, 0.33, 0.18][level]
				if r < perfect_p:
					off = randf_range(-0.04, 0.04)
				elif r < perfect_p + good_p:
					off = randf_range(0.09, 0.14) * (1.0 if randf() < 0.5 else -1.0)
				else:
					off = 0.4   # verpasst
				plan.merge({"t": n.t, "kind": n.kind, "at": float(n.t) + off})
				break
		_cpu_plan[slot] = plan
	if not plan.is_empty() and song_t >= float(plan.at) and song_t < float(plan.at) + 0.06:
		match String(plan.kind):
			"left":
				mv = Vector2.LEFT
			"right":
				mv = Vector2.RIGHT
			"up":
				mv = Vector2.UP
			"down":
				mv = Vector2.DOWN
			"a":
				held["a"] = true
	InputHub.set_virtual(slot, mv, held)
