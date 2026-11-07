extends Node
func run() -> void:
	var keys: PackedStringArray = OS.get_environment("KEYS").split(",")
	for k in keys:
		var b := Assets.model_aabb(k)
		print("%-26s pos=%s size=%s" % [k, b.position.snapped(Vector3.ONE*0.01), b.size.snapped(Vector3.ONE*0.01)])
