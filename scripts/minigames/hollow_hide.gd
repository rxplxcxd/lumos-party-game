extends MinigameBase
## Baumhöhlen-Versteck (1 gegen 3): Das Solo schlüpft in einen von fünf hohlen Baumstümpfen. Dann wirbelt es
## die Stümpfe durcheinander (Stick links/rechts tauscht Nachbarn – je flinker, desto verwirrender). Das Trio
## muss mit den Augen folgen und danach je einen Stumpf antippen. Findet jemand das Solo, punktet das Trio,
## sonst das Solo. Drei Runden, die meisten Punkte gewinnen. Online: Host-Modell.

const N := 5
const SPACING := 3.2

var stumps: Array[Node3D] = []
var order: Array[int] = [0, 1, 2, 3, 4]   # Stumpf-ID je Position
var hidden_id := 0
var phase := "intro"
var _t := 1.5
var _round := 0
var _cursor: Array[int] = [0, 1, 2, 3]
var _locked: Array[bool] = [false, false, false, false]
var _pick: Array[int] = [-1, -1, -1, -1]
var _markers: Array[Node3D] = []
var _swap_cd := 0.0
var _swaps := 0
var team_pts := [0, 0]
var _cpu_t: Array[float] = [0, 0, 0, 0]
var _cpu_guess: Array[int] = [0, 0, 0, 0]


func _init() -> void:
	game_id = "hollow_hide"
	env_preset = "day"
	time_limit = 80.0
	show_timer = false
	arena_radius = 9.0
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 11)
	net_model = "host"
	spawn_points = [Vector3(-4.5, 0.6, 4.5), Vector3(-1.5, 0.6, 4.5), Vector3(1.5, 0.6, 4.5), Vector3(4.5, 0.6, 4.5)]


func build_arena() -> void:
	WorldKit.cylinder(world, 12.0, 1.0, Vector3(0, -0.5, 0), Color("#6fb85a"))
	for k in N:
		var s := Node3D.new()
		world.add_child(s)
		var stump := Assets.spawn("nat/stump", s, Vector3.ZERO, randf() * 360.0, 3.2)
		stump.name = "Stump"
		var hole := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.5
		cm.bottom_radius = 0.5
		cm.height = 0.05
		cm.material = WorldKit.mat(Color(0.12, 0.07, 0.04), 1.0)
		hole.mesh = cm
		hole.position = Vector3(0, 1.62, 0)
		s.add_child(hole)
		var leaf := Assets.spawn("plat/flowers", s, Vector3(0.7, 1.6, 0.3), 0.0, 0.9)
		leaf.name = "Leaf"
		s.position = _slot_pos(k)
		stumps.append(s)
	for i in 4:
		var mk := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.75
		tm.outer_radius = 0.9
		tm.material = WorldKit.mat(Game.player_color(i), 0.4, 1.0)
		mk.mesh = tm
		mk.visible = false
		world.add_child(mk)
		_markers.append(mk)
	for i in 16:
		var a := TAU * i / 16.0
		WorldKit.place(world, ["nat/tree_oak", "nat/tree_pine", "plat/mushrooms", "nat/bush"][i % 4], Vector3(cos(a), 0, sin(a)) * 10.5, randf() * 360.0, 2.2)


func _slot_pos(k: int) -> Vector3:
	return Vector3((k - (N - 1) * 0.5) * SPACING, 0, -1.5)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 1.0, 0)
	c.offset = Vector3(0, 8.5, 11.5)
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
	order = [0, 1, 2, 3, 4]
	for k in N:
		stumps[k].position = _slot_pos(k)
	hidden_id = rng.randi() % N
	phase = "hide"
	_t = 1.6
	for i in 4:
		_locked[i] = i == solo_slot or not active[i]
		_pick[i] = -1
		_markers[i].visible = false
		_cpu_t[i] = randf_range(0.6, 1.4)
	var sav := avatars[solo_slot] as PartyAvatar
	sav.visible = true
	sav.global_position = _slot_pos(hidden_id) + Vector3(0, 0, 1.6)
	var tw := sav.create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(sav, "global_position", _slot_pos(hidden_id) + Vector3.UP * 3.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sav, "global_position", _slot_pos(hidden_id) + Vector3.UP * 0.4, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		sav.visible = false
		Audio.sfx("drop", stumps[hidden_id].position, -2.0)
		Juice.squash(stumps[hidden_id], 1.2, 0.8, 0.3))
	CutsceneManager.big_word("Runde %d" % _round, Color.WHITE, 0.4)


func on_tick(delta: float) -> void:
	_t -= delta
	match phase:
		"hide":
			if _t <= 0.0:
				phase = "shuffle"
				_t = 5.0
				_swaps = 0
				CutsceneManager.big_word("Durcheinander!", UI.GOLD, 0.3)
		"shuffle":
			_swap_cd -= delta
			var mv := InputHub.move(solo_slot)
			if _swap_cd <= 0.0 and absf(mv.x) > 0.6:
				var at := rng.randi() % (N - 1)
				_swap(at, at + 1)
				_swap_cd = maxf(0.16, 0.34 - _swaps * 0.01)
			if _t <= 0.0:
				phase = "pick"
				_t = 6.0
				CutsceneManager.big_word("Wo steckt es?", UI.GOLD, 0.3)
				for i in 4:
					_markers[i].visible = not _locked[i]
		"pick":
			for i in active_slots():
				if _locked[i]:
					continue
				var mv2 := InputHub.move(i)
				var mem := cpu_mem[i]
				if absf(mv2.x) > 0.6 and float(mem.get("cd", 0.0)) <= 0.0:
					_cursor[i] = clampi(_cursor[i] + (1 if mv2.x > 0 else -1), 0, N - 1)
					mem["cd"] = 0.18
					Audio.sfx("ui_move", null, -10.0)
				mem["cd"] = float(mem.get("cd", 0.0)) - delta
				if InputHub.pressed(i, "a"):
					_locked[i] = true
					_pick[i] = _cursor[i]
					Audio.sfx("ui_confirm", null, -6.0)
					(avatars[i] as PartyAvatar).rig.react("determined")
				_markers[i].position = _slot_pos(_cursor[i]) + Vector3(0, 2.6 + (i % 4) * 0.25, 0)
				_markers[i].rotation.x = PI * 0.5
			var all := true
			for i in active_slots():
				if not _locked[i]:
					all = false
			if all or _t <= 0.0:
				for i in active_slots():
					if not _locked[i]:
						_locked[i] = true
						_pick[i] = _cursor[i]
				phase = "reveal"
				_t = 99.0
				_reveal()


func _swap(a: int, b: int) -> void:
	var ia := order[a]
	var ib := order[b]
	order[a] = ib
	order[b] = ia
	_swaps += 1
	var sa := stumps[ia]
	var sb := stumps[ib]
	var pa := _slot_pos(b)
	var pb := _slot_pos(a)
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(t: float) -> void: sa.position = _slot_pos(a).lerp(pa, t) + Vector3(0, sin(t * PI) * 0.6, sin(t * PI) * 1.2), 0.0, 1.0, 0.16)
	tw.tween_method(func(t: float) -> void: sb.position = _slot_pos(b).lerp(pb, t) + Vector3(0, sin(t * PI) * 0.6, -sin(t * PI) * 1.2), 0.0, 1.0, 0.16)
	Audio.sfx("whoosh", null, -10.0, 1.4)


func _reveal() -> void:
	var hidden_pos := order.find(hidden_id)
	var found := false
	for i in active_slots():
		if i != solo_slot and _pick[i] == hidden_pos:
			found = true
	await get_tree().create_timer(0.6, false).timeout
	for k in N:
		var s := stumps[order[k]]
		var tw := s.create_tween()
		tw.tween_property(s, "position:y", 1.6, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Audio.sfx("pop", s.position, -6.0, 1.0 + k * 0.08)
		await get_tree().create_timer(0.22, false).timeout
	var sav := avatars[solo_slot] as PartyAvatar
	sav.visible = true
	sav.global_position = _slot_pos(hidden_pos) + Vector3.UP * 0.2
	if found:
		team_pts[1] += 1
		sav.rig.react("shocked")
		for i in active_slots():
			if i != solo_slot and _pick[i] == hidden_pos:
				(avatars[i] as PartyAvatar).rig.react("cheer")
				FX.confetti(_slot_pos(hidden_pos) + Vector3.UP * 2.0, 30)
		Juice.float_text(self, sav.global_position + Vector3.UP * 3.0, "Gefunden!", TEAM_COLORS[1], 110)
	else:
		team_pts[0] += 1
		sav.rig.react("laugh")
		Juice.float_text(self, sav.global_position + Vector3.UP * 3.0, "Nicht gefunden!", TEAM_COLORS[0], 110)
	for i in 4:
		scores[i] = float(team_pts[teams[i]])
	await get_tree().create_timer(1.6, false).timeout
	for k in N:
		stumps[order[k]].create_tween().tween_property(stumps[order[k]], "position:y", 0.0, 0.2)
	if team_pts[0] >= 2 or team_pts[1] >= 2 or _round >= 3:
		end_game()
	else:
		_new_round()


func team_result() -> int:
	return 0 if team_pts[0] > team_pts[1] else 1


func net_pack() -> Dictionary:
	var pos: Array = []
	for s in stumps:
		pos.append([snappedf(s.position.x, 0.01), snappedf(s.position.y, 0.01), snappedf(s.position.z, 0.01)])
	return {"ph": phase, "st": pos, "cu": _cursor, "lk": _locked, "tp": team_pts, "sv": (avatars[solo_slot] as Node3D).visible}


func net_unpack(d: Dictionary) -> void:
	var pos: Array = d.get("st", [])
	for k in mini(N, pos.size()):
		stumps[k].position = Vector3(float(pos[k][0]), float(pos[k][1]), float(pos[k][2]))
	var cu: Array = d.get("cu", _cursor)
	var lk: Array = d.get("lk", _locked)
	phase = String(d.get("ph", phase))
	for i in 4:
		_cursor[i] = int(cu[i])
		_markers[i].visible = phase == "pick" and not bool(lk[i])
		_markers[i].position = _slot_pos(_cursor[i]) + Vector3(0, 2.6 + i * 0.25, 0)
		_markers[i].rotation.x = PI * 0.5
	(avatars[solo_slot] as Node3D).visible = bool(d.get("sv", true))


func cpu_think(slot: int, delta: float) -> void:
	var level: int = Game.players[slot].cpu_level
	var mv := Vector2.ZERO
	var held := {}
	if slot == solo_slot:
		if phase == "shuffle":
			mv.x = 1.0 if randf() < 0.5 else -1.0
	elif phase == "pick" and not _locked[slot]:
		_cpu_t[slot] -= delta
		if float(cpu_mem[slot].get("g", -1)) < 0.0:
			# Gutes Auge: mit Wahrscheinlichkeit richtig mitverfolgt, sonst geraten
			var track_ok := randf() < clampf([0.35, 0.5, 0.7][level] - _swaps * 0.012, 0.15, 0.8)
			cpu_mem[slot]["g"] = order.find(hidden_id) if track_ok else randi() % N
		var g := int(cpu_mem[slot].g)
		if _cursor[slot] != g:
			mv.x = 1.0 if g > _cursor[slot] else -1.0
		elif _cpu_t[slot] <= 0.0:
			held["a"] = true
			cpu_mem[slot]["g"] = -1
	InputHub.set_virtual(slot, mv, held)
