class_name ClassProgressionEntry
extends Resource

@export_range(1, 100, 1) var level: int = 1
@export var max_hp_gain: int = 0
@export var max_mana_gain: int = 0
@export var granted_abilities: Array[AbilityData] = []


func is_valid(max_level: int) -> bool:
	return level >= 1 and level <= max_level and max_hp_gain >= 0 and max_mana_gain >= 0
