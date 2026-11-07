class_name ButtonPrompt
extends HBoxContainer
## Eingabehinweis mit dem echten Symbol des aktuellen Geräts (Xbox/PlayStation/Switch/Tastatur/Touch).
## Aktualisiert sich automatisch, wenn der Spieler das Eingabegerät wechselt.

var action := "a"
var text := ""
var font_size := 30
var _icon: TextureRect
var _label: Label


func setup(a: String, t: String, size := 30) -> ButtonPrompt:
	action = a
	text = t
	font_size = size
	add_theme_constant_override("separation", 10)
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(size * 1.35, size * 1.35)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_label = UI.label(t, size, Color.WHITE, true, 8)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
	InputHub.device_changed.connect(func(_k: String) -> void: _refresh())
	_refresh()
	return self


func set_text(t: String) -> void:
	text = t
	_refresh()


func _refresh() -> void:
	if not is_instance_valid(_label):
		return
	var tex := InputHub.glyph_texture(action)
	_icon.texture = tex
	_icon.visible = tex != null
	if InputHub.last_device == "touch":
		_label.text = "Tippen: " + text
	elif tex == null:
		_label.text = "%s: %s" % [InputHub.glyph(action), text]
	else:
		_label.text = text
