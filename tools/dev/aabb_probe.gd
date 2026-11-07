extends Node
## Gibt die AABB-Größen ausgewählter Katalog-Modelle aus (Dev-Hilfe für Skalierungen).
func _ready() -> void:
	var keys := ["city/building_a", "city/building_e", "city/sky_a", "city/sky_c", "sub/house_a", "sub/tree", "city/parasol", "nat/cliff_stone", "nat/cliff_large", "nat/rock_tall",
		"hk/tree_snow", "nat/pine_snow", "nat/cactus", "mg/tree_desert", "ss/floor", "sb/landingpad", "grave/fence", "grave/crypt", "hk/train", "sb/module_a", "space/rocket", "race/barrier_white", "toy/cone", "hk/lantern", "grave/lightpost"]
	for k in keys:
		var bb: AABB = Assets.model_aabb(k)
		print("%-22s size=%s" % [k, bb.size.snapped(Vector3.ONE * 0.01)])
	get_tree().quit()
