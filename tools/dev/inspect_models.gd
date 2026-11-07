extends SceneTree
# Dev-Tool: druckt Knotenbäume, Skeleton-Bones und AABBs importierter Modelle.
func _init() -> void:
	var paths := [
		"res://assets/3d/characters/KayKit_Adventurers_2.0_FREE/KayKit_Adventurers_2.0_FREE/Characters/gltf/Knight.glb",
		"res://assets/3d/characters/KayKit_Character_Animations_1.1/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/Rig_Medium_General.glb",
		"res://assets/3d/characters/kenney_mini-characters/Models/GLB format/character-male-a.glb",
		"res://assets/3d/vehicles/kenney_car-kit/Models/GLB format/kart-oobi.glb",
	]
	for p in paths:
		var ps: PackedScene = load(p)
		var n := ps.instantiate()
		print("=== ", p.get_file())
		_dump(n, 0)
		var sk := _find_skel(n)
		if sk:
			var names := []
			for i in sk.get_bone_count(): names.append(sk.get_bone_name(i))
			print("  bones: ", names)
		n.free()
	quit()

func _dump(n: Node, d: int) -> void:
	if d > 4: return
	var extra := ""
	if n is AnimationPlayer:
		extra = " anims=%s root=%s" % [n.get_animation_list().size(), n.root_node]
		var lst = n.get_animation_list()
		if lst.size() > 0:
			var a: Animation = n.get_animation(lst[0])
			extra += " track0=%s" % [a.track_get_path(0) if a.get_track_count() > 0 else "-"]
	if n is MeshInstance3D: extra = " aabb=%s" % n.get_aabb()
	print("  ".repeat(d + 1), n.name, " <", n.get_class(), ">", extra)
	for c in n.get_children(): _dump(c, d + 1)

func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D: return n
	for c in n.get_children():
		var r := _find_skel(c)
		if r: return r
	return null
