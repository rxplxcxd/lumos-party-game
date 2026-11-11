extends Cutscene
## Sieger-Moment nach jedem Minispiel: Kamera umkreist den/die Sieger, die jubeln
## (Konfetti), während die Verlierer frustriert auf den Boden hämmern oder traurig sitzen.

func run(d: Node, ctx: Dictionary) -> void:
	var g: MinigameBase = ctx.game
	var places: Array[int] = ctx.placements
	var winners: Array[int] = []
	for i in 4:
		if places[i] == 1:
			winners.append(i)
	var focus := Vector3.ZERO
	var n := 0
	for w in winners:
		var a: Node3D = g.actors[w]
		if a and a.visible:
			focus += a.global_position
			n += 1
	if n == 0:
		focus = g.arena_center
	else:
		focus /= n
	for i in 4:
		var rig: CharacterRig = g.rigs[i]
		if rig == null or not (g.actors[i] as Node3D).visible:
			continue
		rig.unlock()
		if places[i] == 1:
			rig.turn_to(Vector3(0, 0, 1), 0.3)
			rig.react("victory")
		elif places[i] == 4 or places[i] == 3:
			rig.react("tantrum" if randf() < 0.6 else "sad")
		else:
			rig.react("frustrated")
	FX.confetti(focus + Vector3.UP * 3.0, 70)
	Audio.voice("winner" if winners.size() == 1 else "tie")
	Audio.sfx("crowd")
	Audio.sfx("sparkle_up", null, -2.0, 1.0, 0.0)
	Audio.sfx("ui_select_big", null, -4.0, 1.0, 0.0)
	get_tree().create_timer(0.9).timeout.connect(func() -> void:
		Audio.sfx("sigh", null, -6.0, 1.0, 0.0)
		Audio.sfx("coin_sad", null, -10.0, 0.9, 0.0))
	var who := ""
	for w in winners:
		who += ("" if who == "" else " & ") + Game.hero(Game.players[w].hero).name
	d.title(who, "gewinnt!" if winners.size() == 1 else "gewinnen!", 0.0, Color("#ffcc33"))
	await d.orbit(focus, 5.5, 2.4, -35.0, 35.0, 2.6, 42.0, 1.2, 4.2, 1.8)
	d.punch(-6.0, 0.4)
	await d.wait(0.4)
	d.hide_text()
