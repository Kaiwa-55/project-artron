class_name RunEncounterCatalog
extends Resource

@export var combat_encounters: Array[EncounterData] = []
@export var elite_encounters: Array[EncounterData] = []
@export var boss_encounters: Array[EncounterData] = []


func get_pool(pool_id: String) -> Array[EncounterData]:
	var selected: Array[EncounterData]
	match pool_id:
		"elite":
			selected = elite_encounters
		"boss":
			selected = boss_encounters
		_:
			selected = combat_encounters
	if not selected.is_empty():
		return selected
	# A sparse prototype catalog can safely fall back until each tier receives
	# its own EncounterData resources.
	for fallback in [combat_encounters, elite_encounters, boss_encounters]:
		if not fallback.is_empty():
			return fallback
	return []


func pick_encounter(pool_id: String, run_seed: int, node_id: String) -> EncounterData:
	var pool := get_pool(pool_id)
	if pool.is_empty():
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed ^ node_id.hash()
	return pool[rng.randi_range(0, pool.size() - 1)]
