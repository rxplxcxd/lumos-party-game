extends MinigameBase
## Honigbären-Flucht (1 gegen 3): Das Solo flitzt im Honigwägelchen um den großen Honigbaum, springt (A)
## über Baumstämme und legt klebrige Honigfallen (B, 3 Stück). Das Trio reitet die flauschige Riesenbiene:
## A im Takt hämmern = schneller, Stick links/rechts (Mehrheit) = Spur wechseln. Erwischt die Biene den Wagen,
## gewinnt das Trio – hält das Solo 30 Sekunden durch, gewinnt es. Online: Host-Modell.

const LANES := [7.4, 9.0, 10.6]
const R := 9.0

var cart_a := 0.0
var cart_lane := 1.0
var cart_lane_t := 1
var bee_a := -0.55
var bee_lane := 1.0
var bee_lane_t := 1
var cart_air := 0.0
var cart_stun := 0.0
var bee_stuck := 0.0
var traps_left := 3
var _trap_cd := 0.0
var logs: Array[Dictionary] = []
var traps: Array[Dictionary] = []
var _log_t := 1.2
var _cart: Node3D
var _bee: Node3D
var _bee_rig: CharacterRig
var _done := false
var _mash: Array[float] = [0, 0, 0, 0]
var _lane_cd := 0.0
var _seq := 0


func _init() -> void:
	game_id = "honey_chase"
	env_preset = "day"
	time_limit = 30.0
	arena_radius = 12.0
	teaser_height = 1.2
	cannon_pos = Vector3(0, 0, 15)
	net_model = "host"


func build_arena() -> void:
	WorldKit.cylinder(world, 14.0, 1.0, Vector3(0, -0.5, 0), Color("#8fd16a"))
	var track := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = LANES[0] - 0.9
	tm.outer_radius = LANES[2] + 0.9
	tm.rings = 64
	tm.ring_segments = 8
	tm.material = WorldKit.mat(Color("#c9a06a"), 0.95)
	track.mesh = tm
	track.scale = Vector3(1, 0.02, 1)
	track.position.y = 0.02
	world.add_child(track)
	for l in [LANES[0] + 0.8, LANES[1] + 0.8]:
		var line := MeshInstance3D.new()
		var t2 := TorusMesh.new()
		t2.inner_radius = l - 0.04
		t2.outer_radius = l + 0.04
		t2.rings = 64
		t2.material = WorldKit.mat(Color("#fff3d6"), 0.8)
		line.mesh = t2
		line.scale = Vector3(1, 0.02, 1)
		line.position.y = 0.04
		world.add_child(line)
	# Honigbaum in der Mitte
	WorldKit.place(world, "nat/tree_fat", Vector3.ZERO, 0.0, 5.0)
	for k in 6:
		var a := TAU * k / 6.0
		var pot := WorldKit.cylinder(world, 0.45, 0.6, Vector3(cos(a) * 3.2, 0.3, sin(a) * 3.2), Color("#ffb52e"), false)
		pot.name = "Pot%d" % k
	for i in 16:
		var a2 := TAU * i / 16.0
		WorldKit.place(world, ["plat/flowers", "nat/bush", "plat/mushrooms", "nat/flower_yellow"][i % 4], Vector3(cos(a2), 0, sin(a2)) * 12.6, randf() * 360.0, 1.8)
	_cart = Node3D.new()
	world.add_child(_cart)
	var cart_m := Assets.spawn("town/cart", _cart, Vector3.ZERO, 90.0, 1.1)
	cart_m.name = "CartModel"
	_bee = Node3D.new()
	world.add_child(_bee)
	_bee_rig = CharacterRig.new()
	_bee.add_child(_bee_rig)
	_bee_rig.setup("pet/bee", -1, 3.2)
	_bee_rig.position.y = 1.2
	_bee_rig.play("run")


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, 1)
	c.offset = Vector3(0, 18, 14)
	c.min_dist = 1.0
	c.max_dist = 1.0
	c.follow = false


func on_start() -> void:
	for i in 4:
		var av := avatars[i] as PartyAvatar
		av.can_move = false
		av.can_jump = false
		av.can_shove = false
		av.set_physics_process(false)
		av.rig.play("sit_chair")
	_place_riders()


func _pos(a: float, lane: float) -> Vector3:
	var r := lerpf(LANES[0], LANES[2], lane / 2.0)
	return Vector3(cos(a) * r, 0, sin(a) * r)


func _place_riders() -> void:
	var k := 0
	for i in active_slots():
		var av := avatars[i] as PartyAvatar
		if i == solo_slot:
			av.global_position = _cart.global_position + Vector3.UP * (0.6 + cart_air * 2.0)
			av.rig.rotation.y = _cart.rotation.y
		else:
			var off := Vector3(-0.7 + k * 0.7, 2.0, 0.2)
			av.global_position = _bee.global_position + _bee.global_basis * off
			av.rig.rotation.y = _bee.rotation.y
			k += 1


func on_tick(delta: float) -> void:
	if _done:
		return
	var prog := 1.0 - time_left / time_limit
	# Solo: Spur, Sprung, Honigfalle
	var smv := InputHub.move(solo_slot)
	_lane_cd -= delta
	if absf(smv.x) > 0.6 and _lane_cd <= 0.0:
		cart_lane_t = clampi(cart_lane_t + (1 if smv.x > 0 else -1), 0, 2)
		_lane_cd = 0.22
	if InputHub.pressed(solo_slot, "a") and cart_air <= 0.0:
		cart_air = 0.6
		Audio.sfx("jump", _cart.global_position, -4.0)
	_trap_cd -= delta
	if InputHub.pressed(solo_slot, "b") and traps_left > 0 and _trap_cd <= 0.0:
		traps_left -= 1
		_trap_cd = 1.2
		_drop_trap()
	cart_lane = move_toward(cart_lane, cart_lane_t, delta * 6.0)
	cart_air = maxf(0.0, cart_air - delta)
	cart_stun = maxf(0.0, cart_stun - delta)
	var cart_v := (6.6 + prog * 2.4) * (0.35 if cart_stun > 0.0 else 1.0)
	cart_a += cart_v / R * delta
	# Trio: Tempo durch Hämmern, Spur per Mehrheit
	var bonus := 0.0
	var steer := 0.0
	for i in active_slots():
		if i == solo_slot:
			continue
		_mash[i] = maxf(0.0, _mash[i] - delta * 1.4)
		if InputHub.pressed(i, "a"):
			_mash[i] = minf(_mash[i] + 0.38, 2.0)
		bonus += _mash[i]
		steer += InputHub.move(i).x
	if absf(steer) > 0.9 and _lane_cd <= -0.1:
		bee_lane_t = clampi(bee_lane_t + (1 if steer > 0 else -1), 0, 2)
		_lane_cd = 0.25
	bee_lane = move_toward(bee_lane, bee_lane_t, delta * 4.0)
	bee_stuck = maxf(0.0, bee_stuck - delta)
	var bee_v := (5.2 + bonus * 0.95 + prog * 1.6) * (0.0 if bee_stuck > 0.0 else 1.0)
	bee_a += bee_v / R * delta
	_update_logs(delta, prog)
	_update_traps()
	_apply_visuals(delta)
	var gap := wrapf(cart_a - bee_a, -PI, PI)
	if gap < 0.075 and absf(cart_lane - bee_lane) < 0.6:
		_finish(1)


func _update_logs(delta: float, prog: float) -> void:
	_log_t -= delta
	if _log_t <= 0.0:
		_log_t = lerpf(1.6, 0.9, prog)
		_seq += 1
		var lane := (_seq * 7 + int(time_left * 10.0)) % 3
		var a := cart_a + 1.2
		var n := Assets.spawn("nat/log", world, _pos(a, lane), 0.0, 1.6)
		n.look_at(n.global_position + Vector3(-sin(a), 0, cos(a)), Vector3.UP)
		Juice.pop_in(n, 0.25)
		logs.append({"node": n, "a": a, "lane": lane})
	for lg in logs.duplicate():
		var da := wrapf(float(lg.a) - cart_a, -PI, PI)
		if absf(da) < 0.05 and absf(cart_lane - float(lg.lane)) < 0.5 and cart_air <= 0.0 and cart_stun <= 0.0:
			cart_stun = 0.7
			Audio.sfx("wood_hit", _cart.global_position)
			FX.dust(_cart.global_position, Color(0.7, 0.55, 0.4), 12, 1.0)
			(avatars[solo_slot] as PartyAvatar).rig.react("hit")
		if da < -0.6:
			(lg.node as Node3D).queue_free()
			logs.erase(lg)


func _drop_trap() -> void:
	var a := cart_a - 0.06
	var lane := int(round(cart_lane))
	var puddle := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.9
	cm.bottom_radius = 1.0
	cm.height = 0.08
	cm.material = WorldKit.mat(Color("#ffb52e"), 0.15, 0.3)
	puddle.mesh = cm
	world.add_child(puddle)
	puddle.position = _pos(a, lane) + Vector3.UP * 0.05
	Juice.pop_in(puddle, 0.3)
	Audio.sfx("slime", puddle.position)
	traps.append({"node": puddle, "a": a, "lane": lane})


func _update_traps() -> void:
	for tr in traps.duplicate():
		var da := wrapf(float(tr.a) - bee_a, -PI, PI)
		if absf(da) < 0.06 and absf(bee_lane - float(tr.lane)) < 0.6:
			bee_stuck = 1.3
			_bee_rig.react("dizzy")
			FX.dust((tr.node as Node3D).position, Color("#ffcf6a"), 18, 1.2)
			Audio.sfx("slime", (tr.node as Node3D).position, 2.0, 0.7)
			(tr.node as Node3D).queue_free()
			traps.erase(tr)


func _apply_visuals(_delta: float) -> void:
	var cp := _pos(cart_a, cart_lane)
	_cart.position = cp + Vector3.UP * (sin(cart_air / 0.6 * PI) * 1.4 if cart_air > 0.0 else 0.0)
	_cart.rotation.y = -cart_a
	var bp := _pos(bee_a, bee_lane)
	_bee.position = bp + Vector3.UP * (0.6 + sin(Time.get_ticks_msec() / 120.0) * 0.15)
	_bee.rotation.y = -bee_a + PI
	_place_riders()


func _finish(winner_team: int) -> void:
	_done = true
	for i in 4:
		scores[i] = 1.0 if teams[i] == winner_team else 0.0
	if winner_team == 1:
		Audio.sfx("punch", _cart.global_position)
		FX.stars(_cart.global_position + Vector3.UP * 2.0, Color(1, 0.9, 0.4), 18)
		(avatars[solo_slot] as PartyAvatar).rig.react("launch")
		Juice.shake(0.4)
	await get_tree().create_timer(0.8, false).timeout
	end_game()


func team_result() -> int:
	return 1 if _done and scores[(solo_slot + 1) % 4] > 0.0 else 0


func on_timeout() -> void:
	if not _done:
		_done = true
		for i in 4:
			scores[i] = 1.0 if i == solo_slot else 0.0
		(avatars[solo_slot] as PartyAvatar).rig.react("victory")
		end_game()


func net_pack() -> Dictionary:
	var lg: Array = []
	for l in logs:
		lg.append([snappedf(float(l.a), 0.001), int(l.lane)])
	var tr: Array = []
	for t in traps:
		tr.append([snappedf(float(t.a), 0.001), int(t.lane)])
	return {"ca": snappedf(cart_a, 0.001), "cl": snappedf(cart_lane, 0.01), "air": snappedf(cart_air, 0.01),
		"ba": snappedf(bee_a, 0.001), "bl": snappedf(bee_lane, 0.01), "lg": lg, "tr": tr}


func net_unpack(d: Dictionary) -> void:
	cart_a = float(d.get("ca", cart_a))
	cart_lane = float(d.get("cl", cart_lane))
	cart_air = float(d.get("air", 0.0))
	bee_a = float(d.get("ba", bee_a))
	bee_lane = float(d.get("bl", bee_lane))
	_sync_list(logs, d.get("lg", []), "nat/log")
	_sync_list(traps, d.get("tr", []), "")
	_apply_visuals(0.05)


func _sync_list(list: Array[Dictionary], src: Array, key: String) -> void:
	while list.size() > src.size():
		(list[0].node as Node3D).queue_free()
		list.remove_at(0)
	while list.size() < src.size():
		var n: Node3D
		if key != "":
			n = Assets.spawn(key, world, Vector3.ZERO, 0.0, 1.6)
		else:
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.9
			cm.bottom_radius = 1.0
			cm.height = 0.08
			cm.material = WorldKit.mat(Color("#ffb52e"), 0.15, 0.3)
			mi.mesh = cm
			world.add_child(mi)
			n = mi
		list.append({"node": n, "a": 0.0, "lane": 0})
	for k in src.size():
		var e: Array = src[k]
		list[k].a = float(e[0])
		list[k].lane = int(e[1])
		(list[k].node as Node3D).position = _pos(float(e[0]), float(e[1])) + Vector3.UP * 0.05


func cpu_think(slot: int, _delta: float) -> void:
	var level: int = Game.players[slot].cpu_level
	var held := {}
	var mv := Vector2.ZERO
	if slot == solo_slot:
		for lg in logs:
			var da := wrapf(float(lg.a) - cart_a, -PI, PI)
			if da > 0.0 and da < [0.12, 0.16, 0.2][level] and absf(cart_lane - float(lg.lane)) < 0.5:
				if randf() < [0.4, 0.6, 0.85][level]:
					held["a"] = true
				else:
					mv.x = 1.0 if cart_lane_t < 2 else -1.0
		var gap := wrapf(cart_a - bee_a, -PI, PI)
		if gap < 0.35 and absf(cart_lane - bee_lane) < 0.6:
			if randf() < 0.05 * (level + 1):
				held["b"] = true
			elif randf() < 0.04:
				mv.x = 1.0 if randf() < 0.5 else -1.0
	else:
		var mem := cpu_mem[slot]
		var t := float(mem.get("t", 0.0)) - get_physics_process_delta_time()
		if t <= 0.0:
			held["a"] = true
			t = 1.0 / [4.5, 6.0, 8.0][level]
		mem["t"] = t
		var want := cart_lane - bee_lane
		if absf(want) > 0.4:
			mv.x = signf(want)
	InputHub.set_virtual(slot, mv, held)
