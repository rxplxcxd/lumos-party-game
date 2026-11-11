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
var partners: PartnerSystem


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
	var bd: Array = {"dungeon": ["dungeon", Color("#1a0d1a")], "pirates": ["beach", Color("#e8d6a0")], "sky": ["sky", Color.WHITE],
		"graveyard": ["night", Color("#2d3a35")], "frost": ["snow", Color("#eef4fb")], "station": ["sky_dusk", Color.WHITE],
		"glowforest": ["meadow", Color("#4f9a46")], "meadow": ["meadow", Color("#86d06a")], "cake": ["cake", Color("#f6c9d8")],
		"tower": ["sky", Color.WHITE]}.get(Game.party.board, ["meadow", Color("#7cc860")])
	WorldKit.backdrop(self, String(bd[0]), bd[1], -0.56)
	var pts: Array[Vector3] = []
	var top := 0.0
	for sp in spaces:
		pts.append(sp.pos as Vector3)
		top = maxf(top, (sp.pos as Vector3).y)
	var life := CritterLife.populate(self, String(bd[0]), Vector3.ZERO, 0.0, 0.0, 12, pts)
	if life:
		life.y_min = -2.0
		life.y_max = top + 3.0
		life.max_walk = 4.5
	if bool(BoardDefs.get_def(Game.party.board).get("daynight", false)):
		builder.apply_time_of_day(int(Game.party.round) % 2 == 0 and int(Game.party.round) > 1, self, false)
	partners = PartnerSystem.new(self)
	_spawn_players()
	cam = BoardCamera.new()
	add_child(cam)
	cam.overview_center = Vector3(0, 0, 1)
	if bool(def.get("vertical", false)):
		cam.radial = true
		cam.orbit_overview = true
		cam.overview_center = Vector3(0, float(def.helix.h) * 0.42, 0)
		cam.overview_offset = Vector3(0, 10.0, 58.0)
	cam.make_current()
	cam.snap_overview()
	_build_hud()
	Audio.music(def.music)
	InputHub.set_touch_profile("board")
	_apply_routes(false)
	_place_star_node()
	partners.restore_visuals()
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
	match String(party.phase):
		"minigame":
			await _apply_minigame_results()
			party.round += 1
			party.turn = 0
			partners.expire_round()
			if party.round > party.max_rounds:
				await _finale()
				return
		"partner_game":
			await _after_partner_game()
		"duel_game":
			await _after_duel()
		"boss_game":
			await _after_boss()
		"showdown":
			if await _after_showdown_stage():
				return
	party.phase = "turns"
	if "--test-roulette" in OS.get_cmdline_user_args():
		await _choose_minigame()
		return
	while true:
		await _round_start()
		if String(party.phase) != "turns":
			return
		for t in range(int(party.turn), 4):
			party.turn = t
			await _turn(t)
			if String(party.phase) != "turns":
				return   # Zug für ein Partner-/Duell-Minispiel unterbrochen
		party.turn = 0
		await _choose_minigame()
		return


func _round_start() -> void:
	var party: Dictionary = Game.party
	var r: int = party.round
	if int(party.get("round_started", 0)) == r:
		cam.overview = true
		return
	party.round_started = r
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
	# Zauberwald: Tag/Nacht-Wechsel jede Runde (ungerade = Tag, gerade = Nacht)
	if bool(BoardDefs.get_def(Game.party.board).get("daynight", false)) and r > 1:
		var night := r % 2 == 0
		await _show_banner("Die Nacht bricht herein…" if night else "Ein neuer Morgen!", Color("#c9b5ff") if night else Color("#ffe27a"), 0.9)
		Audio.sfx("bell", null, -4.0, 0.7 if night else 1.15)
		builder.apply_time_of_day(night, self)
		await _wait(1.0)
	# Wechselnde Routen: Wer auf einer gleich schließenden Abkürzung steht, wird zuerst gerettet
	await _rescue_from_closing_routes()
	if _apply_routes(true):
		await _wait(1.2)
	if int(party.star_space) < 0:
		await _relocate_star(-1, true)
	# Endspurt: Start-Ereignis + Showdown (Dreikampf)
	if _is_endspurt() and not bool(party.get("endspurt_done", false)):
		party.endspurt_done = true
		await _endspurt_start()
		if String(party.phase) != "turns":
			return
	# Boss-Alarm zur Brettmitte
	var boss_round := maxi(2, int(ceil(int(party.max_rounds) / 2.0)))
	if r == boss_round and not bool(party.get("boss_done", false)) and Game.party_mode() != "blitz":
		party.boss_done = true
		await _start_boss()
		return
	await partners.maybe_spawn()


func _turn(p: int) -> void:
	_current = p
	for i in 4:
		_badges[i].modulate = Color.WHITE if i == p else Color(0.75, 0.75, 0.8)
	Juice.ui_punch(_badges[p], 0.2, 0.4)
	EventBus.turn_started.emit(p)
	Audio.sfx("ding", null, -6.0, 0.95 + p * 0.08, 0.0)
	var rig := rigs[p]
	cam.target = rig
	cam.overview = false
	cam.zoom = 1.0
	_ff_hint.visible = Game.players[p].cpu and _any_human()
	await _show_banner("%s ist dran!" % _pname(p), Game.player_color(p), 0.9)
	rig.turn_to(cam.global_position - rig.global_position, 0.3)
	rig.react("determined")
	await _wait(0.6)
	var dice := 2 if Game.party_mode() == "blitz" else 1
	var items: Array = Game.players[p].items
	if "double_dice" in items:
		var use := await _ask(p, "Doppelwürfel benutzen?", true)
		if use:
			items.erase("double_dice")
			dice += 1
	await partners.turn_start(p)
	var total := 0
	for k in dice:
		total += await _roll_dice(p, k, dice)
	var mod := partners.modify_roll(p, total)
	if mod != total:
		await _show_banner("%s: %d → %d Felder!" % [PartnerSystem.PARTNERS[partners.partner_of(p)].name, total, mod], Color("#ffd23f"), 0.8)
		total = mod
	Game.players[p].last_roll = total
	Game.players[p].dice_total = int(Game.players[p].get("dice_total", 0)) + total
	await _move(p, total)
	if String(Game.party.phase) != "turns":
		_ff_hint.visible = false
		return
	await _land(p)
	await partners.check_trap(p)
	await _maybe_duel(p)
	if String(Game.party.phase) != "turns":
		return
	partners.turn_end(p)
	_debug_digest("Zug %d" % p)
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
	_set_prompt("Würfeln!" if _local_human(p) else "")
	var value := 1
	var t := 0.0
	var wait_cpu := randf_range(0.7, 1.4)
	var tick := 0.0
	var n := _next_decision()
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
		if not _decides_here(p):
			if Net.decisions.has(n):
				value = int(Net.decisions[n])
				break
			_wait_hint(p, t)
		elif Game.players[p].cpu:
			if t > wait_cpu:
				break
		elif t > 0.25 and (InputHub.ui_pressed(p, "a") or _tap_consume()):
			break
		await get_tree().process_frame
	_publish(p, n, value)
	_set_prompt("")
	# Sprung gegen den Block: Ausholen → Absprung → Flug (Luft-Pose) → Treffer → Fall → Landung → Stand
	rig.play("jump_start", 0.1, 1.4, true)
	await rig.anticipate(0.35, 0.09).step_finished
	Audio.sfx("jump", rig.global_position)
	rig.hop(1.4, 0.42)
	get_tree().create_timer(0.1, false).timeout.connect(func() -> void:
		if is_instance_valid(rig):
			rig.play("jump_air", 0.12))
	get_tree().create_timer(0.42, false).timeout.connect(func() -> void:
		if is_instance_valid(rig):
			rig.play("land", 0.06, 1.4, true)
			rig.land_impact(0.5)
			get_tree().create_timer(0.2, false).timeout.connect(func() -> void:
				if is_instance_valid(rig) and rig.current == "land":
					rig.play("idle", 0.28)))
	await _wait(0.17)
	Audio.sfx("dice_hit", holder.global_position)
	Audio.sfx("plop", null, -4.0, 1.1, 0.05)
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


## Abkürzungen, die in dieser Runde schließen: Spieler darauf fliegt die Hummel Summsi zurück an die
## Abzweigung auf dem Hauptweg (kein Vorteil, niemand bleibt in versinkenden Feldern stecken).
func _rescue_from_closing_routes() -> void:
	var states: Dictionary = Game.party.get("route_states", {})
	for bi in def.branches.size():
		var br: Dictionary = def.branches[bi]
		if br.get("toggle", "") == "" or _route_open(bi) or states.get(bi, true) == false:
			continue
		for p in 4:
			var sid: int = Game.players[p].space
			if sid < 0 or int(spaces[sid].branch) != bi:
				continue
			await _helper_rescue(p, _branch_junction(sid))


## Hauptweg-Feld, an dem die Abkürzung des Feldes sid abzweigt.
func _branch_junction(sid: int) -> int:
	var cur := sid
	var guard := 0
	while int(spaces[cur].branch) >= 0 and guard < 64:
		cur = int(spaces[cur].prev[0])
		guard += 1
	return cur


func _helper_rescue(p: int, target: int) -> void:
	var rig := rigs[p]
	cam.overview = false
	cam.target = rig
	cam.zoom = 1.2
	await _show_banner("Die Abkürzung schließt sich!", Color("#ffcc33"), 0.8)
	var bee := CharacterRig.new()
	add_child(bee)
	bee.setup("pet/bee", -1, 2.0)
	var start := rig.position
	bee.position = start + Vector3(-6, 9, 3)
	bee.play("idle")
	bee.face_now(start - bee.position)
	Audio.sfx("whoosh", start, -4.0, 1.2)
	var tw := bee.create_tween()
	tw.tween_property(bee, "position", start + Vector3(0, 2.3, 0), 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	rig.react("cheer")
	Audio.sfx("woop", start, -2.0)
	await _show_banner("Summsi trägt %s zurück zur Abzweigung!" % _pname(p), Color("#ffe27a"), 0.9)
	# Gemeinsam im Bogen zur Abzweigung fliegen
	var a := rig.position
	var b := _space_pos(target)
	var fly := create_tween()
	fly.tween_method(func(t: float) -> void:
		rig.position = a.lerp(b, t) + Vector3.UP * sin(t * PI) * 5.0
		bee.position = rig.position + Vector3(0, 2.3, 0), 0.0, 1.0, 1.4).set_trans(Tween.TRANS_SINE)
	bee.face_now(b - a)
	await fly.finished
	rig.position = b
	rig.land_impact(0.8)
	FX.stars(rig.global_position + Vector3.UP * 1.5, Color(1, 0.9, 0.4), 10)
	Audio.sfx("plop", null, -2.0)
	Game.players[p].space = target
	var away := bee.create_tween()
	away.tween_property(bee, "position", bee.position + Vector3(8, 10, -4), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	away.tween_callback(bee.queue_free)
	_formation_all()
	cam.zoom = 1.0
	await _wait(0.6)


## Wendet Routen-Zustände an. Gibt true zurück, wenn sich etwas geändert hat (mit Kamerafahrt).
func _apply_routes(animate: bool) -> bool:
	var changed := false
	var states: Dictionary = Game.party.get("route_states", {})
	for bi in def.branches.size():
		var br: Dictionary = def.branches[bi]
		if br.get("toggle", "") == "":
			continue
		var open := _route_open(bi)
		if not open:
			# Sicherheitsnetz (z. B. alter Spielstand): niemand darf auf einem geschlossenen Feld stehen
			for p in 4:
				var sid: int = Game.players[p].space
				if sid >= 0 and int(spaces[sid].branch) == bi:
					Game.players[p].space = _branch_junction(sid)
					rigs[p].position = _space_pos(Game.players[p].space)
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
		await _hop(p, cur, nxt, remaining == steps, remaining == 1)
		cur = nxt
		Game.players[p].space = cur
		remaining -= 1
		counter.text = str(remaining) if remaining > 0 else ""
		Juice.squash(counter, 1.3, 1.3, 0.25)
		# Durchgangs-Events
		if partners.on_pass(p, cur):
			counter.queue_free()
			await _start_partner_game(p)
			return
		if cur == int(Game.party.star_space):
			await _star_event(p)
		elif spaces[cur].type == "Z":
			await _summit(p)
		elif spaces[cur].type == "N" and remaining > 0:
			await _shop(p)
	counter.queue_free()


## Ein Feld weiter hüpfen. first/last: Anlauf beim ersten Hüpfer, Abbremsen + Landen beim letzten –
## dazwischen gleichmäßiger Lauf-Rhythmus; Richtungswechsel werden weich gedreht statt umgeschnappt.
func _hop(p: int, from: int, to: int, first := false, last := false) -> void:
	var rig := rigs[p]
	if spaces[from].type == "Z" and int(spaces[to].branch) < 0 and to == 0:
		await _rainbow_slide(p)
		return
	var a := rig.position
	var b := _space_pos(to)
	rig.turn_to(b - a, 0.14 if not first else 0.2)
	rig.play("run", 0.22 if first else 0.15, 1.15 if first else 1.3)
	var dur := 0.36 if first else (0.34 if last else 0.3)
	var height := 0.5 if first else 0.6
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		rig.position = a.lerp(b, t) + Vector3.UP * sin(t * PI) * height, 0.0, 1.0, dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN if first else (Tween.EASE_OUT if last else Tween.EASE_IN_OUT))
	await tw.finished
	FX.step(rig.global_position, surface, 0.9, true)
	Audio.sfx("tick", null, -10.0, 1.2)
	if last:
		rig.squash(1.22, 0.8, 0.3)
		rig.play("land", 0.08, 1.4, true)
		rig.lock(0.18)
		get_tree().create_timer(0.18, false).timeout.connect(func() -> void:
			if is_instance_valid(rig) and rig.current == "land":
				rig.play("idle", 0.28))
	else:
		rig.squash(1.12, 0.9, 0.2)


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
	_set_prompt("Weg wählen (Stick links/rechts)" if _local_human(p) else "")
	var n := _next_decision()
	while chosen < 0:
		var dt := get_process_delta_time()
		t += dt
		for i in arrows.size():
			var s := 1.0 + (0.25 + sin(t * 8.0) * 0.12 if i == sel else 0.0)
			arrows[i].scale = arrows[i].scale.lerp(Vector3.ONE * s, clampf(dt * 12.0, 0, 1))
		if not _decides_here(p):
			if Net.decisions.has(n):
				sel = clampi(int(Net.decisions[n]), 0, options.size() - 1)
				chosen = options[sel]
			_wait_hint(p, t)
		elif Game.players[p].cpu:
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
	_publish(p, n, sel)
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
	Game.players[p].last_color = _space_color(t)
	if _space_color(t) == "green":
		Game.players[p].events_landed = int(Game.players[p].get("events_landed", 0)) + 1
	EventBus.space_landed.emit(p, t)
	rig.turn_to(cam.global_position - rig.global_position, 0.3)
	var node := builder.space_nodes[s]
	Juice.squash(node, 1.15, 0.7, 0.4, node.scale)
	match t:
		"B", "S":
			if _high_up(s):
				await _show_banner("Höhenbonus! ×2", Color("#ffd23f"), 0.6)
			_coins(p, 3 * partners.mult(p) * (2 if _is_endspurt() else 1) * (2 if _high_up(s) else 1))
			rig.react("coin_gain")
			await _wait(1.0)
		"R":
			if String(Game.party.get("endspurt_event", "")) == "lucky_red":
				_coins(p, 3 * partners.mult(p))
				rig.react("coin_gain")
			else:
				_coins(p, -3 * partners.mult(p) * (2 if _is_endspurt() else 1) * (2 if _high_up(s) else 1))
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
		"D":
			await _duel_space(p)
		"U":
			await _updraft(p)
	_formation_all()


## Wolkenturm: Felder im oberen Drittel zählen doppelt (Höhenbonus).
func _high_up(s: int) -> bool:
	return bool(def.get("vertical", false)) and (spaces[s].pos as Vector3).y > float(def.helix.h) * 0.66


## Wolkenturm: Aufwind trägt 3–6 Felder nach oben.
func _updraft(p: int) -> void:
	var rig := rigs[p]
	await _show_banner("Aufwind!", Color("#7ed957"), 0.6)
	var n := Game.prng.randi_range(3, 6)
	var target: int = Game.players[p].space
	for _i in n:
		target = int(_available_next(target)[0])
		if spaces[target].type == "Z":
			break
	Audio.sfx("whoosh", rig.global_position, 0.0, 0.8)
	Audio.sfx("sparkle_up", null, -6.0)
	rig.react("launch")
	FX.dust(rig.global_position, Color(0.8, 1.0, 0.85), 14, 1.0)
	var a := rig.position
	var b := _space_pos(target)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		rig.position = a.lerp(b, t) + Vector3.UP * sin(t * PI) * 4.0
		rig.rotation.y = t * TAU * 2.0, 0.0, 1.0, 1.2).set_trans(Tween.TRANS_SINE)
	await tw.finished
	rig.land_impact(1.0)
	Game.players[p].space = target
	await _wait(0.4)
	if spaces[target].type == "Z":
		await _summit(p)
	elif target == int(Game.party.star_space):
		await _star_event(p)


## Wolkenturm: Gipfel erreicht → Gipfelstern (gratis) + Jubel; danach geht es per Regenbogen-Rutsche hinab.
func _summit(p: int) -> void:
	var rig := rigs[p]
	cam.overview = false
	cam.target = rig
	cam.zoom = 0.8
	Audio.jingle("star")
	Audio.sfx("sparkle_up", null, -2.0)
	FX.confetti(rig.global_position + Vector3.UP * 2.0, 90)
	FX.stars(rig.global_position + Vector3.UP * 2.0, Color(1, 0.9, 0.4), 30)
	rig.react("star_get")
	Game.add_stars(p, 1)
	Game.players[p].summits = int(Game.players[p].get("summits", 0)) + 1
	await _show_banner("%s erreicht den Gipfel! +1 Stern" % _pname(p), UI.GOLD, 1.4)
	cam.zoom = 1.0


func _rainbow_slide(p: int) -> void:
	var rig := rigs[p]
	var h := float(def.helix.h)
	var R := float(def.helix.r)
	Audio.sfx("whistle_fall", rig.global_position, -2.0, 0.9)
	Audio.sfx("woop", null, -4.0, 0.8)
	rig.react("cheer")
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var a := -TAU * 2.0 * t + PI
		rig.position = Vector3(sin(a) * (R + 4.2), h * (1.0 - t) + 0.2, cos(a) * (R + 4.2))
		rig.rotation.y = a + PI * 0.5, 0.0, 1.0, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	FX.sparks(rig.global_position, Color(1, 0.8, 1.0), 16)
	var b := _space_pos(0)
	var t2 := create_tween()
	t2.tween_property(rig, "position", b, 0.4).set_trans(Tween.TRANS_QUAD)
	await t2.finished
	rig.land_impact(1.2)
	Audio.sfx("plop", null, -2.0)


## Brettspezifische Namen der Ereignisfelder.
func _event_name(t: String) -> String:
	var b: String = Game.party.board
	match t:
		"E":
			return "Schoko-Rutsche!" if b == "cake" else "Eis-Rutsche!"
		"W":
			return {"glowforest": "Feenring!", "station": "Sternen-Tor!"}.get(b, "Warp-Blume!")
		"T":
			return {"cake": "Kerzen-Falle!", "tower": "Windböe!"}.get(b, "Fackel-Falle!")
		"K":
			return {"station": "Raketen-Start!", "meadow": "Pusteblumen-Flug!"}.get(b, "Wolken-Kanone!")
	return ""


## Duell-Feld: Gegner wählen und im Duell-Minispiel um 10 Münzen spielen.
func _duel_space(p: int) -> void:
	await _show_banner("Duell-Feld!", Color("#ff9f1a"), 0.8)
	var foes: Array[int] = []
	for o in 4:
		if o != p:
			foes.append(o)
	var best := foes[0]
	for o in foes:
		if int(Game.players[o].coins) > int(Game.players[best].coins):
			best = o
	var foe: int = await _pick_player(p, "Wen forderst du heraus?", foes, best)
	if foe < 0:
		return
	await _start_duel(p, foe, "coins")


func _pick_player(p: int, question: String, options: Array[int], cpu_choice: int) -> int:
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
	var h := UI.hbox(16)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	var answer := [-1]
	var btns: Array[Button] = []
	for o in options:
		var b := UI.button("%s\n%d Münzen" % [_pname(o), int(Game.players[o].coins)], Game.player_color(o), 26, 200)
		b.custom_minimum_size.y = 96
		h.add_child(b)
		btns.append(b)
		var oo: int = o
		b.pressed.connect(func() -> void: answer[0] = oo)
	await get_tree().process_frame
	panel.position = Vector2((root.size.x - panel.size.x) / 2.0, root.size.y * 0.58)
	Juice.pop_in(panel, 0.3)
	if _local_human(p):
		btns[options.find(cpu_choice)].grab_focus()
	else:
		for b in btns:
			b.disabled = not _decides_here(p)
	var t := 0.0
	var n := _next_decision()
	while answer[0] < 0:
		t += get_process_delta_time()
		if not _decides_here(p):
			if Net.decisions.has(n):
				answer[0] = int(Net.decisions[n])
			_wait_hint(p, t)
		elif Game.players[p].cpu and t > 1.0:
			answer[0] = cpu_choice
			btns[options.find(cpu_choice)].emit_signal("pressed")
		await get_tree().process_frame
	_publish(p, n, answer[0])
	_set_prompt("")
	_tap = false
	await _wait(0.2)
	layer.queue_free()
	return answer[0]


func _torch_trap(p: int) -> void:
	var rig := rigs[p]
	await _show_banner(_event_name("T"), Color("#ffb070"), 0.7)
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
	await _show_banner(_event_name("K"), Color("#7fd6ff"), 0.7)
	var cur: int = Game.players[p].space
	var jumps := Game.prng.randi_range(5, 12)
	var target := cur
	for i in jumps:
		target = _available_next(target)[Game.prng.randi() % _available_next(target).size()]
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
	var forest: bool = Game.party.board == "glowforest"
	await _show_banner("Hummel-Taxi!" if forest else "Geister-Taxi!", Color("#ffe27a") if forest else Color("#9dffc8"), 0.7)
	var ghost := CharacterRig.new()
	add_child(ghost)
	ghost.setup("pet/bee" if forest else "npc/ghost", -1, 2.2 if forest else 1.6)
	var start := rig.position
	ghost.position = start + Vector3(0, 7, -2)
	ghost.play("idle")
	Audio.sfx("whoosh" if forest else "ghost", start)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "position", start + Vector3(0, 1.9, 0), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	rig.react("scared")
	InputHub.rumble(p, 0.5, 0.2)
	await _wait(0.6)
	var forward := Game.prng.randf() < 0.6
	var n := Game.prng.randi_range(2, 6) if forward else Game.prng.randi_range(2, 4)
	var target: int = Game.players[p].space
	for _i in n:
		if forward:
			var opts := _available_next(target)
			target = opts[Game.prng.randi() % opts.size()]
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
	await _show_banner(_event_name("E"), Color("#c98d5a") if Game.party.board == "cake" else Color("#bfefff"), 0.7)
	if Game.prng.randf() < 0.3:
		rig.react("slip")
		Audio.sfx("boing", rig.global_position)
		InputHub.rumble(p, 0.6, 0.2)
		await _wait(1.1)
		_coins(p, -2)
		await _show_banner("Ausgerutscht! -2 Münzen", Color("#ff9db0"), 0.8)
		return
	var n := Game.prng.randi_range(2, 4)
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
	await _show_banner(_event_name("W"), Color("#d9a8ff") if Game.party.board == "glowforest" else Color("#ffe27a"), 0.7)
	var target: int = pads[Game.prng.randi() % pads.size()]
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
	_set_prompt("Stopp!" if _local_human(p) else "")
	var t := 0.0
	var stop_at := randf_range(1.2, 2.2)
	var n := _next_decision()
	while not wheel.stopping:
		t += get_process_delta_time()
		var stop_now := false
		if not _decides_here(p):
			if Net.decisions.has(n):
				wheel.stop_on(int(Net.decisions[n]))
			_wait_hint(p, t)
		elif Game.players[p].cpu and t > stop_at:
			stop_now = true
		elif not Game.players[p].cpu and t > 0.4 and (InputHub.ui_pressed(p, "a") or _tap_consume()):
			stop_now = true
		if stop_now:
			var land := wheel.predict_stop()
			_publish(p, n, land)
			wheel.stop_on(land)
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
	var price := DOUBLE_DICE_COST / (2 if partners.has_ability(p, "shop_half") else 1)
	if Game.party_mode() == "pro" and int(Game.party.get("shop_stock", 2)) <= 0:
		return
	if "double_dice" in Game.players[p].items or Game.players[p].coins < price:
		return
	if builder.merchant:
		builder.merchant.react("wave")
	var cpu_buy: bool = Game.players[p].coins >= price + 12
	var buy := await _ask(p, "Händler: Doppelwürfel für %d Münzen?" % price, cpu_buy)
	if buy:
		_coins(p, -price)
		if Game.party_mode() == "pro":
			Game.party.shop_stock = int(Game.party.get("shop_stock", 2)) - 1
		Game.players[p].items.append("double_dice")
		Audio.sfx("item_get")
		rigs[p].react("cheer")
		if builder.merchant:
			builder.merchant.react("cheer")
		await _wait(0.8)


func _star_event(p: int) -> void:
	var rig := rigs[p]
	cam.zoom = 0.85
	var cost := _star_cost(p)
	if partners.partner_of(p) != "" and Game.players[p].coins >= cost * 2:
		var two := await _ask(p, "Mit Partner: 2 Sterne für %d Münzen kaufen?" % (cost * 2), true)
		if two:
			_coins(p, -cost * 2)
			Game.add_stars(p, 2)
			FX.confetti(rig.global_position + Vector3.UP * 2.0, 80)
			Audio.jingle("star")
			rig.react("star_get")
			await _show_banner("Doppel-Stern für %s!" % _pname(p), UI.GOLD, 1.2)
			await _relocate_star(int(Game.party.star_space))
			cam.zoom = 1.0
			return
	if Game.players[p].coins < cost:
		await _show_banner("Zu wenig Münzen für den Stern!", Color("#ff6b6b"), 1.0)
		rig.react("sad")
		await _wait(0.8)
		cam.zoom = 1.0
		return
	var buy := await _ask(p, "Lumos-Stern für %d Münzen kaufen?" % cost, true)
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
	var s: int = cands[Game.prng.randi() % cands.size()]
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

# --- Endspurt, Boss, Partner-, Duell- & Showdown-Minispiele ----------------------------------------------

func _endspurt_len() -> int:
	var mr := int(Game.party.max_rounds)
	if Game.party_mode() == "blitz":
		return mr
	return 2 if mr <= 5 else (3 if mr <= 10 else 5)


func _is_endspurt() -> bool:
	return int(Game.party.round) > int(Game.party.max_rounds) - _endspurt_len()


## Minispiel starten und danach zum Brett zurück (Phase bestimmt die Auswertung).
func _launch(game_id: String, setup: Dictionary, phase: String) -> void:
	var info := Game.minigame_info(game_id)
	setup["game"] = game_id
	Game.minigame_setup = setup
	Game.party.last_setup = setup
	Game.party.phase = phase
	Game.pending_minigame = game_id
	await _wait(0.4)
	Router.goto(info.scene)


func _endspurt_start() -> void:
	cam.overview = true
	Audio.voice("final_round")
	Audio.sfx("drumroll")
	await _show_banner("ENDSPURT!", Color("#ff4d6d"), 1.4)
	await _show_banner("Blaue und rote Felder zählen doppelt · Duelle auf gleichen Feldern", Color.WHITE, 1.4)
	if Game.party_mode() != "pro":
		var events := [["half_star", "Sterne zum halben Preis!"], ["lucky_red", "Rote Felder bringen jetzt Münzen!"], ["catch_up", "Aufholjagd: Letzter bekommt 15 Münzen!"]]
		var ev: Array = events[Game.prng.randi() % events.size()]
		Game.party.endspurt_event = ev[0]
		await _show_banner(String(ev[1]), Color("#ffd23f"), 1.4)
		if ev[0] == "catch_up":
			var lastp := Game.ranking()[3]
			_coins(lastp, 15)
			rigs[lastp].react("cheer")
	# Showdown: Lumos-Dreikampf um 20 Münzen
	var stages: Array = ["flower_rush", "plush_balls", "sleepy_stars"]
	Game.party.showdown = {"stage": 0, "games": stages, "points": [0, 0, 0, 0]}
	await _show_banner("Showdown: Lumos-Dreikampf!", UI.GOLD, 1.4)
	await _launch(stages[0], {"cat": "ffa", "short": true}, "showdown")


## Showdown-Stufe ausgewertet. true = nächste Stufe wurde gestartet.
func _after_showdown_stage() -> bool:
	var sd: Dictionary = Game.party.get("showdown", {})
	var res: Dictionary = Game.last_results
	if not res.is_empty():
		var pl: Array = res.placements
		for i in 4:
			sd.points[i] = int(sd.points[i]) + [3, 2, 1, 0][clampi(int(pl[i]) - 1, 0, 3)]
		Game.last_results = {}
	sd.stage = int(sd.stage) + 1
	cam.overview = true
	var pts: Array = sd.points
	await _show_banner("Dreikampf: %s" % " · ".join(range(4).map(func(i: int) -> String: return "%s %d" % [Game.hero(Game.players[i].hero).name.get_slice(" ", 0), int(pts[i])])), Color.WHITE, 1.6)
	if int(sd.stage) < (sd.games as Array).size():
		await _launch(String(sd.games[int(sd.stage)]), {"cat": "ffa", "short": true}, "showdown")
		return true
	var best := 0
	for i in 4:
		if int(pts[i]) > int(pts[best]):
			best = i
	cam.overview = false
	cam.target = rigs[best]
	rigs[best].react("victory")
	FX.confetti(rigs[best].global_position + Vector3.UP * 2.0, 80)
	Audio.jingle("win")
	await _show_banner("%s gewinnt den Dreikampf! +20 Münzen" % _pname(best), UI.GOLD, 1.6)
	_coins(best, 20)
	await _wait(1.0)
	Game.party.erase("showdown")
	return false


func _start_boss() -> void:
	cam.overview = true
	var bid := BossDefs.for_board(String(Game.party.board))
	var bdef := BossDefs.get_def(bid)
	Audio.sfx("thunder", null, -4.0, 1.2)
	Juice.shake(0.4)
	await _show_banner("BOSS-ALARM! %s greift an!" % bdef.name, Color("#c9b5ff"), 1.6)
	await _show_banner(String(bdef.title), Color.WHITE, 1.0)
	await _launch("boss_battle", {"cat": "boss", "boss": bid}, "boss_game")


func _after_boss() -> void:
	var res: Dictionary = Game.last_results
	cam.overview = true
	if not res.is_empty():
		var pl: Array = res.placements
		var cd: Array = res.get("coin_delta", [0, 0, 0, 0])
		var steal: Array = res.get("item_steal", [0, 0, 0, 0])
		for i in 4:
			var reward: int = MinigameBase.reward_for(int(pl[i]), "boss") + int(cd[i])
			if bool(res.get("boss_defeated", false)) and int(pl[i]) > 0:
				reward += 5   # gemeinsamer Sieges-Bonus
			if reward != 0:
				_coins(i, reward)
			var items: Array = Game.players[i].get("items", [])
			for k in mini(int(steal[i]), items.size()):
				items.pop_back()
		Game.last_results = {}
		await _show_banner("Boss besiegt! Belohnung verteilt!" if bool(res.get("boss_defeated", false)) else "Der Boss ist entkommen – Belohnung nach Schaden.", UI.GOLD, 1.2)
	await partners.maybe_spawn()


func _start_partner_game(p: int) -> void:
	var trig: Dictionary = Game.party.get("partner_trigger", {})
	var id := String(trig.get("partner", ""))
	cam.overview = false
	cam.target = rigs[p]
	await _show_banner("%s erreicht %s – Partner-Minispiel!" % [_pname(p), PartnerSystem.PARTNERS[id].name], Color("#ffd23f"), 1.4)
	var pool: Array = []
	for m in Game.MINIGAMES:
		if "ffa" in (m.get("cats", []) as Array) and String(m.kind) != "race" and Game.minigame_allowed(m):
			pool.append(m)
	var pick: Dictionary = await _roulette(pool, "ffa")
	Game.party.turn = p
	await _launch(String(pick.id), {"cat": "ffa", "handicap": p}, "partner_game")


func _after_partner_game() -> void:
	var res: Dictionary = Game.last_results
	var winner := -1
	if not res.is_empty():
		var pl: Array = res.placements
		for i in 4:
			if int(pl[i]) == 1:
				winner = i if winner < 0 or i == int(Game.party.get("partner_trigger", {}).get("slot", -1)) else winner
		Game.last_results = {}
	_formation_all(true)
	await partners.award(winner)
	Game.party.turn = int(Game.party.turn) + 1


## Endspurt: Landet man auf einem besetzten Feld, gibt es ein Duell um 10 Münzen (Profi-Regeln: Stern möglich).
func _maybe_duel(p: int) -> void:
	if not _is_endspurt():
		return
	var s: int = Game.players[p].space
	var foe := -1
	for o in 4:
		if o != p and int(Game.players[o].space) == s:
			foe = o
	if foe < 0:
		return
	var stake := "coins"
	if Game.party_mode() == "pro" and int(Game.players[p].stars) > 0 and int(Game.players[foe].stars) > 0:
		var star_duel: bool = await _ask(p, "Duell! Um einen Stern kämpfen?", false)
		stake = "star" if star_duel else "coins"
	var duel: bool = await _ask(p, "Duell gegen %s um 10 Münzen?" % _pname(foe), true) if stake == "coins" else true
	if not duel:
		return
	await _start_duel(p, foe, stake)


func _start_duel(p: int, foe: int, stake: String) -> void:
	await CutsceneManager.play("TeamIntro", {"board": self, "setup": {"cat": "duel", "teams": _duel_teams(p, foe)}})
	await _show_banner("DUELL: %s gegen %s!" % [_pname(p), _pname(foe)], Color("#ff9f1a"), 1.2)
	var pool: Array = []
	for m in Game.MINIGAMES:
		if "duel" in (m.get("cats", []) as Array) and Game.minigame_allowed(m):
			pool.append(m)
	var pick: Dictionary = await _roulette(pool, "duel")
	var act := [false, false, false, false]
	act[p] = true
	act[foe] = true
	Game.party.duel = {"a": p, "b": foe, "stake": stake}
	Game.party.turn = p
	await _launch(String(pick.id), {"cat": "duel", "active": act}, "duel_game")


func _duel_teams(a: int, b: int) -> Array:
	var t := [-1, -1, -1, -1]
	t[a] = 0
	t[b] = 1
	return t


func _after_duel() -> void:
	var d: Dictionary = Game.party.get("duel", {})
	var res: Dictionary = Game.last_results
	_formation_all(true)
	if not res.is_empty() and not d.is_empty():
		var pl: Array = res.placements
		var a := int(d.a)
		var b := int(d.b)
		var win := a if int(pl[a]) < int(pl[b]) else (b if int(pl[b]) < int(pl[a]) else -1)
		if win >= 0:
			var lose := b if win == a else a
			cam.overview = false
			cam.target = rigs[win]
			if String(d.stake) == "star":
				Game.add_stars(lose, -1)
				Game.add_stars(win, 1)
				await _show_banner("%s gewinnt das Duell und einen Stern!" % _pname(win), UI.GOLD, 1.4)
			else:
				var n: int = -Game.add_coins(lose, -10)
				_coins(win, n)
				await _show_banner("%s gewinnt das Duell! +%d Münzen" % [_pname(win), n], UI.GOLD, 1.4)
			rigs[win].react("victory")
			rigs[lose].react("sad")
		else:
			await _show_banner("Unentschieden!", Color.WHITE, 1.0)
		Game.last_results = {}
	Game.party.erase("duel")
	Game.party.turn = int(Game.party.turn) + 1


## Farbe des zuletzt betretenen Feldes: blau | rot | grün (Ereignisfelder werden vor dem Minispiel zugelost).
static func _space_color(t: String) -> String:
	if t in ["B", "S"]:
		return "blue"
	if t in ["R", "T", "C"]:
		return "red"
	return "green"


## Bestimmt Kategorie und Teams nach den Feldfarben (wie im Vorbild).
func _team_setup() -> Dictionary:
	if Game.party_mode() == "team":
		return {"cat": "2v2", "teams": [0, 1, 0, 1]}
	var cols: Array = []
	for i in 4:
		cols.append(String(Game.players[i].get("last_color", "blue")))
	var greens: Array[int] = []
	for i in 4:
		if cols[i] == "green":
			greens.append(i)
	if not greens.is_empty():
		await _show_banner("Farbrad für Ereignisfelder!", Color("#7dff9a"), 0.8)
		for i in greens:
			var c := "blue" if Game.prng.randf() < 0.5 else "red"
			cols[i] = c
			Game.players[i].last_color = c
			var b: PlayerBadge = _badges[i]
			var tw := b.create_tween()
			for k in 6:
				tw.tween_property(b, "modulate", Color("#6fb8ff") if k % 2 == 0 else Color("#ff7a8a"), 0.08)
			tw.tween_property(b, "modulate", Color("#6fb8ff") if c == "blue" else Color("#ff7a8a"), 0.1)
			Audio.sfx("wheel_tick", null, -6.0)
			await tw.finished
	var blue: Array[int] = []
	var red: Array[int] = []
	for i in 4:
		if cols[i] == "blue":
			blue.append(i)
		else:
			red.append(i)
	for i in 4:
		_badges[i].create_tween().tween_property(_badges[i], "modulate", Color.WHITE, 0.4).set_delay(1.0)
	if blue.size() == 3 or red.size() == 3:
		var solo: int = red[0] if blue.size() == 3 else blue[0]
		return {"cat": "1v3", "solo": solo}
	if blue.size() == 2:
		var tm := [0, 0, 0, 0]
		for i in red:
			tm[i] = 1
		return {"cat": "2v2", "teams": tm}
	return {"cat": "ffa"}


func _choose_minigame() -> void:
	cam.overview = true
	_set_prompt("")
	var setup: Dictionary = await _team_setup()
	var cat: String = setup.cat
	var played: Array = Game.party.minigames_played
	var pool: Array = []
	for m in Game.MINIGAMES:
		if cat in (m.get("cats", ["ffa"]) as Array) and Game.minigame_allowed(m) and not (m.id in played.slice(maxi(0, played.size() - 4))):
			pool.append(m)
	if pool.is_empty():
		for m in Game.MINIGAMES:
			if cat in (m.get("cats", ["ffa"]) as Array) and Game.minigame_allowed(m):
				pool.append(m)
	if cat != "ffa":
		await CutsceneManager.play("TeamIntro", {"board": self, "setup": setup})
	var pick: Dictionary
	if Game.party_mode() == "pro":
		pick = await _vote_minigame(pool, cat)
	else:
		pick = await _roulette(pool, cat)
	played.append(pick.id)
	setup["game"] = pick.id
	Game.minigame_setup = setup
	Game.party.last_setup = setup
	Game.party.phase = "minigame"
	Game.pending_minigame = pick.id
	Router.goto(pick.scene)


func _roulette(pool: Array, cat: String) -> Dictionary:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var root := UI.center_root(layer)
	var panel := UI.panel()
	root.add_child(panel)
	var v := UI.vbox(10)
	panel.add_child(v)
	var catl := UI.label(MinigameBase.CATEGORY_LABELS.get(cat, "").to_upper(), 24, UI.ACCENT2, true, 8)
	catl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(catl)
	var title := UI.label("Minispiel-Roulette!", 52, UI.GOLD, true, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var names: Array = pool.map(func(m: Dictionary) -> String: return m.name)
	var palette := [Color("#ff4fb8"), Color("#2f9bff"), Color("#2ecc71"), Color("#ff9f1a"), Color("#c06bff")]
	var cols: Array = []
	for i in names.size():
		cols.append(palette[i % palette.size()])
	var reel := RouletteReel.new().setup(names, cols)
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
	var target := Game.prng.randi() % pool.size()
	await reel.spin_to(target, 3, 3.2)
	# Anzeige und geladenes Spiel sind identisch: wir laden exakt den Eintrag unter dem Zeiger
	var pick: Dictionary = pool[reel.current_index()]
	desc.text = pick.desc
	await get_tree().process_frame
	panel.create_tween().tween_property(panel, "position", (root.size - panel.size) / 2.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Audio.sfx("bell")
	Juice.ui_punch(reel, 0.12, 0.5)
	FX.confetti(cam.global_position + cam.global_basis.z * -12.0, 40)
	await _wait(1.6)
	return pick


## Profi-Regeln: drei Vorschläge, jeder stimmt ab (CPU zufällig), Mehrheit gewinnt (Gleichstand: Zufall).
func _vote_minigame(pool: Array, cat: String) -> Dictionary:
	var opts: Array = pool.duplicate()
	for k in range(opts.size() - 1, 0, -1):
		var j := Game.prng.randi() % (k + 1)
		var tmp: Variant = opts[k]
		opts[k] = opts[j]
		opts[j] = tmp
	opts = opts.slice(0, mini(3, opts.size()))
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var root := UI.center_root(layer)
	var panel := UI.panel()
	root.add_child(panel)
	var v := UI.vbox(12)
	panel.add_child(v)
	var t := UI.label("Abstimmung · %s" % MinigameBase.CATEGORY_LABELS.get(cat, ""), 40, UI.GOLD, true, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var rows: Array = []
	for o in opts:
		var row := UI.hbox(12)
		var nm := UI.label(String(o.name), 30, Color.WHITE, true)
		nm.custom_minimum_size.x = 420
		row.add_child(nm)
		var votes := UI.label("", 30, UI.GOLD, true)
		row.add_child(votes)
		v.add_child(row)
		rows.append([row, votes, 0])
	var hint := UI.prompt("a", "Stick: wählen · A: abstimmen", 22)
	v.add_child(hint)
	await get_tree().process_frame
	panel.position = (root.size - panel.size) / 2.0
	Juice.pop_in(panel, 0.35)
	var choice := [0, 0, 0, 0]
	var done := [false, false, false, false]
	var t_wait := 0.0
	var n0 := _next_decision()
	for _k in 3:
		_next_decision()
	while t_wait < 12.0 or (_online() and false in done):
		var all := true
		for i in 4:
			if done[i]:
				continue
			if not _decides_here(i):
				all = false
				if Net.decisions.has(n0 + i):
					choice[i] = clampi(int(Net.decisions[n0 + i]), 0, opts.size() - 1)
					done[i] = true
				continue
			if t_wait >= 12.0:
				done[i] = true
				_publish(i, n0 + i, choice[i])
				continue
			if Game.players[i].cpu:
				if t_wait > 0.6 + i * 0.4:
					choice[i] = randi() % opts.size()
					done[i] = true
					_publish(i, n0 + i, choice[i])
				else:
					all = false
				continue
			all = false
			var mv := InputHub.move(i)
			if absf(mv.y) > 0.6 and InputHub.ui_pressed(i, "a") == false and Engine.get_process_frames() % 8 == 0:
				choice[i] = clampi(choice[i] + (1 if mv.y > 0 else -1), 0, opts.size() - 1)
			if InputHub.ui_pressed(i, "a") or (i == _touch_slot() and _tap_consume()):
				done[i] = true
				_publish(i, n0 + i, choice[i])
				Audio.sfx("ui_confirm")
		for k in rows.size():
			var cnt := 0
			var marks := ""
			for i in 4:
				if choice[i] == k:
					marks += "●" if done[i] else "○"
					if done[i]:
						cnt += 1
			rows[k][2] = cnt
			(rows[k][1] as Label).text = marks
		if all:
			break
		await get_tree().process_frame
		t_wait += get_process_delta_time()
	var best := 0
	for k in rows.size():
		if int(rows[k][2]) > int(rows[best][2]) or (int(rows[k][2]) == int(rows[best][2]) and Game.prng.randf() < 0.5 and k != best):
			best = k
	Juice.ui_punch(rows[best][0], 0.2, 0.5)
	Audio.sfx("bell")
	await _wait(1.2)
	layer.queue_free()
	return opts[best]


func _apply_minigame_results() -> void:
	cam.overview = true
	var res: Dictionary = Game.last_results
	if res.is_empty():
		return
	var places: Array = res.placements
	await _show_banner("Minispiel-Belohnung", UI.GOLD, 0.9)
	var order := [0, 1, 2, 3]
	order.sort_custom(func(a: int, b: int) -> bool: return places[a] < places[b])
	var cat := String(res.get("cat", "ffa"))
	var scs: Array = res.get("scores", [0, 0, 0, 0])
	for p in order:
		if int(places[p]) <= 0:
			continue
		var reward: int = MinigameBase.reward_for(int(places[p]), cat, float(scs[p]))
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
	_debug_digest("nach Minispiel")
	cam.zoom = 1.0
	cam.overview = true
	await _wait(0.4)


# --- Finale ------------------------------------------------------------------------------------------------

func _finale() -> void:
	Game.party.phase = "final"
	cam.overview = true
	Audio.voice("game_over")
	await _show_banner("Das Spiel ist vorbei!", Color.WHITE, 1.4)
	# Bonus-Sterne (Profi-Regeln: Abenteuer-, Trödel- und Flitzer-Stern)
	var bonus := [["Minispiel-Star", "minigame_wins"], ["Münz-Star", "coins_max"]]
	if Game.party_mode() == "pro":
		bonus = [["Abenteuer-Stern (meiste Ereignisfelder)", "events_landed"], ["Flitzer-Stern (meiste Felder gewürfelt)", "dice_total"], ["Trödel-Stern (wenigste Felder gewürfelt)", "dice_low"]]
		for i in 4:
			Game.players[i].dice_low = 1000 - int(Game.players[i].get("dice_total", 0))
			Game.players[i].events_landed = int(Game.players[i].get("events_landed", 0))
	for b in bonus:
		var best := -1
		for i in 4:
			best = maxi(best, int(Game.players[i].get(b[1], 0)))
		if best <= 0:
			continue
		for i in 4:
			if int(Game.players[i].get(b[1], 0)) == best:
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
	if _online():
		Net.back_to_lobby()
		Game.mode = "online"
		Router.goto("res://scenes/menu/MainMenu.tscn", {"page": "online"})
		return
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


func _star_cost(p := -1) -> int:
	var c := 10 if Game.party_mode() == "blitz" else STAR_COST_DEFAULT
	if String(Game.party.get("endspurt_event", "")) == "half_star":
		c /= 2
	if p >= 0 and partners and partners.has_ability(p, "star_half"):
		c /= 2
	return c


func _coins(p: int, delta: int) -> void:
	var real := Game.add_coins(p, delta)
	if real == 0 and delta < 0:
		return
	var rig := rigs[p]
	Audio.coin_cascade(real, rig.global_position)
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


# --- Online-Lockstep ---------------------------------------------------------------------------------------
## Alle Geräte führen den Brettablauf identisch aus (gemeinsamer Brett-Zufall Game.prng). Jede Spieler-
## Entscheidung (Würfel, Weg, Ja/Nein, Glücksrad, Abstimmung …) bekommt eine fortlaufende Nummer. Wer den
## Slot besitzt (Mensch am eigenen Gerät, CPUs beim Host), entscheidet und verteilt das Ergebnis; die
## anderen Geräte zeigen dieselbe Animation und übernehmen genau diesen Wert.

func _online() -> bool:
	return Net.in_game()


## Dev-Test: Zustands-Fingerabdruck (muss auf allen Geräten identisch sein).
func _debug_digest(tag: String) -> void:
	if not ("--net-test" in str(OS.get_cmdline_user_args())):
		return
	var sp := []
	var co := []
	var st := []
	for i in 4:
		sp.append(int(Game.players[i].space))
		co.append(int(Game.players[i].coins))
		st.append(int(Game.players[i].stars))
	print("[NET] Brett R%d %s · Felder %s · Münzen %s · Sterne %s · Stern@%d · Entscheidungen %d" % [int(Game.party.round), tag, sp, co, st, int(Game.party.star_space), int(Game.party.get("dseq", 0))])


func _next_decision() -> int:
	var n := int(Game.party.get("dseq", 0))
	Game.party.dseq = n + 1
	return n


## Wird die Entscheidung für Slot p auf diesem Gerät getroffen?
func _decides_here(p: int) -> bool:
	return not _online() or Net.owns_slot(p)


## Spielt an diesem Gerät ein Mensch für Slot p?
func _local_human(p: int) -> bool:
	return not Game.players[p].cpu and _decides_here(p)


func _publish(p: int, n: int, v: Variant) -> void:
	if _online() and _decides_here(p):
		Net.decide_send(n, v)


## Touch-Eingabe (Tippen) gehört offline Spieler 1, online dem eigenen Slot.
func _touch_slot() -> int:
	return Net.my_slot if _online() else 0


func _wait_hint(p: int, t: float) -> void:
	if t > 2.0 and not _prompt.visible and not Game.players[p].cpu:
		_set_prompt("Warte auf %s …" % _pname(p), "")


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
	var n := _next_decision()
	var here := _decides_here(p)
	if not here:
		yes.disabled = true
		no.disabled = true
	if _local_human(p):
		yes.grab_focus()
	while answer[0] < 0:
		t += get_process_delta_time()
		if not _decides_here(p):
			if Net.decisions.has(n):
				answer[0] = int(Net.decisions[n])
				Juice.ui_punch(yes if answer[0] == 1 else no, 0.2, 0.3)
			_wait_hint(p, t)
		elif Game.players[p].cpu:
			if t > 0.8:
				answer[0] = 1 if cpu_answer else 0
				(yes if cpu_answer else no).emit_signal("pressed")
		elif t > 0.2:
			if InputHub.ui_pressed(p, "b"):
				answer[0] = 0
		await get_tree().process_frame
	_publish(p, n, answer[0])
	_set_prompt("")
	_tap = false
	await _wait(0.15)
	layer.queue_free()
	return answer[0] == 1


func _show_banner(text: String, color := Color.WHITE, hold := 1.0) -> void:
	_banner.text = text
	UI.fit_label(_banner, 68, minf(_banner.size.x, get_viewport().get_visible_rect().size.x * 0.92), 22)
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
