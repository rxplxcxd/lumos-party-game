extends MinigameBase
## Schleim-Spur Sprint: Ein Sprint-Parcours zu Fuß. Grüne Schleimpfützen sind spiegelglatt,
## Pendel-Fallen schwingen gnadenlos quer über die Bahn und Baumstämme wollen übersprungen
## werden. Wer zuerst durchs Ziel läuft, gewinnt.

const LENGTH := 96.0
const HALF_W := 5.0

var slimes: Array[Dictionary] = []
var pendulums: Array[Dictionary] = []
var logs: Array[Dictionary] = []
var _t := 0.0


func _init() -> void:
	game_id = "slime_sprint"
	env_preset = "day"
	time_limit = 45.0
	race = true
	respawn_on_fall = true
	kill_y = -6.0
	hazard = "void"
	arena_radius = 10.0
	arena_center = Vector3(0, 0, -6)
	cannon_pos = Vector3(-9, 0, 8)
	spawn_points = [Vector3(-3.6, 0.3, 2.5), Vector3(-1.2, 0.3, 2.5), Vector3(1.2, 0.3, 2.5), Vector3(3.6, 0.3, 2.5)]


func build_arena() -> void:
	var tiles: Array = []
	for z in range(4, -int(LENGTH) - 10, -6):
		for x in [-3.0, 3.0]:
			tiles.append(Transform3D(Basis(), Vector3(x, -1.0, z)))
	WorldKit.multimesh(world, "mg/tile_large_forest", tiles)
	var ground := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(HALF_W * 2.0 + 2.0, 1.0, LENGTH + 20)
	cs.shape = bs
	ground.add_child(cs)
	world.add_child(ground)
	ground.position = Vector3(0, -0.5, -LENGTH * 0.5 + 2)
	for side in [-1.0, 1.0]:
		var wall := WorldKit.box(world, Vector3(0.4, 1.2, LENGTH + 20), Vector3(side * (HALF_W + 1.2), 0.6, -LENGTH * 0.5 + 2), Color(0.5, 0.35, 0.2), true)
		wall.visible = false
		for z in range(2, -int(LENGTH) - 8, -4):
			WorldKit.place(world, "plat/fence", Vector3(side * (HALF_W + 1.1), 0, z), 90.0, 2.0)
	# Schleim
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 1.0, 0.3, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.9, 0.2)
	mat.emission_energy_multiplier = 0.5
	mat.roughness = 0.05
	for i in 12:
		var z := -8.0 - i * 7.0 + randf_range(-1.5, 1.5)
		var x := randf_range(-HALF_W + 1.5, HALF_W - 1.5)
		var r := randf_range(1.4, 2.4)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = 0.05
		cm.material = mat
		mi.mesh = cm
		mi.position = Vector3(x, 0.03, z)
		mi.scale = Vector3(1.0, 1.0, randf_range(0.7, 1.3))
		world.add_child(mi)
		slimes.append({"pos": Vector2(x, z), "r": r})
	# Pendel-Fallen
	for i in 7:
		var z := -14.0 - i * 12.0
		var frame := Node3D.new()
		world.add_child(frame)
		frame.position = Vector3(0, 0, z)
		for side in [-1.0, 1.0]:
			WorldKit.cylinder(frame, 0.25, 8.0, Vector3(side * (HALF_W + 0.6), 4.0, 0), Color("#6a4a2a"), false)
		var beam := WorldKit.box(frame, Vector3(HALF_W * 2.0 + 2.0, 0.4, 0.4), Vector3(0, 8.0, 0), Color("#6a4a2a"), false)
		var pivot := Node3D.new()
		frame.add_child(pivot)
		pivot.position = Vector3(0, 7.8, 0)
		var chain := MeshInstance3D.new()
		var ch := CylinderMesh.new()
		ch.top_radius = 0.07
		ch.bottom_radius = 0.07
		ch.height = 6.0
		ch.material = WorldKit.mat(Color(0.5, 0.5, 0.55), 0.3)
		chain.mesh = ch
		chain.position = Vector3(0, -3.0, 0)
		pivot.add_child(chain)
		var ball := Assets.spawn("mg/spike_roller", pivot, Vector3(0, -7.0, 0), 0.0, 0.85)
		ball.position = Vector3(0, -7.85, 0)
		pendulums.append({"pivot": pivot, "phase": randf() * TAU, "speed": randf_range(1.5, 2.3), "z": z})
	# Baumstämme
	for i in 6:
		var z := -20.0 - i * 13.0 + 6.0
		var lg := Assets.spawn("nat/log", world, Vector3(randf_range(-2, 2), 0, z), 90.0, 3.2)
		var body := StaticBody3D.new()
		var bcs := CollisionShape3D.new()
		var bb := BoxShape3D.new()
		bb.size = Vector3(4.5, 0.7, 0.8)
		bcs.shape = bb
		bcs.position.y = 0.35
		body.add_child(bcs)
		world.add_child(body)
		body.position = lg.position
		logs.append({"z": z, "x": lg.position.x})
	# Ziel
	var gate := WorldKit.place(world, "toy/gate_finish", Vector3(0, 0, -LENGTH), 0.0, 7.5)
	for x in [-HALF_W - 2.0, HALF_W + 2.0]:
		WorldKit.place(world, "race/flag_checkers", Vector3(x, 0, -LENGTH), 0.0, 3.0)
		WorldKit.place(world, "race/grandstand", Vector3(x * 1.6, 0, -LENGTH + 4), 90.0 if x < 0 else -90.0, 4.0)
	var keys := ["nat/tree_oak", "nat/tree_default", "plat/tree", "nat/flower_red", "for/tree_a", "for/bush", "plat/mushrooms"]
	for k in 44:
		var side := -1.0 if k % 2 == 0 else 1.0
		var z := 6.0 - k * (LENGTH + 12.0) / 44.0
		WorldKit.place(world, keys[k % keys.size()], Vector3(side * randf_range(8.5, 16.0), 0, z), randf() * 360.0, randf_range(2.0, 3.2), false, false)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, 0)
	c.offset = Vector3(0, 9.0, 11.5)
	c.center_weight = 0.0
	c.min_dist = 1.0
	c.max_dist = 1.35
	c.spread_ref = 16.0


func on_start() -> void:
	for av in avatars:
		(av as PartyAvatar).rig.surface = "grass"
		(av as PartyAvatar).can_shove = false
		(av as PartyAvatar).max_speed = 8.5


func on_tick(delta: float) -> void:
	_t += delta
	for p in pendulums:
		var piv: Node3D = p.pivot
		piv.rotation.z = sin(_t * float(p.speed) + float(p.phase)) * 1.05
	for i in 4:
		var av := avatars[i] as PartyAvatar
		if not av.alive or i in finish_order:
			continue
		var fp := Vector2(av.global_position.x, av.global_position.z)
		var on_slime := false
		for s in slimes:
			if fp.distance_to(s.pos) < float(s.r) * 0.95:
				on_slime = true
		if on_slime and av.slippery < 0.5 and av.velocity.length() > 5.0 and randf() < 0.35:
			av.rig.react("slip")
			av.stun(0.6)
			FX.slime(av.global_position, 0.8)
		av.slippery = 1.0 if on_slime else 0.0
		av.rig.surface = "slime" if on_slime else "grass"
		# Pendel-Treffer
		for p in pendulums:
			var piv2: Node3D = p.pivot
			var ball := piv2.global_position + piv2.global_basis.y * -7.0
			if av.global_position.distance_to(ball) < 1.7 and not av.is_stunned():
				var dir := Vector3(signf(av.global_position.x - ball.x) * 0.6, 0, 1.0)
				av.apply_knockback(dir, 15.0, 1.0, 6.0)
				av.rig.react("big_hit")
				Audio.sfx("metal_hit", ball)
				Juice.shake(0.3)
				Juice.hitstop(0.07)
				InputHub.rumble(i, 0.9, 0.25)
		scores[i] = clampf(-av.global_position.z / LENGTH * 100.0, 0, 100)
		if av.global_position.z < -LENGTH:
			finish_player(i)
			av.freeze(true)
			FX.confetti(av.global_position + Vector3.UP * 3.0, 50)
			av.rig.react("victory")
	var lead := 0.0
	for i in 4:
		lead = minf(lead, (avatars[i] as Node3D).global_position.z)
	cam.fixed_center = Vector3(0, 0, lead + 3.0)


func check_end() -> bool:
	return finish_order.size() >= 4


func _update_badges() -> void:
	for i in badges.size():
		if i in finish_order:
			badges[i].set_status("done", finish_order.find(i) + 1)
		else:
			badges[i].set_status("", "%d%%" % int(scores[i]))


# --- CPU ---------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	if not av.alive or slot in finish_order:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var pos := av.global_position
	var mv := Vector2(0, -1)
	var held := {}
	# Schleim ausweichen
	for s in slimes:
		var sp: Vector2 = s.pos
		if sp.y < pos.z and sp.y > pos.z - 6.0 and absf(sp.x - pos.x) < float(s.r) + 0.6 and level > 0:
			mv.x = 1.0 if pos.x < sp.x else -1.0
			if absf(sp.x) + float(s.r) > HALF_W - 1.0:
				mv.x = -signf(sp.x)
	# Baumstämme überspringen
	for l in logs:
		var dz := pos.z - float(l.z)
		if dz > 0.4 and dz < 1.9 and av.is_on_floor():
			if randf() < [0.6, 0.85, 1.0][level]:
				held["a"] = true
	# Pendel abwarten
	for p in pendulums:
		var dz2 := pos.z - float(p.z)
		if dz2 > 0.5 and dz2 < 3.6 and level > 0:
			var piv: Node3D = p.pivot
			var ball_x := (piv.global_position + piv.global_basis.y * -7.0).x
			var swing_v := cos(_t * float(p.speed) + float(p.phase))
			var coming := signf(swing_v) == signf(pos.x - ball_x) or absf(ball_x - pos.x) < 2.5
			if coming and absf(ball_x - pos.x) < [1.5, 3.0, 4.0][level]:
				mv.y = 0.3
	mv.x += -pos.x * 0.05
	InputHub.set_virtual(slot, mv.limit_length(1.0) * [0.8, 0.92, 1.0][level], held)
