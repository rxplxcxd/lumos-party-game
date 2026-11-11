extends MinigameBase
## Eislauf-Münzjagd: Ein zugefrorener Teich voller Münzen (in Mustern: Reihe, Kreis, Haufen; manchmal eine
## dicke Goldmünze für 5). Auf dem Eis schlittert alles. B = Schubsen – wer geschubst wird, verliert zwei
## Münzen, die übers Eis kullern. Ein Eisbär schiebt seinen Schneepflug über den Teich: Kontakt kostet eine Münze.
## Online: Host-Modell (Host verwaltet Münzen, Eisbär und Klau).

const POND_R := 9.0
const MAX_COINS := 16

var _coins: Array[Dictionary] = []   # {pos, val, node, vel}
var _wave_t := 0.5
var _bear: Node3D
var _bear_t := 0.0
var _bear_hit: Array[float] = [0, 0, 0, 0]
var _next_id := 0


func _init() -> void:
	game_id = "ice_coins"
	fair_spawns = true   # Startplätze jede Runde neu auslosen (kein fester Platzvorteil)
	env_preset = "snow"
	backdrop_style = "sky_day"
	time_limit = 40.0
	score_format = "%d Münzen"
	arena_radius = 9.5
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 12)
	net_model = "host"
	spawn_points = [Vector3(-3, 0.6, -3), Vector3(3, 0.6, -3), Vector3(-3, 0.6, 3), Vector3(3, 0.6, 3)]


func build_arena() -> void:
	WorldKit.box(world, Vector3(40, 0.4, 40), Vector3(0, -0.45, 0), Color("#f4f9ff"), false)
	WorldKit.cylinder(world, POND_R, 0.5, Vector3(0, -0.25, 0), Color("#a9dcf5"))
	var gloss := WorldKit.cylinder(world, POND_R - 0.3, 0.02, Vector3(0, 0.01, 0), Color("#d4f0ff"), false)
	(gloss.get_child(0) as MeshInstance3D).material_override = WorldKit.mat(Color(0.85, 0.95, 1.0, 1.0), 0.05, 0.1)
	# Schneewall als Bande (rundum fest), Lichterketten, Schneemänner, Hütte
	for i in 28:
		var a := TAU * i / 28.0
		var w := WorldKit.box(world, Vector3(2.3, 0.9, 0.9), Vector3(cos(a) * (POND_R + 0.4), 0.2, sin(a) * (POND_R + 0.4)), Color("#ffffff"))
		w.rotation.y = -a + PI / 2.0
	for i in 6:
		var a2 := TAU * i / 6.0 + 0.5
		var p := Vector3(cos(a2), 0, sin(a2)) * 12.5
		WorldKit.place(world, ["hk/snowman", "hk/tree_snow", "hk/tree_decorated", "hk/present", "hk/tree_snow_b", "hk/lantern"][i], p, rad_to_deg(-a2) - 90.0, 1.6)
	WorldKit.place(world, "hk/reindeer", Vector3(-11.0, 0, -6.0), 40.0, 1.4)
	_bear = Node3D.new()
	world.add_child(_bear)
	WorldKit.place(_bear, "pet/polar", Vector3(0, 0, -0.5), 0.0, 1.6)
	WorldKit.box(_bear, Vector3(2.4, 0.7, 0.3), Vector3(0, 0.35, 0.9), Color("#ffb627"), false)
	WorldKit.box(_bear, Vector3(2.5, 0.12, 0.34), Vector3(0, 0.05, 0.95), Color("#5b5f66"), false)
	_bear.position = Vector3(0, 0, -POND_R * 0.6)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, 0.5)
	c.offset = Vector3(0, 14.5, 12.0)
	c.min_dist = 0.9
	c.max_dist = 1.1


func on_start() -> void:
	for av in avatars:
		var pa := av as PartyAvatar
		pa.slippery = 0.75
		pa.rig.surface = "stone"
		if not pa.shoved.is_connected(_on_shoved):
			pa.shoved.connect(_on_shoved)


func _on_shoved(_by: PartyAvatar, victim: PartyAvatar) -> void:
	if state == "play" and not _is_host_model_client():
		_drop(victim.slot, 2)


## Münzen verlieren: sie kullern in alle Richtungen über das Eis
func _drop(slot: int, n: int) -> void:
	var have := int(scores[slot])
	var k := mini(n, have)
	if k <= 0:
		return
	add_score(slot, -float(k))
	var at := (avatars[slot] as PartyAvatar).global_position
	for j in k:
		var a := randf() * TAU
		_add_coin(Vector3(at.x, 0, at.z), 1, Vector3(cos(a), 0, sin(a)) * randf_range(3.5, 5.5))
	Audio.sfx("coin_lose", at)
	(avatars[slot] as PartyAvatar).rig.react("coin_loss")


func on_tick(delta: float) -> void:
	var prog := 1.0 - time_left / time_limit
	_wave_t -= delta
	if _wave_t <= 0.0 and _coins.size() < MAX_COINS - 4:
		_wave_t = lerpf(3.2, 2.2, prog)
		_spawn_pattern()
	# Münzen rutschen nach, prallen an der Bande ab
	for c in _coins:
		var v: Vector3 = c.vel
		if v.length() > 0.05:
			var p: Vector3 = c.pos + v * delta
			var r := Vector2(p.x, p.z).length()
			if r > POND_R - 0.6:
				var nrm := Vector3(p.x, 0, p.z).normalized()
				v = v - 2.0 * v.dot(nrm) * nrm
				p = nrm * (POND_R - 0.6)
			c.pos = p
			c.vel = v.move_toward(Vector3.ZERO, 3.0 * delta)
			(c.node as Node3D).position = Vector3(p.x, 0.45, p.z)
	# Einsammeln
	for i in active_slots():
		var av := avatars[i] as PartyAvatar
		_bear_hit[i] = maxf(0.0, _bear_hit[i] - delta)
		var k := _coins.size() - 1
		while k >= 0:
			var c := _coins[k]
			if (c.vel as Vector3).length() < 2.5 and Vector2(av.global_position.x - (c.pos as Vector3).x, av.global_position.z - (c.pos as Vector3).z).length() < 0.9:
				add_score(i, float(c.val), (c.pos as Vector3) + Vector3.UP)
				Audio.sfx("coin" if int(c.val) == 1 else "coin_chime", c.pos as Vector3)
				FX.sparks((c.pos as Vector3) + Vector3.UP * 0.5, Color(1, 0.85, 0.3), 6 if int(c.val) == 1 else 14)
				(c.node as Node3D).queue_free()
				_coins.remove_at(k)
			k -= 1
	_update_bear(delta, prog)


func _spawn_pattern() -> void:
	var kind := rng.randi() % 3
	var a := rng.randf() * TAU
	var c := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, POND_R - 3.0)
	match kind:
		0:   # Reihe
			var d := Vector3(cos(a + PI / 2.0), 0, sin(a + PI / 2.0))
			for k in 5:
				_add_coin(c + d * (k - 2) * 1.1, 1, Vector3.ZERO)
		1:   # Kreis
			for k in 6:
				var b := TAU * k / 6.0
				_add_coin(c + Vector3(cos(b), 0, sin(b)) * 1.6, 1, Vector3.ZERO)
		2:   # Haufen
			for k in 4:
				_add_coin(c + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8)), 1, Vector3.ZERO)
	if rng.randf() < 0.3:
		var g := rng.randf() * TAU
		_add_coin(Vector3(cos(g), 0, sin(g)) * rng.randf_range(1.0, POND_R - 2.0), 5, Vector3.ZERO)
	Audio.sfx("sparkle_up", c, -8.0)


func _add_coin(p: Vector3, val: int, vel: Vector3) -> void:
	var r := Vector2(p.x, p.z).length()
	if r > POND_R - 0.8:
		p = Vector3(p.x, 0, p.z).normalized() * (POND_R - 0.8)
	var node := WorldKit.cylinder(world, 0.3 if val == 1 else 0.55, 0.09, Vector3(p.x, 0.45, p.z), Color("#ffd23f") if val == 1 else Color("#ffb627"), false)
	(node.get_child(0) as MeshInstance3D).material_override = WorldKit.mat(Color("#ffd23f") if val == 1 else Color("#ffb627"), 0.25, 0.35 if val > 1 else 0.12)
	node.rotation.x = PI / 2.0
	var spin := node.create_tween().set_loops()
	spin.tween_property(node, "rotation:y", TAU, 1.4 if val == 1 else 0.9).as_relative()
	node.scale = Vector3.ONE * 0.1
	node.create_tween().tween_property(node, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	_next_id += 1
	_coins.append({"pos": Vector3(p.x, 0, p.z), "val": val, "node": node, "vel": vel, "id": _next_id})


func _update_bear(delta: float, prog: float) -> void:
	_bear_t += delta * lerpf(0.32, 0.5, prog)
	var target := Vector3(sin(_bear_t * 1.3) * (POND_R - 2.5), 0, sin(_bear_t * 0.9 + 1.0) * (POND_R - 2.5))
	var dir := target - _bear.position
	if dir.length() > 0.01:
		_bear.rotation.y = lerp_angle(_bear.rotation.y, atan2(dir.x, dir.z), 0.12)
	_bear.position = target
	if fmod(_bear_t, 0.5) < delta * 0.5:
		FX.dust(_bear.position + _bear.basis.z * 1.2, Color(1, 1, 1), 3, 0.5)
	for i in active_slots():
		var av := avatars[i] as PartyAvatar
		var off := av.global_position - _bear.position
		off.y = 0.0
		if off.length() < 1.6 and _bear_hit[i] <= 0.0:
			_bear_hit[i] = 1.2
			av.apply_knockback(off.normalized() if off.length() > 0.05 else Vector3.FORWARD, 11.0, 0.6, 4.0)
			Audio.sfx("hit_soft", av.global_position)
			FX.stars(av.global_position + Vector3.UP * 1.5, Color(1, 1, 1), 8)
			_drop(i, 1)


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	d["c"] = _coins.map(func(c: Dictionary) -> Array: return [int(c.id), snappedf((c.pos as Vector3).x, 0.02), snappedf((c.pos as Vector3).z, 0.02), int(c.val)])
	d["b"] = [snappedf(_bear.position.x, 0.02), snappedf(_bear.position.z, 0.02), snappedf(_bear.rotation.y, 0.02)]
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var cs: Array = d.get("c", [])
	var seen := {}
	for e in cs:
		seen[int(e[0])] = e
	var k := _coins.size() - 1
	while k >= 0:
		var c := _coins[k]
		if not seen.has(int(c.id)):
			FX.sparks((c.pos as Vector3) + Vector3.UP * 0.5, Color(1, 0.85, 0.3), 6)
			Audio.sfx("coin", c.pos as Vector3, -4.0)
			(c.node as Node3D).queue_free()
			_coins.remove_at(k)
		else:
			var e: Array = seen[int(c.id)]
			c.pos = Vector3(float(e[1]), 0, float(e[2]))
			(c.node as Node3D).position = Vector3(float(e[1]), 0.45, float(e[2]))
			seen.erase(int(c.id))
		k -= 1
	for id in seen:
		var e2: Array = seen[id]
		_add_coin(Vector3(float(e2[1]), 0, float(e2[2])), int(e2[3]), Vector3.ZERO)
		_coins[-1].id = int(id)
	var b: Array = d.get("b", [])
	if b.size() == 3:
		_bear.position = Vector3(float(b[0]), 0, float(b[1]))
		_bear.rotation.y = float(b[2])


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	var level: int = Game.players[slot].cpu_level
	var p := av.global_position
	var best := Vector3.INF
	var bs := INF
	for c in _coins:
		var cp: Vector3 = c.pos
		var sc := Vector2(cp.x - p.x, cp.z - p.z).length() / (2.5 if int(c.val) > 1 else 1.0)
		if sc < bs:
			bs = sc
			best = cp
	var mv := Vector2.ZERO
	if best != Vector3.INF:
		var to := Vector2(best.x - p.x, best.z - p.z)
		# Auf Eis vorausschauend lenken: eigenes Tempo herausrechnen
		to -= Vector2(av.velocity.x, av.velocity.z) * Game.lv([0.1, 0.25, 0.35], level)
		mv = to.normalized()
	# Dem Eisbären ausweichen
	var off := Vector2(p.x - _bear.position.x, p.z - _bear.position.z)
	if off.length() < 3.2:
		mv = (mv * 0.4 + off.normalized()).normalized()
	var held := {}
	for o in avatars:
		var oa := o as PartyAvatar
		if oa != av and oa.global_position.distance_to(p) < 1.7 and int(scores[oa.slot]) > 0 and randf() < Game.lv([0.02, 0.05, 0.08], level):
			held["b"] = true
			mv = Vector2(oa.global_position.x - p.x, oa.global_position.z - p.z).normalized()
	InputHub.set_virtual(slot, mv, held)
