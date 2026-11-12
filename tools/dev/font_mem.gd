extends Node
## Misst den Grafikspeicher der Schrift-Glyphen-Caches (53 Schriftgrößen mit Kontur) und ob UI.clear_font_caches()
## ihn wieder freigibt.   xvfb-run ./godot --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/font_mem.gd
func run() -> void:
	var tree := get_tree()
	get_parent().remove_child.call_deferred(self)
	tree.root.add_child.call_deferred(self)
	await tree.process_frame
	await tree.process_frame
	var layer := CanvasLayer.new()
	add_child(layer)
	await tree.process_frame
	var m0 := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1e6
	var labels: Array = []
	for sz in range(14, 120, 2):
		var l := UI.label("Ignis, der Seelenschmied 0123456789 Schmetterball!", sz, Color.WHITE, true, int(sz * 0.22))
		layer.add_child(l)
		l.position = Vector2(10, 10)
		labels.append(l)
		await tree.process_frame
	await tree.process_frame
	var m1 := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1e6
	for l in labels:
		l.queue_free()
	await tree.process_frame
	await tree.process_frame
	var m2 := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1e6
	UI.clear_font_caches()
	await tree.process_frame
	await tree.process_frame
	var m3 := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1e6
	print("FONTMEM vorher %.1f MB · 53 Größen %.1f MB · nach Freigabe der Labels %.1f MB · nach clear_font_caches %.1f MB" % [m0, m1, m2, m3])
	tree.quit()
