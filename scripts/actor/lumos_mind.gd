class_name LumosMind
extends RefCounted
## Soziales Verhalten einer Figur: hört Ereignisse anderer (LumosSocial.emit), entscheidet nach Persönlichkeit,
## Beziehung, Entfernung und eigenem Zustand, ob und wie sie reagiert – zeitversetzt (Reaktionszeit je
## Persönlichkeit, mit Streuung) und individuell, nie alle gleichzeitig gleich.
##
## Autonomie (cfg.autonomy) begrenzt, was die Figur von sich aus tut:
##   ≥ 0,2  hinschauen · ≥ 0,35 Gesicht reagiert (lächeln, Mitgefühl, Staunen) · ≥ 0,6 Gesten und Mitlachen mit dem
##   Körper, Cartoon aus starken Gefühlen · ≥ 0,75 Handlungen mit Ortswechsel (trösten gehen, mittanzen)
## Reaktionen auf Ereignisse:
##   laugh → Mitlachen (Ansteckung) oder Lächeln · cry → Mitgefühl, ggf. trösten gehen · fright/boo → in die
##   Richtung schauen, kurz erschrecken · wave → zurückwinken · joke/tease/hit → lachen, schmunzeln oder ungläubig
##   den Kopf schütteln · win/lose → freuen, bewundern, gespielt enttäuscht, Schadenfreude · dance → mittanzen oder
##   mitwippen · sulk → Mitgefühl oder necken · point → dem Zeigen folgen · talk → zuhören (hinschauen, nicken)

var actor: LumosActor
var reactions: Array = []        # Protokoll (Tests): [Zeit, Ereignis, Reaktion, Verzögerung]
var _inbox: Array = []
var _todo: Array = []            # [fällig, Callable, Name]
var _cool := {}
var _t := 0.0
var _tick := 0.0
var _emo_c := ""
var _emo_c_t := -99.0
var _last_dom := ""
var _pant_t := 0.0
var _peak_t := 0.0
var _peak_id := ""


func setup(a: LumosActor) -> void:
	actor = a
	_tick = a.rng.randf() * 0.2


func hear(ev: Dictionary, dist: float) -> void:
	_inbox.append([ev, dist])


func update(d: float) -> void:
	_t += d
	for e: Array in _inbox:
		_react(e[0], float(e[1]))
	_inbox.clear()
	if not _todo.is_empty():
		var due: Array = _todo.filter(func(x: Array) -> bool: return float(x[0]) <= _t)
		if not due.is_empty():
			_todo = _todo.filter(func(x: Array) -> bool: return float(x[0]) > _t)
			for x: Array in due:
				(x[1] as Callable).call()
	_tick -= d
	if _tick <= 0.0:
		_tick = 0.2
		_periodic()


func pending() -> int:
	return _todo.size()


func _later(ev_kind: String, name: String, delay: float, f: Callable) -> void:
	_todo.append([_t + delay, f, name])
	reactions.append([_t, ev_kind, name, delay])
	if reactions.size() > 80:
		reactions.pop_front()


func _cool_ok(tag: String, secs: float) -> bool:
	if float(_cool.get(tag, -99.0)) > _t:
		return false
	_cool[tag] = _t + secs
	return true


func _react(ev: Dictionary, dist: float) -> void:
	var kind := String(ev.kind)
	var src: LumosActor = ev.src if ev.src is LumosActor else null
	var p := actor.personality
	var rng := actor.rng
	var em := actor.emotion
	var rel := actor.social.relation(actor, src) if src and actor.social else 0.75
	var i := float(ev.intensity)
	var delay := p.reaction_delay(rng) * (1.0 + dist / 14.0)
	var data: Dictionary = ev.data
	if actor.in_interaction() and kind != "boo":
		return
	match kind:
		"laugh":
			if not actor.autonomy_gate(0.2) or src == null or actor.is_laughing() or not _cool_ok("laugh", 2.4):
				return
			_later(kind, "look", delay * 0.6, actor.look_social.bind(src, 1.6))
			if not actor.autonomy_gate(0.35):
				return
			var pc := p.contagion() * rel * clampf(i, 0.3, 1.0) * (1.0 if dist < 6.0 else 0.55)
			if rng.randf() < pc and p.shyness < 0.75:
				var li := clampf((0.35 + 0.6 * p.contagion()) * rng.randf_range(0.75, 1.1), 0.3, 1.0)
				if not actor.autonomy_gate(0.6):
					li *= 0.5
				var ld := rng.randf_range(0.8, 1.6)
				_later(kind, "laugh", delay + rng.randf_range(0.1, 0.5), func() -> void:
					if not actor.in_interaction():
						actor.laugh(ld, li, "smile", false))
			else:
				_later(kind, "smile", delay, em.trigger.bind("smile" if p.shyness < 0.6 else "bashful", 0.65, 1.5, -1.0, -1.0, src))
		"cry":
			if not actor.autonomy_gate(0.2) or src == null:
				return
			_later(kind, "look", delay, actor.look_social.bind(src, 2.5))
			if actor.autonomy_gate(0.35):
				_later(kind, "compassion", delay, em.trigger.bind("compassion", clampf(0.45 + 0.55 * p.friendliness * rel, 0.0, 1.0), 3.0, -1.0, -1.0, src))
			if actor.autonomy_gate(0.75) and p.friendliness > 0.55 and actor.social.comforter_for(src) == null and _cool_ok("comfort", 8.0):
				actor.social.claim_comfort(src, actor)
				_later(kind, "comfort", delay + 0.5, func() -> void:
					var it := LumosInteraction.start("comfort", actor, src)
					if it == null:
						actor.social.claim_comfort(src, null)
					else:
						it.finished.connect(func(_ok: bool) -> void: actor.social.claim_comfort(src, null)))
		"fright", "scream", "boo":
			if not actor.autonomy_gate(0.2) or data.get("target") == actor:
				return
			var at: Vector3 = data.get("source", ev.pos)
			_later(kind, "look_toward", delay * 0.6, actor.look_social.bind(at, 1.4))
			if actor.autonomy_gate(0.35):
				_later(kind, "startle", delay * 0.6, em.trigger.bind("surprise", clampf(0.55 * (1.25 - p.confidence) * i, 0.15, 0.8), 0.5))
		"wave":
			var tg: Variant = data.get("target")
			if not actor.autonomy_gate(0.35) or src == null or (tg != null and tg != actor):
				return
			_later(kind, "look", delay, actor.look_social.bind(src, 1.8))
			_later(kind, "smile", delay, em.trigger.bind("smile", 0.75, 1.6, -1.0, -1.0, src))
			if actor.autonomy_gate(0.6) and _cool_ok("wave", 4.0):
				_later(kind, "wave_back", delay + 0.25, actor.micro.play.bind("wave", {"target": src, "prio": LumosLayers.P_SOCIAL}))
		"joke", "tease", "funny", "hit", "slapstick":
			if not actor.autonomy_gate(0.35) or src == null or not _cool_ok("joke", 2.0):
				return
			_later(kind, "look", delay * 0.7, actor.look_social.bind(src, 1.5))
			var h := p.humor * rng.randf_range(0.7, 1.3)
			if h > 0.58 and actor.autonomy_gate(0.6):
				var ls := rng.randf_range(0.8, 1.4)
				_later(kind, "laugh", delay + 0.2, actor.laugh.bind(ls, clampf(h, 0.4, 1.0), "smile", false))
			elif h < 0.3:
				_later(kind, "disbelief", delay, em.trigger.bind("disbelief", 0.7, 1.2))
				if actor.autonomy_gate(0.6):
					_later(kind, "head_shake", delay + 0.1, actor.micro.play.bind("head_shake", {"prio": LumosLayers.P_SOCIAL}))
			else:
				_later(kind, "smirk", delay, em.trigger.bind("playful", 0.7, 1.4))
			if kind == "hit" and p.friendliness > 0.65:
				_later(kind, "worried", delay * 0.5, em.trigger.bind("worried", 0.5, 0.8))
		"win":
			if not actor.autonomy_gate(0.35) or src == null:
				return
			_later(kind, "look", delay, actor.look_social.bind(src, 2.0))
			if rel >= 0.5:
				var e := "joy" if rng.randf() < 0.6 else "admiration"
				_later(kind, e, delay, em.trigger.bind(e, 0.8, 1.8, -1.0, -1.0, src))
				if actor.autonomy_gate(0.6):
					_later(kind, "clap", delay + 0.2, actor.micro.play.bind("clap" if p.energy < 0.7 else "fist_pump", {"prio": LumosLayers.P_SOCIAL}))
			else:
				var e2 := "disappointed" if p.humor < 0.5 else "playful"
				_later(kind, e2, delay, em.trigger.bind(e2, 0.7, 1.6, -1.0, -1.0, src))
		"lose":
			if not actor.autonomy_gate(0.35) or src == null:
				return
			_later(kind, "look", delay, actor.look_social.bind(src, 1.8))
			var e3 := "gloat" if p.playfulness > 0.7 and p.friendliness < 0.5 else "compassion"
			_later(kind, e3, delay, em.trigger.bind(e3, 0.7, 1.6, -1.0, -1.0, src))
		"dance":
			if not actor.autonomy_gate(0.35) or src == null:
				return
			_later(kind, "look", delay, actor.look_social.bind(src, 2.0))
			if actor.autonomy_gate(0.75) and p.playfulness + p.sociability > 1.15 and _cool_ok("dance", 10.0):
				_later(kind, "join_dance", delay + 0.4, func() -> void:
					if not actor.in_interaction() and is_instance_valid(src):
						LumosInteraction.start("dance_together", src, actor, {"move": false}))
			elif actor.autonomy_gate(0.6):
				_later(kind, "bob", delay, actor.micro.play.bind("nod", {"prio": LumosLayers.P_SOCIAL}))
				_later(kind, "smile", delay, em.trigger.bind("joy", 0.6, 1.5))
		"sulk", "offended":
			if not actor.autonomy_gate(0.35) or src == null:
				return
			_later(kind, "look", delay, actor.look_social.bind(src, 1.6))
			var e4 := "teasing" if p.playfulness > 0.7 else "compassion"
			_later(kind, e4, delay, em.trigger.bind(e4, 0.6, 1.4, -1.0, -1.0, src))
		"point":
			if not actor.autonomy_gate(0.2):
				return
			var tp: Vector3 = data.get("target_pos", ev.pos)
			_later(kind, "follow_point", delay, actor.look_social.bind(tp, 2.0))
			if actor.autonomy_gate(0.35) and p.curiosity > 0.45:
				_later(kind, "curious", delay + 0.2, em.trigger.bind("curious", 0.6, 1.4))
		"talk":
			if not actor.autonomy_gate(0.2) or src == null:
				return
			_later(kind, "listen", delay * 0.5, actor.look_social.bind(src, float(data.get("secs", 2.0))))
			if actor.autonomy_gate(0.6) and rng.randf() < 0.5:
				_later(kind, "nod", delay + rng.randf_range(0.5, 1.2), actor.micro.play.bind("nod", {"prio": LumosLayers.P_SOCIAL}))


## Alle 0,2 s: starke Gefühle → Cartoon (situationsabhängig, nicht ständig), Mundaktionen, Atem.
func _periodic() -> void:
	var em := actor.emotion
	if em == null:
		return
	var p := actor.personality
	var sr: Array = em.strongest_reaction()
	var dom := String(sr[0])
	var di := float(sr[1])
	var c := String(LumosEmotion.meta(dom).get("c", "")) if dom != "" else ""
	var thr := 0.97 - 0.25 * p.cartoon_bias()
	_peak_t = _peak_t + 0.2 if c != "" and di > thr and dom == _peak_id else 0.0
	_peak_id = dom
	# nur bei einem anhaltenden Höhepunkt (≥ 0,4 s), nicht jedes Mal (Zufall je Persönlichkeit), nie in Interaktionen
	if c != "" and _peak_t >= 0.4 and actor.autonomy_gate(0.6) and (dom != _emo_c or _t - _emo_c_t > 9.0) and not actor.in_interaction():
		_emo_c = dom
		_emo_c_t = _t
		if actor.rng.randf() < 0.3 + 0.5 * p.cartoon_bias() and LumosCartoon.react(actor, c, di):
			reactions.append([_t, "emotion:" + dom, "cartoon:" + c, 0.0])
	var m := String(em.mods.mouth)
	if actor.face and m != "":
		if em.dominant() != _last_dom and m != "pant":
			actor.face.mouth_action(m)
		elif m == "pant":
			_pant_t -= 0.2
			if _pant_t <= 0.0:
				_pant_t = 1.8
				actor.face.mouth_action("pant")
	_last_dom = em.dominant()
