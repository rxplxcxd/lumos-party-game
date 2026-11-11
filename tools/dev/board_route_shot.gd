extends Node
## Kontrollbilder der Routen-Extras eines Bretts (Schlüsseltor, Geheimgang, Schatz-Umweg) aus Schrägsicht.
##   xvfb-run ./godot --path . --resolution 1280x720 res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/board_route_shot.gd
##     --board=meadow --out=/pfad


func run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var tree := get_tree()
	get_parent().remove_child.call_deferred(self)
	tree.root.add_child.call_deferred(self)
	await tree.process_frame
	await tree.process_frame
	var id := String(args.get("board", "meadow"))
	var out := String(args.get("out", "user://shots"))
	DirAccess.make_dir_recursive_absolute(out)
	Game.reset_players(0)
	Game.start_party(id, 5, "classic")
	var world := Node3D.new()
	add_child(world)
	WorldKit.env(world, String(BoardDefs.get_def(id).env))
	var spaces := BoardDefs.build_graph(BoardDefs.get_def(id))
	var b := BoardBuilder.new()
	b.build(world, id, spaces)
	var cam := Camera3D.new()
	cam.fov = 50.0
	world.add_child(cam)
	cam.make_current()
	var def: Dictionary = b.def
	for bi in def.branches.size():
		var br: Dictionary = def.branches[bi]
		var kind := String(br.get("kind", ""))
		if not kind in ["express", "treasure_detour"]:
			continue
		var mid := Vector3.ZERO
		var n := 0
		for sp in spaces:
			if int(sp.branch) == bi:
				mid += sp.pos
				n += 1
		mid /= maxf(1.0, n)
		var focus: Vector3 = (spaces[br.from].pos as Vector3).lerp(mid, 0.5) if kind == "express" else mid
		cam.position = focus + Vector3(0, 9, 11)
		cam.look_at(focus, Vector3.UP)
		for k in 30:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out, id, kind])
		if bool(br.get("secret", false)):
			b.reveal_branch(bi, true, false)
			for k in 10:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("%s/%s_%s_revealed.png" % [out, id, kind])
	print("SHOTS OK")
	get_tree().quit()
