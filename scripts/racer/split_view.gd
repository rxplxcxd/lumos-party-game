class_name SplitView
extends Control
## Eine Spieler-Ansicht für Split-Screen/Multi-Monitor im Rennen: eigener SubViewport (teilt die
## 3D-Welt), eigene Verfolgerkamera und ein kompaktes HUD (Platz, Runde, Item, Drift-Ladung).
## Wird in ein Raster der Hauptansicht oder in ein eigenes Fenster (zweiter Monitor) gehängt.

var racer: Racer
var vp: SubViewport
var cam: Camera3D
var _container: SubViewportContainer
var _pos: Label
var _lap: Label
var _tag: Label
var _item: UIIcon
var _item_bg: PanelContainer
var _drift: ColorRect
var _drift_bg: ColorRect
var _msg: Label
var _msg_t := 0.0
var _up := Vector3.UP
var _laps := 3
var _last_item := ""


func setup(r: Racer, laps: int) -> SplitView:
	racer = r
	_laps = laps
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container = SubViewportContainer.new()
	_container.stretch = true
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)
	vp = SubViewport.new()
	vp.handle_input_locally = false
	vp.audio_listener_enable_3d = r.slot == 0
	vp.msaa_3d = Gfx.preset().msaa
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	_container.add_child(vp)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 700.0
	vp.add_child(cam)
	cam.current = true
	_build_hud()
	return self


func _build_hud() -> void:
	var frame := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = racer.color
	sb.set_border_width_all(4)
	frame.add_theme_stylebox_override("panel", sb)
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var left := UI.vbox(-8)
	left.position = Vector2(16, 6)
	add_child(left)
	_pos = UI.label("1.", 64, Color.WHITE, true, 12)
	left.add_child(_pos)
	_lap = UI.label("Runde 1/%d" % _laps, 22, Color.WHITE, true, 6)
	left.add_child(_lap)
	_tag = UI.label("P%d %s" % [racer.slot + 1, racer.display_name], 20, racer.color.lightened(0.35), true, 6)
	_tag.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_tag.position = Vector2(16, -36)
	add_child(_tag)
	_item_bg = UI.panel(Color(0.08, 0.04, 0.2, 0.8), 18)
	_item_bg.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_item_bg.position = Vector2(-96, 12)
	_item_bg.custom_minimum_size = Vector2(80, 80)
	add_child(_item_bg)
	_item = UIIcon.new("question", 56)
	_item_bg.add_child(_item)
	_item.visible = false
	_drift_bg = ColorRect.new()
	_drift_bg.color = Color(1, 1, 1, 0.18)
	_drift_bg.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_drift_bg.position = Vector2(-176, -28)
	_drift_bg.size = Vector2(160, 10)
	add_child(_drift_bg)
	_drift = ColorRect.new()
	_drift.size = Vector2(0, 10)
	_drift_bg.add_child(_drift)
	_msg = UI.label("", 40, Color.WHITE, true, 10)
	_msg.set_anchors_preset(Control.PRESET_CENTER)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.position = Vector2(-300, -60)
	_msg.size = Vector2(600, 60)
	_msg.visible = false
	add_child(_msg)


## Skaliert HUD-Schriften auf die Ansichtshöhe (Viertel-Bildschirm = kleiner).
func fit_hud() -> void:
	var k := clampf(size.y / 540.0, 0.55, 1.2)
	_pos.add_theme_font_size_override("font_size", int(64 * k))
	_lap.add_theme_font_size_override("font_size", int(22 * k))
	_msg.add_theme_font_size_override("font_size", int(40 * k))


func message(text: String, color := Color.WHITE, hold := 1.0) -> void:
	_msg.text = text
	_msg.add_theme_color_override("font_color", color)
	_msg.visible = true
	_msg_t = hold
	Juice.ui_punch(_msg, 0.25, 0.35)


func tick(delta: float, race_time: float) -> void:
	if not is_instance_valid(racer):
		return
	_follow(delta)
	vp.scaling_3d_scale = Gfx.dynamic_scale
	_pos.text = "%d." % racer.place
	_pos.add_theme_color_override("font_color", UI.GOLD if racer.place == 1 else Color.WHITE)
	_lap.text = "Runde %d/%d" % [clampi(racer.lap + 1, 1, _laps), _laps] if not racer.finished else "ZIEL! %s" % _fmt(racer.finish_time)
	var frac := 0.0
	if racer.drift_dir != 0:
		frac = clampf(racer.drift_t / Racer.DRIFT_LEVELS[2], 0, 1)
	_drift.size.x = 160.0 * frac
	_drift.color = [Color(1, 1, 1, 0.6), KartVisual.SPARK_COLORS[0], KartVisual.SPARK_COLORS[1], Color.from_hsv(fmod(race_time * 2.5, 1.0), 0.8, 1.0)][racer.drift_level]
	if racer.rolling > 0.0:
		_item.visible = true
		if int(Time.get_ticks_msec() / 70) % 2 == 0:
			_item.set_kind(ItemModels.icon_of(ItemModels.INFO.keys()[randi() % ItemModels.INFO.size()]))
	elif racer.item != "":
		_item.visible = true
		_item.set_kind(ItemModels.icon_of(racer.item))
		if _last_item != racer.item:
			Juice.ui_punch(_item_bg, 0.25, 0.4)
	else:
		_item.visible = false
	_last_item = racer.item
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0:
			_msg.visible = false


var _snapped := false


func _follow(delta: float) -> void:
	var fr := racer.global_transform
	if not _snapped:
		_snapped = true
		cam.global_position = fr.origin + fr.basis.z * 8.0 + fr.basis.y * 3.2
		cam.look_at(fr.origin, Vector3.UP)
	var fwd := -fr.basis.z
	_up = _up.lerp(fr.basis.y.normalized(), clampf(delta * 5.0, 0, 1)).normalized()
	var drift_side := fr.basis.x * float(racer.drift_dir) * -1.2
	var dist := 5.4 + absf(racer.v) * 0.03
	var want := fr.origin - fwd * dist + _up * (3.9 + (1.5 if racer.gliding else 0.0)) + drift_side
	cam.global_position = cam.global_position.lerp(want, 1.0 - exp(-delta * 9.0))
	var look := fr.origin + fwd * 6.0 + _up * 1.0
	if cam.global_position.distance_to(look) > 0.1:
		cam.look_at(look, _up)
	var base_fov := 68.0 + clampf(absf(racer.v) / Racer.MAX_SPEED, 0, 1.4) * 8.0 + (6.0 if racer.boost_t > 0.0 else 0.0)
	cam.fov = lerpf(cam.fov, base_fov, clampf(delta * 3.0, 0, 1))


static func _fmt(t: float) -> String:
	return "%d:%05.2f" % [int(t) / 60, fmod(t, 60.0)]
