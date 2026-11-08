class_name FortuneWheel
extends Control
## Mini-Glücksrad für die Glücksrad-Kiste. Segmente mit Gewichten, Zeiger oben,
## dreht schnell, bremst nach Stopp-Eingabe physikalisch ab, tickt bei jedem Segment.

signal finished(index: int)

var segments: Array = []      # [{text, color, weight}]
var angle := 0.0
var speed := 0.0
var stopping := false
var radius := 220.0
var _last_seg := -1
var _done := false
var _font: Font
var _decel := 5.5


func setup(segs: Array) -> FortuneWheel:
	segments = segs
	custom_minimum_size = Vector2(radius * 2 + 40, radius * 2 + 80)
	_font = UI.title_font()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	return self


func spin() -> void:
	speed = randf_range(13.0, 17.0)
	stopping = false
	_done = false


func stop() -> void:
	if not stopping:
		stopping = true
		_decel = 5.5
		Audio.sfx("ui_confirm")


## Segment, auf dem das Rad bei normalem Abbremsen ab jetzt landen würde.
func predict_stop() -> int:
	return _segment_for(angle + speed * speed / (2.0 * 5.5))


## Abbremsen, sodass das Rad genau in der Mitte von Segment idx landet (Online: alle sehen dasselbe).
func stop_on(idx: int) -> void:
	if stopping:
		return
	var total := _total_weight()
	var acc := 0.0
	for i in clampi(idx, 0, segments.size() - 1):
		acc += float(segments[i].weight) / total * TAU
	var mid := acc + float(segments[clampi(idx, 0, segments.size() - 1)].weight) / total * TAU * 0.5
	var natural := angle + speed * speed / (2.0 * 5.5)
	var final := -mid + ceilf((natural + mid) / TAU) * TAU
	_decel = speed * speed / (2.0 * maxf(0.6, final - angle))
	stopping = true
	Audio.sfx("ui_confirm")


func _total_weight() -> float:
	var t := 0.0
	for s in segments:
		t += float(s.weight)
	return t


func _segment_at_pointer() -> int:
	return _segment_for(angle)


func _segment_for(ang: float) -> int:
	var total := _total_weight()
	var a := fposmod(-ang, TAU)   # Zeiger oben
	var acc := 0.0
	for i in segments.size():
		var w: float = segments[i].weight / total * TAU
		if a >= acc and a < acc + w:
			return i
		acc += w
	return segments.size() - 1


func _process(delta: float) -> void:
	if speed <= 0.0 and _done:
		return
	if stopping:
		speed = maxf(0.0, speed - delta * _decel)
	angle += speed * delta
	var seg := _segment_at_pointer()
	if seg != _last_seg:
		_last_seg = seg
		Audio.sfx("wheel_tick", null, -6.0, 1.0 + speed * 0.02, 0.02)
	if stopping and speed <= 0.0 and not _done:
		_done = true
		Audio.sfx("bell")
		Juice.ui_punch(self, 0.08, 0.4)
		finished.emit(seg)
	queue_redraw()


func _draw() -> void:
	var c := Vector2(size.x / 2.0, radius + 50)
	draw_circle(c + Vector2(0, 10), radius + 16, Color(0, 0, 0, 0.35))
	draw_circle(c, radius + 16, Color("#ffcc33"))
	draw_circle(c, radius + 6, Color("#8a4b00"))
	var total := _total_weight()
	var acc := 0.0
	for i in segments.size():
		var s: Dictionary = segments[i]
		var w: float = s.weight / total * TAU
		var a0 := angle + acc - PI / 2.0
		var pts := PackedVector2Array([c])
		var steps := maxi(4, int(w * 18))
		for k in steps + 1:
			var a := a0 + w * k / steps
			pts.append(c + Vector2(cos(a), sin(a)) * radius)
		draw_colored_polygon(pts, s.color)
		draw_polyline(pts, Color(1, 1, 1, 0.5), 2.0, true)
		# Beschriftung
		var mid := a0 + w / 2.0
		var tp := c + Vector2(cos(mid), sin(mid)) * radius * 0.62
		draw_set_transform(tp, mid + PI / 2.0, Vector2.ONE)
		var fs := 22 if String(s.text).length() > 9 else 26
		var sz := _font.get_string_size(s.text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string_outline(_font, Vector2(-sz.x / 2.0, fs * 0.35), s.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.6))
		draw_string(_font, Vector2(-sz.x / 2.0, fs * 0.35), s.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		acc += w
	draw_circle(c, 34, Color("#ffcc33"))
	draw_circle(c, 24, Color("#ff4fb8"))
	# Zeiger
	var tip := c + Vector2(0, -radius + 18)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-24, -52), tip + Vector2(24, -52)]), Color("#ff3355"))
	draw_polyline(PackedVector2Array([tip, tip + Vector2(-24, -52), tip + Vector2(24, -52), tip]), Color.WHITE, 3.0, true)
