class_name KartVisual
extends Node3D
## Optik eines Karts: Kenney-Kart mit dem gewählten Helden als Fahrer (statt des eingebauten
## Fahrers), Lenkpose per SlapstickModifier, drehende/lenkende Räder, Federung, Neigung,
## Drift-Funken (Blau -> Orange -> Regenbogen), Boost-Flammen, Staubspur.
## Blickrichtung: -Z (Godot-Standard).

const SPARK_COLORS := [Color(0.35, 0.65, 1.0), Color(1.0, 0.6, 0.15), Color(1, 1, 1)]

var body: Node3D
var model: Node3D
var hero: CharacterRig
var wheels: Array[Node3D] = []
var front_wheels: Array[Node3D] = []
var spark_l: CPUParticles3D
var spark_r: CPUParticles3D
var flame: CPUParticles3D
var dust: CPUParticles3D
var kart_scale := 2.2

var _wheel_rot := 0.0
var _hue := 0.0
var _bob := 0.0
# Federung (Feder-Dämpfer je Achse): Einfedern bei Landung, Nicken bei Gas/Bremse, Wanken in Kurven
var _sy := 0.0
var _svy := 0.0
var _pitch := 0.0
var _pitch_v := 0.0
var _roll := 0.0
var _roll_v := 0.0
var _prev_speed := 0.0
var _was_air := false
var _lock_t := 0.0     # während Dreh-/Überschlag-Animationen keine Federung auf die Rotation
const SPRING := 120.0
const DAMP := 11.0


func setup(kart_key: String, hero_key: String, player_idx := -1, scl := 2.2) -> KartVisual:
	kart_scale = scl
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	model = Assets.spawn(kart_key, body)
	model.rotation.y = PI
	model.scale = Vector3.ONE * scl
	for n in _all(model):
		var nm := String(n.name)
		if nm == "character" and n is MeshInstance3D:
			(n as MeshInstance3D).visible = false
		elif nm.begins_with("wheel") and n is Node3D:
			wheels.append(n)
			if nm.contains("front"):
				front_wheels.append(n)
	hero = CharacterRig.new()
	model.add_child(hero)
	hero.setup(hero_key, -1, 0.48 if hero_key.begins_with("hero/") else 1.0)
	hero.position = Vector3(0, 0.3, -0.12)
	hero.rotation.y = PI   # Rig blickt -Z, Kart-Modell-Raum vorne = +Z
	if hero.kind == "kaykit":
		hero.play("sit_chair")
		hero.set_steer_pose(true)
	else:
		hero.play("drive")
	if player_idx >= 0:
		_add_ring(Game.player_color(player_idx))
	spark_l = FX.make_trail(body, "sparks")
	spark_l.position = Vector3(-0.55, 0.2, 0.9) * scl / 2.2
	spark_r = FX.make_trail(body, "sparks")
	spark_r.position = Vector3(0.55, 0.2, 0.9) * scl / 2.2
	flame = FX.make_trail(body, "flame")
	flame.position = Vector3(0, 0.55, 1.35) * scl / 2.2
	dust = FX.make_trail(body, "dust")
	dust.position = Vector3(0, 0.1, 1.2) * scl / 2.2
	return self


func _all(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out


func _add_ring(col: Color) -> void:
	var ring := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(3.4, 3.4) * kart_scale / 2.2
	q.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = FX.tex_ring
	m.albedo_color = Color(col, 0.85)
	q.material = m
	ring.mesh = q
	ring.position.y = 0.05
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)


## Pro Frame: Geschwindigkeit (m/s), Lenkung (-1..1), Drift-Richtung (-1/0/1), Drift-Stufe (0..3).
func update_visual(speed: float, steer: float, drift_dir: int, drift_level: int, boosting: bool, airborne: bool, delta: float) -> void:
	_wheel_rot += speed * delta / 0.42
	for w in wheels:
		w.rotation.x = _wheel_rot
	for fw in front_wheels:
		fw.rotation.y = lerpf(fw.rotation.y, -steer * 0.45, clampf(delta * 10.0, 0, 1))
	_bob += delta * (8.0 + speed * 0.3)
	var dt := maxf(delta, 0.0001)
	var acc := clampf((speed - _prev_speed) / dt, -60.0, 60.0)
	_prev_speed = speed
	# Ziele: Wanken nach außen in Kurven, Nicken beim Beschleunigen (Heck runter) und Bremsen (Nase runter)
	var target_roll := -steer * 0.11 * clampf(speed / 20.0, 0, 1) + float(drift_dir) * 0.16
	var target_pitch := clampf(-acc * 0.0035, -0.09, 0.07)
	if airborne:
		target_pitch = -0.06
	_roll_v += ((target_roll - _roll) * SPRING - _roll_v * DAMP) * dt
	_roll += _roll_v * dt
	_pitch_v += ((target_pitch - _pitch) * SPRING - _pitch_v * DAMP) * dt
	_pitch += _pitch_v * dt
	# Einfedern: Landestoß + leichtes Rütteln der Fahrbahn
	if _was_air and not airborne:
		_svy -= 2.6
	_was_air = airborne
	var road := 0.0 if airborne else sin(_bob) * 0.02 * clampf(speed / 15.0, 0.2, 1.0)
	_svy += ((road - _sy) * SPRING - _svy * (DAMP * 0.8)) * dt
	_sy += _svy * dt
	var target_yaw := float(drift_dir) * 0.42
	_lock_t = maxf(0.0, _lock_t - delta)
	body.rotation.z = _roll
	if _lock_t <= 0.0:
		body.rotation.x = _pitch
		body.rotation.y = lerpf(body.rotation.y, target_yaw, clampf(delta * 6.0, 0, 1))
	body.position.y = clampf(_sy, -0.22, 0.2)
	if hero.modifier:
		hero.set_steer_pose(true, steer)
		hero.set_lean(-steer * 0.8 - drift_dir * 0.4)
	var drifting := drift_dir != 0 and not airborne
	spark_l.emitting = drifting and drift_level > 0
	spark_r.emitting = drifting and drift_level > 0
	if drift_level > 0:
		var c: Color
		if drift_level >= 3:
			_hue = fmod(_hue + delta * 2.5, 1.0)
			c = Color.from_hsv(_hue, 0.8, 1.0)
		else:
			c = SPARK_COLORS[drift_level - 1]
		spark_l.color = c
		spark_r.color = c
	flame.emitting = boosting
	dust.emitting = (speed > 8.0 and not airborne) or drifting


## Wackel-/Dreh-Effekt bei Treffern.
func spin_out(turns := 2.0, duration := 1.0) -> void:
	_lock_t = duration + 0.05
	var tw := create_tween()
	tw.tween_property(body, "rotation:y", body.rotation.y + TAU * turns, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: body.rotation.y = 0.0)
	hero.react("dizzy")


func flip(duration := 0.9) -> void:
	_lock_t = duration + 0.05
	var tw := create_tween()
	tw.tween_property(body, "rotation:x", TAU, duration).as_relative().set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void: body.rotation.x = 0.0)
	hero.react("big_hit")
