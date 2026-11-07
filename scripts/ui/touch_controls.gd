extends CanvasLayer
## On-Screen-Controls für Touch-Geräte (Smartphone, Tablet, Lumos One im Touch-Modus).
##
## * Schwebender Analog-Stick in der linken Bildschirmhälfte (erscheint dort, wo der Daumen landet)
## * Kontextabhängige Buttons je Profil (board / minigame / race / menu)
## * Visuelles Haptik-Feedback (Puls + Ring) und echte Vibration (navigator.vibrate)
## * Anpassbares Layout: Positionen/Größe/Deckkraft werden in den Einstellungen gespeichert

const DEFAULT_LAYOUT := {
	"a": Vector2(0.905, 0.64), "b": Vector2(0.80, 0.74), "x": Vector2(0.795, 0.53),
	"r": Vector2(0.915, 0.40), "start": Vector2(0.64, 0.07),
}
const BUTTON_STYLE := {
	"a": {"color": Color("#2ee59d"), "radius": 62.0},
	"b": {"color": Color("#ff5c7a"), "radius": 50.0},
	"x": {"color": Color("#ffc93c"), "radius": 50.0},
	"r": {"color": Color("#5ab8ff"), "radius": 56.0},
	"start": {"color": Color("#ffffff"), "radius": 30.0},
}
const PROFILES := {
	"none": {"stick": false, "buttons": {}},
	"menu": {"stick": false, "buttons": {}},
	"board": {"stick": true, "buttons": {"a": "OK", "b": "Nein", "start": "II"}},
	"minigame": {"stick": true, "buttons": {"a": "Sprung", "b": "Aktion", "start": "II"}},
	"action_only": {"stick": false, "buttons": {"a": "Los!", "start": "II"}},
	"race": {"stick": true, "buttons": {"r": "Drift", "x": "Item", "b": "Bremse", "start": "II"}},
	"edit": {"stick": true, "buttons": {"a": "A", "b": "B", "x": "Item", "r": "Drift", "start": "II"}},
}

var profile := "none"
var editing := false

var _root: Control
var _stick: TouchStick
var _buttons := {}
var _finger_owner := {}     # finger index -> "stick" | button id
var _held := {}
var _drag_btn := ""


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_stick = TouchStick.new()
	_root.add_child(_stick)
	for id in BUTTON_STYLE.keys():
		var b := TouchButton.new()
		b.id = id
		b.color = BUTTON_STYLE[id].color
		b.radius = BUTTON_STYLE[id].radius
		_root.add_child(b)
		_buttons[id] = b
	get_viewport().size_changed.connect(_relayout)
	EventBus.settings_changed.connect(_relayout)
	InputHub.device_changed.connect(func(_k: String) -> void: _refresh_visibility())
	set_profile("none")


func set_profile(p: String) -> void:
	profile = p if PROFILES.has(p) else "none"
	_release_all()
	_relayout()


func _refresh_visibility() -> void:
	var show_any := (Game.is_touch_device or editing) and profile != "none" and profile != "menu"
	var prof: Dictionary = PROFILES[profile]
	var buttons: Dictionary = prof.buttons.duplicate()
	if profile == "race" and not Game.settings.auto_accel:
		buttons["a"] = "Gas"
	_stick.visible = show_any and prof.stick
	for id in _buttons:
		var b: TouchButton = _buttons[id]
		b.visible = show_any and buttons.has(id)
		b.label = buttons.get(id, "")
		b.queue_redraw()


func _relayout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var layout: Dictionary = DEFAULT_LAYOUT.duplicate()
	var saved: Dictionary = Game.settings.get("touch_layout", {})
	for k in saved.keys():
		if layout.has(k):
			layout[k] = saved[k] if saved[k] is Vector2 else layout[k]
	var scl: float = Game.settings.get("touch_scale", 1.0)
	var opacity: float = Game.settings.get("touch_opacity", 0.8)
	for id in _buttons:
		var b: TouchButton = _buttons[id]
		b.scale_factor = scl
		b.center = (layout[id] as Vector2) * vs
		b.modulate.a = opacity
		b.queue_redraw()
	_stick.modulate.a = opacity
	_stick.scale_factor = scl
	_stick.home = Vector2(0.14, 0.62) * vs
	_stick.zone = Rect2(Vector2.ZERO, Vector2(vs.x * 0.48, vs.y))
	_stick.reset()
	_refresh_visibility()


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	Game.is_touch_device = true
	if not _stick.visible and _visible_buttons().is_empty():
		if profile != "none" and profile != "menu":
			_refresh_visibility()
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			var hit := _button_at(st.position)
			if hit != "":
				_finger_owner[st.index] = hit
				if editing:
					_drag_btn = hit
				else:
					_press(hit)
				get_viewport().set_input_as_handled()
			elif _stick.visible and _stick.zone.has_point(st.position):
				_finger_owner[st.index] = "stick"
				_stick.begin(st.position)
				get_viewport().set_input_as_handled()
		else:
			var owner: String = _finger_owner.get(st.index, "")
			_finger_owner.erase(st.index)
			if owner == "stick":
				_stick.end()
			elif owner != "":
				if editing:
					_drag_btn = ""
					_save_layout()
				else:
					_release(owner)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		var owner2: String = _finger_owner.get(sd.index, "")
		if owner2 == "stick":
			_stick.drag(sd.position)
			get_viewport().set_input_as_handled()
		elif editing and owner2 != "" and owner2 == _drag_btn:
			(_buttons[owner2] as TouchButton).center = sd.position
			(_buttons[owner2] as TouchButton).queue_redraw()
	_push_state()


func _visible_buttons() -> Array:
	var out := []
	for id in _buttons:
		if (_buttons[id] as TouchButton).visible:
			out.append(id)
	return out


func _button_at(pos: Vector2) -> String:
	var best := ""
	var best_d := INF
	for id in _buttons:
		var b: TouchButton = _buttons[id]
		if not b.visible:
			continue
		var d := pos.distance_to(b.center)
		if d < b.radius * b.scale_factor * 1.25 and d < best_d:
			best = id
			best_d = d
	return best


func _press(id: String) -> void:
	_held[id] = true
	(_buttons[id] as TouchButton).pulse()
	InputHub.latch_touch_press(id)
	InputHub.vibrate_device(14)


func _release(id: String) -> void:
	_held[id] = false
	(_buttons[id] as TouchButton).release()


func _release_all() -> void:
	for id in _held.keys():
		if _held[id]:
			_release(id)
	_held.clear()
	_finger_owner.clear()
	if _stick:
		_stick.end()
	_push_state()


func _push_state() -> void:
	var held := {}
	for id in _held:
		if _held[id]:
			held[id] = true
	var mv := _stick.value if _stick and _stick.visible else Vector2.ZERO
	if profile == "race" and Game.settings.auto_accel and Game.is_touch_device:
		held["a"] = not held.get("b", false)
	InputHub.set_touch_state(mv, held)


func start_edit() -> void:
	editing = true
	set_profile("edit")


func stop_edit() -> void:
	editing = false
	_save_layout()
	set_profile("none")


func reset_layout() -> void:
	Game.settings.touch_layout = {}
	Game.save_settings()
	_relayout()


func _save_layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var lay := {}
	for id in _buttons:
		lay[id] = (_buttons[id] as TouchButton).center / vs
	Game.settings.touch_layout = lay
	Game.save_settings()


# ------------------------------------------------------------------------------------------
class TouchStick extends Control:
	var home := Vector2(200, 500)
	var zone := Rect2()
	var base := Vector2.ZERO
	var knob := Vector2.ZERO
	var value := Vector2.ZERO
	var active := false
	var scale_factor := 1.0
	var max_r := 78.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func reset() -> void:
		base = home
		knob = home
		value = Vector2.ZERO
		active = false
		queue_redraw()

	func begin(p: Vector2) -> void:
		active = true
		base = p
		knob = p
		value = Vector2.ZERO
		queue_redraw()

	func drag(p: Vector2) -> void:
		var r := max_r * scale_factor
		var off := (p - base)
		if off.length() > r * 1.6:
			base = p - off.normalized() * r * 1.6   # Basis wandert mit (Floating-Stick)
			off = p - base
		knob = base + off.limit_length(r)
		value = (knob - base) / r
		if value.length() < 0.12:
			value = Vector2.ZERO
		queue_redraw()

	func end() -> void:
		active = false
		value = Vector2.ZERO
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "knob", home, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "base", home, 0.12)
		tw.tween_callback(queue_redraw)
		tw.chain().tween_callback(queue_redraw)

	func _process(_d: float) -> void:
		if visible and not active:
			queue_redraw()

	func _draw() -> void:
		var r := max_r * scale_factor
		draw_circle(base, r * 1.25, Color(0, 0, 0, 0.22))
		draw_arc(base, r * 1.25, 0, TAU, 48, Color(1, 1, 1, 0.55), 4.0, true)
		for k in 4:
			var ang := k * PI / 2.0
			var tip := base + Vector2.from_angle(ang) * r * 1.02
			draw_colored_polygon(PackedVector2Array([tip + Vector2.from_angle(ang) * 10, tip + Vector2.from_angle(ang + 2.2) * 8, tip + Vector2.from_angle(ang - 2.2) * 8]), Color(1, 1, 1, 0.5))
		draw_circle(knob + Vector2(0, 5), r * 0.55, Color(0, 0, 0, 0.25))
		draw_circle(knob, r * 0.55, Color(1, 1, 1, 0.92 if active else 0.75))
		draw_circle(knob, r * 0.38, Color(0.85, 0.9, 1.0, 1.0))


class TouchButton extends Control:
	var id := ""
	var label := ""
	var color := Color.WHITE
	var radius := 50.0
	var center := Vector2.ZERO
	var scale_factor := 1.0
	var press_scale := 1.0
	var ring := 0.0
	var pressed_now := false
	var _font: Font

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _ready() -> void:
		_font = load("res://assets/fonts/LilitaOne-Regular.ttf")

	func pulse() -> void:
		pressed_now = true
		var tw := create_tween().set_parallel(true)
		press_scale = 0.84
		ring = 0.0
		tw.tween_property(self, "ring", 1.0, 0.35).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(_v: float) -> void: queue_redraw(), 0.0, 1.0, 0.35)

	func release() -> void:
		pressed_now = false
		var tw := create_tween()
		tw.tween_property(self, "press_scale", 1.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_method(func(_v: float) -> void: queue_redraw(), 0.0, 1.0, 0.18)

	func _draw() -> void:
		var r := radius * scale_factor * press_scale
		if ring > 0.0 and ring < 1.0:
			draw_arc(center, radius * scale_factor * (1.0 + ring * 0.7), 0, TAU, 48, Color(color, 1.0 - ring), 6.0 * (1.0 - ring) + 1.0, true)
		draw_circle(center + Vector2(0, 6 * scale_factor), r, Color(0, 0, 0, 0.3))
		draw_circle(center, r, color.darkened(0.25) if pressed_now else color)
		draw_circle(center + Vector2(-r * 0.25, -r * 0.3), r * 0.45, Color(1, 1, 1, 0.22))
		draw_arc(center, r, 0, TAU, 48, Color(1, 1, 1, 0.85), 3.0, true)
		if _font and label != "":
			var fs := int(clampf(r * (0.55 if label.length() <= 2 else 0.34), 12, 40))
			var sz := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
			draw_string_outline(_font, center + Vector2(-sz.x / 2.0, fs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.55))
			draw_string(_font, center + Vector2(-sz.x / 2.0, fs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
