class_name UI
extends RefCounted
## Statische UI-Fabrik: Theme, Schriften, Buttons, Panels, Labels im Lumos-Party-Stil.
## Seit 1.2.3 im „Cozy“-Look: Holz-, Creme- und Rot-Elemente aus dem Cozy UI Pack (9-Slice-Texturen unter
## assets/ui/cozy/s/), warme Palette, eigener Mauszeiger. Farbige Buttons/Panels entstehen durch Einfärben
## der hellen Vorlagen – Bedeutungsfarben (Rot = zurück, Grün = los …) bleiben erhalten.

const BG_DARK := Color("#24140e")
const PANEL := Color(0.29, 0.17, 0.11, 0.95)
const ACCENT := Color("#f2665c")
const ACCENT2 := Color("#43b8c9")
const GOLD := Color("#ffcc33")
const TEXT := Color("#fff7e8")
const OUTLINE := Color("#2e1708")
const COZY := "res://assets/ui/cozy/s/"
## Alle Cozy-Texturen (für die Export-Liste)
const COZY_TEX := ["btn_wood", "btn_white", "btn_red", "pill_wood", "pill_white", "panel_wood", "panel_grey", "panel_blue",
	"card_wood", "card_red", "bar_wood", "note", "hotbar", "slot", "slot_sel", "check_on", "check_off", "check_x", "knob",
	"knob_wood", "arrow_l", "arrow_u", "arrow_d", "arrow_r", "arrow_l_cream", "arrow_r_cream", "icon_heart", "icon_heart_dark",
	"icon_plus", "icon_x", "icon_bolt", "cursor", "cursor_click"]
## 9-Slice-Ränder je Textur (links, oben, rechts, unten) in Texturpixeln
const COZY_MARGIN := {
	"btn": Vector4(20, 14, 20, 22), "pill": Vector4(32, 14, 32, 22), "panel": Vector4(26, 26, 26, 32),
	"card": Vector4(26, 34, 26, 30), "bar": Vector4(36, 24, 36, 30), "note": Vector4(34, 20, 22, 22),
	"hotbar": Vector4(36, 24, 36, 26), "slot": Vector4(20, 20, 20, 24)}

static var _theme: Theme
static var _title_font: Font
static var _body_font: Font
static var _bold_font: Font


## Größte Schriftgröße ≤ base, bei der jede Zeile von text höchstens max_w breit ist (lange Namen,
## schmale Handy-Bildschirme). outline_k: Anteil der Kontur an der Schriftgröße (sie verbreitert den Text).
static func fit_font_size(text: String, font: Font, base: int, max_w: float, min_size := 16, outline_k := 0.16) -> int:
	if font == null or text == "" or max_w <= 0.0:
		return base
	var size := base
	for _i in 8:
		var w := 0.0
		for line in text.split("\n"):
			w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + size * outline_k * 2.0)
		if w <= max_w or size <= min_size:
			break
		size = maxi(min_size, int(floor(size * max_w / w)))
	return size


## Label auf die verfügbare Breite einpassen (setzt font_size; Kontur/Schatten wachsen proportional mit).
static func fit_label(l: Label, base: int, max_w: float, min_size := 16) -> void:
	var fs := fit_font_size(l.text, l.get_theme_font("font"), base, max_w, min_size)
	l.add_theme_font_size_override("font_size", fs)
	if l.has_theme_constant_override("outline_size"):
		l.add_theme_constant_override("outline_size", int(fs * 0.16))
	if l.has_theme_constant_override("shadow_offset_y"):
		l.add_theme_constant_override("shadow_offset_y", int(fs * 0.06))


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


## Glyphen-Caches der Schriften leeren (beim Szenenwechsel). Jede Schriftgröße × Konturstärke × Gewicht legt eigene
## Texturseiten im Grafikspeicher an (gemessen: ~3 MB je Größe mit Kontur) – und die Engine gibt sie nie frei.
## Angepasste Labels, schwebende Texte, Bossnamen … erzeugen über eine lange Session hunderte Größen; auf
## iPhones lief der Grafikspeicher so nach 10–15 Runden voll, Safari hat den Tab neu geladen. Die Glyphen der
## neuen Szene werden beim ersten Zeichnen neu gerastert (während des Ladebildschirms).
static func clear_font_caches() -> void:
	for p in [Assets.FONT_TITLE, Assets.FONT_BODY]:
		var f := load(p) as FontFile
		if f == null:
			continue
		# nur die Größen-Caches (Glyphen-Texturen) – die Schrift selbst bleibt gültig, laufende Texte zeichnen weiter
		for c in f.get_cache_count():
			f.clear_size_cache(c)


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


static var _tex_cache: Dictionary = {}


static func cozy(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		_tex_cache[name] = load(COZY + name + ".png")
	return _tex_cache[name]


## 9-Slice-Stylebox aus einer Cozy-Textur. tint färbt ein (helle Vorlagen „white/grey“), pad = Innenabstand.
static func tex_box(name: String, tint := Color.WHITE, pad := Vector4(18, 8, 18, 12)) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = cozy(name)
	var m: Vector4 = COZY_MARGIN.get(name.get_slice("_", 0), Vector4(20, 20, 20, 20))
	sb.texture_margin_left = m.x
	sb.texture_margin_top = m.y
	sb.texture_margin_right = m.z
	sb.texture_margin_bottom = m.w
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	sb.modulate_color = tint
	return sb


## Button-Styleboxen (normal/hover/pressed/disabled) für eine Grundfarbe; null = Holz
static func button_boxes(color: Variant = null) -> Dictionary:
	var tex := "btn_wood" if color == null else "btn_white"
	var c: Color = Color.WHITE if color == null else (color as Color).lightened(0.08)
	var pressed := tex_box(tex, c.darkened(0.14), Vector4(18, 11, 18, 9))
	return {"normal": tex_box(tex, c), "hover": tex_box(tex, c * Color(1.12, 1.1, 1.06)), "pressed": pressed,
		"disabled": tex_box("btn_white", Color(0.62, 0.58, 0.55, 0.85))}


## Panel im Cozy-Stil: Holz (Standard), Blau (hervorgehoben) oder eingefärbtes Grau (Spielerfarbe & Co.)
static func cozy_panel(color: Variant = null, pad := 22) -> StyleBoxTexture:
	if color == null:
		# Leicht abgedunkeltes Holz: helle und spielerfarbige Schrift bleibt gut lesbar
		return tex_box("panel_wood", Color(0.74, 0.6, 0.53), Vector4(pad, pad - 4, pad, pad))
	return tex_box("panel_grey", color as Color, Vector4(pad, pad - 4, pad, pad))


## Eigener Mauszeiger (Desktop): Pfeil + Klick-Variante für Buttons
static func apply_cursor() -> void:
	if DisplayServer.is_touchscreen_available() and OS.has_feature("mobile"):
		return
	Input.set_custom_mouse_cursor(cozy("cursor"), Input.CURSOR_ARROW, Vector2(3, 2))
	Input.set_custom_mouse_cursor(cozy("cursor_click"), Input.CURSOR_POINTING_HAND, Vector2(3, 2))


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 26
	# Buttons: Holz-Vorlage aus dem Cozy UI Pack
	var bb := button_boxes()
	for st in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(st, "Button", bb[st])
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
	# Panels: Holzkasten
	t.set_stylebox("panel", "PanelContainer", cozy_panel())
	t.set_stylebox("panel", "Panel", cozy_panel())
	# Labels
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", OUTLINE)
	t.set_constant("outline_size", "Label", 6)
	# Slider / CheckButton
	t.set_stylebox("slider", "HSlider", box(Color(1, 1, 1, 0.18), 10, 0, Color.TRANSPARENT, 0, 0))
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT, 10, 0, Color.TRANSPARENT, 0, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT.lightened(0.2), 10, 0, Color.TRANSPARENT, 0, 0))
	t.set_icon("grabber", "HSlider", cozy("knob"))
	t.set_icon("grabber_highlight", "HSlider", cozy("knob_wood"))
	t.set_font("font", "CheckButton", bold_font())
	t.set_color("font_color", "CheckButton", TEXT)
	# Häkchen-Kästchen aus dem Pack statt Schiebeschalter
	for cls in ["CheckButton", "CheckBox"]:
		t.set_icon("checked", cls, cozy("check_on"))
		t.set_icon("unchecked", cls, cozy("check_off"))
		t.set_icon("checked_disabled", cls, cozy("check_on"))
		t.set_icon("unchecked_disabled", cls, cozy("check_off"))
	t.set_font("font", "OptionButton", title_font())
	t.set_stylebox("normal", "OptionButton", tex_box("pill_wood", Color.WHITE, Vector4(26, 8, 40, 12)))
	t.set_stylebox("hover", "OptionButton", tex_box("pill_wood", Color(1.12, 1.1, 1.06), Vector4(26, 8, 40, 12)))
	t.set_stylebox("pressed", "OptionButton", tex_box("pill_wood", Color(0.86, 0.86, 0.86), Vector4(26, 11, 40, 9)))
	t.set_stylebox("focus", "OptionButton", focus)
	t.set_font("font", "PopupMenu", bold_font())
	t.set_font_size("font_size", "PopupMenu", 26)
	t.set_stylebox("panel", "PopupMenu", cozy_panel(null, 14))
	t.set_stylebox("panel", "TooltipPanel", tex_box("note", Color.WHITE, Vector4(38, 12, 20, 14)))
	t.set_color("font_color", "TooltipLabel", Color("#4a2c1c"))
	t.set_color("font_outline_color", "TooltipLabel", Color(0, 0, 0, 0))
	# Scrollleisten: dünne Holzleiste (Wischen per Touch übernimmt das System-Update)
	t.set_stylebox("grabber", "VScrollBar", box(Color("#c98b5a"), 8, 0, Color.TRANSPARENT, 0, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(Color("#e0a676"), 8, 0, Color.TRANSPARENT, 0, 0))
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0.18), 8, 0, Color.TRANSPARENT, 0, 0))
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
		# Farbige Buttons: helle Cozy-Vorlage eingefärbt (Bedeutungsfarbe bleibt, Look bleibt einheitlich)
		var bx := button_boxes(color)
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, bx[st])
	if min_w > 0:
		b.custom_minimum_size.x = min_w
	b.focus_entered.connect(func() -> void:
		Audio.sfx("ui_hover", null, -4.0, 1.0, 0.05)
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
		p.add_theme_stylebox_override("panel", cozy_panel(color, clampi(radius, 14, 30)))
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


## Wie center_root, aber innerhalb der sicheren Bildschirmränder (Notch, runde Displayecken, Home-Leiste).
## Für HUDs und Anzeigen an den Rändern; Hintergründe/Abdunklungen bleiben mit center_root randlos.
static func hud_root(parent: Node) -> Control:
	var c := center_root(parent)
	c.name = "SafeHud"
	var ref: WeakRef = weakref(c)   # schwach gebunden: verzögerte Aufrufe nach dem Freigeben laufen ins Leere statt in Fehler
	c.resized.connect(_fit_safe.bind(ref), CONNECT_DEFERRED)   # erst nachdem InputHub die Ränder neu gemessen hat
	c.tree_entered.connect(_fit_safe.bind(ref))
	_fit_safe(ref)
	return c


static func _fit_safe(ref: WeakRef) -> void:
	var c := ref.get_ref() as Control
	if c == null:
		return
	var m := InputHub.safe_margins()
	if not is_equal_approx(c.offset_left, m.x) or not is_equal_approx(c.offset_top, m.y) or not is_equal_approx(c.offset_right, -m.z) or not is_equal_approx(c.offset_bottom, -m.w):
		c.offset_left = m.x
		c.offset_top = m.y
		c.offset_right = -m.z
		c.offset_bottom = -m.w


## Hintergrund-Gradient (Party-Lila -> Pink) als fullscreen TextureRect.
static func gradient_bg(parent: Node, top := Color("#3a2440"), bottom := Color("#f08c64")) -> TextureRect:
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
	"target": "<circle cx='32' cy='32' r='20' fill='none' stroke='#2e1708' stroke-width='9'/><circle cx='32' cy='32' r='20' fill='none' stroke='#C' stroke-width='5'/><path d='M32 2 V18 M32 46 V62 M2 32 H18 M46 32 H62' stroke='#2e1708' stroke-width='8' stroke-linecap='round'/><path d='M32 4 V17 M32 47 V60 M4 32 H17 M47 32 H60' stroke='#C' stroke-width='4' stroke-linecap='round'/><circle cx='32' cy='32' r='3.5' fill='#C'/>",
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
	"gear": "<circle cx='32' cy='32' r='11' fill='none' stroke='#C' stroke-width='8'/><path d='M32 4 V14 M32 50 V60 M4 32 H14 M50 32 H60 M12 12 L19 19 M45 45 L52 52 M12 52 L19 45 M45 19 L52 12' stroke='#C' stroke-width='9' stroke-linecap='round'/>",
	"info": "<circle cx='32' cy='32' r='26' fill='none' stroke='#C' stroke-width='6'/><circle cx='32' cy='19' r='5' fill='#C'/><rect x='27' y='28' width='10' height='22' rx='4' fill='#C'/>",
	"music": "<path d='M24 46 V14 L52 7 V40' fill='none' stroke='#C' stroke-width='6' stroke-linejoin='round'/><circle cx='17' cy='46' r='9' fill='#C'/><circle cx='45' cy='40' r='9' fill='#C'/>",
	"trophy": "<path d='M18 8 H46 V22 C46 32 40 38 32 38 C24 38 18 32 18 22 Z' fill='#C'/><path d='M18 14 H8 C8 24 12 28 18 28 M46 14 H56 C56 24 52 28 46 28' fill='none' stroke='#C' stroke-width='5'/><rect x='28' y='38' width='8' height='10' fill='#C'/><rect x='18' y='48' width='28' height='8' rx='3' fill='#C'/>",
	"bolt": "<path d='M36 4 L12 36 H30 L26 60 L52 26 H34 Z' fill='#C' stroke-linejoin='round'/>",
	"dice": "<rect x='8' y='8' width='48' height='48' rx='10' fill='#C'/><circle cx='22' cy='22' r='5' fill='#1a0833'/><circle cx='42' cy='42' r='5' fill='#1a0833'/><circle cx='32' cy='32' r='5' fill='#1a0833'/>",
	"cherry": "<path d='M22 44 C24 30 30 18 44 8 M42 44 C40 32 40 22 44 8' fill='none' stroke='#C' stroke-width='4' stroke-linecap='round'/><circle cx='20' cy='46' r='12' fill='#C'/><circle cx='44' cy='46' r='12' fill='#C'/>",
	"bell": "<path d='M32 6 C20 6 14 16 14 28 V40 L8 48 H56 L50 40 V28 C50 16 44 6 32 6 Z' fill='#C'/><circle cx='32' cy='54' r='6' fill='#C'/>",
	"clover": "<circle cx='22' cy='22' r='12' fill='#C'/><circle cx='42' cy='22' r='12' fill='#C'/><circle cx='22' cy='40' r='12' fill='#C'/><circle cx='42' cy='40' r='12' fill='#C'/><path d='M32 32 L40 60' stroke='#C' stroke-width='5' stroke-linecap='round'/>",
	"coin": "<circle cx='32' cy='32' r='26' fill='#C'/><circle cx='32' cy='32' r='17' fill='none' stroke='#FFFFFF' stroke-opacity='0.55' stroke-width='4'/><rect x='29' y='20' width='6' height='24' rx='3' fill='#FFFFFF' fill-opacity='0.6'/>",
	"mushroom": "<path d='M6 34 C6 16 18 6 32 6 C46 6 58 16 58 34 Z' fill='#C'/><rect x='22' y='32' width='20' height='24' rx='8' fill='#C' fill-opacity='0.65'/><circle cx='22' cy='20' r='5' fill='#FFFFFF' fill-opacity='0.8'/><circle cx='42' cy='22' r='4' fill='#FFFFFF' fill-opacity='0.8'/>",
	"ghost": "<path d='M12 58 V28 C12 14 20 6 32 6 C44 6 52 14 52 28 V58 L44 52 L38 58 L32 52 L26 58 L20 52 Z' fill='#C'/><circle cx='25' cy='28' r='4' fill='#000000' fill-opacity='0.7'/><circle cx='39' cy='28' r='4' fill='#000000' fill-opacity='0.7'/>",
	"crown": "<path d='M6 22 L18 34 L32 12 L46 34 L58 22 L52 52 H12 Z' fill='#C' stroke-linejoin='round'/>",
	"chest": "<rect x='6' y='26' width='52' height='30' rx='4' fill='#C'/><path d='M6 28 C6 14 16 10 32 10 C48 10 58 14 58 28 Z' fill='#C' fill-opacity='0.8'/><rect x='28' y='26' width='8' height='12' rx='2' fill='#FFFFFF' fill-opacity='0.7'/>",
}

static var _icon_cache := {}


static func cache_size() -> int:
	return _icon_cache.size() + _tex_cache.size()


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
