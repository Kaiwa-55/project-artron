class_name AbilityLearningResult
extends RefCounted

var success: bool = false
var failure_reason: String = ""
var ability_id: String = ""
var ability_name: String = ""
var points_spent: int = 0
var remaining_ability_points: int = 0


static func failure(reason: String) -> AbilityLearningResult:
	var result := AbilityLearningResult.new()
	result.failure_reason = reason
	return result
