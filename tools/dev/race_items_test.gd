extends Node
## Regeltest für die Nitro-Dash-Items (echte Rennszene, 8 CPU-Karts, eingefroren): Trefferarten und ihre Grenzen,
## Schutzblase, Kometen-Unverwundbarkeit, Spiegel-Rückwurf, Donnerwolke nur gegen Vorausfahrende, Anker,
## Item-Verteilung nach Platz (Aufholhilfe), Abklingzeiten, Gefahren-Takt und die Online-Übertragung der Effekte.
## Gibt je Prüfung PASS/FAIL aus, am Ende "RACE-ITEMS OK" oder Exit-Code 1.
##   godot --headless --fixed-fps 60 --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/race_items_test.gd

var _fails := 0
var nd: Node
var track: RaceTrack
var racers: Array = []


func _ok(cond: bool, what: String) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		_fails += 1


func run() -> void:
	var tree := get_tree()
	get_parent().remove_child.call_deferred(self)
	tree.root.add_child.call_deferred(self)
	await tree.process_frame
	await tree.process_frame
	for p in Game.players:
		p.cpu = true
		p.cpu_level = 2
	Game.mode = "free_play"
	Game.race_cfg = {"track": "lumos_ring", "laps": 3, "cpu_level": 2, "mode": "single", "cup": 0}
	tree.change_scene_to_file("res://scenes/racer/NitroDash.tscn")
	for i in 300:
		await tree.process_frame
		if tree.current_scene and tree.current_scene.has_method("use_item"):
			nd = tree.current_scene
			break
	if nd == null:
		_ok(false, "Rennszene geladen")
		tree.quit(1)
		return
	track = nd.get("track")
	racers = nd.get("racers")
	while String(nd.get("state")) != "race":
		await tree.physics_frame
	_ok(racers.size() == 8, "8 Karts im Rennen")
	# Alle einfrieren (keine KI-Fahrt, keine eigenen Items) und auf feste Plätze setzen
	var s0 := 200.0
	for i in racers.size():
		var r: Racer = racers[i]
		r.started = false
		r.item = ""
		r.v = 0.0
	_place([0.0, 40.0, 80.0, -40.0, 300.0, 340.0, 380.0, 420.0], s0)
	await _frames(3)
	var a: Racer = racers[0]
	var b: Racer = racers[1]
	var c: Racer = racers[2]
	var d: Racer = racers[3]

	# --- Trefferarten: kurz, nie dauerhafter Kontrollverlust -----------------------------------------------------
	for kind in ["splat", "spin", "blast", "shrink", "anchor", "honey", "zap", "knock"]:
		_reset(b)
		b.s = s0 + 40.0
		var hit := b.hit(kind)
		var ok := hit and b.stun_t <= 1.5 and b.invuln_t > 0.0
		if kind == "honey":
			ok = ok and b.stun_t == 0.0 and b.honey_t > 0.0 and b.honey_t <= 2.0
		if kind == "shrink":
			ok = ok and b.stun_t == 0.0 and b.shrink_t > 0.0 and b.shrink_t <= 5.0
		if kind == "anchor":
			ok = ok and absf(track.wrap_s(s0 + 40.0 - b.s) - 18.0) < 0.01
		_ok(ok, "Treffer „%s“: kurz (Betäubung %.2f s ≤ 1,5 s), danach unverwundbar" % [kind, b.stun_t])
		_ok(not b.hit("spin"), "Treffer „%s“: direkt danach kein zweiter Treffer" % kind)
	await _frames(2)

	# --- Schutz ------------------------------------------------------------------------------------------------
	_reset(b)
	b.bubble_t = 5.0
	_ok(not b.hit("blast") and b.bubble_t == 0.0 and b.stun_t == 0.0, "Seifenblase schluckt einen Treffer und platzt")
	_reset(b)
	b.bubble_t = 5.0
	_ok(b.hit("shrink"), "Seifenblase schützt nicht vor dem Megafon-Schrumpfen")
	_reset(b)
	b.comet_t = 3.0
	_ok(not b.hit("blast") and b.stun_t == 0.0, "Kometenritt ist unverwundbar")
	_reset(b)

	# --- Spiegel: Kuchen prallt zum Werfer zurück -------------------------------------------------------------
	_reset(a)
	_reset(b)
	_place([0.0, 40.0, 80.0, -40.0, 300.0, 340.0, 380.0, 420.0], s0)
	b.mirror_t = 8.0
	var projs: Array = nd.get("projectiles")
	projs.clear()
	nd.call("_spawn_projectile", a, "pie", 45.0, 0.0, 1.6, 0.0)
	var a_hit := false
	var t := 0.0
	while t < 4.0:
		await tree.physics_frame
		_no_items()
		t += 1.0 / 60.0
		if a.stun_t > 0.0:
			a_hit = true
			break
	_ok(b.stun_t == 0.0 and b.mirror_t == 0.0, "Spiegelschild: Halter bleibt unversehrt, Schild verbraucht")
	_ok(a_hit, "Spiegelschild: das Geschoss trifft den Werfer (%.2f s)" % t)

	# Treffer-Nahaufnahme (Zeitlupe) abwarten
	while CutsceneManager.active or Engine.time_scale < 0.99:
		await tree.process_frame
	# --- Donnerwolke: nur Vorausfahrende ----------------------------------------------------------------------
	for r: Racer in racers:
		_reset(r)
	_place([0.0, 40.0, 80.0, -40.0, -80.0, -120.0, -160.0, -200.0], s0 + 400.0)
	nd.call("_rank")
	var ahead: Array = []
	var behind: Array = []
	for r: Racer in racers:
		if r != a:
			(ahead if r.place < a.place else behind).append(r)
	_ok(ahead.size() == 2 and behind.size() == 5, "Platzierung für den Test (a auf Platz %d)" % a.place)
	nd.set("race_time", 100.0)
	nd.call("use_item", a, "thunder")
	await _secs(1.4)
	var ahead_zapped := ahead.all(func(r: Racer) -> bool: return r.invuln_t > 0.0)
	var behind_clean := behind.all(func(r: Racer) -> bool: return r.invuln_t <= 0.0 and r.stun_t <= 0.0)
	if not ahead_zapped:
		for r: Racer in racers:
			print("  Kart %d Platz %d s=%.0f invuln=%.2f stun=%.2f fin=%s" % [r.idx, r.place, r.s, r.invuln_t, r.stun_t, r.finished])
	_ok(ahead_zapped, "Donnerwolke trifft alle Vorausfahrenden")
	_ok(behind_clean and a.stun_t <= 0.0, "Donnerwolke verschont den Werfer und alle Hinteren")

	# --- Item-Verteilung (Aufholhilfe) und Grenzen -------------------------------------------------------------
	for r: Racer in racers:
		_reset(r)
	nd.set("_last_thunder", -100.0)
	var first: Dictionary = {}
	var last: Dictionary = {}
	for i in 1500:
		var k1 := String(nd.call("_roll_item", 1))
		first[k1] = int(first.get(k1, 0)) + 1
		var k8 := String(nd.call("_roll_item", 8))
		last[k8] = int(last.get(k8, 0)) + 1
	_ok(not first.has("comet") and not first.has("thunder") and not first.has("homing") and not first.has("anchor"),
		"Platz 1 bekommt keine Angriffs-Joker (%s)" % str(first.keys()))
	_ok(first.has("bubble") or first.has("mirror"), "Platz 1 bekommt Verteidigung (Blase/Spiegel)")
	_ok(last.has("comet") and last.has("thunder") and int(last.get("nitro", 0)) > 150, "Letzte bekommen Komet, Donnerwolke und viel Nitro")
	nd.set("_last_thunder", float(nd.get("race_time")))
	var thunder_again := false
	for i in 800:
		if String(nd.call("_roll_item", 8)) == "thunder":
			thunder_again = true
	_ok(not thunder_again, "Donnerwolke hat eine Abklingzeit (%.0f s)" % float(nd.get("THUNDER_COOLDOWN")))
	c.comet_t = 3.0
	var comet_twice := false
	for i in 800:
		if String(nd.call("_roll_item", 8)) == "comet":
			comet_twice = true
	_ok(not comet_twice, "höchstens ein Komet gleichzeitig")
	c.comet_t = 0.0
	for kind in ItemModels.INFO.keys():
		_ok(ItemModels.icon_of(kind) != "" and ItemModels.name_of(kind) != "", "Item „%s“ hat Name und Symbol" % kind)

	# --- Gefahren-Takt: deterministisch, immer mit Vorwarnung --------------------------------------------------
	var hz := {"period": 6.0, "on": 2.0, "phase": 0.5}
	var warned := false
	var x := 6.0   # ab dem zweiten Takt (beim Rennstart darf eine Gefahr schon laufen – die Karts stehen woanders)
	var prev := RaceTrack.hazard_phase(hz, x - 1.0 / 60.0)
	var bad := false
	while x < 36.0:
		var ph := RaceTrack.hazard_phase(hz, x)
		if ph >= 1.0 and prev == 0.0:
			bad = true   # ohne Vorwarnung aktiv
		if ph < 0.0:
			warned = true
		prev = ph
		x += 1.0 / 60.0
	_ok(warned and not bad, "Gefahren: jede Aktivphase hat eine Vorwarnung")
	_ok(RaceTrack.hazard_phase(hz, 12.3) == RaceTrack.hazard_phase(hz, 12.3), "Gefahren: Takt nur aus der Rennzeit (auf allen Geräten gleich)")

	# --- Online: Effekte im Zustand ---------------------------------------------------------------------------
	_reset(d)
	d.bubble_t = 4.0
	d.mirror_t = 4.0
	d.honey_t = 1.0
	var st: Dictionary = d.net_state()
	_ok(int(st.fx) & 1 and int(st.fx) & 2 and int(st.fx) & 16 and not (int(st.fx) & 8), "Zustand überträgt Blase, Spiegel, Honig (fx=%d)" % int(st.fx))
	_ok(st.has("sl"), "Zustand überträgt den Schräglauf (Drift-Optik bei anderen)")

	print("RACE-ITEMS " + ("OK" if _fails == 0 else "FEHLER: %d" % _fails))
	tree.quit(0 if _fails == 0 else 1)


func _place(offsets: Array, s0: float) -> void:
	for i in racers.size():
		var r: Racer = racers[i]
		r.s = track.wrap_s(s0 + float(offsets[i]))
		r.x = 0.0
		r.h = 0.0
		r.lap = 1
		r.progress = r.lap * track.length + r.s


func _reset(r: Racer) -> void:
	r.stun_t = 0.0
	r.invuln_t = 0.0
	r.bubble_t = 0.0
	r.mirror_t = 0.0
	r.comet_t = 0.0
	r.honey_t = 0.0
	r.shrink_t = 0.0
	r.spark_t = 0.0
	r.h = 0.0
	r.vh = 0.0


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		_no_items()


## Eingefrorene Karts sollen keine Boxen einsammeln und benutzen
func _no_items() -> void:
	for r: Racer in racers:
		r.item = ""
		r.rolling = 0.0


func _secs(t: float) -> void:
	var e := 0.0
	while e < t:
		await get_tree().physics_frame
		_no_items()
		e += 1.0 / 60.0
