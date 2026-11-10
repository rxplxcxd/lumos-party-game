extends Node
## Performance-Sonde: lädt eine Szene und meldet nach ein paar Sekunden Draw-Calls, Objekte, Primitive,
## Lichter, Partikel und Mesh-Instanzen. Braucht eine Grafikausgabe (xvfb-run).
##   xvfb-run -a ./godot --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/perf_probe.gd --probe=res://scenes/menu/MainMenu.tscn
func run() -> void:
	var scene := "res://scenes/menu/MainMenu.tscn"
	var wait := 4.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--probe="):
			scene = a.substr(8)
		if a.begins_with("--probe-wait="):
			wait = a.substr(13).to_float()
	var inst: Node = (load(scene) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(inst)
	await get_tree().create_timer(wait).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var rs := RenderingServer
	var counts := {"MeshInstance3D": 0, "OmniLight3D": 0, "SpotLight3D": 0, "DirectionalLight3D": 0, "CPUParticles3D": 0,
		"GPUParticles3D": 0, "AnimationPlayer": 0, "MultiMeshInstance3D": 0, "shadow_casters": 0, "shadow_lights": 0}
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var c := n.get_class()
		if counts.has(c):
			counts[c] += 1
		if n is GeometryInstance3D and (n as GeometryInstance3D).visible and (n as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			counts.shadow_casters += 1
		if n is Light3D and (n as Light3D).shadow_enabled and (n as Light3D).visible:
			counts.shadow_lights += 1
		for ch in n.get_children():
			stack.append(ch)
	print("[PERF] %s · draw calls %d · objects %d · primitives %d · %s" % [scene.get_file(),
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), str(counts)])
	print("[PERF] preset %s · fps %d · process %.1f ms · physics %.1f ms · nodes %d" % [Gfx.active, Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
