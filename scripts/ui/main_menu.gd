extends Node3D
## Hauptmenü mit lebendigem 3D-Diorama und Unterseiten:
## main · party (Setup) · race (Setup) · minigames (Arena) · settings · credits

@export var start_page := "main"

var _ui: Control
var _page: Control
var _heroes: Array[CharacterRig] = []
var _cam: Camera3D
var _cam_t := 0.0
var _logo: Control
var _wheel: Node3D

var _party_board := 0
var _party_rounds := 0
var _party_mode := 0
var _hero_steppers: Array[Stepper] = []
var _cpu_steppers: Array[Stepper] = []


func _ready() -> void:
	Game.mode = "menu"
	Engine.time_scale = 1.0
	_build_diorama()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_ui = UI.center_root(layer)
	_ui.mouse_filter = Control.MOUSE_FILTER_PASS
	Audio.music("menu")
	InputHub.set_touch_profile("menu")
	var p: String = Router.params.get("page", start_page)
	Router.params = {}
	show_page(p)


# --- 3D-Diorama -------------------------------------------------------------------------------

func _build_diorama() -> void:
	var we := WorldKit.env(self, "day")
	WorldKit.god_rays(self, Vector3(-2, 0, -2), 9.0, we.get_meta("sun"), 6, Color(1.0, 0.92, 0.7), 0.2)
	WorldKit.water(self, Vector2(260, 260), -0.6)
	WorldKit.backdrop(self, "beach", Color("#e8d6a0"), -0.56)
	# Insel
	WorldKit.cylinder(self, 9.0, 1.2, Vector3(0, -0.6, 0), Color("#f1d9a0"), false)
	WorldKit.cylinder(self, 7.0, 0.3, Vector3(0, 0.1, 0), Color("#7fd36a"), false)
	for i in 10:
		var a := TAU * i / 10.0
		if sin(a) > 0.2:
			continue   # kein Baum zwischen Kamera und Helden
		WorldKit.place(self, "pirate/palm" if i % 2 == 0 else "pirate/palm_bend", Vector3(cos(a) * 8.0, 0, sin(a) * 8.0), randf() * 360.0, randf_range(0.8, 1.1))
	for i in 18:
		var a2 := randf() * TAU
		var r2 := randf_range(2.0, 6.4)
		WorldKit.place(self, ["plat/flowers", "nat/flower_yellow", "nat/flower_purple", "nat/grass"][i % 4], Vector3(cos(a2) * r2, 0.25, sin(a2) * r2), randf() * 360.0, randf_range(0.8, 1.2))
	var ship := WorldKit.place(self, "pirate/ship_large", Vector3(-22, -1.0, -26), 35.0, 1.0)
	var boat := WorldKit.place(self, "pirate/ship_small", Vector3(26, -0.8, -18), -60.0, 1.0)
	for sh: Node3D in [ship, boat]:
		var bt := sh.create_tween().set_loops()
		bt.tween_property(sh, "rotation:z", 0.05, 2.2).set_trans(Tween.TRANS_SINE)
		bt.tween_property(sh, "rotation:z", -0.05, 2.2).set_trans(Tween.TRANS_SINE)
	WorldKit.place(self, "pirate/tower", Vector3(14, -0.5, -30), 0.0, 1.5)
	_wheel = WorldKit.place(self, "arcade/prize_wheel", Vector3(1.8, 0.2, -4.3), 0.0, 2.8)
	WorldKit.place(self, "arena/trophy", Vector3(-1.6, 0.2, -4.0), 10.0, 2.6)
	var kart := WorldKit.place(self, "kart/oopi", Vector3(-2.8, 0.25, -1.6), 40.0, 2.0)
	_kart = kart
	WorldKit.place(self, "pirate/chest", Vector3(-0.6, 0.2, 3.4), 30.0, 0.9)
	WorldKit.place(self, "toy/item_box", Vector3(6.2, 2.6, -1.0), 15.0, 2.4)
	var star := WorldKit.place(self, "plat/star", Vector3(0, 4.6, -5.0), 0.0, 3.6)
	var st := star.create_tween().set_loops()
	st.tween_property(star, "rotation:y", TAU, 6.0).as_relative()
	_cam = Camera3D.new()
	_cam.fov = 45.0
	add_child(_cam)
	_cam.make_current()
	_update_cam(0.0)
	# --- Lebendige Szene: jede Figur hat eine kleine, sinnvolle Beschäftigung ---
	var mage := _actor("hero/mage", Vector3(0.6, 0.25, 1.4))
	var barb := _actor("hero/barbarian", Vector3(4.4, 0.25, 0.4))
	_act_ball(mage, barb)
	_act_fishing(_actor("hero/ranger", Vector3(6.7, 0.25, 3.0)))
	_act_sandcastle(_actor("hero/rogue_hooded", Vector3(3.0, 0.25, -2.2)), Vector3(3.9, 0.25, -1.6))
	_act_wheel(_actor("hero/rogue", Vector3(0.4, 0.25, -2.6)))
	var knight := _actor("hero/knight", Vector3(-1.0, 0.25, 2.2))
	var chick := _actor("pet/chick", Vector3(-1.8, 0.25, 2.6), 0.55)
	_act_walk(knight, chick)
	_act_bunny(_actor("pet/bunny", Vector3(2.0, 0.25, 3.4), 0.6))
	_act_cat(_actor("pet/cat", Vector3(-0.2, 0.25, 2.9), 0.6))


var _kart: Node3D


func _actor(key: String, pos: Vector3, scl := 0.95) -> CharacterRig:
	var r := CharacterRig.new()
	add_child(r)
	r.setup(key, -1, scl)
	r.position = pos
	r.face_now(Vector3(0, 0, 1))
	r.play("idle")
	_heroes.append(r)
	return r


func _pause(t: float) -> bool:
	if not is_inside_tree():
		return false
	await get_tree().create_timer(t).timeout
	return is_inside_tree()


func _walk_to(r: CharacterRig, to: Vector3, speed := 1.6, clip := "walk") -> void:
	if not is_instance_valid(r):
		return
	r.face_now(to - r.position)
	r.play(clip)
	var tw := r.create_tween()
	tw.tween_property(r, "position", to, maxf(0.2, r.position.distance_to(to) / speed))
	await tw.finished
	if is_instance_valid(r):
		r.play("idle")


## Wasserball werfen und fangen – im Wechsel, mit hohem Bogen.
func _act_ball(a: CharacterRig, b: CharacterRig) -> void:
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	sm.material = WorldKit.mat(Color("#ff6b6b"), 0.4, 0.05)
	ball.mesh = sm
	add_child(ball)
	var stripe := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.27
	tm.outer_radius = 0.3
	tm.material = WorldKit.mat(Color.WHITE, 0.4)
	stripe.mesh = tm
	ball.add_child(stripe)
	var from := a
	var to := b
	while await _pause(randf_range(0.4, 1.2)):
		if not is_instance_valid(from) or not is_instance_valid(to):
			return
		from.face_now(to.position - from.position)
		to.face_now(from.position - to.position)
		from.play_once("throw")
		await _pause(0.35)
		var p0 := from.position + Vector3.UP * 1.4
		var p1 := to.position + Vector3.UP * 1.3
		var tw := ball.create_tween()
		tw.tween_method(func(t: float) -> void:
			ball.position = p0.lerp(p1, t) + Vector3.UP * sin(t * PI) * 2.6
			ball.rotation.x += 0.2, 0.0, 1.0, 1.05)
		await tw.finished
		if randf() < 0.18:
			# verfehlt! Ball kullert weg, kurzer Schreck, dann holen
			to.react("surprised" if to.has_clip("surprised") else "dodge")
			var roll := to.position + Vector3(randf_range(-1.5, 1.5), 0.2, randf_range(0.8, 1.6))
			var rt := ball.create_tween()
			rt.tween_property(ball, "position", roll, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			await rt.finished
			var home := to.position
			await _walk_to(to, roll + Vector3(0.3, -0.2, 0), 2.4, "run")
			to.play_once("pickup")
			await _pause(0.4)
			await _walk_to(to, home, 2.0)
		else:
			to.play_once("pickup")
			if randf() < 0.3:
				to.react("cheer")
		var tmp := from
		from = to
		to = tmp


## Angeln am Ufer: Pose, Pose, Biss! Fang fliegt ins Eimerchen.
func _act_fishing(r: CharacterRig) -> void:
	r.face_now(Vector3(1, 0, 0.6))
	var rod := WorldKit.cylinder(r, 0.03, 2.2, Vector3(0.35, 1.5, 0.6), Color("#b07a4a"), false)
	rod.rotation.x = 0.9
	var bob := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.09
	bs.height = 0.18
	bs.material = WorldKit.mat(Color("#ff5c7a"), 0.4)
	bob.mesh = bs
	add_child(bob)
	var water_spot := r.position + Vector3(2.2, -0.82, 1.4)
	bob.position = water_spot
	var bucket := WorldKit.cylinder(self, 0.25, 0.35, r.position + Vector3(-0.6, 0.18, 0.2), Color("#7fb8ff"), false)
	bucket.name = "Bucket"
	while await _pause(randf_range(4.0, 8.0)):
		r.play("fish" if r.has_clip("fish") else "hold")
		var dip := bob.create_tween()
		for k in 3:
			dip.tween_property(bob, "position:y", water_spot.y - 0.12, 0.12)
			dip.tween_property(bob, "position:y", water_spot.y, 0.18)
		await dip.finished
		r.play_once("pickup")
		var fish := MeshInstance3D.new()
		var fs := SphereMesh.new()
		fs.radius = 0.16
		fs.height = 0.2
		fs.material = WorldKit.mat([Color("#ffd23f"), Color("#ff9f43"), Color("#8fd0ff")][randi() % 3], 0.4)
		fish.mesh = fs
		fish.scale = Vector3(1, 1, 1.8)
		add_child(fish)
		var a := water_spot
		var b := bucket.position + Vector3.UP * 0.3
		var ft := fish.create_tween()
		ft.tween_method(func(t: float) -> void:
			fish.position = a.lerp(b, t) + Vector3.UP * sin(t * PI) * 2.2
			fish.rotation.x = t * TAU, 0.0, 1.0, 0.8)
		ft.tween_callback(fish.queue_free)
		await ft.finished
		Juice.squash(bucket, 1.2, 0.8, 0.25, Vector3.ONE)
		r.react("cheer")
		await _pause(1.2)
		r.play("sit" if r.has_clip("sit") else "idle")


## Sandburg bauen: hämmern, die Burg wächst … und stürzt manchmal ein.
func _act_sandcastle(r: CharacterRig, at: Vector3) -> void:
	r.face_now(at - r.position)
	var castle := Node3D.new()
	add_child(castle)
	castle.position = at
	var parts: Array[Node3D] = []
	for k in 4:
		var p := WorldKit.box(castle, Vector3(0.9 - k * 0.18, 0.32, 0.9 - k * 0.18), Vector3(0, 0.16 + k * 0.32, 0), Color("#f1d9a0").darkened(k * 0.04), false)
		p.visible = false
		parts.append(p)
	var flag := WorldKit.place(castle, "plat/flag", Vector3(0, 1.3, 0), 0.0, 0.5)
	flag.visible = false
	while is_inside_tree():
		for k in parts.size():
			r.play("hammer" if r.has_clip("hammer") else "interact")
			if not await _pause(1.0):
				return
			parts[k].visible = true
			Juice.pop_in(parts[k], 0.25)
		flag.visible = true
		Juice.pop_in(flag, 0.3)
		r.react("cheer")
		if not await _pause(3.0):
			return
		if randf() < 0.6:
			# Welle! Die Burg sackt zusammen
			for p in parts:
				var tw := p.create_tween()
				tw.tween_property(p, "scale", Vector3(1.3, 0.05, 1.3), 0.35).set_trans(Tween.TRANS_BOUNCE)
			flag.visible = false
			r.react("sad")
			if not await _pause(2.0):
				return
		for p in parts:
			p.visible = false
			p.scale = Vector3.ONE
		flag.visible = false


## Glücksrad drehen: hingehen, kräftig drehen, mitfiebern.
func _act_wheel(r: CharacterRig) -> void:
	var home := r.position
	while await _pause(randf_range(5.0, 9.0)):
		await _walk_to(r, _wheel.position + Vector3(0.4, 0.05, 1.3), 1.4)
		r.face_now(Vector3(0, 0, -1))
		r.play_once("interact")
		_wheel_boost = 9.0
		if not await _pause(2.6):
			return
		r.face_now(Vector3(0, 0, 1))
		r.react(["cheer", "dizzy", "laugh", "sad"][randi() % 4])
		if not await _pause(1.4):
			return
		await _walk_to(r, home, 1.4)


var _wheel_boost := 0.0


## Spaziergang in Etappen über die Insel, das Küken trippelt hinterher; ab und zu Winken in die Kamera.
func _act_walk(r: CharacterRig, chick: CharacterRig) -> void:
	var pts := [Vector3(-1.0, 0.25, 2.2), Vector3(1.6, 0.25, 4.2), Vector3(5.2, 0.25, 4.6), Vector3(5.8, 0.25, 1.2), Vector3(2.0, 0.25, -0.6)]
	var i := 0
	while is_inside_tree():
		i = (i + 1) % pts.size()
		var to: Vector3 = pts[i]
		var follow := to - (to - r.position).normalized() * 0.9
		chick.face_now(follow - chick.position)
		chick.play("walk")
		var ct := chick.create_tween()
		ct.tween_property(chick, "position", follow, maxf(0.3, chick.position.distance_to(follow) / 1.5)).set_delay(0.3)
		ct.tween_callback(func() -> void: chick.play("idle"))
		await _walk_to(r, to, 1.4)
		if not await _pause(randf_range(0.8, 2.0)):
			return
		if randf() < 0.45:
			r.face_now(_cam.global_position - r.global_position)
			r.react("wave")
			chick.hop(0.3, 0.25)
			if not await _pause(1.6):
				return


## Hase hoppelt in kleinen Sprüngen umher und schnuppert an Blumen.
func _act_bunny(r: CharacterRig) -> void:
	var center := r.position
	while await _pause(randf_range(0.6, 1.8)):
		var to := center + Vector3(randf_range(-1.6, 1.6), 0, randf_range(-1.0, 1.0))
		r.face_now(to - r.position)
		for k in 3:
			var from := r.position
			var step := from.lerp(to, (k + 1) / 3.0)
			var tw := r.create_tween()
			tw.tween_method(func(t: float) -> void:
				r.position = from.lerp(step, t) + Vector3.UP * sin(t * PI) * 0.35, 0.0, 1.0, 0.28)
			await tw.finished
		if randf() < 0.4:
			r.play_once("eat" if r.has_clip("eat") else "idle")


## Katze döst (Zzz) … und jagt dann einem Schmetterling hinterher.
func _act_cat(r: CharacterRig) -> void:
	var fly := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.02, 0.14)
	bm.material = WorldKit.mat(Color("#ffb3e6"), 0.6, 0.2)
	fly.mesh = bm
	add_child(fly)
	fly.visible = false
	while is_inside_tree():
		FX.zzz(r, 1.2, 4.0)
		if not await _pause(5.0):
			return
		fly.visible = true
		var c := r.position + Vector3(0, 1.0, 0)
		r.play("run" if r.has_clip("run") else "walk")
		for k in 6:
			var p := c + Vector3(randf_range(-1.5, 1.5), randf_range(0.0, 0.6), randf_range(-1.0, 1.0))
			var ft := fly.create_tween()
			ft.tween_property(fly, "position", p, 0.5).set_trans(Tween.TRANS_SINE)
			var rt := r.create_tween()
			rt.tween_property(r, "position", Vector3(p.x, 0.25, p.z), 0.55)
			r.face_now(p - r.position)
			await ft.finished
			if not is_inside_tree():
				return
			fly.rotation.z = sin(k) * 0.6
		r.play("idle")
		r.hop(0.4, 0.3)
		var away := fly.create_tween()
		away.tween_property(fly, "position", fly.position + Vector3(2, 4, -3), 1.2)
		await away.finished
		fly.visible = false


func _process(delta: float) -> void:
	_cam_t += delta
	_update_cam(delta)
	if _wheel:
		_wheel_boost = move_toward(_wheel_boost, 0.0, delta * 3.2)
		_wheel.rotation.z += delta * (0.4 + _wheel_boost)
	if _kart:
		_kart.position.y = 0.25 + absf(sin(_cam_t * 2.6)) * 0.04


func _update_cam(_d: float) -> void:
	var a := sin(_cam_t * 0.1) * 0.35
	var offset_x := 3.2 if _page and _page.name != "main" else 2.0
	_cam.position = Vector3(sin(a) * 15.0 - offset_x, 4.4 + sin(_cam_t * 0.3) * 0.25, cos(a) * 15.0)
	_cam.look_at(Vector3(-offset_x * 0.55 - 1.9, 1.4, 0.5), Vector3.UP)   # Insel rechts neben den Menü-Kacheln


# --- Seitensystem -------------------------------------------------------------------------------

func show_page(name: String) -> void:
	if _page:
		var old := _page
		var otw := old.create_tween().set_parallel(true)
		otw.tween_property(old, "modulate:a", 0.0, 0.16)
		otw.tween_property(old, "position:x", -50.0, 0.16).set_ease(Tween.EASE_IN)
		otw.chain().tween_callback(old.queue_free)
	var p: Control
	match name:
		"party":
			p = _page_party()
		"race":
			p = _page_race()
		"minigames":
			p = _page_minigames()
		"settings":
			p = _page_settings()
		"credits":
			p = _page_credits()
		"touch_edit":
			p = _page_touch_edit()
		"profile":
			p = _page_profile()
		"online":
			p = _page_online()
		"modes":
			p = _page_modes()
		_:
			p = _page_main()
	p.name = name
	_ui.add_child(p)
	_page = p
	p.modulate.a = 0.0
	p.position.x = -70.0
	var tw := p.create_tween().set_parallel(true)
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_property(p, "position:x", 0.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var k := 0
	for b in _all_buttons(p):
		b.modulate.a = 0.0
		var bt := b.create_tween()
		bt.tween_interval(0.04 * k)
		bt.tween_property(b, "modulate:a", 1.0, 0.2)
		k += 1
	await get_tree().process_frame
	var first := _first_focus(p)
	if first:
		first.grab_focus()


func _all_buttons(n: Node) -> Array[Button]:
	var out: Array[Button] = []
	for c in n.get_children():
		if c is Button:
			out.append(c)
		out.append_array(_all_buttons(c))
	return out


func _first_focus(n: Node) -> Control:
	if n is Button and (n as Button).visible and not (n as Button).disabled:
		return n
	for c in n.get_children():
		var r := _first_focus(c)
		if r:
			return r
	return null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _page and _page.name != "main":
		Audio.sfx("ui_back")
		if _page.name == "touch_edit":
			InputHub.touch_controls.call("stop_edit")
			show_page("settings")
		else:
			show_page("main")
		get_viewport().set_input_as_handled()


func _side_panel(title: String, width := 640.0) -> Array:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := UI.panel()
	root.add_child(panel)
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 28
	panel.offset_top = 28
	panel.offset_bottom = -28
	panel.offset_right = 28 + width
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	var v := UI.vbox(14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	var t := UI.label(title, 56, UI.GOLD, true, 12)
	v.add_child(t)
	return [root, v]


func _back_button(v: Control, target := "main") -> Button:
	var b := UI.button("Zurück", Color("#5a4a80"), 28)
	b.pressed.connect(func() -> void: show_page(target))
	v.add_child(b)
	return b


# --- Hauptseite -------------------------------------------------------------------------------------

func _page_main() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var logo := UI.vbox(-14)
	root.add_child(logo)
	logo.position = Vector2(44, 22)
	var l1 := UI.label("LUMOS PARTY", 88, Color.WHITE, true, 18)
	l1.add_theme_color_override("font_outline_color", Color("#5a1aa0"))
	logo.add_child(l1)
	var l2 := UI.label("& NITRO DASH", 44, UI.GOLD, true, 12)
	logo.add_child(l2)
	_logo = logo
	var tw := logo.create_tween().set_loops()
	tw.tween_property(logo, "position:y", 28.0, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(logo, "position:y", 22.0, 1.6).set_trans(Tween.TRANS_SINE)
	# Fünf große Modus-Kacheln – wie auf der Konsole
	var v := UI.vbox(10)
	root.add_child(v)
	v.position = Vector2(48, 170)
	var items := [
		["Lumos Party", "Das Brettspiel mit Freunden", "dice", Color("#ff4fb8"), "party"],
		["Nitro Dash", "Arcade-Kart-Rennen & Grand Prix", "bolt", Color("#2f9bff"), "race"],
		["Minispiele", "Alle Minispiele frei spielen · Marathon", "star", Color("#2ecc71"), "minigames"],
		["Abenteuer & Modi", "Reise · Küche · Athlon · Wolkenturm · Kolosseum", "trophy", Color("#ff9f1a"), "modes"],
		["Online", "Mit Freunden über Raumcode", "globe", Color("#00b894"), "online"],
	]
	var desc := UI.label("", 22, Color(1, 1, 1, 0.92), true, 8)
	for it in items:
		var b := _mode_tile(String(it[0]), String(it[1]), String(it[2]), it[3])
		var target: String = it[4]
		var sub: String = it[1]
		b.pressed.connect(func() -> void: show_page(target))
		b.focus_entered.connect(func() -> void: desc.text = sub)
		v.add_child(b)
	# Kleine runde Knöpfe: Einstellungen, Credits, Profil
	var small := UI.hbox(14)
	root.add_child(small)
	UI.place(small, Control.PRESET_BOTTOM_LEFT, Vector2(48, -92), Vector2(0, 64))
	for sb in [["gear", "Einstellungen", "settings"], ["heart", "Credits", "credits"], ["user", "Profil", "profile"]]:
		var rb := UI.button("", Color("#4a3a7a"), 20, 64)
		rb.icon = UI.icon_tex(String(sb[0]), 30)
		rb.custom_minimum_size = Vector2(64, 64)
		rb.tooltip_text = String(sb[1])
		var tgt: String = sb[2]
		var label: String = sb[1]
		rb.pressed.connect(func() -> void: show_page(tgt))
		rb.focus_entered.connect(func() -> void: desc.text = label)
		small.add_child(rb)
	# Konto-Pille oben rechts
	var acc := UI.button("", Color("#3a2a6a"), 22, 0.0)
	acc.icon = UI.icon_tex("user", 28)
	acc.text = ("  " + Account.display_name()) if Account.signed_in() else "  Anmelden"
	acc.pressed.connect(func() -> void: show_page("profile"))
	root.add_child(acc)
	UI.place(acc, Control.PRESET_TOP_RIGHT, Vector2(-300, 24), Vector2(276, 56))
	# Untere Leiste: Beschreibung des gewählten Eintrags + Bedienhilfe
	var bar := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.12, 0.06, 0.25, 0.72)
	bs.set_corner_radius_all(22)
	bs.set_content_margin_all(10)
	bar.add_theme_stylebox_override("panel", bs)
	root.add_child(bar)
	UI.place(bar, Control.PRESET_CENTER_BOTTOM, Vector2(-330, -70), Vector2(660, 52))
	var hb := UI.hbox(18)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(hb)
	hb.add_child(desc)
	hb.add_child(UI.prompt("a", "Auswählen", 20))
	hb.add_child(UI.prompt("b", "Zurück", 20))
	var foot := UI.label("v%s" % ProjectSettings.get_setting("application/config/version", "1.0"), 16, Color(1, 1, 1, 0.55))
	root.add_child(foot)
	UI.place(foot, Control.PRESET_BOTTOM_RIGHT, Vector2(-90, -32), Vector2(80, 24))
	return root


## Große Modus-Kachel: Icon links, Titel + Untertitel – fokussiert leicht vergrößert.
func _mode_tile(title: String, sub: String, icon: String, col: Color) -> Button:
	var b := UI.button("", col, 30, 430.0)
	b.custom_minimum_size = Vector2(430, 76)
	var h := UI.hbox(14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	h.offset_left = 18
	var ic := TextureRect.new()
	ic.texture = UI.icon_tex(icon, 46, Color.WHITE)
	ic.custom_minimum_size = Vector2(46, 46)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var tv := UI.vbox(-2)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tv)
	var tl := UI.label(title, 30, Color.WHITE, true, 8)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(tl)
	var sl := UI.label(sub, 17, Color(1, 1, 1, 0.85), true, 5)
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(sl)
	b.focus_entered.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
		b.create_tween().tween_property(b, "scale", Vector2(1.04, 1.04), 0.12))
	b.focus_exited.connect(func() -> void: b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.12))
	return b


# --- Profil & Anmeldung -----------------------------------------------------------------------------------

var _need_credentials := false


func _page_profile() -> Control:
	var arr := _side_panel("Profil", 720)
	var v: VBoxContainer = arr[1]
	if not Account.changed.is_connected(_on_account_changed):
		Account.changed.connect(_on_account_changed)
		Account.bridge_event.connect(func(t: String, _d: Variant) -> void:
			if t == "lumos_resume_failed" and _page and _page.name == "profile":
				_need_credentials = true
				_on_account_changed())
	if Account.signed_in():
		_profile_view(v)
	else:
		_login_view(v)
	_back_button(v)
	return arr[0]


func _on_account_changed() -> void:
	if _page and _page.name == "profile":
		show_page("profile")


func _login_view(v: VBoxContainer) -> void:
	var lumos := Account.lumos_available
	var head := UI.label("Lumos-Gerät erkannt – melde dich mit deiner Lumos-ID an." if lumos else "Melde dich an, um Bestzeiten, Freischaltungen und Statistiken geräteübergreifend zu sichern.", 22, Color(1, 1, 1, 0.85))
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size.x = 640
	v.add_child(head)
	if Account.busy:
		v.add_child(UI.label("Anmeldung läuft …", 28, UI.GOLD, true))
	if lumos and not _need_credentials:
		var one := UI.button("  Login mit Lumos Cloud", Color("#7b3cff"), 32, 520)
		one.icon = UI.icon_tex("user", 34)
		one.custom_minimum_size.y = 72
		one.pressed.connect(func() -> void: Account.resume_lumos())
		v.add_child(one)
		var reg := UI.button("Neue Lumos-ID registrieren", Color("#5a4a80"), 24, 520)
		reg.pressed.connect(func() -> void:
			_need_credentials = true
			show_page("profile"))
		v.add_child(reg)
	else:
		if Account.is_web and not lumos:
			var g := UI.button("  Mit Google anmelden", Color("#ffffff"), 30, 520)
			g.add_theme_color_override("font_color", Color("#202124"))
			g.add_theme_color_override("font_hover_color", Color("#202124"))
			g.add_theme_color_override("font_focus_color", Color("#202124"))
			g.icon = UI.icon_tex("globe", 30, Color("#4285f4"))
			g.custom_minimum_size.y = 66
			g.pressed.connect(func() -> void: Account.login_google())
			v.add_child(g)
			v.add_child(UI.label("oder mit E-Mail und Passwort", 20, Color(1, 1, 1, 0.6)))
		var email := LineEdit.new()
		email.placeholder_text = "E-Mail"
		email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
		email.custom_minimum_size = Vector2(520, 54)
		email.add_theme_font_size_override("font_size", 24)
		v.add_child(email)
		var pw := LineEdit.new()
		pw.placeholder_text = "Passwort"
		pw.secret = true
		pw.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
		pw.custom_minimum_size = Vector2(520, 54)
		pw.add_theme_font_size_override("font_size", 24)
		v.add_child(pw)
		var name_edit := LineEdit.new()
		name_edit.placeholder_text = "Anzeigename (nur bei Registrierung)"
		name_edit.custom_minimum_size = Vector2(520, 54)
		name_edit.add_theme_font_size_override("font_size", 24)
		name_edit.text = Game.hero(Game.players[0].hero).name
		v.add_child(name_edit)
		var row := UI.hbox(12)
		var login := UI.button("Anmelden", Color("#2ecc71"), 28, 250)
		var register := UI.button("Registrieren", Color("#2f9bff"), 28, 250)
		login.pressed.connect(func() -> void:
			if lumos:
				Account.login_lumos(email.text.strip_edges(), pw.text)
			else:
				Account.login_email(email.text.strip_edges(), pw.text))
		register.pressed.connect(func() -> void:
			if lumos:
				Account.register_lumos(email.text.strip_edges(), pw.text, name_edit.text.strip_edges())
			else:
				Account.register_email(email.text.strip_edges(), pw.text, name_edit.text.strip_edges()))
		pw.text_submitted.connect(func(_t: String) -> void: login.pressed.emit())
		row.add_child(login)
		row.add_child(register)
		v.add_child(row)
		if not lumos:
			var forgot := UI.button("Passwort vergessen?", Color("#5a4a80"), 20, 260)
			forgot.pressed.connect(func() -> void: Account.reset_password(email.text.strip_edges()))
			v.add_child(forgot)
		else:
			v.add_child(UI.label("Lumos Cloud: %s" % Account.lumos_url, 18, Color(1, 1, 1, 0.5)))
	var guest := UI.button("Als Gast spielen", Color("#5a4a80"), 24, 520)
	guest.pressed.connect(func() -> void:
		Account.play_as_guest()
		show_page("main"))
	v.add_child(guest)


func _profile_view(v: VBoxContainer) -> void:
	var u: Dictionary = Account.user
	var head := UI.hbox(14)
	head.add_child(UI.icon_rect("user", 64, UI.GOLD))
	var hv := UI.vbox(0)
	hv.add_child(UI.label(Account.display_name(), 36, Color.WHITE, true))
	var sub := "%s · %s" % [Account.provider_label(), u.get("email", "")]
	if u.has("friend_code"):
		sub += " · Freundescode " + String(u.friend_code)
	hv.add_child(UI.label(sub, 20, Color(1, 1, 1, 0.7)))
	head.add_child(hv)
	v.add_child(head)
	var st: Dictionary = Account.profile.get("stats", {})
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 24)
	var pairs := [["Rennen", "races"], ["Siege", "race_wins"], ["GP-Siege", "gp_wins"], ["Partys", "parties"],
		["Party-Siege", "party_wins"], ["Minispiele", "minigames"], ["Minispiel-Siege", "minigame_wins"]]
	for pr in pairs:
		var cell := UI.vbox(-4)
		cell.add_child(UI.label(str(int(st.get(pr[1], 0))), 34, UI.GOLD, true))
		cell.add_child(UI.label(pr[0], 18, Color(1, 1, 1, 0.7)))
		grid.add_child(cell)
	v.add_child(grid)
	v.add_child(UI.label("Bestzeiten (Zeitfahren)", 28, UI.ACCENT2, true))
	var hs: Dictionary = Account.profile.get("highscores", {})
	if hs.is_empty():
		v.add_child(UI.label("Noch keine – probier den Zeitfahr-Modus in Nitro Dash!", 20, Color(1, 1, 1, 0.6)))
	for t in Game.TRACKS:
		if hs.has(t.id):
			var row := UI.hbox(12)
			var n := UI.label(t.name, 22, Color.WHITE, true)
			n.custom_minimum_size.x = 320
			row.add_child(n)
			var tt := float(hs[t.id])
			row.add_child(UI.label("%d:%05.2f" % [int(tt) / 60, fmod(tt, 60.0)], 22, UI.GOLD, true))
			v.add_child(row)
	v.add_child(UI.label("Freischaltungen", 28, UI.ACCENT2, true))
	for id in Account.UNLOCKS:
		var info: Dictionary = Account.UNLOCKS[id]
		var have := Account.has_unlock(id)
		var row2 := UI.hbox(10)
		row2.add_child(UI.icon_rect("check" if have else "lock", 26, Color("#7dff9a") if have else Color(1, 1, 1, 0.45)))
		var nl := UI.label(info.name, 22, Color.WHITE if have else Color(1, 1, 1, 0.55), true)
		nl.custom_minimum_size.x = 240
		row2.add_child(nl)
		row2.add_child(UI.label(info.desc, 18, Color(1, 1, 1, 0.6)))
		v.add_child(row2)
	var out := UI.button("Abmelden", Color("#c0392b"), 24, 260)
	out.pressed.connect(func() -> void:
		_need_credentials = false
		Account.logout())
	v.add_child(out)


# --- Online ----------------------------------------------------------------------------------------------

func _page_online() -> Control:
	return OnlinePage.new().build(self)


# --- Abenteuer & Modi ----------------------------------------------------------------------------------

var _athlon_size := 0


func _mode_card(v: VBoxContainer, title: String, col: Color, icon: String, desc: String) -> VBoxContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.55)
	sb.bg_color.a = 0.85
	sb.border_color = col
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", sb)
	v.add_child(card)
	var inner := UI.vbox(8)
	card.add_child(inner)
	var head := UI.hbox(12)
	head.add_child(UI.icon_rect(icon, 40, col.lightened(0.3)))
	head.add_child(UI.label(title, 34, col.lightened(0.35), true, 8))
	inner.add_child(head)
	var d := UI.label(desc, 20, Color(1, 1, 1, 0.85))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(620, 0)
	inner.add_child(d)
	return inner


func _page_modes() -> Control:
	var arr := _side_panel("Abenteuer & Modi", 700)
	var v: VBoxContainer = arr[1]
	var stars := Game.stat("journey_ministars", 0)
	var j := _mode_card(v, "Partyhelfer-Reise", Color("#ff9f1a"), "star",
		"Einzelspieler-Abenteuer auf der Pusteblumen-Insel: Hilf den Inselbewohnern mit Minispiel-Aufträgen, sammle Mini-Sterne und stelle dich am Ende Pustebacke!")
	var jp := UI.label("Fortschritt: %d Mini-Sterne" % maxi(0, stars), 20, UI.GOLD, true)
	j.add_child(jp)
	var jb := UI.button("Reise starten" if stars <= 0 else "Reise fortsetzen", Color("#ff9f1a"), 28, 360)
	jb.pressed.connect(func() -> void:
		_apply_players()
		Game.mode = "journey"
		Router.goto("res://scenes/modes/Journey.tscn"))
	j.add_child(jb)
	var k := _mode_card(v, "Rhythmus-Küche", Color("#ff7ad9"), "music",
		"1–4 Köche, ein Fünf-Gänge-Menü, alles im Takt: schnippeln, rühren, Pfannkuchen wenden, würzen und Torte verzieren. Gemeinsam zur Sterne-Küche!")
	var best := Game.stat("rhythm_kitchen_grade", -1)
	if best >= 0:
		k.add_child(UI.label("Beste Küchen-Note: %s" % ["C", "B", "A", "S"][best], 20, UI.GOLD, true))
	var kb := UI.button("Ab in die Küche!", Color("#ff7ad9"), 28, 360)
	kb.pressed.connect(func() -> void:
		_apply_players()
		Game.mode = "modes"
		Router.goto(Game.minigame_info("rhythm_kitchen").scene))
	k.add_child(kb)
	var a := _mode_card(v, "Lumos-Athlon", Color("#3fa7ff"), "trophy",
		"Großer Wettlauf um die Wiese: Alle spielen gleichzeitig schnelle Solo-Herausforderungen, jede Münze bringt ein Feld weiter. Online bis zu 20 Spieler (Athlon-Raum im Online-Menü)!")
	var sz := Stepper.new().setup(["8 Läufer", "12 Läufer", "20 Läufer"], _athlon_size, 220, Color("#3fa7ff"))
	sz.changed.connect(func(i: int) -> void: _athlon_size = i)
	a.add_child(_row("Feld", sz))
	var ab := UI.button("Auf die Plätze!", Color("#3fa7ff"), 28, 360)
	ab.pressed.connect(func() -> void:
		_apply_players()
		Game.settings["athlon_size"] = [8, 12, 20][_athlon_size]
		Game.mode = "athlon"
		Router.goto("res://scenes/modes/Athlon.tscn"))
	a.add_child(ab)
	var t := _mode_card(v, "Der Wolkenturm", Color("#6fd08c"), "star",
		"Ein Brettspiel in die Höhe: Wendelwege um einen verwunschenen Pflanzenturm, Ranken-Abkürzungen, Wolkenlift und Aufwind. Wer zuerst oben ist, holt den Gipfelstern – hoch oben zählt alles doppelt!")
	var tb := UI.button("Hinauf in die Wolken!", Color("#6fd08c"), 28, 360)
	tb.pressed.connect(func() -> void:
		_apply_players()
		Game.start_party("tower", [5, 10, 15][_party_rounds], Game.PARTY_MODES[_party_mode].id)
		Router.goto("res://scenes/party/PartyBoard.tscn"))
	t.add_child(tb)
	var c := _mode_card(v, "Das Kolosseum-Turnier", Color("#ff7a59"), "trophy",
		"Acht Champions, ein Pokal: Viertelfinale, Halbfinale, Finale – jedes Match ist ein Duell-Minispiel. Großer Einlauf durchs Tor, und das ganze Publikum besteht aus Figuren des Spiels.")
	var cb := UI.button("In die Arena!", Color("#ff7a59"), 28, 360)
	cb.pressed.connect(func() -> void:
		_apply_players()
		if Game.has_meta("colosseum"):
			Game.remove_meta("colosseum")
		Game.mode = "colosseum"
		Router.goto("res://scenes/modes/Colosseum.tscn"))
	c.add_child(cb)
	v.add_child(UI.label("Spieler", 32, UI.ACCENT2, true))
	_players_editor(v)
	_back_button(v)
	return arr[0]


# --- Party-Setup ----------------------------------------------------------------------------------------

func _page_party() -> Control:
	var arr := _side_panel("Lumos Party", 700)
	var v: VBoxContainer = arr[1]
	var board_names := Game.BOARDS.map(func(b: Dictionary) -> String: return b.name)
	var board_desc := UI.label(Game.BOARDS[_party_board].desc, 22, Color(1, 1, 1, 0.85))
	board_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board_desc.custom_minimum_size = Vector2(620, 60)
	var bs := Stepper.new().setup(board_names, _party_board, 340, Color("#ff4fb8"))
	bs.changed.connect(func(i: int) -> void:
		_party_board = i
		board_desc.text = Game.BOARDS[i].desc)
	v.add_child(_row("Spielbrett", bs))
	v.add_child(board_desc)
	var mode_desc := UI.label(Game.PARTY_MODES[_party_mode].desc, 20, Color(1, 1, 1, 0.75))
	mode_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_desc.custom_minimum_size = Vector2(620, 44)
	var ms := Stepper.new().setup(Game.PARTY_MODES.map(func(m: Dictionary) -> String: return m.name), _party_mode, 340, Color("#ff4fb8"))
	ms.changed.connect(func(i: int) -> void:
		_party_mode = i
		mode_desc.text = Game.PARTY_MODES[i].desc)
	v.add_child(_row("Modus", ms))
	v.add_child(mode_desc)
	var rs := Stepper.new().setup(["5 Runden", "10 Runden", "15 Runden"], _party_rounds, 220, Color("#ff4fb8"))
	rs.changed.connect(func(i: int) -> void: _party_rounds = i)
	v.add_child(_row("Länge", rs))
	v.add_child(UI.label("Spieler", 32, UI.ACCENT2, true))
	_players_editor(v)
	var start := UI.button("Party starten!", Color("#ff4fb8"), 38, 400)
	start.custom_minimum_size.y = 76
	start.pressed.connect(_start_party)
	v.add_child(start)
	_back_button(v)
	return arr[0]


func _players_editor(v: VBoxContainer) -> void:
	_hero_steppers.clear()
	_cpu_steppers.clear()
	var hero_names := Game.hero_list().map(func(h: Dictionary) -> String: return h.name)
	var pads := Input.get_connected_joypads().size()
	for i in 4:
		var p: Dictionary = Game.players[i]
		var row := UI.hbox(10)
		var tag := UI.label("P%d" % (i + 1), 30, Game.player_color(i), true)
		tag.custom_minimum_size.x = 52
		row.add_child(tag)
		var hs := Stepper.new().setup(hero_names, _hero_index(p.hero), 230, Game.player_color(i).darkened(0.2))
		row.add_child(hs)
		_hero_steppers.append(hs)
		var opts := ["Mensch"] + Game.CPU_LEVELS.map(func(l: String) -> String: return "CPU " + l) if i == 0 else Game.CPU_LEVELS.map(func(l: String) -> String: return "CPU " + l) + (["Mensch (Pad %d)" % (i + 1)] if pads > i else [])
		var start_idx := 0
		if i == 0:
			start_idx = 0 if not p.cpu else 1 + int(p.cpu_level)
		else:
			start_idx = int(p.cpu_level) if p.cpu else (3 if pads > i else 1)
		var cs := Stepper.new().setup(opts, start_idx, 170, Color("#5a4a80"))
		row.add_child(cs)
		_cpu_steppers.append(cs)
		v.add_child(row)


func _hero_index(id: String) -> int:
	for i in Game.hero_list().size():
		if Game.hero_list()[i].id == id:
			return i
	return 0


func _apply_players() -> void:
	for i in 4:
		var p: Dictionary = Game.players[i]
		p.hero = Game.hero_list()[_hero_steppers[i].index].id
		p.name = Game.hero_list()[_hero_steppers[i].index].name
		var label: String = _cpu_steppers[i].value()
		p.cpu = not label.begins_with("Mensch")
		if p.cpu:
			p.cpu_level = Game.CPU_LEVELS.find(label.trim_prefix("CPU "))


func _row(title: String, ctrl: Control) -> Control:
	var h := UI.hbox(16)
	var l := UI.label(title, 28, Color.WHITE, true)
	l.custom_minimum_size.x = 180
	h.add_child(l)
	h.add_child(ctrl)
	return h


func _start_party() -> void:
	_apply_players()
	Game.start_party(Game.BOARDS[_party_board].id, [5, 10, 15][_party_rounds], Game.PARTY_MODES[_party_mode].id)
	Router.goto("res://scenes/party/PartyBoard.tscn")


# --- Nitro-Dash-Setup ------------------------------------------------------------------------------------

func _page_race() -> Control:
	var arr := _side_panel("Nitro Dash", 700)
	var v: VBoxContainer = arr[1]
	var names := Game.TRACKS.map(func(t: Dictionary) -> String: return t.name)
	var cur := 0
	for i in Game.TRACKS.size():
		if Game.TRACKS[i].id == Game.race_cfg.track:
			cur = i
	var desc := UI.label(Game.TRACKS[cur].desc, 22, Color(1, 1, 1, 0.85))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(620, 50)
	var modes := ["Einzelrennen", "Grand Prix", "Zeitfahren"]
	var mode_ids := ["single", "gp", "time"]
	var cur_mode := maxi(0, mode_ids.find(String(Game.race_cfg.get("mode", "single"))))
	var ms := Stepper.new().setup(modes, cur_mode, 320, Color("#2f9bff"))
	v.add_child(_row("Modus", ms))
	var ts := Stepper.new().setup(names, cur, 320, Color("#2f9bff"))
	ts.changed.connect(func(i: int) -> void:
		Game.race_cfg.track = Game.TRACKS[i].id
		desc.text = Game.TRACKS[i].desc + _record_text(Game.TRACKS[i].id))
	var track_row := _row("Strecke", ts)
	v.add_child(track_row)
	var cup_names: Array = []
	for ci in Game.CUPS.size():
		cup_names.append(String(Game.CUPS[ci].name) + ("  (gesperrt)" if ci == 2 and not Account.has_unlock("mega_cup") else ""))
	var cups := Stepper.new().setup(cup_names, int(Game.race_cfg.get("cup", 0)), 380, Color("#2f9bff"))
	var cup_row := _row("Cup", cups)
	v.add_child(cup_row)
	v.add_child(desc)
	var cup_text := func(i: int) -> String:
		var names_in_cup: Array = (Game.CUPS[i].tracks as Array).map(func(id: String) -> String: return Game.track_info(id).name)
		return "Vier Rennen, Punkte 15-12-10-8-6-4-2-1: " + " · ".join(names_in_cup) if names_in_cup.size() <= 4 else "Acht Rennen am Stück: " + " · ".join(names_in_cup)
	cups.changed.connect(func(i: int) -> void:
		Game.race_cfg.cup = i
		desc.text = cup_text.call(i))
	var apply_mode := func(i: int) -> void:
		Game.race_cfg.mode = mode_ids[i]
		track_row.visible = mode_ids[i] != "gp"
		cup_row.visible = mode_ids[i] == "gp"
		if mode_ids[i] == "gp":
			desc.text = cup_text.call(int(Game.race_cfg.get("cup", 0)))
		elif mode_ids[i] == "time":
			desc.text = "Allein gegen die Uhr – nur Nitro-Boxen. Bestzeiten werden gespeichert." + _record_text(String(Game.race_cfg.track))
		else:
			desc.text = Game.TRACKS[ts.index].desc + _record_text(String(Game.race_cfg.track))
	ms.changed.connect(apply_mode)
	apply_mode.call(cur_mode)
	var laps := Stepper.new().setup(["2 Runden", "3 Runden", "5 Runden"], [2, 3, 5].find(Game.race_cfg.laps), 220, Color("#2f9bff"))
	laps.changed.connect(func(i: int) -> void: Game.race_cfg.laps = [2, 3, 5][i])
	v.add_child(_row("Runden", laps))
	var lvl := Stepper.new().setup(Game.CPU_LEVELS, Game.race_cfg.cpu_level, 220, Color("#2f9bff"))
	lvl.changed.connect(func(i: int) -> void: Game.race_cfg.cpu_level = i)
	v.add_child(_row("Gegner", lvl))
	v.add_child(UI.label("Fahrer", 32, UI.ACCENT2, true))
	_players_editor(v)
	var hint := UI.label("Drift halten (R / Shift) und lenken: Funken wechseln von Blau über Orange zu Regenbogen.\nItems: Kuchendeckel · Homing-Kanonenkugel · Megafon-Schock · Piraten-Anker · Nitro", 20, Color(1, 1, 1, 0.75))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 620
	v.add_child(hint)
	var start := UI.button("Rennen starten!", Color("#2f9bff"), 38, 400)
	start.custom_minimum_size.y = 76
	start.pressed.connect(func() -> void:
		_apply_players()
		if Game.race_cfg.mode == "gp":
			if int(Game.race_cfg.cup) == 2 and not Account.has_unlock("mega_cup"):
				Account.toast("Mega-Cup gesperrt – gewinne zuerst den Lumos- oder Sternen-Cup!", Color("#ffcc33"))
				return
			Game.start_gp(int(Game.race_cfg.cup))
		Game.mode = "race"
		Router.goto("res://scenes/racer/NitroDash.tscn"))
	v.add_child(start)
	_back_button(v)
	return arr[0]


# --- Minispiel-Arena --------------------------------------------------------------------------------------

func _page_minigames() -> Control:
	var arr := _side_panel("Minispiel-Arena", 800)
	var v: VBoxContainer = arr[1]
	var desc := UI.label("Wähle eines von %d Minispielen." % Game.MINIGAMES.size(), 22, Color(1, 1, 1, 0.85))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(700, 64)
	v.add_child(desc)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var colors := [Color("#ff4fb8"), Color("#2f9bff"), Color("#2ecc71"), Color("#ff9f1a"), Color("#7b3cff")]
	var kind_icon := {"survival": "heart", "score": "star", "race": "bolt"}
	for i in Game.MINIGAMES.size():
		var m: Dictionary = Game.MINIGAMES[i]
		var b := UI.button(m.name, colors[i % colors.size()], 21, 228)
		b.custom_minimum_size.y = 56
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.icon = UI.icon_tex(kind_icon.get(m.kind, "star"), 26)
		b.expand_icon = false
		b.focus_entered.connect(func() -> void: desc.text = "%s – %s" % [m.name, m.desc])
		b.mouse_entered.connect(func() -> void: desc.text = "%s – %s" % [m.name, m.desc])
		b.pressed.connect(func() -> void: _play_minigame(m.id))
		grid.add_child(b)
	var extra := UI.hbox(12)
	var rnd := UI.button("Zufall!", Color("#ffcc33"), 26, 230)
	rnd.pressed.connect(func() -> void: _play_minigame(Game.MINIGAMES[randi() % Game.MINIGAMES.size()].id))
	extra.add_child(rnd)
	for n in [5, 10]:
		var mb := UI.button("Marathon (%d)" % n, Color("#ff4fb8"), 26, 230)
		mb.icon = UI.icon_tex("trophy", 26)
		mb.pressed.connect(func() -> void:
			if not _hero_steppers.is_empty():
				_apply_players()
			Game.start_marathon(n)
			Router.goto("res://scenes/menu/MarathonHub.tscn"))
		extra.add_child(mb)
	v.add_child(extra)
	v.add_child(UI.label("Spieler", 30, UI.ACCENT2, true))
	_players_editor(v)
	_back_button(v)
	return arr[0]


func _record_text(track_id: String) -> String:
	var r := Game.record_for(track_id)
	if r.is_empty() or float(r.total) == INF:
		return ""
	var t := float(r.total)
	return "\nBestzeit: %d:%05.2f" % [int(t) / 60, fmod(t, 60.0)]


func _play_minigame(id: String) -> void:
	if not _hero_steppers.is_empty():
		_apply_players()
	Game.mode = "free_play"
	Router.goto(Game.minigame_info(id).scene)


# --- Einstellungen -----------------------------------------------------------------------------------------

func _page_settings() -> Control:
	var arr := _side_panel("Einstellungen", 700)
	var v: VBoxContainer = arr[1]
	v.add_child(_slider("Musik", "music"))
	v.add_child(_slider("Kart-Lenkung", "steer_sens", 0.5, 1.5))
	v.add_child(_slider("Effekte", "sfx"))
	v.add_child(_slider("Ansager", "voice"))
	v.add_child(_slider("Kamera-Wackeln", "screen_shake"))
	v.add_child(_toggle("Haptik / Vibration", "haptics"))
	v.add_child(_toggle("Auto-Gas (Touch-Racer)", "auto_accel"))
	var qkeys := ["auto", "low", "medium", "high", "ultra"]
	var qnames := ["Automatisch (%s)" % Gfx.PRESETS[Gfx.detected].label, "Niedrig", "Mittel", "Hoch", "Ultra"]
	var q := Stepper.new().setup(qnames, maxi(0, qkeys.find(Game.settings.quality)), 300)
	q.changed.connect(func(i: int) -> void:
		Game.settings.quality = qkeys[i]
		Game.save_settings())
	v.add_child(_row("Grafik", q))
	v.add_child(_toggle("Dynamische Auflösung (stabile 60 FPS)", "dynamic_res"))
	v.add_child(_toggle("FPS anzeigen", "show_fps"))
	v.add_child(_toggle("Split-Screen für mehrere Fahrer", "split_screen"))
	if not OS.has_feature("web"):
		v.add_child(_toggle("Weitere Monitore automatisch nutzen (%d erkannt)" % DisplayServer.get_screen_count(), "multi_display"))
	var hw: Dictionary = Gfx.hardware
	var hw_label := UI.label("Erkannt: %d Kerne · %s · %s" % [int(hw.get("cores", 0)), ("%.0f GB RAM" % hw.memory_gb) if float(hw.get("memory_gb", 0)) > 0 else "RAM unbekannt", String(hw.get("gpu", "GPU unbekannt")).substr(0, 40)], 18, Color(1, 1, 1, 0.6))
	v.add_child(hw_label)
	v.add_child(UI.label("Touch-Steuerung", 30, UI.ACCENT2, true))
	v.add_child(_slider("Button-Größe", "touch_scale", 0.6, 1.5))
	v.add_child(_slider("Deckkraft", "touch_opacity", 0.2, 1.0))
	var edit := UI.button("Layout anpassen", Color("#2f9bff"), 28, 360)
	edit.pressed.connect(func() -> void: show_page("touch_edit"))
	v.add_child(edit)
	var help := UI.label("Tastatur: WASD/Pfeile · Leertaste = A · K = B · E = Item · Shift = Drift · Esc = Pause\nGamepad: Stick/Steuerkreuz · A · B · X/LB = Item · RB/RT = Drift · Start = Pause", 19, Color(1, 1, 1, 0.75))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x = 620
	v.add_child(help)
	_back_button(v)
	return arr[0]


func _slider(title: String, key: String, mn := 0.0, mx := 1.0) -> Control:
	var h := UI.hbox(16)
	var l := UI.label(title, 26, Color.WHITE, true)
	l.custom_minimum_size.x = 250
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 0.05
	s.value = float(Game.settings[key])
	s.custom_minimum_size = Vector2(320, 44)
	s.value_changed.connect(func(val: float) -> void:
		Game.settings[key] = val
		Game.save_settings()
		if key == "sfx":
			Audio.sfx("coin_single"))
	h.add_child(s)
	return h


func _toggle(title: String, key: String) -> Control:
	var c := CheckButton.new()
	c.text = title
	c.button_pressed = bool(Game.settings[key])
	c.add_theme_font_size_override("font_size", 26)
	c.toggled.connect(func(on: bool) -> void:
		Audio.sfx("ui_toggle", null, -2.0, 1.15 if on else 0.9, 0.0)
		Game.settings[key] = on
		Game.save_settings()
		Audio.sfx("ui_toggle"))
	return c


func _page_touch_edit() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	InputHub.touch_controls.call("start_edit")
	var box := UI.vbox(10)
	root.add_child(box)
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-260, 110)
	var info := UI.label("Ziehe die Buttons an die gewünschte Position.", 28, Color.WHITE, true)
	box.add_child(info)
	var row := UI.hbox(12)
	box.add_child(row)
	var done := UI.button("Fertig", Color("#2ecc71"), 30, 200)
	done.pressed.connect(func() -> void:
		InputHub.touch_controls.call("stop_edit")
		show_page("settings"))
	row.add_child(done)
	var reset := UI.button("Zurücksetzen", Color("#ff5c7a"), 30, 240)
	reset.pressed.connect(func() -> void: InputHub.touch_controls.call("reset_layout"))
	row.add_child(reset)
	return root


func _page_credits() -> Control:
	var arr := _side_panel("Credits", 720)
	var v: VBoxContainer = arr[1]
	var txt := """[b]Lumos Party & Nitro Dash[/b] – exklusiver Titel für Lumos OS
Engine: Godot 4 (MIT-Lizenz) · GL-Compatibility / WebGL2

[b]3D-Modelle[/b] (CC0): Kenney – Pirate, Platformer, Castle, Graveyard, Racing, Car, Toy Car, Survival, Space, Nature, Mini Arena, Mini Arcade, Tower Defense, Modular Cave, Watercraft, Fantasy Town, Holiday, Mini Characters, Cube Pets
KayKit (CC0, Kay Lousberg) – Adventurers, Character Animations, Dungeon Pack, Mini-Game Variety Pack, Board Game Bits, Holiday Bits, Forest Nature, RPG Tools

[b]Audio[/b] (CC0): Kenney – Impact, Interface, Digital, RPG, Sci-Fi, UI, Music Jingles, Voiceover
[b]UI-Sounds[/b] (CC BY 4.0): „UI Sound Effects by lolurio“ (lolurio.itch.io) · „Cute, Cozy & Magical UI SFX“ von Nomagician Music (nomagician.itch.io)
Musik: ausschließlich die Lumos-Soundtracks (Brett-, Menü- & Minispiel-Tracks; geschnitten, getaktet & geloopt mit tools/audio/build_music.py)
Cartoon-SFX: tools/compose_sfx.py

[b]Schriften[/b] (SIL OFL 1.1): Lilita One (Juan Montoreano), Fredoka (The Fredoka Project Authors)
[b]Icons[/b] (CC0): Kenney – Input Prompts, Medals, Crosshairs, Board Game Info"""
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.text = txt
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(660, 0)
	rt.add_theme_font_override("normal_font", UI.body_font())
	rt.add_theme_font_override("bold_font", UI.title_font())
	rt.add_theme_font_size_override("normal_font_size", 21)
	rt.add_theme_font_size_override("bold_font_size", 24)
	v.add_child(rt)
	_back_button(v)
	return arr[0]
