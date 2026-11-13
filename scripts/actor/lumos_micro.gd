class_name LumosMicro
extends RefCounted
## Mikroleben und Gesten-Engine einer Figur.
##
## Leerlauf (nur auf freien Kanälen, Priorität P_MICRO): Blicke zu anderen Figuren, Dingen und in die Umgebung
## (Augen springen zuerst, der Kopf folgt), Blickkontakt halten oder ausweichen (Persönlichkeit), Blick nach unten
## oder oben je Gefühl, Gewichtswechsel zwischen Stand- und Spielbein, kleine Kopfbewegungen, Ausweichen im
## persönlichen Raum und gelegentliche Gesten passend zu Gefühl und Persönlichkeit.
##
## Gesten (play): prozedurale Abläufe über die Hand-IK und additive Kopf-/Brust-Bewegungen. Andere Systeme
## (Sozialverhalten, Cartoon, Interaktionen) spielen sie mit höherer Priorität ab. Jede Geste hat Ein-, Halte- und
## Ausblendphase; wird sie verdrängt, lösen sich die Hände sauber.

## Gesten: Dauer (s), Kanäle, nur im Stehen?
const GESTURES := {
	"scratch": [1.5, ["arm.r", "head"], false], "face_touch": [1.4, ["arm.l"], false], "chin": [2.4, ["arm.r", "head"], false],
	"adjust": [1.1, ["arm.l", "arm.r"], false], "hips": [2.6, ["arm.l", "arm.r"], true], "cross_arms": [2.8, ["arm.l", "arm.r"], false],
	"rub_hands": [1.7, ["arm.l", "arm.r"], false], "clasp": [1.9, ["arm.l", "arm.r"], false], "wipe_brow": [1.3, ["arm.r"], false],
	"stretch": [2.3, ["arm.l", "arm.r", "torso"], true], "hug_self": [2.4, ["arm.l", "arm.r"], false],
	"clap": [1.3, ["arm.l", "arm.r"], false], "fist_pump": [1.0, ["arm.r"], false], "arms_up": [1.5, ["arm.l", "arm.r"], false],
	"head_shake": [1.1, ["head"], false], "nod": [0.9, ["head"], false], "shrug": [1.4, ["arm.l", "arm.r", "head"], false],
	"tap": [1.8, ["legs"], true], "bounce": [1.3, ["legs"], true], "clutch": [1.7, ["arm.l", "arm.r"], false],
	"facepalm": [1.5, ["arm.r", "head"], false], "face_hide": [1.7, ["arm.l", "arm.r", "head"], false],
	"fists": [1.6, ["arm.l", "arm.r"], false], "wave": [1.7, ["arm.r"], false], "point": [1.7, ["arm.r"], false],
	"flail": [1.4, ["arm.l", "arm.r"], false], "belly": [1.6, ["arm.l"], false], "knee_slap": [1.6, ["arm.r"], false],
	"wipe_tears": [1.2, ["arm.r"], false], "cheer": [1.6, ["arm.l", "arm.r"], false],
}
## Gesten, die eine Persönlichkeit von sich aus zeigt (ohne Gefühl): Zug → Gesten
const TRAIT_GESTURES := {"confidence": ["hips", "adjust"], "shyness": ["rub_hands", "scratch", "face_touch"],
	"curiosity": ["chin"], "energy": ["bounce", "stretch"], "playfulness": ["bounce", "rub_hands"]}

var actor: LumosActor
var enabled := true
var stats := {"glances": 0, "contacts": 0, "aversions": 0, "shifts": 0, "gestures": {}}
var gesture := ""                   # laufende Geste
var gesture_t := 0.0
var look_target: Variant = null     # Blickziel aus dem Mikroleben (Vector3 | LumosActor | Node3D)
var look_head := 0.85               # wie weit der Kopf dem Blick folgt (Seitenblick: wenig)

var _g := {}                        # laufende Geste: id, dur, t, owner, opts, hands
var _t_look := 0.5
var _look_left := 0.0
var _t_gest := 4.0
var _t_shift := 3.0
var _t_head := 2.0
var _head_t := Vector3.ZERO
var _head_cur := Vector3.ZERO
var _contact: LumosActor
var _space_t := 0.0
var _crouch := 0.0


func setup(a: LumosActor) -> void:
	actor = a
	_t_look = actor.rng.randf_range(0.3, 1.5)
	_t_gest = actor.rng.randf_range(3.0, 7.0)
	_t_shift = actor.rng.randf_range(1.5, 4.0)


# --- Gesten ---------------------------------------------------------------------------------------------------

## Geste abspielen. opts: side ("l"/"r"), target (Vector3/LumosActor, z. B. zum Winken/Zeigen), dur, prio, owner.
## false = abgelehnt (Kanäle belegt, Figur kann die Geste nicht).
func play(id: String, opts := {}) -> bool:
	if not GESTURES.has(id) or actor.body == null:
		return false
	var g: Array = GESTURES[id]
	var chans: Array = (g[1] as Array).duplicate()
	var side := String(opts.get("side", "r"))
	if side == "l":
		for i in chans.size():
			chans[i] = {"arm.r": "arm.l", "arm.l": "arm.r"}.get(chans[i], chans[i])
	if not actor.body.has_arms():
		chans = chans.filter(func(c: String) -> bool: return not c.begins_with("arm"))
	var prio := int(opts.get("prio", LumosLayers.P_MICRO))
	var owner := String(opts.get("owner", "g:" + id))
	if gesture != "":
		if prio <= int(_g.get("prio", 0)) and String(_g.owner) != owner:
			return false   # eine wichtigere Geste läuft
		stop()
	if not actor.layers.claim(owner, chans, prio, stop):
		return false
	_g = {"id": id, "dur": float(opts.get("dur", float(g[0]))), "t": 0.0, "owner": owner, "opts": opts, "side": side,
		"chans": chans, "seed": actor.rng.randf(), "prio": prio}
	gesture = id
	gesture_t = 0.0
	stats.gestures[id] = int(stats.gestures.get(id, 0)) + 1
	for sd in ["l", "r"]:
		if ("arm." + sd) in chans and actor.body.arm_mode() != "none":
			actor.reach(sd, _target.bind(sd), 0.26, _orient.bind(sd), 0.25, owner)
	if id == "flail" and actor.body:
		actor.body.stumble(Vector3.ZERO, 1.0)
	return true


func stop() -> void:
	if gesture == "":
		return
	var owner := String(_g.owner)
	for sd in ["l", "r"]:
		actor.release(sd, 0.3, owner)
	actor.layers.release(owner)
	gesture = ""
	_g = {}
	if actor.body:
		actor.body.crouch = 0.0
		actor.body.micro_chest = Vector3.ZERO


## Ziel der Hand sd für die laufende Geste (Welt) – je Bild ausgewertet.
func _target(sd: String) -> Vector3:
	if _g.is_empty():
		return Vector3.INF
	var id := String(_g.id)
	var t := float(_g.t)
	var r := actor.head_radius()
	var s := 1.0 if sd == "r" else -1.0      # Seitenvorzeichen (rechts +)
	var rt := actor.right()
	var fw := actor.forward()
	var up := Vector3.UP
	var b := actor.body
	var head := b.joint_pos("head") + up * r * 0.55
	var chest := b.joint_pos("chest")
	var sh := b.joint_pos("shoulder." + sd)
	var hips := b.joint_pos("hips")
	var osc := sin(t * TAU * 4.5 + float(_g.seed) * 6.0)
	match id:
		"scratch":
			return head + rt * s * r * 0.55 + up * r * (0.5 + 0.04 * osc) + fw * r * 0.05
		"face_touch":
			return head + rt * s * r * 0.62 - up * r * 0.3 + fw * r * 0.55
		"chin":
			return head - up * r * 0.68 + fw * r * 0.62 + rt * s * r * 0.1
		"adjust":
			return chest + fw * r * 0.42 + rt * s * r * 0.28 - up * r * (0.1 + 0.12 * smoothstep(0.55, 0.85, t / float(_g.dur)))
		"hips":
			return hips + rt * s * r * 0.62 + up * r * 0.12 + fw * r * 0.06
		"cross_arms":
			return chest + fw * r * 0.48 - rt * s * r * 0.32 - up * r * (0.12 if sd == "r" else 0.24)
		"rub_hands":
			return chest + fw * r * 0.55 - up * r * 0.35 + rt * s * r * 0.04 + rt * osc * r * 0.05
		"clasp", "clutch":
			return chest + fw * r * 0.52 + up * r * (0.12 if id == "clutch" else -0.05) + rt * s * r * 0.04
		"wipe_brow":
			return head + up * r * 0.25 + fw * r * 0.72 + rt * r * (0.35 - 0.7 * smoothstep(0.25, 0.75, t / float(_g.dur)))
		"stretch", "arms_up", "cheer":
			var wav := sin(t * TAU * 1.6 + (0.0 if sd == "r" else 1.5)) * 0.12 if id == "cheer" else 0.0
			return sh + up * r * (1.35 + wav) + rt * s * r * (0.3 if id == "stretch" else 0.6) + fw * r * 0.1
		"hug_self":
			var other := b.joint_pos("shoulder." + ("l" if sd == "r" else "r"))
			return other - up * r * 0.28 + fw * r * 0.22
		"clap":
			var cl := absf(sin(t * TAU * 1.8))
			return chest + fw * r * 0.6 - up * r * 0.05 + rt * s * r * (0.02 + 0.22 * cl)
		"fist_pump":
			var e := sin(clampf(t / float(_g.dur), 0.0, 1.0) * PI)
			return sh + up * r * (0.3 + 0.75 * e) + fw * r * 0.25
		"shrug":
			return hips + rt * s * r * 0.85 + fw * r * 0.45 + up * r * 0.3
		"facepalm":
			return head + fw * r * 0.78 + up * r * 0.08
		"face_hide":
			return head + fw * r * 0.75 + rt * s * r * 0.22 - up * r * 0.05
		"fists":
			return hips + fw * r * 0.42 + rt * s * r * 0.38 + up * r * 0.2
		"wave":
			return sh + up * r * 0.8 + rt * s * r * (0.35 + 0.16 * sin(t * TAU * 2.6)) + fw * r * 0.18
		"point":
			var tp := _opt_pos("target", sh + fw * 3.0)
			return sh + (tp - sh).normalized() * b.reach_length() * 0.92
		"belly":
			return hips + fw * r * 0.5 + up * r * 0.35 + rt * s * r * 0.05
		"knee_slap":
			var ks := absf(sin(t * TAU * 1.7))
			return hips + fw * r * 0.45 + rt * s * r * 0.25 - up * r * (0.25 + 0.35 * ks)
		"wipe_tears":
			return head + fw * r * 0.8 + rt * s * r * 0.3 + up * r * (0.02 * osc)
	return Vector3.INF


## Handhaltung [Finger, Handfläche] für die laufende Geste.
func _orient(sd: String) -> Array:
	if _g.is_empty():
		return []
	var s := 1.0 if sd == "r" else -1.0
	var rt := actor.right()
	var fw := actor.forward()
	var up := Vector3.UP
	match String(_g.id):
		"scratch", "face_touch", "wipe_tears":
			return [up, -rt * s]
		"chin":
			return [-rt * s, up]
		"adjust", "hips":
			return [-up, -rt * s]
		"cross_arms", "hug_self":
			return [-rt * s, -fw]
		"rub_hands", "clasp", "clap", "clutch":
			return [fw * 0.4 + up, -rt * s]
		"wipe_brow", "facepalm", "face_hide":
			return [up, -fw]
		"stretch", "arms_up", "cheer", "fist_pump":
			return [up, fw]
		"shrug":
			return [fw, up]
		"fists":
			return [fw, -up]
		"wave":
			return [up, fw]
		"point":
			var tp := _opt_pos("target", actor.rig.global_position + fw * 3.0)
			var d := tp - actor.body.joint_pos("shoulder." + sd)
			return [d.normalized(), -up]
		"belly":
			return [-rt * s, -fw]
		"knee_slap":
			return [fw, -up]
	return []


func _opt_pos(key: String, fallback: Vector3) -> Vector3:
	var v: Variant = (_g.opts as Dictionary).get(key, null)
	if v is Vector3:
		return v
	if v is LumosActor:
		return (v as LumosActor).body.joint_pos("head") if (v as LumosActor).body else (v as LumosActor).rig.global_position + Vector3.UP
	if v is Node3D and is_instance_valid(v):
		return (v as Node3D).global_position
	return fallback


func _tick_gesture(d: float) -> void:
	if gesture == "":
		return
	_g.t = float(_g.t) + d
	gesture_t = float(_g.t)
	var t := float(_g.t)
	var dur := float(_g.dur)
	var ph := clampf(t / dur, 0.0, 1.0)
	var env := smoothstep(0.0, 0.18, ph) * (1.0 - smoothstep(0.82, 1.0, ph))
	var b := actor.body
	var hd := Vector3.ZERO
	var ch := Vector3.ZERO
	var cr := 0.0
	match String(_g.id):
		"scratch":
			hd = Vector3(0.04, 0.0, 0.14 * (1.0 if String(_g.side) == "r" else -1.0))
		"chin":
			hd = Vector3(-0.1, 0.0, 0.08)
		"stretch":
			ch = Vector3(-0.16, 0.0, 0.0)
			hd = Vector3(-0.18, 0.0, 0.0)
		"head_shake":
			hd = Vector3(0.02, sin(t * TAU * 3.2) * 0.2, 0.0)
		"nod":
			hd = Vector3(absf(sin(t * TAU * 2.2)) * 0.16, 0.0, 0.0)
		"shrug":
			hd = Vector3(0.0, 0.0, 0.12)
			ch = Vector3(-0.04, 0.0, 0.0)
		"facepalm":
			hd = Vector3(0.18, sin(t * TAU * 1.4) * 0.06, 0.0)
		"face_hide":
			hd = Vector3(0.24, 0.0, 0.0)
			ch = Vector3(0.1, 0.0, 0.0)
		"tap":
			cr = absf(sin(t * TAU * 2.2)) * 0.12
		"bounce":
			cr = absf(sin(t * TAU * 2.6)) * 0.2
		"cross_arms":
			hd = Vector3(-0.06, 0.0, 0.0)
		"hips":
			ch = Vector3(-0.05, 0.0, 0.0)
		"belly", "knee_slap":
			ch = Vector3(0.22, 0.0, 0.0)
			cr = 0.25
		"cheer", "arms_up":
			hd = Vector3(-0.12, 0.0, 0.0)
	if b:
		b.micro_chest = ch * env
		b.crouch = maxf(_crouch, cr * env)
		if "head" in (_g.chans as Array):
			_head_cur = hd * env
	if t >= dur:
		stop()


# --- Leerlauf ----------------------------------------------------------------------------------------------------

func update(d: float) -> void:
	if not enabled:
		return
	_tick_gesture(d)
	var p := actor.personality
	var em := actor.emotion
	var gz := String(em.mods.gaze) if em else ""
	var still := actor.speed() < 0.25
	# Blick
	_look_left -= d
	_t_look -= d
	if actor.layers.is_free("eyes") or actor.layers.prio_of("eyes") <= LumosLayers.P_MICRO:
		if _look_left <= 0.0 and look_target != null:
			_end_look(p, gz)
		if _t_look <= 0.0:
			_pick_look(p, gz)
	# Gewichtswechsel (Stand- und Spielbein) und kleine Kopfbewegungen im Stand
	_t_shift -= d
	if _t_shift <= 0.0 and actor.body:
		_t_shift = actor.rng.randf_range(2.8, 7.5) / lerpf(0.75, 1.35, p.energy)
		if still and actor.layers.is_free("legs"):
			var r := actor.rng.randf()
			actor.body.weight_shift = 0.0 if r < 0.25 else actor.rng.randf_range(0.55, 1.0) * (-1.0 if actor.body.weight_shift > 0.0 else 1.0)
			stats.shifts = int(stats.shifts) + 1
	_t_head -= d
	if _t_head <= 0.0:
		_t_head = actor.rng.randf_range(1.6, 4.5)
		_head_t = Vector3(actor.rng.randf_range(-0.05, 0.06), actor.rng.randf_range(-0.05, 0.05), actor.rng.randf_range(-0.08, 0.08)) \
			* lerpf(0.6, 1.3, p.energy)
	if actor.body and gesture == "" or (gesture != "" and not ("head" in (_g.get("chans", []) as Array))):
		_head_cur = _head_cur.lerp(_head_t, 1.0 - exp(-d / 0.6))
	if actor.body:
		actor.body.micro_head = _head_cur
	# Gesten passend zu Gefühl und Persönlichkeit
	_t_gest -= d
	if _t_gest <= 0.0:
		var pressure := 0.55 if em and not (em.mods.gest as Array).is_empty() else 1.0
		_t_gest = actor.rng.randf_range(4.0, 9.5) * pressure / p.fidget_rate()
		if still and gesture == "" and actor.autonomy_gate(0.2):
			_pick_gesture(p)
	_personal_space(d)


func _pick_look(p: LumosPersonality, gz: String) -> void:
	var rng := actor.rng
	var hub := actor.social
	var scan := gz == "scan"
	_t_look = rng.randf_range(1.1, 3.4) * lerpf(1.4, 0.7, p.curiosity) * (0.45 if scan else 1.0)
	look_head = 0.85
	if gz == "none":
		look_target = null
		return
	var cands: Array = []   # [Ziel, Gewicht, Dauer, Kopf]
	var me := actor.rig.global_position
	var fw := actor.forward()
	if hub and gz != "avert" and gz != "down":
		for pc: Dictionary in hub.perceive(actor):
			var o: LumosActor = pc.a
			if float(pc.d) > 9.0:
				continue
			var w := 1.0 + (2.5 if bool(pc.looks_at_me) else 0.0) + (1.6 if bool(pc.talking) else 0.0) + (1.4 if bool(pc.laughing) else 0.0) \
				+ maxf(float(pc.approach), 0.0) * 1.2 + float(pc.arousal) * 0.8
			w *= lerpf(1.3, 0.6, float(pc.d) / 9.0) * lerpf(0.6, 1.4, p.sociability)
			cands.append([o, w, rng.randf_range(0.8, 2.2), 0.85])
		for poi: Dictionary in hub.pois:
			var n: Node3D = poi.node
			if is_instance_valid(n) and n.global_position.distance_to(me) < 12.0:
				cands.append([n, float(poi.salience) * lerpf(0.5, 1.6, p.curiosity), rng.randf_range(0.8, 2.0), 0.8])
	# Umgebung: je Gefühl nach unten (traurig, beschämt), nach oben (Nachdenken, Träumen) oder umher
	var side := actor.right() * rng.randf_range(-2.4, 2.4)
	var env_w := 0.8 + (2.0 if gz in ["down", "avert", "think", "up", "scan"] else 0.0)
	var env_p := me + fw * rng.randf_range(2.5, 6.0) + side + Vector3.UP * rng.randf_range(0.8, 2.2)
	match gz:
		"down", "avert":
			env_p = me + fw * rng.randf_range(1.2, 2.6) + side * 0.5 + Vector3.UP * 0.05
		"think", "up":
			env_p = me + fw * 2.0 + side * 0.8 + Vector3.UP * rng.randf_range(3.2, 4.5)
	cands.append([env_p, env_w, rng.randf_range(0.7, 1.8), 0.7 if gz in ["think", "up"] else 0.85])
	if gz == "side" and actor.emotion and actor.emotion.dominant() != "":
		look_head = 0.25   # Seitenblick: die Augen gehen, der Kopf kaum
	var tot := 0.0
	for c: Array in cands:
		tot += float(c[1])
	var r := rng.randf() * tot
	for c2: Array in cands:
		r -= float(c2[1])
		if r <= 0.0:
			look_target = c2[0]
			_look_left = float(c2[2]) * (0.5 if scan else 1.0)
			look_head = minf(look_head, float(c2[3]))
			break
	_contact = look_target as LumosActor if look_target is LumosActor else null
	if _contact:
		var mutual: bool = _contact.look_focus() == actor
		if mutual:   # Blickkontakt: halten je Persönlichkeit, Brauen heben, freundlich lächeln
			stats.contacts = int(stats.contacts) + 1
			_look_left = p.eye_contact_time(rng)
			if actor.face:
				actor.face.flash_brows(0.4)
			if actor.emotion and p.friendliness > 0.4 and actor.autonomy_gate(0.35):
				actor.emotion.trigger("smile", 0.45 * p.friendliness, _look_left, 0.25, 0.5, _contact)
	stats.glances = int(stats.glances) + 1
	actor.face_saccade(look_target)


func _end_look(p: LumosPersonality, gz: String) -> void:
	# Blickkontakt brechen: Schüchterne schauen nach unten/zur Seite, sonst zum nächsten Ziel
	if _contact and actor.rng.randf() < p.avert_chance():
		stats.aversions = int(stats.aversions) + 1
		look_target = actor.rig.global_position + actor.forward() * 1.6 + actor.right() * actor.rng.randf_range(-1.2, 1.2) + Vector3.UP * 0.1
		look_head = 0.55
		_look_left = actor.rng.randf_range(0.6, 1.2)
		_t_look = _look_left
		_contact = null
		return
	look_target = null
	_contact = null
	_t_look = minf(_t_look, actor.rng.randf_range(0.15, 0.6))


func _pick_gesture(p: LumosPersonality) -> void:
	var pool: Array = []
	if actor.emotion:
		for g: String in actor.emotion.mods.gest:
			pool.append([g, 3.0])
	for tr: String in TRAIT_GESTURES:
		var v := float(p.get(tr))
		if v > 0.55:
			for g2: String in TRAIT_GESTURES[tr]:
				pool.append([g2, (v - 0.4) * 2.0])
	pool.append(["scratch", 0.4])
	pool.append(["adjust", 0.4])
	pool.append(["face_touch", 0.3])
	var standing := actor.is_standing()
	var tot := 0.0
	var ok: Array = []
	for e: Array in pool:
		var id := String(e[0])
		if not GESTURES.has(id) or (bool((GESTURES[id] as Array)[2]) and not standing):
			continue
		if id in ["wave", "point", "poke", "flail"]:
			continue
		ok.append(e)
		tot += float(e[1])
	var r := actor.rng.randf() * tot
	for e2: Array in ok:
		r -= float(e2[1])
		if r <= 0.0:
			play(String(e2[0]), {"side": "r" if actor.rng.randf() < 0.65 else "l"})
			return


## Persönlicher Raum: kommt jemand zu nah, lehnt sich die Figur zurück und schaut hin (Schüchterne früher).
func _personal_space(d: float) -> void:
	_space_t -= d
	if _space_t > 0.0 or actor.social == null or actor.body == null:
		return
	_space_t = 0.25
	var lean := 0.0
	for pc: Dictionary in actor.social.perceive(actor):
		var o: LumosActor = pc.a
		var comfort := (actor.head_radius() + o.head_radius()) * lerpf(1.15, 1.6, actor.personality.shyness)
		if float(pc.d) < comfort and float(pc.approach) > 0.25 and not actor.in_interaction():
			lean = -0.1 * (1.0 - float(pc.d) / comfort) - 0.04
			if look_target == null:
				look_target = o
				_look_left = 0.8
	if gesture == "":
		actor.body.micro_chest = actor.body.micro_chest.lerp(Vector3(lean, 0, 0), 0.5)
