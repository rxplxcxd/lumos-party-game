extends Node
## Rendert das Spiel-Logo aus echten Spiel-Assets (Held im Kart + Party-Stern + Würfel + Münzen) als
## transparentes PNG. Aufruf (braucht eine Grafikausgabe, z. B. xvfb-run):
##   xvfb-run -a ./godot --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/brand/render_logo.gd --out=/pfad
## Danach baut tools/brand/make_icons.py daraus App-Icons und das Ladebildschirm-Logo.

const SIZE := 1024


func run() -> void:
	var out := "res://tools/brand/out"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_8X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.95, 0.9, 1.0)
	env.environment.ambient_light_energy = 0.75
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 28, 0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.95, 0.88)
	vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 200, 0)
	rim.light_energy = 0.9
	rim.light_color = Color(0.75, 0.6, 1.0)
	vp.add_child(rim)
	var stage := Node3D.new()
	vp.add_child(stage)

	# Held im Kart, leicht schräg zur Kamera, mit Lenk-Pose
	var kart := KartVisual.new()
	stage.add_child(kart)
	kart.setup("kart/oopi", "hero/knight", -1, 2.2)
	kart.rotation.y = deg_to_rad(180 - 32)
	kart.position = Vector3(0, 0, 0.4)
	for t in [kart.spark_l, kart.spark_r, kart.flame, kart.dust]:
		if t:
			t.queue_free()
	# Party-Stern hinter dem Kart, Würfel & Münzen davor
	var star := Assets.spawn("plat/star", stage, Vector3(0.35, 3.0, -4.0), 0.0, 7.0)
	star.rotation_degrees = Vector3(0, 12, -8)
	var d6 := Assets.spawn("bg/d6", stage, Vector3(-2.35, 0.45, 1.9), 32.0, 1.35)
	d6.rotation_degrees = Vector3(18, 32, 12)
	Assets.spawn("plat/coin", stage, Vector3(2.35, 0.8, 1.6), -25.0, 1.7)
	Assets.spawn("plat/coin", stage, Vector3(2.75, 1.9, 0.6), 15.0, 1.3)

	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.position = Vector3(1.4, 4.2, 14.0)
	cam.look_at(Vector3(0.0, 1.9, 0.0))
	cam.current = true

	for k in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var path := out.path_join("logo_render.png")
	img.save_png(path)
	print("[Logo] gespeichert: ", ProjectSettings.globalize_path(path))
