extends Node
func run() -> void:
	var k: Node3D = Assets.spawn("kart/oobi", self)
	for c in k.get_children():
		for cc in c.get_children():
			print(cc.name, " pos=", (cc as Node3D).position, " aabb=", (cc as MeshInstance3D).get_aabb() if cc is MeshInstance3D else "")
		print(c.name, " ", (c as Node3D).position)
