class_name ItemModels
extends RefCounted
## 3D-Modelle der Nitro-Dash-Items – stilisiert-low-poly wie der Rest von Lumos, aber mit Material-Unterschieden
## (glänzende Sahne, matter Teig, Metall, durchscheinender Honig, schillernde Blase). Jedes Item hat eine klare,
## von Weitem erkennbare Silhouette und Farbe.

static func _m(col: Color, rough := 0.6, metal := 0.0, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = Color(col.r, col.g, col.b)
		m.emission_energy_multiplier = emit
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _sphere(parent: Node3D, r: float, pos: Vector3, mat: Material, squash := Vector3.ONE, seg := 14) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = seg
	sm.rings = maxi(4, seg / 2)
	sm.material = mat
	sm.set_meta("gfx_tuned", true)
	mi.mesh = sm
	mi.position = pos
	mi.scale = squash
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material, seg := 14) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	cm.material = mat
	cm.set_meta("gfx_tuned", true)
	mi.mesh = cm
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Kuchendeckel: Mürbeteig mit Rand, Sahnehaube, Sahnetupfen und glänzender Kirsche.
static func pie(scale := 1.0) -> Node3D:
	var n := Node3D.new()
	var crust := _m(Color("#c98a45"), 0.78)
	_cyl(n, 0.9, 0.74, 0.32, Vector3.ZERO, crust, 18)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.78
	tm.outer_radius = 0.98
	tm.rings = 20
	tm.ring_segments = 8
	tm.material = _m(Color("#a8662a"), 0.7)
	tm.set_meta("gfx_tuned", true)
	rim.mesh = tm
	rim.position.y = 0.15
	n.add_child(rim)
	var cream := _m(Color("#fff7ea"), 0.32)
	_sphere(n, 0.8, Vector3(0, 0.2, 0), cream, Vector3(1, 0.42, 1), 18)
	for k in 7:
		var a := TAU * k / 7.0
		_sphere(n, 0.17, Vector3(cos(a) * 0.62, 0.38, sin(a) * 0.62), cream, Vector3(1, 0.8, 1), 10)
	_sphere(n, 0.19, Vector3(0, 0.6, 0), _m(Color("#e0203a"), 0.12, 0.05), Vector3.ONE, 12)
	_cyl(n, 0.02, 0.025, 0.28, Vector3(0.05, 0.82, 0), _m(Color("#3f8a2a"), 0.6), 6).rotation.z = -0.35
	n.scale = Vector3.ONE * scale
	return n


## Konfetti-Bonbon: gestreifte Kugel (drei davon fliegen als Salve).
static func candy(col: Color, scale := 1.0) -> Node3D:
	var n := Node3D.new()
	_sphere(n, 0.42, Vector3.ZERO, _m(col, 0.18, 0.05), Vector3.ONE, 14)
	for k in 3:
		var band := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.38
		tm.outer_radius = 0.45
		tm.rings = 16
		tm.ring_segments = 6
		tm.material = _m(Color(1, 1, 1), 0.2)
		tm.set_meta("gfx_tuned", true)
		band.mesh = tm
		band.rotation = Vector3(0.6 + k * 1.05, k * 0.8, 0.3)
		n.add_child(band)
	n.scale = Vector3.ONE * scale
	return n


## Homing-Kanonenkugel mit fiesem Grinsen: Metallkugel, böse Augen, glimmende Lunte.
static func cannonball(scale := 1.0) -> Node3D:
	var n := Node3D.new()
	var iron := _m(Color("#24242e"), 0.32, 0.75)
	_sphere(n, 0.72, Vector3.ZERO, iron, Vector3.ONE, 18)
	_cyl(n, 0.22, 0.26, 0.18, Vector3(0, 0.72, 0), iron, 10)
	var fuse := _cyl(n, 0.045, 0.045, 0.38, Vector3(0.06, 0.95, 0), _m(Color("#b08050"), 0.9), 6)
	fuse.rotation.z = -0.4
	_sphere(n, 0.07, Vector3(0.14, 1.12, 0), _m(Color("#ffb030"), 0.4, 0.0, 3.0), Vector3.ONE, 8)
	var white := _m(Color("#fff4e0"), 0.4)
	var black := _m(Color("#0c0c10"), 0.3)
	var red := _m(Color("#ff3355"), 0.4, 0.0, 1.2)
	for sx: float in [-1.0, 1.0]:
		_sphere(n, 0.16, Vector3(sx * 0.24, 0.12, -0.62), white, Vector3(1, 0.85, 0.5), 10)
		_sphere(n, 0.08, Vector3(sx * 0.22, 0.1, -0.7), red, Vector3(1, 1, 0.6), 8)
		_box(n, Vector3(0.28, 0.06, 0.06), Vector3(sx * 0.26, 0.32, -0.66), black, Vector3(0, 0, sx * 0.45))
	var grin := _box(n, Vector3(0.42, 0.06, 0.06), Vector3(0, -0.2, -0.68), black)
	grin.rotation.x = 0.2
	n.scale = Vector3.ONE * scale
	return n


## Piraten-Anker an einem Stück Kette.
static func anchor(scale := 1.0) -> Node3D:
	var n := Node3D.new()
	var steel := _m(Color("#8496b4"), 0.3, 0.8)
	_cyl(n, 0.11, 0.13, 2.0, Vector3.ZERO, steel, 10)
	_box(n, Vector3(1.0, 0.14, 0.14), Vector3(0, 0.62, 0), steel)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.14
	tm.outer_radius = 0.24
	tm.material = steel
	ring.mesh = tm
	ring.rotation.x = PI * 0.5
	ring.position.y = 1.14
	n.add_child(ring)
	var arm := MeshInstance3D.new()
	var tm2 := TorusMesh.new()
	tm2.inner_radius = 0.58
	tm2.outer_radius = 0.76
	tm2.rings = 18
	tm2.material = steel
	arm.mesh = tm2
	arm.rotation.x = PI * 0.5
	arm.position.y = -0.55
	n.add_child(arm)
	var fluke := PrismMesh.new()
	fluke.size = Vector3(0.36, 0.42, 0.16)
	fluke.material = steel
	for sx: float in [-1.0, 1.0]:
		var f := MeshInstance3D.new()
		f.mesh = fluke
		f.position = Vector3(sx * 0.7, -0.38, 0)
		f.rotation.z = sx * 0.5
		n.add_child(f)
	for k in 3:   # Kettenglieder
		var link := MeshInstance3D.new()
		var tl := TorusMesh.new()
		tl.inner_radius = 0.08
		tl.outer_radius = 0.15
		tl.material = _m(Color("#6c6c78"), 0.4, 0.8)
		link.mesh = tl
		link.position = Vector3(0, 1.36 + k * 0.22, 0)
		link.rotation = Vector3(PI * 0.5, (k % 2) * PI * 0.5, 0)
		n.add_child(link)
	n.scale = Vector3.ONE * scale
	return n


## Honigtopf (im Flug) – glasierter Ton, triefender Honig am Rand.
static func honey_pot(scale := 1.0) -> Node3D:
	var n := Node3D.new()
	var clay := _m(Color("#d58a3a"), 0.4)
	_sphere(n, 0.55, Vector3.ZERO, clay, Vector3(1, 0.9, 1), 14)
	_cyl(n, 0.34, 0.4, 0.22, Vector3(0, 0.5, 0), clay, 12)
	var honey := _m(Color("#ffb21e"), 0.08, 0.0, 0.25)
	_sphere(n, 0.36, Vector3(0, 0.6, 0), honey, Vector3(1, 0.4, 1), 12)
	for k in 3:
		var a := TAU * k / 3.0 + 0.4
		_sphere(n, 0.09, Vector3(cos(a) * 0.38, 0.42 - k * 0.07, sin(a) * 0.38), honey, Vector3(1, 1.8, 1), 8)
	_box(n, Vector3(0.7, 0.12, 0.04), Vector3(0, 0.05, -0.53), _m(Color("#ffffff"), 0.5))
	n.scale = Vector3.ONE * scale
	return n


## Honigpfütze auf der Fahrbahn – glänzend, leicht durchscheinend, mit Bläschen.
static func honey_puddle(radius := 1.6) -> Node3D:
	var n := Node3D.new()
	var honey := _m(Color(1.0, 0.68, 0.12, 0.88), 0.05, 0.0, 0.35)
	_cyl(n, radius, radius * 1.05, 0.06, Vector3(0, 0.03, 0), honey, 22)
	for k in 5:
		var a := TAU * k / 5.0 + 0.7
		_cyl(n, radius * 0.32, radius * 0.36, 0.05, Vector3(cos(a) * radius * 0.85, 0.025, sin(a) * radius * 0.85), honey, 12)
	for k in 4:
		var a2 := TAU * k / 4.0 + 0.2
		_sphere(n, 0.08 + k * 0.02, Vector3(cos(a2) * radius * 0.45, 0.08, sin(a2) * radius * 0.45), _m(Color(1, 0.9, 0.55, 0.8), 0.05), Vector3.ONE, 8)
	return n


## Donnerwolke: dunkle Kumuluswolke mit gelbem Blitz.
static func thunder_cloud(scale := 1.0) -> Node3D:
	var n := Node3D.new()
	var dark := _m(Color("#5a5e74"), 0.85)
	var light := _m(Color("#7c8098"), 0.85)
	for e in [[Vector3(0, 0, 0), 0.9], [Vector3(0.85, -0.1, 0.1), 0.7], [Vector3(-0.8, -0.12, -0.05), 0.72], [Vector3(0.3, 0.42, 0), 0.62], [Vector3(-0.35, 0.36, 0.1), 0.55]]:
		_sphere(n, float(e[1]), e[0], dark if (e[0] as Vector3).y <= 0.0 else light, Vector3(1, 0.8, 1), 12)
	var bolt := _m(Color("#ffe14a"), 0.4, 0.0, 2.5)
	_box(n, Vector3(0.18, 0.7, 0.1), Vector3(0.05, -0.95, 0), bolt, Vector3(0, 0, 0.45))
	_box(n, Vector3(0.18, 0.6, 0.1), Vector3(-0.1, -1.45, 0), bolt, Vector3(0, 0, -0.45))
	n.scale = Vector3.ONE * scale
	return n


## Kometenritt: glühender Stern vor dem Kart (Rammbock) – sichtbar für alle. Räumliche Zacken (von jeder Seite ein
## Stern), schwache Aura und nach hinten gezogene Flammenzungen. Leuchtkraft ≤ 1.2, damit die Farbe nicht weiß ausbrennt.
static func comet(scale := 1.0) -> Node3D:
	var n := Node3D.new()
	var core := _m(Color("#ffc21a"), 0.3, 0.0, 1.1)
	var tip := _m(Color("#ff8a1f"), 0.35, 0.0, 1.0)
	_sphere(n, 0.55, Vector3.ZERO, core, Vector3.ONE, 14)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.24
	cone.height = 0.7
	cone.radial_segments = 8
	cone.material = tip
	for k in 5:
		var a := TAU * k / 5.0
		var spike := MeshInstance3D.new()
		spike.mesh = cone
		spike.rotation.z = -a
		spike.position = Vector3(sin(a), cos(a), 0) * 0.72
		spike.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(spike)
	var aura := _m(Color(1.0, 0.75, 0.3, 0.18), 0.5, 0.0, 0.8)
	_sphere(n, 1.05, Vector3.ZERO, aura, Vector3(1, 1, 1.25), 14).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var flame := _m(Color(1.0, 0.45, 0.12, 0.38), 0.5, 0.0, 1.0)
	for e in [[Vector3(0, 0.25, 1.3), 0.42], [Vector3(-0.35, -0.15, 1.15), 0.3], [Vector3(0.35, -0.15, 1.15), 0.3]]:
		var fm := CylinderMesh.new()
		fm.top_radius = float(e[1])
		fm.bottom_radius = 0.0
		fm.height = 2.2
		fm.radial_segments = 8
		fm.material = flame
		var f := MeshInstance3D.new()
		f.mesh = fm
		f.rotation.x = -PI * 0.5   # Spitze zeigt nach hinten (+Z)
		f.position = e[0] + Vector3(0, 0, 0.4)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(f)
	n.scale = Vector3.ONE * scale
	return n


## Funkenkern: kleiner, blau leuchtender Kristall mit Energiering, der um das Kart kreist.
static func spark_core(scale := 1.0) -> Node3D:
	var n := Node3D.new()
	var gem := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	sm.radial_segments = 6
	sm.rings = 2
	sm.material = _m(Color("#3fb8ff"), 0.15, 0.2, 1.0)
	sm.set_meta("gfx_tuned", true)
	gem.mesh = sm
	gem.scale = Vector3(1, 1.6, 1)
	gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(gem)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.3
	tm.outer_radius = 0.35
	tm.rings = 16
	tm.ring_segments = 4
	tm.material = _m(Color(0.75, 0.95, 1.0, 0.7), 0.2, 0.0, 1.2)
	ring.mesh = tm
	ring.rotation.x = 1.1
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(ring)
	n.scale = Vector3.ONE * scale
	return n


## Schutzhülle: "bubble" = schillernde Seifenblase, "mirror" = sechseckiger Spiegelschild.
static func shield(kind: String, kart_scale := 2.2) -> MeshInstance3D:
	var k := kart_scale / 2.2
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if kind == "mirror":
		# Spiegelschild: sechs schwebende Sechseck-Spiegel auf einem Leuchtring (kreisen ums Kart, siehe KartVisual)
		var ring := TorusMesh.new()
		ring.inner_radius = 1.86 * k
		ring.outer_radius = 1.94 * k
		ring.rings = 24
		ring.ring_segments = 6
		var rm := _m(Color(0.6, 0.85, 1.0, 0.55), 0.2, 0.0, 1.2)
		ring.material = rm
		ring.set_meta("gfx_tuned", true)
		mi.mesh = ring
		var pm := _m(Color(0.86, 0.94, 1.0), 0.1, 0.3, 0.45)
		pm.rim_enabled = true
		pm.rim = 0.8
		pm.emission = Color(0.55, 0.8, 1.0)
		var fm := _m(Color(0.95, 0.8, 0.35), 0.3, 0.8)
		for a in 6:
			var ang := TAU * a / 6.0
			var pivot := Node3D.new()
			pivot.rotation.y = ang
			mi.add_child(pivot)
			var plate := MeshInstance3D.new()
			var hm := CylinderMesh.new()
			hm.top_radius = 0.44 * k
			hm.bottom_radius = 0.44 * k
			hm.height = 0.05 * k
			hm.radial_segments = 6
			hm.rings = 1
			hm.material = pm
			plate.mesh = hm
			plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			plate.position = Vector3(0, 0.22 * k * (1.0 if a % 2 == 0 else -1.0), -1.9 * k)
			plate.rotation.x = PI * 0.5   # Spiegelfläche zeigt nach außen
			pivot.add_child(plate)
			var frame := MeshInstance3D.new()   # goldener Rand
			var fr := TorusMesh.new()
			fr.inner_radius = 0.4 * k
			fr.outer_radius = 0.47 * k
			fr.rings = 6
			fr.ring_segments = 4
			fr.material = fm
			frame.mesh = fr
			frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			plate.add_child(frame)
	else:
		var sm := SphereMesh.new()
		sm.radius = 2.1 * k
		sm.height = 3.6 * k
		sm.radial_segments = 20
		sm.rings = 10
		var m2 := _m(Color(0.72, 0.92, 1.0, 0.16), 0.05)
		m2.rim_enabled = true
		m2.rim = 1.0
		m2.rim_tint = 0.2
		m2.emission_enabled = true
		m2.emission = Color(0.5, 0.75, 1.0)
		m2.emission_energy_multiplier = 0.25
		sm.material = m2
		sm.set_meta("gfx_tuned", true)
		mi.mesh = sm
		var hl := MeshInstance3D.new()
		var hs := SphereMesh.new()
		hs.radius = 0.28 * k
		hs.height = 0.4 * k
		hs.material = _m(Color(1, 1, 1, 0.6), 0.1, 0.0, 1.0)
		hl.mesh = hs
		hl.position = Vector3(-0.9, 1.1, -0.8) * k
		mi.add_child(hl)
	return mi


# --- Katalog ----------------------------------------------------------------------------------------------

## Alle Items in Anzeige-Reihenfolge, mit Namen, HUD-Icon und Kurzbeschreibung (für Hilfe/Doku).
const INFO := {
	"pie": {"name": "Kuchendeckel", "icon": "pie", "desc": "Fliegt nach vorn und prallt an den Banden ab – Sahne im Gesicht."},
	"candy": {"name": "Konfetti-Salve", "icon": "candy", "desc": "Drei Bonbons im Fächer – schwer auszuweichen."},
	"homing": {"name": "Homing-Kanonenkugel", "icon": "cannonball", "desc": "Verfolgt den Vordermann und wirft ihn um."},
	"anchor": {"name": "Piraten-Anker", "icon": "anchor", "desc": "Hakt sich beim Nächsten vor dir ein: 18 m zurück."},
	"megaphone": {"name": "Megafon-Schock", "icon": "megaphone", "desc": "Schockwelle: Wer nah dran ist, schrumpft oder dreht sich."},
	"nitro": {"name": "Nitro", "icon": "nitro", "desc": "Kräftiger Boost."},
	"honey": {"name": "Honigfalle", "icon": "honey", "desc": "Nach hinten werfen – die Pfütze klebt und bremst."},
	"bubble": {"name": "Seifenblase", "icon": "bubble", "desc": "Schützt 10 s lang vor einem Treffer."},
	"mirror": {"name": "Spiegelschild", "icon": "mirror", "desc": "Das nächste Geschoss fliegt zum Absender zurück."},
	"spark": {"name": "Funkenkern", "icon": "spark", "desc": "7 s: Drift lädt fast doppelt so schnell, Boosts halten länger."},
	"thunder": {"name": "Donnerwolke", "icon": "thunder", "desc": "Stromschlag für alle vor dir – kurz, aber ärgerlich."},
	"comet": {"name": "Kometenritt", "icon": "comet", "desc": "Selten, nur weit hinten: 4 s Autopilot, unverwundbar, rempelt alle weg."},
}


static func icon_of(kind: String) -> String:
	return String((INFO.get(kind, {}) as Dictionary).get("icon", "question"))


static func name_of(kind: String) -> String:
	return String((INFO.get(kind, {}) as Dictionary).get("name", ""))
