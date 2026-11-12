extends Node
## Fahrtest für Nitro Dash: ein komplettes Rennen mit 8 CPU-Karts im Schnellvorlauf (headless, feste Bildrate).
## Misst je Strecke Streckenlänge, Rundenzeiten, Gesamtdauer, Hängenbleiben, Bandenkontakte, Luftzeit (ohne Gleiten), Gleitzeit, Drift-Anteil,
## Item-Einsätze und Treffer. Ausgabe: eine Zeile "RACE {json}", bei Problemen zusätzlich "RACE-WARN …".
##   godot --headless --fixed-fps 60 --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/race_test.gd --track=lumos_ring [--laps=3] [--level=1]
## Alle Strecken: tools/dev/race_sweep.sh

var _laps: Dictionary = {}       # Racer-Index → Array Rundenzeiten
var _lap_t0: Dictionary = {}
var _used := 0
var _hits := 0
var _hit_kinds: Dictionary = {}
var _got: Dictionary = {}
var _use: Dictionary = {}
var _held: Dictionary = {}
var _air_kind: Dictionary = {}   # Racer-Index → Art des aktuellen Sprungs
var _air_by: Dictionary = {}     # Art → Sekunden (alle Karts)
var _air_n: Dictionary = {}      # Art → Anzahl Absprünge


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
	var track_id := String(args.get("track", "lumos_ring"))
	var laps := int(args.get("laps", "3"))
	for p in Game.players:
		p.cpu = true
		p.cpu_level = int(args.get("level", "1"))
	Game.mode = "free_play"
	Game.race_cfg = {"track": track_id, "laps": laps, "cpu_level": int(args.get("level", "1")), "mode": "single", "cup": 0}
	tree.change_scene_to_file("res://scenes/racer/NitroDash.tscn")
	var nd: Node = null
	for i in 240:
		await tree.process_frame
		if tree.current_scene and tree.current_scene.has_method("use_item"):
			nd = tree.current_scene
			break
	if nd == null:
		print("RACE " + JSON.stringify({"track": track_id, "error": "keine Rennszene"}))
		tree.quit(1)
		return
	var racers: Array = nd.get("racers")
	var track: RaceTrack = nd.get("track")
	for r: Racer in racers:
		_laps[r.idx] = []
		r.lap_done.connect(_on_lap.bind(r, nd))
		r.item_changed.connect(_on_item.bind(r))
	var n := racers.size()
	var stuck := []
	var wall := []
	var air := []
	var drift := []
	var stun_prev := []
	var max_back := []
	var glide := []
	glide.resize(n)
	var run_now := []   # aktuelle zusammenhängende Steh-Phase
	run_now.resize(n)
	stuck.resize(n); wall.resize(n); air.resize(n); drift.resize(n); stun_prev.resize(n); max_back.resize(n)
	for i in n:
		glide[i] = 0.0; run_now[i] = 0.0; stuck[i] = 0.0; wall[i] = 0.0; air[i] = 0.0; drift[i] = 0.0; stun_prev[i] = 0.0; max_back[i] = 0.0
	var dt := 1.0 / 60.0
	var t := 0.0
	var race_t := 0.0
	var max_t := float(args.get("max", "420"))
	var _items_prev := {}
	while t < max_t:
		await tree.physics_frame
		t += dt
		var st := String(nd.get("state"))
		if st == "results" or not is_instance_valid(nd) or tree.current_scene != nd:
			break
		if float(nd.get("_finish_wait")) > 0.0 and not _all_done(racers):
			nd.set("_finish_wait", -1.0)   # nur CPUs: das Rennen läuft, bis alle im Ziel sind
			nd.set("state", "race")
			st = "race"
		if st != "race" and st != "finish":
			continue
		race_t += dt
		for r: Racer in racers:
			var i := r.idx
			if r.finished:
				continue
			if r.started and r.stun_t <= 0.0 and absf(r.v) < 4.0 and race_t > 4.0:
				stuck[i] = float(stuck[i]) + dt
				run_now[i] = float(run_now[i]) + dt
				max_back[i] = maxf(float(max_back[i]), float(run_now[i]))
			else:
				run_now[i] = 0.0
			if absf(r.x) >= track.width * 0.5 - Racer.RADIUS - 0.02 and not r.gliding:
				wall[i] = float(wall[i]) + dt
			if r.gliding:
				glide[i] = float(glide[i]) + dt
			if r.airborne and not r.gliding:
				air[i] = float(air[i]) + dt
				if not _air_kind.has(i):
					var k := "hop" if r.vh < 5.5 else ("knock" if r.vh < 8.0 else "ramp")
					_air_kind[i] = k
					_air_n[k] = int(_air_n.get(k, 0)) + 1
				_air_by[_air_kind[i]] = float(_air_by.get(_air_kind[i], 0.0)) + dt
			else:
				_air_kind.erase(i)
			if r.drift_dir != 0:
				drift[i] = float(drift[i]) + dt
			if r.stun_t > float(stun_prev[i]) + 0.2:
				_hits += 1
			stun_prev[i] = r.stun_t
			var prev := String(_held.get(i, ""))
			if r.rolling <= 0.0 and r.item != prev:
				if r.item != "":
					_got[r.item] = int(_got.get(r.item, 0)) + 1
				elif prev != "":
					_use[prev] = int(_use.get(prev, 0)) + 1
				_held[i] = r.item
		if _all_done(racers):
			break
	# Auswertung
	var best := INF
	var lap_all: Array = []
	for i in n:
		for lt in _laps[i]:
			lap_all.append(float(lt))
			best = minf(best, float(lt))
	lap_all.sort()
	var med := float(lap_all[lap_all.size() / 2]) if not lap_all.is_empty() else 0.0
	var finished := 0
	var spread := 0.0
	var ft: Array = []
	for r: Racer in racers:
		if r.finished:
			finished += 1
			ft.append(r.finish_time)
	if ft.size() > 1:
		spread = float(ft.max()) - float(ft.min())
	var res := {"track": track_id, "length_m": snappedf(track.length, 1.0), "laps": laps, "race_s": snappedf(race_t, 0.1),
		"lap_best_s": snappedf(best, 0.1) if best < INF else 0.0, "lap_median_s": snappedf(med, 0.1), "finished": finished, "of": n,
		"field_spread_s": snappedf(spread, 0.1),
		"stuck_s": _r(stuck), "stuck_run_s": _r(max_back), "wall_s": _r(wall), "air_s": _r(air), "glide_s": _r(glide), "air_by_kind_s": _air_by, "air_count": _air_n, "drift_s": _r(drift),
		"items_used": _used, "hits": _hits, "got": _got, "used": _use}
	print("RACE " + JSON.stringify(res))
	for i in n:
		if float(max_back[i]) > 3.0:   # zusammenhängend (aufsummiert stehen auch Treffer und Anfahren drin)
			print("RACE-WARN Kart %d hängt %.1f s am Stück fest" % [i, max_back[i]])
	if finished < n:
		print("RACE-WARN nur %d/%d im Ziel" % [finished, n])
	tree.quit(0)


func _all_done(racers: Array) -> bool:
	for r: Racer in racers:
		if not r.finished:
			return false
	return true


func _r(a: Array) -> Array:
	var out := []
	for v in a:
		out.append(snappedf(float(v), 0.1))
	return out


func _on_lap(r: Racer, lap: int, _rr: Racer, nd: Node) -> void:
	var now := float(nd.get("race_time"))
	if lap <= 0:
		_lap_t0[r.idx] = now
		return
	(_laps[r.idx] as Array).append(now - float(_lap_t0.get(r.idx, now)))
	_lap_t0[r.idx] = now


func _on_item(r: Racer, _rr: Racer) -> void:
	if r.item == "" and r.rolling <= 0.0:
		_used += 1
