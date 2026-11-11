extends MinigameBase
## Wackelsteg-Wirbel: Ein langer, schmaler Holzsteg über dem Fluss. Vom Sägewerk rollen Baumstämme heran
## (dicke kündigen sich mit Rumpeln an), A = drüberspringen. Der Steg kippt mal links, mal rechts – mit dem
## Stick gegenhalten. Wer getroffen wird, fliegt vom Steg. Übersprungene Stämme = Punkte bei Gleichstand.
## Online: Besitzer-Modell (Stämme aus dem gemeinsamen Zufall, jeder prüft Treffer für die eigene Figur).

const HALF_W := 2.6
const Z_FAR := -15.0
const Z_NEAR := 15.0

var _logs: Array[Dictionary] = []   # {node, mesh, z, v, r, passed:{}, hit:{}}
var _spawn_t := 2.2
var _tilt := 0.0
var _pier: Node3D


func _init() -> void:
	game_id = "log_bridge"
	env_preset = "day"
	time_limit = 45.0
	survival = true
	hazard = "water"
	kill_y = -2.5
	arena_radius = 12.0
	arena_center = Vector3(0, 0, 0)
	teaser_height = 1.0
	cannon_pos = Vector3(9, 0, 6)
	spawn_points = [Vector3(-1.6, 0.6, 1.0), Vector3(1.6, 0.6, 1.0), Vector3(-1.6, 0.6, 4.0), Vector3(1.6, 0.6, 4.0)]


func build_arena() -> void:
	WorldKit.water(world, Vector2(60, 90), -1.6, Color(0.1, 0.35, 0.4), Color(0.35, 0.6, 0.6))
	# Kollision bleibt eben (fair & physik-stabil); nur die sichtbaren Planken kippen mit
	WorldKit.box(world, Vector3(HALF_W * 2.0, 0.4, Z_NEAR - Z_FAR), Vector3(0, -0.2, 0), Color("#a06a3c"))
	_pier = Node3D.new()
	world.add_child(_pier)
	# Planken-Optik: helle/dunkle Querbretter
	var z := Z_FAR + 0.5
	var k := 0
	while z < Z_NEAR:
		var plank := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(HALF_W * 2.0 + 0.2, 0.06, 0.9)
		bm.material = WorldKit.mat(Color("#b9814d") if k % 2 == 0 else Color("#9b6638"))
		plank.mesh = bm
		plank.position = Vector3(0, 0.01, z)
		_pier.add_child(plank)
		z += 1.0
		k += 1
	for side in [-1.0, 1.0]:
		for i in 7:
			WorldKit.cylinder(_pier, 0.22, 3.0, Vector3(side * (HALF_W - 0.1), -1.5, Z_FAR + 2.0 + i * 4.4), Color("#6b4a2b"), false)
			WorldKit.cylinder(_pier, 0.12, 0.9, Vector3(side * (HALF_W - 0.1), 0.45, Z_FAR + 2.0 + i * 4.4), Color("#7a5532"), false)
	# Ufer mit Wald, Sägewerk am fernen Ende
	for side in [-1.0, 1.0]:
		WorldKit.box(world, Vector3(20, 2, 90), Vector3(side * 14.0, -1.4, 0), Color("#79c25a"), false)
		WorldKit.scatter(world, ["nat/tree_pine", "nat/tree_oak", "nat/bush", "nat/stump", "nat/flower_yellow"], 14, Vector3(side * 13.0, -0.4, 0), 2.0, 8.0, -0.4)
	WorldKit.cottage(world, Vector3(0, -0.4, Z_FAR - 6.0), PI, 1.6, Color("#e9c79a"))
	for i in 5:
		WorldKit.place(world, "nat/log", Vector3(-3.0 + i * 1.5, -0.2, Z_FAR - 3.0), 90.0, 1.4)
	WorldKit.place(world, "water/boat_fishing", Vector3(6.5, -1.6, 9.0), 30.0, 1.6)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, 0.0)
	c.offset = Vector3(9.5, 12.0, 13.0)
	c.min_dist = 0.9
	c.max_dist = 1.15


func on_start() -> void:
	for av in avatars:
		(av as PartyAvatar).rig.surface = "wood"


func on_tick(delta: float) -> void:
	var prog := 1.0 - time_left / time_limit
	# Steg kippt langsam hin und her (stärker gegen Ende) – drückt alle zur Seite
	_tilt = sin((time_limit - time_left) * 0.9) * lerpf(0.04, 0.1, prog)
	_pier.rotation.z = _tilt
	for i in active_slots():
		var av := avatars[i] as PartyAvatar
		if av.alive and net_owned(i) and av.is_on_floor():
			av.velocity.x -= sin(_tilt) * 24.0 * delta
	# Neue Stämme (gemeinsamer Zufall → auf allen Geräten gleich)
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		var big := rng.randf() < lerpf(0.1, 0.35, prog)
		_spawn_log(big, lerpf(5.0, 9.5, prog) * (0.8 if big else 1.0) * rng.randf_range(0.9, 1.15))
		if prog > 0.45 and rng.randf() < 0.35:
			_spawn_t = rng.randf_range(0.45, 0.6)   # Doppelstamm: zwei kurz hintereinander
		else:
			_spawn_t = lerpf(2.4, 1.2, prog) * rng.randf_range(0.85, 1.2)
	var i_log := _logs.size() - 1
	while i_log >= 0:
		var L := _logs[i_log]
		L.z = float(L.z) + float(L.v) * delta
		var n: Node3D = L.node
		n.position.z = float(L.z)
		(L.mesh as Node3D).rotation.x += float(L.v) * delta / float(L.r)
		for j in active_slots():
			var av2 := avatars[j] as PartyAvatar
			if not av2.alive or not net_owned(j) or (L.hit as Dictionary).has(j):
				continue
			var dz := av2.global_position.z - float(L.z)
			var low := av2.global_position.y < float(L.r) * 1.25
			if absf(dz) < float(L.r) + 0.2 and low:
				(L.hit as Dictionary)[j] = true
				var side := 1.0 if av2.global_position.x >= 0.0 else -1.0
				# Zurückgeworfen (Richtung Kamera) statt seitlich ins Wasser – fällt nur, wer am Ende/Rand steht
				av2.apply_knockback(Vector3(side * 0.2, 0, 1).normalized(), 8.5, 0.6, 5.0)
				av2.rig.react("big_hit")
				Audio.sfx("wood_hit", av2.global_position)
				FX.stars(av2.global_position + Vector3.UP * 1.6, Color(1, 0.9, 0.4), 10)
				Juice.shake(0.2)
			elif dz < -float(L.r) - 0.4 and not (L.passed as Dictionary).has(j):
				(L.passed as Dictionary)[j] = true
				add_score(j, 1.0)
		if float(L.z) > Z_NEAR + 1.5:
			var tw := n.create_tween()
			tw.tween_property(n, "position:y", -3.0, 0.5)
			tw.tween_callback(n.queue_free)
			FX.splash(Vector3(0, -1.5, Z_NEAR + 2.0), 1.0)
			_logs.remove_at(i_log)
		i_log -= 1


func _spawn_log(big: bool, speed: float) -> void:
	var r := 0.85 if big else 0.5
	var n := Node3D.new()
	_pier.add_child(n)
	n.position = Vector3(0, r, Z_FAR)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = HALF_W * 2.0 - 0.3
	cm.material = WorldKit.mat(Color("#7a4f2a") if not big else Color("#5e3b1e"))
	mi.mesh = cm
	mi.rotation.z = PI / 2.0
	n.add_child(mi)
	# Jahresringe an den Stirnseiten
	for s in [-1.0, 1.0]:
		var cap := MeshInstance3D.new()
		var cc := CylinderMesh.new()
		cc.top_radius = r * 0.9
		cc.bottom_radius = r * 0.9
		cc.height = 0.04
		cc.material = WorldKit.mat(Color("#e8c48c"))
		cap.mesh = cc
		cap.position.y = s * (HALF_W - 0.13)
		mi.add_child(cap)
	n.scale = Vector3(1, 0.01, 1)
	n.create_tween().tween_property(n, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	Audio.sfx("stone_hit" if big else "wood_hit", n.global_position, -2.0 if big else -6.0, 0.7 if big else 1.0)
	if big:
		Juice.shake(0.12)
	_logs.append({"node": n, "mesh": mi, "z": Z_FAR, "v": speed, "r": r, "passed": {}, "hit": {}})


func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	if not av.alive:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var mem: Dictionary = cpu_mem[slot]
	if not mem.has("lane"):
		mem["lane"] = randf_range(-1.4, 1.4)
		mem["home"] = randf_range(0.0, 5.0)
	var p := av.global_position
	# Gegen die Neigung halten und in der eigenen Spur bleiben
	var mv := Vector2(clampf((float(mem.lane) - p.x) * 0.9 + sin(_tilt) * 7.0, -1.0, 1.0), clampf((float(mem.home) - p.z) * 0.4, -0.6, 0.6))
	var held := {}
	for L in _logs:
		var dz := p.z - float(L.z)
		var t_hit := dz / maxf(float(L.v), 0.1)
		# Absprung, bevor der Stamm das Trefferfenster erreicht (Fenster = r + 0,2 m)
		var lead: float = (float(L.r) + 0.2) / maxf(float(L.v), 0.1) + [0.22, 0.16, 0.12][level]
		if t_hit > 0.0 and t_hit < lead + randf_range(-0.06, 0.06) * (3 - level) and av.is_on_floor():
			held["a"] = true
	InputHub.set_virtual(slot, mv, held)
