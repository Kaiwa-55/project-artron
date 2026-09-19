class_name ShopCatalog
extends Resource

@export var shops: Array[Resource] = []


func pick_shop(run_seed: int, node_id: String) -> Resource:
	if shops.is_empty():
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed ^ node_id.hash() ^ 0x53484F50
	return shops[rng.randi_range(0, shops.size() - 1)]
