extends Cutscene
## Minispiel-Teaser: schneller Cine-Orbit über die Arena mit Titelkarte, danach betreten die Spieler die
## Arena mit einem themenpassenden Auftritt:
##   * Kanone (Standard): Das Rohr schwenkt auf jedes Ziel und richtet sich auf den echten Abschusswinkel
##     der Flugbahn auf, Rückstoß + Rauch, die Mündung wandert mit.
##   * Piratenschiff (Piraten-Arenen): Ein kleines Schiff segelt heran, alle springen nacheinander an Land.
##   * Eisschollen (Schnee): Jede Figur rutscht auf einer eigenen Scholle herein und hüpft ab.
##   * Wolken (Himmel/Sternwarte): Wölkchen schweben über den Startpunkten, die Figuren plumpsen herab.
##   * Portal (Nacht/Geister/Dungeon): Ein funkelnder Ring öffnet sich, die Figuren steigen heraus.
## Dabei werden hohe Deko-Objekte, die Kamera und Spieler trennen, ausgeblendet (auch für die Spielkamera).

var _hidden: Array[Node3D] = []
var _ids: Array[int] = []   # nur teilnehmende Figuren (im Duell sind zwei auf der Bank: deaktiviert, ihre Tweens liefen nie)


func run(d: Node, ctx: Dictionary) -> void:
	var g: MinigameBase = ctx.game
	var c := g.arena_center
	var r := g.arena_radius
	var targets: Array[Vector3] = []
	for i in 4:
		if g.active[i]:
			_ids.append(i)
		var a: Node3D = g.actors[i]
		targets.append(a.global_position)
		a.visible = false
		if a is PartyAvatar:
			a.set_physics_process(false)

	# 1) Arena-Flug mit Titel
	var th: float = g.teaser_height
	d.cut(c + Vector3(r * 1.6, r * th * 0.7, r * 1.6), c, 62.0)
	d.title(g.info.get("name", ""), "Minispiel!", 0.0, Color("#ffcc33"))
	Audio.jingle("minigame_start", false)
	await d.orbit(c, r * 1.55, r * th, 45.0, 140.0, 2.3, 48.0, 0.0, r * 1.25, r * th * 1.25)
	d.hide_text()

	# Sichtachsen frei räumen: Spielkamera → Startpunkte (bleibt fürs Spiel ausgeblendet)
	if is_instance_valid(g.cam):
		for t in targets:
			_hide_occluders(g, g.cam.global_position, t + Vector3.UP * 1.0, true)

	# 2) Auftritt (Minispiele können einen eigenen Auftritt liefern)
	if g.has_method("custom_entrance"):
		await g.custom_entrance(d, targets, self)
		await d.move(g.cam.global_position, g.arena_center + g.cam.look_offset, 0.8, g.cam.fov)
		for i in _ids:
			var a3: Node3D = g.actors[i]
			if a3 is PartyAvatar:
				a3.set_physics_process(true)
		return
	match _entrance_style(g):
		"ship":
			await _ship_entrance(d, g, targets)
		"ice":
			await _ice_entrance(d, g, targets)
		"cloud":
			await _cloud_entrance(d, g, targets)
		"portal":
			await _portal_entrance(d, g, targets)
		_:
			await _cannon_entrance(d, g, targets)

	# 3) Kamera geht in Spielposition
	await d.move(g.cam.global_position, g.arena_center + g.cam.look_offset, 0.8, g.cam.fov)
	for n in _hidden:
		if is_instance_valid(n) and not n.has_meta("keep_hidden"):
			n.visible = true
	for i in _ids:
		var a2: Node3D = g.actors[i]
		if a2 is PartyAvatar:
			a2.set_physics_process(true)


func _entrance_style(g: MinigameBase) -> String:
	match g.env_preset:
		"pirates":
			return "ship"
		"snow":
			return "ice"
		"sky", "observatory":
			return "cloud"
		"ghost", "night", "dungeon", "graveyard", "forest_night":
			return "portal"
	return "cannon"


# --- Sichtfreiheit ---------------------------------------------------------------------------------------

## Blendet hohe Deko zwischen Kamera und Ziel aus. Böden/Plattformen (groß oder unter dem Ziel) bleiben.
func _hide_occluders(g: MinigameBase, from: Vector3, to: Vector3, for_game := false) -> void:
	for child in g.world.get_children():
		var n := child as Node3D
		if n == null or not n.visible or n in g.actors or n.has_meta("keep_visible"):
			continue   # z. B. der Boss selbst – nie als Sichthindernis ausblenden
		var bb := _bounds(n)
		if bb.size == Vector3.ZERO:
			continue
		if bb.size.x > 16.0 or bb.size.z > 16.0 or bb.size.y < 1.3:
			continue   # Boden, Plattform oder flache Deko
		if bb.end.y < to.y - 0.3:
			continue
		var hit := false
		for k in range(1, 20):
			var p := from.lerp(to, k / 20.0)
			if bb.grow(0.35).has_point(p):
				hit = true
				break
		if hit:
			n.visible = false
			if for_game:
				n.set_meta("keep_hidden", true)
			_hidden.append(n)


func _bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in Assets.find_meshes(n):
		var bb := mi.global_transform * mi.get_aabb()
		out = bb if first else out.merge(bb)
		first = false
	return out


func _land(g: MinigameBase, i: int, t: Vector3, reactions: Array) -> void:
	var rig: CharacterRig = g.rigs[i]
	if rig:
		rig.land_impact(1.1)
		rig.turn_to(Vector3(0, 0, 1), 0.28)
		rig.react(String(reactions[(i + randi()) % reactions.size()]))
	FX.dust(t, Color(0.9, 0.85, 0.75), 8, 0.8)
	Audio.sfx("plop", null, -6.0, 0.9 + i * 0.08)
	InputHub.rumble(i, 0.4, 0.12)


# --- Kanone (zielt pro Schuss) ---------------------------------------------------------------------------

func _cannon_entrance(d: Node, g: MinigameBase, targets: Array[Vector3]) -> void:
	var c := g.arena_center
	var cannon_pos: Vector3 = g.cannon_pos
	var base := Node3D.new()
	add_child(base)
	base.global_position = cannon_pos
	var cannon := Assets.spawn("pirate/cannon", base, Vector3.ZERO, 0.0, 2.6)
	var toward := Vector3(c.x - cannon_pos.x, 0, c.z - cannon_pos.z).normalized()
	_aim(base, toward, 0.0)
	Juice.pop_in(base, 0.3)
	var side := toward.cross(Vector3.UP)
	_hide_occluders(g, cannon_pos + side * 7.0 + Vector3.UP * 3.0 - toward * 2.0, (cannon_pos + c) * 0.5 + Vector3.UP)
	d.cut(cannon_pos + side * 7.0 + Vector3.UP * 3.0 - toward * 2.0, (cannon_pos + c) * 0.5 + Vector3.UP, 55.0)
	await d.wait(0.25)
	var reactions := ["wave", "scared", "determined", "cheer"]
	for i in _ids:
		var actor: Node3D = g.actors[i]
		var rig: CharacterRig = g.rigs[i]
		var tgt := targets[i]
		# Rohr auf das Ziel schwenken und auf den Abschusswinkel der Flugbahn aufrichten
		var flat := Vector3(tgt.x - cannon_pos.x, 0, tgt.z - cannon_pos.z)
		var dist := maxf(flat.length(), 0.5)
		var height := 5.0 + dist * 0.12
		var elev := atan2(PI * height + (tgt.y - cannon_pos.y), dist)
		await _aim_tween(base, flat.normalized(), elev, 0.28)
		var muzzle := cannon_pos + _barrel_dir(flat.normalized(), elev) * 2.2 + Vector3.UP * 1.2
		actor.global_position = muzzle
		actor.visible = true
		Audio.sfx("cannon", muzzle)
		FX.smoke(muzzle, Color(0.85, 0.85, 0.85), 8, 0.8)
		FX.sparks(muzzle, Color(1, 0.7, 0.3), 10)
		d.shake(0.25)
		# Rückstoß: Rohr ruckt zurück und federt wieder vor
		var rec := base.create_tween()
		rec.tween_property(base, "global_position", cannon_pos - flat.normalized() * 0.6, 0.06)
		rec.tween_property(base, "global_position", cannon_pos, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		Juice.squash(cannon, 1.2, 0.8, 0.3, Vector3.ONE * 2.6)
		if rig:
			rig.face_now(tgt - muzzle)
			rig.react("launch")
		var flight := 0.75
		var mid := (muzzle + tgt) * 0.5
		d.move(mid + side * 6.0 + Vector3.UP * 4.0, mid + Vector3.UP * 1.5, flight * 0.9, 58.0)
		await arc(actor, muzzle, tgt, height, flight)
		_land(g, i, tgt, reactions)
		await d.wait(0.12)
	FX.smoke(cannon_pos + Vector3.UP, Color(1, 1, 1), 10, 1.2)
	Audio.sfx("pop", cannon_pos)
	var tw := base.create_tween()
	tw.tween_property(base, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


## Laufrichtung des Rohrs bei Gier "dir" und Elevation "elev".
func _barrel_dir(dir: Vector3, elev: float) -> Vector3:
	return (dir * cos(elev) + Vector3.UP * sin(elev)).normalized()


func _aim(base: Node3D, dir: Vector3, elev: float) -> void:
	var fwd := _barrel_dir(dir, elev)
	var b := Basis.looking_at(fwd, Vector3.UP)    # Kanonen-Modell: Mündung zeigt entlang -Z
	base.global_basis = b


func _aim_tween(base: Node3D, dir: Vector3, elev: float, dur: float) -> void:
	var from := base.global_basis.get_rotation_quaternion()
	var to := Basis.looking_at(_barrel_dir(dir, elev), Vector3.UP).get_rotation_quaternion()
	Audio.sfx("creak", base.global_position, -10.0, 1.3)
	var tw := base.create_tween()
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(base):
			base.global_basis = Basis(from.slerp(to, t)), 0.0, 1.0, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished


# --- Piratenschiff -------------------------------------------------------------------------------------

func _ship_entrance(d: Node, g: MinigameBase, targets: Array[Vector3]) -> void:
	var c := g.arena_center
	var dock: Vector3 = g.cannon_pos
	var out := Vector3(dock.x - c.x, 0, dock.z - c.z).normalized()
	var ship := Node3D.new()
	add_child(ship)
	var model := Assets.spawn("pirate/ship_small", ship, Vector3.ZERO, 0.0, 1.2)
	model.rotation.y = atan2(out.x, out.z) + PI * 0.5
	var stop := dock + out * 3.5 + Vector3(0, -0.4, 0)
	ship.global_position = stop + out * 26.0 + out.cross(Vector3.UP) * 6.0
	var cam_p := stop + out.cross(Vector3.UP) * 22.0 + Vector3.UP * 9.0 - out * 6.0
	d.cut(cam_p, stop - out * 3.0 + Vector3.UP * 1.0, 50.0)
	_hide_occluders(g, cam_p, stop + Vector3.UP * 1.5)
	Audio.sfx("whistle_up", stop, -8.0, 0.8)
	var sail := ship.create_tween()
	sail.tween_property(ship, "global_position", stop, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var bob := model.create_tween().set_loops()
	bob.tween_property(model, "rotation:z", 0.06, 0.7).set_trans(Tween.TRANS_SINE)
	bob.tween_property(model, "rotation:z", -0.06, 0.7).set_trans(Tween.TRANS_SINE)
	await sail.finished
	FX.splash(stop, 1.0)
	Audio.sfx("splash", stop, -4.0)
	var reactions := ["cheer", "wave", "determined", "laugh"]
	var deck := stop + Vector3.UP * 2.4
	for i in _ids:
		var actor: Node3D = g.actors[i]
		var rig: CharacterRig = g.rigs[i]
		actor.global_position = deck + out.cross(Vector3.UP) * (i - 1.5) * 0.7
		actor.visible = true
		if rig:
			rig.face_now(targets[i] - actor.global_position)
			rig.play("jump_start", 0.05, 1.4, true)
		Audio.sfx("jump", deck, -4.0)
		var mid := (deck + targets[i]) * 0.5
		d.move(mid + out.cross(Vector3.UP) * 7.0 + Vector3.UP * 4.0, mid + Vector3.UP * 1.2, 0.6, 54.0)
		await arc(actor, actor.global_position, targets[i], 2.8, 0.6)
		_land(g, i, targets[i], reactions)
		await d.wait(0.08)
	var leave := ship.create_tween()
	leave.tween_property(ship, "global_position", stop + out * 30.0, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	leave.tween_callback(ship.queue_free)


# --- Eisschollen ------------------------------------------------------------------------------------------

func _ice_entrance(d: Node, g: MinigameBase, targets: Array[Vector3]) -> void:
	var c := g.arena_center
	var reactions := ["cheer", "wave", "determined", "laugh"]
	d.cut(c + Vector3(0, g.arena_radius * 0.9, g.arena_radius * 1.6), c, 55.0)
	var slides: Array = []
	for i in _ids:
		var tgt := targets[i]
		var dir := Vector3(tgt.x - c.x, 0, tgt.z - c.z)
		if dir.length() < 0.5:
			dir = Vector3(i - 1.5, 0, 1)
		dir = dir.normalized()
		var start := tgt + dir * (g.arena_radius + 6.0) + Vector3.UP * 0.05
		var floe := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.5, 0.18, 1.5)
		var m := WorldKit.mat(Color(0.8, 0.93, 1.0, 0.85), 0.05, 0.25)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.material = m
		floe.mesh = bm
		add_child(floe)
		floe.global_position = start
		var actor: Node3D = g.actors[i]
		actor.global_position = start + Vector3.UP * 0.1
		actor.visible = true
		slides.append([floe, actor, start, tgt, i])
		var rig: CharacterRig = g.rigs[i]
		if rig:
			rig.face_now(tgt - start)
			rig.play("idle")
	Audio.sfx("drift", c, -4.0, 1.3)
	var tw := create_tween().set_parallel(true)
	for k in slides.size():
		var s: Array = slides[k]
		var floe: Node3D = s[0]
		var actor2: Node3D = s[1]
		var from: Vector3 = s[2]
		var to: Vector3 = s[3]
		tw.tween_method(func(t: float) -> void:
			var p := from.lerp(to - (to - from).normalized() * 0.8, ease(t, -1.8))
			floe.global_position = p
			actor2.global_position = p + Vector3.UP * 0.1
			floe.rotation.y = t * 1.2, 0.0, 1.0, 1.6 + k * 0.12)
	await tw.finished
	for k in slides.size():
		var s2: Array = slides[k]
		var actor3: Node3D = s2[1]
		await arc(actor3, actor3.global_position, s2[3], 1.2, 0.3)
		_land(g, int(s2[4]), s2[3], reactions)
		var floe2: Node3D = s2[0]
		var ft := floe2.create_tween()
		ft.tween_property(floe2, "scale", Vector3.ZERO, 0.4)
		ft.tween_callback(floe2.queue_free)
		FX.sparks(s2[3], Color(0.8, 0.95, 1.0), 8)


# --- Wolken ----------------------------------------------------------------------------------------------

func _cloud_entrance(d: Node, g: MinigameBase, targets: Array[Vector3]) -> void:
	var c := g.arena_center
	var reactions := ["cheer", "wave", "determined", "scared"]
	d.cut(c + Vector3(0, g.arena_radius * 1.0, g.arena_radius * 1.7), c + Vector3.UP * 2.0, 55.0)
	var clouds := {}   # Spieler → Wolke (im Duell sind nicht alle Plätze dabei)
	for i in _ids:
		var cl := Node3D.new()
		add_child(cl)
		cl.global_position = targets[i] + Vector3.UP * 6.0
		for k in 4:
			var puff := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.8
			sm.height = 1.1
			sm.material = WorldKit.mat(Color.WHITE, 1.0, 0.15)
			puff.mesh = sm
			puff.position = Vector3(k * 0.6 - 0.9, sin(k) * 0.15, 0)
			cl.add_child(puff)
		Juice.pop_in(cl, 0.3)
		clouds[i] = cl
	Audio.sfx("sparkle_up", null, -6.0)
	await d.wait(0.45)
	for i in _ids:
		var actor: Node3D = g.actors[i]
		actor.global_position = targets[i] + Vector3.UP * 5.6
		actor.visible = true
		var rig: CharacterRig = g.rigs[i]
		if rig:
			rig.react("scared")
		Audio.sfx("whistle_fall", targets[i], -8.0, 1.4)
		var tw := actor.create_tween()
		tw.tween_property(actor, "global_position", targets[i], 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
		_land(g, i, targets[i], reactions)
		var cl2: Node3D = clouds[i]
		var ct := cl2.create_tween()
		ct.tween_property(cl2, "global_position", cl2.global_position + Vector3(0, 6, -4), 1.2)
		ct.parallel().tween_property(cl2, "scale", Vector3.ZERO, 1.2)
		ct.tween_callback(cl2.queue_free)


# --- Portal ----------------------------------------------------------------------------------------------

func _portal_entrance(d: Node, g: MinigameBase, targets: Array[Vector3]) -> void:
	var c := g.arena_center
	var reactions := ["wave", "determined", "cheer", "scared"]
	d.cut(c + Vector3(0, g.arena_radius * 0.9, g.arena_radius * 1.6), c, 55.0)
	for i in _ids:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.7
		tm.outer_radius = 0.9
		tm.material = WorldKit.mat(Color("#c9b5ff"), 0.3, 1.6)
		ring.mesh = tm
		add_child(ring)
		ring.global_position = targets[i] + Vector3.UP * 0.05
		ring.scale = Vector3.ZERO
		var rt := ring.create_tween()
		rt.tween_property(ring, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
		var actor: Node3D = g.actors[i]
		actor.global_position = targets[i] + Vector3.DOWN * 1.8
		actor.visible = true
		FX.sparks(targets[i] + Vector3.UP * 0.4, Color("#d9c2ff"), 14)
		Audio.sfx("sparkle_up", null, -6.0, 0.9 + i * 0.1)
		var up := actor.create_tween()
		up.tween_property(actor, "global_position", targets[i], 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await up.finished
		_land(g, i, targets[i], reactions)
		# Der Aufpopp-Tween ist längst fertig – fürs Einklappen einen neuen anlegen (sonst bleibt der Ring liegen)
		var rt2 := ring.create_tween()
		rt2.tween_property(ring, "scale", Vector3.ZERO, 0.3)
		rt2.tween_callback(ring.queue_free)
		await d.wait(0.1)
