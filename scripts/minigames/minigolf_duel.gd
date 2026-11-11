extends MinigameBase
## Minigolf-Duell: Alle putten gleichzeitig auf dieselbe Bahn! Stick = Zielen, A halten = Kraft
## laden (pendelt!), loslassen = Schlag. Bälle prallen voneinander und von Pilz-Bumpern ab.
## Wer zuerst einlocht, bekommt 4 Punkte, dann 3, 2, 1. Drei Löcher.

const HALF_X := 9.0
const HALF_Z := 6.5
const BALL_R := 0.22
const HOLE_R := 0.42
const MAX_SHOT := 17.0
const HOLES := [Vector3(6.5, 0, -3.5), Vector3(-6.0, 0, 3.8), Vector3(0.0, 0, -4.6)]
const TEES := [Vector3(-6.5, 0, 3.5), Vector3(6.0, 0, -3.8), Vector3(0.0, 0, 4.8)]

var balls: Array[Dictionary] = []
var bumpers: Array[Dictionary] = []
var blocks: Array[Rect2] = []
var hole_idx := 0
var hole_pos := Vector3.ZERO
var sunk_order: Array[int] = []
var _hole_node: Node3D
var _flag: Node3D
var _hole_time := 0.0
var _between := false


func _init() -> void:
	game_id = "minigolf_duel"
	touch_profile = "golf"
	env_preset = "day"
	time_limit = 75.0
	arena_radius = 10.0
	teaser_height = 0.9
	cannon_pos = Vector3(0, 0, 12)


func build_arena() -> void:
	WorldKit.box(world, Vector3(HALF_X * 2 + 1.0, 1.0, HALF_Z * 2 + 1.0), Vector3(0, -0.5, 0), Color("#3fae4a"))
	# Banden
	var wood := Color("#c8874a")
	for side in [-1.0, 1.0]:
		WorldKit.box(world, Vector3(HALF_X * 2 + 1.6, 0.5, 0.4), Vector3(0, 0.25, side * (HALF_Z + 0.3)), wood, false)
		WorldKit.box(world, Vector3(0.4, 0.5, HALF_Z * 2 + 1.6), Vector3(side * (HALF_X + 0.3), 0.25, 0), wood, false)
	# Hindernisse (Rechtecke in XZ) & Bumper
	blocks = [Rect2(-1.2, -1.6, 2.4, 0.6), Rect2(-4.2, 0.2, 0.6, 2.6), Rect2(3.6, -2.4, 0.6, 2.6)]
	for r in blocks:
		WorldKit.box(world, Vector3(r.size.x, 0.6, r.size.y), Vector3(r.get_center().x, 0.3, r.get_center().y), Color("#8a6a4a"), false)
	for bp in [Vector3(0, 0, 1.4), Vector3(-2.2, 0, -3.4), Vector3(2.6, 0, 3.2), Vector3(-7.0, 0, -1.0), Vector3(7.0, 0, 1.2)]:
		var m := Assets.spawn("plat/mushrooms", world, bp, randf() * 360.0, 1.0)
		bumpers.append({"pos": bp, "r": 0.7, "node": m})
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.62
		tm.outer_radius = 0.74
		tm.material = WorldKit.mat(Color("#ff4fb8"), 0.4, 1.0)
		ring.mesh = tm
		world.add_child(ring)
		ring.position = bp + Vector3.UP * 0.08
	# Deko ringsum
	for i in 14:
		var a := TAU * i / 14.0
		var pos := Vector3(cos(a) * (HALF_X + 3.0), 0, sin(a) * (HALF_Z + 3.0))
		WorldKit.place(world, ["golf/castle", "plat/tree", "plat/flowers", "nat/bush", "golf/obstacle_diamond", "plat/fence", "nat/tree_oak"][i % 7], pos, rad_to_deg(-a), 1.6)
	_hole_node = Node3D.new()
	world.add_child(_hole_node)
	var cup := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = HOLE_R
	cm.bottom_radius = HOLE_R
	cm.height = 0.02
	cm.material = WorldKit.mat(Color(0.03, 0.05, 0.03), 1.0)
	cup.mesh = cm
	cup.position.y = 0.012
	_hole_node.add_child(cup)
	_flag = Assets.spawn("golf/flag", _hole_node, Vector3.ZERO, 0.0, 1.6)
	var glow := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.4, 2.4)
	q.orientation = PlaneMesh.FACE_Y
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_texture = FX.tex_ring
	gm.albedo_color = Color(1, 1, 0.6, 0.6)
	q.material = gm
	glow.mesh = q
	glow.position.y = 0.03
	_hole_node.add_child(glow)
	var ps: Array[Vector3] = []
	for i in 4:
		ps.append(TEES[0] + Vector3(-1.0 + (i % 2) * 2.0, 0.5, -0.6 + (i >> 1) * 1.2) * 1.0 + Vector3(0, 0, 0))
	spawn_points = ps


func spawn_players() -> void:
	super.spawn_players()
	var keys := ["golf/ball_red", "golf/ball_blue", "golf/ball_green", "golf/ball_red"]
	for i in 4:
		var node := Assets.spawn(keys[i], world, Vector3.ZERO, 0.0, 1.0)
		var bb := Assets.model_aabb(keys[i])
		node.scale = Vector3.ONE * (BALL_R * 2.0 / maxf(bb.size.x, 0.01)) * 1.25
		if i == 3:
			Assets.tint(node, Color(1.6, 1.4, 0.2))
		# Farbring unter dem Ball für Übersicht
		var mark := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		q.orientation = PlaneMesh.FACE_Y
		var mm := StandardMaterial3D.new()
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mm.albedo_texture = FX.tex_ring
		mm.albedo_color = Game.player_color(i)
		q.material = mm
		mark.mesh = q
		world.add_child(mark)
		var aim := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.04, 1.0)
		bm.material = WorldKit.mat(Game.player_color(i), 0.4, 1.2)
		aim.mesh = bm
		world.add_child(aim)
		aim.visible = false
		balls.append({"node": node, "pos": Vector2.ZERO, "vel": Vector2.ZERO, "aim": Vector2(0, -1), "charge": 0.0, "charging": false,
			"sunk": false, "aim_node": aim, "strokes": 0, "best": INF, "stuck": 0, "mark": mark, "scl": node.scale})
	_place_hole(0)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, 0.5)
	c.offset = Vector3(0, 15.5, 11.0)
	c.min_dist = 1.0
	c.max_dist = 1.0
	c.follow = false


func _place_hole(idx: int) -> void:
	hole_idx = idx
	hole_pos = HOLES[idx]
	_hole_node.position = hole_pos
	Juice.pop_in(_flag, 0.4)
	sunk_order.clear()
	_hole_time = 0.0
	var tee: Vector3 = TEES[idx]
	for i in 4:
		var b: Dictionary = balls[i]
		var p := Vector2(tee.x, tee.z) + Vector2(-0.9 + (i % 2) * 1.8, -0.5 + (i >> 1) * 1.0)
		b.pos = p
		b.vel = Vector2.ZERO
		b.sunk = false
		b.charge = 0.0
		b.charging = false
		b.best = INF
		b.stuck = 0
		var to := Vector2(hole_pos.x, hole_pos.z) - p
		b.aim = to.normalized()
		(b.node as Node3D).visible = true
		(b.node as Node3D).scale = b.scl
		(b.mark as Node3D).visible = true
		(b.node as Node3D).position = Vector3(p.x, BALL_R, p.y)
		var av := avatars[i] as PartyAvatar
		av.global_position = Vector3(p.x, 0, p.y) - Vector3(b.aim.x, 0, b.aim.y) * 0.9
		av.visible = true


func on_start() -> void:
	for i in 4:
		var av := avatars[i] as PartyAvatar
		av.can_move = false
		av.can_jump = false
		av.can_shove = false
		av.set_physics_process(false)
		av.rig.surface = "grass"


func on_tick(delta: float) -> void:
	_hole_time += delta
	_flag.rotation.y = sin(_hole_time * 2.0) * 0.15
	for i in 4:
		_control(i, delta)
	for i in 4:
		_simulate(i, delta)
	_collide_balls()
	for i in 4:
		_update_golfer(i, delta)
	if not _between and (sunk_order.size() >= 4 or _hole_time > 24.0 or (sunk_order.size() >= 3 and _hole_time > 16.0)):
		_next_hole()


func _control(i: int, delta: float) -> void:
	var b: Dictionary = balls[i]
	var aim_node: MeshInstance3D = b.aim_node
	var vel: Vector2 = b.vel
	if b.sunk or _between or vel.length() > 0.25:
		aim_node.visible = false
		b.charging = false
		return
	var mv := InputHub.move(i)
	if mv.length() > 0.35:
		var want := mv.normalized()
		b.aim = (b.aim as Vector2).slerp(want, clampf(delta * 10.0, 0.0, 1.0)).normalized()
	if InputHub.held(i, "a"):
		if not b.charging:
			b.charging = true
			b.charge = 0.0
		b.charge = float(b.charge) + delta
	elif b.charging:
		b.charging = false
		_shoot(i, _power(float(b.charge)))
	var pw := _power(float(b.charge)) if b.charging else 0.25
	var p: Vector2 = b.pos
	var aim: Vector2 = b.aim
	aim_node.visible = true
	var length := 0.6 + pw * 3.2
	aim_node.scale = Vector3(1.0, 1.0, length)
	aim_node.position = Vector3(p.x + aim.x * (0.35 + length * 0.5), 0.06, p.y + aim.y * (0.35 + length * 0.5))
	aim_node.rotation.y = atan2(aim.x, aim.y)


## Kraft pendelt 0..1..0 alle 1,3 s.
func _power(t: float) -> float:
	return 1.0 - absf(fmod(t / 0.65, 2.0) - 1.0)


func _shoot(i: int, power: float) -> void:
	var b: Dictionary = balls[i]
	var pw := clampf(power, 0.06, 1.0)
	b.vel = (b.aim as Vector2) * MAX_SHOT * pw
	b.strokes = int(b.strokes) + 1
	var av := avatars[i] as PartyAvatar
	av.rig.play("slice", 0.03, 1.6, true)
	av.rig.lock(0.4)
	Audio.sfx("wood_hit", (b.node as Node3D).position, -4.0 + pw * 4.0, 1.6 - pw * 0.4)
	InputHub.rumble(i, 0.2 + pw * 0.4, 0.08)
	if pw > 0.9:
		FX.ring((b.node as Node3D).position, Game.player_color(i), 1.5, 0.3)


func _simulate(i: int, delta: float) -> void:
	var b: Dictionary = balls[i]
	if b.sunk:
		return
	var vel: Vector2 = b.vel
	var pos: Vector2 = b.pos
	var steps := 3
	var h := delta / steps
	for _s in steps:
		pos += vel * h
		# Banden
		if absf(pos.x) > HALF_X - BALL_R:
			pos.x = signf(pos.x) * (HALF_X - BALL_R)
			vel.x = -vel.x * 0.8
			_clack(pos, vel.length())
		if absf(pos.y) > HALF_Z - BALL_R:
			pos.y = signf(pos.y) * (HALF_Z - BALL_R)
			vel.y = -vel.y * 0.8
			_clack(pos, vel.length())
		# Blöcke
		for r in blocks:
			var grown := r.grow(BALL_R)
			if grown.has_point(pos):
				var dl := pos.x - grown.position.x
				var dr := grown.end.x - pos.x
				var dt := pos.y - grown.position.y
				var db := grown.end.y - pos.y
				var m := minf(minf(dl, dr), minf(dt, db))
				if m == dl:
					pos.x = grown.position.x
					vel.x = -absf(vel.x) * 0.8
				elif m == dr:
					pos.x = grown.end.x
					vel.x = absf(vel.x) * 0.8
				elif m == dt:
					pos.y = grown.position.y
					vel.y = -absf(vel.y) * 0.8
				else:
					pos.y = grown.end.y
					vel.y = absf(vel.y) * 0.8
				_clack(pos, vel.length())
		# Bumper: schleudern mit Extraschwung
		for bm in bumpers:
			var bp: Vector3 = bm.pos
			var d := pos - Vector2(bp.x, bp.z)
			var rr: float = float(bm.r) + BALL_R
			if d.length() < rr and d.length() > 0.001:
				var n := d.normalized()
				pos = Vector2(bp.x, bp.z) + n * rr
				vel = vel - 2.0 * vel.dot(n) * n
				vel += n * 3.5
				Audio.sfx("boing", Vector3(pos.x, 0, pos.y), -6.0, 1.2)
				Juice.squash(bm.node, 1.3, 0.7, 0.3, (bm.node as Node3D).scale)
	# Rollreibung
	var spd := vel.length()
	if spd > 0.0:
		spd = maxf(0.0, spd - (1.8 + spd * 0.35) * delta)
		vel = vel.normalized() * spd
	# Loch
	var to_hole := Vector2(hole_pos.x, hole_pos.z) - pos
	if to_hole.length() < HOLE_R and not _between:
		if spd < 9.0:
			_sink(i)
			b.pos = pos
			b.vel = Vector2.ZERO
			return
		else:
			# zu schnell: Lippe – leichte Ablenkung
			vel = vel.rotated(randf_range(-0.6, 0.6)) * 0.7
			Audio.sfx("metal_light", hole_pos, -4.0, 1.5)
	elif to_hole.length() < HOLE_R * 2.5 and spd < 4.0 and spd > 0.05:
		vel += to_hole.normalized() * 2.5 * delta   # Trichter-Sog
	if spd < 0.25 and float((b.vel as Vector2).length()) >= 0.25:
		# gerade liegen geblieben: Fortschritt merken (für CPU-Bandenlogik)
		var dist := to_hole.length()
		if dist > float(b.best) - 0.3:
			b.stuck = int(b.stuck) + 1
		else:
			b.stuck = 0
		b.best = minf(float(b.best), dist)
	if spd < 0.25:
		vel = Vector2.ZERO
	b.vel = vel
	b.pos = pos
	var node: Node3D = b.node
	node.position = Vector3(pos.x, BALL_R, pos.y)
	(b.mark as Node3D).position = Vector3(pos.x, 0.04, pos.y)
	if vel.length() > 0.1:
		node.rotate(Vector3(vel.y, 0, -vel.x).normalized(), vel.length() * delta / BALL_R)


func _clack(pos: Vector2, speed: float) -> void:
	if speed > 2.0:
		Audio.sfx("wood_hit", Vector3(pos.x, 0.2, pos.y), -12.0 + minf(speed, 12.0), 1.8)


func _collide_balls() -> void:
	for a in 4:
		for c in range(a + 1, 4):
			var ba: Dictionary = balls[a]
			var bc: Dictionary = balls[c]
			if ba.sunk or bc.sunk:
				continue
			var d: Vector2 = bc.pos - ba.pos
			var dist := d.length()
			if dist < BALL_R * 2.0 and dist > 0.0001:
				var n := d / dist
				var overlap := BALL_R * 2.0 - dist
				ba.pos = (ba.pos as Vector2) - n * overlap * 0.5
				bc.pos = (bc.pos as Vector2) + n * overlap * 0.5
				var rel: float = ((ba.vel as Vector2) - (bc.vel as Vector2)).dot(n)
				if rel > 0.0:
					ba.vel = (ba.vel as Vector2) - n * rel * 0.95
					bc.vel = (bc.vel as Vector2) + n * rel * 0.95
					Audio.sfx("click", Vector3(ba.pos.x, 0, ba.pos.y), -2.0, 1.4)


func _sink(i: int) -> void:
	var b: Dictionary = balls[i]
	b.sunk = true
	sunk_order.append(i)
	var pts: int = [4, 3, 2, 1][sunk_order.size() - 1]
	add_score(i, pts, hole_pos + Vector3.UP * 2.2)
	var node: Node3D = b.node
	(b.mark as Node3D).visible = false
	var tw := node.create_tween()
	tw.tween_property(node, "position", hole_pos + Vector3.DOWN * 0.1, 0.12)
	tw.tween_property(node, "scale", Vector3.ZERO, 0.1)
	Audio.sfx("coin", hole_pos, 0.0, 1.0 + sunk_order.size() * 0.1)
	FX.confetti(hole_pos + Vector3.UP * 0.5, 30 if sunk_order.size() == 1 else 14)
	FX.stars(hole_pos + Vector3.UP * 0.8, Game.player_color(i).lightened(0.4), 10)
	Juice.float_text(self, hole_pos + Vector3.UP * 3.2, "EINGELOCHT!" if int(b.strokes) > 1 else "HOLE IN ONE!", Game.player_color(i).lightened(0.4), 90)
	(avatars[i] as PartyAvatar).rig.react("victory" if sunk_order.size() == 1 else "cheer")
	InputHub.rumble(i, 0.6, 0.2)
	if sunk_order.size() == 1:
		Audio.voice("correct")


func _next_hole() -> void:
	_between = true
	for i in 4:
		var b: Dictionary = balls[i]
		b.strokes = 0
		if not b.sunk:
			(avatars[i] as PartyAvatar).rig.react("frustrated")
	await get_tree().create_timer(1.4, false).timeout
	if state != "play":
		return
	if hole_idx + 1 >= HOLES.size():
		end_game()
		return
	await CutsceneManager.big_word("Loch %d" % (hole_idx + 2), UI.GOLD, 0.6)
	_place_hole(hole_idx + 1)
	_between = false


func check_end() -> bool:
	return false


func _update_golfer(i: int, delta: float) -> void:
	var b: Dictionary = balls[i]
	var av := avatars[i] as PartyAvatar
	if b.sunk:
		return
	var p: Vector2 = b.pos
	var aim: Vector2 = b.aim
	var target := Vector3(p.x, 0, p.y) - Vector3(aim.x, 0, aim.y) * 0.9 + Vector3(-aim.y, 0, aim.x) * 0.35
	var cur := av.global_position
	var step := target - cur
	var moving := step.length() > 0.1 and (b.vel as Vector2).length() < 0.25
	if moving:
		av.global_position = cur + step.limit_length(6.0 * delta)
		av.rig.face(step, delta, 10.0)
		av.rig.locomote(6.0, 7.0, true, 0.0, delta)
	elif (b.vel as Vector2).length() < 0.25:
		av.rig.face(Vector3(aim.x, 0, aim.y), delta, 10.0)
		if not av.rig.is_locked():
			av.rig.play("hold" if b.charging else "idle", 0.15)


func cpu_think(slot: int, _delta: float) -> void:
	var b: Dictionary = balls[slot] if slot < balls.size() else {}
	if b.is_empty() or b.sunk or _between:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var mem := cpu_mem[slot]
	var vel: Vector2 = b.vel
	if vel.length() > 0.25:
		mem.erase("plan")
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var pos: Vector2 = b.pos
	if not mem.has("plan"):
		var target := Vector2(hole_pos.x, hole_pos.z)
		var dir := (target - pos).normalized()
		var dist := pos.distance_to(target)
		var blocked := _path_blocked(pos, target)
		if blocked or int(b.stuck) >= 2:
			# Bandenschlag: Ziel an einer Bande spiegeln, bestes nehmen
			var opts: Array[Vector2] = [Vector2(target.x, 2.0 * HALF_Z - target.y), Vector2(target.x, -2.0 * HALF_Z - target.y),
				Vector2(2.0 * HALF_X - target.x, target.y), Vector2(-2.0 * HALF_X - target.x, target.y)]
			var best := opts[randi() % opts.size()]
			for o in opts:
				if not _path_blocked(pos, pos.lerp(o, 0.5)) and randf() < 0.6:
					best = o
					break
			dir = (best - pos).normalized()
			dist = pos.distance_to(best)
		var noise: float = Game.lv([0.22, 0.12, 0.05], level, true)
		dir = dir.rotated(randf_range(-noise, noise))
		# benötigte Startgeschwindigkeit grob aus der Reibung: v ≈ sqrt(2·a·d) + Reserve
		var need := sqrt(2.0 * 2.6 * dist) + 1.0
		var pw := clampf(need / MAX_SHOT * randf_range(1.0 - noise, 1.0 + noise), 0.08, 1.0)
		mem["plan"] = {"dir": dir, "power": pw, "wait": randf_range(0.4, 1.2) - level * 0.2}
	var plan: Dictionary = mem.plan
	plan.wait = float(plan.wait) - get_physics_process_delta_time()
	var held := {}
	var aim: Vector2 = b.aim
	var want: Vector2 = plan.dir
	if aim.dot(want) < 0.995 or float(plan.wait) > 0.0:
		InputHub.set_virtual(slot, want, {})
		return
	# Kraft laden, bis die Pendel-Kraft passt (erste Aufwärtsphase), dann loslassen
	var charge := float(b.charge) if b.charging else 0.0
	var target_t := float(plan.power) * 0.65
	if not b.charging or charge < target_t:
		held["a"] = true
	InputHub.set_virtual(slot, want * 0.4, held)


func _path_blocked(a: Vector2, c: Vector2) -> bool:
	for k in 12:
		var p := a.lerp(c, (k + 1) / 13.0)
		for r in blocks:
			if r.grow(BALL_R + 0.1).has_point(p):
				return true
		for bm in bumpers:
			var bp: Vector3 = bm.pos
			if p.distance_to(Vector2(bp.x, bp.z)) < float(bm.r) + 0.25:
				return true
	return false
