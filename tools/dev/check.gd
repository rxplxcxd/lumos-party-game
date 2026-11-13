extends Node
## Lädt alle Skripte und Szenen des Projekts, um Parse-/Ladefehler zu finden.
## Andere Ordner (z. B. eigenständige Produktionen, die das Spiel nicht kennen darf) prüft man mit
##   -- --check-dirs=res://ordner[,res://weiterer]   (ersetzt die Standardliste)
func _ready() -> void:
	var bad := 0
	var files: Array[String] = []
	var dirs: Array[String] = ["res://autoload", "res://scripts", "res://scenes", "res://tools/charlab"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--check-dirs="):
			dirs.assign(a.trim_prefix("--check-dirs=").split(",", false))
	for d in dirs:
		_collect(d, files)
	for f in files:
		var r = load(f)
		if r == null:
			bad += 1
			printerr("LOAD FAIL: ", f)
		elif r is GDScript and not (r as GDScript).can_instantiate():
			bad += 1
			printerr("SCRIPT INVALID: ", f)
	print("checked %d files, %d problems" % [files.size(), bad])
	get_tree().quit(1 if bad > 0 else 0)

func _collect(dir: String, out: Array[String]) -> void:
	var da := DirAccess.open(dir)
	if da == null: return
	for f in da.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir + "/" + f)
	for sub in da.get_directories():
		_collect(dir + "/" + sub, out)
