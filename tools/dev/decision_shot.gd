extends Node
## Kontrollbild des Entscheidungs-Dialogs: links die Bedienansicht (lokaler Mensch), rechts die Zuschauer-
## Ansicht (CPU bzw. Mitspieler entscheidet – ohne Knöpfe, mit Markierung).
##   xvfb-run ./godot --path . --resolution 1280x720 res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/decision_shot.gd --out=/pfad


func run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var tree := get_tree()
	get_parent().remove_child.call_deferred(self)
	tree.root.add_child.call_deferred(self)
	await tree.process_frame
	await tree.process_frame
	var out := String(args.get("out", "user://shots"))
	DirAccess.make_dir_recursive_absolute(out)
	Game.reset_players(1)
	Game.start_party("meadow", 5, "classic")
	Game.party.first_intro_done = true
	Game.party.round_started = 1
	Game.players[0].items = ["double_dice", "warp_card"]
	Game.players[1].items = ["double_dice", "warp_card"]
	var board: Node = load("res://scenes/party/PartyBoard.tscn").instantiate()
	add_child(board)
	for k in 30:
		await tree.process_frame
	board.set_process(false)
	var labels := ["Doppelwürfel\nZwei Würfel: 2–20 Felder", "Platztausch-Karte\nTausche den Platz", "Kein Item"]
	# Zuschauer-Ansicht: CPU (Platz 1) entscheidet
	board.call("_decision_panel", 1, "Item benutzen?", labels, [Color("#43b8c9"), Color("#43b8c9"), Color("#8a5a3c")], 1, [], 2, 1, 22, 460.0, 3.0, 0.5)
	for k in 125:
		await tree.process_frame
	tree.root.get_texture().get_image().save_png(out + "/decision_spectator.png")
	for k in 120:
		await tree.process_frame
	# Bedienansicht: lokaler Mensch (Platz 0)
	board.call("_decision_panel", 0, "Item benutzen?", labels, [Color("#43b8c9"), Color("#43b8c9"), Color("#8a5a3c")], 2, [], 2, 1, 22, 460.0, 6.0, 0.5)
	for k in 30:
		await tree.process_frame
	tree.root.get_texture().get_image().save_png(out + "/decision_player.png")
	print("SHOTS OK")
	tree.quit()
