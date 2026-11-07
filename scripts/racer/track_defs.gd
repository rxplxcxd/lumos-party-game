class_name TrackDefs
extends RefCounted
## Streckendefinitionen für Nitro Dash. Jede Strecke ist eine geschlossene Folge von
## Kontrollpunkten; Loopings werden analytisch erzeugt (inkl. seitlichem Versatz, damit sich
## die Fahrbahn nicht selbst schneidet). Abschnitte werden über Punkt-Indizes markiert.
##
## Rückgabe: {points, width, env, theme, loops:[{from,to,axis_point,axis_dir}], glide:[[a,b]],
##            water:[[a,b]], ramps:[i], boosts:[[i,lateral]], items:[i], bank:{i:deg}}

static func get_def(id: String) -> Dictionary:
	match id:
		"coral_canal":
			return _coral()
		"neon_volcano":
			return _neon()
		_:
			return _ring()


## Erzeugt Looping-Punkte. entry = unterster Punkt, dir = Fahrtrichtung, lat = Versatzrichtung.
static func _loop(pts: Array, d: Dictionary, entry: Vector3, dir: Vector3, lat: Vector3, r: float, shift: float) -> void:
	var start := pts.size()
	for k in 9:
		var th := TAU * k / 8.0
		pts.append(entry + dir * (r * sin(th)) + Vector3.UP * (r - r * cos(th)) + lat * (shift * th / TAU))
	(d.loops as Array).append({"from": start, "to": start + 8, "center": entry + Vector3.UP * r, "axis": lat, "radius": r})


static func _ring() -> Dictionary:
	var d := {"id": "lumos_ring", "name": "Lumos-Ring", "env": "day", "theme": "ring", "width": 16.0,
		"loops": [], "glide": [], "water": [], "ramps": [], "boosts": [], "items": [], "bank": {}, "ground_y": -0.15}
	var p: Array = []
	p.append(Vector3(0, 0, 40))       # 0 Start
	p.append(Vector3(0, 0, -20))      # 1
	p.append(Vector3(8, 0, -62))      # 2
	p.append(Vector3(32, 0, -84))     # 3
	p.append(Vector3(62, 0, -88))     # 4
	p.append(Vector3(84, 0, -88))     # 5
	_loop(p, d, Vector3(100, 0, -88), Vector3(1, 0, 0), Vector3(0, 0, 1), 12.0, 18.0)   # 6..14
	p.append(Vector3(118, 0, -70))    # 15
	p.append(Vector3(142, 0, -68))    # 16
	p.append(Vector3(164, 0, -48))    # 17
	p.append(Vector3(172, 0, -18))    # 18
	p.append(Vector3(173, 1.5, 2))    # 19 Rampe
	p.append(Vector3(173, 6, 18))     # 20 Absprung
	p.append(Vector3(172, 7, 40))     # 21 Gleiter
	p.append(Vector3(170, 3, 66))     # 22
	p.append(Vector3(167, 0, 86))     # 23 Landung
	p.append(Vector3(156, 0, 112))    # 24
	p.append(Vector3(132, 0, 128))    # 25
	p.append(Vector3(100, 0, 130))    # 26
	p.append(Vector3(72, 0, 118))     # 27
	p.append(Vector3(46, 0, 128))     # 28
	p.append(Vector3(20, 0, 116))     # 29
	p.append(Vector3(4, 0, 90))       # 30
	p.append(Vector3(0, 0, 64))       # 31
	d.points = p
	d.glide = [[20, 23]]
	d.ramps = [19]
	d.boosts = [[1, 0.0], [17, -3.0], [26, 3.0]]
	d.items = [2, 16, 24, 29]
	d.bank = {3: -8, 17: -10, 24: 8, 25: 10, 28: -6}
	return d


static func _coral() -> Dictionary:
	var d := {"id": "coral_canal", "name": "Korallen-Kanal", "env": "pirates", "theme": "pirates", "width": 15.0,
		"loops": [], "glide": [], "water": [], "ramps": [], "boosts": [], "items": [], "bank": {}, "ground_y": -0.15}
	var p: Array = []
	p.append(Vector3(0, 0, 40))       # 0 Start
	p.append(Vector3(0, 0, -10))      # 1
	p.append(Vector3(10, 0, -50))     # 2
	p.append(Vector3(40, 0, -72))     # 3
	p.append(Vector3(76, 0, -74))     # 4
	p.append(Vector3(100, -2, -68))   # 5 Tunnel-Einfahrt
	p.append(Vector3(120, -8, -55))   # 6
	p.append(Vector3(135, -12, -30))  # 7
	p.append(Vector3(139, -12, 0))    # 8
	p.append(Vector3(132, -10, 30))   # 9
	p.append(Vector3(116, -5, 50))    # 10
	p.append(Vector3(95, -0.5, 62))   # 11 Tunnel-Ausfahrt
	p.append(Vector3(74, 0, 70))      # 12
	p.append(Vector3(56, 1.2, 74))    # 13 Rampe
	p.append(Vector3(40, 3.0, 78))    # 14
	p.append(Vector3(26, 0, 80))      # 15
	p.append(Vector3(10, 0, 72))      # 16
	p.append(Vector3(0, 0, 58))       # 17
	d.points = p
	d.water = [[5, 11]]
	d.ramps = [13]
	d.boosts = [[1, 2.0], [7, 0.0], [12, -2.0]]
	d.items = [2, 6, 9, 15]
	d.bank = {3: -8, 7: 10, 9: 8, 16: -8}
	return d


static func _neon() -> Dictionary:
	var d := {"id": "neon_volcano", "name": "Neon-Vulkan", "env": "night", "theme": "neon", "width": 15.0,
		"loops": [], "glide": [], "water": [], "ramps": [], "boosts": [], "items": [], "bank": {}, "ground_y": -0.15}
	var p: Array = []
	p.append(Vector3(0, 0, 40))       # 0 Start
	p.append(Vector3(0, 0, -4))       # 1
	p.append(Vector3(16, 0, -40))     # 2
	p.append(Vector3(44, 0, -56))     # 3
	p.append(Vector3(62, 0, -57))     # 4
	_loop(p, d, Vector3(78, 0, -57), Vector3(1, 0, 0), Vector3(0, 0, 1), 14.0, 19.0)    # 5..13
	p.append(Vector3(96, 0, -38))     # 14
	p.append(Vector3(114, 0, -24))    # 15
	p.append(Vector3(120, 0, 0))      # 16
	p.append(Vector3(120, 1.5, 14))   # 17 Rampe
	p.append(Vector3(119, 7, 30))     # 18 Absprung
	p.append(Vector3(114, 9, 52))     # 19 Gleiter über Lava
	p.append(Vector3(104, 4, 78))     # 20
	p.append(Vector3(92, 0, 98))      # 21 Landung
	p.append(Vector3(66, 0, 110))     # 22
	p.append(Vector3(36, 0, 104))     # 23
	p.append(Vector3(14, 0, 86))      # 24
	p.append(Vector3(2, 0, 64))       # 25
	d.points = p
	d.glide = [[18, 21]]
	d.ramps = [17]
	d.boosts = [[1, 0.0], [15, 3.0], [22, -3.0], [24, 0.0]]
	d.items = [2, 14, 22, 25]
	d.bank = {2: -8, 15: -10, 22: 8, 23: 8}
	return d
