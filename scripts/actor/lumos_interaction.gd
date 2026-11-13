class_name LumosInteraction
extends RefCounted
## Universelles Interaktionsprotokoll zwischen zwei Figuren (oder einer Figur und einem Gegenstand).
##
## Jede Interaktion hat Initiator (a), Ziel (b), Art (kind), Absicht (opts.intent) und läuft in Phasen:
##   approach  Annäherung, Zuwenden, Blickkontakt (Brauen heben), Vorbereitung (Ausholen)
##   contact   Kontaktpunkte werden angefahren (Hände mit Ausrichtung, aus der echten Reichweite berechnet)
##   main      eigentliche Interaktion (Schlag, Drücken, Schütteln, Klopfen, Übergabe …)
##   response  Reaktion des Gegenübers (Rückfedern, Lachen, Erleichterung …)
##   after     Nachwirkung (Lösen, Zurücktreten, Gefühle klingen aus)
## Danach wird alles sauber beendet: Hände nur vom eigenen Besitzer gelöst, Zusatz-Neigungen zurückgesetzt,
## Schicht-Ansprüche (P_INTERACT) freigegeben. Wird eine Interaktion verdrängt oder ein Teilnehmer verschwindet,
## bricht sie kontrolliert ab (cancel) – niemand springt in eine andere Position.
##
## Arten: high_five, handshake, hug, pat, take_hand, give, comfort, tease, cheer_together, dance_together,
## playful_shove, scare, shared_laugh. Figuren ohne zweiteilige Arme bekommen eine Körper-Variante (Stups).
##
##   var it := LumosInteraction.start("hug", a, b)       # null = abgelehnt (einer ist beschäftigt)
##   it.finished.connect(func(ok): …)

signal phase_changed(name: String)
signal finished(ok: bool)

const KINDS := ["high_five", "handshake", "hug", "pat", "take_hand", "give", "comfort", "tease", "cheer_together",
	"dance_together", "playful_shove", "scare", "shared_laugh"]

var kind := ""
var a: LumosActor
var b: LumosActor
var opts := {}
var phase := ""
var done := false
var ok := true
var phases_done: Array[String] = []
var times := {}                  # Phase → Startzeit (s seit Beginn)
var t := 0.0
var _pt := 0.0
var _i := -1
var _plan: Array = []
var _owner := ""
var _tw: Array = []
var _clean: Array = []
var _saved := {}                 # Figur → [chest_add, head_add] beim Start (werden am Ende wiederhergestellt)
var _n := Vector3.FORWARD        # Richtung a → b (waagerecht), beim Start bestimmt
var _rt := Vector3.RIGHT


## Interaktion starten. opts: move (false = niemand wird versetzt), secs, count, hand, intent …
static func start(p_kind: String, p_a: LumosActor, p_b: LumosActor, p_opts := {}) -> LumosInteraction:
	if p_a == null or p_a.social == null or not (p_kind in KINDS):
		return null
	var it := LumosInteraction.new()
	it.kind = p_kind
	it.a = p_a
	it.b = p_b
	it.opts = p_opts
	it._owner = "ia:%s:%d" % [p_kind, it.get_instance_id()]
	var ch := ["root", "torso", "head", "eyes", "arm.l", "arm.r"]
	if not p_a.layers.claim(it._owner, ch, LumosLayers.P_INTERACT, it.cancel):
		return null
	if p_b and not p_b.layers.claim(it._owner, ch, LumosLayers.P_INTERACT, it.cancel):
		p_a.layers.release(it._owner)
		return null
	if p_b:
		var d := p_b.rig.global_position - p_a.rig.global_position
		d.y = 0.0
		it._n = d.normalized() if d.length() > 0.01 else p_a.forward()
		it._rt = it._n.cross(Vector3.UP).normalized()
	for p in [p_a, p_b]:
		if p != null and p.body:
			it._saved[p] = [p.body.chest_add, p.body.head_add]
	it._plan = it._build()
	if it._plan.is_empty():
		it._finish(false)
		return null
	p_a.social.add_interaction(it)
	it._next()
	return it


func tick(d: float) -> void:
	if done:
		return
	if not is_instance_valid(a) or (b != null and not is_instance_valid(b)):
		cancel()
		return
	t += d
	_pt += d
	var ph: Dictionary = _plan[_i]
	var tk: Callable = ph.get("tick", Callable())
	if tk.is_valid():
		tk.call(_pt, d)
	var dur := float(ph.get("dur", 0.3))
	var until: Callable = ph.get("until", Callable())
	if _pt >= dur and (not until.is_valid() or bool(until.call()) or _pt >= dur * 2.5 + 0.5):
		_next()


func cancel() -> void:
	if not done:
		_finish(false)


func _next() -> void:
	_i += 1
	if _i >= _plan.size():
		_finish(true)
		return
	var ph: Dictionary = _plan[_i]
	phase = String(ph.name)
	_pt = 0.0
	times[phase] = t
	phases_done.append(phase)
	phase_changed.emit(phase)
	var en: Callable = ph.get("enter", Callable())
	if en.is_valid():
		en.call()


func _finish(p_ok: bool) -> void:
	done = true
	ok = p_ok
	phase = "end"
	for tw in _tw:
		if tw is Tween and (tw as Tween).is_valid():
			(tw as Tween).kill()
	for c: Callable in _clean:
		if c.is_valid():
			c.call()
	for p in [a, b]:
		if p != null and is_instance_valid(p):
			for sd in ["l", "r"]:
				p.release(sd, 0.4, _owner)
			if p.body:
				var sv: Array = _saved.get(p, [Vector3.ZERO, Vector3.ZERO])
				p.body.chest_add = sv[0]
				p.body.head_add = sv[1]
				p.body.micro_chest = Vector3.ZERO
			p.layers.release(_owner)
	finished.emit(p_ok)


# --- Bausteine -------------------------------------------------------------------------------------------------

func _phase(p_name: String, dur: float, enter := Callable(), tk := Callable(), until := Callable()) -> Dictionary:
	return {"name": p_name, "dur": dur, "enter": enter, "tick": tk, "until": until}


func _move(p: LumosActor, pos: Vector3, secs: float) -> void:
	if not bool(opts.get("move", true)):
		return
	var tw := p.create_tween()
	tw.tween_property(p.rig, "global_position", pos, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.append(tw)


func _face_each_other() -> void:
	if b == null:
		return
	a.rig.turn_to(_n, 0.22)
	b.rig.turn_to(-_n, 0.22)
	a.look_at_target(b)
	b.look_at_target(a)
	_clean.append(func() -> void:
		if is_instance_valid(a) and a.look_target() == b:
			a.look_at_target(null)
		if is_instance_valid(b) and b.look_target() == a:
			b.look_at_target(null))


func _reach(p: LumosActor, sd: String, target: Variant, secs: float, orient: Variant = null, assist := 1.0) -> void:
	p.reach(sd, target, secs, orient, assist, _owner)


func _two(p: LumosActor) -> bool:
	return p != null and p.body != null and p.body.arm_mode() == "2bone"


## Versetzt beide so, dass der gegebene Abstand entsteht (Mitte bleibt), optional seitlich versetzt.
func _approach_to(want: float, lateral := 0.0, secs := 0.3) -> void:
	var pa := a.rig.global_position
	var pb := b.rig.global_position
	var mid := (pa + pb) * 0.5
	_move(a, Vector3(mid.x, pa.y, mid.z) - _n * want * 0.5 - _rt * lateral, secs)
	_move(b, Vector3(mid.x, pb.y, mid.z) + _n * want * 0.5 + _rt * lateral, secs)


func _laugh(p: LumosActor, secs: float, strength: float) -> void:
	if is_instance_valid(p):
		p.laugh(secs, strength)


# --- Arten ------------------------------------------------------------------------------------------------------

func _build() -> Array:
	match kind:
		"high_five":
			return _b_high_five()
		"handshake":
			return _b_handshake()
		"hug":
			return _b_hug()
		"pat", "comfort":
			return _b_pat(kind == "comfort")
		"take_hand":
			return _b_take_hand()
		"give":
			return _b_give()
		"tease":
			return _b_tease()
		"cheer_together":
			return _b_cheer()
		"dance_together":
			return _b_dance()
		"playful_shove":
			return _b_shove()
		"scare":
			return _b_scare()
		"shared_laugh":
			return _b_shared_laugh()
	return []


## Körper-Variante für Figuren ohne zweiteilige Arme: aufeinander zu, Stups mit Körper-Reaktion, lachen.
func _b_simple(contact_kind: String) -> Array:
	return [
		_phase("approach", 0.25, _face_each_other),
		_phase("contact", 0.2, func() -> void:
			a.nudge(-_n * 1.4)
			b.nudge(_n * 1.4)
			a.interact.contact.emit(contact_kind, b)
			b.interact.contact.emit(contact_kind, a)),
		_phase("response", 0.5, func() -> void:
			_laugh(a, 1.0, 0.8)
			_laugh(b, 1.0, 0.8)),
	]


## Rechte Schultern einander gegenüber (die großen Köpfe bleiben seitlich versetzt), Abstand aus der Reichweite.
## Der Treffpunkt hängt an den Ruhepositionen der Schultern – nicht an der gebeugten Pose, sonst würde das Lehnen
## zum Ziel das Ziel verschieben (Rückkopplung, Zittern).
func _pair_geometry(h_up: float) -> Dictionary:
	var geo := func(me: LumosActor) -> Vector2:
		var o := me.body.rest_pos("shoulder.r") - me.rig.global_position
		return Vector2(o.dot(me.rig.global_basis.x.normalized()), o.dot(me.forward()))
	var ga: Vector2 = geo.call(a)
	var gb: Vector2 = geo.call(b)
	var x := (ga.x + gb.x) * 0.5
	var h := h_up * (a.body.reach_length() + b.body.reach_length()) * 0.5
	var horiz := func(me: LumosActor) -> float:
		var r := me.body.reach_length() * 0.93
		var v := absf(h) - me.body.wrist_offset("r")
		return sqrt(maxf(r * r - v * v, 0.01))
	return {"want": ga.y + gb.y + float(horiz.call(a)) + float(horiz.call(b)) + 0.05, "x": x, "h": h}


func _b_high_five() -> Array:
	if not (_two(a) and _two(b)):
		return _b_simple("high_five")
	var g := _pair_geometry(0.32)
	var gap := 0.025
	var meet := func() -> Vector3:
		return (a.body.rest_pos("shoulder.r") + b.body.rest_pos("shoulder.r")) * 0.5 + Vector3.UP * float(g.h)
	return [
		_phase("approach", 0.3, func() -> void:
			_face_each_other()
			a.feel("grin", 0.2)
			b.feel("grin", 0.2)
			a.rig.anticipate(0.22, 0.06)
			b.rig.anticipate(0.22, 0.06)
			_approach_to(float(g.want), float(g.x), 0.3)),
		_phase("contact", 0.25, func() -> void:
			for me: LumosActor in [a, b]:
				me.body.chest_add = Vector3(0.06, -0.12, 0)
				me.body.head_add = Vector3(0, 0, -0.12)
			_reach(a, "r", func() -> Vector3: return (meet.call() as Vector3) - _n * gap, 0.22, func() -> Array: return [Vector3.UP, _n])
			_reach(b, "r", func() -> Vector3: return (meet.call() as Vector3) + _n * gap, 0.22, func() -> Array: return [Vector3.UP, -_n])),
		_phase("main", 0.16, func() -> void:
			Audio.sfx("pop", meet.call(), -3.0, 1.2)
			a.nudge(-_n * 1.8)
			b.nudge(_n * 1.8)
			a.rig.squash(1.06, 0.95, 0.25)
			b.rig.squash(1.06, 0.95, 0.25)
			a.interact.contact.emit("high_five", b)
			b.interact.contact.emit("high_five", a)),
		_phase("response", 0.22, func() -> void:
			a.release("r", 0.45, _owner)
			b.release("r", 0.45, _owner)
			for me2: LumosActor in [a, b]:
				me2.body.chest_add = Vector3.ZERO
				me2.body.head_add = Vector3.ZERO
			_laugh(a, 1.2, 0.8)),
		_phase("after", 0.3, func() -> void: _laugh(b, 1.2, 0.9)),
	]


## Handschlag: rechte Hände auf Hüfthöhe, Handflächen senkrecht zueinander, Daumen oben; dreimal schütteln,
## beide Körper wippen mit, danach Nicken und Lächeln.
func _b_handshake() -> Array:
	if not (_two(a) and _two(b)):
		return _b_simple("handshake")
	var g := _pair_geometry(-0.38)
	var pump := [0.0]
	var meet := func() -> Vector3:
		return (a.body.rest_pos("shoulder.r") + b.body.rest_pos("shoulder.r")) * 0.5 + Vector3.UP * (float(g.h) + float(pump[0]))
	return [
		_phase("approach", 0.45, func() -> void:
			_face_each_other()
			a.feel("smile", 0.3)
			b.feel("smile", 0.3)
			if a.face:
				a.face.flash_brows(0.6)
			_approach_to(float(g.want) * 0.92, float(g.x), 0.45)),
		_phase("contact", 0.3, func() -> void:
			_reach(a, "r", func() -> Vector3: return (meet.call() as Vector3) - _rt * 0.025, 0.28, func() -> Array: return [_n, -_rt])
			_reach(b, "r", func() -> Vector3: return (meet.call() as Vector3) + _rt * 0.025, 0.28, func() -> Array: return [-_n, _rt])),
		_phase("main", float(opts.get("secs", 1.1)), func() -> void:
			a.interact.contact.emit("handshake", b)
			b.interact.contact.emit("handshake", a),
			func(pt: float, _d: float) -> void:
				pump[0] = sin(pt * TAU * 2.4) * 0.045 * (1.0 - smoothstep(0.7, 1.0, pt / float(opts.get("secs", 1.1))))
				if is_instance_valid(a.body):
					a.body.micro_chest = Vector3(float(pump[0]) * 0.6, 0, 0)
				if is_instance_valid(b.body):
					b.body.micro_chest = Vector3(float(pump[0]) * 0.6, 0, 0)),
		_phase("response", 0.35, func() -> void:
			a.release("r", 0.4, _owner)
			b.release("r", 0.4, _owner)
			a.body.micro_chest = Vector3.ZERO
			b.body.micro_chest = Vector3.ZERO
			a.micro.play("nod", {"prio": LumosLayers.P_SOCIAL, "owner": _owner + ":nod"})
			b.micro.play("nod", {"prio": LumosLayers.P_SOCIAL, "owner": _owner + ":nod"})
			a.emotion.trigger("content", 0.6, 1.5)
			b.emotion.trigger("content", 0.6, 1.5)),
	]


## Umarmung: annähern (Köpfe seitlich versetzt), Arme um die Schultern, drücken (beide wiegen sich), lösen, zurücktreten.
func _b_hug() -> Array:
	if not (_two(a) and _two(b)):
		return _b_simple("hug")
	var hold := float(opts.get("secs", 1.2))
	var ra := a.head_radius()
	var rb := b.head_radius()
	var pa0 := a.rig.global_position
	var pb0 := b.rig.global_position
	var arms := func() -> void:
		for pair in [[a, b, 1.0], [b, a, -1.0]]:
			var me: LumosActor = pair[0]
			var other: LumosActor = pair[1]
			for hand in ["l", "r"]:
				var opp := "r" if hand == "l" else "l"
				_reach(me, hand, func() -> Vector3: return other.body.joint_pos("shoulder." + opp) - other.forward() * 0.14 + Vector3(0, -0.04, 0), 0.32,
					func() -> Array: return [(other.rig.global_position - me.rig.global_position).normalized().cross(Vector3.UP) * (-1.0 if hand == "r" else 1.0), other.forward()],
					0.2)
			me.body.head_add = Vector3(0.1, 0.25 * float(pair[2]), 0.25 * float(pair[2]))
			me.body.chest_add = Vector3(0.16, 0, 0)
	return [
		_phase("approach", 0.4, func() -> void:
			_face_each_other()
			a.feel("affection", 0.3)
			b.feel("affection", 0.3)
			_approach_to((ra + rb) * 0.72, 0.1, 0.4)),   # seitlich versetzt: die großen Köpfe gehen aneinander vorbei
		_phase("contact", 0.34, arms),
		_phase("main", hold, func() -> void:
			a.nudge(_n * 1.2)
			b.nudge(-_n * 1.2)
			a.interact.contact.emit("hug", b)
			b.interact.contact.emit("hug", a),
			func(pt: float, _d: float) -> void:   # beide wiegen sich leicht
				var sw := sin(pt * TAU * 0.8) * 0.05
				a.body.micro_chest = Vector3(0, 0, sw)
				b.body.micro_chest = Vector3(0, 0, -sw)),
		_phase("response", 0.3, func() -> void:
			for me2: LumosActor in [a, b]:
				for hand2 in ["l", "r"]:
					me2.release(hand2, 0.4, _owner)
				me2.body.head_add = Vector3.ZERO
				me2.body.chest_add = Vector3.ZERO
				me2.body.micro_chest = Vector3.ZERO
			a.feel("content", 0.5)
			b.feel("content", 0.5)),
		_phase("after", 0.5, func() -> void:
			if bool(opts.get("step_back", true)):   # zurück an den Ausgangspunkt
				_move(a, pa0, 0.5)
				_move(b, pb0, 0.5)),
	]


## Schulterklopfen (pat) oder Trösten (comfort): Hand mit der Handfläche auf die Schulter, die Schulter gibt bei
## jedem Klopfer nach. Beim Trösten tritt a neben b, das Gefühl von b wandelt sich von Traurigkeit zu Erleichterung.
func _b_pat(comfort: bool) -> Array:
	if not _two(a):
		return _b_simple("comfort" if comfort else "pat")
	var count := int(opts.get("count", 4 if comfort else 3))
	var hand := String(opts.get("hand", "r"))
	var near := func() -> Vector3:
		var l := b.body.joint_pos("shoulder.l") if b.body else b.rig.global_position + Vector3.UP
		var r := b.body.joint_pos("shoulder.r") if b.body else l
		var p := a.rig.global_position
		return l if l.distance_to(p) < r.distance_to(p) else r
	var dip := [0.0]
	var per := 0.5 if comfort else 0.32   # Trösten: ruhiger Takt · Schulterklopfen: munter
	var main_secs := per * count + 0.2
	return [
		_phase("approach", 0.5 if comfort else 0.2, func() -> void:
			a.look_at_target(b)
			if comfort:
				a.feel("compassion", 0.4)
				var side := b.rig.global_position + b.right() * (a.head_radius() + b.head_radius()) * 0.85
				_move(a, Vector3(side.x, a.rig.global_position.y, side.z), 0.5)
				var tw := a.create_tween()
				tw.tween_interval(0.25)
				tw.tween_callback(func() -> void: a.rig.turn_to(b.rig.global_position - side, 0.25))
				_tw.append(tw)
			else:
				a.rig.turn_to(b.rig.global_position - a.rig.global_position, 0.2)
			_clean.append(func() -> void:
				if is_instance_valid(a):
					a.look_at_target(null))),
		_phase("contact", 0.22, func() -> void:
			_reach(a, hand, func() -> Vector3: return (near.call() as Vector3) + Vector3.UP * (0.07 + float(dip[0])), 0.22,
				func() -> Array: return [(b.rig.global_position - a.rig.global_position).normalized(), Vector3.DOWN], 0.5)
			a.body.head_add = Vector3(0.06, 0.0, 0.14 if comfort else 0.0)),
		_phase("main", main_secs, func() -> void:
			a.interact.contact.emit("comfort" if comfort else "pat", b)
			if comfort:
				b.look_at_target(a),
			func(pt: float, _d: float) -> void:
				var ph := fmod(pt, per) / per
				var prev := float(dip[0])
				dip[0] = -sin(ph * PI) * 0.05
				if prev > -0.045 and float(dip[0]) <= -0.045 and b.body:   # Tiefpunkt: die Schulter gibt nach
					b.nudge((b.rig.global_position - a.rig.global_position).normalized() * 1.1 + Vector3.DOWN * 1.0)
				if comfort and pt > main_secs * 0.5 and b.emotion and b.emotion.intensity_of("relief") < 0.05:
					b.emotion.clear("cry")
					b.emotion.clear("sad")
					b.emotion.trigger("relief", 0.8, 1.6)),
		_phase("response", 0.4, func() -> void:
			a.release(hand, 0.4, _owner)
			a.body.head_add = Vector3.ZERO
			if comfort:
				b.emotion.trigger("tender", 0.7, 1.8, -1.0, -1.0, a)
				a.emotion.trigger("smile", 0.7, 1.2)
			else:
				b.emotion.trigger("smile", 0.7, 1.2)),
	]


## An die Hand nehmen: Handflächen zueinander zwischen beiden; hält opts.secs (Standard 2 s).
func _b_take_hand() -> Array:
	if not (_two(a) and _two(b)):
		return _b_simple("take_hand")
	var mid := func() -> Vector3:
		return (a.body.rest_pos("shoulder.l") + b.body.rest_pos("shoulder.r")) * 0.5 + Vector3.DOWN * 0.22
	var d_ba := func() -> Vector3:
		var d := a.rig.global_position - b.rig.global_position
		d.y = 0.0
		return d.normalized()
	return [
		_phase("approach", 0.2, func() -> void:
			a.look_at_target(b)
			b.look_at_target(a)
			a.feel("smile", 0.3)),
		_phase("contact", 0.32, func() -> void:
			_reach(a, "l", func() -> Vector3: return (mid.call() as Vector3) + (d_ba.call() as Vector3) * 0.03, 0.3,
				func() -> Array: return [(a.forward() * 0.5 + Vector3.DOWN).normalized(), -(d_ba.call() as Vector3)])
			_reach(b, "r", func() -> Vector3: return (mid.call() as Vector3) - (d_ba.call() as Vector3) * 0.03, 0.34,
				func() -> Array: return [(b.forward() * 0.5 + Vector3.DOWN).normalized(), d_ba.call()])),
		_phase("main", float(opts.get("secs", 2.0)), func() -> void:
			a.interact.contact.emit("take_hand", b)
			b.nudge((d_ba.call() as Vector3) * 1.6)),
	]


## Übergabe: Gegenstand aus a.interact.held[hand] – beide Hände treffen sich (Handflächen oben), Besitzwechsel.
func _b_give() -> Array:
	var hand := String(opts.get("hand", "r"))
	var to_hand := String(opts.get("to_hand", "l"))
	var obj: Node3D = a.interact.held.get(hand)
	if obj == null or not (_two(a) and _two(b)):
		return []
	var mid := func() -> Vector3:
		return (a.body.rest_pos("shoulder." + hand) + b.body.rest_pos("shoulder." + to_hand)) * 0.5 + Vector3(0, -0.12, 0)
	return [
		_phase("approach", 0.2, func() -> void:
			a.look_at_target(b)
			b.look_at_target(obj)
			b.emotion.trigger("curious", 0.5, 0.8)),
		_phase("contact", 0.5, func() -> void:
			_reach(a, hand, mid, 0.4, func() -> Array: return [a.forward(), Vector3.UP])
			_reach(b, to_hand, func() -> Vector3: return (mid.call() as Vector3) + Vector3(0, -0.06, 0), 0.45, func() -> Array: return [b.forward(), Vector3.UP])),
		_phase("main", 0.15, func() -> void:
			a.interact.held[hand] = null
			b.interact.held[to_hand] = obj
			a.interact.released.emit(obj, hand)
			b.interact.grabbed.emit(obj, to_hand)
			a.interact.contact.emit("give", b)),
		_phase("response", 0.4, func() -> void:
			a.release(hand, 0.4, _owner)
			b.reach(to_hand, func() -> Vector3: return b.interact.carry_point(to_hand), 0.4, func() -> Array: return [b.forward(), Vector3.UP])
			b.look_at_target(a)
			b.emotion.trigger("joy", 0.7, 1.2, -1.0, -1.0, a)
			a.emotion.trigger("smile", 0.6, 1.0)),
	]


## Necken: nah heran, mit dem Finger in die Wange/Schulter stupsen; das Gegenüber reagiert je nach Humor
## (mitlachen oder erst gespielt beleidigt mit Backen aufblasen, dann lachen).
func _b_tease() -> Array:
	if not _two(a):
		return _b_simple("tease")
	var poke := [0.0]
	var cheek := func() -> Vector3:
		var hd := b.body.joint_pos("head") if b.body else b.rig.global_position + Vector3.UP * 1.5
		return hd + Vector3.UP * b.head_radius() * 0.25 - _n * b.head_radius() * (0.85 + float(poke[0]))
	var humor := b.personality.humor
	return [
		_phase("approach", 0.35, func() -> void:
			_face_each_other()
			a.feel("teasing", 0.25)
			_approach_to((a.head_radius() + b.head_radius()) * 1.05, 0.12, 0.35)),
		_phase("contact", 0.3, func() -> void:
			_reach(a, "r", cheek, 0.25, func() -> Array: return [_n, Vector3.DOWN])),
		_phase("main", 0.7, func() -> void:
			a.interact.contact.emit("tease", b)
			b.nudge(_n * 0.8)
			if a.face:
				a.face.mouth_action("snicker"),
			func(pt: float, _d: float) -> void: poke[0] = -absf(sin(pt * TAU * 2.1)) * 0.06),
		_phase("response", 0.9, func() -> void:
			a.release("r", 0.35, _owner)
			if humor > 0.55:
				_laugh(b, 1.2, 0.8)
			else:
				b.feel("puffed", 0.15)
				var tw := b.create_tween()
				tw.tween_interval(0.6)
				tw.tween_callback(func() -> void:
					b.feel("neutral", 0.3)
					_laugh(b, 1.0, 0.6))
				_tw.append(tw)
			_laugh(a, 1.1, 0.7)),
	]


## Gemeinsam jubeln: zueinander drehen, Arme hoch, zweimal im Gleichtakt hüpfen.
func _b_cheer() -> Array:
	return [
		_phase("approach", 0.25, func() -> void:
			_face_each_other()
			a.emotion.trigger("delight", 0.9, 1.6)
			b.emotion.trigger("delight", 0.9, 1.6)),
		_phase("main", 1.1, func() -> void:
			for me: LumosActor in [a, b]:
				me.micro.play("cheer", {"prio": LumosLayers.P_INTERACT + 1, "owner": _owner + ":cheer", "dur": 1.1})
			a.interact.contact.emit("cheer", b),
			func(pt: float, d: float) -> void:
				for k in 2:
					var th := 0.1 + k * 0.48
					if pt - d < th and pt >= th:
						for me2: LumosActor in [a, b]:
							me2.rig.hop(0.35, 0.36)
							var tw := me2.create_tween()
							tw.tween_interval(0.36)
							tw.tween_callback(func() -> void:
								if is_instance_valid(me2) and me2.body:
									me2.body.land(0.6))
							_tw.append(tw)),
		_phase("after", 0.4, func() -> void:
			a.micro.stop()
			b.micro.stop()),
	]


## Gemeinsam tanzen: beide spielen den Tanz-Clip (oder Jubeln) zueinander gewandt, freuen sich, Kopf wippt.
func _b_dance() -> Array:
	var secs := float(opts.get("secs", 2.6))
	return [
		_phase("approach", 0.3, func() -> void:
			_face_each_other()
			a.emotion.trigger("joy", 0.9, secs)
			b.emotion.trigger("joy", 0.9, secs)),
		_phase("main", secs, func() -> void:
			for me: LumosActor in [a, b]:
				var c := "dance" if me.rig.has_clip("dance") else "cheer"
				me.rig.play(c, 0.3, 1.0, true)
				me.rig.lock(secs)
			a.social.emit("dance", a, {}),
			func(pt: float, _d: float) -> void:
				for me2: LumosActor in [a, b]:
					if me2.body:
						me2.body.micro_head = Vector3(absf(sin(pt * TAU * 2.0)) * 0.08, 0, sin(pt * TAU) * 0.08)),
		_phase("after", 0.3, func() -> void:
			for me3: LumosActor in [a, b]:
				me3.rig.unlock()
				me3.rig.play("idle", 0.4)),
	]


## Spielerisch schubsen: ausholen, Handflächen an die Brust, b taumelt einen Schritt (Ausfallschritt, Arme rudern),
## beide lachen.
func _b_shove() -> Array:
	if not _two(a):
		return _b_simple("shove")
	var strength := float(opts.get("strength", 0.7))
	var chest := func(sd: String) -> Vector3:
		var c := b.body.joint_pos("chest") if b.body else b.rig.global_position + Vector3.UP
		return c - _n * b.head_radius() * 0.55 + _rt * (0.12 if sd == "r" else -0.12)
	return [
		_phase("approach", 0.3, func() -> void:
			_face_each_other()
			a.feel("playful", 0.2)
			a.rig.anticipate(0.25, 0.08)
			_approach_to((a.head_radius() + b.head_radius()) * 1.0, 0.0, 0.3)),
		_phase("contact", 0.16, func() -> void:
			for sd in ["l", "r"]:
				_reach(a, sd, chest.bind(sd), 0.14, func() -> Array: return [Vector3.UP, _n])),
		_phase("main", 0.3, func() -> void:
			a.interact.contact.emit("shove", b)
			b.react_hit(-_n, 0.6 * strength, false)
			if b.body:
				b.body.stumble(_n, strength)
			_move(b, b.rig.global_position + _n * 0.45 * strength, 0.35)),
		_phase("response", 0.6, func() -> void:
			for sd2 in ["l", "r"]:
				a.release(sd2, 0.35, _owner)
			b.emotion.trigger("surprise", 0.6, 0.4)
			_laugh(a, 1.0, 0.7)
			var tw := b.create_tween()
			tw.tween_interval(0.45)
			tw.tween_callback(_laugh.bind(b, 1.1, 0.8))
			_tw.append(tw)),
	]


## Erschrecken: a schleicht sich hinter b, reißt die Arme hoch – „Buh!“ –, b springt erschrocken weg (Cartoon),
## dann lachen beide.
func _b_scare() -> Array:
	var behind := b.rig.global_position - b.forward() * (a.head_radius() + b.head_radius()) * 1.0
	return [
		_phase("approach", float(opts.get("sneak", 0.6)), func() -> void:
			a.feel("teasing", 0.3)
			a.look_at_target(b)
			_move(a, Vector3(behind.x, a.rig.global_position.y, behind.z), float(opts.get("sneak", 0.6)))
			a.rig.turn_to(b.rig.global_position - behind, 0.3)),
		_phase("main", 0.35, func() -> void:
			a.micro.play("arms_up", {"prio": LumosLayers.P_INTERACT + 1, "owner": _owner + ":boo", "dur": 0.7})
			a.feel("delight", 0.1)
			a.social.emit("boo", a, {"target": b, "source": a.rig.global_position + Vector3.UP})
			Audio.sfx("whoosh", a.rig.global_position, -6.0, 1.3)
			LumosCartoon.react(b, "jump_back", 0.9, {"from": a.rig.global_position, "force": true})),
		_phase("response", 1.2, func() -> void:
			var tw := b.create_tween()
			tw.tween_interval(0.7)
			tw.tween_callback(func() -> void:
				b.emotion.trigger("relief", 0.7, 0.6)
				_laugh(b, 1.2, 0.8))
			_tw.append(tw)
			_laugh(a, 1.4, 1.0)),
	]


## Gemeinsam lachen: Blickkontakt, beide lachen versetzt, a legt b die Hand auf die Schulter, beide lehnen sich zu.
func _b_shared_laugh() -> Array:
	var near := func() -> Vector3:
		if b.body == null:
			return b.rig.global_position + Vector3.UP
		var l := b.body.joint_pos("shoulder.l")
		var r := b.body.joint_pos("shoulder.r")
		return (l if l.distance_to(a.rig.global_position) < r.distance_to(a.rig.global_position) else r) + Vector3.UP * 0.06
	return [
		_phase("approach", 0.3, _face_each_other),
		_phase("main", float(opts.get("secs", 1.6)), func() -> void:
			_laugh(a, float(opts.get("secs", 1.6)) + 0.3, 1.0)
			var tw := b.create_tween()
			tw.tween_interval(0.25)
			tw.tween_callback(_laugh.bind(b, float(opts.get("secs", 1.6)), 0.9))
			_tw.append(tw)
			if _two(a):
				_reach(a, "r", near, 0.35, func() -> Array: return [(b.rig.global_position - a.rig.global_position).normalized(), Vector3.DOWN], 0.4)
			a.interact.contact.emit("shared_laugh", b)),
	]
