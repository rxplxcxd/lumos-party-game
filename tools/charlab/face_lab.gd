extends RefCounted
## Gesichts-Labor (CharLab, ab 1.5.3): Modell-Kompatibilität, Anschmiegen des Munds an die Haut, Ausrüstung,
## Ausdrücke × Blickwinkel × Kopfdrehungen als Referenzbilder.
##   godot --headless --fixed-fps 60 --path . res://tools/charlab/CharLab.tscn -- --lab-face               Messungen
##   xvfb-run godot --fixed-fps 60 --resolution 640x640 --path . res://tools/charlab/CharLab.tscn -- --lab-face=/ordner   + Bilder
##   … --face-only=hero/knight,hero/mage                                                                     nur diese Modelle
## Messung „Mund an der Haut“: Ein feines Tiefenraster aus den echten Dreiecken des Kopf-Meshs (¼ der Rasterweite,
## die das Gesicht selbst nutzt) dient als Wahrheit; für jeden gezeichneten Mund-Punkt wird der Abstand zur Haut
## bestimmt – positiv = schwebt davor, negativ = steckt in der Haut. Bewertet je Modell und Ausdruck.
## Kopfdrehungen: Das Gesicht hängt starr am Kopfknochen; ob der Kopf-Mesh beim Drehen anders verformt wird
## (Skin-Gewichte auf Hals/Brust), zeigt die Kompatibilitätsliste („kopf_starr“).

const MODELS := ["hero/knight", "hero/barbarian", "hero/mage", "hero/ranger", "hero/rogue", "hero/rogue_hooded",
	"hero/skeleton_minion", "hero/skeleton_warrior", "hero/skeleton_rogue", "hero/skeleton_mage",
	"mini/male_a", "mini/female_b", "mini/robot", "mini/alien", "npc/bear", "npc/duck", "npc/keeper", "npc/vampire",
	"pet/cat", "pet/dog"]
const EXPRESSIONS := ["neutral", "laugh", "sad", "angry", "surprised", "talk"]
const VIEWS := [["vorn", 0.0, Vector3.ZERO], ["schraeg", 35.0, Vector3.ZERO], ["seite", 80.0, Vector3.ZERO],
	["kopf_links", 0.0, Vector3(0, 0.6, 0)], ["kopf_hoch", 20.0, Vector3(-0.35, 0, 0)], ["kopf_runter", -20.0, Vector3(0.3, 0, 0)]]
const MOUTH_MATS := ["cavity", "teeth", "tongue", "lip"]
## Abnahme je Modell mit Gesicht (Kopfbreiten). Ausgangslage vor 1.5.3: Mund bis 0,45 vor der Haut (Zunge unter dem
## Kinn), bis −0,134 in der Haut, Zähne unter der Maske des Kapuzen-Schurken.
const MAX_GAP := 0.04         ## größter senkrechter Abstand eines Mund-Punkts vor der Haut (Versatz 0,005–0,008 + Raster)
const MAX_PEN := -0.015       ## tiefster Punkt in der Haut
const MAX_HAND_IN_GEAR := 0.05   ## Anteil der Hand-Punkte, die mit Ausweichen in Kopf-Ausrüstung stecken dürfen

var lab: Node
var results: Array = []
var fails := 0


func run(p_lab: Node, out_dir: String) -> void:
	lab = p_lab
	var tree := lab.get_tree()
	if out_dir != "":
		Game.settings["quality"] = "high"
		Gfx.apply()
		DirAccess.make_dir_recursive_absolute(out_dir)
	lab.label.visible = false
	for a in lab.actors + lab.others:
		a.rig.visible = false
	var cam: Camera3D = lab.cam
	cam.fov = 24.0
	var only: Array = []   # --face-only=hero/knight,hero/mage: nur diese Modelle (schnellere Bildläufe)
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--face-only="):
			only = String(a).get_slice("=", 1).split(",")
	for key: String in MODELS:
		if not only.is_empty() and not key in only:
			continue
		var r := CharacterRig.new()
		lab.add_child(r)
		r.setup(key, -1, 1.0)
		r.position = Vector3(0, 0, 3.0)
		r.face_now(Vector3(0, 0, 1))
		r.play("idle")
		var actor := LumosActor.attach(r)
		for i in 20:
			await tree.process_frame
		var info := census(r, actor)
		var face := actor.face if actor else null
		if face and face.visible:
			info["mund"] = await _mouth_check(actor, face)
			info["ausruestung_test"] = await _gear_check(actor, face)
			info["haende_am_kopf"] = await _hand_check(actor, face)
			if out_dir != "":
				await _sheet(actor, face, out_dir.path_join(key.replace("/", "_") + ".png"))
		if info.get("gesicht", "") == "ja":
			var why := _verdict(info)
			info["abnahme"] = "PASS" if why.is_empty() else "FAIL"
			if not why.is_empty():
				info["abnahme_gruende"] = why
				fails += 1
			print("FACE-PRUEFUNG %s: %s%s" % [key, info.abnahme, "" if why.is_empty() else " – " + "; ".join(why)])
		results.append(info)
		print("FACE " + JSON.stringify(info))
		r.queue_free()
		await tree.process_frame


## Abnahme eines Modells: Mund an der Haut (alle Ausdrücke), nichts unter Ausrüstung oder auf steiler Haut, Kopf
## starr am Gesichtsknochen, ausgeblendete Bereiche zeichnen nichts, eigene Teile aus/ein stellt den Zustand wieder
## her, Hände stecken mit Ausweichen nicht in Ausrüstung. Rückgabe: Gründe für FAIL (leer = PASS).
func _verdict(info: Dictionary) -> Array:
	var why: Array = []
	if float(info.get("kopf_starr", 0.0)) < 0.99:
		why.append("Kopf-Mesh nicht starr am Gesichtsknochen (%s)" % str(info.get("kopf_starr")))
	var mouth: Dictionary = info.get("mund", {})
	for ex: String in EXPRESSIONS:
		var d: Dictionary = mouth.get(ex, {})
		if int(d.get("punkte", 0)) == 0:
			continue   # Mund ausgeblendet (Maske) – zählt unten bei den Bereichen
		if float(d.get("max_vor_haut_senkrecht", 0.0)) > MAX_GAP:
			why.append("%s: Mund %.3f vor der Haut" % [ex, float(d.max_vor_haut_senkrecht)])
		if float(d.get("max_in_haut", 0.0)) < MAX_PEN:
			why.append("%s: Mund %.3f in der Haut" % [ex, float(d.max_in_haut)])
		if int(d.get("unter_ausruestung", 0)) > 0:
			why.append("%s: %d Mund-Punkte unter Ausrüstung" % [ex, int(d.unter_ausruestung)])
		if int(d.get("auf_steiler_haut", 0)) > 0:
			why.append("%s: %d Mund-Punkte auf steiler Haut" % [ex, int(d.auf_steiler_haut)])
	var gt: Dictionary = info.get("ausruestung_test", {})
	for k: String in gt:
		var v = gt[k]
		if v is Dictionary and (v as Dictionary).has("ok") and not bool(v.ok):
			why.append("Ausrüstungstest %s" % k)
		elif v is bool and not bool(v):
			why.append("Ausrüstungstest %s" % k)
	var hc: Dictionary = info.get("haende_am_kopf", {})
	for gid: String in hc:
		var v2 = hc[gid]
		if v2 is Dictionary and v2.get("mit_ausweichen") != null and float(v2.mit_ausweichen) > MAX_HAND_IN_GEAR:
			why.append("Geste %s: %.0f %% der Hand in Ausrüstung" % [gid, 100.0 * float(v2.mit_ausweichen)])
	return why


## Was kann das Modell? Skelett, Kopfknochen, Kopf-Mesh, Skin-Gewichte am Kopf, Blend Shapes, Ausrüstung am Kopf,
## gemalte Gesichtsbehaarung, Gesicht eingerichtet oder warum nicht.
func census(r: CharacterRig, actor: LumosActor) -> Dictionary:
	var info := {"model": r.model_key, "skelett": r.skel != null}
	var sk := r.skel
	var hb := sk.find_bone("head") if sk else -1
	info["kopfknochen"] = hb >= 0
	var head := LumosFace._find_head_mesh(r)
	info["kopf_mesh"] = String(head.name) if head else ""
	var blend := 0
	var parts: Array = []
	for mi in Assets.find_meshes(r.model):
		if mi.mesh and not mi.mesh is ImmediateMesh:   # ohne die Gesichtsebene des Frameworks selbst
			blend += mi.mesh.get_blend_shape_count() if mi.mesh is ArrayMesh else 0
			parts.append(String(mi.name))
	info["blend_shapes"] = blend
	info["teile"] = parts
	# Kopf starr? Anteil der Gesichts-Punkte des Kopf-Meshs, die zu ≥ 99 % an dem Knochen hängen, dem das Gesicht
	# folgt (LumosFace.attach_bone; ohne Gesicht der Kopfknochen)
	if actor and actor.face and actor.face.attach_bone != "" and sk:
		hb = sk.find_bone(actor.face.attach_bone)
		info["gesicht_knochen"] = actor.face.attach_bone
	if head and head.mesh and head.skin and sk and hb >= 0:
		var arr := head.mesh.surface_get_arrays(0)
		var bones = arr[Mesh.ARRAY_BONES]
		var weights = arr[Mesh.ARRAY_WEIGHTS]
		if bones != null and weights != null and (bones as PackedInt32Array).size() > 0:
			var per := (bones as PackedInt32Array).size() / maxi(1, (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
			var n := 0
			var rigid := 0
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bb := head.mesh.get_aabb()
			for i in vs.size():
				if vs[i].z < bb.end.z - 0.35 * bb.size.z:
					continue   # nur die vordere Gesichtshälfte
				n += 1
				var w_head := 0.0
				for k in per:
					# Knochen über den Bind-Namen auflösen (wie Godot beim Skinning); der gespeicherte Bind-Index
					# gehört zum Skelett der Quelldatei und passt nicht bei jedem Modell (Kapuzen-Schurke)
					var bind_idx: int = (bones as PackedInt32Array)[i * per + k]
					var bone := -1
					if bind_idx < head.skin.get_bind_count():
						var bn := head.skin.get_bind_name(bind_idx)
						bone = sk.find_bone(bn) if bn != &"" else head.skin.get_bind_bone(bind_idx)
					if bone == hb:
						w_head += (weights as PackedFloat32Array)[i * per + k]
				if w_head >= 0.99:
					rigid += 1
			info["kopf_starr"] = snappedf(float(rigid) / maxf(1.0, float(n)), 0.01)
	# Ausrüstung am Kopf: Teile, deren Mitte im Kopfbereich liegt und die nicht der Kopf selbst sind
	var gear: Array = []
	if head:
		var hbox := head.global_transform * head.get_aabb()
		for mi in Assets.find_meshes(r.model):
			if mi == head or mi.mesh == null or mi.mesh is ImmediateMesh:
				continue
			var b := mi.global_transform * mi.get_aabb()
			if hbox.grow(0.05).intersects(b) and b.get_center().y > hbox.position.y + hbox.size.y * 0.3:
				gear.append(String(mi.name))
	info["kopf_ausruestung"] = gear
	if actor == null:
		info["gesicht"] = "kein Framework (Profil rigid)"
		return info
	var face := actor.face
	if face == null:
		info["gesicht"] = "nicht eingerichtet (kein Kopf-Mesh oder keine Augen erkannt)"
		return info
	var m := face.metrics()
	info["gesicht"] = "ja"
	info["schnurrbart"] = bool(m.get("stache", false))
	info["bart"] = bool(m.get("beard", false))
	info["eigene_brauen"] = face.has_own_brows
	var ap = face.get("appearance")
	if ap:
		info["verdeckung"] = ap.summary()
	return info


## Abstand jedes Mund-Punkts zur echten Haut, je Ausdruck. Raster aus den Dreiecken des (versenkten) Kopf-Meshs.
func _mouth_check(actor: LumosActor, face: LumosFace) -> Dictionary:
	var tree := lab.get_tree()
	var m := face.metrics()
	var u: float = m.u
	var mc: Vector3 = m.mouth
	var step := LumosFace.GRID * u * 0.25
	var x0: float = mc.x - 0.36 * u
	var y0: float = mc.y - 0.24 * u
	var nx := int(ceil(0.72 * u / step)) + 1
	var ny := int(ceil(0.36 * u / step)) + 1
	var depth := _raster(m.mesh as Mesh, x0, y0, step, nx, ny)
	var out := {}
	var worst_gap := 0.0
	var worst_pen := 0.0
	for ex: String in EXPRESSIONS:
		if ex == "talk":
			actor.feel("joy", 0.0)
			face.talk = 1.0
		else:
			face.talk = 0.0
			actor.feel(ex, 0.0)
		for i in 24:
			await tree.process_frame
		var gap := -INF
		var pen := INF
		var gap_n := -INF
		var pts := 0
		var corner_gap := 0.0
		var under_gear := 0
		var steep := 0
		var gap_at := []
		var ap: LumosAppearance = face.appearance
		var im := face.drawn_mesh()
		for s in im.get_surface_count():
			if not _is_mouth(face, im.surface_get_material(s)):
				continue
			var mat_name := _mat_name(face, im.surface_get_material(s))
			var arr := im.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for v in vs:
				if v == Vector3.ZERO:
					continue   # Null-Dreieck leerer Flächen
				var z := _sample(depth, x0, y0, step, nx, ny, v.x, v.y)
				if z < -1e6:
					continue
				var d := (v.z - z) / u
				if d > gap:
					gap_at = [snappedf((v.x - mc.x) / u, 0.001), snappedf((v.y - mc.y) / u, 0.001), mat_name]
				gap = maxf(gap, d)
				pen = minf(pen, d)
				# senkrechter Abstand: z-Abstand × Neigung der echten Haut an dieser Stelle (Gradient des feinen Rasters)
				var zx := _sample(depth, x0, y0, step, nx, ny, v.x + step, v.y)
				var zy := _sample(depth, x0, y0, step, nx, ny, v.x, v.y + step)
				if zx > -1e6 and zy > -1e6:
					gap_n = maxf(gap_n, d * Vector3(-(zx - z) / step, -(zy - z) / step, 1.0).normalized().z)
				pts += 1
				if ap and not ap._mask.is_empty():
					var c := _cell(m, v.x, v.y)
					if c >= 0 and ap._mask[c] & LumosFace.CELL_COVER:
						under_gear += 1
					elif c >= 0 and not ap._mask[c] & LumosFace.CELL_FRONT:
						steep += 1
				if absf(v.x - mc.x) > 0.75 * absf(_half_width(vs, mc.x)):
					corner_gap = maxf(corner_gap, d)
		if pts == 0:
			out[ex] = {"punkte": 0}
			continue
		out[ex] = {"punkte": pts, "max_vor_haut": snappedf(gap, 0.0001), "max_in_haut": snappedf(pen, 0.0001),
			"max_vor_haut_senkrecht": snappedf(gap_n, 0.0001), "ecken_vor_haut": snappedf(corner_gap, 0.0001),
			"unter_ausruestung": under_gear, "auf_steiler_haut": steep, "groesster_abstand_bei": gap_at}
		worst_gap = maxf(worst_gap, gap)
		worst_pen = minf(worst_pen, pen)
	face.talk = 0.0
	actor.feel("neutral", 0.0)
	out["schlechtester_abstand"] = snappedf(worst_gap, 0.0001)
	out["tiefste_durchdringung"] = snappedf(worst_pen, 0.0001)
	return out


## Ausrüstung: eigene Teile aus- und wieder einblenden, dann künstliche Teile vor das Gesicht setzen (geschlossenes
## Visier, Brille aus Glas, Maske über dem Mund) – Zustände der Bereiche, gezeichnete Punkte je Bereich, Hände.
func _gear_check(actor: LumosActor, face: LumosFace) -> Dictionary:
	var ap: LumosAppearance = face.appearance
	if ap == null:
		return {"fehler": "keine Vermessung"}
	var out := {}
	var m := face.metrics()
	var u: float = m.u
	actor.feel("joy", 0.0)
	face.talk = 1.0   # offener, bewegter Mund: zeichnet jedes Bild
	await _frames(20)
	var before := _states(ap)
	var lim_before := ap.limits
	var own: Array = []
	for e: Dictionary in ap.items:
		if not e.painted and is_instance_valid(e.node):
			own.append(e.node)
	if not own.is_empty():
		for n: Node3D in own:
			n.visible = false
		await _frames(45)   # LumosFace prüft die Sichtbarkeit alle 0,5 s
		out["eigene_teile_aus"] = {"bereiche": _states(ap), "mund_grenzen": ap.summary().mund_grenzen}
		for n: Node3D in own:
			n.visible = true
		await _frames(45)
		out["eigene_teile_wieder_an_wie_vorher"] = _states(ap) == before and ap.limits.is_equal_approx(lim_before)
	var ec: Array = m.eye_c
	var eye_y := ((ec[0] as Vector3).y + (ec[1] as Vector3).y) * 0.5
	var mc: Vector3 = m.mouth
	var front: float = m.front
	var cx: float = m.cx
	var er: Vector2 = m.eye_r
	# [Name, Art, Größe, Mitte (Raum des Kopf-Meshs), durchsichtig, erwartet ausgeblendet, erwartet gezeichnet]
	var tests := [
		["visier_zu", "visier", Vector3(u * 1.05, eye_y - mc.y + 0.36 * u, 0.02 * u), Vector3(cx, (eye_y + mc.y) * 0.5 + 0.03 * u, front + 0.03 * u), false,
			["augen", "mund"], []],
		["brille_glas", "brille", Vector3(u * 0.8, er.y * 3.2, 0.01 * u), Vector3(cx, eye_y, front + 0.02 * u), true, [], ["augen"]],
		["maske_mund", "maske", Vector3(u * 0.75, 0.24 * u, 0.02 * u), Vector3(cx, mc.y - 0.04 * u, front + 0.02 * u), false, ["mund"], ["augen"]],
	]
	var head: MeshInstance3D = face._head
	for t: Array in tests:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = t[2]
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.45, 0.55, 0.35 if t[4] else 1.0)
		if t[4]:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = mat
		mi.name = "Test_" + String(t[0])
		head.add_child(mi)
		mi.position = t[3]
		ap.add_item(mi, String(t[1]))
		await _frames(6)
		var st := _states(ap)
		var drawn := _drawn_by_region(face)
		var ok := true
		for rg: String in t[5]:
			ok = ok and st.get(rg, "") == "ausgeblendet" and int(drawn.get(rg, 0)) == 0
		for rg: String in t[6]:
			ok = ok and st.get(rg, "") != "ausgeblendet" and int(drawn.get(rg, 0)) > 0
		var hand := {}
		if ap.has_gear:   # Hand vor dem Gesicht (Gesicht verbergen): wie weit wird sie nach außen geschoben?
			var p := face.global_transform * Vector3(cx, eye_y - 0.05 * u, front + 0.02 * u)
			hand["vorn_verschoben_um"] = snappedf(actor.clear_of_gear(p).distance_to(p) / (u * face.global_basis.get_scale().x), 0.001)
		out[t[0]] = {"bereiche": st, "gezeichnet": drawn, "hand": hand, "ok": ok}
		ap.remove_item(mi)
		mi.queue_free()
		await _frames(6)
	out["nach_dem_test_wie_vorher"] = _states(ap) == before and ap.limits.is_equal_approx(lim_before)
	face.talk = 0.0
	actor.feel("neutral", 0.0)
	return out


## Hände an Helm, Hut und Maske: jede Geste am Kopf einmal ohne und einmal mit Ausweichen (LumosActor.gear_clearance).
## Gemessen wird die echte Hand: alle Punkte des Arm-Meshs, die am Handknochen hängen, in der aktuellen Pose (Skinning
## auf der CPU). Ergebnis je Geste: größter Anteil der Hand-Punkte, die in sichtbarer Kopf-Ausrüstung stecken
## (Dreiecke in aktueller Pose, Wippen inklusive; Strahl-Parität in drei Richtungen, Mehrheit entscheidet).
func _hand_check(actor: LumosActor, face: LumosFace) -> Dictionary:
	var ap: LumosAppearance = face.appearance
	if ap == null or not ap.has_gear or actor.body == null:
		return {"ausruestung_am_kopf": false}
	var out := {}
	var hands := {"l": _hand_points(actor, "l"), "r": _hand_points(actor, "r")}
	for gid: String in LumosMicro.HEAD_GESTURES:
		var res := {}
		for mode: bool in [false, true]:
			LumosActor.gear_clearance = mode
			actor.micro.stop()
			await _frames(20)
			actor.gesture(gid)
			var worst := 0.0
			var samples := 0
			for i in 60:
				await lab.get_tree().process_frame
				if i >= 24 and i % 6 == 0 and actor.micro.gesture == gid:
					var tris := _gear_tris(actor, face)
					samples += 1
					for sd: String in ["l", "r"]:
						var pts := _posed(actor, hands[sd])
						if pts.is_empty():
							continue
						var n_in := 0
						for q in pts:
							if _inside(tris, q):
								n_in += 1
						worst = maxf(worst, float(n_in) / float(pts.size()))
			res["mit_ausweichen" if mode else "ohne_ausweichen"] = snappedf(worst, 0.01) if samples > 0 else null
		out[gid] = res
	LumosActor.gear_clearance = true
	actor.micro.stop()
	await _frames(20)
	return out


## Punkte der Hand sd: [Mesh-Instanz, Bind-Index, Punkte im Mesh-Raum] (jeder 2. Punkt mit ≥ 50 % am Handknochen).
func _hand_points(actor: LumosActor, sd: String) -> Array:
	var sk := actor.rig.skel
	var hb := sk.find_bone("hand." + sd) if sk else -1
	if hb < 0:
		return []
	for mi in Assets.find_meshes(actor.rig.model):
		if mi.skin == null or mi.mesh == null or mi.mesh is ImmediateMesh:
			continue
		var bind := -1
		for b in mi.skin.get_bind_count():
			var bn := mi.skin.get_bind_name(b)
			if (sk.find_bone(bn) if bn != &"" else mi.skin.get_bind_bone(b)) == hb:
				bind = b
		if bind < 0:
			continue
		var arr := mi.mesh.surface_get_arrays(0)
		if arr[Mesh.ARRAY_BONES] == null:
			continue
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / maxi(vs.size(), 1)
		var pts := PackedVector3Array()
		for i in range(0, vs.size(), 2):
			for k in per:
				if bones[i * per + k] == bind and wts[i * per + k] >= 0.5:
					pts.append(vs[i])
					break
		if pts.size() >= 8:
			return [mi, bind, hb, pts]
	return []


func _posed(actor: LumosActor, h: Array) -> PackedVector3Array:
	if h.is_empty():
		return PackedVector3Array()
	var sk := actor.rig.skel
	var mi: MeshInstance3D = h[0]
	var xf := sk.global_transform * sk.get_bone_global_pose(int(h[2])) * mi.skin.get_bind_pose(int(h[1]))
	var out := PackedVector3Array()
	for v in (h[3] as PackedVector3Array):
		out.append(xf * v)
	return out


## Dreiecke (Welt, aktuelle Pose) der sichtbaren, undurchsichtigen Kopf-Ausrüstung.
func _gear_tris(actor: LumosActor, face: LumosFace) -> PackedVector3Array:
	var out := PackedVector3Array()
	var sk := actor.rig.skel
	for e: Dictionary in face.appearance.items:
		if e.painted or not e.visible or not e.head_gear or e.glass or not is_instance_valid(e.node):
			continue
		var mi: MeshInstance3D = e.node
		var xf := mi.global_transform
		if mi.skin and sk:   # starr an einem Knochen (Kopf oder Feder eines wippenden Huts): aktuelle Pose des Knochens
			var arr0 := mi.mesh.surface_get_arrays(0)
			if arr0[Mesh.ARRAY_BONES] != null and (arr0[Mesh.ARRAY_BONES] as PackedInt32Array).size() > 0:
				var bi: int = (arr0[Mesh.ARRAY_BONES] as PackedInt32Array)[0]
				var bn := mi.skin.get_bind_name(bi)
				var bone := sk.find_bone(bn) if bn != &"" else mi.skin.get_bind_bone(bi)
				if bone >= 0:
					xf = sk.global_transform * sk.get_bone_global_pose(bone) * mi.skin.get_bind_pose(bi)
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ia: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var n := ia.size() if ia.size() > 0 else vs.size()
			for q in n:
				out.append(xf * vs[ia[q] if ia.size() > 0 else q])
	return out


## Punkt in einem (weitgehend geschlossenen) Netz? Strahl-Parität in drei Richtungen, Mehrheit entscheidet.
func _inside(tris: PackedVector3Array, p: Vector3) -> bool:
	var votes := 0
	for dir: Vector3 in [Vector3(0.31, 0.95, 0.07).normalized(), Vector3(-0.83, 0.2, 0.52).normalized(), Vector3(0.12, -0.4, 0.91).normalized()]:
		var hits := 0
		for t in range(0, tris.size() - 2, 3):
			if Geometry3D.ray_intersects_triangle(p, dir, tris[t], tris[t + 1], tris[t + 2]) != null:
				hits += 1
		if hits % 2 == 1:
			votes += 1
	return votes >= 2


func _states(ap: LumosAppearance) -> Dictionary:
	var d := {}
	for r: String in LumosAppearance.REGIONS:
		d[r] = LumosAppearance.STATE[ap.state(r)]
	return d


## Gezeichnete Punkte je Bereich (ohne Null-Dreiecke leerer Flächen).
func _drawn_by_region(face: LumosFace) -> Dictionary:
	var groups := {"augen": ["eye", "white"], "mund": ["cavity", "teeth", "tongue", "lip"], "brauen": ["brow"], "wangen": ["blush", "cheek"]}
	var out := {}
	var im := face.drawn_mesh()
	for g: String in groups:
		var n := 0
		for s in im.get_surface_count():
			var mat := im.surface_get_material(s)
			var hit := false
			for k: String in groups[g]:
				hit = hit or face.material_of(k) == mat
			if hit:
				for v in (im.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
					if v != Vector3.ZERO:
						n += 1
		out[g] = n
	return out


func _frames(n: int) -> void:
	for i in n:
		await lab.get_tree().process_frame


## Nächster Punkt des Gesichtsrasters (LumosFace) zu (x, y), -1 = außerhalb.
func _cell(m: Dictionary, x: float, y: float) -> int:
	var i := int(roundf((x - float(m.gx0)) / float(m.g)))
	var j := int(roundf((y - float(m.gy0)) / float(m.g)))
	if i < 0 or j < 0 or i >= int(m.nx) or j >= int(m.ny):
		return -1
	return j * int(m.nx) + i


func _half_width(vs: PackedVector3Array, cx: float) -> float:
	var w := 0.0
	for v in vs:
		if v != Vector3.ZERO:
			w = maxf(w, absf(v.x - cx))
	return w


func _mat_name(face: LumosFace, mat: Material) -> String:
	for k: String in MOUTH_MATS:
		if face.material_of(k) == mat:
			return k
	return "?"


func _is_mouth(face: LumosFace, mat: Material) -> bool:
	for k: String in MOUTH_MATS:
		if face.material_of(k) == mat:
			return true
	return false


## Vorderste Haut je Rasterpunkt aus den Dreiecken (wie LumosFace._measure, aber 4× feiner und nur um den Mund).
func _raster(mesh: Mesh, x0: float, y0: float, g: float, nx: int, ny: int) -> PackedFloat32Array:
	var depth := PackedFloat32Array()
	depth.resize(nx * ny)
	depth.fill(-INF)
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ia: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var tri_n := ia.size() / 3 if ia.size() > 0 else vs.size() / 3
		for t in tri_n:
			var p0 := vs[ia[t * 3] if ia.size() > 0 else t * 3]
			var p1 := vs[ia[t * 3 + 1] if ia.size() > 0 else t * 3 + 1]
			var p2 := vs[ia[t * 3 + 2] if ia.size() > 0 else t * 3 + 2]
			var den := (p1.y - p2.y) * (p0.x - p2.x) + (p2.x - p1.x) * (p0.y - p2.y)
			if absf(den) < 1e-12:
				continue
			var i0 := maxi(int(floor((minf(p0.x, minf(p1.x, p2.x)) - x0) / g)), 0)
			var i1 := mini(int(ceil((maxf(p0.x, maxf(p1.x, p2.x)) - x0) / g)), nx - 1)
			var j0 := maxi(int(floor((minf(p0.y, minf(p1.y, p2.y)) - y0) / g)), 0)
			var j1 := mini(int(ceil((maxf(p0.y, maxf(p1.y, p2.y)) - y0) / g)), ny - 1)
			if i0 > i1 or j0 > j1:
				continue
			for j in range(j0, j1 + 1):
				for i in range(i0, i1 + 1):
					var x := x0 + i * g
					var y := y0 + j * g
					var w0 := ((p1.y - p2.y) * (x - p2.x) + (p2.x - p1.x) * (y - p2.y)) / den
					var w1 := ((p2.y - p0.y) * (x - p2.x) + (p0.x - p2.x) * (y - p2.y)) / den
					var w2 := 1.0 - w0 - w1
					if w0 >= -0.001 and w1 >= -0.001 and w2 >= -0.001:
						var z := w0 * p0.z + w1 * p1.z + w2 * p2.z
						if z > depth[j * nx + i]:
							depth[j * nx + i] = z
	return depth


func _sample(d: PackedFloat32Array, x0: float, y0: float, g: float, nx: int, ny: int, x: float, y: float) -> float:
	var fx := (x - x0) / g
	var fy := (y - y0) / g
	if fx < 0.0 or fy < 0.0 or fx > nx - 1.001 or fy > ny - 1.001:
		return -INF
	var i := int(fx)
	var j := int(fy)
	var a := d[j * nx + i]
	var b := d[j * nx + i + 1]
	var c := d[(j + 1) * nx + i]
	var e := d[(j + 1) * nx + i + 1]
	if a < -1e6 or b < -1e6 or c < -1e6 or e < -1e6:
		return -INF
	return lerpf(lerpf(a, b, fx - i), lerpf(c, e, fx - i), fy - j)


## Referenzbild je Modell: Zeilen = Ausdrücke, Spalten = Blickwinkel/Kopfdrehungen (Nahaufnahme des Kopfes).
func _sheet(actor: LumosActor, face: LumosFace, path: String) -> void:
	var tree := lab.get_tree()
	var cam: Camera3D = lab.cam
	var m := face.metrics()
	var u: float = m.u
	var cell := Vector2i(320, 320)
	var sheet := Image.create(cell.x * VIEWS.size(), cell.y * EXPRESSIONS.size(), false, Image.FORMAT_RGB8)
	for row in EXPRESSIONS.size():
		var ex: String = EXPRESSIONS[row]
		face.talk = 1.0 if ex == "talk" else 0.0
		actor.feel("joy" if ex == "talk" else ex, 0.0)
		for col in VIEWS.size():
			var v: Array = VIEWS[col]
			actor.body.head_add = v[2]
			for i in 16:
				await tree.process_frame
			var target := face.global_transform * Vector3(float(m.cx), (m.mouth as Vector3).y + 0.1 * u, float(m.front))
			var a := deg_to_rad(float(v[1]))
			var dist := u * 0.62 / tan(deg_to_rad(cam.fov * 0.5)) * face.global_transform.basis.get_scale().x
			cam.position = target + Vector3(sin(a), 0.12, cos(a)).normalized() * dist
			cam.look_at(target)
			await RenderingServer.frame_post_draw
			var img := lab.get_viewport().get_texture().get_image()
			var side := mini(img.get_width(), img.get_height())
			img = img.get_region(Rect2i((img.get_width() - side) / 2, (img.get_height() - side) / 2, side, side))
			img.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
			img.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), Vector2i(col * cell.x, row * cell.y))
	actor.body.head_add = Vector3.ZERO
	face.talk = 0.0
	actor.feel("neutral", 0.0)
	sheet.save_png(path)
	print("FACE-BILD " + path)
