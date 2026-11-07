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
		var look := s.global_position + Vector3.UP * 1.2
		var dir := _clear_dir(builder, look, 6.0)
		if s is CharacterRig:
			(s as CharacterRig).face_now(dir)
		var hidden := _hide_occluders(builder, look + dir * 6.0 + Vector3.UP * 2.0, look, s)
		d.cut(look + dir * 6.0 + Vector3.UP * 2.0, look, 40.0)
		d.subtitle("Psst … die Gegner schlafen noch.", 1.2)
		await d.move(look + dir * 4.5 + Vector3.UP * 1.2, look + Vector3.UP * 0.2, 1.4, 34.0)
		for n in hidden:
			if is_instance_valid(n):
				n.visible = true

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


## Kulissen-Objekte (Katalog-Modelle), die zwischen Kamera und Ziel stehen.
static func _occluders(builder: BoardBuilder, cam_pos: Vector3, target: Vector3, ignore: Node = null) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var a := Vector2(cam_pos.x, cam_pos.z)
	var b := Vector2(target.x, target.z)
	var seg := b - a
	var len2 := maxf(seg.length_squared(), 0.001)
	for c in builder.root.get_children():
		if not (c is Node3D) or c == ignore or (c as Node3D).scene_file_path == "" or not (c as Node3D).visible:
			continue
		var n := c as Node3D
		var p := Vector2(n.global_position.x, n.global_position.z)
		var t := clampf((p - a).dot(seg) / len2, 0.0, 1.0)
		if t > 0.9:
			continue   # direkt am Ziel: gehört zur Szene
		if p.distance_to(a + seg * t) < 1.8:
			out.append(n)
	return out


## Richtung (vom Ziel weg), aus der möglichst nichts im Bild steht. Bevorzugt Blick von +Z (Brett-Kamera).
static func _clear_dir(builder: BoardBuilder, target: Vector3, dist: float) -> Vector3:
	var best := Vector3.BACK
	var best_score := INF
	for k in 16:
		var ang := TAU * k / 16.0
		var dir := Vector3(sin(ang), 0, cos(ang))
		var score := float(_occluders(builder, target + dir * dist + Vector3.UP * 2.0, target).size()) * 10.0
		score += (1.0 - dir.z) * 0.8
		if score < best_score:
			best_score = score
			best = dir
	return best


static func _hide_occluders(builder: BoardBuilder, cam_pos: Vector3, target: Vector3, ignore: Node) -> Array[Node3D]:
	var list := _occluders(builder, cam_pos, target, ignore)
	for n in list:
		n.visible = false
	return list
