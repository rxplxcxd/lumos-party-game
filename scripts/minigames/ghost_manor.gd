extends MinigameBase
## Spukvilla-Sprint (Rennen, jeder gegen jeden): Drei Räume, in jeder Rückwand drei Türen – nur eine führt
## weiter. A vor einer Tür = öffnen. Falsche Tür: Ein Gespenst springt heraus und wirft dich zurück. Die richtige
## Tür bleibt kurz offen – wer aufpasst, sieht, wo die anderen durchkommen. Dazu schweben Geister durch die Räume.
## Wer zuerst aus dem letzten Raum entkommt, gewinnt.
## Online: Host-Modell.

const ROOMS := 3
const DEPTH := 7.5
const HALF_X := 5.0
const DOOR_X := [-3.0, 0.0, 3.0]

var _right: Array[int] = []
var _doors: Array = []                 # [raum][tür] = {body, cs, mesh, open_t, known}
var _ghosts: Array[Dictionary] = []    # {node, pos, room, speed}
var _room: Array[int] = [0, 0, 0, 0]
var _cd: Array[float] = [0, 0, 0, 0]
var _known: Dictionary = {}            # "r:d" -> true (richtig) / false (Geist)


func _init() -> void:
	game_id = "ghost_manor"
	env_preset = "mansion"
	backdrop_style = "night"
	time_limit = 60.0
	race = true
	score_format = "Raum %d"
	arena_radius = 9.0
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 6)
	net_model = "host"
	spawn_points = [Vector3(-3, 0.6, 2.5), Vector3(-1, 0.6, 2.5), Vector3(1, 0.6, 2.5), Vector3(3, 0.6, 2.5)]


func _wall_z(k: int) -> float:
	return -DEPTH * (k + 1) + DEPTH * 0.5


func build_arena() -> void:
	WorldKit.box(world, Vector3(HALF_X * 2 + 1, 0.4, DEPTH * ROOMS + 8), Vector3(0, -0.2, -DEPTH * ROOMS * 0.5 + 2.5), Color("#5a3d5c"))
	for z in range(-int(DEPTH * ROOMS) - 2, 6, 2):
		WorldKit.box(world, Vector3(HALF_X * 2, 0.02, 0.9), Vector3(0, 0.01, z), Color("#6e4a6e"), false)
	for side in [-1.0, 1.0]:
		WorldKit.box(world, Vector3(0.4, 3.2, DEPTH * ROOMS + 8), Vector3(side * (HALF_X + 0.2), 1.6, -DEPTH * ROOMS * 0.5 + 2.5), Color("#3b2a4a"))
	WorldKit.box(world, Vector3(HALF_X * 2 + 1, 3.2, 0.4), Vector3(0, 1.6, 6.0), Color("#3b2a4a"))
	for k in ROOMS:
		_right.append(rng.randi() % 3)
		var wz := _wall_z(k)
		# Rückwand mit drei Türöffnungen (je 1,6 m breit)
		var edges := [-HALF_X, -3.8, -2.2, -0.8, 0.8, 2.2, 3.8, HALF_X]
		for e in range(0, edges.size(), 2):
			var x0: float = edges[e]
			var x1: float = edges[e + 1]
			WorldKit.box(world, Vector3(x1 - x0, 3.2, 0.4), Vector3((x0 + x1) * 0.5, 1.6, wz), Color("#4a3358"))
		var row: Array = []
		for d in 3:
			var body := StaticBody3D.new()
			world.add_child(body)
			body.position = Vector3(DOOR_X[d], 1.15, wz)
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(1.6, 2.3, 0.3)
			cs.shape = bs
			body.add_child(cs)
			var hinge := Node3D.new()
			world.add_child(hinge)
			hinge.position = Vector3(DOOR_X[d] - 0.8, 1.15, wz)
			var panel := WorldKit.box(hinge, Vector3(1.56, 2.26, 0.16), Vector3(0.78, 0, 0), Color("#8a5a34"), false)
			WorldKit.box(panel, Vector3(1.2, 0.08, 0.18), Vector3(0, 0.5, 0), Color("#6b4426"), false)
			WorldKit.cylinder(panel, 0.08, 0.06, Vector3(0.55, -0.1, 0.12), Color("#ffd166"), false).rotation.x = PI / 2.0
			row.append({"body": body, "cs": cs, "hinge": hinge, "open_t": 0.0, "panel": panel})
		_doors.append(row)
		# Raumdeko: Kerzenleuchter, Gemälde, Spinnweben-Ecken, Kürbisse
		var rz := wz + DEPTH * 0.5
		WorldKit.torch_light(world, Vector3(-HALF_X + 0.4, 2.2, rz), Color(0.8, 0.5, 1.0), 1.4, 7.0)
		for s in [-1.0, 1.0]:
			WorldKit.box(world, Vector3(0.06, 1.0, 1.4), Vector3(s * (HALF_X - 0.02), 1.9, rz + 1.0), Color("#d8a64a"), false)
			WorldKit.box(world, Vector3(0.07, 0.8, 1.2), Vector3(s * (HALF_X - 0.03), 1.9, rz + 1.0), Color("#2c3e6a"), false)
		WorldKit.place(world, "npc/ghost", Vector3(4.0, 0.0, rz - 1.5), randf() * 360.0, 0.6).visible = false
		_ghosts.append({"node": Assets.spawn("npc/ghost", world, Vector3(0, 0.6, rz), 0.0, 1.0), "pos": Vector3(rng.randf_range(-3, 3), 0, rz), "room": k, "speed": 1.1 + k * 0.25})
	var exit := MgKit.ring(world, 1.6, 0.12, Color(1.0, 0.85, 0.3), 1.6)
	exit.position = Vector3(0, 0.03, _wall_z(ROOMS - 1) - 2.0)


func setup_camera(c: ArenaCamera) -> void:
	c.follow = true
	c.center_weight = 0.0
	c.offset = Vector3(0, 13.0, 9.5)
	c.min_dist = 0.95
	c.max_dist = 1.2
	c.spread_ref = 12.0


func on_start() -> void:
	for av in avatars:
		if av:
			(av as PartyAvatar).can_jump = false
			(av as PartyAvatar).can_shove = false


func check_end() -> bool:
	return not finish_order.is_empty()


func on_tick(delta: float) -> void:
	for i in active_slots():
		_cd[i] = maxf(0.0, _cd[i] - delta)
		var av := avatars[i] as PartyAvatar
		var z := av.global_position.z
		var r := 0
		while r < ROOMS and z < _wall_z(r) - 0.3:
			r += 1
		if r > _room[i]:
			_room[i] = r
			add_score(i, 1.0)
			if r >= ROOMS and not (i in finish_order):
				finish_player(i)
		if InputHub.pressed(i, "a") and _cd[i] <= 0.0:
			_try_door(i)
	for k in ROOMS:
		for d in 3:
			var dr: Dictionary = _doors[k][d]
			if float(dr.open_t) > 0.0:
				dr.open_t = float(dr.open_t) - delta
				if float(dr.open_t) <= 0.0 and _door_clear(k, d):
					_set_door(k, d, false)
				elif float(dr.open_t) <= 0.0:
					dr.open_t = 0.3
	_move_ghosts(delta)


func _door_clear(k: int, d: int) -> bool:
	var p := Vector3(DOOR_X[d], 0, _wall_z(k))
	for i in active_slots():
		if Vector2((avatars[i] as PartyAvatar).global_position.x - p.x, (avatars[i] as PartyAvatar).global_position.z - p.z).length() < 1.2:
			return false
	return true


func _set_door(k: int, d: int, open: bool) -> void:
	var dr: Dictionary = _doors[k][d]
	(dr.cs as CollisionShape3D).set_deferred("disabled", open)
	var h: Node3D = dr.hinge
	h.create_tween().tween_property(h, "rotation:y", 1.7 if open else 0.0, 0.3).set_trans(Tween.TRANS_BACK)
	Audio.sfx("door", h.global_position, -4.0)


func _try_door(i: int) -> void:
	var av := avatars[i] as PartyAvatar
	var p := av.global_position
	_cd[i] = 0.6
	for k in ROOMS:
		var wz := _wall_z(k)
		if absf(p.z - wz) > 1.6 or p.z < wz:
			continue
		for d in 3:
			if absf(p.x - DOOR_X[d]) > 0.95 or float(_doors[k][d].open_t) > 0.0:
				continue
			av.rig.play_once("interact", "idle", 1.6)
			if d == _right[k]:
				_doors[k][d].open_t = 4.0
				_set_door(k, d, true)
				_known["%d:%d" % [k, d]] = true
				Audio.sfx("chime", Vector3(DOOR_X[d], 1, wz), -4.0)
			else:
				_known["%d:%d" % [k, d]] = false
				var g := Assets.spawn("npc/ghost", world, Vector3(DOOR_X[d], 0.6, wz + 0.3), 0.0, 1.3)
				var tw := g.create_tween()
				tw.tween_property(g, "position", Vector3(DOOR_X[d], 1.8, wz + 1.6), 0.25).set_trans(Tween.TRANS_BACK)
				tw.tween_interval(0.5)
				tw.tween_property(g, "scale", Vector3.ONE * 0.01, 0.2)
				tw.tween_callback(g.queue_free)
				av.apply_knockback(Vector3(randf_range(-0.3, 0.3), 0, 1).normalized(), 10.0, 1.1, 4.0)
				av.rig.react("scared")
				Audio.sfx("ghost", av.global_position)
				Juice.shake(0.2)
			return


func _move_ghosts(delta: float) -> void:
	for g in _ghosts:
		var target := Vector3.INF
		var bd := INF
		for i in active_slots():
			if _room[i] != int(g.room):
				continue
			var ap := (avatars[i] as PartyAvatar).global_position
			var dd := ap.distance_to(g.pos as Vector3)
			if dd < bd:
				bd = dd
				target = ap
		var p: Vector3 = g.pos
		var rz := _wall_z(int(g.room)) + DEPTH * 0.5
		var tt := time_limit - time_left
		var want := target if target != Vector3.INF else Vector3(sin(tt * 0.7 + int(g.room)) * 3.0, 0, rz)
		var dir := want - p
		dir.y = 0.0
		p += dir.normalized() * minf(float(g.speed) * delta, dir.length())
		p.z = clampf(p.z, _wall_z(int(g.room)) + 0.8, _wall_z(int(g.room)) + DEPTH - 0.8)
		g.pos = p
		var node: Node3D = g.node
		node.position = p + Vector3(0, 0.6 + sin(tt * 3.0 + int(g.room)) * 0.2, 0)
		if dir.length() > 0.1:
			node.rotation.y = atan2(dir.x, dir.z)
		for i in active_slots():
			var av := avatars[i] as PartyAvatar
			var off := av.global_position - p
			off.y = 0.0
			if off.length() < 0.9 and _cd[i] < 0.3:
				_cd[i] = 1.2
				av.apply_knockback(off.normalized() if off.length() > 0.05 else Vector3.BACK, 8.0, 0.8, 3.0)
				av.rig.react("scared")
				Audio.sfx("ghost", av.global_position, -4.0)


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	var doors := []
	for k in ROOMS:
		for dd in 3:
			doors.append(1 if float(_doors[k][dd].open_t) > 0.0 else 0)
	d["gm"] = [doors, _ghosts.map(func(g: Dictionary) -> Array: return [snappedf((g.pos as Vector3).x, 0.02), snappedf((g.pos as Vector3).z, 0.02)])]
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var e: Array = d.get("gm", [])
	if e.size() < 2:
		return
	var doors: Array = e[0]
	for k in ROOMS:
		for dd in 3:
			var open := int(doors[k * 3 + dd]) == 1
			var was := float(_doors[k][dd].open_t) > 0.0
			if open != was:
				_doors[k][dd].open_t = 9.0 if open else 0.0
				_set_door(k, dd, open)
	for g in mini(_ghosts.size(), (e[1] as Array).size()):
		_ghosts[g].pos = Vector3(float(e[1][g][0]), 0, float(e[1][g][1]))
		(_ghosts[g].node as Node3D).position = (_ghosts[g].pos as Vector3) + Vector3(0, 0.6, 0)


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	var level: int = Game.players[slot].cpu_level
	var mem: Dictionary = cpu_mem[slot]
	var p := av.global_position
	var r := mini(_room[slot], ROOMS - 1)
	var held := {}
	if _room[slot] >= ROOMS:
		InputHub.set_virtual(slot, Vector2(0, -1))
		return
	var wz := _wall_z(r)
	# Tür wählen: offene oder bekannte richtige Tür (andere beobachtet → Stufe bestimmt, wie gut man aufpasst),
	# sonst eine noch nicht bekannte falsche ausschließen
	var key := "pick%d" % r
	if not mem.has(key) or (_known.get("%d:%d" % [r, int(mem[key])], true) == false):
		var cand: Array[int] = []
		var sure := -1
		var tried: Array = mem.get("tried%d" % r, [])
		for dd in 3:
			var kn = _known.get("%d:%d" % [r, dd])
			# Eigene Fehlversuche merkt man sich immer, fremde je nach Aufmerksamkeit
			var noticed: bool = dd in tried or randf() < float([0.4, 0.7, 0.95][level])
			if (kn == true or float(_doors[r][dd].open_t) > 0.0) and noticed:
				sure = dd
			elif kn == false and noticed:
				continue
			else:
				cand.append(dd)
		mem[key] = sure if sure >= 0 else (cand[randi() % cand.size()] if not cand.is_empty() else randi() % 3)
	var door := int(mem[key])
	var target := Vector3(DOOR_X[door], 0, wz + 0.9)
	if float(_doors[r][door].open_t) > 0.0:
		target = Vector3(DOOR_X[door], 0, wz - 1.5)
	var to := Vector2(target.x - p.x, target.z - p.z)
	var mv := to.normalized() * clampf(to.length(), 0.0, 1.0)
	# Geister meiden
	for g in _ghosts:
		var off := Vector2(p.x - (g.pos as Vector3).x, p.z - (g.pos as Vector3).z)
		if off.length() < [1.4, 1.9, 2.4][level]:
			mv = (mv + off.normalized() * 1.2).normalized()
	if to.length() < 0.5 and float(_doors[r][door].open_t) <= 0.0 and randf() < 0.3:
		held["a"] = true
		var tl: Array = mem.get("tried%d" % r, [])
		if not door in tl:
			tl.append(door)
		mem["tried%d" % r] = tl
	InputHub.set_virtual(slot, mv, held)
