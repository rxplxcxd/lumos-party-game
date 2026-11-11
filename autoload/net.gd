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
const MAX_BIG := 20                # Lumos-Athlon-Räume

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
# Synchronisations-Gates (sync_point): tag -> {id: true} bzw. tag -> true. Liegen im Autoload, damit Meldungen,
# die vor dem eigenen Erreichen des Gates (z. B. noch beim Laden) eintreffen, nicht verloren gehen.
var _sp_arrived: Dictionary = {}
var _sp_go: Dictionary = {}
var scene_epoch := 0               # zählt Szenenwechsel in einer Sitzung (gleich auf allen Geräten)
var _last_pong := 0.0
var _notice_layer: CanvasLayer
var _wait_label: Label


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
	while Account.fb_uid == "" and Account.online_error == "" and waited < 10.0:
		await get_tree().create_timer(0.2, true).timeout
		waited += 0.2
	me = Account.fb_uid
	if me == "":
		if Account.online_error != "":
			status.emit("Online-Spiel nicht möglich: %s Mit einem Konto (im Profil anmelden) klappt es trotzdem." % Account.online_error)
		else:
			status.emit("Keine Verbindung zum Online-Dienst (Firebase). Bitte Internetverbindung prüfen.")
		return false
	return true


func _player_info(slot: int) -> Dictionary:
	return {"name": Account.display_name() if Account.signed_in() else Game.hero(Game.players[0].hero).name,
		"hero": Game.players[0].hero, "slot": slot, "ready": false, "t": int(Time.get_unix_time_from_system())}


# --- Raum anlegen / beitreten / verlassen -------------------------------------------------------------------

## Maximale Spielerzahl im aktuellen Raum (4, im Athlon-Raum 20).
func capacity() -> int:
	return int(meta.get("max", MAX_PLAYERS))


func create_room(max_players := MAX_PLAYERS) -> void:
	if online or _joining:
		return
	meta["max"] = max_players
	_joining = true
	if not await _ensure_identity():
		_joining = false
		return
	code = _new_code()
	is_host = true
	host_id = me
	my_slot = 0
	status.emit("Erstelle Raum %s …" % code)
	_db.create_if_absent("rooms/%s/meta" % code, {"host": me, "created": int(Time.get_unix_time_from_system()), "state": "lobby", "v": 2, "max": max_players}, "create")


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
			# Mitspieler ausdrücklich informieren (sonst flögen sie wortlos raus) – kurz vor dem Löschen des Raums
			send({"k": "bye", "r": "Der Host hat das Spiel beendet." if session else "Der Host hat den Raum geschlossen."}, true)
			var room := code
			get_tree().create_timer(0.5, true).timeout.connect(func() -> void: _db.remove("rooms/%s" % room))
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
	var cap := int(m.get("max", MAX_PLAYERS))
	if ps.size() >= cap and not ps.has(me):
		_joining = false
		code = ""
		status.emit("Der Raum ist voll (%d Spieler)." % cap)
		return
	meta["max"] = cap
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
					end_with_notice("Der Host hat das Spiel beendet." if session else "Der Host hat den Raum verlassen.")
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
					end_with_notice("Der Host hat das Spiel beendet." if session else "Der Raum wurde geschlossen.")
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
	# Verbindungswächter: im Spiel kommt jede Sekunde ein Pong – bleibt er 12 s aus, ist der Host weg
	if session and not is_host and _last_pong > 0.0 and Time.get_ticks_msec() / 1000.0 - _last_pong > 12.0:
		_last_pong = 0.0
		end_with_notice("Die Verbindung zum Host wurde getrennt.")


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
		_last_pong = Time.get_ticks_msec() / 1000.0
		return
	if k == "sp":
		if is_host:
			_sp_mark(String(msg.get("tag", "")), String(msg.get("f", from)))
		return
	if k == "sp_go":
		_sp_go[String(msg.get("tag", ""))] = true
		return
	if k == "bye" and not is_host:
		end_with_notice(String(msg.get("r", "Der Host hat das Spiel beendet.")))
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
	# Derselbe Start kann über zwei Datenbank-Ereignisse (state + cfg) ankommen – ein zweiter Aufruf würde die
	# laufende Partie zurücksetzen (Felder -1 → Figuren auf einem falschen Feld). Nur einmal je Spiel starten.
	if session and int(game_cfg.get("seed", -1)) == int(cfg.get("seed", -2)):
		return
	var slots: Dictionary = cfg.get("slots", {})
	if not slots.has(me) and not is_host:
		# Später Beitritt: Das Spiel lief schon ohne uns los – nicht mitstarten, sondern sauber Bescheid geben
		status.emit("Das Spiel hat bereits begonnen – du bist bei der nächsten Runde dabei.")
		return
	game_cfg = cfg
	my_slot = int(slots.get(me, my_slot))
	_sp_arrived.clear()
	_sp_go.clear()
	scene_epoch = 0
	_last_pong = Time.get_ticks_msec() / 1000.0
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
		"athlon":
			# Eigener Kader bis 20 Läufer; das lokale Gerät steuert immer über Slot 0.
			InputHub.online_local = 0
			for i in 4:
				Game.players[i].cpu = i != 0
				Game.players[i].remote = false
			Game.players[0].hero = String(heroes.get(str(my_slot), Game.players[0].hero))
			Game.mode = "athlon"
			Router.goto("res://scenes/modes/Athlon.tscn")
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


# --- Synchronisations-Gate ---------------------------------------------------------------------------------------

## Teilnehmer der laufenden Sitzung, die noch im Raum sind (Host eingeschlossen).
func session_peers() -> Array:
	var out: Array = []
	for id in (game_cfg.get("slots", {}) as Dictionary):
		if players.has(id) or id == me:
			out.append(id)
	return out


## Wartet, bis ALLE Teilnehmer diesen Punkt erreicht haben (z. B. Szene fertig geladen, Zugbeginn).
## Der Host sammelt die Meldungen und gibt frei; Gäste melden sich wiederholt, bis die Freigabe kommt.
## timeout: Sicherheitsnetz gegen Hänger (dann geht es ohne Nachzügler weiter).
func sync_point(tag: String, timeout := 45.0) -> void:
	if not in_game():
		return
	var t0 := Time.get_ticks_msec() / 1000.0
	var resend := 0.0
	if is_host:
		_sp_mark(tag, me)
	while in_game() and not _sp_go.has(tag):
		var now := Time.get_ticks_msec() / 1000.0
		if not is_host and now >= resend:
			resend = now + 1.5
			send({"k": "sp", "tag": tag}, true, false)
		if is_host:
			_sp_check(tag)   # Teilnehmer kann inzwischen gegangen sein
		if now - t0 > 0.6:
			_show_wait(tag)
		if now - t0 > timeout:
			if is_host:
				_sp_release(tag)
			break
		await get_tree().process_frame
	_hide_wait()


## Szenenwechsel-Gate: jede neu geladene Online-Szene ruft das auf, bevor irgendetwas läuft.
func loading_gate() -> void:
	if not in_game():
		return
	scene_epoch += 1
	await sync_point("load:%d" % scene_epoch, 60.0)


func _sp_mark(tag: String, id: String) -> void:
	if not _sp_arrived.has(tag):
		_sp_arrived[tag] = {}
	(_sp_arrived[tag] as Dictionary)[id] = true
	_sp_check(tag)


func _sp_check(tag: String) -> void:
	if not is_host or _sp_go.has(tag) or not (_sp_arrived.get(tag, {}) as Dictionary).has(me):
		return
	var arr: Dictionary = _sp_arrived.get(tag, {})
	for id in session_peers():
		if not arr.has(id):
			return
	_sp_release(tag)


func _sp_release(tag: String) -> void:
	_sp_go[tag] = true
	send({"k": "sp_go", "tag": tag}, true)


func _show_wait(tag: String) -> void:
	if _wait_label == null:
		var layer := CanvasLayer.new()
		layer.layer = 110
		add_child(layer)
		_wait_label = UI.label("", 26, Color.WHITE, true, 10)
		_wait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UI.place(_wait_label, Control.PRESET_CENTER_TOP, Vector2(-450, 86), Vector2(900, 40))
		layer.add_child(_wait_label)
	var n := session_peers().size()
	var have := (_sp_arrived.get(tag, {}) as Dictionary).size() if is_host else -1
	var dots := ".".repeat(1 + int(Time.get_ticks_msec() / 400) % 3)
	_wait_label.text = ("Warte auf Mitspieler%s  (%d/%d bereit)" % [dots, have, n]) if have >= 0 else "Warte auf die anderen%s" % dots
	_wait_label.visible = true


func _hide_wait() -> void:
	if _wait_label:
		_wait_label.visible = false


# --- Abbruch mit Hinweis -----------------------------------------------------------------------------------------

## Beendet das Online-Spiel und zeigt einen klaren Hinweis (statt wortlos ins Menü zu fliegen).
func end_with_notice(reason: String) -> void:
	var was_game := session
	if "--net-test" in str(OS.get_cmdline_user_args()):
		print("[NET] Hinweis: ", reason)
	leave(reason)
	_show_notice(reason, was_game)


func _show_notice(reason: String, to_menu: bool) -> void:
	if _notice_layer and is_instance_valid(_notice_layer):
		_notice_layer.queue_free()
	_notice_layer = CanvasLayer.new()
	_notice_layer.layer = 125
	_notice_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_notice_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.01, 0.08, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_notice_layer.add_child(dim)
	var panel := UI.panel()
	UI.place(panel, Control.PRESET_CENTER, Vector2(-330, -150), Vector2(660, 300))
	_notice_layer.add_child(panel)
	var v := UI.vbox(18)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	var title := UI.label("Online-Spiel beendet", 40, UI.GOLD, true, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var msg := UI.label(reason, 26, Color.WHITE)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size.x = 600
	v.add_child(msg)
	var hint := UI.label("Das ist kein Fehler im Spiel – die Sitzung wurde beendet.", 18, Color(1, 1, 1, 0.65))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	var ok := UI.button("OK", Color("#2ecc71"), 28, 240)
	v.add_child(ok)
	Audio.sfx("negative", null, -4.0)
	ok.pressed.connect(func() -> void:
		_notice_layer.queue_free()
		get_tree().paused = false
		if to_menu:
			Router.goto("res://scenes/menu/MainMenu.tscn", {"page": "online"}))
	ok.grab_focus.call_deferred()
	if to_menu:
		get_tree().paused = true   # laufende Szene anhalten, bis der Hinweis bestätigt ist


## Gehört ein Slot (bzw. eine CPU) zu diesem Gerät? Host simuliert alle CPUs.
func owns_slot(slot: int) -> bool:
	if not online:
		return true
	if slot < 0:
		return is_host
	if slot == my_slot:
		return true
	return is_host and Game.players[slot].cpu
