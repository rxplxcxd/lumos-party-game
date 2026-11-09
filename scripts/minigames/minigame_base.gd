class_name MinigameBase
extends Node3D
## Basis aller 10 Minispiele.
##
## Ablauf: Teaser-Cutscene (Kanonen-Einflug) -> Anleitung -> 3-2-1-LOS -> Spiel -> "FERTIG!"
##         -> Sieger-Cutscene -> Ergebnis-Tafel -> zurück zum Brett / zur Auswahl.
## Unterklassen überschreiben build_arena(), optional spawn_players(), cpu_think(), on_tick(),
## check_end() und compute_placements().

const REWARDS := [10, 5, 2, 0]
const CATEGORY_LABELS := {"ffa": "Jeder gegen Jeden", "1v3": "1 gegen 3", "2v2": "2 gegen 2", "duel": "Duell",
	"coin": "Münzen-Minispiel", "luck": "Glücks-Minispiel", "boss": "Boss-Minispiel", "showdown": "Showdown", "coop": "Gemeinsam"}
const TEAM_COLORS := [Color("#3fa7ff"), Color("#ff4d6d")]

var game_id := ""
var info: Dictionary = {}
var env_preset := "day"
var time_limit := 40.0
var time_left := 40.0
var state := "setup"
var touch_profile := "minigame"
var survival := false
var race := false
var show_timer := true
var score_format := "%d"
var hazard := "lava"
var kill_y := -6.0
var avatar_scale := 0.85
var respawn_on_fall := false
var teaser_height := 0.75

var cam: ArenaCamera
var avatars: Array = [null, null, null, null]
var actors: Array = [null, null, null, null]
var rigs: Array = [null, null, null, null]
var alive: Array[bool] = [true, true, true, true]
var scores: Array[float] = [0.0, 0.0, 0.0, 0.0]
var out_order: Array[int] = []
var finish_order: Array[int] = []
var spawn_points: Array[Vector3] = []
var arena_center := Vector3.ZERO
var arena_radius := 12.0
var cannon_pos := Vector3(0, 0, 20)
var world: Node3D

var hud: CanvasLayer
var badges: Array[PlayerBadge] = []
var timer_label: Label
var _hud_root: Control
var _hurry_said := false
var _last_tick := -1
var cpu_mem: Array[Dictionary] = [{}, {}, {}, {}]
## Kategorie & Teams (vom Brett/Menü über Game.minigame_setup gesetzt)
var category := "ffa"
var teams: Array[int] = [0, 1, 2, 3]
var active: Array[bool] = [true, true, true, true]
var solo_slot := -1
## Online-Modell: "owner" = Figuren simuliert ihr Besitzer (NetAvatarSync), "host" = Host simuliert alles,
## Clients senden Eingaben und zeigen den Zustand aus net_pack()/net_unpack().
var net_model := "owner"
var _net_pack_t := 0.0
var _handicap := -1
## Spiel-Zufall: online auf allen Geräten gleich geseedet → identische Ereignisse (Farben, Bälle, Folgen).
var rng := RandomNumberGenerator.new()
var forced_placements: Array[int] = []
var net_sync: NetAvatarSync
## Minispiel-Musik: -1 = automatisch (Rotation über die vier Soundtracks), 0..3 = fester Track,
## -2 = das Spiel steuert seine Musik selbst (z. B. Rhythmus-Küche).
var music_track := -1
## Weite Umgebung hinter der Arena (Hügel, Wolken, Vögel, Dunst): "auto" nach env_preset, "none" = aus.
var backdrop_style := "auto"
var hurry_at := 12.0             # Sekunden vor Schluss: taktsynchroner Wechsel in die Hurry-Up-Version
var _music_hurried := false
var _net_ready: Dictionary = {}
var _net_go := false
var _debug_ai := "--debug-ai" in OS.get_cmdline_user_args()


func _ready() -> void:
	info = Game.minigame_info(game_id)
	if Net.in_game():
		rng.seed = int(Net.game_cfg.get("seed", 1)) ^ hash(game_id) ^ (int(Game.party.get("dseq", 0)) * 7919 if Game.mode == "party" else 0)
	else:
		rng.randomize()
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	var we := WorldKit.env(self, env_preset)
	if WorldKit.PRESETS.get(env_preset, {}).get("rays", false):
		WorldKit.god_rays(self, arena_center, arena_radius * 1.2, we.get_meta("sun"), 6)
	if spawn_points.is_empty():
		for i in 4:
			spawn_points.append(arena_center + Vector3(-4.5 + i * 3.0, 0.5, 0))
	_apply_setup()
	build_arena()
	_build_backdrop()
	spawn_players()
	_bench_inactive()
	_setup_camera()
	_build_hud()
	InputHub.set_touch_profile("none")
	# Soundtrack: offline rotierend, online aus dem gemeinsamen Zufall (alle Geräte hören denselben)
	if music_track == -1 and Net.in_game():
		music_track = rng.randi() % MusicMeta.MINIGAME.size()
	_flow()


# --- Zu überschreiben ------------------------------------------------------------------

func build_arena() -> void:
	pass


func spawn_players() -> void:
	for i in 4:
		var av := PartyAvatar.new()
		world.add_child(av)
		av.setup(i, spawn_points[i], avatar_scale)
		av.kill_y = kill_y
		av.hazard = hazard
		av.rig.face_now(Vector3(0, 0, 1))
		av.fell.connect(_on_avatar_fell)
		avatars[i] = av
		actors[i] = av
		rigs[i] = av.rig


func on_start() -> void:
	pass


func on_tick(_delta: float) -> void:
	pass


func on_timeout() -> void:
	end_game()


func check_end() -> bool:
	if survival:
		if is_team_game():
			return _alive_teams().size() <= 1
		return alive_count() <= 1
	return false


func cpu_think(_slot: int, _delta: float) -> void:
	pass


func on_fell(slot: int, _hazard: String) -> void:
	if respawn_on_fall:
		await get_tree().create_timer(1.2, false).timeout
		if state == "play" and avatars[slot]:
			(avatars[slot] as PartyAvatar).respawn(spawn_points[slot] + Vector3.UP * 2.0)
	else:
		eliminate(slot)


func _on_avatar_fell(av: PartyAvatar, hz: String) -> void:
	on_fell(av.slot, hz)


func setup_camera(c: ArenaCamera) -> void:
	c.fixed_center = arena_center
	c.offset = Vector3(0, arena_radius * 1.05, arena_radius * 0.95)


# --- Ablauf ---------------------------------------------------------------------------------------

func _setup_camera() -> void:
	cam = ArenaCamera.new()
	var tg: Array = []
	for i in 4:
		if actors[i] != null and active[i]:
			tg.append(actors[i])
	cam.targets = tg
	setup_camera(cam)
	add_child(cam)
	cam.make_current()
	cam.snap()


func _freeze_all(on: bool) -> void:
	for a in avatars:
		if a is PartyAvatar:
			(a as PartyAvatar).freeze(on)


func _flow() -> void:
	state = "intro"
	_freeze_all(true)
	await get_tree().process_frame
	await CutsceneManager.play("MinigameTeaser", {"game": self})
	await _instructions()
	if Net.in_game():
		Net.message.connect(_on_score_msg)
		if net_model == "owner":
			net_sync = NetAvatarSync.new().setup(self)
			add_child(net_sync)
		else:
			Net.message.connect(_on_host_model_msg)
		await _net_barrier()
	InputHub.set_touch_profile(touch_profile)
	await CutsceneManager.countdown()
	time_left = time_limit
	if music_track != -2:
		Audio.minigame_music(music_track)   # Schlag 0 = Spielstart (Rhythmus-Spiele laufen im Takt)
	state = "play"
	_freeze_all(false)
	on_start()
	# Partner-Minispiel: kleiner Startvorteil für den Auslöser
	if _handicap >= 0 and avatars[_handicap] is PartyAvatar:
		(avatars[_handicap] as PartyAvatar).max_speed *= 1.15
		scores[_handicap] += 0.5 if not survival else 0.0


func _process(delta: float) -> void:
	if state != "play":
		return
	if show_timer:
		time_left = maxf(0.0, time_left - delta)
		var secs := int(ceil(time_left))
		timer_label.text = str(secs)
		if time_left <= hurry_at and not _music_hurried and time_limit > hurry_at + 5.0:
			_start_hurry()
		if secs <= 10 and not _hurry_said:
			_hurry_said = true
			Audio.voice("hurry_up")
			timer_label.add_theme_color_override("font_color", Color("#ff6b6b"))
		if secs <= 5 and secs != _last_tick:
			_last_tick = secs
			Audio.sfx("tick", null, 0.0, 1.0 + (5 - secs) * 0.08, 0.0)
			Juice.ui_punch(timer_label, 0.3, 0.3)
	if _is_host_model_client():
		_update_badges()
		return   # Online (Host-Modell): Zustand kommt vom Host
	on_tick(delta)
	# Spiele ohne Uhr: Hurry-Up, sobald nur noch zwei im Rennen sind (Showdown-Spannung)
	if not show_timer and survival and not _music_hurried and active_slots().size() >= 3 and alive_count() == 2:
		_start_hurry()
	_update_badges()
	if _host_model_online() and Net.is_host:
		_net_pack_t -= delta
		if _net_pack_t <= 0.0:
			_net_pack_t = 1.0 / minf(Net.state_rate(), 15.0)
			Net.send({"k": "gs", "d": net_pack(), "tl": snappedf(time_left, 0.01), "sc": scores, "al": alive}, false)
	if (net_sync or _host_model_online()) and not Net.is_host:
		return   # Online: das Ende entscheidet der Host
	if state == "play" and show_timer and time_left <= 0.0:
		on_timeout()
	elif state == "play" and check_end():
		end_game()


func _physics_process(delta: float) -> void:
	if state == "play":
		for i in 4:
			if Game.players[i].cpu and active[i] and Net.owns_slot(i):
				cpu_think(i, delta)
		if _is_host_model_client() and not Game.players[Net.my_slot].cpu:
			var mv := InputHub.move(Net.my_slot)
			var held := {}
			for a in ["a", "b", "x", "r"]:
				if InputHub.held(Net.my_slot, a):
					held[a] = true
			Net.send({"k": "in", "s": Net.my_slot, "m": [snappedf(mv.x, 0.01), snappedf(mv.y, 0.01)], "h": held}, false, false)
		if _debug_ai and Engine.get_physics_frames() % 90 == 0:
			for i in 4:
				var a: Node3D = actors[i]
				print("[AI] P%d pos=%s mv=%s score=%s alive=%s" % [i, a.global_position.snapped(Vector3.ONE * 0.1), InputHub.move(i).snapped(Vector2.ONE * 0.01), scores[i], alive[i]])
	elif state != "setup":
		InputHub.clear_virtual()


## Online: alle Geräte starten gleichzeitig (Host gibt "go").
func _on_net_barrier_msg(from: String, msg: Dictionary) -> void:
	var k := String(msg.get("k", ""))
	if k == "ready":
		_net_ready[from] = true
	elif k == "go":
		_net_go = true


func _net_barrier() -> void:
	Net.message.connect(_on_net_barrier_msg)
	if Net.is_host:
		var waited := 0.0
		while waited < 12.0:
			var all := true
			for id in Net.players:
				if id != Net.me and not _net_ready.has(id):
					all = false
			if all:
				break
			await get_tree().process_frame
			waited += get_process_delta_time()
		Net.send({"k": "go"}, true)
	else:
		Net.send({"k": "ready"}, true, false)
		var w := 0.0
		while not _net_go and w < 15.0:
			await get_tree().process_frame
			w += get_process_delta_time()


func alive_count() -> int:
	var n := 0
	for a in alive:
		if a:
			n += 1
	return n


## Online (Owner-Modell): Gehört die Figur diesem Gerät? Nur dann wird über sie entschieden.
func net_owned(slot: int) -> bool:
	return net_sync == null or Net.owns_slot(slot)


func eliminate(slot: int) -> void:
	if not alive[slot]:
		return
	if not net_owned(slot):
		return   # der Besitzer meldet das Ausscheiden selbst
	alive[slot] = false
	if net_sync:
		report_score(slot)
	out_order.append(slot)
	if slot < badges.size():
		badges[slot].set_out(true)
	if alive_count() >= 1:
		Audio.sfx("bong", null, -4.0)


func finish_player(slot: int) -> void:
	if slot in finish_order:
		return
	finish_order.append(slot)
	Audio.sfx("star")
	if rigs[slot]:
		(rigs[slot] as CharacterRig).react("cheer")
	Juice.float_text(self, (actors[slot] as Node3D).global_position + Vector3.UP * 2.8, "%d." % finish_order.size(), Game.player_color(slot), 120)


func add_score(slot: int, amount: float, at: Vector3 = Vector3.INF) -> void:
	if not net_owned(slot):
		return
	scores[slot] += amount
	if net_sync:
		report_score(slot)
	if at != Vector3.INF:
		var txt := ("+%d" % int(amount)) if amount > 0 else ("%d" % int(amount))
		Juice.float_text(self, at, txt, Color("#7dff9a") if amount > 0 else Color("#ff6b6b"), 90)


func _build_backdrop() -> void:
	var st := backdrop_style
	if st == "auto":
		st = {"day": "meadow", "sunset": "meadow", "pirates": "beach", "snow": "snow", "sky": "sky", "observatory": "sky_dusk",
			"ghost": "night", "night": "night", "forest_night": "night", "graveyard": "night", "dungeon": "dungeon",
			"volcano": "dungeon", "space": "none", "station": "none"}.get(env_preset, "meadow")
	var col: Color = {"meadow": Color("#7cc860"), "beach": Color("#e8d6a0"), "snow": Color("#eef4fb"), "night": Color("#26324a"),
		"cake": Color("#f6c9d8")}.get(st, Color("#7cc860"))
	WorldKit.backdrop(world, st, col, -7.0, arena_center)


## Hurry-Up: Musik wechselt taktgenau in die schnellere Version, kleiner Warnton.
func _start_hurry() -> void:
	if _music_hurried:
		return
	_music_hurried = true
	if music_track != -2:
		Audio.minigame_hurry()
	Audio.sfx("alert", null, -4.0, 1.0, 0.0)
	on_hurry()


## Hook: Hurry-Up hat begonnen (Spiele können z. B. ihr Tempo anziehen).
func on_hurry() -> void:
	pass


func end_game() -> void:
	if state != "play":
		return
	state = "finish"
	if music_track != -2:
		Audio.minigame_outro()
	_freeze_all(true)
	InputHub.clear_virtual()
	InputHub.set_touch_profile("none")
	Audio.sfx("bell")
	await CutsceneManager.big_word("FERTIG!", Color("#ffcc33"), 1.0)
	# Online-Client: Endergebnis kommt vom Host (alle Geräte zeigen und verbuchen dasselbe)
	if (net_sync or _host_model_online()) and not Net.is_host:
		var w := 0.0
		while forced_placements.size() != 4 and w < 5.0 and Net.online:
			await get_tree().process_frame
			w += get_process_delta_time()
	var placements := forced_placements if forced_placements.size() == 4 else compute_placements()
	if net_sync and "--net-test" in str(OS.get_cmdline_user_args()):
		print("[NET] Minispiel-Ende · Platzierungen %s · alive %s · empfangen %s" % [placements, alive, Net.debug_counts])
	if (net_sync or _host_model_online()) and Net.is_host:
		Net.send({"k": "end", "pl": placements, "sc": scores}, true)
	await CutsceneManager.play("MinigameWin", {"game": self, "placements": placements})
	await _show_results(placements)
	_return(placements)


## Platzierung pro Spieler (1..4, Gleichstand teilt Platz). Nicht teilnehmende Slots erhalten 0.
## Team-Spiele: Siegerteam = Platz 1, Verlierer = Platz 2 (Unentschieden: alle Platz 2).
func compute_placements() -> Array[int]:
	var places: Array[int] = [0, 0, 0, 0]
	if is_team_game():
		var win := team_result()
		for i in 4:
			if active[i]:
				places[i] = 1 if teams[i] == win else 2
		return places
	var act := active_slots()
	if race:
		var order: Array[int] = []
		for f in finish_order:
			if active[f]:
				order.append(f)
		var rest: Array[int] = []
		for i in act:
			if not (i in order):
				rest.append(i)
		rest.sort_custom(func(a: int, b: int) -> bool: return scores[a] > scores[b])
		order.append_array(rest)
		for pos in order.size():
			places[order[pos]] = pos + 1
		return places
	if survival:
		var survivors: Array[int] = []
		for i in act:
			if alive[i]:
				survivors.append(i)
		for sv in survivors:
			places[sv] = 1
		var place := survivors.size() + 1
		for k in range(out_order.size() - 1, -1, -1):
			if active[out_order[k]]:
				places[out_order[k]] = place
				place += 1
		return places
	var idx: Array[int] = act.duplicate()
	idx.sort_custom(func(a: int, b: int) -> bool: return scores[a] > scores[b])
	for pos in idx.size():
		var p := idx[pos]
		places[p] = pos + 1
		if pos > 0 and is_equal_approx(scores[p], scores[idx[pos - 1]]):
			places[p] = places[idx[pos - 1]]
	return places


## Siegerteam (Team-ID) oder -1 bei Gleichstand. Überschreibbar.
func team_result() -> int:
	if survival:
		var at := _alive_teams()
		if at.size() == 1:
			return at[0]
		if at.is_empty():
			return teams[out_order[out_order.size() - 1]] if not out_order.is_empty() else -1
		var cnt := {}
		for i in active_slots():
			if alive[i]:
				cnt[teams[i]] = int(cnt.get(teams[i], 0)) + 1
		var best := -1
		var bc := -1
		var tie := false
		for t in cnt:
			if int(cnt[t]) > bc:
				bc = int(cnt[t])
				best = int(t)
				tie = false
			elif int(cnt[t]) == bc:
				tie = true
		return -1 if tie else best
	if race and not finish_order.is_empty():
		for f in finish_order:
			if active[f]:
				return teams[f]
	var sums := {}
	for i in active_slots():
		sums[teams[i]] = float(sums.get(teams[i], 0.0)) + scores[i]
	var best_t := -1
	var best_s := -INF
	var tie2 := false
	for t in sums:
		if float(sums[t]) > best_s:
			best_s = float(sums[t])
			best_t = int(t)
			tie2 = false
		elif is_equal_approx(float(sums[t]), best_s):
			tie2 = true
	return -1 if tie2 else best_t


# --- Teams & Kategorien -----------------------------------------------------------------------------------

func _apply_setup() -> void:
	var st: Dictionary = Game.minigame_setup
	Game.minigame_setup = {}
	var cats: Array = info.get("cats", ["ffa"])
	category = String(st.get("cat", cats[0] if not cats.is_empty() else "ffa"))
	if not (category in cats) and not cats.is_empty():
		category = String(cats[0])
	match category:
		"1v3":
			solo_slot = int(st.get("solo", 0))
			for i in 4:
				teams[i] = 0 if i == solo_slot else 1
		"2v2":
			var tm: Array = st.get("teams", [0, 1, 0, 1])
			for i in 4:
				teams[i] = int(tm[i])
		"duel":
			var ac: Array = st.get("active", [true, true, false, false])
			for i in 4:
				active[i] = bool(ac[i])
	if bool(st.get("short", false)):
		time_limit = maxf(15.0, time_limit * 0.55)
	_handicap = int(st.get("handicap", -1))
	if st.has("active") and category != "duel":
		var ac2: Array = st.active
		for i in 4:
			active[i] = bool(ac2[i])
	on_setup()


## Hook: nach Kategorie/Teams, vor build_arena() (z. B. Solo-Rolle vorbereiten).
func on_setup() -> void:
	pass


func is_team_game() -> bool:
	return category in ["1v3", "2v2"]


func same_team(a: int, b: int) -> bool:
	return is_team_game() and teams[a] == teams[b]


func active_slots() -> Array[int]:
	var out: Array[int] = []
	for i in 4:
		if active[i]:
			out.append(i)
	return out


func _alive_teams() -> Array:
	var out: Array = []
	for i in active_slots():
		if alive[i] and not (teams[i] in out):
			out.append(teams[i])
	return out


## Nicht teilnehmende Figuren (z. B. im Duell) aus dem Spiel nehmen.
func _bench_inactive() -> void:
	for i in 4:
		if active[i]:
			continue
		alive[i] = false
		var a: Node3D = actors[i]
		if a:
			a.visible = false
			a.global_position = Vector3(0, -300, 0)
			a.set_physics_process(false)
			a.process_mode = Node.PROCESS_MODE_DISABLED
		if avatars[i] is PartyAvatar:
			(avatars[i] as PartyAvatar).alive = false


## Münzen-Belohnung je Platz und Kategorie (Party-Modus).
static func reward_for(place: int, cat: String, score := 0.0) -> int:
	if place <= 0:
		return 0
	match cat:
		"1v3", "2v2":
			return 10 if place == 1 else 0
		"coin":
			return int(score)
		"duel", "luck", "showdown":
			return 0
	return REWARDS[clampi(place - 1, 0, 3)]


# --- Online: Host-Modell ---------------------------------------------------------------------------------

func _host_model_online() -> bool:
	return net_model == "host" and Net.in_game()


func _is_host_model_client() -> bool:
	return _host_model_online() and not Net.is_host


## Besitzer meldet Punktestand/Status seiner Figur (Owner-Modell, z. B. Rhythmus, Würfe, Glücksspiele).
func report_score(slot: int) -> void:
	if Net.in_game() and Net.owns_slot(slot):
		Net.send({"k": "sc", "s": slot, "v": scores[slot], "al": alive[slot], "x": score_extra(slot)}, true)


## Hook: zusätzliche Ergebnisdaten (z. B. "Boss besiegt") für Abenteuer-Aufträge.
func result_extra() -> Dictionary:
	return {}


## Zusatzdaten zur Punktemeldung (z. B. Wurfwinkel für die Wiederholung bei anderen).
func score_extra(_slot: int) -> Dictionary:
	return {}


## Hook: Punktemeldung eines anderen Geräts angekommen.
func on_remote_score(_slot: int, _extra: Dictionary) -> void:
	pass


func _on_score_msg(_from: String, msg: Dictionary) -> void:
	if String(msg.get("k", "")) != "sc":
		return
	var sl := int(msg.get("s", -1))
	if sl < 0 or sl > 3 or Net.owns_slot(sl):
		return
	scores[sl] = float(msg.get("v", 0.0))
	var was := alive[sl]
	alive[sl] = bool(msg.get("al", true))
	if was and not alive[sl] and not (sl in out_order):
		out_order.append(sl)
		_remote_out(sl)
	on_remote_score(sl, msg.get("x", {}))


## Eine fremde Figur ist laut ihrem Besitzer ausgeschieden: Anzeige nachziehen.
func _remote_out(sl: int) -> void:
	if sl < badges.size():
		badges[sl].set_out(true)
	var av := avatars[sl] as PartyAvatar
	if av and av.alive:
		av.alive = false
		av.freeze(true)
		av.rig.react("sad")
	Audio.sfx("bong", null, -6.0)


func _on_host_model_msg(_from: String, msg: Dictionary) -> void:
	match String(msg.get("k", "")):
		"in":
			if Net.is_host:
				var sl := int(msg.get("s", -1))
				var m: Array = msg.get("m", [0, 0])
				InputHub.set_net_input(sl, Vector2(float(m[0]), float(m[1])), msg.get("h", {}))
		"gs":
			if not Net.is_host:
				time_left = float(msg.get("tl", time_left))
				var sc: Array = msg.get("sc", [])
				for i in mini(4, sc.size()):
					scores[i] = float(sc[i])
				var al: Array = msg.get("al", [])
				for i in mini(4, al.size()):
					alive[i] = bool(al[i])
				net_unpack(msg.get("d", {}))
		"end":
			if not Net.is_host:
				var pl: Array = msg.get("pl", [])
				var places: Array[int] = []
				for p in pl:
					places.append(int(p))
				if places.size() == 4:
					var fsc: Array = msg.get("sc", [])
					for fi in mini(4, fsc.size()):
						scores[fi] = float(fsc[fi])
					forced_placements = places
					end_game()


## Host: kompakter Spielzustand für Clients (Host-Modell). Figuren werden automatisch mitgeschickt.
func net_pack() -> Dictionary:
	return {"av": _pack_avatars()}


## Client: Spielzustand vom Host anwenden (Host-Modell).
func net_unpack(d: Dictionary) -> void:
	_unpack_avatars(d.get("av", []))


func _pack_avatars() -> Array:
	var out: Array = []
	for i in 4:
		var a: Node3D = actors[i]
		if a == null or not active[i]:
			out.append(null)
			continue
		var p := a.global_position
		var ry: float = (avatars[i] as PartyAvatar).rig.rotation.y if avatars[i] is PartyAvatar else a.rotation.y
		var hs: float = Vector2((avatars[i] as PartyAvatar).velocity.x, (avatars[i] as PartyAvatar).velocity.z).length() if avatars[i] is PartyAvatar else 0.0
		out.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01), snappedf(ry, 0.01), snappedf(hs, 0.1)])
	return out


func _unpack_avatars(arr: Array) -> void:
	for i in mini(4, arr.size()):
		if arr[i] == null or actors[i] == null:
			continue
		var e: Array = arr[i]
		var a: Node3D = actors[i]
		var target := Vector3(float(e[0]), float(e[1]), float(e[2]))
		a.set_physics_process(false)
		a.global_position = a.global_position.lerp(target, 0.5) if a.global_position.distance_to(target) < 4.0 else target
		if avatars[i] is PartyAvatar:
			var av := avatars[i] as PartyAvatar
			av.rig.rotation.y = lerp_angle(av.rig.rotation.y, float(e[3]), 0.5)
			av.rig.locomote(float(e[4]), av.max_speed, true, 0.0, 0.05)
		else:
			a.rotation.y = lerp_angle(a.rotation.y, float(e[3]), 0.5)


func _return(placements: Array[int]) -> void:
	Game.last_results = {"game": game_id, "placements": placements, "scores": scores.duplicate(), "cat": category, "teams": teams.duplicate()}
	Game.last_results.merge(result_extra(), true)
	if not Game.players[0].cpu:
		EventBus.minigame_result.emit(placements)
	match Game.mode:
		"party":
			Router.goto("res://scenes/party/PartyBoard.tscn")
		"free_play":
			Router.goto("res://scenes/menu/MinigameSelect.tscn")
		"marathon":
			Router.goto("res://scenes/menu/MarathonHub.tscn")
		"modes":
			Router.goto("res://scenes/menu/MainMenu.tscn", {"page": "modes"})
		"journey":
			Router.goto("res://scenes/modes/Journey.tscn")
		"online":
			Net.back_to_lobby()
			Router.goto("res://scenes/menu/MainMenu.tscn", {"page": "online"})
		_:
			Router.goto("res://scenes/menu/MainMenu.tscn")


# --- HUD & Overlays -------------------------------------------------------------------------------

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	_hud_root = UI.center_root(hud)
	var corners := [Control.PRESET_TOP_LEFT, Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT]
	for i in 4:
		var b := PlayerBadge.new()
		b.setup(i, true, true)
		_hud_root.add_child(b)
		b.grow_horizontal = Control.GROW_DIRECTION_BEGIN if i % 2 == 1 else Control.GROW_DIRECTION_END
		b.grow_vertical = Control.GROW_DIRECTION_BEGIN if i >= 2 else Control.GROW_DIRECTION_END
		b.set_anchors_and_offsets_preset(corners[i], Control.PRESET_MODE_MINSIZE, 14)
		badges.append(b)
	timer_label = UI.label(str(int(time_limit)), 64, Color.WHITE, true, 12)
	timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.position = Vector2(-60, 12)
	timer_label.size = Vector2(120, 80)
	timer_label.visible = show_timer
	_hud_root.add_child(timer_label)
	_update_badges()


func _update_badges() -> void:
	for i in badges.size():
		badges[i].visible = active[i]
		if survival:
			badges[i].set_status("alive" if alive[i] else "out")
		else:
			badges[i].set_score(score_format % scores[i])


func _instructions() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var root := UI.center_root(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.12, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := UI.panel()
	root.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(760, 0)
	var v := UI.vbox(16)
	panel.add_child(v)
	var cat_l := UI.label(CATEGORY_LABELS.get(category, "").to_upper(), 26, UI.ACCENT2, true, 8)
	cat_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cat_l)
	var t := UI.label(info.get("name", game_id), 64, UI.GOLD, true, 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if is_team_game() or category == "duel":
		v.add_child(_team_lineup())
	var d := UI.label(info.get("desc", ""), 28)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.custom_minimum_size.x = 700
	v.add_child(d)
	var c := UI.label(info.get("controls", ""), 24, UI.ACCENT2)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(c)
	var go := UI.prompt("a", "Los geht's!", 30)
	v.add_child(go)
	await get_tree().process_frame
	panel.position = (root.size - panel.size) / 2.0
	Juice.pop_in(panel, 0.4)
	var has_human := false
	for i in 4:
		if not Game.players[i].cpu:
			has_human = true
	var wait := 0.0
	var limit := 8.0 if has_human else 2.0
	while wait < limit:
		await get_tree().process_frame
		wait += get_process_delta_time()
		if wait > 0.4 and (InputHub.any_human_pressed("a") or _touch_tap):
			break
		go.modulate.a = 0.6 + 0.4 * sin(wait * 5.0)
	_touch_tap = false
	Audio.sfx("ui_confirm")
	var tw := create_tween()
	tw.tween_property(panel, "scale", Vector2(0.01, 0.01), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(dim, "color:a", 0.0, 0.2)
	await tw.finished
	layer.queue_free()


var _touch_tap := false


## "Rot & Grün  VS  Blau & Gelb" mit Spielerfarben.
func _team_lineup() -> Control:
	var row := UI.hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var groups: Array = [[], []]
	for i in active_slots():
		(groups[0 if (category == "duel" and i == active_slots()[0]) or (category != "duel" and teams[i] == 0) else 1] as Array).append(i)
	for g in 2:
		var col := UI.vbox(2)
		for i in groups[g]:
			var l := UI.label(Game.hero(Game.players[i].hero).name, 26, Game.player_color(i).lightened(0.3), true, 6)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(l)
		row.add_child(col)
		if g == 0:
			row.add_child(UI.label("VS", 48, UI.GOLD, true, 10))
	return row


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed and state in ["intro", "results"]:
		_touch_tap = true
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and state in ["intro", "results"]:
		_touch_tap = true


func _show_results(placements: Array[int]) -> void:
	state = "results"
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var root := UI.center_root(layer)
	var panel := UI.panel()
	root.add_child(panel)
	panel.custom_minimum_size = Vector2(720, 0)
	var v := UI.vbox(12)
	panel.add_child(v)
	var t := UI.label("Ergebnis", 56, UI.GOLD, true, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var order: Array[int] = []
	for i in 4:
		if placements[i] > 0:
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return placements[a] < placements[b])
	if is_team_game():
		var win := -1
		for i in order:
			if placements[i] == 1:
				win = teams[i]
		var tl := UI.label("Unentschieden!" if win < 0 else ("Das Solo gewinnt!" if category == "1v3" and win == 0 else ("Das Dreier-Team gewinnt!" if category == "1v3" else "Team %s gewinnt!" % ["Blau", "Rot"][win])), 34, Color.WHITE, true, 8)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(tl)
	var rows: Array[Control] = []
	for p in order:
		var row := UI.hbox(16)
		var place := placements[p]
		var medal := TextureRect.new()
		medal.custom_minimum_size = Vector2(48, 48)
		medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if place <= 3:
			medal.texture = Assets.icon("medal_%d" % place)
		row.add_child(medal)
		var pl := UI.label("%d." % place, 40, UI.GOLD if place == 1 else Color.WHITE, true)
		pl.custom_minimum_size.x = 60
		row.add_child(pl)
		var nm := UI.label(Game.hero(Game.players[p].hero).name, 32, Game.player_color(p).lightened(0.3), true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		if not survival:
			row.add_child(UI.label(score_format % scores[p], 32, Color.WHITE, true))
		if Game.mode == "party" and category not in ["duel", "luck", "showdown"]:
			var reward: int = reward_for(place, category, scores[p])
			var rw := UI.hbox(4)
			rw.add_child(UIIcon.new("coin", 30))
			rw.add_child(UI.label("+%d" % reward, 32, Color("#7dff9a"), true))
			row.add_child(rw)
		row.modulate.a = 0.0
		v.add_child(row)
		rows.append(row)
	var go := UI.prompt("a", "Weiter", 28)
	v.add_child(go)
	await get_tree().process_frame
	panel.position = (root.size - panel.size) / 2.0
	Juice.pop_in(panel, 0.45)
	Audio.jingle("win")
	for i in range(rows.size() - 1, -1, -1):
		await get_tree().create_timer(0.18, false).timeout
		rows[i].modulate.a = 1.0
		Juice.ui_punch(rows[i], 0.15, 0.3)
		Audio.sfx("pluck", null, -4.0, 1.0 + (3 - i) * 0.1)
	var has_human := false
	for i in 4:
		if not Game.players[i].cpu:
			has_human = true
	var wait := 0.0
	_touch_tap = false
	while wait < (12.0 if has_human else 3.0):
		await get_tree().process_frame
		wait += get_process_delta_time()
		if wait > 0.6 and (InputHub.any_human_pressed("a") or _touch_tap):
			break
	Audio.sfx("ui_confirm")
