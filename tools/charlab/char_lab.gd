extends Node3D
## Testlabor des Character-Frameworks (scripts/actor). Eigenständig – kein Teil der Spielabläufe.
##
##   godot --path . res://tools/charlab/CharLab.tscn                       interaktiv (Tasten siehe Einblendung)
##   godot --headless --path . res://tools/charlab/CharLab.tscn -- --lab-auto          alle Vorführungen + Messungen
##   xvfb-run godot --path . res://tools/charlab/CharLab.tscn -- --lab-auto=/ordner    zusätzlich je Vorführung ein PNG
## Ausgabe: je Prüfung „LAB PASS/FAIL …“, am Ende „CHARLAB OK“ (Exit 0) oder „CHARLAB FEHLER: n“ (Exit 1).

const KEYS := ["hero/knight", "hero/mage", "hero/barbarian", "hero/ranger"]
const HELP := "1 Stehen/Atmen · 2 Gehen/Rennen · 3 Lachen · 4 Mimik · 5 Greifen · 6 Werfen · 7 Lenkrad · 8 High-Five · 9 Treffer · 0 Kombination · U Umarmung · S Schubser · B Boden-Stufe"

var actors: Array[LumosActor] = []
var cam: Camera3D
var ball: Node3D
var wheel: Node3D
var label: Label
var _fails := 0
var _out := ""
var _walk := -1.0          # > 0: Figuren 0/1 laufen im Kreis (Tempo)
var _combo := false
var _bump := 0.0           # Höhe der Bodenstufe unter Figur 2
var _expr_i := 0


func _ready() -> void:
	Seasonal.test_override = "off"
	WorldKit.env(self, "day")
	WorldKit.box(self, Vector3(40, 1, 40), Vector3(0, -0.5, 0), Color("#7fc96a"), false)
	cam = Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 2.4, 7.5)
	cam.look_at(Vector3(0, 1.1, 0))
	cam.fov = 42.0
	for i in KEYS.size():
		var r := CharacterRig.new()
		add_child(r)
		r.setup(KEYS[i], -1, 1.0)
		r.position = Vector3(-3.0 + i * 2.0, 0, 0)
		r.face_now(Vector3(0, 0, 1))
		r.play("idle")
		var a := LumosActor.attach(r)
		actors.append(a)
		print("[LAB] %s: Gesicht=%s · bewegliche Brauen=%s · Arme=%s · Beine=%s · Gehen %.2f / Laufen %.2f m/s" % [KEYS[i], a.face != null,
			a.face.has_own_brows if a.face else false, a.body.has_arms(), a.body.has_legs(), a.loco.walk_nat, a.loco.run_nat])
	# Requisiten: Ball auf einem Sockel vor Figur 0, Lenkrad vor Figur 3
	WorldKit.cylinder(self, 0.18, 0.8, Vector3(-3.0, 0.4, 0.55), Color("#a6744a"), false)
	ball = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.11
	sm.height = 0.22
	sm.material = WorldKit.mat(Color("#ff5c7a"), 0.4)
	(ball as MeshInstance3D).mesh = sm
	add_child(ball)
	ball.position = Vector3(-3.0, 0.92, 0.55)
	wheel = Node3D.new()
	add_child(wheel)
	wheel.position = Vector3(3.0, 0.98, 0.5)
	wheel.rotation.x = -0.5
	var tm := TorusMesh.new()
	tm.inner_radius = 0.2
	tm.outer_radius = 0.26
	tm.material = WorldKit.mat(Color("#30343c"), 0.5)
	var wm := MeshInstance3D.new()
	wm.mesh = tm
	wm.rotation.x = PI * 0.5
	wheel.add_child(wm)
	WorldKit.cylinder(self, 0.04, 0.9, Vector3(3.0, 0.5, 0.62), Color("#555a66"), false)
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.text = HELP
	label.position = Vector2(12, 8)
	label.add_theme_font_size_override("font_size", 15)
	layer.add_child(label)
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--lab-faces="):
			_face_sheet.call_deferred(String(a).get_slice("=", 1))
		if String(a).begins_with("--lab-auto"):
			_out = String(a).get_slice("=", 1) if String(a).contains("=") else ""
			_auto.call_deferred()


func _ground(p: Vector3) -> float:
	# Bodenstufe: links von Figur 2 (x < 1.0) liegt der Boden um _bump höher
	return _bump if (p.x > 0.4 and p.x < 1.0 and absf(p.z) < 1.0) else 0.0


func _process(delta: float) -> void:
	if _walk > 0.0:
		for i in 2:
			var a := actors[i]
			var c := Vector3(-2.0, 0, 2.2)
			var rel := a.rig.global_position - c
			var tang := Vector3(-rel.z, 0, rel.x).normalized()
			var wish := (tang + (rel.normalized() * (1.6 - rel.length())) * 0.8).normalized() * _walk * (1.0 if i == 0 else 0.85)
			a.move(wish, true, delta)
	else:
		for i in 2:
			actors[i].move(Vector3.ZERO, true, delta)
	if _combo:
		actors[2].move(Vector3(0.0, 0, 0.6), true, delta)


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	match (e as InputEventKey).keycode:
		KEY_1: demo_idle()
		KEY_2: demo_walk(0.67 if _walk < 0.0 or _walk > 1.0 else 2.2)
		KEY_3: demo_laugh()
		KEY_4: demo_expression()
		KEY_5: demo_grab()
		KEY_6: demo_throw()
		KEY_7: demo_wheel()
		KEY_8: demo_high_five()
		KEY_9: demo_hit()
		KEY_0: demo_combo()
		KEY_U: LumosInteract.hug(actors[1], actors[2])
		KEY_S: LumosInteract.shove(actors[1], actors[2])
		KEY_B: demo_bump(0.0 if _bump > 0.0 else 0.2)
		KEY_ESCAPE: get_tree().quit()


# --- Vorführungen ---------------------------------------------------------------------------------------------

func demo_idle() -> void:
	_walk = -1.0
	_combo = false
	for a in actors:
		a.look_at_target(null)
		a.express("neutral", 0.3)
		a.set_breath(0.35)


func demo_walk(speed: float) -> void:
	_walk = speed


func demo_laugh() -> void:
	for i in actors.size():
		get_tree().create_timer(i * 0.22).timeout.connect(actors[i].laugh.bind(1.6, 1.0))


func demo_expression() -> void:
	var names: Array = LumosFace.EXPR.keys()
	_expr_i = (_expr_i + 1) % names.size()
	label.text = HELP + "\nAusdruck: " + String(names[_expr_i])
	for a in actors:
		a.express(String(names[_expr_i]), 0.25)


func demo_grab() -> void:
	ball.position = Vector3(-3.0, 0.92, 0.55)
	actors[0].interact.drop("r")
	actors[0].interact.grab(ball, "r")


func demo_throw() -> void:
	actors[0].interact.throw_to(Vector3(-1.0, 0.11, 3.0))


func demo_wheel() -> void:
	if actors[3].hand_weight("l") > 0.5:
		actors[3].interact.release_wheel()
	else:
		actors[3].interact.hold_wheel(wheel, 0.23)
		var tw := wheel.create_tween().set_loops(3)
		tw.tween_property(wheel, "rotation:z", 0.6, 0.7).set_trans(Tween.TRANS_SINE)
		tw.tween_property(wheel, "rotation:z", -0.6, 1.4).set_trans(Tween.TRANS_SINE)
		tw.tween_property(wheel, "rotation:z", 0.0, 0.7).set_trans(Tween.TRANS_SINE)


func demo_high_five() -> void:
	_walk = -1.0
	actors[1].rig.global_position = Vector3(-0.47, 0, 0)
	actors[2].rig.global_position = Vector3(0.47, 0, 0)
	LumosInteract.high_five(actors[1], actors[2])


func demo_hit() -> void:
	for a in actors:
		a.react_hit(Vector3(1, 0, -0.3), 1.0, a == actors[1])


func demo_bump(h: float) -> void:
	_bump = h
	actors[2].rig.face_now(Vector3(0, 0, 1))
	actors[2].rig.global_position = Vector3(1.0, 0, 0)   # linker Fuß (aus Kamerasicht rechts) steht auf der Stufe
	actors[2].body.ground = _ground


## Alles zugleich: Figur 2 geht, schaut Figur 1 an und trägt dabei den Ball.
func demo_combo() -> void:
	_bump = 0.0
	actors[2].rig.global_position = Vector3(1.0, 0, -1.0)
	ball.global_position = actors[2].rel(0.25, 0.95, 0.35)
	actors[2].interact.grab(ball, "r", 0.2)
	actors[2].look_at_target(actors[1])
	actors[2].express("smile", 0.3)
	_combo = true


# --- automatische Prüfung -------------------------------------------------------------------------------------

func _ok(cond: bool, what: String) -> void:
	print(("LAB PASS " if cond else "LAB FAIL ") + what)
	if not cond:
		_fails += 1


func _wait(secs: float, each := Callable()) -> void:
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()
		if each.is_valid():
			each.call()


func _shot(name: String) -> void:
	if _out != "" and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(_out)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))


func _finite(a: LumosActor) -> bool:
	for j in ["hand.l", "hand.r", "elbow.l", "elbow.r", "foot.l", "foot.r", "knee.l", "knee.r", "head"]:
		var p := a.body.joint_pos(j)
		if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)) or p.distance_to(a.rig.global_position) > 3.0:
			return false
	return true


func _auto() -> void:
	label.visible = _out == ""
	var m := {"lo": INF, "hi": -INF, "gap": 0.0, "open": 0.0, "body": 0.0, "sq": 0.0, "min_d": INF, "w": 0.0, "min_h": INF, "peak": 0.0}   # Messwerte (Lambdas kopieren lokale Variablen)
	await _wait(0.5)
	# 0 – Aufbau mit allen Modellen
	_ok(actors.all(func(a: LumosActor) -> bool: return a.face != null and a.body.has_arms() and a.body.has_legs()), "alle %d Modelle: Gesicht, Arme, Beine erkannt" % actors.size())
	# 1 – Stehen und Atmen
	demo_idle()
	var samp := func() -> void:
		var y := actors[0].body.joint_pos("shoulder.l").y
		m.lo = minf(m.lo, y)
		m.hi = maxf(m.hi, y)
		for a in actors:
			m.gap = maxf(m.gap, absf(minf(a.body.joint_pos("foot.l").y, a.body.joint_pos("foot.r").y) - a.cfg.ankle_height - a.rig.global_position.y))
	await _wait(3.0, samp)
	_ok(m.hi - m.lo > 0.002 and m.hi - m.lo < 0.08, "1 Atmung sichtbar und dezent (Schulter hebt sich %.1f mm)" % ((m.hi - m.lo) * 1000.0))
	_ok(m.gap < 0.07, "1 Füße am Boden im Stand (größte Abweichung %.0f mm)" % (m.gap * 1000.0))
	await _shot("01_stehen")
	# 2 – Gehen/Rennen: Füße rutschen nicht (Standfuß-Geschwindigkeit über Grund), Anfahren mit Trägheit
	for sp: float in [0.67, 2.2]:
		demo_walk(sp)
		var a0 := actors[0]
		await _wait(0.035)
		var v_early := a0.loco.velocity.length()
		await _wait(1.6)
		var smp: Array = []   # [Fußhöhe, Geschwindigkeit über Grund] des jeweils tieferen Fußes
		var prev := {"l": a0.body.joint_pos("foot.l"), "r": a0.body.joint_pos("foot.r")}
		var t := 0.0
		while t < 2.0:
			await get_tree().process_frame
			var dt := get_process_delta_time()
			t += dt
			var cur := {"l": a0.body.joint_pos("foot.l"), "r": a0.body.joint_pos("foot.r")}
			var sd := "l" if (cur.l as Vector3).y < (cur.r as Vector3).y else "r"
			var d: Vector3 = (cur[sd] as Vector3) - (prev[sd] as Vector3)
			smp.append([(cur[sd] as Vector3).y, Vector2(d.x, d.z).length() / maxf(dt, 0.0001)])
			prev = cur
		var min_y := INF
		for e in smp:
			min_y = minf(min_y, float(e[0]))
		var slip := 0.0
		var n := 0
		for e in smp:
			if float(e[0]) < min_y + 0.012:   # Fuß steht auf dem Boden
				slip += float(e[1])
				n += 1
		slip /= maxf(n, 1)
		_ok(v_early < a0.loco.velocity.length() and v_early > 0.0, "2 Anfahren mit Trägheit bei %.2f m/s (nach 2 Bildern erst %.2f m/s)" % [sp, v_early])
		_ok(slip < sp * 0.45 and n > 10, "2 Schritte synchron bei %.2f m/s: Standfuß rutscht ⌀ %.2f m/s (Zustand %s)" % [sp, slip, a0.loco.state])
		_ok(_finite(a0), "2 Gelenke stabil bei %.2f m/s" % sp)
		if sp < 1.0:
			await _shot("02_gehen")
	await _shot("02_rennen")
	_walk = -1.0
	await _wait(0.8)
	_ok(actors[0].loco.velocity.length() < 0.05 and actors[0].loco.state == "idle", "2 Ausrollen bis zum Stand (Zustand %s)" % actors[0].loco.state)
	# 3 – Lachen: Mund, Augen und Körper gleichzeitig, danach wieder Ruhe
	demo_laugh()
	var smp3 := func() -> void:
		m.open = maxf(m.open, actors[0].face.param("open") + actors[0].face.laugh * 0.3)
		m.body = maxf(m.body, actors[0].body.laugh)
		m.sq = maxf(m.sq, actors[0].face.param("squint"))
	await _wait(1.0, smp3)
	await _shot("03_lachen")
	await _wait(1.6, smp3)
	_ok(m.open > 0.5 and m.sq > 0.6 and m.body > 0.8, "3 Lachen: Mund %.2f · Lachaugen %.2f · Körper %.2f" % [m.open, m.sq, m.body])
	_ok(actors[0].body.laugh < 0.02, "3 Lachen klingt aus")
	# 4 – Mimik: jeder Ausdruck wird erreicht, kein Sprung zwischen zwei Bildern
	var worst := 0.0
	var reached := true
	for nm in LumosFace.EXPR.keys():
		for a in actors:
			a.express(String(nm), 0.25)
		var last := {}
		for k in LumosFace.KEYS:
			last[k] = actors[1].face.param(k)
		var t4 := 0.0
		while t4 < 0.6:
			await get_tree().process_frame
			t4 += get_process_delta_time()
			for k in LumosFace.KEYS:
				worst = maxf(worst, absf(actors[1].face.param(k) - float(last[k])))
				last[k] = actors[1].face.param(k)
		for k in LumosFace.KEYS:
			var want := float((LumosFace.EXPR[nm] as Dictionary).get(k, 1.0 if k == "width" else 0.0))
			if absf(actors[1].face.param(k) - want) > 0.06:
				reached = false
		if String(nm) in ["joy", "surprised", "angry", "sad", "confused", "scared"]:
			await _shot("04_mimik_" + String(nm))
	_ok(reached, "4 alle %d Ausdrücke werden erreicht" % LumosFace.EXPR.size())
	_ok(worst < 0.3, "4 Übergänge weich (größter Sprung je Bild %.2f)" % worst)
	demo_idle()
	# 5 – Greifen und Halten
	var got := [false]
	actors[0].interact.grabbed.connect(func(_o: Node3D, _h: String) -> void: got[0] = true, CONNECT_ONE_SHOT)
	demo_grab()
	var smp5 := func() -> void:
		if not got[0]:
			m.min_d = minf(m.min_d, actors[0].hand_pos("r").distance_to(ball.global_position))
	await _wait(0.5, smp5)
	_ok(got[0] and m.min_d < 0.06, "5 Hand erreicht den Gegenstand (Abstand %.0f mm)" % (m.min_d * 1000.0))
	await _wait(0.8)
	_ok(actors[0].interact.held.r == ball and ball.global_position.distance_to(actors[0].hand_pos("r")) < 0.15, "5 Gegenstand liegt in der Hand und folgt ihr")
	await _shot("05_halten")
	# 6 – Werfen und Loslassen
	var land := [Vector3.INF]
	actors[0].interact.landed.connect(func(_o: Node3D, p: Vector3) -> void: land[0] = p, CONNECT_ONE_SHOT)
	demo_throw()
	await _wait(0.3)
	await _shot("06_werfen")
	await _wait(1.6)
	_ok(land[0] != Vector3.INF and ball.global_position.distance_to(Vector3(-1.0, 0.11, 3.0)) < 0.05, "6 Wurf landet am Ziel")
	_ok(actors[0].interact.held.r == null and actors[0].hand_weight("r") < 0.02, "6 Hand ist losgelassen und zurück in der Animation")
	# 7 – beide Hände am Lenkrad, auch wenn es dreht
	demo_wheel()
	await _wait(0.6)
	var smp7 := func() -> void:
		for sd in ["l", "r"]:
			var hp := actors[3].hand_pos(sd)
			var rim := (wheel.global_transform.affine_inverse() * hp)
			m.w = maxf(m.w, absf(Vector2(rim.x, rim.y).length() - 0.23) + absf(rim.z))
	await _wait(1.2, smp7)
	await _shot("07_lenkrad")
	await _wait(1.5, smp7)
	_ok(m.w > 0.0 and m.w < 0.07, "7 beide Hände bleiben am drehenden Lenkradkranz (größte Abweichung %.0f mm)" % (m.w * 1000.0))
	actors[3].interact.release_wheel()
	# 8 – High-Five
	var hit := [false]
	actors[1].interact.contact.connect(func(k: String, _o: LumosActor) -> void: hit[0] = hit[0] or k == "high_five", CONNECT_ONE_SHOT)
	demo_high_five()
	var smp8 := func() -> void: m.min_h = minf(m.min_h, actors[1].hand_pos("r").distance_to(actors[2].hand_pos("r")))
	await _wait(0.5, smp8)
	await _shot("08_high_five")
	await _wait(1.0, smp8)
	_ok(hit[0] and m.min_h < 0.12, "8 High-Five: die Hände treffen sich (Abstand %.0f mm)" % (m.min_h * 1000.0))
	_ok(actors[1].body.laugh > 0.2 or actors[2].body.laugh > 0.2, "8 danach lachen beide")
	await _wait(1.5)
	# Umarmung und Schubser
	LumosInteract.hug(actors[1], actors[2], 0.8)
	await _wait(0.9)
	await _shot("08_umarmung")
	_ok(actors[1].hand_weight("l") > 0.9 and actors[2].hand_weight("r") > 0.9 and _finite(actors[1]) and _finite(actors[2]), "8 Umarmung: beide Arme liegen an, Gelenke stabil")
	await _wait(1.6)
	# 9 – Treffer
	demo_hit()
	var smp9 := func() -> void: m.peak = maxf(m.peak, actors[0].body._imp.length())
	await _wait(0.25, smp9)
	await _shot("09_treffer")
	await _wait(2.0, smp9)
	_ok(m.peak > 0.05 and actors[0].body._imp.length() < 0.02, "9 Treffer: Oberkörper federt (%.2f) und beruhigt sich" % m.peak)
	_ok(actors[0].face.current == "neutral", "9 Gesicht kehrt zur Ruhe zurück")
	# Fuß-IK auf einer Stufe
	demo_bump(0.2)
	await _wait(1.0)
	var fl := actors[2].body.joint_pos("foot.l").y
	var fr := actors[2].body.joint_pos("foot.r").y
	_ok(absf(absf(fl - fr) - 0.2) < 0.06 and _finite(actors[2]), "Fuß-IK: ein Fuß steht 20 cm höher (gemessen %.0f mm), Becken senkt sich" % (absf(fl - fr) * 1000.0))
	await _shot("10_fuss_ik")
	demo_bump(0.0)
	await _wait(0.5)
	# 0 – Kombination: gehen + Blickkontakt + Gegenstand tragen
	demo_combo()
	await _wait(1.3)
	var a2 := actors[2]
	_ok(a2.loco.state == "walk" and a2.interact.held.r == ball and a2.hand_weight("r") > 0.9 and a2._gaze_w > 0.8, "10 Kombination: geht (%s), trägt den Ball (%s, Hand %.2f), hält Blickkontakt (%.2f)" % [a2.loco.state, a2.interact.held.r == ball, a2.hand_weight("r"), a2._gaze_w])
	await _shot("11_kombination")
	_combo = false
	# Leistung: 12 zusätzliche Akteure
	var extra: Array[CharacterRig] = []
	for i in 12:
		var r := CharacterRig.new()
		add_child(r)
		r.setup(KEYS[i % 4], -1, 1.0)
		r.position = Vector3(-5.5 + i, 0, -3.0)
		LumosActor.attach(r).laugh(3.0)
		extra.append(r)
	await _wait(0.5)
	var t0 := Time.get_ticks_usec()
	for i in 120:
		await get_tree().process_frame
	var ms := (Time.get_ticks_usec() - t0) / 120000.0
	_ok(ms < 12.0 or DisplayServer.get_name() != "headless", "Leistung: 16 Akteure, %.2f ms je Bild (alles, ohne Grafik)" % ms)
	print("CHARLAB " + ("OK" if _fails == 0 else "FEHLER: %d" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


## Nahaufnahmen aller Gesichter je Ausdruck (… -- --lab-faces=/ordner): Sichtprüfung für neue Modelle.
func _face_sheet(dir: String) -> void:
	label.visible = false
	DirAccess.make_dir_recursive_absolute(dir)
	for i in actors.size():
		actors[i].rig.global_position = Vector3(-1.8 + i * 1.2, 0, 0)
		actors[i].rig.face_now(Vector3(0.12 * (1.5 - i), 0, 1))
	cam.position = Vector3(0, 1.62, 4.6)
	cam.look_at(Vector3(0, 1.55, 0))
	cam.fov = 30.0
	for nm in ["neutral", "joy", "laugh", "surprised", "scared", "angry", "sad", "confused", "asleep", "smug"]:
		for a in actors:
			if a.face:
				a.face.blink_on = false
				a.express(nm, 0.0)
		await _wait(0.3)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join(nm + ".png"))
	get_tree().quit()
