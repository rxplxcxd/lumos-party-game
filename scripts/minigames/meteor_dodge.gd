extends MinigameBase
## Meteor-Ausweichen: Auf einem Mond-Plateau regnen Meteore herab. Rote Zielkreise wachsen vor dem
## Einschlag. Später zielen manche Meteore direkt auf Spieler. Wer getroffen wird, fliegt raus.
## 1 gegen 3: Das Solo schwebt in der Sternwarten-Kuppel und lenkt mit einem Zielkreis eigene Meteore (A),
## das Trio muss 30 Sekunden überstehen.

const RADIUS := 10.0

var meteors: Array[Dictionary] = []
var _spawn_t := 1.0


func _init() -> void:
	game_id = "meteor_dodge"
	env_preset = "space"
	time_limit = 45.0
	survival = true
	arena_radius = 11.0
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 13.5)
	spawn_points = [Vector3(-3, 0.5, -3), Vector3(3, 0.5, -3), Vector3(-3, 0.5, 3), Vector3(3, 0.5, 3)]


func build_arena() -> void:
	WorldKit.cylinder(world, RADIUS + 0.5, 2.0, Vector3(0, -1.0, 0), Color("#7a7690"))
	for i in 10:
		var a := randf() * TAU
		var r := randf_range(2.0, RADIUS - 1.0)
		WorldKit.place(world, "space/crater", Vector3(cos(a) * r, 0.0, sin(a) * r), randf() * 360.0, randf_range(1.0, 1.8))
	for i in 12:
		var a2 := TAU * i / 12.0
		WorldKit.place(world, ["space/rock_crystals", "space/rock_crystals_b", "space/machine", "space/satellite"][i % 4], Vector3(cos(a2), 0, sin(a2)) * (RADIUS + 2.5), rad_to_deg(-a2), 1.6)
	WorldKit.place(world, "space/rocket", Vector3(-14, 0, -12), 0.0, 3.0)
	WorldKit.place(world, "space/hangar", Vector3(14, 0, -12), -40.0, 2.0)
	var planet := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 30.0
	sm.height = 60.0
	sm.material = WorldKit.mat(Color("#4a7ad8"), 0.8, 0.4)
	planet.mesh = sm
	planet.position = Vector3(40, 30, -120)
	world.add_child(planet)


var _reticle: MeshInstance3D
var _ret_pos := Vector3.ZERO
var _solo_cd := 0.0


func spawn_players() -> void:
	super.spawn_players()
	if category == "1v3":
		time_limit = 30.0
		var sav := avatars[solo_slot] as PartyAvatar
		sav.set_physics_process(false)
		var perch := WorldKit.cylinder(world, 1.4, 0.4, Vector3(0, 0, -RADIUS - 3.0), Color("#c8c4e0"), false)
		perch.name = "Perch"
		sav.position = Vector3(0, 0.2, -RADIUS - 3.0)
		sav.rig.face_now(Vector3(0, 0, 1))
		_reticle = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(3.0, 3.0)
		q.orientation = PlaneMesh.FACE_Y
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = FX.tex_ring
		m.albedo_color = Game.player_color(solo_slot)
		q.material = m
		_reticle.mesh = q
		world.add_child(_reticle)
		_reticle.position = Vector3(0, 0.08, 0)


func team_result() -> int:
	if category == "1v3":
		for i in active_slots():
			if i != solo_slot and alive[i]:
				return 1
		return 0
	return super.team_result()


func check_end() -> bool:
	if category == "1v3":
		for i in active_slots():
			if i != solo_slot and alive[i]:
				return false
		return true
	return super.check_end()


func on_start() -> void:
	for av in avatars:
		(av as PartyAvatar).rig.surface = "stone"
		(av as PartyAvatar).can_shove = true


func on_tick(delta: float) -> void:
	if category == "1v3":
		var mv := InputHub.move(solo_slot)
		_ret_pos += Vector3(mv.x, 0, mv.y) * 10.0 * delta
		var flat := Vector2(_ret_pos.x, _ret_pos.z)
		if flat.length() > RADIUS - 0.5:
			flat = flat.normalized() * (RADIUS - 0.5)
		_ret_pos = Vector3(flat.x, 0, flat.y)
		_reticle.position = _ret_pos + Vector3.UP * 0.08
		_reticle.rotation.y += delta * 2.0
		_solo_cd -= delta
		if _solo_cd <= 0.0 and InputHub.pressed(solo_slot, "a"):
			_solo_cd = 0.75
			_spawn(_ret_pos)
			(avatars[solo_slot] as PartyAvatar).rig.play("cast", 0.05, 1.6, true)
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = lerpf(0.35, 1.1, time_left / time_limit) * (2.4 if category == "1v3" else 1.0)
		var target := Vector3(randf_range(-RADIUS, RADIUS), 0, randf_range(-RADIUS, RADIUS))
		if randf() < 0.35 * (1.0 - time_left / time_limit) + 0.1:
			var living: Array = []
			for i in 4:
				if alive[i]:
					living.append(avatars[i])
			if not living.is_empty():
				var v: Node3D = living[randi() % living.size()]
				target = Vector3(v.global_position.x, 0, v.global_position.z)
		if Vector2(target.x, target.z).length() > RADIUS - 0.5:
			target = Vector3(target.x, 0, target.z).normalized() * (RADIUS - 0.5)
		_spawn(target)
	for m in meteors.duplicate():
		m.t = float(m.t) + delta
		var k: float = clampf(float(m.t) / float(m.dur), 0.0, 1.0)
		var node: Node3D = m.node
		node.position = (m.from as Vector3).lerp(m.to, k)
		node.rotation += Vector3(3, 2, 1) * delta
		var ring: MeshInstance3D = m.ring
		ring.scale = Vector3.ONE * lerpf(0.3, 2.4, k)
		(ring.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color.a = 0.3 + 0.5 * k
		if k >= 1.0:
			_impact(m)


func _spawn(target: Vector3) -> void:
	var node := Assets.spawn("space/meteor", world, target + Vector3(randf_range(-8, 8), 30, -12), 0.0, 1.2)
	Assets.tint(node, Color(1.2, 0.7, 0.4), false, 0.8)
	var trail := FX.make_trail(node, "embers")
	trail.emitting = true
	trail.amount = 20
	var ring := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	q.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = FX.tex_ring
	m.albedo_color = Color(1, 0.25, 0.15, 0.3)
	q.material = m
	ring.mesh = q
	world.add_child(ring)
	ring.position = target + Vector3.UP * 0.06
	meteors.append({"node": node, "ring": ring, "from": node.position, "to": target, "t": 0.0, "dur": randf_range(1.4, 2.0)})
	Audio.sfx("whistle_fall", target, -12.0)


func _impact(m: Dictionary) -> void:
	meteors.erase(m)
	var p: Vector3 = m.to
	(m.node as Node3D).queue_free()
	(m.ring as Node3D).queue_free()
	FX.explosion(p, 0.9)
	var crater := Assets.spawn("space/crater", world, p, randf() * 360.0, 0.9)
	Juice.pop_in(crater, 0.2)
	for i in 4:
		var av := avatars[i] as PartyAvatar
		if not alive[i] or i == solo_slot:
			continue
		var d := Vector2(av.global_position.x - p.x, av.global_position.z - p.z).length()
		if d < 1.7:
			_blast(i)
		elif d < 3.2:
			av.apply_knockback(Vector3(av.global_position.x - p.x, 0, av.global_position.z - p.z), 10.0, 0.5, 4.0)


func _blast(i: int) -> void:
	var av := avatars[i] as PartyAvatar
	av.alive = false
	av.freeze(true)
	av.set_physics_process(false)
	av.rig.set_soot(10.0)
	av.rig.react("launch")
	eliminate(i)
	InputHub.rumble(i, 1.0, 0.4)
	var from := av.global_position
	var tw := av.create_tween()
	tw.tween_property(av, "global_position", from + Vector3(randf_range(-5, 5), 24, -10), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(av.rig.pivot, "rotation:x", TAU * 3.0, 1.2)
	tw.tween_callback(func() -> void:
		FX.stars(av.global_position, Color(1, 1, 0.9), 6)
		Audio.sfx("bell", null, -8.0, 2.0)
		av.visible = false)


func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	if slot == solo_slot:
		# Solo-KI: Zielkreis zum nächsten Trio-Mitglied (mit Vorhalt), dann werfen
		var tgt := Vector3.INF
		for i in active_slots():
			if i != solo_slot and alive[i]:
				var ap := (avatars[i] as PartyAvatar)
				var pp := ap.global_position + ap.velocity * 0.8
				if tgt == Vector3.INF or pp.distance_to(_ret_pos) < tgt.distance_to(_ret_pos):
					tgt = pp
		var mv2 := Vector2.ZERO
		var held := {}
		if tgt != Vector3.INF:
			var to := Vector2(tgt.x - _ret_pos.x, tgt.z - _ret_pos.z)
			mv2 = to.normalized() * clampf(to.length() / 2.0, 0.0, 1.0)
			if to.length() < [2.2, 1.6, 1.1][Game.players[slot].cpu_level]:
				held["a"] = true
		InputHub.set_virtual(slot, mv2, held)
		return
	if not alive[slot]:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var pos := av.global_position
	var flee := Vector2.ZERO
	for m in meteors:
		var to: Vector3 = m.to
		var d := Vector2(pos.x - to.x, pos.z - to.z)
		var danger := 3.4 - d.length()
		var urgency: float = float(m.t) / float(m.dur)
		if danger > 0.0 and urgency > [0.55, 0.35, 0.15][level]:
			flee += d.normalized() * danger
	var center_pull := -Vector2(pos.x, pos.z) / RADIUS * 0.6
	var mv := (flee + center_pull)
	InputHub.set_virtual(slot, mv.normalized() if mv.length() > 0.15 else Vector2.ZERO)
