extends MinigameBase
## Fischfang: Alle angeln am selben Teich. Mit dem Stick steuerst du deinen Schwimmer, Fisch-Schatten
## schwimmen umher. Taucht der Schwimmer ab ("!"), sofort A drücken! Kleine Fische 1, große 3,
## Goldfisch 6 Punkte – und manchmal hängt nur ein alter Stiefel dran.

const POND_R := 8.5
const BITE_WINDOW := 0.55

var bobbers: Array[Dictionary] = []
var fish: Array[Dictionary] = []
var _spawn_t := 0.5


func _init() -> void:
	game_id = "fish_catch"
	env_preset = "day"
	time_limit = 45.0
	arena_radius = 11.0
	teaser_height = 1.2
	cannon_pos = Vector3(0, 0, 14)
	var r := (POND_R + 0.9) * 0.7071
	spawn_points = [Vector3(-r, 0.5, -r), Vector3(r, 0.5, -r), Vector3(-r, 0.5, r), Vector3(r, 0.5, r)]


func build_arena() -> void:
	# Ufer-Ring mit Loch für den Teich (Ring aus Segmenten)
	var seg := 28
	for k in seg:
		var a := TAU * (k + 0.5) / seg
		var c := Vector3(cos(a), 0, sin(a)) * (POND_R + 2.5)
		var b := WorldKit.box(world, Vector3(3.2, 1.0, 5.0), c + Vector3(0, -0.5, 0), Color("#6fae4a"))
		b.rotation.y = -a + PI * 0.5
	WorldKit.water(world, Vector2(POND_R * 2.0 + 1.0, POND_R * 2.0 + 1.0), -0.35, Color(0.04, 0.3, 0.42), Color(0.3, 0.7, 0.72))
	WorldKit.cylinder(world, POND_R + 0.6, 0.2, Vector3(0, -2.0, 0), Color("#2b4a3a"), false)
	# Holzstege: vom Ufer ins Wasser, die Figur steht am Ufer-Ende
	for i in 4:
		var sp := spawn_points[i]
		var dir := Vector3(sp.x, 0, sp.z).normalized()
		var dock := WorldKit.box(world, Vector3(1.9, 0.18, 3.0), dir * (POND_R - 0.3) + Vector3(0, -0.08, 0), Color("#a0703f"), false)
		dock.rotation.y = atan2(dir.x, dir.z)
		dock.name = "Dock%d" % i
		for side in [-1.0, 1.0]:
			var post := WorldKit.cylinder(world, 0.12, 1.2, dir * (POND_R - 1.6) + dir.cross(Vector3.UP) * side * 0.85 + Vector3(0, -0.4, 0), Color("#6b4a2b"), false)
			post.name = "Post"
		WorldKit.place(world, "surv/barrel", dir * (POND_R + 1.4) + dir.cross(Vector3.UP) * 1.2, randf() * 360.0, 1.2)
	for i in 16:
		var a2 := TAU * i / 16.0 + 0.2
		var pos := Vector3(cos(a2), 0, sin(a2)) * (POND_R + 4.5)
		WorldKit.place(world, ["nat/tree_oak", "plat/flowers", "nat/bush", "nat/rock_large", "nat/lily", "plat/mushrooms"][i % 6], pos, randf() * 360.0, 1.8)
	WorldKit.place(world, "water/boat_fishing", Vector3(3.5, -0.3, -2.0), 40.0, 1.0)
	WorldKit.place(world, "pirate/boat_row", Vector3(-4.0, -0.3, 2.5), -70.0, 1.0)


func on_start() -> void:
	for i in 4:
		var av := avatars[i] as PartyAvatar
		av.can_move = false
		av.can_jump = false
		av.can_shove = false
		av.velocity = Vector3.ZERO
		av.set_physics_process(false)   # steht fest am Steg, keine Lauf-Animation
		av.rig.face_now(-Vector3(av.global_position.x, 0, av.global_position.z).normalized())
		av.rig.play("fish", 0.2)
		var bob := Node3D.new()
		world.add_child(bob)
		var ball := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.22
		sm.height = 0.44
		sm.material = WorldKit.mat(Game.player_color(i), 0.4, 0.6)
		ball.mesh = sm
		bob.add_child(ball)
		var top := MeshInstance3D.new()
		var sm2 := SphereMesh.new()
		sm2.radius = 0.12
		sm2.height = 0.24
		sm2.material = WorldKit.mat(Color.WHITE, 0.4, 0.4)
		top.mesh = sm2
		top.position.y = 0.2
		bob.add_child(top)
		var ring := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.6, 1.6)
		q.orientation = PlaneMesh.FACE_Y
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = FX.tex_ring
		m.albedo_color = Game.player_color(i)
		m.albedo_color.a = 0.6
		q.material = m
		ring.mesh = q
		ring.position.y = -0.1
		bob.add_child(ring)
		var home := Vector3(av.global_position.x, 0, av.global_position.z).normalized() * (POND_R - 2.5)
		bob.position = Vector3(home.x, -0.25, home.z)
		var line := MeshInstance3D.new()
		line.mesh = ImmediateMesh.new()
		var lm := StandardMaterial3D.new()
		lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lm.albedo_color = Color(1, 1, 1, 0.8)
		line.material_override = lm
		world.add_child(line)
		bobbers.append({"node": bob, "line": line, "state": "idle", "t": 0.0, "fish": null, "cd": 0.0, "dip": 0.0})
	for _k in 6:
		_spawn_fish()


func _spawn_fish() -> void:
	var r := randf()
	var kind := "small"
	if r < 0.08:
		kind = "gold"
	elif r < 0.18:
		kind = "boot"
	elif r < 0.5:
		kind = "big"
	var a := randf() * TAU
	var pos := Vector3(cos(a), 0, sin(a)) * randf_range(1.0, POND_R - 1.0)
	var shadow := MeshInstance3D.new()
	var q := QuadMesh.new()
	var size := {"small": Vector2(0.7, 1.2), "big": Vector2(1.1, 2.0), "gold": Vector2(0.9, 1.6), "boot": Vector2(0.9, 1.1)}[kind] as Vector2
	q.size = size
	q.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = FX.tex_soft
	m.albedo_color = Color(1.0, 0.8, 0.1, 0.85) if kind == "gold" else Color(0.0, 0.04, 0.08, 0.72)
	q.material = m
	shadow.mesh = q
	world.add_child(shadow)
	shadow.position = Vector3(pos.x, -0.3, pos.z)
	fish.append({"node": shadow, "kind": kind, "pos": pos, "dir": randf() * TAU, "speed": randf_range(0.8, 1.6) * (1.6 if kind == "gold" else 1.0),
		"target": -1, "hooked": false, "turn_t": 0.0})


func on_tick(delta: float) -> void:
	_spawn_t -= delta
	if _spawn_t <= 0.0 and fish.size() < 8:
		_spawn_t = randf_range(0.8, 1.8)
		_spawn_fish()
	for i in 4:
		_update_bobber(i, delta)
	for f in fish.duplicate():
		_update_fish(f, delta)


func _update_bobber(i: int, delta: float) -> void:
	var b: Dictionary = bobbers[i]
	var bob: Node3D = b.node
	var av := avatars[i] as PartyAvatar
	b.cd = maxf(0.0, float(b.cd) - delta)
	var mv := InputHub.move(i)
	if b.state != "bite":
		var p := bob.position + Vector3(mv.x, 0, mv.y) * 5.0 * delta
		var flat := Vector2(p.x, p.z)
		if flat.length() > POND_R - 0.6:
			flat = flat.normalized() * (POND_R - 0.6)
		bob.position = Vector3(flat.x, bob.position.y, flat.y)
	b.t = float(b.t) + delta
	var bob_y := -0.25 + sin(float(b.t) * 3.0 + i) * 0.04
	if b.state == "bite":
		bob_y = -0.55 + sin(float(b.t) * 40.0) * 0.06
		if float(b.t) > BITE_WINDOW:
			_miss(i, true)
	bob.position.y = bob_y
	if InputHub.pressed(i, "a") and float(b.cd) <= 0.0:
		if b.state == "bite":
			_catch(i)
		else:
			# zu früh: Schnur verheddert
			b.cd = 1.0
			Juice.float_text(self, av.global_position + Vector3.UP * 2.8, "Zu früh!", Color(0.8, 0.85, 1.0), 70)
			Audio.sfx("whoosh", bob.position, -10.0, 0.7)
			FX.splash(bob.position, 0.3)
			for f in fish:
				if int(f.target) == i:
					f.target = -1
	# Angelschnur zeichnen
	var im: ImmediateMesh = (b.line as MeshInstance3D).mesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var tip := av.global_position + Vector3.UP * 2.2 - Vector3(av.global_position.x, 0, av.global_position.z).normalized() * 1.2
	var mid := (tip + bob.position) * 0.5 + Vector3.DOWN * 0.6
	var prev := tip
	for k in range(1, 9):
		var t := k / 8.0
		var pt := tip.lerp(mid, t).lerp(mid.lerp(bob.position + Vector3.UP * 0.2, t), t)
		im.surface_add_vertex(prev)
		im.surface_add_vertex(pt)
		prev = pt
	im.surface_end()


func _update_fish(f: Dictionary, delta: float) -> void:
	var n: MeshInstance3D = f.node
	var pos: Vector3 = f.pos
	var tgt: int = int(f.target)
	if tgt >= 0:
		var b: Dictionary = bobbers[tgt]
		var bp: Vector3 = (b.node as Node3D).position
		var to := Vector3(bp.x - pos.x, 0, bp.z - pos.z)
		if to.length() > 2.6 or (b.state == "bite" and not is_same(b.fish, f)):
			f.target = -1
		elif to.length() < 0.35:
			if b.state == "idle" and float(b.cd) <= 0.0:
				b.state = "bite"
				b.t = 0.0
				b.fish = f
				f.hooked = true
				FX.splash(bp, 0.4)
				Audio.sfx("pop", bp, -2.0, 1.4)
				FX.emote(avatars[tgt], "!", Color(1, 0.85, 0.2), 2.8, BITE_WINDOW)
				InputHub.rumble(tgt, 0.5, 0.12)
			if f.hooked:
				pos = bp
		else:
			f.dir = lerp_angle(float(f.dir), atan2(to.x, to.z), delta * 4.0)
	else:
		f.turn_t = float(f.turn_t) - delta
		if float(f.turn_t) <= 0.0:
			f.turn_t = randf_range(0.8, 2.0)
			f.dir = float(f.dir) + randf_range(-1.4, 1.4)
		# Köder in der Nähe? (pro Fisch nur ein Interessent)
		for i in 4:
			var b2: Dictionary = bobbers[i]
			if b2.state != "idle" or float(b2.cd) > 0.0:
				continue
			var bp2: Vector3 = (b2.node as Node3D).position
			if Vector2(bp2.x - pos.x, bp2.z - pos.z).length() < 2.2 and randf() < delta * 1.5:
				var taken := false
				for o in fish:
					if o != f and int(o.target) == i:
						taken = true
				if not taken:
					f.target = i
					break
	if not f.hooked:
		var spd := float(f.speed) * (0.6 if tgt >= 0 else 1.0)
		pos += Vector3(sin(float(f.dir)), 0, cos(float(f.dir))) * spd * delta
		var flat := Vector2(pos.x, pos.z)
		if flat.length() > POND_R - 0.8:
			f.dir = atan2(-pos.x, -pos.z) + randf_range(-0.5, 0.5)
			flat = flat.normalized() * (POND_R - 0.8)
			pos = Vector3(flat.x, 0, flat.y)
	f.pos = pos
	n.position = Vector3(pos.x, -0.3, pos.z)
	n.rotation.y = float(f.dir)


func _catch(i: int) -> void:
	var b: Dictionary = bobbers[i]
	var f: Dictionary = b.fish
	var av := avatars[i] as PartyAvatar
	var bp: Vector3 = (b.node as Node3D).position
	b.state = "idle"
	b.fish = null
	b.cd = 0.6
	fish.erase(f)
	(f.node as Node3D).queue_free()
	FX.splash(bp, 0.8)
	Audio.sfx("splash", bp, -2.0, 1.2)
	var kind: String = f.kind
	var pts: int = {"small": 1, "big": 3, "gold": 6, "boot": 0}[kind]
	var key := "surv/fish_small" if kind == "small" else "surv/fish"
	var catch_node: Node3D
	if kind == "boot":
		catch_node = Assets.spawn("plat/crate", world, bp, 0.0, 0.5)
		Assets.tint(catch_node, Color(0.45, 0.32, 0.2))
	else:
		catch_node = Assets.spawn(key, world, bp, 0.0, 2.2 if kind == "big" else 1.6)
		if kind == "gold":
			Assets.tint(catch_node, Color(1.4, 1.1, 0.3), false, 0.8)
	var dest := av.global_position + Vector3.UP * 2.4
	var arc := func(t: float) -> void:
		catch_node.position = bp.lerp(dest, t) + Vector3.UP * sin(t * PI) * 3.0
		catch_node.rotation.z = t * TAU * 1.5
	var tw := catch_node.create_tween()
	tw.tween_method(arc, 0.0, 1.0, 0.7)
	tw.tween_callback(func() -> void:
		if pts > 0:
			add_score(i, pts, dest + Vector3.UP * 0.6)
			FX.stars(dest, Color(1, 0.9, 0.3) if kind == "gold" else Color(0.7, 0.95, 1.0), 6 + pts * 3)
			Audio.sfx("star" if pts >= 3 else "coin_single", dest)
			av.rig.react("star_get" if pts >= 3 else "cheer")
		else:
			Juice.float_text(self, dest + Vector3.UP * 0.6, "Stiefel…", Color(0.8, 0.7, 0.6), 80)
			Audio.sfx("sad_trombone", dest, -6.0)
			av.rig.react("frustrated")
		catch_node.queue_free())
	InputHub.rumble(i, 0.7, 0.2)
	get_tree().create_timer(1.2, false).timeout.connect(func() -> void:
		if is_instance_valid(av) and state == "play":
			av.rig.play("fish", 0.25))


func _miss(i: int, escaped: bool) -> void:
	var b: Dictionary = bobbers[i]
	var f: Variant = b.fish
	b.state = "idle"
	b.fish = null
	b.cd = 0.5
	if f is Dictionary:
		(f as Dictionary).hooked = false
		(f as Dictionary).target = -1
		(f as Dictionary).speed = float((f as Dictionary).speed) * 2.0
	if escaped:
		Juice.float_text(self, (avatars[i] as Node3D).global_position + Vector3.UP * 2.8, "Weg!", Color(0.7, 0.8, 1.0), 70)


func cpu_think(slot: int, delta: float) -> void:
	var level: int = Game.players[slot].cpu_level
	var mem := cpu_mem[slot]
	var b: Dictionary = bobbers[slot] if slot < bobbers.size() else {}
	if b.is_empty():
		return
	var bp: Vector3 = (b.node as Node3D).position
	var held := {}
	var mv := Vector2.ZERO
	if b.state == "bite":
		var react: float = float(mem.get("react", -1.0))
		if react < 0.0:
			react = randf_range([0.28, 0.2, 0.14][level], [0.7, 0.45, 0.32][level])
			mem["react"] = react
		if float(b.t) >= react:
			held["a"] = true
			mem["react"] = -1.0
	else:
		mem["react"] = -1.0
		# nächsten (wertvollen) Fischschatten anpeilen und vor ihm parken
		var best := Vector3.INF
		var bs := INF
		for f in fish:
			if f.hooked:
				continue
			var fp: Vector3 = f.pos
			var d := Vector2(fp.x - bp.x, fp.z - bp.z).length()
			var val := {"small": 1.0, "big": 2.0, "gold": 3.5, "boot": 0.6 if level == 0 else 0.0}[f.kind] as float
			if val <= 0.0:
				continue
			var s := d / val
			if s < bs:
				bs = s
				best = fp + Vector3(sin(float(f.dir)), 0, cos(float(f.dir))) * 1.0
		if best != Vector3.INF:
			var to := Vector2(best.x - bp.x, best.z - bp.z)
			if to.length() > 0.5:
				mv = to.normalized() * clampf(to.length() / 2.0, 0.25, 1.0) * [0.6, 0.8, 1.0][level]
		# ungeduldige CPUs drücken manchmal zu früh
		if level == 0 and randf() < delta * 0.25:
			held["a"] = true
	InputHub.set_virtual(slot, mv, held)
