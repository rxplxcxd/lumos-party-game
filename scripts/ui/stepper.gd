class_name Stepper
extends HBoxContainer
## "< Wert >"-Auswahl, bedienbar mit Touch, Maus, Gamepad (links/rechts bei Fokus) und Tastatur.

signal changed(index: int)

## "value": links/rechts ändert den Wert (einzelne Auswahl). "focus": links/rechts wandert zwischen den
## Spalten (z. B. Lobby: Charakter → Mensch/CPU), A auf einem Pfeil ändert den Wert – kein „Gefangensein“.
var nav_mode := "value"
var options: Array = []
var index := 0
var _label: Label
var _left: Button
var _right: Button


func setup(opts: Array, start := 0, width := 260.0, accent := Color("#7b3cff")) -> Stepper:
	options = opts
	index = clampi(start, 0, maxi(opts.size() - 1, 0))
	add_theme_constant_override("separation", 6)
	_left = UI.button("", accent, 28)
	_left.icon = UI.cozy("arrow_l_cream")   # Cozy-Pfeil (Creme mit Holzrand)
	_left.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_left.custom_minimum_size = Vector2(64, 56)
	_right = UI.button("", accent, 28)
	_right.icon = UI.cozy("arrow_r_cream")
	_right.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_right.custom_minimum_size = Vector2(64, 56)
	_label = UI.label("", 28, Color.WHITE, true)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(width, 56)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_left)
	add_child(_label)
	add_child(_right)
	_left.pressed.connect(func() -> void: step(-1))
	_right.pressed.connect(func() -> void: step(1))
	for b in [_left, _right]:
		b.gui_input.connect(_on_btn_input)
	_refresh()
	return self


func _on_btn_input(ev: InputEvent) -> void:
	if nav_mode != "value":
		return
	if ev.is_action_pressed("ui_left"):
		step(-1)
		accept_event()
	elif ev.is_action_pressed("ui_right"):
		step(1)
		accept_event()


func step(d: int) -> void:
	if options.is_empty():
		return
	index = wrapi(index + d, 0, options.size())
	_refresh()
	Juice.ui_punch(_label, 0.15, 0.25)
	Audio.sfx("ui_move", null, -3.0, 1.0 + 0.04 * float(index % 5), 0.0)
	changed.emit(index)


func set_index(i: int) -> void:
	index = clampi(i, 0, options.size() - 1)
	_refresh()


func value() -> Variant:
	return options[index]


func _refresh() -> void:
	if _label and not options.is_empty():
		_label.text = str(options[index])


func arrows() -> Array[Button]:
	return [_left, _right]


func focus_first() -> void:
	_right.grab_focus()
