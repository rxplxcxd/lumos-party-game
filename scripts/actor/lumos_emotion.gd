class_name LumosEmotion
extends RefCounted
## Dynamischer Gefühlszustand einer Figur. Mehrere Gefühle können gleichzeitig wirken – auch widersprüchliche –,
## jedes mit Stärke, Anstieg, Haltezeit, Abklingen, Auslöser und Nachwirkung. Daraus entstehen je Bild:
##   face_out      Gesichtsparameter (LumosFace.KEYS), gemischt nach Stärke
##   posture_out   Haltung (Brust, Kopf, Schultern, Neigung) inkl. Grundhaltung der Persönlichkeit
##   mods          Verhaltens-Hinweise: Blickstil, Lidschlag, bevorzugte Gesten, Atmung, Mundaktion, Cartoon-Vorschlag
## Gesicht (LumosFace.EXPR) und Körper (LumosBody.POSTURE) besitzen ihre Parameter-Vorlagen; hier liegt nur, wie ein
## Gefühl sich verhält (META). Unbekannte Namen mit Gesichtsvorlage funktionieren ebenfalls (Standardverhalten).
##
## Begriffe: Stimmung (set_mood) = hält an, bis eine neue gesetzt wird · Reaktion (trigger) = steigt an, hält, klingt
## ab und hinterlässt ggf. eine Nachwirkung (after, z. B. Lachen → Zufriedenheit, Schreck → Nervosität).

signal changed(dominant: String)
signal triggered(name: String, intensity: float, source: Variant)

## v Valenz (−1..1) · a Erregung (0..1) · g Blickstil · b Lidschlag-Faktor · x bevorzugte Gesten · after/ai Nachwirkung
## und deren Stärke · hold Haltezeit (s) · c Cartoon-Reaktion bei großer Stärke · br Atmung [Stärke, Takt] · m Mundaktion
const META := {
	"neutral": {"v": 0.0, "a": 0.2},
	"smile": {"v": 0.5, "a": 0.3, "g": "contact"},
	"grin": {"v": 0.65, "a": 0.5, "g": "contact"},
	# — positiv —
	"joy": {"v": 0.8, "a": 0.6, "g": "contact", "x": ["clap"], "after": "content", "ai": 0.5},
	"laugh": {"v": 0.9, "a": 0.8, "after": "content", "ai": 0.6, "c": "laugh_fit"},
	"delight": {"v": 0.9, "a": 0.85, "x": ["clap", "fist_pump"], "after": "joy", "ai": 0.6, "c": "joy_hop", "b": 1.2},
	"euphoria": {"v": 1.0, "a": 1.0, "x": ["arms_up", "fist_pump"], "after": "delight", "ai": 0.6, "c": "spin_joy"},
	"pride": {"v": 0.7, "a": 0.45, "g": "contact", "x": ["hips"], "after": "content", "ai": 0.5, "c": "proud_pose"},
	"relief": {"v": 0.5, "a": 0.25, "x": ["wipe_brow"], "after": "content", "ai": 0.5, "m": "sigh", "br": [0.9, 0.7]},
	"content": {"v": 0.55, "a": 0.2, "g": "soft", "b": 0.85},
	"affection": {"v": 0.8, "a": 0.4, "g": "contact", "x": ["clasp"], "c": "love", "after": "content", "ai": 0.5},
	"tender": {"v": 0.7, "a": 0.3, "g": "contact"},
	"curious": {"v": 0.35, "a": 0.55, "g": "target", "x": ["chin"], "b": 0.8},
	"playful": {"v": 0.7, "a": 0.7, "x": ["bounce"], "c": "joy_hop"},
	"gloat": {"v": 0.5, "a": 0.6, "x": ["rub_hands"], "m": "snicker", "after": "playful", "ai": 0.4},
	"bashful": {"v": 0.35, "a": 0.45, "g": "avert", "x": ["scratch", "face_touch"], "c": "blush_shy", "b": 1.3},
	# — negativ —
	"sad": {"v": -0.7, "a": 0.25, "g": "down", "b": 0.7, "x": ["hug_self"], "c": "cry", "br": [0.5, 0.9]},
	"disappointed": {"v": -0.55, "a": 0.3, "g": "down", "m": "sigh", "x": ["facepalm"], "after": "sad", "ai": 0.3},
	"fear": {"v": -0.7, "a": 0.85, "g": "scan", "b": 1.6, "x": ["clutch"], "c": "jump_back", "after": "nervous", "ai": 0.5,
		"br": [0.8, 2.4]},
	"scared": {"v": -0.7, "a": 0.85, "g": "scan", "b": 1.6, "x": ["clutch"], "c": "jump_back", "after": "nervous", "ai": 0.5},
	"panic": {"v": -0.9, "a": 1.0, "g": "scan", "b": 2.0, "x": ["flail"], "c": "freeze", "after": "fear", "ai": 0.5, "br": [1.0, 3.0]},
	"anger": {"v": -0.7, "a": 0.85, "g": "target", "b": 0.6, "x": ["fists"], "c": "puff_cheeks", "after": "frustrated", "ai": 0.4},
	"angry": {"v": -0.7, "a": 0.85, "g": "target", "b": 0.6, "x": ["fists"], "c": "puff_cheeks", "after": "frustrated", "ai": 0.4},
	"frustrated": {"v": -0.5, "a": 0.6, "x": ["scratch", "facepalm"], "c": "stomp", "m": "press"},
	"jealous": {"v": -0.4, "a": 0.5, "g": "side", "x": ["cross_arms"], "c": "sulk", "after": "defiant", "ai": 0.3},
	"shame": {"v": -0.6, "a": 0.4, "g": "down", "x": ["face_hide"], "c": "face_in_hands", "b": 1.4},
	"confused": {"v": -0.1, "a": 0.45, "g": "scan", "x": ["scratch", "shrug"], "c": "head_shake"},
	"insecure": {"v": -0.3, "a": 0.4, "g": "avert", "b": 1.4, "x": ["rub_hands", "hug_self"]},
	"lonely": {"v": -0.55, "a": 0.2, "g": "scan", "x": ["hug_self"], "b": 0.8},
	"exhausted": {"v": -0.3, "a": 0.3, "g": "down", "x": ["wipe_brow", "stretch"], "m": "pant", "br": [1.0, 2.6], "b": 0.7},
	# — sozial / situativ —
	"surprise": {"v": 0.0, "a": 0.9, "g": "target", "c": "big_surprise", "after": "curious", "ai": 0.5, "hold": 0.9},
	"surprised": {"v": 0.0, "a": 0.9, "g": "target", "c": "big_surprise", "after": "curious", "ai": 0.5, "hold": 0.9},
	"disbelief": {"v": -0.1, "a": 0.5, "x": ["head_shake"], "c": "head_shake", "after": "confused", "ai": 0.3},
	"suspicious": {"v": -0.3, "a": 0.4, "g": "side", "b": 0.5, "x": ["cross_arms", "chin"]},
	"embarrassed": {"v": -0.1, "a": 0.5, "g": "avert", "x": ["scratch", "face_touch"], "c": "blush_shy", "after": "bashful", "ai": 0.4},
	"nervous": {"v": -0.35, "a": 0.6, "g": "scan", "b": 2.0, "x": ["rub_hands", "scratch"], "c": "sweat"},
	"compassion": {"v": 0.2, "a": 0.35, "g": "target"},
	"admiration": {"v": 0.7, "a": 0.55, "g": "target", "x": ["clasp"], "b": 0.7},
	"defiant": {"v": -0.3, "a": 0.55, "g": "away", "x": ["cross_arms"], "c": "sulk"},
	"impatient": {"v": -0.3, "a": 0.6, "g": "scan", "b": 1.4, "x": ["tap", "hips", "cross_arms"]},
	"focus": {"v": 0.0, "a": 0.5, "g": "target", "b": 0.4, "m": "press"},
	"pensive": {"v": 0.0, "a": 0.25, "g": "think", "x": ["chin"], "b": 0.75},
	"teasing": {"v": 0.6, "a": 0.6, "g": "contact", "x": ["poke"], "m": "snicker"},
	# — vorhandene Ausdrücke (1.5.x) —
	"awe": {"v": 0.6, "a": 0.7, "g": "target", "b": 0.5},
	"worried": {"v": -0.4, "a": 0.45, "g": "scan", "b": 1.3, "x": ["rub_hands"]},
	"determined": {"v": 0.2, "a": 0.6, "g": "target", "b": 0.6, "x": ["fists"]},
	"sleepy": {"v": 0.0, "a": 0.05, "g": "down", "b": 0.5, "x": ["stretch"], "m": "yawn"},
	"asleep": {"v": 0.1, "a": 0.0, "g": "none", "br": [0.9, 0.7]},
	"pant": {"v": -0.1, "a": 0.6, "m": "pant", "br": [1.0, 2.8], "x": ["wipe_brow"]},
	"ouch": {"v": -0.5, "a": 0.8},
	"smug": {"v": 0.5, "a": 0.4, "g": "contact", "x": ["hips"]},
	"dreamy": {"v": 0.5, "a": 0.15, "g": "up", "b": 0.8},
	"plead": {"v": 0.1, "a": 0.5, "g": "contact", "x": ["clasp"], "c": "puppy"},
	# — Cartoon-Gesichter —
	"cry": {"v": -0.9, "a": 0.8, "m": "sob", "after": "sad", "ai": 0.45, "br": [0.9, 2.0]},
	"love": {"v": 0.9, "a": 0.5, "g": "target"},
	"puppy": {"v": 0.2, "a": 0.5, "g": "contact"},
	"sulk": {"v": -0.4, "a": 0.4, "g": "away", "x": ["cross_arms"]},
	"puffed": {"v": -0.6, "a": 0.8},
	"dizzy": {"v": -0.2, "a": 0.5, "g": "none"},
	"cross_eyed": {"v": 0.1, "a": 0.4, "g": "none"},
	"sleep_smile": {"v": 0.4, "a": 0.0, "g": "none"},
}
## Diese Gesichtsparameter werden nicht gemittelt, sondern das stärkste Gefühl gewinnt (Röte, Tränen, Zittern …).
const MAX_KEYS := ["blush", "tear", "tremble", "cheek", "sclera", "cross"]

var personality: LumosPersonality
var expressions: Dictionary = {}
var postures: Dictionary = {}
var keys: Array = []
var face_out := {}
var posture_out := Vector4.ZERO
var mods := {"blink": 1.0, "gaze": "", "gest": [], "breath": [], "mouth": "", "valence": 0.0, "arousal": 0.2,
	"cartoon": "", "cartoon_i": 0.0}
var mood_id := "neutral"
var _act: Array = []
var _dom := "neutral"
var _base := {}


func setup(p: LumosPersonality, exprs: Dictionary, posts: Dictionary, face_keys: Array) -> void:
	personality = p if p else LumosPersonality.new()
	expressions = exprs
	postures = posts
	keys = face_keys
	var n: Dictionary = expressions.get("neutral", {})
	for k: String in keys:
		_base[k] = float(n.get(k, 1.0 if k in ["width", "pupil"] else 0.0))
	face_out = _base.duplicate()
	set_mood("neutral", 1.0, 0.0)


static func meta(id: String) -> Dictionary:
	return META.get(id, {"v": 0.0, "a": 0.4})


func knows(id: String) -> bool:
	return expressions.has(id) or META.has(id)


## Grundstimmung: hält an, bis eine neue gesetzt wird. secs = Übergangszeit (wie bisher feel()/expr()).
func set_mood(id: String, intensity := 1.0, secs := 0.3) -> void:
	for e in _act:
		if bool(e.sus):
			e.phase = "rel"
			e.rel = maxf(secs, 0.05) / 2.5
	_act.append({"id": id, "i": 0.0 if secs > 0.0 else intensity, "peak": clampf(intensity, 0.0, 1.0), "att": maxf(secs, 0.001) / 2.5,
		"hold": INF, "rel": 0.3, "t": 0.0, "phase": "att", "src": null, "sus": true})
	mood_id = id


## Gefühlsreaktion: steigt in attack s an, hält hold s, klingt in release s ab; Werte < 0 = aus META/Persönlichkeit.
## Ein bereits aktives Gefühl gleichen Namens wird verstärkt statt verdoppelt.
func trigger(id: String, intensity := 1.0, hold := -1.0, attack := -1.0, release := -1.0, source: Variant = null) -> void:
	var m := meta(id)
	var a := float(m.get("a", 0.4))
	var imp := personality.impulsivity
	var peak := clampf(intensity * personality.intensity_scale(), 0.0, 1.0)
	var att := (attack if attack >= 0.0 else lerpf(0.45, 0.07, a) * lerpf(1.35, 0.65, imp)) / 2.5
	var hl := hold if hold >= 0.0 else float(m.get("hold", lerpf(2.4, 1.0, a))) * lerpf(0.8, 1.3, personality.emotionality)
	var rl := (release if release >= 0.0 else lerpf(1.2, 0.45, a)) / 2.5
	for e in _act:
		if String(e.id) == id and not bool(e.sus) and String(e.phase) != "rel":
			e.peak = maxf(float(e.peak), peak)
			e.hold = maxf(float(e.hold) - float(e.t), hl)
			e.t = 0.0
			triggered.emit(id, peak, source)
			return
	_act.append({"id": id, "i": 0.0, "peak": peak, "att": maxf(att, 0.004), "hold": hl, "rel": maxf(rl, 0.02), "t": 0.0,
		"phase": "att", "src": source, "sus": false})
	triggered.emit(id, peak, source)


## Gefühl beenden (leer = alle Reaktionen; die Stimmung bleibt).
func clear(id := "") -> void:
	for e in _act:
		if (id == "" and not bool(e.sus)) or String(e.id) == id:
			e.phase = "rel"


func intensity_of(id: String) -> float:
	var v := 0.0
	for e in _act:
		if String(e.id) == id:
			v = maxf(v, float(e.i))
	return v


func dominant() -> String:
	return _dom


func dominant_intensity() -> float:
	return intensity_of(_dom)


## Stärkste laufende Reaktion (nicht die Stimmung): [name, Stärke] – Cartoon-Übertreibungen entstehen nur aus
## Reaktionen auf Ereignisse, nie aus einer bewusst gesetzten Stimmung.
func strongest_reaction() -> Array:
	var best := ["", 0.0]
	for e in _act:
		if not bool(e.sus) and float(e.i) > float(best[1]):
			best = [String(e.id), float(e.i)]
	return best


## [[name, intensity], …] der wirksamen Gefühle (für Tests und Wahrnehmung anderer).
func active() -> Array:
	var out: Array = []
	for e in _act:
		if float(e.i) > 0.02:
			out.append([String(e.id), float(e.i)])
	return out


func update(dt: float) -> void:
	# Hüllkurven
	var spawn: Array = []
	for e in _act:
		e.t = float(e.t) + dt
		match String(e.phase):
			"att":
				e.i = lerpf(float(e.i), float(e.peak), 1.0 - exp(-dt / float(e.att)))
				if float(e.t) > float(e.att) * 3.0:
					e.phase = "hold"
					e.t = 0.0
			"hold":
				e.i = lerpf(float(e.i), float(e.peak), 1.0 - exp(-dt / 0.08))
				if float(e.t) >= float(e.hold):
					e.phase = "rel"
					e.t = 0.0
					var m := meta(String(e.id))
					if String(m.get("after", "")) != "":
						spawn.append([String(m.after), float(e.peak) * float(m.get("ai", 0.5)), e.src])
			"rel":
				e.i = float(e.i) * exp(-dt / float(e.rel))
	_act = _act.filter(func(x: Dictionary) -> bool: return String(x.phase) != "rel" or float(x.i) > 0.015)
	for s in spawn:   # Nachwirkung blendet über, während das alte Gefühl abklingt
		trigger(String(s[0]), float(s[1]) / maxf(personality.intensity_scale(), 0.01), -1.0, 0.6, 1.2, s[2])
	_mix()


func _mix() -> void:
	var gain := personality.expressiveness()
	var acc := {}
	var mx := {}
	for k: String in keys:
		acc[k] = 0.0
		mx[k] = float(_base[k])
	var wsum := 0.0
	var post := Vector4.ZERO
	var blink := 0.0
	var val := 0.0
	var aro := 0.0
	var best := ""
	var best_w := 0.0
	var gest: Array = []
	var breath: Array = []
	var br_w := 0.0
	# Mischung: gewichteter Mittelwert der nach Stärke skalierten Ausschläge – ein Gefühl allein wirkt mit seiner
	# Stärke, mehrere teilen sich das Gesicht (Reaktionen wiegen 1,6-fach gegen die Stimmung). „neutral“ ist die
	# Abwesenheit von Gefühl und verdünnt nichts.
	for e in _act:
		var i := float(e.i)
		var id := String(e.id)
		if i < 0.01 or id == "neutral":
			continue
		var w := i * (1.0 if bool(e.sus) else 1.6)
		var ex: Dictionary = expressions.get(id, {})
		for k: String in keys:
			var b := float(_base[k])
			var v := float(ex.get(k, 1.0 if k in ["width", "pupil"] else 0.0))   # fehlender Schlüssel = Grundwert (wie im Gesicht)
			if k in MAX_KEYS:
				mx[k] = maxf(float(mx[k]), b + (v - b) * i * gain)
			else:
				acc[k] = float(acc[k]) + (v - b) * i * w
		var p: Array = postures.get(id, postures.get("neutral", [0.0, 0.0, 0.0, 0.0]))
		post += Vector4(float(p[0]), float(p[1]), float(p[2]), float(p[3])) * i * w
		var m := meta(id)
		blink += float(m.get("b", 1.0)) * w
		val += float(m.get("v", 0.0)) * w
		aro += float(m.get("a", 0.4)) * w
		wsum += w
		if w > best_w:
			best_w = w
			best = id
		if i > 0.35:
			for g: String in m.get("x", []):
				if not (g in gest):
					gest.append(g)
		var bri := i * float(m.get("a", 0.4))
		if m.has("br") and bri > br_w:
			br_w = bri
			breath = m.br
	var n := maxf(wsum, 0.0001)
	for k: String in keys:
		if k in MAX_KEYS:
			face_out[k] = float(mx[k])
		else:
			face_out[k] = float(_base[k]) + float(acc[k]) / n * gain
	posture_out = post / n * gain + personality.posture()
	var dm := meta(best)
	mods.blink = blink / wsum if wsum > 0.0 else 1.0
	mods.valence = val / wsum if wsum > 0.0 else 0.0
	mods.arousal = aro / wsum if wsum > 0.0 else 0.2
	mods.gaze = String(dm.get("g", ""))
	mods.gest = gest
	mods.breath = breath
	mods.mouth = String(dm.get("m", "")) if intensity_of(best) > 0.4 else ""
	mods.cartoon = String(dm.get("c", ""))
	mods.cartoon_i = intensity_of(best)
	if best == "":
		best = "neutral"
	if best != _dom:
		_dom = best
		changed.emit(best)
