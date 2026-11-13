class_name LumosActor
extends Node
## Fassade des Character-Frameworks: hängt Gesicht, Körper-Ebene, Fortbewegung und Interaktionen an eine
## vorhandene CharacterRig-Figur – ohne das Rig oder das Modell zu verändern.
##
##   var actor := LumosActor.attach(rig)            # erkennt das Rig selbst (LumosActorConfig.detect)
##   actor.move(wish_velocity, grounded, delta)     # Fortbewegung mit Trägheit, verankerte Füße
##   actor.feel("joy", 0.2, 0.8)                    # Gesicht UND Körperhaltung gemeinsam
##   actor.laugh(1.4)
##   actor.look_at_target(other_actor)              # Augen, Kopf und Oberkörper wenden sich zu
##   actor.reach("r", some_node, 0.3, LumosActor.palm(Vector3.FORWARD, Vector3.UP))
##   actor.interact.grab(item, "r"); actor.interact.throw_to(target_pos)
##
## Signale: laughed, hit_reacted(strength), hand_reached(hand), hand_released(hand).
## Was ein Rig nicht hergibt (Gesicht, Arme, Beine, Skelett), wird sauber weggelassen – siehe capabilities().

signal laughed
signal hit_reacted(strength: float)
signal hand_reached(hand: String)
signal hand_released(hand: String)

var rig: CharacterRig
var cfg: LumosActorConfig
var face: LumosFace            # null, wenn das Modell kein passendes Gesicht hat
var body: LumosBody            # null bei Figuren ohne Skelett (dann wirkt alles auf den ganzen Körper)
var loco: LumosLocomotion
var interact: LumosInteract
var time_scale := 1.0
## Detailstufe, je Bild bestimmt (cfg.lod): 0 = voll · 1 = fern (ohne Fuß-IK und Oberkörper-Blick, Gesicht seltener)
## · 2 = seit 0,4 s außerhalb des Bildes (Körper-Modifier und Gesicht pausieren, Hände/Blick laufen logisch weiter).
var lod := 0
var _off_t := 0.0
var enabled := true

var _look: Variant = null      # Vector3 | Node3D | LumosActor | null
var _gaze := Vector3.ZERO
var _gaze_w := 0.0
var _laugh_t := -1.0
var _laugh_dur := 0.0
var _laugh_str := 0.0
var _hands := {"l": {"w": 0.0, "to": 0.0, "rate": 4.0, "target": null, "orient": null, "reached": false, "assist": 1.0},
	"r": {"w": 0.0, "to": 0.0, "rate": 4.0, "target": null, "orient": null, "reached": false, "assist": 1.0}}
var _t := 0.0
# Ersatz für Figuren ohne Skelett: Haltung/Stöße/Lachen über den ganzen Körper (Pivot)
var _rig_post := Vector2.ZERO
var _rig_post_t := Vector2.ZERO
var _rig_imp := Vector2.ZERO
var _rig_imp_v := Vector2.ZERO
var _rig_lean := Vector2.ZERO


## Framework an ein Rig hängen (oder das vorhandene zurückgeben).
static func attach(p_rig: CharacterRig, config: LumosActorConfig = null) -> LumosActor:
	if p_rig == null:
		push_error("LumosActor.attach: Rig fehlt")
		return null
	var ex := p_rig.get_node_or_null("LumosActor") as LumosActor
	if ex:
		return ex
	var a := LumosActor.new()
	a.name = "LumosActor"
	a.rig = p_rig
	a.cfg = config if config else LumosActorConfig.detect(p_rig)
	p_rig.add_child(a)
	return a


static func of(p_rig: Node) -> LumosActor:
	return p_rig.get_node_or_null("LumosActor") as LumosActor if p_rig else null


## Handhaltung für reach(): Fingerrichtung und Handflächen-Normale (Welt) – fest oder als Callable.
static func palm(finger: Vector3, palm_normal: Vector3) -> Array:
	return [finger, palm_normal]


func _ready() -> void:
	process_priority = 10
	if rig.skel and cfg.profile != "rigid":
		body = LumosBody.new()
		rig.skel.add_child(body)
		if not body.bind(rig.skel, cfg):
			push_warning("LumosActor: %s – Skelett ohne Kopfknochen, Körper-Ebene eingeschränkt" % rig.model_key)
	if cfg.face_enabled:
		var f := LumosFace.new()
		f.feature_scale = cfg.feature_scale
		if f.setup(rig):
			face = f
		else:
			f.free()
	loco = LumosLocomotion.new()
	loco.setup(rig, cfg)
	interact = LumosInteract.new()
	interact.actor = self


func _exit_tree() -> void:
	if interact:
		interact.cancel_all()


## Was diese Figur kann: profile, face, brows, arms ("2bone"/"aim"/"none"), hand_orient, legs, foot_lock, posture.
func capabilities() -> Dictionary:
	return {"profile": cfg.profile, "face": face != null, "brows": face != null and face.has_own_brows,
		"arms": body.arm_mode() if body else "none", "hand_orient": body != null and body.arm_mode() == "2bone",
		"legs": body != null and body.has_legs(), "foot_lock": body != null and body.has_legs() and cfg.foot_lock,
		"posture": "bones" if body else "whole_body"}


## Kopfgröße (Welt) – für Abstände bei Interaktionen (die Lumos-Köpfe sind groß!).
func head_radius() -> float:
	var s := rig.global_basis.get_scale().x if rig.is_inside_tree() else 1.0
	return (float(face.metrics().u) * 0.5 * s) if face else 0.45 * s


# --- Fortbewegung --------------------------------------------------------------------------------------------

func move(wish_velocity: Vector3, grounded := true, delta := -1.0) -> void:
	var d := (delta if delta > 0.0 else get_process_delta_time()) * time_scale
	var v := loco.steer(wish_velocity, d)
	rig.global_position += v * d
	animate(v, grounded, d)


## Nur animieren (die Figur wird vom Spiel selbst bewegt): echte Geschwindigkeit übergeben.
func animate(velocity: Vector3, grounded := true, delta := -1.0) -> void:
	var d := (delta if delta > 0.0 else get_process_delta_time()) * time_scale
	loco.update(velocity, grounded, d)
	var lean := Vector2(clampf(loco.accel_local.z * -cfg.lean_accel + velocity.length() * 0.012, -0.3, 0.35),
		clampf(-loco.turn_speed * cfg.lean_turn * minf(velocity.length() / 3.0, 1.0), -0.25, 0.25))
	if body:
		body.lean = lean
		body.grounded = grounded
	else:
		_rig_lean = lean


# --- Gefühl, Gesicht, Blick, Lachen ----------------------------------------------------------------------

## Gefühl zeigen: Gesichtsausdruck und Körperhaltung wechseln gemeinsam (gleiche Namen wie LumosFace.EXPR).
func feel(name: String, secs := 0.22, intensity := 1.0) -> void:
	if face:
		face.set_expression(name, secs, intensity)
	var p: Array = LumosBody.POSTURE.get(name, LumosBody.POSTURE.neutral)
	if body:
		body.set_posture(name, secs * 1.4, intensity)
	else:
		_rig_post_t = Vector2(float(p[0]) + float(p[1]) * 0.5, float(p[3])) * intensity * cfg.posture_scale


## Wie feel() – der Name bleibt für bestehende Aufrufer.
func express(name: String, secs := 0.18, intensity := 1.0) -> void:
	feel(name, secs, intensity)


## Blickziel: Vector3 (Welt), Node3D, LumosActor (schaut ins Gesicht) oder null. Augen, Kopf und Oberkörper wenden
## sich gemeinsam zu; ein neues Gegenüber wird mit einem kurzen Hochziehen der Brauen begrüßt.
func look_at_target(target: Variant) -> void:
	if target != null and not is_same(target, _look) and face and (target is LumosActor or target is Node3D):
		face.flash_brows(0.45)
	_look = target


func look_target() -> Variant:
	return _look


## Lachen als Kette: Schmunzeln → Lachen (Mund, Augen, Brust, Schultern im selben Takt) → klingt aus → then.
func laugh(duration := 1.4, strength := 1.0, then := "smile") -> void:
	_laugh_t = 0.0
	_laugh_dur = maxf(duration, 0.6)
	_laugh_str = clampf(strength, 0.0, 1.0)
	feel("grin", 0.14)
	var tw := create_tween()
	tw.tween_interval(0.2)
	tw.tween_callback(feel.bind("laugh", 0.16, lerpf(0.6, 1.0, _laugh_str)))
	tw.tween_interval(maxf(_laugh_dur - 0.7, 0.1))
	tw.tween_callback(feel.bind(then, 0.5))
	rig.squash(1.04, 0.97, 0.3)
	laughed.emit()


## Treffer/Stoß aus einer Weltrichtung: Oberkörper federt, Gesicht und Haltung reagieren, optional Stolper-Clip.
func react_hit(from_dir: Vector3, strength := 1.0, stumble := false) -> void:
	var d := from_dir
	d.y = 0.0
	if d.length() > 0.01:
		if body:
			body.push(d.normalized() * 5.5 * strength + Vector3.UP * 0.6 * strength)
		else:
			var loc := rig.global_basis.inverse() * d.normalized()
			_rig_imp_v += Vector2(-loc.z, loc.x) * 4.0 * strength
	feel("ouch", 0.08)
	rig.squash(1.0 + 0.1 * strength, 1.0 - 0.08 * strength, 0.3)
	if stumble:
		loco.play_action("stumble", "", 0.5, 0.1, 1.3)
	var tw := create_tween()
	tw.tween_interval(0.45 + 0.35 * strength)
	tw.tween_callback(feel.bind("neutral", 0.4))
	hit_reacted.emit(strength)


## Kleiner Stoß ohne Schmerz (Kontakt bei Interaktionen): der Körper nimmt das Gewicht auf.
func nudge(world_impulse: Vector3) -> void:
	if body:
		body.push(world_impulse)
	else:
		var loc := rig.global_basis.inverse() * world_impulse
		_rig_imp_v += Vector2(-loc.z, loc.x) * 0.7


func set_breath(amount: float, rate := 1.4) -> void:
	if body:
		body.breath = amount
		body.breath_rate = rate


# --- Hände ---------------------------------------------------------------------------------------------------

## Hand an ein Ziel führen und dort halten: Vector3 (Welt), Node3D (folgt) oder Callable → Vector3.
## orient: Handhaltung [Finger, Handfläche] (Welt) oder Callable → Array; null = Hand bleibt, wie die Animation sie hält.
## assist: wie stark sich der Oberkörper zu einem zu fernen Ziel lehnen darf (0 = gar nicht, 1 = bis cfg.reach_lean).
func reach(hand: String, target: Variant, secs := 0.3, orient: Variant = null, assist := 1.0) -> void:
	if not _hands.has(hand) or body == null or not body.has_arms():
		return
	var h: Dictionary = _hands[hand]
	h.target = target
	h.orient = orient
	h.assist = assist
	h.to = 1.0
	h.rate = 1.0 / maxf(secs, 0.02)
	h.reached = false


func release(hand: String, secs := 0.35) -> void:
	if not _hands.has(hand):
		return
	var h: Dictionary = _hands[hand]
	h.to = 0.0
	h.rate = 1.0 / maxf(secs, 0.02)
	hand_released.emit(hand)


func hand_pos(hand: String) -> Vector3:
	return body.joint_pos("hand." + hand) if body else rig.global_position + Vector3.UP


func hand_weight(hand: String) -> float:
	return float(_hands[hand].w) if _hands.has(hand) else 0.0


## Punkt relativ zur Figur (rechts, oben, vorn) in Weltkoordinaten.
func rel(right: float, up: float, fwd: float) -> Vector3:
	var b := rig.global_basis
	return rig.global_position + b.x.normalized() * right + Vector3.UP * up - b.z.normalized() * fwd


func forward() -> Vector3:
	return -rig.global_basis.z.normalized()


func right() -> Vector3:
	return rig.global_basis.x.normalized()


func _resolve(t: Variant) -> Vector3:
	if t is Vector3:
		return t
	if t is Callable:
		return (t as Callable).call()
	if t is LumosActor:
		var a := t as LumosActor
		return a.body.joint_pos("head") + Vector3.UP * 0.25 if a.body else a.rig.global_position + Vector3.UP * 1.5
	if t is Node3D and is_instance_valid(t):
		return (t as Node3D).global_position
	return Vector3.INF


## Framework für diese Figur ein-/ausschalten (aus = nur noch die normale Animation des Spiels).
func set_enabled(on: bool) -> void:
	enabled = on
	set_process(on)
	if body:
		body.active = on and lod < 2
	if face:
		face.visible = on
		face.set_process(on)


func _update_lod(d: float) -> void:
	var n := 0
	var cam := rig.get_viewport().get_camera_3d() if cfg.lod and rig.is_inside_tree() else null
	if cam:
		var r := maxf(head_radius() * 2.5, 0.3)
		var c := rig.global_position + Vector3.UP * r * 0.8
		var vis := true
		for pl: Plane in cam.get_frustum():
			if pl.distance_to(c) > r:
				vis = false
				break
		_off_t = 0.0 if vis else _off_t + d
		n = 2 if _off_t > 0.4 else (1 if cam.global_position.distance_to(c) > cfg.lod_far * r else 0)
	if n != lod:
		lod = n
		if body:
			body.active = n < 2
			body.lite = n >= 1
		if face:
			face.paused = n >= 2


func _process(delta: float) -> void:
	var d := delta * time_scale
	_t += d
	_update_lod(d)
	if body:
		body.dt = d
	if face:
		face.dt_scale = time_scale
	# Blick: Augen, Kopf (Blick-Modifier des Spiels) und Oberkörper (Körper-Ebene) wandern gemeinsam zum Ziel
	var want := _resolve(_look) if _look != null else Vector3.INF
	var w := 1.0 if want != Vector3.INF else 0.0
	if w > 0.0:
		_gaze = want if _gaze_w < 0.02 else _gaze.lerp(want, 1.0 - exp(-d / 0.14))
	_gaze_w = lerpf(_gaze_w, w, 1.0 - exp(-d / 0.2))
	if rig.modifier:
		rig.modifier.look_target = _gaze
		rig.modifier.look_weight = _gaze_w
	if body:
		body.attend_target = _gaze
		body.attend_w = _gaze_w
	if face:
		var loc: Vector3 = face.global_transform.affine_inverse() * _gaze
		var gz := Vector2(clampf(loc.x / maxf(loc.z, 0.4) * 1.3, -1, 1), clampf((loc.y - 1.6) / maxf(loc.z, 0.4) * 1.3, -1, 1))
		face.gaze = face.gaze.lerp(gz * _gaze_w, 0.25)
	# Lachen
	var lv := 0.0
	if _laugh_t >= 0.0:
		_laugh_t += d
		lv = _laugh_str * smoothstep(0.0, 0.32, _laugh_t) * (1.0 - smoothstep(_laugh_dur - 0.65, _laugh_dur, _laugh_t))
		if _laugh_t >= _laugh_dur:
			_laugh_t = -1.0
	if body:
		body.laugh = lv
	if face:
		face.laugh = lv
		face.laugh_phase = body.laugh_phase if body else _t * 17.0
	if body == null:
		_rigid_body(d, lv)
	# Hände
	if body:
		for hand in ["l", "r"]:
			var h: Dictionary = _hands[hand]
			h.w = move_toward(float(h.w), float(h.to), float(h.rate) * d)
			var sw := smoothstep(0.0, 1.0, float(h.w))
			if sw > 0.0 and h.target != null:
				var p := _resolve(h.target)
				if p != Vector3.INF:
					body.hand_t[hand] = p
				else:
					h.to = 0.0   # Ziel verschwunden → sauber loslassen
				var o: Variant = h.orient
				if o is Callable:
					o = (o as Callable).call()
				body.hand_dir[hand] = o if o is Array else []
			body.hand_w[hand] = sw
			body.hand_assist[hand] = float(h.assist)
			if float(h.w) >= 1.0 and not h.reached:
				h.reached = true
				hand_reached.emit(hand)
			if float(h.w) <= 0.0 and float(h.to) <= 0.0:
				h.target = null
				h.orient = null
	if interact:
		interact.tick(d)


## Figuren ohne Skelett: Haltung, Lachen und Stöße als Neigen und Wippen des ganzen Körpers.
func _rigid_body(d: float, lv: float) -> void:
	if rig.pivot == null:
		return
	_rig_post = _rig_post.lerp(_rig_post_t, 1.0 - exp(-d / 0.15))
	_rig_imp_v += (-_rig_imp * 60.0 - _rig_imp_v * 8.0) * d
	_rig_imp += _rig_imp_v * d
	var rock := sin(_t * 17.0) * 0.08 * lv
	rig.pivot.rotation.x = _rig_post.x * 0.6 + _rig_lean.x + _rig_imp.x + rock
	rig.pivot.rotation.z = _rig_post.y + _rig_lean.y + _rig_imp.y
