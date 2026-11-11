class_name MgKit
extends RefCounted
## Gemeinsame Bausteine der Minispiele ab 1.2.2: gut lesbare Gefahren-Warnungen, Ringe, CPU-Ausweichen.
## Regel für alle Spiele: Jede Gefahr wird vorher sichtbar angekündigt (Fairness), und alles ist mit den
## Standard-Aktionen spielbar (docs/CONTROLS.md).


## Flache, pulsierende Warnscheibe am Boden; verschwindet nach duration (oder bleibt bei duration <= 0).
static func warn_disc(parent: Node, pos: Vector3, radius: float, color := Color(1.0, 0.3, 0.2), duration := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.03
	cm.radial_segments = 40
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r, color.g, color.b, 0.25)
	m.no_depth_test = false
	cm.material = m
	mi.mesh = cm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3.UP * 0.04
	var tw := mi.create_tween().set_loops()
	tw.tween_property(m, "albedo_color:a", 0.6, 0.18)
	tw.tween_property(m, "albedo_color:a", 0.25, 0.18)
	if duration > 0.0:
		mi.get_tree().create_timer(duration, false).timeout.connect(func() -> void:
			if is_instance_valid(mi):
				mi.queue_free())
	return mi


## Leuchtender Ring (Torus) – für Wellen, Ränder, Ziel-Markierungen.
static func ring(parent: Node, radius: float, width: float, color: Color, emission := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = maxf(radius - width * 0.5, 0.01)
	tm.outer_radius = radius + width * 0.5
	tm.rings = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = Color(color.r, color.g, color.b)
	m.emission_energy_multiplier = emission
	tm.material = m
	mi.mesh = tm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## CPU: Richtung weg von Gefahren (Punkte mit Radius) und – nahe am Rand – zurück zur Mitte.
static func flee(pos: Vector3, threats: Array, center: Vector3, edge: float, keep := 0.7) -> Vector2:
	var p := Vector2(pos.x - center.x, pos.z - center.z)
	var mv := Vector2.ZERO
	for t in threats:
		var tp: Vector3 = t[0]
		var r: float = t[1]
		var d := Vector2(pos.x - tp.x, pos.z - tp.z)
		var dist := d.length()
		if dist < r + 1.6:
			mv += d.normalized() * (r + 1.6 - dist) / (r + 1.6) * 2.0 if dist > 0.01 else Vector2(1, 0)
	if p.length() > edge * keep:
		mv -= p.normalized() * (p.length() / edge) * 1.4
	return mv.limit_length(1.0)


## Kleines Konfetti-/Sternen-Feedback an einer Spielerposition (Treffer, Punkt, Erfolg).
static func pop_fx(pos: Vector3, color: Color, big := false) -> void:
	FX.stars(pos + Vector3.UP * 1.6, color, 14 if big else 7)
	if big:
		FX.ring(pos + Vector3.UP * 0.1, Color(color.r, color.g, color.b, 0.8), 2.4, 0.35)
