extends Node
## Qualitäts-Sweep für ein Minispiel mit 4 CPU-Spielern (Schnellvorlauf: headless + --fixed-fps 60).
## Gibt eine Zeile "SWEEP {json}" aus: Spieldauer, Ende, durchgefallene/feststeckende Figuren, Text-Überläufe.
##   godot --headless --fixed-fps 60 --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/minigame_sweep.gd --only=bubble_ballet [--cat=2v2]
## Alle Spiele: tools/dev/minigame_sweep.sh

var _overflow: Dictionary = {}


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
	var id := String(args.get("only", ""))
	var m: Dictionary = Game.minigame_info(id)
	if m.is_empty() or not m.has("scene"):
		print("SWEEP " + JSON.stringify({"id": id, "error": "unbekannt"}))
		tree.quit()
		return
	var cats: Array = m.get("cats", ["ffa"])
	var cat := String(args.get("cat", cats[0] if not cats.is_empty() else "ffa"))
	# --levels=0,1,2,3 setzt die CPU-Stufe je Slot (Standard: wie gespeichert)
	var lv_arg := String(args.get("levels", "")).split(",", false)
	for i in Game.players.size():
		Game.players[i].cpu = true
		if i < lv_arg.size():
			Game.players[i].cpu_level = int(lv_arg[i])
	Game.mode = "free_play"
	var cs := {"cat": cat}
	if cat == "2v2":
		cs["teams"] = [0, 1, 0, 1]
	elif cat == "duel":
		cs["active"] = [true, true, false, false]
	elif cat == "1v3":
		cs["solo"] = 0
	Game.minigame_setup = cs
	tree.change_scene_to_file(String(m.scene))
	var mg: MinigameBase = null
	for i in 120:
		await tree.process_frame
		if tree.current_scene is MinigameBase:
			mg = tree.current_scene
			break
	if mg == null:
		print("SWEEP " + JSON.stringify({"id": id, "cat": cat, "error": "keine MinigameBase"}))
		tree.quit()
		return
	var dt := 1.0 / 60.0
	var t := 0.0
	var play_t := 0.0
	var intro_t := 0.0
	var fell := 0
	var below := [false, false, false, false]
	var inside := [0, 0, 0, 0]
	var limit := mg.time_limit
	var ended := ""
	var alive_start: Array = []
	var space := mg.get_world_3d().direct_space_state
	var q := PhysicsPointQueryParameters3D.new()
	q.collide_with_areas = false
	q.collide_with_bodies = true
	while true:
		await tree.physics_frame
		t += dt
		if t > 0.2 and int(t / dt) % 30 == 0:
			_scan_ui(tree.root, mg.state)
		if mg.state == "intro" or mg.state == "setup":
			intro_t += dt
			if intro_t > 40.0:
				ended = "intro_haengt"
				break
			continue
		if mg.state == "play":
			if alive_start.is_empty():
				alive_start = mg.alive.duplicate()
			play_t += dt * Engine.time_scale   # Spielzeit (Hitstop/Zeitlupe laufen über Echtzeit)
			if args.has("trace") and int(play_t * 60.0) % 60 == 0:
				var tr := "t=%.0f alive=%s" % [play_t, str(mg.alive)]
				if "tiles" in mg:
					var cnt := {}
					for k in mg.tiles:
						cnt[mg.tiles[k].state] = int(cnt.get(mg.tiles[k].state, 0)) + 1
					tr += " platten=%s" % str(cnt)
				var ys := []
				for av in mg.avatars:
					ys.append(((av as Node3D).global_position.snapped(Vector3.ONE * 0.1)) if av else Vector3.ZERO)
				print("TRACE ", tr, " y=", ys)
			for i in 4:
				var av = mg.avatars[i]
				if not (av is PartyAvatar) or not mg.active[i] or not mg.alive[i]:
					continue
				var pa := av as PartyAvatar
				if not pa.is_inside_tree():
					continue
				if pa.global_position.y < mg.kill_y - 4.0 and not below[i]:
					below[i] = true
					fell += 1
				# Körpermitte in fester Geometrie (eigener Körper ausgenommen)?
				q.position = pa.global_position + Vector3.UP * 0.9 * pa.scale.y
				q.exclude = [pa.get_rid()]
				q.collision_mask = 1
				for hit in space.intersect_point(q, 4):
					var col = hit.get("collider")
					if col is StaticBody3D or col is AnimatableBody3D:
						inside[i] += 1
						break
			if play_t > limit + 45.0:
				ended = "haengt_in_play"
				break
		elif mg.state == "finish" or mg.state == "results":
			ended = "ok"
			break
		if t > limit + 120.0:
			ended = "timeout_" + mg.state
			break
	var inside_s: Array = []
	for i in 4:
		inside_s.append(snappedf(inside[i] * dt, 0.1))
	print("SWEEP " + JSON.stringify({"id": id, "cat": cat, "end": ended, "play": snappedf(play_t, 0.1), "limit": limit,
		"intro": snappedf(intro_t, 0.1), "alive_start": alive_start, "alive_end": mg.alive, "durchgefallen": fell, "in_geometrie_s": inside_s, "survival": mg.survival,
		"race": mg.race, "scores": mg.scores, "ueberlauf": _overflow}))
	tree.quit()


## Sichtbare Texte, die über den Bildschirm oder ihre eigene Box hinausragen.
func _scan_ui(n: Node, phase: String) -> void:
	var vp := get_viewport().get_visible_rect()
	for l in n.find_children("*", "Label", true, false):
		var lb := l as Label
		if not lb.is_visible_in_tree() or lb.text.strip_edges() == "" or lb.modulate.a < 0.2:
			continue
		var r := lb.get_global_rect()
		var font := lb.get_theme_font("font")
		var fs := lb.get_theme_font_size("font_size")
		var w := font.get_string_size(lb.text.get_slice("\n", 0), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * lb.get_global_transform().get_scale().x
		var wrap := lb.autowrap_mode != TextServer.AUTOWRAP_OFF or lb.clip_text or lb.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
		# Gerade aufpoppende/skalierte Texte (Animation) und bildschirmbreite Boxen nicht über die Box bewerten,
		# sondern nur über die tatsächliche Textbreite
		var sc := lb.get_global_transform().get_scale().x
		if sc > 1.05:
			continue
		var centered := lb.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
		var off := not centered and (r.position.x < vp.position.x - 2.0 or r.end.x > vp.end.x + 2.0)
		var too_wide := not wrap and w > r.size.x + 4.0 and w > 0.0
		var cx := r.position.x + r.size.x * 0.5
		var text_off := not wrap and centered and (cx - w * 0.5 < -2.0 or cx + w * 0.5 > vp.end.x + 2.0)
		# Nur echte Probleme melden: Text ragt über den Bildschirmrand (sichtbar abgeschnitten)
		if off or text_off:
			var over := maxf(maxf(-(cx - w * 0.5), cx + w * 0.5 - vp.end.x), maxf(-r.position.x, r.end.x - vp.end.x))
			var k := "%s:%s" % [phase, lb.text.left(40).replace("\n", " ")]
			_overflow[k] = maxf(float(_overflow.get(k, 0.0)), snappedf(over, 1.0))
