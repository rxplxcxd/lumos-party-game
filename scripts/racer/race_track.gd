class_name RaceTrack
extends Node3D
## Strecke für Nitro Dash: geschlossener Catmull-Rom-Spline mit selbst berechneten Rahmen
## (Welt-oben + Banking, im Looping analytisch zur Loop-Achse – so bleibt "oben" stabil),
## prozedurale Fahrbahn/Leitplanken/Unterseite, Glas-Tunnel unter Wasser, Boost-Felder.
## Fahrphysik arbeitet im Strecken-Raum (s = Meter entlang, x = seitlich, h = Höhe).

const STEP := 0.5

var def: Dictionary
var curve: Curve3D
var length := 0.0
var width := 16.0
var point_s: Array[float] = []
var loops: Array[Dictionary] = []
var glide_ranges: Array[Vector2] = []
var water_ranges: Array[Vector2] = []
var ramp_s: Array[float] = []
var boosts: Array[Vector2] = []     # (s, x)
var item_rows: Array[float] = []
var minimap: PackedVector2Array

var _pos := PackedVector3Array()
var _rot: Array[Quaternion] = []
var _n := 0


func build(d: Dictionary) -> void:
	def = d
	width = d.width
	var pts: Array = d.points
	curve = Curve3D.new()
	curve.bake_interval = 0.2
	var n := pts.size()
	for i in n + 1:
		var p: Vector3 = pts[i % n]
		var prev: Vector3 = pts[(i - 1 + n) % n]
		var nxt: Vector3 = pts[(i + 1) % n]
		var tan := (nxt - prev) * 0.22
		curve.add_point(p, -tan, tan)
	length = curve.get_baked_length()
	for i in n:
		point_s.append(curve.get_closest_offset(pts[i]))
	for lp in d.loops:
		var l: Dictionary = lp.duplicate()
		l["s0"] = point_s[int(lp.from)]
		l["s1"] = point_s[int(lp.to)] if int(lp.to) < n else length
		loops.append(l)
	for g in d.glide:
		glide_ranges.append(Vector2(point_s[g[0]], point_s[g[1]]))
	for w in d.water:
		water_ranges.append(Vector2(point_s[w[0]], point_s[w[1]]))
	for r in d.ramps:
		ramp_s.append(point_s[r])
	for b in d.boosts:
		boosts.append(Vector2(point_s[b[0]] + 6.0, b[1]))
	for it in d.items:
		item_rows.append(point_s[it])
	_bake_frames()
	_build_mesh()
	_build_extras()


# --- Rahmen -------------------------------------------------------------------------------------------

func _bank_at(s: float) -> float:
	var bank: Dictionary = def.bank
	if bank.is_empty():
		return 0.0
	var best := 0.0
	var weight := 0.0
	for k in bank.keys():
		var ps := point_s[int(k)]
		var d := absf(_wrap_diff(s, ps))
		var w := clampf(1.0 - d / 28.0, 0.0, 1.0)
		w = w * w * (3.0 - 2.0 * w)
		best += float(bank[k]) * w
		weight = maxf(weight, w)
	return best


func _bake_frames() -> void:
	_n = int(ceil(length / STEP)) + 1
	_pos.resize(_n)
	_rot.resize(_n)
	minimap = PackedVector2Array()
	for i in _n:
		var s := fmod(i * STEP, length)
		var p := curve.sample_baked(s, true)
		var a := curve.sample_baked(fmod(s - 0.6 + length, length), true)
		var b := curve.sample_baked(fmod(s + 0.6, length), true)
		var t := (b - a).normalized()
		var up := Vector3.UP
		for l in loops:
			if s >= float(l.s0) - 0.01 and s <= float(l.s1) + 0.01:
				var c: Vector3 = l.center
				var axis: Vector3 = l.axis
				var q := c + axis * axis.dot(p - c)
				up = (q - p).normalized()
		up = (up - t * up.dot(t)).normalized()
		var bank := deg_to_rad(_bank_at(s))
		if absf(bank) > 0.001:
			up = up.rotated(t, bank)
		var right := t.cross(up).normalized()
		up = right.cross(t).normalized()
		_pos[i] = p
		_rot[i] = Basis(right, up, -t).orthonormalized().get_rotation_quaternion().normalized()
		if i % 8 == 0:
			minimap.append(Vector2(p.x, p.z))


func _wrap_diff(a: float, b: float) -> float:
	var d := fmod(a - b, length)
	if d > length * 0.5:
		d -= length
	elif d < -length * 0.5:
		d += length
	return d


func wrap_s(s: float) -> float:
	return fposmod(s, length)


## Rahmen bei s: origin = Mittellinie, basis.x = rechts, basis.y = oben, -basis.z = vorwärts.
func frame(s: float) -> Transform3D:
	var f := fposmod(s, length) / STEP
	var i := int(floor(f))
	var j := (i + 1) % _n
	var t := f - i
	i = i % _n
	return Transform3D(Basis(_rot[i].slerp(_rot[j], t).normalized()), _pos[i].lerp(_pos[j], t))


## Weltposition für Strecken-Koordinaten.
func to_world(s: float, x: float, h: float) -> Vector3:
	var fr := frame(s)
	return fr.origin + fr.basis.x * x + fr.basis.y * h


## Krümmung (Gierrate pro Meter, + = Rechtskurve).
func curvature(s: float, ahead := 0.0) -> float:
	var f0 := frame(s + ahead)
	var f1 := frame(s + ahead + 4.0)
	var t0 := -f0.basis.z
	var t1 := -f1.basis.z
	var up := f0.basis.y
	t1 = (t1 - up * t1.dot(up)).normalized()
	var ang := t0.signed_angle_to(t1, up)
	return -ang / 4.0


func in_range(s: float, ranges: Array[Vector2]) -> bool:
	var w := wrap_s(s)
	for r in ranges:
		if w >= r.x and w <= r.y:
			return true
	return false


func is_glide(s: float) -> bool:
	return in_range(s, glide_ranges)


func is_water(s: float) -> bool:
	return in_range(s, water_ranges)


func is_loop(s: float) -> bool:
	var w := wrap_s(s)
	for l in loops:
		if w >= float(l.s0) and w <= float(l.s1):
			return true
	return false


# --- Mesh ---------------------------------------------------------------------------------------------

func _build_mesh() -> void:
	var road := SurfaceTool.new()
	road.begin(Mesh.PRIMITIVE_TRIANGLES)
	var under := SurfaceTool.new()
	under.begin(Mesh.PRIMITIVE_TRIANGLES)
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := width * 0.5
	var step := 1.5
	var count := int(ceil(length / step))
	var wall_h := 0.9
	for k in count:
		var s0 := k * step
		var s1 := minf((k + 1) * step, length)
		if is_glide(s0 + 0.1) or is_glide(s1 - 0.1):
			continue
		var f0 := frame(s0)
		var f1 := frame(s1)
		var l0 := f0.origin - f0.basis.x * hw
		var r0 := f0.origin + f0.basis.x * hw
		var l1 := f1.origin - f1.basis.x * hw
		var r1 := f1.origin + f1.basis.x * hw
		var n0 := f0.basis.y
		var n1 := f1.basis.y
		_quad(road, l0, r0, r1, l1, n0, n1, Vector2(0, s0), Vector2(1, s0), Vector2(1, s1), Vector2(0, s1))
		var d0 := -n0 * 0.6
		var d1 := -n1 * 0.6
		_quad(under, r0 + d0, l0 + d0, l1 + d1, r1 + d1, -n0, -n1, Vector2.ZERO, Vector2.ONE, Vector2.ONE, Vector2.ZERO)
		# Seitenkanten
		_quad(under, l0 + d0, l0, l1, l1 + d1, -f0.basis.x, -f1.basis.x, Vector2.ZERO, Vector2.ONE, Vector2.ONE, Vector2.ZERO)
		_quad(under, r0, r0 + d0, r1 + d1, r1, f0.basis.x, f1.basis.x, Vector2.ZERO, Vector2.ONE, Vector2.ONE, Vector2.ZERO)
		# Leitplanken
		var u0 := n0 * wall_h
		var u1 := n1 * wall_h
		var stripe := float(k % 2)
		_quad(walls, l0, l0 + u0, l1 + u1, l1, f0.basis.x, f1.basis.x, Vector2(stripe, 0), Vector2(stripe, 1), Vector2(stripe, 1), Vector2(stripe, 0))
		_quad(walls, r0 + u0, r0, r1, r1 + u1, -f0.basis.x, -f1.basis.x, Vector2(stripe, 1), Vector2(stripe, 0), Vector2(stripe, 0), Vector2(stripe, 1))
	var road_mi := MeshInstance3D.new()
	road_mi.mesh = road.commit()
	var rm := ShaderMaterial.new()
	rm.shader = load("res://assets/shaders/road.gdshader")
	rm.set_shader_parameter("track_len", length)
	rm.set_shader_parameter("start_v", 0.0)
	if def.theme == "neon":
		rm.set_shader_parameter("neon", 1.0)
	elif def.theme == "pirates":
		rm.set_shader_parameter("asphalt", Color(0.78, 0.68, 0.5))
		rm.set_shader_parameter("kerb_a", Color(0.2, 0.55, 0.95))
	road_mi.material_override = rm
	add_child(road_mi)
	var under_mi := MeshInstance3D.new()
	under_mi.mesh = under.commit()
	var um := WorldKit.mat(Color(0.35, 0.3, 0.38) if def.theme != "neon" else Color(0.12, 0.08, 0.2))
	um.cull_mode = BaseMaterial3D.CULL_DISABLED
	under_mi.material_override = um
	add_child(under_mi)
	var wall_mi := MeshInstance3D.new()
	wall_mi.mesh = walls.commit()
	var wm := StandardMaterial3D.new()
	wm.vertex_color_use_as_albedo = false
	wm.albedo_color = Color(1, 1, 1)
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	if def.theme == "neon":
		wm.emission_enabled = true
		wm.emission = Color(1.0, 0.2, 0.8)
		wm.emission_energy_multiplier = 1.5
		wm.albedo_color = Color(0.3, 0.05, 0.3)
	else:
		var g := Gradient.new()
		g.set_color(0, Color("#e8364f"))
		g.set_color(1, Color("#ffffff"))
		g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		var gt := GradientTexture1D.new()
		gt.gradient = g
		wm.albedo_texture = gt
	wall_mi.material_override = wm
	add_child(wall_mi)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	st.set_normal(na); st.set_uv(ua); st.add_vertex(a)
	st.set_normal(na); st.set_uv(ub); st.add_vertex(b)
	st.set_normal(nb); st.set_uv(uc); st.add_vertex(c)
	st.set_normal(na); st.set_uv(ua); st.add_vertex(a)
	st.set_normal(nb); st.set_uv(uc); st.add_vertex(c)
	st.set_normal(nb); st.set_uv(ud); st.add_vertex(d)


func _build_extras() -> void:
	# Boost-Felder
	var bm := ShaderMaterial.new()
	bm.shader = load("res://assets/shaders/boost_pad.gdshader")
	for b in boosts:
		var fr := frame(b.x)
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(4.0, 6.0)
		q.orientation = PlaneMesh.FACE_Y
		q.material = bm
		mi.mesh = q
		add_child(mi)
		mi.global_transform = Transform3D(fr.basis, fr.origin + fr.basis.x * b.y + fr.basis.y * 0.04)
	# Rampen-Markierung
	for rs in ramp_s:
		var fr2 := frame(rs + 4.0)
		var mi2 := MeshInstance3D.new()
		var q2 := QuadMesh.new()
		q2.size = Vector2(width * 0.85, 4.0)
		q2.orientation = PlaneMesh.FACE_Y
		q2.material = bm
		mi2.mesh = q2
		add_child(mi2)
		mi2.global_transform = Transform3D(fr2.basis, fr2.origin + fr2.basis.y * 0.05)
	# Glas-Tunnel
	for wr in water_ranges:
		_build_tube(wr.x - 6.0, wr.y + 6.0)


func _build_tube(s0: float, s1: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 16
	var r := width * 0.72
	var step := 2.0
	var s := s0
	while s < s1:
		var fa := frame(s)
		var fb := frame(minf(s + step, s1))
		for k in seg:
			var a0 := PI * k / seg
			var a1 := PI * (k + 1) / seg
			var ca := fa.origin + fa.basis.y * 0.2
			var cb := fb.origin + fb.basis.y * 0.2
			var p00 := ca + (fa.basis.x * cos(a0) + fa.basis.y * sin(a0)) * r
			var p01 := ca + (fa.basis.x * cos(a1) + fa.basis.y * sin(a1)) * r
			var p10 := cb + (fb.basis.x * cos(a0) + fb.basis.y * sin(a0)) * r
			var p11 := cb + (fb.basis.x * cos(a1) + fb.basis.y * sin(a1)) * r
			var nrm := (p00 - ca).normalized()
			_quad(st, p00, p01, p11, p10, -nrm, -nrm, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
		# Rippen & Lichter
		if int(s) % 16 < 2:
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = r - 0.15
			tm.outer_radius = r + 0.15
			tm.rings = 24
			ring.mesh = tm
			ring.material_override = WorldKit.mat(Color(0.6, 0.75, 0.9), 0.3, 0.2)
			add_child(ring)
			ring.global_transform = Transform3D(fa.basis * Basis(Vector3.RIGHT, PI / 2.0), fa.origin + fa.basis.y * 0.2)
			var spot := SpotLight3D.new()
			spot.light_color = Color(0.6, 0.9, 1.0)
			spot.light_energy = 1.6
			spot.spot_range = r * 1.8
			spot.spot_angle = 32.0
			add_child(spot)
			spot.global_transform = Transform3D(Basis.looking_at(-fa.basis.y, -fa.basis.z), fa.origin + fa.basis.y * (r * 0.9))
			var cone := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.3
			cm.bottom_radius = r * 0.55
			cm.height = r * 0.85
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.albedo_color = Color(0.4, 0.75, 1.0, 0.07)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			cm.material = m
			cone.mesh = cm
			add_child(cone)
			cone.global_transform = Transform3D(fa.basis, fa.origin + fa.basis.y * (r * 0.9 - r * 0.42))
		s += step
	var tube := MeshInstance3D.new()
	tube.mesh = st.commit()
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.3, 0.6, 0.85, 0.16)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	gm.roughness = 0.05
	gm.metallic_specular = 1.0
	tube.mesh.surface_set_material(0, gm)
	tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tube)


## Nächste Position auf der Strecke zu einem Weltpunkt (grob, für Respawn/Deko-Abstand).
func min_dist_to_track(p: Vector3) -> float:
	var best := INF
	for i in range(0, _n, 6):
		best = minf(best, _pos[i].distance_to(p))
	return best
