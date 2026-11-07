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


## Verankert ein Control und setzt die Offsets relativ zum Anker – unabhängig davon, ob es schon im
## Baum hängt (Control.position rechnet sonst gegen die aktuelle Elterngröße und landet außerhalb).
static func place(c: Control, preset: int, pos: Vector2, sz := Vector2.ZERO) -> void:
	c.set_anchors_preset(preset)
	var s := sz if sz != Vector2.ZERO else c.get_combined_minimum_size()
	c.offset_left = pos.x
	c.offset_top = pos.y
	c.offset_right = pos.x + s.x
	c.offset_bottom = pos.y + s.y


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


## Hinweiszeile als Text (Fallback ohne Symbolbild), z. B. "Leertaste: Weiter".
static func prompt_text(action: String, text: String) -> String:
	if InputHub.last_device == "touch":
		return "Tippen: " + text
	return "%s: %s" % [InputHub.glyph(action), text]


# --- Vektor-Icons (SVG, zur Laufzeit gerastert – schriftunabhängig, keine Tofu-Kästchen) ----

const SVG_ICONS := {
	"arrow_left": "<path d='M40 10 L18 32 L40 54' fill='none' stroke='#C' stroke-width='11' stroke-linecap='round' stroke-linejoin='round'/>",
	"arrow_right": "<path d='M24 10 L46 32 L24 54' fill='none' stroke='#C' stroke-width='11' stroke-linecap='round' stroke-linejoin='round'/>",
	"arrow_up": "<path d='M10 40 L32 18 L54 40' fill='none' stroke='#C' stroke-width='11' stroke-linecap='round' stroke-linejoin='round'/>",
	"arrow_down": "<path d='M10 24 L32 46 L54 24' fill='none' stroke='#C' stroke-width='11' stroke-linecap='round' stroke-linejoin='round'/>",
	"heart": "<path d='M32 56 C10 40 4 30 4 20 C4 11 11 5 19 5 C25 5 29 8 32 13 C35 8 39 5 45 5 C53 5 60 11 60 20 C60 30 54 40 32 56 Z' fill='#C' stroke='#3a0a1a' stroke-width='4'/><ellipse cx='20' cy='18' rx='6' ry='4' fill='#fff' opacity='0.55'/>",
	"cross": "<path d='M14 14 L50 50 M50 14 L14 50' stroke='#C' stroke-width='12' stroke-linecap='round'/>",
	"check": "<path d='M10 34 L26 50 L54 16' fill='none' stroke='#C' stroke-width='11' stroke-linecap='round' stroke-linejoin='round'/>",
	"star": "<path d='M32 4 L40 23 L60 24 L44 37 L50 58 L32 46 L14 58 L20 37 L4 24 L24 23 Z' fill='#C' stroke='#5a3000' stroke-width='3' stroke-linejoin='round'/>",
	"pause": "<rect x='14' y='10' width='12' height='44' rx='4' fill='#C'/><rect x='38' y='10' width='12' height='44' rx='4' fill='#C'/>",
	"play": "<path d='M18 8 L54 32 L18 56 Z' fill='#C' stroke-linejoin='round'/>",
	"back": "<path d='M28 12 L10 30 L28 48 M12 30 L42 30 C52 30 56 38 56 44' fill='none' stroke='#C' stroke-width='9' stroke-linecap='round' stroke-linejoin='round'/>",
	"globe": "<circle cx='32' cy='32' r='24' fill='none' stroke='#C' stroke-width='6'/><path d='M8 32 H56 M32 8 C20 20 20 44 32 56 C44 44 44 20 32 8' fill='none' stroke='#C' stroke-width='5'/>",
	"user": "<circle cx='32' cy='22' r='12' fill='#C'/><path d='M8 58 C10 42 20 36 32 36 C44 36 54 42 56 58 Z' fill='#C'/>",
	"lock": "<rect x='12' y='28' width='40' height='30' rx='6' fill='#C'/><path d='M20 28 V20 C20 12 26 8 32 8 C38 8 44 12 44 20 V28' fill='none' stroke='#C' stroke-width='7'/>",
	"gamepad": "<path d='M14 20 H50 C58 20 62 28 62 38 C62 50 56 54 50 50 L42 44 H22 L14 50 C8 54 2 50 2 38 C2 28 6 20 14 20 Z' fill='#C'/><circle cx='46' cy='31' r='4' fill='#1a0833'/><circle cx='52' cy='37' r='4' fill='#1a0833'/><path d='M14 34 H26 M20 28 V40' stroke='#1a0833' stroke-width='5' stroke-linecap='round'/>",
	"trophy": "<path d='M18 8 H46 V22 C46 32 40 38 32 38 C24 38 18 32 18 22 Z' fill='#C'/><path d='M18 14 H8 C8 24 12 28 18 28 M46 14 H56 C56 24 52 28 46 28' fill='none' stroke='#C' stroke-width='5'/><rect x='28' y='38' width='8' height='10' fill='#C'/><rect x='18' y='48' width='28' height='8' rx='3' fill='#C'/>",
	"bolt": "<path d='M36 4 L12 36 H30 L26 60 L52 26 H34 Z' fill='#C' stroke-linejoin='round'/>",
	"dice": "<rect x='8' y='8' width='48' height='48' rx='10' fill='#C'/><circle cx='22' cy='22' r='5' fill='#1a0833'/><circle cx='42' cy='42' r='5' fill='#1a0833'/><circle cx='32' cy='32' r='5' fill='#1a0833'/>",
}

static var _icon_cache := {}


## Gerastertes Vektor-Icon als Textur (gecacht).
static func icon_tex(name: String, px := 48, color := Color.WHITE) -> Texture2D:
	var key := "%s_%d_%s" % [name, px, color.to_html()]
	if _icon_cache.has(key):
		return _icon_cache[key]
	var body: String = SVG_ICONS.get(name, SVG_ICONS.star)
	body = body.replace("#C", "#" + color.to_html(false))
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>%s</svg>" % body
	var img := Image.new()
	var err := img.load_svg_from_string(svg, px / 64.0)
	if err != OK:
		img = Image.create(px, px, false, Image.FORMAT_RGBA8)
		img.fill(color)
	var tex := ImageTexture.create_from_image(img)
	_icon_cache[key] = tex
	return tex


static func icon_rect(name: String, px := 40, color := Color.WHITE) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = icon_tex(name, px * 2, color)
	tr.custom_minimum_size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## Hinweis mit echtem Button-Symbol des aktuellen Eingabegeräts ("[A] Weiter").
static func prompt(action: String, text: String, size := 30) -> ButtonPrompt:
	return ButtonPrompt.new().setup(action, text, size)
