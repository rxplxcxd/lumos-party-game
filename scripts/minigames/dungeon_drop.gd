extends MinigameBase
## Dungeon Drop: Quadratische Steinplatten brechen 1,5 s nach dem Betreten ein. Darunter: Lava.
## Ab der Hälfte der Zeit stürzen zusätzlich zufällige Platten. Letzter Überlebender gewinnt.

const GRID := 8
const TILE := 2.0
const FALL_DELAY := 1.5

var tiles := {}          # Vector2i -> {body, model, state, t}
var _random_drop_t := 0.0


func _init() -> void:
	game_id = "dungeon_drop"
	env_preset = "dungeon"
	time_limit = 60.0
	survival = true
	hazard = "lava"
	kill_y = -3.0
	teaser_height = 1.1
	arena_radius = 9.0
	arena_center = Vector3.ZERO
	cannon_pos = Vector3(0, 0, 11.5)
	spawn_points = [Vector3(-3, 0.3, -3), Vector3(3, 0.3, -3), Vector3(-3, 0.3, 3), Vector3(3, 0.3, 3)]
	arena_radius = 10.0


func build_arena() -> void:
	WorldKit.lava(world, Vector2(80, 80), -3.2, Vector2(0.05, 0.12))
	var off := (GRID - 1) * TILE * 0.5
	for x in GRID:
		for z in GRID:
			var pos := Vector3(x * TILE - off, 0, z * TILE - off)
			var body := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(TILE * 0.98, 0.6, TILE * 0.98)
			cs.shape = bs
			cs.position.y = -0.3
			body.add_child(cs)
			world.add_child(body)
			body.position = pos
			var model := Assets.spawn("dun/floor_small" if (x + z) % 3 != 0 else "dun/floor_rocks", body)
			if (x + z) % 3 == 0:
				model.scale = Vector3(0.5, 0.35, 0.5)
			# Unterbau als Felsblock, damit die Platte beim Fallen "massiv" wirkt
			var under := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(TILE * 0.96, 1.4, TILE * 0.96)
			bm.material = WorldKit.mat(Color(0.32, 0.28, 0.3))
			under.mesh = bm
			under.position.y = -0.8
			body.add_child(under)
			tiles[Vector2i(x, z)] = {"body": body, "state": "ok", "t": 0.0, "base": pos}
	# Kulisse: Säulen, Wände und Fackeln rund um die Grube
	for i in 12:
		var a := TAU * i / 12.0
		var p := Vector3(cos(a), 0, sin(a)) * 13.5
		var pillar := Assets.spawn("dun/pillar_deco", world, p + Vector3(0, -3.2, 0), rad_to_deg(-a))
		pillar.scale = Vector3(1, 1.6, 1)
		if i % 2 == 0:
			var t := Assets.spawn("dun/torch_mounted", world, p + Vector3(0, 2.4, 0) - p.normalized() * 0.8, rad_to_deg(-a) - 90.0)
			t.look_at(Vector3(0, 2.4, 0), Vector3.UP)
			WorldKit.torch_light(world, p + Vector3(0, 3.0, 0) - p.normalized() * 1.2, Color(1.0, 0.55, 0.2), 2.2, 9.0)
	for i in 8:
		var a2 := TAU * (i + 0.5) / 8.0
		var wp := Vector3(cos(a2), 0, sin(a2)) * 17.0
		var w := Assets.spawn("dun/wall_arched" if i % 2 else "dun/wall", world, wp + Vector3(0, -3.2, 0), 0.0, 1.5)
		w.look_at(Vector3(0, w.position.y, 0), Vector3.UP)
	WorldKit.scatter(world, ["dun/barrel", "dun/crates", "dun/rubble", "dun/box_stacked"], 10, Vector3(0, -3.0, 0), 11.0, 14.0, 0.0, Vector2(0.8, 1.1), 7)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, 0.5)
	c.offset = Vector3(0, 15.0, 12.5)
	c.min_dist = 1.0
	c.max_dist = 1.08
	c.center_weight = 0.75


func on_start() -> void:
	for av in avatars:
		(av as PartyAvatar).rig.surface = "dungeon"


func _tile_at(pos: Vector3) -> Vector2i:
	var off := (GRID - 1) * TILE * 0.5
	return Vector2i(int(round((pos.x + off) / TILE)), int(round((pos.z + off) / TILE)))


func on_tick(delta: float) -> void:
	# Betretene Platten aktivieren
	for i in 4:
		var av: PartyAvatar = avatars[i]
		if av.alive and av.is_on_floor():
			var k := _tile_at(av.global_position)
			if tiles.has(k) and tiles[k].state == "ok":
				_trigger(k)
	# Zufällige Einstürze in der zweiten Hälfte
	if time_left < time_limit * 0.55:
		_random_drop_t -= delta
		if _random_drop_t <= 0.0:
			_random_drop_t = lerpf(0.5, 1.4, time_left / time_limit)
			var ok := tiles.keys().filter(func(k: Vector2i) -> bool: return tiles[k].state == "ok")
			if ok.size() > 3:
				_trigger(ok[randi() % ok.size()])
	# Wackeln & Fallen
	for k in tiles:
		var t: Dictionary = tiles[k]
		if t.state == "shaking":
			t.t += delta
			var body: Node3D = t.body
			var amp: float = 0.04 + t.t * 0.05
			body.position = t.base + Vector3(randf_range(-amp, amp), randf_range(-amp, amp) * 0.5, randf_range(-amp, amp))
			if t.t >= FALL_DELAY:
				_drop(k)


func _trigger(k: Vector2i) -> void:
	var t: Dictionary = tiles[k]
	t.state = "shaking"
	t.t = 0.0
	Audio.sfx("creak", t.base, -4.0)
	FX.dust(t.base + Vector3.UP * 0.1, Color(0.6, 0.55, 0.5), 6, 0.8)
	for mi in Assets.find_meshes(t.body):
		mi.material_overlay = _warn_mat()


var _warn: StandardMaterial3D


func _warn_mat() -> StandardMaterial3D:
	if _warn == null:
		_warn = StandardMaterial3D.new()
		_warn.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_warn.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_warn.albedo_color = Color(1.0, 0.25, 0.1, 0.28)
	return _warn


func _drop(k: Vector2i) -> void:
	var t: Dictionary = tiles[k]
	t.state = "gone"
	var body: StaticBody3D = t.body
	for c in body.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", true)
	Audio.sfx("stone_hit", t.base)
	FX.step(t.base, "dungeon", 2.0, false)
	var tw := body.create_tween().set_parallel(true)
	tw.tween_property(body, "position:y", -7.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(body, "rotation", Vector3(randf_range(-0.6, 0.6), randf_range(-0.5, 0.5), randf_range(-0.6, 0.6)), 0.9)
	tw.chain().tween_callback(func() -> void:
		FX.embers(Vector3(t.base.x, -3.0, t.base.z), 8)
		body.visible = false)


# --- CPU ----------------------------------------------------------------------------------------

func cpu_think(slot: int, delta: float) -> void:
	var av: PartyAvatar = avatars[slot]
	if not av.alive:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var mem: Dictionary = cpu_mem[slot]
	var level: int = Game.players[slot].cpu_level
	var here := _tile_at(av.global_position)
	var here_state: String = tiles[here].state if tiles.has(here) else "gone"
	mem["t"] = mem.get("t", 0.0) - delta
	var react_delay: float = [0.55, 0.3, 0.12][level]
	var here_t: float = tiles[here].t if tiles.has(here) else 99.0
	var must_move := here_state == "gone" or (here_state == "shaking" and here_t > react_delay)
	if not mem.has("target") or must_move and mem.get("target") == here or mem["t"] <= 0.0 and must_move:
		mem["t"] = 0.25
		mem["target"] = _best_tile(av.global_position, level)
	if not must_move and mem.get("target") == here:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var target: Vector2i = mem["target"]
	if not tiles.has(target) or tiles[target].state == "gone":
		mem["t"] = 0.0
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var goal: Vector3 = tiles[target].base
	var to := goal - av.global_position
	to.y = 0
	var mv := Vector2(to.x, to.z)
	if mv.length() < 0.35:
		mv = Vector2.ZERO
	else:
		mv = mv.normalized()
	var held := {}
	# Über Lücken springen
	var ahead := _tile_at(av.global_position + Vector3(mv.x, 0, mv.y) * 1.3)
	if mv != Vector2.ZERO and (not tiles.has(ahead) or tiles[ahead].state == "gone") and av.is_on_floor():
		held["a"] = true
	# Gegner schubsen, wenn nah und Gelegenheit
	for o in avatars:
		var oa := o as PartyAvatar
		if oa != av and oa.alive and oa.global_position.distance_to(av.global_position) < 1.6 and randf() < 0.02 * (level + 1):
			held["b"] = true
	InputHub.set_virtual(slot, mv, held)


func _best_tile(from: Vector3, level: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_s := -INF
	for k in tiles:
		var t: Dictionary = tiles[k]
		if t.state != "ok":
			continue
		var s := 0.0
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var nk: Vector2i = k + Vector2i(dx, dz)
				if tiles.has(nk) and tiles[nk].state == "ok":
					s += 1.0
		s -= (t.base as Vector3).distance_to(from) * (0.35 if level > 0 else 0.15)
		s += randf() * (3.0 - level)
		if s > best_s:
			best_s = s
			best = k
	return best
