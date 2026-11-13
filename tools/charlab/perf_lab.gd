extends Node3D
## Performance-Labor des Character-Frameworks (scripts/actor). Eigenständig – kein Teil der Spielabläufe.
##
##   godot --headless --fixed-fps 60 --path . res://tools/charlab/PerfLab.tscn -- --perf[=/ordner]    alle Szenarien
##       --perf-quick      nur 16 Figuren (0A, A, F, G1)          --perf-repeat=2   zweiter Durchlauf (Wiederholbarkeit)
##   xvfb-run -a godot --fixed-fps 60 --path . res://tools/charlab/PerfLab.tscn -- --perf-render[=/ordner]
##       mit Grafik: Renderzeit CPU/GPU des Viewports, Draw-Calls (0A, A, F, G1 mit 16 Figuren)
##   xvfb-run -a godot --fixed-fps 60 --path . res://tools/charlab/PerfLab.tscn -- --perf-shots=/ordner [--perf-vis=0]
##       Bildvergleich: Szenario D (Gefühle, Lachen, Winken) mit 4 Figuren in Nahaufnahme, alle 6 Bilder ein PNG
##       (vis = Sichtbarkeitsschwelle des Gesichts in Pixeln; 0 = bei jeder Änderung neu zeichnen = Referenz).
##       Globaler Zufall fest, Cartoon aus (Partikel haben eigenen Zufall) – beide Läufe rechnen dieselben Abläufe.
##
## Szenarien (je 1, 4, 8, 16 Figuren, 4 Heldenmodelle mit ihren Persönlichkeiten, feste Startwerte):
##   0A/0B  ohne Framework (nur Spiel-Animation) – stehend / in Bewegung: Vergleichsbasis
##   A  alle stehen, Mikroleben (Blicke, Gewichtsverlagerung, Gesten, Lidschlag, Atem)
##   B  alle bewegen sich (Gehen und Laufen im Kreis, Fußanker, Gewicht)
##   C  Paare interagieren nacheinander (High-Five, Handschlag, Umarmung, Klopfen, Hand nehmen …)
##   D  Gefühlsreaktionen im Wechsel, Lachen steckt an, Winken und Witze lösen soziale Reaktionen aus
##   E  Cartoon-Effekte gleichzeitig – erzwungen, ohne Budget (Worst Case: Tränen, Herzen, Sterne, Schweiß …)
##   F  alles zugleich, realistisch: Hälfte bewegt sich, Rest interagiert paarweise, Gefühle, Cartoon mit Budget
##   G1 wie F, Kamera abgewandt (alle außerhalb des Bildes) · G2 wie F, Kamera 50 m entfernt
##
## Je Lauf: 0,5 s Aufbau, 1 s Einschwingen, dann 240 Bilder ohne Messpunkte (Gesamtzeiten) und 240 Bilder mit
## Messpunkten (Aufschlüsselung je Teilsystem, LumosProf). Kennwerte: Mittel, Median, 95./99. Perzentil, Spitze.
## „Bild“ = Abstand zweier Bilder (headless: reine CPU, keine Grafik), „Framework“ = Summe der nicht verschachtelten
## Messabschnitte, „Rest“ = Bild − Framework im selben Bild (Spiel-Animation, Skelette, Tweens, Partikel, Effekt-
## Erzeugung, Lab-Steuerung). Gesichter: Neuzeichnungen je Gesicht und Sekunde (60 = jedes Bild).

const KEYS := ["hero/knight", "hero/mage", "hero/barbarian", "hero/ranger"]
const COUNTS: Array[int] = [1, 4, 8, 16]
const SCENES := {
	"0A": "ohne Framework, Stehen (nur Spiel-Animation)",
	"0B": "ohne Framework, Bewegung (nur Spiel-Animation)",
	"A": "Stehen mit Mikroleben",
	"B": "alle bewegen sich",
	"C": "Paare interagieren",
	"D": "Gefühlsreaktionen, soziale Ansteckung",
	"E": "Cartoon-Effekte gleichzeitig (erzwungen)",
	"F": "alles zugleich (realistisch)",
	"G1": "wie F, außerhalb des Bildes",
	"G2": "wie F, weit entfernt",
}
const TOP: Array[StringName] = [&"actor", &"face", &"body", &"loco", &"social.hub"]
const ORDER: Array[StringName] = [&"actor", &"actor.base", &"actor.mind", &"actor.micro", &"actor.gesture", &"actor.hat",
	&"actor.apart", &"actor.emotion", &"actor.gaze", &"actor.hands", &"actor.interact", &"actor.rigid", &"social.perceive", &"social.hub",
	&"interaction", &"face", &"face.draw", &"body", &"body.dyn", &"body.pose", &"body.feet", &"body.arms", &"body.jiggle",
	&"body.cache", &"loco"]
const LABEL := {
	&"actor": "LumosActor-Fassade gesamt", &"actor.base": "  Grundlauf (LOD, Geschwindigkeit)",
	&"actor.mind": "  Mind (Ereignisse, Reaktionen)", &"actor.micro": "  Mikroleben (Blicke, Gewicht, Kopf)",
	&"actor.gesture": "    davon Gesten-Engine", &"actor.hat": "  Hutkrempe weicht aus",
	&"actor.apart": "  Ausweichen bei Nähe (Durchdringungsschutz)",
	&"actor.emotion": "  Gefühlszustand + Persönlichkeit", &"actor.gaze": "  Blicksteuerung (Augen, Kopf, Brust)",
	&"actor.hands": "  Lachen, Hand-Ziele", &"actor.interact": "  Halten/Tragen (LumosInteract)",
	&"actor.rigid": "  Figuren ohne Skelett", &"social.perceive": "Wahrnehmung (in Mind/Mikro enthalten)",
	&"social.hub": "Sozialer Knoten", &"interaction": "  davon Interaktionsprotokoll",
	&"face": "LumosFace gesamt", &"face.draw": "  davon Neuzeichnen", &"body": "LumosBody gesamt",
	&"body.dyn": "  Gewicht/Trägheit (Federn)", &"body.pose": "  Haltung, Atem, Kopf, Armpendel",
	&"body.feet": "  Fußanker, Becken", &"body.arms": "  Arm-IK, Handausrichtung",
	&"body.jiggle": "  Zubehör/Sekundärbewegung", &"body.cache": "  Gelenkpositionen merken",
	&"loco": "LumosLocomotion",
}

var cam: Camera3D
var crowd: Array[LumosActor] = []
var homes: Array[Vector3] = []
var results: Array[Dictionary] = []
var _scn := ""
var _f := 0
var _rec := 0
var _last := 0
var _wall := PackedFloat64Array()
var _drv := PackedFloat64Array()
var _rcpu := PackedFloat64Array()
var _rgpu := PackedFloat64Array()
var _draws := PackedFloat64Array()
var _sec: Array = []
var _emos: Array[String] = []
var _toons: Array[String] = []
var _kinds: Array[String] = []
var _st := {}
var _frames := 240
var _render := false
var _quick := false
var _repeat := 1
var _out := ""
var _shots := ""


func _ready() -> void:
	Seasonal.test_override = "off"
	WorldKit.env(self, "day")
	WorldKit.box(self, Vector3(60, 1, 60), Vector3(0, -0.5, 0), Color("#7fc96a"), true)
	cam = Camera3D.new()
	add_child(cam)
	cam.fov = 42.0
	_cam_home()
	for k: String in LumosEmotion.META:
		if k != "neutral":
			_emos.append(k)
	_emos.sort()
	for k: String in LumosCartoon.available():
		_toons.append(k)
	for k: String in LumosInteraction.KINDS:
		if not (k in ["give", "help_up"]):   # Übergabe braucht einen Gegenstand, Aufhelfen eine Gestürzte – eigene Tests im Behavior Lab
			_kinds.append(k)
	var go := false
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--perf-render"):
			_render = true
			go = true
			_out = s.get_slice("=", 1) if s.contains("=") else ""
		elif s.begins_with("--perf-quick"):
			_quick = true
		elif s.begins_with("--perf-shots="):
			_shots = s.get_slice("=", 1)
		elif s.begins_with("--perf-vis="):
			LumosFace.vis_px = s.get_slice("=", 1).to_float()
		elif s.begins_with("--perf-frames="):
			_frames = maxi(30, s.get_slice("=", 1).to_int())
		elif s.begins_with("--perf-repeat="):
			_repeat = maxi(1, s.get_slice("=", 1).to_int())
		elif s.begins_with("--perf"):
			go = true
			_out = s.get_slice("=", 1) if s.contains("=") else ""
	if _shots != "":
		_shoot.call_deferred()
	elif go:
		_run_all.call_deferred()


## Bildvergleich: gleicher Ablauf (feste Startwerte, feste Bildrate), Nahaufnahme von 4 Figuren, 40 Bilder.
func _shoot() -> void:
	seed(4242)
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(_shots)
	_spawn(4)
	for a in crowd:
		a.cfg.cartoon = 0.0
	cam.position = Vector3(0, 1.55, 4.6)
	cam.look_at(Vector3(0, 1.05, 1.2))
	await _frames_wait(30)
	_st = {}
	_f = 0
	_scn = "D"
	for k in 240:
		await get_tree().process_frame
		if k % 6 == 5:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_shots.path_join("f%03d.png" % k))
	var dr := 0
	for a in crowd:
		dr += a.face.draws if a.face else 0
	print("[PERF] Bildvergleich gespeichert: %s · Sichtbarkeitsschwelle %.2f px · Gesichter neu gezeichnet: %d" % [_shots, LumosFace.vis_px, dr])
	get_tree().quit(0)


func _cam_home() -> void:
	cam.position = Vector3(0, 4.2, 8.5)
	cam.look_at(Vector3(0, 0.9, -1.2))


func _plan() -> Array:
	var plan: Array = []
	if _render or _quick:
		for s in ["0A", "A", "F", "G1"]:
			plan.append([s, 16])
		return plan
	for s: String in SCENES:
		for n in COUNTS:
			if s == "C" and n < 2:
				continue
			plan.append([s, n])
	return plan


func _run_all() -> void:
	await get_tree().process_frame
	if _render:
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var obj0 := Performance.get_monitor(Performance.OBJECT_COUNT)
	print("[PERF] %s · %s · %d Bilder je Messung · Kamera %.1f m vor der ersten Reihe" % [DisplayServer.get_name(),
		RenderingServer.get_video_adapter_name(), _frames, cam.position.distance_to(Vector3(0, 0.9, 1.2))])
	for rep in _repeat:
		for p: Array in _plan():
			var r := await _measure(String(p[0]), int(p[1]))
			r["rep"] = rep
			results.append(r)
			_print(r)
	var leak := Performance.get_monitor(Performance.OBJECT_COUNT) - obj0
	print("[PERF] Objekte nach allen Läufen: %+d gegenüber dem Start (Figuren, Effekte, Interaktionen aufgeräumt)" % int(leak))
	if _repeat > 1:
		_print_repeat()
	if _out != "":
		_save(leak)
	print("PERFLAB OK")
	get_tree().quit(0)


func _measure(scn: String, n: int) -> Dictionary:
	_spawn(n)
	await _frames_wait(30)
	if scn.begins_with("0"):
		for a in crowd:
			a.set_enabled(false)
	_st = {}
	_f = 0
	_scn = scn
	match scn:
		"G1":
			cam.look_at(cam.position + Vector3(0, 0, 30))
		"G2":
			cam.position = Vector3(0, 14, 50)
			cam.look_at(Vector3(0, 0.9, -1.2))
	await _frames_wait(60)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var dr0 := 0
	for a in crowd:
		dr0 += a.face.draws if a.face else 0
	LumosProf.on = false
	await _record()
	var dr1 := 0
	for a in crowd:
		dr1 += a.face.draws if a.face else 0
	var wall := _wall.duplicate()
	var drv := _drv.duplicate()
	var rend := [_rcpu.duplicate(), _rgpu.duplicate(), _draws.duplicate()]
	LumosProf.on = true
	await _record()
	LumosProf.on = false
	var sec := _sec.duplicate()
	var wall2 := _wall.duplicate()
	var lods := [0, 0, 0]
	for a in crowd:
		lods[clampi(a.lod, 0, 2)] += 1
	var faces := 0
	for a in crowd:
		if a.face:
			faces += 1
	_scn = ""
	await _clear()
	_cam_home()
	var r := {"scn": scn, "n": n, "wall": _stats(wall), "driver": _stats(drv), "nodes": int(nodes),
		"lod": lods, "faces": faces, "sec": {}, "fw": {}, "objects_after": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"face_draws_per_s": float(dr1 - dr0) / maxf(faces, 1) / (_frames / 60.0)}
	var fw := PackedFloat64Array()
	fw.resize(sec.size())
	var by := {}
	for k in ORDER:
		var v := PackedFloat64Array()
		v.resize(sec.size())
		for i in sec.size():
			v[i] = float(sec[i].get(k, 0)) / 1000.0
			if k in TOP:
				fw[i] += v[i]
		by[k] = v
	for k in ORDER:
		var st := _stats(by[k])
		if float(st.max) > 0.0:
			(r.sec as Dictionary)[String(k)] = st
	r.fw = _stats(fw)
	var rest := PackedFloat64Array()
	for i in mini(fw.size(), wall2.size()):
		rest.append(maxf(wall2[i] - fw[i], 0.0))
	r["rest"] = _stats(rest)
	r["max_sec"] = {}
	for k in ORDER:   # welcher Abschnitt verursacht Spitzen?
		var st: Dictionary = (r.sec as Dictionary).get(String(k), {})
		if not st.is_empty() and float(st.max) > 0.5:
			(r.max_sec as Dictionary)[String(k)] = st.max
	if _render:
		r["render_cpu"] = _stats(rend[0])
		r["render_gpu"] = _stats(rend[1])
		r["draws"] = _stats(rend[2])
	return r


func _record() -> void:
	_wall.clear()
	_drv.clear()
	_rcpu.clear()
	_rgpu.clear()
	_draws.clear()
	_sec.clear()
	LumosProf.take()
	await get_tree().process_frame
	await get_tree().process_frame
	LumosProf.take()
	_rec = _frames + 2   # die ersten beiden Bilder je Messung verworfen (Umschalten der Messpunkte)
	while _rec > 0:
		await get_tree().process_frame
	_wall = _wall.slice(2)
	_drv = _drv.slice(2)
	_rcpu = _rcpu.slice(2)
	_rgpu = _rgpu.slice(2)
	_draws = _draws.slice(2)
	_sec = _sec.slice(2)


func _frames_wait(k: int) -> void:
	for i in k:
		await get_tree().process_frame


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _rec > 0:
		_wall.append((now - _last) / 1000.0)
		_sec.append(LumosProf.take() if LumosProf.on else {})
		if _render:
			var vp := get_viewport().get_viewport_rid()
			_rcpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu())
			_rgpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
			_draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_rec -= 1
	_last = now
	if _scn != "":
		var t0 := Time.get_ticks_usec()
		_drive()
		_f += 1
		if _rec > 0:
			_drv.append((Time.get_ticks_usec() - t0) / 1000.0)


# --- Figuren ------------------------------------------------------------------------------------------------------

func _spawn(n: int) -> void:
	for i in n:
		var r := CharacterRig.new()
		add_child(r)
		r.setup(KEYS[i % KEYS.size()], -1, 1.0)
		var h := Vector3(-2.4 + (i % 4) * 1.6, 0, 1.2 - (i / 4) * 1.6)
		r.position = h
		r.face_now(Vector3(0, 0, 1))
		r.play("idle")
		var cfg := LumosActorConfig.detect(r)
		cfg.seed = 7100 + i   # gleiche Abläufe bei jedem Lauf; Persönlichkeit aus dem Modell (Ritter mutig …)
		crowd.append(LumosActor.attach(r, cfg))
		homes.append(h)


func _clear() -> void:
	var soc := LumosSocial.find(self)
	for a in crowd:
		if not is_instance_valid(a):
			continue
		if soc:
			var it := soc.interaction_of(a)
			if it:
				it.call("cancel")
		for id: String in LumosCartoon.running(a):
			LumosCartoon.stop(a, id)
	for a in crowd:
		if is_instance_valid(a):
			a.rig.queue_free()
	crowd.clear()
	homes.clear()
	await _frames_wait(70)   # Effekte klingen aus (Partikel, Ausblenden)


# --- Szenarien ----------------------------------------------------------------------------------------------------

func _drive() -> void:
	var dt := 1.0 / 60.0
	var t := _f * dt
	var n := crowd.size()
	match _scn:
		"0B", "B":
			for i in n:
				_walk(i, dt)
		"C":
			_pairs(0)
		"D":
			_emotions(t, 1.5)
		"E":
			_toon(t, 2.0, true)
		"F", "G1", "G2":
			var half := (n + 1) / 2
			for i in half:
				_walk(i, dt)
			_pairs(half)
			_emotions(t, 2.5)
			_toon(t, 4.0, false)


## Gehen (gerade Figuren) bzw. Laufen (ungerade) auf einem Kreis um den eigenen Platz.
func _walk(i: int, dt: float) -> void:
	var a := crowd[i]
	var rel := a.rig.global_position - homes[i]
	rel.y = 0.0
	var tang := Vector3(-rel.z, 0, rel.x).normalized() if rel.length() > 0.05 else Vector3.RIGHT
	var wish := (tang + rel.normalized() * (0.55 - rel.length()) * 1.5).normalized() * (0.9 if i % 2 == 0 else 2.0)
	a.move(wish, true, dt)


## Paare (i, i+1) ab start: sobald beide frei sind, beginnt die nächste Interaktion der Liste.
func _pairs(start: int) -> void:
	var i := start
	while i + 1 < crowd.size():
		var a := crowd[i]
		var b := crowd[i + 1]
		var key := "p%d" % i
		if not a.in_interaction() and not b.in_interaction() and _f >= int(_st.get(key + "t", 0)):
			var k := int(_st.get(key, 0))
			_st[key] = k + 1
			a.interact_with(_kinds[(k + i) % _kinds.size()], b)
			_st[key + "t"] = _f + 20
		i += 2


## Alle period Sekunden (je Figur versetzt) eine andere Gefühlsreaktion; dazu Lachen (steckt an), Winken, Witze.
func _emotions(t: float, period: float) -> void:
	for i in crowd.size():
		var k := int(floor((t + i * 0.11) / period))
		var key := "e%d" % i
		if k == int(_st.get(key, -1)):
			continue
		_st[key] = k
		var a := crowd[i]
		a.react(_emos[(k * 7 + i * 5) % _emos.size()], 0.85, 0.9)
		match (k + i) % 3:
			0:
				a.laugh(1.2, 0.6)
			1:
				a.emit_social("wave" if k % 2 == 0 else "joke")


func _toon(t: float, period: float, force: bool) -> void:
	for i in crowd.size():
		var k := int(floor((t + i * 0.13) / period))
		var key := "t%d" % i
		if k == int(_st.get(key, -1)):
			continue
		_st[key] = k
		crowd[i].cartoon(_toons[(k * 5 + i * 3) % _toons.size()], 0.8, {"force": force})


# --- Auswertung ---------------------------------------------------------------------------------------------------

static func _stats(v: PackedFloat64Array) -> Dictionary:
	var n := v.size()
	if n == 0:
		return {"mean": 0.0, "p50": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0}
	var s := v.duplicate()
	s.sort()
	var sum := 0.0
	for x in s:
		sum += x
	return {"mean": sum / n, "p50": s[n / 2], "p95": s[clampi(ceili(n * 0.95) - 1, 0, n - 1)],
		"p99": s[clampi(ceili(n * 0.99) - 1, 0, n - 1)], "max": s[n - 1]}


func _print(r: Dictionary) -> void:
	var w: Dictionary = r.wall
	var fw: Dictionary = r.fw
	var n := int(r.n)
	var line := "[PERF] %-2s %2d Fig. · Bild Ø %.2f ms (p50 %.2f · p95 %.2f · p99 %.2f · max %.2f) · Framework Ø %.2f (p95 %.2f, max %.2f) = %.3f ms/Figur · Rest Ø %.2f (max %.2f) · Gesicht %.0f/s · LOD %s · Objekte %d" % [
		r.scn, n, w.mean, w.p50, w.p95, w.p99, w.max, fw.mean, fw.p95, fw.max, float(fw.mean) / n, (r.rest as Dictionary).mean,
		(r.rest as Dictionary).max, r.face_draws_per_s, str(r.lod), r.objects_after]
	if r.has("render_cpu"):
		line += " · Render CPU Ø %.2f ms, GPU Ø %.2f ms, Draw-Calls Ø %d" % [(r.render_cpu as Dictionary).mean, (r.render_gpu as Dictionary).mean, int((r.draws as Dictionary).mean)]
	print(line)
	var parts: Array[String] = []
	for k: String in r.sec:
		parts.append("%s %.3f" % [k, float((r.sec[k] as Dictionary).mean)])
	print("[PERF]      " + " · ".join(parts))
	if not (r.max_sec as Dictionary).is_empty():
		print("[PERF]      Spitzen > 0,5 ms: " + str(r.max_sec))


func _print_repeat() -> void:
	var first := {}
	for r in results:
		var key := "%s/%d" % [r.scn, r.n]
		if int(r.rep) == 0:
			first[key] = r
		elif first.has(key):
			var a := float(((first[key] as Dictionary).wall as Dictionary).mean)
			var b := float((r.wall as Dictionary).mean)
			var fa := float(((first[key] as Dictionary).fw as Dictionary).mean)
			var fb := float((r.fw as Dictionary).mean)
			print("[PERF] Wiederholung %-8s Bild %.2f → %.2f ms (%+.1f %%) · Framework %.2f → %.2f ms (%+.1f %%)" % [key, a, b,
				(b - a) / maxf(a, 0.001) * 100.0, fa, fb, (fb - fa) / maxf(fa, 0.001) * 100.0])


func _save(leak: float) -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	var f := FileAccess.open(_out.path_join("perf.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": ProjectSettings.get_setting("application/config/version", ""),
		"display": DisplayServer.get_name(), "adapter": RenderingServer.get_video_adapter_name(), "frames": _frames,
		"cpu": OS.get_processor_name(), "cores": OS.get_processor_count(), "leak_objects": leak, "results": results}, "  "))
	f.close()
	var md := "# Performance-Labor – %s\n\nCPU %s (%d Kerne) · %s · %d Bilder je Messung · --fixed-fps 60\n\n" % [
		ProjectSettings.get_setting("application/config/version", ""), OS.get_processor_name(), OS.get_processor_count(),
		DisplayServer.get_name(), _frames]
	md += "| Szenario | Fig. | Bild Ø | p95 | p99 | max | Framework Ø | p95 | je Figur | Rest Ø | Gesicht/s |\n|---|---|---|---|---|---|---|---|---|---|---|\n"
	for r in results:
		var w: Dictionary = r.wall
		var fw: Dictionary = r.fw
		md += "| %s %s | %d | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.3f | %.2f | %.0f |\n" % [r.scn, SCENES[r.scn], r.n, w.mean, w.p95,
			w.p99, w.max, fw.mean, fw.p95, float(fw.mean) / int(r.n), (r.rest as Dictionary).mean, r.face_draws_per_s]
	md += "\n## Aufschlüsselung (Ø ms je Bild, alle Figuren zusammen)\n\n| Abschnitt |"
	var cols: Array = []
	for r in results:
		if int(r.n) == 16 and int(r.rep) == 0:
			cols.append(r)
			md += " %s |" % r.scn
	md += "\n|---|" + "---|".repeat(cols.size()) + "\n"
	for k in ORDER:
		md += "| %s |" % LABEL[k]
		for r in cols:
			var st: Dictionary = (r.sec as Dictionary).get(String(k), {})
			md += " %s |" % ("%.3f" % float(st.mean) if not st.is_empty() else "–")
		md += "\n"
	var f2 := FileAccess.open(_out.path_join("perf.md"), FileAccess.WRITE)
	f2.store_string(md)
	f2.close()
	print("[PERF] gespeichert: " + _out)
