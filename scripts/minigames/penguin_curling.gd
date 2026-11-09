extends MinigameBase
## Pinguin-Curling: Auf einer langen, spiegelglatten Eisbahn schubst jeder Spieler nacheinander seinen Pinguin,
## der sich auf den Bauch legt und Richtung Zielscheibe rutscht. Stick links/rechts = Richtung, A = Schwung
## holen (die Kraftleiste pendelt) und loslassen. Solange der eigene Pinguin rutscht, wischt A-Hämmern das Eis
## glatter. Pinguine stoßen sich gegenseitig weg – gezieltes Rammen ist erlaubt! Nach jeder Runde bekommt der
## Pinguin am nächsten am Zentrum 3 Punkte, der zweite 2, der dritte 1. Drei Runden.
## Online: Host-Modell (Host simuliert die Rutschphysik, Eingaben kommen vom Werfer).

const LANE_HALF := 3.4
const START_Z := 14.0
const HOUSE := Vector3(0, 0, -26.0)
const HOUSE_R := 3.0
const PR := 0.55          # Pinguin-Radius
const ROUNDS := 3

var pens: Array[Dictionary] = []     # {node, owner, vel, moving}
var _round := 0
var _turn := 0
var _order: Array[int] = []
var phase := "aim"                   # aim | slide | score | done
var _aim := 0.0
var _power := 0.0
var _power_dir := 1.0
var _charging := false
var _current: Dictionary = {}
var _sweep := 0.0
var _wait := 0.0
var _power_bar: ProgressBar
var _info: Label
var _cam_target := Vector3(0, 0, 8)


func _init() -> void:
	game_id = "penguin_curling"
	env_preset = "snow"
	time_limit = 200.0
	show_timer = false
	arena_radius = 12.0
	teaser_height = 0.9
	cannon_pos = Vector3(-6, 0, 18)
	net_model = "host"
	score_format = "%d Pkt."
	spawn_points = [Vector3(-3.0, 0.5, 17.5), Vector3(-1.0, 0.5, 18.2), Vector3(1.0, 0.5, 18.2), Vector3(3.0, 0.5, 17.5)]


func build_arena() -> void:
	# Eisbahn mit Banden, Zielscheibe (Haus), Startlinie
	WorldKit.box(world, Vector3(40, 1, 70), Vector3(0, -0.52, -6), Color("#eef4fb"))
	var ice := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(LANE_HALF * 2.0, 0.04, 48)
	var im := WorldKit.mat(Color(0.82, 0.93, 1.0), 0.04, 0.12)
	im.metallic_specular = 1.0
	bm.material = im
	ice.mesh = bm
	ice.position = Vector3(0, 0.02, -6)
	world.add_child(ice)
	for sd in [-1.0, 1.0]:
		WorldKit.box(world, Vector3(0.4, 0.6, 48), Vector3(sd * (LANE_HALF + 0.2), 0.3, -6), Color("#7fb8ff"), false)
	for k in 4:
		var ring := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var r := HOUSE_R * (1.0 - k * 0.25)
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = 0.02
		cm.material = WorldKit.mat([Color("#3fa7ff"), Color.WHITE, Color("#ff5c7a"), Color.WHITE][k], 0.3)
		ring.mesh = cm
		ring.position = HOUSE + Vector3(0, 0.045 + k * 0.002, 0)
		world.add_child(ring)
	WorldKit.box(world, Vector3(LANE_HALF * 2.0, 0.02, 0.12), Vector3(0, 0.05, START_Z - 1.0), Color("#ff5c7a"), false)
	# Winterliche Kulisse: Iglu, Tannen, Schneemänner, Fähnchen, zuschauende Pinguine
	WorldKit.place(world, "hk/snow_bunker", Vector3(-10, 0, -28), 30.0, 3.0)
	for i in 20:
		var z := -34.0 + i * 3.0
		WorldKit.place(world, ["hk/tree_snow", "hk/tree_snow_b", "nat/pine_snow", "hk/snowman"][i % 4], Vector3(-9.0 - (i % 3) * 2.0, 0, z), randf() * 360.0, 2.2)
		WorldKit.place(world, ["hk/tree_snow_b", "nat/pine_snow", "hk/tree_snow", "hk/present"][i % 4], Vector3(9.0 + (i % 3) * 2.0, 0, z), randf() * 360.0, 2.2)
	for k in 8:
		var fan := _make_penguin(Color("#2a2f40"))
		world.add_child(fan)
		fan.position = Vector3(-5.2 if k % 2 == 0 else 5.2, 0.0, -20.0 + k * 3.0)
		fan.rotation.y = PI * 0.5 if k % 2 == 0 else -PI * 0.5
		var hop := fan.create_tween().set_loops()
		hop.tween_property(fan, "position:y", 0.25, 0.25 + k * 0.03).set_trans(Tween.TRANS_SINE)
		hop.tween_property(fan, "position:y", 0.0, 0.25 + k * 0.03).set_trans(Tween.TRANS_SINE)


## Niedlicher Pinguin: schwarzer Körper, weißer Bauch, oranger Schnabel und Füße, Flossen, Mütze in Spielerfarbe.
func _make_penguin(cap: Color) -> Node3D:
	var n := Node3D.new()
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.2
	sm.material = WorldKit.mat(Color("#2a2f40"), 0.6)
	body.mesh = sm
	body.position = Vector3(0, 0.6, 0)
	n.add_child(body)
	var belly := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.38
	bs.height = 0.9
	bs.material = WorldKit.mat(Color("#f8f8f8"), 0.7)
	belly.mesh = bs
	belly.position = Vector3(0, 0.55, 0.18)
	n.add_child(belly)
	var beak := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.1
	cm.height = 0.25
	cm.material = WorldKit.mat(Color("#ff9f43"), 0.5)
	beak.mesh = cm
	beak.rotation.x = PI * 0.5
	beak.position = Vector3(0, 0.95, 0.48)
	n.add_child(beak)
	for sd in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.06
		es.height = 0.12
		es.material = WorldKit.mat(Color.WHITE, 0.3, 0.2)
		eye.mesh = es
		eye.position = Vector3(sd * 0.16, 1.05, 0.4)
		n.add_child(eye)
		var flip := WorldKit.box(n, Vector3(0.08, 0.5, 0.25), Vector3(sd * 0.5, 0.6, 0), Color("#2a2f40"), false)
		flip.rotation.z = sd * 0.35
		var foot := WorldKit.box(n, Vector3(0.18, 0.06, 0.26), Vector3(sd * 0.18, 0.03, 0.15), Color("#ff9f43"), false)
		foot.name = "Foot"
	var hat := WorldKit.cylinder(n, 0.28, 0.22, Vector3(0, 1.2, 0), cap, false)
	hat.name = "Hat"
	var pom := MeshInstance3D.new()
	var ps := SphereMesh.new()
	ps.radius = 0.1
	ps.height = 0.2
	ps.material = WorldKit.mat(Color.WHITE, 0.9)
	pom.mesh = ps
	pom.position = Vector3(0, 1.38, 0)
	n.add_child(pom)
	return n


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, 6)
	c.offset = Vector3(0, 9.0, 12.0)
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
	var root := UI.center_root(hud)
	_info = UI.label("", 34, UI.GOLD, true, 10)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_info)
	UI.place(_info, Control.PRESET_CENTER_TOP, Vector2(-400, 88), Vector2(800, 50))
	_power_bar = ProgressBar.new()
	_power_bar.max_value = 1.0
	_power_bar.show_percentage = false
	root.add_child(_power_bar)
	UI.place(_power_bar, Control.PRESET_CENTER_BOTTOM, Vector2(-220, -120), Vector2(440, 28))
	_order = active_slots()
	_next_round()


func _next_round() -> void:
	_round += 1
	for p in pens:
		(p.node as Node3D).queue_free()
	pens.clear()
	_turn = 0
	for _k in (_round - 1):
		_order.push_back(_order.pop_front())
	CutsceneManager.big_word("Runde %d" % _round, Color.WHITE, 0.4)
	_begin_turn()


func _thrower() -> int:
	return _order[_turn] if _turn < _order.size() else -1


func _begin_turn() -> void:
	var p := _thrower()
	if p < 0:
		_score_round()
		return
	phase = "aim"
	_aim = 0.0
	_power = 0.0
	_charging = false
	var pen := _make_penguin(Game.player_color(p))
	world.add_child(pen)
	pen.position = Vector3(0, 0.04, START_Z)
	_current = {"node": pen, "owner": p, "vel": Vector3.ZERO, "moving": false}
	pens.append(_current)
	var av := avatars[p] as PartyAvatar
	av.position = Vector3(0, 0.5, START_Z + 1.2)
	av.rig.face_now(Vector3(0, 0, -1))
	_info.text = "%s ist dran!" % Game.hero(Game.players[p].hero).name
	_info.add_theme_color_override("font_color", Game.player_color(p).lightened(0.3))
	_cam_target = Vector3(0, 0, START_Z - 6.0)


func on_tick(delta: float) -> void:
	cam.fixed_center = cam.fixed_center.lerp(_cam_target, clampf(delta * 3.0, 0.0, 1.0))
	match phase:
		"aim":
			_tick_aim(delta)
		"slide":
			_tick_slide(delta)
		"between":
			_wait -= delta
			if _wait <= 0.0:
				_begin_turn()
		"score":
			_wait -= delta
			if _wait <= 0.0:
				if _round >= ROUNDS:
					phase = "done"
					end_game()
				else:
					_next_round()
	_physics(delta)


func _tick_aim(delta: float) -> void:
	var p := _thrower()
	var mv := InputHub.move(p)
	_aim = clampf(_aim + mv.x * delta * 0.9, -0.35, 0.35)
	var pen: Node3D = _current.node
	pen.rotation.y = -_aim + PI
	pen.position.x = lerpf(pen.position.x, 0.0, delta * 4.0)
	if InputHub.held(p, "a"):
		_charging = true
		_power += _power_dir * delta * 1.1
		if _power >= 1.0 or _power <= 0.0:
			_power_dir *= -1.0
			_power = clampf(_power, 0.0, 1.0)
	elif _charging:
		_release(p)
	_power_bar.value = _power


func _release(p: int) -> void:
	_charging = false
	var spd := lerpf(7.0, 15.5, _power)
	_current.vel = Vector3(sin(_aim), 0, -cos(_aim)) * spd
	_current.moving = true
	phase = "slide"
	var av := avatars[p] as PartyAvatar
	av.rig.play_once("throw")
	Audio.sfx("whoosh", av.global_position, -2.0, 0.9)
	Audio.sfx("woop", null, -6.0, 1.1)
	var pen: Node3D = _current.node
	# Pinguin legt sich auf den Bauch
	pen.create_tween().tween_property(pen, "rotation:x", -PI * 0.42, 0.25)


func _tick_slide(delta: float) -> void:
	var p := _thrower()
	_sweep = maxf(0.0, _sweep - delta * 1.8)
	if InputHub.pressed(p, "a"):
		_sweep = minf(1.0, _sweep + 0.25)
		var av := avatars[p] as PartyAvatar
		av.rig.play_once("interact")
		Audio.sfx("drift", null, -16.0, 1.6)
	var pen: Node3D = _current.node
	_cam_target = Vector3(0, 0, pen.position.z + 4.0)
	var any := false
	for pe in pens:
		if bool(pe.moving):
			any = true
	if not any:
		(pen as Node3D).create_tween().tween_property(pen, "rotation:x", 0.0, 0.3)
		_turn += 1
		_wait = 0.8
		phase = "between"


## Rutschphysik (2D in x/z): Reibung, Wischen, elastische Stöße, Banden.
func _physics(delta: float) -> void:
	for pe in pens:
		if not bool(pe.moving):
			continue
		var v: Vector3 = pe.vel
		var fric := 1.6 * (1.0 - (_sweep * 0.55 if pe == _current else 0.0))
		var sp := maxf(0.0, v.length() - fric * delta)
		v = v.normalized() * sp if sp > 0.0 else Vector3.ZERO
		var n: Node3D = pe.node
		n.position += v * delta
		if absf(n.position.x) > LANE_HALF - PR:
			n.position.x = signf(n.position.x) * (LANE_HALF - PR)
			v.x = -v.x * 0.5
			Audio.sfx("wood_hit", n.position, -10.0, 1.4)
		if n.position.z < -31.0:
			n.position.z = -31.0
			v = Vector3.ZERO
		pe.vel = v
		if sp < 0.08:
			pe.moving = false
			pe.vel = Vector3.ZERO
	for a in pens.size():
		for b in range(a + 1, pens.size()):
			var na: Node3D = pens[a].node
			var nb: Node3D = pens[b].node
			var d := Vector3(nb.position.x - na.position.x, 0, nb.position.z - na.position.z)
			var dist := d.length()
			if dist < PR * 2.0 and dist > 0.001:
				var nrm := d / dist
				var va: Vector3 = pens[a].vel
				var vb: Vector3 = pens[b].vel
				var rel := (va - vb).dot(nrm)
				if rel > 0.0:
					pens[a].vel = va - nrm * rel * 0.92
					pens[b].vel = vb + nrm * rel * 0.92
					pens[a].moving = true
					pens[b].moving = true
					Audio.sfx("boing", nb.position, -6.0, 1.3)
					FX.sparks(na.position.lerp(nb.position, 0.5) + Vector3.UP * 0.4, Color(0.85, 0.95, 1.0), 8)
				var push := (PR * 2.0 - dist) * 0.5
				na.position -= nrm * push
				nb.position += nrm * push


func _score_round() -> void:
	phase = "score"
	_wait = 3.0
	_cam_target = HOUSE + Vector3(0, 0, 6)
	var ds: Array = []
	for pe in pens:
		var n: Node3D = pe.node
		var d := Vector2(n.position.x - HOUSE.x, n.position.z - HOUSE.z).length()
		if d <= HOUSE_R + PR:
			ds.append([d, int(pe.owner), n])
	ds.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for k in mini(3, ds.size()):
		var who := int(ds[k][1])
		var pts: int = [3, 2, 1][k]
		scores[who] += pts
		var n2: Node3D = ds[k][2]
		Juice.float_text(self, n2.position + Vector3.UP * 1.8, "+%d" % pts, Game.player_color(who).lightened(0.3), 80)
		FX.stars(n2.position + Vector3.UP, Game.player_color(who), 10)
		(avatars[who] as PartyAvatar).rig.react("cheer" if k == 0 else "wave")
	if ds.is_empty():
		_info.text = "Niemand im Ziel!"
	else:
		_info.text = "Runde %d: %s liegt vorne!" % [_round, Game.hero(Game.players[int(ds[0][1])].hero).name]
		Audio.sfx("positive", null, -4.0)


func on_timeout() -> void:
	end_game()


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	d["p"] = pens.map(func(pe: Dictionary) -> Array:
		var n: Node3D = pe.node
		return [int(pe.owner), snappedf(n.position.x, 0.01), snappedf(n.position.z, 0.01), snappedf(n.rotation.x, 0.01), snappedf(n.rotation.y, 0.01)])
	d["ph"] = phase
	d["pw"] = snappedf(_power, 0.01)
	d["in"] = _info.text if _info else ""
	d["cz"] = snappedf(_cam_target.z, 0.1)
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var src: Array = d.get("p", [])
	while pens.size() > src.size():
		var pe0: Dictionary = pens.pop_back()
		(pe0.node as Node3D).queue_free()
	while pens.size() < src.size():
		var e0: Array = src[pens.size()]
		var pen := _make_penguin(Game.player_color(int(e0[0])))
		world.add_child(pen)
		pens.append({"node": pen, "owner": int(e0[0]), "vel": Vector3.ZERO, "moving": false})
	for k in src.size():
		var e: Array = src[k]
		var n: Node3D = pens[k].node
		n.position = n.position.lerp(Vector3(float(e[1]), 0.04, float(e[2])), 0.6)
		n.rotation = Vector3(float(e[3]), float(e[4]), 0)
	if _power_bar:
		_power_bar.value = float(d.get("pw", 0.0))
	if _info:
		_info.text = String(d.get("in", ""))
	_cam_target.z = float(d.get("cz", _cam_target.z))
	cam.fixed_center = cam.fixed_center.lerp(Vector3(0, 0, _cam_target.z), 0.3)


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var held := {}
	var mv := Vector2.ZERO
	if _thrower() == slot:
		var level: int = Game.players[slot].cpu_level
		var mem := cpu_mem[slot]
		if phase == "aim":
			if not mem.has("aim"):
				mem["aim"] = randf_range(-0.06, 0.06) * (3 - level)
				mem["pw"] = clampf(0.62 + randf_range(-0.12, 0.12) * (3 - level) * 0.6, 0.2, 0.95)
			mv.x = clampf((float(mem.aim) - _aim) * 8.0, -1.0, 1.0)
			if absf(float(mem.aim) - _aim) < 0.02 and not (_charging and _power >= float(mem.pw) and _power_dir > 0.0):
				held["a"] = true
		elif phase == "slide":
			mem.erase("aim")
			var pen: Node3D = _current.node
			if pen.position.z > HOUSE.z + 6.0 and (_current.vel as Vector3).length() < 6.0 and randf() < 0.3 * (level + 1):
				held["a"] = true
	InputHub.set_virtual(slot, mv, held)
