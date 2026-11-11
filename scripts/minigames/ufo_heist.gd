extends MinigameBase
## UFO-Kaperung (1 gegen 3): Der Solo-Spieler steuert eine fliegende Untertasse. A halten = Traktorstrahl –
## wer im Lichtkegel steht, schwebt langsam nach oben und ist bei voller Höhe entführt (A hämmern = zappeln,
## das bremst). Das Trio stellt sich auf die drei Energiefelder: Ist ein Feld voll geladen, startet eine
## Konfetti-Rakete Richtung UFO (ausweichen möglich!). Drei Treffer, und das UFO trudelt davon.
## Solo gewinnt, wenn alle drei entführt sind; das Trio, wenn jemand bis zum Schluss übrig ist oder das UFO fällt.
## Online: Host-Modell.

const ARENA_R := 9.0
const UFO_H := 6.0
const BEAM_R := 1.7
const PADS := [Vector3(0, 0, -5.5), Vector3(-4.8, 0, 2.8), Vector3(4.8, 0, 2.8)]

var _ufo: Node3D
var _beam: MeshInstance3D
var _shadow: MeshInstance3D
var _lights: Array[MeshInstance3D] = []
var _uv := Vector3.ZERO
var _beaming := false
var _hp := 3
var _lift: Array[float] = [0, 0, 0, 0]
var _pad_charge: Array[float] = [0, 0, 0]
var _pad_fill: Array[MeshInstance3D] = []
var _rockets: Array[Dictionary] = []   # {node, pos, vel, t}
var _done := false
var _light_t := 0.0
var _fire_cd := 0.0


func _init() -> void:
	game_id = "ufo_heist"
	env_preset = "night"
	backdrop_style = "night"
	time_limit = 45.0
	score_format = "%d"
	arena_radius = 9.5
	teaser_height = 2.0
	cannon_pos = Vector3(0, 0, 12)
	net_model = "host"
	spawn_points = [Vector3(0, UFO_H, 0), Vector3(-3, 0.6, 3), Vector3(3, 0.6, 3), Vector3(0, 0.6, -2.5)]


func build_arena() -> void:
	# Bauernhof bei Nacht: Wiese, Kornkreis, Scheune, Zaun, Heuballen
	WorldKit.cylinder(world, ARENA_R + 3.0, 0.5, Vector3(0, -0.25, 0), Color("#4f8a3c"))
	for k in 3:
		MgKit.ring(world, 2.0 + k * 2.4, 0.12, Color(0.75, 0.95, 0.6, 0.6), 0.3).position.y = 0.02
	for i in 20:
		var a := TAU * i / 20.0
		WorldKit.place(world, "nat/fence", Vector3(cos(a), 0, sin(a)) * (ARENA_R + 0.6), rad_to_deg(-a), 1.2, true)
	WorldKit.cottage(world, Vector3(-9.0, 0, -12.0), 0.4, 1.8, Color("#c0392b"))
	for i in 5:
		WorldKit.cylinder(world, 0.7, 1.0, Vector3(8.0 + (i % 2) * 1.3, 0.5, -9.0 + i * 1.6), Color("#e9c46a"), false).rotation.z = PI / 2.0
	WorldKit.place(world, "pet/cow", Vector3(11.0, 0, 3.0), -60.0, 1.5)
	WorldKit.place(world, "pet/pig", Vector3(-11.5, 0, 4.0), 70.0, 1.3)
	for k in 3:
		var pad := WorldKit.cylinder(world, 1.4, 0.1, PADS[k] + Vector3(0, 0.05, 0), Color("#3a6b8a"), false)
		MgKit.ring(pad, 1.35, 0.1, Color(0.5, 0.9, 1.0), 1.2).position.y = 0.06
		var fill := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.25
		cm.bottom_radius = 1.25
		cm.height = 0.04
		cm.material = WorldKit.mat(Color(0.4, 1.0, 0.9), 0.3, 1.6)
		fill.mesh = cm
		fill.position = PADS[k] + Vector3(0, 0.13, 0)
		fill.scale = Vector3(0.01, 1, 0.01)
		world.add_child(fill)
		_pad_fill.append(fill)
		WorldKit.cylinder(world, 0.28, 1.1, PADS[k] + Vector3(0, 0.55, -1.7), Color("#5b5f66"), false)
	_build_ufo()


func _build_ufo() -> void:
	_ufo = Node3D.new()
	_ufo.set_meta("keep_visible", true)   # der Solo-Startpunkt liegt im UFO – nie ausblenden
	world.add_child(_ufo)
	_ufo.position = Vector3(0, UFO_H, 0)
	var disc := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 2.0
	sm.height = 0.9
	sm.material = WorldKit.mat(Color("#d9e2f2"), 0.35, 0.22)
	(sm.material as StandardMaterial3D).metallic = 0.3
	disc.mesh = sm
	_ufo.add_child(disc)
	# Leuchtring unten und grünes Bodenlicht – nachts gut sichtbar
	var glow := MgKit.ring(_ufo, 1.2, 0.12, Color(0.55, 1.0, 0.7), 2.5)
	glow.position.y = -0.32
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.6, 1.0, 0.7)
	lamp.light_energy = 1.6
	lamp.omni_range = 8.0
	lamp.position.y = -0.8
	_ufo.add_child(lamp)
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.95
	dm.height = 1.6
	var gm := WorldKit.mat(Color(0.6, 0.95, 1.0, 0.35), 0.05)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.material = gm
	dome.mesh = dm
	dome.position.y = 0.45
	_ufo.add_child(dome)
	for k in 8:
		var a := TAU * k / 8.0
		var l := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.14
		lm.height = 0.28
		lm.material = WorldKit.mat(Color(1, 0.9, 0.3), 0.3, 2.0)
		l.mesh = lm
		l.position = Vector3(cos(a) * 1.75, -0.05, sin(a) * 1.75)
		_ufo.add_child(l)
		_lights.append(l)
	_beam = MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.6
	bm.bottom_radius = BEAM_R
	bm.height = UFO_H
	var bmat := WorldKit.mat(Color(0.6, 1.0, 0.7, 0.28), 0.2, 0.8)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.material = bmat
	_beam.mesh = bm
	_beam.position.y = -UFO_H * 0.5
	_ufo.add_child(_beam)
	_beam.visible = false
	_shadow = MgKit.warn_disc(world, Vector3(0, 0.04, 0), 1.6, Color(0, 0, 0, 0.5), 9999.0)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 1.5, 0.5)
	c.offset = Vector3(0, 13.0, 13.0)
	c.min_dist = 0.95
	c.max_dist = 1.05


func on_start() -> void:
	var sav := avatars[solo_slot] as PartyAvatar
	sav.freeze(true)
	sav.set_physics_process(false)
	sav.rig.scale *= 0.75   # Pilot im Cockpit etwas kleiner (nur Optik – Körper nicht skalieren)
	for i in active_slots():
		(avatars[i] as PartyAvatar).can_shove = false


func check_end() -> bool:
	if _done:
		return true
	var left := 0
	for i in active_slots():
		if i != solo_slot and alive[i]:
			left += 1
	return left == 0 or _hp <= 0


func team_result() -> int:
	return teams[solo_slot] if _hp > 0 and _trio_left() == 0 else (1 - teams[solo_slot])


func _trio_left() -> int:
	var n := 0
	for i in active_slots():
		if i != solo_slot and alive[i]:
			n += 1
	return n


func on_tick(delta: float) -> void:
	# UFO steuern: langsamer, solange der Strahl an ist
	var mv := InputHub.move(solo_slot)
	_beaming = InputHub.held(solo_slot, "a")
	var spd := 4.0 if _beaming else 7.5
	_uv = _uv.lerp(Vector3(mv.x, 0, mv.y) * spd, minf(1.0, delta * 4.0))
	var p := _ufo.position + _uv * delta
	var flat := Vector2(p.x, p.z)
	if flat.length() > ARENA_R - 1.0:
		flat = flat.normalized() * (ARENA_R - 1.0)
	_ufo.position = Vector3(flat.x, UFO_H + sin((time_limit - time_left) * 2.0) * 0.15, flat.y)
	_ufo.rotation.z = -_uv.x * 0.03
	_ufo.rotation.x = _uv.z * 0.03
	var sav := avatars[solo_slot] as PartyAvatar
	sav.global_position = _ufo.position + Vector3(0, -0.1, 0)
	# Niemand versteckt sich hinter dem Zaun
	for i in active_slots():
		if i != solo_slot and alive[i]:
			var av := avatars[i] as PartyAvatar
			var fp := Vector2(av.global_position.x, av.global_position.z)
			if fp.length() > ARENA_R - 0.4:
				fp = fp.normalized() * (ARENA_R - 0.4)
				av.global_position = Vector3(fp.x, av.global_position.y, fp.y)
	_tractor(delta)
	_update_pads(delta)
	_update_rockets(delta)
	_visuals(delta)


func _tractor(delta: float) -> void:
	for i in active_slots():
		if i == solo_slot or not alive[i]:
			continue
		var av := avatars[i] as PartyAvatar
		var off := Vector2(av.global_position.x - _ufo.position.x, av.global_position.z - _ufo.position.z)
		var inside := _beaming and off.length() < BEAM_R
		if inside:
			_lift[i] += 0.45 * delta
			# Teamwork: ein freier Mitspieler daneben hält fest
			for j in active_slots():
				if j != i and j != solo_slot and alive[j] and _lift[j] <= 0.0 and (avatars[j] as PartyAvatar).global_position.distance_to(av.global_position) < 1.6:
					_lift[i] = maxf(0.0, _lift[i] - 0.5 * delta)
					if randf() < 0.05:
						FX.stars(av.global_position + Vector3.UP, Color(1, 1, 0.6), 3)
			if InputHub.pressed(i, "a"):
				_lift[i] = maxf(0.0, _lift[i] - 0.042)
				if randf() < 0.1:
					av.rig.react("scared")
			# Zur Strahlmitte ziehen und anheben
			var target := Vector3(_ufo.position.x, _lift[i] * (UFO_H - 1.2), _ufo.position.z)
			av.global_position = av.global_position.lerp(target, minf(1.0, delta * 3.0))
			av.velocity = Vector3.ZERO
			av.can_move = false
			if _lift[i] >= 1.0:
				_abduct(i)
		elif _lift[i] > 0.0:
			_lift[i] = maxf(0.0, _lift[i] - 1.2 * delta)
			av.can_move = true


func _abduct(i: int) -> void:
	var av := avatars[i] as PartyAvatar
	_lift[i] = 0.0
	FX.sparks(av.global_position, Color(0.6, 1.0, 0.7), 16)
	FX.ring(_ufo.position + Vector3.DOWN * 0.4, Color(0.6, 1.0, 0.7), 2.5, 0.4)
	Audio.sfx("laser", av.global_position)
	Juice.shake(0.2)
	av.visible = false
	av.global_position = Vector3(0, -20, 0)
	add_score(solo_slot, 1.0)
	eliminate(i)
	(avatars[solo_slot] as PartyAvatar).rig.react("taunt")


func _update_pads(delta: float) -> void:
	_fire_cd = maxf(0.0, _fire_cd - delta)
	for k in 3:
		var on := false
		for i in active_slots():
			if i == solo_slot or not alive[i]:
				continue
			var av := avatars[i] as PartyAvatar
			if Vector2(av.global_position.x - PADS[k].x, av.global_position.z - PADS[k].z).length() < 1.4 and av.global_position.y < 0.8:
				on = true
		if on:
			_pad_charge[k] = minf(1.0, _pad_charge[k] + delta / 6.0)
			if _pad_charge[k] >= 1.0 and _fire_cd <= 0.0:
				_fire_cd = 6.0
				_pad_charge[k] = 0.0
				_fire(k)
		else:
			_pad_charge[k] = maxf(0.0, _pad_charge[k] - delta * 0.25)


func _fire(k: int) -> void:
	var from: Vector3 = PADS[k] + Vector3(0, 1.2, -1.7)
	var aim := _ufo.position + _uv * 0.6
	var node := Node3D.new()
	world.add_child(node)
	node.position = from
	var body := WorldKit.cylinder(node, 0.18, 0.7, Vector3.ZERO, Color("#ff6bd5"), false)
	body.rotation.x = PI / 2.0
	FX.make_trail(node, "sparks")
	_rockets.append({"node": node, "pos": from, "vel": (aim - from).normalized() * 6.5, "t": 2.2})
	Audio.sfx("cannon", from, -4.0)
	FX.dust(from, Color(1, 0.9, 1.0), 8, 0.8)


func _update_rockets(delta: float) -> void:
	var k := _rockets.size() - 1
	while k >= 0:
		var r := _rockets[k]
		r.pos = (r.pos as Vector3) + (r.vel as Vector3) * delta
		r.t = float(r.t) - delta
		var node: Node3D = r.node
		node.position = r.pos
		node.look_at(node.position + (r.vel as Vector3), Vector3.UP)
		var hit := (r.pos as Vector3).distance_to(_ufo.position) < 2.0
		if hit or float(r.t) <= 0.0:
			if hit:
				_hp -= 1
				FX.explosion(r.pos as Vector3, 0.8, false)
				FX.stars(r.pos as Vector3, Color(1, 0.8, 1.0), 14)
				Audio.sfx("explosion", r.pos as Vector3, -2.0)
				Juice.shake(0.35)
				for i in active_slots():
					if i != solo_slot and alive[i]:
						add_score(i, 1.0)
				(avatars[solo_slot] as PartyAvatar).rig.react("shocked")
				if _hp <= 0:
					_ufo_down()
			else:
				FX.sparks(r.pos as Vector3, Color(1, 0.7, 0.9), 8)
			node.queue_free()
			_rockets.remove_at(k)
		k -= 1


func _ufo_down() -> void:
	_done = true
	CutsceneManager.big_word("UFO abgeschossen!", Color("#ff9ff3"), 0.9)
	var tw := _ufo.create_tween()
	tw.tween_property(_ufo, "rotation:z", 2.5, 1.2)
	tw.parallel().tween_property(_ufo, "position", _ufo.position + Vector3(14, 6, -10), 1.2).set_ease(Tween.EASE_IN)


func _visuals(delta: float) -> void:
	_beam.visible = _beaming
	if _beaming:
		_beam.rotation.y += delta * 2.0
	_shadow.position = Vector3(_ufo.position.x, 0.04, _ufo.position.z)
	_light_t += delta * (8.0 if _beaming else 3.0)
	for k in _lights.size():
		var on := int(_light_t + k) % 3 == 0
		(_lights[k].mesh as SphereMesh).material.emission_energy_multiplier = 3.0 if on else 0.4
	for k in 3:
		var s := maxf(_pad_charge[k], 0.01)
		_pad_fill[k].scale = Vector3(s, 1, s)
	# Damage: Rauchfahne bei wenig Leben
	if _hp < 3 and randf() < 0.15 * (3 - _hp):
		FX.dust(_ufo.position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), Color(0.3, 0.3, 0.35), 2, 0.6)


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	d["u"] = [snappedf(_ufo.position.x, 0.01), snappedf(_ufo.position.y, 0.01), snappedf(_ufo.position.z, 0.01), 1 if _beaming else 0, _hp]
	d["pc"] = _pad_charge.map(func(c: float) -> float: return snappedf(c, 0.02))
	d["rk"] = _rockets.map(func(r: Dictionary) -> Array: return [snappedf((r.pos as Vector3).x, 0.05), snappedf((r.pos as Vector3).y, 0.05), snappedf((r.pos as Vector3).z, 0.05)])
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var u: Array = d.get("u", [])
	if u.size() == 5:
		_ufo.position = Vector3(float(u[0]), float(u[1]), float(u[2]))
		_beaming = int(u[3]) == 1
		if int(u[4]) < _hp:
			FX.stars(_ufo.position, Color(1, 0.8, 1.0), 14)
			Audio.sfx("explosion", _ufo.position, -2.0)
			Juice.shake(0.35)
			if int(u[4]) <= 0:
				_ufo_down()
		_hp = int(u[4])
	var pc: Array = d.get("pc", [])
	for k in mini(3, pc.size()):
		_pad_charge[k] = float(pc[k])
	var rk: Array = d.get("rk", [])
	while _rockets.size() < rk.size():
		var node := Node3D.new()
		world.add_child(node)
		WorldKit.cylinder(node, 0.18, 0.7, Vector3.ZERO, Color("#ff6bd5"), false).rotation.x = PI / 2.0
		_rockets.append({"node": node, "pos": Vector3.ZERO, "vel": Vector3.ZERO, "t": 9.0})
	while _rockets.size() > rk.size():
		(_rockets[-1].node as Node3D).queue_free()
		_rockets.remove_at(_rockets.size() - 1)
	for k in rk.size():
		(_rockets[k].node as Node3D).position = Vector3(float(rk[k][0]), float(rk[k][1]), float(rk[k][2]))
	for i in 4:
		if avatars[i] and not alive[i] and i != solo_slot:
			(avatars[i] as PartyAvatar).visible = false
	_visuals(1.0 / 30.0)


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var level: int = Game.players[slot].cpu_level
	if slot == solo_slot:
		_cpu_ufo(slot, level)
		return
	var av := avatars[slot] as PartyAvatar
	var held := {}
	if not alive[slot]:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	if _lift[slot] > 0.0:
		# Zappeln mit menschlichem Tempo (Tipps pro Sekunde je Stufe)
		var mem: Dictionary = cpu_mem[slot]
		mem["acc"] = float(mem.get("acc", 0.0)) + [5.0, 7.0, 9.0][level] / 60.0
		if float(mem.acc) >= 1.0:
			mem.acc = float(mem.acc) - 1.0
			held["a"] = true
		InputHub.set_virtual(slot, Vector2.ZERO, held)
		return
	var p := av.global_position
	var off := Vector2(p.x - _ufo.position.x, p.z - _ufo.position.z)
	# Freies Energiefeld suchen, das weit genug vom UFO entfernt ist
	var best := Vector3.INF
	var bs := INF
	for k in 3:
		var pd: Vector3 = PADS[k]
		var dist_ufo := Vector2(pd.x - _ufo.position.x, pd.z - _ufo.position.z).length()
		var sc := pd.distance_to(p) - dist_ufo * 0.8 - _pad_charge[k] * 3.0
		if sc < bs:
			bs = sc
			best = pd
	for j in active_slots():
		if j != slot and j != solo_slot and alive[j] and _lift[j] > 0.15 and level > 0:
			var jp := (avatars[j] as PartyAvatar).global_position
			if jp.distance_to(p) < 6.0:
				best = jp
	var to := Vector2(best.x - p.x, best.z - p.z)
	var mv := to.normalized() * clampf(to.length(), 0.0, 1.0)
	if off.length() < [2.0, 2.8, 3.4][level]:
		mv = (mv * 0.3 + off.normalized() * 1.2)
	InputHub.set_virtual(slot, mv.limit_length(1.0), held)


func _cpu_ufo(slot: int, level: int) -> void:
	var held := {}
	var target := Vector3.INF
	var bd := INF
	for i in active_slots():
		if i == slot or not alive[i]:
			continue
		var av := avatars[i] as PartyAvatar
		var d := Vector2(av.global_position.x - _ufo.position.x, av.global_position.z - _ufo.position.z).length() - _lift[i] * 3.0
		if d < bd:
			bd = d
			target = av.global_position
	var mv := Vector2.ZERO
	if target != Vector3.INF:
		var to := Vector2(target.x - _ufo.position.x, target.z - _ufo.position.z)
		mv = to.normalized() * clampf(to.length() * 0.7, 0.0, 1.0)
		if to.length() < BEAM_R * [0.8, 1.0, 1.15][level]:
			held["a"] = true
	# Raketen ausweichen (seitlich)
	for r in _rockets:
		var rv: Vector3 = r.vel
		var rel: Vector3 = _ufo.position - (r.pos as Vector3)
		if rel.length() < 6.0 and rel.dot(rv) > 0.0 and randf() < [0.2, 0.6, 0.9][level]:
			var side := Vector2(-rv.z, rv.x).normalized()
			mv = side
			held.erase("a")
	InputHub.set_virtual(slot, mv.limit_length(1.0), held)
