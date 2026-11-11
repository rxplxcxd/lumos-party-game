extends Node
## Deko-Prüfung aller Minispiele: Steht nach dem Aufbau (inkl. PropSettler.settle) jedes platzierte Modell auf
## etwas, oder schwebt es bzw. ragt über eine Kante? Gleiche Prüfung wie PropSettler (exakte Strahltests).
##   godot --headless --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/deco_audit.gd [--only=id,id]
## Ausgabe: "DECO <id> schwebt|Kante <asset> @ (x, y, z)" und "DECO-SUMME <n>"; Exit-Code 1 bei Funden.


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
	var only: Array = String(args.get("only", "")).split(",", false)
	var total := 0
	for m in Game.MINIGAMES:
		if not m.has("scene") or (not only.is_empty() and not String(m.id) in only):
			continue
		for p in Game.players:
			p.cpu = true
		Game.mode = "free_play"
		var cats: Array = m.get("cats", ["ffa"])
		Game.minigame_setup = {"cat": String(cats[0])}
		if String(cats[0]) == "2v2":
			Game.minigame_setup["teams"] = [0, 1, 0, 1]
		elif String(cats[0]) == "duel":
			Game.minigame_setup["active"] = [true, true, false, false]
		elif String(cats[0]) == "1v3":
			Game.minigame_setup["solo"] = 0
		tree.change_scene_to_file(String(m.scene))
		for k in 6:
			await tree.process_frame
		var scene := tree.current_scene
		if scene == null:
			continue
		var world: Node = scene.get_node_or_null("World")
		for f in PropSettler.check(world if world else scene, PropSettler.script_refs(scene)):
			var p: Vector3 = f.pos
			print("DECO %s %s %s @ (%.1f, %.1f, %.1f)" % [m.id, f.kind, f.asset, p.x, p.y, p.z])
			total += 1
	print("DECO-SUMME %d Auffälligkeiten" % total)
	tree.quit(1 if total > 0 and args.has("strict") else 0)
