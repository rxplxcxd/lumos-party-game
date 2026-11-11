extends Node
## Übersichtsbild einer Minispiel-Arena aus schräger Vogelperspektive (zum Prüfen von Deko und Weltgrenzen).
##   xvfb-run ./godot --path . --resolution 1280x720 res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/arena_overview.gd --only=id,id --out=/pfad [--dist=40]


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
	var out := String(args.get("out", "user://shots"))
	DirAccess.make_dir_recursive_absolute(out)
	var dist := float(args.get("dist", "38"))
	for id in String(args.get("only", "")).split(",", false):
		var m: Dictionary = Game.minigame_info(id)
		for p in Game.players:
			p.cpu = true
		if args.has("human"):
			Game.players[0].cpu = false   # Erklärkarte bleibt stehen (wartet auf Bestätigung)
		Game.mode = "free_play"
		var cats: Array = m.get("cats", ["ffa"])
		Game.minigame_setup = {"cat": String(cats[0])}
		tree.change_scene_to_file(String(m.scene))
		await tree.create_timer(float(args.get("wait", "11"))).timeout
		if args.has("card"):
			tree.root.get_texture().get_image().save_png("%s/%s_card.png" % [out, id])
			continue
		var cam := Camera3D.new()
		cam.fov = 60.0
		cam.far = 900.0
		tree.current_scene.add_child(cam)
		for side in [0, 1]:
			cam.position = Vector3(dist * (0.55 if side == 0 else -0.55), dist * 0.62, dist * (0.8 if side == 0 else -0.8))
			cam.look_at(Vector3.ZERO, Vector3.UP)
			cam.make_current()
			for k in 6:
				await tree.process_frame
			tree.root.get_texture().get_image().save_png("%s/%s_%d.png" % [out, id, side])
	print("SHOTS OK")
	tree.quit()
