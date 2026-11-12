class_name PropSettler
extends RefCounted
## Sorgt dafür, dass Deko-Modelle sauber in der Welt stehen – nicht schwebend neben einer erhöhten Arena oder
## halb über einer Kante. Nach dem Aufbau einer Szene prüft settle() jedes platzierte Modell (Assets.spawn setzt
## die Markierung "asset"):
##   1. steht auf etwas (Boden, Plattform, Wasser)            → nichts tun
##   2. steht knapp neben einer Kante (z. B. Zaun am Rand)     → bis 1,5 m nach innen auf festen Boden rücken
##   3. darunter liegt tieferer Boden (Baum neben der Insel)  → auf diesen Boden absenken
##   4. darunter ist gar nichts                               → ausblenden
## Ausgenommen: alles mit Kollision (Spielelemente), Modelle an bewegten Haltern, gewollt Fliegendes (Wolken,
## Sterne, Sammelobjekte …) und tragende Bauteile (Böden, Wände, Klippen, Blöcke …).
## check() liefert dieselbe Prüfung ohne Änderung – genutzt von tools/dev/deco_audit.gd.

const AIRBORNE := ["cloud", "star", "coin", "gem", "balloon", "item_box", "bee", "lamp", "ufo", "kite", "bird", "heart",
	"key", "thunder", "skull", "ghost", "bat", "lantern", "banner", "sign", "arrow", "spark", "fruit", "present",
	"cube_q", "cube_excl", "trophy", "crown", "mount_", "orb", "planet", "rocket", "satellite", "meteor", "torch",
	"chandelier", "web", "flag", "bell", "drone", "fish", "jelly", "bubble", "leaf", "snowflake", "space/"]
## Bauteile, die selbst Boden/Struktur sind (dürfen über Abgründe ragen, tragen andere)
const STRUCTURAL := ["floor", "wall", "block", "plat_", "rock_plat", "platform", "cliff", "tile", "bridge", "stairs",
	"pillar", "island", "terrain", "dock", "ground", "column", "tower", "arch", "gate", "door", "roof", "beam", "rail",
	"track", "ramp", "pier", "cube_", "pipe", "support", "stepping", "sandbank"]

static var _tri_cache := {}


static func cache_size() -> int:
	return _tri_cache.size()


## keep: Knoten, die nie verändert werden (z. B. alles, was das Spielskript selbst hält – siehe script_refs).
static func settle(scene: Node, keep := {}) -> int:
	var n := _run(scene, true, [], keep)
	_tri_cache.clear()   # hält sonst jedes Mesh der Szene (samt Grafikpuffern) über den Szenenwechsel hinaus fest
	return n


static func check(scene: Node, keep := {}) -> Array:
	var out: Array = []
	_run(scene, false, out, keep)
	_tri_cache.clear()
	return out


## Alle Node3D, die ein Skript in seinen Variablen hält (direkt, in Listen oder in Einträgen von Listen/Dictionaries).
## Solche Modelle sind Spielelemente (werden bewegt, gedreht, eingeblendet) – der Settler lässt sie in Ruhe.
static func script_refs(obj: Object) -> Dictionary:
	var out := {}
	for prop in obj.get_property_list():
		if not (int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		_collect(obj.get(prop.name), out, 0)
	return out


static func _collect(v: Variant, out: Dictionary, depth: int) -> void:
	if depth > 2:
		return
	if v is Node3D:
		out[v] = true
	elif v is Array:
		for e in v:
			_collect(e, out, depth + 1)
	elif v is Dictionary:
		for e in (v as Dictionary).values():
			_collect(e, out, depth + 1)


static func _run(scene: Node, fix: bool, report: Array = [], keep := {}) -> int:
	var supports := _supports(scene)
	var changed := 0
	for node in scene.find_children("*", "Node3D", true, false):
		if not node.has_meta("asset"):
			continue
		var n := node as Node3D
		var key := String(n.get_meta("asset"))
		if _skip(n, key) or _kept(n, keep, scene):
			continue
		var bb := _world_aabb(n)
		if bb.size == Vector3.ZERO or bb.size.y < 0.25:
			continue
		var own := n.find_children("*", "MeshInstance3D", true, false)
		var c := bb.get_center()
		var base := Vector3(c.x, bb.position.y, c.z)
		var tall := bb.size.y > 1.5
		var foot := Vector2(bb.size.x, bb.size.z) * 0.32
		var ok := _ground_at(base, supports, own, 0.6, 0.6) != INF
		if ok and tall:
			var miss := 0
			for o in [Vector3(foot.x, 0, 0), Vector3(-foot.x, 0, 0), Vector3(0, 0, foot.y), Vector3(0, 0, -foot.y)]:
				if _ground_at(base + o, supports, own, 0.6, 0.6) == INF:
					miss += 1
			ok = miss < 2
		if ok:
			continue
		if not fix:
			report.append({"asset": key, "pos": base, "kind": "Kante" if _ground_at(base, supports, own, 0.6, 0.6) != INF else "schwebt"})
			continue
		changed += 1
		# 2) knapp neben einer Kante: zum nächsten tragfähigen Punkt in einer von acht Richtungen rücken (≤ 1,5 m)
		var moved := false
		for k in range(1, 8):
			for d in 8:
				var a := TAU * d / 8.0
				var off := Vector3(cos(a), 0, sin(a)) * (k * 0.22)
				var p := base + off
				if _ground_at(p, supports, own, 0.6, 0.6) != INF and (not tall or _fully_on(p, foot, supports, own)):
					n.global_position += off
					moved = true
					break
			if moved:
				break
		if moved:
			continue
		# 3) tieferer Boden darunter: absenken
		var below := _ground_at(base, supports, own, 0.6, 40.0)
		if below != INF and (not tall or _fully_on(Vector3(base.x, below, base.z), foot, supports, own)):
			n.global_position.y += below - base.y
			continue
		# 4) nichts darunter: ausblenden (Deko im Nichts)
		n.visible = false
	return changed


## Gehört n (oder ein Halter darüber) zu den Spielelementen? Die Welt selbst und ihre Wurzeln zählen nicht –
## sonst wäre alles darin geschützt.
static func _kept(n: Node, keep: Dictionary, root: Node) -> bool:
	var p: Node = n
	while p and p != root and p.name != "World" and p.name != "Backdrop":
		if keep.has(p):
			return true
		p = p.get_parent()
	return false


static func _fully_on(p: Vector3, foot: Vector2, supports: Dictionary, own: Array) -> bool:
	var miss := 0
	for o in [Vector3(foot.x, 0, 0), Vector3(-foot.x, 0, 0), Vector3(0, 0, foot.y), Vector3(0, 0, -foot.y)]:
		if _ground_at(p + o, supports, own, 0.6, 0.6) == INF:
			miss += 1
	return miss < 2


static func _skip(n: Node3D, key: String) -> bool:
	if not n.visible:
		return true
	for a in AIRBORNE:
		if a in key:
			return true
	for s in STRUCTURAL:
		if s in key:
			return true
	if not n.find_children("*", "CollisionObject3D", true, false).is_empty():
		return true   # Spielelement (Kollision) – nie verschieben
	var p := n.get_parent()
	while p:
		if p is PartyAvatar or p is CharacterRig or p is CollisionObject3D or p is Camera3D:
			return true
		if p.has_meta("asset"):
			return true   # Teil eines größeren Modells
		if p.name == "World" or p.name == "Backdrop" or p is Window:
			break
		if p is Node3D and (p as Node3D).get_script() != null:
			return true   # an einem eigenen (oft bewegten) Halter
		p = p.get_parent()
	return false


## Flächen, die etwas tragen können: [Mesh, Welt-Hüllquader, Welt-Transform, Besitzer-Knoten], dazu ein Raster-
## Index (4-m-Zellen) für schnelle Abfragen. Nur echte Untergründe zählen: Grundformen (Platten, Inseln, Wasser),
## MultiMesh-Kacheln und breite, flache Modelle (Gelände). Hohe, schmale Modelle (Bäume …) tragen nichts.
const CELL := 4.0


static func _supports(scene: Node) -> Dictionary:
	var list: Array = []
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var gb := m.global_transform * m.get_aabb()
		if gb.size.x * gb.size.z < 0.8:
			continue
		var prim := m.mesh is BoxMesh or m.mesh is PlaneMesh or m.mesh is CylinderMesh
		if not prim and (gb.size.x * gb.size.z < 4.0 or gb.size.y > 0.6 * maxf(gb.size.x, gb.size.z)):
			continue   # hohes/schmales Modell: kein Untergrund
		list.append([m.mesh, gb, m.global_transform, m])
	for mmi in scene.find_children("*", "MultiMeshInstance3D", true, false):
		var mm := (mmi as MultiMeshInstance3D).multimesh
		if mm == null or mm.mesh == null or mm.transform_format != MultiMesh.TRANSFORM_3D:
			continue
		var ab := mm.mesh.get_aabb()
		for i in mini(mm.instance_count, 4000):
			var xf := (mmi as MultiMeshInstance3D).global_transform * mm.get_instance_transform(i)
			var gb2 := xf * ab
			if gb2.size.x * gb2.size.z >= 0.8 and gb2.size.y <= 0.6 * maxf(gb2.size.x, gb2.size.z):
				list.append([mm.mesh, gb2, xf, mmi])
	var grid := {}
	var huge: Array = []
	for e in list:
		var gb: AABB = e[1]
		if gb.size.x > CELL * 12.0 or gb.size.z > CELL * 12.0:
			huge.append(e)   # riesige Flächen (Fernboden, Meer): immer prüfen
			continue
		for cx in range(floori(gb.position.x / CELL), floori(gb.end.x / CELL) + 1):
			for cz in range(floori(gb.position.z / CELL), floori(gb.end.z / CELL) + 1):
				var k := Vector2i(cx, cz)
				if not grid.has(k):
					grid[k] = []
				(grid[k] as Array).append(e)
	return {"grid": grid, "huge": huge}


## Höhe der obersten tragenden Fläche unter p (zwischen p.y + up und p.y - down), sonst INF.
static func _ground_at(p: Vector3, supports: Dictionary, own: Array, up: float, down: float) -> float:
	var best := INF
	var from := p + Vector3.UP * up
	var cell: Array = (supports.grid as Dictionary).get(Vector2i(floori(p.x / CELL), floori(p.z / CELL)), [])
	for lst in [cell, supports.huge]:
		for e in lst:
			var gb: AABB = e[1]
			if e[3] in own:
				continue
			if p.x < gb.position.x - 0.05 or p.x > gb.end.x + 0.05 or p.z < gb.position.z - 0.05 or p.z > gb.end.z + 0.05:
				continue
			if gb.end.y < p.y - down or gb.position.y > p.y + up:
				continue
			var y := _surface_y(e[0], e[2], from, up + down)
			if y != INF and (best == INF or y > best):
				best = y
	return best


static func _surface_y(mesh: Mesh, xf: Transform3D, from: Vector3, reach: float) -> float:
	var inv := xf.affine_inverse()
	var lf: Vector3 = inv * from
	# Schnellweg für Grundformen (Bodenplatten, Inseln, Wasserflächen)
	if mesh is BoxMesh:
		var h := (mesh as BoxMesh).size * 0.5
		if absf(lf.x) <= h.x and absf(lf.z) <= h.z:
			return _hit_y(xf, Vector3(lf.x, h.y, lf.z), from, reach)
		return INF
	if mesh is PlaneMesh:
		var ps := (mesh as PlaneMesh).size * 0.5
		if absf(lf.x) <= ps.x and absf(lf.z) <= ps.y:
			return _hit_y(xf, Vector3(lf.x, 0, lf.z), from, reach)
		return INF
	if mesh is CylinderMesh:
		var cm := mesh as CylinderMesh
		if Vector2(lf.x, lf.z).length() <= maxf(cm.top_radius, cm.bottom_radius):
			return _hit_y(xf, Vector3(lf.x, cm.height * 0.5, lf.z), from, reach)
		return INF
	if not _tri_cache.has(mesh):
		_tri_cache[mesh] = mesh.generate_triangle_mesh()
	var tm: TriangleMesh = _tri_cache[mesh]
	if tm == null:
		return INF
	var hit := tm.intersect_ray(lf, (inv.basis * Vector3.DOWN).normalized())
	if hit.is_empty():
		return INF
	return _hit_y(xf, Vector3(hit.position), from, reach)


static func _hit_y(xf: Transform3D, local: Vector3, from: Vector3, reach: float) -> float:
	var wp: Vector3 = xf * local
	if wp.y > from.y + 0.01 or from.y - wp.y > reach:
		return INF
	return wp.y


static func _world_aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	var list: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		list.append(n)
	for mi in list:
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var b := m.global_transform * m.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out
