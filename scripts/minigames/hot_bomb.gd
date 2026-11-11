extends MinigameBase
## Bomben-Heißer-Hut: Eine tickende Kanonenkugel geht im Kreis herum. Mit B wirfst du sie zum
## nächsten Mitspieler in Blickrichtung. Wer sie beim Knall hält, fliegt mit Ruß-Gesicht in den
## Himmel (und funkelt dort als Sternchen). Drei Explosionen – der Letzte gewinnt.

const RADIUS := 10.0

var bomb: Node3D
var holder := -1
var _fuse := 10.0
var _fuse_max := 10.0
var _flight := false
var _immune := {}
var _tick := 0.0
var _glow: OmniLight3D
var _round_pause := false


func _init() -> void:
	game_id = "hot_bomb"
	env_preset = "day"
	time_limit = 999.0
	show_timer = false
	survival = true
	teaser_height = 1.2
	arena_radius = 11.0
	cannon_pos = Vector3(0, 0, 13.5)
	spawn_points = [Vector3(-4, 0.3, -3), Vector3(4, 0.3, -3), Vector3(-4, 0.3, 4), Vector3(4, 0.3, 4)]


func build_arena() -> void:
	WorldKit.cylinder(world, RADIUS + 0.6, 1.0, Vector3(0, -0.5, 0), Color("#c9b48a"))
	WorldKit.cylinder(world, RADIUS - 1.5, 0.04, Vector3(0, 0.02, 0), Color("#d8c49a"), false)
	for i in 16:
		var a := TAU * i / 16.0
		var p := Vector3(cos(a), 0, sin(a)) * (RADIUS + 0.9)
		var w := WorldKit.place(world, "castle/wall", p, 0.0, 2.2)
		w.look_at(Vector3(0, 0, 0), Vector3.UP)
		Assets.add_box_collision(w, "castle/wall")
		if i % 4 == 0:
			WorldKit.place(world, "castle/tower_hex_base", p * 1.08, 0.0, 2.4)
	for i in 10:
		var a2 := TAU * i / 10.0 + 0.2
		var pet := CharacterRig.new()
		world.add_child(pet)
		pet.setup(["pet/cat", "pet/bunny", "pet/chick", "pet/cow", "pet/deer"][i % 5], -1, 0.8)
		pet.position = Vector3(cos(a2), 0, sin(a2)) * (RADIUS + 4.5)
		pet.face_now(-pet.position)
		pet.play("dance" if i % 2 else "idle")
	bomb = Node3D.new()
	world.add_child(bomb)
	Assets.spawn("pirate/cannon_ball", bomb, Vector3.ZERO, 0.0, 1.5)
	var fuse := FX.make_trail(bomb, "sparks")
	fuse.position = Vector3(0, 0.55, 0)
	fuse.amount = 14
	fuse.emitting = true
	fuse.color = Color(1, 0.7, 0.2)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1, 0.4, 0.1)
	_glow.omni_range = 4.0
	bomb.add_child(_glow)
	bomb.visible = false


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, 0.5)
	c.offset = Vector3(0, 16, 13)
	c.min_dist = 0.9
	c.max_dist = 1.05
	c.center_weight = 0.7


func on_start() -> void:
	for av in avatars:
		(av as PartyAvatar).rig.surface = "sand"
		(av as PartyAvatar).can_shove = false
		(av as PartyAvatar).can_jump = true
	_new_round()


func _new_round() -> void:
	var cands: Array[int] = []
	for i in 4:
		if alive[i]:
			cands.append(i)
	holder = cands[randi() % cands.size()]
	_fuse_max = randf_range(7.0, 12.0)
	_fuse = _fuse_max
	bomb.visible = true
	_flight = false
	_round_pause = false
	Juice.pop_in(bomb, 0.4)
	Audio.sfx("pop", bomb.global_position)
	(avatars[holder] as PartyAvatar).rig.react("scared")


func on_tick(delta: float) -> void:
	if _round_pause or holder < 0:
		return
	for k in _immune.keys():
		_immune[k] = float(_immune[k]) - delta
		if _immune[k] <= 0.0:
			_immune.erase(k)
	var hav := avatars[holder] as PartyAvatar
	if not _flight:
		bomb.global_position = hav.global_position + Vector3.UP * 2.7
		bomb.rotation.y += delta * 4.0
		hav.max_speed = 6.0
		if not hav.rig.is_locked():
			hav.rig.play("hold" if hav.velocity.length() < 0.5 else "run")
		if InputHub.pressed(holder, "b"):
			_throw()
	_fuse -= delta
	var urgency := 1.0 - _fuse / _fuse_max
	_tick -= delta
	if _tick <= 0.0:
		_tick = lerpf(0.6, 0.09, urgency)
		Audio.sfx("tick", bomb.global_position, 0.0, 1.0 + urgency * 0.6, 0.0)
		Juice.squash(bomb, 1.25, 1.25, 0.12)
		_glow.light_energy = 3.0
	_glow.light_energy = lerpf(_glow.light_energy, 0.4 + urgency, delta * 6.0)
	if _fuse <= 0.0 and not _flight:
		_explode()
	for i in 4:
		var av := avatars[i] as PartyAvatar
		if i != holder:
			av.max_speed = 7.5
		var flat := Vector2(av.global_position.x, av.global_position.z)
		if flat.length() > RADIUS - 0.6:
			flat = flat.normalized() * (RADIUS - 0.6)
			av.global_position = Vector3(flat.x, av.global_position.y, flat.y)


func _throw() -> void:
	var hav := avatars[holder] as PartyAvatar
	var fwd := -hav.rig.global_basis.z
	fwd.y = 0
	var best := -1
	var best_s := -INF
	for i in 4:
		if i == holder or not alive[i] or _immune.has(i):
			continue
		var d := (avatars[i] as Node3D).global_position - hav.global_position
		d.y = 0
		var s := fwd.normalized().dot(d.normalized()) * 2.0 - d.length() * 0.12
		if s > best_s:
			best_s = s
			best = i
	if best < 0:
		return
	_flight = true
	hav.rig.play("throw", 0.05, 1.5, true)
	hav.rig.lock(0.4)
	Audio.sfx("whoosh", hav.global_position)
	var from := bomb.global_position
	var target_av := avatars[best] as PartyAvatar
	var prev := holder
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var to := target_av.global_position + Vector3.UP * 2.7
		bomb.global_position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * 3.0
		bomb.rotation.x = t * TAU * 2.0, 0.0, 1.0, 0.45)
	await tw.finished
	if state != "play" or _round_pause:
		return
	_immune[prev] = 0.9
	holder = best
	_flight = false
	target_av.rig.react("shocked")
	Audio.sfx("hit_soft", target_av.global_position)
	InputHub.rumble(best, 0.4, 0.12)


func _explode() -> void:
	_round_pause = true
	var av := avatars[holder] as PartyAvatar
	var p := av.global_position
	bomb.visible = false
	FX.explosion(p + Vector3.UP, 1.4)
	Audio.sfx("explosion_big", p)
	Juice.hitstop(0.12)
	InputHub.rumble(holder, 1.0, 0.5)
	av.rig.set_soot(10.0)
	av.rig.react("launch")
	av.freeze(true)
	av.set_physics_process(false)
	var victim := holder
	eliminate(victim)
	holder = -1
	# Ab in den Himmel – Funkel-Stern
	var tw := av.create_tween()
	tw.tween_property(av, "global_position", p + Vector3(randf_range(-4, 4), 30.0, -12.0), 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(av.rig.pivot, "rotation:x", TAU * 3.0, 1.4)
	tw.tween_callback(func() -> void:
		FX.stars(av.global_position, Color(1, 1, 0.9), 6)
		Audio.sfx("bell", null, -6.0, 2.0)
		av.visible = false)
	await get_tree().create_timer(2.4, false).timeout
	if state == "play" and alive_count() > 1:
		_new_round()


func _update_badges() -> void:
	for i in badges.size():
		badges[i].set_status("alive" if alive[i] else "out")


# --- CPU ---------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	if not alive[slot] or holder < 0:
		InputHub.set_virtual(slot, Vector2.ZERO)
		return
	var level: int = Game.players[slot].cpu_level
	var held := {}
	var mv := Vector2.ZERO
	if slot == holder and not _flight:
		var best := -1
		var bd := INF
		for i in 4:
			if i != slot and alive[i]:
				var d := av.global_position.distance_to((avatars[i] as Node3D).global_position)
				if d < bd:
					bd = d
					best = i
		if best >= 0:
			var to := (avatars[best] as Node3D).global_position - av.global_position
			mv = Vector2(to.x, to.z).normalized()
			var mem: Dictionary = cpu_mem[slot]
			mem["hold_t"] = mem.get("hold_t", 0.0) + _delta
			var wait: float = Game.lv_react([1.6, 0.9, 0.35], level)
			if bd < 7.0 and mem["hold_t"] > wait:
				held["b"] = true
				mem["hold_t"] = 0.0
	else:
		var hp := (avatars[holder] as Node3D).global_position
		var away := av.global_position - hp
		away.y = 0
		mv = Vector2(away.x, away.z).normalized()
		var tangent := Vector2(-av.global_position.z, av.global_position.x).normalized()
		if Vector2(av.global_position.x, av.global_position.z).length() > RADIUS - 2.5:
			mv = (mv + tangent * 1.5).normalized()
		if away.length() > 7.0:
			mv *= 0.3
	InputHub.set_virtual(slot, mv, held)
