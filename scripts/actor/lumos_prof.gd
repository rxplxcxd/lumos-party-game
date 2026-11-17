class_name LumosProf
extends RefCounted
## Messpunkte des Performance-Labors (tools/charlab/perf_lab.gd). Im Normalbetrieb aus: Jeder Messpunkt kostet
## dann nur das Lesen von LumosProf.on. Eingeschaltet summiert er die CPU-Zeit (Mikrosekunden) je Abschnitt und
## Bild auf; das Labor holt die Summen nach jedem Bild mit take() ab.
##
## Abschnitte (verschachtelt; „actor“ enthält alle actor.*-Abschnitte):
##   actor            gesamte LumosActor._process-Fassade (LOD, Geschwindigkeit, alle Teilsysteme unten)
##   actor.mind       Mind: Ereignisse auswerten, zeitversetzte Reaktionen, periodische Cartoon-/Mundaktionen
##   actor.micro      Mikroleben: Blicke, Gewichtsverlagerung, Kopf-Mikrobewegung, persönlicher Abstand
##   actor.gesture    davon Gesten-Engine (Auswahl und Ablauf der Gesten)
##   actor.hat        Hutkrempe weicht nahen Köpfen aus
##   actor.apart      Kopf/Oberkörper weichen nahen Körpern aus, vorausschauend (Durchdringungsschutz)
##   actor.emotion    Gefühlszustand mischen und auf Gesicht/Haltung/Atem anwenden (inkl. Persönlichkeit)
##   actor.gaze       Blicksteuerung (Augen, Kopf, Oberkörper)
##   actor.hands      Lachen und Hand-Ziele (Greifen, Regie, Gesten)
##   actor.interact   Gegenstände halten/tragen (LumosInteract)
##   actor.rigid      Figuren ohne Skelett (Schwanz, Beine, Zittern)
##   social.perceive  Wahrnehmung (einmal je Figur und Bild berechnet, danach aus dem Zwischenspeicher)
##   social.hub       sozialer Knoten: Interaktionsprotokoll weiterschalten
##   interaction      davon LumosInteraction.tick (Phasen, Kontakte)
##   face             LumosFace: Ausdruck überblenden, Lidschlag, Sprechen, Signatur
##   face.draw        davon Gesicht neu zeichnen (ImmediateMesh)
##   body             LumosBody._process_modification gesamt (Skelett-Modifikation)
##   body.dyn         davon Gewicht/Trägheit (Federn)
##   body.arms        davon Arm-IK und Handausrichtung
##   body.feet        davon Fußanker, Becken
##   body.jiggle      davon Zubehör-Nachschwingen (Hut, Haare, Taschen)
##   loco             LumosLocomotion (Schritt-Synchronisierung, Clip-Auswahl)

static var on := false
static var _acc := {}


static func add(section: StringName, t0: int) -> void:
	_acc[section] = int(_acc.get(section, 0)) + Time.get_ticks_usec() - t0


## Abschnitt bis jetzt verbuchen und die neue Startzeit zurückgeben (für aufeinanderfolgende Abschnitte).
static func lap(section: StringName, t0: int) -> int:
	var t := Time.get_ticks_usec()
	_acc[section] = int(_acc.get(section, 0)) + t - t0
	return t


## Summen des letzten Bilds (Mikrosekunden je Abschnitt) abholen und zurücksetzen.
static func take() -> Dictionary:
	var d := _acc
	_acc = {}
	return d
