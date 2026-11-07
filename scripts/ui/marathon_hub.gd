extends Node3D
## Minispiel-Marathon: Zwischenstation zwischen den Minispielen. Wertet das letzte Spiel aus
## (5/3/1/0 Punkte), zeigt die Tabelle mit animierten Balken und startet das nächste Spiel –
## nach dem letzten Spiel folgt die Siegerehrung auf dem Podest.

const POINTS := [5, 3, 1, 0]

var _layer: CanvasLayer
var _root: Control


func _ready() -> void:
	if Game.marathon.is_empty():
		Game.start_marathon(5)
	Game.mode = "marathon"
	var we := WorldKit.env(self, "sunset")
	we.name = "Env"
	_build_backdrop()
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	_root = UI.center_root(_layer)
	Audio.music("menu")
	InputHub.set_touch_profile("none")
	_flow()


func _build_backdrop() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 4.5, 11)
	cam.look_at(Vector3(0, 1.2, 0))
	cam.make_current()
	WorldKit.cylinder(self, 9.0, 0.6, Vector3(0, -0.3, 0), Color("#ffd23f"), false)
	for i in 4:
		var r := CharacterRig.new()
		add_child(r)
		r.setup(Game.hero(Game.players[i].hero).model, i, 1.0)
		r.position = Vector3(-4.5 + i * 3.0, 0, 0)
		r.face_now(Vector3(0, 0, 1))
		r.play("idle")
		r.set_meta("slot", i)
	FX.confetti(Vector3(0, 6, 0), 60)


func _rigs() -> Array[CharacterRig]:
	var out: Array[CharacterRig] = []
	for c in get_children():
		if c is CharacterRig:
			out.append(c)
	return out


func _flow() -> void:
	var m: Dictionary = Game.marathon
	var games: Array = m.games
	var idx: int = m.index
	var gained := [0, 0, 0, 0]
	var res: Dictionary = Game.last_results
	if not res.is_empty() and idx < games.size() and String(res.get("game", "")) == String(games[idx]):
		var places: Array = res.placements
		for i in 4:
			gained[i] = POINTS[clampi(int(places[i]) - 1, 0, 3)]
			m.points[i] = int(m.points[i]) + gained[i]
		m.index = idx + 1
		idx = m.index
		Game.last_results = {}
	await get_tree().process_frame
	var finished := idx >= games.size()
	await _show_table(finished, gained, games)
	if finished:
		await _ceremony()
		Game.marathon = {}
		Game.mode = "menu"
		Router.goto("res://scenes/menu/MainMenu.tscn")
	else:
		var info := Game.minigame_info(String(games[idx]))
		Game.mode = "marathon"
		Router.goto(info.scene)


func _order() -> Array[int]:
	var pts: Array = Game.marathon.points
	var order: Array[int] = [0, 1, 2, 3]
	order.sort_custom(func(a: int, b: int) -> bool:
		if int(pts[a]) != int(pts[b]):
			return int(pts[a]) > int(pts[b])
		return a < b)
	return order


func _show_table(finished: bool, gained: Array, games: Array) -> void:
	var m: Dictionary = Game.marathon
	var panel := UI.panel()
	_root.add_child(panel)
	panel.custom_minimum_size = Vector2(760, 0)
	var v := UI.vbox(12)
	panel.add_child(v)
	var title := UI.label("Minispiel-Marathon", 54, UI.GOLD, true, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := UI.label(("Endstand nach %d Spielen" % games.size()) if finished else ("Spiel %d von %d" % [int(m.index) + 1, games.size()]), 28, UI.ACCENT2, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var best := 1
	for i in 4:
		best = maxi(best, int(m.points[i]))
	var bars: Array = []
	for i in _order():
		var row := UI.hbox(12)
		var nm := UI.label(Game.hero(Game.players[i].hero).name, 28, Game.player_color(i).lightened(0.3), true)
		nm.custom_minimum_size.x = 300
		row.add_child(nm)
		var bar_bg := ColorRect.new()
		bar_bg.color = Color(1, 1, 1, 0.12)
		bar_bg.custom_minimum_size = Vector2(260, 26)
		bar_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar_bg)
		var bar := ColorRect.new()
		bar.color = Game.player_color(i)
		bar.size = Vector2(0, 26)
		bar_bg.add_child(bar)
		var pts := UI.label("%d" % int(m.points[i]), 30, Color.WHITE, true)
		pts.custom_minimum_size.x = 60
		row.add_child(pts)
		if int(gained[i]) > 0:
			row.add_child(UI.label("+%d" % int(gained[i]), 26, Color("#7dff9a"), true))
		v.add_child(row)
		bars.append([bar, 260.0 * float(m.points[i]) / float(best)])
	if not finished:
		var next := Game.minigame_info(String(games[int(m.index)]))
		var nl := UI.label("Als Nächstes: %s" % next.get("name", "?"), 30, Color.WHITE, true)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nl)
	var go := UI.prompt("a", "Siegerehrung!" if finished else "Weiter", 28)
	v.add_child(go)
	await get_tree().process_frame
	panel.position = (_root.size - panel.size) / 2.0 + Vector2(0, -40)
	Juice.pop_in(panel, 0.4)
	for b in bars:
		var tw := create_tween()
		tw.tween_property(b[0], "size:x", float(b[1]), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Figuren: Führende jubeln
	var lead := _order()[0]
	for r in _rigs():
		if int(r.get_meta("slot")) == lead:
			r.react("victory")
		elif int(gained[int(r.get_meta("slot"))]) > 0:
			r.react("cheer")
	var has_human := false
	for i in 4:
		if not Game.players[i].cpu:
			has_human = true
	var wait := 0.0
	while wait < (10.0 if has_human else 2.5):
		await get_tree().process_frame
		wait += get_process_delta_time()
		if wait > 0.6 and InputHub.any_human_pressed("a"):
			break
	Audio.sfx("ui_confirm")
	var tw2 := create_tween()
	tw2.tween_property(panel, "modulate:a", 0.0, 0.25)
	await tw2.finished
	panel.queue_free()


func _ceremony() -> void:
	var order := _order()
	var entries: Array = []
	for i in order:
		entries.append({"model": Game.hero(Game.players[i].hero).model, "name": Game.hero(Game.players[i].hero).name, "color": Game.player_color(i), "player": i})
	await CutsceneManager.play("Podium", {"entries": [entries[0], entries[1], entries[2], entries[3]], "skippable": true})
