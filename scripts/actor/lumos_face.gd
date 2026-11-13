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
	# — 1.5.2: erweitertes Gefühlsspektrum (Verhalten in LumosEmotion.META, Haltung in LumosBody.POSTURE) —
	"delight": {"curve": 1.0, "open": 0.62, "wide": 0.5, "brow": 0.8, "squint": 0.15, "blush": 0.5},
	"euphoria": {"curve": 1.0, "open": 0.85, "squint": 0.8, "brow": 1.0, "blush": 0.9, "width": 1.15},
	"pride": {"curve": 0.6, "smirk": 0.35, "lid": 0.22, "brow": 0.25, "asym": 0.2},
	"relief": {"curve": 0.45, "lid": 0.4, "brow": 0.3, "tilt": 0.35, "open": 0.18, "round": 0.3},
	"content": {"curve": 0.55, "lid": 0.28, "squint": 0.2, "blush": 0.15},
	"affection": {"curve": 0.7, "squint": 0.4, "blush": 0.65, "tilt": 0.3, "lid": 0.15},
	"tender": {"curve": 0.6, "lid": 0.22, "tilt": 0.45, "blush": 0.3, "brow": 0.2},
	"playful": {"curve": 0.85, "smirk": 0.45, "asym": 0.5, "squint": 0.3, "brow": 0.5, "open": 0.12},
	"gloat": {"curve": 0.85, "smirk": 0.85, "lid": 0.38, "asym": 0.7, "tilt": -0.25, "open": 0.22, "squint": 0.2},
	"bashful": {"curve": 0.55, "blush": 1.0, "lid": 0.32, "tilt": 0.45, "smirk": 0.2, "press": 0.2},
	"disappointed": {"curve": -0.65, "lid": 0.38, "tilt": 0.6, "brow": 0.1, "pout": 0.35},
	"fear": {"wide": 0.9, "sclera": 0.8, "pupil": 0.62, "brow": 0.8, "tilt": 0.9, "open": 0.35, "curve": -0.5, "tremble": 0.35},
	"panic": {"wide": 1.0, "sclera": 1.0, "pupil": 0.45, "brow": 1.0, "tilt": 1.0, "open": 0.92, "round": 0.45, "curve": -0.7,
		"width": 1.2, "tremble": 0.5},
	"anger": {"tilt": -1.0, "brow": -0.6, "curve": -0.6, "lid": 0.2, "open": 0.42, "width": 1.25, "cheek": 0.15},
	"frustrated": {"tilt": -0.65, "brow": -0.45, "press": 0.75, "curve": -0.45, "lid": 0.22, "cheek": 0.2},
	"jealous": {"lid": 0.38, "tilt": -0.3, "pout": 0.6, "asym": 0.5, "curve": -0.35},
	"shame": {"lid": 0.5, "tilt": 0.75, "curve": -0.45, "blush": 0.75, "press": 0.35},
	"insecure": {"tilt": 0.55, "brow": 0.3, "press": 0.45, "curve": -0.2, "lid": 0.1},
	"lonely": {"tilt": 0.75, "lid": 0.32, "curve": -0.55, "brow": 0.2, "tear": 0.15},
	"exhausted": {"lid": 0.55, "open": 0.45, "round": 0.3, "curve": -0.25, "tilt": 0.45},
	"surprise": {"wide": 1.0, "brow": 1.0, "open": 0.72, "round": 0.95, "curve": 0.0, "sclera": 0.55, "pupil": 0.8},
	"disbelief": {"wide": 0.5, "brow": 0.75, "asym": 0.65, "open": 0.28, "round": 0.5, "curve": -0.12, "lid": 0.1},
	"suspicious": {"lid": 0.45, "squint": 0.35, "tilt": -0.5, "asym": 0.7, "press": 0.5, "curve": -0.2},
	"embarrassed": {"blush": 1.0, "curve": 0.12, "press": 0.3, "tilt": 0.5, "lid": 0.3},
	"nervous": {"tilt": 0.6, "brow": 0.4, "press": 0.3, "curve": -0.12, "wide": 0.3, "sclera": 0.25, "tremble": 0.2},
	"compassion": {"tilt": 0.85, "brow": 0.45, "curve": 0.18, "lid": 0.15, "open": 0.06},
	"admiration": {"wide": 0.6, "brow": 0.7, "curve": 0.6, "open": 0.28, "round": 0.4, "blush": 0.35, "sclera": 0.3},
	"defiant": {"tilt": -0.5, "pout": 0.5, "lid": 0.22, "brow": -0.2, "curve": -0.3},
	"impatient": {"tilt": -0.3, "press": 0.55, "lid": 0.15, "curve": -0.22, "asym": 0.3},
	"focus": {"lid": 0.3, "squint": 0.25, "tilt": -0.4, "press": 0.6, "brow": -0.3},
	"pensive": {"lid": 0.25, "asym": 0.4, "press": 0.3, "curve": 0.0, "brow": 0.2},
	"teasing": {"curve": 0.85, "smirk": 0.75, "asym": 0.8, "brow": 0.5, "squint": 0.3, "open": 0.2},
	# — Cartoon-Gesichter —
	"cry": {"lid": 0.7, "squint": 0.6, "tilt": 1.0, "open": 0.9, "round": 0.2, "curve": -1.0, "width": 1.25, "tear": 1.0,
		"tremble": 0.6, "blush": 0.4},
	"love": {"curve": 0.8, "squint": 0.55, "blush": 1.0, "lid": 0.2, "tilt": 0.3},
	"puppy": {"wide": 0.9, "brow": 0.75, "tilt": 0.95, "curve": 0.3, "sclera": 0.7, "pupil": 1.35, "tear": 0.3, "pout": 0.3},
	"sulk": {"pout": 0.8, "tilt": -0.3, "lid": 0.3, "curve": -0.4, "cheek": 0.25},
	"puffed": {"cheek": 1.0, "tilt": -0.9, "brow": -0.6, "lid": 0.2, "press": 0.8, "blush": 0.6},
	"dizzy": {"lid": 0.3, "asym": 0.6, "open": 0.35, "round": 0.5, "curve": -0.1, "cross": 0.5},
	"cross_eyed": {"cross": 1.0, "wide": 0.4, "open": 0.2, "round": 0.6},
	"sleep_smile": {"lid": 1.0, "curve": 0.5, "open": 0.05},
}
const KEYS := ["lid", "squint", "wide", "brow", "tilt", "asym", "open", "curve", "width", "round", "blush",
	"pout", "press", "tremble", "cheek", "sclera", "pupil", "tear", "smirk", "cross"]
const ONE_KEYS := ["width", "pupil"]   ## Grundwert 1 statt 0
## Mundaktionen (kurze Hüllkurven über dem Ausdruck): Dauer in s
const MOUTH_ACTIONS := {"yawn": 2.2, "sigh": 1.1, "swallow": 0.45, "gasp": 0.7, "sob": 1.6, "snicker": 1.2, "smack": 0.5,
	"chatter": 1.2, "pant": 2.0, "press": 0.8}
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
var gaze_target := Vector2(INF, INF)   # gesetzt = Augen springen schnell dorthin (Sakkade), sonst gilt gaze direkt
var talk := 0.0           # 0..1 – Lippen bewegen sich silbenweise (Sprechen ohne Ton, später Dialog-System)
var blink_mult := 1.0     # Lidschlag-Häufigkeit (Gefühl: nervös > 1, konzentriert < 1)
var blink_slow := 1.0     # Lidschlag-Dauer (müde > 1)
var rng := RandomNumberGenerator.new()

var _cur := {}
var _tgt := {}
var _tau := 0.1
var _m := {}              # Vermessung: eye_c (Array), eye_r (Vector2), mouth (Vector3), u (Kopfbreite), grid …
var _im: ImmediateMesh
var _cur_n := Vector3.INF       # zuletzt gesetzte Normale der offenen Fläche
var _nv := 0                    # Punkte in der offenen Fläche
var _u := 1.0                   # Kopfbreite (aus _m.u, beim Zeichnen gesetzt)
var _tilt := 0.0                # Lidneigung (aus _cur.tilt, beim Zeichnen gesetzt)
var draws := 0                  # Neuzeichnungen (Messung: wie ereignisgesteuert das Gesicht arbeitet)
var _inp := PackedFloat32Array()  # Eingänge des Zeichnens in diesem Bild …
var _drawn := PackedFloat32Array()  # … und beim letzten Neuzeichnen
var _drawn_mask := -1             # Schaltpunkte beim letzten Neuzeichnen
## Sichtbarkeitsschwelle des Neuzeichnens in Bildpunkten (0 = bei jeder Änderung, wie vor 1.5.2 – Referenz für den
## Bildvergleich im Performance-Labor).
static var vis_px := 0.25
static var expr_rev := 0          ## Zähler für Änderungen an Ausdrücken zur Laufzeit
var _mat := {}
var _blink_t := 2.0
var _blink := 0.0
var _flash := 0.0
var _t := 0.0
var _lod_acc := 0.0
var paused := false              # LOD: außerhalb des Bildes nicht aktualisieren
var blinks := 0                  # Zähler (Tests)
var _blink_dur := 0.16
var _blink2 := -1.0              # zweiter Lidschlag (Doppelblinzeln)
var _act := ""                   # laufende Mundaktion
var _act_t := 0.0
var _act_d := 1.0
var _syl_t := 0.0                # Sprech-Silben
var _syl := Vector3.ZERO         # aktuelle Silbe: (Öffnung, Rundung, Breite)
var _syl_to := Vector3.ZERO


## Baut die Ebene. false = Modell ungeeignet (kein Kopf-Mesh, keine erkennbaren Augen) – die Figur bleibt unverändert.
func setup(rig: CharacterRig) -> bool:
	if rig == null or rig.model == null:
		return false
	for k in KEYS:
		_cur[k] = 1.0 if k in ONE_KEYS else 0.0
		_tgt[k] = _cur[k]
	_blink_t = rng.randf_range(0.6, 3.0)
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
			["blush", Color("#ff7a8a"), 0.9, 0.55], ["tear", Color("#9fd8ff"), 0.15, 0.78], ["lip", Color("#c95c66"), 0.7, 1.0],
			["cheek", (_m.get("skin", Color(0.95, 0.75, 0.6)) as Color).lightened(0.12), 0.8, 1.0]]:
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
	_blink_t = rng.randf_range(1.0, 4.0)   # eigener, geseedeter Zufall: bildgenau wiederholbar
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
	# Wangenfarbe (unter den Augen – dort ist sicher Haut, auch bei Bart) und Gesichtsbehaarung um den Mund
	var cheek_col := skin
	var hist2 := {}
	var best2 := 0
	for i in vs.size():
		var dxc := absf(vs[i].x - cx)
		if dxc > 0.05 * u and dxc < 0.2 * u and vs[i].y < eye_y - 0.05 * u and vs[i].y > eye_y - 0.12 * u and vs[i].z > front - 0.2 * bb.size.z:
			var ck2: Color = px.call(i)
			var key2 := ck2.to_html(false).substr(0, 4)
			hist2[key2] = int(hist2.get(key2, 0)) + 1
			if int(hist2[key2]) > best2:
				best2 = int(hist2[key2])
				cheek_col = ck2
	var hair := func(y0: float, y1: float) -> float:
		var n_all := 0
		var n_h := 0
		for i in vs.size():
			if absf(vs[i].x - cx) < 0.1 * u and vs[i].y > y0 and vs[i].y < y1 and vs[i].z > front - 0.15 * bb.size.z:
				n_all += 1
				var c5: Color = px.call(i)
				if absf(c5.r - cheek_col.r) + absf(c5.g - cheek_col.g) + absf(c5.b - cheek_col.b) > 0.35:
					n_h += 1
		return float(n_h) / float(n_all) if n_all >= 4 else 0.0
	var mouth_y := eye_y - 0.16 * u
	var stache: bool = float(hair.call(mouth_y + 0.005 * u, mouth_y + 0.06 * u)) > 0.45   # Schnurrbart über dem Mund
	var beard: bool = float(hair.call(mouth_y - 0.14 * u, mouth_y - 0.03 * u)) > 0.5      # Bart unter dem Mund
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
		"mouth": Vector3(cx, eye_y - 0.16 * u - (0.032 * u if stache else 0.0), 0.0), "gx0": gx0, "gy0": gy0, "g": g, "nx": nx, "ny": ny,
		"depth": depth, "front": front, "skin": cheek_col, "stache": stache, "beard": beard}
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
		var base := 1.0 if k in ONE_KEYS else 0.0
		_tgt[k] = lerpf(float(n.get(k, base)), float(e.get(k, base)), clampf(intensity, 0.0, 1.0))
	_tau = maxf(secs, 0.001) / 2.5
	if secs <= 0.0:
		for k in KEYS:
			_cur[k] = _tgt[k]
	if name != current:
		current = name
		expression_changed.emit(name)


## Zielwerte direkt setzen (LumosEmotion mischt die Gefühle; das Gesicht gleitet in secs hinüber).
func set_params(params: Dictionary, secs := 0.06) -> void:
	for k: String in params:
		if _tgt.has(k):
			_tgt[k] = float(params[k])
	_tau = maxf(secs, 0.001) / 2.5


## Kurze Mundaktion über dem Ausdruck: yawn, sigh, swallow, gasp, sob, snicker, smack, chatter, pant, press.
func mouth_action(id: String, secs := -1.0) -> void:
	if not MOUTH_ACTIONS.has(id):
		return
	_act = id
	_act_t = 0.0
	_act_d = secs if secs > 0.0 else float(MOUTH_ACTIONS[id])


func mouth_action_running() -> String:
	return _act


## Großer Blicksprung: oft blinzelt man dabei (natürlich, nicht bei jedem).
func saccade(amount: float) -> void:
	if amount > 0.45 and _blink <= 0.0 and rng.randf() < 0.4:
		_start_blink()


func _start_blink() -> void:
	if not blink_on or float(_tgt.squint) > 0.6 or float(_tgt.lid) > 0.8:
		return
	_blink = 1.0
	_blink_dur = rng.randf_range(0.11, 0.2) * blink_slow
	blinks += 1
	if rng.randf() < 0.14:
		_blink2 = _blink_dur + rng.randf_range(0.06, 0.12)   # Doppelblinzeln


## Alias der Trailer-Schreibweise.
func set_expr(name: String, secs := 0.16) -> void:
	set_expression(name, secs)


func add_expression(name: String, params: Dictionary) -> void:
	expressions[name] = params
	expr_rev += 1   # zwischengespeicherte Mischwerte (LumosEmotion) neu aufbauen


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
	var prof := LumosProf.on
	var p0 := Time.get_ticks_usec() if prof else 0
	delta *= dt_scale
	_t += delta
	var f := 1.0 - exp(-delta / _tau)
	for k in KEYS:
		_cur[k] = lerpf(_cur[k], _tgt[k], f)
	_flash = move_toward(_flash, 0.0, delta * 1.4)
	if gaze_target.x != INF:
		gaze = gaze.lerp(gaze_target, 1.0 - exp(-delta / 0.035))   # Augen springen (Sakkade), der Kopf folgt später
	# Lidschlag: unregelmäßig (log-normal um ~3,4 s), Häufigkeit/Dauer je Gefühl, gelegentlich doppelt
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink_t = clampf(3.4 * exp(rng.randfn(0.0, 0.5)) / maxf(blink_mult, 0.1), 0.35, 11.0)
		_start_blink()
	if _blink2 > 0.0:
		_blink2 -= delta
		if _blink2 <= 0.0 and _blink <= 0.0:
			_blink = 1.0
			blinks += 1
	var bl := 0.0
	if _blink > 0.0:
		_blink = maxf(0.0, _blink - delta / _blink_dur)
		bl = sin(clampf(1.0 - _blink, 0.0, 1.0) * PI)
	if _act != "":
		_act_t += delta
		if _act_t >= _act_d:
			_act = ""
	if talk > 0.01:
		_syl_t -= delta
		if _syl_t <= 0.0:   # nächste Silbe: Öffnung, Rundung, Breite – mit Pausen wie beim Sprechen
			_syl_t = rng.randf_range(0.1, 0.21)
			_syl_to = Vector3(0.0, 0.0, 1.0) if rng.randf() < 0.16 else Vector3(rng.randf_range(0.2, 1.0), rng.randf_range(0.0, 0.7), rng.randf_range(0.85, 1.12))
		_syl = _syl.lerp(_syl_to, 1.0 - exp(-delta / 0.045))
	else:
		_syl = _syl.lerp(Vector3(0, 0, 1), 1.0 - exp(-delta / 0.06))
	# Neu zeichnen nur bei sichtbarer Änderung: obere Schranke der Verschiebung eines Punkts der Gesichtszüge seit
	# dem zuletzt gezeichneten Stand (in Kopfbreiten je Einheit: Blick 0,035, jeder andere Eingang 0,35 – größer als
	# jeder Faktor in _draw) × Bildgröße des Kopfs in Pixeln. Bleibt sie unter vis_px (¼ Pixel), ist der Unterschied
	# nicht sichtbar und das Gesicht bleibt stehen. Lachen, Kauen und Zittern gehen mit ihren Schwingungen ein (ein
	# ausklingendes Lachen hört auf zu zeichnen, sobald es unsichtbar wird); Mundaktionen und Tränen (Wellen, fallende
	# Tropfen) zeichnen jedes Bild. Ohne Kamera: bei jeder Änderung.
	var trem := float(_cur.tremble)
	var n_in := KEYS.size() + 15
	if _inp.size() != n_in:
		_inp.resize(n_in)
		_drawn.resize(n_in)
		_drawn.fill(INF)
	_inp[0] = gaze.x
	_inp[1] = gaze.y
	_inp[2] = bl
	_inp[3] = laugh
	_inp[4] = _flash
	_inp[5] = feature_scale
	_inp[6] = _syl.x * talk
	_inp[7] = _syl.y * talk
	_inp[8] = (_syl.z - 1.0) * talk
	_inp[9] = sin(laugh_phase) * laugh
	_inp[10] = chew
	_inp[11] = sin(_t * 9.0) * chew
	_inp[12] = sin(_t * 38.0) * trem * 0.0115   # Zittern der Augen (0,004 Kopfbreiten) …
	_inp[13] = sin(_t * 33.0) * trem * 0.08     # … der Mundwinkel …
	_inp[14] = sin(_t * 41.0) * trem * 0.0145   # … und der Unterlippe
	for ki in KEYS.size():
		_inp[15 + ki] = float(_cur[KEYS[ki]])
	var dmax := maxf(absf(_inp[0] - _drawn[0]), absf(_inp[1] - _drawn[1])) * 0.1
	for i in range(2, n_in):
		dmax = maxf(dmax, absf(_inp[i] - _drawn[i]))
	var anim := _act != "" or float(_cur.tear) > 0.05
	# Schaltpunkte in _draw (Element erscheint/verschwindet sprunghaft): jeder Wechsel zeichnet sofort neu
	var mask := _mask(bl, trem)
	_lod_acc += delta
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var period := 0.0
	var head_px := INF
	if cam:
		var hw := maxf(float(_m.u) * global_basis.get_scale().x, 0.01)
		var dist := cam.global_position.distance_to(global_position) / hw
		period = 0.0 if dist < 14.0 else (0.05 if dist < 40.0 else 0.2)   # nah: jedes Bild · mittel: 20 Hz · fern: 5 Hz
		var vh := get_viewport().get_visible_rect().size.y
		if cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
			head_px = vh * hw / maxf(cam.size, 0.001)
		else:
			head_px = vh / (2.0 * tan(deg_to_rad(cam.fov) * 0.5) * maxf(dist, 0.01))
	var visible_change := mask != _drawn_mask or (dmax > 0.0 and (dmax * 0.35 * head_px > vis_px or vis_px <= 0.0))
	if (anim or visible_change) and _lod_acc >= period:
		_lod_acc = 0.0
		_drawn_mask = mask
		var sw := _drawn
		_drawn = _inp
		_inp = sw
		var q := Time.get_ticks_usec() if prof else 0
		_draw(bl)
		if prof: LumosProf.add(&"face.draw", q)
	if prof: LumosProf.add(&"face", p0)


## Schaltpunkte von _draw als Bitmaske (gleiche Formeln wie dort): weiße Augen, Glanzpunkte, doppelter Glanz,
## Wangenröte, Backen, Zähne/Zunge, Grimasse, Schmolllippe.
func _mask(bl: float, trem: float) -> int:
	var scl := maxf(float(_cur.sclera), float(_cur.cross) * 0.85)
	var lid := clampf(maxf(float(_cur.lid), bl), 0.0, 1.0)
	var squint := clampf(float(_cur.squint) + laugh * 0.4, 0.0, 1.0)
	var pup := clampf(float(_cur.pupil), 0.3, 1.6)
	var cheek := float(_cur.cheek)
	var open := clampf(float(_cur.open) + laugh * (0.2 + 0.3 * (0.5 + 0.5 * sin(laugh_phase))) + _syl.x * talk * 0.55, 0.0, 1.0)
	var press := float(_cur.press)
	if cheek > 0.05:
		press = maxf(press, cheek)
	open *= 1.0 - press
	if chew > 0.0:
		open = maxf(open * (1.0 - chew), 0.0)
	var curve := float(_cur.curve) + sin(_t * 33.0) * 0.08 * trem
	return int(scl > 0.02) | int(lid < 0.5 and squint < 0.55) << 1 | int(pup > 1.15 and scl > 0.3) << 2 \
		| int(float(_cur.blush) + laugh * 0.3 > 0.03) << 3 | int(cheek > 0.05) << 4 | int(open > 0.2) << 5 \
		| int(curve < 0.0 and open > 0.05) << 6 | int(float(_cur.pout) > 0.1) << 7


func _draw(bl: float) -> void:
	_im.clear_surfaces()
	draws += 1
	var u: float = _m.u
	_u = u
	_tilt = float(_cur.tilt)
	var fs := feature_scale
	var eye_c: Array = _m.eye_c
	var er: Vector2 = _m.eye_r * 1.12 * fs
	var ae := sin(clampf(_act_t / _act_d, 0.0, 1.0) * PI) if _act != "" else 0.0   # Hüllkurve der Mundaktion
	var lid := clampf(maxf(float(_cur.lid), bl) + (ae * 0.85 if _act == "yawn" else 0.0), 0.0, 1.0)
	var squint := clampf(float(_cur.squint) + laugh * 0.4 + (ae * 0.4 if _act == "sob" else 0.0), 0.0, 1.0)
	var wide := float(_cur.wide) + (ae * 0.6 if _act == "gasp" else 0.0)
	var a := er.x * (1.0 + 0.22 * wide)
	var b := er.y * (1.0 + 0.3 * wide + 0.1 * float(_cur.brow))
	var cross := float(_cur.cross)
	var scl := maxf(float(_cur.sclera), cross * 0.85)   # weiße Augen mit Pupille (Schreck, Bettelblick, Schielen)
	var pup := clampf(float(_cur.pupil), 0.3, 1.6)
	var shake := sin(_t * 38.0) * float(_cur.tremble) * 0.004 * u
	var gz := Vector2(gaze.x * 0.012, gaze.y * 0.008) * u * (1.0 - scl)   # mit Lederhaut wandert nur die Pupille
	# --- Augen ---
	var eyes: Array = []
	_sb(_mat.white if scl > 0.02 else _mat.eye)
	for sd in 2:
		var c: Vector3 = eye_c[sd]
		var cx := c.x + gz.x + shake
		var cy := c.y + gz.y
		var inner := 1.0 if sd == 0 else -1.0
		var ld := clampf(lid + (float(_cur.asym) * 0.3 if sd == 1 else 0.0), 0.0, 1.0)
		var pe := _plane(cx, cy, a)
		eyes.append([cx, cy, ld, pe, inner])
		for k in SEG:
			var x0 := -1.0 + 2.0 * k / SEG
			var x1 := -1.0 + 2.0 * (k + 1) / SEG
			var t0 := _eye_top(x0, b, ld, x0 * inner)
			var t1 := _eye_top(x1, b, ld, x1 * inner)
			var b0 := _eye_bot(x0, b, ld, squint, t0, u)
			var b1 := _eye_bot(x1, b, ld, squint, t1, u)
			_quad_s(pe, cx + x0 * a, cy + t0, cx + x1 * a, cy + t1, cx + x1 * a, cy + b1, cx + x0 * a, cy + b0, 0.004)
	_se()
	var hl_c := []   # Mittelpunkte der Glanzpunkte
	if scl > 0.02:
		# Pupille im weißen Auge: klein vor Schreck, groß beim Bettelblick, wandert mit dem Blick und beim Schielen zur Nase
		_sb(_mat.eye)
		for sd in 2:
			var e: Array = eyes[sd]
			var ecx: float = e[0]
			var ecy: float = e[1]
			var eld: float = e[2]
			var ein: float = e[4]
			var pa := a * lerpf(1.0, 0.46, scl) * pup
			var pb := b * lerpf(1.0, 0.52, scl) * pup
			var px := ecx + gaze.x * a * 0.45 * scl + cross * ein * a * 0.42
			var py := ecy + gaze.y * b * 0.4 * scl
			hl_c.append(Vector3(px - pa * 0.3, py + pb * 0.38, pa))
			for k in SEG:
				var q0 := -1.0 + 2.0 * k / SEG
				var q1 := -1.0 + 2.0 * (k + 1) / SEG
				var ax0 := px + q0 * pa
				var ax1 := px + q1 * pa
				var xe0 := clampf((ax0 - ecx) / a, -1.0, 1.0)
				var xe1 := clampf((ax1 - ecx) / a, -1.0, 1.0)
				var et0 := _eye_top(xe0, b, eld, xe0 * ein)
				var et1 := _eye_top(xe1, b, eld, xe1 * ein)
				var tp0 := minf(py + pb * sqrt(maxf(1.0 - q0 * q0, 0.0)), ecy + et0)
				var tp1 := minf(py + pb * sqrt(maxf(1.0 - q1 * q1, 0.0)), ecy + et1)
				var bt0 := maxf(py - pb * sqrt(maxf(1.0 - q0 * q0, 0.0)), ecy + _eye_bot(xe0, b, eld, squint, et0, u))
				var bt1 := maxf(py - pb * sqrt(maxf(1.0 - q1 * q1, 0.0)), ecy + _eye_bot(xe1, b, eld, squint, et1, u))
				if tp0 > bt0 and tp1 > bt1:
					_quad_s(e[3], ax0, tp0, ax1, tp1, ax1, bt1, ax0, bt0, 0.0055)
		_se()
	else:
		for sd in 2:
			var e2: Array = eyes[sd]
			hl_c.append(Vector3(float(e2[0]) - a * 0.28 + gaze.x * a * 0.2, float(e2[1]) + b * 0.38 - lid * b * 0.5, a))
	# --- Glanzpunkte (nur bei offenen Augen; beim Bettelblick groß und doppelt) ---
	if lid < 0.5 and squint < 0.55:
		_sb(_mat.white if scl <= 0.02 else _mat.white)
		for sd in 2:
			var h: Vector3 = hl_c[sd]
			var r := (0.011 + 0.004 * wide) * u * fs * (lerpf(1.0, pup * 1.15, scl) if scl > 0.02 else 1.0)
			var spots: Array = [[h.x, h.y, r]]
			if pup > 1.15 and scl > 0.3:
				spots.append([h.x + r * 1.6, h.y - r * 1.4, r * 0.5])
			for sp in spots:
				var hx: float = sp[0]
				var hy: float = sp[1]
				var rr: float = sp[2]
				var ph := _plane(hx, hy, rr * 2.0)
				for k in 8:
					var a0 := TAU * k / 8.0
					var a1 := TAU * (k + 1) / 8.0
					_tri_s(ph, Vector2(hx, hy), Vector2(hx + cos(a0) * rr, hy + sin(a0) * rr), Vector2(hx + cos(a1) * rr, hy + sin(a1) * rr), 0.0075)
		_se()
	# --- Tränen: feuchter Lidrand, Bäche über die Wangen, fallende Tropfen ---
	var tear := float(_cur.tear)
	if tear > 0.05:
		_sb(_mat.tear)
		for sd in 2:
			var e3: Array = eyes[sd]
			var tx: float = float(e3[0]) - float(e3[4]) * a * 0.55
			var ty: float = float(e3[1]) - b * 0.55
			var tw := 0.012 * u * fs * (0.7 + 0.5 * tear)
			var ln := (0.05 + 0.17 * tear) * u
			var pt := _plane(tx, ty - ln * 0.5, maxf(ln, tw))
			for k in 6:
				var y0 := ty - ln * k / 6.0
				var y1 := ty - ln * (k + 1) / 6.0
				var wob0 := sin(_t * 5.0 + y0 * 40.0) * 0.004 * u
				var wob1 := sin(_t * 5.0 + y1 * 40.0) * 0.004 * u
				_quad_s(pt, tx - tw * 0.5 + wob0, y0, tx + tw * 0.5 + wob0, y0, tx + tw * 0.5 + wob1, y1, tx - tw * 0.5 + wob1, y1, 0.008)
			var dy := ty - ln - fmod(_t * 0.7 + sd * 0.37, 1.0) * 0.06 * u   # Tropfen am Ende des Bachs
			var dr := tw * 0.9
			for k in 8:
				var a4 := TAU * k / 8.0
				var a5 := TAU * (k + 1) / 8.0
				_tri_s(pt, Vector2(tx, dy), Vector2(tx + cos(a4) * dr, dy + sin(a4) * dr * 1.3), Vector2(tx + cos(a5) * dr, dy + sin(a5) * dr * 1.3), 0.0085)
		_se()
	# --- Wangenröte (Freude, Verlegenheit) ---
	var blush := float(_cur.blush) + laugh * 0.3
	if blush > 0.03:
		(_mat.blush as StandardMaterial3D).albedo_color.a = clampf(blush, 0.0, 1.0) * 0.55
		_sb(_mat.blush)
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
		_se()
	# --- aufgeblasene Backen (Wut, Trotz) ---
	var cheek := float(_cur.cheek)
	if cheek > 0.05:
		_sb(_mat.cheek)
		var mcp: Vector3 = _m.mouth
		for sd in 2:
			var cxp := mcp.x + (-0.115 if sd == 0 else 0.115) * u
			var cyp := mcp.y + 0.03 * u
			var rxp := 0.075 * u * fs * (0.5 + 0.6 * cheek)
			var ryp := 0.062 * u * fs * (0.5 + 0.6 * cheek)
			var pc := _plane(cxp, cyp, rxp)
			for k in 14:
				var a6 := TAU * k / 14.0
				var a7 := TAU * (k + 1) / 14.0
				_tri_s(pc, Vector2(cxp, cyp), Vector2(cxp + cos(a6) * rxp, cyp + sin(a6) * ryp), Vector2(cxp + cos(a7) * rxp, cyp + sin(a7) * ryp), 0.0095 + 0.01 * cheek)
		_se()
	# --- Brauen (nur wenn die Original-Brauen ersetzt wurden) ---
	if has_own_brows:
		_sb(_mat.brow)
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
		_se()
	# --- Mund: groß und rund, damit Gefühle auch von weitem lesbar sind ---
	var open := clampf(float(_cur.open) + laugh * (0.2 + 0.3 * (0.5 + 0.5 * sin(laugh_phase))) + _syl.x * talk * 0.55, 0.0, 1.0)
	var curve := float(_cur.curve)
	var rnd := clampf(float(_cur.round) + _syl.y * talk * 0.6, 0.0, 1.0)
	var pout := float(_cur.pout)
	var press := float(_cur.press)
	var smirk := float(_cur.smirk)
	var widf := float(_cur.width) * lerpf(1.0, _syl.z, talk)
	match _act:   # Mundaktionen über dem Ausdruck
		"yawn":
			open = maxf(open, ae)
			rnd = maxf(rnd, 0.65 * ae)
		"sigh":
			open = maxf(open, 0.3 * ae)
			rnd = maxf(rnd, 0.5 * ae)
		"swallow", "press":
			press = maxf(press, ae)
		"gasp":
			open = maxf(open, 0.9 * ae)
			rnd = maxf(rnd, 0.8 * ae)
		"sob":
			open = maxf(open, (0.35 + 0.5 * absf(sin(_act_t * 8.5))) * ae)
			curve = minf(curve, -0.8)
		"snicker":
			smirk = maxf(smirk, 0.7 * ae)
			open = maxf(open, (0.08 + 0.14 * absf(sin(_act_t * 17.0))) * ae)
		"smack":
			press = maxf(press, absf(sin(_act_t * 14.0)) * ae)
		"chatter":
			open = maxf(open, (0.12 + 0.1 * absf(sin(_act_t * 42.0))) * ae)
		"pant":
			open = maxf(open, (0.28 + 0.22 * sin(_act_t * 13.0)) * ae)
			rnd = maxf(rnd, 0.4 * ae)
	if cheek > 0.05:   # Backen voll Luft: Mund klein und zu
		press = maxf(press, cheek)
		widf *= 1.0 - 0.45 * cheek
	open *= 1.0 - press
	var trem := float(_cur.tremble)
	curve += sin(_t * 33.0) * 0.08 * trem
	var w := 0.125 * u * fs * widf * (1.0 + 0.45 * maxf(curve, 0.0) + 0.4 * open) * lerpf(1.0, 0.8, rnd) * (1.0 + 0.1 * sin(_t * 9.0) * chew) \
		* (1.0 - 0.42 * pout) * (1.0 + 0.06 * press)
	if chew > 0.0:
		open = maxf(open * (1.0 - chew), 0.0)
		curve = lerpf(curve, 0.35 + 0.25 * sin(_t * 9.0), chew)
	var hu := (0.015 * (1.0 - 0.55 * press) + open * lerpf(0.03, 0.12, rnd)) * u * fs
	var hl2 := (0.015 * (1.0 - 0.55 * press) + open * lerpf(0.22, 0.15, rnd) + 0.01 * pout) * u * fs + sin(_t * 41.0) * 0.005 * u * trem
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
		var yc := curve * 0.085 * u * fs * (x * x - 0.4) + smirk * 0.05 * u * fs * (x + 0.35 * x * x)
		top.append(Vector2(mc.x + x * w, mc.y + yc + hu * bell))
		bot.append(Vector2(mc.x + x * w, mc.y + yc - hl2 * bell))
	var pm := _plane(mc.x, mc.y - (hl2 - hu) * 0.5, maxf(w, 0.02 * u))
	_sb(_mat.cavity)
	for k in SEG:
		var m0 := (top[k] + bot[k]) * 0.5
		var m1 := (top[k + 1] + bot[k + 1]) * 0.5
		_quad_s(pm, top[k].x, top[k].y, top[k + 1].x, top[k + 1].y, m1.x, m1.y, m0.x, m0.y, 0.005)
		_quad_s(pm, m0.x, m0.y, m1.x, m1.y, bot[k + 1].x, bot[k + 1].y, bot[k].x, bot[k].y, 0.005)
	_se()
	if pout > 0.1:   # Schmollen: vorgeschobene Unterlippe
		_sb(_mat.lip)
		var lth := 0.016 * u * fs * pout
		for k in range(1, SEG - 1):
			_quad_s(pm, bot[k].x, bot[k].y, bot[k + 1].x, bot[k + 1].y, bot[k + 1].x, bot[k + 1].y - lth, bot[k].x, bot[k].y - lth, 0.0075)
		_se()
	if open > 0.2 or _act == "chatter":
		_sb(_mat.teeth)
		for k in range(2, SEG - 2):
			var d0 := (top[k] - bot[k]) * 0.24
			var d1 := (top[k + 1] - bot[k + 1]) * 0.24
			_quad_s(pm, top[k].x, top[k].y, top[k + 1].x, top[k + 1].y, top[k + 1].x - d1.x, top[k + 1].y - d1.y, top[k].x - d0.x, top[k].y - d0.y, 0.008)
		_se()
		_sb(_mat.tongue)
		for k in range(3, SEG - 3):
			var e0 := (top[k] - bot[k]) * 0.38
			var e1 := (top[k + 1] - bot[k + 1]) * 0.38
			_quad_s(pm, bot[k].x + e0.x, bot[k].y + e0.y, bot[k + 1].x + e1.x, bot[k + 1].y + e1.y, bot[k + 1].x, bot[k + 1].y, bot[k].x, bot[k].y, 0.008)
		_se()


## Oberkante des Auges: Bogen, vom Oberlid gekappt; tilt stellt das Lid schräg (besorgt > 0, grimmig < 0).
func _eye_top(x: float, b: float, lid: float, xi: float) -> float:
	var tl := _tilt
	var cap := b * (1.0 - 1.15 * lid - 0.3 * absf(tl) + 0.55 * tl * xi)
	return minf(b * sqrt(maxf(1.0 - x * x, 0.0)), cap)


func _eye_bot(x: float, b: float, lid: float, squint: float, top: float, u: float) -> float:
	var arc := b * sqrt(maxf(1.0 - x * x, 0.0))
	var open_bot := maxf(-arc, -b * (1.0 - 0.75 * lid))
	var y := lerpf(open_bot, arc - 0.026 * u, squint)   # Lachaugen: kräftige Sichel „∩“
	return minf(y, top - 0.012 * u)


## Viereck auf der Haut (Ecken als x/y-Paare) über der Fläche pl, off = Abstand darüber (Anteil der Kopfbreite).
## Gleiche Punkte wie zwei Dreiecke (p0 p1 p2, p0 p2 p3) – die vier Ecken werden nur einmal auf die Haut gelegt.
func _quad_s(pl: Array, x0: float, y0: float, x1: float, y1: float, x2: float, y2: float, x3: float, y3: float, off: float) -> void:
	var n: Vector3 = pl[6]
	if n != _cur_n:
		_im.surface_set_normal(n)
		_cur_n = n
	var o := off * _u
	var px: float = pl[0]
	var py: float = pl[1]
	var pz: float = pl[2]
	var sx: float = pl[3]
	var sy: float = pl[4]
	var k := 0.5 * float(pl[5])
	var dx := x0 - px
	var v0 := Vector3(x0, y0, pz + sx * dx + sy * (y0 - py) + k * dx * dx + o)
	dx = x1 - px
	var v1 := Vector3(x1, y1, pz + sx * dx + sy * (y1 - py) + k * dx * dx + o)
	dx = x2 - px
	var v2 := Vector3(x2, y2, pz + sx * dx + sy * (y2 - py) + k * dx * dx + o)
	dx = x3 - px
	var v3 := Vector3(x3, y3, pz + sx * dx + sy * (y3 - py) + k * dx * dx + o)
	_im.surface_add_vertex(v0)
	_im.surface_add_vertex(v1)
	_im.surface_add_vertex(v2)
	_im.surface_add_vertex(v0)
	_im.surface_add_vertex(v2)
	_im.surface_add_vertex(v3)
	_nv += 6


## Dreieck auf der Haut. Heißester Pfad des Gesichts (je Neuzeichnen einige hundert Aufrufe): Ebene einmal entpacken,
## Normale nur bei Wechsel setzen (ImmediateMesh behält sie für folgende Punkte), keine Zwischen-Arrays.
func _tri_s(pl: Array, p0: Vector2, p1: Vector2, p2: Vector2, off: float) -> void:
	var n: Vector3 = pl[6]
	if n != _cur_n:
		_im.surface_set_normal(n)
		_cur_n = n
	var o := off * _u
	var px: float = pl[0]
	var py: float = pl[1]
	var pz: float = pl[2]
	var sx: float = pl[3]
	var sy: float = pl[4]
	var k := 0.5 * float(pl[5])
	var dx := p0.x - px
	_im.surface_add_vertex(Vector3(p0.x, p0.y, pz + sx * dx + sy * (p0.y - py) + k * dx * dx + o))
	dx = p1.x - px
	_im.surface_add_vertex(Vector3(p1.x, p1.y, pz + sx * dx + sy * (p1.y - py) + k * dx * dx + o))
	dx = p2.x - px
	_im.surface_add_vertex(Vector3(p2.x, p2.y, pz + sx * dx + sy * (p2.y - py) + k * dx * dx + o))
	_nv += 3


## Fläche beginnen/beenden. Eine Fläche ohne Punkte (z. B. Pupille, während das Lid geschlossen ist) bekommt ein
## unsichtbares Null-Dreieck: ImmediateMesh ließe sie sonst offen, und die folgenden Gesichtsteile landeten für
## dieses Bild im Material der leeren Fläche.
func _sb(mat: Material) -> void:
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	_cur_n = Vector3.INF
	_nv = 0


func _se() -> void:
	if _nv == 0:
		_im.surface_set_normal(Vector3.BACK)
		for i in 3:
			_im.surface_add_vertex(Vector3.ZERO)
	_im.surface_end()
