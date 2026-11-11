extends MinigameBase
## Sandwich-Sturm: Auf einem Riesen-Picknickteller fallen Zutaten vom Himmel – ein Schatten kündigt jede an.
## Wer darunter steht, wird plattgedrückt. Gelandete Zutaten bleiben liegen und stapeln sich zu Plattformen
## (draufspringen erlaubt!). Gegen Ende fallen mehrere gleichzeitig. Knapp entwischt = Punkte bei Gleichstand.
## Online: Besitzer-Modell (Zutaten aus dem gemeinsamen Zufall).

const PLATE_R := 9.0
const KINDS := [
	{"name": "bread", "shape": "box", "size": Vector3(3.2, 0.45, 3.2), "col": Color("#e0a05a")},
	{"name": "cheese", "shape": "box", "size": Vector3(2.8, 0.3, 2.8), "col": Color("#ffd23f")},
	{"name": "tomato", "shape": "cyl", "size": Vector3(1.5, 0.35, 1.5), "col": Color("#ff4a3d")},
	{"name": "salad", "shape": "cyl", "size": Vector3(1.9, 0.25, 1.9), "col": Color("#6fd14d")},
	{"name": "salami", "shape": "cyl", "size": Vector3(1.4, 0.3, 1.4), "col": Color("#b83b4a")},
]

var _drops: Array[Dictionary] = []   # {node, kind, pos, top, t, warn, landed}
var _spawn_t := 1.5
var _space: PhysicsDirectSpaceState3D
var _lid_state := 0        # 0 = noch nicht, 1 = Warnung läuft, 2 = gelandet
var _lid_t := 0.0
var _safe: Array[Vector3] = []
var _safe_marks: Array[Node3D] = []
var _lid: MeshInstance3D


func _init() -> void:
	game_id = "sandwich_storm"
	env_preset = "day"
	time_limit = 45.0
	survival = true
	arena_radius = 9.5
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 13)
	spawn_points = [Vector3(-3, 0.6, -3), Vector3(3, 0.6, -3), Vector3(-3, 0.6, 3), Vector3(3, 0.6, 3)]


func build_arena() -> void:
	# Kariertes Picknick-Tuch, Teller, Körbe und Gläser ringsum
	for x in range(-5, 6):
		for z in range(-5, 6):
			WorldKit.box(world, Vector3(4, 0.1, 4), Vector3(x * 4, -0.65, z * 4), Color("#e8425a") if (x + z) % 2 == 0 else Color("#fff4f0"), false)
	WorldKit.cylinder(world, PLATE_R, 0.4, Vector3(0, -0.2, 0), Color("#fbfbff"))
	var rim := MgKit.ring(world, PLATE_R - 0.1, 0.35, Color("#cfd8ff"), 0.2)
	rim.position.y = 0.02
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		var p := Vector3(cos(a), 0, sin(a)) * 14.0
		WorldKit.place(world, ["town/cart", "nat/tree_oak", "hol/cookie", "nat/flower_red"][i % 4], p + Vector3(0, -0.6, 0), randf() * 360.0, [1.6, 2.4, 3.0, 2.0][i % 4])
	_space = get_world_3d().direct_space_state


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, 0.5)
	c.offset = Vector3(0, 15.0, 13.0)
	c.min_dist = 0.9
	c.max_dist = 1.1


func on_tick(delta: float) -> void:
	var prog := 1.0 - time_left / time_limit
	_update_lid(delta)
	_spawn_t -= delta
	if _spawn_t <= 0.0 and _lid_state != 1:
		var n := 1 if prog < 0.25 else (2 if prog < 0.55 else (3 if prog < 0.8 else 4))
		for k in n:
			var ang := rng.randf() * TAU
			var rad := sqrt(rng.randf()) * (PLATE_R - 1.5)
			_spawn_drop(rng.randi() % KINDS.size(), Vector3(cos(ang) * rad, 0, sin(ang) * rad), lerpf(1.25, 0.65, prog))
		_spawn_t = lerpf(1.5, 0.95, prog)
	for d in _drops:
		if bool(d.landed):
			continue
		d.t = float(d.t) - delta
		var node: Node3D = d.node
		var top := float(d.top)
		var h := float(KINDS[int(d.kind)].size.y)
		node.position.y = top - h * 0.5 + maxf(float(d.t), 0.0) * 14.0   # fällt gleichmäßig auf den Schatten
		if float(d.t) <= 0.0:
			_land(d)


## Finale: Der Brot-Deckel deckt den ganzen Teller ab – nur drei leuchtende Kreise sind sicher.
func _update_lid(delta: float) -> void:
	if _lid_state == 0 and time_left <= 8.0:
		_lid_state = 1
		_lid_t = 3.5
		for k in 3:
			var a := rng.randf() * TAU
			var r := rng.randf_range(2.0, PLATE_R - 2.5)
			var c := Vector3(cos(a) * r, 0.05, sin(a) * r)
			_safe.append(c)
			var m := MgKit.ring(world, 1.7, 0.3, Color(0.4, 1.0, 0.5, 0.9), 2.0)
			m.position = c + Vector3.UP * 0.1
			_safe_marks.append(m)
		CutsceneManager.big_word("Der Deckel kommt!", Color("#ffd166"), 0.9)
		Audio.sfx("alert")
		_lid = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(PLATE_R * 2.2, 0.7, PLATE_R * 2.2)
		bm.material = WorldKit.mat(Color("#d8964e"), 0.8)
		_lid.mesh = bm
		_lid.position = Vector3(0, 22.0, 0)
		world.add_child(_lid)
	elif _lid_state == 1:
		_lid_t -= delta
		_lid.position.y = lerpf(1.2, 22.0, clampf(_lid_t / 3.5, 0.0, 1.0) * clampf(_lid_t / 3.5, 0.0, 1.0))
		if _lid_t <= 0.0:
			_lid_state = 2
			Juice.shake(0.6)
			Audio.sfx("explosion", Vector3.ZERO, -4.0)
			FX.dust(Vector3.ZERO, Color(1, 0.9, 0.75), 40, 4.0)
			for j in active_slots():
				var av := avatars[j] as PartyAvatar
				if not av.alive or not net_owned(j):
					continue
				var safe := false
				for c in _safe:
					if Vector2(av.global_position.x - c.x, av.global_position.z - c.z).length() < 1.8:
						safe = true
				if safe:
					add_score(j, 3.0)
					av.rig.react("triumph")
				else:
					_squash(j)
			var tw := _lid.create_tween()
			tw.tween_interval(0.5)
			tw.tween_property(_lid, "position:y", 30.0, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			for m in _safe_marks:
				m.queue_free()


func _spawn_drop(kind: int, pos: Vector3, warn_t: float) -> void:
	var k: Dictionary = KINDS[kind]
	var size: Vector3 = k.size
	# Landehöhe: oberste Fläche an dieser Stelle (Stapel wachsen)
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 30.0, pos + Vector3.DOWN * 5.0, 1)
	var hit := _space.intersect_ray(q)
	var ground := float((hit.get("position", Vector3.ZERO) as Vector3).y) if not hit.is_empty() else 0.0
	var top := ground + size.y
	var body := StaticBody3D.new()
	world.add_child(body)
	body.position = Vector3(pos.x, top - size.y * 0.5 + warn_t * 14.0, pos.z)
	body.rotation.y = rng.randf() * TAU
	var mi := MeshInstance3D.new()
	var cs := CollisionShape3D.new()
	if String(k.shape) == "box":
		var bm := BoxMesh.new()
		bm.size = size
		bm.material = WorldKit.mat(k.col, 0.7)
		mi.mesh = bm
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
	else:
		var cm := CylinderMesh.new()
		cm.top_radius = size.x
		cm.bottom_radius = size.x
		cm.height = size.y
		cm.material = WorldKit.mat(k.col, 0.55)
		mi.mesh = cm
		var sh := CylinderShape3D.new()
		sh.radius = size.x
		sh.height = size.y
		cs.shape = sh
	body.add_child(mi)
	cs.disabled = true   # erst nach der Landung fest
	body.add_child(cs)
	var foot := maxf(size.x, size.z) * (0.72 if String(k.shape) == "box" else 1.0)
	var warn := MgKit.warn_disc(world, Vector3(pos.x, ground, pos.z), foot, Color(0.1, 0.05, 0.1), warn_t + 0.05)
	Audio.sfx("whistle_fall", body.position, -12.0, 1.3)
	_drops.append({"node": body, "kind": kind, "pos": pos, "top": top, "t": warn_t, "landed": false, "foot": foot, "cs": cs, "warn": warn})


func _land(d: Dictionary) -> void:
	d.landed = true
	(d.cs as CollisionShape3D).set_deferred("disabled", false)
	var node: Node3D = d.node
	var p: Vector3 = d.pos
	Juice.squash(node, 1.15, 0.7, 0.3, Vector3.ONE)
	Audio.sfx("plop", node.global_position, 0.0, 0.8)
	Audio.sfx("slime", node.global_position, -8.0)
	FX.dust(Vector3(p.x, float(d.top), p.z), Color(1, 0.95, 0.85), 10, 1.2)
	Juice.shake(0.12)
	for j in active_slots():
		var av := avatars[j] as PartyAvatar
		if not av.alive or not net_owned(j):
			continue
		var ap := av.global_position
		var dist := Vector2(ap.x - p.x, ap.z - p.z).length()
		if dist < float(d.foot) + 0.2 and ap.y < float(d.top) - 0.1:
			_squash(j)
		elif dist < float(d.foot) + 2.2:
			add_score(j, 1.0)   # knapp entwischt
			av.rig.react("scared")


func _squash(j: int) -> void:
	var av := avatars[j] as PartyAvatar
	av.freeze(true)
	av.rig.react("land_flat")
	var tw := av.rig.create_tween()
	tw.tween_property(av.rig, "scale", Vector3(1.4, 0.12, 1.4), 0.12)
	Audio.sfx("hit_soft", av.global_position)
	FX.stars(av.global_position + Vector3.UP * 0.6, Color(1, 1, 0.6), 10)
	InputHub.rumble(j, 1.0, 0.3)
	eliminate(j)


func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	if not av.alive:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var threats: Array = []
	for d in _drops:
		if not bool(d.landed) and float(d.t) < [0.45, 0.6, 0.8][level]:
			threats.append([d.pos, float(d.foot) + 0.4])
	var mv := MgKit.flee(av.global_position, threats, Vector3.ZERO, PLATE_R - 0.5, 0.75)
	if _lid_state == 1 and _lid_t < [2.2, 2.9, 3.3][level]:
		var best := Vector3.ZERO
		var bd := INF
		for c in _safe:
			var dd := c.distance_to(av.global_position)
			if dd < bd:
				bd = dd
				best = c
		var to := best - av.global_position
		mv = Vector2(to.x, to.z).normalized() if bd > 0.6 else Vector2.ZERO
	var held := {}
	# Steht vor einem hohen Stapel? Hochspringen statt dagegenlaufen
	if mv.length() > 0.5 and av.is_on_wall() and av.is_on_floor():
		held["a"] = true
	InputHub.set_virtual(slot, mv, held)
