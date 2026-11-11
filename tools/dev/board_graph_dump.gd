extends Node
## Gibt die Feld-Graphen aller Bretter als JSON aus (Position, Typ, Nachfolger, Abzweig) – für Draufsicht-Karten.
##   godot --headless --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/board_graph_dump.gd
func run() -> void:
	var out := {}
	for id in BoardDefs.BOARDS.keys():
		var def := BoardDefs.get_def(id)
		var g := BoardDefs.build_graph(def)
		out[id] = g.map(func(s: Dictionary) -> Array: return [snappedf((s.pos as Vector3).x, 0.1), snappedf((s.pos as Vector3).z, 0.1), s.type, s.next, s.branch])
	print("GRAPH " + JSON.stringify(out))
	get_tree().quit()
