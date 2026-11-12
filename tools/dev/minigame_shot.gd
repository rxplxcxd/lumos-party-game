extends Node
## Kontrollbilder eines Minispiels mit 4 CPUs: wartet auf die Spielphase und speichert zu den angegebenen
## Sekunden je ein PNG.
##   xvfb-run ./godot --path . --resolution 1280x720 res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/minigame_shot.gd
##     --only=nail_pro --out=/pfad --at=6,20


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
	var id := String(args.get("only", ""))
	var out := String(args.get("out", "user://shots"))
	DirAccess.make_dir_recursive_absolute(out)
	var m: Dictionary = Game.minigame_info(id)
	for p in Game.players:
		p.cpu = true
	Game.mode = "free_play"
	var cats: Array = m.get("cats", ["ffa"])
	var cs := {"cat": String(cats[0])}
	if cs.cat == "1v3":
		cs["solo"] = 0
	elif cs.cat == "2v2":
		cs["teams"] = [0, 1, 0, 1]
	if args.has("boss"):
		cs["boss"] = String(args.boss)   # Boss-Kampf: bestimmten Boss zeigen (--boss=ignis)
	Game.minigame_setup = cs
	tree.change_scene_to_file(String(m.scene))
	var mg: MinigameBase = null
	while mg == null:
		await tree.process_frame
		if tree.current_scene is MinigameBase:
			mg = tree.current_scene
	while mg.state != "play":
		await tree.process_frame
	var t0 := Time.get_ticks_msec()
	for at in String(args.get("at", "5")).split(","):
		while (Time.get_ticks_msec() - t0) / 1000.0 < float(at):
			await tree.process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(out.path_join("%s_%ss.png" % [id, at]))
		print("SHOT ", out.path_join("%s_%ss.png" % [id, at]))
	tree.quit()
