class_name AttributeChoiceResult
extends RefCounted

var success: bool = false
var failure_reason: String = ""
var attribute: int = -1
var new_value: int = 0
var remaining_attribute_points: int = 0


static func failure(reason: String) -> AttributeChoiceResult:
	var result := AttributeChoiceResult.new()
	result.failure_reason = reason
	return result
