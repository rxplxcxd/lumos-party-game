extends MinigameBase
## Kürbis-Weitwurf: Alle stehen am Rand der Erntewiese. Stick im Kreis drehen (oder B hämmern), um mit dem
## dicken Kürbis Schwung zu holen – dann A drücken, wenn der Pfeil nach vorn zeigt! Je mehr Schwung und je
## genauer der Winkel, desto weiter fliegt er. Zwei Würfe, der weiteste zählt.
## Online: Jeder wirft auf seinem Gerät, die anderen sehen die Wiederholung mit gleicher Weite.

const LANES := [-6.0, -2.0, 2.0, 6.0]
const MAX_SPIN := 14.0

var _spin: Array[float] = [0, 0, 0, 0]
var _ang: Array[float] = [0, 0, 0, 0]
var _prev_stick: Array[float] = [0, 0, 0, 0]
var _throws: Array[int] = [0, 0, 0, 0]
var _busy: Array[bool] = [false, false, false, false]
var _arrows: Array[Node3D] = []
var _pumpkins: Array[Node3D] = []
var _meters: Array[MeshInstance3D] = []
var _cpu_target: Array[float] = [0, 0, 0, 0]
var _markers: Array[Node3D] = []


func _init() -> void:
	game_id = "pumpkin_toss"
	env_preset = "day"
	time_limit = 40.0
	arena_radius = 16.0
	teaser_height = 1.2
	cannon_pos = Vector3(0, 0, 9)
	score_format = "%.1f m"
	spawn_points = [Vector3(LANES[0], 0.6, 4), Vector3(LANES[1], 0.6, 4), Vector3(LANES[2], 0.6, 4), Vector3(LANES[3], 0.6, 4)]


func build_arena() -> void:
	WorldKit.box(world, Vector3(30, 1, 90), Vector3(0, -0.5, -30), Color("#86c95a"))
	for d in range(10, 75, 10):
		var line := WorldKit.box(world, Vector3(26, 0.04, 0.3), Vector3(0, 0.02, 4.0 - d), Color(1, 1, 1, 1), false)
		line.name = "Line%d" % d
		var lbl := Label3D.new()
		lbl.text = "%d m" % d
		lbl.font = UI.title_font()
		lbl.font_size = 120
		lbl.outline_size = 24
		lbl.modulate = Color("#fff6d8")
		lbl.position = Vector3(-14.0, 0.6, 4.0 - d)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(lbl)
	for i in 4:
		var x: float = LANES[i]
		var ring := WorldKit.cylinder(world, 1.2, 0.1, Vector3(x, 0.05, 4), Game.player_color(i).lightened(0.4), false)
		ring.name = "Circle%d" % i
		var arrow := Node3D.new()
		world.add_child(arrow)
		arrow.position = Vector3(x, 0.12, 4)
		var am := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.5, 0.06, 1.2)
		pm.material = WorldKit.mat(Game.player_color(i), 0.4, 0.8)
		am.mesh = pm
		am.rotation.x = -PI * 0.5
		am.position = Vector3(0, 0, -1.5)
		arrow.add_child(am)
		_arrows.append(arrow)
		var meter := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.25, 1.0, 0.25)
		bm.material = WorldKit.mat(Color("#ffb347"), 0.4, 1.0)
		meter.mesh = bm
		meter.position = Vector3(x + 1.6, 0.0, 4.5)
		meter.scale.y = 0.01
		world.add_child(meter)
		_meters.append(meter)
		var pk := Assets.spawn("grave/pumpkin", world, Vector3(x, 1.0, 3.2), 0.0, 2.2)
		_pumpkins.append(pk)
		var mk := Assets.spawn("plat/flag", world, Vector3(x, 0, 4), 0.0, 1.2)
		mk.visible = false
		Assets.tint(mk, Game.player_color(i))
		_markers.append(mk)
	for i in 10:
		WorldKit.place(world, ["surv/barrel", "nat/fence", "plat/tree", "town/cart"][i % 4], Vector3(-15.0 if i % 2 == 0 else 15.0, 0, 6.0 - i * 8.0), 90.0, 2.0)
	WorldKit.place(world, "town/windmill", Vector3(18, 0, -40), -40.0, 3.0)
	for i in 5:
		var r := CharacterRig.new()
		world.add_child(r)
		r.setup(["pet/cow", "pet/chick", "pet/bunny"][i % 3], -1, 1.2)
		r.position = Vector3(-13.5 + (i % 2) * 27.0, 0, -6.0 - i * 9.0)
		r.face_now(Vector3(-r.position.x, 0, 0))
		r.play("idle")


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, -6)
	c.offset = Vector3(0, 13, 17)
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
		av.rig.play("hold")
		_cpu_target[i] = randf_range(0.75, 0.98)


func on_tick(delta: float) -> void:
	for i in active_slots():
		if _busy[i] or _throws[i] >= 2 or not Net.owns_slot(i):
			continue
		var av := avatars[i] as PartyAvatar
		var mv := InputHub.move(i)
		if mv.length() > 0.55:
			var a := atan2(mv.y, mv.x)
			var d := wrapf(a - _prev_stick[i], -PI, PI)
			if absf(d) < 1.6:
				_spin[i] = minf(MAX_SPIN, _spin[i] + absf(d) * 2.4)
			_prev_stick[i] = a
		if InputHub.pressed(i, "b"):
			_spin[i] = minf(MAX_SPIN, _spin[i] + 0.9)
		_spin[i] = maxf(0.0, _spin[i] - delta * 2.2)
		_ang[i] += _spin[i] * delta
		_arrows[i].rotation.y = _ang[i]
		_meters[i].scale.y = maxf(0.01, _spin[i] / MAX_SPIN * 2.4)
		_meters[i].position.y = _meters[i].scale.y * 0.5
		av.rig.rotation.y = _ang[i] + PI
		_pumpkins[i].position = av.global_position + Vector3(sin(_ang[i] + PI) * -1.3, 1.1, cos(_ang[i] + PI) * -1.3)
		if _spin[i] > 2.0 and int(_ang[i] * 2.0) != int((_ang[i] - _spin[i] * delta) * 2.0):
			Audio.sfx("whoosh", av.global_position, -14.0, 0.8 + _spin[i] / MAX_SPIN * 0.6)
		if InputHub.pressed(i, "a") and _spin[i] > 1.0:
			_release(i)


func _release(i: int) -> void:
	# Pfeil vorwärts = -Z; Abweichung kostet Weite, zu große Abweichung = Wurf ins Aus
	var dirv := Vector3(-sin(_ang[i]), 0, -cos(_ang[i]))
	var acc := dirv.dot(Vector3(0, 0, -1))
	var dist := 0.0
	if acc > 0.2:
		dist = (_spin[i] / MAX_SPIN) * 70.0 * pow(acc, 1.6) + 2.0
	_throw(i, dist, dirv)
	report_score(i)


func score_extra(slot: int) -> Dictionary:
	return {"d": scores[slot], "last": _markers[slot].get_meta("last", 0.0) if _markers[slot].has_meta("last") else 0.0, "n": _throws[slot]}


func on_remote_score(slot: int, extra: Dictionary) -> void:
	var n := int(extra.get("n", 0))
	if n > _throws[slot]:
		_throw(slot, float(extra.get("last", 0.0)), Vector3(0, 0, -1), true)


func _throw(i: int, dist: float, dirv: Vector3, remote := false) -> void:
	_throws[i] += 1
	_busy[i] = true
	var av := avatars[i] as PartyAvatar
	av.rig.play("throw", 0.05, 1.4, true)
	av.rig.squash(1.2, 0.85, 0.3)
	Audio.sfx("whoosh", av.global_position, 0.0, 0.9)
	_markers[i].set_meta("last", dist)
	if not remote:
		scores[i] = maxf(scores[i], snappedf(dist, 0.1))
	var pk := _pumpkins[i]
	var from := pk.position
	var side := dirv.x * dist * 0.3
	var to := Vector3(LANES[i] + side, 0.9, 4.0 - maxf(dist, 1.0))
	if dist <= 0.0:
		to = Vector3(LANES[i] + (6.0 if dirv.x > 0 else -6.0), 0.9, 3.0)
	var h := 4.0 + dist * 0.18
	var dur := 0.7 + dist * 0.018
	var arc := func(t: float) -> void:
		pk.position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * h
		pk.rotation.x = -t * TAU * 2.0
	var tw := create_tween()
	tw.tween_method(arc, 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		Juice.squash(pk, 1.4, 0.6, 0.35, pk.scale)
		FX.dust(pk.position, Color(0.75, 0.6, 0.4), 16, 1.2)
		Audio.sfx("stone_hit", pk.position, -2.0, 0.8)
		Juice.float_text(self, pk.position + Vector3.UP * 2.5, ("%.1f m" % dist) if dist > 0.0 else "Ins Aus!", Game.player_color(i).lightened(0.3), 110)
		if dist > 0.0:
			_markers[i].visible = true
			_markers[i].position = Vector3(pk.position.x, 0, pk.position.z) if dist >= float(scores[i]) - 0.05 else _markers[i].position
			if dist > 50.0:
				av.rig.react("triumph")
				FX.confetti(pk.position + Vector3.UP, 30)
		else:
			av.rig.react("frustrated"))
	tw.tween_interval(0.8)
	tw.tween_callback(func() -> void:
		_busy[i] = false
		_spin[i] = 0.0
		if _throws[i] < 2:
			pk.position = av.global_position + Vector3(0, 1.1, -1.3)
			pk.rotation = Vector3.ZERO
			Juice.pop_in(pk, 0.3)
			av.rig.play("hold"))


func check_end() -> bool:
	for i in active_slots():
		if _throws[i] < 2 or _busy[i]:
			return false
	return true


func cpu_think(slot: int, _delta: float) -> void:
	if _busy[slot] or _throws[slot] >= 2:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var held := {}
	var t := Time.get_ticks_msec() / 1000.0 * (7.0 + mini(level, 2) * 2.0) + slot
	var mv := Vector2(cos(t), sin(t))
	if _spin[slot] >= MAX_SPIN * _cpu_target[slot] * Game.lv([0.75, 0.88, 1.0], level):
		mv = Vector2.ZERO
		var dirv := Vector3(-sin(_ang[slot]), 0, -cos(_ang[slot]))
		if dirv.dot(Vector3(0, 0, -1)) > Game.lv([0.8, 0.9, 0.97], level):
			held["a"] = true
	InputHub.set_virtual(slot, mv, held)
