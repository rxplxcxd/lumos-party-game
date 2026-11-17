extends Node
## Projektinventar aus dem tatsächlichen Code (keine Handpflege): Minispiele, Strecken, Bretter, Bosse, Figuren,
## Modi, Systeme. Prüft je Eintrag, ob Szene und Skript existieren. Schreibt data/project_inventory.json und gibt
## Abweichungen zu README/CHANGELOG aus.
##   godot --headless --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/inventory.gd [--out=pfad]


func run() -> void:
	var out_path := "res://data/project_inventory.json"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--out="):
			out_path = String(a).substr(6)
	var inv := {"version": String(ProjectSettings.get_setting("application/config/version", "")), "godot": Engine.get_version_info().string}
	# --- Minispiele ---------------------------------------------------------------------------------------------
	var mgs: Array = []
	var cats := {}
	var kinds := {}
	var problems: Array = []
	for m: Dictionary in Game.MINIGAMES:
		var scene := String(m.get("scene", ""))
		var ok := scene != "" and ResourceLoader.exists(scene)
		var script := ""
		if ok:
			var st := (load(scene) as PackedScene).get_state()
			for pi in st.get_node_property_count(0):
				if st.get_node_property_name(0, pi) == "script":
					script = (st.get_node_property_value(0, pi) as Script).resource_path
		if not ok:
			problems.append("Minispiel %s: Szene fehlt (%s)" % [m.id, scene])
		for c: String in m.get("cats", ["ffa"]):
			cats[c] = int(cats.get(c, 0)) + 1
		kinds[String(m.get("kind", ""))] = int(kinds.get(String(m.get("kind", "")), 0)) + 1
		mgs.append({"id": m.id, "name": m.name, "kind": m.get("kind", ""), "cats": m.get("cats", ["ffa"]), "online": bool(m.get("online", false)),
			"scene": scene, "script": script, "playable": ok and script != "", "controls": m.get("controls", "")})
	inv["minigames"] = {"count": mgs.size(), "playable": mgs.filter(func(e: Dictionary) -> bool: return e.playable).size(), "by_category": cats, "by_kind": kinds, "list": mgs}
	# Skripte in scripts/minigames, die in keinem Katalogeintrag stehen (Hilfsdateien ausgenommen)
	var used := {}
	for e: Dictionary in mgs:
		used[String(e.script)] = true
	var orphan: Array = []
	for f in DirAccess.get_files_at("res://scripts/minigames"):
		if f.ends_with(".gd") and not used.has("res://scripts/minigames/" + f) and not f in ["minigame_base.gd", "mg_kit.gd"]:
			orphan.append(f)
	inv["minigames"]["scripts_without_catalog_entry"] = orphan
	# --- Strecken -----------------------------------------------------------------------------------------------
	var tracks: Array = []
	for t: Dictionary in Game.TRACKS:
		var d: Dictionary = TrackDefs.get_def(String(t.id))
		var pts: Array = d.get("points", [])
		var length := 0.0
		var ymin := INF
		var ymax := -INF
		var turn := 0.0
		for i in pts.size():
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[(i + 1) % pts.size()]
			var c: Vector3 = pts[(i + 2) % pts.size()]
			length += a.distance_to(b)
			ymin = minf(ymin, a.y)
			ymax = maxf(ymax, a.y)
			var d1 := Vector2(b.x - a.x, b.z - a.z)
			var d2 := Vector2(c.x - b.x, c.z - b.z)
			if d1.length() > 0.01 and d2.length() > 0.01:
				turn += absf(d1.angle_to(d2))
		# Selbstüberschneidung: zwei Stellen der Runde (mehr als 70 m Fahrweg auseinander), die sich im Grundriss näher
		# kommen als eine Fahrbahnbreite, ohne mindestens 6 m Höhenunterschied (Brücke) – dort lägen Fahrbahnen ineinander.
		var cum: Array = [0.0]
		for i in pts.size():
			cum.append(float(cum[i]) + (pts[i] as Vector3).distance_to(pts[(i + 1) % pts.size()]))
		var overlaps := 0
		var closest := INF
		var w := float(d.get("width", 15.0))
		for i in pts.size():
			for j in range(i + 1, pts.size()):
				var along := float(cum[j]) - float(cum[i])
				if minf(along, length - along) < 70.0:
					continue
				var pa: Vector3 = pts[i]
				var pb: Vector3 = pts[j]
				var hd := Vector2(pa.x - pb.x, pa.z - pb.z).length()
				if absf(pa.y - pb.y) < 6.0:
					closest = minf(closest, hd)
					if hd < w:
						overlaps += 1
		if overlaps > 0:
			problems.append("Strecke %s: %d Überschneidungen ohne Höhenabstand (engste Stelle %.1f m bei Breite %.0f m)" % [t.id, overlaps, closest, w])
		if d.has("weave_skipped"):
			problems.append("Strecke %s: gestaltete Rückgerade passt nicht (%s)" % [t.id, d.weave_skipped])
		# längste Gerade der Runde (Kontrollpunkte ohne Richtungsänderung)
		var run := 0.0
		var longest := 0.0
		for i in pts.size() * 2:
			var a2: Vector3 = pts[i % pts.size()]
			var b2: Vector3 = pts[(i + 1) % pts.size()]
			var c2: Vector3 = pts[(i + 2) % pts.size()]
			var e1 := Vector2(b2.x - a2.x, b2.z - a2.z)
			var e2 := Vector2(c2.x - b2.x, c2.z - b2.z)
			run = run + e1.length() if absf(e1.angle_to(e2)) < 0.03 else 0.0
			longest = maxf(longest, run)
		var feats := {}
		for k in ["loops", "glide", "water", "ice", "ramps", "boosts", "items"]:
			feats[k] = (d.get(k, []) as Array).size()
		var extra: Array = []
		for k: String in d.keys():
			if not k in ["id", "name", "env", "theme", "width", "points", "loops", "glide", "water", "ice", "ramps", "boosts", "items", "bank", "ground_y", "desc"]:
				var v: Variant = d[k]
				extra.append("%s:%d" % [k, (v as Array).size() if v is Array else ((v as Dictionary).size() if v is Dictionary else 1)])
		tracks.append({"id": t.id, "name": t.name, "env": d.get("env", ""), "theme": d.get("theme", ""), "width": d.get("width", 0.0),
			"length_m": snappedf(length, 1.0), "height_range_m": snappedf(ymax - ymin, 0.1), "total_turn_deg": snappedf(rad_to_deg(turn), 1.0),
			"features": feats, "mechanics": extra, "hazards": (d.get("hazards", []) as Array).map(func(h: Dictionary) -> String: return TrackMechanics.skin_of(h)),
			"closest_self_distance_m": snappedf(closest, 0.1), "self_overlaps": overlaps,
			"longest_straight_m": snappedf(longest, 1.0), "close_straight_m": snappedf(float(d.get("close_straight", 0.0)), 1.0)})
	for a in OS.get_cmdline_user_args():   # --points=datei.json: Grundrisse aller Strecken (für Zeichnungen beim Streckenbau)
		if String(a).begins_with("--points="):
			var pl := {}
			for t: Dictionary in Game.TRACKS:
				var d2: Dictionary = TrackDefs.get_def(String(t.id))
				var marks := {}
				for k in ["ramps", "items"]:
					marks[k] = d2.get(k, [])
				pl[String(t.id)] = {"pts": (d2.points as Array).map(func(v: Vector3) -> Array: return [snappedf(v.x, 0.1), snappedf(v.y, 0.1), snappedf(v.z, 0.1)]), "width": d2.width,
					"glide": d2.get("glide", []), "loops": (d2.get("loops", []) as Array).map(func(l: Dictionary) -> Array: return [l.from, l.to]), "marks": marks}
			var pf := FileAccess.open(String(a).substr(9), FileAccess.WRITE)
			pf.store_string(JSON.stringify(pl))
			pf.close()
	inv["tracks"] = {"count": tracks.size(), "cups": Game.CUPS.map(func(c: Dictionary) -> Dictionary: return {"id": c.id, "name": c.name, "tracks": c.tracks}), "list": tracks}
	# --- Bretter ------------------------------------------------------------------------------------------------
	var boards: Array = []
	for b: Dictionary in Game.BOARDS:
		var def: Dictionary = BoardDefs.get_def(String(b.id))
		var graph: Array = BoardDefs.build_graph(def) if not def.is_empty() else []
		var types := {}
		var branches := 0
		for n: Dictionary in graph:
			var ty := String(n.get("type", "?"))
			types[ty] = int(types.get(ty, 0)) + 1
			if (n.get("next", []) as Array).size() > 1:
				branches += 1
		if def.is_empty():
			problems.append("Brett %s: keine Definition" % b.id)
		boards.append({"id": b.id, "name": b.name, "music": b.get("music", ""), "spaces": graph.size(), "branch_points": branches, "space_types": types,
			"boss": BossDefs.for_board(String(b.id))})
	inv["boards"] = {"count": boards.size(), "party_modes": Game.PARTY_MODES.map(func(p: Dictionary) -> String: return String(p.id)), "list": boards}
	# --- Bosse, Figuren, Modi -----------------------------------------------------------------------------------
	var bosses: Array = []
	for id: String in BossDefs.BOSSES:
		var bd: Dictionary = BossDefs.BOSSES[id]
		bosses.append({"id": id, "name": bd.get("name", id), "attacks": (bd.get("attacks", []) as Array).size(), "hp": bd.get("hp", 0)})
	inv["bosses"] = {"count": bosses.size(), "list": bosses}
	var heroes: Array = []
	for h: Dictionary in Game.HEROES:
		heroes.append({"id": h.id, "name": h.name, "model": h.model, "model_exists": Assets.has_model(String(h.model)) if Assets.has_method("has_model") else true})
	inv["characters"] = {"count": heroes.size(), "list": heroes}
	var modes: Array = []
	for f in DirAccess.get_files_at("res://scenes/modes"):
		if f.ends_with(".tscn"):
			modes.append("scenes/modes/" + f)
	inv["modes"] = {"party_modes": Game.PARTY_MODES.map(func(p: Dictionary) -> String: return String(p.name)), "scenes": modes,
		"race_modes": ["single", "grand_prix", "time_trial", "split_screen", "online"], "other": ["free_play", "marathon"]}
	# --- Systeme ------------------------------------------------------------------------------------------------
	var systems := {}
	for dir in ["autoload", "scripts/core", "scripts/actor", "scripts/party", "scripts/racer", "scripts/bosses", "scripts/modes", "scripts/net", "scripts/ui", "scripts/minigames"]:
		var n := 0
		var lines := 0
		for f in DirAccess.get_files_at("res://" + dir):
			if f.ends_with(".gd"):
				n += 1
				lines += FileAccess.get_file_as_string("res://%s/%s" % [dir, f]).count("\n")
		systems[dir] = {"scripts": n, "lines": lines}
	inv["systems"] = systems
	# --- Abgleich mit der Dokumentation -------------------------------------------------------------------------
	var readme := FileAccess.get_file_as_string("res://README.md")
	var claims: Array = []
	var rx := RegEx.create_from_string("(\\d+)\\s+(Minispiele|Strecken|Bretter|Spielbretter|Bosse|Items)")
	for mm in rx.search_all(readme):
		claims.append("%s %s" % [mm.get_string(1), mm.get_string(2)])
	inv["doc_claims_readme"] = claims
	inv["problems"] = problems
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(inv, "  "))
	f.close()
	print("INVENTAR %d Minispiele (%d spielbar) · %d Strecken · %d Bretter · %d Bosse · %d Figuren · Probleme: %s" % [mgs.size(),
		int(inv.minigames.playable), tracks.size(), boards.size(), bosses.size(), heroes.size(), str(problems)])
	print("INVENTAR Kategorien %s · Arten %s · Skripte ohne Katalog %s" % [str(cats), str(kinds), str(orphan)])
	print("INVENTAR README nennt: %s" % str(claims))
	for t: Dictionary in tracks:
		print("INVENTAR Strecke %-14s %5.0f m · Höhe %5.1f m · Kurven %5.0f° · engste Eigen-Annäherung %5.1f m · längste Gerade %3.0f m (Rückgerade %3.0f m) · Gefahren %s" % [t.id, t.length_m, t.height_range_m, t.total_turn_deg, t.closest_self_distance_m, t.longest_straight_m, t.close_straight_m, str(t.hazards)])
	for b: Dictionary in boards:
		print("INVENTAR Brett %-11s %3d Felder · %d Abzweige · Boss %s · %s" % [b.id, b.spaces, b.branch_points, b.boss, str(b.space_types)])
