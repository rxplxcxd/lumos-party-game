extends Cutscene
## Siegerehrung & Podest-Drama.
## 3. und 2. Platz werden enthüllt, der Sieger bekommt eine goldene Spotlight-Dusche,
## Konfetti-Kanonen und eine epische Pose. Der Letzte stolpert über die eigenen Füße,
## fällt rückwärts von der Bühne – und bekommt zur Krönung einen Amboss auf den Kopf.
##
## ctx.ranking: Array[int] Spielerindizes (Party) ODER ctx.entries: [{model, name, color}]

const STAGE := Vector3(0, 0, 90)
## Letzter Platz: vorne rechts auf der Bühne – deutlich vor und neben den Konfetti-Kanonen (x = ±7,5 / z = 2,5),
## damit beim Sturz nach vorne nichts ineinander clippt.
const LOSER_SPOT := Vector3(5.3, 0.7, 2.4)
const CANNON_X := 7.5

var _rigs: Array[CharacterRig] = []
var _win_style := "golden"   # golden | fireworks | star
var _gag := "anvil"          # anvil | pie | rain | bounce


func _pick(n: int) -> int:
	# Online-Party: gemeinsamer Brett-Zufall → alle sehen dieselbe Siegerehrung
	return (Game.prng.randi() if not Game.party.is_empty() else randi()) % n


func run(d: Node, ctx: Dictionary) -> void:
	var entries: Array = ctx.get("entries", [])
	if entries.is_empty():
		for p in ctx.get("ranking", [0, 1, 2, 3]):
			entries.append({"model": Game.hero(Game.players[p].hero).model, "name": Game.hero(Game.players[p].hero).name,
				"color": Game.player_color(p), "player": p})
	_win_style = ["golden", "fireworks", "star"][_pick(3)]
	_gag = ["anvil", "pie", "rain", "bounce"][_pick(4)]
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
			r.global_position = STAGE + LOSER_SPOT
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
	match _win_style:
		"fireworks":
			_fireworks(STAGE + spots[0] + Vector3.UP * 2.4)
		"star":
			_star_float(w, STAGE + spots[0] + Vector3.UP * 2.4)
		_:
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
		match _gag:
			"pie":
				await _gag_pie(d, entries[3])
			"rain":
				await _gag_rain(d, entries[3])
			"bounce":
				await _gag_bounce(d, entries[3])
			_:
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
	# Boden vor der Bühne (dort landet der Letzte) und die Bühne selbst
	WorldKit.box(s, Vector3(34, 0.2, 20), Vector3(0, -0.1, 4), Color("#3a2a5a"), false)
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
	for x in [-CANNON_X, CANNON_X]:
		var c := Assets.spawn("pirate/cannon", self, STAGE + Vector3(x, 0.7, 2.5), 0.0, 1.6)
		c.look_at(STAGE + Vector3(0, 7, 0), Vector3.UP)   # Mündung (-Z) zielt schräg nach oben zur Bühnenmitte
		Audio.sfx("cannon", c.global_position)
		FX.confetti(c.global_position + Vector3.UP * 1.2, 90, (Vector3(-x, 9, -2)).normalized(), 18.0)
		FX.smoke(c.global_position + Vector3.UP, Color(1, 1, 1), 6, 0.8)
	Juice.shake(0.3)


func _loser_gag(d: Node, e: Dictionary) -> void:
	var r := _rigs[3]
	var pos := r.global_position
	d.cut(pos + Vector3(-2.5, 1.8, 7.0), pos + Vector3.UP * 1.2, 42.0)
	d.subtitle("Und auf dem letzten Platz … %s!" % e.name, 1.4)
	r.face_now(Vector3(0, 0, 1))
	r.react("wave")
	await d.wait(1.2)
	# Stolpert über die eigenen Füße – nach vorne von der Bühne auf den Boden (weg von den Kanonen)
	r.play("walk", 0.1, 1.0)
	var tw := r.create_tween()
	tw.tween_property(r, "global_position", pos + Vector3(0, 0, 1.4), 0.6)
	await tw.finished
	r.react("trip_fall")
	Audio.sfx("whistle_fall", pos)
	var land := Vector3(pos.x - 0.4, STAGE.y, STAGE.z + 5.6)
	var start := r.global_position
	d.move(land + Vector3(-1.8, 2.4, 6.2), land + Vector3.UP * 0.8, 0.55, 42.0)
	var tw2 := r.create_tween()
	tw2.tween_method(func(t: float) -> void:
		r.global_position = start.lerp(land, t) + Vector3.UP * sin(t * PI) * 0.6, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw2.finished
	r.global_position = land
	r.land_impact(1.2)
	d.shake(0.25)
	await d.wait(0.8)
	# … und dann der Amboss
	var hit_pos := r.global_position
	var anvil := Assets.spawn("rpg/anvil", self, hit_pos + Vector3.UP * 14.0, 0.0, 1.2)
	# Amboss steht mit der Unterseite exakt auf dem Kopf bzw. danach auf der plattgedrückten Figur
	var ab := _bounds(anvil)
	var foot := anvil.global_position.y - ab.position.y
	Audio.sfx("whistle_fall", hit_pos)
	d.move(hit_pos + Vector3(-1.0, 2.2, 6.0), hit_pos + Vector3.UP * 1.0, 0.6, 40.0)
	var head_y := hit_pos.y + _bounds(r).size.y * 0.9
	var tw3 := anvil.create_tween()
	tw3.tween_property(anvil, "global_position", Vector3(hit_pos.x, head_y + foot, hit_pos.z), 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw3.finished
	anvil.create_tween().tween_property(anvil, "global_position:y", hit_pos.y + 0.42 + foot, 0.08)
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
	var tw5 := anvil.create_tween()
	tw5.tween_property(anvil, "global_position", anvil.global_position + Vector3(-1.2, 0, 0.6), 0.4).set_trans(Tween.TRANS_BACK)
	await tw5.finished
	await d.wait(0.8)
	anvil.queue_free()


## Weltraum-Begrenzungsbox eines Modells (für passgenaues Aufsetzen).
func _bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in Assets.find_meshes(n):
		var bb := mi.global_transform * mi.get_aabb()
		out = bb if first else out.merge(bb)
		first = false
	if first:
		return AABB(n.global_position, Vector3(1, 1.6, 1))
	return out


# --- Weitere Sieger-Feiern ------------------------------------------------------------------------------

func _fireworks(pos: Vector3) -> void:
	var cols := [Color("#ff5c7a"), Color("#ffd23f"), Color("#7fd6ff"), Color("#b6f29a"), Color("#c9b5ff")]
	for k in 7:
		var p := pos + Vector3(randf_range(-6, 6), randf_range(6, 10), randf_range(-3, 0))
		get_tree().create_timer(0.25 + k * 0.35).timeout.connect(func() -> void:
			if not is_inside_tree():
				return
			FX.stars(p, cols[k % cols.size()], 26)
			FX.confetti(p, 30)
			FX.flash_light(p, cols[k % cols.size()], 6.0, 0.4)
			Audio.sfx("explosion", null, -16.0, 1.6 + randf() * 0.3, 0.0)
			Audio.sfx("sparkle_up", null, -10.0, 1.0 + k * 0.05, 0.0))


func _star_float(w: CharacterRig, pos: Vector3) -> void:
	var star := Assets.spawn("plat/star", self, pos + Vector3(0, 0.5, -1.2), 0.0, 0.1)
	Assets.tint(star, Color(1.1, 1.0, 0.6), false, 0.9)
	var tw := star.create_tween()
	tw.tween_property(star, "scale", Vector3.ONE * 3.2, 0.6).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(star, "position:y", pos.y + 3.4, 0.6)
	var spin := star.create_tween().set_loops()
	spin.tween_property(star, "rotation:y", TAU, 2.0).as_relative()
	var lift := w.create_tween()
	lift.tween_property(w, "global_position:y", pos.y + 0.9, 1.0).set_trans(Tween.TRANS_SINE)
	lift.tween_property(w, "global_position:y", pos.y, 1.0).set_trans(Tween.TRANS_SINE)
	FX.stars(pos + Vector3.UP * 2.0, Color(1, 0.9, 0.4), 30)
	Audio.sfx("sparkle_up", null, -4.0)


# --- Weitere Verlierer-Gags (alle auf dem Boden vor der Bühne, fern der Kanonen) --------------------------

func _gag_intro(d: Node, e: Dictionary) -> CharacterRig:
	var r := _rigs[3]
	var pos := r.global_position
	d.cut(pos + Vector3(-2.5, 1.8, 7.0), pos + Vector3.UP * 1.2, 42.0)
	d.subtitle("Und auf dem letzten Platz … %s!" % e.name, 1.4)
	r.face_now(Vector3(0, 0, 1))
	r.react("wave")
	await d.wait(1.2)
	return r


## Torte ins Gesicht: aus dem Off fliegt eine Sahnetorte, Sahne spritzt.
func _gag_pie(d: Node, e: Dictionary) -> void:
	var r: CharacterRig = await _gag_intro(d, e)
	var head := r.global_position + Vector3.UP * 1.4
	var pie := Node3D.new()
	add_child(pie)
	var base := WorldKit.cylinder(pie, 0.45, 0.25, Vector3.ZERO, Color("#c98d5a"), false)
	base.name = "Base"
	var cream := MeshInstance3D.new()
	var cs := SphereMesh.new()
	cs.radius = 0.42
	cs.height = 0.4
	cs.material = WorldKit.mat(Color("#fffaf2"), 0.7)
	cream.mesh = cs
	cream.position = Vector3(0, 0.15, 0)
	pie.add_child(cream)
	pie.global_position = head + Vector3(-9, 2.5, 3)
	pie.rotation.z = PI * 0.5
	Audio.sfx("whoosh", head, -2.0, 1.2)
	await arc(pie, pie.global_position, head + Vector3(0, 0, 0.3), 1.5, 0.55)
	Audio.sfx("slime", head, 0.0, 0.9)
	Audio.sfx("plop", head, -2.0)
	FX.smoke(head, Color(1, 1, 0.96), 16, 0.9)
	FX.dust(head, Color(1, 0.98, 0.92), 14, 1.2)
	d.shake(0.3)
	r.set_soot(4.0)
	r.react("sad")
	var fall := pie.create_tween()
	fall.tween_property(pie, "global_position:y", r.global_position.y + 0.1, 0.5).set_trans(Tween.TRANS_BOUNCE)
	await d.wait(0.6)
	Audio.sfx("sad_trombone")
	await d.wait(2.0)
	pie.queue_free()


## Persönliche Regenwolke: graue Wolke über dem Kopf, es tropft.
func _gag_rain(d: Node, e: Dictionary) -> void:
	var r: CharacterRig = await _gag_intro(d, e)
	var top := r.global_position + Vector3.UP * 3.4
	var cloud := Node3D.new()
	add_child(cloud)
	cloud.global_position = top + Vector3(0, 3, 0)
	for k in 4:
		var puff := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.6
		sm.height = 0.9
		sm.material = WorldKit.mat(Color("#8a90a8"), 1.0)
		puff.mesh = sm
		puff.position = Vector3(k * 0.5 - 0.75, sin(k * 1.7) * 0.15, 0)
		cloud.add_child(puff)
	var tw := cloud.create_tween()
	tw.tween_property(cloud, "global_position", top, 0.6).set_trans(Tween.TRANS_BACK)
	await tw.finished
	Audio.sfx("thunder", top, -12.0, 1.5)
	var rain := FX.emitter({"amount": 60, "life": 0.6, "one_shot": false, "explosive": 0.0, "spread": 4.0, "dir": Vector3.DOWN,
		"vel_min": 6.0, "vel_max": 8.0, "gravity": Vector3(0, -10, 0), "size": 0.08, "color": Color(0.6, 0.75, 1.0, 0.9), "box": Vector3(1.2, 0.1, 0.6)})
	cloud.add_child(rain)
	rain.position = Vector3(0, -0.4, 0)
	rain.emitting = true
	r.react("sad")
	FX.dizzy_stars(r, 0.6, 1.0)
	await d.wait(1.2)
	Audio.sfx("sigh", null, -2.0)
	Audio.sfx("sad_trombone")
	await d.wait(2.0)
	cloud.queue_free()


## Hüpfpilz: wippt fröhlich, wird zu hoch katapultiert und landet kopfüber im Blumenbeet.
func _gag_bounce(d: Node, e: Dictionary) -> void:
	var r: CharacterRig = await _gag_intro(d, e)
	var pos := r.global_position
	var land := Vector3(pos.x - 1.0, STAGE.y, STAGE.z + 6.0)
	var shroom := Assets.spawn("plat/mushrooms", self, land + Vector3(0, 0, 0), 0.0, 1.8)
	var bed := Assets.spawn("plat/flowers", self, land + Vector3(-2.2, 0, 0.6), 0.0, 2.2)
	bed.name = "Bed"
	var start := r.global_position
	await arc(r, start, land + Vector3.UP * 1.2, 1.4, 0.5)
	Audio.sfx("boing", land, -2.0)
	Juice.squash(shroom, 1.3, 0.6, 0.3, shroom.scale)
	await arc(r, r.global_position, land + Vector3.UP * 1.2, 1.0, 0.4)
	Audio.sfx("boing", land, 0.0, 1.3)
	Juice.squash(shroom, 1.4, 0.5, 0.3, shroom.scale)
	r.react("launch")
	Audio.sfx("whistle_up", land, -4.0)
	var target := land + Vector3(-2.2, 0.0, 0.6)
	d.move(target + Vector3(-1.5, 3.0, 7.0), target + Vector3.UP * 1.5, 1.0, 44.0)
	var spin := r.create_tween()
	spin.tween_method(func(t: float) -> void:
		r.global_position = (land + Vector3.UP * 1.2).lerp(target, t) + Vector3.UP * sin(t * PI) * 6.0
		r.rotation.x = t * TAU * 1.5, 0.0, 1.0, 1.1)
	await spin.finished
	r.rotation.x = PI
	r.global_position = target + Vector3.UP * 1.3
	FX.dust(target, Color(1.0, 0.8, 0.9), 16, 1.2)
	FX.stars(target + Vector3.UP, Color(1, 0.9, 0.4), 12)
	Audio.sfx("plop", target, 0.0)
	d.shake(0.35)
	await d.wait(1.0)
	Audio.sfx("sad_trombone")
	await d.wait(1.2)
	var flip := r.create_tween()
	flip.tween_property(r, "rotation:x", 0.0, 0.4).set_trans(Tween.TRANS_BACK)
	flip.parallel().tween_property(r, "global_position", target, 0.4)
	r.react("dizzy")
	await d.wait(0.8)
