extends Node
## Menü-Agent (UI/UX-Prüfung): bedient das Menü ausschließlich über echte Tastatur- bzw. Controller-Ereignisse
## (Input.parse_input_event) – wie jemand ohne Maus und ohne Touch. Je Seite:
##   * Ankunft: Seite gewechselt, Fokus liegt sichtbar auf einem Element der Seite
##   * Erreichbarkeit: Fokus-Breitensuche mit hoch/runter/links/rechts – jedes Bedienelement muss erreichbar sein
##     (Schieberegler und Wert-Stepper ändern mit links/rechts den Wert; dort nur hoch/runter)
##   * Fallen: Elemente, aus denen keine Richtung herausführt; Fokus außerhalb des sichtbaren Ausschnitts
##   * Text: Beschriftungen, die über den Bildschirm oder ihren Scroll-Ausschnitt hinausragen
##   * Ausgang: Abbrechen (Esc / B) und der „Zurück“-Knopf führen zur erwarteten Seite
## Danach Abläufe Start → Spiel → Pause → „Zum Hauptmenü“ → wieder im Menü (Brett, Rennen, Minispiel, Zufall,
## Marathon, alle Abenteuer-Modi) und ein freies Minispiel bis zum Ende (Ergebnis → Auswahl → zurück).
## Fehlerausgaben der Engine werden über einen eigenen Logger je Seite/Ablauf mitgeschnitten.
##   godot --headless --fixed-fps 60 --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/menu_agent.gd [--pad] [--pages-only]
## Ausgabe: je Seite/Ablauf eine Zeile "MENU {json}", am Ende "MENU-SUMMARY {json}".

const MENU := "res://scenes/menu/MainMenu.tscn"
const DIRS := ["ui_up", "ui_down", "ui_left", "ui_right"]
const KEY_OF := {"ui_up": KEY_UP, "ui_down": KEY_DOWN, "ui_left": KEY_LEFT, "ui_right": KEY_RIGHT,
	"ui_accept": KEY_ENTER, "ui_cancel": KEY_ESCAPE, "start": KEY_ESCAPE, "a": KEY_J}
const PAD_OF := {"ui_up": JOY_BUTTON_DPAD_UP, "ui_down": JOY_BUTTON_DPAD_DOWN, "ui_left": JOY_BUTTON_DPAD_LEFT,
	"ui_right": JOY_BUTTON_DPAD_RIGHT, "ui_accept": JOY_BUTTON_A, "ui_cancel": JOY_BUTTON_B}
## Knöpfe auf Unterseiten, die nur zu einer anderen Menüseite führen (werden mitgeprüft)
const NAV_BUTTONS := {"settings": {"Layout anpassen": "touch_edit"}}
## Wohin Abbrechen/Zurück von einer Seite führen soll
const BACK_TO := {"touch_edit": "settings"}


class ErrLog extends Logger:
	var _m := Mutex.new()
	var _items: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_m.lock()
		_items.append("%s:%d %s %s" % [file.get_file(), line, function, (rationale if rationale != "" else code)])
		_m.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> Array[String]:
		_m.lock()
		var out := _items.duplicate()
		_items.clear()
		_m.unlock()
		return out


var pad := false
var _log := ErrLog.new()
var _paths := {}      # Seite → {Beschriftung: Tastenweg ab Erst-Fokus}
var _home := {}       # Seite → Pfad-Schlüssel des Erst-Fokus (Startpunkt aller Tastenwege)
var _results: Array = []
var _seen_pages := {}


func run() -> void:
	var args := OS.get_cmdline_user_args()
	pad = "--pad" in args
	var tree := get_tree()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_parent().remove_child.call_deferred(self)
	tree.root.add_child.call_deferred(self)
	await tree.process_frame
	await tree.process_frame
	# Headless hat kein Fenster (sichtbarer Bereich sonst 1280×1280): realistische Bildgröße setzen, z. B. 16:9,
	# Smartphone quer (19.5:9) oder Tablet (4:3)
	var size := Vector2i(1280, 720)
	for a in args:
		if String(a).begins_with("--size="):
			var wh := String(a).trim_prefix("--size=").split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
	tree.root.size = size
	await tree.process_frame
	OS.add_logger(_log)
	Router.goto(MENU)
	await _until(func() -> bool: return _menu() != null and not Router.busy, 1200)
	_log.take()
	await _pages()
	if not "--pages-only" in args:
		await _flows()
	_summary()
	OS.remove_logger(_log)
	tree.quit()


# --- Seiten ---------------------------------------------------------------------------------------------

func _pages() -> void:
	if not await _at_page("main"):
		_emit({"kind": "page", "page": "main", "arrive_ok": false, "note": "Hauptseite ohne Fokus"})
		return
	var main_audit := await _audit("main")
	_emit(main_audit)
	# Jeden erreichbaren Knopf der Hauptseite drücken: Wohin führt er? Jede Zielseite einmal ganz prüfen.
	var targets: Array = []
	for label: String in _paths["main"]:
		await _go_main()
		var dest := await _press_path("main", label)
		targets.append([label, dest])
		if dest == "" or dest == "main" or dest.begins_with("?"):
			_emit({"kind": "edge", "from": "main", "button": label, "to": dest, "ok": false, "note": "keine Reaktion" if not dest.begins_with("?") else "Weg nicht nachgehbar"})
			if _menu() == null:
				await _back_to_menu()
			continue
		if _seen_pages.has(dest):
			await _leave_with_cancel(dest)
			continue
		_seen_pages[dest] = true
		var r := await _audit(dest)
		r["via"] = label
		await _check_exits(dest, "main", label, r)
		# Unterseiten-Navigation (z. B. Einstellungen → Touch-Layout)
		for nav_label: String in NAV_BUTTONS.get(dest, {}):
			var sub: String = NAV_BUTTONS[dest][nav_label]
			await _go_main()
			await _press_path("main", label)
			var got := await _press_path(dest, nav_label)
			if got != sub:
				r["sub_" + sub] = "nicht erreicht (%s)" % got
				continue
			_seen_pages[sub] = true
			var rs := await _audit(sub)
			rs["via"] = "%s → %s" % [label, nav_label]
			await _check_exits(sub, dest, "%s|%s" % [label, nav_label], rs)
			_emit(rs)
		_emit(r)
	_emit({"kind": "edges", "from": "main", "edges": targets})


## Prüft Abbrechen und den Zurück-Knopf einer Seite. via = Tastenweg zur Seite (Beschriftungen, mit | getrennt).
func _check_exits(page: String, parent: String, via: String, r: Dictionary) -> void:
	var expect: String = BACK_TO.get(page, "main")
	await _tap("ui_cancel")
	r["esc_to"] = await _settled_page()
	r["esc_ok"] = r["esc_to"] == expect
	r["esc_focus"] = _focus_in_page()
	# Fokus-Gedächtnis: zurück steht man auf dem Eintrag, über den man hineinkam
	var back_on := _desc(get_viewport().gui_get_focus_owner())
	r["return_focus"] = back_on
	r["return_focus_ok"] = back_on == via.split("|")[-1] or (parent == "main" and back_on == via.split("|")[0])
	# Erneut hinein und mit dem Zurück-Knopf (per Fokus angesteuert) heraus
	await _go_main()
	var hops := via.split("|")
	var cur := "main"
	for h in hops:
		cur = await _press_path(cur, h)
	if cur != page:
		r["back_ok"] = false
		r["back_note"] = "Seite nicht wieder erreicht (%s)" % cur
		return
	var back := ""
	for label: String in _paths[page]:
		if label in ["Zurück", "Fertig"]:
			back = label
	if back == "":
		r["back_ok"] = false
		r["back_note"] = "kein Zurück-Knopf per Fokus erreichbar"
		return
	var to := await _press_path(page, back)
	r["back_button"] = back
	r["back_to"] = to
	r["back_ok"] = to == expect
	r["back_focus"] = _focus_in_page()
	if parent != "main" and to == parent:
		pass


## Seite vollständig prüfen: Fokus, Breitensuche, Fallen, Text-Überlauf.
func _audit(page: String) -> Dictionary:
	await _frames(30)   # Einblend-Animation der Seite abwarten
	var root := _page_root()
	var r := {"kind": "page", "page": page, "input": "pad" if pad else "keyboard", "arrive_ok": _page_name() == page}
	var start := get_viewport().gui_get_focus_owner()
	r["focus"] = _desc(start) if start else ""
	r["focus_ok"] = start != null and root != null and root.is_ancestor_of(start)
	if not r["focus_ok"]:
		_paths[page] = {}
		r["errors"] = _log.take()
		return r
	var all := _focusables(root)
	_home[page] = _ipath(start, root)
	var seen := {}           # Pfad-Schlüssel → Tastenweg
	var labels := {}         # Beschriftung → Tastenweg (erste Fundstelle)
	var queue: Array[Control] = [start]
	seen[_ipath(start, root)] = []
	labels[_desc(start)] = []
	var traps: Array = []
	var hidden: Array = []
	var left_page := 0
	while not queue.is_empty():
		var c: Control = queue.pop_front()
		var base: Array = seen[_ipath(c, root)]
		var moved := false
		for d: String in _dirs_for(c):
			c.grab_focus()
			await _frames(1)
			await _tap(d)
			var o := get_viewport().gui_get_focus_owner()
			if o == null or not root.is_ancestor_of(o):
				left_page += 1
				continue
			if o != c:
				moved = true
			var k := _ipath(o, root)
			if not seen.has(k):
				var p := base.duplicate()
				p.append(d)
				seen[k] = p
				queue.append(o)
				if not labels.has(_desc(o)):
					labels[_desc(o)] = p
				await _frames(18)   # Scrollen und Fokus-Puls (Juice.ui_punch) abwarten
				var miss := _hidden_px(o)
				if miss > 2.0:
					hidden.append("%s (%d px)" % [_desc(o), int(miss)])
		if not moved and all.size() > 1:
			traps.append(_desc(c))
	# Nicht erreichte Bedienelemente (je Widget; ein Stepper zählt als erreicht, wenn einer seiner Pfeile erreicht ist)
	var reached_w := {}
	for c in all:
		if seen.has(_ipath(c, root)):
			reached_w[_widget_key(c, root)] = true
	var unreached: Array = []
	var widgets := {}
	for c in all:
		var wk := _widget_key(c, root)
		widgets[wk] = true
		if not reached_w.has(wk) and not unreached.has(_desc(c)):
			unreached.append(_desc(c))
	_paths[page] = labels
	r["controls"] = widgets.size()
	r["reached"] = reached_w.size()
	r["unreached"] = unreached
	r["traps"] = traps
	r["focus_hidden"] = hidden
	r["left_page"] = left_page
	r["overflow"] = _overflow(root)
	r["unnamed"] = _unnamed(all)
	if "--paths" in OS.get_cmdline_user_args():
		r["paths"] = labels
	r["errors"] = _log.take()
	# Fokus zurück auf den Anfang (für die folgenden Wege)
	if is_instance_valid(start):
		start.grab_focus()
	await _frames(2)
	return r


func _dirs_for(c: Control) -> Array:
	if c is Slider or c is LineEdit or c is SpinBox:
		return ["ui_up", "ui_down"]
	var st := _stepper_of(c)
	if st and String(st.get("nav_mode")) == "value":
		return ["ui_up", "ui_down"]
	return DIRS


func _stepper_of(c: Node) -> Node:
	var p := c.get_parent()
	while p:
		if p is Stepper:
			return p
		p = p.get_parent()
	return null


func _widget_key(c: Control, root: Node) -> String:
	var st := _stepper_of(c)
	return _ipath(st, root) if st else _ipath(c, root)


func _focusables(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	for n in root.find_children("*", "Control", true, false):
		var c := n as Control
		if c.focus_mode == Control.FOCUS_NONE or not c.is_visible_in_tree():
			continue
		if not (c is BaseButton or c is Slider or c is LineEdit or c is ItemList or c is TextEdit or c is SpinBox):
			continue
		if c is BaseButton and (c as BaseButton).disabled:
			continue
		out.append(c)
	return out


## Wie weit ragt das (fokussierte) Element aus dem Bild bzw. seinem Scroll-Ausschnitt heraus? 0 = ganz sichtbar.
func _hidden_px(c: Control) -> float:
	var r := c.get_global_rect()
	var areas: Array[Rect2] = [get_viewport().get_visible_rect()]
	var clip := _clip_of(c)
	if clip:
		areas.append(clip.get_global_rect())
	var miss := 0.0
	for a in areas:
		miss = maxf(miss, maxf(maxf(a.position.x - r.position.x, r.end.x - a.end.x), maxf(a.position.y - r.position.y, r.end.y - a.end.y)))
	return miss


func _clip_of(c: Control) -> Control:
	var p := c.get_parent()
	while p:
		if p is Control and (p as Control).clip_contents:
			return p
		p = p.get_parent()
	return null


## Beschriftungen und Knöpfe, deren Text über den Bildschirm oder den Scroll-Ausschnitt hinausragt (in px).
func _overflow(root: Control) -> Array:
	var out: Array = []
	var vp := get_viewport().get_visible_rect()
	for n in root.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree() or c.modulate.a < 0.2:
			continue
		var text := ""
		var x0 := 0.0
		var x1 := 0.0
		var r := c.get_global_rect()
		if c is Label:
			var l := c as Label
			text = l.text
			if text.strip_edges() == "":
				continue
			x0 = r.position.x
			x1 = r.end.x
			var wraps := l.autowrap_mode != TextServer.AUTOWRAP_OFF or l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
			if not wraps:
				var w := 0.0
				for line in text.split("\n"):
					w = maxf(w, l.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x)
				w *= l.get_global_transform().get_scale().x
				match l.horizontal_alignment:
					HORIZONTAL_ALIGNMENT_CENTER:
						x0 = r.get_center().x - w * 0.5
						x1 = r.get_center().x + w * 0.5
					HORIZONTAL_ALIGNMENT_RIGHT:
						x0 = r.end.x - w
					_:
						x1 = r.position.x + w
		elif c is Button:
			text = (c as Button).text
			if text.strip_edges() == "":
				text = "[%s]" % c.tooltip_text
			x0 = r.position.x
			x1 = r.end.x
		else:
			continue
		if c.get_global_transform().get_scale().x > 1.06:
			continue   # gerade animiert vergrößert (Fokus-Puls)
		var over := maxf(vp.position.x - x0, x1 - vp.end.x)
		var clip := _clip_of(c)
		if clip:
			var cr := clip.get_global_rect()
			over = maxf(over, maxf(cr.position.x - x0, x1 - cr.end.x))
		else:
			over = maxf(over, maxf(vp.position.y - r.position.y, r.end.y - vp.end.y))
		if over > 2.0:
			out.append({"text": text.left(48).replace("\n", " "), "px": snappedf(over, 1.0)})
	return out


# --- Navigation -----------------------------------------------------------------------------------------

## Drückt auf der aktuellen Seite den Knopf mit dieser Beschriftung – per Tastenweg ab dem Erst-Fokus und
## Bestätigen. Rückgabe: Name der danach angezeigten Seite ("" = Szenenwechsel/keine Seite).
func _press_path(page: String, label: String) -> String:
	if not _paths.has(page) or not _paths[page].has(label):
		return "?"
	await _frames(20)
	var root := _page_root()
	var home := _node_at(root, String(_home.get(page, "")))
	if home:
		home.grab_focus()   # Tastenwege beginnen am Erst-Fokus der Seite (die Hauptseite merkt sich sonst den letzten Eintrag)
		await _frames(2)
	var path: Array = _paths[page][label]
	var trail: Array = []
	for d: String in path:
		await _tap(d)
		trail.append("%s→%s" % [d.trim_prefix("ui_"), _desc(get_viewport().gui_get_focus_owner())])
	var o := get_viewport().gui_get_focus_owner()
	if o == null or _desc(o) != label:
		if "--trace" in OS.get_cmdline_user_args():
			print("TRACE %s/%s: %s" % [page, label, " | ".join(trail)])
		return "?weg(%s)" % (_desc(o) if o else "kein Fokus")
	var before := _page_root()
	await _tap("ui_accept")
	for i in 90:
		if Router.busy:
			return ""
		if _page_root() != before:
			break
		await _frames(1)
	if root == _page_root():
		return _page_name()
	return await _settled_page()


func _settled_page() -> String:
	await _frames(8)
	await _until(func() -> bool: return get_viewport().gui_get_focus_owner() != null, 60)
	return _page_name()


func _back_to_menu() -> void:
	await _until(func() -> bool: return not Router.busy, 1800)
	Router.goto(MENU)
	await _until(func() -> bool: return not Router.busy and _menu() != null, 1800)


func _go_main() -> void:
	if _menu() == null:
		await _back_to_menu()
	if _page_name() == "main":
		_menu().show_page("main")   # frische Hauptseite (Fokus wieder auf dem ersten Eintrag)
	else:
		for i in 3:
			if _page_name() == "main":
				break
			await _tap("ui_cancel")
			await _frames(6)
	await _at_page("main")
	await _frames(20)


func _leave_with_cancel(_page: String) -> void:
	await _tap("ui_cancel")
	await _frames(10)


func _at_page(page: String) -> bool:
	return await _until(func() -> bool:
		return _page_name() == page and get_viewport().gui_get_focus_owner() != null, 240)


func _menu() -> Node:
	var cs := get_tree().current_scene
	if cs and cs.get_script() and String(cs.get_script().resource_path).ends_with("main_menu.gd"):
		return cs
	return null


func _page_root() -> Control:
	var m := _menu()
	return m.get("_page") as Control if m else null


func _page_name() -> String:
	var p := _page_root()
	return String(p.name) if p else ""


func _focus_in_page() -> bool:
	var o := get_viewport().gui_get_focus_owner()
	var p := _page_root()
	return o != null and p != null and p.is_ancestor_of(o)


func _desc(c: Node) -> String:
	if c == null:
		return ""
	var st := _stepper_of(c)
	if st:
		var arrow := "◀" if c == st.get("_left") else "▶"
		var row := st.get_parent()
		var tag := ""
		if row:
			for s in row.get_children():
				if s is Label and String((s as Label).text) != "":
					tag = (s as Label).text
					break
		return "Stepper %s%s %s" % [tag + " " if tag != "" else "", arrow, String(st.call("value"))]
	if c is Slider:
		var row2 := c.get_parent()
		for s in row2.get_children():
			if s is Label:
				return "Regler " + String((s as Label).text)
		return "Regler"
	if c is Button:
		var b := c as Button
		if b.text.strip_edges() != "":
			return b.text.strip_edges()
		if b.accessibility_name != "":
			return "[%s]" % b.accessibility_name
		if b.tooltip_text != "":
			return "[%s]" % b.tooltip_text
		for l in b.find_children("*", "Label", true, false):
			if String((l as Label).text).strip_edges() != "":
				return "{%s}" % String((l as Label).text).strip_edges()
		return "[Knopf ohne Text]"
	return c.get_class()


## Bedienelemente ohne zugänglichen Namen (kein Text, kein accessibility_name): Bildschirmleser sagen dort nichts.
func _unnamed(all: Array[Control]) -> Array:
	var out: Array = []
	for c in all:
		if c is Button and (c as Button).text.strip_edges() == "" and c.accessibility_name == "":
			out.append(_desc(c))
		elif (c is Slider or c is LineEdit) and c.accessibility_name == "":
			out.append(_desc(c))
	return out


func _node_at(root: Node, key: String) -> Control:
	if root == null or key == "":
		return null
	var cur := root
	for part in key.split("/"):
		var i := int(part)
		if i >= cur.get_child_count():
			return null
		cur = cur.get_child(i)
	return cur as Control


func _ipath(n: Node, root: Node) -> String:
	var parts: PackedStringArray = []
	var cur := n
	while cur and cur != root:
		parts.append(str(cur.get_index()))
		cur = cur.get_parent()
	parts.reverse()
	return "/".join(parts)


# --- Abläufe: Start → Spiel → Pause → Hauptmenü --------------------------------------------------------

func _flows() -> void:
	var mg_first: String = Game.MINIGAMES[0].name
	var flows := [
		["Brettspiel", ["[Lumos Party]", "Party starten!"], "/party/PartyBoard"],
		["Rennen", ["[Nitro Dash]", "Rennen starten!"], "/racer/NitroDash"],
		["Minispiel", ["[Minispiele]", mg_first], String(Game.MINIGAMES[0].scene)],
		["Minispiel Zufall", ["[Minispiele]", "Zufall!"], "/minigames/"],
		["Marathon", ["[Minispiele]", "Marathon (5)"], "/menu/MarathonHub"],
		["Partyhelfer-Reise", ["[Abenteuer & Modi]", "Reise starten"], "/modes/Journey"],
		["Rhythmus-Küche", ["[Abenteuer & Modi]", "Ab in die Küche!"], String(Game.minigame_info("rhythm_kitchen").scene)],
		["Athlon", ["[Abenteuer & Modi]", "Auf die Plätze!"], "/modes/Athlon"],
		["Wolkenturm", ["[Abenteuer & Modi]", "Hinauf in die Wolken!"], "/party/PartyBoard"],
		["Kolosseum", ["[Abenteuer & Modi]", "In die Arena!"], "/modes/Colosseum"],
	]
	for f in flows:
		await _flow_pause(String(f[0]), f[1], String(f[2]))
	await _flow_end("tug_of_war")


## Startet über den Tastenweg, wartet im Spiel, öffnet die Pause und geht über „Zum Hauptmenü“ zurück.
func _flow_pause(title: String, hops: Array, expect: String) -> void:
	var r := {"kind": "flow", "flow": title, "input": "keyboard"}
	var was_pad := pad
	pad = false
	await _go_main()
	var obj0 := Performance.get_monitor(Performance.OBJECT_COUNT)
	var t0 := Time.get_ticks_msec()
	var cur := "main"
	var started := false
	for h: String in hops:
		var label := h
		if label == "Reise starten" and _paths.get(cur, {}).has("Reise fortsetzen"):
			label = "Reise fortsetzen"
		var got := await _press_path(cur, label)
		if got == "":
			started = true
			break
		cur = got
	if not started:
		r["ok"] = false
		r["note"] = "Start nicht erreicht (zuletzt %s)" % cur
		r["errors"] = _log.take()
		_emit(r)
		pad = was_pad
		return
	await _until(func() -> bool: return not Router.busy, 1800)
	r["load_s"] = snappedf((Time.get_ticks_msec() - t0) / 1000.0, 0.01)
	var scene := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	r["scene"] = scene
	r["scene_ok"] = scene.contains(expect.trim_prefix("res://").trim_suffix(".tscn")) if expect != "" else true
	await _frames(240)   # 4 s im Spiel (Intro, erste Züge)
	await _tap("start")
	await _frames(20)
	var pm: PauseMenu = Router.pause_menu
	r["pause_ok"] = pm.open
	r["paused"] = get_tree().paused
	if not pm.open:
		# zweiter Versuch nach dem Intro
		await _frames(300)
		await _tap("start")
		await _frames(20)
		r["pause_ok_late"] = pm.open
	if pm.open:
		var proot: Control = pm.get("_root")
		var path := await _bfs_to(proot, "Zum Hauptmenü")
		r["pause_path"] = path
		if path.is_empty() and _desc(get_viewport().gui_get_focus_owner()) != "Zum Hauptmenü":
			r["quit_ok"] = false
			r["note"] = "„Zum Hauptmenü“ per Fokus nicht erreichbar"
		else:
			await _tap("ui_accept")
			await _frames(6)
			await _tap("ui_accept")   # „Wirklich? Nochmal drücken“
			await _until(func() -> bool: return Router.busy, 60)
			await _until(func() -> bool: return not Router.busy and _menu() != null, 1800)
			await _at_page("main")
			r["quit_ok"] = _menu() != null and _page_name() == "main"
			r["menu_focus"] = _focus_in_page()
			r["paused_after"] = get_tree().paused
			r["time_scale"] = Engine.time_scale
	else:
		# ohne Pause zurück: Szene direkt verlassen, damit die übrigen Abläufe laufen
		Router.goto(MENU)
		await _until(func() -> bool: return not Router.busy and _menu() != null, 1800)
	await _frames(30)
	r["objects_delta"] = int(Performance.get_monitor(Performance.OBJECT_COUNT) - obj0)
	r["orphans"] = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	r["errors"] = _log.take()
	r["ok"] = bool(r.get("scene_ok", false)) and bool(r.get("pause_ok", false) or r.get("pause_ok_late", false)) and bool(r.get("quit_ok", false)) \
		and not bool(r.get("paused_after", false)) and (r["errors"] as Array).is_empty()
	_emit(r)
	pad = was_pad


## Breitensuche im Pausenmenü (oder einer anderen Wurzel) bis zum Knopf mit der Beschriftung; geht den Weg.
func _bfs_to(root: Control, label: String) -> Array:
	var start := get_viewport().gui_get_focus_owner()
	if start == null or not root.is_ancestor_of(start):
		return []
	if _desc(start) == label:
		return []
	var seen := {_ipath(start, root): []}
	var queue: Array[Control] = [start]
	var found: Array = []
	while not queue.is_empty() and found.is_empty():
		var c: Control = queue.pop_front()
		var base: Array = seen[_ipath(c, root)]
		for d: String in _dirs_for(c):
			c.grab_focus()
			await _frames(1)
			await _tap(d)
			var o := get_viewport().gui_get_focus_owner()
			if o == null or not root.is_ancestor_of(o):
				continue
			var k := _ipath(o, root)
			if seen.has(k):
				continue
			var p := base.duplicate()
			p.append(d)
			seen[k] = p
			queue.append(o)
			if _desc(o) == label:
				found = p
				break
	# Weg ab dem Start wirklich gehen (wie ein Spieler)
	start.grab_focus()
	await _frames(2)
	for d: String in found:
		await _tap(d)
	return found


## Freies Minispiel bis zum Ende: Intro mit A bestätigen, spielen lassen, Ergebnis abwarten → Auswahl-Szene.
func _flow_end(game_id: String) -> void:
	var r := {"kind": "flow", "flow": "Minispiel bis zum Ende (%s)" % game_id, "input": "keyboard"}
	pad = false
	await _go_main()
	var name: String = Game.minigame_info(game_id).name
	var cur := await _press_path("main", "[Minispiele]")
	if cur != "minigames" or not _paths.get("minigames", {}).has(name):
		r["ok"] = false
		r["note"] = "Minispiel-Knopf nicht erreichbar"
		_emit(r)
		return
	var got := await _press_path("minigames", name)
	r["started"] = got == ""
	await _until(func() -> bool: return not Router.busy, 1800)
	var t0 := 0
	# A antippen, bis das Spiel läuft (Erklärbildschirm), dann laufen lassen; nach dem Ende A für „weiter“
	var back := false
	for i in 120 * 60:
		if i % 90 == 45:
			await _tap("a")
		else:
			await _frames(1)
		t0 += 1
		if _menu() != null and not Router.busy:
			back = true
			break
	r["frames"] = t0
	r["back_in_menu"] = back
	var scene := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	r["scene"] = scene
	await _at_page("minigames")
	r["page"] = _page_name()
	r["focus"] = _focus_in_page()
	await _tap("ui_cancel")
	r["esc_to"] = await _settled_page()
	r["errors"] = _log.take()
	r["ok"] = back and r["page"] == "minigames" and r["focus"] and r["esc_to"] == "main" and (r["errors"] as Array).is_empty()
	_emit(r)


# --- Eingabe --------------------------------------------------------------------------------------------

func _tap(act: String) -> void:
	var down: InputEvent
	if pad and PAD_OF.has(act):
		var j := InputEventJoypadButton.new()
		j.button_index = PAD_OF[act]
		j.device = 0
		j.pressed = true
		down = j
	else:
		var k := InputEventKey.new()
		k.keycode = KEY_OF[act]
		k.physical_keycode = KEY_OF[act]
		k.pressed = true
		down = k
	Input.parse_input_event(down)
	await _frames(2)
	var up: InputEvent = down.duplicate()
	if up is InputEventKey:
		(up as InputEventKey).pressed = false
	else:
		(up as InputEventJoypadButton).pressed = false
	Input.parse_input_event(up)
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())


# --- Ausgabe --------------------------------------------------------------------------------------------

func _emit(d: Dictionary) -> void:
	_results.append(d)
	print("MENU " + JSON.stringify(d))


func _summary() -> void:
	var pages := 0
	var page_issues: Array = []
	var flows_ok := 0
	var flows: Array = []
	for r: Dictionary in _results:
		if r.get("kind") == "page":
			pages += 1
			var iss: Array = []
			if not r.get("arrive_ok", false) or not r.get("focus_ok", false):
				iss.append("Ankunft/Fokus")
			if not (r.get("unreached", []) as Array).is_empty():
				iss.append("unerreichbar %d" % (r.unreached as Array).size())
			if not (r.get("traps", []) as Array).is_empty():
				iss.append("Fallen %d" % (r.traps as Array).size())
			if not (r.get("focus_hidden", []) as Array).is_empty():
				iss.append("Fokus unsichtbar %d" % (r.focus_hidden as Array).size())
			if not (r.get("overflow", []) as Array).is_empty():
				iss.append("Überlauf %d" % (r.overflow as Array).size())
			if r.page != "main" and not r.get("esc_ok", false):
				iss.append("Abbrechen")
			if r.page != "main" and not r.get("back_ok", false):
				iss.append("Zurück-Knopf")
			if not (r.get("errors", []) as Array).is_empty():
				iss.append("Fehler %d" % (r.errors as Array).size())
			if not iss.is_empty():
				page_issues.append("%s: %s" % [r.page, ", ".join(iss)])
		elif r.get("kind") == "flow":
			flows.append(r.flow)
			if r.get("ok", false):
				flows_ok += 1
	print("MENU-SUMMARY " + JSON.stringify({"input": "pad" if pad else "keyboard", "view": get_viewport().get_visible_rect().size, "pages": pages, "page_issues": page_issues,
		"flows": flows.size(), "flows_ok": flows_ok}))
