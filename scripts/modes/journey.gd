extends Node3D
## Partyhelfer-Reise: Einzelspieler-Abenteuer auf der Pusteblumen-Insel. Pustebacke hat das große
## Inselfest weggepustet! Du läufst frei über die Insel, hilfst den Bewohnern mit Minispiel-Aufträgen
## (gegen CPU-Gegner) und sammelst Mini-Sterne – für jeden Auftrag drei, dazu zehn versteckte auf der
## Insel. Mit genug Mini-Sternen öffnet sich das Wolkentor: oben wartet Pustebacke zum Bosskampf.
## Fortschritt wird gespeichert (user://journey.cfg).

const SAVE_PATH := "user://journey.cfg"
const GATE_STARS := 24
const QUESTS := [
	{"id": "hoppel", "npc": "pet/bunny", "name": "Hoppel", "pos": Vector3(-9, 0, 9), "game": "plush_balls", "setup": {"cat": "ffa"}, "goal": "win",
		"talk": "Meine Kuschelbälle hüpfen wild herum! Bleib als Letzte·r auf dem Kissen-Feld stehen, dann bekommst du Mini-Sterne!"},
	{"id": "piepsi", "npc": "pet/chick", "name": "Piepsi", "pos": Vector3(8, 0, 10), "game": "sleepy_stars", "setup": {"cat": "ffa"}, "goal": "win",
		"talk": "Piep! Kannst du dir die Melodie meiner Schlummer-Freunde merken? Bleib am längsten wach!"},
	{"id": "mauzi", "npc": "pet/cat", "name": "Mauzi", "pos": Vector3(-18, 0, -2), "game": "pumpkin_toss", "setup": {"cat": "ffa"}, "goal": "win",
		"talk": "Miau, die Kürbisernte ist da! Wirf weiter als alle anderen – dann gehört dir die Ernte-Belohnung."},
	{"id": "hirschi", "npc": "pet/deer", "name": "Hirschi", "pos": Vector3(-14, 0, -15), "game": "flower_rush", "setup": {"cat": "ffa"}, "goal": "win",
		"talk": "Die Blumenwiese ist ganz blass geworden. Färbe die meisten Blumen in deiner Farbe!"},
	{"id": "muhla", "npc": "pet/cow", "name": "Bürgermeisterin Muhla", "pos": Vector3(0, 0, 2), "game": "tug_of_war", "setup": {"cat": "1v3", "solo": 0}, "goal": "win",
		"talk": "Muuuh! Beweise deine Stärke: Gewinne das Seilziehen am Pilzbach – ganz allein gegen drei!"},
	{"id": "summsi", "npc": "pet/bee", "name": "Summsi", "pos": Vector3(17, 0, -6), "game": "honey_chase", "setup": {"cat": "1v3", "solo": 1}, "goal": "win",
		"talk": "Bssss! Der Honigbär will unseren Honig! Hilf deinem Team, ihm zu entkommen!"},
	{"id": "kraxi", "npc": "pet/crab", "name": "Kraxi", "pos": Vector3(6, 0, 22), "game": "chest_sniff", "setup": {"cat": "ffa"}, "goal": "score", "target": 18,
		"talk": "Am Strand liegen Schatzkisten! Schnüffle mindestens 18 Münzen heraus – aber Vorsicht vor dem Kistengeist!"},
	{"id": "quaki", "npc": "npc/duck", "name": "Quaki", "pos": Vector3(-6, 0, 21), "game": "star_hoops", "setup": {"cat": "2v2", "teams": [0, 0, 1, 1]}, "goal": "win",
		"talk": "Quak! Spiel mit mir Sternen-Korbschlacht! Zusammen schlagen wir die beiden da drüben."},
	{"id": "brummbaer", "npc": "npc/bear", "name": "Chefkoch Brummbär", "pos": Vector3(14, 0, 6), "game": "rhythm_kitchen", "setup": {"cat": "coop"}, "goal": "grade",
		"talk": "Für das Fest fehlt noch das Menü! Koch mit meinen Helfern im Takt und hol mindestens eine A-Note!"},
	{"id": "wuff", "npc": "npc/dog", "name": "Wuff", "pos": Vector3(19, 0, 15), "game": "lucky_bells", "setup": {"cat": "ffa"}, "goal": "win",
		"talk": "Wuff! In meinen Glöckchen stecken Münzen. Hab das meiste Glück und gewinne!"},
]
const HIDDEN := [Vector3(-24, 1.4, 6), Vector3(-20, 1.4, -20), Vector3(2, 1.4, -24), Vector3(24, 1.4, -14), Vector3(26, 1.4, 6),
	Vector3(12, 1.4, 26), Vector3(-14, 1.4, 25), Vector3(-27, 1.4, -8), Vector3(-20, 4.4, 13), Vector3(18, 1.4, -22)]

var save := ConfigFile.new()
var player: PartyAvatar
var cam: Camera3D
var _npcs: Array[CharacterRig] = []
var _marks: Array[Label3D] = []
var _stars: Array[Node3D] = []
var _gate: Node3D
var _gate_open := false
var _hud_stars: Label
var _prompt: Label
var _area: Label
var _busy := false
var _near := -1
var _cam_yaw := 0.0


func _ready() -> void:
	save.load(SAVE_PATH)
	WorldKit.env(self, "day")
	WorldKit.backdrop(self, "beach", Color("#e8d6a0"), -0.56)
	_build_island()
	for i in range(1, 4):
		Game.players[i].cpu = true
		Game.players[i].cpu_level = clampi(_done_count() / 4, 0, 2)
	Game.players[0].cpu = false
	player = PartyAvatar.new().setup(0, Vector3(0, 1.0, 12), 0.85)
	add_child(player)
	player.can_shove = false
	player.kill_y = -6.0
	var lp: Variant = save.get_value("state", "pos", null)
	if lp is Vector3:
		player.position = lp
	cam = Camera3D.new()
	add_child(cam)
	cam.fov = 55.0
	cam.make_current()
	cam.position = player.position + Vector3(0, 9, 11)
	cam.look_at(player.position + Vector3.UP)
	_build_hud()
	Audio.music("board_meadow", 1.2)
	InputHub.set_touch_profile("explore")
	_refresh()
	var fresh := String(save.get_value("state", "pending", "")) == ""
	_after_return()
	if "--journey-test" in OS.get_cmdline_user_args() and fresh and not _done("hoppel"):
		await get_tree().create_timer(2.0).timeout
		_busy = false
		_start_quest(0)
		Game.players[0].cpu = true


# --- Speicherstand ------------------------------------------------------------------------------------------

func _done(id: String) -> bool:
	return bool(save.get_value("quests", id, false))


func _done_count() -> int:
	var n := 0
	for q in QUESTS:
		if _done(String(q.id)):
			n += 1
	return n


func _ministars() -> int:
	var n := _done_count() * 3
	for i in HIDDEN.size():
		if bool(save.get_value("hidden", str(i), false)):
			n += 1
	return n


func _write() -> void:
	save.set_value("state", "pos", player.position if player else Vector3(0, 1, 12))
	save.save(SAVE_PATH)
	Game.records_note("journey_ministars", _ministars())


# --- Insel --------------------------------------------------------------------------------------------------

func _build_island() -> void:
	WorldKit.water(self, Vector2(260, 260), -0.6, Color(0.08, 0.42, 0.66), Color(0.3, 0.8, 0.9))
	WorldKit.cylinder(self, 34.0, 2.0, Vector3(0, -1.0, 0), Color("#f2dca0"))
	WorldKit.cylinder(self, 30.0, 2.04, Vector3(0, -0.98, 0), Color("#7cc860"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	for i in 30:
		var d := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var r := rng.randf_range(2.5, 5.5)
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = 0.04
		cm.material = WorldKit.mat([Color("#8fd16a"), Color("#6fb85e"), Color("#a6dc7a")][i % 3], 1.0)
		d.mesh = cm
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(d)
		var a := rng.randf() * TAU
		var rr := rng.randf_range(0, 26)
		d.position = Vector3(cos(a) * rr, 0.045 + i * 0.0005, sin(a) * rr)
	# Dorf in der Mitte
	WorldKit.place(self, "town/fountain", Vector3(0, 0, -2), 0.0, 2.4, true)
	var roofs := [Color("#ff8a8a"), Color("#7fb8ff"), Color("#ffb347"), Color("#b99bff")]
	var hk := 0
	for p in [Vector3(-8, 0, -6), Vector3(8, 0, -7), Vector3(-5, 0, -12), Vector3(6, 0, -13)]:
		WorldKit.cottage(self, p, rad_to_deg(atan2(-p.x, -p.z)) + 180.0, 1.5, Color("#fff1d8"), roofs[hk % 4], true)
		hk += 1
	for p in [Vector3(-3, 0, 5), Vector3(3, 0, 5), Vector3(-10, 0, 0), Vector3(10, 0, 0)]:
		WorldKit.place(self, "town/lantern", p, 0.0, 1.8)
	WorldKit.place(self, "town/stall", Vector3(12, 0, 3), -60.0, 2.4, true)
	WorldKit.place(self, "town/windmill", Vector3(22, 0, -2), -90.0, 3.2, true)
	# Wald im Westen, Strand im Süden
	for i in 26:
		var p := Vector3(rng.randf_range(-30, -12), 0, rng.randf_range(-24, 10))
		if p.length() < 29.0 and p.distance_to(Vector3(-18, 0, -2)) > 4.0 and p.distance_to(Vector3(-14, 0, -15)) > 4.0:
			WorldKit.place(self, ["nat/tree_oak", "nat/tree_fat", "plat/tree", "nat/tree_pine"][i % 4], p, rng.randf() * 360.0, rng.randf_range(2.6, 3.6), true)
	for i in 10:
		var a := PI * 0.25 + PI * 0.5 * float(i) / 9.0
		WorldKit.place(self, ["pirate/palm", "pirate/palm_bend"][i % 2], Vector3(cos(a), 0, sin(a)) * 31.0, rng.randf() * 360.0, 2.6)
	for i in 50:
		var a2 := rng.randf() * TAU
		var r2 := rng.randf_range(4, 28)
		var p2 := Vector3(cos(a2) * r2, 0, sin(a2) * r2)
		var free := true
		for q in QUESTS:
			if p2.distance_to(q.pos) < 3.0:
				free = false
		if free:
			WorldKit.place(self, ["plat/flowers", "nat/flower_yellow", "nat/flower_purple", "nat/bush", "plat/mushrooms"][i % 5], p2, rng.randf() * 360.0, rng.randf_range(1.2, 1.8))
	# Kleiner Hügel mit verstecktem Stern (Sprung-Herausforderung)
	WorldKit.box(self, Vector3(3.4, 1.2, 3.4), Vector3(-20, 0.6, 13), Color("#b9a27a"))
	WorldKit.box(self, Vector3(2.2, 1.2, 2.2), Vector3(-20, 1.8, 13), Color("#c9b28a"))
	WorldKit.box(self, Vector3(1.4, 1.2, 1.4), Vector3(-20, 3.0, 13), Color("#d9c29a"))
	# Wolkentor im Norden
	_gate = Node3D.new()
	add_child(_gate)
	_gate.position = Vector3(0, 0, -26)
	for sx in [-3.0, 3.0]:
		WorldKit.cylinder(_gate, 0.6, 6.0, Vector3(sx, 3.0, 0), Color("#f2ead8"), true)
	var bar := WorldKit.box(_gate, Vector3(7.4, 1.0, 1.0), Vector3(0, 6.2, 0), Color("#8fb0ff"), false)
	bar.name = "Bar"
	var gl := Label3D.new()
	gl.text = "Wolkentor"
	gl.font = UI.title_font()
	gl.font_size = 72
	gl.outline_size = 14
	gl.pixel_size = 0.01
	gl.position = Vector3(0, 7.4, 0)
	_gate.add_child(gl)
	var door := WorldKit.box(_gate, Vector3(5.4, 5.4, 0.4), Vector3(0, 2.7, 0), Color("#c9b5ff"), true)
	door.name = "Door"
	for k in 6:
		var puff := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.6
		sm.height = 2.6
		sm.material = WorldKit.mat(Color.WHITE, 1.0, 0.15)
		puff.mesh = sm
		puff.position = Vector3(-5 + k * 2.0, 9.0 + sin(k) * 0.6, -1.5)
		_gate.add_child(puff)
	# Bewohner
	for qi in QUESTS.size():
		var q: Dictionary = QUESTS[qi]
		var r := CharacterRig.new()
		add_child(r)
		r.setup(String(q.npc), -1, 0.95 if String(q.npc).begins_with("pet/") else 1.15)
		r.position = q.pos
		r.face_now(Vector3(0, 0, 12) - r.position)
		r.play("idle")
		_npcs.append(r)
		var m := Label3D.new()
		m.font = UI.title_font()
		m.font_size = 120
		m.outline_size = 22
		m.outline_modulate = Color(0.25, 0.1, 0.0)
		m.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		m.pixel_size = 0.01
		m.position = q.pos + Vector3(0, 3.0, 0)
		add_child(m)
		_marks.append(m)
		var tw := m.create_tween().set_loops()
		tw.tween_property(m, "position:y", 3.3, 0.6).set_trans(Tween.TRANS_SINE)
		tw.tween_property(m, "position:y", 3.0, 0.6).set_trans(Tween.TRANS_SINE)
	# Versteckte Mini-Sterne
	for i in HIDDEN.size():
		var s := Node3D.new()
		add_child(s)
		s.position = HIDDEN[i]
		var st := Assets.spawn("plat/star", s, Vector3.ZERO, 0.0, 1.1)
		Assets.tint(st, Color(1, 0.95, 0.6), false, 0.6)
		var spin := s.create_tween().set_loops()
		spin.tween_property(s, "rotation:y", TAU, 2.4).from(0.0)
		_stars.append(s)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := UI.center_root(layer)
	var box := UI.panel()
	root.add_child(box)
	var h := UI.hbox(10)
	box.add_child(h)
	h.add_child(UIIcon.new("star", 36))
	_hud_stars = UI.label("0", 34, UI.GOLD, true, 8)
	h.add_child(_hud_stars)
	UI.place(box, Control.PRESET_TOP_LEFT, Vector2(20, 18), Vector2(0, 0))
	_area = UI.label("Pusteblumen-Insel", 28, Color.WHITE, true, 8)
	_area.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_area)
	UI.place(_area, Control.PRESET_TOP_RIGHT, Vector2(-520, 22), Vector2(500, 40))
	_prompt = UI.label("", 28, Color.WHITE, true, 8)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_prompt)
	UI.place(_prompt, Control.PRESET_CENTER_BOTTOM, Vector2(-400, -90), Vector2(800, 44))
	var help := UI.label("Stick: Laufen · A: Springen · B: Sprechen · X: Aufträge · Start: Menü", 18, Color(1, 1, 1, 0.6), true, 6)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(help)
	UI.place(help, Control.PRESET_CENTER_BOTTOM, Vector2(-500, -36), Vector2(1000, 28))


func _refresh() -> void:
	_hud_stars.text = "%d / %d" % [_ministars(), QUESTS.size() * 3 + HIDDEN.size()]
	for qi in QUESTS.size():
		var done := _done(String(QUESTS[qi].id))
		_marks[qi].text = "" if done else "!"
		_marks[qi].modulate = Color("#ff5c7a")
		var crown := _marks[qi].get_node_or_null("Done") as Node3D
		if done and crown == null:
			crown = Assets.spawn("plat/star", _marks[qi], Vector3.ZERO, 0.0, 0.7)
			crown.name = "Done"
			Assets.tint(crown, Color(1, 0.95, 0.6), false, 0.5)
	for i in HIDDEN.size():
		_stars[i].visible = not bool(save.get_value("hidden", str(i), false))
	_gate_open = _ministars() >= GATE_STARS
	var door := _gate.get_node("Door") as Node3D
	door.visible = not _gate_open
	for c in door.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = _gate_open
	if door is StaticBody3D:
		(door as StaticBody3D).collision_layer = 0 if _gate_open else 1


# --- Spielschleife ------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if player == null:
		return
	var target := player.position + Vector3(0, 8.5, 10.5)
	cam.position = cam.position.lerp(target, clampf(delta * 4.0, 0.0, 1.0))
	cam.look_at(player.position + Vector3.UP * 1.2, Vector3.UP)
	if _busy:
		return
	if player.position.y < -4.0:
		player.respawn(Vector3(0, 1.0, 12))
		Audio.sfx("splash")
	# Bereich
	var p := player.position
	var area := "Dorfplatz"
	if p.z < -20:
		area = "Wolkentor"
	elif p.x < -12:
		area = "Flüsterwald"
	elif p.z > 17:
		area = "Sonnenstrand"
	elif p.x > 15:
		area = "Mühlenhügel"
	if _area.text != area:
		_area.text = area
		Juice.ui_punch(_area, 0.15, 0.3)
	# Nächster Bewohner
	_near = -1
	var best := 2.8
	for qi in QUESTS.size():
		var d := p.distance_to(QUESTS[qi].pos)
		if d < best:
			best = d
			_near = qi
	var at_gate := _gate_open and p.distance_to(_gate.position) < 4.5
	if _near >= 0:
		_prompt.text = "B: Mit %s sprechen" % String(QUESTS[_near].name)
	elif at_gate:
		_prompt.text = "B: Durch das Wolkentor zu Pustebacke!"
	elif p.distance_to(_gate.position) < 5.0 and not _gate_open:
		_prompt.text = "Das Wolkentor öffnet sich ab %d Mini-Sternen (%d/%d)" % [GATE_STARS, _ministars(), GATE_STARS]
	else:
		_prompt.text = ""
	if InputHub.pressed(0, "b"):
		if _near >= 0:
			_talk(_near)
		elif at_gate:
			_boss()
	elif InputHub.pressed(0, "x"):
		_quest_log()
	# Versteckte Sterne einsammeln
	for i in HIDDEN.size():
		if _stars[i].visible and p.distance_to(_stars[i].position) < 1.4:
			save.set_value("hidden", str(i), true)
			_stars[i].visible = false
			FX.stars(_stars[i].position, UI.GOLD, 20)
			Audio.sfx("star")
			Juice.float_text(self, _stars[i].position + Vector3.UP, "Mini-Stern!", UI.GOLD, 70)
			_write()
			_refresh()
			Juice.ui_punch(_hud_stars, 0.4, 0.4)


func _freeze(on: bool) -> void:
	_busy = on
	player.can_move = not on
	player.can_jump = not on


func _dialog(speaker: String, text: String, options: Array[String]) -> int:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var root := UI.center_root(layer)
	var panel := UI.panel()
	root.add_child(panel)
	var v := UI.vbox(10)
	panel.add_child(v)
	v.add_child(UI.label(speaker, 30, UI.GOLD, true, 8))
	var t := UI.label("", 26, Color.WHITE, true, 6)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(860, 80)
	v.add_child(t)
	var h := UI.hbox(16)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	var answer := [-1]
	var btns: Array[Button] = []
	for k in options.size():
		var b := UI.button(options[k], Color("#2ecc71") if k == 0 else Color("#5a4a80"), 26, 260)
		var kk := k
		b.pressed.connect(func() -> void: answer[0] = kk)
		h.add_child(b)
		btns.append(b)
	await get_tree().process_frame
	UI.place(panel, Control.PRESET_CENTER_BOTTOM, Vector2(-460, -panel.size.y - 40), Vector2(920, 0))
	Juice.pop_in(panel, 0.3)
	# Schreibmaschinen-Text
	for n in text.length() + 1:
		t.text = text.substr(0, n)
		if n % 3 == 0:
			Audio.sfx("tick", null, -16.0, 1.6)
		await get_tree().create_timer(0.012).timeout
		if InputHub.pressed(0, "a") and n > 4:
			t.text = text
			break
	if not btns.is_empty():
		btns[0].grab_focus()
	var w := 0.0
	while answer[0] < 0:
		await get_tree().process_frame
		w += get_process_delta_time()
		if w > 0.3 and InputHub.pressed(0, "b"):
			answer[0] = options.size() - 1
	Audio.sfx("ui_confirm")
	layer.queue_free()
	return answer[0]


func _talk(qi: int) -> void:
	_freeze(true)
	var q: Dictionary = QUESTS[qi]
	var npc := _npcs[qi]
	npc.face_now(player.position - npc.position)
	npc.react("wave")
	Audio.sfx("pop")
	var done := _done(String(q.id))
	var text := String(q.talk)
	if done:
		text = "Danke nochmal für deine Hilfe! Willst du zum Spaß noch eine Runde spielen?"
	var info := Game.minigame_info(String(q.game))
	var ans: int = await _dialog(String(q.name), text + "\n(Minispiel: %s)" % String(info.get("name", "")), ["Los geht's!", "Später"])
	if ans == 0:
		_start_quest(qi)
		return
	_freeze(false)


func _start_quest(qi: int) -> void:
	var q: Dictionary = QUESTS[qi]
	_write()
	save.set_value("state", "pending", String(q.id))
	save.save(SAVE_PATH)
	var heroes: Array = Game.HEROES.map(func(h: Dictionary) -> String: return h.id)
	var k := 0
	for i in range(1, 4):
		while String(heroes[k % heroes.size()]) == String(Game.players[0].hero):
			k += 1
		Game.players[i].hero = String(heroes[k % heroes.size()])
		k += 1
	Game.minigame_setup = (q.setup as Dictionary).duplicate(true)
	Game.mode = "journey"
	Audio.sfx("minigame_start")
	Router.goto(Game.minigame_info(String(q.game)).scene)


## Nach einem Auftrags-Minispiel: Ergebnis prüfen und belohnen.
func _after_return() -> void:
	var pending := String(save.get_value("state", "pending", ""))
	if pending == "" or Game.last_results.is_empty():
		if not bool(save.get_value("state", "intro", false)):
			await _intro()
		return
	save.set_value("state", "pending", "")
	var res: Dictionary = Game.last_results
	Game.last_results = {}
	if pending == "boss":
		await _boss_result(res)
		return
	var qi := -1
	for k in QUESTS.size():
		if String(QUESTS[k].id) == pending:
			qi = k
	if qi < 0:
		return
	var q: Dictionary = QUESTS[qi]
	var place := int((res.get("placements", [0, 0, 0, 0]) as Array)[0])
	var ok := false
	match String(q.goal):
		"win":
			ok = place == 1
		"score":
			ok = float((res.get("scores", [0, 0, 0, 0]) as Array)[0]) >= float(q.get("target", 10))
		"grade":
			ok = String(res.get("grade", "C")) in ["S", "A"]
	_freeze(true)
	player.position = (q.pos as Vector3) + Vector3(0, 0.5, 2.4)
	cam.position = player.position + Vector3(0, 8.5, 10.5)
	await get_tree().create_timer(0.6).timeout
	var npc := _npcs[qi]
	if ok and not _done(String(q.id)):
		save.set_value("quests", String(q.id), true)
		_write()
		npc.react("cheer")
		player.rig.react("star_get")
		for s in 3:
			FX.stars(player.position + Vector3.UP * 2.0, UI.GOLD, 14)
			Audio.sfx("star", null, -4.0, 1.0 + s * 0.12)
			await get_tree().create_timer(0.35).timeout
		_refresh()
		Juice.ui_punch(_hud_stars, 0.5, 0.5)
		await _dialog(String(q.name), "Hurra, du hast es geschafft! Hier sind drei Mini-Sterne für dich. Das Fest kann bald steigen!", ["Gern geschehen!"])
		if _ministars() >= GATE_STARS and not bool(save.get_value("state", "gate_told", false)):
			save.set_value("state", "gate_told", true)
			_write()
			await _gate_cutscene()
	elif ok:
		npc.react("cheer")
		await _dialog(String(q.name), "Super gespielt! Du bist wirklich ein Partyprofi.", ["Danke!"])
	else:
		npc.react("sad")
		await _dialog(String(q.name), "Oh, knapp daneben! Versuch es einfach nochmal – ich glaub an dich!", ["Okay!"])
	_freeze(false)


func _intro() -> void:
	_freeze(true)
	save.set_value("state", "intro", true)
	_write()
	cam.position = Vector3(0, 30, 40)
	var tw := create_tween()
	tw.tween_property(cam, "position", player.position + Vector3(0, 8.5, 10.5), 3.0).set_trans(Tween.TRANS_SINE)
	Audio.jingle("round", false)
	await get_tree().create_timer(3.2).timeout
	var muhla := _npcs[4]
	muhla.react("wave")
	await _dialog("Bürgermeisterin Muhla", "Willkommen auf der Pusteblumen-Insel! Oh je – Pustebacke hat unser großes Fest weggepustet! Hilf den Inselbewohnern bei ihren Aufgaben und sammle Mini-Sterne.", ["Weiter"])
	await _dialog("Bürgermeisterin Muhla", "Wer ein Ausrufezeichen hat, braucht deine Hilfe. Mit %d Mini-Sternen öffnet sich das Wolkentor im Norden – dort wartet Pustebacke! Ein paar Sterne sind auch irgendwo versteckt …" % GATE_STARS, ["Los geht's!"])
	_freeze(false)


func _gate_cutscene() -> void:
	var old := cam.position
	_busy = true
	var tw := create_tween()
	tw.tween_property(cam, "position", _gate.position + Vector3(0, 6, 14), 1.4).set_trans(Tween.TRANS_SINE)
	await tw.finished
	cam.look_at(_gate.position + Vector3.UP * 4.0)
	Audio.sfx("door")
	Audio.jingle("star")
	FX.confetti(_gate.position + Vector3.UP * 5.0, 60)
	await get_tree().create_timer(1.6).timeout
	cam.position = old
	_busy = false


func _quest_log() -> void:
	_freeze(true)
	var lines: Array[String] = []
	for q in QUESTS:
		lines.append("%s – %s%s" % [String(q.name), String(Game.minigame_info(String(q.game)).get("name", "")), "  (erledigt)" if _done(String(q.id)) else ""])
	var hid := 0
	for i in HIDDEN.size():
		if bool(save.get_value("hidden", str(i), false)):
			hid += 1
	lines.append("Versteckte Mini-Sterne: %d / %d" % [hid, HIDDEN.size()])
	await _dialog("Aufträge (%d / %d erledigt)" % [_done_count(), QUESTS.size()], "\n".join(lines), ["Schließen"])
	_freeze(false)


# --- Bosskampf ----------------------------------------------------------------------------------------------

func _boss() -> void:
	_freeze(true)
	var ans: int = await _dialog("Wolkentor", "Oben auf den Wolken tobt Pustebacke, der Wolkendrache. Gemeinsam mit drei Inselfreunden wirfst du Sonnenbälle, bis er aufgibt. Bereit?", ["Auf zum Kampf!", "Noch nicht"])
	if ans != 0:
		_freeze(false)
		return
	_write()
	save.set_value("state", "pending", "boss")
	save.save(SAVE_PATH)
	for i in range(1, 4):
		Game.players[i].cpu_level = 1
	Game.minigame_setup = {"cat": "boss"}
	Game.mode = "journey"
	Router.goto(Game.minigame_info("boss_cloud").scene)


func _boss_result(res: Dictionary) -> void:
	_freeze(true)
	player.position = _gate.position + Vector3(0, 0.5, 5)
	if bool(res.get("boss_defeated", false)):
		var first := not bool(save.get_value("state", "boss_done", false))
		save.set_value("state", "boss_done", true)
		_write()
		Audio.jingle("win")
		for r in _npcs:
			r.react("victory")
		for k in 6:
			FX.confetti(Vector3(randf_range(-12, 12), 6, randf_range(-12, 12)), 50)
			FX.stars(Vector3(randf_range(-12, 12), 4, randf_range(-12, 12)), UI.GOLD, 20)
			Audio.sfx("explosion", null, -14.0, 1.6)
			await get_tree().create_timer(0.4).timeout
		await _dialog("Bürgermeisterin Muhla", "Du hast Pustebacke besiegt! Er entschuldigt sich und pustet jetzt nur noch Seifenblasen. Das Inselfest kann endlich steigen – du bist unser Partyheld!" if first else "Pustebacke wurde erneut besiegt! Die Insel feiert dich.", ["Feiern!"])
		if first:
			await _dialog("Partyhelfer-Reise", "Geschafft! Danke fürs Spielen. Sammle alle %d Mini-Sterne für die volle Sternen-Krone!" % (QUESTS.size() * 3 + HIDDEN.size()), ["Weiter"])
	else:
		await _dialog("Bürgermeisterin Muhla", "Pustebacke war diesmal zu stark … Ruh dich kurz aus und versuch es nochmal!", ["Okay"])
	_freeze(false)


func _exit_tree() -> void:
	if player:
		_write()
