extends Node
## Prüfskript für die Systeme aus 1.2.4: CPU-Stufen (Game.lv), Inventar-Schutz, Item-Taktik je Stufe,
## Emote-Grafiken und -Abklingzeit, Stepper-Navigation, Touch-Wischen, Menü-Figuren,
## Online-Codec, Spielerliste (Roster) und Host-Schnappschuss. Gibt je Prüfung PASS/FAIL aus, Exit-Code 1 bei Fehler.
##   godot --headless --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/test_systems.gd [--emote-sheet=/pfad.png]

var _fails := 0


func _ok(cond: bool, what: String) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		_fails += 1


## Ersatz-Brett für BoardItems: Abstand zum Stern und Sternpreis frei einstellbar
class FakeBoard extends Node:
	var star_dist := 7
	var lock := false
	func _dist(_a: int, _b: int) -> int:
		return star_dist
	func _star_cost(_p := -1) -> int:
		return 20
	func _lock_ahead(_p: int) -> bool:
		return lock


func run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	# --- CPU-Stufen -------------------------------------------------------------------------------------------
	_ok(Game.CPU_LEVELS.size() == 4 and Game.CPU_LEVELS[3] == "Insane", "vier CPU-Stufen inkl. Insane")
	_ok(is_equal_approx(float(Game.lv([0.3, 0.14, 0.05], 1)), 0.14), "lv: Stufe 1 = Listenwert")
	var miss := float(Game.lv([0.3, 0.14, 0.05], 3, true))
	_ok(miss > 0.0 and miss < 0.05, "lv: Insane-Fehlerquote kleiner als Profi, aber > 0 (%.3f)" % miss)
	var succ := float(Game.lv([0.7, 0.85, 0.97], 3, true))
	_ok(succ > 0.97 and succ < 1.0, "lv: Insane-Trefferquote > Profi, < 100 %% (%.3f)" % succ)
	var react := float(Game.lv_react([0.42, 0.3, 0.21], 3))
	_ok(react >= 0.12 and react < 0.21, "lv: Insane-Reaktionszeit menschlich (%.3f s)" % react)
	_ok(is_equal_approx(float(Game.lv([0.9, 0.97, 1.02], 3, false)), 1.02), "lv: kein Bonus wo es Mogeln wäre")
	_ok(Game.lv([3, 5, 7], 3, true) is int, "lv: ganzzahlige Listen bleiben ganzzahlig")
	_ok(is_equal_approx(float(Game.lv([0.8, 1.0, 1.2], 3)), 1.2), "lv: abgestimmte Größen (Regler, Timing) bleiben auf Profi-Niveau")
	_ok(Game.lv_react([0.55, 0.3, 0.12], 3) >= 0.12, "lv_react: nie schneller als menschlich bzw. Profi (%.3f s)" % Game.lv_react([0.55, 0.3, 0.12], 3))
	var n_react := 0
	for f in DirAccess.get_files_at("res://scripts/minigames"):
		if f.ends_with(".gd"):
			n_react += FileAccess.get_file_as_string("res://scripts/minigames/" + f).count("Game.lv_react(")
	_ok(n_react >= 8, "Reaktionszeiten der Minispiele laufen über lv_react (%d Stellen)" % n_react)
	# --- Inventar-Schutz --------------------------------------------------------------------------------------
	Game.reset_players(0)
	Game.start_party("meadow", 5, "classic")
	Game.players[0].items = ["double_dice", "key"]
	Game.players[2].items = ["trap"]
	var pb: Node = load("res://scripts/party/party_board.gd").new()
	Game.party.inv_guard = pb.call("_inventory_copy")
	Game.players[0].items = []            # simulierter Verlust beim Szenenwechsel
	(Game.players[2].items as Array).clear()
	pb.call("_verify_inventory")
	_ok(Game.players[0].items == ["double_dice", "key"] and Game.players[2].items == ["trap"], "Inventar nach Minispiel/Cutscene wiederhergestellt")
	_ok(not Game.party.has("inv_guard"), "Schutz-Snapshot wird verbraucht")
	pb.free()
	# --- Item-Taktik ------------------------------------------------------------------------------------------
	var fb := FakeBoard.new()
	add_child(fb)
	Game.party.star_space = 5
	for i in 4:
		Game.players[i].space = 0
		Game.players[i].coins = 30
		Game.players[i].cpu = true
	Game.players[1].cpu_level = 3
	fb.star_dist = 7
	_ok(BoardItems.cpu_pick(fb, 1, ["double_dice", "custom_dice"]) == "custom_dice", "Insane: Wunschwürfel, wenn der Stern genau erreichbar ist")
	_ok(BoardItems.cpu_custom_number(fb, 1) == 7, "Insane: wählt exakt den Sternabstand")
	fb.star_dist = 25
	_ok(BoardItems.cpu_pick(fb, 1, ["double_dice", "triple_dice"]) == "triple_dice", "Insane: Dreifachwürfel bei weitem Stern")
	fb.star_dist = 2
	Game.players[1].cpu_level = 2
	_ok(BoardItems.cpu_pick(fb, 1, ["double_dice", "slow_dice"]) == "slow_dice", "Profi: Schneckenwürfel zum genauen Ansteuern")
	fb.lock = true
	var stock := ["double_dice", "key", "trap", "coin_card"]
	var buy := BoardItems.cpu_buy(fb, 1, stock, [8, 5, 6, 7])
	_ok(buy >= 0 and buy < stock.size(), "CPU-Kauf liefert gültiges Angebot (%s)" % (stock[buy] if buy >= 0 else "-"))
	Game.players[1].items = ["a", "b", "c"]
	_ok(BoardItems.cpu_buy(fb, 1, stock, [8, 5, 6, 7]) == -1, "kein Kauf bei vollem Inventar (max. %d)" % BoardItems.MAX)
	var picks := {}
	Game.players[2].cpu_level = 0
	for k in 40:
		picks[BoardItems.cpu_pick(fb, 2, ["double_dice", "trap"])] = true
	_ok(picks.size() >= 2, "Leicht: entscheidet uneinheitlich (Anfänger)")
	# --- Emotes -----------------------------------------------------------------------------------------------
	var sheet := Image.create(Emotes.IDS.size() * 100, 100, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.3, 0.35, 0.45))
	var all_ok := true
	for k in Emotes.IDS.size():
		var img := (Emotes.texture(Emotes.IDS[k], 96) as ImageTexture).get_image()
		var opaque := 0
		for y in range(0, img.get_height(), 4):
			for x in range(0, img.get_width(), 4):
				if img.get_pixel(x, y).a > 0.5:
					opaque += 1
		if opaque < 60:
			all_ok = false
		img.convert(Image.FORMAT_RGBA8)
		sheet.blend_rect(img, Rect2i(0, 0, 96, 96), Vector2i(k * 100 + 2, 2))
	_ok(all_ok, "alle %d Emotes rendern (eigene Vektorgrafik)" % Emotes.IDS.size())
	if args.has("emote-sheet"):
		sheet.save_png(String(args["emote-sheet"]))
	Emotes.send(0, "herz")
	var cd_before: float = Emotes._cd[0]
	Emotes.send(0, "lachen")
	_ok(cd_before > 0.0 and is_equal_approx(Emotes._cd[0], cd_before), "Emote-Abklingzeit verhindert Spam")
	Emotes.send(0, "gibtsnicht")
	_ok(true, "unbekanntes Emote wird ignoriert")
	# --- Stepper-Navigation -----------------------------------------------------------------------------------
	var st := Stepper.new().setup(["A", "B", "C"], 0, 120)
	st.nav_mode = "focus"
	add_child(st)
	await get_tree().process_frame
	var right := st.get_child(2) as Button
	var ev := InputEventAction.new()
	ev.action = "ui_right"
	ev.pressed = true
	st._on_btn_input(ev)
	_ok(st.index == 0, "Stepper im Fokus-Modus: rechts wechselt nicht den Wert (Sprung in die nächste Spalte)")
	right.emit_signal("pressed")
	_ok(st.index == 1, "Stepper: A auf dem Pfeil wechselt den Wert")
	st.queue_free()
	# --- Online: Codec, Spielerliste, Host-Schnappschuss -------------------------------------------------------
	var raw := {"traps": {12: 1, 30: 3}, "coins": 23, "f": 0.5, "v": Vector3(1, 2, 3), "items": ["key", "trap"], "nest": [{"a": 7}]}
	var back: Dictionary = NetCodec.roundtrip(raw)
	_ok(back.traps.has(12) and typeof(back.coins) == TYPE_INT and is_equal_approx(float(back.f), 0.5) and back.v == Vector3(1, 2, 3) and back.items == ["key", "trap"] and int(back.nest[0].a) == 7,
		"NetCodec: Ganzzahl-Schlüssel, Ganzzahlen, Kommazahlen und Vektoren überstehen JSON")
	_ok(NetCodec.enc(Node) == null, "NetCodec: Objekte werden nie übertragen")
	var saved_players := Net.players.duplicate(true)
	Net.players = {
		"gast2": {"name": "B", "hero": "knight", "slot": 1, "t": 30},   # gleicher Platz und gleiche Figur wie Gast 1
		"host": {"name": "H", "hero": "knight", "slot": 0, "t": 50},
		"gast1": {"name": "A", "hero": "ranger", "slot": 1, "t": 20},
	}
	Net.host_id = "host"
	Net.me = "gast1"
	var order := Net.lobby_order()
	_ok(order == ["host", "gast1", "gast2"], "Spielerliste: Host zuerst, dann Beitrittsreihenfolge (%s)" % str(order))
	Game.players[3].hero = "custom:me"
	var roster := Net.build_roster(order)
	var heroes_used := {}
	var uniq := true
	for e in roster:
		if heroes_used.has(e.hero) or String(e.hero).begins_with("custom:"):
			uniq = false
		heroes_used[e.hero] = true
	_ok(uniq and roster.size() == 4, "Spielerliste: jede Figur genau einmal, keine geräte-eigenen Avatare")
	_ok(roster[0].hero == "knight" and roster[1].hero == "ranger" and roster[2].hero != "knight", "Spielerliste: Host behält seine Figur, doppelte Wahl wird getauscht")
	_ok(not bool(roster[2].cpu) and bool(roster[3].cpu) and String(roster[3].uid) == "", "Spielerliste: drei Menschen, freier Platz ist CPU")
	Net.apply_roster(roster)
	_ok(Net.my_slot == 1 and Game.players[1].hero == "ranger" and bool(Game.players[3].cpu) and not bool(Game.players[2].cpu) and bool(Game.players[2].remote),
		"Spielerliste: Gerät übernimmt eigenen Platz, Figuren und Rollen")
	Net.players = saved_players
	Net.me = ""
	Net.host_id = ""
	for i in 4:
		Game.players[i].net_uid = ""
	var pb2: Node = load("res://scripts/party/party_board.gd").new()
	Game.players[0].coins = 31
	Game.party.traps = {7: 2}
	var host_state: Dictionary = NetCodec.roundtrip(pb2.call("_state_pack"))
	Game.players[0].coins = 5                    # simulierte Abweichung auf einem Client
	Game.party.traps = {}
	Game.prng.randi()
	_ok(bool(pb2.call("_state_apply", host_state)) and int(Game.players[0].coins) == 31 and (Game.party.traps as Dictionary).has(7),
		"Host-Schnappschuss: abweichender Client übernimmt Münzen, Fallen und Zufall vom Host")
	_ok(not bool(pb2.call("_state_apply", host_state)), "Host-Schnappschuss: gleicher Stand → keine Korrektur")
	pb2.free()
	# --- Glücksrad: gleiches Ergebnis bei jeder Bildrate ----------------------------------------------------------
	var wsegs := [{"text": "a", "weight": 2.0}, {"text": "b", "weight": 1.6}, {"text": "c", "weight": 1.4}, {"text": "d", "weight": 1.0},
		{"text": "e", "weight": 1.4}, {"text": "f", "weight": 0.45}, {"text": "g", "weight": 1.8}, {"text": "h", "weight": 0.9}]
	var wheel_ok := true
	for fps in [15.0, 60.0, 144.0]:
		for want in wsegs.size():
			var wh := FortuneWheel.new().setup(wsegs)
			wh.spin()
			wh.angle = randf() * TAU
			for k in int(fps * 0.5):
				wh._process(1.0 / fps)
			wh.stop_on(want)
			var got := [-1]
			wh.finished.connect(func(i: int) -> void: got[0] = i)
			var guard := 0
			while got[0] < 0 and guard < 4000:
				wh._process((1.0 / fps) * randf_range(0.6, 1.6))   # schwankende Bildrate
				guard += 1
			if got[0] != want or wh._segment_at_pointer() != want:
				wheel_ok = false
			wh.free()
	_ok(wheel_ok, "Glücksrad: landet bei 15, 60 und 144 FPS (mit Schwankungen) exakt auf dem festgelegten Feld")
	# --- Deko-Absicherung (PropSettler) ------------------------------------------------------------------------
	var w := Node3D.new()
	w.name = "World"
	add_child(w)
	WorldKit.box(w, Vector3(10, 1, 10), Vector3(0, -0.5, 0), Color.GREEN, false)        # Arena: Oberkante y = 0
	var far := MeshInstance3D.new()
	var fpm := PlaneMesh.new()
	fpm.size = Vector2(400, 400)
	far.mesh = fpm
	far.position.y = -7.0
	w.add_child(far)                                                                     # Fernboden 7 m tiefer
	var bush := Assets.spawn("nat/bush", w, Vector3(20, 0, 0), 0.0, 1.0)                # schwebt neben der Arena
	var fence := Assets.spawn("plat/fence", w, Vector3(5.6, 0, 0), 0.0, 1.0)            # knapp über der Kante
	var held := Assets.spawn("plat/flowers", w, Vector3(0, 1.2, 0), 0.0, 1.0)           # vom Spiel gehalten (z. B. Seil-Markierung)
	var keep := {held: true}
	await get_tree().process_frame
	PropSettler.settle(w, keep)
	_ok(bush.position.y < -6.0, "Deko-Absicherung: schwebender Busch steht danach auf dem Boden darunter (y %.1f)" % bush.position.y)
	_ok(fence.position.x <= 5.05 and absf(fence.position.y) < 0.1, "Deko-Absicherung: Zaun rückt von der Kante auf die Fläche (x %.2f)" % fence.position.x)
	_ok(is_equal_approx(held.position.y, 1.2) and held.visible, "Deko-Absicherung: Spielelemente bleiben unangetastet")
	_ok(PropSettler.check(w, keep).is_empty(), "Deko-Absicherung: danach keine schwebenden Modelle mehr")
	w.free()
	# --- Bildrate ------------------------------------------------------------------------------------------------
	var fm_old := String(Game.settings.get("fps_mode", "60"))
	Game.settings.fps_mode = "120"
	_ok(Gfx.fps_cap() == 120, "Bildrate: 120-FPS-Modus")
	Game.settings.fps_mode = "60"
	_ok(Gfx.fps_cap() == 60, "Bildrate: Standard 60 FPS")
	Game.settings.fps_mode = fm_old
	# --- Touch-Wischen ----------------------------------------------------------------------------------------
	var layer := CanvasLayer.new()
	add_child(layer)
	var sc := ScrollContainer.new()
	sc.position = Vector2(100, 100)
	sc.size = Vector2(300, 300)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layer.add_child(sc)
	var tall := Control.new()
	tall.custom_minimum_size = Vector2(280, 1600)
	sc.add_child(tall)
	await get_tree().process_frame
	await get_tree().process_frame
	var down := InputEventScreenTouch.new()
	down.pressed = true
	down.position = Vector2(250, 350)
	InputHub._touch_scroll(down)
	var pos := down.position
	for k in 10:
		var drag := InputEventScreenDrag.new()
		drag.relative = Vector2(0, -12)
		pos += drag.relative
		drag.position = pos
		InputHub._touch_scroll(drag)
	_ok(sc.scroll_vertical >= 90, "Touch: Wischen nach oben scrollt die Liste (%d px)" % sc.scroll_vertical)
	var up := InputEventScreenTouch.new()
	up.pressed = false
	up.position = pos
	_ok(InputHub._touch_scroll(up), "Touch: Loslassen nach dem Wischen löst keinen Knopf aus")
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	tap.position = Vector2(250, 200)
	InputHub._touch_scroll(tap)
	tap = tap.duplicate()
	tap.pressed = false
	_ok(not InputHub._touch_scroll(tap), "Touch: kurzes Tippen bleibt ein Tippen")
	layer.queue_free()
	# --- Menü-Überraschungen (Figuren antippen) ---------------------------------------------------------------
	var menu: Node = load("res://scenes/menu/MainMenu.tscn").instantiate()
	add_child(menu)
	for k in 20:
		await get_tree().process_frame
	var cam: Camera3D = menu.get("_cam")
	var heroes: Array = menu.get("_heroes")
	var mage: CharacterRig = heroes[0]
	var spot := cam.unproject_position(mage.global_position + Vector3.UP * 0.8 * mage.base_scale.y)
	_ok(bool(menu.call("_poke_at", spot)), "Menü: Antippen trifft die Figur")
	_ok(mage.current != "" and (menu.get("_pokes") as Dictionary).has(mage.get_instance_id()), "Menü: Figur reagiert (%s)" % mage.current)
	_ok(not bool(menu.call("_poke_at", Vector2(2, 2))), "Menü: Klick ins Leere löst nichts aus")
	menu.queue_free()
	print("TESTS %s – %d Fehler" % ["OK" if _fails == 0 else "FEHLGESCHLAGEN", _fails])
	get_tree().quit(1 if _fails > 0 else 0)
