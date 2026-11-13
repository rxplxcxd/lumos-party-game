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
	"dance_together", "playful_shove", "scare", "shared_laugh", "help_up"]

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
	var ch := ["root", "legs", "torso", "head", "eyes", "arm.l", "arm.r"]
	var helping := p_kind == "help_up"
	if helping and (p_b == null or not p_b.fallen or p_b.is_rising()):
		return null
	if not p_a.layers.claim(it._owner, ch, LumosLayers.P_INTERACT, it.cancel):
		return null
	if helping:   # das Aufhelfen übernimmt die Figur am Boden (ihr Sitzen gibt die Kanäle ab)
		p_b.layers.release("fall")
	if p_b and not p_b.layers.claim(it._owner, ch, LumosLayers.P_INTERACT, it.cancel):
		p_a.layers.release(it._owner)
		if helping:
			p_b.reclaim_fall()
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
		if done:   # die Phase hat die Interaktion beendet (Abbruch, Verdrängung)
			return
	var dur := float(ph.get("dur", 0.3))
	var until: Callable = ph.get("until", Callable())
	if _pt >= dur and (not until.is_valid() or bool(until.call()) or _pt >= dur * 2.5 + 0.5):
		_next()


func cancel() -> void:
	if not done:
		_finish(false)


func _next() -> void:
	if done:
		return
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
	if kind == "help_up" and is_instance_valid(b):
		b.reclaim_fall()   # abgebrochen, bevor sie stand: sie sitzt weiter (und steht später allein auf)
	# Phasen, Aufräum- und Tween-Rückrufe halten die Interaktion selbst fest (Lambdas) – Kreis lösen, sonst bleibt
	# jede beendete Interaktion samt Rückrufen im Speicher
	_plan.clear()
	_clean.clear()
	_tw.clear()
	_saved.clear()
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


## Standplatz für a bei b: Kandidaten im Kreis um b (Winkel in Grad zu b.forward(), Abstände in m), a schaut jeweils
## zu b. Gültig nur, wo die festen Körperteile mindestens margin Luft haben (in der aktuellen Haltung, z. B. sitzend);
## gewählt wird der Platz, von dem aus a's Hand (Schulter → target(schulter)) am besten reicht, dann der kürzeste Weg.
func _solve_spot(hand: String, target: Callable, angles: Array, dists: Array, margin: float) -> Vector3:
	var a_loc := a.local_volumes()
	var b_w := b.volumes()
	var sh_loc := a.rig.global_transform.affine_inverse() * a.body.rest_pos("shoulder." + hand)
	var ra := a.body.reach_length()
	var best := a.rig.global_position
	var best_s := INF
	var roomy := a.rig.global_position   # falls nichts ganz frei ist: der Platz mit der meisten Luft
	var roomy_c := -INF
	for ang: float in angles:
		var dir := b.forward().rotated(Vector3.UP, deg_to_rad(ang))
		for dd: float in dists:
			var p := b.rig.global_position + dir * dd
			var xf := LumosActor.root_xf(a, p, -dir)
			var cl := LumosActor.clear_of(LumosActor.place_volumes(a_loc, xf), b_w)
			if cl > roomy_c:
				roomy_c = cl
				roomy = Vector3(p.x, a.rig.global_position.y, p.z)
			if cl < margin:
				continue
			var sh := xf * sh_loc
			var c: Vector3 = target.call(sh)
			var score := maxf(sh.distance_to(c) - ra * 0.93, 0.0) * 10.0 + p.distance_to(a.rig.global_position) * 0.3   # kurzer Weg zählt
			if score < best_s:
				best_s = score
				best = Vector3(p.x, a.rig.global_position.y, p.z)
	return best if best_s < INF else roomy


## Weg von p zu spot, der nicht durch around hindurchführt: schneidet die Gerade den Kreis mit radius um around,
## geht der Weg in einem Bogen außen herum (Wegpunkte alle 30°, kürzere Richtung).
func _path_around(p: LumosActor, spot: Vector3, around: LumosActor, radius: float) -> Array[Vector3]:
	var c := around.rig.global_position
	var s0 := p.rig.global_position
	var seg := spot - s0
	seg.y = 0.0
	var pts: Array[Vector3] = []
	var t := clampf((c - s0).dot(seg) / maxf(seg.length_squared(), 0.0001), 0.0, 1.0)
	var closest := s0 + seg * t
	if Vector2(closest.x - c.x, closest.z - c.z).length() < radius and seg.length() > 0.2:
		var v0 := Vector3(s0.x - c.x, 0.0, s0.z - c.z)
		var v1 := Vector3(spot.x - c.x, 0.0, spot.z - c.z)
		var a0 := Vector3.BACK.signed_angle_to(v0.normalized(), Vector3.UP)
		var da := wrapf(Vector3.BACK.signed_angle_to(v1.normalized(), Vector3.UP) - a0, -PI, PI)
		var steps := maxi(1, int(ceil(absf(da) / deg_to_rad(30.0))))
		for k in range(1, steps):
			var r := lerpf(maxf(v0.length(), radius), maxf(v1.length(), radius), float(k) / steps)
			var w := c + Vector3.BACK.rotated(Vector3.UP, a0 + da * k / steps) * r
			pts.append(Vector3(w.x, s0.y, w.z))
	pts.append(spot)
	return pts


## Trostplatz neben b mit gleicher Blickrichtung (Arm um den Freund): die Schultern zeigen zueinander, die zugewandte
## Hand erreicht b's nahen Oberarm, die Köpfe neigen sich auseinander. Liefert {pos, hand}.
func _solve_beside(target: Callable, dists: Array, margin: float) -> Dictionary:
	var a_loc := a.local_volumes()
	var b_w := b.volumes()
	var f := b.forward()
	var best := {"pos": a.rig.global_position, "hand": "r"}
	var best_s := INF
	var roomy := best
	var roomy_c := -INF
	for ang: float in [90.0, -90.0, 75.0, -75.0, 105.0, -105.0]:
		var dir := f.rotated(Vector3.UP, deg_to_rad(ang))
		for dd: float in dists:
			var p := b.rig.global_position + dir * dd
			var xf := LumosActor.root_xf(a, p, f)
			var cl := LumosActor.clear_of(LumosActor.place_volumes(a_loc, xf), b_w)
			var right_w := xf.basis.x.normalized() * (1.0 if a.right().dot(a.rig.global_basis.x) >= 0.0 else -1.0)
			var hand := "r" if (b.rig.global_position - p).dot(right_w) > 0.0 else "l"
			var cand := {"pos": Vector3(p.x, a.rig.global_position.y, p.z), "hand": hand}
			if cl > roomy_c:
				roomy_c = cl
				roomy = cand
			if cl < margin:
				continue
			var sh := xf * (a.rig.global_transform.affine_inverse() * a.body.rest_pos("shoulder." + hand))
			var c: Vector3 = target.call(sh)
			var score := maxf(sh.distance_to(c) - a.body.reach_length() * 0.93, 0.0) * 10.0 + p.distance_to(a.rig.global_position) * 0.3
			if score < best_s:
				best_s = score
				best = cand
	return best if best_s < INF else roomy


## Phasen-Takt fürs Hingehen mit echten Schritten (Lokomotion, Fußanker) über Wegpunkte; der letzte ist das Ziel.
func _walk_tick(p: LumosActor, path: Array[Vector3]) -> Callable:
	var i := [0]
	return func(_pt: float, d: float) -> void:
		var goal: Vector3 = path[mini(int(i[0]), path.size() - 1)]
		var to := goal - p.rig.global_position
		to.y = 0.0
		var dist := to.length()
		var last := int(i[0]) >= path.size() - 1
		if not last and dist < 0.15:
			i[0] = int(i[0]) + 1
		p.move(to.normalized() * (clampf(dist * 2.4, 0.0, 1.15) if last else 1.1) if dist > 0.03 else Vector3.ZERO, true, d)


func _arrived(p: LumosActor, spot: Vector3) -> Callable:
	return func() -> bool:
		var to := spot - p.rig.global_position
		to.y = 0.0
		return to.length() < 0.07 and p.speed() < 0.25


## Versetzt beide so, dass der gegebene Abstand entsteht (Mitte bleibt), optional seitlich versetzt.
func _approach_to(want: float, lateral := 0.0, secs := 0.3, overlap := 0.0) -> void:
	# nie näher, als die festen Körperteile erlauben (Köpfe mit Helm/Kapuze, Rümpfe); overlap > 0 erlaubt bewusst so
	# viel Nähe, wie das Ausweichen von Kopf und Oberkörper auflöst (Wange an Wange beim Umarmen)
	want = maxf(want, LumosActor.fit_distance(a, b, _n, _n, -_n, LumosActor.AVOID_MARGIN - overlap, _rt * lateral * 2.0, true))
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
		"help_up":
			return _b_help_up()
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
			_approach_to(float(g.want), float(g.x), 0.3, 0.08)),   # nah genug für die kurzen Arme; die Köpfe weichen dabei aus
		_phase("contact", 0.25, func() -> void:
			for me: LumosActor in [a, b]:
				me.body.chest_add = Vector3(0.06, -0.12, 0)
				me.body.head_add = Vector3(0, 0, -0.12)
			_reach(a, "r", func() -> Vector3: return (meet.call() as Vector3) - _n * gap, 0.22, func() -> Array: return [Vector3.UP, _n], 0.8)
			_reach(b, "r", func() -> Vector3: return (meet.call() as Vector3) + _n * gap, 0.22, func() -> Array: return [Vector3.UP, -_n], 0.8)),
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
	# Seitumarmung: bei Chibi-Proportionen (Arm kürzer als der Kopfradius) stecken die Köpfe bei einer Umarmung von vorn
	# ineinander. Beide drehen sich darum in eine gemeinsame Blickrichtung, stehen Schulter an Schulter, legen den
	# inneren Arm um die Schulter des anderen; die Köpfe gehen Wange an Wange (das Ausweichen hält sie gerade frei).
	if not (_two(a) and _two(b)):
		return _b_simple("hug")
	var hold := float(opts.get("secs", 1.2))
	var pa0 := a.rig.global_position
	var pb0 := b.rig.global_position
	var f := _n.cross(Vector3.UP)   # gemeinsame Blickrichtung: quer zur Verbindung, näher an der bisherigen
	if f.dot(a.forward() + b.forward()) < 0.0:
		f = -f
	var right_f := f.cross(Vector3.UP)
	var ha := "r" if _n.dot(right_f) > 0.0 else "l"     # innere Hände
	var hb := "r" if (-_n).dot(right_f) > 0.0 else "l"
	var lat := maxf(LumosActor.fit_distance(a, b, _n, f, f, LumosActor.AVOID_MARGIN - 0.15, Vector3.ZERO, true), 0.62)
	var mid := (pa0 + pb0) * 0.5
	var spot_a := Vector3(mid.x, pa0.y, mid.z) - _n * lat * 0.5
	var spot_b := Vector3(mid.x, pb0.y, mid.z) + _n * lat * 0.5
	var around := func(me: LumosActor, other: LumosActor, dir: Vector3) -> Vector3:   # nahe Schulter, ein wenig dahinter
		var sd := "l" if other.body.joint_pos("shoulder.l").distance_to(me.rig.global_position) < other.body.joint_pos("shoulder.r").distance_to(me.rig.global_position) else "r"
		return other.body.joint_pos("shoulder." + sd) - f * 0.08 + Vector3.UP * 0.04 + dir * 0.02
	return [
		_phase("approach", 0.45, func() -> void:
			a.rig.turn_to(f, 0.3)
			b.rig.turn_to(f, 0.3)
			a.look_at_target(null)   # Wange an Wange: beide schauen nach vorn (vorstehende Kopfteile zeigen nicht zum anderen)
			b.look_at_target(null)
			a.emotion.trigger("affection", 0.8, 2.4)
			b.emotion.trigger("affection", 0.8, 2.4)
			_move(a, spot_a, 0.45)
			_move(b, spot_b, 0.45)
			_clean.append(func() -> void:
				if is_instance_valid(a) and a.look_target() == b:
					a.look_at_target(null)
				if is_instance_valid(b) and b.look_target() == a:
					b.look_at_target(null))),
		_phase("contact", 0.34, func() -> void:
			_reach(a, ha, around.bind(a, b, _n), 0.32, func() -> Array: return [_n, Vector3.DOWN], 0.2)
			_reach(b, hb, around.bind(b, a, -_n), 0.32, func() -> Array: return [-_n, Vector3.DOWN], 0.2)
			for pr in [[a, 1.0 if ha == "r" else -1.0], [b, 1.0 if hb == "r" else -1.0]]:   # zueinander neigen
				var me: LumosActor = pr[0]
				me.body.chest_add = Vector3(0.02, 0.0, -0.05 * float(pr[1]))   # der Oberkörper lehnt sich an, die Köpfe
				me.body.head_add = Vector3(0.04, 0.0, 0.0)),                    # bleiben Wange an Wange (Ausweichen)
		_phase("main", hold, func() -> void:
			a.nudge(_n * 0.8)
			b.nudge(-_n * 0.8)
			a.interact.contact.emit("hug", b)
			b.interact.contact.emit("hug", a),
			func(pt: float, _d: float) -> void:   # beide wiegen sich leicht
				var sw := sin(pt * TAU * 0.8) * 0.05
				a.body.micro_chest = Vector3(0, 0, sw)
				b.body.micro_chest = Vector3(0, 0, sw)),
		_phase("response", 0.3, func() -> void:
			for me2: LumosActor in [a, b]:
				for hand2 in ["l", "r"]:
					me2.release(hand2, 0.4, _owner)
				me2.body.head_add = Vector3.ZERO
				me2.body.chest_add = Vector3.ZERO
				me2.body.micro_chest = Vector3.ZERO
			# beim Loslassen ein kleiner Schritt auseinander: richten sich die Köpfe wieder auf, haben sie Platz
			if bool(opts.get("step_back", true)):
				_move(a, a.rig.global_position - _n * 0.06, 0.3)
				_move(b, b.rig.global_position + _n * 0.06, 0.3)
			a.emotion.trigger("content", 0.6, 1.5)
			b.emotion.trigger("content", 0.6, 1.5)),
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
	# Trösten: Hand auf den nahen Oberarm – bei Chibi-Proportionen (Arm kürzer als der Kopfradius) liegt die Schulter
	# unter dem großen Kopf und ist nur zu erreichen, wenn die Köpfe ineinanderstecken. Klopfen: auf die Schulter.
	var near := func() -> Vector3:
		if b.body == null:
			return b.rig.global_position + Vector3.UP
		var p := a.rig.global_position
		var sd := "l" if b.body.joint_pos("shoulder.l").distance_to(p) < b.body.joint_pos("shoulder.r").distance_to(p) else "r"
		var s := b.body.joint_pos("shoulder." + sd)
		if not comfort:
			return s
		var out := s - b.rig.global_position
		out.y = 0.0
		return s.lerp(b.body.joint_pos("elbow." + sd), 0.4) + out.normalized() * 0.06 - Vector3.UP * 0.07
	var dip := [0.0]
	var per := 0.5 if comfort else 0.32   # Trösten: ruhiger Takt · Schulterklopfen: munter
	var main_secs := per * count + 0.2
	# Trösten: Platz seitlich bis schräg hinter b, von dem die Hand die nahe Schulter erreicht, ohne dass sich Köpfe
	# durchdringen (kleiner Rest: die Köpfe weichen aus); dorthin geht a mit echten Schritten
	var side := a.rig.global_position
	var beside := false
	if comfort and b.body:
		var upper_arm := func(sh: Vector3) -> Vector3:   # nahe Oberarm-Außenseite (wie near(), aber vom gedachten Platz aus)
			var sd := "l" if b.body.joint_pos("shoulder.l").distance_to(sh) < b.body.joint_pos("shoulder.r").distance_to(sh) else "r"
			var s := b.body.joint_pos("shoulder." + sd)
			var out := s - b.rig.global_position
			out.y = 0.0
			return s.lerp(b.body.joint_pos("elbow." + sd), 0.4) + out.normalized() * 0.06
		var sol := _solve_beside(upper_arm, [0.76, 0.8, 0.84, 0.88, 0.92, 0.96, 1.0, 1.05], LumosActor.AVOID_MARGIN - 0.09)
		side = sol.pos
		hand = String(sol.hand)
		beside = true
	# Vorplatz eine Schulterbreite weiter außen: dort eindrehen (die großen Köpfe schwenken frei), dann heranrücken
	var out_dir := side - b.rig.global_position
	out_dir.y = 0.0
	var pre := side + out_dir.normalized() * 0.3 if beside else side
	var path := _path_around(a, pre, b, (a.head_radius() + b.head_radius()) * 1.08) if comfort else ([side] as Array[Vector3])
	var walk := 0.0
	var wp := a.rig.global_position
	for w: Vector3 in path:
		walk += wp.distance_to(w)
		wp = w
	return [
		_phase("approach", (walk / 1.0 + 0.4) if comfort else 0.2, func() -> void:
			a.look_at_target(b)
			if comfort:
				a.emotion.trigger("compassion", 0.7, 3.0, -1.0, -1.0, b)
			else:
				a.rig.turn_to(b.rig.global_position - a.rig.global_position, 0.2)
			_clean.append(func() -> void:
				if is_instance_valid(a):
					a.look_at_target(null)),
			_walk_tick(a, path) if comfort else Callable(),
			_arrived(a, pre) if comfort else Callable()),
		_phase("turn", 0.5 if comfort else 0.0, func() -> void:
			if comfort:
				a.move(Vector3.ZERO, true, 1.0 / 60.0)
				a.rig.turn_to(b.forward() if beside else b.rig.global_position - a.rig.global_position, 0.22)
				if beside:   # nach dem Eindrehen seitlich heranrücken
					var tw := a.create_tween()
					tw.tween_interval(0.22)
					tw.tween_property(a.rig, "global_position", side, 0.26).set_trans(Tween.TRANS_SINE)
					_tw.append(tw)),
		_phase("contact", 0.22, func() -> void:
			_reach(a, hand, func() -> Vector3: return (near.call() as Vector3) + Vector3.UP * (0.07 + float(dip[0])), 0.22,
				func() -> Array: return [(b.rig.global_position - a.rig.global_position).normalized(), Vector3.DOWN], 0.0 if comfort else 0.5)
			a.body.head_add = Vector3(0.06, 0.0, 0.0 if comfort else 0.0)),   # kein Zuneigen: die großen Köpfe bleiben frei
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


## Aufhelfen (a hilft, b sitzt am Boden): mit echten Schritten hingehen, sich vorbeugen und die Hand reichen; b greift
## zu (Handschlag-Griff), beide ziehen – b steht mit dem Aufsteh-Clip auf, die Hände bleiben verbunden und steigen mit
## ihrer Schulter, a lehnt sich als Gegengewicht zurück –, kurz festhalten, loslassen, danken.
func _b_help_up() -> Array:
	if not (_two(a) and _two(b)) or not b.fallen:
		return []
	# Abstand so, dass beide Arme den Griffpunkt erreichen: a gebeugt (Schulter ≈ 8 cm tiefer), b sitzend
	var ra := a.body.reach_length()
	var rb := b.body.reach_length()
	var ha := a.body.rest_pos("shoulder.r").y - a.rig.global_position.y - 0.08
	var hb := b.body.joint_pos("shoulder.r").y - b.rig.global_position.y
	var span := 0.86 * (ra + rb)
	var stand := clampf(sqrt(maxf(span * span - (ha - hb) * (ha - hb), 0.04)) + 0.06, 0.42, 0.95)
	# Standplatz vor bis schräg vor der Sitzenden: beide Arme erreichen den Griffpunkt, niemand steht im anderen
	var grip := func(sh: Vector3) -> Vector3:
		var sb := b.body.joint_pos("shoulder.r")
		return sb + (sh - sb) * rb / maxf(ra + rb, 0.01)
	var solved := _solve_spot("r", grip, [0.0, 20.0, -20.0, 40.0, -40.0, 60.0, -60.0],
		[stand, stand + 0.08, stand + 0.16, stand + 0.24, stand + 0.32, stand + 0.4], LumosActor.AVOID_MARGIN + 0.04)
	var spot := func() -> Vector3:
		return solved
	var help_walk := _walk_tick(a, _path_around(a, solved, b, (a.head_radius() + b.head_radius()) * 0.9))
	var to_b := func() -> Vector3:
		var d := b.rig.global_position - a.rig.global_position
		d.y = 0.0
		return d.normalized() if d.length() > 0.01 else a.forward()
	var meet := func() -> Vector3:   # Griffpunkt auf der Verbindung der Schultern, nach Armlängen geteilt
		return grip.call(a.body.rest_pos("shoulder.r"))
	var walk := (spot.call() as Vector3).distance_to(a.rig.global_position)
	var rise := b.rig.clip_length("sit_up") / 1.3 if b.rig.has_clip("sit_up") else 0.6
	_clean.append(func() -> void:
		if is_instance_valid(a) and a.look_target() == b:
			a.look_at_target(null)
		if is_instance_valid(b) and b.look_target() == a:
			b.look_at_target(null))
	return [
		_phase("approach", walk / 1.0 + 0.4, func() -> void:
			a.look_at_target(b)
			a.emotion.trigger("compassion", 0.6, 2.0, -1.0, -1.0, b)
			var f := (a.rig.global_position - b.rig.global_position)
			f.y = 0.0
			if f.length() > 0.05 and b.forward().angle_to(f) > 1.0:   # die Sitzende dreht sich zum Helfer
				b.rig.turn_to(f, 0.6),
			func(_pt: float, d: float) -> void:
				(help_walk as Callable).call(_pt, d)
				if _pt > 0.35 and b.look_target() != a:
					b.look_at_target(a),
			func() -> bool:
				var to := (spot.call() as Vector3) - a.rig.global_position
				to.y = 0.0
				return to.length() < 0.07 and a.speed() < 0.25),
		_phase("offer", 0.55, func() -> void:
			a.rig.turn_to(to_b.call(), 0.22)
			a.move(Vector3.ZERO, true, 1.0 / 60.0)
			a.body.chest_add = Vector3(0.16, 0.0, 0.0)   # leicht vorbeugen, der Blick geht mit dem Kopf nach unten
			a.body.head_add = Vector3(0.24, 0.0, 0.0)
			_reach(a, "r", meet, 0.42, func() -> Array:
				var n := to_b.call() as Vector3
				return [(n + Vector3.DOWN * 0.35).normalized(), -n.cross(Vector3.UP).normalized()], 0.8),
			func(pt: float, _d: float) -> void:
				if pt > 0.18 and b.hand_owner("r") != _owner:
					_reach(b, "r", meet, 0.36, func() -> Array:
						var n := -(to_b.call() as Vector3)
						return [(n + Vector3.UP * 0.45).normalized(), n.cross(Vector3.UP).normalized()], 0.0),
			func() -> bool:
				return a.hand_pos("r").distance_to(b.hand_pos("r")) < 0.07),
		_phase("grip", 0.22, func() -> void:
			a.interact.contact.emit("help_up", b)
			b.interact.contact.emit("help_up", a)
			b.nudge((to_b.call() as Vector3) * -0.8)),
		_phase("pull", rise, func() -> void:
			b.get_up(1.3)
			a.nudge((to_b.call() as Vector3) * -1.2)
			a.body.chest_add = Vector3(-0.12, 0.0, 0.0)   # zurücklehnen: Gegengewicht beim Ziehen
			a.body.head_add = Vector3.ZERO
			var tw2 := a.create_tween()
			tw2.tween_interval(rise * 0.6)
			tw2.tween_callback(func() -> void:
				if is_instance_valid(a) and a.body:
					a.body.chest_add = Vector3.ZERO)
			_tw.append(tw2)),
		_phase("steady", 0.4, func() -> void:
			b.nudge((to_b.call() as Vector3) * -0.6)
			b.emotion.trigger("relief", 0.75, 1.4),
			Callable(),
			func() -> bool:
				return not b.fallen),
		_phase("release", 0.35, func() -> void:
			a.release("r", 0.35, _owner)
			b.release("r", 0.35, _owner)
			a.emotion.trigger("smile", 0.7, 1.2)
			b.emotion.trigger("tender", 0.6, 1.4, -1.0, -1.0, a)
			b.micro.play("nod", {"prio": LumosLayers.P_SOCIAL, "owner": _owner + ":nod"})),
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
			for sd in ["l", "r"]:   # wenig Vorlehnen: die Arme schieben, der Kopf bleibt weg
				_reach(a, sd, chest.bind(sd), 0.14, func() -> Array: return [Vector3.UP, _n], 0.35)),
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
	# hinter b, mit Abstand aus den Körpervolumen; liegt b auf dem Weg, geht a in einem Bogen außen herum
	var back := -b.forward()
	var dist := maxf(LumosActor.fit_distance(b, a, back, b.forward(), b.forward(), 0.12), (a.head_radius() + b.head_radius()) * 1.0)
	var behind := b.rig.global_position + back * dist
	var from := a.rig.global_position - b.rig.global_position
	from.y = 0.0
	var sneak := float(opts.get("sneak", 0.6))
	return [
		_phase("approach", sneak, func() -> void:
			a.feel("teasing", 0.3)
			a.look_at_target(b)
			var tw := a.create_tween()
			if from.length() > 0.05 and from.normalized().dot(back) < 0.9:   # nicht schon dahinter: im Kreisbogen außen herum
				var c := b.rig.global_position
				var y := a.rig.global_position.y
				var r0 := maxf(from.length(), dist)
				var ang0 := Vector3.BACK.signed_angle_to(from.normalized(), Vector3.UP)
				var ang1 := Vector3.BACK.signed_angle_to(back, Vector3.UP)
				var da := wrapf(ang1 - ang0, -PI, PI)
				tw.tween_method(func(k: float) -> void:
					if is_instance_valid(a) and is_instance_valid(b):
						var p := c + Vector3.BACK.rotated(Vector3.UP, ang0 + da * k) * lerpf(r0, dist, k)
						a.rig.global_position = Vector3(p.x, y, p.z), 0.0, 1.0, sneak).set_trans(Tween.TRANS_SINE)
			else:
				tw.tween_property(a.rig, "global_position", Vector3(behind.x, a.rig.global_position.y, behind.z), sneak).set_trans(Tween.TRANS_SINE)
			_tw.append(tw)
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
