extends MinigameBase
## Ballon-Kart-Battle: Jedes Kart trägt drei Ballons. Turbo-Rempler (B) platzen einen Ballon des
## Gegners – und du klaust ihn dir! Item-Boxen geben Torten-Kanonen (X). Ohne Ballons ist man raus.
## Am Ende zählen übrige Ballons.

const HALF := 14.0
const MAX_SPEED := 12.0
const TURBO_SPEED := 22.0
const KART_R := 1.35
const MAX_BALLOONS := 5

var karts: Array[Dictionary] = []
var pies: Array[Dictionary] = []
var boxes: Array[Dictionary] = []
var pillars: Array[Vector2] = []
var _elim_time: Array[float] = [0, 0, 0, 0]
var _box_t := 2.0


func _init() -> void:
	game_id = "balloon_battle"
	env_preset = "day"
	time_limit = 60.0
	survival = true
	teaser_height = 1.4
	arena_radius = 15.0
	cannon_pos = Vector3(0, 0, 17)
	touch_profile = "battle"
	spawn_points = [Vector3(-9, 0, -9), Vector3(9, 0, -9), Vector3(-9, 0, 9), Vector3(9, 0, 9)]


func build_arena() -> void:
	WorldKit.box(world, Vector3(HALF * 2 + 6, 1, HALF * 2 + 6), Vector3(0, -0.5, 0), Color("#3f8f4f"))
	var tiles: Array = []
	for x in range(-12, 13, 4):
		for z in range(-12, 13, 4):
			tiles.append(Transform3D(Basis(), Vector3(x, 0.01, z)))
	WorldKit.multimesh(world, "mg/tile_large_blue", tiles)
	# Banden aus Reifenstapeln und Kegeln
	for i in range(-13, 14, 2):
		for side in [Vector3(i, 0, -HALF - 0.6), Vector3(i, 0, HALF + 0.6), Vector3(-HALF - 0.6, 0, i), Vector3(HALF + 0.6, 0, i)]:
			WorldKit.place(world, "car/debris_tire" if absi(i) % 4 == 1 else "toy/cone", side, randf() * 360.0, 2.2)
	pillars = [Vector2(0, 0), Vector2(-6, 0), Vector2(6, 0), Vector2(0, -6), Vector2(0, 6)]
	for p in pillars:
		var col := WorldKit.cylinder(world, 1.1, 2.4, Vector3(p.x, 1.2, p.y), Color("#ffd23f"), false)
		col.name = "Pillar"
		var star := Assets.spawn("plat/star", world, Vector3(p.x, 2.9, p.y), 0.0, 2.0)
		var tw := star.create_tween().set_loops()
		tw.tween_property(star, "rotation:y", TAU, 3.0).as_relative()
	for i in 10:
		var a := TAU * i / 10.0
		WorldKit.place(world, ["arcade/prize_wheel", "nat/tree_palm", "toy/gate_finish", "nat/tree_palm_bend", "arcade/machine"][i % 5], Vector3(cos(a), 0, sin(a)) * (HALF + 5.0), rad_to_deg(-a) - 90.0, 2.2)


func spawn_players() -> void:
	var kart_keys := ["kart/oobi", "kart/oodi", "kart/ooli", "kart/oopi"]
	for i in 4:
		var kv := KartVisual.new()
		world.add_child(kv)
		kv.setup(kart_keys[i], Game.hero(Game.players[i].hero).model, i, 2.0)
		kv.position = spawn_points[i]
		var heading := atan2(-spawn_points[i].x, -spawn_points[i].z)   # zur Mitte
		kv.rotation.y = heading + PI
		var holder := Node3D.new()
		holder.position = Vector3(0, 0, 0.9)
		kv.add_child(holder)
		var k := {"node": kv, "pos": Vector2(spawn_points[i].x, spawn_points[i].z), "vel": Vector2.ZERO, "heading": heading,
			"balloons": 3, "turbo": 0.0, "turbo_cd": 0.0, "stun": 0.0, "inv": 0.0, "item": "", "holder": holder, "b_nodes": []}
		karts.append(k)
		actors[i] = kv
		rigs[i] = kv.hero
		_rebuild_balloons(i)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, 1)
	c.offset = Vector3(0, 19.5, 14.5)
	c.min_dist = 1.0
	c.max_dist = 1.0
	c.follow = false


func _update_badges() -> void:
	for i in badges.size():
		var n: int = int(karts[i].balloons) if i < karts.size() else 0
		if n > 0:
			badges[i].set_status("hearts", n)
		else:
			badges[i].set_status("out")


func _rebuild_balloons(i: int) -> void:
	var k: Dictionary = karts[i]
	for n in k.b_nodes:
		(n as Node3D).queue_free()
	var arr: Array = []
	var holder: Node3D = k.holder
	var cnt: int = k.balloons
	for b in cnt:
		var bal := Node3D.new()
		holder.add_child(bal)
		var off := (b - (cnt - 1) * 0.5) * 0.55
		bal.position = Vector3(off, 2.6 + absf(off) * -0.2, 0.2)
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.42
		sm.height = 1.0
		var m := WorldKit.mat(Game.player_color(i).lightened(0.15), 0.25, 0.25)
		m.metallic_specular = 0.9
		sm.material = m
		mi.mesh = sm
		bal.add_child(mi)
		var string := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.015
		cm.bottom_radius = 0.015
		cm.height = 1.6
		cm.material = WorldKit.mat(Color(0.95, 0.95, 0.95))
		string.mesh = cm
		string.position = Vector3(-off * 0.4, -1.2, 0)
		string.rotation.z = off * 0.25
		bal.add_child(string)
		var tw := bal.create_tween().set_loops()
		tw.tween_property(bal, "position:y", bal.position.y + 0.15, 0.6 + b * 0.07).set_trans(Tween.TRANS_SINE)
		tw.tween_property(bal, "position:y", bal.position.y, 0.6 + b * 0.07).set_trans(Tween.TRANS_SINE)
		arr.append(bal)
	k.b_nodes = arr


func on_tick(delta: float) -> void:
	_box_t -= delta
	if _box_t <= 0.0 and boxes.size() < 4:
		_box_t = randf_range(2.5, 4.5)
		_spawn_box()
	for i in 4:
		_drive(i, delta)
	_collide_karts()
	_update_pies(delta)
	for b in boxes.duplicate():
		var n: Node3D = b.node
		n.rotation.y += delta * 2.0
		n.position.y = 0.9 + sin(Time.get_ticks_msec() / 250.0 + float(b.seed)) * 0.2
		for i in 4:
			if alive[i] and (karts[i].pos as Vector2).distance_to(b.pos) < KART_R + 0.8 and karts[i].item == "":
				karts[i].item = "pie"
				Audio.sfx("item_get", n.position)
				FX.stars(n.position, Color(1, 1, 1), 10)
				Juice.float_text(self, n.position + Vector3.UP * 2.0, "Torte!", Color("#ffd2a0"), 80)
				boxes.erase(b)
				n.queue_free()
				break


func _spawn_box() -> void:
	for _try in 10:
		var p := Vector2(randf_range(-HALF + 2, HALF - 2), randf_range(-HALF + 2, HALF - 2))
		var ok := true
		for pl in pillars:
			if p.distance_to(pl) < 2.5:
				ok = false
		if ok:
			var n := Assets.spawn("toy/item_box", world, Vector3(p.x, 0.9, p.y), 0.0, 2.2)
			Juice.pop_in(n, 0.35)
			boxes.append({"node": n, "pos": p, "seed": randf() * 10.0})
			return


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
		var want := atan2(mv.x, mv.y)
		var diff := wrapf(want - float(k.heading), -PI, PI)
		steer = clampf(diff * 2.0, -1.0, 1.0)
		k.heading = float(k.heading) + clampf(diff, -3.8 * delta, 3.8 * delta)
	if InputHub.pressed(i, "b") and k.turbo_cd <= 0.0 and k.stun <= 0.0:
		k.turbo = 0.5
		k.turbo_cd = 1.6
		Audio.sfx("boost", kv.global_position)
		Juice.squash(kv.body, 0.85, 1.15, 0.3)
		FX.ring(kv.global_position + Vector3.UP * 0.3, Color(0.6, 0.85, 1.0, 0.8), 3.0, 0.3)
		InputHub.rumble(i, 0.5, 0.15)
	if InputHub.pressed(i, "x") and k.item == "pie" and k.stun <= 0.0:
		k.item = ""
		_fire_pie(i)
	var fwd := Vector2(sin(float(k.heading)), cos(float(k.heading)))
	var target := fwd * (TURBO_SPEED if k.turbo > 0.0 else MAX_SPEED * throttle)
	var vel: Vector2 = k.vel
	vel = vel.lerp(target, clampf(delta * (6.0 if k.turbo > 0.0 else 2.6), 0, 1))
	var pos: Vector2 = k.pos + vel * delta
	for ax in 2:
		if absf(pos[ax]) > HALF - KART_R:
			pos[ax] = signf(pos[ax]) * (HALF - KART_R)
			vel[ax] = -vel[ax] * 0.5
			if absf(vel[ax]) > 3.0:
				Audio.sfx("boing", kv.global_position, -6.0)
	for pl in pillars:
		var d := pos - pl
		if d.length() < KART_R + 1.1:
			var n := d.normalized()
			pos = pl + n * (KART_R + 1.1)
			vel = vel - n * minf(0.0, vel.dot(n)) * 1.5
	k.vel = vel
	k.pos = pos
	kv.position = Vector3(pos.x, 0, pos.y)
	kv.rotation.y = float(k.heading) + PI
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
					ka.vel -= n * rel * 0.6
					kb.vel += n * rel * 0.6
					if ka.turbo > 0.0 and kb.turbo <= 0.0:
						_pop(b, a)
					elif kb.turbo > 0.0 and ka.turbo <= 0.0:
						_pop(a, b)
					elif ka.turbo > 0.0 and kb.turbo > 0.0:
						# Frontal mit beidem Turbo: beide drehen sich, keiner verliert
						(ka.node as KartVisual).spin_out(1.0, 0.6)
						(kb.node as KartVisual).spin_out(1.0, 0.6)
						ka.stun = 0.5
						kb.stun = 0.5
						Audio.sfx("metal_hit", (ka.node as Node3D).global_position)
					elif rel > 4.0:
						Audio.sfx("hit_soft", (ka.node as Node3D).global_position, -4.0)


## victim verliert einen Ballon, thief (>= 0) bekommt ihn.
func _pop(victim: int, thief: int) -> void:
	var kv: Dictionary = karts[victim]
	if float(kv.inv) > 0.0 or not alive[victim]:
		return
	var node: KartVisual = kv.node
	var at := node.global_position + Vector3.UP * 3.0
	kv.balloons = int(kv.balloons) - 1
	kv.inv = 1.4
	kv.stun = 0.7
	node.spin_out(1.5, 0.7)
	FX.confetti(at, 30)
	FX.stars(at, Game.player_color(victim).lightened(0.4), 10)
	Audio.sfx("pop", at, 2.0)
	Juice.hitstop(0.06)
	Juice.shake(0.25)
	InputHub.rumble(victim, 0.9, 0.25)
	if thief >= 0 and alive[thief]:
		var kt: Dictionary = karts[thief]
		if int(kt.balloons) < MAX_BALLOONS:
			kt.balloons = int(kt.balloons) + 1
			_rebuild_balloons(thief)
			Juice.float_text(self, (kt.node as Node3D).global_position + Vector3.UP * 3.5, "Geklaut!", Game.player_color(thief).lightened(0.3), 80)
			(kt.node as KartVisual).hero.react("taunt")
		InputHub.rumble(thief, 0.4, 0.1)
	_rebuild_balloons(victim)
	if int(kv.balloons) <= 0:
		_knock_out(victim)


func _knock_out(i: int) -> void:
	var node: KartVisual = karts[i].node
	_elim_time[i] = time_limit - time_left
	FX.explosion(node.global_position, 0.8)
	node.hero.set_soot(3.0)
	node.hero.react("launch")
	var tw := node.create_tween()
	tw.tween_property(node, "position", node.position + Vector3.UP * 10.0 + Vector3(randf_range(-3, 3), 0, -4), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(node.body, "rotation:x", TAU * 2.0, 0.9)
	tw.tween_property(node, "scale", Vector3.ZERO, 0.3)
	eliminate(i)


func _fire_pie(i: int) -> void:
	var k: Dictionary = karts[i]
	var fwd := Vector2(sin(float(k.heading)), cos(float(k.heading)))
	var start: Vector2 = (k.pos as Vector2) + fwd * (KART_R + 0.6)
	var node := Assets.spawn("hol/cookie", world, Vector3(start.x, 1.0, start.y), 0.0, 2.4)
	Assets.tint(node, Color(1.2, 0.95, 0.8))
	pies.append({"node": node, "pos": start, "vel": fwd * 24.0 + (k.vel as Vector2) * 0.5, "owner": i, "life": 1.6})
	Audio.sfx("cannon", node.position, -6.0, 1.4)
	(k.node as KartVisual).hero.play("throw", 0.05, 1.5, true)


func _update_pies(delta: float) -> void:
	for p in pies.duplicate():
		var pos: Vector2 = p.pos + (p.vel as Vector2) * delta
		p.pos = pos
		p.life = float(p.life) - delta
		var n: Node3D = p.node
		n.position = Vector3(pos.x, 1.0, pos.y)
		n.rotation.y += delta * 12.0
		var gone := float(p.life) <= 0.0 or absf(pos.x) > HALF or absf(pos.y) > HALF
		for pl in pillars:
			if pos.distance_to(pl) < 1.3:
				gone = true
		if not gone:
			for j in 4:
				if j != int(p.owner) and alive[j] and pos.distance_to(karts[j].pos) < KART_R + 0.4:
					_pop(j, -1)
					FX.dust(Vector3(pos.x, 1.2, pos.y), Color(1, 0.95, 0.85), 16, 1.2)
					Audio.sfx("slime", Vector3(pos.x, 1.0, pos.y), 0.0)
					gone = true
					break
		if gone:
			FX.dust(n.position, Color(1, 0.95, 0.85), 8, 0.8)
			pies.erase(p)
			n.queue_free()


func compute_placements() -> Array[int]:
	var idx: Array[int] = [0, 1, 2, 3]
	idx.sort_custom(func(a: int, b: int) -> bool:
		if alive[a] != alive[b]:
			return alive[a]
		if alive[a]:
			return karts[a].balloons > karts[b].balloons
		return _elim_time[a] > _elim_time[b])
	var places: Array[int] = [4, 4, 4, 4]
	for pos in idx.size():
		var p := idx[pos]
		places[p] = pos + 1
		if pos > 0:
			var q := idx[pos - 1]
			if alive[p] and alive[q] and karts[p].balloons == karts[q].balloons:
				places[p] = places[q]
	return places


func cpu_think(slot: int, _delta: float) -> void:
	if not alive[slot]:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var k: Dictionary = karts[slot]
	var level: int = Game.players[slot].cpu_level
	var pos: Vector2 = k.pos
	var fwd := Vector2(sin(float(k.heading)), cos(float(k.heading)))
	var held := {"a": true}
	var mv := Vector2.ZERO
	# Ziel: Item-Box wenn leer, sonst nächstes verwundbares Kart
	var goal := Vector2.INF
	if k.item == "":
		var bd := 9.0 + level * 2.0
		for b in boxes:
			var d := pos.distance_to(b.pos)
			if d < bd:
				bd = d
				goal = b.pos
	var best := -1
	var best_d := INF
	for j in 4:
		if j != slot and alive[j] and float(karts[j].inv) <= 0.0:
			var d := pos.distance_to(karts[j].pos)
			if d < best_d:
				best_d = d
				best = j
	if goal == Vector2.INF and best >= 0:
		var tp: Vector2 = karts[best].pos
		var tv: Vector2 = karts[best].vel
		goal = tp + tv * (0.25 + mini(level, 2) * 0.15)
	if goal != Vector2.INF:
		mv = (goal - pos).normalized()
	# Pfeiler umfahren
	for pl in pillars:
		var d := pl - pos
		if d.length() < 4.0 and fwd.dot(d.normalized()) > 0.6:
			mv += Vector2(-d.y, d.x).normalized() * 1.2
	if best >= 0:
		var to: Vector2 = (karts[best].pos as Vector2) - pos
		var facing := fwd.dot(to.normalized())
		if best_d < 7.0 and facing > 0.9 and float(k.turbo_cd) <= 0.0 and randf() < 0.05 * mini(level + 1, 3):
			held["b"] = true
		if k.item == "pie" and best_d < 14.0 and facing > 0.96 and randf() < 0.04 * mini(level + 1, 3):
			held["x"] = true
	# Wenn selbst verwundbar und ein Gegner mit Turbo heranrast: ausweichen
	if level > 0:
		for j in 4:
			if j != slot and alive[j] and float(karts[j].turbo) > 0.0:
				var rel := pos - (karts[j].pos as Vector2)
				if rel.length() < 6.0:
					mv += Vector2(-rel.y, rel.x).normalized() * 1.5
	mv += -pos / HALF * 0.3
	InputHub.set_virtual(slot, mv.limit_length(1.0), held)
