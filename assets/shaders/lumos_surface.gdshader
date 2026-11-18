// Lumos-Oberfläche: gemeinsamer Material-Shader für Böden, Wände, Felsen, Holz, Dächer … (Premium-Visual-Überarbeitung).
// Die Palettenfarbe des Spiels bleibt die Grundfarbe (tint); die JulioVII-Textur liefert nur Detail: Helligkeits- und
// leichte Farbtonvariation (Mittelwert 1,0 → Farbe bleibt), Rauheit (Alphakanal) und Normalmap (OpenGL-Konvention).
// Projektion ohne UVs (triplanar, Welt- oder Objektraum, Kachelgröße in Metern) – passt auf jede Low-Poly-Form.
// Stufen (uniform quality): 0 = nur Farbe (Niedrig) · 1 = + Normalmap der Hauptprojektion (Mittel)
//                           2 = Normalmap aller Projektionen + Großflächen-Variation (Hoch/Ultra)
// Farbe immer weich überblendet. Kosten flacher Böden: Stufe 0 = 1 Texturzugriff, 1 und 2 = 2; Kanten 2–3 (Stufe 0),
// 3–4 (Stufe 1), 4–6 (Stufe 2).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D detail_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float k = 0.7;                       // Normierung der Detailfarbe, linear (data/surface_stats.json)
uniform float ks = 0.85;                     // dieselbe Normierung im sRGB-Raum
// Farbraum-Erkennung: Godot setzt hier 0,5 (sRGB). Rechnet der Renderer linear, kommt 0,214 an, sonst 0,5 –
// so bleibt der Mittelwert der Detailfarbe in beiden Fällen 1,0 (Compatibility rechnet je nach Plattform anders).
uniform vec4 space_probe : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float tile = 2.0;                    // Kachelgröße in Metern
uniform float color_strength : hint_range(0.0, 1.5) = 1.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform float rough_min : hint_range(0.0, 1.0) = 0.7;
uniform float rough_max : hint_range(0.0, 1.0) = 0.95;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
uniform float specular_value : hint_range(0.0, 1.0) = 0.4;
uniform float macro_strength : hint_range(0.0, 0.5) = 0.1;
uniform float highlight : hint_range(0.0, 1.0) = 0.3;     // Anteil der Aufhellung heller Detailstellen   // großflächige Helligkeitsvariation gegen Kachelmuster
uniform float sharpness = 8.0;               // Übergangshärte zwischen den Projektionen
uniform float fade_far = 120.0;              // Detail blendet zur Ferne hin aus (kein Flimmern, kein Muster am Horizont)
uniform bool object_space = false;           // bewegte Teile: Detail wandert mit dem Objekt
uniform int quality = 2;
uniform float emission_energy = 0.0;         // z. B. Lavastein: Detailfarbe leuchtet leicht
uniform vec4 emission_tint : source_color = vec4(1.0, 0.4, 0.1, 1.0);

varying vec3 v_pos;
varying vec3 v_nrm;

void vertex() {
	if (object_space) {
		vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		v_pos = VERTEX * sc;
		v_nrm = normalize(NORMAL / sc);
	} else {
		v_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		v_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	}
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec3 n = normalize(v_nrm);
	if (!FRONT_FACING) n = -n;   // nur in der doppelseitigen Variante (cull_disabled) relevant
	vec3 p = v_pos / tile;
	// Projektionen: Y (Boden) uv = xz · X uv = (z, -y) · Z uv = (x, -y) – Bildoberkante zeigt auf Wänden nach oben
	vec3 an = abs(n);
	// Farbe in allen Stufen weich überblendet (eine harte Einzelprojektion zeigte auf runden Seitenwänden Nähte);
	// flache Flächen brauchen trotzdem nur eine Projektion (Gewichte < 0,01 werden übersprungen)
	vec3 w = pow(an, vec3(sharpness));
	w /= (w.x + w.y + w.z);
	// Normalmap: Hoch alle Projektionen, Mittel nur die Hauptprojektion, Niedrig keine
	vec3 wn_w = w;
	if (quality == 1) {
		// Hauptprojektion, an der Umschaltstelle (zwei Gewichte gleich) weich ausgeblendet → keine Lichtnaht
		float wmax = max(w.x, max(w.y, w.z));
		float wmid = w.x + w.y + w.z - wmax - min(w.x, min(w.y, w.z));
		float fade = smoothstep(0.0, 0.35, wmax - wmid);
		wn_w = (w.y >= w.x && w.y >= w.z) ? vec3(0.0, fade, 0.0) : (w.x >= w.z ? vec3(fade, 0.0, 0.0) : vec3(0.0, 0.0, fade));
	}
	vec2 uvx = vec2(p.z, -p.y);
	vec2 uvy = p.xz;
	vec2 uvz = vec2(p.x, -p.y);
	vec4 a = vec4(0.0);
	vec3 t = vec3(0.0);   // Summe der Tangential-Störungen (Weltraum)
	bool nm = quality >= 1 && normal_strength > 0.001;
	if (w.x > 0.01) {
		a += texture(detail_albedo, uvx) * w.x;
		if (nm && wn_w.x > 0.01) { vec2 g = texture(detail_normal, uvx).rg * 2.0 - 1.0; t += vec3(0.0, g.g, g.r) * wn_w.x; }
	}
	if (w.y > 0.01) {
		a += texture(detail_albedo, uvy) * w.y;
		if (nm && wn_w.y > 0.01) { vec2 g = texture(detail_normal, uvy).rg * 2.0 - 1.0; t += vec3(g.r, 0.0, -g.g) * wn_w.y; }
	}
	if (w.z > 0.01) {
		a += texture(detail_albedo, uvz) * w.z;
		if (nm && wn_w.z > 0.01) { vec2 g = texture(detail_normal, uvz).rg * 2.0 - 1.0; t += vec3(g.r, g.g, 0.0) * wn_w.z; }
	}
	float dist = length(VERTEX);   // Abstand zur Kamera (Sichtraum)
	float near = 1.0 - smoothstep(fade_far * 0.35, fade_far, dist);
	// Detail asymmetrisch: Vertiefungen dunkeln voll ab, helle Stellen heben nur zu highlight an. Helle Tag-Szenen
	// liegen schon nahe am Weißpunkt (Gras-Grün, Sand) – symmetrisches Detail würde dort ausbleichen statt zu zeichnen.
	vec3 d = a.rgb / (space_probe.r < 0.35 ? k : ks);
	d = min(d, vec3(1.0)) + max(d - 1.0, vec3(0.0)) * highlight;
	vec3 det = mix(vec3(1.0), d, color_strength * mix(0.45, 1.0, near));
	if (quality >= 2 && macro_strength > 0.0) {
		vec3 q = v_pos * 0.045;
		float m = vnoise(q.xz + q.y * 0.7) * 0.65 + vnoise(q.xz * 2.3 - q.y) * 0.35;
		det *= 1.0 - m * macro_strength;   // nur abdunkeln (siehe oben)
	}
	ALBEDO = tint.rgb * det;
	ROUGHNESS = mix(rough_min, rough_max, a.a);
	METALLIC = metallic_value;
	SPECULAR = specular_value;
	if (nm) {
		vec3 wn = normalize(n + t * normal_strength * near);
		NORMAL = normalize((VIEW_MATRIX * vec4(object_space ? (MODEL_MATRIX * vec4(wn, 0.0)).xyz : wn, 0.0)).xyz);
	}
	if (emission_energy > 0.0) {
		EMISSION = emission_tint.rgb * smoothstep(1.05, 1.6, a.r / (space_probe.r < 0.35 ? k : ks)) * emission_energy;
	}
}
