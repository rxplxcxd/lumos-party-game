extends MinigameBase
## Schatz-Seilbahn: Jeder saust an einem Seil über die Schlucht. Unter den Seilen wippen
## Felssäulen mit Schatzkisten (und Bomben!). Mit A lässt man sich am Gummiseil hinunter
## schnellen – im richtigen Moment, wenn die Säule oben ist. Stick hoch/runter wechselt das Seil.

const LANES := [-3.6, -1.2, 1.2, 3.6]
const ROPE_Y := 9.0
const START_X := -6.0
const END_X := 104.0
const SPEED := 3.4
const REACH_Y := 6.3

var riders: Array[Dictionary] = []
var pillars: Array[Dictionary] = []
var _t := 0.0


func _init() -> void:
	game_id = "treasure_zipline"
	env_preset = "day"
	time_limit = 36.0
	arena_radius = 10.0
	arena_center = Vector3(0, 6, 0)
	cannon_pos = Vector3(-12, 0.0, 9)


func build_arena() -> void:
	WorldKit.water(world, Vector2(260, 60), -14.0, Color(0.05, 0.3, 0.45), Color(0.2, 0.6, 0.7))
	# Schlucht-Wände
	for x in range(-20, 130, 9):
		for z in [-11.0, 11.0]:
			var c := WorldKit.place(world, "nat/cliff_large" if (x / 9) % 2 == 0 else "nat/cliff", Vector3(x, -14, z), 0.0 if z < 0 else 180.0, 9.0)
			c.scale.y = 12.0
	# Plattformen an Start und Ziel
	WorldKit.box(world, Vector3(10, 1, 14), Vector3(START_X - 4, 4.5, 0), Color("#8a6a4a"))
	WorldKit.box(world, Vector3(10, 1, 14), Vector3(END_X + 5, 4.5, 0), Color("#8a6a4a"))
	WorldKit.place(world, "toy/gate_finish", Vector3(END_X + 1, 5.0, 0), 90.0, 8.0)
	for z in LANES:
		var rope := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.06
		cm.bottom_radius = 0.06
		cm.height = END_X - START_X + 14.0
		cm.radial_segments = 6
		cm.material = WorldKit.mat(Color("#c8a070"))
		rope.mesh = cm
		rope.rotation.z = PI / 2.0
		rope.position = Vector3((START_X + END_X) * 0.5, ROPE_Y + 0.9, z)
		world.add_child(rope)
		for px in [START_X - 6.0, END_X + 7.0]:
			WorldKit.cylinder(world, 0.25, 6.0, Vector3(px, 7.5, z), Color("#6a4a2a"), false)
	# Felssäulen mit Kisten/Bomben
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()
	for li in LANES.size():
		var x := START_X + 8.0 + rng.randf() * 4.0
		while x < END_X - 4.0:
			var kind := "chest"
			var r := rng.randf()
			if r < 0.18:
				kind = "gold"
			elif r < 0.38:
				kind = "bomb"
			var node := Node3D.new()
			world.add_child(node)
			WorldKit.cylinder(node, 0.75, 22.0, Vector3(0, -11.15, 0), Color(0.55, 0.42, 0.36), false)
			WorldKit.cylinder(node, 0.95, 0.3, Vector3(0, -0.15, 0), Color(0.45, 0.33, 0.28), false)
			var item: Node3D
			match kind:
				"gold":
					item = Assets.spawn("dun/chest_gold", node, Vector3.ZERO, -90.0, 0.7)
				"bomb":
					item = Assets.spawn("mg/powerup_bomb", node, Vector3(0, 0.3, 0), 0.0, 1.0)
				_:
					item = Assets.spawn("pirate/chest", node, Vector3.ZERO, -90.0, 0.9)
			pillars.append({"node": node, "item": item, "lane": li, "x": x, "kind": kind, "taken": false,
				"phase": rng.randf() * TAU, "speed": rng.randf_range(1.6, 2.6)})
			x += rng.randf_range(5.0, 9.0)


func spawn_players() -> void:
	for i in 4:
		var holder := Node3D.new()
		world.add_child(holder)
		holder.position = Vector3(START_X, ROPE_Y, LANES[i])
		var pulley := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.6, 0.35, 0.3)
		bm.material = WorldKit.mat(Game.player_color(i))
		pulley.mesh = bm
		pulley.position.y = 0.9
		holder.add_child(pulley)
		var bungee := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.04
		cm.bottom_radius = 0.04
		cm.height = 1.0
		cm.material = WorldKit.mat(Color("#ff4fb8"))
		bungee.mesh = cm
		holder.add_child(bungee)
		var rig := CharacterRig.new()
		holder.add_child(rig)
		rig.setup(Game.hero(Game.players[i].hero).model, i, 0.75)
		rig.ring.visible = false
		rig.position.y = -1.6
		rig.face_now(Vector3(1, 0, 0))
		rig.play("jump_air")
		riders.append({"holder": holder, "rig": rig, "bungee": bungee, "lane": i, "drop": 0.0, "cooldown": 0.0,
			"stun": 0.0, "switch": 0.0, "z_from": LANES[i], "z_to": LANES[i], "speed": SPEED})
		actors[i] = holder
		rigs[i] = rig


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(START_X + 4, 6.0, 0)
	c.offset = Vector3(-7.0, 8.0, 15.0)
	c.look_offset = Vector3(5.0, -1.0, 0)
	c.min_dist = 1.0
	c.max_dist = 1.2
	c.center_weight = 0.0
	c.spread_ref = 20.0


func on_tick(delta: float) -> void:
	_t += delta
	for p in pillars:
		var node: Node3D = p.node
		var y := 4.6 + sin(_t * float(p.speed) + float(p.phase)) * 1.6
		node.position = Vector3(p.x, y, LANES[p.lane])
		if not p.taken:
			(p.item as Node3D).rotation.y += delta * 1.5
	for i in 4:
		_ride(i, delta)
	cam.fixed_center = Vector3(_avg_x(), 6.0, 0)


func _avg_x() -> float:
	var s := 0.0
	for r in riders:
		s += (r.holder as Node3D).position.x
	return s / 4.0


func _ride(i: int, delta: float) -> void:
	var r: Dictionary = riders[i]
	var h: Node3D = r.holder
	var rig: CharacterRig = r.rig
	r.cooldown = maxf(0.0, r.cooldown - delta)
	r.stun = maxf(0.0, r.stun - delta)
	if h.position.x < END_X:
		h.position.x += float(r.speed) * delta
		if h.position.x >= END_X:
			finish_player(i)
			rig.react("cheer")
	# Seilwechsel
	if r.switch > 0.0:
		r.switch = maxf(0.0, r.switch - delta)
		var t: float = 1.0 - r.switch / 0.35
		h.position.z = lerpf(r.z_from, r.z_to, t)
		h.position.y = ROPE_Y + sin(t * PI) * 1.2
	else:
		var mv := InputHub.move(i)
		if absf(mv.y) > 0.6 and r.stun <= 0.0 and r.drop <= 0.0:
			var target_lane := clampi(int(r.lane) + (1 if mv.y > 0 else -1), 0, LANES.size() - 1)
			if target_lane != r.lane and _lane_free(target_lane, h.position.x, i):
				r.z_from = LANES[r.lane]
				r.lane = target_lane
				r.z_to = LANES[target_lane]
				r.switch = 0.35
				Audio.sfx("whoosh", h.global_position, -6.0)
				rig.react("determined")
	# Greifen (Gummiseil)
	if r.drop <= 0.0 and r.cooldown <= 0.0 and r.stun <= 0.0 and InputHub.pressed(i, "a"):
		r.drop = 0.6
		r.cooldown = 0.85
		rig.squash(0.8, 1.3, 0.3)
		Audio.sfx("boing", h.global_position, -4.0)
	var depth := 0.0
	if r.drop > 0.0:
		r.drop = maxf(0.0, r.drop - delta)
		var t2: float = 1.0 - r.drop / 0.6
		depth = sin(t2 * PI) * 2.9
		if t2 > 0.35 and t2 < 0.65:
			_try_grab(i)
	rig.position.y = -1.6 - depth
	var bg: MeshInstance3D = r.bungee
	bg.scale.y = 1.0 + depth
	bg.position.y = 0.4 - (1.0 + depth) * 0.5
	if rig.current != "jump_air" and not rig.is_locked():
		rig.play("jump_air")


func _lane_free(lane: int, x: float, me: int) -> bool:
	for j in 4:
		if j != me and riders[j].lane == lane and absf((riders[j].holder as Node3D).position.x - x) < 1.6:
			return false
	return true


func _try_grab(i: int) -> void:
	var r: Dictionary = riders[i]
	var hand := (r.rig as Node3D).global_position + Vector3.UP * 0.5
	for p in pillars:
		if p.taken or p.lane != r.lane:
			continue
		var item: Node3D = p.item
		var ip := item.global_position
		if absf(ip.x - hand.x) < 1.0 and ip.y > REACH_Y - 1.0 and absf(ip.y - (hand.y - 0.3)) < 1.3:
			p.taken = true
			match p.kind:
				"bomb":
					FX.explosion(ip, 0.7)
					(r.rig as CharacterRig).set_soot(3.0)
					(r.rig as CharacterRig).react("big_hit")
					add_score(i, -2, ip + Vector3.UP)
					r.stun = 1.2
					r.speed = SPEED * 0.8
					get_tree().create_timer(1.5, false).timeout.connect(func() -> void: r.speed = SPEED)
					InputHub.rumble(i, 1.0, 0.3)
				"gold":
					add_score(i, 3, ip + Vector3.UP)
					FX.stars(ip, Color(1, 0.85, 0.2), 18)
					FX.coins_burst(ip, 6, true)
					Audio.sfx("powerup", ip)
					(r.rig as CharacterRig).react("coin_gain")
					InputHub.rumble(i, 0.5, 0.15)
				_:
					add_score(i, 1, ip + Vector3.UP)
					FX.stars(ip, Color(1, 1, 0.6), 10)
					Audio.sfx("coin", ip)
					InputHub.rumble(i, 0.3, 0.1)
			item.reparent(r.rig)
			var tw := item.create_tween()
			tw.tween_property(item, "scale", Vector3.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw.tween_callback(item.queue_free)
			return


func check_end() -> bool:
	return finish_order.size() >= 4


func compute_placements() -> Array[int]:
	race = false
	return super.compute_placements()


# --- CPU ---------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var r: Dictionary = riders[slot]
	var level: int = Game.players[slot].cpu_level
	var hx := (r.holder as Node3D).position.x
	var held := {}
	var mv := Vector2.ZERO
	var best_lane := int(r.lane)
	var best_val := -INF
	for p in pillars:
		if p.taken:
			continue
		var dx := float(p.x) - hx
		if dx < 0.4 or dx > 9.0:
			continue
		var val: float = {"gold": 3.0, "chest": 1.0, "bomb": -3.0}[p.kind] - dx * 0.15 - absf(int(p.lane) - int(r.lane)) * 0.6
		if p.kind != "bomb" and val > best_val:
			best_val = val
			best_lane = p.lane
	if best_lane != r.lane and level > 0 and randf() < 0.05 * level:
		mv.y = 1.0 if best_lane > r.lane else -1.0
	for p in pillars:
		if p.taken or p.lane != r.lane or p.kind == "bomb":
			continue
		var item_y: float = (p.item as Node3D).global_position.y
		var dx2 := float(p.x) - hx
		var lead := float(r.speed) * 0.2
		var tol: float = [0.9, 0.5, 0.25][level]
		if absf(dx2 - lead) < tol and item_y > REACH_Y - [1.4, 0.9, 0.5][level]:
			held["a"] = true
	for p in pillars:
		if not p.taken and p.lane == r.lane and p.kind == "bomb" and absf(float(p.x) - hx) < 1.0:
			held.erase("a")
	InputHub.set_virtual(slot, mv, held)
