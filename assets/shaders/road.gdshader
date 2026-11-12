// Fahrbahn: Asphalt mit Rauschen, Randlinien, gestrichelter Mittellinie, rot/weiße Kerbs,
// Start-/Zielkaro. neon > 0 = dunkle Fahrbahn mit leuchtenden Kanten (Neon-Vulkan).
shader_type spatial;
render_mode cull_disabled;

uniform vec4 asphalt : source_color = vec4(0.32, 0.32, 0.36, 1.0);
uniform vec4 line_col : source_color = vec4(0.95, 0.95, 0.95, 1.0);
uniform vec4 kerb_a : source_color = vec4(0.9, 0.15, 0.2, 1.0);
uniform vec4 kerb_b : source_color = vec4(0.98, 0.98, 0.98, 1.0);
uniform vec4 neon_col : source_color = vec4(0.2, 0.9, 1.0, 1.0);
uniform float neon = 0.0;
uniform float wet = 0.0;          // nasse Fahrbahn: dunkler, glänzend (Gewitter)
uniform float edge_glow = 0.0;    // reflektierende Randmarkierungen (dezentes Leuchten)
uniform vec4 glow_col : source_color = vec4(1.0, 0.8, 0.35, 1.0);
uniform float start_v = 0.0;
uniform float track_len = 800.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }

void fragment() {
	// Die Oberseite der Fahrbahn ist im Mesh die Rückseite – ohne Umdrehen zeigt die Normale nach unten und die
	// Sonne erreicht den Asphalt nicht (Fahrbahn fast schwarz).
	if (!FRONT_FACING) NORMAL = -NORMAL;
	float u = UV.x;
	float v = UV.y;           // Meter entlang der Strecke
	vec3 col = asphalt.rgb * (0.9 + 0.2 * hash(floor(vec2(u * 60.0, v * 4.0))));
	float edge = min(u, 1.0 - u);
	// Kerbs
	if (edge < 0.055) {
		float stripe = step(0.5, fract(v / 2.0));
		col = mix(kerb_a.rgb, kerb_b.rgb, stripe);
	}
	// Randlinien
	if (edge > 0.07 && edge < 0.085) col = line_col.rgb;
	// Mittellinie gestrichelt
	if (abs(u - 0.5) < 0.008 && fract(v / 6.0) < 0.5) col = line_col.rgb;
	// Start-/Ziel-Karo
	float dv = abs(v - start_v);
	dv = min(dv, abs(v - start_v - track_len));
	if (dv < 1.6) {
		float c = mod(floor(u * 16.0) + floor(v / 0.8), 2.0);
		col = mix(vec3(0.05), vec3(0.98), c);
	}
	vec3 emi = vec3(0.0);
	if (neon > 0.5) {
		col *= 0.35;
		float glow = smoothstep(0.08, 0.0, edge) + smoothstep(0.012, 0.0, abs(u - 0.5)) * step(0.5, fract(v / 6.0));
		emi = neon_col.rgb * glow * 2.5;
		if (edge < 0.055) { col = vec3(0.08); emi = mix(neon_col.rgb, vec3(1.0, 0.2, 0.8), step(0.5, fract(v / 4.0))) * 2.0; }
	}
	if (edge_glow > 0.0) {
		// Reflektor-Strich auf der Randlinie, alle 3 m kurz unterbrochen
		float dash = step(0.35, fract(v / 3.0));
		if (edge > 0.065 && edge < 0.09) emi += glow_col.rgb * edge_glow * 0.55 * dash;
		if (abs(u - 0.5) < 0.01 && fract(v / 6.0) < 0.5) emi += glow_col.rgb * edge_glow * 0.25;
	}
	col *= mix(1.0, 0.72, wet);
	ALBEDO = col;
	ROUGHNESS = mix(0.8, 0.18, wet * (0.6 + 0.4 * hash(floor(vec2(u * 12.0, v * 0.8)))));
	SPECULAR = mix(0.5, 0.9, wet);
	EMISSION = emi;
}
