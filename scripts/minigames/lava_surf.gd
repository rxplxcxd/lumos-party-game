extends MinigameBase
## Lavastrom-Surfen: Jeder steht auf einem kleinen Floß im Lavastrom. Edelsteine treiben heran,
## Felsen und Feuer-Geysire wollen ausgewichen (oder übersprungen) werden. Mit dem Boxhandschuh
## (B) schubst man Gegner weg – die verlieren dabei einen Edelstein. Wer hinten aus dem Bild
## treibt, stürzt den Lavafall hinunter!

const HALF_W := 6.4
const FRONT_Z := -6.0
const BACK_Z := 6.5
const FLOW := 2.6
const ITEM_SPEED := 7.0

var rafts: Array[Dictionary] = []
var items: Array[Dictionary] = []
var decor: Array[Node3D] = []
var _spawn_t := 0.0
var _decor_t := 0.0
var _lava: MeshInstance3D


func _init() -> void:
	game_id = "lava_surf"
	env_preset = "volcano"
	time_limit = 40.0
	arena_radius = 9.0
	cannon_pos = Vector3(-10, 0.5, 2)
	spawn_points = [Vector3(-4.5, 0, 0), Vector3(-1.5, 0, 0), Vector3(1.5, 0, 0), Vector3(4.5, 0, 0)]


func build_arena() -> void:
	_lava = WorldKit.lava(world, Vector2(18, 90), 0.0, Vector2(0, -0.6))
	_lava.position.z = -20
	for side in [-1.0, 1.0]:
		WorldKit.box(world, Vector3(8, 3, 90), Vector3(side * (HALF_W + 4.8), 0.5, -20), Color(0.22, 0.12, 0.1), false)
	# Lavafall hinten
	var fall := WorldKit.lava(world, Vector2(18, 12), -6.0, Vector2(0, 1.8))
	fall.rotation.x = deg_to_rad(-80)
	fall.position = Vector3(0, -5.5, BACK_Z + 2.5)
	WorldKit.place(world, "space/rock_crystals", Vector3(-12, 1.5, -30), 0.0, 4.0)
	WorldKit.place(world, "space/rock_crystals_b", Vector3(13, 1.5, -40), 0.0, 4.0)
	WorldKit.place(world, "space/meteor", Vector3(0, 18, -60), 0.0, 8.0)


func spawn_players() -> void:
	for i in 4:
		var raft := Node3D.new()
		world.add_child(raft)
		raft.position = spawn_points[i]
		var plat := Assets.spawn("pirate/platform", raft, Vector3(0, -0.1, 0), 0.0, 1.0)
		plat.scale = Vector3(1.0, 1.0, 1.0)
		var rig := CharacterRig.new()
		raft.add_child(rig)
		rig.setup(Game.hero(Game.players[i].hero).model, i, 0.75)
		rig.position.y = 0.15
		rig.surface = "wood"
		rig.face_now(Vector3(0, 0, -1))
		rig.play("block" if rig.has_clip("block") else "idle")
		var glove := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.32
		sm.height = 0.6
		sm.material = WorldKit.mat(Color("#e8364f"), 0.4)
		glove.mesh = sm
		glove.position = Vector3(0.5, 1.2, -0.4)
		raft.add_child(glove)
		rafts.append({"node": raft, "rig": rig, "glove": glove, "vel": Vector2.ZERO, "hop": 0.0, "stun": 0.0,
			"punch_cd": 0.0, "punch_t": 0.0, "respawn": 0.0})
		actors[i] = raft
		rigs[i] = rig


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, -1)
	c.offset = Vector3(0, 11.5, 13.0)
	c.follow = false


func on_tick(delta: float) -> void:
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = randf_range(0.35, 0.75)
		_spawn_item()
	_decor_t -= delta
	if _decor_t <= 0.0:
		_decor_t = 0.7
		for side in [-1.0, 1.0]:
			var key: String = ["td/rocks", "td/crystal", "nat/rock_large", "space/rock_crystals"][randi() % 4]
			var d := Assets.spawn(key, world, Vector3(side * randf_range(HALF_W + 1.5, HALF_W + 5.0), 2.0, -50), randf() * 360.0, randf_range(1.5, 3.0))
			decor.append(d)
	for d in decor.duplicate():
		d.position.z += ITEM_SPEED * delta
		if d.position.z > 15:
			d.queue_free()
			decor.erase(d)
	for i in 4:
		_raft(i, delta)
	_raft_collisions()
	_update_items(delta)


func _raft(i: int, delta: float) -> void:
	var r: Dictionary = rafts[i]
	var n: Node3D = r.node
	var rig: CharacterRig = r.rig
	if r.respawn > 0.0:
		r.respawn -= delta
		if r.respawn <= 0.0:
			n.position = Vector3(spawn_points[i].x, 0, 0)
			n.visible = true
			Juice.pop_in(n, 0.4)
			FX.stars(n.position + Vector3.UP, Color.WHITE, 8)
		return
	r.stun = maxf(0.0, r.stun - delta)
	r.punch_cd = maxf(0.0, r.punch_cd - delta)
	var mv := InputHub.move(i) if r.stun <= 0.0 else Vector2.ZERO
	var vel: Vector2 = r.vel
	vel = vel.lerp(mv * 7.5, clampf(delta * 3.0, 0, 1))
	vel.y += FLOW * delta * 2.2
	var pos := Vector2(n.position.x, n.position.z) + vel * delta
	if absf(pos.x) > HALF_W:
		pos.x = signf(pos.x) * HALF_W
		vel.x *= -0.5
	if pos.y < FRONT_Z:
		pos.y = FRONT_Z
		vel.y = maxf(vel.y, 0.0)
	r.vel = vel
	n.position.x = pos.x
	n.position.z = pos.y
	# Hüpfen
	if r.hop <= 0.0 and r.stun <= 0.0 and InputHub.pressed(i, "a"):
		r.hop = 0.55
		rig.jump_stretch()
		Audio.sfx("jump", n.global_position, -6.0)
	var hy := 0.0
	if r.hop > 0.0:
		r.hop = maxf(0.0, r.hop - delta)
		hy = sin((1.0 - r.hop / 0.55) * PI) * 1.4
	n.position.y = hy + sin(Time.get_ticks_msec() / 300.0 + i) * 0.05
	n.rotation.z = lerpf(n.rotation.z, -vel.x * 0.03, clampf(delta * 5, 0, 1))
	n.rotation.x = lerpf(n.rotation.x, vel.y * 0.02, clampf(delta * 5, 0, 1))
	rig.set_lean(-mv.x)
	# Boxhandschuh
	var glove: Node3D = r.glove
	if r.punch_cd <= 0.0 and r.stun <= 0.0 and InputHub.pressed(i, "b"):
		r.punch_cd = 0.8
		r.punch_t = 0.25
		rig.play("punch", 0.05, 1.6, true)
		rig.lock(0.35)
		Audio.sfx("whoosh", n.global_position, -6.0)
		_punch(i)
	if r.punch_t > 0.0:
		r.punch_t = maxf(0.0, r.punch_t - delta)
		glove.position = Vector3(0.5, 1.2, -0.4 - sin((1.0 - r.punch_t / 0.25) * PI) * 1.6)
	if pos.y > BACK_Z:
		_fall(i)


func _punch(i: int) -> void:
	var me: Node3D = rafts[i].node
	var best := -1
	var bd := 3.2
	for j in 4:
		if j == i or rafts[j].respawn > 0.0:
			continue
		var d := me.position.distance_to((rafts[j].node as Node3D).position)
		if d < bd:
			bd = d
			best = j
	if best < 0:
		return
	var other: Dictionary = rafts[best]
	var dir := Vector2((other.node as Node3D).position.x - me.position.x, (other.node as Node3D).position.z - me.position.z).normalized()
	other.vel = dir * 14.0
	other.stun = 0.7
	(other.rig as CharacterRig).react("hit")
	(other.node as Node3D).create_tween().tween_property(other.node, "rotation:y", (other.node as Node3D).rotation.y + TAU, 0.6)
	Audio.sfx("punch", (other.node as Node3D).global_position)
	FX.stars((other.node as Node3D).global_position + Vector3.UP * 1.6, Color(1, 1, 0.5), 10)
	Juice.hitstop(0.06)
	Juice.shake(0.2)
	InputHub.rumble(i, 0.5, 0.12)
	InputHub.rumble(best, 0.8, 0.2)
	if scores[best] > 0:
		scores[best] -= 1
		_spawn_gem((other.node as Node3D).position + Vector3(0, 0, -1.5), "diamond")
		Juice.float_text(self, (other.node as Node3D).global_position + Vector3.UP * 2.5, "-1", Color("#ff6b6b"), 90)


func _fall(i: int) -> void:
	var r: Dictionary = rafts[i]
	var n: Node3D = r.node
	Audio.sfx("whistle_fall", n.global_position)
	FX.embers(n.global_position, 20)
	FX.smoke(n.global_position, Color(0.3, 0.25, 0.25), 8)
	(r.rig as CharacterRig).set_soot(3.0)
	var lost := mini(2, int(scores[i]))
	scores[i] -= lost
	if lost > 0:
		Juice.float_text(self, n.global_position + Vector3.UP * 2.0, "-%d" % lost, Color("#ff6b6b"), 100)
	n.visible = false
	r.respawn = 1.4
	r.vel = Vector2.ZERO
	InputHub.rumble(i, 1.0, 0.3)


func _raft_collisions() -> void:
	for a in 4:
		for b in range(a + 1, 4):
			var na: Node3D = rafts[a].node
			var nb: Node3D = rafts[b].node
			if not na.visible or not nb.visible:
				continue
			var d := Vector2(nb.position.x - na.position.x, nb.position.z - na.position.z)
			if d.length() < 2.4 and d.length() > 0.01:
				var n := d.normalized()
				var push := (2.4 - d.length()) * 0.5
				na.position -= Vector3(n.x, 0, n.y) * push
				nb.position += Vector3(n.x, 0, n.y) * push
				var va: Vector2 = rafts[a].vel
				var vb: Vector2 = rafts[b].vel
				var rel := (va - vb).dot(n)
				if rel > 0:
					rafts[a].vel = va - n * rel
					rafts[b].vel = vb + n * rel


func _spawn_item() -> void:
	var r := randf()
	var x := randf_range(-HALF_W + 0.6, HALF_W - 0.6)
	if r < 0.55:
		_spawn_gem(Vector3(x, 0.4, -36), "diamond" if randf() < 0.7 else "ring")
	elif r < 0.82:
		var rock := Assets.spawn("td/rocks", world, Vector3(x, 0, -36), randf() * 360.0, 3.0)
		items.append({"node": rock, "kind": "rock", "r": 1.3})
	else:
		var g := Node3D.new()
		world.add_child(g)
		g.position = Vector3(x, 0.05, -36)
		var ring_m := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.2
		cm.bottom_radius = 1.2
		cm.height = 0.05
		cm.material = WorldKit.mat(Color(1.0, 0.5, 0.1), 0.6, 2.0)
		ring_m.mesh = cm
		g.add_child(ring_m)
		items.append({"node": g, "kind": "geyser", "r": 1.3, "t": randf_range(2.0, 3.5), "fired": false})


func _spawn_gem(pos: Vector3, kind: String) -> void:
	var gem := Assets.spawn("mg/diamond" if kind == "diamond" else "mg/ring", world, pos, 0.0, 1.6)
	Assets.tint(gem, Color(1, 1, 1), false, 0.4)
	items.append({"node": gem, "kind": kind, "r": 1.4})


func _update_items(delta: float) -> void:
	for it in items.duplicate():
		var n: Node3D = it.node
		n.position.z += ITEM_SPEED * delta
		if it.kind in ["diamond", "ring"]:
			n.rotation.y += delta * 3.0
			n.position.y = 0.5 + sin(Time.get_ticks_msec() / 200.0 + n.position.x) * 0.15
		if it.kind == "geyser":
			it.t = float(it.t) - delta
			if it.t <= 0.0 and not it.fired:
				it.fired = true
				Audio.sfx("thruster", n.global_position)
				FX.burst(n.global_position, {"amount": 40, "life": 0.9, "spread": 8.0, "vel_min": 10.0, "vel_max": 14.0,
					"gravity": Vector3(0, -9, 0), "size": 0.9, "additive": true, "radius": 0.6,
					"ramp": FX._ramp(Color(1, 0.9, 0.4, 1), Color(1, 0.2, 0, 0))})
				Juice.shake(0.12)
		for i in 4:
			var raft: Node3D = rafts[i].node
			if not raft.visible:
				continue
			var d := Vector2(raft.position.x - n.position.x, raft.position.z - n.position.z).length()
			if d > float(it.r) + 0.9:
				continue
			match it.kind:
				"diamond", "ring":
					var pts := 1 if it.kind == "diamond" else 2
					add_score(i, pts, n.global_position + Vector3.UP * 1.5)
					Audio.sfx("coin_single", n.global_position, 0.0, 1.0 + pts * 0.1)
					FX.stars(n.global_position, Color(0.6, 0.9, 1.0), 8)
					InputHub.rumble(i, 0.25, 0.08)
					items.erase(it)
					n.queue_free()
					break
				"rock":
					if raft.position.y < 0.6 and rafts[i].stun <= 0.0:
						rafts[i].vel = Vector2(signf(raft.position.x - n.position.x) * 6.0, 6.0)
						rafts[i].stun = 0.6
						(rafts[i].rig as CharacterRig).react("hit")
						Audio.sfx("stone_hit", n.global_position)
						Juice.shake(0.15)
				"geyser":
					if it.fired and float(it.t) > -0.8 and raft.position.y < 0.8 and rafts[i].stun <= 0.0:
						rafts[i].stun = 1.0
						(rafts[i].rig as CharacterRig).react("soot_blast")
						rafts[i].vel = Vector2(0, 5.0)
						if scores[i] > 0:
							scores[i] -= 1
							Juice.float_text(self, raft.global_position + Vector3.UP * 2.5, "-1", Color("#ff6b6b"), 90)
		if n.position.z > 14.0 and is_instance_valid(n):
			items.erase(it)
			n.queue_free()


# --- CPU ---------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var r: Dictionary = rafts[slot]
	var n: Node3D = r.node
	if not n.visible:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var target := Vector2(n.position.x, -1.5)
	var best := INF
	var held := {}
	for it in items:
		var ip: Vector3 = (it.node as Node3D).position
		if ip.z > n.position.z + 0.5:
			continue
		var dz := n.position.z - ip.z
		if it.kind in ["diamond", "ring"]:
			var score := absf(ip.x - n.position.x) + dz * 0.3 - (2.0 if it.kind == "ring" else 0.0)
			if score < best and dz < 18.0:
				best = score
				target = Vector2(ip.x, clampf(ip.z + 6.0, FRONT_Z, 2.0))
		elif dz < 2.6 and absf(ip.x - n.position.x) < 2.0:
			if level > 0 and randf() < 0.5 + 0.2 * level:
				held["a"] = true
			else:
				target.x = n.position.x + (3.0 if ip.x < n.position.x else -3.0)
	var to := target - Vector2(n.position.x, n.position.z)
	if n.position.z > 3.0:
		to.y = -3.0
	for j in 4:
		if j != slot and (rafts[j].node as Node3D).visible and n.position.distance_to((rafts[j].node as Node3D).position) < 2.8 and randf() < 0.03 * (level + 1):
			held["b"] = true
	InputHub.set_virtual(slot, to.normalized() * clampf(to.length() / 2.0, 0.3, 1.0) if to.length() > 0.2 else Vector2.ZERO, held)
