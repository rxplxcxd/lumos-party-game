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
	"graveyard": {"sky_top": Color("#070a1e"), "sky_horizon": Color("#2a2a5a"), "ground": Color("#0c0c1a"), "sun": Color("#b8c8ff"),
		"sun_energy": 0.55, "sun_rot": Vector3(-52, 35, 0), "ambient": Color("#5a5a9a"), "ambient_energy": 0.55, "sky_energy": 1.0,
		"fog": true, "fog_color": Color("#2a2850"), "fog_density": 0.009},
	"station": {"sky_top": Color("#03030c"), "sky_horizon": Color("#1c1448"), "ground": Color("#06060f"), "sun": Color("#fff0dc"),
		"sun_energy": 0.95, "sun_rot": Vector3(-50, -30, 0), "ambient": Color("#6a74b0"), "ambient_energy": 0.55, "sky_energy": 1.0,
		"fog": false, "fog_color": Color("#120a30"), "fog_density": 0.002},
	"desert": {"sky_top": Color("#3f78c4"), "sky_horizon": Color("#efc48e"), "ground": Color("#8a6a40"), "sun": Color("#ffe2b8"),
		"sun_energy": 1.0, "sun_rot": Vector3(-40, 50, 0), "ambient": Color("#c4a888"), "ambient_energy": 0.4, "sky_energy": 0.75,
		"fog": true, "fog_color": Color("#e3c39a"), "fog_density": 0.0028, "rays": true},
	"observatory": {"sky_top": Color("#2a2a66"), "sky_horizon": Color("#c79bd8"), "ground": Color("#3a3466"), "sun": Color("#ffe6c8"),
		"sun_energy": 0.85, "sun_rot": Vector3(-45, -30, 0), "ambient": Color("#a8a0d8"), "ambient_energy": 0.55, "sky_energy": 0.9,
		"fog": true, "fog_color": Color("#8a7ab8"), "fog_density": 0.002},
	"forest_night": {"sky_top": Color("#0c1238"), "sky_horizon": Color("#3a3a78"), "ground": Color("#101228"), "sun": Color("#b8c8ff"),
		"sun_energy": 0.35, "sun_rot": Vector3(-50, 30, 0), "ambient": Color("#5a6aa8"), "ambient_energy": 0.55, "sky_energy": 1.0,
		"fog": true, "fog_color": Color("#283060"), "fog_density": 0.006},
	"mansion": {"sky_top": Color("#140c2a"), "sky_horizon": Color("#3a2a5a"), "ground": Color("#1a1226"), "sun": Color("#9fb4ff"),
		"sun_energy": 0.32, "sun_rot": Vector3(-55, 30, 0), "ambient": Color("#6a5a9a"), "ambient_energy": 0.48, "sky_energy": 0.6,
		"fog": true, "fog_color": Color("#2a1f40"), "fog_density": 0.006},
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
	e.ambient_light_sky_contribution = 0.4   # weniger bläuliches Himmelslicht in den Schatten → sattere Farben
	e.ambient_light_energy = p.ambient_energy
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# ACES statt Filmic: Filmic entsättigt helle Flächen stark (Ursache für den „ausgewaschenen“ Look);
	# ACES hält Farben satt und gibt Kontrast, wie im Nachtmodus des Zauberwalds.
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.08
	e.tonemap_white = 3.0
	if glow:
		e.glow_enabled = true
		e.glow_intensity = 0.45
		e.glow_bloom = 0.0
		e.glow_hdr_threshold = 1.0
		e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.fog_enabled = p.fog
	e.fog_light_color = p.fog_color
	e.fog_density = p.fog_density
	e.fog_sun_scatter = 0.05
	e.fog_aerial_perspective = 0.12   # weniger Dunst-Schleier über nahen Objekten
	e.adjustment_enabled = true
	e.adjustment_brightness = 1.03
	e.adjustment_contrast = 1.12
	e.adjustment_saturation = 1.48
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


## Niedliches Häuschen: Pastellwände, Spitzdach, Tür, zwei Fenster und Schornstein (optional mit Kollision).
static func cottage(parent: Node, pos: Vector3, rot_y := 0.0, scl := 1.0, wall := Color("#fff1d8"), roof := Color("#ff8a8a"), collide := false) -> Node3D:
	var root: Node3D = StaticBody3D.new() if collide else Node3D.new()
	parent.add_child(root)
	root.position = pos
	root.rotation_degrees.y = rot_y
	root.scale = Vector3.ONE * scl
	if collide:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(3.0, 3.2, 2.6)
		cs.shape = bs
		cs.position.y = 1.6
		root.add_child(cs)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.0, 2.0, 2.6)
	bm.material = mat(wall, 0.9)
	body.mesh = bm
	body.position.y = 1.0
	root.add_child(body)
	var rf := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(3.5, 1.5, 3.0)
	pm.material = mat(roof, 0.7)
	rf.mesh = pm
	rf.position.y = 2.75
	root.add_child(rf)
	var door := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.8, 1.3, 0.08)
	dm.material = mat(Color("#a8704a"), 0.8)
	door.mesh = dm
	door.position = Vector3(0, 0.65, 1.31)
	root.add_child(door)
	for wx in [-0.95, 0.95]:
		var w := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.6, 0.6, 0.08)
		wm.material = mat(Color("#bfe6ff"), 0.2, 0.25)
		w.mesh = wm
		w.position = Vector3(wx, 1.25, 1.31)
		root.add_child(w)
	var ch := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.4, 0.9, 0.4)
	cm.material = mat(Color("#c98d5a"), 0.9)
	ch.mesh = cm
	ch.position = Vector3(0.8, 3.1, -0.4)
	root.add_child(ch)
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
	# Wellen brauchen ein paar Stützpunkte, aber keine 18.000 Dreiecke pro Fläche
	var cap := 32 if maxf(size.x, size.y) > 400.0 else 48
	pm.subdivide_width = int(clampf(size.x / 3.0, 6, cap))
	pm.subdivide_depth = int(clampf(size.y / 3.0, 6, cap))
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


# --- Weite & Leben: kein "Ende der Welt" ---------------------------------------------------------------------

## Erweitert jede Szene über ihre Bodenplatte hinaus: weiter Boden (bzw. Meer/Wolkenmeer), dunstige
## Hügelketten am Horizont, ziehende Wolken, kreisende Vögel und themenpassende Partikel. Dazu wird der
## Tiefendunst so gesetzt, dass Kanten und Horizont weich ineinander übergehen.
## style: meadow | beach | snow | night | sky | sky_dusk | cake | dungeon | none
static func backdrop(parent: Node3D, style: String, ground: Color, ground_y := -0.55, center := Vector3.ZERO) -> Node3D:
	var root := Node3D.new()
	root.name = "Backdrop"
	parent.add_child(root)
	root.position = Vector3(center.x, 0, center.z)
	if style == "none":
		return root
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(style) ^ int(ground.to_rgba32())
	var we := _find_env(parent)
	var horizon := Color("#a9cfee")
	if we and we.environment:
		var e := we.environment
		if e.sky and e.sky.sky_material is ProceduralSkyMaterial:
			horizon = (e.sky.sky_material as ProceduralSkyMaterial).sky_horizon_color
			# Unterhalb des Horizonts zeigt der Himmel nun die Bodenfarbe → kein sichtbarer Bruch
			(e.sky.sky_material as ProceduralSkyMaterial).ground_bottom_color = ground.lerp(horizon, 0.35)
			(e.sky.sky_material as ProceduralSkyMaterial).ground_horizon_color = horizon
		e.fog_enabled = true
		e.fog_light_color = horizon
		e.fog_density = maxf(e.fog_density, 0.0042 if style != "dungeon" else 0.012)
		e.fog_aerial_perspective = 0.55
		e.fog_sky_affect = 0.25
	if style == "dungeon":
		return root
	var far_col := ground
	match style:
		"beach":
			var sea := water(root, Vector2(1400, 1400), ground_y - 0.35, Color(0.06, 0.4, 0.65), Color(0.3, 0.8, 0.9))
			sea.name = "FarSea"
			far_col = Color("#e8d6a0")
		"sky", "sky_dusk":
			var cl := water(root, Vector2(1400, 1400), ground_y - 14.0, Color(1, 1, 1) if style == "sky" else Color("#f4d6e8"), Color(1, 1, 1))
			var cm := cl.mesh.surface_get_material(0) as ShaderMaterial
			cm.set_shader_parameter("wave_height", 0.9)
			cm.set_shader_parameter("alpha", 1.0)
			far_col = Color("#ffffff") if style == "sky" else Color("#f0d8f0")
		_:
			var g := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(1400, 1400)
			pm.material = mat(ground, 1.0)
			g.mesh = pm
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g.position.y = ground_y
			g.name = "FarGround"
			root.add_child(g)
	# Hügelketten (bzw. Inseln/Wolkenberge/Tortenstücke) am Horizont – leicht ins Horizontblau gemischt
	var hill_col := far_col.darkened(0.08).lerp(horizon, 0.28)
	if style == "cake":
		hill_col = Color("#ffb3c7").lerp(horizon, 0.25)
	elif style == "snow":
		hill_col = Color("#f4f8ff").lerp(horizon, 0.2)
	elif style == "night":
		hill_col = ground.darkened(0.2).lerp(horizon, 0.15)
	for i in 22:
		var a := TAU * i / 22.0 + rng.randf_range(-0.08, 0.08)
		var r := rng.randf_range(150.0, 240.0)
		var h := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(28.0, 60.0)
		sm.height = sm.radius * rng.randf_range(0.55, 0.9)
		sm.radial_segments = 20
		sm.rings = 10
		sm.material = mat(hill_col.lerp(horizon, rng.randf_range(0.0, 0.18)), 1.0)
		h.mesh = sm
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var hy := ground_y - sm.height * 0.18
		if style in ["sky", "sky_dusk"]:
			hy = ground_y - 12.0 + rng.randf_range(-4.0, 6.0)
		h.position = Vector3(cos(a) * r, hy, sin(a) * r)
		root.add_child(h)
	# Ziehende Wolken (langsame Rotation um die Szene)
	var cloud_pivot := Node3D.new()
	cloud_pivot.name = "Clouds"
	root.add_child(cloud_pivot)
	var cloud_col := Color(1, 1, 1) if style != "night" else Color("#5a6496")
	if style in ["sky_dusk", "cake"]:
		cloud_col = Color("#ffe6f0")
	for c in 16:
		var cluster := Node3D.new()
		cloud_pivot.add_child(cluster)
		var a2 := TAU * c / 16.0 + rng.randf() * 0.3
		var r2 := rng.randf_range(90.0, 230.0)
		cluster.position = Vector3(cos(a2) * r2, rng.randf_range(38.0, 75.0), sin(a2) * r2)
		for k in rng.randi_range(3, 6):
			var puff := MeshInstance3D.new()
			var ps := SphereMesh.new()
			ps.radius = rng.randf_range(6.0, 12.0)
			ps.height = ps.radius * 1.3
			ps.radial_segments = 16
			ps.rings = 8
			ps.material = mat(cloud_col, 1.0, 0.12 if style != "night" else 0.0)
			puff.mesh = ps
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			puff.position = Vector3(k * 7.0 - 14.0 + rng.randf_range(-2, 2), rng.randf_range(-2.0, 3.0), rng.randf_range(-4, 4))
			cluster.add_child(puff)
	var ct := cloud_pivot.create_tween().set_loops()
	ct.tween_property(cloud_pivot, "rotation:y", TAU, 900.0).as_relative()
	# Kreisende Vögel (Möwen am Strand, Schwalben auf der Wiese) – nachts dafür Sternschnuppen
	if style != "night":
		for b in 6:
			var piv := Node3D.new()
			root.add_child(piv)
			piv.rotation.y = rng.randf() * TAU
			var bird := Node3D.new()
			piv.add_child(bird)
			bird.position = Vector3(rng.randf_range(35.0, 75.0), rng.randf_range(16.0, 30.0), 0)
			bird.rotation.y = PI * 0.5
			var bcol := Color("#fdfdfd") if style == "beach" else Color("#4a4a5a")
			var body := MeshInstance3D.new()
			var bs := SphereMesh.new()
			bs.radius = 0.35
			bs.height = 0.5
			bs.material = mat(bcol, 0.8)
			body.mesh = bs
			bird.add_child(body)
			for sd in [-1.0, 1.0]:
				var wing := MeshInstance3D.new()
				var wb := BoxMesh.new()
				wb.size = Vector3(1.4, 0.06, 0.45)
				wb.material = mat(bcol, 0.8)
				wing.mesh = wb
				wing.position = Vector3(0.7 * sd, 0, 0)
				var wp := Node3D.new()
				bird.add_child(wp)
				wp.add_child(wing)
				var wt := wp.create_tween().set_loops()
				wt.tween_property(wp, "rotation:z", 0.55 * sd, 0.22 + b * 0.02).set_trans(Tween.TRANS_SINE)
				wt.tween_property(wp, "rotation:z", -0.35 * sd, 0.22 + b * 0.02).set_trans(Tween.TRANS_SINE)
			var ft := piv.create_tween().set_loops()
			ft.tween_property(piv, "rotation:y", TAU * (1.0 if b % 2 == 0 else -1.0), rng.randf_range(24.0, 40.0)).as_relative()
	# Themen-Partikel in Bodennähe (bewegen sich langsam durchs Bild)
	var pcfg := {}
	match style:
		"meadow":
			pcfg = {"amount": 40, "life": 7.0, "color": Color(1.0, 0.9, 0.55, 0.9), "size": 0.16, "vel": 0.5, "grav": Vector3(0.15, 0.05, 0.0)}
		"beach":
			pcfg = {"amount": 30, "life": 6.0, "color": Color(1, 1, 1, 0.7), "size": 0.12, "vel": 0.6, "grav": Vector3(0.3, 0.02, 0.0)}
		"snow":
			pcfg = {"amount": 160, "life": 8.0, "color": Color(1, 1, 1, 0.95), "size": 0.16, "vel": 0.3, "grav": Vector3(0.2, -0.9, 0.0)}
		"night":
			pcfg = {"amount": 70, "life": 5.0, "color": Color(1.0, 0.95, 0.55, 0.95), "size": 0.2, "vel": 0.35, "grav": Vector3(0, 0.05, 0), "add": true}
		"cake":
			pcfg = {"amount": 50, "life": 7.0, "color": Color("#ffd1e3"), "size": 0.18, "vel": 0.3, "grav": Vector3(0.05, -0.4, 0.0)}
		"sky", "sky_dusk":
			pcfg = {"amount": 40, "life": 8.0, "color": Color(1, 1, 1, 0.8), "size": 0.2, "vel": 0.4, "grav": Vector3(0.25, 0.0, 0.0), "add": true}
	if not pcfg.is_empty():
		var em := FX.emitter({"amount": pcfg.amount, "life": pcfg.life, "one_shot": false, "explosive": 0.0, "spread": 180.0,
			"vel_min": 0.05, "vel_max": pcfg.vel, "gravity": pcfg.grav, "size": pcfg.size, "additive": pcfg.get("add", false),
			"color": pcfg.color, "box": Vector3(60, 6 if style != "snow" else 1, 46)})
		root.add_child(em)
		em.position = Vector3(0, 3.5 if style != "snow" else 16.0, 0)
		em.preprocess = 6.0
		em.emitting = true
	return root


static func _find_env(n: Node) -> WorldEnvironment:
	for c in n.get_children():
		if c is WorldEnvironment:
			return c as WorldEnvironment
	if n.get_parent() and n.get_parent() != n.get_tree().root:
		return _find_env(n.get_parent())
	return null


# --- Fluss ---------------------------------------------------------------------------------------------------

## Mäandernder Fluss entlang "path" (Punkte von Horizont zu Horizont): Wasser-Segmente, dunkles Flussbett,
## durchgehende Ufer (Kollision optional) und Ufersteine. Gibt die geglättete Mittellinie zurück.
static func river(parent: Node3D, path: Array, width := 3.6, water_y := -0.45, bank_col := Color("#7ec86a"),
		bank_w := 70.0, collide := true) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for k in path.size() - 1:
		var a: Vector3 = path[k]
		var b: Vector3 = path[k + 1]
		var mid := (a + b) * 0.5
		var seg := b - a
		var length := seg.length()
		var yaw := atan2(seg.x, seg.z)
		var perp := Vector3(seg.z, 0, -seg.x).normalized()
		# Wasser (etwas länger für überlappende Fugen)
		var w := water(parent, Vector2(width + 0.8, length + 1.2), water_y, Color(0.08, 0.42, 0.58), Color(0.42, 0.84, 0.9))
		w.position = Vector3(mid.x, water_y, mid.z)
		w.rotation.y = yaw
		# Flussbett
		var bed := box(parent, Vector3(width + 1.0, 1.0, length + 1.2), Vector3(mid.x, water_y - 1.0, mid.z), Color("#4f8a6a"), false)
		bed.rotation.y = yaw
		# Ufer links/rechts (Oberkante = 0)
		for sd in [-1.0, 1.0]:
			var bc := mid + perp * float(sd) * (width * 0.5 + bank_w * 0.5)
			var bank := box(parent, Vector3(bank_w, 1.0, length + 1.6), Vector3(bc.x, -0.5, bc.z), bank_col, collide)
			bank.rotation.y = yaw
			# Uferkante: kleine Steine und Schilf
			for j in 3:
				var t := (j + rng.randf()) / 3.0
				var p := a.lerp(b, t) + perp * float(sd) * (width * 0.5 + rng.randf_range(0.1, 0.6))
				if rng.randf() < 0.55:
					place(parent, "nat/rock_small", Vector3(p.x, -0.12, p.z), rng.randf() * 360.0, rng.randf_range(1.0, 1.7))
				else:
					place(parent, "nat/grass", Vector3(p.x, 0.0, p.z), rng.randf() * 360.0, rng.randf_range(1.4, 2.2))
	return path


## Hilfsfunktion: Mittellinie eines Flusses, der in z-Richtung von -length bis +length mäandert. In der
## Arena (|z| < straight) bleibt er gerade.
static func meander_path(length := 170.0, step := 8.0, straight := 18.0, amp := 9.0) -> Array:
	var pts: Array = []
	var z := -length
	while z <= length + 0.01:
		var off := 0.0
		var az := absf(z)
		if az > straight:
			var k := clampf((az - straight) / 30.0, 0.0, 1.0)
			off = sin((az - straight) / 22.0) * amp * k * (1.0 if z > 0 else -1.0)
		pts.append(Vector3(off, 0, z))
		z += step
	return pts
