extends MinigameBase
## Sumo-Schubser: Eine runde Plattform über dem Meer, die langsam schrumpft. Schubser (B) sind
## doppelt so stark wie sonst. Wer zuletzt oben steht, gewinnt.

var platform: Node3D
var _radius := 9.0
var _shown_radius := 9.0
var _rim: MeshInstance3D
var _shape: CylinderShape3D
var _mesh: CylinderMesh


func _init() -> void:
	game_id = "sumo_shove"
	fair_spawns = true   # Startplätze jede Runde neu auslosen (kein fester Platzvorteil)
	env_preset = "sunset"
	time_limit = 50.0
	survival = true
	hazard = "water"
	kill_y = -3.0
	arena_radius = 10.0
	teaser_height = 0.9
	cannon_pos = Vector3(0, 0, 13)
	spawn_points = [Vector3(-3.5, 0.6, -3.5), Vector3(3.5, 0.6, -3.5), Vector3(-3.5, 0.6, 3.5), Vector3(3.5, 0.6, 3.5)]


func build_arena() -> void:
	WorldKit.water(world, Vector2(140, 140), -2.6, Color(0.05, 0.2, 0.4), Color(0.2, 0.45, 0.65))
	platform = WorldKit.cylinder(world, _radius, 1.0, Vector3(0, -0.5, 0), Color("#ecdcb0"))
	for c in platform.get_children():
		if c is CollisionShape3D:
			_shape = (c as CollisionShape3D).shape as CylinderShape3D
		elif c is MeshInstance3D:
			_mesh = (c as MeshInstance3D).mesh as CylinderMesh
	# Sockel unter der Plattform: Holzpfähle im Wasser
	for i in 6:
		var a0 := TAU * i / 6.0
		WorldKit.cylinder(world, 0.35, 3.0, Vector3(cos(a0) * 2.2, -2.2, sin(a0) * 2.2), Color("#6b4a2b"), false)
	var mat := WorldKit.mat(Color("#e8c79a"), 0.9, 0.05)
	_rim = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.96
	tm.outer_radius = 1.04
	tm.rings = 48
	tm.material = mat
	_rim.mesh = tm
	_rim.scale = Vector3(_radius, 1.0, _radius)
	_rim.position.y = 0.02
	world.add_child(_rim)
	for i in 8:
		var a := TAU * i / 8.0
		var p := Vector3(cos(a), -2.5, sin(a)) * 1.0 * 15.0
		p.y = -2.5
		WorldKit.place(world, "pirate/rocks_b" if i % 2 else "nat/rock_tall", p, randf() * 360.0, 3.0)
	WorldKit.place(world, "arena/statue", Vector3(0, -2.6, -18), 0.0, 6.0)
	for side in [-1.0, 1.0]:
		WorldKit.place(world, "arena/column", Vector3(side * 16, -2.6, -14), 0.0, 6.0)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, 0.5)
	c.offset = Vector3(0, 15, 13)
	c.min_dist = 0.85
	c.max_dist = 1.1


func on_start() -> void:
	for av in avatars:
		var a := av as PartyAvatar
		a.shove_power = 20.0
		a.rig.surface = "sand"


func on_tick(delta: float) -> void:
	var target := lerpf(3.2, 9.0, time_left / time_limit)
	_radius = move_toward(_radius, target, delta * 0.25)
	_rim.scale = Vector3(_radius, 1.0, _radius)
	pass
	# Kollision & Mesh nur in kleinen Schritten neu aufbauen (Physik-sicher, kein nicht-uniformer Scale)
	if absf(_shown_radius - _radius) > 0.04:
		_shown_radius = _radius
		_shape.radius = _radius
		_mesh.top_radius = _radius
		_mesh.bottom_radius = _radius
		FX.dust(Vector3(_radius, 0.1, 0).rotated(Vector3.UP, randf() * TAU), Color(0.85, 0.75, 0.55), 3, 0.6)


func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	if not av.alive:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var pos := av.global_position
	var best: PartyAvatar = null
	var bd := INF
	for o in avatars:
		var oa := o as PartyAvatar
		if oa != av and oa.alive:
			var d := oa.global_position.distance_to(pos)
			if d < bd:
				bd = d
				best = oa
	var mv := Vector2.ZERO
	var held := {}
	var r := Vector2(pos.x, pos.z).length()
	if r > _radius * 0.7:
		mv = -Vector2(pos.x, pos.z).normalized()
	elif best:
		var to := best.global_position - pos
		mv = Vector2(to.x, to.z).normalized()
		# Mit Anlauf vom Rand weg in Richtung Gegner + Plattformmitte schieben
		if bd < 2.2 and randf() < 0.05 * mini(level + 1, 3):
			held["b"] = true
	if level > 0 and best and bd < 1.6 and randf() < 0.02:
		held["a"] = true
	InputHub.set_virtual(slot, mv * Game.lv([0.75, 0.9, 1.0], level), held)
