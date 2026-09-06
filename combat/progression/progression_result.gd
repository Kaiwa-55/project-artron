class_name ProgressionResult
extends RefCounted

var success: bool = false
var failure_reason: String = ""
var previous_experience: int = 0
var current_experience: int = 0
var experience_gained: int = 0
var previous_level: int = 1
var current_level: int = 1
var levels_gained: Array[int] = []
var ability_points_gained: int = 0
var attribute_points_gained: int = 0
var max_hp_gained: int = 0
var max_mana_gained: int = 0
var granted_ability_ids: Array[String] = []
# Each entry describes rewards for one level and can be consumed directly by Level-up UI.
var level_rewards: Array[Dictionary] = []


func has_level_up() -> bool:
	return not levels_gained.is_empty()


func has_pending_choices() -> bool:
	return ability_points_gained > 0 or attribute_points_gained > 0


static func failure(reason: String) -> ProgressionResult:
	var result := ProgressionResult.new()
	result.failure_reason = reason
	return result
