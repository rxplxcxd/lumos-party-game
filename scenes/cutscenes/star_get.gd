extends Cutscene
## Stern-Erhalt: Der Lumos-Stern fliegt zum Spieler, der springt jubelnd hoch – Konfetti,
## Fanfare, riesiges "STERN!". Danach zieht der Stern um (bei Kauf, durch das Brett).

func run(d: Node, ctx: Dictionary) -> void:
	var board: Node3D = ctx.board
	var p: int = ctx.player
	var free: bool = ctx.get("free", false)
	var rig: CharacterRig = board.rigs[p]
	var star: Node3D = board.builder.star_node
	var rp := rig.global_position
	d.cut(rp + Vector3(0, 2.2, 6.5), rp + Vector3.UP * 1.8, 42.0)
	rig.face_now(Vector3(0, 0, 1))
	var from := star.global_position if star.visible else rp + Vector3.UP * 10.0
	var fly := Assets.spawn("plat/star", self, from, 0.0, 5.0)
	Assets.tint(fly, Color(1.2, 1.1, 0.6), false, 0.8)
	Audio.sfx("whistle_up", rp)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		fly.global_position = from.lerp(rp + Vector3.UP * 3.2, t) + Vector3.UP * sin(t * PI) * 3.0
		fly.rotation.y = t * TAU * 3.0, 0.0, 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	await tw.finished
	rig.react("star_get")
	Audio.jingle("fanfare")
	FX.confetti(rp + Vector3.UP * 2.5, 90)
	FX.stars(rp + Vector3.UP * 3.0, Color(1, 0.9, 0.3), 24)
	FX.flash_light(rp + Vector3.UP * 3.0, Color(1, 0.9, 0.5), 8.0, 0.8)
	d.punch(-10.0, 0.5)
	d.shake(0.25)
	InputHub.rumble(p, 0.8, 0.4)
	var tw2 := fly.create_tween()
	tw2.tween_property(fly, "scale", Vector3.ZERO, 0.4).set_delay(0.5)
	board.grant_star(p, not free)
	await d.big_word("STERN!", Color("#ffcc33"), 1.2)
	await d.wait(0.6)
