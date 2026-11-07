extends MinigameBase
## Turm-Balancieren: Über jedem Turm schwingt ein Dungeon-Block am Haken. Mit A fallen lassen –
## Säulen und Platten stapeln sich physikalisch (Jolt). Ein Wind-Mutator weht ständig aus
## wechselnder Richtung. Wer am Ende den höchsten Turm hat, gewinnt.

const BASE_X := [-7.5, -2.5, 2.5, 7.5]
const BASE_Y := 1.0
const HOOK_ABOVE := 3.6
const SWING := 1.5

var towers: Array[Dictionary] = []
var _wind := 0.0
var _wind_target := 0.0
var _wind_t := 4.0
var _wind_label: Label
var _wind_fx: CPUParticles3D
var _phys_mat: PhysicsMaterial
var _t := 0.0


func _init() -> void:
	game_id = "tower_balance"
	env_preset = "sky"
	time_limit = 45.0
	score_format = "%.1f m"
	arena_radius = 11.0
	arena_center = Vector3(0, 2, 0)
	cannon_pos = Vector3(-13, 0, 6)
	spawn_points = [Vector3(-7.5, BASE_Y + 0.2, 1.8), Vector3(-2.5, BASE_Y + 0.2, 1.8), Vector3(2.5, BASE_Y + 0.2, 1.8), Vector3(7.5, BASE_Y + 0.2, 1.8)]
	touch_profile = "action_only"


func build_arena() -> void:
	_phys_mat = PhysicsMaterial.new()
	_phys_mat.friction = 1.0
	_phys_mat.bounce = 0.0
	var clouds := WorldKit.water(world, Vector2(200, 200), -8.0, Color(0.92, 0.94, 1.0), Color(1, 1, 1))
	(clouds.mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter("wave_height", 0.6)
	WorldKit.box(world, Vector3(22, 2, 6), Vector3(0, 0, 0.5), Color("#7fc95a"))
	for x in BASE_X:
		var base := WorldKit.box(world, Vector3(2.6, 0.4, 2.6), Vector3(x, BASE_Y + 0.2, 0), Color("#b8a090"))
		(base as StaticBody3D).physics_material_override = _phys_mat
		WorldKit.place(world, "castle/flag_pennant", Vector3(x + 1.5, BASE_Y, 1.4), 0.0, 1.6)
	for p in [Vector3(-12, 1, -3), Vector3(12, 1, -3)]:
		var t := Assets.spawn("castle/tower_base", world, p, 0.0, 3.0)
		Assets.spawn("castle/tower_mid", t, Vector3(0, 1, 0))
		Assets.spawn("castle/tower_roof", t, Vector3(0, 2, 0))
	WorldKit.place(world, "town/windmill", Vector3(0, 1, -9), 0.0, 3.0)
	_wind_fx = FX.make_trail(world, "dust")
	_wind_fx.amount = 40
	_wind_fx.lifetime = 1.2
	_wind_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_wind_fx.emission_box_extents = Vector3(1, 8, 4)
	_wind_fx.position = Vector3(-14, 6, 0)
	_wind_fx.gravity = Vector3.ZERO
	_wind_fx.initial_velocity_min = 14.0
	_wind_fx.initial_velocity_max = 20.0
	_wind_fx.spread = 4.0
	_wind_fx.direction = Vector3(1, 0, 0)


func spawn_players() -> void:
	super.spawn_players()
	for i in 4:
		var av := avatars[i] as PartyAvatar
		av.freeze(true)
		var hook := Node3D.new()
		world.add_child(hook)
		var rope := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.04
		cm.bottom_radius = 0.04
		cm.height = 3.0
		cm.material = WorldKit.mat(Color("#6a4a2a"))
		rope.mesh = cm
		rope.position.y = 1.5
		hook.add_child(rope)
		towers.append({"hook": hook, "held": null, "blocks": [], "cool": 0.6, "count": 0, "height": 0.0, "phase": randf() * TAU})


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 3.0, 0)
	c.offset = Vector3(0, 5.0, 19.0)
	c.follow = false


func _top_y(i: int) -> float:
	return BASE_Y + 0.4 + towers[i].height


func on_tick(delta: float) -> void:
	_t += delta
	# Wind-Mutator
	_wind_t -= delta
	if _wind_t <= 0.0:
		_wind_t = randf_range(4.0, 7.0)
		_wind_target = [-1.0, 1.0][randi() % 2] * randf_range(0.6, 1.0) if randf() < 0.75 else 0.0
		if _wind_target != 0.0:
			Audio.sfx("whoosh", null, 0.0, 0.6)
			CutsceneManager.big_word("WIND " + ("→" if _wind_target > 0 else "←"), Color("#bfe3ff"), 0.8)
	_wind = lerpf(_wind, _wind_target, clampf(delta * 1.5, 0, 1))
	_wind_fx.emitting = absf(_wind) > 0.2
	_wind_fx.position.x = -14.0 if _wind > 0 else 14.0
	_wind_fx.direction = Vector3(signf(_wind), 0, 0)
	var max_h := 0.0
	for i in 4:
		var tw: Dictionary = towers[i]
		var top := _top_y(i)
		max_h = maxf(max_h, top)
		var hook: Node3D = tw.hook
		var sx := sin(_t * (1.6 + i * 0.07) + float(tw.phase)) * SWING + _wind * 0.6
		hook.position = Vector3(BASE_X[i] + sx, top + HOOK_ABOVE, 0)
		tw.cool = float(tw.cool) - delta
		if tw.held == null and tw.cool <= 0.0:
			_new_block(i)
		if tw.held != null:
			var held: RigidBody3D = tw.held
			held.global_position = hook.global_position + Vector3.DOWN * 0.9
			held.rotation = Vector3(0, 0, sx * 0.05)
			if InputHub.pressed(i, "a"):
				_drop(i)
		# Höhe messen
		var h := 0.0
		for b in (tw.blocks as Array).duplicate():
			var rb := b as RigidBody3D
			if not is_instance_valid(rb):
				continue
			if rb.global_position.y < BASE_Y - 2.0:
				(tw.blocks as Array).erase(b)
				FX.dust(rb.global_position, Color(1, 1, 1), 8)
				rb.queue_free()
				continue
			rb.apply_central_force(Vector3(_wind * 7.0 * rb.mass * clampf((rb.global_position.y - BASE_Y) / 4.0, 0.2, 1.5), 0, 0))
			if absf(rb.global_position.x - BASE_X[i]) < 2.2 and rb.linear_velocity.length() < 0.5:
				var half: float = rb.get_meta("half_h", 0.5)
				h = maxf(h, rb.global_position.y + half - (BASE_Y + 0.4))
		tw.height = h
		scores[i] = h
	cam.fixed_center = Vector3(0, maxf(3.0, max_h - 1.5), 0)


func _new_block(i: int) -> void:
	var tw: Dictionary = towers[i]
	var pillar := int(tw.count) % 2 == 0
	var rb := RigidBody3D.new()
	rb.physics_material_override = _phys_mat
	rb.freeze = true
	rb.mass = 1.0 if pillar else 1.6
	rb.collision_layer = 1
	rb.collision_mask = 1
	rb.can_sleep = true
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	var size := Vector3(0.75, 1.5, 0.75) if pillar else Vector3(1.9, 0.36, 1.9)
	bs.size = size
	cs.shape = bs
	rb.add_child(cs)
	var model: Node3D
	if pillar:
		model = Assets.spawn("dun/column", rb, Vector3(0, -0.75, 0), randf() * 360.0, 1.07)
	else:
		model = Assets.spawn("dun/floor_small", rb, Vector3(0, -0.06, 0), 0.0, 0.95)
		model.scale.y = 2.4
	rb.set_meta("half_h", size.y * 0.5)
	world.add_child(rb)
	rb.global_position = (tw.hook as Node3D).global_position + Vector3.DOWN * 0.9
	tw.held = rb
	tw.count = int(tw.count) + 1
	Juice.pop_in(rb, 0.25)


func _drop(i: int) -> void:
	var tw: Dictionary = towers[i]
	var rb: RigidBody3D = tw.held
	tw.held = null
	tw.cool = 1.1
	rb.freeze = false
	rb.linear_velocity = Vector3(cos(_t * 1.6) * 0.5, -1.0, 0)
	(tw.blocks as Array).append(rb)
	Audio.sfx("drop", rb.global_position)
	rb.body_entered.connect(func(_b: Node) -> void:
		if rb.has_meta("landed"):
			return
		rb.set_meta("landed", true)
		Audio.sfx("stone_hit", rb.global_position, -4.0)
		FX.dust(rb.global_position + Vector3.DOWN * 0.3, Color(0.8, 0.75, 0.7), 6, 0.6)
		Juice.shake(0.06))
	rb.contact_monitor = true
	rb.max_contacts_reported = 2
	InputHub.rumble(i, 0.25, 0.08)
	if rigs[i]:
		(rigs[i] as CharacterRig).react("determined" if randf() < 0.5 else "scared")


func _update_badges() -> void:
	for i in badges.size():
		badges[i].set_score("%.1f m" % scores[i])


# --- CPU ---------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var tw: Dictionary = towers[slot]
	var held := {}
	if tw.held != null:
		var level: int = Game.players[slot].cpu_level
		var tol: float = [0.55, 0.3, 0.12][level]
		var hx := (tw.hook as Node3D).global_position.x
		var target_x: float = BASE_X[slot]
		for b in tw.blocks:
			if is_instance_valid(b) and (b as RigidBody3D).global_position.y > _top_y(slot) - 0.8:
				target_x = (b as RigidBody3D).global_position.x
		target_x -= _wind * 0.4
		if absf(hx - target_x) < tol and randf() < 0.35:
			held["a"] = true
	InputHub.set_virtual(slot, Vector2.ZERO, held)
