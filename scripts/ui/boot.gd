extends Node
## Boot: Lumos-Splash, Vorladen der wichtigsten Ressourcen, dann Hauptmenü.
##
## Test-/Dev-Optionen (nach "--" auf der Kommandozeile oder als URL-Parameter im Web):
##   --scene=res://scenes/minigames/DungeonDrop.tscn   Szene direkt starten
##   --mode=free_play|party|race                         Spielmodus setzen
##   --cpu                                               alle Spieler CPU
##   --shots=2,5,9                                       Screenshots nach x Sekunden
##   --shotdir=/pfad                                     Zielordner für Screenshots
##   --quit=20                                           nach x Sekunden beenden
##   --board=dungeon --rounds=5 --track=lumos_ring       Brett/Strecke
##   --party-mode=classic|blitz|team                     Party-Modus
##   --race-mode=single|gp|time --cup=0                  Renn-Modus (Grand Prix mit Cup-Index)
##   --marathon=5                                        Minispiel-Marathon mit n Spielen
##   --cat=1v3|2v2|duel --solo=0                         Minispiel-Kategorie/Teams für Direktstart
##   --touch                                             Touch-Steuerung erzwingen

const PRELOAD := [
	"res://scenes/menu/MainMenu.tscn",
]

var _args := {}


func _ready() -> void:
	_parse_args()
	get_tree().root.theme = UI.theme()
	if _args.has("cpu"):
		for p in Game.players:
			p.cpu = true
	if _args.has("mode"):
		Game.mode = _args.mode
	if _args.has("touch"):
		Game.is_touch_device = true
	if _args.has("shots") or _args.has("quit"):
		var cap := ShotDaemon.new()
		cap.shots = Array(String(_args.get("shots", "")).split(",", false)).map(func(s: String) -> float: return s.to_float())
		cap.quit_after = String(_args.get("quit", "0")).to_float()
		cap.dir = _args.get("shotdir", "user://shots")
		get_tree().root.add_child.call_deferred(cap)
	await _splash()
	var target: String = _args.get("scene", "res://scenes/menu/MainMenu.tscn")
	if _args.has("board"):
		Game.start_party(_args.board, int(_args.get("rounds", "5")), String(_args.get("party-mode", "classic")))
		Game.mode = "party"
	if _args.has("track"):
		Game.race_cfg.track = _args.track
	if _args.has("race-mode"):
		Game.race_cfg.mode = _args["race-mode"]
		if Game.race_cfg.mode == "gp":
			Game.start_gp(int(_args.get("cup", "0")))
	if _args.has("cat"):
		var cs := {"cat": String(_args.cat)}
		if _args.has("solo"):
			cs["solo"] = int(_args.solo)
		if String(_args.cat) == "2v2":
			cs["teams"] = [0, 1, 0, 1]
		if String(_args.cat) == "duel":
			cs["active"] = [true, true, false, false]
		Game.minigame_setup = cs
	if _args.has("marathon"):
		Game.start_marathon(int(_args.marathon))
		target = "res://scenes/menu/MarathonHub.tscn"
	if _args.has("laps"):
		Game.race_cfg.laps = int(_args.laps)
	if _args.has("net-test"):
		_net_test()
		return
	Router.goto(target, {"page": _args.page} if _args.has("page") else {})


## Dev: automatischer Online-Test zweier Instanzen (siehe tools/dev/net_test.sh).
func _net_test() -> void:
	var mode: String = _args["net-test"]
	var code_file: String = _args.get("net-code-file", "/tmp/lumos_net_code")
	Net.status.connect(func(t: String) -> void: print("[NET] ", t))
	Net.room_changed.connect(func() -> void: print("[NET] Spieler: %d, Transport: %s" % [Net.players.size(), Net.transport]))
	var tick := func() -> void:
		while true:
			await get_tree().create_timer(5.0, true).timeout
			print("[NET] empfangen: %s rtt=%d" % [Net.debug_counts, int(Net.rtt_ms)])
	tick.call()
	if mode == "host":
		Net.create_room(Net.MAX_BIG if String(_args.get("net-game", "race")) == "athlon" else Net.MAX_PLAYERS)
		while not Net.online:
			await get_tree().process_frame
		print("[NET] CODE ", Net.code)
		var f := FileAccess.open(code_file, FileAccess.WRITE)
		f.store_string(Net.code)
		f.close()
		var need := int(_args.get("net-players", "2"))
		while Net.players.size() < need:
			await get_tree().process_frame
		await get_tree().create_timer(2.0).timeout
		var game := String(_args.get("net-game", "race"))
		if game == "race":
			Net.start_game({"mode": "race", "track": String(_args.get("track", "lumos_ring")), "laps": int(_args.get("laps", "1"))})
		elif game == "athlon":
			Net.start_game({"mode": "athlon"})
		elif game == "party":
			Net.start_game({"mode": "party", "board": String(_args.get("net-board", "meadow")), "rounds": int(_args.get("net-rounds", "5")), "pmode": String(_args.get("party-mode", "classic"))})
		else:
			Net.start_game({"mode": "minigame", "id": game})
	else:
		var code := ""
		while code == "":
			if FileAccess.file_exists(code_file):
				code = FileAccess.get_file_as_string(code_file).strip_edges()
			await get_tree().create_timer(0.3).timeout
		Net.join_room(code)
		while not Net.online:
			await get_tree().process_frame
		Net.set_ready(true)


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var s := String(a).trim_prefix("--")
		var kv := s.split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("window.location.search", true)
		if q is String and (q as String).length() > 1:
			for part in (q as String).substr(1).split("&"):
				var kv2 := part.split("=", true, 1)
				if kv2.size() == 2 and kv2[0] in ["scene", "mode", "cpu", "board", "track"]:
					_args[kv2[0]] = kv2[1].uri_decode()


func _splash() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := UI.center_root(layer)
	UI.gradient_bg(root, Color("#120634"), Color("#3a0f6a"))
	var v := UI.vbox(6)
	root.add_child(v)
	v.set_anchors_preset(Control.PRESET_CENTER)
	var logo := UI.label("LUMOS", 120, Color.WHITE, true, 18)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(logo)
	var sub := UI.label("PARTY  &  NITRO DASH", 42, UI.GOLD, true, 10)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(1, 1, 1, 0.15)
	bar_bg.custom_minimum_size = Vector2(420, 10)
	v.add_child(bar_bg)
	var bar := ColorRect.new()
	bar.color = UI.ACCENT
	bar.size = Vector2(0, 10)
	bar_bg.add_child(bar)
	await get_tree().process_frame
	v.position = (root.size - v.size) / 2.0
	Juice.pop_in(logo, 0.6)
	# Vorladen: Rig-Animationen + Menü
	var steps := PRELOAD.size() + 1
	Assets.rig_library()
	bar.size.x = 420.0 / steps
	await get_tree().process_frame
	for i in PRELOAD.size():
		if ResourceLoader.exists(PRELOAD[i]):
			load(PRELOAD[i])
		bar.size.x = 420.0 * (i + 2) / steps
		await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	# Browser erlauben Ton erst nach einer Geste: "Press Start" wie auf der Konsole
	if OS.has_feature("web") and not _args.has("scene") and not _args.has("net-test"):
		bar_bg.visible = false
		var hint := UI.label("Tippen oder Taste drücken", 34, Color.WHITE, true, 10)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(hint)
		var tw := hint.create_tween().set_loops()
		tw.tween_property(hint, "modulate:a", 0.35, 0.7).set_trans(Tween.TRANS_SINE)
		tw.tween_property(hint, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
		_started = false
		while not _started:
			await get_tree().process_frame
		tw.kill()
		Audio.sfx("ui_confirm")
		Juice.ui_punch(hint, 0.2, 0.3)
		await get_tree().create_timer(0.25).timeout


var _started := true


func _input(event: InputEvent) -> void:
	if _started:
		return
	if (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
		_started = true
		Audio.sfx("ui_start", null, -6.0, 1.0, 0.0)
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.__lumosResumeAudio && window.__lumosResumeAudio()", true)


class ShotDaemon extends Node:
	var shots: Array = []
	var quit_after := 0.0
	var dir := "user://shots"
	var _t := 0.0
	var _n := 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		DirAccess.make_dir_recursive_absolute(dir)

	func _process(delta: float) -> void:
		_t += delta / maxf(Engine.time_scale, 0.01)
		if shots.size() > 0 and _t >= float(shots[0]):
			shots.pop_front()
			var img := get_viewport().get_texture().get_image()
			var path := "%s/shot_%02d_%04.1fs.png" % [dir, _n, _t]
			img.save_png(path)
			print("SHOT ", path)
			_n += 1
		if quit_after > 0.0 and _t >= quit_after:
			print("QUIT after ", _t)
			get_tree().quit(0)
