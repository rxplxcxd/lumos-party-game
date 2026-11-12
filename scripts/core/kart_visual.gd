class_name KartVisual
extends Node3D
## Optik eines Karts: Kenney-Kart mit dem gewählten Helden als Fahrer, als Fahrwerk aufgebaut.
##
##   KartVisual (Fahrtrichtung)
##    └ _yaw        Schräglauf im Drift, Dreher bei Treffern – Drehpunkt an der Vorderachse, damit das Heck ausschert
##       └ _base
##          ├ _wheels  Räder bleiben am Boden (lenken, drehen, federn nur leicht mit)
##          └ body     Karosserie: Feder-Dämpfer für Einfedern, Nicken, Wanken – legt sich in die Kurve
##              └ model + Fahrer + Effekte
##
## Alle Bewegungen sind gedämpfte Federn (keine Sprünge zwischen festen Posen): Drift einleiten = Heck schwingt
## mit leichtem Überschwingen nach außen, Drift beenden = Kart pendelt sich in die Fahrtrichtung zurück.
## Treffer wirken als Impulse auf dieselben Federn (Schleudern, Durchschütteln, Überschlag, Wackeln) und klingen
## von selbst aus – danach fährt das Kart ohne Ruck normal weiter. Blickrichtung: -Z (Godot-Standard).

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

var _yaw: Node3D
var _base: Node3D
var _wheels: Node3D
var _wheel_xf: Dictionary = {}     # Rad → Grund-Transform im Fahrwerk
var _wheel_rot := 0.0
var _steer_vis := 0.0
var _hue := 0.0
var _odo := 0.0
var _prev_speed := 0.0
var _prev_steer := 0.0
var _was_air := false
var _drift_prev := 0
var _exhaust: Array[Node3D] = []
var _shield: MeshInstance3D
var _shield_kind := ""
var _cream: MeshInstance3D

# Feder-Dämpfer (Wert, Geschwindigkeit)
var _sy := 0.0      # Einfedern
var _svy := 0.0
var _pitch := 0.0
var _pitch_v := 0.0
var _roll := 0.0
var _roll_v := 0.0
var _slip := 0.0    # Schräglauf (rad, + = Nase nach rechts)
var _slip_v := 0.0
# Treffer-Kanäle: zusätzlicher Dreh-, Nick- und Wankwinkel (laufen ab und gehen nahtlos in die Federn über)
var _spin := 0.0
var _flip := 0.0
var _tumble := 0.0
var _shake_t := 0.0
var _shake_amp := 0.0
var _wobble_t := 0.0
var _wobble_amp := 0.0
# Fahrer: Oberkörper-Ruck (Feder), Arme
var _jolt := Vector2.ZERO
var _jolt_v := Vector2.ZERO

const SPRING := 120.0
const DAMP := 11.0
const SLIP_K := 95.0       # Heck: weich, mit sichtbarem Überschwingen
const SLIP_D := 9.5


func setup(kart_key: String, hero_key: String, player_idx := -1, scl := 2.2) -> KartVisual:
	kart_scale = scl
	_yaw = Node3D.new()
	_yaw.name = "Yaw"
	add_child(_yaw)
	var pivot := Vector3(0, 0, -0.62 * scl / 2.2)   # Vorderachse
	_yaw.position = pivot
	_base = Node3D.new()
	_base.position = -pivot
	_yaw.add_child(_base)
	_wheels = Node3D.new()
	_wheels.name = "Wheels"
	_base.add_child(_wheels)
	body = Node3D.new()
	body.name = "Body"
	_base.add_child(body)
	model = Assets.spawn(kart_key, body)
	model.rotation.y = PI
	model.scale = Vector3.ONE * scl
	var found: Array[Node3D] = []
	for n in _all(model):
		var nm := String(n.name)
		if nm == "character" and n is MeshInstance3D:
			(n as MeshInstance3D).visible = false
		elif nm.begins_with("wheel") and n is Node3D:
			found.append(n as Node3D)
	# Räder aus der Karosserie lösen: Sie bleiben am Boden, die Karosserie federt darüber
	for w in found:
		var xf := _chain_xf(w, body)
		w.get_parent().remove_child(w)
		_wheels.add_child(w)
		w.transform = xf
		_wheel_xf[w] = xf
		wheels.append(w)
		if String(w.name).contains("front"):
			front_wheels.append(w)
	_refine_materials()
	_add_details()
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


## Transform eines Knotens relativ zu einem Vorfahren (ohne Szenenbaum – setup läuft auch vor add_child).
func _chain_xf(n: Node3D, ancestor: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var p: Node = n
	while p != null and p != ancestor:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## Kenney-Karts teilen ein flaches Kunststoff-Material. Eigene Kopie je Kart mit Lack-Glanz auf der Karosserie,
## matten Reifen und Metall-Felgen – stilisiert, aber nicht mehr wie Spielzeug-Plastik.
func _refine_materials() -> void:
	for n in _all(body):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var src := mi.get_active_material(0) as StandardMaterial3D
		if src == null:
			continue
		var m := src.duplicate() as StandardMaterial3D
		m.roughness = 0.34
		m.metallic = 0.08
		m.metallic_specular = 0.7
		m.rim_enabled = true
		m.rim = 0.25
		m.rim_tint = 0.6
		mi.material_override = m
	for w in wheels:
		var mi := w as MeshInstance3D
		if mi == null:
			continue
		var src := mi.get_active_material(0) as StandardMaterial3D
		if src == null:
			continue
		var m := src.duplicate() as StandardMaterial3D
		m.roughness = 0.72
		m.metallic = 0.25
		m.metallic_specular = 0.6
		mi.material_override = m


## Liebevolle Details: verchromte Auspuffrohre (Boost-Flammen kommen hier heraus), Scheinwerfer, Achsschenkel.
func _add_details() -> void:
	var k := kart_scale / 2.2
	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color(0.78, 0.8, 0.86)
	chrome.metallic = 0.9
	chrome.roughness = 0.22
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.13, 0.13, 0.16)
	dark.roughness = 0.6
	for sx: float in [-1.0, 1.0]:
		var ex := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.075 * k
		cm.bottom_radius = 0.095 * k
		cm.height = 0.42 * k
		cm.radial_segments = 12
		cm.rings = 1
		cm.material = chrome
		cm.set_meta("gfx_tuned", true)
		ex.mesh = cm
		ex.rotation.x = PI * 0.5 - 0.35
		ex.position = Vector3(sx * 0.26 * k, 0.52 * k, 1.28 * k)
		body.add_child(ex)
		var inner := MeshInstance3D.new()
		var cm2 := CylinderMesh.new()
		cm2.top_radius = 0.055 * k
		cm2.bottom_radius = 0.055 * k
		cm2.height = 0.02 * k
		cm2.material = dark
		inner.mesh = cm2
		inner.position = Vector3(0, -0.205 * k, 0)
		ex.add_child(inner)
		_exhaust.append(ex)
		var lamp := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.07 * k
		sm.height = 0.1 * k
		sm.radial_segments = 10
		sm.rings = 5
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color(1.0, 0.96, 0.82)
		lm.emission_enabled = true
		lm.emission = Color(1.0, 0.92, 0.7)
		lm.emission_energy_multiplier = 1.4
		sm.material = lm
		lamp.mesh = sm
		lamp.position = Vector3(sx * 0.3 * k, 0.43 * k, -1.18 * k)
		body.add_child(lamp)
	# Achsschenkel: dunkle Stummel zwischen Karosserie und Vorderrädern – beim Einfedern sieht man das Fahrwerk arbeiten
	for w in front_wheels:
		var st := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.36, 0.08, 0.1) * k
		bm.material = dark
		st.mesh = bm
		var p: Vector3 = (_wheel_xf[w] as Transform3D).origin
		st.position = Vector3(p.x * 0.55, p.y + 0.02 * k, p.z)
		_wheels.add_child(st)


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


## Pro Physik-Schritt: Geschwindigkeit (m/s), Lenkung (-1..1), Drift-Richtung (-1/0/1), Drift-Stufe (0..3).
## Optional: slip = Schräglauf (rad, NAN = aus der Drift-Richtung ableiten), lat = Querbeschleunigung (m/s², + rechts),
## vy = Vertikaltempo (für das Nicken in der Luft).
func update_visual(speed: float, steer: float, drift_dir: int, drift_level: int, boosting: bool, airborne: bool, delta: float,
		slip := NAN, lat := NAN, vy := 0.0) -> void:
	var dt := clampf(delta, 0.0001, 0.05)
	if is_nan(slip):
		slip = float(drift_dir) * (0.42 + 0.2 * clampf(steer * float(drift_dir), 0.0, 1.0))
	if is_nan(lat):
		lat = steer * speed * 0.55 + float(drift_dir) * speed * 0.35
	# --- Räder: drehen, lenken (im Drift sichtbares Gegenlenken), federn mit ---
	_wheel_rot += speed * dt / (0.21 * kart_scale)
	var wheel_yaw := clampf(-steer * 0.42 + _slip * 0.8, -0.7, 0.7)   # Rotationssinn: + = links
	_steer_vis = lerpf(_steer_vis, wheel_yaw, 1.0 - exp(-dt * 14.0))
	for w in wheels:
		var base_xf: Transform3D = _wheel_xf[w]
		var yaw_w := PI + (_steer_vis if w in front_wheels else 0.0)
		w.transform = Transform3D(Basis.from_euler(Vector3(_wheel_rot, yaw_w, 0.0)).scaled(base_xf.basis.get_scale()), base_xf.origin)
	_wheels.position.y = _sy * 0.25
	# --- Schräglauf: Heck schert aus, Feder mit Überschwingen ---
	if drift_dir != 0 and _drift_prev == 0:
		_slip_v += float(drift_dir) * 3.2      # Einlenk-Impuls: das Heck wird herumgeworfen
		_roll_v += -float(drift_dir) * 1.6    # … und die Karosserie kippt in die Kurve
		_jolt_v.y += -float(drift_dir) * 2.0
		if hero:
			hero.squash(1.06, 0.94, 0.22)
	elif drift_dir == 0 and _drift_prev != 0:
		_jolt_v.x += 1.4                      # Drift-Boost: Oberkörper wird nach hinten gedrückt
	_drift_prev = drift_dir
	_slip_v += ((slip - _slip) * SLIP_K - _slip_v * SLIP_D) * dt
	_slip += _slip_v * dt
	# --- Karosserie: in die Kurve legen, nicken bei Gas/Bremse, in der Luft Nase nach Flugbahn ---
	var acc := clampf((speed - _prev_speed) / dt, -60.0, 60.0)
	_prev_speed = speed
	var target_roll := clampf(-lat * 0.0085, -0.2, 0.2) - float(drift_dir) * 0.1
	var target_pitch := clampf(acc * 0.0028, -0.08, 0.075)
	if airborne:
		target_pitch = clampf(vy * 0.018, -0.22, 0.16)
	# Richtungswechsel: die Feder wird angestoßen (Gewicht wandert von einer Seite auf die andere)
	var dsteer := (steer - _prev_steer) / dt
	_prev_steer = steer
	_roll_v += clampf(dsteer, -12.0, 12.0) * -0.012 * clampf(speed / 20.0, 0.0, 1.0)
	_roll_v += ((target_roll - _roll) * SPRING - _roll_v * DAMP) * dt
	_roll += _roll_v * dt
	_pitch_v += ((target_pitch - _pitch) * SPRING - _pitch_v * DAMP) * dt
	_pitch += _pitch_v * dt
	# --- Federung: Landestoß + Fahrbahn-Unebenheiten (aus der gefahrenen Strecke, damit sie zur Fahrt passen) ---
	if _was_air and not airborne:
		land(1.0)
	_was_air = airborne
	_odo += speed * dt
	var road := 0.0
	if not airborne:
		road = (sin(_odo * 0.83) * 0.6 + sin(_odo * 2.17 + 1.3) * 0.3 + sin(_odo * 5.3) * 0.1) * 0.022 * clampf(speed / 15.0, 0.15, 1.0)
	_svy += ((road - _sy) * SPRING - _svy * (DAMP * 0.8)) * dt
	_sy += _svy * dt
	# --- Treffer-Kanäle ---
	var shake := Vector3.ZERO
	if _shake_t > 0.0:
		_shake_t -= dt
		var a := _shake_amp * clampf(_shake_t / 0.4, 0.0, 1.0)
		shake = Vector3(sin(_odo * 9.0 + _shake_t * 70.0), sin(_shake_t * 83.0), sin(_shake_t * 61.0)) * a
	var wob := 0.0
	if _wobble_t > 0.0:
		_wobble_t -= dt
		wob = sin(_wobble_t * 15.0) * _wobble_amp * clampf(_wobble_t / 0.5, 0.0, 1.0)
	_yaw.rotation.y = -_slip + _spin + wob
	body.rotation = Vector3(_pitch + _flip + shake.x * 0.6, 0.0, _roll + _tumble + shake.z)
	body.position.y = clampf(_sy, -0.24, 0.22) + shake.y * 0.05
	# --- Fahrer: in die Kurve legen, in die Kurve schauen, Ruck im Oberkörper ---
	_jolt_v += (-_jolt * 70.0 - _jolt_v * 8.0) * dt
	_jolt += _jolt_v * dt
	if hero and hero.modifier:
		hero.set_steer_pose(true, steer)
		hero.set_lean(-steer * 0.8 - float(drift_dir) * 0.5)
		var mod := hero.modifier
		mod.jolt = _jolt
		# Kopf dreht leicht in die Kurve (ein Punkt vor dem Kart, zur Lenkseite versetzt)
		var fwd := -global_basis.z
		var right := global_basis.x
		mod.look_target = global_position + fwd * 8.0 + right * (steer * 4.0 + float(drift_dir) * 3.0) + Vector3.UP * 1.0
		mod.look_weight = lerpf(mod.look_weight, 0.65 if speed > 4.0 else 0.0, 1.0 - exp(-dt * 4.0))
	# --- Effekte ---
	var drifting := drift_dir != 0 and not airborne
	spark_l.emitting = drifting and drift_level > 0
	spark_r.emitting = drifting and drift_level > 0
	if drift_level > 0:
		var c: Color
		if drift_level >= 3:
			_hue = fmod(_hue + dt * 2.5, 1.0)
			c = Color.from_hsv(_hue, 0.8, 1.0)
		else:
			c = SPARK_COLORS[drift_level - 1]
		spark_l.color = c
		spark_r.color = c
	flame.emitting = boosting
	dust.emitting = (speed > 8.0 and not airborne) or drifting
	if _shield:
		_shield.rotation.y += dt * 1.6
		var pulse := 1.0 + sin(_odo * 0.4 + Time.get_ticks_msec() * 0.006) * 0.03
		_shield.scale = Vector3.ONE * pulse


# --- Impulse & Reaktionen ---------------------------------------------------------------------------------

## Landestoß: Karosserie federt ein und schwingt nach.
func land(strength := 1.0) -> void:
	_svy -= 2.6 * strength
	_pitch_v -= 0.8 * strength
	_jolt_v.x -= 2.0 * strength


## Seitlicher Rempler (Kart-Kollision): side = +1 → Stoß von rechts.
func bump(side: float, strength := 1.0) -> void:
	_roll_v += side * 2.4 * strength
	_slip_v += -side * 1.6 * strength
	_jolt_v.y += side * 3.0 * strength
	_shake_t = 0.25
	_shake_amp = 0.05 * strength


## Wackeln (z. B. Kuchen im Gesicht, Honig): das Heck pendelt hin und her und beruhigt sich.
func wobble(strength := 0.35, duration := 1.0) -> void:
	_wobble_t = duration
	_wobble_amp = strength
	_jolt_v.x += 2.0


## Dreher: dreht das Kart `turns`-mal und läuft weich aus; danach übernimmt nahtlos die Fahrtrichtung.
func spin_out(turns := 2.0, duration := 1.0) -> void:
	var tw := create_tween()
	_spin = 0.0
	tw.tween_property(self, "_spin", TAU * turns, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		_spin = 0.0
		_slip_v += 1.2)   # kleines Nachpendeln statt hartem Stopp
	_jolt_v += Vector2(1.0, 3.5)
	if hero:
		hero.modifier_pulse("dizzy", duration + 0.6, 1.0)
		hero.modifier_pulse("scared", 0.5, 0.8)


## Überschlag nach vorn (Explosion): Karosserie macht einen Salto, der Fahrer rudert mit den Armen.
func flip(duration := 0.9) -> void:
	var tw := create_tween()
	_flip = 0.0
	tw.tween_property(self, "_flip", TAU, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		_flip = 0.0
		land(1.3))
	_jolt_v += Vector2(-3.0, 0.0)
	if hero:
		hero.modifier_pulse("scared", duration + 0.3, 1.0)
		hero.squash(0.85, 1.2, 0.3)


## Seitwärts-Überschlag (vom Kometen weggeschleudert): rollt um die Längsachse.
func tumble(side := 1.0, duration := 0.8) -> void:
	var tw := create_tween()
	_tumble = 0.0
	tw.tween_property(self, "_tumble", -signf(side) * TAU, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		_tumble = 0.0
		land(1.0))
	_jolt_v.y += side * 4.0
	if hero:
		hero.modifier_pulse("scared", duration + 0.2, 1.0)


## Stromschlag: hochfrequentes Zittern von Kart und Fahrer.
func zap(duration := 0.7) -> void:
	_shake_t = duration
	_shake_amp = 0.12
	if hero:
		hero.modifier_pulse("tremble", duration + 0.3, 1.0)
		hero.modifier_pulse("scared", duration, 0.7)


## Rückwärts-Ruck (Anker): Nase taucht ein, Fahrer fliegt nach vorn und wieder zurück.
func yank() -> void:
	_pitch_v -= 3.5
	_jolt_v.x -= 5.0
	_shake_t = 0.3
	_shake_amp = 0.06


## Trick in der Luft: Salto oder Schraube, je nach Richtung (0 = Salto, ±1 = Schraube).
func trick(dir := 0) -> void:
	if dir == 0:
		var tw := create_tween()
		tw.tween_property(self, "_flip", -TAU, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(func() -> void: _flip = 0.0)
	else:
		var tw2 := create_tween()
		tw2.tween_property(self, "_tumble", float(dir) * TAU, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw2.tween_callback(func() -> void: _tumble = 0.0)
	if hero:
		hero.modifier_pulse("triumph", 0.7, 1.0)
		hero.squash(0.9, 1.12, 0.25)


## Wurf-Bewegung des Fahrers: Ausholen (antizipieren) → Wurf → Nachschwingen. back = nach hinten fallen lassen.
## Gibt die Zeit bis zum Loslassen zurück.
func throw_anim(back := false) -> float:
	if hero == null or hero.modifier == null:
		return 0.0
	var mod := hero.modifier
	var tw := create_tween()
	var wind := 0.14
	if back:
		tw.tween_property(mod, "arm_throw", 0.6, wind).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(mod, "arm_throw", -0.9, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		tw.tween_property(mod, "arm_throw", -1.0, wind).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(mod, "arm_throw", 1.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(mod, "arm_throw", 0.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_jolt_v.x += -1.2 if not back else 1.0
	return wind + 0.06


## Sahne im Gesicht: ein weißer Klecks vorne am Kart, der nach ein paar Sekunden abtropft.
func splat(duration := 2.2) -> void:
	if _cream == null:
		_cream = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.42 * kart_scale / 2.2
		sm.height = 0.5 * kart_scale / 2.2
		sm.radial_segments = 12
		sm.rings = 6
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#fff6e8")
		m.roughness = 0.35
		sm.material = m
		_cream.mesh = sm
		_cream.position = Vector3(0, 0.65, -0.95) * kart_scale / 2.2
		body.add_child(_cream)
	_cream.visible = true
	_cream.scale = Vector3(1.2, 0.3, 1.0)
	var tw := _cream.create_tween()
	tw.tween_property(_cream, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(duration - 0.6, 0.1))
	tw.tween_property(_cream, "scale", Vector3(0.6, 0.05, 0.6), 0.4)
	tw.tween_callback(func() -> void: _cream.visible = false)
	wobble(0.3, 1.0)
	if hero:
		hero.modifier_pulse("frustrated", duration, 1.0)


## Schutzhülle um das Kart: "bubble" (Seifenblase), "mirror" (Spiegelschild), "" = aus.
func set_shield(kind: String) -> void:
	if kind == _shield_kind:
		return
	_shield_kind = kind
	if _shield:
		var old := _shield
		var tw := old.create_tween()
		tw.tween_property(old, "scale", Vector3.ONE * 1.35, 0.12)
		tw.tween_callback(old.queue_free)
		_shield = null
	if kind == "":
		return
	_shield = ItemModels.shield(kind, kart_scale)
	add_child(_shield)
	_shield.position = Vector3(0, 0.95, 0) * kart_scale / 2.2
	_shield.scale = Vector3.ONE * 0.2
	Juice.pop_in(_shield, 0.25)
