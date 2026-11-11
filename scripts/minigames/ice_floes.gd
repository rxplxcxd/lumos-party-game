extends MinigameBase
## Eisschollen-Sturm: Eine Scholle aus sechseckigen Eisplatten im Polarmeer. Platten knacken (Risse, Wackeln)
## und versinken, Windböen (Pfeil + Schneetreiben kündigen sie an) schieben alle übers glatte Eis.
## B = Schubsen. Wer ins Wasser rutscht, ist raus; gelungene Schubser zählen bei Gleichstand.
## Online: Besitzer-Modell (Platten und Böen aus dem gemeinsamen Zufall, Schubser über shove_remote).

const HEX_R := 1.95
const RINGS := 2

var _tiles: Array[Dictionary] = []   # {body, mesh, ring, state 0=fest 1=knackt 2=weg, t}
var _crack_t := 3.5
var _gust_state := 0                 # 0 = ruhig, 1 = Warnung, 2 = Böe
var _gust_t := 6.5
var _gust_dir := Vector3.ZERO
var _arrow: Node3D
var _snow_t := 0.0


func _init() -> void:
	game_id = "ice_floes"
	env_preset = "snow"
	backdrop_style = "sky_day"
	time_limit = 45.0
	survival = true
	hazard = "water"
	kill_y = -2.0
	arena_radius = 9.0
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 12)
	spawn_points = [Vector3(-2.6, 0.6, -1.6), Vector3(2.6, 0.6, -1.6), Vector3(-2.6, 0.6, 1.8), Vector3(2.6, 0.6, 1.8)]


func build_arena() -> void:
	WorldKit.water(world, Vector2(80, 80), -0.9, Color(0.12, 0.3, 0.45), Color(0.6, 0.85, 0.95))
	# Axiales Sechseck-Raster: Mitte, 6 Innen-, 12 Außenplatten
	for q in range(-RINGS, RINGS + 1):
		for r in range(-RINGS, RINGS + 1):
			var s := -q - r
			var ring := maxi(absi(q), maxi(absi(r), absi(s)))
			if ring > RINGS:
				continue
			var pos := Vector3(HEX_R * 1.5 * q, 0, HEX_R * sqrt(3.0) * (r + q * 0.5)) * 1.02
			_add_tile(pos, ring)
	# Eisberge, Pinguin-Iglus und Schneeschollen ringsum
	for i in 9:
		var a := TAU * i / 9.0 + 0.3
		var p := Vector3(cos(a), 0, sin(a)) * randf_range(13.0, 17.0)
		WorldKit.cylinder(world, randf_range(1.2, 2.6), randf_range(1.5, 4.5), p + Vector3(0, -0.4, 0), Color("#e8f6ff"), false)
	for i in 3:
		var a3 := TAU * i / 3.0 + 1.2
		var pp := Vector3(cos(a3), 0, sin(a3)) * 11.5
		WorldKit.cylinder(world, 1.2, 0.4, pp + Vector3(0, -0.75, 0), Color("#e8f6ff"), false)
		var peng := WorldKit.place(world, "pet/penguin", pp + Vector3(0, -0.55, 0), rad_to_deg(-a3) - 90.0, 1.4)
		var wob := peng.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		wob.tween_property(peng, "rotation:z", 0.12, 0.6 + i * 0.1)
		wob.tween_property(peng, "rotation:z", -0.12, 0.6 + i * 0.1)
	for i in 4:
		var a2 := TAU * i / 4.0 + 0.8
		WorldKit.place(world, "nat/pine_snow", Vector3(cos(a2), 0, sin(a2)) * 15.0 + Vector3(0, 0.6, 0), randf() * 360.0, 2.2)
	_arrow = Node3D.new()
	world.add_child(_arrow)
	var shaft := WorldKit.box(_arrow, Vector3(0.7, 0.12, 3.0), Vector3(0, 0, -0.6), Color(0.7, 0.95, 1.0), false)
	var head := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(1.9, 1.5, 0.12)
	pm.material = WorldKit.mat(Color(0.7, 0.95, 1.0), 0.4, 1.0)
	head.mesh = pm
	head.rotation.x = -PI / 2.0
	head.position = Vector3(0, 0, 1.4)
	_arrow.add_child(head)
	(shaft.get_child(0) as MeshInstance3D).material_override = pm.material
	_arrow.visible = false


func _add_tile(pos: Vector3, ring: int) -> void:
	var body := StaticBody3D.new()
	world.add_child(body)
	body.position = pos + Vector3(0, -0.3, 0)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = HEX_R
	cm.bottom_radius = HEX_R * 0.88
	cm.height = 0.6
	cm.radial_segments = 6
	cm.rings = 1
	var col := Color("#dff3ff").lerp(Color("#bfe6ff"), randf() * 0.6)
	cm.material = WorldKit.mat(col, 0.12)
	mi.mesh = cm
	mi.rotation.y = PI / 6.0
	body.add_child(mi)
	# Schneehäubchen obenauf
	var cap := WorldKit.cylinder(mi, HEX_R * 0.55, 0.05, Vector3(randf_range(-0.4, 0.4), 0.31, randf_range(-0.4, 0.4)), Color("#ffffff"), false)
	cap.scale = Vector3(1.0, 1.0, randf_range(0.6, 1.0))
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = HEX_R * 0.97
	sh.height = 0.6
	cs.shape = sh
	body.add_child(cs)
	_tiles.append({"body": body, "mesh": mi, "ring": ring, "state": 0, "t": 0.0, "cs": cs})


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, 0.5)
	c.offset = Vector3(0, 14.0, 12.0)
	c.min_dist = 0.9
	c.max_dist = 1.1


func on_start() -> void:
	for av in avatars:
		var pa := av as PartyAvatar
		pa.slippery = 0.8
		pa.rig.surface = "stone"
		if not pa.shoved.is_connected(_on_shoved):
			pa.shoved.connect(_on_shoved)


func _on_shoved(by: PartyAvatar, _victim: PartyAvatar) -> void:
	if state == "play" and net_owned(by.slot):
		add_score(by.slot, 1.0)


func on_tick(delta: float) -> void:
	var prog := 1.0 - time_left / time_limit
	_update_tiles(delta, prog)
	_update_gust(delta, prog)


func _update_tiles(delta: float, prog: float) -> void:
	_crack_t -= delta
	if _crack_t <= 0.0:
		_crack_t = lerpf(3.6, 1.8, prog)
		# Erst die Außenplatten, dann die inneren – die Mitte bleibt immer
		var cand: Array[int] = []
		for want in [2, 1]:
			for k in _tiles.size():
				if int(_tiles[k].ring) == want and int(_tiles[k].state) == 0:
					cand.append(k)
			if not cand.is_empty():
				break
		if not cand.is_empty():
			_crack(cand[rng.randi() % cand.size()])
	for t in _tiles:
		if int(t.state) != 1:
			continue
		t.t = float(t.t) - delta
		var mi: MeshInstance3D = t.mesh
		mi.position = Vector3(sin(float(t.t) * 47.0) * 0.05, 0, cos(float(t.t) * 39.0) * 0.05)
		if float(t.t) <= 0.0:
			t.state = 2
			(t.cs as CollisionShape3D).set_deferred("disabled", true)
			var body: Node3D = t.body
			FX.splash(body.global_position + Vector3.UP * 0.3, 1.4)
			Audio.sfx("splash", body.global_position)
			var tw := body.create_tween()
			tw.tween_property(body, "position:y", -2.5, 0.9).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(body, "rotation:z", 0.5, 0.9)
			tw.tween_callback(body.hide)


func _crack(k: int) -> void:
	var t := _tiles[k]
	t.state = 1
	t.t = 1.8
	var mi: MeshInstance3D = t.mesh
	var m := ((mi.mesh as CylinderMesh).material as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.albedo_color = Color("#7fc6ef")
	m.emission_enabled = true
	m.emission = Color(0.3, 0.6, 0.9)
	m.emission_energy_multiplier = 0.4
	mi.material_override = m
	# Risslinien
	for i in 3:
		var crack := WorldKit.box(mi, Vector3(0.06, 0.02, HEX_R * 1.4), Vector3(0, 0.31, 0), Color("#24506e"), false)
		crack.rotation.y = i * 1.05 + rng.randf() * 0.4
	Audio.sfx("plank_break", (t.body as Node3D).global_position, -6.0, 1.4)
	FX.sparks((t.body as Node3D).global_position + Vector3.UP * 0.4, Color(0.8, 0.95, 1.0), 8)


func _update_gust(delta: float, prog: float) -> void:
	_gust_t -= delta
	match _gust_state:
		0:
			if _gust_t <= 0.0:
				_gust_state = 1
				_gust_t = 1.6
				var a := rng.randf() * TAU
				_gust_dir = Vector3(cos(a), 0, sin(a))
				_arrow.visible = true
				_arrow.position = Vector3(0, 2.6, 0)
				_arrow.look_at(_arrow.position + _gust_dir, Vector3.UP)
				_arrow.rotate_object_local(Vector3.UP, PI)
				_arrow.scale = Vector3.ONE * 0.2
				_arrow.create_tween().tween_property(_arrow, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)
				Audio.sfx("alert", Vector3.ZERO, -6.0)
		1:
			_arrow.position.y = 2.6 + sin(_gust_t * 12.0) * 0.12
			if _gust_t <= 0.0:
				_gust_state = 2
				_gust_t = lerpf(1.8, 2.6, prog)
				Audio.sfx("woom", Vector3.ZERO, -2.0, 0.7)
				Juice.shake(0.15)
		2:
			var force := lerpf(7.0, 10.5, prog)
			for i in active_slots():
				var av := avatars[i] as PartyAvatar
				if av.alive and net_owned(i):
					av.velocity += _gust_dir * force * delta
			_snow_t -= delta
			if _snow_t <= 0.0:
				_snow_t = 0.08
				FX.dust(-_gust_dir * 8.0 + Vector3(randf_range(-6, 6), randf_range(0.5, 2.5), randf_range(-6, 6)), Color(1, 1, 1, 0.8), 3, 0.5)
			if _gust_t <= 0.0:
				_gust_state = 0
				_gust_t = lerpf(5.5, 3.6, prog) * rng.randf_range(0.85, 1.15)
				_arrow.visible = false


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	if not av.alive:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var p := av.global_position
	# Ziel: nächste feste Platte nahe der Mitte (knackende meiden)
	var best := Vector3.ZERO
	var bs := INF
	for t in _tiles:
		if int(t.state) != 0:
			continue
		var tp := (t.body as Node3D).global_position
		var sc := tp.distance_to(p) * 0.6 + Vector2(tp.x, tp.z).length() * 0.5
		if sc < bs:
			bs = sc
			best = tp
	var to := best - p
	var mv := Vector2(to.x, to.z)
	mv = mv.normalized() * clampf(mv.length() * 0.6, 0.0, 1.0)
	if _gust_state == 2 or (_gust_state == 1 and _gust_t < [0.2, 0.5, 0.9][level]):
		mv += -Vector2(_gust_dir.x, _gust_dir.z) * [0.5, 0.8, 1.0][level]
	var held := {}
	for o in avatars:
		var oa := o as PartyAvatar
		if oa != av and oa.alive and oa.global_position.distance_to(p) < 1.7 and randf() < [0.02, 0.04, 0.07][level]:
			held["b"] = true
			mv = Vector2(oa.global_position.x - p.x, oa.global_position.z - p.z).normalized()
	InputHub.set_virtual(slot, mv.limit_length(1.0), held)
