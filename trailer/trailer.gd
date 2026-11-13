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

const DUR := 97.25
const BEAT := 60.0 / 138.0   # Hurry-Up-Track der Montage
const WIPE_T := 52.0
const WIPE2_T := 57.95      # Weltenwechsel hinter dem Wasserfall-Tor (Wiese → Bucht)
const FIREFLY_T := 17.3
const BUTTERFLY_T := 38.0
const BOSS_SCALE := 2.2       # Weltenwechsel hinter dem Stamm (Wald → Wiese)
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
var _gaze: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _gaze_w: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _moving: Array[bool] = [false, false, false, false]
var _curtain: Node3D
var _curtain_local := Vector3.ZERO
var _track: RaceTrack
var _rc_pos := Vector3.ZERO
var _rc_look := Vector3.ZERO
var _rc_shot := -1
var _cam_tan: Array = []
var _trunk: MeshInstance3D
var _flames: Array[MeshInstance3D] = []
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
var _caption: Label
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
var faces: Array[LumosFace] = []          # Framework-Gesicht je Figur (scripts/actor/lumos_face.gd)
var bodies: Array[LumosBody] = []         # Framework-Körper je Figur (Arm-IK, Fußanker, Haltung, Blick, Lachen, Atmung)
var _laughs: Array = [[], [], [], []]     # je Figur: [Beginn, Dauer, Stärke]
var _reach: Array = [[], [], [], []]      # je Figur: [Seite, t0, t1, t2, t3, Ziel]
var _carry: Array = []                    # [Objekt, Figur, Seite, t0, t1, Versatz]
var _nat := {"walk": 1.6, "run": 4.6}     # Tempo, bei dem die Füße im Clip nicht rutschen (wird vermessen)
var _air: Array[bool] = [false, false, false, false]
var _avoid: Array = []                    # [Mittelpunkt, Radius] – dort streut die Kulisse nichts hin
var _face_test := ""
var _env_we := {}                         # Umgebung → WorldEnvironment (für das Aufblenden des Waldes)
var _shroom_lights: Array[OmniLight3D] = []
var _hill_y := 0.25
var _stone_y := 0.6
var _fall_mat: ShaderMaterial
var _fill: OmniLight3D
var _board: BoardBuilder
var _bp: Array[Vector3] = []              # Standpunkte auf den Brettfeldern (Set-Koordinaten)
var _dice: Node3D
var _dice_fixed := false
var _dice_tick := 0.0
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
		if String(a).begins_with("--trailer-faces="):
			_face_test = String(a).substr(16)
		if String(a).begins_with("--trailer-msaa="):
			_msaa = clampi(String(a).substr(15).to_int(), 0, 3)
		if String(a).begins_with("--trailer-shadow="):
			_shadow = clampi(String(a).substr(17).to_int(), 1024, 16384)
	Engine.time_scale = 1.0
	Seasonal.test_override = "off"   # Trailer ist zeitlos (nur im Speicher dieses Prozesses)
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
	var cw2: Vector3 = _cam_eval(WIPE2_T)[0]
	_curtain_local = Vector3(cw2.x, 0.0, cw2.z - 1.7)
	_use_set("forest")
	_dim_forest()   # Akt 1 beginnt im gedämpften Mondlicht – der Stern weckt die Welt
	if _face_test != "":
		_run_face_test()
		return
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
	var vp := get_viewport()
	if vp.scaling_3d_scale != 1.0:
		vp.scaling_3d_scale = 1.0
	while not _ev.is_empty() and float(_ev[0][0]) <= t:
		var e: Array = _ev.pop_front()
		(e[1] as Callable).call()
	for i in heroes.size():
		bodies[i].dt = delta
		_drive(i, delta)
	_drive_carry()
	_drive_camera()
	_qa_popins()
	if _trunk.visible:   # nach den Ereignissen: im Wechselbild steht der Stamm schon in der neuen Welt
		_trunk.global_position = _origin + _trunk_local
	if _curtain.visible:
		_curtain.global_position = _origin + _curtain_local
	_fill.light_energy = lerpf(_fill.light_energy, (1.15 if (_set_now == "forest" and t > 7.6 and t < 84.0) else (1.7 if (t > 54.5 and t < 56.96) else 0.0)), 1.0 - exp(-delta / 0.6))
	_drive_music()
	_animate_props(delta)
	if t >= DUR:
		set_process(false)
		_write_marks()
		get_tree().quit()   # eigenständige Produktion: nach dem Abspann ist Schluss


var _was_visible: Array[bool] = [false, false, false, false]


## Räumliche Prüfung: Eine Figur darf nicht mitten im Bild erscheinen (nur bei Schnitt/Weltenwechsel oder außerhalb).
func _qa_popins() -> void:
	for i in heroes.size():
		var vis := heroes[i].is_visible_in_tree()
		if vis and not _was_visible[i] and t > 0.3 and cam.is_position_in_frustum(heroes[i].global_position + Vector3.UP):
			var near_cut := false
			for m in _marks:
				if absf(float(m[0]) - t) < 0.08:
					near_cut = true
			if not near_cut:
				print("[TRAILER-QA] Figur %d erscheint mitten im Bild bei %.2f s" % [i, t])
		_was_visible[i] = vis


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
	at(time, func() -> void:
		if target is int and not (_look[i] is int and int(_look[i]) == int(target)):
			faces[i].flash_brows(0.7)   # neuer Blickkontakt: Brauen heben sich kurz
		_look[i] = target)


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


## Reaktion aus der Bibliothek des Spiels – aber ohne Symbol-Einblendungen (kein „HAHA“, „!“, Sternchen):
## Gefühle zeigen im Trailer Gesicht und Körper. Längere Überblendung, damit keine Pose springt.
func react(i: int, time: float, id: String) -> void:
	var c := heroes[i].reaction(id)
	if c == null:
		return
	at(time, func() -> void:
		var r := heroes[i]
		r.play(c.clip, 0.26, c.clip_speed, true)
		r.lock(c.hold)
		if c.squash != Vector2.ONE:
			r.squash(c.squash.x, c.squash.y, 0.45)
		if c.hop > 0.0:
			r.hop(c.hop, 0.4)
		if c.spin != 0.0:
			r.spin_around(c.spin, 0.55))
	at(time + c.hold, func() -> void:
		if heroes[i].current == c.clip and not _hold[i]:
			heroes[i].play(c.then_clip if c.then_clip != "" else "idle", 0.38))


## Gesichtsausdruck wechseln (gleitet in secs Sekunden hinüber).
func expr(i: int, time: float, name: String, secs := 0.18) -> void:
	at(time, func() -> void:
		faces[i].set_expr(name, secs)
		bodies[i].set_posture(name, maxf(secs, 0.3)))   # Haltung trägt das Gefühl mit (Brust, Kopf, Schultern)


## Lachen als Bewegungskette: Schmunzeln → Mund auf, Augen zu Sicheln, Brust und Schultern wippen → klingt aus.
## Davor muss die Figur stehen und den Auslöser ansehen (Regie); then = Ausdruck danach.
func laugh(i: int, time: float, dur := 1.4, strength := 1.0, then := "smile") -> void:
	(_laughs[i] as Array).append([time, dur, strength])
	expr(i, time - 0.14, "grin", 0.14)
	expr(i, time + 0.08, "laugh", 0.16)
	expr(i, time + dur - 0.5, then, 0.5)
	at(time, func() -> void: heroes[i].squash(1.04, 0.97, 0.3))


## Hand an einen Punkt führen: t0→t1 hin, bis t2 halten, bis t3 zurück. Ziel: Vector3 (Set-Koordinaten) oder
## Callable → Weltposition (z. B. die Schulter eines Freundes, die sich bewegt). orient: Handhaltung
## [Fingerrichtung, Handflächen-Normale] (Welt) oder Callable → Array; leer = Hand bleibt, wie die Animation sie hält.
func reach(i: int, side: String, t0: float, t1: float, t2: float, t3: float, target: Variant, orient: Variant = []) -> void:
	(_reach[i] as Array).append([side, t0, t1, t2, t3, target, orient])


## Gegenstand liegt von t0 bis t1 in der Hand der Figur.
func carry(node: Node3D, i: int, side: String, t0: float, t1: float, offset := Vector3(0, -0.06, 0.08)) -> void:
	_carry.append([node, i, side, t0, t1, offset])


## Kopf zusätzlich neigen (nicken, drehen, schief legen – rad) bzw. Atmung einstellen.
func tilt(i: int, time: float, v: Vector3) -> void:
	at(time, func() -> void: bodies[i].head_add = v)


func breath(i: int, time: float, amount: float, rate := 1.4) -> void:
	at(time, func() -> void:
		bodies[i].breath = amount
		bodies[i].breath_rate = rate)


func _bone(i: int, name: String) -> Vector3:
	return bodies[i].joint_pos(name.replace("upperarm.", "shoulder."))


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
	for k in segs.size():
		var s: Array = segs[k]
		var t0: float = s[0]
		var t1: float = s[1]
		if time < t0:
			break
		if time <= t1:
			var u := (time - t0) / maxf(t1 - t0, 0.001)
			var pre := k > 0 and _chained(segs[k - 1], s)
			var post := k + 1 < segs.size() and _chained(s, segs[k + 1])
			var e := u
			if pre and not post:
				var q := 1.0 - u
				e = 1.0 - q * q * (1.5 - 0.5 * q)   # nur ausrollen
			elif post and not pre:
				e = u * u * (1.5 - 0.5 * u)          # nur anfahren
			elif not pre and not post:
				e = u * u * u * (u * (u * 6.0 - 15.0) + 10.0)   # Smootherstep: weich an- und abfahren
			var p: Vector3 = (s[2] as Vector3).lerp(s[3], e)
			var hop: float = s[4]
			if hop > 0.0:
				p.y += hop * 4.0 * u * (1.0 - u)
			return p
		last = s[3]
	return last


## Zwei Wegstücke gehen fließend ineinander über (gleicher Zeitpunkt, gleicher Ort, ähnliche Richtung) – dann wird
## dazwischen nicht angehalten.
func _chained(a: Array, b: Array) -> bool:
	if absf(float(a[1]) - float(b[0])) > 0.02 or (a[3] as Vector3).distance_to(b[2]) > 0.06:
		return false
	var da := (a[3] as Vector3) - (a[2] as Vector3)
	var db := (b[3] as Vector3) - (b[2] as Vector3)
	da.y = 0.0
	db.y = 0.0
	return da.length() > 0.3 and db.length() > 0.3 and da.normalized().dot(db.normalized()) > 0.25


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
		_loco(i, r, spd, absf(v.y) < 2.5 or lp.y < 0.05)
	var lk = _look[i]
	var head := p + Vector3.UP * 1.7
	var want := Vector3.ZERO
	var w := 0.0
	if lk is Vector3:
		want = _origin + (lk as Vector3)
		w = 1.0
	elif lk is Node3D and is_instance_valid(lk):
		want = (lk as Node3D).global_position + Vector3.UP * 0.2
		w = 1.0
	elif lk is int:
		want = heroes[int(lk)].global_position + Vector3.UP * 1.6
		w = 1.0
	elif lk is String and String(lk) == "cam":
		want = cam.global_position   # Blick zum Zuschauer
		w = 1.0
	elif spd > 0.6 and not _hold[i]:
		# unterwegs: Blick voraus, der Kopf schweift leicht (jeder in seinem eigenen Takt)
		var fdir := flat.normalized()
		want = head + fdir * 4.0 + fdir.cross(Vector3.UP) * sin(t * 0.6 + i * 2.3) * 1.3 + Vector3.UP * (sin(t * 0.9 + i * 1.7) * 0.35 - 0.2)
		w = 0.45
	if w > 0.0:
		if _gaze_w[i] < 0.02:
			_gaze[i] = want
		_gaze[i] = _gaze[i].lerp(want, 1.0 - exp(-delta / 0.14))   # der Kopf wandert zum Ziel, statt umzuspringen
	_gaze_w[i] = lerpf(_gaze_w[i], w, 1.0 - exp(-delta / 0.2))
	if r.modifier:
		r.modifier.look_target = _gaze[i]
		r.modifier.look_weight = _gaze_w[i]
	_drive_actor(i)
	# Nachschwingen: beim Anhalten sackt die Figur kurz ein, beim Loslaufen streckt sie sich
	if not _hold[i] and lp.y < 0.05:
		if _moving[i] and spd < 0.3:
			_moving[i] = false
			r.squash(1.05, 0.96, 0.34)
		elif not _moving[i] and spd > 1.6:
			_moving[i] = true
			r.squash(0.97, 1.04, 0.24)
	# eigener Laufweg: niemand läuft wie auf Schienen
	if spd > 0.5 and lp.y < 0.05 and _set_now != "montage":
		r.global_position = p + flat.normalized().cross(Vector3.UP) * sin(t * 1.3 + i * 2.1) * 0.09 * clampf(spd / 4.0, 0.0, 1.0)


## Fortbewegung mit passender Schrittlänge: Die Abspielgeschwindigkeit folgt dem tatsächlichen Tempo, damit die
## Füße am Boden haften statt zu rutschen (das Tempo je Clip wird beim Start an der Fußbewegung vermessen).
func _loco(i: int, r: CharacterRig, spd: float, grounded: bool) -> void:
	if r.is_locked():
		return
	if not grounded:
		_air[i] = true
		r.play("jump_air", 0.14)
		return
	if _air[i]:
		_air[i] = false
		if r.has_clip("land") and spd < 3.0:
			r.play("land", 0.08, 1.4, true)
			r.lock(0.16)
			return
	var cur := r.current
	var wn: float = _nat.walk
	if spd < (0.14 if cur in ["walk", "run"] else 0.32):
		if cur != "idle_b":
			r.play("idle", 0.32)
	elif spd < wn * (1.5 if cur == "run" else 1.8):
		r.play("walk", 0.24, clampf(spd / wn, 0.45, 1.9))
	else:
		r.play("run", 0.22, clampf(spd / float(_nat.run), 0.6, 1.5))


## Tempo, bei dem der Standfuß eines Lauf-Clips am Boden stillsteht (Rückwärtsgeschwindigkeit des Fußes im Skelett).
func _stride(r: CharacterRig, clip_name: String, fallback: float) -> float:
	var fb := r.skel.find_bone("foot.l")
	var length := r.clip_length(clip_name)
	if fb < 0 or length <= 0.0 or r.anim == null:
		return fallback
	r.play(clip_name, 0.0, 1.0, true)
	var an := r.anim.get_animation(r.anim.current_animation)
	if an == null:
		return fallback
	var chain: Array[int] = []
	var bi := fb
	while bi >= 0:
		chain.append(bi)
		bi = r.skel.get_bone_parent(bi)
	var tracks := {}   # Knochen → [Positions-Spur, Rotations-Spur]
	for ti in an.get_track_count():
		var bn := String(an.track_get_path(ti)).get_slice(":", 1)
		var b := r.skel.find_bone(bn)
		if b in chain:
			if not tracks.has(b):
				tracks[b] = [-1, -1]
			if an.track_get_type(ti) == Animation.TYPE_POSITION_3D:
				tracks[b][0] = ti
			elif an.track_get_type(ti) == Animation.TYPE_ROTATION_3D:
				tracks[b][1] = ti
	var vs: Array[float] = []
	var prev := 0.0
	for k in 41:
		var tm := length * k / 40.0
		var x := Transform3D.IDENTITY   # Fußpose direkt aus den Spuren des Clips
		for b in chain:
			var rest := r.skel.get_bone_rest(b)
			var tr: Array = tracks.get(b, [-1, -1])
			var pos: Vector3 = an.position_track_interpolate(tr[0], tm) if int(tr[0]) >= 0 else rest.origin
			var rot: Quaternion = an.rotation_track_interpolate(tr[1], tm) if int(tr[1]) >= 0 else rest.basis.get_rotation_quaternion()
			x = Transform3D(Basis(rot), pos) * x
		var z := x.origin.z
		if k > 0:
			vs.append((prev - z) / (length / 40.0))
		prev = z
	vs.sort()
	var v := vs[int(vs.size() * 0.78)] * r.skel.global_transform.basis.get_scale().z
	return v if v > 0.4 and v < 9.0 else fallback


## Mimik und Körper-Ebene je Bild: Augen folgen dem Blickziel, Lach-Hüllkurve, Hände an ihre Ziele.
func _drive_actor(i: int) -> void:
	var fc = faces[i]
	var bd = bodies[i]
	var loc: Vector3 = (fc as Node3D).global_transform.affine_inverse() * _gaze[i]
	var gz := Vector2(clampf(loc.x / maxf(loc.z, 0.4) * 1.3, -1, 1), clampf((loc.y - 1.6) / maxf(loc.z, 0.4) * 1.3, -1, 1))
	fc.gaze = fc.gaze.lerp(gz * _gaze_w[i], 0.25)
	var lv := 0.0
	for l in _laughs[i]:
		var u := t - float(l[0])
		if u > 0.0 and u < float(l[1]):
			lv = maxf(lv, float(l[2]) * smoothstep(0.0, 0.32, u) * (1.0 - smoothstep(float(l[1]) - 0.65, float(l[1]), u)))
	bd.laugh = lv
	fc.laugh = lv
	fc.laugh_phase = bd.laugh_phase
	# Blick: Oberkörper und Hüfte drehen mit (Kopf bleibt auf dem Ziel) – Ausdruck, Haltung und Blick gemeinsam
	bd.attend_target = _gaze[i]
	bd.attend_w = _gaze_w[i]
	# Fußanker nur beim normalen Stehen/Gehen/Laufen auf dem Boden (nicht in Posen, Sprüngen, im Kart)
	var r := heroes[i]
	bd.grounded = not _hold[i] and not r.is_locked() and _set_now != "race" and r.current in ["idle", "idle_b", "walk", "run"] \
		and r.global_position.y - _origin.y < 0.06
	var hw := {"l": 0.0, "r": 0.0}
	var hd := {"l": [], "r": []}
	for rc in _reach[i]:
		if t < float(rc[1]) or t > float(rc[4]):
			continue
		var w := smoothstep(float(rc[1]), float(rc[2]), t) * (1.0 - smoothstep(float(rc[3]), float(rc[4]), t))
		var sd := String(rc[0])
		if w >= float(hw[sd]):
			hw[sd] = w
			var tg = rc[5]
			bd.hand_t[sd] = (tg as Callable).call() if tg is Callable else _origin + (tg as Vector3)
			var o: Variant = rc[6]
			hd[sd] = (o as Callable).call() if o is Callable else o
	bd.hand_w = hw
	bd.hand_dir = hd
	bd.hand_assist = {"l": 0.6, "r": 0.6}   # zu ferne Ziele: etwas hinlehnen, aber die großen Köpfe bleiben frei


func _drive_carry() -> void:
	for c in _carry:
		var n: Node3D = c[0]
		if is_instance_valid(n) and t >= float(c[3]) and t <= float(c[4]):
			var i: int = c[1]
			var sd := String(c[2])
			var hd: Array = bodies[i].hand_dir.get(sd, [])
			if hd.size() == 2 and float(bodies[i].hand_w.get(sd, 0.0)) > 0.5:
				var ax: Array = bodies[i].hand_axes(sd)   # ausgerichtete Hand: Gegenstand liegt auf der Handfläche
				n.global_position = _bone(i, "hand." + sd) + (ax[1] as Vector3) * 0.07 + (ax[0] as Vector3) * 0.04
			else:
				n.global_position = _bone(i, "hand." + sd) + heroes[i].global_basis * (c[5] as Vector3)


func _drive_camera() -> void:
	if _cam_keys.is_empty():
		return
	if _set_now == "race":
		_race_camera()
		return
	var c := _cam_eval(t)
	# ein Hauch Handkamera: die Kamera atmet (Zentimeter, nie spürbar als Wackeln)
	c[0] = (c[0] as Vector3) + Vector3(sin(t * 0.53) * 0.02, sin(t * 0.71 + 1.3) * 0.014, 0.0)
	c[1] = (c[1] as Vector3) + Vector3(sin(t * 0.37 + 2.0) * 0.03, sin(t * 0.47) * 0.018, 0.0)
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
	_water = _rect(root, Color(0.5, 0.78, 1.0), 0.0)
	var wg := Gradient.new()
	wg.set_color(0, Color(0.92, 0.98, 1.0, 0.75))
	wg.set_color(1, Color(0.1, 0.38, 0.7, 0.8))
	wg.add_point(0.45, Color(0.55, 0.85, 1.0, 0.35))
	var gt := GradientTexture2D.new()
	gt.gradient = wg
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var wr := TextureRect.new()
	wr.texture = gt
	wr.stretch_mode = TextureRect.STRETCH_SCALE
	wr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wr.set_anchors_preset(Control.PRESET_FULL_RECT)
	_water.add_child(wr)
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
	_caption = _label(root, "", 40, Color(1, 1, 1, 0.95), 10, 0.8)   # dezente Einblendung in der Montage
	for l in [_title, _slogan, _slogan2, _cta, _bigword, _caption]:
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
	for preset in ["forest_night", "day", "sunset", "volcano"]:
		var holder := Node3D.new()
		var we := WorldKit.env(holder, preset, true)
		_envs[preset] = holder
		_env_we[preset] = we
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
	_fill = OmniLight3D.new()   # weiches Fülllicht von der Kamera: Gesichter bleiben im Nachtwald lesbar
	_fill.light_color = Color(0.82, 0.88, 1.0)
	_fill.light_energy = 0.0
	_fill.omni_range = 11.0
	_fill.omni_attenuation = 0.6
	_fill.shadow_enabled = false
	cam.add_child(_fill)
	_fill.position = Vector3(0.6, 0.5, 0.2)
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
	_curtain = _build_curtain()
	_sets["forest"] = _build_forest(Vector3(0, 0, 0))
	_sets["meadow"] = _build_meadow(Vector3(0, 0, 600))
	_sets["beach"] = _build_beach(Vector3(0, 0, 1800))
	_sets["montage"] = _build_montage(Vector3(0, 0, 2600))
	_sets["board"] = _build_board(Vector3(0, 0, 3600))
	_sets["race"] = _build_race()
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
		var blocked := false
		for av in _avoid:
			if Vector2(p.x - (av[0] as Vector3).x, p.z - (av[0] as Vector3).z).length() < float(av[1]):
				blocked = true
		if blocked:
			continue   # Lichtung, Wasserfall, Sitzplätze: nichts wächst in Figuren oder Requisiten hinein
		var key_i := _rng.randi() % keys.size()
		var rot := _rng.randf() * 360.0
		var sc := _rng.randf_range(scl.x, scl.y)
		if p.z > 5.0:
			continue   # Kameraseite: nichts, was dicht vor der Linse durchs Bild wischt
		if s.name == "Forest" and p.x > -17.0 and p.x < 7.0 and p.z > -27.5 and p.z < -8.0:
			continue   # Lagerfeuer-Lichtung samt Kamerablick (Akt 5) frei
		if s.name == "Forest" and p.x > 8.5 and p.x < 23.5 and p.z > -13.5 and p.z < -6.0:
			continue   # Felswand am Wasserfall: keine Bäume hindurch
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
	_shroom_lights.append(l)


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
	# Lichtung, Wasserfall, Hügel, Stein und Stolper-Ast bleiben frei – nichts wächst in Figuren oder Requisiten
	_avoid = [[Vector3(-6, 0, -19.4), 6.0], [Vector3(14, 0, -8), 7.0], [Vector3(22.5, 0, -1.6), 3.8], [Vector3(31, 0, -2.6), 2.4], [Vector3(8.6, 0, 0), 1.6]]
	_strip(s, Color("#2f5a35"), Color("#5a4a36"), -20, 60)
	_scatter(s, ["nat/tree_oak", "nat/tree_fat", "nat/tree_pine", "nat/tree_default", "plat/tree"], 64, -30, 70, -40, -7, Vector2(2.6, 4.2))
	_scatter(s, ["nat/bush", "nat/flower_purple", "nat/mushroom", "nat/rock_small", "nat/stump"], 64, -20, 60, -9, 9, Vector2(1.2, 1.8))
	_scatter(s, ["nat/flower_yellow", "nat/flower_red"], 14, 34, 46, -8, 8, Vector2(1.2, 1.8))   # die Wiese kündigt sich an
	for k in 16:
		var x := -12.0 + k * 4.4
		_glow_mushroom(s, Vector3(x, 0, -3.6 - (k % 3) * 1.2), [Color("#d9a8ff"), Color("#8fe8ff"), Color("#ffb3e6")][k % 3])
	_fireflies(s, Vector3(20, 2.0, -8), Vector3(52, 2.5, 5.5))   # nur hinter dem Weg – nie direkt vor der Linse
	# Wasserfall am Weg (Akt 2): Felswand, Wasser mit eigenem Fließ-Shader (keine Wellen-Verformung → kein
	# Flimmern vor der Wand), Becken, Gischt und Nebel
	WorldKit.box(s, Vector3(12.0, 10.6, 2.4), Vector3(14.0, 5.3, -9.9), Color("#3d4b52"), false)
	WorldKit.box(s, Vector3(13.0, 0.8, 3.2), Vector3(14.0, 10.7, -9.9), Color("#2f5a35"), false)
	var wf := MeshInstance3D.new()
	var wq := QuadMesh.new()
	wq.size = Vector2(4.2, 10.4)
	wq.material = _fall_material()
	wf.mesh = wq
	wf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.add_child(wf)
	wf.position = Vector3(14.0, 5.2, -8.3)
	for p in [Vector3(11.2, 0, -8.6), Vector3(16.8, 0, -8.4), Vector3(14, 9.6, -8.9)]:
		WorldKit.place(s, "nat/rock_large", p, _rng.randf() * 360.0, 2.6)
	for e in [[Vector3(9.4, 0, -8.9), 3.4], [Vector3(18.7, 0, -8.8), 3.6], [Vector3(10.4, 4.4, -9.0), 2.6], [Vector3(17.9, 5.0, -9.0), 2.8], [Vector3(11.0, 8.2, -9.1), 2.2], [Vector3(17.2, 8.6, -9.1), 2.2], [Vector3(8.6, 0, -10.6), 4.2], [Vector3(19.6, 0, -10.6), 4.2]]:
		WorldKit.place(s, "nat/rock_tall", e[0], _rng.randf() * 360.0, float(e[1]))   # die Wand ist Fels, kein glatter Block
	for p in [Vector3(12.0, 10.9, -9.4), Vector3(15.6, 10.9, -9.6), Vector3(9.6, 10.9, -10.0)]:
		WorldKit.place(s, "nat/bush", p, _rng.randf() * 360.0, 2.2)
	for p in [Vector3(10.6, 0, -6.4), Vector3(17.4, 0, -6.6), Vector3(12.0, 0, -4.3), Vector3(16.2, 0, -4.2)]:
		WorldKit.place(s, "nat/bush", p, _rng.randf() * 360.0, 1.5)
	WorldKit.water(s, Vector2(6.6, 3.6), 0.05, Color(0.1, 0.35, 0.55), Color(0.55, 0.85, 1.0)).position = Vector3(14.0, 0.05, -6.3)
	var spray := FX.emitter({"amount": 70, "life": 1.4, "one_shot": false, "explosive": 0.0, "spread": 50.0, "dir": Vector3.UP, "vel_min": 0.8,
		"vel_max": 2.0, "gravity": Vector3(0, -2.5, 0), "size": 0.3, "color": Color(1, 1, 1, 0.5), "box": Vector3(3.8, 0.2, 0.6)})
	s.add_child(spray)
	spray.position = Vector3(14.0, 0.3, -7.6)
	spray.emitting = true
	var mist := FX.emitter({"amount": 26, "life": 3.6, "one_shot": false, "explosive": 0.0, "spread": 180.0, "vel_min": 0.15, "vel_max": 0.5,
		"gravity": Vector3(0, 0.12, 0), "size": 1.5, "color": Color(0.85, 0.93, 1.0, 0.14), "box": Vector3(4.5, 0.6, 2.0)})
	s.add_child(mist)
	mist.position = Vector3(14.0, 0.9, -6.2)
	mist.emitting = true
	mist.preprocess = 3.0
	# Ast zum Stolpern · Hügel, auf dem die Magierin wartet · Stein, auf dem der Träumer sitzt
	WorldKit.place(s, "nat/log", Vector3(8.6, 0, 0.2), 90.0, 0.45)
	WorldKit.cylinder(s, 3.0, 0.5, Vector3(22.5, 0.0, -1.6), Color("#3a6a3e"), false)
	_hill_y = 0.25
	var stone := WorldKit.place(s, "nat/rock_large", Vector3(31.0, 0, -2.7), 20.0, 1.1)
	_stone_y = _top_y(stone) - o.y
	WorldKit.place(s, "nat/flower_red", Vector3(32.1, 0, -1.9), 0.0, 1.6)
	# Lagerfeuer-Lichtung (Akt 5): Feuer, davor eine lange Bank aus Stämmen – alle sitzen nebeneinander
	WorldKit.place(s, "nat/campfire", Vector3(-6.0, 0, -18.0), 0.0, 1.6)
	var ll := maxf(Assets.model_aabb("nat/log").size.x, Assets.model_aabb("nat/log").size.z) * 1.3
	var along_x := Assets.model_aabb("nat/log").size.x >= Assets.model_aabb("nat/log").size.z
	var n_logs := int(ceil(3.4 / maxf(ll, 0.5)))
	for k in n_logs:
		WorldKit.place(s, "nat/log", Vector3(-6.35 + (k - (n_logs - 1) * 0.5) * ll * 0.98, 0, -20.05), 0.0 if along_x else 90.0, 1.3)
	_snack = WorldKit.place(s, "hol/cookie", Vector3(-5.4, 1.0, -19.8), 0.0, 1.0)
	var ca := Assets.model_aabb("hol/cookie").size
	_snack.scale = Vector3.ONE * (0.24 / maxf(maxf(ca.x, ca.z), 0.01))
	_snack.rotation.x = 1.2
	_snack.visible = false
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.6, 0.28)
	_fire_light.light_energy = 3.0
	_fire_light.omni_range = 9.0
	_fire_light.position = Vector3(-6.0, 1.2, -18.0)
	s.add_child(_fire_light)
	for e in [[0.34, 1.0, Color(0.95, 0.32, 0.06, 0.42)], [0.24, 0.76, Color(1.0, 0.55, 0.12, 0.42)], [0.12, 0.46, Color(1.0, 0.8, 0.35, 0.45)]]:
		var fl := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = float(e[0])
		cm.height = float(e[1])
		cm.radial_segments = 10
		cm.rings = 1
		cm.set_meta("gfx_tuned", true)
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.albedo_color = e[2]
		fm.no_depth_test = false
		cm.material = fm
		fl.mesh = cm
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.add_child(fl)
		fl.position = Vector3(-6.0, 0.22 + float(e[1]) * 0.5, -18.0)
		_flames.append(fl)
	var fire := FX.emitter({"amount": 22, "life": 0.8, "one_shot": false, "explosive": 0.0, "spread": 10.0, "dir": Vector3.UP, "vel_min": 0.6,
		"vel_max": 1.4, "gravity": Vector3(0, 0.6, 0), "size": 0.16, "additive": true, "color": Color(1.0, 0.62, 0.22, 0.95), "box": Vector3(0.5, 0.1, 0.5)})
	s.add_child(fire)
	fire.position = Vector3(-6.0, 0.6, -18.0)
	fire.emitting = true
	_scatter(s, ["nat/tree_oak", "nat/tree_fat", "nat/tree_pine"], 26, -30, 18, -36, -25, Vector2(2.8, 4.0))
	_fireflies(s, Vector3(-6, 3.4, -27.5), Vector3(20, 2.6, 3.5), 24)   # hinter der Bank zwischen den Bäumen, nicht vor den Gesichtern
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
	_avoid = []
	return s


func _build_meadow(o: Vector3) -> Node3D:
	var s := Node3D.new()
	s.name = "Meadow"
	add_child(s)
	s.position = o
	_avoid = [[Vector3(43.2, 0, -2.8), 2.8]]
	_strip(s, Color("#6fbf55"), Color("#d8c48a"), 16, 72)
	_scatter(s, ["nat/tree_oak", "nat/tree_default", "plat/tree", "nat/tree_fat"], 28, 10, 62, -40, -8, Vector2(2.4, 3.6))
	_scatter(s, ["nat/flower_yellow", "nat/flower_purple", "nat/flower_red", "nat/bush"], 110, 22, 60, -9, 8, Vector2(1.2, 2.0))
	_scatter(s, ["nat/mushroom", "nat/stump"], 8, 30, 40, -9, 8, Vector2(1.2, 1.8))   # der Wald klingt noch nach
	# Riesenblume, vor der die Magierin staunend stehen bleibt
	var flower := WorldKit.place(s, "nat/flower_purple", Vector3(43.2, 0, -2.8), 0.0, 10.0)
	flower.name = "GiantFlower"
	var bf := FX.emitter({"amount": 18, "life": 4.0, "one_shot": false, "explosive": 0.0, "spread": 180.0, "vel_min": 0.2, "vel_max": 0.6,
		"gravity": Vector3.ZERO, "size": 0.25, "color": Color(1.0, 0.7, 0.9, 0.95), "box": Vector3(5, 2, 3)})
	s.add_child(bf)
	bf.position = Vector3(43.2, 1.8, -2.8)
	bf.emitting = true
	# Übergang zum Strand: der Boden wird sandig, die ersten Palmen stehen schon am Ende der Wiese
	_gradient_floor(s, 47.0, 58.0, 0.075, Color("#6fbf55"), Color("#e9cf96"))
	WorldKit.box(s, Vector3(40.0, 0.06, 60.0), Vector3(78.0, 0.045, -8.0), Color("#e9cf96"), false)
	for p in [Vector3(53.0, 0, -7.5), Vector3(57.5, 0, -9.0), Vector3(60.0, 0, -6.5)]:
		WorldKit.place(s, "pirate/palm", p, _rng.randf() * 360.0, 1.0)
	_avoid = []
	return s


func _build_beach(o: Vector3) -> Node3D:
	var s := Node3D.new()
	s.name = "Beach"
	add_child(s)
	s.position = o
	# Sand geht allmählich in dunkles Vulkangestein über (Landschaftswechsel ohne Schnitt)
	WorldKit.box(s, Vector3(170, 1, 120), Vector3(75, -0.5, -20), Color("#e9cf96"), false)
	_gradient_floor(s, 52.0, 62.0, 0.05, Color("#e9cf96"), Color("#3a2f33"))
	WorldKit.box(s, Vector3(90, 0.06, 60.0), Vector3(107.0, 0.02, -8.0), Color("#3a2f33"), false)
	WorldKit.water(s, Vector2(170, 70), -0.25, Color(0.08, 0.38, 0.6), Color(0.45, 0.85, 0.9)).position = Vector3(70, -0.25, -60)
	_scatter(s, ["pirate/palm", "pirate/palm_bend"], 14, 34, 56, -26, -6, Vector2(0.9, 1.2))
	_scatter(s, ["nat/bush", "nat/flower_yellow"], 12, 40, 50, -9, 8, Vector2(1.2, 1.8))   # letzte Wiesenblumen im Sand
	_scatter(s, ["nat/rock_tall", "nat/rock_large"], 16, 60, 92, -30, -7, Vector2(1.6, 2.6))
	# Lava-Arena mit dem Boss (Akt 4)
	var lava := WorldKit.lava(s, Vector2(40, 24), 0.05, Vector2(0.1, 0.0))
	lava.position = Vector3(80, 0.05, -26)
	_boss = BossModel.create("ignis")
	s.add_child(_boss)
	_boss.position = Vector3(70.0, 0, -11.0)
	_boss.rotation.y = deg_to_rad(-20)
	_boss.scale = Vector3.ONE * BOSS_SCALE   # riesig gegenüber der kleinen Gruppe
	_boss.visible = false
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.45, 0.15)
	glow.light_energy = 2.4
	glow.omni_range = 26.0
	glow.position = Vector3(74, 3, -18)
	s.add_child(glow)
	var embers := FX.emitter({"amount": 80, "life": 4.0, "one_shot": false, "explosive": 0.0, "spread": 30.0, "dir": Vector3.UP, "vel_min": 0.4,
		"vel_max": 1.4, "gravity": Vector3(0, 0.3, 0), "size": 0.14, "additive": true, "color": Color(1.0, 0.55, 0.2, 0.9), "box": Vector3(30, 1, 16)})
	s.add_child(embers)
	embers.position = Vector3(76, 0.5, -16)
	embers.emitting = true
	return s


## Bühnen der Minispiele in der Montage: Sumo-Ring über dem Wasser · Zielsprint · Boss-Arena. Dazu die Karts.
func _build_montage(o: Vector3) -> Node3D:
	var s := Node3D.new()
	s.name = "Montage"
	add_child(s)
	s.position = o
	WorldKit.backdrop(s, "meadow", Color("#7fc96a"), -0.75, Vector3(60, 0, 0))   # Horizont: Hügel, Wolken, Dunst
	WorldKit.box(s, Vector3(260, 1, 200), Vector3(160, -0.5, 0), Color("#7fc96a"), false)   # Land ab x = 30
	# 0 Sumo-Ring: runde Plattform mitten im Wasser (wer runterfällt, wird nass)
	WorldKit.water(s, Vector2(90, 120), -0.35, Color(0.1, 0.4, 0.65), Color(0.5, 0.85, 1.0)).position = Vector3(-15, -0.35, 0)
	WorldKit.cylinder(s, 4.6, 1.2, Vector3(0, 0.0, 0), Color("#ffb347"), false)
	WorldKit.cylinder(s, 4.0, 1.22, Vector3(0, 0.0, 0), Color("#ff6f91"), false)
	MgKit.ring(s, 2.0, 0.16, Color.WHITE, 0.4).position = Vector3(0, 0.625, 0)
	for a in 8:
		var bp := Vector3(cos(TAU * a / 8.0), 0, sin(TAU * a / 8.0)) * 7.4
		WorldKit.place(s, "kp/flag_red" if a % 2 == 0 else "kp/flag_blue", bp + Vector3(0, -0.3, 0), 0.0, 1.3)
	# 1 Zielsprint: vier Sandbahnen, Zielbogen, Fahnen
	for z in 4:
		WorldKit.box(s, Vector3(26.0, 0.04, 1.3), Vector3(51.0, 0.02, -2.25 + z * 1.5), Color("#dba36a") if z % 2 == 0 else Color("#cf955c"), false)
	for z in 5:
		WorldKit.box(s, Vector3(26.0, 0.05, 0.08), Vector3(51.0, 0.03, -3.0 + z * 1.5), Color.WHITE, false)
	for z in 8:
		for c in 2:
			WorldKit.box(s, Vector3(0.38, 0.05, 0.75), Vector3(59.8 + c * 0.38, 0.045, -2.62 + z * 0.75), Color.WHITE if (z + c) % 2 == 0 else Color.BLACK, false)
	WorldKit.place(s, "kp/finish_wide", Vector3(60.0, 0, 0.0), 90.0, 1.0)
	for e in [[Vector3(58.5, 0, -4.4), "kp/flag_red"], [Vector3(58.5, 0, 4.4), "kp/flag_blue"], [Vector3(53.0, 0, -4.4), "kp/flag_blue"], [Vector3(47.0, 0, -4.4), "kp/flag_red"]]:
		WorldKit.place(s, String(e[1]), e[0], 90.0, 1.4)
	# 2 Boss-Arena: Steinscheibe am Lavasee
	WorldKit.lava(s, Vector2(34, 26), 0.04, Vector2(0.08, 0.0)).position = Vector3(120, 0.04, -15)
	WorldKit.cylinder(s, 7.0, 0.4, Vector3(120, 0.2, 2), Color("#4a3a3e"), false)
	var boss2 := BossModel.create("ignis")
	s.add_child(boss2)
	boss2.position = Vector3(120.0, 0, -8.0)
	boss2.name = "Boss2"
	var hk := ["hero/knight", "hero/mage", "hero/barbarian", "hero/ranger"]
	var kk := ["kart/oopi", "kart/ooli", "kart/oobi", "kart/oodi"]
	for i in 3:
		var kv := KartVisual.new()
		s.add_child(kv)
		kv.setup(kk[i], hk[i], i, 2.0)
		kv.visible = false
		_karts.append(kv)
	_scatter(s, ["nat/tree_oak", "nat/tree_default", "plat/tree"], 40, 30, 200, -60, -16, Vector2(2.4, 3.4))
	return s


## Das echte Spielbrett „Wuschel-Wiesen“ – gebaut vom Brett-Baukasten des Spiels (nur gelesen): Felder, Wege,
## Kulisse, Stern. Dazu der Würfelblock, wie er im Spiel über dem Kopf schwebt.
func _build_board(o: Vector3) -> Node3D:
	var s := Node3D.new()
	s.name = "BoardSet"
	add_child(s)
	s.position = o
	var def := BoardDefs.get_def("meadow")
	_board = BoardBuilder.new()
	_board.build(s, "meadow", BoardDefs.build_graph(def))
	WorldKit.backdrop(s, "meadow", Color("#86d06a"), -0.56)
	for n in _board.space_nodes:
		_bp.append(n.position + Vector3.UP * 0.45)
	_board.star_node.visible = true
	_board.star_node.position = _bp[21] + Vector3.UP * 2.5
	_dice = Node3D.new()
	s.add_child(_dice)
	Assets.spawn("bg/d6", _dice, Vector3.ZERO, 0.0, 2.0).name = "Die"
	var num := Label3D.new()
	num.name = "Num"
	num.font = UI.title_font()
	num.font_size = 150
	num.outline_size = 32
	num.outline_modulate = Color(0.1, 0.03, 0.2)
	num.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	num.no_depth_test = true
	num.pixel_size = 0.006
	_dice.add_child(num)
	_dice.visible = false
	return s


## Weicher Farbverlauf im Boden entlang x (ein Mesh mit Eckfarben – keine sichtbaren Streifen).
func _gradient_floor(s: Node3D, x0: float, x1: float, y: float, c0: Color, c1: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [[x0, -38.0, c0], [x1, -38.0, c1], [x1, 22.0, c1], [x0, 22.0, c0]]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_color(pts[idx][2])
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(float(pts[idx][0]), y, float(pts[idx][1])))
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.add_child(mi)


## Fließendes Wasser für Wasserfälle (ein gemeinsames Material): laufende Schlieren, deckend, ohne Verformung.
func _fall_material() -> ShaderMaterial:
	if _fall_mat == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
	float x = UV.x * 30.0;
	float y = UV.y * 4.0 - TIME * 1.5;
	float a = sin(x + sin(y * 2.0 + x * 0.31) * 1.3) * 0.5 + 0.5;
	float b = sin(x * 2.7 + y * 5.0) * 0.5 + 0.5;
	float f = smoothstep(0.5, 1.0, a * 0.7 + b * 0.3);
	vec3 deep = mix(vec3(0.13, 0.38, 0.66), vec3(0.24, 0.55, 0.82), UV.y);
	vec3 foam = vec3(0.78, 0.92, 1.0);
	ALBEDO = mix(deep, foam, clamp(f * 0.6 + smoothstep(0.88, 1.0, UV.y) * 0.5, 0.0, 1.0));
}"""
		_fall_mat = ShaderMaterial.new()
		_fall_mat.shader = sh
	return _fall_mat


## Oberkante einer Requisite in Weltkoordinaten (damit niemand über einem Stein schwebt oder darin versinkt).
func _top_y(n: Node3D) -> float:
	var top := -INF
	for mi in Assets.find_meshes(n):
		var m := mi as MeshInstance3D
		var bb := m.global_transform * m.get_aabb()
		top = maxf(top, bb.end.y)
	return top if top > -INF else n.global_position.y


func _fwd(i: int) -> Vector3:
	return -heroes[i].global_basis.z.normalized()


## Punkt relativ zur Figur: nach rechts, nach oben, nach vorn (Meter).
func _rel(i: int, right: float, up: float, fwd: float) -> Vector3:
	var b := heroes[i].global_basis
	return heroes[i].global_position + b.x.normalized() * right + Vector3.UP * up - b.z.normalized() * fwd


## Die Schulter von Figur j, die näher an Figur i liegt (zum Antippen, Festhalten).
func _near_shoulder(j: int, i: int) -> Vector3:
	var l := _bone(j, "upperarm.l")
	var r := _bone(j, "upperarm.r")
	var p := heroes[i].global_position + Vector3.UP
	return l if l.distance_to(p) < r.distance_to(p) else r


func _build_cast() -> void:
	for k in ["hero/knight", "hero/mage", "hero/barbarian", "hero/ranger"]:
		var r := CharacterRig.new()
		r.set_meta("gfx_lod", 0)   # Darsteller nie ins Animations-LOD der Spiel-Grafik (immer volle Bildrate, Kopf-Blick an)
		add_child(r)
		r.setup(k, -1, 0.95)
		r.play("idle")
		r.visible = false
		heroes.append(r)
		# Character Framework (eine zentrale Umsetzung für Spiel-Labor und Trailer): Rig-Profil automatisch erkannt
		var cfg := LumosActorConfig.detect(r)
		cfg.ground_mask = 0      # Boden = Standhöhe der Figur (Callable unten) – keine Raycasts gegen Kulissen
		cfg.lod = false          # Film: immer volle Qualität
		cfg.attention = 0.42     # beim Ansehen dreht der Oberkörper deutlich mit
		var body := LumosBody.new()
		r.skel.add_child(body)   # nach dem Slapstick-Modifier des Spiels → wird zuletzt angewandt
		body.bind(r.skel, cfg)
		body.ground = func(_p: Vector3) -> float: return r.global_position.y
		body.grounded = false
		bodies.append(body)
		var fc := LumosFace.new()
		fc.feature_scale = cfg.feature_scale
		if not fc.setup(r):
			push_error("TRAILER: kein Gesicht für " + k)
		faces.append(fc)
	_nat.walk = _stride(heroes[0], "walk", 1.6)
	_nat.run = _stride(heroes[0], "run", 4.6)
	heroes[0].play("idle", 0.0, 1.0, true)
	print("[TRAILER] Schritt-Tempo: Gehen %.2f m/s · Laufen %.2f m/s" % [_nat.walk, _nat.run])
	# Glühwürmchen (Nasen-Gag) und Schmetterling
	_firefly = _glowbug(Color(1.0, 0.95, 0.5), 0.09)
	_butterfly = Node3D.new()
	add_child(_butterfly)
	var wing_m := WorldKit.mat(Color("#6fc8f0"), 0.5, 0.35)
	wing_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for sd in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.name = "WingL" if sd < 0 else "WingR"
		_butterfly.add_child(hinge)
		for part in [[0.07, Vector3(0.065, 0, -0.02)], [0.05, Vector3(0.05, 0, 0.06)]]:   # Vorder- und Hinterflügel
			var w := MeshInstance3D.new()
			var sp := SphereMesh.new()
			sp.radius = float(part[0])
			sp.height = float(part[0]) * 2.0
			sp.radial_segments = 10
			sp.rings = 5
			sp.material = wing_m
			w.mesh = sp
			w.scale = Vector3(1.0, 0.06, 0.8)
			w.position = (part[1] as Vector3) * Vector3(sd, 1, 1)
			w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			hinge.add_child(w)
	var body_m := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.012
	cap.height = 0.11
	cap.material = WorldKit.mat(Color("#2b2233"), 0.8)
	body_m.mesh = cap
	body_m.rotation.x = PI * 0.5
	_butterfly.add_child(body_m)
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
		if p.contains("hurry"):   # die Montage ist einen Takt länger als das Stück – nahtlos weiterlaufen lassen
			var lp := (a.stream as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
			lp.loop = true
			a.stream = lp
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
	var end_m := MONTAGE_T0 + 11.0 * 4.0 * BEAT
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


## Mondlicht-Wald zu Beginn: alles ist schon da, aber kühl und gedämpft; die Leuchtpilze sind aus.
func _dim_forest() -> void:
	_sets.forest.visible = true
	_use_env("forest_night")
	var we: WorldEnvironment = _env_we["forest_night"]
	var env := we.environment
	var sun := we.get_meta("sun") as DirectionalLight3D
	we.set_meta("full", [env.ambient_light_energy, env.background_energy_multiplier, env.fog_light_energy, sun.light_energy])
	env.ambient_light_energy *= 0.3
	env.background_energy_multiplier *= 0.35
	env.fog_light_energy *= 0.3
	sun.light_energy *= 0.22
	for l in _shroom_lights:
		l.light_energy = 0.0


## Der Stern weckt den Wald: Himmel, Mond- und Umgebungslicht blenden vom Mondlicht auf volle Stärke, die
## Leuchtpilze gehen der Reihe nach an – je weiter weg, desto später.
func _reveal_forest() -> void:
	_sets.forest.visible = true
	_use_env("forest_night")
	var we: WorldEnvironment = _env_we["forest_night"]
	var env := we.environment
	var sun := we.get_meta("sun") as DirectionalLight3D
	var full: Array = we.get_meta("full", [env.ambient_light_energy, env.background_energy_multiplier, env.fog_light_energy, sun.light_energy])
	var tw := create_tween().set_parallel()
	tw.tween_property(env, "ambient_light_energy", float(full[0]), 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(env, "background_energy_multiplier", float(full[1]), 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(env, "fog_light_energy", float(full[2]), 2.8)
	tw.tween_property(sun, "light_energy", float(full[3]), 2.6)
	for l in _shroom_lights:
		var d := l.global_position.distance_to(_origin + Vector3(2.0, 1.0, 0.0))
		l.light_energy = 0.0
		var t2 := l.create_tween()
		t2.tween_interval(0.12 + d * 0.085)
		t2.tween_property(l, "light_energy", 0.9, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Akt 1 – Ein kleiner Stern (0–15 s) ----------------------------------------------------------------------
## Der Wald liegt von Anfang an im kühlen, gedämpften Mondlicht (kein schwarzes Nichts); der Stern erscheint nach
## gut zwei Sekunden, weicht einmal kichernd aus und weckt beim Berühren die Welt – danach bleibt Zeit zum Staunen.
func _act1() -> void:
	var A := 0
	var star := func() -> Vector3: return _star.global_position
	at(0.0, func() -> void:
		heroes[A].visible = true
		var rim := OmniLight3D.new()   # Mondlicht von schräg hinten: die Figur hebt sich vom dunklen Wald ab
		rim.name = "VoidRim"
		rim.light_color = Color(0.6, 0.7, 1.0)
		rim.light_energy = 1.7
		rim.omni_range = 6.0
		rim.shadow_enabled = false
		heroes[A].add_child(rim)
		rim.position = Vector3(0.7, 2.3, 1.9)
		_letterbox(0.1, 0.01)
		_fade(_black, 0.0, 1.4))
	# Allein im Mondlicht: zögernde Schritte, der Blick sucht
	expr(A, 0.0, "worried", 0.0)
	breath(A, 0.0, 0.55)
	go(A, 0.3, 2.3, Vector3(-3.4, 0, 0), Vector3(-1.4, 0, 0))
	look(A, 0.5, Vector3(-4.0, 1.4, 3.0))
	look(A, 1.2, Vector3(1.0, 1.7, -3.0))
	look(A, 1.9, Vector3(2.0, 1.3, 1.5))
	key(0.0, Vector3(-3.7, 1.65, 6.2), Vector3(-2.9, 1.2, 0.0), 38.0)
	key(2.3, Vector3(-1.0, 1.6, 5.0), Vector3(-0.7, 1.25, 0.0), 36.0)
	face(A, 2.3, Vector3(1, 0, 0))
	at(2.4, func() -> void:
		_star.visible = true
		_star.scale = Vector3.ONE * 0.01
		create_tween().tween_property(_star, "scale", Vector3.ONE * 0.75, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		create_tween().tween_property(_star_light, "light_energy", 2.6, 0.8)
		Audio.sfx("sparkle_up", null, -4.0, 1.1, 0.0))
	# Schreck → Neugier: Kopf schief, vorsichtig näher
	look(A, 2.5, Vector3(1.2, 1.55, 0))
	expr(A, 2.52, "surprised", 0.1)
	at(2.55, func() -> void: heroes[A].squash(0.94, 1.08, 0.3))
	expr(A, 3.1, "curious", 0.35)
	tilt(A, 3.1, Vector3(0, 0, 0.22))
	go(A, 3.3, 4.4, Vector3(-1.4, 0, 0), Vector3(0.25, 0, 0))
	key(3.7, Vector3(1.5, 1.6, 4.3), Vector3(0.6, 1.38, 0.0), 36.0)
	# Die Hand streckt sich aus – der Stern weicht kichernd aus, er muss selbst lachen
	reach(A, "r", 4.4, 4.82, 4.9, 5.4, star)
	at(4.85, func() -> void:
		create_tween().tween_property(_star, "position:x", 2.05, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Audio.sfx("pluck", null, -6.0, 1.4, 0.0))
	look(A, 4.9, Vector3(2.05, 1.55, 0))
	expr(A, 4.9, "surprised", 0.1)
	tilt(A, 5.25, Vector3.ZERO)
	laugh(A, 5.3, 0.75, 0.55, "smile")
	go(A, 5.6, 6.4, Vector3(0.25, 0, 0), Vector3(1.45, 0, 0))
	key(5.9, Vector3(2.9, 1.55, 3.5), Vector3(1.75, 1.42, 0.0), 36.0)
	reach(A, "r", 6.4, 6.82, 7.15, 7.9, star)
	# Berührung: der Stern leuchtet auf, steigt in die Baumkronen und weckt den Wald (Licht, Farben, Leuchtpilze)
	at(6.85, func() -> void:
		Audio.sfx("chime", null, -2.0, 1.0, 0.0)
		Audio.sfx("woom", null, -6.0, 0.8, 0.0)
		FX.shockwave(_origin + Vector3(2.05, 1.5, 0), 40.0, Color(1.0, 0.85, 0.45, 0.9))
		_mark("Blitz")
		create_tween().tween_property(_flash, "modulate:a", 0.5, 0.1))
	at(6.98, func() -> void:
		var rim := heroes[A].get_node_or_null("VoidRim")
		if rim:
			rim.queue_free()
		_reveal_forest()
		_fade(_flash, 0.0, 1.3)
		var tw := create_tween().set_parallel()
		tw.tween_property(_star, "position:y", 9.5, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_property(_star, "scale", Vector3.ONE * 0.15, 2.2)
		tw.tween_property(_star_light, "light_energy", 0.0, 2.2)
		tw.chain().tween_callback(func() -> void: _star.visible = false))
	# Freunde und Träumer sind von Anfang an in dieser Welt (noch weit außerhalb des Bildes)
	go(1, 7.0, 7.01, Vector3(22.5, _hill_y, -1.6), Vector3(22.5, _hill_y, -1.6))
	face(1, 7.0, Vector3(-1, 0, 0.3))
	go(3, 7.0, 7.01, Vector3(31.0, _stone_y - 0.04, -2.6), Vector3(31.0, _stone_y - 0.04, -2.6))
	pose(3, 7.0, "sit")
	face(3, 7.0, Vector3(0.6, 0, 0.7))
	look(3, 7.0, Vector3(32.1, 0.7, -1.9))
	expr(3, 7.0, "dreamy", 0.0)
	at(7.06, func() -> void:
		heroes[1].visible = true
		heroes[3].visible = true)
	# Staunen in Nahaufnahme, dann hebt sich die Kamera und gibt den erwachten Wald frei
	expr(A, 6.9, "awe", 0.15)
	look(A, 7.0, _star)
	key(6.9, Vector3(3.0, 1.55, 3.5), Vector3(1.7, 1.45, 0.0), 37.0)
	key(8.4, Vector3(3.1, 1.62, 3.8), Vector3(1.6, 1.5, 0.0), 38.0)
	key(15.0, Vector3(3.8, 4.2, 9.4), Vector3(1.9, 2.0, -5.0), 50.0)
	face(A, 9.2, Vector3(0.35, 0, -1))
	look(A, 9.4, Vector3(-6.0, 4.0, -12.0))
	look(A, 10.1, Vector3(8.0, 3.0, -10.0))
	# Die Welt leuchtet: er dreht sich zu uns, Freudensprung und echtes Lachen (Gesicht, Brust, Schultern)
	face(A, 10.5, Vector3(0.3, 0, 1))
	look(A, 10.7, "cam")
	expr(A, 10.9, "joy", 0.25)
	react(A, 11.1, "cheer")
	laugh(A, 11.2, 1.3, 0.85, "smile")
	face(A, 12.4, Vector3(-1, 0, -0.3))
	look(A, 12.8, Vector3(1.0, 14.0, -4.0))   # ganz nach oben in die Baumkronen
	face(A, 13.5, Vector3(0.25, 0, 1))
	look(A, 13.9, "cam")            # … und entdeckt uns: „Kommst du mit?“
	expr(A, 14.0, "grin", 0.3)
	reach(A, "r", 14.2, 14.55, 15.2, 15.6, func() -> Vector3: return _rel(A, 0.42, 1.95 + sin(t * 13.0) * 0.06, 0.12 + sin(t * 13.0) * 0.1))


# --- Akt 2 – Eine Welt voller Wunder (15–35 s) ----------------------------------------------------------------
func _act2() -> void:
	var A := 0
	var B := 1
	look(A, 15.4, null)
	expr(A, 15.5, "smile", 0.4)
	# gemütlich los – die Kamera bleibt nah bei ihm
	go(A, 15.9, 18.2, Vector3(1.45, 0, 0), Vector3(4.0, 0, 0))
	key(15.9, Vector3(3.4, 1.6, 4.8), Vector3(2.0, 1.25, 0.0), 42.0)
	key(18.2, Vector3(5.7, 1.55, 3.5), Vector3(4.25, 1.42, 0.0), 36.0)
	# Glühwürmchen vor der Nase: er schielt darauf, will es behutsam fangen – es entwischt, er lacht
	at(FIREFLY_T, func() -> void: _firefly.visible = true)
	look(A, FIREFLY_T + 0.2, _firefly)
	expr(A, 18.3, "curious", 0.25)
	tilt(A, 18.4, Vector3(0, 0, -0.18))
	reach(A, "r", 18.85, 19.25, 19.35, 19.85, func() -> Vector3: return _firefly.global_position)
	expr(A, 19.45, "surprised", 0.12)
	tilt(A, 19.7, Vector3.ZERO)
	laugh(A, 19.8, 1.25, 0.75)
	look(A, 20.3, Vector3(7.0, 3.5, -3.0))
	look(A, 21.1, null)
	go(A, 21.2, 23.2, Vector3(4.0, 0, 0), Vector3(8.0, 0, 0))
	key(21.2, Vector3(6.2, 1.6, 4.6), Vector3(4.7, 1.25, 0.0), 42.0)
	key(23.2, Vector3(10.0, 1.45, 4.0), Vector3(8.4, 0.95, 0.0), 42.0)
	# Ast auf dem Weg: Stolpern, Arme rudern, gerade noch gefangen – er schaut zurück und lacht über sich selbst
	go(A, 23.2, 23.7, Vector3(8.0, 0, 0), Vector3(8.75, 0.0, 0.05), 0.25)
	at(23.33, func() -> void:
		heroes[A].play("hit_b", 0.1, 1.3, true)
		heroes[A].lock(0.45)
		Audio.sfx("wood_hit", heroes[A].global_position, -8.0, 1.3, 0.0))
	expr(A, 23.3, "ouch", 0.08)
	reach(A, "l", 23.3, 23.46, 23.62, 24.15, func() -> Vector3: return _rel(A, -0.6, 1.75, 0.3))
	reach(A, "r", 23.34, 23.52, 23.72, 24.25, func() -> Vector3: return _rel(A, 0.62, 1.6, 0.35))
	go(A, 23.7, 24.4, Vector3(8.75, 0, 0.05), Vector3(9.3, 0, -0.1))
	at(24.4, func() -> void: heroes[A].squash(1.12, 0.88, 0.3))
	expr(A, 24.5, "surprised", 0.2)
	face(A, 24.65, Vector3(-1, 0, 0.25))
	look(A, 24.7, Vector3(8.6, 0.2, 0.2))
	laugh(A, 25.1, 1.0, 0.55)
	look(A, 26.0, null)
	go(A, 26.1, 27.6, Vector3(9.3, 0, -0.1), Vector3(12.0, 0, 0))
	key(26.1, Vector3(11.4, 1.6, 4.4), Vector3(9.9, 1.25, -0.3), 42.0)
	# Wasserfall: er bleibt stehen und schaut hinauf – die Kamera fährt hinter seine Schulter und folgt dem Blick
	face(A, 27.6, Vector3(0.35, 0, -1))
	look(A, 27.7, Vector3(14.0, 7.5, -8.5))
	expr(A, 27.8, "awe", 0.3)
	at(27.9, func() -> void: heroes[A].squash(0.95, 1.07, 0.4))
	key(27.9, Vector3(10.7, 1.7, 2.9), Vector3(13.4, 3.2, -8.0), 48.0)
	key(29.6, Vector3(10.2, 1.85, 3.4), Vector3(13.7, 4.4, -8.2), 52.0)
	# In der Ferne winkt jemand
	pose(B, 29.3, "wave")
	look(B, 29.3, A)
	expr(B, 29.3, "grin", 0.3)
	face(A, 29.9, Vector3(1, 0, -0.1))
	look(A, 29.9, Vector3(22.5, 1.6, -1.6))
	expr(A, 30.0, "surprised", 0.15)
	at(30.0, func() -> void: heroes[A].squash(0.93, 1.1, 0.25))   # kurzes Erstarren
	key(30.5, Vector3(10.0, 1.7, 3.4), Vector3(17.5, 1.3, -0.7), 40.0)
	expr(A, 30.5, "grin", 0.3)
	reach(A, "r", 30.45, 30.8, 31.15, 31.5, func() -> Vector3: return _rel(A, 0.42, 1.95 + sin(t * 13.0) * 0.06, 0.12 + sin(t * 13.0) * 0.1))
	at(31.32, func() -> void: heroes[A].anticipate(0.3, 0.1))
	go(A, 31.5, 34.6, Vector3(12.0, 0, 0), Vector3(21.3, 0, 0.1))
	expr(A, 31.6, "smile", 0.4)
	look(A, 31.6, B)
	key(31.5, Vector3(13.2, 1.6, 5.4), Vector3(13.2, 1.2, 0.0), 44.0)
	key(34.6, Vector3(22.3, 1.5, 4.0), Vector3(21.8, 1.3, -0.2), 38.0)
	at(33.5, func() -> void:
		_hold[B] = false
		heroes[B].play("idle", 0.3))
	go(B, 33.9, 34.6, Vector3(22.5, _hill_y, -1.6), Vector3(22.15, 0, -0.35), 0.35)


# --- Akt 3 – Gemeinsam unterwegs (35–58 s) --------------------------------------------------------------------
func _act3() -> void:
	var A := 0
	var B := 1
	var C := 2
	var D := 3
	# Abklatschen: beide holen aus, die Hände treffen sich wirklich in der Mitte
	face(A, 34.6, Vector3(1, 0, 0.25))    # leicht zur Kamera geöffnet: beide Gesichter sind zu sehen
	face(B, 34.6, Vector3(-1, 0, 0.3))
	look(A, 34.6, B)
	look(B, 34.6, A)
	expr(A, 34.6, "grin", 0.3)
	var d_ab := func() -> Vector3:
		var d := heroes[B].global_position - heroes[A].global_position
		d.y = 0.0
		return d.normalized()
	var clap := func() -> Vector3: return (_bone(A, "upperarm.r") + _bone(B, "upperarm.l")) * 0.5 + Vector3.UP * 0.2
	at(34.82, func() -> void:
		heroes[A].anticipate(0.22, 0.06)
		heroes[B].anticipate(0.22, 0.06))
	reach(A, "r", 34.95, 35.26, 35.36, 35.85, func() -> Vector3: return (clap.call() as Vector3) - (d_ab.call() as Vector3) * 0.025,
		func() -> Array: return [Vector3.UP, d_ab.call()])
	reach(B, "l", 34.98, 35.26, 35.36, 35.85, func() -> Vector3: return (clap.call() as Vector3) + (d_ab.call() as Vector3) * 0.025,
		func() -> Array: return [Vector3.UP, -(d_ab.call() as Vector3)])
	tilt(A, 35.0, Vector3(0, 0, 0.12))   # Köpfe weichen dem Arm aus
	tilt(B, 35.0, Vector3(0, 0, 0.12))
	tilt(A, 35.7, Vector3.ZERO)
	tilt(B, 35.7, Vector3.ZERO)
	at(35.27, func() -> void:
		Audio.sfx("pop", null, -2.0, 1.2, 0.0)
		FX.ring(clap.call(), Color(1, 1, 1, 0.7), 0.9, 0.25)
		var d: Vector3 = d_ab.call()
		bodies[A].push(-d * 1.8)   # der Schlag geht durch beide Körper
		bodies[B].push(d * 1.8)
		heroes[A].squash(1.06, 0.95, 0.25)
		heroes[B].squash(1.06, 0.95, 0.25))
	laugh(A, 35.6, 1.25, 0.8)
	laugh(B, 35.82, 1.2, 0.9)
	key(36.7, Vector3(22.0, 1.5, 3.6), Vector3(21.8, 1.32, -0.2), 36.0)
	# gemeinsam weiter – ein Schmetterling landet auf der Nase des Helden; er bremst, sie schaut dem Falter nach …
	go(A, 37.0, 38.9, Vector3(21.3, 0, 0.1), Vector3(24.6, 0, 0.2))
	go(B, 37.15, 39.05, Vector3(22.15, 0, -0.35), Vector3(23.72, 0, 0.1))
	look(A, 37.0, null)
	look(B, 37.0, null)
	key(37.0, Vector3(24.4, 1.6, 4.6), Vector3(22.7, 1.25, -0.2), 42.0)
	key(39.0, Vector3(26.5, 1.55, 3.6), Vector3(24.4, 1.38, 0.0), 38.0)
	at(BUTTERFLY_T, func() -> void: _butterfly.visible = true)
	look(A, BUTTERFLY_T + 0.2, _butterfly)
	look(B, BUTTERFLY_T + 0.3, _butterfly)
	expr(A, 38.6, "curious", 0.25)
	expr(B, 38.4, "dreamy", 0.3)
	# … und läuft auf: beide Hände landen in seinem Rücken, er stolpert einen Schritt vor
	var back := func() -> Vector3: return _bone(A, "chest") - _fwd(A) * 0.2
	reach(B, "l", 38.9, 39.05, 39.22, 39.6, back, func() -> Array: return [Vector3.UP, _fwd(B)])
	reach(B, "r", 38.9, 39.05, 39.22, 39.6, back, func() -> Array: return [Vector3.UP, _fwd(B)])
	at(39.06, func() -> void:
		bodies[A].push(_fwd(A) * 2.6)    # Oberkörper wird nach vorn geworfen …
		bodies[B].push(-_fwd(B) * 1.6)   # … sie prallt zurück
		heroes[A].squash(1.1, 0.92, 0.3)
		heroes[B].squash(1.08, 0.94, 0.3)
		Audio.sfx("hit_soft", heroes[A].global_position, -4.0, 1.2, 0.0))
	expr(A, 39.05, "ouch", 0.08)
	expr(B, 39.05, "ouch", 0.08)
	go(A, 39.06, 39.6, Vector3(24.6, 0, 0.2), Vector3(25.3, 0, 0.2), 0.14)
	go(B, 39.06, 39.6, Vector3(23.72, 0, 0.1), Vector3(23.4, 0, -0.5))
	face(A, 39.7, Vector3(-1, 0, 0.7))
	face(B, 39.7, Vector3(1, 0, 0.8))
	look(A, 39.7, B)
	look(B, 39.7, A)
	expr(A, 39.7, "surprised", 0.2)
	expr(B, 39.7, "plead", 0.2)   # „'tschuldigung!“
	laugh(A, 40.05, 1.5, 0.9)
	laugh(B, 40.3, 1.4, 1.0)
	key(41.2, Vector3(26.0, 1.6, 5.2), Vector3(24.2, 1.2, 0.0), 44.0)
	# Der Barbar kommt keuchend von hinten ins Bild gerannt, stützt die Hände auf die Knie
	at(40.6, func() -> void: heroes[C].visible = true)
	go(C, 40.6, 43.6, Vector3(14.0, 0, 0.9), Vector3(22.9, 0, 0.9))
	go(C, 43.6, 44.5, Vector3(22.9, 0, 0.9), Vector3(23.7, 0, 0.9))
	expr(C, 40.6, "pant", 0.0)
	breath(C, 40.6, 1.0, 2.8)
	look(A, 42.4, C)
	look(B, 42.7, C)
	expr(A, 42.5, "smile", 0.4)
	expr(B, 42.8, "smile", 0.4)
	at(44.5, func() -> void: bodies[C].chest_add = Vector3(0.32, 0, 0))   # gebückt, das Gesicht bleibt sichtbar
	reach(C, "l", 44.45, 44.9, 46.5, 46.95, func() -> Vector3: return _rel(C, -0.2, 0.5, 0.24))
	reach(C, "r", 44.45, 44.9, 46.5, 46.95, func() -> Vector3: return _rel(C, 0.2, 0.5, 0.24))
	look(C, 44.6, Vector3(24.6, 0.2, 0.9))
	key(42.6, Vector3(25.4, 1.6, 5.6), Vector3(23.9, 1.2, 0.3), 44.0)
	# Der Held geht hin und klopft ihm auf die Schulter – die Hand kommt an
	go(A, 44.3, 45.0, Vector3(25.3, 0, 0.2), Vector3(24.55, 0, 0.5))
	face(A, 45.0, Vector3(-1, 0, 0.45))
	reach(A, "r", 45.05, 45.42, 46.3, 46.8, func() -> Vector3: return _near_shoulder(C, A) + Vector3(0, 0.1 + 0.05 * sin(t * 12.0), 0),
		func() -> Array: return [_fwd(A), Vector3.DOWN])
	for pt in [45.42, 45.94]:   # Tiefpunkte des Klopfens: die Schulter gibt nach
		at(pt, func() -> void:
			var d := heroes[C].global_position - heroes[A].global_position
			d.y = 0.0
			bodies[C].push(d.normalized() * 1.3))
	key(45.2, Vector3(25.7, 0.95, 3.0), Vector3(24.0, 1.2, 0.7), 40.0)   # tief vor dem Barbaren: Gesicht und Hand auf der Schulter
	look(C, 45.45, A)
	expr(C, 45.8, "smile", 0.4)
	laugh(B, 45.7, 1.0, 0.5)
	at(46.7, func() -> void: bodies[C].chest_add = Vector3.ZERO)
	breath(C, 46.9, 0.6, 2.0)
	expr(C, 46.9, "grin", 0.4)
	key(47.0, Vector3(25.4, 1.6, 5.0), Vector3(24.7, 1.2, 0.4), 42.0)
	# Alle weiter – vorbei am Träumer auf dem Stein, der es zu spät bemerkt
	go(A, 47.2, 49.6, Vector3(24.55, 0, 0.5), Vector3(29.4, 0, 0.2))
	go(B, 47.3, 49.6, Vector3(23.4, 0, -0.5), Vector3(28.5, 0, -0.7))
	go(C, 47.5, 49.4, Vector3(23.7, 0, 0.9), Vector3(27.4, 0, 1.0))
	for k in [A, B, C]:
		look(k, 47.2, null)
		expr(k, 47.4, "smile", 0.4)
	key(49.6, Vector3(32.4, 1.6, 5.4), Vector3(30.6, 1.2, -0.9), 44.0)
	look(D, 48.7, Vector3(26.0, 1.5, 0.0))
	look(D, 49.1, Vector3(36.0, 1.5, 0.0))
	look(D, 49.4, A)
	expr(D, 49.15, "surprised", 0.12)
	at(49.42, func() -> void:
		heroes[D].squash(0.9, 1.14, 0.25)
		_hold[D] = false)
	go(D, 49.5, 49.95, Vector3(31.0, _stone_y - 0.04, -2.6), Vector3(31.4, 0, -1.2), 0.5)
	expr(D, 50.0, "grin", 0.3)
	# Der Held schaut über die Schulter und winkt ihn heran – im Laufen
	look(A, 49.3, D)
	expr(A, 49.3, "grin", 0.3)
	reach(A, "l", 49.3, 49.65, 50.3, 50.7, func() -> Vector3: return _rel(A, -0.45, 1.9 + sin(t * 12.0) * 0.07, -0.1))
	# Gemeinsam los – Weltenwechsel 1: hinter dem riesigen Baumstamm
	go(A, 49.6, 53.2, Vector3(29.4, 0, 0.2), Vector3(38.0, 0, 0.2))
	go(B, 49.6, 53.2, Vector3(28.5, 0, -0.7), Vector3(37.0, 0, -0.7))
	go(C, 49.4, 53.2, Vector3(27.4, 0, 1.0), Vector3(39.6, 0, 1.0))      # Barbar und Träumer ziehen vorbei
	go(D, 49.95, 53.2, Vector3(31.4, 0, -1.2), Vector3(40.4, 0, -1.25))
	for k in 4:
		look(k, 50.8, null)
	key(50.6, Vector3(34.6, 1.7, 6.6), Vector3(32.6, 1.15, -0.3), 46.0)
	key(53.6, Vector3(41.6, 1.8, 7.2), Vector3(40.4, 1.1, 0.0), 46.0)
	# Der Stamm zieht ganz nah durchs Bild und deckt es im Wechselmoment vollständig ab
	at(49.8, func() -> void: _trunk.visible = true)
	at(WIPE_T, func() -> void: _use_set("meadow", "day"))
	at(55.2, func() -> void: _trunk.visible = false)
	# Wiese: Die Magierin bleibt staunend vor der Riesenblume stehen – der Held kommt zurück, nimmt ihre Hand
	# und zieht sie mit (sie wird wirklich gezogen: Arm gestreckt, ein Ruck, dann läuft sie hinterher)
	go(A, 53.2, 54.8, Vector3(38.0, 0, 0.2), Vector3(42.0, 0, 0.2))
	go(B, 53.2, 54.6, Vector3(37.0, 0, -0.7), Vector3(40.6, 0, -0.9))
	go(C, 53.2, 57.6, Vector3(39.6, 0, 1.0), Vector3(49.6, 0, 1.0))
	go(D, 53.2, 57.6, Vector3(40.4, 0, -1.25), Vector3(48.8, 0, -1.25))
	face(B, 54.6, Vector3(0.75, 0, -1))
	look(B, 54.4, Vector3(43.2, 2.6, -2.8))
	expr(B, 54.5, "awe", 0.3)
	tilt(B, 54.8, Vector3(-0.1, 0, 0.15))
	look(A, 54.7, B)
	expr(A, 54.9, "smile", 0.3)
	go(A, 55.0, 55.7, Vector3(42.0, 0, 0.2), Vector3(41.1, 0, 0.3))   # stellt sich neben sie – beide Gesichter frei
	var hands := func() -> Vector3: return (_bone(A, "upperarm.l") + _bone(B, "upperarm.r")) * 0.5 + Vector3(0, -0.22, 0)
	var d_ba := func() -> Vector3:
		var d := heroes[A].global_position - heroes[B].global_position
		d.y = 0.0
		return d.normalized()
	reach(A, "l", 55.65, 55.98, 57.35, 57.8, func() -> Vector3: return (hands.call() as Vector3) + (d_ba.call() as Vector3) * 0.03,
		func() -> Array: return [(_fwd(A) * 0.5 + Vector3.DOWN).normalized(), -(d_ba.call() as Vector3)])
	reach(B, "r", 55.75, 56.02, 57.35, 57.8, func() -> Vector3: return (hands.call() as Vector3) - (d_ba.call() as Vector3) * 0.03,
		func() -> Array: return [(_fwd(B) * 0.5 + Vector3.DOWN).normalized(), d_ba.call()])
	at(55.98, func() -> void: Audio.sfx("plop", null, -8.0, 1.3, 0.0))
	look(B, 56.0, A)
	expr(B, 56.0, "surprised", 0.15)
	tilt(B, 56.0, Vector3.ZERO)
	go(A, 56.1, 57.9, Vector3(41.1, 0, 0.3), Vector3(46.6, 0, 0.1))
	at(56.24, func() -> void:
		heroes[B].squash(0.94, 1.07, 0.3)   # der Ruck: ihr Oberkörper wird mitgerissen
		bodies[B].push((d_ba.call() as Vector3) * 2.4)
		bodies[A].push(-(d_ba.call() as Vector3) * 0.9))
	go(B, 56.26, 57.9, Vector3(40.6, 0, -0.9), Vector3(45.4, 0, -0.5))
	expr(B, 56.6, "laugh", 0.3)
	expr(A, 56.3, "grin", 0.3)
	look(A, 56.6, null)
	look(B, 57.3, null)
	# Gegenschuss von der Blüte aus: das staunende Gesicht, der Held kommt zurück und nimmt ihre Hand
	key(54.55, Vector3(42.9, 1.45, -2.5), Vector3(40.9, 1.38, -0.75), 40.0, true)
	key(56.95, Vector3(43.3, 1.5, -2.2), Vector3(42.2, 1.3, -0.5), 42.0)
	key(56.96, Vector3(45.4, 1.7, 5.7), Vector3(44.0, 1.2, -0.2), 44.0, true)
	key(58.4, Vector3(50.0, 1.9, 6.6), Vector3(48.6, 1.2, 0.0), 46.0)
	# Weltenwechsel 2: Die Kamera fährt hinter dem Wasserfall-Tor hindurch – dahinter liegt die Bucht
	at(53.0, func() -> void: _curtain.visible = true)
	at(WIPE2_T - 0.35, func() -> void: Audio.sfx("splash", null, -6.0, 1.0, 0.0))
	at(WIPE2_T, func() -> void: _use_set("beach", "sunset"))
	at(63.45, func() -> void: _curtain.visible = false)   # erst im Schnitt auf den Boss – vorher bliebe es als Sprung sichtbar


# --- Akt 4 – Das Abenteuer eskaliert (Strand, Vulkan, Boss, BOOM, Montage) --------------------------------------
func _act4() -> void:
	var A := 0
	var B := 1
	var C := 2
	var D := 3
	# Bucht im Abendlicht: die vier laufen den Strand entlang, der Sand wird zu Vulkangestein
	go(A, 57.9, 60.4, Vector3(46.6, 0, 0.1), Vector3(53.0, 0, 0.1))
	go(B, 57.9, 60.4, Vector3(45.4, 0, -0.5), Vector3(52.0, 0, -0.6))
	go(C, 57.6, 60.4, Vector3(49.6, 0, 1.0), Vector3(54.4, 0, 1.0))
	go(D, 57.6, 60.4, Vector3(48.8, 0, -1.25), Vector3(53.8, 0, -1.25))
	for k in 4:
		expr(k, 58.3 + k * 0.12, "awe", 0.4)
		look(k, 58.3 + k * 0.1, Vector3(60.0, 4.0, -40.0))   # das Meer, der glühende Berg
		expr(k, 59.6 + k * 0.1, "smile", 0.5)
		look(k, 60.0, null)
	go(A, 60.4, 63.2, Vector3(53.0, 0, 0.1), Vector3(60.6, 0, 0.2))
	go(B, 60.4, 63.2, Vector3(52.0, 0, -0.6), Vector3(59.6, 0, -0.8))
	go(C, 60.4, 63.2, Vector3(54.4, 0, 1.0), Vector3(59.2, 0, 1.1))
	go(D, 60.4, 63.2, Vector3(53.8, 0, -1.25), Vector3(58.4, 0, -1.3))
	key(60.4, Vector3(54.6, 1.8, 6.2), Vector3(52.8, 1.2, -0.4), 44.0)
	key(63.2, Vector3(62.6, 2.0, 7.0), Vector3(60.4, 1.3, -1.0), 46.0)
	# Der Barbar knufft den Träumer im Laufen mit dem Ellbogen – der lacht und weicht aus
	reach(C, "l", 61.3, 61.55, 61.7, 62.05, func() -> Vector3: return _near_shoulder(D, C))
	look(C, 61.2, D)
	expr(C, 61.2, "grin", 0.2)
	at(61.58, func() -> void:
		heroes[D].squash(1.1, 0.92, 0.25)
		var d := heroes[D].global_position - heroes[C].global_position
		d.y = 0.0
		bodies[D].push(d.normalized() * 2.0)   # der Knuff schiebt ihn seitlich weg
		Audio.sfx("hit_soft", null, -8.0, 1.4, 0.0))
	laugh(D, 61.75, 0.9, 0.7)
	look(D, 61.6, C)
	expr(D, 61.6, "laugh", 0.2)
	look(C, 62.2, null)
	look(D, 62.3, null)
	# Die Magierin zeigt nach vorn zum Berg
	reach(B, "r", 62.0, 62.4, 63.0, 63.4, func() -> Vector3: return _rel(B, 0.25, 1.5, 0.75))
	# Der Boss taucht auf – alle bleiben stehen und schauen hinauf
	at(63.3, func() -> void:
		_boss.visible = true
		_boss.position.y = -7.0 * BOSS_SCALE
		create_tween().tween_property(_boss, "position:y", 0.0, 1.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Juice.shake(0.35)
		Audio.sfx("stone_hit", null, 0.0, 0.6, 0.0)
		_boss.act("roar"))
	for k in 4:
		look(k, 63.5 + k * 0.08, Vector3(70.0, 11.0, -11.0))
		face(k, 63.5, Vector3(0.5, 0, -1))
		expr(k, 63.5 + k * 0.07, "scared", 0.12)
		at(63.55 + k * 0.07, func() -> void: heroes[k].squash(0.92, 1.1, 0.3))
		breath(k, 63.6, 0.9, 2.6)
	# Die Magierin klammert sich an den Arm des Helden, der Träumer duckt sich hinter den Barbaren –
	# und der stellt sich breitbeinig vor ihn
	reach(B, "l", 63.9, 64.3, 65.5, 65.6, func() -> Vector3: return _near_shoulder(A, B) + Vector3(0, -0.12, 0))
	go(B, 63.75, 64.3, Vector3(59.6, 0, -0.8), Vector3(60.05, 0, -0.35))
	go(D, 63.8, 64.5, Vector3(58.4, 0, -1.3), Vector3(58.3, 0, 1.35))
	expr(C, 64.5, "determined", 0.3)
	# Tief hinter der Gruppe: die vier klein im unteren Bilddrittel, der Boss türmt sich darüber auf
	key(63.45, Vector3(55.0, 1.25, 9.4), Vector3(67.0, 6.4, -9.5), 54.0, true)
	key(65.3, Vector3(56.0, 1.15, 8.2), Vector3(68.0, 7.4, -10.5), 50.0)
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


## Elf Takte Spiel (je 1,74 s): Spielbrett aus der Luft + Würfelblock (2) · Zug über vier Felder · Stern ·
## Ereignisfeld „?“ · Minispiel Sumo-Ring · Boss-Ausweichen · Nitro Dash: Start, Drift, Überholen, Ziel.
## Dezente Einblendungen benennen, was man sieht: Spielbrett · Ereignisfelder · Minispiele · Bosskämpfe · Nitro Dash.
func _montage() -> void:
	var sh := 4.0 * BEAT
	var s := []
	for k in 12:
		s.append(MONTAGE_T0 + k * sh)
	var A := 0
	var B := 1
	var C := 2
	var D := 3
	# Was man sieht, in einem Wort – klein über dem unteren Kinobalken
	for c: Array in [[s[0] + 0.3, "SPIELBRETT", s[4]], [s[4] + 0.15, "EREIGNISFELDER", s[5]], [s[5] + 0.15, "MINISPIELE", s[6]],
			[s[6] + 0.15, "BOSSKÄMPFE", s[7]], [s[7] + 0.15, "NITRO DASH", s[11] - 0.2]]:
		at(float(c[0]), func() -> void:
			_caption.text = String(c[1])
			_fade(_caption, 1.0, 0.16))
		at(float(c[2]) - 0.2, func() -> void: _fade(_caption, 0.0, 0.16))
	var cast := func(on: Array, time: float) -> void:
		at(time, func() -> void:
			for k in 4:
				heroes[k].visible = k in on
				heroes[k].set_lean(0.0)
				_look[k] = null
				_hold[k] = false
				bodies[k].chest_add = Vector3.ZERO
				bodies[k].head_add = Vector3.ZERO
				bodies[k].breath = 0.4
				bodies[k].breath_rate = 1.4
				faces[k].set_expr("smile", 0.0)
			for kv in _karts:
				kv.visible = false)
	# --- 0+1: Das Spielbrett – Kamerafahrt von oben bis zum Helden, der Würfelblock erscheint, er springt dagegen
	var i0 := 16
	var side := Vector3(0, 0, 1)   # die Kamera steht außen vor der vorderen Brettseite
	var home := {A: i0, B: 24, C: 27, D: 12}
	at(s[0], func() -> void: _use_set("board", "day"))
	cast.call([A, B, C, D], s[0])
	for k in 4:
		var p: Vector3 = _bp[home[k]]
		go(k, s[0], s[0] + 0.01, p, p)
		face(k, s[0], (_bp[home[k] + 1] - p).normalized() + side * 0.8)
		if k != A:
			look(k, s[0] + 0.2, A)
	var pa: Vector3 = _bp[i0]
	key(s[0], Vector3(2.0, 27.0, 40.0), Vector3(0.0, 0.0, 1.0), 50.0, true)
	key(s[1], pa + Vector3(3.2, 4.6, 9.5), pa + Vector3(0, 1.6, 0), 44.0)
	key(s[2] - 0.01, pa + Vector3(1.4, 2.3, 6.4), pa + Vector3(0, 2.0, 0), 40.0)
	at(s[0] + 1.3, func() -> void:
		_dice.visible = true
		_dice_fixed = false
		_dice.position = pa + Vector3.UP * 3.0
		Juice.pop_in(_dice, 0.3)
		Audio.sfx("dice_spin", null, -6.0, 1.0, 0.0))
	look(A, s[0] + 1.4, _dice)
	expr(A, s[0] + 1.4, "grin", 0.2)
	at(s[1] + 0.42, func() -> void: heroes[A].anticipate(0.34, 0.08))
	go(A, s[1] + 0.62, s[1] + 1.06, pa, pa, 1.35)
	reach(A, "r", s[1] + 0.6, s[1] + 0.82, s[1] + 0.88, s[1] + 1.15, func() -> Vector3: return _dice.global_position + Vector3(0, -0.5, 0))
	at(s[1] + 0.84, func() -> void:
		_dice_fixed = true
		(_dice.get_node("Num") as Label3D).text = "4"
		(_dice.get_node("Num") as Label3D).modulate = Color("#ffd23f")
		Audio.sfx("dice_hit", null, 0.0, 1.0, 0.0)
		FX.ring(_dice.global_position, Color(1, 1, 1, 0.8), 2.4, 0.35)
		var tw := _dice.create_tween()
		tw.tween_property(_dice, "position:y", _dice.position.y + 0.5, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_dice, "position:y", _dice.position.y, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT))
	at(s[1] + 1.06, func() -> void: heroes[A].land_impact(0.6))
	expr(A, s[1] + 0.9, "laugh", 0.15)
	# --- 2: Der Zug – vier Felder weit, Hüpfer für Hüpfer; die anderen schauen zu
	at(s[2], func() -> void:
		var tw := _dice.create_tween()
		tw.tween_property(_dice, "scale", Vector3.ONE * 0.05, 0.25)
		tw.tween_callback(func() -> void: _dice.visible = false))
	look(A, s[2], null)
	expr(A, s[2], "grin", 0.2)
	for k in 4:
		var t0: float = s[2] + 0.08 + k * 0.4
		go(A, t0, t0 + 0.36, _bp[i0 + k], _bp[i0 + k + 1], 0.75)
		at(t0 + 0.36, func() -> void:
			heroes[A].land_impact(0.45)
			Audio.sfx("tick", null, -2.0, 1.0 + k * 0.12, 0.0))
	var pe: Vector3 = _bp[i0 + 4]
	at(s[2] + 1.56, func() -> void:
		Audio.sfx("coin", null, 0.0, 1.0, 0.0)
		Juice.float_text(self, _origin + pe + Vector3.UP * 2.4, "+3", UI.GOLD, 100))
	key(s[2], pa + Vector3(-2.0, 5.2, 5.4), pa + Vector3(-2.4, 0.9, 0), 46.0, true)
	key(s[3] - 0.01, pe + Vector3(0.4, 4.4, 4.8), pe + Vector3(0, 1.0, 0), 42.0)
	# --- 3: Der Stern schwebt herab in die erhobenen Hände – die Freunde jubeln von ihren Feldern
	face(A, s[3], (_bp[i0 + 5] - pe).normalized() + side * 1.2)
	look(A, s[3], _board.star_node)
	expr(A, s[3], "awe", 0.15)
	at(s[3] + 0.15, func() -> void:
		var tw := _board.star_node.create_tween()
		tw.tween_property(_board.star_node, "position", pe + Vector3(0, 2.75, 0.0), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		Audio.sfx("sparkle_up", null, -4.0, 1.0, 0.0))
	reach(A, "l", s[3] + 0.35, s[3] + 0.85, s[4], s[4], func() -> Vector3: return _rel(A, -0.5, 2.1, 0.12))
	reach(A, "r", s[3] + 0.4, s[3] + 0.85, s[4], s[4], func() -> Vector3: return _rel(A, 0.5, 2.1, 0.12))
	at(s[3] + 0.92, func() -> void:
		Audio.sfx("star", null, 0.0, 1.0, 0.0)
		FX.confetti(_origin + pe + Vector3.UP * 3.0, 60)
		heroes[A].squash(0.94, 1.08, 0.3))
	laugh(A, s[3] + 0.95, 1.2, 1.0)
	for k in [B, C, D]:
		react(k, s[3] + 1.0 + 0.06 * k, "cheer")
		expr(k, s[3] + 1.0, "laugh", 0.2)
	key(s[3], pe + Vector3(-1.6, 1.5, 5.0), pe + Vector3(0.1, 2.0, 0), 46.0, true)
	key(s[4] - 0.01, pe + Vector3(-1.2, 1.5, 4.2), pe + Vector3(0.0, 2.0, 0), 42.0)
	# --- 4: Ereignisfeld „?“ – die Magierin hüpft drauf, ein Geschenk springt aus dem Feld und platzt: Münzregen
	cast.call([A, B, C, D], s[4])
	var pq: Vector3 = _bp[23]
	var pq0: Vector3 = _bp[22]
	for k in [A, C, D]:
		var hp: Vector3 = _bp[[19, 0, 27, 12][k]] if k != A else _bp[i0 + 4]
		go(k, s[4], s[4] + 0.01, hp, hp)
		look(k, s[4] + 0.1, B)
		expr(k, s[4], "curious", 0.0)
	go(B, s[4], s[4] + 0.01, pq0, pq0)
	face(B, s[4], (pq - pq0).normalized() + side * 0.9)
	expr(B, s[4], "grin", 0.0)
	go(B, s[4] + 0.08, s[4] + 0.46, pq0, pq, 0.8)
	at(s[4] + 0.46, func() -> void:
		heroes[B].land_impact(0.5)
		Audio.sfx("tick", null, -2.0, 1.3, 0.0)
		var lbl: Label3D = _board.space_nodes[23].get_child(1) as Label3D
		if lbl:
			var tw := lbl.create_tween()
			tw.tween_property(lbl, "scale", Vector3.ONE * 1.7, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(lbl, "scale", Vector3.ONE, 0.3))
	at(s[4] + 0.6, func() -> void:
		var gift := Assets.spawn("hol/present_red", _sets.board, pq + Vector3(0.75, 0.0, 0.95), 25.0, 1.1)
		gift.name = "EventGift"
		Juice.pop_in(gift, 0.28)
		var tw := gift.create_tween()
		tw.tween_property(gift, "position:y", pq.y + 0.9, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(gift, "position:y", pq.y + 0.05, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		Audio.sfx("sparkle_up", null, -4.0, 1.2, 0.0))
	look(B, s[4] + 0.62, pq + Vector3(0.75, 0.5, 0.95))
	expr(B, s[4] + 0.62, "surprised", 0.1)
	at(s[4] + 0.64, func() -> void: heroes[B].squash(0.93, 1.09, 0.28))
	at(s[4] + 1.12, func() -> void:
		var gift := _sets.board.get_node_or_null("EventGift") as Node3D
		if gift:
			FX.confetti(gift.global_position + Vector3.UP * 0.8, 70)
			FX.coins_burst(heroes[B].global_position, 12, true, _sets.board)   # Münzregen auf die Magierin
			gift.queue_free()
		Audio.sfx("coin", null, 0.0, 1.0, 0.0)
		Juice.float_text(self, _origin + pq + Vector3.UP * 2.6, "+10", UI.GOLD, 110))
	expr(B, s[4] + 1.14, "joy", 0.12)
	laugh(B, s[4] + 1.2, 1.0, 1.0)
	reach(B, "l", s[4] + 1.12, s[4] + 1.32, s[5], s[5], func() -> Vector3: return _rel(B, -0.5, 2.05, 0.15), func() -> Array: return [Vector3.UP, _fwd(B)])
	reach(B, "r", s[4] + 1.14, s[4] + 1.34, s[5], s[5], func() -> Vector3: return _rel(B, 0.5, 2.05, 0.15), func() -> Array: return [Vector3.UP, _fwd(B)])
	for k in [A, C, D]:
		expr(k, s[4] + 1.2, "laugh", 0.2)
		laugh(k, s[4] + 1.25 + 0.05 * k, 0.8, 0.6)
	key(s[4], pq + Vector3(-1.5, 1.6, 4.9), pq + Vector3(0.4, 1.25, 0.3), 44.0, true)
	key(s[5] - 0.01, pq + Vector3(-1.1, 1.5, 4.2), pq + Vector3(0.45, 1.35, 0.3), 40.0)
	# --- 5: Minispiel „Sumo-Ring“ – der Barbar schiebt den Träumer mit beiden Händen von der Plattform
	at(s[5], func() -> void:
		_use_set("montage", "day")
		_board.star_node.position = _bp[21] + Vector3.UP * 2.5)
	cast.call([A, B, C, D], s[5])
	var top := 0.6
	go(C, s[5], s[5] + 0.5, Vector3(-1.5, top, 0.2), Vector3(-0.25, top, 0.2))
	go(D, s[5], s[5] + 0.01, Vector3(0.55, top, 0.2), Vector3(0.55, top, 0.2))
	face(D, s[5], Vector3(-1, 0, 0))
	look(C, s[5], D)
	look(D, s[5], C)
	expr(C, s[5], "determined", 0.0)
	expr(D, s[5], "surprised", 0.0)
	var chest_d := func() -> Vector3: return _bone(D, "chest") + Vector3(0, 0.05, 0)
	reach(C, "l", s[5] + 0.3, s[5] + 0.5, s[5] + 0.95, s[5] + 1.2, chest_d)
	reach(C, "r", s[5] + 0.3, s[5] + 0.5, s[5] + 0.95, s[5] + 1.2, chest_d)
	at(s[5] + 0.5, func() -> void:
		Audio.sfx("hit_soft", null, -2.0, 1.0, 0.0)
		heroes[D].squash(1.1, 0.92, 0.3))
	go(C, s[5] + 0.5, s[5] + 0.95, Vector3(-0.25, top, 0.2), Vector3(1.9, top, 0.2))
	go(D, s[5] + 0.5, s[5] + 0.95, Vector3(0.55, top, 0.2), Vector3(2.75, top, 0.2))
	expr(D, s[5] + 0.55, "scared", 0.1)
	reach(D, "l", s[5] + 0.6, s[5] + 0.85, s[5] + 1.2, s[5] + 1.5, func() -> Vector3: return _rel(D, -0.6, 1.8, 0.1))
	reach(D, "r", s[5] + 0.65, s[5] + 0.9, s[5] + 1.2, s[5] + 1.5, func() -> Vector3: return _rel(D, 0.6, 1.7, 0.1))
	go(D, s[5] + 0.95, s[5] + 1.5, Vector3(2.75, top, 0.2), Vector3(5.3, -0.7, 0.4), 0.7)
	at(s[5] + 1.42, func() -> void:
		FX.splash(_origin + Vector3(5.3, -0.3, 0.4), 1.7)
		Audio.sfx("splash", null, 0.0, 1.0, 0.0))
	expr(C, s[5] + 1.1, "laugh", 0.2)
	# im Hintergrund ringen der Held und die Magierin, Hände an den Schultern
	go(A, s[5], s[5] + 0.01, Vector3(-1.2, top, -1.9), Vector3(-1.2, top, -1.9))
	go(B, s[5], s[5] + 0.01, Vector3(-0.3, top, -2.1), Vector3(-0.3, top, -2.1))
	face(A, s[5], Vector3(1, 0, -0.2))
	face(B, s[5], Vector3(-1, 0, 0.2))
	look(A, s[5], B)
	look(B, s[5], A)
	for hs in ["l", "r"]:
		reach(A, hs, s[5], s[5] + 0.05, s[6], s[6], func() -> Vector3: return _bone(B, "upperarm." + ("r" if hs == "l" else "l")))
		reach(B, hs, s[5], s[5] + 0.05, s[6], s[6], func() -> Vector3: return _bone(A, "upperarm." + ("r" if hs == "l" else "l")))
	expr(A, s[5], "determined", 0.0)
	expr(B, s[5], "grin", 0.0)
	key(s[5], Vector3(-2.2, 2.3, 7.6), Vector3(0.6, 1.3, 0.0), 44.0, true)
	key(s[6] - 0.01, Vector3(0.6, 2.0, 7.0), Vector3(2.6, 0.9, 0.2), 42.0)
	# --- 6: Bosskampf – dem Schlag gerade noch ausgewichen
	cast.call([D], s[6])
	at(s[6], func() -> void:
		_use_env("volcano")
		(_sets.montage.get_node("Boss2") as BossModel).act("slam")
		MgKit.warn_disc(_sets.montage, Vector3(120, 0.45, 3), 1.6, Color(1, 0.2, 0.1, 0.6), 0.9))
	go(D, s[6], s[6] + 0.01, Vector3(120.0, 0.4, 3.0), Vector3(120.0, 0.4, 3.0))
	face(D, s[6], Vector3(0, 0, -1))
	look(D, s[6], Vector3(120, 5, -8))
	expr(D, s[6], "scared", 0.0)
	clip(D, s[6] + 0.5, "dodge", 0.1, 1.4)
	go(D, s[6] + 0.5, s[6] + 0.95, Vector3(120.0, 0.4, 3.0), Vector3(123.2, 0.4, 3.6), 0.5)
	at(s[6] + 0.95, func() -> void:
		FX.explosion(_origin + Vector3(120, 0.6, 3), 1.2)
		Juice.shake(0.4))
	look(D, s[6] + 1.0, Vector3(120, 4, -8))
	expr(D, s[6] + 1.1, "determined", 0.2)
	key(s[6], Vector3(115.6, 3.0, 9.6), Vector3(120.0, 2.4, -1.0), 46.0, true)
	key(s[7] - 0.01, Vector3(116.4, 2.6, 8.8), Vector3(121.0, 2.0, 0.0), 44.0)
	# --- 7–10: Nitro Dash auf dem Lumos-Ring: Start · Drift · Überholen · Ziel (Kamera fährt mit, siehe _race_camera)
	at(s[7], func() -> void:
		_use_set("race", "day")
		Audio.sfx("go", null, -3.0, 1.0, 0.0))
	for k in [7, 8, 9, 10]:
		cast.call([], s[k])
		key(s[k], Vector3(0, 2, 0), Vector3(0, 2, -5), 60.0, true)
		at(s[k] + 0.1, func() -> void: Audio.sfx("whoosh", null, -5.0, 0.8, 0.0))
	at(s[10] + 0.36 * sh, func() -> void:
		FX.confetti(_track.frame(0.0).origin + Vector3.UP * 6.0, 160)
		Audio.sfx("chime", null, -2.0, 1.0, 0.0))


# --- Akt 5 – Wieder zusammen (Lagerfeuer, Logo) ------------------------------------------------------------------
func _act5() -> void:
	var A := 0
	var B := 1
	var C := 2
	var D := 3
	var t0 := MONTAGE_T0 + 11.0 * 4.0 * BEAT
	var fire := Vector3(-6.0, 0.6, -18.0)
	# Alle auf einer Bank aus Stämmen, dem Feuer zugewandt: Träumer (schläft, lehnt am Helden) · Held · Barbar (isst);
	# die Magierin liegt daneben im Gras und zeigt in die Sterne
	var pd := Vector3(-7.32, 0.42, -20.0)
	var pa := Vector3(-6.5, 0.42, -20.0)
	var pc := Vector3(-5.45, 0.42, -20.0)
	var pb := Vector3(-2.7, 0.05, -21.0)
	at(t0, func() -> void:
		_use_set("forest", "forest_night")
		for k in 4:
			heroes[k].visible = true
			heroes[k].set_lean(0.0)
			bodies[k].chest_add = Vector3.ZERO
			bodies[k].head_add = Vector3.ZERO
			bodies[k].breath = 0.45
			bodies[k].breath_rate = 1.2
		_music[2].play(84.0)
		_snack.visible = true
		FX.embers(_origin + fire, 10))
	for e in [[A, pa], [B, pb], [C, pc], [D, pd]]:
		go(int(e[0]), t0, t0 + 0.01, e[1], e[1])
	pose(A, t0, "sit")
	pose(B, t0, "lie")
	pose(C, t0, "sit")
	pose(D, t0, "sit")
	for k in [A, C, D]:
		face(k, t0, Vector3(0, 0, 1))
	face(B, t0, Vector3(1, 0, 0))
	at(t0 + 0.02, func() -> void:
		for k in [A, C, D]:
			heroes[k].face_now(Vector3(0, 0, 1))
		heroes[B].face_now(Vector3(1, 0, 0))
		heroes[D].rotation.z = deg_to_rad(-13.0)   # lehnt sich an den Freund
		bodies[D].head_add = Vector3(0.12, 0, -0.3)
		bodies[D].breath = 0.9
		bodies[D].breath_rate = 0.75
		bodies[A].chest_add = Vector3(0.16, 0, 0)
		faces[C].chew = 1.0)
	expr(D, t0, "asleep", 0.0)
	expr(A, t0, "smile", 0.0)
	expr(B, t0, "dreamy", 0.0)
	expr(C, t0, "smile", 0.0)
	look(A, t0, fire)
	look(B, t0, Vector3(-2.0, 20.0, -24.0))
	look(C, t0, fire)
	# Der Held wärmt sich die Hände am Feuer
	var warm_l := func() -> Vector3: return _rel(A, -0.17, 0.78 + sin(t * 2.2) * 0.02, 0.5)
	var warm_r := func() -> Vector3: return _rel(A, 0.17, 0.78 + sin(t * 2.2 + 1.0) * 0.02, 0.5)
	reach(A, "l", t0 - 0.1, t0, t0 + 3.9, t0 + 4.35, warm_l)
	reach(A, "r", t0 - 0.1, t0, t0 + 6.6, t0 + 7.4, warm_r)
	# Die Magierin zeigt auf einen Stern
	reach(B, "r", t0 + 0.6, t0 + 1.3, t0 + 5.4, t0 + 6.2, func() -> Vector3: return _rel(B, 0.25, 1.25, 0.1))
	# Der Barbar hält den Keks in der Hand: abbeißen, kauen
	var bite := func(u: float) -> float: return smoothstep(0.0, 0.3, u) * (1.0 - smoothstep(0.45, 0.8, u))
	var mid := Vector3(-5.98, 1.08, -19.72)
	var c_hand := func() -> Vector3:
		var rest := _rel(C, 0.2, 0.8, 0.34)
		var mouth := _bone(C, "head") + _fwd(C) * 0.36 + Vector3(0, 0.08, 0)
		var give := smoothstep(t0 + 4.05, t0 + 4.5, t) * (1.0 - smoothstep(t0 + 4.85, t0 + 5.3, t))
		return rest.lerp(mouth, bite.call(t - (t0 + 0.5))).lerp(_origin + mid, give)
	reach(C, "r", t0 - 0.1, t0, t0 + 5.3, t0 + 5.8, c_hand, func() -> Array: return [_fwd(C), Vector3.UP])   # Keks auf der Handfläche
	carry(_snack, C, "r", t0, t0 + 4.74)
	at(t0 + 0.82, func() -> void: Audio.sfx("plop", null, -12.0, 1.7, 0.0))
	# Die kleine Pointe, nah: Der Held schielt auf den Keks · der Barbar merkt es, zieht die Braue hoch · der Held
	# setzt den Bettelblick auf · der Barbar seufzt, grinst und reicht ihn hinüber · Hand nimmt Keks · beide lachen leise
	at(t0 + 2.45, func() -> void: bodies[A].chest_add = Vector3.ZERO)   # aufgerichtet: das Gesicht bleibt zu sehen
	look(A, t0 + 2.7, Vector3(-5.6, 1.25, -19.6))   # schielt zum Keks hinüber (die Augen wandern, der Kopf kaum)
	expr(A, t0 + 2.75, "curious", 0.25)
	tilt(A, t0 + 2.8, Vector3(0, 0, 0.14))
	look(C, t0 + 3.2, A)
	at(t0 + 3.2, func() -> void: faces[C].chew = 0.0)
	expr(C, t0 + 3.25, "smug", 0.2)
	look(A, t0 + 3.55, C)
	expr(A, t0 + 3.6, "plead", 0.25)
	look(C, t0 + 4.0, _snack)
	expr(C, t0 + 4.0, "smile", 0.3)
	at(t0 + 4.02, func() -> void: heroes[C].squash(1.03, 0.97, 0.4))   # das Seufzen
	look(A, t0 + 4.3, Vector3(-5.9, 1.2, -19.5))
	expr(A, t0 + 4.3, "awe", 0.2)
	reach(A, "l", t0 + 4.3, t0 + 4.72, t0 + 4.8, t0 + 5.0, func() -> Vector3: return _origin + mid + Vector3.UP * 0.06,
		func() -> Array: return [_fwd(A), Vector3.DOWN])   # greift von oben zu
	at(t0 + 4.74, func() -> void: Audio.sfx("plop", null, -10.0, 1.5, 0.0))
	carry(_snack, A, "l", t0 + 4.74, DUR + 1.0)
	var a_hand := func() -> Vector3:
		var mouth := _bone(A, "head") + _fwd(A) * 0.36 + Vector3(0, 0.06, 0)
		var rest := _rel(A, -0.2, 0.82, 0.34)
		return (_origin + mid).lerp(mouth, smoothstep(t0 + 4.85, t0 + 5.25, t)).lerp(rest, smoothstep(t0 + 5.55, t0 + 6.0, t))
	reach(A, "l", t0 + 4.76, t0 + 4.9, DUR, DUR, a_hand, func() -> Array: return [_fwd(A), Vector3.UP])
	tilt(A, t0 + 4.9, Vector3.ZERO)
	at(t0 + 5.3, func() -> void:
		faces[A].chew = 1.0
		Audio.sfx("plop", null, -12.0, 1.7, 0.0))
	expr(A, t0 + 5.3, "smile", 0.3)
	look(A, t0 + 5.5, C)
	look(C, t0 + 5.4, A)
	laugh(C, t0 + 5.55, 1.7, 0.6)
	at(t0 + 5.9, func() -> void: faces[A].chew = 0.0)
	laugh(A, t0 + 5.95, 1.5, 0.55)
	# … die Magierin im Gras dreht den Kopf zu den beiden und lacht mit
	pose(B, t0 + 5.6, "sit")
	face(B, t0 + 5.65, Vector3(-1, 0, 0.6))
	look(B, t0 + 5.7, A)
	expr(B, t0 + 5.8, "grin", 0.25)
	laugh(B, t0 + 6.25, 1.5, 0.8)
	look(B, t0 + 7.9, Vector3(-2.0, 20.0, -24.0))
	# Ein Funke steigt auf – die Kamera zieht sich zurück und steigt in den Nachthimmel
	at(t0 + 6.4, func() -> void:
		FX.sparks(_origin + fire + Vector3.UP * 0.6, Color(1.0, 0.7, 0.3), 8, 0.6)
		var sp := _glowbug(Color(1.0, 0.75, 0.35), 0.07)
		sp.global_position = _origin + fire + Vector3.UP * 0.8
		sp.visible = true
		create_tween().tween_property(sp, "global_position", _origin + fire + Vector3(0.8, 9.0, -1.0), 4.5).set_trans(Tween.TRANS_SINE))
	key(t0, Vector3(-4.6, 1.9, -12.4), Vector3(-5.9, 0.9, -19.4), 40.0, true)
	key(t0 + 2.49, Vector3(-4.8, 1.95, -12.8), Vector3(-5.9, 0.9, -19.4), 40.0)
	# nah dran: Held und Barbar nebeneinander, das Feuer flackert unscharf im Vordergrund
	key(t0 + 2.5, Vector3(-4.75, 1.3, -17.0), Vector3(-5.98, 1.2, -20.0), 38.0, true)
	key(t0 + 6.19, Vector3(-5.0, 1.3, -17.3), Vector3(-5.98, 1.2, -20.0), 35.0)
	key(t0 + 6.2, Vector3(-4.8, 2.0, -12.9), Vector3(-5.9, 0.95, -19.4), 41.0, true)
	key(t0 + 11.8, Vector3(8.0, 17.0, 6.0), Vector3(-6.0, 0.0, -18.0), 56.0)
	# Die Kamera steigt – der Held und der Barbar schauen uns nach
	look(A, t0 + 7.7, "cam")
	look(C, t0 + 8.2, "cam")
	expr(A, t0 + 7.8, "smile", 0.4)
	expr(C, t0 + 8.3, "smile", 0.4)
	# Logo und Slogan
	at(t0 + 8.4, func() -> void: _fade(_title, 1.0, 1.0))
	at(t0 + 9.4, func() -> void: _fade(_slogan, 1.0, 0.9))
	at(t0 + 10.2, func() -> void: _fade(_slogan2, 1.0, 0.9))
	at(t0 + 11.0, func() -> void: _fade(_cta, 1.0, 0.8))
	at(DUR - 1.2, func() -> void: _fade(_black, 1.0, 1.0))


func _animate_props(delta: float) -> void:
	if _firefly.visible:
		var a := heroes[0]
		var tt := t - FIREFLY_T
		var head := a.global_position + Vector3.UP * 1.62 + _fwd(0) * 0.62
		if tt < 2.1:
			_firefly.global_position = head + Vector3(cos(tt * 5.0) * 0.3, sin(tt * 7.0) * 0.1, sin(tt * 5.0) * 0.22) * clampf(1.4 - tt * 0.5, 0.35, 1.0)
		else:
			_firefly.global_position = _firefly.global_position.lerp(head + Vector3(3.0, 2.5, -3.0), clampf(delta * 1.5, 0, 1))
			if tt > 4.6:
				_firefly.visible = false
	if _butterfly.visible:
		var a2 := heroes[0]
		var tb := t - BUTTERFLY_T
		var nose := a2.global_position + Vector3.UP * 1.56 + _fwd(0) * 0.5
		var flap := sin(t * 40.0) * 0.9
		(_butterfly.get_node("WingL") as Node3D).rotation.z = -flap
		(_butterfly.get_node("WingR") as Node3D).rotation.z = flap
		if tb < 0.8:
			_butterfly.global_position = nose + Vector3(1.4 - tb * 1.75, 0.6 - tb * 0.75, 0.6 - tb * 0.75)
		elif tb < 1.06:
			_butterfly.global_position = nose   # sitzt auf der Nase – er schielt darauf
		else:
			_butterfly.global_position = _butterfly.global_position.lerp(nose + Vector3(2, 3, -2), clampf(delta * 1.2, 0, 1))
			if tb > 3.4:
				_butterfly.visible = false
	if _dice.visible and not _dice_fixed:
		(_dice.get_node("Die") as Node3D).rotation += Vector3(7.0, 9.0, 4.0) * delta
		_dice_tick += delta
		if _dice_tick > 0.06:
			_dice_tick = 0.0
			var num := _dice.get_node("Num") as Label3D
			num.text = str(_rng.randi_range(1, 6))
			num.modulate = Color.from_hsv(_rng.randf(), 0.4, 1.0)
	elif _dice.visible:
		(_dice.get_node("Die") as Node3D).rotation += Vector3(0, 2.5, 0) * delta
	if _fire_light:
		_fire_light.light_energy = 3.0 + sin(t * 9.0) * 0.35 + sin(t * 23.0) * 0.2
	for k in _flames.size():
		var fl := _flames[k]
		var fy := 1.0 + sin(t * (11.0 + k * 3.0) + k) * 0.14 + sin(t * 27.0 + k * 2.0) * 0.07
		fl.scale = Vector3(1.0 + sin(t * 17.0 + k) * 0.06, fy, 1.0 + cos(t * 15.0 + k) * 0.06)
		fl.rotation.y = t * (0.8 + k * 0.4)
	_drive_karts(delta)


var _spark_acc := 0.0


## Wasserfall im Vordergrund (zwischen Kamera und Weg): Die Kamera fährt dahinter entlang. Er gehört keiner Welt und
## zieht mit dem Set-Ursprung um – solange sein Wasser das Bild füllt, wechselt die Welt unsichtbar.
## Wasserfall-Tor für den Weltenwechsel: zwei Felsen, ein bemooster Sturz, dazwischen fällt das Wasser. Steht in
## beiden Welten an derselben Stelle (Wiese und Strand) – die Kamera fährt dahinter hindurch.
func _build_curtain() -> Node3D:
	var n := Node3D.new()
	n.name = "Curtain3D"
	n.visible = false
	add_child(n)
	var q := QuadMesh.new()
	q.size = Vector2(4.0, 7.4)
	q.material = _fall_material()
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.position = Vector3(0, 3.7, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	for sx: float in [-3.0, 3.0]:
		Assets.tint(WorldKit.place(n, "nat/rock_tall", Vector3(sx, 0, -2.2), 40.0 * sx, 3.2), Color(0.62, 0.7, 0.62))   # dunkler, bemooster Fels
	WorldKit.box(n, Vector3(8.4, 1.8, 3.6), Vector3(0, 8.2, -1.6), Color("#4a565c"), false)
	WorldKit.box(n, Vector3(8.8, 0.5, 4.0), Vector3(0, 9.3, -1.6), Color("#4f8a4a"), false)
	WorldKit.cylinder(n, 2.6, 0.08, Vector3(0, 0.03, -0.2), Color("#5fa6d8"), false)
	var spray := FX.emitter({"amount": 60, "life": 1.1, "one_shot": false, "explosive": 0.0, "spread": 50.0, "dir": Vector3.UP, "vel_min": 0.6,
		"vel_max": 1.6, "gravity": Vector3(0, -2.5, 0), "size": 0.22, "color": Color(1, 1, 1, 0.55), "box": Vector3(1.9, 0.2, 0.4)})
	n.add_child(spray)
	spray.position = Vector3(0, 0.25, -0.2)
	spray.emitting = true
	return n


## Nitro Dash: der Lumos-Ring des Spiels (eingefrorene Trailer-Kopie, trailer_track.gd) mit Kulisse wie im Rennen –
## geschlossene Strecke, Banden, Tribünen, Zieltor, Horizont. Liegt im Ursprung (immer nur ein Set sichtbar).
func _build_race() -> Node3D:
	var s := Node3D.new()
	s.name = "Race"
	add_child(s)
	_track = RaceTrack.new()
	s.add_child(_track)
	_track.build(preload("res://trailer/trailer_track.gd").lumos_ring())   # eingefrorener Stand (Kamerafahrten)
	WorldKit.box(s, Vector3(700, 1, 700), Vector3(80, -0.8, 20), Color("#4c9a36"), false)
	if not ("--no-bd" in OS.get_cmdline_user_args()):
		WorldKit.backdrop(s, "meadow", Color("#4c9a36"), -0.85, Vector3(80, 0, 20))
	var keys := ["race/tree_large", "race/tree_small", "nat/tree_oak", "nat/tree_default", "race/tent", "race/billboard", "race/banner_tower_red",
		"race/banner_tower_green", "race/radar", "race/pits"]
	var near := ["race/barrier_red", "race/barrier_white", "race/light_post", "race/flag_checkers", "race/pylon"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var hw := _track.width * 0.5
	var ts := 0.0
	while ts < _track.length:
		var fr := _track.frame(ts)
		if fr.basis.y.dot(Vector3.UP) > 0.95 and fr.origin.y < 2.5 and fr.origin.y > -1.5 and not _track.is_glide(ts) and not _track.is_loop(ts):
			for side: float in [-1.0, 1.0]:
				var p: Vector3 = fr.origin + fr.basis.x * side * (hw + rng.randf_range(2.5, 4.0))
				p.y = 0.0
				if rng.randf() < 0.6 and _track.min_dist_to_track(p) > hw + 1.0:
					var n := WorldKit.place(s, near[rng.randi() % near.size()], p, 0.0, 3.0, false, false)
					n.look_at(p + fr.basis.z, Vector3.UP)
				var far_p: Vector3 = fr.origin + fr.basis.x * side * (hw + rng.randf_range(9.0, 26.0))
				far_p.y = 0.0
				if rng.randf() < 0.6 and _track.min_dist_to_track(far_p) > hw + 5.0:
					var k: String = keys[rng.randi() % keys.size()]
					WorldKit.place(s, k, far_p, rng.randf() * 360.0, rng.randf_range(3.0, 5.0), false, rng.randf() < 0.4)
		ts += 9.0
	# Fahrbahn: eigene Kopie des Straßen-Shaders nur für den Trailer – die Oberseite der Fahrbahn ist im Mesh die
	# Rückseite, ihre Normale wird sonst nach unten gedreht und die Sonne erreicht den Asphalt nicht.
	for c in _track.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).material_override is ShaderMaterial:
			var src := (c as MeshInstance3D).material_override as ShaderMaterial
			var sh2 := Shader.new()
			sh2.code = src.shader.code if src.shader.code.contains("FRONT_FACING") else src.shader.code.replace("void fragment() {", "void fragment() {\n\tif (!FRONT_FACING) NORMAL = -NORMAL;")
			var m2 := ShaderMaterial.new()
			m2.shader = sh2
			m2.set_shader_parameter("track_len", _track.length)
			(c as MeshInstance3D).material_override = m2
			break
	var f0 := _track.frame(0.0)
	var gate := Assets.spawn("toy/gate_finish", s, f0.origin, 0.0, 1.0)
	gate.global_transform = Transform3D(f0.basis.scaled(Vector3.ONE * (_track.width / 1.55 * 1.05)), f0.origin)
	for i in 5:
		var f2 := _track.frame(_track.length - 30.0 + i * 12.0)
		var p2 := f2.origin - f2.basis.x * (hw + 6.0)
		p2.y = 0.0
		var gs := WorldKit.place(s, "race/grandstand_round", p2, 0.0, 5.0, false)
		gs.look_at(f2.origin, Vector3.UP)
	for kv in _karts:
		kv.reparent(s)
	var k4 := KartVisual.new()
	s.add_child(k4)
	k4.setup("kart/oodi", "hero/ranger", 3, 2.0)
	_karts.append(k4)
	for kv in _karts:
		kv.visible = false
	return s


func _track_fwd(s: float) -> Vector3:
	return (_track.frame(s + 1.0).origin - _track.frame(s).origin).normalized()


## Punkt in Streckenkoordinaten: s entlang der Strecke, x nach rechts, h nach oben.
func _track_pt(s: float, x: float, h: float) -> Vector3:
	var fr := _track.frame(s)
	var up := fr.basis.y.normalized()
	return fr.origin + _track_fwd(s).cross(up).normalized() * x + up * h


func _kart_xf(s: float, x: float, yaw: float) -> Transform3D:
	var up := _track.frame(s).basis.y.normalized()
	var fwd := _track_fwd(s)
	var right := fwd.cross(up).normalized()
	return Transform3D(Basis.looking_at((fwd * cos(yaw) + right * sin(yaw)).normalized(), up), _track_pt(s, x, 0.05))


## Kurveninnenseite (+1 rechts, −1 links) der Drift-Kurve.
func _drift_inner() -> float:
	var s := _track.point_s[2] + 14.0
	var right := _track_fwd(s).cross(Vector3.UP).normalized()
	return signf(right.dot(_track.frame(s + 22.0).origin - _track.frame(s - 8.0).origin))


## Renn-Einstellung k (0 Start · 1 Drift · 2 Überholen · 3 Ziel) zum Anteil u → je Kart [s, x, Gierwinkel, Tempo, Boost].
## Reine Funktion der Zeit: Karts und Kamera lesen denselben Zustand, bildgenau.
func _race_state(k: int, u: float) -> Array:
	var sh := 4.0 * BEAT
	var ln := _track.length
	var st: Array = []
	match k:
		0:   # Startaufstellung – jeder kommt etwas anders weg, der Held am besten
			for g: Array in [[-3.0, -3.2, 50.0, 0.0], [-3.0, 3.2, 45.0, 0.06], [-9.5, -3.2, 42.0, 0.1], [-9.5, 3.2, 39.0, 0.14]]:
				var uu := clampf((u - float(g[3])) / (1.0 - float(g[3])), 0.0, 1.0)
				st.append([float(g[0]) + float(g[2]) * uu * uu * (1.6 - 0.6 * uu), float(g[1]), 0.0,
					float(g[2]) * (3.2 * uu - 1.8 * uu * uu) / sh, uu > 0.05 and uu < 0.7])
		1:   # Drift: von außen an den Scheitel, das Heck bricht aus und fängt sich
			var s0 := _track.point_s[2] - 14.0
			var inner := _drift_inner()
			var e1 := u * u * (3.0 - 2.0 * u)
			var slide := sin(clampf(u * 1.12, 0.0, 1.0) * PI)
			st.append([s0 + 58.0 * u, inner * lerpf(-4.2, 3.6, e1), inner * 0.68 * slide, 33.0, false])
			st.append([s0 - 10.0 + 55.0 * u, inner * lerpf(-1.0, -4.5, e1), inner * 0.34 * slide, 31.5, false])
			st.append([s0 - 19.0 + 54.0 * u, inner * 2.0, inner * 0.22 * slide, 31.0, false])
			st.append([s0 - 30.0 + 54.0 * u, -inner * 2.5, 0.0, 31.0, false])
		2:   # Überholen: im Windschatten, Boost, ausscheren, vorbeiziehen und wieder einscheren
			var e2 := u * u * (3.0 - 2.0 * u)
			var lane := lerpf(lerpf(-2.3, 1.8, smoothstep(0.2, 0.5, u)), -1.6, smoothstep(0.74, 1.0, u))
			st.append([ln - 86.0 + 52.0 * u + 16.0 * e2, lane, 0.0, 30.0 + 55.0 * u * (1.0 - u), u > 0.25 and u < 0.85])
			st.append([ln - 76.0 + 52.0 * u, -2.6 + 0.35 * smoothstep(0.55, 0.75, u) * (1.0 - smoothstep(0.75, 1.0, u)), 0.0, 30.0, false])
			st.append([ln - 92.0 + 51.0 * u, -0.5, 0.0, 29.5, false])
			st.append([ln - 101.0 + 50.0 * u, 3.0, 0.0, 29.0, false])
		_:   # Zieldurchfahrt
			st.append([ln - 21.0 + 60.0 * u, 2.6, 0.0, 34.5, true])
			st.append([ln - 28.0 + 58.0 * u, -2.6, 0.0, 33.5, false])
			st.append([ln - 41.0 + 57.0 * u, -0.3, 0.0, 33.0, false])
			st.append([ln - 52.0 + 56.0 * u, 3.4, 0.0, 32.0, false])
	return st


func _race_shot() -> Vector2:
	var sh := 4.0 * BEAT
	var rt := (t - (MONTAGE_T0 + 7.0 * sh)) / sh
	var k := clampi(int(rt), 0, 3)
	return Vector2(k, clampf(rt - k, 0.0, 1.0))


func _drive_karts(delta: float) -> void:
	if _set_now != "race":
		return
	var rs := _race_shot()
	var st := _race_state(int(rs.x), rs.y)
	# Nachbarzustände (±du) → Fahrtrichtung und Querbeschleunigung aus der tatsächlichen Bahn
	var du := 0.012
	var hdt := du * 4.0 * BEAT
	var st0 := _race_state(int(rs.x), maxf(rs.y - du, 0.0))
	var st2 := _race_state(int(rs.x), minf(rs.y + du, 1.0))
	for j in _karts.size():
		var kv := _karts[j]
		var e: Array = st[j]
		var drift := float(e[2])
		var p0 := _track_pt(float(st0[j][0]), float(st0[j][1]), 0.0)
		var p1 := _track_pt(float(e[0]), float(e[1]), 0.0)
		var p2 := _track_pt(float(st2[j][0]), float(st2[j][1]), 0.0)
		var fwd_t := _track_fwd(float(e[0]))
		var right_t := fwd_t.cross(Vector3.UP).normalized()
		var vel := (p2 - p0) / (2.0 * hdt)
		var head := atan2(vel.dot(right_t), maxf(vel.dot(fwd_t), 0.5))   # Nase zeigt dorthin, wo das Kart hinfährt
		var acc := (p2 - 2.0 * p1 + p0) / (hdt * hdt)
		var right_k := (fwd_t * cos(head) + right_t * sin(head)).cross(Vector3.UP).normalized()
		var lat := clampf(acc.dot(right_k), -45.0, 45.0)
		var sc := kv.scale
		kv.visible = true
		kv.global_transform = _kart_xf(float(e[0]), float(e[1]), head)
		kv.scale = sc
		var ddir := int(signf(drift)) if absf(drift) > 0.12 else 0
		kv.update_visual(float(e[3]), clampf(head * 3.0 + lat * 0.02 + drift * 0.8, -1.0, 1.0), ddir, 2 if absf(drift) > 0.3 else 0,
			bool(e[4]), false, delta, drift * 1.15, lat)
	_spark_acc += delta
	if absf(float(st[0][2])) > 0.3 and _spark_acc >= 0.05:   # Funken am Heck, zeitbasiert
		_spark_acc = 0.0
		var xf := _karts[0].global_transform
		FX.sparks(xf.origin + xf.basis.z.normalized() * 1.4 + Vector3.UP * 0.2, Color(0.5, 0.8, 1.0), 4, 0.5)


## Kamera im Rennen: fährt mit (in Streckenkoordinaten), leicht nachgeführt – Tempo durch Nähe zum Boden, weite
## Brennweite in der Verfolgung und Vorbeiflug dicht an der Linse.
func _race_camera() -> void:
	var rs := _race_shot()
	var k := int(rs.x)
	var u := rs.y
	var st := _race_state(k, u)
	var a := _track_pt(float(st[0][0]), float(st[0][1]), 0.0)
	var b := _track_pt(float(st[1][0]), float(st[1][1]), 0.0)
	var pos := Vector3.ZERO
	var lk := Vector3.ZERO
	var fov := 60.0
	match k:
		0:   # am Boden vor der Startlinie: die Karts schießen an der Linse vorbei
			pos = _track_pt(15.0, 5.8, 0.55)
			lk = a.lerp(b, 0.35) + Vector3.UP * 0.7
			fov = lerpf(64.0, 54.0, u)
		1:   # Verfolger: tief hinter dem driftenden Kart, auf der Außenseite
			var inner := _drift_inner()
			pos = _track_pt(float(st[0][0]) - 6.2, float(st[0][1]) - inner * 1.8, 1.75)
			lk = _track_pt(float(st[0][0]) + 7.0, float(st[0][1]) + inner * 2.0, 0.7)
			fov = 74.0
		2:   # Parallelfahrt knapp über dem Asphalt
			pos = _track_pt(float(st[1][0]) + 8.5, 7.2, 0.95)
			lk = a.lerp(b, 0.5) + Vector3.UP * 0.8
			fov = 56.0
		_:   # hinter der Ziellinie, Schwenk mit dem Sieger
			pos = _track_pt(10.0, -5.0, 0.6)
			lk = a + Vector3.UP * 0.9
			fov = lerpf(58.0, 66.0, u)
	if _rc_shot != k:
		_rc_shot = k
		_rc_pos = pos
		_rc_look = lk
	var dt := get_process_delta_time()
	_rc_pos = _rc_pos.lerp(pos, 1.0 - exp(-dt / 0.09))
	_rc_look = _rc_look.lerp(lk, 1.0 - exp(-dt / 0.07))
	cam.global_position = _rc_pos + Vector3(sin(t * 31.0), sin(t * 37.0 + 1.0), 0.0) * (0.012 if k == 1 else 0.004)
	cam.fov = fov
	cam.look_at(_rc_look, Vector3.UP)


## Kontrollbilder der Mimik: alle vier Darsteller nebeneinander, je Ausdruck ein PNG (… -- --trailer-faces=/ordner).
func _run_face_test() -> void:
	set_process(false)
	_ui.visible = false
	_use_env("day")
	WorldKit.box(self, Vector3(30, 1, 30), Vector3(0, -0.5, 0), Color("#6fbf55"), false)
	for i in 4:
		heroes[i].visible = true
		heroes[i].global_position = Vector3(-2.1 + i * 1.4, 0, 0)
		heroes[i].face_now(Vector3(0.15 * (1.5 - i), 0, 1))
	cam.global_position = Vector3(0, 1.7, 5.2)
	cam.look_at(Vector3(0, 1.6, 0))
	cam.fov = 34.0
	DirAccess.make_dir_recursive_absolute(_face_test)
	for name in ["neutral", "smile", "laugh", "awe", "scared", "determined", "asleep", "plead"]:
		for i in 4:
			faces[i].blink_on = false
			faces[i].set_expr(name, 0.0)
			faces[i].laugh = 1.0 if name == "laugh" else 0.0
			bodies[i].laugh = faces[i].laugh
			bodies[i].dt = 1.0 / 60.0
		for k in 8:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(_face_test.path_join(name + ".png"))
	get_tree().quit()
