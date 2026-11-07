class_name UI
extends RefCounted
## Statische UI-Fabrik: Theme, Schriften, Buttons, Panels, Labels im Lumos-Party-Stil.

const BG_DARK := Color("#170b33")
const PANEL := Color(0.11, 0.06, 0.25, 0.93)
const ACCENT := Color("#ff4fb8")
const ACCENT2 := Color("#5ab8ff")
const GOLD := Color("#ffcc33")
const TEXT := Color("#fff8ff")
const OUTLINE := Color("#1a0833")

static var _theme: Theme
static var _title_font: Font
static var _body_font: Font
static var _bold_font: Font


static func title_font() -> Font:
	if _title_font == null:
		_title_font = load(Assets.FONT_TITLE)
	return _title_font


static func body_font() -> Font:
	if _body_font == null:
		var base: Font = load(Assets.FONT_BODY)
		var fv := FontVariation.new()
		fv.base_font = base
		var ts := TextServerManager.get_primary_interface()
		fv.variation_opentype = {ts.name_to_tag("wght"): 500}
		_body_font = fv
	return _body_font


static func bold_font() -> Font:
	if _bold_font == null:
		var base: Font = load(Assets.FONT_BODY)
		var fv := FontVariation.new()
		fv.base_font = base
		var ts := TextServerManager.get_primary_interface()
		fv.variation_opentype = {ts.name_to_tag("wght"): 650}
		_bold_font = fv
	return _bold_font


static func box(color: Color, radius := 22, border := 0, border_color := Color.TRANSPARENT, bottom := 0, shadow := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 8
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = border_color
	if bottom > 0:
		sb.border_width_bottom = bottom
		sb.border_color = border_color if border_color.a > 0 else color.darkened(0.4)
	if shadow > 0:
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = shadow
		sb.shadow_offset = Vector2(0, shadow * 0.5)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.anti_aliasing = true
	return sb


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 26
	# Buttons
	var base := Color("#7b3cff")
	t.set_stylebox("normal", "Button", box(base, 24, 0, Color.TRANSPARENT, 8, 6))
	t.set_stylebox("hover", "Button", box(base.lightened(0.12), 24, 0, Color.TRANSPARENT, 8, 8))
	t.set_stylebox("pressed", "Button", box(base.darkened(0.1), 24, 0, Color.TRANSPARENT, 2, 2))
	t.set_stylebox("disabled", "Button", box(Color(0.35, 0.3, 0.45), 24, 0, Color.TRANSPARENT, 6, 0))
	var focus := box(Color(1, 1, 1, 0), 26, 5, GOLD)
	focus.draw_center = false
	t.set_stylebox("focus", "Button", focus)
	t.set_font("font", "Button", title_font())
	t.set_font_size("font_size", "Button", 32)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_outline_color", "Button", OUTLINE)
	t.set_constant("outline_size", "Button", 8)
	# Panels
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 30, 4, Color(1, 1, 1, 0.14), 0, 14))
	t.set_stylebox("panel", "Panel", box(PANEL, 30, 4, Color(1, 1, 1, 0.14), 0, 14))
	# Labels
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", OUTLINE)
	t.set_constant("outline_size", "Label", 6)
	# Slider / CheckButton
	t.set_stylebox("slider", "HSlider", box(Color(1, 1, 1, 0.18), 10, 0, Color.TRANSPARENT, 0, 0))
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT, 10, 0, Color.TRANSPARENT, 0, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT.lightened(0.2), 10, 0, Color.TRANSPARENT, 0, 0))
	t.set_font("font", "CheckButton", bold_font())
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_font("font", "OptionButton", title_font())
	t.set_stylebox("normal", "OptionButton", box(base, 20, 0, Color.TRANSPARENT, 6, 4))
	t.set_stylebox("hover", "OptionButton", box(base.lightened(0.12), 20, 0, Color.TRANSPARENT, 6, 4))
	t.set_stylebox("pressed", "OptionButton", box(base.darkened(0.1), 20, 0, Color.TRANSPARENT, 2, 2))
	t.set_stylebox("focus", "OptionButton", focus)
	t.set_font("font", "PopupMenu", bold_font())
	t.set_font_size("font_size", "PopupMenu", 26)
	t.set_stylebox("panel", "PopupMenu", box(PANEL, 18, 3, Color(1, 1, 1, 0.2), 0, 8))
	t.set_stylebox("panel", "TooltipPanel", box(PANEL, 12))
	_theme = t
	return t


static func label(text: String, size := 28, color := TEXT, title := false, outline := 6) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", title_font() if title else bold_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	return l


static func button(text: String, color := Color("#7b3cff"), size := 32, min_w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	if color != Color("#7b3cff"):
		b.add_theme_stylebox_override("normal", box(color, 24, 0, Color.TRANSPARENT, 8, 6))
		b.add_theme_stylebox_override("hover", box(color.lightened(0.12), 24, 0, Color.TRANSPARENT, 8, 8))
		b.add_theme_stylebox_override("pressed", box(color.darkened(0.1), 24, 0, Color.TRANSPARENT, 2, 2))
	if min_w > 0:
		b.custom_minimum_size.x = min_w
	b.focus_entered.connect(func() -> void:
		Audio.sfx("ui_move", null, -6.0)
		Juice.ui_punch(b, 0.06, 0.25))
	b.mouse_entered.connect(func() -> void:
		if not b.has_focus() and not b.disabled:
			b.grab_focus())
	b.pressed.connect(func() -> void:
		Audio.sfx("ui_confirm", null, -3.0)
		InputHub.vibrate_device(10)
		Juice.ui_punch(b, 0.12, 0.3))
	return b


static func panel(color := PANEL, radius := 30) -> PanelContainer:
	var p := PanelContainer.new()
	if color != PANEL or radius != 30:
		p.add_theme_stylebox_override("panel", box(color, radius, 4, Color(1, 1, 1, 0.14), 0, 14))
	return p


static func vbox(sep := 14) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 14) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func center_root(parent: Node) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.theme = theme()
	parent.add_child(c)
	return c


## Hintergrund-Gradient (Party-Lila -> Pink) als fullscreen TextureRect.
static func gradient_bg(parent: Node, top := Color("#2a0f5c"), bottom := Color("#ff4fb8")) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr


## Hinweiszeile "Ⓐ Weiter" passend zum Eingabegerät.
static func prompt_text(action: String, text: String) -> String:
	if InputHub.last_device == "touch":
		return "Tippen: " + text
	return "%s  %s" % [InputHub.glyph(action), text]
