extends MinigameBase
## Schlummer-Sternchen-Tanz: Vier verschlafene Wiesentiere sitzen auf leuchtenden Pilzen – oben, rechts,
## unten, links. Nacheinander leuchten sie auf und singen ihren Ton. Danach müssen alle die Folge im Takt
## mit dem Stick (oder Steuerkreuz) nachspielen. Jede Runde wird die Folge länger und schneller.
## Ein falscher Ton oder zu langsam? Dann schläft man ein und ist raus. Wer am längsten wach bleibt, gewinnt.
## Online: Folgen kommen aus dem gemeinsamen Spiel-Zufall, jeder bewertet seine eigene Eingabe.

const DIRS := ["up", "right", "down", "left"]
const VECS := [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
const ANIMALS := ["pet/chick", "pet/bunny", "pet/cat", "pet/deer"]
const GLOW := [Color("#ffe27a"), Color("#ff9fc6"), Color("#8fd0ff"), Color("#b6f29a")]
const PITCH := [1.0, 1.26, 1.5, 1.68]

var creatures: Array[CharacterRig] = []
var lamps: Array[OmniLight3D] = []
var caps: Array[MeshInstance3D] = []
var seq: Array[int] = []
var _phase := "pause"
var _t := 1.0
var _show_i := 0
var _round := 0
var _progress: Array[int] = [0, 0, 0, 0]
var _prev_mag: Array[float] = [0, 0, 0, 0]
var _done: Array[bool] = [false, false, false, false]
var _cpu_next: Array[float] = [0, 0, 0, 0]
var _bells: Array[Node3D] = []


func _init() -> void:
	game_id = "sleepy_stars"
	env_preset = "sunset"
	time_limit = 90.0
	show_timer = false
	survival = true
	arena_radius = 8.0
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 11)
	spawn_points = [Vector3(-4.5, 0.6, 3.5), Vector3(-1.5, 0.6, 3.5), Vector3(1.5, 0.6, 3.5), Vector3(4.5, 0.6, 3.5)]


func build_arena() -> void:
	WorldKit.cylinder(world, 11.0, 1.0, Vector3(0, -0.5, 0), Color("#7cc46a"))
	var pos := [Vector3(0, 0, -5.2), Vector3(4.2, 0, -2.6), Vector3(0, 0, -0.4), Vector3(-4.2, 0, -2.6)]
	for k in 4:
		var stem := WorldKit.cylinder(world, 0.35, 1.2, pos[k] + Vector3(0, 0.6, 0), Color("#f4ead2"), false)
		stem.name = "Stem%d" % k
		var cap := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.3
		sm.height = 1.2
		sm.material = WorldKit.mat(GLOW[k].darkened(0.25), 0.6, 0.15)
		cap.mesh = sm
		cap.position = pos[k] + Vector3(0, 1.35, 0)
		world.add_child(cap)
		caps.append(cap)
		var c := CharacterRig.new()
		world.add_child(c)
		c.setup(ANIMALS[k], -1, 1.15)
		c.position = pos[k] + Vector3(0, 1.85, 0)
		c.face_now(Vector3(0, 0, 1))
		c.play("idle")
		creatures.append(c)
		var l := OmniLight3D.new()
		l.light_color = GLOW[k]
		l.light_energy = 0.0
		l.omni_range = 5.0
		l.position = pos[k] + Vector3(0, 2.6, 0.6)
		world.add_child(l)
		lamps.append(l)
		var arrow := Sprite3D.new()
		arrow.texture = UI.icon_tex("arrow_" + DIRS[k], 96, GLOW[k])
		arrow.pixel_size = 0.012
		arrow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		arrow.position = pos[k] + Vector3(0, 3.6, 0)
		world.add_child(arrow)
	for i in 4:
		var bell := Assets.spawn("hol/bell", world, spawn_points[i] + Vector3(0, 0, 1.2), 0.0, 1.4)
		Assets.tint(bell, Game.player_color(i).lightened(0.2))
		_bells.append(bell)
	for i in 14:
		var a := TAU * i / 14.0
		WorldKit.place(world, ["plat/mushrooms", "nat/tree_oak", "plat/flowers", "nat/bush"][i % 4], Vector3(cos(a), 0, sin(a)) * 10.0, randf() * 360.0, 2.0)
	var fireflies := FX.emitter({"amount": 40, "life": 4.0, "one_shot": false, "explosive": 0.0, "spread": 180.0, "vel_min": 0.1, "vel_max": 0.4,
		"gravity": Vector3(0, 0.05, 0), "size": 0.18, "additive": true, "color": Color(1.0, 0.95, 0.6, 0.9), "box": Vector3(10, 2, 6)})
	world.add_child(fireflies)
	fireflies.position = Vector3(0, 2.5, -2)
	fireflies.emitting = true


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 1.4, -1.2)
	c.offset = Vector3(0, 6.5, 10.5)
	c.min_dist = 1.0
	c.max_dist = 1.0
	c.follow = false


func on_start() -> void:
	for av in avatars:
		var a := av as PartyAvatar
		a.can_move = false
		a.can_jump = false
		a.can_shove = false
		a.set_physics_process(false)
		a.rig.face_now(Vector3(0, 0, -1))
	_next_round()


func _next_round() -> void:
	_round += 1
	seq.append(rng.randi() % 4)
	if _round == 1:
		seq.append(rng.randi() % 4)
	_phase = "pause"
	_t = 1.0
	_show_i = 0
	for i in 4:
		_progress[i] = 0
		_done[i] = not alive[i] or not active[i]
	CutsceneManager.big_word("Runde %d" % _round, Color.WHITE, 0.4)


func _note_dur() -> float:
	return clampf(0.62 - _round * 0.035, 0.3, 0.62)


func on_tick(delta: float) -> void:
	_t -= delta
	match _phase:
		"pause":
			if _t <= 0.0:
				_phase = "show"
				_t = 0.0
		"show":
			if _t <= 0.0:
				if _show_i < seq.size():
					_light(seq[_show_i], _note_dur() * 0.8)
					_show_i += 1
					_t = _note_dur()
				else:
					_phase = "input"
					_t = seq.size() * maxf(_note_dur(), 0.45) + 1.6
					CutsceneManager.big_word("Jetzt du!", UI.GOLD, 0.3)
					for i in 4:
						_cpu_next[i] = randf_range(0.35, 0.6)
		"input":
			for i in active_slots():
				if _done[i] or not Net.owns_slot(i):
					continue
				var inp := _read(i, delta)
				if inp >= 0:
					_judge(i, inp)
			var all_done := true
			for i in active_slots():
				if not _done[i]:
					all_done = false
			if _t <= 0.0 or all_done:
				for i in active_slots():
					if not _done[i] and Net.owns_slot(i):
						_fall_asleep(i)
				if alive_count() <= 1 or _round >= 12:
					end_game()
				else:
					_next_round()


func _read(i: int, delta: float) -> int:
	if Game.players[i].cpu:
		_cpu_next[i] -= delta
		if _cpu_next[i] <= 0.0:
			_cpu_next[i] = randf_range(0.25, 0.42)
			var level: int = Game.players[i].cpu_level
			var ok: bool = randf() < [0.9, 0.95, 0.985][level] - _round * 0.008
			var want: int = seq[_progress[i]]
			return want if ok else (want + 1 + randi() % 3) % 4
		return -1
	var mv := InputHub.move(i)
	var mag := mv.length()
	var res := -1
	if mag > 0.6 and _prev_mag[i] <= 0.6:
		var best := -1.0
		for k in 4:
			var d := mv.normalized().dot(VECS[k])
			if d > best:
				best = d
				res = k
	_prev_mag[i] = mag
	return res


func _judge(i: int, k: int) -> void:
	var av := avatars[i] as PartyAvatar
	_ring_bell(i, k)
	if k == seq[_progress[i]]:
		_progress[i] += 1
		scores[i] += 1
		av.rig.hop(0.3, 0.2)
		if _progress[i] >= seq.size():
			_done[i] = true
			scores[i] += 2
			av.rig.react("cheer")
			Juice.float_text(self, av.global_position + Vector3.UP * 2.6, "Perfekt!", UI.GOLD, 70)
		report_score(i)
	else:
		_fall_asleep(i)


func _fall_asleep(i: int) -> void:
	_done[i] = true
	if not alive[i]:
		return
	var av := avatars[i] as PartyAvatar
	av.rig.react("sleepy")
	FX.zzz(av, 2.4, 4.0)
	Audio.sfx("sad_trombone", av.global_position, -8.0)
	eliminate(i)
	report_score(i)


func _ring_bell(i: int, k: int) -> void:
	Audio.sfx("bell", null, -6.0, PITCH[k], 0.0)
	Juice.squash(_bells[i], 1.3, 0.75, 0.25, _bells[i].scale)
	_light(k, 0.18, false)


func _light(k: int, dur: float, sing := true) -> void:
	var l := lamps[k]
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 3.5, 0.06)
	tw.tween_property(l, "light_energy", 0.0, dur)
	var m := caps[k].mesh.surface_get_material(0) as StandardMaterial3D
	var tw2 := caps[k].create_tween()
	tw2.tween_property(m, "emission_energy_multiplier", 2.2, 0.06)
	tw2.tween_property(m, "emission_energy_multiplier", 0.15, dur)
	if sing:
		Audio.sfx("pluck", null, 0.0, PITCH[k], 0.0)
		creatures[k].play("cheer", 0.05, 1.5, true)
		creatures[k].hop(0.45, 0.28)
		FX.stars(creatures[k].global_position + Vector3.UP * 0.8, GLOW[k], 6)


func on_remote_score(slot: int, _extra: Dictionary) -> void:
	if not alive[slot]:
		var av := avatars[slot] as PartyAvatar
		av.rig.react("sleepy")
		FX.zzz(av, 2.4, 4.0)
		_done[slot] = true
		if badges.size() > slot:
			badges[slot].set_out(true)


func cpu_think(slot: int, _delta: float) -> void:
	InputHub.set_virtual(slot, Vector2.ZERO)
