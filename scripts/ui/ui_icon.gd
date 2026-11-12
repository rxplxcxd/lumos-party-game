class_name UIIcon
extends Control
## Prozedural gezeichnete Icons (scharf in jeder Auflösung, keine Texturen nötig):
## coin, star, pie, cannonball, megaphone, anchor, nitro, candy, honey, bubble, mirror, spark, thunder, comet,
## dice, double_dice, question, crown

var kind := "coin"
var tint := Color.WHITE
var spin := 0.0


func _init(k := "coin", sz := 40.0) -> void:
	kind = k
	custom_minimum_size = Vector2(sz, sz)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_kind(k: String) -> void:
	kind = k
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	var r := s * 0.45
	match kind:
		"coin":
			draw_circle(c + Vector2(0, s * 0.04), r, Color("#8a5a00"))
			draw_circle(c, r, Color("#ffcc33"))
			draw_circle(c, r * 0.72, Color("#ffe27a"))
			draw_rect(Rect2(c - Vector2(r * 0.12, r * 0.42), Vector2(r * 0.24, r * 0.84)), Color("#e0a400"))
			draw_arc(c, r, 0, TAU, 32, Color("#7a4a00"), maxf(1.5, s * 0.05), true)
		"star":
			_star(c, r, Color("#ffcc33"), Color("#8a5a00"))
		"pie":
			draw_circle(c + Vector2(0, r * 0.15), r, Color("#b5651d"))
			draw_circle(c, r * 0.92, Color("#fff4e0"))
			for k in 6:
				var a := TAU * k / 6.0
				draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.62, r * 0.2, Color("#ffffff"))
			draw_circle(c + Vector2(0, -r * 0.1), r * 0.26, Color("#e0203a"))
			draw_circle(c + Vector2(-r * 0.08, -r * 0.18), r * 0.08, Color(1, 1, 1, 0.8))
		"cannonball":
			draw_circle(c + Vector2(r * 0.1, r * 0.1), r * 0.85, Color("#1b1b24"))
			draw_circle(c + Vector2(-r * 0.25, -r * 0.2), r * 0.25, Color(1, 1, 1, 0.25))
			draw_line(c + Vector2(r * 0.4, -r * 0.5), c + Vector2(r * 0.75, -r * 0.95), Color("#c8a070"), s * 0.08)
			_star(c + Vector2(r * 0.8, -r * 1.0), r * 0.3, Color("#ffaa22"), Color("#ff4400"))
			draw_circle(c + Vector2(-r * 0.25, r * 0.05), r * 0.12, Color("#ff3355"))
			draw_circle(c + Vector2(r * 0.2, r * 0.05), r * 0.12, Color("#ff3355"))
		"megaphone":
			var pts := PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.25), c + Vector2(r * 0.6, -r * 0.8), c + Vector2(r * 0.6, r * 0.8), c + Vector2(-r * 0.8, r * 0.25)])
			draw_colored_polygon(pts, Color("#ff5c7a"))
			draw_rect(Rect2(c + Vector2(-r * 0.95, -r * 0.3), Vector2(r * 0.3, r * 0.6)), Color("#ffffff"))
			for k in 3:
				draw_arc(c + Vector2(r * 0.6, 0), r * (0.35 + k * 0.22), -0.8, 0.8, 12, Color(1, 1, 1, 0.9 - k * 0.25), s * 0.05, true)
		"anchor":
			var col := Color("#7a8ca8")
			draw_line(c + Vector2(0, -r * 0.7), c + Vector2(0, r * 0.75), col, s * 0.12)
			draw_arc(c + Vector2(0, -r * 0.8), r * 0.2, 0, TAU, 16, col, s * 0.08, true)
			draw_line(c + Vector2(-r * 0.45, -r * 0.35), c + Vector2(r * 0.45, -r * 0.35), col, s * 0.1)
			draw_arc(c + Vector2(0, r * 0.15), r * 0.65, 0.2, PI - 0.2, 20, col, s * 0.12, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.75, r * 0.1), c + Vector2(-r * 0.45, r * 0.45), c + Vector2(-r * 0.85, r * 0.5)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.75, r * 0.1), c + Vector2(r * 0.45, r * 0.45), c + Vector2(r * 0.85, r * 0.5)]), col)
		"nitro":
			draw_rect(Rect2(c + Vector2(-r * 0.4, -r * 0.55), Vector2(r * 0.8, r * 1.35)), Color("#3fa7ff"))
			draw_rect(Rect2(c + Vector2(-r * 0.2, -r * 0.85), Vector2(r * 0.4, r * 0.3)), Color("#bfe4ff"))
			draw_rect(Rect2(c + Vector2(-r * 0.4, -r * 0.05), Vector2(r * 0.8, r * 0.35)), Color("#ffcc33"))
			_star(c + Vector2(0, r * 0.12), r * 0.15, Color("#ff5c7a"), Color("#ff5c7a"))
		"candy":   # drei gestreifte Bonbons im Fächer
			for k in 3:
				var cc := c + Vector2((k - 1) * r * 0.55, (absf(k - 1.0) * r * 0.25) - r * 0.05)
				var col2: Color = [Color("#ff5c9a"), Color("#5cc8ff"), Color("#ffd23f")][k]
				draw_circle(cc + Vector2(0, r * 0.06), r * 0.36, col2.darkened(0.35))
				draw_circle(cc, r * 0.36, col2)
				draw_arc(cc, r * 0.22, 0.4, 2.4, 10, Color(1, 1, 1, 0.9), s * 0.05, true)
		"honey":   # Honigtopf mit Tropfen
			draw_circle(c + Vector2(0, r * 0.2), r * 0.7, Color("#c87a2a"))
			draw_rect(Rect2(c + Vector2(-r * 0.45, -r * 0.6), Vector2(r * 0.9, r * 0.3)), Color("#a8601e"))
			draw_circle(c + Vector2(0, -r * 0.35), r * 0.42, Color("#ffb21e"))
			draw_circle(c + Vector2(r * 0.3, -r * 0.05), r * 0.13, Color("#ffb21e"))
			draw_circle(c + Vector2(-r * 0.2, r * 0.05), r * 0.1, Color("#ffcf5e"))
			draw_rect(Rect2(c + Vector2(-r * 0.4, r * 0.25), Vector2(r * 0.8, r * 0.14)), Color(1, 1, 1, 0.85))
		"bubble":
			draw_circle(c, r * 0.92, Color(0.6, 0.85, 1.0, 0.35))
			draw_arc(c, r * 0.92, 0, TAU, 32, Color(0.85, 0.95, 1.0), s * 0.06, true)
			draw_arc(c, r * 0.65, PI * 1.05, PI * 1.45, 10, Color(1, 1, 1, 0.9), s * 0.07, true)
			draw_circle(c + Vector2(-r * 0.38, -r * 0.4), r * 0.12, Color(1, 1, 1, 0.95))
		"mirror":   # Sechseck-Schild mit Spiegel-Glanz
			var hexp := PackedVector2Array()
			for k in 6:
				var a := TAU * k / 6.0 + PI / 6.0
				hexp.append(c + Vector2(cos(a), sin(a)) * r * 0.9)
			draw_colored_polygon(hexp, Color("#9fb6d8"))
			var inner := PackedVector2Array()
			for k in 6:
				var a2 := TAU * k / 6.0 + PI / 6.0
				inner.append(c + Vector2(cos(a2), sin(a2)) * r * 0.66)
			draw_colored_polygon(inner, Color("#e8f2ff"))
			draw_line(c + Vector2(-r * 0.35, r * 0.2), c + Vector2(r * 0.15, -r * 0.4), Color(1, 1, 1), s * 0.07)
			draw_line(c + Vector2(-r * 0.1, r * 0.4), c + Vector2(r * 0.35, -r * 0.15), Color(1, 1, 1, 0.7), s * 0.05)
		"spark":   # leuchtender Kristall mit Funken
			var gem := PackedVector2Array([c + Vector2(0, -r * 0.9), c + Vector2(r * 0.5, 0), c + Vector2(0, r * 0.9), c + Vector2(-r * 0.5, 0)])
			draw_colored_polygon(gem, Color("#7fd6ff"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.9), c + Vector2(r * 0.5, 0), c]), Color("#c8f0ff"))
			for k in 3:
				_star(c + Vector2(cos(k * 2.1) * r * 0.85, sin(k * 2.1) * r * 0.75), r * 0.16, Color("#ffd23f"), Color("#ff9f1a"))
		"thunder":   # dunkle Wolke mit gelbem Blitz
			draw_circle(c + Vector2(-r * 0.35, -r * 0.15), r * 0.42, Color("#6a6e86"))
			draw_circle(c + Vector2(r * 0.3, -r * 0.2), r * 0.48, Color("#6a6e86"))
			draw_circle(c + Vector2(0, -r * 0.45), r * 0.4, Color("#868aa2"))
			draw_rect(Rect2(c + Vector2(-r * 0.75, -r * 0.15), Vector2(r * 1.5, r * 0.4)), Color("#6a6e86"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.1, r * 0.1), c + Vector2(-r * 0.25, r * 0.55), c + Vector2(0, r * 0.55),
				c + Vector2(-r * 0.2, r * 0.98), c + Vector2(r * 0.32, r * 0.42), c + Vector2(r * 0.06, r * 0.42), c + Vector2(r * 0.28, r * 0.1)]), Color("#ffe14a"))
		"comet":   # Stern mit Schweif
			for k in 3:
				draw_line(c + Vector2(r * 0.1, r * 0.1), c + Vector2(r * 0.95, r * (0.55 + k * 0.2)), Color(1.0, 0.6 + k * 0.1, 0.2, 0.8 - k * 0.2), s * (0.14 - k * 0.03))
			_star(c + Vector2(-r * 0.15, -r * 0.15), r * 0.62, Color("#ffd23f"), Color("#ff8a1a"))
		"dice", "double_dice":
			var off := Vector2(r * 0.18, -r * 0.18) if kind == "double_dice" else Vector2.ZERO
			if kind == "double_dice":
				_die(c - off, r * 0.7, Color("#ffcc33"))
			_die(c + off, r * 0.7, Color("#ffffff"))
		"question":
			draw_circle(c, r, Color("#7b3cff"))
			var f := UI.title_font()
			draw_string(f, c + Vector2(-s * 0.18, s * 0.22), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.7), Color.WHITE)
		"crown":
			var pts2 := PackedVector2Array([c + Vector2(-r, r * 0.5), c + Vector2(-r, -r * 0.4), c + Vector2(-r * 0.5, 0), c + Vector2(0, -r * 0.7), c + Vector2(r * 0.5, 0), c + Vector2(r, -r * 0.4), c + Vector2(r, r * 0.5)])
			draw_colored_polygon(pts2, Color("#ffcc33"))
			draw_circle(c + Vector2(0, r * 0.15), r * 0.15, Color("#ff4d6d"))
		_:
			draw_circle(c, r, tint)


func _star(c: Vector2, r: float, fill: Color, edge: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var rr := r if k % 2 == 0 else r * 0.45
		var a := -PI / 2.0 + k * PI / 5.0 + spin
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(0, r * 0.1))
	draw_colored_polygon(shadow, edge.darkened(0.3))
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, edge, maxf(1.0, r * 0.08), true)


func _die(c: Vector2, r: float, col: Color) -> void:
	var rect := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
	draw_rect(Rect2(rect.position + Vector2(0, r * 0.12), rect.size), col.darkened(0.45))
	draw_rect(rect, col)
	var pip := Color("#2a0f5c")
	for p in [Vector2(-0.5, -0.5), Vector2(0.5, 0.5), Vector2(0, 0), Vector2(0.5, -0.5), Vector2(-0.5, 0.5)]:
		draw_circle(c + p * r, r * 0.16, pip)
