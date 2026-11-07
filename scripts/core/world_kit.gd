class_name WorldKit
extends RefCounted
## Baukasten für Welten: Licht-/Himmels-Presets, Böden, Wasser, Lava, Props mit Kollision, Streuung.

const PRESETS := {
	"day": {"sky_top": Color("#3d8bff"), "sky_horizon": Color("#bfe3ff"), "ground": Color("#7fb860"), "sun": Color("#fff2d6"),
		"sun_energy": 1.25, "sun_rot": Vector3(-52, -35, 0), "ambient": Color("#b8c8e8"), "ambient_energy": 0.7,
		"fog": false, "fog_color": Color("#bfe3ff"), "fog_density": 0.002},
	"sunset": {"sky_top": Color("#4b2a8a"), "sky_horizon": Color("#ff9a6b"), "ground": Color("#6a4a5a"), "sun": Color("#ffc49a"),
		"sun_energy": 1.1, "sun_rot": Vector3(-25, -60, 0), "ambient": Color("#c8a0c0"), "ambient_energy": 0.65,
		"fog": true, "fog_color": Color("#ff9a8b"), "fog_density": 0.004},
	"pirates": {"sky_top": Color("#2f8cff"), "sky_horizon": Color("#ffe8b0"), "ground": Color("#3a9fd0"), "sun": Color("#fff0c8"),
		"sun_energy": 1.3, "sun_rot": Vector3(-48, 30, 0), "ambient": Color("#bcd8f0"), "ambient_energy": 0.75,
		"fog": true, "fog_color": Color("#cfeaff"), "fog_density": 0.0025},
	"dungeon": {"sky_top": Color("#0d0718"), "sky_horizon": Color("#2a1430"), "ground": Color("#1a0d1a"), "sun": Color("#ffb070"),
		"sun_energy": 0.55, "sun_rot": Vector3(-65, 20, 0), "ambient": Color("#5a4a80"), "ambient_energy": 0.55,
		"fog": true, "fog_color": Color("#2a1030"), "fog_density": 0.012},
	"sky": {"sky_top": Color("#5aa8ff"), "sky_horizon": Color("#fff6ff"), "ground": Color("#ffffff"), "sun": Color("#fffbe8"),
		"sun_energy": 1.3, "sun_rot": Vector3(-40, 140, 0), "ambient": Color("#d8e4ff"), "ambient_energy": 0.85,
		"fog": true, "fog_color": Color("#f4f0ff"), "fog_density": 0.003},
	"night": {"sky_top": Color("#05031a"), "sky_horizon": Color("#3a1a6a"), "ground": Color("#0a0618"), "sun": Color("#a0b0ff"),
		"sun_energy": 0.5, "sun_rot": Vector3(-60, 60, 0), "ambient": Color("#6050a0"), "ambient_energy": 0.6,
		"fog": true, "fog_color": Color("#2a0f4a"), "fog_density": 0.006},
	"volcano": {"sky_top": Color("#1a0505"), "sky_horizon": Color("#ff5a20"), "ground": Color("#200808"), "sun": Color("#ffa060"),
		"sun_energy": 0.9, "sun_rot": Vector3(-35, 10, 0), "ambient": Color("#a05040"), "ambient_energy": 0.6,
		"fog": true, "fog_color": Color("#5a1a10"), "fog_density": 0.006},
	"ghost": {"sky_top": Color("#020208"), "sky_horizon": Color("#101030"), "ground": Color("#050510"), "sun": Color("#8090ff"),
		"sun_energy": 0.08, "sun_rot": Vector3(-70, 0, 0), "ambient": Color("#202040"), "ambient_energy": 0.12,
		"fog": true, "fog_color": Color("#05050f"), "fog_density": 0.03},
}

static var _water_shader: Shader
static var _lava_shader: Shader


static func env(parent: Node, preset := "day", glow := true) -> WorldEnvironment:
	var p: Dictionary = PRESETS.get(preset, PRESETS.day)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = p.sky_top
	sm.sky_horizon_color = p.sky_horizon
	sm.ground_horizon_color = p.sky_horizon
	sm.ground_bottom_color = p.ground
	sm.sun_angle_max = 30.0
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = p.ambient
	e.ambient_light_energy = p.ambient_energy
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.05
	if glow:
		e.glow_enabled = true
		e.glow_intensity = 0.6
		e.glow_bloom = 0.05
		e.glow_hdr_threshold = 1.1
	e.fog_enabled = p.fog
	e.fog_light_color = p.fog_color
	e.fog_density = p.fog_density
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.12
	e.adjustment_contrast = 1.04
	we.environment = e
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = p.sun
	sun.light_energy = p.sun_energy
	sun.rotation_degrees = p.sun_rot
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	parent.add_child(sun)
	we.set_meta("sun", sun)
	return we


static func mat(color: Color, rough := 0.85, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


## Statischer Quader mit Kollision (Boden, Wände, Plattformen).
static func box(parent: Node, size: Vector3, pos: Vector3, color := Color(0.6, 0.6, 0.65), collide := true, layer := 1) -> Node3D:
	var root: Node3D = StaticBody3D.new() if collide else Node3D.new()
	if collide:
		(root as StaticBody3D).collision_layer = layer
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		root.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat(color)
	mi.mesh = bm
	root.add_child(mi)
	parent.add_child(root)
	root.position = pos
	return root


static func cylinder(parent: Node, radius: float, height: float, pos: Vector3, color := Color(0.6, 0.6, 0.65), collide := true) -> Node3D:
	var root: Node3D = StaticBody3D.new() if collide else Node3D.new()
	if collide:
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = radius
		sh.height = height
		cs.shape = sh
		root.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.material = mat(color)
	mi.mesh = cm
	root.add_child(mi)
	parent.add_child(root)
	root.position = pos
	return root


static func water(parent: Node, size := Vector2(200, 200), y := 0.0, deep := Color(0.05, 0.35, 0.65), shallow := Color(0.25, 0.75, 0.9)) -> MeshInstance3D:
	if _water_shader == null:
		_water_shader = load("res://assets/shaders/water.gdshader")
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	pm.subdivide_width = int(clampf(size.x / 2.5, 8, 96))
	pm.subdivide_depth = int(clampf(size.y / 2.5, 8, 96))
	var m := ShaderMaterial.new()
	m.shader = _water_shader
	m.set_shader_parameter("deep", deep)
	m.set_shader_parameter("shallow", shallow)
	pm.material = m
	mi.mesh = pm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position.y = y
	return mi


static func lava(parent: Node, size := Vector2(200, 200), y := 0.0, flow := Vector2(0, 0.25)) -> MeshInstance3D:
	if _lava_shader == null:
		_lava_shader = load("res://assets/shaders/lava.gdshader")
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	pm.subdivide_width = 24
	pm.subdivide_depth = 24
	var m := ShaderMaterial.new()
	m.shader = _lava_shader
	m.set_shader_parameter("flow", flow)
	pm.material = m
	mi.mesh = pm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position.y = y
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.45, 0.15)
	light.light_energy = 1.4
	light.omni_range = maxf(size.x, size.y) * 0.4
	light.position = Vector3(0, 2.0, 0)
	mi.add_child(light)
	return mi


## Platziert ein Katalog-Modell, optional mit Box-Kollision.
static func place(parent: Node, key: String, pos: Vector3, rot_y := 0.0, scl := 1.0, collide := false, shadows := true) -> Node3D:
	var n := Assets.spawn(key, parent, pos, rot_y, scl)
	if collide:
		Assets.add_box_collision(n, key)
	if not shadows:
		Assets.set_shadows(n, false)
	return n


## Streut Modelle zufällig auf einen Ring/Bereich, mit Abstand zum Zentrum.
static func scatter(parent: Node, keys: Array, count: int, center: Vector3, r_min: float, r_max: float, y := 0.0, scl_range := Vector2(0.8, 1.3), seed := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in count:
		var a := rng.randf() * TAU
		var r := rng.randf_range(r_min, r_max)
		var pos := center + Vector3(cos(a) * r, y, sin(a) * r)
		place(parent, keys[rng.randi() % keys.size()], pos, rng.randf() * 360.0, rng.randf_range(scl_range.x, scl_range.y), false, false)


## Leuchtender Punkt (z. B. Fackelflamme) mit flackerndem Licht.
static func torch_light(parent: Node, pos: Vector3, color := Color(1.0, 0.6, 0.25), energy := 1.8, rng := 7.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.4
	parent.add_child(l)
	l.position = pos
	var tw := l.create_tween().set_loops()
	tw.tween_property(l, "light_energy", energy * 0.75, randf_range(0.08, 0.16))
	tw.tween_property(l, "light_energy", energy * 1.1, randf_range(0.08, 0.16))
	var embers := FX.make_trail(l, "embers")
	embers.amount = 4
	embers.emission_sphere_radius = 0.15
	embers.emitting = true
	return l


## Rendert viele Kopien eines Katalog-Modells als MultiMesh (ein Draw-Call pro Teil-Mesh).
static func multimesh(parent: Node, key: String, transforms: Array) -> Node3D:
	var holder := Node3D.new()
	parent.add_child(holder)
	var ps := Assets.scene(key)
	if ps == null or transforms.is_empty():
		return holder
	var inst := ps.instantiate() as Node3D
	var stack: Array = [[inst, Transform3D.IDENTITY]]
	while stack.size() > 0:
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		var xf: Transform3D = item[1]
		if node is Node3D and node != inst:
			xf = xf * (node as Node3D).transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh:
			var mi := node as MeshInstance3D
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mi.mesh
			mm.instance_count = transforms.size()
			for i in transforms.size():
				mm.set_instance_transform(i, (transforms[i] as Transform3D) * xf)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			if mi.get_surface_override_material_count() > 0 and mi.get_surface_override_material(0):
				mmi.material_override = mi.get_surface_override_material(0)
			holder.add_child(mmi)
		for c in node.get_children():
			stack.append([c, xf])
	inst.free()
	return holder
