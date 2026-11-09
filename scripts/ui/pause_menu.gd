class_name PauseMenu
extends CanvasLayer
## Globales Pausenmenü (Start/Esc/Touch-"II") für Brett, Minispiele, Rennen und Abenteuer-Modi.
## Offline wird das Spiel angehalten; online läuft es weiter (die anderen spielen ja), das Menü bietet
## dann "Raum verlassen". Lautstärke lässt sich direkt anpassen.

const PAUSABLE := ["/party/", "/minigames/", "/racer/", "/modes/", "/menu/MarathonHub"]

var open := false
var _root: Control
var _panel: PanelContainer
var _confirm: Button
var _help: Label
var _cool := 0.0


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS


func _allowed() -> bool:
	if Router.busy:
		return false
	var cur := get_tree().current_scene
	if cur == null:
		return false
	var path := cur.scene_file_path
	for p in PAUSABLE:
		if path.contains(p):
			return true
	return false


func _process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	if _cool > 0.0:
		return
	if InputHub.any_human_pressed("start") or (Input.is_action_just_pressed("ui_cancel") and open):
		if open:
			close()
		elif _allowed():
			show_menu()


func show_menu() -> void:
	if open:
		return
	open = true
	_cool = 0.25
	if not Net.in_game():
		get_tree().paused = true
	Audio.sfx("ui_open")
	_root = UI.center_root(self)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.1, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_panel = UI.panel()
	_root.add_child(_panel)
	var v := UI.vbox(12)
	_panel.add_child(v)
	var t := UI.label("Pause", 60, UI.GOLD, true, 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if Net.in_game():
		var on := UI.label("Online-Spiel läuft weiter", 20, Color(1, 1, 1, 0.7), true)
		on.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(on)
	var resume := UI.button("Weiter", Color("#2ecc71"), 32, 420)
	resume.pressed.connect(close)
	v.add_child(resume)
	v.add_child(_slider("Musik", "music"))
	v.add_child(_slider("Effekte", "sfx"))
	var hb := UI.button("Steuerung", Color("#5a4a80"), 26, 420)
	_help = UI.label("Stick/Steuerkreuz: Bewegen · A: Springen/Bestätigen · B: Aktion/Zurück\nX/LB: Item · RB/RT: Drift · Start: Pause\nTastatur: WASD · Leertaste = A · K = B · E = Item · Shift = Drift · Esc = Pause", 18, Color(1, 1, 1, 0.8))
	_help.visible = false
	hb.pressed.connect(func() -> void: _help.visible = not _help.visible)
	v.add_child(hb)
	v.add_child(_help)
	_confirm = UI.button("Raum verlassen" if Net.in_game() else "Zum Hauptmenü", Color("#c0392b"), 26, 420)
	_confirm.pressed.connect(_quit)
	v.add_child(_confirm)
	await get_tree().process_frame
	_panel.position = (_root.size - _panel.size) / 2.0
	Juice.pop_in(_panel, 0.25)
	resume.grab_focus()


func _slider(title: String, key: String) -> Control:
	var h := UI.hbox(14)
	var l := UI.label(title, 24, Color.WHITE, true)
	l.custom_minimum_size.x = 140
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(Game.settings.get(key, 0.8))
	s.custom_minimum_size = Vector2(260, 40)
	s.value_changed.connect(func(val: float) -> void:
		Game.settings[key] = val
		Game.save_settings()
		if key == "sfx":
			Audio.sfx("coin_single"))
	h.add_child(s)
	return h


func _quit() -> void:
	if _confirm.text.begins_with("Wirklich"):
		close()
		if Net.in_game():
			Net.leave()
		Game.mode = "menu"
		Router.goto("res://scenes/menu/MainMenu.tscn")
		return
	_confirm.text = "Wirklich? Nochmal drücken"
	Juice.ui_punch(_confirm, 0.2, 0.3)
	Audio.sfx("ui_error")


func close() -> void:
	if not open:
		return
	open = false
	_cool = 0.25
	get_tree().paused = false
	Audio.sfx("ui_close")
	if is_instance_valid(_root):
		_root.queue_free()
