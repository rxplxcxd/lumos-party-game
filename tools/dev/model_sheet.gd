extends Node
## Modell-Übersicht: rendert alle Modelle eines Ordners als beschriftetes Raster (auf Zellgröße normiert) und
## gibt pro Modell die Originalgröße (AABB) aus – zum Sichten neuer Asset-Packs.
##   xvfb-run ./godot --path . --resolution 1600x1000 res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/model_sheet.gd
##     --dir=res://assets/3d/quaternius/nature --out=/pfad/bild.png [--filter=Tree] [--cols=10] [--max=80]


func run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var tree := get_tree()
	get_parent().remove_child.call_deferred(self)
	tree.root.add_child.call_deferred(self)
	await tree.process_frame
	var dir := String(args.get("dir", ""))
	var filt := String(args.get("filter", ""))
	var files: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		var ext := f.get_extension().to_lower()
		if ext in ["glb", "gltf", "fbx", "obj"] and (filt == "" or filt in f):
			files.append(dir.path_join(f))
	files.sort()
	files = files.slice(0, int(args.get("max", "80")))
	var cols := int(args.get("cols", "10"))
	var root := Node3D.new()
	add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.65, 0.75)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.85)
	e.ambient_light_energy = 0.6
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root.add_child(sun)
	var cell := 3.0
	for i in files.size():
		var ps := load(files[i])
		var n: Node3D = null
		if ps is PackedScene:
			n = (ps as PackedScene).instantiate() as Node3D
		elif ps is Mesh:
			var mi := MeshInstance3D.new()
			mi.mesh = ps
			n = mi
		if n == null:
			continue
		var holder := Node3D.new()
		root.add_child(holder)
		holder.add_child(n)
		var bb := _aabb(n)
		var s := 2.4 / maxf(maxf(bb.size.x, bb.size.y), maxf(bb.size.z, 0.01))
		n.scale = Vector3.ONE * s
		n.position = -bb.get_center() * s + Vector3(0, bb.size.y * s * 0.5, 0)
		holder.position = Vector3((i % cols) * cell, 0, (i / cols) * cell * 1.2)
		var lb := Label3D.new()
		lb.text = files[i].get_file().get_basename().right(22)
		lb.font_size = 40
		lb.pixel_size = 0.006
		lb.outline_size = 10
		lb.position = Vector3(0, -0.3, 1.2)
		lb.rotation_degrees.x = -50
		holder.add_child(lb)
		print("MODEL %s size=%s" % [files[i].get_file(), bb.size.snapped(Vector3.ONE * 0.01)])
	var rows := int(ceil(files.size() / float(cols)))
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(cols * cell * 0.62, rows * cell * 1.2 * 1.05)
	var center := Vector3((cols - 1) * cell * 0.5, 0, (rows - 1) * cell * 1.2 * 0.5)
	cam.look_at_from_position(center + Vector3(0, 30, 22), center, Vector3.UP)
	cam.current = true
	for k in 8:
		await tree.process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(String(args.get("out", "user://sheet.png")))
	print("SHEET ", args.get("out", ""))
	tree.quit()


func _aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var t := _rel(m, n)
		var b := t * m.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		out = (n as MeshInstance3D).mesh.get_aabb() if first else out
	return out


func _rel(m: Node3D, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = m
	while cur and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t
