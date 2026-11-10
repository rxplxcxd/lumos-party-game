extends Node
## Grafik-Manager: Presets (Niedrig/Mittel/Hoch/Ultra), automatisches Hardware-Profiling und
## dynamische Auflösung für stabile 60 FPS auf Smartphones, alten Notebooks und Handhelds im Akkubetrieb.
##
## Greift global ein: jedes neu hinzugefügte DirectionalLight3D, WorldEnvironment und CPUParticles3D
## wird beim Eintritt in den Baum an das aktive Preset angepasst – Szenen müssen nichts wissen.

signal preset_changed(name: String)

const PRESETS := {
	"low": {"label": "Niedrig", "scale": 0.62, "min_scale": 0.5, "msaa": Viewport.MSAA_DISABLED, "shadows": false, "shadow_size": 1024,
		"shadow_dist": 35.0, "glow": false, "particles": 0.45, "detail": 0.5, "fps_target": 55.0},
	"medium": {"label": "Mittel", "scale": 0.8, "min_scale": 0.6, "msaa": Viewport.MSAA_DISABLED, "shadows": true, "shadow_size": 1024,
		"shadow_dist": 45.0, "glow": true, "particles": 0.75, "detail": 0.8, "fps_target": 57.0},
	"high": {"label": "Hoch", "scale": 1.0, "min_scale": 0.7, "msaa": Viewport.MSAA_2X, "shadows": true, "shadow_size": 2048,
		"shadow_dist": 70.0, "glow": true, "particles": 1.0, "detail": 1.0, "fps_target": 57.0},
	"ultra": {"label": "Ultra", "scale": 1.0, "min_scale": 0.85, "msaa": Viewport.MSAA_4X, "shadows": true, "shadow_size": 4096,
		"shadow_dist": 100.0, "glow": true, "particles": 1.3, "detail": 1.25, "fps_target": 58.0},
}
const ORDER := ["low", "medium", "high", "ultra"]

var active := "high"
var detected := "high"
var hardware := {}
var dynamic_scale := 1.0
var on_battery := false

var _fps_acc := 0.0
var _fps_frames := 0
var _good_time := 0.0
var _bad_time := 0.0
var _pending_mesh: Array[Node] = []
var _tuned_meshes := {}
var _lod_rigs: Array[CharacterRig] = []
var _lod_frame := 0
var _fps_label: Label
var _current_fps := 60.0


func _ready() -> void:
	get_viewport().size_changed.connect(func() -> void:
		var cap := minf(float(preset().scale), _pixel_cap())
		if dynamic_scale > cap:
			dynamic_scale = cap
			get_viewport().scaling_3d_scale = cap)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_profile_hardware()
	get_tree().node_added.connect(_on_node_added)
	EventBus.settings_changed.connect(apply)
	var layer := CanvasLayer.new()
	layer.layer = 95
	add_child(layer)
	_fps_label = Label.new()
	_fps_label.position = Vector2(8, 4)
	_fps_label.add_theme_font_size_override("font_size", 16)
	_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_label.add_theme_constant_override("outline_size", 4)
	layer.add_child(_fps_label)
	apply.call_deferred()


func preset() -> Dictionary:
	return PRESETS[active]


func particles_mult() -> float:
	return float(preset().particles)


func detail() -> float:
	return float(preset().detail)


# --- Hardware-Profiling ------------------------------------------------------------------

func _profile_hardware() -> void:
	var cores := OS.get_processor_count()
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	var mem_gb := float(OS.get_memory_info().get("physical", 0)) / 1e9
	var mobile := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	if OS.has_feature("web"):
		var info = JavaScriptBridge.eval("""(function(){
			var c=document.createElement('canvas'),gl=c.getContext('webgl2')||c.getContext('webgl'),r='';
			if(gl){var e=gl.getExtension('WEBGL_debug_renderer_info');r=e?gl.getParameter(e.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER);}
			var m=/Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent)||(navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1);
			if(navigator.getBattery){navigator.getBattery().then(function(b){window.__lumosBattery={charging:b.charging,level:b.level};});}
			return JSON.stringify({cores:navigator.hardwareConcurrency||4,mem:navigator.deviceMemory||0,gpu:r||'',mobile:m});
		})()""", true)
		if info is String:
			var d = JSON.parse_string(info)
			if d is Dictionary:
				cores = int(d.get("cores", cores))
				mem_gb = float(d.get("mem", 0))
				gpu = String(d.get("gpu", gpu)).to_lower()
				mobile = mobile or bool(d.get("mobile", false))
	var software := gpu.contains("swiftshader") or gpu.contains("llvmpipe") or gpu.contains("software")
	var integrated := gpu.contains("intel") or gpu.contains("uhd") or gpu.contains("iris") or gpu.contains("mali") or gpu.contains("adreno") or gpu.contains("powervr") or gpu.contains("apple gpu")
	var amd_apu := gpu.contains("radeon") and (gpu.contains("graphics") or gpu.contains("780m") or gpu.contains("680m") or gpu.contains("vega"))
	var p := "high"
	if software or (cores > 0 and cores <= 2) or (mem_gb > 0.0 and mem_gb < 2.5):
		p = "low"
	elif mobile:
		p = "medium" if (cores >= 6 and (mem_gb == 0.0 or mem_gb >= 4.0)) else "low"
	elif integrated or amd_apu or Game.is_lumos_device:
		p = "medium"
	elif cores >= 8 and not integrated:
		p = "high"
	detected = p
	hardware = {"cores": cores, "memory_gb": snappedf(mem_gb, 0.1), "gpu": gpu, "mobile": mobile, "software": software}


## 3D-Pixelbudget: Hochauflösende Displays (Retina/4K, Browser mit devicePixelRatio 2–3) rendern sonst
## ein Vielfaches der nötigen Pixel. Die 3D-Szene wird auf ~1700 px Breite (Ultra: 2200) begrenzt und
## hochskaliert; die UI bleibt gestochen scharf.
func _pixel_cap() -> float:
	var w := float(get_viewport().get_visible_rect().size.x)
	if w <= 0.0:
		return 1.0
	var budget := 2200.0 if active == "ultra" else 1700.0
	return clampf(budget / w, 0.35, 1.0)


func _effective_preset() -> String:
	var q: String = Game.settings.get("quality", "auto")
	if q in PRESETS:
		return q
	var p := detected
	if on_battery and ORDER.find(p) > 1:
		p = "medium"   # Akkubetrieb: höchstens Mittel
	return p


func apply() -> void:
	var p := _effective_preset()
	var changed := p != active
	active = p
	var cfg := preset()
	dynamic_scale = minf(float(cfg.scale), _pixel_cap())
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = dynamic_scale
	# WebGL: MSAA kostet im Browser überproportional – dort nur bei „Ultra“
	vp.msaa_3d = cfg.msaa if not OS.has_feature("web") or active == "ultra" else Viewport.MSAA_DISABLED
	RenderingServer.directional_shadow_atlas_set_size(int(cfg.shadow_size), true)
	_walk(get_tree().root)
	_fps_label.visible = bool(Game.settings.get("show_fps", false))
	if changed:
		preset_changed.emit(active)


func _walk(n: Node) -> void:
	_tune(n)
	for c in n.get_children():
		_walk(c)


func _on_node_added(n: Node) -> void:
	_tune(n)


func _tune(n: Node) -> void:
	var cfg := preset()
	if n is MeshInstance3D or n is CharacterRig:
		_pending_mesh.append(n)   # erst im nächsten Bild – dann stehen Mesh, Position und Skalierung fest
		return
	if n is DirectionalLight3D:
		var l := n as DirectionalLight3D
		if not l.has_meta("gfx_shadow_wanted"):
			l.set_meta("gfx_shadow_wanted", l.shadow_enabled)
		if not l.has_meta("gfx_dist"):
			l.set_meta("gfx_dist", l.directional_shadow_max_distance)
		l.shadow_enabled = bool(l.get_meta("gfx_shadow_wanted")) and bool(cfg.shadows)
		l.directional_shadow_max_distance = minf(float(l.get_meta("gfx_dist")), float(cfg.shadow_dist) * (0.7 if OS.has_feature("web") else 1.0))
		if not l.has_meta("gfx_mode"):
			l.set_meta("gfx_mode", l.directional_shadow_mode)
		# Eine Schattenkaskade statt zwei halbiert die Schatten-Renderdurchgänge (Browser & schwache Stufen)
		l.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if (OS.has_feature("web") and ORDER.find(active) < 2) or active == "low" else int(l.get_meta("gfx_mode"))
	elif n is WorldEnvironment and (n as WorldEnvironment).environment:
		var e := (n as WorldEnvironment).environment
		if not e.has_meta("gfx_glow_wanted"):
			e.set_meta("gfx_glow_wanted", e.glow_enabled)
		e.glow_enabled = bool(e.get_meta("gfx_glow_wanted")) and bool(cfg.glow) and not (OS.has_feature("web") and active != "ultra")
	elif n is CPUParticles3D:
		var pp := n as CPUParticles3D
		if not pp.has_meta("gfx_amount"):
			pp.set_meta("gfx_amount", pp.amount)
			pp.amount = maxi(1, int(round(pp.amount * float(cfg.particles) * (0.7 if OS.has_feature("web") else 1.0))))
	elif n is OmniLight3D or n is SpotLight3D:
		# Fackeln, Lampen & Co.: weit entfernte Lichter ausblenden (kostet sonst pro Pixel jedes Objekts)
		var ol := n as Light3D
		if active == "low":
			ol.shadow_enabled = false
		ol.distance_fade_enabled = true
		ol.distance_fade_begin = 22.0 + 18.0 * float(cfg.detail)
		ol.distance_fade_length = 8.0
		ol.distance_fade_shadow = 15.0


# --- Geometrie-Diät (gilt für alle Szenen & Plattformen) --------------------------------------------------

## Prozedurale Grundkörper (WorldKit & Co.) kommen mit 64 Segmenten – im Cartoon-Look unsichtbar, aber
## tausende Dreiecke pro Kugel. Kleine Deko wirft keinen Schatten und verschwindet in großer Entfernung.
## Figuren (CharacterRig/Kart) bleiben unangetastet.
func _tune_mesh(mi: MeshInstance3D) -> void:
	var m := mi.mesh
	if m == null:
		return
	if not _tuned_meshes.has(m):
		_tuned_meshes[m] = true
		if m is SphereMesh:
			(m as SphereMesh).radial_segments = mini((m as SphereMesh).radial_segments, 20)
			(m as SphereMesh).rings = mini((m as SphereMesh).rings, 10)
		elif m is CapsuleMesh:
			(m as CapsuleMesh).radial_segments = mini((m as CapsuleMesh).radial_segments, 16)
			(m as CapsuleMesh).rings = mini((m as CapsuleMesh).rings, 4)
		elif m is CylinderMesh:
			(m as CylinderMesh).radial_segments = mini((m as CylinderMesh).radial_segments, 24 if maxf((m as CylinderMesh).top_radius, (m as CylinderMesh).bottom_radius) > 4.0 else 14)
			(m as CylinderMesh).rings = 0
		elif m is TorusMesh:
			(m as TorusMesh).rings = mini((m as TorusMesh).rings, 28)
			(m as TorusMesh).ring_segments = mini((m as TorusMesh).ring_segments, 10)
	if _in_character(mi):
		return
	var size := m.get_aabb().size * mi.global_basis.get_scale().abs()
	var ext := maxf(size.x, maxf(size.y, size.z))
	if ext < 1.4 and mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if mi.visibility_range_end == 0.0 and ext < 2.5:
		mi.visibility_range_end = (60.0 if ext < 0.7 else 110.0) * (0.75 + 0.25 * float(preset().detail))
		mi.visibility_range_end_margin = 4.0


# --- Animations-LOD für Statisten (Zuschauer, Tiere, NPCs – nie Spielfiguren) ------------------------------

func _register_lod(r: CharacterRig) -> void:
	if r.player >= 0 or r.anim == null or r.has_meta("gfx_lod"):
		return
	r.set_meta("gfx_lod", randi() % 4)   # Phase, damit nicht alle im selben Bild rechnen
	r.set_meta("gfx_acc", 0.0)
	r.anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_lod_rigs.append(r)


## Nah: jedes Bild · mittel (> 16 m): jedes 2. · fern (> 34 m) oder unsichtbar: jedes 4. Bild.
func _anim_lod(delta: float) -> void:
	if _lod_rigs.is_empty():
		return
	_lod_frame += 1
	var cam := get_viewport().get_camera_3d()
	var cp := cam.global_position if cam else Vector3.ZERO
	var near := 16.0 * (0.8 + 0.2 * float(preset().detail))
	var i := _lod_rigs.size() - 1
	while i >= 0:
		var r := _lod_rigs[i]
		if not is_instance_valid(r) or not r.is_inside_tree() or r.anim == null:
			_lod_rigs.remove_at(i)
			i -= 1
			continue
		var acc := float(r.get_meta("gfx_acc")) + delta
		var d := r.global_position.distance_to(cp)
		var step := 1 if d < near else (2 if d < near * 2.1 else 4)
		if not r.is_visible_in_tree():
			step = 4
		if (_lod_frame + int(r.get_meta("gfx_lod"))) % step == 0:
			r.anim.advance(acc)
			acc = 0.0
		r.set_meta("gfx_acc", acc)
		if r.modifier:
			r.modifier.active = d < near
		i -= 1


func _in_character(n: Node) -> bool:
	var p := n.get_parent()
	for i in 7:
		if p == null:
			return false
		if p is CharacterRig or p is KartVisual:
			return true
		p = p.get_parent()
	return false


# --- Dynamische Auflösung -------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _pending_mesh.is_empty():
		var batch := _pending_mesh
		_pending_mesh = []
		for m in batch:
			if is_instance_valid(m) and m.is_inside_tree():
				if m is CharacterRig:
					_register_lod(m as CharacterRig)
				else:
					_tune_mesh(m as MeshInstance3D)
	_anim_lod(delta)
	var real := delta / maxf(Engine.time_scale, 0.01)
	_fps_acc += real
	_fps_frames += 1
	if _fps_acc < 1.0:
		return
	_current_fps = _fps_frames / _fps_acc
	_fps_acc = 0.0
	_fps_frames = 0
	if _fps_label.visible:
		_fps_label.text = "%d FPS · %s · %d%%" % [int(_current_fps), preset().label, int(dynamic_scale * 100)]
	if OS.has_feature("web"):
		var b = JavaScriptBridge.eval("window.__lumosBattery?JSON.stringify(window.__lumosBattery):''", true)
		if b is String and b != "":
			var bd = JSON.parse_string(b)
			if bd is Dictionary:
				var batt := not bool(bd.get("charging", true))
				if batt != on_battery:
					on_battery = batt
					apply()
	if not Game.settings.get("dynamic_res", true):
		return
	var cfg := preset()
	var vp := get_viewport()
	var top := minf(float(cfg.scale), _pixel_cap())
	var floor_s := minf(float(cfg.min_scale), top)
	if _current_fps < float(cfg.fps_target) - 8.0:
		_good_time = 0.0
		if dynamic_scale > floor_s + 0.001:
			dynamic_scale = maxf(floor_s, dynamic_scale - 0.08)
			vp.scaling_3d_scale = dynamic_scale
			_bad_time = 0.0
		else:
			# Schon an der Untergrenze und immer noch zu langsam → eine Qualitätsstufe runter (nur bei „Auto“)
			_bad_time += 1.0
			if _bad_time >= 4.0 and Game.settings.get("quality", "auto") == "auto" and ORDER.find(detected) > 0:
				_bad_time = 0.0
				detected = ORDER[ORDER.find(detected) - 1]
				apply()
	elif _current_fps > float(cfg.fps_target):
		_bad_time = 0.0
		_good_time += 1.0
		if _good_time > 5.0 and dynamic_scale < top:
			dynamic_scale = minf(top, dynamic_scale + 0.05)
			vp.scaling_3d_scale = dynamic_scale
			_good_time = 0.0
