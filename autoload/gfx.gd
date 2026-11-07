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
var _fps_label: Label
var _current_fps := 60.0


func _ready() -> void:
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
	dynamic_scale = float(cfg.scale)
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = dynamic_scale
	vp.msaa_3d = cfg.msaa
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
	if n is DirectionalLight3D:
		var l := n as DirectionalLight3D
		if not l.has_meta("gfx_shadow_wanted"):
			l.set_meta("gfx_shadow_wanted", l.shadow_enabled)
		if not l.has_meta("gfx_dist"):
			l.set_meta("gfx_dist", l.directional_shadow_max_distance)
		l.shadow_enabled = bool(l.get_meta("gfx_shadow_wanted")) and bool(cfg.shadows)
		l.directional_shadow_max_distance = minf(float(l.get_meta("gfx_dist")), float(cfg.shadow_dist))
	elif n is WorldEnvironment and (n as WorldEnvironment).environment:
		var e := (n as WorldEnvironment).environment
		if not e.has_meta("gfx_glow_wanted"):
			e.set_meta("gfx_glow_wanted", e.glow_enabled)
		e.glow_enabled = bool(e.get_meta("gfx_glow_wanted")) and bool(cfg.glow)
	elif n is CPUParticles3D:
		var pp := n as CPUParticles3D
		if not pp.has_meta("gfx_amount"):
			pp.set_meta("gfx_amount", pp.amount)
			pp.amount = maxi(1, int(round(pp.amount * float(cfg.particles))))
	elif n is OmniLight3D and active == "low":
		(n as OmniLight3D).shadow_enabled = false


# --- Dynamische Auflösung -------------------------------------------------------------------

func _process(delta: float) -> void:
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
	if _current_fps < float(cfg.fps_target) - 8.0 and dynamic_scale > float(cfg.min_scale):
		dynamic_scale = maxf(float(cfg.min_scale), dynamic_scale - 0.08)
		vp.scaling_3d_scale = dynamic_scale
		_good_time = 0.0
	elif _current_fps > float(cfg.fps_target):
		_good_time += 1.0
		if _good_time > 5.0 and dynamic_scale < float(cfg.scale):
			dynamic_scale = minf(float(cfg.scale), dynamic_scale + 0.05)
			vp.scaling_3d_scale = dynamic_scale
			_good_time = 0.0
