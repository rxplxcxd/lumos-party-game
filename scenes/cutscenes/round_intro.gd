extends Cutscene
## Runden-Start-Intro: 360°-Kurvenflug über das Brett, schlafende Gegner, zuckende Fallen,
## dann Zoom auf den Startspieler, der entschlossen in die Kamera grinst – "3… 2… 1… LOS!"

func run(d: Node, ctx: Dictionary) -> void:
	var board: Node3D = ctx.board
	var builder: BoardBuilder = board.builder
	var center := Vector3(0, 0, 0)
	Audio.jingle("round", false)
	d.cut(center + Vector3(0, 30, 46), center, 55.0)
	d.title(builder.def.name, "Lumos Party · %d Runden" % int(Game.party.max_rounds), 0.0, Color("#ffcc33"))
	# 1) dynamische 360-Grad-Kurve
	await d.orbit(center, 44.0, 26.0, 0.0, 200.0, 3.6, 52.0, 0.0, 30.0, 16.0)
	d.hide_text()

	# 2) schlafende Gegner
	if builder.sleepers.size() > 0:
		var s: Node3D = builder.sleepers[randi() % builder.sleepers.size()]
		FX.zzz(s, 2.6, 2.5)
		if s is CharacterRig:
			(s as CharacterRig).play("sit" if (s as CharacterRig).has_clip("sit") else "idle")
		var dir := (s.global_position - center).normalized()
		d.cut(s.global_position + dir * 6.0 + Vector3(2.0, 3.0, 0.0), s.global_position + Vector3.UP * 1.2, 40.0)
		d.subtitle("Psst … die Gegner schlafen noch.", 1.2)
		await d.move(s.global_position + dir * 4.5 + Vector3(1.0, 2.2, 0), s.global_position + Vector3.UP * 1.4, 1.4, 34.0)

	# 3) zuckende Fallen
	if builder.traps.size() > 0:
		var trap: Node3D = builder.traps[randi() % builder.traps.size()]
		var tp := trap.global_position
		d.cut(tp + Vector3(3.5, 3.0, 4.5), tp + Vector3.UP * 0.5, 45.0)
		for i in 3:
			Juice.squash(trap, 1.25, 0.75, 0.25, trap.scale)
			Audio.sfx("creak", tp, -2.0, 1.0 + i * 0.15)
			FX.dust(tp, Color(0.85, 0.8, 0.7), 6)
			await d.wait(0.35)
		d.subtitle("Die Fallen zucken schon …", 1.0)
		await d.wait(0.5)

	# 4) Startspieler
	var rig: CharacterRig = board.rigs[0]
	var front := rig.global_position + Vector3(0, 1.7, 4.2)
	d.cut(rig.global_position + Vector3(0, 6, 12), rig.global_position + Vector3.UP * 1.2, 50.0)
	await d.move(front, rig.global_position + Vector3.UP * 1.45, 0.9, 38.0, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	rig.face_now(front - rig.global_position)
	rig.look_at_point(front, 1.0)
	rig.react("determined")
	d.punch(-8.0, 0.35)
	d.subtitle("%s beginnt!" % Game.hero(Game.players[0].hero).name, 1.0)
	await d.wait(1.0)
	await d.countdown("LOS!")
	rig.clear_look()
