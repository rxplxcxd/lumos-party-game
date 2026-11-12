class_name BossBar
extends Control
## Kompakte Boss-Lebensleiste für Bosskämpfe: eine halbtransparente Zeile mit Name (links) und Werten (rechts)
## in der Leiste, darunter optional ein Zustand („Gepanzert“ …). Steht der Boss auf dem Bildschirm dahinter,
## blendet sie sich weiter aus – der Boss bleibt immer sichtbar.
##   var bar := BossBar.new().setup(parent, "Ignis", boss_node)   →   bar.set_hp(0.7, "67 / 96 · Phase 2", "Gepanzert")

const W := 540.0
const H := 30.0

var tracked: Node3D            # Boss-Knoten (Bildschirm-Abgleich fürs Ausblenden)
var track_heights: Array[float] = [1.5, 3.0, 4.5]
var color := Color("#ff4d6d")

var _fill: ColorRect
var _value: Label
var _tag: Label


func setup(parent: Control, boss_name: String, boss: Node3D = null, top := 90.0) -> BossBar:
	tracked = boss
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(self)
	UI.place(self, Control.PRESET_CENTER_TOP, Vector2(-W * 0.5, top), Vector2(W, H))
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.05, 0.15, 0.5)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.size = Vector2(W, H)
	add_child(bg)
	_fill = ColorRect.new()
	_fill.color = color
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.position = Vector2(3, 3)
	_fill.size = Vector2(W - 6, H - 6)
	_fill.modulate.a = 0.78
	bg.add_child(_fill)
	var name_l := UI.label(boss_name, 20, Color.WHITE, true, 6)
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.position = Vector2(12, 0)
	name_l.size = Vector2(330, H)
	add_child(name_l)
	UI.fit_label(name_l, 20, 330.0, 14)
	_value = UI.label("", 17, Color.WHITE, true, 5)
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value.position = Vector2(W - 240, 0)
	_value.size = Vector2(228, H)
	add_child(_value)
	_tag = UI.label("", 16, Color(1, 1, 1, 0.85), true, 5)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.position = Vector2(-30, H + 1)
	_tag.size = Vector2(W + 60, 24)
	add_child(_tag)
	return self


func set_hp(frac: float, value_text := "", tag := "", fill := Color(0, 0, 0, 0)) -> void:
	_fill.size.x = (W - 6) * clampf(frac, 0.0, 1.0)
	if fill.a > 0.0:
		_fill.color = fill
	_value.text = value_text
	_tag.text = tag


func _process(delta: float) -> void:
	if tracked == null or not is_instance_valid(tracked) or not tracked.is_inside_tree():
		modulate.a = move_toward(modulate.a, 1.0, delta * 3.0)
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var r := get_global_rect().grow(24.0)
	r.size.y += 30.0   # samt Zustandszeile
	var behind := false
	for h in track_heights:
		var wp := tracked.global_position + Vector3.UP * h
		if not cam.is_position_behind(wp) and r.has_point(cam.unproject_position(wp)):
			behind = true
	modulate.a = move_toward(modulate.a, 0.38 if behind else 1.0, delta * 3.0)
