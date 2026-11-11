extends MinigameBase
## Schnell-Angler (Duell): Zwei Angler am Steg, fünf Runden. Nach einer zufälligen Wartezeit beißt der Fisch –
## großes Platschen, die Pose taucht ab. Wer dann zuerst A drückt, holt den Fisch (+1, Goldfisch +2).
## Vorher zuckt die Pose manchmal nur (Täuschung!) – wer zu früh zieht, ist für diese Runde raus.
## Online: Host-Modell (Host misst die Reaktionen).

const ROUNDS := 5
const X := [-2.2, 2.2]

var _round := 0
var _phase := "wait"          # wait | bite | done
var _t := 0.0
var _bite_at := 0.0
var _fakes: Array[float] = []
var _out: Array[bool] = [false, false]
var _duel: Array[int] = []
var _bobbers: Array[Node3D] = []
var _lines: Array[MeshInstance3D] = []
var _rods: Array[Node3D] = []
var _gold := false
var _excl: Label3D
var _pressed_prev: Array[bool] = [false, false]


func _init() -> void:
	game_id = "quick_fishing"
	env_preset = "sunset"
	backdrop_style = "beach"
	time_limit = 70.0
	score_format = "%d Fische"
	arena_radius = 6.0
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 7)
	net_model = "host"
	spawn_points = [Vector3(X[0], 0.7, 1.0), Vector3(X[1], 0.7, 1.0), Vector3(-5, 0.7, 3), Vector3(5, 0.7, 3)]


func build_arena() -> void:
	WorldKit.water(world, Vector2(80, 80), -0.5, Color(0.1, 0.28, 0.48), Color(0.42, 0.62, 0.78))
	# Langer Holzsteg, Laternen, Boot, Seerosen; Sonnenuntergang über dem See
	WorldKit.box(world, Vector3(7.0, 0.3, 8.0), Vector3(0, 0.55, 3.5), Color("#a4703f"))
	for z in range(0, 8):
		WorldKit.box(world, Vector3(7.1, 0.04, 0.06), Vector3(0, 0.71, z), Color("#7a4f2a"), false)
	for x in [-3.3, 3.3]:
		for z in [0.0, 3.5, 7.0]:
			WorldKit.cylinder(world, 0.15, 2.0, Vector3(x, -0.3, z), Color("#6b4a2b"), false)
	WorldKit.place(world, "town/lantern", Vector3(-3.2, 0.7, 0.2), 0.0, 1.0)
	WorldKit.place(world, "town/lantern", Vector3(3.2, 0.7, 0.2), 0.0, 1.0)
	WorldKit.place(world, "water/boat_fishing", Vector3(-8, -0.5, -5), 40.0, 1.6)
	WorldKit.scatter(world, ["qn/lilypad", "mt/cattail", "mt/cattail_b"], 18, Vector3(0, 0, -6), 4.0, 12.0, -0.45)
	for k in 2:
		var bob := Node3D.new()
		world.add_child(bob)
		bob.position = Vector3(X[k] * 1.3, -0.45, -4.5)
		WorldKit.cylinder(bob, 0.18, 0.18, Vector3(0, 0.0, 0), Color("#ff4d4d"), false)
		WorldKit.cylinder(bob, 0.18, 0.18, Vector3(0, 0.18, 0), Color("#ffffff"), false)
		WorldKit.cylinder(bob, 0.03, 0.3, Vector3(0, 0.38, 0), Color("#333344"), false)
		_bobbers.append(bob)
		var rod := Node3D.new()
		world.add_child(rod)
		rod.position = Vector3(X[k] + 0.35, 1.5, 0.6)
		var stick := WorldKit.cylinder(rod, 0.04, 3.2, Vector3(0, 1.6, 0), Color("#7a4f2a"), false)
		stick.rotation.x = 0.0
		rod.rotation.x = -0.9
		_rods.append(rod)
		var line := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.01
		cm.bottom_radius = 0.01
		cm.height = 1.0
		cm.material = WorldKit.mat(Color(1, 1, 1, 0.8), 0.5)
		line.mesh = cm
		world.add_child(line)
		_lines.append(line)
	_excl = Label3D.new()
	_excl.font_size = 260
	_excl.outline_size = 40
	_excl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_excl.modulate = Color("#ffd23f")
	_excl.position = Vector3(0, 3.0, -3.5)
	_excl.text = ""
	world.add_child(_excl)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0.8, -1.0)
	c.offset = Vector3(0, 6.5, 9.0)
	c.min_dist = 1.0
	c.max_dist = 1.0


func on_start() -> void:
	_duel = active_slots()
	for k in _duel.size():
		var av := avatars[_duel[k]] as PartyAvatar
		av.can_move = false
		av.can_jump = false
		av.can_shove = false
		av.global_position = Vector3(X[mini(k, 1)], 0.7, 1.0)
		av.rig.face_now(Vector3.FORWARD)
		av.rig.play("fish", 0.1)
	_new_round()


func check_end() -> bool:
	return _round >= ROUNDS


func _new_round() -> void:
	_phase = "wait"
	_t = 0.0
	_bite_at = rng.randf_range(2.0, 5.5)
	_fakes.clear()
	for k in rng.randi_range(0, 2):
		_fakes.append(rng.randf_range(0.8, _bite_at - 0.4))
	_out = [false, false]
	_gold = rng.randf() < 0.2
	_excl.text = ""
	CutsceneManager.big_word("Runde %d" % (_round + 1), Color("#ffffff"), 0.5)


func on_tick(delta: float) -> void:
	_t += delta
	match _phase:
		"wait":
			for f in _fakes:
				if absf(_t - f) < delta:
					for b in _bobbers:
						b.create_tween().tween_property(b, "position:y", -0.6, 0.08).set_trans(Tween.TRANS_SINE)
						b.create_tween().tween_interval(0.08)
					Audio.sfx("plop", Vector3(0, 0, -4.5), -10.0, 1.4)
			for k in _bobbers.size():
				_bobbers[k].position.y = lerpf(_bobbers[k].position.y, -0.45 + sin(_t * 2.0 + k) * 0.03, 0.2)
			if _t >= _bite_at:
				_phase = "bite"
				_t = 0.0
				_excl.text = "!"
				Audio.sfx("splash", Vector3(0, 0, -4.5))
				Audio.sfx("alert", null, -2.0)
				for b in _bobbers:
					FX.splash(b.position + Vector3.UP * 0.2, 0.8)
					b.position.y = -0.85
			else:
				_check_presses(true)
		"bite":
			_check_presses(false)
			if _t > 2.5:
				_end_round(-1)
		"done":
			if _t > 2.2:
				_round += 1
				if _round < ROUNDS:
					_new_round()
	_draw_lines()


func _check_presses(early: bool) -> void:
	# Beide im selben Frame? Dann entscheidet das Los (sonst hätte Slot 1 immer Vorrang)
	var order: Array = range(_duel.size())
	if rng.randf() < 0.5:
		order.reverse()
	for k in order:
		var s := _duel[k]
		var now := InputHub.held(s, "a")
		var edge := now and not _pressed_prev[k]
		_pressed_prev[k] = now
		if not edge or _out[k]:
			continue
		if early:
			_out[k] = true
			Juice.float_text(self, (avatars[s] as PartyAvatar).global_position + Vector3.UP * 2.2, "Zu früh!", Color("#ff8a5c"), 70)
			(avatars[s] as PartyAvatar).rig.react("frustrated")
			Audio.sfx("negative", null, -4.0)
			if not (false in _out):
				_end_round(-1)
		else:
			_end_round(k)
			return


func _end_round(winner: int) -> void:
	_phase = "done"
	_t = 0.0
	_excl.text = ""
	if winner < 0:
		Juice.float_text(self, Vector3(0, 2.4, -3.0), "Entwischt!", Color("#c9d6e8"), 70)
		return
	var s := _duel[winner]
	var av := avatars[s] as PartyAvatar
	add_score(s, 2.0 if _gold else 1.0, av.global_position + Vector3.UP * 2.5)
	av.rig.react("victory" if _gold else "cheer")
	# Fisch fliegt aus dem Wasser auf den Steg
	var fish := Assets.spawn("surv/fish", world, _bobbers[winner].position, 0.0, 1.6 if _gold else 1.2)
	if _gold:
		Assets.tint(fish, Color("#ffd23f"), false, 0.4)
	var tw := fish.create_tween()
	tw.tween_property(fish, "position", av.global_position + Vector3(0, 1.2, 0.3), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(fish, "rotation:z", TAU * 2.0, 0.6)
	tw.tween_interval(1.0)
	tw.tween_callback(fish.queue_free)
	FX.splash(_bobbers[winner].position + Vector3.UP * 0.2, 1.0)
	Audio.sfx("coin_chime" if _gold else "coin", av.global_position)
	var rod := _rods[winner]
	var rt := rod.create_tween()
	rt.tween_property(rod, "rotation:x", -0.2, 0.12)
	rt.tween_property(rod, "rotation:x", -0.9, 0.5).set_delay(0.4)


func _draw_lines() -> void:
	for k in _lines.size():
		var tip := _rods[k].global_transform * Vector3(0, 3.2, 0)
		var end := _bobbers[k].global_position + Vector3.UP * 0.5
		var mid := (tip + end) * 0.5
		var l := _lines[k]
		l.global_position = mid
		(l.mesh as CylinderMesh).height = tip.distance_to(end)
		var dir := (tip - end).normalized()
		l.global_basis = Basis(Quaternion(Vector3.UP, dir))


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	d["f"] = [_round, ["wait", "bite", "done"].find(_phase), 1 if _out[0] else 0, 1 if _out[1] else 0]
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var f: Array = d.get("f", [])
	if f.size() < 4:
		return
	var ph: String = ["wait", "bite", "done"][int(f[1])]
	if ph != _phase:
		if ph == "bite":
			_excl.text = "!"
			Audio.sfx("splash", Vector3(0, 0, -4.5))
			for b in _bobbers:
				FX.splash(b.position + Vector3.UP * 0.2, 0.8)
				b.position.y = -0.85
		elif ph == "done":
			_excl.text = ""
		elif ph == "wait":
			for b in _bobbers:
				b.position.y = -0.45
	_phase = ph
	_round = int(f[0])
	_draw_lines()


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var level: int = Game.players[slot].cpu_level
	var mem: Dictionary = cpu_mem[slot]
	var held := {}
	var k := _duel.find(slot)
	if k < 0:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	if _phase == "bite":
		if not mem.has("react"):
			mem["react"] = [0.42, 0.3, 0.21][level] + randf_range(-0.04, 0.08)
		if _t >= float(mem.react):
			held["a"] = true
	else:
		mem.erase("react")
		# Täuschung: Anfänger fallen öfter darauf herein
		for f in _fakes:
			if _phase == "wait" and _t > f + 0.15 and _t < f + 0.2 and randf() < [0.35, 0.12, 0.03][level]:
				held["a"] = true
	InputHub.set_virtual(slot, Vector2.ZERO, held)
