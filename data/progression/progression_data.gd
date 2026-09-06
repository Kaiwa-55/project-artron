class_name ProgressionData
extends Resource

@export_range(1, 100, 1) var max_level: int = 10
# Every progression array is indexed by character level. Index 0 is unused.
@export var cumulative_xp_thresholds: PackedInt32Array = PackedInt32Array([
	0, 0, 100, 300, 600, 1000, 1500, 2100, 2800, 3600, 4500
])
@export var ability_points_by_level: PackedInt32Array = PackedInt32Array([
	0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0
])
@export var attribute_points_by_level: PackedInt32Array = PackedInt32Array([
	0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0
])


func get_cumulative_xp_for_level(level: int) -> int:
	var safe_level := clampi(level, 1, max_level)
	if safe_level >= cumulative_xp_thresholds.size():
		return 0
	return maxi(0, cumulative_xp_thresholds[safe_level])


func get_level_for_xp(experience: int) -> int:
	var safe_xp := maxi(0, experience)
	var resolved_level := 1
	for level in range(2, max_level + 1):
		if safe_xp < get_cumulative_xp_for_level(level):
			break
		resolved_level = level
	return resolved_level


func get_xp_to_next_level(level: int, experience: int) -> int:
	if level >= max_level:
		return 0
	var next_level := clampi(level + 1, 2, max_level)
	return maxi(0, get_cumulative_xp_for_level(next_level) - maxi(0, experience))


func get_xp_span_for_level(level: int) -> int:
	if level < 1 or level >= max_level:
		return 0
	return maxi(0, get_cumulative_xp_for_level(level + 1) - get_cumulative_xp_for_level(level))


func get_ability_points_for_level(level: int) -> int:
	return _get_level_reward(ability_points_by_level, level)


func get_attribute_points_for_level(level: int) -> int:
	return _get_level_reward(attribute_points_by_level, level)


func is_valid() -> bool:
	var expected_size := max_level + 1
	if max_level < 1 or cumulative_xp_thresholds.size() != expected_size:
		return false
	if ability_points_by_level.size() != expected_size or attribute_points_by_level.size() != expected_size:
		return false
	if cumulative_xp_thresholds[1] != 0:
		return false
	for level in range(2, max_level + 1):
		if cumulative_xp_thresholds[level] <= cumulative_xp_thresholds[level - 1]:
			return false
	for level in range(1, max_level + 1):
		if ability_points_by_level[level] < 0 or attribute_points_by_level[level] < 0:
			return false
	return true


func _get_level_reward(rewards: PackedInt32Array, level: int) -> int:
	if level < 1 or level > max_level or level >= rewards.size():
		return 0
	return maxi(0, rewards[level])
