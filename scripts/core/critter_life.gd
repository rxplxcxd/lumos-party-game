class_name CritterLife
extends Node3D
## Lebendige Ränder für jedes Level: themenpassende Tierchen, die scheinbar sinnvolle Dinge tun – hoppeln
## zu einem Platz, schnüffeln/picken, setzen sich hin und schauen dem Geschehen zu, tanzen bei Jubel –
## dazu Flatterer (Schmetterlinge, Glühwürmchen, Fledermäuse, Schneeflöckchen-Vögel).
## Rein dekorativ: keine Kollision, kein Netz-Sync; Bodenhöhe per Raycast (nie im Leeren schweben).

const THEMES := {
	"meadow": {"walk": ["pet/bunny", "pet/chick", "pet/fox", "pet/deer", "pet/pig", "pet/caterpillar", "pet/chick"], "fly": "butterfly"},
	"beach": {"walk": ["pet/crab", "pet/crab", "pet/parrot", "pet/monkey", "pet/crab"], "fly": "butterfly"},
	"snow": {"walk": ["pet/penguin", "pet/penguin", "pet/polar", "pet/bunny", "pet/penguin"], "fly": "snowbird"},
	"night": {"walk": ["pet/cat", "pet/fox", "pet/hog", "pet/cat"], "fly": "firefly"},
	"sky": {"walk": ["pet/chick", "pet/bunny", "pet/parrot", "pet/koala"], "fly": "butterfly"},
	"sky_dusk": {"walk": ["pet/cat", "pet/bunny", "pet/koala"], "fly": "firefly"},
	"dungeon": {"walk": ["pet/cat", "pet/hog"], "fly": "bat"},
	"cake": {"walk": ["pet/bunny", "pet/chick", "pet/pig", "pet/panda", "pet/bunny"], "fly": "butterfly"},
}
const HOPPERS := ["pet/bunny", "pet/chick", "pet/penguin", "pet/caterpillar"]
const SIDEWAYS := ["pet/crab"]

var center := Vector3.ZERO
var r_in := 10.0
var r_out := 16.0
var anchors: Array[Vector3] = []
var y_min := -3.0
var y_max := 6.0
var max_walk := 9.0   # maximale Laufstrecke zu einem neuen Platz
var _critters: Array[Dictionary] = []
var _flyers: Array[Node3D] = []
var _excite := 0.0
var _rng := RandomNumberGenerator.new()


## Bevölkert den Rand einer Spielfläche. anchors (optional): Punkte, um die herum Plätze gesucht werden
## (z. B. Brettfelder) – sonst ein Ring [r_in, r_out] um center.
static func populate(parent: Node3D, style: String, at: Vector3, inner: float, outer: float, count := 7, anchor_pts: Array[Vector3] = []) -> CritterLife:
	if not THEMES.has(style):
		return null
	var cl := CritterLife.new()
	cl.name = "CritterLife"
	cl.center = at
	cl.r_in = inner
	cl.r_out = outer
	cl.anchors = anchor_pts
	cl.y_min = at.y - 3.0
	cl.y_max = at.y + 8.0
	cl.add_to_group("critters")
	parent.add_child(cl)
	cl._spawn.call_deferred(style, count)
	return cl


## Alle Tierchen jubeln kurz mit (z. B. am Minispiel-Ende).
func excite(seconds := 4.0) -> void:
	_excite = seconds


func _spawn(style: String, count: int) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	_rng.seed = hash(style) ^ int(center.x * 13.0) ^ int(center.z * 7.0)
	var th: Dictionary = THEMES[style]
	var keys: Array = th.walk
	for k in count:
		var spot := _find_spot(18)
		if spot == Vector3.INF:
			continue
		var key: String = keys[k % keys.size()]
		var r := CharacterRig.new()
		add_child(r)
		r.setup(key, -1, _rng.randf_range(0.55, 0.8))
		r.global_position = spot
		r.face_now(Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)))
		r.play("idle")
		for mi in Assets.find_meshes(r):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_critters.append({"rig": r, "key": key, "state": "idle", "t": _rng.randf_range(0.5, 3.0), "to": spot,
			"spd": _rng.randf_range(0.7, 1.4) * (0.6 if key == "pet/caterpillar" else 1.0), "ph": _rng.randf() * TAU})
	var fly := String(th.fly)
	for k in 6:
		var spot2 := _find_spot(10)
		if spot2 == Vector3.INF:
			# Flatterer brauchen keinen Boden: dann einfach am Rand der Spielfläche schweben
			var ang := _rng.randf() * TAU
			var base: Vector3 = anchors[_rng.randi() % anchors.size()] if not anchors.is_empty() else center
			spot2 = base + Vector3(cos(ang), 0.4, sin(ang)) * (_rng.randf_range(r_in, r_out) if anchors.is_empty() else 3.0)
		_flyers.append(_make_flyer(fly, spot2))


## Sucht einen Bodenpunkt (Raycast) im Ring bzw. neben einem Anker.
func _find_spot(tries: int) -> Vector3:
	var space := get_world_3d().direct_space_state
	for t in tries:
		var p: Vector3
		if not anchors.is_empty():
			var a: Vector3 = anchors[_rng.randi() % anchors.size()]
			var ang := _rng.randf() * TAU
			p = a + Vector3(cos(ang), 0, sin(ang)) * _rng.randf_range(2.2, 4.5)
		else:
			var ang2 := _rng.randf() * TAU
			p = center + Vector3(cos(ang2), 0, sin(ang2)) * _rng.randf_range(r_in, r_out)
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, y_max + 6.0, p.z), Vector3(p.x, y_min - 2.0, p.z), 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			if anchors.size() > 1:
				# Bretter haben oft nur sichtbaren Boden: dann auf dem Weg zwischen zwei Nachbarfeldern
				var i := _rng.randi() % (anchors.size() - 1)
				var a0: Vector3 = anchors[i]
				var a1: Vector3 = anchors[i + 1]
				if a0.distance_to(a1) < 7.0 and a0.distance_to(a1) > 1.5:
					var m := a0.lerp(a1, 0.5)
					var side := (a1 - a0).cross(Vector3.UP).normalized() * _rng.randf_range(-0.9, 0.9)
					return m + side
			continue
		var pos: Vector3 = hit.position
		var nrm: Vector3 = hit.normal
		if pos.y < y_min or pos.y > y_max or nrm.y < 0.8:
			continue
		if not anchors.is_empty() and _near_anchor(pos, 1.3):
			continue   # nicht auf Brettfelder stellen
		return pos
	return Vector3.INF


func _near_anchor(p: Vector3, d: float) -> bool:
	for a in anchors:
		if Vector2(a.x - p.x, a.z - p.z).length() < d:
			return true
	return false


func _physics_process(delta: float) -> void:
	_excite = maxf(0.0, _excite - delta)
	var t := Time.get_ticks_msec() * 0.001
	for c in _critters:
		var r: CharacterRig = c.rig
		if not is_instance_valid(r):
			continue
		var key := String(c.key)
		if _excite > 0.0:
			if c.state != "party":
				c.state = "party"
				r.play("cheer" if r.has_clip("cheer") else "idle")
			r.pivot.position.y = absf(sin(t * 9.0 + float(c.ph))) * 0.35
			continue
		elif c.state == "party":
			c.state = "idle"
			c.t = _rng.randf_range(0.5, 1.5)
			r.pivot.position.y = 0.0
			r.play("idle")
		match String(c.state):
			"idle", "act", "watch":
				c.t = float(c.t) - delta
				if float(c.t) <= 0.0:
					_next(c)
			"move":
				var to: Vector3 = c.to
				var d := to - r.global_position
				d.y = 0.0
				if d.length() < 0.15:
					r.global_position = to
					r.pivot.position.y = 0.0
					_arrive(c)
				else:
					var step := d.normalized() * float(c.spd) * delta
					r.global_position += step
					r.global_position.y = lerpf(r.global_position.y, to.y, clampf(delta * 3.0, 0.0, 1.0))
					if key in SIDEWAYS:
						r.face_now(Vector3(-d.z, 0, d.x))
					else:
						r.face_now(d)
					if key in HOPPERS:
						r.pivot.position.y = absf(sin(t * 9.0 + float(c.ph))) * 0.22
	for f in _flyers:
		_animate_flyer(f, t)


## Nächste Tätigkeit: zu einem neuen Platz laufen oder etwas vor Ort tun.
func _next(c: Dictionary) -> void:
	var r: CharacterRig = c.rig
	var roll := _rng.randf()
	if roll < 0.55:
		var to := _find_spot(6)
		if to != Vector3.INF and to.distance_to(r.global_position) < max_walk:
			c.to = to
			c.state = "move"
			r.play("walk" if float(c.spd) < 1.15 else "run")
			return
	if roll < 0.8:
		c.state = "act"   # schnüffeln, picken, knabbern
		r.play("eat" if r.has_clip("eat") else "idle")
		c.t = _rng.randf_range(1.5, 3.5)
	else:
		c.state = "watch"   # setzt sich hin und schaut zur Spielfläche
		var look := center - r.global_position
		if not anchors.is_empty():
			look = anchors[_rng.randi() % anchors.size()] - r.global_position
		r.face_now(Vector3(look.x, 0, look.z))
		r.play("idle")
		c.t = _rng.randf_range(2.5, 5.0)


func _arrive(c: Dictionary) -> void:
	var r: CharacterRig = c.rig
	c.state = "act" if _rng.randf() < 0.6 else "watch"
	c.t = _rng.randf_range(1.2, 3.0)
	r.play("eat" if c.state == "act" and r.has_clip("eat") else "idle")
	if _rng.randf() < 0.25:
		r.squash(1.15, 0.85, 0.3)


# --- Flatterer ---------------------------------------------------------------------------------------------------

func _make_flyer(kind: String, at: Vector3) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	n.global_position = at
	n.set_meta("home", at)
	n.set_meta("ph", _rng.randf() * TAU)
	n.set_meta("kind", kind)
	var m := StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	match kind:
		"firefly":
			var s := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.06
			sm.height = 0.12
			m.albedo_color = Color(1.0, 0.95, 0.45)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.9, 0.3)
			m.emission_energy_multiplier = 3.0
			sm.material = m
			s.mesh = sm
			n.add_child(s)
			return n
		"bat":
			m.albedo_color = Color("#3a2c48")
		"snowbird":
			m.albedo_color = Color("#f4f8ff")
		_:
			m.albedo_color = Color.from_hsv(_rng.randf(), 0.45, 1.0)
	for side in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.name = "L" if side < 0 else "R"
		n.add_child(hinge)
		var w := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.22, 0.18) if kind != "bat" else Vector2(0.32, 0.16)
		q.orientation = PlaneMesh.FACE_Y
		q.material = m
		w.mesh = q
		w.position = Vector3(side * q.size.x * 0.5, 0, 0)
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hinge.add_child(w)
	return n


func _animate_flyer(f: Node3D, t: float) -> void:
	var home: Vector3 = f.get_meta("home")
	var ph := float(f.get_meta("ph"))
	var kind := String(f.get_meta("kind"))
	var sp := 0.5 if kind == "firefly" else 0.8
	var h := 1.2 if kind != "bat" else 2.6
	var p := home + Vector3(sin(t * sp + ph) * 2.2, h + sin(t * sp * 1.7 + ph) * 0.6, sin(t * sp * 0.8 + ph * 2.0) * 2.0)
	var dir := p - f.global_position
	f.global_position = p
	if dir.length() > 0.001:
		f.rotation.y = atan2(dir.x, dir.z)
	if kind == "firefly":
		f.scale = Vector3.ONE * (0.6 + 0.4 * absf(sin(t * 2.5 + ph * 3.0)))
		return
	var flap := sin(t * (22.0 if kind == "bat" else 16.0) + ph) * 0.9
	(f.get_node("L") as Node3D).rotation.z = -flap
	(f.get_node("R") as Node3D).rotation.z = flap
