extends MinigameBase
## Boss-Kampf: Rundenbasiertes Würfel-Duell gegen einen der zehn Brett-Bosse (siehe BossDefs) auf einer
## Ring-Arena aus 20 Feldern rund um den Boss.
##   1. Würfeln: Alle stoppen gleichzeitig ihren Würfelblock (A).
##   2. Ziehen: Nacheinander hüpfen alle über den Ring. Angriffsfelder treffen den Boss (Schaden = Punkte),
##      Münzfelder bringen Münzen, Spezialfelder lösen die Einzigartigkeit des Bosses aus.
##   3. Bossrunde: Der Boss kündigt eine Fähigkeit an und setzt sie ein (Phase 3 = Wut: zwei pro Runde).
## Phasen bei 66 % / 33 % Lebenspunkten. Besiegt ihr ihn in 10 Runden, gibt es Bonuspunkte für den finalen
## Treffer; sonst flieht er. Münz- und Item-Effekte werden auf dem Brett verrechnet (result_extra).
## Online: Host-Modell (Host würfelt & simuliert, Clients zeigen Zustand und Boss-Animationen).

const RING := 20
const RING_R := 10.5
const MAX_ROUNDS := 10

var boss_id := ""
var def: Dictionary = {}
var model: BossModel
var hp := 40.0
var max_hp := 40.0
var bphase := 1
var round_n := 0
var fields: Array[Dictionary] = []
var fpos: Array[int] = [0, 5, 10, 15]
var status: Array[Dictionary] = [{}, {}, {}, {}]
var rolls: Array[int] = [0, 0, 0, 0]
var rolling: Array[bool] = [false, false, false, false]
var coin_delta: Array[int] = [0, 0, 0, 0]
var item_steal: Array[int] = [0, 0, 0, 0]
var move_dir := 1
var dir_t := 0
var night := false
var night_t := 0
var flood := false
var flood_t := 0
var armor_t := 0
var fog_t := 0
var slide_t := 0
var overclock_t := 0
var frost_armor := true
var defeated := false
var _last_ability := ""
var _act_seq := 0
var _act_kind := ""
var _say_text := ""
var _hp_fill: ColorRect
var _hp_label: Label
var _say_label: Label
var _dice: Array[Node3D] = []
var _dice_labels: Array[Label3D] = []
var _sun: DirectionalLight3D
var _water: Node3D


func _init() -> void:
	game_id = "boss_battle"
	time_limit = 999.0
	show_timer = false
	arena_radius = 13.0
	teaser_height = 2.0
	cannon_pos = Vector3(0, 0, 16)
	net_model = "host"
	score_format = "%d Schaden"
	music_track = 3
	boss_id = String(Game.minigame_setup.get("boss", ""))
	spawn_points = []
	for i in 4:
		spawn_points.append(_field_pos(i * 5) + Vector3(0, 0.6, 0))


func on_setup() -> void:
	if boss_id == "" or not BossDefs.BOSSES.has(boss_id):
		if Game.mode == "party":
			boss_id = BossDefs.for_board(String(Game.party.get("board", "meadow")))
		else:
			var keys := BossDefs.BOSSES.keys()
			boss_id = String(keys[rng.randi() % keys.size()])
	def = BossDefs.get_def(boss_id)
	env_preset = String(def.env)
	backdrop_style = String(def.backdrop)
	info = info.duplicate()
	info["name"] = "%s – %s" % [def.name, def.title]
	info["desc"] = "%s Würfelt gemeinsam über den Ring: Angriffsfelder treffen den Boss, Schaden zählt als Punkte. %s" % [def.intro, def.unique]
	info["controls"] = "A: Würfel stoppen"
	var n := maxi(1, active_slots().size())
	max_hp = 8.0 * n + 6.0
	hp = max_hp


func _field_pos(i: int) -> Vector3:
	var a := TAU * float(i) / RING + PI * 0.5
	return Vector3(cos(a) * RING_R, 0.0, sin(a) * RING_R)


# --- Arena ------------------------------------------------------------------------------------------------------

func build_arena() -> void:
	var ground: Color = def.ground
	var tile: Color = def.tile
	WorldKit.cylinder(world, 14.5, 1.0, Vector3(0, -0.5, 0), ground)
	WorldKit.cylinder(world, 6.0, 0.3, Vector3(0, 0.05, -0.5), tile.darkened(0.08), false)
	match String(def.env):
		"dungeon":
			WorldKit.lava(world, Vector2(90, 90), -0.7)
		"pirates":
			_water = WorldKit.water(world, Vector2(120, 120), -0.4)
	var layout := String(def.layout)
	for i in RING:
		var ty := layout[i % layout.length()]
		var node := Node3D.new()
		world.add_child(node)
		node.position = _field_pos(i)
		var col: Color = BossDefs.FIELD_COLORS.get(ty, tile)
		var base := WorldKit.cylinder(node, 1.2, 0.28, Vector3(0, 0.14, 0), col.lerp(tile, 0.15), false)
		base.name = "Tile"
		WorldKit.cylinder(node, 1.3, 0.16, Vector3(0, 0.06, 0), tile.darkened(0.25), false)
		_field_prop(ty, node)
		var st := Label3D.new()
		st.text = BossDefs.FIELD_NAMES.get(ty, "") if ty != "N" else ""
		st.font_size = 40
		st.outline_size = 10
		st.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		st.position = Vector3(0, 0.55, 0.9)
		st.modulate = col.lightened(0.3)
		node.add_child(st)
		fields.append({"type": ty, "node": node, "block": 0, "crack": 0, "sheep": 0, "cherry": 0, "coins": 0,
			"broken": false, "synced": false, "collected": false, "fx": null})
	model = BossModel.create(boss_id)
	model.set_meta("keep_visible", true)
	world.add_child(model)
	model.position = Vector3(0, 0.2, -0.8)
	# Würfelblöcke über den Köpfen
	for i in 4:
		var d := Node3D.new()
		world.add_child(d)
		var cube := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.9, 0.9, 0.9)
		bm.material = WorldKit.mat(Color("#fff7e6"), 0.4, 0.15)
		cube.mesh = bm
		d.add_child(cube)
		var lb := Label3D.new()
		lb.font_size = 96
		lb.outline_size = 16
		lb.modulate = Game.player_color(i)
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.no_depth_test = true
		lb.position = Vector3(0, 0, 0.5)
		d.add_child(lb)
		d.visible = false
		_dice.append(d)
		_dice_labels.append(lb)


## Kleine 3D-Requisite je Feldtyp.
func _field_prop(ty: String, n: Node3D) -> void:
	match ty:
		"A":
			var sw := Node3D.new()
			n.add_child(sw)
			sw.position = Vector3(0, 0.85, 0)
			WorldKit.box(sw, Vector3(0.12, 0.9, 0.05), Vector3(0, 0.15, 0), Color("#e8eef8"), false)
			WorldKit.box(sw, Vector3(0.5, 0.08, 0.1), Vector3(0, -0.3, 0), Color("#ffcf3a"), false)
			sw.rotation.z = 0.6
			var tw := sw.create_tween().set_loops()
			tw.tween_property(sw, "position:y", 1.05, 0.8).set_trans(Tween.TRANS_SINE)
			tw.tween_property(sw, "position:y", 0.85, 0.8).set_trans(Tween.TRANS_SINE)
		"C":
			var c := WorldKit.cylinder(n, 0.32, 0.08, Vector3(0, 0.75, 0), Color("#ffd23f"), false)
			c.rotation.x = PI * 0.5
			var tw2 := c.create_tween().set_loops()
			tw2.tween_property(c, "rotation:y", TAU, 1.6).as_relative()
		"R":
			for k in 3:
				var cr := WorldKit.box(n, Vector3(0.9, 0.03, 0.06), Vector3(randf_range(-0.3, 0.3), 0.3, randf_range(-0.4, 0.4)), Color("#2a1a14"), false)
				cr.rotation.y = randf() * PI
		"H":
			WorldKit.cylinder(n, 1.05, 0.5, Vector3(0, 0.4, 0), Color("#f6e3a8"), false)
			WorldKit.place(n, "pirate/palm", Vector3(0.6, 0.6, -0.4), 30.0, 0.8)
		"K":
			var cn := WorldKit.cylinder(n, 0.35, 0.8, Vector3(0, 0.6, 0), Color("#ffffff"), false)
			cn.rotation.x = -0.7
		"T":
			var tomb := WorldKit.box(n, Vector3(0.8, 1.1, 0.25), Vector3(0, 0.85, 0), Color("#8a8a9a"), false)
			tomb.name = "Tomb"
		"S":
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.45
			sm.height = 0.9
			sm.material = WorldKit.mat(Color.WHITE, 0.9)
			mi.mesh = sm
			mi.position = Vector3(0, 0.75, 0)
			mi.name = "Snowball"
			n.add_child(mi)
		"G":
			var g := WorldKit.cylinder(n, 0.6, 0.15, Vector3(0, 0.6, 0), Color("#d9a441"), false)
			g.rotation.x = PI * 0.5
			g.name = "Gear"
		"M":
			WorldKit.cylinder(n, 0.08, 0.4, Vector3(0, 0.5, 0), Color("#e8e0d0"), false)
			var cap := MeshInstance3D.new()
			var cs := SphereMesh.new()
			cs.radius = 0.45
			cs.height = 0.5
			var m := WorldKit.mat(Color("#5fffe0"), 0.4, 2.0)
			cs.material = m
			cap.mesh = cs
			cap.position = Vector3(0, 0.8, 0)
			n.add_child(cap)
		"D":
			for sd in [-1.0, 1.0]:
				var b := WorldKit.box(n, Vector3(0.1, 0.8, 0.05), Vector3(sd * 0.15, 0.85, 0), Color("#e8eef8"), false)
				b.rotation.z = sd * 0.6
		"L":
			WorldKit.cylinder(n, 0.06, 2.4, Vector3(0, 1.4, 0), Color("#ffffff"), false)
			var ch := MeshInstance3D.new()
			var chs := SphereMesh.new()
			chs.radius = 0.4
			chs.height = 0.8
			chs.material = WorldKit.mat(Color("#e0203a"), 0.15)
			ch.mesh = chs
			ch.position = Vector3(0, 2.7, 0)
			n.add_child(ch)
		"P":
			WorldKit.box(n, Vector3(1.6, 0.1, 0.7), Vector3(0, 0.33, 0), Color("#7a4a32"), false)
		"U":
			var sw2 := FX.emitter({"amount": 10, "life": 1.2, "one_shot": false, "explosive": 0.0, "spread": 10.0, "vel_min": 2.0, "vel_max": 3.0,
				"gravity": Vector3.ZERO, "size": 0.18, "color": Color(1, 1, 1, 0.8), "box": Vector3(0.6, 0.1, 0.6)})
			sw2.position = Vector3(0, 0.3, 0)
			n.add_child(sw2)
			sw2.emitting = true


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, 1.5)
	c.offset = Vector3(0, 15.5, 19.5)
	c.min_dist = 1.0
	c.max_dist = 1.0
	c.follow = false


func _build_hud() -> void:
	super._build_hud()
	var root := UI.center_root(hud)
	var name_l := UI.label("%s" % def.get("name", "Boss"), 30, Color.WHITE, true, 8)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(name_l)
	UI.place(name_l, Control.PRESET_CENTER_TOP, Vector2(-300, 80), Vector2(600, 40))
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.05, 0.15, 0.8)
	root.add_child(bg)
	UI.place(bg, Control.PRESET_CENTER_TOP, Vector2(-260, 122), Vector2(520, 22))
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color("#ff4d6d")
	bg.add_child(_hp_fill)
	_hp_fill.position = Vector2(3, 3)
	_hp_fill.size = Vector2(514, 16)
	_hp_label = UI.label("", 18, Color.WHITE, true, 5)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_hp_label)
	UI.place(_hp_label, Control.PRESET_CENTER_TOP, Vector2(-260, 146), Vector2(520, 26))
	_say_label = UI.label("", 40, UI.GOLD, true, 12)
	_say_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_say_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_say_label)
	UI.place(_say_label, Control.PRESET_CENTER_BOTTOM, Vector2(-520, -200), Vector2(1040, 110))


func on_start() -> void:
	for i in 4:
		var av := avatars[i] as PartyAvatar
		av.can_move = false
		av.can_jump = false
		av.can_shove = false
		av.set_physics_process(false)
		if active[i]:
			av.position = _slot_pos(i, fpos[i])
			av.rig.face_now(-_field_pos(fpos[i]))
	for c in get_children():
		if c is WorldEnvironment and (c as WorldEnvironment).environment:
			var e := (c as WorldEnvironment).environment
			e.fog_density *= 0.35   # Arena klar lesbar halten
	for c in world.get_children():
		if c is DirectionalLight3D:
			_sun = c
	if _sun == null:
		for c2 in get_children():
			if c2 is DirectionalLight3D:
				_sun = c2
	_refresh_hp()
	if _is_host_model_client():
		return
	_battle()


func _slot_pos(slot: int, field: int) -> Vector3:
	var off: Vector3 = [Vector3(-0.45, 0, -0.3), Vector3(0.45, 0, -0.3), Vector3(-0.45, 0, 0.35), Vector3(0.45, 0, 0.35)][slot]
	var y := 0.6
	if String(fields[field].type) == "H" if not fields.is_empty() else false:
		y = 1.0
	return _field_pos(field) + off + Vector3(0, y, 0)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _say(text: String, hold := 1.2) -> void:
	_say_text = text
	if _say_label:
		_say_label.text = text
		Juice.ui_punch(_say_label, 0.12, 0.3)
	await _wait(hold)


# --- Ablauf (Host) ----------------------------------------------------------------------------------------------

func _battle() -> void:
	await _wait(0.4)
	_act("roar")
	await _say("%s!" % def.name, 1.6)
	await _say(String(def.unique), 2.4)
	while round_n < MAX_ROUNDS and not defeated:
		round_n += 1
		await _round_start()
		await _roll_phase()
		for p in active_slots():
			if defeated:
				break
			await _move_player(p)
		if defeated:
			break
		await _boss_turn()
		_round_end()
	await _finale()


func _round_start() -> void:
	var extra := ""
	match boss_id:
		"klabautox":
			if flood_t > 0:
				flood_t -= 1
			else:
				flood = (round_n % 4) in [2, 3]
			_set_flood(flood)
			extra = " · Flut!" if flood else " · Ebbe"
		"noxumbra":
			if night_t > 0:
				night_t -= 1
				night = true
			else:
				night = round_n % 2 == 0
			_set_night(night)
			extra = " · Nacht" if night else " · Tag"
		"marquise":
			for i in RING:
				if int(fields[i].cherry) > 0:
					fields[i].cherry = int(fields[i].cherry) - 1
					if int(fields[i].cherry) == 0:
						await _cherry_explode(i)
	_refresh_fields()
	await _say("Runde %d / %d%s" % [round_n, MAX_ROUNDS, extra], 1.0)


func _round_end() -> void:
	for f in fields:
		if int(f.block) > 0 and int(f.block) < 90:
			f.block = int(f.block) - 1
		if int(f.sheep) > 0:
			f.sheep = int(f.sheep) - 1
	if dir_t > 0:
		dir_t -= 1
		if dir_t == 0:
			move_dir = 1
	armor_t = maxi(0, armor_t - 1)
	fog_t = maxi(0, fog_t - 1)
	slide_t = maxi(0, slide_t - 1)
	_refresh_fields()


## Alle stoppen gleichzeitig ihren Würfel (A); nach 6,5 s stoppt er von selbst.
func _roll_phase() -> void:
	var who: Array[int] = []
	for p in active_slots():
		if bool(status[p].get("stun", false)):
			status[p].erase("stun")
			_float(p, "Betäubt!", Color("#c7a0ff"))
			continue
		who.append(p)
		rolling[p] = true
		rolls[p] = 0
	_say_text = "Würfelt! (A)"
	if _say_label:
		_say_label.text = _say_text
	var t0 := Time.get_ticks_msec()
	while true:
		var any := false
		for p in who:
			if not rolling[p]:
				continue
			any = true
			if InputHub.pressed(p, "a") or Time.get_ticks_msec() - t0 > 6500:
				rolling[p] = false
				rolls[p] = _roll_value(p)
				Audio.sfx("dice_hit", (avatars[p] as PartyAvatar).global_position, -4.0)
				(avatars[p] as PartyAvatar).rig.play_once("jump_full" if (avatars[p] as PartyAvatar).rig.has_clip("jump_full") else "cheer")
		if not any:
			break
		await get_tree().process_frame
	# Sporen-Wolke: zwei Würfe werden vertauscht
	if bool(get_meta("swap", false)) and who.size() >= 2:
		set_meta("swap", false)
		var a := who[0]
		var b := who[who.size() - 1]
		var tmp := rolls[a]
		rolls[a] = rolls[b]
		rolls[b] = tmp
		await _say("Sporen! %s und %s tauschen ihre Würfe!" % [_pname(a), _pname(b)], 1.2)
	await _wait(0.5)


func _roll_value(p: int) -> int:
	var v := rng.randi_range(1, 6)
	var st := status[p]
	if bool(st.get("frost", false)):
		st.erase("frost")
		v = rng.randi_range(1, 2)
	if armor_t > 0:
		v = int(ceil(v / 2.0))
	if flood and String(fields[fpos[p]].type) != "H":
		v = maxi(0, v - 2)
	if bool(st.get("minus", false)):
		st.erase("minus")
		v = -v
	return v


func _move_player(p: int) -> void:
	var av := avatars[p] as PartyAvatar
	var st := status[p]
	if bool(st.get("stuck", false)):
		st.erase("stuck")
		await _say("%s klebt fest!" % _pname(p), 0.8)
		return
	if bool(st.get("bubble", false)):
		if absi(rolls[p]) >= 4:
			st.erase("bubble")
			FX.splash(av.global_position + Vector3.UP, 1.0)
			await _say("%s platzt aus der Blase!" % _pname(p), 0.8)
		else:
			await _say("%s zappelt in der Blase …" % _pname(p), 0.8)
			return
	var steps := rolls[p]
	if steps == 0:
		await _say("%s kommt nicht vom Fleck!" % _pname(p), 0.6)
		return
	if slide_t > 0:
		steps += 2 * signi(steps)
	var sgn := move_dir * signi(steps)
	await _walk(p, absi(steps), sgn)
	await _land(p, 0)


func _walk(p: int, n: int, sgn: int) -> void:
	var av := avatars[p] as PartyAvatar
	for k in n:
		var nxt := posmod(fpos[p] + sgn, RING)
		if int(fields[nxt].block) > 0:
			FX.sparks(_field_pos(nxt) + Vector3.UP, Color(1, 0.5, 0.3), 10)
			_float(p, "Versperrt!", Color("#ff8a5c"))
			break
		if int(fields[nxt].sheep) > 0:
			_float(p, "Määh! Zurück!", Color.WHITE)
			Audio.sfx("boing", av.global_position, -6.0)
			await _knockback(p, 2)
			return
		fpos[p] = nxt
		var to := _slot_pos(p, nxt)
		av.rig.face_now(to - av.position)
		var tw := av.create_tween()
		tw.tween_property(av, "position", to + Vector3(0, 0.7, 0), 0.1).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(av, "position", to, 0.1).set_trans(Tween.TRANS_QUAD)
		Audio.sfx("hop_marimba", null, -10.0, 1.0 + k * 0.05)
		await tw.finished
	av.rig.face_now(-_field_pos(fpos[p]))


func _land(p: int, depth: int) -> void:
	var f: Dictionary = fields[fpos[p]]
	var av := avatars[p] as PartyAvatar
	if int(f.coins) > 0:
		_coins(p, int(f.coins))
		f.coins = 0
		_refresh_fields()
	match String(f.type):
		"A":
			if boss_id == "noxumbra" and night:
				await _say("Im Schatten unsichtbar! Nur Leuchtpilze helfen.", 0.9)
			else:
				await _attack(p, 1.0)
		"C":
			_coins(p, 2)
			await _wait(0.4)
		"R":
			f.crack = int(f.crack) + 1
			if int(f.crack) >= 2:
				f.block = 99
				_refresh_fields()
				FX.explosion(_field_pos(fpos[p]), 0.8)
				await _say("Der Boden bricht ein! %s fällt zurück." % _pname(p), 0.8)
				_coins(p, -2)
				await _knockback(p, 3)
			else:
				FX.dust(_field_pos(fpos[p]) + Vector3.UP * 0.3, Color(0.5, 0.35, 0.3), 12, 1.0)
				_float(p, "Knacks …", Color("#ffb38a"))
				_refresh_fields()
		"K":
			await _say("Wolkenkanone! Rückenangriff!", 0.6)
			var tw := av.create_tween()
			tw.tween_property(av, "position", Vector3(0, 9.0, -6.0), 0.5).set_trans(Tween.TRANS_QUAD)
			tw.tween_property(av, "position", _slot_pos(p, fpos[p]), 0.6).set_trans(Tween.TRANS_BOUNCE)
			await get_tree().create_timer(0.5).timeout
			await _attack(p, 2.0, false)
		"T":
			if not bool(f.broken):
				f.broken = true
				scores[p] += 1
				_refresh_fields()
				FX.smoke(_field_pos(fpos[p]) + Vector3.UP, Color(0.6, 0.6, 0.7), 16, 1.2)
				Audio.sfx("stone_hit", null, -2.0)
				var left := _tombs_left()
				await _say("Grabstein zerstört!" + (" Noch %d." % left if left > 0 else " Der Graf ist verwundbar!"), 1.0)
		"S":
			if not bool(f.collected) and frost_armor:
				f.collected = true
				var got := 0
				for f2 in fields:
					if bool(f2.collected):
						got += 1
				_refresh_fields()
				Audio.sfx("plop", null, -2.0)
				if got >= 3:
					frost_armor = false
					_act("hit")
					model.hit()
					FX.explosion(model.global_position + Vector3.UP * 3.0, 1.5)
					await _say("Drei Schneebälle – die Frost-Rüstung zerspringt!", 1.4)
				else:
					await _say("Schneeball gesammelt (%d/3)" % got, 0.8)
		"G":
			if not bool(f.synced):
				f.synced = true
				var sy := 0
				for f3 in fields:
					if bool(f3.synced):
						sy += 1
				_refresh_fields()
				Audio.sfx("wheel_tick", null, -2.0)
				if sy >= 3:
					overclock_t = 1
					for f4 in fields:
						f4.synced = false
					_refresh_fields()
					await _say("Alle Uhrwerke synchron – Galaxus gerät aus dem Takt! Doppelter Schaden!", 1.5)
				else:
					await _say("Uhrwerk synchronisiert (%d/3)" % sy, 0.8)
		"M":
			if night or boss_id != "noxumbra":
				await _say("Pilzlicht enthüllt die Schattenwurzel!", 0.7)
				await _attack(p, 1.5)
			else:
				_coins(p, 1)
		"D":
			await _duel(p)
		"L":
			await _say("Kirsch-Lift! Bombardement von oben!", 0.6)
			var tw2 := av.create_tween()
			tw2.tween_property(av, "position:y", 5.0, 0.5).set_trans(Tween.TRANS_QUAD)
			tw2.tween_property(av, "position:y", _slot_pos(p, fpos[p]).y, 0.5).set_trans(Tween.TRANS_BOUNCE)
			await get_tree().create_timer(0.5).timeout
			await _attack(p, 2.0, false)
		"P":
			if depth == 0 and not bool(status[p].get("caramel", false)):
				await _say("Schoko-Rutsche!", 0.5)
				await _walk(p, 3, move_dir)
				await _land(p, 1)
			elif bool(status[p].get("caramel", false)):
				status[p].erase("caramel")
				await _say("Karamell! %s klebt auf der Rutsche fest." % _pname(p), 0.8)
		"U":
			await _say("Aufwind! Höhenbonus ×2", 0.6)
			var tw3 := av.create_tween()
			tw3.tween_property(av, "position:y", 4.5, 0.45).set_trans(Tween.TRANS_QUAD)
			tw3.tween_property(av, "position:y", _slot_pos(p, fpos[p]).y, 0.45).set_trans(Tween.TRANS_BOUNCE)
			await get_tree().create_timer(0.45).timeout
			await _attack(p, 2.0, false)
			if depth == 0:
				await _walk(p, 2, move_dir)


func _tombs_left() -> int:
	var n := 0
	for f in fields:
		if String(f.type) == "T" and not bool(f.broken):
			n += 1
	return n


func _attack(p: int, mult: float, leap := true) -> void:
	var av := avatars[p] as PartyAvatar
	if boss_id == "grabstein" and _tombs_left() > 0:
		_act("cast")
		await _say("Unverwundbar! Erst die Grabsteine zerstören (%d übrig)." % _tombs_left(), 1.0)
		return
	var base := 2.0 + floorf(absi(rolls[p]) / 2.0)
	var dmg := base * mult
	if boss_id == "frostbart" and frost_armor:
		dmg = ceilf(dmg / 2.0)
	if overclock_t > 0:
		dmg *= 2.0
	dmg = minf(dmg, hp)
	if leap:
		var from := av.position
		var tgt := model.global_position + (from - model.global_position).normalized() * 3.2 + Vector3(0, 1.5, 0)
		av.rig.play_once("punch" if av.rig.has_clip("punch") else "throw")
		var tw := av.create_tween()
		tw.tween_property(av, "position", tgt, 0.22).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(av, "position", from, 0.3).set_trans(Tween.TRANS_BACK)
		await get_tree().create_timer(0.22).timeout
	hp -= dmg
	scores[p] += dmg
	model.hit()
	_act_seq += 1
	_act_kind = "hit"
	FX.sparks(model.global_position + Vector3(0, 3.0, 2.0), Game.player_color(p), 26)
	FX.stars(model.global_position + Vector3(0, 4.0, 1.5), UI.GOLD, 10)
	Audio.sfx("punch", null, 0.0, 0.9)
	Juice.float_text(self, model.global_position + Vector3(randf_range(-1.5, 1.5), 5.5, 2.0), "-%d" % int(dmg), Game.player_color(p).lightened(0.3), 110)
	if armor_t > 0:
		_coins(p, 2)
		_float(p, "Schatz-Münzen!", UI.GOLD)
	_refresh_hp()
	await _wait(0.5)
	if hp <= 0.0:
		defeated = true
		scores[p] += 5.0
		await _say("%s landet den finalen Treffer! +5" % _pname(p), 1.2)
		return
	var np := 1 if hp > max_hp * 0.66 else (2 if hp > max_hp * 0.33 else 3)
	if np > bphase:
		bphase = np
		model.set_rage(bphase - 1)
		_act_seq += 1
		_act_kind = "rage%d" % bphase
		await _say(("Phase %d! %s wird wütend!" % [bphase, def.name]) if bphase == 2 else ("WUT-PHASE! %s greift doppelt an!" % def.name), 1.5)


func _duel(p: int) -> void:
	var best := -1
	var bd := 999
	for q in active_slots():
		if q == p:
			continue
		var d := absi(posmod(fpos[q] - fpos[p] + RING / 2, RING) - RING / 2)
		if d < bd:
			bd = d
			best = q
	if best < 0:
		return
	var a := rng.randi_range(1, 6)
	var b := rng.randi_range(1, 6)
	while a == b:
		b = rng.randi_range(1, 6)
	await _say("Mini-Duell! %s (%d) gegen %s (%d)" % [_pname(p), a, _pname(best), b], 1.2)
	var w := p if a > b else best
	scores[w] += 3
	(avatars[w] as PartyAvatar).rig.react("cheer")
	_float(w, "+3 Duell-Sieg", UI.GOLD)


# --- Bossrunde --------------------------------------------------------------------------------------------------

func _boss_turn() -> void:
	if overclock_t > 0:
		overclock_t -= 1
		_act("timejump")
		await _say("%s taumelt aus dem Takt und setzt aus!" % def.name, 1.2)
		return
	var abil: Array = def.abilities
	var avail := 2 if bphase == 1 else 3
	var count := 2 if bphase >= 3 else 1
	for k in count:
		var pick: Array = abil[rng.randi() % avail]
		var guard := 0
		while String(pick[0]) == _last_ability and guard < 6:
			pick = abil[rng.randi() % avail]
			guard += 1
		_last_ability = String(pick[0])
		await _say("%s: %s!" % [def.name, pick[1]], 0.9)
		_act(_anim_for(String(pick[0])))
		await _wait(0.45)
		await _ability(String(pick[0]))
		_refresh_fields()
		await _wait(0.5)


func _anim_for(ab: String) -> String:
	return {"lava": "breath", "tail": "tail", "armor": "curl", "tsunami": "wave", "bubble": "breath", "claw": "pinch",
		"comet": "comet", "cannonade": "gust", "gravity": "gravity", "soulsteal": "steal", "taxi": "spin", "fog": "breath",
		"iceslide": "spin", "avalanche": "stomp", "frostbreath": "frost", "timejump": "timejump", "rockets": "roar", "nova": "slam",
		"darkness": "roar", "roots": "slam", "spores": "breath", "ramstorm": "ram", "sheepflood": "roar", "dandelion": "gust",
		"caramel": "breath", "candleflame": "flame", "cherrybomb": "lunge", "gust": "gust", "whirl": "spin", "seedstorm": "storm"}.get(ab, "roar")


func _random_players(n: int) -> Array[int]:
	var act := active_slots()
	var out: Array[int] = []
	var pool := act.duplicate()
	for k in mini(n, pool.size()):
		var i := rng.randi() % pool.size()
		out.append(pool[i])
		pool.remove_at(i)
	return out


func _players_on(idx: Array) -> Array[int]:
	var out: Array[int] = []
	for p in active_slots():
		if fpos[p] in idx:
			out.append(p)
	return out


func _random_fields(n: int, free := true) -> Array:
	var out: Array = []
	var guard := 0
	while out.size() < n and guard < 200:
		guard += 1
		var i := rng.randi() % RING
		if i in out or (free and int(fields[i].block) > 0):
			continue
		out.append(i)
	return out


## Bogen von n Feldern, die dem Boss gegenüber liegen (Front zur Kamera = +Z, oder um einen Spieler herum).
func _arc_around(center: int, n: int) -> Array:
	var out: Array = []
	for k in n:
		out.append(posmod(center - n / 2 + k, RING))
	return out


func _ability(ab: String) -> void:
	match ab:
		# Ignis
		"lava":
			var fs := _random_fields(3)
			for i in fs:
				fields[i].block = 2
				FX.embers(_field_pos(i) + Vector3.UP * 0.5, 20)
				FX.smoke(_field_pos(i) + Vector3.UP, Color(1, 0.45, 0.15), 12, 1.2)
			_refresh_fields()
			for p in _players_on(fs):
				_coins(p, -2)
				await _knockback(p, 2)
			await _say("Drei Felder glühen – zwei Runden lang gesperrt!", 1.0)
		"tail":
			var c := fpos[_random_players(1)[0]]
			var arc := _arc_around(c, 5)
			for i in arc:
				FX.shockwave(_field_pos(i), 2.5, Color(1, 0.6, 0.3, 0.8))
			for p in _players_on(arc):
				_coins(p, -1)
				await _knockback(p, 3)
		"armor":
			armor_t = 2
			await _say("Panzerung! Würfe halbiert – doch Treffer lassen Schatz-Münzen fallen.", 1.4)
		# Klabautox
		"tsunami":
			flood = true
			flood_t = 2
			_set_flood(true)
			for p in active_slots():
				if String(fields[fpos[p]].type) != "H":
					await _knockback(p, 1)
			await _say("Flut! Wer nicht auf einer Sandbank steht, verliert 2 Würfelaugen.", 1.4)
		"bubble":
			for p in _random_players(2):
				status[p]["bubble"] = true
				FX.bubbles((avatars[p] as PartyAvatar).global_position + Vector3.UP, 12)
				_float(p, "Blasen-Gefängnis!", Color("#9fe8ff"))
			await _say("Nur wer 4 oder mehr würfelt, kommt frei!", 1.2)
		"claw":
			var best := active_slots()[0]
			for p in active_slots():
				if _items(p) > _items(best):
					best = p
			var n := _items(best)
			if n > 0:
				item_steal[best] += int(ceil(n / 2.0))
				await _say("Die Zange schnappt %d Item(s) von %s!" % [int(ceil(n / 2.0)), _pname(best)], 1.2)
			else:
				_coins(best, -3)
				await _say("Keine Items – die Zange schnappt 3 Münzen von %s!" % _pname(best), 1.2)
		# Astraios
		"comet":
			var fs2 := _random_fields(4, false)
			for i in fs2:
				FX.explosion(_field_pos(i) + Vector3.UP * 0.3, 0.6)
			for p in _players_on(fs2):
				status[p]["stun"] = true
				FX.dizzy_stars(avatars[p] as Node3D, 2.4, 2.0)
				_float(p, "Betäubt!", Color("#c7a0ff"))
			await _wait(0.6)
		"cannonade":
			for p in active_slots():
				await _knockback(p, 2)
		"gravity":
			move_dir = -move_dir
			dir_t = 2
			await _say("Die Laufrichtung kehrt sich um!", 1.0)
		# Graf Grabstein
		"soulsteal":
			for p in _random_players(2):
				status[p]["minus"] = true
				_float(p, "Seele gestohlen!", Color("#c7a0ff"))
			await _say("Der nächste Wurf zählt rückwärts!", 1.0)
		"taxi":
			var p2 := _random_players(1)[0]
			var to := rng.randi() % RING
			FX.smoke((avatars[p2] as PartyAvatar).global_position, Color(0.7, 1.0, 0.9), 16, 1.2)
			fpos[p2] = to
			(avatars[p2] as PartyAvatar).position = _slot_pos(p2, to)
			FX.smoke((avatars[p2] as PartyAvatar).global_position, Color(0.7, 1.0, 0.9), 16, 1.2)
			await _say("Geister-Taxi! %s landet woanders." % _pname(p2), 1.0)
		"fog":
			fog_t = 2
			await _say("Nebelwand – eure Würfel sind nicht mehr zu sehen!", 1.0)
		# Frostbart
		"iceslide":
			slide_t = 2
			await _say("Eisrutschen! Alle schlittern 2 Felder weiter.", 1.0)
		"avalanche":
			var fs3 := _random_fields(2)
			for i in fs3:
				fields[i].block = 2
				FX.smoke(_field_pos(i) + Vector3.UP * 2.0, Color(0.95, 0.98, 1.0), 16, 1.4)
			for p in _players_on(fs3):
				await _knockback(p, 2)
			await _say("Eiszapfen versperren den Weg!", 0.9)
		"frostbreath":
			for p in _random_players(2):
				status[p]["frost"] = true
				FX.smoke((avatars[p] as PartyAvatar).global_position + Vector3.UP, Color(0.75, 0.95, 1.0), 12, 1.0)
				_float(p, "Eingefroren: nur 1–2!", Color("#9fe8ff"))
			await _wait(0.6)
		# Galaxus
		"timejump":
			var undone := false
			for f in fields:
				if bool(f.synced):
					f.synced = false
					undone = true
					break
			if undone:
				await _say("Zeitsprung! Ein Uhrwerk springt zurück.", 1.0)
			else:
				var lead := active_slots()[0]
				for p in active_slots():
					if scores[p] > scores[lead]:
						lead = p
				await _knockback(lead, 3)
		"rockets":
			for p in _random_players(3):
				var a := (avatars[p] as PartyAvatar).global_position
				FX.explosion(a + Vector3.UP * 0.5, 0.6)
				_coins(p, -2)
				await _knockback(p, 1)
		"nova":
			FX.shockwave(model.global_position, 14.0, Color(0.8, 0.85, 1.0, 0.9))
			for p in active_slots():
				if fpos[p] % 2 == 1:
					status[p]["stun"] = true
					_float(p, "Supernova – betäubt!", Color("#c7a0ff"))
			await _wait(0.8)
		# Noxumbra
		"darkness":
			night = true
			night_t = 2
			_set_night(true)
			await _say("Ewige Finsternis bricht herein!", 1.0)
		"roots":
			for p in _random_players(2):
				status[p]["stuck"] = true
				FX.dust((avatars[p] as PartyAvatar).global_position, Color(0.35, 0.25, 0.15), 14, 1.2)
				_float(p, "Wurzel-Schlinge!", Color("#9fe07a"))
			await _wait(0.6)
		"spores":
			set_meta("swap", true)
			FX.smoke(model.global_position + Vector3.UP * 3.0, Color(0.8, 0.6, 1.0), 30, 3.0)
			await _say("Sporen-Wolke! Die nächsten Würfe geraten durcheinander.", 1.0)
		# Baaah-hemoth
		"ramstorm":
			var c2 := fpos[_random_players(1)[0]]
			var arc2 := _arc_around(c2, 6)
			for i in arc2:
				FX.dust(_field_pos(i) + Vector3.UP * 0.3, Color(0.8, 0.9, 0.6), 10, 1.0)
			for p in _players_on(arc2):
				_coins(p, -1)
				(avatars[p] as PartyAvatar).rig.react("launch")
				await _knockback(p, 3)
		"sheepflood":
			for i in _random_fields(5):
				fields[i].sheep = 1
			await _say("Schäfchen-Flut! Wer auf ein Schaf hüpft, prallt zurück.", 1.2)
		"dandelion", "seedstorm":
			for p in active_slots():
				var to2 := rng.randi() % RING
				fpos[p] = to2
				var av := avatars[p] as PartyAvatar
				var tw := av.create_tween()
				tw.tween_property(av, "position", _slot_pos(p, to2) + Vector3(0, 4.0, 0), 0.4)
				tw.tween_property(av, "position", _slot_pos(p, to2), 0.4).set_trans(Tween.TRANS_BOUNCE)
			FX.confetti(model.global_position + Vector3.UP * 4.0, 50)
			await _wait(1.0)
		# Marzipan-Marquise
		"caramel":
			for p in _random_players(2):
				status[p]["stuck"] = true
				status[p]["caramel"] = true
				FX.slime((avatars[p] as PartyAvatar).global_position, 1.0)
				_float(p, "Karamell-Kleister!", Color("#e8a23a"))
			await _wait(0.6)
		"candleflame":
			var c3 := fpos[_random_players(1)[0]]
			var arc3 := _arc_around(c3, 4)
			for i in arc3:
				FX.embers(_field_pos(i) + Vector3.UP * 0.5, 16)
			for p in _players_on(arc3):
				_coins(p, -3)
				await _knockback(p, 2)
		"cherrybomb":
			var fi := _random_fields(1)[0] as int
			fields[fi].cherry = 3
			await _say("Eine Kirsch-Bombe! Sie explodiert in 3 Runden.", 1.2)
		# Zephyros
		"gust":
			for p in active_slots():
				await _knockback(p, 3)
		"whirl":
			for p in _random_players(2):
				await _walk(p, rng.randi_range(2, 4), move_dir)
			await _wait(0.4)


func _cherry_explode(i: int) -> void:
	FX.explosion(_field_pos(i) + Vector3.UP * 0.5, 1.2)
	for k in [-2, -1, 1, 2]:
		fields[posmod(i + k, RING)].coins = int(fields[posmod(i + k, RING)].coins) + 2
	var near: Array = [posmod(i - 1, RING), i, posmod(i + 1, RING)]
	for p in _players_on(near):
		await _knockback(p, 2)
	_refresh_fields()
	await _say("BUMM! Die Kirsch-Bombe verstreut Münzen!", 1.0)


func _knockback(p: int, n: int) -> void:
	var av := avatars[p] as PartyAvatar
	av.rig.react("hit")
	for k in n:
		var nxt := posmod(fpos[p] - move_dir, RING)
		if int(fields[nxt].block) > 0:
			break
		fpos[p] = nxt
	var tw := av.create_tween()
	tw.tween_property(av, "position", _slot_pos(p, fpos[p]) + Vector3(0, 1.2, 0), 0.18)
	tw.tween_property(av, "position", _slot_pos(p, fpos[p]), 0.18).set_trans(Tween.TRANS_BOUNCE)
	await tw.finished


func _finale() -> void:
	_say_text = ""
	if defeated:
		_act("defeat")
		model.defeat()
		Audio.jingle("fanfare")
		for p in active_slots():
			(avatars[p] as PartyAvatar).rig.react("victory")
		FX.confetti(Vector3(0, 6, 0), 120)
		await _say("%s ist besiegt!" % def.name, 3.0)
	else:
		_act("roar")
		await _say("%s entkommt lachend … nächstes Mal!" % def.name, 2.6)
		var tw := model.create_tween()
		tw.tween_property(model, "position:y", 14.0, 1.2).set_trans(Tween.TRANS_BACK)
		await _wait(1.2)
	end_game()


func check_end() -> bool:
	return false


func result_extra() -> Dictionary:
	return {"boss": boss_id, "boss_defeated": defeated, "coin_delta": coin_delta.duplicate(), "item_steal": item_steal.duplicate()}


# --- Hilfen & Darstellung --------------------------------------------------------------------------------------

func _act(kind: String) -> void:
	_act_seq += 1
	_act_kind = kind
	if model and kind != "hit" and kind != "defeat" and not kind.begins_with("rage"):
		model.act(kind)


func _items(p: int) -> int:
	return (Game.players[p].get("items", []) as Array).size() - item_steal[p] if Game.mode == "party" else 0


func _coins(p: int, n: int) -> void:
	coin_delta[p] += n
	var av := avatars[p] as PartyAvatar
	FX.coins_burst(av.global_position + Vector3.UP * 1.5, absi(n), n > 0)
	_float(p, ("+%d" % n) if n > 0 else ("%d" % n), UI.GOLD if n > 0 else Color("#ff8a8a"))
	Audio.sfx("coin" if n > 0 else "coin_lose", av.global_position, -4.0)


func _float(p: int, text: String, col: Color) -> void:
	Juice.float_text(self, (avatars[p] as PartyAvatar).global_position + Vector3.UP * 2.6, text, col, 70)


func _pname(p: int) -> String:
	return String(Game.hero(Game.players[p].hero).name).split(" ")[0]


func _set_flood(on: bool) -> void:
	if _water:
		_water.create_tween().tween_property(_water, "position:y", 0.12 if on else -0.4, 0.8)


func _set_night(on: bool) -> void:
	if model:
		model.set_shadow(on)
	if _sun:
		_sun.create_tween().tween_property(_sun, "light_energy", 0.25 if on else 1.0, 0.8)


func _refresh_hp() -> void:
	if _hp_fill:
		_hp_fill.size.x = 514.0 * clampf(hp / max_hp, 0.0, 1.0)
		_hp_fill.color = Color("#ff4d6d") if bphase < 3 else Color("#ff2a2a")
	if _hp_label:
		var tag := ""
		if boss_id == "frostbart" and frost_armor:
			tag = " · Frost-Rüstung"
		elif boss_id == "grabstein" and _tombs_left() > 0:
			tag = " · Unverwundbar (%d Grabsteine)" % _tombs_left()
		_hp_label.text = "%d / %d · Phase %d%s" % [int(ceil(hp)), int(max_hp), bphase, tag]


func _refresh_fields() -> void:
	for i in fields.size():
		var f: Dictionary = fields[i]
		var n: Node3D = f.node
		var tile := n.get_node_or_null("Tile") as Node3D
		if tile:
			tile.visible = int(f.block) < 90
		# Sperre (Lava / Eiszapfen / allgemein)
		var blk := n.get_node_or_null("Block") as Node3D
		if int(f.block) > 0 and int(f.block) < 90 and blk == null:
			blk = Node3D.new()
			blk.name = "Block"
			n.add_child(blk)
			if boss_id == "frostbart":
				for k in 3:
					WorldKit.cylinder(blk, 0.0, 0.25, Vector3((k - 1) * 0.35, 0.9, 0), Color("#bfefff"), false).rotation.x = PI
			else:
				var lava := WorldKit.cylinder(blk, 1.05, 0.1, Vector3(0, 0.33, 0), Color("#ff7a1a") if boss_id == "ignis" else Color("#8a5aaa"), false)
				lava.name = "Lava"
		elif (int(f.block) == 0 or int(f.block) >= 90) and blk:
			blk.queue_free()
		# Schafe
		var sh := n.get_node_or_null("Sheep") as Node3D
		if int(f.sheep) > 0 and sh == null:
			sh = Node3D.new()
			sh.name = "Sheep"
			n.add_child(sh)
			var sm := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.45
			s.height = 0.8
			s.material = WorldKit.mat(Color.WHITE, 1.0)
			sm.mesh = s
			sm.position = Vector3(0, 0.75, 0)
			sh.add_child(sm)
			WorldKit.box(sh, Vector3(0.25, 0.25, 0.3), Vector3(0, 0.85, 0.42), Color("#3a3040"), false)
		elif int(f.sheep) == 0 and sh:
			sh.queue_free()
		# Kirsch-Bombe
		var cb := n.get_node_or_null("Cherry") as Node3D
		if int(f.cherry) > 0:
			if cb == null:
				cb = Node3D.new()
				cb.name = "Cherry"
				n.add_child(cb)
				var cm := MeshInstance3D.new()
				var cs := SphereMesh.new()
				cs.radius = 0.5
				cs.height = 1.0
				cs.material = WorldKit.mat(Color("#e0203a"), 0.15, 0.2)
				cm.mesh = cs
				cm.position = Vector3(0, 0.9, 0)
				cb.add_child(cm)
				var lb := Label3D.new()
				lb.name = "Count"
				lb.font_size = 64
				lb.outline_size = 12
				lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				lb.position = Vector3(0, 1.8, 0)
				cb.add_child(lb)
			(cb.get_node("Count") as Label3D).text = str(int(f.cherry))
		elif cb:
			cb.queue_free()
		# Münzen auf dem Feld
		var cn := n.get_node_or_null("Coins") as Node3D
		if int(f.coins) > 0 and cn == null:
			cn = Node3D.new()
			cn.name = "Coins"
			n.add_child(cn)
			for k in 3:
				var c := WorldKit.cylinder(cn, 0.22, 0.06, Vector3((k - 1) * 0.3, 0.4 + k * 0.05, 0.3), Color("#ffd23f"), false)
				c.rotation.x = PI * 0.4
		elif int(f.coins) == 0 and cn:
			cn.queue_free()
		# Zustände der Spezialfelder
		var tomb := n.get_node_or_null("Tomb") as Node3D
		if tomb:
			tomb.rotation.x = -PI * 0.45 if bool(f.broken) else 0.0
			tomb.position.y = 0.4 if bool(f.broken) else 0.85
		var snow := n.get_node_or_null("Snowball") as Node3D
		if snow:
			snow.visible = not bool(f.collected)
		var gear := n.get_node_or_null("Gear") as Node3D
		if gear:
			gear.scale = Vector3.ONE * (1.35 if bool(f.synced) else 1.0)
		if int(f.crack) == 1 and n.get_node_or_null("Crack2") == null:
			var c2 := WorldKit.box(n, Vector3(1.4, 0.03, 0.12), Vector3(0, 0.3, 0), Color("#1a0d0a"), false)
			c2.name = "Crack2"
	_refresh_hp()


func _process(delta: float) -> void:
	super._process(delta)
	if fields.is_empty():
		return
	for i in 4:
		var d := _dice[i]
		var show := active[i] and (rolling[i] or (rolls[i] != 0 and _say_text.begins_with("Würfelt")))
		d.visible = show
		if not show:
			continue
		var av := avatars[i] as PartyAvatar
		d.position = av.global_position + Vector3(0, 2.8, 0)
		if rolling[i]:
			d.rotation += Vector3(0.11, 0.17, 0.07)
			_dice_labels[i].text = str(1 + (Time.get_ticks_msec() / 70 + i) % 6)
		else:
			d.rotation = d.rotation.lerp(Vector3.ZERO, 0.3)
			_dice_labels[i].text = "?" if fog_t > 0 else str(rolls[i])


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	d["fp"] = fpos.duplicate()
	d["rl"] = rolls.duplicate()
	d["ro"] = rolling.duplicate()
	d["hp"] = snappedf(hp, 0.1)
	d["bp"] = bphase
	d["ni"] = night
	d["fl"] = flood
	d["fo"] = fog_t
	d["sy"] = _say_text
	d["as"] = _act_seq
	d["ak"] = _act_kind
	d["df"] = defeated
	d["fa"] = frost_armor
	d["f"] = fields.map(func(f: Dictionary) -> Array:
		return [int(f.block), int(f.crack), int(f.sheep), int(f.cherry), int(f.coins), 1 if bool(f.broken) else 0, 1 if bool(f.synced) else 0, 1 if bool(f.collected) else 0])
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var fp: Array = d.get("fp", fpos)
	var rl: Array = d.get("rl", rolls)
	var ro: Array = d.get("ro", rolling)
	for i in 4:
		fpos[i] = int(fp[i])
		rolls[i] = int(rl[i])
		rolling[i] = bool(ro[i])
	var new_hp := float(d.get("hp", hp))
	if new_hp < hp - 0.01 and model:
		model.hit()
	hp = new_hp
	var nb := int(d.get("bp", bphase))
	if nb > bphase and model:
		model.set_rage(nb - 1)
	bphase = nb
	var ni := bool(d.get("ni", night))
	if ni != night:
		_set_night(ni)
	night = ni
	var fl := bool(d.get("fl", flood))
	if fl != flood:
		_set_flood(fl)
	flood = fl
	fog_t = int(d.get("fo", fog_t))
	frost_armor = bool(d.get("fa", frost_armor))
	var sy := String(d.get("sy", ""))
	if sy != _say_text:
		_say_text = sy
		if _say_label:
			_say_label.text = sy
	var aseq := int(d.get("as", _act_seq))
	if aseq != _act_seq:
		_act_seq = aseq
		var k := String(d.get("ak", ""))
		if model and k != "" and k != "hit" and not k.begins_with("rage"):
			if k == "defeat":
				model.defeat()
			else:
				model.act(k)
	defeated = bool(d.get("df", defeated))
	var fs: Array = d.get("f", [])
	for i in mini(fs.size(), fields.size()):
		var e: Array = fs[i]
		var f: Dictionary = fields[i]
		f.block = int(e[0])
		f.crack = int(e[1])
		f.sheep = int(e[2])
		f.cherry = int(e[3])
		f.coins = int(e[4])
		f.broken = int(e[5]) == 1
		f.synced = int(e[6]) == 1
		f.collected = int(e[7]) == 1
	_refresh_fields()


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var held := {}
	if rolling[slot]:
		var mem := cpu_mem[slot]
		if not mem.has("t"):
			mem["t"] = Time.get_ticks_msec() + randi_range(500, 1800)
		if Time.get_ticks_msec() > int(mem.t):
			held["a"] = true
			mem.erase("t")
	InputHub.set_virtual(slot, Vector2.ZERO, held)
