extends MinigameBase
## Kullerfels-Flucht: In einer Schlucht rollt ein riesiger Felsbrocken hinter allen her. Kisten, Stämme und
## Zäune mit Lücke kommen entgegen – drüberspringen (A) oder durch die Lücke laufen. Wer hängen bleibt, wird vom
## Brocken eingeholt und plattgerollt. Münzen unterwegs zählen bei Gleichstand.
## Technik: Laufband – die Welt (Hindernisse, Deko, Figuren) wandert Richtung Brocken, der Brocken rollt auf der
## Stelle. Online: Besitzer-Modell (Hindernisse aus dem gemeinsamen Zufall, jeder verschiebt nur die eigene Figur).

const HALF_W := 3.6
const BOULDER_Z := -6.8
const BOULDER_R := 3.2
const SPAWN_Z := 13.0
const FRONT_Z := 6.5

var _obs: Array[Dictionary] = []   # {node, kind, gap_x, depth, smashed}
var _coins: Array[Dictionary] = [] # {node, taken}
var _decor: Array[Node3D] = []
var _belt := 3.0
var _spawn_t := 1.2
var _coin_t := 0.6
var _boulder: Node3D
var _rumble_t := 0.0


func _init() -> void:
	game_id = "boulder_run"
	env_preset = "day"
	backdrop_style = "sky_day"
	time_limit = 40.0
	survival = true
	arena_radius = 9.0
	teaser_height = 1.0
	cannon_pos = Vector3(8, 0, 4)
	spawn_points = [Vector3(-2.4, 0.6, 1.5), Vector3(-0.8, 0.6, 1.5), Vector3(0.8, 0.6, 1.5), Vector3(2.4, 0.6, 1.5)]


func build_arena() -> void:
	# Fester Boden mit Felswänden; die Optik (Streifen, Deko) läuft als Band mit
	WorldKit.box(world, Vector3(HALF_W * 2.0, 0.5, 40), Vector3(0, -0.25, 2), Color("#b98a5a"))
	for side in [-1.0, 1.0]:
		WorldKit.box(world, Vector3(1.0, 5.0, 40), Vector3(side * (HALF_W + 0.5), 2.5, 2), Color("#8a6a4a"))
		WorldKit.box(world, Vector3(9.0, 7.0, 40), Vector3(side * (HALF_W + 5.4), 2.0, 2), Color("#9c7a52"), false)
	for i in 14:
		var strip := WorldKit.box(world, Vector3(HALF_W * 2.0 - 0.1, 0.04, 1.2), Vector3(0, 0.01, -10.0 + i * 2.0), Color("#a7784b"), false)
		_decor.append(strip)
	for i in 12:
		var side2 := -1.0 if i % 2 == 0 else 1.0
		var key: String = ["nat/rock_large", "nat/cactus", "nat/rock_tall", "nat/bush", "nat/rock_small", "nat/cactus_short"][i % 6]
		var d := WorldKit.place(world, key, Vector3(side2 * (HALF_W + 2.0 + randf() * 2.5), 5.0, -10.0 + i * 2.4), randf() * 360.0, randf_range(1.2, 2.0))
		_decor.append(d)
	# Der Brocken: dicke Kugel mit Moosflecken
	_boulder = Node3D.new()
	_boulder.set_meta("keep_visible", true)   # Intro darf den Brocken nicht als Sichthindernis ausblenden
	world.add_child(_boulder)
	_boulder.position = Vector3(0, BOULDER_R - 0.2, BOULDER_Z)
	var bm := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = BOULDER_R
	sm.height = BOULDER_R * 2.0
	sm.material = WorldKit.mat(Color("#7d7468"), 0.95)
	bm.mesh = sm
	_boulder.add_child(bm)
	# Buckel und Moospolster (kleine Kugeln halb eingesunken) – liest sich als grober Fels
	for k in 14:
		var dir := Vector3(cos(k * 2.4) * sin(k * 0.9 + 0.5), cos(k * 0.9 + 0.5), sin(k * 2.4) * sin(k * 0.9 + 0.5)).normalized()
		var bump := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = randf_range(0.5, 0.9)
		bs.height = bs.radius * 1.6
		bs.material = WorldKit.mat(Color("#5f9d48") if k % 3 == 0 else Color("#6b6358"), 0.95)
		bump.mesh = bs
		bump.position = dir * (BOULDER_R - 0.25)
		bm.add_child(bump)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, -0.5)
	c.offset = Vector3(0, 15.5, 11.5)
	c.min_dist = 0.95
	c.max_dist = 1.1


func on_start() -> void:
	for av in avatars:
		(av as PartyAvatar).can_shove = false
		(av as PartyAvatar).rig.surface = "sand"


func on_tick(delta: float) -> void:
	var prog := 1.0 - time_left / time_limit
	_belt = lerpf(3.2, 5.8, prog)
	var step := _belt * delta
	_boulder.get_child(0).rotation.x -= step / BOULDER_R
	_boulder.position.y = BOULDER_R - 0.2 + absf(sin((time_limit - time_left) * 5.0)) * 0.08
	_rumble_t -= delta
	if _rumble_t <= 0.0:
		_rumble_t = 0.45
		Juice.shake(0.05)
		FX.dust(Vector3(randf_range(-2.5, 2.5), 0.2, BOULDER_Z + BOULDER_R * 0.6), Color(0.85, 0.7, 0.5), 5, 0.9)
		Audio.sfx("stone_hit", _boulder.global_position, -16.0, randf_range(0.5, 0.65))
	for d in _decor:
		d.position.z -= step
		if d.position.z < -12.0:
			d.position.z += 28.0
	# Figuren mit dem Band zum Brocken tragen (nur die eigenen – fremde kommen über das Netz)
	for i in active_slots():
		var av := avatars[i] as PartyAvatar
		if not av.alive or not net_owned(i):
			continue
		av.global_position.z -= step
		if av.global_position.z > FRONT_Z:
			av.global_position.z = FRONT_Z
		if av.global_position.z < BOULDER_Z + BOULDER_R + 0.3:
			_squash(i)
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_obstacle(prog)
		# Später Kombis: zweites Hindernis kurz dahinter
		if prog > 0.4 and rng.randf() < 0.4:
			_spawn_t = rng.randf_range(0.42, 0.55)
		else:
			_spawn_t = lerpf(1.6, 0.9, prog) * rng.randf_range(0.85, 1.15)
	_coin_t -= delta
	if _coin_t <= 0.0:
		_coin_t = rng.randf_range(0.7, 1.2)
		_spawn_coin(rng.randf_range(-HALF_W + 0.7, HALF_W - 0.7))
	_move_obstacles(step)
	_move_coins(step)


func _spawn_obstacle(prog: float) -> void:
	var roll := rng.randf()
	var kind := "crate" if roll < 0.4 else ("log" if roll < 0.65 else "fence")
	if prog < 0.15 and kind == "fence":
		kind = "crate"
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	world.add_child(body)
	body.position = Vector3(0, 0, SPAWN_Z)
	var gap_x := 0.0
	var depth := 1.0
	match kind:
		"crate":
			# Ein bis zwei Kisten nebeneinander – daneben vorbei oder drüber
			var n := 1 if prog < 0.4 or rng.randf() < 0.5 else 2
			for k in n:
				var x := rng.randf_range(-HALF_W + 0.8, HALF_W - 0.8)
				_add_box(body, Vector3(1.3, 0.95, 1.1), Vector3(x, 0.475, 0), Color("#c68a3e"))
				WorldKit.box(body, Vector3(1.34, 0.12, 0.12), Vector3(x, 0.5, 0.56), Color("#8a5a28"), false)
			depth = 1.1
		"log":
			var lm := WorldKit.cylinder(body, 0.38, HALF_W * 2.0 - 0.2, Vector3(0, 0.38, 0), Color("#7a4f2a"))
			lm.rotation.z = PI / 2.0
			depth = 0.8
		"fence":
			gap_x = rng.randf_range(-HALF_W + 1.3, HALF_W - 1.3)
			var gap := 2.2 - prog * 0.5
			var left_w := (gap_x - gap * 0.5) + HALF_W
			var right_w := HALF_W - (gap_x + gap * 0.5)
			if left_w > 0.05:
				_add_box(body, Vector3(left_w, 2.3, 0.4), Vector3(-HALF_W + left_w * 0.5, 1.15, 0), Color("#e8d2a0"))
			if right_w > 0.05:
				_add_box(body, Vector3(right_w, 2.3, 0.4), Vector3(HALF_W - right_w * 0.5, 1.15, 0), Color("#e8d2a0"))
			for s in [-1.0, 1.0]:
				WorldKit.cylinder(body, 0.14, 2.6, Vector3(gap_x + s * gap * 0.5, 1.3, 0), Color("#ff6b4a"), false)
			depth = 0.4
	_obs.append({"node": body, "kind": kind, "gap_x": gap_x, "depth": depth, "smashed": false})


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = WorldKit.mat(col, 0.8)
	mi.mesh = bm
	mi.position = pos
	parent.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	parent.add_child(cs)


func _move_obstacles(step: float) -> void:
	var k := _obs.size() - 1
	while k >= 0:
		var o := _obs[k]
		var n: Node3D = o.node
		n.position.z -= step
		# Vom Brocken zermalmt: Splitter und weg damit
		if not bool(o.smashed) and n.position.z < BOULDER_Z + BOULDER_R + 0.4:
			o.smashed = true
			FX.sparks(Vector3(0, 1.0, n.position.z), Color(0.8, 0.55, 0.3), 14)
			FX.dust(Vector3(0, 0.4, n.position.z), Color(0.8, 0.65, 0.45), 12, 1.6)
			Audio.sfx("plank_break" if String(o.kind) != "log" else "wood_hit", n.global_position, -6.0)
			# Physik-Körper nie skalieren (Jolt): Kollision aus, nur die Optik plattdrücken
			var tw := n.create_tween().set_parallel(true)
			_flatten(n, tw)
			tw.chain().tween_callback(n.queue_free)
			_obs.remove_at(k)
		k -= 1


## Kollisionen abschalten und nur sichtbare Teile plattdrücken (auch in verschachtelten Körpern)
func _flatten(n: Node, tw: Tween) -> void:
	for ch in n.get_children():
		if ch is CollisionShape3D:
			(ch as CollisionShape3D).set_deferred("disabled", true)
		elif ch is CollisionObject3D:
			_flatten(ch, tw)
		elif ch is Node3D:
			tw.tween_property(ch, "scale", Vector3(1.2, 0.05, 1.0), 0.18)


func _spawn_coin(x: float) -> void:
	var c := WorldKit.cylinder(world, 0.32, 0.08, Vector3(x, 0.9, SPAWN_Z), Color("#ffd23f"), false)
	c.rotation.x = PI / 2.0
	var tw := c.create_tween().set_loops()
	tw.tween_property(c, "rotation:y", TAU, 1.2).as_relative()
	_coins.append({"node": c, "taken": false})


func _move_coins(step: float) -> void:
	var k := _coins.size() - 1
	while k >= 0:
		var c := _coins[k]
		var n: Node3D = c.node
		n.position.z -= step
		var gone := n.position.z < BOULDER_Z + BOULDER_R
		for j in active_slots():
			var av := avatars[j] as PartyAvatar
			if av.alive and av.global_position.distance_to(n.position) < 1.0:
				if net_owned(j):
					add_score(j, 1.0, n.position)
				Audio.sfx("coin", n.position, -4.0)
				FX.sparks(n.position, Color(1, 0.85, 0.3), 8)
				gone = true
				break
		if gone:
			n.queue_free()
			_coins.remove_at(k)
		k -= 1


func _squash(j: int) -> void:
	var av := avatars[j] as PartyAvatar
	av.freeze(true)
	av.rig.react("land_flat")
	var tw := av.rig.create_tween()
	tw.tween_property(av.rig, "scale", Vector3(1.4, 0.12, 1.4), 0.12)
	Audio.sfx("hit_soft", av.global_position)
	FX.stars(av.global_position + Vector3.UP * 0.6, Color(1, 1, 0.6), 10)
	Juice.shake(0.25)
	InputHub.rumble(j, 1.0, 0.3)
	eliminate(j)


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	if not av.alive:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var mem: Dictionary = cpu_mem[slot]
	if not mem.has("lane"):
		mem["lane"] = [-2.4, -0.8, 0.8, 2.4][slot]
		mem["home"] = randf_range(0.5, 2.5)
		mem["miss"] = {}
	var p := av.global_position
	var lane := float(mem.lane)
	var held := {}
	var closing := maxf(_belt + av.velocity.z, 1.0)
	var miss: Dictionary = mem.miss
	for o in _obs:
		var n: Node3D = o.node
		# Pro Hindernis einmal entscheiden, ob die CPU patzt (zu spät springt / zu spät lenkt)
		if not miss.has(n.get_instance_id()):
			miss[n.get_instance_id()] = randf() < [0.3, 0.14, 0.05][level]
		var late: float = 0.35 if bool(miss[n.get_instance_id()]) else 0.0
		var dz := n.position.z - p.z - float(o.depth) * 0.5
		if dz < -0.6 or dz > 4.5:
			continue
		match String(o.kind):
			"fence":
				if dz < 4.5 - late * 8.0:
					lane = float(o.gap_x)
			"log":
				if dz < closing * ([0.26, 0.2, 0.16][level] - late) + 0.25 and av.is_on_floor():
					held["a"] = true
			"crate":
				# Kiste in der eigenen Spur? Ausweichen, wenn noch Zeit ist, sonst springen
				for ch in n.get_children():
					if ch is CollisionShape3D and absf((ch as Node3D).position.x - p.x) < 1.25:
						if dz > 2.2 and level > 0:
							lane = (ch as Node3D).position.x + (1.6 if (ch as Node3D).position.x < 0.0 else -1.6)
						elif dz < closing * ([0.26, 0.2, 0.16][level] - late) + 0.3 and av.is_on_floor():
							held["a"] = true
	if randf() < [0.012, 0.006, 0.002][level]:
		held["a"] = true
	var mv := Vector2(clampf((lane - p.x) * 1.2, -1.0, 1.0), clampf(_belt / av.max_speed + (float(mem.home) - p.z) * 0.45, -1.0, 1.0))
	InputHub.set_virtual(slot, mv, held)
