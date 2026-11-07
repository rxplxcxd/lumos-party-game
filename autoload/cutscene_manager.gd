extends Node
## Globaler CutsceneManager.
##
## * Reagiert auf EventBus.cutscene_requested oder direkte Aufrufe von play().
## * Lädt Cutscene-Szenen aus res://scenes/cutscenes/<Id>.tscn (Skript mit run(director, ctx)).
## * Übernimmt nahtlos von der Gameplay-Kamera, fährt mit einer eigenen Camera3D
##   (Tween-Fahrten, Orbits, Spline-Pfade, FOV-Dyna-Zoom, Shake) und blendet zurück.
## * Overlay: Letterbox-Balken, Titelkarten, Untertitel, Blitz, Abblende, 3-2-1-LOS-Countdown.
## * A gedrückt halten spult vor (Zeit x3).

signal finished(id: String)

const LETTERBOX_H := 0.11

var active := false
var current_id := ""
var cam: Camera3D
var skippable := true

var _prev_cam: Camera3D
var _layer: CanvasLayer
var _bar_top: ColorRect
var _bar_bot: ColorRect
var _flash: ColorRect
var _title: Label
var _subtitle: Label
var _hint: Label
var _big: Label
var _title_font: Font
var _body_font: Font
var _queue: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_title_font = load(Assets.FONT_TITLE)
	_body_font = load(Assets.FONT_BODY)
	_build_overlay()
	EventBus.cutscene_requested.connect(func(id: String, ctx: Dictionary) -> void: play(id, ctx))


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 50
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	_bar_top = _mk_bar(root, true)
	_bar_bot = _mk_bar(root, false)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)
	_title = _mk_label(root, _title_font, 92, 0.38)
	_subtitle = _mk_label(root, _body_font, 34, 0.52)
	_big = _mk_label(root, _title_font, 220, 0.42)
	_hint = Label.new()
	_hint.add_theme_font_override("font", _body_font)
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_hint.text = "Ⓐ halten: Vorspulen"
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.position = Vector2(-260, -40)
	_hint.size = Vector2(240, 30)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.visible = false
	root.add_child(_hint)


func _mk_bar(root: Control, top: bool) -> ColorRect:
	var b := ColorRect.new()
	b.color = Color(0.02, 0.01, 0.05, 1)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.anchor_left = 0
	b.anchor_right = 1
	if top:
		b.anchor_top = 0
		b.anchor_bottom = 0
	else:
		b.anchor_top = 1
		b.anchor_bottom = 1
	b.offset_top = 0
	b.offset_bottom = 0
	root.add_child(b)
	return b


func _mk_label(root: Control, font: Font, size: int, y_anchor: float) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.2))
	l.add_theme_constant_override("outline_size", int(size * 0.16))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_y", int(size * 0.06))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.anchor_left = 0
	l.anchor_right = 1
	l.anchor_top = y_anchor
	l.anchor_bottom = y_anchor
	l.offset_top = -size
	l.offset_bottom = size
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible = false
	root.add_child(l)
	return l


func _process(_delta: float) -> void:
	if active and skippable:
		var ff := false
		for i in 4:
			if InputHub.is_slot_human(i) and InputHub.held(i, "a"):
				ff = true
		Juice.base_time_scale = 3.0 if ff else 1.0
	elif Juice.base_time_scale != 1.0 and not active:
		Juice.base_time_scale = 1.0


# --- Ablaufsteuerung ----------------------------------------------------------------------------

## Spielt eine Cutscene-Szene und wartet, bis sie fertig ist.
func play(id: String, ctx: Dictionary = {}) -> void:
	while active:
		await finished
	var path := "res://scenes/cutscenes/%s.tscn" % id
	if not ResourceLoader.exists(path):
		push_warning("Cutscene fehlt: " + path)
		return
	var ps: PackedScene = load(path)
	var cs := ps.instantiate()
	var host := get_tree().current_scene
	host.add_child(cs)
	begin(id, ctx.get("letterbox", true), ctx.get("skippable", true))
	if cs.has_method("run"):
		await cs.run(self, ctx)
	await end(ctx.get("blend_back", 0.55))
	if is_instance_valid(cs):
		cs.queue_free()


func begin(id: String, bars := true, can_skip := true) -> void:
	active = true
	current_id = id
	skippable = can_skip
	_prev_cam = get_viewport().get_camera_3d()
	cam = Camera3D.new()
	cam.name = "CineCam"
	get_tree().current_scene.add_child(cam)
	if is_instance_valid(_prev_cam):
		cam.global_transform = _prev_cam.global_transform
		cam.fov = _prev_cam.fov
		cam.far = _prev_cam.far
	else:
		cam.fov = 55.0
	cam.far = maxf(cam.far, 600.0)
	cam.make_current()
	if bars:
		letterbox(true)
	_hint.visible = can_skip and InputHub.is_slot_human(0)
	EventBus.cutscene_started.emit(id)


func end(blend := 0.55) -> void:
	letterbox(false)
	_hint.visible = false
	hide_text()
	if is_instance_valid(_prev_cam) and is_instance_valid(cam) and blend > 0.0:
		var from := cam.global_transform
		var from_fov := cam.fov
		var tw := create_tween()
		tw.tween_method(func(t: float) -> void:
			if is_instance_valid(_prev_cam) and is_instance_valid(cam):
				var e := ease(t, -2.2)
				cam.global_transform = from.interpolate_with(_prev_cam.global_transform, e)
				cam.fov = lerpf(from_fov, _prev_cam.fov, e), 0.0, 1.0, blend)
		await tw.finished
	if is_instance_valid(_prev_cam):
		_prev_cam.make_current()
	if is_instance_valid(cam):
		cam.queue_free()
	cam = null
	active = false
	Juice.base_time_scale = 1.0
	var id := current_id
	current_id = ""
	EventBus.cutscene_finished.emit(id)
	finished.emit(id)


# --- Kamera-Primitive (alle awaitbar) -------------------------------------------------------

func cut(pos: Vector3, look: Vector3, fov := -1.0) -> void:
	if not is_instance_valid(cam):
		return
	cam.global_position = pos
	_look(look)
	if fov > 0:
		cam.fov = fov


func _look(target: Vector3, up := Vector3.UP) -> void:
	if cam.global_position.distance_squared_to(target) < 0.0001:
		return
	var dir := (target - cam.global_position).normalized()
	if absf(dir.dot(up)) > 0.995:
		up = Vector3.FORWARD
	cam.look_at(target, up)


## Kamerafahrt von der aktuellen Position zu pos, Blickziel wandert mit.
func move(pos: Vector3, look: Vector3, duration := 1.0, fov := -1.0, trans := Tween.TRANS_SINE, ease_type := Tween.EASE_IN_OUT) -> void:
	if not is_instance_valid(cam):
		return
	var p0 := cam.global_position
	var l0 := cam.global_position - cam.global_basis.z * 10.0
	var f0 := cam.fov
	var f1 := fov if fov > 0 else f0
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(cam):
			cam.global_position = p0.lerp(pos, t)
			_look(l0.lerp(look, t))
			cam.fov = lerpf(f0, f1, t), 0.0, 1.0, duration).set_trans(trans).set_ease(ease_type)
	await tw.finished


## Orbit um einen Punkt (Grad, gegen den Uhrzeigersinn von +Z aus).
func orbit(center: Vector3, radius: float, height: float, from_deg: float, to_deg: float, duration := 2.0, fov := -1.0, look_h := 1.0, radius_end := -1.0, height_end := -999.0) -> void:
	if not is_instance_valid(cam):
		return
	var f0 := cam.fov
	var f1 := fov if fov > 0 else f0
	var r1 := radius_end if radius_end > 0 else radius
	var h1 := height_end if height_end > -998.0 else height
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(cam):
			var a := deg_to_rad(lerpf(from_deg, to_deg, t))
			var r := lerpf(radius, r1, t)
			cam.global_position = center + Vector3(sin(a) * r, lerpf(height, h1, t), cos(a) * r)
			_look(center + Vector3.UP * look_h)
			cam.fov = lerpf(f0, f1, t), 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


## Flug entlang eines Catmull-Rom-Splines. look kann Vector3 oder Array[Vector3] (mitlaufend) sein.
func fly_path(points: Array, look: Variant, duration := 3.0, fov := -1.0) -> void:
	if not is_instance_valid(cam) or points.size() < 2:
		return
	var curve := Curve3D.new()
	for i in points.size():
		var p: Vector3 = points[i]
		var prev: Vector3 = points[maxi(i - 1, 0)]
		var nxt: Vector3 = points[mini(i + 1, points.size() - 1)]
		var tangent := (nxt - prev) * 0.25
		curve.add_point(p, -tangent, tangent)
	var length := curve.get_baked_length()
	var f0 := cam.fov
	var f1 := fov if fov > 0 else f0
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(cam):
			return
		cam.global_position = curve.sample_baked(t * length, true)
		var target: Vector3
		if look is Array:
			var arr: Array = look
			var ft := t * (arr.size() - 1)
			var i0 := clampi(int(floor(ft)), 0, arr.size() - 1)
			var i1 := mini(i0 + 1, arr.size() - 1)
			target = (arr[i0] as Vector3).lerp(arr[i1], ft - i0)
		else:
			target = look
		_look(target)
		cam.fov = lerpf(f0, f1, t), 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


## Verfolgt einen (bewegten) Node für eine Dauer mit festem Offset.
func track(node: Node3D, offset: Vector3, duration: float, look_offset := Vector3.UP, lag := 6.0) -> void:
	if not is_instance_valid(cam):
		return
	var elapsed := 0.0
	while elapsed < duration and is_instance_valid(node) and is_instance_valid(cam):
		var dt := get_process_delta_time()
		elapsed += dt
		var want := node.global_position + offset
		cam.global_position = cam.global_position.lerp(want, clampf(dt * lag, 0, 1))
		_look(node.global_position + look_offset)
		await get_tree().process_frame


func zoom(fov: float, duration := 0.5) -> void:
	if not is_instance_valid(cam):
		return
	var tw := create_tween()
	tw.tween_property(cam, "fov", fov, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished


func punch(amount := 10.0, duration := 0.4) -> void:
	Juice.fov_punch(cam, amount, duration)


func shake(strength := 0.4) -> void:
	Juice.shake(strength)


func wait(t: float) -> void:
	await get_tree().create_timer(t, false).timeout


# --- Overlay-Primitive ----------------------------------------------------------------------------

func letterbox(on: bool, duration := 0.35) -> void:
	var h := get_viewport().get_visible_rect().size.y * LETTERBOX_H
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_bar_top, "offset_bottom", h if on else 0.0, duration).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_bar_bot, "offset_top", -h if on else 0.0, duration).set_trans(Tween.TRANS_CUBIC)


## Große Titelkarte mit Pop-Animation. duration <= 0 lässt sie stehen (hide_text()).
func title(text: String, sub := "", duration := 1.6, color := Color.WHITE) -> void:
	_title.text = text
	_title.add_theme_color_override("font_color", color)
	_title.visible = true
	_title.pivot_offset = Vector2(get_viewport().get_visible_rect().size.x / 2.0, _title.size.y / 2.0)
	_title.scale = Vector2(0.2, 0.2)
	_title.rotation = -0.12
	_title.modulate.a = 1.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_title, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_title, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_subtitle.visible = sub != ""
	_subtitle.text = sub
	_subtitle.modulate.a = 0.0
	if sub != "":
		tw.tween_property(_subtitle, "modulate:a", 1.0, 0.3).set_delay(0.25)
	if duration > 0.0:
		await get_tree().create_timer(duration, false).timeout
		await _fade_text()


func subtitle(text: String, duration := 2.0) -> void:
	_subtitle.text = text
	_subtitle.visible = true
	_subtitle.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_subtitle, "modulate:a", 1.0, 0.2)
	if duration > 0:
		tw.tween_interval(duration)
		tw.tween_property(_subtitle, "modulate:a", 0.0, 0.25)
		await tw.finished


func _fade_text() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_title, "modulate:a", 0.0, 0.25)
	tw.tween_property(_subtitle, "modulate:a", 0.0, 0.25)
	await tw.finished
	_title.visible = false
	_subtitle.visible = false


func hide_text() -> void:
	_title.visible = false
	_subtitle.visible = false
	_big.visible = false


func flash(color := Color.WHITE, duration := 0.25) -> void:
	_flash.color = color
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, duration).from(color.a)
	await tw.finished


func fade(to_black: bool, duration := 0.4) -> void:
	var tw := create_tween()
	tw.tween_property(_flash, "color", Color(0.02, 0.01, 0.05, 1.0 if to_black else 0.0), duration)
	await tw.finished


## Riesige Einzelzahl/-wort mit Squash-Pop (für Countdown, "STERN!", "AUTSCH!").
func big_word(text: String, color := Color.WHITE, hold := 0.55) -> void:
	_big.text = text
	_big.add_theme_color_override("font_color", color)
	_big.visible = true
	_big.modulate.a = 1.0
	_big.pivot_offset = Vector2(get_viewport().get_visible_rect().size.x / 2.0, _big.size.y / 2.0)
	_big.scale = Vector2(2.2, 0.3)
	var tw := create_tween()
	tw.tween_property(_big, "scale", Vector2(0.85, 1.25), 0.1)
	tw.tween_property(_big, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(hold - 0.45, 0.05))
	tw.tween_property(_big, "modulate:a", 0.0, 0.15)
	await tw.finished
	_big.visible = false


## Klassischer 3-2-1-LOS!-Countdown mit Ansager und Juice.
func countdown(go_text := "LOS!") -> void:
	var colors := [Color("#ff4d6d"), Color("#ffcc00"), Color("#4cd964")]
	for i in 3:
		var n := 3 - i
		Audio.voice(str(n))
		Audio.sfx("countdown", null, 0.0, 1.0, 0.0)
		Juice.shake(0.12)
		await big_word(str(n), colors[i], 0.75)
	Audio.voice("go")
	Audio.sfx("go")
	Juice.shake(0.3)
	InputHub.rumble(0, 0.6, 0.2)
	big_word(go_text, Color("#5ab8ff"), 0.8)
	await get_tree().create_timer(0.25, false).timeout
