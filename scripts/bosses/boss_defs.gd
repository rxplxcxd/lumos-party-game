class_name BossDefs
## Die zehn Bosse: Brett-Zuordnung, Thema, Feld-Layout der Ring-Arena (20 Felder), drei Fähigkeiten
## (Phase 1 nutzt die ersten zwei, ab Phase 2 alle drei, Phase 3 = Wut: zwei Aktionen pro Bossrunde)
## und die Einzigartigkeit (Spezialfelder + Sonderregel).
##
## Felder: N normal · A Angriff · C Münzen · Spezial: R brüchig · H Sandbank · K Wolkenkanone · T Grabstein
## S Schneeball · G Uhrwerk · M Leuchtpilz · D Duell · L Kirsch-Lift · P Schoko-Rutsche · U Aufwind

const BOSSES := {
	"ignis": {
		"name": "Ignis, der Seelenschmied", "title": "Der Uralte Höhlendrache", "board": "dungeon",
		"env": "dungeon", "backdrop": "dungeon", "ground": Color("#3a2630"), "tile": Color("#5a4048"),
		"layout": "NARNCANRNANRCNARNANR",
		"abilities": [["lava", "Lava-Atem"], ["tail", "Schweifpeitsche"], ["armor", "Schatz-Panzerung"]],
		"unique": "Brüchiger Boden: Felder mit Rissen brechen beim zweiten Betreten ein.",
		"intro": "Tief im Verlies regt sich etwas … der Schatzhaufen bebt!",
	},
	"klabautox": {
		"name": "Klabautox", "title": "Der Gezeiten-Leviathan", "board": "pirates",
		"env": "pirates", "backdrop": "beach", "ground": Color("#e8d6a0"), "tile": Color("#f3e3b8"),
		"layout": "NAHNCANHNANHCNAHNANH",
		"abilities": [["tsunami", "Tsunami-Welle"], ["bubble", "Blasen-Gefängnis"], ["claw", "Scheren-Zange"]],
		"unique": "Ebbe & Flut: Bei Flut kostet tiefes Wasser 2 Würfelaugen – rettet euch auf die Sandbänke!",
		"intro": "Die Flut steigt … und mit ihr eine gewaltige Schere!",
	},
	"astraios": {
		"name": "Astraios", "title": "Der Himmelsgolem", "board": "sky",
		"env": "sky", "backdrop": "sky", "ground": Color("#ffffff"), "tile": Color("#e9efff"),
		"layout": "NANKCANNANKNCANNANKN",
		"abilities": [["comet", "Sternschnuppen-Regen"], ["cannonade", "Wolken-Kanonade"], ["gravity", "Gravitations-Umkehr"]],
		"unique": "Wolken-Kanonen schießen euch in seinen Rücken – doppelter Schaden!",
		"intro": "Über den Wolken sammeln sich uralte Sternensteine …",
	},
	"grabstein": {
		"name": "Graf Grabstein", "title": "& die Phantom-Meute", "board": "graveyard",
		"env": "graveyard", "backdrop": "night", "ground": Color("#2d3a35"), "tile": Color("#4a5a52"),
		"layout": "NATNCANNTANNCATNNANN",
		"abilities": [["soulsteal", "Seelenraub"], ["taxi", "Geister-Taxi-Umleitung"], ["fog", "Nebelwand"]],
		"unique": "Solange Grabsteine stehen, ist der Graf unverwundbar – zerstört sie durch Betreten!",
		"intro": "Ein spöttisches Kichern hallt über die Gräber …",
	},
	"frostbart": {
		"name": "Yeti-König Frostbart", "title": "Herrscher des ewigen Eises", "board": "frost",
		"env": "snow", "backdrop": "snow", "ground": Color("#eef4fb"), "tile": Color("#d8e8f8"),
		"layout": "NASNCANSNANNCASNNANS",
		"abilities": [["iceslide", "Eisrutschen-Chaos"], ["avalanche", "Lawinen-Stampfer"], ["frostbreath", "Frostiger Atem"]],
		"unique": "Frost-Rüstung halbiert jeden Schaden – sammelt drei Schneebälle, um sie zu sprengen!",
		"intro": "Der Boden zittert, Schnee rieselt von den Dächern …",
	},
	"galaxus": {
		"name": "Galaxus", "title": "Der Kosmos-Uhrmacher", "board": "station",
		"env": "observatory", "backdrop": "sky_dusk", "ground": Color("#3a3a6a"), "tile": Color("#5a5a8a"),
		"layout": "NAGNCANGNANNCAGNNANG",
		"abilities": [["timejump", "Zeitsprung"], ["rockets", "Raketen-Feuersturm"], ["nova", "Supernova-Impuls"]],
		"unique": "Synchronisiert drei Uhrwerke – dann gerät er aus dem Takt: doppelter Schaden, er setzt aus!",
		"intro": "Tick … tack … die Sterne bleiben stehen.",
	},
	"noxumbra": {
		"name": "Noxumbra", "title": "Die Schattenwurzel", "board": "glowforest",
		"env": "forest_night", "backdrop": "night", "ground": Color("#26402a"), "tile": Color("#3a5a3e"),
		"layout": "NAMNCAMNNANMCANMNANM",
		"abilities": [["darkness", "Ewige Finsternis"], ["roots", "Wurzel-Schlingen"], ["spores", "Sporen-Wolke"]],
		"unique": "Nachts ist sie im Schatten unsichtbar – nur von den Leuchtpilzen aus trefft ihr sie!",
		"intro": "Die Glühwürmchen verstummen. Ein Baum öffnet die Augen …",
	},
	"baahemoth": {
		"name": "Baaah-hemoth", "title": "Das Wolken-Schaf", "board": "meadow",
		"env": "day", "backdrop": "meadow", "ground": Color("#86d06a"), "tile": Color("#a8e08a"),
		"layout": "NADNCANDNANNCADNNAND",
		"abilities": [["ramstorm", "Rammbock-Sturm"], ["sheepflood", "Schäfchen-Flut"], ["dandelion", "Pusteblumen-Orkan"]],
		"unique": "Duell-Felder: Wer darauf landet, fordert den Nächsten zum Mini-Duell um Bonuspunkte!",
		"intro": "Määäh! Die Wiese bebt unter gewaltigen Hufen …",
	},
	"marquise": {
		"name": "Marzipan-Marquise", "title": "& das Sahne-Monster", "board": "cake",
		"env": "sunset", "backdrop": "cake", "ground": Color("#f6c9d8"), "tile": Color("#ffe0ec"),
		"layout": "NALPCANLNAPNCALNPANL",
		"abilities": [["caramel", "Karamell-Kleister"], ["candleflame", "Kerzen-Flammenwerfer"], ["cherrybomb", "Kirsch-Bombe"]],
		"unique": "Kirsch-Lifte tragen euch nach oben – von dort bombardiert ihr sie doppelt!",
		"intro": "Es duftet nach Karamell … und die Torte lächelt.",
	},
	"zephyros": {
		"name": "Zephyros", "title": "Der Herrscher der Lüfte", "board": "tower",
		"env": "sky", "backdrop": "sky", "ground": Color("#ffffff"), "tile": Color("#eaf3ff"),
		"layout": "NAUNCANUNANUCANUNANU",
		"abilities": [["gust", "Windböe"], ["whirl", "Aufwind-Wirbel"], ["seedstorm", "Pusteblumen-Sturm"]],
		"unique": "Höhenbonus: Von Aufwind-Feldern aus trefft ihr doppelt – und der Wind trägt euch weiter.",
		"intro": "Ganz oben am Wolkenturm dreht der Wind …",
	},
}

const BOARD_BOSS := {"dungeon": "ignis", "pirates": "klabautox", "sky": "astraios", "graveyard": "grabstein",
	"frost": "frostbart", "station": "galaxus", "glowforest": "noxumbra", "meadow": "baahemoth", "cake": "marquise", "tower": "zephyros"}

const FIELD_NAMES := {"N": "Feld", "A": "Angriff", "C": "Münzen", "R": "Brüchig", "H": "Sandbank", "K": "Wolkenkanone",
	"T": "Grabstein", "S": "Schneeball", "G": "Uhrwerk", "M": "Leuchtpilz", "D": "Duell", "L": "Kirsch-Lift", "P": "Schoko-Rutsche", "U": "Aufwind"}

const FIELD_COLORS := {"N": Color("#d8d2c8"), "A": Color("#ff5c6a"), "C": Color("#ffd23f"), "R": Color("#b07a5a"), "H": Color("#f0d890"),
	"K": Color("#9fd0ff"), "T": Color("#8a8a9a"), "S": Color("#ffffff"), "G": Color("#d9a441"), "M": Color("#5fffe0"),
	"D": Color("#ff9f1a"), "L": Color("#e0203a"), "P": Color("#7a4a32"), "U": Color("#bfe8ff")}


static func get_def(id: String) -> Dictionary:
	return BOSSES.get(id, BOSSES.zephyros)


static func for_board(board: String) -> String:
	return String(BOARD_BOSS.get(board, "baahemoth"))
