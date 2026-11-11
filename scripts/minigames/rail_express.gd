extends MinigameBase
## Schienen-Express (2 gegen 2): Jedes Team fährt eine quietschbunte Lore. Vorne sitzt der Pumper
## (A hämmern = Tempo), hinten der Springer (A = die Lore hüpft über Schranken). Wer eine Schranke rammt,
## kullert zurück. Erstes Team im Ziel-Bahnhof gewinnt. Online: Host-Modell.

const LENGTH := 90.0
const TRACK_Z := [-2.6, 2.6]

var carts: Array[Dictionary] = []
var barriers: Array[float] = []
var _done := false
var _cart_nodes: Array[Node3D] = []


func _init() -> void:
	game_id = "rail_express"
	env_preset = "day"
	time_limit = 50.0
	race = true
	arena_radius = 12.0
	teaser_height = 1.0
	cannon_pos = Vector3(-6, 0, 12)
	touch_profile = "action_only"
	net_model = "host"


func on_setup() -> void:
	carts.clear()
	for t in 2:
		var members: Array[int] = []
		for i in 4:
			if teams[i] == t and active[i]:
				members.append(i)
		carts.append({"x": 0.0, "v": 0.0, "air": 0.0, "stun": 0.0, "pump": members[0] if members.size() > 0 else -1,
			"jump": members[1] if members.size() > 1 else (members[0] if members.size() > 0 else -1)})


func build_arena() -> void:
	WorldKit.box(world, Vector3(LENGTH + 40, 1, 22), Vector3(LENGTH * 0.5, -0.5, 0), Color("#8fd16a"))
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 4242
	var x := 12.0
	while x < LENGTH - 6.0:
		barriers.append(x)
		x += rng2.randf_range(8.0, 13.0)
	for t in 2:
		var z: float = TRACK_Z[t]
		for side in [-0.6, 0.6]:
			var rail := WorldKit.box(world, Vector3(LENGTH + 20, 0.12, 0.12), Vector3(LENGTH * 0.5, 0.1, z + side), Color("#8a8f99"), false)
			rail.name = "Rail"
		var xs := -8.0
		while xs < LENGTH + 10.0:
			WorldKit.box(world, Vector3(0.4, 0.1, 1.8), Vector3(xs, 0.04, z), Color("#9a6a3a"), false)
			xs += 1.2
		for bx in barriers:
			var b := Node3D.new()
			world.add_child(b)
			b.position = Vector3(bx, 0, z)
			var bar := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.2, 0.2, 2.0)
			var g := Gradient.new()
			g.set_color(0, Color("#ff6b6b"))
			g.set_color(1, Color("#ffffff"))
			g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
			var gt := GradientTexture1D.new()
			gt.gradient = g
			var m := StandardMaterial3D.new()
			m.albedo_texture = gt
			m.uv1_scale = Vector3(4, 1, 1)
			bm.material = m
			bar.mesh = bm
			bar.position.y = 0.75
			b.add_child(bar)
			for sz in [-1.1, 1.1]:
				WorldKit.cylinder(b, 0.08, 1.0, Vector3(0, 0.5, sz), Color("#f4f4f4"), false)
		var cart := Node3D.new()
		world.add_child(cart)
		var body := WorldKit.box(cart, Vector3(2.2, 0.8, 1.5), Vector3(0, 0.75, 0), Color("#ffb3c7") if t == 0 else Color("#a8dcff"), false)
		body.name = "Body"
		for wx in [-0.7, 0.7]:
			for wz in [-0.6, 0.6]:
				var wheel := WorldKit.cylinder(cart, 0.28, 0.12, Vector3(wx, 0.3, wz), Color("#5a5a66"), false)
				wheel.rotation.x = PI * 0.5
		var lever := WorldKit.box(cart, Vector3(0.12, 0.9, 0.12), Vector3(0.6, 1.5, 0), Color("#ffd23f"), false)
		lever.name = "Lever"
		cart.position = Vector3(0, 0, z)
		_cart_nodes.append(cart)
	# Bahnhof am Ziel
	WorldKit.place(world, "toy/gate_finish", Vector3(LENGTH, 0, 0), 90.0, 4.0)
	WorldKit.cottage(world, Vector3(LENGTH + 8, 0, -6), -90.0, 1.5, Color("#fff1d8"), Color("#ff8a8a"))
	for i in 14:
		var px := -6.0 + i * 8.0
		WorldKit.place(world, ["plat/tree", "plat/flowers", "nat/tree_oak", "plat/fence"][i % 4], Vector3(px, 0, -8.0 if i % 2 == 0 else 8.0), randf() * 360.0, 2.0)


func setup_camera(c: ArenaCamera) -> void:
	c.targets = _cart_nodes
	c.offset = Vector3(-2, 9, 13)
	c.min_dist = 1.0
	c.max_dist = 1.2


func on_start() -> void:
	for i in 4:
		var av := avatars[i] as PartyAvatar
		av.can_move = false
		av.can_jump = false
		av.can_shove = false
		av.set_physics_process(false)
		av.rig.play("sit_chair")
	_place_riders()


func _place_riders() -> void:
	for t in 2:
		var c: Dictionary = carts[t]
		var cn := _cart_nodes[t]
		if int(c.pump) >= 0:
			var p := avatars[int(c.pump)] as PartyAvatar
			p.global_position = cn.global_position + Vector3(0.45, 1.05, 0)
			p.rig.rotation.y = -PI * 0.5
		if int(c.jump) >= 0 and int(c.jump) != int(c.pump):
			var j := avatars[int(c.jump)] as PartyAvatar
			j.global_position = cn.global_position + Vector3(-0.55, 1.05, 0)
			j.rig.rotation.y = -PI * 0.5


func on_tick(delta: float) -> void:
	if _done:
		return
	for t in 2:
		var c: Dictionary = carts[t]
		c.stun = maxf(0.0, float(c.stun) - delta)
		c.air = maxf(0.0, float(c.air) - delta)
		var pump := int(c.pump)
		var jump := int(c.jump)
		if pump >= 0 and float(c.stun) <= 0.0 and InputHub.pressed(pump, "a"):
			c.v = minf(float(c.v) + 1.15, 13.0)
			(avatars[pump] as PartyAvatar).rig.squash(1.1, 0.9, 0.12)
			var lev := _cart_nodes[t].get_node("Lever") as Node3D
			lev.rotation.z = 0.5 if lev.rotation.z < 0.0 else -0.5
			Audio.sfx("creak", _cart_nodes[t].global_position, -14.0, 1.6)
		if jump >= 0 and jump != pump and float(c.air) <= 0.0 and InputHub.pressed(jump, "a"):
			c.air = 0.55
			Audio.sfx("jump", _cart_nodes[t].global_position, -6.0)
		elif jump == pump and pump >= 0 and float(c.air) <= 0.0 and InputHub.pressed(pump, "b"):
			c.air = 0.55
		c.v = move_toward(float(c.v), 0.0, delta * 2.6)
		var old_x := float(c.x)
		c.x = old_x + float(c.v) * delta
		for bx in barriers:
			if old_x + 1.1 < bx and float(c.x) + 1.1 >= bx and float(c.air) <= 0.08:
				c.x = bx - 1.2
				c.v = -3.0
				c.stun = 0.7
				Audio.sfx("wood_hit", _cart_nodes[t].global_position)
				FX.stars(_cart_nodes[t].global_position + Vector3.UP * 2.0, Color(1, 0.9, 0.4), 10)
				Juice.shake(0.15)
				for i in 4:
					if teams[i] == t and active[i]:
						(avatars[i] as PartyAvatar).rig.react("hit")
		if float(c.x) >= LENGTH:
			_finish(t)
			return
	_apply_visuals()


func _apply_visuals() -> void:
	for t in 2:
		var c: Dictionary = carts[t]
		var air := float(c.air)
		_cart_nodes[t].position = Vector3(float(c.x), (sin(air / 0.55 * PI) * 1.4) if air > 0.0 else 0.0, TRACK_Z[t])
		_cart_nodes[t].rotation.z = -0.15 if air > 0.0 else 0.0
	_place_riders()
	for i in 4:
		scores[i] = float(carts[teams[i]].x) if active[i] and teams[i] < 2 else 0.0


func _finish(t: int) -> void:
	_done = true
	for i in 4:
		if active[i] and teams[i] == t:
			finish_order.append(i)
			(avatars[i] as PartyAvatar).rig.react("victory")
	Audio.sfx("bell")
	FX.confetti(_cart_nodes[t].global_position + Vector3.UP * 3.0, 60)
	await get_tree().create_timer(0.8, false).timeout
	end_game()


func team_result() -> int:
	if not finish_order.is_empty():
		return teams[finish_order[0]]
	return 0 if float(carts[0].x) > float(carts[1].x) else 1


func net_pack() -> Dictionary:
	return {"c": [[snappedf(float(carts[0].x), 0.01), snappedf(float(carts[0].air), 0.01)], [snappedf(float(carts[1].x), 0.01), snappedf(float(carts[1].air), 0.01)]]}


func net_unpack(d: Dictionary) -> void:
	var c: Array = d.get("c", [])
	for t in mini(2, c.size()):
		carts[t].x = float(c[t][0])
		carts[t].air = float(c[t][1])
	_apply_visuals()


func cpu_think(slot: int, _delta: float) -> void:
	var level: int = Game.players[slot].cpu_level
	var t := teams[slot]
	if t > 1:
		return
	var c: Dictionary = carts[t]
	var held := {}
	var mem := cpu_mem[slot]
	if int(c.pump) == slot:
		var tt := float(mem.get("t", 0.0)) - get_physics_process_delta_time()
		if tt <= 0.0:
			held["a"] = true
			tt = 1.0 / Game.lv([4.5, 6.0, 7.5], level)
		mem["t"] = tt
	if int(c.jump) == slot:
		for bx in barriers:
			var dx := bx - (float(c.x) + 1.1)
			var tti := dx / maxf(float(c.v), 0.5)
			if dx > 0.0 and tti < Game.lv([0.32, 0.26, 0.2], level) and tti > 0.05 and randf() < Game.lv([0.75, 0.88, 0.97], level):
				held["a" if int(c.pump) != slot else "b"] = true
	InputHub.set_virtual(slot, Vector2.ZERO, held)
