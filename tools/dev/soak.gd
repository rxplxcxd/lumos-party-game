extends Node
## Langzeit-Test (Soak): spielt eine komplette Party mit 4 CPUs über viele Runden (Brett → Minispiel → Brett …)
## im Schnellvorlauf und misst bei jedem Szenenwechsel den Speicher OHNE geladene Szene. Wächst dieser Wert von
## Runde zu Runde, ist es ein Leck (genau das hat lange Browser-Sessions nach 11–15 Runden neu laden lassen).
##   ./godot --headless --fixed-fps 60 --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/soak.gd --rounds=15 [--board=meadow] [--max-min=60]
## Mit echtem Rendering (misst zusätzlich den Grafikspeicher – Texturen, Schrift-Glyphen):
##   xvfb-run ./godot --fixed-fps 60 --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/soak.gd --rounds=6
## Ausgabe: [SOAK]-Zeilen und am Ende "SOAK OK" bzw. "SOAK FEHLER …" (Exit-Code 0/1).

var _empty: Array = []        # Speicher (MB) zwischen den Szenen – je Wechsel
var _objects: Array = []
var _scenes: Array = []
var _hang := ""


func run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var tree := get_tree()
	get_parent().remove_child.call_deferred(self)
	tree.root.add_child.call_deferred(self)
	await tree.process_frame
	await tree.process_frame
	var rounds := int(args.get("rounds", "15"))
	var board := String(args.get("board", "meadow"))
	var max_s := float(args.get("max-min", "90")) * 60.0
	for p in Game.players:
		p.cpu = true
	Game.settings["show_fps"] = true   # Debug-Anzeige im Test mitlaufen lassen
	Game.start_party(board, rounds, String(args.get("party-mode", "classic")))
	# Musik vorab laden: Der Musik-Cache füllt sich sonst über die Runden bis zur Gesamtgröße aller Stücke (~28 MB,
	# begrenzt und gewollt) – das soll nicht als Leck zählen.
	for t in MusicMeta.MINIGAME:
		for sec in ["normal", "hurry", "outro"]:
			Audio._stream(String(t[sec].file))
	for pth in Audio.MUSIC.values():
		Audio._stream(String(pth))
	for pth in Audio.JINGLES.values():
		Audio._stream(String(pth))
	Router.log_scenes = true
	Router.scene_changed.connect(_on_scene)
	Router.goto("res://scenes/party/PartyBoard.tscn")
	var t := 0.0
	var last_scene := ""
	var same_t := 0.0
	var last_report := 0.0
	var wall0 := Time.get_ticks_msec()
	while t < max_s:
		await tree.process_frame
		var dt := get_process_delta_time()
		t += dt
		var cur := tree.current_scene
		var name := String(cur.scene_file_path.get_file()) if cur else "-"
		if name != last_scene:
			last_scene = name
			same_t = 0.0
		else:
			same_t += dt
		if t - last_report > 30.0:
			last_report = t
			var st := String(cur.get("state")) if cur and "state" in cur else ""
			var ph := String(Game.party.get("phase", ""))
			print("[SOAK] t=%4.0fs (echt %3.0fs) Szene %s %s · Runde %d/%d · Phase %s · %s" % [t, (Time.get_ticks_msec() - wall0) / 1000.0, name, st, int(Game.party.get("round", 0)), rounds, ph, Router.mem_report()])
		if same_t > 600.0:
			_hang = "%s hängt seit 10 min (Zustand %s, Phase %s)" % [name, String(cur.get("state")) if cur and "state" in cur else "?", String(Game.party.get("phase", ""))]
			break
		if name == "MainMenu.tscn" and _scenes.size() > 2:
			break   # Party zu Ende → zurück im Menü
	_finish(rounds)


func _on_scene(path: String) -> void:
	_scenes.append(path.get_file())


func _finish(rounds: int) -> void:
	# Die "(leer)"-Messungen kommen vom Router (Speicher ohne Szene); hier nur die Brett-Rückkehr vergleichen.
	var fails: Array = []
	if _hang != "":
		fails.append(_hang)
	var boards := _scenes.count("PartyBoard.tscn")
	var played := int(Game.party.get("round", 0))
	print("[SOAK] Szenenwechsel %d · Brett-Besuche %d · erreichte Runde %d · Minispiele %s" % [_scenes.size(), boards, played, str(Game.party.get("minigames_played", []))])
	if played < rounds and _hang == "" and not ("MainMenu.tscn" in _scenes):
		fails.append("Party nicht zu Ende gespielt (Runde %d/%d)" % [played, rounds])
	var leak := Router.mem_trend()
	print("[SOAK] Speicher ohne Szene: %s" % str(leak.samples))
	print("[SOAK] Trend: erste Hälfte ⌀ %.1f MB · zweite Hälfte ⌀ %.1f MB · Zuwachs %.1f MB · Objekte %d → %d" % [leak.first, leak.second, leak.second - leak.first, leak.obj_first, leak.obj_last])
	if leak.samples.size() >= 6 and leak.second - leak.first > 25.0:
		fails.append("Speicher wächst über die Runden (+%.1f MB)" % (leak.second - leak.first))
	if float(leak.tex_first) > 0.0:
		print("[SOAK] Grafikspeicher (Texturen) ohne Szene: erste Hälfte ⌀ %.1f MB · zweite Hälfte ⌀ %.1f MB" % [leak.tex_first, leak.tex_second])
		if leak.samples.size() >= 6 and float(leak.tex_second) - float(leak.tex_first) > 20.0:
			fails.append("Grafikspeicher wächst über die Runden (+%.1f MB)" % (float(leak.tex_second) - float(leak.tex_first)))
	if leak.samples.size() >= 6 and leak.obj_last - leak.obj_first > 1500:
		fails.append("Objektanzahl wächst über die Runden (+%d)" % (leak.obj_last - leak.obj_first))
	if fails.is_empty():
		print("SOAK OK")
		get_tree().quit(0)
	else:
		print("SOAK FEHLER " + "; ".join(fails))
		get_tree().quit(1)
