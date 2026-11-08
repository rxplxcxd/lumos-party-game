class_name TrackDefs
extends RefCounted
## Streckendefinitionen für Nitro Dash. Jede Strecke ist eine geschlossene Folge von
## Kontrollpunkten; Loopings werden analytisch erzeugt (inkl. seitlichem Versatz, damit sich
## die Fahrbahn nicht selbst schneidet). Abschnitte werden über Punkt-Indizes markiert.
##
## Rückgabe: {points, width, env, theme, loops:[{from,to,axis_point,axis_dir}], glide:[[a,b]],
##            water:[[a,b]], ice:[[a,b]], ramps:[i], boosts:[[i,lateral]], items:[i], bank:{i:deg}}

static func get_def(id: String) -> Dictionary:
	match id:
		"coral_canal":
			return _coral()
		"neon_volcano":
			return _neon()
		"storm_pass":
			return _storm()
		"frost_peak":
			return _frost()
		"orbit_ring":
			return _orbit()
		"city_rally":
			return _city()
		"desert_canyon":
			return _desert()
		_:
			return _ring()


static func _base(id: String, name: String, env: String, theme: String, width := 15.0) -> Dictionary:
	return {"id": id, "name": name, "env": env, "theme": theme, "width": width,
		"loops": [], "glide": [], "water": [], "ice": [], "ramps": [], "boosts": [], "items": [], "bank": {}, "ground_y": -0.15}


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
	var d := {"id": "neon_volcano", "name": "Vulkan-Inselchen", "env": "sunset", "theme": "volcano", "width": 15.0,
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


## Gewitter-Pass: Nachtfahrt über einen Bergpass im Unwetter. Lange, helle Blitze, Leuchtmarkierungen
## an den Leitplanken, nasse Fahrbahn, Sprung über eine Schlucht.
static func _storm() -> Dictionary:
	var d := _base("storm_pass", "Gewitter-Pass", "storm", "storm")
	var p: Array = []
	p.append(Vector3(0, 0, 40))       # 0 Start
	p.append(Vector3(0, 0, -6))       # 1
	p.append(Vector3(12, 1, -44))     # 2
	p.append(Vector3(36, 3, -66))     # 3 Anstieg
	p.append(Vector3(66, 6, -72))     # 4
	p.append(Vector3(94, 8, -60))     # 5
	p.append(Vector3(110, 8, -36))    # 6
	p.append(Vector3(112, 9.5, -14))  # 7 Rampe
	p.append(Vector3(110, 14, 4))     # 8 Absprung
	p.append(Vector3(104, 15, 28))    # 9 Gleiter über die Schlucht
	p.append(Vector3(94, 9, 52))      # 10
	p.append(Vector3(84, 4, 72))      # 11 Landung
	p.append(Vector3(62, 2, 86))      # 12
	p.append(Vector3(36, 1, 92))      # 13
	p.append(Vector3(14, 0, 84))      # 14
	p.append(Vector3(2, 0, 64))       # 15
	d.points = p
	d.glide = [[8, 11]]
	d.ramps = [7]
	d.boosts = [[1, 0.0], [5, -3.0], [13, 2.0]]
	d.items = [2, 6, 12, 15]
	d.bank = {3: -8, 5: 10, 12: 8, 14: -8}
	return d


## Frostgipfel: Verschneite Bergstraße mit glatten Eisplatten und einer Skisprungschanze.
static func _frost() -> Dictionary:
	var d := _base("frost_peak", "Frostgipfel", "snow", "snow")
	var p: Array = []
	p.append(Vector3(0, 0, 40))       # 0 Start
	p.append(Vector3(0, 0, -4))       # 1
	p.append(Vector3(-14, 0, -40))    # 2
	p.append(Vector3(-40, 0, -58))    # 3 Eis
	p.append(Vector3(-70, 2, -56))    # 4
	p.append(Vector3(-92, 5, -38))    # 5
	p.append(Vector3(-98, 7, -12))    # 6
	p.append(Vector3(-96, 9, 8))      # 7 Schanze
	p.append(Vector3(-90, 14, 26))    # 8 Absprung
	p.append(Vector3(-80, 13, 50))    # 9 Gleiter
	p.append(Vector3(-66, 6, 70))     # 10
	p.append(Vector3(-50, 1, 82))     # 11 Landung
	p.append(Vector3(-26, 0, 94))     # 12 Eis
	p.append(Vector3(-4, 0, 90))      # 13
	p.append(Vector3(10, 0, 72))      # 14
	p.append(Vector3(4, 0, 58))       # 15
	d.points = p
	d.glide = [[8, 11]]
	d.ramps = [7]
	d.ice = [[2, 4], [12, 14]]
	d.boosts = [[1, 0.0], [5, 3.0], [13, -2.0]]
	d.items = [2, 6, 12, 15]
	d.bank = {3: 8, 5: -10, 12: -8, 14: 8}
	return d


## Sternenstaub-Bahn: Schwebende Pastell-Fahrbahn im Abendhimmel mit Looping und langem Schwebe-Gleiter.
static func _orbit() -> Dictionary:
	var d := _base("orbit_ring", "Sternenstaub-Bahn", "observatory", "space")
	var p: Array = []
	p.append(Vector3(0, 0, 40))       # 0 Start
	p.append(Vector3(0, 0, -8))       # 1
	p.append(Vector3(10, 2, -46))     # 2
	p.append(Vector3(34, 4, -64))     # 3
	p.append(Vector3(56, 4, -66))     # 4
	_loop(p, d, Vector3(74, 4, -66), Vector3(1, 0, 0), Vector3(0, 0, 1), 13.0, 19.0)   # 5..13
	p.append(Vector3(94, 4, -44))     # 14
	p.append(Vector3(108, 6, -22))    # 15
	p.append(Vector3(112, 8, 0))      # 16 Rampe
	p.append(Vector3(110, 13, 20))    # 17 Absprung
	p.append(Vector3(100, 16, 48))    # 18 Schwerelos
	p.append(Vector3(84, 10, 72))     # 19
	p.append(Vector3(64, 4, 84))      # 20 Landung
	p.append(Vector3(38, 2, 90))      # 21
	p.append(Vector3(14, 0, 80))      # 22
	p.append(Vector3(2, 0, 62))       # 23
	d.points = p
	d.glide = [[17, 20]]
	d.ramps = [16]
	d.boosts = [[1, 0.0], [14, -3.0], [21, 3.0]]
	d.items = [2, 15, 21, 23]
	d.bank = {3: -10, 15: -8, 21: 8, 22: 10}
	return d


## Stadt-Rallye: Enge 90°-Kurven durch die Innenstadt, Sprung über einen Kanal.
static func _city() -> Dictionary:
	var d := _base("city_rally", "Stadt-Rallye", "day", "city", 14.0)
	var p: Array = []
	p.append(Vector3(0, 0, 40))       # 0 Start
	p.append(Vector3(0, 0, -10))      # 1
	p.append(Vector3(4, 0, -40))      # 2
	p.append(Vector3(24, 0, -52))     # 3
	p.append(Vector3(56, 0, -52))     # 4
	p.append(Vector3(76, 0, -40))     # 5
	p.append(Vector3(80, 0, -12))     # 6
	p.append(Vector3(80, 1.2, 6))     # 7 Rampe
	p.append(Vector3(80, 4.5, 20))    # 8 Absprung
	p.append(Vector3(80, 3.5, 36))    # 9 Kanal
	p.append(Vector3(80, 0, 52))      # 10 Landung
	p.append(Vector3(70, 0, 74))      # 11
	p.append(Vector3(46, 0, 80))      # 12
	p.append(Vector3(22, 0, 72))      # 13
	p.append(Vector3(6, 0, 60))       # 14
	d.points = p
	d.glide = [[8, 10]]
	d.ramps = [7]
	d.boosts = [[1, 0.0], [4, 2.0], [12, -2.0]]
	d.items = [2, 5, 11, 14]
	d.bank = {3: -6, 5: -6, 11: -6, 13: -6}
	return d


## Wüsten-Canyon: Sandpiste mit Looping und Gleitflug über eine tiefe Schlucht.
static func _desert() -> Dictionary:
	var d := _base("desert_canyon", "Wüsten-Canyon", "desert", "desert")
	var p: Array = []
	p.append(Vector3(0, 0, 40))       # 0 Start
	p.append(Vector3(0, 0, -6))       # 1
	p.append(Vector3(-10, 0, -44))    # 2
	p.append(Vector3(-34, 0, -64))    # 3
	p.append(Vector3(-58, 0, -66))    # 4
	_loop(p, d, Vector3(-76, 0, -66), Vector3(-1, 0, 0), Vector3(0, 0, 1), 12.0, 18.0)   # 5..13
	p.append(Vector3(-96, 0, -46))    # 14
	p.append(Vector3(-112, 0, -26))   # 15
	p.append(Vector3(-116, 0, 0))     # 16
	p.append(Vector3(-114, 1.5, 16))  # 17 Rampe
	p.append(Vector3(-110, 7, 34))    # 18 Absprung
	p.append(Vector3(-100, 8, 58))    # 19 Schlucht
	p.append(Vector3(-86, 3, 80))     # 20
	p.append(Vector3(-70, 0, 96))     # 21 Landung
	p.append(Vector3(-44, 0, 104))    # 22
	p.append(Vector3(-18, 0, 96))     # 23
	p.append(Vector3(-4, 0, 78))      # 24
	p.append(Vector3(0, 0, 60))       # 25
	d.points = p
	d.glide = [[18, 21]]
	d.ramps = [17]
	d.boosts = [[1, 0.0], [15, 3.0], [22, -3.0]]
	d.items = [2, 14, 22, 25]
	d.bank = {3: 8, 15: 10, 22: -8, 23: -8}
	return d
