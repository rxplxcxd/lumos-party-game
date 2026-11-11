extends MinigameBase
## Münzregen: Vom Himmel regnet es Münzen (+1), selten Sterne (+5) – und Bomben! Schatten zeigen,
## wo etwas landet. Schubsen (B) lässt Gegner zwei Münzen verlieren.

const HALF := 8.0

var drops: Array[Dictionary] = []
var _spawn_t := 0.6


func _init() -> void:
	game_id = "coin_rain"
	env_preset = "day"
	time_limit = 40.0
	arena_radius = 10.0
	cannon_pos = Vector3(0, 0, 12)
	spawn_points = [Vector3(-3, 0.5, -3), Vector3(3, 0.5, -3), Vector3(-3, 0.5, 3), Vector3(3, 0.5, 3)]


func build_arena() -> void:
	# Grasblöcke exakt bündig: Oberkante = y 0, Raster = Modellbreite
	var bb := Assets.model_aabb("plat/block_grass_large")
	var step := maxf(bb.size.x, 1.0)
	var tiles: Array = []
	var n := int(ceil((HALF * 2.0 + 2.0) / step))
	for x in n:
		for z in n:
			var px := -HALF - 1.0 + step * (x + 0.5)
			var pz := -HALF - 1.0 + step * (z + 0.5)
			tiles.append(Transform3D(Basis(), Vector3(px - bb.get_center().x, -bb.end.y, pz - bb.get_center().z)))
	WorldKit.multimesh(world, "plat/block_grass_large", tiles)
	WorldKit.box(world, Vector3(HALF * 2 + 2, 1, HALF * 2 + 2), Vector3(0, -0.52, 0), Color("#5aa83e")).visible = false
	for i in 16:
		var a := TAU * i / 16.0
		var p := Vector3(cos(a), 0, sin(a)) * (HALF + 2.5)
		WorldKit.place(world, ["plat/fence", "plat/flowers", "plat/tree", "nat/bush"][i % 4], p, rad_to_deg(-a), 2.0)
	for side in [-1.0, 1.0]:
		var wall := WorldKit.box(world, Vector3(0.4, 2, HALF * 2 + 2), Vector3(side * (HALF + 0.9), 1, 0), Color(1, 1, 1, 0))
		wall.visible = false
		var wall2 := WorldKit.box(world, Vector3(HALF * 2 + 2, 2, 0.4), Vector3(0, 1, side * (HALF + 0.9)), Color(1, 1, 1, 0))
		wall2.visible = false
	WorldKit.place(world, "castle/tower", Vector3(-12, 0, -12), 0.0, 4.0)
	WorldKit.place(world, "town/windmill", Vector3(13, 0, -11), -30.0, 2.6)


func on_start() -> void:
	for av in avatars:
		(av as PartyAvatar).rig.surface = "grass"
		(av as PartyAvatar).shoved.connect(_on_shoved)


func on_tick(delta: float) -> void:
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = lerpf(0.18, 0.45, time_left / time_limit)
		_spawn_drop()
	for d in drops.duplicate():
		var n: Node3D = d.node
		if d.state == "fall":
			d.y = float(d.y) - float(d.speed) * delta
			n.position.y = float(d.y)
			var sh: MeshInstance3D = d.shadow
			sh.scale = Vector3.ONE * clampf(1.3 - float(d.y) / 14.0, 0.3, 1.2)
			if float(d.y) <= 0.4:
				_land(d)
		else:
			n.rotation.y += delta * 3.0
			d.life = float(d.life) - delta
			if d.life <= 0.0:
				_remove(d)
				continue
			for i in 4:
				var av := avatars[i] as PartyAvatar
				if av.alive and Vector2(av.global_position.x - n.position.x, av.global_position.z - n.position.z).length() < 1.1:
					_collect(i, d)
					break


func _spawn_drop() -> void:
	var r := randf()
	var kind := "coin"
	if r < 0.07:
		kind = "star"
	elif r < 0.22 + (1.0 - time_left / time_limit) * 0.12:
		kind = "bomb"
	var pos := Vector3(randf_range(-HALF + 0.8, HALF - 0.8), 14.0, randf_range(-HALF + 0.8, HALF - 0.8))
	var node: Node3D
	match kind:
		"star":
			node = Assets.spawn("plat/star", world, pos, 0.0, 2.6)
		"bomb":
			node = Assets.spawn("mg/powerup_bomb", world, pos, 0.0, 1.0)
		_:
			node = Assets.spawn("plat/coin", world, pos, 0.0, 2.0)
	var shadow := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.4, 1.4)
	q.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = FX.tex_soft
	m.albedo_color = Color(1, 0.2, 0.1, 0.7) if kind == "bomb" else Color(0, 0, 0, 0.45)
	q.material = m
	shadow.mesh = q
	world.add_child(shadow)
	shadow.position = Vector3(pos.x, 0.05, pos.z)
	drops.append({"node": node, "shadow": shadow, "kind": kind, "state": "fall", "y": pos.y, "speed": randf_range(9.0, 13.0), "life": 4.0})


func _land(d: Dictionary) -> void:
	var n: Node3D = d.node
	d.state = "ground"
	n.position.y = 0.4
	(d.shadow as Node3D).queue_free()
	if d.kind == "bomb":
		FX.explosion(n.position, 0.7)
		for i in 4:
			var av := avatars[i] as PartyAvatar
			var dd := av.global_position - n.position
			dd.y = 0
			if av.alive and dd.length() < 2.6:
				av.apply_knockback(dd.normalized(), 14.0, 0.9, 6.0)
				av.rig.set_soot(2.5)
				_lose(i, 3)
		_remove(d)
	else:
		Juice.squash(n, 1.3, 0.7, 0.3, n.scale)
		FX.dust(n.position, Color(1, 1, 0.8), 4, 0.5)
		Audio.sfx("coin_single", n.position, -10.0)


func _collect(i: int, d: Dictionary) -> void:
	var n: Node3D = d.node
	var pts := 5 if d.kind == "star" else 1
	add_score(i, pts, n.position + Vector3.UP * 2.0)
	FX.stars(n.position + Vector3.UP, Color(1, 0.9, 0.3), 6 if pts == 1 else 16)
	Audio.sfx("star" if pts > 1 else "coin_single", n.position, -2.0, 1.0 + randf() * 0.2)
	if pts > 1:
		(avatars[i] as PartyAvatar).rig.react("coin_gain")
	_remove(d)


func _lose(i: int, amount: int) -> void:
	var lost := mini(amount, int(scores[i]))
	if lost <= 0:
		return
	scores[i] -= lost
	var p := (avatars[i] as Node3D).global_position
	Juice.float_text(self, p + Vector3.UP * 2.6, "-%d" % lost, Color("#ff6b6b"), 100)
	for _k in lost:
		var n := Assets.spawn("plat/coin", world, p + Vector3(randf_range(-2, 2), 0.4, randf_range(-2, 2)), 0.0, 2.0)
		n.position.x = clampf(n.position.x, -HALF, HALF)
		n.position.z = clampf(n.position.z, -HALF, HALF)
		Juice.pop_in(n, 0.3)
		drops.append({"node": n, "shadow": null, "kind": "coin", "state": "ground", "y": 0.4, "speed": 0.0, "life": 4.0})


func _on_shoved(_by: PartyAvatar, victim: PartyAvatar) -> void:
	_lose(victim.slot, 2)


func _remove(d: Dictionary) -> void:
	drops.erase(d)
	if is_instance_valid(d.node):
		(d.node as Node3D).queue_free()
	if d.shadow and is_instance_valid(d.shadow):
		(d.shadow as Node3D).queue_free()


func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	var level: int = Game.players[slot].cpu_level
	var pos := av.global_position
	var best := Vector3.INF
	var best_s := INF
	var flee := Vector3.ZERO
	for d in drops:
		var n: Node3D = d.node
		var p := Vector3(n.position.x, 0, n.position.z)
		var dist := Vector2(p.x - pos.x, p.z - pos.z).length()
		if d.kind == "bomb":
			if dist < 3.2 and float(d.y) < 9.0:
				flee += (pos - p).normalized() * (3.2 - dist)
			continue
		var t_land: float = maxf(0.0, (float(d.y) - 0.4) / maxf(float(d.speed), 0.1)) if d.state == "fall" else 0.0
		var score := dist / 7.0 - t_land * 0.3 - (3.0 if d.kind == "star" else 0.0) + randf() * (1.5 - level * 0.5)
		if score < best_s:
			best_s = score
			best = p
	var mv := Vector2.ZERO
	if flee.length() > 0.1 and level > 0:
		mv = Vector2(flee.x, flee.z).normalized()
	elif best != Vector3.INF:
		mv = Vector2(best.x - pos.x, best.z - pos.z)
		mv = mv.normalized() if mv.length() > 0.2 else Vector2.ZERO
	var held := {}
	for o in avatars:
		var oa := o as PartyAvatar
		if oa != av and oa.global_position.distance_to(pos) < 1.6 and randf() < 0.03 * mini(level + 1, 3):
			held["b"] = true
	InputHub.set_virtual(slot, mv * Game.lv([0.8, 0.92, 1.0], level), held)
