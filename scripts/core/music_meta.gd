class_name MusicMeta
## Automatisch erzeugt von tools/audio/build_music.py – nicht von Hand bearbeiten.
## Minispiel-Tracks: Abschnitte normal/hurry (nahtlose Loops in ganzen Takten, auf Ziel-BPM gestreckt)
## und outro (einmalig). Brett-/Menü-Tracks: nahtlose Loops. Jede Datei beginnt exakt auf einem Schlag.

const MINIGAME := [
	{
		"normal": {
			"file": "res://assets/music/minigame/mg1_normal.ogg",
			"bpm": 120.0,
			"native_bpm": 120.02,
			"start": 1.772,
			"bars": 20,
			"length": 39.995
		},
		"hurry": {
			"file": "res://assets/music/minigame/mg1_hurry.ogg",
			"bpm": 145.0,
			"native_bpm": 120.0,
			"start": 41.768,
			"bars": 14,
			"length": 23.185
		},
		"outro": {
			"file": "res://assets/music/minigame/mg1_outro.ogg",
			"bpm": 119.9,
			"start": 154.768,
			"length": 20.357
		}
	},
	{
		"normal": {
			"file": "res://assets/music/minigame/mg2_normal.ogg",
			"bpm": 110.0,
			"native_bpm": 109.96,
			"start": 1.94,
			"bars": 59,
			"length": 128.733
		},
		"hurry": {
			"file": "res://assets/music/minigame/mg2_hurry.ogg",
			"bpm": 138.0,
			"native_bpm": 109.98,
			"start": 132.856,
			"bars": 10,
			"length": 17.399
		},
		"outro": {
			"file": "res://assets/music/minigame/mg2_outro.ogg",
			"bpm": 109.68,
			"start": 157.912,
			"length": 14.94
		}
	},
	{
		"normal": {
			"file": "res://assets/music/minigame/mg3_normal.ogg",
			"bpm": 120.0,
			"native_bpm": 120.06,
			"start": 1.78,
			"bars": 68,
			"length": 135.99
		},
		"hurry": {
			"file": "res://assets/music/minigame/mg3_hurry.ogg",
			"bpm": 140.0,
			"native_bpm": 120.02,
			"start": 138.016,
			"bars": 7,
			"length": 12.008
		},
		"outro": {
			"file": "res://assets/music/minigame/mg3_outro.ogg",
			"bpm": 120.16,
			"start": 154.772,
			"length": 17.349
		}
	},
	{
		"normal": {
			"file": "res://assets/music/minigame/mg4_normal.ogg",
			"bpm": 115.0,
			"native_bpm": 120.0,
			"start": 1.764,
			"bars": 60,
			"length": 125.204
		},
		"hurry": {
			"file": "res://assets/music/minigame/mg4_hurry.ogg",
			"bpm": 145.0,
			"native_bpm": 119.98,
			"start": 120.76,
			"bars": 16,
			"length": 26.495
		},
		"outro": {
			"file": "res://assets/music/minigame/mg4_outro.ogg",
			"bpm": 119.94,
			"start": 153.764,
			"length": 13.394
		}
	}
]

const BOARDS := {
	"menu": {
		"file": "res://assets/music/board/menu.ogg",
		"bpm": 164.02,
		"start": 0.068,
		"bars": 72,
		"length": 105.353
	},
	"board_dungeon": {
		"file": "res://assets/music/board/dungeon.ogg",
		"bpm": 179.99,
		"start": 0.064,
		"bars": 128,
		"length": 170.676
	},
	"board_pirates": {
		"file": "res://assets/music/board/pirates.ogg",
		"bpm": 80.02,
		"start": 0.044,
		"bars": 56,
		"length": 167.958
	},
	"board_sky": {
		"file": "res://assets/music/board/sky.ogg",
		"bpm": 159.95,
		"start": 0.028,
		"bars": 106,
		"length": 159.05
	},
	"board_graveyard": {
		"file": "res://assets/music/board/graveyard.ogg",
		"bpm": 89.96,
		"start": 0.388,
		"bars": 56,
		"length": 149.4
	},
	"board_frost": {
		"file": "res://assets/music/board/frost.ogg",
		"bpm": 159.99,
		"start": 0.044,
		"bars": 108,
		"length": 162.01
	},
	"board_station": {
		"file": "res://assets/music/board/station.ogg",
		"bpm": 159.93,
		"start": 0.028,
		"bars": 102,
		"length": 153.067
	},
	"board_glowforest": {
		"file": "res://assets/music/board/glowforest.ogg",
		"bpm": 159.99,
		"start": 0.04,
		"bars": 110,
		"length": 165.01
	},
	"board_meadow": {
		"file": "res://assets/music/board/meadow.ogg",
		"bpm": 159.91,
		"start": 0.024,
		"bars": 104,
		"length": 156.088
	},
	"board_cake": {
		"file": "res://assets/music/board/cake.ogg",
		"bpm": 159.97,
		"start": 0.028,
		"bars": 100,
		"length": 150.028
	}
}
