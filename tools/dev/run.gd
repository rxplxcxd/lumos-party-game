extends Node
## Dev-Runner: führt ein Skript mit aktiven Autoloads aus.
## godot --headless --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/xyz.gd
func _ready() -> void:
	var path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dev-script="):
			path = a.substr(13)
	if path == "":
		printerr("kein --dev-script angegeben"); get_tree().quit(1); return
	var s: GDScript = load(path)
	var obj = s.new()
	add_child(obj)
	await obj.run()
	get_tree().quit(0)
