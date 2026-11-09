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
	{"id": "pirates", "name": "Sonnige Palmen-Bucht", "desc": "Tropenbucht mit Planken-Katapulten, verspielten Delfinen und einer Sandbank, die bei Ebbe auftaucht.", "music": "board_pirates"},
	{"id": "sky", "name": "Sternen-Wolkenland", "desc": "Flauschige Wolkeninseln, Regenbögen, Zugbrücken und Wolken-Kanonen.", "music": "board_sky"},
	{"id": "graveyard", "name": "Geisterfriedhof", "desc": "Mondlicht, Bodennebel und ein Geister-Taxi, das dich vor- oder zurückfliegt. Die Geisterbrücke erscheint nur in ungeraden Runden.", "music": "board_dungeon"},
	{"id": "frost", "name": "Frostdorf", "desc": "Verschneites Dorf mit Eis-Rutschen, Schlittenbahn und einem See, der in geraden Runden zufriert.", "music": "board_sky"},
	{"id": "station", "name": "Sternen-Sternwarte", "desc": "Gemütliche Sternwarte auf einer schwebenden Wiese: Kometen-Pads, Raketen und Sternenbrücken.", "music": "board_sky"},
	{"id": "glowforest", "name": "Glühwürmchen-Zauberwald", "desc": "Tag und Nacht wechseln jede Runde – nachts leuchten die Pilze und ein geheimer Pilzpfad öffnet sich.", "music": "board_dungeon"},
	{"id": "meadow", "name": "Wuschel-Wiesen", "desc": "Weiche Hügel, wuschelige Schäfchen, Pusteblumen-Flüge und Duell-Felder.", "music": "board_pirates"},
	{"id": "cake", "name": "Zuckerback-Torte", "desc": "Ein Spielbrett auf einer riesigen Torte: Schoko-Rutschen, Sahne-Spritzer und Kirsch-Lifte.", "music": "board_sky"},
	{"id": "tower", "name": "Der Wolkenturm", "desc": "Vertikales Brett: Wendelweg um einen verwunschenen Pflanzenturm, Ranken-Abkürzungen, Wolkenlift, Aufwind – oben wartet der Gipfelstern, hinab geht es per Regenbogen-Rutsche.", "music": "board_sky"},
]

const MINIGAMES := [
	{"id": "plank_panic", "name": "Plank-Panic", "scene": "res://scenes/minigames/PlankPanic.tscn", "kind": "survival", "online": true, "cats": ["ffa", "2v2"],
		"desc": "Die morsche Planke über dem Haifischbecken bricht Stück für Stück. Schubse die anderen ins Wasser!",
		"controls": "Stick: Laufen · A: Springen · B: Schubsen"},
	{"id": "dungeon_drop", "name": "Dungeon Drop", "scene": "res://scenes/minigames/DungeonDrop.tscn", "kind": "survival", "online": true, "cats": ["ffa", "2v2", "duel"],
		"desc": "Steinplatten brechen 1,5 Sekunden nach dem Betreten ein. Bleib in Bewegung oder fall in die Lava!",
		"controls": "Stick: Laufen · A: Springen · B: Schubsen"},
	{"id": "kart_bowling", "name": "Kart-Bowling", "scene": "res://scenes/minigames/KartBowling.tscn", "kind": "survival", "cats": ["ffa", "2v2"],
		"desc": "Riesige Dungeon-Felsen rollen durch die Arena. Weiche aus und rempel Gegner mit Turbo in die Bahn!",
		"controls": "Stick: Lenken · A: Gas · B: Turbo-Rempler"},
	{"id": "treasure_zipline", "name": "Schatz-Seilbahn", "scene": "res://scenes/minigames/TreasureZipline.tscn", "kind": "score", "cats": ["ffa", "2v2"],
		"desc": "Sause an der Seilbahn über die Schlucht. Spring im richtigen Moment ab, um Schatzkisten zu schnappen!",
		"controls": "A: Absprung / Greifen · Stick: Seil wechseln"},
	{"id": "ghost_castle", "name": "Geister-Schloss Schwindel", "scene": "res://scenes/minigames/GhostCastle.tscn", "kind": "race", "online": true, "cats": ["ffa", "2v2", "duel"],
		"desc": "Stockfinster! Nur die Blitze zeigen kurz den sicheren Weg durchs Geisterschloss. Merk ihn dir!",
		"controls": "Stick: Laufen · A: Springen"},
	{"id": "barrel_chaos", "name": "Fässer-Chaos", "scene": "res://scenes/minigames/BarrelChaos.tscn", "kind": "score", "cats": ["ffa", "2v2"],
		"desc": "Der Kapitän versteckt den Schatz in einem tanzenden Fass. Folge ihm mit den Augen und spring ins richtige!",
		"controls": "Stick: Laufen · A: Ins Fass springen"},
	{"id": "lava_surf", "name": "Lavastrom-Surfen", "scene": "res://scenes/minigames/LavaSurf.tscn", "kind": "score", "cats": ["ffa", "2v2"],
		"desc": "Surfe auf deinem Floß den Lavastrom hinab, sammle Edelsteine und boxe Gegner vom Floß!",
		"controls": "Stick: Steuern · B: Boxhandschuh · A: Hüpfen"},
	{"id": "tower_balance", "name": "Turm-Balancieren", "scene": "res://scenes/minigames/TowerBalance.tscn", "kind": "score", "cats": ["ffa", "duel"],
		"desc": "Staple wackelige Dungeon-Blöcke zum höchsten Turm – aber der Wind dreht ständig!",
		"controls": "A: Block fallen lassen"},
	{"id": "hot_bomb", "name": "Bomben-Heißer-Hut", "scene": "res://scenes/minigames/HotBomb.tscn", "kind": "survival", "cats": ["ffa"],
		"desc": "Die Kanonenkugel tickt! Wirf sie schnell weiter – wer sie beim Knall hält, fliegt spektakulär in die Luft.",
		"controls": "Stick: Laufen/Zielen · B: Werfen"},
	{"id": "slime_sprint", "name": "Schleim-Spur Sprint", "scene": "res://scenes/minigames/SlimeSprint.tscn", "kind": "race", "online": true, "cats": ["ffa", "2v2", "duel"],
		"desc": "Sprinte durch den Parcours! Schleimpfützen sind glitschig und Pendel-Fallen schwingen gnadenlos.",
		"controls": "Stick: Laufen · A: Springen"},
	{"id": "coin_rain", "name": "Münzregen", "scene": "res://scenes/minigames/CoinRain.tscn", "kind": "score", "cats": ["coin", "ffa", "2v2", "duel"],
		"desc": "Münzen, Sterne – und Bomben regnen vom Himmel! Schnapp dir die meisten Münzen und schubse Gegner, damit sie welche verlieren.",
		"controls": "Stick: Laufen · A: Springen · B: Schubsen"},
	{"id": "sumo_shove", "name": "Sumo-Schubser", "scene": "res://scenes/minigames/SumoShove.tscn", "kind": "survival", "online": true, "cats": ["ffa", "2v2", "duel"],
		"desc": "Die runde Plattform über dem Meer schrumpft! Doppelt starke Schubser – wer zuletzt oben steht, gewinnt.",
		"controls": "Stick: Laufen · A: Springen · B: Super-Schubser"},
	{"id": "snowball_fight", "name": "Schneeball-Schlacht", "scene": "res://scenes/minigames/SnowballFight.tscn", "kind": "score", "cats": ["ffa", "2v2"],
		"desc": "Verschanz dich hinter Schneemännern und triff die anderen! Am Schneehaufen lädt Munition schneller nach.",
		"controls": "Stick: Laufen · A: Springen · B: Werfen"},
	{"id": "color_chaos", "name": "Farb-Chaos", "scene": "res://scenes/minigames/ColorChaos.tscn", "kind": "score", "online": true, "cats": ["ffa", "2v2"],
		"desc": "Jedes Feld, über das du läufst, wird in deiner Farbe eingefärbt. Farbbomben färben ganze Bereiche!",
		"controls": "Stick: Laufen · A: Springen · B: Schubsen (betäubt)"},
	{"id": "hammer_hop", "name": "Hammer-Hüpfen", "scene": "res://scenes/minigames/HammerHop.tscn", "kind": "survival", "online": true, "cats": ["ffa", "1v3"],
		"desc": "Ein Riesenhammer kreist über den Turm – spring rechtzeitig! Später kommt ein hoher Balken dazu: darunter bloß nicht springen.",
		"controls": "Stick: Laufen · A: Springen · B: Schubsen"},
	{"id": "fish_catch", "name": "Fischfang", "scene": "res://scenes/minigames/FishCatch.tscn", "kind": "score", "cats": ["ffa", "duel", "coin"],
		"desc": "Steuere deinen Schwimmer zu den Fisch-Schatten. Taucht er ab, sofort A! Goldfische bringen 6 Punkte – Stiefel nichts.",
		"controls": "Stick: Schwimmer bewegen · A: Anschlagen"},
	{"id": "meteor_dodge", "name": "Sternschnuppen-Regen", "scene": "res://scenes/minigames/MeteorDodge.tscn", "kind": "survival", "online": true, "cats": ["ffa", "1v3"],
		"desc": "Auf der Abendwiese purzeln Sternschnuppen-Brocken vom Himmel! Rote Kreise zeigen den Einschlag – und manche zielen direkt auf dich.",
		"controls": "Stick: Laufen · A: Springen · B: Schubsen"},
	{"id": "rhythm_dance", "name": "Rhythmus-Tanz", "scene": "res://scenes/minigames/RhythmDance.tscn", "kind": "score", "cats": ["ffa", "2v2"],
		"desc": "Schnipp den Stick genau im Takt in Pfeilrichtung oder drück A! PERFEKT gibt 3 Punkte, Serien geben Bonus.",
		"controls": "Stick: Richtung schnippen · A: A-Note"},
	{"id": "minigolf_duel", "name": "Minigolf-Duell", "scene": "res://scenes/minigames/MinigolfDuel.tscn", "kind": "score", "cats": ["ffa", "duel"],
		"desc": "Alle putten gleichzeitig! Wer zuerst einlocht, kassiert 4 Punkte. Pilz-Bumper schleudern Bälle quer über die Bahn.",
		"controls": "Stick: Zielen · A halten: Kraft laden · loslassen: Schlag"},
	{"id": "balloon_battle", "name": "Ballon-Kart-Battle", "scene": "res://scenes/minigames/BalloonBattle.tscn", "kind": "survival", "cats": ["ffa", "2v2"],
		"desc": "Platze die Ballons der anderen per Turbo-Rempler und klau sie dir! Item-Boxen geben Torten-Kanonen.",
		"controls": "Stick: Lenken · A: Gas · B: Turbo-Rempler · X: Torte"},
	{"id": "flower_rush", "name": "Blumen-Farbenrausch", "scene": "res://scenes/minigames/FlowerRush.tscn", "kind": "survival", "online": true, "cats": ["ffa"],
		"desc": "Das Vögelchen zwitschert eine Farbe – flitz aufs passende Blütenbeet, bevor die anderen in den Teich sinken!",
		"controls": "Stick: Laufen · A: Springen · B: Schubsen"},
	{"id": "plush_balls", "name": "Kuschel-Bälle-Hüpfen", "scene": "res://scenes/minigames/PlushBalls.tscn", "kind": "survival", "online": true, "cats": ["ffa"],
		"desc": "Riesige Plüschbälle kullern über das Wolkenkissen. Kleine überspringen, vor großen flüchten!",
		"controls": "Stick: Laufen · A: Springen"},
	{"id": "sleepy_stars", "name": "Schlummer-Sternchen-Tanz", "scene": "res://scenes/minigames/SleepyStars.tscn", "kind": "survival", "online": true, "cats": ["ffa"],
		"desc": "Die Wiesentiere singen eine Melodie vor – spiel sie fehlerfrei mit dem Stick nach, sonst schläfst du ein!",
		"controls": "Stick/Steuerkreuz: oben · rechts · unten · links"},
	{"id": "pumpkin_toss", "name": "Kürbis-Weitwurf", "scene": "res://scenes/minigames/PumpkinToss.tscn", "kind": "score", "online": true, "cats": ["ffa", "duel"],
		"desc": "Stick kreisen lassen für Schwung und A drücken, wenn der Pfeil nach vorn zeigt. Wer wirft den Kürbis am weitesten?",
		"controls": "Stick kreisen / B hämmern: Schwung · A: Loslassen"},
	{"id": "tug_of_war", "name": "Seilziehen am Pilzbach", "scene": "res://scenes/minigames/TugOfWar.tscn", "kind": "score", "online": true, "cats": ["1v3", "2v2"],
		"desc": "A hämmern zum Ziehen – im Kraft-Takt doppelt! Wer zuerst in den Bach gezogen wird, verliert.",
		"controls": "A: Ziehen (im Takt = doppelt)"},
	{"id": "honey_chase", "name": "Honigbären-Flucht", "scene": "res://scenes/minigames/HoneyChase.tscn", "kind": "score", "online": true, "cats": ["1v3"],
		"desc": "Das Solo flieht im Honigwägelchen und legt Honigfallen, das Trio reitet die Riesenbiene hinterher!",
		"controls": "Solo: Stick Spur · A Sprung · B Honigfalle — Trio: A Tempo · Stick Spur"},
	{"id": "hollow_hide", "name": "Baumhöhlen-Versteck", "scene": "res://scenes/minigames/HollowHide.tscn", "kind": "score", "online": true, "cats": ["1v3"],
		"desc": "Das Solo versteckt sich und wirbelt die Baumstümpfe durcheinander. Folgt ihm das Trio mit den Augen?",
		"controls": "Solo: Stick wirbeln — Trio: Stick wählen · A tippen"},
	{"id": "rail_express", "name": "Schienen-Express", "scene": "res://scenes/minigames/RailExpress.tscn", "kind": "race", "online": true, "cats": ["2v2"],
		"desc": "Einer pumpt, einer springt: Bringt eure quietschbunte Lore als Erste über die Schranken ins Ziel!",
		"controls": "Pumper: A hämmern · Springer: A springen"},
	{"id": "star_hoops", "name": "Sternen-Korbschlacht", "scene": "res://scenes/minigames/StarHoops.tscn", "kind": "score", "online": true, "cats": ["2v2"],
		"desc": "Sternenbälle schnappen und in den Wolkenkorb der anderen werfen. Von weit weg zählt doppelt!",
		"controls": "Stick: Laufen · B: Werfen / Schubsen"},
	{"id": "lucky_bells", "name": "Glücks-Glöckchen", "scene": "res://scenes/minigames/LuckyBells.tscn", "kind": "score", "online": true, "cats": ["luck", "coin", "ffa"],
		"desc": "Drei Walzen, drei Drehungen: Stoppe Kirschen, Glocken, Kleeblätter, Sterne und Kronen – drei Gleiche läuten groß ab!",
		"controls": "A: Walze stoppen"},
	{"id": "chest_sniff", "name": "Schatzkisten-Schnüffeln", "scene": "res://scenes/minigames/ChestSniff.tscn", "kind": "score", "online": true, "cats": ["luck", "ffa"],
		"desc": "Reihum eine Kiste wählen: Gold, Münzen – oder der Kistengeist ruft Buh!",
		"controls": "Stick: Kiste wählen · A: Nehmen"},
	{"id": "boss_cloud", "name": "Boss: Pustebacke, der Wolkendrache", "scene": "res://scenes/minigames/BossCloud.tscn", "kind": "score", "online": true, "cats": ["boss"],
		"desc": "Gemeinsam gegen den Wolkendrachen! Sonnenbälle sammeln und werfen – wer am meisten trifft, gewinnt.",
		"controls": "Stick: Laufen · A: Springen · B: Werfen"},
	{"id": "ghost_photo", "name": "Geister-Fotograf", "scene": "res://scenes/minigames/GhostPhoto.tscn", "kind": "score", "online": true, "cats": ["ffa"],
		"desc": "Geistervilla bei Nacht: Knipse huschende Buh-Geister und funkelnde Schätze! Die alte Kamera lädt langsam – ruhige, mittige Motive werden scharf, schnelle verwackeln.",
		"controls": "Stick: Laufen & Taschenlampe richten · A: Foto (wenn der Ring leuchtet)"},
	{"id": "cheese_brawl", "name": "Käse-Kloppe", "scene": "res://scenes/minigames/CheeseBrawl.tscn", "kind": "survival", "online": true, "cats": ["ffa"],
		"desc": "Als Mäuse auf einem wackeligen Riesenkäse: Kugel-Katzen rollen heran! Packe und wirf deine Mitspieler – die letzte Maus auf dem Käse gewinnt.",
		"controls": "Stick: Laufen · A: Springen · B: Packen / Werfen"},
	{"id": "penguin_curling", "name": "Pinguin-Curling", "scene": "res://scenes/minigames/PenguinCurling.tscn", "kind": "score", "online": true, "cats": ["ffa"],
		"desc": "Schubse deinen Pinguin über die Eisbahn ins Zielhaus – gegnerische Pinguine darfst du wegrammen. Drei Runden, der nächste am Zentrum punktet.",
		"controls": "Stick: Richtung · A halten & loslassen: Schwung · A hämmern: Eis wischen"},
	{"id": "bubble_ballet", "name": "Seifenblasen-Ballett", "scene": "res://scenes/minigames/BubbleBallet.tscn", "kind": "survival", "online": true, "cats": ["ffa"],
		"desc": "Balanciere auf deiner Seifenblase und puste die anderen über den Rand! A und B im Wechsel pumpen Wind – aber zu wild, und deine Blase platzt.",
		"controls": "Stick: Pust-Richtung · A/B abwechselnd: Wind pumpen"},
	{"id": "sleepwalk", "name": "Schlafwandler-Parcours", "scene": "res://scenes/minigames/Sleepwalk.tscn", "kind": "score", "online": true, "cats": ["ffa"],
		"desc": "Im Schlaf über schmale Balken! Wähle vor jedem Hindernis blitzschnell die richtige Aktion – falsch oder zu langsam, und du stolperst.",
		"controls": "Stick/Steuerkreuz: ↑ Schritt · ← / → Lehnen · ↓ Hinsetzen"},
	{"id": "rhythm_kitchen", "name": "Rhythmus-Küche", "scene": "res://scenes/minigames/RhythmKitchen.tscn", "kind": "score", "online": true, "cats": ["coop"], "mode": true,
		"desc": "Gemeinsam ein Fünf-Gänge-Menü im Takt kochen: schnippeln, rühren, wenden, würzen, verzieren. Am Ende vergibt Chefkoch Brummbär die Küchen-Note!",
		"controls": "A/B: Noten · Stick: Pfeil-Noten schnippen"},
]

const TRACKS := [
	{"id": "lumos_ring", "name": "Lumos-Ring", "desc": "Sonniger Grand-Prix-Kurs mit Looping und Gleiter-Schlucht.", "music": "race"},
	{"id": "coral_canal", "name": "Korallen-Kanal", "desc": "Piratenbucht mit gläsernem Unterwasser-Tunnel.", "music": "race"},
	{"id": "neon_volcano", "name": "Vulkan-Inselchen", "desc": "Sonnenuntergang auf der Vulkaninsel: Looping, Gleiter über warme Lavaseen und Palmen am Wegesrand.", "music": "race"},
	{"id": "storm_pass", "name": "Gewitter-Pass", "desc": "Nacht, Regen, grelle Blitze: Bergpass mit Leuchtmarkierungen und Sprung über die Schlucht.", "music": "race"},
	{"id": "frost_peak", "name": "Frostgipfel", "desc": "Spiegelglatte Eisplatten, Schneegestöber und eine Skisprungschanze.", "music": "race"},
	{"id": "orbit_ring", "name": "Sternenstaub-Bahn", "desc": "Pastellbahn durch den Abendhimmel: Looping, Schwebe-Gleiter und ein Ringplanet zum Greifen nah.", "music": "race"},
	{"id": "city_rally", "name": "Stadt-Rallye", "desc": "Enge 90°-Kurven zwischen Hochhäusern und ein Sprung über den Stadtkanal.", "music": "race"},
	{"id": "desert_canyon", "name": "Wüsten-Canyon", "desc": "Sandpiste mit Looping und Gleitflug über eine schwindelerregende Schlucht.", "music": "race"},
]

const CUPS := [
	{"id": "lumos", "name": "Lumos-Cup", "tracks": ["lumos_ring", "coral_canal", "neon_volcano", "storm_pass"]},
	{"id": "stars", "name": "Sternen-Cup", "tracks": ["frost_peak", "orbit_ring", "city_rally", "desert_canyon"]},
	{"id": "mega", "name": "Mega-Cup (8 Strecken)", "tracks": ["lumos_ring", "frost_peak", "coral_canal", "city_rally", "neon_volcano", "desert_canyon", "storm_pass", "orbit_ring"]},
]
const GP_POINTS := [15, 12, 10, 8, 6, 4, 2, 1]
const PARTY_MODES := [
	{"id": "classic", "name": "Klassisch", "desc": "Sterne sammeln, Münzen horten, Minispiele nach jeder Runde."},
	{"id": "pro", "name": "Profi-Regeln", "desc": "12 Runden, angekündigte Bonussterne (Abenteuer, Flitzer, Trödler), Minispiele per Abstimmung, Laden mit begrenztem Vorrat, Stern-Duelle."},
	{"id": "blitz", "name": "Blitz-Party", "desc": "5 Runden, alle starten mit 50 Münzen, einem Stern und einem Doppelwürfel – Endspurt ab der ersten Runde."},
	{"id": "team", "name": "Team-Party (2 gegen 2)", "desc": "Rot + Grün gegen Blau + Gelb: Teampartner teilen sich Münzen, Sterne und Items."},
]
const RECORDS_PATH := "user://records.cfg"
const SETTINGS_PATH := "user://settings.cfg"

var players: Array[Dictionary] = []
var settings := {
	"music": 0.7, "sfx": 0.9, "voice": 1.0,
	"haptics": true, "touch_opacity": 0.8, "touch_scale": 1.0, "touch_layout": {},
	"auto_accel": true, "steer_sens": 1.0, "screen_shake": 1.0, "quality": "auto", "show_fps": false, "dynamic_res": true,
		"split_screen": true, "multi_display": true,
}
var party: Dictionary = {}
var race_cfg := {"track": "lumos_ring", "laps": 3, "cpu_level": 1, "mode": "single", "cup": 0}
var gp: Dictionary = {}           # {cup, tracks, index, points: {name: pts}, colors: {name: Color}, models: {name: model}, slots: {name: slot}}
var marathon: Dictionary = {}     # {games: [ids], index, points: [4]}
var mode := "menu"          # menu | party | free_play | race | marathon
var pending_minigame := ""
## Kategorie/Teams für das nächste Minispiel: {cat, teams, solo, active}
var minigame_setup: Dictionary = {}
var last_results: Dictionary = {}
var free_play_queue: Array = []
var is_touch_device := false
var is_lumos_device := false


func _ready() -> void:
	load_settings()
	reset_players()
	is_touch_device = detect_mobile()


## Echtes Mobilgerät (Handy/Tablet)? Nur dann gibt es Touch-Steuerelemente. Desktop, Konsole/App und
## Laptops mit Touchscreen oder Maus zählen nicht – dort reichen Gamepad, Tastatur und Maus.
func detect_mobile() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	if OS.has_feature("web"):
		var r: Variant = JavaScriptBridge.eval("""(function(){
			var ua = navigator.userAgent || '';
			var mobileUA = /Android|iPhone|iPad|iPod|Mobile|Silk|Kindle|Opera Mini|IEMobile/i.test(ua);
			var iPadOS = navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1;
			var coarseOnly = window.matchMedia && matchMedia('(pointer: coarse)').matches && !matchMedia('(any-pointer: fine)').matches;
			return (mobileUA || iPadOS || coarseOnly) && navigator.maxTouchPoints > 0;
		})()""", true)
		return r is bool and r
	return false


func reset_players(human_count := 1) -> void:
	players.clear()
	var hero_order := ["knight", "mage", "barbarian", "rogue"]
	for i in 4:
		players.append(new_player(i, hero_order[i], i >= human_count, 1))


func new_player(idx: int, hero_id: String, cpu: bool, cpu_level: int) -> Dictionary:
	return {
		"idx": idx, "hero": hero_id, "name": hero(hero_id).name, "color": SLOT_COLORS[idx],
		"cpu": cpu, "cpu_level": cpu_level, "device": idx, "remote": false, "last_color": "blue",
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
	# Team-Regeln: Teampartner teilen sich die Kasse
	if is_team_mode():
		var mate: Dictionary = players[(i + 2) % 4]
		mate.coins = p.coins
		mate.coins_max = maxi(int(mate.coins_max), int(mate.coins))
		EventBus.coins_changed.emit((i + 2) % 4, mate.coins, real)
	return real


func add_stars(i: int, delta: int) -> void:
	var p: Dictionary = players[i]
	p.stars = maxi(0, int(p.stars) + delta)
	EventBus.stars_changed.emit(i, p.stars, delta)
	if is_team_mode():
		players[(i + 2) % 4].stars = p.stars
		EventBus.stars_changed.emit((i + 2) % 4, p.stars, delta)


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


## Team-Modus: Spieler 0+2 (Rot/Grün) gegen 1+3 (Blau/Gelb).
func team_of(i: int) -> int:
	return i % 2


func is_team_mode() -> bool:
	return mode == "party" and String(party.get("mode", "classic")) == "team"


func party_mode() -> String:
	return String(party.get("mode", "classic"))


## Team-Rangliste [Siegerteam, Verliererteam] nach Sternen, dann Münzen.
func team_ranking() -> Array[int]:
	var st := [0, 0]
	var co := [0, 0]
	for i in 4:
		st[team_of(i)] += int(players[i].stars)
		co[team_of(i)] += int(players[i].coins)
	if st[0] != st[1]:
		return [0, 1] if st[0] > st[1] else [1, 0]
	return [0, 1] if co[0] >= co[1] else [1, 0]


## Brett-Zufall (Ereignisse, Stern, Partner, Roulette): online deterministisch auf allen Geräten.
var prng := RandomNumberGenerator.new()


func start_party(board_id: String, rounds: int, party_mode := "classic") -> void:
	var start_coins := 50 if party_mode == "blitz" else 10
	if party_mode == "pro":
		rounds = 12
	elif party_mode == "blitz":
		rounds = 5
	for p in players:
		p.coins = start_coins
		p.stars = 1 if party_mode == "blitz" else 0
		p.space = -1
		p.items = ["double_dice"] if party_mode == "blitz" else []
		p.dice_total = 0
		p.events_landed = 0
		p.last_color = "blue"
		p.minigame_wins = 0
		p.coins_max = start_coins
	party = {
		"board": board_id, "max_rounds": rounds, "round": 1, "turn": 0, "phase": "intro", "mode": party_mode,
		"star_space": -1, "minigames_played": [], "events": {}, "first_intro_done": false, "dseq": 0,
	}
	# Brett-Zufall: online auf allen Geräten identisch (gleicher Startwert aus der Raum-Konfiguration)
	if Net.in_game():
		prng.seed = int(Net.game_cfg.get("seed", 1)) ^ 0x5eed
	else:
		prng.randomize()
	mode = "party"


## Darf dieses Minispiel gerade laufen? (Online nur netzwerkfähige Spiele.)
func minigame_allowed(m: Dictionary) -> bool:
	return not Net.in_game() or bool(m.get("online", false))


# --- Grand Prix ---------------------------------------------------------------

func start_gp(cup_index: int) -> void:
	var cup: Dictionary = CUPS[clampi(cup_index, 0, CUPS.size() - 1)]
	gp = {"cup": cup.name, "tracks": cup.tracks.duplicate(), "index": 0, "points": {}, "colors": {}, "models": {}, "slots": {}}
	race_cfg.mode = "gp"
	race_cfg.track = cup.tracks[0]
	mode = "race"


# --- Minispiel-Marathon ---------------------------------------------------------

func start_marathon(count: int) -> void:
	var ids: Array = []
	for m in MINIGAMES:
		if not bool(m.get("mode", false)) and not ("boss" in (m.get("cats", []) as Array)):
			ids.append(m.id)
	ids.shuffle()
	marathon = {"games": ids.slice(0, mini(count, ids.size())), "index": 0, "points": [0, 0, 0, 0]}
	mode = "marathon"


# --- Zeitfahren-Rekorde ----------------------------------------------------------

## Speichert eine Zeitfahrt. Gibt {total_record: bool, lap_record: bool, best_total, best_lap} zurück.
func submit_time(track_id: String, total: float, best_lap: float) -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(RECORDS_PATH)
	var old_total: float = cfg.get_value(track_id, "total", INF)
	var old_lap: float = cfg.get_value(track_id, "lap", INF)
	var res := {"total_record": total < old_total, "lap_record": best_lap < old_lap,
		"best_total": minf(total, old_total), "best_lap": minf(best_lap, old_lap), "prev_total": old_total}
	cfg.set_value(track_id, "total", res.best_total)
	cfg.set_value(track_id, "lap", res.best_lap)
	cfg.save(RECORDS_PATH)
	EventBus.record_set.emit(track_id, float(res.best_total), float(res.best_lap))
	return res


## Bestwert speichern (z. B. beste Küchen-Note); gibt true zurück, wenn es ein neuer Rekord ist.
func records_note(key: String, value: int) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(RECORDS_PATH)
	var old := int(cfg.get_value("stats", key, -1))
	if value <= old:
		return false
	cfg.set_value("stats", key, value)
	cfg.save(RECORDS_PATH)
	return true


func stat(key: String, default := -1) -> int:
	var cfg := ConfigFile.new()
	if cfg.load(RECORDS_PATH) != OK:
		return default
	return int(cfg.get_value("stats", key, default))


func record_for(track_id: String) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(RECORDS_PATH) != OK:
		return {}
	if not cfg.has_section(track_id):
		return {}
	return {"total": cfg.get_value(track_id, "total", INF), "lap": cfg.get_value(track_id, "lap", INF)}


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
