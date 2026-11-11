class_name Racer
extends Node3D
## Ein Kart in Nitro Dash. Arcade-Physik im Strecken-Raum:
##   s = Meter entlang der Strecke, x = seitlich (rechts +), h = Höhe über Fahrbahn,
##   psi = Gierwinkel relativ zur Fahrtrichtung, v = Geschwindigkeit.
## Knackiges Handling, dreistufiger Drift-Boost (Blau -> Orange -> Regenbogen), Rampen,
## Gleiter-Passagen, Unterwasser-Abschnitte und Loopings (Kart klebt dank Rahmen an der Bahn).

signal lap_done(r: Racer, lap: int)
signal item_changed(r: Racer)

const MAX_SPEED := 27.5
const BOOST_SPEED := 38.0
const ACCEL := 12.5
const BRAKE := 26.0
const TURN := 1.75
## Lenkgefühl (Mensch): Eingabe wird weich angefahren, kehrt etwas schneller zur Mitte zurück und
## die Gierrate hat Trägheit – wie bei klassischen Arcade-Kart-Spielen.
const STEER_RISE := 3.4
const STEER_FALL := 5.5
const YAW_RESPONSE := 5.5
const DRIFT_LEVELS := [0.6, 1.35, 2.2]
const DRIFT_BOOST := [0.55, 1.0, 1.6]
const RADIUS := 1.25
const GRAVITY := 32.0

var idx := 0
var slot := -1                  # Spieler-Slot (0-3) oder -1 für Zusatz-CPU
var display_name := ""
var color := Color.WHITE
var is_cpu := true
var cpu_level := 1
var track: RaceTrack
var visual: KartVisual

var s := 0.0
var x := 0.0
var h := 0.0
var psi := 0.0
var v := 0.0
var vh := 0.0
var lap := 0
var finished := false
var finish_time := 0.0
var place := 1
var progress := 0.0
var item := ""
var rolling := 0.0
var started := false

var drift_dir := 0
var drift_t := 0.0
var drift_level := 0
var boost_t := 0.0
var stun_t := 0.0
var shrink_t := 0.0
var invuln_t := 0.0
var gliding := false
var airborne := false
var speed_mult := 1.0
var steer_in := 0.0
var _steer_s := 0.0
var _yaw_rate := 0.0
var _half_passed := false
var _glider: Node3D
var _engine: AudioStreamPlayer3D
var _ai_offset := 0.0
var _ai_item_t := 0.0
var _scale := 1.0
var _was_drift_held := false
var _prev_boost_on := false

# --- Online: entfernte Karts werden aus Zustands-Snapshots interpoliert ---
const INTERP_DELAY := 0.1         # Jitter-Puffer (s)
const MAX_EXTRAPOLATE := 0.25
var remote := false
var _snaps: Array[Dictionary] = []


func setup(i: int, p_slot: int, kart_key: String, hero_key: String, name_: String, col: Color, rt: RaceTrack) -> Racer:
	idx = i
	slot = p_slot
	track = rt
	display_name = name_
	color = col
	is_cpu = p_slot < 0 or Game.players[p_slot].cpu
	cpu_level = Game.race_cfg.cpu_level if p_slot < 0 else (Game.players[p_slot].cpu_level if is_cpu else 2)
	visual = KartVisual.new()
	add_child(visual)
	visual.setup(kart_key, hero_key, p_slot, 2.2)
	_glider = _make_glider()
	_glider.visible = false
	visual.body.add_child(_glider)
	_engine = Audio.make_loop("engine", self, -16.0 if is_cpu else -9.0)
	_ai_offset = randf_range(-0.25, 0.25)
	return self


func _make_glider() -> Node3D:
	var g := Node3D.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = color.lightened(0.2)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(3.2, 0.08, 1.6)
		pm.material = m
		wing.mesh = pm
		wing.position = Vector3(side * 1.9, 2.4, 0.2)
		wing.rotation = Vector3(0, 0, side * 0.12)
		g.add_child(wing)
	var mast := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.06
	cm.height = 1.5
	cm.material = WorldKit.mat(Color(0.3, 0.3, 0.35))
	mast.mesh = cm
	mast.position = Vector3(0, 1.7, 0.2)
	g.add_child(mast)
	return g


func place_on_grid(s0: float, x0: float) -> void:
	s = track.wrap_s(s0)
	x = x0
	h = 0.0
	psi = 0.0
	v = 0.0
	# Startaufstellung liegt hinter der Ziellinie: erste Überquerung startet Runde 0
	lap = -1
	_half_passed = true
	progress = lap * track.length + s
	_apply_transform(0.0)


## Eingaben (Mensch oder KI) -> Steuerwerte.
func _read_input(delta: float) -> Dictionary:
	if is_cpu:
		return _ai_input(delta)
	var mv := InputHub.move(slot)
	var accel := InputHub.held(slot, "a") or mv.y < -0.5
	var brake := InputHub.held(slot, "b") or mv.y > 0.6
	if Game.is_touch_device and Game.settings.auto_accel and InputHub.last_device == "touch":
		accel = not InputHub.held(slot, "b")
	# Weiche Lenkung: Ansprechkurve (feine Korrekturen um die Mitte) × Empfindlichkeit, zeitlich geglättet
	var sens := clampf(float(Game.settings.get("steer_sens", 1.0)), 0.4, 1.6)
	var raw := clampf(mv.x, -1.0, 1.0)
	var target := signf(raw) * pow(absf(raw), 1.45) * sens
	var rate := STEER_RISE * (0.7 + sens * 0.3) if absf(target) > absf(_steer_s) and signf(target) == signf(_steer_s) or _steer_s == 0.0 else STEER_FALL
	_steer_s = move_toward(_steer_s, clampf(target, -1.0, 1.0), rate * delta)
	return {"steer": _steer_s, "accel": accel, "brake": brake and not accel, "drift": InputHub.held(slot, "r"),
		"item": InputHub.pressed(slot, "x"), "pitch": mv.y}


## Kompakter Zustand für das Netz (unzuverlässiger Kanal, 20–30 Hz).
func net_state() -> Dictionary:
	return {"k": "rs", "i": idx, "s": snappedf(s, 0.01), "x": snappedf(x, 0.01), "h": snappedf(h, 0.01), "p": snappedf(psi, 0.001),
		"v": snappedf(v, 0.01), "dd": drift_dir, "dl": drift_level, "b": 1 if boost_t > 0.0 else 0, "g": 1 if gliding else 0,
		"a": 1 if airborne else 0, "l": lap, "fi": 1 if finished else 0, "ft": snappedf(finish_time, 0.01), "it": item,
		"sh": 1 if shrink_t > 0.0 else 0}


func push_snapshot(d: Dictionary) -> void:
	d["rt"] = Time.get_ticks_msec() / 1000.0
	_snaps.append(d)
	if _snaps.size() > 16:
		_snaps.pop_front()


## Interpolation zwischen zwei Snapshots (100 ms in der Vergangenheit), sonst kurze Extrapolation.
func _remote_tick(delta: float) -> void:
	if _snaps.is_empty():
		_apply_transform(delta)
		return
	var now := Time.get_ticks_msec() / 1000.0 - INTERP_DELAY
	var a: Dictionary = {}
	var b: Dictionary = {}
	for i in range(_snaps.size() - 1, -1, -1):
		if float(_snaps[i].rt) <= now:
			a = _snaps[i]
			if i + 1 < _snaps.size():
				b = _snaps[i + 1]
			break
	var last: Dictionary = _snaps[_snaps.size() - 1]
	if a.is_empty():
		a = _snaps[0]
	if b.is_empty():
		var dt := clampf(now - float(a.rt), 0.0, MAX_EXTRAPOLATE)
		s = track.wrap_s(float(a.s) + float(a.v) * cos(float(a.p)) * dt)
		x = float(a.x) + float(a.v) * sin(float(a.p)) * dt
		h = float(a.h)
		psi = float(a.p)
		v = float(a.v)
	else:
		var span := maxf(float(b.rt) - float(a.rt), 0.001)
		var t := clampf((now - float(a.rt)) / span, 0.0, 1.0)
		var ds := fposmod(float(b.s) - float(a.s) + track.length * 0.5, track.length) - track.length * 0.5
		s = track.wrap_s(float(a.s) + ds * t)
		x = lerpf(float(a.x), float(b.x), t)
		h = lerpf(float(a.h), float(b.h), t)
		psi = lerp_angle(float(a.p), float(b.p), t)
		v = lerpf(float(a.v), float(b.v), t)
	drift_dir = int(last.dd)
	drift_level = int(last.dl)
	boost_t = 0.15 if int(last.b) == 1 else 0.0
	airborne = int(last.a) == 1
	shrink_t = 0.2 if int(last.get("sh", 0)) == 1 else 0.0
	if gliding != (int(last.g) == 1):
		gliding = int(last.g) == 1
		_glider.visible = gliding
	item = String(last.it)
	if int(last.fi) == 1 and not finished:
		finished = true
		finish_time = float(last.ft)
	var nl := int(last.l)
	if nl > lap:
		lap = nl
		lap_done.emit(self, lap)
	progress = lap * track.length + s
	_scale = lerpf(_scale, 0.55 if shrink_t > 0.0 else 1.0, clampf(delta * 6.0, 0, 1))
	visual.scale = Vector3.ONE * _scale
	if _engine:
		_engine.pitch_scale = 0.7 + absf(v) / MAX_SPEED * 0.9 + (0.25 if boost_t > 0.0 else 0.0)
	_apply_transform(delta)


func tick(delta: float) -> void:
	if remote:
		_remote_tick(delta)
		return
	if not started:
		_apply_transform(delta)
		return
	var inp := _read_input(delta) if not finished else _ai_input(delta)
	stun_t = maxf(0.0, stun_t - delta)
	invuln_t = maxf(0.0, invuln_t - delta)
	boost_t = maxf(0.0, boost_t - delta)
	shrink_t = maxf(0.0, shrink_t - delta)
	_scale = lerpf(_scale, 0.55 if shrink_t > 0.0 else 1.0, clampf(delta * 6.0, 0, 1))
	visual.scale = Vector3.ONE * _scale
	var water := track.is_water(s)
	var max_v := (BOOST_SPEED if boost_t > 0.0 else MAX_SPEED) * speed_mult * (0.88 if water else 1.0) * (0.75 if shrink_t > 0.0 else 1.0)
	# Längsdynamik
	var steer: float = clampf(inp.steer, -1.0, 1.0) if stun_t <= 0.0 else 0.0
	steer_in = steer
	if stun_t > 0.0:
		v = move_toward(v, 0.0, BRAKE * 1.2 * delta)
	elif boost_t > 0.0:
		v = move_toward(v, max_v, ACCEL * 3.0 * delta)
	elif inp.accel:
		v = move_toward(v, max_v, ACCEL * delta * (1.4 if v < 12.0 else 1.0))
	elif inp.brake:
		v = move_toward(v, -8.0, BRAKE * delta)
	else:
		v = move_toward(v, 0.0, 6.0 * delta)
	if v > max_v:
		v = move_toward(v, max_v, 14.0 * delta)
	# Drift
	var drift_held: bool = inp.drift and stun_t <= 0.0
	if drift_held and not _was_drift_held and absf(steer) > 0.25 and v > 12.0 and not airborne:
		drift_dir = 1 if steer > 0 else -1
		drift_t = 0.0
		drift_level = 0
		vh = 4.5
		h = maxf(h, 0.01)
		visual.hero.squash(1.1, 0.9, 0.2)
		Audio.sfx("jump", global_position, -10.0, 1.3)
	if drift_dir != 0:
		if not drift_held or v < 8.0 or stun_t > 0.0:
			_release_drift()
		else:
			drift_t += delta * (0.75 + 0.5 * absf(clampf(steer * drift_dir, 0.0, 1.0)))
			var lvl := 0
			for k in 3:
				if drift_t >= DRIFT_LEVELS[k]:
					lvl = k + 1
			if lvl > drift_level:
				drift_level = lvl
				Audio.sfx("spark", global_position, -6.0, 0.9 + lvl * 0.15)
				if not is_cpu:
					InputHub.rumble(slot, 0.2 + lvl * 0.15, 0.08)
			steer = float(drift_dir) * (0.6 + 0.45 * clampf(steer * drift_dir, -0.8, 1.0))
	_was_drift_held = drift_held
	# Lenkung / Gier relativ zur Strecke
	var turn := TURN * clampf(absf(v) / 14.0, 0.25, 1.0) * (1.25 if drift_dir != 0 else 1.0)
	if airborne and not gliding:
		turn *= 0.5
	var on_ice := track.is_ice(s) and not airborne
	if on_ice:
		turn *= 0.7   # Eis: träge Lenkung, der Kart schiebt über die Vorderräder
	var kappa := track.curvature(s)
	# Gier-Trägheit: Das Kart dreht nicht schlagartig ein, sondern baut die Drehrate auf
	_yaw_rate = lerpf(_yaw_rate, steer * turn, clampf(delta * (YAW_RESPONSE * (1.6 if drift_dir != 0 else 1.0)), 0.0, 1.0))
	psi += (_yaw_rate - kappa * v * cos(psi)) * delta
	psi = clampf(psi, -1.1, 1.1)
	if drift_dir == 0 and not airborne and not on_ice:
		psi = lerpf(psi, psi * 0.9, delta * 2.0)
	# Bewegung
	var ds := v * cos(psi) * delta
	var dx := v * sin(psi) * delta
	var old_s := s
	s = track.wrap_s(s + ds)
	x += dx
	_lap_check(old_s, ds)
	# Leitplanken
	var hw := track.width * 0.5 - RADIUS
	if absf(x) > hw and not gliding:
		x = signf(x) * hw
		if absf(psi) > 0.05:
			psi = -psi * 0.35
			v *= 0.86
			if absf(v) > 10.0:
				FX.sparks(global_position + global_basis.x * signf(x) * 1.2 + Vector3.UP * 0.5, Color(1, 0.8, 0.3), 8)
				Audio.sfx("metal_light", global_position, -8.0)
				if not is_cpu:
					Juice.shake(0.12)
					InputHub.rumble(slot, 0.35, 0.08)
	# Vertikal: Rampen, Gleiter, Schwerkraft
	var glide := track.is_glide(s)
	if glide and not gliding:
		gliding = true
		_glider.visible = true
		_glider.scale = Vector3(0.05, 1, 1)
		_glider.create_tween().tween_property(_glider, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		vh = maxf(vh, 6.0)
		Audio.sfx("whoosh", global_position)
		if not is_cpu:
			Juice.fov_punch(get_viewport().get_camera_3d(), 8.0, 0.6)
	elif not glide and gliding:
		gliding = false
		var tw := _glider.create_tween()
		tw.tween_property(_glider, "scale", Vector3(0.05, 1, 1), 0.25)
		tw.tween_callback(func() -> void: _glider.visible = false)
	for rs in track.ramp_s:
		var d := track.wrap_s(s - rs)
		if d < ds + 0.5 and d >= 0.0 and h <= 0.05 and not gliding:
			vh = 10.5
			Audio.sfx("boing", global_position, -6.0)
	for b in track.boosts:
		var db := track.wrap_s(s - b.x)
		if db < 3.0 and absf(x - b.y) < 2.4 and h < 0.4:
			if boost_t < 0.5:
				_boost(0.9, false)
	var g := GRAVITY * (0.5 if water else 1.0)
	if gliding:
		g *= 0.22
		vh += -float(inp.get("pitch", 0.0)) * 6.0 * delta
		vh = clampf(vh, -6.0, 6.0)
	if h > 0.0 or vh > 0.0:
		airborne = true
		vh -= g * delta
		h += vh * delta
		if gliding:
			h = clampf(h, 0.0, 9.0)
			if h <= 0.0:
				vh = maxf(vh, 0.0)
		if h <= 0.0 and not gliding:
			h = 0.0
			if vh < -7.0:
				visual.body.scale = Vector3(1.15, 0.8, 1.15)
				visual.body.create_tween().tween_property(visual.body, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				FX.dust(global_position, Color(0.9, 0.85, 0.75), 10, 1.2)
				Audio.sfx("land", global_position, -6.0)
				if not is_cpu:
					Juice.shake(0.18)
					InputHub.rumble(slot, 0.4, 0.1)
			vh = 0.0
			airborne = false
	else:
		airborne = false
	# Items
	if rolling > 0.0:
		rolling -= delta
		if rolling <= 0.0:
			Audio.sfx("item_get", global_position, -4.0 if not is_cpu else -14.0)
			item_changed.emit(self)
	elif item != "" and inp.get("item", false) and stun_t <= 0.0:
		var used := item
		item = ""
		item_changed.emit(self)
		get_parent().call("use_item", self, used)
	_apply_transform(delta)
	# Motor-Sound
	if _engine:
		_engine.pitch_scale = 0.7 + absf(v) / MAX_SPEED * 0.9 + (0.25 if boost_t > 0.0 else 0.0)


func _release_drift() -> void:
	if drift_level > 0:
		_boost(DRIFT_BOOST[drift_level - 1], true)
	drift_dir = 0
	drift_t = 0.0
	drift_level = 0


func _boost(t: float, from_drift: bool) -> void:
	boost_t = maxf(boost_t, t)
	Audio.sfx("boost", global_position, -4.0 if not is_cpu else -12.0)
	if not is_cpu:
		Juice.fov_punch(get_viewport().get_camera_3d(), 10.0 if from_drift else 7.0, 0.5)
		InputHub.rumble(slot, 0.5, 0.2)
	FX.ring(global_position + global_basis.y * 0.5, Color(0.6, 0.9, 1.0, 0.7), 3.5, 0.3)


func _lap_check(old_s: float, ds: float) -> void:
	if not _half_passed and absf(track.wrap_s(s) - track.length * 0.5) < absf(ds) + 1.0:
		_half_passed = true
	if ds > 0.0 and s < old_s and _half_passed:
		_half_passed = false
		lap += 1
		lap_done.emit(self, lap)
	progress = lap * track.length + s


func _apply_transform(delta: float) -> void:
	var fr := track.frame(s)
	var up := fr.basis.y.normalized()
	var pos := fr.origin + fr.basis.x * x + up * (h + 0.05)
	var basis := fr.basis.rotated(up, -psi)
	global_transform = Transform3D(basis, pos)
	visual.update_visual(absf(v), steer_in, drift_dir, drift_level, boost_t > 0.0, airborne, delta)
	visual.visible = invuln_t <= 0.0 or int(invuln_t * 14.0) % 2 == 0


# --- Treffer --------------------------------------------------------------------------------------

func hit(kind: String) -> bool:
	if invuln_t > 0.0 or finished:
		return false
	drift_dir = 0
	drift_level = 0
	match kind:
		"spin":
			stun_t = 1.1
			invuln_t = 1.6
			visual.spin_out(2.0, 1.0)
		"blast":
			stun_t = 1.5
			invuln_t = 2.0
			vh = 11.0
			h = 0.1
			visual.flip(1.0)
			visual.hero.set_soot(3.0)
		"shrink":
			shrink_t = 4.0
			invuln_t = 0.5
			visual.hero.react("shocked")
		"anchor":
			stun_t = 1.0
			invuln_t = 1.6
			s = track.wrap_s(s - 20.0)
			if s > track.length - 25.0 and lap > 0:
				lap -= 1
				_half_passed = true
			progress = lap * track.length + s
			visual.spin_out(1.0, 0.8)
	if not is_cpu:
		InputHub.rumble(slot, 1.0, 0.4)
		Juice.shake(0.4)
	return true


# --- KI --------------------------------------------------------------------------------------------

func _ai_input(delta: float) -> Dictionary:
	var look := clampf(v * 0.55, 8.0, 20.0)
	var k_ahead := track.curvature(s, look)
	var hw := track.width * 0.5 - RADIUS - 0.5
	var target_x := clampf((k_ahead * 70.0) + _ai_offset * hw, -hw, hw)
	# Item-Boxen ansteuern, wenn kein Item
	if item == "" and rolling <= 0.0:
		for rs in track.item_rows:
			var d := track.wrap_s(rs - s)
			if d > 5.0 and d < 40.0:
				target_x = lerpf(target_x, roundf(x / 3.5) * 3.5, 0.5)
	var want_psi := atan2(target_x - x, look)
	var turn_eff := TURN * clampf(absf(v) / 14.0, 0.25, 1.0)
	var k_now := track.curvature(s, 2.0)
	var steer := clampf((want_psi - psi) * 2.6 + k_now * v / maxf(turn_eff, 0.1), -1.0, 1.0)
	var drift := false
	var sharp := absf(k_ahead) > 0.022 and v > 18.0 and cpu_level > 0
	if drift_dir != 0:
		drift = absf(k_ahead) > 0.012 and drift_t < Game.lv([1.0, 1.6, 2.4], cpu_level)
	elif sharp:
		drift = true
		steer = signf(k_ahead) * maxf(absf(steer), 0.6)
	_ai_item_t -= delta
	var use := false
	if item != "" and _ai_item_t <= 0.0:
		_ai_item_t = randf_range(0.8, 2.0)
		use = get_parent().call("ai_wants_item", self)
	return {"steer": steer, "accel": true, "brake": false, "drift": drift, "item": use, "pitch": -0.3 if gliding else 0.0}
