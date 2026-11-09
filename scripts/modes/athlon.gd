class_name Athlon
extends Node3D
## Lumos-Athlon: Ein großer Wettlauf für bis zu 20 Läufer (online) bzw. 1–4 Spieler mit CPUs (lokal).
## Jede Runde spielen alle gleichzeitig dieselbe schnelle Solo-Herausforderung (12 Sekunden). Jede Münze
## bringt ein Feld weiter. Glücksfelder schieben an, Pusteböen werfen zurück, und jede dritte Runde pustet
## Pustebacke den Führenden ein Stück zurück. Wer zuerst zwei Runden um die Wiese schafft, gewinnt.
## Online steuert der Host den Ablauf: Er verkündet die Herausforderung, sammelt die Münzen aller Geräte
## und verteilt das Rundenergebnis. Alle Geräte bewegen die Läufer daraus identisch.

const TRACK_N := 36
const LAPS := 2
const MAX_ROUNDS := 10
const RX := 17.0
const RZ := 11.5
const SPECIAL := {4: "luck", 9: "wind", 14: "star", 20: "luck", 25: "wind", 31: "star"}
const PALETTE := [Color("#ff5c7a"), Color("#3fa7ff"), Color("#2ecc71"), Color("#ffd23f"), Color("#c06bff"), Color("#ff9f1a"),
	Color("#1abc9c"), Color("#ff7ad9"), Color("#7fd6ff"), Color("#a3e048"), Color("#f78fb3"), Color("#6c7bff"),
	Color("#ffb070"), Color("#57e0c1"), Color("#d6a2ff"), Color("#ffe27a"), Color("#8fd16a"), Color("#ff8a8a"),
	Color("#9ad0ff"), Color("#e8c25a")]
const CPU_NAMES := ["Hoppel", "Piepsi", "Mauzi", "Hirschi", "Muhla", "Summsi", "Kraxi", "Wuschel", "Flausch", "Knuddel",
	"Plüschi", "Brummi", "Zwitschi", "Puschel", "Mümmel", "Tapsi", "Schnuffel", "Kuschel", "Bommel", "Flocke"]

var runners: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var round_i := 0
var online := false
var cam: Camera3D
var _tiles: Array[Vector3] = []
var _hud: Control
var _round_label: Label
var _banner: Label
var _sub: Label
var _board: VBoxContainer
var _panels: Control
var _challenges: Array[AthlonChallenge] = []
var _order: Array[String] = []
var _finish: Array[int] = []
var _net_round: Dictionary = {}
var _net_res: Dictionary = {}
var _net_scores: Dictionary = {}
var _net_ready: Dictionary = {}
var _net_start := false
var _cam_target := Vector3.ZERO
var _cam_pos := Vector3(0, 21, 25)


static func runner_color(i: int) -> Color:
	return PALETTE[i % PALETTE.size()]


func _ready() -> void:
	online = Net.in_game()
	rng.seed = (int(Net.game_cfg.get("seed", 1)) ^ 0xa7410) if online else randi()
	WorldKit.env(self, "day")
	WorldKit.backdrop(self, "meadow", Color("#86d06a"), -0.56)
	_build_world()
	_build_roster()
	_spawn_runners()
	_build_hud()
	cam = Camera3D.new()
	add_child(cam)
	cam.fov = 50.0
	cam.position = _cam_pos
	cam.look_at(Vector3(0, 0, 2))
	cam.make_current()
	if online:
		Net.message.connect(_on_net)
	_order = []
	for k in AthlonChallenge.KINDS:
		_order.append(String(k))
	for k in range(_order.size() - 1, 0, -1):
		var j := rng.randi() % (k + 1)
		var tmp := _order[k]
		_order[k] = _order[j]
		_order[j] = tmp
	Audio.music("race", 1.0)
	InputHub.set_touch_profile("athlon")
	_main()


var _look := Vector3(0, 0, 2)


func _process(delta: float) -> void:
	if cam:
		var k := clampf(delta * 2.2, 0.0, 1.0)
		cam.position = cam.position.lerp(_cam_pos, k)
		_look = _look.lerp(_cam_target, k)
		cam.look_at(_look, Vector3.UP)


# --- Welt ---------------------------------------------------------------------------------------------------

func _tile_pos(k: int) -> Vector3:
	var a := PI * 0.5 - TAU * float(posmod(k, TRACK_N)) / TRACK_N
	return Vector3(cos(a) * RX, 0.0, sin(a) * RZ)


func _build_world() -> void:
	WorldKit.box(self, Vector3(110, 1, 90), Vector3(0, -0.5, 0), Color("#86d06a"), false)
	for i in TRACK_N:
		_tiles.append(_tile_pos(i))
	# Laufbahn: helle Platten, Sonderfelder farbig
	for i in TRACK_N:
		var p := _tiles[i]
		var sp: String = SPECIAL.get(i, "")
		var col := Color("#fff3e0")
		if i == 0:
			col = Color("#ffffff")
		elif sp == "luck":
			col = Color("#7ed957")
		elif sp == "wind":
			col = Color("#8fb0ff")
		elif sp == "star":
			col = Color("#ffd23f")
		var t := WorldKit.cylinder(self, 1.35, 0.3, p + Vector3(0, 0.15, 0), col, false)
		t.name = "Tile%d" % i
		if sp != "":
			var l := Label3D.new()
			l.text = {"luck": "+3", "wind": "-3", "star": "+5"}[sp]
			l.font = UI.title_font()
			l.font_size = 96
			l.outline_size = 20
			l.outline_modulate = Color(0.15, 0.08, 0.02)
			l.pixel_size = 0.008
			l.rotation.x = -PI * 0.5
			l.position = p + Vector3(0, 0.32, 0)
			add_child(l)
	# Start-/Zielbogen
	var s := _tiles[0]
	for side in [-1.0, 1.0]:
		WorldKit.cylinder(self, 0.25, 4.6, s + Vector3(side * 2.4, 2.3, 0), Color("#f2ead8"), false)
	WorldKit.box(self, Vector3(5.6, 1.0, 0.3), s + Vector3(0, 4.6, 0), Color("#ff5c7a"), false)
	var sl := Label3D.new()
	sl.text = "START · ZIEL"
	sl.font = UI.title_font()
	sl.font_size = 72
	sl.outline_size = 14
	sl.pixel_size = 0.009
	sl.position = s + Vector3(0, 4.6, 0.2)
	add_child(sl)
	# Innenfeld: Blumen, Teich, Pustebacke-Wolke
	for i in 50:
		var p := Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-7, 7))
		if Vector2(p.x / (RX - 3.0), p.z / (RZ - 3.0)).length() < 1.0:
			WorldKit.place(self, ["plat/flowers", "nat/flower_yellow", "nat/flower_purple", "nat/bush", "nat/grass"][i % 5], p, rng.randf() * 360.0, rng.randf_range(1.2, 1.8))
	var cloud := Node3D.new()
	cloud.name = "Pustebacke"
	add_child(cloud)
	cloud.position = Vector3(0, 6, -2)
	for q in [Vector3(0, 0, 0), Vector3(1.6, 0.2, 0), Vector3(-1.6, 0.1, 0), Vector3(0.8, 0.9, 0), Vector3(-0.8, 0.8, 0)]:
		var puff := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.4
		sm.height = 2.4
		sm.material = WorldKit.mat(Color(1, 1, 1), 1.0, 0.1)
		puff.mesh = sm
		puff.position = q
		cloud.add_child(puff)
	for ex in [-0.5, 0.5]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.2
		es.height = 0.4
		es.material = WorldKit.mat(Color(0.12, 0.1, 0.2), 0.4)
		eye.mesh = es
		eye.position = Vector3(ex, 0.3, 1.3)
		cloud.add_child(eye)
	var tw := cloud.create_tween().set_loops()
	tw.tween_property(cloud, "position:y", 6.6, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(cloud, "position:y", 6.0, 1.6).set_trans(Tween.TRANS_SINE)
	# Kulisse: Bäume, Hügel, Windmühle
	for i in 46:
		var a := TAU * i / 46.0
		var r := rng.randf_range(27.0, 34.0)
		var front := clampf(sin(a), 0.0, 1.0)
		WorldKit.place(self, ["plat/tree", "nat/tree_oak", "castle/tree", "nat/tree_default", "nat/bush"][i % 5], Vector3(cos(a) * r, 0, sin(a) * r * 0.8), rng.randf() * 360.0, rng.randf_range(3.0, 4.4) * (1.0 - front * 0.5))
	WorldKit.place(self, "town/windmill", Vector3(-24, 0, -16), 30.0, 3.0)
	WorldKit.cottage(self, Vector3(24, 0, -15), -140.0, 1.6, Color("#fff1d8"), Color("#ff8a8a"))
	for k in 6:
		var a2 := TAU * k / 6.0 + 0.3
		WorldKit.place(self, "plat/flag", Vector3(cos(a2) * (RX + 3.2), 0, sin(a2) * (RZ + 3.2)), 0.0, 1.6)


# --- Läufer -------------------------------------------------------------------------------------------------

func _build_roster() -> void:
	runners.clear()
	if online:
		var heroes: Dictionary = Net.game_cfg.get("heroes", {})
		var names: Dictionary = Net.game_cfg.get("names", {})
		var keys: Array = heroes.keys()
		keys.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
		for k in keys:
			var sl := int(k)
			runners.append({"name": String(names.get(k, "Spieler")), "hero": String(heroes[k]), "cpu": false, "level": 1,
				"local": 0 if sl == Net.my_slot else -1, "slot": sl, "steps": 0, "place": 0})
	else:
		for i in 4:
			if not Game.players[i].cpu:
				runners.append({"name": Game.hero(Game.players[i].hero).name, "hero": String(Game.players[i].hero), "cpu": false, "level": 1,
					"local": i, "slot": i, "steps": 0, "place": 0})
	var want := maxi(int(Game.settings.get("athlon_size", 8)) if not online else 8, runners.size())
	var hero_ids: Array = Game.HEROES.map(func(h: Dictionary) -> String: return h.id)
	var n := 0
	while runners.size() < want:
		runners.append({"name": CPU_NAMES[n % CPU_NAMES.size()], "hero": String(hero_ids[(n + 2) % hero_ids.size()]), "cpu": true,
			"level": rng.randi() % 3, "local": -1, "slot": 100 + n, "steps": 0, "place": 0})
		n += 1


func _spawn_runners() -> void:
	for i in runners.size():
		var r := CharacterRig.new()
		add_child(r)
		r.setup(Game.hero(String(runners[i].hero)).model, -1, 0.62)
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.42
		cm.bottom_radius = 0.42
		cm.height = 0.04
		cm.material = WorldKit.mat(runner_color(i), 0.5, 0.4)
		disc.mesh = cm
		disc.position.y = 0.03
		r.add_child(disc)
		if int(runners[i].local) >= 0:
			var tag := Label3D.new()
			tag.text = "P%d" % (int(runners[i].local) + 1) if not online else "DU"
			tag.font = UI.title_font()
			tag.font_size = 64
			tag.outline_size = 14
			tag.modulate = runner_color(i).lightened(0.3)
			tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			tag.no_depth_test = true
			tag.pixel_size = 0.008
			tag.position = Vector3(0, 2.2, 0)
			r.add_child(tag)
		r.play("idle")
		runners[i]["rig"] = r
	_arrange(true)


## Läufer auf ihren Feldern verteilen (mehrere auf einem Feld stehen nebeneinander).
func _arrange(instant := false) -> void:
	var by_tile := {}
	for i in runners.size():
		var tk := posmod(int(runners[i].steps), TRACK_N) if int(runners[i].place) == 0 else -1
		if not by_tile.has(tk):
			by_tile[tk] = []
		(by_tile[tk] as Array).append(i)
	for tk in by_tile:
		var list: Array = by_tile[tk]
		for j in list.size():
			var i: int = list[j]
			var base := _tiles[0] + Vector3(0, 0, 3.5) if int(tk) < 0 else _tiles[int(tk)]
			var off := Vector3.ZERO
			if list.size() > 1:
				var cols := mini(5, list.size())
				var row := j / cols
				var col := j % cols
				var tangent := (_tiles[posmod(int(tk) + 1, TRACK_N)] - _tiles[posmod(int(tk), TRACK_N)]).normalized() if int(tk) >= 0 else Vector3.RIGHT
				var side := Vector3(-tangent.z, 0, tangent.x)
				off = side * (float(col) - (cols - 1) * 0.5) * 0.75 - tangent * float(row) * 0.75
			var rig: CharacterRig = runners[i].rig
			var target := base + off + Vector3(0, 0.3, 0)
			if instant:
				rig.position = target
			else:
				rig.create_tween().tween_property(rig, "position", target, 0.3)


# --- HUD ----------------------------------------------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_hud = UI.center_root(layer)
	_round_label = UI.label("Lumos-Athlon", 34, Color.WHITE, true, 10)
	_hud.add_child(_round_label)
	UI.place(_round_label, Control.PRESET_TOP_LEFT, Vector2(24, 18), Vector2(420, 48))
	var bp := UI.panel()
	_hud.add_child(bp)
	_board = UI.vbox(2)
	bp.add_child(_board)
	UI.place(bp, Control.PRESET_TOP_RIGHT, Vector2(-330, 16), Vector2(314, 0))
	_banner = UI.label("", 64, UI.GOLD, true, 14)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_banner)
	UI.place(_banner, Control.PRESET_CENTER, Vector2(-560, -150), Vector2(1120, 90))
	_sub = UI.label("", 28, Color.WHITE, true, 8)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud.add_child(_sub)
	UI.place(_sub, Control.PRESET_CENTER, Vector2(-520, -60), Vector2(1040, 80))
	_panels = Control.new()
	_panels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_panels)
	_panels.set_anchors_preset(Control.PRESET_FULL_RECT)
	_refresh_board({})


func _ranking() -> Array[int]:
	var idx: Array[int] = []
	for i in runners.size():
		idx.append(i)
	idx.sort_custom(func(a: int, b: int) -> bool:
		var pa := int(runners[a].place)
		var pb := int(runners[b].place)
		if pa > 0 or pb > 0:
			if pa > 0 and pb > 0:
				return pa < pb
			return pa > 0
		if int(runners[a].steps) != int(runners[b].steps):
			return int(runners[a].steps) > int(runners[b].steps)
		return a < b)
	return idx


func _refresh_board(gains: Dictionary) -> void:
	for c in _board.get_children():
		c.queue_free()
	var rank := _ranking()
	var shown: Array[int] = []
	for k in mini(8, rank.size()):
		shown.append(rank[k])
	for k in range(8, rank.size()):
		if int(runners[rank[k]].local) >= 0:
			shown.append(rank[k])
	for i in shown:
		var row := UI.hbox(8)
		var pos := rank.find(i) + 1
		row.add_child(UI.label("%d." % pos, 20, UI.GOLD if pos <= 3 else Color.WHITE, true))
		var dot := ColorRect.new()
		dot.color = runner_color(i)
		dot.custom_minimum_size = Vector2(14, 14)
		row.add_child(dot)
		var nm := UI.label(String(runners[i].name).substr(0, 12), 19, Color.WHITE if int(runners[i].local) < 0 else runner_color(i).lightened(0.4), true)
		nm.custom_minimum_size.x = 130
		row.add_child(nm)
		var st := int(runners[i].steps)
		var info := "ZIEL!" if int(runners[i].place) > 0 else "R%d · %d" % [mini(LAPS, st / TRACK_N + 1), st % TRACK_N]
		row.add_child(UI.label(info, 18, Color(1, 1, 1, 0.8), true))
		if gains.has(i):
			row.add_child(UI.label("+%d" % int(gains[i]), 18, Color("#7dff9a"), true))
		_board.add_child(row)


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


# --- Ablauf -------------------------------------------------------------------------------------------------

func _main() -> void:
	await get_tree().process_frame
	_cam_pos = _tiles[0] + Vector3(0, 4.5, 9.0)
	_cam_target = _tiles[0] + Vector3(0, 1.0, 0)
	cam.position = _cam_pos
	_look = _cam_target
	for i in runners.size():
		(runners[i].rig as CharacterRig).react(["wave", "cheer", "determined"][i % 3])
	Audio.jingle("round", false)
	await _show("Lumos-Athlon!", "%d Läufer · %d Runden um die Wiese · jede Münze = ein Feld" % [runners.size(), LAPS], UI.GOLD, 2.4)
	_cam_pos = Vector3(0, 21, 25)
	_cam_target = Vector3(0, 0, 1)
	if online:
		await _net_barrier()
	for r in range(1, MAX_ROUNDS + 1):
		round_i = r
		_round_label.text = "Runde %d / %d" % [r, MAX_ROUNDS]
		Juice.ui_punch(_round_label, 0.2, 0.3)
		var kind := await _round_kind(r)
		await _play_challenge(kind)
		var gains := await _collect(r)
		await _apply_gains(gains)
		if r % 3 == 0 and _finish.size() < runners.size():
			await _pustebacke()
		if _finish.size() >= mini(3, runners.size()) or _finish.size() >= runners.size():
			break
	await _finale()


func _round_kind(r: int) -> String:
	if not online or Net.is_host:
		var k := _order[(r - 1) % _order.size()]
		if online:
			Net.send({"k": "ath_round", "r": r, "c": k}, true)
		return k
	var w := 0.0
	while not _net_round.has(r) and w < 60.0 and Net.online:
		await get_tree().process_frame
		w += get_process_delta_time()
	return String(_net_round.get(r, _order[(r - 1) % _order.size()]))


func _play_challenge(kind: String) -> void:
	var info: Dictionary = AthlonChallenge.INFO[kind]
	Audio.sfx("drumroll", null, -6.0)
	await _show(String(info.name), String(info.help), Color.WHITE, 2.2)
	for c in _challenges:
		c.queue_free()
	_challenges.clear()
	var locals: Array[int] = []
	for i in runners.size():
		if int(runners[i].local) >= 0:
			locals.append(i)
	var vp := get_viewport().get_visible_rect().size
	var n := locals.size()
	var sz := Vector2(760, 430) if n == 1 else (Vector2(600, 400) if n == 2 else Vector2(560, 300))
	for k in n:
		var i := locals[k]
		var ch := AthlonChallenge.new().setup(kind, int(runners[i].local), rng.randi() if not online else (int(Net.game_cfg.get("seed", 1)) + round_i * 31 + k), String(runners[i].name), runner_color(i))
		ch.set_meta("runner", i)
		_panels.add_child(ch)
		var pos := (vp - sz) * 0.5
		if n == 2:
			pos = Vector2(vp.x * 0.5 - sz.x - 12 + k * (sz.x + 24), (vp.y - sz.y) * 0.5 + 30)
		elif n >= 3:
			pos = Vector2(vp.x * 0.5 - sz.x - 10 + (k % 2) * (sz.x + 20), 120 + (k / 2) * (sz.y + 16))
		ch.position = pos
		ch.size = sz
		Juice.pop_in(ch, 0.3)
		_challenges.append(ch)
	for k in 3:
		CutsceneManager.big_word(str(3 - k), Color.WHITE, 0.25)
		Audio.sfx("countdown", null, -4.0)
		await get_tree().create_timer(0.6).timeout
	CutsceneManager.big_word("LOS!", UI.GOLD, 0.3)
	Audio.sfx("go", null, -2.0)
	for c in _challenges:
		c.start()
	Audio.minigame_music(-1, 0.3)
	get_tree().create_timer(AthlonChallenge.DURATION - 4.5).timeout.connect(Audio.minigame_hurry)
	if n == 0:
		_show("Alle spielen …", "", Color.WHITE, AthlonChallenge.DURATION)
	await get_tree().create_timer(AthlonChallenge.DURATION + 0.3).timeout
	Audio.minigame_outro()
	Audio.sfx("bell")
	await get_tree().create_timer(1.0).timeout


func _collect(r: int) -> Dictionary:
	var gains := {}
	for ch in _challenges:
		gains[int(ch.get_meta("runner", 0))] = ch.coins
	for c in _challenges:
		var tw := c.create_tween()
		tw.tween_property(c, "modulate:a", 0.0, 0.3)
		tw.tween_callback(c.queue_free)
	_challenges.clear()
	if not online:
		for i in runners.size():
			if bool(runners[i].cpu):
				gains[i] = AthlonChallenge.sim_score(_order[(r - 1) % _order.size()], int(runners[i].level), rng)
		return gains
	if not Net.is_host:
		for i in gains:
			Net.send({"k": "ath_sc", "r": r, "i": int(i), "v": int(gains[i])}, true, false)
		var w := 0.0
		_show("Warte auf die anderen …", "", Color.WHITE, 0.8)
		while not _net_res.has(r) and w < 40.0 and Net.online:
			await get_tree().process_frame
			w += get_process_delta_time()
		var res: Array = _net_res.get(r, [])
		var out := {}
		for i in mini(res.size(), runners.size()):
			out[i] = int(res[i])
		return out
	# Host: Münzen aller Geräte einsammeln (max. 8 s warten), CPUs simulieren, Ergebnis verteilen
	for i in gains:
		_net_scores["%d:%d" % [r, int(i)]] = int(gains[i])
	var w2 := 0.0
	while w2 < 8.0:
		var missing := false
		for i in runners.size():
			if not bool(runners[i].cpu) and not _net_scores.has("%d:%d" % [r, i]) and _slot_connected(int(runners[i].slot)):
				missing = true
		if not missing:
			break
		await get_tree().process_frame
		w2 += get_process_delta_time()
	var arr: Array = []
	var cpu_rng := RandomNumberGenerator.new()
	cpu_rng.seed = rng.seed + r * 977
	for i in runners.size():
		var v := 0
		if bool(runners[i].cpu):
			v = AthlonChallenge.sim_score(_order[(r - 1) % _order.size()], int(runners[i].level), cpu_rng)
		else:
			v = int(_net_scores.get("%d:%d" % [r, i], 0))
		arr.append(v)
	Net.send({"k": "ath_res", "r": r, "g": arr}, true)
	var out2 := {}
	for i in arr.size():
		out2[i] = int(arr[i])
	return out2


func _slot_connected(slot: int) -> bool:
	for id in Net.players:
		if int(Net.players[id].get("slot", -1)) == slot:
			return true
	return false


func _debug_digest() -> void:
	if "--net-test" in str(OS.get_cmdline_user_args()):
		print("[NET] Athlon R%d · Felder %s" % [round_i, runners.map(func(r: Dictionary) -> int: return int(r.steps))])


func _apply_gains(gains: Dictionary) -> void:
	Audio.music("race", 1.5)
	_refresh_board(gains)
	for i in gains:
		var rig: CharacterRig = runners[int(i)].rig
		Juice.float_text(self, rig.global_position + Vector3.UP * 2.0, "+%d" % int(gains[i]), UI.GOLD, 60)
	await get_tree().create_timer(1.2).timeout
	# Alle laufen gleichzeitig los: Schritt für Schritt
	var max_steps := 0
	for i in gains:
		max_steps = maxi(max_steps, int(gains[i]))
	var before := {}
	for i in runners.size():
		before[i] = int(runners[i].steps)
	for s in max_steps:
		for i in gains:
			if int(runners[int(i)].place) > 0 or s >= int(gains[i]):
				continue
			runners[int(i)].steps = int(runners[int(i)].steps) + 1
			var rig: CharacterRig = runners[int(i)].rig
			var to := _tiles[posmod(int(runners[int(i)].steps), TRACK_N)]
			rig.face_now(to - rig.position)
			rig.play("run", 0.1, 1.4)
			rig.hop(0.35, 0.16)
			if int(runners[int(i)].steps) >= TRACK_N * LAPS:
				_runner_finished(int(i))
		_arrange()
		Audio.sfx("tick", null, -14.0, 1.0 + s * 0.02)
		await get_tree().create_timer(0.17).timeout
	for i in runners.size():
		(runners[i].rig as CharacterRig).play("idle")
	# Sonderfelder (in fester Reihenfolge, damit alle Geräte gleich rechnen)
	for i in runners.size():
		if int(runners[i].place) > 0 or int(before[i]) == int(runners[i].steps):
			continue
		var sp: String = SPECIAL.get(posmod(int(runners[i].steps), TRACK_N), "")
		if sp == "":
			continue
		var rig2: CharacterRig = runners[i].rig
		match sp:
			"luck":
				runners[i].steps = int(runners[i].steps) + 3
				FX.stars(rig2.global_position + Vector3.UP, Color("#7ed957"), 10)
				Juice.float_text(self, rig2.global_position + Vector3.UP * 2.4, "Glück! +3", Color("#7ed957"), 54)
				Audio.sfx("powerup", rig2.global_position, -6.0)
			"wind":
				runners[i].steps = maxi(0, int(runners[i].steps) - 3)
				FX.smoke(rig2.global_position + Vector3.UP, Color(0.85, 0.9, 1.0), 8, 0.8)
				Juice.float_text(self, rig2.global_position + Vector3.UP * 2.4, "Pusteböe! -3", Color("#8fb0ff"), 54)
				Audio.sfx("whoosh", rig2.global_position, -4.0)
				rig2.react("dizzy")
			"star":
				runners[i].steps = int(runners[i].steps) + 5
				FX.stars(rig2.global_position + Vector3.UP, UI.GOLD, 16)
				Juice.float_text(self, rig2.global_position + Vector3.UP * 2.4, "Sternenschub! +5", UI.GOLD, 54)
				Audio.sfx("star", rig2.global_position, -4.0)
				rig2.react("cheer")
		if int(runners[i].steps) >= TRACK_N * LAPS:
			_runner_finished(i)
	_arrange()
	_refresh_board({})
	_debug_digest()
	await get_tree().create_timer(1.0).timeout


func _runner_finished(i: int) -> void:
	if int(runners[i].place) > 0:
		return
	_finish.append(i)
	runners[i].place = _finish.size()
	var rig: CharacterRig = runners[i].rig
	rig.react("victory")
	FX.confetti(rig.global_position + Vector3.UP * 2.0, 40)
	Audio.sfx("fanfare" if _finish.size() == 1 else "star", null, -4.0)
	Juice.float_text(self, rig.global_position + Vector3.UP * 2.8, "%d. Platz!" % _finish.size(), UI.GOLD, 70)


func _pustebacke() -> void:
	var cloud := get_node("Pustebacke") as Node3D
	_cam_target = cloud.position
	Audio.sfx("thunder", null, -6.0, 1.3)
	await _show("Pustebacke pustet!", "Die Führenden werden zurückgeweht – hinten gibt es Rückenwind!", Color("#c9b5ff"), 1.8)
	var rank := _ranking()
	var lead: Array[int] = []
	for i in rank:
		if int(runners[i].place) == 0:
			lead.append(i)
		if lead.size() >= 2:
			break
	for i in lead:
		runners[i].steps = maxi(0, int(runners[i].steps) - 4)
		var rig: CharacterRig = runners[i].rig
		rig.react("launch")
		FX.smoke(rig.global_position + Vector3.UP, Color(1, 1, 1), 12, 1.0)
	var back: Array[int] = []
	for k in range(rank.size() - 1, -1, -1):
		if int(runners[rank[k]].place) == 0 and not (rank[k] in lead):
			back.append(rank[k])
		if back.size() >= 2:
			break
	for i in back:
		runners[i].steps = int(runners[i].steps) + 4
		(runners[i].rig as CharacterRig).react("cheer")
	Audio.sfx("whoosh", null, -2.0)
	_arrange()
	_refresh_board({})
	await get_tree().create_timer(1.4).timeout
	_cam_target = Vector3(0, 0, 2)


# --- Online ---------------------------------------------------------------------------------------------------

func _on_net(_from: String, msg: Dictionary) -> void:
	match String(msg.get("k", "")):
		"ath_ready":
			_net_ready[String(msg.get("f", _from))] = true
		"ath_start":
			_net_start = true
		"ath_round":
			_net_round[int(msg.get("r", 0))] = String(msg.get("c", "hammer"))
		"ath_sc":
			if Net.is_host:
				_net_scores["%d:%d" % [int(msg.get("r", 0)), int(msg.get("i", -1))]] = clampi(int(msg.get("v", 0)), 0, 15)
		"ath_res":
			_net_res[int(msg.get("r", 0))] = msg.get("g", [])


func _net_barrier() -> void:
	if Net.is_host:
		var w := 0.0
		while w < 15.0:
			var all := true
			for id in Net.players:
				if id != Net.me and not _net_ready.has(id):
					all = false
			if all:
				break
			await get_tree().process_frame
			w += get_process_delta_time()
		Net.send({"k": "ath_start"}, true)
	else:
		Net.send({"k": "ath_ready"}, true, false)
		var w2 := 0.0
		while not _net_start and w2 < 30.0 and Net.online:
			await get_tree().process_frame
			w2 += get_process_delta_time()


# --- Finale ---------------------------------------------------------------------------------------------------

func _finale() -> void:
	var rank := _ranking()
	for k in rank.size():
		if int(runners[rank[k]].place) == 0:
			_finish.append(rank[k])
			runners[rank[k]].place = _finish.size()
	rank = _ranking()
	Audio.jingle("win")
	_cam_pos = Vector3(0, 5.5, 12)
	_cam_target = Vector3(0, 1.6, 0)
	for k in mini(3, rank.size()):
		var h: float = [2.2, 1.6, 1.1][k]
		var px: float = [0.0, -2.4, 2.4][k]
		var block := WorldKit.box(self, Vector3(2.2, h, 2.0), Vector3(px, h * 0.5, 0), [UI.GOLD, Color("#d8dce6"), Color("#e0a070")][k], false)
		block.name = "Podium%d" % k
		var rig: CharacterRig = runners[rank[k]].rig
		rig.position = Vector3(px, h + 0.05, 0)
		rig.face_now(Vector3(0, 0, 1))
		rig.react("victory" if k == 0 else "cheer")
	FX.confetti(Vector3(0, 4, 0), 120)
	await _show("%s gewinnt den Athlon!" % String(runners[rank[0]].name), "", UI.GOLD, 2.6)
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var root := UI.center_root(layer)
	var panel := UI.panel()
	root.add_child(panel)
	var v := UI.vbox(4)
	panel.add_child(v)
	var t := UI.label("Endstand", 44, UI.GOLD, true, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	for k in mini(12, rank.size()):
		var i := rank[k]
		var row := UI.hbox(10)
		row.add_child(UI.label("%d." % (k + 1), 24, UI.GOLD if k < 3 else Color.WHITE, true))
		var nm := UI.label(String(runners[i].name), 24, runner_color(i).lightened(0.3) if int(runners[i].local) >= 0 else Color.WHITE, true)
		nm.custom_minimum_size.x = 260
		row.add_child(nm)
		row.add_child(UI.label("Ziel" if int(runners[i].steps) >= TRACK_N * LAPS else "%d Felder" % int(runners[i].steps), 20, Color(1, 1, 1, 0.75), true))
		v.add_child(row)
	v.add_child(UI.prompt("a", "Weiter", 26))
	await get_tree().process_frame
	panel.position = (root.size - panel.size) / 2.0
	Juice.pop_in(panel, 0.4)
	var w := 0.0
	while w < 20.0:
		await get_tree().process_frame
		w += get_process_delta_time()
		if w > 1.0 and InputHub.any_human_pressed("a"):
			break
	for i in runners.size():
		if int(runners[i].local) >= 0:
			Game.records_note("athlon_best_place", 100 - int(runners[i].place))
	if online:
		Net.back_to_lobby()
		Game.mode = "online"
		Router.goto("res://scenes/menu/MainMenu.tscn", {"page": "online"})
	else:
		Router.goto("res://scenes/menu/MainMenu.tscn", {"page": "modes"})
