// Fließende Lava mit dunkler Kruste und glühenden Adern.
shader_type spatial;
render_mode unshaded;

uniform vec4 hot : source_color = vec4(1.0, 0.75, 0.15, 1.0);
uniform vec4 warm : source_color = vec4(1.0, 0.3, 0.05, 1.0);
uniform vec4 crust : source_color = vec4(0.18, 0.06, 0.05, 1.0);
uniform vec2 flow = vec2(0.0, 0.25);
uniform float scale = 0.22;
uniform float glow = 1.6;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; } return v; }
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wpos.x * 0.6 + TIME) * 0.06;
}
void fragment() {
	vec2 uv = wpos.xz * scale + flow * TIME;
	float n = fbm(uv + fbm(uv * 1.7 - TIME * 0.05));
	float cells = smoothstep(0.42, 0.62, n);
	vec3 col = mix(hot.rgb * glow, warm.rgb, smoothstep(0.2, 0.5, n));
	col = mix(col, crust.rgb, cells);
	ALBEDO = col;
}
