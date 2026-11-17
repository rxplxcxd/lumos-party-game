extends Node
## Kontrollbilder „Leben je Brett“ (BoardLife, ab 1.5.3): je Brett ein Bild aus der Spielkamera und eines aus der
## Weite (Rand, Himmel – dort fliegen Vögel, Ballons, Polarlicht, Sternschnuppen). Partie wie im Spiel (alle CPU).
##   xvfb-run -a ./godot --fixed-fps 30 --path . --resolution 960x540 res://tools/dev/Run.tscn -- \
##     --dev-script=res://tools/dev/board_life_shot.gd --out=/pfad [--only=meadow,frost] [--board-life=0]

const BOARDS := ["meadow", "pirates", "dungeon", "sky", "graveyard", "frost", "station", "glowforest", "cake", "tower"]


func run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var out := String(args.get("out", "user://board_life"))
	DirAccess.make_dir_recursive_absolute(out)
	var only: Array = String(args.get("only", "")).split(",", false)
	if args.has("board-life"):
		Game.settings["board_life"] = String(args["board-life"]) != "0"
	Game.settings["quality"] = "high"
	Gfx.apply()
	var tree := get_tree()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_parent().remove_child.call_deferred(self)
	tree.root.add_child.call_deferred(self)
	await tree.process_frame
	await tree.process_frame
	for i in Game.players.size():
		Game.players[i].cpu = true
	for b: String in BOARDS:
		if not only.is_empty() and not b in only:
			continue
		Game.start_party(b, 5, "classic")
		var path := "res://scenes/party/PartyBoard.tscn"
		Router.goto(path, {})
		for k in 600:
			await tree.process_frame
			if not Router.busy and tree.current_scene and tree.current_scene.scene_file_path == path:
				break
		for k in 150:   # Einführung laufen lassen, Partikel und Vögel verteilen sich
			await tree.process_frame
		await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_png(out.path_join("%s_spiel.png" % b))
		var board := tree.current_scene as Node3D
		var bl := board.get_node_or_null("BoardLife") as BoardLife if board else null
		var c := bl.center if bl else Vector3.ZERO
		var e := bl.extent if bl else 30.0
		var cam := Camera3D.new()
		cam.fov = 55.0
		cam.far = 900.0
		board.add_child(cam)
		cam.global_position = c + Vector3(0, e * 0.9 + (bl.top if bl else 0.0) * 0.6, e * 1.9)
		cam.look_at(c + Vector3(0, 6.0 + (bl.top if bl else 0.0) * 0.4, 0))
		cam.current = true
		for k in 20:
			await tree.process_frame
		await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_png(out.path_join("%s_weit.png" % b))
		print("BOARD-SHOT %s" % b)
		cam.queue_free()
	print("BOARD-SHOTS OK")
