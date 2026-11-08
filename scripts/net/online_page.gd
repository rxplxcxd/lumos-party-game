class_name OnlinePage
extends Control
## Online-Lobby im Hauptmenü: Raum erstellen/beitreten per Raumcode, Figur wählen, bereit melden,
## Host wählt Spiel (Lumos Party auf dem Brett, Nitro-Dash-Rennen oder ein netzwerkfähiges Minispiel)
## und startet für bis zu 4 Geräte. Freie Plätze übernehmen CPUs (vom Host gesteuert).

const ROUNDS := [5, 10, 15, 20]

var GAMES: Array = []
var _board_idx := 0
var _game_stepper: Control
var _party_rows: Array = []
var _rounds_idx := 1
var _pmode_idx := 0

var menu: Node
var _v: VBoxContainer
var _status: Label
var _room_box: VBoxContainer
var _join_box: VBoxContainer
var _code_label: Label
var _players_box: VBoxContainer
var _net_label: Label
var _host_box: VBoxContainer
var _start: Button
var _ready_btn: Button
var _code_edit: LineEdit
var _game_idx := 0
var _track_idx := 0
var _laps_idx := 1
var _ready := false


func build(m: Node) -> OnlinePage:
	menu = m
	GAMES = [{"mode": "party", "name": "Lumos Party – Brettspiel"}, {"mode": "race", "name": "Nitro Dash – Online-Rennen"},
		{"mode": "minigame", "id": "_random", "name": "Minispiel: Zufall!"}]
	for mg in Game.MINIGAMES:
		if bool(mg.get("online", false)) and not ("boss" in (mg.get("cats", []) as Array) and (mg.get("cats", []) as Array).size() == 1):
			GAMES.append({"mode": "minigame", "id": mg.id, "name": "Minispiel: " + String(mg.name)})
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := UI.panel()
	add_child(panel)
	panel.anchor_bottom = 1.0
	panel.offset_left = 28
	panel.offset_top = 28
	panel.offset_bottom = -28
	panel.offset_right = 28 + 760
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	_v = UI.vbox(12)
	_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_v)
	_v.add_child(UI.label("Online-Spiel", 56, UI.GOLD, true, 12))
	_status = UI.label("Spiele mit bis zu 4 Smartphones, Tablets, PCs oder Lumos-Konsolen – über einen Raumcode.", 22, Color(1, 1, 1, 0.85))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 700
	_v.add_child(_status)
	# Eigene Figur
	var heroes := Game.HEROES.map(func(h: Dictionary) -> String: return h.name)
	var cur := 0
	for i in Game.HEROES.size():
		if Game.HEROES[i].id == Game.players[0].hero:
			cur = i
	var hs := Stepper.new().setup(heroes, cur, 300, Game.player_color(0).darkened(0.2))
	hs.changed.connect(func(i: int) -> void: Net.set_hero(Game.HEROES[i].id))
	_v.add_child(_row("Deine Figur", hs))
	_build_join()
	_build_room()
	var back := UI.button("Zurück", Color("#5a4a80"), 28)
	back.pressed.connect(func() -> void:
		if Net.online:
			Net.leave()
		menu.show_page("main"))
	_v.add_child(back)
	Net.status.connect(_on_status)
	Net.room_changed.connect(_refresh)
	Net.left.connect(func(reason: String) -> void: _on_status(reason))
	_refresh()
	return self


func _row(title: String, ctrl: Control) -> Control:
	var h := UI.hbox(16)
	var l := UI.label(title, 26, Color.WHITE, true)
	l.custom_minimum_size.x = 200
	h.add_child(l)
	h.add_child(ctrl)
	return h


func _build_join() -> void:
	_join_box = UI.vbox(12)
	_v.add_child(_join_box)
	var create := UI.button("  Raum erstellen", Color("#00b894"), 32, 520)
	create.icon = UI.icon_tex("globe", 32)
	create.custom_minimum_size.y = 70
	create.pressed.connect(func() -> void: Net.create_room())
	_join_box.add_child(create)
	var big := UI.button("  Athlon-Raum (bis 20 Spieler)", Color("#ff9f1a"), 26, 520)
	big.icon = UI.icon_tex("trophy", 28)
	big.custom_minimum_size.y = 58
	big.tooltip_text = "Lumos-Athlon: Wettlauf über schnelle Solo-Minispiele für bis zu 20 Geräte"
	big.pressed.connect(func() -> void: Net.create_room(Net.MAX_BIG))
	_join_box.add_child(big)
	var row := UI.hbox(12)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "Raumcode"
	_code_edit.max_length = 6
	_code_edit.custom_minimum_size = Vector2(240, 60)
	_code_edit.add_theme_font_size_override("font_size", 32)
	_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_edit.text_changed.connect(func(t: String) -> void:
		var up := t.to_upper()
		if up != t:
			var c := _code_edit.caret_column
			_code_edit.text = up
			_code_edit.caret_column = c)
	_code_edit.text_submitted.connect(func(t: String) -> void: Net.join_room(t))
	row.add_child(_code_edit)
	var join := UI.button("Beitreten", Color("#2f9bff"), 30, 260)
	join.custom_minimum_size.y = 60
	join.pressed.connect(func() -> void: Net.join_room(_code_edit.text))
	row.add_child(join)
	_join_box.add_child(row)
	var hint := UI.label("Tipp: Alle Geräte brauchen Internet. Die Verbindung läuft direkt (WebRTC) – im selben WLAN unter 20 ms.", 18, Color(1, 1, 1, 0.6))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 700
	_join_box.add_child(hint)


func _build_room() -> void:
	_room_box = UI.vbox(10)
	_v.add_child(_room_box)
	var code_row := UI.hbox(14)
	code_row.add_child(UI.label("Raumcode", 26, Color(1, 1, 1, 0.8), true))
	_code_label = UI.label("-----", 64, UI.GOLD, true, 12)
	code_row.add_child(_code_label)
	if OS.has_feature("web"):
		var copy := UI.button("Kopieren", Color("#5a4a80"), 20, 140)
		copy.pressed.connect(func() -> void:
			JavaScriptBridge.eval("navigator.clipboard && navigator.clipboard.writeText(%s)" % JSON.stringify(Net.code), true)
			Account.toast("Raumcode kopiert", Color("#7dff9a")))
		code_row.add_child(copy)
	else:
		var copy2 := UI.button("Kopieren", Color("#5a4a80"), 20, 140)
		copy2.pressed.connect(func() -> void: DisplayServer.clipboard_set(Net.code))
		code_row.add_child(copy2)
	_room_box.add_child(code_row)
	_players_box = UI.vbox(6)
	_room_box.add_child(_players_box)
	_net_label = UI.label("", 20, UI.ACCENT2, true)
	_room_box.add_child(_net_label)
	_ready_btn = UI.button("Bereit!", Color("#2ecc71"), 30, 300)
	_ready_btn.pressed.connect(func() -> void:
		_ready = not _ready
		Net.set_ready(_ready)
		_ready_btn.text = "Doch nicht" if _ready else "Bereit!")
	_room_box.add_child(_ready_btn)
	_host_box = UI.vbox(10)
	_room_box.add_child(_host_box)
	var gs := Stepper.new().setup(GAMES.map(func(g: Dictionary) -> String: return g.name), _game_idx, 420, Color("#00b894"))
	_game_stepper = gs
	_host_box.add_child(_row("Spiel", gs))
	var ts := Stepper.new().setup(Game.TRACKS.map(func(t: Dictionary) -> String: return t.name), _track_idx, 320, Color("#2f9bff"))
	ts.changed.connect(func(i: int) -> void: _track_idx = i)
	var track_row := _row("Strecke", ts)
	_host_box.add_child(track_row)
	var ls := Stepper.new().setup(["2 Runden", "3 Runden", "5 Runden"], _laps_idx, 220, Color("#2f9bff"))
	ls.changed.connect(func(i: int) -> void: _laps_idx = i)
	var laps_row := _row("Runden", ls)
	_host_box.add_child(laps_row)
	var bs := Stepper.new().setup(Game.BOARDS.map(func(b: Dictionary) -> String: return b.name), _board_idx, 380, Color("#ff9f1a"))
	bs.changed.connect(func(i: int) -> void: _board_idx = i)
	var board_row := _row("Brett", bs)
	_host_box.add_child(board_row)
	var rs := Stepper.new().setup(ROUNDS.map(func(r: int) -> String: return "%d Runden" % r), _rounds_idx, 220, Color("#ff9f1a"))
	rs.changed.connect(func(i: int) -> void: _rounds_idx = i)
	var rounds_row := _row("Länge", rs)
	_host_box.add_child(rounds_row)
	var ms := Stepper.new().setup(Game.PARTY_MODES.map(func(pm: Dictionary) -> String: return pm.name), _pmode_idx, 320, Color("#ff9f1a"))
	ms.changed.connect(func(i: int) -> void: _pmode_idx = i)
	var mode_row := _row("Regeln", ms)
	_host_box.add_child(mode_row)
	var vis := func(i: int) -> void:
		_game_idx = i
		track_row.visible = GAMES[i].mode == "race"
		laps_row.visible = GAMES[i].mode == "race"
		board_row.visible = GAMES[i].mode == "party"
		rounds_row.visible = GAMES[i].mode == "party"
		mode_row.visible = GAMES[i].mode == "party"
	gs.changed.connect(vis)
	vis.call(_game_idx)
	_party_rows = [track_row, laps_row, board_row, rounds_row, mode_row]
	_start = UI.button("Spiel starten!", Color("#ff4fb8"), 34, 420)
	_start.custom_minimum_size.y = 70
	_start.pressed.connect(_start_game)
	_host_box.add_child(_start)
	var leave := UI.button("Raum verlassen", Color("#c0392b"), 24, 300)
	leave.pressed.connect(func() -> void:
		Net.leave()
		_ready = false)
	_room_box.add_child(leave)


func _start_game() -> void:
	if Net.capacity() > Net.MAX_PLAYERS:
		Net.start_game({"mode": "athlon"})
		return
	var g: Dictionary = GAMES[_game_idx]
	var cfg := {"mode": g.mode}
	if g.mode == "race":
		cfg["track"] = Game.TRACKS[_track_idx].id
		cfg["laps"] = [2, 3, 5][_laps_idx]
	elif g.mode == "party":
		cfg["board"] = Game.BOARDS[_board_idx].id
		cfg["rounds"] = ROUNDS[_rounds_idx]
		cfg["pmode"] = Game.PARTY_MODES[_pmode_idx].id
	else:
		var id := String(g.id)
		if id == "_random":
			var ids: Array = []
			for k in range(3, GAMES.size()):
				if not bool(Game.minigame_info(String(GAMES[k].id)).get("mode", false)):
					ids.append(GAMES[k].id)
			id = String(ids[randi() % ids.size()])
		cfg["id"] = id
	Net.start_game(cfg)


func _on_status(text: String) -> void:
	if is_instance_valid(_status):
		_status.text = text
		Juice.ui_punch(_status, 0.08, 0.2)


func _refresh() -> void:
	if not is_instance_valid(_room_box):
		return
	_join_box.visible = not Net.online
	_room_box.visible = Net.online
	if not Net.online:
		return
	_code_label.text = Net.code
	_host_box.visible = Net.is_host
	for c in _players_box.get_children():
		c.queue_free()
	var ids: Array = Net.players.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return int(Net.players[a].get("slot", 0)) < int(Net.players[b].get("slot", 0)))
	var all_ready := true
	var big := Net.capacity() > Net.MAX_PLAYERS
	for id in ids:
		var p: Dictionary = Net.players[id]
		var slot := int(p.get("slot", 0))
		var row := UI.hbox(12)
		row.add_child(UI.label("P%d" % (slot + 1), 22 if big else 28, Game.player_color(slot % 4) if slot < 4 else Athlon.runner_color(slot), true))
		var nm := UI.label("%s%s" % [String(p.get("name", "Spieler")), "  (du)" if id == Net.me else ""], 18 if big else 24, Color.WHITE, true)
		nm.custom_minimum_size.x = 300
		row.add_child(nm)
		row.add_child(UI.label(Game.hero(String(p.get("hero", "knight"))).name, 20, Color(1, 1, 1, 0.7)))
		if id == Net.host_id:
			row.add_child(UI.icon_rect("trophy", 26, UI.GOLD))
		var rd := bool(p.get("ready", false))
		if not rd and id != Net.host_id:
			all_ready = false
		row.add_child(UI.icon_rect("check" if rd else "pause", 24, Color("#7dff9a") if rd else Color(1, 1, 1, 0.35)))
		_players_box.add_child(row)
	if big:
		_players_box.add_child(UI.label("%d / %d Läufer · freie Plätze bis 8 füllen CPUs auf" % [ids.size(), Net.capacity()], 18, Color(1, 1, 1, 0.5)))
	else:
		for k in range(ids.size(), Net.MAX_PLAYERS):
			_players_box.add_child(UI.label("P%d – frei (CPU)" % (k + 1), 20, Color(1, 1, 1, 0.4)))
	if is_instance_valid(_game_stepper):
		_game_stepper.get_parent().visible = not big
		for r in _party_rows:
			if big:
				(r as Control).visible = false
	_start.disabled = not all_ready
	_start.text = "Spiel starten!" if all_ready else "Warte auf „Bereit“ …"
	_ready_btn.visible = not Net.is_host


func _process(_delta: float) -> void:
	if Net.online and is_instance_valid(_net_label):
		var ping := ("%d ms" % int(Net.rtt_ms)) if Net.rtt_ms >= 0.0 else ("Host" if Net.is_host else "…")
		_net_label.text = "Verbindung: %s · %s · %d/%d Spieler" % [Net.transport, ping, Net.players.size(), Net.capacity()]
