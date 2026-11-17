class_name LumosSocial
extends Node
## Gemeinsame soziale Wahrnehmung aller Figuren einer Szene (ein Knoten je SceneTree, wird bei Bedarf angelegt).
##
##  * Register: Figuren (LumosActor) und interessante Dinge (add_poi) mit Auffälligkeit.
##  * Ereignisse: emit(kind, quelle, daten) – Lachen, Weinen, Schreck, Winken, Zeigen, Witz, Sieg, Niederlage,
##    Anbieten, Tanzen, Schmollen, Treffer, Sprechen … Hörbare Ereignisse erreichen alle im Umkreis, sichtbare nur,
##    wer in die Richtung schaut. Jede Figur entscheidet selbst (LumosMind), ob und wie sie reagiert.
##  * Wahrnehmung: perceive(figur) – wer ist nah, wer schaut mich an, wer kommt näher, wer lacht/weint/spricht,
##    wer hält etwas – je Bild einmal berechnet und geteilt (nicht jede Figur fragt alles ständig ab).
##  * Beziehungen: relation(a, b) 0..1 (Standard 0,75 = befreundet), set_relation().
##  * Laufende Interaktionen (LumosInteraction) werden hier getaktet.

const AUDIBLE := ["laugh", "cry", "fright", "scream", "talk", "joke", "cheer", "hit", "win", "lose", "boo", "fall"]
const RANGE := 14.0

var actors: Array[LumosActor] = []
var pois: Array = []                   # [{node, salience, kind}]
var interactions: Array = []           # LumosInteraction
var log: Array = []                    # letzte Ereignisse (Tests): [t, kind, quelle]
var t := 0.0
var _rel := {}
var _perc := {}                        # Figur → [Bild, Ergebnis]
var _pub := {}                         # Figur → [Bild, öffentlicher Zustand, Blickziel, Geschwindigkeit]
var _frame := 0
var _root_frame := -1
var _roots := PackedVector3Array()     # Wurzel je Eintrag in actors (INF = unsichtbar/ohne Körper), einmal je Bild


static func of(n: Node) -> LumosSocial:
	if n == null or not n.is_inside_tree():
		return null
	var root := n.get_tree().root
	var h := root.get_node_or_null("LumosSocial") as LumosSocial
	if h == null and root.has_meta("lumos_social"):   # schon angelegt, aber noch nicht eingehängt (gleiches Bild)
		var m: Variant = root.get_meta("lumos_social")
		if m is LumosSocial and is_instance_valid(m):
			h = m
	if h == null:
		h = LumosSocial.new()
		h.name = "LumosSocial"
		root.add_child.call_deferred(h)
		root.set_meta("lumos_social", h)
	return h


static func find(n: Node) -> LumosSocial:
	if n == null or not n.is_inside_tree():
		return null
	var root := n.get_tree().root
	var h := root.get_node_or_null("LumosSocial") as LumosSocial
	if h == null and root.has_meta("lumos_social"):
		h = root.get_meta("lumos_social") as LumosSocial
	return h


func _ready() -> void:
	process_priority = 5


func register(a: LumosActor) -> void:
	if not (a in actors):
		actors.append(a)
		_root_frame = -1


func unregister(a: LumosActor) -> void:
	actors.erase(a)
	_root_frame = -1
	_perc.erase(a)
	_pub.erase(a)
	_help.erase(a)
	_comfort.erase(a)


## Wurzelpositionen aller Figuren (Index wie actors), einmal je Bild ermittelt: Nachbarschaftsabfragen (Ausweichen
## bei Nähe) prüfen Abstände in einem gepackten Feld statt je Paar mehrere Objekt-Eigenschaften. Unsichtbare oder
## körperlose Figuren stehen auf INF.
func roots() -> PackedVector3Array:
	var fr := Engine.get_process_frames()
	if fr != _root_frame or _roots.size() != actors.size():
		_root_frame = fr
		_roots.resize(actors.size())
		for i in actors.size():
			var o := actors[i]
			var ok := is_instance_valid(o) and o.body != null and o.rig.visible and o.rig.is_inside_tree()
			_roots[i] = o.rig.global_position if ok else Vector3(INF, INF, INF)
	return _roots


func add_poi(node: Node3D, salience := 1.0, kind := "thing") -> void:
	pois.append({"node": node, "salience": salience, "kind": kind})


func relation(a: LumosActor, b: LumosActor) -> float:
	return float(_rel.get(_key(a, b), 0.75))


func set_relation(a: LumosActor, b: LumosActor, v: float) -> void:
	_rel[_key(a, b)] = clampf(v, 0.0, 1.0)


func _key(a: LumosActor, b: LumosActor) -> String:
	var ia := a.get_instance_id()
	var ib := b.get_instance_id()
	return "%d_%d" % [mini(ia, ib), maxi(ia, ib)]


## Ereignis aussenden. data: pos (Vector3), target (LumosActor), intensity (0..1), dir … beliebig erweiterbar.
signal event(kind: String, src: LumosActor, data: Dictionary)   ## jedes soziale Ereignis (Werkzeuge, Tests)


func emit(kind: String, src: LumosActor, data := {}) -> void:
	var pos: Vector3 = data.get("pos", src.rig.global_position if src else Vector3.ZERO)
	var ev := {"kind": kind, "src": src, "pos": pos, "t": t, "data": data, "intensity": float(data.get("intensity", 1.0))}
	log.append([t, kind, src])
	if log.size() > 64:
		log.pop_front()
	event.emit(kind, src, data)
	var audible := kind in AUDIBLE
	for a in actors:
		if a == src or not is_instance_valid(a) or a.mind == null or not a.rig.visible:
			continue
		var d := a.rig.global_position.distance_to(pos)
		if d > float(data.get("range", RANGE)):
			continue
		if not audible:   # sichtbar: nur wer ungefähr hinschaut (210°) oder sehr nah ist
			var to := pos - a.rig.global_position
			to.y = 0.0
			if d > 2.5 and to.length() > 0.01 and a.forward().dot(to.normalized()) < -0.26:
				continue
		a.mind.hear(ev, d)


## Was a von den anderen wahrnimmt – je Bild einmal berechnet.
func perceive(a: LumosActor) -> Array:
	var c: Array = _perc.get(a, [])
	if not c.is_empty() and int(c[0]) == _frame:
		return c[1]
	var p0 := Time.get_ticks_usec() if LumosProf.on else 0
	var out: Array = []
	var me := a.rig.global_position
	for o in actors:
		if o == a or not is_instance_valid(o) or not o.rig.visible or not o.rig.is_inside_tree():
			continue
		var to := o.rig.global_position - me
		var d := to.length()
		if d > RANGE:
			continue
		var flat := Vector3(to.x, 0.0, to.z)
		var dir := flat.normalized() if flat.length() > 0.01 else a.forward()
		var pub := _public(o)
		var e: Dictionary = (pub[1] as Dictionary).duplicate()
		e.d = d
		e.dir = dir
		e.looks_at_me = pub[2] == a
		e.approach = -(pub[3] as Vector3).dot(dir)
		out.append(e)
	_perc[a] = [_frame, out]
	if p0 > 0: LumosProf.add(&"social.perceive", p0)
	return out


## Was andere an einer Figur wahrnehmen können (Gefühl, Lachen, Weinen, Sprechen, Halten, Blickziel, Bewegung):
## einmal je Bild und Figur ermittelt – eine Momentaufnahme, gleich für alle Beobachter und unabhängig davon, in
## welcher Reihenfolge die Figuren verarbeitet werden. Die Einträge je Beobachter ergänzen nur Abstand und Richtung.
func _public(o: LumosActor) -> Array:
	var c: Array = _pub.get(o, [])
	if not c.is_empty() and int(c[0]) == _frame:
		return c
	var em := o.emotion
	var st := {"a": o, "d": 0.0, "dir": Vector3.ZERO, "looks_at_me": false, "approach": 0.0,
		"emo": em.dominant() if em else "neutral", "emo_i": em.dominant_intensity() if em else 0.0,
		"valence": float(em.mods.valence) if em else 0.0, "arousal": float(em.mods.arousal) if em else 0.2,
		"laughing": o.is_laughing(), "crying": em != null and (em.intensity_of("cry") > 0.3 or em.intensity_of("sad") > 0.6),
		"talking": o.face != null and o.face.talk > 0.1, "holding": o.interact != null and (o.interact.held.l != null or o.interact.held.r != null)}
	c = [_frame, st, o.look_focus(), o.velocity()]
	_pub[o] = c
	return c


var _comfort := {}


## Wer tröstet gerade diese Figur? (nur einer geht hin)
func comforter_for(a: LumosActor) -> LumosActor:
	var c: Variant = _comfort.get(a)
	return c if c is LumosActor and is_instance_valid(c) else null


func claim_comfort(a: LumosActor, by: LumosActor) -> void:
	if by == null:
		_comfort.erase(a)
	else:
		_comfort[a] = by


var _help := {}


## Wer hilft gerade dieser Figur auf? (nur einer geht hin)
func helper_for(a: LumosActor) -> LumosActor:
	var c: Variant = _help.get(a)
	return c if c is LumosActor and is_instance_valid(c) else null


func claim_help(a: LumosActor, by: LumosActor) -> void:
	if by == null:
		_help.erase(a)
	else:
		_help[a] = by


func add_interaction(it: RefCounted) -> void:
	interactions.append(it)


## Laufende Interaktion einer Figur (oder null).
func interaction_of(a: LumosActor) -> RefCounted:
	for it in interactions:
		if it.get("a") == a or it.get("b") == a:
			return it
	return null


func _process(delta: float) -> void:
	var p0 := Time.get_ticks_usec() if LumosProf.on else 0
	t += delta
	_frame += 1
	actors = actors.filter(func(x: LumosActor) -> bool: return is_instance_valid(x))
	for it in interactions.duplicate():
		var q := Time.get_ticks_usec() if p0 > 0 else 0
		it.call("tick", delta)
		if q > 0: LumosProf.add(&"interaction", q)
	interactions = interactions.filter(func(x: RefCounted) -> bool: return not bool(x.get("done")))
	if p0 > 0: LumosProf.add(&"social.hub", p0)
