extends Node
## Partikel- & Effekt-Bibliothek (CPUParticles3D – läuft überall, auch WebGL2/Compatibility).
##
## Umgebungsbezogen: FX.step(pos, "sand") wirft Sandwirbel, "stone" Dungeon-Geröll,
## "water" Spritzer, "metal"/"lava" Funken usw.

const SURFACES := {
	"stone": {"preset": "dust", "color": Color(0.62, 0.58, 0.55), "sfx": "step_stone"},
	"dungeon": {"preset": "rubble", "color": Color(0.5, 0.46, 0.44), "sfx": "step_stone"},
	"sand": {"preset": "sand", "color": Color(0.95, 0.83, 0.58), "sfx": "step_sand"},
	"wood": {"preset": "dust", "color": Color(0.72, 0.56, 0.38), "sfx": "step_wood"},
	"grass": {"preset": "leaves", "color": Color(0.45, 0.8, 0.35), "sfx": "step_grass"},
	"water": {"preset": "splash_small", "color": Color(0.6, 0.85, 1.0), "sfx": "slime"},
	"metal": {"preset": "sparks", "color": Color(1.0, 0.8, 0.3), "sfx": "step_metal"},
	"lava": {"preset": "embers", "color": Color(1.0, 0.5, 0.1), "sfx": "step_stone"},
	"slime": {"preset": "slime", "color": Color(0.45, 1.0, 0.3), "sfx": "slime"},
	"cloud": {"preset": "dust", "color": Color(1, 1, 1), "sfx": "step_grass"},
	"snow": {"preset": "dust", "color": Color(0.95, 0.97, 1.0), "sfx": "step_sand"},
}

var tex_soft: Texture2D
var tex_star: Texture2D
var tex_ring: Texture2D
var tex_spark: Texture2D
var _mats := {}
var _quad: QuadMesh
var _spark_quad: QuadMesh
var _confetti_quad: QuadMesh


func _ready() -> void:
	tex_soft = _make_soft_circle()
	tex_star = _make_star()
	tex_ring = _make_ring()
	tex_spark = _make_spark()
	_quad = QuadMesh.new()
	_quad.size = Vector2(0.5, 0.5)
	_spark_quad = QuadMesh.new()
	_spark_quad.size = Vector2(0.06, 0.45)
	_confetti_quad = QuadMesh.new()
	_confetti_quad.size = Vector2(0.14, 0.09)


# --- Texturen prozedural erzeugen (keine externen Dateien nötig) ------------------------

func _make_soft_circle() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.55, Color(1, 1, 1, 0.75))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


func _make_ring() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.62, 0.78, 0.92, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


func _make_star() -> Texture2D:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var pts := PackedVector2Array()
	for k in 10:
		var r := 30.0 if k % 2 == 0 else 13.0
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(Vector2(32, 33) + Vector2(cos(a), sin(a)) * r)
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5)
			var inside := Geometry2D.is_point_in_polygon(p, pts)
			if inside:
				var d := p.distance_to(Vector2(32, 33)) / 30.0
				img.set_pixel(x, y, Color(1, 1, 1.0 - d * 0.3, 1))
	return ImageTexture.create_from_image(img)


func _make_spark() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_LINEAR
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	t.width = 8
	t.height = 32
	return t


func _mat(tex: Texture2D, billboard := true, additive := false) -> StandardMaterial3D:
	var key := "%s_%s_%s" % [tex.get_instance_id(), billboard, additive]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_receive_shadows = true
	_mats[key] = m
	return m


# --- Kern: One-Shot-Partikel ---------------------------------------------------------------

func _world() -> Node:
	var s := get_tree().current_scene
	return s if s else get_tree().root


func _ramp(c0: Color, c1: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, c1)
	return g


func _scale_curve(points: Array) -> Curve:
	var c := Curve.new()
	for p in points:
		c.add_point(p)
	return c


func emitter(cfg: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = cfg.get("amount", 16)
	p.lifetime = cfg.get("life", 0.8)
	p.one_shot = cfg.get("one_shot", true)
	p.explosiveness = cfg.get("explosive", 0.95)
	p.randomness = 0.5
	p.local_coords = cfg.get("local", false)
	var mesh: Mesh = cfg.get("mesh", _quad)
	if mesh is QuadMesh:
		var qm := (mesh as QuadMesh).duplicate() as QuadMesh
		qm.size = (mesh as QuadMesh).size * float(cfg.get("size", 1.0))
		qm.material = _mat(cfg.get("tex", tex_soft), cfg.get("billboard", true), cfg.get("additive", false))
		mesh = qm
	p.mesh = mesh
	p.direction = cfg.get("dir", Vector3.UP)
	p.spread = cfg.get("spread", 45.0)
	p.initial_velocity_min = cfg.get("vel_min", 2.0)
	p.initial_velocity_max = cfg.get("vel_max", 4.0)
	p.gravity = cfg.get("gravity", Vector3(0, -9.8, 0))
	p.damping_min = cfg.get("damping", 0.0)
	p.damping_max = cfg.get("damping", 0.0) * 1.3
	p.angular_velocity_min = cfg.get("spin", 0.0) * -1.0
	p.angular_velocity_max = cfg.get("spin", 0.0)
	p.angle_max = 360.0 if cfg.get("rand_angle", true) else 0.0
	p.scale_amount_min = cfg.get("scale_min", 0.6)
	p.scale_amount_max = cfg.get("scale_max", 1.2)
	p.scale_amount_curve = cfg.get("scale_curve", _scale_curve([Vector2(0, 0.3), Vector2(0.2, 1.0), Vector2(1, 0.0)]))
	p.emission_shape = cfg.get("shape", CPUParticles3D.EMISSION_SHAPE_SPHERE)
	p.emission_sphere_radius = cfg.get("radius", 0.2)
	if cfg.has("box"):
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = cfg.box
	if cfg.has("ramp"):
		p.color_ramp = cfg.ramp
	else:
		p.color = cfg.get("color", Color.WHITE)
	if cfg.has("color_initial"):
		p.color_initial_ramp = cfg.color_initial
	if cfg.get("align_y", false):
		p.particle_flag_align_y = true
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func burst(pos: Vector3, cfg: Dictionary, parent: Node = null) -> CPUParticles3D:
	var p := emitter(cfg)
	(parent if parent else _world()).add_child(p)
	p.global_position = pos
	p.emitting = true
	if p.one_shot:
		p.finished.connect(p.queue_free)
	return p


# --- Presets -----------------------------------------------------------------------------------

## Vorwärmen: jede Effektart einmal sichtbar vor der Kamera auslösen, solange der Ladebildschirm darüberliegt.
## So kompiliert der Browser (WebGL) die Partikel-Shader schon beim Laden – nicht erst mitten im Spiel
## (z. B. beim ersten Konfetti nach dem Minispiel-Roulette), wo das Kompilieren ein spürbares Ruckeln wäre.
func prewarm(cam: Camera3D) -> void:
	if cam == null:
		return
	var p := cam.global_position + (-cam.global_basis.z) * 6.0
	confetti(p, 4)
	stars(p, Color(1, 0.9, 0.3), 3)
	sparks(p, Color(1, 0.8, 0.3), 3)
	dust(p, Color(0.8, 0.75, 0.7), 3)
	smoke(p, Color(0.4, 0.4, 0.4), 2)
	ring(p, Color(1, 1, 1, 0.5), 0.5, 0.2)


func dust(pos: Vector3, color := Color(0.8, 0.75, 0.7), amount := 12, size := 1.0) -> void:
	burst(pos + Vector3.UP * 0.1, {"amount": amount, "life": 0.7, "dir": Vector3.UP, "spread": 85.0,
		"vel_min": 1.0, "vel_max": 2.6, "gravity": Vector3(0, 0.6, 0), "damping": 3.0, "size": 0.9 * size,
		"ramp": _ramp(Color(color, 0.85), Color(color, 0.0)), "radius": 0.3})


func step(pos: Vector3, surface := "stone", strength := 1.0, with_sound := true) -> void:
	var s: Dictionary = SURFACES.get(surface, SURFACES.stone)
	match s.preset:
		"sand":
			burst(pos + Vector3.UP * 0.05, {"amount": int(10 * strength), "life": 0.9, "dir": Vector3.UP, "spread": 70.0,
				"vel_min": 1.2, "vel_max": 3.0, "gravity": Vector3(0, -2.0, 0), "damping": 1.5, "size": 0.45, "spin": 260.0,
				"ramp": _ramp(Color(s.color, 0.9), Color(s.color, 0.0)), "radius": 0.25})
		"rubble":
			dust(pos, s.color, int(8 * strength), 0.8)
			burst(pos + Vector3.UP * 0.1, {"amount": int(5 * strength), "life": 0.6, "spread": 60.0, "vel_min": 2.0, "vel_max": 3.5,
				"gravity": Vector3(0, -14, 0), "size": 0.18, "color": s.color.darkened(0.3), "tex": tex_soft})
		"leaves":
			burst(pos + Vector3.UP * 0.1, {"amount": int(6 * strength), "life": 0.8, "spread": 60.0, "vel_min": 1.5, "vel_max": 3.0,
				"gravity": Vector3(0, -4, 0), "size": 0.28, "spin": 400.0, "color": s.color, "mesh": _confetti_quad, "billboard": false})
		"splash_small":
			splash(pos, 0.5)
		"sparks":
			sparks(pos, s.color, int(8 * strength))
		"embers":
			embers(pos, int(8 * strength))
		"slime":
			slime(pos, 0.6)
		_:
			dust(pos, s.color, int(8 * strength), 0.8)
	if with_sound:
		Audio.sfx(s.sfx, pos, -8.0)


func land(pos: Vector3, surface := "stone", strength := 1.0) -> void:
	step(pos, surface, 1.6 * strength, false)
	ring(pos + Vector3.UP * 0.05, Color(1, 1, 1, 0.5), 1.2 * strength, 0.35)


func splash(pos: Vector3, strength := 1.0) -> void:
	burst(pos, {"amount": int(26 * strength), "life": 0.9, "dir": Vector3.UP, "spread": 30.0, "vel_min": 4.0 * strength,
		"vel_max": 8.0 * strength, "gravity": Vector3(0, -18, 0), "size": 0.45, "radius": 0.4 * strength,
		"ramp": _ramp(Color(0.85, 0.95, 1.0, 0.95), Color(0.5, 0.75, 1.0, 0.0))})
	ring(pos + Vector3.UP * 0.05, Color(0.85, 0.95, 1.0, 0.8), 2.2 * strength, 0.6)


func sparks(pos: Vector3, color := Color(1.0, 0.75, 0.25), amount := 18, speed := 1.0) -> void:
	burst(pos, {"amount": amount, "life": 0.45, "spread": 180.0, "vel_min": 5.0 * speed, "vel_max": 11.0 * speed,
		"gravity": Vector3(0, -14, 0), "mesh": _spark_quad, "tex": tex_spark, "billboard": false, "align_y": true,
		"additive": true, "rand_angle": false, "ramp": _ramp(Color(1, 1, 0.8, 1), Color(color, 0.0)),
		"scale_curve": _scale_curve([Vector2(0, 1), Vector2(1, 0.2)])})


func embers(pos: Vector3, amount := 10) -> void:
	burst(pos, {"amount": amount, "life": 1.1, "spread": 35.0, "vel_min": 2.0, "vel_max": 4.5, "gravity": Vector3(0, 1.5, 0),
		"size": 0.3, "additive": true, "ramp": _ramp(Color(1.0, 0.85, 0.3, 1), Color(1.0, 0.2, 0.0, 0))})


func slime(pos: Vector3, strength := 1.0) -> void:
	burst(pos, {"amount": int(14 * strength), "life": 0.7, "spread": 55.0, "vel_min": 2.5, "vel_max": 5.0,
		"gravity": Vector3(0, -16, 0), "size": 0.45, "ramp": _ramp(Color(0.55, 1.0, 0.35, 1), Color(0.2, 0.7, 0.1, 0))})


func smoke(pos: Vector3, color := Color(0.35, 0.33, 0.35), amount := 10, size := 1.0) -> void:
	burst(pos, {"amount": amount, "life": 1.6, "spread": 30.0, "vel_min": 0.8, "vel_max": 2.0, "gravity": Vector3(0, 1.2, 0),
		"damping": 0.8, "size": 2.0 * size, "radius": 0.5 * size, "spin": 40.0, "explosive": 0.8,
		"ramp": _ramp(Color(color, 0.7), Color(color.lightened(0.2), 0.0)),
		"scale_curve": _scale_curve([Vector2(0, 0.4), Vector2(1, 1.3)])})


func stars(pos: Vector3, color := Color(1, 0.9, 0.2), amount := 12) -> void:
	burst(pos, {"amount": amount, "life": 0.9, "spread": 180.0, "vel_min": 3.0, "vel_max": 6.0, "gravity": Vector3(0, -6, 0),
		"damping": 2.0, "size": 0.7, "tex": tex_star, "spin": 300.0, "color": color,
		"scale_curve": _scale_curve([Vector2(0, 1), Vector2(0.7, 0.9), Vector2(1, 0)])})


func confetti(pos: Vector3, amount := 80, up := Vector3.UP, spread := 35.0) -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	g.colors = PackedColorArray([Color("#ff4d6d"), Color("#ffcc00"), Color("#4cd964"), Color("#3fa7ff"), Color("#c06bff"), Color("#ffffff")])
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	burst(pos, {"amount": amount, "life": 3.2, "dir": up, "spread": spread, "vel_min": 7.0, "vel_max": 12.0,
		"gravity": Vector3(0, -5.5, 0), "damping": 2.2, "mesh": _confetti_quad, "billboard": false, "spin": 720.0,
		"color_initial": g, "scale_curve": _scale_curve([Vector2(0, 1), Vector2(0.85, 1), Vector2(1, 0)]),
		"scale_min": 0.8, "scale_max": 1.5, "explosive": 0.9})
	Audio.sfx("pop", pos)


func bubbles(pos: Vector3, amount := 8, parent: Node = null) -> CPUParticles3D:
	return burst(pos, {"amount": amount, "life": 2.0, "spread": 20.0, "vel_min": 0.8, "vel_max": 1.8, "gravity": Vector3(0, 1.0, 0),
		"size": 0.35, "tex": tex_ring, "color": Color(0.8, 0.95, 1.0, 0.8), "radius": 0.6,
		"scale_curve": _scale_curve([Vector2(0, 0.4), Vector2(1, 1.0)])}, parent)


func explosion(pos: Vector3, scale := 1.0, with_sound := true) -> void:
	flash_light(pos + Vector3.UP, Color(1.0, 0.7, 0.3), 8.0 * scale, 0.35, 10.0 * scale)
	burst(pos, {"amount": int(22 * scale), "life": 0.7, "spread": 180.0, "vel_min": 3.0 * scale, "vel_max": 7.0 * scale,
		"gravity": Vector3(0, 2, 0), "damping": 4.0, "size": 1.6 * scale, "radius": 0.5 * scale, "additive": true,
		"ramp": _ramp(Color(1.0, 0.9, 0.5, 1), Color(0.9, 0.2, 0.0, 0)), "scale_curve": _scale_curve([Vector2(0, 0.5), Vector2(0.3, 1.2), Vector2(1, 0.2)])})
	smoke(pos + Vector3.UP * 0.5, Color(0.25, 0.22, 0.22), int(10 * scale), 1.2 * scale)
	sparks(pos, Color(1, 0.6, 0.2), int(20 * scale), 1.2 * scale)
	ring(pos + Vector3.UP * 0.1, Color(1, 0.8, 0.5, 0.8), 5.0 * scale, 0.45)
	Juice.shake(0.55 * scale)
	if with_sound:
		Audio.sfx("explosion", pos)


func coins_burst(pos: Vector3, count: int, gain := true, parent: Node = null) -> void:
	var w := parent if parent else _world()
	var ps := Assets.scene("bg/coin_gold")
	for i in mini(count, 20):
		var c: Node3D = ps.instantiate() if ps else MeshInstance3D.new()
		w.add_child(c)
		c.scale = Vector3.ONE * 1.6
		var start := pos + (Vector3.UP * 2.6 if gain else Vector3.UP * 1.2)
		var dir := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(0.8, 2.2)
		var end := pos + (Vector3.UP * 1.2 if gain else dir + Vector3.DOWN * 0.2)
		if gain:
			start = pos + dir + Vector3.UP * 4.0
		c.global_position = start
		var tw := c.create_tween()
		tw.tween_interval(i * 0.06)
		tw.tween_method(func(t: float) -> void:
			if is_instance_valid(c):
				c.global_position = start.lerp(end, t) + Vector3.UP * sin(t * PI) * 2.0
				c.rotation.y = t * 12.0, 0.0, 1.0, 0.55)
		tw.tween_callback(func() -> void:
			if gain:
				Audio.sfx("coin_single", c.global_position, -6.0, 1.0 + i * 0.03))
		tw.tween_property(c, "scale", Vector3.ZERO, 0.15)
		tw.tween_callback(c.queue_free)
	Audio.sfx("coin" if gain else "coin_lose", pos)


func ring(pos: Vector3, color := Color(1, 1, 1, 0.8), radius := 3.0, duration := 0.5, parent: Node = null) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 2.0
	q.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex_ring
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else _world()).add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * 0.1
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


func flash_light(pos: Vector3, color: Color, energy := 6.0, duration := 0.3, rng := 10.0) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	_world().add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, duration)
	tw.tween_callback(l.queue_free)


## Dauerhafter Emitter (z. B. Drift-Funken, Boost-Flammen). Aufrufer steuert emitting/color.
func make_trail(parent: Node3D, kind := "sparks") -> CPUParticles3D:
	var cfg := {}
	match kind:
		"sparks":
			cfg = {"amount": 26, "life": 0.35, "one_shot": false, "explosive": 0.0, "spread": 50.0, "dir": Vector3(0, 1, 0.6),
				"vel_min": 3.0, "vel_max": 6.0, "gravity": Vector3(0, -12, 0), "mesh": _spark_quad, "tex": tex_spark,
				"billboard": false, "align_y": true, "additive": true, "rand_angle": false, "radius": 0.1,
				"scale_curve": _scale_curve([Vector2(0, 1), Vector2(1, 0.2)])}
		"flame":
			cfg = {"amount": 30, "life": 0.3, "one_shot": false, "explosive": 0.0, "spread": 12.0, "dir": Vector3(0, 0.2, 1),
				"vel_min": 4.0, "vel_max": 7.0, "gravity": Vector3.ZERO, "size": 0.7, "additive": true, "radius": 0.12,
				"ramp": _ramp(Color(0.6, 0.9, 1.0, 1), Color(1.0, 0.3, 0.8, 0))}
		"dust":
			cfg = {"amount": 18, "life": 0.6, "one_shot": false, "explosive": 0.0, "spread": 30.0, "dir": Vector3(0, 0.5, 1),
				"vel_min": 1.0, "vel_max": 2.0, "gravity": Vector3(0, 1, 0), "size": 0.9, "radius": 0.3,
				"ramp": _ramp(Color(0.85, 0.8, 0.75, 0.6), Color(0.85, 0.8, 0.75, 0))}
		"bubbles":
			cfg = {"amount": 12, "life": 1.6, "one_shot": false, "explosive": 0.0, "spread": 25.0, "vel_min": 0.6, "vel_max": 1.4,
				"gravity": Vector3(0, 1.5, 0), "size": 0.3, "tex": tex_ring, "color": Color(0.85, 0.95, 1, 0.8), "radius": 0.5}
		"embers":
			cfg = {"amount": 14, "life": 1.0, "one_shot": false, "explosive": 0.0, "spread": 30.0, "vel_min": 1.0, "vel_max": 2.5,
				"gravity": Vector3(0, 1.2, 0), "size": 0.25, "additive": true, "radius": 1.0,
				"ramp": _ramp(Color(1.0, 0.85, 0.3, 1), Color(1.0, 0.2, 0.0, 0))}
	var p := emitter(cfg)
	parent.add_child(p)
	p.emitting = false
	return p


## Drehende Cartoon-Sterne über dem Kopf (Benommenheit).
func dizzy_stars(target: Node3D, height := 2.5, duration := 2.0, count := 4) -> Node3D:
	var holder := Node3D.new()
	target.add_child(holder)
	holder.position = Vector3.UP * height
	for i in count:
		var s := Sprite3D.new()
		s.texture = tex_star
		s.pixel_size = 0.009
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.modulate = Color(1, 0.92, 0.25)
		s.shaded = false
		holder.add_child(s)
		var a := TAU * i / count
		s.position = Vector3(cos(a), 0, sin(a)) * 0.6
	var tw := holder.create_tween().set_loops(int(duration / 0.6) + 1)
	tw.tween_property(holder, "rotation:y", TAU, 0.6).as_relative()
	var tw2 := holder.create_tween()
	tw2.tween_interval(duration)
	tw2.tween_property(holder, "scale", Vector3.ZERO, 0.2)
	tw2.tween_callback(holder.queue_free)
	return holder


## Schwebende "Z"s (schlafende Gegner im Runden-Intro).
func zzz(target: Node3D, height := 2.4, duration := 3.0) -> void:
	for i in 3:
		var l := Label3D.new()
		l.text = "Z"
		l.font = load(Assets.FONT_TITLE)
		l.font_size = 64 + i * 16
		l.outline_size = 12
		l.modulate = Color(0.75, 0.85, 1.0)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.pixel_size = 0.006
		target.add_child(l)
		l.position = Vector3(0.3, height, 0)
		l.modulate.a = 0.0
		var tw := l.create_tween().set_loops(int(duration / 1.5))
		tw.tween_interval(i * 0.5)
		tw.tween_property(l, "modulate:a", 1.0, 0.2)
		tw.parallel().tween_property(l, "position", Vector3(0.3 + 0.6 * (i + 1) * 0.5, height + 1.2, 0), 1.2)
		tw.tween_property(l, "modulate:a", 0.0, 0.2)
		tw.tween_callback(func() -> void: l.position = Vector3(0.3, height, 0))
		get_tree().create_timer(duration + 0.2, false).timeout.connect(func() -> void:
			if is_instance_valid(l):
				l.queue_free())


## Schweißtropfen / Schreck-Symbol über dem Kopf.
func emote(target: Node3D, symbol := "!", color := Color(1, 0.85, 0.2), height := 2.7, duration := 1.0) -> void:
	var l := Label3D.new()
	l.text = symbol
	l.font = load(Assets.FONT_TITLE)
	l.font_size = 140
	l.outline_size = 26
	l.modulate = color
	l.outline_modulate = Color(0.1, 0.05, 0.15)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = 0.006
	l.no_depth_test = true
	target.add_child(l)
	l.position = Vector3(0.4, height, 0)
	l.scale = Vector3.ZERO
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", height + 0.25, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", height, 0.15).set_ease(Tween.EASE_IN)
	tw.tween_interval(maxf(duration - 0.55, 0.05))
	tw.tween_property(l, "scale", Vector3.ZERO, 0.15)
	tw.tween_callback(l.queue_free)


func shockwave(pos: Vector3, radius := 12.0, color := Color(0.6, 0.9, 1.0, 0.9)) -> void:
	ring(pos + Vector3.UP * 0.3, color, radius, 0.55)
	ring(pos + Vector3.UP * 0.6, Color(1, 1, 1, 0.6), radius * 0.7, 0.4)
	burst(pos, {"amount": 30, "life": 0.5, "spread": 90.0, "dir": Vector3.UP, "vel_min": 10.0, "vel_max": 16.0,
		"gravity": Vector3.ZERO, "damping": 8.0, "size": 0.6, "additive": true, "color": color})
