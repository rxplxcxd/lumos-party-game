extends Node
## Szenen-Profil (Technik-Audit): startet eine Szene wie im Spiel (über den Router, alle Plätze CPU), wartet die
## Aufbauphase ab und misst dann eine feste Spielzeit lang jedes Bild:
##   * Bildzeit = Wanduhr zwischen zwei Bildern. Headless (Dummy-Renderer) ist das die reine Rechenzeit der
##     CPU-Seite – Skripte, Physik, Animation, Szenenbaum, Audio-Mischung. Die Grafikkarte wird dabei NICHT gemessen.
##     Mit xvfb-run (Software-Renderer) kommen Draw-Calls, Primitive, Objekte je Bild und Videospeicher dazu; dessen
##     Bildzeiten sind Software-Rasterung und taugen nicht als FPS-Aussage für echte Geräte.
##   * Mittel, Median, p95, p99, Maximum (mit Zeitpunkt), Anteil Bilder > 16,7 ms / > 33,3 ms, 1 %-Tief (Mittel der
##     langsamsten 1 % der Bilder, als FPS); Ausreißer > 33,3 ms mit Zeitpunkt; Modelle, die erst während der Messung
##     geladen wurden (Assets.late_loads – häufigste Ruckler-Ursache)
##   * Speicher: statisch (Mittel, Spitze im Messfenster), Objekte, Knoten, verwaiste Knoten
##   godot --headless --fixed-fps 60 --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/scene_profile.gd --target=board:meadow [--secs=20] [--warm=2]
## Ziele: menu · board:<id> · track:<id> · mg:<id> · boss:<id> · mode:journey|athlon|colosseum|marathon|kitchen
## Ausgabe: eine Zeile "PROFILE {json}". Alle Ziele nacheinander: tools/dev/scene_profile.sh

const MENU := "res://scenes/menu/MainMenu.tscn"


class ErrLog extends Logger:
	var _m := Mutex.new()
	var items: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_m.lock()
		if items.size() < 20:
			items.append("%s:%d %s %s" % [file.get_file(), line, function, (rationale if rationale != "" else code)])
		_m.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _log := ErrLog.new()


func run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var tree := get_tree()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_parent().remove_child.call_deferred(self)
	tree.root.add_child.call_deferred(self)
	await tree.process_frame
	await tree.process_frame
	# Bildgröße: Standard 1280×720; für Render-Zählwerte mit Software-Renderer genügt 640×360 (Draw-Calls und
	# Primitive hängen nicht von der Auflösung ab, gleiches Seitenverhältnis = gleicher Bildausschnitt)
	var res := String(args.get("res", "1280x720")).split("x")
	tree.root.size = Vector2i(int(res[0]), int(res[1]))
	if args.has("lively"):    # Character Framework (Menü-Insel, Siegerehrung) an/aus – für den Kostenvergleich
		Game.settings["lively_faces"] = String(args["lively"]) != "0"
	if args.has("board-life"):   # eigenes Leben je Brett an/aus (BoardLife, 1.5.3) – für den Kostenvergleich
		Game.settings["board_life"] = String(args["board-life"]) != "0"
	if args.has("quality"):   # Grafikstufe erzwingen (xvfb/Software-Renderer erkennt sonst „Niedrig“)
		Game.settings["quality"] = String(args["quality"])
		Gfx.apply()
	OS.add_logger(_log)
	var target := String(args.get("target", "menu"))
	var secs := float(args.get("secs", "20"))
	var warm := float(args.get("warm", "2"))
	var out := {"target": target, "renderer": DisplayServer.get_name(), "quality": Gfx.active}
	var path := _setup(target)
	if path == "":
		out["error"] = "unbekanntes Ziel"
		_finish(out)
		return
	var t_load := Time.get_ticks_msec()
	Router.goto(path, Router.params)
	await _until(func() -> bool: return not Router.busy and tree.current_scene != null and tree.current_scene.scene_file_path == path, 3600)
	out["load_s"] = snappedf((Time.get_ticks_msec() - t_load) / 1000.0, 0.01)
	out["scene"] = path
	# Minispiele: Messung ab Spielbeginn (Erklärbildschirm und Intro zählen nicht)
	var mg := tree.current_scene as MinigameBase
	if mg:
		await _until(func() -> bool: return not is_instance_valid(mg) or mg.state == "play", 60 * 60)
	await _frames(int(warm * 60.0))
	var frames: PackedFloat32Array = []
	var dc: PackedFloat32Array = []
	var prim: PackedFloat32Array = []
	var objs: PackedFloat32Array = []
	var mem: PackedFloat32Array = []
	var spikes: Array = []
	var start_scene := tree.current_scene
	var n := int(secs * 60.0)
	var render := DisplayServer.get_name() != "headless"
	Assets.late_loads.clear()
	Assets.late_watch = true
	var last := Time.get_ticks_usec()
	for i in n:
		await tree.process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		if tree.current_scene != start_scene:
			out["scene_changed_at_s"] = snappedf(i / 60.0, 0.1)
			break
		if mg and is_instance_valid(mg) and mg.state != "play" and i > 60:
			out["ended_at_s"] = snappedf(i / 60.0, 0.1)   # Minispiel vorbei: Ergebnisbildschirm nicht mitmessen
			break
		frames.append(ms)
		mem.append(Performance.get_monitor(Performance.MEMORY_STATIC) / 1e6)
		if render:
			dc.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			prim.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			objs.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		if ms > 33.3:
			spikes.append([snappedf(i / 60.0, 0.01), snappedf(ms, 0.1)])
	Assets.late_watch = false
	out["late_loads"] = Assets.late_loads.slice(0, 10)
	if mg and is_instance_valid(mg):
		out["mg_state"] = mg.state
	out["frames"] = frames.size()
	if frames.size() > 0:
		var s := frames.duplicate()
		s.sort()
		var cnt := s.size()
		var worst := maxi(1, int(ceil(cnt * 0.01)))
		var low_sum := 0.0
		for k in worst:
			low_sum += s[cnt - 1 - k]
		var avg := _mean(frames)
		out["ms_avg"] = snappedf(avg, 0.01)
		out["ms_p50"] = snappedf(s[int(cnt * 0.5)], 0.01)
		out["ms_p95"] = snappedf(s[mini(cnt - 1, int(cnt * 0.95))], 0.01)
		out["ms_p99"] = snappedf(s[mini(cnt - 1, int(cnt * 0.99))], 0.01)
		out["ms_max"] = snappedf(s[cnt - 1], 0.1)
		out["max_at_s"] = snappedf(frames.find(s[cnt - 1]) / 60.0, 0.01)
		out["fps_avg"] = snappedf(1000.0 / maxf(avg, 0.001), 1.0)
		out["fps_1low"] = snappedf(1000.0 / maxf(low_sum / worst, 0.001), 1.0)
		var o16 := 0
		var o33 := 0
		for v in frames:
			if v > 16.7:
				o16 += 1
			if v > 33.3:
				o33 += 1
		out["over16_pct"] = snappedf(100.0 * o16 / cnt, 0.01)
		out["over33"] = o33
		out["mem_mb"] = snappedf(_mean(mem), 0.1)
		out["mem_peak_mb"] = snappedf(_max(mem), 0.1)
		out["spikes"] = spikes.slice(0, 8)
	out["objects"] = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	out["nodes"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	out["orphans"] = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if render and dc.size() > 0:
		out["draw_calls"] = snappedf(_mean(dc), 1.0)
		out["draw_calls_max"] = _max(dc)
		out["prims_k"] = snappedf(_mean(prim) / 1000.0, 0.1)
		out["objs_in_frame"] = snappedf(_mean(objs), 1.0)
		out["vmem_mb"] = snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1e6, 0.1)
		out["tex_mb"] = snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1e6, 0.1)
	_finish(out)


func _finish(out: Dictionary) -> void:
	_log._m.lock()
	out["errors"] = _log.items.duplicate()
	_log._m.unlock()
	print("PROFILE " + JSON.stringify(out))
	OS.remove_logger(_log)
	get_tree().quit()


## Spielzustand wie im Menü vorbereiten; Rückgabe: Szene, die der Router laden soll.
func _setup(target: String) -> String:
	for i in Game.players.size():
		Game.players[i].cpu = true
		Game.players[i].cpu_level = 1
	Router.params = {}
	var kind := target.get_slice(":", 0)
	var id := target.get_slice(":", 1) if target.contains(":") else ""
	match kind:
		"menu":
			return MENU
		"board":
			Game.start_party(id, 5, "classic")
			return "res://scenes/party/PartyBoard.tscn"
		"track":
			Game.race_cfg = {"track": id, "laps": 3, "cpu_level": 1, "mode": "single", "cup": 0}
			Game.mode = "race"
			return "res://scenes/racer/NitroDash.tscn"
		"mg", "boss":
			var gid := id if kind == "mg" else "boss_battle"
			var m: Dictionary = Game.minigame_info(gid)
			if m.is_empty():
				return ""
			var cats: Array = m.get("cats", ["ffa"])
			var cat := String(cats[0]) if not cats.is_empty() else "ffa"
			var cs := {"cat": cat}
			if cat == "2v2":
				cs["teams"] = [0, 1, 0, 1]
			elif cat == "duel":
				cs["active"] = [true, true, false, false]
			elif cat == "1v3":
				cs["solo"] = 0
			if kind == "boss":
				cs["boss"] = id
			Game.minigame_setup = cs
			Game.mode = "free_play"
			return String(m.scene)
		"mode":
			match id:
				"journey":
					Game.mode = "journey"
					return "res://scenes/modes/Journey.tscn"
				"athlon":
					Game.settings["athlon_size"] = 8
					Game.mode = "athlon"
					return "res://scenes/modes/Athlon.tscn"
				"colosseum":
					Game.mode = "colosseum"
					return "res://scenes/modes/Colosseum.tscn"
				"marathon":
					Game.start_marathon(5)
					return "res://scenes/menu/MarathonHub.tscn"
				"kitchen":
					Game.mode = "modes"
					return String(Game.minigame_info("rhythm_kitchen").scene)
	return ""


func _mean(a: PackedFloat32Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += v
	return s / a.size()


func _max(a: PackedFloat32Array) -> float:
	var m := 0.0
	for v in a:
		m = maxf(m, v)
	return m


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())
