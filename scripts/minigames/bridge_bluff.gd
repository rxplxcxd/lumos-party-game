extends MinigameBase
## Blockpfad-Poker: Fünf Runden Nervenspiel. Vor dem Abgrund liegen vier Brückenfelder mit Punktwerten.
## Bis der Countdown abläuft, stellt sich jeder auf ein Feld – man sieht, wohin die anderen laufen, und kann
## blitzschnell umschwenken (Bluff!). Wer ALLEIN auf seinem Feld steht, kassiert dessen Punkte; teilen sich
## mehrere ein Feld, kracht es unter ihnen weg. Wer auf keinem Feld steht, geht leer aus.
## Online: Host-Modell (Host wertet die Positionen aus).

const PAD_X := [-4.5, -1.5, 1.5, 4.5]
const PAD_W := 2.8
const T_CHOOSE := 4.5
const T_REVEAL := 2.6
const ROUNDS := 5
const RL := T_CHOOSE + T_REVEAL

var _pads: Array[Dictionary] = []    # {body, cs, mesh, label, x}
var _vals: Array[int] = [1, 1, 2, 3]
var _round := -1
var _phase := ""
var _result: Array = []              # je Feld: [Anzahl, Gewinner-Slot oder -1]
var _count_lbl: Label3D
var _last_secs := -1


func _init() -> void:
	game_id = "bridge_bluff"
	env_preset = "sunset"
	backdrop_style = "sky_dusk"
	time_limit = RL * ROUNDS + 0.3
	score_format = "%d Pkt."
	kill_y = -30.0
	arena_radius = 8.0
	teaser_height = 1.0
	cannon_pos = Vector3(8, 0, 7)
	net_model = "host"
	spawn_points = [Vector3(-3.0, 0.6, 4.5), Vector3(-1.0, 0.6, 4.5), Vector3(1.0, 0.6, 4.5), Vector3(3.0, 0.6, 4.5)]


func build_arena() -> void:
	# Startplateau, vier Brückenfelder, dahinter Hängebrücken zur Zielinsel über einer nebligen Schlucht
	WorldKit.box(world, Vector3(13.5, 1.0, 5.0), Vector3(0, -0.5, 4.0), Color("#c9a26b"))
	WorldKit.box(world, Vector3(13.5, 6.0, 5.0), Vector3(0, -4.0, 4.0), Color("#8a6a4a"), false)
	for i in 4:
		var body := StaticBody3D.new()
		world.add_child(body)
		body.position = Vector3(PAD_X[i], -0.3, 0.0)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(PAD_W, 0.6, 3.0)
		bm.material = WorldKit.mat(Color("#b9814d"), 0.8)
		mi.mesh = bm
		body.add_child(mi)
		for k in 4:
			WorldKit.box(mi, Vector3(PAD_W + 0.02, 0.62, 0.06), Vector3(0, 0, -1.2 + k * 0.8), Color("#8a5a34"), false)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(PAD_W, 0.6, 3.0)
		cs.shape = bs
		body.add_child(cs)
		var lb := Label3D.new()
		lb.font_size = 150
		lb.outline_size = 28
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.position = Vector3(PAD_X[i], 2.6, -1.0)
		world.add_child(lb)
		# Hängebrücke dahinter (Deko), Seile in Feldfarbe
		for p in 7:
			WorldKit.box(world, Vector3(PAD_W * 0.7, 0.12, 0.8), Vector3(PAD_X[i], -0.25 - sin(p / 6.0 * PI) * 0.6, -2.2 - p * 1.0), Color("#a4703f"), false)
		for s in [-1.0, 1.0]:
			WorldKit.box(world, Vector3(0.06, 0.06, 7.2), Vector3(PAD_X[i] + s * PAD_W * 0.38, 0.5, -5.2), Color("#e8d2a0"), false)
		_pads.append({"body": body, "cs": cs, "mesh": mi, "label": lb, "x": PAD_X[i]})
	WorldKit.box(world, Vector3(14, 1.0, 4.0), Vector3(0, -0.5, -11.0), Color("#7cc85a"), false)
	WorldKit.place(world, "plat/flag", Vector3(0, 0, -11.0), 0.0, 1.4)
	WorldKit.place(world, "plat/chest", Vector3(2.5, 0, -11.5), 0.0, 1.4)
	WorldKit.scatter(world, ["nat/tree_pine", "nat/rock_large", "nat/bush"], 8, Vector3(0, 0, -12.0), 4.0, 8.0, 0.0)
	# Auffangnetz unten in der Schlucht (Gestürzte warten dort auf die nächste Runde)
	WorldKit.box(world, Vector3(16, 0.4, 6), Vector3(0, -7.6, 0.0), Color("#6b5a8a"), true)
	# Nebel in der Schlucht
	var fog := WorldKit.box(world, Vector3(40, 0.2, 40), Vector3(0, -7.0, -4.0), Color("#f0d6ff"), false)
	(fog.get_child(0) as MeshInstance3D).material_override = WorldKit.mat(Color(0.95, 0.85, 1.0), 1.0, 0.4)
	_count_lbl = Label3D.new()
	_count_lbl.font_size = 220
	_count_lbl.outline_size = 36
	_count_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_count_lbl.position = Vector3(0, 4.4, -1.0)
	_count_lbl.modulate = Color("#fff1a8")
	world.add_child(_count_lbl)
	_show_vals()


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = Vector3(0, 0, 1.5)
	c.offset = Vector3(0, 10.0, 11.0)
	c.min_dist = 0.95
	c.max_dist = 1.05


func on_start() -> void:
	for av in avatars:
		(av as PartyAvatar).can_shove = false


func check_end() -> bool:
	return _round >= ROUNDS


func on_tick(_delta: float) -> void:
	var el := time_limit - time_left
	var r := int(el / RL)
	var t := el - r * RL
	if r != _round:
		_round = r
		if r >= ROUNDS:
			return
		_new_round()
	var ph := "choose" if t < T_CHOOSE else "reveal"
	if ph != _phase:
		_phase = ph
		if ph == "reveal":
			_resolve()
	if _phase == "choose":
		var secs := int(ceil(T_CHOOSE - t))
		_count_lbl.text = str(secs)
		if secs != _last_secs:
			_last_secs = secs
			Audio.sfx("tick", Vector3.ZERO, -4.0, 1.0 + (3 - secs) * 0.1)
	else:
		_count_lbl.text = ""


func _new_round() -> void:
	_result = []
	_phase = ""
	_last_secs = -1
	# Werte mischen (gemeinsamer Zufall), letzte Runde doppelt
	var vals: Array[int] = [1, 1, 2, 3]
	for k in range(3, 0, -1):
		var j := rng.randi() % (k + 1)
		var tmp := vals[k]
		vals[k] = vals[j]
		vals[j] = tmp
	if _round == ROUNDS - 1:
		for k in 4:
			vals[k] *= 2
	_vals = vals
	_reset_pads()
	_show_vals()
	CutsceneManager.big_word("Runde %d%s" % [_round + 1, " – doppelte Punkte!" if _round == ROUNDS - 1 else ""], Color("#ffffff"), 0.6)
	# Alle zurück aufs Plateau
	for i in active_slots():
		var av := avatars[i] as PartyAvatar
		if av.global_position.y < -0.5 or _round > 0:
			av.global_position = spawn_points[i]
			av.velocity = Vector3.ZERO
			FX.dust(av.global_position, Color(1, 1, 1), 6, 0.6)
		av.can_move = true


func _reset_pads() -> void:
	for p in _pads:
		(p.cs as CollisionShape3D).set_deferred("disabled", false)
		var body: Node3D = p.body
		body.position = Vector3(float(p.x), -0.3, 0.0)
		body.rotation = Vector3.ZERO
		(p.mesh as MeshInstance3D).material_override = null
		body.show()


func _show_vals() -> void:
	for k in _pads.size():
		var lb: Label3D = _pads[k].label
		lb.text = "%d" % _vals[k]
		lb.modulate = [Color("#c9f2ff"), Color("#c9f2ff"), Color("#ffe066"), Color("#ff9f6b"), Color("#ff6bd5"), Color("#ff6bd5")][mini(_vals[k], 5)] if _vals[k] <= 5 else Color("#ff6bd5")


func _pad_of(av: PartyAvatar) -> int:
	var p := av.global_position
	if absf(p.z) > 1.5 or p.y < -0.6:
		return -1
	for k in PAD_X.size():
		if absf(p.x - float(PAD_X[k])) <= PAD_W * 0.5:
			return k
	return -1


func _resolve() -> void:
	var on: Array = [[], [], [], []]
	for i in active_slots():
		var av := avatars[i] as PartyAvatar
		av.can_move = false
		var k := _pad_of(av)
		if k >= 0:
			on[k].append(i)
		else:
			av.rig.react("confused")
	_result = []
	for k in 4:
		var who: Array = on[k]
		_result.append([who.size(), int(who[0]) if who.size() == 1 else -1])
		if who.size() == 1:
			add_score(int(who[0]), float(_vals[k]), Vector3(float(PAD_X[k]), 2.0, 0.0))
		elif who.size() > 1:
			for s in who:
				var av2 := avatars[int(s)] as PartyAvatar
				av2.velocity = Vector3(0, 1.5, 0)
				av2.can_move = true
	_play_result()


## Ergebnis darstellen (Host direkt, Clients sobald das Ergebnis ankommt)
func _play_result() -> void:
	for k in mini(_result.size(), _pads.size()):
		var n := int(_result[k][0])
		var w := int(_result[k][1])
		var body: Node3D = _pads[k].body
		if n == 1 and w >= 0:
			var m := WorldKit.mat(Game.player_color(w), 0.5, 0.6)
			(_pads[k].mesh as MeshInstance3D).material_override = m
			FX.stars(body.global_position + Vector3.UP * 1.0, Game.player_color(w).lightened(0.3), 14)
			Audio.sfx("coin_chime", body.global_position)
			if avatars[w]:
				(avatars[w] as PartyAvatar).rig.react("victory")
		elif n > 1:
			(_pads[k].cs as CollisionShape3D).set_deferred("disabled", true)
			FX.dust(body.global_position, Color(0.85, 0.65, 0.45), 18, 1.6)
			Audio.sfx("plank_break", body.global_position)
			Juice.shake(0.3)
			var tw := body.create_tween()
			tw.tween_property(body, "rotation:x", 0.7, 0.3)
			tw.parallel().tween_property(body, "position:y", -8.0, 1.0).set_ease(Tween.EASE_IN)
			tw.tween_callback(body.hide)


# --- Online (Host-Modell) ---------------------------------------------------------------------------------------

func net_pack() -> Dictionary:
	var d := super.net_pack()
	d["v"] = _vals
	d["res"] = _result
	d["rd"] = _round
	return d


func net_unpack(d: Dictionary) -> void:
	super.net_unpack(d)
	var rd := int(d.get("rd", _round))
	if rd != _round:
		_round = rd
		_reset_pads()
		_result = []
	var v: Array = d.get("v", [])
	if v.size() == 4:
		for k in 4:
			_vals[k] = int(v[k])
		_show_vals()
	var res: Array = d.get("res", [])
	if _result.is_empty() and not res.is_empty():
		_result = res
		_play_result()
	var el := time_limit - time_left
	var t := el - maxi(_round, 0) * RL
	_count_lbl.text = str(int(ceil(T_CHOOSE - t))) if t < T_CHOOSE and t >= 0.0 else ""


# --- CPU --------------------------------------------------------------------------------------------------------

func cpu_think(slot: int, _delta: float) -> void:
	var av := avatars[slot] as PartyAvatar
	var level: int = Game.players[slot].cpu_level
	var mem: Dictionary = cpu_mem[slot]
	if _phase != "choose" or not av.can_move:
		InputHub.set_virtual(slot, Vector2.ZERO)
		mem.erase("pick")
		mem.erase("switched")
		return
	var el := time_limit - time_left
	var t := el - _round * RL
	if not mem.has("pick"):
		mem["pick"] = _best_pad(slot, level, false)
	# Kurz vor Schluss: Profis schwenken um, wenn das Ziel überfüllt ist
	if t > T_CHOOSE - [0.5, 0.9, 1.2][level] and not mem.has("switched"):
		mem["switched"] = true
		if randf() < [0.2, 0.5, 0.8][level]:
			mem["pick"] = _best_pad(slot, level, true)
	var tx := float(PAD_X[int(mem.pick)])
	var to := Vector2(tx - av.global_position.x, 0.0 - av.global_position.z)
	InputHub.set_virtual(slot, to.normalized() * clampf(to.length() * 1.5, 0.0, 1.0))


func _best_pad(slot: int, level: int, crowd_aware: bool) -> int:
	var best := 0
	var bs := -INF
	for k in 4:
		var sc := float(_vals[k]) + randf_range(0.0, [3.0, 1.6, 0.8][level])
		for o in active_slots():
			if o == slot:
				continue
			var oa := avatars[o] as PartyAvatar
			var close := absf(oa.global_position.x - float(PAD_X[k])) < (1.6 if crowd_aware else 2.2)
			if close:
				sc -= 2.2 if crowd_aware else 0.8
		if sc > bs:
			bs = sc
			best = k
	return best
