class_name WorldKit
extends RefCounted
## Baukasten für Welten: Licht-/Himmels-Presets, Böden, Wasser, Lava, Props mit Kollision, Streuung.

const PRESETS := {
	"day": {"sky_top": Color("#2f74d8"), "sky_horizon": Color("#a9d4f2"), "ground": Color("#4f7a3c"), "sun": Color("#fff0d0"),
		"sun_energy": 1.0, "sun_rot": Vector3(-48, -35, 0), "ambient": Color("#9fb8dc"), "ambient_energy": 0.42, "sky_energy": 0.8,
		"fog": true, "fog_color": Color("#a9cfee"), "fog_density": 0.0016, "rays": true},
	"sunset": {"sky_top": Color("#33307a"), "sky_horizon": Color("#e8946a"), "ground": Color("#3e3a4c"), "sun": Color("#ffc898"),
		"sun_energy": 0.95, "sun_rot": Vector3(-28, -60, 0), "ambient": Color("#9890b4"), "ambient_energy": 0.42, "sky_energy": 0.72,
		"fog": true, "fog_color": Color("#b88a98"), "fog_density": 0.0022, "rays": true},
	"pirates": {"sky_top": Color("#2a7ae0"), "sky_horizon": Color("#cfe6f2"), "ground": Color("#2c86b8"), "sun": Color("#fff2d4"),
		"sun_energy": 0.95, "sun_rot": Vector3(-46, 30, 0), "ambient": Color("#93b6d8"), "ambient_energy": 0.42, "sky_energy": 0.8,
		"fog": true, "fog_color": Color("#b8dcf0"), "fog_density": 0.0018, "rays": true},
	"dungeon": {"sky_top": Color("#0d0718"), "sky_horizon": Color("#2a1430"), "ground": Color("#1a0d1a"), "sun": Color("#ffb070"),
		"sun_energy": 0.5, "sun_rot": Vector3(-65, 20, 0), "ambient": Color("#5a4a80"), "ambient_energy": 0.5, "sky_energy": 1.0,
		"fog": true, "fog_color": Color("#2a1030"), "fog_density": 0.011},
	"sky": {"sky_top": Color("#3c86e6"), "sky_horizon": Color("#d8e6fa"), "ground": Color("#c8d4ea"), "sun": Color("#fff6e0"),
		"sun_energy": 0.95, "sun_rot": Vector3(-40, 140, 0), "ambient": Color("#a8b8e0"), "ambient_energy": 0.45, "sky_energy": 0.78,
		"fog": true, "fog_color": Color("#d4def5"), "fog_density": 0.0014, "rays": true},
	"night": {"sky_top": Color("#05031a"), "sky_horizon": Color("#3a1a6a"), "ground": Color("#0a0618"), "sun": Color("#a0b0ff"),
		"sun_energy": 0.5, "sun_rot": Vector3(-60, 60, 0), "ambient": Color("#6050a0"), "ambient_energy": 0.6, "sky_energy": 1.0,
		"fog": true, "fog_color": Color("#2a0f4a"), "fog_density": 0.006},
	"storm": {"sky_top": Color("#060914"), "sky_horizon": Color("#1c2240"), "ground": Color("#080a12"), "sun": Color("#9fb4ff"),
		"sun_energy": 0.35, "sun_rot": Vector3(-58, 25, 0), "ambient": Color("#3a4470"), "ambient_energy": 0.42, "sky_energy": 1.0,
		"fog": true, "fog_color": Color("#121830"), "fog_density": 0.0085},
	"snow": {"sky_top": Color("#5a86c8"), "sky_horizon": Color("#d9e4f0"), "ground": Color("#c9d6e6"), "sun": Color("#fff4e6"),
		"sun_energy": 0.85, "sun_rot": Vector3(-35, -40, 0), "ambient": Color("#a6b8d8"), "ambient_energy": 0.42, "sky_energy": 0.72,
		"fog": true, "fog_color": Color("#c8d6e8"), "fog_density": 0.004, "rays": true},
	"space": {"sky_top": Color("#02020a"), "sky_horizon": Color("#1a1040"), "ground": Color("#05040c"), "sun": Color("#ffe6c8"),
		"sun_energy": 1.0, "sun_rot": Vector3(-30, 70, 0), "ambient": Color("#4a4a8a"), "ambient_energy": 0.4, "sky_energy": 1.0,
		"fog": false, "fog_color": Color("#100830"), "fog_density": 0.002},
	"volcano": {"sky_top": Color("#1a0505"), "sky_horizon": Color("#d84a1c"), "ground": Color("#200808"), "sun": Color("#ffa060"),
		"sun_energy": 0.85, "sun_rot": Vector3(-35, 10, 0), "ambient": Color("#a05040"), "ambient_energy": 0.5, "sky_energy": 0.9,
		"fog": true, "fog_color": Color("#5a1a10"), "fog_density": 0.006},
	"ghost": {"sky_top": Color("#020208"), "sky_horizon": Color("#101030"), "ground": Color("#050510"), "sun": Color("#8090ff"),
		"sun_energy": 0.08, "sun_rot": Vector3(-70, 0, 0), "ambient": Color("#202040"), "ambient_energy": 0.14, "sky_energy": 1.0,
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
	sm.sky_curve = 0.12
	sm.sun_angle_max = 25.0
	sm.energy_multiplier = p.get("sky_energy", 0.85)
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	# Himmel als Umgebungslicht (natürlicher Verlauf statt flacher Farbe), leicht eingefärbt
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_color = p.ambient
	e.ambient_light_sky_contribution = 0.55
	e.ambient_light_energy = p.ambient_energy
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.95
	e.tonemap_white = 1.2
	if glow:
		e.glow_enabled = true
		e.glow_intensity = 0.45
		e.glow_bloom = 0.0
		e.glow_hdr_threshold = 1.0
		e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.fog_enabled = p.fog
	e.fog_light_color = p.fog_color
	e.fog_density = p.fog_density
	e.fog_sun_scatter = 0.12
	e.fog_aerial_perspective = 0.35
	e.adjustment_enabled = true
	e.adjustment_brightness = 0.98
	e.adjustment_contrast = 1.14
	e.adjustment_saturation = 1.22
	we.environment = e
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = p.sun
	sun.light_energy = p.sun_energy
	sun.rotation_degrees = p.sun_rot
	sun.shadow_enabled = true
	sun.shadow_blur = 1.0
	sun.shadow_opacity = 0.9
	sun.light_angular_distance = 0.6
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	parent.add_child(sun)
	we.set_meta("sun", sun)
	we.set_meta("preset", preset)
	return we


## Lichtschäfte entlang der Sonnenrichtung über einem Bereich (God Rays).
static func god_rays(parent: Node, center: Vector3, radius: float, sun: DirectionalLight3D, count := 7, tint := Color(1.0, 0.9, 0.65), strength := 0.16) -> Node3D:
	var holder := Node3D.new()
	parent.add_child(holder)
	if Gfx.active == "low":
		return holder
	var shader: Shader = load("res://assets/shaders/god_rays.gdshader")
	var dir := -sun.global_basis.z.normalized() if sun.is_inside_tree() else Vector3(0.3, -1, 0.2).normalized()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(center)
	for i in count:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		mi.mesh = q
		var m := ShaderMaterial.new()
		m.shader = shader
		var length := rng.randf_range(30.0, 55.0)
		m.set_shader_parameter("axis", dir)
		m.set_shader_parameter("length", length)
		m.set_shader_parameter("width", rng.randf_range(3.0, 8.0))
		m.set_shader_parameter("tint", tint)
		m.set_shader_parameter("strength", strength * rng.randf_range(0.6, 1.2))
		m.set_shader_parameter("seed", rng.randf())
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 80.0
		holder.add_child(mi)
		var target := center + Vector3(rng.randf_range(-radius, radius), 0, rng.randf_range(-radius, radius))
		mi.global_position = target - dir * length * 0.85
	return holder


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
