extends Node
## Online-Mehrspieler für bis zu 4 Geräte (Smartphones, PCs, Lumos One).
##
## Signaling: Firebase Realtime Database unter /rooms/{roomCode}
##   rooms/{code}/meta        {host, created, state: lobby|playing, cfg}
##   rooms/{code}/players/{id} {name, hero, slot, ready, t}
##   rooms/{code}/signal/{to}/{push} {from, type: offer|answer|ice, sdp | mid,idx,cand}
##   rooms/{code}/relay/{to}/{push}  {from, d}    – Fallback-Transport ohne WebRTC
##
## Transport: Stern-Topologie. Jeder Client baut eine WebRTC-Verbindung zum Host auf (zwei
## ausgehandelte Datenkanäle: zuverlässig/geordnet für Ereignisse, unzuverlässig/ungeordnet für
## Zustände mit 20–30 Hz). Der Host leitet Broadcasts weiter. Ist WebRTC nicht verfügbar (nativ ohne
## webrtc-native-Erweiterung) oder kommt keine Verbindung zustande, läuft alles über RTDB-Relay
## (höhere Latenz, Zustände werden auf 10 Hz gedrosselt).
##
## Nachrichten sind Dictionaries mit Schlüssel "k" (Art). Gameplay-Code nutzt send()/message.

signal status(text: String)
signal room_changed
signal message(from: String, msg: Dictionary)
signal started(cfg: Dictionary)
signal left(reason: String)
signal peer_connected(id: String)

const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const ICE := [{"urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302", "stun:stun.cloudflare.com:3478"]}]
const MAX_PLAYERS := 4

var online := false
var is_host := false
var code := ""
var me := ""
var host_id := ""
var my_slot := 0
var players: Dictionary = {}       # id -> {name, hero, slot, ready}
var meta: Dictionary = {}
var transport := "—"
var rtt_ms := -1.0
var game_cfg: Dictionary = {}
var session := false               # läuft gerade ein gemeinsames Spiel (Rennen, Minispiel, Party)?
var decisions: Dictionary = {}     # Brett-Lockstep: Entscheidungsnummer -> Wert

var _db: RtdbClient
var _pcs: Dictionary = {}          # id -> {pc, rel, unrel, open}
var _relay_peers: Dictionary = {}  # id -> true (nutzt Relay)
var _webrtc_ok := -1               # -1 unbekannt, 0 nein, 1 ja
var _ping_t := 0.0
var _connect_watch: Dictionary = {}  # id -> verbleibende Sekunden bis Relay-Fallback
var _joining := false
var _relay_consumed: Dictionary = {}   # verarbeitete Relay-Schlüssel, gebündelt gelöscht


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_db = RtdbClient.new()
	add_child(_db)
	_db.child.connect(_on_child)
	_db.value.connect(_on_value)
	_db.created.connect(_on_created)
	_db.failed.connect(func(tag: String, msg: String) -> void:
		if tag in ["create", "join"]:
			_joining = false
			status.emit("Fehler: " + msg))


func webrtc_available() -> bool:
	if _webrtc_ok < 0:
		if OS.has_feature("web"):
			_webrtc_ok = 1
		else:
			# Ohne webrtc-native-Erweiterung meldet initialize() teils OK, liefert aber keine Datenkanäle
			var test := WebRTCPeerConnection.new()
			_webrtc_ok = 0
			if test.initialize({"iceServers": []}) == OK:
				var ch := test.create_data_channel("probe", {"negotiated": true, "id": 9})
				_webrtc_ok = 1 if ch != null else 0
			test.close()
	return _webrtc_ok == 1


# --- Identität -------------------------------------------------------------------------------------------

func _ensure_identity() -> bool:
	if Account.fb_uid != "":
		me = Account.fb_uid
		return true
	status.emit("Verbinde mit dem Online-Dienst …")
	Account.ensure_online_identity()
	var waited := 0.0
	while Account.fb_uid == "" and waited < 10.0:
		await get_tree().create_timer(0.2, true).timeout
		waited += 0.2
	me = Account.fb_uid
	if me == "":
		status.emit("Keine Verbindung zum Online-Dienst (Firebase). Bitte Internetverbindung prüfen.")
		return false
	return true


func _player_info(slot: int) -> Dictionary:
	return {"name": Account.display_name() if Account.signed_in() else Game.hero(Game.players[0].hero).name,
		"hero": Game.players[0].hero, "slot": slot, "ready": false, "t": int(Time.get_unix_time_from_system())}


# --- Raum anlegen / beitreten / verlassen -------------------------------------------------------------------

func create_room() -> void:
	if online or _joining:
		return
	_joining = true
	if not await _ensure_identity():
		_joining = false
		return
	code = _new_code()
	is_host = true
	host_id = me
	my_slot = 0
	status.emit("Erstelle Raum %s …" % code)
	_db.create_if_absent("rooms/%s/meta" % code, {"host": me, "created": int(Time.get_unix_time_from_system()), "state": "lobby", "v": 2}, "create")


func join_room(room: String) -> void:
	if online or _joining:
		return
	room = room.strip_edges().to_upper()
	if room.length() < 4:
		status.emit("Bitte einen gültigen Raumcode eingeben.")
		return
	_joining = true
	if not await _ensure_identity():
		_joining = false
		return
	code = room
	is_host = false
	status.emit("Suche Raum %s …" % code)
	_db.get_value("rooms/%s" % code, "join")


func leave(reason := "Raum verlassen.") -> void:
	if code != "":
		if is_host:
			_db.remove("rooms/%s" % code)
		else:
			_db.remove("rooms/%s/players/%s" % [code, me])
	_db.off_all()
	for id in _pcs:
		(_pcs[id].pc as WebRTCPeerConnection).close()
	_pcs.clear()
	_relay_peers.clear()
	_connect_watch.clear()
	var was := online
	if Game.mode == "online" or session:
		Game.mode = "menu"
	session = false
	decisions.clear()
	InputHub.online_local = -1
	InputHub.net_driven.clear()
	Game.reset_players(1)
	online = false
	is_host = false
	code = ""
	players.clear()
	meta.clear()
	game_cfg.clear()
	transport = "—"
	rtt_ms = -1.0
	_joining = false
	if was:
		left.emit(reason)
	room_changed.emit()


func set_ready(on: bool) -> void:
	if online:
		_db.update("rooms/%s/players/%s" % [code, me], {"ready": on})


func set_hero(hero_id: String) -> void:
	Game.players[0].hero = hero_id
	if online:
		_db.update("rooms/%s/players/%s" % [code, me], {"hero": hero_id, "name": _player_info(my_slot).name})


func _new_code() -> String:
	var s := ""
	for i in 5:
		s += CODE_CHARS[randi() % CODE_CHARS.length()]
	return s


func _on_created(tag: String, ok: bool) -> void:
	if tag != "create":
		return
	if not ok:
		code = _new_code()
		_db.create_if_absent("rooms/%s/meta" % code, {"host": me, "created": int(Time.get_unix_time_from_system()), "state": "lobby", "v": 2}, "create")
		return
	_enter_room()


func _on_value(tag: String, val: Variant) -> void:
	if tag != "join":
		return
	if not (val is Dictionary) or not (val as Dictionary).has("meta"):
		_joining = false
		code = ""
		status.emit("Raum nicht gefunden.")
		return
	var room: Dictionary = val
	var m: Dictionary = room.meta
	var ps: Dictionary = room.get("players", {}) if room.get("players", {}) is Dictionary else {}
	if String(m.get("state", "lobby")) != "lobby":
		_joining = false
		code = ""
		status.emit("Das Spiel in diesem Raum läuft bereits.")
		return
	if ps.size() >= MAX_PLAYERS and not ps.has(me):
		_joining = false
		code = ""
		status.emit("Der Raum ist voll (4 Spieler).")
		return
	host_id = String(m.get("host", ""))
	var used: Array = []
	for id in ps:
		used.append(int((ps[id] as Dictionary).get("slot", -1)))
	my_slot = 0
	while my_slot in used:
		my_slot += 1
	_enter_room()


func _enter_room() -> void:
	online = true
	_joining = false
	var path := "rooms/%s/players/%s" % [code, me]
	_db.set_value(path, _player_info(my_slot))
	_db.remove_on_disconnect(path)
	if is_host:
		_db.remove_on_disconnect("rooms/%s/meta" % code)
	_db.listen("rooms/%s/players" % code, "players", 0.8)
	_db.listen("rooms/%s/meta" % code, "meta", 0.8)
	_db.listen("rooms/%s/signal/%s" % [code, me], "signal", 0.25)
	_db.listen("rooms/%s/relay/%s" % [code, me], "relay", 0.12)
	status.emit("Raum %s – warte auf Mitspieler …" % code if is_host else "Verbunden mit Raum %s" % code)
	room_changed.emit()
	if not is_host:
		_connect_to_host()


# --- RTDB-Ereignisse --------------------------------------------------------------------------------------

func _on_child(tag: String, ev: String, key: String, val: Variant) -> void:
	match tag:
		"players":
			if ev == "removed":
				players.erase(key)
				if key == host_id and not is_host:
					leave("Der Host hat den Raum verlassen.")
					return
				if _pcs.has(key):
					(_pcs[key].pc as WebRTCPeerConnection).close()
					_pcs.erase(key)
				_relay_peers.erase(key)
				_takeover_slot(key)
				message.emit(key, {"k": "left"})
			elif val is Dictionary:
				var isnew := not players.has(key)
				players[key] = val
				if isnew and key != me:
					Audio.sfx("pop", null, -4.0)
					if is_host and not _pcs.has(key):
						if webrtc_available():
							_connect_watch[key] = 10.0   # Angebot des Clients abwarten, sonst Relay
						else:
							_relay_peers[key] = true
							transport = "Relay (RTDB)"
			room_changed.emit()
		"meta":
			if ev == "removed":
				if not is_host:
					leave("Der Raum wurde geschlossen.")
				return
			meta[key] = val
			if key == "state" and String(val) == "playing" and not is_host and meta.has("cfg"):
				_start_local(meta.cfg as Dictionary)
			elif key == "cfg" and String(meta.get("state", "")) == "playing" and not is_host:
				_start_local(val as Dictionary)
			room_changed.emit()
		"signal":
			if ev == "added" and val is Dictionary:
				_on_signal(val as Dictionary)
				_db.remove("rooms/%s/signal/%s/%s" % [code, me, key])
		"relay":
			if ev == "added" and val is Dictionary:
				var d: Dictionary = val
				var raw: Variant = JSON.parse_string(String(d.get("d", "")))
				if raw is Dictionary:
					_receive(String(d.get("from", "")), raw as Dictionary)
				_relay_consumed[key] = null


# --- WebRTC ---------------------------------------------------------------------------------------------------

func _make_pc(peer: String, offerer: bool) -> void:
	if not webrtc_available():
		_relay_peers[peer] = true
		transport = "Relay (RTDB)"
		peer_connected.emit(peer)
		return
	var pc := WebRTCPeerConnection.new()
	if pc.initialize({"iceServers": ICE}) != OK:
		_relay_peers[peer] = true
		transport = "Relay (RTDB)"
		return
	pc.session_description_created.connect(func(type: String, sdp: String) -> void:
		pc.set_local_description(type, sdp)
		_send_signal(peer, {"type": type, "sdp": sdp}))
	pc.ice_candidate_created.connect(func(mid: String, idx: int, cand: String) -> void:
		_send_signal(peer, {"type": "ice", "mid": mid, "idx": idx, "cand": cand}))
	var rel := pc.create_data_channel("rel", {"negotiated": true, "id": 1})
	var unrel := pc.create_data_channel("unrel", {"negotiated": true, "id": 2, "ordered": false, "maxRetransmits": 0})
	if rel == null or unrel == null:
		pc.close()
		_webrtc_ok = 0
		_relay_peers[peer] = true
		transport = "Relay (RTDB)"
		peer_connected.emit(peer)
		return
	_pcs[peer] = {"pc": pc, "rel": rel, "unrel": unrel, "open": false}
	_connect_watch[peer] = 9.0
	if offerer:
		pc.create_offer()


func _connect_to_host() -> void:
	status.emit("Baue Direktverbindung zum Host auf …")
	_make_pc(host_id, true)


func _send_signal(to: String, d: Dictionary) -> void:
	d["from"] = me
	_db.push("rooms/%s/signal/%s" % [code, to], d)


func _on_signal(d: Dictionary) -> void:
	var from := String(d.get("from", ""))
	var type := String(d.get("type", ""))
	if type == "offer" and is_host:
		if _pcs.has(from):
			(_pcs[from].pc as WebRTCPeerConnection).close()
		_make_pc(from, false)
	if not _pcs.has(from):
		return
	var pc: WebRTCPeerConnection = _pcs[from].pc
	match type:
		"offer", "answer":
			pc.set_remote_description(type, String(d.get("sdp", "")))
		"ice":
			pc.add_ice_candidate(String(d.get("mid", "")), int(d.get("idx", 0)), String(d.get("cand", "")))


func _process(delta: float) -> void:
	if not online:
		return
	for id in _pcs.keys():
		var e: Dictionary = _pcs[id]
		var pc: WebRTCPeerConnection = e.pc
		pc.poll()
		var rel: WebRTCDataChannel = e.rel
		var unrel: WebRTCDataChannel = e.unrel
		if not bool(e.open) and rel.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
			e.open = true
			_connect_watch.erase(id)
			_relay_peers.erase(id)
			transport = "WebRTC (P2P)"
			status.emit("Direktverbindung steht (WebRTC).")
			peer_connected.emit(id)
		for ch: WebRTCDataChannel in [rel, unrel]:
			while ch.get_ready_state() == WebRTCDataChannel.STATE_OPEN and ch.get_available_packet_count() > 0:
				var raw: Variant = JSON.parse_string(ch.get_packet().get_string_from_utf8())
				if raw is Dictionary:
					_receive(id, raw as Dictionary)
	# Fallback, wenn WebRTC nicht zustande kommt (z. B. symmetrisches NAT ohne TURN)
	for id in _connect_watch.keys():
		_connect_watch[id] = float(_connect_watch[id]) - delta
		if float(_connect_watch[id]) <= 0.0:
			_connect_watch.erase(id)
			_relay_peers[id] = true
			transport = "Relay (RTDB)"
			status.emit("Keine Direktverbindung möglich – nutze Relay.")
			peer_connected.emit(id)
	if not _relay_consumed.is_empty():
		_db.update("rooms/%s/relay/%s" % [code, me], _relay_consumed)   # null = löschen (ein Request)
		_relay_consumed = {}
	_ping_t -= delta
	if _ping_t <= 0.0 and not is_host and connected():
		_ping_t = 1.0
		send({"k": "ping", "t": Time.get_ticks_msec()}, true, false)


func connected() -> bool:
	if is_host:
		return true
	return _relay_peers.has(host_id) or (_pcs.has(host_id) and bool(_pcs[host_id].open))


func using_relay() -> bool:
	return not _relay_peers.is_empty()


## Sendefrequenz für Zustände: WebRTC 30 Hz, Relay 10 Hz.
func state_rate() -> float:
	return 10.0 if using_relay() else 30.0


# --- Nachrichten ------------------------------------------------------------------------------------------------

## Sendet eine Nachricht. Client → Host (mit broadcast=true leitet der Host an alle weiter);
## Host → alle Clients (oder an "to").
func send(msg: Dictionary, reliable := true, broadcast := true, to := "") -> void:
	if not online:
		return
	msg["f"] = me
	if is_host:
		for id in players:
			if id == me or (to != "" and id != to):
				continue
			_send_to(id, msg, reliable)
	else:
		if broadcast:
			msg["b"] = 1
		_send_to(host_id, msg, reliable)


func _send_to(id: String, msg: Dictionary, reliable: bool) -> void:
	var text := JSON.stringify(msg)
	if _pcs.has(id) and bool(_pcs[id].open):
		var ch: WebRTCDataChannel = _pcs[id].rel if reliable else _pcs[id].unrel
		if ch.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
			ch.put_packet(text.to_utf8_buffer())
			return
	if _relay_peers.has(id) or not webrtc_available() or reliable:
		# Relay (bzw. zuverlässige Nachrichten, solange der Direktkanal noch aufgebaut wird)
		_db.push("rooms/%s/relay/%s" % [code, id], {"from": me, "d": text})
	# unzuverlässig & Direktkanal noch nicht offen: verwerfen (der nächste Zustand kommt gleich)


var debug_counts: Dictionary = {}


func _receive(from: String, msg: Dictionary) -> void:
	var k := String(msg.get("k", ""))
	debug_counts[k] = int(debug_counts.get(k, 0)) + 1
	if k == "ping" and is_host:
		_send_to(from, {"k": "pong", "t": msg.get("t", 0)}, true)
		return
	if k == "pong":
		rtt_ms = float(Time.get_ticks_msec() - int(msg.get("t", 0)))
		return
	if k == "bd":
		decisions[int(msg.get("n", -1))] = msg.get("v")
	if is_host and msg.has("b"):
		msg.erase("b")
		for id in players:
			if id != me and id != from:
				_send_to(id, msg, true if k in ["item", "hit", "fell", "shove", "end", "start", "ready", "finish", "bd", "sc"] else false)
	message.emit(String(msg.get("f", from)), msg)


# --- Spielstart -----------------------------------------------------------------------------------------------

## Host: verteilt Slots und Konfiguration, setzt den Raum auf "playing".
func start_game(cfg: Dictionary) -> void:
	if not is_host:
		return
	var slots := {}
	var heroes := {}
	var names := {}
	for id in players:
		var p: Dictionary = players[id]
		slots[id] = int(p.get("slot", 0))
		heroes[str(int(p.get("slot", 0)))] = String(p.get("hero", "knight"))
		names[str(int(p.get("slot", 0)))] = String(p.get("name", "Spieler"))
	cfg["slots"] = slots
	cfg["heroes"] = heroes
	cfg["names"] = names
	cfg["seed"] = randi()
	_db.update("rooms/%s/meta" % code, {"state": "playing", "cfg": cfg})
	_start_local(cfg)


## Läuft gerade ein gemeinsames Online-Spiel (Rennen, Minispiel oder Party)?
func in_game() -> bool:
	return online and session


## Brett-Lockstep: eigene Entscheidung Nummer n verteilen.
func decide_send(n: int, v: Variant) -> void:
	decisions[n] = v
	send({"k": "bd", "n": n, "v": v}, true)


## Spieler hat den Raum während des Spiels verlassen: Sein Slot wird zur CPU (vom Host gesteuert).
func _takeover_slot(id: String) -> void:
	if not session:
		return
	var slots: Dictionary = game_cfg.get("slots", {})
	if not slots.has(id):
		return
	var sl := int(slots[id])
	slots.erase(id)
	Game.players[sl].cpu = true
	Game.players[sl].remote = false
	InputHub.net_driven.erase(sl)
	Account.toast("%s hat das Spiel verlassen – die CPU übernimmt." % String(Game.players[sl].name), Color("#ffb070"))


## Zurück in die Lobby (Host), z. B. nach Rennende.
func back_to_lobby() -> void:
	session = false
	decisions.clear()
	if not online:
		return
	if is_host:
		_db.update("rooms/%s/meta" % code, {"state": "lobby"})
	_db.update("rooms/%s/players/%s" % [code, me], {"ready": false})
	meta["state"] = "lobby"
	InputHub.online_local = -1
	InputHub.net_driven.clear()


func _start_local(cfg: Dictionary) -> void:
	game_cfg = cfg
	var slots: Dictionary = cfg.get("slots", {})
	my_slot = int(slots.get(me, my_slot))
	var heroes: Dictionary = cfg.get("heroes", {})
	for i in 4:
		var key := str(i)
		var taken := heroes.has(key)
		Game.players[i].cpu = not taken
		Game.players[i].remote = taken and i != my_slot
		if taken:
			Game.players[i].hero = String(heroes[key])
			Game.players[i].name = Game.hero(Game.players[i].hero).name
	if "--net-autodrive" in OS.get_cmdline_user_args():
		Game.players[my_slot].cpu = true   # Dev-Test: lokale Figur/Kart fährt per KI
		Game.players[my_slot].cpu_level = 2
	seed(int(cfg.get("seed", 0)))
	InputHub.online_local = my_slot
	Game.mode = "online"
	session = true
	decisions.clear()
	started.emit(cfg)
	match String(cfg.get("mode", "race")):
		"party":
			var humans: Array[bool] = []
			for i in 4:
				humans.append(not Game.players[i].cpu)
			Game.start_party(String(cfg.get("board", "meadow")), int(cfg.get("rounds", 10)), String(cfg.get("pmode", "classic")))
			for i in 4:
				Game.players[i].cpu = not humans[i]
			Router.goto("res://scenes/party/PartyBoard.tscn")
		"race":
			Game.race_cfg.track = String(cfg.get("track", "lumos_ring"))
			Game.race_cfg.laps = int(cfg.get("laps", 3))
			Game.race_cfg.mode = "single"
			Router.goto("res://scenes/racer/NitroDash.tscn")
		"minigame":
			Router.goto(Game.minigame_info(String(cfg.get("id", "sumo_shove"))).scene)


## Gehört ein Slot (bzw. eine CPU) zu diesem Gerät? Host simuliert alle CPUs.
func owns_slot(slot: int) -> bool:
	if not online:
		return true
	if slot < 0:
		return is_host
	if slot == my_slot:
		return true
	return is_host and Game.players[slot].cpu
