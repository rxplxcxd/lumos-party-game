extends Node
## Konto & Profil.
##
## Anmeldewege:
##   * Lumos-Hardware / Lumos OS erkannt  → "Mit Lumos Cloud anmelden" (still per gespeicherter Sitzung,
##     Lumos-OS-Sitzung oder Schlüsselbund; sonst ein Klick mit E-Mail/Passwort der Lumos-ID)
##   * Web / iOS / Android / PWA            → Google (Firebase) oder E-Mail/Passwort (Firebase)
##   * Nativ ohne Browser                   → E-Mail/Passwort über die Firebase-REST-API
##   * Gast                                 → nur lokales Profil
##
## Profil: Bestzeiten, Statistiken, freigeschaltete Karts/Skins/Features. Lokal in user://profile.cfg,
## bei Anmeldung mit der Cloud zusammengeführt (Rekorde = Minimum, Zähler = Maximum, Freischaltungen = Vereinigung)
## und nach Änderungen gebündelt hochgeladen (Lumos: /v1/profile, Firebase: RTDB /profiles/{uid}).
##
## Die Brücke (web/lumos_bridge.js) liefert Ereignisse über LumosBridge.poll(); andere Systeme (Net)
## hängen sich an bridge_event.

signal changed
signal error(message: String)
signal info(message: String)
signal bridge_event(type: String, data: Variant)

const PROFILE_PATH := "user://profile.cfg"
const ACCOUNT_PATH := "user://account.cfg"
const FB_KEY := "AIzaSyBpCU5im11sq4YQbs5XPQ26cjs2XT0n4K0"
const FB_AUTH := "https://identitytoolkit.googleapis.com/v1/accounts:"
const FB_TOKEN := "https://securetoken.googleapis.com/v1/token?key="
const DB_URL := "https://lumos-party-game-default-rtdb.europe-west1.firebasedatabase.app"
const DEFAULT_LUMOS_URL := "http://127.0.0.1:8787"

## Freischaltungen: id -> {name, desc, kind}
const UNLOCKS := {
	"kart_oozi": {"name": "Kart „Oozi“", "desc": "Gewinne einen Grand Prix.", "kind": "kart"},
	"mega_cup": {"name": "Mega-Cup", "desc": "Gewinne den Lumos- oder Sternen-Cup.", "kind": "feature"},
	"skin_gold": {"name": "Goldlack", "desc": "Gewinne 5 Rennen.", "kind": "skin"},
	"skin_neon": {"name": "Glitzer-Lack", "desc": "Gewinne 10 Minispiele.", "kind": "skin"},
	"skin_star": {"name": "Sternen-Glanz", "desc": "Gewinne eine Party.", "kind": "skin"},
	"time_ace": {"name": "Zeitfahr-Ass", "desc": "Stelle auf 3 Strecken eine Bestzeit auf.", "kind": "feature"},
}

var user: Dictionary = {}          # {uid, name, email, provider}  provider: lumos | google | password | anonymous | guest
var fb_uid := ""                   # Firebase-UID (auch anonym) – Identität für Online-Räume
var profile: Dictionary = {}
var is_web := OS.has_feature("web")
var lumos_available := false
var lumos_url := DEFAULT_LUMOS_URL
var env: Dictionary = {}
var busy := false

var _bridge := false
var _profile_version := 0
var _push_t := -1.0
var _fb_id := ""
var _fb_refresh := ""
var _fb_exp := 0.0
var _lumos_access := ""
var _lumos_refresh := ""
var _lumos_exp := 0.0


var _toast: Label
var _toast_tw: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_toast()
	info.connect(func(m: String) -> void: toast(m, Color("#7dff9a")))
	error.connect(func(m: String) -> void: toast(m, Color("#ff8a8a")))
	_load_profile()
	_detect_lumos_native()
	if is_web:
		_bridge = JavaScriptBridge.eval("typeof window.LumosBridge !== 'undefined'", true) == true
		if _bridge:
			var e = JavaScriptBridge.eval("LumosBridge.env()", true)
			if e is String:
				var d = JSON.parse_string(e)
				if d is Dictionary:
					env = d
					lumos_url = String(d.get("cloudUrl", lumos_url))
					if bool(d.get("lumosUA", false)):
						lumos_available = true
						Game.is_lumos_device = true
	EventBus.record_set.connect(_on_record)
	EventBus.race_result.connect(_on_race_result)
	EventBus.gp_result.connect(_on_gp_result)
	EventBus.party_result.connect(_on_party_result)
	EventBus.minigame_result.connect(_on_minigame_result)
	_restore_session.call_deferred()


func _process(delta: float) -> void:
	if _bridge:
		var raw = JavaScriptBridge.eval("LumosBridge.poll()", true)
		if raw is String and raw != "":
			var arr = JSON.parse_string(raw)
			if arr is Array:
				for ev in arr:
					if ev is Dictionary:
						_on_bridge(String(ev.get("type", "")), ev.get("data"))
	if _push_t > 0.0:
		_push_t -= delta
		if _push_t <= 0.0:
			_push_profile()


# --- Hinweis-Einblendung ----------------------------------------------------------------------------------

func _build_toast() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 96
	add_child(layer)
	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 24)
	_toast.add_theme_color_override("font_outline_color", Color(0.06, 0.02, 0.14))
	_toast.add_theme_constant_override("outline_size", 10)
	_toast.modulate.a = 0.0
	UI.place(_toast, Control.PRESET_CENTER_BOTTOM, Vector2(-500, -150), Vector2(1000, 40))
	layer.add_child(_toast)


func toast(text: String, color := Color.WHITE, hold := 2.6) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	if _toast_tw:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tw.tween_interval(hold)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


# --- Status ------------------------------------------------------------------------------------------------

func signed_in() -> bool:
	return not user.is_empty() and not (String(user.get("provider", "guest")) in ["guest", "anonymous"])


func display_name() -> String:
	if user.is_empty():
		return "Gast"
	return String(user.get("name", "Gast"))


func provider_label() -> String:
	return {"lumos": "Lumos Cloud", "google.com": "Google", "google": "Google", "password": "E-Mail", "anonymous": "Gast (online)", "guest": "Gast"}.get(String(user.get("provider", "guest")), "Konto")


func uid() -> String:
	return String(user.get("uid", ""))


func has_unlock(id: String) -> bool:
	return id in (profile.get("unlocked", []) as Array)


# --- Lumos-Erkennung --------------------------------------------------------------------------------------

func _detect_lumos_native() -> void:
	if is_web:
		return
	var home := OS.get_environment("HOME")
	var url := OS.get_environment("LUMOS_CLOUD_URL")
	if url != "":
		lumos_url = url
	if OS.get_environment("LUMOS_KIOSK") == "1" or FileAccess.file_exists(home + "/.cache/lumos/daemon.token") or url != "":
		lumos_available = true
		Game.is_lumos_device = true


## Prüft, ob eine Lumos Cloud erreichbar ist (Web: über die Brücke, nativ: HTTP /v1/health).
func probe_lumos() -> void:
	if _bridge:
		JavaScriptBridge.eval("LumosBridge.probeLumos()", true)
		return
	var r := await _http(HTTPClient.METHOD_GET, lumos_url + "/v1/health", [], "", 1.5)
	var ok: bool = r.ok and (r.json is Dictionary) and String((r.json as Dictionary).get("provider", "")) == "lumos"
	if ok:
		lumos_available = true
		Game.is_lumos_device = true
	changed.emit()


# --- Anmeldung -------------------------------------------------------------------------------------------------

func _restore_session() -> void:
	probe_lumos()
	var cfg := ConfigFile.new()
	cfg.load(ACCOUNT_PATH)
	var last: String = cfg.get_value("account", "provider", "")
	if _bridge:
		if lumos_available or last == "lumos" or bool(env.get("hasLumosSession", false)):
			JavaScriptBridge.eval("LumosBridge.lumosResume()", true)
		if last in ["google", "google.com", "password", "anonymous"]:
			JavaScriptBridge.eval("LumosBridge.fbInit()", true)
		return
	# Nativ: gespeicherte Refresh-Tokens
	if last == "lumos":
		_lumos_refresh = cfg.get_value("account", "lumos_refresh", "")
		if _lumos_refresh != "":
			await _lumos_refresh_token()
	elif last == "password":
		_fb_refresh = cfg.get_value("account", "fb_refresh", "")
		if _fb_refresh != "":
			await _fb_refresh_token()


func login_lumos(email: String, password: String) -> void:
	busy = true
	changed.emit()
	if _bridge:
		JavaScriptBridge.eval("LumosBridge.lumosLogin(%s, %s)" % [JSON.stringify(email), JSON.stringify(password)], true)
		return
	var r := await _http(HTTPClient.METHOD_POST, lumos_url + "/v1/auth/login", ["Content-Type: application/json"], JSON.stringify({"email": email, "password": password}))
	_lumos_session_result(r)


func register_lumos(email: String, password: String, name: String) -> void:
	busy = true
	changed.emit()
	if _bridge:
		JavaScriptBridge.eval("LumosBridge.lumosRegister(%s, %s, %s)" % [JSON.stringify(email), JSON.stringify(password), JSON.stringify(name)], true)
		return
	var r := await _http(HTTPClient.METHOD_POST, lumos_url + "/v1/auth/register", ["Content-Type: application/json"], JSON.stringify({"email": email, "password": password, "displayName": name}))
	_lumos_session_result(r)


## Ein-Klick-Anmeldung auf Lumos-Geräten: erst still versuchen, sonst meldet die UI Bedarf an Zugangsdaten.
func resume_lumos() -> void:
	if _bridge:
		busy = true
		changed.emit()
		JavaScriptBridge.eval("LumosBridge.lumosResume()", true)
	elif _lumos_refresh != "":
		await _lumos_refresh_token()
	else:
		bridge_event.emit("lumos_resume_failed", null)


func login_google() -> void:
	if not _bridge:
		error.emit("Google-Anmeldung ist im Browser bzw. in der installierten Web-App verfügbar.")
		return
	busy = true
	changed.emit()
	JavaScriptBridge.eval("LumosBridge.fbGoogle()", true)


func login_email(email: String, password: String) -> void:
	busy = true
	changed.emit()
	if _bridge:
		JavaScriptBridge.eval("LumosBridge.fbEmailLogin(%s, %s)" % [JSON.stringify(email), JSON.stringify(password)], true)
		return
	var r := await _http(HTTPClient.METHOD_POST, FB_AUTH + "signInWithPassword?key=" + FB_KEY, ["Content-Type: application/json"],
		JSON.stringify({"email": email, "password": password, "returnSecureToken": true}))
	_fb_rest_result(r)


func register_email(email: String, password: String, name: String) -> void:
	busy = true
	changed.emit()
	if _bridge:
		JavaScriptBridge.eval("LumosBridge.fbEmailRegister(%s, %s, %s)" % [JSON.stringify(email), JSON.stringify(password), JSON.stringify(name)], true)
		return
	var r := await _http(HTTPClient.METHOD_POST, FB_AUTH + "signUp?key=" + FB_KEY, ["Content-Type: application/json"],
		JSON.stringify({"email": email, "password": password, "returnSecureToken": true}))
	if r.ok and name != "":
		var j: Dictionary = r.json
		await _http(HTTPClient.METHOD_POST, FB_AUTH + "update?key=" + FB_KEY, ["Content-Type: application/json"],
			JSON.stringify({"idToken": j.get("idToken", ""), "displayName": name, "returnSecureToken": false}))
		j["displayName"] = name
	_fb_rest_result(r)


func reset_password(email: String) -> void:
	if _bridge:
		JavaScriptBridge.eval("LumosBridge.fbResetPassword(%s)" % JSON.stringify(email), true)
		return
	var r := await _http(HTTPClient.METHOD_POST, FB_AUTH + "sendOobCode?key=" + FB_KEY, ["Content-Type: application/json"],
		JSON.stringify({"requestType": "PASSWORD_RESET", "email": email}))
	if r.ok:
		info.emit("E-Mail zum Zurücksetzen wurde gesendet.")
	else:
		error.emit(_fb_error_text(r))


## Anonyme Firebase-Sitzung (für Online-Räume ohne Konto).
func ensure_online_identity() -> void:
	if OS.get_environment("LUMOS_NET_TEST_UID") != "":
		fb_uid = OS.get_environment("LUMOS_NET_TEST_UID")   # lokaler Netztest mit tools/dev/rtdb_mock.py
		return
	if _bridge:
		if fb_uid == "":
			JavaScriptBridge.eval("LumosBridge.fbAnonymous()", true)
		return
	if _fb_id != "":
		return
	var r := await _http(HTTPClient.METHOD_POST, FB_AUTH + "signUp?key=" + FB_KEY, ["Content-Type: application/json"], JSON.stringify({"returnSecureToken": true}))
	if r.ok:
		var j: Dictionary = r.json
		_fb_id = String(j.get("idToken", ""))
		_fb_refresh = String(j.get("refreshToken", ""))
		_fb_exp = Time.get_unix_time_from_system() + float(j.get("expiresIn", "3600"))
		fb_uid = String(j.get("localId", ""))
		if user.is_empty() or String(user.get("provider", "")) == "guest":
			user = {"uid": j.get("localId", ""), "name": Game.hero(Game.players[0].hero).name, "email": "", "provider": "anonymous"}
		changed.emit()


func play_as_guest() -> void:
	user = {"uid": "", "name": "Gast", "email": "", "provider": "guest"}
	_save_account("guest")
	changed.emit()


func logout() -> void:
	var prov := String(user.get("provider", ""))
	if _bridge:
		if prov == "lumos":
			JavaScriptBridge.eval("LumosBridge.lumosLogout()", true)
		else:
			JavaScriptBridge.eval("LumosBridge.fbSignOut()", true)
	user = {}
	_fb_id = ""
	_fb_refresh = ""
	_lumos_access = ""
	_lumos_refresh = ""
	_save_account("")
	changed.emit()


# --- Brücken-Ereignisse (Web) -----------------------------------------------------------------------------------

func _on_bridge(type: String, data: Variant) -> void:
	match type:
		"lumos_user":
			busy = false
			_set_user(data as Dictionary)
		"fb_user":
			busy = false
			if data == null:
				fb_uid = ""
				if String(user.get("provider", "")) not in ["lumos", "guest", ""]:
					user = {}
					changed.emit()
			else:
				var fd: Dictionary = data
				fb_uid = String(fd.get("uid", ""))
				# Anonyme Firebase-Sitzung nur als Online-Identität – ein Lumos-/Google-Konto bleibt aktiv
				if bool(fd.get("anonymous", false)) and signed_in():
					changed.emit()
				else:
					_set_user(fd)
		"auth_error":
			busy = false
			error.emit(String((data as Dictionary).get("message", "Anmeldung fehlgeschlagen.")))
			changed.emit()
		"lumos_resume_failed":
			busy = false
			changed.emit()
		"lumos_probe":
			var ok := bool((data as Dictionary).get("ok", false))
			if ok:
				lumos_available = true
				Game.is_lumos_device = true
				changed.emit()
		"profile":
			_merge_remote((data as Dictionary).get("profile"), int((data as Dictionary).get("version", 0)))
		"profile_saved":
			_profile_version = int((data as Dictionary).get("version", _profile_version))
		"profile_error":
			if int((data as Dictionary).get("status", 0)) == 409:
				_fetch_profile()   # Konflikt: neu laden, zusammenführen, erneut senden
		"db_value":
			var d: Dictionary = data
			if String(d.get("tag", "")) == "profile":
				_merge_remote(d.get("value"), 0)
		"info":
			info.emit(String(data))
		"signed_out":
			pass
	bridge_event.emit(type, data)


func _set_user(d: Dictionary) -> void:
	var prov := String(d.get("provider", "password"))
	user = {"uid": String(d.get("uid", "")), "name": String(d.get("name", "Spieler")), "email": String(d.get("email", "")), "provider": prov}
	if d.has("friendCode"):
		user["friend_code"] = d.friendCode
	_save_account(prov)
	profile["name"] = user.name
	changed.emit()
	info.emit("Angemeldet als %s (%s)" % [user.name, provider_label()])
	_fetch_profile()


# --- Native REST -----------------------------------------------------------------------------------------------

func _lumos_session_result(r: Dictionary) -> void:
	busy = false
	if not r.ok:
		var msg := "Lumos Cloud nicht erreichbar."
		if r.json is Dictionary:
			msg = String((r.json as Dictionary).get("error", msg))
		error.emit(msg)
		changed.emit()
		return
	var j: Dictionary = r.json
	_lumos_access = String(j.get("accessToken", ""))
	_lumos_refresh = String(j.get("refreshToken", ""))
	_lumos_exp = Time.get_unix_time_from_system() + float(j.get("expiresIn", 900))
	var u: Dictionary = j.get("user", {})
	_set_user({"uid": u.get("id", ""), "name": u.get("displayName", "Lumos"), "email": u.get("email", ""), "provider": "lumos", "friendCode": u.get("friendCode", "")})


func _lumos_refresh_token() -> void:
	var r := await _http(HTTPClient.METHOD_POST, lumos_url + "/v1/auth/refresh", ["Content-Type: application/json"], JSON.stringify({"refreshToken": _lumos_refresh}))
	if r.ok:
		_lumos_session_result(r)
	else:
		_lumos_refresh = ""


func _fb_rest_result(r: Dictionary) -> void:
	busy = false
	if not r.ok:
		error.emit(_fb_error_text(r))
		changed.emit()
		return
	var j: Dictionary = r.json
	_fb_id = String(j.get("idToken", ""))
	_fb_refresh = String(j.get("refreshToken", ""))
	_fb_exp = Time.get_unix_time_from_system() + float(j.get("expiresIn", "3600"))
	fb_uid = String(j.get("localId", ""))
	var email := String(j.get("email", ""))
	_set_user({"uid": j.get("localId", ""), "name": j.get("displayName", email.get_slice("@", 0)), "email": email, "provider": "password"})


func _fb_refresh_token() -> void:
	var r := await _http(HTTPClient.METHOD_POST, FB_TOKEN + FB_KEY, ["Content-Type: application/x-www-form-urlencoded"],
		"grant_type=refresh_token&refresh_token=" + _fb_refresh.uri_encode())
	if not r.ok:
		_fb_refresh = ""
		return
	var j: Dictionary = r.json
	_fb_id = String(j.get("id_token", ""))
	_fb_refresh = String(j.get("refresh_token", _fb_refresh))
	_fb_exp = Time.get_unix_time_from_system() + float(j.get("expires_in", "3600"))
	fb_uid = String(j.get("user_id", fb_uid))
	if user.is_empty():
		var cfg := ConfigFile.new()
		cfg.load(ACCOUNT_PATH)
		_set_user({"uid": j.get("user_id", ""), "name": cfg.get_value("account", "name", "Spieler"), "email": cfg.get_value("account", "email", ""), "provider": "password"})


## Gültiges Firebase-ID-Token (nativ), für REST-Aufrufe an die Realtime Database.
func fb_token() -> String:
	if _fb_refresh != "" and Time.get_unix_time_from_system() > _fb_exp - 60.0:
		await _fb_refresh_token()
	return _fb_id


func _fb_error_text(r: Dictionary) -> String:
	var code := ""
	if r.json is Dictionary and (r.json as Dictionary).has("error"):
		code = String(((r.json as Dictionary).error as Dictionary).get("message", ""))
	return {"EMAIL_NOT_FOUND": "Kein Konto mit dieser E-Mail.", "INVALID_PASSWORD": "Falsches Passwort.", "INVALID_LOGIN_CREDENTIALS": "E-Mail oder Passwort falsch.",
		"EMAIL_EXISTS": "Diese E-Mail ist bereits registriert.", "WEAK_PASSWORD : Password should be at least 6 characters": "Das Passwort muss mindestens 6 Zeichen haben.",
		"INVALID_EMAIL": "Ungültige E-Mail-Adresse.", "TOO_MANY_ATTEMPTS_TRY_LATER": "Zu viele Versuche – bitte kurz warten."}.get(code, "Anmeldung fehlgeschlagen (%s)." % (code if code != "" else "keine Verbindung"))


func _http(method: int, url: String, headers: Array, body := "", timeout := 10.0) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = timeout
	add_child(req)
	var err := req.request(url, PackedStringArray(headers), method, body)
	if err != OK:
		req.queue_free()
		return {"ok": false, "code": 0, "json": null}
	var res: Array = await req.request_completed
	req.queue_free()
	var code: int = res[1]
	var text := (res[3] as PackedByteArray).get_string_from_utf8()
	var j = JSON.parse_string(text) if text != "" else null
	return {"ok": res[0] == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300, "code": code, "json": j}


func _save_account(provider: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("account", "provider", provider)
	cfg.set_value("account", "name", user.get("name", ""))
	cfg.set_value("account", "email", user.get("email", ""))
	if not is_web:
		cfg.set_value("account", "lumos_refresh", _lumos_refresh)
		cfg.set_value("account", "fb_refresh", _fb_refresh)
	cfg.save(ACCOUNT_PATH)


# --- Profil ------------------------------------------------------------------------------------------------------

func _default_profile() -> Dictionary:
	return {"name": "", "highscores": {}, "best_laps": {}, "stats": {"races": 0, "race_wins": 0, "gp_wins": 0, "parties": 0, "party_wins": 0,
		"minigames": 0, "minigame_wins": 0}, "unlocked": [], "updated": 0}


func _load_profile() -> void:
	profile = _default_profile()
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) == OK:
		var d = cfg.get_value("profile", "data", {})
		if d is Dictionary:
			profile = _merge(profile, d)


func _save_profile(push := true) -> void:
	profile.updated = int(Time.get_unix_time_from_system())
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "data", profile)
	cfg.save(PROFILE_PATH)
	changed.emit()
	if push and signed_in():
		_push_t = 3.0


func _fetch_profile() -> void:
	var prov := String(user.get("provider", ""))
	if prov == "lumos":
		if _bridge:
			JavaScriptBridge.eval("LumosBridge.lumosGetProfile()", true)
		elif _lumos_access != "":
			var r := await _http(HTTPClient.METHOD_GET, lumos_url + "/v1/profile", ["Authorization: Bearer " + _lumos_access])
			if r.ok and r.json is Dictionary:
				_merge_remote((r.json as Dictionary).get("profile"), int((r.json as Dictionary).get("version", 0)))
	elif prov in ["google", "google.com", "password", "anonymous"] and uid() != "":
		if _bridge:
			JavaScriptBridge.eval("LumosBridge.dbGet(%s, 'profile')" % JSON.stringify("profiles/" + uid()), true)
		else:
			var tok: String = await fb_token()
			var r2 := await _http(HTTPClient.METHOD_GET, "%s/profiles/%s.json?auth=%s" % [DB_URL, uid(), tok], [])
			if r2.ok:
				_merge_remote(r2.json, 0)


func _merge_remote(remote: Variant, version: int) -> void:
	if version > 0:
		_profile_version = version
	if remote is Dictionary:
		profile = _merge(profile, remote as Dictionary)
	_check_unlocks()
	_save_profile(true)


## Zusammenführen: Bestzeiten = Minimum, Zähler = Maximum, Freischaltungen = Vereinigung.
func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate(true)
	for key in ["highscores", "best_laps"]:
		var ma: Dictionary = out.get(key, {})
		var mb: Dictionary = b.get(key, {}) if b.get(key, {}) is Dictionary else {}
		for t in mb:
			ma[t] = minf(float(ma.get(t, INF)), float(mb[t]))
		out[key] = ma
	var sa: Dictionary = out.get("stats", {})
	var sb: Dictionary = b.get("stats", {}) if b.get("stats", {}) is Dictionary else {}
	for k in sb:
		sa[k] = maxi(int(sa.get(k, 0)), int(sb[k]))
	out["stats"] = sa
	var ua: Array = out.get("unlocked", [])
	var ub: Array = b.get("unlocked", []) if b.get("unlocked", []) is Array else []
	for u in ub:
		if not (u in ua):
			ua.append(u)
	out["unlocked"] = ua
	if String(b.get("name", "")) != "" and String(out.get("name", "")) == "":
		out["name"] = b.name
	return out


func _push_profile() -> void:
	var prov := String(user.get("provider", ""))
	var json := JSON.stringify(profile)
	if prov == "lumos":
		if _bridge:
			JavaScriptBridge.eval("LumosBridge.lumosPutProfile(%s, %d)" % [JSON.stringify(json), _profile_version], true)
		elif _lumos_access != "":
			var r := await _http(HTTPClient.METHOD_PUT, lumos_url + "/v1/profile", ["Content-Type: application/json", "Authorization: Bearer " + _lumos_access],
				JSON.stringify({"profile": profile, "version": _profile_version}))
			if r.ok and r.json is Dictionary:
				_profile_version = int((r.json as Dictionary).get("version", _profile_version + 1))
			elif r.code == 409:
				_fetch_profile()
	elif prov in ["google", "google.com", "password", "anonymous"] and uid() != "":
		if _bridge:
			JavaScriptBridge.eval("LumosBridge.dbSet(%s, %s, '')" % [JSON.stringify("profiles/" + uid()), JSON.stringify(json)], true)
		else:
			var tok: String = await fb_token()
			await _http(HTTPClient.METHOD_PUT, "%s/profiles/%s.json?auth=%s" % [DB_URL, uid(), tok], ["Content-Type: application/json"], json)


# --- Fortschritt & Freischaltungen ----------------------------------------------------------------------------

func _stat_add(key: String, n := 1) -> void:
	var st: Dictionary = profile.stats
	st[key] = int(st.get(key, 0)) + n


func _on_record(track_id: String, best_total: float, best_lap: float) -> void:
	profile.highscores[track_id] = minf(float(profile.highscores.get(track_id, INF)), best_total)
	profile.best_laps[track_id] = minf(float(profile.best_laps.get(track_id, INF)), best_lap)
	_check_unlocks()
	_save_profile()


func _on_race_result(slot: int, place: int) -> void:
	if slot != 0:
		return
	_stat_add("races")
	if place == 1:
		_stat_add("race_wins")
	_check_unlocks()
	_save_profile()


func _on_gp_result(slot: int, place: int, cup: String) -> void:
	if slot != 0 or place != 1:
		return
	_stat_add("gp_wins")
	_unlock("kart_oozi")
	if cup != "Mega-Cup (8 Strecken)":
		_unlock("mega_cup")
	_save_profile()


func _on_party_result(ranking: Array) -> void:
	_stat_add("parties")
	if not ranking.is_empty() and int(ranking[0]) == 0:
		_stat_add("party_wins")
		_unlock("skin_star")
	_save_profile()


func _on_minigame_result(placements: Array) -> void:
	if placements.is_empty():
		return
	_stat_add("minigames")
	if int(placements[0]) == 1:
		_stat_add("minigame_wins")
	_check_unlocks()
	_save_profile()


func _check_unlocks() -> void:
	var st: Dictionary = profile.stats
	if int(st.get("race_wins", 0)) >= 5:
		_unlock("skin_gold")
	if int(st.get("minigame_wins", 0)) >= 10:
		_unlock("skin_neon")
	if int(st.get("gp_wins", 0)) >= 1:
		_unlock("kart_oozi")
	if (profile.highscores as Dictionary).size() >= 3:
		_unlock("time_ace")


func _unlock(id: String) -> void:
	var arr: Array = profile.unlocked
	if id in arr:
		return
	arr.append(id)
	var u: Dictionary = UNLOCKS.get(id, {})
	info.emit("Freigeschaltet: %s!" % u.get("name", id))
	EventBus.unlocked.emit(id)
