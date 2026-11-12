extends Node3D
## Trailer „Lumos Party – Best adventures are shared.“ (≈ 94 s, komplett in der Engine)
##
## Fünf Akte ohne Dialog: Ein kleiner Stern · Eine Welt voller Wunder · Gemeinsam unterwegs · Das Abenteuer
## eskaliert · Wieder zusammen. Alles ist eine zeitgenaue Regie (Zeitleiste in Sekunden), dadurch bildgenau
## wiederholbar – im Spiel ansehbar und als Video renderbar (Movie Maker):
##   godot --path . --write-movie trailer.avi --fixed-fps 30 --resolution 1920x1080 res://scenes/trailer/Trailer.tscn
## Vorschau ab Sekunde X: … -- --trailer-from=42
##
## Animationsregie (Figuren bleiben Low-Poly, bewegen sich aber filmisch):
##  * Bewegung über Segmente mit weichem Anfahren/Abbremsen (Smootherstep) – Gehen/Laufen folgt der echten
##    Geschwindigkeit (Fußkontakt), die Figur neigt sich beim Beschleunigen nach vorn und beim Bremsen zurück.
##  * Blick: Kopf folgt einem Aufmerksamkeitsziel (Stern, Glühwürmchen, Freund), unabhängig vom Körper.
##  * Antizipation → Aktion → Nachschwingen bei Sprüngen, Stolpern, Zusammenstößen (Squash & Stretch, Taumeln).
##  * Weltenwechsel sind verdeckt (Baumstamm, Wasserwand, Sternenblitz) oder fließend (Bodenwechsel).

const DUR := 95.5
const BEAT := 60.0 / 138.0   # Hurry-Up-Track der Montage
const WIPE_T := 52.0       # Weltenwechsel hinter dem Stamm (Wald → Wiese)
const MONTAGE_T0 := 65.4   # BOOM – Montage im 4-Schläge-Raster (1,74 s je Bild)

var t := 0.0
var _from := 0.0
var cam: Camera3D
var heroes: Array[CharacterRig] = []      # 0 Ritter (Held) · 1 Magierin (winkt) · 2 Barbar (keucht hinterher) · 3 Waldläufer (Träumer)
var _ev: Array = []                       # [Zeit, Callable] – einmalige Ereignisse
var _segs: Array = [[], [], [], []]       # je Figur: [t0, t1, von, nach, Bogenhöhe]
var _look: Array = [null, null, null, null]
var _face_hint: Array = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _prev_pos: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _prev_v: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _acc_s: Array[float] = [0.0, 0.0, 0.0, 0.0]          # geglättete Beschleunigung (Gewichtsverlagerung)
var _last_v: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _marks: Array = []
var _cam_tan: Array = []
var _trunk: MeshInstance3D
var _trunk_local := Vector3.ZERO   # Schnitt-/Übergangsliste für die Video-Prüfung (trailer/qa.py)
var _hold: Array[bool] = [false, false, false, false]   # eigene Pose (Sitzen, Liegen) – kein Gehen/Stehen
var _cam_keys: Array = []                 # [t, Position, Blickpunkt, FOV]
var _sets := {}
var _envs := {}
var _origin := Vector3.ZERO
var _set_now := ""
var _ui: CanvasLayer
var _flash: ColorRect
var _black: ColorRect
var _water: ColorRect
var _bars: Array[ColorRect] = []
var _title: Label
var _slogan: Label
var _slogan2: Label
var _cta: Label
var _bigword: Label
var _music: Array[AudioStreamPlayer] = []
var _star: Node3D
var _star_light: OmniLight3D
var _firefly: Node3D
var _butterfly: Node3D
var _boss: BossModel
var _karts: Array[KartVisual] = []
var _fire_light: OmniLight3D
var _snack: Node3D
var _rng := RandomNumberGenerator.new()
var _movie := false
var _msaa := 2   # Viewport.MSAA_4X
var _shadow := 4096


func _ready() -> void:
	_rng.seed = 20261112
	_movie = OS.has_feature("movie") or "--write-movie" in OS.get_cmdline_args()
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--trailer-from="):
			_from = String(a).substr(15).to_float()
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--trailer-msaa="):
			_msaa = clampi(String(a).substr(15).to_int(), 0, 3)
		if String(a).begins_with("--trailer-shadow="):
			_shadow = clampi(String(a).substr(17).to_int(), 1024, 16384)
	Engine.time_scale = 1.0
	InputHub.set_touch_profile("none")
	_lock_render_quality.call_deferred()
	_build_ui()
	_build_sets()
	_build_cast()
	_build_music()
	_script_all()
	at(0.25, _unlimit_ranges)   # nachdem die Spiel-Grafik die ersten Meshes eingestellt hat
	_ev.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	_cam_keys.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	_prepare_camera()
	# Vordergrund-Stamm für den verdeckten Weltenwechsel genau dorthin, wo die Kamera im Wechselmoment steht
	var cw: Vector3 = _cam_eval(WIPE_T)[0]
	_trunk_local = Vector3(cw.x, 8.0, cw.z - 2.2)
	_use_set("forest")
	_sets.forest.visible = false   # Akt 1 beginnt in völliger Dunkelheit
	_use_env("void")
	if _from > 0.0:
		t = _from
		for e in _ev:
			if float(e[0]) <= _from:
				(e[1] as Callable).call()
		_ev = _ev.filter(func(e: Array) -> bool: return float(e[0]) > _from)
		for m in _music:
			if m.playing:
				m.seek(m.get_playback_position() + _from)


## Eigene Renderqualität der Produktion, unabhängig von der Grafik-Automatik des Spiels: Die misst im Movie-Maker
## die echte (sehr niedrige) Bildrate und würde Auflösung und Stufe senken; bei 4K deckelt sie die 3D-Auflösung.
## Alles nur im Speicher dieses Prozesses – es wird nichts gespeichert, das Spiel bleibt unberührt.
func _lock_render_quality() -> void:
	Game.settings["quality"] = "ultra"
	Game.settings["dynamic_res"] = false
	Game.settings["show_fps"] = false
	Gfx.apply()
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = 1.0
	vp.msaa_3d = _msaa as Viewport.MSAA
	RenderingServer.directional_shadow_atlas_set_size(_shadow, true)
	_unlimit_ranges.call_deferred()
	print("[TRAILER] Fenster %s · Bildschirm %s · 3D-Skalierung %.2f · MSAA-Stufe %d" % [str(get_window().size),
		str(DisplayServer.screen_get_size()), vp.scaling_3d_scale, int(vp.msaa_3d)])


## Keine Sichtweiten-Abschaltung im Bild (die Spiel-Grafik setzt sie für kleine Teile – in weiten Kamerafahrten
## würden sie sonst aufploppen).
func _unlimit_ranges() -> void:
	for n in find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		g.visibility_range_end = 0.0
		g.visibility_range_begin = 0.0


func _process(delta: float) -> void:
	t += delta
	if _trunk.visible:
		_trunk.global_position = _origin + _trunk_local
	var vp := get_viewport()
	if vp.scaling_3d_scale != 1.0:
		vp.scaling_3d_scale = 1.0
	while not _ev.is_empty() and float(_ev[0][0]) <= t:
		var e: Array = _ev.pop_front()
		(e[1] as Callable).call()
	for i in heroes.size():
		_drive(i, delta)
	_drive_camera()
	_drive_music()
	_animate_props(delta)
	if t >= DUR:
		set_process(false)
		_write_marks()
		get_tree().quit()   # eigenständige Produktion: nach dem Abspann ist Schluss


func _write_marks() -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--trailer-marks="):
			var f := FileAccess.open(String(a).substr(16), FileAccess.WRITE)
			if f:
				f.store_string(JSON.stringify({"duration": DUR, "marks": _marks}))


func _exit_tree() -> void:
	# Musik sauber anhalten (laufende Wiedergaben hielten ihre Streams sonst über das Szenenende hinaus fest)
	for m in _music:
		m.stop()
		m.stream = null
	# Umgebungen, die gerade nicht im Baum hängen, gehören niemandem – selbst freigeben
	for h in _envs.values():
		if is_instance_valid(h) and (h as Node).get_parent() == null:
			(h as Node).free()


func _unhandled_input(event: InputEvent) -> void:
	# Vorschau im Fenster: Esc beendet
	if not _movie and event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_tree().quit()


# =============================================================================================================
# Regie-Werkzeuge
# =============================================================================================================

func at(time: float, f: Callable) -> void:
	_ev.append([time, f])


## Figur i geht/läuft von a nach b (Set-Koordinaten) zwischen t0 und t1; hop > 0 = Sprung-Bogen.
func go(i: int, t0: float, t1: float, a: Vector3, b: Vector3, hop := 0.0) -> void:
	(_segs[i] as Array).append([t0, t1, a, b, hop])


func look(i: int, time: float, target: Variant) -> void:
	at(time, func() -> void: _look[i] = target)


func face(i: int, time: float, dir: Vector3) -> void:
	at(time, func() -> void: _face_hint[i] = dir)


func clip(i: int, time: float, name: String, blend := 0.2, speed := 1.0) -> void:
	at(time, func() -> void:
		heroes[i].play(name, blend, speed, true)
		heroes[i].lock(heroes[i].clip_length(name) / maxf(speed, 0.1) if heroes[i].has_clip(name) else 0.6))


func pose(i: int, time: float, name: String, on := true) -> void:
	at(time, func() -> void:
		_hold[i] = on
		if on:
			heroes[i].play(name, 0.35))


func react(i: int, time: float, id: String) -> void:
	at(time, func() -> void: heroes[i].react(id))


## Kamera-Schlüsselbild (Set-Koordinaten). cut = harter Schnitt (kein Übergang vom vorigen Schlüssel).
func key(time: float, pos: Vector3, lk: Vector3, fov := 50.0, cut := false) -> void:
	_cam_keys.append([time, pos, lk, fov, cut])
	if cut:
		_marks.append([time, "Schnitt"])


## Gewollter Bildwechsel (Blitz, Wasserwand, Weltenwechsel) – die Video-Prüfung erwartet dort einen Sprung.
func _mark(kind: String) -> void:
	_marks.append([t, kind])


func _pos_of(i: int, time: float) -> Vector3:
	var segs: Array = _segs[i]
	var last := Vector3.INF
	for s in segs:
		var t0: float = s[0]
		var t1: float = s[1]
		if time < t0:
			break
		if time <= t1:
			var u := (time - t0) / maxf(t1 - t0, 0.001)
			var e := u * u * u * (u * (u * 6.0 - 15.0) + 10.0)   # Smootherstep: weich an- und abfahren
			var p: Vector3 = (s[2] as Vector3).lerp(s[3], e)
			var hop: float = s[4]
			if hop > 0.0:
				p.y += hop * 4.0 * u * (1.0 - u)
			return p
		last = s[3]
	return last


func _drive(i: int, delta: float) -> void:
	var r := heroes[i]
	var lp := _pos_of(i, t)
	if lp == Vector3.INF:
		return
	var p := _origin + lp
	var v := (p - _prev_pos[i]) / maxf(delta, 0.001)
	if (p - _prev_pos[i]).length() > 6.0:
		v = _last_v[i]   # Weltenwechsel / Szenensprung: Bewegung läuft einfach weiter (kein Zucken)
	_last_v[i] = v
	_prev_pos[i] = p
	r.global_position = p
	var flat := Vector3(v.x, 0, v.z)
	var spd := flat.length()
	# Gewicht: beim Beschleunigen nach vorn, beim Bremsen zurück lehnen
	# (bildratenunabhängig: bei 30 und 60 fps dieselbe Haltung)
	var acc_raw := (spd - _prev_v[i]) / maxf(delta, 0.001)
	_prev_v[i] = spd
	_acc_s[i] = lerpf(_acc_s[i], acc_raw, 1.0 - exp(-delta / 0.07))
	r.set_lean(clampf(_acc_s[i] * 0.05 + spd * 0.025, -0.35, 0.45))
	if spd > 0.25:
		r.face(flat, delta, 7.0)
	elif _face_hint[i] != Vector3.ZERO:
		r.face(_face_hint[i], delta, 4.0)
	if not _hold[i]:
		r.locomote(spd, 6.5, absf(v.y) < 2.5 or lp.y < 0.05, v.y, delta)
	var lk = _look[i]
	if lk is Vector3:
		r.look_at_point(_origin + (lk as Vector3), 1.0)
	elif lk is Node3D and is_instance_valid(lk):
		r.look_at_point((lk as Node3D).global_position + Vector3.UP * 0.2, 1.0)
	elif lk is int:
		r.look_at_point(heroes[int(lk)].global_position + Vector3.UP * 1.6, 1.0)
	else:
		r.clear_look()


func _drive_camera() -> void:
	if _cam_keys.is_empty():
		return
	var c := _cam_eval(t)
	cam.global_position = _origin + (c[0] as Vector3)
	cam.fov = float(c[2])
	var target := _origin + (c[1] as Vector3)
	if not cam.global_position.is_equal_approx(target):
		cam.look_at(target, Vector3.UP)


## Kamerafahrt als monotone kubische Spline je Einstellung (Fritsch-Carlson je Kanal): Innerhalb einer Einstellung
## fährt die Kamera ohne Halt durch alle Zwischenpunkte, beschleunigt nur am Anfang und bremst nur am Ende – ohne
## Überschwingen (wo eine Achse ruht oder umkehrt, ist auch die Tangente null).
func _prepare_camera() -> void:
	_cam_tan.clear()
	var n := _cam_keys.size()
	for k in n:
		var start := k == 0 or bool(_cam_keys[k][4])
		var stop := k == n - 1 or bool(_cam_keys[k + 1][4])
		var tan: Array[float] = []
		var v := _cam_vec(k)
		for ch in v.size():
			var m := 0.0
			if not start and not stop:
				var vp := _cam_vec(k - 1)
				var vn := _cam_vec(k + 1)
				var d0 := (v[ch] - vp[ch]) / maxf(float(_cam_keys[k][0]) - float(_cam_keys[k - 1][0]), 0.001)
				var d1 := (vn[ch] - v[ch]) / maxf(float(_cam_keys[k + 1][0]) - float(_cam_keys[k][0]), 0.001)
				if d0 * d1 > 0.0:
					m = clampf((d0 + d1) * 0.5, -3.0 * minf(absf(d0), absf(d1)), 3.0 * minf(absf(d0), absf(d1)))
			tan.append(m)
		_cam_tan.append(tan)


func _cam_vec(k: int) -> Array[float]:
	var p: Vector3 = _cam_keys[k][1]
	var l: Vector3 = _cam_keys[k][2]
	return [p.x, p.y, p.z, l.x, l.y, l.z, float(_cam_keys[k][3])]


## Kamera (Position, Blickpunkt, Brennweite) zur Zeit tt, in Set-Koordinaten.
func _cam_eval(tt: float) -> Array:
	var i0 := 0
	for k in _cam_keys.size():
		if float(_cam_keys[k][0]) <= tt:
			i0 = k
		else:
			break
	var v0 := _cam_vec(i0)
	var out := v0.duplicate()
	if i0 + 1 < _cam_keys.size() and not bool(_cam_keys[i0 + 1][4]) and tt > float(_cam_keys[i0][0]):
		var t0 := float(_cam_keys[i0][0])
		var dt := maxf(float(_cam_keys[i0 + 1][0]) - t0, 0.001)
		var u := clampf((tt - t0) / dt, 0.0, 1.0)
		var u2 := u * u
		var u3 := u2 * u
		var v1 := _cam_vec(i0 + 1)
		var m0: Array[float] = _cam_tan[i0]
		var m1: Array[float] = _cam_tan[i0 + 1]
		for ch in out.size():
			out[ch] = (2 * u3 - 3 * u2 + 1) * v0[ch] + (u3 - 2 * u2 + u) * dt * m0[ch] + (-2 * u3 + 3 * u2) * v1[ch] + (u3 - u2) * dt * m1[ch]
	return [Vector3(out[0], out[1], out[2]), Vector3(out[3], out[4], out[5]), out[6]]


# =============================================================================================================
# Aufbau
# =============================================================================================================

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 40
	add_child(_ui)
	var root := UI.center_root(_ui)
	_black = _rect(root, Color.BLACK, 1.0)
	_flash = _rect(root, Color(1, 0.97, 0.85), 0.0)
	_water = _rect(root, Color(0.55, 0.8, 1.0), 0.0)
	for top in [true, false]:
		var b := ColorRect.new()
		b.color = Color.BLACK
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.anchor_right = 1.0
		if top:
			b.anchor_bottom = 0.0
			b.offset_bottom = 0.0
		else:
			b.anchor_top = 1.0
			b.anchor_bottom = 1.0
			b.offset_top = 0.0
		root.add_child(b)
		_bars.append(b)
	_title = _label(root, "LUMOS PARTY", 150, Color.WHITE, 26, 0.40)
	_title.add_theme_color_override("font_outline_color", Color("#5a1aa0"))
	_slogan = _label(root, "Best adventures are shared.", 54, UI.GOLD, 12, 0.56)
	_slogan2 = _label(root, "A little adventure. A lot of memories.", 34, Color(1, 1, 1, 0.92), 8, 0.635)
	_cta = _label(root, "Lumos One  ·  Browser & PWA  ·  Lokal & Online mit bis zu 4 Freunden", 26, Color(1, 1, 1, 0.8), 6, 0.84)
	_bigword = _label(root, "", 170, UI.GOLD, 28, 0.42)
	for l in [_title, _slogan, _slogan2, _cta, _bigword]:
		l.modulate.a = 0.0


func _rect(root: Control, c: Color, a: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.modulate.a = a
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(r)
	return r


func _label(root: Control, text: String, size: int, col: Color, outline: int, y: float) -> Label:
	var l := UI.label(text, size, col, true, outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = y
	l.anchor_bottom = y
	l.offset_top = -size
	l.offset_bottom = size
	l.pivot_offset = Vector2(960, size)
	root.add_child(l)
	return l


## Kinobalken (Anteil der Bildhöhe je Balken)
func _letterbox(frac: float, dur := 0.8) -> void:
	for k in 2:
		var b := _bars[k]
		var h := get_viewport().get_visible_rect().size.y * frac
		var tw := create_tween()
		if k == 0:
			tw.tween_property(b, "offset_bottom", h, dur).set_trans(Tween.TRANS_SINE)
		else:
			tw.tween_property(b, "offset_top", -h, dur).set_trans(Tween.TRANS_SINE)


func _fade(r: CanvasItem, to: float, dur: float) -> void:
	create_tween().tween_property(r, "modulate:a", to, dur).set_trans(Tween.TRANS_SINE)


func _build_sets() -> void:
	# Umgebungen (immer nur eine im Baum)
	for preset in ["forest_night", "day", "snow", "sunset", "volcano"]:
		var holder := Node3D.new()
		var we := WorldKit.env(holder, preset, true)
		_envs[preset] = holder
		we.set_meta("holder", true)
	var void_holder := Node3D.new()
	var we_v := WorldKit.env(void_holder, "night", true)
	we_v.environment.background_mode = Environment.BG_COLOR
	we_v.environment.background_color = Color.BLACK
	we_v.environment.ambient_light_color = Color(0.05, 0.05, 0.1)
	we_v.environment.ambient_light_energy = 0.15
	we_v.environment.fog_enabled = false
	(we_v.get_meta("sun") as DirectionalLight3D).light_energy = 0.0
	_envs["void"] = void_holder
	cam = Camera3D.new()
	cam.far = 260.0
	add_child(cam)
	cam.make_current()
	_trunk = MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 1.35
	tm.bottom_radius = 1.6
	tm.height = 16.0
	tm.radial_segments = 28
	tm.set_meta("gfx_tuned", true)   # Spiel-Grafik soll die Rundung nicht reduzieren (Silhouette ganz nah)
	var bark := StandardMaterial3D.new()
	bark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # in beiden Welten gleich dunkel – kein Lichtsprung
	bark.albedo_color = Color("#20140d")
	bark.disable_fog = true
	tm.material = bark
	_trunk.mesh = tm
	_trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trunk.visible = false
	add_child(_trunk)
	_sets["forest"] = _build_forest(Vector3(0, 0, 0))
	_sets["meadow"] = _build_meadow(Vector3(0, 0, 600))
	_sets["snow"] = _build_snow(Vector3(0, 0, 1200))
	_sets["beach"] = _build_beach(Vector3(0, 0, 1800))
	_sets["montage"] = _build_montage(Vector3(0, 0, 2600))
	for s in _sets.values():
		(s as Node3D).visible = false


func _use_env(name: String) -> void:
	for k in _envs:
		var h: Node3D = _envs[k]
		if k == name:
			if h.get_parent() == null:
				add_child(h)
		elif h.get_parent() != null:
			remove_child(h)


func _use_set(name: String, env := "") -> void:
	var to: Node3D = _sets[name]
	for k in _sets:
		(_sets[k] as Node3D).visible = (k == name)
	_origin = to.position
	_set_now = name
	_mark("Welt " + name)
	if env != "":
		_use_env(env)
	_unlimit_ranges.call_deferred()


## Langer Weg entlang +X (Set-Koordinaten), Boden + Pfad + Kulisse zu beiden Seiten (vorn nur Niedriges).
func _strip(s: Node3D, ground: Color, path_col: Color, x0: float, x1: float) -> void:
	WorldKit.box(s, Vector3(x1 - x0 + 80, 1, 120), Vector3((x0 + x1) * 0.5, -0.5, -20), ground, false)
	var path := WorldKit.box(s, Vector3(x1 - x0, 0.04, 3.2), Vector3((x0 + x1) * 0.5, 0.01, 0), path_col, false)
	path.name = "Path"


func _scatter(s: Node3D, keys: Array, n: int, x0: float, x1: float, z0: float, z1: float, scl := Vector2(1.0, 1.4)) -> void:
	for k in n:
		var p := Vector3(_rng.randf_range(x0, x1), 0, _rng.randf_range(z0, z1))
		if absf(p.z) < 2.4:
			continue   # Weg freihalten
		var key_i := _rng.randi() % keys.size()
		var rot := _rng.randf() * 360.0
		var sc := _rng.randf_range(scl.x, scl.y)
		if p.z > 5.0:
			continue   # Kameraseite: nichts, was dicht vor der Linse durchs Bild wischt
		if s.name == "Forest" and p.x > -17.0 and p.x < 7.0 and p.z > -27.5 and p.z < -8.0:
			continue   # Lagerfeuer-Lichtung samt Kamerablick (Akt 5) frei
		WorldKit.place(s, keys[key_i], p, rot, sc)


func _glow_mushroom(s: Node3D, p: Vector3, col: Color) -> void:
	var m := Assets.spawn("plat/mushrooms", s, p, _rng.randf() * 360.0, 1.4)
	Assets.tint(m, col.lightened(0.25))
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 0.9
	l.omni_range = 4.0
	l.position = p + Vector3.UP * 1.0
	s.add_child(l)


func _fireflies(s: Node3D, center: Vector3, box: Vector3, amount := 120) -> void:
	var ff := FX.emitter({"amount": amount, "life": 5.0, "one_shot": false, "explosive": 0.0, "spread": 180.0, "vel_min": 0.1, "vel_max": 0.45,
		"gravity": Vector3(0, 0.04, 0), "size": 0.2, "additive": true, "color": Color(1.0, 0.95, 0.55, 0.95), "box": box})
	s.add_child(ff)
	ff.position = center
	ff.emitting = true
	ff.preprocess = 4.0


func _build_forest(o: Vector3) -> Node3D:
	var s := Node3D.new()
	s.name = "Forest"
	add_child(s)
	s.position = o
	Assets.season = "moss"
	_strip(s, Color("#2f5a35"), Color("#5a4a36"), -20, 75)
	_scatter(s, ["nat/tree_oak", "nat/tree_fat", "nat/tree_pine", "nat/tree_default", "plat/tree"], 70, -30, 85, -40, -7, Vector2(2.6, 4.2))
	_scatter(s, ["nat/bush", "nat/flower_purple", "nat/mushroom", "nat/rock_small", "nat/stump"], 70, -20, 75, -9, 9, Vector2(1.2, 1.8))
	for k in 18:
		var x := -12.0 + k * 5.0
		_glow_mushroom(s, Vector3(x, 0, -3.6 - (k % 3) * 1.2), [Color("#d9a8ff"), Color("#8fe8ff"), Color("#ffb3e6")][k % 3])
	_fireflies(s, Vector3(25, 2.0, -3), Vector3(60, 2.5, 10))
	# Wasserfall am Weg (Akt 2) mit Felsen, Gischt und Nebel
	var wf := WorldKit.water(s, Vector2(4.5, 10.0), 0.0, Color(0.42, 0.7, 0.95), Color(0.92, 0.98, 1.0))
	wf.rotation_degrees = Vector3(90, 0, 0)
	wf.position = Vector3(16.0, 5.0, -8.5)
	for p in [Vector3(13.2, 0, -8.6), Vector3(18.8, 0, -8.4), Vector3(16, 9.6, -8.8)]:
		WorldKit.place(s, "nat/rock_large", p, _rng.randf() * 360.0, 2.6)
	WorldKit.water(s, Vector2(7.0, 3.5), 0.05, Color(0.1, 0.35, 0.55), Color(0.55, 0.85, 1.0)).position = Vector3(16.0, 0.05, -6.2)
	var spray := FX.emitter({"amount": 60, "life": 1.4, "one_shot": false, "explosive": 0.0, "spread": 50.0, "dir": Vector3.UP, "vel_min": 0.8,
		"vel_max": 2.0, "gravity": Vector3(0, -2.5, 0), "size": 0.3, "color": Color(1, 1, 1, 0.5), "box": Vector3(4.0, 0.2, 0.6)})
	s.add_child(spray)
	spray.position = Vector3(16.0, 0.3, -7.6)
	spray.emitting = true
	# Hügel, auf dem die Magierin wartet; Stein, auf dem der Träumer sitzt; Lagerfeuer-Lichtung (Akt 5)
	WorldKit.cylinder(s, 3.0, 0.5, Vector3(31.0, 0.0, -1.6), Color("#3a6a3e"), false)
	WorldKit.place(s, "nat/rock_large", Vector3(46.0, 0, -2.6), 20.0, 1.1)
	WorldKit.place(s, "nat/flower_red", Vector3(47.0, 0, -2.0), 0.0, 1.6)
	WorldKit.place(s, "nat/campfire", Vector3(-6.0, 0, -18.0), 0.0, 1.6)
	for e in [[Vector3(-8.35, 0, -18.7), 69.0], [Vector3(-4.0, 0, -19.0), -63.0], [Vector3(-6.4, 0, -22.0), 0.0]]:
		WorldKit.place(s, "nat/log", e[0], e[1], 1.3)
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.6, 0.28)
	_fire_light.light_energy = 3.0
	_fire_light.omni_range = 9.0
	_fire_light.position = Vector3(-6.0, 1.2, -18.0)
	s.add_child(_fire_light)
	var fire := FX.emitter({"amount": 40, "life": 0.9, "one_shot": false, "explosive": 0.0, "spread": 18.0, "dir": Vector3.UP, "vel_min": 0.8,
		"vel_max": 1.8, "gravity": Vector3(0, 0.8, 0), "size": 0.42, "additive": true, "color": Color(1.0, 0.55, 0.18, 0.95), "box": Vector3(0.7, 0.1, 0.7)})
	s.add_child(fire)
	fire.position = Vector3(-6.0, 0.3, -18.0)
	fire.emitting = true
	_scatter(s, ["nat/tree_oak", "nat/tree_fat", "nat/tree_pine"], 26, -30, 18, -34, -23, Vector2(2.8, 4.0))
	_fireflies(s, Vector3(-6, 2.6, -21), Vector3(18, 3, 8), 35)
	# Stern für den Weg (wird von Akt 1 benutzt, Ursprung)
	_star = Assets.spawn("kp/star", self, o + Vector3(1.2, 1.55, 0), 0.0, 0.0)
	_star.visible = false
	var sm := WorldKit.mat(Color("#ffd23f"), 0.3, 2.4)
	for mi in Assets.find_meshes(_star):
		mi.material_override = sm
	_star_light = OmniLight3D.new()
	_star_light.light_color = Color(1.0, 0.85, 0.4)
	_star_light.light_energy = 0.0
	_star_light.omni_range = 7.0
	_star.add_child(_star_light)
	Assets.season = ""
	return s


func _build_meadow(o: Vector3) -> Node3D:
	var s := Node3D.new()
	s.name = "Meadow"
	add_child(s)
	s.position = o
	_strip(s, Color("#6fbf55"), Color("#d8c48a"), 40, 90)
	_scatter(s, ["nat/tree_oak", "nat/tree_default", "plat/tree", "nat/tree_fat"], 30, 30, 100, -40, -8, Vector2(2.4, 3.6))
	_scatter(s, ["nat/flower_yellow", "nat/flower_purple", "nat/flower_red", "nat/bush"], 110, 40, 90, -9, 8, Vector2(1.2, 2.0))
	# Riesenblume, vor der die Magierin staunend stehen bleibt
	var flower := WorldKit.place(s, "nat/flower_purple", Vector3(63.0, 0, -2.8), 0.0, 10.0)
	flower.name = "GiantFlower"
	var bf := FX.emitter({"amount": 18, "life": 4.0, "one_shot": false, "explosive": 0.0, "spread": 180.0, "vel_min": 0.2, "vel_max": 0.6,
		"gravity": Vector3.ZERO, "size": 0.25, "color": Color(1.0, 0.7, 0.9, 0.95), "box": Vector3(5, 2, 3)})
	s.add_child(bf)
	bf.position = Vector3(63.0, 1.8, -2.8)
	bf.emitting = true
	# Wasserwand für den nächsten Wechsel (zwischen Kamera und Weg, fällt von oben)
	var curtain := WorldKit.water(s, Vector2(7.0, 14.0), 0.0, Color(0.25, 0.55, 0.85), Color(0.8, 0.95, 1.0))
	curtain.rotation_degrees = Vector3(90, 0, 0)
	curtain.position = Vector3(69.0, 7.0, 5.2)
	curtain.name = "Curtain"
	return s


func _build_snow(o: Vector3) -> Node3D:
	var s := Node3D.new()
	s.name = "Snow"
	add_child(s)
	s.position = o
	Assets.season = "snow"
	_strip(s, Color("#eef6ff"), Color("#c9dcef"), 55, 100)
	_scatter(s, ["nat/tree_pine", "nat/tree_default", "nat/tree_pine"], 40, 45, 110, -40, -7, Vector2(2.4, 3.8))
	_scatter(s, ["hol/snowball_pile", "nat/rock_small", "nat/bush"], 30, 55, 100, -9, 8, Vector2(0.8, 1.2))
	WorldKit.place(s, "hol/snowman_a", Vector3(66.0, 0, -4.5), -20.0, 0.9)
	var snowfall := FX.emitter({"amount": 260, "life": 6.0, "one_shot": false, "explosive": 0.0, "spread": 10.0, "dir": Vector3.DOWN, "vel_min": 0.6,
		"vel_max": 1.2, "gravity": Vector3(0, -0.3, 0), "size": 0.12, "color": Color(1, 1, 1, 0.9), "box": Vector3(40, 1, 18)})
	s.add_child(snowfall)
	snowfall.position = Vector3(72, 9, 0)
	snowfall.emitting = true
	snowfall.preprocess = 6.0
	# schwebender Stern, den der Träumer berührt
	var st := Assets.spawn("kp/star", s, Vector3(73.6, 1.7, -1.4), 0.0, 0.55)
	st.name = "TouchStar"
	var sm := WorldKit.mat(Color("#ffd23f"), 0.3, 2.4)
	for mi in Assets.find_meshes(st):
		mi.material_override = sm
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.85, 0.4)
	l.light_energy = 1.4
	l.omni_range = 5.0
	st.add_child(l)
	Assets.season = ""
	return s


func _build_beach(o: Vector3) -> Node3D:
	var s := Node3D.new()
	s.name = "Beach"
	add_child(s)
	s.position = o
	# Boden geht vom Sand allmählich in dunkles Vulkangestein über (Landschaftswechsel ohne Schnitt)
	WorldKit.box(s, Vector3(160, 1, 120), Vector3(80, -0.5, -20), Color("#e9cf96"), false)
	for k in 28:
		var x := 66.0 + k * 1.2
		var u := clampf((x - 74.0) / 12.0, 0.0, 1.0)
		var col := Color("#e9cf96").lerp(Color("#3a2f33"), u)
		WorldKit.box(s, Vector3(1.25, 0.06, 26.0), Vector3(x, 0.02, -3.0), col, false)
	WorldKit.box(s, Vector3(70, 0.06, 26.0), Vector3(134.0, 0.02, -3.0), Color("#3a2f33"), false)
	WorldKit.water(s, Vector2(160, 70), -0.25, Color(0.08, 0.38, 0.6), Color(0.45, 0.85, 0.9)).position = Vector3(70, -0.25, -60)
	_scatter(s, ["pirate/palm", "pirate/palm_bend"], 14, 55, 78, -26, -6, Vector2(0.9, 1.2))
	_scatter(s, ["nat/rock_tall", "nat/rock_large"], 16, 82, 110, -30, -7, Vector2(1.6, 2.6))
	# Lava-Arena mit dem Boss (Akt 4)
	var lava := WorldKit.lava(s, Vector2(40, 24), -0.3, Vector2(0.1, 0.0))
	lava.position = Vector3(100, -0.3, -24)
	_boss = BossModel.create("ignis")
	s.add_child(_boss)
	_boss.position = Vector3(92.0, 0, -11.0)
	_boss.rotation.y = deg_to_rad(-20)
	_boss.visible = false
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.45, 0.15)
	glow.light_energy = 2.4
	glow.omni_range = 26.0
	glow.position = Vector3(96, 3, -18)
	s.add_child(glow)
	var embers := FX.emitter({"amount": 80, "life": 4.0, "one_shot": false, "explosive": 0.0, "spread": 30.0, "dir": Vector3.UP, "vel_min": 0.4,
		"vel_max": 1.4, "gravity": Vector3(0, 0.3, 0), "size": 0.14, "additive": true, "color": Color(1.0, 0.55, 0.2, 0.9), "box": Vector3(30, 1, 16)})
	s.add_child(embers)
	embers.position = Vector3(98, 0.5, -16)
	embers.emitting = true
	return s


## Bühnen der Montage (je eine klar erkennbare Spielsituation), nebeneinander im Abstand von 60 m.
func _build_montage(o: Vector3) -> Node3D:
	var s := Node3D.new()
	s.name = "Montage"
	add_child(s)
	s.position = o
	WorldKit.box(s, Vector3(800, 1, 200), Vector3(300, -0.5, 0), Color("#7fc96a"), false)
	# 0 Start-Arena · 1 letzte Münze · 2 Zielsprint · 3 Planke über Wasser · 4 Boss-Ausweichen · 5 Siegerpose
	WorldKit.cylinder(s, 6.0, 0.6, Vector3(0, 0.3, 0), Color("#ffb347"), false)
	WorldKit.cylinder(s, 5.0, 0.62, Vector3(0, 0.31, 0), Color("#ff6f91"), false)
	WorldKit.cylinder(s, 5.0, 0.4, Vector3(60, 0.2, 0), Color("#8fd3ff"), false)
	var coin := Assets.spawn("bg/coin_gold", s, Vector3(60, 1.2, 0), 0.0, 1.6)
	coin.name = "Coin"
	for z in range(-14, 15, 2):
		WorldKit.box(s, Vector3(1.0, 0.02, 1.0), Vector3(124.0, 0.03, z), Color.WHITE if (z / 2) % 2 == 0 else Color.BLACK, false)
	WorldKit.place(s, "kp/finish_wide", Vector3(124.0, 0, -0.5), 90.0, 1.0)
	WorldKit.water(s, Vector2(30, 30), -0.6, Color(0.1, 0.4, 0.65), Color(0.5, 0.85, 1.0)).position = Vector3(180, -0.6, 0)
	WorldKit.box(s, Vector3(30, 2, 30), Vector3(180, -1.65, 0), Color("#7fc96a"), false)   # Ufer unter dem Wasser verdeckt
	var plank := WorldKit.box(s, Vector3(5.0, 0.25, 1.0), Vector3(180.0, 0.5, 0), Color("#a6744a"), false)
	plank.name = "Plank"
	WorldKit.lava(s, Vector2(30, 30), -0.2, Vector2(0.08, 0.0)).position = Vector3(240, -0.2, -12)
	WorldKit.cylinder(s, 7.0, 0.4, Vector3(240, 0.2, 2), Color("#4a3a3e"), false)
	var boss2 := BossModel.create("ignis")
	s.add_child(boss2)
	boss2.position = Vector3(240.0, 0, -8.0)
	boss2.name = "Boss2"
	var podium := WorldKit.cylinder(s, 1.4, 1.2, Vector3(300.0, 0.6, 0), Color("#ffd23f"), false)
	podium.name = "Podium"
	# 6–8 Nitro-Dash-Strecke: Kurve, Gerade mit Überholen, Ziel
	var road := Color("#4b4f5c")
	for k in 24:
		var a := -PI * 0.5 + PI * k / 23.0
		var p := Vector3(360.0, 0.02, 0) + Vector3(cos(a), 0, sin(a)) * 12.0
		var seg := WorldKit.box(s, Vector3(7.0, 0.05, 2.2), p, road, false)
		seg.rotation.y = -a
		var curb := WorldKit.box(s, Vector3(0.5, 0.1, 2.2), Vector3(360.0, 0.03, 0) + Vector3(cos(a), 0, sin(a)) * 15.7, Color.WHITE if k % 2 == 0 else Color("#e8384f"), false)
		curb.rotation.y = -a
	WorldKit.box(s, Vector3(90, 0.05, 9), Vector3(450.0, 0.02, 0), road, false)
	for x in range(408, 492, 6):
		WorldKit.box(s, Vector3(2.0, 0.06, 0.25), Vector3(x, 0.04, 0), Color.WHITE, false)
	for z in [-4.8, 4.8]:
		for x in range(406, 494, 2):
			WorldKit.box(s, Vector3(2.0, 0.12, 0.4), Vector3(x, 0.05, z), Color.WHITE if (x / 2) % 2 == 0 else Color("#e8384f"), false)
	for z in range(-4, 5, 1):
		WorldKit.box(s, Vector3(1.0, 0.03, 1.0), Vector3(480.0, 0.05, z), Color.WHITE if (z + 10) % 2 == 0 else Color.BLACK, false)
	WorldKit.place(s, "kp/finish_wide", Vector3(480.0, 0, 0), 90.0, 1.0)
	for e in [[Vector3(478, 0, -6), "kp/flag_red"], [Vector3(478, 0, 6), "kp/flag_blue"]]:
		WorldKit.place(s, String(e[1]), e[0], 90.0, 1.4)
	var hk := ["hero/knight", "hero/mage", "hero/barbarian", "hero/ranger"]
	var kk := ["kart/oopi", "kart/ooli", "kart/oobi", "kart/oodi"]
	for i in 3:
		var kv := KartVisual.new()
		s.add_child(kv)
		kv.setup(kk[i], hk[i], i, 2.0)
		kv.visible = false
		_karts.append(kv)
	_scatter(s, ["nat/tree_oak", "nat/tree_default", "plat/tree"], 60, -20, 520, -60, -16, Vector2(2.4, 3.4))
	return s


func _build_cast() -> void:
	for k in ["hero/knight", "hero/mage", "hero/barbarian", "hero/ranger"]:
		var r := CharacterRig.new()
		r.set_meta("gfx_lod", 0)   # Darsteller nie ins Animations-LOD der Spiel-Grafik (immer volle Bildrate, Kopf-Blick an)
		add_child(r)
		r.setup(k, -1, 0.95)
		r.play("idle")
		r.visible = false
		heroes.append(r)
	# Glühwürmchen (Nasen-Gag) und Schmetterling
	_firefly = _glowbug(Color(1.0, 0.95, 0.5), 0.09)
	_butterfly = Node3D.new()
	add_child(_butterfly)
	for sd in [-1.0, 1.0]:
		var w := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.18, 0.14)
		var m := WorldKit.mat(Color("#8fe8ff"), 0.4, 2.0)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		q.material = m
		w.mesh = q
		w.position = Vector3(sd * 0.09, 0, 0)
		w.name = "WingL" if sd < 0 else "WingR"
		_butterfly.add_child(w)
	_butterfly.visible = false


func _glowbug(col: Color, r: float) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	var m := WorldKit.mat(col, 0.2, 4.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = m
	mi.mesh = sm
	n.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 0.8
	l.omni_range = 2.0
	n.add_child(l)
	n.visible = false
	return n


func _build_music() -> void:
	for p in ["res://assets/music/board/glowforest.ogg", "res://assets/music/minigame/mg2_hurry.ogg", "res://assets/music/board/glowforest.ogg"]:
		var a := AudioStreamPlayer.new()
		a.bus = "Music"
		a.stream = load(p)
		a.volume_db = -80.0
		add_child(a)
		_music.append(a)
	_music[0].play()


var _vol := [0.0, 0.0, 0.0]


func _drive_music() -> void:
	# Lautstärke-Kurven je Spur (linear 0..1): Wald-Thema baut auf · Stille vor dem BOOM · Hurry-Up · ruhiges Ende
	var v0 := 0.0
	if t < 64.6:
		v0 = clampf(t / 3.0, 0.0, 1.0) * lerpf(0.55, 1.0, clampf((t - 10.0) / 22.0, 0.0, 1.0))
	elif t < 65.0:
		v0 = lerpf(1.0, 0.0, (t - 64.6) / 0.4)
	var end_m := MONTAGE_T0 + 10.0 * 4.0 * BEAT
	var v1 := 0.0
	if t >= MONTAGE_T0 and t < end_m - 0.2:
		v1 = 1.0
	elif t >= end_m - 0.2 and t < end_m + 0.3:
		v1 = lerpf(1.0, 0.0, (t - end_m + 0.2) / 0.5)
	var v2 := 0.0
	if t >= end_m:
		v2 = clampf((t - end_m) / 1.4, 0.0, 1.0) * 0.85 * (1.0 - clampf((t - (DUR - 2.8)) / 2.6, 0.0, 1.0))
	var vs := [v0, v1, v2]
	for k in 3:
		_music[k].volume_db = linear_to_db(maxf(float(vs[k]), 0.0001))


# =============================================================================================================
# Drehbuch
# =============================================================================================================

func _script_all() -> void:
	_act1()
	_act2()
	_act3()
	_act4()
	_act5()


# --- Akt 1 – Ein kleiner Stern (0–15 s) ----------------------------------------------------------------------
func _act1() -> void:
	var A := 0
	at(0.0, func() -> void:
		heroes[A].visible = true
		var rim := OmniLight3D.new()   # nur ein Hauch Mondlicht – die Figur bleibt klein in der Dunkelheit
		rim.name = "VoidRim"
		rim.light_color = Color(0.55, 0.65, 1.0)
		rim.light_energy = 1.0
		rim.omni_range = 5.0
		rim.shadow_enabled = false
		heroes[A].add_child(rim)
		rim.position = Vector3(0.8, 2.6, 1.6)
		_letterbox(0.1, 0.01)
		_fade(_black, 0.0, 2.2))
	# Weit weg, fast verloren in der Dunkelheit
	key(0.0, Vector3(-2.0, 2.6, 15.0), Vector3(-2.0, 1.0, 0.0), 42.0)
	key(3.6, Vector3(-1.4, 2.2, 12.0), Vector3(-0.6, 1.1, 0.0), 40.0)
	go(A, 0.4, 3.6, Vector3(-8.0, 0, 0), Vector3(-1.4, 0, 0))
	face(A, 3.6, Vector3(1, 0, 0))
	at(3.6, func() -> void:
		_star.visible = true
		_star.scale = Vector3.ONE * 0.01
		create_tween().tween_property(_star, "scale", Vector3.ONE * 0.75, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		create_tween().tween_property(_star_light, "light_energy", 2.2, 0.8)
		Audio.sfx("sparkle_up", null, -4.0, 1.1, 0.0))
	look(A, 3.7, Vector3(1.2, 1.55, 0))
	# Neugier: vorsichtig näher, Kopf schief
	react(A, 4.3, "confused")
	go(A, 4.6, 5.8, Vector3(-1.4, 0, 0), Vector3(-0.4, 0, 0))
	key(5.0, Vector3(1.6, 1.7, 5.2), Vector3(0.2, 1.3, 0.0), 38.0)
	clip(A, 6.0, "interact", 0.15, 0.9)
	at(6.25, func() -> void:   # der Stern weicht kichernd aus
		create_tween().tween_property(_star, "position:x", 1.9, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Audio.sfx("pluck", null, -6.0, 1.4, 0.0))
	look(A, 6.3, Vector3(1.9, 1.55, 0))
	react(A, 6.9, "confused")
	go(A, 7.2, 8.0, Vector3(-0.4, 0, 0), Vector3(0.7, 0, 0))
	key(7.6, Vector3(2.4, 1.6, 4.4), Vector3(1.2, 1.4, 0.0), 36.0)
	clip(A, 8.05, "interact", 0.12, 1.1)
	react(A, 8.35, "star_get")
	# Berührung: warmer Lichtblitz, die Dunkelheit verschwindet
	at(8.45, func() -> void:
		Audio.sfx("chime", null, -2.0, 1.0, 0.0)
		Audio.sfx("woom", null, -6.0, 0.8, 0.0)
		FX.shockwave(_origin + Vector3(1.9, 1.0, 0), 40.0, Color(1.0, 0.85, 0.45, 0.9))
		_mark("Blitz")
		create_tween().tween_property(_flash, "modulate:a", 1.0, 0.12))
	at(8.6, func() -> void:
		_star.visible = false
		var rim := heroes[A].get_node_or_null("VoidRim")
		if rim:
			rim.queue_free()
		_sets.forest.visible = true
		_use_env("forest_night")
		FX.stars(_origin + Vector3(1.9, 1.6, 0), Color(1, 0.9, 0.4), 30)
		_fade(_flash, 0.0, 1.1))
	# Enthüllung: Kamera fährt nach oben, der Held staunt und dreht sich langsam um
	react(A, 9.0, "shocked")
	look(A, 9.2, Vector3(-6.0, 4.0, -12.0))
	key(9.0, Vector3(3.0, 1.5, 4.6), Vector3(1.0, 1.4, 0.0), 40.0)
	key(15.0, Vector3(4.0, 7.8, 13.0), Vector3(2.0, 2.4, -6.0), 52.0)
	face(A, 10.5, Vector3(0, 0, -1))
	look(A, 11.0, Vector3(8.0, 3.0, -10.0))
	face(A, 12.0, Vector3(-1, 0, -0.3))
	look(A, 12.8, Vector3(1.0, 14.0, -4.0))   # ganz nach oben in die Baumkronen
	face(A, 13.6, Vector3(0.2, 0, 1))


# --- Akt 2 – Eine Welt voller Wunder (15–35 s) ----------------------------------------------------------------
func _act2() -> void:
	var A := 0
	look(A, 15.0, null)
	react(A, 15.1, "wave")
	# gemütlich los (seitlich, leicht von vorne begleitet)
	go(A, 15.6, 17.4, Vector3(0.7, 0, 0), Vector3(3.4, 0, 0))
	key(15.6, Vector3(4.8, 1.9, 6.8), Vector3(2.2, 1.2, 0.0), 46.0)
	key(17.4, Vector3(6.6, 1.8, 5.6), Vector3(3.6, 1.3, 0.0), 44.0)
	# Glühwürmchen vor der Nase
	at(16.9, func() -> void: _firefly.visible = true)
	look(A, 17.0, _firefly)
	clip(A, 17.9, "interact", 0.12, 1.0)
	react(A, 18.6, "laugh")
	go(A, 18.8, 21.6, Vector3(3.4, 0, 0), Vector3(8.0, 0, 0))
	look(A, 19.6, null)
	key(21.0, Vector3(10.6, 1.7, 5.4), Vector3(8.2, 1.0, 0.0), 44.0)
	# Ast auf dem Weg: Stolpern, Arme rudern, gerade noch gefangen
	at(19.0, func() -> void: WorldKit.place(_sets.forest, "nat/log", Vector3(8.6, 0, 0.2), 90.0, 0.45))
	go(A, 21.6, 22.1, Vector3(8.0, 0, 0), Vector3(8.7, 0.0, 0.05), 0.25)
	at(21.75, func() -> void:
		heroes[A].modifier_pulse("scared", 0.9, 1.0)
		heroes[A].play("hit_b", 0.08, 1.4, true)
		heroes[A].lock(0.45)
		Audio.sfx("wood_hit", heroes[A].global_position, -8.0, 1.3, 0.0))
	go(A, 22.1, 22.8, Vector3(8.7, 0, 0.05), Vector3(9.2, 0, -0.1))   # taumelnd abgefangen
	at(22.5, func() -> void: heroes[A].squash(1.15, 0.85, 0.3))
	react(A, 23.0, "determined")
	go(A, 23.3, 25.0, Vector3(9.2, 0, -0.1), Vector3(13.2, 0, 0))
	key(24.6, Vector3(14.6, 1.6, 4.8), Vector3(14.0, 2.6, -6.0), 46.0)
	# Wasserfall: stehen bleiben, nach oben schauen – die Kamera fährt an ihm vorbei
	face(A, 25.0, Vector3(0.4, 0, -1))
	look(A, 25.2, Vector3(16.0, 9.0, -8.5))
	react(A, 25.4, "shocked")
	key(28.0, Vector3(18.6, 2.2, 3.2), Vector3(15.0, 4.2, -8.0), 54.0)
	# In der Ferne: ein Freund winkt
	at(26.5, func() -> void:
		heroes[1].visible = true
		heroes[1].play("wave", 0.2))
	go(1, 26.5, 26.6, Vector3(31.0, 0.5, -1.6), Vector3(31.0, 0.5, -1.6))
	face(1, 26.5, Vector3(-1, 0, 0.3))
	go(A, 28.0, 29.0, Vector3(13.2, 0, 0), Vector3(14.6, 0, 0))
	key(29.2, Vector3(12.0, 2.2, 6.0), Vector3(22.0, 1.4, -1.0), 40.0)
	look(A, 29.0, Vector3(31.0, 2.0, -1.6))
	at(29.1, func() -> void: heroes[A].squash(0.9, 1.12, 0.25))   # Überraschung: kurzes Erstarren
	react(A, 29.8, "cheer")
	at(30.4, func() -> void: heroes[A].anticipate(0.3, 0.1))
	go(A, 30.6, 35.0, Vector3(14.6, 0, 0), Vector3(29.6, 0, 0.1))
	key(31.0, Vector3(17.0, 1.8, 6.4), Vector3(19.5, 1.2, 0.0), 46.0)
	key(35.0, Vector3(31.4, 1.8, 6.6), Vector3(29.6, 1.2, -0.4), 46.0)


# --- Akt 3 – Gemeinsam unterwegs (35–58 s) --------------------------------------------------------------------
func _act3() -> void:
	var A := 0
	var B := 1
	var C := 2
	var D := 3
	look(A, 33.0, B)
	at(34.0, func() -> void: heroes[B].play("idle", 0.3))
	go(B, 34.2, 35.0, Vector3(31.0, 0.5, -1.6), Vector3(30.6, 0, -0.8), 0.4)
	look(B, 34.0, A)
	# High-Five
	face(A, 35.0, Vector3(0.4, 0, -1))
	face(B, 35.0, Vector3(-0.4, 0, 1))
	clip(A, 35.35, "punch", 0.1, 1.2)
	clip(B, 35.35, "punch", 0.1, 1.2)
	at(35.6, func() -> void:
		FX.stars(_origin + Vector3(30.1, 1.6, -0.35), Color(1, 0.9, 0.3), 14)
		Audio.sfx("pop", null, -2.0, 1.2, 0.0))
	react(A, 35.9, "laugh")
	react(B, 35.9, "laugh")
	key(35.4, Vector3(32.6, 1.6, 4.4), Vector3(30.1, 1.3, -0.4), 40.0)
	# gemeinsam weiter – der Schmetterling landet auf der Nase des Helden, die Magierin läuft auf
	go(A, 36.4, 38.2, Vector3(29.6, 0, 0.1), Vector3(33.4, 0, 0.0))
	go(B, 36.4, 38.4, Vector3(30.6, 0, -0.8), Vector3(33.0, 0, -0.1))
	look(A, 36.6, null)
	look(B, 36.6, null)
	key(37.0, Vector3(34.6, 1.7, 5.4), Vector3(32.0, 1.2, 0.0), 42.0)
	at(37.4, func() -> void: _butterfly.visible = true)
	look(A, 37.6, _butterfly)
	at(38.25, func() -> void: heroes[A].squash(0.92, 1.08, 0.2))
	# Aufprall von hinten: beide taumeln
	go(B, 38.4, 38.65, Vector3(33.0, 0, -0.1), Vector3(33.05, 0, -0.05))
	at(38.6, func() -> void:
		heroes[A].modifier_pulse("dizzy", 0.9, 0.8)
		heroes[B].modifier_pulse("dizzy", 0.9, 0.8)
		heroes[B].play("hit", 0.06, 1.3, true)
		heroes[B].lock(0.4)
		Audio.sfx("boing", heroes[A].global_position, -4.0, 1.2, 0.0)
		FX.dizzy_stars(heroes[B], 2.5, 1.0, 3))
	go(A, 38.65, 39.2, Vector3(33.4, 0, 0.0), Vector3(34.2, 0, 0.1), 0.3)
	go(B, 38.65, 39.2, Vector3(33.05, 0, -0.05), Vector3(32.4, 0, -0.4))
	react(A, 39.4, "laugh")
	react(B, 39.5, "laugh")
	look(A, 39.3, B)
	# Der Barbar kommt keuchend von hinten angerannt
	at(39.0, func() -> void: heroes[C].visible = true)
	go(C, 39.0, 42.6, Vector3(18.0, 0, 0.9), Vector3(32.6, 0, 1.0))
	go(C, 42.6, 43.8, Vector3(32.6, 0, 1.0), Vector3(34.4, 0, 0.9))   # außer Atem, wird langsamer
	at(42.8, func() -> void: heroes[C].set_lean(0.6))
	react(C, 43.9, "sleepy")
	look(A, 41.8, C)
	look(B, 42.2, C)
	key(40.4, Vector3(31.0, 1.8, 7.4), Vector3(31.0, 1.1, 0.0), 48.0)
	# Alle weiter – vorbei am Träumer auf dem Stein
	at(40.0, func() -> void:
		heroes[D].visible = true
		heroes[D].play("sit", 0.1))
	pose(D, 40.0, "sit")
	go(D, 40.0, 40.1, Vector3(46.0, 0.55, -2.4), Vector3(46.0, 0.55, -2.4))
	face(D, 40.0, Vector3(0.6, 0, 0.6))
	look(D, 40.0, Vector3(47.0, 0.6, -2.0))
	go(A, 44.0, 47.4, Vector3(34.2, 0, 0.1), Vector3(42.0, 0, 0.0))
	go(B, 44.0, 47.4, Vector3(32.4, 0, -0.4), Vector3(41.0, 0, -0.8))
	go(C, 44.6, 47.4, Vector3(34.4, 0, 0.9), Vector3(40.0, 0, 1.0))
	look(A, 44.2, null)
	look(B, 44.2, null)
	look(C, 44.6, null)
	key(44.0, Vector3(37.0, 1.8, 6.6), Vector3(36.2, 1.0, -0.6), 44.0)
	key(47.4, Vector3(46.0, 1.8, 6.0), Vector3(44.0, 1.0, -1.0), 44.0)
	# … und bemerkt es zu spät: links, rechts, hinterher!
	look(D, 46.8, Vector3(40.0, 1.6, 0.0))
	look(D, 47.3, Vector3(52.0, 1.6, 0.0))
	look(D, 47.8, Vector3(44.0, 1.6, 0.0))
	at(47.9, func() -> void:
		heroes[D].squash(0.9, 1.15, 0.25)
		_hold[D] = false
		FX.emote(heroes[D], "!", Color(1, 0.85, 0.2), 2.7, 0.8))
	go(D, 48.1, 48.5, Vector3(46.0, 0.55, -2.4), Vector3(45.6, 0, -0.6), 0.6)
	# Er rennt so schnell los, dass er beinahe in den Barbaren kracht
	go(C, 47.4, 48.6, Vector3(40.0, 0, 1.0), Vector3(43.8, 0, 0.6))
	go(D, 48.5, 48.75, Vector3(45.6, 0, -0.6), Vector3(44.6, 0, 0.3))
	at(48.75, func() -> void:
		for k in [C, D]:
			heroes[k].modifier_pulse("dizzy", 0.7, 0.9)
			heroes[k].squash(1.12, 0.9, 0.3)
		Audio.sfx("hit_soft", heroes[C].global_position, -2.0, 1.1, 0.0))
	go(C, 48.75, 49.3, Vector3(43.8, 0, 0.6), Vector3(43.3, 0, 1.3))
	go(D, 48.75, 49.3, Vector3(44.6, 0, 0.3), Vector3(45.1, 0, -0.3))
	react(C, 49.35, "laugh")
	react(D, 49.35, "laugh")
	# Der Held schaut über die Schulter, lacht und winkt
	go(A, 47.4, 49.0, Vector3(42.0, 0, 0.0), Vector3(46.6, 0, 0.0))
	go(B, 47.4, 49.0, Vector3(41.0, 0, -0.8), Vector3(45.6, 0, -0.8))
	look(A, 48.8, D)
	react(A, 49.5, "wave")
	key(48.6, Vector3(47.6, 1.7, 5.6), Vector3(45.0, 1.2, 0.0), 42.0)
	# Gemeinsam los – Weltenwechsel 1: hinter dem riesigen Baumstamm
	go(A, 50.0, 53.2, Vector3(46.6, 0, 0.0), Vector3(57.0, 0, 0.0))
	go(B, 50.0, 53.2, Vector3(45.6, 0, -0.8), Vector3(56.0, 0, -0.9))
	go(C, 49.6, 53.2, Vector3(43.3, 0, 1.3), Vector3(55.0, 0, 1.0))
	go(D, 49.6, 53.2, Vector3(45.1, 0, -0.3), Vector3(54.0, 0, -1.8))
	for k in 4:
		look(k, 50.0, null)
	key(50.0, Vector3(49.0, 1.8, 7.6), Vector3(48.0, 1.1, 0.0), 46.0)
	# Der Stamm zieht ganz nah durchs Bild und deckt es im Wechselmoment vollständig ab
	at(48.0, func() -> void: _trunk.visible = true)
	at(WIPE_T, func() -> void: _use_set("meadow", "day"))
	at(56.0, func() -> void: _trunk.visible = false)
	# Wiese: Die Magierin bleibt staunend vor der Riesenblume stehen – der Held holt sie
	go(A, 53.2, 55.0, Vector3(57.0, 0, 0.0), Vector3(63.0, 0, 0.0))
	go(B, 53.2, 54.4, Vector3(56.0, 0, -0.9), Vector3(60.6, 0, -1.0))
	go(C, 53.2, 55.0, Vector3(55.0, 0, 1.0), Vector3(61.0, 0, 1.0))
	go(D, 53.2, 55.0, Vector3(54.0, 0, -1.8), Vector3(60.0, 0, -1.8))
	face(B, 54.4, Vector3(0.6, 0, -1))
	look(B, 54.5, Vector3(63.0, 2.4, -2.8))
	react(B, 54.6, "shocked")
	look(A, 54.8, B)
	go(A, 55.0, 55.6, Vector3(63.0, 0, 0.0), Vector3(61.4, 0, -0.5))
	clip(A, 55.65, "interact", 0.1, 1.2)
	at(55.8, func() -> void: Audio.sfx("plop", null, -6.0, 1.3, 0.0))
	look(B, 55.8, A)
	go(A, 56.0, 58.4, Vector3(61.4, 0, -0.5), Vector3(68.4, 0, 0.0))
	go(B, 56.05, 58.4, Vector3(60.6, 0, -1.0), Vector3(67.4, 0, -0.9))
	go(C, 55.0, 58.4, Vector3(61.0, 0, 1.0), Vector3(67.0, 0, 1.0))
	go(D, 55.0, 58.4, Vector3(60.0, 0, -1.8), Vector3(66.0, 0, -1.8))
	for k in 4:
		look(k, 56.2, null)
	key(53.6, Vector3(60.6, 1.8, 7.6), Vector3(59.8, 1.1, 0.0), 46.0)
	key(55.6, Vector3(63.4, 1.6, 5.2), Vector3(61.5, 1.3, -0.6), 42.0)
	# Weltenwechsel 2: durch die Wasserwand
	key(58.0, Vector3(69.0, 2.0, 7.0), Vector3(67.0, 1.2, 0.0), 46.0)
	at(57.75, func() -> void:
		Audio.sfx("splash", null, -6.0, 1.0, 0.0)
		_mark("Wasserwand")
		create_tween().tween_property(_water, "modulate:a", 0.95, 0.18))
	at(57.95, func() -> void:
		_use_set("snow", "snow")
		_fade(_water, 0.0, 0.5))


# --- Akt 4 – Das Abenteuer eskaliert (Weltenwechsel 3+4, Boss, BOOM, Montage) --------------------------------------
func _act4() -> void:
	var A := 0
	var B := 1
	var C := 2
	var D := 3
	# Schnee: Der Träumer berührt einen schwebenden Stern – Sternenblitz
	go(A, 58.4, 60.4, Vector3(68.4, 0, 0.0), Vector3(74.6, 0, 0.1))
	go(B, 58.4, 60.4, Vector3(67.4, 0, -0.9), Vector3(73.6, 0, -0.6))
	go(C, 58.4, 60.4, Vector3(67.0, 0, 1.0), Vector3(73.0, 0, 1.0))
	go(D, 58.4, 59.6, Vector3(66.0, 0, -1.8), Vector3(73.0, 0, -1.4))
	look(D, 58.8, Vector3(73.6, 1.7, -1.4))
	clip(D, 59.6, "interact", 0.1, 1.2)
	key(59.8, Vector3(75.4, 1.9, 5.6), Vector3(73.2, 1.3, -0.6), 44.0)
	at(59.85, func() -> void:
		Audio.sfx("chime", null, -3.0, 1.2, 0.0)
		_mark("Blitz")
		create_tween().tween_property(_flash, "modulate:a", 1.0, 0.1))
	at(60.0, func() -> void:
		_use_set("beach", "sunset")
		_fade(_flash, 0.0, 0.7))
	go(D, 60.0, 60.4, Vector3(73.0, 0, -1.4), Vector3(73.6, 0, -1.2))
	# Strand → Vulkangestein: Boden wandelt sich, die Gruppe läuft, springt, stupst sich an
	go(A, 60.4, 63.4, Vector3(74.6, 0, 0.1), Vector3(84.6, 0, 0.2))
	go(B, 60.4, 63.4, Vector3(73.6, 0, -0.6), Vector3(83.4, 0, -0.9))
	go(C, 60.4, 61.6, Vector3(73.0, 0, 1.0), Vector3(77.2, 0, 0.6))
	go(D, 60.4, 61.6, Vector3(73.6, 0, -1.2), Vector3(77.0, 0, -0.2))
	at(61.6, func() -> void:   # Stupser
		heroes[D].squash(1.12, 0.9, 0.25)
		heroes[D].modifier_pulse("scared", 0.5, 0.6)
		Audio.sfx("hit_soft", null, -8.0, 1.4, 0.0))
	go(C, 61.6, 63.4, Vector3(77.2, 0, 0.6), Vector3(83.0, 0, 1.2))
	go(D, 61.6, 62.0, Vector3(77.0, 0, -0.2), Vector3(77.9, 0, -1.4), 0.3)
	go(D, 62.0, 63.4, Vector3(77.9, 0, -1.4), Vector3(82.2, 0, -1.8))
	react(D, 62.1, "laugh")
	at(62.0, func() -> void: heroes[A].anticipate(0.25, 0.08))
	key(60.4, Vector3(77.0, 2.0, 7.6), Vector3(75.0, 1.1, 0.0), 46.0)
	key(63.2, Vector3(85.8, 2.4, 8.2), Vector3(83.8, 1.4, -1.0), 48.0)
	# Der Boss taucht auf – alle stehen still und schauen nach oben
	at(63.3, func() -> void:
		_boss.visible = true
		_boss.position.y = -7.0
		create_tween().tween_property(_boss, "position:y", 0.0, 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Juice.shake(0.35)
		Audio.sfx("stone_hit", null, 0.0, 0.6, 0.0)
		_boss.act("roar"))
	for k in 4:
		look(k, 63.5 + k * 0.08, Vector3(92.0, 6.5, -11.0))
		face(k, 63.5, Vector3(0.5, 0, -1))
		react(k, 63.6 + k * 0.1, "scared")
	key(63.45, Vector3(81.6, 1.0, 5.2), Vector3(89.0, 5.2, -10.0), 50.0, true)
	key(65.3, Vector3(82.2, 1.2, 4.2), Vector3(90.0, 6.2, -10.5), 44.0)
	at(64.5, func() -> void: _boss.act("slam"))   # hebt den Arm …
	# … die Musik stoppt einen Moment … BOOM!
	at(MONTAGE_T0, func() -> void:
		Juice.shake(0.6)
		Audio.sfx("explosion_big", null, 0.0, 1.0, 0.0)
		_mark("BOOM")
		_flash.modulate.a = 1.0
		_fade(_flash, 0.0, 0.35)
		_music[1].play())
	_montage()


## Zehn Schnitte im Takt: Start · letzte Münze · Zielfoto · Wasser · Boss ausweichen · Siegerpose ·
## Drift · Überholen · Ziellinie · Jubel.
func _montage() -> void:
	var sh := 4.0 * BEAT
	var s := []
	for k in 10:
		s.append(MONTAGE_T0 + k * sh)
	var A := 0
	var B := 1
	var C := 2
	var D := 3
	var cast := func(on: Array, time: float) -> void:
		at(time, func() -> void:
			for k in 4:
				heroes[k].visible = k in on
				heroes[k].set_lean(0.0)
				heroes[k].clear_look()
			for kv in _karts:
				kv.visible = false)
	at(s[0], func() -> void: _use_set("montage", "day"))
	# 0 – „LOS!“
	cast.call([A, B, C, D], s[0])
	var ring := [Vector3(-1.6, 0.62, 1.2), Vector3(1.6, 0.62, 1.2), Vector3(-1.6, 0.62, -1.4), Vector3(1.6, 0.62, -1.4)]
	for k in 4:
		go(k, s[0], s[0] + 0.01, ring[k], ring[k])
		go(k, s[0] + 0.25 + k * 0.08, s[0] + 0.85 + k * 0.08, ring[k], ring[k], 0.9)
		face(k, s[0], Vector3(0, 0, 1))
		react(k, s[0] + 0.9, "cheer")
	key(s[0], Vector3(0.0, 3.4, 8.4), Vector3(0.0, 1.4, 0.0), 44.0, true)
	key(s[1] - 0.01, Vector3(0.0, 2.8, 6.8), Vector3(0.0, 1.5, 0.0), 42.0)
	at(s[0] + 0.15, func() -> void: _word("LOS!", Color("#ffd23f")))
	# 1 – Zwei kämpfen um die letzte Münze
	cast.call([A, C], s[1])
	at(s[1], func() -> void: (_sets.montage.get_node("Coin") as Node3D).visible = true)
	go(A, s[1], s[1] + 0.01, Vector3(56.4, 0.4, 0), Vector3(56.4, 0.4, 0))
	go(C, s[1], s[1] + 0.01, Vector3(63.6, 0.4, 0), Vector3(63.6, 0.4, 0))
	go(A, s[1] + 0.2, s[1] + 0.85, Vector3(56.4, 0.4, 0), Vector3(59.6, 0.4, 0), 0.7)
	go(C, s[1] + 0.25, s[1] + 0.95, Vector3(63.6, 0.4, 0), Vector3(60.5, 0.4, 0), 0.6)
	at(s[1] + 0.85, func() -> void:
		var coin := _sets.montage.get_node("Coin") as Node3D
		coin.visible = false
		Audio.sfx("coin", null, 0.0, 1.0, 0.0)
		Juice.float_text(self, _origin + Vector3(59.6, 2.6, 0), "+1", UI.GOLD, 110))
	react(A, s[1] + 0.95, "victory")
	react(C, s[1] + 1.0, "trip_fall")
	key(s[1], Vector3(60.0, 1.9, 6.4), Vector3(60.0, 1.1, 0.0), 40.0, true)
	key(s[2] - 0.01, Vector3(60.0, 1.6, 5.4), Vector3(60.0, 1.0, 0.0), 38.0)
	# 2 – Zielfoto: knapp vorn!
	cast.call([B, D], s[2])
	go(B, s[2], s[2] + 1.25, Vector3(111.0, 0, -0.8), Vector3(125.4, 0, -0.8))
	go(D, s[2], s[2] + 1.32, Vector3(111.0, 0, 0.8), Vector3(125.0, 0, 0.8))
	react(B, s[2] + 1.3, "cheer")
	react(D, s[2] + 1.4, "frustrated")
	at(s[2] + 1.15, func() -> void:
		_mark("Blitz")
		_flash.modulate.a = 0.6
		_fade(_flash, 0.0, 0.25)
		Audio.sfx("whistle_up", null, -4.0, 1.2, 0.0))
	key(s[2], Vector3(127.2, 1.0, 3.6), Vector3(120.0, 1.2, 0.0), 38.0, true)
	key(s[3] - 0.01, Vector3(127.0, 1.1, 3.2), Vector3(123.0, 1.2, 0.0), 36.0)
	# 3 – Einer fällt ins Wasser
	cast.call([C, A], s[3])
	go(C, s[3], s[3] + 0.7, Vector3(178.0, 0.62, 0), Vector3(180.6, 0.62, 0))
	at(s[3] + 0.6, func() -> void: heroes[C].modifier_pulse("tremble", 0.6, 1.0))
	react(C, s[3] + 0.75, "slip")
	go(C, s[3] + 0.8, s[3] + 1.25, Vector3(180.6, 0.62, 0), Vector3(181.6, -0.9, 0.5), 0.4)
	at(s[3] + 1.2, func() -> void:
		FX.splash(_origin + Vector3(181.6, -0.5, 0.5), 1.6)
		Audio.sfx("splash", null, 0.0, 1.0, 0.0))
	go(A, s[3], s[3] + 0.01, Vector3(176.4, 0, 1.8), Vector3(176.4, 0, 1.8))
	face(A, s[3], Vector3(1, 0, -0.6))
	look(A, s[3], C)
	react(A, s[3] + 1.3, "laugh")
	key(s[3], Vector3(175.6, 2.6, 6.6), Vector3(180.0, 0.6, 0.0), 42.0, true)
	key(s[4] - 0.01, Vector3(176.4, 2.2, 6.0), Vector3(181.0, 0.2, 0.2), 40.0)
	# 4 – Bossangriff gerade noch ausgewichen
	cast.call([D], s[4])
	at(s[4], func() -> void:
		_use_env("volcano")
		(_sets.montage.get_node("Boss2") as BossModel).act("slam")
		MgKit.warn_disc(_sets.montage, Vector3(240, 0.45, 3), 1.6, Color(1, 0.2, 0.1, 0.6), 0.9))
	go(D, s[4], s[4] + 0.01, Vector3(240.0, 0.4, 3.0), Vector3(240.0, 0.4, 3.0))
	look(D, s[4], Vector3(240, 5, -8))
	clip(D, s[4] + 0.5, "dodge", 0.08, 1.4)
	go(D, s[4] + 0.5, s[4] + 0.95, Vector3(240.0, 0.4, 3.0), Vector3(243.4, 0.4, 3.6), 0.5)
	at(s[4] + 0.95, func() -> void:
		FX.explosion(_origin + Vector3(240, 0.6, 3), 1.2)
		Juice.shake(0.4))
	react(D, s[4] + 1.2, "determined")
	key(s[4], Vector3(235.6, 3.0, 9.6), Vector3(240.0, 2.4, -1.0), 46.0, true)
	key(s[5] - 0.01, Vector3(236.4, 2.6, 8.8), Vector3(241.0, 2.0, 0.0), 44.0)
	# 5 – Völlig übertriebene Siegerpose
	cast.call([A], s[5])
	at(s[5], func() -> void: _use_env("day"))
	go(A, s[5], s[5] + 0.01, Vector3(300.0, 1.2, 0), Vector3(300.0, 1.2, 0))
	face(A, s[5], Vector3(0, 0, 1))
	react(A, s[5] + 0.1, "victory")
	at(s[5] + 0.45, func() -> void:
		heroes[A].spin_around(1.0, 0.45)
		FX.confetti(_origin + Vector3(300, 3.0, 0), 90))
	react(A, s[5] + 1.0, "flex")
	key(s[5], Vector3(300.4, 0.7, 4.6), Vector3(300.0, 2.3, 0.0), 48.0, true)
	key(s[6] - 0.01, Vector3(301.8, 0.9, 4.2), Vector3(300.0, 2.4, 0.0), 44.0)
	# 6 – Nitro Dash: Drift durch die Kurve · 7 – knappes Überholen · 8 – Ziellinie
	cast.call([], s[6])
	at(s[6], func() -> void: _karts[0].visible = true)
	key(s[6], Vector3(357.0, 2.0, -1.0), Vector3(363.8, 0.6, -11.4), 32.0, true)
	key(s[7] - 0.01, Vector3(358.0, 2.0, 0.5), Vector3(368.8, 0.6, 8.2), 30.0)
	cast.call([], s[7])
	at(s[7], func() -> void:
		_karts[1].visible = true
		_karts[2].visible = true)
	key(s[7], Vector3(420.0, 1.5, 7.4), Vector3(425.0, 0.8, 0.0), 44.0, true)
	key(s[8] - 0.01, Vector3(441.0, 1.5, 7.4), Vector3(446.0, 0.8, 0.0), 44.0)
	cast.call([], s[8])
	at(s[8], func() -> void: _karts[2].visible = true)
	at(s[8] + 0.85, func() -> void:
		FX.confetti(_origin + Vector3(480, 4.4, 0), 120)
		Audio.sfx("go", null, -2.0, 1.0, 0.0))
	key(s[8], Vector3(485.0, 1.4, 6.0), Vector3(477.0, 1.0, 0.0), 44.0, true)
	key(s[9] - 0.01, Vector3(485.6, 1.6, 5.4), Vector3(479.0, 1.2, 0.0), 42.0)
	# 9 – Jubel
	cast.call([A, B, C, D], s[9])
	var spots := [Vector3(300.0, 1.2, 0), Vector3(298.2, 0, 0.8), Vector3(301.8, 0, 0.8), Vector3(300.0, 0, 2.0)]
	for k in 4:
		go(k, s[9], s[9] + 0.01, spots[k], spots[k])
		face(k, s[9], Vector3(0, 0, 1))
		go(k, s[9] + 0.2 + k * 0.1, s[9] + 0.75 + k * 0.1, spots[k], spots[k], 0.8)
		react(k, s[9] + 0.8, "cheer")
	at(s[9] + 0.3, func() -> void: FX.confetti(_origin + Vector3(300, 4, 0), 120))
	key(s[9], Vector3(300.0, 2.2, 8.6), Vector3(300.0, 1.5, 0.0), 46.0, true)
	key(s[9] + sh - 0.02, Vector3(300.0, 2.6, 7.4), Vector3(300.0, 1.6, 0.0), 44.0)


## Großes Wort mitten im Bild (Pop-in, kurz stehen, weg)
func _word(text: String, col: Color) -> void:
	_bigword.text = text
	_bigword.add_theme_color_override("font_color", col)
	_bigword.modulate.a = 1.0
	_bigword.scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(_bigword, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.7)
	tw.tween_property(_bigword, "modulate:a", 0.0, 0.25)
	Audio.sfx("go", null, -2.0, 1.0, 0.0)


# --- Akt 5 – Wieder zusammen (Lagerfeuer, Logo) ------------------------------------------------------------------
func _act5() -> void:
	var A := 0
	var B := 1
	var C := 2
	var D := 3
	var t0 := MONTAGE_T0 + 10.0 * 4.0 * BEAT
	at(t0, func() -> void:
		_use_set("forest", "forest_night")
		for k in 4:
			heroes[k].visible = true
			heroes[k].set_lean(0.0)
		_music[2].play(84.0)
		_snack = WorldKit.place(_sets.forest, "hol/cookie", Vector3(-3.6, 0.62, -18.2), 0.0, 0.9))
	# Held wärmt sich die Hände (sitzt, zum Feuer gebeugt) · Magierin liegt und schaut in die Sterne
	# · Barbar isst · Waldläufer ist eingeschlafen und lehnt am Helden
	var fire := Vector3(-6.0, 0.6, -18.0)
	var pa := Vector3(-8.12, 0.42, -19.37)
	var pc := Vector3(-3.9, 0.42, -19.2)
	var pd := Vector3(-8.66, 0.42, -17.97)
	go(A, t0, t0 + 0.01, pa, pa)
	go(B, t0, t0 + 0.01, Vector3(-5.2, 0.05, -21.2), Vector3(-5.2, 0.05, -21.2))
	go(C, t0, t0 + 0.01, pc, pc)
	go(D, t0, t0 + 0.01, pd, pd)
	pose(A, t0, "sit")
	pose(B, t0, "lie")
	pose(C, t0, "sit")
	pose(D, t0, "sit")
	face(A, t0, (Vector3(fire.x, 0, fire.z) - Vector3(pa.x, 0, pa.z)).normalized())
	face(C, t0, (Vector3(fire.x, 0, fire.z) - Vector3(pc.x, 0, pc.z)).normalized())
	face(D, t0, Vector3(1, 0, 0))
	face(B, t0, Vector3(1, 0, 0))
	look(A, t0, fire)
	look(B, t0, Vector3(-4.0, 20.0, -24.0))
	look(C, t0, Vector3(-3.6, 0.6, -18.2))
	at(t0 + 0.05, func() -> void:
		heroes[A].set_lean(0.25)
		heroes[D].rotation.z = deg_to_rad(-14.0)   # lehnt sich an den Freund
		FX.zzz(heroes[D], 2.3, 12.0)
		FX.embers(_origin + fire, 10))
	for k in 6:
		at(t0 + 0.8 + k * 0.9, func() -> void: heroes[C].squash(1.05, 0.96, 0.25))   # kauen
	# Die kleine Pointe: Der Keks wandert heimlich zum Helden – der Barbar merkt es, beide grinsen
	look(A, t0 + 2.6, C)
	at(t0 + 3.0, func() -> void:
		var tw := create_tween()
		tw.tween_property(_snack, "position", Vector3(-7.5, 0.95, -18.7), 0.5).set_trans(Tween.TRANS_SINE)
		Audio.sfx("plop", null, -10.0, 1.6, 0.0))
	look(A, t0 + 3.5, fire)
	look(C, t0 + 4.0, Vector3(-7.5, 0.95, -18.7))
	at(t0 + 4.3, func() -> void: heroes[C].squash(0.92, 1.1, 0.25))
	look(C, t0 + 4.8, A)
	look(A, t0 + 5.2, C)
	at(t0 + 5.6, func() -> void:
		heroes[A].modifier_pulse("laugh", 1.4, 1.0)
		heroes[C].modifier_pulse("laugh", 1.4, 1.0))
	# Ein Funke steigt auf – die Kamera zieht sich zurück und steigt in den Nachthimmel
	at(t0 + 6.4, func() -> void:
		FX.sparks(_origin + fire + Vector3.UP * 0.6, Color(1.0, 0.7, 0.3), 8, 0.6)
		var sp := _glowbug(Color(1.0, 0.75, 0.35), 0.07)
		sp.global_position = _origin + fire + Vector3.UP * 0.8
		sp.visible = true
		create_tween().tween_property(sp, "global_position", _origin + fire + Vector3(0.8, 9.0, -1.0), 4.5).set_trans(Tween.TRANS_SINE))
	key(t0, Vector3(-4.3, 1.9, -12.0), Vector3(-6.0, 0.8, -18.9), 40.0, true)
	key(t0 + 6.0, Vector3(-4.7, 2.1, -12.7), Vector3(-6.0, 0.9, -18.9), 42.0)
	key(t0 + 11.2, Vector3(8.0, 17.0, 6.0), Vector3(-6.0, 0.0, -18.0), 56.0)
	# Logo und Slogan
	at(t0 + 8.4, func() -> void: _fade(_title, 1.0, 1.0))
	at(t0 + 9.4, func() -> void: _fade(_slogan, 1.0, 0.9))
	at(t0 + 10.2, func() -> void: _fade(_slogan2, 1.0, 0.9))
	at(t0 + 11.0, func() -> void: _fade(_cta, 1.0, 0.8))
	at(DUR - 1.2, func() -> void: _fade(_black, 1.0, 1.0))


func _animate_props(delta: float) -> void:
	if _firefly.visible:
		var a := heroes[0]
		var tt := t - 16.9
		var head := a.global_position + Vector3.UP * 1.9 + a.global_basis.z * -0.55
		if tt < 1.8:
			_firefly.global_position = head + Vector3(cos(tt * 5.0) * 0.4, sin(tt * 7.0) * 0.12, sin(tt * 5.0) * 0.3)
		else:
			_firefly.global_position = _firefly.global_position.lerp(head + Vector3(3.0, 2.5, -3.0), clampf(delta * 1.5, 0, 1))
			if tt > 4.0:
				_firefly.visible = false
	if _butterfly.visible:
		var a2 := heroes[0]
		var tb := t - 37.4
		var nose := a2.global_position + Vector3.UP * 1.95 - a2.global_basis.z * 0.42
		var flap := sin(t * 40.0) * 0.9
		(_butterfly.get_node("WingL") as Node3D).rotation.y = flap
		(_butterfly.get_node("WingR") as Node3D).rotation.y = -flap
		if tb < 0.8:
			_butterfly.global_position = nose + Vector3(1.4 - tb * 1.75, 0.6 - tb * 0.75, 0.6 - tb * 0.75)
		elif tb < 1.4:
			_butterfly.global_position = nose   # sitzt auf der Nase – er schielt darauf
		else:
			_butterfly.global_position = _butterfly.global_position.lerp(nose + Vector3(2, 3, -2), clampf(delta * 1.2, 0, 1))
			if tb > 3.5:
				_butterfly.visible = false
	if _fire_light:
		_fire_light.light_energy = 3.0 + sin(t * 9.0) * 0.35 + sin(t * 23.0) * 0.2
	_drive_karts(delta)


var _spark_acc := 0.0


func _drive_karts(delta: float) -> void:
	if _set_now != "montage" or _karts.is_empty():
		return
	var sh := 4.0 * BEAT
	var s6 := MONTAGE_T0 + 6.0 * sh
	var s7 := s6 + sh
	var s8 := s7 + sh
	if t >= s6 and t < s7:   # Drift: Bogen um die Kurve, Heck schwenkt aus
		var u := (t - s6) / sh
		var a := lerpf(-1.25, 0.75, u)
		var p := Vector3(360, 0, 0) + Vector3(cos(a), 0, sin(a)) * 12.0
		var tang := Vector3(-sin(a), 0, cos(a))
		_place_kart(_karts[0], p, tang.rotated(Vector3.UP, 0.45))
		_karts[0].update_visual(22.0, 0.9, 1, 2, false, false, delta)
		_spark_acc += delta
		if _spark_acc >= 0.05:   # zeitbasiert – bei 30 und 60 fps gleich dicht
			_spark_acc = 0.0
			FX.sparks(_origin + p - tang * 1.2, Color(0.5, 0.8, 1.0), 4, 0.5)
	elif t >= s7 and t < s8:   # Überholen: der hintere Kart zündet den Boost
		var u2 := (t - s7) / sh
		var e := u2 * u2 * (3.0 - 2.0 * u2)
		_place_kart(_karts[1], Vector3(lerpf(420, 441, u2), 0, -1.7), Vector3.RIGHT)
		_place_kart(_karts[2], Vector3(lerpf(414, 447, e), 0, 1.7), Vector3.RIGHT)
		_karts[1].update_visual(20.0, 0.0, 0, 0, false, false, delta)
		_karts[2].update_visual(26.0, -0.1, 0, 0, u2 > 0.3, false, delta)
	elif t >= s8 and t < s8 + sh:   # Ziellinie
		var u3 := (t - s8) / sh
		_place_kart(_karts[2], Vector3(lerpf(468, 492, u3), 0, 0.0), Vector3.RIGHT)
		_karts[2].update_visual(24.0, 0.0, 0, 0, true, false, delta)


func _place_kart(kv: KartVisual, p: Vector3, dir: Vector3) -> void:
	kv.global_position = _origin + p
	kv.rotation.y = atan2(dir.x, dir.z) + PI
