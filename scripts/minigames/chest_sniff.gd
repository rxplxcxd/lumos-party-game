extends MinigameBase
## Schatzkisten-Schnüffeln: Fünf Schatzkisten, ein kleiner Kistengeist versteckt darin Gold. Reihum sucht
## sich jeder eine Kiste aus (bereits gewählte sind weg). Dann klappen alle Deckel auf: Gold (10 Münzen),
## kleine Münzhaufen (2–4) – oder der Geist ruft "Buh!" und mopst 3 Münzen. Vier Runden. Online: Host-Modell.

const N := 5

var chests: Array[Node3D] = []
var contents: Array[int] = []      # 10 = Gold, 2..4 = Münzen, -3 = Geist
var picks: Array[int] = [-1, -1, -1, -1]
var _turn_order: Array[int] = []
var _turn := 0
var _cursor := 0
var phase := "intro"
var _round := 0
var _t := 1.0
var _marker: MeshInstance3D
var _cpu_t := 0.0


func _init() -> void:
	game_id = "chest_sniff"
	env_preset = "sunset"
	time_limit = 90.0
	show_timer = false
	arena_radius = 8.0
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 10)
	net_model = "host"
	score_format = "%d Münzen"
	spawn_points = [Vector3(-4.5, 0.6, 3.6), Vector3(-1.5, 0.6, 3.6), Vector3(1.5, 0.6, 3.6), Vector3(4.5, 0.6, 3.6)]


func build_arena() -> void:
	WorldKit.cylinder(world, 10.0, 1.0, Vector3(0, -0.5, 0), Color("#d9c09a"))
	for k in N:
		var c := Assets.spawn("pirate/chest", world, _slot_pos(k), 0.0, 1.8)
		chests.append(c)
	_marker = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.8
	tm.outer_radius = 0.95
	tm.material = WorldKit.mat(Color.WHITE, 0.4, 1.0)
	_marker.mesh = tm
	_marker.visible = false
	world.add_child(_marker)
	for i in 12:
		var a := TAU * i / 12.0
		WorldKit.place(world, ["pirate/barrel", "pirate/palm", "pirate/rocks_a", "plat/flowers"][i % 4], Vector3(cos(a), 0, sin(a)) * 9.0, randf() * 360.0, 1.8)
	for p in [Vector3(-6, 0, -3), Vector3(6, 0, -3)]:
		WorldKit.torch_light(world, p + Vector3.UP * 2.0, Color(1.0, 0.75, 0.4), 1.6, 8.0)


func _slot_pos(k: int) -> Vector3:
	return Vector3((k - (N - 1) * 0.5) * 2.4, 0, -1.2)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 1.0, 0)
	c.offset = Vector3(0, 7, 10)
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
		av.rig.face_now(Vector3(0, 0, -1))
	_new_round()


func _new_round() -> void:
	_round += 1
	contents = [10, -3, 2, 3, 4]
	for k in range(N - 1, 0, -1):
		var j := rng.randi() % (k + 1)
		var tmp := contents[k]
		contents[k] = contents[j]
		contents[j] = tmp
	picks = [-1, -1, -1, -1]
	_turn_order = active_slots()
	for _k in (_round - 1):
		_turn_order.push_back(_turn_order.pop_front())
	_turn = 0
	_cursor = 0
	phase = "pick"
	_cpu_t = randf_range(0.6, 1.2)
	for k in N:
		chests[k].scale = Vector3.ONE * 1.8
		chests[k].rotation = Vector3.ZERO
	_marker.visible = true
	CutsceneManager.big_word("Runde %d" % _round, Color.WHITE, 0.4)
	_skip_taken()


func _picker() -> int:
	return _turn_order[_turn] if _turn < _turn_order.size() else -1


func _taken(k: int) -> bool:
	return k in picks


func _skip_taken() -> void:
	var guard := 0
	while _taken(_cursor) and guard < N:
		_cursor = (_cursor + 1) % N
		guard += 1


func on_tick(delta: float) -> void:
	_t -= delta
	if phase != "pick":
		return
	var p := _picker()
	if p < 0:
		phase = "open"
		_marker.visible = false
		_open_all()
		return
	var mem := cpu_mem[p]
	mem["cd"] = float(mem.get("cd", 0.0)) - delta
	var mv := InputHub.move(p)
	if absf(mv.x) > 0.6 and float(mem.cd) <= 0.0:
		var d := 1 if mv.x > 0 else -1
		_cursor = (_cursor + d + N) % N
		var guard := 0
		while _taken(_cursor) and guard < N:
			_cursor = (_cursor + d + N) % N
			guard += 1
		mem["cd"] = 0.2
		Audio.sfx("ui_move", null, -10.0)
	(_marker.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color = Game.player_color(p)
	(_marker.mesh.surface_get_material(0) as StandardMaterial3D).emission = Game.player_color(p)
	_marker.position = _slot_pos(_cursor) + Vector3(0, 2.4 + sin(Time.get_ticks_msec() / 160.0) * 0.12, 0)
	_marker.rotation.x = PI * 0.5
	if InputHub.pressed(p, "a"):
		picks[p] = _cursor
		var av := avatars[p] as PartyAvatar
		av.rig.react("determined")
		Juice.float_text(self, _slot_pos(_cursor) + Vector3.UP * 2.6, "P%d" % (p + 1), Game.player_color(p), 90)
		Audio.sfx("ui_confirm", null, -4.0)
		_turn += 1
		_cpu_t = randf_range(0.6, 1.2)
		_skip_taken()


var _last_phase := ""


func _open_all(apply_score := true) -> void:
	await get_tree().create_timer(0.6, false).timeout
	for k in N:
		var c := chests[k]
		var owner := picks.find(k)
		var v := contents[k]
		var tw := c.create_tween()
		tw.tween_property(c, "scale", Vector3(2.1, 1.5, 2.1), 0.12)
		tw.tween_property(c, "scale", Vector3.ONE * 1.8, 0.25).set_trans(Tween.TRANS_BACK)
		var top := c.global_position + Vector3.UP * 1.8
		if v == 10:
			FX.coins_burst(top, 10, true, world)
			FX.stars(top, Color(1, 0.9, 0.3), 18)
			Audio.sfx("chest_open", top)
			Audio.sfx("star", top, -2.0)
		elif v < 0:
			FX.smoke(top, Color(0.75, 0.7, 1.0), 12, 1.0)
			Audio.sfx("ghost", top)
			Juice.float_text(self, top + Vector3.UP * 0.6, "Buh!", Color("#c9b5ff"), 110)
		else:
			FX.coins_burst(top, v, true, world)
			Audio.sfx("coin", top, -4.0)
		if owner >= 0 and apply_score:
			var gained := v if v > 0 else -mini(3, int(scores[owner]))
			scores[owner] += gained
			var av := avatars[owner] as PartyAvatar
			av.rig.react("star_get" if v == 10 else ("scared" if v < 0 else "coin_gain"))
			Juice.float_text(self, av.global_position + Vector3.UP * 2.6, ("+%d" % gained) if gained >= 0 else "%d" % gained, Color("#7dff9a") if gained >= 0 else Color("#ff6b6b"), 90)
		await get_tree().create_timer(0.45, false).timeout
	await get_tree().create_timer(1.4, false).timeout
	if not apply_score:
		return
	if _round >= 4:
		end_game()
	else:
		_new_round()


func net_pack() -> Dictionary:
	return {"ph": phase, "cu": _cursor, "pk": picks, "tu": _picker(), "ct": contents}


func net_unpack(d: Dictionary) -> void:
	_cursor = int(d.get("cu", _cursor))
	phase = String(d.get("ph", phase))
	if phase == "open" and _last_phase != "open":
		var ct: Array = d.get("ct", [])
		var pk: Array = d.get("pk", [])
		for k in mini(N, ct.size()):
			if k < contents.size():
				contents[k] = int(ct[k])
			else:
				contents.append(int(ct[k]))
		for i in mini(4, pk.size()):
			picks[i] = int(pk[i])
		_open_all(false)
	_last_phase = phase
	var p := int(d.get("tu", -1))
	_marker.visible = phase == "pick" and p >= 0
	if p >= 0:
		(_marker.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color = Game.player_color(p)
	_marker.position = _slot_pos(_cursor) + Vector3(0, 2.4, 0)
	_marker.rotation.x = PI * 0.5


func cpu_think(slot: int, delta: float) -> void:
	var held := {}
	if phase == "pick" and _picker() == slot:
		_cpu_t -= delta
		if _cpu_t <= 0.0:
			held["a"] = true
	InputHub.set_virtual(slot, Vector2(1.0 if randf() < 0.03 else 0.0, 0), held)
