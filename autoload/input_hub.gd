extends Node
## Vereinheitlichte Eingabe für bis zu 4 Spieler-Slots.
##
## Slot 0: Tastatur + Touch + erstes Gamepad. Slots 1–3: weitere Gamepads.
## CPU-Spieler schreiben über set_virtual() in denselben Kanal – Minispiele fragen
## also immer nur move()/held()/pressed() ab, egal ob Mensch oder KI.

const ACTIONS := ["a", "b", "x", "y", "r", "l", "start"]
const DEADZONE := 0.22

const KEYS := {
	"a": [KEY_SPACE, KEY_ENTER, KEY_J, KEY_Z],
	"b": [KEY_K, KEY_X, KEY_BACKSPACE],
	"x": [KEY_E, KEY_L, KEY_C, KEY_CTRL],
	"y": [KEY_Q, KEY_I, KEY_V],
	"r": [KEY_SHIFT, KEY_SPACE],
	"l": [KEY_TAB],
	"start": [KEY_ESCAPE, KEY_P],
}
const PAD := {
	"a": [JOY_BUTTON_A], "b": [JOY_BUTTON_B], "x": [JOY_BUTTON_X, JOY_BUTTON_LEFT_SHOULDER],
	"y": [JOY_BUTTON_Y], "r": [JOY_BUTTON_RIGHT_SHOULDER], "l": [JOY_BUTTON_LEFT_SHOULDER],
	"start": [JOY_BUTTON_START, JOY_BUTTON_BACK],
}

signal device_changed(kind: String)

var last_device := "keyboard"   # keyboard | gamepad | touch
var mouse_play := false   # während Minispielen: Maustasten als A/B (siehe docs/CONTROLS.md)
var touch_controls: CanvasLayer

var _held_phys: Array = []
var _held_proc: Array = []
var _edge_phys: Array = []
var _edge_proc: Array = []
var _latch_phys: Array = []
var _latch_proc: Array = []
var _virtual: Array = []
var _touch := {"move": Vector2.ZERO, "held": {}}


## Konsolen-Bedienung für die gesamte Oberfläche: A = Bestätigen, B = Zurück, D-Pad UND linker Stick
## navigieren den Fokus (Godot belegt ui_accept standardmäßig nicht mit einer Gamepad-Taste).
func _setup_ui_actions() -> void:
	_ui_joy_button("ui_accept", JOY_BUTTON_A)
	_ui_joy_button("ui_cancel", JOY_BUTTON_B)
	_ui_joy_button("ui_up", JOY_BUTTON_DPAD_UP)
	_ui_joy_button("ui_down", JOY_BUTTON_DPAD_DOWN)
	_ui_joy_button("ui_left", JOY_BUTTON_DPAD_LEFT)
	_ui_joy_button("ui_right", JOY_BUTTON_DPAD_RIGHT)
	_ui_joy_axis("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_ui_joy_axis("ui_down", JOY_AXIS_LEFT_Y, 1.0)
	_ui_joy_axis("ui_left", JOY_AXIS_LEFT_X, -1.0)
	_ui_joy_axis("ui_right", JOY_AXIS_LEFT_X, 1.0)
	for act in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		InputMap.action_set_deadzone(act, 0.5)


func _ui_joy_button(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == button:
			return
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.device = -1
	InputMap.action_add_event(action, ev)


func _ui_joy_axis(action: String, axis: JoyAxis, dir: float) -> void:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadMotion and (e as InputEventJoypadMotion).axis == axis and signf((e as InputEventJoypadMotion).axis_value) == dir:
			return
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = dir
	ev.device = -1
	InputMap.action_add_event(action, ev)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -1000
	process_physics_priority = -1000
	for i in 4:
		_held_phys.append({})
		_held_proc.append({})
		_edge_phys.append({})
		_edge_proc.append({})
		_latch_phys.append({})
		_latch_proc.append({})
		_virtual.append({"move": Vector2.ZERO, "held": {}})
	var tc_script: GDScript = load("res://scripts/ui/touch_controls.gd")
	touch_controls = tc_script.new()
	add_child(touch_controls)
	Input.joy_connection_changed.connect(_on_joy_changed)
	_setup_ui_actions()
	# Kanten-Erkennung an die Frame-Signale hängen: InputHub verbindet sich als Erster und läuft
	# damit vor allen Koroutinen (await process_frame) und vor jedem _process/_physics_process.
	get_tree().process_frame.connect(_on_process_frame)
	get_tree().physics_frame.connect(_on_physics_frame)
	_detect_lumos()


func _on_joy_changed(_device: int, _connected: bool) -> void:
	_detect_lumos()


func _detect_lumos() -> void:
	for d in Input.get_connected_joypads():
		if Input.get_joy_name(d).to_lower().contains("lumos"):
			Game.is_lumos_device = true


func pad_for_slot(slot: int) -> int:
	var pads := Input.get_connected_joypads()
	if slot < pads.size():
		return pads[slot]
	return -1


func is_slot_human(slot: int) -> bool:
	if slot < 0 or slot >= Game.players.size():
		return false
	return not Game.players[slot].cpu


# --- Rohdaten ---------------------------------------------------------------------

## Online: Spiel-Slot, der von den lokalen Eingabegeräten (Slot-0-Geräte) gesteuert wird. -1 = aus.
var online_local := -1


## Eingabegerät-Index für einen Spiel-Slot: -2 = virtuell (CPU), -1 = keine lokale Eingabe (Online-Mitspieler).
var net_driven: Dictionary = {}   # Online (Host-Modell): Slot -> true, Eingaben kommen vom Client


## Online (Host-Modell): Eingaben eines entfernten Spielers einspeisen.
func set_net_input(slot: int, mv: Vector2, held_actions: Dictionary) -> void:
	if slot < 0 or slot > 3:
		return
	net_driven[slot] = true
	_virtual[slot].move = mv
	_virtual[slot].held = held_actions


func _dev(slot: int) -> int:
	if not is_slot_human(slot) or net_driven.has(slot):
		return -2
	if online_local >= 0:
		return 0 if slot == online_local else -1
	return slot


func _raw_held(slot: int, action: String) -> bool:
	var dev := _dev(slot)
	if dev == -2:
		return _virtual[slot].held.get(action, false)
	if dev == -1:
		return false
	slot = dev
	var pad := pad_for_slot(slot)
	if pad >= 0:
		for b in PAD[action]:
			if Input.is_joy_button_pressed(pad, b):
				return true
		if action == "r" and Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT) > 0.5:
			return true
		if action == "x" and Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT) > 0.5:
			return true
	if slot == 0:
		for k in KEYS[action]:
			if Input.is_physical_key_pressed(k):
				return true
		if _touch.held.get(action, false):
			return true
		# Maus (Laptop ohne Gamepad): Linksklick = A, Rechtsklick = B
		if mouse_play and not Game.is_touch_device and ((action == "a" and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) or (action == "b" and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))):
			return true
	return false


func _raw_move(slot: int) -> Vector2:
	var dev := _dev(slot)
	if dev == -2:
		return (_virtual[slot].move as Vector2).limit_length(1.0)
	if dev == -1:
		return Vector2.ZERO
	slot = dev
	var v := Vector2.ZERO
	var pad := pad_for_slot(slot)
	if pad >= 0:
		var s := Vector2(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X), Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y))
		if s.length() > DEADZONE:
			v += s.normalized() * inverse_lerp(DEADZONE, 1.0, minf(s.length(), 1.0))
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_LEFT): v.x -= 1
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_RIGHT): v.x += 1
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_UP): v.y -= 1
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_DOWN): v.y += 1
	if slot == 0:
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): v.x -= 1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): v.x += 1
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): v.y -= 1
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): v.y += 1
		v += _touch.move
	return v.limit_length(1.0)


# --- Abfrage-API -----------------------------------------------------------------------

func move(slot: int) -> Vector2:
	return _raw_move(slot)


func held(slot: int, action: String) -> bool:
	return _raw_held(slot, action) or _latch_phys[slot].get(action, false)


## Gerade gedrückt. Erkennt automatisch, ob aus _physics_process oder _process gefragt wird.
func pressed(slot: int, action: String) -> bool:
	if Engine.is_in_physics_frame():
		return _edge_phys[slot].get(action, -1) == Engine.get_physics_frames()
	return _edge_proc[slot].get(action, -1) == Engine.get_process_frames()


## Gerade gedrückt (Prozess-Frame-genau; für _process / UI-Logik).
func ui_pressed(slot: int, action: String) -> bool:
	return _edge_proc[slot].get(action, -1) == Engine.get_process_frames()


## Irgendein menschlicher Spieler hat die Aktion gedrückt (Prozess-Frame).
func any_human_pressed(action: String) -> bool:
	for i in 4:
		if is_slot_human(i) and ui_pressed(i, action):
			return true
	return false


func set_virtual(slot: int, mv: Vector2, held_actions: Dictionary = {}) -> void:
	_virtual[slot].move = mv
	_virtual[slot].held = held_actions


## Zusätzlich eine Aktion für diesen Frame halten (z. B. Sprungtaste der CPU weiterhalten)
func hold_virtual(slot: int, action: String) -> void:
	var h: Dictionary = (_virtual[slot].held as Dictionary).duplicate()
	h[action] = true
	_virtual[slot].held = h


func virtual_held(slot: int, action: String) -> bool:
	return bool((_virtual[slot].held as Dictionary).get(action, false))


func clear_virtual() -> void:
	for v in _virtual:
		v.move = Vector2.ZERO
		v.held = {}


func set_touch_state(mv: Vector2, held_actions: Dictionary) -> void:
	_touch.move = mv
	_touch.held = held_actions


func latch_touch_press(action: String) -> void:
	_latch_phys[0][action] = true
	_latch_proc[0][action] = true
	_set_device("touch")


## Sichere Ränder (Notch/Rundungen): x = links, y = rechts (Pixel im Viewport).
func safe_insets() -> Vector2:
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("(function(){var d=document.createElement('div');d.style.cssText='position:fixed;left:env(safe-area-inset-left);right:env(safe-area-inset-right)';document.body.appendChild(d);var s=getComputedStyle(d);var r=[parseFloat(s.left)||0,parseFloat(s.right)||0,window.devicePixelRatio||1];d.remove();return JSON.stringify(r);})()", true)
		if v is String:
			var arr = JSON.parse_string(v)
			if arr is Array and arr.size() == 3:
				var scale: float = get_viewport().get_visible_rect().size.x / maxf(1.0, float(DisplayServer.window_get_size().x) / float(arr[2]))
				return Vector2(float(arr[0]), float(arr[1])) * scale
		return Vector2.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var full := DisplayServer.screen_get_size()
	if safe.size.x <= 0 or full.x <= 0:
		return Vector2.ZERO
	return Vector2(safe.position.x, full.x - safe.end.x)


func set_touch_profile(profile: String) -> void:
	mouse_play = profile != "none"   # Maus-Tasten zählen nur im laufenden Spiel als A/B (Menüs: normale Klicks)
	if touch_controls:
		touch_controls.call("set_profile", profile)


# --- Kanten-Erkennung ---------------------------------------------------------------------

func _on_physics_frame() -> void:
	_update_edges(_held_phys, _edge_phys, _latch_phys, Engine.get_physics_frames())


func _on_process_frame() -> void:
	_update_edges(_held_proc, _edge_proc, _latch_proc, Engine.get_process_frames())


func _update_edges(held_store: Array, edge_store: Array, latch_store: Array, frame: int) -> void:
	for slot in 4:
		var hs: Dictionary = held_store[slot]
		var latch: Dictionary = latch_store[slot]
		for a in ACTIONS:
			var now: bool = _raw_held(slot, a) or latch.get(a, false)
			if now and not hs.get(a, false):
				edge_store[slot][a] = frame
			hs[a] = now
		latch.clear()


## Gamepad-Navigation ohne aktuellen Fokus (z. B. nach Mausklick): ersten sichtbaren Button fokussieren.
func _ensure_ui_focus(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion) or not event.is_pressed():
		return
	var nav := false
	for act in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept"]:
		if event.is_action(act):
			nav = true
	if not nav or get_viewport().gui_get_focus_owner() != null:
		return
	var best := _first_button(get_tree().root)
	if best:
		best.grab_focus()
		get_viewport().set_input_as_handled()


func _first_button(n: Node) -> Button:
	for c in n.get_children():
		if c is Button and (c as Button).is_visible_in_tree() and not (c as Button).disabled and (c as Button).focus_mode != Control.FOCUS_NONE:
			return c as Button
		var r := _first_button(c)
		if r:
			return r
	return null


func _input(event: InputEvent) -> void:
	_ensure_ui_focus(event)
	if event is InputEventKey and event.pressed and not event.echo:
		_set_device("keyboard")
		for a in ACTIONS:
			if (event as InputEventKey).physical_keycode in KEYS[a]:
				_latch_phys[0][a] = true
				_latch_proc[0][a] = true
	elif event is InputEventJoypadButton and event.pressed:
		_set_device("gamepad")
		var pads := Input.get_connected_joypads()
		var slot := pads.find(event.device)
		if slot >= 0 and slot < 4:
			for a in ACTIONS:
				if (event as InputEventJoypadButton).button_index in PAD[a]:
					_latch_phys[slot][a] = true
					_latch_proc[slot][a] = true
	elif mouse_play and event is InputEventMouseButton and event.pressed and not Game.is_touch_device:
		var mb := (event as InputEventMouseButton).button_index
		var act := "a" if mb == MOUSE_BUTTON_LEFT else ("b" if mb == MOUSE_BUTTON_RIGHT else "")
		if act != "":
			_set_device("keyboard")
			_latch_phys[0][act] = true   # auch sehr kurze Klicks zwischen zwei Frames zählen
			_latch_proc[0][act] = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		_set_device("gamepad")
	elif event is InputEventScreenTouch and Game.is_touch_device:
		_set_device("touch")


func _set_device(kind: String) -> void:
	if kind != last_device:
		last_device = kind
		device_changed.emit(kind)


# --- Haptik ------------------------------------------------------------------------------------

## Vibration für einen Spieler-Slot (Gamepad-Rumble, Handy-Vibration im Browser/nativ).
func rumble(slot: int, strength := 0.5, duration := 0.15) -> void:
	if not Game.settings.haptics or not is_slot_human(slot):
		return
	var pad := pad_for_slot(slot)
	if pad >= 0:
		Input.start_joy_vibration(pad, clampf(strength * 0.7, 0, 1), clampf(strength, 0, 1), duration)
	if slot == 0 and last_device == "touch":
		vibrate_device(int(duration * 1000.0 * clampf(strength + 0.3, 0.3, 1.0)))


func vibrate_device(ms: int) -> void:
	if not Game.settings.haptics:
		return
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try{navigator.vibrate&&navigator.vibrate(%d)}catch(e){}" % ms, true)
	elif OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


## Bezeichnung einer Taste je nach zuletzt genutztem Eingabegerät.
## Controller-Layout eines Gamepads anhand des Gerätenamens (SDL-GUID/Name).
func pad_layout(device: int = -1) -> String:
	if device < 0:
		var pads := Input.get_connected_joypads()
		if pads.is_empty():
			return "xbox"
		device = pads[0]
	var n := Input.get_joy_name(device).to_lower() + " " + Input.get_joy_guid(device).to_lower()
	if n.contains("lumos") or n.contains("nintendo") or n.contains("switch") or n.contains("pro controller") or n.contains("joy-con") or n.contains("057e"):
		return "switch"
	if n.contains("playstation") or n.contains("dualsense") or n.contains("dualshock") or n.contains("ps4") or n.contains("ps5") or n.contains("054c") or n.contains("wireless controller"):
		return "playstation"
	return "xbox"


## Aktuelles Glyphen-Set: touch | keyboard | xbox | playstation | switch
func glyph_set() -> String:
	match last_device:
		"touch":
			return "touch"
		"gamepad":
			return pad_layout()
		_:
			return "keyboard"


## Textur des Button-Symbols für eine Aktion im aktuellen Eingabegerät (oder null).
func glyph_texture(action: String) -> Texture2D:
	var set_name := glyph_set()
	var table: Dictionary = Assets.GLYPHS.get(set_name, {})
	if not table.has(action):
		return null
	return Assets.icon(table[action])


## Textbezeichnung (Fallback, wenn kein Bild passt).
func glyph(action: String) -> String:
	match glyph_set():
		"touch":
			return {"a": "A", "b": "B", "x": "Item", "r": "Drift", "start": "Pause"}.get(action, action.to_upper())
		"playstation":
			return {"a": "Kreuz", "b": "Kreis", "x": "Quadrat", "y": "Dreieck", "r": "R1", "l": "L1", "start": "Options"}.get(action, action.to_upper())
		"switch":
			return {"a": "B", "b": "A", "x": "Y", "y": "X", "r": "R", "l": "L", "start": "+"}.get(action, action.to_upper())
		"xbox":
			return {"a": "A", "b": "B", "x": "X", "y": "Y", "r": "RB", "l": "LB", "start": "Menü"}.get(action, action.to_upper())
		_:
			return {"a": "Leertaste", "b": "K", "x": "E", "y": "Q", "r": "Shift", "l": "Tab", "start": "Esc"}.get(action, action.to_upper())
