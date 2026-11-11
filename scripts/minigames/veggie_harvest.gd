extends MinigameBase
## Gemüse-Ernte (2 gegen 2): Auf dem Acker sprießen Karotten, Tomaten und Auberginen. Über jeder Teamkiste
## zeigt ein Schild, welche Sorte gerade gebraucht wird (wechselt alle paar Sekunden). B mehrmals = Gemüse
## herausziehen, dann zur eigenen Kiste tragen: richtige Sorte +1, goldene +3, falsche fliegt zurück.
## A = Rempler – wer gerade etwas trägt, lässt es fallen.
## Online: Host-Modell.

const HALF_X := 7.5
const HALF_Z := 5.0
const PULLS := 3
const KIND_COL := [Color("#ff8c2e"), Color("#ff3b3b"), Color("#8e44ad")]
const KIND_NAME := ["Karotte", "Tomate", "Aubergine"]

var _veg: Array[Dictionary] = []     # {node, pos, kind, gold, pull, carrier, vel}
var _carry: Array[int] = [-1, -1, -1, -1]
var _want := [0, 1]
var _want_t := 10.0
var _signs: Array[Node3D] = []
var _crates := [Vector3(-HALF_X - 0.5, 0, 0), Vector3(HALF_X + 0.5, 0, 0)]
var _spawn_t := 0.3
var _cd: Array[float] = [0, 0, 0, 0]
var _next_id := 0


func _init() -> void:
	game_id = "veggie_harvest"
	env_preset = "day"
	backdrop_style = "meadow"
	time_limit = 45.0
	score_format = "%d"
	arena_radius = 9.0
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 9)
	net_model = "host"
	spawn_points = [Vector3(-4, 0.6, -2), Vector3(4, 0.6, -2), Vector3(-4, 0.6, 2), Vector3(4, 0.6, 2)]


func on_setup() -> void:
	var c := [0, 0]
	for i in 4:
		var t := teams[i]
		spawn_points[i] = Vector3(-5.0 if t == 0 else 5.0, 0.6, -2.0 + c[t] * 4.0)
		c[t] += 1


func build_arena() -> void:
	WorldKit.box(world, Vector3(HALF_X * 2 + 5, 0.4, HALF_Z * 2 + 3), Vector3(0, -0.2, 0), Color("#7cc85a"))
	# Ackerfurchen
	for z in range(-4, 5, 2):
		WorldKit.box(world, Vector3(HALF_X * 2 - 2.0, 0.12, 1.2), Vector3(0, 0.05, z), Color("#8a5a34"), false)
	# Teamkisten mit Wunschschild, Scheune, Vogelscheuche, Maisfeld ringsum
	for t in 2:
		var cp: Vector3 = _crates[t]
		WorldKit.box(world, Vector3(1.8, 0.9, 1.8), cp + Vector3(0, 0.45, 0), Color("#c98a4a"))
		WorldKit.box(world, Vector3(1.9, 0.1, 1.9), cp + Vector3(0, 0.92, 0), Color("#ff4d6d") if t == 0 else Color("#4da6ff"), false)
		var sign := Node3D.new()
		world.add_child(sign)
		sign.position = cp + Vector3(0, 2.6, 0)
		WorldKit.cylinder(world, 0.08, 1.7, cp + Vector3(0, 1.7, -0.7), Color("#7a4f2a"), false)
		_signs.append(sign)
	WorldKit.cottage(world, Vector3(0, 0, -9.5), 0.0, 1.6, Color("#c0392b"))
	WorldKit.place(world, "qn/corn", Vector3(-9, 0, -6), 0.0, 1.2)
	WorldKit.scatter(world, ["qn/corn", "qn/corn_b", "qn/wheat"], 26, Vector3(0, 0, 0), 10.5, 14.0, 0.0)
	WorldKit.place(world, "pet/cow", Vector3(10.5, 0, -5.5), -40.0, 1.4)
	WorldKit.place(world, "pet/chick", Vector3(-10.0, 0, 5.5), 30.0, 1.4)
	_refresh_signs()


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, 0.6)
	c.offset = Vector3(0, 13.5, 10.0)
	c.min_dist = 0.95
	c.max_dist = 1.05


func on_start() -> void:
	for av in avatars:
		if av:
			(av as PartyAvatar).can_shove = false
			(av as PartyAvatar).can_jump = false
			(av as PartyAvatar).rig.surface = "sand"


func _veg_node(kind: int, gold: bool) -> Node3D:
	var n := Node3D.new()
	world.add_child(n)
	var col: Color = KIND_COL[kind] if not gold else Color("#ffd23f")
	match kind:
		0:
			var cone := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.22
			cm.bottom_radius = 0.02
			cm.height = 0.7
			cm.material = WorldKit.mat(col, 0.6, 0.4 if gold else 0.0)
			cone.mesh = cm
			cone.position.y = 0.2
			n.add_child(cone)
		1:
			var sp := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.3
			sm.height = 0.55
			sm.material = WorldKit.mat(col, 0.4, 0.4 if gold else 0.0)
			sp.mesh = sm
			sp.position.y = 0.25
			n.add_child(sp)
		_:
			var cap := MeshInstance3D.new()
			var cpm := CapsuleMesh.new()
			cpm.radius = 0.2
			cpm.height = 0.75
			cpm.material = WorldKit.mat(col, 0.35, 0.4 if gold else 0.0)
			cap.mesh = cpm
			cap.position.y = 0.3
			cap.rotation.z = 0.3
			n.add_child(cap)
	for k in 3:
		var leaf := WorldKit.box(n, Vector3(0.08, 0.35, 0.16), Vector3(0, 0.62, 0), Color("#3fae3a"), false)
		leaf.rotation = Vector3(0.4, k * 2.1, 0.0)
	return n


func _spawn_veg() -> void:
	var p := Vector3(rng.randf_range(-HALF_X + 1.5, HALF_X - 1.5), 0, float(rng.randi_range(-2, 2) * 2))
	for v in _veg:
		if (v.pos as Vector3).distance_to(p) < 1.2:
			return
	var kind := rng.randi() % 3
	var gold := rng.randf() < 0.1
	var n := _veg_node(kind, gold)
	n.position = p + Vector3(0, -0.45, 0)
	n.create_tween().tween_property(n, "position:y", -0.25, 0.4).set_trans(Tween.TRANS_BACK)
	_next_id += 1
	_veg.append({"node": n, "pos": p, "kind": kind, "gold": gold, "pull": 0, "carrier": -1, "vel": Vector3.ZERO, "id": _next_id})


func _refresh_signs() -> void:
	for t in 2:
		var s: Node3D = _signs[t]
		for c in s.get_children():
			c.queue_free()
		var icon := _veg_node(int(_want[t]), false)
		icon.reparent(s, false)
		icon.position = Vector3.ZERO
		icon.scale = Vector3.ONE * 1.6
		var spin := icon.create_tween().set_loops()
		spin.tween_property(icon, "rotation:y", TAU, 3.0).as_relative()


func on_tick(delta: float) -> void:
	_want_t -= delta
	if _want_t <= 0.0:
		_want_t = rng.randf_range(9.0, 13.0)
		for t in 2:
			var nw := rng.randi() % 3
			if nw == int(_want[t]):
				nw = (nw + 1) % 3
			_want[t] = nw
		_refresh_signs()
		Audio.sfx("bell", Vector3.ZERO, -6.0)
		CutsceneManager.big_word("Neue Bestellung!", Color("#fff1a8"), 0.5)
	_spawn_t -= delta
	if _spawn_t <= 0.0 and _veg.size() < 14:
		_spawn_t = 0.55
		_spawn_veg()
	for i in active_slots():
		_cd[i] = maxf(0.0, _cd[i] - delta)
		var av := avatars[i] as PartyAvatar
		var p := av.global_position
		p.x = clampf(p.x, -HALF_X - 1.0, HALF_X + 1.0)
		p.z = clampf(p.z, -HALF_Z, HALF_Z)
		av.global_position = p
		if InputHub.pressed(i, "b") and _carry[i] < 0:
			_pull(i)
		elif InputHub.pressed(i, "a") and _cd[i] <= 0.0:
			_shove(i)
		if _carry[i] >= 0:
			var crate: Vector3 = _crates[teams[i]]
			if Vector2(p.x - crate.x, p.z - crate.z).length() < 1.7:
				_deliver(i)
	_update_veg(delta)


func _veg_by_id(id: int) -> Dictionary:
	for v in _veg:
		if int(v.id) == id:
			return v
	return {}


func _pull(i: int) -> void:
	var av := avatars[i] as PartyAvatar
	var best: Dictionary = {}
	var bd := 1.1
	for v in _veg:
		if int(v.carrier) >= 0:
			continue
		var d := Vector2((v.pos as Vector3).x - av.global_position.x, (v.pos as Vector3).z - av.global_position.z).length()
		if d < bd:
			bd = d
			best = v
	if best.is_empty():
		return
	best.pull = int(best.pull) + 1
	av.rig.play_once("interact", "idle", 2.0)
	FX.dust(best.pos as Vector3, Color(0.55, 0.35, 0.2), 4, 0.5)
	Audio.sfx("step_sand", best.pos as Vector3, -6.0, 1.3)
	if int(best.pull) >= PULLS:
		best.carrier = i
		_carry[i] = int(best.id)
		Audio.sfx("pop", best.pos as Vector3)
		av.rig.react("triumph")


func _shove(i: int) -> void:
	_cd[i] = 0.8
	var av := avatars[i] as PartyAvatar
	av.rig.play_once("punch", "idle", 1.8)
	for j in active_slots():
		if teams[j] == teams[i] or _carry[j] < 0:
			continue
		var o := avatars[j] as PartyAvatar
		var off := o.global_position - av.global_position
		off.y = 0.0
		if off.length() < 1.5:
			o.apply_knockback(off.normalized(), 6.0, 0.4, 3.0)
			_drop(j)
			FX.stars(o.global_position + Vector3.UP * 1.5, Color(1, 1, 0.6), 8)
			Audio.sfx("hit_soft", o.global_position)


func _drop(j: int) -> void:
	var v := _veg_by_id(_carry[j])
	_carry[j] = -1
	if v.is_empty():
		return
	v.carrier = -1
	v.pull = PULLS - 1
	v.vel = Vector3(randf_range(-3, 3), 5.0, randf_range(-3, 3))


func _deliver(i: int) -> void:
	var v := _veg_by_id(_carry[i])
	_carry[i] = -1
	if v.is_empty():
		return
	var crate: Vector3 = _crates[teams[i]]
	if int(v.kind) == int(_want[teams[i]]) or bool(v.gold):
		add_score(i, 3.0 if bool(v.gold) else 1.0, crate + Vector3.UP * 2.0)
		FX.stars(crate + Vector3.UP * 1.2, KIND_COL[int(v.kind)], 10)
		Audio.sfx("coin_chime" if bool(v.gold) else "coin", crate)
		(v.node as Node3D).queue_free()
		_veg.erase(v)
	else:
		Juice.float_text(self, crate + Vector3.UP * 2.0, "Falsch – %s!" % KIND_NAME[int(_want[teams[i]])], Color("#ff8a5c"), 56)
		Audio.sfx("negative", crate, -4.0)
		(avatars[i] as PartyAvatar).rig.react("confused")
		v.carrier = -1
		v.pull = PULLS - 1
		v.vel = Vector3(-signf(crate.x) * 5.0, 6.0, randf_range(-2, 2))
		v.pos = crate + Vector3(-signf(crate.x) * 1.2, 1.0, 0)


func _update_veg(delta: float) -> void:
	for v in _veg:
		var n: Node3D = v.node
		if int(v.carrier) >= 0:
			var av := avatars[int(v.carrier)] as PartyAvatar
			v.pos = av.global_position + Vector3(0, 2.0, 0)
			n.position = v.pos
			n.rotation.y += delta * 3.0
		else:
			var vel: Vector3 = v.vel
			if vel.length() > 0.01 or (v.pos as Vector3).y > 0.0:
				vel.y -= 20.0 * delta
				var p: Vector3 = (v.pos as Vector3) + vel * delta
				if p.y <= 0.0:
					p.y = 0.0
					vel = Vector3.ZERO
				p.x = clampf(p.x, -HALF_X, HALF_X)
				p.z = clampf(p.z, -HALF_Z + 0.5, HALF_Z - 0.5)
				v.pos = p
				v.vel = vel
			n.position = (v.pos as Vector3) + Vector3(0, -0.25 + int(v.pull) * 0.08, 0)
			n.rotation.z = sin((time_limit - time_left) * 18.0) * 0.08 * int(v.pull)


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	d["v"] = _veg.map(func(v: Dictionary) -> Array: return [int(v.id), int(v.kind), 1 if bool(v.gold) else 0, snappedf((v.pos as Vector3).x, 0.02), snappedf((v.pos as Vector3).y, 0.02), snappedf((v.pos as Vector3).z, 0.02), int(v.pull), int(v.carrier)])
	d["w"] = _want.duplicate()
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var w: Array = d.get("w", [])
	if w.size() == 2 and (int(w[0]) != int(_want[0]) or int(w[1]) != int(_want[1])):
		_want = [int(w[0]), int(w[1])]
		_refresh_signs()
	var seen := {}
	for e in d.get("v", []):
		seen[int(e[0])] = e
	var k := _veg.size() - 1
	while k >= 0:
		if not seen.has(int(_veg[k].id)):
			FX.stars(_veg[k].pos as Vector3, Color(1, 0.9, 0.4), 6)
			(_veg[k].node as Node3D).queue_free()
			_veg.remove_at(k)
		k -= 1
	for id in seen:
		var e: Array = seen[id]
		var v := _veg_by_id(int(id))
		if v.is_empty():
			var n := _veg_node(int(e[1]), int(e[2]) == 1)
			v = {"node": n, "pos": Vector3.ZERO, "kind": int(e[1]), "gold": int(e[2]) == 1, "pull": 0, "carrier": -1, "vel": Vector3.ZERO, "id": int(id)}
			_veg.append(v)
		v.pos = Vector3(float(e[3]), float(e[4]), float(e[5]))
		v.pull = int(e[6])
		v.carrier = int(e[7])
		(v.node as Node3D).position = (v.pos as Vector3) + (Vector3.ZERO if int(v.carrier) >= 0 else Vector3(0, -0.25 + int(v.pull) * 0.08, 0))


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	var level: int = Game.players[slot].cpu_level
	var mem: Dictionary = cpu_mem[slot]
	var p := av.global_position
	var held := {}
	var target := p
	if _carry[slot] >= 0:
		target = _crates[teams[slot]]
	else:
		var want := int(_want[teams[slot]])
		var bd := INF
		for v in _veg:
			if int(v.carrier) >= 0:
				continue
			var ok := int(v.kind) == want or bool(v.gold) or (level == 0 and randf() < 0.002)
			if not ok:
				continue
			var d := (v.pos as Vector3).distance_to(p) - (3.0 if bool(v.gold) else 0.0)
			if d < bd:
				bd = d
				target = v.pos
		if bd < 0.9:
			mem["acc"] = float(mem.get("acc", 0.0)) + [4.0, 6.0, 8.0][level] / 60.0
			if float(mem.acc) >= 1.0:
				mem.acc = float(mem.acc) - 1.0
				held["b"] = true
		# Gegnerischer Träger in Reichweite? Rempeln (Profis öfter)
		for j in active_slots():
			if teams[j] != teams[slot] and _carry[j] >= 0 and (avatars[j] as PartyAvatar).global_position.distance_to(p) < 1.4 and randf() < [0.02, 0.06, 0.12][level]:
				held["a"] = true
	var to := Vector2(target.x - p.x, target.z - p.z)
	InputHub.set_virtual(slot, to.normalized() * clampf(to.length() * 1.5, 0.0, 1.0), held)
