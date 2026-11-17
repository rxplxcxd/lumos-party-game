extends Node
## Linsentropfen im Split-Screen (ab 1.5.3): Gewitterstrecke, 4 Fahrer als Spieler (--split-test), Linse erzwungen
## (LUMOS_LENS). Prüft nach 12 s Rennen: jede Ansicht hat eine eigene Linse mit Tropfen, die Vollbild-Linse bleibt leer,
## jede Linse liest nur ihr eigenes Rechteck (view_rect = Lage der Ansicht), Tropfen liegen innerhalb der Ansicht.
##   LUMOS_LENS=1 godot --headless --fixed-fps 60 --path . res://tools/dev/Run.tscn -- \
##     --dev-script=res://tools/dev/lens_split_test.gd --split-test
## Ausgabe: "LENS {json}" und "LENS-SPLIT OK" bzw. "LENS-FEHLER …".


func run() -> void:
	var tree := get_tree()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_parent().remove_child.call_deferred(self)
	tree.root.add_child.call_deferred(self)
	await tree.process_frame
	await tree.process_frame
	tree.root.size = Vector2i(1280, 720)
	for i in Game.players.size():
		Game.players[i].cpu = true
	Game.settings["split_screen"] = true
	Game.race_cfg = {"track": "storm_pass", "laps": 2, "cpu_level": 1, "mode": "single", "cup": 0}
	Game.mode = "race"
	var path := "res://scenes/racer/NitroDash.tscn"
	Router.goto(path, {})
	for k in 60 * 120:   # Streckenaufbau dauert headless eine Weile
		await tree.process_frame
		if not Router.busy and tree.current_scene and tree.current_scene.scene_file_path == path:
			break
	var nd: Node = tree.current_scene
	if nd == null or nd.scene_file_path != path:
		print("LENS-FEHLER Rennszene nicht geladen")
		tree.quit(1)   # der Szenenwechsel hat den Dev-Runner entfernt – selbst beenden
		return
	for k in 60 * 40:   # Countdown abwarten, dann 12 s Rennen
		await tree.process_frame
		if String(nd.get("state")) == "race":
			break
	for k in 60 * 12:
		await tree.process_frame
	var fails: Array = []
	var views: Array = nd.get("views")
	var info := {"ansichten": views.size(), "je_ansicht": []}
	if views.size() < 2:
		fails.append("kein Split-Screen (%d Ansichten)" % views.size())
	var vs := tree.root.get_visible_rect().size
	for v in views:
		var lens: LensDrops = v.lens
		if lens == null:
			fails.append("Ansicht ohne eigene Linse")
			continue
		var gr: Rect2 = lens.get_global_rect()
		var want := Vector4(gr.position.x / vs.x, gr.position.y / vs.y, gr.end.x / vs.x, gr.end.y / vs.y)
		var gv: Variant = (lens.material as ShaderMaterial).get_shader_parameter("view_rect")
		var got: Vector4 = gv if gv is Vector4 else Vector4(0, 0, 1, 1)   # erst gesetzt, sobald Tropfen da sind
		var inside := 0   # Tropfen in der Ansicht (laufen sie am Rand hinaus, schneidet die Ansicht sie ab – gewollt)
		for d in lens._drops:
			var p: Vector2 = d.p
			if p.x >= 0.0 and p.y >= 0.0 and p.x <= 1.0 and p.y <= 1.0:
				inside += 1
		var vr: Rect2 = (v as Control).get_global_rect()
		info.je_ansicht.append({"tropfen": lens._drops.size(), "regen": snappedf(lens.rain, 0.1), "rechteck": [vr.position, vr.size], "linse": [gr.position, gr.size],
			"linse_liest": [snappedf(got.x, 0.001), snappedf(got.y, 0.001), snappedf(got.z, 0.001), snappedf(got.w, 0.001)], "innerhalb": inside})
		if not gr.is_equal_approx(vr):
			fails.append("Linse deckt nicht genau ihre Ansicht ab")
		if lens._drops.size() > 0 and not got.is_equal_approx(want):
			fails.append("view_rect passt nicht zur Ansicht")
		if lens._drops.size() > 0 and inside == 0:
			fails.append("kein Tropfen in der eigenen Ansicht")
	var total := 0
	for e: Dictionary in info.je_ansicht:
		total += int(e.tropfen)
	if total == 0:
		fails.append("in keiner Ansicht Tropfen (Gewitter sollte regnen)")
	var main_lens: LensDrops = nd.get("_lens")
	info["vollbild_tropfen"] = main_lens._drops.size() if main_lens else -1
	if main_lens and main_lens._drops.size() > 0:
		fails.append("Vollbild-Linse hat im Split-Screen Tropfen")
	print("LENS " + JSON.stringify(info))
	if fails.is_empty():
		print("LENS-SPLIT OK")
	else:
		for f in fails:
			print("LENS-FEHLER " + String(f))
	tree.quit(0 if fails.is_empty() else 1)   # der Szenenwechsel hat den Dev-Runner entfernt – selbst beenden
