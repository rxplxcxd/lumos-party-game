class_name LumosLocomotion
extends RefCounted
## Fortbewegung des Character-Frameworks: wählt und überblendet Clips nach Zustand und Tempo und hält die
## Schritte synchron zur tatsächlichen Bewegung.
##
##  * Schritt-Tempo je Clip wird aus dem Clip vermessen (Rückwärtsgeschwindigkeit des Standfußes) – die
##    Abspielgeschwindigkeit folgt dem echten Tempo, die Füße rutschen nicht.
##  * Zustände: idle · walk · run · jump · fall · land · stumble · dance (weitere über play_action()).
##  * Beschleunigen/Bremsen/Drehen: steer() liefert eine geglättete Geschwindigkeit (Trägheit).
## Signal: state_changed(from, to).

signal state_changed(from: String, to: String)

static var _stride_cache := {}   # "modell|clip" → m/s

var rig: CharacterRig
var cfg := LumosActorConfig.new()
var state := "idle"
var velocity := Vector3.ZERO       # geglättete Ist-Geschwindigkeit (von steer())
var accel_local := Vector3.ZERO    # Beschleunigung im Figurenraum (für die Körper-Neigung)
var turn_speed := 0.0              # rad/s
var walk_nat := 1.0
var run_nat := 3.0
var _action_until := 0.0
var _t := 0.0
var _air := false


func setup(p_rig: CharacterRig, config: LumosActorConfig = null) -> void:
	rig = p_rig
	if config:
		cfg = config
	walk_nat = cfg.walk_speed if cfg.walk_speed > 0.0 else stride_speed(rig, "walk", 1.0)
	run_nat = cfg.run_speed if cfg.run_speed > 0.0 else stride_speed(rig, "run", 3.0)


## Tempo, bei dem der Standfuß des Clips am Boden stillsteht (m/s, mit Figurenskalierung). Zwischengespeichert.
static func stride_speed(r: CharacterRig, clip_name: String, fallback: float) -> float:
	var key := r.model_key + "|" + clip_name
	var scl := r.skel.global_transform.basis.get_scale().z if r.skel and r.skel.is_inside_tree() else 1.0
	if _stride_cache.has(key):
		return float(_stride_cache[key]) * scl
	var v := _measure(r, clip_name)
	_stride_cache[key] = v if v > 0.2 and v < 9.0 else fallback
	return float(_stride_cache[key]) * scl


static func _measure(r: CharacterRig, clip_name: String) -> float:
	if r.skel == null or r.anim == null or not r.has_clip(clip_name):
		return 0.0
	var fb := r.skel.find_bone("foot.l")
	var an: Animation = r.anim.get_animation(r._map[clip_name])
	if fb < 0 or an == null:
		return 0.0
	var chain: Array[int] = []
	var bi := fb
	while bi >= 0:
		chain.append(bi)
		bi = r.skel.get_bone_parent(bi)
	var tracks := {}
	for ti in an.get_track_count():
		var b := r.skel.find_bone(String(an.track_get_path(ti)).get_slice(":", 1))
		if b in chain:
			if not tracks.has(b):
				tracks[b] = [-1, -1]
			if an.track_get_type(ti) == Animation.TYPE_POSITION_3D:
				tracks[b][0] = ti
			elif an.track_get_type(ti) == Animation.TYPE_ROTATION_3D:
				tracks[b][1] = ti
	var smp: Array = []   # [Fußhöhe, Rückwärtsgeschwindigkeit]
	var prev := 0.0
	var n := 60
	for k in n + 1:
		var tm := an.length * k / float(n)
		var x := Transform3D.IDENTITY
		for b in chain:
			var rest := r.skel.get_bone_rest(b)
			var tr: Array = tracks.get(b, [-1, -1])
			var pos: Vector3 = an.position_track_interpolate(tr[0], tm) if int(tr[0]) >= 0 else rest.origin
			var rot: Quaternion = an.rotation_track_interpolate(tr[1], tm) if int(tr[1]) >= 0 else rest.basis.get_rotation_quaternion()
			x = Transform3D(Basis(rot), pos) * x
		if k > 0:
			smp.append([x.origin.y, (prev - x.origin.z) / (an.length / float(n))])
		prev = x.origin.z
	# Standphase = der Fuß ist am tiefsten; dort ist seine Rückwärtsgeschwindigkeit das Tempo über Grund
	var min_y := INF
	for e in smp:
		min_y = minf(min_y, float(e[0]))
	var sum := 0.0
	var cnt := 0
	for e in smp:
		if float(e[0]) < min_y + 0.012 and float(e[1]) > 0.0:
			sum += float(e[1])
			cnt += 1
	return sum / cnt if cnt > 0 else 0.0


## Wunschgeschwindigkeit → geglättete Geschwindigkeit mit Anfahren, Ausrollen und begrenzter Drehrate.
## Rückgabe = Geschwindigkeit, mit der die Figur dieses Bild bewegt werden soll.
func steer(wish: Vector3, delta: float) -> Vector3:
	var before := velocity
	var rate := cfg.accel if wish.length() > velocity.length() else cfg.decel
	velocity = velocity.move_toward(Vector3(wish.x, 0, wish.z), rate * delta)
	var acc := (velocity - before) / maxf(delta, 0.0001)
	accel_local = rig.global_basis.inverse() * acc if rig else acc
	return velocity


## Animation an die tatsächliche Bewegung anpassen. vel = Welt-Geschwindigkeit, grounded = am Boden.
func update(vel: Vector3, grounded: bool, delta: float) -> void:
	_t += delta
	if rig == null:
		return
	var flat := Vector3(vel.x, 0, vel.z)
	var spd := flat.length()
	if spd > 0.15:   # Blickrichtung folgt der Bewegung mit begrenzter Drehrate
		var before := rig.rotation.y
		rig.face(flat, delta, cfg.turn_rate)
		turn_speed = lerpf(turn_speed, wrapf(rig.rotation.y - before, -PI, PI) / maxf(delta, 0.0001), 0.2)
	else:
		turn_speed = lerpf(turn_speed, 0.0, 0.2)
	if _t < _action_until:
		return
	if not grounded:
		_air = true
		_go("jump" if vel.y > 0.5 else "fall", "jump_air", 0.16, 1.0)
		return
	if _air:
		_air = false
		if rig.has_clip("land"):
			_go("land", "land", 0.08, 1.4)
			_action_until = _t + 0.18
			rig.land_impact(clampf(absf(vel.y) / 8.0, 0.3, 1.0))
			return
	var moving := state in ["walk", "run"]
	if spd < (0.12 if moving else 0.3):
		_go("idle", "idle", 0.32, 1.0)
	elif spd < walk_nat * (1.5 if state == "run" else 1.85):
		_go("walk", "walk", 0.24, clampf(spd / walk_nat, 0.45, 1.9))
	else:
		_go("run", "run", 0.22, clampf(spd / run_nat, 0.6, 1.75))


## Einmalige Aktion mit Überblendung (z. B. "stumble" → Clip "hit_b", "dance" → "dance"); danach übernimmt update().
func play_action(name: String, clip := "", secs := 0.0, blend := 0.2, speed := 1.0) -> void:
	var c: String = clip if clip != "" else {"stumble": "hit_b", "dance": "dance", "fall_down": "lie", "cheer": "cheer", "throw": "throw"}.get(name, name)
	if rig == null or not rig.has_clip(c):
		push_warning("LumosLocomotion: Clip '%s' fehlt" % c)
		return
	var dur := secs if secs > 0.0 else rig.clip_length(c) / maxf(speed, 0.1)
	_go(name, c, blend, speed, true)
	_action_until = _t + dur


func stop_action() -> void:
	_action_until = 0.0


func _go(st: String, clip: String, blend: float, speed: float, force := false) -> void:
	rig.play(clip, blend, speed, force)
	if st != state:
		var from := state
		state = st
		state_changed.emit(from, st)
