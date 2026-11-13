extends Node
## Durchdringungsprüfung des Trailers: spielt ihn ohne Grafik ab (feste Bildrate) und misst je Bild den kleinsten
## Abstand der festen Körperteile (Köpfe mit Helm/Kapuze, Rümpfe – LumosActor.clearance) zwischen allen sichtbaren
## Figuren-Paaren. Ausgabe: jede Zeitspanne unter der Toleranz, mit Figuren und tiefstem Wert.
##
##   godot --headless --fixed-fps 60 --path . res://trailer/ClearanceProbe.tscn [-- --trailer-from=s] [--detail]
##     [--watch=von-bis]   (je Bild alle nahen Paare mit Kopflage relativ zur Wurzel, Ausweichen, Haltungszusätzen
##                          und dem kleinsten Abstand der Hände beider Figuren – prüft, ob Berührungen wirklich ankommen)
## Ende: „CLEARANCE OK“ oder „CLEARANCE FEHLER: n Spannen“ (Exit 0/1).

const TOL := -0.03
var tr: Node
var _bad := {}      # Paar → [Start, Ende, tiefster Wert, Zeit des tiefsten]
var _spans: Array = []
var _worst := INF
var _worst_at := ""
var _last_t := -1.0
var _watch := Vector2(-1.0, -1.0)


func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--watch="):
			var p := a.substr(8).split("-")
			if p.size() == 2:
				_watch = Vector2(p[0].to_float(), p[1].to_float())


func _ready() -> void:
	tr = load("res://trailer/Trailer.tscn").instantiate()
	add_child(tr)


func _process(_d: float) -> void:
	if tr == null or not ("t" in tr):
		return
	var t: float = tr.get("t")
	var actors: Array = tr.get("actors")
	if t < _last_t - 1.0 or t >= 97.2:
		_finish()
		return
	_last_t = t
	var seen := {}
	for i in actors.size():
		for j in range(i + 1, actors.size()):
			var a: LumosActor = actors[i]
			var b: LumosActor = actors[j]
			if not is_instance_valid(a) or not is_instance_valid(b) or not a.rig.is_visible_in_tree() or not b.rig.is_visible_in_tree():
				continue
			if a.rig.global_position.distance_to(b.rig.global_position) > 2.5:
				continue
			var c := LumosActor.clearance(a, b)
			var key := "%s+%s" % [a.rig.model_key.get_file(), b.rig.model_key.get_file()]
			if t >= _watch.x and t <= _watch.y and (c < 0.1 or _hands(a, b) < 0.3):
				print("[WATCH] %.2f %s %4.0f mm · Hände %3.0f mm · %s · %s" % [t, key, c * 1000.0, _hands(a, b) * 1000.0, _pose(a), _pose(b)])
			if c < _worst:
				_worst = c
				_worst_at = "%.2f s %s" % [t, key]
			if c < TOL:
				seen[key] = true
				if not _bad.has(key):
					_bad[key] = [t, t, INF, t, ""]
				var e: Array = _bad[key]
				e[1] = t
				if c < float(e[2]):
					e[2] = c
					e[3] = t
					e[4] = _closest(a, b)
	for key: String in _bad.keys():
		if not seen.has(key):
			var sp: Array = [key] + (_bad[key] as Array)
			_spans.append(sp)
			_print_span(sp)   # sofort ausgeben: der Trailer beendet sich nach dem Abspann selbst
			_bad.erase(key)


func _print_span(s: Array) -> void:
	print("[CLEARANCE] %5.2f–%5.2f s  %-20s tiefster Wert %4.0f mm bei %.2f s" % [s[1], s[2], s[0], float(s[3]) * 1000.0, s[4]])
	if OS.get_cmdline_user_args().has("--detail"):
		print("[CLEARANCE]      " + String(s[5]))


## Engstes Paar der Hüllkörper: Art, Mitte, Radien entlang der Verbindung (für die Fehlersuche).
static func _closest(a: LumosActor, b: LumosActor) -> String:
	var best := INF
	var txt := ""
	for va: Array in a.volumes():
		for vb: Array in b.volumes():
			var d: Vector3 = (vb[0] as Vector3) - (va[0] as Vector3)
			var l := maxf(d.length(), 0.0001)
			var ra := LumosActor._radius_along(va, d / l)
			var rb := LumosActor._radius_along(vb, -d / l)
			if l - ra - rb < best:
				best = l - ra - rb
				txt = "%s %s Wurzel %s Mitte %s r %.2f · %s %s Wurzel %s Mitte %s r %.2f · Abstand %.2f" % [
					a.rig.model_key.get_file(), va[3], _v(a.rig.global_position), _v(va[0]), ra,
					b.rig.model_key.get_file(), vb[3], _v(b.rig.global_position), _v(vb[0]), rb, l]
	return txt


## Kleinster Abstand zwischen einer Hand von a und einer Hand von b (Handgelenk-Gelenkpunkte).
static func _hands(a: LumosActor, b: LumosActor) -> float:
	if a.body == null or b.body == null:
		return INF
	var best := INF
	for ha: String in ["hand.l", "hand.r"]:
		for hb: String in ["hand.l", "hand.r"]:
			best = minf(best, a.body.joint_pos(ha).distance_to(b.body.joint_pos(hb)))
	return best


## Kopf relativ zur Wurzel in den Achsen der Figur (rechts, oben, vorn) und die Haltungszusätze.
static func _pose(a: LumosActor) -> String:
	if a.body == null or a.volumes().is_empty():
		return a.rig.model_key.get_file()
	var hv: Vector3 = (a.volumes()[0] as Array)[0]
	var fw := a.forward()
	var rt := fw.cross(Vector3.UP).normalized()
	var o := hv - a.rig.global_position
	return "%s Kopf r%+.2f o%.2f v%+.2f avoid %s chest %s head %s" % [a.rig.model_key.get_file(), o.dot(rt), o.y, o.dot(fw),
		_v(a.body.avoid), _v(a.body.chest_add), _v(a.body.head_add)]


static func _v(p: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z]


func _finish() -> void:
	for key: String in _bad:
		var sp: Array = [key] + (_bad[key] as Array)
		_spans.append(sp)
		_print_span(sp)
	_bad.clear()
	print("[CLEARANCE] kleinster Abstand im ganzen Trailer: %.0f mm (%s)" % [_worst * 1000.0, _worst_at])
	print("CLEARANCE OK" if _spans.is_empty() else "CLEARANCE FEHLER: %d Spannen" % _spans.size())
	get_tree().quit(0 if _spans.is_empty() else 1)
	set_process(false)
