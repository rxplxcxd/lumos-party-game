class_name LumosFace
extends Node3D
## Gesichtsebene des Character-Frameworks (siehe docs/CHARACTER_FRAMEWORK.md).
##
## Für Figuren ohne Gesichts-Bones. Die Ebene hängt am Kopfknochen (oder bei Figuren ohne Skelett am Kopf-Mesh) und
## zeichnet Augen, Glanzpunkte, Brauen, Wangen und Mund jedes Bild neu aus wenigen Parametern.
##  * Vermessung je Modell: Kopf-Mesh suchen, Original-Augen (dunkle Kapseln) finden und in einer EIGENEN Kopie des
##    Meshs versenken; Original-Brauen nur ersetzen, wenn sie eindeutig erkennbar sind (nie doppelte Brauen).
##  * Oberflächentreu: Aus dem Kopf-Mesh entsteht ein Tiefenraster der Gesichtsfläche. Jeder gezeichnete Punkt liegt
##    knapp über der Haut – auch ein breiter Mund folgt der Rundung des Gesichts und schwebt bei Seitenansicht nicht.
##  * Alle Maße relativ zur Kopfbreite: gleiche Ausdrücke bei unterschiedlichen Proportionen.
##
##   var face := LumosFace.new()
##   if face.setup(rig): face.set_expression("laugh", 0.2)
## Signal: expression_changed(name). Ausdrücke = Parametersätze (EXPR, erweiterbar über add_expression()).

signal expression_changed(name: String)

const EXPR := {
	"neutral": {"curve": 0.25},
	"smile": {"curve": 0.85, "squint": 0.25, "brow": 0.2, "blush": 0.25},
	"grin": {"curve": 1.0, "open": 0.3, "squint": 0.45, "brow": 0.3, "blush": 0.45},
	"joy": {"curve": 1.0, "open": 0.45, "squint": 0.6, "brow": 0.6, "blush": 0.7},
	"laugh": {"curve": 1.0, "open": 0.68, "squint": 0.95, "brow": 0.55, "blush": 1.0},
	"awe": {"wide": 1.0, "brow": 1.0, "open": 0.75, "round": 1.0, "curve": 0.0},
	"surprised": {"wide": 1.0, "brow": 1.0, "open": 0.72, "round": 0.95, "curve": 0.0},
	"curious": {"brow": 0.6, "asym": 1.0, "open": 0.22, "round": 0.8, "curve": 0.15, "wide": 0.3},
	"confused": {"brow": 0.5, "asym": 1.0, "tilt": 0.3, "curve": -0.25, "open": 0.12, "round": 0.4},
	"scared": {"wide": 0.9, "brow": 0.8, "tilt": 0.9, "open": 0.6, "curve": -0.7, "width": 1.2},
	"worried": {"tilt": 0.8, "brow": 0.3, "curve": -0.55, "open": 0.12},
	"sad": {"tilt": 0.95, "curve": -1.0, "lid": 0.25, "brow": 0.15, "open": 0.14, "width": 1.1},
	"angry": {"tilt": -1.0, "brow": -0.6, "curve": -0.6, "lid": 0.2, "open": 0.42, "width": 1.25},
	"determined": {"tilt": -0.8, "brow": -0.3, "curve": 0.2, "lid": 0.15},
	"sleepy": {"lid": 0.55, "brow": -0.2, "curve": 0.0},
	"asleep": {"lid": 1.0, "open": 0.16, "round": 0.6, "curve": 0.0, "brow": -0.1},
	"pant": {"open": 0.55, "round": 0.35, "tilt": 0.6, "lid": 0.2, "curve": -0.2},
	"ouch": {"lid": 1.0, "tilt": -0.6, "brow": -0.4, "open": 0.45, "curve": -0.85, "width": 1.25},
	"smug": {"lid": 0.35, "curve": 0.75, "asym": 1.0, "brow": 0.2, "blush": 0.2},
	"dreamy": {"lid": 0.3, "curve": 0.6, "brow": 0.3, "blush": 0.5},
	"plead": {"wide": 0.8, "brow": 0.7, "tilt": 0.9, "curve": 0.35, "blush": 0.6},
}
const KEYS := ["lid", "squint", "wide", "brow", "tilt", "asym", "open", "curve", "width", "round", "blush"]
const SEG := 14
const GRID := 0.025          ## Rasterweite des Tiefenrasters (Anteil der Kopfbreite)

static var _cache := {}      ## Modell → Vermessung (Mesh-Kopie, Augen, Mund, Raster) – gleiche Figuren teilen sie

var expressions: Dictionary = EXPR.duplicate(true)   # je Instanz erweiterbar
var current := "neutral"
var has_own_brows := false     # true: Original-Brauen wurden ersetzt und sind beweglich
var dt_scale := 1.0
var laugh := 0.0          # 0..1 – Mund geht im Lachrhythmus auf und zu (Phase kommt vom Körper)
var laugh_phase := 0.0
var chew := 0.0           # 0..1 – Kaubewegung
var gaze := Vector2.ZERO  # Blickrichtung der Augen (−1..1)
var blink_on := true
var feature_scale := 1.0  # Gesamtgröße der Züge (1 = Standard; größer = von weitem besser lesbar)

var _cur := {}
var _tgt := {}
var _tau := 0.1
var _m := {}              # Vermessung: eye_c (Array), eye_r (Vector2), mouth (Vector3), u (Kopfbreite), grid …
var _im: ImmediateMesh
var _mat := {}
var _blink_t := 2.0
var _blink := 0.0
var _flash := 0.0
var _t := 0.0
var _last_sig := 0.0
var _lod_acc := 0.0
var paused := false              # LOD: außerhalb des Bildes nicht aktualisieren


## Baut die Ebene. false = Modell ungeeignet (kein Kopf-Mesh, keine erkennbaren Augen) – die Figur bleibt unverändert.
func setup(rig: CharacterRig) -> bool:
	if rig == null or rig.model == null:
		return false
	for k in KEYS:
		_cur[k] = 1.0 if k == "width" else 0.0
		_tgt[k] = _cur[k]
	var head := _find_head_mesh(rig)
	if head == null:
		push_warning("LumosFace: kein Kopf-Mesh gefunden (%s) – Gesicht übersprungen" % rig.model_key)
		return false
	var key := rig.model_key + "|" + String(head.name)
	if not _cache.has(key):
		_cache[key] = _measure(head)
	_m = _cache[key]
	if _m.is_empty():
		push_warning("LumosFace: keine Augen im Kopf-Mesh erkannt (%s) – Gesicht übersprungen" % rig.model_key)
		return false
	head.mesh = _m.mesh
	has_own_brows = bool(_m.brows)
	# Befestigung: am Kopfknochen (lokale Koordinaten = Skelett-Raum in Ruhepose) oder direkt am Kopf-Mesh
	var sk := rig.skel
	var hb := sk.find_bone("head") if sk else -1
	if hb >= 0 and head.skin != null:
		var att := BoneAttachment3D.new()
		att.bone_name = sk.get_bone_name(hb)
		sk.add_child(att)
		att.add_child(self)
		# lokale Koordinaten = Mesh-Raum in Ruhepose (Kopfknochen-Ruhepose herausgerechnet, Mesh-Versatz berücksichtigt)
		transform = sk.get_bone_global_rest(hb).affine_inverse() * (sk.global_transform.affine_inverse() * head.global_transform)
	else:
		head.add_child(self)
	_im = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _im
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("gfx_tuned", true)
	add_child(mi)
	for e in [["eye", Color("#14181c"), 0.25, 1.0], ["white", Color("#ffffff"), 0.4, 1.0], ["cavity", Color("#3a1216"), 0.9, 1.0],
			["teeth", Color("#f6f1e6"), 0.6, 1.0], ["tongue", Color("#e0707a"), 0.7, 1.0], ["brow", _m.brow_col, 0.9, 1.0],
			["blush", Color("#ff7a8a"), 0.9, 0.55]]:
		var m := StandardMaterial3D.new()
		m.albedo_color = e[1]
		m.albedo_color.a = float(e[3])
		m.roughness = e[2]
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if float(e[3]) < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat[e[0]] = m
	set_expression("neutral", 0.0)
	_blink_t = randf_range(1.0, 4.0)
	return true


## Kopf-Mesh: KayKit „*_Head“, Kenney „head-mesh“, sonst ein Mesh mit „head“ im Namen, sonst (Figuren ohne Skelett)
## das größte Mesh des Modells.
static func _find_head_mesh(rig: CharacterRig) -> MeshInstance3D:
	var best: MeshInstance3D = null
	var best_v := 0.0
	for n in Assets.find_meshes(rig.model):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var nm := String(mi.name).to_lower()
		if nm.ends_with("_head") or nm == "head-mesh" or nm == "head":
			return mi
		var v := mi.mesh.get_aabb().get_volume()
		if nm.contains("head") and not nm.contains("helmet"):
			v *= 100.0
		if v > best_v:
			best_v = v
			best = mi
	if best == null:
		return null
	return best if rig.skel == null or String(best.name).to_lower().contains("head") else null


## Vermessung eines Kopf-Meshs (einmal je Modell): Augen, Brauen, Mund, Tiefenraster; Augen/Brauen versenkt.
static func _measure(head: MeshInstance3D) -> Dictionary:
	var mesh := head.mesh
	var mat := head.get_active_material(0) as BaseMaterial3D
	if mat == null or mat.albedo_texture == null:
		return {}
	var img := mat.albedo_texture.get_image()
	if img.is_compressed():
		img.decompress()
	var arr := mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var bb := mesh.get_aabb()
	var u := bb.size.x                       # Kopfbreite = Maßeinheit aller Züge
	var cx := bb.get_center().x
	var front := bb.end.z
	var px := func(i: int) -> Color:
		return img.get_pixel(clampi(int(fposmod(uv[i].x, 1.0) * img.get_width()), 0, img.get_width() - 1),
			clampi(int(fposmod(uv[i].y, 1.0) * img.get_height()), 0, img.get_height() - 1))
	# Augen: dunkle, leicht bläuliche Punkte vorne in der oberen Gesichtshälfte, je Seite gesammelt
	var mn := [Vector3.INF, Vector3.INF]
	var mx := [-Vector3.INF, -Vector3.INF]
	var idx: Array = [[], []]
	for i in vs.size():
		var v := vs[i]
		if v.z < front - 0.3 * bb.size.z or absf(v.x - cx) > 0.3 * u or v.y < bb.position.y + 0.2 * bb.size.y or v.y > bb.position.y + 0.62 * bb.size.y:
			continue
		var c: Color = px.call(i)
		if c.get_luminance() < 0.2 and c.g - c.r > 0.008:
			var sd := 0 if v.x < cx else 1
			mn[sd] = (mn[sd] as Vector3).min(v)
			mx[sd] = (mx[sd] as Vector3).max(v)
			(idx[sd] as Array).append(i)
	if (idx[0] as Array).size() < 6 or (idx[1] as Array).size() < 6:
		return {}
	var eye_c: Array[Vector3] = []
	var er := Vector2.ZERO
	for sd in 2:
		var a: Vector3 = mn[sd]
		var b: Vector3 = mx[sd]
		eye_c.append(Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, b.z))
		er = er.max(Vector2((b.x - a.x) * 0.5, (b.y - a.y) * 0.5))
	for sd in 2:
		for i in idx[sd]:
			vs[i] = Vector3(lerpf(vs[i].x, cx, 0.5), vs[i].y, vs[i].z - 0.4 * bb.size.z)   # Original-Auge im Kopf versenken
	var eye_y := (eye_c[0].y + eye_c[1].y) * 0.5
	# Hautfarbe = häufigste Farbe auf Mundhöhe
	var my := eye_y - 0.15 * u
	var hist := {}
	var skin := Color(0.9, 0.7, 0.55)
	var best := 0
	for i in vs.size():
		if absf(vs[i].x - cx) < 0.13 * u and absf(vs[i].y - my) < 0.08 * u and vs[i].z > front - 0.15 * bb.size.z:
			var ck: Color = px.call(i)
			var key := ck.to_html(false).substr(0, 4)
			hist[key] = int(hist.get(key, 0)) + 1
			if int(hist[key]) > best:
				best = int(hist[key])
				skin = ck
	# Original-Brauen: kleine, nicht hautfarbene Fläche direkt über jedem Auge – nur wenn auf beiden Seiten eindeutig
	var ey := eye_y + er.y
	var cand: Array = [[], []]
	for i in vs.size():
		var v := vs[i]
		if v.y > ey + 0.004 * u and v.y < ey + 0.1 * u and v.z > eye_c[0].z - 0.07 * u:
			var sd := 0 if v.x < cx else 1
			if absf(v.x - eye_c[sd].x) < er.x * 2.0:
				var c: Color = px.call(i)
				if absf(c.r - skin.r) + absf(c.g - skin.g) + absf(c.b - skin.b) > 0.35:
					(cand[sd] as Array).append([i, c])
	var brows := true
	var brow_col := Color("#2b1c14")
	var brow_y := 0.0
	for sd in 2:
		var lo := INF
		for e in cand[sd]:
			lo = minf(lo, vs[int(e[0])].y)
		cand[sd] = (cand[sd] as Array).filter(func(e2: Array) -> bool: return vs[int(e2[0])].y < lo + 0.045 * u)
		if (cand[sd] as Array).size() < 6 or (cand[sd] as Array).size() > 60:
			brows = false
	if brows:
		var ysum := 0.0
		var n := float((cand[0] as Array).size() + (cand[1] as Array).size())
		for sd in 2:
			for e in cand[sd]:
				ysum += vs[int(e[0])].y / n
				vs[int(e[0])] = Vector3(lerpf(vs[int(e[0])].x, cx, 0.5), vs[int(e[0])].y - 0.05 * u, vs[int(e[0])].z - 0.4 * bb.size.z)
		brow_col = cand[0][0][1]
		brow_y = ysum - eye_y
	arr[Mesh.ARRAY_VERTEX] = vs
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.surface_set_material(0, mesh.surface_get_material(0))
	for s2 in range(1, mesh.get_surface_count()):
		am.add_surface_from_arrays(mesh.surface_get_primitive_type(s2), mesh.surface_get_arrays(s2))
		am.surface_set_material(s2, mesh.surface_get_material(s2))
	# Tiefenraster der Gesichtsfläche (vorderste Haut je Rasterpunkt) aus den Dreiecken des versenkten Meshs
	var g := GRID * u
	var gx0 := cx - 0.48 * u
	var gy0 := eye_y - 0.42 * u
	var nx := int(ceil(0.96 * u / g)) + 1
	var ny := int(ceil(0.72 * u / g)) + 1
	var depth := PackedFloat32Array()
	depth.resize(nx * ny)
	depth.fill(-INF)
	var ia: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var tri_n := ia.size() / 3 if ia.size() > 0 else vs.size() / 3
	for t in tri_n:
		var p0 := vs[ia[t * 3] if ia.size() > 0 else t * 3]
		var p1 := vs[ia[t * 3 + 1] if ia.size() > 0 else t * 3 + 1]
		var p2 := vs[ia[t * 3 + 2] if ia.size() > 0 else t * 3 + 2]
		var den := (p1.y - p2.y) * (p0.x - p2.x) + (p2.x - p1.x) * (p0.y - p2.y)
		if absf(den) < 1e-9:
			continue
		var i0 := maxi(int(floor((minf(p0.x, minf(p1.x, p2.x)) - gx0) / g)), 0)
		var i1 := mini(int(ceil((maxf(p0.x, maxf(p1.x, p2.x)) - gx0) / g)), nx - 1)
		var j0 := maxi(int(floor((minf(p0.y, minf(p1.y, p2.y)) - gy0) / g)), 0)
		var j1 := mini(int(ceil((maxf(p0.y, maxf(p1.y, p2.y)) - gy0) / g)), ny - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var x := gx0 + i * g
				var y := gy0 + j * g
				var w0 := ((p1.y - p2.y) * (x - p2.x) + (p2.x - p1.x) * (y - p2.y)) / den
				var w1 := ((p2.y - p0.y) * (x - p2.x) + (p0.x - p2.x) * (y - p2.y)) / den
				var w2 := 1.0 - w0 - w1
				if w0 >= -0.02 and w1 >= -0.02 and w2 >= -0.02:
					var z := w0 * p0.z + w1 * p1.z + w2 * p2.z
					if z > depth[j * nx + i]:
						depth[j * nx + i] = z
	# Lücken mit dem Nachbarwert füllen (Ränder des Gesichts)
	for pass_i in 3:
		for j in ny:
			for i in nx:
				if depth[j * nx + i] == -INF:
					var acc := -INF
					for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
						var ii: int = i + int(d[0])
						var jj: int = j + int(d[1])
						if ii >= 0 and ii < nx and jj >= 0 and jj < ny:
							acc = maxf(acc, depth[jj * nx + ii])
					depth[j * nx + i] = acc
	var nrm := PackedVector3Array()
	nrm.resize(nx * ny)
	for j in ny:
		for i in nx:
			var zl := depth[j * nx + maxi(i - 1, 0)]
			var zr := depth[j * nx + mini(i + 1, nx - 1)]
			var zd := depth[maxi(j - 1, 0) * nx + i]
			var zu := depth[mini(j + 1, ny - 1) * nx + i]
			var ok := zl > -1e6 and zr > -1e6 and zd > -1e6 and zu > -1e6
			nrm[j * nx + i] = Vector3(-(zr - zl) / (2.0 * g), -(zu - zd) / (2.0 * g), 1.0).normalized() if ok else Vector3(0, 0.15, 1).normalized()
	var res := {"nrm": nrm, "mesh": am, "eye_c": eye_c, "eye_r": er, "u": u, "cx": cx, "brows": brows, "brow_col": brow_col, "brow_y": brow_y,
		"mouth": Vector3(cx, eye_y - 0.16 * u, 0.0), "gx0": gx0, "gy0": gy0, "g": g, "nx": nx, "ny": ny, "depth": depth, "front": front}
	return res


## Hautoberfläche (z) unter einem Punkt des Gesichts – bilinear aus dem Tiefenraster.
func surface_z(x: float, y: float) -> float:
	var g: float = _m.g
	var fx := clampf((x - float(_m.gx0)) / g, 0.0, float(_m.nx) - 1.001)
	var fy := clampf((y - float(_m.gy0)) / g, 0.0, float(_m.ny) - 1.001)
	var i := int(fx)
	var j := int(fy)
	var nx: int = _m.nx
	var d: PackedFloat32Array = _m.depth
	var a := lerpf(d[j * nx + i], d[j * nx + i + 1], fx - i)
	var b := lerpf(d[(j + 1) * nx + i], d[(j + 1) * nx + i + 1], fx - i)
	var z := lerpf(a, b, fy - j)
	return z if z > -1e6 else float(_m.front)


## Lokale Hautfläche eines Gesichtszugs um (cx, cy) mit Halbbreite r: Höhe, Neigung, Krümmung quer und Normale –
## jeder Punkt des Zugs wird daraus berechnet (drei Raster-Abfragen je Zug statt einer je Punkt).
func _plane(cx: float, cy: float, r: float) -> Array:
	var zc := surface_z(cx, cy)
	var zl := surface_z(cx - r, cy)
	var zr := surface_z(cx + r, cy)
	var n := _nrm(cx, cy)
	var sy := -n.y / maxf(n.z, 0.2)
	return [cx, cy, zc, (zr - zl) / (2.0 * r), sy, (zr + zl - 2.0 * zc) / (r * r), n]


func _nrm(x: float, y: float) -> Vector3:
	var i := clampi(int(roundf((x - float(_m.gx0)) / float(_m.g))), 0, int(_m.nx) - 1)
	var j := clampi(int(roundf((y - float(_m.gy0)) / float(_m.g))), 0, int(_m.ny) - 1)
	return (_m.nrm as PackedVector3Array)[j * int(_m.nx) + i]


## Ausdruck wechseln. secs = Dauer des weichen Übergangs, intensity 0..1 mischt mit „neutral“.
func set_expression(name: String, secs := 0.18, intensity := 1.0) -> void:
	if not expressions.has(name):
		push_warning("LumosFace: unbekannter Ausdruck '%s'" % name)
		name = "neutral"
	var e: Dictionary = expressions[name]
	var n: Dictionary = expressions.neutral
	for k in KEYS:
		var base := 1.0 if k == "width" else 0.0
		_tgt[k] = lerpf(float(n.get(k, base)), float(e.get(k, base)), clampf(intensity, 0.0, 1.0))
	_tau = maxf(secs, 0.001) / 2.5
	if secs <= 0.0:
		for k in KEYS:
			_cur[k] = _tgt[k]
	if name != current:
		current = name
		expression_changed.emit(name)


## Alias der Trailer-Schreibweise.
func set_expr(name: String, secs := 0.16) -> void:
	set_expression(name, secs)


func add_expression(name: String, params: Dictionary) -> void:
	expressions[name] = params


func param(key: String) -> float:
	return float(_cur.get(key, 0.0))


## Kurzes Hochziehen der Brauen (Erkennen, Aufmerksamkeit), klingt von selbst ab.
func flash_brows(amount := 0.5) -> void:
	_flash = maxf(_flash, amount)


## Vermessene Werte (für Tests und eigene Anbauten): eye_c, eye_r, mouth, u (Kopfbreite) …
func metrics() -> Dictionary:
	return _m


func _process(delta: float) -> void:
	if _im == null or paused:
		return
	delta *= dt_scale
	_t += delta
	var f := 1.0 - exp(-delta / _tau)
	for k in KEYS:
		_cur[k] = lerpf(_cur[k], _tgt[k], f)
	_flash = move_toward(_flash, 0.0, delta * 1.4)
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink_t = randf_range(2.2, 5.0)
		if blink_on and float(_tgt.squint) < 0.6 and float(_tgt.lid) < 0.8:
			_blink = 1.0
	var bl := 0.0
	if _blink > 0.0:
		_blink = maxf(0.0, _blink - delta / 0.17)
		bl = sin(clampf(1.0 - _blink, 0.0, 1.0) * PI)
	# nur neu zeichnen, wenn sich etwas sichtbar ändert
	var sig := bl * 7.0 + laugh * 3.1 + sin(laugh_phase) * laugh + chew * sin(_t * 9.0) + gaze.x * 1.7 + gaze.y * 2.3 + _flash * 5.0 + feature_scale
	for k in KEYS:
		sig += float(_cur[k]) * (KEYS.find(k) + 1.3)
	_lod_acc += delta
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var period := 0.0
	if cam:
		var dist := cam.global_position.distance_to(global_position) / maxf(float(_m.u) * global_basis.get_scale().x, 0.01)
		period = 0.0 if dist < 14.0 else (0.05 if dist < 40.0 else 0.2)   # nah: jedes Bild · mittel: 20 Hz · fern: 5 Hz
	if absf(sig - _last_sig) > 0.0005 and _lod_acc >= period:
		_lod_acc = 0.0
		_last_sig = sig
		_draw(bl)


func _draw(bl: float) -> void:
	_im.clear_surfaces()
	var u: float = _m.u
	var fs := feature_scale
	var eye_c: Array = _m.eye_c
	var er: Vector2 = _m.eye_r * 1.12 * fs
	var lid := clampf(maxf(float(_cur.lid), bl), 0.0, 1.0)
	var squint := clampf(float(_cur.squint) + laugh * 0.4, 0.0, 1.0)
	var wide := float(_cur.wide)
	var a := er.x * (1.0 + 0.22 * wide)
	var b := er.y * (1.0 + 0.3 * wide + 0.1 * float(_cur.brow))
	var gz := Vector2(gaze.x * 0.012, gaze.y * 0.008) * u
	# --- Augen ---
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat.eye)
	for sd in 2:
		var c: Vector3 = eye_c[sd]
		var cx := c.x + gz.x
		var cy := c.y + gz.y
		var inner := 1.0 if sd == 0 else -1.0
		var ld := clampf(lid + (float(_cur.asym) * 0.3 if sd == 1 else 0.0), 0.0, 1.0)
		var pe := _plane(cx, cy, a)
		for k in SEG:
			var x0 := -1.0 + 2.0 * k / SEG
			var x1 := -1.0 + 2.0 * (k + 1) / SEG
			var t0 := _eye_top(x0, b, ld, x0 * inner)
			var t1 := _eye_top(x1, b, ld, x1 * inner)
			var b0 := _eye_bot(x0, b, ld, squint, t0, u)
			var b1 := _eye_bot(x1, b, ld, squint, t1, u)
			_quad_s(pe, cx + x0 * a, cy + t0, cx + x1 * a, cy + t1, cx + x1 * a, cy + b1, cx + x0 * a, cy + b0, 0.004)
	_im.surface_end()
	# --- Glanzpunkte (nur bei offenen Augen) ---
	if lid < 0.5 and squint < 0.55:
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat.white)
		for sd in 2:
			var c2: Vector3 = eye_c[sd]
			var hx := c2.x + gz.x - a * 0.28 + gaze.x * a * 0.2
			var hy := c2.y + gz.y + b * 0.38 - lid * b * 0.5
			var r := (0.011 + 0.004 * wide) * u * fs
			var ph := _plane(hx, hy, r * 2.0)
			for k in 8:
				var a0 := TAU * k / 8.0
				var a1 := TAU * (k + 1) / 8.0
				_tri_s(ph, Vector2(hx, hy), Vector2(hx + cos(a0) * r, hy + sin(a0) * r), Vector2(hx + cos(a1) * r, hy + sin(a1) * r), 0.007)
		_im.surface_end()
	# --- Wangenröte (Freude, Verlegenheit) ---
	var blush := float(_cur.blush) + laugh * 0.3
	if blush > 0.03:
		(_mat.blush as StandardMaterial3D).albedo_color.a = clampf(blush, 0.0, 1.0) * 0.55
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat.blush)
		for sd in 2:
			var c3: Vector3 = eye_c[sd]
			var bx := c3.x + (-0.075 if sd == 0 else 0.075) * u
			var by := c3.y - 0.085 * u
			var rx := 0.06 * u * fs
			var ry := 0.034 * u * fs
			var pb := _plane(bx, by, rx)
			for k in 12:
				var a2 := TAU * k / 12.0
				var a3 := TAU * (k + 1) / 12.0
				_tri_s(pb, Vector2(bx, by), Vector2(bx + cos(a2) * rx, by + sin(a2) * ry), Vector2(bx + cos(a3) * rx, by + sin(a3) * ry), 0.003)
		_im.surface_end()
	# --- Brauen (nur wenn die Original-Brauen ersetzt wurden) ---
	if has_own_brows:
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat.brow)
		for sd in 2:
			var s := -1.0 if sd == 0 else 1.0
			var c4: Vector3 = eye_c[sd]
			var raise := float(_cur.brow) + _flash + (float(_cur.asym) * 0.7 if sd == 0 else 0.0)
			var bx2 := c4.x
			var by2 := c4.y + float(_m.brow_y) + raise * 0.045 * u + wide * 0.012 * u
			var ang := float(_cur.tilt) * 0.45 * s
			var hl := er.x * 1.45
			var th := 0.0085 * u * fs
			var pw := _plane(bx2, by2, hl)
			var pts: Array[Vector2] = []
			for k in 7:   # leicht gebogene Braue aus 6 Stücken
				var xx := -1.0 + 2.0 * k / 6.0
				var yy := (1.0 - xx * xx) * 0.012 * u
				pts.append(Vector2(bx2 + cos(ang) * xx * hl - sin(ang) * yy, by2 + sin(ang) * xx * hl + cos(ang) * yy))
			for k in 6:
				var thk := th * (1.0 - 0.35 * absf(-1.0 + 2.0 * (k + 0.5) / 6.0))
				_quad_s(pw, pts[k].x, pts[k].y + thk, pts[k + 1].x, pts[k + 1].y + thk, pts[k + 1].x, pts[k + 1].y - thk, pts[k].x, pts[k].y - thk, 0.006)
		_im.surface_end()
	# --- Mund: groß und rund, damit Gefühle auch von weitem lesbar sind ---
	var open := clampf(float(_cur.open) + laugh * (0.2 + 0.3 * (0.5 + 0.5 * sin(laugh_phase))), 0.0, 1.0)
	var curve := float(_cur.curve)
	var rnd := float(_cur.round)
	var w := 0.125 * u * fs * float(_cur.width) * (1.0 + 0.45 * maxf(curve, 0.0) + 0.4 * open) * lerpf(1.0, 0.8, rnd) * (1.0 + 0.1 * sin(_t * 9.0) * chew)
	if chew > 0.0:
		open = maxf(open * (1.0 - chew), 0.0)
		curve = lerpf(curve, 0.35 + 0.25 * sin(_t * 9.0), chew)
	var hu := (0.015 + open * lerpf(0.03, 0.12, rnd)) * u * fs
	var hl2 := (0.015 + open * lerpf(0.22, 0.15, rnd)) * u * fs
	if curve < 0.0 and open > 0.05:
		# offener Mund bei negativen Gefühlen: oben gewölbt, unten flach („∩“) – liest sich als Grimasse statt Grinsen
		var k := clampf(-curve, 0.0, 1.0) * 0.65
		var tot := hu + hl2
		hu = lerpf(hu, tot * 0.62, k)
		hl2 = tot - hu
	var mc: Vector3 = _m.mouth
	var top: Array[Vector2] = []
	var bot: Array[Vector2] = []
	for k in SEG + 1:
		var x := -1.0 + 2.0 * k / SEG
		var bell := pow(maxf(1.0 - x * x, 0.0), lerpf(0.7, 0.5, rnd))
		var yc := curve * 0.085 * u * fs * (x * x - 0.4)
		top.append(Vector2(mc.x + x * w, mc.y + yc + hu * bell))
		bot.append(Vector2(mc.x + x * w, mc.y + yc - hl2 * bell))
	var pm := _plane(mc.x, mc.y - (hl2 - hu) * 0.5, maxf(w, 0.02 * u))
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat.cavity)
	for k in SEG:
		var m0 := (top[k] + bot[k]) * 0.5
		var m1 := (top[k + 1] + bot[k + 1]) * 0.5
		_quad_s(pm, top[k].x, top[k].y, top[k + 1].x, top[k + 1].y, m1.x, m1.y, m0.x, m0.y, 0.005)
		_quad_s(pm, m0.x, m0.y, m1.x, m1.y, bot[k + 1].x, bot[k + 1].y, bot[k].x, bot[k].y, 0.005)
	_im.surface_end()
	if open > 0.2:
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat.teeth)
		for k in range(2, SEG - 2):
			var d0 := (top[k] - bot[k]) * 0.24
			var d1 := (top[k + 1] - bot[k + 1]) * 0.24
			_quad_s(pm, top[k].x, top[k].y, top[k + 1].x, top[k + 1].y, top[k + 1].x - d1.x, top[k + 1].y - d1.y, top[k].x - d0.x, top[k].y - d0.y, 0.008)
		_im.surface_end()
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat.tongue)
		for k in range(3, SEG - 3):
			var e0 := (top[k] - bot[k]) * 0.38
			var e1 := (top[k + 1] - bot[k + 1]) * 0.38
			_quad_s(pm, bot[k].x + e0.x, bot[k].y + e0.y, bot[k + 1].x + e1.x, bot[k + 1].y + e1.y, bot[k + 1].x, bot[k + 1].y, bot[k].x, bot[k].y, 0.008)
		_im.surface_end()


## Oberkante des Auges: Bogen, vom Oberlid gekappt; tilt stellt das Lid schräg (besorgt > 0, grimmig < 0).
func _eye_top(x: float, b: float, lid: float, xi: float) -> float:
	var tl := float(_cur.tilt)
	var cap := b * (1.0 - 1.15 * lid - 0.3 * absf(tl) + 0.55 * tl * xi)
	return minf(b * sqrt(maxf(1.0 - x * x, 0.0)), cap)


func _eye_bot(x: float, b: float, lid: float, squint: float, top: float, u: float) -> float:
	var arc := b * sqrt(maxf(1.0 - x * x, 0.0))
	var open_bot := maxf(-arc, -b * (1.0 - 0.75 * lid))
	var y := lerpf(open_bot, arc - 0.026 * u, squint)   # Lachaugen: kräftige Sichel „∩“
	return minf(y, top - 0.012 * u)


## Viereck auf der Haut (Ecken als x/y-Paare) über der Fläche pl, off = Abstand darüber (Anteil der Kopfbreite).
func _quad_s(pl: Array, x0: float, y0: float, x1: float, y1: float, x2: float, y2: float, x3: float, y3: float, off: float) -> void:
	_tri_s(pl, Vector2(x0, y0), Vector2(x1, y1), Vector2(x2, y2), off)
	_tri_s(pl, Vector2(x0, y0), Vector2(x2, y2), Vector2(x3, y3), off)


func _tri_s(pl: Array, p0: Vector2, p1: Vector2, p2: Vector2, off: float) -> void:
	var n: Vector3 = pl[6]
	var o := off * float(_m.u)
	for p: Vector2 in [p0, p1, p2]:
		var dx: float = p.x - float(pl[0])
		var z: float = float(pl[2]) + float(pl[3]) * dx + float(pl[4]) * (p.y - float(pl[1])) + 0.5 * float(pl[5]) * dx * dx
		_im.surface_set_normal(n)
		_im.surface_add_vertex(Vector3(p.x, p.y, z + o))
