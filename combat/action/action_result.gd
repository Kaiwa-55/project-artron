class_name ActionResult
extends RefCounted


var success: bool = false
var failure_reason: String = ""
var requires_reaction_choice: bool = false
var reaction_prompt: Dictionary = {}

var events: Array[CombatEvent] = []


static func success_result() -> ActionResult:
	var result := ActionResult.new()
	result.success = true
	return result


static func failure(
	reason: String
) -> ActionResult:
	var result := ActionResult.new()
	result.success = false
	result.failure_reason = reason
	return result
