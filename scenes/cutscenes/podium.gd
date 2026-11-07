extends Cutscene
## Siegerehrung & Podest-Drama.
## 3. und 2. Platz werden enthüllt, der Sieger bekommt eine goldene Spotlight-Dusche,
## Konfetti-Kanonen und eine epische Pose. Der Letzte stolpert über die eigenen Füße,
## fällt rückwärts von der Bühne – und bekommt zur Krönung einen Amboss auf den Kopf.
##
## ctx.ranking: Array[int] Spielerindizes (Party) ODER ctx.entries: [{model, name, color}]

const STAGE := Vector3(0, 0, 90)

var _rigs: Array[CharacterRig] = []


func run(d: Node, ctx: Dictionary) -> void:
	var entries: Array = ctx.get("entries", [])
	if entries.is_empty():
		for p in ctx.get("ranking", [0, 1, 2, 3]):
			entries.append({"model": Game.hero(Game.players[p].hero).model, "name": Game.hero(Game.players[p].hero).name,
				"color": Game.player_color(p), "player": p})
	_build_stage()
	var heights := [2.4, 1.6, 1.0]
	var spots := [Vector3(0, 0, 0), Vector3(-3.2, 0, 0.4), Vector3(3.2, 0, 0.4)]
	for i in mini(entries.size(), 4):
		var e: Dictionary = entries[i]
		var r := CharacterRig.new()
		add_child(r)
		r.setup(e.model, e.get("player", -1), 1.0)
		if i < 3:
			r.global_position = STAGE + spots[i] + Vector3.UP * heights[i]
		else:
			r.global_position = STAGE + Vector3(6.4, 0.6, 1.6)
		r.face_now(Vector3(0, 0, 1))
		r.visible = i >= 3
		_rigs.append(r)
	Audio.music("podium", 0.6)
	await d.fade(true, 0.3)
	d.cut(STAGE + Vector3(0, 6, 22), STAGE + Vector3.UP * 2.0, 50.0)
	await d.fade(false, 0.4)
	d.title("Siegerehrung", "", 1.4, Color("#ffcc33"))
	await d.move(STAGE + Vector3(0, 4, 16), STAGE + Vector3.UP * 2.5, 1.4, 45.0)

	# 3. Platz
	if entries.size() > 2:
		await _reveal(d, 2, entries[2], "3. Platz", Color("#e0a070"), "wave")
	# 2. Platz
	if entries.size() > 1:
		await _reveal(d, 1, entries[1], "2. Platz", Color("#dfe8f0"), "cheer")
	# 1. Platz – Drama!
	Audio.sfx("drumroll")
	d.cut(STAGE + Vector3(0, 3.5, 10), STAGE + Vector3.UP * 3.0, 40.0)
	await d.wait(1.5)
	var w := _rigs[0]
	w.visible = true
	Juice.pop_in(w.pivot, 0.4)
	w.hop(1.6, 0.5)
	_golden_shower(STAGE + spots[0] + Vector3.UP * 2.4)
	_confetti_cannons()
	Audio.jingle("fanfare")
	Audio.sfx("crowd")
	Audio.voice("congratulations")
	w.react("victory")
	d.title(entries[0].name, "ist der große Sieger!", 0.0, Color("#ffcc33"))
	await d.orbit(STAGE + spots[0] + Vector3.UP * 2.4, 6.0, 1.6, -40.0, 40.0, 3.2, 36.0, 1.4, 4.5, 1.0)
	d.punch(-10.0, 0.4)
	await d.wait(0.6)
	d.hide_text()

	# Letzter Platz – Slapstick
	if _rigs.size() > 3:
		await _loser_gag(d, entries[3])

	# Schlussbild
	for i in mini(3, _rigs.size()):
		_rigs[i].react("cheer" if i == 0 else "wave")
	FX.confetti(STAGE + Vector3(0, 8, 0), 120)
	d.cut(STAGE + Vector3(0, 5, 17), STAGE + Vector3.UP * 2.2, 48.0)
	d.title("Danke fürs Spielen!", "Lumos Party", 0.0, Color.WHITE)
	await d.move(STAGE + Vector3(0, 7, 20), STAGE + Vector3.UP * 2.2, 2.6, 52.0)
	await d.wait(0.6)
	d.hide_text()


func _reveal(d: Node, i: int, e: Dictionary, place: String, color: Color, reaction: String) -> void:
	var r := _rigs[i]
	var pos := r.global_position
	d.cut(pos + Vector3(0, 1.5, 7.5), pos + Vector3.UP * 1.3, 42.0)
	await d.wait(0.3)
	r.visible = true
	Juice.pop_in(r.pivot, 0.35)
	FX.stars(pos + Vector3.UP, color, 14)
	Audio.sfx("pop", pos)
	var spot := SpotLight3D.new()
	spot.light_color = color
	spot.light_energy = 6.0
	spot.spot_range = 12.0
	spot.spot_angle = 18.0
	add_child(spot)
	spot.global_position = pos + Vector3.UP * 9.0
	spot.look_at(pos, Vector3.FORWARD)
	r.react(reaction)
	d.title(e.name, place, 0.0, color)
	await d.wait(1.6)
	d.hide_text()


func _build_stage() -> void:
	var s := Node3D.new()
	add_child(s)
	s.global_position = STAGE
	WorldKit.box(s, Vector3(16, 0.6, 8), Vector3(0, 0.3, 0), Color("#5a2a8a"), false)
	WorldKit.box(s, Vector3(16.4, 0.15, 8.4), Vector3(0, 0.62, 0), Color("#ffcc33"), false)
	WorldKit.box(s, Vector3(2.4, 2.4, 2.4), Vector3(0, 1.2, 0), Color("#ffcc33"), false)
	WorldKit.box(s, Vector3(2.4, 1.6, 2.4), Vector3(-3.2, 0.8, 0.4), Color("#dfe8f0"), false)
	WorldKit.box(s, Vector3(2.4, 1.0, 2.4), Vector3(3.2, 0.5, 0.4), Color("#e0a070"), false)
	for pair in [["1", Vector3(0, 1.2, 1.22)], ["2", Vector3(-3.2, 0.8, 1.62)], ["3", Vector3(3.2, 0.5, 1.62)]]:
		var l := Label3D.new()
		l.text = pair[0]
		l.font = UI.title_font()
		l.font_size = 180
		l.outline_size = 30
		l.pixel_size = 0.005
		l.position = pair[1]
		s.add_child(l)
	WorldKit.place(s, "arena/trophy", Vector3(0, 2.4, -0.6), 0.0, 2.5)
	for x in [-7.0, 7.0]:
		WorldKit.place(s, "arena/banner", Vector3(x, 0.6, -3.0), 0.0, 3.0)
		WorldKit.place(s, "arena/column", Vector3(x, 0.6, -3.6), 0.0, 3.0)
	WorldKit.place(s, "arena/statue", Vector3(0, 0.6, -3.6), 0.0, 3.0)
	WorldKit.box(s, Vector3(26, 12, 0.5), Vector3(0, 6, -4.5), Color("#1a0c3a"), false)
	var key := OmniLight3D.new()
	key.light_energy = 1.6
	key.omni_range = 26.0
	key.position = Vector3(0, 7, 8)
	s.add_child(key)
	for i in 6:
		var star := Assets.spawn("plat/star", s, Vector3(-10 + i * 4.0, 9.0 + (i % 2), -4.0), 0.0, 3.0)
		Assets.tint(star, Color(1.1, 1.0, 0.6), false, 0.5)


func _golden_shower(pos: Vector3) -> void:
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.85, 0.35)
	spot.light_energy = 14.0
	spot.spot_range = 16.0
	spot.spot_angle = 22.0
	add_child(spot)
	spot.global_position = pos + Vector3.UP * 11.0
	spot.look_at(pos, Vector3.FORWARD)
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = 3.0
	cm.height = 11.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.85, 0.35, 0.22)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	cm.material = m
	cone.mesh = cm
	add_child(cone)
	cone.global_position = pos + Vector3.UP * 5.5
	var gold := FX.burst(pos + Vector3.UP * 9.0, {"amount": 60, "life": 2.2, "one_shot": false, "explosive": 0.0, "dir": Vector3.DOWN,
		"spread": 14.0, "vel_min": 2.0, "vel_max": 4.0, "gravity": Vector3(0, -2, 0), "size": 0.35, "tex": FX.tex_star,
		"color": Color(1, 0.85, 0.3), "additive": true, "radius": 1.5})
	gold.emitting = true
	get_tree().create_timer(5.0).timeout.connect(func() -> void:
		if is_instance_valid(gold):
			gold.emitting = false)


func _confetti_cannons() -> void:
	for x in [-7.5, 7.5]:
		var c := Assets.spawn("pirate/cannon", self, STAGE + Vector3(x, 0.6, 2.5), 0.0, 1.8)
		c.look_at(STAGE + Vector3(0, 6, 0), Vector3.UP)
		c.rotate_object_local(Vector3.UP, PI)
		Audio.sfx("cannon", c.global_position)
		FX.confetti(c.global_position + Vector3.UP * 1.2, 90, (Vector3(-x, 9, -2)).normalized(), 18.0)
		FX.smoke(c.global_position + Vector3.UP, Color(1, 1, 1), 6, 0.8)
	Juice.shake(0.3)


func _loser_gag(d: Node, e: Dictionary) -> void:
	var r := _rigs[3]
	var pos := r.global_position
	d.cut(pos + Vector3(-1.5, 1.6, 6.5), pos + Vector3.UP * 1.2, 42.0)
	d.subtitle("Und auf dem letzten Platz … %s!" % e.name, 1.4)
	r.react("wave")
	await d.wait(1.2)
	# Stolpert über die eigenen Füße
	r.face_now(Vector3(-1, 0, 0))
	r.play("walk", 0.1, 1.0)
	var tw := r.create_tween()
	tw.tween_property(r, "global_position", pos + Vector3(0.9, 0, 0.0), 0.5)
	await tw.finished
	r.react("trip_fall")
	Audio.sfx("whistle_fall", pos)
	var tw2 := r.create_tween()
	tw2.tween_property(r, "global_position", pos + Vector3(2.2, -0.6, 1.4), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw2.finished
	r.land_impact(1.2)
	d.shake(0.25)
	await d.wait(0.8)
	# … und dann der Amboss
	var hit_pos := r.global_position
	var anvil := Assets.spawn("rpg/anvil", self, hit_pos + Vector3.UP * 14.0, 0.0, 1.3)
	Audio.sfx("whistle_fall", hit_pos)
	d.move(hit_pos + Vector3(0, 2.0, 5.5), hit_pos + Vector3.UP * 1.0, 0.6, 40.0)
	var tw3 := anvil.create_tween()
	tw3.tween_property(anvil, "global_position", hit_pos + Vector3.UP * 1.1, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw3.finished
	Audio.sfx("metal_hit", hit_pos)
	Audio.sfx("bell", hit_pos)
	Juice.hitstop(0.1)
	d.shake(0.6)
	FX.stars(hit_pos + Vector3.UP * 1.5, Color(1, 0.9, 0.3), 20)
	FX.dust(hit_pos, Color(0.8, 0.75, 0.7), 18, 1.4)
	r.pivot.scale = Vector3(1.6, 0.25, 1.6)
	FX.dizzy_stars(r, 0.9, 2.5)
	await d.wait(0.6)
	Audio.sfx("sad_trombone")
	await d.wait(2.0)
	var tw4 := r.pivot.create_tween()
	tw4.tween_property(r.pivot, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	r.react("dizzy")
	anvil.queue_free()
	await d.wait(0.8)
