class_name BossDefs
## Die zehn Bosse: Brett-Zuordnung, Thema, Wurfgeschosse, drei Fähigkeiten (Phase 1 nutzt die ersten zwei,
## ab Phase 2 alle drei, Phase 3 = Wut: Doppelangriffe) und die Einzigartigkeit (Spezial-Orte in der Arena).
## Der Kampf selbst ist ein freier Echtzeit-Arenakampf (scripts/minigames/boss_battle.gd).

const BOSSES := {
	"ignis": {
		"name": "Ignis, der Seelenschmied", "title": "Der Uralte Höhlendrache", "board": "dungeon",
		"env": "dungeon", "backdrop": "dungeon", "ground": Color("#3a2630"), "tile": Color("#5a4048"),
		"ammo": ["Wasserbomben", Color("#4fb8ff")],
		"abilities": [["lava", "Lava-Atem"], ["tail", "Schweifpeitsche"], ["armor", "Schatz-Panzerung"]],
		"unique": "Brüchiger Boden: Risse brechen ein, wenn man zu lange darauf steht – darunter brodelt Lava.",
		"intro": "Tief im Verlies regt sich etwas … der Schatzhaufen bebt!",
	},
	"klabautox": {
		"name": "Klabautox", "title": "Der Gezeiten-Leviathan", "board": "pirates",
		"env": "pirates", "backdrop": "beach", "ground": Color("#e8d6a0"), "tile": Color("#f3e3b8"),
		"ammo": ["Kokosnüsse", Color("#8a5a34")],
		"abilities": [["tsunami", "Tsunami-Welle"], ["bubble", "Blasen-Gefängnis"], ["claw", "Scheren-Zange"]],
		"unique": "Ebbe & Flut: Bei Flut bremst tiefes Wasser – rettet euch auf die Sandbänke!",
		"intro": "Die Flut steigt … und mit ihr eine gewaltige Schere!",
	},
	"astraios": {
		"name": "Astraios", "title": "Der Himmelsgolem", "board": "sky",
		"env": "sky", "backdrop": "sky", "ground": Color("#ffffff"), "tile": Color("#e9efff"),
		"ammo": ["Sternsplitter", Color("#ffd23f")],
		"abilities": [["comet", "Sternschnuppen-Regen"], ["cannonade", "Wolken-Kanonade"], ["gravity", "Gravitations-Umkehr"]],
		"unique": "Wolken-Kanonen schießen euch in seinen Rücken – Rückenangriff mit Riesenschaden!",
		"intro": "Über den Wolken sammeln sich uralte Sternensteine …",
	},
	"grabstein": {
		"name": "Graf Grabstein", "title": "& die Phantom-Meute", "board": "graveyard",
		"env": "graveyard", "backdrop": "night", "ground": Color("#2d3a35"), "tile": Color("#4a5a52"),
		"ammo": ["Lichtkugeln", Color("#fff2a8")],
		"abilities": [["soulsteal", "Seelenraub"], ["taxi", "Geister-Taxi-Umleitung"], ["fog", "Nebelwand"]],
		"unique": "Solange Grabsteine stehen, ist der Graf unverwundbar – zerstört sie mit Würfen!",
		"intro": "Ein spöttisches Kichern hallt über die Gräber …",
	},
	"frostbart": {
		"name": "Yeti-König Frostbart", "title": "Herrscher des ewigen Eises", "board": "frost",
		"env": "snow", "backdrop": "snow", "ground": Color("#eef4fb"), "tile": Color("#d8e8f8"),
		"ammo": ["Glutkugeln", Color("#ff8a3a")],
		"abilities": [["iceslide", "Eisrutschen-Chaos"], ["avalanche", "Lawinen-Stampfer"], ["frostbreath", "Frostiger Atem"]],
		"unique": "Frost-Rüstung halbiert jeden Schaden – sammelt drei Riesen-Schneebälle, um sie zu sprengen!",
		"intro": "Der Boden zittert, Schnee rieselt von den Dächern …",
	},
	"galaxus": {
		"name": "Galaxus", "title": "Der Kosmos-Uhrmacher", "board": "station",
		"env": "observatory", "backdrop": "sky_dusk", "ground": Color("#3a3a6a"), "tile": Color("#5a5a8a"),
		"ammo": ["Schraubenbolzen", Color("#c8ccd8")],
		"abilities": [["timejump", "Zeitsprung"], ["rockets", "Raketen-Feuersturm"], ["nova", "Supernova-Impuls"]],
		"unique": "Stellt euch auf alle drei Uhrwerke – dann gerät er aus dem Takt: doppelter Schaden!",
		"intro": "Tick … tack … die Sterne bleiben stehen.",
	},
	"noxumbra": {
		"name": "Noxumbra", "title": "Die Schattenwurzel", "board": "glowforest",
		"env": "forest_night", "backdrop": "night", "ground": Color("#26402a"), "tile": Color("#3a5a3e"),
		"ammo": ["Glühbeeren", Color("#5fffe0")],
		"abilities": [["darkness", "Ewige Finsternis"], ["roots", "Wurzel-Schlingen"], ["spores", "Sporen-Wolke"]],
		"unique": "Nachts ist sie im Schatten unsichtbar – nur aus dem Licht der Leuchtpilze trefft ihr sie!",
		"intro": "Die Glühwürmchen verstummen. Ein Baum öffnet die Augen …",
	},
	"baahemoth": {
		"name": "Baaah-hemoth", "title": "Das Wolken-Schaf", "board": "meadow",
		"env": "day", "backdrop": "meadow", "ground": Color("#86d06a"), "tile": Color("#a8e08a"),
		"ammo": ["Pusteäpfel", Color("#ff5c6a")],
		"abilities": [["ramstorm", "Rammbock-Sturm"], ["sheepflood", "Schäfchen-Flut"], ["dandelion", "Pusteblumen-Orkan"]],
		"unique": "Duell-Felder: Stehen zwei Spieler auf beiden Feldern, startet ein Hämmer-Duell um Bonuspunkte!",
		"intro": "Määäh! Die Wiese bebt unter gewaltigen Hufen …",
	},
	"marquise": {
		"name": "Marzipan-Marquise", "title": "& das Sahne-Monster", "board": "cake",
		"env": "sunset", "backdrop": "cake", "ground": Color("#f6c9d8"), "tile": Color("#ffe0ec"),
		"ammo": ["Zitronenbonbons", Color("#ffe066")],
		"abilities": [["caramel", "Karamell-Kleister"], ["candleflame", "Kerzen-Flammenwerfer"], ["cherrybomb", "Kirsch-Bombe"]],
		"unique": "Kirsch-Lifte tragen euch nach oben – von dort trefft ihr doppelt!",
		"intro": "Es duftet nach Karamell … und die Torte lächelt.",
	},
	"zephyros": {
		"name": "Zephyros", "title": "Der Herrscher der Lüfte", "board": "tower",
		"env": "sky", "backdrop": "sky", "ground": Color("#ffffff"), "tile": Color("#eaf3ff"),
		"ammo": ["Sonnenbälle", Color("#ffcf3a")],
		"abilities": [["gust", "Windböe"], ["whirl", "Aufwind-Wirbel"], ["seedstorm", "Pusteblumen-Sturm"]],
		"unique": "Aufwind-Felder schleudern euch hoch – Würfe aus der Luft zählen doppelt!",
		"intro": "Ganz oben am Wolkenturm dreht der Wind …",
	},
}

const BOARD_BOSS := {"dungeon": "ignis", "pirates": "klabautox", "sky": "astraios", "graveyard": "grabstein",
	"frost": "frostbart", "station": "galaxus", "glowforest": "noxumbra", "meadow": "baahemoth", "cake": "marquise", "tower": "zephyros"}

static func get_def(id: String) -> Dictionary:
	return BOSSES.get(id, BOSSES.zephyros)


static func for_board(board: String) -> String:
	return String(BOARD_BOSS.get(board, "baahemoth"))
