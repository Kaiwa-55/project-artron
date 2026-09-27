class_name EffectInstance
extends RefCounted


var data: EffectData
var remaining_turns: int = 0
var stack_count: int = 1
var source_ability_id: String = ""
var source_ability_name: String = ""
var source_combatant_id: String = ""
var source_combatant_name: String = ""
var source_class_dc: int = 0
var is_stance: bool = false


func _init(p_data: EffectData, p_source_ability_id: String = "", p_source_ability_name: String = "", p_is_stance: bool = false, p_source_combatant_id: String = "", p_source_class_dc: int = 0) -> void:
	data = p_data
	remaining_turns = p_data.duration_turns
	stack_count = p_data.stacks_on_apply if p_data.max_stacks <= 0 else mini(p_data.max_stacks, p_data.stacks_on_apply)
	source_ability_id = p_source_ability_id
	source_ability_name = p_source_ability_name
	source_combatant_id = p_source_combatant_id
	source_class_dc = p_source_class_dc
	is_stance = p_is_stance


func get_display_name() -> String:
	if data == null:
		return ""
	var other_name := source_combatant_name if not source_combatant_name.is_empty() else source_combatant_id
	if not other_name.is_empty():
		if data.id == "grabbing":
			return "Grabbing %s" % other_name
		if data.id == "grabbed":
			return "Grabbed by %s" % other_name
	return data.display_name
