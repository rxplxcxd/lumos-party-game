extends MinigameBase
## Glücks-Glöckchen: Jeder hat seinen eigenen fröhlichen Glücksautomaten mit Kirschen, Glocken, Kleeblättern,
## Sternen und Kronen. Mit A stoppt man die drei Walzen nacheinander – drei Gleiche läuten den Gewinn ein!
## Drei Drehungen, die Münzen zählen. Online: jeder dreht auf seinem Gerät, die Ergebnisse werden geteilt.

const SYMBOLS := ["cherry", "bell", "clover", "star", "crown"]
const SYM_COL := [Color("#ff5a6e"), Color("#ffcf3f"), Color("#5fd16a"), Color("#ffe066"), Color("#c38bff")]
const PAY3 := [6, 8, 10, 12, 15]
const SPINS := 3

var machines: Array[Dictionary] = []
var _spun: Array[int] = [0, 0, 0, 0]


func _init() -> void:
	game_id = "lucky_bells"
	env_preset = "day"
	time_limit = 35.0
	arena_radius = 8.0
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 10)
	touch_profile = "action_only"
	score_format = "%d Münzen"
	spawn_points = [Vector3(-6, 0.6, 2.5), Vector3(-2, 0.6, 2.5), Vector3(2, 0.6, 2.5), Vector3(6, 0.6, 2.5)]


func build_arena() -> void:
	WorldKit.box(world, Vector3(20, 1, 12), Vector3(0, -0.5, -1), Color("#f6d8a8"))
	WorldKit.box(world, Vector3(20, 6, 0.6), Vector3(0, 3, -4.6), Color("#ffb3c7"), false)
	for k in 9:
		var lamp := WorldKit.cylinder(world, 0.22, 0.22, Vector3(-8 + k * 2.0, 5.9, -4.2), Color("#fff3a0"), false)
		lamp.name = "Lamp%d" % k
		WorldKit.torch_light(world, Vector3(-8 + k * 2.0, 5.6, -3.6), Color(1.0, 0.9, 0.6), 0.6, 3.0)
	for i in 4:
		var x: float = spawn_points[i].x
		var m := Node3D.new()
		world.add_child(m)
		m.position = Vector3(x, 0, -1.6)
		WorldKit.box(m, Vector3(3.2, 3.6, 1.4), Vector3(0, 1.8, 0), Game.player_color(i).lerp(Color.WHITE, 0.45), false)
		WorldKit.box(m, Vector3(2.7, 1.1, 0.1), Vector3(0, 2.4, 0.72), Color("#fffaf0"), false)
		var dome := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.6
		sm.height = 1.6
		sm.material = WorldKit.mat(Game.player_color(i).lerp(Color.WHITE, 0.25), 0.5)
		dome.mesh = sm
		dome.position = Vector3(0, 3.6, 0)
		m.add_child(dome)
		var bell := Assets.spawn("hol/bell", m, Vector3(0, 4.6, 0), 0.0, 1.2)
		var lever := WorldKit.cylinder(m, 0.08, 1.2, Vector3(1.8, 2.4, 0.2), Color("#c0c0c8"), false)
		var knob := MeshInstance3D.new()
		var ks := SphereMesh.new()
		ks.radius = 0.22
		ks.height = 0.44
		ks.material = WorldKit.mat(Color("#ff5a6e"), 0.3, 0.3)
		knob.mesh = ks
		knob.position = Vector3(0, 0.6, 0)
		lever.add_child(knob)
		var reels: Array = []
		for r in 3:
			var spr := Sprite3D.new()
			spr.pixel_size = 0.0075
			spr.position = Vector3(-0.85 + r * 0.85, 2.4, 0.8)
			m.add_child(spr)
			reels.append(spr)
		var tray := Label3D.new()
		tray.font = UI.title_font()
		tray.font_size = 72
		tray.outline_size = 16
		tray.position = Vector3(0, 0.9, 0.8)
		tray.text = ""
		m.add_child(tray)
		machines.append({"node": m, "reels": reels, "stop": [-1, -1, -1], "phase": 0.0, "spinning": false, "stopped": 0,
			"bell": bell, "lever": lever, "tray": tray, "res": [], "speed": [0.0, 0.0, 0.0]})
	for i in 8:
		WorldKit.place(world, ["plat/flowers", "hol/present_red", "plat/mushrooms", "hol/present_green"][i % 4], Vector3(-9 + i * 2.6, 0, 3.8), randf() * 360.0, 1.4)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 2.0, -1)
	c.offset = Vector3(0, 4.5, 11.5)
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
		av.rig.face_now(Vector3(0, 0, -1))
		if active[i] and Net.owns_slot(i):
			_start_spin(i)


func _start_spin(i: int) -> void:
	var m: Dictionary = machines[i]
	m.spinning = true
	m.stopped = 0
	m.stop = [-1, -1, -1]
	m.speed = [18.0, 21.0, 24.0]
	(m.tray as Label3D).text = ""
	var lever: Node3D = m.lever
	var tw := lever.create_tween()
	tw.tween_property(lever, "rotation:x", 0.9, 0.12)
	tw.tween_property(lever, "rotation:x", 0.0, 0.3).set_trans(Tween.TRANS_BACK)
	Audio.sfx("wheel_tick", (m.node as Node3D).global_position, -8.0, 1.4)


func on_tick(delta: float) -> void:
	for i in active_slots():
		var m: Dictionary = machines[i]
		var reels: Array = m.reels
		var stop: Array = m.stop
		if m.spinning:
			m.phase = float(m.phase) + delta
			for r in 3:
				if int(stop[r]) < 0:
					var sym := int(float(m.phase) * float(m.speed[r]) + r * 2) % SYMBOLS.size()
					(reels[r] as Sprite3D).texture = UI.icon_tex(SYMBOLS[sym], 96, SYM_COL[sym])
					(reels[r] as Sprite3D).offset.y = sin(float(m.phase) * 40.0 + r) * 6.0
			if Net.owns_slot(i) and InputHub.pressed(i, "a"):
				_stop_reel(i)
		(m.bell as Node3D).rotation.z = lerpf((m.bell as Node3D).rotation.z, 0.0, delta * 6.0)


## Walze anhalten. Leichte Glücksfee: die dritte Walze rutscht manchmal noch auf ein passendes Symbol.
func _stop_reel(i: int) -> void:
	var m: Dictionary = machines[i]
	var stop: Array = m.stop
	var r := int(m.stopped)
	var sym := int(float(m.phase) * float(m.speed[r]) + r * 2) % SYMBOLS.size()
	if r == 2 and int(stop[0]) == int(stop[1]) and randf() < 0.3:
		sym = int(stop[0])
	stop[r] = sym
	m.stopped = r + 1
	var spr: Sprite3D = m.reels[r]
	spr.texture = UI.icon_tex(SYMBOLS[sym], 96, SYM_COL[sym])
	spr.offset.y = 0.0
	Juice.squash(spr, 1.3, 0.75, 0.2, Vector3.ONE)
	Audio.sfx("click", (m.node as Node3D).global_position, -2.0, 1.0 + r * 0.15)
	if int(m.stopped) >= 3:
		m.spinning = false
		_payout(i)


func _payout(i: int) -> void:
	var m: Dictionary = machines[i]
	var st: Array = m.stop
	var win := 1
	if int(st[0]) == int(st[1]) and int(st[1]) == int(st[2]):
		win = PAY3[int(st[0])]
	elif int(st[0]) == int(st[1]) or int(st[1]) == int(st[2]) or int(st[0]) == int(st[2]):
		win = 3
	scores[i] += win
	_spun[i] += 1
	_show_win(i, win)
	report_score(i)
	if _spun[i] < SPINS:
		get_tree().create_timer(1.3, false).timeout.connect(func() -> void:
			if state == "play":
				_start_spin(i))


func _show_win(i: int, win: int) -> void:
	var m: Dictionary = machines[i]
	var av := avatars[i] as PartyAvatar
	(m.tray as Label3D).text = "+%d" % win
	(m.tray as Label3D).modulate = Color("#7dff9a") if win >= 6 else Color.WHITE
	var bell: Node3D = m.bell
	bell.rotation.z = 0.6
	if win >= 6:
		Audio.sfx("bell", bell.global_position, 0.0, 1.2)
		Audio.sfx("coin", bell.global_position, -2.0)
		FX.coins_burst(bell.global_position, mini(win, 12), true, world)
		FX.confetti(bell.global_position, 30)
		av.rig.react("triumph" if win >= 12 else "cheer")
	elif win == 3:
		Audio.sfx("coin_single", bell.global_position, -2.0)
		av.rig.react("coin_gain")
	else:
		Audio.sfx("pluck", bell.global_position, -6.0, 0.8)


func score_extra(slot: int) -> Dictionary:
	return {"st": machines[slot].stop, "n": _spun[slot]}


func on_remote_score(slot: int, extra: Dictionary) -> void:
	var st: Array = extra.get("st", [])
	if st.size() == 3:
		var m: Dictionary = machines[slot]
		for r in 3:
			var sym := int(st[r])
			if sym >= 0:
				(m.reels[r] as Sprite3D).texture = UI.icon_tex(SYMBOLS[sym], 96, SYM_COL[sym])
		_spun[slot] = int(extra.get("n", _spun[slot]))
		_show_win(slot, 0 if st.has(-1) else 1)


func check_end() -> bool:
	for i in active_slots():
		if _spun[i] < SPINS:
			return false
	return true


func cpu_think(slot: int, delta: float) -> void:
	var m: Dictionary = machines[slot]
	var held := {}
	var mem := cpu_mem[slot]
	if m.spinning:
		var t := float(mem.get("t", randf_range(0.4, 0.9))) - delta
		if t <= 0.0:
			held["a"] = true
			t = randf_range(0.35, 0.8)
		mem["t"] = t
	InputHub.set_virtual(slot, Vector2.ZERO, held)
