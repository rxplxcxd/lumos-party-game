extends MinigameBase
## Boss: Pustebacke, der Wolkendrache. Ein flauschiger, schlecht gelaunter Wolkendrache bläst Wind, lässt
## Mini-Gewitterwölkchen regnen und rauscht im Sturzflug über die Insel. Alle sammeln Sonnenbälle (Berühren)
## und werfen sie mit B auf ihn. Wer am meisten Schaden macht, gewinnt – besiegen alle ihn rechtzeitig,
## gibt es einen Extra-Bonus. Online: Host-Modell (Host simuliert alles, Clients zeigen den Zustand).

const RADIUS := 10.0
const MAX_HP := 60.0

var hp := MAX_HP
var boss: Node3D
var _body: Node3D
var _face: Node3D
var _phase := 1
var _attack := "idle"
var _atk_t := 2.5
var _boss_pos := Vector3(0, 4.0, -6)
var _dash_from := Vector3.ZERO
var _dash_to := Vector3.ZERO
var orbs: Array[Dictionary] = []
var clouds: Array[Dictionary] = []
var carry: Array[bool] = [false, false, false, false]
var _orb_t := 0.5
var _hp_bar: ColorRect
var _hp_bg: ColorRect
var defeated := false
var _flash := 0.0


func _init() -> void:
	game_id = "boss_cloud"
	env_preset = "sky"
	time_limit = 70.0
	arena_radius = 11.0
	teaser_height = 2.0
	cannon_pos = Vector3(0, 0, 14)
	net_model = "host"
	score_format = "%d Schaden"
	spawn_points = [Vector3(-4, 0.6, 3), Vector3(4, 0.6, 3), Vector3(-4, 0.6, 6), Vector3(4, 0.6, 6)]


func build_arena() -> void:
	WorldKit.cylinder(world, RADIUS, 1.4, Vector3(0, -0.7, 0), Color("#a8e08a"))
	WorldKit.cylinder(world, RADIUS + 0.4, 0.5, Vector3(0, -1.5, 0), Color("#e9f0ff"), false)
	for i in 10:
		var a := TAU * i / 10.0
		WorldKit.place(world, ["plat/flowers", "plat/tree", "plat/mushrooms", "nat/bush", "plat/flag"][i % 5], Vector3(cos(a), 0, sin(a)) * (RADIUS - 0.9), randf() * 360.0, 1.6)
	for i in 26:
		var a2 := TAU * i / 26.0
		var puff := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = randf_range(2.0, 4.0)
		sm.height = sm.radius * 1.2
		sm.material = WorldKit.mat(Color.WHITE, 1.0, 0.18)
		puff.mesh = sm
		world.add_child(puff)
		puff.position = Vector3(cos(a2) * randf_range(15, 24), randf_range(-7, -2), sin(a2) * randf_range(15, 24))
	_build_boss()


func _build_boss() -> void:
	boss = Node3D.new()
	world.add_child(boss)
	_body = Node3D.new()
	boss.add_child(_body)
	var white := WorldKit.mat(Color("#fbfcff"), 1.0, 0.12)
	for e in [[Vector3(0, 0, 0), 1.9], [Vector3(-1.3, 0.3, 0.3), 1.2], [Vector3(1.3, 0.3, 0.3), 1.2], [Vector3(0, 1.1, 0.2), 1.3], [Vector3(0, -0.6, 1.2), 1.0], [Vector3(0, 0.2, 1.9), 0.7]]:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = float(e[1])
		sm.height = float(e[1]) * 2.0
		sm.material = white
		mi.mesh = sm
		mi.position = e[0]
		_body.add_child(mi)
	_face = Node3D.new()
	_face.position = Vector3(0, 0.4, -1.7)
	_body.add_child(_face)
	for s in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.28
		es.height = 0.56
		es.material = WorldKit.mat(Color(0.12, 0.1, 0.18), 0.3)
		eye.mesh = es
		eye.position = Vector3(s * 0.6, 0.25, 0)
		_face.add_child(eye)
		var cheek := MeshInstance3D.new()
		var cs := SphereMesh.new()
		cs.radius = 0.35
		cs.height = 0.2
		cs.material = WorldKit.mat(Color("#ffb3c7"), 1.0, 0.1)
		cheek.mesh = cs
		cheek.position = Vector3(s * 1.0, -0.25, 0.15)
		_face.add_child(cheek)
		var wing := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(2.6, 0.2, 1.4)
		pm.material = WorldKit.mat(Color("#dfe8ff"), 1.0, 0.1)
		wing.mesh = pm
		wing.position = Vector3(s * 2.4, 0.8, 0.4)
		wing.rotation.z = s * 0.4
		wing.name = "Wing" + ("L" if s < 0 else "R")
		_body.add_child(wing)
	var mouth := MeshInstance3D.new()
	var ms := SphereMesh.new()
	ms.radius = 0.3
	ms.height = 0.35
	ms.material = WorldKit.mat(Color("#5a3a6a"), 0.5)
	mouth.mesh = ms
	mouth.position = Vector3(0, -0.35, 0)
	mouth.name = "Mouth"
	_face.add_child(mouth)
	boss.position = _boss_pos


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0.5, 0)
	c.offset = Vector3(0, 15, 14)
	c.min_dist = 1.0
	c.max_dist = 1.0
	c.follow = false


func _build_hud() -> void:
	super._build_hud()
	_hp_bg = ColorRect.new()
	_hp_bg.color = Color(0.1, 0.05, 0.2, 0.7)
	UI.place(_hp_bg, Control.PRESET_CENTER_TOP, Vector2(-260, 92), Vector2(520, 26))
	_hud_root.add_child(_hp_bg)
	_hp_bar = ColorRect.new()
	_hp_bar.color = Color("#ff8fb8")
	_hp_bar.position = Vector2(3, 3)
	_hp_bar.size = Vector2(514, 20)
	_hp_bg.add_child(_hp_bar)
	var name_l := UI.label("Pustebacke, der Wolkendrache", 20, Color.WHITE, true, 6)
	UI.place(name_l, Control.PRESET_CENTER_TOP, Vector2(-260, 64), Vector2(520, 28))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_root.add_child(name_l)


func on_start() -> void:
	for av in avatars:
		(av as PartyAvatar).rig.surface = "grass"
		(av as PartyAvatar).can_shove = false


func on_tick(delta: float) -> void:
	if defeated:
		return
	_update_orbs(delta)
	_update_clouds(delta)
	_boss_ai(delta)
	_apply_boss_visuals(delta)


func _update_orbs(delta: float) -> void:
	_orb_t -= delta
	if _orb_t <= 0.0 and orbs.size() < 5:
		_orb_t = 1.1
		var a := rng.randf() * TAU
		var r := rng.randf_range(2.0, RADIUS - 2.0)
		var n := Assets.spawn("plat/coin", world, Vector3(cos(a) * r, 0.8, sin(a) * r), 0.0, 1.8)
		Assets.tint(n, Color(1.4, 1.0, 0.4), false, 0.9)
		Juice.pop_in(n, 0.3)
		orbs.append({"node": n, "holder": -1})
	for o in orbs.duplicate():
		var n: Node3D = o.node
		if int(o.holder) >= 0:
			var av := avatars[int(o.holder)] as Node3D
			n.position = av.global_position + Vector3.UP * 2.3
			continue
		n.rotation.y += delta * 3.0
		for i in active_slots():
			if not carry[i] and (avatars[i] as Node3D).global_position.distance_to(n.position) < 1.2:
				carry[i] = true
				o.holder = i
				Audio.sfx("item_get", n.position, -6.0)
				break
	for i in active_slots():
		if carry[i] and InputHub.pressed(i, "b"):
			_throw(i)


func _throw(i: int) -> void:
	carry[i] = false
	var orb: Dictionary = {}
	for o in orbs:
		if int(o.holder) == i:
			orb = o
	if orb.is_empty():
		return
	orbs.erase(orb)
	var n: Node3D = orb.node
	var av := avatars[i] as PartyAvatar
	av.rig.play("throw", 0.05, 1.5, true)
	var from := n.position
	var to := boss.position + Vector3(randf_range(-0.6, 0.6), 0, 0)
	var dist := from.distance_to(to)
	var hit := dist < 16.0 and _attack != "dash"
	var arc := func(t: float) -> void:
		n.position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * 2.5
	var tw := create_tween()
	tw.tween_method(arc, 0.0, 1.0, 0.35 + dist * 0.02)
	tw.tween_callback(func() -> void:
		n.queue_free()
		if hit and not defeated:
			var dmg := 4.0 if _attack == "dizzy" else 2.5
			hp = maxf(0.0, hp - dmg)
			scores[i] += dmg
			_flash = 0.25
			FX.stars(boss.position, Color(1, 0.9, 0.4), 14)
			Audio.sfx("punch", boss.position, 0.0, 1.2)
			Juice.float_text(self, boss.position + Vector3.UP * 2.5, "-%d" % int(dmg), Game.player_color(i).lightened(0.3), 120)
			Juice.squash(_body, 1.25, 0.8, 0.3)
			if hp <= 0.0:
				_defeat()
			elif hp < MAX_HP * (1.0 - _phase / 3.0):
				_phase += 1
				_attack = "dizzy"
				_atk_t = 3.0
				Audio.sfx("bong", boss.position)
				CutsceneManager.big_word("Pustebacke ist benommen!", UI.GOLD, 0.6)
		else:
			FX.dust(n.position, Color(1, 1, 0.8), 6, 0.5))


func _boss_ai(delta: float) -> void:
	_atk_t -= delta
	match _attack:
		"idle":
			_boss_pos = _boss_pos.lerp(Vector3(sin(Time.get_ticks_msec() / 1400.0) * 5.0, 4.0, -5.0), delta * 1.5)
			if _atk_t <= 0.0:
				var options := ["wind", "rain", "dash"] if _phase >= 2 else ["wind", "rain"]
				_attack = options[rng.randi() % options.size()]
				_atk_t = {"wind": 3.2, "rain": 4.0, "dash": 2.6}[_attack]
				_start_attack()
		"wind":
			var dir := Vector3(0, 0, 1)
			for i in active_slots():
				var av := avatars[i] as PartyAvatar
				if av.alive and av.is_on_floor():
					av.velocity += dir * 9.0 * delta * (1.0 + _phase * 0.3)
			if _atk_t <= 0.0:
				_attack = "idle"
				_atk_t = lerpf(2.4, 1.2, (_phase - 1) / 2.0)
		"rain":
			if int(_atk_t * 4.0) != int((_atk_t + delta) * 4.0):
				var a := rng.randf() * TAU
				var r := rng.randf_range(0.0, RADIUS - 1.0)
				_spawn_cloud(Vector3(cos(a) * r, 0, sin(a) * r))
			if _atk_t <= 0.0:
				_attack = "idle"
				_atk_t = lerpf(2.2, 1.2, (_phase - 1) / 2.0)
		"dash":
			var k := clampf(1.0 - _atk_t / 2.6, 0.0, 1.0)
			_boss_pos = _dash_from.lerp(_dash_to, smoothstep(0.25, 1.0, k))
			_boss_pos.y = lerpf(4.0, 1.2, sin(k * PI))
			if k > 0.25:
				for i in active_slots():
					var av := avatars[i] as PartyAvatar
					if av.alive and av.global_position.distance_to(_boss_pos) < 2.4:
						av.apply_knockback(av.global_position - _boss_pos, 16.0, 0.9, 7.0)
						scores[i] = maxf(0.0, scores[i] - 1.0)
			if _atk_t <= 0.0:
				_attack = "idle"
				_atk_t = 2.0
		"dizzy":
			_boss_pos = _boss_pos.lerp(Vector3(_boss_pos.x, 1.6, -3.0), delta * 3.0)
			_body.rotation.z = sin(Time.get_ticks_msec() / 90.0) * 0.2
			if _atk_t <= 0.0:
				_attack = "idle"
				_atk_t = 1.5
				_body.rotation.z = 0.0
	for i in active_slots():
		var av := avatars[i] as PartyAvatar
		if av.global_position.y < -4.0:
			av.respawn(Vector3(0, 2.0, 4.0))
			scores[i] = maxf(0.0, scores[i] - 2.0)


func _start_attack() -> void:
	match _attack:
		"wind":
			Audio.sfx("whoosh", boss.position, 2.0, 0.6)
			var wind := FX.emitter({"amount": 60, "life": 1.4, "one_shot": false, "explosive": 0.0, "spread": 12.0, "dir": Vector3(0, -0.1, 1),
				"vel_min": 12.0, "vel_max": 16.0, "gravity": Vector3.ZERO, "size": 0.6, "color": Color(1, 1, 1, 0.45), "box": Vector3(9, 1, 1)})
			world.add_child(wind)
			wind.position = boss.position + Vector3(0, -2.5, 1.5)
			wind.emitting = true
			get_tree().create_timer(3.0, false).timeout.connect(func() -> void:
				wind.emitting = false
				get_tree().create_timer(1.6, false).timeout.connect(wind.queue_free))
		"rain":
			Audio.sfx("thunder", boss.position, -8.0, 1.4)
		"dash":
			var target := Vector3.ZERO
			var living := active_slots()
			if not living.is_empty():
				target = (avatars[living[rng.randi() % living.size()]] as Node3D).global_position
			_dash_from = _boss_pos
			_dash_to = target + (target - _boss_pos).normalized() * 6.0
			_dash_to.y = 4.0
			Audio.sfx("whistle_fall", boss.position, -2.0)
			FX.emote(boss, "!", Color(1, 0.4, 0.4), 3.2, 0.6)


func _spawn_cloud(p: Vector3) -> void:
	var shadow := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.4, 2.4)
	q.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = FX.tex_soft
	m.albedo_color = Color(0.3, 0.3, 0.5, 0.5)
	q.material = m
	shadow.mesh = q
	world.add_child(shadow)
	shadow.position = p + Vector3.UP * 0.05
	var cl := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.8
	sm.height = 1.1
	sm.material = WorldKit.mat(Color("#c9cfe8"), 1.0, 0.1)
	cl.mesh = sm
	world.add_child(cl)
	cl.position = p + Vector3.UP * 9.0
	clouds.append({"node": cl, "shadow": shadow, "p": p, "t": 1.2})


func _update_clouds(delta: float) -> void:
	for c in clouds.duplicate():
		c.t = float(c.t) - delta
		var n: Node3D = c.node
		var p: Vector3 = c.p
		n.position = p + Vector3.UP * (0.6 + 8.4 * maxf(float(c.t), 0.0) / 1.2)
		if float(c.t) <= 0.0:
			FX.splash(p + Vector3.UP * 0.2, 0.6)
			Audio.sfx("splash", p, -8.0, 1.4)
			for i in active_slots():
				var av := avatars[i] as PartyAvatar
				if av.alive and Vector2(av.global_position.x - p.x, av.global_position.z - p.z).length() < 1.4:
					av.apply_knockback(av.global_position - p, 9.0, 1.0, 4.0)
					av.rig.react("dizzy")
					scores[i] = maxf(0.0, scores[i] - 1.0)
			n.queue_free()
			(c.shadow as Node3D).queue_free()
			clouds.erase(c)


func _apply_boss_visuals(delta: float) -> void:
	boss.position = boss.position.lerp(_boss_pos, clampf(delta * 8.0, 0.0, 1.0))
	boss.position.y += sin(Time.get_ticks_msec() / 300.0) * 0.01
	var wl := _body.get_node("WingL") as Node3D
	var wr := _body.get_node("WingR") as Node3D
	var flap := sin(Time.get_ticks_msec() / 140.0) * 0.4
	wl.rotation.z = -0.4 + flap
	wr.rotation.z = 0.4 - flap
	var mouth := _face.get_node("Mouth") as Node3D
	mouth.scale = Vector3.ONE * (1.8 if _attack == "wind" else 1.0)
	_flash = maxf(0.0, _flash - delta)
	_body.scale = Vector3.ONE * (1.0 + _flash * 0.4)
	if _hp_bar:
		_hp_bar.size.x = 514.0 * hp / MAX_HP
	boss.look_at(Vector3(boss.position.x * 0.3, boss.position.y, 9.0), Vector3.UP)


func _defeat() -> void:
	defeated = true
	Audio.jingle("win")
	Juice.slowmo(0.3, 1.0)
	FX.confetti(boss.position, 120)
	FX.explosion(boss.position, 1.0, false)
	for i in active_slots():
		(avatars[i] as PartyAvatar).rig.react("victory")
	var tw := boss.create_tween()
	tw.tween_property(boss, "position", boss.position + Vector3(0, 12, -20), 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(boss, "scale", Vector3.ONE * 0.4, 1.6)
	CutsceneManager.big_word("Pustebacke flieht!", UI.GOLD, 0.8)
	await get_tree().create_timer(2.0, false).timeout
	for i in active_slots():
		scores[i] += 5.0
	end_game()


func check_end() -> bool:
	return false


func net_pack() -> Dictionary:
	var d := super.net_pack()
	d["b"] = [snappedf(_boss_pos.x, 0.01), snappedf(_boss_pos.y, 0.01), snappedf(_boss_pos.z, 0.01)]
	d["hp"] = snappedf(hp, 0.1)
	d["at"] = _attack
	var ob: Array = []
	for o in orbs:
		var p := (o.node as Node3D).position
		ob.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)])
	d["ob"] = ob
	var cl: Array = []
	for c in clouds:
		var cp: Vector3 = c.p
		cl.append([snappedf(cp.x, 0.01), snappedf(cp.z, 0.01), snappedf(float(c.t), 0.01)])
	d["cl"] = cl
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var b: Array = d.get("b", [0, 4, -6])
	_boss_pos = Vector3(float(b[0]), float(b[1]), float(b[2]))
	var old_hp := hp
	hp = float(d.get("hp", hp))
	if hp < old_hp:
		_flash = 0.25
		FX.stars(boss.position, Color(1, 0.9, 0.4), 8)
	_attack = String(d.get("at", _attack))
	var ob: Array = d.get("ob", [])
	while orbs.size() > ob.size():
		(orbs[0].node as Node3D).queue_free()
		orbs.remove_at(0)
	while orbs.size() < ob.size():
		var n := Assets.spawn("plat/coin", world, Vector3.ZERO, 0.0, 1.8)
		Assets.tint(n, Color(1.4, 1.0, 0.4), false, 0.9)
		orbs.append({"node": n, "holder": -1})
	for k in ob.size():
		(orbs[k].node as Node3D).position = Vector3(float(ob[k][0]), float(ob[k][1]), float(ob[k][2]))
	var cl: Array = d.get("cl", [])
	while clouds.size() > cl.size():
		(clouds[0].node as Node3D).queue_free()
		(clouds[0].shadow as Node3D).queue_free()
		clouds.remove_at(0)
	while clouds.size() < cl.size():
		_spawn_cloud(Vector3.ZERO)
	for k in cl.size():
		clouds[k].p = Vector3(float(cl[k][0]), 0, float(cl[k][1]))
		clouds[k].t = float(cl[k][2])
		(clouds[k].shadow as Node3D).position = clouds[k].p + Vector3.UP * 0.05
		(clouds[k].node as Node3D).position = clouds[k].p + Vector3.UP * (0.6 + 8.4 * maxf(float(cl[k][2]), 0.0) / 1.2)
	_apply_boss_visuals(0.05)


func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	var level: int = Game.players[slot].cpu_level
	var pos := av.global_position
	var mv := Vector2.ZERO
	var held := {}
	if carry[slot]:
		var to := Vector2(boss.position.x - pos.x, boss.position.z - pos.z)
		if to.length() < [9.0, 11.0, 13.0][level] and randf() < 0.08:
			held["b"] = true
		else:
			mv = to.normalized() * 0.6
	else:
		var best := Vector3.INF
		for o in orbs:
			if int(o.holder) < 0:
				var p: Vector3 = (o.node as Node3D).position
				if best == Vector3.INF or p.distance_to(pos) < best.distance_to(pos):
					best = p
		if best != Vector3.INF:
			mv = Vector2(best.x - pos.x, best.z - pos.z).normalized()
	for c in clouds:
		var p2: Vector3 = c.p
		var d := Vector2(pos.x - p2.x, pos.z - p2.z)
		if d.length() < 2.0 and float(c.t) < [0.5, 0.8, 1.1][level]:
			mv = d.normalized()
	if _attack == "dash" and level > 0:
		var d2 := Vector2(pos.x - _boss_pos.x, pos.z - _boss_pos.z)
		if d2.length() < 4.0:
			mv = Vector2(-d2.y, d2.x).normalized()
	if _attack == "wind":
		mv.y -= 0.5
	if Vector2(pos.x, pos.z).length() > RADIUS - 2.0:
		mv += -Vector2(pos.x, pos.z).normalized()
	InputHub.set_virtual(slot, mv.limit_length(1.0), held)


func result_extra() -> Dictionary:
	return {"boss_defeated": hp <= 0.0}
