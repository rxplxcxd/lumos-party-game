extends MinigameBase
## Farb-Chaos: Jedes Feld, über das du läufst, nimmt deine Farbe an. Farbbomben (Eimer) färben
## einen 5x5-Bereich auf einen Schlag. Schubsen (B) betäubt kurz. Wer am Ende die meisten Felder hat, gewinnt.

const N := 14
const TILE := 1.4
const NEUTRAL := Color("#e8e2d6")

var owner_of: PackedInt32Array = PackedInt32Array()
var tiles: Array[MeshInstance3D] = []
var mats: Array[StandardMaterial3D] = []
var bombs: Array[Dictionary] = []
var _bomb_t := 4.0
var _half := N * TILE * 0.5


func _init() -> void:
	game_id = "color_chaos"
	env_preset = "day"
	time_limit = 40.0
	arena_radius = 11.0
	cannon_pos = Vector3(0, 0, 13)
	var h := N * TILE * 0.5 - 2.0
	spawn_points = [Vector3(-h, 0.5, -h), Vector3(h, 0.5, -h), Vector3(-h, 0.5, h), Vector3(h, 0.5, h)]


func build_arena() -> void:
	WorldKit.box(world, Vector3(N * TILE + 1.0, 1.0, N * TILE + 1.0), Vector3(0, -0.52, 0), Color("#8a8070"))
	for side in [-1.0, 1.0]:
		WorldKit.box(world, Vector3(0.6, 0.8, N * TILE + 1.6), Vector3(side * (_half + 0.6), 0.4, 0), Color("#ff6fb5"))
		WorldKit.box(world, Vector3(N * TILE + 1.6, 0.8, 0.6), Vector3(0, 0.4, side * (_half + 0.6)), Color("#6fd0ff"))
	var m0 := WorldKit.mat(NEUTRAL, 0.7)
	mats.append(m0)
	for i in 4:
		var m := WorldKit.mat(Game.player_color(i).lightened(0.1), 0.55, 0.25)
		mats.append(m)
	var bm := BoxMesh.new()
	bm.size = Vector3(TILE * 0.94, 0.08, TILE * 0.94)
	owner_of.resize(N * N)
	owner_of.fill(-1)
	for z in N:
		for x in N:
			var mi := MeshInstance3D.new()
			mi.mesh = bm
			mi.material_override = m0
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			world.add_child(mi)
			mi.position = _tile_pos(x, z)
			tiles.append(mi)
	# Kulisse: Farbtöpfe, Spielplatz-Deko
	for i in 12:
		var a := TAU * i / 12.0
		var pos := Vector3(cos(a), 0, sin(a)) * (_half + 4.0)
		WorldKit.place(world, ["plat/flowers", "mg/tree_forest", "plat/mushrooms", "arcade/prizes"][i % 4], pos, rad_to_deg(-a), 1.8)
	for c in [Vector3(-_half - 2, 0, -_half - 2), Vector3(_half + 2, 0, -_half - 2), Vector3(-_half - 2, 0, _half + 2), Vector3(_half + 2, 0, _half + 2)]:
		WorldKit.place(world, "plat/barrel", c, randf() * 360.0, 2.0)


func _tile_pos(x: int, z: int) -> Vector3:
	return Vector3(-_half + TILE * (x + 0.5), 0.04, -_half + TILE * (z + 0.5))


func _tile_at(p: Vector3) -> Vector2i:
	return Vector2i(int(floor((p.x + _half) / TILE)), int(floor((p.z + _half) / TILE)))


func on_start() -> void:
	for av in avatars:
		var a := av as PartyAvatar
		a.rig.surface = "slime"
		a.shoved.connect(func(_by: PartyAvatar, victim: PartyAvatar) -> void: victim.stun(0.9))
	for i in 4:
		var t := _tile_at((avatars[i] as Node3D).global_position)
		_paint_area(t, 1, i, false)


func _paint(t: Vector2i, slot: int, pop := true) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= N or t.y >= N:
		return false
	var idx := t.y * N + t.x
	if owner_of[idx] == slot:
		return false
	var prev := owner_of[idx]
	owner_of[idx] = slot
	var mi := tiles[idx]
	mi.material_override = mats[slot + 1]
	if prev >= 0:
		scores[prev] -= 1
	scores[slot] += 1
	if pop:
		var tw := mi.create_tween()
		mi.scale = Vector3(1.15, 3.0, 1.15)
		tw.tween_property(mi, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return true


func _paint_area(center: Vector2i, r: int, slot: int, pop := true) -> int:
	var n := 0
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if _paint(center + Vector2i(dx, dz), slot, pop):
				n += 1
	return n


func on_tick(delta: float) -> void:
	for i in 4:
		var av := avatars[i] as PartyAvatar
		if av.is_on_floor() and _paint(_tile_at(av.global_position), i):
			if randf() < 0.3:
				Audio.sfx("slime", av.global_position, -16.0, 1.4)
	_bomb_t -= delta
	if _bomb_t <= 0.0 and bombs.size() < 3:
		_bomb_t = randf_range(3.5, 6.0)
		var t := Vector2i(randi_range(1, N - 2), randi_range(1, N - 2))
		var p := _tile_pos(t.x, t.y)
		var node := Assets.spawn("mg/powerup_bomb", world, p + Vector3.UP * 0.6, 0.0, 1.1)
		Assets.tint(node, Color(1.2, 0.6, 1.4), false, 0.5)
		Juice.pop_in(node, 0.35)
		FX.ring(p + Vector3.UP * 0.1, Color(1, 0.5, 1, 0.9), 2.0, 0.4)
		bombs.append({"node": node, "tile": t})
	for b in bombs.duplicate():
		var n: Node3D = b.node
		n.rotation.y += delta * 2.5
		n.position.y = 0.6 + sin(Time.get_ticks_msec() / 200.0) * 0.15
		for i in 4:
			var av := avatars[i] as PartyAvatar
			if Vector2(av.global_position.x - n.position.x, av.global_position.z - n.position.z).length() < 1.0:
				var cnt := _paint_area(b.tile, 2, i)
				FX.explosion(n.position, 0.5, false)
				FX.confetti(n.position, 40)
				Audio.sfx("pop", n.position, 0.0)
				Audio.sfx("slime", n.position, -2.0, 0.8)
				Juice.float_text(self, n.position + Vector3.UP * 2.0, "+%d" % cnt, Game.player_color(i).lightened(0.3), 110)
				Juice.shake(0.15)
				av.rig.react("triumph")
				bombs.erase(b)
				n.queue_free()
				break


func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	var level: int = Game.players[slot].cpu_level
	var mem := cpu_mem[slot]
	var pos := av.global_position
	var held := {}
	var goal: Vector3 = mem.get("goal", Vector3.INF)
	mem["t"] = float(mem.get("t", 0.0)) - get_physics_process_delta_time()
	# Farbbombe in der Nähe hat Vorrang
	for b in bombs:
		var bn: Node3D = b.node
		if pos.distance_to(bn.position) < 4.0 + level * 3.0:
			goal = bn.position
			mem["t"] = 0.3
	if goal == Vector3.INF or float(mem.t) <= 0.0 or Vector2(goal.x - pos.x, goal.z - pos.z).length() < 0.6:
		# bestes Ziel: fremdes/neutrales Feld mit vielen fremden Nachbarn, nicht zu weit weg
		var here := _tile_at(pos)
		var best_s := -INF
		for _k in 14:
			var t := here + Vector2i(randi_range(-5, 5), randi_range(-5, 5))
			if t.x < 0 or t.y < 0 or t.x >= N or t.y >= N:
				continue
			var s := 0.0
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var q := t + Vector2i(dx, dz)
					if q.x >= 0 and q.y >= 0 and q.x < N and q.y < N:
						var o := owner_of[q.y * N + q.x]
						s += 0.0 if o == slot else (1.5 if o >= 0 else 1.0)
			s -= Vector2(t - here).length() * 0.35
			if s > best_s:
				best_s = s
				goal = _tile_pos(t.x, t.y)
		mem["t"] = randf_range(0.8, 1.6)
	mem["goal"] = goal
	var mv := Vector2(goal.x - pos.x, goal.z - pos.z)
	mv = mv.normalized() if mv.length() > 0.3 else Vector2.ZERO
	for o in avatars:
		var oa := o as PartyAvatar
		if oa != av and oa.global_position.distance_to(pos) < 1.7 and randf() < 0.02 * (level + 1):
			held["b"] = true
	InputHub.set_virtual(slot, mv * [0.8, 0.92, 1.0][level], held)
