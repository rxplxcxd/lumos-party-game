extends Node3D
## Kolosseum-Turnier: 8 Teilnehmer (bis zu 4 Spieler + Gast-Champions) im K.-o.-System – Viertelfinale,
## Halbfinale, Finale. Jeder Kampf ist ein Duell-Minispiel. Vor jedem Kampf: Einlauf durch die Tore mit
## Spotlights, Rauch und Namensansage, das Publikum tobt. Das Publikum besteht ausschließlich aus Figuren
## des Spiels – als 2D-Sprites (einmal gerendert, als MultiMesh mit Jubel-Shader auf die Ränge gestapelt),
## damit es im Browser flüssig bleibt. KI-gegen-KI-Kämpfe werden als kurzes Schnell-Duell entschieden.

const ROUNDS := ["Viertelfinale", "Halbfinale", "Finale"]
const GUESTS := [
	{"name": "Champion Brummbär", "model": "npc/bear", "level": 1},
	{"name": "Gräfin Quaki", "model": "npc/duck", "level": 1},
	{"name": "Sir Wuff", "model": "npc/dog", "level": 2},
	{"name": "Mauzi die Flinke", "model": "pet/cat", "level": 2},
	{"name": "Kraxi Scherenhand", "model": "pet/crab", "level": 1},
	{"name": "Muhla die Mächtige", "model": "pet/cow", "level": 2},
]
const CROWD_MODELS := ["hero/knight", "hero/mage", "hero/barbarian", "hero/ranger", "hero/rogue", "pet/bunny", "pet/chick", "pet/cat", "pet/deer", "pet/cow"]

var state: Dictionary = {}
var cam: Camera3D
var _crowd_mat: ShaderMaterial
var _ui: Control
var _banner: Label
var _sub: Label
var _bracket_box: Control
var _cheer := 0.0
var _look := Vector3(0, 2, 0)
var _cam_pos := Vector3(0, 14, 30)
var _cam_look := Vector3(0, 2, 0)
var _gates: Array[Node3D] = []
var _fighters: Array[CharacterRig] = []


func _ready() -> void:
	Game.mode = "colosseum"
	WorldKit.env(self, "sunset")
	WorldKit.backdrop(self, "meadow", Color("#c9b28a"), -0.56)
	_build_arena()
	cam = Camera3D.new()
	cam.fov = 52.0
	add_child(cam)
	cam.position = _cam_pos
	cam.look_at(_cam_look)
	cam.make_current()
	_build_hud()
	Audio.minigame_music(3, 1.0)
	InputHub.set_touch_profile("menu")
	state = Game.get_meta("colosseum") if Game.has_meta("colosseum") else {}
	if state.is_empty():
		_new_tournament()
	else:
		_after_match()
	_main()


func _process(delta: float) -> void:
	if cam:
		var k := clampf(delta * 2.0, 0.0, 1.0)
		cam.position = cam.position.lerp(_cam_pos, k)
		_look = _look.lerp(_cam_look, k)
		cam.look_at(_look, Vector3.UP)
	_cheer = move_toward(_cheer, 0.25, delta * 0.4)
	_animate_life(delta)
	if _crowd_mat:
		_crowd_mat.set_shader_parameter("cheer", _cheer)


# --- Turnier-Logik ----------------------------------------------------------------------------------------------

func _new_tournament() -> void:
	var cont: Array = []
	for i in 4:
		cont.append({"name": String(Game.players[i].name), "model": Game.hero(Game.players[i].hero).model, "slot": i,
			"human": not Game.players[i].cpu, "level": int(Game.players[i].cpu_level)})
	var g := GUESTS.duplicate()
	g.shuffle()
	for k in 4:
		var gd: Dictionary = g[k]
		cont.append({"name": gd.name, "model": gd.model, "slot": -1, "human": false, "level": int(gd.level)})
	# Setzliste: jeder Spieler trifft im Viertelfinale auf einen Gast
	var order: Array = []
	for i in 4:
		order.append(i)
		order.append(4 + i)
	state = {"cont": cont, "round": 0, "match": 0, "bracket": [order, [], [], []], "pending": {}, "backup": {}}
	Game.set_meta("colosseum", state)


func _pairs(r: int) -> Array:
	var lst: Array = state.bracket[r]
	var out: Array = []
	for k in range(0, lst.size() - 1, 2):
		out.append([int(lst[k]), int(lst[k + 1])])
	return out


func _main() -> void:
	await get_tree().process_frame
	_refresh_bracket()
	while int(state.round) < 3:
		var pairs := _pairs(int(state.round))
		while int(state.match) < pairs.size():
			var pr: Array = pairs[int(state.match)]
			await _entrance(int(pr[0]), int(pr[1]))
			var a: Dictionary = state.cont[int(pr[0])]
			var b: Dictionary = state.cont[int(pr[1])]
			if bool(a.human) or bool(b.human):
				_launch_duel(int(pr[0]), int(pr[1]))
				return   # weiter nach dem Minispiel (Szene wird neu geladen)
			await _quick_duel(int(pr[0]), int(pr[1]))
			state.match = int(state.match) + 1
			_refresh_bracket()
		state.round = int(state.round) + 1
		state.match = 0
		if int(state.round) < 3:
			await _show(ROUNDS[int(state.round)] + "!", "Die Sieger ziehen weiter", UI.GOLD, 1.8)
	await _champion()


func _winner_to_next(w: int) -> void:
	(state.bracket[int(state.round) + 1] as Array).append(w)


## KI-gegen-KI: kurzes Schnell-Duell mit Kamera und Publikum.
func _quick_duel(a: int, b: int) -> void:
	await _show("Schnell-Duell!", "%s gegen %s" % [state.cont[a].name, state.cont[b].name], Color.WHITE, 1.2)
	var la := float(state.cont[a].level) + randf()
	var lb := float(state.cont[b].level) + randf()
	for k in 4:
		if _fighters.size() < 2:
			break
		var att := _fighters[k % 2]
		var def := _fighters[1 - k % 2]
		att.play(["punch", "kick"][k % 2] if att.has_clip("punch") else "cheer", 0.08, 1.2, true)
		att.lock(0.5)
		att.create_tween().tween_property(att, "position:x", att.position.x + signf(def.position.x - att.position.x) * 0.8, 0.15)
		await get_tree().create_timer(0.22).timeout
		def.react("hit")
		FX.stars(def.global_position + Vector3.UP * 1.5, Color(1, 0.9, 0.4), 8)
		Audio.sfx("punch", null, -6.0)
		Juice.shake(0.15)
		_cheer = 1.0
		await get_tree().create_timer(0.45).timeout
	var w := a if la >= lb else b
	_declare(w, a if w == b else b)
	await get_tree().create_timer(2.0).timeout


func _declare(w: int, l: int) -> void:
	_winner_to_next(w)
	var wi := 0 if _fighters.size() > 0 and String(_fighters[0].get_meta("who", "")) == str(w) else 1
	if _fighters.size() >= 2:
		_fighters[wi].react("victory")
		_fighters[1 - wi].react("sad")
		FX.confetti(_fighters[wi].global_position + Vector3.UP * 2.0, 60)
	_cheer = 1.0
	Audio.sfx("crowd", null, 0.0)
	Audio.sfx("sparkle_up", null, -4.0)
	_show("%s gewinnt!" % state.cont[w].name, "", UI.GOLD, 1.6)


## Echtes Duell-Minispiel: Gast belegt vorübergehend einen freien Spieler-Slot.
func _launch_duel(a: int, b: int) -> void:
	var ca: Dictionary = state.cont[a]
	var cb: Dictionary = state.cont[b]
	var sa := int(ca.slot)
	var sb := int(cb.slot)
	var backup := {}
	if sa < 0:
		sa = _free_slot([sb])
		backup[str(sa)] = Game.players[sa].duplicate(true)
		_install_guest(sa, ca)
	if sb < 0:
		sb = _free_slot([sa])
		backup[str(sb)] = Game.players[sb].duplicate(true)
		_install_guest(sb, cb)
	state.backup = backup
	state.pending = {"a": a, "b": b, "sa": sa, "sb": sb}
	var act := [false, false, false, false]
	act[sa] = true
	act[sb] = true
	var pool: Array = []
	for m in Game.MINIGAMES:
		if "duel" in (m.get("cats", []) as Array):
			pool.append(m)
	var pick: Dictionary = pool[randi() % pool.size()]
	Game.minigame_setup = {"cat": "duel", "active": act}
	Game.set_meta("colosseum", state)
	Game.mode = "colosseum"
	Router.goto(String(pick.scene))


func _free_slot(taken: Array) -> int:
	for i in range(3, -1, -1):
		if not (i in taken) and Game.players[i].cpu:
			return i
	for i in range(3, -1, -1):
		if not (i in taken):
			return i
	return 3


func _install_guest(slot: int, c: Dictionary) -> void:
	var p: Dictionary = Game.players[slot]
	p.cpu = true
	p.cpu_level = int(c.level)
	p.name = String(c.name)
	# Gäste nutzen ein Heldenmodell (Minispiele erwarten Helden-Rigs); Tiermodelle nur fürs Kolosseum
	var hero_ids: Array = Game.HEROES.map(func(h: Dictionary) -> String: return h.id)
	p.hero = String(hero_ids[(slot + 3) % hero_ids.size()])


## Nach dem Minispiel: Ergebnis übernehmen, Gast-Slots zurücksetzen.
func _after_match() -> void:
	var pd: Dictionary = state.get("pending", {})
	if pd.is_empty():
		return
	var res: Dictionary = Game.last_results
	var pl: Array = res.get("placements", [1, 2, 0, 0])
	var sa := int(pd.sa)
	var sb := int(pd.sb)
	var w := int(pd.a) if int(pl[sa]) <= int(pl[sb]) else int(pd.b)
	for k in (state.backup as Dictionary).keys():
		Game.players[int(k)] = (state.backup[k] as Dictionary).duplicate(true)
	state.backup = {}
	state.pending = {}
	_winner_to_next(w)
	state.match = int(state.match) + 1
	Game.last_results = {}
	_show("%s gewinnt!" % state.cont[w].name, "", UI.GOLD, 1.8)
	_cheer = 1.0


func _champion() -> void:
	var w := int((state.bracket[3] as Array)[0]) if (state.bracket[3] as Array).size() > 0 else 0
	var c: Dictionary = state.cont[w]
	_clear_fighters()
	var r := _spawn_fighter(String(c.model), Vector3(0, 1.6, 0), w)
	WorldKit.cylinder(self, 1.8, 1.6, Vector3(0, 0.8, 0), UI.GOLD, false)
	WorldKit.place(self, "arena/trophy", Vector3(1.6, 1.6, 0), 0.0, 2.0)
	_cam_pos = Vector3(0, 4.5, 9.5)
	_cam_look = Vector3(0, 2.4, 0)
	r.react("victory")
	_cheer = 1.0
	Audio.jingle("fanfare")
	Audio.sfx("crowd")
	for k in 5:
		FX.confetti(Vector3(randf_range(-6, 6), 8, randf_range(-4, 4)), 70)
		FX.stars(Vector3(randf_range(-6, 6), 7, randf_range(-4, 4)), UI.GOLD, 20)
		await get_tree().create_timer(0.4).timeout
	await _show("%s ist Kolosseums-Champion!" % c.name, "", UI.GOLD, 3.2)
	Game.remove_meta("colosseum")
	Game.mode = "menu"
	Router.goto("res://scenes/menu/MainMenu.tscn", {"page": "modes"})


# --- Einlauf-Spektakel ------------------------------------------------------------------------------------------

func _entrance(a: int, b: int) -> void:
	_clear_fighters()
	var ca: Dictionary = state.cont[a]
	var cb: Dictionary = state.cont[b]
	await _show(ROUNDS[int(state.round)], "Kampf %d" % (int(state.match) + 1), Color.WHITE, 1.2)
	var gate_pos := [Vector3(-22.0, 0, 0), Vector3(22.0, 0, 0)]
	var ids := [a, b]
	var cs := [ca, cb]
	for k in 2:
		var gp: Vector3 = gate_pos[k]
		var sx := signf(gp.x)
		_cam_pos = Vector3(gp.x * 0.5, 3.0, 8.0)
		_cam_look = Vector3(gp.x * 0.88, 1.8, 0)
		# Fallgitter versinkt im Boden, Trommelwirbel, dann stürmt der Kämpfer heraus
		var gate := _gates[k]
		Audio.sfx("creak", gp, -2.0)
		Juice.shake(0.12)
		gate.create_tween().tween_property(gate, "position:y", -2.5, 0.7).set_trans(Tween.TRANS_QUAD)
		await get_tree().create_timer(0.6).timeout
		var r := _spawn_fighter(String(cs[k].model), gp, int(ids[k]))
		r.face_now(Vector3(-sx, 0, 0))
		r.play("run")
		FX.smoke(Vector3(sx * 20.6, 1.0, 0), Color(1, 0.95, 0.9), 18, 1.6)
		for sz in [-2.6, 2.6]:
			FX.sparks(Vector3(sx * 20.4, 6.0, sz), Color(1, 0.8, 0.3), 24)
			FX.confetti(Vector3(sx * 20.4, 6.4, sz), 30)
		var tw := r.create_tween()
		tw.tween_property(r, "position", Vector3(sx * 4.3, 0.0, 0), 1.4)
		_cheer = 1.0
		Audio.sfx("crowd", null, -4.0)
		_cam_look = Vector3(sx * 4.3, 1.6, 0)
		await _show(("IN DER BLAUEN ECKE" if k == 0 else "UND IN DER ROTEN ECKE"), String(cs[k].name), Color("#7fd6ff") if k == 0 else Color("#ff8a8a"), 1.5)
		r.play("idle")
		r.face_now(Vector3(-sx, 0, 0.6))
		r.react("flex")
		gate.create_tween().tween_property(gate, "position:y", float(gate.get_meta("closed_y")), 0.6)
	_cam_pos = Vector3(0, 5.5, 16)
	_cam_look = Vector3(0, 1.6, 0)
	Audio.sfx("bell", null, 0.0, 0.8)
	FX.confetti(Vector3(0, 6, 0), 60)
	await _show("VS", "", UI.GOLD, 1.0)


func _spawn_fighter(model: String, pos: Vector3, who: int) -> CharacterRig:
	var r := CharacterRig.new()
	add_child(r)
	r.setup(model, -1, 1.1 if model.begins_with("hero/") else 1.3)
	r.position = pos
	r.set_meta("who", str(who))
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.92, 0.7)
	spot.light_energy = 5.0
	spot.spot_range = 14.0
	spot.spot_angle = 16.0
	r.add_child(spot)
	spot.position = Vector3(0, 11, 0)
	spot.rotation_degrees = Vector3(-90, 0, 0)
	_fighters.append(r)
	return r


func _clear_fighters() -> void:
	for f in _fighters:
		if is_instance_valid(f):
			f.queue_free()
	_fighters.clear()


# --- Arena & Publikum -------------------------------------------------------------------------------------------

const TIER_R0 := 21.0
const TIER_D := 1.8
const TIER_RISE := 1.1
const WALL_H := 2.6
const TIERS := 7

var _balloons: Array[Node3D] = []
var _birds: Array[Node3D] = []
var _flags: Array[Node3D] = []
var _ref: CharacterRig


func _build_arena() -> void:
	# Sandboden mit geharkten Ringen und Sternen-Emblem in der Mitte
	WorldKit.cylinder(self, 20.6, 1.0, Vector3(0, -0.5, 0), Color("#e8d29a"))
	for k in 4:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 3.0 + k * 4.2
		tm.outer_radius = 3.25 + k * 4.2
		tm.rings = 48
		tm.material = WorldKit.mat(Color("#d4b878"), 0.95)
		ring.mesh = tm
		ring.scale = Vector3(1, 0.04, 1)
		ring.position.y = 0.01
		add_child(ring)
	var em := WorldKit.cylinder(self, 2.4, 0.06, Vector3(0, 0.02, 0), Color("#f4c95d"), false)
	em.name = "Emblem"
	for k in 5:
		var a := TAU * k / 5.0
		var pt := WorldKit.box(self, Vector3(0.9, 0.07, 1.6), Vector3(sin(a) * 2.8, 0.03, cos(a) * 2.8), Color("#ffdf7a"), false)
		pt.rotation.y = a
	# Arena-Mauer (niedrig, damit die Ränge sichtbar sind) mit Bannern, Kränzen und Fackeln
	var seg_n := 40
	for k in seg_n:
		var a := TAU * (k + 0.5) / seg_n
		if absf(sin(a)) < 0.13:
			continue
		var p := Vector3(cos(a) * 20.9, WALL_H * 0.5, sin(a) * 20.9)
		var seg := WorldKit.box(self, Vector3(3.4, WALL_H, 0.8), p, Color("#d8c39a"), true)
		seg.rotation.y = -a + PI * 0.5
		var cap := WorldKit.box(self, Vector3(3.5, 0.25, 1.0), p + Vector3(0, WALL_H * 0.5 + 0.12, 0), Color("#f1e3c0"), false)
		cap.rotation.y = seg.rotation.y
		if k % 3 == 0:
			var col: Color = [Color("#ff5c7a"), Color("#3fa7ff"), Color("#2ecc71"), Color("#ffd23f")][(k / 3) % 4]
			var ban := WorldKit.box(self, Vector3(1.3, 1.7, 0.06), Vector3(cos(a) * 20.45, 1.45, sin(a) * 20.45), col, false)
			ban.rotation.y = seg.rotation.y
			var tip := WorldKit.box(self, Vector3(0.9, 0.9, 0.06), Vector3(cos(a) * 20.45, 0.62, sin(a) * 20.45), col, false)
			tip.rotation = Vector3(0, seg.rotation.y, 0)
			tip.rotate_object_local(Vector3.FORWARD, PI * 0.25)
			tip.scale = Vector3(1, 1, 1)
			WorldKit.cylinder(self, 0.32, 0.06, Vector3(cos(a) * 20.4, 1.6, sin(a) * 20.4), Color("#fff3c4"), false).rotation = Vector3(PI * 0.5, 0, 0).rotated(Vector3.UP, 0)
		if k % 6 == 3:
			WorldKit.torch_light(self, Vector3(cos(a) * 20.2, WALL_H + 0.6, sin(a) * 20.2), Color(1.0, 0.72, 0.42), 1.0, 6.0)
			WorldKit.cylinder(self, 0.12, 0.7, Vector3(cos(a) * 20.4, WALL_H + 0.25, sin(a) * 20.4), Color("#7a5232"), false)
	# Heuballen, Fässer und Wassereimer am Rand
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k in 10:
		var a := rng.randf() * TAU
		if absf(sin(a)) < 0.25:
			continue
		var bp := Vector3(cos(a) * 19.2, 0.45, sin(a) * 19.2)
		var hb := WorldKit.cylinder(self, 0.55, 1.0, bp, Color("#e9c46a"), false)
		hb.rotation = Vector3(0, -a, PI * 0.5)
		WorldKit.cylinder(self, 0.3, 0.5, bp + Vector3(cos(a + 0.12) * 0.0, 0.0, 0.0) + Vector3(-sin(a), -0.2, cos(a)) * 1.2, Color("#8a5a34"), false)
	# Torhäuser mit Fallgittern links und rechts (die Ränge haben dort eine Lücke)
	for sx in [-1.0, 1.0]:
		var gx: float = sx * 20.9
		for sz in [-1.0, 1.0]:
			WorldKit.box(self, Vector3(1.6, 6.2, 1.4), Vector3(gx, 3.1, sz * 2.6), Color("#cdb68c"), true)
			WorldKit.box(self, Vector3(1.9, 0.4, 1.7), Vector3(gx, 6.3, sz * 2.6), Color("#f1e3c0"), false)
			WorldKit.torch_light(self, Vector3(gx - sx * 1.0, 4.4, sz * 2.6), Color(1.0, 0.7, 0.4), 1.6, 7.0)
		WorldKit.box(self, Vector3(1.6, 1.4, 6.6), Vector3(gx, 5.6, 0), Color("#cdb68c"), false)
		var sign_col := Color("#3fa7ff") if sx < 0 else Color("#ff5c7a")
		WorldKit.box(self, Vector3(0.1, 0.9, 3.6), Vector3(gx - sx * 0.85, 5.6, 0), sign_col, false)
		WorldKit.box(self, Vector3(4.0, 4.6, 4.6), Vector3(gx + sx * 2.6, 2.3, 0), Color("#2a2030"), false)
		var gate := Node3D.new()
		add_child(gate)
		gate.position = Vector3(gx - sx * 0.2, 2.3, 0)
		for b in 6:
			WorldKit.box(gate, Vector3(0.16, 4.6, 0.16), Vector3(0, 0, -2.0 + b * 0.8), Color("#5a5a6a"), false)
		for b in 3:
			WorldKit.box(gate, Vector3(0.14, 0.14, 4.2), Vector3(0, -1.6 + b * 1.6, 0), Color("#4a4a58"), false)
		gate.set_meta("closed_y", 2.3)
		_gates.append(gate)
	# Tribünen als hohle Stufenringe (Lücke über den Toren bleibt offen)
	add_child(_tier_mesh())
	# Äußere Krone mit Säulen und wehenden Wimpeln
	for k in 24:
		var a2 := TAU * (k + 0.5) / 24.0
		var r_out := TIER_R0 + TIERS * TIER_D + 0.4
		var top := WALL_H + TIERS * TIER_RISE
		WorldKit.box(self, Vector3(0.7, 3.2, 0.7), Vector3(cos(a2) * r_out, top + 1.6, sin(a2) * r_out), Color("#e2d0a8"), false)
		var fl := WorldKit.place(self, "castle/flag_pennant", Vector3(cos(a2) * r_out, top + 3.2, sin(a2) * r_out), rad_to_deg(-a2), 1.6)
		if fl:
			_flags.append(fl)
	_build_crowd()
	_build_life()


## Hohle Tribünen-Stufen als ein einziges Mesh (Stufen-Oberseite + Setzstufe), Lücken an den Toren.
func _tier_mesh() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 120
	for t in TIERS:
		var r0 := TIER_R0 + t * TIER_D
		var r1 := r0 + TIER_D
		var y0 := WALL_H + (t - 1) * TIER_RISE if t > 0 else 0.0
		var y1 := WALL_H + t * TIER_RISE
		var col := Color("#cbb48a").darkened(0.04 * float(t % 2)).lerp(Color("#e7d6b0"), 0.12 * float(t))
		for k in segs:
			var a0 := TAU * k / segs
			var a1 := TAU * (k + 1) / segs
			var am := (a0 + a1) * 0.5
			if absf(sin(am)) < 0.13 and t < 3:
				continue
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			st.set_color(col)
			st.set_normal(Vector3.UP)
			_quad(st, d0 * r0 + Vector3.UP * y1, d1 * r0 + Vector3.UP * y1, d1 * r1 + Vector3.UP * y1, d0 * r1 + Vector3.UP * y1)
			st.set_color(col.darkened(0.18))
			st.set_normal(-(d0 + d1).normalized())
			_quad(st, d0 * r0 + Vector3.UP * y0, d1 * r0 + Vector3.UP * y0, d1 * r0 + Vector3.UP * y1, d0 * r0 + Vector3.UP * y1)
	# Rückwand außen
	var ro := TIER_R0 + TIERS * TIER_D
	var yt := WALL_H + (TIERS - 1) * TIER_RISE + 1.4
	for k in segs:
		var a0 := TAU * k / segs
		var a1 := TAU * (k + 1) / segs
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		st.set_color(Color("#d9c39a"))
		st.set_normal(-(d0 + d1).normalized())
		_quad(st, d0 * ro, d1 * ro, d1 * ro + Vector3.UP * yt, d0 * ro + Vector3.UP * yt)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	return mi


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)


## Kleine Bewegung überall: Ballons, kreisende Vögel, ein Schiedsrichter-Küken, Wimpel.
func _build_life() -> void:
	var cols := [Color("#ff5c7a"), Color("#3fa7ff"), Color("#2ecc71"), Color("#ffd23f"), Color("#c79bff"), Color("#ff9f1a")]
	for k in 14:
		var b := Node3D.new()
		add_child(b)
		var a := randf() * TAU
		var r := randf_range(23.0, 33.0)
		b.position = Vector3(cos(a) * r, randf_range(8.0, 16.0), sin(a) * r)
		var sp := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.55
		sm.height = 1.3
		sm.material = WorldKit.mat(cols[k % cols.size()], 0.35)
		sp.mesh = sm
		b.add_child(sp)
		WorldKit.box(b, Vector3(0.03, 1.6, 0.03), Vector3(0, -1.4, 0), Color(1, 1, 1, 0.8), false)
		b.set_meta("ph", randf() * TAU)
		b.set_meta("base", b.position)
		_balloons.append(b)
	for k in 6:
		var bird := Node3D.new()
		add_child(bird)
		for side in [-1.0, 1.0]:
			var w := WorldKit.box(bird, Vector3(0.7, 0.05, 0.25), Vector3(side * 0.35, 0, 0), Color("#4a3a4a"), false)
			w.name = "W%d" % (0 if side < 0 else 1)
		bird.set_meta("ph", TAU * k / 6.0)
		bird.set_meta("r", randf_range(14.0, 30.0))
		bird.set_meta("h", randf_range(16.0, 22.0))
		_birds.append(bird)
	_ref = CharacterRig.new()
	add_child(_ref)
	_ref.setup("pet/chick", -1, 1.3)
	_ref.position = Vector3(0, 0, -7.5)
	_ref.face_now(Vector3(0, 0, 1))
	_ref.play("idle")


func _animate_life(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for b in _balloons:
		var base: Vector3 = b.get_meta("base")
		var ph := float(b.get_meta("ph"))
		b.position = base + Vector3(sin(t * 0.4 + ph) * 0.6, sin(t * 0.9 + ph) * 0.5, cos(t * 0.35 + ph) * 0.6)
		b.rotation.z = sin(t * 0.8 + ph) * 0.15
	for bird in _birds:
		var ph := float(bird.get_meta("ph")) + t * 0.25
		var r := float(bird.get_meta("r"))
		bird.position = Vector3(cos(ph) * r, float(bird.get_meta("h")) + sin(t + ph) * 0.8, sin(ph) * r)
		bird.rotation.y = -ph
		var flap := sin(t * 9.0 + ph * 3.0) * 0.6
		(bird.get_node("W0") as Node3D).rotation.z = flap
		(bird.get_node("W1") as Node3D).rotation.z = -flap
	for f in _flags:
		f.rotation.z = sin(t * 2.2 + f.position.x) * 0.06
	if _ref and _cheer > 0.8 and _ref.current != "cheer":
		_ref.play("cheer")
	elif _ref and _cheer < 0.4 and _ref.current == "cheer":
		_ref.play("idle")
	if _cheer > 0.9 and randf() < delta * 3.0:
		_release_balloon()


## Bei großem Jubel steigen Ballons aus dem Publikum auf.
func _release_balloon() -> void:
	var a := randf() * TAU
	var r := randf_range(TIER_R0 + 1.0, TIER_R0 + TIERS * TIER_D - 1.0)
	var b := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.4
	sm.height = 0.95
	sm.material = WorldKit.mat(Color.from_hsv(randf(), 0.6, 1.0), 0.35)
	b.mesh = sm
	add_child(b)
	b.position = Vector3(cos(a) * r, WALL_H + 3.0, sin(a) * r)
	var tw := b.create_tween()
	tw.tween_property(b, "position", b.position + Vector3(randf_range(-3, 3), 22.0, randf_range(-3, 3)), 7.0)
	tw.tween_callback(b.queue_free)


## Publikum: Jede Figur einmal in eine Textur gerendert (Atlas), dann Hunderte Billboards per MultiMesh;
## ein Shader lässt sie phasenversetzt hüpfen (stärker, wenn "cheer" hoch ist) und dunkelt hintere Reihen ab.
func _build_crowd() -> void:
	var atlas := await _render_atlas()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(1.4, 1.6)
	quad.center_offset = Vector3(0, 0.8, 0)
	mm.mesh = quad
	var places: Array[Transform3D] = []
	var customs: Array[Color] = []
	for tier in TIERS:
		var r := TIER_R0 + tier * TIER_D + TIER_D * 0.55
		var h := WALL_H + tier * TIER_RISE
		var count := int(TAU * r / 1.1)
		for k in count:
			var a := TAU * (k + (tier % 2) * 0.5) / count
			if absf(sin(a)) < 0.13 and tier < 3:
				continue   # Torbögen frei lassen
			var p := Vector3(cos(a) * r, h, sin(a) * r)
			places.append(Transform3D(Basis(), p))
			customs.append(Color(float(randi() % CROWD_MODELS.size()), randf() * TAU, 0.8 + randf() * 0.5, 1.0 - tier * 0.06))
	mm.instance_count = places.size()
	for k in places.size():
		mm.set_instance_transform(k, places[k])
		mm.set_instance_custom_data(k, customs[k])
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform float cols = 5.0;
uniform float rows = 2.0;
uniform float cheer = 0.25;
varying float shade;
void vertex() {
	float idx = INSTANCE_CUSTOM.r;
	float ph = INSTANCE_CUSTOM.g;
	float spd = INSTANCE_CUSTOM.b;
	shade = INSTANCE_CUSTOM.a;
	// Billboard um die Hochachse
	vec3 world_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - world_pos);
	vec3 right = normalize(vec3(to_cam.z, 0.0, -to_cam.x));
	float hop = abs(sin(TIME * 6.0 * spd + ph)) * (0.08 + cheer * 0.5);
	vec3 local = right * VERTEX.x + vec3(0.0, VERTEX.y + hop, 0.0);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world_pos + local, 1.0)).xyz;
	vec2 cell = vec2(mod(idx, cols), floor(idx / cols));
	UV = (UV + cell) / vec2(cols, rows);
}
void fragment() {
	vec4 c = texture(atlas, UV);
	if (c.a < 0.4) { discard; }
	ALBEDO = c.rgb * shade;
}"""
	_crowd_mat = ShaderMaterial.new()
	_crowd_mat.shader = sh
	_crowd_mat.set_shader_parameter("atlas", atlas)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _crowd_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## Rendert jede Publikums-Figur einmal in eine Kachel eines 5×2-Atlas (transparenter Hintergrund).
func _render_atlas() -> Texture2D:
	var cell := 128
	var img := Image.create(cell * 5, cell * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var vp := SubViewport.new()
	vp.size = Vector2i(cell, cell)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	vp.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.9, 0.9, 1.0)
	env.environment.ambient_light_energy = 0.8
	vp.add_child(env)
	var c := Camera3D.new()
	c.fov = 34.0
	vp.add_child(c)
	c.position = Vector3(0, 1.1, 4.0)
	c.look_at(Vector3(0, 0.9, 0))
	c.current = true
	for k in CROWD_MODELS.size():
		var r := CharacterRig.new()
		vp.add_child(r)
		r.setup(CROWD_MODELS[k], -1, 1.0 if String(CROWD_MODELS[k]).begins_with("hero/") else 1.5)
		r.face_now(Vector3(0, 0, 1))
		r.play("cheer")
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var shot := vp.get_texture().get_image()
		if shot:
			shot.convert(Image.FORMAT_RGBA8)
			img.blit_rect(shot, Rect2i(0, 0, cell, cell), Vector2i((k % 5) * cell, (k / 5) * cell))
		r.queue_free()
	vp.queue_free()
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# --- HUD --------------------------------------------------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_ui = UI.hud_root(layer)
	_banner = UI.label("", 64, UI.GOLD, true, 14)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui.add_child(_banner)
	UI.place(_banner, Control.PRESET_CENTER_TOP, Vector2(-560, 90), Vector2(1120, 90))
	_sub = UI.label("", 34, Color.WHITE, true, 10)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui.add_child(_sub)
	UI.place(_sub, Control.PRESET_CENTER_TOP, Vector2(-560, 176), Vector2(1120, 50))
	var pan := UI.panel(Color(0.12, 0.08, 0.16, 0.72), 22)
	_ui.add_child(pan)
	pan.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pan.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 18)
	_bracket_box = UI.hbox(26)
	pan.add_child(_bracket_box)


func _short(idx: int) -> String:
	var parts := String(state.cont[idx].name).split(" ")
	for w in ["Champion", "Gräfin", "Sir"]:
		if parts.size() > 1 and parts[0] == w:
			return parts[-1]
	return parts[0]


func _name_label(idx: int, dim: bool) -> Label:
	var c: Dictionary = state.cont[idx]
	var l := UI.label(_short(idx), 16, Color.WHITE, true, 5)
	if bool(c.human):
		l.add_theme_color_override("font_color", Game.player_color(int(c.slot)).lightened(0.35))
	if dim:
		l.modulate.a = 0.38
	return l


func _refresh_bracket() -> void:
	for c in _bracket_box.get_children():
		c.queue_free()
	for r in 4:
		var col := UI.vbox(2)
		_bracket_box.add_child(col)
		col.add_child(UI.label(["Viertelfinale", "Halbfinale", "Finale", "Champion"][r], 16, UI.GOLD if r == int(state.round) else UI.ACCENT2, true, 5))
		var lst: Array = state.bracket[r]
		if r == 3:
			if lst.is_empty():
				col.add_child(UI.label("?", 16, Color(1, 1, 1, 0.4), true, 5))
			else:
				var cl := _name_label(int(lst[0]), false)
				cl.text = "★ " + cl.text
				col.add_child(cl)
			continue
		var nxt: Array = state.bracket[r + 1]
		for k in range(0, 8 >> r, 2):
			var row := UI.hbox(6)
			col.add_child(row)
			for j in 2:
				if k + j < lst.size():
					var idx := int(lst[k + j])
					var decided := nxt.size() > k / 2 and (int(nxt[k / 2]) == int(lst[k]) or (k + 1 < lst.size() and int(nxt[k / 2]) == int(lst[k + 1])))
					row.add_child(_name_label(idx, decided and not (idx in nxt)))
				else:
					row.add_child(UI.label("?", 16, Color(1, 1, 1, 0.4), true, 5))
				if j == 0:
					row.add_child(UI.label("·", 16, Color(1, 1, 1, 0.5), true, 0))


func _show(text: String, sub := "", col := UI.GOLD, hold := 1.4) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", col)
	_sub.text = sub
	_banner.modulate.a = 1.0
	_sub.modulate.a = 1.0
	Juice.ui_punch(_banner, 0.25, 0.4)
	await get_tree().create_timer(hold).timeout
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.25)
	tw.tween_property(_sub, "modulate:a", 0.0, 0.25)
	await tw.finished
