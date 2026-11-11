extends MinigameBase
## Klatsch-Karussell (Duell): Zwei Spieler auf einer drehenden Plattform über dem Teich. Ein Holzarm mit
## Riesenhandschuh kreist darüber – mal tief (springen, A), mal hoch (ducken, B halten). Die Farbe des
## Handschuhs verrät die Höhe kurz vorher (orange = tief, lila = hoch). Wer erwischt wird, verliert ein Herz und
## wird weggeschleudert; drei Herzen. Gegen Ende dreht der Arm schneller und wechselt häufiger.
## Online: Besitzer-Modell (Arm aus dem gemeinsamen Zufall, jeder prüft Treffer für die eigene Figur).

const R := 5.0
const ARM_LEN := 5.6

var _plat: Node3D
var _arm: Node3D
var _glove: MeshInstance3D
var _ang := -PI * 0.5   # startet gegenüber den Spielern (faire erste Sekunde)
var _speed := 1.3
var _high := false
var _next_high := false
var _switch_t := 3.0
var _hit_cd: Array[float] = [0, 0, 0, 0]
var _duck: Array[bool] = [false, false, false, false]


func _init() -> void:
	game_id = "slap_carousel"
	env_preset = "day"
	backdrop_style = "meadow"
	time_limit = 45.0
	survival = true
	hazard = "water"
	kill_y = -2.5
	score_format = "%d Herzen"
	arena_radius = 6.0
	teaser_height = 1.0
	cannon_pos = Vector3(0, 0, 8)
	spawn_points = [Vector3(-2.2, 0.6, 1.2), Vector3(2.2, 0.6, 1.2), Vector3(-2.2, 0.6, -1.2), Vector3(2.2, 0.6, -1.2)]


func build_arena() -> void:
	WorldKit.water(world, Vector2(70, 70), -1.2, Color(0.1, 0.4, 0.5), Color(0.4, 0.8, 0.8))
	_plat = Node3D.new()
	world.add_child(_plat)
	# Kollision fest (fair), Optik dreht: Karussellscheibe mit Streifen, Glühbirnenrand, Mittelsäule
	WorldKit.cylinder(world, R, 0.5, Vector3(0, -0.25, 0), Color("#ffe0b8"))
	for k in 8:
		var seg := WorldKit.box(_plat, Vector3(R * 0.95, 0.03, 0.9), Vector3(R * 0.47, 0.02, 0), [Color("#ff8fab"), Color("#ffd166")][k % 2], false)
		seg.get_parent().remove_child(seg)
		var piv := Node3D.new()
		_plat.add_child(piv)
		piv.rotation.y = TAU * k / 8.0
		piv.add_child(seg)
	for k in 16:
		var a := TAU * k / 16.0
		var bulb := WorldKit.cylinder(_plat, 0.09, 0.12, Vector3(cos(a) * (R - 0.15), 0.06, sin(a) * (R - 0.15)), Color("#fff6c8"), false)
		((bulb.get_child(0) as MeshInstance3D)).material_override = WorldKit.mat(Color("#fff3a0"), 0.3, 2.0)
	WorldKit.cylinder(world, 0.45, 2.8, Vector3(0, 1.4, 0), Color("#c0392b"))
	_arm = Node3D.new()
	world.add_child(_arm)
	_arm.position = Vector3(0, 0.35, 0)
	WorldKit.box(_arm, Vector3(ARM_LEN, 0.22, 0.32), Vector3(ARM_LEN * 0.5, 0, 0), Color("#8a5a34"), false)
	_glove = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.55
	sm.height = 0.9
	_glove.mesh = sm
	_glove.material_override = WorldKit.mat(Color("#ff9f43"), 0.4)
	_glove.position = Vector3(ARM_LEN - 0.4, 0, 0)
	_arm.add_child(_glove)
	# Ufer mit Jahrmarkt-Deko
	for i in 8:
		var a2 := TAU * i / 8.0 + 0.2
		var p := Vector3(cos(a2), 0, sin(a2)) * 11.0
		WorldKit.box(world, Vector3(5, 2, 5), p + Vector3(0, -1.6, 0), Color("#7cc85a"), false)
		WorldKit.place(world, ["nat/tree_oak", "qp/tree_fruit", "nat/bush", "town/lantern"][i % 4], p + Vector3(0, -0.6, 0), randf() * 360.0, [2.0, 0.28, 2.2, 1.0][i % 4])


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0.5, 0.5)
	c.offset = Vector3(0, 10.0, 9.0)
	c.min_dist = 1.0
	c.max_dist = 1.0


func on_start() -> void:
	for i in active_slots():
		scores[i] = 3.0
		(avatars[i] as PartyAvatar).can_shove = false


func on_tick(delta: float) -> void:
	var prog := 1.0 - time_left / time_limit
	_speed = lerpf(1.4, 2.6, prog)
	_ang += _speed * delta
	_switch_t -= delta
	if _switch_t <= 0.0:
		_switch_t = rng.randf_range(lerpf(3.0, 1.4, prog), lerpf(4.5, 2.4, prog))
		_next_high = rng.randf() < 0.5
	# Höhe wechselt erst, wenn der Arm die Spieler gerade nicht überstreicht (Farbe kündigt an)
	if _next_high != _high and _arm_clear():
		_high = _next_high
	_arm.rotation.y = -_ang
	_arm.position.y = lerpf(_arm.position.y, 1.45 if _high else 0.35, 0.2)
	(_glove.material_override as StandardMaterial3D).albedo_color = Color("#a06bff") if _next_high else Color("#ff9f43")
	_plat.rotation.y += 0.5 * delta
	for i in active_slots():
		_hit_cd[i] = maxf(0.0, _hit_cd[i] - delta)
		var av := avatars[i] as PartyAvatar
		if not av.alive:
			continue
		# Plattform nimmt Figuren mit (Drehung um die Mitte)
		if net_owned(i) and av.is_on_floor():
			var p := av.global_position
			var rot := Vector2(p.x, p.z).rotated(-0.5 * delta)
			av.global_position = Vector3(rot.x, p.y, rot.y)
		_duck[i] = InputHub.held(i, "b") and av.is_on_floor()
		av.max_speed = 3.0 if _duck[i] else 6.0
		av.rig.scale.y = lerpf(av.rig.scale.y, 0.6 if _duck[i] else 1.0, 0.3) if av.rig.scale.y > 0.2 else av.rig.scale.y
		if net_owned(i) and _hit_cd[i] <= 0.0:
			_check_hit(i)


## Höhenwechsel nur, wenn der Arm gerade weit weg von allen Spielern ist (kein unfairer Wechsel über dem Kopf)
func _arm_clear() -> bool:
	for i in active_slots():
		var av := avatars[i] as PartyAvatar
		if av.alive and absf(wrapf(atan2(av.global_position.z, av.global_position.x) - _ang, -PI, PI)) < 1.2:
			return false
	return true


func _check_hit(i: int) -> void:
	var av := avatars[i] as PartyAvatar
	var p := av.global_position
	var r := Vector2(p.x, p.z).length()
	if r < 0.6:
		return
	var a := atan2(p.z, p.x)
	var d := wrapf(a - _ang, -PI, PI)
	if absf(d) * r > 0.42:
		return
	var safe := (not _high and p.y > 0.45) or (_high and _duck[i])
	if safe:
		return
	_hit_cd[i] = 2.0
	# In Bewegungsrichtung des Arms wegschleudern (Tangente) – sonst trifft er gleich nochmal
	var push := Vector3(p.x, 0, p.z).normalized() * 0.5 + Vector3(-sin(_ang), 0, cos(_ang))
	av.apply_knockback(push.normalized(), 5.5, 0.6, 4.0)   # Herz weg, aber nicht gleich ins Wasser
	av.rig.react("big_hit")
	FX.stars(p + Vector3.UP * 1.4, Color(1, 0.95, 0.5), 12)
	Audio.sfx("punch", p)
	Juice.shake(0.25)
	add_score(i, -1.0, p + Vector3.UP * 2.0)
	if scores[i] <= 0.0:
		eliminate(i)


func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	if not av.alive:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var mem: Dictionary = cpu_mem[slot]
	var p := av.global_position
	var r := Vector2(p.x, p.z).length()
	var a := atan2(p.z, p.x)
	var gap := wrapf(a - _ang, -PI, PI)
	# Relative Annäherung: Arm dreht vorwärts, die Plattform trägt die Figur entgegen (0,5 rad/s)
	var closing := _speed + 0.5
	var t_hit := gap / closing if gap > 0.0 else (gap + TAU) / closing
	var held := {}
	# Pro Überstreichen einmal entscheiden, ob die CPU patzt
	var pass_id := int((_ang + gap) / TAU)
	if int(mem.get("pass", -1)) != pass_id:
		mem["pass"] = pass_id
		mem["miss"] = randf() < [0.28, 0.12, 0.04][level]
		mem["wrong"] = randf() < [0.15, 0.06, 0.02][level]
	var high := _high if t_hit < 0.6 else _next_high
	if bool(mem.wrong):
		high = not high
	if not bool(mem.miss):
		if high and (t_hit < 0.5 or gap > -0.45):
			held["b"] = true
		elif not high and t_hit < [0.3, 0.27, 0.24][level] and av.is_on_floor():
			held["a"] = true
	# Nicht zu nah an den Rand
	var mv := Vector2.ZERO
	if r > R - 1.6:
		mv = -Vector2(p.x, p.z).normalized()
	elif r < 1.2:
		mv = Vector2(p.x, p.z).normalized() if r > 0.1 else Vector2.RIGHT
	InputHub.set_virtual(slot, mv, held)
