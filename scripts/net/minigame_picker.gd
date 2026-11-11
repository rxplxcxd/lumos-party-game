class_name MinigamePicker
extends Control
## Minispiel-Auswahl für die Online-Lobby: Kategorie-Filter, „Alle an/aus“, alphabetische Liste mit Häkchen,
## optional ▶ zum direkten Start eines bestimmten Spiels. Statt sich durch Dutzende Einträge zu klicken.
## Die Auswahl (deaktivierte IDs) liegt in Game.settings.online_pool_off und gilt für Zufall und Party-Brett.

signal closed
signal play(id: String)

const CAT_NAMES := {"all": "Alle", "ffa": "Jeder gegen jeden", "1v3": "1 gegen 3", "2v2": "2 gegen 2", "duel": "Duell",
	"luck": "Glück", "coin": "Münzen", "showdown": "Showdown"}

var allow_play := false
var _games: Array = []
var _off: Dictionary = {}
var _filter := "all"
var _grid: GridContainer
var _count: Label
var _chips: HBoxContainer


## Alle online-fähigen Minispiele (ohne reine Boss-Kämpfe), alphabetisch.
static func online_games() -> Array:
	var out: Array = []
	for m in Game.MINIGAMES:
		var cats: Array = m.get("cats", ["ffa"])
		if bool(m.get("online", false)) and m.has("scene") and not (cats.size() == 1 and "boss" in cats):
			out.append(m)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
	return out


static func disabled_ids() -> Array:
	return (Game.settings.get("online_pool_off", []) as Array).duplicate()


static func enabled_ids() -> Array:
	var off := disabled_ids()
	return online_games().filter(func(m: Dictionary) -> bool: return not (m.id in off)).map(func(m: Dictionary) -> String: return String(m.id))


func build(with_play := false) -> MinigamePicker:
	allow_play = with_play
	_games = online_games()
	for id in disabled_ids():
		_off[id] = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.01, 0.08, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := UI.panel()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 40
	panel.offset_right = -40
	panel.offset_top = 30
	panel.offset_bottom = -30
	add_child(panel)
	var v := UI.vbox(12)
	panel.add_child(v)
	var head := UI.hbox(16)
	head.add_child(UI.label("Minispiele auswählen", 44, UI.GOLD, true, 10))
	_count = UI.label("", 24, Color(1, 1, 1, 0.8), true)
	head.add_child(_count)
	v.add_child(head)
	# Kategorie-Filter (nur Kategorien, die es wirklich gibt)
	_chips = UI.hbox(8)
	var present := {"all": true}
	for m in _games:
		for c in (m.get("cats", ["ffa"]) as Array):
			if CAT_NAMES.has(c):
				present[c] = true
	for c in CAT_NAMES:
		if present.has(c):
			var b := UI.button(CAT_NAMES[c], Color("#8a5a3c"), 20, 0)
			b.set_meta("cat", c)
			b.pressed.connect(func() -> void:
				_filter = c
				_rebuild())
			_chips.add_child(b)
	var chip_scroll := ScrollContainer.new()
	chip_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chip_scroll.custom_minimum_size.y = 64
	chip_scroll.add_child(_chips)
	v.add_child(chip_scroll)
	var bulk := UI.hbox(10)
	var on := UI.button("Alle an", Color("#2ecc71"), 22, 200)
	on.pressed.connect(func() -> void: _set_visible_all(true))
	var off := UI.button("Alle aus", Color("#c0392b"), 22, 200)
	off.pressed.connect(func() -> void: _set_visible_all(false))
	bulk.add_child(on)
	bulk.add_child(off)
	var done := UI.button("Fertig", Color("#ff4fb8"), 24, 220)
	done.pressed.connect(_close)
	bulk.add_child(done)
	v.add_child(bulk)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)
	_rebuild()
	return self


func _visible_games() -> Array:
	if _filter == "all":
		return _games
	return _games.filter(func(m: Dictionary) -> bool: return _filter in (m.get("cats", ["ffa"]) as Array))


func _rebuild() -> void:
	for c in _grid.get_children():
		c.queue_free()
	for b in _chips.get_children():
		(b as Button).modulate = Color.WHITE if String(b.get_meta("cat")) == _filter else Color(1, 1, 1, 0.55)
	var first: Control = null
	for m in _visible_games():
		var id := String(m.id)
		var row := UI.hbox(6)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tags := " · ".join((m.get("cats", ["ffa"]) as Array).map(func(c: String) -> String: return String(CAT_NAMES.get(c, c))))
		var t := UI.button("  %s\n  %s" % [m.name, tags], Color("#2c6e49") if not _off.has(id) else Color("#3a2f55"), 20, 0)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.alignment = HORIZONTAL_ALIGNMENT_LEFT
		t.custom_minimum_size.y = 64
		t.icon = UI.icon_tex("check", 28) if not _off.has(id) else null
		t.modulate = Color.WHITE if not _off.has(id) else Color(1, 1, 1, 0.6)
		t.pressed.connect(func() -> void:
			if _off.has(id):
				_off.erase(id)
			else:
				_off[id] = true
			Audio.sfx("click", null, -6.0)
			_save()
			_rebuild())
		row.add_child(t)
		if allow_play:
			var pl := UI.button("", Color("#ff9f1a"), 20, 64)
			pl.icon = UI.icon_tex("play", 26)
			pl.tooltip_text = "Genau dieses Spiel jetzt starten"
			pl.custom_minimum_size = Vector2(64, 64)
			pl.pressed.connect(func() -> void:
				play.emit(id)
				_close())
			row.add_child(pl)
		_grid.add_child(row)
		if first == null:
			first = t
	var n_on := _games.filter(func(m: Dictionary) -> bool: return not _off.has(String(m.id))).size()
	_count.text = "%d von %d aktiv" % [n_on, _games.size()]
	if first:
		first.grab_focus.call_deferred()


func _set_visible_all(on: bool) -> void:
	for m in _visible_games():
		if on:
			_off.erase(String(m.id))
		else:
			_off[String(m.id)] = true
	_save()
	_rebuild()


func _save() -> void:
	Game.settings["online_pool_off"] = _off.keys()
	Game.save_settings()


func _close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
