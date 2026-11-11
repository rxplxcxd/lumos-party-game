extends MinigameBase
## Seilziehen am Pilzbach: Über den plätschernden Bach spannt sich ein dickes Seil. A hämmern zum Ziehen –
## wer genau auf den pulsierenden Kraft-Takt drückt, zieht doppelt! 1 gegen 3: Das Solo ist dreimal so stark.
## Wer zuerst ins Wasser gezogen wird, verliert. Bei Zeitablauf gewinnt die Seite, auf der der Knoten liegt.
## Online: Host-Modell (Eingaben gehen an den Host, das Seil kommt zurück).

const WIN_X := 3.6
const BEAT_BEATS := 2.0   # Kraft-Takt = alle zwei Musik-Schläge (folgt dem BPM des Soundtracks)

var rope_x := 0.0
var rope_v := 0.0
var _beat_t := 0.0
var _rope: MeshInstance3D
var _knot: Node3D
var _beat_ring: MeshInstance3D
var _done := false
var _press_t: Array[float] = [0, 0, 0, 0]
var _side: Array[int] = [0, 0, 0, 0]
var _slot_pos: Array[float] = [0, 0, 0, 0]
var _fans: Array[CharacterRig] = []


func _init() -> void:
	game_id = "tug_of_war"
	env_preset = "day"
	backdrop_style = "meadow"
	time_limit = 25.0
	arena_radius = 9.0
	teaser_height = 0.9
	cannon_pos = Vector3(0, 0, 11)
	touch_profile = "action_only"
	net_model = "host"


func on_setup() -> void:
	for i in 4:
		_side[i] = teams[i] if is_team_game() else (0 if i % 2 == 0 else 1)
	var counts := [0, 0]
	for i in 4:
		if active[i]:
			_slot_pos[i] = 2.2 + counts[_side[i]] * 1.6
			counts[_side[i]] += 1
	spawn_points = []
	for i in 4:
		var sx := -1.0 if _side[i] == 0 else 1.0
		spawn_points.append(Vector3(sx * _slot_pos[i], 0.6, 0))


func build_arena() -> void:
	# Der Pilzbach: ein echter, mäandernder Bach, der beidseitig bis zum Horizont fließt, mit durchgehenden
	# Ufern, Flussbett, Schilf und Steinen. Auf dem Wasser treiben Seerosen, Blätter und Enten, Fische springen.
	var path := WorldKit.meander_path(175.0, 8.0, 18.0, 9.0)
	WorldKit.river(world, path, 3.4, -0.45, Color("#7ec86a"), 80.0, true)
	var life := RiverLife.new().setup(path, 3.4, -0.45)
	world.add_child(life)
	# Ufer-Deko: Pilzgruppen (Pilzbach!), Blumen, Büsche, Bäume weiter hinten – Arena-Mitte bleibt frei
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for i in 90:
		var z := rng.randf_range(-160.0, 160.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * rng.randf_range(3.0, 40.0)
		if absf(z) < 7.0 and absf(x) < 9.0:
			continue   # Zugplatz frei halten
		var off := 0.0
		for k in path.size() - 1:
			if (path[k] as Vector3).z <= z and (path[k + 1] as Vector3).z > z:
				off = (path[k] as Vector3).x
		var far := absf(x) > 18.0
		var key: String = ["nat/tree_oak", "plat/tree", "nat/tree_default", "nat/bush"][i % 4] if far else ["plat/mushrooms", "plat/flowers", "nat/flower_yellow", "nat/flower_purple", "nat/bush", "plat/mushrooms"][i % 6]
		WorldKit.place(world, key, Vector3(x + off, 0, z), rng.randf() * 360.0, rng.randf_range(2.4, 3.6) if far else rng.randf_range(1.4, 2.2))
	# dichter Uferbewuchs rund um den Zugplatz
	for i in 70:
		var zz := rng.randf_range(-36.0, 36.0)
		var xx := (-1.0 if i % 2 == 0 else 1.0) * rng.randf_range(2.6, 16.0)
		if absf(zz) < 6.0 and absf(xx) < 8.5:
			continue
		WorldKit.place(world, ["plat/flowers", "nat/flower_yellow", "nat/flower_red", "nat/flower_purple", "nat/grass", "plat/mushrooms", "nat/mushroom"][i % 7],
			Vector3(xx, 0, zz), rng.randf() * 360.0, rng.randf_range(1.2, 2.0))
	for z in [-10.0, 34.0]:
		WorldKit.place(world, "nat/bridge_wood", Vector3(0, -0.15, z), 90.0, 2.0)
	# Kleine Mühle am Ufer mit drehendem Wasserrad
	WorldKit.cottage(world, Vector3(-11, 0, -16), 20.0, 1.3, Color("#fff1d8"), Color("#ff8a8a"))
	var wheel := WorldKit.cylinder(world, 1.6, 0.4, Vector3(-2.6, 0.3, -16), Color("#b07a4a"), false)
	wheel.rotation.z = PI * 0.5
	var wt := wheel.create_tween().set_loops()
	wt.tween_property(wheel, "rotation:x", TAU, 6.0).as_relative()
	# Zuschauer: Wiesentiere auf beiden Ufern, die mitfiebern
	for k in 6:
		var fan := CharacterRig.new()
		world.add_child(fan)
		fan.setup(["pet/bunny", "pet/chick", "pet/cat", "pet/deer", "pet/cow", "npc/duck"][k], -1, 0.8)
		var sx := -1.0 if k % 2 == 0 else 1.0
		fan.position = Vector3(sx * (5.0 + k * 0.8), 0, -5.5 - (k % 3) * 1.2)
		fan.face_now(Vector3(-sx * 0.3, 0, 1))
		fan.play("idle")
		_fans.append(fan)
	_rope = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.09
	cm.bottom_radius = 0.09
	cm.height = 1.0
	cm.material = WorldKit.mat(Color("#d8b47a"), 0.9)
	_rope.mesh = cm
	_rope.rotation.z = PI * 0.5
	_rope.position.y = 1.15
	world.add_child(_rope)
	_knot = Assets.spawn("plat/flowers", world, Vector3(0, 1.15, 0), 0.0, 1.4)
	_beat_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.material = WorldKit.mat(Color("#ffd23f"), 0.4, 1.2)
	_beat_ring.mesh = tm
	_beat_ring.position = Vector3(0, 1.15, 0)
	_beat_ring.rotation.x = PI * 0.5
	world.add_child(_beat_ring)
	for side in [-1.0, 1.0]:
		var flag := WorldKit.place(world, "plat/flag", Vector3(side * WIN_X, 0, 2.5), 0.0, 1.4)
		Assets.tint(flag, TEAM_COLORS[0 if side < 0 else 1])


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0.8, 0)
	c.offset = Vector3(0, 7.5, 12.5)
	c.min_dist = 1.0
	c.max_dist = 1.0
	c.follow = false


func on_start() -> void:
	for i in 4:
		var av := avatars[i] as PartyAvatar
		av.can_move = false
		av.can_jump = false
		av.can_shove = false
		av.set_physics_process(false)
		av.rig.face_now(Vector3(1 if _side[i] == 0 else -1, 0, 0))
		av.rig.play("hold")


## Position im Kraft-Takt (0..1), direkt aus der Beat-Uhr der Musik – auch nach dem Hurry-Up-Tempowechsel.
func _pull_phase() -> float:
	return fposmod(Audio.music_beat(), BEAT_BEATS) / BEAT_BEATS


func _strength(i: int) -> float:
	if category == "1v3" and i == solo_slot:
		return 2.7
	return 1.0


func on_tick(delta: float) -> void:
	if _done:
		return
	_beat_t += delta
	var phase := _pull_phase()
	_beat_ring.scale = Vector3.ONE * (1.0 + (1.0 - phase) * 0.6)
	var pull := [0.0, 0.0]
	for i in active_slots():
		if InputHub.pressed(i, "a"):
			var on_beat := phase < 0.16 or phase > 0.88
			var p := _strength(i) * (2.0 if on_beat else 1.0)
			pull[_side[i]] += p
			_press_t[i] = 0.12
			var av := avatars[i] as PartyAvatar
			av.rig.squash(0.9, 1.08, 0.15)
			if on_beat:
				FX.stars(av.global_position + Vector3.UP * 1.8, Color(1, 0.9, 0.4), 3)
	rope_v += (pull[1] - pull[0]) * 0.11
	rope_v = move_toward(rope_v, 0.0, delta * 1.6)
	rope_x += rope_v * delta
	_apply_visuals(delta)
	if absf(rope_x) >= WIN_X:
		_finish(1 if rope_x > 0.0 else 0)


func _apply_visuals(delta: float) -> void:
	var left_end := -10.0 + rope_x
	var right_end := 10.0 + rope_x
	_rope.position.x = (left_end + right_end) * 0.5
	_rope.scale.y = right_end - left_end
	_knot.position.x = rope_x
	_beat_ring.position.x = rope_x
	for i in active_slots():
		var av := avatars[i] as PartyAvatar
		var sx := -1.0 if _side[i] == 0 else 1.0
		av.position.x = sx * _slot_pos[i] + rope_x
		_press_t[i] = maxf(0.0, _press_t[i] - delta)
		av.rig.rotation.z = lerpf(av.rig.rotation.z, (0.35 if _press_t[i] > 0.0 else 0.18) * sx, delta * 10.0)


func _finish(winner_side: int) -> void:
	_done = true
	for f in _fans:
		f.react("cheer")
	var loser := 1 - winner_side
	Audio.sfx("splash", Vector3(0, 0, 0))
	Juice.shake(0.35)
	for i in active_slots():
		var av := avatars[i] as PartyAvatar
		if _side[i] == loser:
			var tw := av.create_tween()
			tw.tween_property(av, "position", Vector3(0, -1.2, av.position.z), 0.5).set_trans(Tween.TRANS_QUAD)
			tw.tween_callback(func() -> void: FX.splash(av.global_position, 1.0))
			av.rig.react("launch")
		else:
			av.rig.react("victory")
	for i in 4:
		scores[i] = 1.0 if _side[i] == winner_side else 0.0
	await get_tree().create_timer(1.0, false).timeout
	end_game()


func team_result() -> int:
	var w := 1 if rope_x > 0.0 else (0 if rope_x < 0.0 else -1)
	if w < 0:
		return -1
	for i in active_slots():
		if _side[i] == w:
			return teams[i]
	return -1


func on_timeout() -> void:
	for i in 4:
		scores[i] = 1.0 if (rope_x > 0.0) == (_side[i] == 1) and rope_x != 0.0 else 0.0
	end_game()


func net_pack() -> Dictionary:
	return {"r": snappedf(rope_x, 0.01), "b": snappedf(_beat_t, 0.01)}


func net_unpack(d: Dictionary) -> void:
	rope_x = lerpf(rope_x, float(d.get("r", rope_x)), 0.6)
	_beat_t = float(d.get("b", _beat_t))
	_apply_visuals(0.05)
	var phase := _pull_phase()
	_beat_ring.scale = Vector3.ONE * (1.0 + (1.0 - phase) * 0.6)


func cpu_think(slot: int, _delta: float) -> void:
	var level: int = Game.players[slot].cpu_level
	var mem := cpu_mem[slot]
	var t := float(mem.get("t", 0.0)) - get_physics_process_delta_time()
	var held := {}
	if t <= 0.0:
		var phase := _pull_phase()
		var aim_beat: bool = randf() < Game.lv([0.25, 0.5, 0.8], level)
		if not aim_beat or phase > 0.86 or phase < 0.1:
			held["a"] = true
			t = 1.0 / Game.lv([5.0, 7.0, 9.0], level)
	mem["t"] = t
	InputHub.set_virtual(slot, Vector2.ZERO, held)
