extends Cutscene
## Dungeon-Fluch-Feld: Ein Geist erscheint mit fiesem Lachen und vertauscht die Positionen
## der beiden am weitesten voneinander entfernten Spieler.

func run(d: Node, ctx: Dictionary) -> void:
	var board: Node3D = ctx.board
	var rigs: Array = board.rigs
	var a := 0
	var b := 1
	var best := -1.0
	for i in 4:
		for j in range(i + 1, 4):
			var dist: float = (rigs[i] as Node3D).global_position.distance_to((rigs[j] as Node3D).global_position)
			if dist > best:
				best = dist
				a = i
				b = j
	var ra: CharacterRig = rigs[a]
	var rb: CharacterRig = rigs[b]
	var mid := (ra.global_position + rb.global_position) * 0.5
	# Geist erscheint
	var ghost := CharacterRig.new()
	add_child(ghost)
	ghost.setup("npc/ghost", -1, 4.0)
	ghost.global_position = mid + Vector3.UP * 6.0
	Assets.tint(ghost.model, Color(0.85, 0.75, 1.0, 0.75), false, 0.5)
	ghost.play("idle")
	Juice.pop_in(ghost, 0.5)
	d.cut(mid + Vector3(0, 14, 22), mid + Vector3.UP * 5.0, 55.0)
	Audio.sfx("ghost", mid)
	Audio.sfx("evil_laugh", mid)
	FX.smoke(mid + Vector3.UP * 6.0, Color(0.6, 0.3, 0.9), 14, 1.6)
	d.subtitle("Ein Fluch! %s und %s tauschen die Plätze!" % [Game.hero(Game.players[a].hero).name, Game.hero(Game.players[b].hero).name], 1.6)
	var spin := ghost.create_tween().set_loops(4)
	spin.tween_property(ghost, "rotation:y", TAU, 0.5).as_relative()
	await d.wait(1.2)
	ra.react("cursed")
	rb.react("cursed")
	var pa := ra.global_position
	var pb := rb.global_position
	for r in [ra, rb]:
		FX.smoke((r as Node3D).global_position, Color(0.55, 0.25, 0.85), 10, 0.9)
	Audio.sfx("swap", mid)
	Juice.shake(0.3)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var side := (pb - pa).cross(Vector3.UP).normalized() * sin(t * PI) * 4.0
		ra.global_position = pa.lerp(pb, t) + Vector3.UP * sin(t * PI) * 8.0 + side
		rb.global_position = pb.lerp(pa, t) + Vector3.UP * sin(t * PI) * 8.0 - side
		ra.rotation.y = t * TAU * 2.0
		rb.rotation.y = -t * TAU * 2.0, 0.0, 1.0, 1.6).set_trans(Tween.TRANS_SINE)
	await tw.finished
	ra.land_impact(1.0)
	rb.land_impact(1.0)
	ra.react("dizzy")
	rb.react("dizzy")
	var sa: int = Game.players[a].space
	Game.players[a].space = Game.players[b].space
	Game.players[b].space = sa
	var tw2 := ghost.create_tween()
	tw2.tween_property(ghost, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	Audio.sfx("pop", ghost.global_position)
	await d.wait(1.4)
