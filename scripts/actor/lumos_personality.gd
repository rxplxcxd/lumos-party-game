class_name LumosPersonality
extends Resource
## Persönlichkeit einer Figur – zehn Züge von 0 bis 1 (0,5 = durchschnittlich). Sie verändern nicht WAS eine Figur
## kann, sondern WIE: Blickverhalten, Gestengröße, Haltung, Reaktionszeit, Gefühlsstärke, Kontaktfreude und die
## Neigung zu Cartoon-Übertreibungen. Keine Sonderlösungen je Figur: Werte aus Vorlagen (PRESETS) oder frei gesetzt.

@export_range(0.0, 1.0) var energy := 0.5         ## Antrieb, Tempo, Größe der Bewegungen
@export_range(0.0, 1.0) var playfulness := 0.5    ## Verspieltheit, Lust an Übertreibung
@export_range(0.0, 1.0) var confidence := 0.5     ## Selbstbewusstsein: direkter Blick, aufrechte Haltung, große Gesten
@export_range(0.0, 1.0) var shyness := 0.3        ## Schüchternheit: Blick ausweichen, kleiner werden
@export_range(0.0, 1.0) var friendliness := 0.6   ## Freundlichkeit: trösten, lächeln, helfen
@export_range(0.0, 1.0) var curiosity := 0.5      ## Neugier: schaut sich mehr um, beobachtet Dinge
@export_range(0.0, 1.0) var impulsivity := 0.5    ## Reaktionsgeschwindigkeit, schnelle Gefühlswechsel
@export_range(0.0, 1.0) var emotionality := 0.5   ## Stärke der Gefühle
@export_range(0.0, 1.0) var humor := 0.5          ## lacht mit, nimmt Missgeschicke mit Humor
@export_range(0.0, 1.0) var sociability := 0.6    ## sucht Kontakt, schließt sich an

const TRAITS := ["energy", "playfulness", "confidence", "shyness", "friendliness", "curiosity", "impulsivity",
	"emotionality", "humor", "sociability"]

## Vorlagen (nur Abweichungen vom Durchschnitt). Eigene Vorlagen: PRESETS-Kopie erweitern oder Werte direkt setzen.
const PRESETS := {
	"balanced": {},
	"brave": {"confidence": 0.8, "friendliness": 0.75, "energy": 0.6, "shyness": 0.12, "humor": 0.6, "sociability": 0.7},
	"curious": {"curiosity": 0.9, "playfulness": 0.75, "emotionality": 0.75, "friendliness": 0.8, "energy": 0.65, "shyness": 0.2},
	"boisterous": {"energy": 0.9, "impulsivity": 0.85, "humor": 0.85, "confidence": 0.75, "playfulness": 0.8, "shyness": 0.05,
		"emotionality": 0.7},
	"dreamy": {"energy": 0.3, "shyness": 0.55, "curiosity": 0.75, "impulsivity": 0.25, "emotionality": 0.6, "sociability": 0.45,
		"confidence": 0.35},
	"shy": {"shyness": 0.9, "confidence": 0.2, "sociability": 0.3, "energy": 0.4, "impulsivity": 0.35},
	"calm": {"energy": 0.25, "impulsivity": 0.15, "emotionality": 0.25, "playfulness": 0.3, "confidence": 0.6},
	"pet": {"energy": 0.85, "playfulness": 0.9, "curiosity": 0.85, "impulsivity": 0.8, "friendliness": 0.9, "sociability": 0.9,
		"emotionality": 0.8, "shyness": 0.15},
}


static func preset(name: String) -> LumosPersonality:
	var p := LumosPersonality.new()
	var d: Dictionary = PRESETS.get(name, {})
	for k: String in d:
		p.set(k, float(d[k]))
	return p


func to_dict() -> Dictionary:
	var d := {}
	for k: String in TRAITS:
		d[k] = float(get(k))
	return d


## Verzögerung bis zur Reaktion auf ein Ereignis (s): impulsiv schnell, ruhig langsam – mit Streuung.
func reaction_delay(rng: RandomNumberGenerator) -> float:
	return lerpf(0.62, 0.14, impulsivity) * rng.randf_range(0.75, 1.4)


## Faktor für die Stärke eines ausgelösten Gefühls.
func intensity_scale() -> float:
	return lerpf(0.65, 1.3, emotionality) * lerpf(0.88, 1.12, energy)


## Wie offen Gefühle gezeigt werden (Mimik- und Haltungsausschlag): ruhige und schüchterne Figuren subtiler.
func expressiveness() -> float:
	return clampf(lerpf(0.7, 1.18, energy * 0.4 + confidence * 0.25 + playfulness * 0.35) * lerpf(1.0, 0.85, shyness), 0.55, 1.25)


func gesture_scale() -> float:
	return lerpf(0.72, 1.28, (confidence + energy) * 0.5)


## Wie lange Blickkontakt gehalten wird (s), bevor der Blick bricht.
func eye_contact_time(rng: RandomNumberGenerator) -> float:
	return lerpf(2.4, 0.45, shyness) * lerpf(0.8, 1.3, confidence) * rng.randf_range(0.7, 1.3)


## Wahrscheinlichkeit, einem Blick auszuweichen (nach unten/zur Seite) statt ihn zu erwidern.
func avert_chance() -> float:
	return clampf(shyness * 0.8 + (1.0 - confidence) * 0.2, 0.0, 0.95)


## Neigung zu Cartoon-Übertreibungen (0..1).
func cartoon_bias() -> float:
	return (playfulness * 0.45 + energy * 0.3 + emotionality * 0.25)


## Ansteckung durch Lachen und Freude anderer (0..1).
func contagion() -> float:
	return clampf(humor * 0.45 + sociability * 0.3 + friendliness * 0.25, 0.0, 1.0)


## Häufigkeit kleiner Gesten und Unruhe (Faktor um 1).
func fidget_rate() -> float:
	return lerpf(0.55, 1.6, energy * 0.5 + shyness * 0.25 + (1.0 - confidence) * 0.25)


## Grundhaltung (Brust vor, Kopf, Schultern, Neigung – wie LumosBody.POSTURE): selbstbewusst aufrecht, schüchtern klein.
func posture() -> Vector4:
	var c := confidence - 0.5
	var s := shyness - 0.3
	return Vector4(-0.1 * c + 0.08 * s, -0.12 * c + 0.12 * s, -0.04 * c + 0.06 * s, 0.0)
