extends MinigameBase
## Pinguin-Curling: Jede Runde eine NEUE Eisbahn – lang oder kurz, Links-/Rechtskurve, S-Kurve, Slalom mit
## Schneemännern und Eisblöcken oder ein Prellbock vor dem Haus. Man kann sich also keine Schussstärke merken,
## sondern muss jede Runde neu lesen, Banden anspielen und Hindernisse umkurven.
## Zielen: Der Pinguin liegt bäuchlings direkt vor der eigenen Figur und dreht sich live in die Schussrichtung
## (Stick links/rechts, Stick-Richtung oder Maus); eine gepunktete Linie zeigt den Weg bis zur ersten Bande.
## A gedrückt halten = Kraftleiste pendelt, loslassen = Schubs. Während der eigene Pinguin rutscht, wischt
## A-Hämmern das Eis glatter. Rammen erlaubt! Nach jeder Runde: nächster am Zentrum 3, dann 2 und 1 Punkte.
## Online: Host-Modell; die Bahn entsteht auf allen Geräten aus dem gemeinsamen Zufall + Rundennummer.

const START_Z := 16.0
const HOUSE_R := 3.0
const PR := 0.55          # Pinguin-Radius
const ROUNDS := 3
const FRICTION := 1.55
const BOUNCE := 0.55      # Energie, die an Banden erhalten bleibt
const LAYOUTS := [
	["gerade", "Lange Gerade"], ["kurz", "Kurze Bahn"], ["links", "Linkskurve"], ["rechts", "Rechtskurve"],
	["s", "S-Kurve"], ["slalom", "Schneemann-Slalom"], ["prell", "Prellbock vorm Haus"],
]

var pens: Array[Dictionary] = []     # {node, owner, vel, moving}
var _round := 0
var _turn := 0
var _order: Array[int] = []
var phase := "aim"                   # aim | slide | between | score | done
var _aim := 0.0                      # Winkel relativ zur Startrichtung (-Z)
var _power := 0.0
var _power_dir := 1.0
var _charging := false
var _current: Dictionary = {}
var _sweep := 0.0
var _wait := 0.0
var _power_bar: ProgressBar
var _info: Label
var _cam_target := Vector3(0, 0, 8)
var _last_mouse := Vector2(-1, -1)

# Bahn der aktuellen Runde
var _course_round := -1
var _course_root: Node3D
var _center: PackedVector2Array = PackedVector2Array()   # Mittellinie (x, z)
var _walls: Array = []                                   # [[a: Vector2, b: Vector2], …]
var _obst: Array = []                                    # [[pos: Vector2, r: float], …]
var _house := Vector3(0, 0, -26)
var _dots: Array[MeshInstance3D] = []


func _init() -> void:
	game_id = "penguin_curling"
	env_preset = "snow"
	time_limit = 260.0
	show_timer = false
	arena_radius = 14.0
	teaser_height = 0.9
	cannon_pos = Vector3(-6, 0, 20)
	net_model = "host"
	score_format = "%d Pkt."
	spawn_points = [Vector3(-4.0, 0.5, 19.5), Vector3(-2.4, 0.5, 20.2), Vector3(2.4, 0.5, 20.2), Vector3(4.0, 0.5, 19.5)]


func build_arena() -> void:
	WorldKit.box(world, Vector3(80, 1, 110), Vector3(0, -0.52, -12), Color("#eef4fb"))
	WorldKit.place(world, "hk/snow_bunker", Vector3(-14, 0, 24), 150.0, 3.0)
	for k in 10:
		var fan := _make_penguin(Color("#2a2f40"))
		world.add_child(fan)
		fan.position = Vector3(-7.5 + k * 1.6, 0.0, 22.5 + (k % 2) * 0.8)
		fan.rotation.y = PI
		var hop := fan.create_tween().set_loops()
		hop.tween_property(fan, "position:y", 0.25, 0.25 + k * 0.03).set_trans(Tween.TRANS_SINE)
		hop.tween_property(fan, "position:y", 0.0, 0.25 + k * 0.03).set_trans(Tween.TRANS_SINE)
	# Zielpunkte für die Ziellinie (gepunktet)
	var dm := WorldKit.mat(Color(1, 1, 1, 0.9), 0.4, 0.6)
	for k in 14:
		var d := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.09
		sm.height = 0.18
		sm.material = dm
		d.mesh = sm
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		d.visible = false
		world.add_child(d)
		_dots.append(d)


# --- Bahn-Generator -------------------------------------------------------------------------------------------

func _course_rng(r: int) -> RandomNumberGenerator:
	var g := RandomNumberGenerator.new()
	g.seed = hash("curling:%d:%d" % [rng.seed, r])
	return g


## Baut die Bahn einer Runde (deterministisch aus gemeinsamem Zufall + Runde).
func _build_course(r: int) -> void:
	_course_round = r
	if _course_root:
		_course_root.queue_free()
	_course_root = Node3D.new()
	_course_root.name = "Course%d" % r
	world.add_child(_course_root)
	var g := _course_rng(r)
	var pick: Array = LAYOUTS[g.randi() % LAYOUTS.size()] if r > 1 else LAYOUTS[[0, 1, 2, 3][g.randi() % 4]]
	var kind := String(pick[0])
	set_meta("layout_name", String(pick[1]))
	var length := g.randf_range(34.0, 46.0)
	if kind == "kurz":
		length = g.randf_range(24.0, 29.0)
	var amp := g.randf_range(5.0, 8.5)
	var half := g.randf_range(3.1, 3.9)
	var side := -1.0 if g.randf() < 0.5 else 1.0
	_center = PackedVector2Array()
	var steps := int(length / 1.5)
	for i in steps + 1:
		var t := float(i) / steps
		var x := 0.0
		match kind:
			"links", "rechts":
				var dir := -1.0 if kind == "links" else 1.0
				x = dir * amp * smoothstep(0.25, 1.0, t)
			"s":
				x = side * amp * 0.7 * sin(t * TAU * 0.85) * smoothstep(0.0, 0.2, t)
			"slalom":
				x = side * 1.2 * sin(t * TAU * 1.5) * smoothstep(0.1, 0.3, t)
		_center.append(Vector2(x, START_Z - t * length))
	# Haus kurz vor dem Bahnende, auf der Mittellinie
	var hp := _center[maxi(0, _center.size() - 3)]
	_house = Vector3(hp.x, 0, hp.y)
	# Banden links/rechts + Abschluss
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in _center.size():
		var a := _center[maxi(0, i - 1)]
		var b := _center[mini(_center.size() - 1, i + 1)]
		var tan := (b - a).normalized()
		var nrm := Vector2(-tan.y, tan.x)
		var w := half * (1.0 + 0.15 * sin(float(i) * 0.4 + float(r)))   # leicht atmende Bahnbreite
		left.append(_center[i] + nrm * w)
		right.append(_center[i] - nrm * w)
	_walls.clear()
	for i in _center.size() - 1:
		_walls.append([left[i], left[i + 1]])
		_walls.append([right[i], right[i + 1]])
	_walls.append([left[left.size() - 1], right[right.size() - 1]])
	_walls.append([left[0] + (left[0] - right[0]).normalized() * 0.0, right[0]])   # hinten (hinter dem Werfer)
	# Hindernisse
	_obst.clear()
	match kind:
		"slalom":
			for k in 3:
				var ci := int(_center.size() * (0.32 + k * 0.17))
				var off := (1.6 if k % 2 == 0 else -1.6) * side
				_obst.append([_center[ci] + Vector2(off, 0), 0.75])
		"prell":
			var ci2 := int(_center.size() * 0.72)
			_obst.append([_center[ci2], 0.9])
		_:
			if r >= 2 and g.randf() < 0.6:
				var ci3 := int(_center.size() * g.randf_range(0.45, 0.65))
				_obst.append([_center[ci3] + Vector2(g.randf_range(-1.2, 1.2), 0), 0.7])
	_build_course_visuals(left, right, g)


func _build_course_visuals(left: PackedVector2Array, right: PackedVector2Array, g: RandomNumberGenerator) -> void:
	# Eisband als ein Mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in left.size() - 1:
		var a := Vector3(left[i].x, 0.03, left[i].y)
		var b := Vector3(right[i].x, 0.03, right[i].y)
		var c := Vector3(right[i + 1].x, 0.03, right[i + 1].y)
		var d := Vector3(left[i + 1].x, 0.03, left[i + 1].y)
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(b)
		st.add_vertex(a)
		st.add_vertex(d)
		st.add_vertex(c)
	var ice := MeshInstance3D.new()
	ice.mesh = st.commit()
	var im := WorldKit.mat(Color(0.8, 0.92, 1.0), 0.04, 0.1)
	im.metallic_specular = 1.0
	im.cull_mode = BaseMaterial3D.CULL_DISABLED
	ice.material_override = im
	ice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_course_root.add_child(ice)
	# Banden (Schneewälle mit blauer Kante) entlang beider Ränder
	for w in _walls:
		var a2: Vector2 = w[0]
		var b2: Vector2 = w[1]
		var mid := (a2 + b2) * 0.5
		var len := a2.distance_to(b2)
		var seg := WorldKit.box(_course_root, Vector3(0.45, 0.55, len + 0.25), Vector3(mid.x, 0.27, mid.y), Color("#9fd0ff"), false)
		seg.rotation.y = atan2(b2.x - a2.x, b2.y - a2.y)
		var cap := WorldKit.box(_course_root, Vector3(0.6, 0.18, len + 0.3), Vector3(mid.x, 0.6, mid.y), Color("#ffffff"), false)
		cap.rotation.y = seg.rotation.y
	# Haus
	for k in 4:
		var ring := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var rr := HOUSE_R * (1.0 - k * 0.25)
		cm.top_radius = rr
		cm.bottom_radius = rr
		cm.height = 0.02
		cm.material = WorldKit.mat([Color("#3fa7ff"), Color.WHITE, Color("#ff5c7a"), Color.WHITE][k], 0.3)
		ring.mesh = cm
		ring.position = _house + Vector3(0, 0.05 + k * 0.002, 0)
		_course_root.add_child(ring)
	WorldKit.box(_course_root, Vector3(6.0, 0.02, 0.12), Vector3(_center[0].x, 0.05, START_Z - 1.6), Color("#ff5c7a"), false)
	# Hindernisse: Schneemänner & Eisblöcke
	for o in _obst:
		var p: Vector2 = o[0]
		var rad: float = o[1]
		if rad >= 0.85:
			var blk := WorldKit.box(_course_root, Vector3(rad * 1.6, 1.0, rad * 1.6), Vector3(p.x, 0.5, p.y), Color(0.75, 0.9, 1.0), false)
			blk.rotation.y = PI * 0.25
		else:
			WorldKit.place(_course_root, "hk/snowman", Vector3(p.x, 0, p.y), g.randf() * 360.0, 2.0)
	# Kulisse entlang der Bahn
	for i in range(0, left.size(), 3):
		var lp: Vector2 = left[i]
		var rp: Vector2 = right[i]
		var outl := (lp - rp).normalized()
		var keys := ["hk/tree_snow", "hk/tree_snow_b", "nat/pine_snow", "hk/snowman", "hk/present"]
		var k1: String = keys[g.randi() % keys.size()]
		var k2: String = keys[g.randi() % keys.size()]
		var q1 := lp + outl * g.randf_range(2.0, 4.5)
		var q2 := rp - outl * g.randf_range(2.0, 4.5)
		WorldKit.place(_course_root, k1, Vector3(q1.x, 0, q1.y), g.randf() * 360.0, 2.0)
		WorldKit.place(_course_root, k2, Vector3(q2.x, 0, q2.y), g.randf() * 360.0, 2.0)


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
	c.fixed_center = Vector3(0, 0, 8)
	c.offset = Vector3(0, 9.5, 12.5)
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
	UI.place(_info, Control.PRESET_CENTER_TOP, Vector2(-450, 88), Vector2(900, 50))
	_power_bar = ProgressBar.new()
	_power_bar.max_value = 1.0
	_power_bar.show_percentage = false
	root.add_child(_power_bar)
	UI.place(_power_bar, Control.PRESET_CENTER_BOTTOM, Vector2(-220, -120), Vector2(440, 28))
	_order = active_slots()
	if _is_host_model_client():
		_build_course(1)
		return
	_next_round()


func _next_round() -> void:
	_round += 1
	for p in pens:
		(p.node as Node3D).queue_free()
	pens.clear()
	_turn = 0
	for _k in (_round - 1):
		_order.push_back(_order.pop_front())
	_build_course(_round)
	CutsceneManager.big_word("Runde %d · %s" % [_round, String(get_meta("layout_name", ""))], Color.WHITE, 0.5)
	_begin_turn()


func _thrower() -> int:
	return _order[_turn] if _turn < _order.size() else -1


func _start_dir() -> Vector2:
	return (_center[1] - _center[0]).normalized() if _center.size() > 1 else Vector2(0, -1)


func _aim_dir() -> Vector2:
	return _start_dir().rotated(_aim)


func _begin_turn() -> void:
	var p := _thrower()
	if p < 0:
		_score_round()
		return
	phase = "aim"
	_aim = 0.0
	_power = 0.0
	_charging = false
	cpu_mem[p].clear()
	var pen := _make_penguin(Game.player_color(p))
	world.add_child(pen)
	var s := _center[0] + _start_dir() * 0.6
	pen.position = Vector3(s.x, 0.04, s.y)
	pen.rotation.x = -PI * 0.42   # liegt schon bäuchlings bereit
	_current = {"node": pen, "owner": p, "vel": Vector3.ZERO, "moving": false}
	pens.append(_current)
	_place_thrower()
	_info.text = "%s ist dran!" % Game.hero(Game.players[p].hero).name
	_info.add_theme_color_override("font_color", Game.player_color(p).lightened(0.3))
	_cam_target = Vector3(s.x, 0, s.y - 3.0)   # Werfer + Pinguin gut im Bild, Bahn davor sichtbar


## Figur hockt direkt hinter dem Pinguin, beide schauen in Schussrichtung.
func _place_thrower() -> void:
	var p := _thrower()
	if p < 0 or _current.is_empty():
		return
	var pen: Node3D = _current.node
	var d := _aim_dir()
	pen.rotation.y = atan2(d.x, d.y)
	var av := avatars[p] as PartyAvatar
	av.position = Vector3(pen.position.x - d.x * 1.15, 0.5, pen.position.z - d.y * 1.15)
	av.rig.face_now(Vector3(d.x, 0, d.y))
	if av.rig.current != "crouch" and av.rig.has_clip("crouch") and phase == "aim":
		av.rig.play("crouch")


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
	_update_dots()


func _tick_aim(delta: float) -> void:
	var p := _thrower()
	var mv := InputHub.move(p)
	if mv.length() > 0.6 and absf(mv.y) > 0.5 and mv.y < 0.0:
		# Stick nach vorne gedrückt: direkt in Stick-Richtung zielen
		var want := _start_dir().angle_to(mv.normalized())
		_aim = lerp_angle(_aim, clampf(want, -1.2, 1.2), clampf(delta * 6.0, 0.0, 1.0))
	else:
		_aim = clampf(_aim + mv.x * delta * 1.1, -1.2, 1.2)
	_mouse_aim(p)
	_place_thrower()
	if InputHub.held(p, "a"):
		_charging = true
		_power += _power_dir * delta * 1.0
		if _power >= 1.0 or _power <= 0.0:
			_power_dir *= -1.0
			_power = clampf(_power, 0.0, 1.0)
	elif _charging:
		_release(p)
	_power_bar.value = _power


## Maus (nur für den lokalen Spieler 1 am Rechner): Pinguin zeigt auf den Bodenpunkt unter dem Mauszeiger.
func _mouse_aim(p: int) -> void:
	if p != 0 or Game.players[0].cpu or OS.has_feature("mobile") or cam == null:
		return
	var mp := get_viewport().get_mouse_position()
	if _last_mouse.x < 0.0:
		_last_mouse = mp
		return
	if mp.distance_to(_last_mouse) < 2.0:
		return
	_last_mouse = mp
	var c: Camera3D = cam
	var o := c.project_ray_origin(mp)
	var dir := c.project_ray_normal(mp)
	if absf(dir.y) < 0.001:
		return
	var hit := o + dir * (-o.y / dir.y)
	var pen: Node3D = _current.node
	var to := Vector2(hit.x - pen.position.x, hit.z - pen.position.z)
	if to.length() > 1.0:
		_aim = clampf(_start_dir().angle_to(to.normalized()), -1.2, 1.2)


func _release(p: int) -> void:
	_charging = false
	var spd := lerpf(6.5, 17.5, _power)
	var d := _aim_dir()
	_current.vel = Vector3(d.x, 0, d.y) * spd
	_current.moving = true
	phase = "slide"
	var av := avatars[p] as PartyAvatar
	av.rig.play_once("throw")
	Audio.sfx("whoosh", av.global_position, -2.0, 0.9)
	Audio.sfx("woop", null, -6.0, 1.1)


func _tick_slide(delta: float) -> void:
	var p := _thrower()
	_sweep = maxf(0.0, _sweep - delta * 1.8)
	if InputHub.pressed(p, "a"):
		_sweep = minf(1.0, _sweep + 0.25)
		var av := avatars[p] as PartyAvatar
		av.rig.play_once("interact")
		Audio.sfx("drift", null, -16.0, 1.6)
	var pen: Node3D = _current.node
	_cam_target = Vector3(pen.position.x, 0, pen.position.z + 3.0)
	var any := false
	for pe in pens:
		if bool(pe.moving):
			any = true
	if not any:
		_turn += 1
		_wait = 0.8
		phase = "between"


# --- Physik (2D in x/z) – von Spiel UND CPU-Vorausberechnung genutzt ------------------------------------------

## Ein Schritt für einen Kreis: Reibung, Banden, Hindernisse. Gibt [pos, vel, getroffen] zurück.
func _step(pos: Vector2, vel: Vector2, dt: float, sweep: float) -> Array:
	var fric := FRICTION * (1.0 - sweep * 0.55)
	var sp := maxf(0.0, vel.length() - fric * dt)
	vel = vel.normalized() * sp if sp > 0.0 else Vector2.ZERO
	pos += vel * dt
	var hit := false
	for w in _walls:
		var a: Vector2 = w[0]
		var b: Vector2 = w[1]
		var ab := b - a
		var t := clampf((pos - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var q := a + ab * t
		var dv := pos - q
		var dist := dv.length()
		if dist < PR and dist > 0.0001:
			var nrm := dv / dist
			pos = q + nrm * PR
			var vn := vel.dot(nrm)
			if vn < 0.0:
				vel -= nrm * vn * (1.0 + BOUNCE)
				vel *= 0.9
				hit = true
	for o in _obst:
		var c: Vector2 = o[0]
		var rr: float = float(o[1]) + PR
		var dv2 := pos - c
		var d2 := dv2.length()
		if d2 < rr and d2 > 0.0001:
			var n2 := dv2 / d2
			pos = c + n2 * rr
			var vn2 := vel.dot(n2)
			if vn2 < 0.0:
				vel -= n2 * vn2 * (1.0 + BOUNCE)
				hit = true
	return [pos, vel, hit]


func _physics(delta: float) -> void:
	for pe in pens:
		if not bool(pe.moving):
			continue
		var n: Node3D = pe.node
		var v: Vector3 = pe.vel
		var res := _step(Vector2(n.position.x, n.position.z), Vector2(v.x, v.z), delta, _sweep if pe == _current else 0.0)
		var np: Vector2 = res[0]
		var nv: Vector2 = res[1]
		n.position = Vector3(np.x, 0.04, np.y)
		if nv.length() > 0.3:
			n.rotation.y = lerp_angle(n.rotation.y, atan2(nv.x, nv.y), clampf(delta * 8.0, 0.0, 1.0))
		if bool(res[2]):
			Audio.sfx("wood_hit", n.position, -10.0, 1.4)
			FX.sparks(n.position + Vector3.UP * 0.4, Color(0.9, 0.97, 1.0), 6)
		pe.vel = Vector3(nv.x, 0, nv.y)
		if nv.length() < 0.08:
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


## Gepunktete Ziellinie: geradeaus bis zur ersten Bande, danach ein kurzes Stück abgeprallt.
func _update_dots() -> void:
	var show := phase == "aim" and not _current.is_empty()
	if not show:
		for d in _dots:
			d.visible = false
		return
	var pen: Node3D = _current.node
	var pos := Vector2(pen.position.x, pen.position.z)
	var vel := _aim_dir() * 9.0
	var k := 0
	var guard := 0
	var bounced := false
	while k < _dots.size() and guard < 400:
		guard += 1
		var res := _step(pos, vel, 1.0 / 60.0, 0.0)
		var np: Vector2 = res[0]
		vel = (res[1] as Vector2).normalized() * 9.0
		if bool(res[2]):
			if bounced:
				break
			bounced = true
		if np.distance_to(pos) <= 0.0:
			break
		pos = np
		if guard % 7 == 0:
			_dots[k].visible = true
			_dots[k].position = Vector3(pos.x, 0.12, pos.y)
			_dots[k].scale = Vector3.ONE * (1.0 - float(k) / _dots.size() * 0.6)
			k += 1
	for j in range(k, _dots.size()):
		_dots[j].visible = false


func _score_round() -> void:
	phase = "score"
	_wait = 3.0
	_cam_target = _house + Vector3(0, 0, 6)
	var ds: Array = []
	for pe in pens:
		var n: Node3D = pe.node
		var d := Vector2(n.position.x - _house.x, n.position.z - _house.z).length()
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
		_info.text = "Niemand im Haus!"
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
	d["am"] = snappedf(_aim, 0.01)
	d["rd"] = _round
	d["in"] = _info.text if _info else ""
	d["cx"] = snappedf(_cam_target.x, 0.1)
	d["cz"] = snappedf(_cam_target.z, 0.1)
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var rd := int(d.get("rd", 1))
	if rd != _course_round and rd > 0:
		_build_course(rd)
	phase = String(d.get("ph", phase))
	_aim = float(d.get("am", _aim))
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
	if not pens.is_empty():
		_current = pens[pens.size() - 1]
	if _power_bar:
		_power_bar.value = float(d.get("pw", 0.0))
	if _info:
		_info.text = String(d.get("in", ""))
	_cam_target = Vector3(float(d.get("cx", _cam_target.x)), 0, float(d.get("cz", _cam_target.z)))
	cam.fixed_center = cam.fixed_center.lerp(_cam_target, 0.3)
	_update_dots()


# --- CPU: rechnet Schüsse mit derselben Physik voraus (ein Kandidat pro Bild) ------------------------------------

func _simulate(aim: float, power: float) -> float:
	var pen: Node3D = _current.node
	var pos := Vector2(pen.position.x, pen.position.z)
	var vel := _start_dir().rotated(aim) * lerpf(6.5, 17.5, power)
	var dt := 1.0 / 45.0
	for i in 900:
		var res := _step(pos, vel, dt, 0.0)
		pos = res[0]
		vel = res[1]
		if vel.length() < 0.08:
			break
	return pos.distance_to(Vector2(_house.x, _house.z))


func cpu_think(slot: int, _delta: float) -> void:
	var held := {}
	var mv := Vector2.ZERO
	if _thrower() == slot:
		var level: int = Game.players[slot].cpu_level
		var mem := cpu_mem[slot]
		if phase == "aim":
			if not mem.has("cands"):
				var cands: Array = []
				for a in 9:
					for pw in 5:
						cands.append([-0.8 + a * 0.2, 0.25 + pw * 0.17])
				mem["cands"] = cands
				mem["best"] = [0.0, 0.6, INF]
			var cl: Array = mem.cands
			if not cl.is_empty():
				var c: Array = cl.pop_back()
				var score := _simulate(float(c[0]), float(c[1]))
				if score < float(mem.best[2]):
					mem["best"] = [float(c[0]), float(c[1]), score]
				InputHub.set_virtual(slot, Vector2.ZERO, {})
				return   # weiter rechnen, noch nicht zielen
			if not mem.has("aim"):
				var noise := (3 - level) * 0.045
				mem["aim"] = float(mem.best[0]) + randf_range(-noise, noise)
				mem["pw"] = clampf(float(mem.best[1]) + randf_range(-noise, noise) * 1.5, 0.1, 0.98)
			var diff := float(mem.aim) - _aim
			mv.x = clampf(diff * 6.0, -1.0, 1.0)
			if absf(diff) < 0.02 and not (_charging and _power >= float(mem.pw) and _power_dir > 0.0):
				held["a"] = true
		elif phase == "slide":
			var pen: Node3D = _current.node
			var to_house := Vector2(_house.x - pen.position.x, _house.z - pen.position.z).length()
			if to_house > 5.0 and (_current.vel as Vector3).length() < 6.0 and randf() < 0.3 * mini(level + 1, 3):
				held["a"] = true
	InputHub.set_virtual(slot, mv, held)
