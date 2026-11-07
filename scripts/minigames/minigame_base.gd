class_name MinigameBase
extends Node3D
## Basis aller 10 Minispiele.
##
## Ablauf: Teaser-Cutscene (Kanonen-Einflug) -> Anleitung -> 3-2-1-LOS -> Spiel -> "FERTIG!"
##         -> Sieger-Cutscene -> Ergebnis-Tafel -> zurück zum Brett / zur Auswahl.
## Unterklassen überschreiben build_arena(), optional spawn_players(), cpu_think(), on_tick(),
## check_end() und compute_placements().

const REWARDS := [10, 5, 2, 0]

var game_id := ""
var info: Dictionary = {}
var env_preset := "day"
var time_limit := 40.0
var time_left := 40.0
var state := "setup"
var touch_profile := "minigame"
var survival := false
var race := false
var show_timer := true
var score_format := "%d"
var hazard := "lava"
var kill_y := -6.0
var avatar_scale := 0.85
var respawn_on_fall := false
var teaser_height := 0.75

var cam: ArenaCamera
var avatars: Array = [null, null, null, null]
var actors: Array = [null, null, null, null]
var rigs: Array = [null, null, null, null]
var alive: Array[bool] = [true, true, true, true]
var scores: Array[float] = [0.0, 0.0, 0.0, 0.0]
var out_order: Array[int] = []
var finish_order: Array[int] = []
var spawn_points: Array[Vector3] = []
var arena_center := Vector3.ZERO
var arena_radius := 12.0
var cannon_pos := Vector3(0, 0, 20)
var world: Node3D

var hud: CanvasLayer
var badges: Array[PlayerBadge] = []
var timer_label: Label
var _hud_root: Control
var _hurry_said := false
var _last_tick := -1
var cpu_mem: Array[Dictionary] = [{}, {}, {}, {}]
var forced_placements: Array[int] = []
var net_sync: NetAvatarSync
var _net_ready: Dictionary = {}
var _net_go := false
var _debug_ai := "--debug-ai" in OS.get_cmdline_user_args()


func _ready() -> void:
	info = Game.minigame_info(game_id)
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	var we := WorldKit.env(self, env_preset)
	if WorldKit.PRESETS.get(env_preset, {}).get("rays", false):
		WorldKit.god_rays(self, arena_center, arena_radius * 1.2, we.get_meta("sun"), 6)
	if spawn_points.is_empty():
		for i in 4:
			spawn_points.append(arena_center + Vector3(-4.5 + i * 3.0, 0.5, 0))
	build_arena()
	spawn_players()
	_setup_camera()
	_build_hud()
	InputHub.set_touch_profile("none")
	Audio.music("minigame")
	_flow()


# --- Zu überschreiben ------------------------------------------------------------------

func build_arena() -> void:
	pass


func spawn_players() -> void:
	for i in 4:
		var av := PartyAvatar.new()
		world.add_child(av)
		av.setup(i, spawn_points[i], avatar_scale)
		av.kill_y = kill_y
		av.hazard = hazard
		av.rig.face_now(Vector3(0, 0, 1))
		av.fell.connect(_on_avatar_fell)
		avatars[i] = av
		actors[i] = av
		rigs[i] = av.rig


func on_start() -> void:
	pass


func on_tick(_delta: float) -> void:
	pass


func on_timeout() -> void:
	end_game()


func check_end() -> bool:
	if survival:
		return alive_count() <= 1
	return false


func cpu_think(_slot: int, _delta: float) -> void:
	pass


func on_fell(slot: int, _hazard: String) -> void:
	if respawn_on_fall:
		await get_tree().create_timer(1.2, false).timeout
		if state == "play" and avatars[slot]:
			(avatars[slot] as PartyAvatar).respawn(spawn_points[slot] + Vector3.UP * 2.0)
	else:
		eliminate(slot)


func _on_avatar_fell(av: PartyAvatar, hz: String) -> void:
	on_fell(av.slot, hz)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = arena_center
	c.offset = Vector3(0, arena_radius * 1.05, arena_radius * 0.95)


# --- Ablauf ---------------------------------------------------------------------------------------

func _setup_camera() -> void:
	cam = ArenaCamera.new()
	cam.targets = actors.filter(func(a: Variant) -> bool: return a != null)
	setup_camera(cam)
	add_child(cam)
	cam.make_current()
	cam.snap()


func _freeze_all(on: bool) -> void:
	for a in avatars:
		if a is PartyAvatar:
			(a as PartyAvatar).freeze(on)


func _flow() -> void:
	state = "intro"
	_freeze_all(true)
	await get_tree().process_frame
	await CutsceneManager.play("MinigameTeaser", {"game": self})
	await _instructions()
	if Game.mode == "online" and Net.online:
		net_sync = NetAvatarSync.new().setup(self)
		add_child(net_sync)
		await _net_barrier()
	InputHub.set_touch_profile(touch_profile)
	await CutsceneManager.countdown()
	time_left = time_limit
	state = "play"
	_freeze_all(false)
	on_start()


func _process(delta: float) -> void:
	if state != "play":
		return
	if show_timer:
		time_left = maxf(0.0, time_left - delta)
		var secs := int(ceil(time_left))
		timer_label.text = str(secs)
		if secs <= 10 and not _hurry_said:
			_hurry_said = true
			Audio.voice("hurry_up")
			timer_label.add_theme_color_override("font_color", Color("#ff6b6b"))
		if secs <= 5 and secs != _last_tick:
			_last_tick = secs
			Audio.sfx("tick", null, 0.0, 1.0 + (5 - secs) * 0.08, 0.0)
			Juice.ui_punch(timer_label, 0.3, 0.3)
	on_tick(delta)
	_update_badges()
	if net_sync and not Net.is_host:
		return   # Online: das Ende entscheidet der Host
	if state == "play" and show_timer and time_left <= 0.0:
		on_timeout()
	elif state == "play" and check_end():
		end_game()


func _physics_process(delta: float) -> void:
	if state == "play":
		for i in 4:
			if Game.players[i].cpu and Net.owns_slot(i):
				cpu_think(i, delta)
		if _debug_ai and Engine.get_physics_frames() % 90 == 0:
			for i in 4:
				var a: Node3D = actors[i]
				print("[AI] P%d pos=%s mv=%s score=%s alive=%s" % [i, a.global_position.snapped(Vector3.ONE * 0.1), InputHub.move(i).snapped(Vector2.ONE * 0.01), scores[i], alive[i]])
	elif state != "setup":
		InputHub.clear_virtual()


## Online: alle Geräte starten gleichzeitig (Host gibt "go").
func _on_net_barrier_msg(from: String, msg: Dictionary) -> void:
	var k := String(msg.get("k", ""))
	if k == "ready":
		_net_ready[from] = true
	elif k == "go":
		_net_go = true


func _net_barrier() -> void:
	Net.message.connect(_on_net_barrier_msg)
	if Net.is_host:
		var waited := 0.0
		while waited < 12.0:
			var all := true
			for id in Net.players:
				if id != Net.me and not _net_ready.has(id):
					all = false
			if all:
				break
			await get_tree().process_frame
			waited += get_process_delta_time()
		Net.send({"k": "go"}, true)
	else:
		Net.send({"k": "ready"}, true, false)
		var w := 0.0
		while not _net_go and w < 15.0:
			await get_tree().process_frame
			w += get_process_delta_time()


func alive_count() -> int:
	var n := 0
	for a in alive:
		if a:
			n += 1
	return n


func eliminate(slot: int) -> void:
	if not alive[slot]:
		return
	alive[slot] = false
	out_order.append(slot)
	if slot < badges.size():
		badges[slot].set_out(true)
	if alive_count() >= 1:
		Audio.sfx("bong", null, -4.0)


func finish_player(slot: int) -> void:
	if slot in finish_order:
		return
	finish_order.append(slot)
	Audio.sfx("star")
	if rigs[slot]:
		(rigs[slot] as CharacterRig).react("cheer")
	Juice.float_text(self, (actors[slot] as Node3D).global_position + Vector3.UP * 2.8, "%d." % finish_order.size(), Game.player_color(slot), 120)


func add_score(slot: int, amount: float, at: Vector3 = Vector3.INF) -> void:
	scores[slot] += amount
	if at != Vector3.INF:
		var txt := ("+%d" % int(amount)) if amount > 0 else ("%d" % int(amount))
		Juice.float_text(self, at, txt, Color("#7dff9a") if amount > 0 else Color("#ff6b6b"), 90)


func end_game() -> void:
	if state != "play":
		return
	state = "finish"
	_freeze_all(true)
	InputHub.clear_virtual()
	InputHub.set_touch_profile("none")
	Audio.sfx("bell")
	await CutsceneManager.big_word("FERTIG!", Color("#ffcc33"), 1.0)
	var placements := forced_placements if forced_placements.size() == 4 else compute_placements()
	if net_sync and "--net-test" in str(OS.get_cmdline_user_args()):
		print("[NET] Minispiel-Ende · Platzierungen %s · alive %s · empfangen %s" % [placements, alive, Net.debug_counts])
	if net_sync and Net.is_host:
		Net.send({"k": "end", "pl": placements}, true)
	await CutsceneManager.play("MinigameWin", {"game": self, "placements": placements})
	await _show_results(placements)
	_return(placements)


## Platzierung pro Spieler (1..4, Gleichstand teilt Platz).
func compute_placements() -> Array[int]:
	var places: Array[int] = [4, 4, 4, 4]
	if race:
		var order: Array[int] = finish_order.duplicate()
		var rest: Array[int] = []
		for i in 4:
			if not (i in order):
				rest.append(i)
		rest.sort_custom(func(a: int, b: int) -> bool: return scores[a] > scores[b])
		order.append_array(rest)
		for pos in order.size():
			places[order[pos]] = pos + 1
		return places
	if survival:
		var survivors: Array[int] = []
		for i in 4:
			if alive[i]:
				survivors.append(i)
		for s in survivors:
			places[s] = 1
		var place := survivors.size() + 1
		for k in range(out_order.size() - 1, -1, -1):
			places[out_order[k]] = place
			place += 1
		return places
	var idx: Array[int] = [0, 1, 2, 3]
	idx.sort_custom(func(a: int, b: int) -> bool: return scores[a] > scores[b])
	for pos in idx.size():
		var p := idx[pos]
		places[p] = pos + 1
		if pos > 0 and is_equal_approx(scores[p], scores[idx[pos - 1]]):
			places[p] = places[idx[pos - 1]]
	return places


func _return(placements: Array[int]) -> void:
	Game.last_results = {"game": game_id, "placements": placements, "scores": scores.duplicate()}
	if not Game.players[0].cpu:
		EventBus.minigame_result.emit(placements)
	match Game.mode:
		"party":
			Router.goto("res://scenes/party/PartyBoard.tscn")
		"free_play":
			Router.goto("res://scenes/menu/MinigameSelect.tscn")
		"marathon":
			Router.goto("res://scenes/menu/MarathonHub.tscn")
		"online":
			Net.back_to_lobby()
			Router.goto("res://scenes/menu/MainMenu.tscn", {"page": "online"})
		_:
			Router.goto("res://scenes/menu/MainMenu.tscn")


# --- HUD & Overlays -------------------------------------------------------------------------------

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	_hud_root = UI.center_root(hud)
	var corners := [Control.PRESET_TOP_LEFT, Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT]
	for i in 4:
		var b := PlayerBadge.new()
		b.setup(i, true, true)
		_hud_root.add_child(b)
		b.grow_horizontal = Control.GROW_DIRECTION_BEGIN if i % 2 == 1 else Control.GROW_DIRECTION_END
		b.grow_vertical = Control.GROW_DIRECTION_BEGIN if i >= 2 else Control.GROW_DIRECTION_END
		b.set_anchors_and_offsets_preset(corners[i], Control.PRESET_MODE_MINSIZE, 14)
		badges.append(b)
	timer_label = UI.label(str(int(time_limit)), 64, Color.WHITE, true, 12)
	timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.position = Vector2(-60, 12)
	timer_label.size = Vector2(120, 80)
	timer_label.visible = show_timer
	_hud_root.add_child(timer_label)
	_update_badges()


func _update_badges() -> void:
	for i in badges.size():
		if survival:
			badges[i].set_status("alive" if alive[i] else "out")
		else:
			badges[i].set_score(score_format % scores[i])


func _instructions() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var root := UI.center_root(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.12, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := UI.panel()
	root.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(760, 0)
	var v := UI.vbox(16)
	panel.add_child(v)
	var t := UI.label(info.get("name", game_id), 64, UI.GOLD, true, 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var d := UI.label(info.get("desc", ""), 28)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.custom_minimum_size.x = 700
	v.add_child(d)
	var c := UI.label(info.get("controls", ""), 24, UI.ACCENT2)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(c)
	var go := UI.prompt("a", "Los geht's!", 30)
	v.add_child(go)
	await get_tree().process_frame
	panel.position = (root.size - panel.size) / 2.0
	Juice.pop_in(panel, 0.4)
	var has_human := false
	for i in 4:
		if not Game.players[i].cpu:
			has_human = true
	var wait := 0.0
	var limit := 8.0 if has_human else 2.0
	while wait < limit:
		await get_tree().process_frame
		wait += get_process_delta_time()
		if wait > 0.4 and (InputHub.any_human_pressed("a") or _touch_tap):
			break
		go.modulate.a = 0.6 + 0.4 * sin(wait * 5.0)
	_touch_tap = false
	Audio.sfx("ui_confirm")
	var tw := create_tween()
	tw.tween_property(panel, "scale", Vector2(0.01, 0.01), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(dim, "color:a", 0.0, 0.2)
	await tw.finished
	layer.queue_free()


var _touch_tap := false


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed and state in ["intro", "results"]:
		_touch_tap = true
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and state in ["intro", "results"]:
		_touch_tap = true


func _show_results(placements: Array[int]) -> void:
	state = "results"
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var root := UI.center_root(layer)
	var panel := UI.panel()
	root.add_child(panel)
	panel.custom_minimum_size = Vector2(720, 0)
	var v := UI.vbox(12)
	panel.add_child(v)
	var t := UI.label("Ergebnis", 56, UI.GOLD, true, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var order: Array[int] = [0, 1, 2, 3]
	order.sort_custom(func(a: int, b: int) -> bool: return placements[a] < placements[b])
	var rows: Array[Control] = []
	for p in order:
		var row := UI.hbox(16)
		var place := placements[p]
		var medal := TextureRect.new()
		medal.custom_minimum_size = Vector2(48, 48)
		medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if place <= 3:
			medal.texture = Assets.icon("medal_%d" % place)
		row.add_child(medal)
		var pl := UI.label("%d." % place, 40, UI.GOLD if place == 1 else Color.WHITE, true)
		pl.custom_minimum_size.x = 60
		row.add_child(pl)
		var nm := UI.label(Game.hero(Game.players[p].hero).name, 32, Game.player_color(p).lightened(0.3), true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		if not survival:
			row.add_child(UI.label(score_format % scores[p], 32, Color.WHITE, true))
		if Game.mode == "party":
			var reward: int = REWARDS[clampi(place - 1, 0, 3)]
			var rw := UI.hbox(4)
			rw.add_child(UIIcon.new("coin", 30))
			rw.add_child(UI.label("+%d" % reward, 32, Color("#7dff9a"), true))
			row.add_child(rw)
		row.modulate.a = 0.0
		v.add_child(row)
		rows.append(row)
	var go := UI.prompt("a", "Weiter", 28)
	v.add_child(go)
	await get_tree().process_frame
	panel.position = (root.size - panel.size) / 2.0
	Juice.pop_in(panel, 0.45)
	Audio.jingle("win")
	for i in range(rows.size() - 1, -1, -1):
		await get_tree().create_timer(0.18, false).timeout
		rows[i].modulate.a = 1.0
		Juice.ui_punch(rows[i], 0.15, 0.3)
		Audio.sfx("pluck", null, -4.0, 1.0 + (3 - i) * 0.1)
	var has_human := false
	for i in 4:
		if not Game.players[i].cpu:
			has_human = true
	var wait := 0.0
	_touch_tap = false
	while wait < (12.0 if has_human else 3.0):
		await get_tree().process_frame
		wait += get_process_delta_time()
		if wait > 0.6 and (InputHub.any_human_pressed("a") or _touch_tap):
			break
	Audio.sfx("ui_confirm")
