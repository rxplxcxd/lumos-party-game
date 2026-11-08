extends MinigameBase
## Seilziehen am Pilzbach: Über den plätschernden Bach spannt sich ein dickes Seil. A hämmern zum Ziehen –
## wer genau auf den pulsierenden Kraft-Takt drückt, zieht doppelt! 1 gegen 3: Das Solo ist dreimal so stark.
## Wer zuerst ins Wasser gezogen wird, verliert. Bei Zeitablauf gewinnt die Seite, auf der der Knoten liegt.
## Online: Host-Modell (Eingaben gehen an den Host, das Seil kommt zurück).

const WIN_X := 3.6
const BEAT := 0.8

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


func _init() -> void:
	game_id = "tug_of_war"
	env_preset = "day"
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
	for side in [-1.0, 1.0]:
		WorldKit.box(world, Vector3(14, 1, 12), Vector3(side * 8.6, -0.5, 0), Color("#7ec86a"))
	WorldKit.water(world, Vector2(3.4, 40), -0.6, Color(0.1, 0.45, 0.6), Color(0.45, 0.85, 0.9))
	WorldKit.box(world, Vector3(3.4, 1, 40), Vector3(0, -2.2, 0), Color("#4f8a6a"), false)
	for i in 10:
		var z := -14.0 + i * 3.2
		WorldKit.place(world, "nat/rock_small", Vector3(-1.9 if i % 2 == 0 else 1.9, -0.1, z), randf() * 360.0, 1.6)
		WorldKit.place(world, "plat/mushrooms", Vector3(-6.0 - (i % 3) * 2.5, 0, z * 0.6), randf() * 360.0, 1.8)
		WorldKit.place(world, "plat/mushrooms", Vector3(6.0 + (i % 3) * 2.5, 0, -z * 0.6), randf() * 360.0, 1.8)
	WorldKit.place(world, "nat/bridge_wood", Vector3(0, -0.2, -10), 90.0, 2.0)
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


func _strength(i: int) -> float:
	if category == "1v3" and i == solo_slot:
		return 2.7
	return 1.0


func on_tick(delta: float) -> void:
	if _done:
		return
	_beat_t += delta
	var phase := fmod(_beat_t, BEAT) / BEAT
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
	var phase := fmod(_beat_t, BEAT) / BEAT
	_beat_ring.scale = Vector3.ONE * (1.0 + (1.0 - phase) * 0.6)


func cpu_think(slot: int, _delta: float) -> void:
	var level: int = Game.players[slot].cpu_level
	var mem := cpu_mem[slot]
	var t := float(mem.get("t", 0.0)) - get_physics_process_delta_time()
	var held := {}
	if t <= 0.0:
		var phase := fmod(_beat_t, BEAT) / BEAT
		var aim_beat: bool = randf() < [0.25, 0.5, 0.8][level]
		if not aim_beat or phase > 0.86 or phase < 0.1:
			held["a"] = true
			t = 1.0 / [5.0, 7.0, 9.0][level]
	mem["t"] = t
	InputHub.set_virtual(slot, Vector2.ZERO, held)
