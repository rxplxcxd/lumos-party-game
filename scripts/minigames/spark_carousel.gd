extends MinigameBase
## Funken-Karussell: Eine Jahrmarkt-Drehscheibe bei Nacht. Ein Funkenarm kreist gegen die Drehrichtung
## (A = drüberspringen), Blitzstreifen auf der Scheibe glühen erst auf und schlagen dann ein (rausgehen!).
## Die Scheibe dreht sich mit – man wird mitgenommen. 3 Leben, gegen Ende zwei Arme und mehr Streifen.
## Online: Besitzer-Modell (Arm/Streifen aus gemeinsamem Zufall, Treffer prüft jedes Gerät für seine Figur).

const R := 8.0
const ARM_H := 0.5

var _disc: Node3D
var _spin := 0.0          # Winkel der Scheibe
var _omega := 0.35
var _arms: Array[Dictionary] = []    # {node, a, w}
var _strips: Array[Dictionary] = []  # {node, mat, a, t, fired}
var _strip_t := 3.0
var _lives: Array[int] = [3, 3, 3, 3]
var _hit_cd: Array[float] = [0, 0, 0, 0]


func _init() -> void:
	game_id = "spark_carousel"
	env_preset = "night"
	backdrop_style = "night"
	time_limit = 45.0
	survival = true
	score_format = "%d Leben"
	arena_radius = 9.0
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 12)
	spawn_points = [Vector3(-3, 0.6, -3), Vector3(3, 0.6, -3), Vector3(-3, 0.6, 3), Vector3(3, 0.6, 3)]


func build_arena() -> void:
	WorldKit.box(world, Vector3(60, 1, 60), Vector3(0, -1.6, 0), Color("#2b2440"), false)
	WorldKit.cylinder(world, R, 0.5, Vector3(0, -0.25, 0), Color("#f2e6ff"))   # Kollision bleibt fest
	_disc = Node3D.new()
	world.add_child(_disc)
	# Bunte Segmente (nur Optik, drehen sich)
	for i in 12:
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(R * 0.98, 0.04, 1.2)
		bm.material = WorldKit.mat([Color("#ff6b9e"), Color("#ffd166"), Color("#7ad1ff")][i % 3], 0.6, 0.15)
		seg.mesh = bm
		seg.position = Vector3(cos(TAU * i / 12.0), 0, sin(TAU * i / 12.0)) * R * 0.5 + Vector3.UP * 0.02
		seg.rotation.y = -TAU * i / 12.0
		_disc.add_child(seg)
	for i in 24:
		var a := TAU * i / 24.0
		var bulb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.32
		sm.material = WorldKit.mat([Color("#ffe08a"), Color("#ff8ad8")][i % 2], 0.3, 2.0)
		bulb.mesh = sm
		bulb.position = Vector3(cos(a) * (R - 0.15), 0.12, sin(a) * (R - 0.15))
		_disc.add_child(bulb)
	# Mittelmast mit gestreiftem Zeltdach und Funken-Spule
	WorldKit.cylinder(world, 0.45, 5.0, Vector3(0, 2.5, 0), Color("#c9b8ff"))
	var roof := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.1
	cm.bottom_radius = 3.2
	cm.height = 1.6
	cm.material = WorldKit.mat(Color("#ff5c8a"), 0.5, 0.1)
	roof.mesh = cm
	roof.position.y = 5.6
	world.add_child(roof)
	WorldKit.torch_light(world, Vector3(0, 4.2, 0), Color(0.6, 0.8, 1.0))
	for i in 6:
		var a2 := TAU * i / 6.0 + 0.3
		WorldKit.place(world, ["race/light_colored", "arcade/prize_wheel", "arcade/claw"][i % 3], Vector3(cos(a2) * 14.0, -1.1, sin(a2) * 14.0), rad_to_deg(-a2) - 90.0, 2.2)
	_add_arm(0.0, -0.9)


func _add_arm(angle: float, w: float) -> void:
	var n := Node3D.new()
	world.add_child(n)
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(R - 0.6, 0.18, 0.18)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.6, 0.9, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.5, 0.85, 1.0)
	m.emission_energy_multiplier = 3.0
	bm.material = m
	beam.mesh = bm
	beam.position = Vector3((R - 0.6) * 0.5 + 0.5, ARM_H, 0)
	n.add_child(beam)
	var sparks := FX.make_trail(beam, "sparks")
	if sparks:
		sparks.position.x = (R - 0.6) * 0.5
	n.rotation.y = angle
	_arms.append({"node": n, "a": angle, "w": w})


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, 0.5)
	c.offset = Vector3(0, 14.0, 12.5)
	c.min_dist = 0.9
	c.max_dist = 1.1


func on_start() -> void:
	for i in 4:
		scores[i] = 3.0
		(avatars[i] as PartyAvatar).rig.surface = "metal"


func on_tick(delta: float) -> void:
	var prog := 1.0 - time_left / time_limit
	_omega = lerpf(0.35, 0.8, prog)
	_spin += _omega * delta
	_disc.rotation.y = -_spin
	if prog > 0.5 and _arms.size() < 2:
		_add_arm(PI, 1.15)   # zweiter Arm, gegenläufig
		Audio.sfx("zap")
		CutsceneManager.big_word("Zweiter Arm!", Color("#9fe0ff"), 0.5)
	for arm in _arms:
		arm.a = float(arm.a) + float(arm.w) * lerpf(1.0, 1.6, prog) * delta
		(arm.node as Node3D).rotation.y = float(arm.a)
	# Blitzstreifen: aufglühen (1 s), dann Einschlag
	_strip_t -= delta
	if _strip_t <= 0.0:
		_strip_t = lerpf(2.6, 1.3, prog)
		var n_strips := 1 if prog < 0.4 else 2
		for k in n_strips:
			_spawn_strip(rng.randf() * TAU)
	var i_s := _strips.size() - 1
	while i_s >= 0:
		var st := _strips[i_s]
		st.t = float(st.t) + delta
		var m: StandardMaterial3D = st.mat
		if not bool(st.fired):
			m.albedo_color.a = 0.25 + 0.35 * absf(sin(float(st.t) * 14.0))
			if float(st.t) >= 1.0:
				st.fired = true
				m.albedo_color = Color(0.85, 0.95, 1.0, 0.95)
				m.emission_energy_multiplier = 5.0
				var mid := Vector3(cos(-_spin + float(st.a)), 0.3, sin(-_spin + float(st.a))) * R * 0.5
				FX.flash_light(mid, Color(0.6, 0.85, 1.0), 6.0, 0.25, 9.0)
				Audio.sfx("zap", mid, -2.0)
				for j in active_slots():
					if _in_strip(j, float(st.a)):
						_hit(j)
		elif float(st.t) >= 1.25:
			(st.node as Node3D).queue_free()
			_strips.remove_at(i_s)
		i_s -= 1
	for j in active_slots():
		_hit_cd[j] = maxf(0.0, _hit_cd[j] - delta)
		var av := avatars[j] as PartyAvatar
		if not av.alive or not net_owned(j):
			continue
		# Mitdrehen: Figuren auf der Scheibe werden mitgenommen
		if av.is_on_floor():
			var p := av.global_position
			var rot := Vector2(p.x, p.z).rotated(-_omega * delta)
			av.global_position = Vector3(rot.x, p.y, rot.y)
		# Funkenarm
		for arm in _arms:
			var p2 := av.global_position
			var ang := atan2(-p2.z, p2.x)   # gleiche Konvention wie rotation.y
			var dist := Vector2(p2.x, p2.z).length()
			var da := absf(wrapf(ang - float(arm.a), -PI, PI))
			if dist > 0.5 and dist < R and da * dist < 0.45 and p2.y < ARM_H + 0.25:
				_hit(j)


func _spawn_strip(a: float) -> void:
	var n := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(R - 1.0, 0.03, 1.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.55, 0.85, 1.0, 0.3)
	m.emission_enabled = true
	m.emission = Color(0.5, 0.8, 1.0)
	m.emission_energy_multiplier = 1.5
	bm.material = m
	n.mesh = bm
	n.position = Vector3((R - 1.0) * 0.5 + 0.9, 0.06, 0)
	var holder := Node3D.new()
	_disc.add_child(holder)
	holder.rotation.y = a
	holder.add_child(n)
	Audio.sfx("spark", null, -10.0, 1.4)
	_strips.append({"node": holder, "mat": m, "a": a, "t": 0.0, "fired": false})


## Steht Figur j im Blitzstreifen (Winkel a auf der drehenden Scheibe)?
func _in_strip(j: int, a: float) -> bool:
	var av := avatars[j] as PartyAvatar
	if not av.alive or not net_owned(j):
		return false
	var p := av.global_position
	var local := Vector2(p.x, p.z).rotated(_spin)   # in Scheiben-Koordinaten
	var along := local.rotated(a)
	return along.x > 0.4 and along.x < R - 0.5 and absf(along.y) < 0.85 and p.y < 1.2


func _hit(j: int) -> void:
	if _hit_cd[j] > 0.0:
		return
	_hit_cd[j] = 1.2
	var av := avatars[j] as PartyAvatar
	_lives[j] -= 1
	add_score(j, -1.0)
	av.stun(0.7)
	av.rig.react("shocked")
	av.rig.set_soot(2.0)
	FX.sparks(av.global_position + Vector3.UP, Color(0.6, 0.9, 1.0), 16)
	Audio.sfx("zap", av.global_position)
	InputHub.rumble(j, 0.8, 0.25)
	if _lives[j] <= 0:
		av.rig.react("soot_blast")
		eliminate(j)
		var tw := av.create_tween()
		tw.tween_property(av, "global_position", av.global_position.normalized() * (R + 4.0) + Vector3(0, -6, 0), 1.0)


func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	if not av.alive:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var p := av.global_position
	var held := {}
	var mv := Vector2.ZERO
	# Glühenden Streifen verlassen (quer zum Streifen ausweichen)
	for st in _strips:
		if not bool(st.fired) and float(st.t) > [0.55, 0.35, 0.2][level]:
			var local := Vector2(p.x, p.z).rotated(_spin).rotated(float(st.a))
			if local.x > 0.0 and absf(local.y) < 1.4:
				var side := Vector2(0, 1.0 if local.y >= 0.0 else -1.0).rotated(-float(st.a)).rotated(-_spin)
				mv += side * 1.5
	# Über den Arm springen: tatsächlichen Abstand messen, aus der Annäherung die Zeit bis zum Treffer schätzen
	var mem: Dictionary = cpu_mem[slot]
	var dist := Vector2(p.x, p.z).length()
	for k in _arms.size():
		var ang := atan2(-p.z, p.x)
		var gap := absf(wrapf(ang - float(_arms[k].a), -PI, PI)) * maxf(dist, 0.5)
		var key := "gap%d" % k
		var prev := float(mem.get(key, gap))
		mem[key] = gap
		var rate := (prev - gap) / maxf(_delta, 0.001)
		if rate > 0.5 and gap / rate < [0.24, 0.19, 0.16][level] and gap < 3.0 and av.is_on_floor():
			held["a"] = true
	# Mittlerer Ring ist am sichersten
	var r := Vector2(p.x, p.z).length()
	if r > R * 0.75 or r < 2.0:
		mv += -Vector2(p.x, p.z).normalized() * (1.0 if r > R * 0.75 else -1.0)
	InputHub.set_virtual(slot, mv.limit_length(1.0), held)
