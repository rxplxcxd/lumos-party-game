class_name BoardCamera
extends Camera3D
## Brettspiel-Kamera: folgt dem aktiven Spieler weich, kann auf Übersicht herauszoomen.

var target: Node3D
var offset := Vector3(0, 8.0, 9.5)
var look_offset := Vector3(0, 1.0, 0)
var smooth := 3.5
var overview := false
var overview_center := Vector3.ZERO
var overview_offset := Vector3(0, 34, 30)
var zoom := 1.0
## Wolkenturm: Kamera steht immer AUSSEN am Turm (radial zur Achse) und die Übersicht umkreist ihn.
var radial := false
var orbit_overview := false
var _orbit_t := 0.0

var _look := Vector3.ZERO


func _ready() -> void:
	fov = 50.0
	far = 500.0
	set_meta("base_fov", fov)


func _process(delta: float) -> void:
	var want_pos: Vector3
	var want_look: Vector3
	_orbit_t += delta
	if overview or not is_instance_valid(target):
		want_pos = overview_center + overview_offset
		if orbit_overview:
			var a := _orbit_t * 0.12
			want_pos = overview_center + Vector3(sin(a) * overview_offset.z, overview_offset.y, cos(a) * overview_offset.z)
		want_look = overview_center
	else:
		want_look = target.global_position + look_offset
		want_pos = target.global_position + offset * zoom
		if radial:
			var tp := target.global_position
			var out := Vector3(tp.x, 0, tp.z)
			out = out.normalized() if out.length() > 0.5 else Vector3.BACK
			var side := out.cross(Vector3.UP)
			want_pos = tp + (out * 10.5 + Vector3.UP * 4.5 - side * 2.0) * zoom
			want_look = tp + Vector3.UP * 0.6
	var k := clampf(delta * smooth, 0.0, 1.0)
	global_position = global_position.lerp(want_pos, k)
	_look = _look.lerp(want_look, k)
	look_at(_look, Vector3.UP)


func snap_to(t: Node3D) -> void:
	target = t
	overview = false
	if is_instance_valid(t):
		global_position = t.global_position + offset * zoom
		_look = t.global_position + look_offset
		look_at(_look, Vector3.UP)


func snap_overview() -> void:
	overview = true
	global_position = overview_center + overview_offset
	_look = overview_center
	look_at(_look, Vector3.UP)
