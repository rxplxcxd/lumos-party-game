extends MinigameBase
## Sternen-Korbschlacht (2 gegen 2): Auf der Wolkenwiese tauchen funkelnde Sternenbälle auf. Einsammeln
## durch Berühren, mit B in den Wolkenkorb des anderen Teams werfen (nah = 1 Punkt, weit = 2). Ohne Ball
## schubst B – der Gegner lässt seinen Stern fallen. Team mit den meisten Punkten gewinnt. Online: Host-Modell.

const HALF_X := 9.0
const HALF_Z := 6.0

var stars: Array[Dictionary] = []
var carry: Array[int] = [-1, -1, -1, -1]
var team_pts := [0, 0]
var _spawn_t := 0.5
var _hoops: Array[Vector3] = [Vector3(-HALF_X, 3.2, 0), Vector3(HALF_X, 3.2, 0)]
var _cd: Array[float] = [0, 0, 0, 0]
var _next_id := 0


func _init() -> void:
	game_id = "star_hoops"
	env_preset = "sky"
	time_limit = 45.0
	arena_radius = 10.0
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 12)
	net_model = "host"
	spawn_points = [Vector3(-5, 0.6, -2), Vector3(5, 0.6, -2), Vector3(-5, 0.6, 2), Vector3(5, 0.6, 2)]


func on_setup() -> void:
	# Team 0 startet links und wirft rechts, Team 1 umgekehrt
	var k := [0, 0]
	spawn_points = []
	for i in 4:
		var t := teams[i] if is_team_game() else i % 2
		spawn_points.append(Vector3(-5.0 if t == 0 else 5.0, 0.6, -2.0 + k[t] * 4.0))
		k[t] += 1


func build_arena() -> void:
	WorldKit.box(world, Vector3(HALF_X * 2 + 3, 1, HALF_Z * 2 + 3), Vector3(0, -0.5, 0), Color("#f2f6ff"))
	WorldKit.box(world, Vector3(0.15, 0.03, HALF_Z * 2), Vector3(0, 0.02, 0), Color("#b9c8ff"), false)
	for side in [-1.0, 1.0]:
		WorldKit.box(world, Vector3(HALF_X * 2 + 3, 1.4, 0.4), Vector3(0, 0.7, side * (HALF_Z + 1.4)), Color(1, 1, 1)).visible = false
		WorldKit.box(world, Vector3(0.4, 1.4, HALF_Z * 2 + 3), Vector3(side * (HALF_X + 1.6), 0.7, 0), Color(1, 1, 1)).visible = false
	for t in 2:
		var hp: Vector3 = _hoops[t]
		WorldKit.cylinder(world, 0.12, hp.y, Vector3(hp.x, hp.y * 0.5, 0), Color("#e8ecff"), false)
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.9
		tm.outer_radius = 1.15
		tm.material = WorldKit.mat(TEAM_COLORS[t].lightened(0.35), 0.5, 0.4)
		ring.mesh = tm
		ring.position = hp
		world.add_child(ring)
		for k in 6:
			var puff := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.45
			sm.height = 0.7
			sm.material = WorldKit.mat(Color.WHITE, 1.0, 0.15)
			puff.mesh = sm
			world.add_child(puff)
			var a := TAU * k / 6.0
			puff.position = hp + Vector3(cos(a), 0, sin(a)) * 1.05
	for i in 20:
		var a2 := TAU * i / 20.0
		var p := MeshInstance3D.new()
		var s2 := SphereMesh.new()
		s2.radius = randf_range(1.5, 3.0)
		s2.height = s2.radius * 1.3
		s2.material = WorldKit.mat(Color.WHITE, 1.0, 0.18)
		p.mesh = s2
		world.add_child(p)
		p.position = Vector3(cos(a2) * 16.0, randf_range(-4, -1), sin(a2) * 13.0)


func on_start() -> void:
	for av in avatars:
		(av as PartyAvatar).rig.surface = "cloud"
		(av as PartyAvatar).can_shove = false


func _team(i: int) -> int:
	return teams[i] if is_team_game() else i % 2


func on_tick(delta: float) -> void:
	_spawn_t -= delta
	if _spawn_t <= 0.0 and stars.size() < 3:
		_spawn_t = 1.8
		_spawn_star(Vector3(rng.randf_range(-3, 3), 0.6, rng.randf_range(-HALF_Z + 1, HALF_Z - 1)))
	for i in active_slots():
		_cd[i] = maxf(0.0, _cd[i] - delta)
		var av := avatars[i] as PartyAvatar
		av.max_speed = 6.0 if carry[i] >= 0 else 7.2
		if carry[i] >= 0:
			var st := _star(carry[i])
			if st.is_empty():
				carry[i] = -1
			else:
				(st.node as Node3D).position = av.global_position + Vector3.UP * 2.2
		if InputHub.pressed(i, "b") and _cd[i] <= 0.0:
			_cd[i] = 0.5
			if carry[i] >= 0:
				_throw(i)
			else:
				_shove(i)
	for st in stars.duplicate():
		if int(st.holder) >= 0:
			continue
		var n: Node3D = st.node
		if st.has("fly"):
			continue
		n.rotation.y += delta * 3.0
		n.position.y = 0.7 + sin(Time.get_ticks_msec() / 220.0 + float(st.id)) * 0.15
		for i in active_slots():
			if carry[i] < 0 and (avatars[i] as Node3D).global_position.distance_to(n.position) < 1.2:
				carry[i] = int(st.id)
				st.holder = i
				Audio.sfx("item_get", n.position, -6.0)
				break


func _spawn_star(p: Vector3) -> void:
	var n := Assets.spawn("plat/star", world, p, 0.0, 1.8)
	Assets.tint(n, Color(1.15, 1.05, 0.6), false, 0.5)
	Juice.pop_in(n, 0.3)
	_next_id += 1
	stars.append({"id": _next_id, "node": n, "holder": -1})


func _star(id: int) -> Dictionary:
	for st in stars:
		if int(st.id) == id:
			return st
	return {}


func _throw(i: int) -> void:
	var st := _star(carry[i])
	carry[i] = -1
	if st.is_empty():
		return
	st.holder = -2
	st["fly"] = true
	var av := avatars[i] as PartyAvatar
	var t := _team(i)
	var hoop: Vector3 = _hoops[1 - t]
	var from := av.global_position + Vector3.UP * 2.2
	var dist := Vector2(hoop.x - from.x, hoop.z - from.z).length()
	var chance := clampf(1.15 - dist / 13.0, 0.15, 0.95)
	var hit := randf() < chance
	var pts := 2 if dist > 7.0 else 1
	var to := hoop if hit else hoop + Vector3(randf_range(-2, 2), -3.0, randf_range(-2.5, 2.5))
	av.rig.play("throw", 0.05, 1.5, true)
	var n: Node3D = st.node
	var arc := func(k: float) -> void:
		n.position = from.lerp(to, k) + Vector3.UP * sin(k * PI) * (2.0 + dist * 0.25)
	var tw := create_tween()
	tw.tween_method(arc, 0.0, 1.0, 0.55 + dist * 0.03)
	tw.tween_callback(func() -> void:
		if hit:
			team_pts[t] += pts
			for k2 in 4:
				if active[k2] and _team(k2) == t:
					scores[k2] = float(team_pts[t])
			FX.confetti(hoop, 30)
			FX.stars(hoop, Color(1, 0.95, 0.5), 16)
			Audio.sfx("star", hoop)
			Juice.float_text(self, hoop + Vector3.UP * 1.5, "+%d" % pts, TEAM_COLORS[t].lightened(0.3), 120)
			av.rig.react("cheer")
			stars.erase(st)
			n.queue_free()
		else:
			Audio.sfx("boing", n.position, -4.0)
			st.erase("fly")
			st.holder = -1
			n.position = Vector3(clampf(n.position.x, -HALF_X + 1, HALF_X - 1), 0.7, clampf(n.position.z, -HALF_Z + 1, HALF_Z - 1)))


func _shove(i: int) -> void:
	var av := avatars[i] as PartyAvatar
	av.rig.play("punch", 0.05, 1.5, true)
	for j in active_slots():
		if j == i or _team(j) == _team(i):
			continue
		var o := avatars[j] as PartyAvatar
		if o.global_position.distance_to(av.global_position) < 2.0:
			o.apply_knockback(o.global_position - av.global_position, 10.0, 0.6, 4.0)
			if carry[j] >= 0:
				var st := _star(carry[j])
				carry[j] = -1
				if not st.is_empty():
					st.holder = -1
					(st.node as Node3D).position = o.global_position + Vector3(randf_range(-1.5, 1.5), 0.7, randf_range(-1.5, 1.5))
			Audio.sfx("punch", o.global_position)
			FX.stars(o.global_position + Vector3.UP * 1.6, Color(1, 1, 0.6), 6)


func team_result() -> int:
	if team_pts[0] == team_pts[1]:
		return -1
	return 0 if team_pts[0] > team_pts[1] else 1


func net_pack() -> Dictionary:
	var d := super.net_pack()
	var st: Array = []
	for s in stars:
		var p := (s.node as Node3D).position
		st.append([int(s.id), snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)])
	d["st"] = st
	d["tp"] = team_pts
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var src: Array = d.get("st", [])
	var ids: Array = src.map(func(e: Array) -> int: return int(e[0]))
	for s in stars.duplicate():
		if not (int(s.id) in ids):
			(s.node as Node3D).queue_free()
			stars.erase(s)
	for e in src:
		var s := _star(int(e[0]))
		if s.is_empty():
			var n := Assets.spawn("plat/star", world, Vector3.ZERO, 0.0, 1.8)
			Assets.tint(n, Color(1.15, 1.05, 0.6), false, 0.5)
			s = {"id": int(e[0]), "node": n, "holder": -1}
			stars.append(s)
		(s.node as Node3D).position = Vector3(float(e[1]), float(e[2]), float(e[3]))
	team_pts = d.get("tp", team_pts)


func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	var level: int = Game.players[slot].cpu_level
	var pos := av.global_position
	var held := {}
	var mv := Vector2.ZERO
	var t := _team(slot)
	if carry[slot] >= 0:
		var hoop: Vector3 = _hoops[1 - t]
		var to := Vector2(hoop.x - pos.x, hoop.z - pos.z)
		mv = to.normalized()
		if to.length() < [4.0, 5.5, 7.5][level] and randf() < 0.1:
			held["b"] = true
	else:
		var best := Vector3.INF
		for st in stars:
			if int(st.holder) == -1 and not st.has("fly"):
				var p: Vector3 = (st.node as Node3D).position
				if best == Vector3.INF or p.distance_to(pos) < best.distance_to(pos):
					best = p
		for j in active_slots():
			if _team(j) != t and carry[j] >= 0:
				var op := (avatars[j] as Node3D).global_position
				if op.distance_to(pos) < 6.0 and level > 0:
					best = op
					if op.distance_to(pos) < 1.8:
						held["b"] = true
		if best != Vector3.INF:
			mv = Vector2(best.x - pos.x, best.z - pos.z).normalized()
	InputHub.set_virtual(slot, mv * [0.8, 0.92, 1.0][level], held)
