extends Node
## Helligkeits-Abgleich LumosSurface gegen das bisherige einfarbige Material (gleiches Licht wie die Menü-Insel):
## vier Platten nebeneinander – flach · Lumos ohne Detail · Lumos nur Farbe · Lumos voll. Ausgabe "PROBE {json}".
##   xvfb-run -a ./godot --path . --resolution 800x400 res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/surface_probe.gd \
##     [--family=grass] [--color=7fd36a] [--out=/pfad.png]

func run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var fam := String(args.get("family", "grass"))
	var col := Color(String(args.get("color", "7fd36a")))
	var tree := get_tree()
	get_parent().remove_child.call_deferred(self)
	tree.root.add_child.call_deferred(self)
	await tree.process_frame
	Game.settings["quality"] = "high"
	Gfx.apply()
	var root := Node3D.new()
	tree.root.add_child(root)
	var we := WorldKit.env(root, String(args.get("env", "day")))
	if args.has("neutral"):   # ohne Farbanpassung, linear: zeigt, ob Abweichungen aus dem Material oder aus der Nachbearbeitung kommen
		we.environment.adjustment_enabled = false
		we.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		we.environment.tonemap_exposure = 1.0
		we.environment.fog_enabled = false
		we.environment.glow_enabled = false
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 5.0
	cam.position = Vector3(0, 10, 0)
	root.add_child(cam)
	cam.look_at(Vector3.ZERO, Vector3.FORWARD)
	cam.make_current()
	if args.has("raw"):   # Rohwert der Detailtextur unbeleuchtet (Fehlersuche)
		var sh := Shader.new()
		sh.code = (load(LumosMaterials.SHADER) as Shader).code.replace("render_mode blend_mix,", "render_mode unshaded, blend_mix,").replace("ALBEDO = tint.rgb * det;", "ALBEDO = %s;" % String(args.raw))
		LumosMaterials._shader = sh
	var mats: Array[Material] = [WorldKit.mat(col), LumosMaterials.surface(fam, col, {"strength": 0.0, "normal": 0.0}),
		LumosMaterials.surface(fam, col, {"normal": 0.0}), LumosMaterials.surface(fam, col)]
	for i in 4:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(2.4, 0.2, 4.8)
		b.material = mats[i]
		mi.mesh = b
		mi.position.x = -3.75 + i * 2.5
		root.add_child(mi)
	for k in 10:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var img := tree.root.get_texture().get_image()
	if args.has("out"):
		img.save_png(String(args.out))
	var w := img.get_width()
	var h := img.get_height()
	var res := []
	for i in 4:
		var cx := int(w * (0.5 + (-3.75 + i * 2.5) / (cam.size * float(w) / float(h))))   # Ortho: Höhe = size
		var acc := Vector3.ZERO
		var n := 0
		for y in range(h / 3, h * 2 / 3, 3):
			for x in range(cx - int(h * 0.08), cx + int(h * 0.08), 3):
				var c := img.get_pixel(clampi(x, 0, w - 1), y)
				acc += Vector3(c.r, c.g, c.b)
				n += 1
		var m := acc / n
		res.append([snappedf(m.x, 0.001), snappedf(m.y, 0.001), snappedf(m.z, 0.001)])
	print("PROBE " + JSON.stringify({"family": fam, "flat|lumos0|farbe|voll": res}))
	tree.quit()
