extends MinigameBase
## Blumen-Farbenrausch: Ein Vögelchen auf dem Maibaum zwitschert eine Blütenfarbe – alle flitzen auf das
## passende Blütenbeet. Kurz darauf sinken alle anderen Beete (und die Mitte) in den Teich. Die Runden werden
## schneller, später werden zwei Farben gerufen – oder die Farbe wechselt im letzten Moment!
## Wer ins Wasser plumpst, scheidet aus. Online: gleicher Spiel-Zufall auf allen Geräten.

const COLORS := [Color("#ff8fb8"), Color("#ffd54f"), Color("#7ec8ff"), Color("#b38bff"), Color("#ffab66"), Color("#8ee08a")]
const NAMES := ["Rosa", "Gelb", "Blau", "Lila", "Orange", "Grün"]
const R_IN := 2.6
const R_OUT := 9.0

var sectors: Array[Node3D] = []
var hub: Node3D
var bird: CharacterRig
var _bubble: Label3D
var _ring: MeshInstance3D
var _phase := "wait"
var _t := 2.5
var _called: Array[int] = []
var _round := 0
var _fake := -1


func _init() -> void:
	game_id = "flower_rush"
	fair_spawns = true   # Startplätze jede Runde neu auslosen (kein fester Platzvorteil)
	env_preset = "day"
	time_limit = 60.0
	survival = true
	hazard = "water"
	kill_y = -3.0
	arena_radius = 10.0
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 13)
	spawn_points = [Vector3(-1.4, 0.6, -1.4), Vector3(1.4, 0.6, -1.4), Vector3(-1.4, 0.6, 1.4), Vector3(1.4, 0.6, 1.4)]


func build_arena() -> void:
	WorldKit.water(world, Vector2(90, 90), -2.2, Color(0.12, 0.42, 0.55), Color(0.42, 0.78, 0.82))
	hub = _disc(R_IN, Color("#e8dcb8"))
	for k in 6:
		var sec := _sector(k)
		sectors.append(sec)
	# Maibaum mit Vögelchen
	var pole := WorldKit.cylinder(hub, 0.18, 3.4, Vector3(0, 1.7, 0), Color("#c98d5a"), false)
	pole.name = "Pole"
	for k in 6:
		var rib := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.03
		cm.bottom_radius = 0.03
		cm.height = 3.0
		cm.material = WorldKit.mat(COLORS[k], 0.6, 0.2)
		rib.mesh = cm
		hub.add_child(rib)
		var a := TAU * k / 6.0
		rib.position = Vector3(cos(a) * 0.9, 2.1, sin(a) * 0.9)
		rib.rotation = Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5)
	bird = CharacterRig.new()
	hub.add_child(bird)
	bird.setup("pet/chick", -1, 1.4)
	bird.position = Vector3(0, 3.45, 0)
	bird.face_now(Vector3(0, 0, 1))
	bird.play("idle")
	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.font = UI.title_font()
	_bubble.font_size = 110
	_bubble.outline_size = 26
	_bubble.outline_modulate = Color(0.15, 0.08, 0.25)
	_bubble.position = Vector3(0, 5.6, 0)
	_bubble.no_depth_test = true
	_bubble.text = ""
	hub.add_child(_bubble)
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.95
	tm.outer_radius = 1.05
	tm.material = WorldKit.mat(Color.WHITE, 0.4, 0.8)
	_ring.mesh = tm
	_ring.position = Vector3(0, 0.08, 0)
	_ring.visible = false
	world.add_child(_ring)
	# Uferkulisse
	for i in 18:
		var a2 := TAU * i / 18.0 + 0.1
		var p := Vector3(cos(a2), 0, sin(a2)) * (R_OUT + 6.0 + (i % 3))
		WorldKit.place(world, ["nat/tree_oak", "plat/flowers", "nat/bush", "plat/tree", "nat/lily", "plat/mushrooms"][i % 6], Vector3(p.x, -1.6 if i % 6 == 4 else 0.0, p.z), randf() * 360.0, 2.2)
	for i in 6:
		var a3 := TAU * i / 6.0 + 0.5
		var r := CharacterRig.new()
		world.add_child(r)
		r.setup(["pet/bunny", "pet/cat", "pet/deer"][i % 3], -1, 1.2)
		r.position = Vector3(cos(a3), 0, sin(a3)) * (R_OUT + 3.5)
		r.face_now(-r.position)
		r.play("idle")


func _disc(r: float, col: Color) -> Node3D:
	var n := WorldKit.cylinder(world, r, 1.0, Vector3(0, -0.5, 0), col)
	return n


## Kuchenstück-Segment (Prisma) mit eigener Kollision und Blumen.
func _sector(k: int) -> Node3D:
	var body := StaticBody3D.new()
	world.add_child(body)
	var a0 := TAU * k / 6.0 + 0.02
	var a1 := TAU * (k + 1) / 6.0 - 0.02
	var pts := PackedVector3Array()
	var steps := 6
	for j in steps + 1:
		var a := lerpf(a0, a1, float(j) / steps)
		for y in [0.0, -1.0]:
			pts.append(Vector3(cos(a) * R_IN, y, sin(a) * R_IN))
			pts.append(Vector3(cos(a) * R_OUT, y, sin(a) * R_OUT))
	var cs := CollisionShape3D.new()
	var sh := ConvexPolygonShape3D.new()
	sh.points = pts
	cs.shape = sh
	body.add_child(cs)
	# Sichtbares Segment (SurfaceTool)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in steps:
		var a := lerpf(a0, a1, float(j) / steps)
		var b := lerpf(a0, a1, float(j + 1) / steps)
		var i0 := Vector3(cos(a) * R_IN, 0, sin(a) * R_IN)
		var o0 := Vector3(cos(a) * R_OUT, 0, sin(a) * R_OUT)
		var i1 := Vector3(cos(b) * R_IN, 0, sin(b) * R_IN)
		var o1 := Vector3(cos(b) * R_OUT, 0, sin(b) * R_OUT)
		st.set_normal(Vector3.UP)
		for v in [i0, o0, o1, i0, o1, i1]:
			st.add_vertex(v)
		st.set_normal(Vector3(cos((a + b) * 0.5), 0, sin((a + b) * 0.5)))
		for v in [o0, o0 + Vector3.DOWN, o1 + Vector3.DOWN, o0, o1 + Vector3.DOWN, o1]:
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = WorldKit.mat(COLORS[k].lerp(Color("#f4ecd6"), 0.35), 0.9)
	body.add_child(mi)
	# Blumen im Beet
	var am := (a0 + a1) * 0.5
	for f in 7:
		var rr := randf_range(R_IN + 1.2, R_OUT - 0.8)
		var aa := randf_range(a0 + 0.12, a1 - 0.12)
		var fl := Assets.spawn("nat/flower_red" if f % 2 == 0 else "plat/flowers", body, Vector3(cos(aa) * rr, 0, sin(aa) * rr), randf() * 360.0, 1.4)
		Assets.tint(fl, COLORS[k].lightened(0.15))
	var spot := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(3.2, 3.2)
	q.orientation = PlaneMesh.FACE_Y
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.albedo_texture = FX.tex_soft
	qm.albedo_color = Color(COLORS[k].r, COLORS[k].g, COLORS[k].b, 0.85)
	q.material = qm
	spot.mesh = q
	spot.position = Vector3(cos(am) * (R_IN + R_OUT) * 0.5, 0.03, sin(am) * (R_IN + R_OUT) * 0.5)
	body.add_child(spot)
	body.set_meta("col", k)
	return body


func on_start() -> void:
	for av in avatars:
		(av as PartyAvatar).rig.surface = "grass"
		(av as PartyAvatar).can_shove = true


func on_tick(delta: float) -> void:
	_t -= delta
	var speed := lerpf(1.0, 0.55, 1.0 - time_left / time_limit)
	match _phase:
		"wait":
			if _t <= 0.0:
				_call()
		"call":
			var k: float = clampf(_t / (2.6 * speed), 0.0, 1.0)
			_ring.scale = Vector3.ONE * lerpf(R_OUT, 0.6, 1.0 - k)
			if _fake >= 0 and _t < 0.9 * speed:
				_called = [_fake]
				_fake = -1
				_show_call()
				Audio.sfx("whistle_up", null, -2.0, 1.4)
				FX.emote(bird, "!", Color(1, 0.4, 0.4), 1.6, 0.6)
			if _t <= 0.0:
				_drop()
		"drop":
			if _t <= 0.0:
				_raise()


func _call() -> void:
	_round += 1
	_called = [rng.randi() % 6]
	var prog := 1.0 - time_left / time_limit
	if prog > 0.45 and rng.randf() < 0.4:
		var second := (int(_called[0]) + 1 + rng.randi() % 5) % 6
		_called.append(second)
	_fake = -1
	if prog > 0.3 and rng.randf() < 0.25:
		_fake = (int(_called[0]) + 2 + rng.randi() % 3) % 6
	_phase = "call"
	_t = 2.6 * lerpf(1.0, 0.55, prog)
	_show_call()
	bird.play("cheer", 0.05, 1.4, true)
	bird.hop(0.5, 0.3)
	Audio.sfx("pluck", null, 0.0, 1.6)
	Audio.sfx("pluck", null, -2.0, 1.9)
	_ring.visible = true


func _show_call() -> void:
	var txt := ""
	for i in _called.size():
		txt += ("  +  " if i > 0 else "") + NAMES[_called[i]]
	_bubble.text = txt
	_bubble.modulate = COLORS[_called[0]]
	(_ring.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color = COLORS[_called[0]]
	(_ring.mesh.surface_get_material(0) as StandardMaterial3D).emission = COLORS[_called[0]]
	Juice.squash(_bubble, 1.3, 1.3, 0.3)
	for sec in sectors:
		var on: bool = int(sec.get_meta("col")) in _called
		var tw := sec.create_tween()
		tw.tween_property(sec, "position:y", 0.12 if on else 0.0, 0.2)


func _drop() -> void:
	_phase = "drop"
	_t = 1.5
	_ring.visible = false
	Audio.sfx("plank_break", null, 0.0)
	Juice.shake(0.2)
	for sec in [hub] + sectors:
		var n: Node3D = sec
		if n != hub and int(n.get_meta("col")) in _called:
			continue
		var tw := n.create_tween()
		tw.tween_property(n, "position:y", -4.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		FX.splash(Vector3(0, -2.0, 0) + (Vector3(cos(TAU * (int(n.get_meta("col")) + 0.5) / 6.0), 0, sin(TAU * (int(n.get_meta("col")) + 0.5) / 6.0)) * 5.8 if n != hub else Vector3.ZERO), 0.8)
	for i in active_slots():
		if alive[i] and _on_called(i):
			(avatars[i] as PartyAvatar).rig.react("cheer")


func _raise() -> void:
	_phase = "wait"
	_t = lerpf(1.6, 0.9, 1.0 - time_left / time_limit)
	_bubble.text = ""
	for n in [hub] + sectors:
		var tw := (n as Node3D).create_tween()
		tw.tween_property(n, "position:y", -0.5 if n == hub else 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.sfx("whoosh", null, -6.0, 0.8)


func _on_called(i: int) -> bool:
	var p := (avatars[i] as Node3D).global_position
	var r := Vector2(p.x, p.z).length()
	if r < R_IN or r > R_OUT:
		return false
	var k := int(floor(fposmod(atan2(p.z, p.x), TAU) / (TAU / 6.0)))
	return k in _called


func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	if not alive[slot]:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var mem := cpu_mem[slot]
	var pos := av.global_position
	var target := Vector3.ZERO
	if _phase == "call" and not _called.is_empty():
		var react := float(mem.get("react", 0.0)) + get_physics_process_delta_time()
		mem["react"] = react
		# Reaktionszeit + gelegentlich auf die "falsche" Ansage reinfallen
		if react > Game.lv_react([0.7, 0.45, 0.25], level):
			var best := INF
			for k in _called:
				var am := TAU * (k + 0.5) / 6.0
				var c := Vector3(cos(am), 0, sin(am)) * ((R_IN + R_OUT) * 0.5)
				if c.distance_to(pos) < best:
					best = c.distance_to(pos)
					target = c
			mem["tgt"] = target
		else:
			target = mem.get("tgt", pos)
	else:
		mem["react"] = 0.0
		target = mem.get("tgt", Vector3(pos.x, 0, pos.z) * 0.6)
	var mv := Vector2(target.x - pos.x, target.z - pos.z)
	InputHub.set_virtual(slot, mv.normalized() * clampf(mv.length() / 1.5, 0.0, 1.0) * Game.lv([0.85, 0.95, 1.0], level))
