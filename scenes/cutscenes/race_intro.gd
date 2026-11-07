extends Cutscene
## Rennen-Intro: Flug entlang der Strecke (Looping, Gleiter-Schlucht, Unterwasser-Tunnel),
## dann Kamerafahrt durch die Startaufstellung bis hinter das Kart des Spielers.

func run(d: Node, ctx: Dictionary) -> void:
	var race: Node3D = ctx.race
	var track: RaceTrack = race.track
	var L := track.length
	var pts: Array = []
	var looks: Array = []
	for k in 7:
		var s := L * (0.08 + k * 0.13)
		var fr := track.frame(s)
		pts.append(fr.origin + fr.basis.y * 14.0 - fr.basis.x * 18.0 + Vector3.UP * 6.0)
		looks.append(track.frame(s + 25.0).origin)
	d.cut(pts[0], looks[0], 60.0)
	d.title(track.def.name, "Nitro Dash · %d Runden" % int(race.laps), 0.0, Color("#7fd6ff"))
	Audio.jingle("round", false)
	await d.fly_path(pts, looks, 5.2, 55.0)
	d.hide_text()
	# Startaufstellung
	var racers: Array = race.racers
	var first: Racer = racers[0]
	var last: Racer = racers[racers.size() - 1]
	var a := first.global_position + first.global_basis.x * 9.0 + Vector3.UP * 3.0 - first.global_basis.z * 6.0
	d.cut(a, first.global_position, 50.0)
	for r in racers:
		(r as Racer).visual.hero.react(["wave", "determined", "cheer", "taunt"][randi() % 4])
	var focus: Racer = race.focus
	await d.move(last.global_position + last.global_basis.x * 7.0 + Vector3.UP * 2.5 + last.global_basis.z * 4.0, focus.global_position + Vector3.UP, 1.6, 48.0)
	focus.visual.hero.look_at_point(d.cam.global_position, 1.0)
	focus.visual.hero.react("determined")
	d.subtitle("%s ist bereit!" % focus.display_name, 1.0)
	await d.wait(0.8)
	focus.visual.hero.clear_look()
	var fr2 := focus.global_transform
	await d.move(fr2.origin + fr2.basis.z * 6.4 + fr2.basis.y * 3.6, fr2.origin - fr2.basis.z * 6.0 + Vector3.UP * 1.0, 0.9, 68.0)
