class_name Cutscene
extends Node3D
## Basisklasse für Cutscene-Szenen in res://scenes/cutscenes/.
## CutsceneManager instanziert die Szene im aktuellen Level und ruft run(director, ctx) auf.
## Alle Director-Methoden (move, orbit, fly_path, track, title, countdown …) sind awaitbar.

func run(_d: Node, _ctx: Dictionary) -> void:
	pass


## Bogenflug eines Nodes (z. B. Spieler aus der Kanone). Awaitbar.
func arc(node: Node3D, from: Vector3, to: Vector3, height: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(node):
			node.global_position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * height, 0.0, 1.0, duration)
	await tw.finished
