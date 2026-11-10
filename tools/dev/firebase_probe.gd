extends Node
## Prüft Firebase Auth über den nativen REST-Weg (gleiche Endpunkte/Key wie das Spiel), ohne Spuren:
##   1. Login mit einem nicht existierenden Konto → erwartet „E-Mail oder Passwort falsch.“ (legt nichts an)
##   2. --anon: anonyme Anmeldung (für Online-Lobbys) und sofortiges Löschen dieses Gast-Kontos
## godot --headless --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/firebase_probe.gd [--anon]

var _fails := 0


func run() -> void:
	Account.login_email("niemand-%d@example.invalid" % (randi() % 100000), "xxxxxx99")
	await _idle()
	_expect(Account.last_error == "E-Mail oder Passwort falsch.", "E-Mail-Login erreicht Firebase: " + Account.last_error)
	if "--anon" in OS.get_cmdline_user_args():
		await Account.ensure_online_identity()
		_expect(Account.fb_uid != "", "Anonyme Anmeldung (Lobbys): uid=" + Account.fb_uid)
		if Account._fb_id != "":
			var r: Dictionary = await Account._http(HTTPClient.METHOD_POST, Account.FB_AUTH + "delete?key=" + Account.FB_KEY,
				["Content-Type: application/json"], JSON.stringify({"idToken": Account._fb_id}))
			_expect(r.ok, "Test-Gastkonto wieder gelöscht")
		Account.logout()
	print("FIREBASE-PROBE: %s" % ("OK" if _fails == 0 else "%d FEHLER" % _fails))


func _idle() -> void:
	await get_tree().process_frame
	var t := 0.0
	while Account.busy and t < 15.0:
		await get_tree().process_frame
		t += get_process_delta_time()


func _expect(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails += 1
