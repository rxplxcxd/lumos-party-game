// Stilisiertes Cartoon-Wasser: Wellen per Vertex, Schaumkronen, Fresnel. WebGL2-tauglich.
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

uniform vec4 deep : source_color = vec4(0.05, 0.35, 0.65, 1.0);
uniform vec4 shallow : source_color = vec4(0.25, 0.75, 0.9, 1.0);
uniform vec4 foam : source_color = vec4(0.95, 1.0, 1.0, 1.0);
uniform float wave_height = 0.18;
uniform float wave_scale = 0.35;
uniform float speed = 1.0;
uniform float alpha = 0.92;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * speed;
	VERTEX.y += (sin(wpos.x * wave_scale + t * 1.3) + cos(wpos.z * wave_scale * 1.3 + t)) * wave_height;
}
void fragment() {
	float t = TIME * speed;
	vec2 uv = wpos.xz * 0.15;
	float n = noise(uv * 3.0 + vec2(t * 0.15, t * 0.1)) * 0.6 + noise(uv * 7.0 - vec2(t * 0.2, 0.0)) * 0.4;
	float caustic = smoothstep(0.7, 0.76, n);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 col = mix(deep.rgb, shallow.rgb, n * 0.7 + fres * 0.3);
	col = mix(col, foam.rgb, caustic * 0.55);
	ALBEDO = col;
	ROUGHNESS = 0.15;
	SPECULAR = 0.6;
	EMISSION = col * 0.05;
	ALPHA = alpha;
}
