extends RefCounted
## Eingefrorener Lumos-Ring für den Trailer (Stand Spiel 1.3.0).
## Die Kamerafahrten der Nitro-Dash-Szene sind auf genau diesen Streckenverlauf choreografiert. Das Spiel darf
## seine Strecken weiterentwickeln (1.4.0: komplett neuer Lumos-Ring), ohne dass sich der Trailer verändert.
## Nur der Trailer liest diese Datei; das Spiel verweist nie hierher (siehe trailer/check_isolation.sh).


static func lumos_ring() -> Dictionary:
	var d := {"id": "lumos_ring", "name": "Lumos-Ring", "env": "day", "theme": "ring", "width": 16.0,
		"loops": [], "glide": [], "water": [], "ice": [], "ramps": [], "boosts": [], "items": [], "bank": {}, "ground_y": -0.15}
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


## Looping-Punkte. entry = unterster Punkt, dir = Fahrtrichtung, lat = Versatzrichtung.
static func _loop(pts: Array, d: Dictionary, entry: Vector3, dir: Vector3, lat: Vector3, r: float, shift: float) -> void:
	var start := pts.size()
	for k in 9:
		var th := TAU * k / 8.0
		pts.append(entry + dir * (r * sin(th)) + Vector3.UP * (r - r * cos(th)) + lat * (shift * th / TAU))
	(d.loops as Array).append({"from": start, "to": start + 8, "center": entry + Vector3.UP * r, "axis": lat, "radius": r})
