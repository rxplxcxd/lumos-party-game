extends Node
## Szenenwechsel mit Stern-Wipe. Router.goto("res://scenes/...tscn", {params})

signal scene_changed(path: String)

var params: Dictionary = {}
var busy := false

var _layer: CanvasLayer
var _rect: ColorRect
var _mat: ShaderMaterial
var _loading: Label
var pause_menu: PauseMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 90
	add_child(_layer)
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://assets/shaders/star_wipe.gdshader")
	_rect.material = _mat
	_layer.add_child(_rect)
	_set_radius(2.6)
	_loading = Label.new()
	_loading.text = "Lädt …"
	_loading.add_theme_font_override("font", load(Assets.FONT_TITLE))
	_loading.add_theme_font_size_override("font_size", 40)
	_loading.set_anchors_preset(Control.PRESET_CENTER)
	_loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading.position = Vector2(-120, -30)
	_loading.size = Vector2(240, 60)
	_loading.visible = false
	_layer.add_child(_loading)
	get_viewport().size_changed.connect(_update_aspect)
	_update_aspect()
	pause_menu = PauseMenu.new()
	add_child(pause_menu)


func _update_aspect() -> void:
	var s := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("aspect", s.x / maxf(s.y, 1.0))


func _set_radius(r: float) -> void:
	_mat.set_shader_parameter("radius", r)
	_mat.set_shader_parameter("rotation", (2.6 - r) * 0.9)
	_rect.visible = r < 2.55


func goto(path: String, p: Dictionary = {}) -> void:
	if busy:
		return
	busy = true
	params = p
	if "--log-scenes" in OS.get_cmdline_user_args():
		print("[SCENE] %s · Speicher %.0f MB · Objekte %d" % [path.get_file(), Performance.get_monitor(Performance.MEMORY_STATIC) / 1e6, int(Performance.get_monitor(Performance.OBJECT_COUNT))])
	Audio.sfx("whoosh")
	await _wipe(2.6, 0.0, 0.45)
	_loading.visible = true
	await get_tree().process_frame
	if pause_menu and pause_menu.open:
		pause_menu.close()
	get_tree().paused = false
	Juice.base_time_scale = 1.0
	InputHub.clear_virtual()
	InputHub.set_touch_profile("none")
	CutsceneManager.abort()
	# Erst die alte Szene vollständig freigeben, dann die neue laden – sonst liegen beide gleichzeitig im
	# Speicher (Spitzenlast genau beim Rücksprung aus Minispielen).
	if get_tree().current_scene:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	await get_tree().process_frame
	Assets.prune_cache()
	var ps: PackedScene = null
	if OS.has_feature("web"):
		# Web (ohne Threads): direkt laden – Thread-Laden kann dort bei manchen Szenen hängen bleiben
		await get_tree().process_frame
		ps = load(path) as PackedScene
	else:
		ResourceLoader.load_threaded_request(path)
		var waited := 0.0
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS and waited < 20.0:
			await get_tree().process_frame
			waited += get_process_delta_time()
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
			ps = ResourceLoader.load_threaded_get(path) as PackedScene
		if ps == null:
			ps = load(path) as PackedScene
	if ps == null and path != "res://scenes/menu/MainMenu.tscn":
		push_error("Szene konnte nicht geladen werden: " + path)
		ps = load("res://scenes/menu/MainMenu.tscn") as PackedScene
	get_tree().change_scene_to_packed(ps)
	await get_tree().process_frame
	await get_tree().process_frame
	_loading.visible = false
	scene_changed.emit(path)
	await _wipe(0.0, 2.6, 0.55)
	busy = false


func _wipe(from: float, to: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_method(_set_radius, from, to, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT if to > from else Tween.EASE_IN)
	await tw.finished


## Nur Ein-/Ausblenden ohne Szenenwechsel (z. B. zwischen Brettspiel-Phasen).
func cover() -> void:
	await _wipe(2.6, 0.0, 0.4)


func uncover() -> void:
	await _wipe(0.0, 2.6, 0.5)
