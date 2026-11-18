extends Node
## Vergleichsbilder fürs Material-System (ab Premium-Visual-Überarbeitung): feste Kameras, fester Zufall, gleiche
## Auflösung und gleiches Licht – damit Vorher/Nachher wirklich vergleichbar sind.
##   xvfb-run -a -s "-screen 0 1600x900x24" ./godot --fixed-fps 30 --path . --resolution 1280x720 \
##     res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/material_shot.gd --out=/pfad --tag=vorher \
##     [--surfaces=0|1] [--quality=high|medium|low]
## Hauptmenü-Insel: Spielansicht mit und ohne Menü, Nahaufnahmen Boden/Sand, Requisiten, Uferkante, Weitwinkel.
## --surfaces: Einstellung „Oberflächen-Details“ (LumosSurface) aus/an; ohne Angabe gilt die Einstellung der Grafikstufe.

const VIEWS := {
	# Name: [Kameraposition, Blickziel, Sichtfeld]
	"nah_boden": [Vector3(-6.4, 1.4, 3.8), Vector3(-4.4, 0.1, 1.2), 50.0],
	"nah_requisiten": [Vector3(-4.6, 1.9, 1.4), Vector3(-1.6, 0.9, -2.6), 50.0],
	"ufer": [Vector3(7.8, 1.6, 8.6), Vector3(5.6, -0.2, 4.6), 55.0],
	"weit": [Vector3(-14.0, 9.0, 20.0), Vector3(0.0, 0.0, 0.0), 50.0],
}


func run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var out := String(args.get("out", "user://material_shots"))
	var tag := String(args.get("tag", "shot"))
	DirAccess.make_dir_recursive_absolute(out)
	var tree := get_tree()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_parent().remove_child.call_deferred(self)
	tree.root.add_child.call_deferred(self)
	await tree.process_frame
	await tree.process_frame
	Game.settings["quality"] = String(args.get("quality", "high"))   # xvfb würde sonst „Niedrig“ wählen
	if args.has("surfaces"):
		Game.settings["surface_detail"] = String(args["surfaces"]) != "0"
	Gfx.apply()
	seed(4242)   # Palmen/Blumen der Insel liegen bei jedem Lauf gleich
	Router.goto("res://scenes/menu/MainMenu.tscn")
	while Router.busy or tree.current_scene == null or tree.current_scene.scene_file_path != "res://scenes/menu/MainMenu.tscn":
		await tree.process_frame
	var m := tree.current_scene
	for k in 75:   # Figuren in ihre Beschäftigungen laufen lassen
		await tree.process_frame
	m.set_process(false)   # Menü-Kamera anhalten – Figuren bewegen sich weiter
	var cam: Camera3D = m.get("_cam")
	m.set("_cam_t", 0.0)
	m.call("_update_cam", 0.0)
	await _shot("%s/menu_spiel_%s.png" % [out, tag])
	var layers: Array[CanvasLayer] = []
	for c in m.get_children():
		if c is CanvasLayer and (c as CanvasLayer).visible:
			layers.append(c)
			(c as CanvasLayer).visible = false
	await _shot("%s/menu_spiel_ohne_ui_%s.png" % [out, tag])
	for v: String in VIEWS:
		var d: Array = VIEWS[v]
		cam.fov = float(d[2])
		cam.global_position = d[0]
		cam.look_at(d[1], Vector3.UP)
		await _shot("%s/menu_%s_%s.png" % [out, v, tag])
	for l in layers:
		l.visible = true
	print("MATERIAL-SHOTS OK %s" % out)
	tree.quit()


func _shot(path: String) -> void:
	for k in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(path)
