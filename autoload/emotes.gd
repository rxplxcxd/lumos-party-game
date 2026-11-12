extends CanvasLayer
## Emote-System: Spieler reagieren jederzeit schnell – auf dem Brett, in Minispielen, im Menü und online.
## Eigene, gezeichnete Vektor-Emotes im Cozy-Stil (keine System-Emojis: die sähen je nach Gerät anders aus).
## Bedienung: Y halten (Tastatur Q) → Rad erscheint, Stick/Pfeile wählen, loslassen = senden.
## Maus/Touch: Sprechblasen-Knopf oben rechts → Emote antippen.
## Anzeige: Sprechblase über der eigenen Figur (Brett: rigs, Minispiel: actors), sonst als Toast.
## Online: {"k": "emo", "s": slot, "e": id} an alle.

const IDS := ["freude", "lachen", "wow", "grr", "traurig", "herz", "daumen", "cool"]
const NAMES := {"freude": "Juhu!", "lachen": "Haha!", "wow": "Wow!", "grr": "Grr!", "traurig": "Ohje …",
	"herz": "Lieb!", "daumen": "Super!", "cool": "Easy."}
const COOLDOWN := 1.1

const OUT := "#2e1708"
const SKIN := "#ffcf5a"
## Vektor-Zeichnungen (viewBox 0 0 64 64), Kontur in Holzbraun wie das Cozy-UI
const SVG := {
	"freude": "<circle cx='32' cy='32' r='27' fill='%s' stroke='%s' stroke-width='4'/><path d='M19 27 q4 -6 8 0 M37 27 q4 -6 8 0' fill='none' stroke='%s' stroke-width='3.5' stroke-linecap='round'/><path d='M18 36 q14 16 28 0 z' fill='#a8323a' stroke='%s' stroke-width='3' stroke-linejoin='round'/><ellipse cx='16' cy='36' rx='4' ry='2.6' fill='#ff8fab' opacity='0.8'/><ellipse cx='48' cy='36' rx='4' ry='2.6' fill='#ff8fab' opacity='0.8'/>",
	"lachen": "<circle cx='32' cy='32' r='27' fill='%s' stroke='%s' stroke-width='4'/><path d='M17 26 l7 3 l-7 3 M47 26 l-7 3 l7 3' fill='none' stroke='%s' stroke-width='3.5' stroke-linecap='round' stroke-linejoin='round'/><path d='M16 36 q16 20 32 0 z' fill='#a8323a' stroke='%s' stroke-width='3' stroke-linejoin='round'/><path d='M22 44 q10 6 20 0' fill='#ff8fab'/><path d='M8 30 q-3 8 2 10 q5 -2 2 -10 z M56 30 q3 8 -2 10 q-5 -2 -2 -10 z' fill='#6ec6ff'/>",
	"wow": "<circle cx='32' cy='32' r='27' fill='%s' stroke='%s' stroke-width='4'/><circle cx='23' cy='27' r='4.5' fill='%s'/><circle cx='41' cy='27' r='4.5' fill='%s'/><path d='M17 17 q6 -4 11 -1 M36 16 q5 -3 11 1' fill='none' stroke='%s' stroke-width='3' stroke-linecap='round'/><ellipse cx='32' cy='44' rx='6' ry='8' fill='#a8323a' stroke='%s' stroke-width='3'/>",
	"grr": "<circle cx='32' cy='33' r='26' fill='#ff8a5c' stroke='%s' stroke-width='4'/><path d='M17 22 l10 5 M47 22 l-10 5' stroke='%s' stroke-width='4' stroke-linecap='round'/><circle cx='24' cy='31' r='3.5' fill='%s'/><circle cx='40' cy='31' r='3.5' fill='%s'/><path d='M21 47 q11 -9 22 0' fill='none' stroke='%s' stroke-width='4' stroke-linecap='round'/><path d='M50 8 q4 3 1 6 q4 1 2 5' fill='none' stroke='#ffffff' stroke-width='3' stroke-linecap='round'/>",
	"traurig": "<circle cx='32' cy='32' r='27' fill='#9bd0ff' stroke='%s' stroke-width='4'/><path d='M18 24 q5 3 10 1 M36 25 q5 2 10 -1' fill='none' stroke='%s' stroke-width='3' stroke-linecap='round'/><circle cx='24' cy='31' r='3.5' fill='%s'/><circle cx='40' cy='31' r='3.5' fill='%s'/><path d='M22 47 q10 -8 20 0' fill='none' stroke='%s' stroke-width='3.5' stroke-linecap='round'/><path d='M43 36 q-4 8 0 10 q4 -2 0 -10 z' fill='#2f8cff'/>",
	"herz": "<path d='M32 56 C10 40 5 30 5 20 C5 11 12 6 20 6 C26 6 30 9 32 14 C34 9 38 6 44 6 C52 6 59 11 59 20 C59 30 54 40 32 56 Z' fill='#ff5d73' stroke='%s' stroke-width='4' stroke-linejoin='round'/><ellipse cx='20' cy='18' rx='6' ry='4' fill='#ffffff' opacity='0.6'/><path d='M54 6 l2 5 l5 2 l-5 2 l-2 5 l-2 -5 l-5 -2 l5 -2 z' fill='#ffe066'/>",
	"daumen": "<path d='M14 30 h10 v24 h-10 z' fill='#43b8c9' stroke='%s' stroke-width='3.5' stroke-linejoin='round'/><path d='M24 30 l8 -18 q4 -6 8 0 q2 4 -1 12 h13 q6 0 5 6 l-3 18 q-1 6 -7 6 h-23 z' fill='%s' stroke='%s' stroke-width='3.5' stroke-linejoin='round'/><path d='M40 36 h10 M40 43 h9' stroke='%s' stroke-width='2.5' stroke-linecap='round'/>",
	"cool": "<circle cx='32' cy='32' r='27' fill='%s' stroke='%s' stroke-width='4'/><path d='M11 24 h42 l-2 9 q-1 5 -7 5 h-6 q-5 0 -6 -6 q-1 6 -6 6 h-6 q-6 0 -7 -5 z' fill='#2b2236' stroke='%s' stroke-width='2'/><path d='M16 27 l5 0' stroke='#9be7ff' stroke-width='2'/><path d='M23 46 q10 6 20 -3' fill='none' stroke='%s' stroke-width='3.5' stroke-linecap='round'/>",
}

var _tex := {}
var _cd: Array[float] = [0, 0, 0, 0]
var _rx_at: Array[int] = [0, 0, 0, 0]   # Empfangs-Bremse (ms), falls ein Gerät zu oft sendet
var _wheel: Control
var _wheel_slot := -1
var _wheel_btns: Array[Control] = []
var _sel := -1
var _open_btn: Button
var _toasts: VBoxContainer


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	Net.message.connect(_on_net)
	var safe := UI.hud_root(self)   # Ecken-Knopf und Hinweise innerhalb der sicheren Ränder (iPhone-Rundungen)
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toasts.position = Vector2(-300, 80)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(_toasts)
	_open_btn = Button.new()
	_open_btn.icon = texture("freude", 40)
	_open_btn.tooltip_text = "Emotes (Y / Q)"
	_open_btn.focus_mode = Control.FOCUS_NONE
	_open_btn.flat = true
	_open_btn.custom_minimum_size = Vector2(52, 52)
	_open_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_open_btn.position = Vector2(-66, 82)
	_open_btn.pressed.connect(func() -> void: _open(_local_slot(), true))
	safe.add_child(_open_btn)
	_open_btn.visible = false


## Emote-Bild (gecacht)
func texture(id: String, px := 96) -> Texture2D:
	var key := "%s_%d" % [id, px]
	if _tex.has(key):
		return _tex[key]
	var body: String = SVG.get(id, SVG.freude)
	var n := body.count("%s")
	var args: Array = []
	for k in n:
		args.append(SKIN if (k == 0 and id in ["freude", "lachen", "wow", "cool"]) else OUT)
	if id == "daumen":
		args = [OUT, SKIN, OUT, OUT]
	body = body % args
	var img := Image.new()
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>%s</svg>" % body
	if img.load_svg_from_string(svg, px / 64.0) != OK:
		img = Image.create(px, px, false, Image.FORMAT_RGBA8)
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


func _local_slot() -> int:
	if Net.in_game():
		return Net.my_slot
	for i in 4:
		if not Game.players[i].cpu and not bool(Game.players[i].get("remote", false)):
			return i
	return 0


func _process(delta: float) -> void:
	for i in 4:
		_cd[i] = maxf(0.0, _cd[i] - delta)
	# Knopf nur, wo es Sinn ergibt: im Spiel (Brett/Minispiel/Online), nicht über Menüs mit eigener Leiste
	var sc := get_tree().current_scene
	_open_btn.visible = sc != null and (sc is MinigameBase or sc.has_method("_turn")) and _wheel == null
	if _wheel == null:
		for i in 4:
			if Game.players[i].cpu or bool(Game.players[i].get("remote", false)):
				continue
			if Net.in_game() and i != Net.my_slot:
				continue
			if InputHub.pressed(i, "y"):
				_open(i, false)
				break
	elif _wheel_slot >= 0:
		var mv := InputHub.move(_wheel_slot)
		if mv.length() > 0.5:
			var a := fposmod(atan2(mv.y, mv.x) + PI / 2.0, TAU)
			_set_sel(int(round(a / (TAU / IDS.size()))) % IDS.size())
		if not bool(_wheel.get_meta("click", false)) and not InputHub.held(_wheel_slot, "y"):
			var pick := _sel
			_close()
			if pick >= 0:
				send(_wheel_slot, IDS[pick])
		elif bool(_wheel.get_meta("click", false)) and (InputHub.pressed(_wheel_slot, "b") or InputHub.pressed(_wheel_slot, "y")):
			_close()
		elif bool(_wheel.get_meta("click", false)) and InputHub.pressed(_wheel_slot, "a") and _sel >= 0:
			var pk := _sel
			_close()
			send(_wheel_slot, IDS[pk])


func _open(slot: int, click: bool) -> void:
	if _wheel or slot < 0:
		return
	_wheel_slot = slot
	_sel = -1
	_wheel = Control.new()
	_wheel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wheel.mouse_filter = Control.MOUSE_FILTER_STOP if click else Control.MOUSE_FILTER_IGNORE
	_wheel.set_meta("click", click)
	add_child(_wheel)
	var vp := get_viewport().get_visible_rect().size
	var c := vp * 0.5
	var ring := TextureRect.new()
	ring.texture = UI.cozy("panel_wood")
	ring.modulate = Color(1, 1, 1, 0.0)
	_wheel.add_child(ring)
	_wheel_btns.clear()
	for k in IDS.size():
		var a := TAU * k / IDS.size() - PI / 2.0
		var b := TextureButton.new()
		b.texture_normal = texture(IDS[k], 96)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.size = Vector2(84, 84)
		b.pivot_offset = b.size * 0.5
		b.position = c + Vector2(cos(a), sin(a)) * 150.0 - b.size * 0.5
		b.mouse_entered.connect(_set_sel.bind(k))
		var kk := k
		b.pressed.connect(func() -> void:
			var sl := _wheel_slot
			_close()
			send(sl, IDS[kk]))
		_wheel.add_child(b)
		_wheel_btns.append(b)
		var lb := UI.label(String(NAMES[IDS[k]]), 18, Color.WHITE, true, 5)
		lb.position = b.position + Vector2(0, 86)
		lb.size = Vector2(84, 24)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_wheel.add_child(lb)
		b.scale = Vector2.ONE * 0.2
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.18 + k * 0.02).set_trans(Tween.TRANS_BACK)
	Audio.sfx("ui_open", null, -6.0)


func _set_sel(k: int) -> void:
	if k == _sel:
		return
	_sel = k
	for i in _wheel_btns.size():
		_wheel_btns[i].modulate = Color(1, 1, 1, 1.0) if i == k else Color(1, 1, 1, 0.55)
		_wheel_btns[i].create_tween().tween_property(_wheel_btns[i], "scale", Vector2.ONE * (1.25 if i == k else 1.0), 0.1)
	Audio.sfx("ui_move", null, -12.0)


func _close() -> void:
	if _wheel:
		_wheel.queue_free()
	_wheel = null
	_wheel_slot = -1
	_wheel_btns.clear()


## Emote senden (lokal anzeigen + online verteilen)
func send(slot: int, id: String) -> void:
	if slot < 0 or slot > 3 or not id in IDS or _cd[slot] > 0.0:
		return
	_cd[slot] = COOLDOWN
	show_emote(slot, id)
	if Net.in_game():
		Net.send({"k": "emo", "s": slot, "e": id}, true)


func _on_net(_from: String, msg: Dictionary) -> void:
	if String(msg.get("k", "")) == "emo":
		var s := int(msg.get("s", -1))
		var now := Time.get_ticks_msec()
		if s >= 0 and s < 4 and String(msg.get("e", "")) in IDS and now >= _rx_at[s]:
			_rx_at[s] = now + 900
			show_emote(s, String(msg.e))


## Sprechblase über der Figur des Spielers (oder Toast, wenn es gerade keine Figur gibt)
func show_emote(slot: int, id: String) -> void:
	var anchor := _actor_of(slot)
	Audio.sfx("plop", null, -6.0, randf_range(1.1, 1.3))
	if anchor:
		var spr := Sprite3D.new()
		spr.texture = texture(id, 128)
		spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spr.pixel_size = 0.009
		spr.no_depth_test = true
		spr.render_priority = 10
		spr.position = Vector3.UP * 2.6
		anchor.add_child(spr)
		spr.scale = Vector3.ONE * 0.1
		var tw := spr.create_tween()
		tw.tween_property(spr, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
		tw.parallel().tween_property(spr, "position:y", 3.0, 0.25)
		tw.tween_interval(1.4)
		tw.tween_property(spr, "modulate:a", 0.0, 0.3)
		tw.tween_callback(spr.queue_free)
		if anchor.has_method("react") and id in ["freude", "lachen", "herz", "daumen"]:
			anchor.call("react", {"freude": "cheer", "lachen": "laugh", "herz": "wave", "daumen": "flex"}[id])
		return
	var row := UI.hbox(8)
	var ic := TextureRect.new()
	ic.texture = texture(id, 64)
	ic.custom_minimum_size = Vector2(48, 48)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	row.add_child(ic)
	row.add_child(UI.label("%s: %s" % [Game.hero(Game.players[slot].hero).name.split(" ")[0], NAMES[id]], 22, Game.player_color(slot).lightened(0.3), true))
	_toasts.add_child(row)
	var tw2 := row.create_tween()
	tw2.tween_interval(2.0)
	tw2.tween_property(row, "modulate:a", 0.0, 0.3)
	tw2.tween_callback(row.queue_free)


func _actor_of(slot: int) -> Node3D:
	var sc := get_tree().current_scene
	if sc == null:
		return null
	for prop in ["rigs", "actors"]:
		if prop in sc:
			var arr = sc.get(prop)
			if arr is Array and slot < (arr as Array).size() and (arr as Array)[slot] is Node3D and is_instance_valid((arr as Array)[slot]):
				return (arr as Array)[slot]
	return null
