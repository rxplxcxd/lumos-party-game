extends Node
## "Juice"-Werkzeugkasten: Hitstop, Zeitlupe, Trauma-Shake, FOV-Punch, Squash & Stretch,
## schwebende Zahlen. Besitzt exklusiv Engine.time_scale, damit sich Effekte nicht beißen.

var trauma := 0.0
var trauma_decay := 1.6
var max_shake := 0.55
var base_time_scale := 1.0

var _hitstop_until := 0
var _slowmo_until := 0
var _slowmo_scale := 1.0
var _noise := FastNoiseLite.new()
var _t := 0.0
var _title_font: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_noise.frequency = 2.2
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	EventBus.camera_shake.connect(func(s: float, _d: float) -> void: shake(s))
	EventBus.hitstop.connect(hitstop)
	_title_font = load(Assets.FONT_TITLE)


func _process(delta: float) -> void:
	var real_dt := delta / maxf(Engine.time_scale, 0.0001) if Engine.time_scale > 0 else delta
	_t += real_dt
	trauma = maxf(0.0, trauma - trauma_decay * real_dt)
	var now := Time.get_ticks_msec()
	var ts := base_time_scale
	if now < _slowmo_until:
		ts *= _slowmo_scale
	if now < _hitstop_until:
		ts = 0.02
	if get_tree().paused:
		ts = 1.0
	Engine.time_scale = ts
	_apply_camera_shake()


func _apply_camera_shake() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var amount := trauma * trauma * max_shake * float(Game.settings.get("screen_shake", 1.0))
	cam.h_offset = _noise.get_noise_2d(_t * 40.0, 0.0) * amount
	cam.v_offset = _noise.get_noise_2d(0.0, _t * 40.0) * amount


## Trauma-Shake (0..1 addiert, gedeckelt).
func shake(strength := 0.4) -> void:
	trauma = clampf(trauma + strength, 0.0, 1.0)


## Kurzer Hitstop (Echtzeit-Sekunden). Nach einem Hitstop folgen mindestens 0,3 s normales Tempo – sonst
## würden Treffer-Serien (z. B. Dauer-Rempeln) das Spiel ins Stocken bringen.
func hitstop(duration := 0.07) -> void:
	var now := Time.get_ticks_msec()
	if now < _hitstop_until:
		_hitstop_until = maxi(_hitstop_until, now + int(duration * 1000.0))   # laufenden Hitstop höchstens verlängern
		return
	if now < _hitstop_until + 300:
		return
	_hitstop_until = now + int(duration * 1000.0)


func slowmo(scale := 0.3, duration := 0.5) -> void:
	_slowmo_scale = scale
	_slowmo_until = Time.get_ticks_msec() + int(duration * 1000.0)


func is_slowmo() -> bool:
	return Time.get_ticks_msec() < _slowmo_until


## Dyna-Zoom: FOV kurz weiten/verengen und zurückfedern.
func fov_punch(cam: Camera3D, amount := 8.0, duration := 0.35) -> void:
	if cam == null:
		return
	var base: float = cam.get_meta("base_fov", cam.fov)
	cam.set_meta("base_fov", base)
	var tw := cam.create_tween()
	tw.tween_property(cam, "fov", base + amount, duration * 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_property(cam, "fov", base, duration * 0.75).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# --- Squash & Stretch -------------------------------------------------------------------

## Staucht/streckt einen Node (Füße bleiben am Boden, da Ursprung unten) und federt elastisch zurück.
func squash(node: Node3D, sx: float, sy: float, duration := 0.35, base := Vector3.ONE) -> void:
	if not is_instance_valid(node):
		return
	node.scale = Vector3(base.x * sx, base.y * sy, base.z * sx)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", base, duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Antizipation: erst tief in die Knie, dann Streckung. Gibt Tween zurück (await tw.finished).
func anticipate(node: Node3D, depth := 0.35, hold := 0.12, base := Vector3.ONE) -> Tween:
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3(base.x * (1.0 + depth * 0.6), base.y * (1.0 - depth), base.z * (1.0 + depth * 0.6)), hold).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector3(base.x * 0.82, base.y * 1.3, base.z * 0.82), 0.07)
	tw.tween_property(node, "scale", base, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return tw


func pop_in(node: Node, duration := 0.4, from := 0.0) -> void:
	if node is Node3D:
		var n3 := node as Node3D
		var target := n3.scale
		n3.scale = target * maxf(from, 0.001)
		n3.create_tween().tween_property(n3, "scale", target, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif node is Control:
		var c := node as Control
		c.pivot_offset = c.size / 2.0
		c.scale = Vector2.ONE * maxf(from, 0.001)
		c.create_tween().tween_property(c, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func ui_punch(c: Control, amount := 0.18, duration := 0.3) -> void:
	if not is_instance_valid(c):
		return
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2.ONE * (1.0 + amount)
	c.create_tween().tween_property(c, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Schwebender 3D-Text ("+10", "-3", "AUA!") der aufsteigt und verblasst.
func float_text(parent: Node, pos: Vector3, text: String, color := Color.WHITE, size := 96, rise := 1.6, life := 1.1) -> Label3D:
	if parent == null:
		return null
	var l := Label3D.new()
	l.text = text
	l.font = _title_font
	l.font_size = size
	l.outline_size = int(size * 0.22)
	l.modulate = color
	l.outline_modulate = Color(0.08, 0.04, 0.12, 1)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.006
	parent.add_child(l)
	l.global_position = pos
	l.scale = Vector3.ONE * 0.2
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector3.ONE * 1.15, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector3.ONE, 0.1)
	tw.parallel().tween_property(l, "global_position", pos + Vector3.UP * rise, life).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, life * 0.4).set_delay(life * 0.6)
	tw.tween_callback(l.queue_free)
	return l
