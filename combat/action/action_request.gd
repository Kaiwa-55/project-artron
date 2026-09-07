class_name ActionRequest
extends RefCounted


var actor_id: String = ""

var action_type: ActionTypes.Type

var target_id: String = ""

var target_position: Vector2 = Vector2.ZERO

var attack_data: AttackData
var movement_data: MovementData
var skill_data
# Internal continuation marker used by multi-attack Actions. Each attack still
# opens and resolves its own defensive Reaction window.
var attack_sequence_continuation: bool = false


func _init(
	p_actor_id: String = "",
	p_action_type: ActionTypes.Type = ActionTypes.Type.ATTACK
) -> void:

	actor_id = p_actor_id
	action_type = p_action_type
