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
const AM := "res://assets/music/"

const SFX := {
	"ui_move": [AIF + "select_001.ogg", AIF + "select_002.ogg"],
	"ui_confirm": [AIF + "confirmation_001.ogg"],
	"ui_back": [AIF + "back_001.ogg"],
	"ui_open": [AIF + "maximize_003.ogg"],
	"ui_error": [AIF + "error_004.ogg"],
	"ui_toggle": [AIF + "toggle_002.ogg"],
	"tick": [AIF + "tick_001.ogg", AIF + "tick_002.ogg"],
	"click": [AU + "click3.ogg"],
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

const MUSIC := {
	"menu": AM + "menu_theme.ogg", "board_dungeon": AM + "board_dungeon.ogg", "board_pirates": AM + "board_pirates.ogg",
	"board_sky": AM + "board_sky.ogg", "minigame": AM + "minigame.ogg", "race": AM + "race.ogg", "podium": AM + "podium.ogg",
}

const POOL_2D := 20
const POOL_3D := 16

var _cache := {}
var _pool2d: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current := ""
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
	_voice = _mk_player("Voice")
	_jingle = _mk_player("Music")
	apply_volumes()
	EventBus.settings_changed.connect(apply_volumes)


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
		_cache[path] = load(path)
	return _cache[path]


func _pick(id: String) -> AudioStream:
	var list: Array = SFX.get(id, [])
	if list.is_empty():
		return null
	return _stream(list[randi() % list.size()])


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
	for m in [_music_a, _music_b]:
		if m.playing:
			_duck_tween.parallel().tween_property(m, "volume_db", db, 0.15)
	_duck_tween.tween_interval(maxf(hold - 0.3, 0.1))
	for m in [_music_a, _music_b]:
		if m.playing and m.stream:
			_duck_tween.parallel().tween_property(m, "volume_db", 0.0, 0.6)


func music(id: String, fade := 1.0) -> void:
	if id == _music_current:
		return
	_music_current = id
	var from := _music_a if _music_a.playing else _music_b
	var to := _music_b if from == _music_a else _music_a
	if id == "" or not MUSIC.has(id):
		var tw0 := create_tween()
		tw0.tween_property(from, "volume_db", -60.0, fade)
		tw0.tween_callback(from.stop)
		return
	var st: AudioStream = _stream(MUSIC[id])
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	to.stream = st
	to.volume_db = -40.0
	to.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(to, "volume_db", 0.0, fade)
	if from.playing:
		tw.tween_property(from, "volume_db", -60.0, fade)
		tw.chain().tween_callback(from.stop)


func set_music_pitch(p: float) -> void:
	for m in [_music_a, _music_b]:
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
	return out
