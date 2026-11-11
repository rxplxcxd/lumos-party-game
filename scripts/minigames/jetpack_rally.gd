extends MinigameBase
## Raketen-Rucksack-Rallye: Alle tragen einen Raketenrucksack. A halten = Schub (verbraucht Treibstoff, am Boden
## lädt er nach). In der Luft schweben Sternenringe – durchfliegen gibt Punkte, Goldringe drei. Zwei Gewitterwolken
## ziehen ihre Kreise und schicken nach kurzem Grummeln einen Blitz nach unten: getroffen = kurz betäubt.
## Online: Host-Modell (Host simuliert Schub, Ringe und Blitze).

const ARENA_R := 9.0
const THRUST := 46.0
const MAX_UP := 6.5
const DRAIN := 0.42
const REFILL := 0.7

var _fuel: Array[float] = [1, 1, 1, 1]
var _thrusting: Array[bool] = [false, false, false, false]
var _rings: Array[Dictionary] = []      # {pos, gold, node}
var _packs: Array[Node3D] = []
var _bars: Array[Node3D] = []
var _clouds: Array[Dictionary] = []     # {node, ang, rad, h, speed, t, warn}
var _flame_t := 0.0


func _init() -> void:
	game_id = "jetpack_rally"
	fair_spawns = true   # Startplätze jede Runde neu auslosen (kein fester Platzvorteil)
	env_preset = "sky"
	backdrop_style = "sky_day"
	time_limit = 40.0
	score_format = "%d Pkt."
	arena_radius = 9.5
	teaser_height = 3.0
	cannon_pos = Vector3(0, 0, 12)
	net_model = "host"
	spawn_points = [Vector3(-3, 0.6, -2), Vector3(3, 0.6, -2), Vector3(-3, 0.6, 2.5), Vector3(3, 0.6, 2.5)]


func build_arena() -> void:
	# Schwebende Startinsel mit Landeplätzen, ringsum Wolken und Ballons
	WorldKit.cylinder(world, ARENA_R, 1.0, Vector3(0, -0.5, 0), Color("#8fd16a"))
	WorldKit.cylinder(world, ARENA_R * 0.85, 2.5, Vector3(0, -2.2, 0), Color("#a2784f"), false)
	WorldKit.cylinder(world, ARENA_R * 0.5, 2.0, Vector3(0, -4.2, 0), Color("#8a6440"), false)
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		var pad := WorldKit.cylinder(world, 1.3, 0.12, Vector3(cos(a) * 5.0, 0.06, sin(a) * 5.0), Color("#ffd166"), false)
		MgKit.ring(pad, 1.15, 0.08, Color("#ff9f43"), 0.8).position.y = 0.07
	for i in 10:
		var a2 := TAU * i / 10.0
		var p := Vector3(cos(a2) * randf_range(13.0, 18.0), randf_range(-3.0, 6.0), sin(a2) * randf_range(13.0, 18.0))
		if i % 3 == 0:
			WorldKit.place(world, "plat/block_grass_large", p, randf() * 360.0, randf_range(1.4, 2.0))
		else:
			# Schäfchenwolke aus Kugeln
			var cl := Node3D.new()
			world.add_child(cl)
			cl.position = p
			for b in 4:
				var puff := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = randf_range(0.9, 1.5)
				sm.height = sm.radius * 1.5
				sm.material = WorldKit.mat(Color("#ffffff"), 1.0, 0.15)
				puff.mesh = sm
				puff.position = Vector3((b - 1.5) * 1.1, randf_range(-0.2, 0.4), randf_range(-0.5, 0.5))
				cl.add_child(puff)
			var bob := cl.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
			bob.tween_property(cl, "position:y", p.y + 0.6, 3.0 + i * 0.3)
			bob.tween_property(cl, "position:y", p.y, 3.0 + i * 0.3)
	WorldKit.scatter(world, ["nat/flower_yellow", "nat/flower_red", "nat/bush", "nat/grass"], 14, Vector3.ZERO, 2.0, ARENA_R - 1.0, 0.0)
	for k in 2:
		var cloud := Node3D.new()
		cloud.set_meta("keep_visible", true)
		world.add_child(cloud)
		for b in 5:
			var puff := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = randf_range(0.7, 1.1)
			sm.height = sm.radius * 1.6
			sm.material = WorldKit.mat(Color("#6b6f86"), 0.9)
			puff.mesh = sm
			puff.position = Vector3((b - 2) * 0.75, randf_range(-0.2, 0.3), randf_range(-0.4, 0.4))
			cloud.add_child(puff)
		_clouds.append({"node": cloud, "ang": k * PI, "rad": 5.0, "h": 8.5, "speed": 0.35 if k == 0 else -0.28, "t": 4.0 + k * 2.5, "warn": false})


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 2.5, 0.5)
	c.offset = Vector3(0, 9.0, 16.0)
	c.look_offset = Vector3(0, 2.5, 0)
	c.min_dist = 0.95
	c.max_dist = 1.1


func on_start() -> void:
	for i in 4:
		var av := avatars[i] as PartyAvatar
		if av == null:
			_packs.append(null)
			_bars.append(null)
			continue
		av.can_shove = false
		av.air_control = 1.0
		# Raketenrucksack: Tank in Spielerfarbe, zwei Düsen
		var pack := Node3D.new()
		av.rig.add_child(pack)
		pack.position = Vector3(0, 0.95, -0.32)
		WorldKit.box(pack, Vector3(0.5, 0.6, 0.28), Vector3.ZERO, Game.player_color(i), false)
		for s in [-1.0, 1.0]:
			WorldKit.cylinder(pack, 0.1, 0.32, Vector3(s * 0.16, -0.36, -0.02), Color("#5b5f66"), false)
		_packs.append(pack)
		var bar := Node3D.new()
		av.add_child(bar)
		bar.position = Vector3(0, 2.25, 0)
		WorldKit.box(bar, Vector3(0.9, 0.12, 0.05), Vector3.ZERO, Color("#2b2236"), false)
		var fill := WorldKit.box(bar, Vector3(0.84, 0.08, 0.06), Vector3.ZERO, Color("#7dff8a"), false)
		fill.name = "Fill"
		_bars.append(bar)
	for k in 3:
		_spawn_ring()


func on_tick(delta: float) -> void:
	for i in active_slots():
		var av := avatars[i] as PartyAvatar
		var on := InputHub.held(i, "a") and _fuel[i] > 0.02 and not av.is_stunned()
		_thrusting[i] = on
		if on:
			av.velocity.y = minf(av.velocity.y + THRUST * delta, MAX_UP)
			_fuel[i] = maxf(0.0, _fuel[i] - DRAIN * delta)
		elif av.is_on_floor():
			_fuel[i] = minf(1.0, _fuel[i] + REFILL * delta)
		# Ringe durchfliegen
		for r in _rings:
			if av.global_position.distance_to(r.pos as Vector3) < 1.35 + 0.0 * delta:
				_collect(i, r)
				break
	_update_clouds(delta)
	_visuals(delta)


func _spawn_ring() -> void:
	var gold := rng.randf() < 0.22
	var a := rng.randf() * TAU
	var rad := rng.randf_range(1.5, ARENA_R - 1.5)
	var pos := Vector3(cos(a) * rad, rng.randf_range(2.2, 7.5), sin(a) * rad)
	var node := MgKit.ring(world, 1.0, 0.14, Color("#ffd23f") if gold else Color("#8be9ff"), 1.6)
	node.position = pos
	node.rotation.x = PI / 2.0
	node.rotation.y = rng.randf() * TAU
	node.scale = Vector3.ONE * 0.1
	node.create_tween().tween_property(node, "scale", Vector3.ONE * (1.25 if gold else 1.0), 0.3).set_trans(Tween.TRANS_BACK)
	var spin := node.create_tween().set_loops()
	spin.tween_property(node, "rotation:y", TAU, 4.0).as_relative()
	_rings.append({"pos": pos, "gold": gold, "node": node})


func _collect(i: int, r: Dictionary) -> void:
	var pos: Vector3 = r.pos
	add_score(i, 3.0 if bool(r.gold) else 1.0, pos)
	Audio.sfx("coin", pos, 0.0, 1.3 if bool(r.gold) else 1.0)
	FX.ring(pos, Color(1, 0.9, 0.4) if bool(r.gold) else Color(0.6, 0.95, 1.0), 2.2, 0.35)
	FX.stars(pos, Color(1, 0.95, 0.6), 10 if bool(r.gold) else 6)
	(r.node as Node3D).queue_free()
	_rings.erase(r)
	_spawn_ring()


func _update_clouds(delta: float) -> void:
	for c in _clouds:
		c.ang = float(c.ang) + float(c.speed) * delta
		var node: Node3D = c.node
		node.position = Vector3(cos(float(c.ang)) * float(c.rad), float(c.h) + sin(float(c.ang) * 3.0) * 0.3, sin(float(c.ang)) * float(c.rad))
		c.t = float(c.t) - delta
		if not bool(c.warn) and float(c.t) <= 1.1:
			c.warn = true
			Audio.sfx("thunder", node.position, -8.0)
			MgKit.warn_disc(world, Vector3(node.position.x, 0.03, node.position.z), 1.6, Color(1.0, 0.9, 0.2), 1.1)
			for p in node.get_children():
				((p as MeshInstance3D).mesh as SphereMesh).material.albedo_color = Color("#3d3f55")
		if float(c.t) <= 0.0:
			c.t = rng.randf_range(3.0, 4.5)
			c.warn = false
			_bolt(node.position)
			for p in node.get_children():
				((p as MeshInstance3D).mesh as SphereMesh).material.albedo_color = Color("#6b6f86")


func _bolt(at: Vector3) -> void:
	var bolt := WorldKit.cylinder(world, 0.25, at.y, Vector3(at.x, at.y * 0.5, at.z), Color(1, 1, 0.6), false)
	((bolt.get_child(0) as MeshInstance3D)).material_override = WorldKit.mat(Color(1, 1, 0.7), 0.2, 3.0)
	var tw := bolt.create_tween()
	tw.tween_property(bolt, "scale", Vector3(0.1, 1, 0.1), 0.25)
	tw.tween_callback(bolt.queue_free)
	FX.flash_light(Vector3(at.x, 1.0, at.z), Color(1, 1, 0.7), 6.0, 0.25)
	Audio.sfx("zap", Vector3(at.x, 1.0, at.z))
	Juice.shake(0.2)
	for i in active_slots():
		var av := avatars[i] as PartyAvatar
		var d := Vector2(av.global_position.x - at.x, av.global_position.z - at.z).length()
		if d < 1.7 and av.global_position.y < at.y:
			av.apply_knockback(Vector3(av.global_position.x - at.x, 0, av.global_position.z - at.z).normalized(), 4.0, 1.0, 0.0)
			av.velocity.y = -6.0
			_fuel[i] = 0.0
			av.rig.react("soot_blast")
			av.rig.set_soot(3.0)
			FX.sparks(av.global_position + Vector3.UP, Color(1, 1, 0.5), 12)


func _visuals(delta: float) -> void:
	_flame_t -= delta
	var puff := _flame_t <= 0.0
	if puff:
		_flame_t = 0.05
	for i in 4:
		if i >= _bars.size() or _bars[i] == null:
			continue
		var fill := _bars[i].get_node("Fill") as Node3D
		fill.scale.x = maxf(_fuel[i], 0.01)
		fill.position.x = -0.42 * (1.0 - _fuel[i])
		if puff and _thrusting[i] and avatars[i] and (avatars[i] as PartyAvatar).alive:
			var p := (_packs[i] as Node3D).global_position + Vector3.DOWN * 0.55
			FX.sparks(p, Color(1.0, 0.6, 0.2), 2)
			if randf() < 0.12:
				Audio.sfx("thruster", p, -14.0, randf_range(0.9, 1.1))


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	d["f"] = _fuel.map(func(f: float) -> float: return snappedf(f, 0.02))
	d["th"] = _thrusting.map(func(b: bool) -> int: return 1 if b else 0)
	d["r"] = _rings.map(func(r: Dictionary) -> Array: return [snappedf((r.pos as Vector3).x, 0.01), snappedf((r.pos as Vector3).y, 0.01), snappedf((r.pos as Vector3).z, 0.01), 1 if bool(r.gold) else 0])
	d["c"] = _clouds.map(func(c: Dictionary) -> Array: return [snappedf(float(c.ang), 0.01), snappedf(float(c.t), 0.02)])
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var f: Array = d.get("f", [])
	var th: Array = d.get("th", [])
	for i in mini(f.size(), 4):
		_fuel[i] = float(f[i])
		_thrusting[i] = int(th[i]) == 1 if i < th.size() else false
	# Ringe: Unterschiede neu aufbauen (selten – nur beim Einsammeln)
	var rs: Array = d.get("r", [])
	var same := rs.size() == _rings.size()
	if same:
		for k in rs.size():
			if Vector3(float(rs[k][0]), float(rs[k][1]), float(rs[k][2])).distance_to(_rings[k].pos as Vector3) > 0.05:
				same = false
	if not same:
		for r in _rings:
			if not _ring_in(rs, r.pos as Vector3):
				FX.ring(r.pos as Vector3, Color(0.6, 0.95, 1.0), 2.2, 0.35)
				Audio.sfx("coin", r.pos as Vector3)
			(r.node as Node3D).queue_free()
		_rings.clear()
		for e in rs:
			_make_ring_node(Vector3(float(e[0]), float(e[1]), float(e[2])), int(e[3]) == 1)
	var cs: Array = d.get("c", [])
	for k in mini(cs.size(), _clouds.size()):
		var old_t := float(_clouds[k].t)
		_clouds[k].ang = float(cs[k][0])
		_clouds[k].t = float(cs[k][1])
		var node: Node3D = _clouds[k].node
		node.position = Vector3(cos(float(_clouds[k].ang)) * float(_clouds[k].rad), float(_clouds[k].h), sin(float(_clouds[k].ang)) * float(_clouds[k].rad))
		if float(_clouds[k].t) > old_t + 1.0:
			_bolt_fx(node.position)
	_visuals(1.0 / 30.0)


func _ring_in(rs: Array, p: Vector3) -> bool:
	for e in rs:
		if Vector3(float(e[0]), float(e[1]), float(e[2])).distance_to(p) < 0.05:
			return true
	return false


func _make_ring_node(pos: Vector3, gold: bool) -> void:
	var node := MgKit.ring(world, 1.0, 0.14, Color("#ffd23f") if gold else Color("#8be9ff"), 1.6)
	node.position = pos
	node.rotation.x = PI / 2.0
	node.scale = Vector3.ONE * (1.25 if gold else 1.0)
	var spin := node.create_tween().set_loops()
	spin.tween_property(node, "rotation:y", TAU, 4.0).as_relative()
	_rings.append({"pos": pos, "gold": gold, "node": node})


func _bolt_fx(at: Vector3) -> void:
	var bolt := WorldKit.cylinder(world, 0.25, at.y, Vector3(at.x, at.y * 0.5, at.z), Color(1, 1, 0.6), false)
	var tw := bolt.create_tween()
	tw.tween_property(bolt, "scale", Vector3(0.1, 1, 0.1), 0.25)
	tw.tween_callback(bolt.queue_free)
	Audio.sfx("zap", Vector3(at.x, 1.0, at.z))


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	var level: int = Game.players[slot].cpu_level
	var mem: Dictionary = cpu_mem[slot]
	var p := av.global_position
	var held := {}
	var mv := Vector2.ZERO
	var refuel := bool(mem.get("refuel", false))
	if _fuel[slot] < Game.lv([0.25, 0.15, 0.1], level):
		refuel = true
	elif _fuel[slot] > Game.lv([0.7, 0.85, 0.95], level):
		refuel = false
	mem["refuel"] = refuel
	var best: Dictionary = {}
	var bs := INF
	for r in _rings:
		var sc := (r.pos as Vector3).distance_to(p) / (2.2 if bool(r.gold) else 1.0)
		if sc < bs:
			bs = sc
			best = r
	if not best.is_empty() and not refuel:
		var tp: Vector3 = best.pos
		var to := tp - p
		mv = Vector2(to.x, to.z)
		mv = mv.normalized() * clampf(mv.length() * 0.5, 0.0, 1.0)
		if tp.y - 0.6 > p.y or (av.velocity.y < -3.0 and tp.y > p.y - 1.5):
			held["a"] = true
	# Unter einer grummelnden Wolke weg
	for c in _clouds:
		var cp := (c.node as Node3D).position
		var off := Vector2(p.x - cp.x, p.z - cp.z)
		if bool(c.warn) and off.length() < 2.6 and randf() < Game.lv([0.4, 0.75, 0.95], level):
			mv = off.normalized()
	InputHub.set_virtual(slot, mv.limit_length(1.0), held)
