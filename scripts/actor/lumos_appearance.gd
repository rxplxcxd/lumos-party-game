class_name LumosAppearance
extends RefCounted
## Aussehen und Verdeckung des Gesichts (Character Framework, ab 1.5.3; docs/CHARACTER_FRAMEWORK.md).
##
## Welche Gesichtsbereiche einer Figur sind sichtbar, eingeschränkt, teilweise verdeckt oder ausgeblendet – und warum?
##  * Quellen: alle Teile des Modells außer dem Kopf selbst (Helm, Visier, Hut, Kapuze, Maske, Brille, Kragen …), die
##    gemalte Gesichtsbehaarung aus der Textur des Kopfs (Bart, Schnurrbart) und Vorgaben – je Modell in OVERRIDES,
##    zur Laufzeit mit set_override().
##  * Vermessung einmal je Modell und Teil: Das Teil wird in Ruhepose in den Raum des Kopf-Meshs gelegt und auf das
##    Gesichtsraster projiziert (LumosFace, Rasterweite 0,025 Kopfbreiten). Ein Rasterpunkt gilt als verdeckt, sobald
##    das Teil dort vor oder auf der Haut liegt – auch knapp davor: Was das Gesicht dort zeichnet, stäche sonst hindurch.
##  * Bereiche augen, brauen, mund, wangen, traenen: Anteil verdeckter Punkte ≥ HIDE_AT → ausgeblendet (wird gar nicht
##    gezeichnet), ≥ PARTIAL_AT → teilweise verdeckt (gezeichnet; das Teil davor deckt den Rest ab).
##  * Mund-Grenzen (halbe Breite, nach oben, nach unten): bis zur ersten Stelle, an der die Haut nicht mehr nach vorn
##    zeigt (Kinn-Unterseite, Nase, Wangenrand), ein sichtbares Teil liegt oder – nach oben – ein gemalter Schnurrbart
##    beginnt. LumosFace staucht größere Ausdrücke weich in diese Grenzen; ist eine Grenze kleiner als ein breites
##    Lachen, gilt der Mund als eingeschränkt.
##  * Durchsichtige Teile (Material mit Transparenz: Brillengläser, Visier aus Glas) blenden nichts aus – der Bereich
##    gilt als teilweise verdeckt („hinter Glas“) und wird gezeichnet.
##  * Hände: Gesten am Kopf (Kratzen, Kinn, Stirn wischen, Gesicht verbergen …) greifen nicht in Helm, Hut oder
##    Maske. Sichtbare Kopf-Ausrüstung (Teile am Kopfknochen) liegt als Belegungsgitter vor (Voxel, VOX Kopfbreiten).
##    push_out() verfolgt den Strahl aus der Kopfmitte durch das Ziel der Hand: Liegt Ausrüstung näher als GAP_HAND
##    davor (oder steckt die Hand schon darin), wandert das Ziel bis hinter ihre Außenseite – die Hand kratzt am Helm
##    statt hindurch. Unter einer weit abstehenden Krempe bleibt Platz: dort ändert sich nichts. Ohne Ausrüstung
##    bleiben die Gesten unverändert.
##  * Laufzeit: refresh() (LumosFace alle 0,5 s) prüft, ob Teile ein- oder ausgeblendet wurden, und rechnet dann neu.
##  * Erweiterbar: add_item(mesh_instance, art) für Teile, die das Spiel später an den Kopf hängt (Mütze, Maske …).

enum { VISIBLE, RESTRICTED, PARTIAL, HIDDEN }
const STATE := ["sichtbar", "eingeschränkt", "teilweise verdeckt", "ausgeblendet"]
const REGIONS := ["augen", "brauen", "mund", "wangen", "traenen"]
const H_EYES := 1
const H_BROWS := 2
const H_MOUTH := 4
const H_CHEEKS := 8
const H_TEARS := 16
const REGION_BIT := {"augen": H_EYES, "brauen": H_BROWS, "mund": H_MOUTH, "wangen": H_CHEEKS, "traenen": H_TEARS}
const HIDE_AT := 0.6      ## Anteil verdeckter Rasterpunkte, ab dem ein Bereich ausgeblendet wird
const PARTIAL_AT := 0.12  ## … ab dem er als teilweise verdeckt gilt
## Art eines Teils aus seinem Namen (erste passende Silbe gewinnt; nur für Bericht und Vorgaben – verdeckt wird nach
## Geometrie, egal wie ein Teil heißt)
const KINDS := [["visor", "visier"], ["helmet", "helm"], ["mask", "maske"], ["glasses", "brille"], ["goggle", "brille"],
	["hood", "kapuze"], ["cape", "umhang"], ["cloak", "umhang"], ["hat", "hut"], ["cap", "hut"], ["crown", "hut"],
	["helm", "helm"], ["beard", "bart"], ["mustache", "schnurrbart"], ["moustache", "schnurrbart"], ["stache", "schnurrbart"],
	["scarf", "schal"], ["collar", "kragen"], ["hair", "haare"], ["body", "körper"], ["arm", "arm"], ["leg", "bein"]]
## Vorgaben je Modell, falls die Messung einmal danebenliegt: "bereiche": {Bereich: Zustand}, "teile": {Teil: Art oder
## "ignorieren"}, "mund": {"oben"/"unten"/"breite": Grenze in Kopfbreiten}. Bisher nicht nötig – alle sechs Helden
## werden richtig vermessen (CharLab --lab-face).
const OVERRIDES := {}
const STACHE_OVERLAP := 0.012   ## so weit (Kopfbreiten) darf die Oberlippe unter einen gemalten Schnurrbart reichen
const MIN_LIM := Vector3(0.07, 0.02, 0.03)   ## Mindestgrenzen des Munds (geschlossener Mund passt immer)
const WIDE_LAUGH := Vector3(0.2, 0.05, 0.2)  ## Ausmaß eines breiten Lachens (für „eingeschränkt“)

static var _cache := {}   ## Modell|Teil → Vermessung (verdeckte Rasterpunkte, Belegung, vorderste Fläche, Kopf-Anteil)


static func clear_cache() -> void:
	_cache.clear()
const VOX := 0.05             ## Kantenlänge der Ausrüstungs-Voxel (Kopfbreiten)
const GAP_HAND := 0.12        ## liegt Ausrüstung näher vor der Hand (Kopfbreiten), muss die Hand darüber
const HAND_R := 0.05          ## Abstand der Hand zur Außenseite der Ausrüstung (Kopfbreiten)

var items: Array = []         ## {node, name, kind, cells (PackedInt32Array), mask (PackedByteArray), visible, painted}
var regions := {}             ## Bereich → {state, covered, by}
var limits := Vector3(INF, INF, INF)   ## Mund: halbe Breite, nach oben, nach unten (Gesichtsraum)
var limit_by := {}            ## Mund-Grenze → was sie setzt (kinn, nase, wange, schnurrbart, Teilname …)
var hidden := 0               ## ausgeblendete Bereiche als Bitmaske (H_*)
var has_gear := false         ## sichtbare, undurchsichtige Kopf-Ausrüstung vorhanden (Hände weichen aus)
var rev := 0                  ## zählt jede Neuberechnung (LumosFace zeichnet dann sofort neu)
var center := Vector3.ZERO    ## Mitte des Kopf-Meshs (Gesichtsraum)
var _vx0 := Vector3.ZERO      ## Belegungsgitter der Kopf-Ausrüstung (Gesichtsraum): Ursprung, Kante, Größe, Zellen
var _vs := 1.0
var _vn := Vector3i.ONE
var _vox := PackedByteArray()
var _gfront := PackedFloat32Array()   ## vorderste Fläche sichtbarer Kopf-Ausrüstung je Rasterpunkt (−INF = keine)
var _sk: Skeleton3D
var _hb := -1
var overrides := {}           ## Laufzeit-Vorgaben: Bereich → Zustand
var _m := {}
var _key := ""
var _head: MeshInstance3D
var _root: Node
var _cells := {}              ## Bereich → Rasterpunkte (PackedInt32Array)
var _mask := PackedByteArray()


func setup(face: LumosFace, rig: CharacterRig, head: MeshInstance3D) -> void:
	_m = face.metrics()
	_key = rig.model_key
	_head = head
	_root = rig.model
	_sk = rig.skel
	_hb = _sk.find_bone("head") if _sk else -1
	if _m.is_empty() or not _m.has("bits"):
		return
	var hb := (_m.mesh as Mesh).get_aabb()
	center = hb.get_center()
	var u: float = _m.u
	_vs = VOX * u   # Gitter um den Kopf, oben Platz für hohe Hüte; gleich für alle Figuren desselben Modells
	_vx0 = hb.position - Vector3(0.75, 0.5, 0.75) * u
	var vsz := hb.size + Vector3(1.5, 1.8, 1.5) * u
	_vn = Vector3i(int(ceil(vsz.x / _vs)), int(ceil(vsz.y / _vs)), int(ceil(vsz.z / _vs)))
	var ov: Dictionary = OVERRIDES.get(_key, {})
	for st: String in (ov.get("bereiche", {}) as Dictionary):
		overrides[st] = STATE.find(String(ov.bereiche[st]))
	_region_cells()
	_painted()
	for mi in Assets.find_meshes(rig.model):
		if mi == head or mi.mesh == null or mi.mesh is ImmediateMesh or face.is_ancestor_of(mi):
			continue
		_add(mi, String((ov.get("teile", {}) as Dictionary).get(String(mi.name), "")), true)
	refresh(true)


## Teil nachträglich berücksichtigen (z. B. eine Mütze, die das Spiel an den Kopf hängt). kind: Art für den Bericht
## ("hut", "maske", "brille" …; leer = aus dem Namen). Wirkt ab dem nächsten refresh().
func add_item(mi: MeshInstance3D, kind := "") -> void:
	if mi and mi.mesh and not _m.is_empty():
		_add(mi, kind, false)
		refresh(true)


## Ziel einer Hand (Gesichtsraum) aus eng anliegender Kopf-Ausrüstung heraus.
##  * Vor dem Gesicht (über dem Gesichtsraster, nicht tiefer als 0,25 Kopfbreiten hinter der Haut): Liegt dort
##    Ausrüstung vor der Haut (Maske, Visier, Kinnschutz), kommt die Hand davor – + HAND_R vor ihre vorderste Fläche.
##  * Sonst (Scheitel, Seiten, Hinterkopf): Strahl aus der Kopfmitte durch p. Liegt Ausrüstung näher als GAP_HAND vor p
##    oder steckt p darin, wandert p bis hinter ihre Außenseite (+ HAND_R).
func push_out(p: Vector3) -> Vector3:
	if not has_gear:
		return p
	var u: float = _m.u
	if not _gfront.is_empty():
		var g: float = _m.g
		var nx: int = _m.nx
		var ny: int = _m.ny
		var i := int(roundf((p.x - float(_m.gx0)) / g))
		var j := int(roundf((p.y - float(_m.gy0)) / g))
		if i >= 0 and j >= 0 and i < nx and j < ny and p.z > (_m.depth as PackedFloat32Array)[j * nx + i] - 0.25 * u:
			var gz := -INF   # Hand ist breit: vorderste Fläche im Umkreis von einem Rasterpunkt
			for jj in range(maxi(j - 1, 0), mini(j + 1, ny - 1) + 1):
				for ii in range(maxi(i - 1, 0), mini(i + 1, nx - 1) + 1):
					gz = maxf(gz, _gfront[jj * nx + ii])
			if gz > -INF:
				return Vector3(p.x, p.y, maxf(p.z, gz + HAND_R * u))
			return p
	var d := p - center
	var l := d.length()
	if l < 1e-6:
		return p
	d /= l
	var step := _vs * 0.25
	var t := 0.0
	var hit := -1.0
	while t <= GAP_HAND * u:
		if _occ(p + d * t):
			hit = t
			break
		t += step
	if hit < 0.0:
		return p   # frei (oder Ausrüstung weit weg wie eine Hutkrempe): Geste unverändert
	t = hit
	while t < hit + u and _occ(p + d * t):
		t += step
	return p + d * (t + HAND_R * u)


func _occ(q: Vector3) -> bool:
	var f := (q - _vx0) / _vs
	var ix := int(floor(f.x))
	var iy := int(floor(f.y))
	var iz := int(floor(f.z))
	if ix < 0 or iy < 0 or iz < 0 or ix >= _vn.x or iy >= _vn.y or iz >= _vn.z or _vox.is_empty():
		return false
	return _vox[ix + iy * _vn.x + iz * _vn.x * _vn.y] != 0


## Teil wieder entfernen (z. B. Mütze abgenommen). Gelöschte Teile fallen beim nächsten refresh() von selbst heraus.
func remove_item(mi: MeshInstance3D) -> void:
	items = items.filter(func(e: Dictionary) -> bool: return e.painted or e.node != mi)
	refresh(true)


## Bereich fest vorgeben (Zustand VISIBLE … HIDDEN), -1 = wieder messen lassen.
func set_override(region: String, state: int) -> void:
	if state < 0:
		overrides.erase(region)
	else:
		overrides[region] = state
	refresh(true)


func state(region: String) -> int:
	return int((regions.get(region, {}) as Dictionary).get("state", VISIBLE))


## Sichtbarkeit der Teile prüfen; bei Änderung (oder force) Bereiche und Mund-Grenzen neu bestimmen. true = geändert.
func refresh(force := false) -> bool:
	if _m.is_empty() or not _m.has("bits"):
		return false
	var changed := force
	var gone := false
	for e: Dictionary in items:
		if e.painted:
			continue
		if not is_instance_valid(e.node):
			gone = true
			continue
		var on := (e.node as Node3D).is_visible_in_tree()
		if on != bool(e.visible):
			e.visible = on
			changed = true
	if gone:   # gelöschte Teile entfernen
		items = items.filter(func(e: Dictionary) -> bool: return e.painted or is_instance_valid(e.node))
		changed = true
	if not changed:
		return false
	_mask = (_m.bits as PackedByteArray).duplicate()
	has_gear = false
	_vox = PackedByteArray()
	_gfront = PackedFloat32Array()
	for e: Dictionary in items:
		if e.visible and not e.painted:
			var bit := LumosFace.CELL_GLASS if e.glass else LumosFace.CELL_COVER
			for c in (e.cells as PackedInt32Array):
				_mask[c] |= bit
			if e.head_gear and not e.glass and not (e.vox as PackedInt32Array).is_empty():
				if _vox.is_empty():
					_vox.resize(_vn.x * _vn.y * _vn.z)
				for c in (e.vox as PackedInt32Array):
					_vox[c] = 1
				has_gear = true
				var fz: PackedFloat32Array = e.front
				if not fz.is_empty():
					if _gfront.is_empty():
						_gfront.resize(fz.size())
						_gfront.fill(-INF)
					for c in fz.size():
						_gfront[c] = maxf(_gfront[c], fz[c])
	_scan_mouth()
	_eval()
	rev += 1
	return true


## Bericht für CharLab und Doku.
func summary() -> Dictionary:
	var u: float = _m.get("u", 1.0)
	var it := []
	for e: Dictionary in items:
		it.append({"teil": e.name, "art": e.kind, "sichtbar": e.visible, "gemalt": e.painted, "durchsichtig": e.get("glass", false),
			"am_kopf": e.get("head_gear", false), "kopf_anteil": snappedf(float(e.get("head_share", 0.0)), 0.01),
			"rasterpunkte": (e.cells as PackedInt32Array).size()})
	var rg := {}
	for r: String in REGIONS:
		var d: Dictionary = regions.get(r, {})
		rg[r] = {"zustand": STATE[int(d.get("state", VISIBLE))], "verdeckt": snappedf(float(d.get("covered", 0.0)), 0.01), "durch": d.get("by", [])}
	var over := {}   # wie weit Hände an typischen Stellen ausweichen (Kopfbreiten): Stirn, Scheitel, Wange, Kinn, vorm Gesicht
	if has_gear and _m.has("eye_c"):
		var ec: Array = _m.eye_c
		var ey := ((ec[0] as Vector3).y + (ec[1] as Vector3).y) * 0.5
		var mc: Vector3 = _m.mouth
		var fr: float = _m.front
		var top := center + Vector3(0.0, 0.5 * (_m.mesh as Mesh).get_aabb().size.y, 0.0)
		for e2: Array in [["stirn", Vector3(mc.x, ey + 0.12 * u, fr - 0.04 * u)], ["scheitel", top],
				["wange", Vector3(mc.x + 0.3 * u, mc.y + 0.05 * u, fr - 0.12 * u)], ["kinn", Vector3(mc.x, mc.y - 0.12 * u, fr - 0.06 * u)],
				["vorm_gesicht", Vector3(mc.x, ey - 0.05 * u, fr + 0.02 * u)]]:
			over[e2[0]] = snappedf(push_out(e2[1]).distance_to(e2[1]) / u, 0.001)
	return {"teile": it, "bereiche": rg, "ausruestung_ueberstand": over, "mund_grenzen": {"halbe_breite": snappedf(limits.x / u, 0.001), "oben": snappedf(limits.y / u, 0.001),
		"unten": snappedf(limits.z / u, 0.001), "gesetzt_durch": limit_by}}


# --- intern ---

func _add(mi: MeshInstance3D, kind: String, cache: bool) -> void:
	var nm := String(mi.name)
	var k := kind if kind != "" else _kind(nm)
	if k == "ignorieren":
		return
	var ck := _key + "|" + nm
	var d: Dictionary
	if cache and _cache.has(ck):
		d = _cache[ck]
	else:
		var share := _head_share(mi) if cache else 1.0   # nachträglich angehängt = am Kopf
		d = _cover(mi, share >= 0.8)
		d["head_share"] = share
		d["head_gear"] = share >= 0.8
		d["glass"] = _see_through(mi)
		if cache:
			_cache[ck] = d
	if (d.cells as PackedInt32Array).is_empty() and not d.head_gear:
		return   # liegt nirgends vor dem Gesicht und hängt nicht am Kopf (Beine, Arme, Umhang …)
	items.append({"node": mi, "name": nm, "kind": k, "cells": d.cells, "mask": _to_mask(d.cells), "vox": d.vox, "front": d.front, "head_gear": d.head_gear,
		"head_share": d.head_share, "glass": d.glass, "visible": mi.is_visible_in_tree(), "painted": false})


## Anteil der Punkte eines Teils, die überwiegend am Kopfknochen hängen (1 = bewegt sich starr mit dem Kopf).
func _head_share(mi: MeshInstance3D) -> float:
	if _sk == null or _hb < 0:
		return 0.0
	if mi.skin == null:
		var c: Node = mi.get_parent()
		while c != null and c != _root:
			if c is BoneAttachment3D:
				return 1.0 if (c as BoneAttachment3D).bone_name == _sk.get_bone_name(_hb) else 0.0
			c = c.get_parent()
		return 0.0
	var arr := mi.mesh.surface_get_arrays(0)
	if arr[Mesh.ARRAY_BONES] == null or arr[Mesh.ARRAY_WEIGHTS] == null:
		return 0.0
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var nv := (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	if nv == 0 or bones.size() < nv:
		return 0.0
	var per := bones.size() / nv
	var is_head := {}   # Bind → hängt am Kopfknochen oder an einem Knochen darunter (z. B. Feder eines wippenden Huts)
	for b in mi.skin.get_bind_count():
		var bn := mi.skin.get_bind_name(b)
		var bone := _sk.find_bone(bn) if bn != &"" else mi.skin.get_bind_bone(b)
		while bone >= 0 and bone != _hb:
			bone = _sk.get_bone_parent(bone)
		is_head[b] = bone == _hb and _hb >= 0
	var n := 0
	for v in nv:
		var w := 0.0
		for k in per:
			if is_head.get(bones[v * per + k], false):
				w += wts[v * per + k]
		if w >= 0.5:
			n += 1
	return float(n) / float(nv)


## Durchsichtig: jedes Material des Teils hat Transparenz (Brillenglas, Glasvisier).
static func _see_through(mi: MeshInstance3D) -> bool:
	for s in mi.mesh.get_surface_count():
		var m := mi.get_active_material(s) as BaseMaterial3D
		if m == null or (m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and m.albedo_color.a > 0.99):
			return false
	return mi.mesh.get_surface_count() > 0


static func _kind(nm: String) -> String:
	var l := nm.to_lower()
	for e: Array in KINDS:
		if l.contains(String(e[0])):
			return String(e[1])
	return "teil"


func _to_mask(cells: PackedInt32Array) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(int(_m.nx) * int(_m.ny))
	for c in cells:
		b[c] = 1
	return b


## Vermessung eines Teils (Ruhepose, Raum des Kopf-Meshs): Rasterpunkte des Gesichts, vor denen es liegt, und
## seine Belegung im Voxelgitter (für push_out). Teile, die nicht am Kopf hängen (Körper, Arme), bewegen sich gegen das
## Gesicht – sie zählen nur dort, wo die Haut nach vorn zeigt (ein hoher Kragen vor dem Kinn ja, Arme in der
## Ruhepose neben dem Kieferwinkel nicht).
func _cover(mi: MeshInstance3D, on_head: bool) -> Dictionary:
	var g: float = _m.g
	var gx0: float = _m.gx0
	var gy0: float = _m.gy0
	var nx: int = _m.nx
	var ny: int = _m.ny
	var u: float = _m.u
	var xf := _chain(_head).affine_inverse() * _chain(mi)
	var cz := PackedFloat32Array()
	cz.resize(nx * ny)
	cz.fill(-INF)
	var x1 := gx0 + (nx - 1) * g
	var y1 := gy0 + (ny - 1) * g
	var vox := PackedByteArray()   # Belegung (nur Teile am Kopf – andere bewegen sich gegen ihn)
	if on_head:
		vox.resize(_vn.x * _vn.y * _vn.z)
	for s in mi.mesh.get_surface_count():
		if mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue   # Linien/Punkte verdecken nichts (Grundkörper wie BoxMesh sind immer Dreiecke)
		var arr := mi.mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var tv := PackedVector3Array()
		tv.resize(vs.size())
		for i in vs.size():
			tv[i] = xf * vs[i]
		var ia: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var tri_n := ia.size() / 3 if ia.size() > 0 else tv.size() / 3
		for t in tri_n:
			var p0 := tv[ia[t * 3] if ia.size() > 0 else t * 3]
			var p1 := tv[ia[t * 3 + 1] if ia.size() > 0 else t * 3 + 1]
			var p2 := tv[ia[t * 3 + 2] if ia.size() > 0 else t * 3 + 2]
			if on_head:
				_voxelize(vox, p0, p1, p2)
			var lx := minf(p0.x, minf(p1.x, p2.x))
			var hx := maxf(p0.x, maxf(p1.x, p2.x))
			var ly := minf(p0.y, minf(p1.y, p2.y))
			var hy := maxf(p0.y, maxf(p1.y, p2.y))
			if hx < gx0 or lx > x1 or hy < gy0 or ly > y1:
				continue
			var den := (p1.y - p2.y) * (p0.x - p2.x) + (p2.x - p1.x) * (p0.y - p2.y)
			if absf(den) < 1e-12:
				continue
			for j in range(maxi(int(floor((ly - gy0) / g)), 0), mini(int(ceil((hy - gy0) / g)), ny - 1) + 1):
				for i in range(maxi(int(floor((lx - gx0) / g)), 0), mini(int(ceil((hx - gx0) / g)), nx - 1) + 1):
					var x := gx0 + i * g
					var y := gy0 + j * g
					var w0 := ((p1.y - p2.y) * (x - p2.x) + (p2.x - p1.x) * (y - p2.y)) / den
					var w1 := ((p2.y - p0.y) * (x - p2.x) + (p0.x - p2.x) * (y - p2.y)) / den
					var w2 := 1.0 - w0 - w1
					if w0 >= -0.02 and w1 >= -0.02 and w2 >= -0.02:
						cz[j * nx + i] = maxf(cz[j * nx + i], w0 * p0.z + w1 * p1.z + w2 * p2.z)
	var out := PackedInt32Array()
	var dep: PackedFloat32Array = _m.depth
	var bits: PackedByteArray = _m.bits
	var tol := 0.002 * u   # auch Teile, die die Haut nur berühren: Gesichtszüge liegen 0,4–1 % darüber
	var need := LumosFace.CELL_SKIN if on_head else LumosFace.CELL_SKIN | LumosFace.CELL_FRONT
	for c in nx * ny:
		if bits[c] & need == need and cz[c] > dep[c] - tol:
			out.append(c)
	var vl := PackedInt32Array()
	for c in vox.size():
		if vox[c]:
			vl.append(c)
	# vorderste Fläche je Rasterpunkt (nur Teile am Kopf): Hände vor dem Gesicht bleiben vor Maske, Visier, Kinnschutz
	return {"cells": out, "vox": vl, "front": cz if on_head else PackedFloat32Array()}


## Dreieck ins Belegungsgitter: dicht abgetastet (Abstand ≤ halbe Voxelkante), damit kein Strahl durch eine Lücke fällt.
func _voxelize(vox: PackedByteArray, a: Vector3, b: Vector3, c: Vector3) -> void:
	var e := maxf((b - a).length(), maxf((c - a).length(), (c - b).length()))
	var n := maxi(1, int(ceil(e / (_vs * 0.5))))
	var ab := (b - a) / n
	var ac := (c - a) / n
	var sx := _vn.x
	var sxy := _vn.x * _vn.y
	for i in n + 1:
		for j in n + 1 - i:
			var f := (a + ab * i + ac * j - _vx0) / _vs
			var ix := int(f.x)
			var iy := int(f.y)
			var iz := int(f.z)
			if f.x >= 0.0 and f.y >= 0.0 and f.z >= 0.0 and ix < _vn.x and iy < _vn.y and iz < _vn.z:
				vox[ix + iy * sx + iz * sxy] = 1


## Transformation eines Knotens bis zur Modellwurzel (ohne Szenenbaum – funktioniert auch vor dem Einhängen).
func _chain(n: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c := n
	while c != null and c != _root:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


## Gemalte Gesichtsbehaarung als eigene Einträge (verdeckt nichts, setzt aber die Grenze des Munds nach oben).
func _painted() -> void:
	var bits: PackedByteArray = _m.bits
	var mc: Vector3 = _m.mouth
	var u: float = _m.u
	for e: Array in [["Schnurrbart (gemalt)", "schnurrbart", 0.0, 0.1], ["Bart (gemalt)", "bart", -0.26, 0.0]]:
		var cells := PackedInt32Array()
		for c in bits.size():
			if bits[c] & LumosFace.CELL_HAIR:
				var p := _pos(c)
				if absf(p.x - mc.x) < 0.2 * u and p.y - mc.y > float(e[2]) * u and p.y - mc.y <= float(e[3]) * u:
					cells.append(c)
		if cells.size() >= 4:
			items.append({"node": null, "name": e[0], "kind": e[1], "cells": cells, "mask": _to_mask(cells), "visible": true, "painted": true})


func _pos(c: int) -> Vector2:
	var nx: int = _m.nx
	return Vector2(float(_m.gx0) + (c % nx) * float(_m.g), float(_m.gy0) + (c / nx) * float(_m.g))


## Rasterpunkte je Bereich (Ruhegröße der Züge, wie LumosFace sie zeichnet).
func _region_cells() -> void:
	var u: float = _m.u
	var ec: Array = _m.eye_c
	var er: Vector2 = (_m.eye_r as Vector2) * 1.12
	var mc: Vector3 = _m.mouth
	var by: float = float(_m.get("brow_y", 0.0))
	var eyes := PackedInt32Array()
	var brows := PackedInt32Array()
	var cheeks := PackedInt32Array()
	var tears := PackedInt32Array()
	var mouth := PackedInt32Array()
	var nxy: int = int(_m.nx) * int(_m.ny)
	for c in nxy:
		var p := _pos(c)
		for sd in 2:
			var e: Vector3 = ec[sd]
			var d := Vector2((p.x - e.x) / (er.x + 0.01 * u), (p.y - e.y) / (er.y + 0.01 * u))
			if d.length_squared() <= 1.0:
				eyes.append(c)
			var bo := (by if by > 0.0 else er.y + 0.03 * u)
			if absf(p.x - e.x) <= er.x * 1.45 and p.y - e.y >= bo - 0.02 * u and p.y - e.y <= bo + 0.04 * u:
				brows.append(c)
			var ck := Vector2((p.x - (e.x + (-0.075 if sd == 0 else 0.075) * u)) / (0.06 * u), (p.y - (e.y - 0.085 * u)) / (0.034 * u))
			if ck.length_squared() <= 1.0:
				cheeks.append(c)
			var tx := e.x - (1.0 if sd == 0 else -1.0) * er.x * 0.55   # Tränenbach am inneren Lidrand
			if absf(p.x - tx) <= 0.015 * u and p.y < e.y - er.y * 0.5 and p.y > e.y - er.y * 0.5 - 0.12 * u:
				tears.append(c)
		if absf(p.x - mc.x) <= 0.125 * u and p.y >= mc.y - 0.06 * u and p.y <= mc.y + 0.025 * u:
			mouth.append(c)
	# erst jetzt ablegen: gepackte Arrays sind Werte – ein append() auf den Eintrag im Wörterbuch ginge verloren
	_cells = {"augen": eyes, "brauen": brows, "wangen": cheeks, "traenen": tears, "mund": mouth}


func _blocked(c: int) -> bool:
	var b := _mask[c]
	return not b & LumosFace.CELL_SKIN or not b & LumosFace.CELL_FRONT or b & LumosFace.CELL_COVER


## Warum ein Rasterpunkt den Mund begrenzt (für den Bericht).
func _why(c: int, fallback: String) -> String:
	var b := _mask[c]
	if b & LumosFace.CELL_COVER:
		for e: Dictionary in items:
			if e.visible and not e.painted and (e.mask as PackedByteArray)[c]:
				return String(e.name)
	if b & LumosFace.CELL_HAIR and fallback == "nase":
		return "schnurrbart"
	return fallback


func _scan_mouth() -> void:
	var g: float = _m.g
	var gx0: float = _m.gx0
	var gy0: float = _m.gy0
	var nx: int = _m.nx
	var ny: int = _m.ny
	var u: float = _m.u
	var mc: Vector3 = _m.mouth
	var ic := clampi(int(roundf((mc.x - gx0) / g)), 0, nx - 1)
	var jc := clampi(int(roundf((mc.y - gy0) / g)), 0, ny - 1)
	var band := maxi(1, int(ceil(0.07 * u / g)))
	limit_by = {}
	# nach unten: letzte Zeile, in der das Mittelband noch freie, nach vorn gewandte Haut ist (Bart darf: der Mund
	# öffnet sich in ihn hinein)
	var j := jc
	var stop := -1
	while j - 1 >= 0 and stop < 0:
		for i in range(maxi(ic - band, 0), mini(ic + band, nx - 1) + 1):
			if _blocked((j - 1) * nx + i):
				stop = (j - 1) * nx + i
				break
		if stop < 0:
			j -= 1
	var down := mc.y - (gy0 + j * g)
	limit_by["unten"] = _why(stop, "kinn") if stop >= 0 else "raster"
	# nach oben: Nase oder gemalter Schnurrbart (der darf ein wenig überlappen – nur Farbe, keine Geometrie)
	j = jc
	stop = -1
	var hair := false
	while j + 1 < ny and stop < 0:
		for i in range(maxi(ic - band, 0), mini(ic + band, nx - 1) + 1):
			var c := (j + 1) * nx + i
			if _blocked(c) or _mask[c] & LumosFace.CELL_HAIR:
				stop = c
				hair = not _blocked(c)
				break
		if stop < 0:
			j += 1
	var upv := (gy0 + j * g) - mc.y + (STACHE_OVERLAP * u if hair else 0.0)
	limit_by["oben"] = ("schnurrbart" if hair else _why(stop, "nase")) if stop >= 0 else "raster"
	# zur Seite: Wangenrand oder Ausrüstung in Mundhöhe
	var half := INF
	var why_s := "raster"
	for sd: int in [-1, 1]:
		var i := ic
		var hit := -1
		while i + sd >= 0 and i + sd < nx and hit < 0:
			for jj in range(maxi(jc - 1, 0), mini(jc + 1, ny - 1) + 1):
				if _blocked(jj * nx + i + sd):
					hit = jj * nx + i + sd
					break
			if hit < 0:
				i += sd
		var hv := absf(gx0 + i * g - mc.x)
		if hv < half:
			half = hv
			why_s = _why(hit, "wange") if hit >= 0 else "raster"
	limit_by["breite"] = why_s
	var ov: Dictionary = (OVERRIDES.get(_key, {}) as Dictionary).get("mund", {})
	limits = Vector3(maxf(float(ov.get("breite", half / u)) * u, MIN_LIM.x * u), maxf(float(ov.get("oben", upv / u)) * u, MIN_LIM.y * u),
		maxf(float(ov.get("unten", down / u)) * u, MIN_LIM.z * u))


func _eval() -> void:
	hidden = 0
	var u: float = _m.u
	for r: String in REGIONS:
		var cells: PackedInt32Array = _cells[r]
		var n := 0
		var cov := 0
		var glass := 0
		var by := {}
		for c in cells:
			if not _mask[c] & LumosFace.CELL_SKIN:
				continue
			n += 1
			if _mask[c] & (LumosFace.CELL_COVER | LumosFace.CELL_GLASS):
				if _mask[c] & LumosFace.CELL_COVER:
					cov += 1
				else:
					glass += 1
				for e: Dictionary in items:
					if e.visible and not e.painted and (e.mask as PackedByteArray)[c]:
						by[e.name] = true
		var frac := float(cov) / float(maxi(n, 1))
		var st := VISIBLE
		if n > 0 and frac >= HIDE_AT:
			st = HIDDEN
		elif n > 0 and (frac >= PARTIAL_AT or float(cov + glass) / float(n) >= PARTIAL_AT):
			st = PARTIAL
		if r == "mund" and st == VISIBLE and (limits.x < WIDE_LAUGH.x * u or limits.y < WIDE_LAUGH.y * u or limits.z < WIDE_LAUGH.z * u):
			st = RESTRICTED
		if overrides.has(r):
			st = int(overrides[r])
		if st == HIDDEN:
			hidden |= int(REGION_BIT[r])
		regions[r] = {"state": st, "covered": frac, "by": by.keys()}
