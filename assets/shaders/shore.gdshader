// Uferkante: Flachwasser-Verlauf + wandernde Schaumbänder auf einem Ring um Inseln/Ufer (Premium-Visual-Überarbeitung).
// UV.x = 0 an der Uferlinie, 1 am äußeren Rand (dort ganz durchsichtig). Unbeleuchtet, ohne Tiefenschreiben:
// legt sich über das Meer, kostet nur die Ringfläche (kein Bildschirm-Effekt).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 shallow : source_color = vec4(0.55, 0.92, 0.9, 1.0);
uniform vec4 foam : source_color = vec4(1.0, 1.0, 0.97, 1.0);
uniform float shallow_alpha = 0.55;
uniform float foam_alpha = 0.85;
uniform float speed = 0.35;
uniform float bands = 3.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	float d = UV.x;
	float ang = UV.y;   // 0..1 rundherum
	float n = noise(vec2(ang * 60.0, TIME * 0.2)) * 0.5 + noise(vec2(ang * 160.0, d * 4.0 + TIME * 0.1)) * 0.5;
	// Schaum: direkt an der Uferlinie und zwei, drei Bänder, die nach außen laufen und vergehen
	float edge = 1.0 - smoothstep(0.0, 0.07 + n * 0.05, d);
	float wave = fract(d * bands - TIME * speed + n * 0.35);
	float band = smoothstep(0.82, 0.9, wave) * (1.0 - smoothstep(0.9, 1.0, wave)) * (1.0 - smoothstep(0.15, 0.75, d));
	float f = clamp(edge + band * (0.55 + n * 0.45), 0.0, 1.0);
	float sa = shallow_alpha * pow(1.0 - d, 1.6);
	ALBEDO = mix(shallow.rgb, foam.rgb, f);
	ALPHA = clamp(sa + f * foam_alpha * (1.0 - d), 0.0, 1.0);
}
