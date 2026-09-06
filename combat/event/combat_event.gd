class_name CombatEvent
extends RefCounted


var type: EventTypes.Type

var source_id: String = ""
var target_id: String = ""

var data: Dictionary = {}


func _init(
	p_type: EventTypes.Type,
	p_source_id: String = "",
	p_target_id: String = "",
	p_data: Dictionary = {}
) -> void:

	type = p_type
	source_id = p_source_id
	target_id = p_target_id
	data = p_data
