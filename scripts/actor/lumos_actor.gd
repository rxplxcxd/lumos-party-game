class_name LumosActor
extends Node
## Fassade des Character-Frameworks: hängt Gesicht, Körper, Gefühlszustand, Mikroleben, Sozialverhalten,
## Fortbewegung und Interaktionen an eine vorhandene CharacterRig-Figur – ohne Rig oder Modell zu verändern.
##
##   var actor := LumosActor.attach(rig)            # erkennt das Rig (LumosActorConfig.detect), Persönlichkeit inklusive
##   actor.move(wish_velocity, grounded, delta)     # Fortbewegung mit Trägheit, verankerte Füße, Gewicht
##   actor.feel("joy", 0.2, 0.8)                    # Stimmung: Gesicht, Haltung, Blick, Gesten passen sich an
##   actor.react("surprise", 0.9)                   # Reaktion: steigt an, hält, klingt ab, Nachwirkung
##   actor.laugh(1.4)                               # andere in der Nähe lachen ggf. mit (LumosSocial)
##   actor.cartoon("cry", 0.9)                      # Cartoon-Übertreibung (Tränenfontänen …)
##   actor.interact_with("hug", other)              # Interaktionsprotokoll mit Phasen
##   actor.look_at_target(other_actor)              # Augen springen, Kopf und Oberkörper folgen
##
## Ebenen je Bild (unten → oben): Animation/Lokomotion → Gewicht & Balance (LumosBody) → Haltung (Gefühl +
## Persönlichkeit) → Kopf & Blick → Gesicht & Gefühl → Arme & Hände (Gesten, Interaktionen, Regie) →
## Sekundärbewegung (Zubehör, Nachschwingen) → Cartoon → Effekte. Konflikte regelt LumosLayers.
## Signale: laughed, hit_reacted(strength), hand_reached(hand), hand_released(hand).

signal laughed
signal hit_reacted(strength: float)
signal hand_reached(hand: String)
signal hand_released(hand: String)

const API_VERSION := LumosActorConfig.API_VERSION

var rig: CharacterRig
var cfg: LumosActorConfig
var face: LumosFace            # null, wenn das Modell kein passendes Gesicht hat
var body: LumosBody            # null bei Figuren ohne Skelett (dann wirkt alles auf den ganzen Körper)
var loco: LumosLocomotion
var interact: LumosInteract
var personality: LumosPersonality
var emotion: LumosEmotion
var layers := LumosLayers.new()
var micro: LumosMicro
var mind: LumosMind
var social: LumosSocial
var rng := RandomNumberGenerator.new()
var time_scale := 1.0
## Detailstufe (cfg.lod): 0 voll · 1 fern (ohne Fuß-IK/Oberkörper-Blick, Gesicht seltener) · 2 seit 0,4 s außerhalb
## des Bildes (Körper und Gesicht pausieren, Verhalten ruht; Hände/Blick laufen logisch weiter).
var lod := 0
var enabled := true
var scripted := false           ## Regie bewegt die Figur (Trailer, Zwischensequenz): keine eigenen Ortswechsel
var cartoon_state := {}         ## LumosCartoon: Abklingzeiten, laufende Reaktionen
var cartoon_head := Vector3.ZERO
var pet_tremble := 0.0

var _off_t := 0.0
var _look: Variant = null      # Vector3 | Node3D | LumosActor | null
var _soc_look: Variant = null
var _soc_until := 0.0
var _s_look := Vector3.ZERO
var _s_look_w := 0.0
var _s_hands := {}
var _s_laugh := 0.0
var _breath_over := false
var _gaze := Vector3.ZERO
var _gaze_w := 0.0
var _eye := Vector3.ZERO
var _eye_w := 0.0
var _eye_y := 1.6
var _laugh_t := -1.0
var _laugh_dur := 0.0
var _laugh_str := 0.0
var _hands := {"l": {"w": 0.0, "to": 0.0, "rate": 4.0, "target": null, "orient": null, "reached": false, "assist": 1.0, "owner": ""},
	"r": {"w": 0.0, "to": 0.0, "rate": 4.0, "target": null, "orient": null, "reached": false, "assist": 1.0, "owner": ""}}
var _t := 0.0
var _vel := Vector3.ZERO
var _prev_pos := Vector3.INF
var _top := -1.0
# Ersatz für Figuren ohne Skelett: Haltung/Stöße/Lachen über den ganzen Körper (Pivot), Haustier-Einzelteile
var _rig_post := Vector2.ZERO
var _rig_post_t := Vector2.ZERO
var _rig_imp := Vector2.ZERO
var _rig_imp_v := Vector2.ZERO
var _rig_lean := Vector2.ZERO
var _pet := {}
var _step := 0.0


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
	a.cfg = LumosActorConfig.migrate(config if config else LumosActorConfig.detect(p_rig))
	p_rig.add_child(a)
	return a


static func of(p_rig: Node) -> LumosActor:
	return p_rig.get_node_or_null("LumosActor") as LumosActor if p_rig else null


## Handhaltung für reach(): Fingerrichtung und Handflächen-Normale (Welt) – fest oder als Callable.
static func palm(finger: Vector3, palm_normal: Vector3) -> Array:
	return [finger, palm_normal]


func _ready() -> void:
	process_priority = 10
	personality = cfg.personality if cfg.personality else LumosPersonality.preset("balanced")
	rng.seed = cfg.seed if cfg.seed != 0 else absi(hash(rig.model_key)) + 1
	if rig.skel and cfg.profile != "rigid":
		body = LumosBody.new()
		rig.skel.add_child(body)
		if not body.bind(rig.skel, cfg):
			push_warning("LumosActor: %s – Skelett ohne Kopfknochen, Körper-Ebene eingeschränkt" % rig.model_key)
	if cfg.face_enabled:
		var f := LumosFace.new()
		f.feature_scale = cfg.feature_scale
		f.rng.seed = rng.seed + 7
		if f.setup(rig):
			face = f
			var ec: Array = f.metrics().eye_c
			_eye_y = ((ec[0] as Vector3).y + (ec[1] as Vector3).y) * 0.5
		else:
			f.free()
	emotion = LumosEmotion.new()
	emotion.setup(personality, face.expressions if face else LumosFace.EXPR, LumosBody.POSTURE, LumosFace.KEYS)
	loco = LumosLocomotion.new()
	loco.setup(rig, cfg)
	interact = LumosInteract.new()
	interact.actor = self
	micro = LumosMicro.new()
	micro.setup(self)
	mind = LumosMind.new()
	mind.setup(self)
	social = LumosSocial.of(self)
	if social:
		social.register(self)
	if body == null:
		_find_pet_parts()


func _exit_tree() -> void:
	if interact:
		interact.cancel_all()
	if social and is_instance_valid(social):
		social.unregister(self)


## Was diese Figur kann: profile, face, brows, arms ("2bone"/"aim"/"none"), hand_orient, legs, foot_lock, posture,
## jiggle (Zubehör), pet_parts (Schwanz/Beine bei Figuren ohne Skelett).
func capabilities() -> Dictionary:
	return {"profile": cfg.profile, "face": face != null, "brows": face != null and face.has_own_brows,
		"arms": body.arm_mode() if body else "none", "hand_orient": body != null and body.arm_mode() == "2bone",
		"legs": body != null and body.has_legs(), "foot_lock": body != null and body.has_legs() and cfg.foot_lock,
		"posture": "bones" if body else "whole_body", "jiggle": body.jiggle_state().size() if body else 0,
		"pet_parts": _pet.keys(), "api": API_VERSION}


## Kopfgröße (Welt) – für Abstände bei Interaktionen (die Lumos-Köpfe sind groß!).
func head_radius() -> float:
	var s := rig.global_basis.get_scale().x if rig.is_inside_tree() else 1.0
	return (float(face.metrics().u) * 0.5 * s) if face else 0.45 * s


## Oberkante des Kopfes (Welt) – Ankerpunkt für Effekte über dem Kopf.
func head_top() -> Vector3:
	if body:
		return body.joint_pos("head") + Vector3.UP * head_radius() * 1.75
	if _top < 0.0:
		_top = 0.6
		for mi in Assets.find_meshes(rig):
			var m := mi as MeshInstance3D
			if m and m.mesh:
				var bb := m.global_transform * m.get_aabb()
				_top = maxf(_top, bb.end.y - rig.global_position.y)
	return rig.global_position + Vector3.UP * _top


func clock() -> float:
	return _t


func velocity() -> Vector3:
	return _vel


func speed() -> float:
	return Vector2(_vel.x, _vel.z).length()


func is_standing() -> bool:
	var c := String(rig.current)
	return c in ["idle", "idle_b", ""] or (c in ["walk", "run"] and speed() < 0.3)


func is_laughing() -> bool:
	return _laugh_t >= 0.0 or _s_laugh > 0.3 or (emotion != null and emotion.intensity_of("laugh") > 0.4)


func in_interaction() -> bool:
	return social != null and social.interaction_of(self) != null


func autonomy_gate(level: float) -> bool:
	return cfg.autonomy >= level


# --- Fortbewegung, Gewicht -----------------------------------------------------------------------------------

func move(wish_velocity: Vector3, grounded := true, delta := -1.0) -> void:
	var d := (delta if delta > 0.0 else get_process_delta_time()) * time_scale
	var v := loco.steer(wish_velocity, d)
	rig.global_position += v * d
	animate(v, grounded, d)


## Nur animieren (die Figur wird vom Spiel selbst bewegt): echte Geschwindigkeit übergeben.
func animate(velocity_in: Vector3, grounded := true, delta := -1.0) -> void:
	var d := (delta if delta > 0.0 else get_process_delta_time()) * time_scale
	loco.update(velocity_in, grounded, d)
	var lean := Vector2(clampf(loco.accel_local.z * -cfg.lean_accel + velocity_in.length() * 0.012, -0.3, 0.35),
		clampf(-loco.turn_speed * cfg.lean_turn * minf(velocity_in.length() / 3.0, 1.0), -0.25, 0.25))
	if body:
		body.lean = lean
		body.grounded = grounded
	else:
		_rig_lean = lean


## Sprung mit Ausholen, Flug und gewichtiger Landung (schwere Figuren federn tiefer ein).
func jump(height := 0.6) -> void:
	if body:
		body.crouch = 0.45
	var tw := create_tween()
	tw.tween_interval(0.14)
	tw.tween_callback(func() -> void:
		if body:
			body.crouch = 0.0
		rig.hop(height, 0.3 + height * 0.4))
	tw.tween_interval(0.3 + height * 0.4)
	tw.tween_callback(land.bind(clampf(height * 1.4, 0.3, 1.6)))


func land(strength := 1.0) -> void:
	if body:
		body.land(strength)
	rig.squash(1.0 + 0.12 * strength, 1.0 - 0.1 * strength, 0.3)


func stumble(world_dir: Vector3, strength := 1.0) -> void:
	if body:
		body.stumble(world_dir, strength)
	else:
		nudge(world_dir * 3.0 * strength)
	emotion.trigger("surprise", 0.5 * strength, 0.4)


# --- Gefühl, Gesicht, Blick, Lachen ----------------------------------------------------------------------

## Stimmung: Gesicht, Haltung, Blickstil, Lidschlag, Gesten und Atmung passen sich an (hält bis zur nächsten).
func feel(name: String, secs := 0.22, intensity := 1.0) -> void:
	emotion.set_mood(name, intensity, secs)


## Wie feel() – der Name bleibt für bestehende Aufrufer.
func express(name: String, secs := 0.18, intensity := 1.0) -> void:
	feel(name, secs, intensity)


## Gefühlsreaktion: steigt an, hält, klingt ab und hinterlässt ggf. eine Nachwirkung (LumosEmotion.META).
func react(name: String, intensity := 1.0, hold := -1.0, source: Variant = null) -> void:
	emotion.trigger(name, intensity, hold, -1.0, -1.0, source)


func cartoon(id: String, intensity := 0.7, opts := {}) -> bool:
	return LumosCartoon.react(self, id, intensity, opts)


func interact_with(kind: String, other: LumosActor, opts := {}) -> LumosInteraction:
	return LumosInteraction.start(kind, self, other, opts)


func gesture(id: String, opts := {}) -> bool:
	return micro.play(id, opts)


## Lippen bewegen sich silbenweise (Sprechen ohne Ton); Zuhörer schauen her und nicken.
func say(secs := 1.5, intensity := 0.8) -> void:
	if face == null:
		return
	face.talk = intensity
	var tw := create_tween()
	tw.tween_interval(secs)
	tw.tween_property(face, "talk", 0.0, 0.15)
	emit_social("talk", {"secs": secs})


func emit_social(kind: String, data := {}) -> void:
	if social:
		social.emit(kind, self, data)


## Blickziel: Vector3 (Welt), Node3D, LumosActor (schaut ins Gesicht) oder null. Augen springen, Kopf und
## Oberkörper folgen; ein neues Gegenüber wird mit einem kurzen Hochziehen der Brauen begrüßt.
func look_at_target(target: Variant) -> void:
	if target != null and not is_same(target, _look) and face and (target is LumosActor or target is Node3D):
		face.flash_brows(0.45)
	_look = target
	face_saccade(target)


func look_target() -> Variant:
	return _look


## Kurzes Hinschauen aus dem Sozialverhalten (unter look_at_target und Regie, über dem Mikroleben).
func look_social(target: Variant, secs := 1.5) -> void:
	_soc_look = target
	_soc_until = _t + secs
	face_saccade(target)


## Auf wen schaut die Figur gerade? (für Blickkontakt anderer)
func look_focus() -> LumosActor:
	if _look is LumosActor:
		return _look
	if _soc_look is LumosActor and _t < _soc_until:
		return _soc_look
	if _s_look_w < 0.05 and micro and micro.look_target is LumosActor:
		return micro.look_target
	return null


## Großer Blicksprung → gelegentlich Lidschlag (natürlich).
func face_saccade(target: Variant) -> void:
	if face == null or target == null:
		return
	var p := _resolve(target)
	if p == Vector3.INF or _eye_w < 0.05:
		return
	var head := body.joint_pos("head") if body else rig.global_position + Vector3.UP
	var a := (_eye - head).normalized()
	var bb := (p - head).normalized()
	face.saccade(a.angle_to(bb))


## Lachen als Kette: Schmunzeln → Lachen (Mund, Augen, Brust, Schultern im selben Takt) → klingt aus → then.
## emit = andere in der Nähe hören es (Ansteckung).
func laugh(duration := 1.4, strength := 1.0, then := "smile", emit := true) -> void:
	_laugh_t = 0.0
	_laugh_dur = maxf(duration, 0.6)
	_laugh_str = clampf(strength, 0.0, 1.0)
	emotion.trigger("laugh", lerpf(0.6, 1.0, _laugh_str), maxf(_laugh_dur - 0.6, 0.3), 0.18, 0.5)
	var tw := create_tween()
	tw.tween_interval(maxf(_laugh_dur - 0.5, 0.1))
	tw.tween_callback(func() -> void:
		if then != "" and emotion.mood_id in ["neutral", "smile", "grin", "laugh", "joy", "content"]:
			feel(then, 0.5))
	rig.squash(1.04, 0.97, 0.3)
	laughed.emit()
	if emit:
		emit_social("laugh", {"intensity": _laugh_str})


## Treffer/Stoß aus einer Weltrichtung: Oberkörper federt, Gesicht und Haltung reagieren, optional Stolper-Clip.
func react_hit(from_dir: Vector3, strength := 1.0, stumble_clip := false) -> void:
	var d := from_dir
	d.y = 0.0
	if d.length() > 0.01:
		if body:
			body.push(d.normalized() * 5.5 * strength + Vector3.UP * 0.6 * strength)
		else:
			var loc := rig.global_basis.inverse() * d.normalized()
			_rig_imp_v += Vector2(-loc.z, loc.x) * 4.0 * strength
	emotion.trigger("ouch", 1.0, 0.45 + 0.35 * strength, 0.04, 0.4)
	rig.squash(1.0 + 0.1 * strength, 1.0 - 0.08 * strength, 0.3)
	if stumble_clip:
		loco.play_action("stumble", "", 0.5, 0.1, 1.3)
	hit_reacted.emit(strength)
	emit_social("hit", {"intensity": strength})


## Kleiner Stoß ohne Schmerz (Kontakt bei Interaktionen): der Körper nimmt das Gewicht auf.
func nudge(world_impulse: Vector3) -> void:
	if body:
		body.push(world_impulse)
	else:
		var loc := rig.global_basis.inverse() * world_impulse
		_rig_imp_v += Vector2(-loc.z, loc.x) * 0.7


## Atmung fest vorgeben (Regie); amount < 0 gibt sie wieder an den Gefühlszustand zurück.
func set_breath(amount: float, rate := 1.4) -> void:
	_breath_over = amount >= 0.0
	if body and amount >= 0.0:
		body.breath = amount
		body.breath_rate = rate


# --- Regie-Eingänge (Trailer, Zwischensequenzen): höchste Schicht, je Bild gesetzt --------------------------------

func script_look(target: Vector3, weight: float) -> void:
	_s_look = target
	_s_look_w = clampf(weight, 0.0, 1.0)
	if _s_look_w > 0.05:
		layers.claim("script:look", ["eyes", "head"], LumosLayers.P_SCRIPT)
	elif layers.owner_of("eyes") == "script:look":
		layers.release("script:look")


func script_hand(hand: String, weight: float, target := Vector3.ZERO, orient: Array = [], assist := 0.6) -> void:
	_s_hands[hand] = [clampf(weight, 0.0, 1.0), target, orient, assist]
	var own := "script:arm." + hand
	if weight > 0.01:
		layers.claim(own, ["arm." + hand], LumosLayers.P_SCRIPT)
	elif layers.owner_of("arm." + hand) == own:
		layers.release(own)


func script_laugh(level: float) -> void:
	_s_laugh = clampf(level, 0.0, 1.0)


# --- Hände ---------------------------------------------------------------------------------------------------

## Hand an ein Ziel führen und dort halten: Vector3 (Welt), Node3D (folgt) oder Callable → Vector3.
## orient: Handhaltung [Finger, Handfläche] (Welt) oder Callable → Array; null = Hand bleibt, wie die Animation sie hält.
## assist: wie stark sich der Oberkörper zu einem zu fernen Ziel lehnen darf. owner: wer die Hand führt – release()
## mit Besitzer löst nur die eigene Hand (eine verdrängte Geste kann keine neue Haltung lösen).
func reach(hand: String, target: Variant, secs := 0.3, orient: Variant = null, assist := 1.0, owner := "") -> void:
	if not _hands.has(hand) or body == null or not body.has_arms():
		return
	var h: Dictionary = _hands[hand]
	if owner == "":   # ausdrücklicher Aufruf (Spiel, Regie): Kanal belegen, damit keine Leerlauf-Geste ihn übernimmt
		layers.claim("api:arm." + hand, ["arm." + hand], LumosLayers.P_API)
	h.target = target
	h.orient = orient
	h.assist = assist
	h.owner = owner
	h.to = 1.0
	h.rate = 1.0 / maxf(secs, 0.02)
	h.reached = false


func release(hand: String, secs := 0.35, owner := "") -> void:
	if not _hands.has(hand):
		return
	var h: Dictionary = _hands[hand]
	if owner != "" and String(h.owner) != owner:
		return
	if String(h.owner) == "":
		layers.release("api:arm." + hand)
	h.to = 0.0
	h.rate = 1.0 / maxf(secs, 0.02)
	hand_released.emit(hand)


func hand_owner(hand: String) -> String:
	return String(_hands[hand].owner) if _hands.has(hand) and float(_hands[hand].to) > 0.0 else ""


func hand_pos(hand: String) -> Vector3:
	return body.joint_pos("hand." + hand) if body else rig.global_position + Vector3.UP


func hand_weight(hand: String) -> float:
	return float(_hands[hand].w) if _hands.has(hand) else 0.0


## Punkt relativ zur Figur (rechts, oben, vorn) in Weltkoordinaten.
func rel(p_right: float, up: float, fwd: float) -> Vector3:
	var b := rig.global_basis
	return rig.global_position + b.x.normalized() * p_right + Vector3.UP * up - b.z.normalized() * fwd


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
		if not is_instance_valid(a):
			return Vector3.INF
		return a.body.joint_pos("head") + Vector3.UP * 0.25 if a.body else a.head_top() - Vector3.UP * a.head_radius()
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
	var p := rig.global_position
	if _prev_pos != Vector3.INF:
		var v := (p - _prev_pos) / maxf(d, 0.001)
		_vel = Vector3.ZERO if v.length() > 40.0 else _vel.lerp(v, 1.0 - exp(-d / 0.1))
	_prev_pos = p
	if body:
		body.dt = d
		body.hop_lift = rig.pivot.position.y if rig.pivot else 0.0
	if face:
		face.dt_scale = time_scale
	if lod < 2:
		mind.update(d)
		micro.update(d)
		_hat_clearance()
	emotion.update(d)
	_apply_emotion(d)
	_update_gaze(d)
	var lv := _update_laugh(d)
	_update_hands(d)
	if interact:
		interact.tick(d)
	if body == null:
		_rigid_body(d, lv)


## Breite Hutkrempe: kommt ein anderer Kopf in ihren Bereich, weicht der Hut nach hinten aus.
func _hat_clearance() -> void:
	if body == null or social == null:
		return
	var hr := body.hat_radius()
	if hr <= 0.0:
		return
	var me := body.joint_pos("head")
	var push := Vector3.ZERO
	for pc: Dictionary in social.perceive(self):
		var o: LumosActor = pc.a
		if float(pc.d) > hr + 1.2:
			continue
		var oh := o.body.joint_pos("head") if o.body else o.head_top()
		var to := oh - me
		to.y = 0.0
		var reach := hr + o.head_radius()
		if to.length() < reach and to.length() > 0.01:
			push += to.normalized() * (1.0 - to.length() / reach) * 1.6
	body.hat_avoid = body.hat_avoid.lerp(push.limit_length(1.0), 0.2)


func _apply_emotion(d: float) -> void:
	if face:
		face.set_params(emotion.face_out, 0.05)
		face.blink_mult = float(emotion.mods.blink)
		face.blink_slow = 1.7 if emotion.dominant() in ["exhausted", "sleepy", "content", "dreamy", "relief"] else 1.0
	var po := emotion.posture_out
	if body:
		body.set_posture_vec(po, 0.3)
		body.micro_head += cartoon_head
		if not _breath_over:
			var br: Array = emotion.mods.breath
			var ta := cfg.breath if br.is_empty() else lerpf(cfg.breath, float(br[0]), clampf(emotion.dominant_intensity(), 0.0, 1.0))
			var tr := cfg.breath_rate if br.is_empty() else lerpf(cfg.breath_rate, float(br[1]), clampf(emotion.dominant_intensity(), 0.0, 1.0))
			body.breath = lerpf(body.breath, ta, 1.0 - exp(-d / 0.8))
			body.breath_rate = lerpf(body.breath_rate, tr, 1.0 - exp(-d / 0.8))
	else:
		_rig_post_t = Vector2(po.x + po.y * 0.5, po.w) * cfg.posture_scale


## Blick: Augen springen schnell zum Ziel (Sakkade), der Kopf folgt verzögert und nur teilweise, der Oberkörper
## dreht mit. Vorrang: Regie > ausdrückliches Ziel > soziales Hinschauen > Mikroleben.
func _update_gaze(d: float) -> void:
	var want := Vector3.INF
	var w := 0.0
	var follow := 0.85
	var tau_h := lerpf(0.34, 0.16, personality.impulsivity)
	if _s_look_w > 0.02:   # Regie: Ziel ungeglättet – Augen springen, der Kopf folgt in ~0,15 s fast ganz
		want = _s_look
		w = _s_look_w
		follow = 0.92
		tau_h = 0.15
	elif _look != null:   # der Kopf dreht ~80 % mit, den Rest übernehmen die Augen (wie beim Menschen)
		want = _resolve(_look)
		w = 1.0
		follow = 0.8
	elif _soc_look != null and _t < _soc_until:
		want = _resolve(_soc_look)
		w = 0.9
		follow = 0.75
	elif micro.look_target != null:
		want = _resolve(micro.look_target)
		w = 0.75
		follow = micro.look_head * 0.8
	if want == Vector3.INF:
		w = 0.0
	if w > 0.0:
		_eye = want if _eye_w < 0.02 else _eye.lerp(want, 1.0 - exp(-d / 0.04))
		_gaze = want if _gaze_w < 0.02 else _gaze.lerp(want, 1.0 - exp(-d / tau_h))
	_eye_w = lerpf(_eye_w, w, 1.0 - exp(-d / 0.08))
	_gaze_w = lerpf(_gaze_w, w * follow, 1.0 - exp(-d / 0.2))
	if rig.modifier:
		rig.modifier.look_target = _gaze
		rig.modifier.look_weight = _gaze_w
	if body:
		body.attend_target = _gaze
		body.attend_w = _gaze_w
	if face:
		var loc: Vector3 = face.global_transform.affine_inverse() * _eye
		var gz := Vector2(clampf(loc.x / maxf(loc.z, 0.4) * 1.3, -1, 1), clampf((loc.y - _eye_y) / maxf(loc.z, 0.4) * 1.3, -1, 1))
		face.gaze_target = gz * _eye_w


func _update_laugh(d: float) -> float:
	var lv := 0.0
	if _laugh_t >= 0.0:
		_laugh_t += d
		lv = _laugh_str * smoothstep(0.0, 0.32, _laugh_t) * (1.0 - smoothstep(_laugh_dur - 0.65, _laugh_dur, _laugh_t))
		if _laugh_t >= _laugh_dur:
			_laugh_t = -1.0
	lv = maxf(lv, _s_laugh)
	if body:
		body.laugh = lv
	if face:
		face.laugh = lv
		face.laugh_phase = body.laugh_phase if body else _t * 17.0
	return lv


func _update_hands(d: float) -> void:
	if body == null:
		return
	for hand in ["l", "r"]:
		var h: Dictionary = _hands[hand]
		h.w = move_toward(float(h.w), float(h.to), float(h.rate) * d)
		var sw := smoothstep(0.0, 1.0, float(h.w))
		if sw > 0.0 and h.target != null and float(h.to) > 0.0:   # beim Lösen bleiben Ziel und Haltung stehen
			var p := _resolve(h.target)
			if p != Vector3.INF:
				body.hand_t[hand] = p
			else:
				h.to = 0.0   # Ziel verschwunden → sauber loslassen
			var o: Variant = h.orient
			if o is Callable:
				o = (o as Callable).call()
			var oa: Array = o if o is Array else []
			if not oa.is_empty() or float(h.w) >= 0.999:
				body.hand_dir[hand] = oa
		body.hand_w[hand] = sw
		body.hand_assist[hand] = float(h.assist)
		var sh: Array = _s_hands.get(hand, [])
		if not sh.is_empty() and float(sh[0]) > 0.001 and float(sh[0]) >= sw:   # Regie hat Vorrang
			body.hand_t[hand] = sh[1]
			body.hand_dir[hand] = sh[2]
			body.hand_w[hand] = float(sh[0])
			body.hand_assist[hand] = float(sh[3])
		if float(h.w) >= 1.0 and not h.reached:
			h.reached = true
			hand_reached.emit(hand)
		if float(h.w) <= 0.0 and float(h.to) <= 0.0:
			h.target = null
			h.orient = null
			h.owner = ""


## Haustier-Einzelteile (Schwanz, Beine) für prozedurale Bewegung finden.
func _find_pet_parts() -> void:
	if rig.model == null:
		return
	var legs: Array = []
	for n in rig.model.find_children("*", "Node3D", true, false):
		var nm := String(n.name).to_lower()
		if nm.contains("tail") and not _pet.has("tail"):
			_pet["tail"] = [n, (n as Node3D).transform]
		elif nm.contains("leg"):
			legs.append([n, (n as Node3D).transform])
	if not legs.is_empty():
		_pet["legs"] = legs


## Figuren ohne Skelett: Haltung, Lachen und Stöße als Neigen und Wippen des ganzen Körpers; Haustiere wedeln mit
## dem Schwanz (Freude schnell und weit, Angst eingezogen), bewegen beim Laufen die Beine und zittern bei Angst.
func _rigid_body(d: float, lv: float) -> void:
	if rig.pivot == null:
		return
	_rig_post = _rig_post.lerp(_rig_post_t, 1.0 - exp(-d / 0.15))
	_rig_imp_v += (-_rig_imp * 60.0 - _rig_imp_v * 8.0) * d
	_rig_imp += _rig_imp_v * d
	var rock := sin(_t * 17.0) * 0.08 * lv
	var trem := sin(_t * 46.0) * 0.04 * pet_tremble
	rig.pivot.rotation.x = _rig_post.x * 0.6 + _rig_lean.x + _rig_imp.x + rock
	rig.pivot.rotation.z = _rig_post.y + _rig_lean.y + _rig_imp.y + trem
	var dm := LumosEmotion.meta(emotion.dominant())   # Haustiere zeigen das vorherrschende Gefühl deutlich
	var val := float(dm.get("v", 0.0))
	var aro := float(dm.get("a", 0.4))
	if _pet.has("tail"):
		var tl: Array = _pet.tail
		var tn: Node3D = tl[0]
		var base: Transform3D = tl[1]
		var amp := (0.15 + 0.55 * maxf(val, 0.0) * (0.4 + aro)) * (1.0 - clampf(-val * 1.5, 0.0, 1.0))
		var wag := sin(_t * TAU * (1.6 + 3.2 * aro)) * amp
		var tuck := clampf(-val, 0.0, 1.0) * 0.7
		tn.transform = base * Transform3D(Basis.from_euler(Vector3(tuck, wag, 0.0)), Vector3.ZERO)
	if _pet.has("legs"):
		_step += speed() * d * 7.0
		var k := 0
		for e: Array in _pet.legs:
			var ln: Node3D = e[0]
			var lb: Transform3D = e[1]
			var ph := _step + (PI if k in [1, 2] else 0.0)
			ln.transform = lb * Transform3D(Basis(Vector3.RIGHT, sin(ph) * 0.45 * clampf(speed() * 1.5, 0.0, 1.0)), Vector3.ZERO)
			k += 1
