extends Cutscene
## Piraten-Plank-Feld: Ein Fass kracht auf das andere Plankenende, der Spieler wird im
## hohen Bogen ein Brett zurück katapultiert und verliert 10 Münzen.

const BACK_STEPS := 7
const STOLEN := 10

func run(d: Node, ctx: Dictionary) -> void:
	var board: Node3D = ctx.board
	var p: int = ctx.player
	var rig: CharacterRig = board.rigs[p]
	var spaces: Array = board.spaces
	var start: int = Game.players[p].space
	var target := start
	for i in BACK_STEPS:
		target = spaces[target].prev[0]
	var from := rig.global_position
	var side := Vector3(1, 0, 0)
	d.cut(from + side * 7.0 + Vector3(0, 2.5, 3.0), from + Vector3.UP * 1.0, 48.0)
	rig.face_now(Vector3(0, 0, 1))
	rig.react("shocked")
	await d.wait(0.5)
	# Fass fällt auf die Planke
	var barrel := Assets.spawn("pirate/barrel", self, from + Vector3(-1.6, 9.0, 0), 0.0, 1.2)
	Audio.sfx("whistle_fall", from)
	var tw := barrel.create_tween()
	tw.tween_property(barrel, "global_position", from + Vector3(-1.6, 0.3, 0), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	Audio.sfx("wood_hit", from)
	Audio.sfx("boing", from)
	Juice.squash(barrel, 1.4, 0.6, 0.4, Vector3.ONE * 1.2)
	d.shake(0.5)
	Juice.hitstop(0.08)
	InputHub.rumble(p, 1.0, 0.3)
	FX.dust(from, Color(0.9, 0.8, 0.6), 14)
	# Münzen fliegen davon
	var lost := Game.add_coins(p, -STOLEN)
	FX.coins_burst(from, absi(lost), false)
	if lost != 0:
		Juice.float_text(board, from + Vector3.UP * 3.0, str(lost), Color("#ff6b6b"), 120)
	# Katapult
	rig.react("launch")
	var to: Vector3 = board._space_pos(target)
	var dur := 1.7
	var tw2 := create_tween()
	tw2.tween_method(func(t: float) -> void:
		rig.global_position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * 13.0
		rig.pivot.rotation.x = t * TAU * 1.5, 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE)
	d.track(rig, Vector3(0, 6, 12), dur, Vector3.UP, 4.0)
	await tw2.finished
	rig.pivot.rotation.x = 0.0
	rig.land_impact(1.4)
	rig.react("land_flat")
	d.shake(0.4)
	Game.players[p].space = target
	await d.move(to + Vector3(0, 4, 7), to + Vector3.UP, 0.6, 45.0)
	await d.wait(1.0)
	barrel.queue_free()
