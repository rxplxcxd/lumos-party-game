extends Node
## Prüft, ob source_color-Texturen (VRAM-komprimiert, webp) im Compatibility-Renderer linear dekodiert werden:
## ein unbeleuchtetes Rechteck zeigt Texturwert, daneben die Farbe 0,5 (sRGB). Ausgabe "SRGB tex=… flat=…".

func run() -> void:
	var tree := get_tree()
	get_parent().remove_child.call_deferred(self)
	tree.root.add_child.call_deferred(self)
	await tree.process_frame
	var root := Node3D.new()
	tree.root.add_child(root)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.0
	cam.position = Vector3(0, 0, 5)
	root.add_child(cam)
	cam.make_current()
	var sh := Shader.new()
	var hints := "source_color, filter_linear_mipmap_anisotropic, repeat_enable" if OS.get_cmdline_user_args().has("--hints") else "source_color"
	var sc := 8.0 if OS.get_cmdline_user_args().has("--minify") else 1.0
	sh.code = "shader_type spatial; render_mode unshaded; uniform sampler2D t : %s; uniform vec4 c : source_color; uniform bool use_tex; void fragment(){ ALBEDO = use_tex ? texture(t, UV * %.1f).rgb : c.rgb; }" % [hints, sc]
	for i in 2:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.8, 3.6)
		mi.mesh = q
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("t", load("res://assets/materials/surfaces/%s_albedo.webp" % ("grass" if OS.get_cmdline_user_args().has("--grass") else "plaster")))
		m.set_shader_parameter("c", Color(0.5, 0.5, 0.5))
		m.set_shader_parameter("use_tex", i == 0)
		mi.material_override = m
		mi.position.x = -1.0 if i == 0 else 1.0
		root.add_child(mi)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	root.add_child(env)
	for k in 8:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var img := tree.root.get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	var acc := Vector3.ZERO
	var n := 0
	for y in range(h / 4, h * 3 / 4, 4):
		for x in range(w / 2 - int(w * 0.3), w / 2 - int(w * 0.05), 4):
			var c := img.get_pixel(x, y)
			acc += Vector3(c.r, c.g, c.b)
			n += 1
	var flat := img.get_pixel(w / 2 + int(w * 0.15), h / 2)
	print("SRGB tex=%s flat=%s" % [acc / n, Vector3(flat.r, flat.g, flat.b)])
	tree.quit()
