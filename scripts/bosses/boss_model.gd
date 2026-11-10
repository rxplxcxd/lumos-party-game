class_name BossModel
extends Node3D
## Die zehn Boss-Modelle – vollständig prozedural aus vielen kleinen Teilen gebaut (kein externes Asset nötig),
## jeweils mit eigener Idle-Animation (Atmen, Schweben, Wackeln, Drehen, Glühen, kleine Effekte) und
## maßgeschneiderten Aktions-Animationen für jede Fähigkeit. Blick nach +Z (zur Kamera).
##
## Animation ist deklarativ: _osc() lässt ein Teil schwingen, _spin() dreht es, _every() löst periodische
## Effekte aus (Rauch aus den Nüstern, Blasen, Schneegestöber …). act(kind) spielt eine Aktion, hit() einen
## Treffer (weißes Aufblitzen + Squash), set_rage() die Phasen-Wut, defeat() den Abgang.

signal action_done(kind: String)

var id := ""
var t := 0.0
var rage := 0
var parts := {}
var _osc_list: Array[Dictionary] = []
var _spin_list: Array[Dictionary] = []
var _every_list: Array[Dictionary] = []
var _mat_cache := {}
var _flash_mat: StandardMaterial3D
var _root: Node3D          # alles hängt hier dran (für Squash/Lunge)
var _base_scale := 1.0
var _shadow_mode := false


static func create(boss_id: String) -> BossModel:
	var m := BossModel.new()
	m.id = boss_id
	m.name = "Boss_" + boss_id
	return m


func _ready() -> void:
	_root = Node3D.new()
	_root.name = "Root"
	add_child(_root)
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.albedo_color = Color(1, 1, 1, 0.0)
	match id:
		"ignis": _build_ignis()
		"klabautox": _build_klabautox()
		"astraios": _build_astraios()
		"grabstein": _build_grabstein()
		"frostbart": _build_frostbart()
		"galaxus": _build_galaxus()
		"noxumbra": _build_noxumbra()
		"baahemoth": _build_baahemoth()
		"marquise": _build_marquise()
		_: _build_zephyros()
	for mi in _meshes(self):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if mi.get_aabb().size.length() > 1.2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	t += delta
	var speed := 1.0 + rage * 0.35
	for o in _osc_list:
		var n: Node3D = o.n
		if not is_instance_valid(n):
			continue
		var v := sin(t * float(o.f) * TAU * speed + float(o.ph)) * float(o.a)
		match String(o.k):
			"rot":
				n.rotation = (o.base as Vector3) + (o.axis as Vector3) * v
			"pos":
				n.position = (o.base as Vector3) + (o.axis as Vector3) * v
			"scl":
				n.scale = (o.base as Vector3) * (Vector3.ONE + (o.axis as Vector3) * v)
	for s in _spin_list:
		var n2: Node3D = s.n
		if is_instance_valid(n2):
			n2.rotate_object_local(s.axis, float(s.sp) * delta * speed)
	for e in _every_list:
		e.acc = float(e.acc) + delta
		if float(e.acc) >= float(e.every) / speed:
			e.acc = 0.0
			(e.cb as Callable).call()


# --- Öffentliche Aktionen --------------------------------------------------------------------------------------

## Spielt eine Aktion (Fähigkeit) – gibt die Dauer zurück; danach feuert action_done.
func act(kind: String) -> float:
	var dur := 1.2
	match kind:
		"attack", "ram", "pinch", "steal", "lunge":
			dur = _lunge(2.2 if kind == "ram" else 1.4)
		"breath", "fire", "frost", "gust", "flame":
			dur = _breath(kind)
		"slam", "stomp", "wave", "tail", "comet":
			dur = _slam(kind)
		"spin", "gravity", "timejump", "storm":
			dur = _spin_act()
		"curl", "armor":
			dur = _curl()
		_:
			dur = _roar()
	get_tree().create_timer(dur).timeout.connect(func() -> void: action_done.emit(kind))
	return dur


func hit() -> void:
	for mi in _meshes(self):
		mi.material_overlay = _flash_mat
	_flash_mat.albedo_color.a = 0.85
	var tw := create_tween()
	tw.tween_property(_flash_mat, "albedo_color:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		for mi in _meshes(self):
			mi.material_overlay = null)
	_squash(1.12, 0.86, 0.35)
	var sh := create_tween()
	for k in 4:
		sh.tween_property(_root, "position:x", 0.25 * (1 if k % 2 == 0 else -1), 0.04)
	sh.tween_property(_root, "position:x", 0.0, 0.05)
	match id:
		"frostbart":
			FX.smoke(global_position + Vector3.UP * 4.0, Color(0.95, 0.98, 1.0), 26, 2.4)
		"baahemoth":
			FX.smoke(global_position + Vector3.UP * 3.0, Color.WHITE, 20, 2.0)
		"ignis":
			FX.embers(global_position + Vector3.UP * 3.0, 20)


func set_rage(level: int) -> void:
	rage = level
	_roar()
	FX.shockwave(global_position + Vector3.UP * 0.3, 14.0, Color(1, 0.5, 0.4, 0.8))
	if parts.has("glow"):
		for mi in parts.glow:
			var m := (mi as MeshInstance3D).material_override as StandardMaterial3D
			if m:
				m.emission_energy_multiplier = 1.5 + level * 1.2


## Noxumbra: im Schatten unsichtbar – nur die leuchtenden Pilze und Augen bleiben sichtbar.
func set_shadow(on: bool) -> void:
	_shadow_mode = on
	for mi in _meshes(self):
		var keep: bool = parts.has("glow") and mi in parts.glow
		mi.visible = keep or not on


func defeat() -> void:
	_roar()
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(_root, "rotation:z", 0.5, 0.5).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(_root, "position:y", -1.2, 0.8)
	tw.tween_property(_root, "scale", Vector3(1.3, 0.1, 1.3), 0.35)
	tw.tween_callback(func() -> void:
		FX.explosion(global_position + Vector3.UP * 2.0, 2.0)
		FX.stars(global_position + Vector3.UP * 3.0, UI.GOLD, 40)
		FX.coins_burst(global_position + Vector3.UP * 2.0, 20))
	tw.tween_property(_root, "scale", Vector3.ZERO, 0.25)


## Weltposition eines benannten Teils (z. B. "mouth" für Feueratem).
func part_pos(name_: String) -> Vector3:
	if parts.has(name_) and parts[name_] is Node3D and is_instance_valid(parts[name_]):
		return (parts[name_] as Node3D).global_position
	return global_position + Vector3.UP * 3.5


# --- Aktions-Bausteine -----------------------------------------------------------------------------------------

func _squash(sx: float, sy: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(_root, "scale", Vector3(sx, sy, sx), dur * 0.35).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_root, "scale", Vector3.ONE, dur * 0.65).set_trans(Tween.TRANS_ELASTIC)


func _roar() -> float:
	_squash(0.9, 1.15, 0.6)
	if parts.has("jaw"):
		var j: Node3D = parts.jaw
		var tw := create_tween()
		tw.tween_property(j, "rotation:x", 0.55, 0.2)
		tw.tween_interval(0.5)
		tw.tween_property(j, "rotation:x", 0.0, 0.3)
	Audio.sfx("evil_laugh" if id in ["grabstein", "noxumbra"] else "thunder", null, -6.0, 1.3 if id in ["baahemoth", "marquise", "zephyros"] else 0.8)
	Juice.shake(0.25)
	return 1.0


func _lunge(dist: float) -> float:
	var tw := create_tween()
	tw.tween_property(_root, "position:z", -0.6, 0.25).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_root, "position:z", dist, 0.18).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(_root, "position:z", 0.0, 0.45).set_trans(Tween.TRANS_BACK)
	if parts.has("claw_r"):
		var c: Node3D = parts.claw_r
		var tc := create_tween()
		tc.tween_property(c, "rotation:x", -0.9, 0.3)
		tc.tween_property(c, "rotation:x", 0.0, 0.4)
	get_tree().create_timer(0.42).timeout.connect(func() -> void:
		Juice.shake(0.3)
		Audio.sfx("punch", null, -2.0, 0.7))
	return 1.0


func _breath(kind: String) -> float:
	_roar()
	var col: Color = {"breath": Color(1.0, 0.45, 0.1), "fire": Color(1.0, 0.45, 0.1), "flame": Color(1.0, 0.6, 0.2),
		"frost": Color(0.7, 0.95, 1.0), "gust": Color(1, 1, 1)}.get(kind, Color.WHITE)
	var from := part_pos("mouth")
	for k in 6:
		get_tree().create_timer(0.25 + k * 0.1).timeout.connect(func() -> void:
			var p := from.lerp(global_position + Vector3(randf_range(-6, 6), 0.5, 9.0), float(k) / 6.0)
			FX.smoke(p, col, 10, 1.6)
			if kind in ["breath", "fire", "flame"]:
				FX.embers(p, 8))
	Audio.sfx("whoosh", null, -2.0, 0.6)
	return 1.4


func _slam(kind: String) -> float:
	var tw := create_tween()
	tw.tween_property(_root, "position:y", 2.2, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_root, "position:y", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		Juice.shake(0.55)
		FX.shockwave(global_position + Vector3.UP * 0.2, 13.0, Color(0.9, 0.95, 1.0, 0.85) if kind != "tail" else Color(1, 0.6, 0.3, 0.8))
		Audio.sfx("explosion_big" if kind == "slam" else "stone_hit", null, -2.0, 0.8)
		_squash(1.2, 0.8, 0.4))
	if parts.has("tail"):
		var tl: Node3D = parts.tail
		var tt := create_tween()
		tt.tween_property(tl, "rotation:y", 1.4, 0.3)
		tt.tween_property(tl, "rotation:y", -1.4, 0.25)
		tt.tween_property(tl, "rotation:y", 0.0, 0.4)
	return 1.1


func _spin_act() -> float:
	var tw := create_tween()
	tw.tween_property(_root, "rotation:y", TAU, 0.9).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(func() -> void: _root.rotation.y = 0.0)
	FX.sparks(global_position + Vector3.UP * 3.0, Color(0.8, 0.9, 1.0), 30)
	Audio.sfx("whoosh", null, -3.0, 0.8)
	return 1.0


func _curl() -> float:
	var tw := create_tween()
	tw.tween_property(_root, "scale", Vector3(1.1, 0.7, 1.1), 0.4).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.6)
	tw.tween_property(_root, "scale", Vector3.ONE, 0.4)
	FX.sparks(global_position + Vector3.UP * 2.0, UI.GOLD, 30)
	Audio.sfx("forcefield", null, -4.0)
	return 1.4


# --- Bauhelfer -------------------------------------------------------------------------------------------------

func _mat(col: Color, rough := 0.7, emis := 0.0, metal := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [col.to_html(), rough, emis, metal]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if col.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emis
	_mat_cache[key] = m
	return m


func _glow_mat(col: Color, energy := 1.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()   # eigenes Material, damit Wut-Phasen es heller drehen können
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m


func _piv(parent: Node3D, pos := Vector3.ZERO, nm := "") -> Node3D:
	var n := Node3D.new()
	if nm != "":
		n.name = nm
		parts[nm] = n
	parent.add_child(n)
	n.position = pos
	return n


func _sph(parent: Node3D, r: float, pos: Vector3, col: Color, scl := Vector3.ONE, rough := 0.7, emis := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 20 if r > 0.6 else 12
	sm.rings = 10 if r > 0.6 else 6
	mi.mesh = sm
	mi.material_override = _mat(col, rough, emis)
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _box(parent: Node3D, size: Vector3, pos: Vector3, col: Color, rot := Vector3.ZERO, rough := 0.7, emis := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(col, rough, emis)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, rt: float, rb: float, h: float, pos: Vector3, col: Color, rot := Vector3.ZERO, rough := 0.7, emis := 0.0, seg := 14) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = rt
	cm.bottom_radius = rb
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 0
	mi.mesh = cm
	mi.material_override = _mat(col, rough, emis)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _torus(parent: Node3D, ri: float, ro: float, pos: Vector3, col: Color, rot := Vector3.ZERO, rough := 0.5, emis := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = ri
	tm.outer_radius = ro
	tm.rings = 24
	tm.ring_segments = 8
	mi.mesh = tm
	mi.material_override = _mat(col, rough, emis)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Großes Kulleraugen-Paar-Element: Augapfel, Iris, Pupille, Glanzpunkt; der Pivot blinzelt (scale.y).
func _eye(parent: Node3D, pos: Vector3, r: float, iris := Color("#3a2a5a"), white := Color.WHITE, glow := 0.0) -> Node3D:
	var p := _piv(parent, pos)
	_sph(p, r, Vector3.ZERO, white, Vector3(1, 1, 0.75), 0.3, glow)
	_sph(p, r * 0.62, Vector3(0, 0, r * 0.5), iris, Vector3(1, 1, 0.5), 0.3, glow)
	_sph(p, r * 0.34, Vector3(0, 0, r * 0.72), Color("#120a1a"), Vector3(1, 1, 0.5), 0.2)
	_sph(p, r * 0.16, Vector3(r * 0.22, r * 0.25, r * 0.84), Color.WHITE, Vector3.ONE, 0.1, 0.8)
	if not parts.has("eyes"):
		parts["eyes"] = []
	(parts.eyes as Array).append(p)
	return p


func _blink(every := 3.5) -> void:
	_every(every, func() -> void:
		for e in parts.get("eyes", []):
			var n: Node3D = e
			var tw := n.create_tween()
			tw.tween_property(n, "scale:y", 0.1, 0.06)
			tw.tween_property(n, "scale:y", 1.0, 0.1))


func _osc(n: Node3D, k: String, axis: Vector3, amp: float, freq: float, ph := 0.0) -> void:
	var base: Vector3 = n.rotation if k == "rot" else (n.position if k == "pos" else n.scale)
	_osc_list.append({"n": n, "k": k, "axis": axis, "a": amp, "f": freq, "ph": ph, "base": base})


func _spin(n: Node3D, axis: Vector3, sp: float) -> void:
	_spin_list.append({"n": n, "axis": axis.normalized(), "sp": sp})


func _every(sec: float, cb: Callable) -> void:
	_every_list.append({"every": sec, "acc": randf() * sec, "cb": cb})


func _add_glow(mi: MeshInstance3D, col: Color, energy := 1.6) -> MeshInstance3D:
	mi.material_override = _glow_mat(col, energy)
	if not parts.has("glow"):
		parts["glow"] = []
	(parts.glow as Array).append(mi)
	return mi


func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in n.get_children():
		if c is MeshInstance3D:
			out.append(c)
		out.append_array(_meshes(c))
	return out


# =============================================================================================================
# 1) Ignis, der Seelenschmied – uralter Höhlendrache aus Lavagestein, rhythmisch atmend, Rauch aus den Nüstern
# =============================================================================================================
func _build_ignis() -> void:
	var rock := Color("#3b2b33")
	var rock2 := Color("#4d3640")
	var lava := Color("#ff7a1a")
	var belly := Color("#e9a24a")
	# Schatzhaufen
	var hoard := _piv(_root, Vector3(0, 0, 0.6))
	for k in 26:
		var a := randf() * TAU
		var rr := randf_range(0.6, 3.4)
		_cyl(hoard, 0.28, 0.28, 0.07, Vector3(cos(a) * rr, 0.05 + randf() * 0.35, sin(a) * rr + 1.0), Color("#ffc93c"), Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5)), 0.25, 0.25)
	_box(hoard, Vector3(1.0, 0.7, 0.7), Vector3(2.6, 0.35, 2.2), Color("#8a5a34"), Vector3(0, 0.4, 0))
	_box(hoard, Vector3(1.04, 0.2, 0.74), Vector3(2.6, 0.78, 2.2), Color("#ffc93c"), Vector3(0, 0.4, 0), 0.3, 0.3)
	# Körper (atmend)
	var body := _piv(_root, Vector3(0, 2.4, 0), "body")
	_sph(body, 2.2, Vector3.ZERO, rock, Vector3(1.15, 1.0, 1.25))
	_sph(body, 1.5, Vector3(0, -0.5, 1.2), belly, Vector3(1.0, 1.0, 0.6), 0.6)
	for k in 5:
		_box(body, Vector3(1.5 - k * 0.12, 0.08, 0.5), Vector3(0, -1.1 + k * 0.42, 1.95 - absf(k - 2) * 0.08), belly.darkened(0.15), Vector3(-0.3, 0, 0))
	# glühende Lavarisse (pulsieren)
	for k in 9:
		var a2 := -1.2 + k * 0.3
		var crack := _box(body, Vector3(0.09, randf_range(0.8, 1.6), 0.09), Vector3(sin(a2) * 2.35, randf_range(-0.4, 0.8), cos(a2) * 1.9 - 0.6), lava, Vector3(0, 0, randf_range(-0.6, 0.6)))
		_add_glow(crack, lava, 2.2)
	# Rückenstacheln
	for k in 7:
		_cyl(body, 0.0, 0.32, 0.8, Vector3(0, 2.0 - absf(k - 3) * 0.22, -1.6 + k * 0.45), rock2, Vector3(-0.4 + k * 0.05, 0, 0))
	_osc(body, "scl", Vector3(0.025, 0.04, 0.025), 1.0, 0.32)
	# Glühende Ketten um den Hals
	for k in 6:
		_torus(body, 0.12, 0.22, Vector3(-1.3 + k * 0.52, 1.25, 1.5 - absf(k - 2.5) * 0.1), Color("#8f8a96"), Vector3(0, 0, PI * 0.5 * (k % 2)), 0.4)
	# Kopf
	var neck := _piv(body, Vector3(0, 1.3, 1.6), "neck")
	_sph(neck, 0.9, Vector3(0, 0.3, 0.3), rock, Vector3(1.0, 1.0, 1.2))
	var head := _piv(neck, Vector3(0, 0.9, 0.9), "head")
	_sph(head, 1.05, Vector3.ZERO, rock2, Vector3(1.15, 0.95, 1.1))
	_sph(head, 0.75, Vector3(0, -0.15, 0.95), rock2, Vector3(1.05, 0.8, 1.1))
	for sd in [-1.0, 1.0]:
		var nos := _sph(head, 0.12, Vector3(sd * 0.32, 0.05, 1.7), Color("#1a1014"))
		parts["nostril_%d" % (0 if sd < 0 else 1)] = nos
		var horn := _cyl(head, 0.0, 0.22, 1.2, Vector3(sd * 0.65, 0.95, -0.4), Color("#e8dccb"), Vector3(-0.9, 0, sd * -0.35), 0.5)
		horn.scale = Vector3(1, 1, 1)
		_eye(head, Vector3(sd * 0.5, 0.42, 0.72), 0.26, Color("#ffcf3a"), Color("#fff4c0"), 0.8)
		_box(head, Vector3(0.42, 0.08, 0.14), Vector3(sd * 0.5, 0.72, 0.8), Color("#1a1014"), Vector3(0, 0, sd * 0.35))
		_cyl(head, 0.0, 0.07, 0.22, Vector3(sd * 0.28, -0.55, 1.55), Color.WHITE, Vector3(PI, 0, 0), 0.3)
		_sph(head, 0.16, Vector3(sd * 0.78, -0.05, 0.9), Color("#ff8a7a"), Vector3(1, 0.6, 0.4), 0.8)
	var jaw := _piv(head, Vector3(0, -0.45, 0.3), "jaw")
	_sph(jaw, 0.62, Vector3(0, -0.12, 0.75), rock, Vector3(1.0, 0.45, 1.15))
	var mouth := _sph(jaw, 0.3, Vector3(0, 0.05, 1.1), lava, Vector3(1.2, 0.4, 0.6), 0.5)
	_add_glow(mouth, lava, 2.0)
	parts["mouth"] = mouth
	_osc(neck, "rot", Vector3(1, 0, 0), 0.06, 0.32)
	_osc(head, "rot", Vector3(0, 1, 0.3), 0.1, 0.17)
	_blink(4.0)
	# Flügel (langsames Schlagen)
	for sd in [-1.0, 1.0]:
		var wing := _piv(body, Vector3(sd * 1.6, 1.2, -0.6))
		var bone := _cyl(wing, 0.1, 0.16, 3.2, Vector3(sd * 1.4, 0.8, 0), rock2, Vector3(0, 0, sd * -1.0))
		bone.name = "bone"
		for k in 3:
			var mem := _box(wing, Vector3(1.0, 2.2 - k * 0.4, 0.05), Vector3(sd * (1.1 + k * 0.85), 0.2 - k * 0.15, -0.2), Color("#7a2e3a"), Vector3(0, 0, sd * (-0.25 - k * 0.12)))
			mem.material_override = _mat(Color("#8c3342"), 0.8)
		_osc(wing, "rot", Vector3(0, 0, sd), 0.18, 0.3, 0.5)
	# Schweif aus Segmenten mit Stachelspitze
	var tail := _piv(body, Vector3(0, -1.2, -2.2), "tail")
	var prev := tail
	for k in 6:
		var seg := _piv(prev, Vector3(0, -0.05, -0.75))
		_sph(seg, 0.62 - k * 0.08, Vector3.ZERO, rock if k % 2 == 0 else rock2)
		_osc(seg, "rot", Vector3(0, 1, 0), 0.12, 0.25, k * 0.6)
		prev = seg
	_cyl(prev, 0.0, 0.35, 0.8, Vector3(0, 0.1, -0.6), Color("#e8dccb"), Vector3(-PI * 0.5, 0, 0))
	# Beine
	for sd in [-1.0, 1.0]:
		for fz in [1.0, -1.0]:
			var leg := _sph(_root, 0.75, Vector3(sd * 1.9, 0.6, fz * 1.2), rock2, Vector3(1, 1.2, 1))
			leg.name = "leg"
			for c in 3:
				_cyl(_root, 0.0, 0.1, 0.3, Vector3(sd * 1.9 + (c - 1) * 0.25, 0.08, fz * 1.2 + 0.75), Color("#e8dccb"), Vector3(PI * 0.5, 0, 0))
	# Rauchwölkchen aus den Nüstern im Atemrhythmus, Glutfunken
	_every(3.1, func() -> void:
		for k in 2:
			var nn: Node3D = parts.get("nostril_%d" % k)
			if nn:
				FX.smoke(nn.global_position + Vector3(0, 0.1, 0.2), Color(0.42, 0.4, 0.44), 4, 0.6))
	_every(1.7, func() -> void: FX.embers(global_position + Vector3(randf_range(-2, 2), 2.5, randf_range(-1, 1)), 3))
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.5, 0.2)
	lamp.light_energy = 1.4
	lamp.omni_range = 9.0
	lamp.position = Vector3(0, 2.0, 2.5)
	_root.add_child(lamp)


# =============================================================================================================
# 2) Klabautox, der Gezeiten-Leviathan – Riesenkrabbe mit lebendiger Muschel-Rüstung, klickt & blubbert
# =============================================================================================================
func _build_klabautox() -> void:
	var red := Color("#ef5a3c")
	var red2 := Color("#ff8a5c")
	var shell := Color("#f6dcb8")
	var stripe := Color("#ff9fb8")
	var body := _piv(_root, Vector3(0, 1.8, 0), "body")
	_sph(body, 2.2, Vector3.ZERO, red, Vector3(1.35, 0.7, 1.05), 0.5)
	_sph(body, 1.6, Vector3(0, -0.35, 0.9), red2, Vector3(1.2, 0.55, 0.6), 0.5)
	for k in 14:
		var a := randf() * TAU
		_sph(body, randf_range(0.1, 0.22), Vector3(cos(a) * 2.3, randf_range(-0.2, 0.6), sin(a) * 1.6), Color("#f9f1e1"), Vector3(1, 0.6, 1), 0.8)
	_osc(body, "scl", Vector3(0.02, 0.05, 0.02), 1.0, 0.45)
	# Muschel-Rüstung (Spiralturm) mit Streifen, Seepocken & Seetang
	var sh := _piv(body, Vector3(0, 1.1, -0.4), "shell")
	for k in 6:
		var rr := 1.6 - k * 0.24
		_cyl(sh, rr * 0.85, rr, 0.45, Vector3(0, k * 0.4, -k * 0.08), shell if k % 2 == 0 else stripe, Vector3(0.2, k * 0.4, 0), 0.4)
	_cyl(sh, 0.0, 0.25, 0.6, Vector3(0, 2.6, -0.5), shell, Vector3(0.25, 0, 0), 0.4)
	for k in 8:
		var a3 := TAU * k / 8.0
		var weed := _box(sh, Vector3(0.12, randf_range(0.8, 1.4), 0.04), Vector3(cos(a3) * 1.55, -0.3, sin(a3) * 1.55), Color("#5fbf6a"), Vector3(0, -a3, 0.2))
		_osc(weed, "rot", Vector3(0, 0, 1), 0.25, 0.5, k)
	# Stielaugen
	for sd in [-1.0, 1.0]:
		var stalk := _piv(body, Vector3(sd * 0.7, 1.2, 1.3))
		_cyl(stalk, 0.12, 0.15, 1.1, Vector3(0, 0.5, 0), red, Vector3.ZERO, 0.5)
		_eye(stalk, Vector3(0, 1.15, 0.05), 0.36, Color("#2a3a7a"))
		_osc(stalk, "rot", Vector3(0.3, 0, sd), 0.18, 0.4, sd)
		_sph(body, 0.22, Vector3(sd * 1.25, 0.15, 1.6), Color("#ff9fb8"), Vector3(1, 0.6, 0.4), 0.9)
	_blink(3.2)
	var mouth := _sph(body, 0.32, Vector3(0, -0.1, 1.78), Color("#7a1f2a"), Vector3(1.4, 0.55, 0.5), 0.6)
	parts["mouth"] = mouth
	# Scheren (klicken abwechselnd)
	for sd in [-1.0, 1.0]:
		var arm := _piv(body, Vector3(sd * 2.4, 0.0, 1.0), "claw_r" if sd > 0 else "claw_l")
		_cyl(arm, 0.28, 0.35, 1.6, Vector3(sd * 0.5, 0.3, 0.6), red, Vector3(0.9, 0, sd * -0.6), 0.5)
		var claw := _piv(arm, Vector3(sd * 1.0, 0.9, 1.4))
		_sph(claw, 0.8, Vector3.ZERO, red2, Vector3(1.0, 0.85, 1.25), 0.4)
		var top := _piv(claw, Vector3(0, 0.3, 0.6))
		_box(top, Vector3(0.45, 0.32, 1.2), Vector3(0, 0.1, 0.55), red, Vector3(-0.2, 0, 0), 0.4)
		_box(claw, Vector3(0.42, 0.28, 1.05), Vector3(0, -0.3, 1.05), red, Vector3(0.15, 0, 0), 0.4)
		_osc(top, "rot", Vector3(1, 0, 0), 0.35, 0.9, 0.0 if sd > 0 else PI)
		_osc(arm, "rot", Vector3(0, sd * 0.4, 1 * sd), 0.08, 0.35, sd)
	# Beine (tippeln)
	for sd in [-1.0, 1.0]:
		for k in 3:
			var leg := _piv(body, Vector3(sd * (1.9 - k * 0.1), -0.4, 0.6 - k * 0.8))
			_cyl(leg, 0.12, 0.16, 1.2, Vector3(sd * 0.6, -0.3, 0), red, Vector3(0, 0, sd * 1.0), 0.5)
			_cyl(leg, 0.04, 0.12, 1.1, Vector3(sd * 1.15, -0.95, 0), red2, Vector3(0, 0, sd * 0.25), 0.5)
			_osc(leg, "rot", Vector3(0, 0, 1), 0.12, 1.2, k * 1.3 + sd)
	# Blasen im Takt
	_every(1.3, func() -> void:
		var m: Node3D = parts.mouth
		FX.bubbles(m.global_position + Vector3(0, 0.2, 0.3), 5))


# =============================================================================================================
# 3) Astraios, der Himmelsgolem – schwebende Wolkensteine, von Gravitationsfeldern gehalten, Sternenstaub
# =============================================================================================================
func _build_astraios() -> void:
	var stone := Color("#c4bfe3")
	var stone2 := Color("#a49fd0")
	var rune := Color("#ffd86b")
	var core := _piv(_root, Vector3(0, 4.2, 0), "body")
	_osc(core, "pos", Vector3(0, 1, 0), 0.35, 0.22)
	var torso := _piv(core, Vector3.ZERO)
	_box(torso, Vector3(2.8, 2.4, 2.0), Vector3.ZERO, stone, Vector3(0, 0, 0), 0.8)
	_box(torso, Vector3(2.2, 0.6, 2.1), Vector3(0, 1.0, 0), stone2, Vector3.ZERO, 0.8)
	_box(torso, Vector3(1.6, 0.5, 2.05), Vector3(0, -1.0, 0), stone2, Vector3.ZERO, 0.8)
	for k in 5:
		_add_glow(_box(torso, Vector3(0.08, 1.6, 0.04), Vector3(-0.9 + k * 0.45, 0, 1.02), rune, Vector3(0, 0, (k - 2) * 0.12)), rune, 1.8)
	var gem := _sph(torso, 0.4, Vector3(0, 0.2, 1.05), Color("#7fd6ff"), Vector3(1, 1, 0.5), 0.2)
	_add_glow(gem, Color("#7fd6ff"), 2.5)
	_osc(torso, "rot", Vector3(0, 1, 0), 0.08, 0.15)
	# Kopf (schwebt über dem Rumpf) mit leuchtendem Visier
	var head := _piv(core, Vector3(0, 2.15, 0.1), "head")
	_box(head, Vector3(1.4, 1.1, 1.2), Vector3.ZERO, stone, Vector3.ZERO, 0.8)
	_box(head, Vector3(1.5, 0.25, 1.3), Vector3(0, 0.62, 0), stone2, Vector3.ZERO, 0.8)
	for sd in [-1.0, 1.0]:
		var e := _eye(head, Vector3(sd * 0.32, 0.05, 0.6), 0.2, Color("#7fd6ff"), Color("#e8f8ff"), 1.2)
		e.scale = Vector3(1.2, 0.8, 1)
	_osc(head, "pos", Vector3(0, 1, 0), 0.12, 0.3, 1.0)
	_blink(5.0)
	parts["mouth"] = head
	# Schultern, Arme, Hände: lose schwebende Steine
	for sd in [-1.0, 1.0]:
		var sh := _piv(core, Vector3(sd * 2.1, 0.8, 0))
		_box(sh, Vector3(1.0, 0.9, 1.0), Vector3.ZERO, stone2, Vector3(0, 0, sd * 0.2), 0.8)
		_osc(sh, "pos", Vector3(sd * 0.15, 1, 0), 0.12, 0.35, sd)
		var arm := _piv(core, Vector3(sd * 2.5, -0.5, 0.3))
		_box(arm, Vector3(0.7, 1.2, 0.7), Vector3.ZERO, stone, Vector3(0, 0, sd * 0.15), 0.8)
		_osc(arm, "pos", Vector3(0, 1, 0.3), 0.18, 0.3, sd + 1.0)
		var hand := _piv(core, Vector3(sd * 2.7, -1.9, 0.6), "claw_r" if sd > 0 else "hand_l")
		_sph(hand, 0.55, Vector3.ZERO, stone2, Vector3(1, 0.9, 1), 0.8)
		for f in 3:
			_box(hand, Vector3(0.16, 0.4, 0.16), Vector3((f - 1) * 0.22, -0.5, 0.25), stone, Vector3(0.3, 0, 0), 0.8)
		_osc(hand, "pos", Vector3(0, 1, 0.2), 0.22, 0.28, sd * 2.0)
	# Wolkenrock
	for k in 10:
		var a := TAU * k / 10.0
		_sph(core, randf_range(0.6, 0.9), Vector3(cos(a) * 1.4, -1.9 + randf() * 0.3, sin(a) * 1.1), Color(1, 1, 1), Vector3(1, 0.7, 1), 1.0, 0.15)
	# Halo und kreisende Kleinsteine
	var halo := _piv(core, Vector3(0, 0.4, -1.4))
	_add_glow(_torus(halo, 2.4, 2.55, Vector3.ZERO, rune, Vector3(PI * 0.5, 0, 0)), rune, 1.2)
	_spin(halo, Vector3(0, 0, 1), 0.4)
	var orbit := _piv(core, Vector3.ZERO)
	for k in 7:
		var a2 := TAU * k / 7.0
		_box(orbit, Vector3(0.4, 0.4, 0.4), Vector3(cos(a2) * 3.4, sin(a2 * 2.0) * 0.6, sin(a2) * 3.4), stone2, Vector3(a2, a2, 0), 0.8)
	_spin(orbit, Vector3(0, 1, 0), 0.5)
	var dust := FX.emitter({"amount": 22, "life": 2.5, "one_shot": false, "explosive": 0.0, "spread": 180.0, "vel_min": 0.2, "vel_max": 0.6,
		"gravity": Vector3.ZERO, "size": 0.16, "color": Color(1.0, 0.95, 0.7), "tex": FX.tex_star, "radius": 3.0, "additive": true})
	core.add_child(dust)
	dust.emitting = true


# =============================================================================================================
# 4) Graf Grabstein – aristokratischer Obergeist mit Zylinder, Monokel und Schauermantel, kichert & flimmert
# =============================================================================================================
func _build_grabstein() -> void:
	var ghost := Color(0.88, 0.98, 0.95, 0.9)
	var cape := Color("#4a2a6a")
	var body := _piv(_root, Vector3(0, 3.4, 0), "body")
	_osc(body, "pos", Vector3(0, 1, 0), 0.4, 0.25)
	_osc(body, "rot", Vector3(0, 0, 1), 0.06, 0.18)
	# Laken-Körper mit welligem Saum
	_sph(body, 1.6, Vector3(0, 0.6, 0), ghost, Vector3(1, 1.05, 1), 0.4, 0.35)
	_cyl(body, 1.5, 2.1, 2.2, Vector3(0, -0.9, 0), ghost, Vector3.ZERO, 0.4, 0.35, 20)
	for k in 12:
		var a := TAU * k / 12.0
		var hem := _sph(body, 0.38, Vector3(cos(a) * 1.95, -2.05, sin(a) * 1.95), ghost, Vector3(1, 0.8, 1), 0.4, 0.35)
		_osc(hem, "pos", Vector3(0, 1, 0), 0.12, 0.6, k * 0.8)
	# Gesicht: halb geschlossene, spöttische Augen, Monokel, Schnurrbart, Grinsen
	for sd in [-1.0, 1.0]:
		var e := _eye(body, Vector3(sd * 0.55, 1.0, 1.35), 0.3, Color("#5a2a8a"))
		_box(e, Vector3(0.7, 0.24, 0.3), Vector3(0, 0.2, 0.1), ghost.darkened(0.1), Vector3(0, 0, sd * -0.15), 0.4)
		_box(body, Vector3(0.55, 0.12, 0.12), Vector3(sd * 0.32, 0.35, 1.5), Color("#3a2a3a"), Vector3(0, 0, sd * 0.5))
		_sph(body, 0.18, Vector3(sd * 1.0, 0.5, 1.2), Color("#c7a0ff"), Vector3(1, 0.6, 0.4), 0.8)
	_add_glow(_torus(body, 0.3, 0.38, Vector3(0.55, 1.0, 1.62), Color("#ffd23f"), Vector3(PI * 0.5, 0, 0), 0.2), Color("#ffd23f"), 0.6)
	_cyl(body, 0.02, 0.02, 0.9, Vector3(0.85, 0.5, 1.55), Color("#ffd23f"), Vector3(0, 0, 0.3), 0.2)
	var mouth := _box(body, Vector3(0.7, 0.14, 0.1), Vector3(0, 0.05, 1.55), Color("#2a1a3a"), Vector3(0, 0, 0.12))
	parts["mouth"] = mouth
	_blink(3.0)
	# Zylinder
	var hat := _piv(body, Vector3(0, 2.25, 0.1), "head")
	_cyl(hat, 1.1, 1.1, 0.12, Vector3.ZERO, Color("#1d1424"), Vector3(-0.1, 0, 0.12), 0.5)
	_cyl(hat, 0.75, 0.8, 1.3, Vector3(0, 0.7, 0), Color("#1d1424"), Vector3(-0.1, 0, 0.12), 0.5)
	_cyl(hat, 0.81, 0.81, 0.25, Vector3(0, 0.2, 0), Color("#8a3ad0"), Vector3(-0.1, 0, 0.12), 0.5)
	_osc(hat, "rot", Vector3(0, 0, 1), 0.06, 0.5)
	# Schauermantel (schwingt)
	for sd in [-1.0, 1.0]:
		var panel := _piv(body, Vector3(sd * 1.2, 1.3, -0.6))
		_box(panel, Vector3(1.3, 3.4, 0.08), Vector3(sd * 0.35, -1.6, 0), cape, Vector3(0.1, sd * -0.4, sd * 0.08), 0.6)
		_box(panel, Vector3(1.32, 0.3, 0.1), Vector3(sd * 0.35, 0.05, 0.02), Color("#c0304a"), Vector3(0.1, sd * -0.4, sd * 0.08), 0.6)
		_osc(panel, "rot", Vector3(0.3, 0, sd), 0.12, 0.35, sd)
		var arm := _piv(body, Vector3(sd * 1.5, 0.2, 0.6), "claw_r" if sd > 0 else "arm_l")
		var cap := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.28
		cm.height = 1.4
		cap.mesh = cm
		cap.material_override = _mat(ghost, 0.4, 0.35)
		cap.rotation.z = sd * 1.0
		cap.position = Vector3(sd * 0.45, -0.3, 0.2)
		arm.add_child(cap)
		_sph(arm, 0.32, Vector3(sd * 0.95, -0.75, 0.4), Color.WHITE, Vector3.ONE, 0.6)
		_osc(arm, "rot", Vector3(0.4, 0, sd), 0.2, 0.4, sd * 1.5)
	# kreisende Kerzen & Mini-Phantome
	var ring := _piv(_root, Vector3(0, 3.2, 0))
	for k in 5:
		var a2 := TAU * k / 5.0
		var cpos := Vector3(cos(a2) * 3.6, sin(a2 * 3.0) * 0.4, sin(a2) * 3.6)
		_cyl(ring, 0.1, 0.1, 0.5, cpos, Color("#f4ecd8"))
		var fl := _sph(ring, 0.1, cpos + Vector3(0, 0.36, 0), Color("#ffbf3a"), Vector3(1, 1.6, 1))
		_add_glow(fl, Color("#ffbf3a"), 2.4)
	_spin(ring, Vector3(0, 1, 0), 0.35)
	var mini := _piv(_root, Vector3(0, 5.6, 0))
	for k in 3:
		var a3 := TAU * k / 3.0
		var mg := _piv(mini, Vector3(cos(a3) * 2.6, 0, sin(a3) * 2.6))
		_sph(mg, 0.4, Vector3.ZERO, ghost, Vector3(1, 1.1, 1), 0.4, 0.4)
		_sph(mg, 0.07, Vector3(-0.13, 0.08, 0.35), Color("#2a1a3a"))
		_sph(mg, 0.07, Vector3(0.13, 0.08, 0.35), Color("#2a1a3a"))
		_osc(mg, "pos", Vector3(0, 1, 0), 0.3, 0.5, k * 2.0)
	_spin(mini, Vector3(0, 1, 0), -0.6)
	# Flimmern (kurz durchsichtiger) & Kichern
	_every(4.5, func() -> void:
		var m := _mat(ghost, 0.4, 0.35)
		var tw := create_tween()
		tw.tween_property(m, "albedo_color:a", 0.35, 0.12)
		tw.tween_property(m, "albedo_color:a", 0.9, 0.2)
		var b: Node3D = parts.body
		var tw2 := create_tween()
		for k in 3:
			tw2.tween_property(b, "rotation:z", 0.08, 0.07)
			tw2.tween_property(b, "rotation:z", -0.08, 0.07)
		tw2.tween_property(b, "rotation:z", 0.0, 0.07))


# =============================================================================================================
# 5) Yeti-König Frostbart – extrem flauschig, funkelnde Eiskrone, treuherzig-wütender Blick
# =============================================================================================================
func _build_frostbart() -> void:
	var fur := Color("#f4f8ff")
	var fur2 := Color("#dbe8ff")
	var skin := Color("#9fc0e8")
	var body := _piv(_root, Vector3(0, 2.6, 0), "body")
	_sph(body, 2.2, Vector3.ZERO, fur, Vector3(1.1, 1.15, 1.0), 1.0)
	# Fell-Büschel rundum (wackeln einzeln)
	for k in 40:
		var a := randf() * TAU
		var y := randf_range(-1.8, 2.2)
		var r := sqrt(maxf(0.0, 1.0 - pow(y / 2.6, 2))) * 2.35
		var tp := Vector3(cos(a) * r, y, sin(a) * r * 0.92)
		if tp.z > 0.9 and absf(tp.x) < 1.5 and tp.y > -0.3 and tp.y < 2.0:
			continue   # Gesicht frei lassen
		var tuft := _sph(body, randf_range(0.38, 0.62), tp, fur if k % 3 else fur2, Vector3.ONE, 1.0)
		if k % 4 == 0:
			_osc(tuft, "scl", Vector3(0.08, 0.08, 0.08), 1.0, 0.6, k)
	_osc(body, "scl", Vector3(0.03, 0.04, 0.03), 1.0, 0.3)
	# Gesicht
	var face := _piv(body, Vector3(0, 0.9, 2.05), "head")
	_sph(face, 0.95, Vector3.ZERO, skin, Vector3(1.15, 0.95, 0.5), 0.7)
	for sd in [-1.0, 1.0]:
		_eye(face, Vector3(sd * 0.42, 0.15, 0.32), 0.27, Color("#3a7ad0"))
		var brow := _box(face, Vector3(0.55, 0.14, 0.14), Vector3(sd * 0.42, 0.55, 0.42), Color("#7c8fb0"), Vector3(0, 0, sd * 0.38))
		_osc(brow, "rot", Vector3(0, 0, sd), 0.08, 0.7)
		_sph(face, 0.15, Vector3(sd * 0.72, -0.2, 0.36), Color("#ff9fb8"), Vector3(1, 0.6, 0.4), 0.9)
		_cyl(face, 0.0, 0.06, 0.18, Vector3(sd * 0.18, -0.48, 0.42), Color.WHITE, Vector3(PI, 0, 0), 0.3)
	_sph(face, 0.2, Vector3(0, -0.12, 0.48), Color("#5a6a8a"), Vector3(1.2, 0.8, 0.6), 0.5)
	var mouth := _box(face, Vector3(0.55, 0.1, 0.1), Vector3(0, -0.42, 0.45), Color("#3a4a6a"), Vector3(0, 0, PI))
	parts["mouth"] = mouth
	_blink(3.8)
	# Eiskrone
	var crown := _piv(body, Vector3(0, 2.55, 0.2))
	_torus(crown, 0.8, 0.98, Vector3.ZERO, Color("#ffd23f"), Vector3.ZERO, 0.25)
	for k in 7:
		var a2 := TAU * k / 7.0
		var spike := _cyl(crown, 0.0, 0.18, 0.6 + (k % 2) * 0.25, Vector3(cos(a2) * 0.88, 0.35, sin(a2) * 0.88), Color("#9fe8ff"), Vector3.ZERO, 0.1)
		_add_glow(spike, Color("#9fe8ff"), 1.0)
	_osc(crown, "rot", Vector3(0, 0, 1), 0.05, 0.4)
	_every(1.0, func() -> void: FX.stars(crown.global_position + Vector3(randf_range(-0.8, 0.8), 0.6, 0), Color(0.8, 0.95, 1.0), 2))
	# Arme mit flauschigen Fäusten, Füße
	for sd in [-1.0, 1.0]:
		var arm := _piv(body, Vector3(sd * 2.1, 0.4, 0.3), "claw_r" if sd > 0 else "arm_l")
		_sph(arm, 0.75, Vector3(sd * 0.3, -0.6, 0), fur, Vector3(1, 1.4, 1), 1.0)
		_sph(arm, 0.7, Vector3(sd * 0.45, -1.7, 0.3), fur2, Vector3.ONE, 1.0)
		_sph(arm, 0.4, Vector3(sd * 0.45, -1.85, 0.85), skin, Vector3(1, 0.8, 0.6), 0.7)
		_osc(arm, "rot", Vector3(0.3, 0, sd), 0.1, 0.3, sd)
		_sph(_root, 0.8, Vector3(sd * 1.1, 0.35, 0.6), fur2, Vector3(1.1, 0.6, 1.4), 1.0)
		_sph(_root, 0.38, Vector3(sd * 1.1, 0.25, 1.55), skin, Vector3(1.1, 0.5, 0.6), 0.7)
	var snow := FX.emitter({"amount": 26, "life": 3.0, "one_shot": false, "explosive": 0.0, "spread": 40.0, "vel_min": 0.3, "vel_max": 0.7,
		"gravity": Vector3(0, -0.6, 0), "size": 0.14, "color": Color(1, 1, 1, 0.9), "box": Vector3(4, 0.5, 4)})
	snow.position = Vector3(0, 7.0, 0)
	_root.add_child(snow)
	snow.emitting = true


# =============================================================================================================
# 6) Galaxus, der Kosmos-Uhrmacher – schwebendes Uhrwerk mit Zahnrädern, Pendel und Hologramm-Planeten
# =============================================================================================================
func _build_galaxus() -> void:
	var brass := Color("#d9a441")
	var brass2 := Color("#b07a2a")
	var cream := Color("#fbf3e0")
	var core := _piv(_root, Vector3(0, 4.4, 0), "body")
	_osc(core, "pos", Vector3(0, 1, 0), 0.28, 0.2)
	# Zifferblatt
	var face := _piv(core, Vector3.ZERO, "head")
	_cyl(face, 2.2, 2.2, 0.5, Vector3.ZERO, brass2, Vector3(PI * 0.5, 0, 0), 0.3, 0.0, 28)
	_cyl(face, 1.95, 1.95, 0.52, Vector3(0, 0, 0.02), cream, Vector3(PI * 0.5, 0, 0), 0.5, 0.0, 28)
	_torus(face, 2.05, 2.35, Vector3(0, 0, 0.18), brass, Vector3(PI * 0.5, 0, 0), 0.2)
	for k in 12:
		var a := TAU * k / 12.0
		_box(face, Vector3(0.1, 0.32 if k % 3 == 0 else 0.18, 0.05), Vector3(sin(a) * 1.65, cos(a) * 1.65, 0.3), Color("#3a2a1a"), Vector3(0, 0, -a))
	var hour := _piv(face, Vector3(0, 0, 0.32))
	_box(hour, Vector3(0.14, 1.0, 0.05), Vector3(0, 0.45, 0), Color("#2a1a10"))
	_spin(hour, Vector3(0, 0, 1), -0.08)
	var minute := _piv(face, Vector3(0, 0, 0.36))
	_box(minute, Vector3(0.09, 1.45, 0.05), Vector3(0, 0.68, 0), Color("#2a1a10"))
	parts["minute"] = minute
	_every(1.0, func() -> void:
		var m: Node3D = parts.minute
		var tw := m.create_tween()
		tw.tween_property(m, "rotation:z", m.rotation.z - TAU / 60.0, 0.12).set_trans(Tween.TRANS_BACK)
		Audio.sfx("wheel_tick", null, -24.0, 1.4))
	# niedliches Gesicht auf dem Zifferblatt
	for sd in [-1.0, 1.0]:
		_eye(face, Vector3(sd * 0.62, 0.35, 0.36), 0.28, Color("#4a8aff"), Color.WHITE, 0.3)
		_sph(face, 0.16, Vector3(sd * 1.0, -0.15, 0.36), Color("#ffb3c8"), Vector3(1, 0.6, 0.3), 0.8)
	var mouth := _box(face, Vector3(0.5, 0.1, 0.05), Vector3(0, -0.5, 0.36), Color("#3a2a1a"))
	parts["mouth"] = mouth
	_blink(4.2)
	# Glocke oben
	_sph(core, 0.55, Vector3(0, 2.6, -0.1), brass, Vector3(1, 0.85, 1), 0.2)
	_cyl(core, 0.08, 0.08, 0.5, Vector3(0, 2.2, -0.1), brass2)
	# Zahnräder links/rechts, ineinandergreifend
	for e in [[Vector3(-2.7, 0.9, -0.3), 1.1, 0.6], [Vector3(2.7, 0.7, -0.3), 1.2, -0.55], [Vector3(-2.3, -1.4, -0.4), 0.75, -0.9], [Vector3(2.0, -1.6, -0.4), 0.8, 0.85]]:
		var g := _piv(core, e[0])
		var r: float = e[1]
		_cyl(g, r, r, 0.25, Vector3.ZERO, brass if r > 1.0 else brass2, Vector3(PI * 0.5, 0, 0), 0.25, 0.0, 20)
		_cyl(g, r * 0.3, r * 0.3, 0.32, Vector3.ZERO, brass2, Vector3(PI * 0.5, 0, 0), 0.25)
		var teeth := int(r * 12)
		for k in teeth:
			var a2 := TAU * k / teeth
			_box(g, Vector3(0.22, 0.28, 0.24), Vector3(cos(a2) * (r + 0.1), sin(a2) * (r + 0.1), 0), brass, Vector3(0, 0, a2), 0.25)
		_spin(g, Vector3(0, 0, 1), float(e[2]))
	# Pendel
	var pend := _piv(core, Vector3(0, -2.2, -0.2), "tail")
	_cyl(pend, 0.06, 0.06, 2.0, Vector3(0, -1.0, 0), brass2)
	_cyl(pend, 0.5, 0.5, 0.12, Vector3(0, -2.1, 0), brass, Vector3(PI * 0.5, 0, 0), 0.2)
	_osc(pend, "rot", Vector3(0, 0, 1), 0.4, 0.5)
	# Hologramm-Planeten
	var orbit := _piv(core, Vector3.ZERO)
	for e2 in [[3.3, 0.35, Color("#7fd6ff")], [4.0, 0.45, Color("#ff9f6b")], [4.6, 0.3, Color("#c79bff")]]:
		var a3 := randf() * TAU
		var pp := Vector3(cos(a3) * float(e2[0]), 0.4, sin(a3) * float(e2[0]))
		var pl := _sph(orbit, float(e2[1]), pp, e2[2], Vector3.ONE, 0.3)
		_add_glow(pl, e2[2], 1.4)
		if float(e2[1]) > 0.4:
			_add_glow(_torus(orbit, 0.55, 0.62, pp, Color(1, 0.9, 0.6), Vector3(0.6, 0, 0.3)), Color(1, 0.9, 0.6), 1.0)
	_spin(orbit, Vector3(0, 1, 0), 0.45)


# =============================================================================================================
# 7) Noxumbra, die Schattenwurzel – knorriger Baumgeist mit biolumineszenten Pilzen, pulsiert im Takt
# =============================================================================================================
func _build_noxumbra() -> void:
	var bark := Color("#4a3428")
	var bark2 := Color("#5e4434")
	var leaf := Color("#2f5a3a")
	var cyan := Color("#5fffe0")
	var purple := Color("#c77dff")
	var body := _piv(_root, Vector3(0, 0, 0), "body")
	_cyl(body, 1.3, 2.0, 5.2, Vector3(0, 2.6, 0), bark, Vector3.ZERO, 0.95, 0.0, 16)
	for k in 6:
		var a := TAU * k / 6.0
		_cyl(body, 0.3, 0.6, 1.6, Vector3(cos(a) * 1.9, 0.4, sin(a) * 1.9), bark2, Vector3(sin(a) * 0.9, 0, -cos(a) * 0.9), 0.95)
	for k in 8:
		_box(body, Vector3(0.12, randf_range(1.0, 2.2), 0.1), Vector3(randf_range(-1.2, 1.2), randf_range(1.0, 4.4), 1.55), bark2, Vector3(0, 0, randf_range(-0.3, 0.3)))
	_osc(body, "scl", Vector3(0.02, 0.015, 0.02), 1.0, 0.25)
	# Gesicht als Astlöcher mit leuchtenden Augen und Mund
	var face := _piv(body, Vector3(0, 3.4, 1.45), "head")
	for sd in [-1.0, 1.0]:
		_sph(face, 0.42, Vector3(sd * 0.5, 0.2, 0), Color("#140c08"), Vector3(1, 1.2, 0.5))
		var pupil := _sph(face, 0.18, Vector3(sd * 0.5, 0.18, 0.2), cyan, Vector3(1, 1.3, 0.5), 0.3)
		_add_glow(pupil, cyan, 2.2)
		var e := _piv(face, Vector3(sd * 0.5, 0.2, 0.05))
		(parts.get_or_add("eyes", []) as Array).append(e)
	var mouth := _sph(face, 0.5, Vector3(0, -0.6, 0), Color("#140c08"), Vector3(1.4, 0.6, 0.4))
	parts["mouth"] = mouth
	_add_glow(_sph(face, 0.2, Vector3(0, -0.62, 0.12), purple, Vector3(2.2, 0.35, 0.3), 0.3), purple, 1.4)
	# Äste mit Blattbüscheln und Pilzen, sanft schwingend
	for e2 in [[Vector3(-1.0, 4.6, 0), -1.0, 0.0], [Vector3(1.0, 4.9, 0), 1.0, 1.0], [Vector3(-0.6, 5.3, -0.5), -0.6, 2.0], [Vector3(0.7, 5.4, 0.4), 0.7, 3.0]]:
		var br := _piv(body, e2[0])
		var sd2: float = e2[1]
		_cyl(br, 0.15, 0.35, 2.6, Vector3(sd2 * 1.0, 0.9, 0), bark2, Vector3(0, 0, -sd2 * 0.75), 0.95)
		for k in 3:
			_sph(br, randf_range(0.7, 1.0), Vector3(sd2 * (1.8 + k * 0.3), 1.9 + k * 0.2, randf_range(-0.5, 0.5)), leaf, Vector3.ONE, 0.9)
		_osc(br, "rot", Vector3(0.2, 0, 1), 0.07, 0.25, float(e2[2]))
	# Biolumineszente Pilze am Stamm (pulsieren gemeinsam)
	var mush: Array = []
	for k in 9:
		var a3 := randf_range(-1.3, 1.3)
		var y := randf_range(0.6, 4.2)
		var pos := Vector3(sin(a3) * 1.65, y, cos(a3) * 1.45)
		_cyl(body, 0.06, 0.08, 0.3, pos + Vector3(0, -0.1, 0), Color("#e8e0d0"))
		var cap := _sph(body, randf_range(0.22, 0.38), pos + Vector3(0, 0.1, 0), cyan if k % 2 == 0 else purple, Vector3(1, 0.5, 1), 0.4)
		mush.append(_add_glow(cap, cyan if k % 2 == 0 else purple, 1.8))
	parts["mush"] = mush
	_every(0.05, func() -> void:
		var e3 := 1.4 + sin(t * 2.4) * 0.9 + rage * 0.6
		for mi in parts.mush:
			((mi as MeshInstance3D).material_override as StandardMaterial3D).emission_energy_multiplier = e3)
	var flies := FX.emitter({"amount": 20, "life": 3.0, "one_shot": false, "explosive": 0.0, "spread": 180.0, "vel_min": 0.2, "vel_max": 0.6,
		"gravity": Vector3.ZERO, "size": 0.12, "color": Color(0.9, 1.0, 0.5), "radius": 3.5, "additive": true})
	flies.position = Vector3(0, 3.0, 0)
	_root.add_child(flies)
	flies.emitting = true
	var lamp := OmniLight3D.new()
	lamp.light_color = cyan
	lamp.light_energy = 1.0
	lamp.omni_range = 8.0
	lamp.position = Vector3(0, 3.0, 2.5)
	_root.add_child(lamp)


# =============================================================================================================
# 8) Baaah-hemoth, das Wolken-Schaf – gigantisch flauschig, goldene Hörner, Kulleraugen, scharrt mit den Hufen
# =============================================================================================================
func _build_baahemoth() -> void:
	var wool := Color("#fbfbf6")
	var wool2 := Color("#eef0f6")
	var face_c := Color("#3a3040")
	var body := _piv(_root, Vector3(0, 2.6, 0), "body")
	for k in 34:
		var a := randf() * TAU
		var y := randf_range(-1.2, 1.4)
		var rr := sqrt(maxf(0.0, 1.0 - pow(y / 1.8, 2))) * 2.4
		var puff := _sph(body, randf_range(0.7, 1.1), Vector3(cos(a) * rr, y, sin(a) * rr * 1.1), wool if k % 2 else wool2, Vector3.ONE, 1.0)
		_osc(puff, "scl", Vector3(0.06, 0.06, 0.06), 1.0, 0.35, k * 0.4)
	_sph(body, 2.2, Vector3.ZERO, wool, Vector3(1.15, 0.9, 1.25), 1.0)
	_osc(body, "scl", Vector3(0.03, 0.05, 0.03), 1.0, 0.3)
	# Kopf
	var head := _piv(body, Vector3(0, 0.6, 2.4), "head")
	_sph(head, 1.0, Vector3.ZERO, face_c, Vector3(0.95, 1.05, 1.0), 0.8)
	_sph(head, 0.7, Vector3(0, -0.4, 0.55), face_c.lightened(0.08), Vector3(1.0, 0.75, 0.9), 0.8)
	for k in 6:
		_sph(head, 0.42, Vector3(-0.6 + k * 0.24, 0.95, -0.1), wool, Vector3.ONE, 1.0)
	for sd in [-1.0, 1.0]:
		_eye(head, Vector3(sd * 0.42, 0.2, 0.78), 0.36, Color("#3a2a1a"))
		_sph(head, 0.18, Vector3(sd * 0.68, -0.25, 0.75), Color("#ff9fb8"), Vector3(1, 0.6, 0.4), 0.9)
		# goldene Schneckenhörner
		var horn := _piv(head, Vector3(sd * 0.85, 0.55, -0.1))
		for k in 5:
			_torus(horn, 0.2 + k * 0.05, 0.34 + k * 0.05, Vector3(sd * k * 0.12, -k * 0.08, k * 0.06), Color("#ffcf3a"), Vector3(0, PI * 0.5, 0), 0.2, 0.2)
		var ear := _piv(head, Vector3(sd * 1.0, 0.25, 0.2))
		_box(ear, Vector3(0.6, 0.18, 0.3), Vector3(sd * 0.3, 0, 0), face_c, Vector3(0, 0, sd * -0.4))
		_osc(ear, "rot", Vector3(0, 0, sd), 0.25, 0.4, sd)
	_sph(head, 0.1, Vector3(-0.18, -0.35, 1.18), Color("#1a1016"))
	_sph(head, 0.1, Vector3(0.18, -0.35, 1.18), Color("#1a1016"))
	var mouth := _box(head, Vector3(0.35, 0.08, 0.08), Vector3(0, -0.62, 1.12), Color("#1a1016"))
	parts["mouth"] = mouth
	_blink(3.0)
	_osc(head, "rot", Vector3(0.3, 1, 0), 0.08, 0.2)
	# Glocke am Halsband
	_torus(body, 0.9, 1.1, Vector3(0, 0.0, 2.0), Color("#e84a5f"), Vector3(PI * 0.35, 0, 0), 0.6)
	var bell := _sph(body, 0.35, Vector3(0, -0.6, 2.6), Color("#ffcf3a"), Vector3.ONE, 0.2)
	bell.material_override = _mat(Color("#ffcf3a"), 0.2, 0.2, 0.6)
	# Beine & Hufe (scharren)
	for sd in [-1.0, 1.0]:
		for fz in [1.0, -1.0]:
			var leg := _piv(_root, Vector3(sd * 1.3, 1.2, fz * 1.3), "leg_%d_%d" % [int(sd), int(fz)])
			_cyl(leg, 0.28, 0.24, 1.3, Vector3(0, -0.55, 0), face_c)
			_cyl(leg, 0.3, 0.32, 0.25, Vector3(0, -1.15, 0.05), Color("#1a1016"))
	_every(2.6, func() -> void:
		var lg: Node3D = parts.get("leg_1_1")
		if lg:
			var tw := lg.create_tween()
			tw.tween_property(lg, "rotation:x", -0.5, 0.15)
			tw.tween_property(lg, "rotation:x", 0.2, 0.15)
			tw.tween_property(lg, "rotation:x", 0.0, 0.15)
			FX.dust(lg.global_position + Vector3(0, -1.1, 0.6), Color(0.7, 0.85, 0.5), 6, 0.6))
	_sph(body, 0.5, Vector3(0, 0.6, -2.6), wool, Vector3.ONE, 1.0)


# =============================================================================================================
# 9) Marzipan-Marquise & das Sahne-Monster – lebendige Torte mit Karamellglanz, Kerzen und Sahnehauben-Gesichtern
# =============================================================================================================
func _build_marquise() -> void:
	var pink := Color("#ffb3cf")
	var cream := Color("#fff5e6")
	var choco := Color("#7a4a32")
	var caramel := Color("#e8a23a")
	var body := _piv(_root, Vector3(0, 0, 0), "body")
	var tiers := [[2.6, 1.4, 0.7, choco], [2.0, 1.3, 2.05, pink], [1.4, 1.1, 3.25, cream]]
	for tr in tiers:
		_cyl(body, float(tr[0]), float(tr[0]), float(tr[1]), Vector3(0, float(tr[2]), 0), tr[3], Vector3.ZERO, 0.6, 0.0, 24)
		# Glasur-Tropfen am Rand
		var top := float(tr[2]) + float(tr[1]) * 0.5
		var gl := _cyl(body, float(tr[0]) + 0.05, float(tr[0]) + 0.05, 0.16, Vector3(0, top - 0.05, 0), caramel if tr[3] != cream else Color("#ff8fb8"), Vector3.ZERO, 0.08, 0.0, 24)
		gl.material_override = _mat(caramel if tr[3] != cream else Color("#ff8fb8"), 0.08, 0.15, 0.1)
		for k in 14:
			var a := TAU * k / 14.0
			var dr := _sph(body, 0.16, Vector3(cos(a) * (float(tr[0]) + 0.04), top - 0.25 - (k % 3) * 0.12, sin(a) * (float(tr[0]) + 0.04)), caramel if tr[3] != cream else Color("#ff8fb8"), Vector3(1, 1.6, 1), 0.08)
			dr.material_override = gl.material_override
	_osc(body, "scl", Vector3(0.03, -0.03, 0.03), 1.0, 0.55)
	# Gesicht der Marquise auf der mittleren Etage
	var face := _piv(body, Vector3(0, 2.15, 1.95), "head")
	for sd in [-1.0, 1.0]:
		var e := _eye(face, Vector3(sd * 0.55, 0.15, 0.05), 0.3, Color("#8a3a6a"))
		for l in 3:
			_box(e, Vector3(0.05, 0.18, 0.04), Vector3(sd * (0.12 + l * 0.1), 0.3, 0.16), Color("#2a1a2a"), Vector3(0, 0, sd * (-0.3 - l * 0.25)))
		_sph(face, 0.18, Vector3(sd * 0.95, -0.2, 0.0), Color("#ff7aa8"), Vector3(1, 0.6, 0.3), 0.9)
	var mouth := _torus(face, 0.14, 0.22, Vector3(0, -0.4, 0.06), Color("#c0304a"), Vector3(PI * 0.5, 0, 0), 0.4)
	parts["mouth"] = mouth
	_blink(3.4)
	# Krönchen
	var tiara := _piv(body, Vector3(0, 4.0, 0.6))
	_torus(tiara, 0.45, 0.55, Vector3.ZERO, Color("#ffd23f"), Vector3(0.3, 0, 0), 0.2)
	for k in 3:
		_add_glow(_sph(tiara, 0.12, Vector3(-0.3 + k * 0.3, 0.3 + (k % 2) * 0.12, 0.1), Color("#ff5c9a"), Vector3.ONE, 0.2), Color("#ff5c9a"), 1.0)
	# Kerzen mit flackernden Flammen
	var flames: Array = []
	for k in 6:
		var a2 := TAU * k / 6.0
		var cp := Vector3(cos(a2) * 0.95, 4.15, sin(a2) * 0.95)
		_cyl(body, 0.1, 0.1, 0.8, cp, [Color("#7fd6ff"), Color("#ffd23f"), Color("#c79bff")][k % 3])
		var fl := _sph(body, 0.12, cp + Vector3(0, 0.55, 0), Color("#ffb03a"), Vector3(1, 1.7, 1))
		flames.append(_add_glow(fl, Color("#ffb03a"), 2.6))
		_osc(fl, "scl", Vector3(0.25, 0.35, 0.25), 1.0, 2.3, k)
	parts["flames"] = flames
	# Kirschen & Sahnehauben mit Gesichtern, die wuseln
	for k in 8:
		var a3 := TAU * k / 8.0 + 0.2
		var r := 1.9 if k % 2 == 0 else 2.5
		var y := 2.8 if k % 2 == 0 else 1.5
		var dollop := _piv(body, Vector3(cos(a3) * r, y, sin(a3) * r))
		_sph(dollop, 0.35, Vector3.ZERO, Color.WHITE, Vector3(1, 0.8, 1), 0.9)
		_cyl(dollop, 0.0, 0.25, 0.45, Vector3(0, 0.35, 0), Color.WHITE, Vector3.ZERO, 0.9)
		var fz := Vector3(cos(a3), 0, sin(a3)) * 0.3
		_sph(dollop, 0.05, fz + Vector3(-0.08, 0.05, 0) + Vector3(-sin(a3), 0, cos(a3)) * -0.04, Color("#2a1a2a"))
		_sph(dollop, 0.05, fz + Vector3(0.08, 0.05, 0), Color("#2a1a2a"))
		_osc(dollop, "pos", Vector3(0, 1, 0), 0.08, 1.1, k)
		if k % 2 == 0:
			var ch := _sph(body, 0.28, Vector3(cos(a3) * r, y + 0.55, sin(a3) * r), Color("#e0203a"), Vector3.ONE, 0.1)
			ch.material_override = _mat(Color("#e0203a"), 0.1, 0.1, 0.2)
	# Streusel
	for k in 40:
		var a4 := randf() * TAU
		var rr := randf_range(0.2, 1.3)
		_box(body, Vector3(0.12, 0.04, 0.04), Vector3(cos(a4) * rr, 3.82, sin(a4) * rr), Color.from_hsv(randf(), 0.6, 1.0), Vector3(0, randf() * TAU, 0))
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.75, 0.4)
	lamp.light_energy = 1.0
	lamp.omni_range = 7.0
	lamp.position = Vector3(0, 5.0, 1.5)
	_root.add_child(lamp)


# =============================================================================================================
# 10) Zephyros, der Herrscher der Lüfte – weiches Wolkenwesen mit Windwirbeln und Augen aus Luftströmen
# =============================================================================================================
func _build_zephyros() -> void:
	var cloud := Color("#f8fbff")
	var cloud2 := Color("#e4eeff")
	var wind := Color(0.85, 0.95, 1.0, 0.55)
	var body := _piv(_root, Vector3(0, 4.0, 0), "body")
	_osc(body, "pos", Vector3(0.2, 1, 0), 0.45, 0.2)
	for k in 26:
		var a := randf() * TAU
		var y := randf_range(-1.2, 1.3)
		var rr := sqrt(maxf(0.0, 1.0 - pow(y / 1.7, 2))) * 2.5
		var pp := Vector3(cos(a) * rr, y, sin(a) * rr * 0.8)
		if pp.z > 0.6 and absf(pp.x) < 2.0 and absf(pp.y) < 1.3:
			pp.z = -absf(pp.z)   # Puffs hinter das Gesicht schieben
		var puff := _sph(body, randf_range(0.8, 1.2), pp, cloud if k % 2 else cloud2, Vector3.ONE, 1.0, 0.1)
		_osc(puff, "scl", Vector3(0.07, 0.07, 0.07), 1.0, 0.4, k * 0.5)
	_sph(body, 2.2, Vector3.ZERO, cloud, Vector3(1.25, 1.0, 1.0), 1.0, 0.1)
	# Gesicht: Augen aus kreisenden Luftströmen, Pustebacken
	var face := _piv(body, Vector3(0, 0.3, 2.3), "head")
	for sd in [-1.0, 1.0]:
		var eye := _piv(face, Vector3(sd * 0.75, 0.35, 0.1))
		eye.scale = Vector3.ONE * 1.3
		var coreg := _sph(eye, 0.2, Vector3.ZERO, Color("#7fd6ff"), Vector3.ONE, 0.2)
		_add_glow(coreg, Color("#7fd6ff"), 2.4)
		for k in 2:
			var sw := _torus(eye, 0.28 + k * 0.14, 0.33 + k * 0.14, Vector3.ZERO, Color(0.7, 0.9, 1.0), Vector3(PI * 0.5, 0, k * 0.6), 0.3, 0.6)
			_spin(sw, Vector3(0, 1, 0), (2.0 + k) * sd)
		(parts.get_or_add("eyes", []) as Array).append(eye)
		var cheek := _sph(face, 0.55, Vector3(sd * 1.15, -0.45, 0.0), Color("#ffd1e6"), Vector3(1, 0.9, 0.7), 0.9)
		parts["cheek_%d" % (0 if sd < 0 else 1)] = cheek
		_box(face, Vector3(0.5, 0.1, 0.1), Vector3(sd * 0.75, 0.85, 0.15), Color("#9fb0d0"), Vector3(0, 0, sd * 0.25))
	var mouth := _sph(face, 0.25, Vector3(0, -0.5, 0.25), Color("#9fb0d0"), Vector3(1.0, 1.0, 0.5), 0.5)
	parts["mouth"] = mouth
	_blink(4.0)
	_every(3.0, func() -> void:
		for k in 2:
			var c: Node3D = parts.get("cheek_%d" % k)
			if c:
				var tw := c.create_tween()
				tw.tween_property(c, "scale", Vector3(1.35, 1.2, 0.9), 0.3)
				tw.tween_property(c, "scale", Vector3(1, 0.9, 0.7), 0.4))
	# Windwirbel-Ringe & Windarme
	for k in 3:
		var rg := _piv(body, Vector3(0, -0.5 + k * 0.6, 0))
		_torus(rg, 3.0 + k * 0.4, 3.08 + k * 0.4, Vector3.ZERO, wind, Vector3(0.25 * (k - 1), 0, 0.15 * k), 0.3, 0.3)
		_spin(rg, Vector3(0, 1, 0), 0.6 + k * 0.3)
	for sd in [-1.0, 1.0]:
		var arm := _piv(body, Vector3(sd * 2.6, -0.3, 0.6), "claw_r" if sd > 0 else "arm_l")
		for k in 4:
			_sph(arm, 0.55 - k * 0.1, Vector3(sd * k * 0.5, -k * 0.25, k * 0.15), cloud, Vector3.ONE, 1.0, 0.1)
		_osc(arm, "rot", Vector3(0.3, 0, sd), 0.2, 0.35, sd)
	# Pusteblumen-Samen
	var seeds := _piv(body, Vector3.ZERO)
	for k in 10:
		var a2 := TAU * k / 10.0
		var sp := Vector3(cos(a2) * 3.8, sin(a2 * 3.0) * 1.0, sin(a2) * 3.8)
		_cyl(seeds, 0.01, 0.01, 0.4, sp, Color(1, 1, 1))
		_add_glow(_sph(seeds, 0.14, sp + Vector3(0, 0.25, 0), Color(1, 1, 0.9), Vector3.ONE, 0.3), Color(1, 1, 0.85), 1.4)
	_spin(seeds, Vector3(0, 1, 0), 0.35)
