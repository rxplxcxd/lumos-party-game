extends Node3D
## Testlabor des Character-Frameworks (scripts/actor). Eigenständig – kein Teil der Spielabläufe.
##
##   godot --path . res://tools/charlab/CharLab.tscn                                     interaktiv (Tasten s. Einblendung)
##   godot --headless --fixed-fps 60 --path . res://tools/charlab/CharLab.tscn -- --lab-auto           alle Messungen
##   xvfb-run godot --fixed-fps 60 --path . res://tools/charlab/CharLab.tscn -- --lab-auto=/ordner     + Kontrollbilder
##   xvfb-run godot --path . res://tools/charlab/CharLab.tscn -- --lab-faces=/ordner                   Gesichter, 3 Winkel
## Ausgabe: je Prüfung „LAB PASS/FAIL …“, am Ende „CHARLAB OK“ (Exit 0) oder „CHARLAB FEHLER: n“ (Exit 1).

const KEYS := ["hero/knight", "hero/mage", "hero/barbarian", "hero/ranger"]
const OTHER := ["mini/male_a", "mini/robot", "pet/cat", "pet/dog"]   # Kompatibilität: Kenney-Figuren, Haustiere
const HELP := "1 Stehen · 2 Gehen/Rennen · 3 Lachen · 4 Gefühle · 5 Greifen · 6 Werfen · 7 Lenkrad · 8 High-Five · 9 Treffer · 0 Kombination · U Umarmung · S Schubser · P Schulterklopfen · B Stufe"

var actors: Array[LumosActor] = []
var others: Array[LumosActor] = []
var cam: Camera3D
var ball: Node3D
var wheel: Node3D
var step_box: Node3D
var label: Label
var _fails := 0
var _out := ""
var _walk := -1.0
var _combo := false
var _bump := 0.0
var _expr_i := 0


func _ready() -> void:
	Seasonal.test_override = "off"
	WorldKit.env(self, "day")
	WorldKit.box(self, Vector3(40, 1, 40), Vector3(0, -0.5, 0), Color("#7fc96a"), true)   # mit Kollision (Raycast-Boden)
	cam = Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 2.4, 7.5)
	cam.look_at(Vector3(0, 1.1, 0))
	cam.fov = 42.0
	for i in KEYS.size():
		actors.append(_spawn(KEYS[i], Vector3(-3.0 + i * 2.0, 0, 0)))
	for i in OTHER.size():
		others.append(_spawn(OTHER[i], Vector3(-3.0 + i * 2.0, 0, -4.0)))
	for a in actors + others:
		var c := a.capabilities()
		print("[LAB] %-15s Profil %-8s Gesicht %-5s Brauen %-5s Arme %-5s Handdrehung %-5s Beine %-5s Fußanker %-5s Haltung %s" % [a.rig.model_key,
			c.profile, c.face, c.brows, c.arms, c.hand_orient, c.legs, c.foot_lock, c.posture])
	# Requisiten: Ball auf einem Sockel vor Figur 0, Lenkrad vor Figur 3, Stufe (mit Kollision) für die Bodenabfrage
	WorldKit.cylinder(self, 0.18, 0.8, Vector3(-3.0, 0.4, 0.55), Color("#a6744a"), false)
	ball = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.11
	sm.height = 0.22
	sm.material = WorldKit.mat(Color("#ff5c7a"), 0.4)
	(ball as MeshInstance3D).mesh = sm
	add_child(ball)
	ball.position = Vector3(-3.0, 0.91, 0.55)
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
	step_box = WorldKit.box(self, Vector3(0.6, 0.2, 1.2), Vector3(5.6, 0.1, 2.5), Color("#c9b27c"), true)
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
		elif String(a).begins_with("--lab-auto"):
			_out = String(a).get_slice("=", 1) if String(a).contains("=") else ""
			_auto.call_deferred()
		elif String(a).begins_with("--lab-behavior"):   # nur die Verhaltensbereiche B1–B20 (Entwicklung)
			_out = String(a).get_slice("=", 1) if String(a).contains("=") else ""
			_behavior_only.call_deferred()


func _spawn(key: String, pos: Vector3) -> LumosActor:
	var r := CharacterRig.new()
	add_child(r)
	r.setup(key, -1, 1.0)
	r.position = pos
	r.face_now(Vector3(0, 0, 1))
	r.play("idle")
	return LumosActor.attach(r)


func _ground(p: Vector3) -> float:
	return _bump if (p.x > 0.4 and p.x < 1.0 and absf(p.z) < 1.0) else 0.0


func _process(delta: float) -> void:
	for i in 2:
		var a := actors[i]
		var wish := Vector3.ZERO
		if _walk > 0.0:
			var c := Vector3(-2.0, 0, 2.2)
			var rel := a.rig.global_position - c
			var tang := Vector3(-rel.z, 0, rel.x).normalized()
			wish = (tang + (rel.normalized() * (1.6 - rel.length())) * 0.8).normalized() * _walk * (1.0 if i == 0 else 0.85)
		a.move(wish, true, delta)
	if _combo:
		actors[2].move(Vector3(0.0, 0, 0.6), true, delta)


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	match (e as InputEventKey).keycode:
		KEY_1: demo_idle()
		KEY_2: _walk = 0.67 if _walk < 0.0 or _walk > 1.0 else 2.2
		KEY_3: demo_laugh()
		KEY_4: demo_feel()
		KEY_5: demo_grab()
		KEY_6: demo_throw()
		KEY_7: demo_wheel()
		KEY_8: demo_high_five()
		KEY_9: demo_hit()
		KEY_0: demo_combo()
		KEY_U:
			_pair(1.3)
			LumosInteract.hug(actors[1], actors[2])
		KEY_S:
			_pair(1.25)
			LumosInteract.shove(actors[1], actors[2])
		KEY_P:
			_pair(1.2)
			LumosInteract.pat(actors[1], actors[2])
		KEY_B: demo_bump(0.0 if _bump > 0.0 else 0.2)
		KEY_ESCAPE: get_tree().quit()


# --- Vorführungen ---------------------------------------------------------------------------------------------

func demo_idle() -> void:
	_walk = -1.0
	_combo = false
	for a in actors:
		a.look_at_target(null)
		a.feel("neutral", 0.3)
		a.set_breath(0.35)


func demo_laugh() -> void:
	for i in actors.size():
		get_tree().create_timer(i * 0.22).timeout.connect(actors[i].laugh.bind(1.6, 1.0))


func demo_feel() -> void:
	var names: Array = LumosFace.EXPR.keys()
	_expr_i = (_expr_i + 1) % names.size()
	label.text = HELP + "\nGefühl: " + String(names[_expr_i])
	for a in actors + others:
		a.feel(String(names[_expr_i]), 0.25)


func demo_grab() -> void:
	ball.position = Vector3(-3.0, 0.91, 0.55)
	actors[0].interact.drop("r")
	actors[0].interact.grab(ball, "r")


func demo_throw() -> void:
	actors[0].interact.throw_to(Vector3(-1.0, 0.11, 3.0))


func demo_wheel() -> void:
	if actors[3].hand_weight("l") > 0.5:
		actors[3].interact.release_wheel()
		return
	actors[3].interact.hold_wheel(wheel, 0.23)
	var tw := wheel.create_tween().set_loops(3)
	tw.tween_property(wheel, "rotation:z", 0.6, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(wheel, "rotation:z", -0.6, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(wheel, "rotation:z", 0.0, 0.7).set_trans(Tween.TRANS_SINE)


## Figuren 1 und 2 im Abstand d nebeneinander (Köpfe sind groß – Abstand je Interaktion passend).
func _pair(d: float) -> void:
	_walk = -1.0
	actors[1].rig.global_position = Vector3(-d * 0.5, 0, 0)
	actors[2].rig.global_position = Vector3(d * 0.5, 0, 0)


func demo_high_five() -> void:
	_pair(1.25)
	LumosInteract.high_five(actors[1], actors[2])


func demo_hit() -> void:
	for a in actors + others:
		a.react_hit(Vector3(1, 0, -0.3), 1.0, a == actors[1])


func demo_bump(h: float) -> void:
	_bump = h
	actors[2].rig.face_now(Vector3(0, 0, 1))
	actors[2].rig.global_position = Vector3(1.0, 0, 0)
	actors[2].body.ground = _ground


func demo_combo() -> void:
	_bump = 0.0
	actors[2].body.ground = Callable()
	actors[2].rig.global_position = Vector3(1.0, 0, -1.0)
	ball.global_position = actors[2].rel(0.25, 0.95, 0.35)
	actors[2].interact.grab(ball, "r", 0.2)
	actors[2].look_at_target(actors[1])
	actors[2].laugh(2.5, 0.7)
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
	if a.body == null:
		return true
	for j in ["hand.l", "hand.r", "elbow.l", "elbow.r", "foot.l", "foot.r", "knee.l", "knee.r", "head"]:
		var p := a.body.joint_pos(j)
		if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)) or p.distance_to(a.rig.global_position) > 3.0:
			return false
	return true


func _deg(a: Vector3, b: Vector3) -> float:
	return rad_to_deg(a.normalized().angle_to(b.normalized())) if a.length() > 0.001 and b.length() > 0.001 else 180.0


## Geschwindigkeit des Standfußes über Grund (Ø über die Zeit, in der ein Fuß am Boden ist).
func _stance_slip(a: LumosActor, secs: float) -> Vector2:
	var smp: Array = []
	var prev := {"l": a.body.joint_pos("foot.l"), "r": a.body.joint_pos("foot.r")}
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		var cur := {"l": a.body.joint_pos("foot.l"), "r": a.body.joint_pos("foot.r")}
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
		if float(e[0]) < min_y + 0.012:
			slip += float(e[1])
			n += 1
	return Vector2(slip / maxf(n, 1), n)


func _behavior_only() -> void:
	await get_tree().process_frame
	await (preload("res://tools/charlab/behavior_lab.gd").new() as RefCounted).call("run", self)
	print("CHARLAB " + ("OK" if _fails == 0 else "FEHLER: %d" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _auto() -> void:
	label.visible = false
	var m := {"lo": INF, "hi": -INF, "gap": 0.0, "min_d": INF, "w": 0.0, "wa": 0.0, "min_h": INF, "pd": 1.0, "peak": 0.0, "head": INF, "pat": 0}
	await _wait(0.6)
	# 0 – Kompatibilität: jedes Rig startet, Fähigkeiten passen zum Skelett, Grundfunktionen laufen fehlerfrei
	_ok(actors.all(func(a: LumosActor) -> bool: var c := a.capabilities(); return c.face and c.arms == "2bone" and c.hand_orient and c.foot_lock),
		"0 KayKit-Helden: Gesicht, zweiteilige Arme mit Handdrehung, Fußanker erkannt")
	var mini := others[0]
	_ok(mini.capabilities().profile == "simple" and mini.capabilities().arms == "aim" and not mini.capabilities().foot_lock, "0 Kenney-Figur: Profil „simple“ (Arme zielen, keine Fuß-IK)")
	_ok(others[2].capabilities().profile == "rigid" and others[2].body == null, "0 Haustier ohne Skelett: Profil „rigid“ (ganzer Körper)")
	for o in others:
		o.feel("joy", 0.2)
		o.look_at_target(actors[0])
		o.laugh(1.0)
		o.react_hit(Vector3.RIGHT, 0.8)
		o.reach("r", o.rel(0.3, 1.0, 0.6), 0.3)
	await _wait(1.3)
	_ok(others.all(func(o: LumosActor) -> bool: return _finite(o)), "0 Kenney-Figuren und Haustiere: Gefühl, Blick, Lachen, Treffer, Greifen laufen ohne Fehler")
	var pet := others[2]
	_ok(absf(pet.rig.pivot.rotation.x) < 0.6 and absf(pet.rig.pivot.rotation.z) < 0.6, "0 Haustier: Haltung/Stoß über den ganzen Körper bleibt im Rahmen")
	var mini_tip := mini.body.joint_pos("hand.r")
	_ok(mini_tip.distance_to(mini.rel(0.3, 1.0, 0.6)) < mini_tip.distance_to(mini.rig.global_position) + 0.5, "0 Kenney-Arm zielt zum Griffpunkt (Spitze %.2f m entfernt)" % mini_tip.distance_to(mini.rel(0.3, 1.0, 0.6)))
	for o in others:
		o.release("r")
		o.look_at_target(null)
	# 1 – Stehen und Atmen, Füße am Boden
	demo_idle()
	var samp := func() -> void:
		var y := actors[0].body.joint_pos("shoulder.l").y
		m.lo = minf(m.lo, y)
		m.hi = maxf(m.hi, y)
		for a in actors:
			m.gap = maxf(m.gap, absf(minf(a.body.joint_pos("foot.l").y, a.body.joint_pos("foot.r").y) - a.cfg.ankle_height - a.rig.global_position.y))
	await _wait(2.6, samp)
	_ok(m.hi - m.lo > 0.002 and m.hi - m.lo < 0.08, "1 Atmung sichtbar und dezent (Schulter hebt sich %.1f mm)" % ((m.hi - m.lo) * 1000.0))
	_ok(m.gap < 0.07, "1 Füße am Boden im Stand (größte Abweichung %.0f mm)" % (m.gap * 1000.0))
	await _shot("01_stehen")
	# 2 – Gehen/Rennen: Standfuß verankert (kein Rutschen), Anfahren mit Trägheit, Ausrollen
	for sp: float in [0.67, 2.2]:
		_walk = sp
		var a0 := actors[0]
		await _wait(0.035)
		var v_early := a0.loco.velocity.length()
		await _wait(1.6)
		var sl: Vector2 = await _stance_slip(a0, 2.0)
		_ok(v_early < a0.loco.velocity.length() and v_early > 0.0, "2 Anfahren mit Trägheit bei %.2f m/s (nach 2 Bildern erst %.2f)" % [sp, v_early])
		_ok(sl.x < (0.06 if sp < 1.0 else 0.15) and sl.y > 10, "2 Standfuß verankert bei %.2f m/s: rutscht Ø %.3f m/s (Zustand %s)" % [sp, sl.x, a0.loco.state])
		_ok(_finite(a0), "2 Gelenke stabil bei %.2f m/s" % sp)
		await _shot("02_gehen" if sp < 1.0 else "02_rennen")
	_walk = -1.0
	await _wait(0.9)
	_ok(actors[0].loco.velocity.length() < 0.05 and actors[0].loco.state == "idle", "2 Ausrollen bis zum Stand")
	# 3 – Bodenhöhen: Callable-Stufe und Raycast auf eine Kollisionskiste
	demo_bump(0.2)
	await _wait(1.0)
	var dl := absf(actors[2].body.joint_pos("foot.l").y - actors[2].body.joint_pos("foot.r").y)
	_ok(absf(dl - 0.2) < 0.06 and _finite(actors[2]), "3 Bodenstufe (Callable): ein Fuß steht %.0f mm höher, Becken senkt sich" % (dl * 1000.0))
	demo_bump(0.0)
	actors[2].body.ground = Callable()
	actors[2].rig.global_position = Vector3(5.6 - 0.3, 0, 2.5)   # ein Fuß über der 20-cm-Kiste
	await _wait(1.0)
	var dr := absf(actors[2].body.joint_pos("foot.l").y - actors[2].body.joint_pos("foot.r").y)
	_ok(dr > 0.12 and dr < 0.26, "3 Bodenabfrage per Raycast: Fuß auf der Kiste steht %.0f mm höher" % (dr * 1000.0))
	actors[2].rig.global_position = Vector3(1.0, 0, 0)
	await _wait(0.4)
	# 4 – Lachen: Gesicht und Körper im selben Takt, klingt aus
	var sync := [0.0]
	demo_laugh()
	await _wait(1.0, func() -> void:
		var f := actors[0].face
		sync[0] = maxf(sync[0], absf(actors[0].body.laugh - f.laugh))
		m.peak = maxf(m.peak, minf(f.param("squint"), actors[0].body.laugh)))
	await _shot("04_lachen")
	await _wait(1.6)
	_ok(m.peak > 0.6 and sync[0] < 0.01, "4 Lachen: Lachaugen und Körper zugleich (%.2f), Gesicht/Körper synchron (Abweichung %.3f)" % [m.peak, sync[0]])
	_ok(actors[0].body.laugh < 0.02, "4 Lachen klingt aus")
	# 5 – Gefühle: Gesicht UND Haltung, jeder Ausdruck erreicht, weiche Übergänge, lesbar unterschiedlich
	var worst := 0.0
	var reached := true
	var chest := {}
	for a5 in actors:   # reiner Gesichts-/Gefühlstest: kein Sozialverhalten, Nachwirkungen vorher abklingen lassen
		a5.cfg.autonomy = 0.0
		a5.emotion.clear()
	await _wait(1.2)
	for nm in LumosFace.EXPR.keys():
		for a in actors:
			a.feel(String(nm), 0.25)
		var last := {}
		for k in LumosFace.KEYS:
			last[k] = actors[1].face.param(k)
		var t5 := 0.0
		while t5 < 0.7:
			await get_tree().process_frame
			t5 += get_process_delta_time()
			for k in LumosFace.KEYS:
				worst = maxf(worst, absf(actors[1].face.param(k) - float(last[k])))
				last[k] = actors[1].face.param(k)
		var gain := actors[1].personality.expressiveness()   # ruhige/schüchterne Figuren zeigen Gefühle gedämpfter
		for k in LumosFace.KEYS:
			var base := 1.0 if k in LumosFace.ONE_KEYS else 0.0
			var want := base + (float((LumosFace.EXPR[nm] as Dictionary).get(k, base)) - base) * gain
			if String(nm) != "neutral" and absf(actors[1].face.param(k) - want) > 0.06:
				reached = false
		chest[nm] = actors[1].body.joint_pos("head") - actors[1].rig.global_position
		if String(nm) in ["joy", "sad", "angry", "surprised", "scared"]:
			await _shot("05_gefuehl_" + String(nm))
	for a6 in actors:
		a6.cfg.autonomy = 1.0
	_ok(reached, "5 alle %d Ausdrücke werden erreicht" % LumosFace.EXPR.size())
	_ok(worst < 0.3, "5 Übergänge weich (größter Sprung je Bild %.2f)" % worst)
	var post_d := (chest.sad as Vector3).distance_to(chest.joy)
	_ok(post_d > 0.06, "5 Haltung trägt das Gefühl: Kopf bei „sad“ und „joy“ %.0f mm auseinander" % (post_d * 1000.0))
	demo_idle()
	# 6 – Blickkontakt: Augen, Kopf und Oberkörper wenden sich gemeinsam zu
	actors[1].look_at_target(actors[3])
	var gz_max := [0.0]
	await _wait(0.8, func() -> void: gz_max[0] = maxf(gz_max[0], actors[1].face.gaze.length()))   # Augen laufen dem Kopf voraus
	var b1 := actors[1].body
	var fwd_chest := (b1.joint_pos("chest") - b1.joint_pos("hips"))
	var to_t := actors[3].rig.global_position - actors[1].rig.global_position
	var turned := actors[1].rig.global_basis.inverse() * (b1.joint_pos("shoulder.r") - b1.joint_pos("shoulder.l"))
	_ok(absf(turned.z) > 0.03 and float(gz_max[0]) > 0.1 and fwd_chest.length() > 0.0 and to_t.length() > 0.0,
		"6 Blickkontakt: Schulterlinie dreht sich mit (%.0f mm), Augen wandern voraus (%.2f)" % [absf(turned.z) * 1000.0, float(gz_max[0])])
	actors[1].look_at_target(null)
	# 7 – Greifen: Handfläche auf der Oberseite, richtig ausgerichtet; danach liegt der Ball auf der Handfläche
	var got := [false]
	actors[0].interact.grabbed.connect(func(_o: Node3D, _h: String) -> void: got[0] = true, CONNECT_ONE_SHOT)
	demo_grab()
	await _wait(0.42, func() -> void:
		if not got[0]:
			m.min_d = minf(m.min_d, actors[0].hand_pos("r").distance_to(ball.global_position + Vector3.UP * 0.11))
			m.pd = minf(m.pd, (actors[0].body.hand_axes("r")[1] as Vector3).dot(Vector3.DOWN) * -1.0))
	_ok(got[0] and m.min_d < 0.04, "7 Hand erreicht die Oberfläche des Balls (Abstand %.0f mm)" % (m.min_d * 1000.0))
	_ok(m.pd < -0.85, "7 Handfläche zeigt beim Zugreifen nach unten auf den Ball (Abweichung %.0f°)" % rad_to_deg(acos(clampf(-m.pd, -1, 1))))
	var flip := [Vector3.ZERO, 0.0]   # Wechsel Greifen (Handfläche unten) → Tragen (oben): gleitet statt umzuklappen
	await _wait(0.8, func() -> void:
		var pn: Vector3 = actors[0].body.hand_axes("r")[1]
		if flip[0] != Vector3.ZERO:
			flip[1] = maxf(float(flip[1]), _deg(flip[0], pn))
		flip[0] = pn)
	_ok(float(flip[1]) < 15.0, "7 Wechsel der Handhaltung gleitet (größter Drehschritt je Bild %.1f°)" % float(flip[1]))
	var up_dot := (actors[0].body.hand_axes("r")[1] as Vector3).dot(Vector3.UP)
	_ok(actors[0].interact.held.r == ball and up_dot > 0.85 and ball.global_position.y > actors[0].hand_pos("r").y, "7 Ball liegt auf der nach oben gedrehten Handfläche (%.0f°)" % rad_to_deg(acos(clampf(up_dot, -1, 1))))
	await _shot("07_halten")
	# 8 – Werfen
	var land := [Vector3.INF]
	actors[0].interact.landed.connect(func(_o: Node3D, p: Vector3) -> void: land[0] = p, CONNECT_ONE_SHOT)
	demo_throw()
	await _wait(0.3)
	await _shot("08_werfen")
	await _wait(1.6)
	_ok(land[0] != Vector3.INF and ball.global_position.distance_to(Vector3(-1.0, 0.11, 3.0)) < 0.05, "8 Wurf landet am Ziel")
	_ok(actors[0].interact.held.r == null and actors[0].hand_weight("r") < 0.02, "8 Hand losgelassen und zurück in der Animation")
	# 9 – Lenkrad: beide Hände am drehenden Kranz, Finger entlang des Kranzes
	demo_wheel()
	await _wait(0.6)
	var w_smp := func() -> void:
		for sd in ["l", "r"]:
			var rim := wheel.global_transform.affine_inverse() * actors[3].hand_pos(sd)
			m.w = maxf(m.w, absf(Vector2(rim.x, rim.y).length() - 0.23) + absf(rim.z))
			var radial := (actors[3].hand_pos(sd) - wheel.global_position).normalized()
			var tang := wheel.global_basis.z.normalized().cross(radial)
			m.wa = maxf(m.wa, minf(_deg(actors[3].body.hand_axes(sd)[0], tang), _deg(actors[3].body.hand_axes(sd)[0], -tang)))
	await _wait(1.2, w_smp)
	await _shot("09_lenkrad")
	await _wait(1.5, w_smp)
	_ok(m.w > 0.0 and m.w < 0.05, "9 beide Hände bleiben am drehenden Kranz (größte Abweichung %.0f mm)" % (m.w * 1000.0))
	_ok(m.wa < 25.0, "9 Finger liegen entlang des Kranzes (größte Abweichung %.0f°)" % m.wa)
	actors[3].interact.release_wheel()
	# 10 – High-Five: Handflächen treffen sich, zeigen zueinander, beide Körper nehmen den Schlag auf
	var hit := [false]
	actors[1].interact.contact.connect(func(k: String, _o: LumosActor) -> void: hit[0] = hit[0] or k == "high_five", CONNECT_ONE_SHOT)
	demo_high_five()
	var palm_dot := [1.0]
	await _wait(1.0, func() -> void:
		var d := actors[1].hand_pos("r").distance_to(actors[2].hand_pos("r"))
		if d < m.min_h:
			m.min_h = d
			palm_dot[0] = (actors[1].body.hand_axes("r")[1] as Vector3).dot(actors[2].body.hand_axes("r")[1])
		m.head = minf(m.head, actors[1].body.joint_pos("head").distance_to(actors[2].body.joint_pos("head")))
		m.peak = maxf(m.peak, actors[2].body._imp.length()))
	await _shot("10_high_five")
	_ok(hit[0] and m.min_h < 0.1, "10 High-Five: Hände treffen sich (Abstand %.0f mm)" % (m.min_h * 1000.0))
	_ok(palm_dot[0] < -0.6, "10 Handflächen zeigen zueinander (Skalarprodukt %.2f)" % palm_dot[0])
	_ok(m.head > actors[1].head_radius() * 1.5, "10 Köpfe stecken nicht ineinander (Abstand %.2f m)" % m.head)
	await _wait(1.6)
	# 11 – Umarmung: annähern, Arme liegen an, Köpfe seitlich versetzt, lösen, zurücktreten
	_pair(1.3)
	var p0 := actors[1].rig.global_position
	LumosInteract.hug(actors[1], actors[2], 0.8)
	var min_c := [INF]
	var min_hd := [INF]
	await _wait(1.2, func() -> void:
		min_c[0] = minf(min_c[0], actors[1].body.joint_pos("chest").distance_to(actors[2].body.joint_pos("chest")))
		min_hd[0] = minf(min_hd[0], actors[1].body.joint_pos("head").distance_to(actors[2].body.joint_pos("head"))))
	await _shot("11_umarmung")
	var arm_on := actors[1].hand_pos("l").distance_to(actors[2].body.joint_pos("shoulder.r")) < 0.35 and actors[1].hand_weight("l") > 0.9
	_ok(min_c[0] < 1.0 and arm_on and _finite(actors[1]) and _finite(actors[2]), "11 Umarmung: Körper nähern sich (Brust %.2f m), Arme liegen an den Schultern" % min_c[0])
	_ok(min_hd[0] > actors[1].head_radius() * 1.1, "11 Köpfe seitlich versetzt statt ineinander (Abstand %.2f m)" % min_hd[0])
	await _wait(1.6)
	_ok(actors[1].rig.global_position.distance_to(p0) < 0.02 and actors[1].hand_weight("l") < 0.05, "11 danach gelöst und zurückgetreten")
	# 12 – Schulterklopfen: die Schulter gibt bei jedem Klaps nach
	_pair(1.2)
	actors[2].body._imp = Vector3.ZERO
	var pats := [0]
	var prev_v := [0.0]
	LumosInteract.pat(actors[1], actors[2])
	await _wait(1.3, func() -> void:
		var v := actors[2].body._imp_v.y
		if v < -0.4 and prev_v[0] >= -0.4:
			pats[0] += 1
		prev_v[0] = v)
	_ok(pats[0] >= 3, "12 Schulterklopfen: Schulter gibt %d-mal nach" % pats[0])
	await _wait(0.8)
	# 13 – Treffer
	m.peak = 0.0
	demo_hit()
	await _wait(0.25, func() -> void: m.peak = maxf(m.peak, actors[0].body._imp.length()))
	await _shot("13_treffer")
	await _wait(2.0)
	_ok(m.peak > 0.05 and actors[0].body._imp.length() < 0.02 and actors[0].face.current == "neutral", "13 Treffer: Oberkörper federt (%.2f), beruhigt sich, Gesicht kehrt zurück" % m.peak)
	# 14 – alles zugleich: gehen, Blickkontakt, Ball tragen, lachen – Füße bleiben verankert
	demo_combo()
	await _wait(1.0)
	var a2 := actors[2]
	var sl2: Vector2 = await _stance_slip(a2, 1.2)
	_ok(a2.loco.state == "walk" and a2.interact.held.r == ball and a2.hand_weight("r") > 0.9 and a2._eye_w > 0.9 and a2._gaze_w > 0.6 and a2.body.laugh > 0.2,
		"14 Kombination: geht, trägt, schaut, lacht gleichzeitig")
	_ok(sl2.x < 0.08 and _finite(a2), "14 Kombination: Standfuß bleibt verankert (Ø %.3f m/s)" % sl2.x)
	await _shot("14_kombination")
	_combo = false
	# 15 – Leistung: 16 Figuren gehen, tragen, schauen, lachen; 4 Paare interagieren gleichzeitig
	var extra: Array[LumosActor] = []
	for i in 12:
		var e := _spawn(KEYS[i % 4], Vector3(-5.5 + i, 0, -7.0))
		extra.append(e)
	await _wait(0.4)
	var items: Array[Node3D] = []
	for i in extra.size():
		var it := MeshInstance3D.new()
		it.mesh = (ball as MeshInstance3D).mesh
		add_child(it)
		it.global_position = extra[i].rel(0.25, 0.95, 0.35)
		extra[i].interact.held["r"] = it
		extra[i].reach("r", extra[i].interact.carry_point.bind("r"), 0.2, func() -> Array: return [Vector3.FORWARD, Vector3.UP])
		extra[i].look_at_target(extra[(i + 1) % extra.size()])
		extra[i].laugh(4.0, 0.6)
	for k in 2:
		LumosInteract.high_five(extra[k * 2], extra[k * 2 + 1])
	# Volle Qualität (LOD aus) bei 1, 4, 8, 16 Figuren: Bildzeit mit und ohne Framework (nur Spiel-Animation)
	var crowd: Array[LumosActor] = []
	crowd.append_array(actors)
	crowd.append_array(extra)
	for o in others:
		o.rig.visible = false
		o.rig.process_mode = Node.PROCESS_MODE_DISABLED
	cam.position = Vector3(0, 6.0, 9.0)
	cam.look_at(Vector3(0, 0.8, -3.5))
	var cost16 := 0.0
	var total16 := 0.0
	var line := ""
	for n_act: int in [1, 4, 8, 16]:
		for i in crowd.size():
			crowd[i].rig.visible = i < n_act
			crowd[i].rig.process_mode = Node.PROCESS_MODE_INHERIT if i < n_act else Node.PROCESS_MODE_DISABLED
			crowd[i].cfg.lod = false
		var t_on := await _frame_ms(crowd, n_act, true)
		var t_off := await _frame_ms(crowd, n_act, false)
		line += "  %d: %.2f ms (Framework %.2f)" % [n_act, t_on, maxf(t_on - t_off, 0.0)]
		if n_act == 16:
			cost16 = maxf(t_on - t_off, 0.0)
			total16 = t_on
	print("[LAB] Bildzeit je Figurenzahl (CPU, headless):" + line)
	_ok(total16 < 16.0 or DisplayServer.get_name() != "headless", "15 Leistung: 16 Figuren mit Gehen, Fußanker, Hand-IK, Mimik, Lachen, 2 Interaktionen: %.2f ms je Bild, davon Framework %.2f ms (CPU, ohne Grafik)" % [total16, cost16])
	# LOD: Kamera abgewandt → alle pausiert und deutlich günstiger; zurückgedreht → sofort wieder aktiv
	for c in crowd:
		c.cfg.lod = true
	cam.look_at(Vector3(0, 6.0, 30.0))
	await _wait(0.6)
	var paused := crowd.filter(func(c: LumosActor) -> bool: return c.lod == 2).size()
	var t_lod := await _frame_ms(crowd, 16, true)
	cam.look_at(Vector3(0, 0.8, -3.5))
	await get_tree().process_frame
	var back := crowd.filter(func(c: LumosActor) -> bool: return c.lod < 2).size()
	_ok(paused == 16 and back == 16, "15 LOD: außerhalb des Bildes pausiert (%d/16), im Bild sofort wieder aktiv (%d/16)" % [paused, back])
	_ok(t_lod < total16, "15 LOD: 16 Figuren außerhalb des Bildes %.2f ms statt %.2f ms" % [t_lod, total16])
	# 1.5.2 – Character Behavior Laboratory (Bereiche B1–B20)
	await (preload("res://tools/charlab/behavior_lab.gd").new() as RefCounted).call("run", self)
	print("CHARLAB " + ("OK" if _fails == 0 else "FEHLER: %d" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


## Mittlere Bildzeit (ms) über 90 Bilder; die ersten n Figuren gehen hin und her, lachen, schauen, klatschen ab
## (bis zu zwei Paare), die Zusatzfiguren tragen dabei einen Ball – Framework an oder aus.
func _frame_ms(crowd: Array[LumosActor], n: int, on: bool) -> float:
	for i in n:
		crowd[i].set_enabled(on)
	for k in 10:
		await get_tree().process_frame
	for i in n:   # in jedem Messfenster: alle lachen und schauen, bis zu zwei Paare klatschen ab
		crowd[i].laugh(1.4, 0.6)
		crowd[i].look_at_target(crowd[(i + 1) % n])
	for k in mini(2, n / 2):
		LumosInteract.high_five(crowd[k * 2], crowd[k * 2 + 1])
	var t0 := Time.get_ticks_usec()
	for f in 90:
		for i in n:
			crowd[i].move(Vector3(0, 0, 0.7 if (i + f / 45) % 2 == 0 else -0.7), true, 1.0 / 60.0)
		await get_tree().process_frame
	var ms := (Time.get_ticks_usec() - t0) / 90000.0
	for i in n:
		crowd[i].set_enabled(true)
	return ms


## Nahaufnahmen der Gesichter: je Ausdruck von vorn, schräg (45°) und fast im Profil (75°), Kopf dabei gedreht.
func _face_sheet(dir: String) -> void:
	label.visible = false
	DirAccess.make_dir_recursive_absolute(dir)
	for o in others:
		o.rig.visible = false
	for i in actors.size():
		actors[i].rig.global_position = Vector3(-1.8 + i * 1.2, 0, 0)
		actors[i].rig.face_now(Vector3(0, 0, 1))
	cam.fov = 30.0
	for ang in [0.0, 45.0, 75.0]:
		var a := deg_to_rad(ang)
		cam.position = Vector3(sin(a) * 4.6, 1.62, cos(a) * 4.6)
		cam.look_at(Vector3(0, 1.55, 0))
		for nm in ["laugh", "surprised", "sad", "angry"]:
			for ac in actors:
				ac.face.blink_on = false
				ac.feel(nm, 0.0)
				ac.body.head_add = Vector3(0, deg_to_rad(ang) * 0.3, 0)
			await _wait(0.35)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(dir.path_join("%s_%02d.png" % [nm, int(ang)]))
	get_tree().quit()
