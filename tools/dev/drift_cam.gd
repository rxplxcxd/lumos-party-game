extends Node
## Draufsicht auf die schärfste Kurve einer Strecke während eines CPU-Rennens (für Movie-Maker-Aufnahmen):
## zeigt, wohin Nase und Heck im Drift zeigen, wie sich Karts in die Kurve legen und wie sie sich berühren.
##   xvfb-run godot --path . --write-movie out/f.png --fixed-fps 10 --quit-after 300 res://tools/dev/Run.tscn -- \
##     --dev-script=res://tools/dev/drift_cam.gd --track=lumos_ring [--height=14] [--side]

func run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var tree := get_tree()
	get_parent().remove_child.call_deferred(self)
	tree.root.add_child.call_deferred(self)
	await tree.process_frame
	for p in Game.players:
		p.cpu = true
	Game.race_cfg = {"track": String(args.get("track", "lumos_ring")), "laps": 1, "cpu_level": 2, "mode": "single", "cup": 0}
	tree.change_scene_to_file("res://scenes/racer/NitroDash.tscn")
	var nd: Node = null
	for i in 240:
		await tree.process_frame
		if tree.current_scene and tree.current_scene.has_method("use_item"):
			nd = tree.current_scene
			break
	var track: RaceTrack = nd.get("track")
	# schärfste Kurve auf dem flachen Teil der Strecke
	var best_s := 0.0
	var best_k := 0.0
	var s := 20.0
	while s < track.length - 20.0:
		var fr := track.frame(s)
		if fr.origin.y < 2.0 and fr.basis.y.dot(Vector3.UP) > 0.97 and not track.is_glide(s):
			var k := absf(track.curvature(s, 0.0))
			if k > best_k:
				best_k = k
				best_s = s
		s += 2.0
	var at := track.frame(best_s + float(args.get("ahead", "6"))).origin
	var cam := Camera3D.new()
	tree.current_scene.add_child(cam)
	var hgt := float(args.get("height", "14"))
	if args.has("side"):
		var fr2 := track.frame(best_s)
		cam.global_position = at + fr2.basis.x * -16.0 + Vector3.UP * 4.0
	else:
		cam.global_position = at + Vector3(0.01, hgt, 0)
	cam.look_at(at, Vector3.FORWARD if not args.has("side") else Vector3.UP)
	cam.fov = float(args.get("fov", "60"))
	print("[DRIFTCAM] Kurve bei s=%.0f, Krümmung %.3f" % [best_s, best_k])
	while true:
		await tree.process_frame
		if is_instance_valid(cam):
			cam.make_current()
