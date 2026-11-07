class_name ArenaCamera
extends Camera3D
## Gameplay-Kamera für Arenen: hält alle Ziele im Bild (Schwerpunkt + Zoom nach Streuung),
## federt weich nach und reagiert auf FOV-Punches.

var targets: Array = []
var offset := Vector3(0, 13, 11)
var look_offset := Vector3(0, 0.5, 0)
var min_dist := 1.0
var max_dist := 1.6
var spread_ref := 12.0
var follow := true
var smooth := 3.0
var fixed_center := Vector3.ZERO
var center_weight := 0.35

var _center := Vector3.ZERO
var _zoom := 1.0


func _ready() -> void:
	fov = 50.0
	set_meta("base_fov", fov)
	far = 400.0
	_center = fixed_center
	_apply(1.0)
	EventBus.fov_punch.connect(func(a: float, d: float) -> void: Juice.fov_punch(self, a, d))


func _process(delta: float) -> void:
	_apply(delta)


func _apply(delta: float) -> void:
	var pts: Array[Vector3] = []
	for t in targets:
		if is_instance_valid(t) and (t as Node3D).visible:
			if t is PartyAvatar and not (t as PartyAvatar).alive:
				continue
			pts.append((t as Node3D).global_position)
	var want_center := fixed_center
	var spread := 0.0
	if follow and pts.size() > 0:
		var c := Vector3.ZERO
		for p in pts:
			c += p
		c /= pts.size()
		for p in pts:
			spread = maxf(spread, Vector2(p.x - c.x, p.z - c.z).length())
		want_center = c.lerp(fixed_center, center_weight)
		want_center.y = lerpf(c.y, fixed_center.y, 0.6)
	var want_zoom := clampf(lerpf(min_dist, max_dist, spread / spread_ref), min_dist, max_dist)
	var k := clampf(delta * smooth, 0.0, 1.0)
	_center = _center.lerp(want_center, k)
	_zoom = lerpf(_zoom, want_zoom, k)
	global_position = _center + offset * _zoom
	look_at(_center + look_offset, Vector3.UP)


func snap() -> void:
	_apply(1.0)
	_apply(1.0)
