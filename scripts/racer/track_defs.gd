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
		"glow_forest":
			return _glow()
		"candy_lane":
			return _candy()
		"jungle_ruins":
			return _jungle()
		"falls_gorge":
			return _falls()
		_:
			return _ring()


static func _base(id: String, name: String, env: String, theme: String, width := 15.0) -> Dictionary:
	return {"id": id, "name": name, "env": env, "theme": theme, "width": width,
		"loops": [], "glide": [], "water": [], "ice": [], "ramps": [], "boosts": [], "items": [], "bank": {}, "ground_y": -0.15}


## Streckenbaukasten: Befehle → Kontrollpunkte (alle ~16 m), Runde schließt sich selbst.
##   ["S", länge, dy]            Gerade (dy = Höhenänderung über die Strecke, weich)
##   ["L"/"R", radius, grad, dy] Links-/Rechtskurve mit festem Radius
##   ["LOOP", radius, versatz]   Looping (seitlicher Versatz, damit sich die Fahrbahn nicht schneidet)
##   ["T", "name"]               Marke: Index des aktuellen Punkts (für Rampen, Gleiter, Boxen, Gefahren …)
## Rückgabe: Marken-Dictionary. Die Punkte landen in d.points. Kleine Restfehler beim Schließen werden gleichmäßig
## über die Runde verteilt (der Kurs muss sich also ungefähr selbst schließen – die Prüfung zeigt das).
static func build_path(d: Dictionary, cmds: Array, start := Vector3(0, 0, 40), heading := Vector3(0, 0, -1)) -> Dictionary:
	var pts: Array = [start]
	var tags := {}
	var pos := start
	var dir := Vector3(heading.x, 0, heading.z).normalized()
	for c: Array in cmds:
		match String(c[0]):
			"T":
				tags[String(c[1])] = pts.size() - 1
			"S":
				var ln := float(c[1])
				var dy := float(c[2]) if c.size() > 2 else 0.0
				var n := maxi(1, ceili(ln / 16.0))
				var y0 := pos.y
				var p0 := pos
				for k in range(1, n + 1):
					var u := float(k) / n
					pos = p0 + dir * ln * u
					pos.y = y0 + dy * (u * u * (3.0 - 2.0 * u))
					pts.append(pos)
			"L", "R":
				var r := float(c[1])
				var ang := deg_to_rad(float(c[2])) * (1.0 if String(c[0]) == "L" else -1.0)
				var dy2 := float(c[3]) if c.size() > 3 else 0.0
				var side := dir.rotated(Vector3.UP, PI * 0.5 * signf(ang))
				var center := Vector3(pos.x, 0, pos.z) + side * r
				var rel := Vector3(pos.x, 0, pos.z) - center
				var n2 := maxi(2, ceili(absf(ang) * r / 14.0))
				var y1 := pos.y
				for k in range(1, n2 + 1):
					var u2 := float(k) / n2
					var q := center + rel.rotated(Vector3.UP, ang * u2)
					pos = Vector3(q.x, y1 + dy2 * (u2 * u2 * (3.0 - 2.0 * u2)), q.z)
					pts.append(pos)
				dir = dir.rotated(Vector3.UP, ang)
			"CLOSE":   # Rundenschluss: Kurve – Gerade – Kurve (Dubins, LSL/RSR) zurück auf Start und Startrichtung
				for q: Array in _dubins(pos, dir, float(c[1]), start, heading):
					if String(q[0]) == "S":
						var ln3 := float(q[1])
						var n3 := maxi(1, ceili(ln3 / 16.0))
						var p3 := pos
						for k in range(1, n3 + 1):
							pos = p3 + dir * ln3 * (float(k) / n3)
							pts.append(pos)
					elif absf(float(q[2])) > 0.01:
						var r3 := float(q[1])
						var ang3 := deg_to_rad(float(q[2])) * (1.0 if String(q[0]) == "L" else -1.0)
						var side3 := dir.rotated(Vector3.UP, PI * 0.5 * signf(ang3))
						var center3 := Vector3(pos.x, 0, pos.z) + side3 * r3
						var rel3 := Vector3(pos.x, 0, pos.z) - center3
						var n4 := maxi(2, ceili(absf(ang3) * r3 / 14.0))
						var y3 := pos.y
						for k in range(1, n4 + 1):
							var qq := center3 + rel3.rotated(Vector3.UP, ang3 * float(k) / n4)
							pos = Vector3(qq.x, y3, qq.z)
							pts.append(pos)
						dir = dir.rotated(Vector3.UP, ang3)
			"LOOP":
				var lat := dir.rotated(Vector3.UP, -PI * 0.5)   # nach rechts versetzt
				var entry := pos + dir * 16.0
				_loop(pts, d, entry, dir, lat, float(c[1]), float(c[2]))
				pos = entry + lat * float(c[2])
	# Schließen: letzten Punkt weglassen, wenn er (fast) auf dem Start liegt, Restfehler verteilen
	var err: Vector3 = (pos - start)
	var m0 := pts.size()
	for i in m0:
		pts[i] = (pts[i] as Vector3) - err * (float(i) / m0)
	# Zu dicht liegende Punkte (Mini-Bögen des Rundenschlusses, Doppelpunkte) entfernen – sonst entstehen Knicke.
	# Marken zeigen danach auf den nächsten behaltenen Punkt.
	var keep: Array = [pts[0]]
	var remap := {0: 0}
	for i in range(1, m0):
		if (pts[i] as Vector3).distance_to(keep[keep.size() - 1]) >= 7.0:
			keep.append(pts[i])
		remap[i] = keep.size() - 1
	while keep.size() > 3 and (keep[keep.size() - 1] as Vector3).distance_to(start) < 7.0:
		keep.pop_back()
	var m := keep.size()
	for k in tags.keys():
		tags[k] = mini(int(remap.get(int(tags[k]), 0)), m - 1)
	for lp: Dictionary in d.loops:
		lp["from"] = mini(int(remap.get(int(lp.from), 0)), m - 1)
		lp["to"] = mini(int(remap.get(int(lp.to), 0)), m - 1)
	pts = keep
	d.points = pts
	d["close_err"] = err.length()
	tags["end"] = maxi(0, m - 4)    # auf der Zielgeraden (Rundenschluss)
	tags["end2"] = maxi(0, m - 9)
	return tags


## Kürzester Kurve-Gerade-Kurve-Weg (LSL oder RSR) von (pos, dir) zu (target, tdir) mit Radius r.
static func _dubins(pos: Vector3, dir: Vector3, r: float, target: Vector3, tdir: Vector3) -> Array:
	var p0 := Vector2(pos.x, -pos.z)
	var p1 := Vector2(target.x, -target.z)
	var f0 := atan2(-dir.z, dir.x)
	var f1 := atan2(-tdir.z, tdir.x)
	var best: Array = []
	var best_len := INF
	for kind in ["L", "R"]:
		var sg := 1.0 if kind == "L" else -1.0
		var c0 := Vector2(p0.x - sg * r * sin(f0), p0.y + sg * r * cos(f0))
		var c1 := Vector2(p1.x - sg * r * sin(f1), p1.y + sg * r * cos(f1))
		var v := c1 - c0
		var psi := atan2(v.y, v.x)
		var a1 := fposmod((psi - f0) * sg, TAU)
		var a2 := fposmod((f1 - psi) * sg, TAU)
		var total := (a1 + a2) * r + v.length()
		if total < best_len:
			best_len = total
			best = [[kind, r, rad_to_deg(a1)], ["S", v.length()], [kind, r, rad_to_deg(a2)]]
	return best


## Erzeugt Looping-Punkte. entry = unterster Punkt, dir = Fahrtrichtung, lat = Versatzrichtung.
static func _loop(pts: Array, d: Dictionary, entry: Vector3, dir: Vector3, lat: Vector3, r: float, shift: float) -> void:
	var start := pts.size()
	for k in 9:
		var th := TAU * k / 8.0
		pts.append(entry + dir * (r * sin(th)) + Vector3.UP * (r - r * cos(th)) + lat * (shift * th / TAU))
	(d.loops as Array).append({"from": start, "to": start + 8, "center": entry + Vector3.UP * r, "axis": lat, "radius": r})



## Lumos-Ring – Grand-Prix-Klassiker: schnelle Rechts, Schikane, Looping, Haarnadel und Gleiter über die Schlucht.
static func _ring() -> Dictionary:
	var d := _base("lumos_ring", "Lumos-Ring", "day", "ring", 16.0)
	var t := build_path(d, [
		["T", "start"], ["S", 60], ["T", "b1"], ["S", 70], ["R", 46, 90], ["T", "i1"], ["S", 40], ["L", 26, 45],
		["R", 26, 90], ["L", 26, 45], ["T", "chic"], ["S", 30], ["T", "loop"], ["LOOP", 13, 19], ["S", 36],
		["T", "i2"], ["R", 25, 180], ["T", "hp"], ["S", 40, 6], ["T", "ramp"], ["S", 16, 3], ["T", "g0"],
		["S", 64, -1], ["S", 34, -8], ["T", "g1"], ["S", 10], ["T", "i3"], ["L", 30, 90], ["S", 40], ["T", "b2"],
		["L", 36, 45], ["R", 36, 45], ["S", 30], ["T", "i4"], ["CLOSE", 34],
	])
	d.glide = [[t["g0"], t["g1"]]]
	d.ramps = [t["ramp"]]
	d.boosts = [[t["b1"], 0.0], [t["b2"], 3.0], [t["chic"], -2.0], [t["end2"], -2.0]]
	d.items = [t["i1"], t["i2"], t["i3"], t["i4"]]
	d.bank = {t["i1"]: -8, t["hp"]: 10, t["i4"]: 6}
	d["desc"] = "Grand-Prix-Klassiker: schnelle Rechts, Schikane, Looping, Haarnadel und Gleiter über die Schlucht."
	return d


## Korallen-Kanal – Hafen, Tauchgang durch den Korallentunnel, Felsinsel mit zwei Routen, Sprung über den Steg.
static func _coral() -> Dictionary:
	var d := _base("coral_canal", "Korallen-Kanal", "pirates", "pirates", 17.0)
	var t := build_path(d, [
		["T", "start"], ["S", 50], ["T", "b1"], ["S", 50], ["R", 40, 70], ["T", "i1"], ["S", 40], ["R", 30, 60, -3],
		["T", "w0"], ["S", 30, -6], ["L", 32, 70, -3], ["T", "i2"], ["R", 28, 110], ["S", 30], ["L", 30, 60, 3],
		["T", "b2"], ["S", 30, 6], ["T", "w1"], ["S", 30], ["R", 22, 120], ["T", "i3"], ["S", 30], ["T", "div0"],
		["S", 70], ["T", "div1"], ["S", 20], ["T", "ramp"], ["S", 14, 2], ["S", 30, -2], ["T", "i4"], ["L", 26, 90],
		["CLOSE", 30],
	])
	d.water = [[t["w0"], t["w1"]]]
	d.ramps = [t["ramp"]]
	d.boosts = [[t["b1"], 0.0], [t["end2"], 2.0]]
	d.items = [t["i1"], t["i2"], t["i3"], t["i4"]]
	d.bank = {t["i1"]: -8, t["i3"]: 9}
	d["dividers"] = [[t["div0"], 4.0, 66.0, -2.6, 2.6]]
	d["desc"] = "Hafen, Tauchgang durch den Korallentunnel, Felsinsel mit zwei Routen, Sprung über den Steg."
	return d


## Vulkan-Inselchen – Lavafontänen am Straßenrand, Looping, Gleitflug über den Lavasee.
static func _neon() -> Dictionary:
	var d := _base("neon_volcano", "Vulkan-Inselchen", "sunset", "volcano", 15.0)
	var t := build_path(d, [
		["T", "start"], ["S", 50], ["T", "b1"], ["S", 60], ["R", 30, 75], ["T", "i1"], ["S", 30], ["T", "gey0"],
		["S", 90], ["T", "gey1"], ["L", 22, 60], ["S", 26], ["T", "loop"], ["LOOP", 14, 20], ["S", 30],
		["T", "i2"], ["R", 20, 160, 4], ["S", 40, 4], ["T", "ramp"], ["S", 16, 3], ["T", "g0"], ["S", 60, -2],
		["S", 34, -9], ["T", "g1"], ["S", 20], ["T", "i3"], ["R", 28, 75], ["S", 40], ["T", "gey2"], ["L", 30, 60],
		["R", 30, 60], ["T", "i4"], ["CLOSE", 30],
	])
	d.glide = [[t["g0"], t["g1"]]]
	d.ramps = [t["ramp"]]
	d.boosts = [[t["b1"], 0.0], [t["end2"], -3.0]]
	d.items = [t["i1"], t["i2"], t["i3"], t["i4"]]
	d.bank = {t["i1"]: -8, t["i3"]: -8}
	d["hazards"] = [{"p": t["gey0"], "type": "geyser", "off": 8.0, "x": -4.0, "w": 4.5, "period": 4.2, "on": 1.1, "phase": 0.0}, {"p": t["gey0"], "type": "geyser", "off": 40.0, "x": 4.0, "w": 4.5, "period": 4.2, "on": 1.1, "phase": 1.4}, {"p": t["gey0"], "type": "geyser", "off": 72.0, "x": -3.0, "w": 4.5, "period": 4.2, "on": 1.1, "phase": 2.8}, {"p": t["gey2"], "type": "geyser", "off": 0.0, "x": 3.5, "w": 4.5, "period": 3.6, "on": 1.0, "phase": 0.6}]
	d["desc"] = "Lavafontänen am Straßenrand, Looping, Gleitflug über den Lavasee."
	return d


## Gewitter-Pass – Serpentinen im Unwetter, nasse Kurven, Sprung über die Schlucht, Abfahrt unter der Brücke.
static func _storm() -> Dictionary:
	var d := _base("storm_pass", "Gewitter-Pass", "storm", "storm", 14.0)
	var t := build_path(d, [
		["T", "start"], ["S", 50], ["T", "b1"], ["S", 40], ["R", 34, 80, 4], ["T", "i1"], ["S", 40, 6],
		["L", 18, 150, 3], ["T", "wet0"], ["S", 40, 3], ["R", 18, 150, 2], ["S", 30, 2], ["T", "wet1"],
		["T", "i2"], ["L", 30, 60], ["S", 30], ["T", "ramp"], ["S", 14, 3], ["T", "g0"], ["S", 66, -3],
		["S", 36, -10], ["T", "g1"], ["S", 30], ["T", "i3"], ["L", 30, 160, -1], ["S", 40, -3], ["T", "wet2"],
		["L", 22, 50, -2], ["S", 60, -3], ["R", 24, 70, -1], ["L", 24, 70], ["T", "wet3"], ["S", 40], ["T", "b2"],
		["S", 30], ["T", "i4"], ["CLOSE", 30],
	])
	d.glide = [[t["g0"], t["g1"]]]
	d.wet = [[t["wet0"], t["wet1"]], [t["wet2"], t["wet3"]]]
	d.ramps = [t["ramp"]]
	d.boosts = [[t["b1"], 0.0], [t["end2"], 2.0]]
	d.items = [t["i1"], t["i2"], t["i3"], t["i4"]]
	d.bank = {t["i1"]: -8}
	d["desc"] = "Serpentinen im Unwetter, nasse Kurven, Sprung über die Schlucht, Abfahrt unter der Brücke."
	return d


## Frostgipfel – Eisplatten, enge Kehre am Gipfel, Skisprungschanze und eisige Abfahrt.
static func _frost() -> Dictionary:
	var d := _base("frost_peak", "Frostgipfel", "snow", "snow", 15.0)
	var t := build_path(d, [
		["T", "start"], ["S", 50], ["T", "b1"], ["S", 40], ["L", 36, 80], ["T", "ice0"], ["S", 40], ["R", 30, 60],
		["L", 30, 60], ["T", "ice1"], ["T", "i1"], ["S", 30, 4], ["L", 20, 170, 4], ["S", 40, 5], ["T", "i2"],
		["R", 22, 120, 3], ["S", 20], ["T", "ramp"], ["S", 14, 3], ["T", "g0"], ["S", 70, -4], ["S", 40, -15],
		["T", "g1"], ["S", 30], ["T", "ice2"], ["L", 40, 90], ["S", 40], ["T", "ice3"], ["T", "i3"], ["L", 26, 70],
		["R", 26, 70], ["T", "i4"], ["CLOSE", 30],
	])
	d.glide = [[t["g0"], t["g1"]]]
	d.ice = [[t["ice0"], t["ice1"]], [t["ice2"], t["ice3"]]]
	d.ramps = [t["ramp"]]
	d.boosts = [[t["b1"], 0.0], [t["end2"], -2.0]]
	d.items = [t["i1"], t["i2"], t["i3"], t["i4"]]
	d.bank = {t["i3"]: 8}
	d["desc"] = "Eisplatten, enge Kehre am Gipfel, Skisprungschanze und eisige Abfahrt."
	return d


## Sternenstaub-Bahn – Boost-Tunnel, Sternenfedern, Looping und langer Schwebeflug.
static func _orbit() -> Dictionary:
	var d := _base("orbit_ring", "Sternenstaub-Bahn", "observatory", "space", 15.0)
	var t := build_path(d, [
		["T", "start"], ["S", 40], ["T", "b1"], ["S", 20], ["T", "b1b"], ["S", 20], ["T", "b1c"], ["S", 30],
		["R", 40, 90, 4], ["T", "i1"], ["S", 30, 2], ["T", "bo1"], ["S", 30], ["L", 24, 120], ["T", "i2"],
		["S", 20], ["T", "loop"], ["LOOP", 13, 19], ["S", 30], ["R", 22, 150], ["T", "i3"], ["S", 20, 4],
		["T", "ramp"], ["S", 14, 4], ["T", "g0"], ["S", 90, -2], ["S", 40, -10], ["T", "g1"], ["S", 20],
		["T", "bo2"], ["S", 20], ["T", "i4"], ["R", 34, 80], ["L", 30, 60], ["R", 30, 60], ["CLOSE", 30],
	])
	d.glide = [[t["g0"], t["g1"]]]
	d.ramps = [t["ramp"]]
	d.boosts = [[t["b1"], 0.0], [t["b1b"], 0.0], [t["b1c"], 0.0]]
	d.items = [t["i1"], t["i2"], t["i3"], t["i4"]]
	d.bank = {t["i1"]: -9}
	d["bounce"] = [[t["bo1"], 0.0, -3.5, 4.5, 12.0], [t["bo2"], 0.0, 3.5, 4.5, 12.0]]
	d["desc"] = "Boost-Tunnel, Sternenfedern, Looping und langer Schwebeflug."
	return d


## Stadt-Rallye – Enge 90°-Ecken, Häuserblock mit zwei Routen, Schikane und Kanalsprung.
static func _city() -> Dictionary:
	var d := _base("city_rally", "Stadt-Rallye", "day", "city", 17.0)
	var t := build_path(d, [
		["T", "start"], ["S", 50], ["T", "b1"], ["S", 40], ["R", 15, 90], ["S", 60], ["T", "i1"], ["L", 15, 90],
		["S", 40], ["R", 15, 90], ["T", "div0"], ["S", 80], ["T", "div1"], ["S", 20], ["R", 16, 90], ["T", "i2"],
		["S", 40], ["L", 22, 45], ["R", 22, 90], ["L", 22, 45], ["S", 20], ["T", "ramp"], ["S", 14, 2],
		["T", "g0"], ["S", 30, 1], ["S", 20, -3], ["T", "g1"], ["S", 20], ["T", "i3"], ["S", 40], ["L", 15, 90],
		["S", 40], ["T", "i4"], ["R", 15, 90], ["S", 30], ["R", 15, 90], ["CLOSE", 30],
	])
	d.glide = [[t["g0"], t["g1"]]]
	d.ramps = [t["ramp"]]
	d.boosts = [[t["b1"], 0.0], [t["end2"], 2.0]]
	d.items = [t["i1"], t["i2"], t["i3"], t["i4"]]
	d["dividers"] = [[t["div0"], 6.0, 70.0, -2.2, 2.2]]
	d["desc"] = "Enge 90°-Ecken, Häuserblock mit zwei Routen, Schikane und Kanalsprung."
	return d


## Wüsten-Canyon – Canyon-S-Kurven, Dünen-Sprungfeld, Looping und Gleitflug über die Schlucht.
static func _desert() -> Dictionary:
	var d := _base("desert_canyon", "Wüsten-Canyon", "desert", "desert", 15.0)
	var t := build_path(d, [
		["T", "start"], ["S", 50], ["T", "b1"], ["S", 50], ["L", 40, 90], ["T", "i1"], ["S", 30], ["R", 30, 70],
		["L", 30, 70], ["T", "bo1"], ["S", 40], ["T", "loop"], ["LOOP", 12, 18], ["S", 30], ["T", "i2"],
		["L", 24, 160, 4], ["S", 30, 4], ["T", "ramp"], ["S", 16, 3], ["T", "g0"], ["S", 70, -2], ["S", 36, -9],
		["T", "g1"], ["S", 10], ["T", "i3"], ["R", 34, 70], ["S", 50], ["T", "b2"], ["R", 26, 60], ["L", 26, 60],
		["S", 40], ["T", "i4"], ["CLOSE", 30],
	])
	d.glide = [[t["g0"], t["g1"]]]
	d.ramps = [t["ramp"]]
	d.boosts = [[t["b1"], 0.0], [t["end2"], 3.0]]
	d.items = [t["i1"], t["i2"], t["i3"], t["i4"]]
	d.bank = {t["i1"]: 8, t["i3"]: 8}
	d["bounce"] = [[t["bo1"], 0.0, 0.0, 6.0, 11.0]]
	d["desc"] = "Canyon-S-Kurven, Dünen-Sprungfeld, Looping und Gleitflug über die Schlucht."
	return d


## Glühwald-Pfad – Nachtfahrt durch den Zauberwald: Leuchtpilze als Sprungfedern, hohler Baumtunnel, nasser Bachlauf.
static func _glow() -> Dictionary:
	var d := _base("glow_forest", "Glühwald-Pfad", "forest_dusk", "forest", 15.0)
	var t := build_path(d, [
		["T", "start"], ["S", 50], ["T", "b1"], ["S", 40], ["R", 30, 70], ["T", "i1"], ["S", 20], ["T", "bo1"],
		["S", 30], ["L", 24, 70], ["R", 24, 70], ["T", "tun0"], ["S", 60], ["T", "tun1"], ["R", 18, 160],
		["T", "i2"], ["S", 30, 3], ["L", 28, 60, 3], ["T", "wet0"], ["S", 50, 2], ["T", "wet1"], ["R", 28, 60, -2],
		["T", "bo2"], ["S", 30, -3], ["L", 26, 90, -3], ["T", "i3"], ["S", 30], ["R", 22, 70], ["L", 22, 70],
		["T", "i4"], ["S", 40], ["T", "bo3"], ["L", 22, 100], ["R", 22, 100], ["S", 30], ["CLOSE", 30],
	])
	d.wet = [[t["wet0"], t["wet1"]]]
	d["tunnel"] = [[t["tun0"], t["tun1"]]]
	d.boosts = [[t["b1"], 0.0], [t["end2"], 2.0]]
	d.items = [t["i1"], t["i2"], t["i3"], t["i4"]]
	d["bounce"] = [[t["bo1"], 0.0, 3.5, 4.0, 12.0], [t["bo2"], 0.0, -3.5, 4.0, 12.0], [t["bo3"], 0.0, 0.0, 4.0, 12.0]]
	d["desc"] = "Nachtfahrt durch den Zauberwald: Leuchtpilze als Sprungfedern, hohler Baumtunnel, nasser Bachlauf."
	return d


## Zuckerguss-Allee – Riesen-Süßigkeiten, Kaugummi-Sprungfelder, Lolli-Looping, Brücke über die erste Kurve.
static func _candy() -> Dictionary:
	var d := _base("candy_lane", "Zuckerguss-Allee", "sky", "candy", 16.0)
	var t := build_path(d, [
		["T", "start"], ["S", 50], ["T", "b1"], ["S", 50], ["L", 34, 90], ["T", "i1"], ["S", 30], ["T", "bo1"],
		["S", 30], ["R", 22, 80], ["L", 22, 80], ["S", 20], ["T", "loop"], ["LOOP", 13, 19], ["S", 30],
		["T", "i2"], ["L", 22, 170, 4], ["S", 30, 3], ["T", "ramp"], ["S", 14, 3], ["T", "g0"], ["S", 64, -2],
		["S", 34, -2], ["T", "g1"], ["S", 24, 2], ["T", "i3"], ["L", 36, 70, 0], ["T", "bridge"], ["S", 20],
		["R", 30, 150, -4], ["T", "bo2"], ["S", 60, -4], ["L", 26, 50], ["R", 26, 50], ["T", "i4"], ["S", 30],
		["CLOSE", 30],
	])
	d.glide = [[t["g0"], t["g1"]]]
	d.ramps = [t["ramp"]]
	d.boosts = [[t["b1"], 0.0], [t["end2"], -3.0]]
	d.items = [t["i1"], t["i2"], t["i3"], t["i4"]]
	d.bank = {t["i1"]: 8}
	d["bounce"] = [[t["bo1"], 0.0, -3.5, 4.5, 12.0], [t["bo2"], 0.0, 3.5, 4.5, 12.0]]
	d["desc"] = "Riesen-Süßigkeiten, Kaugummi-Sprungfelder, Lolli-Looping, Brücke über die erste Kurve."
	return d


## Dschungel-Tempel – Rollende Baumstämme, Tempelruine mit zwei Routen, Sprung über den Fluss.
static func _jungle() -> Dictionary:
	var d := _base("jungle_ruins", "Dschungel-Tempel", "day", "jungle", 18.0)
	var t := build_path(d, [
		["T", "start"], ["S", 50], ["T", "b1"], ["S", 50], ["R", 34, 80], ["T", "i1"], ["S", 30], ["T", "log0"],
		["S", 50], ["T", "log1"], ["L", 22, 100], ["R", 22, 100], ["T", "i2"], ["S", 30], ["R", 20, 60],
		["L", 20, 120], ["R", 20, 60], ["S", 30], ["T", "div0"], ["S", 90], ["T", "div1"], ["S", 20], ["R", 20, 150],
		["T", "i3"], ["S", 30, 4], ["T", "ramp"], ["S", 14, 3], ["T", "g0"], ["S", 50, -1], ["S", 30, -6],
		["T", "g1"], ["S", 20], ["T", "log2"], ["L", 30, 70], ["R", 30, 70], ["T", "i4"], ["CLOSE", 30],
	])
	d.glide = [[t["g0"], t["g1"]]]
	d.ramps = [t["ramp"]]
	d.boosts = [[t["b1"], 0.0], [t["end2"], 3.0]]
	d.items = [t["i1"], t["i2"], t["i3"], t["i4"]]
	d.bank = {t["i1"]: -8}
	d["dividers"] = [[t["div0"], 4.0, 86.0, -3.0, 3.0]]
	d["hazards"] = [{"p": t["log0"], "type": "log", "off": 10.0, "x": 0.0, "w": 18.0, "period": 5.0, "on": 2.2, "phase": 0.0}, {"p": t["log1"], "type": "log", "off": 0.0, "x": 0.0, "w": 18.0, "period": 5.0, "on": 2.2, "phase": 2.5}, {"p": t["log2"], "type": "log", "off": 0.0, "x": 0.0, "w": 18.0, "period": 4.6, "on": 2.0, "phase": 1.2}]
	d["desc"] = "Rollende Baumstämme, Tempelruine mit zwei Routen, Sprung über den Fluss."
	return d


## Wasserfall-Schlucht – Fahrt durch die Gischt eines Wasserfalls, Brücke über die eigene Strecke, Sprung über die Schlucht.
static func _falls() -> Dictionary:
	var d := _base("falls_gorge", "Wasserfall-Schlucht", "day", "falls", 15.0)
	var t := build_path(d, [
		["T", "start"], ["S", 50], ["T", "b1"], ["S", 50], ["R", 34, 90], ["T", "i1"], ["S", 40, 1], ["T", "wet0"],
		["S", 50, 4], ["T", "fall"], ["S", 30, 4], ["T", "wet1"], ["R", 22, 120, 2], ["S", 30], ["T", "i2"],
		["R", 26, 100], ["S", 40, -3], ["T", "bridge"], ["S", 60], ["L", 30, 80], ["S", 30], ["T", "i3"],
		["S", 10], ["T", "ramp"], ["S", 14, 3], ["T", "g0"], ["S", 60, -2], ["S", 30, -3], ["T", "g1"],
		["S", 20], ["L", 26, 70, -3], ["R", 26, 70, -3], ["T", "i4"], ["S", 20], ["CLOSE", 34],
	])
	d.glide = [[t["g0"], t["g1"]]]
	d.wet = [[t["wet0"], t["wet1"]]]
	d.ramps = [t["ramp"]]
	d.boosts = [[t["b1"], 0.0], [t["end2"], -2.0]]
	d.items = [t["i1"], t["i2"], t["i3"], t["i4"]]
	d.bank = {t["i1"]: -8}
	d["falls"] = [t["fall"]]
	d["desc"] = "Fahrt durch die Gischt eines Wasserfalls, Brücke über die eigene Strecke, Sprung über die Schlucht."
	return d
