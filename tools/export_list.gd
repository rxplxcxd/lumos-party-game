extends Node
## Erzeugt export_presets.cfg (Web/PWA) mit einer exakten Dateiliste:
## nur Assets, die der Katalog (Assets/Audio-Autoloads) tatsächlich referenziert, plus alle
## Skripte, Szenen, Ressourcen, Shader, Schriften, Musik und SFX. Abhängigkeiten (Texturen der
## Modelle) ergänzt Godot beim Export automatisch.
##
## godot --headless --path . res://tools/dev/Run.tscn -- --dev-script=res://tools/export_list.gd

const DIRS := ["res://autoload", "res://scripts", "res://scenes", "res://assets/animations", "res://assets/shaders",
	"res://assets/music", "res://assets/sfx", "res://assets/fonts"]
const EXT := ["gd", "tscn", "tres", "gdshader", "ogg", "ttf", "res"]


func run() -> void:
	var files := {}
	for p in Assets.all_paths():
		files[p] = true
	for p in Audio.all_paths():
		files[p] = true
	for d in DIRS:
		_collect(d, files)
	files["res://icon.svg"] = true
	var missing := 0
	for f in files.keys():
		if not FileAccess.file_exists(f) and not ResourceLoader.exists(f):
			push_error("Fehlt: " + f)
			missing += 1
	var list: Array = files.keys()
	list.sort()
	var quoted := PackedStringArray()
	for f in list:
		quoted.append("\"%s\"" % f)
	var cfg := PRESET.replace("$FILES", ", ".join(quoted))
	var fa := FileAccess.open("res://export_presets.cfg", FileAccess.WRITE)
	fa.store_string(cfg)
	fa.close()
	print("export_presets.cfg: %d Dateien, %d fehlend" % [list.size(), missing])


func _collect(dir: String, out: Dictionary) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	for f in da.get_files():
		if f.get_extension() in EXT:
			out[dir + "/" + f] = true
	for sub in da.get_directories():
		_collect(dir + "/" + sub, out)


const PRESET := """[preset.0]

name="Web"
platform="Web"
runnable=true
advanced_options=false
dedicated_server=false
custom_features="lumos"
export_filter="resources"
export_files=PackedStringArray($FILES)
include_filter=""
exclude_filter="tools/*"
export_path="build/web/index.html"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/custom_html_shell="res://web/shell.html"
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
progressive_web_app/ensure_cross_origin_isolation_headers=false
progressive_web_app/offline_page=""
progressive_web_app/display=1
progressive_web_app/orientation=1
progressive_web_app/icon_144x144=""
progressive_web_app/icon_180x180=""
progressive_web_app/icon_512x512=""
progressive_web_app/background_color=Color(0.09, 0.043, 0.2, 1)
"""
