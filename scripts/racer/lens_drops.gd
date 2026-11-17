class_name LensDrops
extends Control
## Wassertropfen auf der Kameralinse (Nitro Dash): entstehen situationsabhängig – Fahrt durch den Wasserfall, Treffer
## einer Fontäne, Gischt auf nasser Fahrbahn, Regen, Auftauchen – verlaufen mit dem Fahrtwind zum Bildrand und
## verschwinden nach 1–3 Sekunden wieder. Jeder Tropfen bricht das Bild dahinter wie eine kleine Linse (Bild steht
## darin kopf, heller Rand, Glanzpunkt). Die Bildmitte bleibt frei, die Dichte ist gedeckelt: Die Sicht auf die
## Strecke wird nie verdeckt. Ohne Tropfen ist der Knoten unsichtbar und kostet nichts.
##
##   splash(stärke)   Schwall (0..1): Wasserfall, Fontäne, Auftauchen
##   rain             Dauerregen/Gischt (Tropfen je Sekunde), z. B. 3 im Gewitter, bis 8 in der Gischt eines Vordermanns
##   wind             Fahrtwind 0..1 (Tempo): Tropfen wandern schneller nach außen

const MAX_DROPS := 28
const SHADER := "shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float h = sqrt(max(0.0, 1.0 - r * r));                      // Wölbung des Tropfens
	vec2 px = 1.0 / vec2(textureSize(screen_tex, 0));
	float size = COLOR.g * 64.0;                                // Radius in Pixeln (über die Farbe mitgegeben)
	vec2 uv = SCREEN_UV - p * (0.9 + 1.6 * (1.0 - h)) * size * px;    // Linse: Bild im Tropfen steht kopf und ist gestaucht
	vec3 col = texture(screen_tex, uv).rgb;
	col = mix(col, vec3(dot(col, vec3(0.33))), 0.12) * 1.1 + vec3(0.015, 0.03, 0.05);   // Wasser: etwas heller, kühler
	float rim = smoothstep(0.62, 1.0, r);
	col *= mix(1.0, 0.42, rim);                                  // dunkler Rand (Totalreflexion)
	col += vec3(0.55, 0.66, 0.78) * smoothstep(0.86, 1.0, r) * smoothstep(-0.2, 0.9, p.y) * 0.5;   // heller Unterrand
	float spec = smoothstep(0.80, 0.97, 1.0 - length(p - vec2(-0.36, -0.42)));
	col = mix(col, vec3(1.0), spec * 0.85);                      // Glanzpunkt
	float a = smoothstep(1.0, 0.86, r) * COLOR.a;
	COLOR = vec4(col, a);
}"

var rain := 0.0
var wind := 0.0
var _drops: Array[Dictionary] = []   # {p: Vector2 (0..1), r: px, life, max, v: Vector2, stretch}
var _acc := 0.0
var _rng := RandomNumberGenerator.new()
var _tex: Texture2D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	material = m
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_tex = ImageTexture.create_from_image(img)
	visible = false
	_rng.seed = 4711


## Schwall von Tropfen. strength 0..1 (1 = durch den Wasserfall gefahren).
func splash(strength := 1.0) -> void:
	for k in int(round(lerpf(4.0, 16.0, clampf(strength, 0.0, 1.0)))):
		_add(lerpf(0.7, 1.25, strength))


func _add(scale_f := 1.0) -> void:
	if _drops.size() >= MAX_DROPS:
		return
	# Nie mitten im Bild: Tropfen sitzen im äußeren Bereich (die Strecke voraus bleibt frei)
	var a := _rng.randf() * TAU
	var d := _rng.randf_range(0.42, 1.0)
	var p := Vector2(0.5, 0.5) + Vector2(cos(a) * 0.5, sin(a) * 0.5) * d
	p = p.clamp(Vector2(0.02, 0.03), Vector2(0.98, 0.97))
	var life := _rng.randf_range(1.1, 2.8)
	_drops.append({"p": p, "r": _rng.randf_range(12.0, 38.0) * scale_f * (get_viewport_rect().size.y / 720.0), "life": life, "max": life,
		"v": Vector2(_rng.randf_range(-0.01, 0.01), _rng.randf_range(0.015, 0.05)), "s": _rng.randf_range(1.0, 1.35)})


func _process(delta: float) -> void:
	if rain > 0.0:
		_acc += rain * delta
		while _acc >= 1.0:
			_acc -= 1.0
			_add(0.8)
	if _drops.is_empty():
		if visible:
			visible = false
		return
	visible = true
	var k := _drops.size() - 1
	while k >= 0:
		var d := _drops[k]
		d.life = float(d.life) - delta * (1.0 + wind * 0.8)
		if float(d.life) <= 0.0:
			_drops.remove_at(k)
		else:
			# Schwerkraft zieht nach unten, Fahrtwind drückt vom Bildzentrum nach außen; große Tropfen laufen schneller
			var out := ((d.p as Vector2) - Vector2(0.5, 0.45)).normalized()
			d.p = (d.p as Vector2) + ((d.v as Vector2) + out * wind * 0.09) * delta * (0.6 + float(d.r) / 30.0)
		k -= 1
	queue_redraw()


func _draw() -> void:
	for d in _drops:
		var u := float(d.life) / float(d.max)
		var alpha := smoothstep(0.0, 0.25, u) * smoothstep(1.0, 0.92, u)   # weich erscheinen und verschwinden
		var r := float(d.r) * (0.75 + 0.25 * u)
		var c := (d.p as Vector2) * get_viewport_rect().size
		var h := r * float(d.s) * (1.0 + wind * 0.25)   # läuft der Tropfen, zieht er sich in die Länge
		draw_texture_rect(_tex, Rect2(c - Vector2(r, h), Vector2(r, h) * 2.0), false, Color(1.0, clampf(r / 64.0, 0.0, 1.0), 1.0, alpha))
