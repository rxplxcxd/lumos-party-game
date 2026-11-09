extends MinigameBase
## Seifenblasen-Ballett: Jeder balanciert auf einer schwebenden Seifenblase über einem wolkigen Abgrund.
## Stick = Pust-Richtung, A und B ABWECHSELND drücken = Wind pumpen: Blasen in der Windrichtung werden
## weggeweht. Mit der Zeit schrumpfen die Blasen und werden glitschig (der Wind trägt weiter). Wer zu wild
## hämmert, überhitzt seine eigene Blase – PLOPP. Weggeweht über den Rand oder geplatzt = raus.
## Online: Host-Modell (Host simuliert Blasen und Wind).

const EDGE := 11.0

var bubbles: Array[Dictionary] = []    # {node, sphere, pos(Vector2), vel(Vector2), r, heat, last, popped}
var _aim: Array[Vector2] = [Vector2.UP, Vector2.UP, Vector2.UP, Vector2.UP]
var _gust_fx_t: Array[float] = [0, 0, 0, 0]


func _init() -> void:
	game_id = "bubble_ballet"
	env_preset = "sky"
	backdrop_style = "sky"
	time_limit = 45.0
	survival = true
	arena_radius = 10.0
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 13)
	net_model = "host"
	spawn_points = [Vector3(-4, 2.6, -3), Vector3(4, 2.6, -3), Vector3(-4, 2.6, 3), Vector3(4, 2.6, 3)]


func build_arena() -> void:
	# Abgrund mit Wolkenmeer weit unten, schwebende Inselchen und Regenbogen
	for i in 14:
		var a := TAU * i / 14.0
		var isle := Assets.spawn("plat/block_grass_overhang", world, Vector3(cos(a) * 17.0, rng.randf_range(-6.0, -2.0), sin(a) * 15.0), rng.randf() * 360.0, rng.randf_range(1.4, 2.4))
		if i % 3 == 0:
			Assets.spawn(["plat/tree", "plat/flowers", "plat/mushrooms"][i % 3], isle, Vector3(0, 1, 0), 0.0, 1.0)
		var bob := isle.create_tween().set_loops()
		bob.tween_property(isle, "position:y", isle.position.y + 0.6, 2.0 + i * 0.1).set_trans(Tween.TRANS_SINE)
		bob.tween_property(isle, "position:y", isle.position.y, 2.0 + i * 0.1).set_trans(Tween.TRANS_SINE)
	for k in 7:
		var arc := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 20.0 + k * 0.6
		tm.outer_radius = 20.6 + k * 0.6
		tm.rings = 48
		tm.material = WorldKit.mat([Color("#ff6b6b"), Color("#ff9f43"), Color("#ffd23f"), Color("#7ed957"), Color("#3fa7ff"), Color("#6c7bff"), Color("#c06bff")][k], 0.6, 0.35)
		arc.mesh = tm
		arc.rotation.x = PI * 0.5
		arc.position = Vector3(0, -6.0, -26.0)
		world.add_child(arc)
	# Kleine Blasen steigen überall auf
	var tiny := FX.emitter({"amount": 50, "life": 7.0, "one_shot": false, "explosive": 0.0, "spread": 20.0, "dir": Vector3.UP,
		"vel_min": 0.4, "vel_max": 1.0, "gravity": Vector3(0, 0.1, 0), "size": 0.25, "additive": true, "color": Color(0.85, 0.95, 1.0, 0.6), "box": Vector3(30, 1, 26)})
	world.add_child(tiny)
	tiny.position = Vector3(0, -4.0, 0)
	tiny.preprocess = 5.0
	tiny.emitting = true
	# Die Spieler-Blasen
	for i in 4:
		var n := Node3D.new()
		world.add_child(n)
		var sph := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.85, 0.92, 1.0, 0.28).lerp(Game.player_color(i), 0.15)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.05
		m.metallic_specular = 1.0
		m.rim_enabled = true
		m.rim = 1.0
		m.rim_tint = 0.2
		m.emission_enabled = true
		m.emission = Color(0.7, 0.85, 1.0)
		m.emission_energy_multiplier = 0.15
		sm.material = m
		sph.mesh = sm
		n.add_child(sph)
		var p: Vector3 = spawn_points[i]
		n.position = Vector3(p.x, 1.2, p.z)
		bubbles.append({"node": n, "sphere": sph, "pos": Vector2(p.x, p.z), "vel": Vector2.ZERO, "r": 1.6, "heat": 0.0, "last": "", "popped": false})
		sph.scale = Vector3.ONE * 1.6


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 1.5, 0)
	c.offset = Vector3(0, 12.0, 12.5)
	c.min_dist = 1.0
	c.max_dist = 1.0
	c.follow = false


func on_start() -> void:
	for i in 4:
		var av := avatars[i] as PartyAvatar
		av.can_move = false
		av.can_jump = false
		av.can_shove = false
		av.set_physics_process(false)


func on_tick(delta: float) -> void:
	var prog := 1.0 - time_left / time_limit
	var slip := lerpf(1.0, 1.9, prog)        # kleiner = glitschiger: Wind trägt weiter, weniger Reibung
	for i in active_slots():
		var b := bubbles[i]
		if bool(b.popped):
			continue
		b.r = lerpf(1.6, 0.85, prog)
		b.heat = maxf(0.0, float(b.heat) - delta * 0.6)
		var mv := InputHub.move(i)
		if mv.length() > 0.3:
			_aim[i] = mv.normalized()
		var key := ""
		if InputHub.pressed(i, "a"):
			key = "a"
		elif InputHub.pressed(i, "b"):
			key = "b"
		if key != "" and key != String(b.last):
			b.last = key
			b.heat = float(b.heat) + 0.12
			_gust(i)
			if float(b.heat) > 1.0:
				_pop(i, "Überhitzt!")
				continue
		elif key != "" and key == String(b.last):
			b.heat = float(b.heat) + 0.05   # gleiche Taste zweimal = nur Hitze, kein Wind
	# Bewegung, Reibung, Rand, Kollisionen zwischen Blasen
	for i in active_slots():
		var b2 := bubbles[i]
		if bool(b2.popped):
			continue
		var v: Vector2 = b2.vel
		v = v.move_toward(Vector2.ZERO, delta * 3.4 / slip)
		b2.pos = (b2.pos as Vector2) + v * delta
		b2.vel = v
		if (b2.pos as Vector2).length() > EDGE:
			_pop(i, "Weggeweht!")
	for a in active_slots():
		for c in active_slots():
			if c <= a or bool(bubbles[a].popped) or bool(bubbles[c].popped):
				continue
			var d: Vector2 = (bubbles[c].pos as Vector2) - (bubbles[a].pos as Vector2)
			var minr := float(bubbles[a].r) + float(bubbles[c].r)
			if d.length() < minr and d.length() > 0.001:
				var nrm := d.normalized()
				var push := (minr - d.length()) * 0.5
				bubbles[a].pos = (bubbles[a].pos as Vector2) - nrm * push
				bubbles[c].pos = (bubbles[c].pos as Vector2) + nrm * push
				var rel := ((bubbles[a].vel as Vector2) - (bubbles[c].vel as Vector2)).dot(nrm)
				if rel > 0.0:
					bubbles[a].vel = (bubbles[a].vel as Vector2) - nrm * rel
					bubbles[c].vel = (bubbles[c].vel as Vector2) + nrm * rel
					Audio.sfx("boing", null, -12.0, 1.6)
	_apply_visuals(delta)


func _gust(i: int) -> void:
	var src: Vector2 = bubbles[i].pos
	var dir := _aim[i]
	for j in active_slots():
		if j == i or bool(bubbles[j].popped):
			continue
		var to: Vector2 = (bubbles[j].pos as Vector2) - src
		var dist := to.length()
		if dist < 9.0 and to.normalized().dot(dir) > 0.55:
			var strength := (1.0 - dist / 9.0) * 1.5
			bubbles[j].vel = (bubbles[j].vel as Vector2) + dir * strength
	bubbles[i].vel = (bubbles[i].vel as Vector2) - dir * 0.18   # Rückstoß
	_gust_fx(i)


func _gust_fx(i: int) -> void:
	var av := avatars[i] as PartyAvatar
	var d3 := Vector3(_aim[i].x, 0, _aim[i].y)
	av.rig.face_now(d3)
	av.rig.play_once("cast" if av.rig.has_clip("cast") else "interact", "idle", 1.6)
	FX.dust(av.global_position + d3 * 1.2 + Vector3.UP * 1.2, Color(0.9, 0.97, 1.0), 6, 0.6)
	Audio.sfx("whoosh", av.global_position, -10.0, 1.3 + randf() * 0.2)


func _pop(i: int, why: String) -> void:
	var b := bubbles[i]
	b.popped = true
	var n: Node3D = b.node
	FX.stars(n.global_position, Color(0.85, 0.95, 1.0), 20)
	FX.sparks(n.global_position, Color(0.8, 0.9, 1.0), 16)
	Audio.sfx("pop", n.global_position, 2.0, 0.8)
	(b.sphere as Node3D).visible = false
	Juice.float_text(self, n.global_position + Vector3.UP * 3.0, why, Color("#ff9db0"), 70)
	var av := avatars[i] as PartyAvatar
	av.rig.react("launch")
	var tw := av.create_tween()
	tw.tween_property(av, "global_position:y", -14.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	Audio.sfx("whistle_fall", av.global_position, -4.0)
	eliminate(i)


func _apply_visuals(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in 4:
		var b := bubbles[i]
		if bool(b.popped):
			continue
		var n: Node3D = b.node
		var p: Vector2 = b.pos
		var r := float(b.r)
		n.position = Vector3(p.x, 1.2 + sin(t * 1.6 + i) * 0.2, p.y)
		var wob := 1.0 + sin(t * 7.0 + i) * 0.04 + float(b.heat) * 0.08
		(b.sphere as Node3D).scale = Vector3(r * wob, r / wob, r * wob)
		var m := ((b.sphere as MeshInstance3D).mesh as SphereMesh).material as StandardMaterial3D
		m.emission = Color(0.7, 0.85, 1.0).lerp(Color(1.0, 0.4, 0.3), clampf(float(b.heat), 0.0, 1.0))
		m.emission_energy_multiplier = 0.15 + float(b.heat) * 0.8
		var av := avatars[i] as PartyAvatar
		if av.alive:
			av.global_position = n.position + Vector3(sin(t * 3.0 + i) * 0.05 * r, r * 0.98, 0)
			av.rig.rotation.z = sin(t * 2.2 + i * 1.3) * 0.12 * (1.6 / r)


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	d["b"] = bubbles.map(func(b: Dictionary) -> Array:
		var p: Vector2 = b.pos
		return [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(float(b.r), 0.01), snappedf(float(b.heat), 0.01), 1 if bool(b.popped) else 0])
	d["a"] = _aim.map(func(v: Vector2) -> Array: return [snappedf(v.x, 0.01), snappedf(v.y, 0.01)])
	return d


func net_unpack(d: Dictionary) -> void:
	var bs: Array = d.get("b", [])
	for i in mini(4, bs.size()):
		var e: Array = bs[i]
		var b := bubbles[i]
		b.pos = (b.pos as Vector2).lerp(Vector2(float(e[0]), float(e[1])), 0.6)
		b.r = float(e[2])
		var old_heat := float(b.heat)
		b.heat = float(e[3])
		if b.heat > old_heat + 0.1:
			_gust_fx(i)
		if int(e[4]) == 1 and not bool(b.popped):
			b.popped = true
			(b.sphere as Node3D).visible = false
			FX.stars((b.node as Node3D).global_position, Color(0.85, 0.95, 1.0), 20)
			Audio.sfx("pop", null, 0.0, 0.8)
	var aa: Array = d.get("a", [])
	for i in mini(4, aa.size()):
		_aim[i] = Vector2(float(aa[i][0]), float(aa[i][1]))
	_apply_visuals(0.05)


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var b := bubbles[slot]
	var level: int = Game.players[slot].cpu_level
	var held := {}
	var mv := Vector2.ZERO
	var best := -1
	var bd := INF
	for j in active_slots():
		if j == slot or bool(bubbles[j].popped):
			continue
		var d := (bubbles[j].pos as Vector2).distance_to(b.pos)
		if d < bd:
			bd = d
			best = j
	if best >= 0:
		mv = ((bubbles[best].pos as Vector2) - (b.pos as Vector2)).normalized()
		var safe: float = [0.55, 0.72, 0.82][level]
		if float(b.heat) < safe and bd < 8.0 and randf() < [0.05, 0.09, 0.13][level]:
			held["b" if String(b.last) == "a" else "a"] = true
	InputHub.set_virtual(slot, mv, held)
