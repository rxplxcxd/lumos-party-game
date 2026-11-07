extends Node3D
## Hauptmenü mit lebendigem 3D-Diorama und Unterseiten:
## main · party (Setup) · race (Setup) · minigames (Arena) · settings · credits

@export var start_page := "main"

var _ui: Control
var _page: Control
var _heroes: Array[CharacterRig] = []
var _cam: Camera3D
var _cam_t := 0.0
var _logo: Control
var _wheel: Node3D

var _party_board := 0
var _party_rounds := 0
var _hero_steppers: Array[Stepper] = []
var _cpu_steppers: Array[Stepper] = []


func _ready() -> void:
	Game.mode = "menu"
	Engine.time_scale = 1.0
	_build_diorama()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_ui = UI.center_root(layer)
	_ui.mouse_filter = Control.MOUSE_FILTER_PASS
	Audio.music("menu")
	InputHub.set_touch_profile("menu")
	_apply_quality()
	var p: String = Router.params.get("page", start_page)
	Router.params = {}
	show_page(p)


# --- 3D-Diorama -------------------------------------------------------------------------------

func _build_diorama() -> void:
	WorldKit.env(self, "day")
	WorldKit.water(self, Vector2(260, 260), -0.6)
	# Insel
	WorldKit.cylinder(self, 9.0, 1.2, Vector3(0, -0.6, 0), Color("#f1d9a0"), false)
	WorldKit.cylinder(self, 7.0, 0.3, Vector3(0, 0.1, 0), Color("#7fd36a"), false)
	for i in 10:
		var a := TAU * i / 10.0
		if sin(a) > 0.2:
			continue   # kein Baum zwischen Kamera und Helden
		WorldKit.place(self, "pirate/palm" if i % 2 == 0 else "pirate/palm_bend", Vector3(cos(a) * 8.0, 0, sin(a) * 8.0), randf() * 360.0, randf_range(0.8, 1.1))
	WorldKit.place(self, "pirate/ship_large", Vector3(-22, -1.0, -26), 35.0, 1.0)
	WorldKit.place(self, "pirate/ship_small", Vector3(26, -0.8, -18), -60.0, 1.0)
	WorldKit.place(self, "pirate/tower", Vector3(14, -0.5, -30), 0.0, 1.5)
	var w := WorldKit.place(self, "arcade/prize_wheel", Vector3(-4.5, 0.2, -3.0), 25.0, 3.2)
	_wheel = w
	WorldKit.place(self, "arena/trophy", Vector3(4.6, 0.2, -3.2), -20.0, 3.0)
	var kart := WorldKit.place(self, "kart/oopi", Vector3(5.6, 0.25, 0.6), -55.0, 2.2)
	kart.set_meta("bob", true)
	WorldKit.place(self, "pirate/chest", Vector3(-5.2, 0.2, 1.8), 30.0, 1.0)
	WorldKit.place(self, "toy/item_box", Vector3(6.2, 2.6, -1.0), 15.0, 2.4)
	WorldKit.place(self, "plat/star", Vector3(0, 4.2, -4.0), 0.0, 4.0)
	var heroes := ["hero/knight", "hero/mage", "hero/barbarian", "hero/rogue", "hero/ranger"]
	var clips := ["wave", "cheer", "idle", "taunt_long", "idle_b"]
	for i in heroes.size():
		var r := CharacterRig.new()
		add_child(r)
		r.setup(heroes[i], -1, 0.95)
		r.position = Vector3(-3.6 + i * 1.8, 0.25, 0.6 - absf(i - 2) * 0.6)
		r.rotation.y = PI + (i - 2) * 0.18
		r.play(clips[i])
		_heroes.append(r)
	for pet in [["pet/cat", Vector3(-2.4, 0.25, 3.0)], ["pet/bunny", Vector3(2.0, 0.25, 3.3)], ["pet/chick", Vector3(-0.2, 0.25, 3.8)]]:
		var pr := CharacterRig.new()
		add_child(pr)
		pr.setup(pet[0], -1, 0.6)
		pr.position = pet[1]
		pr.rotation.y = PI
		pr.play("dance" if randf() < 0.5 else "idle")
	_cam = Camera3D.new()
	_cam.fov = 45.0
	add_child(_cam)
	_cam.make_current()
	_update_cam(0.0)


func _process(delta: float) -> void:
	_cam_t += delta
	_update_cam(delta)
	if _wheel:
		_wheel.rotation.z += delta * 0.8
	# Gelegentliche Slapstick-Momente im Hintergrund
	if randf() < delta * 0.25 and _heroes.size() > 0:
		var h: CharacterRig = _heroes[randi() % _heroes.size()]
		if not h.is_locked():
			h.react(["cheer", "laugh", "dizzy", "wave", "flex", "determined"][randi() % 6])


func _update_cam(_d: float) -> void:
	var a := sin(_cam_t * 0.12) * 0.45
	var offset_x := 3.2 if _page and _page.name != "main" else 2.2
	_cam.position = Vector3(sin(a) * 15.0 - offset_x, 4.6 + sin(_cam_t * 0.3) * 0.3, cos(a) * 15.0)
	_cam.look_at(Vector3(-offset_x * 0.6, 1.6, 0), Vector3.UP)


func _apply_quality() -> void:
	var q: String = Game.settings.quality
	var low := q == "low" or (q == "auto" and (Game.is_touch_device or OS.has_feature("mobile")))
	get_viewport().scaling_3d_scale = 0.75 if low else 1.0
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if low else Viewport.MSAA_2X


# --- Seitensystem -------------------------------------------------------------------------------

func show_page(name: String) -> void:
	if _page:
		var old := _page
		var tw := old.create_tween()
		tw.tween_property(old, "modulate:a", 0.0, 0.15)
		tw.tween_callback(old.queue_free)
	var p: Control
	match name:
		"party":
			p = _page_party()
		"race":
			p = _page_race()
		"minigames":
			p = _page_minigames()
		"settings":
			p = _page_settings()
		"credits":
			p = _page_credits()
		"touch_edit":
			p = _page_touch_edit()
		_:
			p = _page_main()
	p.name = name
	_ui.add_child(p)
	_page = p
	p.modulate.a = 0.0
	p.create_tween().tween_property(p, "modulate:a", 1.0, 0.2)
	await get_tree().process_frame
	var first := _first_focus(p)
	if first:
		first.grab_focus()


func _first_focus(n: Node) -> Control:
	if n is Button and (n as Button).visible and not (n as Button).disabled:
		return n
	for c in n.get_children():
		var r := _first_focus(c)
		if r:
			return r
	return null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _page and _page.name != "main":
		Audio.sfx("ui_back")
		if _page.name == "touch_edit":
			InputHub.touch_controls.call("stop_edit")
			show_page("settings")
		else:
			show_page("main")
		get_viewport().set_input_as_handled()


func _side_panel(title: String, width := 640.0) -> Array:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := UI.panel()
	root.add_child(panel)
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 28
	panel.offset_top = 28
	panel.offset_bottom = -28
	panel.offset_right = 28 + width
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var v := UI.vbox(14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	var t := UI.label(title, 56, UI.GOLD, true, 12)
	v.add_child(t)
	return [root, v]


func _back_button(v: Control, target := "main") -> Button:
	var b := UI.button("Zurück", Color("#5a4a80"), 28)
	b.pressed.connect(func() -> void: show_page(target))
	v.add_child(b)
	return b


# --- Hauptseite -------------------------------------------------------------------------------------

func _page_main() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var logo := UI.vbox(-12)
	root.add_child(logo)
	logo.position = Vector2(48, 30)
	var l1 := UI.label("LUMOS PARTY", 104, Color.WHITE, true, 20)
	l1.add_theme_color_override("font_outline_color", Color("#5a1aa0"))
	logo.add_child(l1)
	var l2 := UI.label("& NITRO DASH", 54, UI.GOLD, true, 14)
	logo.add_child(l2)
	_logo = logo
	var tw := logo.create_tween().set_loops()
	tw.tween_property(logo, "position:y", 38.0, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(logo, "position:y", 30.0, 1.4).set_trans(Tween.TRANS_SINE)
	var v := UI.vbox(14)
	root.add_child(v)
	v.position = Vector2(56, 240)
	var items := [
		["Lumos Party", Color("#ff4fb8"), "party", "Das chaotische 3D-Brettspiel"],
		["Nitro Dash", Color("#2f9bff"), "race", "High-Speed Arcade-Racer"],
		["Minispiel-Arena", Color("#2ecc71"), "minigames", "Alle 10 Minispiele frei spielen"],
		["Einstellungen", Color("#7b3cff"), "settings", ""],
		["Credits", Color("#5a4a80"), "credits", ""],
	]
	for it in items:
		var b := UI.button(it[0], it[1], 36, 380.0)
		b.custom_minimum_size.y = 72
		b.tooltip_text = it[3]
		var target: String = it[2]
		b.pressed.connect(func() -> void: show_page(target))
		v.add_child(b)
	var foot := UI.label("v%s · Lumos OS · %s" % [ProjectSettings.get_setting("application/config/version", "1.0"), "Touch, Tastatur & bis zu 4 Gamepads"], 18, Color(1, 1, 1, 0.75))
	root.add_child(foot)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(24, -40)
	return root


# --- Party-Setup ----------------------------------------------------------------------------------------

func _page_party() -> Control:
	var arr := _side_panel("Lumos Party", 700)
	var v: VBoxContainer = arr[1]
	var board_names := Game.BOARDS.map(func(b: Dictionary) -> String: return b.name)
	var board_desc := UI.label(Game.BOARDS[_party_board].desc, 22, Color(1, 1, 1, 0.85))
	board_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board_desc.custom_minimum_size = Vector2(620, 60)
	var bs := Stepper.new().setup(board_names, _party_board, 340, Color("#ff4fb8"))
	bs.changed.connect(func(i: int) -> void:
		_party_board = i
		board_desc.text = Game.BOARDS[i].desc)
	v.add_child(_row("Spielbrett", bs))
	v.add_child(board_desc)
	var rs := Stepper.new().setup(["5 Runden", "10 Runden", "15 Runden"], _party_rounds, 220, Color("#ff4fb8"))
	rs.changed.connect(func(i: int) -> void: _party_rounds = i)
	v.add_child(_row("Länge", rs))
	v.add_child(UI.label("Spieler", 32, UI.ACCENT2, true))
	_players_editor(v)
	var start := UI.button("Party starten!", Color("#ff4fb8"), 38, 400)
	start.custom_minimum_size.y = 76
	start.pressed.connect(_start_party)
	v.add_child(start)
	_back_button(v)
	return arr[0]


func _players_editor(v: VBoxContainer) -> void:
	_hero_steppers.clear()
	_cpu_steppers.clear()
	var hero_names := Game.HEROES.map(func(h: Dictionary) -> String: return h.name)
	var pads := Input.get_connected_joypads().size()
	for i in 4:
		var p: Dictionary = Game.players[i]
		var row := UI.hbox(10)
		var tag := UI.label("P%d" % (i + 1), 30, Game.player_color(i), true)
		tag.custom_minimum_size.x = 52
		row.add_child(tag)
		var hs := Stepper.new().setup(hero_names, _hero_index(p.hero), 230, Game.player_color(i).darkened(0.2))
		row.add_child(hs)
		_hero_steppers.append(hs)
		var opts := ["Mensch"] + Game.CPU_LEVELS.map(func(l: String) -> String: return "CPU " + l) if i == 0 else Game.CPU_LEVELS.map(func(l: String) -> String: return "CPU " + l) + (["Mensch (Pad %d)" % (i + 1)] if pads > i else [])
		var start_idx := 0
		if i == 0:
			start_idx = 0 if not p.cpu else 1 + int(p.cpu_level)
		else:
			start_idx = int(p.cpu_level) if p.cpu else (3 if pads > i else 1)
		var cs := Stepper.new().setup(opts, start_idx, 170, Color("#5a4a80"))
		row.add_child(cs)
		_cpu_steppers.append(cs)
		v.add_child(row)


func _hero_index(id: String) -> int:
	for i in Game.HEROES.size():
		if Game.HEROES[i].id == id:
			return i
	return 0


func _apply_players() -> void:
	for i in 4:
		var p: Dictionary = Game.players[i]
		p.hero = Game.HEROES[_hero_steppers[i].index].id
		p.name = Game.HEROES[_hero_steppers[i].index].name
		var label: String = _cpu_steppers[i].value()
		p.cpu = not label.begins_with("Mensch")
		if p.cpu:
			p.cpu_level = Game.CPU_LEVELS.find(label.trim_prefix("CPU "))


func _row(title: String, ctrl: Control) -> Control:
	var h := UI.hbox(16)
	var l := UI.label(title, 28, Color.WHITE, true)
	l.custom_minimum_size.x = 180
	h.add_child(l)
	h.add_child(ctrl)
	return h


func _start_party() -> void:
	_apply_players()
	Game.start_party(Game.BOARDS[_party_board].id, [5, 10, 15][_party_rounds])
	Router.goto("res://scenes/party/PartyBoard.tscn")


# --- Nitro-Dash-Setup ------------------------------------------------------------------------------------

func _page_race() -> Control:
	var arr := _side_panel("Nitro Dash", 700)
	var v: VBoxContainer = arr[1]
	var names := Game.TRACKS.map(func(t: Dictionary) -> String: return t.name)
	var cur := 0
	for i in Game.TRACKS.size():
		if Game.TRACKS[i].id == Game.race_cfg.track:
			cur = i
	var desc := UI.label(Game.TRACKS[cur].desc, 22, Color(1, 1, 1, 0.85))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(620, 50)
	var ts := Stepper.new().setup(names, cur, 320, Color("#2f9bff"))
	ts.changed.connect(func(i: int) -> void:
		Game.race_cfg.track = Game.TRACKS[i].id
		desc.text = Game.TRACKS[i].desc)
	v.add_child(_row("Strecke", ts))
	v.add_child(desc)
	var laps := Stepper.new().setup(["2 Runden", "3 Runden", "5 Runden"], [2, 3, 5].find(Game.race_cfg.laps), 220, Color("#2f9bff"))
	laps.changed.connect(func(i: int) -> void: Game.race_cfg.laps = [2, 3, 5][i])
	v.add_child(_row("Runden", laps))
	var lvl := Stepper.new().setup(Game.CPU_LEVELS, Game.race_cfg.cpu_level, 220, Color("#2f9bff"))
	lvl.changed.connect(func(i: int) -> void: Game.race_cfg.cpu_level = i)
	v.add_child(_row("Gegner", lvl))
	v.add_child(UI.label("Fahrer", 32, UI.ACCENT2, true))
	_players_editor(v)
	var hint := UI.label("Drift halten (R / Shift) und lenken: Funken wechseln Blau → Orange → Regenbogen.\nItems: Kuchendeckel · Homing-Kanonenkugel · Megafon-Schock · Piraten-Anker · Nitro", 20, Color(1, 1, 1, 0.75))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 620
	v.add_child(hint)
	var start := UI.button("Rennen starten!", Color("#2f9bff"), 38, 400)
	start.custom_minimum_size.y = 76
	start.pressed.connect(func() -> void:
		_apply_players()
		Game.mode = "race"
		Router.goto("res://scenes/racer/NitroDash.tscn"))
	v.add_child(start)
	_back_button(v)
	return arr[0]


# --- Minispiel-Arena --------------------------------------------------------------------------------------

func _page_minigames() -> Control:
	var arr := _side_panel("Minispiel-Arena", 760)
	var v: VBoxContainer = arr[1]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	var colors := [Color("#ff4fb8"), Color("#2f9bff"), Color("#2ecc71"), Color("#ff9f1a"), Color("#7b3cff")]
	var desc := UI.label("Wähle ein Minispiel.", 22, Color(1, 1, 1, 0.85))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(700, 64)
	for i in Game.MINIGAMES.size():
		var m: Dictionary = Game.MINIGAMES[i]
		var b := UI.button(m.name, colors[i % colors.size()], 26, 340)
		b.custom_minimum_size.y = 64
		b.focus_entered.connect(func() -> void: desc.text = m.desc)
		b.mouse_entered.connect(func() -> void: desc.text = m.desc)
		b.pressed.connect(func() -> void: _play_minigame(m.id))
		grid.add_child(b)
	v.add_child(desc)
	var rnd := UI.button("Zufall!", Color("#ffcc33"), 30, 300)
	rnd.pressed.connect(func() -> void: _play_minigame(Game.MINIGAMES[randi() % Game.MINIGAMES.size()].id))
	v.add_child(rnd)
	v.add_child(UI.label("Spieler", 30, UI.ACCENT2, true))
	_players_editor(v)
	_back_button(v)
	return arr[0]


func _play_minigame(id: String) -> void:
	if not _hero_steppers.is_empty():
		_apply_players()
	Game.mode = "free_play"
	Router.goto(Game.minigame_info(id).scene)


# --- Einstellungen -----------------------------------------------------------------------------------------

func _page_settings() -> Control:
	var arr := _side_panel("Einstellungen", 700)
	var v: VBoxContainer = arr[1]
	v.add_child(_slider("Musik", "music"))
	v.add_child(_slider("Effekte", "sfx"))
	v.add_child(_slider("Ansager", "voice"))
	v.add_child(_slider("Kamera-Wackeln", "screen_shake"))
	v.add_child(_toggle("Haptik / Vibration", "haptics"))
	v.add_child(_toggle("Auto-Gas (Touch-Racer)", "auto_accel"))
	var q := Stepper.new().setup(["Automatisch", "Niedrig (Handheld)", "Hoch"], ["auto", "low", "high"].find(Game.settings.quality), 300)
	q.changed.connect(func(i: int) -> void:
		Game.settings.quality = ["auto", "low", "high"][i]
		Game.save_settings()
		_apply_quality())
	v.add_child(_row("Grafik", q))
	v.add_child(UI.label("Touch-Steuerung", 30, UI.ACCENT2, true))
	v.add_child(_slider("Button-Größe", "touch_scale", 0.6, 1.5))
	v.add_child(_slider("Deckkraft", "touch_opacity", 0.2, 1.0))
	var edit := UI.button("Layout anpassen", Color("#2f9bff"), 28, 360)
	edit.pressed.connect(func() -> void: show_page("touch_edit"))
	v.add_child(edit)
	var help := UI.label("Tastatur: WASD/Pfeile · Leertaste = A · K = B · E = Item · Shift = Drift · Esc = Pause\nGamepad: Stick/Steuerkreuz · A · B · X/LB = Item · RB/RT = Drift · Start = Pause", 19, Color(1, 1, 1, 0.75))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x = 620
	v.add_child(help)
	_back_button(v)
	return arr[0]


func _slider(title: String, key: String, mn := 0.0, mx := 1.0) -> Control:
	var h := UI.hbox(16)
	var l := UI.label(title, 26, Color.WHITE, true)
	l.custom_minimum_size.x = 250
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 0.05
	s.value = float(Game.settings[key])
	s.custom_minimum_size = Vector2(320, 44)
	s.value_changed.connect(func(val: float) -> void:
		Game.settings[key] = val
		Game.save_settings()
		if key == "sfx":
			Audio.sfx("coin_single"))
	h.add_child(s)
	return h


func _toggle(title: String, key: String) -> Control:
	var c := CheckButton.new()
	c.text = title
	c.button_pressed = bool(Game.settings[key])
	c.add_theme_font_size_override("font_size", 26)
	c.toggled.connect(func(on: bool) -> void:
		Game.settings[key] = on
		Game.save_settings()
		Audio.sfx("ui_toggle"))
	return c


func _page_touch_edit() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	InputHub.touch_controls.call("start_edit")
	var box := UI.vbox(10)
	root.add_child(box)
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-260, 110)
	var info := UI.label("Ziehe die Buttons an die gewünschte Position.", 28, Color.WHITE, true)
	box.add_child(info)
	var row := UI.hbox(12)
	box.add_child(row)
	var done := UI.button("Fertig", Color("#2ecc71"), 30, 200)
	done.pressed.connect(func() -> void:
		InputHub.touch_controls.call("stop_edit")
		show_page("settings"))
	row.add_child(done)
	var reset := UI.button("Zurücksetzen", Color("#ff5c7a"), 30, 240)
	reset.pressed.connect(func() -> void: InputHub.touch_controls.call("reset_layout"))
	row.add_child(reset)
	return root


func _page_credits() -> Control:
	var arr := _side_panel("Credits", 720)
	var v: VBoxContainer = arr[1]
	var txt := """[b]Lumos Party & Nitro Dash[/b] – exklusiver Titel für Lumos OS
Engine: Godot 4 (MIT-Lizenz) · GL-Compatibility / WebGL2

[b]3D-Modelle[/b] (CC0): Kenney – Pirate, Platformer, Castle, Graveyard, Racing, Car, Toy Car, Survival, Space, Nature, Mini Arena, Mini Arcade, Tower Defense, Modular Cave, Watercraft, Fantasy Town, Holiday, Mini Characters, Cube Pets
KayKit (CC0, Kay Lousberg) – Adventurers, Character Animations, Dungeon Pack, Mini-Game Variety Pack, Board Game Bits, Holiday Bits, Forest Nature, RPG Tools

[b]Audio[/b] (CC0): Kenney – Impact, Interface, Digital, RPG, Sci-Fi, UI, Music Jingles, Voiceover
Soundtrack & Cartoon-SFX: prozedural komponiert (tools/compose_music.py, tools/compose_sfx.py)

[b]Schriften[/b] (SIL OFL 1.1): Lilita One (Juan Montoreano), Fredoka (The Fredoka Project Authors)
[b]Icons[/b] (CC0): Kenney – Input Prompts, Medals, Crosshairs, Board Game Info"""
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.text = txt
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(660, 0)
	rt.add_theme_font_override("normal_font", UI.body_font())
	rt.add_theme_font_override("bold_font", UI.title_font())
	rt.add_theme_font_size_override("normal_font_size", 21)
	rt.add_theme_font_size_override("bold_font_size", 24)
	v.add_child(rt)
	_back_button(v)
	return arr[0]
