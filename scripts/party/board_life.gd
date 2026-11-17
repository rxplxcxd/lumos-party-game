class_name BoardLife
extends Node3D
## Eigenes Leben je Spielbrett (ab 1.5.3): Jedes der 10 Bretter bekommt zwei bis drei Elemente, die nur zu ihm passen –
## kein gemeinsamer Effekt für alle. Ergänzt das Tierleben am Rand (CritterLife) und die Deko des BoardBuilders.
##
##   Wuschel-Wiesen      Pusteblumen-Schirmchen im Wind · Drachen an der Schnur · Schwalben hoch über den Hügeln
##   Palmen-Bucht        Möwen über dem Meer · Glitzern auf dem Wasser
##   Dungeon Deep        Staub im Fackellicht · Tropfen von der Decke · Glut über dem Lavasee
##   Sternen-Wolkenland  Wolkenfetzen ziehen vorbei · Heißluftballons am Horizont
##   Geisterfriedhof     Irrlichter wandern zwischen den Gräbern · Krähen kreisen · welkes Laub
##   Frostdorf           leiser Schneefall · Polarlicht am Himmel
##   Sternwarte          Sternschnuppen · funkelnde Sterne · Planeten kreisen um die Kuppel
##   Glühwürmchen-Wald   leuchtende Sporen · Feenlichter
##   Zuckerback-Torte    Zuckerstreusel rieseln · Luftballons steigen auf
##   Wolkenturm          Blätter wirbeln im Aufwind um den Turm · Vögel kreisen um die Spitze
##
## Regeln: rein dekorativ, keine Kollision, kein Netz-Abgleich, eigener Zufall (feste Startwerte je Brett, der globale
## Zufall bleibt unberührt). Alles liegt in der Luft oder am Rand – nie auf Feldern, Wegen oder vor der Brett-Kamera:
## Vögel kreisen außerhalb des Bretts (Radius > Ausdehnung + 8 m) in 13–22 m Höhe, Lichter am Boden nur im Außenring,
## Partikel sind klein, langsam und dünn gesät. Grafikstufe „Niedrig“: nur die beweglichen Figuren (Vögel, Lichter,
## Ballons), keine Partikel.

var board_id := ""
var center := Vector3.ZERO
var extent := 30.0        ## halbe Ausdehnung des Bretts (größter Abstand eines Felds von der Mitte, waagerecht)
var top := 0.0            ## höchstes Feld (Wolkenturm)
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _movers: Array[Dictionary] = []   # {node, kind, …} – je Bild bewegt
var _low := false


## Belebt das Brett id. spaces: Feld-Positionen (für Mitte und Ausdehnung). Rückgabe: der Knoten (oder null).
static func populate(parent: Node3D, id: String, spaces: Array) -> BoardLife:
	var bl := BoardLife.new()
	bl.name = "BoardLife"
	bl.board_id = id
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for p in spaces:
		var v: Vector3 = p
		lo = lo.min(v)
		hi = hi.max(v)
	if spaces.is_empty():
		lo = Vector3(-25, 0, -18)
		hi = Vector3(25, 0, 18)
	bl.center = Vector3((lo.x + hi.x) * 0.5, 0.0, (lo.z + hi.z) * 0.5)
	var ext := 0.0
	for p in spaces:
		var v2: Vector3 = p
		ext = maxf(ext, Vector2(v2.x - bl.center.x, v2.z - bl.center.z).length())
	bl.extent = maxf(ext, 12.0) if not spaces.is_empty() else 30.0
	bl.top = hi.y if spaces.size() > 0 else 0.0
	parent.add_child(bl)
	bl._build()
	return bl


func _build() -> void:
	_rng.seed = hash("board_life:" + board_id)
	_low = Gfx.active == "low"
	var r := extent
	match board_id:
		"meadow":
			_drift({"amount": 26, "life": 9.0, "color": Color(1, 1, 1, 0.85), "size": 0.32, "wind": Vector3(1.4, 0.25, 0.4), "h": 2.5})
			_kite(center + Vector3(-r - 6.0, 0.0, -r * 0.5), Color("#ff7a59"))
			_flock("swallow", 5, r + 14.0, 17.0, 0.35, Color(0.18, 0.2, 0.32))
		"pirates":
			_flock("gull", 6, r + 10.0, 14.0, 0.28, Color(0.97, 0.97, 0.95))
			_twinkle(center + Vector3(0, 0.25, r + 6.0), Vector3(r, 0.1, 5.0), Color(1.0, 0.97, 0.8), 18)
		"dungeon":
			_drift({"amount": 30, "life": 7.0, "color": Color(1.0, 0.85, 0.6, 0.55), "size": 0.14, "wind": Vector3(0.15, 0.08, 0.1), "h": 3.0})
			_drips(14)
			_embers(center, r * 0.45)
		"sky":
			_drift({"amount": 10, "life": 14.0, "color": Color(1, 1, 1, 0.35), "size": 5.0, "wind": Vector3(1.6, 0.0, 0.3), "h": -3.0, "box_y": 2.0})
			for k in 3:
				_balloon(k)
		"graveyard":
			for k in 7:
				_wisp(Color(0.55, 0.95, 0.85), true)
			_flock("crow", 4, r + 9.0, 15.0, 0.3, Color(0.08, 0.07, 0.1))
			_drift({"amount": 14, "life": 8.0, "color": Color(0.55, 0.38, 0.2, 0.9), "size": 0.3, "wind": Vector3(0.9, -0.25, 0.2), "h": 7.0, "spin": 90.0})
		"frost":
			_drift({"amount": 46, "life": 9.0, "color": Color(1, 1, 1, 0.9), "size": 0.2, "wind": Vector3(0.3, -0.9, 0.15), "h": 14.0})
			_aurora()
		"station":
			_streak()
			_twinkle(center + Vector3(0, 22.0, -r - 10.0), Vector3(r * 1.6, 6.0, 4.0), Color(1.0, 0.95, 0.75), 30)
			for k in 3:
				_planet(k)
		"glowforest":
			_drift({"amount": 24, "life": 8.0, "color": Color(0.75, 1.0, 0.45, 0.8), "size": 0.18, "wind": Vector3(0.2, 0.35, 0.1), "h": 0.8, "glow": true})
			for k in 6:
				_wisp(Color(1.0, 0.85, 0.45), false)
		"cake":
			_drift({"amount": 36, "life": 8.0, "ramp": _sprinkles(), "size": 0.2, "wind": Vector3(0.25, -0.7, 0.1), "h": 13.0, "spin": 180.0})
			for k in 5:
				_party_balloon(k)
		"tower":
			_swirl()
			_flock("swallow", 5, 9.0, top + 6.0, 0.45, Color(0.25, 0.22, 0.35), true)


func _process(delta: float) -> void:
	_t += delta
	for m: Dictionary in _movers:
		var n: Node3D = m.node
		if not is_instance_valid(n):
			continue
		match String(m.kind):
			"bird":
				var a := float(m.phase) + _t * float(m.speed)
				var rr := float(m.radius) + sin(_t * 0.31 + float(m.phase)) * 2.0
				var c: Vector3 = m.center
				var p := c + Vector3(cos(a) * rr, float(m.h) + sin(_t * 0.7 + float(m.phase) * 2.0) * 1.2, sin(a) * rr)
				n.position = p
				n.rotation.y = -a + (PI if float(m.speed) > 0.0 else 0.0)
				var flap := sin(_t * float(m.flap) + float(m.phase) * 5.0) * 0.6 * (0.4 if fmod(_t + float(m.phase), 4.0) < 1.6 else 1.0)
				(m.wl as Node3D).rotation.z = flap
				(m.wr as Node3D).rotation.z = -flap
			"wisp":
				var base: Vector3 = m.base
				n.position = base + Vector3(sin(_t * 0.37 + float(m.phase)) * 2.6, 0.6 * sin(_t * 1.3 + float(m.phase)), cos(_t * 0.29 + float(m.phase) * 1.7) * 2.6)
				var s := 0.8 + 0.25 * sin(_t * 3.1 + float(m.phase) * 4.0)
				n.scale = Vector3.ONE * s
			"balloon":
				var c2: Vector3 = m.center
				var a2 := float(m.phase) + _t * 0.018
				n.position = c2 + Vector3(cos(a2) * float(m.radius), float(m.h) + sin(_t * 0.2 + float(m.phase)) * 1.5, sin(a2) * float(m.radius))
				n.rotation.z = sin(_t * 0.5 + float(m.phase)) * 0.05
			"party":
				var y := fmod(float(m.y0) + _t * float(m.speed), 26.0)
				n.position = (m.base as Vector3) + Vector3(sin(_t * 0.8 + float(m.phase)) * 0.8, y, 0.0)
				n.rotation.z = sin(_t * 1.1 + float(m.phase)) * 0.12
			"planet":
				var a3 := float(m.phase) + _t * float(m.speed)
				n.position = (m.center as Vector3) + Vector3(cos(a3) * float(m.radius), float(m.h) + sin(a3 * 2.0) * 0.6, sin(a3) * float(m.radius))
				n.rotate_y(delta * 0.6)
			"kite":
				var sway := Vector3(sin(_t * 0.6) * 2.0, sin(_t * 0.9) * 1.2, cos(_t * 0.45) * 1.0)
				n.position = (m.base as Vector3) + Vector3(0, 13.0, 0) + sway
				n.rotation = Vector3(0.3 + sin(_t * 1.3) * 0.15, 0.4, sin(_t * 1.7) * 0.25)
				_line(m.line as ImmediateMesh, m.base as Vector3, n.position)
			"streak":
				m.t = float(m.t) - delta
				if float(m.t) <= 0.0:
					m.t = _rng.randf_range(3.0, 7.0)
					m.from = center + Vector3(_rng.randf_range(-extent, extent), _rng.randf_range(24.0, 32.0), -extent - _rng.randf_range(8.0, 20.0))
					m.dir = Vector3(_rng.randf_range(0.6, 1.0) * (1.0 if _rng.randf() < 0.5 else -1.0), -0.35, _rng.randf_range(-0.2, 0.2)).normalized()
					m.age = 0.0
				m.age = float(m.age) + delta
				var u := float(m.age) / 0.9
				n.visible = u < 1.0
				if u < 1.0:
					n.global_position = (m.from as Vector3) + (m.dir as Vector3) * (u * 34.0)
					n.look_at(n.global_position + (m.dir as Vector3), Vector3.UP)
					(n.get_child(0) as MeshInstance3D).transparency = clampf(absf(u - 0.5) * 2.0, 0.0, 1.0)
			"aurora":
				var mat: StandardMaterial3D = m.mat
				var h2 := fmod(0.33 + 0.08 * sin(_t * 0.07), 1.0)
				mat.albedo_color = Color.from_hsv(h2, 0.7, 1.0, 0.16 + 0.07 * sin(_t * 0.5))
				n.rotation.y = sin(_t * 0.03) * 0.15


# --- Bausteine ----------------------------------------------------------------------------------------------

## Dünn gesäte, langsame Partikel über dem Brett (Schirmchen, Schnee, Sporen, Staub, Laub, Streusel …).
## cfg: amount, life, color oder ramp, size, wind (Richtung und Tempo), h (Höhe über dem Boden), box_y, spin, glow.
func _drift(cfg: Dictionary) -> void:
	if _low:
		return
	var w: Vector3 = cfg.get("wind", Vector3(0.5, 0.0, 0.0))
	var e := {"amount": int(cfg.get("amount", 20)), "life": float(cfg.get("life", 8.0)), "one_shot": false, "explosive": 0.0,
		"size": float(cfg.get("size", 0.2)), "dir": w.normalized() if w.length() > 0.01 else Vector3.UP, "spread": 25.0,
		"vel_min": w.length() * 0.7, "vel_max": w.length() * 1.2, "gravity": Vector3.ZERO, "spin": float(cfg.get("spin", 0.0)),
		"box": Vector3(extent * 1.1, float(cfg.get("box_y", 3.0)), extent * 0.9), "additive": bool(cfg.get("glow", false)),
		"scale_curve": FX._scale_curve([Vector2(0, 0.0), Vector2(0.15, 1.0), Vector2(0.85, 1.0), Vector2(1, 0.0)])}
	if cfg.has("ramp"):
		e["color_initial"] = cfg.ramp
		e["color"] = Color.WHITE
	else:
		e["color"] = cfg.get("color", Color.WHITE)
	var p := FX.emitter(e)
	p.preprocess = float(cfg.get("life", 8.0))   # beim Brettstart schon verteilt, nicht erst aus dem Nichts
	p.randomness = 0.8
	add_child(p)
	p.position = center + Vector3(0, float(cfg.get("h", 2.0)), 0)
	p.emitting = true


## Funkeln: kleine Sterne, die an- und ausgehen (Wasser, Himmel).
func _twinkle(at: Vector3, box: Vector3, color: Color, amount: int) -> void:
	if _low:
		return
	var p := FX.emitter({"amount": amount, "life": 1.6, "one_shot": false, "explosive": 0.0, "tex": FX.tex_star, "size": 0.5,
		"color": color, "vel_min": 0.0, "vel_max": 0.05, "gravity": Vector3.ZERO, "box": box, "additive": true,
		"scale_curve": FX._scale_curve([Vector2(0, 0.0), Vector2(0.5, 1.0), Vector2(1, 0.0)])})
	p.preprocess = 1.6
	add_child(p)
	p.position = at
	p.emitting = true


## Vogelschwarm, der außerhalb des Bretts kreist (Schwalben, Möwen, Krähen). around_tower: Kreis um die Mitte.
func _flock(style: String, count: int, radius: float, height: float, speed: float, color: Color, around_tower := false) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	var sz := {"gull": 0.9, "crow": 0.75, "swallow": 0.55}.get(style, 0.6) as float
	var c := center if around_tower else center
	for k in count:
		var b := Node3D.new()
		var body := MeshInstance3D.new()
		var bm := CapsuleMesh.new()
		bm.radius = 0.09 * sz
		bm.height = 0.55 * sz
		body.mesh = bm
		body.rotation.x = PI * 0.5
		body.material_override = mat
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.add_child(body)
		var wings: Array[Node3D] = []
		for sd in [-1.0, 1.0]:
			var pivot := Node3D.new()
			b.add_child(pivot)
			var wm := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.62 * sz, 0.02, 0.2 * sz) if style != "swallow" else Vector3(0.55 * sz, 0.02, 0.14 * sz)
			wm.mesh = box
			wm.material_override = mat
			wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			wm.position = Vector3(sd * box.size.x * 0.5, 0, 0)
			pivot.add_child(wm)
			wings.append(pivot)
		add_child(b)
		_movers.append({"node": b, "kind": "bird", "wl": wings[0], "wr": wings[1], "center": c, "radius": radius + _rng.randf_range(-3.0, 3.0),
			"h": height + _rng.randf_range(-1.5, 2.5), "speed": speed * _rng.randf_range(0.85, 1.15) * (1.0 if k % 3 != 2 else 0.92),
			"phase": TAU * k / count + _rng.randf_range(-0.2, 0.2), "flap": _rng.randf_range(7.0, 10.0) if style == "swallow" else _rng.randf_range(4.0, 6.0)})


## Leuchtendes Licht, das wandert (Irrlicht am Boden im Außenring; Feenlicht etwas höher). Ohne echte Lichtquelle.
func _wisp(color: Color, ground: bool) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16 if ground else 0.1
	sm.height = sm.radius * 2.0
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var halo := MeshInstance3D.new()   # weicher Schein als Billboard
	var q := QuadMesh.new()
	q.size = Vector2.ONE * (1.1 if ground else 0.7)
	var hm := FX._mat(FX.tex_soft, true, true)
	hm.albedo_color = Color(color.r, color.g, color.b, 0.55)
	q.material = hm
	halo.mesh = q
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(halo)
	add_child(mi)
	var a := _rng.randf() * TAU
	var rr := extent + _rng.randf_range(2.0, 7.0)   # Außenring – nie über Feldern oder Wegen
	var base := center + Vector3(cos(a) * rr, (0.9 if ground else 2.4) + _rng.randf_range(0.0, 0.8), sin(a) * rr)
	_movers.append({"node": mi, "kind": "wisp", "base": base, "phase": _rng.randf() * TAU})


## Wasser tropft von der Decke (Dungeon): einzelne Tropfen fallen am Rand, kleiner Spritzer am Boden.
func _drips(count: int) -> void:
	if _low:
		return
	for k in count:
		var a := _rng.randf() * TAU
		var rr := extent + _rng.randf_range(1.0, 6.0)
		var p := FX.emitter({"amount": 1, "life": 1.4, "one_shot": false, "explosive": 0.0, "size": 0.12, "color": Color(0.6, 0.8, 1.0, 0.8),
			"vel_min": 0.0, "vel_max": 0.0, "gravity": Vector3(0, -9.8, 0), "radius": 0.05,
			"scale_curve": FX._scale_curve([Vector2(0, 1.0), Vector2(1, 1.0)])})
		p.lifetime = _rng.randf_range(1.2, 1.6)
		add_child(p)
		p.position = center + Vector3(cos(a) * rr, 9.5, sin(a) * rr)
		p.emitting = true


## Glut steigt über dem Lavasee auf (Dungeon).
func _embers(at: Vector3, radius: float) -> void:
	if _low:
		return
	var p := FX.emitter({"amount": 22, "life": 3.5, "one_shot": false, "explosive": 0.0, "tex": FX.tex_spark, "size": 0.22,
		"color": Color(1.0, 0.55, 0.15), "dir": Vector3.UP, "spread": 20.0, "vel_min": 0.6, "vel_max": 1.4, "gravity": Vector3(0, 0.15, 0),
		"radius": radius, "additive": true})
	p.preprocess = 3.5
	add_child(p)
	p.position = at + Vector3(0, 0.3, 0)
	p.emitting = true


## Heißluftballon am Horizont (Wolkenland).
func _balloon(k: int) -> void:
	var root := Node3D.new()
	var env := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.6
	sm.height = 3.8
	env.mesh = sm
	var cols := [Color("#ff8a5b"), Color("#ffd166"), Color("#7bdff2")]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cols[k % cols.size()]
	mat.roughness = 0.8
	env.material_override = mat
	env.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(env)
	var basket := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.7, 0.55, 0.7)
	basket.mesh = bx
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color("#8a5a2b")
	basket.material_override = bmat
	basket.position = Vector3(0, -2.6, 0)
	root.add_child(basket)
	add_child(root)
	_movers.append({"node": root, "kind": "balloon", "center": center, "radius": extent + 22.0 + k * 6.0, "h": 10.0 + k * 3.0,
		"phase": TAU * k / 3.0 + 0.6})


## Luftballon steigt auf und kommt unten wieder nach (Torte) – am Rand, nie über dem Brett.
func _party_balloon(k: int) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.45
	sm.height = 1.1
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.from_hsv(fmod(0.08 + k * 0.19, 1.0), 0.55, 1.0)
	mat.roughness = 0.35
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var a := _rng.randf() * TAU
	var rr := extent + _rng.randf_range(4.0, 9.0)
	_movers.append({"node": mi, "kind": "party", "base": center + Vector3(cos(a) * rr, -1.0, sin(a) * rr), "y0": _rng.randf() * 26.0,
		"speed": _rng.randf_range(0.7, 1.1), "phase": _rng.randf() * TAU})


## Kleiner Planet mit Ring, der um die Sternwarte kreist.
func _planet(k: int) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.7 + 0.25 * k
	sm.height = sm.radius * 2.0
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = [Color("#ff9e6d"), Color("#8fd3ff"), Color("#c8a2ff")][k % 3]
	mat.emission_enabled = true
	mat.emission = mat.albedo_color * 0.25
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if k == 1:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = sm.radius * 1.35
		tm.outer_radius = sm.radius * 1.6
		ring.mesh = tm
		ring.material_override = mat
		ring.rotation.x = 0.4
		mi.add_child(ring)
	add_child(mi)
	_movers.append({"node": mi, "kind": "planet", "center": center, "radius": extent + 10.0 + k * 5.0, "h": 15.0 + k * 2.5,
		"speed": 0.05 + 0.02 * k, "phase": TAU * k / 3.0})


## Sternschnuppe alle paar Sekunden über den Himmel hinter dem Brett.
func _streak() -> void:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 3.2)
	var mat := FX._mat(FX.tex_spark, false, true)
	mat.albedo_color = Color(1.0, 0.95, 0.8, 0.9)
	q.material = mat
	mi.mesh = q
	mi.rotation.x = PI * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	root.visible = false
	add_child(root)
	_movers.append({"node": root, "kind": "streak", "t": 2.0, "age": 9.0, "from": Vector3.ZERO, "dir": Vector3.RIGHT})


## Polarlicht: breites, durchscheinendes Band hoch über dem Frostdorf, Farbe zieht langsam.
func _aurora() -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(extent * 3.2, 9.0)
	var mat := FX._mat(FX.tex_soft, false, true)
	mat.albedo_color = Color(0.4, 1.0, 0.7, 0.18)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = mat
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = center + Vector3(0, 26.0, -extent - 18.0)
	mi.rotation.x = -0.25
	_movers.append({"node": mi, "kind": "aurora", "mat": mat})


## Drachen an der Schnur über den Hügeln (Wiese).
func _kite(base: Vector3, color: Color) -> void:
	var k := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(1.4, 1.9, 0.05)
	k.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	k.material_override = mat
	k.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(k)
	var line := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	line.mesh = im
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(1, 1, 1, 0.7)
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line.material_override = lm
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line)
	_movers.append({"node": k, "kind": "kite", "base": base, "line": im})


func _line(im: ImmediateMesh, a: Vector3, b: Vector3) -> void:
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in 9:   # durchhängende Schnur
		var u := i / 8.0
		im.surface_add_vertex(a.lerp(b, u) + Vector3(0, -sin(u * PI) * 1.2, 0))
	im.surface_end()


## Blätter wirbeln im Aufwind spiralförmig um den Wolkenturm nach oben.
func _swirl() -> void:
	if _low:
		return
	var p := FX.emitter({"amount": 30, "life": 7.0, "one_shot": false, "explosive": 0.0, "size": 0.3, "color": Color(0.55, 0.85, 0.35, 0.95),
		"dir": Vector3.UP, "spread": 15.0, "vel_min": 1.6, "vel_max": 2.6, "gravity": Vector3.ZERO, "radius": 6.0, "spin": 160.0,
		"scale_curve": FX._scale_curve([Vector2(0, 0.0), Vector2(0.1, 1.0), Vector2(0.9, 1.0), Vector2(1, 0.0)])})
	p.preprocess = 7.0
	p.orbit_velocity_min = 0.06
	p.orbit_velocity_max = 0.1
	add_child(p)
	p.position = center + Vector3(0, 1.0, 0)
	p.emitting = true


func _sprinkles() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	g.colors = PackedColorArray([Color("#ff6b9a"), Color("#ffd166"), Color("#7bdff2"), Color("#b5ead7"), Color("#c3a6ff")])
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	return g
