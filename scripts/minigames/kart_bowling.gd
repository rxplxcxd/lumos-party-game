extends MinigameBase
## Kart-Bowling: Alle sitzen in Karts in einer Dungeon-Arena. Gigantische Felsbrocken rollen
## durch die Halle (Warnspur 1 s vorher). Weiche aus – oder rempel Gegner per Turbo in die Bahn!
## 3 Leben, wer zuletzt noch fährt (oder am Ende die meisten Leben hat), gewinnt.

const HALF := 13.0
const MAX_SPEED := 11.0
const TURBO_SPEED := 21.0
const KART_R := 1.4
const BOULDER_R := 1.75

var karts: Array[Dictionary] = []
var boulders: Array[Dictionary] = []
var _spawn_t := 2.0
var _elim_time: Array[float] = [0, 0, 0, 0]


func _init() -> void:
	game_id = "kart_bowling"
	env_preset = "dungeon"
	time_limit = 50.0
	survival = true
	teaser_height = 1.5
	arena_radius = 14.0
	cannon_pos = Vector3(0, 0, 16)
	touch_profile = "minigame"
	spawn_points = [Vector3(-6, 0, -6), Vector3(6, 0, -6), Vector3(-6, 0, 6), Vector3(6, 0, 6)]


func build_arena() -> void:
	var tiles: Array = []
	for x in range(-14, 15, 4):
		for z in range(-14, 15, 4):
			tiles.append(Transform3D(Basis(), Vector3(x, 0, z)))
	WorldKit.multimesh(world, "dun/floor_large", tiles)
	WorldKit.box(world, Vector3(34, 1, 34), Vector3(0, -0.55, 0), Color(0.25, 0.2, 0.22), false)
	for i in range(-12, 13, 4):
		for side in [[Vector3(i, 0, -HALF - 2.5), 0.0], [Vector3(i, 0, HALF + 2.5), 180.0], [Vector3(-HALF - 2.5, 0, i), 90.0], [Vector3(HALF + 2.5, 0, i), -90.0]]:
			var key := "dun/wall_doorway" if i == 0 else "dun/wall"
			var w := WorldKit.place(world, key, side[0], side[1], 1.0)
			if i == 0:
				WorldKit.torch_light(world, (side[0] as Vector3) * 0.92 + Vector3.UP * 3.2, Color(1, 0.55, 0.2), 2.0, 9.0)
	for c in [Vector3(-HALF - 2, 0, -HALF - 2), Vector3(HALF + 2, 0, -HALF - 2), Vector3(-HALF - 2, 0, HALF + 2), Vector3(HALF + 2, 0, HALF + 2)]:
		WorldKit.place(world, "dun/pillar_deco", c, 0.0, 1.2)
	WorldKit.torch_light(world, Vector3(0, 9, 0), Color(1.0, 0.8, 0.6), 2.2, 30.0)
	for p in [Vector3(-9, 0, -HALF - 1.2), Vector3(9, 0, HALF + 1.2), Vector3(-HALF - 1.2, 0, 9), Vector3(HALF + 1.2, 0, -9)]:
		WorldKit.place(world, "dun/barrel", p, randf() * 360.0, 0.8)


func spawn_players() -> void:
	var kart_keys := ["kart/oobi", "kart/oodi", "kart/ooli", "kart/oopi"]
	for i in 4:
		var kv := KartVisual.new()
		world.add_child(kv)
		kv.setup(kart_keys[i], Game.hero(Game.players[i].hero).model, i, 2.0)
		kv.position = spawn_points[i]
		var heading := atan2(-spawn_points[i].x, -spawn_points[i].z)
		kv.rotation.y = heading + PI
		karts.append({"node": kv, "pos": Vector2(spawn_points[i].x, spawn_points[i].z), "vel": Vector2.ZERO,
			"heading": kv.rotation.y, "lives": 3, "turbo": 0.0, "turbo_cd": 0.0, "stun": 0.0, "inv": 0.0})
		actors[i] = kv
		rigs[i] = kv.hero


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, 1)
	c.offset = Vector3(0, 21, 15)
	c.min_dist = 1.0
	c.max_dist = 1.0
	c.follow = false


func _update_badges() -> void:
	for i in badges.size():
		var lives: int = int(karts[i].lives) if i < karts.size() else 0
		if lives > 0:
			badges[i].set_status("hearts", lives)
		else:
			badges[i].set_status("out")


func on_tick(delta: float) -> void:
	# Felsen spawnen
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = lerpf(1.1, 2.6, time_left / time_limit)
		_spawn_boulder()
	for i in 4:
		_drive(i, delta)
	_collide_karts()
	_update_boulders(delta)


func _drive(i: int, delta: float) -> void:
	var k: Dictionary = karts[i]
	var kv: KartVisual = k.node
	if not alive[i]:
		return
	k.turbo = maxf(0.0, k.turbo - delta)
	k.turbo_cd = maxf(0.0, k.turbo_cd - delta)
	k.stun = maxf(0.0, k.stun - delta)
	k.inv = maxf(0.0, k.inv - delta)
	var mv := InputHub.move(i) if k.stun <= 0.0 else Vector2.ZERO
	var throttle := mv.length()
	if InputHub.held(i, "a") and k.stun <= 0.0:
		throttle = 1.0
	var steer := 0.0
	if mv.length() > 0.2:
		var want := atan2(-mv.x, -mv.y)
		var diff := wrapf(want - float(k.heading), -PI, PI)
		steer = clampf(diff * 2.0, -1.0, 1.0)
		k.heading = float(k.heading) + clampf(diff, -3.6 * delta, 3.6 * delta)
	if InputHub.pressed(i, "b") and k.turbo_cd <= 0.0 and k.stun <= 0.0:
		k.turbo = 0.45
		k.turbo_cd = 1.8
		Audio.sfx("boost", kv.global_position)
		Juice.squash(kv.body, 0.85, 1.15, 0.3)
		FX.ring(kv.global_position + Vector3.UP * 0.3, Color(0.6, 0.85, 1.0, 0.8), 3.0, 0.3)
		InputHub.rumble(i, 0.5, 0.15)
	var fwd := Vector2(-sin(float(k.heading)), -cos(float(k.heading)))
	var target := fwd * (TURBO_SPEED if k.turbo > 0.0 else MAX_SPEED * throttle)
	var vel: Vector2 = k.vel
	vel = vel.lerp(target, clampf(delta * (6.0 if k.turbo > 0.0 else 2.6), 0, 1))
	var pos: Vector2 = k.pos + vel * delta
	# Wände
	for ax in 2:
		if absf(pos[ax]) > HALF - KART_R:
			pos[ax] = signf(pos[ax]) * (HALF - KART_R)
			vel[ax] = -vel[ax] * 0.5
			if absf(vel[ax]) > 3.0:
				Audio.sfx("metal_light", kv.global_position, -6.0)
				FX.sparks(kv.global_position + Vector3.UP * 0.5, Color(1, 0.8, 0.3), 6)
	k.vel = vel
	k.pos = pos
	kv.position = Vector3(pos.x, 0, pos.y)
	kv.rotation.y = float(k.heading)
	kv.update_visual(vel.length(), steer, 0, 0, k.turbo > 0.0, false, delta)
	kv.visible = k.inv <= 0.0 or int(k.inv * 12.0) % 2 == 0


func _collide_karts() -> void:
	for a in 4:
		for b in range(a + 1, 4):
			if not alive[a] or not alive[b]:
				continue
			var ka: Dictionary = karts[a]
			var kb: Dictionary = karts[b]
			var d: Vector2 = kb.pos - ka.pos
			var dist := d.length()
			if dist < KART_R * 2.0 and dist > 0.01:
				var n := d / dist
				var push := (KART_R * 2.0 - dist) * 0.5
				ka.pos -= n * push
				kb.pos += n * push
				var rel: float = (ka.vel - kb.vel).dot(n)
				if rel > 0.0:
					var strength := rel * 1.1
					if ka.turbo > 0.0:
						strength += 12.0
						kb.stun = 0.6
						(kb.node as KartVisual).spin_out(1.0, 0.6)
					if kb.turbo > 0.0:
						strength += 12.0
						ka.stun = 0.6
						(ka.node as KartVisual).spin_out(1.0, 0.6)
					ka.vel -= n * strength * 0.5
					kb.vel += n * strength * 0.5
					if strength > 6.0:
						var mid := ((ka.node as Node3D).global_position + (kb.node as Node3D).global_position) * 0.5
						Audio.sfx("punch", mid)
						FX.stars(mid + Vector3.UP, Color(1, 1, 0.5), 8)
						Juice.shake(0.2)
						Juice.hitstop(0.05)
						InputHub.rumble(a, 0.6, 0.15)
						InputHub.rumble(b, 0.6, 0.15)


func _spawn_boulder() -> void:
	var side := randi() % 4
	var lane := randf_range(-HALF + 2.5, HALF - 2.5)
	var start: Vector2
	var dir: Vector2
	match side:
		0:
			start = Vector2(lane, -HALF - 4)
			dir = Vector2(0, 1)
		1:
			start = Vector2(lane, HALF + 4)
			dir = Vector2(0, -1)
		2:
			start = Vector2(-HALF - 4, lane)
			dir = Vector2(1, 0)
		_:
			start = Vector2(HALF + 4, lane)
			dir = Vector2(-1, 0)
	# Warnspur
	var warn := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(BOULDER_R * 2.0, HALF * 2.0 + 4)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 0.2, 0.15, 0.0)
	q.material = m
	warn.mesh = q
	world.add_child(warn)
	warn.position = Vector3(lane if side < 2 else 0, 0.08, 0 if side < 2 else lane)
	if side >= 2:
		warn.rotation.y = PI / 2.0
	var tw := warn.create_tween().set_loops(4)
	tw.tween_property(m, "albedo_color:a", 0.45, 0.12)
	tw.tween_property(m, "albedo_color:a", 0.1, 0.12)
	Audio.sfx("stone_hit", Vector3(start.x, 0, start.y), -2.0, 0.6)
	var node := Node3D.new()
	world.add_child(node)
	var rock := Assets.spawn("td/boulder", node, Vector3.ZERO, 0.0, 11.0)
	rock.position.y = 0.0
	node.position = Vector3(start.x, BOULDER_R, start.y)
	var speed := randf_range(9.0, 13.0) * lerpf(1.25, 1.0, time_left / time_limit)
	boulders.append({"node": node, "rock": rock, "pos": start, "vel": dir * speed, "delay": 1.0, "warn": warn})


func _update_boulders(delta: float) -> void:
	for b in boulders.duplicate():
		if b.delay > 0.0:
			b.delay -= delta
			if b.delay <= 0.0:
				(b.warn as Node3D).queue_free()
				Juice.shake(0.15)
			continue
		var pos: Vector2 = b.pos + b.vel * delta
		b.pos = pos
		var node: Node3D = b.node
		node.position = Vector3(pos.x, BOULDER_R, pos.y)
		var axis := Vector3(b.vel.y, 0, -b.vel.x).normalized()
		(b.rock as Node3D).rotate(axis, (b.vel as Vector2).length() * delta / BOULDER_R)
		if randf() < 0.3:
			FX.step(Vector3(pos.x, 0, pos.y), "dungeon", 0.6, false)
		for i in 4:
			if not alive[i] or karts[i].inv > 0.0:
				continue
			if (karts[i].pos as Vector2).distance_to(pos) < BOULDER_R + KART_R * 0.8:
				_hit(i, b)
		if absf(pos.x) > HALF + 6 or absf(pos.y) > HALF + 6:
			node.queue_free()
			boulders.erase(b)


func _hit(i: int, b: Dictionary) -> void:
	var k: Dictionary = karts[i]
	var kv: KartVisual = k.node
	k.lives = int(k.lives) - 1
	k.inv = 1.6
	k.stun = 0.9
	k.vel = (b.vel as Vector2).normalized() * 16.0 + ((k.pos as Vector2) - (b.pos as Vector2)).normalized() * 6.0
	kv.flip(0.8)
	Audio.sfx("hit_soft", kv.global_position)
	Audio.sfx("stone_hit", kv.global_position)
	FX.stars(kv.global_position + Vector3.UP * 1.5, Color(1, 0.9, 0.3), 14)
	FX.dust(kv.global_position, Color(0.7, 0.65, 0.6), 14)
	Juice.shake(0.45)
	Juice.hitstop(0.08)
	InputHub.rumble(i, 1.0, 0.3)
	if int(k.lives) <= 0:
		_elim_time[i] = time_limit - time_left
		FX.explosion(kv.global_position, 0.8)
		kv.hero.set_soot(3.0)
		var tw := kv.create_tween()
		tw.tween_property(kv, "position", kv.position + Vector3.UP * 12.0 + Vector3(randf_range(-3, 3), 0, -4), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(kv, "scale", Vector3.ZERO, 0.3)
		eliminate(i)


func compute_placements() -> Array[int]:
	var idx: Array[int] = [0, 1, 2, 3]
	idx.sort_custom(func(a: int, b: int) -> bool:
		if alive[a] != alive[b]:
			return alive[a]
		if alive[a]:
			return karts[a].lives > karts[b].lives
		return _elim_time[a] > _elim_time[b])
	var places: Array[int] = [4, 4, 4, 4]
	for pos in idx.size():
		var p := idx[pos]
		places[p] = pos + 1
		if pos > 0:
			var q := idx[pos - 1]
			if alive[p] and alive[q] and karts[p].lives == karts[q].lives:
				places[p] = places[q]
	return places


# --- CPU ---------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	if not alive[slot]:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var k: Dictionary = karts[slot]
	var level: int = Game.players[slot].cpu_level
	var pos: Vector2 = k.pos
	var flee := Vector2.ZERO
	for b in boulders:
		var bp: Vector2 = b.pos
		var bv: Vector2 = b.vel
		var dir := bv.normalized()
		var rel := pos - bp
		var along := rel.dot(dir)
		if along < -2.0 and b.delay <= 0.0:
			continue
		var perp := rel - dir * along
		var t: float = along / maxf(bv.length(), 0.1) + b.delay
		if perp.length() < BOULDER_R + KART_R + 1.2 and t < Game.lv([0.7, 1.2, 1.8], level):
			flee += perp.normalized() * (1.0 if perp.length() > 0.1 else 1.0) * 2.0
	var held := {}
	var mv := Vector2.ZERO
	if flee.length() > 0.1:
		mv = flee.normalized()
		if level > 0 and k.turbo_cd <= 0.0 and randf() < 0.05:
			held["b"] = true
	else:
		var best := -1
		var bd := INF
		for j in 4:
			if j != slot and alive[j]:
				var d := pos.distance_to(karts[j].pos)
				if d < bd:
					bd = d
					best = j
		if best >= 0:
			var to: Vector2 = (karts[best].pos as Vector2) - pos
			mv = to.normalized() * 0.8
			var fwd := Vector2(-sin(float(k.heading)), -cos(float(k.heading)))
			if bd < 7.0 and fwd.dot(to.normalized()) > 0.9 and randf() < 0.04 * mini(level + 1, 3):
				held["b"] = true
		mv += -pos / HALF * 0.6
	InputHub.set_virtual(slot, mv.limit_length(1.0), held)
