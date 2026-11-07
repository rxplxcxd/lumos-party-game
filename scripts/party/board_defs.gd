class_name BoardDefs
extends RefCounted
## Datendefinition der Spielbretter.
##
## main:     geschlossene Hauptschleife (Kontrollpunkte, Catmull-Rom), main_count Felder
## pattern:  Feldtypen der Hauptschleife (ein Zeichen pro Feld)
## branches: Abzweigungen {from, to, points, pattern, toggle, gate}
##
## Feldtypen:  S Start · B Blau (+3) · R Rot (-3) · L Glücksrad-Kiste · P Piraten-Planke
##             C Dungeon-Fluch · T Fackel-Falle · K Wolken-Kanone/Rakete · N Händler (Durchgang)
##             G Geister-Taxi (fliegt dich vor/zurück) · E Eis-Rutsche · W Warp-Pad (Teleport zu anderem W)
## toggle:    Route ist nur in geraden/ungeraden Runden offen (Lava-Steg, Ebbe, Zugbrücke)
## gate:      Skelett-Wächter verlangt Wegzoll

const BOARDS := {
	"dungeon": {
		"name": "Dungeon Deep", "env": "dungeon", "music": "board_dungeon", "surface": "dungeon",
		"main": [Vector3(-19, 0, -9), Vector3(-9, 0, -14), Vector3(3, 0, -14), Vector3(15, 0, -12), Vector3(21, 0, -2),
			Vector3(19, 0, 9), Vector3(8, 0, 14), Vector3(-4, 0, 14), Vector3(-15, 0, 12), Vector3(-22, 0, 3)],
		"main_count": 32,
		"pattern": "SBBRBLBBTBRBBCBLBRBBTBBRBLBBCBRB",
		"branches": [
			{"from": 29, "to": 13, "points": [Vector3(-14, 0, 1), Vector3(-6, 0, 2), Vector3(2, 0, 1), Vector3(10, 0, 0), Vector3(16, 0, -1)],
				"pattern": "BLBTB", "toggle": "even", "kind": "lava_bridge"},
			{"from": 3, "to": 10, "points": [Vector3(-4, 0, -9), Vector3(2, 0, -7), Vector3(8, 0, -7), Vector3(13, 0, -7)],
				"pattern": "BLRB", "gate": 5, "kind": "skeleton_gate"},
		],
	},
	"pirates": {
		"name": "Pirates Cove", "env": "pirates", "music": "board_pirates", "surface": "sand",
		"main": [Vector3(-20, 0, -6), Vector3(-12, 0, -13), Vector3(0, 0, -15), Vector3(12, 0, -12), Vector3(20, 0, -4),
			Vector3(18, 0, 7), Vector3(8, 0, 13), Vector3(-5, 0, 13), Vector3(-16, 0, 8)],
		"main_count": 30,
		"pattern": "SBBPBLBRBNBBPBLBRBBPBBLBRBBNBR",
		"branches": [
			{"from": 4, "to": 11, "points": [Vector3(-3, 0, -9), Vector3(2, 0, -5), Vector3(8, 0, -6), Vector3(14, 0, -6)],
				"pattern": "BLPB", "toggle": "odd", "kind": "tide"},
			{"from": 19, "to": 26, "points": [Vector3(-4, 0, 8), Vector3(-8, 0, 5), Vector3(-13, 0, 4)],
				"pattern": "LBR", "kind": "jungle"},
		],
	},
	"sky": {
		"name": "Sky Kingdom", "env": "sky", "music": "board_sky", "surface": "grass",
		"main": [Vector3(-20, 0, -4), Vector3(-14, 2, -13), Vector3(-2, 4, -16), Vector3(11, 3, -13), Vector3(20, 1, -4),
			Vector3(19, 0, 7), Vector3(9, 2, 14), Vector3(-4, 3, 14), Vector3(-16, 1, 9)],
		"main_count": 30,
		"pattern": "SBBKBLBRBBKBLBRBBKBBLBRBBKBLBR",
		"branches": [
			{"from": 2, "to": 12, "points": [Vector3(-11, 1, -5), Vector3(-5, 3, -4), Vector3(1, 5, -3), Vector3(8, 4, -4), Vector3(14, 3, -6)],
				"pattern": "BLBKB", "toggle": "even", "kind": "drawbridge"},
			{"from": 17, "to": 26, "points": [Vector3(10, 1, 4), Vector3(4, 3, 4), Vector3(-3, 4, 5), Vector3(-10, 3, 4)],
				"pattern": "BKLB", "toggle": "odd", "kind": "drawbridge"},
		],
	},
	"graveyard": {
		"name": "Geisterfriedhof", "env": "graveyard", "music": "board_dungeon", "surface": "grass",
		"main": [Vector3(-20, 0, -8), Vector3(-11, 0, -14), Vector3(0, 0, -15), Vector3(12, 0, -13), Vector3(20, 0, -5),
			Vector3(20, 0, 6), Vector3(10, 0, 13), Vector3(-2, 0, 14), Vector3(-13, 0, 12), Vector3(-21, 0, 3)],
		"main_count": 32,
		"pattern": "SBBGBLBRBCBBGBLBRBBGBCBLBRBGBBLB",
		"branches": [
			{"from": 4, "to": 11, "points": [Vector3(-5, 0, -9), Vector3(1, 0, -7), Vector3(8, 0, -8)],
				"pattern": "BGL", "toggle": "odd", "kind": "fog_bridge"},
			{"from": 19, "to": 27, "points": [Vector3(5, 0, 8), Vector3(-2, 0, 6), Vector3(-9, 0, 6)],
				"pattern": "LBR", "gate": 5, "kind": "crypt_gate"},
		],
	},
	"frost": {
		"name": "Frostdorf", "env": "snow", "music": "board_sky", "surface": "snow",
		"main": [Vector3(-20, 0, -6), Vector3(-12, 0, -14), Vector3(0, 0, -15), Vector3(12, 0, -12), Vector3(21, 0, -3),
			Vector3(18, 0, 8), Vector3(7, 0, 14), Vector3(-6, 0, 13), Vector3(-17, 0, 8)],
		"main_count": 30,
		"pattern": "SBBEBLBRBNBBEBLBRBBEBBLBRBNBEB",
		"branches": [
			{"from": 3, "to": 10, "points": [Vector3(-5, 0, -9), Vector3(2, 0, -6), Vector3(9, 0, -7)],
				"pattern": "BLE", "toggle": "even", "kind": "ice_bridge"},
			{"from": 17, "to": 25, "points": [Vector3(10, 0, 5), Vector3(3, 0, 6), Vector3(-4, 0, 6), Vector3(-10, 0, 5)],
				"pattern": "BLBR", "kind": "sled"},
		],
	},
	"station": {
		"name": "Orbit-Station", "env": "station", "music": "board_sky", "surface": "metal",
		"main": [Vector3(-20, 0, -5), Vector3(-13, 0, -13), Vector3(-1, 0, -15), Vector3(11, 0, -13), Vector3(20, 0, -5),
			Vector3(19, 0, 6), Vector3(10, 0, 13), Vector3(-3, 0, 14), Vector3(-15, 0, 10)],
		"main_count": 30,
		"pattern": "SBBWBLBRBKBBWBLBRBNBWBLBRBKBBW",
		"branches": [
			{"from": 2, "to": 11, "points": [Vector3(-10, 0, -5), Vector3(-3, 0, -4), Vector3(4, 0, -4), Vector3(12, 0, -6)],
				"pattern": "BLWB", "toggle": "odd", "kind": "airlock"},
			{"from": 16, "to": 25, "points": [Vector3(11, 0, 5), Vector3(4, 0, 4), Vector3(-4, 0, 5), Vector3(-11, 0, 4)],
				"pattern": "BKLB", "toggle": "even", "kind": "airlock"},
		],
	},
}


static func get_def(id: String) -> Dictionary:
	return BOARDS.get(id, BOARDS.dungeon)


## Erzeugt den Feld-Graphen: Array von Dictionaries {id, pos, type, next[], prev[], branch}
static func build_graph(def: Dictionary) -> Array:
	var spaces: Array = []
	var main_pts: Array = def.main
	var n: int = def.main_count
	var pattern: String = def.pattern
	var curve := _closed_curve(main_pts)
	var length := curve.get_baked_length()
	for i in n:
		var pos := curve.sample_baked(length * i / n, true)
		spaces.append({"id": i, "pos": pos, "type": pattern[i % pattern.length()], "next": [(i + 1) % n], "prev": [(i - 1 + n) % n], "branch": -1})
	var bi := 0
	for br in def.branches:
		var from: int = br.from
		var to: int = br.to
		var pts: Array = [spaces[from].pos] + br.points + [spaces[to].pos]
		var bc := _open_curve(pts)
		var blen := bc.get_baked_length()
		var bp: String = br.pattern
		var count := bp.length()
		var ids: Array[int] = []
		for k in count:
			var t := blen * float(k + 1) / float(count + 1)
			var id := spaces.size()
			spaces.append({"id": id, "pos": bc.sample_baked(t, true), "type": bp[k], "next": [], "prev": [], "branch": bi})
			ids.append(id)
		for k in count:
			var sp: Dictionary = spaces[ids[k]]
			sp.next = [ids[k + 1]] if k < count - 1 else [to]
			sp.prev = [ids[k - 1]] if k > 0 else [from]
		(spaces[from].next as Array).append(ids[0])
		(spaces[to].prev as Array).append(ids[count - 1])
		bi += 1
	return spaces


static func _closed_curve(pts: Array) -> Curve3D:
	var c := Curve3D.new()
	var n := pts.size()
	for i in n + 1:
		var p: Vector3 = pts[i % n]
		var prev: Vector3 = pts[(i - 1 + n) % n]
		var nxt: Vector3 = pts[(i + 1) % n]
		var tan := (nxt - prev) * 0.25
		c.add_point(p, -tan, tan)
	c.bake_interval = 0.25
	return c


static func _open_curve(pts: Array) -> Curve3D:
	var c := Curve3D.new()
	var n := pts.size()
	for i in n:
		var p: Vector3 = pts[i]
		var prev: Vector3 = pts[maxi(i - 1, 0)]
		var nxt: Vector3 = pts[mini(i + 1, n - 1)]
		var tan := (nxt - prev) * 0.25
		c.add_point(p, -tan, tan)
	c.bake_interval = 0.25
	return c
