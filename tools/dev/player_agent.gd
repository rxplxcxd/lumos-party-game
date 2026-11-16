extends Node
## Lumos Player Agent – spielt ein Minispiel als MENSCH auf Platz 1 über echte Tastatur-Ereignisse
## (Input.parse_input_event → InputHub → Spiel: derselbe Weg wie ein Spieler am Gerät). Die drei anderen Plätze sind
## CPU-Gegner. Anders als der CPU-Sweep prüft das die Steuerung selbst: Kommen Eingaben an, reagiert die Figur,
## lohnt sich gutes Spielen gegenüber Nichtstun, übersteht das Spiel Unsinn-Eingaben, kommt man mit A durch
## Erklärung und Ergebnis?
##
##   godot --headless --fixed-fps 60 --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/player_agent.gd
##       --only=<minispiel> [--cat=ffa|2v2|duel|1v3|…] [--strategy=mimic|idle|random|mash] [--seed=1] [--level=1]
##
## Strategien:
##   mimic   spielt mit dem Verstand der CPU dieses Spiels (cpu_think für Platz 1), aber über die Tastatur:
##           8 Richtungen statt Analogstick, Tasten als Tasten – so gut wie ein geübter Tastaturspieler
##   idle    fasst nichts an (AFK): Das Spiel muss trotzdem sauber enden; Nichtstun darf nicht gewinnen
##   random  drückt zufällig Richtungen und Tasten (Kleinkind am Controller): nichts darf abstürzen oder hängen
##   mash    läuft Kreise und hämmert abwechselnd A/B/X/Y (Button-Masher)
##
## Ausgabe: eine Zeile „AGENT {json}“ – Ende, Spielzeit, Platz/Punkte von Platz 1, zurückgelegter Weg, Reaktionszeit
## der Figur auf die erste Eingabe, längstes Bild (CPU), Objektzuwachs, ob Erklärung und Ergebnis per A weitergehen.
## Alle Spiele und Auswertung: tools/dev/player_agent.sh, tools/dev/agent_report.py

const KEYMAP := {"a": KEY_J, "b": KEY_K, "x": KEY_L, "y": KEY_I, "r": KEY_SHIFT, "l": KEY_TAB}
const MOVE_KEYS := {"l": KEY_A, "r": KEY_D, "u": KEY_W, "d": KEY_S}

var _down := {}          # Keycode → gedrückt
var _rng := RandomNumberGenerator.new()
var _rand_t := 0.0
var _rand_mv := Vector2.ZERO
var _rand_btn := {}
var _mash_t := 0.0
var presses := 0
var _flick_t := 0


func _key(code: Key, on: bool) -> void:
	if bool(_down.get(code, false)) == on:
		return
	_down[code] = on
	if on:
		presses += 1
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = on
	Input.parse_input_event(ev)


func _release_all() -> void:
	for code: Key in _down.keys():
		_key(code, false)


var _pwm := Vector2.ZERO


## Eingabe als Tastatur anwenden: Analogrichtung → 8 Richtungen, gehaltene Aktionen → Tasten. Kleine Ausschläge
## (feines Zielen) werden wie von einem Menschen an der Tastatur getippt: Taste nur in einem Teil der Bilder.
func _apply(mv: Vector2, held: Dictionary) -> void:
	var on := [false, false]
	for ax in 2:
		var v := absf(mv[ax])
		if v > 0.6:
			on[ax] = true
			_pwm[ax] = 0.0
		elif v > 0.04:
			_pwm[ax] += v / 0.6
			if _pwm[ax] >= 1.0:
				_pwm[ax] -= 1.0
				on[ax] = true
	_key(MOVE_KEYS.l, on[0] and mv.x < 0.0)
	_key(MOVE_KEYS.r, on[0] and mv.x > 0.0)
	_key(MOVE_KEYS.u, on[1] and mv.y < 0.0)
	_key(MOVE_KEYS.d, on[1] and mv.y > 0.0)
	for act: String in KEYMAP:
		_key(KEYMAP[act], bool(held.get(act, false)))


func _strategy(name: String, mg: MinigameBase, dt: float) -> void:
	match name:
		"idle":
			_apply(Vector2.ZERO, {})
		"mimic":
			# Spiele, deren CPU nicht über Eingaben spielt: gezielte Menschen-Strategie (liest die Ansage, schnippt die Richtung)
			if mg.game_id == "sleepwalk" or mg.game_id == "sleepy_stars":
				_flick_t += 1
				var want := Vector2.ZERO
				if mg.game_id == "sleepwalk":
					if int(mg.progress[0]) < int(mg.STEPS) and not bool(mg._busy[0]) and float(mg._stun[0]) <= 0.0:
						want = {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}[String(mg.course[int(mg.progress[0])])]
				elif String(mg._phase) == "input" and int(mg._progress[0]) < (mg.seq as Array).size():
					want = mg.VECS[int(mg.seq[int(mg._progress[0])])]
				_apply(want if _flick_t % 18 < 5 else Vector2.ZERO, {})
				return
			InputHub.set_virtual(0, Vector2.ZERO, {})
			mg.cpu_think(0, dt)
			mg._cpu_full_jump(0, dt)
			var v: Dictionary = InputHub._virtual[0]
			_apply(v.move as Vector2, v.held as Dictionary)
		"random":
			_rand_t -= dt
			if _rand_t <= 0.0:
				_rand_t = _rng.randf_range(0.12, 0.6)
				_rand_mv = Vector2.ZERO if _rng.randf() < 0.15 else Vector2.from_angle(_rng.randi_range(0, 7) * PI / 4.0)
				_rand_btn = {}
				for act: String in KEYMAP:
					if _rng.randf() < 0.3:
						_rand_btn[act] = true
			_apply(_rand_mv, _rand_btn)
		"mash":
			_mash_t += dt
			var k := int(_mash_t / 0.08)
			var acts := ["a", "b", "x", "y"]
			_apply(Vector2.from_angle(_mash_t * 2.2), {acts[(k / 2) % 4]: k % 2 == 0})


func run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var tree := get_tree()
	get_parent().remove_child.call_deferred(self)
	tree.root.add_child.call_deferred(self)
	await tree.process_frame
	await tree.process_frame
	var id := String(args.get("only", ""))
	var strat := String(args.get("strategy", "mimic"))
	var sd := int(args.get("seed", "1"))
	seed(sd * 7919 + 13)
	_rng.seed = sd * 104729 + 7
	var m: Dictionary = Game.minigame_info(id)
	var res := {"id": id, "strategy": strat, "seed": sd}
	if m.is_empty() or not m.has("scene"):
		res["error"] = "unbekannt"
		print("AGENT " + JSON.stringify(res))
		tree.quit()
		return
	var cats: Array = m.get("cats", ["ffa"])
	var cat := String(args.get("cat", cats[0] if not cats.is_empty() else "ffa"))
	res["cat"] = cat
	for i in Game.players.size():
		Game.players[i].cpu = i != 0            # Platz 1 = Mensch (Tastatur), Rest CPU
		Game.players[i].cpu_level = int(args.get("level", "1"))
	Game.mode = "free_play"
	var cs := {"cat": cat}
	if cat == "2v2":
		cs["teams"] = [0, 1, 0, 1]
	elif cat == "duel":
		cs["active"] = [true, true, false, false]
	elif cat == "1v3":
		cs["solo"] = 0
	Game.minigame_setup = cs
	tree.change_scene_to_file(String(m.scene))
	var mg: MinigameBase = null
	for i in 180:
		await tree.process_frame
		if tree.current_scene is MinigameBase:
			mg = tree.current_scene
			break
	if mg == null:
		res["error"] = "keine MinigameBase"
		print("AGENT " + JSON.stringify(res))
		tree.quit()
		return
	var dt := 1.0 / 60.0
	var t := 0.0
	var play_t := 0.0
	var intro_t := 0.0
	var ended := ""
	var path := 0.0
	var last_pos := Vector3.INF
	var first_in := -1.0
	var react := -1.0
	var worst_ms := 0.0
	var worst_at := 0.0
	var last_us := Time.get_ticks_usec()
	var obj0 := -1.0
	var tap := 0.0
	var a_presses_intro := 0
	var out_t := -1.0
	while true:
		await tree.physics_frame
		if not is_instance_valid(mg) or not mg.is_inside_tree():
			ended = "szene_verlassen"
			break
		t += dt
		var now := Time.get_ticks_usec()
		var ms := (now - last_us) / 1000.0
		last_us = now
		if mg.state == "intro" or mg.state == "setup":
			intro_t += dt
			tap += dt
			if strat == "idle" and intro_t < 30.0:
				pass   # AFK drückt erst spät (prüft nebenbei: die Erklärung wartet auf den Menschen)
			elif tap > 0.5:
				tap = 0.0
				_key(KEYMAP.a, not bool(_down.get(KEYMAP.a, false)))
				a_presses_intro += 1
			if intro_t > 60.0:
				ended = "intro_haengt"
				break
			continue
		if mg.state == "play":
			if obj0 < 0.0:
				obj0 = Performance.get_monitor(Performance.OBJECT_COUNT)
				_release_all()
				Assets.late_loads.clear()
				Assets.late_watch = true
			play_t += dt * Engine.time_scale
			if play_t > 0.3 and ms > worst_ms:
				worst_ms = ms
				worst_at = play_t
			_strategy(strat, mg, dt)
			var av = mg.avatars[0]
			if av is Node3D and (av as Node3D).is_inside_tree():
				var p: Vector3 = (av as Node3D).global_position
				if last_pos != Vector3.INF and p.distance_to(last_pos) < 3.0:
					path += Vector2(p.x - last_pos.x, p.z - last_pos.z).length()
				last_pos = p
				if first_in < 0.0 and (bool(_down.get(MOVE_KEYS.l, false)) or bool(_down.get(MOVE_KEYS.r, false)) or bool(_down.get(MOVE_KEYS.u, false)) or bool(_down.get(MOVE_KEYS.d, false))) \
						and av is PartyAvatar and (av as PartyAvatar).can_move and not (av as PartyAvatar).is_stunned():
					first_in = play_t
				if first_in >= 0.0 and react < 0.0 and av is PartyAvatar and Vector2((av as PartyAvatar).velocity.x, (av as PartyAvatar).velocity.z).length() > 0.5:
					react = play_t - first_in
			if not mg.alive[0] and out_t < 0.0:
				out_t = play_t
			if play_t > mg.time_limit + 45.0:
				ended = "haengt_in_play"
				break
		elif mg.state == "finish" or mg.state == "results":
			ended = "ok"
			break
		if t > mg.time_limit + 150.0:
			ended = "timeout_" + mg.state
			break
	_release_all()
	Assets.late_watch = false
	res["late_loads"] = Assets.late_loads.duplicate()
	var place := 0
	var score := 0.0
	var obj1 := Performance.get_monitor(Performance.OBJECT_COUNT)
	if is_instance_valid(mg) and mg.is_inside_tree():
		var pl: Array[int] = mg.forced_placements if not mg.forced_placements.is_empty() else mg.compute_placements()
		place = pl[0]
		score = mg.scores[0]
		res["places"] = pl
		res["scores"] = mg.scores.map(func(s: float) -> float: return snappedf(s, 0.01))
		res["kind"] = "race" if mg.race else ("survival" if mg.survival else "score")
		res["limit"] = mg.time_limit
	# Ergebnisbildschirm: mit A weiter – das Spiel muss die Szene verlassen (kein Hänger, keine Sackgasse)
	var exit_ok := false
	if ended == "ok":
		var w := 0.0
		tap = 0.0
		while w < 45.0:
			await tree.process_frame
			w += dt
			tap += dt
			if tap > 0.4:
				tap = 0.0
				_key(KEYMAP.a, not bool(_down.get(KEYMAP.a, false)))
			if not is_instance_valid(mg) or tree.current_scene != mg:
				exit_ok = true
				break
		_release_all()
		res["exit_s"] = snappedf(w, 0.1)
	res.merge({"end": ended, "play": snappedf(play_t, 0.1), "intro": snappedf(intro_t, 0.1), "place": place, "score": snappedf(score, 0.01),
		"path_m": snappedf(path, 0.1), "react_frames": int(round(react * 60.0)) if react >= 0.0 else -1, "worst_ms": snappedf(worst_ms, 0.1), "worst_at": snappedf(worst_at, 0.1),
		"objects_delta": int(obj1 - obj0) if obj0 >= 0.0 else 0, "out_at": snappedf(out_t, 0.1), "exit_ok": exit_ok, "key_presses": presses})
	print("AGENT " + JSON.stringify(res))
	tree.quit()
