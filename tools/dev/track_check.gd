extends Node
## Streckenprüfer für Nitro Dash: baut jede Strecke und prüft die Geometrie.
##   godot --headless --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/track_check.gd [--only=id] [--json=pfad]
## Prüft: Länge & geschätzte Rundenzeit, Selbstüberschneidung der Fahrbahn (ohne Brücken mit genug Höhe),
## engste Kurvenradien (ohne Loopings), Steigungen, Schließfehler des Baukastens, Anzahl Item-Reihen.
## Ausgabe: "TRACK {json}" je Strecke, "TRACK-FEHLER …" bei Problemen; --json schreibt die Mittellinien (für Draufsichten).

func run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var ids: Array = []
	for t in Game.TRACKS:
		ids.append(String(t.id))
	if args.has("only"):
		ids = String(args.only).split(",")
	var dump := {}
	var fails := 0
	for id in ids:
		var d := TrackDefs.get_def(String(id))
		var tr := RaceTrack.new()
		add_child(tr)
		tr.build(d)
		var res := {"id": id, "length_m": snappedf(tr.length, 1.0), "lap_est_s": snappedf(tr.length / 25.0, 0.1), "width": tr.width,
			"close_err_m": snappedf(float(d.get("close_err", 0.0)), 0.1), "item_rows": tr.item_rows.size()}
		var pts: Array = []
		var step := 3.0
		var n := int(tr.length / step)
		for i in n:
			var o := tr.frame(i * step).origin
			pts.append([snappedf(o.x, 0.1), snappedf(o.y, 0.1), snappedf(o.z, 0.1)])
		# Überschneidung
		var overlaps: Array = []
		var min_gap := INF
		for i in n:
			var a: Array = pts[i]
			for j in range(i + 1, n):
				var along := minf(float(j - i), float(n - (j - i))) * step
				if along < tr.width * 3.0:
					continue
				var b: Array = pts[j]
				var hd := Vector2(float(a[0]) - float(b[0]), float(a[2]) - float(b[2])).length()
				var vd := absf(float(a[1]) - float(b[1]))
				if vd < 5.5:
					min_gap = minf(min_gap, hd - tr.width)
					if hd < tr.width + 2.0 and not (tr.is_loop(i * step) or tr.is_loop(j * step)):
						overlaps.append([snappedf(i * step, 1.0), snappedf(j * step, 1.0)])
		# Radien & Steigung
		var min_r := INF
		var min_r_s := 0.0
		var max_slope := 0.0
		var max_slope_s := 0.0
		for i in n:
			var s := i * step
			if tr.is_loop(s) or tr.is_glide(s):
				continue
			var k := absf(tr.curvature(s, 0.0))
			if k > 0.0001 and 1.0 / k < min_r:
				min_r = 1.0 / k
				min_r_s = s
			var y0 := tr.frame(s).origin.y
			var y1 := tr.frame(s + step).origin.y
			var sl := absf(y1 - y0) / step
			if sl > max_slope and not tr.is_loop(s + step):
				max_slope = sl
				max_slope_s = s
		res["min_radius_m"] = snappedf(min_r, 0.1)
		res["min_radius_at"] = snappedf(min_r_s, 1.0)
		res["max_slope"] = snappedf(max_slope, 0.01)
		res["min_gap_m"] = snappedf(min_gap, 0.1)
		res["overlaps"] = overlaps.slice(0, 6)
		print("TRACK " + JSON.stringify(res))
		if not overlaps.is_empty():
			print("TRACK-FEHLER %s: Fahrbahn überschneidet sich (%d Stellen, z. B. s=%s)" % [id, overlaps.size(), str(overlaps[0])])
			fails += 1
		if min_r < 9.0:
			print("TRACK-FEHLER %s: Kurve zu eng (r=%.1f m bei s=%.0f)" % [id, min_r, min_r_s])
			fails += 1
		if max_slope > 0.35:
			print("TRACK-FEHLER %s: zu steil (%.2f bei s=%.0f)" % [id, max_slope, max_slope_s])
			fails += 1
		if float(d.get("close_err", 0.0)) > 25.0:
			print("TRACK-FEHLER %s: Baukasten schließt schlecht (%.1f m)" % [id, float(d.close_err)])
			fails += 1
		var feats := {"ramps": tr.ramp_s, "items": tr.item_rows, "boosts": tr.boosts.map(func(b: Vector2) -> Array: return [b.x, b.y]),
			"glide": tr.glide_ranges.map(func(g: Vector2) -> Array: return [g.x, g.y]), "water": tr.water_ranges.map(func(g: Vector2) -> Array: return [g.x, g.y]),
			"ice": tr.ice_ranges.map(func(g: Vector2) -> Array: return [g.x, g.y]), "wet": tr.wet_ranges.map(func(g: Vector2) -> Array: return [g.x, g.y]),
			"dividers": tr.dividers, "bounces": tr.bounces, "hazards": tr.hazards}
		dump[id] = {"pts": pts, "step": step, "width": tr.width, "feats": feats, "name": String(d.get("name", id))}
		tr.queue_free()
	if args.has("json"):
		var f := FileAccess.open(String(args.json), FileAccess.WRITE)
		f.store_string(JSON.stringify(dump))
	print("TRACKS %s – %d Probleme" % ["OK" if fails == 0 else "FEHLER", fails])
	get_tree().quit(1 if fails > 0 else 0)
