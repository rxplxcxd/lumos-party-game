extends Node3D
## Gesichtsebene für die Trailer-Darsteller (nur Trailer – das Spiel kennt diese Datei nicht).
##
## Die KayKit-Figuren haben starre Augen (kleine schwarze Kapseln im Kopf-Mesh) und keinen Mund. Diese Ebene
##  * versenkt die Original-Augen einmalig in einer Kopie des Kopf-Meshs (das Mesh des Spiels bleibt unberührt),
##  * hängt eigene Augen, Glanzpunkte und einen Mund an den Kopfknochen (die Brauen der Figuren bleiben) und
##  * formt sie jedes Bild aus wenigen Parametern neu: Lidschlag, zusammengekniffene Lachaugen, große Staune-Augen,
##    Blickrichtung, schräg gestellte Lider (besorgt, entschlossen), Mundbreite, -öffnung, -krümmung, runde Staune-Form, Zähne, Zunge.
## Ausdrücke sind Parametersätze (EXPR); die Regie wechselt sie, das Gesicht gleitet weich dorthin. Lachen und Kauen
## bewegen den Mund rhythmisch, geblinzelt wird von selbst.

const EXPR := {
	"neutral": {"curve": 0.25},
	"smile": {"curve": 0.85, "squint": 0.25, "brow": 0.2},
	"grin": {"curve": 1.0, "open": 0.28, "squint": 0.45, "brow": 0.3},
	"laugh": {"curve": 1.0, "open": 0.62, "squint": 0.92, "brow": 0.55},
	"awe": {"wide": 1.0, "brow": 1.0, "open": 0.42, "round": 1.0, "curve": 0.0},
	"surprised": {"wide": 1.0, "brow": 1.0, "open": 0.3, "round": 0.8, "curve": 0.0},
	"curious": {"brow": 0.6, "asym": 1.0, "open": 0.08, "round": 0.5, "curve": 0.15, "wide": 0.3},
	"scared": {"wide": 0.9, "brow": 0.8, "tilt": 0.9, "open": 0.5, "curve": -0.6, "width": 1.15},
	"worried": {"tilt": 0.8, "brow": 0.3, "curve": -0.4},
	"determined": {"tilt": -0.8, "brow": -0.3, "curve": 0.2, "lid": 0.15},
	"sleepy": {"lid": 0.55, "brow": -0.2, "curve": 0.0},
	"asleep": {"lid": 1.0, "open": 0.14, "round": 0.6, "curve": 0.0, "brow": -0.1},
	"pant": {"open": 0.48, "round": 0.35, "tilt": 0.6, "lid": 0.2, "curve": -0.2},
	"ouch": {"lid": 1.0, "tilt": -0.6, "brow": -0.4, "open": 0.3, "curve": -0.8, "width": 1.2},
	"sad": {"tilt": 0.9, "curve": -0.8, "lid": 0.2},
	"smug": {"lid": 0.35, "curve": 0.7, "asym": 1.0, "brow": 0.2},
	"dreamy": {"lid": 0.3, "curve": 0.6, "brow": 0.3},
	"plead": {"wide": 0.8, "brow": 0.7, "tilt": 0.9, "curve": 0.35},
}
const KEYS := ["lid", "squint", "wide", "brow", "tilt", "asym", "open", "curve", "width", "round"]
const SEG := 12

var laugh := 0.0          # 0..1 – Mund geht im Lachrhythmus auf und zu (Phase kommt vom Körper)
var laugh_phase := 0.0
var chew := 0.0           # 0..1 – Kaubewegung
var gaze := Vector2.ZERO  # Blickrichtung der Augen (−1..1)
var blink_on := true

var _cur := {}
var _tgt := {}
var _tau := 0.1
var _eye_c: Array[Vector3] = [Vector3(-0.188, 1.585, 0.448), Vector3(0.188, 1.585, 0.448)]
var _eye_r := Vector2(0.052, 0.044)
var _mouth_c := Vector3(0, 1.43, 0.46)
var _im: ImmediateMesh
var _mat := {}
var _blink_t := 2.0
var _blink := 0.0
var _t := 0.0


func setup(rig: CharacterRig) -> void:
	for k in KEYS:
		_cur[k] = 0.0
		_tgt[k] = 0.0
	_cur.width = 1.0
	set_expr("neutral", 0.0)
	var sk := rig.skel
	var hb := sk.find_bone("head")
	_hide_original_eyes(rig)
	var att := BoneAttachment3D.new()
	att.bone_name = "head"
	sk.add_child(att)
	att.add_child(self)
	transform = sk.get_bone_global_rest(hb).affine_inverse()   # lokale Koordinaten = Skelett-Raum in Ruhepose
	_im = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _im
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("gfx_tuned", true)
	add_child(mi)
	for e in [["eye", Color("#14181c"), 0.25], ["white", Color("#ffffff"), 0.4], ["cavity", Color("#3a1216"), 0.9],
			["teeth", Color("#f6f1e6"), 0.6], ["tongue", Color("#e0707a"), 0.7]]:
		var m := StandardMaterial3D.new()
		m.albedo_color = e[1]
		m.roughness = e[2]
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat[e[0]] = m
	_blink_t = randf_range(1.0, 4.0)


## Original-Augen (dunkle, bläuliche Kapseln) in einer eigenen Mesh-Kopie in den Kopf schieben und dabei vermessen;
## außerdem die Gesichtsfläche auf Mundhöhe abtasten, damit der Mund bei jeder Figur knapp vor der Haut sitzt.
func _hide_original_eyes(rig: CharacterRig) -> void:
	for n in Assets.find_meshes(rig):
		var mi := n as MeshInstance3D
		if not String(mi.name).ends_with("_Head") or mi.mesh == null:
			continue
		var mat := mi.get_active_material(0) as BaseMaterial3D
		if mat == null or mat.albedo_texture == null:
			return
		var img := mat.albedo_texture.get_image()
		if img.is_compressed():
			img.decompress()
		var arr := mi.mesh.surface_get_arrays(0)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var mn := [Vector3.INF, Vector3.INF]
		var mx := [-Vector3.INF, -Vector3.INF]
		var found := 0
		for i in vs.size():
			var c := img.get_pixel(clampi(int(fposmod(uv[i].x, 1.0) * img.get_width()), 0, img.get_width() - 1),
				clampi(int(fposmod(uv[i].y, 1.0) * img.get_height()), 0, img.get_height() - 1))
			var v := vs[i]
			if c.get_luminance() < 0.2 and c.g - c.r > 0.008 and v.z > 0.25 and absf(v.x) < 0.3 and v.y > 1.45 and v.y < 1.75:
				var sd := 0 if v.x < 0.0 else 1
				mn[sd] = (mn[sd] as Vector3).min(v)
				mx[sd] = (mx[sd] as Vector3).max(v)
				vs[i] = Vector3(v.x * 0.5, v.y, v.z - 0.22)
				found += 1
		if found < 8:
			return
		for sd in 2:
			var a: Vector3 = mn[sd]
			var b: Vector3 = mx[sd]
			_eye_c[sd] = Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, b.z + 0.004)
			_eye_r = Vector2((b.x - a.x) * 0.5 + 0.004, (b.y - a.y) * 0.5 + 0.004)
		# Gesichtsfläche auf Mundhöhe: vorderster Punkt in der Mitte
		var my := _eye_c[0].y - 0.158
		var front := -INF
		for v2 in vs:
			if absf(v2.x) < 0.13 and absf(v2.y - my) < 0.05:
				front = maxf(front, v2.z)
		_mouth_c = Vector3(0, my, (front if front > 0.2 else _eye_c[0].z) + 0.008)
		arr[Mesh.ARRAY_VERTEX] = vs
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(0, mi.mesh.surface_get_material(0))
		mi.mesh = am
		return


## Ausdruck wechseln; secs = wie schnell das Gesicht dorthin gleitet.
func set_expr(name: String, secs := 0.16) -> void:
	var e: Dictionary = EXPR.get(name, EXPR.neutral)
	for k in KEYS:
		_tgt[k] = float(e.get(k, 1.0 if k == "width" else 0.0))
	_tau = maxf(secs, 0.001) / 2.5
	if secs <= 0.0:
		for k in KEYS:
			_cur[k] = _tgt[k]


func _process(delta: float) -> void:
	_t += delta
	var f := 1.0 - exp(-delta / _tau)
	for k in KEYS:
		_cur[k] = lerpf(_cur[k], _tgt[k], f)
	# Lidschlag: zu in 60 ms, auf in 110 ms; nicht beim Lachen oder Schlafen
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink_t = randf_range(2.2, 5.0)
		if blink_on and float(_tgt.squint) < 0.6 and float(_tgt.lid) < 0.8:
			_blink = 1.0
	var bl := 0.0
	if _blink > 0.0:
		_blink = maxf(0.0, _blink - delta / 0.17)
		bl = sin(clampf(1.0 - _blink, 0.0, 1.0) * PI)
	_draw(bl)


func _draw(bl: float) -> void:
	_im.clear_surfaces()
	var lid := clampf(maxf(float(_cur.lid), bl), 0.0, 1.0)
	var squint := clampf(float(_cur.squint) + laugh * 0.4, 0.0, 1.0)
	var wide := float(_cur.wide)
	var a := _eye_r.x * (1.0 + 0.2 * wide)
	var b := _eye_r.y * (1.0 + 0.28 * wide + 0.1 * float(_cur.brow))
	var g := Vector3(gaze.x * 0.012, gaze.y * 0.008, 0.0)
	# --- Augen ---
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat.eye)
	for sd in 2:
		var c := _eye_c[sd] + g
		for k in SEG:
			var x0 := -1.0 + 2.0 * k / SEG
			var x1 := -1.0 + 2.0 * (k + 1) / SEG
			var inner := 1.0 if sd == 0 else -1.0   # zur Nase hin
			var ld := clampf(lid + (float(_cur.asym) * 0.3 if sd == 1 else 0.0), 0.0, 1.0)
			var t0 := _eye_top(x0, b, ld, x0 * inner)
			var t1 := _eye_top(x1, b, ld, x1 * inner)
			var b0 := _eye_bot(x0, b, ld, squint, t0)
			var b1 := _eye_bot(x1, b, ld, squint, t1)
			_quad(c + Vector3(x0 * a, t0, 0), c + Vector3(x1 * a, t1, 0), c + Vector3(x1 * a, b1, 0), c + Vector3(x0 * a, b0, 0))
	_im.surface_end()
	# --- Glanzpunkte (nur bei offenen Augen) ---
	if lid < 0.5 and squint < 0.55:
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat.white)
		for sd in 2:
			var hc := _eye_c[sd] + g + Vector3(-a * 0.28 + gaze.x * a * 0.2, b * 0.38 - lid * b * 0.5, 0.002)
			var r := 0.011 + 0.004 * wide
			for k in 8:
				var a0 := TAU * k / 8.0
				var a1 := TAU * (k + 1) / 8.0
				_tri(hc, hc + Vector3(cos(a0), sin(a0), 0) * r, hc + Vector3(cos(a1), sin(a1), 0) * r)
		_im.surface_end()
	# --- Mund ---
	var open := clampf(float(_cur.open) + laugh * (0.18 + 0.3 * (0.5 + 0.5 * sin(laugh_phase))), 0.0, 1.0)
	var curve := float(_cur.curve)
	var rnd := float(_cur.round)
	var w := 0.098 * float(_cur.width) * lerpf(1.0 + 0.12 * maxf(curve, 0.0), 0.45, rnd) * (1.0 + 0.1 * sin(_t * 9.0) * chew)
	if chew > 0.0:
		open = maxf(open * (1.0 - chew), 0.0)
		curve = lerpf(curve, 0.35 + 0.25 * sin(_t * 9.0), chew)
	var hu := 0.009 + open * lerpf(0.016, 0.05, rnd)       # Oberlippe: beim Lachen fast gerade, beim Staunen rund
	var hl := 0.009 + open * lerpf(0.085, 0.05, rnd)
	var top: Array[Vector3] = []
	var bot: Array[Vector3] = []
	for k in SEG + 1:
		var x := -1.0 + 2.0 * k / SEG
		var bell := pow(maxf(1.0 - x * x, 0.0), lerpf(0.75, 0.5, rnd))
		var yc := curve * 0.05 * (x * x - 0.45)
		top.append(_mouth_c + Vector3(x * w, yc + hu * bell, 0))
		bot.append(_mouth_c + Vector3(x * w, yc - hl * bell, 0))
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat.cavity)
	for k in SEG:
		_quad(top[k], top[k + 1], bot[k + 1], bot[k])
	_im.surface_end()
	if open > 0.22:
		var zo := Vector3(0, 0, 0.002)
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat.teeth)
		for k in range(2, SEG - 2):
			var d0 := (top[k] - bot[k]) * 0.26
			var d1 := (top[k + 1] - bot[k + 1]) * 0.26
			_quad(top[k] + zo, top[k + 1] + zo, top[k + 1] - d1 + zo, top[k] - d0 + zo)
		_im.surface_end()
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat.tongue)
		for k in range(3, SEG - 3):
			var e0 := (top[k] - bot[k]) * 0.36
			var e1 := (top[k + 1] - bot[k + 1]) * 0.36
			_quad(bot[k] + e0 + zo, bot[k + 1] + e1 + zo, bot[k + 1] + zo, bot[k] + zo)
		_im.surface_end()


## Oberkante des Auges: Bogen, vom Oberlid gekappt. Das Lid steht schräg, wenn tilt ≠ 0:
## innen hoch/außen tief = besorgt (tilt > 0), innen tief = entschlossen, grimmig (tilt < 0). xi = +1 an der Nase.
func _eye_top(x: float, b: float, lid: float, xi: float) -> float:
	var tl := float(_cur.tilt)
	var cap := b * (1.0 - 1.15 * lid - 0.3 * absf(tl) + 0.55 * tl * xi)
	return minf(b * sqrt(maxf(1.0 - x * x, 0.0)), cap)


func _eye_bot(x: float, b: float, lid: float, squint: float, top: float) -> float:
	var arc := b * sqrt(maxf(1.0 - x * x, 0.0))
	var open_bot := maxf(-arc, -b * (1.0 - 0.75 * lid))   # das Unterlid kommt dem Oberlid entgegen
	# Lachaugen: der Unterrand folgt dem oberen Bogen – übrig bleibt eine Sichel „∩“
	var y := lerpf(open_bot, arc - 0.02, squint)
	return minf(y, top - 0.011)


func _quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	_tri(p0, p1, p2)
	_tri(p0, p2, p3)


func _tri(p0: Vector3, p1: Vector3, p2: Vector3) -> void:
	_im.surface_set_normal(Vector3(0, 0.15, 1).normalized())
	_im.surface_add_vertex(p0)
	_im.surface_set_normal(Vector3(0, 0.15, 1).normalized())
	_im.surface_add_vertex(p1)
	_im.surface_set_normal(Vector3(0, 0.15, 1).normalized())
	_im.surface_add_vertex(p2)
