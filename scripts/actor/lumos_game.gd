class_name LumosGame
## Spiel-Anbindung des Character Frameworks – an einer Stelle, damit jeder Einsatz im Spiel gleich aussieht und
## sich gemeinsam abschalten lässt. Schrittweise (docs/CHARACTER_FRAMEWORK.md, „Einsatz im Spiel“):
##   1. Figuren-Insel im Hauptmenü: Gesichter, Mikroleben, Blicke, Reaktionen auf Antippen
##   2. Siegerehrung (Podest von Party, Grand Prix und weiteren Modi): Freude, Stolz, Enttäuschung, Verlegenheit
## Spielabläufe, Steuerung, Physik und Kollisionen bleiben unberührt: Das Framework färbt nur Gesicht, Haltung, Blick
## und Mikroleben der normalen Spiel-Animation ein. Nur Figuren, die eigens für die Szene entstehen (kein Gesicht
## „ploppt“ mitten in einer Einstellung auf). Aus: Einstellung „Lebendige Mimik“ oder Grafikstufe „Niedrig“.

const AUTONOMY := 0.35   ## Mikroleben und dezente Reaktionen; keine Ortswechsel (Trösten/Helfen bleiben Regie)

## Wie Spiel-Reaktionen (CharacterRig.react) als Gefühl aussehen
const FROM_REACTION := {
	"wave": ["joy", 0.6], "cheer": ["delight", 0.9], "victory": ["delight", 1.0], "shocked": ["surprise", 0.9],
	"scared": ["scared", 0.8], "confused": ["confused", 0.8], "sleepy": ["sleepy", 0.8], "flex": ["pride", 0.9],
	"taunt": ["smug", 0.9], "tantrum": ["anger", 0.9], "dizzy": ["dizzy", 0.9], "sad": ["sad", 0.8],
	"frustrated": ["frustrated", 0.8], "trip_fall": ["surprise", 1.0], "launch": ["surprise", 1.0],
	"star_get": ["delight", 1.0],
}


static func enabled() -> bool:
	if not bool(Game.settings.get("lively_faces", true)):
		return false
	return Gfx.active != "low"


## Framework an eine Figur hängen. null = abgeschaltet oder Modell ohne passendes Skelett (eigene Lumos-Avatare
## sind noch nicht geprüft und bleiben deshalb ohne Framework).
static func attach(rig: CharacterRig, autonomy := AUTONOMY) -> LumosActor:
	if not enabled() or rig == null or not is_instance_valid(rig) or rig.model_key.begins_with("custom/"):
		return null
	var cfg := LumosActorConfig.detect(rig)
	if cfg.profile == "rigid":
		return null
	cfg.autonomy = autonomy
	return LumosActor.attach(rig, cfg)


## Stimmung setzen (bleibt), falls die Figur das Framework trägt.
static func feel(rig: Node, mood: String, intensity := 1.0) -> void:
	var a := LumosActor.of(rig)
	if a and a.enabled:
		a.feel(mood, 0.25, intensity)


## Kurze Gefühlsreaktion (steigt an, hält, klingt ab), falls die Figur das Framework trägt.
static func react(rig: Node, id: String, intensity := 0.9) -> void:
	var a := LumosActor.of(rig)
	if a and a.enabled:
		a.react(id, intensity)


## Passendes Gefühl zu einer Spiel-Reaktion (CharacterRig.react) auslösen; „laugh“ lacht wirklich.
static func mirror(rig: Node, reaction_id: String) -> void:
	var a := LumosActor.of(rig)
	if a == null or not a.enabled:
		return
	if reaction_id == "laugh":
		a.laugh(1.4)
		return
	var m: Array = FROM_REACTION.get(reaction_id, [])
	if not m.is_empty():
		a.react(String(m[0]), float(m[1]))
