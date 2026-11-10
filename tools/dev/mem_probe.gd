extends Node
## Speicher-Sonde: wechselt wie eine CPU-Testrunde zwischen Brett und Minispielen und protokolliert den
## Speicher nach jedem Szenenwechsel (zeigt Lecks / wachsende Caches).
##   ./godot --headless --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/mem_probe.gd
func run() -> void:
	var tree := get_tree()
	var me := self
	get_parent().remove_child(me)
	tree.root.add_child.call_deferred(me)
	await tree.process_frame
	await tree.process_frame
	for p in Game.players:
		p.cpu = true
	Game.start_party("meadow", 10, String(Game.PARTY_MODES[0].id))
	var seq := ["res://scenes/party/PartyBoard.tscn", "res://scenes/minigames/SumoShove.tscn", "res://scenes/party/PartyBoard.tscn",
		"res://scenes/minigames/TugOfWar.tscn", "res://scenes/party/PartyBoard.tscn", "res://scenes/minigames/BossBattle.tscn",
		"res://scenes/party/PartyBoard.tscn", "res://scenes/minigames/GhostPhoto.tscn", "res://scenes/party/PartyBoard.tscn",
		"res://scenes/minigames/PenguinCurling.tscn", "res://scenes/party/PartyBoard.tscn", "res://scenes/minigames/CheeseBrawl.tscn",
		"res://scenes/party/PartyBoard.tscn"]
	var n_steps := seq.size() if not ("--orphans" in OS.get_cmdline_user_args()) else 5
	for k in n_steps:
		Game.mode = "party"
		Router.goto(seq[k])
		await get_tree().create_timer(7.0).timeout
		print("[MEM] %2d %-22s static %6.1f MB · objects %d · orphans %d · resources %d · assets-cache %d" % [k, String(seq[k]).get_file(),
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1e6, int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)), Assets._cache.size()])
		if "--orphans" in OS.get_cmdline_user_args() and k == 4:
			Node.print_orphan_nodes()
	get_tree().quit()
