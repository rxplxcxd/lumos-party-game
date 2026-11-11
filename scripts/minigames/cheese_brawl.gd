extends MinigameBase
## Käse-Kloppe: Alle sind kleine Mäuse auf einem riesigen Schweizer Käse, der auf dicken Sprungfedern ruht und
## unter dem Gewicht der Spieler wackelt und kippt. Von allen Seiten rollen schwere Kugel-Katzen über den Käse.
## B packt eine Maus vor dir – nochmal B (oder nach kurzer Zeit automatisch) wirft sie im hohen Bogen.
## Wer vom Käse fliegt oder unter eine Katze gerät, scheidet aus. Die letzte Maus gewinnt.
## Online: Host-Modell (Greifen/Werfen und Katzen simuliert der Host).

const RADIUS := 8.0
const GRAB_RANGE := 1.6

var _cheese: Node3D
var _tilt := Vector2.ZERO
var _tilt_v := Vector2.ZERO
var cats: Array[Dictionary] = []     # {node, ball, vel, alive}
var _cat_t := 2.5
var _held_by: Array[int] = [-1, -1, -1, -1]   # wer hält mich?
var _holding: Array[int] = [-1, -1, -1, -1]   # wen halte ich?
var _hold_t: Array[float] = [0, 0, 0, 0]
var _springs: Array[Node3D] = []


func _init() -> void:
	game_id = "cheese_brawl"
	env_preset = "day"
	time_limit = 50.0
	survival = true
	arena_radius = 9.0
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 11.5)
	net_model = "host"
	kill_y = -6.0
	hazard = "fall"
	spawn_points = [Vector3(-3, 1.0, -2), Vector3(3, 1.0, -2), Vector3(-3, 1.0, 2.5), Vector3(3, 1.0, 2.5)]


func build_arena() -> void:
	# Federbett unter dem Käse
	WorldKit.cylinder(world, RADIUS + 1.5, 1.0, Vector3(0, -5.5, 0), Color("#b07a4a"), false)
	for k in 8:
		var a := TAU * k / 8.0
		var sp := Node3D.new()
		world.add_child(sp)
		sp.position = Vector3(cos(a) * RADIUS * 0.6, -5.0, sin(a) * RADIUS * 0.6)
		for c in 6:
			var coil := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.45
			tm.outer_radius = 0.6
			tm.material = WorldKit.mat(Color("#c9ced8"), 0.25, 0.05)
			coil.mesh = tm
			coil.position = Vector3(0, c * 0.7, 0)
			sp.add_child(coil)
		_springs.append(sp)
	# Der Käse: Zylinder + Löcher (dunkle Mulden) + Rinde
	_cheese = Node3D.new()
	_cheese.name = "Cheese"
	world.add_child(_cheese)
	WorldKit.cylinder(_cheese, RADIUS, 1.4, Vector3(0, -0.7, 0), Color("#ffd35a"))
	WorldKit.cylinder(_cheese, RADIUS + 0.05, 0.25, Vector3(0, -1.3, 0), Color("#f0b83a"), false)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 99
	for k in 22:
		var a := rng2.randf() * TAU
		var r := rng2.randf_range(0.5, RADIUS - 0.8)
		var hole := WorldKit.cylinder(_cheese, rng2.randf_range(0.25, 0.7), 0.05, Vector3(cos(a) * r, 0.005, sin(a) * r), Color("#e6a92e"), false)
		hole.name = "Hole"
	for k in 10:
		var a2 := TAU * k / 10.0
		var side := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.45
		sm.height = 0.5
		sm.material = WorldKit.mat(Color("#e6a92e"), 0.9)
		side.mesh = sm
		side.position = Vector3(cos(a2) * RADIUS, -0.7, sin(a2) * RADIUS)
		side.scale = Vector3(1, 1, 0.4)
		side.rotation.y = -a2 + PI * 0.5
		_cheese.add_child(side)
	# Küchen-Kulisse rundherum (wir sind winzig!): riesige Tasse, Brotlaib, Kerze
	WorldKit.cylinder(world, 3.0, 6.0, Vector3(-15, -3, -10), Color("#f4f0ea"), false)
	WorldKit.cylinder(world, 3.2, 0.6, Vector3(-15, 0.2, -10), Color("#7a4a2a"), false)
	var bread := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 4.0
	bs.height = 4.5
	bs.material = WorldKit.mat(Color("#d9954a"), 0.9)
	bread.mesh = bs
	bread.scale = Vector3(1.6, 0.8, 1.0)
	bread.position = Vector3(15, -3.5, -9)
	world.add_child(bread)
	WorldKit.cylinder(world, 0.8, 8.0, Vector3(13, -2, 9), Color("#ffb3c7"), false)
	var flame := FX.emitter({"amount": 16, "life": 0.6, "one_shot": false, "explosive": 0.0, "spread": 10.0, "dir": Vector3.UP,
		"vel_min": 0.5, "vel_max": 1.0, "gravity": Vector3(0, 0.5, 0), "size": 0.3, "additive": true, "color": Color(1, 0.7, 0.3), "box": Vector3(0.2, 0.1, 0.2)})
	world.add_child(flame)
	flame.position = Vector3(13, 2.2, 9)
	flame.emitting = true


func spawn_players() -> void:
	super.spawn_players()
	for i in 4:
		_mouse_ears((avatars[i] as PartyAvatar).rig, Game.player_color(i))


## Mausohren + Schwänzchen an jede Figur.
func _mouse_ears(rig: CharacterRig, col: Color) -> void:
	for sd in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.26
		sm.height = 0.52
		sm.material = WorldKit.mat(Color("#b8b0c0"), 0.8)
		ear.mesh = sm
		ear.scale = Vector3(1, 1, 0.35)
		ear.position = Vector3(sd * 0.32, 1.75, 0)
		rig.add_child(ear)
		var inner := MeshInstance3D.new()
		var si := SphereMesh.new()
		si.radius = 0.16
		si.height = 0.32
		si.material = WorldKit.mat(Color("#ffb3c7"), 0.8)
		inner.mesh = si
		inner.scale = Vector3(1, 1, 0.3)
		inner.position = Vector3(sd * 0.32, 1.75, 0.05)
		rig.add_child(inner)
	var tail := WorldKit.cylinder(rig, 0.04, 0.9, Vector3(0, 0.5, 0.45), col.lightened(0.3), false)
	tail.rotation.x = 1.0
	var tt := tail.create_tween().set_loops()
	tt.tween_property(tail, "rotation:z", 0.5, 0.4).set_trans(Tween.TRANS_SINE)
	tt.tween_property(tail, "rotation:z", -0.5, 0.4).set_trans(Tween.TRANS_SINE)


func on_start() -> void:
	for i in 4:
		var av := avatars[i] as PartyAvatar
		av.can_shove = false
		av.max_speed = 6.4


# --- Spiel ------------------------------------------------------------------------------------------------------

func on_tick(delta: float) -> void:
	_update_tilt(delta)
	_update_grabs(delta)
	_update_cats(delta)


## Der Käse kippt zum Schwerpunkt der Mäuse (Feder-Dämpfer) und lässt sie zur tiefen Seite rutschen.
func _update_tilt(delta: float) -> void:
	var com := Vector2.ZERO
	var n := 0
	for i in active_slots():
		var av := avatars[i] as PartyAvatar
		if alive[i] and av.alive:
			com += Vector2(av.global_position.x, av.global_position.z)
			n += 1
	for c in cats:
		if bool(c.alive):
			com += Vector2((c.node as Node3D).position.x, (c.node as Node3D).position.z) * 2.0
			n += 2
	var target := (com / float(maxi(n, 1))) / RADIUS * 0.16
	_tilt_v += (target - _tilt) * 38.0 * delta
	_tilt_v *= 1.0 - minf(1.0, 5.0 * delta)
	_tilt += _tilt_v * delta
	_cheese.rotation = Vector3(_tilt.y, 0, -_tilt.x)
	for k in _springs.size():
		var sp := _springs[k]
		var lift := Vector2(sp.position.x, sp.position.z).dot(_tilt) * 0.9
		sp.scale.y = clampf(1.0 + lift, 0.6, 1.4)
	for i in active_slots():
		var av2 := avatars[i] as PartyAvatar
		if av2.alive and av2.is_on_floor():
			av2.velocity.x += _tilt.x * 22.0 * delta
			av2.velocity.z += _tilt.y * 22.0 * delta


func _update_grabs(delta: float) -> void:
	for i in active_slots():
		var av := avatars[i] as PartyAvatar
		if not av.alive or _held_by[i] >= 0:
			continue
		var h := _holding[i]
		if h >= 0:
			_hold_t[i] -= delta
			var victim := avatars[h] as PartyAvatar
			victim.global_position = av.global_position + Vector3.UP * 2.1
			victim.velocity = Vector3.ZERO
			if InputHub.pressed(i, "b") or _hold_t[i] <= 0.0:
				_throw(i, h)
		elif InputHub.pressed(i, "b"):
			_try_grab(i)


func _forward(i: int) -> Vector3:
	var rot := (avatars[i] as PartyAvatar).rig.global_rotation.y
	return Vector3(-sin(rot), 0, -cos(rot))


func _try_grab(i: int) -> void:
	var av := avatars[i] as PartyAvatar
	av.rig.play_once("pickup")
	for j in active_slots():
		if j == i or not alive[j] or _held_by[j] >= 0 or _holding[j] >= 0:
			continue
		var other := avatars[j] as PartyAvatar
		var to := other.global_position - av.global_position
		to.y = 0
		if to.length() < GRAB_RANGE and to.normalized().dot(_forward(i)) > 0.3:
			_holding[i] = j
			_held_by[j] = i
			_hold_t[i] = 1.3
			other.set_physics_process(false)
			other.rig.react("scared")
			av.rig.play("hold" if av.rig.has_clip("hold") else "idle")
			Audio.sfx("woop", av.global_position, -4.0, 1.2)
			return
	Audio.sfx("whoosh", av.global_position, -12.0, 1.4)


func _throw(i: int, j: int) -> void:
	var av := avatars[i] as PartyAvatar
	var victim := avatars[j] as PartyAvatar
	_holding[i] = -1
	_held_by[j] = -1
	victim.set_physics_process(true)
	victim.apply_knockback(_forward(i), 15.0, 0.7, 7.0)
	victim.rig.react("launch")
	av.rig.play_once("throw")
	Audio.sfx("boing", av.global_position, -2.0, 0.9)
	Juice.shake(0.15)


## Kugel-Katzen: rollen von einem Rand quer über den Käse; wer getroffen wird, ist platt.
func _update_cats(delta: float) -> void:
	_cat_t -= delta
	var prog := 1.0 - time_left / time_limit
	if _cat_t <= 0.0:
		_cat_t = lerpf(3.0, 1.2, prog) * rng.randf_range(0.8, 1.2)
		_spawn_cat(prog)
	for c in cats.duplicate():
		if not bool(c.alive):
			continue
		var n: Node3D = c.node
		var v: Vector3 = c.vel
		n.position += v * delta
		(c.ball as Node3D).rotate(v.cross(Vector3.UP).normalized() * -1.0, v.length() * delta / 1.1)
		n.position.y = 1.1 + sin(Time.get_ticks_msec() / 90.0) * 0.04
		for i in active_slots():
			var av := avatars[i] as PartyAvatar
			if not alive[i] or not av.alive or _held_by[i] >= 0:
				continue
			var d := Vector2(av.global_position.x - n.position.x, av.global_position.z - n.position.z).length()
			if d < 1.25 and av.global_position.y < 2.4:
				_squash(i)
		if Vector2(n.position.x, n.position.z).length() > RADIUS + 4.0:
			c.alive = false
			var tw := n.create_tween()
			tw.tween_property(n, "position:y", -8.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(n.queue_free)
			cats.erase(c)


func _spawn_cat(prog: float) -> void:
	var a := rng.randf() * TAU
	var from := Vector3(cos(a), 0, sin(a)) * (RADIUS + 2.5)
	var aim := Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
	var dir := (aim - from).normalized()
	var n := Node3D.new()
	world.add_child(n)
	n.position = from + Vector3.UP * 1.1
	var ball := Node3D.new()
	n.add_child(ball)
	var cols := [Color("#ff9f43"), Color("#8a8fa8"), Color("#f4f0ea"), Color("#4a4a5a")]
	var col: Color = cols[rng.randi() % cols.size()]
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.1
	sm.height = 2.2
	sm.material = WorldKit.mat(col, 0.8)
	body.mesh = sm
	ball.add_child(body)
	for k in 3:
		var stripe := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.05
		tm.outer_radius = 1.13
		tm.material = WorldKit.mat(col.darkened(0.3), 0.8)
		stripe.mesh = tm
		stripe.rotation = Vector3(0, 0, PI * 0.5 + (k - 1) * 0.45)
		ball.add_child(stripe)
	# Gesicht & Ohren (drehen nicht mit, schauen in Rollrichtung)
	var face := Node3D.new()
	n.add_child(face)
	face.rotation.y = atan2(dir.x, dir.z)
	for sd in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.35
		cm.height = 0.6
		cm.material = WorldKit.mat(col.darkened(0.1), 0.8)
		ear.mesh = cm
		ear.position = Vector3(sd * 0.55, 1.05, 0.1)
		face.add_child(ear)
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.14
		es.height = 0.28
		es.material = WorldKit.mat(Color("#2a2030"), 0.3)
		eye.mesh = es
		eye.position = Vector3(sd * 0.35, 0.35, 0.98)
		face.add_child(eye)
	var spd := lerpf(5.5, 9.0, prog) * rng.randf_range(0.9, 1.15)
	cats.append({"node": n, "ball": ball, "vel": dir * spd, "alive": true})
	Audio.sfx("evil_laugh", n.position, -14.0, 1.6)
	Audio.sfx("drift", n.position, -8.0, 0.6)


func _squash(i: int) -> void:
	var av := avatars[i] as PartyAvatar
	if _holding[i] >= 0:
		var h := _holding[i]
		_held_by[h] = -1
		_holding[i] = -1
		(avatars[h] as PartyAvatar).set_physics_process(true)
	av.alive = false
	av.freeze(true)
	av.rig.pivot.scale = Vector3(1.5, 0.2, 1.5)
	FX.stars(av.global_position + Vector3.UP, Color(1, 0.9, 0.4), 12)
	Audio.sfx("plop", av.global_position, 0.0, 0.8)
	Audio.sfx("sad_trombone", null, -8.0)
	Juice.shake(0.25)
	eliminate(i)


func check_end() -> bool:
	return alive_count() <= 1


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	d["t"] = [snappedf(_tilt.x, 0.001), snappedf(_tilt.y, 0.001)]
	var cs: Array = []
	for c in cats:
		var p := (c.node as Node3D).position
		var v: Vector3 = c.vel
		cs.append([snappedf(p.x, 0.01), snappedf(p.z, 0.01), snappedf(v.x, 0.01), snappedf(v.z, 0.01)])
	d["c"] = cs
	d["h"] = _holding
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var t: Array = d.get("t", [0, 0])
	_tilt = Vector2(float(t[0]), float(t[1]))
	_cheese.rotation = Vector3(_tilt.y, 0, -_tilt.x)
	var cs: Array = d.get("c", [])
	while cats.size() < cs.size():
		_spawn_cat(0.5)
	while cats.size() > cs.size():
		var c0: Dictionary = cats.pop_back()
		(c0.node as Node3D).queue_free()
	for k in cs.size():
		var e: Array = cs[k]
		var n: Node3D = cats[k].node
		n.position = Vector3(float(e[0]), 1.1, float(e[1]))
		var v := Vector3(float(e[2]), 0, float(e[3]))
		cats[k].vel = v
		if v.length() > 0.1:
			(cats[k].ball as Node3D).rotate(v.cross(Vector3.UP).normalized() * -1.0, v.length() * 0.05)


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	var level: int = Game.players[slot].cpu_level
	var p := Vector2(av.global_position.x, av.global_position.z)
	var mv := -p.normalized() * 0.5 if p.length() > RADIUS * 0.55 else Vector2.ZERO
	# Katzen ausweichen
	for c in cats:
		var cp := Vector2((c.node as Node3D).position.x, (c.node as Node3D).position.z)
		var v := Vector2((c.vel as Vector3).x, (c.vel as Vector3).z)
		var rel := p - cp
		if rel.length() < 5.0 and rel.dot(v) > 0.0:
			var side := Vector2(-v.y, v.x).normalized()
			mv += side * (1.0 if rel.dot(side) > 0.0 else -1.0) * Game.lv([0.6, 1.0, 1.4], level)
	var held := {}
	if _holding[slot] >= 0:
		mv = p.normalized()   # zum Rand tragen
		if p.length() > RADIUS * 0.6:
			held["b"] = true
	else:
		for j in active_slots():
			if j == slot or not alive[j]:
				continue
			var op := Vector2((avatars[j] as PartyAvatar).global_position.x, (avatars[j] as PartyAvatar).global_position.z)
			if op.distance_to(p) < 3.5 and randf() < Game.lv([0.01, 0.025, 0.05], level):
				mv = (op - p).normalized()
				if op.distance_to(p) < GRAB_RANGE:
					held["b"] = true
	InputHub.set_virtual(slot, mv.limit_length(1.0), held)
