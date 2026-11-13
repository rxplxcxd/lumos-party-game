class_name LumosActor
extends Node
## Fassade des Character-Frameworks: hängt Gesicht, Körper-Ebene, Fortbewegung und Interaktionen an eine
## vorhandene CharacterRig-Figur – ohne das Rig oder das Modell zu verändern.
##
##   var actor := LumosActor.attach(rig)            # einmalig; idempotent
##   actor.move(wish_velocity, grounded, delta)     # Fortbewegung mit Trägheit + passende Schritte
##   actor.express("joy", 0.2, 0.7); actor.laugh(1.4)
##   actor.look_at_target(other_actor)              # Kopf + Augen, weich
##   actor.reach("r", some_node); actor.release("r")
##   actor.interact.grab(item, "r"); actor.interact.throw_to(target_pos)
##
## Signale: laughed, hit_reacted(strength), hand_reached(hand), hand_released(hand).
## Alle Teile sind einzeln nutzbar (face, body, loco, interact) und dürfen fehlen (z. B. Rig ohne Arme).

signal laughed
signal hit_reacted(strength: float)
signal hand_reached(hand: String)
signal hand_released(hand: String)

var rig: CharacterRig
var cfg: LumosActorConfig
var face: LumosFace            # null, wenn das Rig kein passendes Gesicht hat
var body: LumosBody
var loco: LumosLocomotion
var interact: LumosInteract
var time_scale := 1.0

var _look: Variant = null      # Vector3 | Node3D | LumosActor | null
var _gaze := Vector3.ZERO
var _gaze_w := 0.0
var _laugh_t := -1.0
var _laugh_dur := 0.0
var _laugh_str := 0.0
var _hands := {"l": {"w": 0.0, "to": 0.0, "rate": 4.0, "target": null, "reached": false},
	"r": {"w": 0.0, "to": 0.0, "rate": 4.0, "target": null, "reached": false}}
var _t := 0.0


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
	a.cfg = config if config else LumosActorConfig.new()
	p_rig.add_child(a)
	return a


static func of(p_rig: Node) -> LumosActor:
	return p_rig.get_node_or_null("LumosActor") as LumosActor if p_rig else null


func _ready() -> void:
	process_priority = 10   # nach der Spiellogik, vor dem Skelett-Update
	if rig.skel:
		body = LumosBody.new()
		rig.skel.add_child(body)
		if not body.bind(rig.skel, cfg):
			push_warning("LumosActor: Skelett ohne Brust/Kopf – Körper-Ebene eingeschränkt")
		if cfg.face_enabled:
			var f := LumosFace.new()
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


# --- Fortbewegung --------------------------------------------------------------------------------------------

## Bequemer Weg: Wunschgeschwindigkeit angeben, die Figur wird mit Trägheit bewegt und passend animiert.
func move(wish_velocity: Vector3, grounded := true, delta := -1.0) -> void:
	var d := (delta if delta > 0.0 else get_process_delta_time()) * time_scale
	var v := loco.steer(wish_velocity, d)
	rig.global_position += v * d
	animate(v, grounded, d)


## Nur animieren (die Figur wird vom Spiel selbst bewegt, z. B. CharacterBody3D): echte Geschwindigkeit übergeben.
func animate(velocity: Vector3, grounded := true, delta := -1.0) -> void:
	var d := (delta if delta > 0.0 else get_process_delta_time()) * time_scale
	loco.update(velocity, grounded, d)
	if body:
		# Beschleunigen → Vorlage, Bremsen → Rücklage, Kurve → Neigung nach innen
		body.lean = Vector2(clampf(loco.accel_local.z * -cfg.lean_accel + velocity.length() * 0.012, -0.3, 0.35),
			clampf(-loco.turn_speed * cfg.lean_turn * minf(velocity.length() / 3.0, 1.0), -0.25, 0.25))
		body.foot_w = lerpf(body.foot_w, 1.0 if grounded else 0.0, 0.25)


# --- Gesicht, Blick, Lachen -------------------------------------------------------------------------------

func express(name: String, secs := 0.18, intensity := 1.0) -> void:
	if face:
		face.set_expression(name, secs, intensity)


## Blickziel: Vector3 (Welt), Node3D, LumosActor (schaut ins Gesicht) oder null (kein Ziel).
func look_at_target(target: Variant) -> void:
	_look = target


func look_target() -> Variant:
	return _look


## Lachen als Kette: Schmunzeln → Lachen (Mund, Augen, Brust, Schultern im selben Takt) → klingt aus → then.
func laugh(duration := 1.4, strength := 1.0, then := "smile") -> void:
	_laugh_t = 0.0
	_laugh_dur = maxf(duration, 0.6)
	_laugh_str = clampf(strength, 0.0, 1.0)
	express("grin", 0.14)
	var tw := create_tween()
	tw.tween_interval(0.2)
	tw.tween_callback(express.bind("laugh", 0.16, lerpf(0.6, 1.0, _laugh_str)))
	tw.tween_interval(maxf(_laugh_dur - 0.7, 0.1))
	tw.tween_callback(express.bind(then, 0.5))
	rig.squash(1.04, 0.97, 0.3)
	laughed.emit()


## Treffer/Stoß aus einer Weltrichtung: Oberkörper federt, Gesicht reagiert, optional Stolper-Clip.
func react_hit(from_dir: Vector3, strength := 1.0, stumble := false) -> void:
	var d := from_dir
	d.y = 0.0
	if body and d.length() > 0.01:
		body.push(d.normalized() * 5.5 * strength + Vector3.UP * 0.6 * strength)
	express("ouch", 0.08)
	rig.squash(1.0 + 0.1 * strength, 1.0 - 0.08 * strength, 0.3)
	if stumble:
		loco.play_action("stumble", "", 0.5, 0.1, 1.3)
	var tw := create_tween()
	tw.tween_interval(0.45 + 0.35 * strength)
	tw.tween_callback(express.bind("neutral", 0.4))
	hit_reacted.emit(strength)


func set_breath(amount: float, rate := 1.4) -> void:
	if body:
		body.breath = amount
		body.breath_rate = rate


# --- Hände ---------------------------------------------------------------------------------------------------

## Hand an ein Ziel führen und dort halten: Vector3 (Welt), Node3D (folgt) oder Callable → Vector3.
func reach(hand: String, target: Variant, secs := 0.3) -> void:
	if not _hands.has(hand) or body == null or not body.has_arms():
		return
	var h: Dictionary = _hands[hand]
	h.target = target
	h.to = 1.0
	h.rate = 1.0 / maxf(secs, 0.02)
	h.reached = false


## Hand weich zurück in die Animation führen.
func release(hand: String, secs := 0.35) -> void:
	if not _hands.has(hand):
		return
	var h: Dictionary = _hands[hand]
	h.to = 0.0
	h.rate = 1.0 / maxf(secs, 0.02)
	hand_released.emit(hand)


func hand_pos(hand: String) -> Vector3:
	return body.joint_pos("hand." + hand) if body else rig.global_position


func hand_weight(hand: String) -> float:
	return float(_hands[hand].w) if _hands.has(hand) else 0.0


## Punkt relativ zur Figur (rechts, oben, vorn) in Weltkoordinaten.
func rel(right: float, up: float, fwd: float) -> Vector3:
	var b := rig.global_basis
	return rig.global_position + b.x.normalized() * right + Vector3.UP * up - b.z.normalized() * fwd


func forward() -> Vector3:
	return -rig.global_basis.z.normalized()


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


func _process(delta: float) -> void:
	var d := delta * time_scale
	_t += d
	if body:
		body.dt = d
	if face:
		face.dt_scale = time_scale
	# Blick: Kopf (über den Modifier des Spiels) und Augen wandern weich zum Ziel
	var want := _resolve(_look) if _look != null else Vector3.INF
	var w := 1.0 if want != Vector3.INF else 0.0
	if w > 0.0:
		_gaze = want if _gaze_w < 0.02 else _gaze.lerp(want, 1.0 - exp(-d / 0.14))
	_gaze_w = lerpf(_gaze_w, w, 1.0 - exp(-d / 0.2))
	if rig.modifier:
		rig.modifier.look_target = _gaze
		rig.modifier.look_weight = _gaze_w
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
			body.hand_w[hand] = sw
			if float(h.w) >= 1.0 and not h.reached:
				h.reached = true
				hand_reached.emit(hand)
			if float(h.w) <= 0.0 and float(h.to) <= 0.0:
				h.target = null
	if interact:
		interact.tick(d)
