class_name RtdbClient
extends Node
## Zugriff auf die Firebase Realtime Database mit einheitlicher Ereignis-Schnittstelle.
##   Web:   über web/lumos_bridge.js (Firebase-SDK, Push-Ereignisse in Echtzeit)
##   Nativ: REST (https://…/path.json?auth=TOKEN); Abos werden per Polling mit Differenzbildung umgesetzt.

signal child(tag: String, ev: String, key: String, value: Variant)   # ev: added | changed | removed
signal value(tag: String, val: Variant)
signal done(tag: String)
signal created(tag: String, ok: bool)
signal failed(tag: String, message: String)

const DB_URL := preload("res://scripts/net/firebase_config.gd").DATABASE_URL

var web := OS.has_feature("web")
var db_url := OS.get_environment("LUMOS_RTDB_URL") if OS.get_environment("LUMOS_RTDB_URL") != "" else DB_URL
var _polls: Dictionary = {}     # tag -> {path, interval, t, last: Dictionary, busy}


func _ready() -> void:
	if web:
		Account.bridge_event.connect(_on_bridge)


func _js(code: String) -> void:
	JavaScriptBridge.eval(code, true)


func _on_bridge(type: String, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var d: Dictionary = data
	match type:
		"db_child":
			child.emit(String(d.get("tag", "")), String(d.get("ev", "")), String(d.get("key", "")), d.get("value"))
		"db_value":
			value.emit(String(d.get("tag", "")), d.get("value"))
		"db_done":
			done.emit(String(d.get("tag", "")))
		"db_created":
			created.emit(String(d.get("tag", "")), bool(d.get("ok", false)))
		"db_error":
			failed.emit(String(d.get("tag", "")), String(d.get("message", "Fehler")))


# --- Schreiben -------------------------------------------------------------------------------------------

func set_value(path: String, v: Variant, tag := "") -> void:
	if web:
		_js("LumosBridge.dbSet(%s, %s, %s)" % [JSON.stringify(path), JSON.stringify(JSON.stringify(v) if v != null else ""), JSON.stringify(tag)])
		return
	var r := await _rest(HTTPClient.METHOD_PUT, path, JSON.stringify(v))
	if tag != "":
		if r.ok:
			done.emit(tag)
		else:
			failed.emit(tag, "HTTP %d" % r.code)


func update(path: String, d: Dictionary, tag := "") -> void:
	if web:
		_js("LumosBridge.dbUpdate(%s, %s, %s)" % [JSON.stringify(path), JSON.stringify(JSON.stringify(d)), JSON.stringify(tag)])
		return
	var r := await _rest(HTTPClient.METHOD_PATCH, path, JSON.stringify(d))
	if tag != "" and r.ok:
		done.emit(tag)


func push(path: String, d: Dictionary) -> void:
	if web:
		_js("LumosBridge.dbPush(%s, %s)" % [JSON.stringify(path), JSON.stringify(JSON.stringify(d))])
		return
	d["t"] = {".sv": "timestamp"}
	await _rest(HTTPClient.METHOD_POST, path, JSON.stringify(d))


func remove(path: String) -> void:
	if web:
		_js("LumosBridge.dbSet(%s, '', '')" % JSON.stringify(path))
		return
	await _rest(HTTPClient.METHOD_DELETE, path, "")


func remove_on_disconnect(path: String) -> void:
	if web:
		_js("LumosBridge.dbRemoveOnDisconnect(%s)" % JSON.stringify(path))
	# Nativ: kein onDisconnect über REST – der Host räumt verwaiste Einträge per Zeitstempel auf.


func create_if_absent(path: String, v: Dictionary, tag: String) -> void:
	if web:
		_js("LumosBridge.dbCreateIfAbsent(%s, %s, %s)" % [JSON.stringify(path), JSON.stringify(JSON.stringify(v)), JSON.stringify(tag)])
		return
	var cur := await _rest(HTTPClient.METHOD_GET, path, "")
	if cur.ok and cur.json == null:
		var w := await _rest(HTTPClient.METHOD_PUT, path, JSON.stringify(v))
		created.emit(tag, w.ok)
	else:
		created.emit(tag, false)


# --- Lesen & Abos ------------------------------------------------------------------------------------------

func get_value(path: String, tag: String) -> void:
	if web:
		_js("LumosBridge.dbGet(%s, %s)" % [JSON.stringify(path), JSON.stringify(tag)])
		return
	var r := await _rest(HTTPClient.METHOD_GET, path, "")
	if r.ok:
		value.emit(tag, r.json)
	else:
		failed.emit(tag, "HTTP %d" % r.code)


func listen(path: String, tag: String, poll_interval := 0.25) -> void:
	if web:
		_js("LumosBridge.dbListen(%s, %s)" % [JSON.stringify(path), JSON.stringify(tag)])
		return
	_polls[tag] = {"path": path, "interval": poll_interval, "t": 0.0, "last": {}, "busy": false}


func off(tag: String) -> void:
	if web:
		_js("LumosBridge.dbOff(%s)" % JSON.stringify(tag))
		return
	_polls.erase(tag)


func off_all() -> void:
	for tag in _polls.keys():
		off(tag)
	_polls.clear()


func _process(delta: float) -> void:
	if web:
		return
	for tag in _polls.keys():
		var p: Dictionary = _polls[tag]
		p.t = float(p.t) - delta
		if float(p.t) <= 0.0 and not bool(p.busy):
			p.t = float(p.interval)
			_poll(tag)


func _poll(tag: String) -> void:
	var p: Dictionary = _polls.get(tag, {})
	if p.is_empty():
		return
	p.busy = true
	var r := await _rest(HTTPClient.METHOD_GET, String(p.path), "")
	if not _polls.has(tag):
		return
	p.busy = false
	if not r.ok:
		return
	var now: Dictionary = r.json if r.json is Dictionary else {}
	var last: Dictionary = p.last
	for k in now:
		if not last.has(k):
			child.emit(tag, "added", String(k), now[k])
		elif JSON.stringify(last[k]) != JSON.stringify(now[k]):
			child.emit(tag, "changed", String(k), now[k])
	for k in last:
		if not now.has(k):
			child.emit(tag, "removed", String(k), null)
	p.last = now


## REST-Anfrage mit Wiederholung: Bei Funklöchern/Serverfehlern (kein Ergebnis, 5xx, 429) bis zu dreimal neu
## versuchen (0,4 s / 0,8 s / 1,6 s). Vorher ging eine gescheiterte Nachricht (Zug-Entscheidung, Spielstand)
## einfach verloren – auf Mobilfunk führte das zu Wartezeiten bis zum 60-s-Timeout. Lesen (Abfragen) läuft ohnehin
## im Takt und wird nicht wiederholt.
func _rest(method: int, path: String, body: String) -> Dictionary:
	var r := await _rest_once(method, path, body)
	if method == HTTPClient.METHOD_GET:
		return r
	var wait := 0.4
	for attempt in 3:
		if r.ok or (int(r.code) >= 400 and int(r.code) < 500 and int(r.code) != 429):
			return r   # Erfolg oder echter Client-Fehler (z. B. keine Berechtigung): nicht wiederholen
		await get_tree().create_timer(wait, true, false, true).timeout
		wait *= 2.0
		r = await _rest_once(method, path, body)
	return r


func _rest_once(method: int, path: String, body: String) -> Dictionary:
	var tok: String = await Account.fb_token()
	var url := "%s/%s.json%s" % [db_url, path.trim_prefix("/"), ("?auth=" + tok) if tok != "" else ""]
	var req := HTTPRequest.new()
	req.timeout = 30.0   # langsame Verbindungen/Geräte: nicht vorschnell abbrechen
	add_child(req)
	var err := req.request(url, PackedStringArray(["Content-Type: application/json"]), method, body)
	if err != OK:
		req.queue_free()
		return {"ok": false, "code": 0, "json": null}
	var res: Array = await req.request_completed
	req.queue_free()
	var text := (res[3] as PackedByteArray).get_string_from_utf8()
	return {"ok": res[0] == HTTPRequest.RESULT_SUCCESS and int(res[1]) < 300, "code": int(res[1]), "json": JSON.parse_string(text) if text != "" else null}
