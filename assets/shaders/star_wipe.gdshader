// Stern-Wipe-Übergang (klassischer Party-Spiel-Look).
shader_type canvas_item;

uniform float radius = 2.5;
uniform float rotation = 0.0;
uniform float aspect = 1.7777;
uniform vec2 center = vec2(0.5, 0.5);
uniform vec4 fill_color : source_color = vec4(0.07, 0.04, 0.16, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.8, 0.2, 1.0);

float sd_star5(vec2 p, float r, float rf) {
	const vec2 k1 = vec2(0.809016994375, -0.587785252292);
	const vec2 k2 = vec2(-0.809016994375, -0.587785252292);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

void fragment() {
	vec2 p = UV - center;
	p.x *= aspect;
	p.y = -p.y;
	float c = cos(rotation), s = sin(rotation);
	p = mat2(vec2(c, -s), vec2(s, c)) * p;
	float d = sd_star5(p, radius, 0.45);
	float inside = 1.0 - smoothstep(-0.004, 0.004, d);
	float rim = smoothstep(0.03, 0.0, abs(d - 0.012)) * step(0.001, radius);
	vec4 col = mix(fill_color, rim_color, rim);
	COLOR = vec4(col.rgb, max(1.0 - inside, rim) * col.a);
}
