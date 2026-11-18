class_name LumosMaterials
extends RefCounted
## Lumos-Materialbibliothek (Premium-Visual-Überarbeitung): EIN Oberflächen-Shader (assets/shaders/lumos_surface.gdshader)
## für alle Materialfamilien, Varianten nur über Parameter. Die Palettenfarbe bleibt die Grundfarbe, die Textur
## (JulioVII, aufbereitet von tools/assets/build_surfaces.py) liefert Detail, Rauheit und Normalmap.
##   LumosMaterials.surface("grass", Color("#7fd36a"))      → Material für Böden/Wände/Primitive
##   LumosMaterials.surface("lava_rock")                    → eigene Farben der Textur (ohne Palettenfarbe)
## Einstellung „Oberflächen-Details“ (Game.settings.surface_detail) aus → bisheriges einfarbiges Material.
## Grafikstufe → Shader-Stufe: Niedrig 0 (nur Farbe) · Mittel 1 (+ Normalmap) · Hoch/Ultra 2 (volle Projektion).
## Regeln und Budgets: docs/VISUAL_STANDARD.md.

const DIR := "res://assets/materials/surfaces/"
const SHADER := "res://assets/shaders/lumos_surface.gdshader"

## Familie: tile = Kachelgröße (m) · rough = Rauheitsbereich · normal/color = Stärke · metal/spec · macro = Großflächen-
## variation · own = gedacht für eigene Texturfarbe (Aufruf ohne Farbe) · glow = Leuchten der hellen Stellen (Lavastein)
const FAMILIES := {
	"grass": {"tile": 3.5, "rough": [0.86, 0.98], "normal": 0.8, "color": 0.9, "macro": 0.14},
	"meadow": {"tile": 4.0, "rough": [0.86, 0.98], "normal": 0.8, "color": 0.9, "macro": 0.12},
	"dirt": {"tile": 3.0, "rough": [0.86, 1.0], "normal": 0.9, "color": 0.9, "macro": 0.1},
	"sand": {"tile": 3.5, "rough": [0.88, 1.0], "normal": 0.85, "color": 0.75, "macro": 0.1},
	"dune": {"tile": 6.0, "rough": [0.86, 1.0], "normal": 0.9, "color": 0.75, "macro": 0.1},
	"pebbles": {"tile": 2.0, "rough": [0.74, 0.95], "normal": 1.0, "color": 0.9, "macro": 0.08},
	"flagstone": {"tile": 3.0, "rough": [0.74, 0.95], "normal": 1.0, "color": 0.9, "macro": 0.08},
	"cobble_moss": {"tile": 2.5, "rough": [0.74, 0.95], "normal": 1.0, "color": 0.9, "macro": 0.08},
	"rock": {"tile": 3.0, "rough": [0.7, 0.95], "normal": 1.1, "color": 0.85, "macro": 0.1},
	"cliff": {"tile": 5.0, "rough": [0.7, 0.95], "normal": 1.0, "color": 0.85, "macro": 0.1},
	"stone_wall": {"tile": 2.5, "rough": [0.7, 0.92], "normal": 1.0, "color": 0.85, "macro": 0.06},
	"bricks": {"tile": 2.0, "rough": [0.72, 0.92], "normal": 1.0, "color": 0.8, "macro": 0.06},
	"plaster": {"tile": 3.0, "rough": [0.82, 0.95], "normal": 0.7, "color": 0.55, "macro": 0.06},
	"planks": {"tile": 2.4, "rough": [0.62, 0.86], "normal": 1.0, "color": 0.85, "macro": 0.06},
	"wood": {"tile": 1.6, "rough": [0.6, 0.86], "normal": 0.8, "color": 0.8, "macro": 0.04},
	"bark": {"tile": 1.5, "rough": [0.75, 0.95], "normal": 1.0, "color": 0.85, "macro": 0.04},
	"roof": {"tile": 2.0, "rough": [0.6, 0.86], "normal": 1.0, "color": 0.85, "macro": 0.06},
	"metal": {"tile": 2.0, "rough": [0.32, 0.55], "normal": 0.7, "color": 0.7, "metal": 0.55, "spec": 0.5, "macro": 0.04},
	"snow": {"tile": 4.0, "rough": [0.55, 0.8], "normal": 0.7, "color": 0.6, "spec": 0.45, "macro": 0.06},
	"ice": {"tile": 3.0, "rough": [0.08, 0.3], "normal": 0.6, "color": 0.7, "spec": 0.6, "macro": 0.05},
	"tiles": {"tile": 1.6, "rough": [0.28, 0.6], "normal": 0.8, "color": 0.8, "spec": 0.5, "macro": 0.03},
	"paving": {"tile": 2.5, "rough": [0.7, 0.95], "normal": 1.0, "color": 0.9, "macro": 0.06},
	"concrete": {"tile": 3.0, "rough": [0.78, 0.95], "normal": 0.7, "color": 0.7, "macro": 0.06},
	"lava_rock": {"tile": 3.0, "rough": [0.6, 0.95], "normal": 1.1, "color": 1.0, "macro": 0.06, "own": true, "glow": 1.6},
	"fabric": {"tile": 1.0, "rough": [0.86, 1.0], "normal": 0.7, "color": 0.7, "macro": 0.03},
}

## Materialnamen importierter Modelle → Familie (nur Pakete mit sprechenden Namen; Farbatlas-Modelle bleiben, wie sie
## sind – ihre Palette ist der Stil). Detail dort schwächer und im Objektraum (wandert mit bewegten Teilen mit).
const MODEL_NAMES := {
	"grass": "grass", "dirt": "dirt", "dirtDark": "dirt", "stone": "rock", "stoneDark": "rock", "rock": "rock",
	"rockDark": "rock", "rockTrack": "rock", "woodBark": "bark", "woodBarkDark": "bark", "wood": "wood",
	"woodDark": "wood", "woodInner": "wood", "sand": "sand", "Rock": "rock", "Rock_Grey": "rock", "Wood": "wood",
	"Wood_Light": "wood", "Dirt_1": "dirt", "Dirt_2": "dirt", "Dirt_3": "dirt", "Stone": "rock", "metal": "metal",
	"metalDark": "metal", "Metal": "metal", "DarkMetal": "metal",
}
const MODEL_STRENGTH := 0.65   # Farbe/Normalmap auf Modellen schwächer als auf großen Flächen
const MODEL_TILE := 0.6        # Kachel auf Modellen kleiner (Requisiten sind klein)
const GLOSSY_OK := ["glass", "glow", "ice", "crystal", "water", "metallic", "gold", "chrome", "gem", "lens", "screen"]

static var _shader: Shader
static var _shader_2s: Shader   # doppelseitig (Böschungen, offene Meshes)
static var _tex := {}       # Familie → [Albedo, Normal]
static var _cache := {}     # Schlüssel → ShaderMaterial
static var _used := {}      # Schlüssel → Szenen-Generation (Aufräumen wie Assets.prune_cache)
static var _gen := 0
static var _model_conv := {}   # Instanz-ID des Modellmaterials → umgewandeltes Material (oder null)


static func enabled() -> bool:
	return bool(Game.settings.get("surface_detail", true))


static func quality_level() -> int:
	match Gfx.active:
		"low":
			return 0
		"medium":
			return 1
	return 2


static func has_family(family: String) -> bool:
	return FAMILIES.has(family) and ResourceLoader.exists(DIR + family + "_albedo.webp")


## Material einer Familie in einer Palettenfarbe. color.a == 0 → eigene Texturfarbe. Ohne Einstellung oder ohne
## Textur: bisheriges einfarbiges Material (WorldKit-Standard) – das Spiel sieht dann aus wie vorher.
static func surface(family: String, color := Color(0, 0, 0, 0), opts := {}) -> Material:
	if not enabled() or not has_family(family):
		return _flat(color if color.a > 0.0 else _own_color(family), float(opts.get("rough", 0.85)))
	var key := "%s|%s|%s" % [family, color.to_html(true), str(opts)]
	_used[key] = _gen
	if _cache.has(key):
		return _cache[key]
	var f: Dictionary = FAMILIES[family]
	if _shader == null:
		_shader = load(SHADER)
	var tx := _textures(family)
	var m := ShaderMaterial.new()
	m.shader = _shader
	if bool(opts.get("double_sided", false)):
		if _shader_2s == null:
			_shader_2s = Shader.new()
			_shader_2s.code = _shader.code.replace("cull_back", "cull_disabled")
		m.shader = _shader_2s
	m.set_shader_parameter("tint", _own_color(family) if color.a == 0.0 else color)
	m.set_shader_parameter("detail_albedo", tx[0])
	m.set_shader_parameter("detail_normal", tx[1])
	m.set_shader_parameter("k", float(_stat(family).get("k", 0.7)))
	m.set_shader_parameter("ks", float(_stat(family).get("ks", 0.85)))
	m.set_shader_parameter("space_probe", Color(0.5, 0.5, 0.5))
	m.set_shader_parameter("tile", float(opts.get("tile", f.tile)))
	var cs := float(opts.get("strength", 1.0))
	m.set_shader_parameter("color_strength", float(f.color) * cs)
	m.set_shader_parameter("normal_strength", float(f.normal) * float(opts.get("normal", cs)))
	var rr: Array = f.rough
	m.set_shader_parameter("rough_min", float(rr[0]))
	m.set_shader_parameter("rough_max", float(rr[1]))
	m.set_shader_parameter("metallic_value", float(opts.get("metal", f.get("metal", 0.0))))
	m.set_shader_parameter("specular_value", float(f.get("spec", 0.4)))
	m.set_shader_parameter("macro_strength", float(f.get("macro", 0.08)) * cs)
	m.set_shader_parameter("object_space", bool(opts.get("object_space", false)))
	m.set_shader_parameter("quality", quality_level())
	if f.has("glow"):
		m.set_shader_parameter("emission_energy", float(f.glow))
	m.set_meta("lumos_family", family)
	_cache[key] = m
	return m


## Ursprüngliches Material hinter einem umgewandelten (für Einfärben/Ausblenden: Assets.tint, Verdeckungs-Fades).
static func source_of(m: Material) -> Material:
	if m and m.has_meta("lumos_src"):
		return m.get_meta("lumos_src")
	return m


## Importiertes Modellmaterial vereinheitlichen (immer, unabhängig von der Einstellung – Fehlerkorrektur):
## Nature-/Space-Kit kommen mit metallic = 1 aus dem glTF (Standardwert, vom Exporter nicht gesetzt) – Bäume, Felsen,
## Klippen wirkten dunkel und spiegelten den Himmel. Glänzender Kunststoff (Rauheit unter 0,45) wird auf 0,55 angehoben,
## Glas/Leuchtteile/Metall bleiben.
static func normalize_model(m: BaseMaterial3D) -> void:
	if m.has_meta("lumos_norm"):
		return
	m.set_meta("lumos_norm", true)
	var n := String(m.resource_name).to_lower()
	var glossy_ok := false
	for g: String in GLOSSY_OK:
		if g in n:
			glossy_ok = true
	var metal_name := "metal" in n or "chrome" in n or "gold" in n
	if m.metallic > 0.9 and not metal_name:
		m.metallic = 0.0
	elif m.metallic > 0.9:
		m.metallic = 0.5
		m.roughness = maxf(m.roughness * 0.5, 0.45)
	if not glossy_ok and m.metallic < 0.3 and m.roughness < 0.45 and m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		m.roughness = 0.55   # KayKit-Platformer 0,3, Mini-Game 0,2/0,4, City Builder 0,4; Figuren (0,5) bleiben unverändert


## Detail-Variante eines Modellmaterials (oder null, wenn der Name keine Familie hat / Einstellung aus).
static func for_model(m: BaseMaterial3D) -> Material:
	if not enabled():
		return null
	var id := m.get_instance_id()
	if _model_conv.has(id):
		var c: Variant = _model_conv[id]
		if c != null:
			_used[c.get_meta("lumos_key")] = _gen
		return c
	var fam: String = MODEL_NAMES.get(String(m.resource_name), "")
	var out: Material = null
	if fam != "" and has_family(fam) and m.albedo_texture == null and m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		var f: Dictionary = FAMILIES[fam]
		var col := m.albedo_color
		col.a = 1.0
		var opts := {"tile": float(f.tile) * MODEL_TILE, "strength": MODEL_STRENGTH, "object_space": true, "metal": m.metallic}
		var sm := surface(fam, col, opts) as ShaderMaterial
		if sm:
			sm = sm.duplicate() as ShaderMaterial   # eigenes Exemplar je Quelle (Rückweg für Einfärben)
			sm.set_meta("lumos_src", m)
			sm.set_meta("lumos_key", "model|%d" % id)
			_cache["model|%d" % id] = sm
			_used["model|%d" % id] = _gen
			out = sm
	_model_conv[id] = out
	return out


## Alle Materialien eines frisch instanzierten Modells: vereinheitlichen und – wo sinnvoll – Detail aufsetzen.
static func apply_to_model(root: Node) -> void:
	for mi in Assets.find_meshes(root):
		var mesh := mi.mesh
		if mesh == null:
			continue
		for si in mesh.get_surface_count():
			var m := mesh.surface_get_material(si) as BaseMaterial3D
			if m == null:
				continue
			normalize_model(m)
			if mi.get_surface_override_material(si) == null:
				var c := for_model(m)
				if c:
					mi.set_surface_override_material(si, c)


## Grafikstufe gewechselt: Shader-Stufe in allen lebenden Materialien nachziehen.
static func refresh_quality() -> void:
	var q := quality_level()
	for k in _cache:
		var m := _cache[k] as ShaderMaterial
		if m:
			m.set_shader_parameter("quality", q)


## Beim Szenenwechsel (Assets.prune_cache): Materialien, die zwei Szenen lang ungenutzt waren, freigeben – samt
## Texturen, wenn keine Familie sie mehr braucht (Grafikspeicher im Browser).
static func prune() -> void:
	_gen += 1
	for k in _cache.keys():
		if int(_used.get(k, -99)) < _gen - 2:
			_cache.erase(k)
			_used.erase(k)
	for id in _model_conv.keys():
		var c: Variant = _model_conv[id]
		if c != null and not _cache.has(String((c as Material).get_meta("lumos_key"))):
			_model_conv.erase(id)
	var live := {}
	for k in _cache:
		live[String((_cache[k] as Material).get_meta("lumos_family", ""))] = true
	for fam in _tex.keys():
		if not live.has(fam):
			_tex.erase(fam)


## Beim Beenden: alle statischen Verweise lösen (sonst meldet Godot Shader/Materialien als „leaked at exit“).
static func clear_cache() -> void:
	_cache.clear()
	_used.clear()
	_model_conv.clear()
	_tex.clear()
	_shader = null
	_shader_2s = null


static func cached_count() -> int:
	return _cache.size()


static func loaded_families() -> Array:
	return _tex.keys()


static func _textures(family: String) -> Array:
	if not _tex.has(family):
		_tex[family] = [load(DIR + family + "_albedo.webp"), load(DIR + family + "_normal.webp")]
	return _tex[family]


static func _stat(family: String) -> Dictionary:
	return SurfaceStats.DATA.get(family, {})


static func _own_color(family: String) -> Color:
	var mc: Array = _stat(family).get("mean", [0.8, 0.8, 0.8])
	return Color(float(mc[0]), float(mc[1]), float(mc[2]))


static func _flat(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m
