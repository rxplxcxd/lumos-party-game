class_name Seasonal
extends RefCounted
## Saisonale Feiertags-Deko: erkennt Weihnachten (1. Dezember – 6. Januar) und Halloween (15. Oktober –
## 2. November) am Datum des Geräts und schmückt Hauptmenü, Spielbretter und Minispiel-Kulissen mit den passenden
## KayKit-Modellen (Holiday Bits bzw. Halloween Bits). Einstellung „Saison-Deko“: Automatisch / Aus / Weihnachten /
## Halloween; Tests: --season=christmas|halloween|off.
##
## Platzierung ist geprüft statt zufällig: Jede Stelle braucht festen Boden darunter (kein Wasser, keine Lava, keine
## Luft), darf kein anderes Modell überlappen, liegt außerhalb der Spielfläche und hohe Teile stehen nie zwischen
## Kamera und Geschehen. Der Zufall ist lokal und fest je Ort – online bleibt der gemeinsame Spielzufall unberührt.

const SETS := {
	"christmas": {
		"tall": [["hol/christmas_tree_decorated", 0.85], ["hol/snowman_a", 0.85], ["hol/snowman_b", 0.85], ["hol/lantern", 0.75]],
		"small": [["hol/present_red", 1.0], ["hol/present_blue", 1.0], ["hol/present_green", 1.0], ["hol/present_sphere_a_red", 1.0],
			["hol/present_e_yellow", 1.0], ["hol/present_f_blue", 1.0], ["hol/candycane_small", 1.8], ["hol/gingerbread_house_decorated", 0.75],
			["hol/snowball_pile", 0.85]],
		"center": [["hol/christmas_tree_decorated", 1.25], ["hol/present_red", 1.1], ["hol/present_sphere_b_green", 1.0], ["hol/present_f_blue", 1.1]],
		"greeting": "Frohe Weihnachten!",
		"glow": Color(1.0, 0.85, 0.55),
	},
	"halloween": {
		"tall": [["hal/tree_dead_large_decorated", 0.85], ["hal/post_lantern", 0.8], ["hal/tree_pine_orange_medium", 0.55], ["hal/post_skull", 0.8]],
		"small": [["hal/pumpkin_orange_jackolantern", 0.8], ["hal/pumpkin_yellow_jackolantern", 0.8], ["hal/pumpkin_orange_small", 1.0],
			["hal/pumpkin_yellow_small", 1.0], ["hal/candle_triple", 1.0], ["hal/skull_candle", 0.75], ["hal/lantern_standing", 1.0]],
		"center": [["hal/pumpkin_orange_jackolantern", 1.4], ["hal/pumpkin_yellow_jackolantern", 1.0], ["hal/pumpkin_orange_small", 1.2], ["hal/candle_triple", 1.2]],
		"greeting": "Fröhliches Halloween!",
		"glow": Color(1.0, 0.55, 0.15),
	},
}

static var test_override := ""   # nur für Tests


## Aktuelle Saison: "christmas", "halloween" oder "" (keine).
static func current() -> String:
	if test_override != "":
		return "" if test_override == "off" else test_override
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--season="):
			var v := String(a).substr(9)
			return v if SETS.has(v) else ""
	var mode := String(Game.settings.get("season_deco", "auto"))
	if mode == "off":
		return ""
	if SETS.has(mode):
		return mode
	return for_date(Time.get_date_dict_from_system())


## Saison für ein Datum ({"month", "day"}).
static func for_date(d: Dictionary) -> String:
	var m := int(d.get("month", 0))
	var day := int(d.get("day", 0))
	if m == 12 or (m == 1 and day <= 6):
		return "christmas"
	if (m == 10 and day >= 15) or (m == 11 and day <= 2):
		return "halloween"
	return ""


static func greeting() -> String:
	var s := current()
	return String(SETS[s].greeting) if s != "" else ""


# --- Platzierung ------------------------------------------------------------------------------------------

## Schmückt einen Ort. candidates: mögliche Stellen (y = Bezugshöhe); allow_tall(p) → ob dort Hohes stehen darf;
## exclude(p) → Stelle gesperrt (Spielfläche). Gibt die Zahl gesetzter Modelle zurück.
static func decorate(scene_root: Node3D, parent: Node3D, candidates: Array[Vector3], count: int, seed_key: String,
		allow_tall: Callable, exclude: Callable, lights := 2) -> int:
	var season := current()
	if season == "" or candidates.is_empty():
		return 0
	var set_def: Dictionary = SETS[season]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_key + season)
	var supports := _solid_supports(scene_root)
	var occupied := _occupancy(scene_root)
	var order := candidates.duplicate()
	for i in range(order.size() - 1, 0, -1):   # lokales Mischen (fester Startwert je Ort)
		var j := rng.randi_range(0, i)
		var tmp: Vector3 = order[i]
		order[i] = order[j]
		order[j] = tmp
	var placed := 0
	var lit := 0
	for p: Vector3 in order:
		if placed >= count:
			break
		if exclude.is_valid() and bool(exclude.call(p)):
			continue
		var tall := allow_tall.is_valid() and bool(allow_tall.call(p)) and rng.randf() < 0.35
		var pool: Array = set_def.tall if tall else set_def.small
		var pick: Array = pool[rng.randi() % pool.size()]
		var n := _try_place(parent, String(pick[0]), float(pick[1]), p, rng.randf() * 360.0, supports, occupied)
		if n == null:
			continue
		placed += 1
		if lit < lights and String(pick[0]).contains("jackolantern"):
			_glow(n, set_def.glow, 1.2)
			lit += 1
	return placed


## Ein geschmücktes Ensemble (Weihnachtsbaum mit Geschenken bzw. Kürbishaufen) an einer gut sichtbaren Stelle.
static func centerpiece(scene_root: Node3D, parent: Node3D, at: Vector3, seed_key: String, light := true, size := 1.0) -> bool:
	var season := current()
	if season == "":
		return false
	var set_def: Dictionary = SETS[season]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_key + season + "c")
	var supports := _solid_supports(scene_root)
	var occupied := _occupancy(scene_root)
	var parts: Array = set_def.center
	var main: Node3D = null
	for k in 25:   # Spirale um den Wunschpunkt: erste freie, feste Stelle
		var off := Vector3.ZERO if k == 0 else Vector3(cos(k * 2.4), 0, sin(k * 2.4)) * (0.6 + k * 0.22)
		main = _try_place(parent, String(parts[0][0]), float(parts[0][1]) * size, at + off, rng.randf_range(-20, 20), supports, occupied)
		if main:
			at = Vector3(main.global_position.x, at.y, main.global_position.z)
			break
	if "--season-log" in OS.get_cmdline_user_args():
		print("[SEASON] Ensemble %s bei %s: %s" % [seed_key, str(at), "gesetzt" if main else "kein Platz"])
	if main == null:
		return false
	var r := maxf(1.0, _footprint(String(parts[0][0]), float(parts[0][1]) * size).size.x * 0.55 + 0.3)
	for k in range(1, parts.size()):
		var a := rng.randf_range(0.0, TAU)
		for attempt in 6:
			var p := at + Vector3(cos(a), 0, sin(a)) * (r + attempt * 0.25)
			if _try_place(parent, String(parts[k][0]), float(parts[k][1]) * maxf(size, 0.85), p, rng.randf() * 360.0, supports, occupied) != null:
				break
			a += 1.1
	if light:
		_glow(main, set_def.glow, 1.6 if season == "christmas" else 1.3)
	return true


static func _try_place(parent: Node3D, key: String, scl: float, p: Vector3, rot: float, supports: Dictionary, occupied: Array) -> Node3D:
	var y := PropSettler._ground_at(p, supports, [], 2.5, 3.5)
	if y == INF:
		return null   # kein fester Boden (Wasser, Lava, Abgrund)
	var fp := _footprint(key, scl)
	var rect := Rect2(Vector2(p.x, p.z) + fp.position, fp.size)
	# Auf dem Untergrund muss die ganze Grundfläche stehen, nicht nur die Mitte (Kantenmitten der Hülle – die Modelle
	# sind rund, die Ecken des Hüllquadrats dürfen über eine runde Insel hinausragen)
	var h := rect.size.x * 0.5 * 0.85
	for c in [Vector2(p.x + h, p.z), Vector2(p.x - h, p.z), Vector2(p.x, p.z + h), Vector2(p.x, p.z - h)]:
		var yc := PropSettler._ground_at(Vector3(c.x, p.y, c.y), supports, [], 2.5, 3.5)
		if yc == INF or absf(yc - y) > 0.25:
			return null
	for o: Rect2 in occupied:
		if o.intersects(rect):
			return null
	var n := WorldKit.place(parent, key, Vector3(p.x, y, p.z), rot, scl)
	n.set_meta("seasonal", true)
	occupied.append(rect.grow(0.25))
	return n


## Grundfläche (x/z) eines Modells relativ zu seinem Ursprung, drehungsunabhängig (Quadrat über die Diagonale).
static func _footprint(key: String, scl: float) -> Rect2:
	var bb := Assets.model_aabb(key)
	var h := maxf(bb.size.x, bb.size.z) * scl * 0.5
	return Rect2(Vector2(-h, -h), Vector2(h * 2.0, h * 2.0))


## Tragende Flächen ohne Wasser/Lava (die haben Shader-Materialien).
static func _solid_supports(scene_root: Node) -> Dictionary:
	var sup: Dictionary = PropSettler._supports(scene_root)
	var keep := func(e: Array) -> bool:
		var m: MeshInstance3D = e[3] as MeshInstance3D
		if m == null:
			return true
		if m.material_override is ShaderMaterial:
			return false
		if m.mesh and m.mesh.get_surface_count() > 0 and m.mesh.surface_get_material(0) is ShaderMaterial:
			return false
		return not String(m.name).to_lower().contains("water")
	var grid: Dictionary = sup.grid
	for k in grid.keys():
		grid[k] = (grid[k] as Array).filter(keep)
	sup.huge = (sup.huge as Array).filter(keep)
	return sup


## Belegte Flächen aller vorhandenen Modelle (Bäume, Häuser, Requisiten, Figuren).
static func _occupancy(scene_root: Node) -> Array:
	var out: Array = []
	for n in scene_root.find_children("*", "Node3D", true, false):
		if not n.has_meta("asset") or not (n as Node3D).is_visible_in_tree():
			continue
		var bb := (n as Node3D).global_transform * Assets.compute_aabb(n as Node3D)
		if bb.size.x > 14.0 or bb.size.z > 14.0:
			continue   # Böden/Inseln sind Untergrund, keine Hindernisse
		if bb.size.y < 0.6 and maxf(bb.size.x, bb.size.z) < 1.6:
			continue   # Bodendecker (Blumen, Gras, Kiesel) – darauf darf man etwas stellen
		if bb.size.y > 3.0:
			# Bäume/Palmen: Die Krone hängt über Kopfhöhe – am Boden belegt nur der Stamm
			var gp := (n as Node3D).global_position
			var t := clampf(minf(bb.size.x, bb.size.z) * 0.3, 0.8, 2.0)
			out.append(Rect2(Vector2(gp.x - t * 0.5, gp.z - t * 0.5), Vector2(t, t)))
			continue
		out.append(Rect2(Vector2(bb.position.x, bb.position.z), Vector2(bb.size.x, bb.size.z)).grow(0.2))
	return out


static func _glow(n: Node3D, color: Color, energy: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = 4.5
	l.shadow_enabled = false
	n.add_child(l)
	l.position = Vector3.UP * 1.2


## Ring-Kandidaten um einen Mittelpunkt (Minispiel-Kulisse, Menü-Insel).
static func ring(center: Vector3, r_min: float, r_max: float, n: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for k in n:
		var a := TAU * k / n
		for rr in [r_min, (r_min + r_max) * 0.5, r_max]:
			out.append(center + Vector3(cos(a + rr * 0.13), 0, sin(a + rr * 0.13)) * rr)
	return out
