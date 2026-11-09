class_name RiverLife
extends Node3D
## Leben auf und am Fluss: treibende Seerosen und Blätter (folgen der Strömung), schwimmende Enten,
## springende Fische mit Platscher und Libellen über dem Wasser. Rein visuell (Zufall lokal).

var path: Array = []
var water_y := -0.45
var width := 3.6
var _drifters: Array[Dictionary] = []
var _fish_t := 1.5
var _len := 1.0
var _seg_len: Array[float] = []


func setup(p: Array, w := 3.6, wy := -0.45) -> RiverLife:
	path = p
	width = w
	water_y = wy
	_len = 0.0
	for k in path.size() - 1:
		var l := ((path[k + 1] as Vector3) - (path[k] as Vector3)).length()
		_seg_len.append(l)
		_len += l
	return self


func _ready() -> void:
	# Seerosen, Blätter und Enten treiben flussabwärts (Strömung ~0,6–1,2 m/s)
	for i in 26:
		var kind := "lily" if i % 3 != 0 else ("duck" if i % 6 == 0 else "leaf")
		var n: Node3D
		match kind:
			"duck":
				var duck := CharacterRig.new()
				add_child(duck)
				duck.setup("npc/duck", -1, 0.75)
				duck.play("idle")
				n = duck
			"lily":
				n = Assets.spawn("nat/lily", self, Vector3.ZERO, randf() * 360.0, randf_range(1.0, 1.6))
			_:
				var leaf := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.35, 0.02, 0.22)
				bm.material = WorldKit.mat([Color("#e8a33a"), Color("#d9693a"), Color("#9cc25a")][i % 3], 0.8)
				leaf.mesh = bm
				add_child(leaf)
				n = leaf
		_drifters.append({"n": n, "s": randf() * _len, "lat": randf_range(-0.35, 0.35) * width, "v": randf_range(0.5, 1.1),
			"spin": randf_range(-0.6, 0.6), "kind": kind, "bob": randf() * TAU})
	# Libellen über dem Wasser
	var flies := FX.emitter({"amount": 14, "life": 4.0, "one_shot": false, "explosive": 0.0, "spread": 180.0, "vel_min": 0.4, "vel_max": 1.2,
		"gravity": Vector3.ZERO, "size": 0.14, "color": Color("#7fe8ff"), "box": Vector3(width * 2.0, 0.6, 40)})
	add_child(flies)
	flies.position = Vector3(0, water_y + 1.0, 0)
	flies.emitting = true


func _sample(s: float) -> Array:
	s = fposmod(s, _len)
	for k in _seg_len.size():
		if s <= _seg_len[k]:
			var a: Vector3 = path[k]
			var b: Vector3 = path[k + 1]
			var dir := (b - a).normalized()
			return [a.lerp(b, s / maxf(_seg_len[k], 0.001)), dir]
		s -= _seg_len[k]
	return [path[0], Vector3.BACK]


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for d in _drifters:
		d.s = float(d.s) + float(d.v) * delta
		var smp := _sample(float(d.s))
		var p: Vector3 = smp[0]
		var dir: Vector3 = smp[1]
		var perp := Vector3(dir.z, 0, -dir.x)
		var n: Node3D = d.n
		if not is_instance_valid(n):
			continue
		var y := water_y + 0.03 + (sin(t * 2.2 + float(d.bob)) * 0.04 if d.kind != "lily" else 0.0)
		n.position = p + perp * float(d.lat) + Vector3(0, y, 0)
		if d.kind == "duck":
			n.rotation.y = atan2(dir.x, dir.z)
		else:
			n.rotation.y += float(d.spin) * delta
	# Springende Fische
	_fish_t -= delta
	if _fish_t <= 0.0:
		_fish_t = randf_range(1.2, 3.0)
		_jump_fish()


func _jump_fish() -> void:
	var smp := _sample(randf() * _len)
	var p: Vector3 = smp[0]
	var dir: Vector3 = smp[1]
	var fish := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.18
	sm.height = 0.24
	sm.material = WorldKit.mat([Color("#ff9f43"), Color("#ffd23f"), Color("#8fd0ff")][randi() % 3], 0.4)
	fish.mesh = sm
	fish.scale = Vector3(1, 1, 1.8)
	add_child(fish)
	var from := p + Vector3(0, water_y, 0)
	var to := from + dir * randf_range(1.2, 2.2)
	fish.position = from
	fish.rotation.y = atan2(dir.x, dir.z)
	FX.splash(from, 0.35)
	var tw := fish.create_tween()
	tw.tween_method(func(k: float) -> void:
		fish.position = from.lerp(to, k) + Vector3.UP * sin(k * PI) * 1.1
		fish.rotation.x = lerpf(-0.9, 0.9, k), 0.0, 1.0, 0.7)
	tw.tween_callback(func() -> void:
		FX.splash(to, 0.3)
		fish.queue_free())
