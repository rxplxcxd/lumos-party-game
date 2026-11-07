// Boost-Feld: wandernde Chevron-Pfeile.
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 col_a : source_color = vec4(1.0, 0.75, 0.1, 1.0);
uniform vec4 col_b : source_color = vec4(1.0, 0.3, 0.05, 1.0);
void fragment() {
	vec2 uv = UV;
	float chev = fract(uv.y * 3.0 + abs(uv.x - 0.5) * 1.4 + TIME * 2.5);
	vec3 c = mix(col_b.rgb, col_a.rgb, step(0.5, chev));
	float border = step(0.08, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));
	ALBEDO = mix(vec3(1.0), c, border) * 1.6;
	ALPHA = 0.95;
}
