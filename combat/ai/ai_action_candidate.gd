class_name AIActionCandidate
extends RefCounted

enum Type { END_TURN, ATTACK, MOVE, SKILL, ABILITY }

var type: Type = Type.END_TURN
var actor_id: String = ""
var target_id: String = ""
var target_position: Vector2 = Vector2.ZERO
var source_data
var expected_damage: float = 0.0
var kill_value: float = 0.0
var position_value: float = 0.0
var follow_up_value: float = 0.0
var status_value: float = 0.0
var resource_cost: float = 0.0
var risk: float = 0.0
var score: float = 0.0
var reason: String = ""


func stable_key() -> String:
	return "%02d|%s|%s|%.2f|%.2f" % [type, target_id, get_source_id(), target_position.x, target_position.y]


func get_source_id() -> String:
	if source_data == null:
		return ""
	return str(source_data.get("id"))


func to_decision() -> Dictionary:
	var decision := {
		"type": type,
		"actor_id": actor_id,
		"target_id": target_id,
		"target_position": target_position,
		"score": score,
		"status_value": status_value,
		"follow_up_value": follow_up_value,
		"reason": reason,
		"candidate": self
	}
	if type == Type.ATTACK:
		decision["attack_data"] = source_data
	return decision
