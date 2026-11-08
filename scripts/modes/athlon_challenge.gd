class_name AthlonChallenge
extends Control
## Eine schnelle Solo-Herausforderung des Lumos-Athlons (12 Sekunden) in einem eigenen Bildschirm-Feld.
## Jede gesammelte Münze bringt den Läufer später ein Feld weiter. Gezeichnet mit _draw, gesteuert über
## InputHub (Slot), damit bis zu vier Spieler gleichzeitig an einem Bildschirm spielen können.

signal done(coins: int)

const DURATION := 12.0
const KINDS := ["hammer", "catch", "rhythm", "pump", "arrows", "bee"]
const INFO := {
	"hammer": {"name": "Münz-Hämmern", "help": "A so schnell wie möglich drücken!"},
	"catch": {"name": "Sternen-Fänger", "help": "Stick: Körbchen bewegen · Sterne fangen, Wolken meiden"},
	"rhythm": {"name": "Takt-Tipper", "help": "A drücken, wenn der Ring den Kreis trifft"},
	"pump": {"name": "Ballon-Pumpe", "help": "A und B abwechselnd drücken – pump den Ballon auf!"},
	"arrows": {"name": "Pfeil-Blitz", "help": "Stick sofort in Pfeilrichtung schnippen"},
	"bee": {"name": "Bienen-Flug", "help": "Stick: Biene fliegen · Blumen einsammeln"},
}

var kind := "hammer"
var slot := 0
var coins := 0
var t := 0.0
var running := false
var player_name := ""
var accent := Color.WHITE
var _rng := RandomNumberGenerator.new()
var _font: Font
# Zustand je Spielart
var _presses := 0
var _basket := 0.5
var _drops: Array[Dictionary] = []
var _drop_t := 0.0
var _rings: Array[float] = []
var _ring_i := 0
var _pump := 0.0
var _pump_last := ""
var _arrow := 0
var _arrow_lock := 0.0
var _prev_mag := 0.0
var _bee := Vector2(0.5, 0.5)
var _flower := Vector2(0.7, 0.3)
var _pop := 0.0
var _msg := ""
var _msg_t := 0.0
var _msg_col := Color.WHITE


func setup(k: String, input_slot: int, seed_v: int, pname: String, col: Color) -> AthlonChallenge:
	kind = k
	slot = input_slot
	player_name = pname
	accent = col
	_rng.seed = seed_v
	_font = UI.title_font()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	match kind:
		"rhythm":
			for i in 9:
				_rings.append(1.2 + i * 1.18)
		"arrows":
			_arrow = _rng.randi() % 4
		"bee":
			_flower = Vector2(_rng.randf_range(0.15, 0.85), _rng.randf_range(0.2, 0.85))
	return self


func start() -> void:
	running = true
	t = 0.0


## Simuliertes Ergebnis für CPU-Läufer (je nach Stärke).
static func sim_score(k: String, level: int, rng: RandomNumberGenerator) -> int:
	var base: float = {"hammer": 9.0, "catch": 8.0, "rhythm": 9.0, "pump": 8.0, "arrows": 9.0, "bee": 7.0}.get(k, 8.0)
	var mul: float = [0.65, 0.85, 1.05][clampi(level, 0, 2)]
	return clampi(int(round(base * mul + rng.randf_range(-2.5, 2.5))), 0, 15)


func _flash(text: String, col: Color) -> void:
	_msg = text
	_msg_t = 0.6
	_msg_col = col


func _add(n: int) -> void:
	coins = clampi(coins + n, 0, 15)
	_pop = 1.0
	if n > 0:
		Audio.sfx("coin", null, -8.0, 1.0 + coins * 0.03)
		_flash("+%d" % n, UI.GOLD)
	elif n < 0:
		Audio.sfx("coin_lose", null, -8.0)
		_flash("%d" % n, Color("#ff6b6b"))


func _process(delta: float) -> void:
	_pop = maxf(0.0, _pop - delta * 4.0)
	_msg_t = maxf(0.0, _msg_t - delta)
	queue_redraw()
	if not running:
		return
	t += delta
	if t >= DURATION:
		running = false
		done.emit(coins)
		return
	var mv := InputHub.move(slot)
	match kind:
		"hammer":
			if InputHub.pressed(slot, "a"):
				_presses += 1
				Audio.sfx("wood_hit", null, -14.0, 1.0 + (_presses % 6) * 0.05)
				if _presses % 6 == 0:
					_add(1)
		"catch":
			_basket = clampf(_basket + mv.x * delta * 1.4, 0.06, 0.94)
			_drop_t -= delta
			if _drop_t <= 0.0:
				_drop_t = _rng.randf_range(0.45, 0.75)
				_drops.append({"x": _rng.randf_range(0.08, 0.92), "y": -0.05, "bad": _rng.randf() < 0.25, "v": _rng.randf_range(0.42, 0.62)})
			for d in _drops:
				d.y = float(d.y) + float(d.v) * delta
			for d in _drops.duplicate():
				if float(d.y) > 0.86 and float(d.y) < 0.96 and absf(float(d.x) - _basket) < 0.1:
					_add(-1 if bool(d.bad) else 1)
					_drops.erase(d)
				elif float(d.y) > 1.05:
					_drops.erase(d)
		"rhythm":
			if InputHub.pressed(slot, "a") and _ring_i < _rings.size():
				var dt := absf(_rings[_ring_i] - t)
				if dt < 0.09:
					_add(2)
					_flash("Perfekt! +2", UI.GOLD)
				elif dt < 0.2:
					_add(1)
				else:
					_flash("Daneben", Color("#ff9db0"))
				_ring_i += 1
			while _ring_i < _rings.size() and t - _rings[_ring_i] > 0.2:
				_ring_i += 1
				_flash("Verpasst", Color("#ff9db0"))
		"pump":
			var key := ""
			if InputHub.pressed(slot, "a"):
				key = "a"
			elif InputHub.pressed(slot, "b"):
				key = "b"
			if key != "" and key != _pump_last:
				_pump_last = key
				_pump += 0.085
				Audio.sfx("whoosh", null, -16.0, 1.0 + _pump)
				if _pump >= 1.0:
					_pump = 0.0
					_add(3)
					Audio.sfx("pop", null, -4.0)
		"arrows":
			_arrow_lock = maxf(0.0, _arrow_lock - delta)
			var mag := mv.length()
			if mag > 0.65 and _prev_mag <= 0.65 and _arrow_lock <= 0.0:
				var dir := 0
				if absf(mv.x) > absf(mv.y):
					dir = 1 if mv.x > 0 else 3
				else:
					dir = 2 if mv.y > 0 else 0
				if dir == _arrow:
					_add(1)
					_arrow = (_arrow + 1 + _rng.randi() % 3) % 4
				else:
					_arrow_lock = 0.5
					_flash("Falsch!", Color("#ff6b6b"))
					Audio.sfx("ui_error", null, -10.0)
			_prev_mag = mag
		"bee":
			_bee += mv * delta * 0.75
			_bee = _bee.clamp(Vector2(0.05, 0.1), Vector2(0.95, 0.92))
			if _bee.distance_to(_flower) < 0.08:
				_add(1)
				_flower = Vector2(_rng.randf_range(0.12, 0.88), _rng.randf_range(0.18, 0.86))


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.16, 0.12, 0.22, 0.88), true)
	draw_rect(r, accent, false, 4.0)
	var title := String(INFO[kind].name)
	draw_string(_font, Vector2(14, 34), player_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, accent.lightened(0.3))
	var cs := "%d" % coins
	var csz := _font.get_string_size(cs, HORIZONTAL_ALIGNMENT_LEFT, -1, int(34 + _pop * 14))
	draw_circle(Vector2(size.x - 40 - csz.x, 24), 13, UI.GOLD)
	draw_string(_font, Vector2(size.x - 18 - csz.x, 36 + _pop * 4), cs, HORIZONTAL_ALIGNMENT_LEFT, -1, int(34 + _pop * 14), UI.GOLD)
	# Zeitleiste
	var frac := clampf(1.0 - t / DURATION, 0.0, 1.0)
	draw_rect(Rect2(Vector2(12, size.y - 16), Vector2((size.x - 24) * frac, 8)), accent if frac > 0.25 else Color("#ff6b6b"), true)
	var area := Rect2(Vector2(12, 48), Vector2(size.x - 24, size.y - 72))
	match kind:
		"hammer":
			var c := area.get_center()
			var fill := float(_presses % 6) / 6.0
			draw_circle(c, 46 + _pop * 10, UI.GOLD.darkened(0.2))
			draw_circle(c, 38 + _pop * 10, UI.GOLD)
			draw_arc(c, 60, -PI / 2, -PI / 2 + TAU * fill, 32, Color.WHITE, 8, true)
			_center_text(c + Vector2(0, 90), "A! A! A!", 26, Color.WHITE)
		"catch":
			for d in _drops:
				var p := area.position + Vector2(float(d.x), float(d.y)) * area.size
				if bool(d.bad):
					draw_circle(p, 14, Color("#8a8fa8"))
					draw_circle(p + Vector2(10, 4), 11, Color("#8a8fa8"))
				else:
					_star(p, 14, UI.GOLD)
			var bx := area.position.x + _basket * area.size.x
			var by := area.position.y + area.size.y * 0.92
			draw_rect(Rect2(Vector2(bx - 34, by - 12), Vector2(68, 22)), Color("#c98d5a"), true)
			draw_rect(Rect2(Vector2(bx - 38, by - 16), Vector2(76, 8)), Color("#e8c79a"), true)
		"rhythm":
			var c := area.get_center()
			draw_arc(c, 40, 0, TAU, 40, Color.WHITE, 6, true)
			if _ring_i < _rings.size():
				var dt := _rings[_ring_i] - t
				var rad := 40.0 + maxf(0.0, dt) * 150.0
				draw_arc(c, rad, 0, TAU, 48, accent.lightened(0.3), 5, true)
			_center_text(c + Vector2(0, 90), "%d / %d" % [mini(_ring_i, _rings.size()), _rings.size()], 22, Color(1, 1, 1, 0.7))
		"pump":
			var c := area.get_center() + Vector2(0, 10)
			var rad := 20.0 + _pump * 70.0
			draw_circle(c, rad, accent.lightened(0.15))
			draw_circle(c + Vector2(-rad * 0.3, -rad * 0.3), rad * 0.2, Color(1, 1, 1, 0.5))
			draw_line(c + Vector2(0, rad), c + Vector2(0, rad + 40), Color.WHITE, 2)
			_center_text(Vector2(c.x, area.end.y - 4), "A · B · A · B", 24, Color.WHITE)
		"arrows":
			var c := area.get_center()
			var d: Vector2 = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT][_arrow]
			var p := Vector2(-d.y, d.x)
			var col := Color("#ff6b6b") if _arrow_lock > 0.0 else Color("#ffd23f")
			draw_colored_polygon(PackedVector2Array([c + d * 60, c - d * 10 + p * 46, c - d * 10 - p * 46]), col)
			draw_line(c - d * 50, c - d * 5, col, 30)
		"bee":
			var fp := area.position + _flower * area.size
			for k in 5:
				var a := TAU * k / 5.0
				draw_circle(fp + Vector2(cos(a), sin(a)) * 11, 9, Color("#ff9fc6"))
			draw_circle(fp, 8, Color("#ffd23f"))
			var bp := area.position + _bee * area.size
			draw_circle(bp, 14, Color("#ffd23f"))
			draw_line(bp + Vector2(-6, -12), bp + Vector2(-6, 12), Color(0.15, 0.1, 0.05), 4)
			draw_line(bp + Vector2(3, -13), bp + Vector2(3, 13), Color(0.15, 0.1, 0.05), 4)
			draw_circle(bp + Vector2(-4, -15), 7, Color(1, 1, 1, 0.7))
			draw_circle(bp + Vector2(6, -15), 7, Color(1, 1, 1, 0.7))
	if _msg_t > 0.0:
		var mc := _msg_col
		mc.a = clampf(_msg_t / 0.3, 0.0, 1.0)
		_center_text(Vector2(size.x * 0.5, 80 - (0.6 - _msg_t) * 30.0), _msg, 30, mc)
	if not running and t >= DURATION:
		draw_rect(r, Color(0, 0, 0, 0.45), true)
		_center_text(size * 0.5, "Fertig! %d Münzen" % coins, 34, UI.GOLD)
	elif not running:
		_center_text(Vector2(size.x * 0.5, size.y - 34), title, 26, Color(1, 1, 1, 0.8))


func _center_text(p: Vector2, s: String, fs: int, col: Color) -> void:
	var sz := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(_font, p - Vector2(sz.x * 0.5, -sz.y * 0.3), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2 + TAU * k / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)
