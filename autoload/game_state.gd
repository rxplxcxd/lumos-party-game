extends Node
## Globaler Spielzustand: Spieler, Einstellungen, Party-Fortschritt, Racer-Konfiguration.
## Bleibt über Szenenwechsel erhalten (Brett -> Minispiel -> Brett).

const HEROES := [
	{"id": "knight", "name": "Ritter Rudi", "model": "hero/knight", "accent": Color("#c9d6ff")},
	{"id": "barbarian", "name": "Barbara Bärenstark", "model": "hero/barbarian", "accent": Color("#ffb37a")},
	{"id": "mage", "name": "Magierin Mimi", "model": "hero/mage", "accent": Color("#c79bff")},
	{"id": "ranger", "name": "Waldläufer Wanja", "model": "hero/ranger", "accent": Color("#9be37a")},
	{"id": "rogue", "name": "Schurkin Sina", "model": "hero/rogue", "accent": Color("#ff8fa3")},
	{"id": "rogue_hooded", "name": "Kapuzen-Kalle", "model": "hero/rogue_hooded", "accent": Color("#7fd6ff")},
]
const SLOT_COLORS := [Color("#ff4d6d"), Color("#3fa7ff"), Color("#4cd964"), Color("#ffcc00")]
const SLOT_NAMES := ["Rot", "Blau", "Grün", "Gelb"]
const CPU_LEVELS := ["Leicht", "Normal", "Profi"]

const BOARDS := [
	{"id": "dungeon", "name": "Dungeon Deep", "desc": "Fackeln, Fallen und ein Lavasee mit fahrender Plattform. Skelette bewachen das Tor.", "music": "board_dungeon"},
	{"id": "pirates", "name": "Pirates Cove", "desc": "Sonnige Bucht mit Planken-Katapulten, Schiffen und einem gierigen Händler.", "music": "board_pirates"},
	{"id": "sky", "name": "Sky Kingdom", "desc": "Schwebende Inseln, eine Zugbrücke, die sich jede Runde dreht, und Wolken-Kanonen.", "music": "board_sky"},
]

const MINIGAMES := [
	{"id": "plank_panic", "name": "Plank-Panic", "scene": "res://scenes/minigames/PlankPanic.tscn", "kind": "survival",
		"desc": "Die morsche Planke über dem Haifischbecken bricht Stück für Stück. Schubse die anderen ins Wasser!",
		"controls": "Stick: Laufen · A: Springen · B: Schubsen"},
	{"id": "dungeon_drop", "name": "Dungeon Drop", "scene": "res://scenes/minigames/DungeonDrop.tscn", "kind": "survival",
		"desc": "Steinplatten brechen 1,5 Sekunden nach dem Betreten ein. Bleib in Bewegung oder fall in die Lava!",
		"controls": "Stick: Laufen · A: Springen · B: Schubsen"},
	{"id": "kart_bowling", "name": "Kart-Bowling", "scene": "res://scenes/minigames/KartBowling.tscn", "kind": "survival",
		"desc": "Riesige Dungeon-Felsen rollen durch die Arena. Weiche aus und rempel Gegner mit Turbo in die Bahn!",
		"controls": "Stick: Lenken · A: Gas · B: Turbo-Rempler"},
	{"id": "treasure_zipline", "name": "Schatz-Seilbahn", "scene": "res://scenes/minigames/TreasureZipline.tscn", "kind": "score",
		"desc": "Sause an der Seilbahn über die Schlucht. Spring im richtigen Moment ab, um Schatzkisten zu schnappen!",
		"controls": "A: Absprung / Greifen · Stick: Seil wechseln"},
	{"id": "ghost_castle", "name": "Geister-Schloss Schwindel", "scene": "res://scenes/minigames/GhostCastle.tscn", "kind": "race",
		"desc": "Stockfinster! Nur die Blitze zeigen kurz den sicheren Weg durchs Geisterschloss. Merk ihn dir!",
		"controls": "Stick: Laufen · A: Springen"},
	{"id": "barrel_chaos", "name": "Fässer-Chaos", "scene": "res://scenes/minigames/BarrelChaos.tscn", "kind": "score",
		"desc": "Der Kapitän versteckt den Schatz in einem tanzenden Fass. Folge ihm mit den Augen und spring ins richtige!",
		"controls": "Stick: Laufen · A: Ins Fass springen"},
	{"id": "lava_surf", "name": "Lavastrom-Surfen", "scene": "res://scenes/minigames/LavaSurf.tscn", "kind": "score",
		"desc": "Surfe auf deinem Floß den Lavastrom hinab, sammle Edelsteine und boxe Gegner vom Floß!",
		"controls": "Stick: Steuern · B: Boxhandschuh · A: Hüpfen"},
	{"id": "tower_balance", "name": "Turm-Balancieren", "scene": "res://scenes/minigames/TowerBalance.tscn", "kind": "score",
		"desc": "Staple wackelige Dungeon-Blöcke zum höchsten Turm – aber der Wind dreht ständig!",
		"controls": "A: Block fallen lassen"},
	{"id": "hot_bomb", "name": "Bomben-Heißer-Hut", "scene": "res://scenes/minigames/HotBomb.tscn", "kind": "survival",
		"desc": "Die Kanonenkugel tickt! Wirf sie schnell weiter – wer sie beim Knall hält, fliegt spektakulär in die Luft.",
		"controls": "Stick: Laufen/Zielen · B: Werfen"},
	{"id": "slime_sprint", "name": "Schleim-Spur Sprint", "scene": "res://scenes/minigames/SlimeSprint.tscn", "kind": "race",
		"desc": "Sprinte durch den Parcours! Schleimpfützen sind glitschig und Pendel-Fallen schwingen gnadenlos.",
		"controls": "Stick: Laufen · A: Springen"},
	{"id": "coin_rain", "name": "Münzregen", "scene": "res://scenes/minigames/CoinRain.tscn", "kind": "score",
		"desc": "Münzen, Sterne – und Bomben regnen vom Himmel! Schnapp dir die meisten Münzen und schubse Gegner, damit sie welche verlieren.",
		"controls": "Stick: Laufen · A: Springen · B: Schubsen"},
	{"id": "sumo_shove", "name": "Sumo-Schubser", "scene": "res://scenes/minigames/SumoShove.tscn", "kind": "survival",
		"desc": "Die runde Plattform über dem Meer schrumpft! Doppelt starke Schubser – wer zuletzt oben steht, gewinnt.",
		"controls": "Stick: Laufen · A: Springen · B: Super-Schubser"},
	{"id": "snowball_fight", "name": "Schneeball-Schlacht", "scene": "res://scenes/minigames/SnowballFight.tscn", "kind": "score",
		"desc": "Verschanz dich hinter Schneemännern und triff die anderen! Am Schneehaufen lädt Munition schneller nach.",
		"controls": "Stick: Laufen · A: Springen · B: Werfen"},
	{"id": "color_chaos", "name": "Farb-Chaos", "scene": "res://scenes/minigames/ColorChaos.tscn", "kind": "score",
		"desc": "Jedes Feld, über das du läufst, wird in deiner Farbe eingefärbt. Farbbomben färben ganze Bereiche!",
		"controls": "Stick: Laufen · A: Springen · B: Schubsen (betäubt)"},
	{"id": "hammer_hop", "name": "Hammer-Hüpfen", "scene": "res://scenes/minigames/HammerHop.tscn", "kind": "survival",
		"desc": "Ein Riesenhammer kreist über den Turm – spring rechtzeitig! Später kommt ein hoher Balken dazu: darunter bloß nicht springen.",
		"controls": "Stick: Laufen · A: Springen · B: Schubsen"},
	{"id": "fish_catch", "name": "Fischfang", "scene": "res://scenes/minigames/FishCatch.tscn", "kind": "score",
		"desc": "Steuere deinen Schwimmer zu den Fisch-Schatten. Taucht er ab, sofort A! Goldfische bringen 6 Punkte – Stiefel nichts.",
		"controls": "Stick: Schwimmer bewegen · A: Anschlagen"},
	{"id": "meteor_dodge", "name": "Meteor-Ausweichen", "scene": "res://scenes/minigames/MeteorDodge.tscn", "kind": "survival",
		"desc": "Auf dem Mond regnen Meteore! Rote Kreise zeigen den Einschlag – und manche zielen direkt auf dich.",
		"controls": "Stick: Laufen · A: Springen · B: Schubsen"},
	{"id": "rhythm_dance", "name": "Rhythmus-Tanz", "scene": "res://scenes/minigames/RhythmDance.tscn", "kind": "score",
		"desc": "Schnipp den Stick genau im Takt in Pfeilrichtung oder drück A! PERFEKT gibt 3 Punkte, Serien geben Bonus.",
		"controls": "Stick: Richtung schnippen · A: A-Note"},
	{"id": "minigolf_duel", "name": "Minigolf-Duell", "scene": "res://scenes/minigames/MinigolfDuel.tscn", "kind": "score",
		"desc": "Alle putten gleichzeitig! Wer zuerst einlocht, kassiert 4 Punkte. Pilz-Bumper schleudern Bälle quer über die Bahn.",
		"controls": "Stick: Zielen · A halten: Kraft laden · loslassen: Schlag"},
	{"id": "balloon_battle", "name": "Ballon-Kart-Battle", "scene": "res://scenes/minigames/BalloonBattle.tscn", "kind": "survival",
		"desc": "Platze die Ballons der anderen per Turbo-Rempler und klau sie dir! Item-Boxen geben Torten-Kanonen.",
		"controls": "Stick: Lenken · A: Gas · B: Turbo-Rempler · X: Torte"},
]

const TRACKS := [
	{"id": "lumos_ring", "name": "Lumos-Ring", "desc": "Sonniger Grand-Prix-Kurs mit Looping und Gleiter-Schlucht.", "music": "race"},
	{"id": "coral_canal", "name": "Korallen-Kanal", "desc": "Piratenbucht mit gläsernem Unterwasser-Tunnel.", "music": "race"},
	{"id": "neon_volcano", "name": "Neon-Vulkan", "desc": "Nachtrennen über Lavaseen – Looping, Gleiter und Neonlicht.", "music": "race"},
]

const SETTINGS_PATH := "user://settings.cfg"

var players: Array[Dictionary] = []
var settings := {
	"music": 0.7, "sfx": 0.9, "voice": 1.0,
	"haptics": true, "touch_opacity": 0.8, "touch_scale": 1.0, "touch_layout": {},
	"auto_accel": true, "screen_shake": 1.0, "quality": "auto", "show_fps": false, "dynamic_res": true,
}
var party: Dictionary = {}
var race_cfg := {"track": "lumos_ring", "laps": 3, "cpu_level": 1}
var mode := "menu"          # menu | party | free_play | race
var pending_minigame := ""
var last_results: Dictionary = {}
var free_play_queue: Array = []
var is_touch_device := false
var is_lumos_device := false


func _ready() -> void:
	load_settings()
	reset_players()
	is_touch_device = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func reset_players(human_count := 1) -> void:
	players.clear()
	var hero_order := ["knight", "mage", "barbarian", "rogue"]
	for i in 4:
		players.append(new_player(i, hero_order[i], i >= human_count, 1))


func new_player(idx: int, hero_id: String, cpu: bool, cpu_level: int) -> Dictionary:
	return {
		"idx": idx, "hero": hero_id, "name": hero(hero_id).name, "color": SLOT_COLORS[idx],
		"cpu": cpu, "cpu_level": cpu_level, "device": idx,
		"coins": 10, "stars": 0, "space": -1, "items": [], "minigame_wins": 0, "coins_max": 10,
		"swaps": 0, "last_roll": 0,
	}


func hero(id: String) -> Dictionary:
	for h in HEROES:
		if h.id == id:
			return h
	return HEROES[0]


func minigame_info(id: String) -> Dictionary:
	for m in MINIGAMES:
		if m.id == id:
			return m
	return {}


func board_info(id: String) -> Dictionary:
	for b in BOARDS:
		if b.id == id:
			return b
	return BOARDS[0]


func track_info(id: String) -> Dictionary:
	for t in TRACKS:
		if t.id == id:
			return t
	return TRACKS[0]


func is_cpu(i: int) -> bool:
	return players[i].cpu


func player_color(i: int) -> Color:
	return players[i].color


func add_coins(i: int, delta: int) -> int:
	var p: Dictionary = players[i]
	var before: int = p.coins
	p.coins = maxi(0, before + delta)
	p.coins_max = maxi(p.coins_max, p.coins)
	var real := int(p.coins) - before
	EventBus.coins_changed.emit(i, p.coins, real)
	return real


func add_stars(i: int, delta: int) -> void:
	var p: Dictionary = players[i]
	p.stars = maxi(0, int(p.stars) + delta)
	EventBus.stars_changed.emit(i, p.stars, delta)


## Rangliste (Sterne, dann Münzen). Gibt Spielerindizes in Platzierungsreihenfolge zurück.
func ranking() -> Array[int]:
	var idx: Array[int] = [0, 1, 2, 3]
	idx.sort_custom(func(a: int, b: int) -> bool:
		var pa: Dictionary = players[a]
		var pb: Dictionary = players[b]
		if pa.stars != pb.stars:
			return pa.stars > pb.stars
		if pa.coins != pb.coins:
			return pa.coins > pb.coins
		return a < b)
	return idx


## Platzierungen 1..4 mit Gleichständen aus einer Rangliste.
func placements_from_ranking(rank: Array[int]) -> Array[int]:
	var places: Array[int] = [0, 0, 0, 0]
	for pos in rank.size():
		var i := rank[pos]
		places[i] = pos + 1
		if pos > 0:
			var prev := rank[pos - 1]
			if players[i].stars == players[prev].stars and players[i].coins == players[prev].coins:
				places[i] = places[prev]
	return places


func start_party(board_id: String, rounds: int) -> void:
	for p in players:
		p.coins = 10
		p.stars = 0
		p.space = -1
		p.items = []
		p.minigame_wins = 0
		p.coins_max = 10
	party = {
		"board": board_id, "max_rounds": rounds, "round": 1, "turn": 0, "phase": "intro",
		"star_space": -1, "minigames_played": [], "events": {}, "first_intro_done": false,
	}
	mode = "party"


# --- Einstellungen ------------------------------------------------------------

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for k in settings.keys():
		if cfg.has_section_key("settings", k):
			settings[k] = cfg.get_value("settings", k)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings.keys():
		cfg.set_value("settings", k, settings[k])
	cfg.save(SETTINGS_PATH)
	EventBus.settings_changed.emit()
