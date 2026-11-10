class_name PlayerBadge
extends PanelContainer
## Spieler-Anzeige für HUDs: Farbe, Name, Münzen, Sterne bzw. Minispiel-Punkte.
## Zahlen zählen animiert hoch/runter, das Badge hüpft bei Änderungen.

var player := 0
var show_coins := true
var show_stars := true
var score_mode := false

var _name: Label
var _coins: Label
var _stars: Label
var _score: Label
var _place: Label
var _shown_coins := 0
var _shown_stars := 0
var _crown: UIIcon
var _status_icon: TextureRect
var _status := ""
var _cpu_tag: Label


func setup(p: int, compact := false, scores := false) -> PlayerBadge:
	player = p
	score_mode = scores
	var col: Color = Game.player_color(p)
	add_theme_stylebox_override("panel", UI.box(Color(col.darkened(0.55), 0.92), 22, 4, col, 0, 8))
	var h := UI.hbox(10)
	add_child(h)
	_place = UI.label("", 34, UI.GOLD, true)
	_place.custom_minimum_size.x = 30
	h.add_child(_place)
	var v := UI.vbox(0)
	h.add_child(v)
	var name_row := UI.hbox(6)
	v.add_child(name_row)
	_name = UI.label(Game.hero(Game.players[p].hero).name.split(" ")[0] if compact else Game.hero(Game.players[p].hero).name, 22 if compact else 24, col.lightened(0.45))
	name_row.add_child(_name)
	_cpu_tag = UI.label("CPU" if Game.players[p].cpu else "P%d" % (p + 1), 16, Color(1, 1, 1, 0.65))
	name_row.add_child(_cpu_tag)
	_crown = UIIcon.new("crown", 26)
	_crown.visible = false
	name_row.add_child(_crown)
	var stats := UI.hbox(8)
	v.add_child(stats)
	if score_mode:
		_status_icon = TextureRect.new()
		_status_icon.custom_minimum_size = Vector2(30, 30)
		_status_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_status_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_status_icon.visible = false
		stats.add_child(_status_icon)
		_score = UI.label("0", 34, Color.WHITE, true)
		stats.add_child(_score)
	else:
		stats.add_child(UIIcon.new("star", 30))
		_stars = UI.label("0", 30, UI.GOLD, true)
		stats.add_child(_stars)
		stats.add_child(UIIcon.new("coin", 28))
		_coins = UI.label("0", 30, Color.WHITE, true)
		stats.add_child(_coins)
		_shown_coins = Game.players[p].coins
		_shown_stars = Game.players[p].stars
		_refresh_numbers()
		EventBus.coins_changed.connect(_on_coins)
		EventBus.stars_changed.connect(_on_stars)
	return self


func _refresh_numbers() -> void:
	if _coins:
		_coins.text = str(_shown_coins)
	if _stars:
		_stars.text = str(_shown_stars)


func _on_coins(p: int, total: int, delta: int) -> void:
	if p != player or delta == 0:
		return
	var tw := create_tween()
	var from := _shown_coins
	tw.tween_method(func(v: float) -> void:
		_shown_coins = int(round(v))
		_refresh_numbers(), float(from), float(total), clampf(absf(delta) * 0.05, 0.25, 1.2))
	Juice.ui_punch(self, 0.08 if delta > 0 else -0.06, 0.35)
	if _coins:
		_coins.add_theme_color_override("font_color", Color("#7dff9a") if delta > 0 else Color("#ff6b6b"))
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			if is_instance_valid(_coins):
				_coins.add_theme_color_override("font_color", Color.WHITE))


func _on_stars(p: int, total: int, _delta: int) -> void:
	if p != player:
		return
	_shown_stars = total
	_refresh_numbers()
	Juice.ui_punch(self, 0.2, 0.5)


func set_score(v: Variant) -> void:
	if _score:
		var s := str(v)
		if _score.text != s:
			_score.text = s
			Juice.ui_punch(_score, 0.25, 0.3)


## Status mit Symbol: "hearts" (Wert = Anzahl), "alive", "out", "done" (Wert = Platz), "" = nur Zahl.
func set_status(kind: String, value: Variant = null) -> void:
	if _score == null:
		return
	var key := "%s:%s" % [kind, str(value)]
	if key == _status:
		return
	var kind_changed := not _status.begins_with(kind + ":")
	_status = key
	match kind:
		"hearts":
			_status_icon.texture = UI.icon_tex("heart", 60, Color("#ff4d6d"))
			_status_icon.visible = true
			_score.text = "x%d" % int(value)
		"alive":
			_status_icon.texture = UI.icon_tex("heart", 60, Color("#ff4d6d"))
			_status_icon.visible = true
			_score.text = ""
		"out":
			_status_icon.texture = UI.icon_tex("cross", 60, Color("#9aa0b0"))
			_status_icon.visible = true
			_score.text = "raus"
		"done":
			_status_icon.texture = UI.icon_tex("check", 60, Color("#7dff9a"))
			_status_icon.visible = true
			_score.text = "%d." % int(value)
		_:
			_status_icon.visible = false
			_score.text = str(value)
	if kind_changed:
		Juice.ui_punch(self, 0.12, 0.3)


func set_place(place: int) -> void:
	_place.text = str(place) if place > 0 else ""
	_crown.visible = place == 1


func set_out(out: bool) -> void:
	modulate = Color(0.55, 0.55, 0.6, 0.85) if out else Color.WHITE
