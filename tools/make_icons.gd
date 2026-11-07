extends Node
## Rendert die PWA-/Store-Icons aus icon.svg (Godot-eigener SVG-Rasterizer).
## godot --headless --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/make_icons.gd
func run() -> void:
	var svg := FileAccess.get_file_as_string("res://icon.svg")
	for size in [180, 192, 512, 1024]:
		var img := Image.new()
		img.load_svg_from_string(svg, size / 512.0)
		img.save_png("res://web/icons/icon-%d.png" % size)
	# maskable: Motiv in der sicheren Zone (80 %), Hintergrund vollflächig
	var bg := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	bg.fill(Color("#7b3cff"))
	var inner := Image.new()
	inner.load_svg_from_string(svg, 0.72)
	bg.blend_rect(inner, Rect2i(Vector2i.ZERO, inner.get_size()), Vector2i((512 - inner.get_width()) / 2, (512 - inner.get_height()) / 2))
	bg.save_png("res://web/icons/icon-maskable-512.png")
	print("Icons geschrieben")
