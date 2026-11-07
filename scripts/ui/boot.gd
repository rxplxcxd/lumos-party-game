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
##   --board=dungeon --track=lumos_ring                  Brett/Strecke

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
	if _args.has("shots") or _args.has("quit"):
		var cap := ShotDaemon.new()
		cap.shots = Array(String(_args.get("shots", "")).split(",", false)).map(func(s: String) -> float: return s.to_float())
		cap.quit_after = String(_args.get("quit", "0")).to_float()
		cap.dir = _args.get("shotdir", "user://shots")
		get_tree().root.add_child.call_deferred(cap)
	await _splash()
	var target: String = _args.get("scene", "res://scenes/menu/MainMenu.tscn")
	if _args.has("board"):
		Game.start_party(_args.board, int(_args.get("rounds", "5")))
		Game.mode = "party"
	if _args.has("track"):
		Game.race_cfg.track = _args.track
	Router.goto(target)


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
