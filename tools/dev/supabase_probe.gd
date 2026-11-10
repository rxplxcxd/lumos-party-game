extends Node
## Durchlauf der Supabase-Anmeldung gegen einen echten oder nachgebauten Server:
##   LUMOS_SUPABASE_URL=http://127.0.0.1:54321 LUMOS_SUPABASE_KEY=<anon> \
##   godot --headless --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/supabase_probe.gd
## Registrieren → falsches Passwort → Login → Profil hoch/runter → Token-Refresh → Abmelden.

var _fails := 0


func run() -> void:
	if not Account.supabase_ready():
		printerr("Supabase nicht konfiguriert (LUMOS_SUPABASE_URL/_KEY)")
		return
	await Account._sb_settings()
	print("settings google=", Account.sb.google_enabled())
	var email := "probe%d@lumos.test" % (randi() % 100000)
	Account.register_email(email, "geheim123", "Probe-Held")
	await _idle()
	_expect(Account.signed_in() or Account.last_error == "", "Registrierung: " + str(Account.user) + " " + Account.last_error)
	if Account.signed_in():
		_expect(Account.display_name() == "Probe-Held", "Anzeigename " + Account.display_name())
		Account.logout()
	Account.register_email(email, "geheim123", "X")
	await _idle()
	_expect(Account.last_error.contains("bereits registriert"), "doppelte Registrierung: " + Account.last_error)
	Account.login_email(email, "falsch999")
	await _idle()
	_expect(not Account.signed_in() and Account.last_error == "E-Mail oder Passwort falsch.", "falsches Passwort: " + Account.last_error)
	Account.login_email(email, "geheim123")
	await _idle()
	_expect(Account.signed_in() and Account.last_error == "", "Login: " + str(Account.user) + " " + Account.last_error)
	Account.profile.stats.races = 7
	await Account._push_profile()
	Account.profile.stats.races = 0
	await Account._fetch_profile()
	_expect(int(Account.profile.stats.races) == 7, "Profil-Sync races=" + str(Account.profile.stats.races))
	Account._sb_exp = 0.0
	var old := Account._sb_access
	var tok: String = await Account._sb_token()
	_expect(tok != "" and tok != old, "Token-Refresh")
	Account.logout()
	await get_tree().process_frame
	_expect(not Account.signed_in(), "Abmelden")
	print("SUPABASE-PROBE: %s" % ("OK" if _fails == 0 else "%d FEHLER" % _fails))


func _idle() -> void:
	await get_tree().process_frame
	var t := 0.0
	while Account.busy and t < 10.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await get_tree().create_timer(0.2).timeout


func _expect(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails += 1
