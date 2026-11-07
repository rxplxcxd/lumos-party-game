extends Cutscene
## Minispiel-Teaser: schneller Cine-Orbit über die Arena mit Titelkarte, dann werden die
## Spieler nacheinander per Piratenkanone ins Bild geschossen und reagieren (winken,
## erschrecken, entschlossen grinsen).

func run(d: Node, ctx: Dictionary) -> void:
	var g: MinigameBase = ctx.game
	var c := g.arena_center
	var r := g.arena_radius
	var targets: Array[Vector3] = []
	for i in 4:
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

	# 2) Kanone am Rand
	var cannon_pos: Vector3 = g.cannon_pos
	var cannon := Assets.spawn("pirate/cannon", self, cannon_pos, 0.0, 2.6)
	cannon.look_at(Vector3(c.x, cannon_pos.y, c.z), Vector3.UP)
	cannon.rotate_object_local(Vector3.UP, PI)
	Juice.pop_in(cannon, 0.3)
	var muzzle := cannon_pos + (c - cannon_pos).normalized() * 1.6 + Vector3.UP * 1.3
	var side := (c - cannon_pos).normalized().cross(Vector3.UP)
	d.cut(cannon_pos + side * 7.0 + Vector3.UP * 3.0 - (c - cannon_pos).normalized() * 2.0, (cannon_pos + c) * 0.5 + Vector3.UP, 55.0)
	await d.wait(0.25)

	var reactions := ["wave", "scared", "determined", "cheer"]
	for i in 4:
		var actor: Node3D = g.actors[i]
		var rig: CharacterRig = g.rigs[i]
		actor.global_position = muzzle
		actor.visible = true
		Audio.sfx("cannon", muzzle)
		FX.smoke(muzzle, Color(0.85, 0.85, 0.85), 8, 0.8)
		FX.sparks(muzzle, Color(1, 0.7, 0.3), 10)
		d.shake(0.25)
		Juice.squash(cannon, 1.2, 0.8, 0.3, Vector3.ONE * 2.6)
		if rig:
			rig.face_now(targets[i] - muzzle)
			rig.react("launch")
		var flight := 0.75
		var mid := (muzzle + targets[i]) * 0.5
		d.move(mid + side * 6.0 + Vector3.UP * 4.0, mid + Vector3.UP * 1.5, flight * 0.9, 58.0)
		await arc(actor, muzzle, targets[i], 5.0, flight)
		if rig:
			rig.land_impact(1.1)
			rig.face_now(Vector3(0, 0, 1))
			rig.react(reactions[(i + randi()) % reactions.size()])
		InputHub.rumble(i, 0.4, 0.12)
		await d.wait(0.12)

	# 3) Kanone verschwindet mit Rauchwolke, Kamera geht in Spielposition
	FX.smoke(cannon_pos + Vector3.UP, Color(1, 1, 1), 10, 1.2)
	Audio.sfx("pop", cannon_pos)
	var tw := cannon.create_tween()
	tw.tween_property(cannon, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await d.move(g.cam.global_position, g.arena_center + g.cam.look_offset, 0.8, g.cam.fov)
	for i in 4:
		var a2: Node3D = g.actors[i]
		if a2 is PartyAvatar:
			a2.set_physics_process(true)
