extends Node
## Audio-System: SFX-Pools (2D + 3D), Musik mit Crossfade, Ansager-Stimme, Jingles mit Ducking.

const AI := "res://assets/audio/kenney_impact-sounds/Audio/"
const AIF := "res://assets/audio/kenney_interface-sounds (1)/Audio/"
const AD := "res://assets/audio/kenney_digital-audio/Audio/"
const AJ := "res://assets/audio/kenney_music-jingles/Audio/"
const AR := "res://assets/audio/kenney_rpg-audio/Audio/"
const AS := "res://assets/audio/kenney_sci-fi-sounds/Audio/"
const AU := "res://assets/audio/kenney_ui-audio/Audio/"
const AV := "res://assets/audio/kenney_voiceover-pack/Female/"
const AVF := "res://assets/audio/kenney_voiceover-pack-fighter/Audio/"
const AX := "res://assets/sfx/"
const UL := "res://assets/sfx/ui_lolurio/"       # Cozy Game UI SFX – lolurio (CC BY 4.0)
const UN := "res://assets/sfx/ui_nomagician/"    # Cute, Cozy & Magical UI SFX – Nomagician Music (CC BY 4.0)
const AM := "res://assets/music/"

## Micro-Feedback-Bibliothek: Jede Bedienung hat einen knackigen, niedlichen Klang (Plopp, Glöckchen, Marimba).
const SFX := {
	# --- Oberfläche --------------------------------------------------------------------------------------
	"ui_hover": [UL + "menu_hover.ogg", UN + "magic_u2.ogg"],
	"ui_move": [UL + "menu_scroll.ogg", UN + "magic_u.ogg"],
	"ui_confirm": [UL + "menu_confirm.ogg", UN + "magic_h.ogg"],
	"ui_back": [UL + "menu_back.ogg", UN + "magic_i2.ogg"],
	"ui_open": [UL + "ingamemenu_open.ogg"],
	"ui_close": [UL + "ingamemenu_close.ogg"],
	"ui_error": [UL + "feedback_negative.ogg", UN + "magic_f.ogg"],
	"ui_toggle": [UN + "magic_a.ogg"],
	"ui_save": [UL + "ingamemenu_save.ogg"],
	"ui_load": [UL + "ingamemenu_load.ogg"],
	"ui_start": [UL + "extra_start_button.ogg"],
	"ui_select_big": [UN + "magic_k.ogg"],
	"tick": [AIF + "tick_001.ogg", AIF + "tick_002.ogg"],
	"click": [UN + "magic_h2.ogg", AU + "click3.ogg"],
	# --- Feedback ----------------------------------------------------------------------------------------
	"positive": [UL + "feedback_positive.ogg", UN + "magic_l.ogg"],
	"negative": [UL + "feedback_negative.ogg"],
	"alert": [UL + "feedback_alert.ogg"],
	"woop": [UL + "feedback_woop.ogg"],
	"woom": [UL + "feedback_woom.ogg"],
	"plop": [UN + "magic_h2.ogg", UN + "magic_j.ogg", UN + "magic_a.ogg"],
	"ding": [UN + "magic_s.ogg", UN + "magic_t.ogg"],
	"chime": [UN + "magic_p.ogg", UN + "magic_q.ogg", UN + "magic_c.ogg"],
	"sparkle_up": [UN + "magic_b.ogg", UN + "magic_e.ogg", UN + "magic_d.ogg"],
	"sparkle_down": [UN + "magic_r.ogg", UN + "magic_g.ogg"],
	"coin_chime": [UN + "magic_l.ogg", UN + "magic_d.ogg"],
	"coin_sad": [UN + "magic_v.ogg", UN + "magic_w.ogg"],
	"marimba": [UN + "magic_m.ogg", UN + "magic_n.ogg", UN + "magic_o.ogg"],
	"hop_marimba": [UL + "extra_marimba_hopping.ogg"],
	"hop_glock": [UL + "extra_glockenspiel_hopping.ogg"],
	"sigh": [UL + "extra_quick_sub_descending.ogg"],
	"dice_spin": [AIF + "scroll_002.ogg"],
	"dice_hit": [AI + "impactPlate_heavy_001.ogg"],
	"coin": [AR + "handleCoins.ogg", AR + "handleCoins2.ogg"],
	"coin_single": [AD + "pepSound2.ogg"],
	"coin_lose": [AD + "lowDown.ogg"],
	"star": [AD + "powerUp7.ogg"],
	"jump": [AD + "phaseJump1.ogg", AD + "phaseJump2.ogg"],
	"land": [AI + "impactSoft_medium_000.ogg", AI + "impactSoft_medium_001.ogg"],
	"step_stone": [AI + "footstep_concrete_000.ogg", AI + "footstep_concrete_001.ogg", AI + "footstep_concrete_002.ogg"],
	"step_wood": [AI + "footstep_wood_000.ogg", AI + "footstep_wood_001.ogg", AI + "footstep_wood_002.ogg"],
	"step_grass": [AI + "footstep_grass_000.ogg", AI + "footstep_grass_001.ogg", AI + "footstep_grass_002.ogg"],
	"step_sand": [AI + "footstep_snow_000.ogg", AI + "footstep_snow_001.ogg", AI + "footstep_snow_002.ogg"],
	"step_metal": [AI + "footstep_carpet_000.ogg", AI + "footstep_carpet_001.ogg"],
	"punch": [AI + "impactPunch_heavy_000.ogg", AI + "impactPunch_heavy_001.ogg", AI + "impactPunch_medium_000.ogg"],
	"hit_soft": [AI + "impactSoft_heavy_000.ogg", AI + "impactSoft_heavy_001.ogg"],
	"wood_hit": [AI + "impactWood_heavy_000.ogg", AI + "impactWood_heavy_001.ogg"],
	"plank_break": [AI + "impactPlank_medium_000.ogg", AI + "impactPlank_medium_001.ogg", AI + "impactPlank_medium_002.ogg"],
	"stone_hit": [AI + "impactMining_000.ogg", AI + "impactMining_001.ogg", AI + "impactMining_002.ogg"],
	"metal_hit": [AI + "impactMetal_heavy_000.ogg", AI + "impactMetal_heavy_001.ogg"],
	"metal_light": [AI + "impactMetal_light_000.ogg", AI + "impactMetal_light_001.ogg"],
	"bell": [AI + "impactBell_heavy_000.ogg"],
	"glass": [AI + "impactGlass_heavy_000.ogg"],
	"creak": [AR + "creak1.ogg", AR + "creak2.ogg", AR + "creak3.ogg"],
	"chest_open": [AR + "doorOpen_1.ogg", AR + "metalLatch.ogg"],
	"door": [AR + "doorClose_1.ogg"],
	"explosion": [AS + "explosionCrunch_000.ogg", AS + "explosionCrunch_001.ogg", AS + "explosionCrunch_002.ogg"],
	"explosion_big": [AS + "lowFrequency_explosion_000.ogg", AS + "lowFrequency_explosion_001.ogg"],
	"slime": [AS + "slime_000.ogg", AS + "slime_001.ogg"],
	"splash": [AS + "slime_001.ogg", AI + "impactSoft_heavy_002.ogg"],
	"forcefield": [AS + "forceField_000.ogg", AS + "forceField_001.ogg"],
	"thruster": [AS + "thrusterFire_000.ogg", AS + "thrusterFire_001.ogg"],
	"laser": [AS + "laserRetro_000.ogg", AS + "laserRetro_001.ogg"],
	"boost": [AD + "phaserUp3.ogg", AS + "thrusterFire_002.ogg"],
	"powerup": [AD + "powerUp2.ogg", AD + "powerUp5.ogg"],
	"item_roll": [AIF + "tick_004.ogg"],
	"item_get": [AD + "powerUp10.ogg"],
	"whoosh": [AD + "phaserDown1.ogg", AD + "phaserDown2.ogg"],
	"zap": [AD + "zap1.ogg", AD + "zap2.ogg"],
	"megaphone": [AD + "lowThreeTone.ogg"],
	"drift": [AIF + "scratch_001.ogg", AIF + "scratch_003.ogg"],
	"spark": [AD + "laser6.ogg"],
	"thunder": [AS + "lowFrequency_explosion_001.ogg"],
	"ghost": [AS + "forceField_003.ogg"],
	"wheel_tick": [AIF + "click_002.ogg"],
	"swap": [AD + "zapThreeToneUp.ogg"],
	"curse": [AD + "zapThreeToneDown.ogg"],
	"countdown": [AD + "tone1.ogg"],
	"go": [AD + "threeTone1.ogg"],
	"glitch": [AIF + "glitch_002.ogg"],
	"bong": [AIF + "bong_001.ogg"],
	"pluck": [AIF + "pluck_001.ogg", AIF + "pluck_002.ogg"],
	"drop": [AIF + "drop_002.ogg"],
	# Synthetische Cartoon-SFX (tools/compose_sfx.py)
	"evil_laugh": [AX + "evil_laugh.ogg"],
	"whistle_fall": [AX + "whistle_fall.ogg"],
	"whistle_up": [AX + "whistle_up.ogg"],
	"boing": [AX + "boing.ogg"],
	"drumroll": [AX + "drumroll.ogg"],
	"sad_trombone": [AX + "sad_trombone.ogg"],
	"pop": [AX + "pop.ogg"],
	"cannon": [AX + "cannon.ogg"],
	"crowd": [AX + "crowd_cheer.ogg"],
	# Motor-Loop (Racer)
	"engine": [AS + "engineCircular_000.ogg"],
}

const VOICE := {
	"ready": AV + "ready.ogg", "set": AV + "set.ogg", "go": AV + "go.ogg",
	"1": AV + "1.ogg", "2": AV + "2.ogg", "3": AV + "3.ogg",
	"congratulations": AV + "congratulations.ogg", "you_win": AV + "you_win.ogg", "you_lose": AV + "you_lose.ogg",
	"game_over": AV + "game_over.ogg", "final_round": AVF + "final_round.ogg", "hurry_up": AV + "hurry_up.ogg",
	"time_over": AV + "time_over.ogg", "winner": AVF + "winner.ogg", "tie": AVF + "it's_a_tie.ogg",
	"round_1": AVF + "round_1.ogg", "round_2": AVF + "round_2.ogg", "round_3": AVF + "round_3.ogg",
	"round_4": AVF + "round_4.ogg", "round_5": AVF + "round_5.ogg", "begin": AVF + "begin.ogg",
	"power_up": AV + "power_up.ogg", "correct": AV + "correct.ogg", "wrong": AV + "wrong.ogg",
	"new_highscore": AV + "new_highscore.ogg", "level_up": AV + "level_up.ogg",
}

const JINGLES := {
	"win": AJ + "Sax jingles/jingles_SAX03.ogg",
	"lose": AJ + "Pizzicato jingles/jingles_PIZZI07.ogg",
	"star": AJ + "Steel jingles/jingles_STEEL02.ogg",
	"event": AJ + "8-Bit jingles/jingles_NES05.ogg",
	"bad_event": AJ + "8-Bit jingles/jingles_NES11.ogg",
	"minigame_start": AJ + "Hit jingles/jingles_HIT02.ogg",
	"lucky": AJ + "Steel jingles/jingles_STEEL08.ogg",
	"round": AJ + "Hit jingles/jingles_HIT10.ogg",
	"finish": AJ + "Sax jingles/jingles_SAX10.ogg",
	"fanfare": AJ + "8-Bit jingles/jingles_NES14.ogg",
}

## Musik: Brett-/Menü-Themes (nahtlose Loops aus MusicMeta) plus Rennen und Siegerehrung.
const MUSIC := {
	"menu": AM + "board/menu.ogg", "board_dungeon": AM + "board/dungeon.ogg", "board_pirates": AM + "board/pirates.ogg",
	"board_sky": AM + "board/sky.ogg", "board_graveyard": AM + "board/graveyard.ogg", "board_frost": AM + "board/frost.ogg",
	"board_station": AM + "board/station.ogg", "board_glowforest": AM + "board/glowforest.ogg",
	"board_meadow": AM + "board/meadow.ogg", "board_cake": AM + "board/cake.ogg",
}
## Ausschließlich hochgeladene Soundtracks – keine prozedural erzeugte Hintergrundmusik.
## Rennen: Minispiel-Soundtrack (Normal → Hurry-Up in der letzten Runde → Outro), Siegerehrung: Hauptmenü-Theme.
const RACE_TRACK := 2
const ALIASES := {"podium": "menu", "race": ""}

## Beat-Uhr der laufenden Musik (für Rhythmus-Minispiele, Kamera-Pulse, Board-Effekte).
signal beat(n: int)
signal bar(n: int)
signal section_changed(section: String, bpm: float)

const POOL_2D := 20
const POOL_3D := 16

var _cache := {}
var _pool2d: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current := ""
# --- Musik-Direktor ---
var _mp: Array[AudioStreamPlayer] = []
var _gain: Array[float] = [0.0, 0.0]
var _gain_tw: Array = [null, null]
var _duck_db := 0.0
var _active := 0
var bpm := 0.0                 # Tempo des aktuell hörbaren Abschnitts
var section := ""              # "", "board", "normal", "hurry", "outro"
var mg_track := -1             # 0..3 = Minispiel-Soundtrack 1..4
var _beat := 0.0               # Schläge seit Abschnittsbeginn (phasengenau, inkl. Tempo-Rampe)
var _last_beat_i := -1
var _sched: Dictionary = {}    # geplanter Wechsel {"at": beat, "section": String, "fade": float}
var _ramp_from := 1.0
var _ramp_to := 1.0
var _ramp_beats := 0.0
var _ramp_start := 0.0
var _voice: AudioStreamPlayer
var _jingle: AudioStreamPlayer
var _duck_tween: Tween
var _last_play := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool2d.append(p)
	for i in POOL_3D:
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = "SFX"
		p3.unit_size = 8.0
		p3.max_distance = 80.0
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p3)
		_pool3d.append(p3)
	_music_a = _mk_player("Music")
	_music_b = _mk_player("Music")
	_mp = [_music_a, _music_b]
	if OS.has_feature("web"):
		# Musik im Web als STREAM (stückweise dekodiert) statt als Sample. Im Sample-Modus dekodiert Godot 4.7
		# jedes Stück beim ersten Abspielen komplett (⌀ 32 MB PCM im Browser + kurz das Doppelte im WASM-Heap)
		# und gibt es nie wieder frei (unregister_stream_as_sample wird von der Engine nirgends aufgerufen).
		# Jedes Minispiel bringt drei eigene Stücke mit → nach 3–5 Runden mehrere hundert MB, bis der Browser
		# den Tab beendet und neu lädt („zurück zu Tippen zum Starten“). Kurze Effekte bleiben Samples.
		for mp in _mp:
			mp.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	_voice = _mk_player("Voice")
	_jingle = _mk_player("Music")
	apply_volumes()
	EventBus.settings_changed.connect(apply_volumes)
	get_tree().create_timer(2.0).timeout.connect(_start_prefetch)


func _mk_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _setup_buses() -> void:
	for bus_name in ["Music", "SFX", "Voice"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func apply_volumes() -> void:
	var s: Dictionary = Game.settings
	_set_bus("Music", s.music)
	_set_bus("SFX", s.sfx)
	_set_bus("Voice", s.voice)


func _set_bus(bus_name: String, lin: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(lin, 0.0001)))
		AudioServer.set_bus_mute(idx, lin <= 0.001)


func _stream(path: String) -> AudioStream:
	if not _cache.has(path):
		if _is_web_music(path):
			_fetch_music(path, true)
			return null   # kommt per Download nach (siehe _play_path)
		_cache[path] = load(path)
	return _cache[path]


# --- Web: Musik nicht im Start-Paket -------------------------------------------------------------------------
# Im Web-Export liegen die Songs NICHT in index.pck (≈ 30 MB weniger Erst-Download), sondern als einzelne
# Dateien unter music/… neben dem Spiel. Gebraucht → sofort geladen; alle übrigen werden nach dem Start
# nacheinander im Hintergrund vorgeladen (Menü zuerst, dann Minispiel-Tracks, dann Bretter).
signal music_loaded(path: String)

var _web_base := ""
var _fetching := {}
var _prefetch: Array[String] = []
var _deferred := {}


func _is_web_music(path: String) -> bool:
	return OS.has_feature("web") and path.begins_with("res://assets/music/") and not ResourceLoader.exists(path)


func _music_url(path: String) -> String:
	if _web_base == "":
		_web_base = str(JavaScriptBridge.eval("location.href.split('#')[0].split('?')[0].replace(/[^/]*$/, '')", true))
	return _web_base + "music/" + path.trim_prefix("res://assets/music/")


func _fetch_music(path: String, urgent := false) -> void:
	if _cache.has(path) or _fetching.has(path):
		return
	if not urgent and not _fetching.is_empty():
		return   # Vorladen strikt nacheinander – drängelt nie vor einen gerade gebrauchten Song
	_fetching[path] = true
	var req := HTTPRequest.new()
	req.timeout = 60.0
	add_child(req)
	var ok := false
	for attempt in 3:
		if req.request(_music_url(path)) != OK:
			break
		var r: Array = await req.request_completed
		if int(r[0]) == HTTPRequest.RESULT_SUCCESS and int(r[1]) == 200:
			var st := AudioStreamOggVorbis.load_from_buffer(r[3])
			if st:
				_cache[path] = st
				ok = true
				break
		await get_tree().create_timer(1.0 + attempt).timeout
	req.queue_free()
	_fetching.erase(path)
	if not ok:
		push_warning("[Audio] Musik nicht ladbar: " + path)
	else:
		music_loaded.emit(path)
		if String(_deferred.get("path", "")) == path and String(_deferred.get("key", "")) == _music_current:
			var d := _deferred
			_deferred = {}
			_crossfade_to(_cache[path], float(d.fade), bool(d.loop), float(d.from))
	_prefetch_next()


func _start_prefetch() -> void:
	if not OS.has_feature("web"):
		return
	_prefetch.clear()
	_prefetch.append(MUSIC.get("menu", ""))
	for t in MusicMeta.MINIGAME:
		for sec in ["normal", "hurry", "outro"]:
			_prefetch.append(String(t[sec].file))
	for p in MUSIC.values():
		_prefetch.append(String(p))
	_prefetch_next()


func _prefetch_next() -> void:
	while not _prefetch.is_empty():
		var p: String = _prefetch.pop_front()
		if p != "" and _is_web_music(p) and not _cache.has(p) and not _fetching.has(p):
			_fetch_music(p)
			return


## Spielt einen Song ab; fehlt er im Web noch, wird er geladen und startet, sobald er da ist
## (vorher ausblenden, damit die Beat-Uhr nicht mit einem falschen Song läuft).
func _play_path(path: String, fade: float, loop: bool, from_pos := 0.0) -> void:
	var st := _stream(path)
	if st:
		_deferred = {}
		_crossfade_to(st, fade, loop, from_pos)
		return
	_deferred = {"path": path, "key": _music_current, "fade": fade, "loop": loop, "from": from_pos}
	_fade_out_all(minf(fade, 0.4))


func _pick(id: String) -> AudioStream:
	var list: Array = SFX.get(id, [])
	if list.is_empty():
		return null
	return _stream(list[randi() % list.size()])


## Münz-Zählkaskade wie auf der Konsole: pro Münze ein Plink mit steigender Tonhöhe, bei Verlust Seufzer.
func coin_cascade(amount: int, pos: Variant = null) -> void:
	if amount > 0:
		sfx("coin_chime", null, -6.0, 1.0, 0.0)
		for k in mini(amount, 12):
			get_tree().create_timer(0.05 * k).timeout.connect(func() -> void:
				_last_play.erase("coin_single")
				sfx("coin_single", pos, -8.0, 1.0 + k * 0.045, 0.0))
	elif amount < 0:
		sfx("coin_sad", null, -4.0, 1.0, 0.0)
		sfx("woom", null, -8.0, 1.0, 0.0)


## Spielt einen Effekt. Mit pos != null als 3D-Sound.
func sfx(id: String, pos: Variant = null, vol_db := 0.0, pitch := 1.0, pitch_var := 0.08) -> void:
	# Spam-Schutz: identische Sounds max. alle 35 ms
	var now := Time.get_ticks_msec()
	if _last_play.get(id, -1000) > now - 35:
		return
	_last_play[id] = now
	var st := _pick(id)
	if st == null:
		return
	var pv := pitch * randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	if pos is Vector3:
		var p3 := _free3d()
		p3.stream = st
		p3.global_position = pos
		p3.volume_db = vol_db
		p3.pitch_scale = pv
		p3.play()
	else:
		var p := _free2d()
		p.stream = st
		p.volume_db = vol_db
		p.pitch_scale = pv
		p.play()


func _free2d() -> AudioStreamPlayer:
	for p in _pool2d:
		if not p.playing:
			return p
	return _pool2d[randi() % _pool2d.size()]


func _free3d() -> AudioStreamPlayer3D:
	for p in _pool3d:
		if not p.playing:
			return p
	return _pool3d[randi() % _pool3d.size()]


## Erzeugt einen dauerhaften (loopenden) 3D-Sound, z. B. Kart-Motor.
func make_loop(id: String, parent: Node3D, vol_db := -6.0) -> AudioStreamPlayer3D:
	var st := _pick(id)
	var p := AudioStreamPlayer3D.new()
	p.bus = "SFX"
	p.unit_size = 6.0
	p.max_distance = 60.0
	p.volume_db = vol_db
	if st is AudioStreamOggVorbis:
		st = st.duplicate()
		(st as AudioStreamOggVorbis).loop = true
	p.stream = st
	parent.add_child(p)
	p.play()
	return p


func voice(id: String) -> void:
	if not VOICE.has(id):
		return
	_voice.stream = _stream(VOICE[id])
	_voice.play()


func jingle(id: String, duck := true) -> void:
	if not JINGLES.has(id):
		return
	_jingle.stream = _stream(JINGLES[id])
	_jingle.play()
	if duck:
		_duck(-14.0, _jingle.stream.get_length())


func _duck(db: float, hold: float) -> void:
	if _duck_tween:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_property(self, "_duck_db", db, 0.15)
	_duck_tween.tween_interval(maxf(hold - 0.3, 0.1))
	_duck_tween.tween_property(self, "_duck_db", 0.0, 0.5)


func music(id: String, fade := 1.0) -> void:
	if id == "minigame":
		minigame_music(-1)
		return
	if id == "race":
		if _music_current != "minigame_%d" % RACE_TRACK or section == "outro":
			minigame_music(RACE_TRACK, fade)
		return
	id = String(ALIASES.get(id, id))
	if id == _music_current and section == "board":
		return
	_music_current = id
	_sched.clear()
	mg_track = -1
	if id == "" or not MUSIC.has(id):
		_fade_out_all(fade)
		section = ""
		bpm = 0.0
		return
	var meta: Dictionary = MusicMeta.BOARDS.get(id, {})
	_play_path(MUSIC[id], fade, true)
	_set_section("board", float(meta.get("bpm", 120.0)))


## Minispiel-Soundtrack (0..3, -1 = automatisch rotierend) im Normal-Abschnitt starten.
func minigame_music(track := -1, fade := 0.35, sect := "normal", from_pos := 0.0) -> void:
	if track < 0:
		track = _next_track
		_next_track = (_next_track + 1) % MusicMeta.MINIGAME.size()
	mg_track = clampi(track, 0, MusicMeta.MINIGAME.size() - 1)
	_music_current = "minigame_%d" % mg_track
	_sched.clear()
	var sec: Dictionary = MusicMeta.MINIGAME[mg_track][sect]
	_play_path(String(sec.file), fade, sect != "outro", maxf(0.0, from_pos))
	_set_section(sect, float(sec.bpm))
	_beat = maxf(0.0, from_pos) * float(sec.bpm) / 60.0 - _latency_beats(float(sec.bpm))


## BPM eines Abschnitts (ohne ihn abzuspielen) – z. B. um ein Notenblatt vorab zu bauen.
## Im Web läuft Musik als Stream über den Ausgabepuffer: hörbar erst nach der Ausgabelatenz. Die Beat-Uhr
## startet um genau so viel später, damit Rhythmus-Spiele und Takt-Effekte synchron zum Ton bleiben.
func _latency_beats(b: float) -> float:
	if not OS.has_feature("web"):
		return 0.0
	return clampf(AudioServer.get_output_latency(), 0.0, 0.25) * b / 60.0


## Vor einem Szenenwechsel (Web): Musik kurz ausblenden. Der Stream wird auf dem Hauptthread nachgemischt;
## während die nächste Szene lädt, stünde er sonst still und würde knacksen. Die neue Szene startet ihre Musik selbst.
func fade_for_load(fade := 0.3) -> void:
	if OS.has_feature("web"):
		_fade_out_all(fade)


static func track_bpm(track: int, sect := "normal") -> float:
	return float(MusicMeta.MINIGAME[clampi(track, 0, MusicMeta.MINIGAME.size() - 1)][sect].bpm)


## Zeitpunkte (Sekunden ab jetzt) der kommenden Schläge innerhalb von "horizon" – berücksichtigt einen
## geplanten Hurry-Wechsel samt Tempo-Rampe. Rhythmus-Spiele setzen ihre Noten exakt darauf.
func upcoming_beats(horizon: float) -> Array[float]:
	var out: Array[float] = []
	var cur := music_bpm()
	var pitch := _mp[_active].pitch_scale if not _mp.is_empty() else 1.0
	var b := ceilf(_beat - 0.0001)
	var t := (b - _beat) * 60.0 / cur / maxf(pitch, 0.01)
	var switch_at := INF
	var new_bpm := cur
	if _sched.has("section") and String(_sched.section) == "hurry" and mg_track >= 0:
		switch_at = float(_sched.at)
		new_bpm = float(MusicMeta.MINIGAME[mg_track].hurry.bpm)
	var guard := 0
	while t < horizon and guard < 256:
		guard += 1
		out.append(t)
		var p := 1.0
		if b >= switch_at:
			cur = new_bpm
		elif switch_at < INF and b >= _ramp_start and _ramp_beats > 0.0:
			var k := clampf((b - _ramp_start) / _ramp_beats, 0.0, 1.0)
			p = lerpf(_ramp_from, _ramp_to, k * k)
		elif switch_at == INF:
			p = pitch
		t += 60.0 / cur / maxf(p, 0.01)
		b += 1.0
	return out


var _next_track := 0


## Hurry-Up: Takt-synchroner Wechsel in den schnelleren Abschnitt. Im letzten Takt davor zieht das Tempo
## sanft an (kleine Rampe), am nächsten Taktanfang wird phasengenau in die Hurry-Version überblendet.
func minigame_hurry() -> void:
	if mg_track < 0 or section != "normal" or _sched.has("section"):
		return
	var b_next := ceilf((_beat + 0.35) / 4.0) * 4.0
	if b_next - _beat < 2.0:
		b_next += 4.0   # mindestens zwei Schläge Anlauf für die Tempo-Rampe
	var target: float = MusicMeta.MINIGAME[mg_track].hurry.bpm
	_ramp_from = 1.0
	_ramp_to = clampf(lerpf(1.0, target / maxf(bpm, 1.0), 0.35), 1.0, 1.08)
	_ramp_start = b_next - 4.0 if b_next - 4.0 > _beat else _beat
	_ramp_beats = b_next - _ramp_start
	_sched = {"at": b_next, "section": "hurry", "fade": 0.18}


## Outro: am nächsten Schlag in den Schluss-Abschnitt (spielt einmal und klingt aus).
func minigame_outro() -> void:
	if mg_track < 0 or section == "outro":
		return
	_sched = {"at": floorf(_beat) + 1.0, "section": "outro", "fade": 0.12}


## Tempo (BPM) und Schlag-Position der laufenden Musik.
func music_bpm() -> float:
	return bpm if bpm > 0.0 else 120.0


func music_beat() -> float:
	return _beat


## Sekunden bis zum nächsten Schlag (für exakte Rhythmus-Vorhersage).
func time_to_next_beat() -> float:
	return (ceilf(_beat) - _beat) * 60.0 / music_bpm() / maxf(_mp[_active].pitch_scale, 0.01)


func _set_section(sec: String, new_bpm: float) -> void:
	section = sec
	bpm = new_bpm
	_beat = 0.0
	_last_beat_i = -1
	section_changed.emit(sec, new_bpm)


func _crossfade_to(st: AudioStream, fade: float, loop: bool, from_pos := 0.0) -> void:
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = loop
	elif st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = loop
	var old := _active
	var nxt := 1 - _active
	_active = nxt
	var to := _mp[nxt]
	to.stream = st
	to.pitch_scale = 1.0
	_gain[nxt] = 0.0
	to.play(from_pos)
	_tween_gain(nxt, 1.0, maxf(fade * 0.6, 0.03))
	if _mp[old].playing:
		_tween_gain(old, 0.0, maxf(fade, 0.05), true)


func _tween_gain(i: int, to: float, dur: float, stop_after := false) -> void:
	if _gain_tw[i] and (_gain_tw[i] as Tween).is_valid():
		(_gain_tw[i] as Tween).kill()
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _gain[i] = v, _gain[i], to, dur)
	if stop_after:
		var pl := _mp[i]
		tw.tween_callback(func() -> void:
			if _active != i:
				pl.stop())
	_gain_tw[i] = tw


func _fade_out_all(fade: float) -> void:
	for i in 2:
		if _mp[i].playing:
			_tween_gain(i, 0.0, fade, true)
	_active = 1 - _active


func _process(delta: float) -> void:
	if _mp.is_empty():
		return
	for i in 2:
		_mp[i].volume_db = linear_to_db(maxf(_gain[i], 0.0001)) + _duck_db
	if bpm <= 0.0 or not _mp[_active].playing:
		return
	var pl := _mp[_active]
	# Tempo-Rampe vor dem Hurry-Wechsel
	if _sched.has("section") and _sched.section == "hurry" and _beat >= _ramp_start and _ramp_beats > 0.0:
		var k := clampf((_beat - _ramp_start) / _ramp_beats, 0.0, 1.0)
		pl.pitch_scale = lerpf(_ramp_from, _ramp_to, k * k)
	_beat += delta * bpm / 60.0 * pl.pitch_scale
	var bi := int(floor(_beat))
	if bi != _last_beat_i:
		_last_beat_i = bi
		beat.emit(bi)
		if bi % 4 == 0:
			bar.emit(bi / 4)
	if _sched.has("section") and _beat >= float(_sched.at):
		var late := (_beat - float(_sched.at)) * 60.0 / bpm / maxf(pl.pitch_scale, 0.01)
		var nsec := String(_sched.section)
		var fade := float(_sched.fade)
		_sched.clear()
		var data: Dictionary = MusicMeta.MINIGAME[mg_track][nsec]
		# Spät um "late" Sekunden? Dann genauso weit in den neuen Abschnitt springen – Phase bleibt exakt.
		_play_path(String(data.file), fade, nsec != "outro", clampf(late, 0.0, 0.25))
		_set_section(nsec, float(data.bpm))
		_beat = late * float(data.bpm) / 60.0 - _latency_beats(float(data.bpm))


func set_music_pitch(p: float) -> void:
	for m in _mp:
		m.pitch_scale = p


func all_paths() -> PackedStringArray:
	var out := PackedStringArray()
	for list in SFX.values():
		for p in list:
			out.append(p)
	for p in VOICE.values():
		out.append(p)
	for p in JINGLES.values():
		out.append(p)
	for p in MUSIC.values():
		out.append(p)
	for t in MusicMeta.MINIGAME:
		for sec in ["normal", "hurry", "outro"]:
			out.append(String(t[sec].file))
	return out
