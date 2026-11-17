extends Node
## Bilder vom Character Framework im Spiel (Menü-Insel, Siegerehrung) – zum Ansehen und Vergleichen (an/aus).
##   xvfb-run -a -s "-screen 0 1280x720x24" ./godot --path . res://tools/dev/Run.tscn -- \
##     --dev-script=res://tools/dev/framework_shot.gd --out=/pfad [--off]
## --off: Einstellung „Lebendige Mimik“ aus (Vergleichsbilder). Schreibt menu_*.png und podium_*.png.

func run() -> void:
	var out := "user://shots"
	var off := false
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--out="):
			out = String(a).substr(6)
		if a == "--off":
			off = true
	DirAccess.make_dir_recursive_absolute(out)
	var tree := get_tree()
	get_parent().remove_child.call_deferred(self)
	tree.root.add_child.call_deferred(self)
	await tree.process_frame
	await tree.process_frame
	Game.settings["lively_faces"] = not off
	Game.settings["quality"] = "high"   # Software-Renderer (xvfb) würde sonst „Niedrig“ wählen – dort ist das Framework aus
	Gfx.apply()
	var tag := "off" if off else "on"
	Router.goto("res://scenes/menu/MainMenu.tscn")
	while Router.busy or tree.current_scene == null:
		await tree.process_frame
	await _secs(2.5)
	await _shot("%s/menu_%s_a.png" % [out, tag])
	# Eine Figur antippen (Reaktion + Gesicht)
	var m := tree.current_scene
	var heroes: Array = m.get("_heroes")
	if not heroes.is_empty():
		m.call("_poke", heroes[0])
		await _secs(0.5)
		await _shot("%s/menu_%s_poke.png" % [out, tag])
	await _secs(2.0)
	# Siegerehrung auf der Menü-Szene als Gastgeber (wie am Ende einer Party)
	for i in 4:
		Game.players[i].hero = Game.hero_list()[i].id
	CutsceneManager.play("Podium", {"ranking": [0, 1, 2, 3], "skippable": false})
	var marks := {3.2: "third", 5.4: "second", 9.0: "winner", 13.0: "loser", 19.5: "gag", 24.0: "final"}
	var t := 0.0
	var keys := marks.keys()
	keys.sort()
	for k in keys:
		await _secs(float(k) - t)
		t = float(k)
		await _shot("%s/podium_%s_%s.png" % [out, tag, marks[k]])
	print("SHOTS fertig: %s" % out)
	tree.quit()


func _secs(s: float) -> void:
	var n := int(s * 60.0)
	for i in n:
		await get_tree().process_frame


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SHOT " + path)
