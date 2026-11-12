extends MinigameBase
## Geister-Fotograf: In der knarzenden Geistervilla huschen kleine Buh-Geister umher und in alten Truhen
## funkeln Schätze. Mit Taschenlampe und uralter Kamera knipst jeder, was er erwischt – aber die Kamera
## lädt extrem langsam. Je ruhiger das Motiv und je mittiger im Lichtkegel, desto schärfer das Foto:
## Scharf = 3 Punkte, Okay = 2, Verwackelt = 1. Funkelnde Schätze bringen 2. Erschrockene Geister
## verpuffen und tauchen woanders wieder auf. Online: Host-Modell (Host simuliert Geister und Fotos).
##
## Licht: absichtlich dämmrig, aber nie stockdunkel – Mondlicht durch die Fenster, Kerzen, Kaminfeuer und
## leicht leuchtende Geister zeichnen die Konturen von Möbeln, Geistern und Schätzen.

const ROOM := Vector2(22.0, 15.0)
const CONE_DEG := 26.0
const CONE_RANGE := 10.0
const RECHARGE := 3.4

var ghosts: Array[Dictionary] = []      # {rig, base, phase, speed, state, t, vel, prev}
var chests: Array[Dictionary] = []      # {node, glint_t}
var _lamps: Array[SpotLight3D] = []
var _charge: Array[float] = [1.0, 1.0, 1.0, 1.0]
var _rings: Array[MeshInstance3D] = []
var _flash_n: Array[int] = [0, 0, 0, 0]
var _last_res: Array[String] = ["", "", "", ""]
var _seen_flash: Array[int] = [0, 0, 0, 0]
var _flicker: Array[OmniLight3D] = []
var _t := 0.0


func _init() -> void:
	game_id = "ghost_photo"
	no_seasonal = true   # geschlossener Raum
	env_preset = "mansion"
	backdrop_style = "none"
	time_limit = 45.0
	arena_radius = 9.0
	teaser_height = 0.9
	cannon_pos = Vector3(-8.5, 0, 6.5)
	net_model = "host"
	score_format = "%d Pkt."
	spawn_points = [Vector3(-4.5, 0.5, 4.0), Vector3(-1.5, 0.5, 4.0), Vector3(1.5, 0.5, 4.0), Vector3(4.5, 0.5, 4.0)]


# --- Geistervilla -----------------------------------------------------------------------------------------------

func build_arena() -> void:
	var hx := ROOM.x * 0.5
	var hz := ROOM.y * 0.5
	# Dielenboden mit Läufer
	WorldKit.box(world, Vector3(ROOM.x, 1, ROOM.y), Vector3(0, -0.5, 0), Color("#5a3d2e"))
	for k in 14:
		WorldKit.box(world, Vector3(ROOM.x, 0.02, 0.06), Vector3(0, 0.005, -hz + 0.5 + k * 1.05), Color("#3e2a20"), false)
	var rug := WorldKit.box(world, Vector3(9.0, 0.03, 5.5), Vector3(0, 0.02, 0.2), Color("#6a2a3a"), false)
	rug.name = "Rug"
	WorldKit.box(world, Vector3(8.4, 0.035, 4.9), Vector3(0, 0.025, 0.2), Color("#8a3a4a"), false)
	# Tapeten-Wände (hinten + Seiten; vorne nur eine niedrige Holzvertäfelung für freie Sicht)
	var wall := Color("#3e2a55")
	WorldKit.box(world, Vector3(ROOM.x, 7, 0.5), Vector3(0, 3.5, -hz), wall)
	WorldKit.box(world, Vector3(0.5, 7, ROOM.y), Vector3(-hx, 3.5, 0), wall)
	WorldKit.box(world, Vector3(0.5, 7, ROOM.y), Vector3(hx, 3.5, 0), wall)
	WorldKit.box(world, Vector3(ROOM.x, 1.0, 0.4), Vector3(0, 0.5, hz), Color("#4a3226"))
	for k in 11:
		WorldKit.box(world, Vector3(0.18, 6.2, 0.05), Vector3(-hx + 1.0 + k * 2.0, 3.3, -hz + 0.28), Color("#4a3366"), false)
	WorldKit.box(world, Vector3(ROOM.x, 1.1, 0.12), Vector3(0, 0.55, -hz + 0.3), Color("#4a3226"), false)
	# Fenster mit Mondlicht
	for x in [-6.5, 6.5]:
		var win := MeshInstance3D.new()
		var qm := BoxMesh.new()
		qm.size = Vector3(2.4, 3.2, 0.06)
		qm.material = WorldKit.mat(Color("#8fa6ff"), 0.2, 0.9)
		win.mesh = qm
		win.position = Vector3(x, 3.6, -hz + 0.3)
		world.add_child(win)
		WorldKit.box(world, Vector3(2.7, 0.16, 0.12), Vector3(x, 3.6, -hz + 0.34), Color("#2a1a12"), false)
		WorldKit.box(world, Vector3(0.16, 3.5, 0.12), Vector3(x, 3.6, -hz + 0.34), Color("#2a1a12"), false)
		var moon := SpotLight3D.new()
		moon.light_color = Color(0.62, 0.7, 1.0)
		moon.light_energy = 2.2
		moon.spot_range = 16.0
		moon.spot_angle = 38.0
		world.add_child(moon)
		moon.position = Vector3(x, 5.0, -hz + 1.0)
		moon.look_at(Vector3(x * 0.6, 0, 1.0), Vector3.UP)
		# Gardinen
		for sd in [-1.0, 1.0]:
			WorldKit.box(world, Vector3(0.5, 3.8, 0.08), Vector3(x + sd * 1.55, 3.5, -hz + 0.42), Color("#5a1a2a"), false)
	# Kamin mit Feuer
	WorldKit.box(world, Vector3(3.2, 2.4, 0.9), Vector3(0, 1.2, -hz + 0.6), Color("#6a5a5a"))
	WorldKit.box(world, Vector3(1.8, 1.3, 0.5), Vector3(0, 0.65, -hz + 0.95), Color("#1a1010"), false)
	WorldKit.box(world, Vector3(3.6, 0.2, 1.1), Vector3(0, 2.45, -hz + 0.65), Color("#3e2a20"), false)
	var fire := FX.emitter({"amount": 24, "life": 0.8, "one_shot": false, "explosive": 0.0, "spread": 20.0, "dir": Vector3.UP,
		"vel_min": 0.6, "vel_max": 1.4, "gravity": Vector3(0, 0.6, 0), "size": 0.3, "additive": true, "color": Color(1.0, 0.55, 0.2, 0.9), "box": Vector3(0.8, 0.1, 0.2)})
	world.add_child(fire)
	fire.position = Vector3(0, 0.2, -hz + 1.0)
	fire.emitting = true
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.55, 0.25)
	fl.light_energy = 1.6
	fl.omni_range = 7.0
	fl.position = Vector3(0, 1.0, -hz + 1.6)
	world.add_child(fl)
	_flicker.append(fl)
	# Einrichtung (KayKit Furniture Bits) eng an den Wänden – die Raummitte bleibt frei zum Herumschleichen; die Möbel
	# sind fest (niemand läuft durch Sessel oder Schränke)
	for x in [-6.5, 6.5]:
		WorldKit.place(world, "fur/shelf_b_large_decorated", Vector3(x, 0, -hz + 0.62), 0.0, 1.0, true)   # unter den Fenstern
	for sx in [-1.0, 1.0]:
		WorldKit.place(world, "fur/cabinet_medium_decorated", Vector3(sx * (hx - 1.35), 0, -hz + 0.85), 0.0, 1.0, true)
		WorldKit.place(world, "fur/armchair_pillows", Vector3(sx * (hx - 1.15), 0, -1.6), -sx * 90.0, 1.0, true)
		WorldKit.place(world, "fur/lamp_standing", Vector3(sx * (hx - 0.85), 0, -3.4), 0.0, 1.0, true)
		WorldKit.place(world, "fur/table_low", Vector3(sx * (hx - 1.2), 0, 1.6), 90.0, 0.8, true)
		WorldKit.place(world, "fur/book_set", Vector3(sx * (hx - 1.2), 0.42, 1.6), sx * 20.0, 1.0)
	# Gemälde über dem Kamin und an den Wänden (mit leise leuchtenden Augen)
	for pp in [Vector3(0, 4.3, -hz + 0.32), Vector3(-hx + 0.32, 3.6, -2.5), Vector3(hx - 0.32, 3.6, -2.5)]:
		var side_wall: bool = absf(pp.x) > 1.0
		var fr := WorldKit.box(world, Vector3(0.08 if side_wall else 2.0, 1.4, 2.0 if side_wall else 0.08), pp, Color("#8a6a2a"), false)
		fr.name = "Frame"
		var inner := WorldKit.box(world, Vector3(0.1 if side_wall else 1.6, 1.0, 1.6 if side_wall else 0.1), pp + (Vector3(0.02 * signf(-pp.x), 0, 0) if side_wall else Vector3(0, 0, 0.02)), Color("#2a3a4a"), false)
		inner.name = "Portrait"
		for ex in [-0.22, 0.22]:
			var eye := MeshInstance3D.new()
			var es := SphereMesh.new()
			es.radius = 0.06
			es.height = 0.12
			es.material = WorldKit.mat(Color("#ffe27a"), 0.3, 1.4)
			eye.mesh = es
			eye.position = pp + (Vector3(0.08 * signf(-pp.x), 0.15, ex) if side_wall else Vector3(ex, 0.15, 0.08))
			world.add_child(eye)
	# Kronleuchter mit flackernden Kerzen
	var chand := Node3D.new()
	world.add_child(chand)
	chand.position = Vector3(0, 5.4, 0.2)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.0
	tm.outer_radius = 1.15
	tm.material = WorldKit.mat(Color("#b08a3a"), 0.4)
	ring.mesh = tm
	chand.add_child(ring)
	WorldKit.cylinder(chand, 0.04, 2.0, Vector3(0, 1.0, 0), Color("#3a2a1a"), false)
	for k in 6:
		var a := TAU * k / 6.0
		Assets.spawn("dun/candle", chand, Vector3(cos(a) * 1.07, 0.05, sin(a) * 1.07), 0.0, 1.2)
	var cl := OmniLight3D.new()
	cl.light_color = Color(1.0, 0.82, 0.55)
	cl.light_energy = 1.3
	cl.omni_range = 9.0
	chand.add_child(cl)
	_flicker.append(cl)
	var sway := chand.create_tween().set_loops()
	sway.tween_property(chand, "rotation:z", 0.04, 1.8).set_trans(Tween.TRANS_SINE)
	sway.tween_property(chand, "rotation:z", -0.04, 1.8).set_trans(Tween.TRANS_SINE)
	# Möbel: Sofa, Sessel, Tische, Bücherregale, Standuhr, verhüllte Möbel, Fässer, Sarg
	_sofa(Vector3(-6.2, 0, -3.6), 0.0, Color("#5a2a4a"))
	_sofa(Vector3(6.4, 0, 1.8), -90.0, Color("#2a4a5a"))
	for tp in [Vector3(-2.6, 0, -1.6), Vector3(3.2, 0, -3.0)]:
		WorldKit.place(world, "dun/table", tp, 0.0, 1.0, true)
		var cd := Assets.spawn("dun/candle", world, tp + Vector3(0, 0.95, 0), 0.0, 1.3)
		cd.name = "Candle"
		var cdl := OmniLight3D.new()
		cdl.light_color = Color(1.0, 0.75, 0.45)
		cdl.light_energy = 0.9
		cdl.omni_range = 4.5
		cdl.position = tp + Vector3(0, 1.4, 0)
		world.add_child(cdl)
		_flicker.append(cdl)
	for sp in [Vector3(-hx + 0.8, 0, 2.5), Vector3(hx - 0.8, 0, -4.6)]:
		var sh := WorldKit.place(world, "dun/shelf", sp, 90.0 if sp.x < 0 else -90.0, 1.4, true)
		sh.name = "Shelf"
		for b in 8:
			var book := WorldKit.box(world, Vector3(0.14, 0.42, 0.32), sp + Vector3(0.0, 0.7 + (b / 4) * 0.8, -0.6 + (b % 4) * 0.36), [Color("#a33a3a"), Color("#3a6aa3"), Color("#3aa36a"), Color("#a38a3a")][b % 4], false)
			book.name = "Book"
	# Standuhr mit pendelndem Perpendikel
	WorldKit.box(world, Vector3(0.9, 3.0, 0.6), Vector3(-9.6, 1.5, -6.2), Color("#4a2a1a"))
	var face := WorldKit.cylinder(world, 0.32, 0.05, Vector3(-9.6, 2.55, -5.88), Color("#f2ead8"), false)
	face.rotation.x = PI * 0.5
	var pend := Node3D.new()
	world.add_child(pend)
	pend.position = Vector3(-9.6, 2.1, -5.86)
	WorldKit.box(pend, Vector3(0.05, 1.0, 0.03), Vector3(0, -0.5, 0), Color("#d9b46a"), false)
	var pt := pend.create_tween().set_loops()
	pt.tween_property(pend, "rotation:z", 0.35, 1.0).set_trans(Tween.TRANS_SINE)
	pt.tween_property(pend, "rotation:z", -0.35, 1.0).set_trans(Tween.TRANS_SINE)
	# Mit Laken verhüllte Möbel (weich, hell – gut erkennbar im Halbdunkel)
	for vp in [Vector3(8.6, 0, -5.4), Vector3(-8.4, 0, 5.4), Vector3(1.0, 0, -5.8)]:
		var sheet := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.9
		sm.height = 1.6
		sm.material = WorldKit.mat(Color("#d9d4e8"), 1.0, 0.05)
		sheet.mesh = sm
		sheet.scale = Vector3(1.2, 0.9, 1.0)
		sheet.position = vp + Vector3(0, 0.7, 0)
		world.add_child(sheet)
	for bp in [Vector3(9.4, 0, 6.0), Vector3(9.0, 0, 5.0)]:
		WorldKit.place(world, "dun/barrel", bp, 0.0, 1.1)
	WorldKit.place(world, "grave/coffin", Vector3(-9.0, 0, -1.2), 90.0, 1.3)
	WorldKit.place(world, "grave/pumpkin", Vector3(5.5, 0, 5.8), 0.0, 1.6)
	WorldKit.place(world, "grave/candles", Vector3(-4.8, 0, 5.8), 0.0, 1.8)
	# Spinnweben in den Ecken
	for cw in [Vector3(-hx + 0.4, 6.4, -hz + 0.4), Vector3(hx - 0.4, 6.4, -hz + 0.4)]:
		for k in 3:
			var web := MeshInstance3D.new()
			var wb := BoxMesh.new()
			wb.size = Vector3(1.6 - k * 0.4, 0.02, 0.02)
			var wm := WorldKit.mat(Color(1, 1, 1, 0.5), 1.0, 0.2)
			wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			wb.material = wm
			web.mesh = wb
			web.position = cw + Vector3(0, -k * 0.35, 0)
			web.rotation = Vector3(0, PI * 0.25 * signf(-cw.x), 0.5 * signf(cw.x))
			world.add_child(web)
	# Schätze: Truhen und Münzstapel, die ab und zu funkeln
	for cp in [Vector3(-7.6, 0, -0.2), Vector3(7.8, 0, -1.6), Vector3(-1.4, 0, -5.4), Vector3(4.6, 0, 3.8), Vector3(-6.0, 0, 3.0)]:
		var key := "dun/chest_gold" if chests.size() % 2 == 0 else "dun/chest"
		var c := Assets.spawn(key, world, cp, randf() * 60.0 - 30.0, 1.1)
		chests.append({"node": c, "glint": 0.0, "id": chests.size()})
	# Staubpartikel im Mondlicht
	var dust := FX.emitter({"amount": 60, "life": 6.0, "one_shot": false, "explosive": 0.0, "spread": 180.0, "vel_min": 0.02, "vel_max": 0.12,
		"gravity": Vector3(0, -0.01, 0), "size": 0.05, "additive": true, "color": Color(0.8, 0.85, 1.0, 0.6), "box": Vector3(ROOM.x, 4, ROOM.y)})
	world.add_child(dust)
	dust.position = Vector3(0, 2.5, 0)
	dust.preprocess = 4.0
	dust.emitting = true
	# Die Geister
	for k in 6:
		var g := CharacterRig.new()
		world.add_child(g)
		g.setup("npc/ghost", -1, 1.0)
		Assets.tint(g, Color(1.0, 1.0, 1.1, 0.88), false, 0.35)
		g.play("idle")
		var base := Vector3(rng.randf_range(-8, 8), 1.3, rng.randf_range(-5, 3))
		g.position = base
		ghosts.append({"rig": g, "base": base, "phase": rng.randf() * TAU, "speed": rng.randf_range(0.4, 0.8), "state": "drift",
			"t": rng.randf_range(2.0, 5.0), "vel": 0.0, "prev": base, "dash_to": base, "id": k})


func _sofa(p: Vector3, rot: float, col: Color) -> void:
	var n := Node3D.new()
	world.add_child(n)
	n.position = p
	n.rotation_degrees.y = rot
	WorldKit.box(n, Vector3(2.6, 0.6, 1.0), Vector3(0, 0.3, 0), col)
	WorldKit.box(n, Vector3(2.6, 0.9, 0.3), Vector3(0, 0.75, -0.4), col.darkened(0.15), false)
	for sd in [-1.0, 1.0]:
		WorldKit.box(n, Vector3(0.3, 0.8, 1.0), Vector3(sd * 1.3, 0.5, 0), col.darkened(0.1), false)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0.6, 0.4)
	c.offset = Vector3(0, 12.5, 10.5)
	c.min_dist = 1.0
	c.max_dist = 1.0
	c.follow = false


func spawn_players() -> void:
	super.spawn_players()
	for i in 4:
		var av := avatars[i] as PartyAvatar
		var lamp := SpotLight3D.new()
		lamp.light_color = Color(1.0, 0.93, 0.75).lerp(Game.player_color(i), 0.15)
		lamp.light_energy = 3.2
		lamp.spot_range = CONE_RANGE
		lamp.spot_angle = CONE_DEG + 4.0
		lamp.spot_attenuation = 0.6
		lamp.position = Vector3(0, 1.25, 0)
		av.rig.add_child(lamp)
		lamp.rotation.x = -0.18
		_lamps.append(lamp)
		var rg := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.5
		tm.outer_radius = 0.6
		tm.material = WorldKit.mat(Game.player_color(i), 0.4, 1.0)
		rg.mesh = tm
		rg.position = Vector3(0, 0.06, 0)
		av.add_child(rg)
		_rings.append(rg)


# --- Intro: zitternd mit Taschenlampen herein, eine Lampe klemmt … und blitzt in die Kamera -------------------

func custom_entrance(d: Node, targets: Array[Vector3], cs: Node) -> void:
	var door := Vector3(-ROOM.x * 0.5 + 1.2, 0.5, ROOM.y * 0.5 - 1.0)
	d.cut(Vector3(0, 6.0, 12.0), Vector3(-2, 1.0, 1.5), 50.0)
	Audio.sfx("creak", door, -2.0, 0.8)
	Audio.sfx("door", door, -4.0)
	var dud := 2   # dessen Lampe zunächst nicht geht
	_lamps[dud].visible = false
	for i in 4:
		var av := avatars[i] as PartyAvatar
		av.global_position = door
		av.visible = true
		av.rig.play("sneak" if av.rig.has_clip("sneak") else "walk", 0.1, 0.8)
		av.rig.face_now(targets[i] - door)
		var tw := av.create_tween()
		tw.tween_property(av, "global_position", targets[i], 1.6 + i * 0.15).set_trans(Tween.TRANS_SINE)
		# Zittern
		var shake := av.rig.create_tween().set_loops(10)
		shake.tween_property(av.rig, "rotation:z", 0.06, 0.06)
		shake.tween_property(av.rig, "rotation:z", -0.06, 0.06)
		await d.wait(0.35)
	await d.wait(1.6)
	for i in 4:
		var av2 := avatars[i] as PartyAvatar
		av2.rig.rotation.z = 0.0
		av2.rig.play("idle")
		av2.rig.face_now(Vector3(0, 0, -1))
		av2.rig.react("scared")
	Audio.sfx("ghost", Vector3.ZERO, -6.0)
	await d.wait(0.8)
	# Die klemmende Lampe: draufklopfen, flackern …
	var dav := avatars[dud] as PartyAvatar
	var dp := dav.global_position
	d.cut(dp + Vector3(1.6, 1.8, 3.2), dp + Vector3.UP * 1.2, 40.0)
	dav.rig.face_now(Vector3(1, 0, 1))
	await d.wait(0.4)
	for k in 3:
		dav.rig.play_once("interact")
		Audio.sfx("wood_hit", dp, -10.0, 1.6)
		await d.wait(0.32)
	for k in 5:
		_lamps[dud].visible = k % 2 == 0
		Audio.sfx("click", dp, -10.0, 1.4)
		await d.wait(0.07 + k * 0.02)
	_lamps[dud].visible = true
	# … und dreht sich – direkt in die Kamera!
	var cam_pos: Vector3 = (d.cam as Camera3D).global_position
	dav.rig.face_now(cam_pos - dp)
	_lamps[dud].look_at(cam_pos, Vector3.UP)
	dav.rig.react("surprised" if dav.rig.has_clip("surprised") else "scared")
	Audio.sfx("zap", dp, -2.0, 1.2)
	d.flash(Color(1, 1, 1, 1), 0.55)
	Juice.shake(0.2)
	await d.wait(0.35)
	_lamps[dud].rotation = Vector3(-0.18, 0, 0)
	dav.rig.face_now(Vector3(0, 0, -1))


func on_start() -> void:
	for i in 4:
		var av := avatars[i] as PartyAvatar
		av.can_jump = false
		av.can_shove = false
		av.max_speed = 5.2
		_charge[i] = 1.0


# --- Spiel ------------------------------------------------------------------------------------------------------

func on_tick(delta: float) -> void:
	_t += delta
	for fl in _flicker:
		fl.light_energy = fl.light_energy * 0.8 + (1.2 + sin(_t * 13.0 + fl.position.x) * 0.25 + randf_range(-0.2, 0.2)) * 0.2
	_update_ghosts(delta)
	for c in chests:
		c.glint = maxf(0.0, float(c.glint) - delta)
		if float(c.glint) <= 0.0 and rng.randf() < delta * 0.12:
			c.glint = 2.2
			FX.stars((c.node as Node3D).global_position + Vector3.UP * 0.9, Color(1, 0.9, 0.4), 10)
			Audio.sfx("ding", (c.node as Node3D).global_position, -12.0, 1.5)
	for i in active_slots():
		_charge[i] = minf(1.0, _charge[i] + delta / RECHARGE)
		_rings[i].scale = Vector3.ONE * (0.4 + _charge[i] * 0.6)
		(_rings[i].mesh.surface_get_material(0) as StandardMaterial3D).emission_energy_multiplier = 0.3 + (1.4 if _charge[i] >= 1.0 else 0.0)
		if InputHub.pressed(i, "a") and _charge[i] >= 1.0:
			_snap(i)


func _update_ghosts(delta: float) -> void:
	for g in ghosts:
		var r: CharacterRig = g.rig
		g.t = float(g.t) - delta
		var prev: Vector3 = r.position
		match String(g.state):
			"drift":
				var ph := float(g.phase) + _t * float(g.speed)
				var base: Vector3 = g.base
				r.position = base + Vector3(sin(ph) * 2.2, sin(ph * 2.3) * 0.35, cos(ph * 0.7) * 1.6)
				if float(g.t) <= 0.0:
					g.state = "dash"
					g.t = rng.randf_range(0.8, 1.3)
					g.dash_to = Vector3(rng.randf_range(-8.5, 8.5), 1.3, rng.randf_range(-5.5, 4.0))
			"dash":
				r.position = r.position.move_toward(g.dash_to, delta * 9.0)
				if float(g.t) <= 0.0 or r.position.distance_to(g.dash_to) < 0.2:
					g.state = "drift"
					g.base = r.position
					g.phase = 0.0
					g.t = rng.randf_range(2.5, 5.5)
			"gone":
				if float(g.t) <= 0.0:
					g.state = "drift"
					g.base = Vector3(rng.randf_range(-8, 8), 1.3, rng.randf_range(-5, 3))
					r.position = g.base
					r.visible = true
					Juice.pop_in(r, 0.35)
					FX.smoke(r.position, Color(0.8, 0.85, 1.0), 6, 0.6)
					g.t = rng.randf_range(2.0, 4.0)
		g.vel = (r.position - prev).length() / maxf(delta, 0.001)
		if (r.position - prev).length() > 0.001:
			r.face_now(r.position - prev)


func _forward(i: int) -> Vector3:
	var rot := (avatars[i] as PartyAvatar).rig.global_rotation.y
	return Vector3(-sin(rot), 0, -cos(rot))


func _snap(i: int) -> void:
	_charge[i] = 0.0
	var av := avatars[i] as PartyAvatar
	var eye := av.global_position + Vector3.UP * 1.2
	var fwd := _forward(i)
	var pts := 0
	var best := ""
	for g in ghosts:
		if String(g.state) == "gone":
			continue
		var r: CharacterRig = g.rig
		var to := r.global_position - eye
		var dist := to.length()
		if dist > CONE_RANGE:
			continue
		var ang := rad_to_deg(acos(clampf(Vector3(to.x, 0, to.z).normalized().dot(fwd), -1.0, 1.0)))
		if ang > CONE_DEG:
			continue
		var q := _quality(ang, float(g.vel))
		pts += q
		best = _better(best, q)
		g.state = "gone"
		g.t = rng.randf_range(3.5, 6.0)
		r.react("scared")
		FX.smoke(r.global_position, Color(0.85, 0.9, 1.0), 10, 0.8)
		Juice.float_text(self, r.global_position + Vector3.UP * 0.8, "Buh!", Color("#c9b5ff"), 60)
		var hide := r.create_tween()
		hide.tween_interval(0.35)
		hide.tween_callback(func() -> void: r.visible = false)
	for c in chests:
		if float(c.glint) <= 0.0:
			continue
		var to2 := (c.node as Node3D).global_position - eye
		if to2.length() > CONE_RANGE:
			continue
		var ang2 := rad_to_deg(acos(clampf(Vector3(to2.x, 0, to2.z).normalized().dot(fwd), -1.0, 1.0)))
		if ang2 <= CONE_DEG:
			pts += 2
			best = _better(best, 2)
			c.glint = 0.0
			FX.coins_burst((c.node as Node3D).global_position + Vector3.UP, 4, true, world)
	scores[i] += pts
	var txt := "Nichts drauf …" if pts == 0 else ("%s +%d" % [best, pts])
	_flash_n[i] += 1
	_last_res[i] = txt
	_flash_fx(i, txt, pts)


func _quality(ang: float, speed: float) -> int:
	if speed > 4.0:
		return 1   # huschte vorbei → verwackelt
	if ang < 11.0 and speed < 1.6:
		return 3
	return 2


func _better(cur: String, q: int) -> String:
	var name := {3: "Scharf!", 2: "Okay!", 1: "Verwackelt!"}[q] as String
	if cur == "Scharf!" or (cur == "Okay!" and q == 1):
		return cur
	return name


## Blitzlicht, Klick und das "Polaroid" über dem Kopf (auch auf Online-Clients).
func _flash_fx(i: int, txt: String, pts: int) -> void:
	var av := avatars[i] as PartyAvatar
	var fl := OmniLight3D.new()
	fl.light_color = Color(1, 1, 1)
	fl.light_energy = 6.0
	fl.omni_range = 10.0
	fl.position = av.global_position + Vector3.UP * 1.4 + _forward(i) * 1.0
	world.add_child(fl)
	var tw := fl.create_tween()
	tw.tween_property(fl, "light_energy", 0.0, 0.25)
	tw.tween_callback(fl.queue_free)
	Audio.sfx("click", av.global_position, 0.0, 0.8)
	Audio.sfx("glass", av.global_position, -10.0, 1.6)
	av.rig.play_once("use" if av.rig.has_clip("use") else "interact")
	var col := UI.GOLD if pts >= 3 else (Color("#7dff9a") if pts == 2 else (Color("#8fb0ff") if pts == 1 else Color(1, 1, 1, 0.6)))
	Juice.float_text(self, av.global_position + Vector3.UP * 2.6, txt, col, 64)
	if pts >= 3:
		Audio.sfx("sparkle_up", null, -8.0)


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	var gs: Array = []
	for g in ghosts:
		var p := (g.rig as Node3D).position
		gs.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01), 0 if String(g.state) == "gone" else 1])
	d["g"] = gs
	d["c"] = chests.map(func(c: Dictionary) -> int: return 1 if float(c.glint) > 0.0 else 0)
	d["fn"] = _flash_n
	d["fr"] = _last_res
	d["ch"] = _charge.map(func(v: float) -> float: return snappedf(v, 0.05))
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var gs: Array = d.get("g", [])
	for k in mini(gs.size(), ghosts.size()):
		var e: Array = gs[k]
		var r: CharacterRig = ghosts[k].rig
		var np := Vector3(float(e[0]), float(e[1]), float(e[2]))
		if (np - r.position).length() > 0.001:
			r.face_now(np - r.position)
		r.position = r.position.lerp(np, 0.6)
		r.visible = int(e[3]) == 1
	var cs: Array = d.get("c", [])
	for k in mini(cs.size(), chests.size()):
		var was := float(chests[k].glint) > 0.0
		chests[k].glint = 1.0 if int(cs[k]) == 1 else 0.0
		if int(cs[k]) == 1 and not was:
			FX.stars((chests[k].node as Node3D).global_position + Vector3.UP * 0.9, Color(1, 0.9, 0.4), 10)
	var fn: Array = d.get("fn", [])
	var fr: Array = d.get("fr", [])
	for i in mini(4, fn.size()):
		if int(fn[i]) != _seen_flash[i]:
			_seen_flash[i] = int(fn[i])
			var txt := String(fr[i]) if i < fr.size() else ""
			var pts := 3 if txt.begins_with("Scharf") else (2 if txt.begins_with("Okay") else (1 if txt.begins_with("Verwackelt") else 0))
			_flash_fx(i, txt, pts)
	var ch: Array = d.get("ch", [])
	for i in mini(4, ch.size()):
		_rings[i].scale = Vector3.ONE * (0.4 + float(ch[i]) * 0.6)


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	var level: int = Game.players[slot].cpu_level
	var mem := cpu_mem[slot]
	var best: Dictionary = {}
	var bd := INF
	for g in ghosts:
		if String(g.state) == "gone":
			continue
		var dd := (g.rig as Node3D).global_position.distance_to(av.global_position)
		if dd < bd:
			bd = dd
			best = g
	var mv := Vector2.ZERO
	var held := {}
	if not best.is_empty():
		var tp: Vector3 = (best.rig as Node3D).global_position
		var to := tp - av.global_position
		var want := 5.0 - level
		if to.length() > want:
			mv = Vector2(to.x, to.z).normalized()
		else:
			mv = Vector2(to.x, to.z).normalized() * 0.15   # nur ausrichten
		var ang := rad_to_deg(acos(clampf(Vector3(to.x, 0, to.z).normalized().dot(_forward(slot)), -1.0, 1.0)))
		mem["wait"] = float(mem.get("wait", 0.0)) - delta
		if _charge[slot] >= 1.0 and ang < Game.lv([20.0, 14.0, 9.0], level) and float(mem.wait) <= 0.0 and float(best.vel) < Game.lv([6.0, 3.0, 1.8], level):
			held["a"] = true
			mem["wait"] = randf_range(0.2, 0.6)
	InputHub.set_virtual(slot, mv, held)
