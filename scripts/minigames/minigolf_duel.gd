extends MinigameBase
## Minigolf-Duell: Alle putten gleichzeitig auf dieselbe Bahn – mit echter Rollphysik.
##   * Steuerung: Stick links/rechts dreht die Zielrichtung (beim Laden feiner), A halten lädt die Kraft
##     gleichmäßig bis 100 % (bleibt dort stehen – kein Pendel), loslassen = Schlag, B bricht das Laden ab.
##     Leuchtpunkte zeigen den Startweg samt erstem Abpraller; ihre Länge und Farbe zeigen die Kraft.
##   * Physik: Rollwiderstand (konstant + geschwindigkeitsabhängig), Hügel und Senken als Höhenfeld (Hangabtrieb
##     einer rollenden Kugel, Bälle bleiben nur auf flachen Stellen liegen), Banden und Blöcke mit Rückprall über
##     den nächsten Punkt (saubere Ecken), elastische Ball-Ball-Stöße, federnde Pilz-Bumper, Lochfang abhängig von
##     Tempo und Trefferlage (zu schnell oder zu knapp am Rand = Lippe, der Ball wird abgelenkt und gebremst).
##   * CPU: simuliert Kandidaten-Schläge mit derselben Physik (direkt, über Banden, verschiedene Kräfte) und
##     wählt den besten; die Stufe bestimmt Suchumfang und Zitter-Abweichung.
## Wer zuerst einlocht, bekommt 4 Punkte, dann 3, 2, 1. Drei Löcher.

const HALF_X := 9.0
const HALF_Z := 6.5
const BALL_R := 0.22
const HOLE_R := 0.42
const V_MAX := 12.0           # Schlaggeschwindigkeit bei 100 % (m/s)
const CHARGE_T := 1.1         # Sekunden bis 100 %
const ROLL_A := 1.9           # Rollwiderstand konstant (m/s²)
const ROLL_B := 0.22          # Rollwiderstand je m/s (Rasenbremse)
const SLOPE_G := 7.0          # Hangabtrieb einer rollenden Vollkugel: 5/7 · g
const STATIC_A := 1.15        # darunter bleibt ein liegender Ball am Hang liegen
const REST_V := 0.07
const WALL_E := 0.74          # Rückprall Banden/Blöcke
const WALL_T := 0.94          # Tangentialbremse beim Bandenkontakt
const BALL_E := 0.92
const BUMPER_KICK := 2.2
const CAP_V := 3.6            # Lochfang: Höchsttempo bei Volltreffer (Mitte) …
const CAP_MIN := 0.7          # … und am Rand
const BASE_H := 0.06          # Grundhöhe des Rasens über dem Unterbau
const HOLES := [Vector3(6.5, 0, -3.5), Vector3(-6.0, 0, 3.8), Vector3(0.0, 0, -4.6)]
const TEES := [Vector3(-6.5, 0, 3.5), Vector3(6.0, 0, -3.8), Vector3(0.0, 0, 4.8)]
## Hügel (x, z, Höhe, Breite) – negative Höhe = Senke
const MOUNDS := [Vector4(2.0, -0.4, 0.32, 1.1), Vector4(-5.6, -3.4, 0.4, 1.6), Vector4(5.2, 3.6, 0.36, 1.5),
	Vector4(-2.6, -0.2, -0.2, 1.2), Vector4(-6.8, 1.6, 0.22, 1.0), Vector4(1.6, 4.4, 0.2, 1.0)]
const DOTS := 10

var balls: Array[Dictionary] = []
var bumpers: Array[Dictionary] = []
var blocks: Array[Rect2] = []
var hole_idx := 0
var hole_pos := Vector3.ZERO
var sunk_order: Array[int] = []
var _hole_node: Node3D
var _flag: Node3D
var _cup: Node3D
var _hole_time := 0.0
var _last_sink := 0.0
var _between := false
var _terrain: MeshInstance3D
var _hole2 := Vector2.ZERO
var _log := "--golf-log" in OS.get_cmdline_user_args()


func _init() -> void:
	game_id = "minigolf_duel"
	touch_profile = "golf"
	env_preset = "day"
	time_limit = 90.0
	arena_radius = 10.0
	teaser_height = 0.9
	cannon_pos = Vector3(0, 0, 12)


# --- Höhenfeld -------------------------------------------------------------------------------------------

func height_at(p: Vector2) -> float:
	var h := BASE_H
	for m: Vector4 in MOUNDS:
		var d2 := (p.x - m.x) * (p.x - m.x) + (p.y - m.y) * (p.y - m.y)
		h += m.z * exp(-d2 / (2.0 * m.w * m.w))
	# flache Mulde ums Loch (wie auf echten Minigolf-Bahnen): langsame Bälle rollen hinein, schnelle nicht
	var dh := p.distance_squared_to(_hole2)
	h -= 0.05 * exp(-dh / (2.0 * 0.5 * 0.5))
	return h


func grad_at(p: Vector2) -> Vector2:
	var g := Vector2.ZERO
	for m: Vector4 in MOUNDS:
		var dx := p.x - m.x
		var dz := p.y - m.y
		var s2 := m.w * m.w
		var e: float = m.z * exp(-(dx * dx + dz * dz) / (2.0 * s2))
		g += Vector2(-dx / s2 * e, -dz / s2 * e)
	var hd := p - _hole2
	var eh := -0.05 * exp(-hd.length_squared() / (2.0 * 0.25))
	g += Vector2(-hd.x / 0.25 * eh, -hd.y / 0.25 * eh)
	return g


func build_arena() -> void:
	WorldKit.box(world, Vector3(HALF_X * 2 + 1.0, 1.0, HALF_Z * 2 + 1.0), Vector3(0, -0.5, 0), Color("#3fae4a"))
	# Banden
	var wood := Color("#c8874a")
	for side in [-1.0, 1.0]:
		WorldKit.box(world, Vector3(HALF_X * 2 + 1.6, 0.5, 0.4), Vector3(0, 0.25, side * (HALF_Z + 0.3)), wood, false)
		WorldKit.box(world, Vector3(0.4, 0.5, HALF_Z * 2 + 1.6), Vector3(side * (HALF_X + 0.3), 0.25, 0), wood, false)
	# Hindernisse (Rechtecke in XZ) & Bumper
	blocks = [Rect2(-1.2, -1.6, 2.4, 0.6), Rect2(-4.2, 0.2, 0.6, 2.6), Rect2(3.6, -2.4, 0.6, 2.6)]
	for r in blocks:
		WorldKit.box(world, Vector3(r.size.x, 0.7, r.size.y), Vector3(r.get_center().x, 0.3, r.get_center().y), Color("#8a6a4a"), false)
	_terrain = MeshInstance3D.new()
	_terrain.name = "Green"
	world.add_child(_terrain)
	for bp in [Vector3(0, 0, 1.4), Vector3(-2.2, 0, -3.4), Vector3(2.6, 0, 3.2), Vector3(-7.0, 0, -1.0), Vector3(7.0, 0, 1.2)]:
		var m := Assets.spawn("plat/mushrooms", world, bp, randf() * 360.0, 1.0)
		# Pilz füllt genau den Bumper-Ring (das Modell hat unterschiedlich große Varianten)
		var mb := Assets.compute_aabb(m)
		m.scale = Vector3.ONE * clampf(1.35 / maxf(0.05, maxf(mb.size.x, mb.size.z)), 0.3, 4.0)
		bumpers.append({"pos": bp, "r": 0.7, "node": m})
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.62
		tm.outer_radius = 0.74
		tm.material = WorldKit.mat(Color("#ff4fb8"), 0.4, 1.0)
		ring.mesh = tm
		world.add_child(ring)
		bumpers[bumpers.size() - 1]["ring"] = ring
	# Deko ringsum
	for i in 14:
		var a := TAU * i / 14.0
		var pos := Vector3(cos(a) * (HALF_X + 3.0), 0, sin(a) * (HALF_Z + 3.0))
		WorldKit.place(world, ["golf/castle", "plat/tree", "plat/flowers", "nat/bush", "golf/obstacle_diamond", "plat/fence", "nat/tree_oak"][i % 7], pos, rad_to_deg(-a), 1.6)
	_hole_node = Node3D.new()
	world.add_child(_hole_node)
	var cup := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = HOLE_R
	cm.bottom_radius = HOLE_R
	cm.height = 0.02
	cm.material = WorldKit.mat(Color(0.03, 0.05, 0.03), 1.0)
	cup.mesh = cm
	cup.position.y = 0.012
	_hole_node.add_child(cup)
	_cup = cup
	_flag = Assets.spawn("golf/flag", _hole_node, Vector3.ZERO, 0.0, 1.6)
	var glow := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.4, 2.4)
	q.orientation = PlaneMesh.FACE_Y
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_texture = FX.tex_ring
	gm.albedo_color = Color(1, 1, 0.6, 0.6)
	q.material = gm
	glow.mesh = q
	glow.position.y = 0.03
	_hole_node.add_child(glow)
	var ps: Array[Vector3] = []
	for i in 4:
		ps.append(TEES[0] + Vector3(-1.0 + (i % 2) * 2.0, 0.5, -0.6 + (i >> 1) * 1.2))
	spawn_points = ps


## Rasen als Höhenfeld-Mesh (Mähstreifen, Hügel heller, Senken dunkler – Gefälle ist so ablesbar).
func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 0.25
	var ex := HALF_X + 0.3
	var ez := HALF_Z + 0.3
	var nx := int(ceil(ex * 2.0 / step))
	var nz := int(ceil(ez * 2.0 / step))
	var base := Color("#46b350")
	var light := Color("#7fd46a")
	var dark := Color("#2f8a3e")
	var verts: Array[Vector3] = []
	var cols: Array[Color] = []
	var norms: Array[Vector3] = []
	for iz in nz + 1:
		for ix in nx + 1:
			var p := Vector2(-ex + ix * step, -ez + iz * step)
			var h := height_at(p)
			var stripe := 0.05 if (int(floor((p.x + 20.0) / 1.5)) % 2 == 0) else -0.03
			var t := clampf((h - BASE_H) * 2.2, -1.0, 1.0)
			var c := base.lerp(light, t) if t > 0.0 else base.lerp(dark, -t)
			cols.append(c.lightened(stripe) if stripe > 0.0 else c.darkened(-stripe))
			verts.append(Vector3(p.x, h, p.y))
			var g := grad_at(p)
			norms.append(Vector3(-g.x, 1.0, -g.y).normalized())
	for iz in nz:
		for ix in nx:
			var i0 := iz * (nx + 1) + ix
			for k in [i0, i0 + 1, i0 + nx + 1, i0 + 1, i0 + nx + 2, i0 + nx + 1]:
				st.set_color(cols[k])
				st.set_normal(norms[k])
				st.add_vertex(verts[k])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	st.set_material(mat)
	_terrain.mesh = st.commit()
	for bm in bumpers:
		var bp: Vector3 = bm.pos
		var y := height_at(Vector2(bp.x, bp.z))
		(bm.node as Node3D).position.y = y - BASE_H
		(bm.ring as Node3D).position = Vector3(bp.x, y + 0.03, bp.z)


func spawn_players() -> void:
	super.spawn_players()
	var keys := ["golf/ball_red", "golf/ball_blue", "golf/ball_green", "golf/ball_red"]
	for i in 4:
		var node := Assets.spawn(keys[i], world, Vector3.ZERO, 0.0, 1.0)
		var bb := Assets.model_aabb(keys[i])
		node.scale = Vector3.ONE * (BALL_R * 2.0 / maxf(bb.size.x, 0.01)) * 1.25
		if i == 3:
			Assets.tint(node, Color(1.6, 1.4, 0.2))
		# Farbring unter dem Ball für Übersicht
		var mark := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		q.orientation = PlaneMesh.FACE_Y
		var mm := StandardMaterial3D.new()
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mm.albedo_texture = FX.tex_ring
		mm.albedo_color = Game.player_color(i)
		q.material = mm
		mark.mesh = q
		world.add_child(mark)
		# Zielhilfe: Leuchtpunkte entlang des Startwegs (inkl. erstem Abpraller)
		var dots: Array[MeshInstance3D] = []
		var dm := SphereMesh.new()
		dm.radius = 0.07
		dm.height = 0.14
		dm.radial_segments = 8
		dm.rings = 4
		var dmat := WorldKit.mat(Game.player_color(i).lightened(0.3), 0.4, 1.4)
		dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.material = dmat
		for k in DOTS:
			var d := MeshInstance3D.new()
			d.mesh = dm
			d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			d.visible = false
			world.add_child(d)
			dots.append(d)
		balls.append({"node": node, "pos": Vector2.ZERO, "vel": Vector2.ZERO, "aim": Vector2(0, -1), "charge": 0.0, "charging": false,
			"sunk": false, "lip": false, "dots": dots, "dot_mat": dmat, "strokes": 0, "mark": mark, "scl": node.scale})
	_place_hole(0)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, 0.5)
	c.offset = Vector3(0, 15.5, 11.0)
	c.min_dist = 1.0
	c.max_dist = 1.0
	c.follow = false


func _place_hole(idx: int) -> void:
	hole_idx = idx
	hole_pos = HOLES[idx]
	_hole2 = Vector2(hole_pos.x, hole_pos.z)
	_build_terrain()
	_hole_node.position = Vector3(hole_pos.x, height_at(_hole2) - 0.012, hole_pos.z)
	Juice.pop_in(_flag, 0.4)
	sunk_order.clear()
	_hole_time = 0.0
	_last_sink = 0.0
	var tee: Vector3 = TEES[idx]
	for i in 4:
		var b: Dictionary = balls[i]
		var p := Vector2(tee.x, tee.z) + Vector2(-0.9 + (i % 2) * 1.8, -0.5 + (i >> 1) * 1.0)
		b.pos = p
		b.vel = Vector2.ZERO
		b.sunk = not active[i]   # Duell: Bank-Spieler spielen nicht mit
		b.lip = false
		b.charge = 0.0
		b.charging = false
		var to := _hole2 - p
		b.aim = to.normalized()
		var on := active[i]
		(b.node as Node3D).visible = on
		(b.node as Node3D).scale = b.scl
		(b.mark as Node3D).visible = on
		(b.node as Node3D).position = Vector3(p.x, height_at(p) + BALL_R, p.y)
		(b.mark as Node3D).position = Vector3(p.x, height_at(p) + 0.04, p.y)
		cpu_mem[i].erase("plan")
		if on:
			var av := avatars[i] as PartyAvatar
			var gp := p - (b.aim as Vector2) * 0.9
			av.global_position = Vector3(gp.x, height_at(gp), gp.y)
			av.visible = true


func on_start() -> void:
	for i in active_slots():
		var av := avatars[i] as PartyAvatar
		av.can_move = false
		av.can_jump = false
		av.can_shove = false
		av.set_physics_process(false)
		av.rig.surface = "grass"


func on_tick(delta: float) -> void:
	_hole_time += delta
	_flag.rotation.y = sin(_hole_time * 2.0) * 0.15
	for i in 4:
		_control(i, delta)
	for i in 4:
		_simulate(i, delta)
	_collide_balls()
	for i in 4:
		_update_golfer(i, delta)
	var playing := active_slots().size()
	if not _between and (sunk_order.size() >= playing or _hole_time > 28.0 or (sunk_order.size() >= playing - 1 and sunk_order.size() > 0 and _hole_time - _last_sink > 10.0)):
		_next_hole()


# --- Steuerung ---------------------------------------------------------------------------------------------

func _control(i: int, delta: float) -> void:
	var b: Dictionary = balls[i]
	var vel: Vector2 = b.vel
	if b.sunk or _between or vel.length() > REST_V:
		_show_dots(i, false)
		b.charging = false
		return
	var mv := InputHub.move(i)
	if absf(mv.x) > 0.15:
		# Drehen statt springender Richtung: mit Stick, Tasten und Touch gleich präzise; beim Laden feiner
		var rate := 2.4 * (0.35 if b.charging else 1.0) * signf(mv.x) * pow(absf(mv.x), 1.6)
		b.aim = (b.aim as Vector2).rotated(rate * delta)
	if InputHub.held(i, "a"):
		if float(b.charge) >= 0.0:   # < 0: abgebrochen – erst nach Loslassen wieder laden
			if not b.charging:
				b.charging = true
				b.charge = 0.0
			b.charge = minf(CHARGE_T, float(b.charge) + delta)
			if InputHub.pressed(i, "b"):
				b.charging = false
				b.charge = -1.0
	elif b.charging:
		b.charging = false
		_shoot(i, float(b.charge) / CHARGE_T)
	else:
		b.charge = 0.0
	_show_dots(i, true)


func _show_dots(i: int, on: bool) -> void:
	var b: Dictionary = balls[i]
	var dots: Array[MeshInstance3D] = b.dots
	if not on:
		for d in dots:
			d.visible = false
		return
	var pw := clampf(float(b.charge) / CHARGE_T, 0.0, 1.0) if b.charging else 0.0
	# Weg der ersten 1,4–4,4 m mit echter Physik vorausrechnen (zeigt den ersten Bandenabprall)
	var length := 1.4 + pw * 3.0
	var pos: Vector2 = b.pos
	var vel: Vector2 = (b.aim as Vector2) * V_MAX * maxf(pw, 0.5)
	var st := [pos, vel, false, false]
	var travelled := 0.0
	var next_at := 0.35
	var k := 0
	var mat: StandardMaterial3D = b.dot_mat
	mat.albedo_color = Game.player_color(i).lightened(0.35).lerp(Color("#ff5a3c"), pw * pw)
	var guard := 0
	while k < DOTS and travelled < length and guard < 400:
		guard += 1
		var before: Vector2 = st[0]
		st = _step(st, 1.0 / 120.0, false)
		travelled += before.distance_to(st[0])
		if travelled >= next_at:
			var p: Vector2 = st[0]
			dots[k].visible = true
			dots[k].position = Vector3(p.x, height_at(p) + 0.09, p.y)
			dots[k].scale = Vector3.ONE * (1.0 - float(k) / DOTS * 0.5)
			k += 1
			next_at += length / DOTS
		if bool(st[3]) or (st[1] as Vector2).length() < 0.2:
			break
	for j in range(k, DOTS):
		dots[j].visible = false


func _shoot(i: int, power: float) -> void:
	var b: Dictionary = balls[i]
	var pw := clampf(power, 0.04, 1.0)
	b.vel = (b.aim as Vector2) * V_MAX * pw
	if _log:
		print("[GOLF] t=%.1f Spieler %d Schlag %d: Kraft %.2f Richtung %.2f von %s → Loch %s" % [_hole_time, i, int(b.strokes) + 1, pw, (b.aim as Vector2).angle(), str(b.pos), str(_hole2)])
	b.lip = false
	b.strokes = int(b.strokes) + 1
	b.charge = 0.0
	_show_dots(i, false)
	var av := avatars[i] as PartyAvatar
	av.rig.play("slice", 0.03, 1.6, true)
	av.rig.lock(0.4)
	Audio.sfx("wood_hit", (b.node as Node3D).position, -4.0 + pw * 4.0, 1.6 - pw * 0.4)
	InputHub.rumble(i, 0.2 + pw * 0.4, 0.08)
	if pw > 0.9:
		FX.ring((b.node as Node3D).position, Game.player_color(i), 1.5, 0.3)


# --- Physik ------------------------------------------------------------------------------------------------

## Ein Physikschritt für einen Ball. st = [pos, vel, lip, sunk]; fx = Effekte/Geräusche auslösen (echter Ball).
## Dieselbe Funktion rechnet die Zielhilfe und die CPU-Schlagplanung – was die CPU erwartet, passiert auch.
func _step(st: Array, h: float, fx: bool) -> Array:
	var pos: Vector2 = st[0]
	var vel: Vector2 = st[1]
	var lip: bool = st[2]
	var spd := vel.length()
	var slope := -grad_at(pos) * SLOPE_G
	if spd < REST_V:
		if pos.distance_to(_hole2) < HOLE_R:
			return [pos, Vector2.ZERO, false, true]   # über dem Loch liegen bleiben = hineinfallen
		if slope.length() < STATIC_A:
			return [pos, Vector2.ZERO, lip, false]   # liegt (flach genug)
	vel += slope * h
	spd = vel.length()
	if spd > 0.0:
		var ns := maxf(0.0, spd - (ROLL_A + ROLL_B * spd) * h)
		vel *= ns / spd
	pos += vel * h
	# Banden
	var lim_x := HALF_X - BALL_R
	var lim_z := HALF_Z - BALL_R
	if absf(pos.x) > lim_x:
		pos.x = signf(pos.x) * lim_x
		if vel.x * signf(pos.x) > 0.0:
			if fx:
				_clack(pos, absf(vel.x))
			vel = Vector2(-vel.x * WALL_E, vel.y * WALL_T)
	if absf(pos.y) > lim_z:
		pos.y = signf(pos.y) * lim_z
		if vel.y * signf(pos.y) > 0.0:
			if fx:
				_clack(pos, absf(vel.y))
			vel = Vector2(vel.x * WALL_T, -vel.y * WALL_E)
	# Blöcke: Normale über den nächsten Punkt des Rechtecks (Kanten UND Ecken prallen richtig ab)
	for r in blocks:
		var cp := Vector2(clampf(pos.x, r.position.x, r.end.x), clampf(pos.y, r.position.y, r.end.y))
		var d := pos - cp
		var dl := d.length()
		if dl < BALL_R:
			var n := d / dl if dl > 0.0001 else (pos - r.get_center()).normalized()
			pos = cp + n * BALL_R
			var vn := vel.dot(n)
			if vn < 0.0:
				if fx:
					_clack(pos, -vn)
				var vt := vel - n * vn
				vel = vt * WALL_T - n * vn * WALL_E
	# Pilz-Bumper: federn mit Extraschwung
	for bm in bumpers:
		var bp: Vector3 = bm.pos
		var c := Vector2(bp.x, bp.z)
		var d2 := pos - c
		var rr: float = float(bm.r) + BALL_R
		var dl2 := d2.length()
		if dl2 < rr and dl2 > 0.0001:
			var n2 := d2 / dl2
			pos = c + n2 * rr
			var vn2 := vel.dot(n2)
			if vn2 < 0.0:
				vel -= 2.0 * vn2 * n2
				vel += n2 * BUMPER_KICK
				if fx:
					Audio.sfx("boing", Vector3(pos.x, 0, pos.y), -6.0, 1.2)
					Juice.squash(bm.node, 1.3, 0.7, 0.3, (bm.node as Node3D).scale)
	# Loch: Fang abhängig von Tempo und Trefferlage (Stoßparameter b = Abstand der Laufbahn zur Lochmitte)
	var to_c := _hole2 - pos
	var dc := to_c.length()
	if dc < HOLE_R:
		if not lip:
			var sp := vel.length()
			var b := absf(vel.normalized().cross(to_c)) if sp > 0.001 else 0.0
			var cap := CAP_MIN + CAP_V * sqrt(maxf(0.0, 1.0 - (b / HOLE_R) * (b / HOLE_R)))
			if sp <= cap:
				return [pos, Vector2.ZERO, false, true]
			# Lippe: Ball läuft über den Rand, wird von der Mitte weg abgelenkt und gebremst
			var side := signf(vel.cross(to_c))
			vel = vel.rotated(-side * 0.5 * (b / HOLE_R + 0.15)) * 0.8
			lip = true
			if fx:
				Audio.sfx("metal_light", hole_pos, -4.0, 1.5)
		elif vel.length() < CAP_MIN:
			return [pos, Vector2.ZERO, false, true]   # nach der Lippe ausgerollt – fällt doch noch
	elif lip:
		lip = false
	return [pos, vel, lip, false]


func _simulate(i: int, delta: float) -> void:
	var b: Dictionary = balls[i]
	if b.sunk:
		return
	var vel: Vector2 = b.vel
	var pos: Vector2 = b.pos
	# Unterschritte, damit ein schneller Ball nie durch eine Kante tunnelt (max. 6 cm je Schritt)
	var n := clampi(int(ceil(vel.length() * delta / 0.06)), 1, 12)
	var st := [pos, vel, bool(b.lip), false]
	for _s in n:
		st = _step(st, delta / n, true)
		if st[3]:
			break
	b.pos = st[0]
	b.vel = st[1]
	b.lip = st[2]
	if st[3]:
		_sink(i)
		return
	pos = st[0]
	vel = st[1]
	var y := height_at(pos)
	var node: Node3D = b.node
	node.position = Vector3(pos.x, y + BALL_R, pos.y)
	(b.mark as Node3D).position = Vector3(pos.x, y + 0.04, pos.y)
	if vel.length() > 0.05:
		node.rotate(Vector3(vel.y, 0, -vel.x).normalized(), vel.length() * delta / BALL_R)


func _clack(pos: Vector2, speed: float) -> void:
	if speed > 1.5:
		Audio.sfx("wood_hit", Vector3(pos.x, 0.2, pos.y), -12.0 + minf(speed, 12.0), 1.8)


func _collide_balls() -> void:
	for a in 4:
		for c in range(a + 1, 4):
			var ba: Dictionary = balls[a]
			var bc: Dictionary = balls[c]
			if ba.sunk or bc.sunk:
				continue
			var d: Vector2 = bc.pos - ba.pos
			var dist := d.length()
			if dist < BALL_R * 2.0 and dist > 0.0001:
				var n := d / dist
				var overlap := BALL_R * 2.0 - dist
				ba.pos = (ba.pos as Vector2) - n * overlap * 0.5
				bc.pos = (bc.pos as Vector2) + n * overlap * 0.5
				var rel: float = ((ba.vel as Vector2) - (bc.vel as Vector2)).dot(n)
				if rel > 0.0:
					# gleich schwere Kugeln: Impuls entlang der Stoßnormalen
					var j := rel * (1.0 + BALL_E) * 0.5
					ba.vel = (ba.vel as Vector2) - n * j
					bc.vel = (bc.vel as Vector2) + n * j
					for k in [a, c]:
						cpu_mem[k].erase("plan")
						cpu_mem[k].erase("search")
					if rel > 0.6:
						Audio.sfx("click", Vector3(ba.pos.x, 0, ba.pos.y), -8.0 + minf(rel, 6.0), 1.4)


func _sink(i: int) -> void:
	var b: Dictionary = balls[i]
	b.sunk = true
	b.vel = Vector2.ZERO
	sunk_order.append(i)
	_last_sink = _hole_time
	_show_dots(i, false)
	var pts: int = [4, 3, 2, 1][sunk_order.size() - 1]
	add_score(i, pts, hole_pos + Vector3.UP * 2.2)
	var node: Node3D = b.node
	(b.mark as Node3D).visible = false
	var cup_y := height_at(_hole2)
	var tw := node.create_tween()
	tw.tween_property(node, "position", Vector3(hole_pos.x, cup_y - 0.1, hole_pos.z), 0.12)
	tw.tween_property(node, "scale", Vector3.ZERO, 0.1)
	Audio.sfx("coin", hole_pos, 0.0, 1.0 + sunk_order.size() * 0.1)
	FX.confetti(hole_pos + Vector3.UP * 0.5, 30 if sunk_order.size() == 1 else 14)
	FX.stars(hole_pos + Vector3.UP * 0.8, Game.player_color(i).lightened(0.4), 10)
	Juice.float_text(self, hole_pos + Vector3.UP * 3.2, "EINGELOCHT!" if int(b.strokes) > 1 else "HOLE IN ONE!", Game.player_color(i).lightened(0.4), 90)
	(avatars[i] as PartyAvatar).rig.react("victory" if sunk_order.size() == 1 else "cheer")
	InputHub.rumble(i, 0.6, 0.2)
	if sunk_order.size() == 1:
		Audio.voice("correct")


func _next_hole() -> void:
	_between = true
	for i in active_slots():
		var b: Dictionary = balls[i]
		b.strokes = 0
		_show_dots(i, false)
		if not b.sunk:
			(avatars[i] as PartyAvatar).rig.react("frustrated")
	await get_tree().create_timer(1.4, false).timeout
	if state != "play":
		return
	if hole_idx + 1 >= HOLES.size():
		end_game()
		return
	await CutsceneManager.big_word("Loch %d" % (hole_idx + 2), UI.GOLD, 0.6)
	_place_hole(hole_idx + 1)
	_between = false


func check_end() -> bool:
	return false


func _update_golfer(i: int, delta: float) -> void:
	var b: Dictionary = balls[i]
	if b.sunk or not active[i]:
		return
	var av := avatars[i] as PartyAvatar
	var p: Vector2 = b.pos
	var aim: Vector2 = b.aim
	var gp := p - aim * 0.9 + Vector2(-aim.y, aim.x) * 0.35
	var target := Vector3(gp.x, height_at(gp), gp.y)
	var cur := av.global_position
	var step := target - cur
	var resting := (b.vel as Vector2).length() < REST_V
	if step.length() > 0.1 and resting:
		av.global_position = cur + step.limit_length(6.0 * delta)
		av.rig.face(Vector3(step.x, 0, step.z), delta, 10.0)
		av.rig.locomote(6.0, 7.0, true, 0.0, delta)
	elif resting:
		av.global_position = Vector3(cur.x, target.y, cur.z)
		av.rig.face(Vector3(aim.x, 0, aim.y), delta, 10.0)
		if not av.rig.is_locked():
			av.rig.play("hold" if b.charging else "idle", 0.15)


# --- CPU: Schläge vorausrechnen ----------------------------------------------------------------------------

## Rechnet einen Schlag mit der echten Physik durch (ohne andere Bälle). Ergebnis: Endpunkt, eingelocht?
func sim_shot(start: Vector2, v: Vector2, max_t := 8.0) -> Dictionary:
	var st := [start, v, false, false]
	var t := 0.0
	var h := 1.0 / 40.0   # gröber als das Spiel (spart Rechenzeit), Unterschritte halten Kanten trotzdem dicht
	while t < max_t:
		var n := clampi(int(ceil((st[1] as Vector2).length() * h / 0.1)), 1, 8)
		for _s in n:
			st = _step(st, h / n, false)
			if st[3]:
				return {"end": _hole2, "sunk": true, "t": t}
		t += h
		if (st[1] as Vector2).length() < REST_V and (-grad_at(st[0]) * SLOPE_G).length() < STATIC_A:
			break
	return {"end": st[0], "sunk": false, "t": t}


func _shot_score(r: Dictionary) -> float:
	if r.sunk:
		return -100.0 + float(r.t) * 0.5   # eingelocht – schneller ist besser
	return (r.end as Vector2).distance_to(_hole2)


func cpu_think(slot: int, delta: float) -> void:
	var b: Dictionary = balls[slot] if slot < balls.size() else {}
	if b.is_empty() or b.sunk or _between:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var mem := cpu_mem[slot]
	var vel: Vector2 = b.vel
	if vel.length() > REST_V:
		mem.erase("plan")
		mem.erase("search")
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var pos: Vector2 = b.pos
	if not mem.has("plan"):
		if not mem.has("search"):
			mem["search"] = _make_search(pos, level)
		var se: Dictionary = mem.search
		# Rechenbudget je Bild verteilen (sonst ruckelt es auf schwachen Geräten)
		var budget := 2 + clampi(level, 0, 3)   # starke CPUs rechnen breiter UND schneller
		while budget > 0 and not (se.queue as Array).is_empty():
			budget -= 1
			var cand: Vector2 = (se.queue as Array).pop_back()
			var r := sim_shot(pos, Vector2.RIGHT.rotated(cand.x) * V_MAX * cand.y)
			var sc := _shot_score(r)
			if sc < float(se.best_score):
				se.best_score = sc
				se.best = cand
		if not (se.queue as Array).is_empty():
			InputHub.set_virtual(slot, Vector2.ZERO)
			return
		if int(se.refine) > 0:
			# Feinsuche um den besten Kandidaten
			se.refine = int(se.refine) - 1
			var bst: Vector2 = se.best
			var da: float = se.da
			var dp: float = se.dp
			for k in [Vector2(-da, 0), Vector2(da, 0), Vector2(0, -dp), Vector2(0, dp), Vector2(-da * 0.5, dp * 0.5), Vector2(da * 0.5, -dp * 0.5)]:
				var c2: Vector2 = bst + k
				(se.queue as Array).append(Vector2(c2.x, clampf(c2.y, 0.04, 1.0)))
			se.da = da * 0.5
			se.dp = dp * 0.5
			InputHub.set_virtual(slot, Vector2.ZERO)
			return
		var best: Vector2 = se.best
		# Menschliche Ungenauigkeit je Stufe (Leicht … Insane)
		var aim_err: float = Game.lv([0.12, 0.06, 0.025, 0.006], level, true)
		var pw_err: float = Game.lv([0.15, 0.08, 0.035, 0.01], level, true)
		var ang := best.x + randfn(0.0, aim_err)
		var pw := clampf(best.y * (1.0 + randfn(0.0, pw_err)), 0.04, 1.0)
		mem.erase("search")
		if _log:
			print("[GOLF] CPU %d plant: Winkel %.2f Kraft %.2f (Wertung %.2f)" % [slot, best.x, best.y, float(se.best_score)])
		mem["plan"] = {"ang": ang, "power": pw, "wait": randf_range(0.3, 0.9) - level * 0.15}
	var plan: Dictionary = mem.plan
	plan.wait = float(plan.wait) - delta
	var aim: Vector2 = b.aim
	var want := Vector2.RIGHT.rotated(float(plan.ang))
	var diff := aim.angle_to(want)
	if absf(diff) > 0.004:
		if absf(diff) < 0.03 and not b.charging:
			b.aim = want   # letzte Feinkorrektur (kleiner als ein Bild Drehung) – Stick dabei loslassen
			InputHub.set_virtual(slot, Vector2.ZERO, {})
			return
		# wie ein Mensch drehen: Stick links/rechts, kurz vor dem Ziel sanfter
		var x := clampf(diff * 4.0, -1.0, 1.0)
		if absf(x) < 0.3:
			x = 0.3 * signf(x)
		InputHub.set_virtual(slot, Vector2(x, 0), {})
		return
	if float(plan.wait) > 0.0:
		InputHub.set_virtual(slot, Vector2.ZERO, {})
		return
	var held := {}
	var target_t := float(plan.power) * CHARGE_T
	if not b.charging or float(b.charge) < target_t - delta * 0.5:
		held["a"] = true
	InputHub.set_virtual(slot, Vector2.ZERO, held)


## Suchraum der CPU: direkte Linie ± Fächer und Bandenspiegelungen, mehrere Kräfte. Höhere Stufen suchen breiter
## und verfeinern öfter.
func _make_search(pos: Vector2, level: int) -> Dictionary:
	var dirs: Array[Vector2] = []   # (Winkel, Weglänge)
	var to_h := _hole2 - pos
	var base := to_h.angle()
	var fan: int = Game.lv([4, 6, 9, 12], level, true)
	for k in range(-fan, fan + 1):
		dirs.append(Vector2(base + k * 0.09, to_h.length()))
	for m in [Vector2(_hole2.x, 2.0 * (HALF_Z - BALL_R) - _hole2.y), Vector2(_hole2.x, -2.0 * (HALF_Z - BALL_R) - _hole2.y),
			Vector2(2.0 * (HALF_X - BALL_R) - _hole2.x, _hole2.y), Vector2(-2.0 * (HALF_X - BALL_R) - _hole2.x, _hole2.y)]:
		dirs.append(Vector2((m - pos).angle(), (m - pos).length() * 1.15))   # Bande kostet Tempo
	var q: Array = []
	var need0 := 0.0
	for d in dirs:
		# Starttempo aus dem Rollwiderstand: v ≈ √(2·a·s) (plus Reserve fürs Loch)
		var need := clampf((sqrt(2.0 * (ROLL_A + 0.8) * d.y) + 0.6) / V_MAX, 0.06, 1.0)
		if need0 == 0.0:
			need0 = need
		for f in [0.8, 1.0, 1.25]:
			q.append(Vector2(d.x, clampf(need * f, 0.04, 1.0)))
	q.shuffle()
	return {"queue": q, "best": Vector2(base, need0), "best_score": INF, "refine": int(Game.lv([1, 2, 3, 4], level, true)), "da": 0.05, "dp": 0.08}
