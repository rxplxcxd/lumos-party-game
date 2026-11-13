class_name LumosLayers
extends RefCounted
## Zentrale Schicht- und Prioritätssteuerung einer Figur. Jede Handlung (Mikrogeste, soziale Reaktion, Cartoon,
## Interaktion, Regie, Reflex) beansprucht die Kanäle, die sie bewegt. Höhere Priorität übersteuert niedrigere
## kontrolliert: Die verdrängte Handlung bekommt einen Rückruf und beendet sich sauber (Hände lösen, Haltung zurück).
## Gleiche oder niedrigere Priorität wird abgelehnt – so kann eine Figur nicht zugleich erschrocken zurückspringen,
## jemanden umarmen und ruhig etwas übergeben, solange das nicht bewusst koordiniert ist (ein Besitzer, viele Kanäle).
##
## Ebenen (Reihenfolge der Wirkung, unten → oben): Basisbewegung · Lokomotion · Gewicht/Balance · Haltung · Kopf/Blick
## · Gesicht/Gefühl · Arme/Hände · Interaktion · Sekundärbewegung · Cartoon · Effekte. Kanäle sind die Stellen, an
## denen sich Handlungen in die Quere kommen könnten; Gewicht, Sekundärbewegung und Effekte wirken immer additiv.

const P_IDLE := 0
const P_MICRO := 10       ## Mikrogesten, Blicke ins Leere
const P_SOCIAL := 20      ## Reaktionen auf andere (Mitlachen, Zurückwinken, Hinschauen)
const P_EMOTE := 30       ## Cartoon-Reaktionen, große Gefühlsausbrüche
const P_INTERACT := 40    ## Interaktionsprotokoll (Umarmung, High-Five, Übergabe …)
const P_SCRIPT := 50      ## Regie (Trailer, Zwischensequenzen, Spiel-Logik)
const P_REFLEX := 60      ## Reflexe (Schreck-Sprung, Treffer)

const CHANNELS := ["root", "legs", "torso", "head", "eyes", "face", "arm.l", "arm.r"]

var _own := {}            # Kanal → [Besitzer, Priorität]
var _cb := {}             # Besitzer → Callable bei Verdrängung
var stats := {"granted": 0, "denied": 0, "preempted": 0, "double": 0}


## Kanäle beanspruchen. true = erteilt (niedrigere Besitzer wurden verdrängt), false = abgelehnt.
func claim(owner: String, channels: Array, prio: int, on_preempt := Callable()) -> bool:
	for c: String in channels:
		if _own.has(c):
			var o: Array = _own[c]
			if String(o[0]) != owner and int(o[1]) >= prio:
				stats.denied = int(stats.denied) + 1
				return false
	var gone := {}
	for c: String in channels:
		if _own.has(c) and String((_own[c] as Array)[0]) != owner:
			gone[String((_own[c] as Array)[0])] = true
	for o: String in gone:
		_preempt(o)
	for c: String in channels:
		_own[c] = [owner, prio]
	if on_preempt.is_valid():
		_cb[owner] = on_preempt
	stats.granted = int(stats.granted) + 1
	return true


## Wäre ein Anspruch erfolgreich? (ohne etwas zu ändern)
func can_claim(channels: Array, prio: int, owner := "") -> bool:
	for c: String in channels:
		if _own.has(c):
			var o: Array = _own[c]
			if String(o[0]) != owner and int(o[1]) >= prio:
				return false
	return true


func release(owner: String) -> void:
	for c: String in _own.keys():
		if String((_own[c] as Array)[0]) == owner:
			_own.erase(c)
	_cb.erase(owner)


func owner_of(channel: String) -> String:
	return String((_own[channel] as Array)[0]) if _own.has(channel) else ""


func prio_of(channel: String) -> int:
	return int((_own[channel] as Array)[1]) if _own.has(channel) else -1


func is_free(channel: String) -> bool:
	return not _own.has(channel)


func owners() -> Dictionary:
	var d := {}
	for c: String in _own:
		d[c] = (_own[c] as Array)[0]
	return d


func _preempt(owner: String) -> void:
	var cb: Callable = _cb.get(owner, Callable())
	release(owner)
	stats.preempted = int(stats.preempted) + 1
	if cb.is_valid():
		cb.call()
