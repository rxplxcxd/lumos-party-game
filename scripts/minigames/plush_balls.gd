extends MinigameBase
## Kuschel-Bälle-Hüpfen: Riesige, weiche Plüschbälle kullern über die Wolkenplattform. Kleine Bälle
## überspringt man (A), vor den ganz großen muss man flüchten – wer erwischt wird, kullert über den Rand.
## Die Bälle werden schneller und kommen aus allen Richtungen. Online: gleicher Spiel-Zufall überall.

const HALF := 8.0
const PASTEL := [Color("#ffb3c7"), Color("#ffe08a"), Color("#a8dcff"), Color("#c9b5ff"), Color("#b8f0b0"), Color("#ffc9a3")]

var balls: Array[Dictionary] = []
var _spawn_t := 1.6
var _wave := 0


func _init() -> void:
	game_id = "plush_balls"
	env_preset = "sky"
	time_limit = 50.0
	survival = true
	hazard = "fall"
	kill_y = -6.0
	arena_radius = 10.0
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 12)
	spawn_points = [Vector3(-2.5, 0.6, -2.5), Vector3(2.5, 0.6, -2.5), Vector3(-2.5, 0.6, 2.5), Vector3(2.5, 0.6, 2.5)]


func build_arena() -> void:
	# Kariertes Kissen als Spielfläche
	for x in 8:
		for z in 8:
			var col := Color("#fff3f8") if (x + z) % 2 == 0 else Color("#ffe0ec")
			WorldKit.box(world, Vector3(2.0, 0.8, 2.0), Vector3(-HALF + 1.0 + x * 2.0, -0.4, -HALF + 1.0 + z * 2.0), col)
	for side in [-1.0, 1.0]:
		for k in 9:
			var t := -HALF + k * 2.0
			WorldKit.place(world, "plat/fence", Vector3(t, 0, side * (HALF + 0.3)), 0.0 if side > 0 else 180.0, 1.6)
	# Wolken ringsum
	for i in 22:
		var a := TAU * i / 22.0
		var puff := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = randf_range(2.0, 4.0)
		sm.height = sm.radius * 1.3
		sm.material = WorldKit.mat(Color(1, 1, 1), 1.0, 0.2)
		puff.mesh = sm
		world.add_child(puff)
		puff.position = Vector3(cos(a) * randf_range(16, 26), randf_range(-8, -3), sin(a) * randf_range(16, 26))
	for i in 4:
		WorldKit.place(world, "plat/flag", Vector3([-1, 1, -1, 1][i] * (HALF + 1.2), 0, [-1, -1, 1, 1][i] * (HALF + 1.2)), 0.0, 1.6)


func on_start() -> void:
	for av in avatars:
		(av as PartyAvatar).rig.surface = "cloud"
		(av as PartyAvatar).can_shove = false
		(av as PartyAvatar).jump_velocity = 11.0


func on_tick(delta: float) -> void:
	_spawn_t -= delta
	var prog := 1.0 - time_left / time_limit
	if _spawn_t <= 0.0:
		_wave += 1
		_spawn_t = lerpf(1.7, 0.7, prog)
		var n := 1 + (1 if prog > 0.4 and rng.randf() < 0.5 else 0) + (1 if prog > 0.75 and rng.randf() < 0.4 else 0)
		for _k in n:
			_spawn_ball(prog)
	for b in balls.duplicate():
		var node: Node3D = b.node
		var vel: Vector3 = b.vel
		node.position += vel * delta
		var r: float = b.r
		node.rotate(Vector3(vel.z, 0, -vel.x).normalized(), vel.length() * delta / r)
		var body: Node3D = b.body
		body.position.y = absf(sin(Time.get_ticks_msec() / 160.0 + float(b.ph))) * 0.25
		if absf(node.position.x) > HALF + 6.0 or absf(node.position.z) > HALF + 6.0:
			balls.erase(b)
			node.queue_free()
			continue
		for i in active_slots():
			var av := avatars[i] as PartyAvatar
			if not alive[i] or not av.alive or av.net_remote:
				continue
			var d := av.global_position - node.position
			var feet := av.global_position.y
			if Vector2(d.x, d.z).length() < r + 0.4 and feet < r * 1.55:
				var dir := (Vector3(d.x, 0, d.z).normalized() * 0.4 + vel.normalized()).normalized()
				av.apply_knockback(dir, 18.0 + r * 4.0, 1.2, 9.0)
				av.rig.react("launch")
				Audio.sfx("boing", av.global_position, 2.0)
				FX.stars(av.global_position + Vector3.UP * 1.5, PASTEL[int(b.c)], 10)
				Juice.shake(0.2)
				InputHub.rumble(i, 0.8, 0.25)


func _spawn_ball(prog: float) -> void:
	var big := rng.randf() < lerpf(0.15, 0.4, prog)
	var r := 1.7 if big else 0.75
	var side := rng.randi() % 4
	var lane := rng.randf_range(-HALF + 1.2, HALF - 1.2)
	var speed := lerpf(5.0, 9.5, prog) * (0.75 if big else 1.0)
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	match side:
		0:
			pos = Vector3(-HALF - 3.0, r, lane)
			vel = Vector3(speed, 0, 0)
		1:
			pos = Vector3(HALF + 3.0, r, lane)
			vel = Vector3(-speed, 0, 0)
		2:
			pos = Vector3(lane, r, -HALF - 3.0)
			vel = Vector3(0, 0, speed)
		_:
			pos = Vector3(lane, r, HALF + 3.0)
			vel = Vector3(0, 0, -speed)
	var c := rng.randi() % PASTEL.size()
	var root := Node3D.new()
	world.add_child(root)
	root.position = pos
	var body := Node3D.new()
	root.add_child(body)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.material = WorldKit.mat(PASTEL[c], 1.0, 0.05)
	ball.mesh = sm
	body.add_child(ball)
	# Naht + Knopfaugen = Plüsch-Look
	var seam := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r * 0.98
	tm.outer_radius = r * 1.03
	tm.material = WorldKit.mat(PASTEL[c].darkened(0.25), 1.0)
	seam.mesh = tm
	body.add_child(seam)
	for e in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = r * 0.12
		es.height = r * 0.24
		es.material = WorldKit.mat(Color(0.1, 0.08, 0.12), 0.3)
		eye.mesh = es
		eye.position = Vector3(e * r * 0.32, r * 0.25, -r * 0.92)
		body.add_child(eye)
	balls.append({"node": root, "body": body, "vel": vel, "r": r, "c": c, "ph": rng.randf() * 6.0})
	if big:
		Audio.sfx("drop", pos, -4.0, 0.7)
	Juice.pop_in(body, 0.3)


func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	if not alive[slot]:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var pos := av.global_position
	var flee := Vector2.ZERO
	var held := {}
	for b in balls:
		var node: Node3D = b.node
		var vel: Vector3 = b.vel
		var rel := Vector2(pos.x - node.position.x, pos.z - node.position.z)
		var dir := Vector2(vel.x, vel.z).normalized()
		var along := rel.dot(dir)
		if along < -1.0:
			continue
		var perp := rel - dir * along
		var t := along / maxf(vel.length(), 0.1)
		if perp.length() < float(b.r) + 0.9 and t < Game.lv([0.55, 0.8, 1.1], level):
			if float(b.r) < 1.0 and t < 0.32 and randf() < Game.lv([0.7, 0.85, 0.97], level):
				held["a"] = true
			elif float(b.r) >= 1.0:
				flee += Vector2(-dir.y, dir.x) * (1.0 if perp.cross(dir) < 0.0 else -1.0)
	flee += -Vector2(pos.x, pos.z) / HALF * 0.35
	InputHub.set_virtual(slot, flee.limit_length(1.0), held)
