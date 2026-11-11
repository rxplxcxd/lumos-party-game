extends MinigameBase
## Kugel-Karambolage: Jeder balanciert auf einer riesigen Gummikugel über dem Meer und rammt die anderen
## von der Plattform. Stick = rollen, A = hopsen (über einen Angriff hinweg), B = Sprint-Stoß (Abklingzeit).
## Zweimal bricht der Außenring weg (vorher blinkt er). Letzter auf der Plattform gewinnt, sonst zählen Treffer.
## Online: Host-Modell (Host simuliert die Kugeln).

const ACC := 9.0
const MAX_V := 7.0
const DASH := 7.2
const DASH_CD := 2.2

var balls: Array[Dictionary] = []   # {node, mesh, pos, vel, h, vh, cd, alive}
var _radius := 10.0
var _stages := [[25.0, 8.3], [12.0, 6.6]]   # [Restzeit, neuer Radius]
var _rim: MeshInstance3D
var _outer: Array[Node3D] = []


func _init() -> void:
	game_id = "bumper_balls"
	env_preset = "pirates"
	time_limit = 50.0
	survival = true
	hazard = "water"
	kill_y = -4.0
	arena_radius = 10.0
	teaser_height = 1.2
	cannon_pos = Vector3(0, 0, 14)
	net_model = "host"
	spawn_points = [Vector3(-4, 0.6, -4), Vector3(4, 0.6, -4), Vector3(-4, 0.6, 4), Vector3(4, 0.6, 4)]


func build_arena() -> void:
	WorldKit.water(world, Vector2(160, 160), -2.4, Color(0.05, 0.25, 0.45), Color(0.25, 0.55, 0.75))
	# Bunte Ring-Plattform aus drei Zonen (die äußeren brechen nacheinander weg)
	var cols := [Color("#ffd166"), Color("#ef476f"), Color("#06d6a0")]
	for k in 3:
		var r: float = [10.0, 8.3, 6.6][k]
		var c := WorldKit.cylinder(world, r, 0.8, Vector3(0, -0.4 + k * 0.03, 0), cols[k], k == 2)   # innen höher → alle Zonen sichtbar
		if k < 2:
			_outer.append(c)
	_rim = MgKit.ring(world, _radius, 0.25, Color(1, 1, 1, 0.8), 0.6)
	_rim.position.y = 0.05
	for i in 10:
		var a := TAU * i / 10.0
		WorldKit.place(world, "pirate/rocks_a" if i % 2 else "water/buoy", Vector3(cos(a) * 17.0, -2.3, sin(a) * 17.0), randf() * 360.0, 2.2 if i % 2 else 1.6)
	WorldKit.place(world, "pirate/ship_medium", Vector3(-20, -2.4, -16), 40.0, 3.0)
	WorldKit.place(world, "pirate/tower_watch", Vector3(19, -2.4, -14), 0.0, 3.0)
	for i in 4:
		var n := Node3D.new()
		world.add_child(n)
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.1
		sm.height = 2.2
		var m := StandardMaterial3D.new()
		m.albedo_color = Game.player_color(i).lightened(0.15)
		m.roughness = 0.35
		m.rim_enabled = true
		m.rim = 0.6
		sm.material = m
		mi.mesh = sm
		n.add_child(mi)
		# Streifen, damit man das Rollen sieht
		var band := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.07
		tm.outer_radius = 1.16
		tm.material = WorldKit.mat(Color.WHITE, 0.4)
		band.mesh = tm
		band.rotation.z = PI / 2.0
		mi.add_child(band)
		var p: Vector3 = spawn_points[i]
		n.position = Vector3(p.x, 1.1, p.z)
		balls.append({"node": n, "mesh": mi, "pos": Vector2(p.x, p.z), "vel": Vector2.ZERO, "h": 0.0, "vh": 0.0, "cd": 0.0, "alive": true})


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, 0.5)
	c.offset = Vector3(0, 15.5, 13.5)
	c.min_dist = 0.9
	c.max_dist = 1.1


func on_start() -> void:
	for i in 4:
		var av := avatars[i] as PartyAvatar
		av.can_move = false
		av.can_jump = false
		av.can_shove = false
		av.set_physics_process(false)


func on_tick(delta: float) -> void:
	# Außenring bricht weg (mit Vorwarnung)
	if not _stages.is_empty():
		var st: Array = _stages[0]
		var idx := 2 - _stages.size()
		if time_left <= float(st[0]) + 2.0 and time_left > float(st[0]):
			_outer[idx].visible = int(time_left * 8.0) % 2 == 0
		elif time_left <= float(st[0]):
			_stages.pop_front()
			_radius = float(st[1])
			_outer[idx].visible = false
			for c in _outer[idx].get_children():
				if c is CollisionShape3D:
					(c as CollisionShape3D).set_deferred("disabled", true)
			Audio.sfx("plank_break")
			Juice.shake(0.4)
			FX.splash(Vector3(_radius + 1.0, -2.2, 0), 2.0)
			var tw := _rim.create_tween()
			tw.tween_property(_rim, "scale", Vector3.ONE * (_radius / 10.0), 0.4).set_trans(Tween.TRANS_BACK)
	for i in active_slots():
		var b := balls[i]
		if not bool(b.alive):
			continue
		b.cd = maxf(0.0, float(b.cd) - delta)
		var mv := InputHub.move(i)
		var v: Vector2 = b.vel
		if mv.length() > 0.1:
			v += mv.limit_length(1.0) * ACC * delta
		v = v.move_toward(Vector2.ZERO, delta * 3.0)
		if v.length() > MAX_V and float(b.cd) < DASH_CD - 0.35:
			v = v.move_toward(v.limit_length(MAX_V), delta * 14.0)
		if InputHub.pressed(i, "b") and float(b.cd) <= 0.0:
			var dir := mv.normalized() if mv.length() > 0.2 else (v.normalized() if v.length() > 0.5 else Vector2(0, -1))
			v += dir * DASH
			b.cd = DASH_CD
			Audio.sfx("boost", (b.node as Node3D).global_position, -6.0)
			FX.dust((b.node as Node3D).global_position, Color(1, 1, 1), 8, 0.6)
		if InputHub.pressed(i, "a") and float(b.h) <= 0.01:
			b.vh = 6.5
			Audio.sfx("boing", (b.node as Node3D).global_position, -8.0, 1.2)
		b.vh = float(b.vh) - 22.0 * delta
		b.h = maxf(0.0, float(b.h) + float(b.vh) * delta)
		if float(b.h) <= 0.0:
			b.vh = 0.0
		b.vel = v
		b.pos = (b.pos as Vector2) + v * delta
		if (b.pos as Vector2).length() > _radius + 0.75 and float(b.h) < 0.5:   # Kugelmitte muss über die Kante
			_fall(i)
	# Zusammenstöße (in der Luft fliegt man drüber)
	var act := active_slots()
	for x in act.size():
		for y in range(x + 1, act.size()):
			var a := balls[act[x]]
			var c := balls[act[y]]
			if not bool(a.alive) or not bool(c.alive) or absf(float(a.h) - float(c.h)) > 0.7:
				continue
			var d: Vector2 = (c.pos as Vector2) - (a.pos as Vector2)
			if d.length() < 2.2 and d.length() > 0.001:
				var n := d.normalized()
				var push := (2.2 - d.length()) * 0.5
				a.pos = (a.pos as Vector2) - n * push
				c.pos = (c.pos as Vector2) + n * push
				var rel := ((a.vel as Vector2) - (c.vel as Vector2)).dot(n)
				if rel > 0.0:
					var imp := n * rel * 1.12   # etwas mehr als elastisch: es soll ordentlich boinggg machen
					a.vel = (a.vel as Vector2) - imp
					c.vel = (c.vel as Vector2) + imp
					var mid := ((a.node as Node3D).global_position + (c.node as Node3D).global_position) * 0.5
					Audio.sfx("boing", mid, -4.0, 0.9 + rel * 0.05)
					FX.stars(mid + Vector3.UP, Color(1, 1, 1), int(clampf(rel * 2.0, 3.0, 12.0)))
					if rel > 4.0:
						Juice.shake(0.15)
					# Wer schneller angreift, bekommt den Treffer gutgeschrieben
					var hitter := act[x] if (a.vel as Vector2).length() < (c.vel as Vector2).length() else act[y]
					add_score(hitter, rel * 0.5)
	_apply_visuals(delta)


func _fall(i: int) -> void:
	var b := balls[i]
	b.alive = false
	var n: Node3D = b.node
	var tw := n.create_tween()
	tw.tween_property(n, "position:y", -5.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	FX.splash(Vector3(n.position.x, -2.3, n.position.z), 1.4)
	Audio.sfx("splash", n.global_position)
	var av := avatars[i] as PartyAvatar
	av.rig.react("launch")
	var tw2 := av.create_tween()
	tw2.tween_property(av, "global_position", av.global_position + Vector3(b.vel.x, 0, b.vel.y).normalized() * 3.0 + Vector3.DOWN * 9.0, 1.0)
	Audio.sfx("whistle_fall", av.global_position, -4.0)
	eliminate(i)


func _apply_visuals(delta: float) -> void:
	for i in 4:
		var b := balls[i]
		if not bool(b.alive):
			continue
		var n: Node3D = b.node
		var p: Vector2 = b.pos
		var v: Vector2 = b.vel
		n.position = Vector3(p.x, 1.1 + float(b.h), p.y)
		if v.length() > 0.05:
			var axis := Vector3(v.y, 0, -v.x).normalized()
			(b.mesh as Node3D).rotate(axis, v.length() * delta / 1.1)
		var av := avatars[i] as PartyAvatar
		if av.alive:
			av.global_position = n.position + Vector3.UP * 1.05
			if v.length() > 0.3:
				av.rig.face(Vector3(v.x, 0, v.y), delta, 8.0)
			av.rig.locomote(v.length(), MAX_V, float(b.h) < 0.05, float(b.vh), delta)


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	d["b"] = balls.map(func(b: Dictionary) -> Array:
		return [snappedf(b.pos.x, 0.01), snappedf(b.pos.y, 0.01), snappedf(b.vel.x, 0.1), snappedf(b.vel.y, 0.1), snappedf(float(b.h), 0.01), 1 if bool(b.alive) else 0])
	d["r"] = _radius
	return d


func net_unpack(d: Dictionary) -> void:
	var bs: Array = d.get("b", [])
	for i in mini(4, bs.size()):
		var e: Array = bs[i]
		var b := balls[i]
		b.pos = (b.pos as Vector2).lerp(Vector2(float(e[0]), float(e[1])), 0.6)
		b.vel = Vector2(float(e[2]), float(e[3]))
		b.h = float(e[4])
		if int(e[5]) == 0 and bool(b.alive):
			_fall(i)
	var r := float(d.get("r", _radius))
	if r < _radius - 0.1:
		_radius = r
		_stages.pop_front()
		for k in _outer.size():
			_outer[k].visible = _radius > [8.3, 6.6][k] + 0.1
	_apply_visuals(0.05)


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var b := balls[slot]
	if not bool(b.alive):
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var p: Vector2 = b.pos
	var best := -1
	var bd := INF
	for j in active_slots():
		if j != slot and bool(balls[j].alive):
			var dd := (balls[j].pos as Vector2).distance_to(p)
			if dd < bd:
				bd = dd
				best = j
	var mv := Vector2.ZERO
	var held := {}
	if best >= 0:
		var tp: Vector2 = balls[best].pos
		# Von der Plattformmitte aus auf den Gegner zielen: so schiebt man ihn nach außen
		mv = (tp - p).normalized() + tp.normalized() * 0.35
		if bd < 3.6 and float(b.cd) <= 0.0 and randf() < Game.lv([0.01, 0.025, 0.045], level):
			held["b"] = true
		var incoming := (balls[best].vel as Vector2).dot((p - tp).normalized())
		if level >= 1 and incoming > 6.0 and bd < 3.5 and randf() < 0.3:
			held["a"] = true
	if p.length() > _radius * 0.55:
		mv = mv * 0.25 - p.normalized() * (p.length() / _radius) * 1.8
	InputHub.set_virtual(slot, mv.limit_length(1.0) * Game.lv([0.7, 0.85, 1.0], level), held)
