extends MinigameBase
## Schlitten an der Kante: Drei Runden. A schnell tippen = Anschieben, dann rauscht der Schlitten die Rampe
## hinunter aufs Eisplateau. B halten = Bremsen. Wer am nächsten an der Klippe zum Stehen kommt, holt die
## meisten Punkte (bis 100 pro Runde) – wer drüber rutscht, plumpst in den Schneehaufen und bekommt nichts.
## Jede Runde liegt ein Glatteis-Fleck woanders: dort greift die Bremse kaum.
## Online: Besitzer-Modell (jeder fährt seinen Schlitten; Runden laufen nach fester Uhr, Flecken aus dem Zufall).

const LANES := [-4.5, -1.5, 1.5, 4.5]
const START_Z := 9.0
const RAMP_END := 4.0
const EDGE_Z := -12.0
const RAMP_H := 2.6
const T_READY := 1.0
const T_PUSH := 1.5
const T_SLIDE := 5.0
const T_SHOW := 2.0
const RL := T_READY + T_PUSH + T_SLIDE + T_SHOW
const ROUNDS := 3

var _round := -1
var _phase := ""
var _sled: Array[Dictionary] = []    # je Spieler: z, v, state ("wait","go","stop","fell"), sled node
var _patch_z := 0.0
var _patch: MeshInstance3D
var _spray_t := 0.0


func _init() -> void:
	game_id = "sled_edge"
	env_preset = "snow"
	backdrop_style = "sky_day"
	time_limit = RL * ROUNDS + 0.3
	score_format = "%d Pkt."
	arena_radius = 10.0
	teaser_height = 1.0
	cannon_pos = Vector3(9, 0, 6)
	spawn_points = [Vector3(LANES[0], RAMP_H + 0.6, START_Z), Vector3(LANES[1], RAMP_H + 0.6, START_Z), Vector3(LANES[2], RAMP_H + 0.6, START_Z), Vector3(LANES[3], RAMP_H + 0.6, START_Z)]


func _height(z: float) -> float:
	if z >= RAMP_END:
		return RAMP_H * clampf((z - RAMP_END) / (START_Z - RAMP_END), 0.0, 1.0)
	return 0.0


func build_arena() -> void:
	# Startpodest, Rampe, Eisplateau mit Zielzonen, Klippe und Schneehaufen unten
	WorldKit.box(world, Vector3(14, RAMP_H, 3.0), Vector3(0, RAMP_H * 0.5 - 0.02, START_Z + 1.4), Color("#eef6ff"))
	var ramp_len := Vector2(START_Z - RAMP_END, RAMP_H).length()
	var ramp := WorldKit.box(world, Vector3(14, 0.4, ramp_len), Vector3(0, RAMP_H * 0.5 - 0.2, (START_Z + RAMP_END) * 0.5), Color("#f4faff"))
	ramp.rotation.x = -atan2(RAMP_H, START_Z - RAMP_END)
	WorldKit.box(world, Vector3(14, 3.0, RAMP_END - EDGE_Z), Vector3(0, -1.5, (RAMP_END + EDGE_Z) * 0.5), Color("#cfe9ff"))
	# Zielzonen kurz vor der Kante (grün, gelb, rot) und Spurlinien
	for k in 3:
		var zc := EDGE_Z + 0.5 + k * 1.0
		WorldKit.box(world, Vector3(13.6, 0.02, 1.0), Vector3(0, 0.01, zc + 0.5), [Color("#ff6b6b"), Color("#ffd166"), Color("#7ddc6a")][k], false)
	for x in [-3.0, 0.0, 3.0]:
		WorldKit.box(world, Vector3(0.08, 0.02, RAMP_END - EDGE_Z), Vector3(x, 0.012, (RAMP_END + EDGE_Z) * 0.5), Color("#9cc9ee"), false)
	for i in 5:
		WorldKit.place(world, "plat/flag", Vector3(-6.6 + i * 3.3, 0, EDGE_Z + 0.4), 0.0, 0.9)
	WorldKit.box(world, Vector3(30, 1.0, 16), Vector3(0, -6.0, EDGE_Z - 8.0), Color("#ffffff"))
	for i in 6:
		WorldKit.cylinder(world, randf_range(1.5, 2.6), 1.2, Vector3(-7.5 + i * 3.0, -5.3, EDGE_Z - 3.0), Color("#f8fbff"), false).scale.y = 0.6
	for i in 4:
		WorldKit.place(world, "hk/snow_pile", Vector3(-6.0 + i * 4.0, -5.5, EDGE_Z - 5.0), randf() * 360.0, 1.8)
	WorldKit.place(world, "hk/snowman", Vector3(-7.6, 0, EDGE_Z + 1.5), 20.0, 1.6)
	WorldKit.place(world, "hk/snowman", Vector3(7.6, 0, EDGE_Z + 1.5), -20.0, 1.6)
	WorldKit.place(world, "hk/sled", Vector3(7.8, RAMP_H, START_Z + 1.5), 60.0, 1.4)
	for side in [-1.0, 1.0]:
		WorldKit.box(world, Vector3(6, 4, 30), Vector3(side * 10.0, -1.0, -2.0), Color("#e3f1ff"), false)
		for i in 6:
			WorldKit.place(world, "nat/pine_snow", Vector3(side * randf_range(8.0, 12.0), 1.0, -12.0 + i * 4.5), randf() * 360.0, randf_range(1.6, 2.4))
	_patch = MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(13.6, 0.03, 2.6)
	var m := WorldKit.mat(Color(0.65, 0.9, 1.0, 0.85), 0.05, 0.3)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.6
	pm.material = m
	_patch.mesh = pm
	world.add_child(_patch)
	_patch.visible = false


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, -3.0)
	c.offset = Vector3(0, 11.5, 15.0)
	c.min_dist = 0.95
	c.max_dist = 1.05


func on_start() -> void:
	for i in 4:
		_sled.append({"z": START_Z, "v": 0.0, "state": "wait", "node": null, "best": 0})
		var av := avatars[i] as PartyAvatar
		if av == null:
			continue
		av.freeze(true)
		av.can_shove = false
		# Holzschlitten mit roten Kufen
		var sled := Node3D.new()
		av.add_child(sled)
		sled.position = Vector3(0, 0.05, 0)
		WorldKit.box(sled, Vector3(0.9, 0.12, 1.5), Vector3(0, 0.22, 0), Color("#b9814d"), false)
		for s in [-1.0, 1.0]:
			WorldKit.box(sled, Vector3(0.08, 0.08, 1.7), Vector3(s * 0.38, 0.06, -0.05), Game.player_color(i), false)
			WorldKit.box(sled, Vector3(0.08, 0.3, 0.08), Vector3(s * 0.38, 0.2, -0.85), Game.player_color(i), false)
		_sled[i].node = sled


func check_end() -> bool:
	return _round >= ROUNDS


func on_tick(delta: float) -> void:
	var el := time_limit - time_left
	var r := int(el / RL)
	var t := el - r * RL
	if r != _round:
		_round = r
		if r >= ROUNDS:
			return
		_new_round()
	var ph := "ready" if t < T_READY else ("push" if t < T_READY + T_PUSH else ("slide" if t < T_READY + T_PUSH + T_SLIDE else "show"))
	if ph != _phase:
		_phase = ph
		if ph == "push":
			CutsceneManager.big_word("Anschieben!", Color("#9be7ff"), 0.6)
			Audio.sfx("go")
		elif ph == "show":
			for i in active_slots():
				if net_owned(i) and String(_sled[i].state) == "go":
					_stop(i)
	for i in active_slots():
		if net_owned(i):
			_drive(i, delta)
	_spray_t -= delta


func _new_round() -> void:
	CutsceneManager.big_word("Runde %d" % (_round + 1), Color("#ffffff"), 0.6)
	_patch_z = rng.randf_range(EDGE_Z + 4.0, EDGE_Z + 9.0)
	_patch.position = Vector3(0, 0.02, _patch_z)
	_patch.visible = true
	for i in active_slots():
		var s := _sled[i]
		s.z = START_Z
		s.v = 0.0
		s.state = "wait"
		var av := avatars[i] as PartyAvatar
		if net_owned(i):
			av.global_position = Vector3(LANES[i], RAMP_H, START_Z)
			av.velocity = Vector3.ZERO
		av.rig.face_now(Vector3.FORWARD)
		av.rig.play("sit_chair", 0.1)
		(s.node as Node3D).rotation = Vector3.ZERO


func _drive(i: int, delta: float) -> void:
	var s := _sled[i]
	var av := avatars[i] as PartyAvatar
	match String(s.state):
		"wait":
			if _phase == "push":
				s.state = "go"
				s.v = 2.5
		"go":
			var z := float(s.z)
			var v := float(s.v)
			if _phase == "push" and InputHub.pressed(i, "a"):
				v = minf(v + 0.55, 7.5)
				av.rig.hop(0.15, 0.15)
				Audio.sfx("step_sand", av.global_position, -8.0, 1.3)
			if z > RAMP_END:
				v += 5.5 * delta
			else:
				var braking := InputHub.held(i, "b") and _phase != "push"
				var on_ice := absf(z - _patch_z) < 1.3
				var dec := (5.5 if not on_ice else 1.2) if braking else (1.6 if not on_ice else 0.4)
				v = maxf(0.0, v - dec * delta)
				if braking and v > 0.5 and _spray_t <= 0.0:
					_spray_t = 0.06
					FX.dust(av.global_position + Vector3(0, 0.1, 0.6), Color(1, 1, 1), 3, 0.5)
					if randf() < 0.25:
						Audio.sfx("drift", av.global_position, -12.0)
				(s.node as Node3D).rotation.x = lerpf((s.node as Node3D).rotation.x, 0.18 if braking else 0.0, 0.2)
			z -= v * delta
			s.z = z
			s.v = v
			if z < EDGE_Z:
				_fall(i)
				return
			av.global_position = Vector3(LANES[i], _height(z), z)
			av.velocity = Vector3.ZERO
			if v <= 0.0 and z <= RAMP_END:
				_stop(i)


func _stop(i: int) -> void:
	var s := _sled[i]
	s.state = "stop"
	var dist := float(s.z) - EDGE_Z
	var pts := int(clampf(roundf(100.0 - dist * 9.0), 0.0, 100.0))
	var av := avatars[i] as PartyAvatar
	if pts > 0:
		add_score(i, float(pts), av.global_position + Vector3.UP * 1.6)
	Juice.float_text(self, av.global_position + Vector3.UP * 2.2, ("Kante geküsst! %d" % pts) if dist < 0.6 else ("%d" % pts), Color("#7dff8a") if pts >= 80 else (Color("#ffd166") if pts >= 40 else Color("#c9d6e8")), 72)
	if pts >= 80:
		av.rig.react("triumph")
		Audio.sfx("sparkle_up", av.global_position)
	elif pts < 30:
		av.rig.react("sad")


func _fall(i: int) -> void:
	var s := _sled[i]
	s.state = "fell"
	var av := avatars[i] as PartyAvatar
	av.global_position = Vector3(LANES[i], 0.05, EDGE_Z - 0.2)
	av.velocity = Vector3(0, 2.0, -maxf(float(s.v), 3.0))
	av.rig.react("scared")
	var sled: Node3D = s.node
	sled.create_tween().tween_property(sled, "rotation:x", -1.2, 0.5)
	Audio.sfx("whistle_fall", av.global_position)
	Juice.float_text(self, av.global_position + Vector3.UP * 2.0, "Zu weit!", Color("#ff8a5c"), 72)
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if is_instance_valid(av):
			FX.dust(av.global_position, Color(1, 1, 1), 18, 1.6)
			Audio.sfx("plop", av.global_position))


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var level: int = Game.players[slot].cpu_level
	var mem: Dictionary = cpu_mem[slot]
	var s := _sled[slot] if slot < _sled.size() else {}
	var held := {}
	if s.is_empty():
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	if _phase == "push":
		mem["tap"] = not bool(mem.get("tap", false))
		# Wunschtempo: genug Schwung fürs Plateau, aber nicht zu viel
		if not mem.has("want"):
			mem["want"] = randf_range(4.5, 7.5)
		if bool(mem.tap) and float(s.v) < float(mem.want) and randf() < Game.lv([0.35, 0.5, 0.6], level):
			held["a"] = true
		mem.erase("plan")
	elif String(s.state) == "go" and float(s.z) <= RAMP_END + 0.5:
		# Bremspunkt schätzen: Bremsweg v²/(2·a) plus Fehler je nach Stufe (einmal pro Runde festgelegt)
		mem.erase("want")
		if not mem.has("plan"):
			mem["plan"] = randf_range(-1.0, 1.0) * Game.lv([2.6, 1.5, 0.6], level, true) + Game.lv([0.4, 0.5, 0.6], level)
		var v := float(s.v)
		var dec := 5.5
		var stop_d := v * v / (2.0 * dec)
		var d := float(s.z) - EDGE_Z
		# Glatteis voraus: früher bremsen (Profis rechnen es ein)
		if level > 0 and float(s.z) > _patch_z and float(s.z) - _patch_z < stop_d + 2.0:
			stop_d += 1.4
		if d - stop_d < float(mem.plan):
			held["b"] = true
	InputHub.set_virtual(slot, Vector2.ZERO, held)
