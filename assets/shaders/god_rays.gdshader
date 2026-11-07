// Lichtschäfte ("God Rays"): achsial ausgerichtete Billboards entlang der Sonnenrichtung,
// additiv, mit weichen Kanten, Längsverlauf und langsamem Flimmern. WebGL2-tauglich.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, skip_vertex_transform, shadows_disabled;

uniform vec3 axis = vec3(0.3, -1.0, 0.2);
uniform float length = 40.0;
uniform float width = 5.0;
uniform vec4 tint : source_color = vec4(1.0, 0.9, 0.65, 1.0);
uniform float strength = 0.18;
uniform float seed = 0.0;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 ax = normalize(axis);
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 to_cam = normalize(cam - origin);
	vec3 side = normalize(cross(ax, to_cam));
	vec3 world = origin + side * VERTEX.x * width + ax * (VERTEX.y + 0.5) * length;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float across = 1.0 - smoothstep(0.0, 0.5, abs(UV.x - 0.5));
	float along = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.45, UV.y);
	float flicker = 0.75 + 0.25 * sin(TIME * 0.7 + seed * 6.2831) * sin(TIME * 1.3 + seed * 3.0);
	ALBEDO = tint.rgb;
	ALPHA = clamp(across * across * along * strength * flicker, 0.0, 1.0);
}
