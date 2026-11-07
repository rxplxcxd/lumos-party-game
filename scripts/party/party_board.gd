extends Node3D
## Lumos Party – 3D-Brettspiel.
##
## Rundenablauf: Runden-Intro -> 4 Züge (Würfelblock, Hüpfen, Abzweigungen, Feld-Events)
## -> Minispiel-Roulette -> Minispiel-Szene -> zurück: Belohnungen -> nächste Runde
## -> nach der letzten Runde: Bonus-Sterne und Siegerehrung (Podest-Cutscene).

const STAR_COST_DEFAULT := 20
const DOUBLE_DICE_COST := 8
const DICE_MAX := 10

var def: Dictionary
var spaces: Array = []
var builder: BoardBuilder
var rigs: Array[CharacterRig] = []
var cam: BoardCamera
var surface := "stone"

var _hud: Control
var _badges: Array[PlayerBadge] = []
var _round_label: Label
var _prompt: ButtonPrompt
var _banner: Label
var _ff_hint: ButtonPrompt
var _current := -1
var _busy_ui := false


func _ready() -> void:
	if Game.party.is_empty():
		Game.start_party("dungeon", 5)
	def = BoardDefs.get_def(Game.party.board)
	spaces = BoardDefs.build_graph(def)
	surface = def.surface
	var we := WorldKit.env(self, def.env)
	if WorldKit.PRESETS.get(def.env, {}).get("rays", false):
		WorldKit.god_rays(self, Vector3.ZERO, 22.0, we.get_meta("sun"), 9)
	builder = BoardBuilder.new()
	builder.build(self, Game.party.board, spaces)
	_spawn_players()
	cam = BoardCamera.new()
	add_child(cam)
	cam.overview_center = Vector3(0, 0, 1)
	cam.make_current()
	cam.snap_overview()
	_build_hud()
	Audio.music(def.music)
	InputHub.set_touch_profile("board")
	_apply_routes(false)
	_place_star_node()
	_main()


# --- Spieler ----------------------------------------------------------------------------------------

func _spawn_players() -> void:
	for i in 4:
		var r := CharacterRig.new()
		add_child(r)
		r.setup(Game.hero(Game.players[i].hero).model, i, 0.8)
		r.surface = surface
		if Game.players[i].space < 0:
			Game.players[i].space = 0
		rigs.append(r)
	_formation_all(true)


func _formation_all(instant := false) -> void:
	var by_space := {}
	for i in 4:
		var s: int = Game.players[i].space
		if not by_space.has(s):
			by_space[s] = []
		by_space[s].append(i)
	for s in by_space:
		var list: Array = by_space[s]
		for k in list.size():
			var p: int = list[k]
			var off := Vector3.ZERO
			if list.size() > 1:
				var a := TAU * k / list.size() + PI / 4.0
				off = Vector3(cos(a), 0, sin(a)) * 0.85
			var target: Vector3 = _space_pos(s) + off
			if instant or p == _current:
				rigs[p].position = target
			else:
				rigs[p].create_tween().tween_property(rigs[p], "position", target, 0.25)
			if instant:
				rigs[p].face_now(Vector3(0, 0, 1))


func _space_pos(id: int) -> Vector3:
	return builder.space_nodes[id].position + Vector3.UP * 0.45


# --- Hauptablauf ---------------------------------------------------------------------------------------

func _main() -> void:
	await get_tree().process_frame
	var party: Dictionary = Game.party
	if party.phase == "minigame":
		await _apply_minigame_results()
		party.round += 1
		party.turn = 0
		if party.round > party.max_rounds:
			await _finale()
			return
	party.phase = "turns"
	if "--test-roulette" in OS.get_cmdline_user_args():
		await _choose_minigame()
		return
	while true:
		await _round_start()
		for t in range(int(party.turn), 4):
			party.turn = t
			await _turn(t)
		party.turn = 0
		await _choose_minigame()
		return


func _round_start() -> void:
	var party: Dictionary = Game.party
	var r: int = party.round
	if not party.first_intro_done:
		party.first_intro_done = true
		await CutsceneManager.play("RoundIntro", {"board": self, "first": true})
	else:
		cam.overview = true
		await _wait(0.5)
	_round_label.text = "Runde %d / %d" % [r, party.max_rounds]
	Juice.ui_punch(_round_label, 0.3, 0.4)
	var last: bool = r == party.max_rounds
	if last:
		Audio.voice("final_round")
		await _show_banner("LETZTE RUNDE!", Color("#ff4d6d"), 1.4)
		# Aufholjagd: Letzter Platz bekommt Bonusmünzen
		var rank := Game.ranking()
		var lastp := rank[3]
		cam.snap_to(rigs[lastp])
		await _wait(0.4)
		await _show_banner("Aufholjagd-Bonus für %s: +10" % _pname(lastp), Game.player_color(lastp), 1.2)
		_coins(lastp, 10)
		rigs[lastp].react("cheer")
		await _wait(1.0)
	else:
		Audio.voice("round_%d" % r if r <= 5 else "begin")
		await _show_banner("Runde %d" % r, Color.WHITE, 1.0)
	# Wechselnde Routen
	if _apply_routes(true):
		await _wait(1.2)
	if int(party.star_space) < 0:
		await _relocate_star(-1, true)


func _turn(p: int) -> void:
	_current = p
	for i in 4:
		_badges[i].modulate = Color.WHITE if i == p else Color(0.75, 0.75, 0.8)
	Juice.ui_punch(_badges[p], 0.2, 0.4)
	EventBus.turn_started.emit(p)
	var rig := rigs[p]
	cam.target = rig
	cam.overview = false
	cam.zoom = 1.0
	_ff_hint.visible = Game.players[p].cpu and _any_human()
	await _show_banner("%s ist dran!" % _pname(p), Game.player_color(p), 0.9)
	rig.face_now(cam.global_position - rig.global_position)
	rig.react("determined")
	await _wait(0.6)
	var dice := 2 if Game.party_mode() == "blitz" else 1
	var items: Array = Game.players[p].items
	if "double_dice" in items:
		var use := await _ask(p, "Doppelwürfel benutzen?", true)
		if use:
			items.erase("double_dice")
			dice += 1
	var total := 0
	for k in dice:
		total += await _roll_dice(p, k, dice)
	Game.players[p].last_roll = total
	await _move(p, total)
	await _land(p)
	_ff_hint.visible = false
	Juice.base_time_scale = 1.0
	rig.play("idle")
	_formation_all()
	await _wait(0.3)


func _process(_delta: float) -> void:
	if CutsceneManager.active:
		return
	if _current >= 0 and Game.players[_current].cpu and _any_human():
		var ff := false
		for i in 4:
			if not Game.players[i].cpu and InputHub.held(i, "a"):
				ff = true
		Juice.base_time_scale = 2.5 if ff else 1.0


# --- Würfel ---------------------------------------------------------------------------------------------

func _roll_dice(p: int, k: int, count: int) -> int:
	var rig := rigs[p]
	var holder := Node3D.new()
	add_child(holder)
	var side := Vector3.ZERO
	if count > 1:
		side = cam.global_basis.x * (1.1 if k == 0 else -1.1)
	holder.global_position = rig.global_position + Vector3.UP * 3.6 + side
	var die := Assets.spawn("bg/d6", holder, Vector3.ZERO, 0.0, 2.4)
	var num := Label3D.new()
	num.font = UI.title_font()
	num.font_size = 160
	num.outline_size = 34
	num.outline_modulate = Color(0.1, 0.03, 0.2)
	num.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	num.no_depth_test = true
	num.pixel_size = 0.006
	num.position = Vector3(0, 0, 0)
	holder.add_child(num)
	Juice.pop_in(holder, 0.35)
	_set_prompt("Würfeln!" if not Game.players[p].cpu else "")
	var value := 1
	var t := 0.0
	var wait_cpu := randf_range(0.7, 1.4)
	var tick := 0.0
	while true:
		var dt := get_process_delta_time()
		t += dt
		tick += dt
		die.rotation += Vector3(7.0, 9.0, 4.0) * dt
		holder.position.y = rig.global_position.y + 3.6 + sin(t * 5.0) * 0.12
		if tick > 0.06:
			tick = 0.0
			value = randi_range(1, DICE_MAX)
			num.text = str(value)
			num.modulate = Color.from_hsv(randf(), 0.4, 1.0)
		if Game.players[p].cpu:
			if t > wait_cpu:
				break
		elif t > 0.25 and (InputHub.ui_pressed(p, "a") or _tap_consume()):
			break
		await get_tree().process_frame
	_set_prompt("")
	# Sprung gegen den Block
	rig.play("jump_start", 0.05, 1.4, true)
	await rig.anticipate(0.35, 0.09).step_finished
	Audio.sfx("jump", rig.global_position)
	rig.hop(1.4, 0.42)
	await _wait(0.17)
	Audio.sfx("dice_hit", holder.global_position)
	Audio.sfx("pop", holder.global_position)
	FX.stars(holder.global_position, Color(1, 0.9, 0.3), 14)
	FX.ring(holder.global_position, Color(1, 1, 1, 0.8), 2.5, 0.35)
	Juice.shake(0.25)
	Juice.hitstop(0.06)
	InputHub.rumble(p, 0.6, 0.15)
	die.visible = false
	num.modulate = Color.WHITE
	num.text = str(value)
	num.scale = Vector3.ONE * 1.8
	num.create_tween().tween_property(num, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await _wait(0.55)
	var tw := holder.create_tween()
	tw.tween_property(holder, "scale", Vector3.ZERO, 0.2)
	tw.tween_callback(holder.queue_free)
	return value


var _tap := false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_tap = true
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_tap = true


func _tap_consume() -> bool:
	var t := _tap
	_tap = false
	return t


# --- Bewegung -------------------------------------------------------------------------------------------

func _route_open(bi: int) -> bool:
	if bi < 0:
		return true
	var br: Dictionary = def.branches[bi]
	var tog: String = br.get("toggle", "")
	if tog == "":
		return true
	var even: bool = int(Game.party.round) % 2 == 0
	return even if tog == "even" else not even


func _available_next(cur: int) -> Array:
	var out := []
	for n in spaces[cur].next:
		var b: int = spaces[n].branch
		if b >= 0 and spaces[cur].branch != b and not _route_open(b):
			continue
		out.append(n)
	if out.is_empty():
		out.append(spaces[cur].next[0])
	return out


## Wendet Routen-Zustände an. Gibt true zurück, wenn sich etwas geändert hat (mit Kamerafahrt).
func _apply_routes(animate: bool) -> bool:
	var changed := false
	var states: Dictionary = Game.party.get("route_states", {})
	for bi in def.branches.size():
		var br: Dictionary = def.branches[bi]
		if br.get("toggle", "") == "":
			continue
		var open := _route_open(bi)
		if states.get(bi, null) != open:
			changed = true
			builder.set_route_open(bi, open, animate)
			states[bi] = open
			if animate:
				var mid := Vector3.ZERO
				var n := 0
				for sp in spaces:
					if sp.branch == bi:
						mid += sp.pos
						n += 1
				if n > 0:
					mid /= n
					cam.overview = false
					cam.target = null
					var marker := Node3D.new()
					add_child(marker)
					marker.position = mid
					cam.target = marker
					cam.zoom = 1.6
					Audio.sfx("creak", mid)
					Audio.sfx("stone_hit", mid)
					Juice.shake(0.2)
					var kind: String = br.get("kind", "")
					var txts: Dictionary = {"lava_bridge": ["Der Lava-Steg taucht auf!", "Der Lava-Steg versinkt!"],
						"tide": ["Ebbe: Die Sandbank taucht auf!", "Flut: Die Sandbank verschwindet!"],
						"drawbridge": ["Die Zugbrücke senkt sich!", "Die Zugbrücke klappt hoch!"],
						"fog_bridge": ["Die Geisterbrücke erscheint!", "Die Geisterbrücke löst sich auf!"],
						"ice_bridge": ["Der See friert zu!", "Das Eis taut weg!"],
						"airlock": ["Luftschleuse offen!", "Luftschleuse geschlossen!"]}
					var pair: Array = txts.get(kind, ["Die Route öffnet sich!", "Die Route schließt sich!"])
					_show_banner(pair[0] if open else pair[1], Color("#ffcc33"), 1.1)
					get_tree().create_timer(1.6).timeout.connect(marker.queue_free)
	Game.party.route_states = states
	return changed


func _move(p: int, steps: int) -> void:
	var rig := rigs[p]
	var counter := Label3D.new()
	counter.font = UI.title_font()
	counter.font_size = 150
	counter.outline_size = 32
	counter.outline_modulate = Color(0.1, 0.03, 0.2)
	counter.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	counter.no_depth_test = true
	counter.pixel_size = 0.006
	counter.position = Vector3.UP * 3.3
	rig.add_child(counter)
	var cur: int = Game.players[p].space
	var remaining := steps
	while remaining > 0:
		counter.text = str(remaining)
		var options := _available_next(cur)
		var nxt: int = options[0]
		if options.size() > 1:
			nxt = await _choose_path(p, cur, options)
		# Skelett-Wächter-Wegzoll
		var nb: int = spaces[nxt].branch
		if nb >= 0 and spaces[cur].branch != nb and def.branches[nb].has("gate"):
			var toll: int = def.branches[nb].gate
			var pay := false
			if Game.players[p].coins >= toll:
				if builder.gate_npc:
					builder.gate_npc.react("taunt")
				pay = await _ask(p, "Skelett-Wächter: %d Münzen Wegzoll?" % toll, true)
			if pay:
				_coins(p, -toll)
				if builder.gate_npc:
					builder.gate_npc.play("wave")
			else:
				if builder.gate_npc:
					builder.gate_npc.react("laugh")
				await _show_banner("Kein Durchkommen!", Color("#ff6b6b"), 0.8)
				nxt = spaces[cur].next[0]
		await _hop(p, cur, nxt)
		cur = nxt
		Game.players[p].space = cur
		remaining -= 1
		counter.text = str(remaining) if remaining > 0 else ""
		Juice.squash(counter, 1.3, 1.3, 0.25)
		# Durchgangs-Events
		if cur == int(Game.party.star_space):
			await _star_event(p)
		elif spaces[cur].type == "N" and remaining > 0:
			await _shop(p)
	counter.queue_free()


func _hop(p: int, from: int, to: int) -> void:
	var rig := rigs[p]
	var a := rig.position
	var b := _space_pos(to)
	rig.face_now(b - a)
	rig.play("run", 0.1, 1.3)
	var dur := 0.3
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		rig.position = a.lerp(b, t) + Vector3.UP * sin(t * PI) * 0.6, 0.0, 1.0, dur)
	await tw.finished
	rig.squash(1.18, 0.85, 0.25)
	FX.step(rig.global_position, surface, 0.9, true)
	Audio.sfx("tick", null, -10.0, 1.2)


func _choose_path(p: int, cur: int, options: Array) -> int:
	var rig := rigs[p]
	rig.play("idle")
	cam.zoom = 1.45
	var arrows: Array[Node3D] = []
	var origin := _space_pos(cur)
	for o in options:
		var dir: Vector3 = (_space_pos(o) - origin)
		dir.y = 0
		dir = dir.normalized()
		var arrow := Node3D.new()
		add_child(arrow)
		arrow.position = origin + dir * 2.2 + Vector3.UP * 0.9
		var m := Assets.spawn("plat/arrow", arrow, Vector3.ZERO, 0.0, 2.2)
		m.rotation.x = -PI / 2.0
		arrow.look_at(arrow.position + dir, Vector3.UP)
		var b: int = spaces[o].branch
		var tag := ""
		if b >= 0 and spaces[cur].branch != b:
			tag = "Wegzoll %d" % def.branches[b].gate if def.branches[b].has("gate") else "Abkürzung?"
		if tag != "":
			var l := Label3D.new()
			l.text = tag
			l.font = UI.title_font()
			l.font_size = 64
			l.outline_size = 14
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.position = Vector3.UP * 1.1
			l.pixel_size = 0.006
			arrow.add_child(l)
		arrows.append(arrow)
	var sel := 0
	var chosen := -1
	var t := 0.0
	var prev_x := 0.0
	var cpu_pick := _cpu_path(p, options)
	_set_prompt("" if Game.players[p].cpu else "Weg wählen (Stick links/rechts)")
	while chosen < 0:
		var dt := get_process_delta_time()
		t += dt
		for i in arrows.size():
			var s := 1.0 + (0.25 + sin(t * 8.0) * 0.12 if i == sel else 0.0)
			arrows[i].scale = arrows[i].scale.lerp(Vector3.ONE * s, clampf(dt * 12.0, 0, 1))
		if Game.players[p].cpu:
			if t > 0.9:
				sel = cpu_pick
				if t > 1.25:
					chosen = options[sel]
		else:
			var mv := InputHub.move(p)
			var x := mv.x if absf(mv.x) > absf(mv.y) else -mv.y
			if absf(x) > 0.6 and absf(prev_x) <= 0.6:
				sel = wrapi(sel + (1 if x > 0 else -1), 0, options.size())
				Audio.sfx("ui_move")
			prev_x = x
			if t > 0.25 and (InputHub.ui_pressed(p, "a") or _tap_consume()):
				chosen = options[sel]
		await get_tree().process_frame
	Audio.sfx("ui_confirm")
	for a in arrows:
		a.queue_free()
	_set_prompt("")
	cam.zoom = 1.0
	return chosen


func _cpu_path(p: int, options: Array) -> int:
	var star: int = Game.party.star_space
	var best := 0
	var best_d := INF
	for i in options.size():
		var d := float(_dist(options[i], star))
		var b: int = spaces[options[i]].branch
		if b >= 0 and def.branches[b].has("gate") and Game.players[p].coins < int(def.branches[b].gate) + _star_cost():
			d += 6.0
		d += randf() * [6.0, 3.0, 0.5][int(Game.players[p].cpu_level)]
		if d < best_d:
			best_d = d
			best = i
	return best


## Schritte von a nach b (BFS über offene Routen).
func _dist(a: int, b: int) -> int:
	if a == b or b < 0:
		return 0
	var seen := {a: 0}
	var q := [a]
	while q.size() > 0:
		var c: int = q.pop_front()
		for n in _available_next(c):
			if not seen.has(n):
				seen[n] = seen[c] + 1
				if n == b:
					return seen[n]
				q.append(n)
	return 99


# --- Feld-Events ----------------------------------------------------------------------------------------------

func _land(p: int) -> void:
	var rig := rigs[p]
	var s: int = Game.players[p].space
	var t: String = spaces[s].type
	EventBus.space_landed.emit(p, t)
	rig.face_now(cam.global_position - rig.global_position)
	var node := builder.space_nodes[s]
	Juice.squash(node, 1.15, 0.7, 0.4, node.scale)
	match t:
		"B", "S":
			_coins(p, 3)
			rig.react("coin_gain")
			await _wait(1.0)
		"R":
			_coins(p, -3)
			rig.react("coin_loss")
			await _wait(1.0)
		"L":
			await _lucky_chest(p)
		"P":
			await _show_banner("Piraten-Planke!", Color("#7dff9a"), 0.8)
			await CutsceneManager.play("PlankLaunch", {"board": self, "player": p})
		"C":
			await _show_banner("Dungeon-Fluch!", Color("#c79bff"), 0.8)
			await CutsceneManager.play("CurseSwap", {"board": self, "player": p})
		"T":
			await _torch_trap(p)
		"K":
			await _cloud_cannon(p)
		"N":
			await _shop(p)
		"G":
			await _ghost_taxi(p)
		"E":
			await _ice_slide(p)
		"W":
			await _warp(p)
	_formation_all()


func _torch_trap(p: int) -> void:
	var rig := rigs[p]
	await _show_banner("Fackel-Falle!", Color("#ffb070"), 0.7)
	Audio.sfx("thruster", rig.global_position)
	for i in 3:
		FX.embers(rig.global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), 16)
	FX.explosion(rig.global_position, 0.6)
	Juice.hitstop(0.08)
	InputHub.rumble(p, 0.9, 0.3)
	rig.react("soot_blast")
	_coins(p, -5)
	await _wait(2.4)


func _cloud_cannon(p: int) -> void:
	var rig := rigs[p]
	await _show_banner("Raketen-Start!" if Game.party.board == "station" else "Wolken-Kanone!", Color("#7fd6ff"), 0.7)
	var cur: int = Game.players[p].space
	var jumps := randi_range(5, 12)
	var target := cur
	for i in jumps:
		target = _available_next(target)[randi() % _available_next(target).size()]
	Audio.sfx("cannon", rig.global_position)
	FX.smoke(rig.global_position, Color(1, 1, 1), 12, 1.2)
	Juice.shake(0.4)
	rig.react("launch")
	var a := rig.position
	var b := _space_pos(target)
	cam.zoom = 2.2
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		rig.position = a.lerp(b, t) + Vector3.UP * sin(t * PI) * 14.0
		rig.rotation.x = t * TAU * 2.0, 0.0, 1.0, 1.6).set_trans(Tween.TRANS_SINE)
	await tw.finished
	rig.rotation.x = 0
	rig.land_impact(1.3)
	rig.react("land_flat")
	Juice.shake(0.35)
	Game.players[p].space = target
	cam.zoom = 1.0
	await _wait(1.3)
	if target == int(Game.party.star_space):
		await _star_event(p)


## Geisterfriedhof: Ein Geist packt dich und fliegt dich ein paar Felder vor – oder zurück.
func _ghost_taxi(p: int) -> void:
	var rig := rigs[p]
	await _show_banner("Geister-Taxi!", Color("#9dffc8"), 0.7)
	var ghost := CharacterRig.new()
	add_child(ghost)
	ghost.setup("npc/ghost", -1, 1.6)
	var start := rig.position
	ghost.position = start + Vector3(0, 7, -2)
	ghost.play("idle")
	Audio.sfx("ghost", start)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "position", start + Vector3(0, 1.9, 0), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	rig.react("scared")
	InputHub.rumble(p, 0.5, 0.2)
	await _wait(0.6)
	var forward := randf() < 0.6
	var n := randi_range(2, 6) if forward else randi_range(2, 4)
	var target: int = Game.players[p].space
	for _i in n:
		if forward:
			var opts := _available_next(target)
			target = opts[randi() % opts.size()]
		else:
			target = int(spaces[target].prev[0])
	await _show_banner(("%d Felder vor!" % n) if forward else ("%d Felder zurück…" % n), Color("#9dffc8") if forward else Color("#ff9db0"), 0.7)
	var a := rig.position
	var b := _space_pos(target)
	cam.zoom = 1.8
	var fly := create_tween()
	fly.tween_method(func(t: float) -> void:
		var pos := a.lerp(b, t) + Vector3.UP * (sin(t * PI) * 5.0 + 1.0 * (1.0 - t))
		rig.position = pos
		ghost.position = pos + Vector3.UP * 1.7
		rig.rotation.z = sin(t * TAU * 2.0) * 0.35, 0.0, 1.0, 1.8).set_trans(Tween.TRANS_SINE)
	await fly.finished
	rig.rotation.z = 0.0
	rig.position = b
	rig.land_impact(1.0)
	Game.players[p].space = target
	FX.smoke(b, Color(0.7, 1.0, 0.85), 10, 1.0)
	Audio.sfx("evil_laugh", b, -6.0)
	var gone := ghost.create_tween()
	gone.tween_property(ghost, "position", ghost.position + Vector3(0, 9, -3), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	gone.tween_callback(ghost.queue_free)
	cam.zoom = 1.0
	await _wait(0.9)
	if target == int(Game.party.star_space):
		await _star_event(p)


## Frostdorf: Auf dem Eis schlitterst du 2–4 Felder weiter. Manchmal legt man sich aber auch hin.
func _ice_slide(p: int) -> void:
	var rig := rigs[p]
	await _show_banner("Eis-Rutsche!", Color("#bfefff"), 0.7)
	if randf() < 0.3:
		rig.react("slip")
		Audio.sfx("boing", rig.global_position)
		InputHub.rumble(p, 0.6, 0.2)
		await _wait(1.1)
		_coins(p, -2)
		await _show_banner("Ausgerutscht! -2 Münzen", Color("#ff9db0"), 0.8)
		return
	var n := randi_range(2, 4)
	var cur: int = Game.players[p].space
	cam.zoom = 1.3
	for _i in n:
		var nxt: int = _available_next(cur)[0]
		var a := rig.position
		var b := _space_pos(nxt)
		rig.spin_around(1.0, 0.3)
		FX.dust(a, Color(0.9, 0.97, 1.0), 8, 0.8)
		Audio.sfx("drift", a, -6.0, 1.2)
		var tw := create_tween()
		tw.tween_property(rig, "position", b, 0.3)
		await tw.finished
		cur = nxt
		Game.players[p].space = cur
		if cur == int(Game.party.star_space):
			break
	rig.land_impact(0.8)
	rig.react("cheer")
	cam.zoom = 1.0
	await _wait(0.8)
	if cur == int(Game.party.star_space):
		await _star_event(p)


## Orbit-Station: Beam zu einem zufälligen anderen Warp-Pad.
func _warp(p: int) -> void:
	var rig := rigs[p]
	var cur: int = Game.players[p].space
	var pads: Array[int] = []
	for sp in spaces:
		if sp.type == "W" and int(sp.id) != cur and (int(sp.branch) < 0 or _route_open(int(sp.branch))):
			pads.append(int(sp.id))
	if pads.is_empty():
		return
	await _show_banner("Warp-Pad!", Color("#7ff0ff"), 0.7)
	var target: int = pads[randi() % pads.size()]
	var base := rig.scale
	Audio.sfx("forcefield", rig.global_position)
	FX.ring(rig.global_position + Vector3.UP * 0.2, Color(0.4, 0.95, 1.0, 0.9), 2.5, 0.4)
	var tw := create_tween()
	tw.tween_property(rig, "scale", Vector3(base.x * 0.15, base.y * 3.0, base.z * 0.15), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tw.finished
	FX.sparks(rig.global_position + Vector3.UP, Color(0.5, 0.95, 1.0), 24, 1.4)
	rig.visible = false
	await _wait(0.25)
	rig.position = _space_pos(target)
	Game.players[p].space = target
	cam.snap_to(rig)
	await _wait(0.2)
	rig.visible = true
	FX.ring(rig.global_position + Vector3.UP * 0.2, Color(0.4, 0.95, 1.0, 0.9), 2.5, 0.4)
	Audio.sfx("zap", rig.global_position)
	var tw2 := create_tween()
	tw2.tween_property(rig, "scale", base, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await tw2.finished
	rig.react("dizzy")
	await _wait(1.0)
	if target == int(Game.party.star_space):
		await _star_event(p)


func _lucky_chest(p: int) -> void:
	var rig := rigs[p]
	var sp: Vector3 = spaces[Game.players[p].space].pos
	var chest: Node3D = null
	var best := INF
	for c in builder.traps:
		if c.has_meta("chest") and c.global_position.distance_to(sp) < best:
			best = c.global_position.distance_to(sp)
			chest = c
	await _show_banner("Glücksrad-Kiste!", Color("#ffcc33"), 0.7)
	if chest:
		Audio.sfx("chest_open", chest.global_position)
		Juice.squash(chest, 1.3, 0.7, 0.5, chest.scale)
		FX.stars(chest.global_position + Vector3.UP, Color(1, 0.9, 0.3), 16)
		FX.flash_light(chest.global_position + Vector3.UP, Color(1, 0.9, 0.4), 6.0, 0.6)
	Audio.jingle("lucky")
	var segs := [
		{"text": "+10 Münzen", "color": Color("#f5b301"), "weight": 2.0, "id": "coins10"},
		{"text": "-5 Münzen", "color": Color("#e8364f"), "weight": 1.6, "id": "minus5"},
		{"text": "Doppelwürfel", "color": Color("#2f9bff"), "weight": 1.4, "id": "dice"},
		{"text": "Münztausch!", "color": Color("#9b4dff"), "weight": 1.0, "id": "swap"},
		{"text": "Alle -3", "color": Color("#ff8c1a"), "weight": 1.4, "id": "all3"},
		{"text": "STERN!", "color": Color("#ffd84d"), "weight": 0.45, "id": "star"},
		{"text": "+5 Münzen", "color": Color("#2ecc71"), "weight": 1.8, "id": "coins5"},
		{"text": "Pech: -10", "color": Color("#7a1a2a"), "weight": 0.9, "id": "minus10"},
	]
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var root := UI.center_root(layer)
	var wheel := FortuneWheel.new().setup(segs)
	root.add_child(wheel)
	await get_tree().process_frame
	wheel.position = Vector2((root.size.x - wheel.custom_minimum_size.x) / 2.0, (root.size.y - wheel.custom_minimum_size.y) / 2.0)
	wheel.size = wheel.custom_minimum_size
	Juice.pop_in(wheel, 0.4)
	wheel.spin()
	_set_prompt("" if Game.players[p].cpu else "Stopp!")
	var t := 0.0
	var stop_at := randf_range(1.2, 2.2)
	while not wheel.stopping:
		t += get_process_delta_time()
		if Game.players[p].cpu and t > stop_at:
			wheel.stop()
		elif not Game.players[p].cpu and t > 0.4 and (InputHub.ui_pressed(p, "a") or _tap_consume()):
			wheel.stop()
		await get_tree().process_frame
	_set_prompt("")
	var idx: int = await wheel.finished
	var seg: Dictionary = segs[idx]
	await _show_banner(seg.text, seg.color, 0.9)
	await _wait(0.3)
	layer.queue_free()
	match seg.id:
		"coins10":
			_coins(p, 10)
			rig.react("cheer")
		"coins5":
			_coins(p, 5)
			rig.react("coin_gain")
		"minus5":
			_coins(p, -5)
			rig.react("coin_loss")
		"minus10":
			_coins(p, -10)
			rig.react("tantrum")
		"dice":
			if not ("double_dice" in Game.players[p].items):
				Game.players[p].items.append("double_dice")
			FX.stars(rig.global_position + Vector3.UP * 2.0)
			rig.react("cheer")
		"swap":
			var rank := Game.ranking()
			var other := rank[0] if rank[0] != p else rank[1]
			var mine: int = Game.players[p].coins
			var theirs: int = Game.players[other].coins
			_coins(p, theirs - mine)
			_coins(other, mine - theirs)
			Audio.sfx("swap")
			rig.react("laugh")
			rigs[other].react("shocked")
		"all3":
			for i in 4:
				if i != p:
					_coins(i, -3)
					rigs[i].react("coin_loss")
			rig.react("laugh")
		"star":
			await CutsceneManager.play("StarGet", {"board": self, "player": p, "free": true})
	await _wait(1.2)


func _shop(p: int) -> void:
	if "double_dice" in Game.players[p].items or Game.players[p].coins < DOUBLE_DICE_COST:
		return
	if builder.merchant:
		builder.merchant.react("wave")
	var cpu_buy: bool = Game.players[p].coins >= DOUBLE_DICE_COST + 12
	var buy := await _ask(p, "Krabben-Kalle: Doppelwürfel für %d Münzen?" % DOUBLE_DICE_COST, cpu_buy)
	if buy:
		_coins(p, -DOUBLE_DICE_COST)
		Game.players[p].items.append("double_dice")
		Audio.sfx("item_get")
		rigs[p].react("cheer")
		if builder.merchant:
			builder.merchant.react("cheer")
		await _wait(0.8)


func _star_event(p: int) -> void:
	var rig := rigs[p]
	cam.zoom = 0.85
	if Game.players[p].coins < _star_cost():
		await _show_banner("Zu wenig Münzen für den Stern!", Color("#ff6b6b"), 1.0)
		rig.react("sad")
		await _wait(0.8)
		cam.zoom = 1.0
		return
	var buy := await _ask(p, "Lumos-Stern für %d Münzen kaufen?" % _star_cost(), true)
	if buy:
		await CutsceneManager.play("StarGet", {"board": self, "player": p, "free": false})
		await _relocate_star(int(Game.party.star_space))
	cam.zoom = 1.0


## Vom StarGet-Cutscene aufgerufen.
func grant_star(p: int, pay: bool) -> void:
	if pay:
		_coins(p, -_star_cost())
	Game.add_stars(p, 1)


func _place_star_node() -> void:
	var s: int = Game.party.star_space
	if s >= 0:
		builder.star_node.visible = true
		builder.star_node.position = _space_pos(s) + Vector3.UP * 2.6
	else:
		builder.star_node.visible = false


## Verlegt den Stern auf ein neues Feld (mit Kamerafahrt).
func _relocate_star(exclude: int, first := false) -> void:
	var cands: Array[int] = []
	for sp in spaces:
		if sp.type == "B" and sp.id != exclude and sp.branch < 0:
			var far := true
			for i in 4:
				if _dist(int(Game.players[i].space), sp.id) < 6:
					far = false
			if far:
				cands.append(sp.id)
	if cands.is_empty():
		for sp in spaces:
			if sp.type == "B" and sp.id != exclude:
				cands.append(sp.id)
	var s: int = cands[randi() % cands.size()]
	Game.party.star_space = s
	var marker := Node3D.new()
	add_child(marker)
	marker.position = _space_pos(s)
	var prev_target := cam.target
	cam.overview = false
	cam.target = marker
	cam.zoom = 1.2
	await _wait(0.8)
	_place_star_node()
	Juice.pop_in(builder.star_node, 0.6)
	FX.stars(builder.star_node.global_position, Color(1, 0.9, 0.3), 20)
	FX.confetti(builder.star_node.global_position, 40)
	Audio.jingle("star")
	await _show_banner("Der Stern ist erschienen!" if first else "Der Stern ist umgezogen!", Color("#ffcc33"), 1.2)
	cam.target = prev_target
	cam.zoom = 1.0
	marker.queue_free()


func relocate_star_after_buy() -> void:
	await _relocate_star(int(Game.party.star_space))


# --- Minispiele -----------------------------------------------------------------------------------------

func _choose_minigame() -> void:
	cam.overview = true
	_set_prompt("")
	var played: Array = Game.party.minigames_played
	var pool: Array = []
	for m in Game.MINIGAMES:
		if not (m.id in played.slice(maxi(0, played.size() - 4))):
			pool.append(m)
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var root := UI.center_root(layer)
	var panel := UI.panel()
	root.add_child(panel)
	var v := UI.vbox(10)
	panel.add_child(v)
	var title := UI.label("Minispiel-Roulette!", 52, UI.GOLD, true, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var all_names: Array = Game.MINIGAMES.map(func(m: Dictionary) -> String: return m.name)
	var palette := [Color("#ff4fb8"), Color("#2f9bff"), Color("#2ecc71"), Color("#ff9f1a"), Color("#c06bff")]
	var cols: Array = []
	for i in all_names.size():
		cols.append(palette[i % palette.size()])
	var reel := RouletteReel.new().setup(all_names, cols)
	v.add_child(reel)
	var desc := UI.label("", 22, Color(1, 1, 1, 0.9))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.custom_minimum_size = Vector2(640, 84)
	v.add_child(desc)
	await get_tree().process_frame
	panel.position = (root.size - panel.size) / 2.0
	Juice.pop_in(panel, 0.35)
	Audio.sfx("drumroll")
	var pick: Dictionary = pool[randi() % pool.size()]
	var target := Game.MINIGAMES.find(pick)
	await reel.spin_to(target, 3, 3.2)
	# Anzeige und geladenes Spiel sind identisch: wir laden exakt den Eintrag unter dem Zeiger
	pick = Game.MINIGAMES[reel.current_index()]
	desc.text = pick.desc
	await get_tree().process_frame
	panel.create_tween().tween_property(panel, "position", (root.size - panel.size) / 2.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Audio.sfx("bell")
	Juice.ui_punch(reel, 0.12, 0.5)
	FX.confetti(cam.global_position + cam.global_basis.z * -12.0, 40)
	await _wait(1.6)
	played.append(pick.id)
	Game.party.phase = "minigame"
	Game.pending_minigame = pick.id
	Router.goto(pick.scene)


func _apply_minigame_results() -> void:
	cam.overview = true
	var res: Dictionary = Game.last_results
	if res.is_empty():
		return
	var places: Array = res.placements
	await _show_banner("Minispiel-Belohnung", UI.GOLD, 0.9)
	var order := [0, 1, 2, 3]
	order.sort_custom(func(a: int, b: int) -> bool: return places[a] < places[b])
	for p in order:
		var reward: int = MinigameBase.REWARDS[clampi(int(places[p]) - 1, 0, 3)]
		if int(places[p]) == 1:
			Game.players[p].minigame_wins += 1
		cam.overview = false
		cam.target = rigs[p]
		cam.zoom = 0.9
		await _wait(0.45)
		if reward > 0:
			_coins(p, reward)
			rigs[p].react("cheer" if int(places[p]) == 1 else "coin_gain")
		else:
			rigs[p].react("sad")
		await _wait(0.7)
	Game.last_results = {}
	cam.zoom = 1.0
	cam.overview = true
	await _wait(0.4)


# --- Finale ------------------------------------------------------------------------------------------------

func _finale() -> void:
	Game.party.phase = "final"
	cam.overview = true
	Audio.voice("game_over")
	await _show_banner("Das Spiel ist vorbei!", Color.WHITE, 1.4)
	# Bonus-Sterne
	var bonus := [["Minispiel-Star", "minigame_wins"], ["Münz-Star", "coins_max"]]
	for b in bonus:
		var best := -1
		for i in 4:
			best = maxi(best, int(Game.players[i][b[1]]))
		if best <= 0:
			continue
		for i in 4:
			if int(Game.players[i][b[1]]) == best:
				cam.overview = false
				cam.target = rigs[i]
				await _show_banner("%s: %s!" % [b[0], _pname(i)], UI.GOLD, 1.2)
				Game.add_stars(i, 1)
				rigs[i].react("star_get")
				FX.confetti(rigs[i].global_position + Vector3.UP * 2.0, 40)
				Audio.jingle("star")
				await _wait(1.6)
	var rank := Game.ranking()
	if Game.is_team_mode():
		var teams := Game.team_ranking()
		var names := ["Team Rot & Grün", "Team Blau & Gelb"]
		cam.overview = true
		await _show_banner("%s gewinnt!" % names[teams[0]], Game.player_color(teams[0]), 1.8)
		var win: Array[int] = []
		var lose: Array[int] = []
		for i in rank:
			if Game.team_of(i) == teams[0]:
				win.append(i)
			else:
				lose.append(i)
		rank = win + lose
		for i in win:
			rigs[i].react("victory")
			FX.confetti(rigs[i].global_position + Vector3.UP * 2.0, 50)
		await _wait(1.2)
	EventBus.party_result.emit(rank)
	await CutsceneManager.play("Podium", {"board": self, "ranking": rank, "skippable": false})
	Router.goto("res://scenes/menu/MainMenu.tscn")


# --- Hilfen ---------------------------------------------------------------------------------------------------

var _mode_label: Label


func _refresh_mode_label() -> void:
	if _mode_label == null:
		return
	if Game.is_team_mode():
		var st := [0, 0]
		var co := [0, 0]
		for i in 4:
			st[Game.team_of(i)] += int(Game.players[i].stars)
			co[Game.team_of(i)] += int(Game.players[i].coins)
		_mode_label.text = "Rot+Grün  ★%d · %d Münzen     |     Blau+Gelb  ★%d · %d Münzen" % [st[0], co[0], st[1], co[1]]
	else:
		_mode_label.text = "BLITZ-PARTY · 2 Würfel · Stern = %d Münzen" % _star_cost()


func _star_cost() -> int:
	return 10 if Game.party_mode() == "blitz" else STAR_COST_DEFAULT


func _coins(p: int, delta: int) -> void:
	var real := Game.add_coins(p, delta)
	if real == 0 and delta < 0:
		return
	var rig := rigs[p]
	FX.coins_burst(rig.global_position, absi(real), real > 0)
	Juice.float_text(self, rig.global_position + Vector3.UP * 2.8, ("+%d" % real) if real >= 0 else str(real),
		Color("#ffe066") if real >= 0 else Color("#ff6b6b"), 110)


func _pname(p: int) -> String:
	return Game.hero(Game.players[p].hero).name


func _any_human() -> bool:
	for p in Game.players:
		if not p.cpu:
			return true
	return false


func _wait(t: float) -> void:
	await get_tree().create_timer(t, false).timeout


func _ask(p: int, question: String, cpu_answer: bool) -> bool:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var root := UI.center_root(layer)
	var panel := UI.panel()
	root.add_child(panel)
	var v := UI.vbox(16)
	panel.add_child(v)
	var q := UI.label(question, 34, Color.WHITE, true)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(q)
	var h := UI.hbox(20)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	var yes := UI.button("Ja", Color("#2ecc71"), 32, 180)
	var no := UI.button("Nein", Color("#ff5c7a"), 32, 180)
	h.add_child(yes)
	h.add_child(no)
	var answer := [-1]
	yes.pressed.connect(func() -> void: answer[0] = 1)
	no.pressed.connect(func() -> void: answer[0] = 0)
	await get_tree().process_frame
	panel.position = Vector2((root.size.x - panel.size.x) / 2.0, root.size.y * 0.62)
	Juice.pop_in(panel, 0.3)
	var t := 0.0
	if not Game.players[p].cpu:
		yes.grab_focus()
	while answer[0] < 0:
		t += get_process_delta_time()
		if Game.players[p].cpu:
			if t > 0.8:
				answer[0] = 1 if cpu_answer else 0
				(yes if cpu_answer else no).emit_signal("pressed")
		elif t > 0.2:
			if InputHub.ui_pressed(p, "b"):
				answer[0] = 0
		await get_tree().process_frame
	_tap = false
	await _wait(0.15)
	layer.queue_free()
	return answer[0] == 1


func _show_banner(text: String, color := Color.WHITE, hold := 1.0) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.visible = true
	_banner.modulate.a = 1.0
	_banner.pivot_offset = _banner.size / 2.0
	_banner.scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.2)
	await tw.finished
	_banner.visible = false


func _set_prompt(text: String, action := "a") -> void:
	_prompt.action = action
	_prompt.set_text(text)
	_prompt.visible = text != ""
	if text != "":
		Juice.ui_punch(_prompt, 0.15, 0.3)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_hud = UI.center_root(layer)
	var corners := [Control.PRESET_TOP_LEFT, Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT]
	for i in 4:
		var b := PlayerBadge.new()
		b.setup(i, false, false)
		_hud.add_child(b)
		b.grow_horizontal = Control.GROW_DIRECTION_BEGIN if i % 2 == 1 else Control.GROW_DIRECTION_END
		b.grow_vertical = Control.GROW_DIRECTION_BEGIN if i >= 2 else Control.GROW_DIRECTION_END
		b.set_anchors_and_offsets_preset(corners[i], Control.PRESET_MODE_MINSIZE, 14)
		_badges.append(b)
	_round_label = UI.label("Runde %d / %d" % [Game.party.round, Game.party.max_rounds], 34, Color.WHITE, true, 10)
	_round_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_label.position = Vector2(-160, 14)
	_round_label.size = Vector2(320, 50)
	_hud.add_child(_round_label)
	if Game.party_mode() != "classic":
		_mode_label = UI.label("", 22, UI.GOLD, true, 8)
		_mode_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_mode_label.position = Vector2(-300, 58)
		_mode_label.size = Vector2(600, 30)
		_hud.add_child(_mode_label)
		EventBus.stars_changed.connect(func(_i: int, _v: int, _d: int) -> void: _refresh_mode_label())
		EventBus.coins_changed.connect(func(_i: int, _v: int, _d: int) -> void: _refresh_mode_label())
		_refresh_mode_label()
	_banner = UI.label("", 68, Color.WHITE, true, 14)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.position = Vector2(-600, -200)
	_banner.size = Vector2(1200, 100)
	_banner.visible = false
	_hud.add_child(_banner)
	_prompt = UI.prompt("a", "", 34)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-400, -120)
	_prompt.size = Vector2(800, 60)
	_prompt.visible = false
	_hud.add_child(_prompt)
	_ff_hint = UI.prompt("a", "halten: CPU vorspulen", 20)
	_ff_hint.modulate.a = 0.75
	_ff_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_ff_hint.position = Vector2(-200, -48)
	_ff_hint.size = Vector2(400, 30)
	_ff_hint.visible = false
	_hud.add_child(_ff_hint)
