extends Node
## Feste Kontrollbilder einer Nitro-Dash-Strecke (Premium-Visual-Überarbeitung): Start wie im Spiel (Router, Modus
## „race“, alle Fahrer CPU), nach 3 s Rennen drei Kameras an festen Streckenpunkten (hinter/über der Fahrbahn) –
## gleiche Rahmung in jedem Stand, also Vorher/Nachher vergleichbar.
##   xvfb-run -a -s "-screen 0 1280x720x24" ./godot --fixed-fps 30 --path . --resolution 960x540 res://tools/dev/Run.tscn -- \
##     --dev-script=res://tools/dev/track_shot.gd --track=lumos_ring --out=/pfad [--at=0.05,0.4,0.7]
## --at: Streckenanteile (0..1). Ausgabe <track>_<n>.png und "TRACK-SHOTS OK".


func run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var tree := get_tree()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_parent().remove_child.call_deferred(self)
	tree.root.add_child.call_deferred(self)
	await tree.process_frame
	await tree.process_frame
	var out := String(args.get("out", "user://track_shots"))
	DirAccess.make_dir_recursive_absolute(out)
	var tid := String(args.get("track", "lumos_ring"))
	Game.settings["quality"] = "high"
	Gfx.apply()
	for i in Game.players.size():
		Game.players[i].cpu = true
	Game.race_cfg = {"track": tid, "laps": 3, "cpu_level": 1, "mode": "single", "cup": 0}
	Game.mode = "race"
	var path := "res://scenes/racer/NitroDash.tscn"
	Router.goto(path, {})
	for k in 60 * 120:
		await tree.process_frame
		if not Router.busy and tree.current_scene and tree.current_scene.scene_file_path == path:
			break
	var nd: Node = tree.current_scene
	if nd == null or nd.scene_file_path != path:
		print("TRACK-FEHLER Rennszene nicht geladen")
		tree.quit(1)
		return
	for k in 60 * 40:
		await tree.process_frame
		if String(nd.get("state")) == "race":
			break
	for k in 90:
		await tree.process_frame
	var track: Node = nd.get("track")
	var length := float(track.get("length"))
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 900.0
	nd.add_child(cam)
	var n := 0
	for f in String(args.get("at", "0.05,0.4,0.7")).split(","):
		var s := float(f) * length
		var fr: Transform3D = track.call("frame", s)
		var fwd := -fr.basis.z
		var up := fr.basis.y
		cam.global_position = fr.origin - fwd * 9.0 + up * 4.5 + fr.basis.x * 2.0
		cam.look_at(fr.origin + fwd * 14.0 + up * 0.8, Vector3.UP)
		cam.current = true
		for k in 8:
			await tree.process_frame
		await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_png(out.path_join("%s_%d.png" % [tid, n]))
		n += 1
	print("TRACK-SHOTS OK %s" % tid)
	tree.quit(0)   # der Szenenwechsel hat den Dev-Runner entfernt – selbst beenden
