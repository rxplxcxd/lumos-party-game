extends Cutscene
## Team-Intro vor 1-gegen-3- und 2-gegen-2-Minispielen: Fanfare, Kamerafahrt zum Solo bzw. zu den
## Teams, winkende und posierende Figuren, großes "VS" mit Teamfarben.

func run(d: Node, ctx: Dictionary) -> void:
	var board: Node3D = ctx.board
	var setup: Dictionary = ctx.setup
	var rigs: Array = board.rigs
	var cat := String(setup.get("cat", "2v2"))
	var groups: Array = [[], []]
	if cat == "1v3":
		var solo := int(setup.get("solo", 0))
		for i in 4:
			(groups[0 if i == solo else 1] as Array).append(i)
	else:
		var tm: Array = setup.get("teams", [0, 1, 0, 1])
		for i in 4:
			if int(tm[i]) >= 0:
				(groups[int(tm[i])] as Array).append(i)
	Audio.jingle("round", false)
	Audio.sfx("drumroll", null, -4.0)
	var titles := {"1v3": "1 GEGEN 3!", "2v2": "2 GEGEN 2!", "duel": "DUELL!"}
	d.title(String(titles.get(cat, "2 GEGEN 2!")), "Duell-Minispiel" if cat == "duel" else "Team-Minispiel", 0.0, Color("#ffcc33"))
	for g in 2:
		var center := Vector3.ZERO
		for i in groups[g]:
			center += (rigs[i] as Node3D).global_position
		center /= float((groups[g] as Array).size())
		var side := Vector3(1.0 if g == 0 else -1.0, 0, 0)
		d.cut(center + Vector3(0, 3.2, 7.5) + side * 2.0, center + Vector3.UP * 1.2, 46.0)
		for i in groups[g]:
			var r: CharacterRig = rigs[i]
			r.face_now(d.cam.global_position - r.global_position)
			if (cat == "1v3" and g == 0) or cat == "duel":
				r.react("flex")
			else:
				r.react("wave" if randi() % 2 == 0 else "cheer")
			FX.stars(r.global_position + Vector3.UP * 2.2, Game.player_color(i).lightened(0.3), 8)
		var names: Array = (groups[g] as Array).map(func(i: int) -> String: return Game.hero(Game.players[i].hero).name)
		var label := ("Solo: " if cat == "1v3" and g == 0 else ("Team Blau: " if g == 0 else "Team Rot: ")) + " & ".join(names)
		if cat == "duel":
			label = ("Herausforderer: " if g == 0 else "Gegner: ") + " & ".join(names)
		d.subtitle(label, 1.2)
		await d.move(center + Vector3(0, 2.4, 5.2) - side * 1.2, center + Vector3.UP * 1.4, 1.3, 40.0)
	d.hide_text()
	d.flash(Color(1, 1, 1, 0.6), 0.2)
	Audio.sfx("bell")
	Juice.shake(0.2)
	await d.big_word("VS", Color("#ffcc33"), 0.7)
