class_name TrackScenery
extends Node3D
## Themen-Welt und Wetter der v2-Strecken (Gewitter-Pass, Frostgipfel, Orbit-Bahn, Stadt-Rallye,
## Wüsten-Canyon): Boden, Kulisse am Streckenrand und Wettereffekte.
##
## Gewitter: Regen folgt der Kamera, lange mehrstufige Blitze (hell, mit Nachglühen, sichtbarem Blitzstrahl
## und verzögertem Donner) sowie dezent leuchtende Reflektorpfosten an beiden Fahrbahnrändern.

const THEMES := ["storm", "snow", "space", "city", "desert", "forest", "candy", "jungle", "falls"]

## Kulisse: far = weit vom Rand (große Objekte), near = direkt an der Leitplanke.
## Werte: [Katalog-Schlüssel, Skalierung min, max]
const DECO := {
	"storm": {"far": [["nat/rock_tall", 6.0, 10.0], ["nat/cliff_stone", 8.0, 14.0], ["nat/pine", 6.0, 9.0], ["grave/pine", 4.0, 6.0], ["nat/rock_large", 5.0, 8.0], ["nat/stump", 3.0, 4.0]],
		"near": [["race/barrier_white", 3.0, 3.0], ["race/pylon", 3.0, 3.0]], "ground": Color("#1d2420")},
	"snow": {"far": [["nat/pine_snow", 6.0, 9.0], ["hk/tree_snow", 4.0, 6.0], ["hk/tree_snow_b", 4.0, 6.0], ["hol/snowman", 2.6, 3.4], ["hk/snow_pile", 4.0, 6.0], ["hk/rocks", 4.0, 6.0]],
		"near": [["hk/candy_cane", 3.0, 3.5], ["race/barrier_white", 3.0, 3.0], ["hk/lantern", 2.4, 2.6]], "ground": Color("#e9f0f8")},
	"city": {"far": [["city/building_a", 14.0, 17.0], ["city/building_e", 10.0, 13.0], ["city/building_h", 12.0, 15.0], ["city/sky_a", 10.0, 13.0], ["city/sky_b", 10.0, 13.0],
		["city/sky_c", 9.0, 12.0], ["sub/house_a", 10.0, 12.0], ["sub/house_f", 10.0, 12.0], ["sub/house_k", 10.0, 12.0], ["sub/tree", 9.0, 12.0]],
		"near": [["toy/cone", 6.0, 7.0], ["race/barrier_red", 3.0, 3.0], ["city/parasol", 6.0, 7.0], ["sub/planter", 6.0, 7.0], ["race/light_post", 3.0, 3.0]], "ground": Color("#5d626c")},
	"desert": {"far": [["nat/cactus", 6.0, 9.0], ["nat/cactus_short", 6.0, 8.0], ["mg/tree_desert", 2.6, 3.4], ["nat/rock_tall", 6.0, 11.0], ["nat/cliff_stone", 8.0, 14.0], ["pirate/rocks_b", 3.0, 5.0]],
		"near": [["race/barrier_white", 3.0, 3.0], ["race/flag_red", 3.0, 3.0], ["toy/cone", 6.0, 7.0]], "ground": Color("#d9b47a")},
	# 1.4.0
	"forest": {"far": [["nat/tree_oak", 6.0, 8.5], ["nat/tree_pine", 6.0, 8.5], ["nat/tree_fat", 6.0, 8.0], ["plat/mushrooms", 6.0, 9.0], ["nat/mushroom", 6.0, 9.0], ["nat/stump", 5.0, 7.0]],
		"near": [["hal/post_lantern", 1.0, 1.15], ["nat/mushroom", 3.0, 4.0]], "ground": Color("#1c3322")},
	"candy": {"far": [["hol/gingerbread_house_decorated", 5.0, 7.0], ["hk/tree_decorated", 4.0, 5.0], ["hk/candy_cane", 12.0, 16.0], ["hol/present_red", 5.0, 8.0],
		["hol/cookie", 10.0, 14.0]], "near": [["hol/candycane_small", 4.5, 5.5], ["hk/candy_cane", 6.0, 7.0]], "ground": Color("#f7c9dc")},
	"jungle": {"far": [["nat/tree_palm", 6.0, 8.0], ["nat/tree_palm_bend", 6.0, 8.0], ["pirate/palm_detailed", 2.0, 2.6], ["dun/pillar", 1.6, 2.4], ["arena/statue", 4.0, 6.0],
		["nat/bush", 6.0, 9.0]], "near": [["nat/log", 3.0, 3.5], ["nat/rock_small", 5.0, 8.0]], "ground": Color("#3f7a2e")},
	"falls": {"far": [["nat/cliff_large", 14.0, 22.0], ["nat/cliff_stone", 10.0, 16.0], ["nat/rock_tall", 8.0, 14.0], ["nat/pine", 6.0, 8.0], ["nat/tree_pine", 6.0, 8.0],
		["nat/rock_large", 6.0, 10.0]], "near": [["race/barrier_white", 3.0, 3.0], ["nat/rock_small", 5.0, 7.0]], "ground": Color("#557a3a")},
}

var track: RaceTrack
var def: Dictionary
var theme := ""
var _env: Environment
var _sun: DirectionalLight3D
var _sun_base := 1.0
var _amb_base := 0.4
var _rng := RandomNumberGenerator.new()

# Gewitter
var _rain: CPUParticles3D
var _bolt_t := 4.0
var _flash := 0.0
var _bolt_mesh: MeshInstance3D
var _bolt_mat: StandardMaterial3D
var _flash_tw: Tween


func build(t: RaceTrack, d: Dictionary, env: Environment) -> void:
	track = t
	def = d
	theme = d.theme
	_env = env
	_rng.seed = hash(String(d.id))
	for c in get_parent().get_children():
		if c is DirectionalLight3D:
			_sun = c
		for cc in c.get_children():
			if cc is DirectionalLight3D:
				_sun = cc
	if _sun:
		_sun_base = _sun.light_energy
	if _env:
		_amb_base = _env.ambient_light_energy
	match theme:
		"space":
			_build_space()
		_:
			_build_ground()
			_decorate()
	match theme:
		"storm":
			_build_storm()
		"snow":
			_build_snow()
		"city":
			_build_city()
		"desert":
			_build_desert()
		"forest":
			_build_forest()
		"candy":
			_build_candy()
		"jungle", "falls":
			_build_river()


# --- Boden & Kulisse ----------------------------------------------------------------------------------

func _build_ground() -> void:
	var col: Color = DECO[theme].ground
	if theme == "desert":
		# Boden in Kacheln, die Schlucht unter dem Gleitflug bleibt offen
		var tile := 24.0
		for ix in range(-12, 13):
			for iz in range(-12, 13):
				var c := Vector3(ix * tile, 0, iz * tile) + Vector3(bounds(track).get_center().x, 0, bounds(track).get_center().y)
				if _in_gorge(c, tile * 0.5):
					continue
				WorldKit.box(self, Vector3(tile, 1, tile), c + Vector3(0, -0.8, 0), col, false)
		return
	var b := bounds(track)
	WorldKit.box(self, Vector3(b.size.x + 320.0, 1, b.size.y + 320.0), Vector3(b.get_center().x, -0.8, b.get_center().y), col, false)


## Ausdehnung der Strecke in x/z (für Boden, Horizont und Kulisse).
static func bounds(t: RaceTrack) -> Rect2:
	var r := Rect2(Vector2(t.frame(0.0).origin.x, t.frame(0.0).origin.z), Vector2.ZERO)
	var s := 0.0
	while s < t.length:
		var o := t.frame(s).origin
		r = r.expand(Vector2(o.x, o.z))
		s += 10.0
	return r


## Liegt ein Bodenpunkt unter einem Gleit-Abschnitt (Schlucht)?
func _in_gorge(p: Vector3, margin: float) -> bool:
	for g in track.glide_ranges:
		var s := g.x + 8.0
		while s <= g.y - 8.0:
			var o := track.frame(s).origin
			if Vector2(o.x - p.x, o.z - p.z).length() < 10.0 + margin:
				return true
			s += 6.0
	return false


func _decorate() -> void:
	var cfg: Dictionary = DECO[theme]
	var far: Array = cfg.far
	var near: Array = cfg.near
	var s := 0.0
	while s < track.length:
		var fr := track.frame(s)
		var flat_up := fr.basis.y.dot(Vector3.UP) > 0.95 and fr.origin.y < 2.5 and fr.origin.y > -1.5
		if flat_up and not track.is_glide(s) and not track.is_loop(s):
			for side: float in [-1.0, 1.0]:
				var p: Vector3 = fr.origin + fr.basis.x * side * (track.width * 0.5 + _rng.randf_range(2.5, 4.0))
				p.y = 0.0
				if _rng.randf() < 0.45 and track.min_dist_to_track(p) > track.width * 0.5 + 1.0:
					var e: Array = near[_rng.randi() % near.size()]
					var n := WorldKit.place(self, e[0], p, 0.0, _rng.randf_range(e[1], e[2]), false, false)
					n.look_at(p + fr.basis.z, Vector3.UP)
				var f: Array = far[_rng.randi() % far.size()]
				var f_scl := _rng.randf_range(f[1], f[2])
				var footprint := Assets.model_aabb(f[0]).size * f_scl
				var radius := maxf(footprint.x, footprint.z) * 0.6
				var dist := _rng.randf_range(9.0, 26.0) + radius
				var far_p: Vector3 = fr.origin + fr.basis.x * side * (track.width * 0.5 + dist)
				far_p.y = 0.0
				if _rng.randf() < (0.8 if theme == "city" else 0.55) and track.min_dist_to_track(far_p) > track.width * 0.5 + radius + 4.0:
					var rot := _rng.randf() * 360.0
					if theme == "city":
						rot = rad_to_deg(atan2(fr.basis.x.x * -side, fr.basis.x.z * -side))   # Fassade zur Straße
					WorldKit.place(self, f[0], far_p, rot, f_scl, false, _rng.randf() < 0.35)
		s += 11.0 if theme != "city" else 9.0


# --- Gewitter-Pass ----------------------------------------------------------------------------------

func _build_storm() -> void:
	# Reflektorpfosten: kleine, dezent leuchtende Marker auf beiden Leitplanken (MultiMesh, 2 Draw-Calls)
	var xf_l: Array[Transform3D] = []
	var xf_r: Array[Transform3D] = []
	var s := 0.0
	while s < track.length:
		if not track.is_glide(s):
			var fr := track.frame(s)
			var up := fr.basis.y
			var b := fr.basis
			xf_l.append(Transform3D(b, fr.origin - b.x * (track.width * 0.5 + 0.05) + up * 1.05))
			xf_r.append(Transform3D(b, fr.origin + b.x * (track.width * 0.5 + 0.05) + up * 1.05))
		s += 7.0
	_marker_mm(xf_l, Color(1.0, 0.62, 0.15))
	_marker_mm(xf_r, Color(0.95, 0.95, 1.0))
	# Regen, der der Kamera folgt
	_rain = FX.emitter({"amount": 420, "life": 1.1, "one_shot": false, "explosive": 0.0, "spread": 4.0,
		"dir": Vector3(0.15, -1, 0), "vel_min": 26.0, "vel_max": 32.0, "gravity": Vector3(0, -12, 0), "mesh": _rain_quad(),
		"billboard": false, "align_y": true, "color": Color(0.75, 0.82, 1.0, 0.45), "box": Vector3(28, 1, 28), "rand_angle": false,
		"scale_curve": null})
	_rain.scale_amount_curve = null
	add_child(_rain)
	_rain.emitting = true
	# Blitzstrahl (wird pro Blitz neu geformt)
	_bolt_mesh = MeshInstance3D.new()
	_bolt_mesh.mesh = ImmediateMesh.new()
	_bolt_mat = StandardMaterial3D.new()
	_bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bolt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bolt_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_bolt_mat.albedo_color = Color(0.85, 0.9, 1.0, 0.0)
	_bolt_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bolt_mesh.material_override = _bolt_mat
	_bolt_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bolt_mesh)
	# Dunkle Felsnadeln als Silhouetten (Blitze zeichnen sie kurz nach)
	_ring_props(["nat/rock_tall", "nat/rock_large", "nat/pine"], 26, 120.0, 175.0, Vector2(14.0, 26.0), Color(0.55, 0.58, 0.7))
	_bolt_t = 2.5


## Verteilt große Silhouetten-Objekte ringförmig um den Streckenmittelpunkt (Horizont-Füller).
func _ring_props(keys: Array, count: int, r_min: float, r_max: float, scl: Vector2, tint: Color) -> void:
	var c := Vector3.ZERO
	for i in track.point_s.size():
		c += track.frame(track.point_s[i]).origin
	c /= maxf(1.0, float(track.point_s.size()))
	c.y = 0.0
	for i in count:
		var a := TAU * i / count + _rng.randf_range(-0.1, 0.1)
		var p := c + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(r_min, r_max)
		if track.min_dist_to_track(p) < track.width + 20.0:
			continue
		var m := WorldKit.place(self, keys[_rng.randi() % keys.size()], p, _rng.randf() * 360.0, _rng.randf_range(scl.x, scl.y), false, false)
		Assets.tint(m, tint)


func _marker_mm(xfs: Array[Transform3D], col: Color) -> void:
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.42, 0.12)
	var m := StandardMaterial3D.new()
	m.albedo_color = col * 0.6
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 1.3
	bm.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = bm
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _rain_quad() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.9)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	q.material = m
	return q


func _process(delta: float) -> void:
	if theme != "storm":
		return
	var cam := get_viewport().get_camera_3d()
	if cam and _rain:
		_rain.global_position = cam.global_position + Vector3(0, 14, 0) - cam.global_basis.z * 10.0
	_bolt_t -= delta
	if _bolt_t <= 0.0:
		_bolt_t = _rng.randf_range(4.5, 9.0)
		_lightning(cam)


## Langer, mehrstufiger Blitz: Vorblitz → Hauptblitz (hält) → Nachblitz → langsames Nachglühen.
func _lightning(cam: Camera3D) -> void:
	if cam == null:
		return
	var fwd := -cam.global_basis.z
	fwd.y = 0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var side := cam.global_basis.x * _rng.randf_range(-60.0, 60.0)
	var ground := cam.global_position + fwd * _rng.randf_range(80.0, 160.0) + side
	ground.y = 0.0
	_shape_bolt(ground + Vector3(0, 120, 0), ground)
	if _flash_tw:
		_flash_tw.kill()
	_flash_tw = create_tween()
	var pulses := [[0.06, 2.2, 0.08], [0.05, 0.4, 0.06], [0.04, 5.0, 0.42], [0.08, 1.2, 0.1], [0.05, 3.6, 0.22]]
	for pl in pulses:
		_flash_tw.tween_method(_set_flash, _flash, float(pl[1]), float(pl[0]))
		_flash_tw.tween_interval(float(pl[2]))
	_flash_tw.tween_method(_set_flash, 3.6, 0.0, 1.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	var dist := cam.global_position.distance_to(ground)
	get_tree().create_timer(clampf(dist / 340.0, 0.2, 0.6) + 0.15, false).timeout.connect(func() -> void:
		Audio.sfx("thunder", null, 0.0, _rng.randf_range(0.8, 1.05), 0.0)
		Juice.shake(0.12))


func _set_flash(v: float) -> void:
	_flash = v
	if _sun:
		_sun.light_energy = _sun_base + v * 0.42
		_sun.light_color = Color(0.82, 0.86, 1.0).lerp(Color(1.0, 1.0, 1.0), clampf(v / 4.0, 0, 1))
	if _env:
		_env.ambient_light_energy = _amb_base + v * 0.16
		_env.background_energy_multiplier = 1.0 + v * 0.55
	if _bolt_mat:
		_bolt_mat.albedo_color.a = clampf(v / 3.0, 0.0, 1.0)


func _shape_bolt(top: Vector3, bottom: Vector3) -> void:
	var im := _bolt_mesh.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 14
	var prev := top
	var cam := get_viewport().get_camera_3d()
	for k in range(1, segs + 1):
		var t := float(k) / segs
		var p := top.lerp(bottom, t) + Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6)) * (1.0 - t * 0.6)
		if k == segs:
			p = bottom
		var w := lerpf(1.6, 0.5, t)
		var view := (cam.global_position - p).normalized() if cam else Vector3.BACK
		var right := (p - prev).cross(view).normalized() * w
		im.surface_add_vertex(prev - right)
		im.surface_add_vertex(prev + right)
		im.surface_add_vertex(p + right)
		im.surface_add_vertex(prev - right)
		im.surface_add_vertex(p + right)
		im.surface_add_vertex(p - right)
		# Seitenast
		if k % 4 == 2:
			var branch := p + Vector3(_rng.randf_range(-14, 14), -_rng.randf_range(8, 16), _rng.randf_range(-14, 14))
			var br := (branch - p).cross(view).normalized() * w * 0.5
			im.surface_add_vertex(p - br)
			im.surface_add_vertex(p + br)
			im.surface_add_vertex(branch)
		prev = p
	im.surface_end()


# --- Frostgipfel ----------------------------------------------------------------------------------------

func _build_snow() -> void:
	var snow := FX.emitter({"amount": 260, "life": 5.0, "one_shot": false, "explosive": 0.0, "spread": 20.0,
		"dir": Vector3(0.3, -1, 0), "vel_min": 2.0, "vel_max": 4.0, "gravity": Vector3(1.0, -1.0, 0), "size": 0.3, "color": Color(1, 1, 1, 0.9),
		"box": Vector3(40, 1, 40)})
	add_child(snow)
	snow.emitting = true
	snow.set_meta("follow_cam", true)
	_ring_props(["nat/pine_snow", "hk/tree_snow", "nat/pine_snow", "nat/rock_large"], 40, 110.0, 160.0, Vector2(9.0, 16.0), Color(1.15, 1.2, 1.3))
	set_process(true)
	_follow = snow


var _follow: Node3D


func _physics_process(_delta: float) -> void:
	if _follow:
		var cam := get_viewport().get_camera_3d()
		if cam:
			_follow.global_position = cam.global_position + Vector3(0, 12, 0) - cam.global_basis.z * 12.0


# --- Orbit-Bahn ----------------------------------------------------------------------------------------

func _build_space() -> void:
	# Kein Boden: Asteroiden, Satelliten, Ringplanet, Sternenfeld
	var planet := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 90.0
	sm.height = 180.0
	sm.material = WorldKit.mat(Color("#ffb3a0"), 0.9, 0.2)
	planet.mesh = sm
	planet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(planet)
	planet.position = Vector3(180, -120, -260)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 120.0
	tm.outer_radius = 165.0
	tm.rings = 64
	tm.material = WorldKit.mat(Color(0.95, 0.85, 0.65), 0.9, 0.5)
	ring.mesh = tm
	ring.scale = Vector3(1, 0.04, 1)
	ring.rotation_degrees = Vector3(14, 0, -10)
	planet.add_child(ring)
	var moon := MeshInstance3D.new()
	var sm2 := SphereMesh.new()
	sm2.radius = 22.0
	sm2.height = 44.0
	sm2.material = WorldKit.mat(Color("#c8d0e8"), 1.0, 0.25)
	moon.mesh = sm2
	add_child(moon)
	moon.position = Vector3(-160, 70, 140)
	var stars := FX.emitter({"amount": 260, "life": 60.0, "one_shot": false, "explosive": 0.0, "spread": 180.0, "vel_min": 0.0, "vel_max": 0.02,
		"gravity": Vector3.ZERO, "size": 1.4, "tex": FX.tex_star, "additive": true, "color": Color(1, 1, 1, 0.85), "box": Vector3(420, 160, 420)})
	add_child(stars)
	stars.position = Vector3(50, 40, 20)
	stars.preprocess = 60.0
	stars.emitting = true
	_dream_clouds()
	var keys := ["plat/block_grass_overhang", "plat/block_snow", "plat/star", "plat/heart", "plat/jewel", "plat/mushrooms", "plat/flowers"]
	var s := 0.0
	while s < track.length:
		var fr := track.frame(s)
		for side in [-1.0, 1.0]:
			if _rng.randf() < 0.55:
				var p: Vector3 = fr.origin + fr.basis.x * float(side) * _rng.randf_range(track.width * 0.5 + 10.0, track.width * 0.5 + 40.0) + Vector3.UP * _rng.randf_range(-18.0, 14.0)
				if track.min_dist_to_track(p) > track.width * 0.5 + 6.0:
					var n := WorldKit.place(self, keys[_rng.randi() % keys.size()], p, _rng.randf() * 360.0, _rng.randf_range(2.5, 6.0), false, false)
					n.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, 0)
					var tw := n.create_tween().set_loops()
					tw.tween_property(n, "rotation:y", TAU, _rng.randf_range(14.0, 30.0)).as_relative()
		s += 14.0
	# Sanfte Laternenlichter entlang der Bahn
	s = 0.0
	var colors := [Color(1.0, 0.85, 0.6), Color(1.0, 0.7, 0.85)]
	var ci := 0
	while s < track.length:
		var fr2 := track.frame(s)
		var l := OmniLight3D.new()
		l.light_color = colors[ci % 2]
		l.light_energy = 1.0
		l.omni_range = 14.0
		add_child(l)
		l.global_position = fr2.origin + fr2.basis.y * 5.0
		ci += 1
		s += 50.0


## Flauschige Pastellwolken unter und neben der schwebenden Bahn.
func _dream_clouds() -> void:
	var cols := [Color(1, 1, 1), Color("#ffe0ec"), Color("#e6dcff"), Color("#fff2d6")]
	for i in 70:
		var puff := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = _rng.randf_range(8.0, 22.0)
		sm.height = sm.radius * 1.1
		sm.material = WorldKit.mat(cols[i % cols.size()], 1.0, 0.18)
		puff.mesh = sm
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(puff)
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(60.0, 260.0)
		puff.position = Vector3(50 + cos(a) * r, _rng.randf_range(-70.0, -25.0), 20 + sin(a) * r)


# --- Stadt-Rallye --------------------------------------------------------------------------------------

func _build_city() -> void:
	# Kanal unter dem Sprung
	for g in track.glide_ranges:
		var mid := track.frame((g.x + g.y) * 0.5).origin
		var w := WorldKit.water(self, Vector2(16, 260), -0.12, Color(0.05, 0.25, 0.35), Color(0.2, 0.55, 0.6))
		w.position = Vector3(mid.x, -0.12, mid.z)
		w.rotation.y = track.frame((g.x + g.y) * 0.5).basis.get_euler().y + PI * 0.5
		for side in [-1.0, 1.0]:
			var quay := WorldKit.box(self, Vector3(1.2, 0.5, 260), Vector3(mid.x, -0.05, mid.z), Color("#8a8f99"), false)
			quay.rotation.y = w.rotation.y
			quay.position += quay.global_basis.x * float(side) * 8.4
	# Straßenlaternen (Lichter) an Kreuzungen
	var s := 0.0
	while s < track.length:
		var fr := track.frame(s)
		if not track.is_glide(s):
			var p := fr.origin + fr.basis.x * (track.width * 0.5 + 2.0)
			WorldKit.place(self, "race/light_post", Vector3(p.x, 0, p.z), 0.0, 3.0, false, false)
		s += 40.0


# --- Wüsten-Canyon ---------------------------------------------------------------------------------------

func _build_desert() -> void:
	# Schluchtboden tief unten + Felswände
	for g in track.glide_ranges:
		var s := g.x - 10.0
		while s < g.y + 10.0:
			var fr := track.frame(s)
			var o := fr.origin
			var floor_box := WorldKit.box(self, Vector3(34, 1, 12), Vector3(o.x, -32.0, o.z), Color("#a87850"), false)
			floor_box.rotation.y = fr.basis.get_euler().y
			for side in [-1.0, 1.0]:
				var wp: Vector3 = o + fr.basis.x * float(side) * 16.0
				var cliff := WorldKit.place(self, "nat/cliff_stone", Vector3(wp.x, -32.0, wp.z), rad_to_deg(fr.basis.get_euler().y), 1.0, false, false)
				cliff.scale = Vector3(12, 31.5, 12)
				Assets.tint(cliff, Color(1.15, 0.85, 0.6))
			s += 10.0
		var river := WorldKit.water(self, Vector2(10, 120), -31.3, Color(0.1, 0.35, 0.45), Color(0.3, 0.65, 0.65))
		var mid := track.frame((g.x + g.y) * 0.5)
		river.position = Vector3(mid.origin.x, -31.3, mid.origin.z)
		river.rotation.y = mid.basis.get_euler().y
	# Tafelberge / Felsnadeln am Horizont
	_ring_props(["nat/rock_tall", "nat/rock_large", "pirate/rocks_b"], 22, 130.0, 190.0, Vector2(18.0, 34.0), Color(1.25, 0.82, 0.58))


# --- 1.4.0: Glühwald, Zuckerwelt, Dschungel, Wasserfall-Schlucht ---------------------------------------------

## Glühwald: Glühwürmchen über der ganzen Strecke, farbige Lichtinseln aus Leuchtpilzen, Mondlicht.
func _build_forest() -> void:
	var s := 0.0
	var k := 0
	var cols := [Color("#d9a8ff"), Color("#8fe8ff"), Color("#ffb3e6"), Color("#b5ffb0")]
	while s < track.length:
		var fr := track.frame(s)
		if not track.is_glide(s):
			var side := 1.0 if k % 2 == 0 else -1.0
			var p: Vector3 = fr.origin + fr.basis.x * side * (track.width * 0.5 + 6.0)
			var cluster := WorldKit.place(self, "plat/mushrooms", Vector3(p.x, 0, p.z), _rng.randf() * 360.0, 7.0, false, false)
			var c: Color = cols[k % cols.size()]
			Assets.tint(cluster, c.lightened(0.3))
			var l := OmniLight3D.new()
			l.light_color = c
			l.light_energy = 1.6
			l.omni_range = 14.0
			l.shadow_enabled = false
			add_child(l)
			l.global_position = Vector3(p.x, 3.0, p.z)
		s += 38.0
		k += 1
	var b := bounds(track)
	var ff := FX.emitter({"amount": 260, "life": 6.0, "one_shot": false, "explosive": 0.0, "spread": 180.0, "vel_min": 0.2, "vel_max": 0.6,
		"gravity": Vector3(0, 0.05, 0), "size": 0.35, "additive": true, "color": Color(1.0, 0.95, 0.55, 0.95), "box": Vector3(b.size.x * 0.5 + 40, 4, b.size.y * 0.5 + 40)})
	add_child(ff)
	ff.position = Vector3(b.get_center().x, 3.0, b.get_center().y)
	ff.emitting = true
	ff.preprocess = 5.0


## Zuckerwelt: Riesen-Lollis und Donuts am Wegesrand, Schokoladenfluss unter dem Gleiter.
func _build_candy() -> void:
	var s := 20.0
	var k := 0
	while s < track.length:
		var fr := track.frame(s)
		if fr.basis.y.dot(Vector3.UP) > 0.95 and not track.is_glide(s) and not track.is_loop(s):
			var side := 1.0 if k % 2 == 0 else -1.0
			var p: Vector3 = fr.origin + fr.basis.x * side * (track.width * 0.5 + _rng.randf_range(9.0, 16.0))
			if track.min_dist_to_track(p) > track.width * 0.5 + 6.0:
				if k % 2 == 0:
					_lollipop(Vector3(p.x, 0, p.z), _rng.randf_range(7.0, 11.0))
				else:
					_donut(Vector3(p.x, 0, p.z), _rng.randf_range(3.5, 5.0))
		s += 26.0
		k += 1
	for g in track.glide_ranges:
		var mid := track.frame((g.x + g.y) * 0.5)
		var river := WorldKit.water(self, Vector2(26, g.y - g.x + 40.0), -0.4, Color("#5a2e17"), Color("#8a4a26"))
		river.position = Vector3(mid.origin.x, -0.4, mid.origin.z)
		river.rotation.y = mid.basis.get_euler().y


func _lollipop(p: Vector3, h: float) -> void:
	var stick := WorldKit.cylinder(self, 0.22, h, p + Vector3.UP * h * 0.5, Color("#fff8f0"), false)
	stick.name = "Lolli"
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = h * 0.28
	cm.bottom_radius = h * 0.28
	cm.height = 0.6
	cm.radial_segments = 24
	cm.material = WorldKit.mat([Color("#ff5c9a"), Color("#5cc8ff"), Color("#ffd23f"), Color("#9b6bff")][_rng.randi() % 4], 0.25)
	disc.mesh = cm
	disc.rotation.x = PI * 0.5
	add_child(disc)
	disc.global_position = p + Vector3.UP * (h + h * 0.2)
	disc.rotation.y = _rng.randf() * TAU
	for r in 3:
		var swirl := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = h * (0.06 + r * 0.07)
		tm.outer_radius = h * (0.09 + r * 0.07)
		tm.material = WorldKit.mat(Color(1, 1, 1), 0.3)
		swirl.mesh = tm
		swirl.rotation.x = PI * 0.5
		disc.add_child(swirl)
		swirl.position = Vector3(0, 0.32, 0)
		swirl.rotation = Vector3.ZERO


func _donut(p: Vector3, r: float) -> void:
	var dough := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r * 0.45
	tm.outer_radius = r
	tm.rings = 24
	tm.ring_segments = 12
	tm.material = WorldKit.mat(Color("#d99a5b"), 0.7)
	dough.mesh = tm
	add_child(dough)
	dough.global_position = p + Vector3.UP * r
	dough.rotation = Vector3(PI * 0.5, _rng.randf() * TAU, 0)
	var icing := MeshInstance3D.new()
	var tm2 := TorusMesh.new()
	tm2.inner_radius = r * 0.5
	tm2.outer_radius = r * 0.96
	tm2.rings = 24
	tm2.ring_segments = 10
	tm2.material = WorldKit.mat([Color("#ff8fc4"), Color("#fff2c8"), Color("#7a3e22")][_rng.randi() % 3], 0.3)
	icing.mesh = tm2
	dough.add_child(icing)
	icing.position.y = r * 0.12
	icing.scale = Vector3(1, 0.6, 1)


## Dschungel und Schlucht: Fluss unter den Gleit-Abschnitten, dichtes Ufergrün.
func _build_river() -> void:
	for g in track.glide_ranges:
		var mid := track.frame((g.x + g.y) * 0.5)
		var river := WorldKit.water(self, Vector2(30, g.y - g.x + 80.0), -0.6, Color(0.1, 0.38, 0.45), Color(0.3, 0.7, 0.7))
		river.position = Vector3(mid.origin.x, -0.6, mid.origin.z)
		river.rotation.y = mid.basis.get_euler().y
		for side: float in [-1.0, 1.0]:
			for k in 6:
				var sp := g.x - 10.0 + (g.y - g.x + 20.0) * k / 5.0
				var fr := track.frame(sp)
				var p: Vector3 = fr.origin + fr.basis.x * side * 17.0
				WorldKit.place(self, "nat/bush" if theme == "jungle" else "nat/rock_large", Vector3(p.x, -0.3, p.z), _rng.randf() * 360.0, 7.0, false, false)
