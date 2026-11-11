extends MinigameBase
## Schalter-Schikane (1 gegen 3): Das Trio läuft einen Hindernisparcours bis zur Zielfahne. Der Solo-Spieler
## steht am Schaltpult: Stick wählt eine von vier Fallen, A löst sie aus (jede hat eine Abklingzeit).
## Fallen: Stampfer (Warnschatten, dann kracht er runter), Klappboden (zwei von drei Platten öffnen sich),
## Windkanone (Böe zur offenen Seite – dagegenhalten!), Fässerlawine (drüberspringen). Erwischt = zurück zum
## letzten Kontrollpunkt. Pendellauf: Ziel → Start → Ziel (drei Strecken). Schaffen das zwei aus dem Trio,
## gewinnt das Trio – sonst der Solo-Spieler.
## Online: Host-Modell.

const HALF_W := 3.0
const GOAL_Z := -13.5
const CHECKS := [8.5, 1.8, -3.6, -8.6, -13.2]     # Kontrollpunkte zwischen den Abschnitten (beide Richtungen)
const START_Z := 7.6
const LEGS := 3
const SECT := [[5.2, 2.6], [1.0, -3.0], [-4.2, -8.0], [-9.0, -13.0]]   # z-Bereiche (von, bis)
const NAMES := ["Stampfer", "Klappboden", "Windkanone", "Fässer"]
const CD := [5.5, 6.0, 6.5, 5.0]

var _sel := 0
var _sel_cd := 0.0
var _cd: Array[float] = [1.5, 1.5, 1.5, 1.5]
var _trap_t: Array[float] = [0, 0, 0, 0]          # >0 = Falle läuft (Restzeit)
var _crusher: Node3D
var _tiles: Array[Dictionary] = []
var _open_mask: Array[bool] = [false, false, false]
var _fans: Array[Node3D] = []
var _barrels: Array[Dictionary] = []
var _dir: Array[float] = [-1, -1, -1, -1]         # Laufrichtung: −1 = zum Ziel, +1 = zurück zum Start
var _legs: Array[int] = [0, 0, 0, 0]
var _finished: Array[bool] = [false, false, false, false]
var _lamps: Array[MeshInstance3D] = []
var _frames: Array[MeshInstance3D] = []
var _sel_label: Label3D
var _hit_cd: Array[float] = [0, 0, 0, 0]


func _init() -> void:
	game_id = "switch_gauntlet"
	env_preset = "day"
	backdrop_style = "meadow"
	time_limit = 45.0
	score_format = "%d"
	kill_y = -40.0
	arena_radius = 12.0
	teaser_height = 1.0
	cannon_pos = Vector3(9, 0, 10)
	net_model = "host"
	spawn_points = [Vector3(7.5, 3.6, -1.0), Vector3(-1.5, 0.6, 9.5), Vector3(0.0, 0.6, 10.2), Vector3(1.5, 0.6, 9.5)]


func build_arena() -> void:
	# Startplatz, Abschnitte, Ziel; Auffangboden tief unten
	WorldKit.box(world, Vector3(HALF_W * 2, 1.0, 4.4), Vector3(0, -0.5, 8.8), Color("#7cc85a"))
	WorldKit.box(world, Vector3(HALF_W * 2, 1.0, 1.6), Vector3(0, -0.5, 1.8), Color("#e0c38a"))
	WorldKit.box(world, Vector3(HALF_W * 2, 1.0, 3.8), Vector3(0, -0.5, 3.9), Color("#c9b28a"))
	WorldKit.box(world, Vector3(HALF_W * 2, 1.0, 4.6), Vector3(0, -0.5, -6.1), Color("#b6d6ec"))
	WorldKit.box(world, Vector3(HALF_W * 2, 1.0, 5.4), Vector3(0, -0.5, -11.3), Color("#d9b48a"))
	WorldKit.box(world, Vector3(HALF_W * 2 + 2, 1.0, 3.0), Vector3(0, -0.5, -15.2), Color("#ffd166"))
	WorldKit.box(world, Vector3(40, 0.5, 40), Vector3(0, -6.0, 0), Color("#5a8a4a"))
	WorldKit.place(world, "plat/flag", Vector3(0, 0, -15.5), 0.0, 1.6)
	WorldKit.place(world, "plat/chest", Vector3(2.6, 0, -15.8), -20.0, 1.3)
	# Geländer links überall, rechts nur außerhalb des Windabschnitts
	for z0 in [[10.8, 7.0], [5.2, -3.6], [-9.0, -13.5]]:
		var zl: float = z0[0] - z0[1]
		WorldKit.box(world, Vector3(0.2, 0.8, zl), Vector3(HALF_W + 0.1, 0.4, (z0[0] + z0[1]) * 0.5), Color("#8a5a34"))
	WorldKit.box(world, Vector3(0.2, 0.8, 24.5), Vector3(-HALF_W - 0.1, 0.4, -1.4), Color("#8a5a34"))
	# 1) Stampfer
	_crusher = Node3D.new()
	_crusher.set_meta("keep_visible", true)
	world.add_child(_crusher)
	_crusher.position = Vector3(0, 4.2, 3.9)
	WorldKit.box(_crusher, Vector3(HALF_W * 2, 1.0, 2.6), Vector3.ZERO, Color("#6b6f86"), false)
	for x in [-2.0, 0.0, 2.0]:
		WorldKit.box(_crusher, Vector3(0.4, 0.4, 0.4), Vector3(x, -0.6, 0.9), Color("#ffd23f"), false)
	for s in [-1.0, 1.0]:
		WorldKit.box(world, Vector3(0.4, 5.5, 0.4), Vector3(s * (HALF_W + 0.5), 2.5, 3.9), Color("#5b5f66"), false)
	# 2) Klappboden: drei Platten nebeneinander
	for k in 3:
		var body := StaticBody3D.new()
		world.add_child(body)
		body.position = Vector3(-2.0 + k * 2.0, -0.2, -1.0)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.96, 0.4, 4.0)
		bm.material = WorldKit.mat(Color("#c98a4a"), 0.8)
		mi.mesh = bm
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.96, 0.4, 4.0)
		cs.shape = bs
		body.add_child(cs)
		_tiles.append({"body": body, "mesh": mi, "cs": cs, "x": -2.0 + k * 2.0})
	# 3) Windkanonen links
	for k in 2:
		var fan := Node3D.new()
		world.add_child(fan)
		fan.position = Vector3(-HALF_W - 0.9, 1.0, -5.0 - k * 2.2)
		WorldKit.cylinder(fan, 0.9, 0.5, Vector3.ZERO, Color("#5b5f66"), false).rotation.z = PI / 2.0
		for b in 3:
			var blade := WorldKit.box(fan, Vector3(0.1, 1.5, 0.3), Vector3(0.3, 0, 0), Color("#9be7ff"), false)
			blade.rotation.x = b * PI / 3.0
		_fans.append(fan)
	# Schaltpult-Turm rechts neben dem Parcours
	WorldKit.box(world, Vector3(3.0, 3.0, 3.0), Vector3(7.5, 1.5, -1.0), Color("#8a6a4a"))
	var panel := WorldKit.box(world, Vector3(2.4, 0.9, 0.5), Vector3(6.6, 3.45, -1.0), Color("#3d3a55"), false)
	panel.rotation.y = PI / 2.0
	for k in 4:
		var lamp := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.32
		sm.material = WorldKit.mat(Color(0.4, 1.0, 0.5), 0.3, 1.5)
		lamp.mesh = sm
		lamp.position = Vector3(6.3, 3.95, -1.9 + k * 0.6)
		world.add_child(lamp)
		_lamps.append(lamp)
		# Rahmen um den Abschnitt: zeigt die Auswahl
		var fr := MeshInstance3D.new()
		var fm := BoxMesh.new()
		var zr: Array = SECT[k]
		fm.size = Vector3(HALF_W * 2 + 0.3, 0.05, float(zr[0]) - float(zr[1]))
		var fmat := WorldKit.mat(Color(1.0, 0.4, 0.3, 0.3), 0.5, 0.8)
		fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.material = fmat
		fr.mesh = fm
		fr.position = Vector3(0, 0.03, (float(zr[0]) + float(zr[1])) * 0.5)
		world.add_child(fr)
		fr.visible = false
		_frames.append(fr)
	_sel_label = Label3D.new()
	_sel_label.font_size = 110
	_sel_label.outline_size = 22
	_sel_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sel_label.position = Vector3(7.5, 5.6, -1.0)
	world.add_child(_sel_label)
	WorldKit.scatter(world, ["nat/tree_oak", "nat/bush", "nat/flower_red", "nat/rock_large"], 16, Vector3(0, -5.7, 0), 9.0, 16.0, -5.7)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(1.5, 0, -2.0)
	c.offset = Vector3(0, 17.0, 11.0)
	c.min_dist = 0.95
	c.max_dist = 1.05


func on_start() -> void:
	var sav := avatars[solo_slot] as PartyAvatar
	sav.freeze(true)
	sav.rig.face_now(Vector3.LEFT)
	for i in active_slots():
		(avatars[i] as PartyAvatar).can_shove = false
		if i != solo_slot:
			(avatars[i] as PartyAvatar).max_speed = 6.2   # Parcours-Tempo: Fallen sollen eine Chance haben


func check_end() -> bool:
	return _finished.count(true) >= 2


func team_result() -> int:
	return (1 - teams[solo_slot]) if _finished.count(true) >= 2 else teams[solo_slot]


func on_tick(delta: float) -> void:
	_solo_input(delta)
	for k in 4:
		_cd[k] = maxf(0.0, _cd[k] - delta)
	_update_crusher(delta)
	_update_tiles(delta)
	_update_wind(delta)
	_update_barrels(delta)
	for i in active_slots():
		if i == solo_slot:
			continue
		_hit_cd[i] = maxf(0.0, _hit_cd[i] - delta)
		var av := avatars[i] as PartyAvatar
		var z := av.global_position.z
		if av.global_position.y < -2.5:
			_penalty(i, false)
		var at_end := (_dir[i] < 0.0 and z < GOAL_Z) or (_dir[i] > 0.0 and z > START_Z)
		if not _finished[i] and at_end and av.global_position.y > -0.5:
			_legs[i] += 1
			add_score(i, 1.0, av.global_position + Vector3.UP * 2.0)
			FX.stars(av.global_position + Vector3.UP, Game.player_color(i), 16)
			if _legs[i] >= LEGS:
				_finished[i] = true
				av.rig.react("victory")
				Audio.jingle("fanfare", false)
			else:
				_dir[i] = -_dir[i]
				av.rig.react("determined")
				Audio.sfx("chime", av.global_position)
				Juice.float_text(self, av.global_position + Vector3.UP * 2.6, "Und zurück!" if _dir[i] > 0.0 else "Noch einmal!", Color("#fff1a8"), 64)
	_visuals(delta)


func _solo_input(delta: float) -> void:
	_sel_cd = maxf(0.0, _sel_cd - delta)
	var mv := InputHub.move(solo_slot)
	var dir := 0
	if absf(mv.y) > 0.5:
		dir = 1 if mv.y < 0.0 else -1     # Stick hoch = weiter Richtung Ziel
	elif absf(mv.x) > 0.5:
		dir = 1 if mv.x > 0.0 else -1
	if dir != 0 and _sel_cd <= 0.0:
		_sel = clampi(_sel + dir, 0, 3)
		_sel_cd = 0.22
		Audio.sfx("ui_move", Vector3(7.5, 3.5, -1.0), -8.0)
	if InputHub.pressed(solo_slot, "a") and _cd[_sel] <= 0.0:
		_trigger(_sel)


func _trigger(k: int) -> void:
	_cd[k] = CD[k]
	var sav := avatars[solo_slot] as PartyAvatar
	sav.rig.play_once("interact", "idle", 1.6)
	Audio.sfx("click", sav.global_position)
	match k:
		0:
			_trap_t[0] = 2.2
			MgKit.warn_disc(world, Vector3(0, 0.05, 3.9), 2.6, Color(0.2, 0, 0, 0.6), 0.8)
			Audio.sfx("alert", _crusher.global_position, -4.0)
		1:
			_trap_t[1] = 2.3
			var keep := rng.randi() % 3
			for t in 3:
				_open_mask[t] = t != keep
			Audio.sfx("creak", Vector3(0, 0, -1), -2.0)
		2:
			_trap_t[2] = 2.8
			Audio.sfx("woom", _fans[0].global_position, -2.0, 0.8)
		3:
			_trap_t[3] = 0.01
			var lanes := [-2.0, 0.0, 2.0]
			var skip := rng.randi() % 3
			for l in 3:
				if l != skip:
					_spawn_barrel(float(lanes[l]), l * 0.35)
			Audio.sfx("drop", Vector3(0, 0, GOAL_Z), -2.0)


func _update_crusher(delta: float) -> void:
	if _trap_t[0] <= 0.0:
		return
	var before := _trap_t[0]
	_trap_t[0] -= delta
	var t := 2.2 - _trap_t[0]
	if t < 0.8:
		_crusher.position.y = 4.2 + sin(t * 40.0) * 0.05
	elif t < 0.95:
		_crusher.position.y = lerpf(4.2, 0.5, (t - 0.8) / 0.15)
	elif t < 1.3:
		_crusher.position.y = 0.5
		if 2.2 - before < 0.95:
			Juice.shake(0.35)
			Audio.sfx("stone_hit", _crusher.global_position, 2.0, 0.6)
			FX.dust(Vector3(0, 0.2, 3.9), Color(0.85, 0.75, 0.6), 22, 2.2)
		for i in active_slots():
			if i == solo_slot:
				continue
			var p := (avatars[i] as PartyAvatar).global_position
			if absf(p.z - 3.9) < 1.35 and p.y < 1.2:
				_penalty(i, true)
	else:
		_crusher.position.y = lerpf(0.5, 4.2, clampf((t - 1.3) / 0.9, 0.0, 1.0))


func _update_tiles(delta: float) -> void:
	if _trap_t[1] <= 0.0:
		return
	_trap_t[1] -= delta
	var t := 2.3 - _trap_t[1]
	for k in 3:
		var body: Node3D = _tiles[k].body
		if not _open_mask[k]:
			continue
		if t < 0.6:
			body.position = Vector3(float(_tiles[k].x) + sin(t * 50.0) * 0.04, -0.2, -1.0)
		elif t < 2.0:
			(_tiles[k].cs as CollisionShape3D).disabled = true
			body.rotation.z = lerpf(body.rotation.z, 1.4 * (1.0 if k >= 1 else -1.0), 0.3)
		else:
			(_tiles[k].cs as CollisionShape3D).disabled = false
			body.rotation.z = lerpf(body.rotation.z, 0.0, 0.4)
	if _trap_t[1] <= 0.0:
		for k in 3:
			(_tiles[k].body as Node3D).rotation.z = 0.0
			(_tiles[k].body as Node3D).position = Vector3(float(_tiles[k].x), -0.2, -1.0)
			(_tiles[k].cs as CollisionShape3D).disabled = false
			_open_mask[k] = false


func _update_wind(delta: float) -> void:
	if _trap_t[2] <= 0.0:
		return
	_trap_t[2] -= delta
	var t := 2.8 - _trap_t[2]
	for f in _fans:
		f.rotation.x += delta * (6.0 if t < 0.7 else 24.0)
	if t >= 0.7:
		for i in active_slots():
			if i == solo_slot:
				continue
			var av := avatars[i] as PartyAvatar
			if av.global_position.z < -4.0 and av.global_position.z > -8.2:
				av.velocity.x += 26.0 * delta
		if randf() < 0.5:
			FX.dust(Vector3(-2.5, randf_range(0.3, 1.6), randf_range(-8.0, -4.2)), Color(0.9, 0.97, 1.0), 2, 0.5)


func _spawn_barrel(x: float, delay: float) -> void:
	var node := WorldKit.place(world, "plat/barrel", Vector3(x, 0.55, -13.2), 0.0, 1.0)
	node.rotation.z = PI / 2.0
	node.visible = false
	_barrels.append({"node": node, "x": x, "z": -13.2, "delay": delay, "hit": {}})


func _update_barrels(delta: float) -> void:
	var k := _barrels.size() - 1
	while k >= 0:
		var b := _barrels[k]
		b.delay = float(b.delay) - delta
		var node: Node3D = b.node
		if float(b.delay) > 0.0:
			k -= 1
			continue
		node.visible = true
		b.z = float(b.z) + 7.0 * delta
		node.position = Vector3(float(b.x), 0.55, float(b.z))
		node.rotation.x += 7.0 * delta / 0.55
		for i in active_slots():
			if i == solo_slot or (b.hit as Dictionary).has(i):
				continue
			var av := avatars[i] as PartyAvatar
			var p := av.global_position
			if absf(p.x - float(b.x)) < 1.05 and absf(p.z - float(b.z)) < 0.7 and p.y < 0.9:
				(b.hit as Dictionary)[i] = true
				av.apply_knockback(Vector3(0, 0, 1), 9.0, 0.6, 4.0)
				av.rig.react("trip_fall")
				Audio.sfx("wood_hit", p)
				add_score(solo_slot, 1.0)
		if float(b.z) > -8.4:
			FX.dust(node.position, Color(0.8, 0.6, 0.4), 6, 0.8)
			node.queue_free()
			_barrels.remove_at(k)
		k -= 1


func _penalty(i: int, squash: bool) -> void:
	if _hit_cd[i] > 0.0 or _finished[i]:
		return
	_hit_cd[i] = 1.0
	var av := avatars[i] as PartyAvatar
	if squash:
		av.rig.react("land_flat")
		FX.stars(av.global_position + Vector3.UP * 0.5, Color(1, 1, 0.6), 10)
		Audio.sfx("hit_soft", av.global_position)
	add_score(solo_slot, 1.0)
	# Nächster Kontrollpunkt hinter der Figur (bezogen auf die Laufrichtung)
	var z := av.global_position.z
	var cz := START_Z + 1.0 if _dir[i] < 0.0 else GOAL_Z
	for c in CHECKS:
		var cf := float(c)
		if _dir[i] < 0.0 and cf > z and cf < cz:
			cz = cf
		elif _dir[i] > 0.0 and cf < z and cf > cz:
			cz = cf
	av.global_position = Vector3(clampf(av.global_position.x, -2.0, 2.0), 0.6, cz)
	av.velocity = Vector3.ZERO
	FX.dust(av.global_position, Color(1, 1, 1), 8, 0.8)
	Audio.sfx("plop", av.global_position)


func _visuals(_delta: float) -> void:
	for k in 4:
		var ready := _cd[k] <= 0.0
		var m := (_lamps[k].mesh as SphereMesh).material as StandardMaterial3D
		m.albedo_color = Color(0.4, 1.0, 0.5) if ready else Color(1.0, 0.35, 0.3)
		m.emission = m.albedo_color
		_lamps[k].scale = Vector3.ONE * (1.5 if k == _sel else 1.0)
		_frames[k].visible = k == _sel
	_sel_label.text = NAMES[_sel] + ("" if _cd[_sel] <= 0.0 else " (%.0f)" % ceil(_cd[_sel]))
	_sel_label.modulate = Color("#7dff8a") if _cd[_sel] <= 0.0 else Color("#ffb38a")


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	d["s"] = _sel
	d["cd"] = _cd.map(func(c: float) -> float: return snappedf(c, 0.1))
	d["cr"] = snappedf(_crusher.position.y, 0.01)
	d["tl"] = _tiles.map(func(t: Dictionary) -> float: return snappedf((t.body as Node3D).rotation.z, 0.02))
	d["wf"] = 1 if _trap_t[2] > 0.0 else 0
	d["br"] = _barrels.map(func(b: Dictionary) -> Array: return [float(b.x), snappedf(float(b.z), 0.02), 1 if float(b.delay) <= 0.0 else 0])
	d["fin"] = _finished.map(func(f: bool) -> int: return 1 if f else 0)
	d["dir"] = _dir.duplicate()
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	_sel = int(d.get("s", _sel))
	var cd: Array = d.get("cd", [])
	for k in mini(4, cd.size()):
		_cd[k] = float(cd[k])
	var cr := float(d.get("cr", _crusher.position.y))
	if cr < 0.6 and _crusher.position.y >= 0.6:
		Juice.shake(0.35)
		Audio.sfx("stone_hit", _crusher.global_position, 2.0, 0.6)
		FX.dust(Vector3(0, 0.2, 3.9), Color(0.85, 0.75, 0.6), 22, 2.2)
	_crusher.position.y = cr
	var tl: Array = d.get("tl", [])
	for k in mini(3, tl.size()):
		(_tiles[k].body as Node3D).rotation.z = float(tl[k])
	if int(d.get("wf", 0)) == 1:
		for f in _fans:
			f.rotation.x += 0.6
	var br: Array = d.get("br", [])
	while _barrels.size() < br.size():
		_spawn_barrel(0.0, 0.0)
	while _barrels.size() > br.size():
		(_barrels[-1].node as Node3D).queue_free()
		_barrels.remove_at(_barrels.size() - 1)
	for k in br.size():
		var node: Node3D = _barrels[k].node
		node.visible = int(br[k][2]) == 1
		node.position = Vector3(float(br[k][0]), 0.55, float(br[k][1]))
		node.rotation.x = float(br[k][1]) * 2.0
	var fin: Array = d.get("fin", [])
	for i in mini(4, fin.size()):
		_finished[i] = int(fin[i]) == 1
	var dr: Array = d.get("dir", [])
	for i in mini(4, dr.size()):
		_dir[i] = float(dr[i])
	_visuals(0.0)


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var level: int = Game.players[slot].cpu_level
	if slot == solo_slot:
		_cpu_solo(slot, level)
		return
	var av := avatars[slot] as PartyAvatar
	if _finished[slot]:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var mem: Dictionary = cpu_mem[slot]
	if not mem.has("lane"):
		mem["lane"] = [0.0, -1.6, 0.0, 1.6][slot]
	var p := av.global_position
	var lane := float(mem.lane)
	var dir := _dir[slot]
	var fwd := dir
	var held := {}
	# Stampfer: im Warnschatten → raus (vor oder zurück, was näher ist); davor warten
	var t0 := 2.2 - _trap_t[0]
	if _trap_t[0] > 0.0 and t0 < 1.3:
		if absf(p.z - 3.9) < 1.8 + Game.lv([0.0, 0.3, 0.5], level):
			fwd = -1.0 if p.z < 3.9 else 1.0
		elif (dir < 0.0 and p.z > 3.9 and p.z < 6.5) or (dir > 0.0 and p.z < 3.9 and p.z > 1.3):
			fwd = 0.0
	# Klappboden: auf die feste Platte, vorher abwarten
	if _trap_t[1] > 0.0:
		for k in 3:
			if not _open_mask[k]:
				lane = float(_tiles[k].x)
		var near := (dir < 0.0 and p.z > 1.0 and p.z < 2.6) or (dir > 0.0 and p.z < -3.0 and p.z > -4.6)
		if near and level > 0 and absf(p.x - lane) > 0.6:
			fwd = -dir * 0.2
	# Wind: dagegenhalten
	var side := (lane - p.x) * 1.2
	if _trap_t[2] > 0.0 and p.z < -3.6 and p.z > -8.4:
		side = -Game.lv([0.5, 0.8, 1.0], level)
	# Fässer: springen, wenn eins in der eigenen Spur naht
	for b in _barrels:
		if float(b.delay) <= 0.0 and absf(p.x - float(b.x)) < 1.1:
			var dz := (p.z - float(b.z)) * (1.0 if dir < 0.0 else -1.0)
			if absf(p.z - float(b.z)) < Game.lv([0.9, 1.2, 1.4], level) + (0.0 if dir < 0.0 else 0.3) and av.is_on_floor() and (dz > 0.0 or dir > 0.0):
				held["a"] = true
	InputHub.set_virtual(slot, Vector2(clampf(side, -1.0, 1.0), fwd).limit_length(1.0), held)


func _cpu_solo(slot: int, level: int) -> void:
	# Ziel: die Falle, in deren Abschnitt (oder kurz davor) die meisten Läufer stecken
	var best := -1
	var bn := 0
	for k in 4:
		var zr: Array = SECT[k]
		var n := 0
		for i in active_slots():
			if i == slot or _finished[i]:
				continue
			var z := (avatars[i] as PartyAvatar).global_position.z
			if z < float(zr[0]) + Game.lv([0.2, 0.8, 1.4], level) and z > float(zr[1]):
				n += 1
		if n > bn and _cd[k] <= 0.0:
			bn = n
			best = k
	var mv := Vector2.ZERO
	var held := {}
	if best >= 0:
		if best != _sel:
			mv.y = -1.0 if best > _sel else 1.0
		elif randf() < Game.lv([0.05, 0.12, 0.25], level):
			held["a"] = true
	InputHub.set_virtual(slot, mv, held)
