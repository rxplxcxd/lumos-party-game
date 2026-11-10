extends Node
## Farb-Look vergleichen: lädt ein Brett, wendet nacheinander Environment-Varianten an und speichert je ein Bild.
## xvfb-run ./godot --path . --resolution 1280x720 res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/look_probe.gd
##   --board=meadow --out=/pfad [--variants=a,b,c]

const VARIANTS := {
	"cur": {},
	"b": {"exp": 0.92, "bri": 1.0, "con": 1.2, "sat": 1.45, "skyamb": 0.25},
	"c": {"exp": 0.92, "bri": 1.0, "con": 1.2, "sat": 1.45, "skyamb": 0.25, "amb": 0.75},
	"d": {"exp": 0.86, "bri": 1.0, "con": 1.22, "sat": 1.5, "skyamb": 0.2, "amb": 0.7, "fog": 0.5},
	"e": {"exp": 0.86, "bri": 1.0, "con": 1.22, "sat": 1.5, "skyamb": 0.2, "amb": 0.7, "fog": 0.5, "refl": false},
	"f": {"exp": 0.9, "bri": 1.0, "con": 1.25, "sat": 1.55, "skyamb": 0.2, "amb": 0.7, "fog": 0.5, "white": 6.0},
	"g": {"exp": 0.86, "bri": 1.0, "con": 1.22, "sat": 1.5, "skyamb": 0.2, "amb": 0.7, "fog": 0.5, "rays": 0.4},
	"h": {"exp": 0.86, "bri": 1.0, "con": 1.22, "sat": 1.5, "skyamb": 0.2, "amb": 0.7, "fog": 0.5, "rays": 0.0},
	"i": {"exp": 0.9, "bri": 1.0, "con": 1.2, "sat": 1.42, "skyamb": 0.2, "amb": 0.72, "fog": 0.5, "rays": 0.4},
}


func run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var tree := get_tree()
	get_parent().remove_child.call_deferred(self)   # Szenenwechsel überleben (Run.tscn wird ersetzt)
	tree.root.add_child.call_deferred(self)
	await tree.process_frame
	await tree.process_frame
	var board := String(args.get("board", "meadow"))
	var out := String(args.get("out", "user://look"))
	DirAccess.make_dir_recursive_absolute(out)
	for p in Game.players:
		p.cpu = true
	Game.start_party(board, 5, "classic")
	Game.mode = "party"
	tree.change_scene_to_file("res://scenes/party/PartyBoard.tscn")
	await tree.create_timer(15.0).timeout
	tree.paused = true   # Szene einfrieren, damit alle Varianten dasselbe Bild zeigen
	var envs := tree.root.find_children("*", "WorldEnvironment", true, false)
	if envs.is_empty():
		printerr("kein WorldEnvironment")
		return
	var e: Environment = (envs[0] as WorldEnvironment).environment
	var base := {"exp": e.tonemap_exposure, "bri": e.adjustment_brightness, "con": e.adjustment_contrast,
		"sat": e.adjustment_saturation, "skyamb": e.ambient_light_sky_contribution, "amb_e": e.ambient_light_energy,
		"fog_d": e.fog_density, "white": e.tonemap_white, "refl": e.reflected_light_source}
	var rays: Array = []
	for mi in tree.root.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).material_override
		if m is ShaderMaterial and (m as ShaderMaterial).shader and (m as ShaderMaterial).shader.resource_path.ends_with("god_rays.gdshader"):
			rays.append([m, float((m as ShaderMaterial).get_shader_parameter("strength"))])
	var names: Array = String(args.get("variants", ",".join(VARIANTS.keys()))).split(",")
	for n in names:
		var v: Dictionary = VARIANTS.get(n, {})
		e.tonemap_exposure = float(v.get("exp", base.exp))
		e.adjustment_brightness = float(v.get("bri", base.bri))
		e.adjustment_contrast = float(v.get("con", base.con))
		e.adjustment_saturation = float(v.get("sat", base.sat))
		e.ambient_light_sky_contribution = float(v.get("skyamb", base.skyamb))
		e.ambient_light_energy = float(base.amb_e) * float(v.get("amb", 1.0))
		e.fog_density = float(base.fog_d) * float(v.get("fog", 1.0))
		e.tonemap_white = float(v.get("white", base.white))
		e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED if v.has("refl") and not bool(v.refl) else int(base.refl)
		for r in rays:
			(r[0] as ShaderMaterial).set_shader_parameter("strength", float(r[1]) * float(v.get("rays", 1.0)))
		for i in 4:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out, board, n])
	print("look_probe: %d Varianten für %s" % [names.size(), board])
	tree.quit()
