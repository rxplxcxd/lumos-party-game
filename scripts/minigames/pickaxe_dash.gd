extends MinigameBase
## Spitzhacken-Spurt: Vier Schächte im Querschnitt, alle mit derselben Erdschichtung. A und B ABWECHSELND
## drücken = hacken (zweimal dieselbe Taste klonkt nur). Erde ist weich, Stein zäh, Felsbrocken unzerstörbar,
## Edelsteine geben Bonus. Stick links/rechts + hacken gräbt seitlich – so umgeht man harte Brocken.
## Punkte = gegrabene Meter + Edelsteine.
## Online: Besitzer-Modell (gleiche Schichtung aus dem gemeinsamen Zufall; fremde Schächte werden aus der
## Position der Figur nachgezeichnet).

const CELL := 1.5
const COLS := 3
const ROWS := 70
const SHAFT_X := [-7.2, -2.4, 2.4, 7.2]
const HP := {"dirt": 4, "clay": 6, "stone": 11, "gem": 4, "rock": 9999}
const COL := {"dirt": Color("#9b6a3f"), "clay": Color("#b9774a"), "stone": Color("#8d8f99"), "gem": Color("#5fd3ff"), "rock": Color("#3d3a44")}

var _layout: Array = []              # _layout[r][c] = Art
var _cells: Array = []               # je Spieler: Dictionary "r,c" -> [Art, Instanz-Index] (MultiMesh je Art)
var _mm := {}                        # Art -> MultiMesh (ein Draw-Call pro Gesteinsart statt hunderter Blöcke)
var _cube: BoxMesh
var _dug: Array = []                 # je Spieler: Dictionary "r,c" -> true
var _pos: Array[Vector2i] = []       # je Spieler: (Spalte, Zeile); Zeile -1 = Oberfläche
var _hit: Array[Dictionary] = []     # je Spieler: {key, hp, last}
var _mats := {}
var _drop_t: Array[float] = [0, 0, 0, 0]


func _init() -> void:
	game_id = "pickaxe_dash"
	env_preset = "day"
	backdrop_style = "meadow"
	time_limit = 30.0
	score_format = "%d m"
	kill_y = -999.0
	arena_radius = 10.0
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 8)
	spawn_points = [Vector3(SHAFT_X[0], 0.1, 0), Vector3(SHAFT_X[1], 0.1, 0), Vector3(SHAFT_X[2], 0.1, 0), Vector3(SHAFT_X[3], 0.1, 0)]


func _cell_pos(i: int, c: int, r: int) -> Vector3:
	return Vector3(SHAFT_X[i] + (c - 1) * CELL, -(r + 0.5) * CELL, 0)


func build_arena() -> void:
	# Schichtung (für alle gleich): oben Erde, tiefer mehr Lehm/Stein, Felsbrocken als Umweg-Rätsel
	for r in ROWS:
		var row: Array = []
		var deep := float(r) / ROWS
		for c in COLS:
			var x := rng.randf()
			var kind := "dirt"
			if x < 0.08 + deep * 0.1:
				kind = "rock"
			elif x < 0.2 + deep * 0.25:
				kind = "stone"
			elif x < 0.42 + deep * 0.2:
				kind = "clay"
			elif x > 0.95:
				kind = "gem"
			row.append(kind)
		_layout.append(row)
	_ensure_path()
	for k in COL:
		_mats[k] = WorldKit.mat(COL[k], 0.9, 0.6 if k == "gem" else 0.0)
	_cube = BoxMesh.new()
	_cube.size = Vector3(CELL * 0.98, CELL * 0.98, CELL)
	var counts := {}
	for r in ROWS:
		for c in COLS:
			counts[_layout[r][c]] = int(counts.get(_layout[r][c], 0)) + 4
	var used := {}
	for k in counts:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _cube
		mm.instance_count = int(counts[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _mats[k]
		mmi.set_meta("keep_visible", true)
		world.add_child(mmi)
		_mm[k] = mm
		used[k] = 0
	for i in 4:
		var cells := {}
		for r in ROWS:
			for c in COLS:
				var kind: String = _layout[r][c]
				var idx := int(used[kind])
				used[kind] = idx + 1
				(_mm[kind] as MultiMesh).set_instance_transform(idx, Transform3D(Basis(), _cell_pos(i, c, r)))
				cells["%d,%d" % [r, c]] = [kind, idx]
		_cells.append(cells)
		_dug.append({})
		_pos.append(Vector2i(1, -1))
		_hit.append({"key": "", "hp": 0, "last": ""})
	# Schachtwände zwischen den Spielern
	for x in [-9.6, -4.8, 0.0, 4.8, 9.6]:
		WorldKit.box(world, Vector3(0.3, ROWS * CELL, CELL * 1.2), Vector3(x, -ROWS * CELL * 0.5, 0), Color("#5a3d26"), false)
	# Rückwand mit Gesteinsschichten und Leuchtkristallen
	for b in 7:
		WorldKit.box(world, Vector3(22, ROWS * CELL / 7.0, 0.4), Vector3(0, -(b + 0.5) * ROWS * CELL / 7.0, -1.0), Color("#6b4a2e").darkened(b * 0.07), false)
	for k in 22:
		var cr := WorldKit.box(world, Vector3(0.25, 0.4, 0.25), Vector3(randf_range(-10, 10), -randf_range(3, ROWS * CELL), -0.78), Color(0.5, 0.9, 1.0) if k % 2 else Color(1.0, 0.6, 0.9), false)
		(cr.get_child(0) as MeshInstance3D).material_override = WorldKit.mat(Color(0.5, 0.9, 1.0) if k % 2 else Color(1.0, 0.6, 0.9), 0.3, 1.5)
		cr.rotation.z = randf_range(-0.6, 0.6)
	# Tiefenmarken
	for d in range(10, ROWS, 10):
		var lb := Label3D.new()
		lb.text = "%d m" % d
		lb.font_size = 90
		lb.outline_size = 18
		lb.modulate = Color("#ffe8b0")
		lb.position = Vector3(-10.6, -d * CELL, 0.3)
		world.add_child(lb)
	# Oberfläche: Wiese, Grubenschilder, Loren
	WorldKit.box(world, Vector3(24, 0.3, 6), Vector3(0, 0.15, -1.5), Color("#7cc85a"), false)
	for i in 4:
		WorldKit.place(world, "plat/sign", Vector3(SHAFT_X[i] + 1.9, 0.3, -1.2), 0.0, 0.8)
	WorldKit.place(world, "nat/tree_oak", Vector3(-11.5, 0.3, -2.5), 0.0, 1.8)
	WorldKit.place(world, "nat/rock_large", Vector3(11.5, 0.3, -2.0), 30.0, 1.6)


## Garantiert einen Weg nach unten: von der Startspalte aus muss jede Reihe über Erde/Stein erreichbar sein
## (seitlich graben innerhalb der Reihe, dann runter). Sackgassen werden zu Erde.
func _ensure_path() -> void:
	if _layout[0][1] == "rock":
		_layout[0][1] = "dirt"
	var reach: Array[int] = [1]
	for r in ROWS:
		var comp: Array[int] = reach.duplicate()
		var grew := true
		while grew:
			grew = false
			for c in comp.duplicate():
				for nc in [c - 1, c + 1]:
					if nc >= 0 and nc < COLS and not (nc in comp) and _layout[r][nc] != "rock":
						comp.append(nc)
						grew = true
		if r + 1 >= ROWS:
			break
		var nxt: Array[int] = []
		for c in comp:
			if _layout[r + 1][c] != "rock":
				nxt.append(c)
		if nxt.is_empty():
			var pick: int = comp[rng.randi() % comp.size()]
			_layout[r + 1][pick] = "dirt"
			nxt.append(pick)
		reach = nxt


func setup_camera(c: ArenaCamera) -> void:
	# Eigene Führung in on_tick: Mitte und Abstand folgen dem Tiefenbereich aller Spieler
	c.follow = false
	c.fixed_center = Vector3(0, -1.0, 0)
	c.offset = Vector3(0, 1.5, 14.0)
	c.look_offset = Vector3.ZERO
	c.min_dist = 1.0
	c.max_dist = 1.0


func on_start() -> void:
	for i in 4:
		var av := avatars[i] as PartyAvatar
		if av == null:
			continue
		av.freeze(true)
		av.can_shove = false
		if net_owned(i):
			av.set_physics_process(false)
		av.global_position = Vector3(SHAFT_X[i], 0.0, 0)
		av.rig.face_now(Vector3.BACK)


func on_tick(delta: float) -> void:
	_follow_depth()
	for i in active_slots():
		if net_owned(i):
			_dig_input(i)
		else:
			_trace_remote(i)
		_drop_t[i] = maxf(0.0, _drop_t[i] - delta)
		var av := avatars[i] as PartyAvatar
		if net_owned(i):
			var want := _feet(i)
			av.global_position = av.global_position.lerp(want, minf(1.0, delta * 14.0))


func _follow_depth() -> void:
	if not is_instance_valid(cam):
		return
	var lo := 0.0
	var hi := -INF
	for i in active_slots():
		var y := (avatars[i] as PartyAvatar).global_position.y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	if hi == -INF:
		return
	cam.fixed_center = Vector3(0, (lo + hi) * 0.5 - 0.5, 0)
	cam.offset = Vector3(0, 1.5, clampf(14.0 + (hi - lo) * 0.8, 14.0, 34.0))


func _feet(i: int) -> Vector3:
	var p := _pos[i]
	if p.y < 0:
		return Vector3(SHAFT_X[i] + (p.x - 1) * CELL, 0.0, 0)
	return _cell_pos(i, p.x, p.y) - Vector3(0, CELL * 0.5 - 0.02, 0)


func _open(i: int, c: int, r: int) -> bool:
	if r < 0:
		return true
	if c < 0 or c >= COLS or r >= ROWS:
		return false
	return (_dug[i] as Dictionary).has("%d,%d" % [r, c])


func _dig_input(i: int) -> void:
	var btn := ""
	if InputHub.pressed(i, "a"):
		btn = "a"
	elif InputHub.pressed(i, "b"):
		btn = "b"
	var mv := InputHub.move(i)
	var p := _pos[i]
	var side := 0
	if absf(mv.x) > 0.5 and p.y >= 0:
		side = 1 if mv.x > 0.0 else -1
	# Seitlich laufen, wenn dort schon offen ist
	if side != 0 and _open(i, p.x + side, p.y) and _drop_t[i] <= 0.0:
		_pos[i] = Vector2i(p.x + side, p.y)
		_drop_t[i] = 0.18
		_fall(i)
		return
	if btn == "":
		return
	var h := _hit[i]
	var av := avatars[i] as PartyAvatar
	if btn == String(h.last):
		Audio.sfx("metal_light", av.global_position, -10.0, 0.7)
		av.rig.play_once("hit", "idle", 1.8)
		return
	h.last = btn
	var tc := p.x + side
	var tr := p.y if side != 0 else p.y + 1
	if tc < 0 or tc >= COLS or tr >= ROWS:
		return
	var key := "%d,%d" % [tr, tc]
	var kind: String = _layout[tr][tc]
	if String(h.key) != key:
		h.key = key
		h.hp = int(HP[kind])
	h.hp = int(h.hp) - 1
	av.rig.play_once("slice" if btn == "a" else "punch", "idle", 2.0)
	var cp := _cell_pos(i, tc, tr)
	if kind == "rock":
		Audio.sfx("metal_hit", cp, -6.0, 0.8)
		FX.sparks(cp + Vector3(0, CELL * 0.5, 0.6), Color(1, 0.9, 0.6), 4)
		return
	Audio.sfx("stone_hit" if kind == "stone" else "step_sand", cp, -6.0, randf_range(0.9, 1.2))
	FX.dust(cp + Vector3(0, CELL * 0.45, 0.6), COL[kind].lightened(0.2), 3, 0.5)
	_wobble(i, tr, tc, 1.0 - float(h.hp) / float(HP[kind]))
	if int(h.hp) <= 0:
		_break(i, tr, tc)
		h.key = ""
		if side == 0:
			_pos[i] = Vector2i(p.x, tr)
			add_score(i, 1.0)
		_fall(i)


func _break(i: int, r: int, c: int) -> void:
	var key := "%d,%d" % [r, c]
	if (_dug[i] as Dictionary).has(key):
		return
	_dug[i][key] = true
	var kind: String = _layout[r][c]
	var cp := _cell_pos(i, c, r)
	var ref: Array = _cells[i][key]
	(_mm[ref[0]] as MultiMesh).set_instance_transform(int(ref[1]), Transform3D(Basis().scaled(Vector3.ONE * 0.001), cp))
	# Kurzlebiger Ersatzblock schrumpft weg
	var mi := MeshInstance3D.new()
	mi.mesh = _cube
	mi.material_override = _mats[kind]
	mi.position = cp
	world.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.14)
	tw.tween_callback(mi.queue_free)
	FX.dust(cp, COL[kind], 10, 1.0)
	if kind == "gem":
		FX.stars(cp, Color(0.5, 0.9, 1.0), 12)
		Audio.sfx("sparkle_up", cp)
		if net_owned(i):
			add_score(i, 3.0, cp + Vector3(0, 1, 0.8))
			(avatars[i] as PartyAvatar).rig.react("star_get")
	else:
		Audio.sfx("plop", cp, -8.0, 0.8)


## Getroffene Zelle wackelt und schrumpft leicht mit dem Schaden
func _wobble(i: int, r: int, c: int, dmg: float) -> void:
	var ref: Array = _cells[i]["%d,%d" % [r, c]]
	var mm: MultiMesh = _mm[ref[0]]
	var base := _cell_pos(i, c, r)
	var sc := 1.0 - clampf(dmg, 0.0, 1.0) * 0.18
	mm.set_instance_transform(int(ref[1]), Transform3D(Basis().scaled(Vector3(sc, sc, 1.0)), base + Vector3(randf_range(-0.06, 0.06), 0, 0)))


## Fallen, solange unter der Figur schon gegraben ist
func _fall(i: int) -> void:
	var p := _pos[i]
	while p.y + 1 < ROWS and _open(i, p.x, p.y + 1) and p.y + 1 >= 0:
		p.y += 1
		add_score(i, 1.0)
	_pos[i] = p


## Fremde Schächte: Zellen dort, wo die (übers Netz bewegte) Figur steht, als gegraben zeichnen
func _trace_remote(i: int) -> void:
	var av := avatars[i] as PartyAvatar
	var lp := av.global_position
	var c := int(round((lp.x - SHAFT_X[i]) / CELL)) + 1
	var r := int(floor(-(lp.y + 0.3) / CELL))
	if c >= 0 and c < COLS and r >= 0 and r < ROWS:
		_break(i, r, c)


# --- CPU --------------------------------------------------------------------------------------------------------

## Erster Schritt (−1/+1 = seitlich, 0 = runter) auf dem billigsten Weg bis „depth" Reihen tiefer.
func _plan(slot: int, p: Vector2i, depth: int) -> int:
	var goal_r := mini(p.y + depth, ROWS - 1)
	var dist := {}
	var first := {}
	var open: Array = [[0, p.x, p.y, 0]]
	dist[Vector2i(p.x, p.y)] = 0
	while not open.is_empty():
		open.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
		var cur: Array = open.pop_front()
		var cc := int(cur[1])
		var cr := int(cur[2])
		if cr >= goal_r:
			return int(cur[3])
		var steps: Array = [[cc, cr + 1, 0]]
		if cr >= 0:
			steps.append([cc - 1, cr, -1])
			steps.append([cc + 1, cr, 1])
		for st in steps:
			var nc := int(st[0])
			var nr := int(st[1])
			if nc < 0 or nc >= COLS or nr >= ROWS:
				continue
			var cost := 0 if _open(slot, nc, nr) else int(HP[_layout[nr][nc]])
			if cost >= 9999:
				continue
			var nd := int(cur[0]) + cost + 1
			var key := Vector2i(nc, nr)
			if nd < int(dist.get(key, 1 << 30)):
				dist[key] = nd
				var fm: int = int(cur[3]) if (cc != p.x or cr != p.y) else int(st[2])
				first[key] = fm
				open.append([nd, nc, nr, fm])
	return 0



func cpu_think(slot: int, _delta: float) -> void:
	var level: int = Game.players[slot].cpu_level
	var mem: Dictionary = cpu_mem[slot]
	var p := _pos[slot]
	var held := {}
	var mv := Vector2.ZERO
	# Route: günstigster Weg ein paar Reihen tief (Dijkstra über Gitter; Felsen sind praktisch unendlich teuer)
	var first := _plan(slot, p, [3, 5, 7][level])
	if first != 0:
		mv.x = float(first)
	# Abwechselnd hacken, Tempo je Stufe
	var rate: float = [5.0, 6.5, 8.0][level]
	mem["acc"] = float(mem.get("acc", 0.0)) + rate / 60.0
	if float(mem.acc) >= 1.0:
		mem.acc = float(mem.acc) - 1.0
		var nxt := "b" if String(mem.get("last", "b")) == "a" else "a"
		if randf() < [0.1, 0.05, 0.0][level]:
			nxt = String(mem.get("last", "a"))   # vertippt
		mem["last"] = nxt
		held[nxt] = true
	InputHub.set_virtual(slot, mv, held)
