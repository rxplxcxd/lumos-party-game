extends RefCounted
## Character Behavior Laboratory (1.5.2) – läuft im selben automatischen Lauf wie das CharLab (CI: „CHARLAB OK“).
##
## Zwanzig Testbereiche mit messbaren Kriterien. Ein bestandener Test heißt hier: die Zahl stimmt. Ob eine
## Bewegung natürlich WIRKT, entscheidet die Sichtprüfung der Kontrollbilder (--lab-auto=/ordner unter xvfb):
## b04_gruppe_*.png (Mikroleben einer Gruppe), b02_cartoon_*.png, b15_troesten_*.png, b16_gleichzeitig_*.png …
##
##   B1 Gefühlsausdrücke        B2 Cartoon-Reaktionen      B3 Augen und Blick         B4 Mikroanimationen
##   B5 Atmung                  B6 Gewicht und Balance     B7 Gehen/Drehen            B8 Springen und Landen
##   B9 Greifen und Werfen*     B10 High-Five*             B11 Umarmung*              B12 Schulterklopfen*
##   B13 Übergabe               B14 gemeinsames Lachen     B15 Trösten                B16 mehrere gleichzeitig
##   B17 Persönlichkeiten       B18 verschiedene Modelltypen  B19 Haustiere           B20 Leistung (Verhalten)
##   (* zusätzlich zu den Prüfungen 7–12 des CharLabs, die seit 1.5.2 über das Interaktionsprotokoll laufen)

const ORIGIN := Vector3(0, 0, 40)
## Die 36 geforderten Gefühle → Kennungen (LumosEmotion.META, LumosFace.EXPR, LumosBody.POSTURE)
const REQUIRED := {"Freude": "joy", "Begeisterung": "delight", "Euphorie": "euphoria", "Stolz": "pride",
	"Erleichterung": "relief", "Zufriedenheit": "content", "Zuneigung": "affection", "Liebevolle Freundlichkeit": "tender",
	"Neugier": "curious", "Verspieltheit": "playful", "Schadenfreude": "gloat", "Verlegenheit (positiv)": "bashful",
	"Traurigkeit": "sad", "Enttäuschung": "disappointed", "Angst": "fear", "Panik": "panic", "Wut": "anger",
	"Frustration": "frustrated", "Eifersucht": "jealous", "Scham": "shame", "Verwirrung": "confused",
	"Unsicherheit": "insecure", "Einsamkeit": "lonely", "Erschöpfung": "exhausted", "Überraschung": "surprise",
	"Ungläubigkeit": "disbelief", "Misstrauen": "suspicious", "Verlegenheit": "embarrassed", "Nervosität": "nervous",
	"Mitgefühl": "compassion", "Bewunderung": "admiration", "Trotz": "defiant", "Ungeduld": "impatient",
	"Konzentration": "focus", "Nachdenklichkeit": "pensive", "spielerische Provokation": "teasing"}

var lab        # das CharLab (Node3D) – dynamisch angesprochen (Helfer, Kamera, Konstanten)
var spawned: Array[LumosActor] = []


func run(p_lab: Variant) -> void:
	lab = p_lab
	for n in lab.get_children():   # Bühne frei: alle bisherigen Figuren ruhen
		if n is CharacterRig:
			(n as CharacterRig).visible = false
			(n as CharacterRig).process_mode = Node.PROCESS_MODE_DISABLED
	_cam(Vector3(0, 2.4, 8.0), Vector3(0, 1.1, 0))
	var nodes0: int = lab.get_tree().get_node_count()
	if _want(1):
		await _b1()
	if _want(2):
		await _b2()
	if _want(3):
		await _b3()
	if _want(4):
		await _b4()
	if _want(5) or _want(6):
		await _b5_b6()
	if _want(7) or _want(8):
		await _b7_b8()
	if _want(13):
		await _b13()
	if _want(14):
		await _b14()
	if _want(15):
		await _b15()
	if _want(16):
		await _b16()
	if _want(17):
		await _b17()
	if _want(18) or _want(19):
		await _b18_b19()
	if _want(21):
		await _b21()
	if _want(22):
		await _b22()
	if _want(23):
		await _b23()
	if _want(24):
		await _b24()
	if _want(25):
		await _b25()
	if _want(26):
		await _b26()
	_clear()
	await _w(1.2)
	var nodes1: int = lab.get_tree().get_node_count()
	lab._ok(nodes1 - nodes0 < 40, "B20 Ressourcen: nach allen Verhaltenstests %d Knoten mehr als vorher (Effekte und Figuren aufgeräumt)" % (nodes1 - nodes0))


# --- Hilfen ------------------------------------------------------------------------------------------------------

## Nur ausgewählte Bereiche laufen lassen (Entwicklung): -- --lab-behavior --lab-only=21,22
func _want(n: int) -> bool:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--lab-only="):
			return str(n) in String(a).get_slice("=", 1).split(",")
	return true


func _cam(pos: Vector3, look: Vector3) -> void:
	var c: Camera3D = lab.cam
	c.position = ORIGIN + pos
	c.look_at(ORIGIN + look)


func _w(secs: float, each := Callable()) -> void:
	await lab._wait(secs, each)


func _spawn(key: String, pos: Vector3, preset := "", autonomy := 1.0) -> LumosActor:
	var a: LumosActor = lab._spawn(key, ORIGIN + pos)
	a.cfg.autonomy = autonomy
	if preset != "":
		var p := LumosPersonality.preset(preset)
		a.personality = p
		a.emotion.personality = p
	spawned.append(a)
	return a


func _face(a: LumosActor, b: LumosActor) -> void:
	var d := b.rig.global_position - a.rig.global_position
	d.y = 0.0
	a.rig.face_now(d)


func _clear() -> void:
	for a in spawned:
		if is_instance_valid(a):
			a.rig.queue_free()
	spawned.clear()


func _shot(name: String) -> void:
	await lab._shot(name)


# --- B1 Gefühle ----------------------------------------------------------------------------------------------------

func _b1() -> void:
	var missing: Array = []
	var vecs := {}
	for de: String in REQUIRED:
		var id := String(REQUIRED[de])
		if not (LumosFace.EXPR.has(id) and LumosBody.POSTURE.has(id) and LumosEmotion.META.has(id)):
			missing.append(de)
			continue
		var e := LumosEmotion.new()
		e.setup(LumosPersonality.new(), LumosFace.EXPR, LumosBody.POSTURE, LumosFace.KEYS)
		e.set_mood(id, 1.0, 0.0)
		e.update(1.0 / 60.0)
		var v: Array = []
		for k: String in LumosFace.KEYS:
			v.append(float(e.face_out[k]))
		for c in 4:
			v.append(e.posture_out[c] * 2.0)
		vecs[de] = v
	lab._ok(missing.is_empty(), "B1 alle %d geforderten Gefühle haben Gesicht, Haltung und Verhalten%s" % [REQUIRED.size(), "" if missing.is_empty() else " – fehlt: " + str(missing)])
	var best := INF
	var pair := ""
	var keys := vecs.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: Array = vecs[keys[i]]
			var b: Array = vecs[keys[j]]
			var d := 0.0
			for k in a.size():
				d += pow(float(a[k]) - float(b[k]), 2.0)
			d = sqrt(d)
			if d < best:
				best = d
				pair = "%s/%s" % [keys[i], keys[j]]
	lab._ok(best > 0.3, "B1 alle Gefühle sichtbar verschieden (nächstes Paar %s: Abstand %.2f)" % [pair, best])
	# Verlauf: Anstieg, Halten, Abklingen, Nachwirkung (Lachen → Zufriedenheit)
	var em := LumosEmotion.new()
	em.setup(LumosPersonality.new(), LumosFace.EXPR, LumosBody.POSTURE, LumosFace.KEYS)
	em.trigger("laugh", 1.0, 0.6)
	var peak := 0.0
	var after := 0.0
	var jump := 0.0
	var prev := 0.0
	for f in 240:
		em.update(1.0 / 60.0)
		var li := em.intensity_of("laugh")
		peak = maxf(peak, li)
		after = maxf(after, em.intensity_of("content"))
		jump = maxf(jump, absf(float(em.face_out.open) - prev))
		prev = float(em.face_out.open)
	lab._ok(peak > 0.85 and em.intensity_of("laugh") < 0.05 and after > 0.25 and jump < 0.2,
		"B1 Verlauf: Lachen steigt an (%.2f), klingt ab, Nachwirkung Zufriedenheit (%.2f), weich (größter Schritt %.3f)" % [peak, after, jump])
	# gleichzeitige Gefühle: Freude als Stimmung + Verlegenheit als Reaktion → beides sichtbar
	var mx := LumosEmotion.new()
	mx.setup(LumosPersonality.new(), LumosFace.EXPR, LumosBody.POSTURE, LumosFace.KEYS)
	mx.set_mood("joy", 1.0, 0.0)
	mx.trigger("embarrassed", 0.9, 2.0, 0.05)
	for f2 in 30:
		mx.update(1.0 / 60.0)
	lab._ok(float(mx.face_out.blush) > 0.6 and float(mx.face_out.curve) > 0.3,
		"B1 gemischte Gefühle: Freude + Verlegenheit (Röte %.2f, Lächeln %.2f)" % [float(mx.face_out.blush), float(mx.face_out.curve)])
	# Persönlichkeit: gefühlsbetont stärker als ruhig
	var hi := LumosEmotion.new()
	hi.setup(LumosPersonality.preset("boisterous"), LumosFace.EXPR, LumosBody.POSTURE, LumosFace.KEYS)
	var lo := LumosEmotion.new()
	lo.setup(LumosPersonality.preset("calm"), LumosFace.EXPR, LumosBody.POSTURE, LumosFace.KEYS)
	hi.trigger("surprise", 0.7)
	lo.trigger("surprise", 0.7)
	for f3 in 20:
		hi.update(1.0 / 60.0)
		lo.update(1.0 / 60.0)
	lab._ok(float(hi.face_out.wide) > float(lo.face_out.wide) * 1.2,
		"B1 Persönlichkeit: Überraschung bei Lebhaftem %.2f, bei Ruhigem %.2f" % [float(hi.face_out.wide), float(lo.face_out.wide)])


# --- B2 Cartoon ------------------------------------------------------------------------------------------------------

func _b2() -> void:
	var heroes: Array[LumosActor] = []
	for k in 4:
		heroes.append(_spawn(lab.KEYS[k], Vector3(-3.3 + k * 2.2, 0, 0), "", 0.0))
	var mini := _spawn("mini/male_a", Vector3(-1.2, 0, 2.4), "", 0.0)
	var pet := _spawn("pet/dog", Vector3(1.4, 0, 2.4), "", 0.0)
	await _w(0.3)
	var base := {}
	for a in heroes + [mini, pet]:
		base[a] = a.rig.get_child_count()
	var ids: Array = LumosCartoon.available()
	var ok_all := true
	var failed: Array = []
	var k2 := 0
	# Stärke: Fontänen bei 0,5 kleiner als bei 1,0
	var amt := [0, 0]
	LumosCartoon.react(heroes[0], "cry", 0.5, {"force": true})
	LumosCartoon.react(heroes[1], "cry", 1.0, {"force": true})
	await _w(0.1)
	for c in heroes[0].rig.get_children():
		if c is CPUParticles3D:
			amt[0] = maxi(int(amt[0]), (c as CPUParticles3D).amount)
	var side_ok := true
	for c2 in heroes[1].rig.get_children():
		if c2 is CPUParticles3D:
			amt[1] = maxi(int(amt[1]), (c2 as CPUParticles3D).amount)
			var dir := (c2 as CPUParticles3D).global_basis * (c2 as CPUParticles3D).direction
			side_ok = side_ok and absf(dir.normalized().dot(heroes[1].forward())) < 0.5   # Fontänen seitlich, nicht übers Gesicht
	await _shot("b02_cartoon_weinen")
	lab._ok(int(amt[1]) > int(amt[0]) and side_ok, "B2 Weinen: Fontänen wachsen mit der Stärke (%d → %d Tropfen), schießen seitlich weg" % [amt[0], amt[1]])
	await _w(3.2)
	while k2 < ids.size():   # alle Reaktionen, je Runde vier Helden gleichzeitig
		for h in heroes:
			if k2 >= ids.size():
				break
			var id := String(ids[k2])
			var opts := {"force": true}
			if id == "hide_behind":
				opts.behind = heroes[(heroes.find(h) + 1) % 4]
				opts.move = false
			if not LumosCartoon.react(h, id, 0.85, opts):
				ok_all = false
				failed.append(id)
			k2 += 1
		await _w(0.9)
		if k2 == 8:
			await _shot("b02_cartoon_mitte")
		await _w(2.6)
	for id2 in ["joy_hop", "cry", "dizzy", "love", "shiver"]:
		var okm := LumosCartoon.react(mini, id2, 0.8, {"force": true})
		var okp := LumosCartoon.react(pet, id2, 0.8, {"force": true})
		if not okm:
			failed.append("mini:" + id2)
		if not okp:
			failed.append("pet:" + id2)
		ok_all = ok_all and okm and okp
		await _w(3.3)
	await _w(2.0)
	var clean := true
	for a2 in heroes + [mini, pet]:
		clean = clean and LumosCartoon.running(a2).is_empty() and a2.rig.get_child_count() <= int(base[a2]) + 1 and lab._finite(a2) \
			and a2.layers.owners().is_empty()
	lab._ok(ok_all, "B2 alle %d Cartoon-Reaktionen laufen auf Helden, Kenney-Figur und Haustier%s" % [ids.size(), "" if failed.is_empty() else " – abgelehnt: " + str(failed)])
	lab._ok(clean, "B2 danach aufgeräumt: keine laufenden Reaktionen, Effekte entfernt, Kanäle frei, Gelenke endlich")
	# Abklingzeit und Budget: nicht ständig
	var h0 := heroes[2]
	var h3 := heroes[3]
	var r1 := LumosCartoon.react(h0, "stomp", 0.7)
	await _w(1.3)
	var r2 := LumosCartoon.react(h0, "stomp", 0.7)        # Abklingzeit: dieselbe Reaktion noch gesperrt
	var r3 := LumosCartoon.react(h3, "head_shake", 0.7)
	await _w(1.6)
	var r4 := LumosCartoon.react(h3, "shrug", 0.7)
	await _w(1.9)
	var r5 := LumosCartoon.react(h3, "facepalm", 0.7)
	await _w(2.0)
	var r6 := LumosCartoon.react(h3, "sweat", 0.7)        # vierte in weniger als 10 s: Budget erschöpft
	lab._ok(r1 and not r2 and r3 and r4 and r5 and not r6, "B2 Abklingzeit (gleiche Reaktion gesperrt) und Budget (höchstens 3 in 10 s) greifen")
	await _w(2.5)
	_clear()


# --- B3 Augen und Blick ----------------------------------------------------------------------------------------------

func _b3() -> void:
	var a := _spawn("hero/mage", Vector3(0, 0, 0), "", 0.0)
	await _w(0.5)
	var target := a.rel(2.6, 1.7, 1.2)
	a.look_at_target(target)
	var d0 := a._eye.distance_to(target)
	var t_eye := [-1.0]
	var t_head := [-1.0]
	var tt := [0.0]
	await _w(1.2, func() -> void:
		tt[0] += lab.get_process_delta_time()
		if float(t_eye[0]) < 0.0 and a._eye.distance_to(target) < d0 * 0.2:
			t_eye[0] = tt[0]
		if float(t_head[0]) < 0.0 and a._gaze.distance_to(target) < d0 * 0.2:
			t_head[0] = tt[0])
	lab._ok(float(t_eye[0]) >= 0.0 and float(t_head[0]) > float(t_eye[0]) and float(t_eye[0]) < 0.2,
		"B3 Augen führen, der Kopf folgt (80 %% erreicht: Augen %.2f s, Kopf %.2f s)" % [float(t_eye[0]), float(t_head[0])])
	a.look_at_target(null)
	# Lidschlag: unregelmäßig, je Gefühl häufiger/seltener (Zeitraffer ×3)
	var nerv := _spawn("hero/knight", Vector3(-2.2, 0, 0), "", 0.0)
	var foc := _spawn("hero/ranger", Vector3(2.2, 0, 0), "", 0.0)
	nerv.feel("nervous", 0.0)
	foc.feel("focus", 0.0)
	var times: Array = []
	var prev := [a.face.blinks]
	for x in [a, nerv, foc]:
		x.time_scale = 3.0
	var b0 := [nerv.face.blinks, foc.face.blinks]
	var clock := [0.0]
	await _w(7.0, func() -> void:
		clock[0] += lab.get_process_delta_time() * 3.0
		if a.face.blinks != int(prev[0]):
			times.append(clock[0])
			prev[0] = a.face.blinks)
	var iv: Array = []
	for i in range(1, times.size()):
		iv.append(float(times[i]) - float(times[i - 1]))
	var mean := 0.0
	for v in iv:
		mean += float(v)
	mean /= maxf(iv.size(), 1)
	var var_ := 0.0
	for v2 in iv:
		var_ += pow(float(v2) - mean, 2.0)
	var cv := sqrt(var_ / maxf(iv.size(), 1)) / maxf(mean, 0.001)
	var nb := nerv.face.blinks - int(b0[0])
	var fb := foc.face.blinks - int(b0[1])
	lab._ok(iv.size() >= 4 and cv > 0.3, "B3 Lidschlag unregelmäßig (%d Abstände, Streuung %.0f %%), nie im Takt" % [iv.size(), cv * 100.0])
	lab._ok(nb > fb * 2, "B3 nervös blinzelt öfter als konzentriert (%d zu %d in 21 s)" % [nb, fb])
	_clear()


# --- B4 Mikroleben einer Gruppe ----------------------------------------------------------------------------------------

func _b4() -> void:
	var g: Array[LumosActor] = []
	var pos := [Vector3(-1.3, 0, 0.4), Vector3(1.3, 0, 0.4), Vector3(-0.6, 0, -1.2), Vector3(0.7, 0, -1.3)]
	for k in 4:
		g.append(_spawn(lab.KEYS[k], pos[k]))
	await _w(0.2)
	for k2 in 4:
		var c := Vector3(0, 0, -0.2) + ORIGIN - g[k2].rig.global_position
		c.y = 0.0
		g[k2].rig.face_now(c)
		g[k2].time_scale = 2.0
	_cam(Vector3(0.0, 1.9, 5.4), Vector3(0, 1.2, -0.4))
	var prev := {}
	var vprev := {}
	var worst := [0.0]
	var fast := [0.0]
	var n := [0]
	await _w(7.0, func() -> void:   # Unstetigkeit = plötzlicher Wechsel der Bewegung zwischen zwei Bildern (nicht Tempo)
		n[0] += 1
		for a in g:
			for j in ["head", "hand.l", "hand.r"]:
				var p := a.body.joint_pos(j)
				var key: String = str(a.get_instance_id()) + String(j)
				if prev.has(key):
					var dv: Vector3 = p - (prev[key] as Vector3)
					fast[0] = maxf(fast[0], dv.length())
					if vprev.has(key) and n[0] > 3:
						var jk := (dv - (vprev[key] as Vector3)).length()
						worst[0] = maxf(worst[0], jk)
					vprev[key] = dv
				prev[key] = p
		if n[0] % 60 == 0 and n[0] <= 360:
			lab._shot("b04_gruppe_%02d" % (n[0] / 60)))
	var glances := 999
	var shifts := 999
	var contacts := 0
	var gestures := 0
	for a2 in g:
		glances = mini(glances, int(a2.micro.stats.glances))
		shifts = mini(shifts, int(a2.micro.stats.shifts))
		contacts += int(a2.micro.stats.contacts)
		for gk: String in a2.micro.stats.gestures:
			gestures += int(a2.micro.stats.gestures[gk])
	lab._ok(glances >= 4 and contacts >= 1, "B4 Blicke: jede Figur schaut sich um (mind. %d Blicke in 14 s), %d-mal Blickkontakt" % [glances, contacts])
	lab._ok(shifts >= 1 and gestures >= 1, "B4 Gewichtswechsel (mind. %d je Figur) und %d kleine Gesten" % [shifts, gestures])
	lab._ok(float(worst[0]) < 0.05, "B4 keine abrupten Sprünge: größte Bewegungsänderung je Bild %.0f mm (schnellste Bewegung %.1f m/s, Zeitraffer ×2)" % [float(worst[0]) * 1000.0, float(fast[0]) * 30.0])
	_clear()


# --- B5 Atmung · B6 Gewicht und Balance ---------------------------------------------------------------------------------

func _b5_b6() -> void:
	var ex := _spawn("hero/barbarian", Vector3(-2.0, 0, 0), "", 0.0)
	var co := _spawn("hero/mage", Vector3(2.0, 0, 0), "", 0.0)
	ex.feel("exhausted", 0.2)
	co.feel("content", 0.2)
	await _w(2.5)
	lab._ok(ex.body.breath > co.body.breath + 0.3 and ex.body.breath_rate > co.body.breath_rate * 1.4,
		"B5 Atmung folgt dem Gefühl: erschöpft %.2f/%.1f, zufrieden %.2f/%.1f (Stärke/Takt)" % [ex.body.breath, ex.body.breath_rate, co.body.breath, co.body.breath_rate])
	_clear()
	# Anhalten: Oberkörper kippt nach vorn und schwingt aus
	var a := _spawn("hero/knight", Vector3(-4.0, 0, 0), "", 0.0)
	a.rig.face_now(Vector3(1, 0, 0))
	a.micro.enabled = false
	await _w(0.2)
	var peak := [0.0]
	await _w(1.4, func() -> void: a.move(Vector3(2.2, 0, 0), true, lab.get_process_delta_time()))
	var settle := [-1.0]
	var tt := [0.0]
	await _w(2.0, func() -> void:
		a.move(Vector3.ZERO, true, lab.get_process_delta_time())
		tt[0] += lab.get_process_delta_time()
		var c: Vector2 = a.body.dynamics_state().chest
		peak[0] = maxf(peak[0], c.x)
		if float(settle[0]) < 0.0 and tt[0] > 0.4 and absf(c.x) < 0.01:
			settle[0] = tt[0])
	lab._ok(float(peak[0]) > 0.04 and float(settle[0]) > 0.0 and float(settle[0]) < 1.8,
		"B6 Abbremsen: Oberkörper kippt nach vorn (%.2f rad) und fängt sich nach %.2f s" % [float(peak[0]), float(settle[0])])
	# Kontrapost: Becken wandert aufs Standbein, Füße bleiben stehen, Schwerpunkt über der Standfläche
	var hip0 := a.body.joint_pos("hips")
	var fl0 := a.body.joint_pos("foot.l")
	var fr0 := a.body.joint_pos("foot.r")
	a.body.weight_shift = 1.0
	await _w(1.5)
	var hip1 := a.body.joint_pos("hips")
	var slip := maxf(a.body.joint_pos("foot.l").distance_to(fl0), a.body.joint_pos("foot.r").distance_to(fr0))
	var shift := Vector2(hip1.x - hip0.x, hip1.z - hip0.z).length()
	var fl := a.body.joint_pos("foot.l")
	var fr := a.body.joint_pos("foot.r")
	var mn := Vector2(minf(fl.x, fr.x), minf(fl.z, fr.z)) - Vector2.ONE * 0.15
	var mxp := Vector2(maxf(fl.x, fr.x), maxf(fl.z, fr.z)) + Vector2.ONE * 0.15
	var com_in := hip1.x > mn.x and hip1.x < mxp.x and hip1.z > mn.y and hip1.z < mxp.y
	lab._ok(shift > 0.012 and slip < 0.012 and com_in, "B6 Standbein: Becken verlagert sich %.0f mm, Füße bleiben (%.0f mm), Schwerpunkt über der Standfläche" % [shift * 1000.0, slip * 1000.0])
	a.body.weight_shift = 0.0
	await _w(1.2)
	# Last: zurücklehnen und einsinken
	var head0 := a.body.joint_pos("head")
	var hipy0 := a.body.joint_pos("hips").y
	a.body.load = 1.0
	await _w(1.2)
	var back := (a.body.joint_pos("head") - head0).dot(-a.forward())
	var sink := hipy0 - a.body.joint_pos("hips").y
	lab._ok(back > 0.015 and sink > 0.008, "B6 schwere Last: lehnt sich zurück (%.0f mm), sinkt ein (%.0f mm)" % [back * 1000.0, sink * 1000.0])
	a.body.load = 0.0
	# Gleichgewicht verlieren und wiederfinden
	a.stumble(a.forward(), 1.0)
	var flail := [0.0]
	await _w(0.5, func() -> void: flail[0] = maxf(flail[0], a.body._flail))
	await _w(2.2)
	var st: Dictionary = a.body.dynamics_state()
	lab._ok(float(flail[0]) > 0.5 and a.body._imp.length() < 0.03 and absf((st.chest as Vector2).x) < 0.02 and lab._finite(a),
		"B6 Stolpern: Arme rudern, danach wieder im Gleichgewicht")
	_clear()


# --- B7 Drehen · B8 Springen und Landen -----------------------------------------------------------------------------------

func _b7_b8() -> void:
	var a := _spawn("hero/ranger", Vector3(0, 0, 0), "", 0.0)
	a.micro.enabled = false
	await _w(0.5)
	a.rig.turn_to(Vector3(0, 0, 1) if a.forward().z < 0.0 else Vector3(0, 0, -1), 0.45)
	var best := [0.0, 0.0]
	await _w(0.6, func() -> void:
		var st: Dictionary = a.body.dynamics_state()
		if absf(float(st.yaw_rate)) > absf(float(best[0])):
			best[0] = float(st.yaw_rate)
			best[1] = float(st.turn_lag))
	lab._ok(absf(float(best[0])) > 2.0 and float(best[0]) * float(best[1]) < 0.0 and absf(float(best[1])) > 0.03,
		"B7 Drehung: Kopf führt, Oberkörper folgt verzögert (Drehrate %.1f rad/s, Brust hängt %.2f rad nach)" % [float(best[0]), float(best[1])])
	_clear()
	var heavy := _spawn("hero/barbarian", Vector3(-1.4, 0, 0), "", 0.0)
	var light := _spawn("hero/mage", Vector3(1.4, 0, 0), "", 0.0)
	for x in [heavy, light]:
		x.micro.enabled = false
	await _w(0.5)
	var fp := {heavy: heavy.body.joint_pos("foot.l"), light: light.body.joint_pos("foot.l")}
	heavy.jump(0.6)
	light.jump(0.6)
	var drop := {heavy: 0.0, light: 0.0}
	var tj := [0.0]
	await _w(1.6, func() -> void:   # erst nach der Landung messen (Ausholen davor zählt nicht)
		tj[0] += lab.get_process_delta_time()
		if float(tj[0]) > 0.72:
			for x2: LumosActor in [heavy, light]:
				drop[x2] = maxf(float(drop[x2]), float(x2.body.dynamics_state().drop)))
	await _shot("b08_landung")
	await _w(1.0)
	var settled := absf(float(heavy.body.dynamics_state().drop)) < 0.006 and absf(float(light.body.dynamics_state().drop)) < 0.006
	var still := heavy.body.joint_pos("foot.l").distance_to(fp[heavy]) < 0.05 and light.body.joint_pos("foot.l").distance_to(fp[light]) < 0.05
	lab._ok(float(drop[heavy]) > float(drop[light]) * 1.15 and float(drop[light]) > 0.01 and settled and still,
		"B8 Landen mit Gewicht: schwer federt %.0f mm ein, leicht %.0f mm, beide stehen danach ruhig" % [float(drop[heavy]) * 1000.0, float(drop[light]) * 1000.0])
	_clear()


# --- B13 Übergabe ----------------------------------------------------------------------------------------------------

func _b13() -> void:
	var a := _spawn("hero/knight", Vector3(-0.65, 0, 0), "", 0.0)
	var b := _spawn("hero/mage", Vector3(0.65, 0, 0), "", 0.0)
	_face(a, b)
	_face(b, a)
	var item := MeshInstance3D.new()
	item.mesh = (lab.ball as MeshInstance3D).mesh
	lab.add_child(item)
	a.interact.held["r"] = item
	a.reach("r", a.interact.carry_point.bind("r"), 0.2, func() -> Array: return [a.forward(), Vector3.UP])
	await _w(0.6)
	var it := LumosInteraction.start("give", a, b, {"hand": "r", "to_hand": "l"})
	var md := [INF]
	await _w(1.6, func() -> void: md[0] = minf(md[0], a.hand_pos("r").distance_to(b.hand_pos("l"))))
	lab._ok(it != null and b.interact.held.l == item and a.interact.held.r == null and float(md[0]) < 0.12 and it.done and it.ok,
		"B13 Übergabe: Hände treffen sich (%.0f mm), Gegenstand wechselt die Hand, Phasen %s" % [float(md[0]) * 1000.0, str(it.phases_done) if it else "–"])
	item.queue_free()
	_clear()


# --- B14 gemeinsames Lachen (Ansteckung, versetzt, individuell) -----------------------------------------------------------

func _b14() -> void:
	var src := _spawn("hero/barbarian", Vector3(0, 0, -0.8), "boisterous")
	var o: Array[LumosActor] = [_spawn("hero/knight", Vector3(-1.6, 0, 0.6), "brave"), _spawn("hero/mage", Vector3(1.6, 0, 0.6), "curious"),
		_spawn("hero/ranger", Vector3(0, 0, 1.8), "shy")]
	for x in o:
		_face(x, src)
		src.social.set_relation(src, x, 1.0)   # enge Freunde
	await _w(0.5)
	src.laugh(2.0, 1.0)
	await _w(3.0)
	var starts: Array = []
	var shy_laughed := false
	var reacted := 0
	for x2 in o:
		for r: Array in x2.mind.reactions:
			if String(r[1]) == "laugh":
				reacted += 1
				if String(r[2]) == "laugh":
					starts.append(float(r[0]) + float(r[3]))
					if x2 == o[2]:
						shy_laughed = true
	starts.sort()
	var spread := INF
	for i in range(1, starts.size()):
		spread = minf(spread, float(starts[i]) - float(starts[i - 1]))
	lab._ok(starts.size() >= 1 and not shy_laughed and reacted >= 3, "B14 Mitlachen: %d lachen mit, die Schüchterne lächelt nur, alle reagieren" % starts.size())
	lab._ok(starts.size() < 2 or spread > 0.08, "B14 nie alle gleichzeitig (kleinster Abstand der Lacher %.2f s)" % (spread if starts.size() > 1 else 0.0))
	_clear()


# --- B15 Trösten -----------------------------------------------------------------------------------------------------

func _b15() -> void:
	var sad := _spawn("hero/mage", Vector3(0.0, 0, 0), "curious", 0.0)
	var friend := _spawn("hero/knight", Vector3(-2.4, 0, 0.4), "brave", 1.0)
	_face(friend, sad)
	await _w(0.5)
	LumosCartoon.react(sad, "cry", 0.8, {"force": true})
	var touch := [INF]
	var relief := [0.0]
	var n := [0]
	await _w(9.0, func() -> void:   # Hingehen mit echten Schritten (um die Weinende herum, falls nötig)
		n[0] += 1
		if friend.body and sad.body:   # Kontakt am nahen Oberarm (Mitte Schulter → Ellbogen, Außenseite)
			for sd in ["l", "r"]:
				var arm := sad.body.joint_pos("shoulder." + sd).lerp(sad.body.joint_pos("elbow." + sd), 0.4)
				for hd in ["l", "r"]:   # die zugewandte Hand tröstet (neben ihr stehend: je nach Seite links oder rechts)
					touch[0] = minf(touch[0], friend.hand_pos(hd).distance_to(arm))
		relief[0] = maxf(relief[0], sad.emotion.intensity_of("relief"))
		if n[0] == 150:
			lab._shot("b15_troesten"))
	var went := false
	for r: Array in friend.mind.reactions:
		went = went or String(r[2]) == "comfort"
	lab._ok(went and float(touch[0]) < 0.16 and float(relief[0]) > 0.3 and sad.emotion.intensity_of("cry") < 0.1,
		"B15 Trösten: Freund geht von selbst hin, Hand am Oberarm (%.0f mm), Weinen → Erleichterung (%.2f)" % [float(touch[0]) * 1000.0, float(relief[0])])
	_clear()


# --- B16 mehrere gleichzeitig ---------------------------------------------------------------------------------------------

func _b16() -> void:
	var pairs: Array = []
	var kinds := ["high_five", "handshake", "hug"]
	for k in 3:
		var a := _spawn(lab.KEYS[k], Vector3(-4.0 + k * 4.0 - 0.65, 0, 0))   # volle Autonomie: Mikrogesten müssen warten
		var b := _spawn(lab.KEYS[(k + 1) % 4], Vector3(-4.0 + k * 4.0 + 0.65, 0, 0))
		_face(a, b)
		_face(b, a)
		pairs.append([a, b])
	_cam(Vector3(0, 2.6, 9.5), Vector3(0, 1.1, 0))
	await _w(0.4)
	var its: Array = []
	var contacts := [0]
	for k2 in 3:
		var p: Array = pairs[k2]
		(p[0] as LumosActor).interact.contact.connect(func(_k: String, _o: LumosActor) -> void: contacts[0] += 1)
		its.append(LumosInteraction.start(kinds[k2], p[0], p[1]))
	var dbl := [false]
	await _w(1.1)
	await _shot("b16_gleichzeitig")
	await _w(3.0, func() -> void:
		for p2: Array in pairs:
			for x: LumosActor in p2:   # nie zwei Besitzer für einen Kanal; Mikrogesten dürfen nicht dazwischen
				var own := x.layers.owners()
				for c: String in own:
					if String(own[c]).begins_with("g:") and x.in_interaction():
						dbl[0] = true)
	var all_ok := true
	for it in its:
		all_ok = all_ok and it != null and (it as LumosInteraction).done and (it as LumosInteraction).ok
	var free := true
	for p3: Array in pairs:
		for y: LumosActor in p3:
			for c2: String in y.layers.owners():
				free = free and not String(y.layers.owners()[c2]).begins_with("ia:")
	lab._ok(all_ok and int(contacts[0]) >= 3 and not dbl[0] and free,
		"B16 High-Five, Handschlag und Umarmung gleichzeitig: alle %d Kontakte, keine Schicht-Konflikte, danach Kanäle frei" % int(contacts[0]))
	# Konfliktlösung: eine Interaktion verdrängt eine Mikrogeste, eine zweite Interaktion mit Beschäftigten wird abgelehnt
	var a3: LumosActor = (pairs[0] as Array)[0]
	var b3: LumosActor = (pairs[0] as Array)[1]
	a3.micro.play("cross_arms")
	var it2 := LumosInteraction.start("handshake", a3, b3)
	var it3 := LumosInteraction.start("hug", b3, a3)
	lab._ok(it2 != null and a3.micro.gesture == "" and it3 == null, "B16 Vorrang: Interaktion verdrängt die Geste sauber, eine zweite mit denselben Beteiligten wird abgelehnt")
	await _w(2.4)
	_cam(Vector3(0, 2.4, 8.0), Vector3(0, 1.1, 0))
	_clear()


# --- B17 Persönlichkeiten -------------------------------------------------------------------------------------------------

func _b17() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var shy := LumosPersonality.preset("shy")
	var brave := LumosPersonality.preset("brave")
	var imp := LumosPersonality.preset("boisterous")
	var calm := LumosPersonality.preset("calm")
	var ec := [0.0, 0.0]
	var rd := [0.0, 0.0]
	for i in 200:
		ec[0] += shy.eye_contact_time(rng) / 200.0
		ec[1] += brave.eye_contact_time(rng) / 200.0
		rd[0] += imp.reaction_delay(rng) / 200.0
		rd[1] += calm.reaction_delay(rng) / 200.0
	lab._ok(float(ec[0]) < float(ec[1]) * 0.6 and float(rd[0]) < float(rd[1]) * 0.6,
		"B17 Blickkontakt schüchtern %.2f s / selbstbewusst %.2f s · Reaktionszeit impulsiv %.2f s / ruhig %.2f s" % [ec[0], ec[1], rd[0], rd[1]])
	var s := _spawn("hero/ranger", Vector3(-0.9, 0, 0), "shy")
	var c := _spawn("hero/knight", Vector3(0.9, 0, 0), "brave")
	_face(s, c)
	_face(c, s)
	s.time_scale = 2.0
	c.time_scale = 2.0
	await _w(8.0)
	lab._ok(int(s.micro.stats.aversions) > int(c.micro.stats.aversions),
		"B17 Schüchterne weicht Blicken öfter aus (%d zu %d)" % [int(s.micro.stats.aversions), int(c.micro.stats.aversions)])
	var calm_a := _spawn("hero/mage", Vector3(3.0, 0, 0), "calm", 0.0)
	var play_a := _spawn("hero/barbarian", Vector3(5.0, 0, 0), "boisterous", 0.0)
	calm_a.feel("joy", 0.0)
	play_a.feel("joy", 0.0)
	await _w(0.3)
	lab._ok(float(play_a.emotion.face_out.curve) > float(calm_a.emotion.face_out.curve) + 0.05,
		"B17 Ausdrucksstärke: lebhaft lacht breiter (%.2f) als ruhig (%.2f)" % [float(play_a.emotion.face_out.curve), float(calm_a.emotion.face_out.curve)])
	_clear()


# --- B18 verschiedene Modelltypen · B19 Haustiere -----------------------------------------------------------------------------

func _b18_b19() -> void:
	var hero := _spawn("hero/knight", Vector3(-1.5, 0, 0), "", 0.0)
	var mini := _spawn("mini/robot", Vector3(-0.3, 0, 0), "", 0.0)
	var pet := _spawn("pet/cat", Vector3(1.4, 0, 0.3), "", 1.0)   # die Katze hat einen eigenen Schwanz-Knoten
	_face(hero, mini)
	_face(mini, hero)
	await _w(0.4)
	var got := []
	for x in [hero, mini, pet]:
		(x as LumosActor).interact.contact.connect(func(k: String, _o: LumosActor) -> void: got.append(k))
	var i1 := LumosInteraction.start("high_five", hero, mini)
	await _w(1.6)
	var i2 := LumosInteraction.start("pat", hero, pet)
	await _w(2.5)
	var i3 := LumosInteraction.start("cheer_together", pet, mini)
	await _w(2.0)
	lab._ok(i1 != null and i2 != null and i3 != null and "high_five" in got and "pat" in got and "cheer" in got and lab._finite(hero),
		"B18 Held ↔ Kenney-Figur (High-Five als Stups), Held tätschelt Haustier, Haustier und Kenney-Figur jubeln: %s" % str(got))
	# Haustier: wedelt vor Freude, zieht bei Angst den Schwanz ein, Beine laufen mit, reagiert auf Lachen
	pet.cfg.autonomy = 0.0
	pet.emotion.clear()   # Nachwirkungen der Interaktionen (Freude vom Jubeln) abklingen lassen
	await _w(1.0)
	var tail: Node3D = (pet._pet.get("tail", [null]) as Array)[0]
	if tail == null:
		print("[LAB] Haustier-Teile: ", pet._pet.keys(), " Modell: ", pet.rig.model)
	pet.feel("joy", 0.1)
	var ry := [INF, -INF]
	await _w(1.2, func() -> void:
		if tail:
			ry[0] = minf(ry[0], tail.rotation.y)
			ry[1] = maxf(ry[1], tail.rotation.y))
	pet.feel("fear", 0.1)
	await _w(0.8)
	var tuck := 0.0   # Winkel zwischen Ruhe- und aktueller Schwanzrichtung
	if tail:
		var b0: Basis = (pet._pet.tail as Array)[1].basis
		tuck = acos(clampf(b0.y.normalized().dot(tail.transform.basis.y.normalized()), -1.0, 1.0))
	pet.feel("neutral", 0.2)
	var legs: Array = pet._pet.get("legs", [])
	var lr := [INF, -INF]
	await _w(1.0, func() -> void:
		pet.rig.global_position += Vector3(1.2, 0, 0) * lab.get_process_delta_time()
		if not legs.is_empty():
			var ln: Node3D = (legs[0] as Array)[0]
			lr[0] = minf(lr[0], ln.rotation.x)
			lr[1] = maxf(lr[1], ln.rotation.x))
	pet.cfg.autonomy = 1.0
	var before := pet.mind.reactions.size()
	hero.laugh(1.2, 1.0)
	await _w(1.5)
	lab._ok(tail != null and float(ry[1]) - float(ry[0]) > 0.3 and absf(tuck) > 0.25 and float(lr[1]) - float(lr[0]) > 0.15 and pet.mind.reactions.size() > before,
		"B19 Haustier: wedelt vor Freude (%.2f rad), zieht bei Angst den Schwanz ein (%.2f rad), Beine laufen mit (%.2f rad), reagiert auf Lachen (%d)" % [float(ry[1]) - float(ry[0]), tuck, float(lr[1]) - float(lr[0]), pet.mind.reactions.size() - before])
	_clear()


# --- B21–B25 Stresstests mit mehreren Figuren (1.5.2) -----------------------------------------------------------------
# Keine Choreografie: Der Test löst nur das Ausgangsereignis aus (ein Sturz, Anfragen, Wiederholungen) und prüft, was
# aus Wahrnehmung, Persönlichkeit, Gefühlszustand und Interaktionslogik entsteht.

## Missgeschick: eine Figur stolpert und fällt; Beobachtung über 12 s. Rückgabe: was geschah (Rollen, Zeiten, Kontakt).
func _mishap(fallen: LumosActor, cast: Array[LumosActor], dir: Vector3, shot := "") -> Dictionary:
	var obs := {"fall": fallen.fall(dir, 1.0), "sat": false, "mood": "", "mood_t": -1.0, "self_t": -1.0, "stood_t": -1.0,
		"helper": null, "help_t": -1.0, "contact": INF, "max_ia": 0, "laugh_ev": [], "shot": false}
	var hub := fallen.social
	var t0 := fallen.clock()
	var on_ev := func(kind: String, src: LumosActor, _data: Dictionary) -> void:
		if kind == "laugh" and is_instance_valid(src):
			(obs.laugh_ev as Array).append([fallen.clock() - t0, src])
	hub.event.connect(on_ev)
	await _w(12.0, func() -> void:
		var t := fallen.clock() - t0
		obs.sat = bool(obs.sat) or String(fallen.rig.current) == "sit"
		var dom := fallen.emotion.dominant()
		if String(obs.mood) == "" and dom in ["frustrated", "embarrassed"]:
			obs.mood = dom
			obs.mood_t = t
		if float(obs.self_t) < 0.0 and String(obs.mood) != "" and fallen.is_laughing():
			obs.self_t = t
		if float(obs.stood_t) < 0.0 and t > 0.5 and not fallen.fallen:
			obs.stood_t = t
		var n_ia := 0
		for x in cast:
			n_ia += 1 if x.in_interaction() else 0
		obs.max_ia = maxi(int(obs.max_ia), n_ia)
		var it: RefCounted = hub.interaction_of(fallen)
		if it != null and String(it.get("kind")) == "help_up":
			var h: LumosActor = it.get("a")
			if obs.helper == null:
				obs.helper = h
				obs.help_t = t
			if String(it.get("phase")) in ["grip", "pull", "steady"]:
				obs.contact = minf(float(obs.contact), h.hand_pos("r").distance_to(fallen.hand_pos("r")))
				if shot != "" and not bool(obs.shot) and String(it.get("phase")) == "pull":
					obs.shot = true
					lab._shot(shot))
	hub.event.disconnect(on_ev)
	# Rollen aus den Reaktionsprotokollen (was jede Figur selbst entschieden hat)
	var roles := {}
	var delays: Array[float] = []
	for x in cast:
		var mine: Array[String] = []
		for r: Array in x.mind.reactions:
			if String(r[1]) == "fall":
				mine.append(String(r[2]))
				if String(r[2]) == "look":
					delays.append(float(r[3]))
		roles[x] = mine
	obs["roles"] = roles
	obs["delays"] = delays
	return obs


func _preset_of(x: LumosActor) -> String:
	var p := x.personality.to_dict()
	for k: String in LumosPersonality.PRESETS:
		var q := LumosPersonality.preset(k).to_dict()
		if q == p:
			return k
	return "?"


func _who(obs: Dictionary, role: String) -> Array[LumosActor]:
	var out: Array[LumosActor] = []
	for x: LumosActor in obs.roles:
		if role in (obs.roles[x] as Array):
			out.append(x)
	return out


func _spread(v: Array[float]) -> float:
	if v.size() < 2:
		return 0.0
	var lo := INF
	var hi := -INF
	for x in v:
		lo = minf(lo, x)
		hi = maxf(hi, x)
	return hi - lo


## Danach ruhig: keine Interaktion, kein Sturz, keine Reste von Interaktion/Regie/Greifen auf den Kanälen, endliche
## Gelenke. Kleine Leerlauf-Gesten (Besitzer „g:…“) und von selbst endende Cartoon-Reaktionen sind gewolltes Leben.
func _calm(cast: Array[LumosActor]) -> bool:
	var ok := true
	for x in cast:
		var rest := false
		for c: String in x.layers.owners():
			var o := String(x.layers.owners()[c])
			rest = rest or o.begins_with("ia:") or o == "fall" or o.begins_with("script:") or o.begins_with("api:")
		var good: bool = not x.in_interaction() and not rest and lab._finite(x) and not x.fallen
		if not good:
			print("[LAB]   nicht ruhig: %s · Interaktion %s · Kanäle %s · am Boden %s · offen %d" % [x.rig.model_key,
				x.in_interaction(), x.layers.owners(), x.fallen, x.mind.pending()])
		ok = ok and good
	return ok


func _b21() -> void:
	# Variante 1: die Magierin (neugierig) fällt. Ringsum: Ritter (mutig), Barbar (ausgelassen), Waldläuferin
	# (verträumt), eine Ruhige, ein Schüchterner – alle in unterschiedlicher Entfernung.
	var fallen := _spawn("hero/mage", Vector3(0, 0, 0), "curious")
	var cast: Array[LumosActor] = [_spawn("hero/knight", Vector3(-2.2, 0, 0.9), "brave"),
		_spawn("hero/barbarian", Vector3(2.0, 0, 1.0), "boisterous"), _spawn("hero/ranger", Vector3(0.4, 0, 2.6), "dreamy"),
		_spawn("hero/knight", Vector3(-1.6, 0, -2.2), "calm"), _spawn("hero/ranger", Vector3(2.5, 0, -1.6), "shy")]
	for x in cast:
		_face(x, fallen)
	_face(fallen, cast[2])
	_cam(Vector3(0, 3.2, 7.8), Vector3(0, 0.7, 0))
	await _w(0.8)
	var o := await _mishap(fallen, cast, Vector3(0.3, 0, 1.0), "b21_aufhelfen")
	for x: LumosActor in o.roles:
		print("[LAB]   B21 %s (%s): %s" % [x.rig.model_key, _preset_of(x), o.roles[x]])
	var scared := _who(o, "fright")
	var mockers := _who(o, "laugh_at")
	var helpers := _who(o, "help")
	var h: LumosActor = o.helper
	var all := cast.duplicate()
	all.append(fallen)
	lab._ok(bool(o.fall) and bool(o.sat) and float(o.stood_t) > 0.0,
		"B21 Sturz: stolpert, sitzt am Boden, steht nach %.1f s wieder" % float(o.stood_t))
	lab._ok(scared.size() >= 1 and mockers.size() >= 1 and helpers.size() == 1 and h == helpers[0],
		"B21 Rollen entstehen aus der Persönlichkeit: %d erschrickt, %d lacht, genau einer hilft (%s)" % [scared.size(), mockers.size(),
			h.personality.resource_name if h and h.personality.resource_name != "" else (h.rig.model_key if h else "–")])
	var fit := true
	for x in scared:
		fit = fit and x.personality.confidence <= 0.5
	for x in mockers:
		fit = fit and x.personality.humor >= 0.6
	fit = fit and h != null and h.personality.friendliness >= 0.6
	lab._ok(fit, "B21 passend: Erschrockene unsicher, Lacher mit Humor, Helfer freundlich und selbstsicher")
	lab._ok(String(o.mood) == "frustrated" and float(o.mood_t) < 1.6 and float(o.self_t) > float(o.mood_t) + 0.5,
		"B21 die Gestürzte ärgert sich zuerst (%.1f s), lacht dann selbst darüber (%.1f s)" % [float(o.mood_t), float(o.self_t)])
	var glared := false
	for r: Array in fallen.mind.reactions:
		glared = glared or String(r[2]) == "glare"
	var sheepish := false
	for x in mockers:
		for r: Array in x.mind.reactions:
			sheepish = sheepish or String(r[1]) == "glare"
	lab._ok(glared and sheepish, "B21 Auslachen bringt einen bösen Blick, der Lacher reagiert darauf")
	var joined := 0
	for e: Array in o.laugh_ev:
		if float(e[0]) > float(o.self_t) and e[1] != fallen:
			joined += 1
	var later := 0
	for x in cast:
		for r: Array in x.mind.reactions:
			if String(r[1]) == "laugh" and String(r[2]) in ["laugh", "smile", "look"]:
				later += 1
	lab._ok(later >= 2, "B21 die anderen reagieren zeitversetzt auf ihr Lachen (%d Reaktionen)" % later)
	lab._ok(float(o.contact) < 0.06, "B21 Aufhelfen: Hände verbunden beim Hochziehen (%.0f mm)" % (float(o.contact) * 1000.0))
	lab._ok(_spread(o.delays) > 0.1 and int(o.max_ia) <= 1, "B21 nicht alle gleichzeitig (Reaktionszeiten streuen %.2f s), höchstens eine Interaktion" % _spread(o.delays))
	await _w(2.0)
	lab._ok(_calm(all), "B21 danach ruhig: keine Interaktion, alle Kanäle frei, Gelenke endlich")
	_clear()
	# Variante 2: der Barbar (Spaßvogel) fällt – niemand lacht ihn aus, er lacht früh über sich selbst, die anderen
	# lachen mit. Dieselben Regeln, andere Rollen.
	var b := _spawn("hero/barbarian", Vector3(0, 0, 0), "boisterous")
	var cast2: Array[LumosActor] = [_spawn("hero/knight", Vector3(-2.0, 0, 1.0), "brave"),
		_spawn("hero/mage", Vector3(2.1, 0, 0.8), "curious"), _spawn("hero/ranger", Vector3(0.3, 0, 2.5), "dreamy")]
	for x in cast2:
		_face(x, b)
	await _w(0.8)
	var o2 := await _mishap(b, cast2, Vector3(-0.4, 0, 1.0))
	var joined2 := 0
	for e: Array in o2.laugh_ev:
		if float(e[0]) > float(o2.self_t) and e[1] != b:
			joined2 += 1
	var mock2 := _who(o2, "laugh_at").size()
	lab._ok(mock2 == 0 and float(o2.self_t) > 0.0 and float(o2.self_t) < float(o.self_t) and o2.helper != null,
		"B21 andere Rollen beim Spaßvogel: niemand lacht ihn aus, er lacht früher über sich (%.1f s), %s hilft" % [float(o2.self_t),
			(o2.helper as LumosActor).rig.model_key if o2.helper else "niemand"])
	await _w(2.0)
	var all2 := cast2.duplicate()
	all2.append(b)
	lab._ok(_calm(all2), "B21 Variante 2 danach ruhig")
	_clear()


func _b22() -> void:
	# Unterbrechungen: ein Schreck-Reflex des Helfers mitten im Aufhelfen; Regie greift während einer Umarmung zum Arm.
	var a := _spawn("hero/knight", Vector3(-1.3, 0, 0), "brave", 0.0)
	var b := _spawn("hero/mage", Vector3(0.6, 0, 0), "curious", 0.0)
	_face(a, b)
	_face(b, a)
	await _w(0.5)
	var fell := b.fall(Vector3(1, 0, 0), 0.8)
	await _w(1.2)
	var it := LumosInteraction.start("help_up", a, b)
	var t := 0.0
	while it != null and not it.done and not (it.phase in ["grip", "pull"]) and t < 6.0:
		await lab.get_tree().process_frame
		t += lab.get_process_delta_time()
	var at := it.phase if it else "–"
	var jumped := LumosCartoon.react(a, "jump_back", 0.8, {"force": true, "from": b.rig.global_position})
	await _w(0.9)
	var released := not a.hand_owner("r").begins_with("ia:") and not a.hand_owner("l").begins_with("ia:") \
		and not b.hand_owner("r").begins_with("ia:")   # die Hände gehören jetzt dem Reflex, nicht mehr der Interaktion
	var b_sits := b.fallen and b.layers.owner_of("legs") == "fall"
	print("[LAB]   B22: gestürzt %s · Interaktion %s · Reflex %s · beendet %s/%s · Hände %s/%s · sitzt %s (Beine: %s)" % [fell,
		it != null, jumped, it.done if it else false, it.ok if it else false, a.hand_owner("l"), a.hand_owner("r"), b.fallen,
		b.layers.owner_of("legs")])
	lab._ok(fell and it != null and jumped and it.done and not it.ok and released and b_sits,
		"B22 Unterbrechung beim %s: Reflex verdrängt das Aufhelfen sauber, Hände frei, die Gestürzte sitzt weiter" % at)
	await _w(6.0)
	lab._ok(not b.fallen and not b.in_interaction() and b.layers.owners().is_empty(),
		"B22 ohne Hilfe steht sie nach ihrer Geduld allein auf, alle Kanäle frei")
	# Regie übernimmt den Arm während einer Umarmung → die Interaktion endet vollständig (beide Figuren frei)
	var hug := LumosInteraction.start("hug", a, b)
	await _w(0.8)
	a.script_hand("r", 1.0, a.rel(0.3, 1.2, 0.3))
	await _w(0.6)
	var ia_free := true
	for x in [a, b]:
		for c: String in (x as LumosActor).layers.owners():
			ia_free = ia_free and not String((x as LumosActor).layers.owners()[c]).begins_with("ia:")
	lab._ok(hug != null and hug.done and ia_free and b.hand_weight("l") < 0.05 and b.hand_weight("r") < 0.05,
		"B22 Regie greift ein: Umarmung endet für beide, keine Reste der Interaktion")
	a.script_hand("r", 0.0)
	_clear()


func _b23() -> void:
	# Drei wollen gleichzeitig mit derselben Figur: genau eine Interaktion beginnt, die anderen kommen nacheinander dran.
	var tgt := _spawn("hero/mage", Vector3(0, 0, 0), "curious", 0.0)
	var ask: Array[LumosActor] = [_spawn("hero/knight", Vector3(-1.3, 0, 0.7), "brave", 0.0),
		_spawn("hero/barbarian", Vector3(1.3, 0, 0.7), "boisterous", 0.0), _spawn("hero/ranger", Vector3(0, 0, 1.5), "dreamy", 0.0)]
	for x in ask:
		_face(x, tgt)
	await _w(0.5)
	var kinds := ["high_five", "handshake", "hug"]
	var first := 0
	for i in 3:
		first += 1 if LumosInteraction.start(kinds[i], ask[i], tgt) != null else 0
	var owners := {}
	for c: String in tgt.layers.owners():
		owners[tgt.layers.owners()[c]] = true
	var done := [0]
	var conc := [0]
	await _w(12.0, func() -> void:
		var n := 0
		for x in ask:
			n += 1 if x.in_interaction() else 0
		conc[0] = maxi(int(conc[0]), n)
		if not tgt.in_interaction():
			for i in 3:
				if not ask[i].has_meta("b23") and LumosInteraction.start(kinds[i], ask[i], tgt) != null:
					ask[i].set_meta("b23", true)
					done[0] += 1
					break)
	lab._ok(first == 1 and owners.size() == 1 and int(conc[0]) <= 1 and int(done[0]) >= 2,
		"B23 drei gleichzeitige Anfragen: eine beginnt (%d), die anderen nacheinander (%d weitere), nie zwei zugleich" % [first, int(done[0])])
	# Alle drei sprechen die Figur gleichzeitig an (Winken, Reden): sie schaut nacheinander hin, ohne Flackern
	var wait := 0.0
	while tgt.in_interaction() and wait < 6.0:
		await lab.get_tree().process_frame
		wait += lab.get_process_delta_time()
	tgt.cfg.autonomy = 1.0
	tgt.look_at_target(null)
	await _w(1.0)
	var s0 := tgt.soc_switches
	var looks: Array = []
	for x in ask:
		x.emit_social("wave", {"target": tgt})
		x.say(1.2)
	var last: Array = [null]   # Lambdas kopieren erfasste Variablen – veränderlicher Zustand in einem Array
	await _w(3.0, func() -> void:
		var f: Variant = tgt.look_focus()
		if f != null and not is_same(f, last[0]):
			looks.append([tgt.clock(), f])
		last[0] = f)
	var min_hold := INF   # nur ganze Blicke: der erste Eintrag ist der Zustand bei Beobachtungsbeginn (schon vorher begonnen)
	for i in range(2, looks.size()):
		min_hold = minf(min_hold, float(looks[i][0]) - float(looks[i - 1][0]))
	var seen := {}
	for e: Array in looks:
		seen[e[1]] = true
	var waves := 0
	var rx: Array = []
	for r: Array in tgt.mind.reactions:
		waves += 1 if String(r[2]) == "wave_back" else 0
		rx.append("%s:%s" % [r[1], r[2]])
	print("[LAB]   B23 Blicke %s · Reaktionen %s" % [looks.map(func(e: Array) -> String: return "%.2f %s" % [float(e[0]), (e[1] as LumosActor).rig.model_key if e[1] is LumosActor else str(e[1])]), rx.slice(-12)])
	lab._ok(seen.size() >= 2 and (looks.size() < 3 or min_hold >= LumosActor.SOC_DWELL - 0.02) and waves <= 1,
		"B23 von drei angesprochen: schaut %d an, %s, winkt einmal zurück (%d)" % [seen.size(),
			("jeder ganze Blick hält ≥ %.2f s" % min_hold) if looks.size() > 2 else "nur ein Blickwechsel (kein Hin und Her)", waves])
	_clear()


func _b24() -> void:
	# Wiederholte Ereignisse: 30 Witze in 3 s und Lachen im Takt – Abklingzeiten begrenzen die Reaktionen, angesteckte
	# Lacher stecken niemanden weiter an, die Gruppe beruhigt sich wieder.
	var src := _spawn("hero/barbarian", Vector3(0, 0, -0.9), "boisterous")
	var grp: Array[LumosActor] = [_spawn("hero/knight", Vector3(-1.7, 0, 0.6), "brave"), _spawn("hero/mage", Vector3(1.7, 0, 0.6), "curious"),
		_spawn("hero/ranger", Vector3(0, 0, 1.9), "dreamy"), _spawn("hero/knight", Vector3(-2.6, 0, -1.4), "calm")]
	for x in grp:
		_face(x, src)
	await _w(0.6)
	var by_others := [0]
	var on_ev := func(kind: String, s2: LumosActor, _d: Dictionary) -> void:
		if kind == "laugh" and s2 != src:
			by_others[0] += 1
	src.social.event.connect(on_ev)
	var n0 := 0
	for x in grp:
		n0 += x.mind.reactions.size()
	var k := [0]
	await _w(3.0, func() -> void:
		k[0] += 1
		if k[0] % 6 == 0:
			src.emit_social("joke")
		if k[0] % 30 == 0:
			src.laugh(0.6, 0.8))
	var laughs := 0
	var n1 := 0
	for x in grp:
		n1 += x.mind.reactions.size()
		for r: Array in x.mind.reactions:
			laughs += 1 if String(r[2]) == "laugh" else 0
	await _w(4.0)
	src.social.event.disconnect(on_ev)
	var pending := 0
	var still := 0
	for x in grp:
		pending += x.mind.pending()
		still += 1 if x.is_laughing() else 0
		if x.mind.pending() > 0 or x.is_laughing():
			var todo: Array = []
			for e: Array in x.mind._todo:
				todo.append(e[2])
			print("[LAB]   B24 %s: lacht %s · offen %s" % [x.rig.model_key, x.is_laughing(), todo])
	lab._ok(laughs <= grp.size() * 3 and int(by_others[0]) == 0 and n1 - n0 <= grp.size() * 30,
		"B24 30 Witze in 3 s: %d Lacher in der Gruppe (Abklingzeit), keine Kettenreaktion (%d weitergegebene Lacher), %d Reaktionen" % [
			laughs, int(by_others[0]), n1 - n0])
	lab._ok(pending == 0 and still == 0, "B24 danach Ruhe: keine offenen Reaktionen, niemand lacht mehr")
	_clear()


func _b25() -> void:
	# Zwei fallen gleichzeitig: je höchstens ein Helfer, niemand hilft zweien zugleich, beide stehen wieder, kein Hängen.
	var f1 := _spawn("hero/mage", Vector3(-1.2, 0, 0), "curious")
	var f2 := _spawn("hero/ranger", Vector3(1.4, 0, 0.2), "dreamy")
	var cast: Array[LumosActor] = [_spawn("hero/knight", Vector3(0, 0, 2.0), "brave"), _spawn("hero/barbarian", Vector3(0.2, 0, -2.0), "boisterous"),
		_spawn("hero/knight", Vector3(-2.8, 0, 1.4), "curious")]
	for x in cast:
		_face(x, f1)
	await _w(0.6)
	f1.fall(Vector3(0, 0, 1), 1.0)
	f2.fall(Vector3(0, 0, -1), 1.0)
	var helpers := {}
	var dbl := [false]
	await _w(14.0, func() -> void:
		var busy := {}
		for f in [f1, f2]:
			var it: RefCounted = f1.social.interaction_of(f)
			if it != null and String(it.get("kind")) == "help_up":
				var h: LumosActor = it.get("a")
				helpers[f] = h
				if busy.has(h):
					dbl[0] = true
				busy[h] = true)
	var all := cast.duplicate()
	all.append_array([f1, f2])
	var hs: Array = []
	for f: LumosActor in helpers:
		hs.append((helpers[f] as LumosActor).rig.model_key)
	print("[LAB]   B25: Helfer %s · am Boden %s/%s" % [hs, f1.fallen, f2.fallen])
	lab._ok(not f1.fallen and not f2.fallen and not dbl[0] and helpers.size() >= 1 and _calm(all),
		"B25 zwei Stürze zugleich: %d Helfer, keiner hilft zweien, beide stehen wieder, danach ruhig" % helpers.size())
	_clear()


## Durchdringung: jede Interaktion zwischen zwei Heldenpaaren – feste Körperteile (Köpfe mit Helm/Kapuze, Rümpfe)
## dürfen sich berühren, aber nicht ineinanderstecken. Gemessen wird der kleinste Abstand über die ganze Interaktion.
const B26_TOL := -0.03


func _b26() -> void:
	var phase_min := {}
	var worst := {}
	var bad: Array[String] = []
	for kind: String in LumosInteraction.KINDS:
		for pr: Array in [["hero/knight", "hero/mage"], ["hero/barbarian", "hero/ranger"]]:
			var a := _spawn(String(pr[0]), Vector3(-0.8, 0, 0), "brave", 0.0)
			var b := _spawn(String(pr[1]), Vector3(0.8, 0, 0), "curious", 0.0)
			_face(a, b)
			_face(b, a)
			var item: MeshInstance3D = null
			var opts := {}
			if kind == "give":
				item = MeshInstance3D.new()
				item.mesh = (lab.ball as MeshInstance3D).mesh
				lab.add_child(item)
				a.interact.held["r"] = item
				a.reach("r", a.interact.carry_point.bind("r"), 0.2, func() -> Array: return [a.forward(), Vector3.UP])
				opts = {"hand": "r", "to_hand": "l"}
			await _w(0.5)
			if kind == "help_up":
				b.fall(Vector3(1, 0, 0), 0.8)
				await _w(1.4)
			var it := LumosInteraction.start(kind, a, b, opts)
			var mn := [INF]
			var t := 0.0
			var shot_at := INF
			while it != null and not it.done and t < 12.0:
				await lab.get_tree().process_frame
				t += lab.get_process_delta_time()
				var c := LumosActor.clearance(a, b)
				if OS.has_environment("LUMOS_DBG_B26") and kind == OS.get_environment("LUMOS_DBG_B26"):
					var ph := String(it.phase)
					phase_min[ph] = minf(float(phase_min.get(ph, INF)), c)
				if c < float(mn[0]) - 0.02 and c < B26_TOL and pr == [["hero/knight", "hero/mage"], ["hero/barbarian", "hero/ranger"]][0]:
					shot_at = t
				mn[0] = minf(float(mn[0]), c)
				if absf(t - shot_at - 0.0) < 0.001 and c < B26_TOL - 0.1:
					await lab._shot("b26_%s_%.1f" % [kind, t])
			if not phase_min.is_empty():
				print("[LAB]   B26 %s %s je Phase (mm): %s · Ausweichen aktiv %d/%d Bilder" % [kind, String(pr[0]).get_file(), str(phase_min), a.avoid_hits, b.avoid_hits])
				phase_min.clear()
			var key := "%s %s/%s" % [kind, String(pr[0]).get_file(), String(pr[1]).get_file()]
			worst[key] = float(mn[0]) if it != null else NAN
			if it == null or float(mn[0]) < B26_TOL:
				bad.append("%s %s" % [key, "nicht gestartet" if it == null else "%.0f mm" % (float(mn[0]) * 1000.0)])
			if item:
				item.queue_free()
			_clear()
			await _w(0.2)
	var line := ""
	for k: String in worst:
		line += " %s %.0f ·" % [k, float(worst[k]) * 1000.0]
	print("[LAB]   B26 kleinster Abstand fester Körperteile je Interaktion (mm):" + line)
	lab._ok(bad.is_empty(), "B26 keine Durchdringung in %d Interaktionen (Toleranz %.0f mm)%s" % [worst.size(), B26_TOL * 1000.0,
		"" if bad.is_empty() else " – " + ", ".join(bad)])
