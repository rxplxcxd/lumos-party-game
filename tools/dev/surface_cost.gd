extends Node
## Kosten des Oberflächen-Shaders kontrolliert messen (ab 1.5.4): feste Kamera, bildschirmfüllender Boden + Zylinder
## (Seitenwände = mehrere Projektionen), gleiche Szene je Lauf nur mit anderem Material: flach (bisher) · Stufe 0 · 1 · 2.
## Bildzeit = Mittel über 150 Bilder nach 40 Bildern Aufwärmen. Im Software-Renderer (xvfb/llvmpipe) „simuliert“ –
## das Verhältnis zeigt die Pixelkosten, nicht die FPS eines Geräts. Ausgabe "COST {json}".
##   xvfb-run -a -s "-screen 0 1280x720x24" ./godot --path . --resolution 960x540 res://tools/dev/Run.tscn -- \
##     --dev-script=res://tools/dev/surface_cost.gd [--family=grass]

func run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var fam := String(args.get("family", "grass"))
	var tree := get_tree()
	get_parent().remove_child.call_deferred(self)
	tree.root.add_child.call_deferred(self)
	await tree.process_frame
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Game.settings["quality"] = "high"
	Gfx.apply()
	Engine.max_fps = 0
	var root := Node3D.new()
	tree.root.add_child(root)
	WorldKit.env(root, "day")
	var cam := Camera3D.new()
	cam.fov = 60.0
	root.add_child(cam)
	cam.position = Vector3(0, 6, 10)
	cam.look_at(Vector3(0, 0, -6))
	cam.make_current()
	var col := Color("#7fd36a")
	var res := {}
	for mode in ["flach", "stufe0", "stufe1", "stufe2"]:
		var m: Material
		if mode == "flach":
			m = WorldKit.mat(col)
		else:
			m = (LumosMaterials.surface(fam, col) as ShaderMaterial).duplicate()
			(m as ShaderMaterial).set_shader_parameter("quality", int(mode.substr(5)))
		var holder := Node3D.new()
		root.add_child(holder)
		var g := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(80, 1, 80)
		b.material = m
		g.mesh = b
		g.position.y = -0.5
		holder.add_child(g)
		for i in 6:
			var c := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 1.6
			cm.bottom_radius = 1.6
			cm.height = 4.0
			cm.material = m
			c.mesh = cm
			c.position = Vector3(-7.5 + i * 3.0, 2.0, -3.0 - (i % 2) * 3.0)
			holder.add_child(c)
		for k in 40:
			await tree.process_frame
		var t0 := Time.get_ticks_usec()
		for k in 150:
			await tree.process_frame
		res[mode] = snappedf((Time.get_ticks_usec() - t0) / 150000.0, 0.01)
		holder.queue_free()
		await tree.process_frame
	var base := float(res.flach)
	var rel := {}
	for k in res:
		rel[k] = snappedf(float(res[k]) / base, 0.01)
	print("COST " + JSON.stringify({"familie": fam, "ms_je_bild": res, "relativ": rel, "renderer": RenderingServer.get_video_adapter_name()}))
	tree.quit()
