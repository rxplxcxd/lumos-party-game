extends MinigameBase
## Schneeball-Schlacht: Verschneiter Dorfplatz mit Schneemännern als Deckung. B wirft einen
## Schneeball (leichte Zielhilfe nach vorne), Munition lädt an Schneehaufen schneller nach.
## Jeder Treffer = 1 Punkt, Getroffene werden kurz zu wackelnden Schnee-Klumpen.

const HALF := 11.0
const MAX_AMMO := 3
const BALL_SPEED := 17.0

var balls: Array[Dictionary] = []
var ammo: Array[int] = [MAX_AMMO, MAX_AMMO, MAX_AMMO, MAX_AMMO]
var _reload: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _cd: Array[float] = [0.0, 0.0, 0.0, 0.0]
var covers: Array[Vector3] = []
var piles: Array[Vector3] = []
var _ammo_labels: Array[Label3D] = []


func _init() -> void:
	game_id = "snowball_fight"
	fair_spawns = true   # Startplätze jede Runde neu auslosen (kein fester Platzvorteil)
	touch_profile = "throw"
	env_preset = "snow"
	time_limit = 45.0
	arena_radius = 12.0
	cannon_pos = Vector3(0, 0, 14)
	spawn_points = [Vector3(-8, 0.5, -7), Vector3(8, 0.5, -7), Vector3(-8, 0.5, 7), Vector3(8, 0.5, 7)]


func build_arena() -> void:
	WorldKit.box(world, Vector3(HALF * 2 + 8, 1, HALF * 2 + 8), Vector3(0, -0.5, 0), Color("#eef4ff"))
	# unsichtbare Begrenzung
	for side in [-1.0, 1.0]:
		WorldKit.box(world, Vector3(0.5, 3, HALF * 2 + 2), Vector3(side * (HALF + 0.6), 1.5, 0), Color.WHITE).visible = false
		WorldKit.box(world, Vector3(HALF * 2 + 2, 3, 0.5), Vector3(0, 1.5, side * (HALF + 0.6)), Color.WHITE).visible = false
	covers = [Vector3(0, 0, 0), Vector3(-5, 0, 0), Vector3(5, 0, 0), Vector3(0, 0, -5), Vector3(0, 0, 5), Vector3(-4, 0, -4.5), Vector3(4, 0, 4.5)]
	for i in covers.size():
		var c := covers[i]
		var key := "hol/snowman" if i % 2 == 0 else "hol/snowball_pile"
		WorldKit.place(world, key, c, randf() * 360.0, 2.2 if i % 2 == 0 else 1.8, true)
	piles = [Vector3(-9, 0, 0), Vector3(9, 0, 0), Vector3(0, 0, -9), Vector3(0, 0, 9)]
	for p in piles:
		WorldKit.place(world, "hol/snowball_pile", p, randf() * 360.0, 1.4)
		var glow := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(3.2, 3.2)
		q.orientation = PlaneMesh.FACE_Y
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = FX.tex_ring
		m.albedo_color = Color(0.5, 0.85, 1.0, 0.6)
		q.material = m
		glow.mesh = q
		world.add_child(glow)
		glow.position = p + Vector3.UP * 0.05
	# Dorfkulisse
	for i in 14:
		var a := TAU * i / 14.0
		var pos := Vector3(cos(a) * (HALF + 5.0), 0, sin(a) * (HALF + 5.0))
		var key: String = ["nat/pine_snow", "hol/christmas_tree", "nat/pine_snow", "hol/gingerbread_house"][i % 4]
		WorldKit.place(world, key, pos, rad_to_deg(-a) + 90.0, 2.6 if key == "hol/gingerbread_house" else 2.2)
	for i in 6:
		WorldKit.torch_light(world, Vector3(cos(TAU * i / 6.0), 0, sin(TAU * i / 6.0)) * (HALF + 2.0) + Vector3.UP * 2.6, Color(1.0, 0.75, 0.45), 1.4, 8.0)
	var snow := FX.emitter({"amount": 90, "life": 6.0, "one_shot": false, "explosive": 0.0, "spread": 10.0, "dir": Vector3(0, -1, 0),
		"vel_min": 1.0, "vel_max": 2.0, "gravity": Vector3(0.3, -0.6, 0), "size": 0.22, "color": Color(1, 1, 1, 0.9), "radius": 16.0})
	world.add_child(snow)
	snow.position = Vector3(0, 14, 0)
	snow.emitting = true


func on_start() -> void:
	for i in 4:
		var av := avatars[i] as PartyAvatar
		av.can_shove = false
		av.rig.surface = "snow"
		av.slippery = 0.25
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font_size = 64
		l.outline_size = 14
		l.modulate = Color(0.8, 0.95, 1.0)
		l.position = Vector3(0, 2.7, 0)
		av.add_child(l)
		_ammo_labels.append(l)
	_refresh_ammo()


func _refresh_ammo() -> void:
	for i in _ammo_labels.size():
		_ammo_labels[i].text = "●".repeat(ammo[i]) + "○".repeat(MAX_AMMO - ammo[i])


func on_tick(delta: float) -> void:
	for i in 4:
		var av := avatars[i] as PartyAvatar
		_cd[i] = maxf(0.0, _cd[i] - delta)
		var near_pile := false
		for p in piles:
			if Vector2(av.global_position.x - p.x, av.global_position.z - p.z).length() < 1.8:
				near_pile = true
		if ammo[i] < MAX_AMMO:
			_reload[i] += delta * (3.5 if near_pile else 1.0)
			if _reload[i] >= 1.4:
				_reload[i] = 0.0
				ammo[i] += 1
				_refresh_ammo()
				if near_pile:
					Audio.sfx("pluck", av.global_position, -8.0, 1.4)
		if not av.is_stunned() and _cd[i] <= 0.0 and InputHub.pressed(i, "b"):
			if ammo[i] > 0:
				_throw(i)
			else:
				Juice.float_text(self, av.global_position + Vector3.UP * 3.0, "Leer!", Color(0.7, 0.8, 1.0), 70)
				_cd[i] = 0.4
	for b in balls.duplicate():
		_update_ball(b, delta)


func _throw(i: int) -> void:
	var av := avatars[i] as PartyAvatar
	ammo[i] -= 1
	_cd[i] = 0.45
	_refresh_ammo()
	var fwd := -av.rig.global_basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	# Zielhilfe: nächster Gegner im 35°-Kegel
	var best_dot := cos(deg_to_rad(35))
	var aim := fwd
	for j in 4:
		if j == i:
			continue
		var o := avatars[j] as PartyAvatar
		var d := o.global_position - av.global_position
		d.y = 0
		var dist := d.length()
		if dist < 15.0 and dist > 0.5:
			var dt := fwd.dot(d / dist)
			if dt > best_dot:
				best_dot = dt
				aim = d / dist
	av.rig.play("throw", 0.05, 1.6, true)
	av.rig.lock(0.3)
	av.rig.squash(1.1, 0.92, 0.25)
	var start := av.global_position + Vector3.UP * 1.4 + aim * 0.7
	var node := Assets.spawn("hol/snowball", world, start, 0.0, 0.8)
	balls.append({"node": node, "pos": start, "vel": aim * BALL_SPEED + Vector3.UP * 3.0, "owner": i, "life": 1.6})
	Audio.sfx("whoosh", start, -6.0, 1.3)


func _update_ball(b: Dictionary, delta: float) -> void:
	var vel: Vector3 = b.vel
	vel.y -= 9.0 * delta
	b.vel = vel
	var pos: Vector3 = b.pos + vel * delta
	b.pos = pos
	b.life = float(b.life) - delta
	var n: Node3D = b.node
	n.position = pos
	n.rotation += Vector3(8, 0, 5) * delta
	var hit: bool = pos.y <= 0.15 or b.life <= 0.0 or absf(pos.x) > HALF + 1.0 or absf(pos.z) > HALF + 1.0
	for c in covers:
		if Vector2(pos.x - c.x, pos.z - c.z).length() < 1.1 and pos.y < 2.6:
			hit = true
	if not hit:
		for j in 4:
			if j == int(b.owner):
				continue
			var o := avatars[j] as PartyAvatar
			var d := o.global_position + Vector3.UP * 0.9 - pos
			if absf(d.y) < 1.1 and Vector2(d.x, d.z).length() < 0.75:
				_splat(int(b.owner), j, Vector3(vel.x, 0, vel.z))
				hit = true
				break
	if hit:
		FX.dust(pos, Color(0.95, 0.97, 1.0), 10, 0.8)
		Audio.sfx("hit_soft", pos, -4.0, 1.3)
		balls.erase(b)
		n.queue_free()


func _splat(thrower: int, victim: int, dir: Vector3) -> void:
	var o := avatars[victim] as PartyAvatar
	add_score(thrower, 1, o.global_position + Vector3.UP * 2.4)
	o.apply_knockback(dir.normalized(), 9.0, 0.9, 3.0)
	FX.dizzy_stars(o, 2.3, 0.9, 3)
	# Schnee-Überzug (Overlay statt Material-Tausch, damit nichts akkumuliert)
	var snow_mat := StandardMaterial3D.new()
	snow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	snow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	snow_mat.albedo_color = Color(0.92, 0.97, 1.0, 0.75)
	for mi in Assets.find_meshes(o.rig.model):
		mi.material_overlay = snow_mat
	var tw := o.create_tween()
	tw.tween_interval(0.7)
	tw.tween_property(snow_mat, "albedo_color:a", 0.0, 0.4)
	tw.tween_callback(func() -> void:
		for mi in Assets.find_meshes(o.rig.model):
			if mi.material_overlay == snow_mat:
				mi.material_overlay = null)
	InputHub.rumble(victim, 0.6, 0.15)
	InputHub.rumble(thrower, 0.25, 0.06)
	Juice.hitstop(0.04)
	(avatars[thrower] as PartyAvatar).rig.react("laugh" if randf() < 0.5 else "taunt")


func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	var level: int = Game.players[slot].cpu_level
	var mem := cpu_mem[slot]
	var pos := av.global_position
	var mv := Vector2.ZERO
	var held := {}
	# Ausweichen anfliegender Bälle
	for b in balls:
		if int(b.owner) == slot:
			continue
		var bp: Vector3 = b.pos
		var bv: Vector3 = b.vel
		var rel := Vector2(pos.x - bp.x, pos.z - bp.z)
		var dir := Vector2(bv.x, bv.z).normalized()
		var along := rel.dot(dir)
		if along > 0.0 and along < Game.lv([3.0, 5.0, 7.0], level):
			var perp := rel - dir * along
			if perp.length() < 1.2:
				mv += Vector2(-dir.y, dir.x) * (1.0 if perp.cross(dir) < 0.0 else -1.0)
	if mv == Vector2.ZERO:
		if ammo[slot] == 0:
			var best := piles[0]
			for p in piles:
				if pos.distance_to(p) < pos.distance_to(best):
					best = p
			mv = Vector2(best.x - pos.x, best.z - pos.z)
			mv = mv.normalized() if mv.length() > 1.0 else Vector2.ZERO
		else:
			var tgt: int = int(mem.get("target", -1))
			if tgt < 0 or randf() < 0.01:
				tgt = (slot + 1 + randi() % 3) % 4
				mem["target"] = tgt
			var tp := (avatars[tgt] as PartyAvatar).global_position
			var to := Vector2(tp.x - pos.x, tp.z - pos.z)
			var dist := to.length()
			var want := 7.0
			if dist > want + 1.0:
				mv = to.normalized()
			elif dist < want - 2.0:
				mv = -to.normalized() * 0.7
			else:
				mv = Vector2(-to.y, to.x).normalized() * 0.5 * (1.0 if slot % 2 == 0 else -1.0) + to.normalized() * 0.25
			var fwd := -av.rig.global_basis.z
			var facing := Vector2(fwd.x, fwd.z).normalized().dot(to.normalized())
			if facing > 0.8 and dist < 14.0 and _cd[slot] <= 0.0 and randf() < Game.lv([0.07, 0.13, 0.22], level):
				held["b"] = true
	InputHub.set_virtual(slot, mv.limit_length(1.0), held)
