extends MinigameBase
## Achterbahn-Schießbude (jeder gegen jeden): Alle sitzen im selben Achterbahnwagen, der eine Runde über den
## Jahrmarkt dreht. Links und rechts klappen Pappziele hoch (Geister, Ballons, seltene Goldsterne). Jeder steuert
## sein eigenes Fadenkreuz (Stick) und schießt mit A – wer zuerst trifft, bekommt den Punkt (Goldstern +3).
## Online: Host-Modell (Host wertet Treffer aus, Fadenkreuze werden mitgeschickt).

const LOOP_T := 42.0
const SHOT_CD := 0.32
const RET_SPEED := 0.75     # Bildschirmbreiten pro Sekunde

var _curve := Curve3D.new()
var _len := 1.0
var _cart: Node3D
var _prog := 0.0
var _targets: Array[Dictionary] = []   # {node, board, at (Weg-Offset), state 0=unten 1=oben 2=getroffen, t, gold, r}
var _ret: Array[Vector2] = [Vector2(0.35, 0.5), Vector2(0.45, 0.5), Vector2(0.55, 0.5), Vector2(0.65, 0.5)]
var _ret_nodes: Array[Control] = []
var _cd: Array[float] = [0, 0, 0, 0]
var _layer: CanvasLayer


func _init() -> void:
	game_id = "coaster_shooter"
	env_preset = "sunset"
	backdrop_style = "meadow"
	time_limit = LOOP_T
	score_format = "%d Treffer"
	arena_radius = 18.0
	teaser_height = 3.0
	cannon_pos = Vector3(0, 0, 0)
	net_model = "host"
	spawn_points = [Vector3(16, 1.6, -0.6), Vector3(16, 1.6, 0.6), Vector3(16, 1.6, -1.8), Vector3(16, 1.6, 1.8)]


func build_arena() -> void:
	WorldKit.box(world, Vector3(60, 0.4, 60), Vector3(0, -0.2, 0), Color("#7cc85a"))
	# Bahn: Rundkurs mit Hügeln
	for k in 16:
		var a := TAU * k / 16.0
		var r := 16.0 + sin(a * 3.0) * 2.5
		_curve.add_point(Vector3(cos(a) * r, 2.0 + maxf(0.0, sin(a * 2.0 + 0.6)) * 3.5, sin(a) * r))
	_curve.add_point(_curve.get_point_position(0))
	for k in _curve.point_count:
		var pp := _curve.get_point_position((k - 1 + _curve.point_count) % _curve.point_count)
		var np := _curve.get_point_position((k + 1) % _curve.point_count)
		var tan := (np - pp) * 0.18
		_curve.set_point_in(k, -tan)
		_curve.set_point_out(k, tan)
	_len = _curve.get_baked_length()
	# Schienen und Stützen
	var d := 0.0
	while d < _len:
		var p := _curve.sample_baked(d)
		var p2 := _curve.sample_baked(minf(d + 1.0, _len))
		var tie := WorldKit.box(world, Vector3(1.6, 0.12, 0.35), p, Color("#8a5a34"), false)
		tie.look_at(p2 if p2.distance_to(p) > 0.01 else p + Vector3.FORWARD, Vector3.UP)
		if int(d) % 4 == 0:
			WorldKit.cylinder(world, 0.12, p.y, Vector3(p.x, p.y * 0.5 - 0.1, p.z), Color("#d9d9e0"), false)
		d += 1.0
	# Wagen mit vier Sitzen
	_cart = Node3D.new()
	_cart.set_meta("keep_visible", true)
	world.add_child(_cart)
	WorldKit.box(_cart, Vector3(1.8, 0.6, 3.6), Vector3(0, 0.3, 0), Color("#ff4d6d"), false)
	WorldKit.box(_cart, Vector3(1.9, 0.15, 3.7), Vector3(0, 0.62, 0), Color("#ffd166"), false)
	# Ziele entlang der Strecke (gemeinsamer Zufall)
	var at := 12.0
	while at < _len - 8.0:
		var cp := _curve.sample_baked(at)
		var fw := (_curve.sample_baked(at + 1.0) - cp).normalized()
		var side := Vector3(-fw.z, 0, fw.x) * (1.0 if rng.randf() < 0.5 else -1.0)
		var gold := rng.randf() < 0.14
		var pos := cp + side * rng.randf_range(3.5, 6.5) + Vector3(0, -cp.y + rng.randf_range(0.0, 2.5), 0)
		var holder := Node3D.new()
		world.add_child(holder)
		holder.position = pos
		WorldKit.cylinder(holder, 0.06, 1.4, Vector3(0, 0.7, 0), Color("#7a4f2a"), false)
		var board := Node3D.new()
		holder.add_child(board)
		board.position = Vector3(0, 1.4, 0)
		var r := 0.55 if gold else 0.75
		var disc := WorldKit.cylinder(board, r, 0.1, Vector3(0, r, 0), Color("#ffd23f") if gold else [Color("#ffffff"), Color("#ff8fab"), Color("#8be9ff")][rng.randi() % 3], false)
		disc.rotation.x = PI / 2.0
		WorldKit.cylinder(board, r * 0.45, 0.12, Vector3(0, r, 0.02), Color("#e8425a"), false).rotation.x = PI / 2.0
		if gold:
			WorldKit.place(board, "qp/star", Vector3(0, r, 0.1), 0.0, 0.4)
		board.rotation.x = -PI / 2.0
		holder.look_at(Vector3(cp.x, pos.y, cp.z), Vector3.UP)
		_targets.append({"node": holder, "board": board, "at": at, "state": 0, "t": 0.0, "gold": gold, "r": r})
		at += rng.randf_range(4.5, 7.5)
	# Jahrmarkt: Riesenrad-Andeutung, Zelte, Laternen, Ballons
	for i in 8:
		var a2 := TAU * i / 8.0 + 0.3
		WorldKit.place(world, ["race/tent", "town/lantern", "qp/tree_fruit", "race/tent_closed"][i % 4], Vector3(cos(a2) * 9.0, 0, sin(a2) * 9.0), rad_to_deg(-a2), [1.4, 1.2, 0.35, 1.4][i % 4])
	var wheel := Node3D.new()
	world.add_child(wheel)
	wheel.position = Vector3(0, 7.0, 0)
	var rim := MgKit.ring(wheel, 6.0, 0.3, Color("#ffd166"), 0.8)
	rim.rotation.x = PI / 2.0
	for k in 8:
		var spoke := WorldKit.box(wheel, Vector3(0.15, 12.0, 0.15), Vector3.ZERO, Color("#ffffff"), false)
		spoke.rotation.z = TAU * k / 16.0
	var wt := wheel.create_tween().set_loops()
	wt.tween_property(wheel, "rotation:z", TAU, 30.0).as_relative()
	WorldKit.cylinder(world, 0.4, 7.0, Vector3(0, 3.5, -0.6), Color("#d9d9e0"), false)


func setup_camera(c: ArenaCamera) -> void:
	c.follow = false
	c.fixed_center = Vector3(16, 2, 0)
	c.offset = Vector3(0, 4, 8)
	c.min_dist = 1.0
	c.max_dist = 1.0
	c.smooth = 5.0


func on_start() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	for i in 4:
		var rc := TextureRect.new()
		rc.texture = UI.icon_tex("target", 56, Game.player_color(i).lightened(0.25))
		rc.size = Vector2(56, 56)
		rc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rc.visible = active[i]
		_layer.add_child(rc)
		_ret_nodes.append(rc)
	for i in active_slots():
		var av := avatars[i] as PartyAvatar
		av.freeze(true)
		av.can_shove = false
		av.set_physics_process(false)
		av.rig.play("sit_chair", 0.1)
		av.rig.scale *= 0.7


func on_tick(delta: float) -> void:
	_prog = minf(_prog + _len / LOOP_T * delta, _len - 0.5)
	var p := _curve.sample_baked(_prog)
	var fw := (_curve.sample_baked(minf(_prog + 1.0, _len)) - p).normalized()
	_cart.position = p
	_cart.look_at(p + fw, Vector3.UP)
	var right := fw.cross(Vector3.UP).normalized()
	var k := 0
	for i in active_slots():
		var seat := p + right * (-0.45 if k % 2 == 0 else 0.45) + fw * (0.8 - (k / 2) * 1.6) + Vector3.UP * 0.55
		(avatars[i] as PartyAvatar).global_position = seat
		(avatars[i] as PartyAvatar).rig.rotation.y = atan2(fw.x, fw.z)
		k += 1
	if is_instance_valid(cam):
		cam.fixed_center = p + fw * 3.0
		cam.offset = -fw * 8.5 + Vector3.UP * 4.5
	# Ziele hoch- und runterklappen
	for t in _targets:
		var ahead := float(t.at) - _prog
		if int(t.state) == 0 and ahead < 16.0 and ahead > -2.0:
			t.state = 1
			t.t = 0.0
			Audio.sfx("whoosh", (t.node as Node3D).position, -12.0, 1.4)
		elif int(t.state) == 1:
			t.t = float(t.t) + delta
			if ahead < -6.0:
				t.state = 3
		var board: Node3D = t.board
		var want := 0.0 if int(t.state) == 1 else -PI / 2.0
		board.rotation.x = lerpf(board.rotation.x, want, minf(1.0, delta * 10.0))
	# Fadenkreuze und Schüsse
	for i in active_slots():
		_cd[i] = maxf(0.0, _cd[i] - delta)
		_ret[i] = (_ret[i] + InputHub.move(i) * RET_SPEED * delta * Vector2(1.0, 1.6)).clamp(Vector2(0.03, 0.05), Vector2(0.97, 0.95))
		if InputHub.pressed(i, "a") and _cd[i] <= 0.0:
			_shoot(i)
	_draw_ret()


func _screen() -> Vector2:
	return get_viewport().get_visible_rect().size


func _target_screen(t: Dictionary) -> Array:
	var board: Node3D = t.board
	var c3 := board.global_transform * Vector3(0, float(t.r), 0)
	if not is_instance_valid(cam) or cam.is_position_behind(c3):
		return []
	var sc := cam.unproject_position(c3)
	var edge := cam.unproject_position(c3 + cam.global_basis.x * float(t.r))
	return [sc, sc.distance_to(edge)]


func _shoot(i: int) -> void:
	_cd[i] = SHOT_CD
	Audio.sfx("pop", null, -8.0, 1.5)
	var sp := _ret[i] * _screen()
	var best: Dictionary = {}
	var bd := INF
	for t in _targets:
		if int(t.state) != 1:
			continue
		var ts := _target_screen(t)
		if ts.is_empty():
			continue
		var dist := (ts[0] as Vector2).distance_to(sp)
		if dist < float(ts[1]) * 1.1 and dist < bd:
			bd = dist
			best = t
	if best.is_empty():
		return
	best.state = 2
	var pos := (best.board as Node3D).global_position + Vector3.UP * float(best.r)
	add_score(i, 3.0 if bool(best.gold) else 1.0, pos + Vector3.UP * 0.8)
	FX.sparks(pos, Game.player_color(i).lightened(0.3), 14)
	FX.stars(pos, Color(1, 0.95, 0.5), 6 if not bool(best.gold) else 14)
	Audio.sfx("coin_chime" if bool(best.gold) else "punch", pos, -4.0)


func _draw_ret() -> void:
	var ss := _screen()
	for i in 4:
		if i < _ret_nodes.size():
			_ret_nodes[i].position = _ret[i] * ss - Vector2(28, 28)
			_ret_nodes[i].visible = active[i] and state == "play"


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	var st := []
	for t in _targets:
		st.append(int(t.state))
	d["cs"] = [snappedf(_prog, 0.01), _ret.map(func(v: Vector2) -> Array: return [snappedf(v.x, 0.002), snappedf(v.y, 0.002)]), st]
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var e: Array = d.get("cs", [])
	if e.size() < 3:
		return
	_prog = float(e[0])
	for i in mini(4, (e[1] as Array).size()):
		_ret[i] = Vector2(float(e[1][i][0]), float(e[1][i][1]))
	var st: Array = e[2]
	for k in mini(st.size(), _targets.size()):
		if int(st[k]) == 2 and int(_targets[k].state) != 2:
			var pos := (_targets[k].board as Node3D).global_position
			FX.sparks(pos, Color(1, 0.95, 0.5), 12)
			Audio.sfx("punch", pos, -4.0)
		_targets[k].state = int(st[k])
	var p := _curve.sample_baked(_prog)
	var fw := (_curve.sample_baked(minf(_prog + 1.0, _len)) - p).normalized()
	_cart.position = p
	_cart.look_at(p + fw, Vector3.UP)
	if is_instance_valid(cam):
		cam.fixed_center = p + fw * 3.0
		cam.offset = -fw * 8.5 + Vector3.UP * 4.5
	for t in _targets:
		var board: Node3D = t.board
		board.rotation.x = lerpf(board.rotation.x, 0.0 if int(t.state) == 1 else -PI / 2.0, 0.35)
	_draw_ret()


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var level: int = Game.players[slot].cpu_level
	var mem: Dictionary = cpu_mem[slot]
	var ss := _screen()
	var best: Vector2 = Vector2(-1, -1)
	var bd := INF
	var br := 30.0
	for t in _targets:
		if int(t.state) != 1:
			continue
		var ts := _target_screen(t)
		if ts.is_empty():
			continue
		var n: Vector2 = (ts[0] as Vector2) / ss
		if n.x < 0.0 or n.x > 1.0 or n.y < 0.0 or n.y > 1.0:
			continue
		var dist := n.distance_to(_ret[slot]) - (0.15 if bool(t.gold) else 0.0)
		if dist < bd:
			bd = dist
			best = n
			br = float(ts[1])
	var held := {}
	var mv := Vector2.ZERO
	if best.x >= 0.0:
		var to := (best - _ret[slot]) * Vector2(1.0, 1.0 / 1.6)
		mv = (to / maxf(RET_SPEED / 60.0 * 6.0, 0.001)).limit_length(1.0) * Game.lv([0.6, 0.8, 1.0], level)
		mem["aim_t"] = float(mem.get("aim_t", 0.0)) + 1.0 / 60.0
		var px := (best - _ret[slot]).length() * ss.x
		if px < br * 0.8 and float(mem.aim_t) > Game.lv([0.35, 0.2, 0.1], level):
			held["a"] = true
			mem.aim_t = 0.0
	InputHub.set_virtual(slot, mv, held)
