extends MinigameBase
## Plank-Panic: Alle stehen auf einer morschen Holzplanke über einem Haifischbecken.
## Stück für Stück bricht sie ab (erst knarzen, dann splittern). Wer ins Wasser fällt,
## wird von einem Hai "begrüßt". Der Letzte auf der Planke gewinnt.

const SEGMENTS := 16
const SEG_W := 1.5
const DEPTH := 2.8

var segs: Array[Dictionary] = []
var sharks: Array[Node3D] = []
var _break_t := 2.5
var _shark_t := 0.0


func _init() -> void:
	game_id = "plank_panic"
	env_preset = "pirates"
	time_limit = 45.0
	survival = true
	hazard = "water"
	kill_y = -1.6
	arena_radius = 11.0
	arena_center = Vector3(0, 0, 0)
	cannon_pos = Vector3(-15, 0.6, 6)
	spawn_points = [Vector3(-4.5, 1.0, 0), Vector3(-1.5, 1.0, 0), Vector3(1.5, 1.0, 0), Vector3(4.5, 1.0, 0)]


func build_arena() -> void:
	WorldKit.water(world, Vector2(160, 160), -1.9, Color(0.02, 0.16, 0.34), Color(0.06, 0.38, 0.58))
	var off := (SEGMENTS - 1) * SEG_W * 0.5
	for i in SEGMENTS:
		var x := i * SEG_W - off
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(SEG_W * 0.97, 0.4, DEPTH)
		cs.shape = bs
		cs.position.y = 0.2
		body.add_child(cs)
		world.add_child(body)
		body.position = Vector3(x, 0, 0)
		var plank := Assets.spawn("pirate/platform_planks", body, Vector3.ZERO, 0.0 if i % 2 == 0 else 180.0, 1.0)
		plank.scale = Vector3(SEG_W / 1.89 * 1.02, 1.0, DEPTH / 2.7)
		segs.append({"body": body, "state": "ok", "t": 0.0, "x": x})
	# Stützpfähle & Schiffe
	for x in [-off - 1.0, off + 1.0]:
		WorldKit.place(world, "pirate/dock", Vector3(x, -1.0, 0), 0.0, 1.4)
	WorldKit.place(world, "pirate/ship_large", Vector3(-26, -1.8, -14), 70.0, 1.2)
	WorldKit.place(world, "pirate/ship_medium", Vector3(24, -1.6, -18), -110.0, 1.2)
	WorldKit.place(world, "pirate/rocks_a", Vector3(16, -1.6, 9), 0.0, 1.5)
	WorldKit.place(world, "pirate/rocks_b", Vector3(-18, -1.6, 10), 40.0, 1.6)
	WorldKit.place(world, "pirate/tower_small", Vector3(0, -1.6, -24), 0.0, 1.3)
	WorldKit.place(world, "pirate/flag", Vector3(-off - 1.0, 0.3, -1.0), 0.0, 1.0)
	WorldKit.place(world, "pirate/flag", Vector3(off + 1.0, 0.3, -1.0), 0.0, 1.0)
	# Haie (Fische, grau eingefärbt und riesig skaliert)
	for i in 3:
		var s := Node3D.new()
		world.add_child(s)
		var m := Assets.spawn("surv/fish", s, Vector3.ZERO, 0.0, 16.0)
		Assets.tint(m, Color(0.55, 0.62, 0.7))
		var fin := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.45
		cm.height = 1.0
		cm.material = WorldKit.mat(Color(0.45, 0.52, 0.6))
		fin.mesh = cm
		fin.scale = Vector3(0.35, 1.0, 1.0)
		fin.position = Vector3(0, 1.6, 0)
		s.add_child(fin)
		s.set_meta("phase", TAU * i / 3.0)
		s.set_meta("radius", 6.0 + i * 2.5)
		sharks.append(s)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0.5, 0)
	c.offset = Vector3(0, 8.5, 13.5)
	c.min_dist = 0.95
	c.max_dist = 1.15
	c.center_weight = 0.6


func on_start() -> void:
	for av in avatars:
		(av as PartyAvatar).rig.surface = "wood"


func on_tick(delta: float) -> void:
	# Haie kreisen unter der Planke, Flosse über Wasser
	var t := Time.get_ticks_msec() / 1000.0
	for s in sharks:
		if s.has_meta("busy"):
			continue
		var ph: float = s.get_meta("phase")
		var r: float = s.get_meta("radius")
		var a := t * 0.6 + ph
		var p := Vector3(cos(a) * r, -2.6, sin(a) * r * 0.45)
		var next := Vector3(cos(a + 0.05) * r, -2.6, sin(a + 0.05) * r * 0.45)
		s.position = p
		s.look_at(next, Vector3.UP)
		s.rotate_object_local(Vector3.UP, PI / 2.0)
	# Planke bricht
	_break_t -= delta
	if _break_t <= 0.0:
		var frac := time_left / time_limit
		_break_t = lerpf(0.75, 1.9, frac)
		_crack_next()
	for sg in segs:
		if sg.state == "cracking":
			sg.t += delta
			var b: Node3D = sg.body
			b.position = Vector3(sg.x + randf_range(-0.03, 0.03), randf_range(-0.04, 0.0), 0)
			b.rotation.z = randf_range(-0.04, 0.04)
			if sg.t > 0.9:
				_break(sg)


func _crack_next() -> void:
	var ok: Array[int] = []
	for i in segs.size():
		if segs[i].state == "ok":
			ok.append(i)
	if ok.size() <= 2:
		return
	# Bevorzugt Ränder, später auch Mitte
	var pick := ok[0] if randf() < 0.5 else ok[ok.size() - 1]
	if time_left < time_limit * 0.6 and randf() < 0.45:
		pick = ok[randi() % ok.size()]
	var sg := segs[pick]
	sg.state = "cracking"
	sg.t = 0.0
	Audio.sfx("creak", (sg.body as Node3D).global_position)
	FX.dust((sg.body as Node3D).global_position + Vector3.UP * 0.4, Color(0.7, 0.55, 0.35), 8)


func _break(sg: Dictionary) -> void:
	sg.state = "gone"
	var b: StaticBody3D = sg.body
	for c in b.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", true)
	Audio.sfx("plank_break", b.global_position)
	FX.step(b.global_position + Vector3.UP * 0.3, "wood", 2.5, false)
	Juice.shake(0.15)
	var tw := b.create_tween().set_parallel(true)
	tw.tween_property(b, "position:y", -2.6, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(b, "rotation", Vector3(randf_range(-0.8, 0.8), 0, randf_range(-1.2, 1.2)), 0.7)
	tw.chain().tween_callback(func() -> void:
		FX.splash(Vector3(b.position.x, -1.8, 0), 0.7)
		b.visible = false)


func on_fell(slot: int, hz: String) -> void:
	eliminate(slot)
	_shark_chomp((avatars[slot] as Node3D).global_position)


func _shark_chomp(at: Vector3) -> void:
	var s: Node3D = sharks[randi() % sharks.size()]
	s.set_meta("busy", true)
	var from := Vector3(at.x - 3.0, -3.0, at.z + 1.0)
	var to := Vector3(at.x + 3.0, -3.0, at.z)
	s.position = from
	s.look_at(to, Vector3.UP)
	s.rotate_object_local(Vector3.UP, PI / 2.0)
	var tw := s.create_tween()
	tw.tween_method(func(t: float) -> void:
		s.position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * 4.0
		s.rotation.z = (t - 0.5) * 1.6, 0.0, 1.0, 0.9)
	tw.tween_callback(func() -> void:
		FX.splash(Vector3(to.x, -1.8, to.z), 1.2)
		s.remove_meta("busy"))
	Audio.sfx("splash", at)
	Audio.sfx("evil_laugh", at, -6.0, 1.4)


# --- CPU ---------------------------------------------------------------------------------------

func cpu_think(slot: int, delta: float) -> void:
	var av: PartyAvatar = avatars[slot]
	if not av.alive:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var mem: Dictionary = cpu_mem[slot]
	mem["t"] = mem.get("t", 0.0) - delta
	if mem["t"] <= 0.0:
		mem["t"] = [0.7, 0.4, 0.2][level]
		var best_x := 0.0
		var best_s := -INF
		for i in segs.size():
			if segs[i].state != "ok":
				continue
			var s := 0.0
			for d in [-2, -1, 1, 2]:
				var j: int = i + d
				if j >= 0 and j < segs.size() and segs[j].state == "ok":
					s += 1.0
			s -= absf(float(segs[i].x) - av.global_position.x) * 0.25
			s += randf() * (2.5 - level)
			if s > best_s:
				best_s = s
				best_x = segs[i].x
		mem["x"] = best_x
	var dx: float = float(mem.get("x", 0.0)) - av.global_position.x
	var dz := -av.global_position.z
	var mv := Vector2(dx, dz * 0.8)
	if mv.length() < 0.3:
		mv = Vector2.ZERO
	else:
		mv = mv.normalized()
	var held := {}
	var idx := int(round((av.global_position.x + (SEGMENTS - 1) * SEG_W * 0.5) / SEG_W)) + int(sign(dx))
	if absf(dx) > 0.5 and (idx < 0 or idx >= segs.size() or segs[idx].state == "gone") and av.is_on_floor():
		held["a"] = true
	for o in avatars:
		var oa := o as PartyAvatar
		if oa != av and oa.alive and oa.global_position.distance_to(av.global_position) < 1.7 and randf() < 0.03 * (level + 1):
			held["b"] = true
	InputHub.set_virtual(slot, mv, held)
