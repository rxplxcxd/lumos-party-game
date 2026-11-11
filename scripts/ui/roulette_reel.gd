class_name RouletteReel
extends Control
## Minispiel-Roulette als Slot-Walze: dreht schnell, bremst weich ab und stoppt exakt auf dem
## Ziel-Eintrag (der Aufrufer lädt danach genau diesen Eintrag – Anzeige und Logik sind identisch).

signal stopped(index: int)

const FONT_PX := 42

var names: Array = []
var colors: Array = []
var offset := 0.0          # Index-Position der Walze (float), Mitte = round(offset)
var row_h := 64.0
var visible_rows := 5
var _last_tick := 0
var _font: Font
var _glow := 0.0


func setup(entries: Array, cols: Array = []) -> RouletteReel:
	names = entries
	colors = cols
	_font = UI.title_font()
	custom_minimum_size = Vector2(640, row_h * visible_rows + 24)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true   # Zeilen nie über den Walzenrand hinaus zeichnen
	offset = randi() % maxi(1, names.size())
	_last_tick = int(round(offset))
	return self


## Dreht und stoppt garantiert auf target. Awaitbar.
func spin_to(target: int, loops := 3, duration := 3.4) -> void:
	var n := names.size()
	var start := offset
	var base := floorf(start / n) * n
	var end := base + loops * n + target
	while end - start < n:
		end += n
	var tw := create_tween()
	tw.tween_method(_set_offset, start, end, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await tw.finished
	offset = end
	_glow = 1.0
	create_tween().tween_property(self, "_glow", 0.0, 1.2)
	queue_redraw()
	stopped.emit(wrapi(int(round(offset)), 0, n))


## Bereitet die Schrift für alle Einträge vor (einmal unsichtbar zeichnen), damit das erste Drehen nicht ruckelt.
## Aufruf z. B. beim Laden des Bretts, solange noch der Ladebildschirm liegt.
static func prewarm(parent: Node, entries: Array) -> void:
	var chars := {}
	for e in entries:
		for c in String(e):
			chars[c] = true
	var warm := RouletteReel.new().setup(["".join(chars.keys()) + "0123456789!?"], [])
	warm.modulate.a = 0.01
	warm.position = Vector2(-4000, -4000)
	parent.add_child(warm)
	warm.offset = 0.0
	warm.queue_redraw()
	parent.get_tree().create_timer(0.3, true, false, true).timeout.connect(warm.queue_free)


func current_index() -> int:
	return wrapi(int(round(offset)), 0, names.size())


func _set_offset(v: float) -> void:
	offset = v
	var t := int(round(offset))
	if t != _last_tick:
		_last_tick = t
		Audio.sfx("tick", null, -5.0, 1.0 + randf() * 0.1, 0.0)
	queue_redraw()


func _process(_d: float) -> void:
	if _glow > 0.0:
		queue_redraw()


func _draw() -> void:
	var n := names.size()
	if n == 0:
		return
	var w := size.x
	var h := row_h * visible_rows
	var top := 12.0
	draw_rect(Rect2(0, top, w, h), Color(0.05, 0.02, 0.12, 0.92), true)
	var center_y := top + h / 2.0
	var frac := offset - floorf(offset)
	var base_i := int(floorf(offset))
	for k in range(-3, 4):
		var i := base_i + k
		var y := center_y + (k - frac) * row_h
		if y < top - row_h * 0.5 or y > top + h + row_h * 0.5:
			continue
		var dist := absf(y - center_y) / (h / 2.0)
		var alpha := clampf(1.0 - dist * 0.85, 0.0, 1.0)
		var idx := wrapi(i, 0, n)
		var col: Color = colors[idx] if idx < colors.size() else Color.WHITE
		# Eine feste Schriftgröße für alle Zeilen, verkleinert per Transformation: Jede andere Größe müsste die
		# Engine erst neu rastern (alle Buchstaben, mit Kontur) – genau das ließ das Roulette anfangs ruckeln.
		var sc := lerpf(1.0, 26.0 / FONT_PX, clampf(dist, 0, 1))
		var text: String = names[idx]
		var sz := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX) * sc
		draw_set_transform(Vector2((w - sz.x) / 2.0, y + FONT_PX * sc * 0.35), 0.0, Vector2(sc, sc))
		draw_string_outline(_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX, 8, Color(0, 0, 0, 0.6 * alpha))
		draw_string(_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX, Color(col.lightened(0.35), alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Mittelfenster
	var win := Rect2(10, center_y - row_h / 2.0, w - 20, row_h)
	draw_rect(win, Color(1, 0.8, 0.2, 0.12 + _glow * 0.25), true)
	draw_rect(win, Color(1, 0.8, 0.2, 0.9), false, 4.0)
	for side in [-1.0, 1.0]:
		var x := 6.0 if side < 0 else w - 6.0
		var tri := PackedVector2Array([Vector2(x, center_y - 16), Vector2(x + side * -22, center_y), Vector2(x, center_y + 16)])
		draw_colored_polygon(tri, Color("#ffcc33"))
	# Rahmen + Verlauf oben/unten
	for k in 8:
		var a := 0.5 * (1.0 - k / 8.0)
		draw_rect(Rect2(0, top + k * 6, w, 6), Color(0.05, 0.02, 0.12, a), true)
		draw_rect(Rect2(0, top + h - (k + 1) * 6, w, 6), Color(0.05, 0.02, 0.12, a), true)
	draw_rect(Rect2(0, top, w, h), Color(1, 1, 1, 0.25), false, 3.0)
