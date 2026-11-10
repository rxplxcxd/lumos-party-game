extends RefCounted
## Supabase-REST-Client (GoTrue-Auth + PostgREST) über HTTPRequest – nativ wie im Web-Export.
##
## Web-Export: HTTPRequest läuft dort über fetch(). Supabase beantwortet CORS-Preflights für jede Herkunft;
## gesendet werden nur apikey, Authorization (nur mit echtem JWT), Content-Type und Prefer – alles Header,
## die Supabase im Preflight erlaubt. Über http:// zu einem fremden Host würde eine HTTPS-Seite (GitHub Pages)
## die Anfrage als „Mixed Content“ still blockieren, deshalb wird jede Nicht-localhost-URL auf https:// gezwungen.
##
## Jede Antwort: {ok, code, json, error}. error ist ein fertiger deutscher Text (leer bei Erfolg).

const CFG = preload("res://scripts/net/backend_config.gd")

var url := ""
var key := ""
var settings: Dictionary = {}      # GET /auth/v1/settings: {external: {google: bool, …}, mailer_autoconfirm, disable_signup}

var _host: Node


func _init(host: Node) -> void:
	_host = host
	var u := OS.get_environment("LUMOS_SUPABASE_URL")
	var k := OS.get_environment("LUMOS_SUPABASE_KEY")
	url = normalize_url(u if u != "" else CFG.SUPABASE_URL)
	key = (k if k != "" else CFG.SUPABASE_ANON_KEY).strip_edges()


func configured() -> bool:
	return url != "" and key != ""


## Projekt-URL säubern: Leerzeichen, Schrägstrich am Ende, versehentlich mitkopierte /rest/v1 bzw. /auth/v1,
## fehlendes Schema; http:// nur für lokale Testserver.
static func normalize_url(raw: String) -> String:
	var s := raw.strip_edges().trim_suffix("/")
	for suffix in ["/rest/v1", "/auth/v1"]:
		s = s.trim_suffix(suffix)
	if s == "":
		return ""
	if not s.contains("://"):
		s = "https://" + s
	var local := s.begins_with("http://localhost") or s.begins_with("http://127.0.0.1")
	if s.begins_with("http://") and not local:
		s = "https://" + s.substr(7)
	return s


func _is_jwt(t: String) -> bool:
	return t.begins_with("eyJ") and t.count(".") == 2


## Roh-Anfrage. path beginnt mit /auth/v1 oder /rest/v1. token = Access-Token des Nutzers (sonst anon).
func request(method: int, path: String, body: Variant = null, token := "", extra_headers: Array = [], timeout := 12.0) -> Dictionary:
	if not configured():
		return {"ok": false, "code": 0, "json": null, "error": "Online-Konten sind noch nicht eingerichtet (Supabase-URL/-Key fehlen)."}
	var headers := PackedStringArray(["apikey: " + key, "Accept: application/json"])
	# Neue „publishable“ Keys sind kein JWT und dürfen nicht als Bearer-Token mitgehen.
	var bearer := token if token != "" else (key if _is_jwt(key) else "")
	if bearer != "":
		headers.append("Authorization: Bearer " + bearer)
	var payload := ""
	if body != null:
		headers.append("Content-Type: application/json")
		payload = JSON.stringify(body)
	for h in extra_headers:
		headers.append(String(h))
	var req := HTTPRequest.new()
	req.timeout = timeout
	req.accept_gzip = not OS.has_feature("web")   # Browser entpackt selbst; Accept-Encoding ist dort ohnehin verboten
	_host.add_child(req)
	var err := req.request(url + path, headers, method, payload)
	if err != OK:
		req.queue_free()
		push_warning("Supabase %s %s: request() fehlgeschlagen (%d)" % [_method_name(method), path.get_slice("?", 0), err])
		return {"ok": false, "code": 0, "json": null, "error": "Anfrage konnte nicht gestartet werden (Fehler %d) – Supabase-URL prüfen: %s" % [err, url]}
	var res: Array = await req.request_completed
	req.queue_free()
	var result: int = res[0]
	var code: int = res[1]
	var text := (res[3] as PackedByteArray).get_string_from_utf8()
	var j: Variant = JSON.parse_string(text) if text.strip_edges() != "" else null
	var ok := result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300
	var out := {"ok": ok, "code": code, "json": j, "error": ""}
	if not ok:
		out.error = _transport_error(result) if result != HTTPRequest.RESULT_SUCCESS else error_text(code, j)
		push_warning("Supabase %s %s → result %d, HTTP %d: %s" % [_method_name(method), path.get_slice("?", 0), result, code, text.left(300)])
	return out


func _method_name(m: int) -> String:
	return {HTTPClient.METHOD_GET: "GET", HTTPClient.METHOD_POST: "POST", HTTPClient.METHOD_PUT: "PUT",
		HTTPClient.METHOD_PATCH: "PATCH", HTTPClient.METHOD_DELETE: "DELETE"}.get(m, str(m))


func _transport_error(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "Supabase-Server nicht gefunden – stimmt die Projekt-URL? (%s)" % url
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "Sichere Verbindung (HTTPS) zu Supabase fehlgeschlagen."
		HTTPRequest.RESULT_TIMEOUT:
			return "Supabase antwortet nicht (Zeitüberschreitung) – bitte erneut versuchen."
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED, HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED:
			return "Ungültige Antwort von Supabase."
	if OS.has_feature("web"):
		# fetch() meldet CORS-Sperren, Werbeblocker und Offline gleichermaßen nur als Netzwerkfehler.
		return "Keine Verbindung zu Supabase (offline, Werbeblocker oder blockierte Anfrage) – %s" % url
	return "Keine Verbindung zu Supabase – Internetverbindung prüfen."


## GoTrue/PostgREST/API-Gateway-Fehler → verständlicher Text. Formate: {error_code, msg} (neu),
## {error, error_description} (alt), {message, hint} (Gateway/PostgREST).
static func error_text(code: int, j: Variant) -> String:
	var ec := ""
	var msg := ""
	if j is Dictionary:
		var d: Dictionary = j
		ec = String(d.get("error_code", d.get("error", "")))
		msg = String(d.get("msg", d.get("error_description", d.get("message", ""))))
	var texts := {
		"invalid_credentials": "E-Mail oder Passwort falsch.",
		"invalid_grant": "E-Mail oder Passwort falsch.",
		"email_not_confirmed": "Bitte bestätige zuerst deine E-Mail-Adresse (Link im Postfach).",
		"user_already_exists": "Diese E-Mail ist bereits registriert – melde dich an.",
		"email_exists": "Diese E-Mail ist bereits registriert – melde dich an.",
		"weak_password": "Das Passwort ist zu schwach (mindestens 6 Zeichen).",
		"email_address_invalid": "Ungültige E-Mail-Adresse.",
		"validation_failed": "Bitte E-Mail und Passwort prüfen.",
		"signup_disabled": "Neue Registrierungen sind im Supabase-Projekt deaktiviert.",
		"email_provider_disabled": "E-Mail-Anmeldung ist im Supabase-Projekt deaktiviert (Authentication → Providers → Email).",
		"provider_disabled": "Dieser Anmeldeweg ist im Supabase-Projekt nicht aktiviert.",
		"over_email_send_rate_limit": "Zu viele E-Mails in kurzer Zeit – bitte etwas warten.",
		"over_request_rate_limit": "Zu viele Versuche – bitte kurz warten.",
		"refresh_token_not_found": "Sitzung abgelaufen – bitte neu anmelden.",
		"refresh_token_already_used": "Sitzung abgelaufen – bitte neu anmelden.",
		"session_not_found": "Sitzung abgelaufen – bitte neu anmelden.",
		"same_password": "Das neue Passwort muss sich vom alten unterscheiden.",
		"user_not_found": "Kein Konto mit dieser E-Mail.",
	}
	if texts.has(ec):
		return texts[ec]
	if msg.contains("Invalid API key") or msg.contains("No API key") or msg.contains("Invalid authentication credentials"):
		return "Supabase lehnt den API-Key ab – bitte den anon/publishable Key prüfen."
	if msg.contains("Invalid login credentials"):
		return "E-Mail oder Passwort falsch."
	if msg.contains("Email not confirmed"):
		return texts.email_not_confirmed
	if msg.contains("already registered"):
		return texts.user_already_exists
	if code == 429:
		return texts.over_request_rate_limit
	if code == 404:
		return "Supabase-Endpunkt nicht gefunden – Projekt-URL prüfen."
	if code >= 500:
		return "Supabase-Serverfehler (%d) – bitte später erneut versuchen." % code
	return "Anmeldung fehlgeschlagen (%s)." % (msg if msg != "" else "HTTP %d" % code)


# --- Auth (GoTrue) -----------------------------------------------------------------------------------------------

func fetch_settings() -> Dictionary:
	var r := await request(HTTPClient.METHOD_GET, "/auth/v1/settings", null, "", [], 6.0)
	if r.ok and r.json is Dictionary:
		settings = r.json
	return r


func google_enabled() -> bool:
	var ext: Variant = settings.get("external", {})
	return ext is Dictionary and bool((ext as Dictionary).get("google", false))


func sign_up(email: String, password: String, name: String, redirect := "") -> Dictionary:
	var q := ("?redirect_to=" + redirect.uri_encode()) if redirect != "" else ""
	return await request(HTTPClient.METHOD_POST, "/auth/v1/signup" + q,
		{"email": email, "password": password, "data": {"display_name": name, "name": name}})


func sign_in(email: String, password: String) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password", {"email": email, "password": password})


func refresh(refresh_token: String) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": refresh_token})


func recover(email: String, redirect := "") -> Dictionary:
	var q := ("?redirect_to=" + redirect.uri_encode()) if redirect != "" else ""
	return await request(HTTPClient.METHOD_POST, "/auth/v1/recover" + q, {"email": email})


func get_user(access_token: String) -> Dictionary:
	return await request(HTTPClient.METHOD_GET, "/auth/v1/user", null, access_token)


func update_user(access_token: String, attrs: Dictionary) -> Dictionary:
	return await request(HTTPClient.METHOD_PUT, "/auth/v1/user", attrs, access_token)


func sign_out(access_token: String) -> void:
	await request(HTTPClient.METHOD_POST, "/auth/v1/logout", null, access_token, [], 5.0)


## Browser-Weiterleitung zum OAuth-Anbieter (Implicit Flow: Tokens kommen im #-Fragment zurück).
func authorize_url(provider: String, redirect: String) -> String:
	return "%s/auth/v1/authorize?provider=%s&redirect_to=%s" % [url, provider.uri_encode(), redirect.uri_encode()]


# --- Profil (PostgREST, Tabelle public.profiles – siehe supabase/schema.sql) ---------------------------------------

func get_profile(access_token: String, uid: String) -> Dictionary:
	return await request(HTTPClient.METHOD_GET, "/rest/v1/profiles?id=eq.%s&select=data" % uid.uri_encode(), null, access_token)


func put_profile(access_token: String, uid: String, name: String, data: Dictionary) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/rest/v1/profiles?on_conflict=id",
		{"id": uid, "name": name, "data": data, "updated_at": Time.get_datetime_string_from_system(true) + "Z"},
		access_token, ["Prefer: resolution=merge-duplicates,return=minimal"])


## Aus einer GoTrue-Sitzungsantwort bzw. einem User-Objekt die Spieler-Daten lesen.
static func user_info(u: Dictionary) -> Dictionary:
	var meta: Dictionary = u.get("user_metadata", {}) if u.get("user_metadata", {}) is Dictionary else {}
	var app: Dictionary = u.get("app_metadata", {}) if u.get("app_metadata", {}) is Dictionary else {}
	var email := String(u.get("email", ""))
	var name := String(meta.get("display_name", meta.get("full_name", meta.get("name", ""))))
	if name == "":
		name = email.get_slice("@", 0) if email != "" else "Spieler"
	return {"uid": String(u.get("id", "")), "name": name, "email": email, "provider": "supabase",
		"via": String(app.get("provider", "email"))}
