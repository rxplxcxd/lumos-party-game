extends Node
## Kontrollbilder für Nitro Dash (CPU-Rennen, echte Grafik):
##   --mode=chase  Spielkamera zu mehreren Rennzeiten (--at=5,15,30)
##   --mode=spots  jede Streckenmechanik von schräg oben, mit Karts, die gerade hindurchfahren
##                 (Rampen, Gleiter, Trennwände, Sprungfelder, Gefahren, Tunnel, Wasserfall, Nässe, Eis, Wasser)
##   --mode=items  Wurf- und Trefferanimationen aller Items in Nahaufnahme (je 3 Phasen)
##   --mode=kart   Kart im Stand, in der Kurve und im Drift von vorne, seitlich und hinten
##   xvfb-run -a -s "-screen 0 1280x720x24" ./godot --path . --resolution 960x540 res://tools/dev/Run.tscn -- \
##     --dev-script=res://tools/dev/race_shot.gd --track=glow_forest --mode=spots --out=/pfad

var nd: Node
var track: RaceTrack
var racers: Array = []
var out := ""
var _cam: Camera3D
var _tag := ""


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
	out = String(args.get("out", "user://race_shots"))
	DirAccess.make_dir_recursive_absolute(out)
	var track_id := String(args.get("track", "lumos_ring"))
	_tag = track_id
	for p in Game.players:
		p.cpu = true
		p.cpu_level = 2
	Game.mode = "free_play"
	Game.race_cfg = {"track": track_id, "laps": 3, "cpu_level": 2, "mode": "single", "cup": 0}
	tree.change_scene_to_file("res://scenes/racer/NitroDash.tscn")
	for i in 300:
		await tree.process_frame
		if tree.current_scene and tree.current_scene.has_method("use_item"):
			nd = tree.current_scene
			break
	if nd == null:
		push_error("race_shot: keine Rennszene")
		tree.quit(1)
		return
	track = nd.get("track")
	racers = nd.get("racers")
	while String(nd.get("state")) != "race":
		await tree.process_frame
	var mode := String(args.get("mode", "chase"))
	match mode:
		"chase":
			for at in String(args.get("at", "4,14,28")).split(","):
				while float(nd.get("race_time")) < float(at):
					await tree.process_frame
				_save("chase_%ss" % at)
		"spots":
			await _spots()
		"items":
			await _items()
		"kart":
			await _kart()
	tree.quit(0)


func _save(name: String) -> void:
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s.png" % [_tag, name]))
	print("SHOT %s_%s" % [_tag, name])


func _own_cam() -> Camera3D:
	if _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 60.0
		_cam.far = 600.0
		add_child(_cam)
	_cam.make_current()
	return _cam


## Karts kurz vor eine Stelle setzen, damit sie im Bild gerade hindurchfahren.
func _place_field(s: float, lead: float) -> void:
	var lanes := [-4.5, 1.5, -1.0, 4.0]
	for i in mini(4, racers.size()):
		var r: Racer = racers[i]
		r.s = track.wrap_s(s - lead - i * 5.0)
		r.x = lanes[i]
		r.h = 0.0
		r.vh = 0.0
		r.v = 24.0
		r.stun_t = 0.0
		r.drift_dir = 0
		r.psi = 0.0
	for i in range(4, racers.size()):
		(racers[i] as Racer).s = track.wrap_s(s + 140.0 + i * 8.0)


func _spot(name: String, s: float, x := 0.0, back := 15.0, up := 7.0, wait := 0.75) -> void:
	_place_field(s, 18.0)
	var t0 := float(nd.get("race_time"))
	var cam := _own_cam()
	while float(nd.get("race_time")) - t0 < wait:
		cam.global_position = track.to_world(s - back, x * 0.4, up)
		cam.look_at(track.to_world(s + 6.0, x, 0.5), track.frame(s).basis.y)
		await get_tree().process_frame
	await _save(name)


func _spots() -> void:
	var d: Dictionary = track.def
	var n := 0
	for rs in track.ramp_s:
		await _spot("ramp%d" % n, rs, 0.0, 14.0, 5.0)
		n += 1
	n = 0
	for g in track.glide_ranges:
		await _spot("glide%d" % n, g.x + 12.0, 0.0, 16.0, 9.0, 1.1)
		n += 1
	n = 0
	for dv in track.dividers:
		await _spot("divider%d" % n, float(dv.s0) + 4.0, 0.0, 14.0, 9.0)
		n += 1
	n = 0
	for b in track.bounces:
		await _spot("bounce%d" % n, float(b.s), float(b.x), 12.0, 4.5)
		n += 1
	n = 0
	for hz in track.hazards:
		await _spot("hazard%d_%s" % [n, hz.type], float(hz.s), float(hz.x), 16.0, 6.0)
		n += 1
	n = 0
	for tu in d.get("tunnel", []):
		await _spot("tunnel%d" % n, track.point_s[int(tu[0])] + 6.0, 0.0, 12.0, 3.5)
		n += 1
	n = 0
	for fi in d.get("falls", []):
		await _spot("falls%d" % n, track.point_s[int(fi)], 0.0, 18.0, 5.0)
		n += 1
	n = 0
	for w in track.wet_ranges:
		await _spot("wet%d" % n, (w.x + w.y) * 0.5, 0.0, 14.0, 6.0)
		n += 1
	n = 0
	for w in track.ice_ranges:
		await _spot("ice%d" % n, w.x + 15.0, 0.0, 14.0, 6.0)
		n += 1
	n = 0
	for w in track.water_ranges:
		await _spot("water%d" % n, w.x + 15.0, 0.0, 14.0, 6.0)
		n += 1
	# Start/Ziel und ein Überblick von hoch oben
	await _spot("start", 2.0, 0.0, 22.0, 10.0)
	var cam := _own_cam()
	var rect := TrackScenery.bounds(track)
	var c := rect.get_center()
	cam.global_position = Vector3(c.x, maxf(rect.size.x, rect.size.y) * 0.75, c.y + rect.size.y * 0.55)
	cam.look_at(Vector3(c.x, 0, c.y), Vector3.UP)
	await get_tree().process_frame
	await _save("overview")


## Kamera hält sich relativ zum Kart (lokale Koordinaten: x rechts, y oben, z hinten).
func _follow(r: Racer, off: Vector3, look: Vector3, secs: float) -> void:
	var t0 := float(nd.get("race_time"))
	var cam := _own_cam()
	while true:
		var fr := track.frame(r.s)
		var o := track.to_world(r.s, r.x, r.h)
		cam.global_position = o + fr.basis * off
		cam.look_at(o + fr.basis * look, fr.basis.y)
		if float(nd.get("race_time")) - t0 >= secs:
			break
		await get_tree().process_frame


func _straight_s() -> float:
	var best := 30.0
	var best_k := INF
	var s := 30.0
	while s < track.length - 60.0:
		var k := 0.0
		for a in [0.0, 15.0, 30.0, 45.0]:
			k += absf(track.curvature(s, a))
		if k < best_k and not track.is_glide(s) and not track.is_water(s) and not track.in_range(s, track.ice_ranges):
			best_k = k
			best = s
		s += 10.0
	return best


func _calm(rs: Array, s: float) -> void:
	var lanes := [-2.0, 2.0, -5.0, 5.0]
	for i in rs.size():
		var r: Racer = rs[i]
		r.s = track.wrap_s(s + (0.0 if i < 2 else 26.0) + (i % 2) * 0.0 + (0.0 if i != 1 else 22.0))
		r.x = lanes[i]
		r.v = 6.0
		r.speed_mult = 0.22
		r.h = 0.0
		r.vh = 0.0
		r.stun_t = 0.0
		r.invuln_t = 0.0
		r.bubble_t = 0.0
		r.mirror_t = 0.0
		r.spark_t = 0.0
		r.comet_t = 0.0
		r.item = ""


func _items() -> void:
	var s := _straight_s()
	var a: Racer = racers[0]
	var b: Racer = racers[1]
	for i in range(2, racers.size()):
		(racers[i] as Racer).s = track.wrap_s(s + 200.0 + i * 10.0)
	for kind in ["pie", "candy", "homing", "anchor", "honey", "megaphone", "nitro", "bubble", "mirror", "spark", "thunder", "comet"]:
		_calm([a, b], s)
		a.place = 2
		b.place = 1
		await _follow(a, Vector3(5.5, 2.2, -1.0), Vector3(0, 0.8, -0.5), 0.3)
		nd.call("use_item", a, kind)
		var done := 0.0
		for ph in [0.08, 0.17, 0.23, 0.45]:   # Griff, Ausholen, Freigabe, Nachschwung
			await _follow(a, Vector3(4.5, 2.0, -1.5), Vector3(0, 1.0, -0.3), ph - done)
			done = ph
			await _save("item_%s_%02d" % [kind, int(ph * 100)])
		await _follow(a, Vector3(1.5, 4.5, 7.0), Vector3(0, 0.5, -16.0), 0.6)
		await _save("item_%s_flight" % kind)
		await _follow(a, Vector3(0, 0, 0), Vector3(0, 0, -1), 1.5)
		a.comet_t = 0.0
		a.boost_t = 0.0
	# Trefferreaktionen
	for kind in ["splat", "spin", "blast", "shrink", "anchor", "honey", "zap", "knock"]:
		_calm([a, b], s)
		await _follow(b, Vector3(-5.0, 2.0, 0.5), Vector3(0, 0.8, -0.5), 0.3)
		b.hit(kind)
		for ph in [0.1, 0.35, 0.8]:
			await _follow(b, Vector3(-5.0, 2.0, 0.5), Vector3(0, 0.8, -0.5), 0.1 if ph == 0.1 else (0.25 if ph == 0.35 else 0.45))
			await _save("hit_%s_%02d" % [kind, int(ph * 100)])
		await _follow(b, Vector3(0, 0, 0), Vector3(0, 0, -1), 1.6)
	# Schild sichtbar
	_calm([a, b], s)
	a.bubble_t = 10.0
	await _follow(a, Vector3(4.0, 1.8, 2.5), Vector3(0, 0.8, 0), 0.4)
	await _save("shield_bubble")
	a.bubble_t = 0.0
	a.mirror_t = 8.0
	await _follow(a, Vector3(4.0, 1.8, 2.5), Vector3(0, 0.8, 0), 0.4)
	await _save("shield_mirror")


func _kart() -> void:
	var s := _straight_s()
	var a: Racer = racers[0]
	for i in range(1, racers.size()):
		(racers[i] as Racer).s = track.wrap_s(s + 200.0 + i * 10.0)
	_calm([a], s)
	a.speed_mult = 0.0
	a.v = 0.0
	await _follow(a, Vector3(2.6, 1.3, -3.2), Vector3(0, 0.5, 0), 0.6)
	await _save("kart_front")
	await _follow(a, Vector3(3.6, 1.0, 0.0), Vector3(0, 0.5, 0), 0.2)
	await _save("kart_side")
	await _follow(a, Vector3(-2.0, 1.6, 3.4), Vector3(0, 0.5, 0), 0.2)
	await _save("kart_back")
	await _follow(a, Vector3(1.2, 4.2, 1.0), Vector3(0, 0, -0.3), 0.2)
	await _save("kart_top")
	a.speed_mult = 1.0
	a.v = 25.0
	for ph in [0.4, 1.0, 1.8]:
		await _follow(a, Vector3(0.0, 2.4, 5.5), Vector3(0, 0.6, -2.0), ph * 0.5)
		await _save("kart_run_%02d" % int(ph * 10))
	# erzwungener Drift für die Optik
	a.drift_dir = 1
	a.drift_t = 1.2
	a.slip = 0.5
	for ph in [0.3, 0.8]:
		await _follow(a, Vector3(0.0, 3.0, 6.0), Vector3(0, 0.6, -2.0), 0.25)
		await _save("kart_drift_%02d" % int(ph * 10))
